"""Export Phase 3 XGBoost models into deterministic MT5-readable artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from model_artifact_contract import (
    ARTIFACT_SCHEMA_VERSION,
    DEFAULT_EXPORT_ROOT,
    EXPORTER_VERSION,
    FEATURE_MAP_COLUMNS,
    FEATURE_MAP_TSV,
    MANIFEST_TSV_COLUMNS,
    MODEL_MANIFEST_JSON,
    MODEL_MANIFEST_TSV,
    REQUIRED_MANIFEST_KEYS,
    REQUIRED_PHASE3_FILES,
)
from model_config import DEFAULT_MODEL_ROOT


class ModelExportError(RuntimeError):
    """Raised when model artifact export cannot proceed."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    model_group = parser.add_mutually_exclusive_group(required=True)
    model_group.add_argument("--model-id", help="Phase 3 model ID under the model root.")
    model_group.add_argument("--model-path", help="Explicit Phase 3 model folder.")
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT, help="Root for --model-id.")
    parser.add_argument("--export-id", required=True, help="Model export output ID.")
    parser.add_argument(
        "--output-root",
        default=DEFAULT_EXPORT_ROOT,
        help="Root folder for generated MT5-readable exports.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing export folder.")
    return parser


def resolve_model_path(args: argparse.Namespace) -> Path:
    model_path = Path(args.model_path) if args.model_path else Path(args.model_root) / args.model_id
    if not model_path.exists():
        raise ModelExportError(f"Model folder does not exist: {model_path}")
    if not model_path.is_dir():
        raise ModelExportError(f"Model path is not a folder: {model_path}")
    return model_path


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
        "regressor_available": regressor_available,
        "regressor_tree_count": 0,
        "regressor_objective": "reg:squarederror" if regressor_available else "",
        "regressor_base_score": "",
        "threshold_probability": "" if recommendation is None else recommendation.get("threshold", ""),
        "threshold_research_source": "phase3_holdout_research" if recommendation else "",
        "research_only": True,
        "mt5_runtime_ready": False,
        "feature_map_file": FEATURE_MAP_TSV,
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


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        model_path = resolve_model_path(args)
        model_manifest, feature_encoder = load_phase3_inputs(model_path)
        output_dir = prepare_output_dir(Path(args.output_root), args.export_id, args.overwrite)
        feature_rows = write_feature_map(output_dir, feature_encoder)
        runtime_manifest = build_runtime_manifest(
            args.export_id,
            model_path,
            model_manifest,
            feature_encoder,
        )
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
