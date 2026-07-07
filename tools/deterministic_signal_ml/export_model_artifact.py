"""Export Phase 3 XGBoost models into deterministic MT5-readable artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np
import xgboost as xgb

from model_artifact_validator import encode_rows, read_feature_map, score_classifier, score_regressor
from model_artifact_contract import (
    ARTIFACT_SCHEMA_VERSION,
    CLASSIFIER_TREES_TSV,
    DEFAULT_EXPORT_ROOT,
    EXPORTER_VERSION,
    FEATURE_MAP_COLUMNS,
    FEATURE_MAP_TSV,
    MANIFEST_TSV_COLUMNS,
    MODEL_MANIFEST_JSON,
    MODEL_MANIFEST_TSV,
    PARITY_REPORT_JSON,
    PARITY_REPORT_MD,
    REGRESSOR_TREES_TSV,
    REQUIRED_MANIFEST_KEYS,
    REQUIRED_PHASE3_FILES,
    THRESHOLD_POLICY_COLUMNS,
    THRESHOLD_POLICY_TSV,
    TREE_COLUMNS,
)
from model_config import DEFAULT_DATASET_ROOT, DEFAULT_MODEL_ROOT
from train_model import load_training_rows


class ModelExportError(RuntimeError):
    """Raised when model artifact export cannot proceed."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    model_group = parser.add_mutually_exclusive_group(required=True)
    model_group.add_argument("--model-id", help="Phase 3 model ID under the model root.")
    model_group.add_argument("--model-path", help="Explicit Phase 3 model folder.")
    dataset_group = parser.add_mutually_exclusive_group()
    dataset_group.add_argument("--dataset-id", help="Phase 2 dataset ID for parity validation.")
    dataset_group.add_argument("--dataset-path", help="Explicit Phase 2 dataset folder for parity validation.")
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT, help="Root for --model-id.")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT, help="Root for --dataset-id.")
    parser.add_argument("--export-id", required=True, help="Model export output ID.")
    parser.add_argument(
        "--output-root",
        default=DEFAULT_EXPORT_ROOT,
        help="Root folder for generated MT5-readable exports.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing export folder.")
    parser.add_argument(
        "--parity-tolerance",
        type=float,
        default=1e-6,
        help="Maximum allowed classifier probability error during parity validation.",
    )
    parser.add_argument(
        "--regressor-parity-tolerance",
        type=float,
        default=1e-6,
        help="Maximum allowed regressor prediction error during parity validation.",
    )
    parser.add_argument(
        "--allow-missing-threshold",
        action="store_true",
        help="Allow export when Phase 3 did not select a research threshold.",
    )
    return parser


def resolve_model_path(args: argparse.Namespace) -> Path:
    model_path = Path(args.model_path) if args.model_path else Path(args.model_root) / args.model_id
    if not model_path.exists():
        raise ModelExportError(f"Model folder does not exist: {model_path}")
    if not model_path.is_dir():
        raise ModelExportError(f"Model path is not a folder: {model_path}")
    return model_path


def resolve_dataset_path(args: argparse.Namespace) -> Path | None:
    if not args.dataset_path and not args.dataset_id:
        return None
    dataset_path = Path(args.dataset_path) if args.dataset_path else Path(args.dataset_root) / args.dataset_id
    if not dataset_path.exists():
        raise ModelExportError(f"Dataset folder does not exist: {dataset_path}")
    if not dataset_path.is_dir():
        raise ModelExportError(f"Dataset path is not a folder: {dataset_path}")
    if not (dataset_path / "training_matrix.parquet").exists():
        raise ModelExportError(f"Dataset missing training_matrix.parquet: {dataset_path}")
    return dataset_path


