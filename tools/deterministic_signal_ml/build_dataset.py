"""Validate strict V11 runs and build policy-aware Parquet research datasets."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import duckdb

from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
)
from schema_contract import (
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    NULL_TOKEN,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    RunValidation,
    SchemaValidationError,
    feature_columns_for_set,
    validate_runs,
)


DEFAULT_DATASET_ROOT = "artifacts/datasets"
ORIGIN_MATRIX_LONG_TABLE = "origin_matrix_long"
INITIAL_MATRIX_WIDE_TABLE = "initial_matrix_wide"
ELIGIBLE_VIRTUAL_TRIALS_TABLE = "eligible_virtual_trials"
POLICY_CHAINS_TABLE = "policy_chains"
BROKER_VIRTUAL_CALIBRATION_TABLE = "broker_virtual_calibration"

DERIVED_TABLES = (
    ORIGIN_MATRIX_LONG_TABLE,
    INITIAL_MATRIX_WIDE_TABLE,
    ELIGIBLE_VIRTUAL_TRIALS_TABLE,
    POLICY_CHAINS_TABLE,
    BROKER_VIRTUAL_CALIBRATION_TABLE,
)

BOOLEAN_COLUMNS = frozenset({
    "macro_band_complete",
    "origin_micro_features_complete",
    "origin_macro_features_complete",
    "origin_feature_snapshot_complete",
    "identity_consumed",
    "matrix_declared",
    "distance_eligible",
    "boundary_eligible",
    "virtual_money_plan_complete",
    "entry_feature_snapshot_complete",
    "origin_window_active_at_entry",
    "virtual_binary_eligible",
    "first_touch_consistent",
    "chain_terminal",
    "continuation_allowed",
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
    "protection_modified",
    "close_reason_consistent",
    "broker_binary_eligible",
    "state_capacity_failed",
})

INTEGER_COLUMNS = frozenset({
    "schema_version",
    "active_bar_open_offset_minutes",
    "source_bar_open_offset_minutes",
    "source_close_boundary_offset_minutes",
    "first_observed_offset_minutes",
    "pp_arm_offset_minutes",
    "terminal_offset_minutes",
    "trigger_offset_minutes",
    "origin_expiry_offset_minutes",
    "declared_offset_minutes",
    "tp_r_multiple",
    "reentry_index",
    "preceding_loss_count",
    "normalized_risk_ticks",
    "virtual_binary_target",
    "duration_seconds",
    "next_reentry_index",
    "check_sequence",
    "offset_minutes",
    "account_margin_mode",
    "symbol_trade_mode",
    "order_check_retcode",
    "send_retcode",
    "order_ticket",
    "deal_ticket",
    "position_ticket",
    "position_identifier",
    "entry_offset_minutes",
    "close_offset_minutes",
    "entry_deal_ticket",
    "last_close_deal_ticket",
    "close_deal_count",
    "broker_binary_target",
    "started_offset_minutes",
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
    "duplicate_identity_count",
    "referential_integrity_error_count",
    "row_integrity_error_count",
})

STRING_COLUMNS = frozenset({
    "account_currency",
    "block_reason",
    "block_source",
    "broker_attempt_status",
    "broker_exclusion_reason",
    "broker_outcome_id",
    "broker_signal_id",
    "broker_terminal_reason",
    "chain_terminal_reason",
    "check_id",
    "check_phase",
    "completion_status",
    "config_id",
    "continuation_reason",
    "continuation_source_outcome_id",
    "direction",
    "eligibility_status",
    "entry_feature_invalid_reason",
    "entry_quote_side",
    "exit_quote_side",
    "export_status",
    "fill_policy",
    "geometry_equivalence_id",
    "ineligible_reason",
    "invalid_reason",
    "key",
    "level_id",
    "lot_mode",
    "macro_band_invalid_reason",
    "macro_timeframe",
    "micro_timeframe",
    "next_trial_id",
    "order_check_comment",
    "origin_feature_invalid_reason",
    "origin_id",
    "origin_terminal_status",
    "outcome_id",
    "parent_trial_id",
    "parity_trial_id",
    "policy_id",
    "pp_initial_relation",
    "pp_role",
    "run_id",
    "send_comment",
    "sl_policy",
    "symbol",
    "terminal_reason",
    "terminal_status",
    "trade_action",
    "trial_id",
    "trial_role",
    "value",
    "virtual_exclusion_reason",
    "window_id",
    "window_state",
})

TIMESTAMP_COLUMNS = frozenset({
    "active_bar_open_analysis_time",
    "active_bar_open_broker_time",
    "analysis_time",
    "broker_time",
    "close_analysis_time",
    "close_broker_time",
    "declared_analysis_time",
    "declared_broker_time",
    "entry_analysis_time",
    "entry_broker_time",
    "finished_analysis_time",
    "finished_broker_time",
    "first_observed_analysis_time",
    "first_observed_broker_time",
    "origin_expiry_analysis_time",
    "origin_expiry_broker_time",
    "pp_arm_analysis_time",
    "pp_arm_broker_time",
    "source_bar_open_analysis_time",
    "source_bar_open_broker_time",
    "source_close_boundary_analysis_time",
    "source_close_boundary_broker_time",
    "started_analysis_time",
    "started_broker_time",
    "terminal_analysis_time",
    "terminal_broker_time",
    "trigger_analysis_time",
    "trigger_broker_time",
})

FLOAT_COLUMNS = frozenset({
    "account_balance",
    "ask",
    "bid",
    "boundary_price",
    "broker_close_price",
    "broker_closed_volume",
    "broker_commission",
    "broker_entry_price",
    "broker_fee",
    "broker_gross_budget_r",
    "broker_gross_execution_r",
    "broker_gross_profit",
    "broker_net_budget_r",
    "broker_net_execution_r",
    "broker_net_profit",
    "broker_stop_loss",
    "broker_swap",
    "broker_take_profit",
    "broker_volume",
    "close_price",
    "closed_volume",
    "entry_ask",
    "entry_bid",
    "entry_macro_band_width_percent_1",
    "entry_macro_pivot_b_percent_0",
    "entry_macro_pivot_b_percent_1",
    "entry_macro_pivot_b_percent_2",
    "entry_macro_pivot_b_percent_3",
    "entry_macro_pivot_b_percent_4",
    "entry_macro_pivot_b_percent_5",
    "entry_micro_b_percent_0",
    "entry_micro_b_percent_1",
    "entry_micro_b_percent_2",
    "entry_micro_b_percent_3",
    "entry_micro_b_percent_4",
    "entry_micro_b_percent_5",
    "entry_micro_band_width_percent_0",
    "entry_price",
    "entry_slippage_points",
    "exit_slippage_points",
    "first_observed_bid",
    "free_margin",
    "freeze_distance_points",
    "freeze_level_points",
    "gap_points",
    "immutable_stop_loss",
    "immutable_take_profit",
    "lot_strategy_size",
    "macro_band_base_1",
    "macro_band_lower_1",
    "macro_band_upper_1",
    "macro_band_width_1",
    "macro_band_width_percent_1",
    "minimum_risk_distance_points",
    "next_outward_pivot_price",
    "normalized_risk_distance_points",
    "normalized_risk_distance_price",
    "normalized_volume",
    "observed_exit_ask",
    "observed_exit_bid",
    "observed_exit_price",
    "origin_macro_pivot_b_percent_0",
    "origin_macro_pivot_b_percent_1",
    "origin_macro_pivot_b_percent_2",
    "origin_macro_pivot_b_percent_3",
    "origin_macro_pivot_b_percent_4",
    "origin_macro_pivot_b_percent_5",
    "origin_micro_b_percent_0",
    "origin_micro_b_percent_1",
    "origin_micro_b_percent_2",
    "origin_micro_b_percent_3",
    "origin_micro_b_percent_4",
    "origin_micro_b_percent_5",
    "origin_micro_band_base_0",
    "origin_micro_band_lower_0",
    "origin_micro_band_upper_0",
    "origin_micro_band_width_0",
    "origin_micro_band_width_percent_0",
    "pivot_raw_price",
    "pivot_trade_price",
    "point_size",
    "pp_arm_bid",
    "quote_expected_reward_risk_ratio",
    "quote_expected_stop_loss",
    "quote_expected_take_profit",
    "raw_pp_price",
    "raw_r1_price",
    "raw_r2_price",
    "raw_r3_price",
    "raw_s1_price",
    "raw_s2_price",
    "raw_s3_price",
    "reference_balance",
    "request_price_reward_risk_ratio",
    "request_reward_distance_points",
    "request_risk_distance_points",
    "requested_risk_distance_points",
    "requested_risk_distance_price",
    "requested_volume",
    "required_margin",
    "reward_distance_points",
    "risk_budget_amount",
    "risk_budget_utilization_ratio",
    "risk_distance_points",
    "source_close",
    "source_high",
    "source_low",
    "source_open",
    "source_range",
    "spread_points",
    "stop_loss_price",
    "stops_distance_points",
    "stops_level_points",
    "structural_entry_price",
    "structural_sl_price",
    "structural_take_profit",
    "submitted_request_price",
    "take_profit_price",
    "threshold_price",
    "trade_pp_price",
    "trade_r1_price",
    "trade_r2_price",
    "trade_r3_price",
    "trade_s1_price",
    "trade_s2_price",
    "trade_s3_price",
    "trade_tick_size",
    "trigger_ask",
    "trigger_bid",
    "virtual_expected_reward_risk_ratio",
    "virtual_expected_stop_loss",
    "virtual_expected_take_profit",
    "virtual_nominal_r",
    "virtual_quote_gross_profit",
    "virtual_quote_gross_r",
    "volume_max",
    "volume_min",
    "volume_step",
})

COLUMN_TYPE_GROUPS = {
    "VARCHAR": STRING_COLUMNS,
    "TIMESTAMP": TIMESTAMP_COLUMNS,
    "BOOLEAN": BOOLEAN_COLUMNS,
    "BIGINT": INTEGER_COLUMNS,
    "DOUBLE": FLOAT_COLUMNS,
}


def _build_column_type_registry() -> dict[str, str]:
    registry: dict[str, str] = {}
    overlaps: set[str] = set()
    for column_type, columns in COLUMN_TYPE_GROUPS.items():
        for column in columns:
            if column in registry:
                overlaps.add(column)
            registry[column] = column_type

    schema_columns = {
        column
        for columns in TABLE_COLUMNS.values()
        for column in columns
    }
    missing = sorted(schema_columns - set(registry))
    unexpected = sorted(set(registry) - schema_columns)
    if overlaps or missing or unexpected:
        raise RuntimeError(
            "Invalid V11 column type registry: "
            f"overlaps={sorted(overlaps)}, missing={missing}, unexpected={unexpected}"
        )
    return registry


COLUMN_TYPE_BY_NAME = _build_column_type_registry()


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _quoted(column: str) -> str:
    return '"' + column.replace('"', '""') + '"'


def _typed_expression(column: str) -> str:
    quoted = _quoted(column)
    nullified = f"NULLIF({quoted}, {_sql_literal(NULL_TOKEN)})"
    try:
        column_type = COLUMN_TYPE_BY_NAME[column]
    except KeyError as exc:
        raise RuntimeError(f"V11 column lacks an explicit dataset type: {column}") from exc
    if column_type == "TIMESTAMP":
        return f"strptime({nullified}, '%Y.%m.%d %H:%M:%S') AS {quoted}"
    if column_type == "BOOLEAN":
        return f"CAST(CAST({nullified} AS TINYINT) AS BOOLEAN) AS {quoted}"
    if column_type == "BIGINT":
        return f"CAST({nullified} AS BIGINT) AS {quoted}"
    if column_type == "VARCHAR":
        return f"{nullified} AS {quoted}"
    if column_type == "DOUBLE":
        return f"CAST({nullified} AS DOUBLE) AS {quoted}"
    raise RuntimeError(f"Unsupported V11 dataset type for {column}: {column_type}")


def _load_typed_table(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
    paths: list[Path],
    columns: tuple[str, ...],
) -> None:
    path_list = ", ".join(_sql_literal(path.resolve().as_posix()) for path in paths)
    raw_table = f"raw_{table_name}"
    connection.execute(
        f"""
