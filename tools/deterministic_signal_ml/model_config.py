"""Pinned research-only XGBoost defaults for the pivot-fractal feature set."""

from __future__ import annotations

from dataclasses import dataclass

from schema_contract import SUPPORTED_FEATURE_SET_ID


TRAINER_VERSION = "pivot_fractal.xgboost.schema_v9.v1"
DEFAULT_DATASET_ROOT = "artifacts/datasets"
DEFAULT_MODEL_ROOT = "artifacts/models"
DEFAULT_HOLDOUT_FRACTION = 0.20
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_WALK_FORWARD_GAP = 1
MIN_TRAINING_ROWS = 500
MIN_CLASS_COUNT = 20


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
class XGBoostRegressorConfig:
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
    eval_metric: str = "rmse"
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
    regressor: XGBoostRegressorConfig = XGBoostRegressorConfig()


def training_config_for_feature_set(feature_set_id: str) -> TrainingConfig:
    if feature_set_id != SUPPORTED_FEATURE_SET_ID:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}")
    return TrainingConfig()
