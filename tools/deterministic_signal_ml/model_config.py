"""Configuration defaults for deterministic signal model training."""

from __future__ import annotations

from dataclasses import dataclass


TRAINER_VERSION = "phase3.xgboost_trainer.v1"
DEFAULT_DATASET_ROOT = "artifacts/datasets"
DEFAULT_MODEL_ROOT = "artifacts/models"
DEFAULT_HOLDOUT_FRACTION = 0.20
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_WALK_FORWARD_GAP = 0
MIN_TRAINING_ROWS = 500
MIN_CLASS_COUNT = 20


@dataclass(frozen=True)
class XGBoostClassifierConfig:
    n_estimators: int = 300
    max_depth: int = 3
    learning_rate: float = 0.05
    subsample: float = 0.90
    colsample_bytree: float = 0.90
    reg_lambda: float = 1.0
    random_state: int = 42
    tree_method: str = "hist"
    eval_metric: str = "logloss"
    early_stopping_rounds: int = 25
    n_jobs: int = 1
    verbosity: int = 0


@dataclass(frozen=True)
class XGBoostRegressorConfig:
    n_estimators: int = 300
    max_depth: int = 3
    learning_rate: float = 0.05
    subsample: float = 0.90
    colsample_bytree: float = 0.90
    reg_lambda: float = 1.0
    random_state: int = 42
    tree_method: str = "hist"
    eval_metric: str = "rmse"
    early_stopping_rounds: int = 25
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
