"""Fail-closed validation for one schema v8 market-data run."""

from __future__ import annotations

import csv
import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable

from schema_contract import (
    ENGINE_ATTEMPTS_FILE,
    ENGINE_CYCLES_FILE,
    ENGINE_REVISIONS_FILE,
    EXECUTION_CHECKS_FILE,
    NULL_TOKEN,
    PHASE1_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_SCHEMA_VERSION,
    SUPPORTED_SCHEMA_VERSIONS,
    expected_column_variants_for,
)


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"


class Phase1ValidationError(RuntimeError):
    """Raised when a schema v8 run violates its data or lineage contract."""


@dataclass(frozen=True)
class Phase1RunValidation:
    run_id: str
    run_path: Path
    config_id: str
    feature_rows: int
    execution_check_rows: int
    outcome_rows: int
    cycle_rows: int
    revision_rows: int
    attempt_rows: int
    joined_rows: int
    duplicate_feature_ids: int
    duplicate_outcome_ids: int
    missing_outcomes: int
    missing_features: int
    path_label_columns_present: bool
    warnings: tuple[str, ...]


def _tsv_header(path: Path) -> tuple[str, ...]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        header = handle.readline().rstrip("\r\n")
    return tuple(header.split("\t")) if header else ()


def _read_tsv(path: Path, filename: str) -> list[dict[str, str]]:
    if not path.is_file():
        raise Phase1ValidationError(f"Missing schema v8 file: {filename}")
    header = _tsv_header(path)
    expected = expected_column_variants_for(filename)
    if header not in expected:
        raise Phase1ValidationError(
            f"Unexpected {filename} header; historical schema files require their historical code revision"
        )
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if any(None in row for row in rows):
        raise Phase1ValidationError(f"Malformed extra columns in {filename}")
    return rows


def _required_int(value: str, field: str, filename: str) -> int:
    if value in ("", NULL_TOKEN, None):
        raise Phase1ValidationError(f"Missing integer {field} in {filename}")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise Phase1ValidationError(f"Invalid integer {field} in {filename}: {value!r}") from exc


def _required_float(value: str, field: str, filename: str) -> float:
    if value in ("", NULL_TOKEN, None):
        raise Phase1ValidationError(f"Missing float {field} in {filename}")
    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise Phase1ValidationError(f"Invalid float {field} in {filename}: {value!r}") from exc
    if not math.isfinite(parsed):
        raise Phase1ValidationError(f"Non-finite float {field} in {filename}")
    return parsed


def _optional_float(value: str) -> float | None:
    if value in ("", NULL_TOKEN, None):
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        raise ValueError("non-finite optional float")
    return parsed


def _parse_time(value: str, field: str, filename: str) -> datetime | None:
    if value in ("", NULL_TOKEN, None):
        return None
    try:
        return datetime.strptime(value, TIMESTAMP_FORMAT)
    except ValueError as exc:
        raise Phase1ValidationError(f"Invalid timestamp {field} in {filename}: {value!r}") from exc


def _validate_time_pair(row: dict[str, str], broker_field: str, analysis_field: str, offset_field: str, filename: str) -> datetime | None:
    broker = _parse_time(row.get(broker_field, NULL_TOKEN), broker_field, filename)
    analysis = _parse_time(row.get(analysis_field, NULL_TOKEN), analysis_field, filename)
    offset = row.get(offset_field, NULL_TOKEN)
    if broker is None or analysis is None:
        if broker is not None or analysis is not None or offset not in ("", NULL_TOKEN, None):
            raise Phase1ValidationError(
                f"Incomplete broker/analysis timestamp pair in {filename}: {broker_field}"
            )
        return None
    applied_offset = _required_int(offset, offset_field, filename)
    if analysis != broker + timedelta(minutes=applied_offset):
        raise Phase1ValidationError(
            f"Inconsistent analysis time conversion in {filename}: {broker_field}"
        )
    return broker