CREATE TEMP TABLE {raw_table} AS
SELECT *
FROM read_csv(
  [{path_list}],
  delim='\t',
  header=true,
  all_varchar=true,
  union_by_name=false,
  nullstr='__PIVOT_V11_NO_AUTOMATIC_NULL__'
)
"""
    )
    typed_columns = ",\n  ".join(_typed_expression(column) for column in columns)
    connection.execute(
        f"""
CREATE TABLE {table_name} AS
SELECT
  {typed_columns}
FROM {raw_table}
"""
    )
    connection.execute(f"DROP TABLE {raw_table}")


def _create_origin_matrix_long(connection: duckdb.DuckDBPyConnection) -> None:
    outcome_columns = (
        "outcome_id",
        "terminal_broker_time",
        "terminal_analysis_time",
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
        "first_touch_consistent",
        "chain_terminal",
        "chain_terminal_reason",
        "continuation_allowed",
        "continuation_reason",
        "next_reentry_index",
        "next_trial_id",
    )
    outcome_select = ",\n  ".join(f"vo.{column}" for column in outcome_columns)
    connection.execute(
        f"""
CREATE TABLE {ORIGIN_MATRIX_LONG_TABLE} AS
SELECT
  vt.*,
  so.symbol,
  so.macro_timeframe,
  so.micro_timeframe,
  so.active_bar_open_broker_time,
  so.trigger_broker_time,
  so.trigger_analysis_time,
  so.trigger_bid,
  so.trigger_ask,
  so.pivot_raw_price,
  so.pivot_trade_price,
  so.structural_sl_price,
  so.origin_feature_snapshot_complete,
  pw.source_open,
  pw.source_high,
  pw.source_low,
  pw.source_close,
  pw.source_range,
  pw.macro_band_width_1,
  concat(
    so.symbol,
    '|',
    so.macro_timeframe,
    '|',
    strftime(so.active_bar_open_broker_time, '%Y.%m.%d %H:%M:%S')
  ) AS research_group_id,
  strftime(vt.declared_analysis_time, '%w') AS analysis_weekday,
  CASE
    WHEN EXTRACT(hour FROM vt.declared_analysis_time) < 6 THEN 'SESSION_00_05'
    WHEN EXTRACT(hour FROM vt.declared_analysis_time) < 12 THEN 'SESSION_06_11'
    WHEN EXTRACT(hour FROM vt.declared_analysis_time) < 18 THEN 'SESSION_12_17'
    ELSE 'SESSION_18_23'
  END AS analysis_session,
  sin(
    2.0 * pi() *
    (EXTRACT(hour FROM vt.declared_analysis_time) * 60.0 +
     EXTRACT(minute FROM vt.declared_analysis_time)) / 1440.0
  ) AS time_sin,
  cos(
    2.0 * pi() *
    (EXTRACT(hour FROM vt.declared_analysis_time) * 60.0 +
     EXTRACT(minute FROM vt.declared_analysis_time)) / 1440.0
  ) AS time_cos,
  abs(vt.entry_price - so.pivot_trade_price)
    / NULLIF(vt.normalized_risk_distance_price, 0.0) AS trigger_gap_to_risk,
  vt.spread_points
    / NULLIF(vt.normalized_risk_distance_points, 0.0) AS spread_to_risk,
  pw.source_range / NULLIF(pw.macro_band_width_1, 0.0) AS macro_range_to_band_width,
  {outcome_select}
