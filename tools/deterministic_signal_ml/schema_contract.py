"""Strict schema V13 contract for H1 lanes and shared deep-pivot evidence.

The producer and offline tools deliberately share this small, explicit contract.
No V12 conversion or compatibility mode is provided.
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

SUPPORTED_SCHEMA_VERSION = 13
SUPPORTED_ENGINE_LABEL = "PIVOT_FRACTAL_V2"
SUPPORTED_FEATURE_SET_ID = "schema_v13_hft_deep_pivot_features"
H1_FEATURE_SET_ID = f"{SUPPORTED_FEATURE_SET_ID}.h1"
DEEP_FEATURE_SET_ID = f"{SUPPORTED_FEATURE_SET_ID}.deep_parent"
STORAGE_ROOT = r"Common\Files\PivotFractalV13\runs"
NULL_TOKEN = r"\N"

FEATURE_SHIFTS = tuple(range(6))
FEATURE_SMA_PERIOD = 5
FEATURE_STATE_TOLERANCE = 1e-7
RISK_TICK_TOLERANCE = 1e-7
FEATURE_STATES = ("ABOVE", "BELOW", "EQUAL")
SIGNAL_SERIES = ("b_percent", "stochastic_main_line", "stochastic_signal_line")


def _series_columns(prefix: str, series: str) -> tuple[str, ...]:
    return tuple(
        column
        for shift in FEATURE_SHIFTS
        for column in (
            f"{prefix}_{series}_{shift}",
            f"{prefix}_{series}_sma_5_{shift}",
            f"{prefix}_{series}_sma_slope_{shift}",
            f"{prefix}_{series}_state_{shift}",
        )
    )


def _timeframe_feature_columns(prefix: str) -> tuple[str, ...]:
    return (
        f"{prefix}_band_width_points_0",
        *(column for series in SIGNAL_SERIES for column in _series_columns(prefix, series)),
        *(
            column
            for shift in FEATURE_SHIFTS
            for column in (
                f"{prefix}_band_base_line_{shift}",
                f"{prefix}_band_base_line_slope_points_{shift}",
            )
        ),
    )


ORIGIN_MICRO_FEATURE_COLUMNS = _timeframe_feature_columns("origin_micro")
ORIGIN_MACRO_FEATURE_COLUMNS = _timeframe_feature_columns("origin_macro")
ORIGIN_SIGNAL_FEATURE_COLUMNS = (*ORIGIN_MICRO_FEATURE_COLUMNS, *ORIGIN_MACRO_FEATURE_COLUMNS)
DEEP_MICRO_FEATURE_COLUMNS = _timeframe_feature_columns("deep_micro")

RUN_MANIFEST_FILE = "run_manifest.tsv"
PIVOT_WINDOWS_FILE = "pivot_windows.tsv"
SIGNAL_ORIGINS_FILE = "signal_origins.tsv"
VIRTUAL_TRIALS_FILE = "virtual_trials.tsv"
VIRTUAL_OUTCOMES_FILE = "virtual_outcomes.tsv"
DEEP_PIVOT_EVENTS_FILE = "deep_pivot_events.tsv"
DEEP_PIVOT_PARENT_LINKS_FILE = "deep_pivot_parent_links.tsv"
DEEP_VIRTUAL_TRIALS_FILE = "deep_virtual_trials.tsv"
DEEP_VIRTUAL_OUTCOMES_FILE = "deep_virtual_outcomes.tsv"
EXECUTION_CHECKS_FILE = "execution_checks.tsv"
BROKER_OUTCOMES_FILE = "broker_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"

RUN_FILES = (
    RUN_MANIFEST_FILE,
    PIVOT_WINDOWS_FILE,
    SIGNAL_ORIGINS_FILE,
    VIRTUAL_TRIALS_FILE,
    VIRTUAL_OUTCOMES_FILE,
    DEEP_PIVOT_EVENTS_FILE,
    DEEP_PIVOT_PARENT_LINKS_FILE,
    DEEP_VIRTUAL_TRIALS_FILE,
    DEEP_VIRTUAL_OUTCOMES_FILE,
    EXECUTION_CHECKS_FILE,
    BROKER_OUTCOMES_FILE,
    RUN_SUMMARY_FILE,
)

MANIFEST_COLUMNS = ("schema_version", "key", "value")

PIVOT_WINDOW_COLUMNS = (
    "schema_version", "run_id", "config_id", "window_id", "window_scope", "symbol",
    "timeframe", "active_bar_open_broker_time", "active_bar_open_analysis_time",
    "active_bar_open_offset_minutes", "source_bar_open_broker_time",
    "source_bar_open_analysis_time", "source_bar_open_offset_minutes",
    "source_close_boundary_broker_time", "source_close_boundary_analysis_time",
    "source_close_boundary_offset_minutes", "source_open", "source_high", "source_low",
    "source_close", "source_range", "raw_s3_price", "raw_s2_price", "raw_s1_price",
    "raw_pp_price", "raw_r1_price", "raw_r2_price", "raw_r3_price", "trade_s3_price",
    "trade_s2_price", "trade_s1_price", "trade_pp_price", "trade_r1_price",
    "trade_r2_price", "trade_r3_price", "first_observed_broker_time",
    "first_observed_analysis_time", "first_observed_offset_minutes", "first_observed_bid",
    "pp_initial_relation", "pp_role", "pp_arm_broker_time", "pp_arm_analysis_time",
    "pp_arm_offset_minutes", "pp_arm_bid", "window_state", "invalid_reason",
    "terminal_broker_time", "terminal_analysis_time", "terminal_offset_minutes",
    "terminal_status",
)

SIGNAL_ORIGIN_COLUMNS = (
    "schema_version", "run_id", "config_id", "origin_id", "window_id", "broker_signal_id",
    "symbol", "macro_timeframe", "deep_timeframe", "micro_timeframe",
    "active_bar_open_broker_time", "level_id", "direction", "trigger_broker_time",
    "trigger_analysis_time", "trigger_offset_minutes", "trigger_bid", "trigger_ask",
    "spread_points", "point_size", "trade_tick_size", "stops_level_points",
    "freeze_level_points", "raw_s3_price", "raw_s2_price", "raw_s1_price", "raw_pp_price",
    "raw_r1_price", "raw_r2_price", "raw_r3_price", "trade_s3_price", "trade_s2_price",
    "trade_s1_price", "trade_pp_price", "trade_r1_price", "trade_r2_price", "trade_r3_price",
    "pivot_raw_price", "pivot_trade_price", "next_outward_pivot_price", "midpoint_50_price",
    "structural_entry_price", "structural_sl_price", "structural_take_profit",
    *ORIGIN_SIGNAL_FEATURE_COLUMNS, "origin_micro_features_complete",
    "origin_macro_features_complete", "origin_feature_snapshot_complete",
    "origin_feature_invalid_reason", "identity_consumed", "h1_lanes_declared",
    "broker_attempt_status", "origin_terminal_status",
)

VIRTUAL_TRIAL_COLUMNS = (
    "schema_version", "run_id", "config_id", "trial_id", "parity_trial_id", "origin_id",
    "window_id", "broker_signal_id", "trial_role", "entry_policy", "tp_r_multiple",
    "level_id", "direction", "declared_broker_time", "declared_analysis_time",
    "declared_offset_minutes", "entry_broker_time", "entry_analysis_time", "entry_offset_minutes",
    "entry_bid", "entry_ask", "entry_price", "entry_quote_side", "exit_quote_side",
    "midpoint_50_price", "midpoint_touched", "requested_risk_distance_price",
    "requested_risk_distance_points", "normalized_risk_ticks", "normalized_risk_distance_price",
    "normalized_risk_distance_points", "stop_loss_price", "take_profit_price",
    "geometry_equivalence_id", "spread_points", "point_size", "trade_tick_size",
    "stops_level_points", "freeze_level_points", "minimum_risk_distance_points",
    "distance_eligible", "lot_mode", "lot_strategy_size", "reference_balance", "account_currency",
    "risk_budget_amount", "requested_volume", "normalized_volume", "virtual_expected_stop_loss",
    "virtual_expected_take_profit", "virtual_expected_reward_risk_ratio",
    "virtual_money_plan_complete", "eligibility_status", "ineligible_reason",
    "origin_window_active_at_entry",
)

VIRTUAL_OUTCOME_COLUMNS = (
    "schema_version", "run_id", "config_id", "outcome_id", "trial_id", "parity_trial_id",
    "origin_id", "window_id", "trial_role", "entry_policy", "tp_r_multiple", "direction",
    "terminal_broker_time", "terminal_analysis_time", "terminal_offset_minutes", "terminal_status",
    "terminal_reason", "threshold_price", "observed_exit_bid", "observed_exit_ask",
    "observed_exit_price", "exit_quote_side", "gap_points", "h1_structural_lifecycle_seconds",
    "virtual_nominal_r", "virtual_quote_gross_profit", "virtual_quote_gross_r",
    "virtual_binary_eligible", "virtual_binary_target", "virtual_exclusion_reason",
    "first_touch_consistent",
)

DEEP_PIVOT_EVENT_COLUMNS = (
    "schema_version", "run_id", "config_id", "deep_event_id", "deep_window_id", "symbol",
    "deep_timeframe", "micro_timeframe", "active_deep_bar_open_broker_time", "level_id",
    "direction", "trigger_broker_time", "trigger_analysis_time", "trigger_offset_minutes",
    "trigger_bid", "trigger_ask", "spread_points", "point_size", "trade_tick_size",
    "stops_level_points", "freeze_level_points", "pivot_raw_price", "pivot_trade_price",
    "next_outward_pivot_price", *DEEP_MICRO_FEATURE_COLUMNS, "deep_micro_features_complete",
    "deep_feature_invalid_reason", "identity_consumed", "admission_status", "active_parent_count",
    "required_link_slots", "required_trial_slots", "required_outcome_slots", "reserved_link_slots",
    "reserved_trial_slots", "reserved_outcome_slots", "capacity_rejection_reason",
)

DEEP_PIVOT_PARENT_LINK_COLUMNS = (
    "schema_version", "run_id", "config_id", "parent_link_id", "deep_event_id", "origin_id",
    "parent_kind", "parent_trial_id", "parent_broker_signal_id", "parent_entry_policy",
    "parent_tp_r_multiple", "direction", "parent_entry_broker_time", "event_trigger_broker_time",
    "m10_parent_age_seconds", "link_status",
)

DEEP_VIRTUAL_TRIAL_COLUMNS = (
    "schema_version", "run_id", "config_id", "deep_trial_id", "deep_event_id", "tp_r_multiple",
    "level_id", "direction", "declared_broker_time", "declared_analysis_time",
    "declared_offset_minutes", "entry_bid", "entry_ask", "entry_price", "entry_quote_side",
    "exit_quote_side", "requested_risk_distance_price", "requested_risk_distance_points",
    "normalized_risk_ticks", "normalized_risk_distance_price", "normalized_risk_distance_points",
    "stop_loss_price", "take_profit_price", "geometry_equivalence_id", "spread_points", "point_size",
    "trade_tick_size", "stops_level_points", "freeze_level_points", "minimum_risk_distance_points",
    "distance_eligible", "eligibility_status", "ineligible_reason",
)

DEEP_VIRTUAL_OUTCOME_COLUMNS = (
    "schema_version", "run_id", "config_id", "deep_outcome_id", "parent_link_id", "deep_trial_id",
    "deep_event_id", "origin_id", "tp_r_multiple", "direction", "terminal_broker_time",
    "terminal_analysis_time", "terminal_offset_minutes", "terminal_status", "terminal_reason",
    "threshold_price", "observed_exit_bid", "observed_exit_ask", "observed_exit_price",
    "exit_quote_side", "gap_points", "deep_lifecycle_seconds", "virtual_nominal_r",
    "virtual_quote_gross_profit", "virtual_quote_gross_r", "virtual_binary_eligible",
    "virtual_binary_target", "virtual_exclusion_reason", "first_touch_consistent",
)

EXECUTION_CHECK_COLUMNS = (
    "schema_version", "run_id", "config_id", "check_id", "origin_id", "broker_signal_id",
    "parity_trial_id", "window_id", "check_sequence", "check_phase", "broker_time", "analysis_time",
    "offset_minutes", "symbol", "direction", "account_margin_mode", "account_margin_mode_supported",
    "symbol_trade_mode", "symbol_trade_mode_allowed", "market_session_open", "account_trade_allowed",
    "account_expert_trade_allowed", "terminal_trade_allowed", "mql_trade_allowed", "bid", "ask",
    "spread_points", "point_size", "trade_tick_size", "stops_distance_points", "freeze_distance_points",
    "entry_price", "stop_loss_price", "take_profit_price", "risk_distance_points",
    "reward_distance_points", "risk_budget_amount", "requested_volume", "normalized_volume", "volume_min",
    "volume_max", "volume_step", "volume_valid", "fok_supported", "fill_policy",
    "quote_expected_stop_loss", "quote_expected_take_profit", "quote_expected_reward_risk_ratio",
    "risk_budget_utilization_ratio", "account_balance", "free_margin", "required_margin", "margin_valid",
    "geometry_valid", "stop_distance_valid", "freeze_distance_valid", "order_check_performed",
    "order_check_allowed", "order_check_retcode", "order_check_comment", "allowed", "block_source",
    "block_reason", "send_performed", "send_succeeded", "trade_action", "send_retcode", "send_comment",
    "order_ticket", "deal_ticket", "position_ticket", "position_identifier", "broker_entry_confirmed",
    "broker_close_confirmed", "broker_entry_price", "broker_volume", "broker_stop_loss",
    "broker_take_profit", "close_price", "closed_volume", "terminal_reason", "protection_modified",
)

BROKER_OUTCOME_COLUMNS = (
    "schema_version", "run_id", "config_id", "broker_outcome_id", "origin_id", "broker_signal_id",
    "parity_trial_id", "window_id", "symbol", "macro_timeframe", "deep_timeframe", "micro_timeframe",
    "active_bar_open_broker_time", "level_id", "direction", "entry_broker_time", "entry_analysis_time",
    "entry_offset_minutes", "close_broker_time", "close_analysis_time", "close_offset_minutes",
    "order_ticket", "entry_deal_ticket", "last_close_deal_ticket", "close_deal_count", "position_ticket",
    "position_identifier", "submitted_request_price", "broker_entry_price", "broker_volume",
    "immutable_stop_loss", "immutable_take_profit", "broker_close_price", "broker_closed_volume",
    "request_risk_distance_points", "request_reward_distance_points", "request_price_reward_risk_ratio",
    "risk_budget_amount", "quote_expected_stop_loss", "quote_expected_take_profit",
    "quote_expected_reward_risk_ratio", "risk_budget_utilization_ratio", "entry_slippage_points",
    "exit_slippage_points", "broker_gross_profit", "broker_commission", "broker_swap", "broker_fee",
    "broker_net_profit", "broker_gross_budget_r", "broker_net_budget_r", "broker_gross_execution_r",
    "broker_net_execution_r", "broker_terminal_reason", "close_reason_consistent", "broker_binary_eligible",
    "broker_binary_target", "broker_exclusion_reason", "h1_structural_lifecycle_seconds",
    "broker_entry_confirmed", "broker_close_confirmed",
)

SUMMARY_COLUMNS = (
    "schema_version", "run_id", "config_id", "started_broker_time", "started_analysis_time",
    "started_offset_minutes", "finished_broker_time", "finished_analysis_time", "finished_offset_minutes",
    "pivot_window_rows", "macro_window_rows", "deep_window_rows", "signal_origin_rows", "h1_trial_rows",
    "h1_structural_trial_rows", "h1_midpoint_trial_rows", "parity_trial_rows", "h1_outcome_rows",
    "h1_tp_rows", "h1_sl_rows", "h1_not_triggered_rows", "h1_ineligible_rows", "h1_run_censored_rows",
    "deep_event_rows", "deep_event_admitted_rows", "deep_event_capacity_rejected_rows",
    "deep_parent_link_rows", "deep_trial_rows", "deep_outcome_rows", "deep_tp_rows", "deep_sl_rows",
    "deep_parent_exit_censored_rows", "deep_run_censored_rows", "deep_ineligible_rows",
    "execution_check_rows", "broker_outcome_rows", "parity_pair_rows", "h1_active_state_peak",
    "h1_active_state_cap", "deep_event_active_peak", "deep_event_active_cap", "deep_link_active_peak",
    "deep_link_active_cap", "deep_trial_active_peak", "deep_trial_active_cap", "deep_outcome_active_peak",
    "deep_outcome_active_cap", "duplicate_identity_count", "referential_integrity_error_count",
    "row_integrity_error_count", "export_status", "completion_status",
)

TABLE_COLUMNS = {
    RUN_MANIFEST_FILE: MANIFEST_COLUMNS,
    PIVOT_WINDOWS_FILE: PIVOT_WINDOW_COLUMNS,
    SIGNAL_ORIGINS_FILE: SIGNAL_ORIGIN_COLUMNS,
    VIRTUAL_TRIALS_FILE: VIRTUAL_TRIAL_COLUMNS,
    VIRTUAL_OUTCOMES_FILE: VIRTUAL_OUTCOME_COLUMNS,
    DEEP_PIVOT_EVENTS_FILE: DEEP_PIVOT_EVENT_COLUMNS,
    DEEP_PIVOT_PARENT_LINKS_FILE: DEEP_PIVOT_PARENT_LINK_COLUMNS,
    DEEP_VIRTUAL_TRIALS_FILE: DEEP_VIRTUAL_TRIAL_COLUMNS,
    DEEP_VIRTUAL_OUTCOMES_FILE: DEEP_VIRTUAL_OUTCOME_COLUMNS,
    EXECUTION_CHECKS_FILE: EXECUTION_CHECK_COLUMNS,
    BROKER_OUTCOMES_FILE: BROKER_OUTCOME_COLUMNS,
    RUN_SUMMARY_FILE: SUMMARY_COLUMNS,
}

PIVOT_LEVELS = ("S3", "S2", "S1", "PP", "R1", "R2", "R3")
SUPPORT_LEVELS = ("S1", "S2", "S3")
RESISTANCE_LEVELS = ("R1", "R2", "R3")
H1_ENTRY_POLICIES = ("STRUCTURAL", "MIDPOINT_50")
H1_TP_R_MULTIPLES = (1, 2, 3, 5)
DEEP_TP_R_MULTIPLES = (1, 2, 3)
H1_MATRIX_SIZE = len(H1_ENTRY_POLICIES) * len(H1_TP_R_MULTIPLES)
# Names retained for callers that describe the H1 lane matrix.
INITIAL_MATRIX_SIZE = H1_MATRIX_SIZE
TP_R_MULTIPLES = H1_TP_R_MULTIPLES
ACTIVE_STATE_CAP = 2048

REFERENCE_LOT_MODE = "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT"
FIXED_LOT_MODE = "EXECUTION_LOT_FIXED_SIZE"
REFERENCE_BALANCE = 1_000_000.0

TIMEFRAME_SECONDS = {
    "PERIOD_M1": 60, "PERIOD_M2": 120, "PERIOD_M3": 180, "PERIOD_M4": 240,
    "PERIOD_M5": 300, "PERIOD_M6": 360, "PERIOD_M10": 600, "PERIOD_M12": 720,
    "PERIOD_M15": 900, "PERIOD_M20": 1200, "PERIOD_M30": 1800, "PERIOD_H1": 3600,
    "PERIOD_H2": 7200, "PERIOD_H3": 10800, "PERIOD_H4": 14400, "PERIOD_H6": 21600,
    "PERIOD_H8": 28800, "PERIOD_H12": 43200, "PERIOD_D1": 86400, "PERIOD_W1": 604800,
    "PERIOD_MN1": 2592000,
}

ORIGIN_STATE_FEATURE_COLUMNS = tuple(c for c in ORIGIN_SIGNAL_FEATURE_COLUMNS if "_state_" in c)
DEEP_STATE_FEATURE_COLUMNS = tuple(c for c in DEEP_MICRO_FEATURE_COLUMNS if "_state_" in c)
ORIGIN_NUMERIC_SIGNAL_FEATURE_COLUMNS = tuple(c for c in ORIGIN_SIGNAL_FEATURE_COLUMNS if c not in ORIGIN_STATE_FEATURE_COLUMNS)
DEEP_NUMERIC_SIGNAL_FEATURE_COLUMNS = tuple(c for c in DEEP_MICRO_FEATURE_COLUMNS if c not in DEEP_STATE_FEATURE_COLUMNS)

H1_CATEGORICAL_COLUMNS = ("symbol", "level_id", "direction", "entry_policy", "analysis_weekday", "analysis_session", *ORIGIN_STATE_FEATURE_COLUMNS)
H1_NUMERIC_FEATURE_COLUMNS = ("tp_r_multiple", *ORIGIN_NUMERIC_SIGNAL_FEATURE_COLUMNS, "trigger_gap_to_risk", "spread_to_risk", "time_sin", "time_cos")
H1_MODEL_FEATURE_COLUMNS = H1_CATEGORICAL_COLUMNS + H1_NUMERIC_FEATURE_COLUMNS
DEEP_CATEGORICAL_COLUMNS = ("symbol", "level_id", "direction", "parent_kind", "parent_entry_policy", "analysis_weekday", "analysis_session", *DEEP_STATE_FEATURE_COLUMNS)
DEEP_NUMERIC_FEATURE_COLUMNS = ("tp_r_multiple", "parent_tp_r_multiple", "m10_parent_age_seconds", *DEEP_NUMERIC_SIGNAL_FEATURE_COLUMNS, "trigger_gap_to_risk", "spread_to_risk", "time_sin", "time_cos")
DEEP_MODEL_FEATURE_COLUMNS = DEEP_CATEGORICAL_COLUMNS + DEEP_NUMERIC_FEATURE_COLUMNS
CATEGORICAL_COLUMNS = H1_CATEGORICAL_COLUMNS
NUMERIC_FEATURE_COLUMNS = H1_NUMERIC_FEATURE_COLUMNS
MODEL_FEATURE_COLUMNS = H1_MODEL_FEATURE_COLUMNS
FEATURE_SET_COLUMNS = {SUPPORTED_FEATURE_SET_ID: H1_MODEL_FEATURE_COLUMNS, H1_FEATURE_SET_ID: H1_MODEL_FEATURE_COLUMNS, DEEP_FEATURE_SET_ID: DEEP_MODEL_FEATURE_COLUMNS}

IDENTITY_COLUMNS = ("schema_version", "run_id", "config_id", "window_id", "origin_id", "trial_id", "deep_event_id", "parent_link_id", "deep_trial_id", "symbol", "level_id", "direction")
TARGET_COLUMNS = ("virtual_binary_target", "terminal_status", "virtual_nominal_r", "virtual_quote_gross_profit", "virtual_quote_gross_r")
AUDIT_COLUMNS = ("entry_price", "stop_loss_price", "take_profit_price", "eligibility_status", "ineligible_reason", "observed_exit_price", "gap_points")
FUTURE_ONLY_COLUMNS = ("terminal_broker_time", "terminal_analysis_time", "terminal_status", "terminal_reason", "h1_structural_lifecycle_seconds", "deep_lifecycle_seconds", "virtual_nominal_r", "virtual_quote_gross_profit", "virtual_quote_gross_r", "virtual_binary_eligible", "virtual_binary_target", "virtual_exclusion_reason", "broker_close_price", "broker_gross_profit", "broker_commission", "broker_swap", "broker_fee", "broker_net_profit", "broker_binary_target", "broker_terminal_reason", "capacity_rejection_reason")

DATASET_CONFIG_KEYS = ("config_id", "engine_label", "macro_timeframe", "deep_timeframe", "micro_timeframe", "h1_entry_policies", "h1_tp_multiples", "deep_tp_multiples", "bands_period", "bands_deviation", "bands_ma_method", "bands_applied_price", "lot_mode", "lot_strategy_size", "reference_balance", "account_currency", "feature_set_id")

REQUIRED_MANIFEST_KEYS = {
    "run_id", "config_id", "started_broker_time", "symbol", "chart_period", "engine_id", "engine_label", "magic_namespace", "storage_root", "macro_timeframe", "deep_timeframe", "micro_timeframe", "pivot_formula", "source_policy", "origin_identity_policy", "trigger_policy", "pp_policy", "real_execution_policy", "h1_entry_policies", "h1_tp_multiples", "midpoint_policy", "reentry_policy", "deep_capture_policy", "deep_event_identity_policy", "deep_parent_policy", "deep_tp_multiples", "deep_geometry_policy", "deep_censor_policy", "deep_capacity_policy", "entry_quote_policy", "exit_quote_policy", "minimum_distance_policy", "h1_active_state_cap", "deep_event_active_cap", "deep_link_active_cap", "deep_trial_active_cap", "deep_outcome_active_cap", "bands_period", "bands_deviation", "bands_shift", "bands_ma_method", "bands_applied_price", "feature_capture_policy", "feature_price_policy", "feature_export_shifts", "feature_sma_period", "feature_state_tolerance", "stochastic_k_period", "stochastic_d_period", "stochastic_slowing", "stochastic_ma_method", "stochastic_price_field", "lot_mode", "lot_strategy_size", "reference_balance", "account_currency", "virtual_money_policy", "broker_money_policy", "duration_policy", "parity_policy", "time_policy", "broker_session", "feature_set_id", "research_approval_state",
}

FIXED_MANIFEST_VALUES = {
    "engine_id": "2", "engine_label": SUPPORTED_ENGINE_LABEL, "magic_namespace": "HFT_GRID_AI_PIVOT_FRACTAL_V13", "storage_root": STORAGE_ROOT,
    "pivot_formula": "CLASSIC_PP_S1_S3_R1_R3", "source_policy": "previous_completed_broker_candle_shift_1_per_macro_or_deep_window", "origin_identity_policy": "symbol,macro_timeframe,active_bar_open,level_first_trigger_once", "trigger_policy": "live_bid_virtual_limit_support_buy_resistance_sell", "pp_policy": "first_causal_bid_side_then_return_touch", "real_execution_policy": "single_structural_1r_fresh_quote_fok_immutable", "h1_entry_policies": "STRUCTURAL,MIDPOINT_50", "h1_tp_multiples": "1,2,3,5", "midpoint_policy": "exact_halfway_toward_next_outward_pivot_actual_entry_clock", "reentry_policy": "NONE", "deep_capture_policy": "active_same_direction_h1_parents_only_h1_terminal_before_deep_discovery", "deep_event_identity_policy": "symbol,deep_timeframe,active_bar_open,level_first_trigger_once_direction_outcome", "deep_parent_policy": "freeze_active_parent_set_no_retroactive_links", "deep_tp_multiples": "1,2,3", "deep_geometry_policy": "shared_event_next_outward_pivot_exact_integer_r", "deep_censor_policy": "parent_exit_or_run_end_never_binary_loss", "deep_capacity_policy": "atomic_event_links_three_trials_three_outcomes_per_link_or_capacity_rejected", "entry_quote_policy": "buy_ask_sell_bid", "exit_quote_policy": "buy_bid_sell_ask", "minimum_distance_policy": "risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick", "bands_period": "21", "bands_deviation": "2.0000", "bands_shift": "0", "bands_ma_method": "MODE_SMA", "bands_applied_price": "PRICE_WEIGHTED", "feature_capture_policy": "one_origin_macro_micro_snapshot_and_one_configured_micro_snapshot_per_deep_event", "feature_price_policy": "immutable_touched_pivot_for_b_percent_all_shifts", "feature_export_shifts": "0,1,2,3,4,5", "feature_sma_period": "5", "feature_state_tolerance": "0.0000001", "stochastic_k_period": "5", "stochastic_d_period": "3", "stochastic_slowing": "3", "stochastic_ma_method": "MODE_SMA", "stochastic_price_field": "STO_CLOSECLOSE", "reference_balance": "1000000.00000000", "virtual_money_policy": "order_calc_profit_counterfactual_gross_only", "broker_money_policy": "deal_history_authoritative_gross_commission_swap_fee_net", "duration_policy": "exact_nonnegative_broker_seconds_completed_h1_only_no_cap_no_rounding", "parity_policy": "one_exact_accepted_request_shadow_calibration_only", "time_policy": "broker_time_causal_analysis_time_export_only", "feature_set_id": SUPPORTED_FEATURE_SET_ID, "research_approval_state": "OFFLINE_RESEARCH_ONLY",
}


class SchemaValidationError(RuntimeError):
    """Raised when a run violates the strict V13 export contract."""


@dataclass(frozen=True)
class DatasetColumnGroups:
    feature_columns: tuple[str, ...] = H1_MODEL_FEATURE_COLUMNS
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

    def __getattr__(self, name: str) -> int:
        suffix = {
            "pivot_window_rows": PIVOT_WINDOWS_FILE,
            "signal_origin_rows": SIGNAL_ORIGINS_FILE,
            "virtual_trial_rows": VIRTUAL_TRIALS_FILE,
            "virtual_outcome_rows": VIRTUAL_OUTCOMES_FILE,
            "deep_event_rows": DEEP_PIVOT_EVENTS_FILE,
            "deep_parent_link_rows": DEEP_PIVOT_PARENT_LINKS_FILE,
            "deep_trial_rows": DEEP_VIRTUAL_TRIALS_FILE,
            "deep_outcome_rows": DEEP_VIRTUAL_OUTCOMES_FILE,
            "execution_check_rows": EXECUTION_CHECKS_FILE,
            "broker_outcome_rows": BROKER_OUTCOMES_FILE,
        }
        if name in suffix:
            return self.row_counts[suffix[name]]
        raise AttributeError(name)


def _require_active_schema(schema_version: int) -> None:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise ValueError(f"Unsupported schema version {schema_version}; active tooling accepts 13 only")


def expected_columns_for(filename: str, schema_version: int = SUPPORTED_SCHEMA_VERSION) -> tuple[str, ...]:
    _require_active_schema(schema_version)
    try:
        return TABLE_COLUMNS[filename]
    except KeyError as exc:
        raise ValueError(f"Unknown schema V13 file: {filename}") from exc


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


TIMESTAMP_COLUMNS = frozenset(c for columns in TABLE_COLUMNS.values() for c in columns if c.endswith("_time") or c in {"broker_time", "analysis_time"})
BOOLEAN_COLUMNS = frozenset({"account_expert_trade_allowed", "account_margin_mode_supported", "account_trade_allowed", "allowed", "broker_binary_eligible", "broker_close_confirmed", "broker_entry_confirmed", "close_reason_consistent", "deep_micro_features_complete", "distance_eligible", "first_touch_consistent", "fok_supported", "freeze_distance_valid", "geometry_valid", "h1_lanes_declared", "identity_consumed", "margin_valid", "market_session_open", "midpoint_touched", "mql_trade_allowed", "order_check_allowed", "order_check_performed", "origin_feature_snapshot_complete", "origin_macro_features_complete", "origin_micro_features_complete", "origin_window_active_at_entry", "protection_modified", "send_performed", "send_succeeded", "stop_distance_valid", "symbol_trade_mode_allowed", "terminal_trade_allowed", "virtual_binary_eligible", "virtual_money_plan_complete", "volume_valid"})
INTEGER_COLUMNS = frozenset({"account_margin_mode", "active_bar_open_offset_minutes", "active_parent_count", "broker_binary_target", "check_sequence", "close_deal_count", "close_offset_minutes", "deal_ticket", "declared_offset_minutes", "deep_event_active_cap", "deep_event_active_peak", "deep_event_admitted_rows", "deep_event_capacity_rejected_rows", "deep_event_rows", "deep_ineligible_rows", "deep_link_active_cap", "deep_link_active_peak", "deep_outcome_active_cap", "deep_outcome_active_peak", "deep_outcome_rows", "deep_parent_exit_censored_rows", "deep_run_censored_rows", "deep_sl_rows", "deep_tp_rows", "deep_trial_active_cap", "deep_trial_active_peak", "deep_trial_rows", "deep_window_rows", "duplicate_identity_count", "entry_deal_ticket", "entry_offset_minutes", "execution_check_rows", "finished_offset_minutes", "first_observed_offset_minutes", "h1_active_state_cap", "h1_active_state_peak", "h1_ineligible_rows", "h1_midpoint_trial_rows", "h1_not_triggered_rows", "h1_outcome_rows", "h1_run_censored_rows", "h1_sl_rows", "h1_structural_lifecycle_seconds", "h1_structural_trial_rows", "h1_tp_rows", "h1_trial_rows", "last_close_deal_ticket", "m10_parent_age_seconds", "macro_window_rows", "normalized_risk_ticks", "offset_minutes", "order_check_retcode", "order_ticket", "parent_tp_r_multiple", "parity_pair_rows", "parity_trial_rows", "pivot_window_rows", "position_identifier", "position_ticket", "pp_arm_offset_minutes", "referential_integrity_error_count", "required_link_slots", "required_outcome_slots", "required_trial_slots", "reserved_link_slots", "reserved_outcome_slots", "reserved_trial_slots", "row_integrity_error_count", "schema_version", "send_retcode", "signal_origin_rows", "source_bar_open_offset_minutes", "source_close_boundary_offset_minutes", "started_offset_minutes", "symbol_trade_mode", "terminal_offset_minutes", "tp_r_multiple", "trigger_offset_minutes", "virtual_binary_target", "deep_lifecycle_seconds"})
FLOAT_COLUMNS = frozenset({"account_balance", "ask", "bid", "broker_close_price", "broker_closed_volume", "broker_commission", "broker_entry_price", "broker_fee", "broker_gross_budget_r", "broker_gross_execution_r", "broker_gross_profit", "broker_net_budget_r", "broker_net_execution_r", "broker_net_profit", "broker_stop_loss", "broker_swap", "broker_take_profit", "broker_volume", "close_price", "closed_volume", "entry_ask", "entry_bid", "entry_price", "entry_slippage_points", "exit_slippage_points", "first_observed_bid", "free_margin", "freeze_distance_points", "freeze_level_points", "gap_points", "immutable_stop_loss", "immutable_take_profit", "lot_strategy_size", "midpoint_50_price", "minimum_risk_distance_points", "next_outward_pivot_price", "normalized_risk_distance_points", "normalized_risk_distance_price", "normalized_volume", "observed_exit_ask", "observed_exit_bid", "observed_exit_price", "pivot_raw_price", "pivot_trade_price", "point_size", "pp_arm_bid", "quote_expected_reward_risk_ratio", "quote_expected_stop_loss", "quote_expected_take_profit", "raw_pp_price", "raw_r1_price", "raw_r2_price", "raw_r3_price", "raw_s1_price", "raw_s2_price", "raw_s3_price", "reference_balance", "request_price_reward_risk_ratio", "request_reward_distance_points", "request_risk_distance_points", "requested_risk_distance_points", "requested_risk_distance_price", "requested_volume", "required_margin", "reward_distance_points", "risk_budget_amount", "risk_budget_utilization_ratio", "risk_distance_points", "source_close", "source_high", "source_low", "source_open", "source_range", "spread_points", "stop_loss_price", "stops_distance_points", "stops_level_points", "structural_entry_price", "structural_sl_price", "structural_take_profit", "submitted_request_price", "take_profit_price", "threshold_price", "trade_pp_price", "trade_r1_price", "trade_r2_price", "trade_r3_price", "trade_s1_price", "trade_s2_price", "trade_s3_price", "trade_tick_size", "trigger_ask", "trigger_bid", "virtual_expected_reward_risk_ratio", "virtual_expected_stop_loss", "virtual_expected_take_profit", "virtual_nominal_r", "virtual_quote_gross_profit", "virtual_quote_gross_r", "volume_max", "volume_min", "volume_step", *ORIGIN_NUMERIC_SIGNAL_FEATURE_COLUMNS, *DEEP_NUMERIC_SIGNAL_FEATURE_COLUMNS})
STRING_COLUMNS = frozenset(c for columns in TABLE_COLUMNS.values() for c in columns if c not in TIMESTAMP_COLUMNS and c not in BOOLEAN_COLUMNS and c not in INTEGER_COLUMNS and c not in FLOAT_COLUMNS)
COLUMN_TYPE_GROUPS = {"VARCHAR": STRING_COLUMNS, "TIMESTAMP": TIMESTAMP_COLUMNS, "BOOLEAN": BOOLEAN_COLUMNS, "BIGINT": INTEGER_COLUMNS, "DOUBLE": FLOAT_COLUMNS}


def _build_column_type_registry() -> dict[str, str]:
    schema_columns = {c for columns in TABLE_COLUMNS.values() for c in columns}
    registry: dict[str, str] = {}
    overlaps: set[str] = set()
    for kind, columns in COLUMN_TYPE_GROUPS.items():
        for column in columns:
            if column in registry:
                overlaps.add(column)
            registry[column] = kind
    missing = sorted(schema_columns - set(registry))
    unexpected = sorted(set(registry) - schema_columns)
    if overlaps or missing or unexpected:
        raise RuntimeError(f"Invalid V13 column type registry: overlaps={sorted(overlaps)}, missing={missing}, unexpected={unexpected}")
    return registry


COLUMN_TYPE_BY_NAME = _build_column_type_registry()
COLUMN_TYPE_REGISTRY_SHA256 = hashlib.sha256(json.dumps(COLUMN_TYPE_BY_NAME, sort_keys=True, separators=(",", ":")).encode("ascii")).hexdigest()


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
        raise SchemaValidationError(f"{context}: invalid integer {column}={value!r}") from exc


def _as_float(row: dict[str, str], column: str, context: str, *, nullable: bool = False) -> float | None:
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


def _as_bool(row: dict[str, str], column: str, context: str, *, nullable: bool = False) -> bool | None:
    value = row.get(column)
    if _is_null(value):
        if nullable:
            return None
        raise SchemaValidationError(f"{context}: required boolean is null: {column}")
    if value not in ("0", "1"):
        raise SchemaValidationError(f"{context}: invalid boolean {column}={value!r}")
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
        raise SchemaValidationError(f"{context}: invalid timestamp {column}={value!r}") from exc


def _same_number(left: float, right: float, tolerance: float = 1e-7) -> bool:
    return math.isclose(left, right, rel_tol=tolerance, abs_tol=tolerance)


def _normalize_risk_ticks_outward(requested_distance: float, trade_tick: float) -> int:
    requested_ticks = requested_distance / trade_tick
    nearest_ticks = round(requested_ticks)
    if nearest_ticks > 0 and abs(requested_ticks - nearest_ticks) <= RISK_TICK_TOLERANCE:
        risk_ticks = nearest_ticks
    else:
        risk_ticks = math.ceil(requested_ticks)
    risk_ticks = max(1, risk_ticks)
    if risk_ticks * trade_tick + trade_tick * RISK_TICK_TOLERANCE < requested_distance:
        risk_ticks += 1
    return risk_ticks


def _validate_time_triplet(row: dict[str, str], broker_column: str, analysis_column: str, offset_column: str, context: str, *, nullable: bool = False) -> tuple[datetime | None, datetime | None, int | None]:
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
        raise SchemaValidationError(f"Missing required schema V13 file: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        header = handle.readline().rstrip("\r\n").split("\t")
        if tuple(header) != expected_columns:
            raise SchemaValidationError(f"Header mismatch for {path.name}: expected {len(expected_columns)} exact columns, received {len(header)}")
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
        raise SchemaValidationError(f"Run must contain exactly twelve V13 TSV files; missing={sorted(expected_files - actual_files)}, unexpected={sorted(actual_files - expected_files)}")
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
            raise SchemaValidationError(f"Manifest fixed value mismatch: {key}={manifest[key]!r}, expected {expected!r}")
    macro, deep, micro = (manifest[key] for key in ("macro_timeframe", "deep_timeframe", "micro_timeframe"))
    if any(value not in TIMEFRAME_SECONDS for value in (macro, deep, micro)):
        raise SchemaValidationError("Manifest contains unsupported timeframe")
    if not TIMEFRAME_SECONDS[micro] < TIMEFRAME_SECONDS[deep] < TIMEFRAME_SECONDS[macro]:
        raise SchemaValidationError("Manifest requires Micro < Deep < Macro timeframe")
    if manifest["lot_mode"] not in (REFERENCE_LOT_MODE, FIXED_LOT_MODE):
        raise SchemaValidationError(f"Manifest has unsupported lot mode: {manifest['lot_mode']}")
    lot_size = float(manifest["lot_strategy_size"])
    if not math.isfinite(lot_size) or lot_size <= 0.0:
        raise SchemaValidationError("Manifest lot_strategy_size must be positive")
    if manifest["lot_mode"] == REFERENCE_LOT_MODE and lot_size > 100.0:
        raise SchemaValidationError("Manifest reference-balance percentage is out of range")
    _as_time({"started_broker_time": manifest["started_broker_time"]}, "started_broker_time", RUN_MANIFEST_FILE)
    return manifest


def _validate_common(row: dict[str, str], context: str, manifest: dict[str, str]) -> None:
    if _as_int(row, "schema_version", context) != SUPPORTED_SCHEMA_VERSION:
        raise SchemaValidationError(f"{context}: unsupported row schema version")
    if row.get("run_id") != manifest["run_id"] or row.get("config_id") != manifest["config_id"]:
        raise SchemaValidationError(f"{context}: run/config identity mismatch")


def _level_column(prefix: str, level_id: str) -> str:
    return f"{prefix}_{level_id.lower()}_price"


def _structural_stop(window: dict[str, str], level_id: str, direction: str) -> float:
    price = lambda level: float(window[_level_column("trade", level)])
    if direction == "BUY":
        return {"PP": price("S1"), "S1": price("S2"), "S2": price("S3"), "S3": price("S3") - (price("S2") - price("S3"))}[level_id]
    if direction == "SELL":
        return {"PP": price("R1"), "R1": price("R2"), "R2": price("R3"), "R3": price("R3") + (price("R3") - price("R2"))}[level_id]
    raise SchemaValidationError(f"No structural route for {direction} {level_id}")


def _next_outward(window: dict[str, str], level_id: str, direction: str) -> float:
    mapping = {("BUY", "PP"): "S1", ("BUY", "S1"): "S2", ("BUY", "S2"): "S3", ("BUY", "S3"): None, ("SELL", "PP"): "R1", ("SELL", "R1"): "R2", ("SELL", "R2"): "R3", ("SELL", "R3"): None}
    level = mapping.get((direction, level_id))
    if level is None:
        return float(window[_level_column("trade", "S3" if direction == "BUY" else "R3")])
    return float(window[_level_column("trade", level)])


def _feature_state(raw: float, sma: float) -> str:
    if raw - sma > FEATURE_STATE_TOLERANCE:
        return "ABOVE"
    if raw - sma < -FEATURE_STATE_TOLERANCE:
        return "BELOW"
    return "EQUAL"


def _validate_feature_family(
    row: dict[str, str],
    prefix: str,
    context: str,
    point_size: float,
    pivot_price: float,
) -> None:
    width = _as_float(row, f"{prefix}_band_width_points_0", context)
    assert width is not None and width > 0.0
    for series in SIGNAL_SERIES:
        raw = [_as_float(row, f"{prefix}_{series}_{shift}", context) for shift in FEATURE_SHIFTS]
        sma = [_as_float(row, f"{prefix}_{series}_sma_5_{shift}", context) for shift in FEATURE_SHIFTS]
        slope = [_as_float(row, f"{prefix}_{series}_sma_slope_{shift}", context) for shift in FEATURE_SHIFTS]
        assert all(value is not None for value in (*raw, *sma, *slope))
        raw_values = [float(value) for value in raw]
        if series.startswith("stochastic_") and any(value < -FEATURE_STATE_TOLERANCE or value > 100.0 + FEATURE_STATE_TOLERANCE for value in raw_values):
            raise SchemaValidationError(f"{context}: Stochastic line is outside 0..100")
        for shift in FEATURE_SHIFTS:
            if shift < 5 and not _same_number(
                float(slope[shift]),
                float(sma[shift]) - float(sma[shift + 1]),
            ):
                raise SchemaValidationError(f"{context}: {prefix} {series} SMA slope mismatch at shift {shift}")
            state = _require_value(row, f"{prefix}_{series}_state_{shift}", context)
            if state not in FEATURE_STATES or state != _feature_state(raw_values[shift], float(sma[shift])):
                raise SchemaValidationError(f"{context}: {prefix} {series} state mismatch at shift {shift}")
    base = [_as_float(row, f"{prefix}_band_base_line_{shift}", context) for shift in FEATURE_SHIFTS]
    slopes = [_as_float(row, f"{prefix}_band_base_line_slope_points_{shift}", context) for shift in FEATURE_SHIFTS]
    assert all(value is not None for value in (*base, *slopes))
    if any(float(value) <= 0.0 for value in base):
        raise SchemaValidationError(f"{context}: {prefix} Band BASE_LINE is not positive")
    expected_b_percent_0 = 50.0 + 100.0 * (
        pivot_price - float(base[0])
    ) / (width * point_size)
    if not _same_number(float(row[f"{prefix}_b_percent_0"]), expected_b_percent_0):
        raise SchemaValidationError(f"{context}: {prefix} B percent shift 0 formula mismatch")
    for shift in range(5):
        expected = (float(base[shift]) - float(base[shift + 1])) / point_size
        if not _same_number(float(slopes[shift]), expected):
            raise SchemaValidationError(f"{context}: {prefix} Band BASE_LINE slope mismatch at shift {shift}")


def _validate_features(
    row: dict[str, str],
    prefix: str,
    context: str,
    complete: bool,
    point_size: float,
    pivot_price: float,
) -> None:
    columns = ORIGIN_MICRO_FEATURE_COLUMNS if prefix == "origin_micro" else ORIGIN_MACRO_FEATURE_COLUMNS if prefix == "origin_macro" else DEEP_MICRO_FEATURE_COLUMNS
    null_count = sum(_is_null(row.get(column)) for column in columns)
    if not complete:
        if null_count != len(columns):
            raise SchemaValidationError(f"{context}: incomplete {prefix} features carry values")
        return
    if null_count:
        raise SchemaValidationError(f"{context}: complete {prefix} features are incomplete")
    _validate_feature_family(row, prefix, context, point_size, pivot_price)


def _validate_windows(rows: list[dict[str, str]], manifest: dict[str, str]) -> dict[str, dict[str, str]]:
    windows: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str]] = set()
    for index, row in enumerate(rows, start=2):
        context = f"{PIVOT_WINDOWS_FILE}:{index}"
        _validate_common(row, context, manifest)
        window_id = _require_value(row, "window_id", context)
        if window_id in windows:
            raise SchemaValidationError(f"Duplicate window_id: {window_id}")
        scope = _require_value(row, "window_scope", context)
        timeframe = _require_value(row, "timeframe", context)
        if scope not in ("MACRO", "DEEP") or timeframe not in TIMEFRAME_SECONDS:
            raise SchemaValidationError(f"{context}: invalid window scope/timeframe")
        expected_tf = manifest["macro_timeframe"] if scope == "MACRO" else manifest["deep_timeframe"]
        if timeframe != expected_tf:
            raise SchemaValidationError(f"{context}: window timeframe differs from manifest")
        active, _, _ = _validate_time_triplet(row, "active_bar_open_broker_time", "active_bar_open_analysis_time", "active_bar_open_offset_minutes", context)
        source, _, _ = _validate_time_triplet(row, "source_bar_open_broker_time", "source_bar_open_analysis_time", "source_bar_open_offset_minutes", context)
        close, _, _ = _validate_time_triplet(row, "source_close_boundary_broker_time", "source_close_boundary_analysis_time", "source_close_boundary_offset_minutes", context)
        terminal, _, _ = _validate_time_triplet(row, "terminal_broker_time", "terminal_analysis_time", "terminal_offset_minutes", context)
        assert active and source and close and terminal
        if not source < close == active <= terminal:
            raise SchemaValidationError(f"{context}: source/window times are not causal")
        identity = (row["symbol"], timeframe, row["active_bar_open_broker_time"])
        if identity in identities:
            raise SchemaValidationError(f"{context}: duplicate window identity")
        identities.add(identity)
        high, low, close_price = (_as_float(row, key, context) for key in ("source_high", "source_low", "source_close"))
        source_range = _as_float(row, "source_range", context)
        assert high is not None and low is not None and close_price is not None and source_range is not None
        if high <= low or not low <= close_price <= high or not _same_number(source_range, high - low):
            raise SchemaValidationError(f"{context}: invalid source OHLC")
        pp = (high + low + close_price) / 3.0
        expected = {"PP": pp, "S1": 2 * pp - high, "S2": pp - source_range, "S3": low - 2 * (high - pp), "R1": 2 * pp - low, "R2": pp + source_range, "R3": high + 2 * (pp - low)}
        for level, value in expected.items():
            actual = _as_float(row, _level_column("raw", level), context)
            assert actual is not None
            if not _same_number(actual, value):
                raise SchemaValidationError(f"{context}: classic pivot formula mismatch for {level}")
        trade = [_as_float(row, _level_column("trade", level), context) for level in PIVOT_LEVELS]
        assert all(value is not None for value in trade)
        if any(left >= right for left, right in zip(trade, trade[1:])):
            raise SchemaValidationError(f"{context}: collapsed or unordered trade pivot ladder")
        first, _, _ = _validate_time_triplet(row, "first_observed_broker_time", "first_observed_analysis_time", "first_observed_offset_minutes", context)
        first_bid = _as_float(row, "first_observed_bid", context)
        assert first and first_bid is not None
        if not active <= first < terminal or first_bid <= 0.0:
            raise SchemaValidationError(f"{context}: first observation outside window")
        relation = "ABOVE" if first_bid > float(row["trade_pp_price"]) else "BELOW" if first_bid < float(row["trade_pp_price"]) else "EQUAL"
        if row["pp_initial_relation"] != relation:
            raise SchemaValidationError(f"{context}: PP initial relation mismatch")
        arm, _, _ = _validate_time_triplet(row, "pp_arm_broker_time", "pp_arm_analysis_time", "pp_arm_offset_minutes", context, nullable=True)
        arm_bid = _as_float(row, "pp_arm_bid", context, nullable=True)
        role = row["pp_role"]
        if role not in ("BUY", "SELL", "UNARMED"):
            raise SchemaValidationError(f"{context}: invalid PP role")
        if role == "UNARMED" and (arm is not None or arm_bid is not None):
            raise SchemaValidationError(f"{context}: unarmed PP has arm facts")
        if role != "UNARMED" and (arm is None or arm_bid is None or not first <= arm < terminal):
            raise SchemaValidationError(f"{context}: armed PP lacks causal arm facts")
        if row["window_state"] != "VALID" or not _is_null(row["invalid_reason"]):
            raise SchemaValidationError(f"{context}: exported window is not valid")
        if row["terminal_status"] not in ("EXPIRED", "RUN_FINISHED"):
            raise SchemaValidationError(f"{context}: invalid window terminal status")
        windows[window_id] = row
    return windows


def _validate_origins(rows: list[dict[str, str]], manifest: dict[str, str], windows: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    origins: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str, str]] = set()
    for index, row in enumerate(rows, start=2):
        context = f"{SIGNAL_ORIGINS_FILE}:{index}"
        _validate_common(row, context, manifest)
        origin_id = _require_value(row, "origin_id", context)
        if origin_id in origins:
            raise SchemaValidationError(f"Duplicate origin_id: {origin_id}")
        window = windows.get(_require_value(row, "window_id", context))
        if window is None or row["macro_timeframe"] != manifest["macro_timeframe"] or row["deep_timeframe"] != manifest["deep_timeframe"] or row["micro_timeframe"] != manifest["micro_timeframe"]:
            raise SchemaValidationError(f"{context}: origin timeframe/window mismatch")
        if row["active_bar_open_broker_time"] != window["active_bar_open_broker_time"]:
            raise SchemaValidationError(f"{context}: origin active bar differs from window")
        level, direction = row["level_id"], row["direction"]
        if level not in PIVOT_LEVELS or direction not in ("BUY", "SELL") or (level in SUPPORT_LEVELS and direction != "BUY") or (level in RESISTANCE_LEVELS and direction != "SELL"):
            raise SchemaValidationError(f"{context}: invalid pivot level/direction")
        identity = (row["symbol"], row["macro_timeframe"], row["active_bar_open_broker_time"], level)
        if identity in identities:
            raise SchemaValidationError(f"{context}: duplicate consumed pivot identity")
        identities.add(identity)
        trigger, _, _ = _validate_time_triplet(row, "trigger_broker_time", "trigger_analysis_time", "trigger_offset_minutes", context)
        assert trigger is not None
        active = _as_time(window, "active_bar_open_broker_time", context)
        terminal = _as_time(window, "terminal_broker_time", context)
        assert active and terminal
        if not active <= trigger < terminal:
            raise SchemaValidationError(f"{context}: trigger outside window")
        point = _as_float(row, "point_size", context)
        bid = _as_float(row, "trigger_bid", context)
        ask = _as_float(row, "trigger_ask", context)
        spread = _as_float(row, "spread_points", context)
        assert point and bid and ask and spread
        if point <= 0 or bid <= 0 or ask < bid or not _same_number(spread, (ask - bid) / point):
            raise SchemaValidationError(f"{context}: invalid broker facts")
        for level_name in PIVOT_LEVELS:
            for prefix in ("raw", "trade"):
                column = _level_column(prefix, level_name)
                if not _same_number(float(row[column]), float(window[column])):
                    raise SchemaValidationError(f"{context}: origin pivot ladder differs from window")
        pivot_raw = _as_float(row, "pivot_raw_price", context)
        pivot_trade = _as_float(row, "pivot_trade_price", context)
        boundary = _as_float(row, "next_outward_pivot_price", context)
        midpoint = _as_float(row, "midpoint_50_price", context)
        assert pivot_raw is not None and pivot_trade is not None and boundary is not None and midpoint is not None
        if not _same_number(pivot_raw, float(window[_level_column("raw", level)])) or not _same_number(pivot_trade, float(window[_level_column("trade", level)])):
            raise SchemaValidationError(f"{context}: pivot price mismatch")
        expected_boundary = _structural_stop(window, level, direction)
        if not _same_number(boundary, expected_boundary):
            raise SchemaValidationError(f"{context}: next outward pivot mismatch")
        expected_midpoint = pivot_trade + 0.5 * (boundary - pivot_trade)
        if not _same_number(midpoint, expected_midpoint):
            raise SchemaValidationError(f"{context}: exact midpoint geometry mismatch")
        entry = _as_float(row, "structural_entry_price", context)
        stop = _as_float(row, "structural_sl_price", context)
        take_profit = _as_float(row, "structural_take_profit", context)
        assert entry is not None and stop is not None and take_profit is not None
        expected_entry = ask if direction == "BUY" else bid
        expected_stop = _structural_stop(window, level, direction)
        expected_tp = expected_entry + (expected_entry - expected_stop) if direction == "BUY" else expected_entry - (expected_stop - expected_entry)
        if not _same_number(entry, expected_entry) or not _same_number(stop, expected_stop) or not _same_number(take_profit, expected_tp):
            raise SchemaValidationError(f"{context}: structural route mismatch")
        micro_complete = bool(_as_bool(row, "origin_micro_features_complete", context))
        macro_complete = bool(_as_bool(row, "origin_macro_features_complete", context))
        snapshot_complete = bool(_as_bool(row, "origin_feature_snapshot_complete", context))
        if snapshot_complete != (micro_complete and macro_complete):
            raise SchemaValidationError(f"{context}: origin feature completeness mismatch")
        _validate_features(
            row,
            "origin_micro",
            context,
            micro_complete,
            point,
            pivot_trade,
        )
        _validate_features(
            row,
            "origin_macro",
            context,
            macro_complete,
            point,
            pivot_trade,
        )
        if snapshot_complete != _is_null(row["origin_feature_invalid_reason"]):
            raise SchemaValidationError(f"{context}: invalid origin feature reason state")
        if not _as_bool(row, "identity_consumed", context) or not _as_bool(row, "h1_lanes_declared", context):
            raise SchemaValidationError(f"{context}: origin identity/lanes not declared")
        if row["broker_attempt_status"] not in ("NOT_EVALUATED", "BLOCKED", "SEND_FAILED", "SENT", "FILLED", "CLOSED", "CENSORED"):
            raise SchemaValidationError(f"{context}: invalid broker attempt status")
        if row["origin_terminal_status"] not in ("WINDOW_EXPIRED", "RUN_FINISHED"):
            raise SchemaValidationError(f"{context}: invalid origin terminal status")
        origins[origin_id] = row
    return origins


def _validate_trials(rows: list[dict[str, str]], manifest: dict[str, str], origins: dict[str, dict[str, str]], windows: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    trials: dict[str, dict[str, str]] = {}
    by_origin: dict[str, list[dict[str, str]]] = {}
    for index, row in enumerate(rows, start=2):
        context = f"{VIRTUAL_TRIALS_FILE}:{index}"
        _validate_common(row, context, manifest)
        trial_id = _require_value(row, "trial_id", context)
        if trial_id in trials:
            raise SchemaValidationError(f"Duplicate trial_id: {trial_id}")
        origin = origins.get(_require_value(row, "origin_id", context))
        if origin is None or row["window_id"] not in windows:
            raise SchemaValidationError(f"{context}: trial references unknown origin/window")
        role = row["trial_role"]
        if role == "BROKER_PARITY":
            if (
                row["entry_policy"] != "STRUCTURAL"
                or int(row["tp_r_multiple"]) != 1
                or row["parity_trial_id"] != trial_id
                or _is_null(row["broker_signal_id"])
            ):
                raise SchemaValidationError(f"{context}: parity must shadow structural 1R")
        elif role == "H1":
            if (
                row["entry_policy"] not in H1_ENTRY_POLICIES
                or int(row["tp_r_multiple"]) not in H1_TP_R_MULTIPLES
                or not _is_null(row["parity_trial_id"])
                or not _is_null(row["broker_signal_id"])
            ):
                raise SchemaValidationError(f"{context}: invalid H1 lane identity")
            by_origin.setdefault(row["origin_id"], []).append(row)
        else:
            raise SchemaValidationError(f"{context}: invalid trial role")
        if row["direction"] != origin["direction"] or row["level_id"] != origin["level_id"]:
            raise SchemaValidationError(f"{context}: trial direction/level mismatch")
        if role == "H1" and row["entry_policy"] == "MIDPOINT_50" and row["midpoint_50_price"] != origin["midpoint_50_price"]:
            raise SchemaValidationError(f"{context}: midpoint lane does not use origin midpoint")
        midpoint_touched = bool(_as_bool(row, "midpoint_touched", context))
        if row["entry_policy"] == "STRUCTURAL" and not midpoint_touched:
            raise SchemaValidationError(f"{context}: structural lane cannot be pending")
        entry_time, _, _ = _validate_time_triplet(
            row,
            "entry_broker_time",
            "entry_analysis_time",
            "entry_offset_minutes",
            context,
            nullable=not midpoint_touched,
        )
        pending_midpoint = row["entry_policy"] == "MIDPOINT_50" and not midpoint_touched
        entry = _as_float(row, "entry_price", context, nullable=pending_midpoint)
        bid = _as_float(row, "entry_bid", context, nullable=pending_midpoint)
        ask = _as_float(row, "entry_ask", context, nullable=pending_midpoint)
        point = _as_float(row, "point_size", context)
        spread = _as_float(row, "spread_points", context)
        if pending_midpoint:
            pending_columns = (
                "entry_bid", "entry_ask", "entry_price", "entry_quote_side",
                "exit_quote_side", "requested_risk_distance_price",
                "requested_risk_distance_points", "normalized_risk_ticks",
                "normalized_risk_distance_price", "normalized_risk_distance_points",
                "stop_loss_price", "take_profit_price", "geometry_equivalence_id",
                "minimum_risk_distance_points", "risk_budget_amount", "requested_volume",
                "normalized_volume", "virtual_expected_stop_loss",
                "virtual_expected_take_profit", "virtual_expected_reward_risk_ratio",
            )
            if entry_time is not None or any(not _is_null(row[column]) for column in pending_columns):
                raise SchemaValidationError(f"{context}: pending midpoint carries entry/geometry")
            pending_quote_facts = (
                spread,
                point,
                _as_float(row, "trade_tick_size", context),
                _as_float(row, "stops_level_points", context),
                _as_float(row, "freeze_level_points", context),
            )
            if any(value is None or not _same_number(value, 0.0) for value in pending_quote_facts):
                raise SchemaValidationError(f"{context}: pending midpoint carries pre-entry quote facts")
            if (
                _as_bool(row, "distance_eligible", context)
                or _as_bool(row, "virtual_money_plan_complete", context)
                or _as_bool(row, "origin_window_active_at_entry", context)
            ):
                raise SchemaValidationError(f"{context}: pending midpoint carries active entry state")
            if row["eligibility_status"] != "NOT_TRIGGERED":
                raise SchemaValidationError(f"{context}: pending midpoint must be NOT_TRIGGERED")
            trials[trial_id] = row
            continue
        if point is None or point <= 0.0 or spread is None:
            raise SchemaValidationError(f"{context}: invalid entry quote facts")
        assert entry_time and entry and bid and ask
        if not _same_number(spread, (ask - bid) / point):
            raise SchemaValidationError(f"{context}: spread arithmetic mismatch")
        if row["entry_quote_side"] != ("ASK" if row["direction"] == "BUY" else "BID") or row["exit_quote_side"] != ("BID" if row["direction"] == "BUY" else "ASK"):
            raise SchemaValidationError(f"{context}: wrong quote side")
        if not _same_number(entry, ask if row["direction"] == "BUY" else bid):
            raise SchemaValidationError(f"{context}: entry price differs from executable quote")
        if row["entry_policy"] == "MIDPOINT_50":
            midpoint = float(origin["midpoint_50_price"])
            if (row["direction"] == "BUY" and bid > midpoint) or (
                row["direction"] == "SELL" and bid < midpoint
            ):
                raise SchemaValidationError(f"{context}: midpoint touch condition is not proven")
        eligibility = row["eligibility_status"]
        geometry = ("requested_risk_distance_price", "requested_risk_distance_points", "normalized_risk_ticks", "normalized_risk_distance_price", "normalized_risk_distance_points", "stop_loss_price", "take_profit_price", "geometry_equivalence_id", "minimum_risk_distance_points")
        if eligibility != "ACTIVE":
            if any(not _is_null(row[column]) for column in geometry if column != "geometry_equivalence_id") or not _is_null(row["geometry_equivalence_id"]):
                raise SchemaValidationError(f"{context}: ineligible trial carries geometry")
        else:
            for column in geometry:
                _require_value(row, column, context)
            stop = float(row["stop_loss_price"])
            risk = abs(entry - stop)
            if role == "H1" and not _same_number(stop, float(origin["next_outward_pivot_price"])):
                raise SchemaValidationError(f"{context}: H1 stop differs from next outward pivot")
            if risk <= 0:
                raise SchemaValidationError(f"{context}: active trial has no risk")
            expected_tp = entry + int(row["tp_r_multiple"]) * risk if row["direction"] == "BUY" else entry - int(row["tp_r_multiple"]) * risk
            if not _same_number(float(row["take_profit_price"]), expected_tp):
                raise SchemaValidationError(f"{context}: exact-R target mismatch")
        trials[trial_id] = row
    for origin_id, origin in origins.items():
        lanes = by_origin.get(origin_id, [])
        if len(lanes) != H1_MATRIX_SIZE:
            raise SchemaValidationError(f"Origin {origin_id}: exactly eight H1 lane declarations required")
        identities = [(row["entry_policy"], int(row["tp_r_multiple"])) for row in lanes]
        expected = [(policy, ratio) for policy in H1_ENTRY_POLICIES for ratio in H1_TP_R_MULTIPLES]
        if sorted(identities) != sorted(expected):
            raise SchemaValidationError(f"Origin {origin_id}: H1 lane matrix is incomplete or duplicated")
    return trials


def _validate_outcomes(rows: list[dict[str, str]], manifest: dict[str, str], trials: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    outcomes: dict[str, dict[str, str]] = {}
    trial_ids: set[str] = set()
    for index, row in enumerate(rows, start=2):
        context = f"{VIRTUAL_OUTCOMES_FILE}:{index}"
        _validate_common(row, context, manifest)
        outcome_id = _require_value(row, "outcome_id", context)
        trial_id = _require_value(row, "trial_id", context)
        if outcome_id in outcomes or trial_id in trial_ids or trial_id not in trials:
            raise SchemaValidationError(f"{context}: duplicate outcome or unknown trial")
        trial = trials[trial_id]
        trial_ids.add(trial_id)
        for column in (
            "parity_trial_id",
            "origin_id",
            "window_id",
            "trial_role",
            "entry_policy",
            "tp_r_multiple",
            "direction",
        ):
            if row[column] != trial[column]:
                raise SchemaValidationError(f"{context}: H1 outcome identity mismatch")
        status = row["terminal_status"]
        if status not in ("TP_FIRST", "SL_FIRST", "NOT_TRIGGERED", "INELIGIBLE", "CENSORED_RUN_END"):
            raise SchemaValidationError(f"{context}: invalid H1 terminal status")
        duration = _as_int(row, "h1_structural_lifecycle_seconds", context, nullable=True)
        if status in ("TP_FIRST", "SL_FIRST") and (duration is None or duration < 0):
            raise SchemaValidationError(f"{context}: completed H1 outcome lacks lifecycle seconds")
        if status in ("NOT_TRIGGERED", "INELIGIBLE", "CENSORED_RUN_END") and duration is not None:
            raise SchemaValidationError(f"{context}: non-completed H1 outcome carries lifecycle seconds")
        terminal_time, _, _ = _validate_time_triplet(
            row,
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_offset_minutes",
            context,
        )
        entry_time = _as_time(trial, "entry_broker_time", context, nullable=True)
        assert terminal_time is not None
        observed_bid = _as_float(row, "observed_exit_bid", context)
        observed_ask = _as_float(row, "observed_exit_ask", context)
        observed_price = _as_float(row, "observed_exit_price", context)
        point = _as_float(trial, "point_size", context)
        assert observed_bid is not None and observed_ask is not None
        assert observed_price is not None and point is not None
        expected_exit_side = "BID" if row["direction"] == "BUY" else "ASK"
        expected_exit_price = observed_bid if row["direction"] == "BUY" else observed_ask
        if (
            observed_bid <= 0.0
            or observed_ask < observed_bid
            or row["exit_quote_side"] != expected_exit_side
            or not _same_number(observed_price, expected_exit_price)
            or not _as_bool(row, "first_touch_consistent", context)
        ):
            raise SchemaValidationError(f"{context}: invalid H1 observed exit facts")
        if status in ("TP_FIRST", "SL_FIRST"):
            assert entry_time is not None and duration is not None
            if terminal_time <= entry_time or duration != int((terminal_time - entry_time).total_seconds()):
                raise SchemaValidationError(f"{context}: H1 lifecycle seconds mismatch")
            if trial["eligibility_status"] != "ACTIVE":
                raise SchemaValidationError(f"{context}: completed H1 outcome references inactive trial")
            threshold = _as_float(row, "threshold_price", context)
            gap = _as_float(row, "gap_points", context)
            nominal_r = _as_float(row, "virtual_nominal_r", context)
            gross_profit = _as_float(row, "virtual_quote_gross_profit", context)
            gross_r = _as_float(row, "virtual_quote_gross_r", context)
            assert threshold is not None and gap is not None and nominal_r is not None
            assert gross_profit is not None and gross_r is not None
            expected_threshold = float(
                trial["take_profit_price"] if status == "TP_FIRST" else trial["stop_loss_price"]
            )
            expected_nominal_r = float(trial["tp_r_multiple"]) if status == "TP_FIRST" else -1.0
            expected_target = 1 if status == "TP_FIRST" else 0
            expected_reason = "TP_THRESHOLD" if status == "TP_FIRST" else "SL_THRESHOLD"
            expected_stop_loss = abs(float(trial["virtual_expected_stop_loss"]))
            if (
                row["terminal_reason"] != expected_reason
                or not _same_number(threshold, expected_threshold)
                or not _same_number(gap, abs(observed_price - threshold) / point)
                or not _same_number(nominal_r, expected_nominal_r)
                or expected_stop_loss <= 0.0
                or not _same_number(gross_r, gross_profit / expected_stop_loss)
                or not _is_null(row["virtual_exclusion_reason"])
            ):
                raise SchemaValidationError(f"{context}: H1 outcome arithmetic mismatch")
            if row["direction"] == "BUY":
                threshold_touched = observed_price >= threshold if status == "TP_FIRST" else observed_price <= threshold
            else:
                threshold_touched = observed_price <= threshold if status == "TP_FIRST" else observed_price >= threshold
            if not threshold_touched:
                raise SchemaValidationError(f"{context}: H1 threshold touch is not proven")
        else:
            terminal_only = (
                "threshold_price",
                "gap_points",
                "h1_structural_lifecycle_seconds",
                "virtual_nominal_r",
                "virtual_quote_gross_profit",
                "virtual_quote_gross_r",
            )
            if any(not _is_null(row[column]) for column in terminal_only):
                raise SchemaValidationError(f"{context}: non-completed H1 outcome carries terminal arithmetic")
            expected_eligibility = {
                "NOT_TRIGGERED": "NOT_TRIGGERED",
                "INELIGIBLE": trial["eligibility_status"],
                "CENSORED_RUN_END": "ACTIVE",
            }[status]
            if trial["eligibility_status"] != expected_eligibility:
                raise SchemaValidationError(f"{context}: H1 terminal status/trial eligibility mismatch")
            if _is_null(row["virtual_exclusion_reason"]):
                raise SchemaValidationError(f"{context}: excluded H1 outcome lacks reason")
        if status == "NOT_TRIGGERED" and bool(_as_bool(trial, "midpoint_touched", context)):
            raise SchemaValidationError(f"{context}: touched midpoint cannot be NOT_TRIGGERED")
        eligible = bool(_as_bool(row, "virtual_binary_eligible", context))
        target = _as_int(row, "virtual_binary_target", context, nullable=True)
        expected_target = 1 if status == "TP_FIRST" else 0 if status == "SL_FIRST" else None
        if eligible != (status in ("TP_FIRST", "SL_FIRST")) or target != expected_target:
            raise SchemaValidationError(f"{context}: H1 binary eligibility/status mismatch")
        outcomes[outcome_id] = row
    if trial_ids != set(trials):
        raise SchemaValidationError("Every H1/parity trial must have exactly one outcome")
    return outcomes


def _validate_broker_outcomes(
    rows: list[dict[str, str]],
    manifest: dict[str, str],
    origins: dict[str, dict[str, str]],
    trials: dict[str, dict[str, str]],
    outcomes: dict[str, dict[str, str]],
) -> dict[str, dict[str, str]]:
    broker_outcomes: dict[str, dict[str, str]] = {}
    outcome_by_trial = {row["trial_id"]: row for row in outcomes.values()}
    outcome_ids: set[str] = set()
    for index, row in enumerate(rows, start=2):
        context = f"{BROKER_OUTCOMES_FILE}:{index}"
        _validate_common(row, context, manifest)
        outcome_id = _require_value(row, "broker_outcome_id", context)
        broker_signal_id = _require_value(row, "broker_signal_id", context)
        origin = origins.get(_require_value(row, "origin_id", context))
        if (
            outcome_id in outcome_ids
            or broker_signal_id in broker_outcomes
            or origin is None
        ):
            raise SchemaValidationError(f"{context}: duplicate/unknown broker outcome")
        outcome_ids.add(outcome_id)
        for column in (
            "window_id",
            "symbol",
            "macro_timeframe",
            "deep_timeframe",
            "micro_timeframe",
            "active_bar_open_broker_time",
            "level_id",
            "direction",
        ):
            origin_column = "window_id" if column == "window_id" else column
            if row[column] != origin[origin_column]:
                raise SchemaValidationError(f"{context}: broker outcome identity mismatch")
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
        duration = _as_int(row, "h1_structural_lifecycle_seconds", context)
        assert entry_time is not None and close_time is not None and duration is not None
        if (
            close_time <= entry_time
            or duration != int((close_time - entry_time).total_seconds())
            or not _as_bool(row, "broker_entry_confirmed", context)
            or not _as_bool(row, "broker_close_confirmed", context)
            or int(_require_value(row, "close_deal_count", context)) <= 0
        ):
            raise SchemaValidationError(f"{context}: incomplete broker lifecycle")
        parity_trial_id = _require_value(row, "parity_trial_id", context)
        parity_trial = trials.get(parity_trial_id)
        parity_outcome = outcome_by_trial.get(parity_trial_id)
        if (
            parity_trial is None
            or parity_outcome is None
            or parity_trial["trial_role"] != "BROKER_PARITY"
            or parity_trial["origin_id"] != row["origin_id"]
            or parity_trial["broker_signal_id"] != broker_signal_id
            or parity_trial["parity_trial_id"] != parity_trial_id
        ):
            raise SchemaValidationError(f"{context}: broker parity reference mismatch")
        request_risk = _as_float(row, "request_risk_distance_points", context)
        request_reward = _as_float(row, "request_reward_distance_points", context)
        request_ratio = _as_float(row, "request_price_reward_risk_ratio", context)
        assert request_risk is not None and request_reward is not None and request_ratio is not None
        if (
            request_risk <= 0.0
            or not _same_number(request_reward, request_risk)
            or not _same_number(request_ratio, 1.0)
        ):
            raise SchemaValidationError(f"{context}: broker request is not structural 1R")
        terminal_reason = _require_value(row, "broker_terminal_reason", context)
        binary_eligible = bool(_as_bool(row, "broker_binary_eligible", context))
        binary_target = _as_int(row, "broker_binary_target", context, nullable=True)
        expected_target = 1 if terminal_reason == "BROKER_TP" else 0 if terminal_reason == "BROKER_SL" else None
        expected_eligible = (
            expected_target is not None
            and bool(_as_bool(row, "close_reason_consistent", context))
            and bool(_as_bool(origin, "origin_feature_snapshot_complete", context))
        )
        if (
            binary_eligible != expected_eligible
            or binary_target != (expected_target if expected_eligible else None)
            or (binary_eligible and not _is_null(row["broker_exclusion_reason"]))
            or (not binary_eligible and _is_null(row["broker_exclusion_reason"]))
        ):
            raise SchemaValidationError(f"{context}: broker binary evidence mismatch")
        broker_outcomes[broker_signal_id] = row
    return broker_outcomes


def _validate_deep(
    rows: dict[str, list[dict[str, str]]],
    manifest: dict[str, str],
    windows: dict[str, dict[str, str]],
    origins: dict[str, dict[str, str]],
    trials: dict[str, dict[str, str]],
    outcomes: dict[str, dict[str, str]],
    broker_outcomes: dict[str, dict[str, str]],
) -> None:
    outcome_by_trial = {row["trial_id"]: row for row in outcomes.values()}
    parent_terminal_by_link: dict[str, datetime | None] = {}
    closed_parent_links: set[str] = set()
    fill_times: dict[tuple[str, str], datetime] = {}
    for check in rows[EXECUTION_CHECKS_FILE]:
        if check["broker_entry_confirmed"] != "1":
            continue
        fill_key = (check["origin_id"], check["broker_signal_id"])
        fill_time = _as_time(check, "broker_time", EXECUTION_CHECKS_FILE)
        assert fill_time is not None
        if fill_key not in fill_times or fill_time < fill_times[fill_key]:
            fill_times[fill_key] = fill_time
    events: dict[str, dict[str, str]] = {}
    identities: set[tuple[str, str, str, str]] = set()
    for index, row in enumerate(rows[DEEP_PIVOT_EVENTS_FILE], start=2):
        context = f"{DEEP_PIVOT_EVENTS_FILE}:{index}"
        _validate_common(row, context, manifest)
        event_id = _require_value(row, "deep_event_id", context)
        identity = (row["symbol"], row["deep_timeframe"], row["active_deep_bar_open_broker_time"], row["level_id"])
        if event_id in events or identity in identities:
            raise SchemaValidationError(f"{context}: duplicate deep event identity")
        identities.add(identity)
        window = windows.get(_require_value(row, "deep_window_id", context))
        level = row["level_id"]
        direction = row["direction"]
        if (
            window is None
            or window["window_scope"] != "DEEP"
            or row["symbol"] != manifest["symbol"]
            or row["symbol"] != window["symbol"]
            or row["deep_timeframe"] != manifest["deep_timeframe"]
            or row["deep_timeframe"] != window["timeframe"]
            or row["micro_timeframe"] != manifest["micro_timeframe"]
            or row["active_deep_bar_open_broker_time"] != window["active_bar_open_broker_time"]
            or level not in PIVOT_LEVELS
            or direction not in ("BUY", "SELL")
            or (level in SUPPORT_LEVELS and direction != "BUY")
            or (level in RESISTANCE_LEVELS and direction != "SELL")
        ):
            raise SchemaValidationError(f"{context}: invalid deep event identity")
        if level == "PP" and window["pp_role"] != direction:
            raise SchemaValidationError(f"{context}: deep PP direction differs from armed role")
        trigger_time, _, _ = _validate_time_triplet(
            row,
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
            context,
        )
        active_time = _as_time(window, "active_bar_open_broker_time", context)
        terminal_time = _as_time(window, "terminal_broker_time", context)
        assert trigger_time is not None and active_time is not None and terminal_time is not None
        if not active_time <= trigger_time < terminal_time:
            raise SchemaValidationError(f"{context}: deep trigger outside referenced window")
        point = _as_float(row, "point_size", context)
        trade_tick = _as_float(row, "trade_tick_size", context)
        bid = _as_float(row, "trigger_bid", context)
        ask = _as_float(row, "trigger_ask", context)
        spread = _as_float(row, "spread_points", context)
        stops = _as_float(row, "stops_level_points", context)
        freeze = _as_float(row, "freeze_level_points", context)
        assert point is not None and trade_tick is not None and bid is not None
        assert ask is not None and spread is not None and stops is not None and freeze is not None
        if (
            point <= 0.0
            or trade_tick <= 0.0
            or bid <= 0.0
            or ask < bid
            or stops < 0.0
            or freeze < 0.0
            or not _same_number(spread, (ask - bid) / point)
        ):
            raise SchemaValidationError(f"{context}: invalid deep broker facts")
        pivot_raw = _as_float(row, "pivot_raw_price", context)
        pivot_trade = _as_float(row, "pivot_trade_price", context)
        boundary = _as_float(row, "next_outward_pivot_price", context)
        assert pivot_raw is not None and pivot_trade is not None and boundary is not None
        if (
            not _same_number(pivot_raw, float(window[_level_column("raw", level)]))
            or not _same_number(pivot_trade, float(window[_level_column("trade", level)]))
            or not _same_number(boundary, _structural_stop(window, level, direction))
        ):
            raise SchemaValidationError(f"{context}: deep pivot/window geometry mismatch")
        if (direction == "BUY" and bid > pivot_trade) or (
            direction == "SELL" and bid < pivot_trade
        ):
            raise SchemaValidationError(f"{context}: deep trigger touch is not proven")
        features_complete = bool(_as_bool(row, "deep_micro_features_complete", context))
        _validate_features(
            row,
            "deep_micro",
            context,
            features_complete,
            point,
            pivot_trade,
        )
        if features_complete != _is_null(row["deep_feature_invalid_reason"]):
            raise SchemaValidationError(f"{context}: invalid deep feature reason state")
        if not _as_bool(row, "identity_consumed", context):
            raise SchemaValidationError(f"{context}: deep identity is not consumed")
        status = row["admission_status"]
        if status not in ("ADMITTED", "CAPACITY_REJECTED"):
            raise SchemaValidationError(f"{context}: invalid deep admission status")
        parent_count = _as_int(row, "active_parent_count", context)
        required_links = _as_int(row, "required_link_slots", context)
        required_trials = _as_int(row, "required_trial_slots", context)
        required_outcomes = _as_int(row, "required_outcome_slots", context)
        reserved_links = _as_int(row, "reserved_link_slots", context)
        reserved_trials = _as_int(row, "reserved_trial_slots", context)
        reserved_outcomes = _as_int(row, "reserved_outcome_slots", context)
        assert parent_count is not None and required_links is not None and required_trials is not None and required_outcomes is not None
        assert reserved_links is not None and reserved_trials is not None and reserved_outcomes is not None
        if parent_count <= 0 or required_links != parent_count or required_trials != 3 or required_outcomes != parent_count * 3:
            raise SchemaValidationError(f"{context}: deep fan-out reservation arithmetic mismatch")
        if status == "ADMITTED":
            if (reserved_links, reserved_trials, reserved_outcomes) != (required_links, required_trials, required_outcomes) or row["capacity_rejection_reason"] != NULL_TOKEN:
                raise SchemaValidationError(f"{context}: admitted event reservation mismatch")
        elif (reserved_links, reserved_trials, reserved_outcomes) != (0, 0, 0) or row["capacity_rejection_reason"] == NULL_TOKEN:
            raise SchemaValidationError(f"{context}: capacity rejection has partial fan-out")
        events[event_id] = row
    links: dict[str, dict[str, str]] = {}
    links_by_event: dict[str, list[str]] = {}
    for index, row in enumerate(rows[DEEP_PIVOT_PARENT_LINKS_FILE], start=2):
        context = f"{DEEP_PIVOT_PARENT_LINKS_FILE}:{index}"
        _validate_common(row, context, manifest)
        link_id = _require_value(row, "parent_link_id", context)
        event = events.get(_require_value(row, "deep_event_id", context))
        parent_kind = row["parent_kind"]
        if parent_kind not in ("VIRTUAL", "BROKER"):
            raise SchemaValidationError(f"{context}: invalid deep parent kind")
        parent_trial_id = _require_value(row, "parent_trial_id", context)
        parent_trial = trials.get(parent_trial_id)
        if link_id in links or event is None:
            raise SchemaValidationError(f"{context}: unknown/duplicate deep parent link")
        if event["admission_status"] != "ADMITTED":
            raise SchemaValidationError(f"{context}: parent link references rejected event")
        origin = origins.get(row["origin_id"])
        if origin is None or row["direction"] != event["direction"] or row["direction"] != origin["direction"]:
            raise SchemaValidationError(f"{context}: parent link identity mismatch")
        entry_time = _as_time(row, "parent_entry_broker_time", context)
        event_time = _as_time(row, "event_trigger_broker_time", context)
        age = _as_int(row, "m10_parent_age_seconds", context)
        assert entry_time and event_time and age is not None
        event_recorded_time = _as_time(event, "trigger_broker_time", context)
        assert event_recorded_time is not None
        if (
            event_time != event_recorded_time
            or entry_time > event_time
            or age < 0
            or age != int((event_time - entry_time).total_seconds())
        ):
            raise SchemaValidationError(f"{context}: m10_parent_age_seconds mismatch")
        if parent_kind == "VIRTUAL":
            if (
                parent_trial is None
                or parent_trial["trial_role"] != "H1"
                or parent_trial["eligibility_status"] != "ACTIVE"
                or parent_trial["origin_id"] != row["origin_id"]
                or parent_trial["direction"] != row["direction"]
                or parent_trial["entry_policy"] != row["parent_entry_policy"]
                or parent_trial["tp_r_multiple"] != row["parent_tp_r_multiple"]
                or parent_trial["broker_signal_id"] != row["parent_broker_signal_id"]
                or _as_time(parent_trial, "entry_broker_time", context) != entry_time
            ):
                raise SchemaValidationError(f"{context}: virtual parent identity mismatch")
            parent_outcome = outcome_by_trial.get(parent_trial_id)
            if parent_outcome is None:
                raise SchemaValidationError(f"{context}: virtual parent lacks outcome")
            parent_terminal = _as_time(parent_outcome, "terminal_broker_time", context)
            assert parent_terminal is not None
            if event_time > parent_terminal:
                raise SchemaValidationError(f"{context}: parent link begins after virtual parent terminal")
            parent_terminal_by_link[link_id] = parent_terminal
            if parent_outcome["terminal_status"] in ("TP_FIRST", "SL_FIRST"):
                closed_parent_links.add(link_id)
        else:
            if (
                parent_trial is None
                or parent_trial["trial_role"] != "BROKER_PARITY"
                or parent_trial["parity_trial_id"] != parent_trial_id
                or parent_trial["origin_id"] != row["origin_id"]
                or parent_trial["broker_signal_id"] != row["parent_broker_signal_id"]
                or row["parent_entry_policy"] != "STRUCTURAL"
                or row["parent_tp_r_multiple"] != "1"
            ):
                raise SchemaValidationError(f"{context}: broker parent parity identity mismatch")
            broker_outcome = broker_outcomes.get(row["parent_broker_signal_id"])
            if broker_outcome is not None:
                broker_entry = _as_time(broker_outcome, "entry_broker_time", context)
                broker_close = _as_time(broker_outcome, "close_broker_time", context)
                assert broker_entry is not None and broker_close is not None
                if entry_time != broker_entry or event_time > broker_close:
                    raise SchemaValidationError(f"{context}: broker parent interval mismatch")
                parent_terminal_by_link[link_id] = broker_close
                closed_parent_links.add(link_id)
            else:
                # A filled broker parent may still be open at run end. Its fill
                # needs execution-check evidence; unresolved deep outcomes are
                # then represented by their own run-end censor rows.
                fill_time = fill_times.get((row["origin_id"], row["parent_broker_signal_id"]))
                if fill_time is None or fill_time > event_time:
                    raise SchemaValidationError(f"{context}: open broker parent lacks fill evidence")
                parent_terminal_by_link[link_id] = None
        links[link_id] = row
        links_by_event.setdefault(row["deep_event_id"], []).append(link_id)
    deep_trials: dict[str, dict[str, str]] = {}
    trials_by_event: dict[str, list[str]] = {}
    for index, row in enumerate(rows[DEEP_VIRTUAL_TRIALS_FILE], start=2):
        context = f"{DEEP_VIRTUAL_TRIALS_FILE}:{index}"
        _validate_common(row, context, manifest)
        trial_id = _require_value(row, "deep_trial_id", context)
        event = events.get(_require_value(row, "deep_event_id", context))
        ratio = _as_int(row, "tp_r_multiple", context)
        if trial_id in deep_trials or event is None or ratio not in DEEP_TP_R_MULTIPLES:
            raise SchemaValidationError(f"{context}: invalid deep trial identity")
        if event["admission_status"] != "ADMITTED":
            raise SchemaValidationError(f"{context}: trial exists for rejected event")
        if (
            row["level_id"] != event["level_id"]
            or row["direction"] != event["direction"]
            or row["declared_broker_time"] != event["trigger_broker_time"]
            or row["declared_analysis_time"] != event["trigger_analysis_time"]
            or row["declared_offset_minutes"] != event["trigger_offset_minutes"]
        ):
            raise SchemaValidationError(f"{context}: deep trial/event identity mismatch")
        event_point = _as_float(event, "point_size", context)
        event_tick = _as_float(event, "trade_tick_size", context)
        event_spread = _as_float(event, "spread_points", context)
        event_stops = _as_float(event, "stops_level_points", context)
        event_freeze = _as_float(event, "freeze_level_points", context)
        event_bid = _as_float(event, "trigger_bid", context)
        event_ask = _as_float(event, "trigger_ask", context)
        boundary = _as_float(event, "next_outward_pivot_price", context)
        assert event_point is not None and event_tick is not None and event_spread is not None
        assert event_stops is not None and event_freeze is not None
        assert event_bid is not None and event_ask is not None and boundary is not None
        active = row["eligibility_status"] == "ACTIVE"
        if row["eligibility_status"] not in (
            "ACTIVE",
            "INELIGIBLE_GEOMETRY",
            "INELIGIBLE_DISTANCE",
            "INELIGIBLE_MONEY_PLAN",
        ):
            raise SchemaValidationError(f"{context}: invalid deep eligibility status")
        if not active:
            geometry_columns = (
                "entry_bid", "entry_ask", "entry_price", "entry_quote_side",
                "exit_quote_side", "requested_risk_distance_price",
                "requested_risk_distance_points", "normalized_risk_ticks",
                "normalized_risk_distance_price", "normalized_risk_distance_points",
                "stop_loss_price", "take_profit_price", "geometry_equivalence_id",
                "spread_points", "point_size", "trade_tick_size",
                "stops_level_points", "freeze_level_points",
                "minimum_risk_distance_points",
            )
            if any(not _is_null(row[column]) for column in geometry_columns) or bool(_as_bool(row, "distance_eligible", context)):
                raise SchemaValidationError(f"{context}: ineligible deep trial carries geometry")
            if _is_null(row["ineligible_reason"]):
                raise SchemaValidationError(f"{context}: ineligible deep trial lacks reason")
            deep_trials[trial_id] = row
            trials_by_event.setdefault(row["deep_event_id"], []).append(trial_id)
            continue
        for column, expected in (
            ("entry_bid", event_bid),
            ("entry_ask", event_ask),
            ("spread_points", event_spread),
            ("point_size", event_point),
            ("trade_tick_size", event_tick),
            ("stops_level_points", event_stops),
            ("freeze_level_points", event_freeze),
        ):
            actual = _as_float(row, column, context)
            assert actual is not None
            if not _same_number(actual, expected):
                raise SchemaValidationError(f"{context}: deep trial/event broker facts mismatch")
        entry_bid = _as_float(row, "entry_bid", context)
        entry_ask = _as_float(row, "entry_ask", context)
        entry = _as_float(row, "entry_price", context)
        requested_risk = _as_float(row, "requested_risk_distance_price", context)
        requested_points = _as_float(row, "requested_risk_distance_points", context)
        normalized_ticks = _as_int(row, "normalized_risk_ticks", context)
        normalized_risk = _as_float(row, "normalized_risk_distance_price", context)
        normalized_points = _as_float(row, "normalized_risk_distance_points", context)
        stop = _as_float(row, "stop_loss_price", context)
        take_profit = _as_float(row, "take_profit_price", context)
        minimum = _as_float(row, "minimum_risk_distance_points", context)
        assert entry_bid is not None and entry_ask is not None and entry is not None
        assert requested_risk is not None and requested_points is not None
        assert normalized_ticks is not None and normalized_risk is not None and normalized_points is not None
        assert stop is not None and take_profit is not None and minimum is not None
        expected_entry = event_ask if event["direction"] == "BUY" else event_bid
        expected_requested = abs(expected_entry - boundary)
        expected_ticks = _normalize_risk_ticks_outward(expected_requested, event_tick)
        expected_normalized = expected_ticks * event_tick
        expected_stop = expected_entry - expected_normalized if event["direction"] == "BUY" else expected_entry + expected_normalized
        expected_tp = expected_entry + ratio * expected_normalized if event["direction"] == "BUY" else expected_entry - ratio * expected_normalized
        expected_minimum = event_spread + max(event_stops, event_freeze) + event_tick / event_point
        if (
            not _same_number(entry, expected_entry)
            or row["entry_quote_side"] != ("ASK" if event["direction"] == "BUY" else "BID")
            or row["exit_quote_side"] != ("BID" if event["direction"] == "BUY" else "ASK")
            or not _same_number(requested_risk, expected_requested)
            or not _same_number(requested_points, expected_requested / event_point)
            or normalized_ticks != expected_ticks
            or not _same_number(normalized_risk, expected_normalized)
            or not _same_number(normalized_points, expected_normalized / event_point)
            or not _same_number(stop, expected_stop)
            or not _same_number(take_profit, expected_tp)
            or not _same_number(minimum, expected_minimum)
            or bool(_as_bool(row, "distance_eligible", context)) != (normalized_points + 1e-7 >= minimum)
            or not _is_null(row["ineligible_reason"])
        ):
            raise SchemaValidationError(f"{context}: deep trial geometry arithmetic mismatch")
        deep_trials[trial_id] = row
        trials_by_event.setdefault(row["deep_event_id"], []).append(trial_id)
    for event_id, event in events.items():
        if event["admission_status"] == "ADMITTED":
            if len(links_by_event.get(event_id, [])) != int(event["active_parent_count"]) or sorted(int(deep_trials[tid]["tp_r_multiple"]) for tid in trials_by_event.get(event_id, [])) != list(DEEP_TP_R_MULTIPLES):
                raise SchemaValidationError(f"Event {event_id}: deep fan-out cardinality mismatch")
    deep_outcomes: set[tuple[str, str]] = set()
    for index, row in enumerate(rows[DEEP_VIRTUAL_OUTCOMES_FILE], start=2):
        context = f"{DEEP_VIRTUAL_OUTCOMES_FILE}:{index}"
        _validate_common(row, context, manifest)
        link = links.get(_require_value(row, "parent_link_id", context))
        trial = deep_trials.get(_require_value(row, "deep_trial_id", context))
        if link is None or trial is None or row["deep_event_id"] != link["deep_event_id"] or row["deep_event_id"] != trial["deep_event_id"]:
            raise SchemaValidationError(f"{context}: deep outcome referential mismatch")
        identity = (row["parent_link_id"], row["deep_trial_id"])
        if identity in deep_outcomes:
            raise SchemaValidationError(f"{context}: duplicate deep outcome identity")
        deep_outcomes.add(identity)
        event = events[row["deep_event_id"]]
        for column, expected in (
            ("origin_id", link["origin_id"]),
            ("tp_r_multiple", trial["tp_r_multiple"]),
            ("direction", event["direction"]),
        ):
            if row[column] != expected:
                raise SchemaValidationError(f"{context}: deep outcome identity mismatch")
        terminal_time, _, _ = _validate_time_triplet(
            row,
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_offset_minutes",
            context,
        )
        event_time = _as_time(event, "trigger_broker_time", context)
        assert terminal_time is not None and event_time is not None
        status = row["terminal_status"]
        if terminal_time < event_time or (
            terminal_time == event_time
            and status != "CENSORED_PARENT_EXIT"
        ):
            raise SchemaValidationError(f"{context}: deep outcome terminal precedes event trigger")
        parent_terminal = parent_terminal_by_link[row["parent_link_id"]]
        if status in ("TP_FIRST", "SL_FIRST") and parent_terminal is not None and terminal_time > parent_terminal:
            raise SchemaValidationError(f"{context}: completed deep outcome follows parent terminal")
        if status == "CENSORED_RUN_END" and row["parent_link_id"] in closed_parent_links:
            raise SchemaValidationError(f"{context}: run-end censor references completed parent")
        observed_bid = _as_float(row, "observed_exit_bid", context)
        observed_ask = _as_float(row, "observed_exit_ask", context)
        observed_price = _as_float(row, "observed_exit_price", context)
        point = _as_float(event, "point_size", context)
        assert observed_bid is not None and observed_ask is not None and observed_price is not None and point is not None
        expected_exit_side = "BID" if row["direction"] == "BUY" else "ASK"
        expected_exit_price = observed_bid if row["direction"] == "BUY" else observed_ask
        if (
            observed_bid <= 0.0
            or observed_ask < observed_bid
            or row["exit_quote_side"] != expected_exit_side
            or not _same_number(observed_price, expected_exit_price)
            or not _as_bool(row, "first_touch_consistent", context)
        ):
            raise SchemaValidationError(f"{context}: invalid deep observed exit facts")
        if status not in ("TP_FIRST", "SL_FIRST", "CENSORED_PARENT_EXIT", "CENSORED_RUN_END", "INELIGIBLE"):
            raise SchemaValidationError(f"{context}: invalid deep terminal status")
        duration = _as_int(row, "deep_lifecycle_seconds", context, nullable=True)
        if status in ("TP_FIRST", "SL_FIRST") and (duration is None or duration < 0):
            raise SchemaValidationError(f"{context}: completed deep outcome lacks duration")
        if status in ("TP_FIRST", "SL_FIRST"):
            if trial["eligibility_status"] != "ACTIVE" or duration != int((terminal_time - event_time).total_seconds()):
                raise SchemaValidationError(f"{context}: completed deep lifecycle mismatch")
            threshold = _as_float(row, "threshold_price", context)
            gap = _as_float(row, "gap_points", context)
            nominal_r = _as_float(row, "virtual_nominal_r", context)
            gross_profit = _as_float(row, "virtual_quote_gross_profit", context)
            gross_r = _as_float(row, "virtual_quote_gross_r", context)
            assert threshold is not None and gap is not None and nominal_r is not None
            assert gross_profit is not None and gross_r is not None
            expected_threshold = float(trial["take_profit_price"] if status == "TP_FIRST" else trial["stop_loss_price"])
            expected_nominal = float(trial["tp_r_multiple"]) if status == "TP_FIRST" else -1.0
            if (
                row["terminal_reason"] != ("TP_THRESHOLD" if status == "TP_FIRST" else "SL_THRESHOLD")
                or not _same_number(threshold, expected_threshold)
                or not _same_number(gap, abs(observed_price - threshold) / point)
                or not _same_number(nominal_r, expected_nominal)
                or not _is_null(row["virtual_exclusion_reason"])
            ):
                raise SchemaValidationError(f"{context}: deep outcome arithmetic mismatch")
            touched = (
                observed_price >= threshold
                if row["direction"] == "BUY" and status == "TP_FIRST"
                else observed_price <= threshold
                if row["direction"] == "BUY"
                else observed_price <= threshold
                if status == "TP_FIRST"
                else observed_price >= threshold
            )
            if not touched:
                raise SchemaValidationError(f"{context}: deep threshold touch is not proven")
        else:
            if any(
                not _is_null(row[column])
                for column in (
                    "threshold_price", "gap_points", "deep_lifecycle_seconds",
                    "virtual_nominal_r", "virtual_quote_gross_profit", "virtual_quote_gross_r",
                )
            ):
                raise SchemaValidationError(f"{context}: non-completed deep outcome carries terminal arithmetic")
            if _is_null(row["virtual_exclusion_reason"]):
                raise SchemaValidationError(f"{context}: excluded deep outcome lacks reason")
            if status == "INELIGIBLE" and trial["eligibility_status"] == "ACTIVE":
                raise SchemaValidationError(f"{context}: active deep trial has ineligible outcome")
            if status in ("CENSORED_PARENT_EXIT", "CENSORED_RUN_END") and trial["eligibility_status"] != "ACTIVE":
                raise SchemaValidationError(f"{context}: censored deep outcome references inactive trial")
            if status == "CENSORED_PARENT_EXIT":
                if parent_terminal is None:
                    raise SchemaValidationError(f"{context}: parent-exit censor lacks terminal parent evidence")
                if terminal_time != parent_terminal:
                    raise SchemaValidationError(f"{context}: parent-exit censor time mismatch")
            if status == "CENSORED_RUN_END" and terminal_time < event_time:
                raise SchemaValidationError(f"{context}: run-end censor precedes event")
        eligible = bool(_as_bool(row, "virtual_binary_eligible", context))
        target = _as_int(row, "virtual_binary_target", context, nullable=True)
        expected_target = 1 if status == "TP_FIRST" else 0 if status == "SL_FIRST" else None
        if eligible != (status in ("TP_FIRST", "SL_FIRST")) or target != expected_target:
            raise SchemaValidationError(f"{context}: deep binary eligibility/status mismatch")
    expected_outcomes = sum(len(ids) * 3 for ids in links_by_event.values())
    if len(deep_outcomes) != expected_outcomes:
        raise SchemaValidationError(f"Deep outcome cardinality mismatch: {len(deep_outcomes)} != {expected_outcomes}")


def _validate_summary(
    row: dict[str, str],
    manifest: dict[str, str],
    tables: dict[str, list[dict[str, str]]],
) -> None:
    context = RUN_SUMMARY_FILE
    _validate_common(row, context, manifest)
    counts = {filename: len(rows) for filename, rows in tables.items()}
    for key, filename in (("pivot_window_rows", PIVOT_WINDOWS_FILE), ("signal_origin_rows", SIGNAL_ORIGINS_FILE), ("h1_trial_rows", VIRTUAL_TRIALS_FILE), ("h1_outcome_rows", VIRTUAL_OUTCOMES_FILE), ("deep_event_rows", DEEP_PIVOT_EVENTS_FILE), ("deep_parent_link_rows", DEEP_PIVOT_PARENT_LINKS_FILE), ("deep_trial_rows", DEEP_VIRTUAL_TRIALS_FILE), ("deep_outcome_rows", DEEP_VIRTUAL_OUTCOMES_FILE), ("execution_check_rows", EXECUTION_CHECKS_FILE), ("broker_outcome_rows", BROKER_OUTCOMES_FILE)):
        value = _as_int(row, key, context)
        assert value is not None
        if value != counts[filename]:
            raise SchemaValidationError(f"{context}: summary {key} mismatch")
    category_checks = {
        "macro_window_rows": sum(window["window_scope"] == "MACRO" for window in tables[PIVOT_WINDOWS_FILE]),
        "deep_window_rows": sum(window["window_scope"] == "DEEP" for window in tables[PIVOT_WINDOWS_FILE]),
        "h1_structural_trial_rows": sum(
            trial["trial_role"] == "H1" and trial["entry_policy"] == "STRUCTURAL"
            for trial in tables[VIRTUAL_TRIALS_FILE]
        ),
        "h1_midpoint_trial_rows": sum(
            trial["trial_role"] == "H1" and trial["entry_policy"] == "MIDPOINT_50"
            for trial in tables[VIRTUAL_TRIALS_FILE]
        ),
        "parity_trial_rows": sum(
            trial["trial_role"] == "BROKER_PARITY"
            for trial in tables[VIRTUAL_TRIALS_FILE]
        ),
        "h1_tp_rows": sum(outcome["terminal_status"] == "TP_FIRST" for outcome in tables[VIRTUAL_OUTCOMES_FILE]),
        "h1_sl_rows": sum(outcome["terminal_status"] == "SL_FIRST" for outcome in tables[VIRTUAL_OUTCOMES_FILE]),
        "h1_not_triggered_rows": sum(outcome["terminal_status"] == "NOT_TRIGGERED" for outcome in tables[VIRTUAL_OUTCOMES_FILE]),
        "h1_ineligible_rows": sum(outcome["terminal_status"] == "INELIGIBLE" for outcome in tables[VIRTUAL_OUTCOMES_FILE]),
        "h1_run_censored_rows": sum(outcome["terminal_status"] == "CENSORED_RUN_END" for outcome in tables[VIRTUAL_OUTCOMES_FILE]),
        "deep_event_admitted_rows": sum(event["admission_status"] == "ADMITTED" for event in tables[DEEP_PIVOT_EVENTS_FILE]),
        "deep_event_capacity_rejected_rows": sum(event["admission_status"] == "CAPACITY_REJECTED" for event in tables[DEEP_PIVOT_EVENTS_FILE]),
        "deep_tp_rows": sum(outcome["terminal_status"] == "TP_FIRST" for outcome in tables[DEEP_VIRTUAL_OUTCOMES_FILE]),
        "deep_sl_rows": sum(outcome["terminal_status"] == "SL_FIRST" for outcome in tables[DEEP_VIRTUAL_OUTCOMES_FILE]),
        "deep_parent_exit_censored_rows": sum(outcome["terminal_status"] == "CENSORED_PARENT_EXIT" for outcome in tables[DEEP_VIRTUAL_OUTCOMES_FILE]),
        "deep_run_censored_rows": sum(outcome["terminal_status"] == "CENSORED_RUN_END" for outcome in tables[DEEP_VIRTUAL_OUTCOMES_FILE]),
        "deep_ineligible_rows": sum(outcome["terminal_status"] == "INELIGIBLE" for outcome in tables[DEEP_VIRTUAL_OUTCOMES_FILE]),
    }
    for key, expected in category_checks.items():
        if _as_int(row, key, context) != expected:
            raise SchemaValidationError(f"{context}: summary {key} mismatch")
    capacity_keys = (
        ("h1_active_state_peak", "h1_active_state_cap", "h1_active_state_cap"),
        ("deep_event_active_peak", "deep_event_active_cap", "deep_event_active_cap"),
        ("deep_link_active_peak", "deep_link_active_cap", "deep_link_active_cap"),
        ("deep_trial_active_peak", "deep_trial_active_cap", "deep_trial_active_cap"),
        ("deep_outcome_active_peak", "deep_outcome_active_cap", "deep_outcome_active_cap"),
    )
    for peak_key, cap_key, manifest_key in capacity_keys:
        peak = _as_int(row, peak_key, context)
        cap = _as_int(row, cap_key, context)
        assert peak is not None and cap is not None
        if peak < 0 or cap <= 0 or peak > cap or str(cap) != manifest[manifest_key]:
            raise SchemaValidationError(f"{context}: invalid {cap_key} active-state capacity")
    for key in ("duplicate_identity_count", "referential_integrity_error_count", "row_integrity_error_count"):
        if _as_int(row, key, context) != 0:
            raise SchemaValidationError(f"{context}: non-zero integrity count {key}")
    if row["export_status"] != "OK":
        raise SchemaValidationError(f"{context}: export status is not OK")
    if row["completion_status"] not in ("NATURAL", "CENSORED"):
        raise SchemaValidationError(f"{context}: invalid completion status")


def validate_run(runs_root: Path, run_id: str, *, schema_version: int = SUPPORTED_SCHEMA_VERSION) -> RunValidation:
    _require_active_schema(schema_version)
    run_path = _resolve_run_path(Path(runs_root), run_id)
    tables = {filename: _read_tsv(run_path / filename, TABLE_COLUMNS[filename]) for filename in RUN_FILES}
    manifest = _validate_manifest(tables[RUN_MANIFEST_FILE], run_id)
    windows = _validate_windows(tables[PIVOT_WINDOWS_FILE], manifest)
    origins = _validate_origins(tables[SIGNAL_ORIGINS_FILE], manifest, windows)
    trials = _validate_trials(tables[VIRTUAL_TRIALS_FILE], manifest, origins, windows)
    outcomes = _validate_outcomes(tables[VIRTUAL_OUTCOMES_FILE], manifest, trials)
    broker_outcomes = _validate_broker_outcomes(
        tables[BROKER_OUTCOMES_FILE],
        manifest,
        origins,
        trials,
        outcomes,
    )
    _validate_deep(
        tables,
        manifest,
        windows,
        origins,
        trials,
        outcomes,
        broker_outcomes,
    )
    if len(tables[RUN_SUMMARY_FILE]) != 1:
        raise SchemaValidationError("run_summary.tsv must contain exactly one row")
    _validate_summary(tables[RUN_SUMMARY_FILE][0], manifest, tables)
    counts = {filename: len(rows) for filename, rows in tables.items()}
    warnings = ("run completion is CENSORED",) if tables[RUN_SUMMARY_FILE][0]["completion_status"] != "NATURAL" else ()
    return RunValidation(run_id, manifest["config_id"], run_path, manifest, counts, warnings)


def validate_runs(runs_root: Path, run_ids: list[str] | tuple[str, ...], *, schema_version: int = SUPPORTED_SCHEMA_VERSION) -> list[RunValidation]:
    validations = [validate_run(runs_root, run_id, schema_version=schema_version) for run_id in run_ids]
    if not validations:
        raise SchemaValidationError("At least one run is required")
    baseline = {key: validations[0].manifest[key] for key in DATASET_CONFIG_KEYS if key in validations[0].manifest}
    for validation in validations[1:]:
        current = {key: validation.manifest[key] for key in baseline}
        if current != baseline:
            raise SchemaValidationError("Runs do not share compatible configuration boundaries")
    return validations
