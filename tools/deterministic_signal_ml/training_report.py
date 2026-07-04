"""Baseline metrics and human-readable reports for Phase 3 training."""

from __future__ import annotations

import math
from typing import Any

import numpy as np
from sklearn.dummy import DummyClassifier, DummyRegressor
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    log_loss,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor

from validation_splits import SplitBundle


def classification_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_proba: np.ndarray,
) -> dict[str, Any]:
    unique_classes = sorted(int(value) for value in np.unique(y_true))
    metrics: dict[str, Any] = {
        "rows": int(len(y_true)),
        "positive_rows": int(np.sum(y_true == 1)),
        "negative_rows": int(np.sum(y_true == 0)),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1": float(f1_score(y_true, y_pred, zero_division=0)),
        "brier_score": float(brier_score_loss(y_true, y_proba)),
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=[0, 1]).astype(int).tolist(),
    }
    if len(unique_classes) == 2:
        metrics["roc_auc"] = float(roc_auc_score(y_true, y_proba))
        metrics["average_precision"] = float(average_precision_score(y_true, y_proba))
        metrics["log_loss"] = float(log_loss(y_true, y_proba, labels=[0, 1]))
    else:
        metrics["roc_auc"] = None
        metrics["average_precision"] = None
        metrics["log_loss"] = None
    return metrics


def regression_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, Any]:
    realized_mean = float(np.mean(y_true))
    predicted_mean = float(np.mean(y_pred))
    if len(y_true) > 1 and float(np.std(y_true)) > 0.0 and float(np.std(y_pred)) > 0.0:
        correlation = float(np.corrcoef(y_true, y_pred)[0, 1])
    else:
        correlation = None
    return {
        "rows": int(len(y_true)),
        "mae": float(mean_absolute_error(y_true, y_pred)),
        "rmse": float(math.sqrt(mean_squared_error(y_true, y_pred))),
        "mean_realized_r": realized_mean,
        "mean_predicted_r": predicted_mean,
        "correlation": correlation,
    }


def evaluate_baselines(
    rows: list[dict[str, Any]],
    feature_matrix: np.ndarray,
    split_bundle: SplitBundle,
) -> dict[str, Any]:
    y_win = np.asarray([int(row["target_is_win"]) for row in rows], dtype=np.int64)
    y_profit = np.asarray([float(row["target_profit_r"]) for row in rows], dtype=np.float64)

    holdout_metrics = _evaluate_split(
        "holdout",
        rows,
        feature_matrix,
        y_win,
        y_profit,
        split_bundle.train_indices,
        split_bundle.holdout_indices,
    )
    fold_metrics = [
        _evaluate_split(
            f"fold_{fold.fold_index}",
            rows,
            feature_matrix,
            y_win,
            y_profit,
            fold.train_indices,
            fold.test_indices,
        )
        for fold in split_bundle.folds
    ]
    return {"holdout": holdout_metrics, "folds": fold_metrics}


def _evaluate_split(
    split_name: str,
    rows: list[dict[str, Any]],
    feature_matrix: np.ndarray,
    y_win: np.ndarray,
    y_profit: np.ndarray,
    train_indices: list[int],
    test_indices: list[int],
) -> dict[str, Any]:
    train_array = np.asarray(train_indices, dtype=np.int64)
    test_array = np.asarray(test_indices, dtype=np.int64)
    x_train = feature_matrix[train_array]
    x_test = feature_matrix[test_array]
    y_win_train = y_win[train_array]
    y_win_test = y_win[test_array]
    y_profit_train = y_profit[train_array]
    y_profit_test = y_profit[test_array]

    classification = {
        "majority_class": _majority_classification(x_train, x_test, y_win_train, y_win_test),
        "strategy_direction_bucket": _bucket_classification(
            rows, train_indices, test_indices, y_win, y_win_test
        ),
        "decision_tree_depth_3": _tree_classification(
            x_train, x_test, y_win_train, y_win_test
        ),
    }
    regression = {
        "global_mean": _global_mean_regression(y_profit_train, y_profit_test),
        "strategy_direction_bucket_mean": _bucket_regression(
            rows, train_indices, test_indices, y_profit, y_profit_test
        ),
        "decision_tree_depth_3": _tree_regression(
            x_train, x_test, y_profit_train, y_profit_test
        ),
    }
    return {
        "split": split_name,
        "train_rows": int(len(train_indices)),
        "test_rows": int(len(test_indices)),
        "classification": classification,
        "regression": regression,
    }


