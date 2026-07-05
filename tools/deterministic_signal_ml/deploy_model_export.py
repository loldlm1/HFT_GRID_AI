"""Deploy a validated deterministic signal model export to MT5 Common Files."""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from model_artifact_contract import DEFAULT_EXPORT_ROOT
from model_artifact_validator import (
    ModelArtifactValidationError,
    resolve_export_path,
    validate_export_artifact,
)


class ModelExportDeployError(RuntimeError):
    """Raised when an export cannot be deployed to MT5 Common Files."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    export_group = parser.add_mutually_exclusive_group(required=True)
    export_group.add_argument("--export-id", help="Export ID under the export root.")
    export_group.add_argument("--export-path", help="Explicit export folder.")
    parser.add_argument("--export-root", default=DEFAULT_EXPORT_ROOT, help="Root for --export-id.")
    parser.add_argument(
        "--mt5-common-files",
        default=os.environ.get("MT5_COMMON_FILES", ""),
        help="MT5 Common Files folder. Defaults to the MT5_COMMON_FILES environment variable.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing deployed export folder.")
    return parser


def require_runtime_ready(report: dict[str, object], source: Path) -> None:
    if str(report.get("mt5_runtime_ready", "")).lower() != "true":
        raise ModelExportDeployError(f"Export is not marked mt5_runtime_ready=true: {source}")
    if str(report.get("research_only", "")).lower() != "true":
        raise ModelExportDeployError(f"Export is expected to remain research_only=true: {source}")


def deploy_export(source_path: Path, common_files: Path, *, overwrite: bool) -> Path:
    if not common_files.exists() or not common_files.is_dir():
        raise ModelExportDeployError(f"MT5 Common Files folder does not exist: {common_files}")

    source_report = validate_export_artifact(source_path)
    require_runtime_ready(source_report, source_path)

    export_id = str(source_report.get("export_id") or source_path.name)
    if not export_id or Path(export_id).name != export_id:
        raise ModelExportDeployError(f"Invalid export_id for deployment: {export_id}")
    destination_root = common_files / "DeterministicSignalML" / "model_exports"
    destination_path = destination_root / export_id

    destination_root.mkdir(parents=True, exist_ok=True)
    if destination_path.exists():
        if not overwrite:
            raise ModelExportDeployError(f"Destination already exists; use --overwrite: {destination_path}")
        shutil.rmtree(destination_path)

    shutil.copytree(source_path, destination_path)

    destination_report = validate_export_artifact(destination_path)
    require_runtime_ready(destination_report, destination_path)
    if str(destination_report.get("export_id", "")) != export_id:
        raise ModelExportDeployError("Destination export_id changed after copy")

    return destination_path


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        common_files_arg = str(args.mt5_common_files).strip()
        if not common_files_arg:
            raise ModelExportDeployError(
                "MT5 Common Files folder was not provided; set MT5_COMMON_FILES or pass --mt5-common-files"
            )
        source_path = resolve_export_path(args)
        destination_path = deploy_export(
            source_path,
            Path(common_files_arg).expanduser(),
            overwrite=args.overwrite,
        )
    except (ModelArtifactValidationError, ModelExportDeployError) as exc:
        parser.exit(1, f"model export deploy failed: {exc}\n")

    print(
        "model export deploy ok | "
        f"source={source_path} | "
        f"destination={destination_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
