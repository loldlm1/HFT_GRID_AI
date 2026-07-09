"""Configuration defaults for deterministic signal model training."""

from __future__ import annotations

from dataclasses import dataclass


TRAINER_VERSION = "phase5.xgboost_trainer.schema_v5_numeric.v1"
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
    max_depth: int = 5
    max_bin: int | None = None
    learning_rate: float = 0.05
    subsample: float = 0.90
    colsample_bytree: float = 0.90
    min_child_weight: float = 1.0
    gamma: float = 0.0
    reg_alpha: float = 0.0
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
    max_depth: int = 5
    max_bin: int | None = None
    learning_rate: float = 0.05
    subsample: float = 0.90
    colsample_bytree: float = 0.90
    min_child_weight: float = 1.0
    gamma: float = 0.0
    reg_alpha: float = 0.0
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


def training_config_for_feature_set(feature_set_id: str) -> TrainingConfig:
    if feature_set_id not in ("schema_v5_numeric_xgb", "schema_v6_numeric_xgb"):
        return TrainingConfig()

    classifier = XGBoostClassifierConfig(
        n_estimators=500,
        max_depth=3,
        max_bin=256,
        learning_rate=0.03,
        subsample=0.85,
        colsample_bytree=0.85,
        min_child_weight=5.0,
        gamma=0.10,
        reg_alpha=0.10,
        reg_lambda=2.0,
        early_stopping_rounds=40,
    )
    regressor = XGBoostRegressorConfig(
        n_estimators=500,
        max_depth=3,
        max_bin=256,
        learning_rate=0.03,
        subsample=0.85,
        colsample_bytree=0.85,
        min_child_weight=5.0,
        gamma=0.10,
        reg_alpha=0.10,
        reg_lambda=2.0,
        early_stopping_rounds=40,
    )
    return TrainingConfig(classifier=classifier, regressor=regressor)
