import csv
import json
import shutil
import unittest
from dataclasses import replace
from datetime import timedelta
from decimal import Decimal

from tools.exness_tick_history.compare import BAR_HEADER, PERIOD_MS, compare_broker, compare_roundtrip, comparison_profile_hash, match_ticks, mcp_ticks, native_ticks, quote_bars, split_capture_interval
from tools.exness_tick_history.archive import SourceError
from tools.exness_tick_history.mt5_export import export_mt5
from tools.exness_tick_history.sanitize import DAY_MS, EPOCH, build_dataset, day_milliseconds, utc_milliseconds
from tools.exness_tick_history.storage import atomic_json, feed_identity, file_hash, object_hash
from tools.exness_tick_history.tests import test_pipeline as fixtures, test_mt5_export as exports


class RoundtripTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PipelineTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.temp.cleanup)
        self.profile = self.fixture.profile
        rows = [self.fixture.row(), self.fixture.row(bid="1.001", ask="1.002"), self.fixture.row(ms="002")]
        inv = self.fixture.seed(rows)
        build_dataset(self.profile, inv, "input")
        self.manifest = export_mt5(self.profile, "input", "export", exports.specification(self.profile), exports.clock_map())
        self.native = self.profile.data_root / "native.tsv"
        shutil.copyfile(self.profile.data_root / "exports/export/ticks-000000.tsv", self.native)

    def evidence(self):
        evidence = {"schema_version": 1, "operator_verified": True, "complete": True,
                    "export_manifest_sha256": self.manifest["manifest_sha256"],
                    "native_specification_sha256": self.manifest["specification_sha256"],
                    "custom_symbol": self.manifest["custom_symbol"], "native_ticks_sha256": file_hash(self.native), "native_bars": {}}
        for period, milliseconds in PERIOD_MS.items():
            path = self.profile.data_root / (period + ".tsv")
            with path.open("w", newline="") as stream:
                writer = csv.writer(stream, delimiter="\t")
                writer.writerow(BAR_HEADER)
                for stamp, *ohlc in quote_bars(native_ticks(self.native), milliseconds):
                    dt = EPOCH + timedelta(milliseconds=stamp)
                    writer.writerow([f"{dt:%Y.%m.%d}", f"{dt:%H:%M:%S}", *ohlc, 3, 0, 1])
            evidence["native_bars"][period] = {"path": path.name, "sha256": file_hash(path)}
        return evidence

    def compare(self, evidence=None):
        return compare_roundtrip(self.profile, "export", self.native, evidence=evidence, evidence_root=self.profile.data_root)

    def test_exact_ticks_need_native_metadata_and_bars(self):
        result = self.compare()
        self.assertEqual(result["tick_equality"], "PASS")
        self.assertEqual(result["mt5_round_trip"], "INCONCLUSIVE")
        self.assertEqual(self.compare(self.evidence())["mt5_round_trip"], "PASS")

    def test_deleted_duplicated_reversed_tie_and_perturbed_ticks_fail(self):
        original = self.native.read_text().splitlines(keepends=True)
        cases = [original[:-1], original + original[-1:], [original[0], original[2], original[1], original[3]],
                 [original[0], original[1].replace("00.001", "00.000"), *original[2:]],
                 [original[0], original[1].replace("1.000", "0.999"), *original[2:]]]
        for lines in cases:
            with self.subTest(lines=lines):
                self.native.write_text("".join(lines))
                self.assertEqual(self.compare()["tick_equality"], "FAIL")

    def test_precision_loss_is_inconclusive_and_wrong_spec_fails(self):
        evidence = self.evidence()
        evidence["native_specification_sha256"] = "wrong"
        self.assertEqual(self.compare(evidence)["mt5_round_trip"], "FAIL")
        self.native.write_text(self.native.read_text().replace(".001\t", "\t").replace(".002\t", "\t"))
        self.assertEqual(self.compare()["tick_equality"], "INCONCLUSIVE")

    def test_missing_or_changed_native_bars_cannot_pass(self):
        evidence = self.evidence()
        (self.profile.data_root / "M10.tsv").write_text("corrupted")
        self.assertEqual(self.compare(evidence)["mt5_round_trip"], "FAIL")


