"""Schema contract for deterministic signal feature exports."""

from __future__ import annotations

from dataclasses import dataclass


SUPPORTED_SCHEMA_VERSION = 7
SUPPORTED_SCHEMA_VERSIONS = (4, 5, 6, 7)
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
SIGNAL_FEATURES_FILE = "signal_features.tsv"
SIGNAL_ADMISSIONS_FILE = "signal_admissions.tsv"
SIGNAL_OUTCOMES_FILE = "signal_outcomes.tsv"
SIGNAL_LEG_OUTCOMES_FILE = "signal_leg_outcomes.tsv"
ENGINE_CYCLES_FILE = "engine_cycles.tsv"
ENGINE_REVISIONS_FILE = "engine_revisions.tsv"
ENGINE_ATTEMPTS_FILE = "engine_attempts.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"
PHASE1_FILES = (
    RUN_MANIFEST_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    RUN_SUMMARY_FILE,
)

MANIFEST_COLUMNS = ("schema_version", "key", "value")

SUMMARY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "started_at",
    "finished_at",
    "feature_rows",
    "outcome_rows",
    "feature_invalid_rows",
    "outcome_invalid_rows",
    "export_status",
)

SCHEMA_V6_SUMMARY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "started_at",
    "finished_at",
    "feature_rows",
    "admission_rows",
    "outcome_rows",
    "feature_invalid_rows",
    "outcome_invalid_rows",
    "export_status",
)

SCHEMA_V6_ADMISSION_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "event_time",
    "event_type",
    "admission_status",
    "admission_source",
    "admission_reason",
    "spread_points",
    "max_spread",
    "market_status",
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "risk_plan_status",
    "risk_target_amount",
    "expected_sl_loss",
    "expected_tp_profit",
    "raw_lot",
    "normalized_lot",
)

ENGINE_GENEALOGY_COLUMNS = (
    "engine_id",
    "engine_label",
    "engine_timeframe",
    "extremum_cycle_id",
    "extremum_revision_id",
    "extremum_attempt_id",
)

SCHEMA_V4_FEATURE_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "symbol",
    "strategy_label",
    "direction",
    "entry_time",
    "source_time",
    "structure_0",
    "structure_1",
    "structure_2",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
)

SCHEMA_V5_NUMERIC_COLUMNS = (
    "stoch_structure_raw_percent",
    "b_percent_main_base",
    "b_percent_main_base_slope",
    "b_percent_main_macro",
    "b_percent_main_macro_slope",
    "session_id",
    "time_sin",
    "time_cos",
)

SCHEMA_V5_FEATURE_COLUMNS = SCHEMA_V4_FEATURE_COLUMNS + SCHEMA_V5_NUMERIC_COLUMNS
FEATURE_COLUMNS = SCHEMA_V5_FEATURE_COLUMNS

OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "terminal_time",
    "terminal_reason",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
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

OUTCOME_COLUMNS_WITH_PATH = OUTCOME_COLUMNS + PATH_RATIO_OUTCOME_COLUMNS

SCHEMA_V6_BROKER_OUTCOME_COLUMNS = (
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "broker_close_source",
    "partial_tp_mode",
    "partial_tp1_confirmed",
    "partial_tp2_confirmed",
    "partial_tp3_confirmed",
    "partial_tp1_closed_volume",
    "partial_tp2_closed_volume",
    "partial_tp3_closed_volume",
)

SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH = (
    OUTCOME_COLUMNS
    + SCHEMA_V6_BROKER_OUTCOME_COLUMNS
    + PATH_RATIO_OUTCOME_COLUMNS
    + ("path_label_source",)
)

IDENTITY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
)

SCHEMA_V7_FEATURE_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    "symbol",
    "direction",
    "entry_time",
    "source_time",
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
    *SCHEMA_V5_NUMERIC_COLUMNS,
)

SCHEMA_V7_ADMISSION_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    "event_time",
    "event_type",
    "admission_status",
    "admission_source",
    "admission_reason",
    "spread_points",
    "max_spread",
    "market_status",
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "risk_plan_status",
    "risk_target_amount",
    "expected_sl_loss",
    "expected_tp_profit",
    "raw_lot",
    "normalized_lot",
)

SCHEMA_V7_OUTCOME_COLUMNS_WITH_PATH = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    *OUTCOME_COLUMNS[6:],
    *SCHEMA_V6_BROKER_OUTCOME_COLUMNS,
    *PATH_RATIO_OUTCOME_COLUMNS,
    "path_label_source",
)

SCHEMA_V7_LEG_OUTCOME_COLUMNS = IDENTITY_COLUMNS + ENGINE_GENEALOGY_COLUMNS + (
    "leg_index",
    "target_r",
    "entry_time",
    "close_time",
    "entry_price",
    "close_price",
    "stop_price",
    "take_profit_price",
    "initial_lot",
    "closed_volume",
    "net_profit",
    "expected_sl_loss",
    "profit_r",
    "terminal_reason",
    "broker_close_confirmed",
    "close_source",
    "position_ticket",
    "position_comment",
)

