"""Train offline-only V10 XGBoost binary candidates with ordered ablations."""

from __future__ import annotations

import argparse
import csv
import json
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
    precision_score,
    recall_score,
    roc_auc_score,
)

from feature_encoder import FeatureEncoder
from model_config import (
    DEFAULT_DATASET_ROOT,
    DEFAULT_MODEL_ROOT,
    FEATURE_ABLATIONS,
    TRAINER_VERSION,
    training_config_for_feature_set,
)
from schema_contract import (
    CATEGORICAL_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TARGET_COLUMNS,
)
from validation_splits import GROUPING_POLICY, build_time_splits


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
    matrix_path = dataset_path / "binary_outcomes.parquet"
    if not matrix_path.is_file():
        raise TrainingError(f"Missing binary outcomes matrix: {matrix_path}")
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


def _labels(rows: list[dict[str, Any]]) -> np.ndarray:
    if any(row.get("binary_target") not in (0, 1, False, True) for row in rows):
        raise TrainingError("Binary cohort contains a null or invalid target")
    return np.asarray([int(row["binary_target"]) for row in rows], dtype=np.int64)


def _require_support(rows: list[dict[str, Any]], min_rows: int, min_class_count: int) -> None:
    if len(rows) < min_rows:
        raise TrainingError(f"Not enough rows: {len(rows)} < {min_rows}")
    labels = _labels(rows)
    counts = {int(label): int(np.sum(labels == label)) for label in np.unique(labels)}
    if set(counts) != {0, 1}:
        raise TrainingError(f"Classifier target requires both classes: {counts}")
    if min(counts.values()) < min_class_count:
        raise TrainingError(
            f"Insufficient minority-class support: {min(counts.values())} < {min_class_count}"
        )


def _classifier(config) -> xgb.XGBClassifier:
    return xgb.XGBClassifier(**asdict(config))


def _select(rows: list[dict[str, Any]], indices: list[int]) -> list[dict[str, Any]]:
    return [rows[index] for index in indices]


