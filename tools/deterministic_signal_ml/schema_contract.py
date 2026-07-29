"""Strict schema V9 contract and referential validator for pivot-fractal exports."""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable


SUPPORTED_SCHEMA_VERSION = 9
SUPPORTED_ENGINE_LABEL = "PIVOT_FRACTAL_V1"
SUPPORTED_FEATURE_SET_ID = "schema_v9_pivot_fractal_xgb"
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
PIVOT_WINDOWS_FILE = "pivot_windows.tsv"
PIVOT_LEVELS_FILE = "pivot_levels.tsv"
SIGNAL_ATTEMPTS_FILE = "signal_attempts.tsv"
SIGNAL_FEATURES_FILE = "signal_features.tsv"
EXECUTION_CHECKS_FILE = "execution_checks.tsv"
TRAILING_EVENTS_FILE = "trailing_events.tsv"
SIGNAL_OUTCOMES_FILE = "signal_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"

RUN_FILES = (
    RUN_MANIFEST_FILE,
    PIVOT_WINDOWS_FILE,
    PIVOT_LEVELS_FILE,
    SIGNAL_ATTEMPTS_FILE,
    SIGNAL_FEATURES_FILE,
    EXECUTION_CHECKS_FILE,
    TRAILING_EVENTS_FILE,
    SIGNAL_OUTCOMES_FILE,
    RUN_SUMMARY_FILE,
)

MANIFEST_COLUMNS = ("schema_version", "key", "value")
PIVOT_WINDOW_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "active_bar_open_analysis_time",
    "active_bar_open_offset_minutes",
    "source_bar_open_broker_time",
    "source_bar_open_analysis_time",
    "source_bar_open_offset_minutes",
    "source_close_boundary_broker_time",
    "source_close_boundary_analysis_time",
    "source_close_boundary_offset_minutes",
    "source_high",
    "source_low",
    "source_close",
    "source_range",
    "window_state",
    "invalid_reason",
    "terminal_broker_time",
    "terminal_analysis_time",
    "terminal_offset_minutes",
    "terminal_status",
)
PIVOT_LEVEL_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "raw_price",
    "trade_price",
    "level_order",
)
SIGNAL_ATTEMPT_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "trigger_broker_time",
    "trigger_analysis_time",
    "trigger_offset_minutes",
    "previous_m1_bar_open_broker_time",
    "previous_m1_close_boundary_broker_time",
    "previous_m1_bid_close",
    "trigger_bid",
    "trigger_ask",
    "spread_points",
    "intended_entry_price",
    "initial_stop_loss",
    "terminal_take_profit",
    "route_status",
    "attempt_status",
    "block_source",
    "block_reason",
    "feature_snapshot_complete",
    "send_attempted",
)
SIGNAL_FEATURE_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "trigger_broker_time",
    "trigger_analysis_time",
    "trigger_offset_minutes",
    "context_timeframe",
    "structure_0",
    "structure_1",
    "structure_2",
    "b_percent_0",
    "b_percent_1",
    "b_percent_2",
    "b_percent_3",
    "b_percent_4",
    "b_percent_5",
    "structure_complete",
    "b_percent_complete",
    "feature_complete",
    "invalid_reason",
)
EXECUTION_CHECK_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "check_sequence",
    "check_phase",
    "broker_time",
    "analysis_time",
    "offset_minutes",
    "symbol",
    "direction",
    "account_margin_mode",
    "account_margin_mode_supported",
    "symbol_trade_mode",
    "symbol_trade_mode_allowed",
    "market_session_open",
    "account_trade_allowed",
    "account_expert_trade_allowed",
    "terminal_trade_allowed",
    "mql_trade_allowed",
    "bid",
    "ask",
    "spread_points",
    "point_size",
    "stops_distance_points",
    "freeze_distance_points",
    "planned_entry_price",
    "stop_loss_price",
    "take_profit_price",
    "risk_distance",
    "requested_volume",
    "normalized_volume",
    "volume_min",
    "volume_max",
    "volume_step",
    "volume_valid",
    "account_balance",
    "free_margin",
    "required_margin",
    "margin_valid",
    "geometry_valid",
    "stop_distance_valid",
    "freeze_distance_valid",
    "order_check_performed",
    "order_check_allowed",
    "order_check_retcode",
    "order_check_comment",
    "allowed",
    "block_source",
    "block_reason",
    "send_retcode",
    "send_comment",
    "order_ticket",
    "deal_ticket",
    "position_ticket",
    "position_identifier",
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "broker_entry_price",
    "broker_volume",
    "broker_stop_loss",
    "broker_take_profit",
    "close_price",
    "closed_volume",
    "realized_profit",
    "terminal_reason",
)
TRAILING_EVENT_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "event_sequence",
    "event_broker_time",
    "event_analysis_time",
    "event_offset_minutes",
    "symbol",
    "direction",
    "position_ticket",
    "position_identifier",
    "milestone_level",
    "milestone_price",
    "previous_confirmed_stop",
    "desired_stop",
    "requested_stop",
    "confirmed_stop",
    "take_profit",
    "request_performed",
    "request_succeeded",
    "retcode",
    "comment",
    "retry_pending",
    "event_status",
)
SIGNAL_OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "entry_broker_time",
    "entry_analysis_time",
    "entry_offset_minutes",
    "close_broker_time",
    "close_analysis_time",
    "close_offset_minutes",
    "order_ticket",
    "entry_deal_ticket",
    "close_deal_ticket",
    "position_ticket",
    "position_identifier",
    "broker_entry_price",
    "broker_volume",
    "initial_stop_loss",
    "terminal_take_profit",
    "final_broker_stop_loss",
    "final_broker_take_profit",
    "close_price",
    "closed_volume",
    "realized_profit",
    "highest_milestone_level",
    "terminal_reason",
    "duration_seconds",
    "broker_entry_confirmed",
    "broker_close_confirmed",
)
SUMMARY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "started_broker_time",
    "started_analysis_time",
    "started_offset_minutes",
    "finished_broker_time",
    "finished_analysis_time",
    "finished_offset_minutes",
    "pivot_window_rows",
    "pivot_level_rows",
    "signal_attempt_rows",
    "signal_feature_rows",
    "execution_check_rows",
    "trailing_event_rows",
    "signal_outcome_rows",
    "feature_incomplete_rows",
    "duplicate_identity_count",
    "referential_integrity_error_count",
    "row_integrity_error_count",
    "export_status",
    "completion_status",
)

