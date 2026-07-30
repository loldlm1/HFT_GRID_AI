"""Train research-only XGBoost candidates from a leakage-safe V9 matrix."""

from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
from dataclasses import asdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb
import numpy as np
import xgboost as xgb
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    log_loss,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    recall_score,
    roc_auc_score,
)

from feature_encoder import FeatureEncoder
from model_config import (
    DEFAULT_DATASET_ROOT,
    DEFAULT_MODEL_ROOT,
    TRAINER_VERSION,
    training_config_for_feature_set,
)
from schema_contract import (
    DATASET_TARGET_FAMILIES,
    FUTURE_ONLY_COLUMNS,
    SUPPORTED_SCHEMA_VERSION,
    TARGET_COLUMNS,
)
from validation_splits import SplitBundle, build_time_splits


class TrainingError(RuntimeError):
    """Raised when an offline candidate cannot be trained safely."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id", help="Dataset ID under --dataset-root.")
    dataset_group.add_argument("--dataset-path", help="Explicit dataset folder.")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--feature-set-id", default="")
    parser.add_argument("--target-family", choices=DATASET_TARGET_FAMILIES, default="")
    parser.add_argument("--overwrite", action="store_true")
    return parser


def _resolve_dataset_path(args: argparse.Namespace) -> Path:
    path = (
        Path(args.dataset_path)
        if args.dataset_path
        else Path(args.dataset_root) / str(args.dataset_id)
    ).resolve()
    if not path.is_dir():
        raise TrainingError(f"Dataset folder does not exist: {path}")
    return path


def _prepare_model_dir(root: Path, model_id: str, overwrite: bool) -> Path:
    if not model_id or Path(model_id).name != model_id or model_id in (".", ".."):
        raise TrainingError(f"Invalid model ID: {model_id}")
    root = root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    output_dir = (root / model_id).resolve()
    if output_dir.parent != root:
        raise TrainingError(f"Refusing model output outside model root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise TrainingError(f"Model output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    return output_dir


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise TrainingError(f"Missing dataset manifest: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def load_training_rows(dataset_path: Path) -> list[dict[str, Any]]:
    matrix_path = dataset_path / "training_matrix.parquet"
    if not matrix_path.is_file():
        raise TrainingError(f"Missing training matrix: {matrix_path}")
    connection = duckdb.connect(":memory:")
    try:
        escaped = matrix_path.resolve().as_posix().replace("'", "''")
        relation = connection.execute(
            f"SELECT * FROM read_parquet('{escaped}') "
            "ORDER BY trigger_broker_time, run_id, signal_id"
        )
        columns = [column[0] for column in relation.description]
        return [dict(zip(columns, row)) for row in relation.fetchall()]
    finally:
        connection.close()


def _classification_metrics(
    actual: np.ndarray,
    probability: np.ndarray,
) -> dict[str, Any]:
    predicted = (probability >= 0.5).astype(np.int64)
    metrics: dict[str, Any] = {
        "rows": int(actual.size),
        "positive_rows": int(np.sum(actual == 1)),
        "negative_rows": int(np.sum(actual == 0)),
        "accuracy": float(accuracy_score(actual, predicted)),
        "balanced_accuracy": float(balanced_accuracy_score(actual, predicted)),
        "precision": float(precision_score(actual, predicted, zero_division=0)),
        "recall": float(recall_score(actual, predicted, zero_division=0)),
    }
    if len(np.unique(actual)) == 2:
        metrics.update(
            {
                "roc_auc": float(roc_auc_score(actual, probability)),
                "average_precision": float(average_precision_score(actual, probability)),
                "log_loss": float(log_loss(actual, probability, labels=[0, 1])),
            }
        )
    else:
        metrics.update({"roc_auc": None, "average_precision": None, "log_loss": None})
    return metrics


def _regression_metrics(actual: np.ndarray, predicted: np.ndarray) -> dict[str, Any]:
    correlation = None
    if actual.size > 1 and float(np.std(actual)) > 0.0 and float(np.std(predicted)) > 0.0:
        with np.errstate(divide="ignore", invalid="ignore"):
            candidate = float(np.corrcoef(actual, predicted)[0, 1])
        correlation = candidate if math.isfinite(candidate) else None
    return {
        "rows": int(actual.size),
        "mae": float(mean_absolute_error(actual, predicted)),
        "rmse": float(math.sqrt(mean_squared_error(actual, predicted))),
        "actual_mean_profit": float(np.mean(actual)),
        "predicted_mean_profit": float(np.mean(predicted)),
        "correlation": correlation,
    }


def _label_column(target_family: str) -> str:
    return "target_is_profit" if target_family == "broker_outcome" else "target_admitted"


def _label_array(rows: list[dict[str, Any]], target_family: str) -> np.ndarray:
    column = _label_column(target_family)
    if any(row.get(column) is None for row in rows):
        raise TrainingError(f"Training target contains null values: {column}")
    return np.asarray([int(bool(row[column])) for row in rows], dtype=np.int64)


def _profit_array(rows: list[dict[str, Any]]) -> np.ndarray:
    if any(row.get("target_realized_profit") is None for row in rows):
        raise TrainingError("Broker-outcome target contains null realized profit")
    return np.asarray(
        [float(row["target_realized_profit"]) for row in rows],
        dtype=np.float64,
    )


def _require_support(
    rows: list[dict[str, Any]],
    target_family: str,
    min_rows: int,
    min_class_count: int,
) -> None:
    if len(rows) < min_rows:
        raise TrainingError(f"Not enough rows: {len(rows)} < {min_rows}")
    labels = _label_array(rows, target_family)
    counts = {int(label): int(np.sum(labels == label)) for label in np.unique(labels)}
    if set(counts) != {0, 1}:
        raise TrainingError(f"Classifier target requires both classes: {counts}")
    if min(counts.values()) < min_class_count:
        raise TrainingError(
            f"Insufficient minority-class support: {min(counts.values())} < {min_class_count}"
        )


def _classifier(config) -> xgb.XGBClassifier:
    return xgb.XGBClassifier(**asdict(config))


def _regressor(config) -> xgb.XGBRegressor:
    return xgb.XGBRegressor(**asdict(config))


def _select(rows: list[dict[str, Any]], indices: list[int]) -> list[dict[str, Any]]:
    return [rows[index] for index in indices]


def _fit_and_score(
    rows: list[dict[str, Any]],
    train_indices: list[int],
    test_indices: list[int],
    target_family: str,
    feature_columns: tuple[str, ...],
    categorical_columns: tuple[str, ...],
    classifier_config,
    regressor_config,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    train_rows = _select(rows, train_indices)
    test_rows = _select(rows, test_indices)
    train_labels = _label_array(train_rows, target_family)
    test_labels = _label_array(test_rows, target_family)
    if len(np.unique(train_labels)) != 2:
        raise TrainingError("A chronological training fold contains only one class")

    encoder = FeatureEncoder.fit(
        train_rows,
        feature_columns,
        categorical_columns,
    )
    train_matrix = encoder.transform(train_rows).matrix
    test_matrix = encoder.transform(test_rows).matrix
    classifier = _classifier(classifier_config)
    classifier.fit(train_matrix, train_labels)
    probabilities = classifier.predict_proba(test_matrix)[:, 1]
    metrics: dict[str, Any] = {
        "classification": _classification_metrics(test_labels, probabilities)
    }
    predicted_profit: np.ndarray | None = None
    if target_family == "broker_outcome":
        regressor = _regressor(regressor_config)
        regressor.fit(train_matrix, _profit_array(train_rows))
        predicted_profit = regressor.predict(test_matrix)
        metrics["regression"] = _regression_metrics(
            _profit_array(test_rows),
            predicted_profit,
        )

    predictions: list[dict[str, Any]] = []
    for row, probability, label, index in zip(
        test_rows,
        probabilities,
        test_labels,
        test_indices,
    ):
        prediction = {
            "row_index": index,
            "run_id": row["run_id"],
            "signal_id": row["signal_id"],
            "window_id": row["window_id"],
            "trigger_broker_time": row["trigger_broker_time"],
            "actual_label": int(label),
            "predicted_probability": float(probability),
        }
        if predicted_profit is not None:
            local_index = len(predictions)
            prediction["actual_realized_profit"] = float(row["target_realized_profit"])
            prediction["predicted_realized_profit"] = float(predicted_profit[local_index])
        predictions.append(prediction)
    return metrics, predictions


def _write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    columns = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _render_report(manifest: dict[str, Any], metrics: dict[str, Any]) -> str:
    holdout = metrics["holdout"]["classification"]
    lines = [
        f"# Offline Pivot Model: {manifest['model_id']}",
        "",
        "Approval: `OFFLINE_RESEARCH_ONLY`",
        f"Dataset: `{manifest['dataset_id']}`",
        f"Target family: `{manifest['target_family']}`",
        f"Rows: `{manifest['training_rows']}`",
        "",
        "## Final Holdout",
        "",
        f"- Rows: `{holdout['rows']}`",
        f"- ROC AUC: `{holdout['roc_auc']}`",
        f"- Average precision: `{holdout['average_precision']}`",
        f"- Balanced accuracy: `{holdout['balanced_accuracy']}`",
        "",
        "This command does not emit or approve an MT5 runtime artifact.",
    ]
    return "\n".join(lines) + "\n"


def train_candidate(
    dataset_path: Path,
    output_dir: Path,
    model_id: str,
    feature_set_id: str,
    target_family: str,
) -> dict[str, Any]:
    dataset_manifest = _read_json(dataset_path / "dataset_manifest.json")
    if int(dataset_manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise TrainingError("Dataset schema version is incompatible with active tooling")
    manifest_feature_set_id = str(dataset_manifest.get("feature_set_id", ""))
    if not manifest_feature_set_id:
        raise TrainingError("Dataset manifest is missing feature_set_id")
    if feature_set_id and manifest_feature_set_id != feature_set_id:
        raise TrainingError("Dataset feature set differs from requested feature set")
    feature_set_id = manifest_feature_set_id
    feature_columns = tuple(dataset_manifest.get("feature_columns", ()))
    categorical_columns = tuple(dataset_manifest.get("categorical_columns", ()))
    if not feature_columns or len(set(feature_columns)) != len(feature_columns):
        raise TrainingError("Dataset manifest has an invalid feature column contract")
    if not set(categorical_columns).issubset(set(feature_columns)):
        raise TrainingError("Dataset manifest has invalid categorical feature columns")
    denied_features = {
        *FUTURE_ONLY_COLUMNS,
        *TARGET_COLUMNS,
        "signal_id",
        "window_id",
        "research_group_id",
        "canonical_member_tokens",
    }
    leaked_features = sorted(set(feature_columns) & denied_features)
    if leaked_features:
        raise TrainingError(f"Dataset feature contract contains denied fields: {leaked_features}")
    if dataset_manifest.get("approval_state") != "OFFLINE_RESEARCH_ONLY":
        raise TrainingError("Dataset is missing the offline-only research boundary")
    manifest_target = str(dataset_manifest.get("target_family", ""))
    if target_family and target_family != manifest_target:
        raise TrainingError(
            f"Dataset target family is {manifest_target}, requested {target_family}"
        )
    target_family = manifest_target
    if target_family not in DATASET_TARGET_FAMILIES:
        raise TrainingError(f"Unsupported dataset target family: {target_family}")

    config = training_config_for_feature_set(feature_set_id)
    rows = load_training_rows(dataset_path)
    if not rows:
        raise TrainingError("Training matrix is empty")
    missing_columns = [column for column in feature_columns if column not in rows[0]]
    if missing_columns:
        raise TrainingError(f"Training matrix is missing manifest features: {missing_columns}")
    _require_support(rows, target_family, config.min_training_rows, config.min_class_count)
    grouping_policy = str(
        dataset_manifest.get("split_grouping_policy", "pivot_window_identity")
    )
    splits = build_time_splits(
        rows,
        holdout_fraction=config.holdout_fraction,
        n_splits=config.walk_forward_splits,
        gap=config.walk_forward_gap,
        grouping_policy=grouping_policy,
    )

    fold_metrics: list[dict[str, Any]] = []
    fold_predictions: list[dict[str, Any]] = []
    for fold in splits.folds:
        metrics, predictions = _fit_and_score(
            rows,
            fold.train_indices,
            fold.test_indices,
            target_family,
            feature_columns,
            categorical_columns,
            config.classifier,
            config.regressor,
        )
        fold_metrics.append({"fold_index": fold.fold_index, **metrics})
        fold_predictions.extend(
            {"split": f"fold_{fold.fold_index}", **row} for row in predictions
        )

    holdout_metrics, holdout_predictions = _fit_and_score(
        rows,
        splits.train_indices,
        splits.holdout_indices,
        target_family,
        feature_columns,
        categorical_columns,
        config.classifier,
        config.regressor,
    )

    final_train_rows = _select(rows, splits.train_indices)
    final_encoder = FeatureEncoder.fit(
        final_train_rows,
        feature_columns,
        categorical_columns,
    )
    final_matrix = final_encoder.transform(final_train_rows).matrix
    classifier = _classifier(config.classifier)
    classifier.fit(final_matrix, _label_array(final_train_rows, target_family))
    classifier.get_booster().save_model(str(output_dir / "classifier.json"))
    regressor_written = False
    if target_family == "broker_outcome":
        regressor = _regressor(config.regressor)
        regressor.fit(final_matrix, _profit_array(final_train_rows))
        regressor.get_booster().save_model(str(output_dir / "regressor.json"))
        regressor_written = True
    final_encoder.write_json(output_dir / "feature_encoder.json")

    metrics_payload = {
        "split_policy": splits.metadata,
        "folds": fold_metrics,
        "holdout": holdout_metrics,
    }
    (output_dir / "metrics.json").write_text(
        json.dumps(metrics_payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )
    _write_tsv(output_dir / "fold_predictions.tsv", fold_predictions)
    _write_tsv(
        output_dir / "holdout_predictions.tsv",
        [{"split": "final_holdout", **row} for row in holdout_predictions],
    )

    model_manifest = {
        "model_id": model_id,
        "trainer_version": TRAINER_VERSION,
        "created_at": datetime.now(UTC).isoformat(),
        "dataset_id": dataset_manifest["dataset_id"],
        "dataset_path": str(dataset_path),
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "feature_set_id": feature_set_id,
        "source_feature_set_id": dataset_manifest.get("source_feature_set_id"),
        "research_feature_set_id": dataset_manifest.get("research_feature_set_id"),
        "feature_columns": list(feature_columns),
        "categorical_columns": list(categorical_columns),
        "split_grouping_policy": grouping_policy,
        "target_family": target_family,
        "training_rows": len(rows),
        "train_partition_rows": len(splits.train_indices),
        "holdout_rows": len(splits.holdout_indices),
        "encoded_feature_count": len(final_encoder.encoded_feature_names),
        "classifier_config": asdict(config.classifier),
        "regressor_config": asdict(config.regressor) if regressor_written else None,
        "approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact_emitted": False,
    }
    (output_dir / "model_manifest.json").write_text(
        json.dumps(model_manifest, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    (output_dir / "model_report.md").write_text(
        _render_report(model_manifest, metrics_payload),
        encoding="utf-8",
    )
    return model_manifest


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_path = _resolve_dataset_path(args)
        output_dir = _prepare_model_dir(Path(args.model_root), args.model_id, args.overwrite)
        manifest = train_candidate(
            dataset_path,
            output_dir,
            args.model_id,
            args.feature_set_id,
            args.target_family,
        )
    except (TrainingError, ValueError, json.JSONDecodeError, duckdb.Error, xgb.core.XGBoostError) as exc:
        parser.exit(1, f"offline pivot model training failed: {exc}\n")

    print(
        "offline pivot model training ok | "
        f"model={manifest['model_id']} | target={manifest['target_family']} | "
        f"rows={manifest['training_rows']} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
