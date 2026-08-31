"""Build typed, grain-aware research artifacts from strict Pivot Fractal V13 runs."""

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
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_GROUPS,
    DEEP_MICRO_FEATURE_COLUMNS,
    DEEP_MODEL_FEATURE_COLUMNS,
    H1_ENTRY_POLICIES,
    H1_MODEL_FEATURE_COLUMNS,
    H1_TP_R_MULTIPLES,
    MODEL_FEATURE_COLUMNS,
    NULL_TOKEN,
    ORIGIN_SIGNAL_FEATURE_COLUMNS,
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
H1_LANE_LONG_TABLE = "h1_lane_long"
H1_LANE_WIDE_TABLE = "h1_lane_wide"
ELIGIBLE_H1_TRIALS_TABLE = "eligible_h1_trials"
DEEP_PARENT_LONG_TABLE = "deep_parent_long"
ELIGIBLE_DEEP_TRIALS_TABLE = "eligible_deep_trials"
BROKER_VIRTUAL_CALIBRATION_TABLE = "broker_virtual_calibration"

DERIVED_TABLES = (
    H1_LANE_LONG_TABLE,
    H1_LANE_WIDE_TABLE,
    ELIGIBLE_H1_TRIALS_TABLE,
    DEEP_PARENT_LONG_TABLE,
    ELIGIBLE_DEEP_TRIALS_TABLE,
    BROKER_VIRTUAL_CALIBRATION_TABLE,
)


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
        raise RuntimeError(f"V13 column lacks an explicit dataset type: {column}") from exc
    if column_type == "TIMESTAMP":
        return f"strptime({nullified}, '%Y.%m.%d %H:%M:%S') AS {quoted}"
    if column_type == "BOOLEAN":
        return f"CAST(CAST({nullified} AS TINYINT) AS BOOLEAN) AS {quoted}"
    if column_type == "BIGINT":
        return f"CAST({nullified} AS BIGINT) AS {quoted}"
    if column_type == "DOUBLE":
        return f"CAST({nullified} AS DOUBLE) AS {quoted}"
    if column_type == "VARCHAR":
        return f"{nullified} AS {quoted}"
    raise RuntimeError(f"Unsupported V13 dataset type for {column}: {column_type}")


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
  nullstr='__PIVOT_V13_NO_AUTOMATIC_NULL__'
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


def create_raw_tables(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
) -> dict[str, int]:
    if not validations:
        raise RuntimeError("At least one validated V13 run is required")
    counts: dict[str, int] = {}
    for filename in RUN_FILES:
        table_name = Path(filename).stem
        _load_typed_table(
            connection,
            table_name,
            [validation.run_path / filename for validation in validations],
            TABLE_COLUMNS[filename],
        )
        counts[table_name] = int(
            connection.execute(f"SELECT count(*) FROM {table_name}").fetchone()[0]
        )
    return counts


def _calendar_columns(timestamp: str) -> str:
    return f"""
  strftime({timestamp}, '%w') AS analysis_weekday,
  CASE
    WHEN EXTRACT(hour FROM {timestamp}) < 6 THEN 'SESSION_00_05'
    WHEN EXTRACT(hour FROM {timestamp}) < 12 THEN 'SESSION_06_11'
    WHEN EXTRACT(hour FROM {timestamp}) < 18 THEN 'SESSION_12_17'
    ELSE 'SESSION_18_23'
  END AS analysis_session,
  sin(
    2.0 * pi() *
    (EXTRACT(hour FROM {timestamp}) * 60.0 +
     EXTRACT(minute FROM {timestamp})) / 1440.0
  ) AS time_sin,
  cos(
    2.0 * pi() *
    (EXTRACT(hour FROM {timestamp}) * 60.0 +
     EXTRACT(minute FROM {timestamp})) / 1440.0
  ) AS time_cos"""


