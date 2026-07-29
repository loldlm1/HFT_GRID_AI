"""Build typed Parquet datasets from schema v8 market-data exports."""

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
    BROKER_TARGET_FAMILY,
    DATASET_TARGET_FAMILIES,
    ENGINE_ATTEMPT_COLUMNS,
    ENGINE_ATTEMPTS_FILE,
    ENGINE_CYCLE_COLUMNS,
    ENGINE_CYCLES_FILE,
    ENGINE_REVISION_COLUMNS,
    ENGINE_REVISIONS_FILE,
    ENGINE_SIMULATED_TARGET_FAMILY,
    EXECUTION_CHECK_COLUMNS,
    EXECUTION_CHECKS_FILE,
    FEATURE_SET_COLUMNS,
    PATH_RATIO_OUTCOME_COLUMNS,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_FEATURE_COLUMNS,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOME_COLUMNS,
    SIGNAL_OUTCOMES_FILE,
    SUMMARY_COLUMNS,
    SUPPORTED_SCHEMA_VERSION,
    SUPPORTED_SCHEMA_VERSIONS,
    default_feature_set_for_schema,
    feature_columns_for_set,
    schema_version_for_feature_set,
)
from validate_phase1_run import Phase1ValidationError, validate_phase1_runs


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


def _varchar_columns_sql(columns: tuple[str, ...]) -> str:
    return "{" + ", ".join(f"'{column}': 'VARCHAR'" for column in columns) + "}"


def _read_tsv_sql(path: Path, columns: tuple[str, ...]) -> str:
    return (
        "read_csv("
        f"{_sql_literal(path)}, delim='\\t', header=true, "
        f"columns={_varchar_columns_sql(columns)}, nullstr='\\N'"
        ")"
    )


def _load_raw_table(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
    paths: list[Path],
    columns: tuple[str, ...],
) -> None:
    if not paths:
        raise RuntimeError(f"No source paths for {table_name}")
    connection.execute(
        f"CREATE TABLE raw_{table_name} AS SELECT * FROM {_read_tsv_sql(paths[0], columns)}"
    )
    for path in paths[1:]:
        connection.execute(
            f"INSERT INTO raw_{table_name} SELECT * FROM {_read_tsv_sql(path, columns)}"
        )


def _time_sql(column: str) -> str:
    return f"strptime({column}, '{TIMESTAMP_FORMAT}')"


def _cast_double(column: str) -> str:
    return f"CAST({column} AS DOUBLE)"


def _cast_int(column: str) -> str:
    return f"CAST({column} AS INTEGER)"


