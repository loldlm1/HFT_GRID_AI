"""Strict schema V10 contract for the macro/micro pivot-band exporter."""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


SUPPORTED_SCHEMA_VERSION = 10
SUPPORTED_ENGINE_LABEL = "PIVOT_FRACTAL_V2"
SUPPORTED_FEATURE_SET_ID = "schema_v10_macro_micro_pivot_bands"
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
PIVOT_WINDOWS_FILE = "pivot_windows.tsv"
SIGNAL_ATTEMPTS_FILE = "signal_attempts.tsv"
EXECUTION_CHECKS_FILE = "execution_checks.tsv"
SIGNAL_OUTCOMES_FILE = "signal_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"

RUN_FILES = (
    RUN_MANIFEST_FILE,
    PIVOT_WINDOWS_FILE,
    SIGNAL_ATTEMPTS_FILE,
    EXECUTION_CHECKS_FILE,
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
    "macro_timeframe",
    "micro_timeframe",
    "active_bar_open_broker_time",
    "active_bar_open_analysis_time",
    "active_bar_open_offset_minutes",
    "source_bar_open_broker_time",
    "source_bar_open_analysis_time",
    "source_bar_open_offset_minutes",
    "source_close_boundary_broker_time",
    "source_close_boundary_analysis_time",
    "source_close_boundary_offset_minutes",
    "source_open",
    "source_high",
    "source_low",
    "source_close",
    "source_range",
    "raw_s3_price",
    "raw_s2_price",
    "raw_s1_price",
    "raw_pp_price",
    "raw_r1_price",
    "raw_r2_price",
    "raw_r3_price",
    "trade_s3_price",
    "trade_s2_price",
    "trade_s1_price",
    "trade_pp_price",
    "trade_r1_price",
    "trade_r2_price",
    "trade_r3_price",
    "first_observed_broker_time",
    "first_observed_analysis_time",
    "first_observed_offset_minutes",
    "first_observed_bid",
    "pp_initial_relation",
    "pp_role",
    "pp_arm_broker_time",
    "pp_arm_analysis_time",
    "pp_arm_offset_minutes",
    "pp_arm_bid",
    "macro_band_base_1",
    "macro_band_upper_1",
    "macro_band_lower_1",
    "macro_band_width_1",
    "macro_band_width_percent_1",
    "macro_band_complete",
    "macro_band_invalid_reason",
    "window_state",
    "invalid_reason",
    "terminal_broker_time",
    "terminal_analysis_time",
    "terminal_offset_minutes",
    "terminal_status",
)

SIGNAL_ATTEMPT_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "macro_timeframe",
    "micro_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "trigger_broker_time",
    "trigger_analysis_time",
    "trigger_offset_minutes",
    "trigger_bid",
    "trigger_ask",
    "spread_points",
    "point_size",
    "pivot_raw_price",
    "pivot_trade_price",
    "structural_sl_price",
    "observed_entry_price",
    "observed_stop_loss",
    "observed_take_profit",
    "observed_risk_distance_points",
    "observed_reward_distance_points",
    "request_broker_time",
    "request_analysis_time",
    "request_offset_minutes",
    "request_bid",
    "request_ask",
    "request_entry_price",
    "request_stop_loss",
    "request_take_profit",
    "request_risk_distance_points",
    "request_reward_distance_points",
    "request_price_reward_risk_ratio",
    "lot_mode",
    "lot_strategy_size",
    "reference_balance",
    "account_currency",
    "risk_budget_amount",
    "requested_volume",
    "normalized_volume",
    "quote_expected_stop_loss",
    "quote_expected_take_profit",
    "quote_expected_reward_risk_ratio",
    "risk_budget_utilization_ratio",
    "micro_band_base_0",
    "micro_band_upper_0",
    "micro_band_lower_0",
    "micro_band_width_0",
    "micro_band_width_percent_0",
    "micro_b_percent_0",
    "micro_b_percent_1",
    "micro_b_percent_2",
    "micro_b_percent_3",
    "micro_b_percent_4",
    "micro_b_percent_5",
    "macro_pivot_b_percent_0",
    "macro_pivot_b_percent_1",
    "macro_pivot_b_percent_2",
    "macro_pivot_b_percent_3",
    "macro_pivot_b_percent_4",
    "macro_pivot_b_percent_5",
    "micro_features_complete",
    "macro_features_complete",
    "feature_snapshot_complete",
    "feature_invalid_reason",
    "identity_consumed",
    "route_status",
    "attempt_status",
    "block_source",
    "block_reason",
    "send_attempted",
    "send_succeeded",
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
    "entry_price",
    "stop_loss_price",
    "take_profit_price",
    "risk_distance_points",
    "reward_distance_points",
    "risk_budget_amount",
    "requested_volume",
    "normalized_volume",
    "volume_min",
    "volume_max",
    "volume_step",
    "volume_valid",
    "quote_expected_stop_loss",
    "quote_expected_take_profit",
    "quote_expected_reward_risk_ratio",
    "risk_budget_utilization_ratio",
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
    "send_performed",
    "send_succeeded",
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
    "terminal_reason",
)

SIGNAL_OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "macro_timeframe",
    "micro_timeframe",
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
    "last_close_deal_ticket",
    "close_deal_count",
    "position_ticket",
    "position_identifier",
    "submitted_request_price",
    "broker_entry_price",
    "broker_volume",
    "immutable_stop_loss",
    "immutable_take_profit",
    "close_price",
    "closed_volume",
    "request_risk_distance_points",
    "request_reward_distance_points",
    "request_price_reward_risk_ratio",
    "risk_budget_amount",
    "quote_expected_stop_loss",
    "quote_expected_take_profit",
    "quote_expected_reward_risk_ratio",
    "risk_budget_utilization_ratio",
    "entry_slippage_points",
    "exit_slippage_points",
    "gross_profit",
    "commission",
    "swap",
    "fee",
    "net_profit",
    "gross_budget_r",
    "net_budget_r",
    "gross_execution_r",
    "net_execution_r",
    "terminal_reason",
    "close_reason_consistent",
    "binary_eligible",
    "binary_target",
    "exclusion_reason",
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
    "signal_attempt_rows",
    "execution_check_rows",
    "signal_outcome_rows",
    "feature_complete_rows",
    "feature_incomplete_rows",
    "send_attempt_rows",
    "send_succeeded_rows",
    "broker_filled_rows",
    "broker_closed_rows",
    "binary_eligible_rows",
    "binary_tp_rows",
    "binary_sl_rows",
    "excluded_outcome_rows",
    "excluded_feature_incomplete_rows",
    "excluded_mixed_rows",
    "excluded_manual_rows",
    "excluded_stop_out_rows",
    "excluded_expert_rows",
    "excluded_other_rows",
    "censored_attempt_rows",
    "duplicate_identity_count",
    "referential_integrity_error_count",
    "row_integrity_error_count",
    "export_status",
    "completion_status",
)

TABLE_COLUMNS = {
    RUN_MANIFEST_FILE: MANIFEST_COLUMNS,
    PIVOT_WINDOWS_FILE: PIVOT_WINDOW_COLUMNS,
    SIGNAL_ATTEMPTS_FILE: SIGNAL_ATTEMPT_COLUMNS,
    EXECUTION_CHECKS_FILE: EXECUTION_CHECK_COLUMNS,
    SIGNAL_OUTCOMES_FILE: SIGNAL_OUTCOME_COLUMNS,
    RUN_SUMMARY_FILE: SUMMARY_COLUMNS,
}

PIVOT_LEVELS = ("S3", "S2", "S1", "PP", "R1", "R2", "R3")
SUPPORT_LEVELS = ("S1", "S2", "S3")
RESISTANCE_LEVELS = ("R1", "R2", "R3")
BAND_SHIFTS = tuple(range(6))
REFERENCE_LOT_MODE = "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT"
FIXED_LOT_MODE = "EXECUTION_LOT_FIXED_SIZE"
REFERENCE_BALANCE = 1_000_000.0

TIMEFRAME_SECONDS = {
    "PERIOD_M1": 60,
    "PERIOD_M2": 120,
    "PERIOD_M3": 180,
    "PERIOD_M4": 240,
    "PERIOD_M5": 300,
    "PERIOD_M6": 360,
    "PERIOD_M10": 600,
    "PERIOD_M12": 720,
    "PERIOD_M15": 900,
    "PERIOD_M20": 1200,
    "PERIOD_M30": 1800,
    "PERIOD_H1": 3600,
    "PERIOD_H2": 7200,
    "PERIOD_H3": 10800,
    "PERIOD_H4": 14400,
    "PERIOD_H6": 21600,
    "PERIOD_H8": 28800,
    "PERIOD_H12": 43200,
    "PERIOD_D1": 86400,
    "PERIOD_W1": 604800,
    "PERIOD_MN1": 2592000,
}