def _create_h1_lane_long(connection: duckdb.DuckDBPyConnection) -> None:
    origin_features = ",\n  ".join(f"so.{column}" for column in ORIGIN_SIGNAL_FEATURE_COLUMNS)
    connection.execute(
        f"""
CREATE TABLE {H1_LANE_LONG_TABLE} AS
SELECT
  vt.*,
  so.symbol,
  so.macro_timeframe,
  so.deep_timeframe,
  so.micro_timeframe,
  so.active_bar_open_broker_time,
  so.trigger_broker_time,
  so.trigger_analysis_time,
  so.trigger_bid,
  so.trigger_ask,
  so.pivot_raw_price,
  so.pivot_trade_price,
  so.next_outward_pivot_price,
  so.structural_entry_price,
  so.structural_sl_price,
  so.structural_take_profit,
  so.origin_micro_features_complete,
  so.origin_macro_features_complete,
  so.origin_feature_snapshot_complete,
  so.origin_feature_invalid_reason,
  {origin_features},
  pw.source_open,
  pw.source_high,
  pw.source_low,
  pw.source_close,
  pw.source_range,
  concat(
    so.symbol,
    '|',
    so.macro_timeframe,
    '|',
    strftime(so.active_bar_open_broker_time, '%Y.%m.%d %H:%M:%S')
  ) AS research_group_id,
{_calendar_columns('so.trigger_analysis_time')},
  abs(vt.entry_price - so.pivot_trade_price)
    / NULLIF(vt.normalized_risk_distance_price, 0.0) AS trigger_gap_to_risk,
  vt.spread_points
    / NULLIF(vt.normalized_risk_distance_points, 0.0) AS spread_to_risk,
  vo.outcome_id,
  vo.terminal_broker_time,
  vo.terminal_analysis_time,
  vo.terminal_status,
  vo.terminal_reason,
  vo.threshold_price,
  vo.observed_exit_bid,
  vo.observed_exit_ask,
  vo.observed_exit_price,
  vo.gap_points,
  vo.h1_structural_lifecycle_seconds,
  vo.virtual_nominal_r,
  vo.virtual_quote_gross_profit,
  vo.virtual_quote_gross_r,
  vo.virtual_binary_eligible,
  vo.virtual_binary_target,
  vo.virtual_exclusion_reason,
  vo.first_touch_consistent
FROM virtual_trials vt
JOIN signal_origins so
  ON so.run_id = vt.run_id
 AND so.config_id = vt.config_id
 AND so.origin_id = vt.origin_id
JOIN pivot_windows pw
  ON pw.run_id = vt.run_id
 AND pw.config_id = vt.config_id
 AND pw.window_id = vt.window_id
JOIN virtual_outcomes vo
  ON vo.run_id = vt.run_id
 AND vo.config_id = vt.config_id
 AND vo.trial_id = vt.trial_id
WHERE vt.trial_role = 'H1'
ORDER BY vt.declared_broker_time, vt.run_id, vt.origin_id,
         vt.entry_policy, vt.tp_r_multiple
"""
    )