TABLE_COLUMNS = {
    RUN_MANIFEST_FILE: MANIFEST_COLUMNS,
    PIVOT_WINDOWS_FILE: PIVOT_WINDOW_COLUMNS,
    PIVOT_LEVELS_FILE: PIVOT_LEVEL_COLUMNS,
    SIGNAL_ATTEMPTS_FILE: SIGNAL_ATTEMPT_COLUMNS,
    SIGNAL_FEATURES_FILE: SIGNAL_FEATURE_COLUMNS,
    EXECUTION_CHECKS_FILE: EXECUTION_CHECK_COLUMNS,
    TRAILING_EVENTS_FILE: TRAILING_EVENT_COLUMNS,
    SIGNAL_OUTCOMES_FILE: SIGNAL_OUTCOME_COLUMNS,
    RUN_SUMMARY_FILE: SUMMARY_COLUMNS,
}

PIVOT_TIMEFRAMES = ("PERIOD_M15", "PERIOD_M30", "PERIOD_H1", "PERIOD_H4", "PERIOD_D1")
CONTEXT_TIMEFRAMES = (
    "PERIOD_M1",
    "PERIOD_M15",
    "PERIOD_M30",
    "PERIOD_H1",
    "PERIOD_H4",
    "PERIOD_D1",
)
PIVOT_LEVELS = ("S3", "S2", "S1", "PP", "R1", "R2", "R3")
STRUCTURE_TOKENS = ("EQ", "HH", "HL", "LH", "LL")
CONTEXT_PREFIXES = {
    "PERIOD_M1": "m1",
    "PERIOD_M15": "m15",
    "PERIOD_M30": "m30",
    "PERIOD_H1": "h1",
    "PERIOD_H4": "h4",
    "PERIOD_D1": "d1",
}

BASE_CATEGORICAL_FEATURE_COLUMNS = (
    "symbol",
    "pivot_timeframe",
    "level_id",
    "direction",
    "analysis_weekday",
)
CONTEXT_CATEGORICAL_FEATURE_COLUMNS = tuple(
    f"{CONTEXT_PREFIXES[timeframe]}_structure_{slot}"
    for timeframe in CONTEXT_TIMEFRAMES
    for slot in range(3)
)
CATEGORICAL_COLUMNS = BASE_CATEGORICAL_FEATURE_COLUMNS + CONTEXT_CATEGORICAL_FEATURE_COLUMNS

BASE_NUMERIC_FEATURE_COLUMNS = (
    "trigger_offset_minutes",
    "analysis_hour",
    "analysis_minute",
    "time_sin",
    "time_cos",
    "source_range",
    "level_trade_price",
    "level_order",
    "previous_m1_bid_close",
    "trigger_bid",
    "trigger_ask",
    "spread_points",
    "intended_entry_price",
    "initial_stop_loss",
    "terminal_take_profit",
    "previous_close_delta_to_level",
    "trigger_delta_to_level",
    "risk_distance",
    "reward_distance",
    "previous_close_delta_to_range",
    "trigger_delta_to_range",
    "risk_to_range",
    "reward_to_range",
)
CONTEXT_NUMERIC_FEATURE_COLUMNS = tuple(
    f"{CONTEXT_PREFIXES[timeframe]}_b_percent_{shift}"
    for timeframe in CONTEXT_TIMEFRAMES
    for shift in range(6)
)
NUMERIC_FEATURE_COLUMNS = BASE_NUMERIC_FEATURE_COLUMNS + CONTEXT_NUMERIC_FEATURE_COLUMNS
MODEL_FEATURE_COLUMNS = CATEGORICAL_COLUMNS + NUMERIC_FEATURE_COLUMNS
FEATURE_SET_COLUMNS = {SUPPORTED_FEATURE_SET_ID: MODEL_FEATURE_COLUMNS}

IDENTITY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "pivot_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "trigger_broker_time",
)
TARGET_COLUMNS = (
    "target_admitted",
    "target_is_profit",
    "target_realized_profit",
    "target_terminal_reason",
    "target_duration_seconds",
)
AUDIT_COLUMNS = (
    "trigger_analysis_time",
    "previous_m1_bid_close",
    "trigger_bid",
    "trigger_ask",
    "attempt_status",
    "block_source",
    "block_reason",
    "broker_entry_price",
    "close_price",
    "highest_milestone_level",
)
DATASET_TARGET_FAMILIES = ("broker_outcome", "admission")

FUTURE_ONLY_COLUMNS = (
    "attempt_status",
    "block_source",
    "block_reason",
    "send_attempted",
    "window_state",
    "terminal_broker_time",
    "terminal_analysis_time",
    "terminal_status",
    "check_phase",
    "allowed",
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "event_status",
    "confirmed_stop",
    "close_broker_time",
    "close_analysis_time",
    "close_price",
    "realized_profit",
    "terminal_reason",
    "duration_seconds",
)

REQUIRED_MANIFEST_KEYS = {
    "run_id",
    "config_id",
    "started_broker_time",
    "symbol",
    "chart_period",
    "engine_id",
    "engine_label",
    "pivot_timeframes",
    "feature_context_timeframes",
    "pivot_formula",
    "source_policy",
    "identity_policy",
    "trigger_policy",
    "execution_price_policy",
    "time_policy",
    "broker_session",
    "lot_mode",
    "lot_size",
    "stoch_structure",
    "b_percent",
    "feature_set_id",
    "outcome_policy",
    "research_approval_state",
}
FIXED_MANIFEST_VALUES = {
    "engine_id": "1",
    "engine_label": SUPPORTED_ENGINE_LABEL,
    "pivot_timeframes": "M15,M30,H1,H4,D1",
    "feature_context_timeframes": "M1,M15,M30,H1,H4,D1",
    "pivot_formula": "CLASSIC_PP_S1_S3_R1_R3",
    "source_policy": "immediately_previous_completed_broker_candle_shift_1",
    "identity_policy": "symbol,timeframe,active_bar_open,level_first_touch_once",
    "trigger_policy": "previous_completed_m1_bid_close_side_live_bid_touch",
    "execution_price_policy": "buy_ask_sell_bid_market_deal",
    "time_policy": "broker_time_causal_analysis_time_export_only",
    "feature_set_id": SUPPORTED_FEATURE_SET_ID,
    "outcome_policy": "broker_confirmed_only",
    "research_approval_state": "OFFLINE_RESEARCH_ONLY",
}


class SchemaValidationError(RuntimeError):
    """Raised when a run violates the strict V9 export contract."""


@dataclass(frozen=True)
class DatasetColumnGroups:
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS
    target_columns: tuple[str, ...] = TARGET_COLUMNS
    identity_columns: tuple[str, ...] = IDENTITY_COLUMNS
    audit_columns: tuple[str, ...] = AUDIT_COLUMNS


