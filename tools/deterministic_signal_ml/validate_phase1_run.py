"""Validation helpers for deterministic signal Phase 1 export runs."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from schema_contract import (
    ENGINE_ATTEMPTS_FILE,
    ENGINE_CYCLES_FILE,
    ENGINE_REVISIONS_FILE,
    NULL_TOKEN,
    PHASE1_FILES,
    RUN_MANIFEST_FILE,
    SIGNAL_ADMISSIONS_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_LEG_OUTCOMES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_SCHEMA_VERSION,
    SUPPORTED_SCHEMA_VERSIONS,
    expected_column_variants_for,
)


class Phase1ValidationError(RuntimeError):
    """Raised when a Phase 1 export folder cannot be used as a dataset input."""


@dataclass(frozen=True)
class Phase1RunValidation:
    run_id: str
    run_path: Path
    config_id: str
    feature_rows: int
    admission_rows: int
    outcome_rows: int
    cycle_rows: int
    revision_rows: int
    attempt_rows: int
    leg_outcome_rows: int
    joined_rows: int
    duplicate_feature_ids: int
    duplicate_outcome_ids: int
    missing_outcomes: int
    missing_features: int
    path_label_columns_present: bool
    warnings: tuple[str, ...]


def _read_tsv(path: Path, expected_columns: tuple[tuple[str, ...], ...]) -> list[dict[str, str]]:
    if not path.exists():
        raise Phase1ValidationError(f"Missing required file: {path}")

    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        try:
            header = next(reader)
        except StopIteration as exc:
            raise Phase1ValidationError(f"Empty TSV file: {path}") from exc

        header_tuple = tuple(header)
        if header_tuple not in expected_columns:
            raise Phase1ValidationError(
                f"Unexpected header in {path.name}: expected one of {expected_columns}, got {header_tuple}"
            )

        for line_number, values in enumerate(reader, start=2):
            if len(values) != len(header):
                raise Phase1ValidationError(
                    f"Bad column count in {path.name}:{line_number}: "
                    f"expected {len(header)}, got {len(values)}"
                )
            rows.append(dict(zip(header, values)))

    return rows


def _tsv_header(path: Path) -> tuple[str, ...]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return tuple(handle.readline().rstrip("\r\n").split("\t"))


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


def _require_schema_version(
    rows: Iterable[dict[str, str]],
    filename: str,
    expected_schema_version: int,
) -> None:
    for index, row in enumerate(rows, start=1):
        schema_version = _required_int(row["schema_version"], "schema_version", filename)
        if schema_version != expected_schema_version:
            raise Phase1ValidationError(
                f"Unsupported schema_version in {filename} row {index}: "
                f"{schema_version}; expected {expected_schema_version}"
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


def _admission_events_by_signal(rows: Iterable[dict[str, str]]) -> dict[str, set[str]]:
    events_by_signal: dict[str, set[str]] = {}
    for row in rows:
        events_by_signal.setdefault(row["signal_id"], set()).add(row["event_type"])
    return events_by_signal


def _manifest_dict(rows: list[dict[str, str]]) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in rows:
        key = row["key"]
        if key in result:
            raise Phase1ValidationError(f"Duplicate manifest key: {key}")
        result[key] = row["value"]
    return result


def validate_phase1_run(
    runs_root: Path,
    run_id: str,
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> Phase1RunValidation:
    """Validate a single Phase 1 run folder."""
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise Phase1ValidationError(f"Unsupported schema_version: {schema_version}")

    run_path = runs_root / run_id
    if not run_path.exists():
        raise Phase1ValidationError(f"Run folder does not exist: {run_path}")
    if not run_path.is_dir():
        raise Phase1ValidationError(f"Run path is not a folder: {run_path}")

    required_files = list(PHASE1_FILES)
    if schema_version >= 6:
        required_files.append(SIGNAL_ADMISSIONS_FILE)
    if schema_version == 7:
        required_files.extend(
            (ENGINE_CYCLES_FILE, ENGINE_REVISIONS_FILE, ENGINE_ATTEMPTS_FILE, SIGNAL_LEG_OUTCOMES_FILE)
        )

    for filename in required_files:
        if not (run_path / filename).exists():
            raise Phase1ValidationError(f"Missing required Phase 1 file: {run_path / filename}")

    manifest_rows = _read_tsv(
        run_path / RUN_MANIFEST_FILE,
        expected_column_variants_for(RUN_MANIFEST_FILE, schema_version),
    )
    summary_rows = _read_tsv(
        run_path / RUN_SUMMARY_FILE,
        expected_column_variants_for(RUN_SUMMARY_FILE, schema_version),
    )
    feature_rows = _read_tsv(
        run_path / SIGNAL_FEATURES_FILE,
        expected_column_variants_for(SIGNAL_FEATURES_FILE, schema_version),
    )
    admission_rows: list[dict[str, str]] = []
    if schema_version >= 6:
        admission_rows = _read_tsv(
            run_path / SIGNAL_ADMISSIONS_FILE,
            expected_column_variants_for(SIGNAL_ADMISSIONS_FILE, schema_version),
        )
    outcome_rows = _read_tsv(
        run_path / SIGNAL_OUTCOMES_FILE,
        expected_column_variants_for(SIGNAL_OUTCOMES_FILE, schema_version),
    )
    cycle_rows: list[dict[str, str]] = []
    revision_rows: list[dict[str, str]] = []
    attempt_rows: list[dict[str, str]] = []
    leg_outcome_rows: list[dict[str, str]] = []
    if schema_version == 7:
        cycle_rows = _read_tsv(
            run_path / ENGINE_CYCLES_FILE,
            expected_column_variants_for(ENGINE_CYCLES_FILE, schema_version),
        )
        revision_rows = _read_tsv(
            run_path / ENGINE_REVISIONS_FILE,
            expected_column_variants_for(ENGINE_REVISIONS_FILE, schema_version),
        )
        attempt_rows = _read_tsv(
            run_path / ENGINE_ATTEMPTS_FILE,
            expected_column_variants_for(ENGINE_ATTEMPTS_FILE, schema_version),
        )
        leg_outcome_rows = _read_tsv(
            run_path / SIGNAL_LEG_OUTCOMES_FILE,
            expected_column_variants_for(SIGNAL_LEG_OUTCOMES_FILE, schema_version),
        )

    _require_schema_version(manifest_rows, RUN_MANIFEST_FILE, schema_version)
    _require_schema_version(summary_rows, RUN_SUMMARY_FILE, schema_version)
    _require_schema_version(feature_rows, SIGNAL_FEATURES_FILE, schema_version)
    _require_schema_version(admission_rows, SIGNAL_ADMISSIONS_FILE, schema_version)
    _require_schema_version(outcome_rows, SIGNAL_OUTCOMES_FILE, schema_version)
    _require_schema_version(cycle_rows, ENGINE_CYCLES_FILE, schema_version)
    _require_schema_version(revision_rows, ENGINE_REVISIONS_FILE, schema_version)
    _require_schema_version(attempt_rows, ENGINE_ATTEMPTS_FILE, schema_version)
    _require_schema_version(leg_outcome_rows, SIGNAL_LEG_OUTCOMES_FILE, schema_version)

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
    expected_admission_rows = 0
    if schema_version >= 6:
        expected_admission_rows = _required_int(summary["admission_rows"], "admission_rows", RUN_SUMMARY_FILE)
    if expected_feature_rows != len(feature_rows):
        raise Phase1ValidationError(
            f"Feature row count mismatch for {run_id}: summary={expected_feature_rows}, actual={len(feature_rows)}"
        )
    if schema_version >= 6 and expected_admission_rows != len(admission_rows):
        raise Phase1ValidationError(
            f"Admission row count mismatch for {run_id}: summary={expected_admission_rows}, actual={len(admission_rows)}"
        )
    if expected_outcome_rows != len(outcome_rows):
        raise Phase1ValidationError(
            f"Outcome row count mismatch for {run_id}: summary={expected_outcome_rows}, actual={len(outcome_rows)}"
        )
    if schema_version == 7:
        for field, rows in (
            ("cycle_rows", cycle_rows),
            ("revision_rows", revision_rows),
            ("attempt_rows", attempt_rows),
            ("leg_outcome_rows", leg_outcome_rows),
        ):
            expected_rows = _required_int(summary[field], field, RUN_SUMMARY_FILE)
            if expected_rows != len(rows):
                raise Phase1ValidationError(
                    f"{field} mismatch for {run_id}: summary={expected_rows}, actual={len(rows)}"
                )

    config_id = summary["config_id"]
    for filename, rows in ((SIGNAL_FEATURES_FILE, feature_rows), (SIGNAL_OUTCOMES_FILE, outcome_rows)):
        for index, row in enumerate(rows, start=1):
            if row["run_id"] != run_id:
                raise Phase1ValidationError(f"{filename} row {index} has wrong run_id: {row['run_id']!r}")
            if row["config_id"] != config_id:
                raise Phase1ValidationError(f"{filename} row {index} has wrong config_id: {row['config_id']!r}")
    for index, row in enumerate(admission_rows, start=1):
        if row["run_id"] != run_id:
            raise Phase1ValidationError(f"{SIGNAL_ADMISSIONS_FILE} row {index} has wrong run_id: {row['run_id']!r}")
        if row["config_id"] != config_id:
            raise Phase1ValidationError(f"{SIGNAL_ADMISSIONS_FILE} row {index} has wrong config_id: {row['config_id']!r}")

    if schema_version == 7:
        for filename, rows in (
            (ENGINE_CYCLES_FILE, cycle_rows),
            (ENGINE_REVISIONS_FILE, revision_rows),
            (ENGINE_ATTEMPTS_FILE, attempt_rows),
            (SIGNAL_LEG_OUTCOMES_FILE, leg_outcome_rows),
        ):
            for index, row in enumerate(rows, start=1):
                if row["run_id"] != run_id or row["config_id"] != config_id:
                    raise Phase1ValidationError(
                        f"{filename} row {index} has mismatched run/config identity"
                    )

        cycle_ids = [row["extremum_cycle_id"] for row in cycle_rows]
        revision_ids = [row["revision_id"] for row in revision_rows]
        attempt_ids = [row["attempt_id"] for row in attempt_rows]
        if _count_duplicates(cycle_ids):
            raise Phase1ValidationError("Duplicate extremum_cycle_id rows")
        if _count_duplicates(revision_ids):
            raise Phase1ValidationError("Duplicate revision_id rows")
        if _count_duplicates(attempt_ids):
            raise Phase1ValidationError("Duplicate attempt_id rows")

        cycles_by_id = {row["extremum_cycle_id"]: row for row in cycle_rows}
        revisions_by_id = {row["revision_id"]: row for row in revision_rows}
        attempts_by_id = {row["attempt_id"]: row for row in attempt_rows}
        for cycle_id, cycle in cycles_by_id.items():
            if _required_float(cycle["reference_range_points"], "reference_range_points", ENGINE_CYCLES_FILE) <= 0:
                raise Phase1ValidationError(f"Non-positive reference range for cycle {cycle_id}")
            cycle_revisions = [row for row in revision_rows if row["extremum_cycle_id"] == cycle_id]
            cycle_attempts = [row for row in attempt_rows if row["extremum_cycle_id"] == cycle_id]
            if _required_int(cycle["revision_count"], "revision_count", ENGINE_CYCLES_FILE) != len(cycle_revisions):
                raise Phase1ValidationError(f"Revision count mismatch for cycle {cycle_id}")
            if _required_int(cycle["attempt_count"], "attempt_count", ENGINE_CYCLES_FILE) != len(cycle_attempts):
                raise Phase1ValidationError(f"Attempt count mismatch for cycle {cycle_id}")

            expected_indexes = list(range(1, len(cycle_revisions) + 1))
            actual_indexes = sorted(
                _required_int(row["revision_index"], "revision_index", ENGINE_REVISIONS_FILE)
                for row in cycle_revisions
            )
            if actual_indexes != expected_indexes:
                raise Phase1ValidationError(f"Non-monotonic revision indexes for cycle {cycle_id}")
            for revision in cycle_revisions:
                if any(
                    revision[field] != cycle[field]
                    for field in (
                        "reference_peak_time", "reference_peak_price",
                        "reference_bottom_time", "reference_bottom_price",
                        "reference_range_points",
                    )
                ):
                    raise Phase1ValidationError(f"Frozen anchors changed in cycle {cycle_id}")

        for revision in revision_rows:
            if revision["extremum_cycle_id"] not in cycles_by_id:
                raise Phase1ValidationError(f"Orphan revision {revision['revision_id']}")
            _required_float(revision["depth_percent_raw"], "depth_percent_raw", ENGINE_REVISIONS_FILE)

        for attempt in attempt_rows:
            if attempt["extremum_cycle_id"] not in cycles_by_id:
                raise Phase1ValidationError(f"Orphan attempt cycle for {attempt['attempt_id']}")
            revision = revisions_by_id.get(attempt["revision_id"])
            if revision is None or revision["extremum_cycle_id"] != attempt["extremum_cycle_id"]:
                raise Phase1ValidationError(f"Orphan attempt revision for {attempt['attempt_id']}")
            _required_float(attempt["candidate_depth_percent"], "candidate_depth_percent", ENGINE_ATTEMPTS_FILE)
            if attempt["simulated_outcome_source"] != "ENGINE_SIMULATION":
                raise Phase1ValidationError(f"Invalid simulated provenance for {attempt['attempt_id']}")
            if attempt["broker_entry_confirmed"] == "0" and attempt["broker_close_confirmed"] == "1":
                raise Phase1ValidationError(f"Broker close without entry for {attempt['attempt_id']}")

        broker_attempt_by_signal = {
            row["broker_signal_id"]: row
            for row in attempt_rows
            if row["broker_signal_id"] not in ("", NULL_TOKEN)
        }
        for outcome in outcome_rows:
            attempt = attempts_by_id.get(outcome["extremum_attempt_id"])
            if attempt is None or broker_attempt_by_signal.get(outcome["signal_id"]) is not attempt:
                raise Phase1ValidationError(
                    f"Broker outcome {outcome['signal_id']} has no matching intrinsic attempt"
                )
            if outcome["broker_entry_confirmed"] != "1" or outcome["broker_close_confirmed"] != "1":
                raise Phase1ValidationError(f"Broker outcome lacks confirmed evidence: {outcome['signal_id']}")

    feature_ids = [row["signal_id"] for row in feature_rows]
    outcome_ids = [row["signal_id"] for row in outcome_rows]
    duplicate_feature_ids = _count_duplicates(feature_ids)
    duplicate_outcome_ids = _count_duplicates(outcome_ids)
    if duplicate_feature_ids > 0:
        raise Phase1ValidationError(f"Duplicate feature signal_id rows in {run_id}: {duplicate_feature_ids}")
    if duplicate_outcome_ids > 0:
        raise Phase1ValidationError(f"Duplicate outcome signal_id rows in {run_id}: {duplicate_outcome_ids}")

    warnings: list[str] = []
    feature_id_set = set(feature_ids)
    outcome_id_set = set(outcome_ids)
    missing_outcome_ids = feature_id_set - outcome_id_set
    missing_feature_ids = outcome_id_set - feature_id_set
    missing_outcomes = len(missing_outcome_ids)
    missing_features = len(missing_feature_ids)
    if missing_features > 0:
        raise Phase1ValidationError(
            f"Join mismatch for {run_id}: features_without_outcome={missing_outcomes}, "
            f"outcomes_without_feature={missing_features}"
        )
    if missing_outcomes > 0:
        if schema_version < 6:
            raise Phase1ValidationError(
                f"Join mismatch for {run_id}: features_without_outcome={missing_outcomes}, "
                f"outcomes_without_feature={missing_features}"
            )
        admission_events = _admission_events_by_signal(admission_rows)
        still_open_ids = [
            signal_id
            for signal_id in missing_outcome_ids
            if "broker_entry" in admission_events.get(signal_id, set())
            and "broker_close" not in admission_events.get(signal_id, set())
        ]
        closed_or_ambiguous = missing_outcomes - len(still_open_ids)
        if closed_or_ambiguous > 0:
            raise Phase1ValidationError(
                f"Join mismatch for {run_id}: features_without_outcome={missing_outcomes}, "
                f"outcomes_without_feature={missing_features}, "
                f"features_without_outcome_with_close_or_missing_entry={closed_or_ambiguous}"
            )
        warnings.append(
            f"{missing_outcomes} broker-entered feature rows have no broker-close/outcome and "
            "will be excluded from supervised training"
        )

    tp_non_positive_net_profit_rows = 0
    sl_non_negative_net_profit_rows = 0
    broker_profit_non_positive_profit_r_rows = 0
    broker_loss_non_negative_profit_r_rows = 0
    for index, row in enumerate(outcome_rows, start=1):
        terminal_reason = row["terminal_reason"]
        profit_r = _required_float(row["profit_r"], "profit_r", SIGNAL_OUTCOMES_FILE)
        net_profit = _required_float(row["net_profit"], "net_profit", SIGNAL_OUTCOMES_FILE)
        if terminal_reason == "TP":
            if profit_r <= 0.0:
                raise Phase1ValidationError(f"TP outcome has non-positive profit_r in row {index}")
            if net_profit <= 0.0:
                tp_non_positive_net_profit_rows += 1
        if terminal_reason == "SL":
            if profit_r >= 0.0:
                raise Phase1ValidationError(f"SL outcome has non-loss profit_r in row {index}")
            if net_profit >= 0.0:
                sl_non_negative_net_profit_rows += 1
        if terminal_reason == "BROKER_PROFIT" and profit_r <= 0.0:
            broker_profit_non_positive_profit_r_rows += 1
        if terminal_reason == "BROKER_LOSS" and profit_r >= 0.0:
            broker_loss_non_negative_profit_r_rows += 1

    feature_invalid_rows = _required_int(summary["feature_invalid_rows"], "feature_invalid_rows", RUN_SUMMARY_FILE)
    outcome_invalid_rows = _required_int(summary["outcome_invalid_rows"], "outcome_invalid_rows", RUN_SUMMARY_FILE)
    if feature_invalid_rows > 0:
        warnings.append(f"{feature_invalid_rows} feature rows were marked invalid by Phase 1")
    if outcome_invalid_rows > 0:
        warnings.append(f"{outcome_invalid_rows} outcome rows were marked invalid by Phase 1")
    if tp_non_positive_net_profit_rows > 0:
        warnings.append(
            f"{tp_non_positive_net_profit_rows} TP outcome rows have non-positive net_profit but positive profit_r"
        )
    if sl_non_negative_net_profit_rows > 0:
        warnings.append(
            f"{sl_non_negative_net_profit_rows} SL terminal rows have non-negative broker net_profit; "
            "schema v6 broker_1r targets use net_profit-normalized R"
        )
    if broker_profit_non_positive_profit_r_rows > 0:
        warnings.append(
            f"{broker_profit_non_positive_profit_r_rows} BROKER_PROFIT rows have non-positive exported profit_r; "
            "regenerate the run with broker net R exporter alignment"
        )
    if broker_loss_non_negative_profit_r_rows > 0:
        warnings.append(
            f"{broker_loss_non_negative_profit_r_rows} BROKER_LOSS rows have non-negative exported profit_r; "
            "regenerate the run with broker net R exporter alignment"
        )

    path_label_columns_present = "path_status" in _tsv_header(run_path / SIGNAL_OUTCOMES_FILE)
    if not path_label_columns_present:
        warnings.append("path-ratio outcome columns are not present; only broker_1r targets can be built")

    return Phase1RunValidation(
        run_id=run_id,
        run_path=run_path,
        config_id=config_id,
        feature_rows=len(feature_rows),
        admission_rows=len(admission_rows),
        outcome_rows=len(outcome_rows),
        cycle_rows=len(cycle_rows),
        revision_rows=len(revision_rows),
        attempt_rows=len(attempt_rows),
        leg_outcome_rows=len(leg_outcome_rows),
        joined_rows=len(feature_id_set & outcome_id_set),
        duplicate_feature_ids=duplicate_feature_ids,
        duplicate_outcome_ids=duplicate_outcome_ids,
        missing_outcomes=missing_outcomes,
        missing_features=missing_features,
        path_label_columns_present=path_label_columns_present,
        warnings=tuple(warnings),
    )


def validate_phase1_runs(
    runs_root: Path,
    run_ids: Iterable[str],
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
    allow_mixed_config: bool = False,
) -> list[Phase1RunValidation]:
    """Validate multiple Phase 1 run folders."""
    validations = [
        validate_phase1_run(runs_root, run_id, schema_version=schema_version)
        for run_id in run_ids
    ]
    config_ids = {validation.config_id for validation in validations}
    if len(config_ids) > 1 and not allow_mixed_config:
        raise Phase1ValidationError(
            "Mixed config_id values are not allowed without --allow-mixed-config: "
            + ", ".join(sorted(config_ids))
        )
    return validations
