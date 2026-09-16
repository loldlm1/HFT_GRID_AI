from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

import duckdb

MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from build_dataset import (
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_GROUPS,
    DEEP_PARENT_LONG_TABLE,
    ELIGIBLE_DEEP_TRIALS_TABLE,
    ELIGIBLE_H1_TRIALS_TABLE,
    H1_LANE_LONG_TABLE,
    H1_LANE_WIDE_TABLE,
    _typed_expression,
    create_dataset_tables,
    create_raw_tables,
)
from feature_encoder import FeatureEncoder, MISSING_CATEGORY
from model_config import (
    DEEP_FEATURE_ABLATIONS,
    FEATURE_ABLATIONS,
    H1_FEATURE_ABLATIONS,
    feature_ablations_for_set,
    model_feature_columns_for_set,
    training_table_for_set,
)
from research_test_support import build_fixture_dataset, copy_run_with_id
from schema_contract import (
    DEEP_FEATURE_SET_ID,
    DEEP_SIGNAL_FEATURE_COLUMNS,
    DEEP_MODEL_FEATURE_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    H1_FEATURE_SET_ID,
    H1_MODEL_FEATURE_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    SUPPORTED_FEATURE_SET_ID,
    TABLE_COLUMNS,
    feature_columns_for_set,
    validate_run,
    validate_runs,
)
from train_model import TrainingError, load_training_rows, train_candidate
from validation_splits import _purge_shared_events, build_time_splits, origin_balanced_weights

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v14_hft_deep_pivot_features"


