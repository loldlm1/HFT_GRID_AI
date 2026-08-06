"""Pinned offline XGBoost configuration and ordered V10 feature ablations."""

from __future__ import annotations

from dataclasses import dataclass

from schema_contract import MODEL_FEATURE_COLUMNS, SUPPORTED_FEATURE_SET_ID


TRAINER_VERSION = "pivot_fractal.xgboost.schema_v10.v1"
DEFAULT_DATASET_ROOT = "artifacts/datasets"
DEFAULT_MODEL_ROOT = "artifacts/models"
DEFAULT_HOLDOUT_FRACTION = 0.20
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_WALK_FORWARD_GAP = 1
MIN_TRAINING_ROWS = 500
MIN_CLASS_COUNT = 20

BASE_FEATURE_COLUMNS = (
    "symbol",
    "level_id",
    "direction",
    "analysis_weekday",
    "analysis_session",
    "trigger_gap_to_risk",
    "spread_to_risk",
    "time_sin",
    "time_cos",
)
WIDTH_FEATURE_COLUMNS = BASE_FEATURE_COLUMNS + (
    "micro_band_width_percent_0",
    "macro_band_width_percent_1",
    "macro_range_to_band_width",
)
MICRO_FEATURE_COLUMNS = WIDTH_FEATURE_COLUMNS + tuple(
    f"micro_b_percent_{shift}" for shift in range(6)
)
MACRO_FEATURE_COLUMNS = MICRO_FEATURE_COLUMNS + tuple(
    f"macro_pivot_b_percent_{shift}" for shift in range(6)
)
FEATURE_ABLATIONS = (
    ("base", BASE_FEATURE_COLUMNS),
    ("widths", WIDTH_FEATURE_COLUMNS),
    ("micro_b_percent", MICRO_FEATURE_COLUMNS),
    ("macro_b_percent", MACRO_FEATURE_COLUMNS),
)

if len(MACRO_FEATURE_COLUMNS) != len(MODEL_FEATURE_COLUMNS) or set(
    MACRO_FEATURE_COLUMNS
) != set(MODEL_FEATURE_COLUMNS):
    raise RuntimeError("V10 ablation order does not reconstruct the frozen feature set")


@dataclass(frozen=True)
class XGBoostClassifierConfig:
    n_estimators: int = 500
    max_depth: int = 3
    max_bin: int = 256
    learning_rate: float = 0.03
    subsample: float = 0.85
    colsample_bytree: float = 0.85
    min_child_weight: float = 5.0
    gamma: float = 0.10
    reg_alpha: float = 0.10
    reg_lambda: float = 2.0
    random_state: int = 42
    tree_method: str = "hist"
    eval_metric: str = "logloss"
    n_jobs: int = 1
    verbosity: int = 0


@dataclass(frozen=True)
class TrainingConfig:
    holdout_fraction: float = DEFAULT_HOLDOUT_FRACTION
    walk_forward_splits: int = DEFAULT_WALK_FORWARD_SPLITS
    walk_forward_gap: int = DEFAULT_WALK_FORWARD_GAP
    min_training_rows: int = MIN_TRAINING_ROWS
    min_class_count: int = MIN_CLASS_COUNT
    classifier: XGBoostClassifierConfig = XGBoostClassifierConfig()


def training_config_for_feature_set(feature_set_id: str) -> TrainingConfig:
    if feature_set_id != SUPPORTED_FEATURE_SET_ID:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}")
    return TrainingConfig()