@dataclass(frozen=True)
class RunValidation:
    run_id: str
    config_id: str
    run_path: Path
    manifest: dict[str, str]
    row_counts: dict[str, int]
    warnings: tuple[str, ...] = ()

    @property
    def pivot_window_rows(self) -> int:
        return self.row_counts[PIVOT_WINDOWS_FILE]

    @property
    def pivot_level_rows(self) -> int:
        return self.row_counts[PIVOT_LEVELS_FILE]

    @property
    def signal_attempt_rows(self) -> int:
        return self.row_counts[SIGNAL_ATTEMPTS_FILE]

    @property
    def signal_feature_rows(self) -> int:
        return self.row_counts[SIGNAL_FEATURES_FILE]

    @property
    def execution_check_rows(self) -> int:
        return self.row_counts[EXECUTION_CHECKS_FILE]

    @property
    def trailing_event_rows(self) -> int:
        return self.row_counts[TRAILING_EVENTS_FILE]

    @property
    def signal_outcome_rows(self) -> int:
        return self.row_counts[SIGNAL_OUTCOMES_FILE]


def _require_active_schema(schema_version: int) -> None:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise ValueError(
            f"Unsupported schema version {schema_version}; "
            f"active tooling accepts {SUPPORTED_SCHEMA_VERSION} only"
        )


def expected_columns_for(
    filename: str,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> tuple[str, ...]:
    _require_active_schema(schema_version)
    try:
        return TABLE_COLUMNS[filename]
    except KeyError as exc:
        raise ValueError(f"Unknown schema V9 file: {filename}") from exc


def feature_columns_for_set(feature_set_id: str) -> tuple[str, ...]:
    try:
        return FEATURE_SET_COLUMNS[feature_set_id]
    except KeyError as exc:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}") from exc


def schema_version_for_feature_set(feature_set_id: str) -> int:
    feature_columns_for_set(feature_set_id)
    return SUPPORTED_SCHEMA_VERSION


def default_feature_set_for_schema(schema_version: int) -> str:
    _require_active_schema(schema_version)
    return SUPPORTED_FEATURE_SET_ID


def _is_null(value: str | None) -> bool:
    return value in (None, "", NULL_TOKEN)


def _require_value(row: dict[str, str], column: str, context: str) -> str:
    value = row.get(column)
    if _is_null(value):
        raise SchemaValidationError(f"{context}: required value is null: {column}")
    return str(value)


def _as_int(row: dict[str, str], column: str, context: str, *, nullable: bool = False) -> int | None:
    value = row.get(column)
    if _is_null(value):
        if nullable:
            return None
        raise SchemaValidationError(f"{context}: required integer is null: {column}")
    try:
        return int(str(value))
    except ValueError as exc:
        raise SchemaValidationError(f"{context}: invalid integer {column}={value}") from exc


def _as_float(
    row: dict[str, str],
    column: str,
    context: str,
    *,
    nullable: bool = False,
) -> float | None:
    value = row.get(column)
    if _is_null(value):
        if nullable:
            return None
        raise SchemaValidationError(f"{context}: required number is null: {column}")
    try:
        number = float(str(value))
    except ValueError as exc:
        raise SchemaValidationError(f"{context}: invalid number {column}={value}") from exc
    if not math.isfinite(number):
        raise SchemaValidationError(f"{context}: non-finite number {column}={value}")
    return number


def _as_bool(row: dict[str, str], column: str, context: str) -> bool:
    value = _require_value(row, column, context)
    if value not in ("0", "1"):
        raise SchemaValidationError(f"{context}: invalid boolean {column}={value}")
    return value == "1"


def _as_time(row: dict[str, str], column: str, context: str, *, nullable: bool = False) -> datetime | None:
    value = row.get(column)
    if _is_null(value):
        if nullable:
            return None
        raise SchemaValidationError(f"{context}: required timestamp is null: {column}")
    try:
        return datetime.strptime(str(value), "%Y.%m.%d %H:%M:%S")
    except ValueError as exc:
        raise SchemaValidationError(f"{context}: invalid timestamp {column}={value}") from exc


def _same_number(left: float, right: float, tolerance: float = 1e-8) -> bool:
    return math.isclose(left, right, rel_tol=tolerance, abs_tol=tolerance)


def _validate_time_triplet(
    row: dict[str, str],
    broker_column: str,
    analysis_column: str,
    offset_column: str,
    context: str,
    *,
    nullable: bool = False,
) -> tuple[datetime | None, datetime | None, int | None]:
    values = (row.get(broker_column), row.get(analysis_column), row.get(offset_column))
    null_count = sum(_is_null(value) for value in values)
    if null_count:
        if nullable and null_count == 3:
            return None, None, None
        raise SchemaValidationError(f"{context}: partial timestamp triplet for {broker_column}")
    broker_time = _as_time(row, broker_column, context)
    analysis_time = _as_time(row, analysis_column, context)
    offset_minutes = _as_int(row, offset_column, context)
    assert broker_time is not None and analysis_time is not None and offset_minutes is not None
    if broker_time + timedelta(minutes=offset_minutes) != analysis_time:
        raise SchemaValidationError(
            f"{context}: inconsistent analysis time conversion for {broker_column}"
        )
    return broker_time, analysis_time, offset_minutes