class PivotFractalV14ResearchContractTests(unittest.TestCase):
    def test_shared_deep_event_purges_all_training_parents_ratios_and_duplicate_runs(self) -> None:
        event = {"symbol": "EURUSD", "deep_timeframe": "PERIOD_M15",
                 "active_deep_bar_open_broker_time": "2026.01.12 10:15:00", "level_id": "PP"}
        rows = [dict(event, deep_event_id=f"run_{run}_event", run_id=run,
                     origin_id=parent, parent_direction=direction, tp_r_multiple=ratio)
                for run in ("a", "b") for parent, direction in (("old_bar", "BUY"), ("new_bar", "SELL"))
                for ratio in (1, 2, 3)]
        rows.append(dict(event, deep_event_id="different_level", level_id="S1"))
        kept = _purge_shared_events(rows, list(range(12)) + [12], [9, 10, 11])
        self.assertEqual(kept, [12])

    def test_shared_holdout_events_cannot_enter_any_model_selection_fold(self) -> None:
        rows = []
        start = datetime(2026, 1, 1)
        for day in range(24):
            time = start + timedelta(days=day)
            for ratio in (1, 2, 3):
                rows.append({"deep_event_id": f"event_{day}", "origin_id": f"origin_{day}",
                             "symbol": "EURUSD", "deep_timeframe": "PERIOD_M15", "level_id": "PP",
                             "active_deep_bar_open_broker_time": time,
                             "research_group_id": f"macro_{day}", "tp_r_multiple": ratio,
                             "declared_broker_time": time, "terminal_broker_time": time + timedelta(hours=1)})
        for index in (21, 66):
            for ratio in (1, 2, 3):
                rows.append(dict(rows[index], research_group_id="macro_3", origin_id="origin_3",
                                 deep_event_id=f"duplicate_run_{index}", tp_r_multiple=ratio))
        bundle = build_time_splits(rows, n_splits=3)
        def identities(indices: list[int]) -> set[tuple]:
            return {(rows[index]["symbol"], rows[index]["deep_timeframe"],
                     rows[index]["active_deep_bar_open_broker_time"], rows[index]["level_id"])
                    for index in indices}
        holdout = identities(bundle.holdout_indices)
        self.assertFalse(holdout & identities(bundle.train_indices))
        for fold in bundle.folds:
            self.assertFalse(identities(fold.train_indices) & identities(fold.test_indices))
            self.assertFalse(holdout & identities(fold.train_indices + fold.test_indices))

    def test_builder_registry_is_exhaustive_and_disjoint(self) -> None:
        schema_columns = {column for columns in TABLE_COLUMNS.values() for column in columns}
        self.assertEqual(set(COLUMN_TYPE_BY_NAME), schema_columns)
        self.assertEqual(
            sum(len(columns) for columns in COLUMN_TYPE_GROUPS.values()),
            len(schema_columns),
        )
        self.assertEqual(COLUMN_TYPE_BY_NAME["block_source"], "VARCHAR")
        with self.assertRaisesRegex(RuntimeError, "lacks an explicit dataset type"):
            _typed_expression("future_unregistered_column")

    def test_feature_sets_are_explicitly_separated(self) -> None:
        self.assertEqual(feature_columns_for_set(SUPPORTED_FEATURE_SET_ID), H1_MODEL_FEATURE_COLUMNS)
        self.assertEqual(feature_columns_for_set(H1_FEATURE_SET_ID), H1_MODEL_FEATURE_COLUMNS)
        self.assertEqual(feature_columns_for_set(DEEP_FEATURE_SET_ID), DEEP_MODEL_FEATURE_COLUMNS)
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertFalse(set(DEEP_MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertNotIn("h1_structural_lifecycle_seconds", DEEP_MODEL_FEATURE_COLUMNS)
        self.assertNotIn("terminal_status", DEEP_MODEL_FEATURE_COLUMNS)

    def test_typed_loader_preserves_parent_age_and_ratio_as_integers(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        connection = duckdb.connect(":memory:")
        try:
            counts = create_raw_tables(connection, [validation])
            self.assertEqual(counts["deep_pivot_parent_links"], 3)
            self.assertEqual(
                connection.execute(
                    "SELECT typeof(m10_parent_age_seconds), "
                    "typeof(parent_tp_r_multiple) FROM deep_pivot_parent_links LIMIT 1"
                ).fetchone(),
                ("BIGINT", "BIGINT"),
            )
        finally:
            connection.close()

    def test_encoder_keeps_unseen_categories_explicit(self) -> None:
        rows = [
            {"symbol": "EURUSD", "entry_policy": "STRUCTURAL", "tp_r_multiple": 1.0},
            {"symbol": "XAUUSD", "entry_policy": "MIDPOINT_50", "tp_r_multiple": 3.0},
        ]
        encoder = FeatureEncoder.fit(
            rows,
            ("symbol", "entry_policy", "tp_r_multiple"),
            ("symbol", "entry_policy"),
        )
        transformed = encoder.transform(
            [{"symbol": "GBPUSD", "entry_policy": None, "tp_r_multiple": 2.0}]
        )
        self.assertEqual(transformed.matrix.shape[0], 1)
        self.assertEqual(
            transformed.matrix[0, transformed.encoded_feature_names.index(f"symbol={MISSING_CATEGORY}")],
            1.0,
        )

    def test_ablation_order_reconstructs_h1_features_without_leakage(self) -> None:
        previous: set[str] = set()
        for _, columns in FEATURE_ABLATIONS:
            current = set(columns)
            self.assertTrue(previous <= current)
            previous = current
        self.assertEqual(previous, set(MODEL_FEATURE_COLUMNS))
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertIn("entry_policy", MODEL_FEATURE_COLUMNS)
        self.assertNotIn("sl_policy", MODEL_FEATURE_COLUMNS)
        self.assertNotIn("reentry_index", MODEL_FEATURE_COLUMNS)

    def test_h1_and_deep_ablations_are_explicit_and_monotonic(self) -> None:
        for feature_set_id, ablations, expected in (
            (H1_FEATURE_SET_ID, H1_FEATURE_ABLATIONS, H1_MODEL_FEATURE_COLUMNS),
            (DEEP_FEATURE_SET_ID, DEEP_FEATURE_ABLATIONS, DEEP_MODEL_FEATURE_COLUMNS),
        ):
            with self.subTest(feature_set_id=feature_set_id):
                previous: set[str] = set()
                for _, columns in ablations:
                    current = set(columns)
                    self.assertTrue(previous <= current)
                    previous = current
                self.assertEqual(previous, set(expected))
                self.assertEqual(feature_ablations_for_set(feature_set_id), ablations)
                self.assertEqual(model_feature_columns_for_set(feature_set_id), expected)
        with self.assertRaisesRegex(ValueError, "Explicit H1 or deep"):
            model_feature_columns_for_set(SUPPORTED_FEATURE_SET_ID)

    def test_builder_preserves_native_deep_feature_grain(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        connection = duckdb.connect(":memory:")
        try:
            counts = create_dataset_tables(connection, [validation])
            self.assertEqual(
                {
                    H1_LANE_LONG_TABLE: counts[H1_LANE_LONG_TABLE],
                    H1_LANE_WIDE_TABLE: counts[H1_LANE_WIDE_TABLE],
                    ELIGIBLE_H1_TRIALS_TABLE: counts[ELIGIBLE_H1_TRIALS_TABLE],
                    DEEP_PARENT_LONG_TABLE: counts[DEEP_PARENT_LONG_TABLE],
                    ELIGIBLE_DEEP_TRIALS_TABLE: counts[ELIGIBLE_DEEP_TRIALS_TABLE],
                },
                {
                    H1_LANE_LONG_TABLE: 16,
                    H1_LANE_WIDE_TABLE: 2,
                    ELIGIBLE_H1_TRIALS_TABLE: 8,
                    DEEP_PARENT_LONG_TABLE: 9,
                    ELIGIBLE_DEEP_TRIALS_TABLE: 7,
                },
            )
            for table_name in (DEEP_PARENT_LONG_TABLE, ELIGIBLE_DEEP_TRIALS_TABLE):
                columns = {
                    row[0]
                    for row in connection.execute(f"DESCRIBE {table_name}").fetchall()
                }
                self.assertFalse(columns & set(DEEP_SIGNAL_FEATURE_COLUMNS))
            self.assertEqual(
                connection.execute(
                    f"SELECT round(sum(origin_sample_weight), 10), "
                    f"round(sum(event_sample_weight), 10) "
                    f"FROM {ELIGIBLE_DEEP_TRIALS_TABLE}"
                ).fetchone(),
                (2.0, 1.0),
            )
            deep_ratios = {
                row[0]
                for row in connection.execute(
                    f"SELECT DISTINCT tp_r_multiple FROM {DEEP_PARENT_LONG_TABLE}"
                ).fetchall()
            }
            self.assertEqual(deep_ratios, {1, 2, 3})
        finally:
            connection.close()

    def test_deep_features_join_only_for_explicit_training_load(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "fixture_v14"
            build_fixture_dataset(FIXTURE, dataset_dir)
            h1_rows = load_training_rows(dataset_dir, H1_FEATURE_SET_ID)
            deep_rows = load_training_rows(dataset_dir, DEEP_FEATURE_SET_ID)
            self.assertEqual((len(h1_rows), len(deep_rows)), (8, 7))
            self.assertTrue(
                all(
                    all(row.get(column) is not None for column in DEEP_MODEL_FEATURE_COLUMNS)
                    for row in deep_rows
                )
            )
            self.assertEqual(
                training_table_for_set(H1_FEATURE_SET_ID),
                ELIGIBLE_H1_TRIALS_TABLE,
            )
            self.assertEqual(
                training_table_for_set(DEEP_FEATURE_SET_ID),
                ELIGIBLE_DEEP_TRIALS_TABLE,
            )

    def test_training_requires_explicit_grain_and_real_support(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "fixture_v14"
            build_fixture_dataset(FIXTURE, dataset_dir)
            for feature_set_id in (H1_FEATURE_SET_ID, DEEP_FEATURE_SET_ID):
                output_dir = root / feature_set_id.rsplit(".", 1)[-1]
                output_dir.mkdir()
                with self.subTest(feature_set_id=feature_set_id):
                    with self.assertRaisesRegex(TrainingError, "Not enough rows"):
                        train_candidate(
                            dataset_dir,
                            output_dir,
                            "fixture_model",
                            feature_set_id,
                        )

    def test_origin_weights_do_not_inflate_repeated_deep_rows(self) -> None:
        rows = [
            {"run_id": "run_a", "origin_id": "origin_1"},
            {"run_id": "run_a", "origin_id": "origin_1"},
            {"run_id": "run_b", "origin_id": "origin_1"},
            {"run_id": "run_b", "origin_id": "origin_2"},
        ]
        weights = origin_balanced_weights(rows, list(range(len(rows))))
        by_origin: dict[str, float] = {}
        for row, weight in zip(rows, weights):
            by_origin[row["origin_id"]] = by_origin.get(row["origin_id"], 0.0) + weight
        self.assertEqual(by_origin, {"origin_1": 1.0, "origin_2": 1.0})

    def test_builder_weights_duplicate_runs_as_one_market_origin(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir)
            copy_run_with_id(FIXTURE, runs_root, "run_a")
            copy_run_with_id(FIXTURE, runs_root, "run_b")
            validations = validate_runs(runs_root, ["run_a", "run_b"])
            connection = duckdb.connect(":memory:")
            try:
                counts = create_dataset_tables(connection, validations)
                self.assertEqual(counts[ELIGIBLE_H1_TRIALS_TABLE], 16)
                self.assertEqual(counts[ELIGIBLE_DEEP_TRIALS_TABLE], 14)
                self.assertEqual(
                    connection.execute(
                        f"SELECT round(sum(origin_sample_weight), 10) "
                        f"FROM {ELIGIBLE_H1_TRIALS_TABLE}"
                    ).fetchone()[0],
                    1.0,
                )
                self.assertEqual(
                    connection.execute(
                        f"SELECT round(sum(origin_sample_weight), 10), "
                        f"round(sum(event_sample_weight), 10) "
                        f"FROM {ELIGIBLE_DEEP_TRIALS_TABLE}"
                    ).fetchone(),
                    (2.0, 1.0),
                )
            finally:
                connection.close()


if __name__ == "__main__":
    unittest.main()
