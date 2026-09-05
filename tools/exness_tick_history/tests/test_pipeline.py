import csv
import io
import tempfile
import unittest
import zipfile
from dataclasses import replace
from datetime import date
from pathlib import Path
from unittest.mock import patch

from tools.exness_tick_history.archive import ArchiveKey, Probe, inventory, verify_zip
from tools.exness_tick_history.cli import DEFAULT_PROFILE
from tools.exness_tick_history.config import load_profile
from tools.exness_tick_history.download import request_identity
from tools.exness_tick_history.report import audit_dataset
from tools.exness_tick_history.sanitize import build_dataset, connection, iter_ticks
from tools.exness_tick_history.storage import Store, StorageError, atomic_json, file_hash, read_json


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.profile = replace(load_profile(DEFAULT_PROFILE), data_root=Path(self.temp.name))

    def seed(self, rows, *, start="2026-09-01", end="2026-09-02", granularity="day"):
        inv = inventory(self.profile, start=start, end=end, granularity=granularity, today=date(2026, 9, 5),
                        probe=lambda key, network: Probe(key.url, "AVAILABLE_CANDIDATE", 200, etag='"fixture"'))
        with Store(self.profile.data_root) as store:
            atomic_json(store.path("runs", inv["inventory_id"], "inventory.json"), inv, immutable=True)
            for owner in inv["owners"]:
                key = ArchiveKey(**owner["key"])
                path = store.path("fixture.zip")
                data = io.StringIO(newline="")
                writer = csv.writer(data)
                writer.writerow(["Exness", "Symbol", "Timestamp", "Bid", "Ask"])
                writer.writerows(rows)
                with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr(key.filename.replace(".zip", ".csv"), data.getvalue())
                sha = file_hash(path)
                target = store.path("archives", sha, key.filename)
                target.parent.mkdir(parents=True, exist_ok=True)
                path.replace(target)
                store.record(request_identity(owner), {"state": "VERIFIED", "sha256": sha, "filename": key.filename,
                                                       **verify_zip(target, key, self.profile.limits)})
        return inv["inventory_id"]

    @staticmethod
    def row(ms="001", bid="1.000", ask="1.001", day="01"):
        return ["exness", "XAUUSD", f"2026-09-{day} 00:00:00.{ms}Z", bid, ask]

    def ticks(self, dataset_id):
        con = connection(self.profile, self.profile.data_root / "test-spill")
        try:
            return list(iter_ticks(con, self.profile.data_root / "datasets" / dataset_id / "date=2026-09-01/ticks.parquet"))
        finally:
            con.close()

    def test_stable_ties_duplicates_and_reproducible_hashes(self):
        rows = [self.row("002"), self.row(), self.row(bid="1.001", ask="1.002"), self.row(bid="1.001", ask="1.002")]
        inv = self.seed(rows)
        first = build_dataset(self.profile, inv, "first")
        second = build_dataset(replace(self.profile, limits=replace(self.profile.limits, memory_limit_mb=64)), inv, "second")
        self.assertEqual(first["logical_sha256"], second["logical_sha256"])
        self.assertEqual([row[5] for row in self.ticks("first")], [2, 3, 4, 1])
        self.assertEqual(first["rows"], 4)
        quality = read_json(self.profile.data_root / "datasets/first/quality.json")
        self.assertEqual(quality["row_conservation"]["timestamp_regressions"], 1)
        self.assertEqual(audit_dataset(self.profile, "first")["artifact_verification"], "PASS")
        self.assertEqual(build_dataset(self.profile, inv, "first"), first)

    def test_quarantine_and_outside_interval_conservation(self):
        rows = [self.row(), self.row(ask="0.9"), self.row(bid="NaN"), self.row(day="02")]
        inv = self.seed(rows, granularity="month")
        result = build_dataset(self.profile, inv, "quarantine")
        quality = read_json(self.profile.data_root / "datasets/quarantine/quality.json")
        counts = quality["row_conservation"]
        self.assertEqual((counts["source_rows"], counts["retained_rows"], counts["quarantined_rows"], counts["outside_selection_rows"]), (4, 1, 2, 1))
        self.assertEqual(result["data_integrity"], "FAIL")
        self.assertTrue(counts["verified"])

    def test_unknown_no_tick_dates_do_not_claim_closure(self):
        inv = self.seed([self.row(day="02")], start="2026-09-01", end="2026-09-03", granularity="month")
        result = build_dataset(self.profile, inv, "gap")
        self.assertEqual(result["data_integrity"], "INCONCLUSIVE")
        quality = read_json(self.profile.data_root / "datasets/gap/quality.json")
        self.assertEqual(quality["no_tick_days_unknown_closure"], ["2026-09-01"])

    def test_publish_interruption_resumes_and_corruption_fails_audit(self):
        inv = self.seed([self.row(), self.row()])
        from tools.exness_tick_history import sanitize
        original = sanitize.os.replace
        def fail_final(src, dst):
            if Path(dst).name == "resume":
                raise OSError("simulated interrupted publish")
            return original(src, dst)
        with patch.object(sanitize.os, "replace", side_effect=fail_final), self.assertRaises(OSError):
            build_dataset(self.profile, inv, "resume")
        self.assertFalse((self.profile.data_root / "datasets/resume").exists())
        result = build_dataset(self.profile, inv, "resume")
        self.assertEqual(result["rows"], 2)
        path = self.profile.data_root / "datasets/resume/date=2026-09-01/ticks.parquet"
        path.write_bytes(b"corrupt")
        self.assertEqual(audit_dataset(self.profile, "resume")["data_integrity"], "FAIL")

    def test_disk_failure_leaves_no_published_dataset(self):
        inv = self.seed([self.row()])
        with patch.object(Store, "disk_check", side_effect=StorageError("disk full")), self.assertRaises(StorageError):
            build_dataset(self.profile, inv, "diskfull")
        self.assertFalse((self.profile.data_root / "datasets/diskfull").exists())

    def test_multiple_batches_with_constrained_memory(self):
        inv = self.seed([self.row(ms=f"{i % 1000:03}") for i in range(9000)])
        profile = replace(self.profile, limits=replace(self.profile.limits, memory_limit_mb=64))
        result = build_dataset(profile, inv, "bounded")
        self.assertEqual(result["rows"], 9000)
        self.assertEqual(result["parts"][0]["equal_timestamp_rows"], 8000)
        self.assertEqual(audit_dataset(profile, "bounded")["artifact_verification"], "PASS")

    def test_exhausted_duckdb_spill_limit_fails(self):
        import duckdb
        profile = replace(self.profile, limits=replace(self.profile.limits, memory_limit_mb=64, temp_limit_mb=1))
        con = connection(profile, profile.data_root / "limited-spill")
        try:
            with self.assertRaises(duckdb.OutOfMemoryException):
                con.execute("SELECT i, hash(i) k FROM range(10000000) t(i) ORDER BY k")
        finally:
            con.close()
