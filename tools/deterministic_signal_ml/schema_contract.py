"""Strict schema V11 contract for pivot trial-matrix research exports."""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


SUPPORTED_SCHEMA_VERSION = 11
SUPPORTED_ENGINE_LABEL = "PIVOT_FRACTAL_V2"
SUPPORTED_FEATURE_SET_ID = "schema_v11_pivot_trial_matrix"
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
PIVOT_WINDOWS_FILE = "pivot_windows.tsv"
SIGNAL_ORIGINS_FILE = "signal_origins.tsv"
VIRTUAL_TRIALS_FILE = "virtual_trials.tsv"
VIRTUAL_OUTCOMES_FILE = "virtual_outcomes.tsv"
EXECUTION_CHECKS_FILE = "execution_checks.tsv"
BROKER_OUTCOMES_FILE = "broker_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"

RUN_FILES = (
    RUN_MANIFEST_FILE,
    PIVOT_WINDOWS_FILE,
    SIGNAL_ORIGINS_FILE,
    VIRTUAL_TRIALS_FILE,
    VIRTUAL_OUTCOMES_FILE,
    EXECUTION_CHECKS_FILE,
    BROKER_OUTCOMES_FILE,
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

SIGNAL_ORIGIN_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "origin_id",
    "window_id",
    "broker_signal_id",
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
    "trade_tick_size",
    "stops_level_points",
    "freeze_level_points",
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
    "pivot_raw_price",
    "pivot_trade_price",
    "next_outward_pivot_price",
    "structural_entry_price",
    "structural_sl_price",
    "structural_take_profit",
    "origin_micro_band_base_0",
    "origin_micro_band_upper_0",
    "origin_micro_band_lower_0",
    "origin_micro_band_width_0",
    "origin_micro_band_width_percent_0",
    *(f"origin_micro_b_percent_{shift}" for shift in range(6)),
    *(f"origin_macro_pivot_b_percent_{shift}" for shift in range(6)),
    "origin_micro_features_complete",
    "origin_macro_features_complete",
    "origin_feature_snapshot_complete",
    "origin_feature_invalid_reason",
    "identity_consumed",
    "matrix_declared",
    "broker_attempt_status",
    "origin_expiry_broker_time",
    "origin_expiry_analysis_time",
    "origin_expiry_offset_minutes",
    "origin_terminal_status",
)

VIRTUAL_TRIAL_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "trial_id",
    "parity_trial_id",
    "policy_id",
    "origin_id",
    "window_id",
    "broker_signal_id",
    "trial_role",
    "sl_policy",
    "tp_r_multiple",
    "reentry_index",
    "preceding_loss_count",
    "level_id",
    "direction",
    "declared_broker_time",
    "declared_analysis_time",
    "declared_offset_minutes",
    "entry_bid",
    "entry_ask",
    "entry_price",
    "entry_quote_side",
    "exit_quote_side",
    "origin_micro_band_width_0",
    "requested_risk_distance_price",
    "requested_risk_distance_points",
    "normalized_risk_ticks",
    "normalized_risk_distance_price",
    "normalized_risk_distance_points",
    "stop_loss_price",
    "take_profit_price",
    "geometry_equivalence_id",
    "spread_points",
    "point_size",
    "trade_tick_size",
    "stops_level_points",
    "freeze_level_points",
    "minimum_risk_distance_points",
    "distance_eligible",
    "boundary_price",
    "boundary_eligible",
    "lot_mode",
    "lot_strategy_size",
    "reference_balance",
    "account_currency",
    "risk_budget_amount",
    "requested_volume",
    "normalized_volume",
    "virtual_expected_stop_loss",
    "virtual_expected_take_profit",
    "virtual_expected_reward_risk_ratio",
    "virtual_money_plan_complete",
    "entry_micro_band_width_percent_0",
    "entry_macro_band_width_percent_1",
    *(f"entry_micro_b_percent_{shift}" for shift in range(6)),
    *(f"entry_macro_pivot_b_percent_{shift}" for shift in range(6)),
    "entry_feature_snapshot_complete",
    "entry_feature_invalid_reason",
    "eligibility_status",
    "ineligible_reason",
    "parent_trial_id",
    "continuation_source_outcome_id",
    "origin_window_active_at_entry",
)

VIRTUAL_OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "outcome_id",
    "trial_id",
    "parity_trial_id",
    "policy_id",
    "origin_id",
    "window_id",
    "trial_role",
    "sl_policy",
    "tp_r_multiple",
    "reentry_index",
    "direction",
    "terminal_broker_time",
    "terminal_analysis_time",
    "terminal_offset_minutes",
    "terminal_status",
    "terminal_reason",
    "threshold_price",
    "observed_exit_bid",
    "observed_exit_ask",
    "observed_exit_price",
    "exit_quote_side",
    "gap_points",
    "duration_seconds",
    "virtual_nominal_r",
    "virtual_quote_gross_profit",
    "virtual_quote_gross_r",
    "virtual_binary_eligible",
    "virtual_binary_target",
    "virtual_exclusion_reason",
    "first_touch_consistent",
    "chain_terminal",
    "chain_terminal_reason",
    "continuation_allowed",
    "continuation_reason",
    "next_reentry_index",
    "next_trial_id",
)

EXECUTION_CHECK_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "check_id",
    "origin_id",
    "broker_signal_id",
    "parity_trial_id",
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
    "trade_tick_size",
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
    "fok_supported",
    "fill_policy",
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
    "trade_action",
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
    "protection_modified",
)

BROKER_OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "broker_outcome_id",
    "origin_id",
    "broker_signal_id",
    "parity_trial_id",
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
    "broker_close_price",
    "broker_closed_volume",
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
    "broker_gross_profit",
    "broker_commission",
    "broker_swap",
    "broker_fee",
    "broker_net_profit",
    "broker_gross_budget_r",
    "broker_net_budget_r",
    "broker_gross_execution_r",
    "broker_net_execution_r",
    "broker_terminal_reason",
    "close_reason_consistent",
    "broker_binary_eligible",
    "broker_binary_target",
    "broker_exclusion_reason",
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
    "signal_origin_rows",
    "virtual_trial_rows",
    "matrix_trial_rows",
    "reentry_trial_rows",
    "parity_trial_rows",
    "virtual_active_trial_rows",
    "virtual_ineligible_feature_rows",
    "virtual_ineligible_geometry_rows",
    "virtual_ineligible_distance_rows",
    "virtual_ineligible_money_rows",
    "virtual_outcome_rows",
    "matrix_tp_rows",
    "matrix_sl_rows",
    "matrix_censored_rows",
    "parity_outcome_rows",
    "execution_check_rows",
    "broker_outcome_rows",
    "broker_binary_eligible_rows",
    "broker_binary_tp_rows",
    "broker_binary_sl_rows",
    "broker_excluded_rows",
    "parity_pair_rows",
    "parity_terminal_match_rows",
    "parity_terminal_mismatch_rows",
    "parity_excluded_rows",
    "chain_tp_complete_rows",
    "chain_structural_sl_rows",
    "chain_reentry_cap_rows",
    "chain_next_pivot_boundary_rows",
    "chain_origin_expired_rows",
    "chain_run_end_censored_rows",
    "chain_ineligible_rows",
    "active_state_peak",
    "active_state_cap",
    "state_capacity_failed",
    "duplicate_identity_count",
    "referential_integrity_error_count",
    "row_integrity_error_count",
    "export_status",
    "completion_status",
)

TABLE_COLUMNS = {
    RUN_MANIFEST_FILE: MANIFEST_COLUMNS,
    PIVOT_WINDOWS_FILE: PIVOT_WINDOW_COLUMNS,
    SIGNAL_ORIGINS_FILE: SIGNAL_ORIGIN_COLUMNS,
    VIRTUAL_TRIALS_FILE: VIRTUAL_TRIAL_COLUMNS,
    VIRTUAL_OUTCOMES_FILE: VIRTUAL_OUTCOME_COLUMNS,
    EXECUTION_CHECKS_FILE: EXECUTION_CHECK_COLUMNS,
    BROKER_OUTCOMES_FILE: BROKER_OUTCOME_COLUMNS,
    RUN_SUMMARY_FILE: SUMMARY_COLUMNS,
}