SCHEMA_V7_CYCLE_COLUMNS = (
    "schema_version", "run_id", "config_id", "symbol", "engine_id",
    "engine_label", "engine_timeframe", "extremum_cycle_id", "extremum_type",
    "cycle_first_seen_time", "cycle_finalized_time", "cycle_status",
    "reference_peak_time", "reference_peak_price", "reference_bottom_time",
    "reference_bottom_price", "reference_range_points", "first_extremum_time",
    "first_extremum_price", "final_extremum_time", "final_extremum_price",
    "final_depth_percent", "revision_count", "attempt_count",
)

SCHEMA_V7_REVISION_COLUMNS = (
    "schema_version", "run_id", "config_id", "symbol", "engine_id",
    "engine_label", "engine_timeframe", "extremum_cycle_id", "revision_id",
    "revision_index", "snapshot_time", "extremum_time", "extremum_price",
    "extremum_type", "depth_percent_raw", "distance_from_first_revision_points",
    "distance_from_previous_revision_points", "depth_delta_from_previous_percent",
    "bars_since_cycle_start", "reference_peak_time", "reference_peak_price",
    "reference_bottom_time", "reference_bottom_price", "reference_range_points",
    "structure_0", "structure_1", "structure_2", "session_id", "time_sin", "time_cos",
)

SCHEMA_V7_ATTEMPT_COLUMNS = (
    "schema_version", "run_id", "config_id", "symbol", "engine_id",
    "engine_label", "engine_timeframe", "extremum_cycle_id", "revision_id",
    "attempt_id", "cycle_attempt_index", "revision_attempt_index",
    "attempt_created_time", "direction", "candidate_depth_percent",
    "reference_range_points", "distance_from_first_revision_points",
    "distance_from_previous_revision_points", "depth_delta_from_previous_percent",
    "bars_since_cycle_start", "trigger_price", "stop_anchor_price",
    "take_profit_price", "trigger_reached", "trigger_time", "attempt_status",
    "operational_block_source", "operational_block_reason",
    "simulated_terminal_reason", "simulated_profit_r",
    "simulated_max_favorable_r", "simulated_max_adverse_r",
    "simulated_path_status", "simulated_outcome_source", "broker_signal_id",
    "broker_entry_confirmed", "broker_close_confirmed",
)

SCHEMA_V7_SUMMARY_COLUMNS = (
    "schema_version", "run_id", "config_id", "started_at", "finished_at",
    "cycle_rows", "revision_rows", "attempt_rows", "feature_rows",
    "admission_rows", "outcome_rows", "leg_outcome_rows",
    "feature_invalid_rows", "outcome_invalid_rows", "max_active_attempt_paths",
    "export_status",
)

SCHEMA_V4_MODEL_FEATURE_COLUMNS = (
    "strategy_label",
    "direction",
    "structure_0",
    "structure_1",
    "structure_2",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
)

SCHEMA_V4_NO_STRATEGY_LABEL_FEATURE_COLUMNS = tuple(
    column for column in SCHEMA_V4_MODEL_FEATURE_COLUMNS if column != "strategy_label"
)

SCHEMA_V5_NUMERIC_MODEL_FEATURE_COLUMNS = (
    "direction",
    "stoch_structure_raw_percent",
    "b_percent_main_base",
    "b_percent_main_base_slope",
    "b_percent_main_macro",
    "b_percent_main_macro_slope",
    "session_id",
    "time_sin",
    "time_cos",
)

