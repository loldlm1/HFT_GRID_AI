"""Single active schema contract for deterministic market-data exports."""

from __future__ import annotations

from dataclasses import dataclass


SUPPORTED_SCHEMA_VERSION = 8
SUPPORTED_SCHEMA_VERSIONS = (SUPPORTED_SCHEMA_VERSION,)
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
ENGINE_CYCLES_FILE = "engine_cycles.tsv"
ENGINE_REVISIONS_FILE = "engine_revisions.tsv"
ENGINE_ATTEMPTS_FILE = "engine_attempts.tsv"
EXECUTION_CHECKS_FILE = "execution_checks.tsv"
SIGNAL_FEATURES_FILE = "signal_features.tsv"
SIGNAL_OUTCOMES_FILE = "signal_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"
PHASE1_FILES = (
    RUN_MANIFEST_FILE,
    ENGINE_CYCLES_FILE,
    ENGINE_REVISIONS_FILE,
    ENGINE_ATTEMPTS_FILE,
    EXECUTION_CHECKS_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    RUN_SUMMARY_FILE,
)

MANIFEST_COLUMNS = ("schema_version", "key", "value")

IDENTITY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
)

ENGINE_GENEALOGY_COLUMNS = (
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "extremum_cycle_id",
    "extremum_revision_id",
    "extremum_attempt_id",
)

SIGNAL_FEATURE_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    "symbol",
    "direction",
    "entry_broker_time",
    "entry_analysis_time",
    "entry_offset_minutes",
    "source_broker_time",
    "source_analysis_time",
    "source_offset_minutes",
    "structure_0",
    "structure_1",
    "structure_2",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
    "stoch_structure_raw_percent",
    "b_percent_main_base",
    "b_percent_main_base_slope",
    "b_percent_main_macro",
    "b_percent_main_macro_slope",
    "session_id",
    "time_sin",
    "time_cos",
)

EXECUTION_CHECK_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
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

PATH_RATIO_OUTCOME_COLUMNS = (
    "hit_1r_before_sl",
    "hit_1_5r_before_sl",
    "hit_2r_before_sl",
    "hit_3r_before_sl",
    "max_favorable_r",
    "max_adverse_r",
    "bars_to_1r",
    "bars_to_1_5r",
    "bars_to_2r",
    "bars_to_3r",
    "bars_to_sl",
    "path_horizon_bars",
    "path_status",
)

SIGNAL_OUTCOME_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    "entry_broker_time",
    "entry_analysis_time",
    "entry_offset_minutes",
    "terminal_broker_time",
    "terminal_analysis_time",
    "terminal_offset_minutes",
    "terminal_reason",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "broker_close_source",
    *PATH_RATIO_OUTCOME_COLUMNS,
    "path_label_source",
)

ENGINE_CYCLE_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "symbol",
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "extremum_cycle_id",
    "extremum_type",
    "cycle_first_seen_broker_time",
    "cycle_first_seen_analysis_time",
    "cycle_first_seen_offset_minutes",
    "cycle_finalized_broker_time",
    "cycle_finalized_analysis_time",
    "cycle_finalized_offset_minutes",
    "cycle_status",
    "reference_peak_broker_time",
    "reference_peak_analysis_time",
    "reference_peak_offset_minutes",
    "reference_peak_price",
    "reference_bottom_broker_time",
    "reference_bottom_analysis_time",
    "reference_bottom_offset_minutes",
    "reference_bottom_price",
    "reference_range_points",
    "first_extremum_broker_time",
    "first_extremum_analysis_time",
    "first_extremum_offset_minutes",
    "first_extremum_price",
    "final_extremum_broker_time",
    "final_extremum_analysis_time",
    "final_extremum_offset_minutes",
    "final_extremum_price",
    "final_depth_percent",
    "revision_count",
    "attempt_count",
)