def _read_tsv(path: Path, expected_columns: tuple[str, ...]) -> list[dict[str, str]]:
    if not path.is_file():
        raise SchemaValidationError(f"Missing required schema V9 file: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        header = handle.readline().rstrip("\r\n").split("\t")
        if tuple(header) != expected_columns:
            raise SchemaValidationError(
                f"Header mismatch for {path.name}: expected {len(expected_columns)} exact columns, "
                f"received {len(header)}"
            )
        reader = csv.DictReader(handle, fieldnames=header, delimiter="\t")
        rows = list(reader)
    for row_index, row in enumerate(rows, start=2):
        if None in row or any(value is None for value in row.values()):
            raise SchemaValidationError(f"Malformed row in {path.name}:{row_index}")
    return rows


def _resolve_run_path(runs_root: Path, run_id: str) -> Path:
    root = runs_root.resolve()
    run_path = (root / run_id).resolve()
    if run_path == root or root not in run_path.parents:
        raise SchemaValidationError(f"Run ID resolves outside runs root: {run_id}")
    if not run_path.is_dir():
        raise SchemaValidationError(f"Run folder does not exist: {run_path}")
    return run_path


def _validate_manifest(rows: list[dict[str, str]], requested_run_id: str) -> dict[str, str]:
    manifest: dict[str, str] = {}
    for row_index, row in enumerate(rows, start=2):
        context = f"{RUN_MANIFEST_FILE}:{row_index}"
        if _as_int(row, "schema_version", context) != SUPPORTED_SCHEMA_VERSION:
            raise SchemaValidationError(f"{context}: unsupported schema version")
        key = _require_value(row, "key", context)
        value = _require_value(row, "value", context)
        if key in manifest:
            raise SchemaValidationError(f"Duplicate manifest key: {key}")
        manifest[key] = value
    if set(manifest) != REQUIRED_MANIFEST_KEYS:
        missing = sorted(REQUIRED_MANIFEST_KEYS - set(manifest))
        extra = sorted(set(manifest) - REQUIRED_MANIFEST_KEYS)
        raise SchemaValidationError(f"Manifest key mismatch: missing={missing} extra={extra}")
    if manifest["run_id"] != requested_run_id:
        raise SchemaValidationError(
            f"Manifest run_id mismatch: folder={requested_run_id} row={manifest['run_id']}"
        )
    for key, expected in FIXED_MANIFEST_VALUES.items():
        if manifest[key] != expected:
            raise SchemaValidationError(
                f"Manifest contract mismatch: {key}={manifest[key]} expected={expected}"
            )
    _as_time({"value": manifest["started_broker_time"]}, "value", "manifest")
    try:
        lot_size = float(manifest["lot_size"])
    except ValueError as exc:
        raise SchemaValidationError("Manifest lot_size is not numeric") from exc
    if not math.isfinite(lot_size) or lot_size <= 0.0:
        raise SchemaValidationError("Manifest lot_size must be finite and positive")
    return manifest


def _validate_common_rows(
    rows: Iterable[dict[str, str]],
    filename: str,
    run_id: str,
    config_id: str,
) -> None:
    for row_index, row in enumerate(rows, start=2):
        context = f"{filename}:{row_index}"
        if _as_int(row, "schema_version", context) != SUPPORTED_SCHEMA_VERSION:
            raise SchemaValidationError(f"{context}: unsupported schema version")
        if row.get("run_id") != run_id:
            raise SchemaValidationError(f"{context}: run_id mismatch")
        if row.get("config_id") != config_id:
            raise SchemaValidationError(f"{context}: config_id mismatch")


def _validate_windows(rows: list[dict[str, str]], symbol: str) -> dict[str, dict[str, str]]:
    windows: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str]] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{PIVOT_WINDOWS_FILE}:{row_index}"
        window_id = _require_value(row, "window_id", context)
        identity = (row["symbol"], row["pivot_timeframe"], row["active_bar_open_broker_time"])
        if window_id in windows or identity in identities:
            raise SchemaValidationError(f"Duplicate pivot window identity: {identity}")
        if row["symbol"] != symbol:
            raise SchemaValidationError(f"{context}: symbol differs from manifest")
        if row["pivot_timeframe"] not in PIVOT_TIMEFRAMES:
            raise SchemaValidationError(f"{context}: unsupported pivot timeframe")
        active_time, _, _ = _validate_time_triplet(
            row,
            "active_bar_open_broker_time",
            "active_bar_open_analysis_time",
            "active_bar_open_offset_minutes",
            context,
        )
        terminal_time, _, _ = _validate_time_triplet(
            row,
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_offset_minutes",
            context,
        )
        assert active_time is not None and terminal_time is not None
        if terminal_time < active_time:
            raise SchemaValidationError(f"{context}: terminal time precedes active window")
        state = _require_value(row, "window_state", context)
        if state not in ("VALID", "INVALID", "PENDING", "EMPTY"):
            raise SchemaValidationError(f"{context}: invalid window state {state}")
        if state == "VALID":
            source_time, _, _ = _validate_time_triplet(
                row,
                "source_bar_open_broker_time",
                "source_bar_open_analysis_time",
                "source_bar_open_offset_minutes",
                context,
            )
            source_close, _, _ = _validate_time_triplet(
                row,
                "source_close_boundary_broker_time",
                "source_close_boundary_analysis_time",
                "source_close_boundary_offset_minutes",
                context,
            )
            assert source_time is not None and source_close is not None
            if not source_time < source_close or source_close != active_time:
                raise SchemaValidationError(
                    f"{context}: source candle boundary is not the active bar open"
                )
            high = _as_float(row, "source_high", context)
            low = _as_float(row, "source_low", context)
            close = _as_float(row, "source_close", context)
            source_range = _as_float(row, "source_range", context)
            assert high is not None and low is not None and close is not None and source_range is not None
            if high <= low or source_range <= 0.0 or not low <= close <= high:
                raise SchemaValidationError(f"{context}: invalid completed source candle")
            if not _same_number(high - low, source_range):
                raise SchemaValidationError(f"{context}: source_range does not equal high-low")
            if not _is_null(row["invalid_reason"]):
                raise SchemaValidationError(f"{context}: valid window has invalid_reason")
        else:
            source_time, _, _ = _validate_time_triplet(
                row,
                "source_bar_open_broker_time",
                "source_bar_open_analysis_time",
                "source_bar_open_offset_minutes",
                context,
                nullable=True,
            )
            source_close, _, _ = _validate_time_triplet(
                row,
                "source_close_boundary_broker_time",
                "source_close_boundary_analysis_time",
                "source_close_boundary_offset_minutes",
                context,
                nullable=True,
            )
            if (source_time is None) != (source_close is None):
                raise SchemaValidationError(f"{context}: partial non-valid source candle identity")
            if source_time is not None and source_close is not None:
                if not source_time < source_close or source_close != active_time:
                    raise SchemaValidationError(
                        f"{context}: non-valid source candle identity is not causal"
                    )
            if _is_null(row["invalid_reason"]):
                raise SchemaValidationError(f"{context}: non-valid window has no invalid_reason")
            for column in ("source_high", "source_low", "source_close", "source_range"):
                _as_float(row, column, context, nullable=True)
        _require_value(row, "terminal_status", context)
        windows[window_id] = row
        identities.add(identity)
    return windows