FROM virtual_trials vt
JOIN signal_origins so
  USING (run_id, config_id, origin_id, window_id)
JOIN pivot_windows pw
  USING (run_id, config_id, window_id)
LEFT JOIN virtual_outcomes vo
  USING (run_id, config_id, trial_id, origin_id, window_id)
WHERE vt.trial_role = 'MATRIX'
ORDER BY vt.declared_broker_time, vt.origin_id, vt.sl_policy, vt.tp_r_multiple, vt.reentry_index
"""
    )


def _create_initial_matrix_wide(connection: duckdb.DuckDBPyConnection) -> None:
    policy_cells: list[str] = []
    for sl_policy in ("STRUCTURAL", "MICRO_BW_13", "MICRO_BW_21", "MICRO_BW_34"):
        slug = sl_policy.lower()
        for tp in (1, 2, 3, 5):
            prefix = f"{slug}_tp{tp}"
            predicate = f"sl_policy = '{sl_policy}' AND tp_r_multiple = {tp}"
            for column in (
                "trial_id",
                "eligibility_status",
                "ineligible_reason",
                "terminal_status",
                "virtual_binary_target",
                "virtual_nominal_r",
                "virtual_quote_gross_r",
            ):
                policy_cells.append(
                    f"max(CASE WHEN {predicate} THEN {column} END) "
                    f"AS {prefix}_{column}"
                )
    cells = ",\n  ".join(policy_cells)
    connection.execute(
        f"""