CATEGORICAL_COLUMNS = (
    "symbol",
    "level_id",
    "direction",
    "analysis_weekday",
    "analysis_session",
)
NUMERIC_FEATURE_COLUMNS = (
    "micro_band_width_percent_0",
    "macro_band_width_percent_1",
    *(f"micro_b_percent_{shift}" for shift in BAND_SHIFTS),
    *(f"macro_pivot_b_percent_{shift}" for shift in BAND_SHIFTS),
    "trigger_gap_to_risk",
    "spread_to_risk",
    "macro_range_to_band_width",
    "time_sin",
    "time_cos",
)
MODEL_FEATURE_COLUMNS = CATEGORICAL_COLUMNS + NUMERIC_FEATURE_COLUMNS
FEATURE_SET_COLUMNS = {SUPPORTED_FEATURE_SET_ID: MODEL_FEATURE_COLUMNS}

IDENTITY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "window_id",
    "symbol",
    "macro_timeframe",
    "micro_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "trigger_broker_time",
)
TARGET_COLUMNS = (
    "binary_target",
    "terminal_reason",
    "gross_profit",
    "net_profit",
    "gross_budget_r",
    "net_budget_r",
    "gross_execution_r",
    "net_execution_r",
)
AUDIT_COLUMNS = (
    "trigger_analysis_time",
    "trigger_bid",
    "trigger_ask",
    "pivot_trade_price",
    "structural_sl_price",
    "request_entry_price",
    "request_take_profit",
    "risk_budget_amount",
    "normalized_volume",
    "entry_slippage_points",
    "exit_slippage_points",
    "exclusion_reason",
)
FUTURE_ONLY_COLUMNS = (
    "route_status",
    "attempt_status",
    "block_source",
    "block_reason",
    "send_attempted",
    "send_succeeded",
    "request_broker_time",
    "request_entry_price",
    "request_take_profit",
    "normalized_volume",
    "quote_expected_stop_loss",
    "quote_expected_take_profit",
    "broker_entry_price",
    "close_broker_time",
    "close_price",
    "entry_slippage_points",
    "exit_slippage_points",
    "gross_profit",
    "net_profit",
    "terminal_reason",
    "binary_target",
    "duration_seconds",
)

DATASET_CONFIG_KEYS = (
    "config_id",
    "engine_label",
    "macro_timeframe",
    "micro_timeframe",
    "bands_period",
    "bands_deviation",
    "bands_ma_method",
    "bands_applied_price",
    "lot_mode",
    "lot_strategy_size",
    "reference_balance",
    "account_currency",
    "feature_set_id",
)

REQUIRED_MANIFEST_KEYS = {
    "run_id",
    "config_id",
    "started_broker_time",
    "symbol",
    "chart_period",
    "engine_id",
    "engine_label",
    "macro_timeframe",
    "micro_timeframe",
    "pivot_formula",
    "source_policy",
    "identity_policy",
    "trigger_policy",
    "pp_policy",
    "execution_price_policy",
    "route_policy",
    "bands_period",
    "bands_deviation",
    "bands_shift",
    "bands_ma_method",
    "bands_applied_price",
    "lot_mode",
    "lot_strategy_size",
    "reference_balance",
    "account_currency",
    "volume_normalization_policy",
    "outcome_policy",
    "binary_cohort_policy",
    "time_policy",
    "broker_session",
    "feature_set_id",
    "research_approval_state",
}
FIXED_MANIFEST_VALUES = {
    "engine_id": "2",
    "engine_label": SUPPORTED_ENGINE_LABEL,
    "pivot_formula": "CLASSIC_PP_S1_S3_R1_R3",
    "source_policy": "macro_immediately_previous_completed_broker_candle_shift_1",
    "identity_policy": "symbol,macro_timeframe,active_bar_open,level_first_trigger_once",
    "trigger_policy": "live_bid_virtual_limit_support_buy_resistance_sell",
    "pp_policy": "first_causal_bid_side_then_return_touch",
    "execution_price_policy": "trigger_bid_buy_fresh_ask_sell_fresh_bid_market_deal",
    "route_policy": "structural_sl_fresh_quote_price_distance_1r_no_modifications",
    "bands_period": "21",
    "bands_deviation": "2.0000",
    "bands_shift": "0",
    "bands_ma_method": "MODE_SMA",
    "bands_applied_price": "PRICE_WEIGHTED",
    "reference_balance": "1000000.00000000",
    "volume_normalization_policy": "normalize_down_block_below_minimum",
    "outcome_policy": "broker_costs_and_execution_slippage_decomposed",
    "binary_cohort_policy": "feature_complete_consistent_broker_tp_or_sl_only",
    "time_policy": "broker_time_causal_analysis_time_export_only",
    "feature_set_id": SUPPORTED_FEATURE_SET_ID,
    "research_approval_state": "OFFLINE_RESEARCH_ONLY",
}


class SchemaValidationError(RuntimeError):
    """Raised when a run violates the strict V10 export contract."""


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
    def signal_attempt_rows(self) -> int:
        return self.row_counts[SIGNAL_ATTEMPTS_FILE]

    @property
    def execution_check_rows(self) -> int:
        return self.row_counts[EXECUTION_CHECKS_FILE]

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
        raise ValueError(f"Unknown schema V10 file: {filename}") from exc


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


def _as_int(
    row: dict[str, str],
    column: str,
    context: str,
    *,
    nullable: bool = False,
) -> int | None:
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


def _as_time(
    row: dict[str, str],
    column: str,
    context: str,
    *,
    nullable: bool = False,
) -> datetime | None:
    value = row.get(column)
    if _is_null(value):
        if nullable:
            return None
        raise SchemaValidationError(f"{context}: required timestamp is null: {column}")
    try:
        return datetime.strptime(str(value), "%Y.%m.%d %H:%M:%S")
    except ValueError as exc:
        raise SchemaValidationError(f"{context}: invalid timestamp {column}={value}") from exc


