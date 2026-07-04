"""Train deterministic signal local ML models from Phase 2 datasets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from model_config import DEFAULT_DATASET_ROOT, DEFAULT_MODEL_ROOT, TRAINER_VERSION


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


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_path = resolve_dataset_path(args)
        manifest = load_dataset_manifest(dataset_path)
    except TrainingInputError as exc:
        parser.exit(1, f"training input failed: {exc}\n")

    print(
        "training input ok | "
        f"trainer={TRAINER_VERSION} | "
        f"dataset={manifest.get('dataset_id', dataset_path.name)} | "
        f"model_id={args.model_id}"
    )
    print("training implementation starts in Sprint 2.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