CREATE TABLE {INITIAL_MATRIX_WIDE_TABLE} AS
SELECT
  run_id,
  config_id,
  origin_id,
  window_id,
  symbol,
  macro_timeframe,
  micro_timeframe,
  active_bar_open_broker_time,
  level_id,
  direction,
  trigger_broker_time,
  trigger_analysis_time,
  trigger_bid,
  trigger_ask,
  pivot_trade_price,
  origin_micro_band_width_0,
  research_group_id,
  {cells}
FROM {ORIGIN_MATRIX_LONG_TABLE}
WHERE reentry_index = 0
GROUP BY ALL
ORDER BY trigger_broker_time, run_id, origin_id
"""
    )


def _create_eligible_virtual_trials(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {ELIGIBLE_VIRTUAL_TRIALS_TABLE} AS
SELECT
  *,
  1.0 / count(*) OVER (PARTITION BY run_id, config_id, origin_id)
    AS origin_sample_weight,
  1.0 / (tp_r_multiple + 1.0) AS break_even_tp_rate
FROM {ORIGIN_MATRIX_LONG_TABLE}
WHERE eligibility_status = 'ACTIVE'
  AND virtual_binary_eligible
  AND virtual_binary_target IN (0, 1)
  AND terminal_status IN ('TP_FIRST', 'SL_FIRST')
ORDER BY declared_broker_time, run_id, origin_id, policy_id, reentry_index
"""
    )


