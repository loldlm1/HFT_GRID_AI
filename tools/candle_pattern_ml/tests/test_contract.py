import tempfile
import unittest
from pathlib import Path

from ..reader import CandleRun, ContractError
from ..research import SelectionPolicy, run_selection
from .fixtures import make_run, mutate


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run = make_run(Path(self.temp.name))

    def test_synthetic_seal_and_separate_ratios(self):
        with CandleRun(self.run) as run:
            report = run_selection(run, SelectionPolicy("ENGULFING", "ALIGNED", allowance=1))
            self.assertEqual(report["decisions"], {"SELECTED": 1})
            self.assertEqual(report["ratios"]["1"]["net_profit"], "4")
            self.assertIsNone(report["ratios"]["2"]["net_profit"])

    def reject_mutation(self, table, field, value, message):
        mutate(self.run, table, lambda rows: rows[0].update({field: value}))
        with self.assertRaisesRegex(ContractError, message):
            with CandleRun(self.run):
                pass

    def test_incomplete_seal(self):
        self.reject_mutation("run_summary.tsv", "value", "999", "Seal count")

    def test_future_atr(self):
        self.reject_mutation("entry_attempts.tsv", "atr_source_time_msc", "3960000", "Non-causal ATR")

    def test_immutable_protection(self):
        self.reject_mutation("outcomes.tsv", "sl", "96", "Submitted protection changed")

    def test_wrong_deadline(self):
        self.reject_mutation("outcomes.tsv", "deadline_msc", "7200000", "Deadline")

    def test_no_invented_fill_deviation(self):
        self.reject_mutation("outcomes.tsv", "fill_deviation_points", "2", "Fill deviation")

    def test_no_censor_as_loss(self):
        self.reject_mutation("outcomes.tsv", "status", "TIME_EXIT", "Non-binary")

    def test_family_is_immutable(self):
        self.reject_mutation("entry_attempts.tsv", "pattern", "HARAMI", "category mismatch")

    def test_context_requires_touch(self):
        self.reject_mutation("entry_attempts.tsv", "context_level", "S1", "Context without")

    def test_no_parity_alias(self):
        self.reject_mutation("trials.tsv", "rr", "3", "identity|cardinality")

    def test_feature_completeness_is_checked(self):
        self.reject_mutation("entry_attempts.tsv", "macro_complete", "1", "Incomplete feature")

    def test_extra_failure_marker_invalidates_seal(self):
        (self.run / "FAILED.txt").write_text("SUMMARY_FLUSH")
        with self.assertRaisesRegex(ContractError, "eight"):
            with CandleRun(self.run):
                pass

    def test_symlink_source_is_rejected(self):
        source = self.run / "outcomes.tsv"
        retained = source.with_suffix(".retained")
        source.rename(retained)
        source.symlink_to(retained)
        with self.assertRaises(ContractError):
            with CandleRun(self.run):
                pass


class SizingContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.run = make_run(Path(self.temp.name), lot_type="EXECUTION_LOT_REFERENCE_BALANCE_PERCENT")

    def manifest_value(self, key, value):
        mutate(self.run, "run_manifest.tsv", lambda rows: next(row for row in rows if row["key"] == key).update(value=value))

    def rejected(self, message):
        with self.assertRaisesRegex(ContractError, message):
            with CandleRun(self.run):
                pass

    def test_reference_schema_preserves_separate_ratio_reports(self):
        with CandleRun(self.run) as run:
            report = run_selection(run, SelectionPolicy("ENGULFING", "ALIGNED"))
            self.assertEqual(report["ratios"]["1"]["net_profit"], "4")
            self.assertIsNone(report["ratios"]["3"]["net_profit"])
            self.assertEqual(run.manifest["schema_version"], "2")

    def test_fixed_schema_records_lots(self):
        self.manifest_value("lot_type", "EXECUTION_LOT_FIXED_SIZE")
        self.manifest_value("lot_size", "1")
        with CandleRun(self.run):
            pass

    def test_fixed_percentage_cannot_masquerade_as_requested_lots(self):
        self.manifest_value("lot_type", "EXECUTION_LOT_FIXED_SIZE")
        self.rejected("Fixed requested volume")

    def test_unknown_schema_is_rejected(self):
        self.manifest_value("schema_version", "3")
        self.rejected("Unsupported Candle schema")

    def test_legacy_schema_cannot_hide_reference_sizing(self):
        self.manifest_value("schema_version", "1")
        self.rejected("Manifest keys")

    def test_missing_lot_mode_is_rejected(self):
        mutate(self.run, "run_manifest.tsv", lambda rows: rows.remove(next(row for row in rows if row["key"] == "lot_type")))
        self.rejected("Manifest keys")

    def test_live_balance_cannot_replace_fixed_reference(self):
        self.manifest_value("reference_balance", "100000")
        self.rejected("fixed reference balance")

    def test_reference_percentage_is_bounded(self):
        self.manifest_value("lot_size", "100.1")
        self.rejected("percentage out of range")

    def test_stop_risk_cannot_exceed_budget(self):
        mutate(self.run, "execution_checks.tsv", lambda rows: rows[0].update(stop_profit="-5.01"))
        self.rejected("exceeds reference risk budget")

    def test_ratio_cannot_change_volume(self):
        mutate(self.run, "trials.tsv", lambda rows: rows[1].update(volume="2"))
        mutate(self.run, "outcomes.tsv", lambda rows: rows[1].update(volume="2"))
        self.rejected("Ratio changed shared execution sizing")

    def test_unavailable_decision_size_is_explicit(self):
        mutate(self.run, "entry_attempts.tsv", lambda rows: rows[0].update(requested_volume=r"\N"))
        with CandleRun(self.run):
            pass

    def test_zero_is_not_an_unavailable_decision_size(self):
        mutate(self.run, "entry_attempts.tsv", lambda rows: rows[0].update(requested_volume="0"))
        self.rejected("Missing requested volume")