def _validate_levels(
    rows: list[dict[str, str]],
    windows: dict[str, dict[str, str]],
) -> dict[tuple[str, str], dict[str, str]]:
    levels: dict[tuple[str, str], dict[str, str]] = {}
    by_window: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row_index, row in enumerate(rows, start=2):
        context = f"{PIVOT_LEVELS_FILE}:{row_index}"
        window = windows.get(row["window_id"])
        if window is None:
            raise SchemaValidationError(f"{context}: orphan pivot level")
        if window["window_state"] != "VALID":
            raise SchemaValidationError(f"{context}: level belongs to non-valid window")
        for column in ("symbol", "pivot_timeframe", "active_bar_open_broker_time"):
            if row[column] != window[column]:
                raise SchemaValidationError(f"{context}: level/window mismatch for {column}")
        level_id = _require_value(row, "level_id", context)
        key = (row["window_id"], level_id)
        if key in levels:
            raise SchemaValidationError(f"Duplicate pivot level: {key}")
        if level_id not in PIVOT_LEVELS:
            raise SchemaValidationError(f"{context}: invalid pivot level {level_id}")
        level_order = _as_int(row, "level_order", context)
        if level_order != PIVOT_LEVELS.index(level_id):
            raise SchemaValidationError(f"{context}: level_order does not match level_id")
        raw_price = _as_float(row, "raw_price", context)
        trade_price = _as_float(row, "trade_price", context)
        if raw_price is None or trade_price is None or raw_price <= 0.0 or trade_price <= 0.0:
            raise SchemaValidationError(f"{context}: pivot prices must be positive")
        levels[key] = row
        by_window[row["window_id"]].append(row)

    valid_window_ids = {key for key, row in windows.items() if row["window_state"] == "VALID"}
    if set(by_window) != valid_window_ids:
        raise SchemaValidationError("Every valid pivot window must own exactly seven level rows")
    for window_id, window_levels in by_window.items():
        ordered = sorted(window_levels, key=lambda row: int(row["level_order"]))
        if tuple(row["level_id"] for row in ordered) != PIVOT_LEVELS:
            raise SchemaValidationError(f"Window {window_id} does not contain the exact pivot ladder")
        raw_prices = [float(row["raw_price"]) for row in ordered]
        trade_prices = [float(row["trade_price"]) for row in ordered]
        if any(left >= right for left, right in zip(raw_prices, raw_prices[1:])):
            raise SchemaValidationError(f"Window {window_id} raw pivot ladder is not strictly ordered")
        if any(left >= right for left, right in zip(trade_prices, trade_prices[1:])):
            raise SchemaValidationError(f"Window {window_id} trade pivot ladder is not strictly ordered")
    return levels


def _validate_attempts(
    rows: list[dict[str, str]],
    windows: dict[str, dict[str, str]],
    levels: dict[tuple[str, str], dict[str, str]],
) -> dict[str, dict[str, str]]:
    attempts: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str, str]] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_ATTEMPTS_FILE}:{row_index}"
        signal_id = _require_value(row, "signal_id", context)
        identity = (
            row["symbol"],
            row["pivot_timeframe"],
            row["active_bar_open_broker_time"],
            row["level_id"],
        )
        if signal_id in attempts or identity in identities:
            raise SchemaValidationError(f"Duplicate signal or first-touch identity: {identity}")
        window = windows.get(row["window_id"])
        level = levels.get((row["window_id"], row["level_id"]))
        if window is None or level is None:
            raise SchemaValidationError(f"{context}: orphan signal attempt")
        for column in ("symbol", "pivot_timeframe", "active_bar_open_broker_time"):
            if row[column] != window[column]:
                raise SchemaValidationError(f"{context}: attempt/window mismatch for {column}")
        direction = _require_value(row, "direction", context)
        if direction not in ("BUY", "SELL"):
            raise SchemaValidationError(f"{context}: invalid direction {direction}")
        trigger_time, _, _ = _validate_time_triplet(
            row,
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
            context,
        )
        active_time = _as_time(row, "active_bar_open_broker_time", context)
        terminal_time = _as_time(window, "terminal_broker_time", context)
        previous_bar = _as_time(row, "previous_m1_bar_open_broker_time", context)
        previous_close_boundary = _as_time(
            row, "previous_m1_close_boundary_broker_time", context
        )
        assert trigger_time is not None and active_time is not None and terminal_time is not None
        assert previous_bar is not None and previous_close_boundary is not None
        if not active_time <= trigger_time <= terminal_time:
            raise SchemaValidationError(f"{context}: trigger is outside its active pivot window")
        if not previous_bar < previous_close_boundary <= trigger_time:
            raise SchemaValidationError(f"{context}: previous M1 context is not causal")
        previous_close = _as_float(row, "previous_m1_bid_close", context)
        trigger_bid = _as_float(row, "trigger_bid", context)
        trigger_ask = _as_float(row, "trigger_ask", context)
        spread_points = _as_float(row, "spread_points", context)
        intended_entry = _as_float(row, "intended_entry_price", context, nullable=True)
        level_price = _as_float(level, "trade_price", context)
        assert previous_close is not None and trigger_bid is not None and trigger_ask is not None
        assert spread_points is not None and level_price is not None
        if trigger_ask < trigger_bid or spread_points < 0.0:
            raise SchemaValidationError(f"{context}: invalid Bid/Ask snapshot")
        if intended_entry is not None and not _same_number(intended_entry, level_price):
            raise SchemaValidationError(f"{context}: intended entry differs from captured pivot level")
        if direction == "BUY" and not (previous_close > level_price and trigger_bid <= level_price):
            raise SchemaValidationError(f"{context}: BUY does not use above-to-downward Bid touch")
        if direction == "SELL" and not (previous_close < level_price and trigger_bid >= level_price):
            raise SchemaValidationError(f"{context}: SELL does not use below-to-upward Bid touch")

        route_status = _require_value(row, "route_status", context)
        attempt_status = _require_value(row, "attempt_status", context)
        send_attempted = _as_bool(row, "send_attempted", context)
        if not _as_bool(row, "feature_snapshot_complete", context):
            raise SchemaValidationError(f"{context}: strict run contains incomplete feature snapshot")
        if route_status == "ALLOWED":
            stop_loss = _as_float(row, "initial_stop_loss", context)
            take_profit = _as_float(row, "terminal_take_profit", context)
            if intended_entry is None or stop_loss is None or take_profit is None:
                raise SchemaValidationError(f"{context}: allowed route has null geometry")
            if direction == "BUY" and not stop_loss < intended_entry < take_profit:
                raise SchemaValidationError(f"{context}: invalid BUY route geometry")
            if direction == "SELL" and not take_profit < intended_entry < stop_loss:
                raise SchemaValidationError(f"{context}: invalid SELL route geometry")
        elif route_status == "NO_FORWARD_LEVEL":
            if (direction, row["level_id"]) not in (("BUY", "R3"), ("SELL", "S3")):
                raise SchemaValidationError(f"{context}: unsupported NO_FORWARD_LEVEL combination")
            if attempt_status != "DENIED" or row["block_reason"] != "NO_FORWARD_LEVEL":
                raise SchemaValidationError(f"{context}: no-forward route is not an explicit denial")
            if send_attempted:
                raise SchemaValidationError(f"{context}: unsupported route attempted a send")
        elif route_status != "INVALID_GEOMETRY":
            raise SchemaValidationError(f"{context}: invalid route status {route_status}")
        if send_attempted and attempt_status not in ("SENT", "SEND_FAILED"):
            raise SchemaValidationError(f"{context}: send_attempted disagrees with attempt_status")
        if not send_attempted and attempt_status == "SENT":
            raise SchemaValidationError(f"{context}: SENT attempt has no send attempt")
        attempts[signal_id] = row
        identities.add(identity)
    return attempts