def _validate_row_time_pairs(rows: Iterable[dict[str, str]], filename: str) -> None:
    fields = {
        "entry": ("entry_broker_time", "entry_analysis_time", "entry_offset_minutes"),
        "source": ("source_broker_time", "source_analysis_time", "source_offset_minutes"),
        "terminal": ("terminal_broker_time", "terminal_analysis_time", "terminal_offset_minutes"),
        "cycle_first": ("cycle_first_seen_broker_time", "cycle_first_seen_analysis_time", "cycle_first_seen_offset_minutes"),
        "cycle_final": ("cycle_finalized_broker_time", "cycle_finalized_analysis_time", "cycle_finalized_offset_minutes"),
        "peak": ("reference_peak_broker_time", "reference_peak_analysis_time", "reference_peak_offset_minutes"),
        "bottom": ("reference_bottom_broker_time", "reference_bottom_analysis_time", "reference_bottom_offset_minutes"),
        "first": ("first_extremum_broker_time", "first_extremum_analysis_time", "first_extremum_offset_minutes"),
        "final": ("final_extremum_broker_time", "final_extremum_analysis_time", "final_extremum_offset_minutes"),
        "snapshot": ("snapshot_broker_time", "snapshot_analysis_time", "snapshot_offset_minutes"),
        "extremum": ("extremum_broker_time", "extremum_analysis_time", "extremum_offset_minutes"),
        "attempt": ("attempt_created_broker_time", "attempt_created_analysis_time", "attempt_created_offset_minutes"),
        "trigger": ("trigger_broker_time", "trigger_analysis_time", "trigger_offset_minutes"),
        "check": ("broker_time", "analysis_time", "offset_minutes"),
        "summary_started": ("started_broker_time", "started_analysis_time", "started_offset_minutes"),
        "summary_finished": ("finished_broker_time", "finished_analysis_time", "finished_offset_minutes"),
    }
    for row in rows:
        for broker_field, analysis_field, offset_field in fields.values():
            if broker_field in row:
                _validate_time_pair(row, broker_field, analysis_field, offset_field, filename)


def _manifest_dict(rows: list[dict[str, str]]) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in rows:
        schema = _required_int(row["schema_version"], "schema_version", RUN_MANIFEST_FILE)
        if schema != SUPPORTED_SCHEMA_VERSION:
            raise Phase1ValidationError(
                f"Historical schema {schema} requires its historical code revision; active schema is {SUPPORTED_SCHEMA_VERSION}"
            )
        key = row["key"]
        if key in result and result[key] != row["value"]:
            raise Phase1ValidationError(f"Conflicting manifest key: {key}")
        result[key] = row["value"]
    for key in (
        "run_id", "config_id", "engine_id", "engine_label", "engine_timeframe",
        "broker_session", "time_policy", "numeric_feature_set",
        "started_broker_time", "started_analysis_time", "started_offset_minutes",
    ):
        if not result.get(key):
            raise Phase1ValidationError(f"Missing manifest key: {key}")
    if result["numeric_feature_set"] != "schema_v8_extremum_engine":
        raise Phase1ValidationError("Manifest numeric_feature_set is not schema_v8_extremum_engine")
    _validate_time_pair(
        result,
        "started_broker_time",
        "started_analysis_time",
        "started_offset_minutes",
        RUN_MANIFEST_FILE,
    )
    return result


def _validate_schema_rows(rows_by_file: dict[str, list[dict[str, str]]]) -> None:
    for filename, rows in rows_by_file.items():
        for row in rows:
            schema = _required_int(row["schema_version"], "schema_version", filename)
            if schema != SUPPORTED_SCHEMA_VERSION:
                raise Phase1ValidationError(
                    f"Historical schema {schema} requires its historical code revision; active schema is {SUPPORTED_SCHEMA_VERSION}"
                )


def _count_duplicates(values: Iterable[str]) -> int:
    values_list = list(values)
    return len(values_list) - len(set(values_list))


_EXECUTION_CHECK_PHASES = {
    "ATTEMPT_OBSERVED",
    "OPERATIONAL_BLOCK",
    "PRE_FILTER",
    "FILTER_RESULT",
    "PRE_SEND",
    "SEND_RESULT",
    "BROKER_ACTIVE",
    "BROKER_CLOSED",
    "BROKER_TERMINAL",
    "LIFECYCLE_CANCELED",
}