def prepare_output_dir(output_root: Path, export_id: str, overwrite: bool) -> Path:
    output_dir = output_root / export_id
    resolved_root = output_root.resolve()
    resolved_output = output_dir.resolve()
    if resolved_output == resolved_root or resolved_root not in resolved_output.parents:
        raise ModelExportError(f"Refusing export output outside output root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise ModelExportError(f"Export output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    return output_dir


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_phase3_inputs(model_path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    missing = [filename for filename in REQUIRED_PHASE3_FILES if not (model_path / filename).exists()]
    if missing:
        raise ModelExportError(
            "Phase 3 model folder is missing required files: " + ", ".join(missing)
        )
    model_manifest = load_json(model_path / "model_manifest.json")
    feature_encoder = load_json(model_path / "feature_encoder.json")
    return model_manifest, feature_encoder


def write_tsv(path: Path, columns: tuple[str, ...], rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(columns), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: _tsv_value(row.get(column, "")) for column in columns})


def _tsv_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.12g}"
    if isinstance(value, (list, dict)):
        return json.dumps(value, separators=(",", ":"), sort_keys=True)
    return str(value)


def build_feature_map_rows(feature_encoder: dict[str, Any]) -> list[dict[str, Any]]:
    numeric_columns = set(feature_encoder.get("numeric_columns", []))
    encoded_names = list(feature_encoder.get("encoded_feature_names", []))
    if not encoded_names:
        raise ModelExportError("feature_encoder.json has no encoded_feature_names")

    rows: list[dict[str, Any]] = []
    for index, feature_name in enumerate(encoded_names):
        if feature_name in numeric_columns:
            source_column = feature_name
            encoding_type = "numeric"
            category = ""
        elif "=" in feature_name:
            source_column, category = feature_name.split("=", 1)
            encoding_type = "one_hot"
        else:
            raise ModelExportError(f"Cannot derive feature map row for: {feature_name}")
        rows.append(
            {
                "encoded_index": index,
                "encoded_feature_name": feature_name,
                "source_column": source_column,
                "encoding_type": encoding_type,
                "category": category,
            }
        )
    return rows


def threshold_recommendation(model_manifest: dict[str, Any]) -> dict[str, Any] | None:
    recommendation = model_manifest.get("threshold_recommendation")
    if isinstance(recommendation, dict):
        return recommendation
    return None


def build_runtime_manifest(
    export_id: str,
    model_path: Path,
    model_manifest: dict[str, Any],
    feature_encoder: dict[str, Any],
) -> dict[str, Any]:
    recommendation = threshold_recommendation(model_manifest)
    regressor_available = (model_path / "regressor_xgboost.json").exists()
    manifest = {
        "artifact_schema_version": ARTIFACT_SCHEMA_VERSION,
        "exporter_version": EXPORTER_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "export_id": export_id,
        "model_id": model_manifest.get("model_id", model_path.name),
        "dataset_id": model_manifest.get("dataset_id", ""),
        "source_run_ids": model_manifest.get("source_run_ids", []),
        "config_ids": model_manifest.get("config_ids", []),
        "phase1_schema_version": model_manifest.get("phase1_schema_version", ""),
        "phase2_builder_version": model_manifest.get("phase2_builder_version", ""),
        "phase3_trainer_version": model_manifest.get("phase3_trainer_version", ""),
        "encoded_feature_count": len(feature_encoder.get("encoded_feature_names", [])),
        "classifier_available": True,
        "classifier_tree_count": 0,
        "classifier_objective": "binary:logistic",
        "classifier_base_score": "",
        "classifier_base_probability": "",
        "classifier_parity_status": "",
        "classifier_parity_max_abs_error": "",
        "regressor_available": regressor_available,
        "regressor_tree_count": 0,
        "regressor_objective": "reg:squarederror" if regressor_available else "",
        "regressor_base_score": "",
        "regressor_parity_status": "",
        "regressor_parity_max_abs_error": "",
        "threshold_probability": "" if recommendation is None else recommendation.get("threshold", ""),
        "threshold_research_source": "phase3_holdout_research" if recommendation else "",
        "research_only": True,
        "mt5_runtime_ready": False,
        "feature_map_file": FEATURE_MAP_TSV,
        "classifier_trees_file": "",
        "regressor_trees_file": "",
        "threshold_policy_file": "",
        "parity_report_file": "",
    }
    missing_keys = [key for key in REQUIRED_MANIFEST_KEYS if key not in manifest]
    if missing_keys:
        raise ModelExportError("Runtime manifest missing required keys: " + ", ".join(missing_keys))
    return manifest