def _create_policy_chains(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {POLICY_CHAINS_TABLE} AS
WITH ranked AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY run_id, config_id, origin_id, policy_id
      ORDER BY reentry_index DESC
    ) AS final_rank
  FROM {ORIGIN_MATRIX_LONG_TABLE}
)
SELECT
  run_id,
  config_id,
  origin_id,
  window_id,
  policy_id,
  symbol,
  macro_timeframe,
  micro_timeframe,
  active_bar_open_broker_time,
  level_id,
  direction,
  sl_policy,
  tp_r_multiple,
  research_group_id,
  count(*) AS attempts,
  sum(CASE WHEN terminal_status = 'SL_FIRST' THEN 1 ELSE 0 END) AS losses_before_success,
  max(reentry_index) AS final_reentry_index,
  sum(coalesce(virtual_nominal_r, 0.0)) AS closed_nominal_r,
  sum(coalesce(virtual_quote_gross_profit, 0.0)) AS virtual_quote_gross_profit,
  sum(coalesce(virtual_quote_gross_r, 0.0)) AS virtual_quote_gross_r,
  max(CASE WHEN final_rank = 1 THEN eligibility_status END) AS final_eligibility_status,
  max(CASE WHEN final_rank = 1 THEN terminal_status END) AS final_terminal_status,
  max(CASE WHEN final_rank = 1 THEN chain_terminal_reason END) AS chain_terminal_reason,
  max(CASE WHEN final_rank = 1 THEN ineligible_reason END) AS ineligible_reason,
  bool_or(terminal_status = 'CENSORED') AS censored,
  bool_or(terminal_status = 'TP_FIRST') AS reached_tp,
  sum(CASE WHEN virtual_binary_eligible THEN 1 ELSE 0 END) AS binary_rows
FROM ranked
GROUP BY
  run_id,
  config_id,
  origin_id,
  window_id,
  policy_id,
  symbol,
  macro_timeframe,
  micro_timeframe,
  active_bar_open_broker_time,
  level_id,
  direction,
  sl_policy,
  tp_r_multiple,
  research_group_id
