from __future__ import annotations

import sys
import unittest
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from model_artifact_validator import (
    ModelArtifactValidationError,
    validate_engine_manifest_compatibility,
)
from schema_contract import feature_columns_for_set
from validation_splits import build_time_splits


class ExtremumEngineResearchContractTests(unittest.TestCase):
    def test_point_in_time_features_exclude_final_cycle_facts(self) -> None:
        features = set(feature_columns_for_set("schema_v7_extremum_engine_xgb"))
        self.assertIn("candidate_depth_percent", features)
        self.assertIn("cycle_attempt_index", features)
        for forbidden in (
            "final_depth_percent",
            "cycle_finalized_time",
            "cycle_status",
            "cycle_total_profit_r",
            "simulated_profit_r",
            "target_profit_r",
        ):
            self.assertNotIn(forbidden, features)

    def test_chronological_splits_keep_cycles_in_one_partition(self) -> None:
        rows = []
        for cycle_index in range(12):
            for attempt_index in (1, 2):
                rows.append(
                    {
                        "entry_time": f"2026-01-{cycle_index + 1:02d} 10:0{attempt_index}:00",
                        "symbol": "EURUSD",
                        "engine_timeframe": "PERIOD_M1",
                        "extremum_cycle_id": f"C_{cycle_index + 1}",
                    }
                )
        bundle = build_time_splits(rows, holdout_fraction=0.25, n_splits=2, gap=1)
        self.assertEqual(bundle.metadata["grouping_policy"], "extremum_cycle")

        def cycle_ids(indices: list[int]) -> set[str]:
            return {rows[index]["extremum_cycle_id"] for index in indices}

        self.assertFalse(cycle_ids(bundle.train_indices) & cycle_ids(bundle.holdout_indices))
        for fold in bundle.folds:
            self.assertFalse(cycle_ids(fold.train_indices) & cycle_ids(fold.test_indices))

    def test_old_and_unapproved_artifacts_fail_closed(self) -> None:
        old_manifest = {
            "phase1_schema_version": "6",
            "feature_set_id": "schema_v6_numeric_xgb",
            "engine_id": "",
            "engine_label": "",
            "engine_timeframe": "",
            "runtime_approval": "APPROVED_FOR_MT5_RUNTIME",
        }
        with self.assertRaisesRegex(ModelArtifactValidationError, "incompatible"):
            validate_engine_manifest_compatibility(old_manifest)

        research_manifest = {
            "phase1_schema_version": "7",
            "feature_set_id": "schema_v7_extremum_engine_xgb",
            "engine_id": "1",
            "engine_label": "EXTREMUM_V1",
            "engine_timeframe": "PERIOD_M1",
            "runtime_approval": "RESEARCH_ONLY_NOT_APPROVED",
        }
        with self.assertRaisesRegex(ModelArtifactValidationError, "not approved"):
            validate_engine_manifest_compatibility(research_manifest)

        approved_manifest = dict(research_manifest, runtime_approval="APPROVED_FOR_MT5_RUNTIME")
        validate_engine_manifest_compatibility(approved_manifest)


if __name__ == "__main__":
    unittest.main()
