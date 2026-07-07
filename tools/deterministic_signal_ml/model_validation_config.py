"""Configuration helpers for deterministic signal ML validation reports."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from model_artifact_contract import DEFAULT_EXPORT_ROOT
from model_config import DEFAULT_DATASET_ROOT, DEFAULT_MODEL_ROOT


SMOKE_BASELINE_DATASET_ID = "test_dataset_1"
SMOKE_BASELINE_MODEL_ID = "xgb_test_1"
SMOKE_BASELINE_EXPORT_ID = "xgb_test_1_export_v1"
SMOKE_DATASET_MAX_ROWS = 10000
CANDIDATE_MANIFEST_VERSION = "phase1.candidate_manifest.v1"
DEFAULT_BASELINE_FEATURE_SET_ID = "schema_v4_full"
DEFAULT_BASELINE_SCHEMA_VERSION = "feature_schema_v4"
DEFAULT_ROBUST_SPLIT_POLICY = "robust_chronological_train_early_threshold_holdout"
DEFAULT_THRESHOLD_POLICY = "threshold_selection_not_final_holdout"

REQUIRED_CANDIDATE_MANIFEST_FIELDS = (
    "manifest_version",
    "candidate_id",
    "dataset_id",
    "model_id",
    "export_id",
    "feature_set_id",
    "schema_version",
    "dataset_grade",
    "split_policy",
    "threshold_policy",
    "robustness_report_path",
    "notes",
)


class ModelValidationConfigError(RuntimeError):
    """Raised when validation configuration or artifacts are inconsistent."""


@dataclass(frozen=True)
class ValidationArtifactPaths:
    dataset_path: str
    model_path: str
    export_path: str


@dataclass(frozen=True)
class BaselineInventory:
    dataset_id: str
    model_id: str
    export_id: str
    dataset_grade: str
    source_run_ids: list[str]
    config_ids: list[str]
    row_counts: dict[str, int]
    phase1_schema_version: int | None
    encoded_feature_count: int | None
    threshold_probability: float | None
    threshold_source: str
    mt5_runtime_ready: bool | None
    research_only: bool | None
    paths: ValidationArtifactPaths
    warnings: list[str]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class CandidateManifest:
    manifest_version: str
    candidate_id: str
    dataset_id: str
    model_id: str
    export_id: str
    feature_set_id: str
    schema_version: str
    dataset_grade: str
    split_policy: str
    threshold_policy: str
    robustness_report_path: str
    notes: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-id", default=SMOKE_BASELINE_DATASET_ID)
    parser.add_argument("--model-id", default=SMOKE_BASELINE_MODEL_ID)
    parser.add_argument("--export-id", default=SMOKE_BASELINE_EXPORT_ID)
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--export-root", default=DEFAULT_EXPORT_ROOT)
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the full inventory as JSON instead of a compact text summary.",
    )
    parser.add_argument(
        "--write-candidate-manifest",
        default="",
        help="Optional path for a lightweight model-candidate manifest JSON.",
    )
    parser.add_argument("--candidate-id", default="")
    parser.add_argument("--feature-set-id", default=DEFAULT_BASELINE_FEATURE_SET_ID)
    parser.add_argument("--schema-version", default=DEFAULT_BASELINE_SCHEMA_VERSION)
    parser.add_argument("--split-policy", default=DEFAULT_ROBUST_SPLIT_POLICY)
    parser.add_argument("--threshold-policy", default=DEFAULT_THRESHOLD_POLICY)
    parser.add_argument("--robustness-report-path", default="")
    parser.add_argument("--notes", default="")
    return parser


def load_json_file(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ModelValidationConfigError(f"Required file does not exist: {path}")
    if not path.is_file():
        raise ModelValidationConfigError(f"Required path is not a file: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def require_folder(path: Path, label: str) -> Path:
    if not path.exists():
        raise ModelValidationConfigError(f"{label} folder does not exist: {path}")
    if not path.is_dir():
        raise ModelValidationConfigError(f"{label} path is not a folder: {path}")
    return path


def _optional_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    return int(value)


def _optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    return float(value)


def _optional_bool(value: Any) -> bool | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return value
    text = str(value).lower()
    if text in {"true", "1", "yes"}:
        return True
    if text in {"false", "0", "no"}:
        return False
    return None


def dataset_grade_for_rows(row_counts: dict[str, int]) -> str:
    matrix_rows = int(row_counts.get("training_matrix", 0))
    if matrix_rows <= 0:
        return "invalid"
    if matrix_rows < SMOKE_DATASET_MAX_ROWS:
        return "smoke_only"
    return "research_candidate"


def build_baseline_inventory(
    dataset_id: str,
    model_id: str,
    export_id: str,
    dataset_root: Path = Path(DEFAULT_DATASET_ROOT),
    model_root: Path = Path(DEFAULT_MODEL_ROOT),
    export_root: Path = Path(DEFAULT_EXPORT_ROOT),
) -> BaselineInventory:
    dataset_path = require_folder(dataset_root / dataset_id, "Dataset")
    model_path = require_folder(model_root / model_id, "Model")
    export_path = require_folder(export_root / export_id, "Export")

    dataset_manifest = load_json_file(dataset_path / "dataset_manifest.json")
    model_manifest = load_json_file(model_path / "model_manifest.json")
    export_manifest = load_json_file(export_path / "model_manifest.json")

    if str(model_manifest.get("dataset_id", "")) != dataset_id:
        raise ModelValidationConfigError(
            f"Model {model_id} does not reference dataset {dataset_id}: "
            f"{model_manifest.get('dataset_id')}"
        )
    if str(export_manifest.get("model_id", "")) != model_id:
        raise ModelValidationConfigError(
            f"Export {export_id} does not reference model {model_id}: "
            f"{export_manifest.get('model_id')}"
        )

    row_counts = {
        str(key): int(value)
        for key, value in dict(dataset_manifest.get("row_counts", {})).items()
    }
    dataset_grade = dataset_grade_for_rows(row_counts)
    warnings: list[str] = []
    if dataset_grade == "smoke_only":
        warnings.append(
            "dataset_has_smoke_only_row_count: use a fresh one-to-two-year Strategy Tester run before approving new features or thresholds"
        )

    threshold_probability = _optional_float(export_manifest.get("threshold_probability"))
    threshold_source = str(export_manifest.get("threshold_research_source", ""))
    if not threshold_source:
        threshold_source = "unknown"

    return BaselineInventory(
        dataset_id=dataset_id,
        model_id=model_id,
        export_id=export_id,
        dataset_grade=dataset_grade,
        source_run_ids=[str(value) for value in dataset_manifest.get("source_run_ids", [])],
        config_ids=[str(value) for value in dataset_manifest.get("config_ids", [])],
        row_counts=row_counts,
        phase1_schema_version=_optional_int(dataset_manifest.get("phase1_schema_version")),
        encoded_feature_count=_optional_int(model_manifest.get("encoded_feature_count")),
        threshold_probability=threshold_probability,
        threshold_source=threshold_source,
        mt5_runtime_ready=_optional_bool(export_manifest.get("mt5_runtime_ready")),
        research_only=_optional_bool(export_manifest.get("research_only")),
        paths=ValidationArtifactPaths(
            dataset_path=str(dataset_path),
            model_path=str(model_path),
            export_path=str(export_path),
        ),
        warnings=warnings,
    )


def build_candidate_manifest(
    inventory: BaselineInventory,
    candidate_id: str = "",
    feature_set_id: str = DEFAULT_BASELINE_FEATURE_SET_ID,
    schema_version: str = DEFAULT_BASELINE_SCHEMA_VERSION,
    split_policy: str = DEFAULT_ROBUST_SPLIT_POLICY,
    threshold_policy: str = DEFAULT_THRESHOLD_POLICY,
    robustness_report_path: str = "",
    notes: str = "",
) -> CandidateManifest:
    resolved_candidate_id = candidate_id or f"{inventory.model_id}:{feature_set_id}"
    resolved_report_path = (
        robustness_report_path
        or str(Path(inventory.paths.model_path) / "robustness" / "robustness_metrics.json")
    )
    return CandidateManifest(
        manifest_version=CANDIDATE_MANIFEST_VERSION,
        candidate_id=resolved_candidate_id,
        dataset_id=inventory.dataset_id,
        model_id=inventory.model_id,
        export_id=inventory.export_id,
        feature_set_id=feature_set_id,
        schema_version=schema_version,
        dataset_grade=inventory.dataset_grade,
        split_policy=split_policy,
        threshold_policy=threshold_policy,
        robustness_report_path=resolved_report_path,
        notes=notes,
    )


def validate_candidate_manifest_payload(payload: dict[str, Any]) -> None:
    missing = [
        field
        for field in REQUIRED_CANDIDATE_MANIFEST_FIELDS
        if field not in payload or payload[field] is None or (field != "notes" and payload[field] == "")
    ]
    if missing:
        raise ModelValidationConfigError(
            "Candidate manifest is missing required fields: " + ", ".join(missing)
        )
    if str(payload.get("manifest_version")) != CANDIDATE_MANIFEST_VERSION:
        raise ModelValidationConfigError(
            "Unsupported candidate manifest version: "
            f"{payload.get('manifest_version')!r}"
        )


def load_candidate_manifest(path: Path) -> CandidateManifest:
    payload = load_json_file(path)
    validate_candidate_manifest_payload(payload)
    return CandidateManifest(
        manifest_version=str(payload["manifest_version"]),
        candidate_id=str(payload["candidate_id"]),
        dataset_id=str(payload["dataset_id"]),
        model_id=str(payload["model_id"]),
        export_id=str(payload["export_id"]),
        feature_set_id=str(payload["feature_set_id"]),
        schema_version=str(payload["schema_version"]),
        dataset_grade=str(payload["dataset_grade"]),
        split_policy=str(payload["split_policy"]),
        threshold_policy=str(payload["threshold_policy"]),
        robustness_report_path=str(payload["robustness_report_path"]),
        notes=str(payload["notes"]),
    )


def write_candidate_manifest(path: Path, manifest: CandidateManifest) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest.to_dict(), indent=2, sort_keys=True), encoding="utf-8")
    return path


def compact_inventory_summary(inventory: BaselineInventory) -> str:
    rows = inventory.row_counts.get("training_matrix", 0)
    warning_token = "none" if not inventory.warnings else ",".join(inventory.warnings)
    return (
        "baseline inventory ok | "
        f"dataset={inventory.dataset_id} | "
        f"model={inventory.model_id} | "
        f"export={inventory.export_id} | "
        f"grade={inventory.dataset_grade} | "
        f"rows={rows} | "
        f"encoded_features={inventory.encoded_feature_count} | "
        f"threshold={inventory.threshold_probability} | "
        f"warnings={warning_token}"
    )


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        inventory = build_baseline_inventory(
            dataset_id=args.dataset_id,
            model_id=args.model_id,
            export_id=args.export_id,
            dataset_root=Path(args.dataset_root),
            model_root=Path(args.model_root),
            export_root=Path(args.export_root),
        )
    except (ModelValidationConfigError, ValueError, json.JSONDecodeError) as exc:
        parser.exit(1, f"validation config failed: {exc}\n")

    candidate_manifest_path = ""
    if args.write_candidate_manifest:
        manifest = build_candidate_manifest(
            inventory,
            candidate_id=args.candidate_id,
            feature_set_id=args.feature_set_id,
            schema_version=args.schema_version,
            split_policy=args.split_policy,
            threshold_policy=args.threshold_policy,
            robustness_report_path=args.robustness_report_path,
            notes=args.notes,
        )
        path = write_candidate_manifest(Path(args.write_candidate_manifest), manifest)
        candidate_manifest_path = str(path)

    if args.json:
        payload = inventory.to_dict()
        if candidate_manifest_path:
            payload["candidate_manifest_path"] = candidate_manifest_path
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(compact_inventory_summary(inventory))
        if candidate_manifest_path:
            print(f"candidate manifest written: {candidate_manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