def _create_typed_tables(
    connection: duckdb.DuckDBPyConnection,
    validations,
) -> None:
    run_paths = [validation.run_path for validation in validations]
    _load_raw_table(connection, "run_manifest", [path / RUN_MANIFEST_FILE for path in run_paths], ("schema_version", "key", "value"))
    _load_raw_table(connection, "engine_cycles", [path / ENGINE_CYCLES_FILE for path in run_paths], ENGINE_CYCLE_COLUMNS)
    _load_raw_table(connection, "engine_revisions", [path / ENGINE_REVISIONS_FILE for path in run_paths], ENGINE_REVISION_COLUMNS)
    _load_raw_table(connection, "engine_attempts", [path / ENGINE_ATTEMPTS_FILE for path in run_paths], ENGINE_ATTEMPT_COLUMNS)
    _load_raw_table(connection, "execution_checks", [path / EXECUTION_CHECKS_FILE for path in run_paths], EXECUTION_CHECK_COLUMNS)
    _load_raw_table(connection, "signal_features", [path / SIGNAL_FEATURES_FILE for path in run_paths], SIGNAL_FEATURE_COLUMNS)
    _load_raw_table(connection, "signal_outcomes", [path / SIGNAL_OUTCOMES_FILE for path in run_paths], SIGNAL_OUTCOME_COLUMNS)
    _load_raw_table(connection, "run_summary", [path / RUN_SUMMARY_FILE for path in run_paths], SUMMARY_COLUMNS)

    connection.execute(
        f"""
CREATE TABLE engine_cycles AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, symbol,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_type,
  {_time_sql('cycle_first_seen_broker_time')} AS cycle_first_seen_broker_time,
  {_time_sql('cycle_first_seen_analysis_time')} AS cycle_first_seen_analysis_time,
  {_cast_int('cycle_first_seen_offset_minutes')} AS cycle_first_seen_offset_minutes,
  {_time_sql('cycle_finalized_broker_time')} AS cycle_finalized_broker_time,
  {_time_sql('cycle_finalized_analysis_time')} AS cycle_finalized_analysis_time,
  {_cast_int('cycle_finalized_offset_minutes')} AS cycle_finalized_offset_minutes,
  cycle_status,
  {_time_sql('reference_peak_broker_time')} AS reference_peak_broker_time,
  {_time_sql('reference_peak_analysis_time')} AS reference_peak_analysis_time,
  {_cast_int('reference_peak_offset_minutes')} AS reference_peak_offset_minutes,
  {_cast_double('reference_peak_price')} AS reference_peak_price,
  {_time_sql('reference_bottom_broker_time')} AS reference_bottom_broker_time,
  {_time_sql('reference_bottom_analysis_time')} AS reference_bottom_analysis_time,
  {_cast_int('reference_bottom_offset_minutes')} AS reference_bottom_offset_minutes,
  {_cast_double('reference_bottom_price')} AS reference_bottom_price,
  {_cast_double('reference_range_points')} AS reference_range_points,
  {_time_sql('first_extremum_broker_time')} AS first_extremum_broker_time,
  {_time_sql('first_extremum_analysis_time')} AS first_extremum_analysis_time,
  {_cast_int('first_extremum_offset_minutes')} AS first_extremum_offset_minutes,
  {_cast_double('first_extremum_price')} AS first_extremum_price,
  {_time_sql('final_extremum_broker_time')} AS final_extremum_broker_time,
  {_time_sql('final_extremum_analysis_time')} AS final_extremum_analysis_time,
  {_cast_int('final_extremum_offset_minutes')} AS final_extremum_offset_minutes,
  {_cast_double('final_extremum_price')} AS final_extremum_price,
  {_cast_double('final_depth_percent')} AS final_depth_percent,
  {_cast_int('revision_count')} AS revision_count,
  {_cast_int('attempt_count')} AS attempt_count
FROM raw_engine_cycles
"""
    )
    connection.execute(
        f"""
CREATE TABLE engine_revisions AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, symbol,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, revision_id, {_cast_int('revision_index')} AS revision_index,
  {_time_sql('snapshot_broker_time')} AS snapshot_broker_time,
  {_time_sql('snapshot_analysis_time')} AS snapshot_analysis_time,
  {_cast_int('snapshot_offset_minutes')} AS snapshot_offset_minutes,
  {_time_sql('extremum_broker_time')} AS extremum_broker_time,
  {_time_sql('extremum_analysis_time')} AS extremum_analysis_time,
  {_cast_int('extremum_offset_minutes')} AS extremum_offset_minutes,
  {_cast_double('extremum_price')} AS extremum_price, extremum_type,
  {_cast_double('depth_percent_raw')} AS depth_percent_raw,
  {_cast_double('distance_from_first_revision_points')} AS distance_from_first_revision_points,
  {_cast_double('distance_from_previous_revision_points')} AS distance_from_previous_revision_points,
  {_cast_double('depth_delta_from_previous_percent')} AS depth_delta_from_previous_percent,
  {_cast_int('bars_since_cycle_start')} AS bars_since_cycle_start,
  {_time_sql('reference_peak_broker_time')} AS reference_peak_broker_time,
  {_time_sql('reference_peak_analysis_time')} AS reference_peak_analysis_time,
  {_cast_int('reference_peak_offset_minutes')} AS reference_peak_offset_minutes,
  {_cast_double('reference_peak_price')} AS reference_peak_price,
  {_time_sql('reference_bottom_broker_time')} AS reference_bottom_broker_time,
  {_time_sql('reference_bottom_analysis_time')} AS reference_bottom_analysis_time,
  {_cast_int('reference_bottom_offset_minutes')} AS reference_bottom_offset_minutes,
  {_cast_double('reference_bottom_price')} AS reference_bottom_price,
  {_cast_double('reference_range_points')} AS reference_range_points,
  structure_0, structure_1, structure_2, session_id,
  {_cast_double('time_sin')} AS time_sin, {_cast_double('time_cos')} AS time_cos
FROM raw_engine_revisions
"""
    )
    connection.execute(
        f"""
CREATE TABLE engine_attempts AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, symbol,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, revision_id, attempt_id,
  {_cast_int('cycle_attempt_index')} AS cycle_attempt_index,
  {_cast_int('revision_attempt_index')} AS revision_attempt_index,
  {_time_sql('attempt_created_broker_time')} AS attempt_created_broker_time,
  {_time_sql('attempt_created_analysis_time')} AS attempt_created_analysis_time,
  {_cast_int('attempt_created_offset_minutes')} AS attempt_created_offset_minutes,
  direction, {_cast_double('candidate_depth_percent')} AS candidate_depth_percent,
  {_cast_double('reference_range_points')} AS reference_range_points,
  {_cast_double('distance_from_first_revision_points')} AS distance_from_first_revision_points,
  {_cast_double('distance_from_previous_revision_points')} AS distance_from_previous_revision_points,
  {_cast_double('depth_delta_from_previous_percent')} AS depth_delta_from_previous_percent,
  {_cast_int('bars_since_cycle_start')} AS bars_since_cycle_start,
  {_cast_double('trigger_price')} AS trigger_price,
  {_cast_double('stop_anchor_price')} AS stop_anchor_price,
  {_cast_double('take_profit_price')} AS take_profit_price,
  {_cast_int('trigger_reached')} AS trigger_reached,
  {_time_sql('trigger_broker_time')} AS trigger_broker_time,
  {_time_sql('trigger_analysis_time')} AS trigger_analysis_time,
  {_cast_int('trigger_offset_minutes')} AS trigger_offset_minutes,
  attempt_status, operational_block_source, operational_block_reason,
  simulated_terminal_reason, {_cast_double('simulated_profit_r')} AS simulated_profit_r,
  {_cast_double('simulated_max_favorable_r')} AS simulated_max_favorable_r,
  {_cast_double('simulated_max_adverse_r')} AS simulated_max_adverse_r,
  simulated_path_status, simulated_outcome_source, broker_signal_id,
  {_cast_int('broker_entry_confirmed')} AS broker_entry_confirmed,
  {_cast_int('broker_close_confirmed')} AS broker_close_confirmed
FROM raw_engine_attempts
"""
    )
    connection.execute(
        f"""
CREATE TABLE execution_checks AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, signal_id,
  source_key, {_cast_int('source_attempt_index')} AS source_attempt_index,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id,
  {_cast_int('check_sequence')} AS check_sequence, check_phase,
  {_time_sql('broker_time')} AS broker_time, {_time_sql('analysis_time')} AS analysis_time,
  {_cast_int('offset_minutes')} AS offset_minutes, symbol, direction,
  account_margin_mode, {_cast_int('account_margin_mode_supported')} AS account_margin_mode_supported,
  symbol_trade_mode, {_cast_int('symbol_trade_mode_allowed')} AS symbol_trade_mode_allowed,
  {_cast_int('market_session_open')} AS market_session_open,
  {_cast_int('account_trade_allowed')} AS account_trade_allowed,
  {_cast_int('account_expert_trade_allowed')} AS account_expert_trade_allowed,
  {_cast_int('terminal_trade_allowed')} AS terminal_trade_allowed,
  {_cast_int('mql_trade_allowed')} AS mql_trade_allowed,
  {_cast_double('bid')} AS bid, {_cast_double('ask')} AS ask,
  {_cast_double('spread_points')} AS spread_points, {_cast_double('point_size')} AS point_size,
  {_cast_double('stops_distance_points')} AS stops_distance_points,
  {_cast_double('freeze_distance_points')} AS freeze_distance_points,
  {_cast_double('planned_entry_price')} AS planned_entry_price,
  {_cast_double('stop_loss_price')} AS stop_loss_price,
  {_cast_double('take_profit_price')} AS take_profit_price,
  {_cast_double('risk_distance')} AS risk_distance,
  {_cast_double('requested_volume')} AS requested_volume,
  {_cast_double('normalized_volume')} AS normalized_volume,
  {_cast_double('volume_min')} AS volume_min, {_cast_double('volume_max')} AS volume_max,
  {_cast_double('volume_step')} AS volume_step, {_cast_int('volume_valid')} AS volume_valid,
  {_cast_double('account_balance')} AS account_balance, {_cast_double('free_margin')} AS free_margin,
  {_cast_double('required_margin')} AS required_margin, {_cast_int('margin_valid')} AS margin_valid,
  {_cast_int('geometry_valid')} AS geometry_valid, {_cast_int('stop_distance_valid')} AS stop_distance_valid,
  {_cast_int('freeze_distance_valid')} AS freeze_distance_valid,
  {_cast_int('order_check_performed')} AS order_check_performed,
  {_cast_int('order_check_allowed')} AS order_check_allowed,
  {_cast_int('order_check_retcode')} AS order_check_retcode,
  order_check_comment, {_cast_int('allowed')} AS allowed, block_source, block_reason,
  {_cast_int('send_retcode')} AS send_retcode, send_comment,
  {_cast_int('order_ticket')} AS order_ticket, {_cast_int('deal_ticket')} AS deal_ticket,
  {_cast_int('position_ticket')} AS position_ticket, {_cast_int('position_identifier')} AS position_identifier,
  {_cast_int('broker_entry_confirmed')} AS broker_entry_confirmed,
  {_cast_int('broker_close_confirmed')} AS broker_close_confirmed,
  {_cast_double('broker_entry_price')} AS broker_entry_price,
  {_cast_double('broker_volume')} AS broker_volume,
  {_cast_double('broker_stop_loss')} AS broker_stop_loss,
  {_cast_double('broker_take_profit')} AS broker_take_profit,
  {_cast_double('close_price')} AS close_price,
  {_cast_double('closed_volume')} AS closed_volume,
  {_cast_double('realized_profit')} AS realized_profit,
  terminal_reason
FROM raw_execution_checks
"""
    )
    connection.execute(
        f"""
CREATE TABLE signal_features AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, signal_id,
  source_key, {_cast_int('source_attempt_index')} AS source_attempt_index,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id, symbol, direction,
  {_time_sql('entry_broker_time')} AS entry_broker_time,
  {_time_sql('entry_analysis_time')} AS entry_analysis_time,
  {_cast_int('entry_offset_minutes')} AS entry_offset_minutes,
  {_time_sql('source_broker_time')} AS source_broker_time,
  {_time_sql('source_analysis_time')} AS source_analysis_time,
  {_cast_int('source_offset_minutes')} AS source_offset_minutes,
  structure_0, structure_1, structure_2, fib_sl_band, fib_entry_band,
  high_chain_profile, low_chain_profile, previous_candle_profile,
  entry_session_bucket, entry_weekday,
  {_cast_double('stoch_structure_raw_percent')} AS stoch_structure_raw_percent,
  {_cast_double('b_percent_main_base')} AS b_percent_main_base,
  {_cast_double('b_percent_main_base_slope')} AS b_percent_main_base_slope,
  {_cast_double('b_percent_main_macro')} AS b_percent_main_macro,
  {_cast_double('b_percent_main_macro_slope')} AS b_percent_main_macro_slope,
  session_id, {_cast_double('time_sin')} AS time_sin, {_cast_double('time_cos')} AS time_cos
FROM raw_signal_features
"""
    )
    connection.execute(
        f"""
CREATE TABLE signal_outcomes AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id, signal_id,
  source_key, {_cast_int('source_attempt_index')} AS source_attempt_index,
  {_cast_int('engine_id')} AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id,
  {_time_sql('entry_broker_time')} AS entry_broker_time,
  {_time_sql('entry_analysis_time')} AS entry_analysis_time,
  {_cast_int('entry_offset_minutes')} AS entry_offset_minutes,
  {_time_sql('terminal_broker_time')} AS terminal_broker_time,
  {_time_sql('terminal_analysis_time')} AS terminal_analysis_time,
  {_cast_int('terminal_offset_minutes')} AS terminal_offset_minutes,
  terminal_reason, {_cast_double('profit_r')} AS profit_r,
  {_cast_int('duration_seconds')} AS duration_seconds,
  {_cast_int('duration_m1_bars')} AS duration_m1_bars,
  {_cast_double('entry_price')} AS entry_price, {_cast_double('close_price')} AS close_price,
  {_cast_double('net_profit')} AS net_profit,
  {_cast_int('broker_entry_confirmed')} AS broker_entry_confirmed,
  {_cast_int('broker_close_confirmed')} AS broker_close_confirmed,
  broker_close_source,
  {_cast_int('hit_1r_before_sl')} AS hit_1r_before_sl,
  {_cast_int('hit_1_5r_before_sl')} AS hit_1_5r_before_sl,
  {_cast_int('hit_2r_before_sl')} AS hit_2r_before_sl,
  {_cast_int('hit_3r_before_sl')} AS hit_3r_before_sl,
  {_cast_double('max_favorable_r')} AS max_favorable_r,
  {_cast_double('max_adverse_r')} AS max_adverse_r,
  {_cast_int('bars_to_1r')} AS bars_to_1r,
  {_cast_int('bars_to_1_5r')} AS bars_to_1_5r,
  {_cast_int('bars_to_2r')} AS bars_to_2r,
  {_cast_int('bars_to_3r')} AS bars_to_3r,
  {_cast_int('bars_to_sl')} AS bars_to_sl,
  {_cast_int('path_horizon_bars')} AS path_horizon_bars,
  path_status, path_label_source
FROM raw_signal_outcomes
"""
    )
    connection.execute(
        f"""
CREATE TABLE run_manifest AS
SELECT {_cast_int('schema_version')} AS schema_version, key, value
FROM raw_run_manifest
"""
    )
    connection.execute(
        f"""
CREATE TABLE run_summary AS
SELECT
  {_cast_int('schema_version')} AS schema_version, run_id, config_id,
  {_time_sql('started_broker_time')} AS started_broker_time,
  {_time_sql('started_analysis_time')} AS started_analysis_time,
  {_cast_int('started_offset_minutes')} AS started_offset_minutes,
  {_time_sql('finished_broker_time')} AS finished_broker_time,
  {_time_sql('finished_analysis_time')} AS finished_analysis_time,
  {_cast_int('finished_offset_minutes')} AS finished_offset_minutes,
  {_cast_int('cycle_rows')} AS cycle_rows, {_cast_int('revision_rows')} AS revision_rows,
  {_cast_int('attempt_rows')} AS attempt_rows, {_cast_int('execution_check_rows')} AS execution_check_rows,
  {_cast_int('feature_rows')} AS feature_rows, {_cast_int('outcome_rows')} AS outcome_rows,
  {_cast_int('feature_invalid_rows')} AS feature_invalid_rows,
  {_cast_int('outcome_invalid_rows')} AS outcome_invalid_rows,
  {_cast_int('max_active_attempt_paths')} AS max_active_attempt_paths,
  export_status
FROM raw_run_summary
"""
    )

    # These views provide stable research aliases while the persisted tables keep exact v8 names.
    connection.execute(
        """
CREATE VIEW features AS
SELECT
  sf.*,
  sf.entry_analysis_time AS entry_time,
  sf.source_analysis_time AS source_time,
  sf.engine_label AS strategy_label
FROM signal_features sf
"""
    )
    connection.execute(
        """
CREATE VIEW outcomes AS
SELECT so.*, so.terminal_analysis_time AS terminal_time
FROM signal_outcomes so
"""
    )


