"""Pinned offline XGBoost configuration for separate V14 H1 and deep cohorts."""

from __future__ import annotations

from dataclasses import dataclass

from schema_contract import (
    DEEP_CATEGORICAL_COLUMNS,
    DEEP_FEATURE_SET_ID,
    DEEP_MODEL_FEATURE_COLUMNS,
    FEATURE_SHIFTS,
    H1_CATEGORICAL_COLUMNS,
    H1_FEATURE_SET_ID,
    H1_MODEL_FEATURE_COLUMNS,
)

TRAINER_VERSION = "pivot_fractal.xgboost.schema_v14_hft_deep_pivot_features.v1"
DEFAULT_DATASET_ROOT = "artifacts/datasets"
DEFAULT_MODEL_ROOT = "artifacts/models"
DEFAULT_HOLDOUT_FRACTION = 0.20
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_WALK_FORWARD_GAP = 1
MIN_TRAINING_ROWS = 500
MIN_TRAINING_ORIGINS = 100
MIN_CLASS_COUNT = 20
MIN_CLASS_ORIGIN_COUNT = 20
ORIGIN_WEIGHT_POLICY = "sum_to_one_per_origin_within_each_training_subset"
EVENT_WEIGHT_POLICY = "sum_to_one_per_deep_event_in_full_cohort"


def _series_columns(prefix: str, series: str) -> tuple[str, ...]:
    return tuple(
        column
        for shift in FEATURE_SHIFTS
        for column in (
            f"{prefix}_{series}_{shift}",
            f"{prefix}_{series}_sma_5_{shift}",
            f"{prefix}_{series}_sma_slope_{shift}",
            f"{prefix}_{series}_state_{shift}",
        )
    )


def _band_columns(prefix: str) -> tuple[str, ...]:
    return (
        *_series_columns(prefix, "b_percent"),
        *(
            column
            for shift in FEATURE_SHIFTS
            for column in (
                f"{prefix}_band_base_line_{shift}",
                f"{prefix}_band_base_line_slope_points_{shift}",
            )
        ),
    )


def _stochastic_columns(prefix: str) -> tuple[str, ...]:
    return (
        *_series_columns(prefix, "stochastic_main_line"),
        *_series_columns(prefix, "stochastic_signal_line"),
    )


H1_BASE_FEATURE_COLUMNS = (
    "symbol",
    "level_id",
    "direction",
    "entry_policy",
    "tp_r_multiple",
    "analysis_weekday",
    "analysis_session",
    "trigger_gap_to_risk",
    "spread_to_risk",
    "time_sin",
    "time_cos",
)
H1_WIDTH_FEATURE_COLUMNS = H1_BASE_FEATURE_COLUMNS + (
    "origin_macro_band_width_points_0",
    "origin_deep_band_width_points_0",
)
H1_MACRO_BANDS_FEATURE_COLUMNS = H1_WIDTH_FEATURE_COLUMNS + _band_columns(
    "origin_macro"
)
H1_DEEP_BANDS_FEATURE_COLUMNS = H1_MACRO_BANDS_FEATURE_COLUMNS + _band_columns(
    "origin_deep"
)
H1_MACRO_STOCHASTIC_FEATURE_COLUMNS = (
    H1_DEEP_BANDS_FEATURE_COLUMNS + _stochastic_columns("origin_macro")
)
H1_ALL_FEATURE_COLUMNS = (
    H1_MACRO_STOCHASTIC_FEATURE_COLUMNS + _stochastic_columns("origin_deep")
)
H1_FEATURE_ABLATIONS = (
    ("base", H1_BASE_FEATURE_COLUMNS),
    ("widths", H1_WIDTH_FEATURE_COLUMNS),
    ("macro_bands", H1_MACRO_BANDS_FEATURE_COLUMNS),
    ("deep_bands", H1_DEEP_BANDS_FEATURE_COLUMNS),
    ("macro_stochastic", H1_MACRO_STOCHASTIC_FEATURE_COLUMNS),
    ("deep_stochastic", H1_ALL_FEATURE_COLUMNS),
)
# Generic callers default to the primary H1 evidence grain; deep training
# selects its own explicit ablation sequence through feature_set_id.
FEATURE_ABLATIONS = H1_FEATURE_ABLATIONS