PIVOT_LEVELS = ("S3", "S2", "S1", "PP", "R1", "R2", "R3")
SUPPORT_LEVELS = ("S1", "S2", "S3")
RESISTANCE_LEVELS = ("R1", "R2", "R3")
BAND_SHIFTS = tuple(range(6))
SL_POLICIES = ("STRUCTURAL", "MICRO_BW_13", "MICRO_BW_21", "MICRO_BW_34")
VOLATILITY_SL_POLICIES = SL_POLICIES[1:]
SL_POLICY_RATIOS = {
    "MICRO_BW_13": 0.13,
    "MICRO_BW_21": 0.21,
    "MICRO_BW_34": 0.34,
}
TP_R_MULTIPLES = (1, 2, 3, 5)
MAX_REENTRY_INDEX = 3
INITIAL_MATRIX_SIZE = len(SL_POLICIES) * len(TP_R_MULTIPLES)
MAX_MATRIX_TRIALS_PER_ORIGIN = len(TP_R_MULTIPLES) + (
    len(VOLATILITY_SL_POLICIES) * len(TP_R_MULTIPLES) * (MAX_REENTRY_INDEX + 1)
)
ACTIVE_STATE_CAP = 2048

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
    "sl_policy",
    "analysis_weekday",
    "analysis_session",
)
NUMERIC_FEATURE_COLUMNS = (
    "tp_r_multiple",
    "reentry_index",
    "preceding_loss_count",
    "origin_micro_band_width_0",
    "entry_micro_band_width_percent_0",
    "entry_macro_band_width_percent_1",
    *(f"entry_micro_b_percent_{shift}" for shift in BAND_SHIFTS),
    *(f"entry_macro_pivot_b_percent_{shift}" for shift in BAND_SHIFTS),
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
    "window_id",
    "origin_id",
    "policy_id",
    "trial_id",
    "symbol",
    "macro_timeframe",
    "micro_timeframe",
    "active_bar_open_broker_time",
    "level_id",
    "direction",
    "sl_policy",
    "tp_r_multiple",
    "reentry_index",
    "declared_broker_time",
)
TARGET_COLUMNS = (
    "virtual_binary_target",
    "terminal_status",
    "virtual_nominal_r",
    "virtual_quote_gross_profit",
    "virtual_quote_gross_r",
)
AUDIT_COLUMNS = (
    "entry_bid",
    "entry_ask",
    "entry_price",
    "stop_loss_price",
    "take_profit_price",
    "minimum_risk_distance_points",
    "eligibility_status",
    "ineligible_reason",
    "threshold_price",
    "observed_exit_price",
    "gap_points",
    "chain_terminal_reason",
)
FUTURE_ONLY_COLUMNS = (
    "outcome_id",
    "terminal_broker_time",
    "terminal_status",
    "terminal_reason",
    "threshold_price",
    "observed_exit_bid",
    "observed_exit_ask",
    "observed_exit_price",
    "gap_points",
    "duration_seconds",
    "virtual_nominal_r",
    "virtual_quote_gross_profit",
    "virtual_quote_gross_r",
    "virtual_binary_eligible",
    "virtual_binary_target",
    "virtual_exclusion_reason",
    "chain_terminal",
    "chain_terminal_reason",
    "continuation_allowed",
    "continuation_reason",
    "next_reentry_index",
    "next_trial_id",
    "broker_attempt_status",
    "broker_entry_price",
    "broker_close_price",
    "broker_gross_profit",
    "broker_commission",
    "broker_swap",
    "broker_fee",
    "broker_net_profit",
    "broker_binary_target",
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
    "matrix_sl_policies",
    "matrix_sl_ratios",
    "matrix_tp_multiples",
    "reentry_max_index",
    "minimum_distance_policy",
    "active_state_cap",
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
    "origin_identity_policy",
    "trigger_policy",
    "pp_policy",
    "real_execution_policy",
    "matrix_mode",
    "matrix_sl_policies",
    "matrix_sl_ratios",
    "matrix_tp_multiples",
    "origin_width_policy",
    "reentry_policy",
    "reentry_max_index",
    "boundary_policy",
    "entry_quote_policy",
    "exit_quote_policy",
    "minimum_distance_policy",
    "active_state_cap",
    "capacity_failure_policy",
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
    "virtual_money_policy",
    "broker_money_policy",
    "virtual_outcome_policy",
    "virtual_binary_cohort_policy",
    "broker_binary_cohort_policy",
    "parity_policy",
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
    "origin_identity_policy": "symbol,macro_timeframe,active_bar_open,level_first_trigger_once",
    "trigger_policy": "live_bid_virtual_limit_support_buy_resistance_sell",
    "pp_policy": "first_causal_bid_side_then_return_touch",
    "real_execution_policy": "single_structural_sl_fresh_quote_1r_fok_immutable",
    "matrix_mode": "export_enabled_virtual_trials_only",
    "matrix_sl_policies": "STRUCTURAL,MICRO_BW_13,MICRO_BW_21,MICRO_BW_34",
    "matrix_sl_ratios": "0.13,0.21,0.34",
    "matrix_tp_multiples": "1,2,3,5",
    "origin_width_policy": "micro_bands_shift_0_full_width_frozen_per_origin",
    "reentry_policy": "sl_first_same_policy_fresh_quote_frozen_width_one_generation_per_tick",
    "reentry_max_index": "3",
    "boundary_policy": "entry_and_sl_strictly_inside_next_outward_pivot_by_one_trade_tick",
    "entry_quote_policy": "buy_ask_sell_bid",
    "exit_quote_policy": "buy_bid_sell_ask",
    "minimum_distance_policy": "risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick",
    "active_state_cap": "2048",
    "capacity_failure_policy": "invalidate_research_stop_new_declarations_keep_active_and_broker_lanes",
    "bands_period": "21",
    "bands_deviation": "2.0000",
    "bands_shift": "0",
    "bands_ma_method": "MODE_SMA",
    "bands_applied_price": "PRICE_WEIGHTED",
    "reference_balance": "1000000.00000000",
    "volume_normalization_policy": "normalize_down_block_below_minimum",
    "virtual_money_policy": "order_calc_profit_counterfactual_gross_only_no_costs_or_net",
    "broker_money_policy": "deal_history_authoritative_gross_commission_swap_fee_net",
    "virtual_outcome_policy": "tp_first_sl_first_or_censored_from_causal_executable_quote",
    "virtual_binary_cohort_policy": "entry_feature_complete_eligible_tp_or_sl_only",
    "broker_binary_cohort_policy": "feature_complete_consistent_broker_tp_or_sl_only",
    "parity_policy": "accepted_request_geometry_shadow_trade_session_observed_broker_terminal_censored_calibration_only_not_matrix_or_ml",
    "time_policy": "broker_time_causal_analysis_time_export_only",
    "feature_set_id": SUPPORTED_FEATURE_SET_ID,
    "research_approval_state": "OFFLINE_RESEARCH_ONLY",
}


class SchemaValidationError(RuntimeError):
    """Raised when a run violates the strict V11 export contract."""


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
    def signal_origin_rows(self) -> int:
        return self.row_counts[SIGNAL_ORIGINS_FILE]

    @property
    def virtual_trial_rows(self) -> int:
        return self.row_counts[VIRTUAL_TRIALS_FILE]

    @property
    def virtual_outcome_rows(self) -> int:
        return self.row_counts[VIRTUAL_OUTCOMES_FILE]

    @property
    def execution_check_rows(self) -> int:
        return self.row_counts[EXECUTION_CHECKS_FILE]

    @property
    def broker_outcome_rows(self) -> int:
        return self.row_counts[BROKER_OUTCOMES_FILE]


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
        raise ValueError(f"Unknown schema V11 file: {filename}") from exc


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
        raise SchemaValidationError(f"{context}: invalid integer {column}={value!r}") from exc


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
        raise SchemaValidationError(f"{context}: invalid number {column}={value!r}") from exc
    if not math.isfinite(number):
        raise SchemaValidationError(f"{context}: non-finite number {column}={value!r}")
    return number


def _as_bool(row: dict[str, str], column: str, context: str) -> bool:
    value = _require_value(row, column, context)
    if value not in ("0", "1"):
        raise SchemaValidationError(f"{context}: invalid boolean {column}={value!r}")
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
        raise SchemaValidationError(f"{context}: invalid timestamp {column}={value!r}") from exc


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
    if nullable and null_count == 3:
        return None, None, None
    if null_count:
        raise SchemaValidationError(f"{context}: partial time triplet for {broker_column}")
    broker_time = _as_time(row, broker_column, context)
    analysis_time = _as_time(row, analysis_column, context)
    offset = _as_int(row, offset_column, context)
    assert broker_time is not None and analysis_time is not None and offset is not None
    if analysis_time != broker_time + timedelta(minutes=offset):
        raise SchemaValidationError(f"{context}: analysis time/offset mismatch")
    return broker_time, analysis_time, offset


def _read_tsv(path: Path, expected_columns: tuple[str, ...]) -> list[dict[str, str]]:
    if not path.is_file():
        raise SchemaValidationError(f"Missing required schema V11 file: {path}")
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
            "Run must contain exactly eight V11 TSV files; "
            f"missing={missing}, unexpected={unexpected}"
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
                raise SchemaValidationError(
                    f"{context}: classic pivot formula mismatch for {level_id}"
                )
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
        expected_relation = (
            "ABOVE" if first_bid > trade_pp else "BELOW" if first_bid < trade_pp else "EQUAL"
        )
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
            if arm_time is not None or arm_bid is not None or relation != "EQUAL":
                raise SchemaValidationError(f"{context}: invalid unarmed PP facts")
        else:
            if arm_time is None or arm_bid is None or not first_time <= arm_time < terminal:
                raise SchemaValidationError(f"{context}: armed PP lacks causal arm facts")
            if role == "BUY" and arm_bid <= trade_pp:
                raise SchemaValidationError(f"{context}: BUY PP must arm from above")
            if role == "SELL" and arm_bid >= trade_pp:
                raise SchemaValidationError(f"{context}: SELL PP must arm from below")

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
        elif _is_null(row["macro_band_invalid_reason"]):
            raise SchemaValidationError(f"{context}: incomplete Macro bands lack invalid reason")
        if row["window_state"] != "VALID" or not _is_null(row["invalid_reason"]):
            raise SchemaValidationError(f"{context}: exported window is not valid")
        if row["terminal_status"] not in ("EXPIRED", "RUN_FINISHED"):
            raise SchemaValidationError(f"{context}: invalid window terminal status")
        windows[window_id] = row
    return windows


def _structural_stop(window: dict[str, str], level_id: str, direction: str) -> float:
    def price(level: str) -> float:
        return float(window[_level_column("trade", level)])

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


def _next_outward_pivot(window: dict[str, str], level_id: str, direction: str) -> float | None:
    mapping = {
        ("BUY", "PP"): "S1",
        ("BUY", "S1"): "S2",
        ("BUY", "S2"): "S3",
        ("SELL", "PP"): "R1",
        ("SELL", "R1"): "R2",
        ("SELL", "R2"): "R3",
    }
    boundary_level = mapping.get((direction, level_id))
    return None if boundary_level is None else float(window[_level_column("trade", boundary_level)])