def _target_sql(target_family: str) -> tuple[str, str, str, str]:
    if target_family == BROKER_TARGET_FAMILY:
        return (
            "CASE WHEN o.profit_r > 0 THEN 1 ELSE 0 END",
            "o.profit_r",
            "CASE WHEN o.profit_r > 0 THEN 'BROKER_PROFIT' WHEN o.profit_r < 0 THEN 'BROKER_LOSS' ELSE 'BROKER_FLAT' END",
            "o.signal_id IS NOT NULL AND o.broker_entry_confirmed = 1 AND o.broker_close_confirmed = 1",
        )
    if target_family == ENGINE_SIMULATED_TARGET_FAMILY:
        return (
            "CASE WHEN a.simulated_profit_r > 0 THEN 1 ELSE 0 END",
            "a.simulated_profit_r",
            "'ENGINE_' || a.simulated_terminal_reason",
            "a.trigger_reached = 1 AND a.simulated_path_status IN ('SL_FIRST', 'TARGET', 'HORIZON_EXPIRED') AND a.simulated_profit_r IS NOT NULL",
        )
    ratio_by_family = {
        "1r": ("hit_1r_before_sl", 1.0),
        "1_5r": ("hit_1_5r_before_sl", 1.5),
        "2r": ("hit_2r_before_sl", 2.0),
        "3r": ("hit_3r_before_sl", 3.0),
    }
    if target_family in ratio_by_family:
        column, target_r = ratio_by_family[target_family]
        return (
            f"CAST(o.{column} AS INTEGER)",
            f"CASE WHEN o.{column} = 1 THEN {target_r:.1f} WHEN o.path_status = 'SL_FIRST' THEN -1.0 ELSE 0.0 END",
            f"'PATH_{target_family}_' || o.path_status",
            f"o.signal_id IS NOT NULL AND o.path_status IN ('SL_FIRST', 'TARGET_3R', 'HORIZON_EXPIRED') AND o.{column} IS NOT NULL",
        )
    if target_family == "expected_r":
        expected = "CASE WHEN o.path_status = 'TARGET_3R' THEN 3.0 WHEN o.path_status = 'SL_FIRST' THEN -1.0 WHEN o.path_status = 'HORIZON_EXPIRED' THEN COALESCE(o.max_favorable_r, 0.0) ELSE NULL END"
        return (
            f"CASE WHEN ({expected}) > 0 THEN 1 ELSE 0 END",
            expected,
            "'PATH_EXPECTED_R_' || o.path_status",
            f"o.signal_id IS NOT NULL AND o.path_status IN ('SL_FIRST', 'TARGET_3R', 'HORIZON_EXPIRED') AND ({expected}) IS NOT NULL",
        )
    raise RuntimeError(f"Unsupported target family: {target_family}")