def _validate_features(
    rows: list[dict[str, str]],
    attempts: dict[str, dict[str, str]],
) -> None:
    snapshot_columns = (
        "structure_0",
        "structure_1",
        "structure_2",
        "b_percent_0",
        "b_percent_1",
        "b_percent_2",
        "b_percent_3",
        "b_percent_4",
        "b_percent_5",
        "structure_complete",
        "b_percent_complete",
        "feature_complete",
        "invalid_reason",
    )
    by_signal: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_FEATURES_FILE}:{row_index}"
        attempt = attempts.get(row["signal_id"])
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan signal feature")
        for column in (
            "window_id",
            "symbol",
            "pivot_timeframe",
            "active_bar_open_broker_time",
            "level_id",
            "direction",
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
        ):
            if row[column] != attempt[column]:
                raise SchemaValidationError(f"{context}: feature/attempt mismatch for {column}")
        context_timeframe = _require_value(row, "context_timeframe", context)
        if context_timeframe not in CONTEXT_TIMEFRAMES:
            raise SchemaValidationError(f"{context}: invalid context timeframe")
        for column in ("structure_0", "structure_1", "structure_2"):
            if row[column] not in STRUCTURE_TOKENS:
                raise SchemaValidationError(f"{context}: invalid structure token {column}")
        for shift in range(6):
            _as_float(row, f"b_percent_{shift}", context)
        if not all(
            _as_bool(row, column, context)
            for column in ("structure_complete", "b_percent_complete", "feature_complete")
        ):
            raise SchemaValidationError(f"{context}: strict feature row is incomplete")
        if not _is_null(row["invalid_reason"]):
            raise SchemaValidationError(f"{context}: complete feature row has invalid_reason")
        by_signal[row["signal_id"]].append(row)

    if set(by_signal) != set(attempts):
        missing = sorted(set(attempts) - set(by_signal))
        raise SchemaValidationError(f"Missing feature contexts for signals: {missing}")
    for signal_id, feature_rows in by_signal.items():
        contexts = [row["context_timeframe"] for row in feature_rows]
        if len(contexts) != len(CONTEXT_TIMEFRAMES) or set(contexts) != set(CONTEXT_TIMEFRAMES):
            raise SchemaValidationError(
                f"Signal {signal_id} must have exactly six unique feature contexts"
            )

    # Attempts are emitted in candidate-processing order. Compare only
    # maximal contiguous runs whose trigger tick and M1 context are identical;
    # unrelated later ticks may legitimately reuse the same broker second.
    batch_columns = (
        "symbol",
        "trigger_broker_time",
        "trigger_analysis_time",
        "trigger_offset_minutes",
        "previous_m1_bar_open_broker_time",
        "previous_m1_close_boundary_broker_time",
        "previous_m1_bid_close",
        "trigger_bid",
        "trigger_ask",
        "spread_points",
    )

    def snapshot_signature(signal_id: str) -> tuple[tuple[str, ...], ...]:
        by_context = {
            row["context_timeframe"]: row
            for row in by_signal[signal_id]
        }
        return tuple(
            tuple(by_context[timeframe][column] for column in snapshot_columns)
            for timeframe in CONTEXT_TIMEFRAMES
        )

    previous_batch_key: tuple[str, ...] | None = None
    batch_signal_ids: list[str] = []

    def validate_batch(signal_ids: list[str]) -> None:
        if len(signal_ids) < 2:
            return
        reference_id = signal_ids[0]
        reference_signature = snapshot_signature(reference_id)
        for signal_id in signal_ids[1:]:
            if snapshot_signature(signal_id) != reference_signature:
                raise SchemaValidationError(
                    "same-trigger feature snapshot divergence: "
                    f"{reference_id} vs {signal_id}"
                )

    for signal_id, attempt in attempts.items():
        batch_key = tuple(attempt[column] for column in batch_columns)
        if previous_batch_key is None or batch_key == previous_batch_key:
            batch_signal_ids.append(signal_id)
        else:
            validate_batch(batch_signal_ids)
            batch_signal_ids = [signal_id]
        previous_batch_key = batch_key
    validate_batch(batch_signal_ids)


def _validate_checks(
    rows: list[dict[str, str]],
    attempts: dict[str, dict[str, str]],
) -> dict[str, list[dict[str, str]]]:
    by_signal: dict[str, list[dict[str, str]]] = defaultdict(list)
    boolean_columns = (
        "account_margin_mode_supported",
        "symbol_trade_mode_allowed",
        "market_session_open",
        "account_trade_allowed",
        "account_expert_trade_allowed",
        "terminal_trade_allowed",
        "mql_trade_allowed",
        "volume_valid",
        "margin_valid",
        "geometry_valid",
        "stop_distance_valid",
        "freeze_distance_valid",
        "order_check_performed",
        "order_check_allowed",
        "allowed",
        "broker_entry_confirmed",
        "broker_close_confirmed",
    )
    for row_index, row in enumerate(rows, start=2):
        context = f"{EXECUTION_CHECKS_FILE}:{row_index}"
        attempt = attempts.get(row["signal_id"])
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan execution check")
        for column in ("window_id", "symbol", "direction"):
            if row[column] != attempt[column]:
                raise SchemaValidationError(f"{context}: check/attempt mismatch for {column}")
        _validate_time_triplet(row, "broker_time", "analysis_time", "offset_minutes", context)
        sequence = _as_int(row, "check_sequence", context)
        if sequence is None or sequence <= 0:
            raise SchemaValidationError(f"{context}: check_sequence must be positive")
        for column in boolean_columns:
            _as_bool(row, column, context)
        bid = _as_float(row, "bid", context, nullable=True)
        ask = _as_float(row, "ask", context, nullable=True)
        if bid is not None and ask is not None and ask < bid:
            raise SchemaValidationError(f"{context}: invalid Bid/Ask ordering")
        by_signal[row["signal_id"]].append(row)

    if set(by_signal) != set(attempts):
        missing = sorted(set(attempts) - set(by_signal))
        raise SchemaValidationError(f"Signals without execution observation: {missing}")
    for signal_id, check_rows in by_signal.items():
        ordered = sorted(check_rows, key=lambda row: int(row["check_sequence"]))
        sequences = [int(row["check_sequence"]) for row in ordered]
        if sequences != list(range(1, len(sequences) + 1)):
            raise SchemaValidationError(f"Signal {signal_id} has duplicate or non-contiguous checks")
        observed = [row for row in ordered if row["check_phase"] == "ATTEMPT_OBSERVED"]
        if len(observed) != 1:
            raise SchemaValidationError(f"Signal {signal_id} requires exactly one ATTEMPT_OBSERVED")
        attempt = attempts[signal_id]
        pre_send = [row for row in ordered if row["check_phase"] == "PRE_SEND"]
        send_result = [row for row in ordered if row["check_phase"] == "SEND_RESULT"]
        if _as_bool(attempt, "send_attempted", f"attempt {signal_id}"):
            if len(pre_send) != 1 or len(send_result) != 1:
                raise SchemaValidationError(
                    f"Signal {signal_id} send requires one PRE_SEND and one SEND_RESULT"
                )
            if not _as_bool(pre_send[0], "order_check_performed", f"check {signal_id}"):
                raise SchemaValidationError(f"Signal {signal_id} PRE_SEND omitted OrderCheck")
            if int(pre_send[0]["check_sequence"]) >= int(send_result[0]["check_sequence"]):
                raise SchemaValidationError(f"Signal {signal_id} SEND_RESULT precedes PRE_SEND")
            if attempt["attempt_status"] == "SENT" and not _as_bool(
                send_result[0], "allowed", f"check {signal_id}"
            ):
                raise SchemaValidationError(f"Signal {signal_id} SENT status has rejected send result")
        elif send_result:
            raise SchemaValidationError(f"Signal {signal_id} has SEND_RESULT without send_attempted")
    return by_signal


