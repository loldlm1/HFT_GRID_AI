from __future__ import annotations

import sys
import unittest
from pathlib import Path

import duckdb

MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from build_dataset import (
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_GROUPS,
    _typed_expression,
    create_raw_tables,
)
from feature_encoder import FeatureEncoder, MISSING_CATEGORY
from model_config import FEATURE_ABLATIONS
from schema_contract import (
    DEEP_FEATURE_SET_ID,
    DEEP_MODEL_FEATURE_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    H1_FEATURE_SET_ID,
    H1_MODEL_FEATURE_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    SUPPORTED_FEATURE_SET_ID,
    TABLE_COLUMNS,
    feature_columns_for_set,
    validate_run,
)

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v13_hft_deep_pivot_features"


class PivotFractalV13ResearchContractTests(unittest.TestCase):
    def test_builder_registry_is_exhaustive_and_disjoint(self) -> None:
        schema_columns = {column for columns in TABLE_COLUMNS.values() for column in columns}
        self.assertEqual(set(COLUMN_TYPE_BY_NAME), schema_columns)
        self.assertEqual(
            sum(len(columns) for columns in COLUMN_TYPE_GROUPS.values()),
            len(schema_columns),
        )
        self.assertEqual(COLUMN_TYPE_BY_NAME["block_source"], "VARCHAR") if "block_source" in COLUMN_TYPE_BY_NAME else self.assertEqual(COLUMN_TYPE_BY_NAME["entry_policy"], "VARCHAR")
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
            self.assertEqual(counts["deep_pivot_parent_links"], 2)
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


if __name__ == "__main__":
    unittest.main()
