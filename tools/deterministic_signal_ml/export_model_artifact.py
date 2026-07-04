"""Export Phase 3 XGBoost models into deterministic MT5-readable artifacts."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Any

from model_artifact_contract import DEFAULT_EXPORT_ROOT, EXPORTER_VERSION, REQUIRED_PHASE3_FILES
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


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        model_path = resolve_model_path(args)
        model_manifest, feature_encoder = load_phase3_inputs(model_path)
        output_dir = prepare_output_dir(Path(args.output_root), args.export_id, args.overwrite)
    except ModelExportError as exc:
        parser.exit(1, f"model export failed: {exc}\n")

    print(
        "model export input ok | "
        f"exporter={EXPORTER_VERSION} | "
        f"model_id={model_manifest.get('model_id', model_path.name)} | "
        f"dataset_id={model_manifest.get('dataset_id', '')} | "
        f"export_id={args.export_id} | "
        f"encoded_features={len(feature_encoder.get('encoded_feature_names', []))} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