ORDER BY active_bar_open_broker_time, run_id, origin_id, sl_policy, tp_r_multiple
"""
    )


def _create_broker_virtual_calibration(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {BROKER_VIRTUAL_CALIBRATION_TABLE} AS
SELECT
  bo.schema_version,
  bo.run_id,
  bo.config_id,
  bo.broker_outcome_id,
  bo.origin_id,
  bo.broker_signal_id,
  bo.parity_trial_id,
  bo.window_id,
  bo.symbol,
  bo.macro_timeframe,
  bo.micro_timeframe,
  bo.level_id,
  bo.direction,
  bo.broker_terminal_reason,
  vo.terminal_status AS virtual_terminal_status,
  bo.broker_binary_eligible
    AND vo.terminal_status IN ('TP_FIRST', 'SL_FIRST') AS strict_pair_eligible,
  CASE
    WHEN NOT bo.broker_binary_eligible THEN bo.broker_exclusion_reason
    WHEN vo.terminal_status = 'CENSORED' THEN 'PARITY_CENSORED'
    WHEN vo.terminal_status NOT IN ('TP_FIRST', 'SL_FIRST') THEN 'PARITY_NONBINARY'
    ELSE NULL
  END AS calibration_exclusion_reason,
  CASE
    WHEN bo.broker_terminal_reason = 'BROKER_TP' THEN vo.terminal_status = 'TP_FIRST'
    WHEN bo.broker_terminal_reason = 'BROKER_SL' THEN vo.terminal_status = 'SL_FIRST'
    ELSE NULL
  END AS terminal_agreement,
  vo.terminal_broker_time AS virtual_first_crossing_time,
  bo.close_broker_time AS broker_close_time,
  date_diff('second', vo.terminal_broker_time, bo.close_broker_time)
    AS crossing_close_delta_seconds,
  bo.submitted_request_price,
  vt.entry_price AS virtual_entry_price,
  bo.broker_entry_price,
  (bo.broker_entry_price - bo.submitted_request_price) / NULLIF(vt.point_size, 0.0)
    AS broker_entry_slippage_points,
  vo.observed_exit_price AS virtual_exit_price,
  bo.broker_close_price,
  (bo.broker_close_price - vo.observed_exit_price) / NULLIF(vt.point_size, 0.0)
    AS broker_minus_virtual_exit_points,
  vo.virtual_quote_gross_profit,
  bo.broker_gross_profit,
  bo.broker_gross_profit - vo.virtual_quote_gross_profit AS broker_minus_virtual_gross_profit,
  vo.virtual_quote_gross_r,
  bo.broker_gross_execution_r,
  bo.broker_gross_execution_r - vo.virtual_quote_gross_r
    AS broker_minus_virtual_gross_execution_r,
  bo.broker_commission,
  bo.broker_swap,
  bo.broker_fee,
  bo.broker_net_profit
FROM broker_outcomes bo
JOIN virtual_trials vt
  ON vt.run_id = bo.run_id
 AND vt.config_id = bo.config_id
 AND vt.parity_trial_id = bo.parity_trial_id
 AND vt.trial_role = 'BROKER_PARITY'
JOIN virtual_outcomes vo
  ON vo.run_id = vt.run_id
 AND vo.config_id = vt.config_id
 AND vo.trial_id = vt.trial_id
WHERE bo.parity_trial_id IS NOT NULL
ORDER BY bo.close_broker_time, bo.run_id, bo.broker_signal_id
"""
    )