def _positive_class_probability(model: Any, x_test: np.ndarray) -> np.ndarray:
    probabilities = model.predict_proba(x_test)
    classes = [int(value) for value in model.classes_]
    if 1 in classes:
        return probabilities[:, classes.index(1)]
    if classes == [1]:
        return np.ones(x_test.shape[0], dtype=np.float64)
    return np.zeros(x_test.shape[0], dtype=np.float64)


def _majority_classification(
    x_train: np.ndarray,
    x_test: np.ndarray,
    y_train: np.ndarray,
    y_test: np.ndarray,
) -> dict[str, Any]:
    model = DummyClassifier(strategy="most_frequent")
    model.fit(x_train, y_train)
    y_pred = model.predict(x_test)
    y_proba = _positive_class_probability(model, x_test)
    return classification_metrics(y_test, y_pred, y_proba)


def _tree_classification(
    x_train: np.ndarray,
    x_test: np.ndarray,
    y_train: np.ndarray,
    y_test: np.ndarray,
) -> dict[str, Any]:
    if len(np.unique(y_train)) < 2:
        return _majority_classification(x_train, x_test, y_train, y_test)
    model = DecisionTreeClassifier(max_depth=3, min_samples_leaf=20, random_state=42)
    model.fit(x_train, y_train)
    y_pred = model.predict(x_test)
    y_proba = _positive_class_probability(model, x_test)
    return classification_metrics(y_test, y_pred, y_proba)


def _global_mean_regression(y_train: np.ndarray, y_test: np.ndarray) -> dict[str, Any]:
    y_pred = np.full(len(y_test), float(np.mean(y_train)), dtype=np.float64)
    return regression_metrics(y_test, y_pred)


def _tree_regression(
    x_train: np.ndarray,
    x_test: np.ndarray,
    y_train: np.ndarray,
    y_test: np.ndarray,
) -> dict[str, Any]:
    model = DecisionTreeRegressor(max_depth=3, min_samples_leaf=20, random_state=42)
    model.fit(x_train, y_train)
    y_pred = model.predict(x_test)
    return regression_metrics(y_test, y_pred)


def _bucket_key(row: dict[str, Any]) -> str:
    return f"{row.get('strategy_label', '')}|{row.get('direction', '')}"


def _bucket_classification(
    rows: list[dict[str, Any]],
    train_indices: list[int],
    test_indices: list[int],
    y_win: np.ndarray,
    y_test: np.ndarray,
) -> dict[str, Any]:
    global_probability = float(np.mean(y_win[np.asarray(train_indices, dtype=np.int64)]))
    bucket_counts: dict[str, list[int]] = {}
    for index in train_indices:
        key = _bucket_key(rows[index])
        counts = bucket_counts.setdefault(key, [0, 0])
        counts[int(y_win[index])] += 1

    bucket_probability = {
        key: counts[1] / (counts[0] + counts[1]) for key, counts in bucket_counts.items()
    }
    y_proba = np.asarray(
        [bucket_probability.get(_bucket_key(rows[index]), global_probability) for index in test_indices],
        dtype=np.float64,
    )
    y_pred = (y_proba >= 0.5).astype(np.int64)
    return classification_metrics(y_test, y_pred, y_proba)


