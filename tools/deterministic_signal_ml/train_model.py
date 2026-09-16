"""Train an offline-only V14 H1 or deep-parent classifier candidate."""

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
    EVENT_WEIGHT_POLICY,
    ORIGIN_WEIGHT_POLICY,
    TRAINER_VERSION,
    categorical_columns_for_set,
    feature_ablations_for_set,
    model_feature_columns_for_set,
    source_grain_for_set,
    training_config_for_feature_set,
    training_table_for_set,
)
from schema_contract import (
    DEEP_FEATURE_SET_ID,
    DEEP_SIGNAL_FEATURE_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    H1_FEATURE_SET_ID,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TARGET_COLUMNS,
)
from validation_splits import (
    GROUPING_POLICY,
    build_time_splits,
    origin_balanced_weights,
)


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
    parser.add_argument(
        "--feature-set-id",
        required=True,
        choices=(H1_FEATURE_SET_ID, DEEP_FEATURE_SET_ID),
    )
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


def load_training_rows(
    dataset_path: Path,
    feature_set_id: str,
) -> list[dict[str, Any]]:
    table_name = training_table_for_set(feature_set_id)
    cohort_path = dataset_path / f"{table_name}.parquet"
    if not cohort_path.is_file():
        raise TrainingError(f"Missing training cohort: {cohort_path}")
    order = (
        "declared_broker_time, run_id, origin_id, entry_policy, tp_r_multiple"
        if feature_set_id == H1_FEATURE_SET_ID
        else "declared_broker_time, run_id, origin_id, deep_event_id, "
        "parent_link_id, tp_r_multiple"
    )
    connection = duckdb.connect(":memory:")
    try:
        escaped_cohort = cohort_path.resolve().as_posix().replace("'", "''")
        if feature_set_id == H1_FEATURE_SET_ID:
            query = f"SELECT * FROM read_parquet('{escaped_cohort}') ORDER BY {order}"
        else:
            event_path = dataset_path / "deep_pivot_events.parquet"
            if not event_path.is_file():
                raise TrainingError(f"Missing deep event feature source: {event_path}")
            escaped_events = event_path.resolve().as_posix().replace("'", "''")
            event_features = ",\n  ".join(
                f"event.\"{column}\"" for column in DEEP_SIGNAL_FEATURE_COLUMNS
            )
            query = f"""
SELECT
  cohort.*,
  {event_features}
FROM read_parquet('{escaped_cohort}') cohort
JOIN read_parquet('{escaped_events}') event
  USING (run_id, config_id, deep_event_id)
ORDER BY {order}
"""
        relation = connection.execute(query)
        columns = [column[0] for column in relation.description]
        rows = [dict(zip(columns, row)) for row in relation.fetchall()]
        expected_rows = int(
            connection.execute(
                f"SELECT count(*) FROM read_parquet('{escaped_cohort}')"
            ).fetchone()[0]
        )
        if len(rows) != expected_rows:
            raise TrainingError(
                "Training feature load changed cohort cardinality: "
                f"{len(rows)} != {expected_rows}"
            )
        return rows
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
    if any(row.get("virtual_binary_target") not in (0, 1, False, True) for row in rows):
        raise TrainingError("Binary cohort contains a null or invalid target")
    return np.asarray([int(row["virtual_binary_target"]) for row in rows], dtype=np.int64)


def _require_support(
    rows: list[dict[str, Any]],
    min_rows: int,
    min_origins: int,
    min_class_count: int,
    min_class_origin_count: int,
) -> None:
    if len(rows) < min_rows:
        raise TrainingError(f"Not enough rows: {len(rows)} < {min_rows}")
    origin_ids = {str(row.get("origin_id", "")) for row in rows}
    if "" in origin_ids:
        raise TrainingError("Training cohort contains a row without origin_id")
    if len(origin_ids) < min_origins:
        raise TrainingError(f"Not enough unique origins: {len(origin_ids)} < {min_origins}")
    labels = _labels(rows)
    counts = {int(label): int(np.sum(labels == label)) for label in np.unique(labels)}
    if set(counts) != {0, 1}:
        raise TrainingError(f"Classifier target requires both classes: {counts}")
    if min(counts.values()) < min_class_count:
        raise TrainingError(
            f"Insufficient minority-class support: {min(counts.values())} < {min_class_count}"
        )
    class_origins = {
        label: {
            str(row["origin_id"])
            for row in rows
            if int(row["virtual_binary_target"]) == label
        }
        for label in (0, 1)
    }
    minority_origin_count = min(len(origins) for origins in class_origins.values())
    if minority_origin_count < min_class_origin_count:
        raise TrainingError(
            "Insufficient minority-class unique-origin support: "
            f"{minority_origin_count} < {min_class_origin_count}"
        )


def _classifier(config: Any) -> xgb.XGBClassifier:
    return xgb.XGBClassifier(**asdict(config))


def _select(rows: list[dict[str, Any]], indices: list[int]) -> list[dict[str, Any]]:
    return [rows[index] for index in indices]


