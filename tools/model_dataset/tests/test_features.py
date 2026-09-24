from decimal import Decimal as D
import unittest

from ..feature_contract import FEATURES, percent_b, pivot_zone, sma
from .fixtures import NOW, PRICES
from .test_contract import RunFixtureCase


class CalculationTests(unittest.TestCase):
    def test_ordinary_weighted_percent_b(self):
        self.assertEqual(percent_b(D(10), D(0), D(2), D(0), D(10)), D(35))
        self.assertEqual(percent_b(D(12), D(10), D(12), D(0), D(10)), D(115))
        self.assertIsNone(percent_b(D(10), D(0), D(2), D(3), D(3)))

    def test_average_aligns_series_per_shift(self):
        values = list(map(D, range(10)))
        self.assertEqual(sma(values), tuple(map(D, range(2, 8))))
        values[2] = None
        self.assertEqual(sma(values)[:3], (None, None, None))
        self.assertEqual(sma(values)[3:], tuple(map(D, (5, 6, 7))))

    def test_pivot_exact_boundary(self):
        prices = tuple(map(D, (1, 2, 3, 4, 5, 6, 7)))
        self.assertEqual(pivot_zone(D("3.9999999999999999"), prices)[0], "S1_TO_PP")
        self.assertEqual(pivot_zone(D(4), prices), ("AT_PP", D(4), D(4)))
        self.assertEqual(pivot_zone(D(0), prices), ("BELOW_S3", None, D(1)))
        self.assertEqual(pivot_zone(D(8), prices), ("ABOVE_R3", D(7), None))

    def test_registry_contains_no_future_or_old_features(self):
        self.assertTrue(all(f.classification == "CAUSAL_FEATURE" for f in FEATURES.values()))
        self.assertFalse(any(any(term in name for term in ("duration", "binary", "band_width", "stochastic_k_sma")) for name in FEATURES))
        self.assertIn("forming_class", FEATURES)
        self.assertIn("confirmed_event_class", FEATURES)


class SnapshotTests(RunFixtureCase):
    def touch(self, level, sequence, *, selected=True, at=NOW-1000):
        row = self.tables["feature_snapshots.tsv"][0]
        index = ("S3", "S2", "S1", "PP", "R1", "R2", "R3").index(level)
        price = D(PRICES[index])
        role = "SUPPORT" if index <= 3 else "RESISTANCE"
        prefix = "pivot_" + level.lower()
        row.update({prefix + "_touch_time_msc": str(at), prefix + "_touch_sequence": str(sequence), prefix + "_role": role})
        if level == "PP":
            self.tables["macro_windows.tsv"][0].update(pp_role=role, pp_arm_time_msc=str(at-1), pp_arm_bid="101")
        if selected:
            bid = D(row["bid"])
            side = "ABOVE" if bid > price else "BELOW" if bid < price else "AT"
            row.update(tested_level=level, tested_price=str(price), tested_role=role,
                       tested_touch_time_msc=str(at), tested_sequence=str(sequence), tested_age_ms=str(NOW-at),
                       tested_distance_price=str(bid-price), tested_distance_points=str((bid-price)/D(row["point"])),
                       tested_reclaimed="0", tested_gap_cross="0", signal_vs_tested_pivot=side+"_"+role)

    def test_latest_support_and_resistance_context(self):
        self.touch("S3", 1)
        self.touch("R1", 2)
        self.validate()

    def test_simultaneous_gap_uses_outermost_level(self):
        self.touch("S1", 1)
        self.touch("S3", 1)
        self.tables["feature_snapshots.tsv"][0].update(pivot_s3_gap_cross="1", tested_gap_cross="1")
        self.validate()

    def test_inner_level_cannot_replace_outermost_tie(self):
        self.touch("S3", 1)
        self.touch("S1", 1)
        self.reject(lambda t: None)

    def test_selected_copy_cannot_disagree_with_touch(self):
        self.touch("S1", 1)
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(tested_sequence="2"))

    def test_macro_reset_excludes_previous_window_touch(self):
        self.touch("S1", 1, at=int(self.tables["macro_windows.tsv"][0]["open_time_msc"])-1)
        self.reject(lambda t: None)

    def test_pp_requires_prior_departure(self):
        self.touch("PP", 1)
        self.validate()
        self.reject(lambda t: t["macro_windows.tsv"][0].update(pp_arm_time_msc=None))

    def test_untested_level_cannot_claim_reclamation(self):
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(pivot_s1_reclaimed="1"))

    def test_feature_gap_does_not_remove_broker_outcome(self):
        row = self.tables["feature_snapshots.tsv"][0]
        row.update(complete="0", macro_complete="0", macro_stochastic_complete="0", macro_reason="INDICATOR_UNAVAILABLE")
        for name in ("stochastic_k", "stochastic_d"):
            for shift in range(6):
                row[f"macro_{name}_{shift}"] = None
        next(r for r in self.tables["run_summary.tsv"] if r["key"] == "feature_gap_count")["value"] = "1"
        self.assertEqual(self.validate()["counts"]["outcomes.tsv"], 8)

    def test_zero_atr_and_unclipped_percent_b(self):
        for row in self.tables["feature_snapshots.tsv"]:
            for role in ("macro", "micro"):
                for shift in range(6):
                    row[f"{role}_atr_13_{shift}"] = "0"
                    row[f"{role}_atr_13_sma_5_{shift}"] = "0"
                    row[f"{role}_percent_b_{shift}"] = "150"
                    row[f"{role}_percent_b_sma_5_{shift}"] = "150"
        self.validate()

    def test_wrong_sma_rejected(self):
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(macro_percent_b_sma_5_0="51"))

    def test_future_source_rejected(self):
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(macro_source_0_time_msc="9439812980000"))

    def test_wrong_zone_rejected(self):
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(signal_zone="AT_PP"))

    def test_initial_structure_cannot_invent_candidate(self):
        self.reject(lambda t: t["feature_snapshots.tsv"][0].update(forming_class="HH"))