ENGINE_REVISION_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "symbol",
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "extremum_cycle_id",
    "revision_id",
    "revision_index",
    "snapshot_broker_time",
    "snapshot_analysis_time",
    "snapshot_offset_minutes",
    "extremum_broker_time",
    "extremum_analysis_time",
    "extremum_offset_minutes",
    "extremum_price",
    "extremum_type",
    "depth_percent_raw",
    "distance_from_first_revision_points",
    "distance_from_previous_revision_points",
    "depth_delta_from_previous_percent",
    "bars_since_cycle_start",
    "reference_peak_broker_time",
    "reference_peak_analysis_time",
    "reference_peak_offset_minutes",
    "reference_peak_price",
    "reference_bottom_broker_time",
    "reference_bottom_analysis_time",
    "reference_bottom_offset_minutes",
    "reference_bottom_price",
    "reference_range_points",
    "structure_0",
    "structure_1",
    "structure_2",
    "session_id",
    "time_sin",
    "time_cos",
)

ENGINE_ATTEMPT_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "symbol",
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "extremum_cycle_id",
    "revision_id",
    "attempt_id",
    "cycle_attempt_index",
    "revision_attempt_index",
    "attempt_created_broker_time",
    "attempt_created_analysis_time",
    "attempt_created_offset_minutes",
    "direction",
    "candidate_depth_percent",
    "reference_range_points",
    "distance_from_first_revision_points",
    "distance_from_previous_revision_points",
    "depth_delta_from_previous_percent",
    "bars_since_cycle_start",
    "trigger_price",
    "stop_anchor_price",
    "take_profit_price",
    "trigger_reached",
    "trigger_broker_time",
    "trigger_analysis_time",
    "trigger_offset_minutes",
    "attempt_status",
    "operational_block_source",
    "operational_block_reason",
    "simulated_terminal_reason",
    "simulated_profit_r",
    "simulated_max_favorable_r",
    "simulated_max_adverse_r",
    "simulated_path_status",
    "simulated_outcome_source",
    "broker_signal_id",
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
    "cycle_rows",
    "revision_rows",
    "attempt_rows",
    "execution_check_rows",
    "feature_rows",
    "outcome_rows",
    "feature_invalid_rows",
    "outcome_invalid_rows",
    "max_active_attempt_paths",
    "export_status",
)

# Public aliases keep the names used by the dataset/report code descriptive.
FEATURE_COLUMNS = SIGNAL_FEATURE_COLUMNS
OUTCOME_COLUMNS = SIGNAL_OUTCOME_COLUMNS
OUTCOME_COLUMNS_WITH_PATH = SIGNAL_OUTCOME_COLUMNS
SCHEMA_V8_FEATURE_COLUMNS = SIGNAL_FEATURE_COLUMNS
SCHEMA_V8_CHECK_COLUMNS = EXECUTION_CHECK_COLUMNS
SCHEMA_V8_OUTCOME_COLUMNS_WITH_PATH = SIGNAL_OUTCOME_COLUMNS
SCHEMA_V8_CYCLE_COLUMNS = ENGINE_CYCLE_COLUMNS
SCHEMA_V8_REVISION_COLUMNS = ENGINE_REVISION_COLUMNS
SCHEMA_V8_ATTEMPT_COLUMNS = ENGINE_ATTEMPT_COLUMNS
SCHEMA_V8_SUMMARY_COLUMNS = SUMMARY_COLUMNS

SCHEMA_V8_ENGINE_MODEL_FEATURE_COLUMNS = (
    "direction",
    "cycle_attempt_index",
    "revision_attempt_index",
    "candidate_depth_percent",
    "reference_range_points",
    "distance_from_first_revision_points",
    "distance_from_previous_revision_points",
    "depth_delta_from_previous_percent",
    "bars_since_cycle_start",
    "structure_0",
    "structure_1",
    "structure_2",
    "session_id",
    "time_sin",
    "time_cos",
)
MODEL_FEATURE_COLUMNS = SCHEMA_V8_ENGINE_MODEL_FEATURE_COLUMNS
FEATURE_SET_COLUMNS = {
    "schema_v8_extremum_engine": SCHEMA_V8_ENGINE_MODEL_FEATURE_COLUMNS,
    "schema_v8_extremum_engine_xgb": SCHEMA_V8_ENGINE_MODEL_FEATURE_COLUMNS,
}
FEATURE_SET_SCHEMA_VERSION = {
    feature_set_id: SUPPORTED_SCHEMA_VERSION for feature_set_id in FEATURE_SET_COLUMNS
}