def _prediction_identity(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "run_id": row["run_id"],
        "origin_id": row["origin_id"],
        "trial_id": row.get("trial_id"),
        "deep_event_id": row.get("deep_event_id"),
        "parent_link_id": row.get("parent_link_id"),
        "deep_trial_id": row.get("deep_trial_id"),
        "research_group_id": row["research_group_id"],
        "declared_broker_time": row["declared_broker_time"],
        "terminal_broker_time": row["terminal_broker_time"],
    }


def _fit_and_score(
    rows: list[dict[str, Any]],
    train_indices: list[int],
    test_indices: list[int],
    feature_columns: tuple[str, ...],
    categorical_columns: tuple[str, ...],
    classifier_config: Any,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    train_rows = _select(rows, train_indices)
    test_rows = _select(rows, test_indices)
    train_labels = _labels(train_rows)
    test_labels = _labels(test_rows)
    if len(np.unique(train_labels)) != 2:
        raise TrainingError("A chronological training fold contains only one class")
    categorical = tuple(column for column in categorical_columns if column in feature_columns)
    encoder = FeatureEncoder.fit(train_rows, feature_columns, categorical)
    classifier = _classifier(classifier_config)
    classifier.fit(
        encoder.transform(train_rows).matrix,
        train_labels,
        sample_weight=np.asarray(
            origin_balanced_weights(rows, train_indices),
            dtype=np.float64,
        ),
    )
    probability = classifier.predict_proba(encoder.transform(test_rows).matrix)[:, 1]
    predictions = [
        {
            "row_index": row_index,
            **_prediction_identity(row),
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
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(rows[0]),
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def _render_report(manifest: dict[str, Any], metrics: dict[str, Any]) -> str:
    lines = [
        f"# Offline Pivot V14 Model: {manifest['model_id']}",
        "",
        "Approval: `OFFLINE_RESEARCH_ONLY`",
        f"Evidence grain: `{manifest['source_grain']}`",
        f"Feature set: `{manifest['feature_set_id']}`",
        f"Training rows: `{manifest['training_rows']}`",
        f"Holdout cutoff: `{manifest['split_metadata']['holdout_boundary']}`",
        f"Weighting: `{manifest['origin_weight_policy']}`",
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
            "The candidate is offline research only. It is not an MT5 runtime artifact and cannot filter execution.",
        ]
    )
    return "\n".join(lines) + "\n"


def train_candidate(
    dataset_path: Path,
    output_dir: Path,
    model_id: str,
    feature_set_id: str,
) -> dict[str, Any]:
    dataset_manifest = _read_json(dataset_path / "dataset_manifest.json")
    if int(dataset_manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise TrainingError("Dataset schema version is incompatible with active tooling")
    if dataset_manifest.get("feature_set_id") != SUPPORTED_FEATURE_SET_ID:
        raise TrainingError("Dataset producer feature set is incompatible with active tooling")
    if feature_set_id not in dataset_manifest.get("available_feature_set_ids", ()):
        raise TrainingError("Dataset does not advertise the requested evidence grain")
    feature_columns = model_feature_columns_for_set(feature_set_id)
    categorical_columns = categorical_columns_for_set(feature_set_id)
    feature_ablations = feature_ablations_for_set(feature_set_id)
    feature_contracts = dataset_manifest.get("feature_contracts", {})
    feature_contract = feature_contracts.get(feature_set_id)
    if not isinstance(feature_contract, dict):
        raise TrainingError("Dataset manifest lacks the requested evidence-grain contract")
    if tuple(feature_contract.get("model_features", ())) != feature_columns:
        raise TrainingError("Dataset manifest does not carry the exact V14 feature contract")
    denied = {*FUTURE_ONLY_COLUMNS, *TARGET_COLUMNS}
    leaked = sorted(set(feature_columns) & denied)
    if leaked:
        raise TrainingError(f"Dataset feature contract contains denied fields: {leaked}")
    if dataset_manifest.get("research_approval_state") != "OFFLINE_RESEARCH_ONLY":
        raise TrainingError("Dataset is missing the offline-only research boundary")
    if feature_contract.get("grouping_policy") != GROUPING_POLICY:
        raise TrainingError("Dataset split grouping policy is incompatible")
    if feature_contract.get("origin_weight_policy") != ORIGIN_WEIGHT_POLICY:
        raise TrainingError("Dataset origin-weight policy is incompatible")
    if feature_contract.get("target") != "virtual_binary_target":
        raise TrainingError("Dataset target is not the V14 virtual target")
    if feature_contract.get("training_table") != training_table_for_set(feature_set_id):
        raise TrainingError("Dataset training-table contract is incompatible")
    if feature_contract.get("source_grain") != source_grain_for_set(feature_set_id):
        raise TrainingError("Dataset source-grain contract is incompatible")
    if feature_set_id == DEEP_FEATURE_SET_ID:
        if feature_contract.get("event_feature_source") != "deep_pivot_events":
            raise TrainingError("Dataset deep event feature source is incompatible")
        if feature_contract.get("event_feature_join") != [
            "run_id",
            "config_id",
            "deep_event_id",
        ]:
            raise TrainingError("Dataset deep event feature join is incompatible")
        if feature_contract.get("event_features_native_grain") is not True:
            raise TrainingError("Dataset does not preserve deep features at event grain")
        if feature_contract.get("event_features_persisted_in_training_table") is not False:
            raise TrainingError("Dataset persists deep event features at parent grain")
        if feature_contract.get("event_weight_policy") != EVENT_WEIGHT_POLICY:
            raise TrainingError("Dataset deep event-weight policy is incompatible")

    config = training_config_for_feature_set(feature_set_id)
    rows = load_training_rows(dataset_path, feature_set_id)
    if not rows:
        raise TrainingError("Requested binary cohort is empty")
    missing_columns = [column for column in feature_columns if column not in rows[0]]
    if missing_columns:
        raise TrainingError(f"Binary cohort is missing model features: {missing_columns}")
    incomplete_rows = sum(
        any(row.get(column) is None for column in feature_columns) for row in rows
    )
    if incomplete_rows:
        raise TrainingError(
            f"Binary cohort contains {incomplete_rows} incomplete feature rows"
        )
    _require_support(
        rows,
        config.min_training_rows,
        config.min_training_origins,
        config.min_class_count,
        config.min_class_origin_count,
    )
    splits = build_time_splits(
        rows,
        holdout_fraction=config.holdout_fraction,
        n_splits=config.walk_forward_splits,
        gap=config.walk_forward_gap,
        grouping_policy=GROUPING_POLICY,
    )

    metrics_payload: dict[str, Any] = {
        "source_grain": source_grain_for_set(feature_set_id),
        "feature_set_id": feature_set_id,
        "split_policy": splits.metadata,
        "ablations": {},
    }
    prediction_rows: list[dict[str, Any]] = []
    model_files: dict[str, str] = {}
    encoder_files: dict[str, str] = {}
    final_train_rows = _select(rows, splits.train_indices)
    for ablation_id, ablation_columns in feature_ablations:
        fold_metrics: list[dict[str, Any]] = []
        for fold in splits.folds:
            metrics, predictions = _fit_and_score(
                rows,
                fold.train_indices,
                fold.test_indices,
                ablation_columns,
                categorical_columns,
                config.classifier,
            )
            fold_metrics.append({"fold_index": fold.fold_index, **metrics})
            prediction_rows.extend(
                {"ablation": ablation_id, "split": f"fold_{fold.fold_index}", **row}
                for row in predictions
            )
        holdout_metrics, holdout_predictions = _fit_and_score(
            rows,
            splits.train_indices,
            splits.holdout_indices,
            ablation_columns,
            categorical_columns,
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
            column for column in categorical_columns if column in ablation_columns
        )
        encoder = FeatureEncoder.fit(final_train_rows, ablation_columns, categorical)
        classifier = _classifier(config.classifier)
        classifier.fit(
            encoder.transform(final_train_rows).matrix,
            _labels(final_train_rows),
            sample_weight=np.asarray(
                origin_balanced_weights(rows, splits.train_indices),
                dtype=np.float64,
            ),
        )
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
        "feature_set_id": feature_set_id,
        "source_grain": source_grain_for_set(feature_set_id),
        "feature_ablations": {
            ablation_id: list(columns) for ablation_id, columns in feature_ablations
        },
        "split_grouping_policy": GROUPING_POLICY,
        "origin_weight_policy": ORIGIN_WEIGHT_POLICY,
        "event_weight_policy": (
            EVENT_WEIGHT_POLICY if feature_set_id == DEEP_FEATURE_SET_ID else None
        ),
        "split_metadata": splits.metadata,
        "training_rows": len(rows),
        "train_partition_rows": len(splits.train_indices),
        "holdout_rows": len(splits.holdout_indices),
        "classifier_config": asdict(config.classifier),
        "support_config": {
            "min_training_rows": config.min_training_rows,
            "min_training_origins": config.min_training_origins,
            "min_class_count": config.min_class_count,
            "min_class_origin_count": config.min_class_origin_count,
        },
        "model_files": model_files,
        "encoder_files": encoder_files,
        "warnings": [
            "H1 lifecycle duration and all terminal fields are excluded from features.",
            *(
                [
                    "Deep event features are joined from native event grain only during explicit model loading.",
                    "Deep parent rows are origin-weighted so repeated M10 events cannot inflate support.",
                ]
                if feature_set_id == DEEP_FEATURE_SET_ID
                else []
            ),
        ],
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
        parser.exit(1, f"offline pivot V14 model training failed: {exc}\n")

    print(
        "offline pivot V14 model training ok | "
        f"model={manifest['model_id']} | grain={manifest['source_grain']} | "
        f"rows={manifest['training_rows']} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