def _validate_execution_checks(
    attempts: list[dict[str, str]],
    checks: list[dict[str, str]],
) -> dict[str, tuple[str, str, str]]:
    attempts_by_id = {attempt["attempt_id"]: attempt for attempt in attempts}
    checks_by_attempt: dict[str, list[dict[str, str]]] = {}
    for check in checks:
        key = check["extremum_attempt_id"]
        attempt = attempts_by_id.get(key)
        if attempt is None:
            raise Phase1ValidationError(f"Orphan execution check for attempt {key}")
        if check["check_phase"] not in _EXECUTION_CHECK_PHASES:
            raise Phase1ValidationError(
                f"Unsupported execution check phase for {key}: {check['check_phase']}"
            )
        for check_field, attempt_field in (
            ("run_id", "run_id"),
            ("config_id", "config_id"),
            ("engine_id", "engine_id"),
            ("engine_label", "engine_label"),
            ("engine_timeframe", "engine_timeframe"),
            ("extremum_cycle_id", "extremum_cycle_id"),
            ("extremum_revision_id", "revision_id"),
            ("symbol", "symbol"),
            ("direction", "direction"),
        ):
            if check[check_field] != attempt[attempt_field]:
                raise Phase1ValidationError(
                    f"Execution check genealogy mismatch for {key}: {check_field}"
                )
        if check["signal_id"] in ("", NULL_TOKEN) or check["signal_id"] != attempt["broker_signal_id"]:
            raise Phase1ValidationError(f"Execution check signal genealogy mismatch for {key}")
        checks_by_attempt.setdefault(key, []).append(check)
    for attempt in attempts:
        attempt_id = attempt["attempt_id"]
        rows = checks_by_attempt.get(attempt_id, [])
        observations = [row for row in rows if row["check_phase"] == "ATTEMPT_OBSERVED"]
        if len(observations) != 1:
            if not observations:
                raise Phase1ValidationError(f"Attempt {attempt_id} has no ATTEMPT_OBSERVED check")
            raise Phase1ValidationError(
                f"Attempt {attempt_id} must have exactly one ATTEMPT_OBSERVED check"
            )
        ordered = sorted(rows, key=lambda row: _required_int(row["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE))
        if ordered[0]["check_phase"] != "ATTEMPT_OBSERVED":
            raise Phase1ValidationError(f"Attempt {attempt_id} does not begin with ATTEMPT_OBSERVED")
        if _required_int(ordered[0]["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE) != 1:
            raise Phase1ValidationError(f"Attempt {attempt_id} check sequence does not begin at 1")
        identity = tuple(
            ordered[0][field] for field in ("signal_id", "source_key", "source_attempt_index")
        )
        previous_sequence = 0
        previous_time: datetime | None = None
        for row in ordered:
            if tuple(row[field] for field in ("signal_id", "source_key", "source_attempt_index")) != identity:
                raise Phase1ValidationError(f"Execution check identity changed for {attempt_id}")
            sequence = _required_int(row["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
            if sequence <= previous_sequence:
                raise Phase1ValidationError(f"Non-monotonic broker check sequence for {attempt_id}")
            previous_sequence = sequence
            broker_time = _parse_time(row["broker_time"], "broker_time", EXECUTION_CHECKS_FILE)
            if broker_time is None:
                raise Phase1ValidationError(f"Execution check has no broker time for {attempt_id}")
            if previous_time is not None and broker_time is not None and broker_time < previous_time:
                raise Phase1ValidationError(f"Broker check time moved backwards for {attempt_id}")
            previous_time = broker_time
        send_rows = [row for row in rows if row["check_phase"] == "SEND_RESULT"]
        if len(send_rows) > 1:
            raise Phase1ValidationError(f"Attempt {attempt_id} has multiple SEND_RESULT checks")
        pre_send_rows = [row for row in rows if row["check_phase"] == "PRE_SEND"]
        if send_rows:
            send = send_rows[0]
            preceding_pre_send = [
                row for row in ordered
                if row["check_phase"] == "PRE_SEND"
                and _required_int(row["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
                < _required_int(send["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
            ]
            if not preceding_pre_send:
                raise Phase1ValidationError(f"Send result has no PRE_SEND check for {attempt_id}")
            pre_send = preceding_pre_send[-1]
            pre_send_sequence = _required_int(pre_send["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
            send_sequence = _required_int(send["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
            if pre_send_sequence + 1 != send_sequence:
                raise Phase1ValidationError(f"Send result is not chained to PRE_SEND for {attempt_id}")
            if pre_send["allowed"] != "1":
                raise Phase1ValidationError(f"Send result follows a blocked PRE_SEND check for {attempt_id}")
            if send["allowed"] == "1" and send["order_check_allowed"] != "1":
                raise Phase1ValidationError(f"Allowed send lacks allowed OrderCheck for {attempt_id}")
        elif any(row["allowed"] == "1" for row in pre_send_rows):
            raise Phase1ValidationError(f"Allowed PRE_SEND has no SEND_RESULT for {attempt_id}")

        filter_results = [row for row in rows if row["check_phase"] == "FILTER_RESULT"]
        pre_filter_rows = [row for row in rows if row["check_phase"] == "PRE_FILTER"]
        for result in filter_results:
            result_sequence = _required_int(result["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE)
            if not any(
                _required_int(row["check_sequence"], "check_sequence", EXECUTION_CHECKS_FILE) < result_sequence
                for row in pre_filter_rows
            ):
                raise Phase1ValidationError(f"FILTER_RESULT has no PRE_FILTER check for {attempt_id}")

        active_rows = [row for row in rows if row["check_phase"] == "BROKER_ACTIVE"]
        closed_rows = [row for row in rows if row["check_phase"] == "BROKER_CLOSED"]
        for active in active_rows:
            if active["broker_entry_confirmed"] != "1":
                raise Phase1ValidationError(f"BROKER_ACTIVE lacks broker entry evidence for {attempt_id}")
        for closed in closed_rows:
            if closed["broker_entry_confirmed"] != "1" or closed["broker_close_confirmed"] != "1":
                raise Phase1ValidationError(f"BROKER_CLOSED lacks broker close evidence for {attempt_id}")
    return {
        attempt_id: (
            rows[0]["signal_id"],
            rows[0]["source_key"],
            rows[0]["source_attempt_index"],
        )
        for attempt_id, rows in checks_by_attempt.items()
    }


def _validate_attempt_row_link(
    row: dict[str, str],
    attempt: dict[str, str],
    identity: tuple[str, str, str],
    filename: str,
) -> None:
    for row_field, attempt_field in (
        ("run_id", "run_id"),
        ("config_id", "config_id"),
        ("symbol", "symbol"),
        ("engine_id", "engine_id"),
        ("engine_label", "engine_label"),
        ("engine_timeframe", "engine_timeframe"),
        ("extremum_cycle_id", "extremum_cycle_id"),
        ("extremum_revision_id", "revision_id"),
        ("extremum_attempt_id", "attempt_id"),
    ):
        if row_field not in row:
            continue
        if row[row_field] != attempt[attempt_field]:
            raise Phase1ValidationError(
                f"{filename} genealogy mismatch for {attempt['attempt_id']}: {row_field}"
            )
    if row["signal_id"] != identity[0] or row["source_key"] != identity[1] or row["source_attempt_index"] != identity[2]:
        raise Phase1ValidationError(
            f"{filename} signal genealogy mismatch for {attempt['attempt_id']}"
        )


def validate_phase1_run(
    runs_root: Path,
    run_id: str,
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> Phase1RunValidation:
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise Phase1ValidationError(
            f"Historical schema {schema_version} requires its historical code revision; active schema is {SUPPORTED_SCHEMA_VERSION}"
        )
    run_path = runs_root / run_id
    if not run_path.is_dir():
        raise Phase1ValidationError(f"Run folder does not exist: {run_path}")
    actual_files = {path.name for path in run_path.glob("*.tsv")}
    expected_files = set(PHASE1_FILES)
    missing = sorted(expected_files - actual_files)
    extra = sorted(actual_files - expected_files)
    if missing or extra:
        detail = []
        if missing:
            detail.append("missing=" + ",".join(missing))
        if extra:
            detail.append("extra=" + ",".join(extra))
        raise Phase1ValidationError("Schema v8 file set mismatch: " + "; ".join(detail))

    rows_by_file = {filename: _read_tsv(run_path / filename, filename) for filename in PHASE1_FILES}
    _validate_schema_rows(rows_by_file)
    _validate_row_time_pairs(rows_by_file[ENGINE_CYCLES_FILE], ENGINE_CYCLES_FILE)
    _validate_row_time_pairs(rows_by_file[ENGINE_REVISIONS_FILE], ENGINE_REVISIONS_FILE)
    _validate_row_time_pairs(rows_by_file[ENGINE_ATTEMPTS_FILE], ENGINE_ATTEMPTS_FILE)
    _validate_row_time_pairs(rows_by_file[EXECUTION_CHECKS_FILE], EXECUTION_CHECKS_FILE)
    _validate_row_time_pairs(rows_by_file[SIGNAL_FEATURES_FILE], SIGNAL_FEATURES_FILE)
    _validate_row_time_pairs(rows_by_file[SIGNAL_OUTCOMES_FILE], SIGNAL_OUTCOMES_FILE)
    _validate_row_time_pairs(rows_by_file[RUN_SUMMARY_FILE], RUN_SUMMARY_FILE)

    manifest = _manifest_dict(rows_by_file[RUN_MANIFEST_FILE])
    if manifest["run_id"] != run_id:
        raise Phase1ValidationError(f"Manifest run_id mismatch: {manifest['run_id']} != {run_id}")
    config_id = manifest["config_id"]
    for filename, rows in rows_by_file.items():
        for row in rows:
            if row.get("run_id", run_id) != run_id:
                raise Phase1ValidationError(f"run_id mismatch in {filename}")
            if row.get("config_id", config_id) != config_id:
                raise Phase1ValidationError(f"config_id mismatch in {filename}")

    cycles = rows_by_file[ENGINE_CYCLES_FILE]
    revisions = rows_by_file[ENGINE_REVISIONS_FILE]
    attempts = rows_by_file[ENGINE_ATTEMPTS_FILE]
    checks = rows_by_file[EXECUTION_CHECKS_FILE]
    features = rows_by_file[SIGNAL_FEATURES_FILE]
    outcomes = rows_by_file[SIGNAL_OUTCOMES_FILE]
    summary = rows_by_file[RUN_SUMMARY_FILE]
    if len(summary) != 1:
        raise Phase1ValidationError("run_summary.tsv must contain exactly one row")

    cycle_ids = [row["extremum_cycle_id"] for row in cycles]
    revision_ids = [row["revision_id"] for row in revisions]
    attempt_ids = [row["attempt_id"] for row in attempts]
    if _count_duplicates(cycle_ids):
        raise Phase1ValidationError("Duplicate extremum_cycle_id rows")
    if _count_duplicates(revision_ids):
        raise Phase1ValidationError("Duplicate revision_id rows")
    if _count_duplicates(attempt_ids):
        raise Phase1ValidationError("Duplicate attempt_id rows")

    cycles_by_id = {row["extremum_cycle_id"]: row for row in cycles}
    revisions_by_id = {row["revision_id"]: row for row in revisions}
    attempts_by_id = {row["attempt_id"]: row for row in attempts}
    for cycle_id, cycle in cycles_by_id.items():
        if _required_float(cycle["reference_range_points"], "reference_range_points", ENGINE_CYCLES_FILE) <= 0:
            raise Phase1ValidationError(f"Non-positive reference range for cycle {cycle_id}")
        cycle_revisions = [row for row in revisions if row["extremum_cycle_id"] == cycle_id]
        cycle_attempts = [row for row in attempts if row["extremum_cycle_id"] == cycle_id]
        if _required_int(cycle["revision_count"], "revision_count", ENGINE_CYCLES_FILE) != len(cycle_revisions):
            raise Phase1ValidationError(f"Revision count mismatch for cycle {cycle_id}")
        if _required_int(cycle["attempt_count"], "attempt_count", ENGINE_CYCLES_FILE) != len(cycle_attempts):
            raise Phase1ValidationError(f"Attempt count mismatch for cycle {cycle_id}")
        actual_indexes = sorted(_required_int(row["revision_index"], "revision_index", ENGINE_REVISIONS_FILE) for row in cycle_revisions)
        if actual_indexes != list(range(1, len(cycle_revisions) + 1)):
            raise Phase1ValidationError(f"Non-monotonic revision indexes for cycle {cycle_id}")
        for revision in cycle_revisions:
            for field in (
                "reference_peak_broker_time", "reference_peak_analysis_time", "reference_peak_offset_minutes", "reference_peak_price",
                "reference_bottom_broker_time", "reference_bottom_analysis_time", "reference_bottom_offset_minutes", "reference_bottom_price",
                "reference_range_points",
            ):
                if revision[field] != cycle[field]:
                    raise Phase1ValidationError(f"Frozen anchors changed in cycle {cycle_id}")

    for revision in revisions:
        if revision["extremum_cycle_id"] not in cycles_by_id:
            raise Phase1ValidationError(f"Orphan revision {revision['revision_id']}")
        _required_float(revision["depth_percent_raw"], "depth_percent_raw", ENGINE_REVISIONS_FILE)

    for attempt in attempts:
        attempt_id = attempt["attempt_id"]
        if attempt["extremum_cycle_id"] not in cycles_by_id:
            raise Phase1ValidationError(f"Orphan attempt cycle for {attempt_id}")
        revision = revisions_by_id.get(attempt["revision_id"])
        if revision is None or revision["extremum_cycle_id"] != attempt["extremum_cycle_id"]:
            raise Phase1ValidationError(f"Orphan attempt revision for {attempt_id}")
        _required_float(attempt["candidate_depth_percent"], "candidate_depth_percent", ENGINE_ATTEMPTS_FILE)
        trigger_price = _required_float(attempt["trigger_price"], "trigger_price", ENGINE_ATTEMPTS_FILE)
        stop_price = _required_float(attempt["stop_anchor_price"], "stop_anchor_price", ENGINE_ATTEMPTS_FILE)
        target_price = _required_float(attempt["take_profit_price"], "take_profit_price", ENGINE_ATTEMPTS_FILE)
        risk_distance = abs(trigger_price - stop_price)
        if min(trigger_price, stop_price, target_price) <= 0.0 or risk_distance <= 0.0:
            raise Phase1ValidationError(f"Invalid attempt geometry for {attempt_id}")
        direction = attempt["direction"]
        if not ((direction == "BULLISH" and stop_price < trigger_price < target_price) or (direction == "BEARISH" and target_price < trigger_price < stop_price)):
            raise Phase1ValidationError(f"Wrong-side attempt target for {attempt_id}")
        if attempt["simulated_outcome_source"] != "ENGINE_SIMULATION":
            raise Phase1ValidationError(f"Invalid simulated provenance for {attempt_id}")
        if attempt["broker_entry_confirmed"] == "0" and attempt["broker_close_confirmed"] == "1":
            raise Phase1ValidationError(f"Broker close without entry for {attempt_id}")
        if attempt["simulated_terminal_reason"] == "SIMULATED_TARGET":
            simulated_profit_r = _required_float(attempt["simulated_profit_r"], "simulated_profit_r", ENGINE_ATTEMPTS_FILE)
            expected_target_r = abs(target_price - trigger_price) / risk_distance
            if not math.isclose(simulated_profit_r, expected_target_r, rel_tol=1e-5, abs_tol=1e-5):
                raise Phase1ValidationError(f"Simulated target R mismatch for {attempt_id}")

    check_identity_by_attempt = _validate_execution_checks(attempts, checks)
    broker_attempt_by_signal = {
        row["broker_signal_id"]: row for row in attempts if row["broker_signal_id"] not in ("", NULL_TOKEN)
    }
    if len(broker_attempt_by_signal) != sum(
        1 for row in attempts if row["broker_signal_id"] not in ("", NULL_TOKEN)
    ):
        raise Phase1ValidationError("Duplicate broker signal_id rows")
    feature_ids = [row["signal_id"] for row in features]
    outcome_ids = [row["signal_id"] for row in outcomes]
    duplicate_feature_ids = _count_duplicates(feature_ids)
    duplicate_outcome_ids = _count_duplicates(outcome_ids)
    if duplicate_feature_ids or duplicate_outcome_ids:
        raise Phase1ValidationError("Duplicate feature or outcome signal_id rows")

    for feature in features:
        attempt = attempts_by_id.get(feature["extremum_attempt_id"])
        if attempt is None or broker_attempt_by_signal.get(feature["signal_id"]) is not attempt:
            raise Phase1ValidationError(f"Feature {feature['signal_id']} has no matching broker attempt")
        _validate_attempt_row_link(
            feature,
            attempt,
            check_identity_by_attempt[attempt["attempt_id"]],
            SIGNAL_FEATURES_FILE,
        )
        if attempt["broker_entry_confirmed"] != "1":
            raise Phase1ValidationError(f"Feature lacks broker entry evidence: {feature['signal_id']}")

    for outcome in outcomes:
        attempt = attempts_by_id.get(outcome["extremum_attempt_id"])
        if attempt is None or broker_attempt_by_signal.get(outcome["signal_id"]) is not attempt:
            raise Phase1ValidationError(f"Broker outcome {outcome['signal_id']} has no matching intrinsic attempt")
        _validate_attempt_row_link(
            outcome,
            attempt,
            check_identity_by_attempt[attempt["attempt_id"]],
            SIGNAL_OUTCOMES_FILE,
        )
        if outcome["broker_entry_confirmed"] != "1" or outcome["broker_close_confirmed"] != "1":
            raise Phase1ValidationError(f"Broker outcome lacks confirmed evidence: {outcome['signal_id']}")
        if attempt["broker_entry_confirmed"] != "1" or attempt["broker_close_confirmed"] != "1":
            raise Phase1ValidationError(f"Attempt broker flags disagree with outcome {outcome['signal_id']}")
        entry_time = _parse_time(outcome["entry_broker_time"], "entry_broker_time", SIGNAL_OUTCOMES_FILE)
        terminal_time = _parse_time(outcome["terminal_broker_time"], "terminal_broker_time", SIGNAL_OUTCOMES_FILE)
        if entry_time is None or terminal_time is None or terminal_time < entry_time:
            raise Phase1ValidationError(f"Invalid broker outcome chronology: {outcome['signal_id']}")
        duration = _required_int(outcome["duration_seconds"], "duration_seconds", SIGNAL_OUTCOMES_FILE)
        if duration != int((terminal_time - entry_time).total_seconds()):
            raise Phase1ValidationError(f"Broker duration disagrees with broker timestamps: {outcome['signal_id']}")

    _summary = summary[0]
    for field, expected in (
        ("cycle_rows", len(cycles)),
        ("revision_rows", len(revisions)),
        ("attempt_rows", len(attempts)),
        ("execution_check_rows", len(checks)),
        ("feature_rows", len(features)),
        ("outcome_rows", len(outcomes)),
    ):
        if _required_int(_summary[field], field, RUN_SUMMARY_FILE) != expected:
            raise Phase1ValidationError(f"Summary counter mismatch for {field}")

    feature_set = set(feature_ids)
    outcome_set = set(outcome_ids)
    missing_outcome_ids = feature_set - outcome_set
    missing_feature_ids = outcome_set - feature_set
    if missing_feature_ids:
        raise Phase1ValidationError("Broker outcomes without feature evidence")
    warnings: list[str] = []
    if missing_outcome_ids:
        for signal_id in missing_outcome_ids:
            attempt = next(row for row in attempts if row.get("broker_signal_id") == signal_id)
            if attempt["broker_close_confirmed"] == "1":
                raise Phase1ValidationError(f"Closed broker attempt lacks outcome evidence: {attempt['attempt_id']}")
        warnings.append(f"{len(missing_outcome_ids)} broker-entered feature rows remain open and are excluded from supervised training")

    for outcome in outcomes:
        profit_r = _required_float(outcome["profit_r"], "profit_r", SIGNAL_OUTCOMES_FILE)
        terminal_reason = outcome["terminal_reason"]
        if terminal_reason in ("TP", "BROKER_PROFIT") and profit_r <= 0.0:
            raise Phase1ValidationError(f"Profitable outcome has non-positive profit_r: {outcome['signal_id']}")
        if terminal_reason in ("SL", "BROKER_LOSS") and profit_r >= 0.0:
            raise Phase1ValidationError(f"Loss outcome has non-negative profit_r: {outcome['signal_id']}")

    return Phase1RunValidation(
        run_id=run_id,
        run_path=run_path,
        config_id=config_id,
        feature_rows=len(features),
        execution_check_rows=len(checks),
        outcome_rows=len(outcomes),
        cycle_rows=len(cycles),
        revision_rows=len(revisions),
        attempt_rows=len(attempts),
        joined_rows=len(feature_set & outcome_set),
        duplicate_feature_ids=duplicate_feature_ids,
        duplicate_outcome_ids=duplicate_outcome_ids,
        missing_outcomes=len(missing_outcome_ids),
        missing_features=len(missing_feature_ids),
        path_label_columns_present=True,
        warnings=tuple(warnings),
    )


def validate_phase1_runs(
    runs_root: Path,
    run_ids: Iterable[str],
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
    allow_mixed_config: bool = False,
) -> list[Phase1RunValidation]:
    selected_run_ids = list(run_ids)
    if _count_duplicates(selected_run_ids):
        raise Phase1ValidationError("Duplicate run_id selection is not allowed")
    validations = [
        validate_phase1_run(runs_root, run_id, schema_version=schema_version)
        for run_id in selected_run_ids
    ]
    config_ids = {validation.config_id for validation in validations}
    if len(config_ids) > 1 and not allow_mixed_config:
        raise Phase1ValidationError(
            "Mixed config_id values are not allowed without --allow-mixed-config: "
            + ", ".join(sorted(config_ids))
        )
    return validations