def _same_number(left: float, right: float, tolerance: float = 1e-7) -> bool:
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
        raise SchemaValidationError(f"Missing required schema V10 file: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        header = handle.readline().rstrip("\r\n").split("\t")
        if tuple(header) != expected_columns:
            raise SchemaValidationError(
                f"Header mismatch for {path.name}: expected {len(expected_columns)} exact columns, "
                f"received {len(header)}"
            )
        rows = list(csv.DictReader(handle, fieldnames=header, delimiter="\t"))
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
    actual_files = {path.name for path in run_path.glob("*.tsv")}
    expected_files = set(RUN_FILES)
    if actual_files != expected_files:
        missing = sorted(expected_files - actual_files)
        unexpected = sorted(actual_files - expected_files)
        raise SchemaValidationError(
            f"Run must contain exactly six V10 TSV files; missing={missing}, unexpected={unexpected}"
        )
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
    missing = sorted(REQUIRED_MANIFEST_KEYS - manifest.keys())
    extra = sorted(manifest.keys() - REQUIRED_MANIFEST_KEYS)
    if missing or extra:
        raise SchemaValidationError(f"Manifest key mismatch: missing={missing}, unexpected={extra}")
    if manifest["run_id"] != requested_run_id:
        raise SchemaValidationError("Manifest run_id does not match requested run")
    for key, expected in FIXED_MANIFEST_VALUES.items():
        if manifest[key] != expected:
            raise SchemaValidationError(
                f"Manifest fixed value mismatch: {key}={manifest[key]!r}, expected {expected!r}"
            )
    macro = manifest["macro_timeframe"]
    micro = manifest["micro_timeframe"]
    if macro not in TIMEFRAME_SECONDS or micro not in TIMEFRAME_SECONDS:
        raise SchemaValidationError("Manifest contains unsupported Macro/Micro timeframe")
    if TIMEFRAME_SECONDS[micro] >= TIMEFRAME_SECONDS[macro]:
        raise SchemaValidationError("Manifest requires Micro timeframe shorter than Macro timeframe")
    lot_mode = manifest["lot_mode"]
    if lot_mode not in (REFERENCE_LOT_MODE, FIXED_LOT_MODE):
        raise SchemaValidationError(f"Manifest has unsupported lot mode: {lot_mode}")
    try:
        lot_size = float(manifest["lot_strategy_size"])
    except ValueError as exc:
        raise SchemaValidationError("Manifest lot_strategy_size must be numeric") from exc
    if not math.isfinite(lot_size) or lot_size <= 0.0:
        raise SchemaValidationError("Manifest lot_strategy_size must be positive")
    if lot_mode == REFERENCE_LOT_MODE and not 0.0 < lot_size <= 100.0:
        raise SchemaValidationError("Manifest reference-balance percentage is out of range")
    try:
        datetime.strptime(manifest["started_broker_time"], "%Y.%m.%d %H:%M:%S")
    except ValueError as exc:
        raise SchemaValidationError("Manifest started_broker_time is invalid") from exc
    return manifest


def _validate_common_row(
    row: dict[str, str],
    context: str,
    manifest: dict[str, str],
) -> None:
    if _as_int(row, "schema_version", context) != SUPPORTED_SCHEMA_VERSION:
        raise SchemaValidationError(f"{context}: unsupported row schema version")
    if row["run_id"] != manifest["run_id"] or row["config_id"] != manifest["config_id"]:
        raise SchemaValidationError(f"{context}: run/config identity mismatch")


def _level_column(prefix: str, level_id: str) -> str:
    return f"{prefix}_{level_id.lower()}_price"


def _validate_band_width(
    row: dict[str, str],
    base_column: str,
    upper_column: str,
    lower_column: str,
    width_column: str,
    percent_column: str,
    context: str,
) -> None:
    base = _as_float(row, base_column, context)
    upper = _as_float(row, upper_column, context)
    lower = _as_float(row, lower_column, context)
    width = _as_float(row, width_column, context)
    width_percent = _as_float(row, percent_column, context)
    assert None not in (base, upper, lower, width, width_percent)
    if upper <= lower or base <= 0.0 or not lower <= base <= upper:
        raise SchemaValidationError(f"{context}: invalid band envelope")
    if not _same_number(width, upper - lower):
        raise SchemaValidationError(f"{context}: band width arithmetic mismatch")
    if not _same_number(width_percent, 100.0 * width / base):
        raise SchemaValidationError(f"{context}: normalized band width mismatch")


def _validate_windows(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
) -> dict[str, dict[str, str]]:
    windows: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str]] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{PIVOT_WINDOWS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        window_id = _require_value(row, "window_id", context)
        if window_id in windows:
            raise SchemaValidationError(f"Duplicate window_id: {window_id}")
        if row["symbol"] != manifest["symbol"]:
            raise SchemaValidationError(f"{context}: symbol differs from manifest")
        if row["macro_timeframe"] != manifest["macro_timeframe"]:
            raise SchemaValidationError(f"{context}: Macro timeframe differs from manifest")
        if row["micro_timeframe"] != manifest["micro_timeframe"]:
            raise SchemaValidationError(f"{context}: Micro timeframe differs from manifest")
        active, _, _ = _validate_time_triplet(
            row,
            "active_bar_open_broker_time",
            "active_bar_open_analysis_time",
            "active_bar_open_offset_minutes",
            context,
        )
        source_open, _, _ = _validate_time_triplet(
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
        terminal, _, _ = _validate_time_triplet(
            row,
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_offset_minutes",
            context,
        )
        assert active is not None and source_open is not None and source_close is not None
        assert terminal is not None
        if not source_open < source_close == active < terminal:
            raise SchemaValidationError(f"{context}: Macro source/window times are not causal")
        identity = (row["symbol"], row["macro_timeframe"], row["active_bar_open_broker_time"])
        if identity in identities:
            raise SchemaValidationError(f"{context}: duplicate Macro window identity")
        identities.add(identity)

        source_open_price = _as_float(row, "source_open", context)
        high = _as_float(row, "source_high", context)
        low = _as_float(row, "source_low", context)
        close = _as_float(row, "source_close", context)
        source_range = _as_float(row, "source_range", context)
        assert None not in (source_open_price, high, low, close, source_range)
        if high <= low or not low <= source_open_price <= high or not low <= close <= high:
            raise SchemaValidationError(f"{context}: invalid Macro source OHLC")
        if not _same_number(source_range, high - low):
            raise SchemaValidationError(f"{context}: source_range mismatch")
        pp = (high + low + close) / 3.0
        expected_raw = {
            "PP": pp,
            "S1": 2.0 * pp - high,
            "S2": pp - source_range,
            "S3": low - 2.0 * (high - pp),
            "R1": 2.0 * pp - low,
            "R2": pp + source_range,
            "R3": high + 2.0 * (pp - low),
        }
        for level_id, expected in expected_raw.items():
            actual = _as_float(row, _level_column("raw", level_id), context)
            assert actual is not None
            if not _same_number(actual, expected):
                raise SchemaValidationError(f"{context}: classic pivot formula mismatch for {level_id}")
        trade_prices = [
            _as_float(row, _level_column("trade", level_id), context)
            for level_id in PIVOT_LEVELS
        ]
        if any(value is None for value in trade_prices) or any(
            left >= right for left, right in zip(trade_prices, trade_prices[1:])
        ):
            raise SchemaValidationError(f"{context}: collapsed or unordered trade pivot ladder")

        first_time, _, _ = _validate_time_triplet(
            row,
            "first_observed_broker_time",
            "first_observed_analysis_time",
            "first_observed_offset_minutes",
            context,
        )
        first_bid = _as_float(row, "first_observed_bid", context)
        trade_pp = _as_float(row, "trade_pp_price", context)
        assert first_time is not None and first_bid is not None and trade_pp is not None
        if first_bid <= 0.0 or not active <= first_time < terminal:
            raise SchemaValidationError(f"{context}: first observed tick is outside the Macro window")
        relation = row["pp_initial_relation"]
        expected_relation = "ABOVE" if first_bid > trade_pp else "BELOW" if first_bid < trade_pp else "EQUAL"
        if relation != expected_relation:
            raise SchemaValidationError(f"{context}: PP initial relation mismatch")
        role = row["pp_role"]
        if role not in ("BUY", "SELL", "UNARMED"):
            raise SchemaValidationError(f"{context}: invalid PP role")
        arm_time, _, _ = _validate_time_triplet(
            row,
            "pp_arm_broker_time",
            "pp_arm_analysis_time",
            "pp_arm_offset_minutes",
            context,
            nullable=True,
        )
        arm_bid = _as_float(row, "pp_arm_bid", context, nullable=True)
        if role == "UNARMED":
            if arm_time is not None or arm_bid is not None:
                raise SchemaValidationError(f"{context}: unarmed PP has arm facts")
            if relation != "EQUAL":
                raise SchemaValidationError(f"{context}: PP remained unarmed after a strict initial side")
        else:
            if arm_time is None or arm_bid is None or not first_time <= arm_time < terminal:
                raise SchemaValidationError(f"{context}: armed PP lacks causal arm facts")
            if role == "BUY" and arm_bid <= trade_pp:
                raise SchemaValidationError(f"{context}: BUY PP must arm from above")
            if role == "SELL" and arm_bid >= trade_pp:
                raise SchemaValidationError(f"{context}: SELL PP must arm from below")
            if relation == "ABOVE" and role != "BUY":
                raise SchemaValidationError(f"{context}: PP role contradicts initial side")
            if relation == "BELOW" and role != "SELL":
                raise SchemaValidationError(f"{context}: PP role contradicts initial side")
            if relation in ("ABOVE", "BELOW") and (
                arm_time != first_time or not _same_number(arm_bid, first_bid)
            ):
                raise SchemaValidationError(
                    f"{context}: PP strict initial side did not arm on the first causal tick"
                )

        macro_complete = _as_bool(row, "macro_band_complete", context)
        if macro_complete:
            _validate_band_width(
                row,
                "macro_band_base_1",
                "macro_band_upper_1",
                "macro_band_lower_1",
                "macro_band_width_1",
                "macro_band_width_percent_1",
                context,
            )
            if not _is_null(row["macro_band_invalid_reason"]):
                raise SchemaValidationError(f"{context}: complete Macro bands have invalid reason")
        else:
            if _is_null(row["macro_band_invalid_reason"]):
                raise SchemaValidationError(f"{context}: incomplete Macro bands lack invalid reason")
        if row["window_state"] != "VALID" or not _is_null(row["invalid_reason"]):
            raise SchemaValidationError(f"{context}: fixture/exported window is not valid")
        if row["terminal_status"] not in ("EXPIRED", "RUN_FINISHED"):
            raise SchemaValidationError(f"{context}: invalid window terminal status")
        windows[window_id] = row
    return windows


def _structural_stop(window: dict[str, str], level_id: str, direction: str) -> float:
    price = lambda level: float(window[_level_column("trade", level)])
    if direction == "BUY":
        if level_id == "PP":
            return price("S1")
        if level_id == "S1":
            return price("S2")
        if level_id == "S2":
            return price("S3")
        if level_id == "S3":
            return price("S3") - (price("S2") - price("S3"))
    if direction == "SELL":
        if level_id == "PP":
            return price("R1")
        if level_id == "R1":
            return price("R2")
        if level_id == "R2":
            return price("R3")
        if level_id == "R3":
            return price("R3") + (price("R3") - price("R2"))
    raise SchemaValidationError(f"No structural route for {direction} {level_id}")


def _validate_optional_number_group(
    row: dict[str, str],
    columns: tuple[str, ...],
    context: str,
    *,
    required: bool,
) -> None:
    null_count = sum(_is_null(row[column]) for column in columns)
    if required and null_count:
        raise SchemaValidationError(f"{context}: required request field group is incomplete")
    if not required and null_count not in (0, len(columns)):
        raise SchemaValidationError(f"{context}: optional request field group is partial")
    if null_count == 0:
        for column in columns:
            _as_float(row, column, context)


def _validate_attempts(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    windows: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    attempts: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str, str]] = set()
    request_geometry_columns = (
        "request_bid",
        "request_ask",
        "request_entry_price",
        "request_stop_loss",
        "request_take_profit",
        "request_risk_distance_points",
        "request_reward_distance_points",
        "request_price_reward_risk_ratio",
    )
    request_money_columns = (
        "requested_volume",
        "normalized_volume",
        "quote_expected_stop_loss",
        "quote_expected_take_profit",
        "quote_expected_reward_risk_ratio",
    )
    micro_feature_columns = (
        "micro_band_base_0",
        "micro_band_upper_0",
        "micro_band_lower_0",
        "micro_band_width_0",
        "micro_band_width_percent_0",
        *(f"micro_b_percent_{shift}" for shift in BAND_SHIFTS),
    )
    macro_feature_columns = (
        *(f"macro_pivot_b_percent_{shift}" for shift in BAND_SHIFTS),
    )
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_ATTEMPTS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        signal_id = _require_value(row, "signal_id", context)
        if signal_id in attempts:
            raise SchemaValidationError(f"Duplicate signal_id: {signal_id}")
        window = windows.get(row["window_id"])
        if window is None:
            raise SchemaValidationError(f"{context}: orphan signal attempt")
        for column in (
            "symbol",
            "macro_timeframe",
            "micro_timeframe",
            "active_bar_open_broker_time",
        ):
            if row[column] != window[column]:
                raise SchemaValidationError(f"{context}: attempt/window mismatch for {column}")
        level_id = row["level_id"]
        direction = row["direction"]
        if level_id not in PIVOT_LEVELS:
            raise SchemaValidationError(f"{context}: invalid pivot level")
        if level_id in SUPPORT_LEVELS and direction != "BUY":
            raise SchemaValidationError(f"{context}: support levels are BUY only")
        if level_id in RESISTANCE_LEVELS and direction != "SELL":
            raise SchemaValidationError(f"{context}: resistance levels are SELL only")
        if level_id == "PP" and direction != window["pp_role"]:
            raise SchemaValidationError(f"{context}: PP direction differs from armed role")
        identity = (
            row["symbol"],
            row["macro_timeframe"],
            row["active_bar_open_broker_time"],
            level_id,
        )
        if identity in identities:
            raise SchemaValidationError(f"{context}: duplicate consumed pivot identity")
        identities.add(identity)
        if not _as_bool(row, "identity_consumed", context):
            raise SchemaValidationError(f"{context}: trigger did not consume identity")

        trigger_time, _, _ = _validate_time_triplet(
            row,
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
            context,
        )
        active = _as_time(window, "active_bar_open_broker_time", context)
        terminal = _as_time(window, "terminal_broker_time", context)
        assert trigger_time is not None and active is not None and terminal is not None
        if not active <= trigger_time < terminal:
            raise SchemaValidationError(f"{context}: trigger is outside its Macro window")
        trigger_bid = _as_float(row, "trigger_bid", context)
        trigger_ask = _as_float(row, "trigger_ask", context)
        point_size = _as_float(row, "point_size", context)
        spread_points = _as_float(row, "spread_points", context)
        pivot_raw = _as_float(row, "pivot_raw_price", context)
        pivot_trade = _as_float(row, "pivot_trade_price", context)
        structural_sl = _as_float(row, "structural_sl_price", context)
        assert None not in (
            trigger_bid,
            trigger_ask,
            point_size,
            spread_points,
            pivot_raw,
            pivot_trade,
            structural_sl,
        )
        if point_size <= 0.0 or trigger_bid <= 0.0 or trigger_ask < trigger_bid:
            raise SchemaValidationError(f"{context}: invalid trigger quote")
        if not _same_number(spread_points, (trigger_ask - trigger_bid) / point_size):
            raise SchemaValidationError(f"{context}: spread_points mismatch")
        expected_raw = float(window[_level_column("raw", level_id)])
        expected_trade = float(window[_level_column("trade", level_id)])
        if not _same_number(pivot_raw, expected_raw) or not _same_number(
            pivot_trade, expected_trade
        ):
            raise SchemaValidationError(f"{context}: attempt pivot differs from window")
        if direction == "BUY" and trigger_bid > pivot_trade:
            raise SchemaValidationError(f"{context}: BUY trigger Bid did not reach pivot")
        if direction == "SELL" and trigger_bid < pivot_trade:
            raise SchemaValidationError(f"{context}: SELL trigger Bid did not reach pivot")
        expected_stop = _structural_stop(window, level_id, direction)
        if not _same_number(structural_sl, expected_stop):
            raise SchemaValidationError(f"{context}: structural SL matrix mismatch")

        observed_geometry_columns = (
            "observed_entry_price",
            "observed_stop_loss",
            "observed_take_profit",
            "observed_risk_distance_points",
            "observed_reward_distance_points",
        )
        _validate_optional_number_group(
            row,
            observed_geometry_columns,
            context,
            required=False,
        )
        observed_geometry_present = not _is_null(row[observed_geometry_columns[0]])
        if observed_geometry_present:
            observed_entry = float(row["observed_entry_price"])
            observed_stop = float(row["observed_stop_loss"])
            observed_take = float(row["observed_take_profit"])
            observed_risk = float(row["observed_risk_distance_points"])
            observed_reward = float(row["observed_reward_distance_points"])
            expected_observed_entry = trigger_ask if direction == "BUY" else trigger_bid
            if not _same_number(observed_entry, expected_observed_entry) or not _same_number(
                observed_stop, structural_sl
            ):
                raise SchemaValidationError(f"{context}: observation geometry mismatch")
            calculated_observed_risk = (
                (observed_entry - observed_stop) / point_size
                if direction == "BUY"
                else (observed_stop - observed_entry) / point_size
            )
            calculated_observed_reward = (
                (observed_take - observed_entry) / point_size
                if direction == "BUY"
                else (observed_entry - observed_take) / point_size
            )
            if (
                calculated_observed_risk <= 0.0
                or not _same_number(observed_risk, calculated_observed_risk)
                or not _same_number(observed_reward, calculated_observed_reward)
                or not _same_number(observed_risk, observed_reward)
            ):
                raise SchemaValidationError(f"{context}: invalid observation risk geometry")

        send_attempted = _as_bool(row, "send_attempted", context)
        send_succeeded = _as_bool(row, "send_succeeded", context)
        if send_succeeded and not send_attempted:
            raise SchemaValidationError(f"{context}: send succeeded without an attempt")
        request_time, _, _ = _validate_time_triplet(
            row,
            "request_broker_time",
            "request_analysis_time",
            "request_offset_minutes",
            context,
            nullable=True,
        )
        _validate_optional_number_group(
            row,
            request_geometry_columns,
            context,
            required=send_attempted,
        )
        has_request_geometry = not _is_null(row[request_geometry_columns[0]])
        if has_request_geometry != (request_time is not None):
            raise SchemaValidationError(f"{context}: request time/geometry availability mismatch")
        _validate_optional_number_group(
            row,
            request_money_columns,
            context,
            required=send_attempted,
        )
        has_request_money = not _is_null(row[request_money_columns[0]])
        if has_request_money and not has_request_geometry:
            raise SchemaValidationError(f"{context}: request money exists without geometry")
        if has_request_geometry:
            assert request_time is not None
            if request_time < trigger_time:
                raise SchemaValidationError(f"{context}: request precedes trigger")
            request_bid = float(row["request_bid"])
            request_ask = float(row["request_ask"])
            request_entry = float(row["request_entry_price"])
            request_stop = float(row["request_stop_loss"])
            request_take = float(row["request_take_profit"])
            request_risk = float(row["request_risk_distance_points"])
            request_reward = float(row["request_reward_distance_points"])
            request_ratio = float(row["request_price_reward_risk_ratio"])
            expected_entry = request_ask if direction == "BUY" else request_bid
            if request_ask < request_bid or not _same_number(request_entry, expected_entry):
                raise SchemaValidationError(f"{context}: request-side entry price mismatch")
            if not _same_number(request_stop, structural_sl):
                raise SchemaValidationError(f"{context}: request changed structural SL")
            calculated_risk = (
                (request_entry - request_stop) / point_size
                if direction == "BUY"
                else (request_stop - request_entry) / point_size
            )
            calculated_reward = (
                (request_take - request_entry) / point_size
                if direction == "BUY"
                else (request_entry - request_take) / point_size
            )
            if calculated_risk <= 0.0 or not _same_number(request_risk, calculated_risk):
                raise SchemaValidationError(f"{context}: invalid request risk distance")
            if not _same_number(request_reward, calculated_reward) or not _same_number(
                request_risk, request_reward
            ) or not _same_number(request_ratio, 1.0):
                raise SchemaValidationError(f"{context}: request is not exact price-distance 1R")

        if row["lot_mode"] != manifest["lot_mode"]:
            raise SchemaValidationError(f"{context}: lot mode differs from manifest")
        if row["account_currency"] != manifest["account_currency"]:
            raise SchemaValidationError(f"{context}: account currency differs from manifest")
        lot_size = _as_float(row, "lot_strategy_size", context)
        assert lot_size is not None
        if not _same_number(lot_size, float(manifest["lot_strategy_size"])):
            raise SchemaValidationError(f"{context}: lot size differs from manifest")
        risk_budget = _as_float(row, "risk_budget_amount", context, nullable=True)
        reference_balance = _as_float(row, "reference_balance", context, nullable=True)
        if row["lot_mode"] == REFERENCE_LOT_MODE:
            if reference_balance is None or risk_budget is None:
                raise SchemaValidationError(f"{context}: reference-risk facts are missing")
            expected_budget = REFERENCE_BALANCE * lot_size / 100.0
            if not _same_number(reference_balance, REFERENCE_BALANCE) or not _same_number(
                risk_budget, expected_budget
            ):
                raise SchemaValidationError(f"{context}: fixed reference risk budget mismatch")
        elif reference_balance is not None or risk_budget is not None:
            raise SchemaValidationError(f"{context}: fixed-lot attempt carries reference-risk facts")

        utilization = _as_float(row, "risk_budget_utilization_ratio", context, nullable=True)
        if has_request_money:
            requested_volume = float(row["requested_volume"])
            normalized_volume = float(row["normalized_volume"])
            expected_stop_loss = float(row["quote_expected_stop_loss"])
            expected_take_profit = float(row["quote_expected_take_profit"])
            expected_ratio = float(row["quote_expected_reward_risk_ratio"])
            if requested_volume <= 0.0 or normalized_volume <= 0.0:
                raise SchemaValidationError(f"{context}: invalid request volume")
            if normalized_volume > requested_volume + 1e-8:
                raise SchemaValidationError(f"{context}: volume normalization increased risk")
            if expected_stop_loss <= 0.0 or expected_take_profit <= 0.0:
                raise SchemaValidationError(f"{context}: invalid quote expected money")
            if not _same_number(expected_ratio, expected_take_profit / expected_stop_loss):
                raise SchemaValidationError(f"{context}: quote expected ratio mismatch")
            if row["lot_mode"] == REFERENCE_LOT_MODE:
                if utilization is None or risk_budget is None or not _same_number(
                    utilization, expected_stop_loss / risk_budget
                ):
                    raise SchemaValidationError(f"{context}: risk budget utilization mismatch")
                if utilization > 1.0 + 1e-7:
                    raise SchemaValidationError(f"{context}: normalized volume exceeds risk budget")
            else:
                if utilization is not None:
                    raise SchemaValidationError(
                        f"{context}: fixed-lot attempt has risk budget utilization"
                    )
                if not _same_number(requested_volume, lot_size):
                    raise SchemaValidationError(f"{context}: fixed-lot requested volume mismatch")
        elif utilization is not None:
            raise SchemaValidationError(f"{context}: utilization exists without request money")

        micro_complete = _as_bool(row, "micro_features_complete", context)
        macro_complete = _as_bool(row, "macro_features_complete", context)
        snapshot_complete = _as_bool(row, "feature_snapshot_complete", context)
        if snapshot_complete != (micro_complete and macro_complete):
            raise SchemaValidationError(f"{context}: feature completeness flags disagree")
        if micro_complete:
            for column in micro_feature_columns:
                _as_float(row, column, context)
            _validate_band_width(
                row,
                "micro_band_base_0",
                "micro_band_upper_0",
                "micro_band_lower_0",
                "micro_band_width_0",
                "micro_band_width_percent_0",
                context,
            )
            micro_lower = float(row["micro_band_lower_0"])
            micro_upper = float(row["micro_band_upper_0"])
            expected_micro_b0 = 100.0 * (trigger_bid - micro_lower) / (
                micro_upper - micro_lower
            )
            if not _same_number(float(row["micro_b_percent_0"]), expected_micro_b0):
                raise SchemaValidationError(f"{context}: Micro %B shift 0 mismatch")
        if macro_complete:
            if not _as_bool(window, "macro_band_complete", context):
                raise SchemaValidationError(
                    f"{context}: Macro features complete with incomplete window bands"
                )
            for column in macro_feature_columns:
                _as_float(row, column, context)
            lower = float(window["macro_band_lower_1"])
            upper = float(window["macro_band_upper_1"])
            expected_b1 = 100.0 * (pivot_trade - lower) / (upper - lower)
            actual_b1 = float(row["macro_pivot_b_percent_1"])
            if not _same_number(actual_b1, expected_b1):
                raise SchemaValidationError(f"{context}: Macro pivot %B shift 1 mismatch")
        if snapshot_complete:
            if not _is_null(row["feature_invalid_reason"]):
                raise SchemaValidationError(f"{context}: complete features have invalid reason")
        elif _is_null(row["feature_invalid_reason"]):
            raise SchemaValidationError(f"{context}: incomplete features lack invalid reason")

        if row["route_status"] != "VALID":
            raise SchemaValidationError(f"{context}: structural route is not valid")
        attempt_status = row["attempt_status"]
        if attempt_status not in ("DENIED", "SEND_FAILED", "SENT", "FILLED", "CLOSED", "CENSORED"):
            raise SchemaValidationError(f"{context}: invalid attempt status")
        blocked = not _is_null(row["block_source"]) or not _is_null(row["block_reason"])
        if (_is_null(row["block_source"]) != _is_null(row["block_reason"])):
            raise SchemaValidationError(f"{context}: partial block reason")
        if attempt_status == "DENIED" and (send_attempted or not blocked):
            raise SchemaValidationError(f"{context}: denied attempt status mismatch")
        if attempt_status == "SEND_FAILED" and (not send_attempted or not blocked):
            raise SchemaValidationError(f"{context}: send-failed status mismatch")
        if attempt_status in ("SENT", "FILLED", "CLOSED", "CENSORED") and not send_succeeded:
            raise SchemaValidationError(f"{context}: successful lifecycle status lacks send success")
        if attempt_status not in ("DENIED", "SEND_FAILED") and blocked:
            raise SchemaValidationError(f"{context}: non-denied attempt has a block reason")
        if not observed_geometry_present and attempt_status != "DENIED":
            raise SchemaValidationError(
                f"{context}: non-denied attempt lacks observation geometry"
            )
        attempts[signal_id] = row
    return attempts


def _validate_checks(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    attempts: dict[str, dict[str, str]],
) -> tuple[
    dict[str, list[dict[str, str]]],
    dict[str, dict[str, str]],
    dict[str, dict[str, str]],
]:
    checks: dict[str, list[dict[str, str]]] = defaultdict(list)
    entry_confirmations: dict[str, dict[str, str]] = {}
    close_confirmations: dict[str, dict[str, str]] = {}
    order_owners: dict[int, str] = {}
    position_owners: dict[int, str] = {}
    phases = {"OBSERVATION", "PRE_SEND", "SEND_RESULT", "OWNERSHIP", "TERMINAL"}
    phase_rank = {
        "OBSERVATION": 0,
        "PRE_SEND": 1,
        "SEND_RESULT": 2,
        "OWNERSHIP": 3,
        "TERMINAL": 4,
    }
    bool_columns = (
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
        "send_performed",
        "send_succeeded",
        "broker_entry_confirmed",
        "broker_close_confirmed",
    )
    for row_index, row in enumerate(rows, start=2):
        context = f"{EXECUTION_CHECKS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        attempt = attempts.get(row["signal_id"])
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan execution check")
        for column in ("window_id", "symbol", "direction"):
            if row[column] != attempt[column]:
                raise SchemaValidationError(f"{context}: check/attempt mismatch for {column}")
        sequence = _as_int(row, "check_sequence", context)
        if sequence is None or sequence <= 0:
            raise SchemaValidationError(f"{context}: invalid check sequence")
        if row["check_phase"] not in phases:
            raise SchemaValidationError(f"{context}: invalid check phase")
        check_time, _, _ = _validate_time_triplet(
            row,
            "broker_time",
            "analysis_time",
            "offset_minutes",
            context,
        )
        trigger_time = _as_time(attempt, "trigger_broker_time", context)
        assert check_time is not None and trigger_time is not None
        if check_time < trigger_time:
            raise SchemaValidationError(f"{context}: execution check precedes trigger")
        for column in bool_columns:
            _as_bool(row, column, context)
        for column in (
            "bid",
            "ask",
            "spread_points",
            "point_size",
            "stops_distance_points",
            "freeze_distance_points",
            "account_balance",
            "free_margin",
        ):
            _as_float(row, column, context)
        allowed = row["allowed"] == "1"
        if allowed and (not _is_null(row["block_source"]) or not _is_null(row["block_reason"])):
            raise SchemaValidationError(f"{context}: allowed check has block reason")
        if not allowed and (_is_null(row["block_source"]) or _is_null(row["block_reason"])):
            raise SchemaValidationError(f"{context}: denied check lacks block reason")
        send_performed = row["send_performed"] == "1"
        send_succeeded = row["send_succeeded"] == "1"
        if send_succeeded and not send_performed:
            raise SchemaValidationError(f"{context}: check send succeeded without send")
        if send_performed and row["check_phase"] != "SEND_RESULT":
            raise SchemaValidationError(f"{context}: send is recorded outside SEND_RESULT")
        if row["broker_entry_confirmed"] == "1":
            if attempt["send_succeeded"] != "1":
                raise SchemaValidationError(f"{context}: entry confirmed without send success")
            for column in ("order_ticket", "deal_ticket", "position_ticket", "position_identifier"):
                value = _as_int(row, column, context)
                if value is None or value <= 0:
                    raise SchemaValidationError(f"{context}: entry confirmation lacks {column}")
            for column in (
                "broker_entry_price",
                "broker_volume",
                "broker_stop_loss",
                "broker_take_profit",
            ):
                value = _as_float(row, column, context)
                if value is None or value <= 0.0:
                    raise SchemaValidationError(f"{context}: entry confirmation lacks {column}")
            for check_column, attempt_column in (
                ("broker_volume", "normalized_volume"),
                ("broker_stop_loss", "request_stop_loss"),
                ("broker_take_profit", "request_take_profit"),
            ):
                if not _same_number(float(row[check_column]), float(attempt[attempt_column])):
                    raise SchemaValidationError(
                        f"{context}: broker entry changed owned {check_column}"
                    )
            order_ticket = int(row["order_ticket"])
            position_identifier = int(row["position_identifier"])
            for owners, ticket, label in (
                (order_owners, order_ticket, "order ticket"),
                (position_owners, position_identifier, "position identifier"),
            ):
                owner = owners.setdefault(ticket, row["signal_id"])
                if owner != row["signal_id"]:
                    raise SchemaValidationError(f"{context}: duplicate {label} ownership")
            previous = entry_confirmations.setdefault(row["signal_id"], row)
            if previous is not row and any(
                previous[column] != row[column]
                for column in (
                    "order_ticket",
                    "deal_ticket",
                    "position_ticket",
                    "position_identifier",
                    "broker_entry_price",
                    "broker_volume",
                    "broker_stop_loss",
                    "broker_take_profit",
                )
            ):
                raise SchemaValidationError(f"{context}: conflicting broker entry confirmation")
        if row["broker_close_confirmed"] == "1":
            if row["check_phase"] != "TERMINAL":
                raise SchemaValidationError(f"{context}: close confirmation is not terminal")
            for column in ("deal_ticket", "position_ticket", "position_identifier"):
                value = _as_int(row, column, context)
                if value is None or value <= 0:
                    raise SchemaValidationError(f"{context}: close confirmation lacks {column}")
            close_price = _as_float(row, "close_price", context)
            closed_volume = _as_float(row, "closed_volume", context)
            terminal_reason = _require_value(row, "terminal_reason", context)
            if close_price is None or close_price <= 0.0 or closed_volume is None or closed_volume <= 0.0:
                raise SchemaValidationError(f"{context}: invalid broker close confirmation")
            if terminal_reason not in (
                "BROKER_TP",
                "BROKER_SL",
                "MIXED",
                "MANUAL",
                "STOP_OUT",
                "EXPERT",
                "OTHER",
            ):
                raise SchemaValidationError(f"{context}: invalid terminal check reason")
            if row["signal_id"] in close_confirmations:
                raise SchemaValidationError(f"{context}: duplicate broker close confirmation")
            close_confirmations[row["signal_id"]] = row
        checks[row["signal_id"]].append(row)

    for signal_id, attempt in attempts.items():
        signal_checks = checks.get(signal_id, [])
        if not signal_checks:
            raise SchemaValidationError(f"Signal {signal_id} has no execution check facts")
        ordered = sorted(signal_checks, key=lambda row: int(row["check_sequence"]))
        sequences = [int(row["check_sequence"]) for row in ordered]
        if sequences != list(range(1, len(sequences) + 1)):
            raise SchemaValidationError(f"Signal {signal_id} has non-contiguous execution checks")
        check_times = [
            _as_time(row, "broker_time", f"Signal {signal_id}")
            for row in ordered
        ]
        if any(left > right for left, right in zip(check_times, check_times[1:])):
            raise SchemaValidationError(f"Signal {signal_id} has non-monotonic check times")
        ranks = [phase_rank[row["check_phase"]] for row in ordered]
        if any(left > right for left, right in zip(ranks, ranks[1:])):
            raise SchemaValidationError(f"Signal {signal_id} has invalid check phase order")
        phases_seen = {row["check_phase"] for row in ordered}
        if attempt["send_attempted"] == "1":
            if not {"PRE_SEND", "SEND_RESULT"}.issubset(phases_seen):
                raise SchemaValidationError(f"Signal {signal_id} lacks pre-send/send-result checks")
            authorizing_rows = [
                row
                for row in ordered
                if row["check_phase"] == "PRE_SEND"
                and row["allowed"] == "1"
                and row["order_check_performed"] == "1"
                and row["order_check_allowed"] == "1"
            ]
            if len(authorizing_rows) != 1:
                raise SchemaValidationError(f"Signal {signal_id} lacks an authorizing fresh check")
            authorizing = authorizing_rows[0]
            for check_column, attempt_column in (
                ("entry_price", "request_entry_price"),
                ("stop_loss_price", "request_stop_loss"),
                ("take_profit_price", "request_take_profit"),
                ("risk_distance_points", "request_risk_distance_points"),
                ("reward_distance_points", "request_reward_distance_points"),
                ("risk_budget_amount", "risk_budget_amount"),
                ("requested_volume", "requested_volume"),
                ("normalized_volume", "normalized_volume"),
                ("quote_expected_stop_loss", "quote_expected_stop_loss"),
                ("quote_expected_take_profit", "quote_expected_take_profit"),
                ("quote_expected_reward_risk_ratio", "quote_expected_reward_risk_ratio"),
                ("risk_budget_utilization_ratio", "risk_budget_utilization_ratio"),
            ):
                check_value = authorizing[check_column]
                attempt_value = attempt[attempt_column]
                if _is_null(check_value) != _is_null(attempt_value) or (
                    not _is_null(check_value)
                    and not _same_number(float(check_value), float(attempt_value))
                ):
                    raise SchemaValidationError(
                        f"Signal {signal_id} fresh check differs from attempt {check_column}"
                    )
            send_rows = [row for row in ordered if row["send_performed"] == "1"]
            if len(send_rows) != 1:
                raise SchemaValidationError(f"Signal {signal_id} does not own exactly one send")
            if (send_rows[0]["send_succeeded"] == "1") != (
                attempt["send_succeeded"] == "1"
            ):
                raise SchemaValidationError(f"Signal {signal_id} send result disagrees with attempt")
        elif any(row["send_performed"] == "1" for row in ordered):
            raise SchemaValidationError(f"Signal {signal_id} sent despite denied attempt")
        if attempt["attempt_status"] in ("FILLED", "CLOSED") and signal_id not in entry_confirmations:
            raise SchemaValidationError(f"Signal {signal_id} lacks broker entry confirmation")
        if attempt["attempt_status"] == "SEND_FAILED" and signal_id in entry_confirmations:
            raise SchemaValidationError(f"Signal {signal_id} failed send but has a broker fill")
        if signal_id in close_confirmations and signal_id not in entry_confirmations:
            raise SchemaValidationError(f"Signal {signal_id} closed without broker entry confirmation")
    return checks, entry_confirmations, close_confirmations


def _validate_outcomes(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    attempts: dict[str, dict[str, str]],
    entry_confirmations: dict[str, dict[str, str]],
    close_confirmations: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    outcomes: dict[str, dict[str, str]] = {}
    terminal_tokens = {"BROKER_TP", "BROKER_SL", "MIXED", "MANUAL", "STOP_OUT", "EXPERT", "OTHER"}
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_OUTCOMES_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        signal_id = row["signal_id"]
        attempt = attempts.get(signal_id)
        if attempt is None:
            raise SchemaValidationError(f"{context}: orphan signal outcome")
        if signal_id in outcomes:
            raise SchemaValidationError(f"Duplicate signal outcome: {signal_id}")
        entry_confirmation = entry_confirmations.get(signal_id)
        if entry_confirmation is None:
            raise SchemaValidationError(f"{context}: outcome has no broker entry evidence")
        if attempt["attempt_status"] != "CLOSED":
            raise SchemaValidationError(f"{context}: outcome attempt is not CLOSED")
        for column in (
            "window_id",
            "symbol",
            "macro_timeframe",
            "micro_timeframe",
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
            raise SchemaValidationError(f"{context}: outcome times are not causal")
        duration = _as_int(row, "duration_seconds", context)
        if duration != int((close_time - entry_time).total_seconds()):
            raise SchemaValidationError(f"{context}: duration_seconds mismatch")
        if not _as_bool(row, "broker_entry_confirmed", context) or not _as_bool(
            row, "broker_close_confirmed", context
        ):
            raise SchemaValidationError(f"{context}: outcome is not broker-confirmed")
        for column in (
            "order_ticket",
            "entry_deal_ticket",
            "last_close_deal_ticket",
            "position_ticket",
            "position_identifier",
            "close_deal_count",
        ):
            value = _as_int(row, column, context)
            if value is None or value <= 0:
                raise SchemaValidationError(f"{context}: invalid ticket/count {column}")
        for column in (
            "submitted_request_price",
            "broker_entry_price",
            "broker_volume",
            "immutable_stop_loss",
            "immutable_take_profit",
            "close_price",
            "closed_volume",
            "request_risk_distance_points",
            "request_reward_distance_points",
            "request_price_reward_risk_ratio",
            "quote_expected_stop_loss",
            "quote_expected_take_profit",
            "quote_expected_reward_risk_ratio",
            "entry_slippage_points",
            "gross_profit",
            "commission",
            "swap",
            "fee",
            "net_profit",
            "gross_execution_r",
            "net_execution_r",
        ):
            _as_float(row, column, context)
        risk_budget = _as_float(row, "risk_budget_amount", context, nullable=True)
        utilization = _as_float(
            row, "risk_budget_utilization_ratio", context, nullable=True
        )
        gross_budget_r = _as_float(row, "gross_budget_r", context, nullable=True)
        net_budget_r = _as_float(row, "net_budget_r", context, nullable=True)
        if not _same_number(float(row["closed_volume"]), float(row["broker_volume"])):
            raise SchemaValidationError(f"{context}: position is not fully closed")
        for outcome_column, check_column in (
            ("order_ticket", "order_ticket"),
            ("entry_deal_ticket", "deal_ticket"),
            ("position_ticket", "position_ticket"),
            ("position_identifier", "position_identifier"),
        ):
            if row[outcome_column] != entry_confirmation[check_column]:
                raise SchemaValidationError(
                    f"{context}: outcome changed entry ownership fact {outcome_column}"
                )
        for outcome_column, check_column in (
            ("broker_entry_price", "broker_entry_price"),
            ("broker_volume", "broker_volume"),
            ("immutable_stop_loss", "broker_stop_loss"),
            ("immutable_take_profit", "broker_take_profit"),
        ):
            if not _same_number(float(row[outcome_column]), float(entry_confirmation[check_column])):
                raise SchemaValidationError(
                    f"{context}: outcome changed broker entry fact {outcome_column}"
                )
        matching_attempt_fields = {
            "submitted_request_price": "request_entry_price",
            "immutable_stop_loss": "request_stop_loss",
            "immutable_take_profit": "request_take_profit",
            "request_risk_distance_points": "request_risk_distance_points",
            "request_reward_distance_points": "request_reward_distance_points",
            "request_price_reward_risk_ratio": "request_price_reward_risk_ratio",
            "risk_budget_amount": "risk_budget_amount",
            "quote_expected_stop_loss": "quote_expected_stop_loss",
            "quote_expected_take_profit": "quote_expected_take_profit",
            "quote_expected_reward_risk_ratio": "quote_expected_reward_risk_ratio",
            "risk_budget_utilization_ratio": "risk_budget_utilization_ratio",
        }
        for outcome_column, attempt_column in matching_attempt_fields.items():
            outcome_value = row[outcome_column]
            attempt_value = attempt[attempt_column]
            if _is_null(outcome_value) != _is_null(attempt_value) or (
                not _is_null(outcome_value)
                and not _same_number(float(outcome_value), float(attempt_value))
            ):
                raise SchemaValidationError(
                    f"{context}: outcome changed captured request fact {outcome_column}"
                )
        point_size = float(attempt["point_size"])
        request_price = float(row["submitted_request_price"])
        entry_price = float(row["broker_entry_price"])
        direction = row["direction"]
        expected_entry_slippage = (
            (entry_price - request_price) / point_size
            if direction == "BUY"
            else (request_price - entry_price) / point_size
        )
        if not _same_number(float(row["entry_slippage_points"]), expected_entry_slippage):
            raise SchemaValidationError(f"{context}: entry slippage sign/arithmetic mismatch")

        gross = float(row["gross_profit"])
        commission = float(row["commission"])
        swap = float(row["swap"])
        fee = float(row["fee"])
        net = float(row["net_profit"])
        executable_risk = float(row["quote_expected_stop_loss"])
        if not _same_number(net, gross + commission + swap + fee):
            raise SchemaValidationError(f"{context}: net profit cost arithmetic mismatch")
        expected_r_values = {
            "gross_execution_r": gross / executable_risk,
            "net_execution_r": net / executable_risk,
        }
        for column, expected in expected_r_values.items():
            if not _same_number(float(row[column]), expected):
                raise SchemaValidationError(f"{context}: R arithmetic mismatch for {column}")
        if attempt["lot_mode"] == REFERENCE_LOT_MODE:
            if risk_budget is None or utilization is None or gross_budget_r is None or net_budget_r is None:
                raise SchemaValidationError(f"{context}: reference-risk outcome facts are missing")
            if not _same_number(gross_budget_r, gross / risk_budget) or not _same_number(
                net_budget_r, net / risk_budget
            ):
                raise SchemaValidationError(f"{context}: budget R arithmetic mismatch")
        elif any(
            value is not None
            for value in (risk_budget, utilization, gross_budget_r, net_budget_r)
        ):
            raise SchemaValidationError(f"{context}: fixed-lot outcome carries budget R facts")

        terminal_reason = row["terminal_reason"]
        if terminal_reason not in terminal_tokens:
            raise SchemaValidationError(f"{context}: unsupported terminal reason")
        consistent = _as_bool(row, "close_reason_consistent", context)
        binary_eligible = _as_bool(row, "binary_eligible", context)
        binary_target = _as_int(row, "binary_target", context, nullable=True)
        exclusion_reason = row["exclusion_reason"]
        exit_slippage = _as_float(row, "exit_slippage_points", context, nullable=True)
        if terminal_reason in ("BROKER_TP", "BROKER_SL"):
            if not consistent:
                raise SchemaValidationError(f"{context}: broker TP/SL outcome is inconsistent")
            expected_target = 1 if terminal_reason == "BROKER_TP" else 0
            feature_complete = attempt["feature_snapshot_complete"] == "1"
            if feature_complete:
                if not binary_eligible or binary_target != expected_target or not _is_null(
                    exclusion_reason
                ):
                    raise SchemaValidationError(f"{context}: binary target mismatch")
            elif binary_eligible or binary_target is not None or exclusion_reason != "FEATURE_INCOMPLETE":
                raise SchemaValidationError(
                    f"{context}: incomplete TP/SL outcome has invalid exclusion facts"
                )
            terminal_price = (
                float(row["immutable_take_profit"])
                if terminal_reason == "BROKER_TP"
                else float(row["immutable_stop_loss"])
            )
            close_price = float(row["close_price"])
            expected_exit_slippage = (
                (terminal_price - close_price) / point_size
                if direction == "BUY"
                else (close_price - terminal_price) / point_size
            )
            if exit_slippage is None or not _same_number(exit_slippage, expected_exit_slippage):
                raise SchemaValidationError(f"{context}: exit slippage sign/arithmetic mismatch")
        else:
            if binary_eligible or binary_target is not None or _is_null(exclusion_reason):
                raise SchemaValidationError(f"{context}: nonbinary outcome carries binary target")
            if terminal_reason == "MIXED" and consistent:
                raise SchemaValidationError(f"{context}: mixed outcome marked reason-consistent")
            if exit_slippage is not None:
                raise SchemaValidationError(f"{context}: nonbinary outcome has terminal slippage")
        close_confirmation = close_confirmations.get(signal_id)
        if close_confirmation is not None:
            for outcome_column, check_column in (
                ("last_close_deal_ticket", "deal_ticket"),
                ("position_ticket", "position_ticket"),
                ("position_identifier", "position_identifier"),
                ("terminal_reason", "terminal_reason"),
            ):
                if row[outcome_column] != close_confirmation[check_column]:
                    raise SchemaValidationError(
                        f"{context}: outcome changed terminal ownership fact {outcome_column}"
                    )
            for outcome_column, check_column in (
                ("close_price", "close_price"),
                ("closed_volume", "closed_volume"),
            ):
                if not _same_number(float(row[outcome_column]), float(close_confirmation[check_column])):
                    raise SchemaValidationError(
                        f"{context}: outcome changed terminal broker fact {outcome_column}"
                    )
        outcomes[signal_id] = row
    return outcomes


def _validate_summary(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    actual_counts: dict[str, int],
    attempts: dict[str, dict[str, str]],
    entry_confirmations: dict[str, dict[str, str]],
    outcomes: dict[str, dict[str, str]],
) -> tuple[str, ...]:
    if len(rows) != 1:
        raise SchemaValidationError("run_summary.tsv must contain exactly one row")
    row = rows[0]
    context = RUN_SUMMARY_FILE
    _validate_common_row(row, context, manifest)
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
        raise SchemaValidationError("run summary started time differs from manifest")
    count_columns = {
        "pivot_window_rows": actual_counts[PIVOT_WINDOWS_FILE],
        "signal_attempt_rows": actual_counts[SIGNAL_ATTEMPTS_FILE],
        "execution_check_rows": actual_counts[EXECUTION_CHECKS_FILE],
        "signal_outcome_rows": actual_counts[SIGNAL_OUTCOMES_FILE],
        "feature_complete_rows": sum(
            row["feature_snapshot_complete"] == "1" for row in attempts.values()
        ),
        "feature_incomplete_rows": sum(
            row["feature_snapshot_complete"] == "0" for row in attempts.values()
        ),
        "send_attempt_rows": sum(row["send_attempted"] == "1" for row in attempts.values()),
        "send_succeeded_rows": sum(row["send_succeeded"] == "1" for row in attempts.values()),
        "broker_filled_rows": len(entry_confirmations),
        "broker_closed_rows": len(outcomes),
        "binary_eligible_rows": sum(row["binary_eligible"] == "1" for row in outcomes.values()),
        "binary_tp_rows": sum(row["binary_target"] == "1" for row in outcomes.values()),
        "binary_sl_rows": sum(row["binary_target"] == "0" for row in outcomes.values()),
        "excluded_outcome_rows": sum(row["binary_eligible"] == "0" for row in outcomes.values()),
        "excluded_feature_incomplete_rows": sum(
            row["exclusion_reason"] == "FEATURE_INCOMPLETE" for row in outcomes.values()
        ),
        "excluded_mixed_rows": sum(row["terminal_reason"] == "MIXED" for row in outcomes.values()),
        "excluded_manual_rows": sum(row["terminal_reason"] == "MANUAL" for row in outcomes.values()),
        "excluded_stop_out_rows": sum(
            row["terminal_reason"] == "STOP_OUT" for row in outcomes.values()
        ),
        "excluded_expert_rows": sum(row["terminal_reason"] == "EXPERT" for row in outcomes.values()),
        "excluded_other_rows": sum(row["terminal_reason"] == "OTHER" for row in outcomes.values()),
        "censored_attempt_rows": sum(row["attempt_status"] == "CENSORED" for row in attempts.values()),
    }
    for column, expected in count_columns.items():
        if _as_int(row, column, context) != expected:
            raise SchemaValidationError(f"run summary count mismatch for {column}")
    for column in (
        "duplicate_identity_count",
        "referential_integrity_error_count",
        "row_integrity_error_count",
    ):
        if _as_int(row, column, context) != 0:
            raise SchemaValidationError(f"run summary reports integrity failure: {column}")
    if row["export_status"] != "OK":
        raise SchemaValidationError(f"run summary export_status is not OK: {row['export_status']}")
    completion_status = row["completion_status"]
    if completion_status not in ("NATURAL", "CENSORED"):
        raise SchemaValidationError(
            f"run summary has invalid completion_status: {completion_status}"
        )
    outstanding = sum(
        attempt["attempt_status"] in ("SENT", "FILLED", "CENSORED")
        for attempt in attempts.values()
    )
    if completion_status == "NATURAL" and outstanding:
        raise SchemaValidationError("natural run contains outstanding or censored attempts")
    return ("run completion is CENSORED",) if completion_status == "CENSORED" else ()


def validate_run(
    runs_root: Path,
    run_id: str,
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> RunValidation:
    _require_active_schema(schema_version)
    run_path = _resolve_run_path(runs_root, run_id)
    table_rows = {
        filename: _read_tsv(run_path / filename, TABLE_COLUMNS[filename])
        for filename in RUN_FILES
    }
    manifest = _validate_manifest(table_rows[RUN_MANIFEST_FILE], run_id)
    windows = _validate_windows(table_rows[PIVOT_WINDOWS_FILE], manifest)
    attempts = _validate_attempts(table_rows[SIGNAL_ATTEMPTS_FILE], manifest, windows)
    _, entry_confirmations, close_confirmations = _validate_checks(
        table_rows[EXECUTION_CHECKS_FILE], manifest, attempts
    )
    outcomes = _validate_outcomes(
        table_rows[SIGNAL_OUTCOMES_FILE],
        manifest,
        attempts,
        entry_confirmations,
        close_confirmations,
    )
    closed_attempts = {
        signal_id
        for signal_id, attempt in attempts.items()
        if attempt["attempt_status"] == "CLOSED"
    }
    if closed_attempts != outcomes.keys():
        raise SchemaValidationError(
            "Closed attempt/outcome mismatch: "
            f"missing={sorted(closed_attempts - outcomes.keys())}, "
            f"unexpected={sorted(outcomes.keys() - closed_attempts)}"
        )
    if not close_confirmations.keys() <= outcomes.keys():
        raise SchemaValidationError("Broker close confirmation exists without an outcome")
    actual_counts = {filename: len(rows) for filename, rows in table_rows.items()}
    warnings = _validate_summary(
        table_rows[RUN_SUMMARY_FILE],
        manifest,
        actual_counts,
        attempts,
        entry_confirmations,
        outcomes,
    )
    return RunValidation(
        run_id=run_id,
        config_id=manifest["config_id"],
        run_path=run_path,
        manifest=manifest,
        row_counts=actual_counts,
        warnings=warnings,
    )


def validate_runs(
    runs_root: Path,
    run_ids: list[str] | tuple[str, ...],
    *,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> list[RunValidation]:
    if not run_ids:
        raise ValueError("At least one run ID is required")
    if len(set(run_ids)) != len(run_ids):
        raise ValueError("Duplicate run IDs are not allowed")
    validations = [
        validate_run(runs_root, run_id, schema_version=schema_version)
        for run_id in run_ids
    ]
    baseline = validations[0].manifest
    for validation in validations[1:]:
        mismatches = [
            key
            for key in DATASET_CONFIG_KEYS
            if validation.manifest[key] != baseline[key]
        ]
        if mismatches:
            raise SchemaValidationError(
                "Runs cannot be mixed across configuration boundaries: "
                f"run_id={validation.run_id}, fields={mismatches}"
            )
    return validations
