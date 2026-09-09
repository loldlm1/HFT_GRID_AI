import csv
import io
import json
import random
import shutil
import tempfile
import unittest
import zipfile
from dataclasses import replace
from datetime import date
from pathlib import Path
from unittest.mock import patch

from tools.exness_tick_history import prepare
from tools.exness_tick_history.archive import ArchiveKey, Probe, SourceError, inventory, verify_zip
from tools.exness_tick_history.cli import DEFAULT_PROFILE, main
from tools.exness_tick_history.compare import native_ticks
from tools.exness_tick_history.config import load_profile
from tools.exness_tick_history.download import request_identity
from tools.exness_tick_history.mt5_export import TICK_HEADER
from tools.exness_tick_history.storage import Store, StorageError, atomic_json, file_hash, read_json


@unittest.skipUnless(shutil.which("g++") or shutil.which("c++"), "C++17 compiler unavailable")
class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.profile = replace(load_profile(DEFAULT_PROFILE), data_root=self.root / "store")
        self.output = self.root / "output"

    @staticmethod
    def row(ms="001", bid="1.10000", ask="1.10002", day="01", symbol="XAUUSD"):
        return ["exness", symbol, f"2026-09-{day} 00:00:00.{ms}Z", bid, ask]

    def seed(self, rows_by_day, *, start="2026-09-01", end="2026-09-02", mode="day", final_newline=True):
        selected = inventory(self.profile, start=start, end=end, granularity=mode, today=date(2026, 9, 8),
                             probe=lambda key, network: Probe(key.url, "AVAILABLE_CANDIDATE", 200, etag='"fixture"'))
        with Store(self.profile.data_root) as store:
            atomic_json(store.path("runs", selected["inventory_id"], "inventory.json"), selected, immutable=True)
            for owner in selected["owners"]:
                key = ArchiveKey(**owner["key"])
                data = io.StringIO(newline="")
                writer = csv.writer(data)
                writer.writerow(["Exness", "Symbol", "Timestamp", "Bid", "Ask"])
                writer.writerows(rows_by_day.get(owner["start"], []))
                body = data.getvalue()
                if not final_newline:
                    body = body.rstrip("\r\n")
                archive_path = store.path("fixture.zip")
                with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr(key.filename.replace(".zip", ".csv"), body)
                sha = file_hash(archive_path)
                target = store.path("archives", sha, key.filename)
                target.parent.mkdir(parents=True, exist_ok=True)
                archive_path.replace(target)
                store.record(request_identity(owner), {"state": "VERIFIED", "sha256": sha,
                    "filename": key.filename, "bytes": target.stat().st_size,
                    **verify_zip(target, key, self.profile.limits)})
        return selected

    def run_preparation(self, selected, name="fixture", **kwargs):
        return prepare.prepare_mt5_file(self.profile, selected["inventory_id"], name, self.output, **kwargs)

    def test_stable_ties_multiplicity_and_single_header_across_sources(self):
        rows = [self.row("002", "1.300", "1.400"), self.row(), self.row(bid="1.200", ask="1.300")]
        rows.append(rows[-1])
        selected = self.seed({"2026-09-01": rows, "2026-09-02": [self.row(day="02")]}, end="2026-09-03")
        result = self.run_preparation(selected)
        output = self.output / "XAUUSD_ticks.tsv"
        self.assertEqual(result["rows"], 5)
        self.assertEqual(output.read_bytes().count(TICK_HEADER.encode()), 1)
        self.assertEqual([str(t[1]) for t in native_ticks(output)], ["1.10000", "1.200", "1.200", "1.300", "1.10000"])
        self.assertEqual(result["sha256"], file_hash(output))
        self.assertEqual(result["file_audit"]["timestamp_regressions"], 0)
        self.assertEqual(result["sources"][0]["source_timestamp_regressions"], 1)
        self.assertEqual(result["file_audit"]["adjacent_equal_time_rows"], 2)
        self.assertEqual(result["native_import"], "NOT_PERFORMED")
        self.assertEqual(self.run_preparation(selected), result)
        self.assertFalse((self.profile.data_root / "preparations/fixture/work").exists())
        self.assertTrue(list((self.profile.data_root / "archives").rglob("*.zip")))

    def test_stream_boundaries_and_absent_final_newline(self):
        rng = random.Random(13)
        rows = [self.row(f"{rng.randrange(1000):03d}", f"1.{i % 1000:03d}", f"2.{i % 1000:03d}") for i in range(32769)]
        selected = self.seed({"2026-09-01": rows}, final_newline=False)
        result = self.run_preparation(selected)
        expected = TICK_HEADER + "".join("2026.09.01\t" + row[2][11:23] + "\t" + row[3] + "\t" + row[4] + "\t0\t0\n"
                                         for row in sorted(rows, key=lambda row: row[2]))
        self.assertEqual((self.output / "XAUUSD_ticks.tsv").read_text(), expected)
        self.assertEqual(result["rows"], len(rows))

    def test_month_container_selection_conservation(self):
        selected = self.seed({"2026-09-02": [self.row(day="01"), self.row(day="02"), self.row(day="03")]},
                             start="2026-09-02", end="2026-09-03", mode="month")
        result = self.run_preparation(selected)
        self.assertEqual(result["rows"], 1)
        self.assertEqual(result["sources"][0]["source_rows"], 3)
        self.assertEqual(result["sources"][0]["outside_selection_rows"], 2)

    def test_resume_truncates_only_uncommitted_tail(self):
        selected = self.seed({"2026-09-01": [self.row()], "2026-09-02": [self.row(day="02")]}, end="2026-09-03")
        original = prepare.atomic_json
        stopped = False
        def interrupt(path, value, **kwargs):
            nonlocal stopped
            if Path(path).name == "progress.json" and len(value.get("completed", [])) == 2 and not stopped:
                stopped = True
                raise OSError("simulated failure after second append")
            return original(path, value, **kwargs)
        with patch.object(prepare, "atomic_json", side_effect=interrupt), self.assertRaises(OSError):
            self.run_preparation(selected)
        self.assertFalse((self.output / "XAUUSD_ticks.tsv").exists())
        result = self.run_preparation(selected)
        self.assertEqual(result["rows"], 2)
        self.assertEqual(len(list(native_ticks(self.output / "XAUUSD_ticks.tsv"))), 2)

    def test_committed_partial_corruption_is_not_repaired_silently(self):
        selected = self.seed({"2026-09-01": [self.row()]})
        original = prepare.run_helper
        with patch.object(prepare, "run_helper", wraps=prepare.run_helper) as runner:
            def stop_audit(binary, args, **kwargs):
                if args[0] == "audit":
                    raise OSError("stop before final audit")
                return original(binary, args, **kwargs)
            runner.side_effect = stop_audit
            with self.assertRaises(OSError): self.run_preparation(selected)
        partial = next(self.output.glob("*.partial"))
        with partial.open("r+b") as stream:
            stream.seek(len(TICK_HEADER) + 1)
            stream.write(b"X")
        with self.assertRaises(StorageError): self.run_preparation(selected)

    def test_publication_recovery_and_output_tampering(self):
        selected = self.seed({"2026-09-01": [self.row()]})
        with patch.object(prepare, "_publish", side_effect=OSError("interrupted publish")), self.assertRaises(OSError):
            self.run_preparation(selected)
        result = self.run_preparation(selected)
        path = self.output / result["file"]
        path.write_text("changed")
        with self.assertRaises(StorageError): self.run_preparation(selected)

    def test_unrelated_output_is_never_overwritten(self):
        selected = self.seed({"2026-09-01": [self.row()]})
        self.output.mkdir()
        final = self.output / "XAUUSD_ticks.tsv"
        final.write_text("user data")
        with self.assertRaises(StorageError): self.run_preparation(selected)
        self.assertEqual(final.read_text(), "user data")

    def test_private_download_disposal_preserves_shared_archives(self):
        selected = self.seed({"2026-09-01": [self.row()]})
        with Store(self.profile.data_root) as store:
            record = store.object(request_identity(selected["owners"][0]))
            original_path = store.path("archives", record["sha256"], record["filename"])
        def fetch(cache, owner, profile, **kwargs):
            path = cache.path("archives", record["sha256"], record["filename"])
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original_path, path)
            return record
        with patch.object(Store, "object", return_value=None), patch.object(prepare, "fetch_object", side_effect=fetch):
            result = self.run_preparation(selected)
        self.assertFalse(result["sources"][0]["shared_source_retained"])
        self.assertFalse(list((self.profile.data_root / "preparations/fixture/download-cache").rglob("*.zip")))
        self.assertTrue(original_path.exists())

    def test_strict_default_and_explicit_bounded_eurusd_artifacts(self):
        self.profile = replace(self.profile, instrument=replace(self.profile.instrument,
            base_symbol="EURUSD", archive_symbol="EURUSD", broker_symbol="EURUSD"))
        selected = self.seed({"2026-09-01": [self.row(symbol="EURUSD", bid="1.1847699999999999", ask="1.1848300000000001")]})
        with self.assertRaisesRegex(SourceError, "precision"):
            self.run_preparation(selected, name="strict")
        self.assertFalse((self.output / "EURUSD_ticks.tsv").exists())
        result = self.run_preparation(selected, name="explicit", price_policy="eurusd-5dp-artifacts")
        self.assertEqual((result["adjusted_rows"], result["adjusted_quotes"]), (1, 2))
        self.assertIn("\t1.18477\t1.18483\t", (self.output / "EURUSD_ticks.tsv").read_text())
        self.assertEqual(result["sources"][0]["max_price_adjustment"], "0.00000000000000010000")
        self.assertEqual(result["price_policy"], "eurusd-5dp-artifacts")
        self.assertEqual(result["broker_equivalence"], "NOT_VERIFIED")

    def test_resume_finishes_interrupted_private_archive_cleanup(self):
        selected = self.seed({"2026-09-01": [self.row()]})
        with Store(self.profile.data_root) as store:
            record = store.object(request_identity(selected["owners"][0]))
            original_path = store.path("archives", record["sha256"], record["filename"])
        def fetch(cache, owner, profile, **kwargs):
            path = cache.path("archives", record["sha256"], record["filename"])
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original_path, path)
            return record
        original_unlink = Path.unlink
        interrupted = False
        def unlink(path, *args, **kwargs):
            nonlocal interrupted
            if path.suffix == ".zip" and "download-cache" in path.parts and not interrupted:
                interrupted = True
                raise OSError("interrupted disposal")
            return original_unlink(path, *args, **kwargs)
        with patch.object(Store, "object", return_value=None), patch.object(prepare, "fetch_object", side_effect=fetch) as download:
            with patch.object(Path, "unlink", unlink), self.assertRaises(OSError):
                self.run_preparation(selected)
            result = self.run_preparation(selected)
            self.assertEqual(download.call_count, 1)
        self.assertEqual(result["rows"], 1)
        self.assertFalse(list((self.profile.data_root / "preparations/fixture/download-cache").rglob("*.zip")))

    def test_checkpoint_offsets_and_candidate_manifest_checksums(self):
        partial = self.root / "partial.tsv"
        partial.write_text(TICK_HEADER)
        with self.assertRaises(StorageError):
            prepare._partial_digest(partial, [{"output_start": len(TICK_HEADER), "output_end": -1}])
        selected = self.seed({"2026-09-01": [self.row()]})
        with patch.object(prepare, "_publish", side_effect=OSError("interrupted publish")), self.assertRaises(OSError):
            self.run_preparation(selected)
        candidate = self.profile.data_root / "preparations/fixture/prepared-manifest.json"
        changed = read_json(candidate)
        changed["rows"] += 1
        atomic_json(candidate, changed)
        with self.assertRaises(StorageError): self.run_preparation(selected)

    def test_normalization_cannot_hide_crossing_or_exceed_tolerance(self):
        self.profile = replace(self.profile, instrument=replace(self.profile.instrument,
            base_symbol="EURUSD", archive_symbol="EURUSD", broker_symbol="EURUSD"))
        for n, (bid, ask) in enumerate([("1.1847700000000001", "1.1847699999999999"),
                                       ("1.1847699999999998", "1.18483")]):
            with self.subTest(bid=bid):
                self.profile = replace(self.profile, data_root=self.root / f"case-{n}")
                selected = self.seed({"2026-09-01": [self.row(symbol="EURUSD", bid=bid, ask=ask)]})
                with self.assertRaises(SourceError):
                    self.run_preparation(selected, name=f"case-{n}", price_policy="eurusd-5dp-artifacts")
        self.assertFalse((self.output / "EURUSD_ticks.tsv").exists())

    def test_invalid_dates_prices_nul_and_oversized_lines(self):
        cases = [(2, "2026-09-31 00:00:00.001Z"), (2, "2026-09-01 00:00:60.001Z"),
                 (2, "2026-09-02 00:00:00.001Z"), (3, "NaN"), (3, "0"), (3, "1e0"),
                 (3, "1.2.3"), (3, "1.1000000000001"), (3, "1\0"), (3, "1" * 65536)]
        with Store(self.profile.data_root) as store:
            binary, _ = prepare.ensure_helper(store)
        for column, value in cases:
            with self.subTest(value=value[:30]):
                row = self.row(); row[column] = value
                source = self.root / "source.csv"
                with source.open("w", newline="") as stream:
                    writer = csv.writer(stream); writer.writerow(["Exness", "Symbol", "Timestamp", "Bid", "Ask"]); writer.writerow(row)
                with self.assertRaises(SourceError):
                    prepare.run_helper(binary, ["convert", str(source), str(self.root / "part.tsv"), "XAUUSD",
                        "2026-09-01", "2026-09-02", "2026-09-01", "2026-09-02", "strict"])

    def test_missing_source_is_explicit_and_access_failure_blocks(self):
        for state in ("NOT_FOUND", "ACCESS_DENIED"):
            self.profile = replace(self.profile, data_root=self.root / state)
            selected = self.seed({"2026-09-01": [self.row()]})
            changed = inventory(self.profile, start="2026-09-01", end="2026-09-03", granularity="day", today=date(2026, 9, 8),
                probe=lambda key, network: Probe(key.url, "AVAILABLE_CANDIDATE", 200, etag='"fixture"')
                if key.day == 1 else Probe(key.url, state, 404 if state == "NOT_FOUND" else 403))
            with Store(self.profile.data_root) as store:
                atomic_json(store.path("runs", changed["inventory_id"], "inventory.json"), changed)
            self.output = self.root / (state + "-out")
            if state == "NOT_FOUND":
                result = self.run_preparation(changed)
                self.assertEqual(result["source_unavailable_intervals"][0]["state"], "NOT_FOUND")
                self.assertEqual(result["coverage"], "PUBLISHED_SOURCES_ONLY")
            else:
                with self.assertRaises(SourceError): self.run_preparation(changed)

    def test_fallback_sort_matches_native_sequence(self):
        selected = self.seed({"2026-09-01": [self.row("002"), self.row("001")]})
        original = shutil.which
        with patch.object(prepare.shutil, "which", side_effect=lambda value: None if value == "sort" else original(value)):
            result = self.run_preparation(selected)
        self.assertEqual(result["sources"][0]["sort_engine"], "duckdb_stable_sort")
        self.assertEqual(len(list(native_ticks(self.output / "XAUUSD_ticks.tsv"))), 2)

    def test_helper_integrity_missing_compiler_and_low_disk(self):
        with Store(self.profile.data_root) as store:
            with patch.object(prepare.shutil, "which", return_value=None), self.assertRaises(SourceError):
                prepare.ensure_helper(store)
            binary, _ = prepare.ensure_helper(store)
            binary.write_bytes(b"changed")
            with self.assertRaises(StorageError): prepare.ensure_helper(store)
        self.profile = replace(self.profile, data_root=self.root / "disk")
        selected = self.seed({"2026-09-01": [self.row()]})
        with patch.object(Store, "disk_check", side_effect=StorageError("disk full")), self.assertRaises(StorageError):
            self.run_preparation(selected)
        self.assertFalse((self.output / "XAUUSD_ticks.tsv").exists())

    def test_cli_dispatches_explicit_policy(self):
        report = dict(symbol="EURUSD", output="ticks.tsv", rows=1, bytes=100, sha256="hash",
                      price_policy="eurusd-5dp-artifacts", adjusted_rows=1, adjusted_quotes=1,
                      native_import="NOT_PERFORMED", broker_equivalence="NOT_VERIFIED")
        with patch("tools.exness_tick_history.cli.prepare_mt5_file", return_value=report) as operation, patch("sys.stdout", io.StringIO()):
            code = main(["prepare-mt5-file", "--inventory", "inv-fixture", "--preparation-id", "cli",
                         "--output-dir", str(self.output), "--normalize-eurusd-decimal-artifacts"])
        self.assertEqual(code, 0)
        self.assertEqual(operation.call_args.kwargs["price_policy"], "eurusd-5dp-artifacts")
