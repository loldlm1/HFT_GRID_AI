from __future__ import annotations

import sys
import unittest
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from feature_encoder import FeatureEncoder, MISSING_CATEGORY
from schema_contract import (
    CONTEXT_PREFIXES,
    CONTEXT_TIMEFRAMES,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    SUPPORTED_FEATURE_SET_ID,
    feature_columns_for_set,
)
from validation_splits import build_time_splits


class PivotFractalResearchContractTests(unittest.TestCase):
    def test_feature_set_contains_all_six_contexts_and_no_future_facts(self) -> None:
        features = set(feature_columns_for_set(SUPPORTED_FEATURE_SET_ID))
        for timeframe in CONTEXT_TIMEFRAMES:
            prefix = CONTEXT_PREFIXES[timeframe]
            for slot in range(3):
                self.assertIn(f"{prefix}_structure_{slot}", features)
            for shift in range(6):
                self.assertIn(f"{prefix}_b_percent_{shift}", features)
        self.assertFalse(features & set(FUTURE_ONLY_COLUMNS))
        self.assertNotIn("target_realized_profit", features)

    def test_chronological_splits_keep_window_confluence_together(self) -> None:
        rows = []
        for window_index in range(16):
            for attempt_index in range(2):
                rows.append(
                    {
                        "run_id": "run_1",
                        "symbol": "EURUSD",
                        "window_id": f"window_{window_index:02d}",
                        "trigger_broker_time": (
                            f"2026-01-{window_index + 1:02d} 10:0{attempt_index}:00"
                        ),
                    }
                )
        bundle = build_time_splits(rows, holdout_fraction=0.25, n_splits=2, gap=1)
        self.assertEqual(bundle.metadata["grouping_policy"], "pivot_window_identity")

        def windows(indices: list[int]) -> set[str]:
            return {rows[index]["window_id"] for index in indices}

        self.assertFalse(windows(bundle.train_indices) & windows(bundle.holdout_indices))
        for fold in bundle.folds:
            self.assertFalse(windows(fold.train_indices) & windows(fold.test_indices))

    def test_encoder_handles_unseen_context_tokens_without_mutating_contract(self) -> None:
        train_row = {column: 1.0 for column in MODEL_FEATURE_COLUMNS}
        for column in ("symbol", "pivot_timeframe", "level_id", "direction", "analysis_weekday"):
            train_row[column] = "known"
        for column in MODEL_FEATURE_COLUMNS:
            if "_structure_" in column:
                train_row[column] = "HH"
        encoder = FeatureEncoder.fit([train_row], MODEL_FEATURE_COLUMNS)
        unseen = dict(train_row, symbol="unseen")
        encoded = encoder.transform([unseen])
        self.assertEqual(encoded.matrix.shape[0], 1)
        self.assertIn(MISSING_CATEGORY, encoder.categories["symbol"])
        self.assertEqual(len(encoded.encoded_feature_names), encoded.matrix.shape[1])


if __name__ == "__main__":
    unittest.main()