def write_manifest(output_dir: Path, manifest: dict[str, Any]) -> None:
    rows = [{"key": key, "value": value} for key, value in manifest.items()]
    write_tsv(output_dir / MODEL_MANIFEST_TSV, MANIFEST_TSV_COLUMNS, rows)
    (output_dir / MODEL_MANIFEST_JSON).write_text(
        json.dumps(manifest, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def write_feature_map(output_dir: Path, feature_encoder: dict[str, Any]) -> list[dict[str, Any]]:
    rows = build_feature_map_rows(feature_encoder)
    write_tsv(output_dir / FEATURE_MAP_TSV, FEATURE_MAP_COLUMNS, rows)
    return rows


def load_booster(path: Path) -> xgb.Booster:
    booster = xgb.Booster()
    booster.load_model(str(path))
    return booster


def booster_config(booster: xgb.Booster) -> dict[str, Any]:
    return json.loads(booster.save_config())


def objective_name(booster: xgb.Booster) -> str:
    config = booster_config(booster)
    return str(config["learner"]["objective"]["name"])


def base_probability(booster: xgb.Booster) -> float:
    config = booster_config(booster)
    raw = str(config["learner"]["learner_model_param"]["base_score"]).strip("[]")
    return float(raw)


def base_score_value(booster: xgb.Booster) -> float:
    config = booster_config(booster)
    raw = str(config["learner"]["learner_model_param"]["base_score"]).strip("[]")
    return float(raw)


def binary_logit(probability: float) -> float:
    if not 0.0 < probability < 1.0:
        raise ModelExportError(f"Classifier base probability must be between 0 and 1: {probability}")
    return float(np.log(probability / (1.0 - probability)))


def effective_tree_count(booster: xgb.Booster) -> int:
    dumps = booster.get_dump(dump_format="json", with_stats=False)
    attributes = booster.attributes()
    if "best_iteration" in attributes:
        tree_count = int(attributes["best_iteration"]) + 1
    else:
        tree_count = len(dumps)
    if tree_count <= 0 or tree_count > len(dumps):
        raise ModelExportError(f"Invalid effective tree count: {tree_count} of {len(dumps)}")
    return tree_count


def export_classifier_trees(output_dir: Path, model_path: Path) -> dict[str, Any]:
    booster = load_booster(model_path / "classifier_xgboost.json")
    objective = objective_name(booster)
    if objective != "binary:logistic":
        raise ModelExportError(f"Unsupported classifier objective: {objective}")

    tree_count = effective_tree_count(booster)
    dump_json = booster.get_dump(dump_format="json", with_stats=False)[:tree_count]
    rows: list[dict[str, Any]] = []
    for tree_index, tree_payload in enumerate(dump_json):
        root = json.loads(tree_payload)
        flatten_tree("classifier", tree_index, root, rows)
    write_tsv(output_dir / CLASSIFIER_TREES_TSV, TREE_COLUMNS, rows)

    probability = base_probability(booster)
    return {
        "tree_count": tree_count,
        "node_count": len(rows),
        "objective": objective,
        "base_probability": probability,
        "base_score": binary_logit(probability),
    }


def export_regressor_trees(output_dir: Path, model_path: Path) -> dict[str, Any]:
    regressor_path = model_path / "regressor_xgboost.json"
    if not regressor_path.exists():
        raise ModelExportError(f"Phase 4 requires regressor export, missing: {regressor_path}")
    booster = load_booster(regressor_path)
    objective = objective_name(booster)
    if objective != "reg:squarederror":
        raise ModelExportError(f"Unsupported regressor objective: {objective}")

    tree_count = effective_tree_count(booster)
    dump_json = booster.get_dump(dump_format="json", with_stats=False)[:tree_count]
    rows: list[dict[str, Any]] = []
    for tree_index, tree_payload in enumerate(dump_json):
        root = json.loads(tree_payload)
        flatten_tree("regressor", tree_index, root, rows)
    write_tsv(output_dir / REGRESSOR_TREES_TSV, TREE_COLUMNS, rows)

    return {
        "tree_count": tree_count,
        "node_count": len(rows),
        "objective": objective,
        "base_score": base_score_value(booster),
    }


def flatten_tree(
    model_role: str,
    tree_index: int,
    node: dict[str, Any],
    rows: list[dict[str, Any]],
) -> None:
    node_index = int(node["nodeid"])
    if "leaf" in node:
        rows.append(
            {
                "model_role": model_role,
                "tree_index": tree_index,
                "node_index": node_index,
                "node_type": "leaf",
                "feature_index": "",
                "threshold": "",
                "left_child": "",
                "right_child": "",
                "default_left": "",
                "leaf_value": float(node["leaf"]),
            }
        )
        return

    split = str(node.get("split", ""))
    if not split.startswith("f"):
        raise ModelExportError(f"Unsupported split feature format: {split}")
    if "categories" in node:
        raise ModelExportError("Categorical XGBoost split export is not supported")

    yes = int(node["yes"])
    no = int(node["no"])
    missing = int(node["missing"])
    rows.append(
        {
            "model_role": model_role,
            "tree_index": tree_index,
            "node_index": node_index,
            "node_type": "split",
            "feature_index": int(split[1:]),
            "threshold": float(node["split_condition"]),
            "left_child": yes,
            "right_child": no,
            "default_left": 1 if missing == yes else 0,
            "leaf_value": "",
        }
    )
    for child in node.get("children", []):
        flatten_tree(model_role, tree_index, child, rows)


def run_classifier_parity(
    output_dir: Path,
    model_path: Path,
    dataset_path: Path,
    model_manifest: dict[str, Any],
    runtime_manifest: dict[str, Any],
    tolerance: float,
) -> dict[str, Any]:
    rows = load_training_rows(dataset_path)
    holdout = model_manifest.get("split_policy", {}).get("holdout", {})
    start_index = int(holdout.get("start_index", 0))
    end_index = int(holdout.get("end_index", len(rows) - 1))
    if start_index < 0 or end_index >= len(rows) or start_index > end_index:
        raise ModelExportError(f"Invalid holdout range in model manifest: {holdout}")

    selected_rows = [rows[index] for index in range(start_index, end_index + 1)]
    feature_map_rows = read_feature_map(output_dir)
    matrix = encode_rows(selected_rows, feature_map_rows)
    artifact_probability = score_classifier(output_dir, matrix)

    booster = load_booster(model_path / "classifier_xgboost.json")
    dmatrix = xgb.DMatrix(matrix)
    tree_count = int(runtime_manifest["classifier_tree_count"])
    xgboost_probability = booster.predict(dmatrix, iteration_range=(0, tree_count))
    errors = np.abs(artifact_probability - xgboost_probability)
    max_abs_error = float(np.max(errors))
    mean_abs_error = float(np.mean(errors))
    threshold = runtime_manifest.get("threshold_probability", "")
    threshold_value = 0.5 if threshold == "" else float(threshold)
    artifact_decisions = artifact_probability >= threshold_value
    xgboost_decisions = xgboost_probability >= threshold_value
    decision_agreement = float(np.mean(artifact_decisions == xgboost_decisions))
    status = "OK" if max_abs_error <= tolerance else "FAIL"
    report = {
        "status": status,
        "model_role": "classifier",
        "rows": len(selected_rows),
        "start_index": start_index,
        "end_index": end_index,
        "tree_count": tree_count,
        "tolerance": tolerance,
        "max_abs_error": max_abs_error,
        "mean_abs_error": mean_abs_error,
        "threshold_probability": threshold_value,
        "threshold_decision_agreement": decision_agreement,
    }
    if status != "OK":
        raise ModelExportError(
            f"Classifier parity failed: max_abs_error={max_abs_error} tolerance={tolerance}"
        )
    return report


def run_regressor_parity(
    output_dir: Path,
    model_path: Path,
    dataset_path: Path,
    model_manifest: dict[str, Any],
    runtime_manifest: dict[str, Any],
    tolerance: float,
) -> dict[str, Any]:
    rows = load_training_rows(dataset_path)
    holdout = model_manifest.get("split_policy", {}).get("holdout", {})
    start_index = int(holdout.get("start_index", 0))
    end_index = int(holdout.get("end_index", len(rows) - 1))
    if start_index < 0 or end_index >= len(rows) or start_index > end_index:
        raise ModelExportError(f"Invalid holdout range in model manifest: {holdout}")

    selected_rows = [rows[index] for index in range(start_index, end_index + 1)]
    feature_map_rows = read_feature_map(output_dir)
    matrix = encode_rows(selected_rows, feature_map_rows)
    artifact_prediction = score_regressor(output_dir, matrix)

    booster = load_booster(model_path / "regressor_xgboost.json")
    dmatrix = xgb.DMatrix(matrix)
    tree_count = int(runtime_manifest["regressor_tree_count"])
    xgboost_prediction = booster.predict(dmatrix, iteration_range=(0, tree_count))
    errors = np.abs(artifact_prediction - xgboost_prediction)
    max_abs_error = float(np.max(errors))
    mean_abs_error = float(np.mean(errors))
    status = "OK" if max_abs_error <= tolerance else "FAIL"
    report = {
        "status": status,
        "model_role": "regressor",
        "rows": len(selected_rows),
        "start_index": start_index,
        "end_index": end_index,
        "tree_count": tree_count,
        "tolerance": tolerance,
        "max_abs_error": max_abs_error,
        "mean_abs_error": mean_abs_error,
    }
    if status != "OK":
        raise ModelExportError(
            f"Regressor parity failed: max_abs_error={max_abs_error} tolerance={tolerance}"
        )
    return report


def write_threshold_policy(
    output_dir: Path,
    model_manifest: dict[str, Any],
    allow_missing_threshold: bool,
) -> dict[str, Any] | None:
    recommendation = threshold_recommendation(model_manifest)
    if recommendation is None:
        if allow_missing_threshold:
            return None
        raise ModelExportError("Phase 3 threshold recommendation is missing")

    row = {
        "threshold": recommendation.get("threshold", ""),
        "selected_rows": recommendation.get("selected_rows", ""),
        "win_rate": recommendation.get("win_rate", ""),
        "mean_profit_r": recommendation.get("mean_profit_r", ""),
        "net_profit_r": recommendation.get("net_profit_r", ""),
        "max_drawdown_r": recommendation.get("max_drawdown_r", ""),
        "source": "phase3_holdout_research",
        "research_only": True,
    }
    write_tsv(output_dir / THRESHOLD_POLICY_TSV, THRESHOLD_POLICY_COLUMNS, [row])
    return row


def write_parity_report(output_dir: Path, report: dict[str, Any]) -> None:
    (output_dir / PARITY_REPORT_JSON).write_text(
        json.dumps(report, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    if "classifier" in report:
        classifier = report["classifier"]
        regressor = report.get("regressor")
        lines = [
            "# Model Artifact Parity Report",
            "",
            f"- Status: `{report['status']}`",
            f"- Classifier rows: {classifier['rows']}",
            f"- Classifier tree count: {classifier['tree_count']}",
            f"- Classifier max absolute error: {classifier['max_abs_error']:.12g}",
            f"- Classifier mean absolute error: {classifier['mean_abs_error']:.12g}",
            f"- Classifier threshold decision agreement: {classifier['threshold_decision_agreement']:.12g}",
        ]
        if regressor is not None:
            lines.extend(
                [
                    f"- Regressor rows: {regressor['rows']}",
                    f"- Regressor tree count: {regressor['tree_count']}",
                    f"- Regressor max absolute error: {regressor['max_abs_error']:.12g}",
                    f"- Regressor mean absolute error: {regressor['mean_abs_error']:.12g}",
                ]
            )
        lines.append("")
        (output_dir / PARITY_REPORT_MD).write_text("\n".join(lines), encoding="utf-8")
        return

    lines = [
        "# Model Artifact Parity Report",
        "",
        f"- Status: `{report['status']}`",
        f"- Model role: `{report['model_role']}`",
        f"- Rows: {report['rows']}",
        f"- Tree count: {report['tree_count']}",
        f"- Max absolute error: {report['max_abs_error']:.12g}",
        f"- Mean absolute error: {report['mean_abs_error']:.12g}",
        f"- Tolerance: {report['tolerance']:.12g}",
        f"- Threshold decision agreement: {report['threshold_decision_agreement']:.12g}",
        "",
    ]
    (output_dir / PARITY_REPORT_MD).write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        model_path = resolve_model_path(args)
        dataset_path = resolve_dataset_path(args)
        model_manifest, feature_encoder = load_phase3_inputs(model_path)
        output_dir = prepare_output_dir(Path(args.output_root), args.export_id, args.overwrite)
        feature_rows = write_feature_map(output_dir, feature_encoder)
        runtime_manifest = build_runtime_manifest(
            args.export_id,
            model_path,
            model_manifest,
            feature_encoder,
        )
        classifier_info = export_classifier_trees(output_dir, model_path)
        runtime_manifest["classifier_tree_count"] = classifier_info["tree_count"]
        runtime_manifest["classifier_objective"] = classifier_info["objective"]
        runtime_manifest["classifier_base_score"] = classifier_info["base_score"]
        runtime_manifest["classifier_base_probability"] = classifier_info["base_probability"]
        runtime_manifest["classifier_trees_file"] = CLASSIFIER_TREES_TSV
        regressor_info = export_regressor_trees(output_dir, model_path)
        runtime_manifest["regressor_tree_count"] = regressor_info["tree_count"]
        runtime_manifest["regressor_objective"] = regressor_info["objective"]
        runtime_manifest["regressor_base_score"] = regressor_info["base_score"]
        runtime_manifest["regressor_trees_file"] = REGRESSOR_TREES_TSV
        threshold_policy = write_threshold_policy(
            output_dir,
            model_manifest,
            args.allow_missing_threshold,
        )
        runtime_manifest["threshold_policy_file"] = "" if threshold_policy is None else THRESHOLD_POLICY_TSV
        write_manifest(output_dir, runtime_manifest)
        if dataset_path is not None:
            classifier_report = run_classifier_parity(
                output_dir,
                model_path,
                dataset_path,
                model_manifest,
                runtime_manifest,
                args.parity_tolerance,
            )
            regressor_report = run_regressor_parity(
                output_dir,
                model_path,
                dataset_path,
                model_manifest,
                runtime_manifest,
                args.regressor_parity_tolerance,
            )
            runtime_manifest["classifier_parity_status"] = classifier_report["status"]
            runtime_manifest["classifier_parity_max_abs_error"] = classifier_report["max_abs_error"]
            runtime_manifest["regressor_parity_status"] = regressor_report["status"]
            runtime_manifest["regressor_parity_max_abs_error"] = regressor_report["max_abs_error"]
            runtime_manifest["mt5_runtime_ready"] = (
                threshold_policy is not None
                and classifier_report["status"] == "OK"
                and regressor_report["status"] == "OK"
            )
            runtime_manifest["parity_report_file"] = PARITY_REPORT_JSON
            parity_report = {
                "status": "OK"
                if classifier_report["status"] == "OK" and regressor_report["status"] == "OK"
                else "FAIL",
                "classifier": classifier_report,
                "regressor": regressor_report,
            }
            write_parity_report(output_dir, parity_report)
        write_manifest(output_dir, runtime_manifest)
    except ModelExportError as exc:
        parser.exit(1, f"model export failed: {exc}\n")

    print(
        "model export input ok | "
        f"exporter={EXPORTER_VERSION} | "
        f"model_id={model_manifest.get('model_id', model_path.name)} | "
        f"dataset_id={model_manifest.get('dataset_id', '')} | "
        f"export_id={args.export_id} | "
        f"encoded_features={len(feature_rows)} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