def _bucket_regression(
    rows: list[dict[str, Any]],
    train_indices: list[int],
    test_indices: list[int],
    y_profit: np.ndarray,
    y_test: np.ndarray,
) -> dict[str, Any]:
    global_mean = float(np.mean(y_profit[np.asarray(train_indices, dtype=np.int64)]))
    bucket_totals: dict[str, list[float]] = {}
    for index in train_indices:
        key = _bucket_key(rows[index])
        total = bucket_totals.setdefault(key, [0.0, 0.0])
        total[0] += float(y_profit[index])
        total[1] += 1.0

    bucket_mean = {key: total[0] / total[1] for key, total in bucket_totals.items()}
    y_pred = np.asarray(
        [bucket_mean.get(_bucket_key(rows[index]), global_mean) for index in test_indices],
        dtype=np.float64,
    )
    return regression_metrics(y_test, y_pred)


def render_validation_report(
    model_id: str,
    dataset_id: str,
    split_metadata: dict[str, Any],
    baseline_metrics: dict[str, Any],
) -> str:
    holdout = baseline_metrics["holdout"]
    majority = holdout["classification"]["majority_class"]
    bucket = holdout["classification"]["strategy_direction_bucket"]
    tree = holdout["classification"]["decision_tree_depth_3"]
    global_mean = holdout["regression"]["global_mean"]
    bucket_mean = holdout["regression"]["strategy_direction_bucket_mean"]
    tree_reg = holdout["regression"]["decision_tree_depth_3"]

    lines = [
        f"# Validation Report: {model_id}",
        "",
        f"- Dataset: `{dataset_id}`",
        f"- Split policy: `{split_metadata['policy']}`",
        f"- Train rows: {split_metadata['train']['row_count']}",
        f"- Holdout rows: {split_metadata['holdout']['row_count']}",
        f"- Walk-forward folds: {split_metadata['walk_forward_splits']}",
        "",
        "## Holdout Classification Baselines",
        "",
        "| Model | Accuracy | Balanced Accuracy | Precision | Recall | F1 | ROC AUC | Log Loss |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        _classification_row("Majority", majority),
        _classification_row("Strategy/Direction", bucket),
        _classification_row("Decision Tree depth 3", tree),
        "",
        "## Holdout Regression Baselines",
        "",
        "| Model | MAE | RMSE | Mean Realized R | Mean Predicted R | Correlation |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        _regression_row("Global Mean", global_mean),
        _regression_row("Strategy/Direction Mean", bucket_mean),
        _regression_row("Decision Tree depth 3", tree_reg),
        "",
        "## Fold Ranges",
        "",
        "| Fold | Train Rows | Test Rows | Train End | Test Start | Test End |",
        "| ---: | ---: | ---: | --- | --- | --- |",
    ]
    for fold in split_metadata["folds"]:
        lines.append(
            "| {fold_index} | {train_rows} | {test_rows} | {train_end} | {test_start} | {test_end} |".format(
                fold_index=fold["fold_index"],
                train_rows=fold["train"]["row_count"],
                test_rows=fold["test"]["row_count"],
                train_end=fold["train"]["entry_time_end"],
                test_start=fold["test"]["entry_time_start"],
                test_end=fold["test"]["entry_time_end"],
            )
        )
    lines.extend(
        [
            "",
            "## Limitations",
            "",
            "- These are research baselines only; no EA inference or trading filter is active in this phase.",
            "- Performance claims must be judged against chronological holdout and walk-forward folds, not random splits.",
        ]
    )
    return "\n".join(lines) + "\n"


def _format_metric(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{float(value):.6f}"


def _classification_row(name: str, metrics: dict[str, Any]) -> str:
    return (
        f"| {name} | {_format_metric(metrics['accuracy'])} | "
        f"{_format_metric(metrics['balanced_accuracy'])} | "
        f"{_format_metric(metrics['precision'])} | {_format_metric(metrics['recall'])} | "
        f"{_format_metric(metrics['f1'])} | {_format_metric(metrics['roc_auc'])} | "
        f"{_format_metric(metrics['log_loss'])} |"
    )


def _regression_row(name: str, metrics: dict[str, Any]) -> str:
    return (
        f"| {name} | {_format_metric(metrics['mae'])} | {_format_metric(metrics['rmse'])} | "
        f"{_format_metric(metrics['mean_realized_r'])} | "
        f"{_format_metric(metrics['mean_predicted_r'])} | "
        f"{_format_metric(metrics['correlation'])} |"
    )
