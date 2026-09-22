import unittest

from ..reader import ContractError
from ..research import Clause, SelectionPolicy, select_entries


def entry(identity, clock, *, window=0, pattern="HARAMI", category="ALIGNED", parent=None, feature="1"):
    return {"attempt_id": identity, "run_id": "run", "entry_time_msc": clock, "sequence": clock,
            "entry_macro_open_time_msc": window, "macro_seconds": 3600, "pattern": pattern,
            "category": category, "entry_type": "REENTRY" if parent else "ORIGINAL",
            "parent_attempt_id": parent, "atr_1": feature}


class SelectionTests(unittest.TestCase):
    def selected(self, rows, **kwargs):
        return [row["attempt_id"] for row, reason in select_entries(rows, SelectionPolicy("HARAMI", "ALIGNED", **kwargs)) if reason == "SELECTED"]

    def test_first_n_includes_reentry_and_resets_by_macro_bar(self):
        rows = [entry("a", 1), entry("b", 2, parent="a"), entry("c", 3), entry("d", 4, window=3600000)]
        self.assertEqual(self.selected(rows, allowance=2), ["a", "b", "d"])
        self.assertEqual(self.selected(rows, allowance=0), ["a", "b", "c", "d"])

    def test_family_and_direction_never_share_budget(self):
        rows = [entry("other-family", 1, pattern="ENGULFING"), entry("opposite", 2, category="OPPOSED"), entry("a", 3)]
        self.assertEqual(self.selected(rows, allowance=1), ["a"])

    def test_type_and_node_filters_precede_allowance(self):
        rows = [entry("a", 1, feature="0"), entry("b", 2, parent="a"), entry("c", 3)]
        self.assertEqual(self.selected(rows, allowance=1, entry_type="ORIGINAL", clauses=(Clause("atr_1", "gt", "0"),)), ["c"])

    def test_skipped_parent_cannot_authorize_child_in_later_window(self):
        rows = [entry("a", 1), entry("b", 2), entry("child", 3, window=3600000, parent="b")]
        self.assertEqual(self.selected(rows, allowance=1, mode="STRATEGY"), ["a"])
        self.assertEqual(self.selected(rows, allowance=1, mode="ANALYSIS"), ["a", "child"])

    def test_reentries_only_is_analysis(self):
        rows = [entry("a", 1), entry("child", 2, parent="a")]
        self.assertEqual(self.selected(rows, entry_type="REENTRY", allowance=1), ["child"])
        with self.assertRaises(ContractError):
            SelectionPolicy("HARAMI", "ALIGNED", entry_type="REENTRY", mode="STRATEGY")

    def test_rejected_does_not_consume_slot(self):
        denied = entry("denied", 0)
        denied["entry_time_msc"] = None
        self.assertEqual(self.selected([denied, entry("entered", 1)], allowance=1), ["entered"])

    def test_outcomes_cannot_be_node_conditions(self):
        for field in ("binary_label", "status", "net_profit", "deadline_msc", "exit_time_msc", "rr"):
            with self.subTest(field=field), self.assertRaises(ContractError):
                Clause(field, "eq", "1")

    def test_duplicate_or_reversed_input_is_rejected(self):
        with self.assertRaisesRegex(ContractError, "unique ordered"):
            self.selected([entry("b", 2), entry("a", 1)])
