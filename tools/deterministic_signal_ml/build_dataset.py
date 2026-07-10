"""Build local deterministic signal datasets from Phase 1 TSV exports."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import duckdb

from schema_contract import (
    BROKER_TARGET_FAMILY,
    DATASET_TARGET_FAMILIES,
    ENGINE_ATTEMPTS_FILE,
    ENGINE_CYCLES_FILE,
    ENGINE_REVISIONS_FILE,
    ENGINE_SIMULATED_TARGET_FAMILY,
    FEATURE_SET_COLUMNS,
    OUTCOME_COLUMNS,
    OUTCOME_COLUMNS_WITH_PATH,
    SCHEMA_V6_ADMISSION_COLUMNS,
    SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH,
    SCHEMA_V7_ADMISSION_COLUMNS,
    SCHEMA_V7_ATTEMPT_COLUMNS,
    SCHEMA_V7_CYCLE_COLUMNS,
    SCHEMA_V7_FEATURE_COLUMNS,
    SCHEMA_V7_LEG_OUTCOME_COLUMNS,
    SCHEMA_V7_OUTCOME_COLUMNS_WITH_PATH,
    SCHEMA_V7_REVISION_COLUMNS,
    SIGNAL_ADMISSIONS_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_LEG_OUTCOMES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_SCHEMA_VERSION,
    SUPPORTED_SCHEMA_VERSIONS,
    default_feature_set_for_schema,
    feature_columns_for_schema,
    feature_columns_for_set,
    schema_version_for_feature_set,
)
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
)
from validate_phase1_run import Phase1ValidationError, validate_phase1_runs


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


def _varchar_columns_sql(columns: tuple[str, ...]) -> str:
    items = [f"'{column}': 'VARCHAR'" for column in columns]
    return "{" + ", ".join(items) + "}"


def _read_tsv_sql(path: Path, columns: tuple[str, ...]) -> str:
    return (
        "read_csv("
        f"{_sql_literal(path)}, "
        "delim='\\t', "
        "header=true, "
        f"columns={_varchar_columns_sql(columns)}, "
        "nullstr='\\N'"
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
    connection.execute(f"CREATE TABLE {table_name} AS SELECT * FROM {_read_tsv_sql(paths[0], columns)}")
    for path in paths[1:]:
        connection.execute(f"INSERT INTO {table_name} SELECT * FROM {_read_tsv_sql(path, columns)}")


def _tsv_header(path: Path) -> tuple[str, ...]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return tuple(handle.readline().rstrip("\r\n").split("\t"))


def _insert_features_sql(path: Path, schema_version: int) -> str:
    source = _read_tsv_sql(path, feature_columns_for_schema(schema_version))
    if schema_version in (5, 6):
        numeric_select = """
  CAST(stoch_structure_raw_percent AS DOUBLE) AS stoch_structure_raw_percent,
  CAST(b_percent_main_base AS DOUBLE) AS b_percent_main_base,
  CAST(b_percent_main_base_slope AS DOUBLE) AS b_percent_main_base_slope,
  CAST(b_percent_main_macro AS DOUBLE) AS b_percent_main_macro,
  CAST(b_percent_main_macro_slope AS DOUBLE) AS b_percent_main_macro_slope,
  session_id,
  CAST(time_sin AS DOUBLE) AS time_sin,
  CAST(time_cos AS DOUBLE) AS time_cos
"""
    else:
        numeric_select = """
  NULL::DOUBLE AS stoch_structure_raw_percent,
  NULL::DOUBLE AS b_percent_main_base,
  NULL::DOUBLE AS b_percent_main_base_slope,
  NULL::DOUBLE AS b_percent_main_macro,
  NULL::DOUBLE AS b_percent_main_macro_slope,
  NULL::VARCHAR AS session_id,
  NULL::DOUBLE AS time_sin,
  NULL::DOUBLE AS time_cos
"""
    return f"""
INSERT INTO features
SELECT
  CAST(schema_version AS INTEGER) AS schema_version,
  run_id,
  config_id,
  signal_id,
  source_key,
  CAST(source_attempt_index AS INTEGER) AS source_attempt_index,
  symbol,
  strategy_label,
  direction,
  strptime(entry_time, '{TIMESTAMP_FORMAT}') AS entry_time,
  strptime(source_time, '{TIMESTAMP_FORMAT}') AS source_time,
  structure_0,
  structure_1,
  structure_2,
  CAST(macro_h1_slope AS INTEGER) AS macro_h1_slope,
  CAST(macro_h4_slope AS INTEGER) AS macro_h4_slope,
  CAST(macro_d1_slope AS INTEGER) AS macro_d1_slope,
  fib_sl_band,
  fib_entry_band,
  high_chain_profile,
  low_chain_profile,
  previous_candle_profile,
  entry_session_bucket,
  entry_weekday,
{numeric_select}
FROM {source}
"""


def _insert_outcomes_sql(path: Path) -> str:
    header = _tsv_header(path)
    has_path_labels = header in (OUTCOME_COLUMNS_WITH_PATH, SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH)
    if header == SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH:
        source_columns = SCHEMA_V6_OUTCOME_COLUMNS_WITH_PATH
    else:
        source_columns = OUTCOME_COLUMNS_WITH_PATH if has_path_labels else OUTCOME_COLUMNS
    return f"""
