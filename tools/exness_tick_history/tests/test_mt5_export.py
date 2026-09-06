import copy
import unittest
from decimal import Decimal

from tools.exness_tick_history.archive import SourceError
from tools.exness_tick_history.mt5_export import ClockMap, compatible_quote, export_mt5, validate_specification
from tools.exness_tick_history.sanitize import build_dataset, utc_milliseconds
from tools.exness_tick_history.storage import feed_identity, object_hash
from tools.exness_tick_history.tests import test_pipeline as fixtures


def specification(profile):
    return {"schema_version": 1, "operator_verified": True, "evidence_id": "authored-test-fixture",
            "feed_sha256": object_hash(feed_identity(profile)), "broker_symbol": profile.instrument.broker_symbol,
            "captured_at_utc": "2026-09-05T00:00:00.000Z", "existing_symbols": [profile.instrument.broker_symbol],
            "properties": {"digits": 3, "point": "0.001", "tick_size": "0.001", "tick_value": "0.1", "chart_mode": "bid",
                           "contract_size": "100", "currency_base": "XAU", "currency_profit": "USD", "currency_margin": "USD",
                           "calculation_mode": "CFD", "volume_min": "0.01", "volume_max": "100", "volume_step": "0.01",
                           "margin_initial": "0", "margin_maintenance": "0", "stops_level": 0, "freeze_level": 0,
                           "quote_sessions": [{"weekday": 1, "from_seconds": 0, "to_seconds": 86400}],
                           "trade_sessions": [{"weekday": 1, "from_seconds": 0, "to_seconds": 86400}]}}


def clock_map():
    return {"schema_version": 1, "operator_verified": True, "evidence_id": "authored-test-clock",
            "periods": [{"start_utc": "2015-01-01T00:00:00.000Z", "end_utc": "2027-01-01T00:00:00.000Z", "offset_seconds": 0}]}


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PipelineTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.temp.cleanup)
        self.profile = self.fixture.profile
        self.spec = specification(self.profile)
        self.clock = clock_map()

    def build(self, rows):
        inv = self.fixture.seed(rows)
        return build_dataset(self.profile, inv, "input")

    def test_six_fields_and_unsplit_equal_time_groups(self):
        self.build([self.fixture.row(), self.fixture.row(), self.fixture.row(bid="1.001", ask="1.002"), self.fixture.row(ms="002")])
        result = export_mt5(self.profile, "input", "export", self.spec, self.clock, chunk_rows=2)
        self.assertEqual([chunk["rows"] for chunk in result["chunks"]], [3, 1])
        self.assertLess(result["chunks"][0]["last_mapped_msc"], result["chunks"][1]["first_mapped_msc"])
        text = (self.profile.data_root / "exports/export/ticks-000000.tsv").read_text()
        self.assertIn("2026.09.01\t00:00:00.001\t1.000\t1.001\t0\t0\n", text)
        self.assertEqual(result["format"]["shift"], 0)
        self.assertEqual(export_mt5(self.profile, "input", "export", self.spec, self.clock, chunk_rows=2), result)

    def test_specification_and_historical_grid_fail_closed(self):
        for key, value in (("tick_size", "0"), ("point", "0.01"), ("digits", True), ("chart_mode", "last")):
            with self.subTest(key=key), self.assertRaises(SourceError):
                bad = copy.deepcopy(self.spec)
                bad["properties"][key] = value
                validate_specification(bad, self.profile)
        with self.assertRaises(SourceError):
            compatible_quote(Decimal("1.0001"), Decimal("1.001"), self.spec)
        self.spec["properties"]["tick_size"] = "0.005"
        with self.assertRaises(SourceError):
            compatible_quote(Decimal("1.001"), Decimal("1.005"), self.spec)

    def test_exact_zero_margin_and_boolean_schema_rejection(self):
        self.spec["properties"]["margin_initial"] = "0.000"
        validate_specification(self.spec, self.profile)
        self.spec["schema_version"] = True
        with self.assertRaises(SourceError):
            validate_specification(self.spec, self.profile)

    def test_clock_is_explicit_reversible_and_covers_input(self):
        self.clock["periods"][0]["offset_seconds"] = 7200
        mapping = ClockMap.parse(self.clock)
        stamp = utc_milliseconds("2026-03-08 01:59:59.999Z")
        self.assertEqual(mapping.forward(stamp), stamp + 7200000)
        self.assertEqual(mapping.inverse(mapping.forward(stamp)), stamp)
        with self.assertRaises(SourceError):
            mapping.forward(0)
        self.clock["operator_verified"] = False
        with self.assertRaises(SourceError):
            ClockMap.parse(self.clock)

    def test_fall_back_ambiguity_and_name_collision_block(self):
        raw = clock_map()
        raw["periods"] = [{"start_utc": "2026-01-01T00:00:00.000Z", "end_utc": "2026-10-25T01:00:00.000Z", "offset_seconds": 7200},
                          {"start_utc": "2026-10-25T01:00:00.000Z", "end_utc": "2027-01-01T00:00:00.000Z", "offset_seconds": 3600}]
        with self.assertRaises(SourceError):
            ClockMap.parse(raw)
        self.build([self.fixture.row()])
        for name in ("XAUUSD", "GOLD_CUSTOM"):
            with self.assertRaises(SourceError):
                export_mt5(self.profile, "input", "export", self.spec, self.clock, custom_symbol=name)
