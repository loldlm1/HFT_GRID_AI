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
