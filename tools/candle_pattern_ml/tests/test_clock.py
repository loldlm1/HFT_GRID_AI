import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfoNotFoundError

from ..clock import analysis_clock
from ..reader import CandleRun, ContractError
from ..research import SelectionPolicy, run_selection
from ..schema_contract import LEGACY_TABLE_COLUMNS, TABLE_COLUMNS, write_mql_header
from .fixtures import make_clock_run, mutate


def milliseconds(value):
    instant = datetime.fromisoformat(value).replace(tzinfo=timezone.utc)
    delta = instant - datetime(1970, 1, 1, tzinfo=timezone.utc)
    return (delta.days * 86400 + delta.seconds) * 1000 + delta.microseconds // 1000


class ClockContractTests(unittest.TestCase):
    def test_seasonal_open_and_mismatch_weeks_for_every_symbol(self):
        cases = (("2026-01-14", "14:30", -60), ("2026-07-15", "13:30", 0),
                 ("2026-03-16", "13:30", 0), ("2026-10-28", "13:30", 0))
        for symbol in ("EURUSD", "XAUUSD", "EURUSD_Exness_2015", "XAUUSD_Exness_2015"):
            for date, raw_hour, offset in cases:
                with self.subTest(symbol=symbol, date=date), tempfile.TemporaryDirectory() as temp:
                    path = make_clock_run(Path(temp), decision=f"{date}T{raw_hour}:00.123", symbol=symbol)
                    with CandleRun(path) as run:
                        event = next(run.rows("signal_events.tsv"))
                        self.assertEqual(int(event["decision_analysis_time_msc"]), milliseconds(f"{date}T13:30:00.123"))
                        self.assertEqual(int(event["decision_analysis_offset_minutes"]), offset)
                        self.assertEqual(run_selection(run, SelectionPolicy("ENGULFING", "ALIGNED", allowance=1))["decisions"], {"SELECTED": 1})

    def test_exact_utc_transitions_preserve_milliseconds(self):
        cases = (("2026-03-08T06:59:59.999", -60), ("2026-03-08T07:00:00.000", 0),
                 ("2026-11-01T05:59:59.999", 0), ("2026-11-01T06:00:00.000", -60),
                 ("2007-03-11T06:59:59.999", -60), ("2007-03-11T07:00:00.000", 0))
        for date, offset in cases:
            with self.subTest(date=date):
                raw = milliseconds(date)
                self.assertEqual(analysis_clock(raw, "EXNESS_SESSION"), (raw + offset * 60000, offset))

    def test_shift_can_cross_day_month_and_year(self):
        for raw, expected in (("2026-01-01T00:30:00.789", "2025-12-31T23:30:00.789"),
                              ("2026-02-01T00:30:00.789", "2026-01-31T23:30:00.789")):
            self.assertEqual(analysis_clock(milliseconds(raw), "EXNESS_SESSION")[0], milliseconds(expected))

    def test_fixed_mode_preserves_broker_clock_and_sizing(self):
        for lot_type in ("EXECUTION_LOT_FIXED_SIZE", "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT"):
            with self.subTest(lot_type=lot_type), tempfile.TemporaryDirectory() as temp:
                with CandleRun(make_clock_run(Path(temp), session="FIXED_TIME_SESSIONS", lot_type=lot_type)) as run:
                    event = next(run.rows("signal_events.tsv"))
                    self.assertEqual(event["decision_time_msc"], event["decision_analysis_time_msc"])
                    self.assertEqual(event["decision_analysis_offset_minutes"], "0")

    def test_dst_jump_and_fold_do_not_change_duration_or_selection(self):
        for instant, analysis_duration in (("2026-03-08T06:59:40.123", 3640000),
                                           ("2026-11-01T05:59:40.123", -3560000)):
            with self.subTest(instant=instant), tempfile.TemporaryDirectory() as temp:
                with CandleRun(make_clock_run(Path(temp), decision=instant)) as run:
                    row = next(run.rows("outcomes.tsv"))
                    self.assertEqual(int(row["deadline_msc"]) - int(row["entry_time_msc"]), 3600000)
                    self.assertEqual(int(row["exit_time_msc"]) - int(row["entry_time_msc"]), 40000)
                    self.assertEqual(int(row["exit_analysis_time_msc"]) - int(row["entry_analysis_time_msc"]), analysis_duration)
                    self.assertEqual(run_selection(run, SelectionPolicy("ENGULFING", "ALIGNED", allowance=1))["decisions"], {"SELECTED": 1})

    def test_clock_corruption_and_false_provenance_are_rejected(self):
        cases = (
            ("signal_events.tsv", "decision_analysis_time_msc", "1", "Analysis clock mismatch"),
            ("entry_attempts.tsv", "decision_analysis_offset_minutes", "0", "Analysis clock mismatch"),
            ("entry_attempts.tsv", "decision_analysis_time_msc", r"\N", "Missing analysis clock"),
            ("entry_attempts.tsv", "pivot_s1_touch_analysis_time_msc", "1", "Clock null mismatch"),
            ("outcomes.tsv", "exit_analysis_time_msc", "1.5", "Invalid integer"),
            ("manifest", "analysis_calendar", "UK", "Clock manifest mismatch"),
            ("manifest", "broker_time_basis", "UTC_PLUS_2", "Clock manifest mismatch"),
            ("manifest", "analysis_clock_policy", "EXNESS_NEW_YORK_V2", "Clock manifest mismatch"),
            ("manifest", "broker_session", "UNKNOWN", "Unknown broker session"),
            ("run_summary.tsv", "last_analysis_time_msc", "1", "Analysis clock mismatch"),
        )
        for table, key, value, error in cases:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as temp:
                path = make_clock_run(Path(temp))
                if table in {"manifest", "run_summary.tsv"}:
                    mutate(path, "run_manifest.tsv" if table == "manifest" else table,
                           lambda rows: next(row for row in rows if row["key"] == key).update(value=value))
                else:
                    mutate(path, table, lambda rows: rows[0].update({key: value}))
                with self.assertRaisesRegex(ContractError, error), CandleRun(path):
                    pass

    def test_clock_version_cannot_use_legacy_headers(self):
        with tempfile.TemporaryDirectory() as temp:
            path = make_clock_run(Path(temp))
            file = path / "signal_events.tsv"
            lines = ["\t".join(line.split("\t")[:len(LEGACY_TABLE_COLUMNS[file.name])]) for line in file.read_text().splitlines()]
            file.write_text("\n".join(lines) + "\n")
            with self.assertRaisesRegex(ContractError, "Header mismatch"), CandleRun(path):
                pass

    def test_unsupported_historical_coverage_is_explicit(self):
        for date in ("2006-12-31T23:59:59", "2100-01-01T00:00:00"):
            with self.assertRaisesRegex(ValueError, "coverage"):
                analysis_clock(milliseconds(date), "EXNESS_SESSION")

    def test_missing_timezone_database_does_not_break_fixed_mode(self):
        raw = milliseconds("2026-01-14T14:30:00")
        with patch("tools.candle_pattern_ml.clock.ZoneInfo", side_effect=ZoneInfoNotFoundError):
            self.assertEqual(analysis_clock(raw, "FIXED_TIME_SESSIONS"), (raw, 0))
            with self.assertRaisesRegex(ValueError, "timezone database unavailable"):
                analysis_clock(raw, "EXNESS_SESSION")

    def test_summary_clock_requires_integer_milliseconds(self):
        with tempfile.TemporaryDirectory() as temp:
            path = make_clock_run(Path(temp))
            mutate(path, "run_summary.tsv", lambda rows: next(row for row in rows if row["key"] == "last_analysis_offset_minutes").update(value="-6_0"))
            with self.assertRaisesRegex(ContractError, "Invalid clock integer"), CandleRun(path):
                pass

    def test_generated_header_matches_and_retains_all_legacy_columns(self):
        with tempfile.TemporaryDirectory() as temp:
            generated = Path(temp) / "schema.mqh"
            write_mql_header(generated)
            source = Path(__file__).resolve().parents[3] / "services/candle_pattern/schema.mqh"
            self.assertEqual(generated.read_bytes(), source.read_bytes())
        for filename, columns in LEGACY_TABLE_COLUMNS.items():
            self.assertEqual(TABLE_COLUMNS[filename][:len(columns)], columns)


if __name__ == "__main__":
    unittest.main()