def _create_training_matrix(
    connection: duckdb.DuckDBPyConnection,
    target_family: str,
    feature_columns: tuple[str, ...],
) -> None:
    target_is_win, target_profit, target_reason, target_valid = _target_sql(target_family)
    required = " AND ".join(
        f"COALESCE(f.{column}, r.{column}) IS NOT NULL" if column in {"structure_0", "structure_1", "structure_2", "session_id", "time_sin", "time_cos"}
        else f"a.{column} IS NOT NULL"
        for column in feature_columns
    )
    target_source = (
        "ENGINE_SIMULATION"
        if target_family == ENGINE_SIMULATED_TARGET_FAMILY
        else "BROKER_CONFIRMED"
    )
    connection.execute(
        f"""
CREATE TABLE training_matrix AS
SELECT
  a.schema_version, a.run_id, a.config_id, a.symbol, a.engine_id, a.engine_label,
  a.engine_timeframe, a.extremum_cycle_id, a.revision_id AS extremum_revision_id,
  a.attempt_id AS extremum_attempt_id,
  COALESCE(f.signal_id, a.broker_signal_id, a.attempt_id) AS signal_id,
  COALESCE(f.source_key, a.symbol || '|' || a.engine_label || '|' || a.revision_id) AS source_key,
  COALESCE(f.source_attempt_index, a.cycle_attempt_index - 1) AS source_attempt_index,
  COALESCE(f.entry_broker_time, a.attempt_created_broker_time) AS entry_broker_time,
  COALESCE(f.entry_analysis_time, a.attempt_created_analysis_time) AS entry_analysis_time,
  COALESCE(f.entry_offset_minutes, a.attempt_created_offset_minutes) AS entry_offset_minutes,
  COALESCE(f.entry_analysis_time, a.attempt_created_analysis_time) AS entry_time,
  r.snapshot_broker_time AS source_broker_time,
  r.snapshot_analysis_time AS source_analysis_time,
  r.snapshot_offset_minutes AS source_offset_minutes,
  r.snapshot_analysis_time AS source_time,
  a.direction, a.cycle_attempt_index, a.revision_attempt_index,
  a.candidate_depth_percent, a.reference_range_points,
  a.distance_from_first_revision_points, a.distance_from_previous_revision_points,
  a.depth_delta_from_previous_percent, a.bars_since_cycle_start,
  r.structure_0, r.structure_1, r.structure_2, r.session_id, r.time_sin, r.time_cos,
  f.fib_sl_band, f.fib_entry_band, f.high_chain_profile, f.low_chain_profile,
  f.previous_candle_profile, f.entry_session_bucket, f.entry_weekday,
  f.stoch_structure_raw_percent, f.b_percent_main_base, f.b_percent_main_base_slope,
  f.b_percent_main_macro, f.b_percent_main_macro_slope,
  a.engine_label AS strategy_label,
  o.terminal_broker_time, o.terminal_analysis_time, o.terminal_analysis_time AS terminal_time,
  o.terminal_reason, o.profit_r, o.duration_seconds, o.duration_m1_bars,
  o.entry_price, o.close_price, o.net_profit,
  o.hit_1r_before_sl, o.hit_1_5r_before_sl, o.hit_2r_before_sl, o.hit_3r_before_sl,
  o.max_favorable_r, o.max_adverse_r, o.bars_to_1r, o.bars_to_1_5r,
  o.bars_to_2r, o.bars_to_3r, o.bars_to_sl, o.path_horizon_bars, o.path_status,
  a.simulated_profit_r, a.simulated_path_status,
  (SELECT COUNT(*)
   FROM execution_checks c
   WHERE c.run_id = a.run_id
     AND c.config_id = a.config_id
     AND c.extremum_attempt_id = a.attempt_id) AS execution_check_count,
  (SELECT COUNT(*)
   FROM execution_checks c
   WHERE c.run_id = a.run_id
     AND c.config_id = a.config_id
     AND c.extremum_attempt_id = a.attempt_id
     AND c.allowed = 0) AS blocked_check_count,
  {target_is_win} AS target_is_win,
  {target_profit} AS target_profit_r,
  {target_reason} AS target_terminal_reason,
  '{target_source}' AS target_source
FROM engine_attempts a
JOIN engine_revisions r
  ON r.run_id = a.run_id
 AND r.config_id = a.config_id
 AND r.revision_id = a.revision_id
LEFT JOIN signal_features f
  ON f.run_id = a.run_id
 AND f.config_id = a.config_id
 AND f.extremum_attempt_id = a.attempt_id
LEFT JOIN signal_outcomes o
  ON o.run_id = a.run_id
 AND o.config_id = a.config_id
 AND o.extremum_attempt_id = a.attempt_id
WHERE {target_valid}
  AND {required}
ORDER BY entry_broker_time, extremum_attempt_id
"""
    )


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations,
    target_family: str,
    schema_version: int,
    feature_columns: tuple[str, ...],
) -> dict[str, int]:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise RuntimeError("Only schema v8 dataset assembly is active")
    if target_family not in DATASET_TARGET_FAMILIES:
        raise RuntimeError(f"Unsupported target family: {target_family}")
    _create_typed_tables(connection, validations)
    _create_training_matrix(connection, target_family, feature_columns)
    table_names = (
        "run_manifest",
        "engine_cycles",
        "engine_revisions",
        "engine_attempts",
        "execution_checks",
        "signal_features",
        "signal_outcomes",
        "run_summary",
        "training_matrix",
    )
    return {
        table_name: int(connection.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0])
        for table_name in table_names
    }