INSERT INTO outcomes
SELECT
  CAST(schema_version AS INTEGER) AS schema_version,
  run_id,
  config_id,
  signal_id,
  source_key,
  CAST(source_attempt_index AS INTEGER) AS source_attempt_index,
  strptime(terminal_time, '{TIMESTAMP_FORMAT}') AS terminal_time,
  terminal_reason,
  CAST(profit_r AS DOUBLE) AS profit_r,
  CAST(duration_seconds AS INTEGER) AS duration_seconds,
  CAST(duration_m1_bars AS INTEGER) AS duration_m1_bars,
  CAST(entry_price AS DOUBLE) AS entry_price,
  CAST(close_price AS DOUBLE) AS close_price,
  CAST(net_profit AS DOUBLE) AS net_profit,
  {("CAST(hit_1r_before_sl AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS hit_1r_before_sl,
  {("CAST(hit_1_5r_before_sl AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS hit_1_5r_before_sl,
  {("CAST(hit_2r_before_sl AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS hit_2r_before_sl,
  {("CAST(hit_3r_before_sl AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS hit_3r_before_sl,
  {("CAST(max_favorable_r AS DOUBLE)" if has_path_labels else "NULL::DOUBLE")} AS max_favorable_r,
  {("CAST(max_adverse_r AS DOUBLE)" if has_path_labels else "NULL::DOUBLE")} AS max_adverse_r,
  {("CAST(bars_to_1r AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS bars_to_1r,
  {("CAST(bars_to_1_5r AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS bars_to_1_5r,
  {("CAST(bars_to_2r AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS bars_to_2r,
  {("CAST(bars_to_3r AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS bars_to_3r,
  {("CAST(bars_to_sl AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS bars_to_sl,
  {("CAST(path_horizon_bars AS INTEGER)" if has_path_labels else "NULL::INTEGER")} AS path_horizon_bars,
  {("path_status" if has_path_labels else "NULL::VARCHAR")} AS path_status
FROM {_read_tsv_sql(path, source_columns)}
"""


def _insert_admissions_sql(path: Path) -> str:
    return f"""
INSERT INTO admissions
SELECT
  CAST(schema_version AS INTEGER) AS schema_version,
  run_id,
  config_id,
  signal_id,
  strptime(event_time, '{TIMESTAMP_FORMAT}') AS event_time,
  event_type,
  admission_status,
  CAST(risk_target_amount AS DOUBLE) AS risk_target_amount,
  CAST(expected_sl_loss AS DOUBLE) AS expected_sl_loss,
  CAST(expected_tp_profit AS DOUBLE) AS expected_tp_profit,
  CAST(normalized_lot AS DOUBLE) AS normalized_lot
FROM {_read_tsv_sql(path, SCHEMA_V6_ADMISSION_COLUMNS)}
"""


def _path_target_sql(target_family: str, schema_version: int) -> tuple[str, str, str, str]:
    if target_family == BROKER_TARGET_FAMILY:
        if schema_version >= 6:
            realized_r = "o.net_profit / ABS(a.expected_sl_loss)"
            return (
                "CASE WHEN o.net_profit > 0 THEN 1 ELSE 0 END",
                realized_r,
                "CASE WHEN o.net_profit > 0 THEN 'BROKER_PROFIT' "
                "WHEN o.net_profit < 0 THEN 'BROKER_LOSS' ELSE 'BROKER_FLAT' END",
                "o.net_profit IS NOT NULL AND a.expected_sl_loss IS NOT NULL AND ABS(a.expected_sl_loss) > 0.0",
            )
        return (
            "CASE WHEN o.profit_r > 0 THEN 1 ELSE 0 END",
            "o.profit_r",
            "o.terminal_reason",
            "TRUE",
        )

    valid_path = "o.path_status IN ('SL_FIRST', 'TARGET_3R', 'HORIZON_EXPIRED')"
    if target_family in ("1r", "1_5r", "2r", "3r"):
        ratio_by_family = {
            "1r": ("hit_1r_before_sl", 1.0),
            "1_5r": ("hit_1_5r_before_sl", 1.5),
            "2r": ("hit_2r_before_sl", 2.0),
            "3r": ("hit_3r_before_sl", 3.0),
        }
        hit_column, target_r = ratio_by_family[target_family]
        return (
            f"CAST(o.{hit_column} AS INTEGER)",
            f"CASE WHEN o.{hit_column} = 1 THEN {target_r:.1f} WHEN o.path_status = 'SL_FIRST' THEN -1.0 ELSE 0.0 END",
            f"'PATH_{target_family}_' || o.path_status",
            f"{valid_path} AND o.{hit_column} IS NOT NULL",
        )

    if target_family == "expected_r":
        target_profit = (
            "CASE "
            "WHEN o.path_status = 'TARGET_3R' THEN 3.0 "
            "WHEN o.path_status = 'SL_FIRST' THEN -1.0 "
            "WHEN o.path_status = 'HORIZON_EXPIRED' THEN COALESCE(o.max_favorable_r, 0.0) "
            "ELSE NULL END"
        )
        return (
            f"CASE WHEN {target_profit} > 0 THEN 1 ELSE 0 END",
            target_profit,
            "'PATH_EXPECTED_R_' || o.path_status",
            f"{valid_path} AND ({target_profit}) IS NOT NULL",
        )

    raise RuntimeError(f"Unsupported target_family: {target_family}")


def _create_v7_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations,
    target_family: str,
    feature_columns: tuple[str, ...],
) -> dict[str, int]:
    if target_family not in (BROKER_TARGET_FAMILY, ENGINE_SIMULATED_TARGET_FAMILY):
        raise RuntimeError(
            "Schema v7 assembly requires target_family=broker_1r or engine_simulated_1r"
        )

    run_paths = [validation.run_path for validation in validations]
    _load_raw_table(connection, "raw_engine_cycles", [path / ENGINE_CYCLES_FILE for path in run_paths], SCHEMA_V7_CYCLE_COLUMNS)
    _load_raw_table(connection, "raw_engine_revisions", [path / ENGINE_REVISIONS_FILE for path in run_paths], SCHEMA_V7_REVISION_COLUMNS)
    _load_raw_table(connection, "raw_engine_attempts", [path / ENGINE_ATTEMPTS_FILE for path in run_paths], SCHEMA_V7_ATTEMPT_COLUMNS)
    _load_raw_table(connection, "raw_features", [path / SIGNAL_FEATURES_FILE for path in run_paths], SCHEMA_V7_FEATURE_COLUMNS)
    _load_raw_table(connection, "raw_admissions", [path / SIGNAL_ADMISSIONS_FILE for path in run_paths], SCHEMA_V7_ADMISSION_COLUMNS)
    _load_raw_table(connection, "raw_outcomes", [path / SIGNAL_OUTCOMES_FILE for path in run_paths], SCHEMA_V7_OUTCOME_COLUMNS_WITH_PATH)
    _load_raw_table(connection, "raw_leg_outcomes", [path / SIGNAL_LEG_OUTCOMES_FILE for path in run_paths], SCHEMA_V7_LEG_OUTCOME_COLUMNS)

    connection.execute(
        """
CREATE TABLE engine_cycles AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, symbol,
  CAST(engine_id AS INTEGER) AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_type,
  strptime(cycle_first_seen_time, '%Y.%m.%d %H:%M:%S') AS cycle_first_seen_time,
  strptime(cycle_finalized_time, '%Y.%m.%d %H:%M:%S') AS cycle_finalized_time,
  cycle_status, reference_peak_time, CAST(reference_peak_price AS DOUBLE) AS reference_peak_price,
  reference_bottom_time, CAST(reference_bottom_price AS DOUBLE) AS reference_bottom_price,
  CAST(reference_range_points AS DOUBLE) AS reference_range_points,
  first_extremum_time, CAST(first_extremum_price AS DOUBLE) AS first_extremum_price,
  final_extremum_time, CAST(final_extremum_price AS DOUBLE) AS final_extremum_price,
  CAST(final_depth_percent AS DOUBLE) AS final_depth_percent,
  CAST(revision_count AS INTEGER) AS revision_count,
  CAST(attempt_count AS INTEGER) AS attempt_count
FROM raw_engine_cycles
"""
    )
    connection.execute(
        """
CREATE TABLE engine_revisions AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, symbol,
  CAST(engine_id AS INTEGER) AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, revision_id, CAST(revision_index AS INTEGER) AS revision_index,
  strptime(snapshot_time, '%Y.%m.%d %H:%M:%S') AS snapshot_time,
  extremum_time, CAST(extremum_price AS DOUBLE) AS extremum_price, extremum_type,
  CAST(depth_percent_raw AS DOUBLE) AS depth_percent_raw,
  CAST(distance_from_first_revision_points AS DOUBLE) AS distance_from_first_revision_points,
  CAST(distance_from_previous_revision_points AS DOUBLE) AS distance_from_previous_revision_points,
  CAST(depth_delta_from_previous_percent AS DOUBLE) AS depth_delta_from_previous_percent,
  CAST(bars_since_cycle_start AS INTEGER) AS bars_since_cycle_start,
  reference_peak_time, CAST(reference_peak_price AS DOUBLE) AS reference_peak_price,
  reference_bottom_time, CAST(reference_bottom_price AS DOUBLE) AS reference_bottom_price,
  CAST(reference_range_points AS DOUBLE) AS reference_range_points,
  structure_0, structure_1, structure_2, session_id,
  CAST(time_sin AS DOUBLE) AS time_sin, CAST(time_cos AS DOUBLE) AS time_cos
FROM raw_engine_revisions
"""
    )
    connection.execute(
        """
CREATE TABLE engine_attempts AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, symbol,
  CAST(engine_id AS INTEGER) AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, revision_id, attempt_id,
  CAST(cycle_attempt_index AS INTEGER) AS cycle_attempt_index,
  CAST(revision_attempt_index AS INTEGER) AS revision_attempt_index,
  strptime(attempt_created_time, '%Y.%m.%d %H:%M:%S') AS attempt_created_time,
  direction, CAST(candidate_depth_percent AS DOUBLE) AS candidate_depth_percent,
  CAST(reference_range_points AS DOUBLE) AS reference_range_points,
  CAST(distance_from_first_revision_points AS DOUBLE) AS distance_from_first_revision_points,
  CAST(distance_from_previous_revision_points AS DOUBLE) AS distance_from_previous_revision_points,
  CAST(depth_delta_from_previous_percent AS DOUBLE) AS depth_delta_from_previous_percent,
  CAST(bars_since_cycle_start AS INTEGER) AS bars_since_cycle_start,
  CAST(trigger_price AS DOUBLE) AS trigger_price,
  CAST(stop_anchor_price AS DOUBLE) AS stop_anchor_price,
  CAST(take_profit_price AS DOUBLE) AS take_profit_price,
  CAST(trigger_reached AS INTEGER) AS trigger_reached, trigger_time, attempt_status,
  operational_block_source, operational_block_reason, simulated_terminal_reason,
  CAST(simulated_profit_r AS DOUBLE) AS simulated_profit_r,
  CAST(simulated_max_favorable_r AS DOUBLE) AS simulated_max_favorable_r,
  CAST(simulated_max_adverse_r AS DOUBLE) AS simulated_max_adverse_r,
  simulated_path_status, simulated_outcome_source, broker_signal_id,
  CAST(broker_entry_confirmed AS INTEGER) AS broker_entry_confirmed,
  CAST(broker_close_confirmed AS INTEGER) AS broker_close_confirmed
FROM raw_engine_attempts
"""
    )
    connection.execute(
        """
CREATE TABLE features AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, signal_id,
  source_key, CAST(source_attempt_index AS INTEGER) AS source_attempt_index,
  CAST(engine_id AS INTEGER) AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id, symbol, direction,
  strptime(entry_time, '%Y.%m.%d %H:%M:%S') AS entry_time,
  strptime(source_time, '%Y.%m.%d %H:%M:%S') AS source_time,
  structure_0, structure_1, structure_2, fib_sl_band, fib_entry_band,
  high_chain_profile, low_chain_profile, previous_candle_profile,
  entry_session_bucket, entry_weekday,
  CAST(stoch_structure_raw_percent AS DOUBLE) AS stoch_structure_raw_percent,
  CAST(b_percent_main_base AS DOUBLE) AS b_percent_main_base,
  CAST(b_percent_main_base_slope AS DOUBLE) AS b_percent_main_base_slope,
  CAST(b_percent_main_macro AS DOUBLE) AS b_percent_main_macro,
  CAST(b_percent_main_macro_slope AS DOUBLE) AS b_percent_main_macro_slope,
  session_id, CAST(time_sin AS DOUBLE) AS time_sin, CAST(time_cos AS DOUBLE) AS time_cos
FROM raw_features
"""
    )
    connection.execute(
        """
CREATE TABLE admissions AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, signal_id,
  extremum_attempt_id,
  strptime(event_time, '%Y.%m.%d %H:%M:%S') AS event_time,
  event_type, admission_status, admission_source, admission_reason,
  CAST(risk_target_amount AS DOUBLE) AS risk_target_amount,
  CAST(expected_sl_loss AS DOUBLE) AS expected_sl_loss,
  CAST(expected_tp_profit AS DOUBLE) AS expected_tp_profit,
  CAST(normalized_lot AS DOUBLE) AS normalized_lot
FROM raw_admissions
"""
    )
    connection.execute(
        """
CREATE TABLE outcomes AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, signal_id,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id,
  strptime(terminal_time, '%Y.%m.%d %H:%M:%S') AS terminal_time,
  terminal_reason, CAST(profit_r AS DOUBLE) AS profit_r,
  CAST(duration_seconds AS INTEGER) AS duration_seconds,
  CAST(duration_m1_bars AS INTEGER) AS duration_m1_bars,
  CAST(entry_price AS DOUBLE) AS entry_price, CAST(close_price AS DOUBLE) AS close_price,
  CAST(net_profit AS DOUBLE) AS net_profit,
  CAST(broker_entry_confirmed AS INTEGER) AS broker_entry_confirmed,
  CAST(broker_close_confirmed AS INTEGER) AS broker_close_confirmed,
  path_status
FROM raw_outcomes
"""
    )
    connection.execute(
        """
CREATE TABLE signal_leg_outcomes AS SELECT
  CAST(schema_version AS INTEGER) AS schema_version, run_id, config_id, signal_id,
  source_key, CAST(source_attempt_index AS INTEGER) AS source_attempt_index,
  CAST(engine_id AS INTEGER) AS engine_id, engine_label, engine_timeframe,
  extremum_cycle_id, extremum_revision_id, extremum_attempt_id,
  CAST(leg_index AS INTEGER) AS leg_index, CAST(target_r AS DOUBLE) AS target_r,
  entry_time, close_time, CAST(entry_price AS DOUBLE) AS entry_price,
  CAST(close_price AS DOUBLE) AS close_price, CAST(stop_price AS DOUBLE) AS stop_price,
  CAST(take_profit_price AS DOUBLE) AS take_profit_price,
  CAST(initial_lot AS DOUBLE) AS initial_lot, CAST(closed_volume AS DOUBLE) AS closed_volume,
  CAST(net_profit AS DOUBLE) AS net_profit, CAST(expected_sl_loss AS DOUBLE) AS expected_sl_loss,
  CAST(profit_r AS DOUBLE) AS profit_r, terminal_reason,
  CAST(broker_close_confirmed AS INTEGER) AS broker_close_confirmed,
  close_source, position_ticket, position_comment
FROM raw_leg_outcomes
"""
    )
    connection.execute(
        """
CREATE TABLE admission_risk AS SELECT
  signal_id,
  MAX(expected_sl_loss) AS expected_sl_loss,
  MAX(risk_target_amount) AS risk_target_amount,
  MAX(expected_tp_profit) AS expected_tp_profit,
  MAX(normalized_lot) AS normalized_lot
FROM admissions GROUP BY signal_id
"""
    )
    revision_features = {"structure_0", "structure_1", "structure_2", "session_id", "time_sin", "time_cos"}
    required_feature_clause = " AND ".join(
        f"{'r' if column in revision_features else 'a'}.{column} IS NOT NULL"
        for column in feature_columns
    )
    if target_family == BROKER_TARGET_FAMILY:
        training_sql = f"""
CREATE TABLE training_matrix AS SELECT
  a.schema_version, a.run_id, a.config_id, a.symbol, a.engine_id, a.engine_label,
  a.engine_timeframe, a.extremum_cycle_id, a.revision_id AS extremum_revision_id,
  a.attempt_id AS extremum_attempt_id, a.broker_signal_id AS signal_id,
  a.attempt_created_time AS entry_time, a.direction, a.cycle_attempt_index,
  a.revision_attempt_index, a.candidate_depth_percent, a.reference_range_points,
  a.distance_from_first_revision_points, a.distance_from_previous_revision_points,
  a.depth_delta_from_previous_percent, a.bars_since_cycle_start,
  r.structure_0, r.structure_1, r.structure_2, r.session_id, r.time_sin, r.time_cos,
  o.terminal_time, o.terminal_reason, o.net_profit,
  o.net_profit / ABS(ar.expected_sl_loss) AS target_profit_r,
  CASE WHEN o.net_profit > 0 THEN 1 ELSE 0 END AS target_is_win,
  CASE WHEN o.net_profit > 0 THEN 'BROKER_PROFIT'
       WHEN o.net_profit < 0 THEN 'BROKER_LOSS' ELSE 'BROKER_FLAT' END AS target_terminal_reason,
  'BROKER_CONFIRMED' AS target_source,
  a.simulated_profit_r, a.simulated_path_status
FROM engine_attempts a
JOIN engine_revisions r ON r.revision_id = a.revision_id
JOIN outcomes o ON o.extremum_attempt_id = a.attempt_id
JOIN admission_risk ar ON ar.signal_id = a.broker_signal_id
WHERE a.broker_entry_confirmed = 1 AND a.broker_close_confirmed = 1
  AND o.broker_entry_confirmed = 1 AND o.broker_close_confirmed = 1
  AND ar.expected_sl_loss IS NOT NULL AND ABS(ar.expected_sl_loss) > 0
  AND {required_feature_clause}
ORDER BY a.attempt_created_time, a.attempt_id
"""
    else:
        training_sql = f"""
CREATE TABLE training_matrix AS SELECT
  a.schema_version, a.run_id, a.config_id, a.symbol, a.engine_id, a.engine_label,
  a.engine_timeframe, a.extremum_cycle_id, a.revision_id AS extremum_revision_id,
  a.attempt_id AS extremum_attempt_id, a.broker_signal_id AS signal_id,
  a.attempt_created_time AS entry_time, a.direction, a.cycle_attempt_index,
  a.revision_attempt_index, a.candidate_depth_percent, a.reference_range_points,
  a.distance_from_first_revision_points, a.distance_from_previous_revision_points,
  a.depth_delta_from_previous_percent, a.bars_since_cycle_start,
  r.structure_0, r.structure_1, r.structure_2, r.session_id, r.time_sin, r.time_cos,
  NULL::TIMESTAMP AS terminal_time, a.simulated_terminal_reason AS terminal_reason,
  NULL::DOUBLE AS net_profit, a.simulated_profit_r AS target_profit_r,
  CASE WHEN a.simulated_profit_r > 0 THEN 1 ELSE 0 END AS target_is_win,
  'ENGINE_' || a.simulated_terminal_reason AS target_terminal_reason,
  'ENGINE_SIMULATION' AS target_source,
  a.simulated_profit_r, a.simulated_path_status
FROM engine_attempts a
JOIN engine_revisions r ON r.revision_id = a.revision_id
WHERE a.trigger_reached = 1
  AND a.simulated_path_status IN ('SL_FIRST', 'TARGET', 'HORIZON_EXPIRED')
  AND a.simulated_profit_r IS NOT NULL
  AND {required_feature_clause}
ORDER BY a.attempt_created_time, a.attempt_id
"""
    connection.execute(training_sql)
    tables = (
        "engine_cycles", "engine_revisions", "engine_attempts", "features",
        "admissions", "outcomes", "signal_leg_outcomes", "admission_risk",
        "training_matrix",
    )
    return {table: int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]) for table in tables}


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations,
    target_family: str,
    schema_version: int,
    feature_columns: tuple[str, ...],
) -> dict[str, int]:
    if schema_version == 7:
        return _create_v7_dataset_tables(
            connection,
            validations,
            target_family,
            feature_columns,
        )

    target_is_win_sql, target_profit_r_sql, target_reason_sql, target_valid_clause = _path_target_sql(
        target_family,
        schema_version,
    )
    required_feature_clause = " AND\n  ".join(
        f"f.{column} IS NOT NULL" for column in feature_columns
    )
    connection.execute(
        """
CREATE TABLE features (
  schema_version INTEGER,
  run_id VARCHAR,
  config_id VARCHAR,
  signal_id VARCHAR,
  source_key VARCHAR,
  source_attempt_index INTEGER,
  symbol VARCHAR,
  strategy_label VARCHAR,
  direction VARCHAR,
  entry_time TIMESTAMP,
  source_time TIMESTAMP,
  structure_0 VARCHAR,
  structure_1 VARCHAR,
  structure_2 VARCHAR,
  macro_h1_slope INTEGER,
  macro_h4_slope INTEGER,
  macro_d1_slope INTEGER,
  fib_sl_band VARCHAR,
  fib_entry_band VARCHAR,
  high_chain_profile VARCHAR,
  low_chain_profile VARCHAR,
  previous_candle_profile VARCHAR,
  entry_session_bucket VARCHAR,
  entry_weekday VARCHAR,
  stoch_structure_raw_percent DOUBLE,
  b_percent_main_base DOUBLE,
  b_percent_main_base_slope DOUBLE,
  b_percent_main_macro DOUBLE,
  b_percent_main_macro_slope DOUBLE,
  session_id VARCHAR,
  time_sin DOUBLE,
  time_cos DOUBLE
)
"""
    )
    connection.execute(
        """
CREATE TABLE admissions (
  schema_version INTEGER,
  run_id VARCHAR,
  config_id VARCHAR,
  signal_id VARCHAR,
  event_time TIMESTAMP,
  event_type VARCHAR,
  admission_status VARCHAR,
  risk_target_amount DOUBLE,
  expected_sl_loss DOUBLE,
  expected_tp_profit DOUBLE,
  normalized_lot DOUBLE
)
"""
    )
    connection.execute(
        """
CREATE TABLE outcomes (
  schema_version INTEGER,
  run_id VARCHAR,
  config_id VARCHAR,
  signal_id VARCHAR,
  source_key VARCHAR,
  source_attempt_index INTEGER,
  terminal_time TIMESTAMP,
  terminal_reason VARCHAR,
  profit_r DOUBLE,
  duration_seconds INTEGER,
  duration_m1_bars INTEGER,
  entry_price DOUBLE,
  close_price DOUBLE,
  net_profit DOUBLE,
  hit_1r_before_sl INTEGER,
  hit_1_5r_before_sl INTEGER,
  hit_2r_before_sl INTEGER,
  hit_3r_before_sl INTEGER,
  max_favorable_r DOUBLE,
  max_adverse_r DOUBLE,
  bars_to_1r INTEGER,
  bars_to_1_5r INTEGER,
  bars_to_2r INTEGER,
  bars_to_3r INTEGER,
  bars_to_sl INTEGER,
  path_horizon_bars INTEGER,
  path_status VARCHAR
)
"""
    )

    for validation in validations:
        connection.execute(_insert_features_sql(validation.run_path / SIGNAL_FEATURES_FILE, schema_version))
        if schema_version >= 6:
            connection.execute(_insert_admissions_sql(validation.run_path / SIGNAL_ADMISSIONS_FILE))
        connection.execute(_insert_outcomes_sql(validation.run_path / SIGNAL_OUTCOMES_FILE))

    connection.execute(
        """
CREATE TABLE admission_risk AS
SELECT
  signal_id,
  COALESCE(
    MAX(CASE WHEN event_type = 'broker_entry' THEN risk_target_amount ELSE NULL END),
    MAX(risk_target_amount)
  ) AS risk_target_amount,
  COALESCE(
    MAX(CASE WHEN event_type = 'broker_entry' THEN expected_sl_loss ELSE NULL END),
    MAX(expected_sl_loss)
  ) AS expected_sl_loss,
  COALESCE(
    MAX(CASE WHEN event_type = 'broker_entry' THEN expected_tp_profit ELSE NULL END),
    MAX(expected_tp_profit)
  ) AS expected_tp_profit,
  COALESCE(
    MAX(CASE WHEN event_type = 'broker_entry' THEN normalized_lot ELSE NULL END),
    MAX(normalized_lot)
  ) AS normalized_lot
FROM admissions
GROUP BY signal_id
"""
    )

    connection.execute(
        f"""
CREATE TABLE training_matrix AS
SELECT
  f.schema_version,
  f.run_id,
  f.config_id,
  f.signal_id,
  f.source_key,
  f.source_attempt_index,
  f.symbol,
  f.strategy_label,
  f.direction,
  f.entry_time,
  f.source_time,
  f.structure_0,
  f.structure_1,
  f.structure_2,
  f.macro_h1_slope,
  f.macro_h4_slope,
  f.macro_d1_slope,
  f.fib_sl_band,
  f.fib_entry_band,
  f.high_chain_profile,
  f.low_chain_profile,
  f.previous_candle_profile,
  f.entry_session_bucket,
  f.entry_weekday,
  f.stoch_structure_raw_percent,
  f.b_percent_main_base,
  f.b_percent_main_base_slope,
  f.b_percent_main_macro,
  f.b_percent_main_macro_slope,
  f.session_id,
  f.time_sin,
  f.time_cos,
  o.terminal_time,
  o.terminal_reason,
  o.profit_r,
  o.duration_seconds,
  o.duration_m1_bars,
  o.entry_price,
  o.close_price,
  o.net_profit,
  o.hit_1r_before_sl,
  o.hit_1_5r_before_sl,
  o.hit_2r_before_sl,
  o.hit_3r_before_sl,
  o.max_favorable_r,
  o.max_adverse_r,
  o.bars_to_1r,
  o.bars_to_1_5r,
  o.bars_to_2r,
  o.bars_to_3r,
  o.bars_to_sl,
  o.path_horizon_bars,
  o.path_status,
  {target_is_win_sql} AS target_is_win,
  {target_profit_r_sql} AS target_profit_r,
  {target_reason_sql} AS target_terminal_reason
FROM features f
INNER JOIN outcomes o ON o.signal_id = f.signal_id
LEFT JOIN admission_risk a ON a.signal_id = f.signal_id
WHERE
  {required_feature_clause}
  AND {target_valid_clause}
ORDER BY f.entry_time, f.signal_id
"""
    )

    feature_count = connection.execute("SELECT COUNT(*) FROM features").fetchone()[0]
    admission_risk_count = connection.execute("SELECT COUNT(*) FROM admission_risk").fetchone()[0]
    outcome_count = connection.execute("SELECT COUNT(*) FROM outcomes").fetchone()[0]
    matrix_count = connection.execute("SELECT COUNT(*) FROM training_matrix").fetchone()[0]
    return {
        "features": int(feature_count),
        "admission_risk": int(admission_risk_count),
        "outcomes": int(outcome_count),
        "training_matrix": int(matrix_count),
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
    output_files = {
        table_name: str(output_dir / f"{table_name}.parquet")
        for table_name in counts
    }
    for table_name, output_file in output_files.items():
        connection.execute(
            f"COPY {table_name} TO {_sql_literal(output_file)} (FORMAT parquet)"
        )
        read_back_count = connection.execute(
            f"SELECT COUNT(*) FROM read_parquet({_sql_literal(output_file)})"
        ).fetchone()[0]
        table_count = connection.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
        if read_back_count != table_count:
            raise RuntimeError(
                f"Parquet readback mismatch for {table_name}: wrote={table_count}, read={read_back_count}"
            )
    return output_files


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs-root", required=True, help="Folder containing Phase 1 run folders.")
    parser.add_argument("--run-id", action="append", required=True, help="Run ID to include. Repeat for multiple runs.")
    parser.add_argument("--dataset-id", required=True, help="Dataset output ID.")
    parser.add_argument("--output-root", default="artifacts/datasets", help="Dataset output root.")
    parser.add_argument(
        "--schema-version",
        type=int,
        default=SUPPORTED_SCHEMA_VERSION,
        choices=SUPPORTED_SCHEMA_VERSIONS,
        help="Phase 1 feature export schema version. Defaults to active schema v6.",
    )
    parser.add_argument(
        "--feature-set-id",
        choices=tuple(FEATURE_SET_COLUMNS),
        default="",
        help="Model feature set stored in the dataset manifest. Defaults from --schema-version.",
    )
    parser.add_argument(
        "--target-family",
        default=BROKER_TARGET_FAMILY,
        choices=DATASET_TARGET_FAMILIES,
        help="Target family to derive from broker outcomes or path-ratio labels.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing dataset folder.")
    parser.add_argument("--validate-only", action="store_true", help="Validate inputs without writing Parquet files.")
    parser.add_argument(
        "--allow-mixed-config",
        action="store_true",
        help="Allow multiple config_id values across selected runs.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    feature_set_id = args.feature_set_id or default_feature_set_for_schema(args.schema_version)
    expected_feature_schema = schema_version_for_feature_set(feature_set_id)
    if expected_feature_schema != args.schema_version:
        parser.exit(
            1,
            "validation failed: feature_set_id "
            f"{feature_set_id!r} requires schema version {expected_feature_schema}, "
            f"got {args.schema_version}\n",
        )
    feature_columns = feature_columns_for_set(feature_set_id)

    try:
        validations = validate_phase1_runs(
            Path(args.runs_root),
            args.run_id,
            schema_version=args.schema_version,
            allow_mixed_config=args.allow_mixed_config,
        )
    except Phase1ValidationError as exc:
        parser.exit(1, f"validation failed: {exc}\n")

    total_features = sum(validation.feature_rows for validation in validations)
    total_outcomes = sum(validation.outcome_rows for validation in validations)
    total_joined = sum(validation.joined_rows for validation in validations)
    print(
        "validation ok | "
        f"runs={len(validations)} | "
        f"features={total_features} | "
        f"outcomes={total_outcomes} | "
        f"joined={total_joined}"
    )
    for validation in validations:
        for warning in validation.warnings:
            print(f"warning [{validation.run_id}]: {warning}")

    if args.validate_only:
        return 0

    connection = duckdb.connect(":memory:")
    counts = create_dataset_tables(
        connection,
        validations,
        args.target_family,
        args.schema_version,
        feature_columns,
    )
    if counts["training_matrix"] <= 0:
        parser.exit(1, f"build failed: no valid rows for target_family={args.target_family}\n")
    print(
        "assembly ok | "
        f"features={counts.get('features', 0)} | "
        f"cycles={counts.get('engine_cycles', 0)} | "
        f"attempts={counts.get('engine_attempts', 0)} | "
        f"outcomes={counts['outcomes']} | "
        f"training_matrix={counts['training_matrix']}"
    )
    try:
        output_dir = prepare_output_dir(Path(args.output_root), args.dataset_id, args.overwrite)
        output_files = write_parquet_outputs(connection, output_dir, counts)
        quality_payload = build_quality_payload(
            connection,
            validations,
            counts,
            args.target_family,
            feature_columns,
        )
        write_dataset_manifest(
            output_dir,
            args.dataset_id,
            validations,
            counts,
            output_files,
            args.target_family,
            args.schema_version,
            feature_set_id,
            feature_columns,
        )
        write_quality_json(output_dir, quality_payload)
        write_dataset_report(output_dir, args.dataset_id, quality_payload)
    except RuntimeError as exc:
        parser.exit(1, f"build failed: {exc}\n")

    print(f"dataset written | path={output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