def _create_h1_lane_wide(connection: duckdb.DuckDBPyConnection) -> None:
    cells: list[str] = []
    for entry_policy in H1_ENTRY_POLICIES:
        slug = entry_policy.lower()
        for ratio in H1_TP_R_MULTIPLES:
            prefix = f"{slug}_tp{ratio}"
            predicate = f"entry_policy = '{entry_policy}' AND tp_r_multiple = {ratio}"
            for column in (
                "trial_id",
                "eligibility_status",
                "ineligible_reason",
                "entry_broker_time",
                "terminal_status",
                "h1_structural_lifecycle_seconds",
                "virtual_binary_target",
                "virtual_nominal_r",
                "virtual_quote_gross_r",
            ):
                cells.append(
                    f"max(CASE WHEN {predicate} THEN {column} END) "
                    f"AS {prefix}_{column}"
                )
    cell_select = ",\n  ".join(cells)
    feature_select = ",\n  ".join(ORIGIN_SIGNAL_FEATURE_COLUMNS)
    connection.execute(
        f"""
CREATE TABLE {H1_LANE_WIDE_TABLE} AS
SELECT
  run_id,
  config_id,
  origin_id,
  window_id,
  symbol,
  macro_timeframe,
  deep_timeframe,
  micro_timeframe,
  active_bar_open_broker_time,
  level_id,
  direction,
  trigger_broker_time,
  trigger_analysis_time,
  trigger_bid,
  trigger_ask,
  pivot_trade_price,
  origin_micro_features_complete,
  origin_macro_features_complete,
  origin_feature_snapshot_complete,
  {feature_select},
  analysis_weekday,
  analysis_session,
  time_sin,
  time_cos,
  research_group_id,
  {cell_select}
FROM {H1_LANE_LONG_TABLE}
GROUP BY ALL
ORDER BY trigger_broker_time, run_id, origin_id
"""
    )


