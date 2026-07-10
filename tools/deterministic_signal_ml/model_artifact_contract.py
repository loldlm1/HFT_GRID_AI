"""Contract constants for MT5-readable deterministic signal model exports."""

from __future__ import annotations


ARTIFACT_SCHEMA_VERSION = 1
EXPORTER_VERSION = "phase4.model_exporter.v2"
DEFAULT_EXPORT_ROOT = "artifacts/model_exports"

MODEL_MANIFEST_TSV = "model_manifest.tsv"
MODEL_MANIFEST_JSON = "model_manifest.json"
FEATURE_MAP_TSV = "feature_map.tsv"
CLASSIFIER_TREES_TSV = "classifier_trees.tsv"
REGRESSOR_TREES_TSV = "regressor_trees.tsv"
THRESHOLD_POLICY_TSV = "threshold_policy.tsv"
PARITY_REPORT_JSON = "parity_report.json"
PARITY_REPORT_MD = "parity_report.md"

REQUIRED_PHASE3_FILES = (
    "model_manifest.json",
    "feature_encoder.json",
    "classifier_xgboost.json",
)

OPTIONAL_PHASE3_FILES = (
    "regressor_xgboost.json",
    "threshold_report.tsv",
)

MANIFEST_TSV_COLUMNS = ("key", "value")

FEATURE_MAP_COLUMNS = (
    "encoded_index",
    "encoded_feature_name",
    "source_column",
    "encoding_type",
    "category",
)

TREE_COLUMNS = (
    "model_role",
    "tree_index",
    "node_index",
    "node_type",
    "feature_index",
    "threshold",
    "left_child",
    "right_child",
    "default_left",
    "leaf_value",
)

THRESHOLD_POLICY_COLUMNS = (
    "threshold",
    "selected_rows",
    "win_rate",
    "mean_profit_r",
    "net_profit_r",
    "max_drawdown_r",
    "source",
    "research_only",
)

REQUIRED_MANIFEST_KEYS = (
    "artifact_schema_version",
    "exporter_version",
    "model_id",
    "dataset_id",
    "phase1_schema_version",
    "phase2_builder_version",
    "phase3_trainer_version",
    "feature_set_id",
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "runtime_approval",
    "encoded_feature_count",
    "classifier_tree_count",
    "classifier_objective",
    "classifier_base_score",
    "regressor_tree_count",
    "regressor_objective",
    "regressor_base_score",
    "threshold_probability",
    "research_only",
    "mt5_runtime_ready",
)