DEEP_BASE_FEATURE_COLUMNS = (
    "symbol",
    "level_id",
    "direction",
    "parent_direction",
    "direction_relationship",
    "parent_kind",
    "parent_entry_policy",
    "tp_r_multiple",
    "parent_tp_r_multiple",
    "m10_parent_age_seconds",
    "analysis_weekday",
    "analysis_session",
    "trigger_gap_to_risk",
    "spread_to_risk",
    "time_sin",
    "time_cos",
)
DEEP_WIDTH_FEATURE_COLUMNS = DEEP_BASE_FEATURE_COLUMNS + (
    "deep_deep_band_width_points_0",
    "deep_micro_band_width_points_0",
)
DEEP_BANDS_FEATURE_COLUMNS = DEEP_WIDTH_FEATURE_COLUMNS + _band_columns("deep_deep")
DEEP_MICRO_BANDS_FEATURE_COLUMNS = DEEP_BANDS_FEATURE_COLUMNS + _band_columns("deep_micro")
DEEP_STOCHASTIC_FEATURE_COLUMNS = DEEP_MICRO_BANDS_FEATURE_COLUMNS + _stochastic_columns("deep_deep")
DEEP_ALL_FEATURE_COLUMNS = DEEP_STOCHASTIC_FEATURE_COLUMNS + _stochastic_columns(
    "deep_micro"
)
DEEP_FEATURE_ABLATIONS = (
    ("base", DEEP_BASE_FEATURE_COLUMNS),
    ("widths", DEEP_WIDTH_FEATURE_COLUMNS),
    ("deep_bands", DEEP_BANDS_FEATURE_COLUMNS),
    ("micro_bands", DEEP_MICRO_BANDS_FEATURE_COLUMNS),
    ("deep_stochastic", DEEP_STOCHASTIC_FEATURE_COLUMNS),
    ("micro_stochastic", DEEP_ALL_FEATURE_COLUMNS),
)

if set(H1_ALL_FEATURE_COLUMNS) != set(H1_MODEL_FEATURE_COLUMNS):
    raise RuntimeError("H1 ablation contract does not reconstruct the V14 H1 feature set")
if set(DEEP_ALL_FEATURE_COLUMNS) != set(DEEP_MODEL_FEATURE_COLUMNS):
    raise RuntimeError("Deep ablation contract does not reconstruct the V14 deep feature set")


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
    min_training_origins: int = MIN_TRAINING_ORIGINS
    min_class_count: int = MIN_CLASS_COUNT
    min_class_origin_count: int = MIN_CLASS_ORIGIN_COUNT
    classifier: XGBoostClassifierConfig = XGBoostClassifierConfig()


def model_feature_columns_for_set(feature_set_id: str) -> tuple[str, ...]:
    if feature_set_id == H1_FEATURE_SET_ID:
        return H1_MODEL_FEATURE_COLUMNS
    if feature_set_id == DEEP_FEATURE_SET_ID:
        return DEEP_MODEL_FEATURE_COLUMNS
    raise ValueError(f"Explicit H1 or deep feature_set_id required: {feature_set_id}")


def categorical_columns_for_set(feature_set_id: str) -> tuple[str, ...]:
    if feature_set_id == H1_FEATURE_SET_ID:
        return H1_CATEGORICAL_COLUMNS
    if feature_set_id == DEEP_FEATURE_SET_ID:
        return DEEP_CATEGORICAL_COLUMNS
    raise ValueError(f"Explicit H1 or deep feature_set_id required: {feature_set_id}")


def feature_ablations_for_set(
    feature_set_id: str,
) -> tuple[tuple[str, tuple[str, ...]], ...]:
    if feature_set_id == H1_FEATURE_SET_ID:
        return H1_FEATURE_ABLATIONS
    if feature_set_id == DEEP_FEATURE_SET_ID:
        return DEEP_FEATURE_ABLATIONS
    raise ValueError(f"Explicit H1 or deep feature_set_id required: {feature_set_id}")


def source_grain_for_set(feature_set_id: str) -> str:
    if feature_set_id == H1_FEATURE_SET_ID:
        return "H1_LANE"
    if feature_set_id == DEEP_FEATURE_SET_ID:
        return "DEEP_PARENT_LINK_X_RATIO"
    raise ValueError(f"Explicit H1 or deep feature_set_id required: {feature_set_id}")


def training_table_for_set(feature_set_id: str) -> str:
    if feature_set_id == H1_FEATURE_SET_ID:
        return "eligible_h1_trials"
    if feature_set_id == DEEP_FEATURE_SET_ID:
        return "eligible_deep_trials"
    raise ValueError(f"Explicit H1 or deep feature_set_id required: {feature_set_id}")


def training_config_for_feature_set(feature_set_id: str) -> TrainingConfig:
    model_feature_columns_for_set(feature_set_id)
    return TrainingConfig()