def _create_eligible_h1_trials(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {ELIGIBLE_H1_TRIALS_TABLE} AS
SELECT
  *,
  1.0 / count(*) OVER (PARTITION BY origin_id)
    AS origin_sample_weight,
  1.0 / (tp_r_multiple + 1.0) AS break_even_tp_rate
FROM {H1_LANE_LONG_TABLE}
WHERE eligibility_status = 'ACTIVE'
  AND origin_feature_snapshot_complete
  AND virtual_binary_eligible
  AND virtual_binary_target IN (0, 1)
  AND terminal_status IN ('TP_FIRST', 'SL_FIRST')
ORDER BY declared_broker_time, run_id, origin_id, entry_policy, tp_r_multiple
"""
    )


def _create_deep_parent_long(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {DEEP_PARENT_LONG_TABLE} AS
SELECT
  dpl.schema_version,
  dpl.run_id,
  dpl.config_id,
  dpl.parent_link_id,
  dpl.deep_event_id,
  dpl.origin_id,
  dpl.parent_kind,
  dpl.parent_trial_id,
  dpl.parent_broker_signal_id,
  dpl.parent_entry_policy,
  dpl.parent_tp_r_multiple,
  dpl.parent_entry_broker_time,
  dpl.event_trigger_broker_time,
  dpl.m10_parent_age_seconds,
  dpl.link_status,
  dt.deep_trial_id,
  dt.tp_r_multiple,
  dt.level_id,
  dt.direction,
  dt.declared_broker_time,
  dt.declared_analysis_time,
  dt.entry_bid,
  dt.entry_ask,
  dt.entry_price,
  dt.entry_quote_side,
  dt.exit_quote_side,
  dt.requested_risk_distance_price,
  dt.requested_risk_distance_points,
  dt.normalized_risk_ticks,
  dt.normalized_risk_distance_price,
  dt.normalized_risk_distance_points,
  dt.stop_loss_price,
  dt.take_profit_price,
  dt.geometry_equivalence_id,
  dt.spread_points,
  dt.point_size,
  dt.trade_tick_size,
  dt.stops_level_points,
  dt.freeze_level_points,
  dt.minimum_risk_distance_points,
  dt.distance_eligible,
  dt.eligibility_status,
  dt.ineligible_reason,
  dpe.symbol,
  so.macro_timeframe,
  dpe.deep_timeframe,
  dpe.micro_timeframe,
  so.active_bar_open_broker_time,
  dpe.active_deep_bar_open_broker_time,
  dpe.trigger_broker_time,
  dpe.trigger_analysis_time,
  dpe.trigger_bid,
  dpe.trigger_ask,
  dpe.pivot_raw_price,
  dpe.pivot_trade_price,
  dpe.next_outward_pivot_price,
  dpe.deep_micro_features_complete,
  dpe.deep_feature_invalid_reason,
  dpe.admission_status,
  concat(
    dpe.symbol,
    '|',
    so.macro_timeframe,
    '|',
    strftime(so.active_bar_open_broker_time, '%Y.%m.%d %H:%M:%S')
  ) AS research_group_id,
{_calendar_columns('dpe.trigger_analysis_time')},
  abs(dt.entry_price - dpe.pivot_trade_price)
    / NULLIF(dt.normalized_risk_distance_price, 0.0) AS trigger_gap_to_risk,
  dt.spread_points
    / NULLIF(dt.normalized_risk_distance_points, 0.0) AS spread_to_risk,
  CASE
    WHEN dpl.parent_kind = 'VIRTUAL' THEN pvo.terminal_broker_time
    WHEN dpl.parent_kind = 'BROKER' THEN pbo.close_broker_time
  END AS parent_terminal_broker_time,
  CASE
    WHEN dpl.parent_kind = 'VIRTUAL' THEN pvo.terminal_status
    WHEN dpl.parent_kind = 'BROKER' THEN pbo.broker_terminal_reason
  END AS parent_terminal_status,
  CASE
    WHEN dpl.parent_kind = 'VIRTUAL'
      THEN pvo.h1_structural_lifecycle_seconds
    WHEN dpl.parent_kind = 'BROKER'
      THEN pbo.h1_structural_lifecycle_seconds
  END AS h1_structural_lifecycle_seconds,
  CASE
    WHEN dpl.parent_kind = 'VIRTUAL'
      THEN pvo.terminal_status IN ('TP_FIRST', 'SL_FIRST')
    WHEN dpl.parent_kind = 'BROKER'
      THEN coalesce(pbo.broker_entry_confirmed AND pbo.broker_close_confirmed, false)
    ELSE false
  END AS parent_lifecycle_complete,
  dvo.deep_outcome_id,
  dvo.terminal_broker_time,
  dvo.terminal_analysis_time,
  dvo.terminal_status,
  dvo.terminal_reason,
  dvo.threshold_price,
  dvo.observed_exit_bid,
  dvo.observed_exit_ask,
  dvo.observed_exit_price,
  dvo.gap_points,
  dvo.deep_lifecycle_seconds,
  dvo.virtual_nominal_r,
  dvo.virtual_quote_gross_profit,
  dvo.virtual_quote_gross_r,
  dvo.virtual_binary_eligible,
  dvo.virtual_binary_target,
  dvo.virtual_exclusion_reason,
  dvo.first_touch_consistent
FROM deep_pivot_parent_links dpl
JOIN deep_pivot_events dpe
  ON dpe.run_id = dpl.run_id
 AND dpe.config_id = dpl.config_id
 AND dpe.deep_event_id = dpl.deep_event_id
JOIN signal_origins so
  ON so.run_id = dpl.run_id
 AND so.config_id = dpl.config_id
 AND so.origin_id = dpl.origin_id
JOIN deep_virtual_outcomes dvo
  ON dvo.run_id = dpl.run_id
 AND dvo.config_id = dpl.config_id
 AND dvo.parent_link_id = dpl.parent_link_id
JOIN deep_virtual_trials dt
  ON dt.run_id = dvo.run_id
 AND dt.config_id = dvo.config_id
 AND dt.deep_trial_id = dvo.deep_trial_id
LEFT JOIN virtual_outcomes pvo
  ON dpl.parent_kind = 'VIRTUAL'
 AND pvo.run_id = dpl.run_id
 AND pvo.config_id = dpl.config_id
 AND pvo.trial_id = dpl.parent_trial_id
LEFT JOIN broker_outcomes pbo
  ON dpl.parent_kind = 'BROKER'
 AND pbo.run_id = dpl.run_id
 AND pbo.config_id = dpl.config_id
 AND pbo.broker_signal_id = dpl.parent_broker_signal_id
ORDER BY dt.declared_broker_time, dpl.run_id, dpl.origin_id,
         dpl.parent_link_id, dt.tp_r_multiple
"""
    )


