"""Validation helpers for deterministic signal Phase 1 export runs."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from schema_contract import (
    NULL_TOKEN,
    PHASE1_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_SCHEMA_VERSION,
    expected_columns_for,
)


class Phase1ValidationError(RuntimeError):
    """Raised when a Phase 1 export folder cannot be used as a dataset input."""


@dataclass(frozen=True)
class Phase1RunValidation:
    run_id: str
    run_path: Path
    config_id: str
    feature_rows: int
    outcome_rows: int
    joined_rows: int
    duplicate_feature_ids: int
    duplicate_outcome_ids: int
    missing_outcomes: int
    missing_features: int
    warnings: tuple[str, ...]


def _read_tsv(path: Path, expected_columns: tuple[str, ...]) -> list[dict[str, str]]:
    if not path.exists():
        raise Phase1ValidationError(f"Missing required file: {path}")

    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        try:
            header = next(reader)
        except StopIteration as exc:
            raise Phase1ValidationError(f"Empty TSV file: {path}") from exc

        if tuple(header) != expected_columns:
            raise Phase1ValidationError(
                f"Unexpected header in {path.name}: expected {expected_columns}, got {tuple(header)}"
            )

        for line_number, values in enumerate(reader, start=2):
            if len(values) != len(header):
                raise Phase1ValidationError(
                    f"Bad column count in {path.name}:{line_number}: "
                    f"expected {len(header)}, got {len(values)}"
                )
            rows.append(dict(zip(header, values)))

    return rows


def _required_int(value: str, field: str, filename: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise Phase1ValidationError(f"Invalid integer in {filename}.{field}: {value!r}") from exc


def _required_float(value: str, field: str, filename: str) -> float:
    if value == NULL_TOKEN:
        raise Phase1ValidationError(f"Unexpected null in {filename}.{field}")
    try:
        return float(value)
    except ValueError as exc:
        raise Phase1ValidationError(f"Invalid float in {filename}.{field}: {value!r}") from exc


def _require_schema_version(rows: Iterable[dict[str, str]], filename: str) -> None:
    for index, row in enumerate(rows, start=1):
        schema_version = _required_int(row["schema_version"], "schema_version", filename)
        if schema_version != SUPPORTED_SCHEMA_VERSION:
            raise Phase1ValidationError(
                f"Unsupported schema_version in {filename} row {index}: {schema_version}"
            )


def _count_duplicates(values: Iterable[str]) -> int:
    seen: set[str] = set()
    duplicate_count = 0
    for value in values:
        if value in seen:
            duplicate_count += 1
        else:
            seen.add(value)
    return duplicate_count


def _manifest_dict(rows: list[dict[str, str]]) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in rows:
        key = row["key"]
        if key in result:
            raise Phase1ValidationError(f"Duplicate manifest key: {key}")
        result[key] = row["value"]
    return result


def validate_phase1_run(runs_root: Path, run_id: str) -> Phase1RunValidation:
    """Validate a single Phase 1 run folder."""
    run_path = runs_root / run_id
    if not run_path.exists():
        raise Phase1ValidationError(f"Run folder does not exist: {run_path}")
    if not run_path.is_dir():
        raise Phase1ValidationError(f"Run path is not a folder: {run_path}")

    for filename in PHASE1_FILES:
        if not (run_path / filename).exists():
            raise Phase1ValidationError(f"Missing required Phase 1 file: {run_path / filename}")

    manifest_rows = _read_tsv(run_path / RUN_MANIFEST_FILE, expected_columns_for(RUN_MANIFEST_FILE))
    summary_rows = _read_tsv(run_path / RUN_SUMMARY_FILE, expected_columns_for(RUN_SUMMARY_FILE))
    feature_rows = _read_tsv(run_path / SIGNAL_FEATURES_FILE, expected_columns_for(SIGNAL_FEATURES_FILE))
    outcome_rows = _read_tsv(run_path / SIGNAL_OUTCOMES_FILE, expected_columns_for(SIGNAL_OUTCOMES_FILE))

    _require_schema_version(manifest_rows, RUN_MANIFEST_FILE)
    _require_schema_version(summary_rows, RUN_SUMMARY_FILE)
    _require_schema_version(feature_rows, SIGNAL_FEATURES_FILE)
    _require_schema_version(outcome_rows, SIGNAL_OUTCOMES_FILE)

    manifest = _manifest_dict(manifest_rows)
    if manifest.get("run_id") != run_id:
        raise Phase1ValidationError(
            f"Manifest run_id mismatch for {run_id}: {manifest.get('run_id')!r}"
        )

    if len(summary_rows) != 1:
        raise Phase1ValidationError(f"Expected exactly one summary row in {RUN_SUMMARY_FILE}")
    summary = summary_rows[0]
    if summary["run_id"] != run_id:
        raise Phase1ValidationError(f"Summary run_id mismatch for {run_id}: {summary['run_id']!r}")
    if summary["config_id"] != manifest.get("config_id"):
        raise Phase1ValidationError(
            f"Summary config_id mismatch for {run_id}: {summary['config_id']!r}"
        )
    if summary["export_status"] != "OK":
        raise Phase1ValidationError(f"Export status is not OK for {run_id}: {summary['export_status']}")

    expected_feature_rows = _required_int(summary["feature_rows"], "feature_rows", RUN_SUMMARY_FILE)
    expected_outcome_rows = _required_int(summary["outcome_rows"], "outcome_rows", RUN_SUMMARY_FILE)
    if expected_feature_rows != len(feature_rows):
        raise Phase1ValidationError(
            f"Feature row count mismatch for {run_id}: summary={expected_feature_rows}, actual={len(feature_rows)}"
        )
    if expected_outcome_rows != len(outcome_rows):
        raise Phase1ValidationError(
            f"Outcome row count mismatch for {run_id}: summary={expected_outcome_rows}, actual={len(outcome_rows)}"
        )

    config_id = summary["config_id"]
    for filename, rows in ((SIGNAL_FEATURES_FILE, feature_rows), (SIGNAL_OUTCOMES_FILE, outcome_rows)):
        for index, row in enumerate(rows, start=1):
            if row["run_id"] != run_id:
                raise Phase1ValidationError(f"{filename} row {index} has wrong run_id: {row['run_id']!r}")
            if row["config_id"] != config_id:
                raise Phase1ValidationError(f"{filename} row {index} has wrong config_id: {row['config_id']!r}")

    feature_ids = [row["signal_id"] for row in feature_rows]
    outcome_ids = [row["signal_id"] for row in outcome_rows]
    duplicate_feature_ids = _count_duplicates(feature_ids)
    duplicate_outcome_ids = _count_duplicates(outcome_ids)
    if duplicate_feature_ids > 0:
        raise Phase1ValidationError(f"Duplicate feature signal_id rows in {run_id}: {duplicate_feature_ids}")
    if duplicate_outcome_ids > 0:
        raise Phase1ValidationError(f"Duplicate outcome signal_id rows in {run_id}: {duplicate_outcome_ids}")

    feature_id_set = set(feature_ids)
    outcome_id_set = set(outcome_ids)
    missing_outcomes = len(feature_id_set - outcome_id_set)
    missing_features = len(outcome_id_set - feature_id_set)
    if missing_outcomes > 0 or missing_features > 0:
        raise Phase1ValidationError(
            f"Join mismatch for {run_id}: features_without_outcome={missing_outcomes}, "
            f"outcomes_without_feature={missing_features}"
        )

    for index, row in enumerate(outcome_rows, start=1):
        terminal_reason = row["terminal_reason"]
        profit_r = _required_float(row["profit_r"], "profit_r", SIGNAL_OUTCOMES_FILE)
        net_profit = _required_float(row["net_profit"], "net_profit", SIGNAL_OUTCOMES_FILE)
        if terminal_reason == "TP" and (profit_r <= 0.0 or net_profit <= 0.0):
            raise Phase1ValidationError(f"TP outcome has non-positive result in row {index}")
        if terminal_reason == "SL" and (profit_r >= 0.0 or net_profit >= 0.0):
            raise Phase1ValidationError(f"SL outcome has non-negative result in row {index}")

    warnings: list[str] = []
    feature_invalid_rows = _required_int(summary["feature_invalid_rows"], "feature_invalid_rows", RUN_SUMMARY_FILE)
    outcome_invalid_rows = _required_int(summary["outcome_invalid_rows"], "outcome_invalid_rows", RUN_SUMMARY_FILE)
    if feature_invalid_rows > 0:
        warnings.append(f"{feature_invalid_rows} feature rows were marked invalid by Phase 1")
    if outcome_invalid_rows > 0:
        warnings.append(f"{outcome_invalid_rows} outcome rows were marked invalid by Phase 1")

    return Phase1RunValidation(
        run_id=run_id,
        run_path=run_path,
        config_id=config_id,
        feature_rows=len(feature_rows),
        outcome_rows=len(outcome_rows),
        joined_rows=len(feature_id_set & outcome_id_set),
        duplicate_feature_ids=duplicate_feature_ids,
        duplicate_outcome_ids=duplicate_outcome_ids,
        missing_outcomes=missing_outcomes,
        missing_features=missing_features,
        warnings=tuple(warnings),
    )


def validate_phase1_runs(
    runs_root: Path,
    run_ids: Iterable[str],
    *,
    allow_mixed_config: bool = False,
) -> list[Phase1RunValidation]:
    """Validate multiple Phase 1 run folders."""
    validations = [validate_phase1_run(runs_root, run_id) for run_id in run_ids]
    config_ids = {validation.config_id for validation in validations}
    if len(config_ids) > 1 and not allow_mixed_config:
        raise Phase1ValidationError(
            "Mixed config_id values are not allowed without --allow-mixed-config: "
            + ", ".join(sorted(config_ids))
        )
    return validations