def _entry_evidence(check_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in check_rows if row["broker_entry_confirmed"] == "1"]


def _validate_trailing(
    rows: list[dict[str, str]],
    attempts: dict[str, dict[str, str]],
    checks: dict[str, list[dict[str, str]]],
) -> dict[str, list[dict[str, str]]]:
    by_signal: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row_index, row in enumerate(rows, start=2):
        context = f"{TRAILING_EVENTS_FILE}:{row_index}"
        attempt = attempts.get(row["signal_id"])
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan trailing event")
        for column in ("window_id", "symbol", "direction"):
            if row[column] != attempt[column]:
                raise SchemaValidationError(f"{context}: trailing/attempt mismatch for {column}")
        event_time, _, _ = _validate_time_triplet(
            row,
            "event_broker_time",
            "event_analysis_time",
            "event_offset_minutes",
            context,
        )
        trigger_time = _as_time(attempt, "trigger_broker_time", context)
        assert event_time is not None and trigger_time is not None
        if event_time < trigger_time:
            raise SchemaValidationError(f"{context}: trailing event precedes trigger")
        position_ticket = _as_int(row, "position_ticket", context)
        position_identifier = _as_int(row, "position_identifier", context)
        if position_ticket is None or position_ticket <= 0 or position_identifier is None or position_identifier <= 0:
            raise SchemaValidationError(f"{context}: trailing event lacks broker ownership")
        evidence = _entry_evidence(checks[row["signal_id"]])
        if not any(
            entry["position_ticket"] == row["position_ticket"]
            and entry["position_identifier"] == row["position_identifier"]
            for entry in evidence
        ):
            raise SchemaValidationError(f"{context}: trailing event has no matching fill evidence")
        _as_float(row, "milestone_price", context)
        _as_float(row, "take_profit", context)
        request_performed = _as_bool(row, "request_performed", context)
        request_succeeded = _as_bool(row, "request_succeeded", context)
        _as_bool(row, "retry_pending", context)
        if request_succeeded and not request_performed:
            raise SchemaValidationError(f"{context}: succeeded trailing request was not performed")
        if request_succeeded and _as_float(row, "confirmed_stop", context, nullable=True) is None:
            raise SchemaValidationError(f"{context}: succeeded trailing request lacks confirmed stop")
        by_signal[row["signal_id"]].append(row)

    for signal_id, event_rows in by_signal.items():
        ordered = sorted(event_rows, key=lambda row: int(row["event_sequence"]))
        sequences = [_as_int(row, "event_sequence", f"trailing {signal_id}") for row in ordered]
        if sequences != list(range(1, len(sequences) + 1)):
            raise SchemaValidationError(f"Signal {signal_id} has duplicate or non-contiguous trailing events")
        direction = attempts[signal_id]["direction"]
        desired_stops = [
            _as_float(row, "desired_stop", f"trailing {signal_id}", nullable=True)
            for row in ordered
        ]
        desired_stops = [value for value in desired_stops if value is not None]
        if direction == "BUY" and any(
            left > right for left, right in zip(desired_stops, desired_stops[1:])
        ):
            raise SchemaValidationError(f"Signal {signal_id} BUY trailing protection widened")
        if direction == "SELL" and any(
            left < right for left, right in zip(desired_stops, desired_stops[1:])
        ):
            raise SchemaValidationError(f"Signal {signal_id} SELL trailing protection widened")
    return by_signal


