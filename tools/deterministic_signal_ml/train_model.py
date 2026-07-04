"""Train deterministic signal local ML models from Phase 2 datasets."""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import asdict
from pathlib import Path

import duckdb
import numpy as np
from xgboost import XGBClassifier, XGBRegressor

from feature_encoder import FeatureEncoder
from model_config import DEFAULT_DATASET_ROOT, DEFAULT_MODEL_ROOT, TRAINER_VERSION, TrainingConfig
from training_report import (
    classification_metrics,
    evaluate_baselines,
    feature_diagnostics,
    feature_importance,
    regression_metrics,
    render_validation_report,
)
from validation_splits import SplitBundle, build_time_splits


class TrainingInputError(RuntimeError):
    """Raised when training cannot proceed because an input is invalid."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id", help="Dataset ID under the dataset root.")
    dataset_group.add_argument("--dataset-path", help="Explicit Phase 2 dataset folder.")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT, help="Dataset root for --dataset-id.")
    parser.add_argument("--model-id", required=True, help="Model output ID.")
    parser.add_argument("--output-root", default=DEFAULT_MODEL_ROOT, help="Model artifact output root.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing model folder.")
    return parser


def resolve_dataset_path(args: argparse.Namespace) -> Path:
    if args.dataset_path:
        dataset_path = Path(args.dataset_path)
    else:
        dataset_path = Path(args.dataset_root) / args.dataset_id
    if not dataset_path.exists():
        raise TrainingInputError(f"Dataset folder does not exist: {dataset_path}")
    if not dataset_path.is_dir():
        raise TrainingInputError(f"Dataset path is not a folder: {dataset_path}")
    return dataset_path


def load_dataset_manifest(dataset_path: Path) -> dict:
    manifest_path = dataset_path / "dataset_manifest.json"
    quality_path = dataset_path / "dataset_quality.json"
    matrix_path = dataset_path / "training_matrix.parquet"
    missing = [path for path in (manifest_path, quality_path, matrix_path) if not path.exists()]
    if missing:
        missing_names = ", ".join(str(path) for path in missing)
        raise TrainingInputError(f"Dataset is missing required files: {missing_names}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    quality = json.loads(quality_path.read_text(encoding="utf-8"))
    if quality.get("status") != "OK":
        raise TrainingInputError(f"Dataset quality status is not OK: {quality.get('status')!r}")
    return manifest


def prepare_output_dir(output_root: Path, model_id: str, overwrite: bool) -> Path:
    output_dir = output_root / model_id
    resolved_root = output_root.resolve()
    resolved_output = output_dir.resolve()
    if resolved_output == resolved_root or resolved_root not in resolved_output.parents:
        raise TrainingInputError(f"Refusing model output outside output root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise TrainingInputError(f"Model output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    return output_dir


def load_training_rows(dataset_path: Path) -> list[dict]:
    matrix_path = dataset_path / "training_matrix.parquet"
    parquet_path = matrix_path.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect(":memory:")
    try:
        relation = connection.execute(
            f"SELECT * FROM read_parquet('{parquet_path}') ORDER BY entry_time, signal_id"
        )
        columns = [column[0] for column in relation.description]
        return [dict(zip(columns, row)) for row in relation.fetchall()]
    finally:
        connection.close()


def validate_training_rows(rows: list[dict], manifest: dict, config: TrainingConfig) -> None:
    if len(rows) < config.min_training_rows:
        raise TrainingInputError(
            f"Dataset has {len(rows)} rows; minimum required is {config.min_training_rows}"
        )

    feature_columns = list(manifest.get("feature_columns", []))
    target_columns = list(manifest.get("target_columns", []))
    if not feature_columns:
        raise TrainingInputError("Dataset manifest does not define feature_columns")

    required_targets = ("target_is_win", "target_profit_r", "target_terminal_reason")
    missing_manifest_targets = [column for column in required_targets if column not in target_columns]
    if missing_manifest_targets:
        raise TrainingInputError(
            "Dataset manifest is missing target columns: " + ", ".join(missing_manifest_targets)
        )

    first_row = rows[0]
    missing_matrix_columns = [
        column for column in feature_columns + list(required_targets) if column not in first_row
    ]
    if missing_matrix_columns:
        raise TrainingInputError(
            "Training matrix is missing columns: " + ", ".join(missing_matrix_columns)
        )

    class_counts: dict[int, int] = {}
    for row in rows:
        target = int(row["target_is_win"])
        class_counts[target] = class_counts.get(target, 0) + 1
    if sorted(class_counts) != [0, 1]:
        raise TrainingInputError(f"target_is_win must contain both classes 0 and 1: {class_counts}")
    small_classes = {
        target: count for target, count in class_counts.items() if count < config.min_class_count
    }
    if small_classes:
        raise TrainingInputError(
            f"target_is_win class counts below {config.min_class_count}: {small_classes}"
        )


def write_training_input_summary(
    output_dir: Path,
    model_id: str,
    manifest: dict,
    rows: list[dict],
    encoder: FeatureEncoder,
) -> None:
    class_counts: dict[str, int] = {}
    for row in rows:
        target = str(int(row["target_is_win"]))
        class_counts[target] = class_counts.get(target, 0) + 1

    summary = {
        "trainer_version": TRAINER_VERSION,
        "model_id": model_id,
        "dataset_id": manifest.get("dataset_id"),
        "source_run_ids": manifest.get("source_run_ids", []),
        "config_ids": manifest.get("config_ids", []),
        "row_count": len(rows),
        "target_is_win_counts": class_counts,
        "feature_columns": list(manifest.get("feature_columns", [])),
        "target_columns": list(manifest.get("target_columns", [])),
        "encoded_feature_count": len(encoder.encoded_feature_names),
        "encoded_feature_names": encoder.encoded_feature_names,
    }
    summary_path = output_dir / "training_input_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8")


def write_validation_outputs(
    output_dir: Path,
    model_id: str,
    manifest: dict,
    split_metadata: dict,
    baseline_metrics: dict,
    xgboost_metrics: dict | None = None,
    diagnostics: dict | None = None,
) -> None:
    dataset_id = str(manifest.get("dataset_id", ""))
    metrics = {
        "trainer_version": TRAINER_VERSION,
        "model_id": model_id,
        "dataset_id": dataset_id,
        "source_run_ids": manifest.get("source_run_ids", []),
        "config_ids": manifest.get("config_ids", []),
        "split_metadata": split_metadata,
        "baseline_metrics": baseline_metrics,
        "xgboost_metrics": xgboost_metrics,
        "feature_diagnostics": diagnostics,
    }
    metrics_path = output_dir / "validation_metrics.json"
    report_path = output_dir / "validation_report.md"
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True), encoding="utf-8")
    report = render_validation_report(
        model_id,
        dataset_id,
        split_metadata,
        baseline_metrics,
        xgboost_metrics=xgboost_metrics,
        diagnostics=diagnostics,
    )
    report_path.write_text(report, encoding="utf-8")


def train_xgboost_models(
    output_dir: Path,
    rows: list[dict],
    encoded_matrix: np.ndarray,
    encoded_feature_names: list[str],
    split_bundle: SplitBundle,
    config: TrainingConfig,
) -> tuple[dict, dict]:
    y_win = np.asarray([int(row["target_is_win"]) for row in rows], dtype=np.int64)
    y_profit = np.asarray([float(row["target_profit_r"]) for row in rows], dtype=np.float64)

    train_indices = np.asarray(split_bundle.train_indices, dtype=np.int64)
    holdout_indices = np.asarray(split_bundle.holdout_indices, dtype=np.int64)
    classifier = _fit_classifier(
        encoded_matrix[train_indices],
        y_win[train_indices],
        encoded_matrix[holdout_indices],
        y_win[holdout_indices],
        config,
    )
    regressor = _fit_regressor(
        encoded_matrix[train_indices],
        y_profit[train_indices],
        encoded_matrix[holdout_indices],
        y_profit[holdout_indices],
        config,
    )

    classifier_path = output_dir / "classifier_xgboost.json"
    regressor_path = output_dir / "regressor_xgboost.json"
    classifier.get_booster().save_model(str(classifier_path))
    regressor.get_booster().save_model(str(regressor_path))

    xgb_metrics = {
        "holdout": {
            "classifier": _classifier_result(
                classifier,
                encoded_matrix[holdout_indices],
                y_win[holdout_indices],
            ),
            "regressor": _regressor_result(
                regressor,
                encoded_matrix[holdout_indices],
                y_profit[holdout_indices],
            ),
        },
        "folds": _xgboost_fold_metrics(rows, encoded_matrix, y_win, y_profit, split_bundle, config),
        "model_files": {
            "classifier": classifier_path.name,
            "regressor": regressor_path.name,
        },
        "params": {
            "classifier": asdict(config.classifier),
            "regressor": asdict(config.regressor),
        },
    }

    classifier_importance = feature_importance(
        classifier.feature_importances_,
        encoded_feature_names,
    )
    regressor_importance = feature_importance(
        regressor.feature_importances_,
        encoded_feature_names,
    )
    diagnostics = feature_diagnostics(
        encoded_matrix,
        encoded_feature_names,
        classifier_importance,
        regressor_importance,
    )
    return xgb_metrics, diagnostics


def _fit_classifier(
    x_train: np.ndarray,
    y_train: np.ndarray,
    x_eval: np.ndarray,
    y_eval: np.ndarray,
    config: TrainingConfig,
) -> XGBClassifier:
    model = XGBClassifier(**asdict(config.classifier))
    model.fit(x_train, y_train, eval_set=[(x_eval, y_eval)], verbose=False)
    return model


def _fit_regressor(
    x_train: np.ndarray,
    y_train: np.ndarray,
    x_eval: np.ndarray,
    y_eval: np.ndarray,
    config: TrainingConfig,
) -> XGBRegressor:
    model = XGBRegressor(**asdict(config.regressor))
    model.fit(x_train, y_train, eval_set=[(x_eval, y_eval)], verbose=False)
    return model


def _classifier_result(
    model: XGBClassifier,
    x_test: np.ndarray,
    y_test: np.ndarray,
) -> dict:
    probabilities = model.predict_proba(x_test)[:, 1]
    predictions = (probabilities >= 0.5).astype(np.int64)
    return {
        "metrics": classification_metrics(y_test, predictions, probabilities),
        "best_iteration": _optional_int(getattr(model, "best_iteration", None)),
        "evals_result": model.evals_result(),
    }


def _regressor_result(
    model: XGBRegressor,
    x_test: np.ndarray,
    y_test: np.ndarray,
) -> dict:
    predictions = model.predict(x_test)
    return {
        "metrics": regression_metrics(y_test, predictions),
        "best_iteration": _optional_int(getattr(model, "best_iteration", None)),
        "evals_result": model.evals_result(),
    }


def _xgboost_fold_metrics(
    rows: list[dict],
    encoded_matrix: np.ndarray,
    y_win: np.ndarray,
    y_profit: np.ndarray,
    split_bundle: SplitBundle,
    config: TrainingConfig,
) -> list[dict]:
    del rows
    fold_metrics: list[dict] = []
    for fold in split_bundle.folds:
        train_indices = np.asarray(fold.train_indices, dtype=np.int64)
        test_indices = np.asarray(fold.test_indices, dtype=np.int64)
        classifier = _fit_classifier(
            encoded_matrix[train_indices],
            y_win[train_indices],
            encoded_matrix[test_indices],
            y_win[test_indices],
            config,
        )
        regressor = _fit_regressor(
            encoded_matrix[train_indices],
            y_profit[train_indices],
            encoded_matrix[test_indices],
            y_profit[test_indices],
            config,
        )
        fold_metrics.append(
            {
                "fold_index": fold.fold_index,
                "train_rows": len(fold.train_indices),
                "test_rows": len(fold.test_indices),
                "classifier": _classifier_result(
                    classifier,
                    encoded_matrix[test_indices],
                    y_win[test_indices],
                ),
                "regressor": _regressor_result(
                    regressor,
                    encoded_matrix[test_indices],
                    y_profit[test_indices],
                ),
            }
        )
    return fold_metrics


def _optional_int(value: object) -> int | None:
    if value is None:
        return None
    return int(value)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_path = resolve_dataset_path(args)
        manifest = load_dataset_manifest(dataset_path)
        config = TrainingConfig()
        rows = load_training_rows(dataset_path)
        validate_training_rows(rows, manifest, config)
        feature_columns = list(manifest["feature_columns"])
        encoder = FeatureEncoder.fit(rows, feature_columns)
        encoded = encoder.transform(rows)
        output_dir = prepare_output_dir(Path(args.output_root), args.model_id, args.overwrite)
        encoder.write_json(output_dir / "feature_encoder.json")
        write_training_input_summary(output_dir, args.model_id, manifest, rows, encoder)
        split_bundle = build_time_splits(
            rows,
            holdout_fraction=config.holdout_fraction,
            n_splits=config.walk_forward_splits,
            gap=config.walk_forward_gap,
        )
        baseline_metrics = evaluate_baselines(rows, encoded.matrix, split_bundle)
        xgboost_metrics, diagnostics = train_xgboost_models(
            output_dir,
            rows,
            encoded.matrix,
            encoded.encoded_feature_names,
            split_bundle,
            config,
        )
        write_validation_outputs(
            output_dir,
            args.model_id,
            manifest,
            split_bundle.metadata,
            baseline_metrics,
            xgboost_metrics=xgboost_metrics,
            diagnostics=diagnostics,
        )
    except (TrainingInputError, ValueError) as exc:
        parser.exit(1, f"training input failed: {exc}\n")

    print(
        "encoding ok | "
        f"trainer={TRAINER_VERSION} | "
        f"dataset={manifest.get('dataset_id', dataset_path.name)} | "
        f"model_id={args.model_id} | "
        f"rows={len(rows)} | "
        f"encoded_features={encoded.matrix.shape[1]} | "
        f"holdout_rows={len(split_bundle.holdout_indices)} | "
        f"folds={len(split_bundle.folds)} | "
        "xgboost=trained"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