def _create_eligible_deep_trials(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        f"""
CREATE TABLE {ELIGIBLE_DEEP_TRIALS_TABLE} AS
SELECT
  *,
  1.0 / count(*) OVER (PARTITION BY origin_id)
    AS origin_sample_weight,
  1.0 / count(*) OVER (PARTITION BY deep_event_id)
    AS event_sample_weight,
  1.0 / (tp_r_multiple + 1.0) AS break_even_tp_rate
FROM {DEEP_PARENT_LONG_TABLE}
WHERE eligibility_status = 'ACTIVE'
  AND deep_micro_features_complete
  AND virtual_binary_eligible
  AND virtual_binary_target IN (0, 1)
  AND terminal_status IN ('TP_FIRST', 'SL_FIRST')
ORDER BY declared_broker_time, run_id, origin_id, deep_event_id,
         parent_link_id, tp_r_multiple
"""
    )


def _create_broker_virtual_calibration(
    connection: duckdb.DuckDBPyConnection,
) -> None:
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
  bo.deep_timeframe,
  bo.micro_timeframe,
  bo.level_id,
  bo.direction,
  bo.broker_terminal_reason,
  vo.terminal_status AS virtual_terminal_status,
  bo.broker_binary_eligible
    AND vo.virtual_binary_eligible
    AND vo.terminal_status IN ('TP_FIRST', 'SL_FIRST') AS strict_pair_eligible,
  CASE
    WHEN NOT bo.broker_binary_eligible THEN bo.broker_exclusion_reason
    WHEN NOT vo.virtual_binary_eligible THEN vo.virtual_exclusion_reason
    WHEN vo.terminal_status NOT IN ('TP_FIRST', 'SL_FIRST') THEN 'PARITY_NONBINARY'
    ELSE NULL
  END AS calibration_exclusion_reason,
  CASE
    WHEN bo.broker_binary_eligible AND vo.virtual_binary_eligible
      THEN bo.broker_binary_target = vo.virtual_binary_target
    ELSE NULL
  END AS terminal_agreement,
  vo.terminal_broker_time AS virtual_first_crossing_time,
  bo.close_broker_time AS broker_close_time,
  date_diff('second', vo.terminal_broker_time, bo.close_broker_time)
    AS crossing_close_delta_seconds,
  bo.submitted_request_price,
  vt.entry_price AS virtual_entry_price,
  bo.broker_entry_price,
  (bo.broker_entry_price - bo.submitted_request_price)
    / NULLIF(vt.point_size, 0.0) AS broker_entry_slippage_points,
  vo.observed_exit_price AS virtual_exit_price,
  bo.broker_close_price,
  (bo.broker_close_price - vo.observed_exit_price)
    / NULLIF(vt.point_size, 0.0) AS broker_minus_virtual_exit_points,
  vo.virtual_quote_gross_profit,
  bo.broker_gross_profit,
  bo.broker_gross_profit - vo.virtual_quote_gross_profit
    AS broker_minus_virtual_gross_profit,
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


def _count(connection: duckdb.DuckDBPyConnection, query: str) -> int:
    return int(connection.execute(query).fetchone()[0])


def _require_weight_balance(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
) -> None:
    invalid = _count(
        connection,
        f"""
SELECT count(*)
FROM (
  SELECT origin_id, sum(origin_sample_weight) AS total_weight
  FROM {table_name}
  GROUP BY origin_id
  HAVING abs(total_weight - 1.0) > 1e-9
)
""",
    )
    if invalid:
        raise RuntimeError(f"{table_name} origin weights do not sum to one")


def _require_event_weight_balance(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
) -> None:
    invalid = _count(
        connection,
        f"""
SELECT count(*)
FROM (
  SELECT deep_event_id, sum(event_sample_weight) AS total_weight
  FROM {table_name}
  GROUP BY deep_event_id
  HAVING abs(total_weight - 1.0) > 1e-9
)
""",
    )
    if invalid:
        raise RuntimeError(f"{table_name} event weights do not sum to one")