def _fit_and_score(
    rows: list[dict[str, Any]],
    train_indices: list[int],
    test_indices: list[int],
    feature_columns: tuple[str, ...],
    classifier_config,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    train_rows = _select(rows, train_indices)
    test_rows = _select(rows, test_indices)
    train_labels = _labels(train_rows)
    test_labels = _labels(test_rows)
    if len(np.unique(train_labels)) != 2:
        raise TrainingError("A chronological training fold contains only one class")
    categorical = tuple(
        column for column in CATEGORICAL_COLUMNS if column in feature_columns
    )
    encoder = FeatureEncoder.fit(train_rows, feature_columns, categorical)
    classifier = _classifier(classifier_config)
    classifier.fit(encoder.transform(train_rows).matrix, train_labels)
    probability = classifier.predict_proba(encoder.transform(test_rows).matrix)[:, 1]
    predictions = [
        {
            "row_index": row_index,
            "run_id": row["run_id"],
            "signal_id": row["signal_id"],
            "research_group_id": row["research_group_id"],
            "trigger_broker_time": row["trigger_broker_time"],
            "close_broker_time": row["close_broker_time"],
            "actual_label": int(label),
            "predicted_probability": float(score),
        }
        for row, label, score, row_index in zip(
            test_rows,
            test_labels,
            probability,
            test_indices,
        )
    ]
    return _classification_metrics(test_labels, probability), predictions


def _write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    columns = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def _render_report(manifest: dict[str, Any], metrics: dict[str, Any]) -> str:
    lines = [
        f"# Offline Pivot V10 Model: {manifest['model_id']}",
        "",
        "Approval: `OFFLINE_RESEARCH_ONLY`",
        f"Dataset: `{manifest['dataset_id']}`",
        f"Binary rows: `{manifest['training_rows']}`",
        "",
        "## Ablations",
        "",
    ]
    for ablation_id, payload in metrics["ablations"].items():
        holdout = payload["holdout"]
        lines.append(
            f"- `{ablation_id}`: ROC AUC `{holdout['roc_auc']}`, "
            f"balanced accuracy `{holdout['balanced_accuracy']}`"
        )
    lines.extend(
        [
            "",
            "The saved classifiers are offline research candidates only; no MT5 runtime artifact is emitted.",
        ]
    )
    return "\n".join(lines) + "\n"


def train_candidate(
    dataset_path: Path,
    output_dir: Path,
    model_id: str,
    feature_set_id: str = "",
) -> dict[str, Any]:
    dataset_manifest = _read_json(dataset_path / "dataset_manifest.json")
    if int(dataset_manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise TrainingError("Dataset schema version is incompatible with active tooling")
    manifest_feature_set = str(dataset_manifest.get("feature_set_id", ""))
    if feature_set_id and feature_set_id != manifest_feature_set:
        raise TrainingError("Dataset feature set differs from requested feature set")
    if manifest_feature_set != SUPPORTED_FEATURE_SET_ID:
        raise TrainingError(f"Unsupported dataset feature set: {manifest_feature_set}")
    feature_columns = tuple(dataset_manifest.get("feature_columns", ()))
    if feature_columns != MODEL_FEATURE_COLUMNS:
        raise TrainingError("Dataset manifest does not carry the exact V10 feature contract")
    denied = {*FUTURE_ONLY_COLUMNS, *TARGET_COLUMNS}
    leaked = sorted(set(feature_columns) & denied)
    if leaked:
        raise TrainingError(f"Dataset feature contract contains denied fields: {leaked}")
    if dataset_manifest.get("approval_state") != "OFFLINE_RESEARCH_ONLY":
        raise TrainingError("Dataset is missing the offline-only research boundary")
    if dataset_manifest.get("split_grouping_policy") != GROUPING_POLICY:
        raise TrainingError("Dataset split grouping policy is incompatible")

    config = training_config_for_feature_set(manifest_feature_set)
    rows = load_training_rows(dataset_path)
    if not rows:
        raise TrainingError("Binary outcomes matrix is empty")
    missing_columns = [column for column in MODEL_FEATURE_COLUMNS if column not in rows[0]]
    if missing_columns:
        raise TrainingError(f"Binary matrix is missing model features: {missing_columns}")
    _require_support(rows, config.min_training_rows, config.min_class_count)
    splits = build_time_splits(
        rows,
        holdout_fraction=config.holdout_fraction,
        n_splits=config.walk_forward_splits,
        gap=config.walk_forward_gap,
        grouping_policy=GROUPING_POLICY,
    )

    metrics_payload: dict[str, Any] = {
        "split_policy": splits.metadata,
        "ablations": {},
    }
    prediction_rows: list[dict[str, Any]] = []
    model_files: dict[str, str] = {}
    encoder_files: dict[str, str] = {}
    final_train_rows = _select(rows, splits.train_indices)
    for ablation_id, ablation_columns in FEATURE_ABLATIONS:
        fold_metrics: list[dict[str, Any]] = []
        for fold in splits.folds:
            metrics, predictions = _fit_and_score(
                rows,
                fold.train_indices,
                fold.test_indices,
                ablation_columns,
                config.classifier,
            )
            fold_metrics.append({"fold_index": fold.fold_index, **metrics})
            prediction_rows.extend(
                {
                    "ablation": ablation_id,
                    "split": f"fold_{fold.fold_index}",
                    **row,
                }
                for row in predictions
            )
        holdout_metrics, holdout_predictions = _fit_and_score(
            rows,
            splits.train_indices,
            splits.holdout_indices,
            ablation_columns,
            config.classifier,
        )
        prediction_rows.extend(
            {"ablation": ablation_id, "split": "final_holdout", **row}
            for row in holdout_predictions
        )
        metrics_payload["ablations"][ablation_id] = {
            "feature_columns": list(ablation_columns),
            "folds": fold_metrics,
            "holdout": holdout_metrics,
        }

        categorical = tuple(
            column for column in CATEGORICAL_COLUMNS if column in ablation_columns
        )
        encoder = FeatureEncoder.fit(final_train_rows, ablation_columns, categorical)
        classifier = _classifier(config.classifier)
        classifier.fit(encoder.transform(final_train_rows).matrix, _labels(final_train_rows))
        model_path = output_dir / f"offline_classifier_{ablation_id}.json"
        encoder_path = output_dir / f"feature_encoder_{ablation_id}.json"
        classifier.get_booster().save_model(str(model_path))
        encoder.write_json(encoder_path)
        model_files[ablation_id] = model_path.name
        encoder_files[ablation_id] = encoder_path.name

    (output_dir / "ablation_metrics.json").write_text(
        json.dumps(metrics_payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )
    _write_tsv(output_dir / "predictions.tsv", prediction_rows)
    model_manifest = {
        "model_id": model_id,
        "trainer_version": TRAINER_VERSION,
        "created_at": datetime.now(UTC).isoformat(),
        "dataset_id": dataset_manifest["dataset_id"],
        "dataset_path": str(dataset_path),
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "feature_set_id": manifest_feature_set,
        "feature_ablations": {
            ablation_id: list(columns) for ablation_id, columns in FEATURE_ABLATIONS
        },
        "split_grouping_policy": GROUPING_POLICY,
        "training_rows": len(rows),
        "train_partition_rows": len(splits.train_indices),
        "holdout_rows": len(splits.holdout_indices),
        "classifier_config": asdict(config.classifier),
        "model_files": model_files,
        "encoder_files": encoder_files,
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
        )
    except (
        TrainingError,
        ValueError,
        json.JSONDecodeError,
        duckdb.Error,
        xgb.core.XGBoostError,
    ) as exc:
        parser.exit(1, f"offline pivot V10 model training failed: {exc}\n")

    print(
        "offline pivot V10 model training ok | "
        f"model={manifest['model_id']} | rows={manifest['training_rows']} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
