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
from tools.exness_tick_history.storage import Store, StorageError, atomic_json, file_hash, object_hash, read_json


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
                store.record(request_identity(owner), {"state": "VERIFIED", "sha256": sha, "filename": key.filename, "bytes": target.stat().st_size,
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

    def test_storage_planning_discloses_unknown_sizes_and_insufficient_disk(self):
        from tools.exness_tick_history.report import storage_plan
        from unittest.mock import Mock
        inv_id = self.seed([self.row()])
        build_dataset(self.profile, inv_id, "pilot")
        self.assertEqual(storage_plan(self.profile, inv_id, "pilot")["status"], "STORAGE_ESTIMATE_INCONCLUSIVE")
        with Store(self.profile.data_root) as store:
            inv = read_json(store.path("runs", inv_id, "inventory.json"))
            inv.pop("inventory_id")
            inv["unknown_size_archives"] = 0
            inv["estimated_download_bytes"] = 1000000
            inv["owners"][0]["probe"]["content_length"] = 1000000
            inv["inventory_id"] = "inv-" + object_hash(inv)[:24]
            atomic_json(store.path("runs", inv["inventory_id"], "inventory.json"), inv, immutable=True)
        with patch("shutil.disk_usage", return_value=Mock(free=1)):
            result = storage_plan(self.profile, inv["inventory_id"], "pilot")
        self.assertEqual(result["status"], "INSUFFICIENT_ESTIMATED_STORAGE")
        self.assertEqual(sum(result["components_bytes"].values()), result["estimated_total_bytes"])
        self.assertFalse(result["assumptions"]["mt5_storage_measured"])

    def test_research_provenance_is_immutable_and_outside_v14_run(self):
        from tools.exness_tick_history.report import research_provenance
        from tools.exness_tick_history.mt5_export import export_mt5
        from tools.exness_tick_history.tests import test_mt5_export as exports
        inv = self.seed([self.row()])
        build_dataset(self.profile, inv, "input")
        export_mt5(self.profile, "input", "export", exports.specification(self.profile), exports.clock_map())
        source, binary = self.profile.data_root / "source.bin", self.profile.data_root / "binary.bin"
        source.write_bytes(b"authored source hash fixture")
        binary.write_bytes(b"authored binary hash fixture; not a compiled program")
        result = research_provenance(self.profile, "input", "export", "research", "v14-fixture", source, binary)
        self.assertEqual(result["schema_version"], 2)
        self.assertEqual(result["v14_run_id"], "v14-fixture")
        self.assertFalse(result["v14_run_files_written"])
        self.assertEqual(result["operator_validation"], "PENDING_OPERATOR")
        self.assertEqual(result["ea_binary_sha256"], file_hash(binary))
        self.assertEqual(list(self.profile.data_root.rglob("*.tsv")), [self.profile.data_root / "exports/export/ticks-000000.tsv"])
        binary.write_bytes(b"changed")
        with self.assertRaises(StorageError):
            research_provenance(self.profile, "input", "export", "research", "v14-fixture", source, binary)

    def test_cli_build_audit_and_deferred_acceptance_status(self):
        from contextlib import redirect_stdout
        from tools.exness_tick_history.cli import main
        inv = self.seed([self.row()])
        config = self.profile.data_root / "local.toml"
        config.write_text(f'schema_version = 1\n[storage]\ndata_root = "{self.profile.data_root}"\n')
        prefix = ["--config", str(config)]
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(main(prefix + ["build", "--inventory", inv, "--dataset-id", "cli"]), 0)
            self.assertEqual(main(prefix + ["audit", "--dataset-id", "cli"]), 0)
            self.assertEqual(main(prefix + ["seasonal-report", "--year", "2026"]), 4)
        self.assertIn('"artifact_verification": "PASS"', output.getvalue())
        self.assertIn('"seasonal_acceptance": "INCONCLUSIVE"', output.getvalue())