def _validate_outcomes(
    rows: list[dict[str, str]],
    attempts: dict[str, dict[str, str]],
    checks: dict[str, list[dict[str, str]]],
    trailing: dict[str, list[dict[str, str]]],
) -> dict[str, dict[str, str]]:
    outcomes: dict[str, dict[str, str]] = {}
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_OUTCOMES_FILE}:{row_index}"
        signal_id = row["signal_id"]
        attempt = attempts.get(signal_id)
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan signal outcome")
        if signal_id in outcomes:
            raise SchemaValidationError(f"Duplicate broker outcome for signal {signal_id}")
        for column in (
            "window_id",
            "symbol",
            "pivot_timeframe",
            "active_bar_open_broker_time",
            "level_id",
            "direction",
        ):
            if row[column] != attempt[column]:
                raise SchemaValidationError(f"{context}: outcome/attempt mismatch for {column}")
        entry_time, _, _ = _validate_time_triplet(
            row,
            "entry_broker_time",
            "entry_analysis_time",
            "entry_offset_minutes",
            context,
        )
        close_time, _, _ = _validate_time_triplet(
            row,
            "close_broker_time",
            "close_analysis_time",
            "close_offset_minutes",
            context,
        )
        trigger_time = _as_time(attempt, "trigger_broker_time", context)
        assert entry_time is not None and close_time is not None and trigger_time is not None
        if not trigger_time <= entry_time <= close_time:
            raise SchemaValidationError(f"{context}: broker outcome is not causal")
        duration = _as_int(row, "duration_seconds", context)
        if duration != int((close_time - entry_time).total_seconds()):
            raise SchemaValidationError(f"{context}: duration_seconds does not match broker times")
        if not _as_bool(row, "broker_entry_confirmed", context) or not _as_bool(
            row, "broker_close_confirmed", context
        ):
            raise SchemaValidationError(f"{context}: outcome is not broker-confirmed")
        required_tickets = (
            "order_ticket",
            "entry_deal_ticket",
            "close_deal_ticket",
            "position_ticket",
            "position_identifier",
        )
        for column in required_tickets:
            value = _as_int(row, column, context)
            if value is None or value <= 0:
                raise SchemaValidationError(f"{context}: invalid broker ticket {column}")
        for column in ("broker_entry_price", "broker_volume", "close_price", "closed_volume"):
            value = _as_float(row, column, context)
            if value is None or value <= 0.0:
                raise SchemaValidationError(f"{context}: invalid broker value {column}")
        _as_float(row, "realized_profit", context)
        _require_value(row, "terminal_reason", context)
        evidence = _entry_evidence(checks[signal_id])
        if not any(
            entry["position_ticket"] == row["position_ticket"]
            and entry["position_identifier"] == row["position_identifier"]
            for entry in evidence
        ):
            raise SchemaValidationError(f"{context}: outcome exists without matching fill evidence")
        initial_stop = _as_float(row, "initial_stop_loss", context)
        terminal_take_profit = _as_float(row, "terminal_take_profit", context)
        attempt_stop = _as_float(attempt, "initial_stop_loss", context)
        attempt_take_profit = _as_float(attempt, "terminal_take_profit", context)
        assert initial_stop is not None and terminal_take_profit is not None
        assert attempt_stop is not None and attempt_take_profit is not None
        if not _same_number(initial_stop, attempt_stop) or not _same_number(
            terminal_take_profit, attempt_take_profit
        ):
            raise SchemaValidationError(f"{context}: outcome changed captured route geometry")
        for event in trailing.get(signal_id, []):
            event_time = _as_time(event, "event_broker_time", context)
            if event_time is not None and event_time > close_time:
                raise SchemaValidationError(f"{context}: trailing event occurs after broker close")
        outcomes[signal_id] = row
    return outcomes


def _validate_summary(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    actual_counts: dict[str, int],
) -> tuple[str, ...]:
    if len(rows) != 1:
        raise SchemaValidationError("run_summary.tsv must contain exactly one row")
    row = rows[0]
    context = RUN_SUMMARY_FILE
    started, _, _ = _validate_time_triplet(
        row,
        "started_broker_time",
        "started_analysis_time",
        "started_offset_minutes",
        context,
    )
    finished, _, _ = _validate_time_triplet(
        row,
        "finished_broker_time",
        "finished_analysis_time",
        "finished_offset_minutes",
        context,
    )
    assert started is not None and finished is not None
    if finished < started:
        raise SchemaValidationError("run_summary.tsv finished before it started")
    manifest_started = datetime.strptime(manifest["started_broker_time"], "%Y.%m.%d %H:%M:%S")
    if started != manifest_started:
        raise SchemaValidationError("run summary started_broker_time differs from manifest")
    count_columns = {
        "pivot_window_rows": PIVOT_WINDOWS_FILE,
        "pivot_level_rows": PIVOT_LEVELS_FILE,
        "signal_attempt_rows": SIGNAL_ATTEMPTS_FILE,
        "signal_feature_rows": SIGNAL_FEATURES_FILE,
        "execution_check_rows": EXECUTION_CHECKS_FILE,
        "trailing_event_rows": TRAILING_EVENTS_FILE,
        "signal_outcome_rows": SIGNAL_OUTCOMES_FILE,
    }
    for column, filename in count_columns.items():
        if _as_int(row, column, context) != actual_counts[filename]:
            raise SchemaValidationError(f"run summary count mismatch for {filename}")
    for column in (
        "feature_incomplete_rows",
        "duplicate_identity_count",
        "referential_integrity_error_count",
        "row_integrity_error_count",
    ):
        if _as_int(row, column, context) != 0:
            raise SchemaValidationError(f"run summary reports integrity failure: {column}")
    if row["export_status"] != "OK":
        raise SchemaValidationError(f"run summary export_status is not OK: {row['export_status']}")
    if row["completion_status"] not in ("NATURAL", "CENSORED"):
        raise SchemaValidationError(
            f"run summary has invalid completion_status: {row['completion_status']}"
        )
    return ("run completion is CENSORED",) if row["completion_status"] == "CENSORED" else ()


def validate_run(
    runs_root: Path,
    run_id: str,
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> RunValidation:
    _require_active_schema(schema_version)
    run_path = _resolve_run_path(Path(runs_root), run_id)
    tables = {
        filename: _read_tsv(run_path / filename, expected_columns_for(filename, schema_version))
        for filename in RUN_FILES
    }
    manifest = _validate_manifest(tables[RUN_MANIFEST_FILE], run_id)
    config_id = manifest["config_id"]
    for filename in RUN_FILES[1:]:
        _validate_common_rows(tables[filename], filename, run_id, config_id)

    windows = _validate_windows(tables[PIVOT_WINDOWS_FILE], manifest["symbol"])
    levels = _validate_levels(tables[PIVOT_LEVELS_FILE], windows)
    attempts = _validate_attempts(tables[SIGNAL_ATTEMPTS_FILE], windows, levels)
    _validate_features(tables[SIGNAL_FEATURES_FILE], attempts)
    checks = _validate_checks(tables[EXECUTION_CHECKS_FILE], attempts)
    trailing = _validate_trailing(tables[TRAILING_EVENTS_FILE], attempts, checks)
    _validate_outcomes(tables[SIGNAL_OUTCOMES_FILE], attempts, checks, trailing)
    row_counts = {filename: len(rows) for filename, rows in tables.items()}
    warnings = _validate_summary(tables[RUN_SUMMARY_FILE], manifest, row_counts)
    return RunValidation(
        run_id=run_id,
        config_id=config_id,
        run_path=run_path,
        manifest=manifest,
        row_counts=row_counts,
        warnings=warnings,
    )


def validate_runs(
    runs_root: Path,
    run_ids: Iterable[str],
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> list[RunValidation]:
    selected = list(run_ids)
    if not selected:
        raise SchemaValidationError("At least one run ID is required")
    if len(set(selected)) != len(selected):
        raise SchemaValidationError("Duplicate run_id selection")
    return [
        validate_run(runs_root, run_id, schema_version=schema_version)
        for run_id in selected
    ]