SCHEMA_V7_ENGINE_MODEL_FEATURE_COLUMNS = (
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

MODEL_FEATURE_COLUMNS = SCHEMA_V5_NUMERIC_MODEL_FEATURE_COLUMNS

FEATURE_SET_COLUMNS = {
    "schema_v4_full": SCHEMA_V4_MODEL_FEATURE_COLUMNS,
    "schema_v4_no_strategy_label": SCHEMA_V4_NO_STRATEGY_LABEL_FEATURE_COLUMNS,
    "schema_v5_numeric_xgb": SCHEMA_V5_NUMERIC_MODEL_FEATURE_COLUMNS,
    "schema_v6_numeric_xgb": SCHEMA_V5_NUMERIC_MODEL_FEATURE_COLUMNS,
    "schema_v7_extremum_engine": SCHEMA_V7_ENGINE_MODEL_FEATURE_COLUMNS,
}

FEATURE_SET_SCHEMA_VERSION = {
    "schema_v4_full": 4,
    "schema_v4_no_strategy_label": 4,
    "schema_v5_numeric_xgb": 5,
    "schema_v6_numeric_xgb": 6,
    "schema_v7_extremum_engine": 7,
}

TARGET_COLUMNS = (
    "target_is_win",
    "target_profit_r",
    "target_terminal_reason",
)

PATH_RATIO_TARGET_FAMILIES = (
    "1r",
    "1_5r",
    "2r",
    "3r",
    "expected_r",
)

BROKER_TARGET_FAMILY = "broker_1r"
DATASET_TARGET_FAMILIES = (BROKER_TARGET_FAMILY,) + PATH_RATIO_TARGET_FAMILIES

AUDIT_COLUMNS = (
    "symbol",
    "entry_time",
    "source_time",
    "terminal_time",
    "entry_price",
    "close_price",
    "net_profit",
    "duration_seconds",
    "duration_m1_bars",
)

NUMERIC_COLUMNS = (
    "schema_version",
    "source_attempt_index",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
    "stoch_structure_raw_percent",
    "b_percent_main_base",
    "b_percent_main_base_slope",
    "b_percent_main_macro",
    "b_percent_main_macro_slope",
    "time_sin",
    "time_cos",
    *PATH_RATIO_OUTCOME_COLUMNS,
)

CATEGORICAL_COLUMNS = (
    "strategy_label",
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
    "session_id",
    "entry_weekday",
    "terminal_reason",
    "path_status",
)

NUMERIC_PATH_RATIO_COLUMNS = (
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
)


@dataclass(frozen=True)
class DatasetColumnGroups:
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS
    target_columns: tuple[str, ...] = TARGET_COLUMNS
    identity_columns: tuple[str, ...] = IDENTITY_COLUMNS
    audit_columns: tuple[str, ...] = AUDIT_COLUMNS


def feature_columns_for_schema(schema_version: int) -> tuple[str, ...]:
    if schema_version == 4:
        return SCHEMA_V4_FEATURE_COLUMNS
    if schema_version == 5:
        return SCHEMA_V5_FEATURE_COLUMNS
    if schema_version == 6:
        return SCHEMA_V5_FEATURE_COLUMNS
    if schema_version == 7:
        return SCHEMA_V7_FEATURE_COLUMNS
    raise ValueError(f"Unsupported feature schema version: {schema_version}")


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
    if schema_version == 4:
        return "schema_v4_full"
    if schema_version == 5:
        return "schema_v5_numeric_xgb"
    if schema_version == 6:
        return "schema_v6_numeric_xgb"
    if schema_version == 7:
        return "schema_v7_extremum_engine"
    raise ValueError(f"Unsupported feature schema version: {schema_version}")


def expected_columns_for(filename: str, schema_version: int = SUPPORTED_SCHEMA_VERSION) -> tuple[str, ...]:
    """Return the expected TSV header for a Phase 1 export file."""
    if filename == RUN_MANIFEST_FILE:
        return MANIFEST_COLUMNS
    if filename == SIGNAL_FEATURES_FILE:
        return feature_columns_for_schema(schema_version)
    if filename == SIGNAL_ADMISSIONS_FILE:
        if schema_version == 6:
            return SCHEMA_V6_ADMISSION_COLUMNS
        if schema_version == 7:
            return SCHEMA_V7_ADMISSION_COLUMNS
        raise ValueError(f"{SIGNAL_ADMISSIONS_FILE} is supported from schema v6")
    if filename == SIGNAL_LEG_OUTCOMES_FILE and schema_version == 7:
        return SCHEMA_V7_LEG_OUTCOME_COLUMNS
    if filename == ENGINE_CYCLES_FILE and schema_version == 7:
        return SCHEMA_V7_CYCLE_COLUMNS
    if filename == ENGINE_REVISIONS_FILE and schema_version == 7:
        return SCHEMA_V7_REVISION_COLUMNS
    if filename == ENGINE_ATTEMPTS_FILE and schema_version == 7:
        return SCHEMA_V7_ATTEMPT_COLUMNS
    if filename == SIGNAL_OUTCOMES_FILE:
        return OUTCOME_COLUMNS
    if filename == RUN_SUMMARY_FILE:
        if schema_version == 6:
            return SCHEMA_V6_SUMMARY_COLUMNS
        if schema_version == 7:
            return SCHEMA_V7_SUMMARY_COLUMNS
        return SUMMARY_COLUMNS
    raise ValueError(f"Unknown Phase 1 file: {filename}")


def expected_column_variants_for(
    filename: str,
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
) -> tuple[tuple[str, ...], ...]:
    """Return acceptable TSV headers for an export file."""
    if filename == SIGNAL_OUTCOMES_FILE:
        if schema_version == 6:
            return (SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH,)
        if schema_version == 7:
            return (SCHEMA_V7_OUTCOME_COLUMNS_WITH_PATH,)
        return (OUTCOME_COLUMNS, OUTCOME_COLUMNS_WITH_PATH)
    return (expected_columns_for(filename, schema_version),)