class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PipelineTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.temp.cleanup)
        self.profile = replace(self.fixture.profile,
                               instrument=replace(self.fixture.profile.instrument, account_mode="demo", server_alias="fixture", feed_mapping_status="operator_confirmed"),
                               comparison_status="PINNED", comparison_provenance={"name": "authored-fixture", "pinned_at_utc": "2026-09-04T00:00:00.000Z",
                               "pilot_dates": ["2026-08-25"], "rationale": "Independent authored test fixture"})
        self.fixture.profile = self.profile
        self.day = "2026-09-03"
        self.start = day_milliseconds(self.day)
        ticks = []
        initial = day_milliseconds("2026-09-01")
        for hour in range(56):
            stamp = initial + hour * 3600000 + 1
            ticks.append((stamp, Decimal("100") + Decimal(hour) / 1000, Decimal("100.002") + Decimal(hour) / 1000))
        ticks.insert(49, (ticks[48][0], Decimal("100.049"), Decimal("100.051")))
        self.all_ticks = ticks
        rows = [["exness", "XAUUSD", (EPOCH + timedelta(milliseconds=stamp)).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3] + "Z", str(bid), str(ask)] for stamp, bid, ask in ticks]
        inv = self.fixture.seed(rows, start="2026-09-01", end="2026-09-04", granularity="month")
        build_dataset(self.profile, inv, "input")
        self.spec, self.clock = exports.specification(self.profile), exports.clock_map()
        self.reference_path = self.profile.data_root / "reference.json"
        self.native = self.profile.data_root / "broker.tsv"
        self.day_ticks = [tick for tick in ticks if self.start <= tick[0] < self.start + DAY_MS]
        self.write_ticks(self.native, self.day_ticks)
        self.reference = {"schema_version": 1, "feed_sha256": object_hash(feed_identity(self.profile)), "operator_verified": True,
                          "all_quotes_verified": True, "terminal_build": 6182, "clock": self.clock, "specification": self.spec,
                          "day": self.day, "captured_at_utc": "2026-09-05T00:00:00.000Z", "purpose": "pilot",
                          "selection_frozen": True, "selection_reason": "Authored deterministic fixture",
                          "comparison_profile_sha256": comparison_profile_hash(self.profile), "clock_alignment_verified": True,
                          "unexplained_clock_offset_seconds": 0, "ticks": [], "bars": {}}
        self.write_bars(self.reference, ticks)
        self.refresh_reference()

    def write_ticks(self, path, ticks):
        from tools.exness_tick_history.mt5_export import TICK_HEADER
        with path.open("w", encoding="ascii") as stream:
            stream.write(TICK_HEADER)
            for stamp, bid, ask in ticks:
                dt = EPOCH + timedelta(milliseconds=stamp)
                stream.write(f"{dt:%Y.%m.%d}\t{dt:%H:%M:%S}.{stamp % 1000:03d}\t{bid}\t{ask}\t0\t0\n")

    def write_bars(self, ref, ticks):
        for period, milliseconds in PERIOD_MS.items():
            path = self.profile.data_root / (period + ".tsv")
            with path.open("w", newline="") as stream:
                writer = csv.writer(stream, delimiter="\t")
                writer.writerow(BAR_HEADER)
                for stamp, *ohlc in quote_bars(ticks, milliseconds):
                    dt = EPOCH + timedelta(milliseconds=stamp)
                    writer.writerow([f"{dt:%Y.%m.%d}", f"{dt:%H:%M:%S}", *ohlc, 1, 0, 2])
            ref["bars"][period] = {"path": path.name, "sha256": file_hash(path)}

    def refresh_reference(self):
        self.reference["ticks"] = [{"path": self.native.name, "sha256": file_hash(self.native), "format": "native_tsv", "rows": len(list(native_ticks(self.native))),
                                    "start_broker_msc": self.start, "end_broker_msc": self.start + DAY_MS, "complete": True}]
        atomic_json(self.reference_path, self.reference)

    def compare(self, **kwargs):
        return compare_broker(self.profile, "input", self.reference_path, **kwargs)

    def test_exact_metrics_and_full_native_evidence_pass(self):
        result = self.compare()
        self.assertEqual(result["matched_source_fraction"], 1)
        self.assertEqual(result["unmatched_broker"], 0)
        self.assertEqual(set(result["gates"].values()), {"PASS"})
        self.assertEqual(result["broker_comparison"], "INCONCLUSIVE")
        manifest = export_mt5(self.profile, "input", "export", self.spec, self.clock)
        native = self.profile.data_root / "all-native.tsv"
        self.write_ticks(native, self.all_ticks)
        evidence = {"schema_version": 1, "operator_verified": True, "complete": True,
                    "export_manifest_sha256": manifest["manifest_sha256"], "native_specification_sha256": manifest["specification_sha256"],
                    "custom_symbol": manifest["custom_symbol"], "native_ticks_sha256": file_hash(native), "native_bars": self.reference["bars"]}
        rt = compare_roundtrip(self.profile, "export", native, evidence=evidence, evidence_root=self.profile.data_root)
        self.assertEqual(rt["mt5_round_trip"], "PASS")
        self.assertEqual(self.compare(roundtrip=rt)["broker_comparison"], "PASS")

    def test_one_broker_tick_cannot_match_multiple_source_ticks(self):
        tick = (1, Decimal("1"), Decimal("2"))
        pairs = list(match_ticks([tick, tick, tick], [tick], 500))
        self.assertEqual(sum(a is not None and b is not None for a, b in pairs), 1)
        self.assertEqual(sum(b is None for a, b in pairs), 2)

    def test_hour_shift_missing_segment_and_spread_change_fail(self):
        cases = [[(stamp + 3600000, bid, ask) for stamp, bid, ask in self.day_ticks], self.day_ticks[:-1],
                 [(stamp, bid, ask + Decimal("0.01")) for stamp, bid, ask in self.day_ticks]]
        for ticks in cases:
            with self.subTest(ticks=ticks):
                self.write_ticks(self.native, ticks)
                self.refresh_reference()
                self.assertEqual(self.compare()["broker_comparison"], "FAIL")

    def test_reversed_equal_time_group_fails_even_with_small_price_errors(self):
        ticks = self.day_ticks.copy()
        ticks[0], ticks[1] = ticks[1], ticks[0]
        self.write_ticks(self.native, ticks)
        self.refresh_reference()
        result = self.compare()
        self.assertEqual(result["reversed_equal_time_groups"], 1)
        self.assertEqual(result["gates"]["equal_time_order"], "FAIL")

    def test_wrong_feed_unpinned_profile_and_tuned_acceptance_day(self):
        self.reference["feed_sha256"] = "wrong"
        atomic_json(self.reference_path, self.reference)
        self.assertEqual(self.compare()["broker_comparison"], "FAIL")
        self.reference["feed_sha256"] = object_hash(feed_identity(self.profile))
        atomic_json(self.reference_path, self.reference)
        result = compare_broker(replace(self.profile, comparison_status="PROPOSED"), "input", self.reference_path)
        self.assertEqual(result["broker_comparison"], "INCONCLUSIVE")
        self.reference["purpose"] = "winter"
        atomic_json(self.reference_path, self.reference)
        profile = replace(self.profile, comparison_provenance={**self.profile.comparison_provenance, "pilot_dates": [self.day]})
        result = compare_broker(profile, "input", self.reference_path)
        self.assertIn("acceptance_day_used_for_profile_tuning", result["unresolved"])

    def test_mcp_numeric_lexemes_and_limit_sized_response(self):
        path = self.profile.data_root / "ticks.jsonl"
        with path.open("w") as stream:
            for stamp, bid, ask in self.day_ticks:
                dt = EPOCH + timedelta(milliseconds=stamp)
                stream.write(json.dumps({"time_ms": f"{dt:%Y.%m.%d %H:%M:%S}.{stamp % 1000:03d}", "bid": str(bid), "ask": str(ask)}) + "\n")
        self.assertEqual(list(mcp_ticks(path)), self.day_ticks)
        entry = self.reference["ticks"][0]
        entry.update(path=path.name, sha256=file_hash(path), format="mcp_jsonl", limit=len(self.day_ticks), millisecond_and_all_quotes_verified=True)
        atomic_json(self.reference_path, self.reference)
        result = self.compare()
        self.assertEqual(result["broker_comparison"], "INCONCLUSIVE")
        self.assertIn("potentially_truncated_mcp_capture", result["unresolved"])

    def test_empty_capture_is_inconclusive(self):
        self.write_ticks(self.native, [])
        self.refresh_reference()
        self.assertEqual(self.compare()["broker_comparison"], "INCONCLUSIVE")

    def test_interval_subdivision_preserves_boundary_groups(self):
        self.assertEqual(split_capture_interval(1000, 2000, 100, 100), [(1000, 1500), (1500, 2000)])
        self.assertEqual(split_capture_interval(1000, 1500, 99, 100), [(1000, 1500)])
        with self.assertRaises(SourceError):
            split_capture_interval(1000, 1001, 100, 100)

    def test_incomplete_interval_and_reference_count_cannot_pass(self):
        for field, value in (("start_broker_msc", self.start + 1), ("rows", 100000)):
            self.refresh_reference()
            self.reference["ticks"][0][field] = value
            atomic_json(self.reference_path, self.reference)
            self.assertEqual(self.compare()["broker_comparison"], "INCONCLUSIVE")

    def test_dst_schedule_keeps_us_uk_mismatch_weeks_explicit(self):
        from tools.exness_tick_history.report import seasonal_report, seasonal_schedule
        schedule = seasonal_schedule(2026)
        self.assertEqual((schedule["winter"], schedule["summer"]), ("2026-01-14", "2026-07-15"))
        self.assertEqual(schedule["transition_days"]["us_spring"]["after"], "2026-03-09")
        self.assertEqual(schedule["transition_days"]["uk_spring"]["before"], "2026-03-27")
        self.assertEqual(schedule["transition_days"]["uk_autumn"]["after"], "2026-10-26")
        self.assertEqual(schedule["transition_days"]["us_autumn"]["before"], "2026-10-30")
        self.assertEqual(seasonal_report(self.profile, 2026, [])["seasonal_acceptance"], "INCONCLUSIVE")