def _validate_origins(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    windows: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    origins: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str, str]] = set()
    broker_signal_ids: set[str] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_ORIGINS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        origin_id = _require_value(row, "origin_id", context)
        if origin_id in origins:
            raise SchemaValidationError(f"Duplicate origin_id: {origin_id}")
        window_id = _require_value(row, "window_id", context)
        try:
            window = windows[window_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: origin references unknown window") from exc
        for column, manifest_key in (
            ("symbol", "symbol"),
            ("macro_timeframe", "macro_timeframe"),
            ("micro_timeframe", "micro_timeframe"),
        ):
            if row[column] != manifest[manifest_key]:
                raise SchemaValidationError(f"{context}: {column} differs from manifest")
        if row["active_bar_open_broker_time"] != window["active_bar_open_broker_time"]:
            raise SchemaValidationError(f"{context}: origin active bar differs from window")
        level_id = row["level_id"]
        direction = row["direction"]
        if level_id not in PIVOT_LEVELS or direction not in ("BUY", "SELL"):
            raise SchemaValidationError(f"{context}: invalid pivot level/direction")
        if level_id in SUPPORT_LEVELS and direction != "BUY":
            raise SchemaValidationError(f"{context}: support origin must be BUY")
        if level_id in RESISTANCE_LEVELS and direction != "SELL":
            raise SchemaValidationError(f"{context}: resistance origin must be SELL")
        identity = (
            row["symbol"],
            row["macro_timeframe"],
            row["active_bar_open_broker_time"],
            level_id,
        )
        if identity in identities:
            raise SchemaValidationError(f"{context}: duplicate consumed pivot identity")
        identities.add(identity)

        trigger_time, _, _ = _validate_time_triplet(
            row,
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
            context,
        )
        expiry_time, _, _ = _validate_time_triplet(
            row,
            "origin_expiry_broker_time",
            "origin_expiry_analysis_time",
            "origin_expiry_offset_minutes",
            context,
        )
        active_time = _as_time(window, "active_bar_open_broker_time", context)
        terminal_time = _as_time(window, "terminal_broker_time", context)
        assert trigger_time is not None and expiry_time is not None
        assert active_time is not None and terminal_time is not None
        if not active_time <= trigger_time < expiry_time or expiry_time != terminal_time:
            raise SchemaValidationError(f"{context}: origin times are outside its Macro window")
        bid = _as_float(row, "trigger_bid", context)
        ask = _as_float(row, "trigger_ask", context)
        point = _as_float(row, "point_size", context)
        tick = _as_float(row, "trade_tick_size", context)
        spread = _as_float(row, "spread_points", context)
        stops = _as_float(row, "stops_level_points", context)
        freeze = _as_float(row, "freeze_level_points", context)
        assert None not in (bid, ask, point, tick, spread, stops, freeze)
        if bid <= 0.0 or ask < bid or point <= 0.0 or tick <= 0.0 or stops < 0.0 or freeze < 0.0:
            raise SchemaValidationError(f"{context}: invalid origin broker facts")
        if not _same_number(spread, (ask - bid) / point):
            raise SchemaValidationError(f"{context}: origin spread arithmetic mismatch")

        for level in PIVOT_LEVELS:
            for prefix in ("raw", "trade"):
                column = _level_column(prefix, level)
                if not _same_number(float(row[column]), float(window[column])):
                    raise SchemaValidationError(f"{context}: origin pivot ladder differs from window")
        pivot_raw = _as_float(row, "pivot_raw_price", context)
        pivot_trade = _as_float(row, "pivot_trade_price", context)
        assert pivot_raw is not None and pivot_trade is not None
        if not _same_number(pivot_raw, float(window[_level_column("raw", level_id)])):
            raise SchemaValidationError(f"{context}: pivot_raw_price mismatch")
        if not _same_number(pivot_trade, float(window[_level_column("trade", level_id)])):
            raise SchemaValidationError(f"{context}: pivot_trade_price mismatch")
        expected_boundary = _next_outward_pivot(window, level_id, direction)
        actual_boundary = _as_float(row, "next_outward_pivot_price", context, nullable=True)
        if (expected_boundary is None) != (actual_boundary is None) or (
            expected_boundary is not None
            and actual_boundary is not None
            and not _same_number(expected_boundary, actual_boundary)
        ):
            raise SchemaValidationError(f"{context}: next outward pivot boundary mismatch")

        entry = _as_float(row, "structural_entry_price", context)
        stop = _as_float(row, "structural_sl_price", context)
        take_profit = _as_float(row, "structural_take_profit", context)
        assert entry is not None and stop is not None and take_profit is not None
        if entry <= 0.0 or stop <= 0.0 or take_profit <= 0.0:
            raise SchemaValidationError(f"{context}: invalid structural route price")
        expected_entry = ask if direction == "BUY" else bid
        expected_stop = _structural_stop(window, level_id, direction)
        expected_tp = (
            expected_entry + (expected_entry - expected_stop)
            if direction == "BUY"
            else expected_entry - (expected_stop - expected_entry)
        )
        if not _same_number(entry, expected_entry) or not _same_number(stop, expected_stop):
            raise SchemaValidationError(f"{context}: structural route mismatch")
        if not _same_number(take_profit, expected_tp):
            raise SchemaValidationError(f"{context}: structural 1R TP mismatch")

        micro_complete = _as_bool(row, "origin_micro_features_complete", context)
        macro_complete = _as_bool(row, "origin_macro_features_complete", context)
        snapshot_complete = _as_bool(row, "origin_feature_snapshot_complete", context)
        if snapshot_complete != (micro_complete and macro_complete):
            raise SchemaValidationError(f"{context}: origin feature completeness mismatch")
        micro_band_columns = (
            "origin_micro_band_base_0",
            "origin_micro_band_upper_0",
            "origin_micro_band_lower_0",
            "origin_micro_band_width_0",
            "origin_micro_band_width_percent_0",
        )
        if micro_complete:
            _validate_band_width(row, *micro_band_columns, context)
            for shift in BAND_SHIFTS:
                _as_float(row, f"origin_micro_b_percent_{shift}", context)
        elif any(not _is_null(row[column]) for column in micro_band_columns):
            raise SchemaValidationError(f"{context}: incomplete Micro features carry band values")
        if macro_complete:
            for shift in BAND_SHIFTS:
                _as_float(row, f"origin_macro_pivot_b_percent_{shift}", context)
        if snapshot_complete and not _is_null(row["origin_feature_invalid_reason"]):
            raise SchemaValidationError(f"{context}: complete origin features have invalid reason")
        if not snapshot_complete and _is_null(row["origin_feature_invalid_reason"]):
            raise SchemaValidationError(f"{context}: incomplete origin features lack invalid reason")
        if not _as_bool(row, "identity_consumed", context):
            raise SchemaValidationError(f"{context}: origin identity was not consumed")
        _as_bool(row, "matrix_declared", context)
        broker_status = row["broker_attempt_status"]
        if broker_status not in (
            "NOT_EVALUATED",
            "BLOCKED",
            "SEND_FAILED",
            "SENT",
            "FILLED",
            "CLOSED",
            "CENSORED",
        ):
            raise SchemaValidationError(f"{context}: invalid broker attempt status")
        broker_signal_id = row["broker_signal_id"]
        if broker_status == "NOT_EVALUATED":
            if not _is_null(broker_signal_id):
                raise SchemaValidationError(f"{context}: unevaluated origin has broker_signal_id")
        else:
            broker_signal_id = _require_value(row, "broker_signal_id", context)
            if broker_signal_id in broker_signal_ids:
                raise SchemaValidationError(f"{context}: duplicate broker_signal_id")
            broker_signal_ids.add(broker_signal_id)
        if row["origin_terminal_status"] not in ("WINDOW_EXPIRED", "RUN_FINISHED"):
            raise SchemaValidationError(f"{context}: invalid origin terminal status")
        origins[origin_id] = row
    return origins


def _require_numeric_group(
    row: dict[str, str],
    columns: tuple[str, ...],
    context: str,
    *,
    required: bool,
) -> None:
    null_count = sum(_is_null(row[column]) for column in columns)
    if required and null_count:
        raise SchemaValidationError(f"{context}: required numeric field group is incomplete")
    if not required and null_count not in (0, len(columns)):
        raise SchemaValidationError(f"{context}: optional numeric field group is partial")
    if null_count == 0:
        for column in columns:
            _as_float(row, column, context)


def _validate_trial_entry_features(row: dict[str, str], context: str) -> None:
    feature_columns = (
        "entry_micro_band_width_percent_0",
        "entry_macro_band_width_percent_1",
        *(f"entry_micro_b_percent_{shift}" for shift in BAND_SHIFTS),
        *(f"entry_macro_pivot_b_percent_{shift}" for shift in BAND_SHIFTS),
    )
    complete = _as_bool(row, "entry_feature_snapshot_complete", context)
    _require_numeric_group(row, feature_columns, context, required=complete)
    if complete and not _is_null(row["entry_feature_invalid_reason"]):
        raise SchemaValidationError(f"{context}: complete entry features have invalid reason")
    if not complete and _is_null(row["entry_feature_invalid_reason"]):
        raise SchemaValidationError(f"{context}: incomplete entry features lack invalid reason")


def _validate_trial_geometry(
    row: dict[str, str],
    origin: dict[str, str],
    context: str,
    *,
    matrix_policy: bool,
) -> None:
    entry = _as_float(row, "entry_price", context)
    bid = _as_float(row, "entry_bid", context)
    ask = _as_float(row, "entry_ask", context)
    point = _as_float(row, "point_size", context)
    tick = _as_float(row, "trade_tick_size", context)
    spread = _as_float(row, "spread_points", context)
    stops = _as_float(row, "stops_level_points", context)
    freeze = _as_float(row, "freeze_level_points", context)
    assert None not in (entry, bid, ask, point, tick, spread, stops, freeze)
    if bid <= 0.0 or ask < bid or point <= 0.0 or tick <= 0.0 or stops < 0.0 or freeze < 0.0:
        raise SchemaValidationError(f"{context}: invalid trial broker facts")
    if not _same_number(spread, (ask - bid) / point):
        raise SchemaValidationError(f"{context}: trial spread arithmetic mismatch")
    direction = row["direction"]
    expected_entry_side = "ASK" if direction == "BUY" else "BID"
    expected_exit_side = "BID" if direction == "BUY" else "ASK"
    expected_entry = ask if direction == "BUY" else bid
    if row["entry_quote_side"] != expected_entry_side:
        raise SchemaValidationError(f"{context}: wrong executable entry quote side")
    if row["exit_quote_side"] != expected_exit_side:
        raise SchemaValidationError(f"{context}: wrong executable exit quote side")
    if not _same_number(entry, expected_entry):
        raise SchemaValidationError(f"{context}: entry price differs from executable quote")

    geometry_columns = (
        "requested_risk_distance_price",
        "requested_risk_distance_points",
        "normalized_risk_ticks",
        "normalized_risk_distance_price",
        "normalized_risk_distance_points",
        "stop_loss_price",
        "take_profit_price",
        "minimum_risk_distance_points",
    )
    eligibility = row["eligibility_status"]
    geometry_available = eligibility not in ("INELIGIBLE_FEATURE", "INELIGIBLE_GEOMETRY")
    if not geometry_available:
        if any(not _is_null(row[column]) for column in geometry_columns) or not _is_null(
            row["geometry_equivalence_id"]
        ):
            raise SchemaValidationError(f"{context}: unavailable geometry carries values")
        return
    _require_numeric_group(row, geometry_columns, context, required=True)

    requested_price = _as_float(row, "requested_risk_distance_price", context)
    requested_points = _as_float(row, "requested_risk_distance_points", context)
    normalized_ticks = _as_int(row, "normalized_risk_ticks", context)
    normalized_price = _as_float(row, "normalized_risk_distance_price", context)
    normalized_points = _as_float(row, "normalized_risk_distance_points", context)
    stop = _as_float(row, "stop_loss_price", context)
    take_profit = _as_float(row, "take_profit_price", context)
    minimum_points = _as_float(row, "minimum_risk_distance_points", context)
    assert None not in (
        requested_price,
        requested_points,
        normalized_ticks,
        normalized_price,
        normalized_points,
        stop,
        take_profit,
        minimum_points,
    )
    if requested_price <= 0.0 or normalized_ticks <= 0:
        raise SchemaValidationError(f"{context}: nonpositive trial risk")
    if not _same_number(requested_points, requested_price / point):
        raise SchemaValidationError(f"{context}: requested risk point conversion mismatch")
    if not _same_number(normalized_price, normalized_ticks * tick):
        raise SchemaValidationError(f"{context}: normalized tick risk mismatch")
    if normalized_price + 1e-10 < requested_price:
        raise SchemaValidationError(f"{context}: normalization shrank requested risk")
    if not _same_number(normalized_points, normalized_price / point):
        raise SchemaValidationError(f"{context}: normalized risk point conversion mismatch")
    trade_tick_points = tick / point
    expected_minimum = spread + max(stops, freeze) + trade_tick_points
    if not _same_number(minimum_points, expected_minimum):
        raise SchemaValidationError(f"{context}: minimum distance formula mismatch")
    distance_eligible = _as_bool(row, "distance_eligible", context)
    if distance_eligible != (normalized_points + 1e-7 >= minimum_points):
        raise SchemaValidationError(f"{context}: distance eligibility mismatch")
    expected_stop = entry - normalized_price if direction == "BUY" else entry + normalized_price
    if not _same_number(stop, expected_stop):
        raise SchemaValidationError(f"{context}: directionally normalized SL mismatch")
    if matrix_policy:
        tp_multiple = _as_int(row, "tp_r_multiple", context)
        assert tp_multiple is not None
        expected_tp = (
            entry + normalized_price * tp_multiple
            if direction == "BUY"
            else entry - normalized_price * tp_multiple
        )
        if not _same_number(take_profit, expected_tp):
            raise SchemaValidationError(f"{context}: exact integer-R TP mismatch")
    elif not ((direction == "BUY" and take_profit > entry > stop) or (
        direction == "SELL" and take_profit < entry < stop
    )):
        raise SchemaValidationError(f"{context}: invalid parity geometry")
    _require_value(row, "geometry_equivalence_id", context)

    boundary = _as_float(row, "boundary_price", context, nullable=True)
    expected_boundary = _as_float(origin, "next_outward_pivot_price", context, nullable=True)
    if (boundary is None) != (expected_boundary is None) or (
        boundary is not None
        and expected_boundary is not None
        and not _same_number(boundary, expected_boundary)
    ):
        raise SchemaValidationError(f"{context}: trial boundary differs from origin")
    boundary_eligible = _as_bool(row, "boundary_eligible", context)
    reentry_index = _as_int(row, "reentry_index", context)
    assert reentry_index is not None
    expected_boundary_eligible = True
    if matrix_policy and reentry_index > 0 and boundary is not None:
        if direction == "BUY":
            expected_boundary_eligible = entry > boundary + tick and stop > boundary + tick
        else:
            expected_boundary_eligible = entry < boundary - tick and stop < boundary - tick
    if boundary_eligible != expected_boundary_eligible:
        raise SchemaValidationError(f"{context}: next-pivot boundary eligibility mismatch")


def _validate_trials(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    origins: dict[str, dict[str, str]],
) -> tuple[
    dict[str, dict[str, str]],
    dict[tuple[str, str, int], list[dict[str, str]]],
    dict[str, dict[str, str]],
]:
    trials: dict[str, dict[str, str]] = {}
    policy_chains: dict[tuple[str, str, int], list[dict[str, str]]] = defaultdict(list)
    parity_trials: dict[str, dict[str, str]] = {}
    policy_ids: dict[tuple[str, str, int], str] = {}
    matrix_identities: set[tuple[str, str, int, int]] = set()
    initial_matrix_order: dict[str, list[tuple[str, int]]] = defaultdict(list)
    matrix_trial_counts: dict[str, int] = defaultdict(int)
    for row_index, row in enumerate(rows, start=2):
        context = f"{VIRTUAL_TRIALS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        trial_id = _require_value(row, "trial_id", context)
        if trial_id in trials:
            raise SchemaValidationError(f"Duplicate trial_id: {trial_id}")
        origin_id = _require_value(row, "origin_id", context)
        try:
            origin = origins[origin_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: trial references unknown origin") from exc
        if row["window_id"] != origin["window_id"]:
            raise SchemaValidationError(f"{context}: trial window differs from origin")
        if row["level_id"] != origin["level_id"] or row["direction"] != origin["direction"]:
            raise SchemaValidationError(f"{context}: trial pivot role differs from origin")
        declared_time, _, _ = _validate_time_triplet(
            row,
            "declared_broker_time",
            "declared_analysis_time",
            "declared_offset_minutes",
            context,
        )
        trigger_time = _as_time(origin, "trigger_broker_time", context)
        expiry_time = _as_time(origin, "origin_expiry_broker_time", context)
        assert declared_time is not None and trigger_time is not None and expiry_time is not None
        role = row["trial_role"]
        if role not in ("MATRIX", "BROKER_PARITY"):
            raise SchemaValidationError(f"{context}: invalid trial role")
        if declared_time < trigger_time:
            raise SchemaValidationError(f"{context}: trial declaration precedes origin trigger")
        origin_window_active = _as_bool(row, "origin_window_active_at_entry", context)
        expected_origin_window_active = declared_time < expiry_time
        if role == "MATRIX":
            if not expected_origin_window_active:
                raise SchemaValidationError(f"{context}: trial declaration is outside origin lifetime")
            if not origin_window_active:
                raise SchemaValidationError(f"{context}: trial declared from expired origin")
        elif origin_window_active != expected_origin_window_active:
            raise SchemaValidationError(f"{context}: broker parity origin-window flag mismatch")

        reentry_index = _as_int(row, "reentry_index", context)
        preceding_losses = _as_int(row, "preceding_loss_count", context)
        assert reentry_index is not None and preceding_losses is not None
        if not 0 <= reentry_index <= MAX_REENTRY_INDEX or preceding_losses != reentry_index:
            raise SchemaValidationError(f"{context}: invalid retry index or preceding-loss count")
        _validate_trial_entry_features(row, context)
        eligibility = row["eligibility_status"]
        if eligibility not in (
            "ACTIVE",
            "INELIGIBLE_FEATURE",
            "INELIGIBLE_GEOMETRY",
            "INELIGIBLE_DISTANCE",
            "INELIGIBLE_MONEY_PLAN",
        ):
            raise SchemaValidationError(f"{context}: invalid eligibility status")
        if eligibility == "ACTIVE":
            if not _is_null(row["ineligible_reason"]):
                raise SchemaValidationError(f"{context}: active trial has ineligible reason")
        elif _is_null(row["ineligible_reason"]):
            raise SchemaValidationError(f"{context}: ineligible trial lacks reason")

        if row["lot_mode"] != manifest["lot_mode"]:
            raise SchemaValidationError(f"{context}: trial lot mode differs from manifest")
        lot_size = _as_float(row, "lot_strategy_size", context)
        assert lot_size is not None
        if not _same_number(lot_size, float(manifest["lot_strategy_size"])):
            raise SchemaValidationError(f"{context}: trial lot size differs from manifest")
        if row["account_currency"] != manifest["account_currency"]:
            raise SchemaValidationError(f"{context}: account currency differs from manifest")
        if manifest["lot_mode"] == REFERENCE_LOT_MODE:
            reference_balance = _as_float(row, "reference_balance", context)
            assert reference_balance is not None
            if not _same_number(reference_balance, REFERENCE_BALANCE):
                raise SchemaValidationError(f"{context}: reference balance mismatch")
        elif not _is_null(row["reference_balance"]):
            raise SchemaValidationError(f"{context}: fixed-lot trial carries reference balance")

        if role == "MATRIX":
            if not _is_null(row["parity_trial_id"]) or not _is_null(row["broker_signal_id"]):
                raise SchemaValidationError(f"{context}: matrix trial carries parity/broker identity")
            policy_id = _require_value(row, "policy_id", context)
            sl_policy = row["sl_policy"]
            tp_multiple = _as_int(row, "tp_r_multiple", context)
            assert tp_multiple is not None
            if sl_policy not in SL_POLICIES or tp_multiple not in TP_R_MULTIPLES:
                raise SchemaValidationError(f"{context}: invalid matrix SL/TP policy")
            if sl_policy == "STRUCTURAL" and reentry_index != 0:
                raise SchemaValidationError(f"{context}: structural policy cannot re-enter")
            identity = (origin_id, sl_policy, tp_multiple, reentry_index)
            if identity in matrix_identities:
                raise SchemaValidationError(f"{context}: duplicate matrix policy/retry identity")
            matrix_identities.add(identity)
            policy_key = (origin_id, sl_policy, tp_multiple)
            if policy_key in policy_ids and policy_ids[policy_key] != policy_id:
                raise SchemaValidationError(f"{context}: policy_id changed across retries")
            policy_ids[policy_key] = policy_id
            matrix_trial_counts[origin_id] += 1
            if reentry_index == 0:
                initial_matrix_order[origin_id].append((sl_policy, tp_multiple))
                if declared_time != trigger_time:
                    raise SchemaValidationError(f"{context}: initial matrix trial not declared on origin tick")
                if not _is_null(row["parent_trial_id"]) or not _is_null(
                    row["continuation_source_outcome_id"]
                ):
                    raise SchemaValidationError(f"{context}: initial trial has retry parent")
            else:
                _require_value(row, "parent_trial_id", context)
                _require_value(row, "continuation_source_outcome_id", context)

            origin_width = _as_float(origin, "origin_micro_band_width_0", context, nullable=True)
            trial_width = _as_float(row, "origin_micro_band_width_0", context, nullable=True)
            if (origin_width is None) != (trial_width is None) or (
                origin_width is not None
                and trial_width is not None
                and not _same_number(origin_width, trial_width)
            ):
                raise SchemaValidationError(f"{context}: frozen origin width mismatch")
            if sl_policy in VOLATILITY_SL_POLICIES and origin_width is None:
                if eligibility != "INELIGIBLE_FEATURE":
                    raise SchemaValidationError(
                        f"{context}: volatility policy without origin width is not feature-ineligible"
                    )
            elif sl_policy in VOLATILITY_SL_POLICIES and eligibility == "INELIGIBLE_FEATURE":
                raise SchemaValidationError(
                    f"{context}: feature-ineligible volatility policy still has frozen origin width"
                )
            requested = _as_float(
                row, "requested_risk_distance_price", context, nullable=True
            )
            structural_route_tradable = (
                float(origin["structural_sl_price"])
                < float(origin["structural_entry_price"])
                if row["direction"] == "BUY"
                else float(origin["structural_sl_price"])
                > float(origin["structural_entry_price"])
            )
            if sl_policy == "STRUCTURAL" and not structural_route_tradable:
                if (
                    eligibility != "INELIGIBLE_GEOMETRY"
                    or row["ineligible_reason"]
                    != "STRUCTURAL_STOP_WRONG_SIDE_OF_ORIGIN_ENTRY"
                ):
                    raise SchemaValidationError(
                        f"{context}: wrong-side structural route must be geometry-ineligible"
                    )
            if requested is not None:
                expected_requested = (
                    abs(float(origin["structural_entry_price"]) - float(origin["structural_sl_price"]))
                    if sl_policy == "STRUCTURAL"
                    else float(origin["origin_micro_band_width_0"])
                    * SL_POLICY_RATIOS[sl_policy]
                )
                if not _same_number(requested, expected_requested):
                    raise SchemaValidationError(f"{context}: requested policy risk mismatch")
            _validate_trial_geometry(row, origin, context, matrix_policy=True)
            policy_chains[policy_key].append(row)
        else:
            parity_trial_id = _require_value(row, "parity_trial_id", context)
            if parity_trial_id != trial_id:
                raise SchemaValidationError(f"{context}: parity_trial_id must equal trial_id")
            broker_signal_id = _require_value(row, "broker_signal_id", context)
            if broker_signal_id != origin["broker_signal_id"]:
                raise SchemaValidationError(f"{context}: parity broker signal differs from origin")
            if not _is_null(row["policy_id"]) or not _is_null(row["sl_policy"]):
                raise SchemaValidationError(f"{context}: parity trial carries matrix policy")
            if not _is_null(row["tp_r_multiple"]):
                raise SchemaValidationError(f"{context}: parity trial carries matrix TP policy")
            if reentry_index != 0 or not _is_null(row["parent_trial_id"]) or not _is_null(
                row["continuation_source_outcome_id"]
            ):
                raise SchemaValidationError(f"{context}: parity trial cannot re-enter")
            if eligibility != "ACTIVE":
                raise SchemaValidationError(f"{context}: accepted parity shadow must be active")
            if parity_trial_id in parity_trials:
                raise SchemaValidationError(f"{context}: duplicate parity_trial_id")
            _validate_trial_geometry(row, origin, context, matrix_policy=False)
            parity_trials[parity_trial_id] = row

        distance_eligible = _as_bool(row, "distance_eligible", context)
        money_complete = _as_bool(row, "virtual_money_plan_complete", context)
        money_columns = (
            "risk_budget_amount",
            "requested_volume",
            "normalized_volume",
            "virtual_expected_stop_loss",
            "virtual_expected_take_profit",
            "virtual_expected_reward_risk_ratio",
        )
        money_required = eligibility in ("ACTIVE",)
        if money_required:
            _require_numeric_group(row, money_columns, context, required=True)
        elif any(not _is_null(row[column]) for column in money_columns):
            raise SchemaValidationError(f"{context}: ineligible trial carries money values")
        if money_complete != money_required:
            if not (eligibility == "INELIGIBLE_MONEY_PLAN" and not money_complete):
                raise SchemaValidationError(f"{context}: virtual money-plan status mismatch")
        if eligibility == "INELIGIBLE_DISTANCE" and distance_eligible:
            raise SchemaValidationError(f"{context}: distance-ineligible trial passed distance check")
        if eligibility == "ACTIVE" and not distance_eligible:
            raise SchemaValidationError(f"{context}: active trial failed distance check")
        if money_required:
            expected_stop = _as_float(row, "virtual_expected_stop_loss", context)
            expected_tp = _as_float(row, "virtual_expected_take_profit", context)
            expected_ratio = _as_float(row, "virtual_expected_reward_risk_ratio", context)
            assert expected_stop is not None and expected_tp is not None and expected_ratio is not None
            if expected_stop >= 0.0 or expected_tp <= 0.0:
                raise SchemaValidationError(f"{context}: invalid virtual gross money signs")
            if not _same_number(expected_ratio, expected_tp / abs(expected_stop)):
                raise SchemaValidationError(f"{context}: virtual money ratio mismatch")
        trials[trial_id] = row

    for origin_id, origin in origins.items():
        actual_order = initial_matrix_order.get(origin_id, [])
        if origin["matrix_declared"] == "1":
            expected_order = [(sl, tp) for sl in SL_POLICIES for tp in TP_R_MULTIPLES]
            if len(actual_order) != INITIAL_MATRIX_SIZE or actual_order != expected_order:
                raise SchemaValidationError(
                    f"Origin {origin_id} must declare exactly sixteen initial matrix cells in policy order"
                )
        elif actual_order:
            raise SchemaValidationError(f"Origin {origin_id} suppressed matrix but exported cells")
        if matrix_trial_counts.get(origin_id, 0) > MAX_MATRIX_TRIALS_PER_ORIGIN:
            raise SchemaValidationError(f"Origin {origin_id} exceeds 52 matrix trial rows")
    return trials, policy_chains, parity_trials


def _validate_virtual_outcomes(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    trials: dict[str, dict[str, str]],
    policy_chains: dict[tuple[str, str, int], list[dict[str, str]]],
    origins: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    outcomes: dict[str, dict[str, str]] = {}
    outcome_ids: set[str] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{VIRTUAL_OUTCOMES_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        outcome_id = _require_value(row, "outcome_id", context)
        if outcome_id in outcome_ids:
            raise SchemaValidationError(f"Duplicate outcome_id: {outcome_id}")
        outcome_ids.add(outcome_id)
        trial_id = _require_value(row, "trial_id", context)
        try:
            trial = trials[trial_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: outcome references unknown trial") from exc
        if trial_id in outcomes:
            raise SchemaValidationError(f"Duplicate virtual outcome for trial_id: {trial_id}")
        if trial["eligibility_status"] != "ACTIVE":
            raise SchemaValidationError(f"{context}: ineligible trial cannot have virtual outcome")
        for column in (
            "origin_id",
            "window_id",
            "trial_role",
            "direction",
            "reentry_index",
        ):
            if row[column] != trial[column]:
                raise SchemaValidationError(f"{context}: outcome changed trial identity {column}")
        for column in ("parity_trial_id", "policy_id", "sl_policy", "tp_r_multiple"):
            if row[column] != trial[column]:
                raise SchemaValidationError(f"{context}: outcome changed policy identity {column}")
        terminal_time, _, _ = _validate_time_triplet(
            row,
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_offset_minutes",
            context,
        )
        declared_time = _as_time(trial, "declared_broker_time", context)
        assert terminal_time is not None and declared_time is not None
        duration = _as_int(row, "duration_seconds", context)
        assert duration is not None
        if terminal_time <= declared_time or duration != int((terminal_time - declared_time).total_seconds()):
            raise SchemaValidationError(f"{context}: virtual outcome duration mismatch")
        status = row["terminal_status"]
        if status not in ("TP_FIRST", "SL_FIRST", "CENSORED"):
            raise SchemaValidationError(f"{context}: invalid virtual terminal status")
        expected_reason = {
            "TP_FIRST": "TP_THRESHOLD",
            "SL_FIRST": "SL_THRESHOLD",
        }.get(status)
        if status == "CENSORED":
            allowed_reasons = (
                ("RUN_END", "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH")
                if trial["trial_role"] == "BROKER_PARITY"
                else ("RUN_END",)
            )
            if row["terminal_reason"] not in allowed_reasons:
                raise SchemaValidationError(f"{context}: virtual terminal reason mismatch")
        elif row["terminal_reason"] != expected_reason:
            raise SchemaValidationError(f"{context}: virtual terminal reason mismatch")
        direction = row["direction"]
        expected_side = "BID" if direction == "BUY" else "ASK"
        if row["exit_quote_side"] != expected_side:
            raise SchemaValidationError(f"{context}: virtual outcome uses wrong exit quote side")
        exit_bid = _as_float(row, "observed_exit_bid", context)
        exit_ask = _as_float(row, "observed_exit_ask", context)
        exit_price = _as_float(row, "observed_exit_price", context)
        assert exit_bid is not None and exit_ask is not None and exit_price is not None
        if exit_ask < exit_bid:
            raise SchemaValidationError(f"{context}: invalid terminal quote")
        expected_exit = exit_bid if direction == "BUY" else exit_ask
        if not _same_number(exit_price, expected_exit):
            raise SchemaValidationError(f"{context}: observed exit differs from executable side")
        point = float(trial["point_size"])
        if status == "CENSORED":
            for column in (
                "threshold_price",
                "gap_points",
                "virtual_nominal_r",
                "virtual_quote_gross_profit",
                "virtual_quote_gross_r",
                "virtual_binary_target",
            ):
                if not _is_null(row[column]):
                    raise SchemaValidationError(f"{context}: censored outcome carries {column}")
        else:
            threshold = _as_float(row, "threshold_price", context)
            gap_points = _as_float(row, "gap_points", context)
            nominal_r = _as_float(row, "virtual_nominal_r", context)
            gross_profit = _as_float(row, "virtual_quote_gross_profit", context)
            gross_r = _as_float(row, "virtual_quote_gross_r", context)
            assert None not in (threshold, gap_points, nominal_r, gross_profit, gross_r)
            expected_threshold = float(
                trial["take_profit_price"] if status == "TP_FIRST" else trial["stop_loss_price"]
            )
            if not _same_number(threshold, expected_threshold):
                raise SchemaValidationError(f"{context}: first-touch threshold mismatch")
            if not _same_number(gap_points, abs(exit_price - threshold) / point):
                raise SchemaValidationError(f"{context}: virtual gap arithmetic mismatch")
            if trial["trial_role"] == "MATRIX":
                expected_nominal = (
                    float(trial["tp_r_multiple"]) if status == "TP_FIRST" else -1.0
                )
            else:
                entry = float(trial["entry_price"])
                stop = float(trial["stop_loss_price"])
                take_profit = float(trial["take_profit_price"])
                expected_nominal = (
                    abs(take_profit - entry) / abs(entry - stop)
                    if status == "TP_FIRST"
                    else -1.0
                )
            if not _same_number(nominal_r, expected_nominal):
                raise SchemaValidationError(f"{context}: virtual nominal R mismatch")
            expected_loss = abs(float(trial["virtual_expected_stop_loss"]))
            if not _same_number(gross_r, gross_profit / expected_loss):
                raise SchemaValidationError(f"{context}: virtual quote gross R mismatch")
        if not _as_bool(row, "first_touch_consistent", context):
            raise SchemaValidationError(f"{context}: virtual first-touch result is inconsistent")

        binary_eligible = _as_bool(row, "virtual_binary_eligible", context)
        expected_binary = (
            trial["trial_role"] == "MATRIX"
            and trial["entry_feature_snapshot_complete"] == "1"
            and status in ("TP_FIRST", "SL_FIRST")
        )
        if binary_eligible != expected_binary:
            raise SchemaValidationError(f"{context}: virtual binary eligibility mismatch")
        binary_target = _as_int(row, "virtual_binary_target", context, nullable=True)
        if expected_binary:
            expected_target = 1 if status == "TP_FIRST" else 0
            if binary_target != expected_target or not _is_null(row["virtual_exclusion_reason"]):
                raise SchemaValidationError(f"{context}: virtual binary target mismatch")
        else:
            if binary_target is not None or _is_null(row["virtual_exclusion_reason"]):
                raise SchemaValidationError(f"{context}: excluded virtual outcome target mismatch")
        if trial["trial_role"] == "BROKER_PARITY":
            expected_exclusion = (
                "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH"
                if row["terminal_reason"] == "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH"
                else "PARITY_CALIBRATION_ONLY"
            )
            if row["virtual_exclusion_reason"] != expected_exclusion:
                raise SchemaValidationError(f"{context}: parity exclusion reason mismatch")

        chain_terminal = _as_bool(row, "chain_terminal", context)
        continuation_allowed = _as_bool(row, "continuation_allowed", context)
        next_index = _as_int(row, "next_reentry_index", context, nullable=True)
        next_trial_id = row["next_trial_id"]
        chain_reason = row["chain_terminal_reason"]
        continuation_reason = row["continuation_reason"]
        if trial["trial_role"] == "BROKER_PARITY":
            if not chain_terminal or continuation_allowed or chain_reason != "PARITY_COMPLETE":
                raise SchemaValidationError(f"{context}: invalid parity terminal semantics")
        elif status == "TP_FIRST":
            if not chain_terminal or continuation_allowed or chain_reason != "TP_REACHED":
                raise SchemaValidationError(f"{context}: TP-consumed chain is not terminal")
        elif status == "CENSORED":
            if not chain_terminal or continuation_allowed or chain_reason != "RUN_END_CENSORED":
                raise SchemaValidationError(f"{context}: censored chain is not terminal")
        elif trial["sl_policy"] == "STRUCTURAL":
            if not chain_terminal or continuation_allowed or chain_reason != "STRUCTURAL_SL":
                raise SchemaValidationError(f"{context}: structural SL chain is not terminal")
        else:
            current_index = int(trial["reentry_index"])
            origin = origins[trial["origin_id"]]
            expiry_time = _as_time(origin, "origin_expiry_broker_time", context)
            assert expiry_time is not None
            boundary = _as_float(trial, "boundary_price", context, nullable=True)
            normalized_risk = float(trial["normalized_risk_distance_price"])
            trade_tick = float(trial["trade_tick_size"])
            proposed_entry = exit_ask if direction == "BUY" else exit_bid
            proposed_stop = (
                proposed_entry - normalized_risk
                if direction == "BUY"
                else proposed_entry + normalized_risk
            )
            boundary_blocked = False
            if boundary is not None:
                boundary_blocked = (
                    proposed_entry <= boundary + trade_tick
                    or proposed_stop <= boundary + trade_tick
                    if direction == "BUY"
                    else proposed_entry >= boundary - trade_tick
                    or proposed_stop >= boundary - trade_tick
                )
            expected_terminal_reason = (
                "ORIGIN_WINDOW_EXPIRED"
                if terminal_time >= expiry_time
                else "NEXT_PIVOT_BOUNDARY"
                if boundary_blocked
                else "REENTRY_CAP_REACHED"
                if current_index >= MAX_REENTRY_INDEX
                else None
            )
            if expected_terminal_reason is None:
                if (
                    chain_terminal
                    or not continuation_allowed
                    or continuation_reason != "REENTRY_ALLOWED"
                    or next_index != current_index + 1
                    or _is_null(next_trial_id)
                    or not _is_null(chain_reason)
                ):
                    raise SchemaValidationError(f"{context}: eligible SL did not continue exactly once")
            elif (
                not chain_terminal
                or continuation_allowed
                or chain_reason != expected_terminal_reason
            ):
                raise SchemaValidationError(
                    f"{context}: losing-chain terminal reason does not match cap/boundary/expiry"
                )
        if not continuation_allowed:
            if next_index is not None or not _is_null(next_trial_id) or not _is_null(
                continuation_reason
            ):
                raise SchemaValidationError(f"{context}: terminal chain carries continuation facts")
        outcomes[trial_id] = row

    active_trials = {
        trial_id
        for trial_id, trial in trials.items()
        if trial["eligibility_status"] == "ACTIVE"
    }
    if outcomes.keys() != active_trials:
        raise SchemaValidationError(
            "Active trial/outcome mismatch: "
            f"missing={sorted(active_trials - outcomes.keys())}, "
            f"unexpected={sorted(outcomes.keys() - active_trials)}"
        )

    for policy_key, chain in policy_chains.items():
        ordered = sorted(chain, key=lambda row: int(row["reentry_index"]))
        indices = [int(row["reentry_index"]) for row in ordered]
        if indices != list(range(len(indices))):
            raise SchemaValidationError(f"Policy chain {policy_key} has retry index gap")
        declaration_times = [row["declared_broker_time"] for row in ordered]
        if any(
            current <= previous
            for previous, current in zip(declaration_times, declaration_times[1:])
        ):
            raise SchemaValidationError(
                f"Policy chain {policy_key} created more than one generation per tick"
            )
        for index, trial in enumerate(ordered):
            if index == 0:
                continue
            previous = ordered[index - 1]
            previous_outcome = outcomes.get(previous["trial_id"])
            if previous_outcome is None or previous_outcome["terminal_status"] != "SL_FIRST":
                raise SchemaValidationError(
                    f"Policy chain {policy_key} retry lacks immediately preceding SL_FIRST"
                )
            if previous_outcome["continuation_allowed"] != "1":
                raise SchemaValidationError(
                    f"Policy chain {policy_key} continued after a terminal predecessor"
                )
            if previous_outcome["next_trial_id"] != trial["trial_id"]:
                raise SchemaValidationError(
                    f"Policy chain {policy_key} continuation points to another trial"
                )
            if trial["parent_trial_id"] != previous["trial_id"]:
                raise SchemaValidationError(f"Policy chain {policy_key} parent_trial_id mismatch")
            if trial["continuation_source_outcome_id"] != previous_outcome["outcome_id"]:
                raise SchemaValidationError(
                    f"Policy chain {policy_key} continuation outcome identity mismatch"
                )
        final = ordered[-1]
        final_outcome = outcomes.get(final["trial_id"])
        if final_outcome is not None and final_outcome["continuation_allowed"] == "1":
            raise SchemaValidationError(f"Policy chain {policy_key} exports missing retry")
    return outcomes


def _validate_execution_checks(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    origins: dict[str, dict[str, str]],
    parity_trials: dict[str, dict[str, str]],
) -> tuple[
    dict[str, list[dict[str, str]]],
    dict[str, dict[str, str]],
    dict[str, dict[str, str]],
]:
    checks_by_signal: dict[str, list[dict[str, str]]] = defaultdict(list)
    entry_confirmations: dict[str, dict[str, str]] = {}
    close_confirmations: dict[str, dict[str, str]] = {}
    check_ids: set[str] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{EXECUTION_CHECKS_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        check_id = _require_value(row, "check_id", context)
        if check_id in check_ids:
            raise SchemaValidationError(f"Duplicate execution check_id: {check_id}")
        check_ids.add(check_id)
        origin_id = _require_value(row, "origin_id", context)
        try:
            origin = origins[origin_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: execution check references unknown origin") from exc
        broker_signal_id = _require_value(row, "broker_signal_id", context)
        if broker_signal_id != origin["broker_signal_id"]:
            raise SchemaValidationError(f"{context}: execution check broker identity mismatch")
        if row["window_id"] != origin["window_id"] or row["direction"] != origin["direction"]:
            raise SchemaValidationError(f"{context}: execution check changed origin role")
        if row["symbol"] != manifest["symbol"]:
            raise SchemaValidationError(f"{context}: execution check symbol mismatch")
        parity_trial_id = row["parity_trial_id"]
        if not _is_null(parity_trial_id):
            try:
                parity = parity_trials[parity_trial_id]
            except KeyError as exc:
                raise SchemaValidationError(f"{context}: check references unknown parity trial") from exc
            if parity["broker_signal_id"] != broker_signal_id:
                raise SchemaValidationError(f"{context}: parity/check broker identity mismatch")
        _as_int(row, "check_sequence", context)
        phase = row["check_phase"]
        if phase not in ("OBSERVATION", "PRE_SEND", "SEND_RESULT", "OWNERSHIP", "TERMINAL"):
            raise SchemaValidationError(f"{context}: invalid execution check phase")
        _validate_time_triplet(row, "broker_time", "analysis_time", "offset_minutes", context)
        for column in (
            "account_margin_mode_supported",
            "symbol_trade_mode_allowed",
            "market_session_open",
            "account_trade_allowed",
            "account_expert_trade_allowed",
            "terminal_trade_allowed",
            "mql_trade_allowed",
            "volume_valid",
            "fok_supported",
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
        ):
            _as_bool(row, column, context)
        if _as_bool(row, "protection_modified", context):
            raise SchemaValidationError(f"{context}: broker protection was modified")
        for column in (
            "bid",
            "ask",
            "spread_points",
            "point_size",
            "trade_tick_size",
            "stops_distance_points",
            "freeze_distance_points",
            "entry_price",
            "stop_loss_price",
            "take_profit_price",
            "risk_distance_points",
            "reward_distance_points",
            "requested_volume",
            "normalized_volume",
            "volume_min",
            "volume_max",
            "volume_step",
            "account_balance",
            "free_margin",
        ):
            _as_float(row, column, context)
        if row["fill_policy"] != "ORDER_FILLING_FOK":
            raise SchemaValidationError(f"{context}: execution path is not FOK-only")
        send_performed = row["send_performed"] == "1"
        send_succeeded = row["send_succeeded"] == "1"
        if send_succeeded and not send_performed:
            raise SchemaValidationError(f"{context}: send succeeded without send_performed")
        if send_performed:
            if row["trade_action"] != "TRADE_ACTION_DEAL":
                raise SchemaValidationError(f"{context}: non-deal trade action detected")
            if row["fok_supported"] != "1":
                raise SchemaValidationError(f"{context}: send performed without FOK support")
        elif not _is_null(row["trade_action"]):
            raise SchemaValidationError(f"{context}: non-send check carries trade action")
        if row["trade_action"] == "TRADE_ACTION_SLTP":
            raise SchemaValidationError(f"{context}: TRADE_ACTION_SLTP is forbidden")
        if row["broker_entry_confirmed"] == "1":
            if broker_signal_id in entry_confirmations:
                previous = entry_confirmations[broker_signal_id]
                for column in (
                    "position_identifier",
                    "broker_entry_price",
                    "broker_volume",
                    "broker_stop_loss",
                    "broker_take_profit",
                ):
                    if row[column] != previous[column]:
                        raise SchemaValidationError(
                            f"{context}: broker entry ownership fact changed: {column}"
                        )
            else:
                for column in (
                    "order_ticket",
                    "deal_ticket",
                    "position_ticket",
                    "position_identifier",
                    "broker_entry_price",
                    "broker_volume",
                    "broker_stop_loss",
                    "broker_take_profit",
                ):
                    _require_value(row, column, context)
                entry_confirmations[broker_signal_id] = row
        if row["broker_close_confirmed"] == "1":
            if row["broker_entry_confirmed"] != "1":
                raise SchemaValidationError(f"{context}: close confirmed without owned entry")
            for column in ("close_price", "closed_volume", "terminal_reason"):
                _require_value(row, column, context)
            close_confirmations[broker_signal_id] = row
        checks_by_signal[broker_signal_id].append(row)

    for broker_signal_id, checks in checks_by_signal.items():
        ordered = sorted(checks, key=lambda row: int(row["check_sequence"]))
        sequences = [int(row["check_sequence"]) for row in ordered]
        if sequences != list(range(1, len(sequences) + 1)):
            raise SchemaValidationError(
                f"Execution checks for {broker_signal_id} are not a contiguous ordered sequence"
            )
        if ordered[0]["check_phase"] != "OBSERVATION":
            raise SchemaValidationError(f"Execution checks for {broker_signal_id} lack observation")
        send_rows = [row for row in ordered if row["send_performed"] == "1"]
        if len(send_rows) > 1:
            raise SchemaValidationError(f"Execution checks for {broker_signal_id} contain multiple sends")
        if send_rows and not any(row["check_phase"] == "PRE_SEND" for row in ordered):
            raise SchemaValidationError(f"Execution checks for {broker_signal_id} lack fresh pre-send")
    return checks_by_signal, entry_confirmations, close_confirmations


def _validate_broker_outcomes(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    origins: dict[str, dict[str, str]],
    parity_trials: dict[str, dict[str, str]],
    virtual_outcomes: dict[str, dict[str, str]],
    entry_confirmations: dict[str, dict[str, str]],
    close_confirmations: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    outcomes: dict[str, dict[str, str]] = {}
    outcome_ids: set[str] = set()
    position_ids: set[str] = set()
    paired_parity_ids: set[str] = set()
    for row_index, row in enumerate(rows, start=2):
        context = f"{BROKER_OUTCOMES_FILE}:{row_index}"
        _validate_common_row(row, context, manifest)
        broker_outcome_id = _require_value(row, "broker_outcome_id", context)
        if broker_outcome_id in outcome_ids:
            raise SchemaValidationError(f"Duplicate broker_outcome_id: {broker_outcome_id}")
        outcome_ids.add(broker_outcome_id)
        origin_id = _require_value(row, "origin_id", context)
        try:
            origin = origins[origin_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: broker outcome references unknown origin") from exc
        broker_signal_id = _require_value(row, "broker_signal_id", context)
        if broker_signal_id != origin["broker_signal_id"]:
            raise SchemaValidationError(f"{context}: broker outcome identity mismatch")
        if broker_signal_id in outcomes:
            raise SchemaValidationError(f"Duplicate broker outcome for signal: {broker_signal_id}")
        for column, expected in (
            ("window_id", origin["window_id"]),
            ("symbol", origin["symbol"]),
            ("macro_timeframe", origin["macro_timeframe"]),
            ("micro_timeframe", origin["micro_timeframe"]),
            ("active_bar_open_broker_time", origin["active_bar_open_broker_time"]),
            ("level_id", origin["level_id"]),
            ("direction", origin["direction"]),
        ):
            if row[column] != expected:
                raise SchemaValidationError(f"{context}: broker outcome changed origin field {column}")
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
        assert entry_time is not None and close_time is not None
        duration = _as_int(row, "duration_seconds", context)
        assert duration is not None
        if close_time < entry_time or duration != int((close_time - entry_time).total_seconds()):
            raise SchemaValidationError(f"{context}: broker duration mismatch")
        position_identifier = _require_value(row, "position_identifier", context)
        if position_identifier in position_ids:
            raise SchemaValidationError(f"{context}: duplicate broker position ownership")
        position_ids.add(position_identifier)
        for column in (
            "order_ticket",
            "entry_deal_ticket",
            "last_close_deal_ticket",
            "close_deal_count",
            "position_ticket",
            "position_identifier",
        ):
            _as_int(row, column, context)
        for column in (
            "submitted_request_price",
            "broker_entry_price",
            "broker_volume",
            "immutable_stop_loss",
            "immutable_take_profit",
            "broker_close_price",
            "broker_closed_volume",
            "request_risk_distance_points",
            "request_reward_distance_points",
            "request_price_reward_risk_ratio",
            "quote_expected_stop_loss",
            "quote_expected_take_profit",
            "quote_expected_reward_risk_ratio",
            "entry_slippage_points",
            "exit_slippage_points",
            "broker_gross_profit",
            "broker_commission",
            "broker_swap",
            "broker_fee",
            "broker_net_profit",
            "broker_gross_execution_r",
            "broker_net_execution_r",
        ):
            _as_float(row, column, context)
        gross = float(row["broker_gross_profit"])
        commission = float(row["broker_commission"])
        swap = float(row["broker_swap"])
        fee = float(row["broker_fee"])
        net = float(row["broker_net_profit"])
        if not _same_number(net, gross + commission + swap + fee):
            raise SchemaValidationError(f"{context}: broker net profit cost arithmetic mismatch")
        if row["broker_entry_confirmed"] != "1" or row["broker_close_confirmed"] != "1":
            raise SchemaValidationError(f"{context}: broker outcome lacks entry/close confirmation")
        try:
            entry_confirmation = entry_confirmations[broker_signal_id]
            close_confirmation = close_confirmations[broker_signal_id]
        except KeyError as exc:
            raise SchemaValidationError(f"{context}: broker outcome lacks execution-check ownership") from exc
        for outcome_column, check_column in (
            ("position_identifier", "position_identifier"),
            ("broker_entry_price", "broker_entry_price"),
            ("broker_volume", "broker_volume"),
            ("immutable_stop_loss", "broker_stop_loss"),
            ("immutable_take_profit", "broker_take_profit"),
        ):
            if row[outcome_column] != entry_confirmation[check_column]:
                raise SchemaValidationError(
                    f"{context}: broker outcome changed entry ownership fact {outcome_column}"
                )
        for outcome_column, check_column in (
            ("broker_close_price", "close_price"),
            ("broker_closed_volume", "closed_volume"),
        ):
            if row[outcome_column] != close_confirmation[check_column]:
                raise SchemaValidationError(
                    f"{context}: broker outcome changed close fact {outcome_column}"
                )
        terminal_reason = row["broker_terminal_reason"]
        if terminal_reason not in (
            "BROKER_TP",
            "BROKER_SL",
            "MANUAL",
            "MIXED",
            "STOP_OUT",
            "EXPERT",
            "OTHER",
            "CENSORED",
        ):
            raise SchemaValidationError(f"{context}: invalid broker terminal reason")
        reason_consistent = _as_bool(row, "close_reason_consistent", context)
        binary_eligible = _as_bool(row, "broker_binary_eligible", context)
        expected_binary = (
            reason_consistent
            and terminal_reason in ("BROKER_TP", "BROKER_SL")
            and origin["origin_feature_snapshot_complete"] == "1"
        )
        if binary_eligible != expected_binary:
            raise SchemaValidationError(f"{context}: broker binary eligibility mismatch")
        target = _as_int(row, "broker_binary_target", context, nullable=True)
        if binary_eligible:
            expected_target = 1 if terminal_reason == "BROKER_TP" else 0
            if target != expected_target or not _is_null(row["broker_exclusion_reason"]):
                raise SchemaValidationError(f"{context}: broker binary target mismatch")
        elif target is not None or _is_null(row["broker_exclusion_reason"]):
            raise SchemaValidationError(f"{context}: excluded broker outcome target mismatch")
        parity_trial_id = row["parity_trial_id"]
        if not _is_null(parity_trial_id):
            try:
                parity_trial = parity_trials[parity_trial_id]
                parity_outcome = virtual_outcomes[parity_trial_id]
            except KeyError as exc:
                raise SchemaValidationError(f"{context}: broker outcome lacks parity pair") from exc
            if parity_trial["broker_signal_id"] != broker_signal_id:
                raise SchemaValidationError(f"{context}: parity pair broker identity mismatch")
            paired_parity_ids.add(parity_trial_id)
            if parity_outcome["terminal_status"] == "CENSORED":
                if (
                    parity_outcome["terminal_reason"]
                    != "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH"
                ):
                    raise SchemaValidationError(
                        f"{context}: broker outcome has unresolved parity without terminal censor"
                    )
                parity_terminal_time = _as_time(
                    parity_outcome, "terminal_broker_time", context
                )
                assert parity_terminal_time is not None
                if parity_terminal_time < close_time:
                    raise SchemaValidationError(
                        f"{context}: broker-terminal parity censor precedes broker close"
                    )
            strict_pair = binary_eligible and parity_outcome["terminal_status"] in (
                "TP_FIRST",
                "SL_FIRST",
            )
            if strict_pair:
                expected_parity = "TP_FIRST" if terminal_reason == "BROKER_TP" else "SL_FIRST"
                if parity_outcome["terminal_status"] != expected_parity:
                    raise SchemaValidationError(
                        f"{context}: unexplained broker/parity TP/SL terminal mismatch"
                    )
        outcomes[broker_signal_id] = row
    for parity_trial_id, parity_outcome in virtual_outcomes.items():
        if (
            parity_outcome["trial_role"] == "BROKER_PARITY"
            and parity_outcome["terminal_reason"]
            == "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH"
            and parity_trial_id not in paired_parity_ids
        ):
            raise SchemaValidationError(
                f"Parity outcome {parity_trial_id} has broker-terminal censor without broker outcome"
            )
    return outcomes


def _validate_summary(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    actual_counts: dict[str, int],
    trials: dict[str, dict[str, str]],
    virtual_outcomes: dict[str, dict[str, str]],
    broker_outcomes: dict[str, dict[str, str]],
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

    matrix_trials = [row for row in trials.values() if row["trial_role"] == "MATRIX"]
    parity_trials = [row for row in trials.values() if row["trial_role"] == "BROKER_PARITY"]
    matrix_outcomes = [
        row for row in virtual_outcomes.values() if row["trial_role"] == "MATRIX"
    ]
    parity_outcomes = [
        row for row in virtual_outcomes.values() if row["trial_role"] == "BROKER_PARITY"
    ]
    strict_pairs = 0
    terminal_matches = 0
    terminal_mismatches = 0
    parity_excluded = 0
    for broker in broker_outcomes.values():
        parity_id = broker["parity_trial_id"]
        if _is_null(parity_id):
            continue
        strict_pairs += 1
        parity = virtual_outcomes[parity_id]
        if broker["broker_binary_eligible"] != "1" or parity["terminal_status"] not in (
            "TP_FIRST",
            "SL_FIRST",
        ):
            parity_excluded += 1
            continue
        expected = "TP_FIRST" if broker["broker_terminal_reason"] == "BROKER_TP" else "SL_FIRST"
        if parity["terminal_status"] == expected:
            terminal_matches += 1
        else:
            terminal_mismatches += 1

    count_columns = {
        "pivot_window_rows": actual_counts[PIVOT_WINDOWS_FILE],
        "signal_origin_rows": actual_counts[SIGNAL_ORIGINS_FILE],
        "virtual_trial_rows": actual_counts[VIRTUAL_TRIALS_FILE],
        "matrix_trial_rows": len(matrix_trials),
        "reentry_trial_rows": sum(int(trial["reentry_index"]) > 0 for trial in matrix_trials),
        "parity_trial_rows": len(parity_trials),
        "virtual_active_trial_rows": sum(
            trial["eligibility_status"] == "ACTIVE" for trial in trials.values()
        ),
        "virtual_ineligible_feature_rows": sum(
            trial["eligibility_status"] == "INELIGIBLE_FEATURE" for trial in trials.values()
        ),
        "virtual_ineligible_geometry_rows": sum(
            trial["eligibility_status"] == "INELIGIBLE_GEOMETRY" for trial in trials.values()
        ),
        "virtual_ineligible_distance_rows": sum(
            trial["eligibility_status"] == "INELIGIBLE_DISTANCE" for trial in trials.values()
        ),
        "virtual_ineligible_money_rows": sum(
            trial["eligibility_status"] == "INELIGIBLE_MONEY_PLAN" for trial in trials.values()
        ),
        "virtual_outcome_rows": actual_counts[VIRTUAL_OUTCOMES_FILE],
        "matrix_tp_rows": sum(outcome["terminal_status"] == "TP_FIRST" for outcome in matrix_outcomes),
        "matrix_sl_rows": sum(outcome["terminal_status"] == "SL_FIRST" for outcome in matrix_outcomes),
        "matrix_censored_rows": sum(outcome["terminal_status"] == "CENSORED" for outcome in matrix_outcomes),
        "parity_outcome_rows": len(parity_outcomes),
        "execution_check_rows": actual_counts[EXECUTION_CHECKS_FILE],
        "broker_outcome_rows": actual_counts[BROKER_OUTCOMES_FILE],
        "broker_binary_eligible_rows": sum(
            outcome["broker_binary_eligible"] == "1" for outcome in broker_outcomes.values()
        ),
        "broker_binary_tp_rows": sum(
            outcome["broker_binary_target"] == "1" for outcome in broker_outcomes.values()
        ),
        "broker_binary_sl_rows": sum(
            outcome["broker_binary_target"] == "0" for outcome in broker_outcomes.values()
        ),
        "broker_excluded_rows": sum(
            outcome["broker_binary_eligible"] == "0" for outcome in broker_outcomes.values()
        ),
        "parity_pair_rows": strict_pairs,
        "parity_terminal_match_rows": terminal_matches,
        "parity_terminal_mismatch_rows": terminal_mismatches,
        "parity_excluded_rows": parity_excluded,
        "chain_tp_complete_rows": sum(
            outcome["trial_role"] == "MATRIX"
            and outcome["chain_terminal_reason"] == "TP_REACHED"
            for outcome in virtual_outcomes.values()
        ),
        "chain_structural_sl_rows": sum(
            outcome["chain_terminal_reason"] == "STRUCTURAL_SL"
            for outcome in matrix_outcomes
        ),
        "chain_reentry_cap_rows": sum(
            outcome["chain_terminal_reason"] == "REENTRY_CAP_REACHED"
            for outcome in matrix_outcomes
        ),
        "chain_next_pivot_boundary_rows": sum(
            outcome["chain_terminal_reason"] == "NEXT_PIVOT_BOUNDARY"
            for outcome in matrix_outcomes
        ),
        "chain_origin_expired_rows": sum(
            outcome["chain_terminal_reason"] == "ORIGIN_WINDOW_EXPIRED"
            for outcome in matrix_outcomes
        ),
        "chain_run_end_censored_rows": sum(
            outcome["chain_terminal_reason"] == "RUN_END_CENSORED"
            for outcome in matrix_outcomes
        ),
        "chain_ineligible_rows": sum(
            trial["eligibility_status"] != "ACTIVE" for trial in matrix_trials
        ),
    }
    for column, expected in count_columns.items():
        if _as_int(row, column, context) != expected:
            raise SchemaValidationError(f"run summary count mismatch for {column}")
    active_state_peak = _as_int(row, "active_state_peak", context)
    active_state_cap = _as_int(row, "active_state_cap", context)
    assert active_state_peak is not None and active_state_cap is not None
    if active_state_cap != ACTIVE_STATE_CAP or not 0 <= active_state_peak <= active_state_cap:
        raise SchemaValidationError("run summary active-state cap/peak mismatch")
    if _as_bool(row, "state_capacity_failed", context):
        raise SchemaValidationError("run summary reports virtual state capacity failure")
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
    if terminal_mismatches:
        raise SchemaValidationError("run summary contains broker/parity terminal mismatch")
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
    origins = _validate_origins(table_rows[SIGNAL_ORIGINS_FILE], manifest, windows)
    trials, policy_chains, parity_trials = _validate_trials(
        table_rows[VIRTUAL_TRIALS_FILE], manifest, origins
    )
    virtual_outcomes = _validate_virtual_outcomes(
        table_rows[VIRTUAL_OUTCOMES_FILE], manifest, trials, policy_chains, origins
    )
    _, entry_confirmations, close_confirmations = _validate_execution_checks(
        table_rows[EXECUTION_CHECKS_FILE], manifest, origins, parity_trials
    )
    broker_outcomes = _validate_broker_outcomes(
        table_rows[BROKER_OUTCOMES_FILE],
        manifest,
        origins,
        parity_trials,
        virtual_outcomes,
        entry_confirmations,
        close_confirmations,
    )
    actual_counts = {filename: len(rows) for filename, rows in table_rows.items()}
    warnings = _validate_summary(
        table_rows[RUN_SUMMARY_FILE],
        manifest,
        actual_counts,
        trials,
        virtual_outcomes,
        broker_outcomes,
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
