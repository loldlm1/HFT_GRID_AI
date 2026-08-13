"""Pinned offline XGBoost configuration and ordered V12 feature ablations."""

from __future__ import annotations

from dataclasses import dataclass

from schema_contract import (
    FEATURE_SHIFTS,
    MODEL_FEATURE_COLUMNS,
    SUPPORTED_FEATURE_SET_ID,
)


TRAINER_VERSION = "pivot_fractal.xgboost.schema_v12_pivot_signal_features.v1"
DEFAULT_DATASET_ROOT = "artifacts/datasets"
DEFAULT_MODEL_ROOT = "artifacts/models"
DEFAULT_HOLDOUT_FRACTION = 0.20
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_WALK_FORWARD_GAP = 1
MIN_TRAINING_ROWS = 500
MIN_TRAINING_ORIGINS = 100
MIN_CLASS_COUNT = 20
MIN_CLASS_ORIGIN_COUNT = 20

BASE_FEATURE_COLUMNS = (
    "symbol",
    "level_id",
    "direction",
    "sl_policy",
    "tp_r_multiple",
    "reentry_index",
    "preceding_loss_count",
    "analysis_weekday",
    "analysis_session",
    "trigger_gap_to_risk",
    "spread_to_risk",
    "time_sin",
    "time_cos",
)
WIDTH_FEATURE_COLUMNS = BASE_FEATURE_COLUMNS + (
    "origin_micro_band_width_points_0",
    "origin_macro_band_width_points_0",
)


def _series_columns(timeframe: str, series: str) -> tuple[str, ...]:
    prefix = f"origin_{timeframe}_{series}"
    return tuple(
        column
        for shift in FEATURE_SHIFTS
        for column in (
            f"{prefix}_{shift}",
            f"{prefix}_sma_5_{shift}",
            f"{prefix}_sma_slope_{shift}",
            f"{prefix}_state_{shift}",
        )
    )


def _band_columns(timeframe: str) -> tuple[str, ...]:
    prefix = f"origin_{timeframe}"
    return (
        *_series_columns(timeframe, "b_percent"),
        *(
            column
            for shift in FEATURE_SHIFTS
            for column in (
                f"{prefix}_band_base_line_{shift}",
                f"{prefix}_band_base_line_slope_points_{shift}",
            )
        ),
    )


def _stochastic_columns(timeframe: str) -> tuple[str, ...]:
    return (
        *_series_columns(timeframe, "stochastic_main_line"),
        *_series_columns(timeframe, "stochastic_signal_line"),
    )


MICRO_BANDS_FEATURE_COLUMNS = WIDTH_FEATURE_COLUMNS + _band_columns("micro")
MACRO_BANDS_FEATURE_COLUMNS = MICRO_BANDS_FEATURE_COLUMNS + _band_columns("macro")
MICRO_STOCHASTIC_FEATURE_COLUMNS = (
    MACRO_BANDS_FEATURE_COLUMNS + _stochastic_columns("micro")
)
MACRO_STOCHASTIC_FEATURE_COLUMNS = (
    MICRO_STOCHASTIC_FEATURE_COLUMNS + _stochastic_columns("macro")
)
FEATURE_ABLATIONS = (
    ("base", BASE_FEATURE_COLUMNS),
    ("widths", WIDTH_FEATURE_COLUMNS),
    ("micro_bands", MICRO_BANDS_FEATURE_COLUMNS),
    ("macro_bands", MACRO_BANDS_FEATURE_COLUMNS),
    ("micro_stochastic", MICRO_STOCHASTIC_FEATURE_COLUMNS),
    ("macro_stochastic", MACRO_STOCHASTIC_FEATURE_COLUMNS),
)

if len(MACRO_STOCHASTIC_FEATURE_COLUMNS) != len(MODEL_FEATURE_COLUMNS) or set(
    MACRO_STOCHASTIC_FEATURE_COLUMNS
) != set(MODEL_FEATURE_COLUMNS):
    raise RuntimeError("V12 ablation order does not reconstruct the frozen feature set")


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


def training_config_for_feature_set(feature_set_id: str) -> TrainingConfig:
    if feature_set_id != SUPPORTED_FEATURE_SET_ID:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}")
    return TrainingConfig()