def _validate_derived_tables(connection: duckdb.DuckDBPyConnection) -> None:
    expected_long = int(
        connection.execute(
            "SELECT count(*) FROM virtual_trials WHERE trial_role = 'MATRIX'"
        ).fetchone()[0]
    )
    actual_long = int(
        connection.execute(f"SELECT count(*) FROM {ORIGIN_MATRIX_LONG_TABLE}").fetchone()[0]
    )
    if actual_long != expected_long:
        raise RuntimeError(f"Origin matrix long grain mismatch: {actual_long} != {expected_long}")
    duplicate_long = int(
        connection.execute(
            f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, trial_id
  FROM {ORIGIN_MATRIX_LONG_TABLE}
  GROUP BY ALL
  HAVING count(*) <> 1
)
"""
        ).fetchone()[0]
    )
    if duplicate_long:
        raise RuntimeError("Origin matrix long contains duplicate trial grain")
    malformed_initial = int(
        connection.execute(
            f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, origin_id, count(*) AS cells
  FROM {ORIGIN_MATRIX_LONG_TABLE}
  WHERE reentry_index = 0
  GROUP BY ALL
  HAVING cells <> 16
)
"""
        ).fetchone()[0]
    )
    if malformed_initial:
        raise RuntimeError("Initial matrix wide source does not contain exactly sixteen cells")
    expected_wide = int(
        connection.execute("SELECT count(*) FROM signal_origins WHERE matrix_declared").fetchone()[0]
    )
    actual_wide = int(
        connection.execute(f"SELECT count(*) FROM {INITIAL_MATRIX_WIDE_TABLE}").fetchone()[0]
    )
    if actual_wide != expected_wide:
        raise RuntimeError(f"Initial matrix wide grain mismatch: {actual_wide} != {expected_wide}")
    expected_eligible = int(
        connection.execute(
            "SELECT count(*) FROM virtual_outcomes WHERE trial_role = 'MATRIX' "
            "AND virtual_binary_eligible"
        ).fetchone()[0]
    )
    actual_eligible = int(
        connection.execute(f"SELECT count(*) FROM {ELIGIBLE_VIRTUAL_TRIALS_TABLE}").fetchone()[0]
    )
    if actual_eligible != expected_eligible:
        raise RuntimeError(
            f"Eligible virtual-trial grain mismatch: {actual_eligible} != {expected_eligible}"
        )
    invalid_weights = int(
        connection.execute(
            f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, origin_id, sum(origin_sample_weight) AS total_weight
  FROM {ELIGIBLE_VIRTUAL_TRIALS_TABLE}
  GROUP BY ALL
  HAVING abs(total_weight - 1.0) > 1e-9
)
"""
        ).fetchone()[0]
    )
    if invalid_weights:
        raise RuntimeError("Eligible virtual-trial origin weights do not sum to one")
    expected_chains = int(
        connection.execute(
            "SELECT count(DISTINCT (run_id, config_id, policy_id)) "
            "FROM virtual_trials WHERE trial_role = 'MATRIX'"
        ).fetchone()[0]
    )
    actual_chains = int(
        connection.execute(f"SELECT count(*) FROM {POLICY_CHAINS_TABLE}").fetchone()[0]
    )
    if actual_chains != expected_chains:
        raise RuntimeError(f"Policy-chain grain mismatch: {actual_chains} != {expected_chains}")
    expected_calibration = int(
        connection.execute(
            "SELECT count(*) FROM broker_outcomes WHERE parity_trial_id IS NOT NULL"
        ).fetchone()[0]
    )
    actual_calibration = int(
        connection.execute(
            f"SELECT count(*) FROM {BROKER_VIRTUAL_CALIBRATION_TABLE}"
        ).fetchone()[0]
    )
    if actual_calibration != expected_calibration:
        raise RuntimeError(
            f"Broker/virtual calibration grain mismatch: {actual_calibration} != {expected_calibration}"
        )
    unexplained_mismatches = int(
        connection.execute(
            f"""
SELECT count(*)
FROM {BROKER_VIRTUAL_CALIBRATION_TABLE}
WHERE strict_pair_eligible AND NOT terminal_agreement
"""
        ).fetchone()[0]
    )
    if unexplained_mismatches:
        raise RuntimeError("Calibration contains unexplained strict TP/SL mismatch")
    long_columns = {
        row[0]
        for row in connection.execute(f"DESCRIBE {ORIGIN_MATRIX_LONG_TABLE}").fetchall()
    }
    missing_features = sorted(set(MODEL_FEATURE_COLUMNS) - long_columns)
    if missing_features:
        raise RuntimeError(f"Origin matrix long lacks model features: {missing_features}")
    leaked_features = sorted(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
    if leaked_features:
        raise RuntimeError(f"Future-only fields leaked into model features: {leaked_features}")


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS,
) -> dict[str, int]:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise RuntimeError(
            f"Only schema {SUPPORTED_SCHEMA_VERSION} dataset assembly is active"
        )
    if tuple(feature_columns) != MODEL_FEATURE_COLUMNS:
        raise RuntimeError("Schema V11 requires the exact frozen feature set")
    if not validations:
        raise RuntimeError("At least one validated run is required")
    for filename in RUN_FILES:
        table_name = Path(filename).stem
        _load_typed_table(
            connection,
            table_name,
            [validation.run_path / filename for validation in validations],
            TABLE_COLUMNS[filename],
        )
    _create_origin_matrix_long(connection)
    _create_initial_matrix_wide(connection)
    _create_eligible_virtual_trials(connection)
    _create_policy_chains(connection)
    _create_broker_virtual_calibration(connection)
    _validate_derived_tables(connection)
    table_names = [Path(filename).stem for filename in RUN_FILES] + list(DERIVED_TABLES)
    return {
        table_name: int(
            connection.execute(f"SELECT count(*) FROM {table_name}").fetchone()[0]
        )
        for table_name in table_names
    }


def prepare_output_dir(output_root: Path, dataset_id: str, overwrite: bool) -> Path:
    if not dataset_id or Path(dataset_id).name != dataset_id or dataset_id in (".", ".."):
        raise RuntimeError(f"Invalid dataset ID: {dataset_id}")
    root = output_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    output_dir = (root / dataset_id).resolve()
    if output_dir.parent != root:
        raise RuntimeError(f"Refusing output outside dataset root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise RuntimeError(f"Dataset output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    return output_dir


def write_parquet_outputs(
    connection: duckdb.DuckDBPyConnection,
    output_dir: Path,
    counts: dict[str, int],
) -> dict[str, str]:
    output_files: dict[str, str] = {}
    for table_name in counts:
        output_path = output_dir / f"{table_name}.parquet"
        connection.execute(
            f"COPY {table_name} TO {_sql_literal(output_path.resolve().as_posix())} "
            "(FORMAT PARQUET, COMPRESSION ZSTD)"
        )
        output_files[table_name] = output_path.name
    return output_files


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs-root", required=True, help="Folder containing V11 run folders.")
    parser.add_argument(
        "--run-id",
        action="append",
        required=True,
        help="Run folder name. Repeat to assemble multiple compatible runs.",
    )
    parser.add_argument("--dataset-id", default="", help="Required unless --validate-only is used.")
    parser.add_argument("--output-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--schema-version", type=int, default=SUPPORTED_SCHEMA_VERSION)
    parser.add_argument("--feature-set-id", default=SUPPORTED_FEATURE_SET_ID)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        feature_columns = feature_columns_for_set(args.feature_set_id)
        validations = validate_runs(
            Path(args.runs_root),
            args.run_id,
            schema_version=args.schema_version,
        )
        if args.validate_only:
            for validation in validations:
                print(
                    f"validated run_id={validation.run_id} "
                    f"origins={validation.signal_origin_rows} "
                    f"trials={validation.virtual_trial_rows} "
                    f"outcomes={validation.virtual_outcome_rows}"
                )
            return 0
        if not args.dataset_id:
            raise RuntimeError("--dataset-id is required unless --validate-only is used")
        output_dir = prepare_output_dir(
            Path(args.output_root),
            args.dataset_id,
            args.overwrite,
        )
        connection = duckdb.connect(":memory:")
        try:
            counts = create_dataset_tables(
                connection,
                validations,
                schema_version=args.schema_version,
                feature_columns=feature_columns,
            )
            output_files = write_parquet_outputs(connection, output_dir, counts)
            quality = build_quality_payload(connection, validations, counts)
            write_dataset_manifest(
                output_dir,
                args.dataset_id,
                validations,
                counts,
                output_files,
                quality,
            )
            write_quality_json(output_dir, quality)
            write_dataset_report(output_dir, args.dataset_id, quality)
        finally:
            connection.close()
        print(f"dataset_id={args.dataset_id} output={output_dir}")
        return 0
    except (RuntimeError, ValueError, SchemaValidationError, duckdb.Error) as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