def prepare_output_dir(output_root: Path, dataset_id: str, overwrite: bool) -> Path:
    output_dir = output_root / dataset_id
    resolved_root = output_root.resolve()
    resolved_output = output_dir.resolve()
    if resolved_root != resolved_output and resolved_root not in resolved_output.parents:
        raise RuntimeError(f"Refusing output outside output root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise RuntimeError(f"Dataset output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    return output_dir


def write_parquet_outputs(
    connection: duckdb.DuckDBPyConnection,
    output_dir: Path,
    counts: dict[str, int],
) -> dict[str, str]:
    output_files = {table_name: str(output_dir / f"{table_name}.parquet") for table_name in counts}
    for table_name, output_file in output_files.items():
        connection.execute(f"COPY {table_name} TO {_sql_literal(output_file)} (FORMAT parquet)")
        read_back_count = connection.execute(
            f"SELECT COUNT(*) FROM read_parquet({_sql_literal(output_file)})"
        ).fetchone()[0]
        if read_back_count != counts[table_name]:
            raise RuntimeError(
                f"Parquet readback mismatch for {table_name}: wrote={counts[table_name]}, read={read_back_count}"
            )
    return output_files


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs-root", required=True, help="Folder containing schema v8 run folders.")
    parser.add_argument("--run-id", action="append", required=True, help="Run ID to include. Repeat for multiple runs.")
    parser.add_argument("--dataset-id", required=True, help="Dataset output ID.")
    parser.add_argument("--output-root", default="artifacts/datasets", help="Dataset output root.")
    parser.add_argument("--schema-version", type=int, default=SUPPORTED_SCHEMA_VERSION, choices=SUPPORTED_SCHEMA_VERSIONS, help="Active export schema (8).")
    parser.add_argument("--feature-set-id", choices=tuple(FEATURE_SET_COLUMNS), default="", help="Research feature set; defaults to schema v8 engine features.")
    parser.add_argument("--target-family", default=BROKER_TARGET_FAMILY, choices=DATASET_TARGET_FAMILIES, help="Target family to derive.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing dataset folder.")
    parser.add_argument("--validate-only", action="store_true", help="Validate inputs without writing Parquet files.")
    parser.add_argument("--allow-mixed-config", action="store_true", help="Allow multiple config_id values across selected runs.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    feature_set_id = args.feature_set_id or default_feature_set_for_schema(args.schema_version)
    if schema_version_for_feature_set(feature_set_id) != args.schema_version:
        parser.exit(1, "validation failed: feature set and schema version do not match\n")
    try:
        validations = validate_phase1_runs(
            Path(args.runs_root),
            args.run_id,
            schema_version=args.schema_version,
            allow_mixed_config=args.allow_mixed_config,
        )
    except (Phase1ValidationError, TypeError) as exc:
        parser.exit(1, f"validation failed: {exc}\n")
    print(
        "validation ok | "
        f"runs={len(validations)} | features={sum(v.feature_rows for v in validations)} | "
        f"checks={sum(v.execution_check_rows for v in validations)} | "
        f"outcomes={sum(v.outcome_rows for v in validations)}"
    )
    for validation in validations:
        for warning in validation.warnings:
            print(f"warning [{validation.run_id}]: {warning}")
    if args.validate_only:
        return 0
    connection = duckdb.connect(":memory:")
    try:
        counts = create_dataset_tables(connection, validations, args.target_family, args.schema_version, feature_columns_for_set(feature_set_id))
        if counts["training_matrix"] <= 0:
            parser.exit(1, f"build failed: no valid rows for target_family={args.target_family}\n")
        output_dir = prepare_output_dir(Path(args.output_root), args.dataset_id, args.overwrite)
        output_files = write_parquet_outputs(connection, output_dir, counts)
        quality = build_quality_payload(connection, validations, counts, args.target_family, feature_columns_for_set(feature_set_id))
        write_dataset_manifest(output_dir, output_dir.name, validations, counts, output_files, args.target_family, args.schema_version, feature_set_id, feature_columns_for_set(feature_set_id))
        write_quality_json(output_dir, quality)
        write_dataset_report(output_dir, output_dir.name, quality)
    except (RuntimeError, duckdb.Error) as exc:
        parser.exit(1, f"build failed: {exc}\n")
    finally:
        connection.close()
    print(f"dataset written | path={output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