def _require_complete_features(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
    complete_column: str,
    feature_columns: tuple[str, ...],
) -> None:
    missing_predicate = " OR ".join(
        f"{_quoted(column)} IS NULL" for column in feature_columns
    )
    invalid = _count(
        connection,
        f"""
SELECT count(*)
FROM {table_name}
WHERE coalesce({_quoted(complete_column)}, false)
  AND ({missing_predicate})
""",
    )
    if invalid:
        raise RuntimeError(
            f"{table_name} marks {complete_column} with missing feature values"
        )


def _validate_derived_tables(connection: duckdb.DuckDBPyConnection) -> None:
    expected_h1 = _count(
        connection,
        "SELECT count(*) FROM virtual_trials WHERE trial_role = 'H1'",
    )
    actual_h1 = _count(connection, f"SELECT count(*) FROM {H1_LANE_LONG_TABLE}")
    if actual_h1 != expected_h1:
        raise RuntimeError(f"H1 lane grain mismatch: {actual_h1} != {expected_h1}")
    malformed_h1 = _count(
        connection,
        f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, origin_id, count(*) AS lane_count
  FROM {H1_LANE_LONG_TABLE}
  GROUP BY ALL
  HAVING lane_count <> 8
)
""",
    )
    if malformed_h1:
        raise RuntimeError("H1 origin does not contain exactly eight lane outcomes")
    duplicate_h1 = _count(
        connection,
        f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, trial_id
  FROM {H1_LANE_LONG_TABLE}
  GROUP BY ALL
  HAVING count(*) <> 1
)
""",
    )
    if duplicate_h1:
        raise RuntimeError("H1 lane long contains duplicate trial grain")
    expected_wide = _count(
        connection,
        "SELECT count(*) FROM signal_origins WHERE h1_lanes_declared",
    )
    actual_wide = _count(connection, f"SELECT count(*) FROM {H1_LANE_WIDE_TABLE}")
    if actual_wide != expected_wide:
        raise RuntimeError(f"H1 lane wide grain mismatch: {actual_wide} != {expected_wide}")
    _require_weight_balance(connection, ELIGIBLE_H1_TRIALS_TABLE)
    _require_complete_features(
        connection,
        "signal_origins",
        "origin_feature_snapshot_complete",
        ORIGIN_SIGNAL_FEATURE_COLUMNS,
    )

    expected_deep = _count(connection, "SELECT count(*) FROM deep_virtual_outcomes")
    actual_deep = _count(connection, f"SELECT count(*) FROM {DEEP_PARENT_LONG_TABLE}")
    if actual_deep != expected_deep:
        raise RuntimeError(f"Deep parent grain mismatch: {actual_deep} != {expected_deep}")
    duplicate_deep = _count(
        connection,
        f"""
SELECT count(*)
FROM (
  SELECT run_id, config_id, parent_link_id, deep_trial_id
  FROM {DEEP_PARENT_LONG_TABLE}
  GROUP BY ALL
  HAVING count(*) <> 1
)
""",
    )
    if duplicate_deep:
        raise RuntimeError("Deep parent long contains duplicate link/trial grain")
    _require_weight_balance(connection, ELIGIBLE_DEEP_TRIALS_TABLE)
    _require_event_weight_balance(connection, ELIGIBLE_DEEP_TRIALS_TABLE)
    _require_complete_features(
        connection,
        "deep_pivot_events",
        "deep_micro_features_complete",
        DEEP_MICRO_FEATURE_COLUMNS,
    )

    deep_columns = {
        row[0]
        for row in connection.execute(f"DESCRIBE {DEEP_PARENT_LONG_TABLE}").fetchall()
    }
    eligible_deep_columns = {
        row[0]
        for row in connection.execute(
            f"DESCRIBE {ELIGIBLE_DEEP_TRIALS_TABLE}"
        ).fetchall()
    }
    duplicated_event_features = sorted(
        set(DEEP_MICRO_FEATURE_COLUMNS) & (deep_columns | eligible_deep_columns)
    )
    if duplicated_event_features:
        raise RuntimeError(
            "Deep event features were persisted outside event grain: "
            f"{duplicated_event_features}"
        )
    h1_columns = {
        row[0]
        for row in connection.execute(f"DESCRIBE {ELIGIBLE_H1_TRIALS_TABLE}").fetchall()
    }
    missing_h1_features = sorted(set(H1_MODEL_FEATURE_COLUMNS) - h1_columns)
    if missing_h1_features:
        raise RuntimeError(f"Eligible H1 cohort lacks model features: {missing_h1_features}")
    deep_event_columns = {
        row[0]
        for row in connection.execute("DESCRIBE deep_pivot_events").fetchall()
    }
    missing_event_features = sorted(set(DEEP_MICRO_FEATURE_COLUMNS) - deep_event_columns)
    if missing_event_features:
        raise RuntimeError(
            f"Deep event grain lacks model features: {missing_event_features}"
        )
    required_parent_features = set(DEEP_MODEL_FEATURE_COLUMNS) - set(
        DEEP_MICRO_FEATURE_COLUMNS
    )
    missing_parent_features = sorted(required_parent_features - eligible_deep_columns)
    if missing_parent_features:
        raise RuntimeError(
            "Eligible deep cohort lacks parent-grain model features: "
            f"{missing_parent_features}"
        )

    expected_calibration = _count(
        connection,
        "SELECT count(*) FROM broker_outcomes WHERE parity_trial_id IS NOT NULL",
    )
    actual_calibration = _count(
        connection,
        f"SELECT count(*) FROM {BROKER_VIRTUAL_CALIBRATION_TABLE}",
    )
    if actual_calibration != expected_calibration:
        raise RuntimeError(
            "Broker/virtual calibration grain mismatch: "
            f"{actual_calibration} != {expected_calibration}"
        )
    mismatches = _count(
        connection,
        f"""
SELECT count(*)
FROM {BROKER_VIRTUAL_CALIBRATION_TABLE}
WHERE strict_pair_eligible AND NOT terminal_agreement
""",
    )
    if mismatches:
        raise RuntimeError("Calibration contains unexplained strict TP/SL mismatch")


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS,
) -> dict[str, int]:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise RuntimeError("Only schema 13 dataset assembly is active")
    if tuple(feature_columns) not in {
        tuple(H1_MODEL_FEATURE_COLUMNS),
        tuple(DEEP_MODEL_FEATURE_COLUMNS),
    }:
        raise RuntimeError("Schema V13 requires an explicit H1 or deep feature set")
    raw_counts = create_raw_tables(connection, validations)
    _create_h1_lane_long(connection)
    _create_h1_lane_wide(connection)
    _create_eligible_h1_trials(connection)
    _create_deep_parent_long(connection)
    _create_eligible_deep_trials(connection)
    _create_broker_virtual_calibration(connection)
    _validate_derived_tables(connection)
    counts = dict(raw_counts)
    for table_name in DERIVED_TABLES:
        counts[table_name] = _count(connection, f"SELECT count(*) FROM {table_name}")
    return counts


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
    parser.add_argument("--runs-root", required=True)
    parser.add_argument("--run-id", action="append", required=True)
    parser.add_argument("--dataset-id", default="")
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
                    f"h1_trials={validation.virtual_trial_rows} "
                    f"deep_events={validation.deep_event_rows}"
                )
            return 0
        if not args.dataset_id:
            raise RuntimeError("--dataset-id is required unless --validate-only is used")
        output_dir = prepare_output_dir(Path(args.output_root), args.dataset_id, args.overwrite)
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
