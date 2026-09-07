import copy
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from tools.exness_tick_history.archive import SourceError
from tools.exness_tick_history.capture import audit_capture, freeze_capture
from tools.exness_tick_history.cli import main
from tools.exness_tick_history.compare import PERIOD_MS, mcp_tick_rows, read_mcp_history
from tools.exness_tick_history.storage import StorageError, atomic_json, file_hash, object_hash


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.requests = self.root / "requests.json"
        self.frozen = self.root / "frozen.json"
        self.tsv = self.root / "source.tsv"
        self.ticks = [
            {"time_ms": "2026.07.15 00:00:00.001", "bid": "1.001", "ask": "1.003"},
            {"time_ms": "2026.07.15 00:00:00.001", "bid": "1.002", "ask": "1.004"},
            {"time_ms": "2026.07.15 00:00:00.001", "bid": "1.002", "ask": "1.004"},
            {"time_ms": "2026.07.15 00:01:00.999", "bid": "1.0015", "ask": "1.0035"},
        ]
        self.tsv.write_text("<DATE>\t<TIME>\t<BID>\t<ASK>\t<LAST>\t<VOLUME>\n" + "".join(
            tick["time_ms"].replace(" ", "\t") + "\t" + tick["bid"] + "\t" + tick["ask"] + "\t0\t0\n" for tick in self.ticks))
        self.expected_hash = file_hash(self.tsv)
        self.request = {"schema_version": 1, "symbol": "XAUUSD_EXN", "requested_from": "2026-07-15T00:00:00",
                        "requested_to": "2026-07-15T01:00:00", "entries": [self.entry("ticks.json", 4)], "bars": {}}
        self.write_response("ticks.json", "tick", self.ticks)
        minute_bars = [self.bar("00:00:00", "1.001", "1.002", "1.001", "1.002", 3),
                       self.bar("00:01:00", "1.0015", "1.0015", "1.0015", "1.0015", 1)]
        aggregate = [self.bar("00:00:00", "1.001", "1.002", "1.001", "1.0015", 4)]
        for period in PERIOD_MS:
            rows = minute_bars if period == "M1" else aggregate
            self.write_response(period + ".json", period, rows)
            self.request["bars"][period] = self.entry(period + ".json", len(rows))

    def entry(self, path, rows):
        return {"path": path, "start": "2026-07-15T00:00:00", "end": "2026-07-15T01:00:00", "rows": rows, "limit": 100}

    def bar(self, time, opened, high, low, closed, volume):
        return dict(time="2026.07.15 " + time, open=opened, high=high, low=low, close=closed, tick_volume=volume)

    def write_response(self, filename, period, rows, symbol="XAUUSD_EXN"):
        atomic_json(self.root / filename, {"symbol": symbol, "period": period, "history": rows})

    def freeze(self, output=None):
        atomic_json(self.requests, self.request)
        return freeze_capture(self.requests, output or self.frozen)

    def audit(self, **kwargs):
        return audit_capture(self.frozen, expected_ticks=self.tsv, expected_sha256=self.expected_hash, **kwargs)

    def test_exact_ticks_ties_and_all_bar_volumes_pass_deterministically(self):
        self.freeze()
        a, b = self.audit(), self.audit()
        self.assertEqual(a, b)
        self.assertEqual(a["capture_audit"], "PASS")
        self.assertEqual(a["tick_equality"], "PASS")
        self.assertEqual(a["native_rows"], 4)
        self.assertEqual(a["adjacent_equal_time_rows"], 2)
        self.assertEqual(a["native_ordered_quote_sha256"], a["expected_ordered_quote_sha256"])
        self.assertEqual(a["native_bars"]["M1"]["native_bars"], 2)
        self.assertEqual({bar["status"] for bar in a["native_bars"].values()}, {"PASS"})
        self.assertEqual(a["broker_comparison"], "INCONCLUSIVE")
        self.assertNotIn("mt5_round_trip", a)

    def test_immutable_freeze_reuses_bytes_and_refuses_changed_capture(self):
        self.freeze()
        first = self.frozen.read_bytes()
        self.freeze()
        self.assertEqual(self.frozen.read_bytes(), first)
        self.write_response("ticks.json", "tick", list(reversed(self.ticks)))
        with self.assertRaises(StorageError):
            self.freeze()

    def test_capture_hash_and_manifest_hash_changes_fail(self):
        self.freeze()
        (self.root / "ticks.json").write_text("corrupt")
        self.assertEqual(self.audit()["capture_integrity"], "FAIL")
        manifest = json.loads(self.frozen.read_text())
        manifest["symbol"] = "OTHER"
        atomic_json(self.frozen, manifest)
        self.assertIn("Frozen capture manifest identity or checksum mismatch", self.audit()["errors"])

    def test_missing_frozen_schema_fields_produce_failure_report(self):
        manifest = self.freeze()
        del manifest["bars"]
        manifest["manifest_sha256"] = object_hash({key: value for key, value in manifest.items() if key != "manifest_sha256"})
        atomic_json(self.frozen, manifest)
        result = self.audit()
        self.assertEqual(result["capture_audit"], "FAIL")
        self.assertIn("Frozen capture requires an explicit timeframe map", result["errors"])

    def test_deleted_duplicated_reordered_and_shifted_ticks_fail(self):
        cases = [self.ticks[:-1], self.ticks + [self.ticks[-1]],
                 [self.ticks[1], self.ticks[0], *self.ticks[2:]],
                 [{**self.ticks[0], "time_ms": "2026.07.15 00:00:00.002"}, *self.ticks[1:]]]
        for index, ticks in enumerate(cases):
            with self.subTest(index=index):
                self.write_response("ticks.json", "tick", ticks)
                self.request["entries"][0]["rows"] = len(ticks)
                self.frozen = self.root / ("frozen-" + str(index) + ".json")
                self.freeze()
                self.assertEqual(self.audit()["capture_audit"], "FAIL")

    def test_gaps_overlaps_reordering_wrong_symbol_and_unsafe_paths_refused(self):
        original = copy.deepcopy(self.request)
        for field, value in (("start", "2026-07-15T00:00:01"), ("end", "2026-07-15T00:59:00"), ("path", "../outside.json")):
            self.request = copy.deepcopy(original)
            self.request["entries"][0][field] = value
            with self.subTest(field=field), self.assertRaises(SourceError):
                self.freeze()
        self.request = copy.deepcopy(original)
        self.request["entries"] *= 2
        with self.assertRaises(SourceError):
            self.freeze()
        self.request = original
        self.write_response("ticks.json", "tick", self.ticks, symbol="WRONG_SYMBOL")
        with self.assertRaises(SourceError):
            self.freeze()

    def test_limit_reached_is_inconclusive_with_disjoint_recapture_requests(self):
        self.request["entries"][0]["limit"] = 4
        self.freeze()
        result = self.audit()
        self.assertEqual(result["capture_audit"], "INCONCLUSIVE")
        self.assertEqual(result["tick_equality"], "INCONCLUSIVE")
        self.assertEqual(result["recapture_requests"][0]["intervals"],
                         [["2026-07-15T00:00:00.000", "2026-07-15T00:30:00.000"], ["2026-07-15T00:30:00.000", "2026-07-15T01:00:00.000"]])

    def test_one_millisecond_limit_requires_native_export(self):
        self.request.update(requested_to="2026-07-15T00:00:00.001", bars={})
        self.request["entries"][0].update(end=self.request["requested_to"], limit=4)
        self.freeze()
        result = self.audit()
        self.assertEqual(result["capture_audit"], "INCONCLUSIVE")
        self.assertTrue(result["recapture_requests"][0]["native_export_required"])

    def test_out_of_range_milliseconds_and_crossed_quotes_fail(self):
        for index, replacement in enumerate(({"time_ms": "2026.07.15 01:00:00.000"},
                                               {"time_ms": "2026.07.15 00:00:00"}, {"ask": "0.5"})):
            ticks = [{**self.ticks[0], **replacement}, *self.ticks[1:]]
            self.write_response("ticks.json", "tick", ticks)
            self.frozen = self.root / (str(index) + ".json")
            self.freeze()
            self.assertEqual(self.audit()["capture_audit"], "FAIL")

    def test_ohlc_and_tick_volume_are_independent_failure_gates(self):
        for index, change in enumerate(({"high": "1.003"}, {"tick_volume": 3})):
            self.write_response("H1.json", "H1", [{**self.bar("00:00:00", "1.001", "1.002", "1.001", "1.0015", 4), **change}])
            self.frozen = self.root / (str(index) + ".json")
            self.freeze()
            result = self.audit()
            self.assertEqual(result["tick_equality"], "PASS")
            self.assertEqual(result["capture_audit"], "FAIL")
            self.assertEqual(result["native_bars"]["H1"]["ohlc_or_tick_volume_mismatches"], 1)

    def test_missing_bars_and_missing_warmup_remain_inconclusive(self):
        self.request["bars"].pop("M10")
        self.request["requested_to"] = "2026-07-16T00:00:00"
        for entry in [*self.request["entries"], *self.request["bars"].values()]:
            entry["end"] = self.request["requested_to"]
        self.freeze()
        result = self.audit(score_day="2026-07-15")
        self.assertEqual(result["capture_audit"], "INCONCLUSIVE")
        self.assertIn("M10_native_bars_missing", result["unresolved"])
        self.assertIn("H1_warmup_or_scored_bars_incomplete", result["unresolved"])

    def test_empty_interval_needs_independent_source_equality(self):
        self.request["entries"][0]["end"] = "2026-07-15T00:30:00"
        empty = {**self.entry("empty.json", 0), "start": "2026-07-15T00:30:00"}
        self.request["entries"].append(empty)
        self.write_response("empty.json", "tick", [])
        self.freeze()
        self.assertEqual(self.audit()["capture_audit"], "PASS")
        result = audit_capture(self.frozen)
        self.assertEqual(result["capture_audit"], "INCONCLUSIVE")
        self.assertIn("unexplained_empty_tick_intervals", result["unresolved"])

    def test_wrong_source_hash_and_counts_fail(self):
        self.request["entries"][0]["rows"] = 3
        with self.assertRaises(SourceError):
            self.freeze()
        self.request["entries"][0]["rows"] = 4
        self.freeze()
        self.expected_hash = "0" * 64
        self.assertIn("Expected TSV checksum mismatch", self.audit()["errors"])

    def test_numeric_lexemes_duplicate_keys_and_nonfinite_numbers(self):
        path = self.root / "precise.json"
        price = "123456789123456789.123456789012"
        raw = '{"symbol":"XAUUSD_EXN","period":"tick","history":[{"time_ms":"2026.07.15 00:00:00.001","bid":' + price + ',"ask":' + price + '}]}'
        path.write_text(raw)
        rows, _ = read_mcp_history(path, "XAUUSD_EXN", "tick")
        self.assertEqual(str(next(mcp_tick_rows(rows))[1]), price)
        for text in (raw.replace('"bid":', '"bid":1,"bid":'), raw.replace(price, "NaN")):
            path.write_text(text)
            with self.assertRaises(SourceError):
                read_mcp_history(path, "XAUUSD_EXN", "tick")

    def test_cli_replay_is_byte_identical_offline_and_does_not_require_profile(self):
        self.freeze()
        report = self.root / "report.json"
        args = ["--config", str(self.root / "absent.toml"), "audit-capture", "--capture", str(self.frozen),
                "--expected-ticks", str(self.tsv), "--expected-sha256", self.expected_hash, "--report", str(report)]
        with patch("socket.socket", side_effect=AssertionError("Offline audit attempted network access")), redirect_stdout(io.StringIO()):
            self.assertEqual(main(args), 0)
            first = report.read_bytes()
            self.assertEqual(main(args), 0)
        self.assertEqual(first, report.read_bytes())


if __name__ == "__main__":
    unittest.main()
