from decimal import Decimal as D
import unittest

from ..feature_contract import FEATURES, percent_b, pivot_zone, sma
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
