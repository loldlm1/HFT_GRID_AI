"""Summarize and validate an MQL5 ML shadow/filter run folder."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path


NULL_TOKEN = r"\N"
REQUIRED_FILES = (
    "shadow_manifest.tsv",
    "shadow_predictions.tsv",
    "shadow_outcomes.tsv",
    "shadow_summary.tsv",
)


class FilterRunSummaryError(RuntimeError):
    """Raised when a run folder is missing or internally inconsistent."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shadow-run-path", required=True, help="Folder containing shadow/filter TSV files.")
    return parser


def duplicate_header_count(path: Path) -> int:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise FilterRunSummaryError(f"Empty TSV file: {path}")
    header = lines[0]
    return sum(1 for line in lines[1:] if line == header)


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def read_manifest(path: Path) -> dict[str, str]:
    rows = read_tsv(path)
    if not rows:
        raise FilterRunSummaryError("Manifest has no rows")
    values: dict[str, str] = {}
    for row in rows:
        key = row.get("key", "")
        if key:
            values[key] = row.get("value", "")
    return values


def require_int(row: dict[str, str], field: str) -> int:
    value = row.get(field)
    if value is None or value == "":
        raise FilterRunSummaryError(f"Missing summary field: {field}")
    try:
        return int(value)
    except ValueError as exc:
        raise FilterRunSummaryError(f"Invalid integer for {field}: {value}") from exc


def optional_int(row: dict[str, str], field: str) -> int | None:
    value = row.get(field)
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError as exc:
        raise FilterRunSummaryError(f"Invalid integer for {field}: {value}") from exc


def is_true(value: str) -> bool:
    return value.lower() == "true"


def validate_required_files(run_path: Path) -> dict[str, Path]:
    if not run_path.is_dir():
        raise FilterRunSummaryError(f"Run folder does not exist: {run_path}")
    paths = {name: run_path / name for name in REQUIRED_FILES}
    missing = [str(path) for path in paths.values() if not path.exists()]
    if missing:
        raise FilterRunSummaryError("Missing run files: " + ", ".join(missing))
    duplicate_headers = {name: duplicate_header_count(path) for name, path in paths.items()}
    bad_headers = [f"{name}={count}" for name, count in duplicate_headers.items() if count > 0]
    if bad_headers:
        raise FilterRunSummaryError("Duplicate header rows: " + ", ".join(bad_headers))
    return paths


def summarize(run_path: Path) -> dict[str, object]:
    paths = validate_required_files(run_path)
    manifest = read_manifest(paths["shadow_manifest.tsv"])
    predictions = read_tsv(paths["shadow_predictions.tsv"])
    outcomes = read_tsv(paths["shadow_outcomes.tsv"])
    summary_rows = read_tsv(paths["shadow_summary.tsv"])
    if len(summary_rows) != 1:
        raise FilterRunSummaryError(f"Expected exactly one summary row, found {len(summary_rows)}")
    summary = summary_rows[0]

    prediction_rows = len(predictions)
    outcome_rows = len(outcomes)
    if require_int(summary, "prediction_rows") != prediction_rows:
        raise FilterRunSummaryError("Summary prediction_rows does not match predictions TSV")
    if require_int(summary, "outcome_rows") != outcome_rows:
        raise FilterRunSummaryError("Summary outcome_rows does not match outcomes TSV")

    invalid_feature_rows = sum(1 for row in predictions if not is_true(row.get("feature_valid", "false")))
    summary_invalid = require_int(summary, "invalid_feature_rows")
    if summary_invalid != invalid_feature_rows:
        raise FilterRunSummaryError("Summary invalid_feature_rows does not match predictions TSV")

    recommendations = Counter(row.get("recommendation", "") or NULL_TOKEN for row in predictions)
    admission_actions = Counter(row.get("admission_action", "") or "LEGACY" for row in predictions)
    filter_reasons = Counter(row.get("filter_reason", "") or NULL_TOKEN for row in predictions)
    unavailable_rows = sum(1 for row in predictions if not is_true(row.get("model_available", "false")))
    scored_rows = sum(1 for row in predictions if row.get("classifier_score", "") not in ("", NULL_TOKEN))

    filter_allow_rows = optional_int(summary, "filter_allow_rows")
    filter_block_rows = optional_int(summary, "filter_block_rows")
    filter_invalid_feature_blocks = optional_int(summary, "filter_invalid_feature_blocks")
    filter_unavailable_blocks = optional_int(summary, "filter_unavailable_blocks")

    if filter_allow_rows is not None and filter_allow_rows != admission_actions["ALLOW"]:
        raise FilterRunSummaryError("Summary filter_allow_rows does not match prediction actions")
    if filter_block_rows is not None and filter_block_rows != admission_actions["BLOCK"]:
        raise FilterRunSummaryError("Summary filter_block_rows does not match prediction actions")
    if filter_invalid_feature_blocks is not None:
        row_invalid_blocks = sum(
            1
            for row in predictions
            if row.get("admission_action") == "BLOCK" and not is_true(row.get("feature_valid", "false"))
        )
        if filter_invalid_feature_blocks != row_invalid_blocks:
            raise FilterRunSummaryError("Summary filter_invalid_feature_blocks does not match prediction actions")
    if filter_unavailable_blocks is not None:
        row_unavailable_blocks = sum(
            1
            for row in predictions
            if row.get("admission_action") == "BLOCK" and not is_true(row.get("model_available", "false"))
        )
        if filter_unavailable_blocks != row_unavailable_blocks:
            raise FilterRunSummaryError("Summary filter_unavailable_blocks does not match prediction actions")

    return {
        "shadow_run_id": manifest.get("shadow_run_id", ""),
        "export_id": manifest.get("export_id", ""),
        "model_id": manifest.get("model_id", ""),
        "mode": manifest.get("mode", ""),
        "prediction_rows": prediction_rows,
        "outcome_rows": outcome_rows,
        "scored_rows": scored_rows,
        "unavailable_rows": unavailable_rows,
        "recommendations": recommendations,
        "admission_actions": admission_actions,
        "filter_reasons": filter_reasons,
        "export_status": summary.get("export_status", ""),
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        report = summarize(Path(args.shadow_run_path))
    except FilterRunSummaryError as exc:
        parser.exit(1, f"filter run summary FAIL | {exc}\n")

    recommendations = report["recommendations"]
    admission_actions = report["admission_actions"]
    print(
        "filter run summary PASS | "
        f"run_id={report['shadow_run_id']} | "
        f"mode={report['mode']} | "
        f"export_id={report['export_id']} | "
        f"predictions={report['prediction_rows']} | "
        f"outcomes={report['outcome_rows']} | "
        f"scored={report['scored_rows']} | "
        f"unavailable_rows={report['unavailable_rows']} | "
        f"recommendation_ALLOW={recommendations['ALLOW']} | "
        f"recommendation_BLOCK={recommendations['BLOCK']} | "
        f"admission_ALLOW={admission_actions['ALLOW']} | "
        f"admission_BLOCK={admission_actions['BLOCK']} | "
        f"export_status={report['export_status']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