TARGET_COLUMNS = ("target_is_win", "target_profit_r", "target_terminal_reason")
BROKER_TARGET_FAMILY = "broker_1r"
ENGINE_SIMULATED_TARGET_FAMILY = "engine_simulated_1r"
PATH_RATIO_TARGET_FAMILIES = ("1r", "1_5r", "2r", "3r", "expected_r")
DATASET_TARGET_FAMILIES = (
    BROKER_TARGET_FAMILY,
    ENGINE_SIMULATED_TARGET_FAMILY,
    *PATH_RATIO_TARGET_FAMILIES,
)

AUDIT_COLUMNS = (
    "symbol",
    "entry_broker_time",
    "entry_analysis_time",
    "terminal_broker_time",
    "terminal_analysis_time",
    "entry_price",
    "close_price",
    "net_profit",
    "duration_seconds",
    "duration_m1_bars",
)

NUMERIC_COLUMNS = (
    "schema_version",
    "source_attempt_index",
    "cycle_attempt_index",
    "revision_attempt_index",
    "candidate_depth_percent",
    "reference_range_points",
    "distance_from_first_revision_points",
    "distance_from_previous_revision_points",
    "depth_delta_from_previous_percent",
    "bars_since_cycle_start",
    "stoch_structure_raw_percent",
    "b_percent_main_base",
    "b_percent_main_base_slope",
    "b_percent_main_macro",
    "b_percent_main_macro_slope",
    "time_sin",
    "time_cos",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
    *PATH_RATIO_OUTCOME_COLUMNS[:-1],
)

CATEGORICAL_COLUMNS = (
    "direction",
    "structure_0",
    "structure_1",
    "structure_2",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
    "session_id",
    "terminal_reason",
    "path_status",
)

NUMERIC_PATH_RATIO_COLUMNS = PATH_RATIO_OUTCOME_COLUMNS[:-1]


@dataclass(frozen=True)
class DatasetColumnGroups:
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS
    target_columns: tuple[str, ...] = TARGET_COLUMNS
    identity_columns: tuple[str, ...] = IDENTITY_COLUMNS
    audit_columns: tuple[str, ...] = AUDIT_COLUMNS


def _require_active_schema(schema_version: int) -> None:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise ValueError(
            f"Historical schema {schema_version} requires its historical code revision; "
            f"active tooling accepts schema {SUPPORTED_SCHEMA_VERSION} only"
        )


def feature_columns_for_schema(schema_version: int) -> tuple[str, ...]:
    _require_active_schema(schema_version)
    return SIGNAL_FEATURE_COLUMNS


def feature_columns_for_set(feature_set_id: str) -> tuple[str, ...]:
    try:
        return FEATURE_SET_COLUMNS[feature_set_id]
    except KeyError as exc:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}") from exc


def schema_version_for_feature_set(feature_set_id: str) -> int:
    try:
        return FEATURE_SET_SCHEMA_VERSION[feature_set_id]
    except KeyError as exc:
        raise ValueError(f"Unsupported feature_set_id: {feature_set_id}") from exc


def default_feature_set_for_schema(schema_version: int) -> str:
    _require_active_schema(schema_version)
    return "schema_v8_extremum_engine_xgb"


_FILE_COLUMNS = {
    RUN_MANIFEST_FILE: MANIFEST_COLUMNS,
    ENGINE_CYCLES_FILE: ENGINE_CYCLE_COLUMNS,
    ENGINE_REVISIONS_FILE: ENGINE_REVISION_COLUMNS,
    ENGINE_ATTEMPTS_FILE: ENGINE_ATTEMPT_COLUMNS,
    EXECUTION_CHECKS_FILE: EXECUTION_CHECK_COLUMNS,
    SIGNAL_FEATURES_FILE: SIGNAL_FEATURE_COLUMNS,
    SIGNAL_OUTCOMES_FILE: SIGNAL_OUTCOME_COLUMNS,
    RUN_SUMMARY_FILE: SUMMARY_COLUMNS,
}


def expected_columns_for(filename: str, schema_version: int = SUPPORTED_SCHEMA_VERSION) -> tuple[str, ...]:
    _require_active_schema(schema_version)
    try:
        return _FILE_COLUMNS[filename]
    except KeyError as exc:
        raise ValueError(f"Unsupported schema v8 file: {filename}") from exc


def expected_column_variants_for(
    filename: str,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> tuple[tuple[str, ...], ...]:
    return (expected_columns_for(filename, schema_version),)
