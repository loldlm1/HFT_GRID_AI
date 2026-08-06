"""Validate strict V10 runs and build leakage-safe Parquet research datasets."""

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
    EXECUTION_CHECKS_FILE,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    NULL_TOKEN,
    PIVOT_WINDOWS_FILE,
    RUN_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_ATTEMPTS_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    RunValidation,
    SchemaValidationError,
    feature_columns_for_set,
    validate_runs,
)


DEFAULT_DATASET_ROOT = "artifacts/datasets"
RESEARCH_MATRIX_TABLE = "research_matrix"
BINARY_OUTCOMES_TABLE = "binary_outcomes"

BOOLEAN_COLUMNS = {
    "macro_band_complete",
    "micro_features_complete",
    "macro_features_complete",
    "feature_snapshot_complete",
    "identity_consumed",
    "send_attempted",
    "send_succeeded",
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
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "close_reason_consistent",
    "binary_eligible",
}

INTEGER_COLUMNS = {
    "schema_version",
    "active_bar_open_offset_minutes",
    "source_bar_open_offset_minutes",
    "source_close_boundary_offset_minutes",
    "first_observed_offset_minutes",
    "pp_arm_offset_minutes",
    "terminal_offset_minutes",
    "trigger_offset_minutes",
    "request_offset_minutes",
    "check_sequence",
    "offset_minutes",
    "entry_offset_minutes",
    "close_offset_minutes",
    "account_margin_mode",
    "symbol_trade_mode",
    "order_check_retcode",
    "send_retcode",
    "order_ticket",
    "deal_ticket",
    "position_ticket",
    "position_identifier",
    "entry_deal_ticket",
    "last_close_deal_ticket",
    "close_deal_count",
    "binary_target",
    "duration_seconds",
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
}

STRING_COLUMNS = {
    "key",
    "value",
    "run_id",
    "config_id",
    "window_id",
    "signal_id",
    "symbol",
    "macro_timeframe",
    "micro_timeframe",
    "pp_initial_relation",
    "pp_role",
    "macro_band_invalid_reason",
    "window_state",
    "invalid_reason",
    "terminal_status",
    "level_id",
    "direction",
    "lot_mode",
    "account_currency",
    "feature_invalid_reason",
    "route_status",
    "attempt_status",
    "block_source",
    "block_reason",
    "check_phase",
    "order_check_comment",
    "send_comment",
    "terminal_reason",
    "exclusion_reason",
    "export_status",
    "completion_status",
}

TIMESTAMP_COLUMNS = {
    column
    for columns in TABLE_COLUMNS.values()
    for column in columns
    if column.endswith("_time")
}


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _quoted(column: str) -> str:
    return '"' + column.replace('"', '""') + '"'


def _typed_expression(column: str) -> str:
    quoted = _quoted(column)
    nullified = f"NULLIF({quoted}, {_sql_literal(NULL_TOKEN)})"
    if column in TIMESTAMP_COLUMNS:
        return f"strptime({nullified}, '%Y.%m.%d %H:%M:%S') AS {quoted}"
    if column in BOOLEAN_COLUMNS:
        return f"CAST(CAST({nullified} AS TINYINT) AS BOOLEAN) AS {quoted}"
    if column in INTEGER_COLUMNS:
        return f"CAST({nullified} AS BIGINT) AS {quoted}"
    if column in STRING_COLUMNS:
        return f"{nullified} AS {quoted}"
    return f"CAST({nullified} AS DOUBLE) AS {quoted}"


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
  union_by_name=true,
  nullstr='__PIVOT_V10_NO_AUTOMATIC_NULL__'
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


def _create_research_matrix(connection: duckdb.DuckDBPyConnection) -> None:
    micro_b_columns = ",\n  ".join(
        f"a.micro_b_percent_{shift}" for shift in range(6)
    )
    macro_b_columns = ",\n  ".join(
        f"a.macro_pivot_b_percent_{shift}" for shift in range(6)
    )
    connection.execute(
        f"""
CREATE TABLE {RESEARCH_MATRIX_TABLE} AS
SELECT
  a.schema_version,
  a.run_id,
  a.config_id,
  a.signal_id,
  a.window_id,
  a.symbol,
  a.macro_timeframe,
  a.micro_timeframe,
  a.active_bar_open_broker_time,
  a.level_id,
  a.direction,
  a.trigger_broker_time,
  a.trigger_analysis_time,
  a.trigger_offset_minutes,
  concat(
    a.symbol,
    '|',
    a.macro_timeframe,
    '|',
    strftime(a.active_bar_open_broker_time, '%Y.%m.%d %H:%M:%S')
  ) AS research_group_id,
  strftime(a.trigger_analysis_time, '%w') AS analysis_weekday,
  CASE
    WHEN EXTRACT(hour FROM a.trigger_analysis_time) < 6 THEN 'SESSION_00_05'
    WHEN EXTRACT(hour FROM a.trigger_analysis_time) < 12 THEN 'SESSION_06_11'
    WHEN EXTRACT(hour FROM a.trigger_analysis_time) < 18 THEN 'SESSION_12_17'
    ELSE 'SESSION_18_23'
  END AS analysis_session,
  sin(
    2.0 * pi() *
    (EXTRACT(hour FROM a.trigger_analysis_time) * 60.0 +
     EXTRACT(minute FROM a.trigger_analysis_time)) / 1440.0
  ) AS time_sin,
  cos(
    2.0 * pi() *
    (EXTRACT(hour FROM a.trigger_analysis_time) * 60.0 +
     EXTRACT(minute FROM a.trigger_analysis_time)) / 1440.0
  ) AS time_cos,
  a.micro_band_width_percent_0,
  w.macro_band_width_percent_1,
  {micro_b_columns},
  {macro_b_columns},
  CASE
    WHEN a.direction = 'BUY' THEN a.pivot_trade_price - a.trigger_bid
    ELSE a.trigger_bid - a.pivot_trade_price
  END / NULLIF(a.observed_risk_distance_points * a.point_size, 0.0)
    AS trigger_gap_to_risk,
  a.spread_points / NULLIF(a.observed_risk_distance_points, 0.0)
    AS spread_to_risk,
  w.source_range / NULLIF(w.macro_band_width_1, 0.0)
    AS macro_range_to_band_width,
  w.source_open,
  w.source_high,
  w.source_low,
  w.source_close,
  w.source_range,
  w.macro_band_width_1,
  a.trigger_bid,
  a.trigger_ask,
  a.spread_points,
  a.point_size,
  a.pivot_raw_price,
  a.pivot_trade_price,
  a.structural_sl_price,
  a.observed_entry_price,
  a.observed_take_profit,
  a.observed_risk_distance_points,
  a.request_broker_time,
  a.request_entry_price,
  a.request_stop_loss,
  a.request_take_profit,
  a.request_risk_distance_points,
  a.request_reward_distance_points,
  a.request_price_reward_risk_ratio,
  a.lot_mode,
  a.lot_strategy_size,
  a.reference_balance,
  a.account_currency,
  a.risk_budget_amount,
  a.normalized_volume,
  a.quote_expected_stop_loss,
  a.quote_expected_take_profit,
  a.quote_expected_reward_risk_ratio,
  a.risk_budget_utilization_ratio,
  a.route_status,
  a.attempt_status,
  a.block_source,
  a.block_reason,
  a.send_attempted,
  a.send_succeeded,
  o.entry_broker_time,
  o.close_broker_time,
  o.order_ticket,
  o.position_identifier,
  o.broker_entry_price,
  o.close_price,
  o.entry_slippage_points,
  o.exit_slippage_points,
  o.gross_profit,
  o.commission,
  o.swap,
  o.fee,
  o.net_profit,
  o.gross_budget_r,
  o.net_budget_r,
  o.gross_execution_r,
  o.net_execution_r,
  o.terminal_reason,
  o.binary_eligible,
  o.binary_target,
  o.exclusion_reason,
  o.duration_seconds
FROM signal_attempts a
JOIN pivot_windows w
  ON w.run_id = a.run_id
 AND w.config_id = a.config_id
 AND w.window_id = a.window_id
LEFT JOIN signal_outcomes o
  ON o.run_id = a.run_id
 AND o.config_id = a.config_id
 AND o.signal_id = a.signal_id
WHERE a.identity_consumed
  AND a.feature_snapshot_complete
ORDER BY a.trigger_broker_time, a.run_id, a.signal_id
"""
    )
    connection.execute(
        f"""
CREATE TABLE {BINARY_OUTCOMES_TABLE} AS
SELECT *
FROM {RESEARCH_MATRIX_TABLE}
WHERE binary_eligible
  AND binary_target IN (0, 1)
  AND close_broker_time IS NOT NULL
ORDER BY trigger_broker_time, run_id, signal_id
"""
    )


def _validate_derived_tables(connection: duckdb.DuckDBPyConnection) -> None:
    expected_research = int(
        connection.execute(
            "SELECT COUNT(*) FROM signal_attempts "
            "WHERE identity_consumed AND feature_snapshot_complete"
        ).fetchone()[0]
    )
    actual_research = int(
        connection.execute(f"SELECT COUNT(*) FROM {RESEARCH_MATRIX_TABLE}").fetchone()[0]
    )
    if actual_research != expected_research:
        raise RuntimeError(
            f"Research matrix grain mismatch: {actual_research} != {expected_research}"
        )
    duplicate_rows = int(
        connection.execute(
            f"""
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, signal_id
  FROM {RESEARCH_MATRIX_TABLE}
  GROUP BY 1, 2, 3
  HAVING COUNT(*) <> 1
)
"""
        ).fetchone()[0]
    )
    if duplicate_rows:
        raise RuntimeError("Research matrix contains duplicate attempt rows")
    expected_binary = int(
        connection.execute(
            "SELECT COUNT(*) FROM signal_outcomes WHERE binary_eligible"
        ).fetchone()[0]
    )
    actual_binary = int(
        connection.execute(f"SELECT COUNT(*) FROM {BINARY_OUTCOMES_TABLE}").fetchone()[0]
    )
    if actual_binary != expected_binary:
        raise RuntimeError(
            f"Binary outcome grain mismatch: {actual_binary} != {expected_binary}"
        )
    matrix_columns = {
        row[0]
        for row in connection.execute(f"DESCRIBE {RESEARCH_MATRIX_TABLE}").fetchall()
    }
    missing_features = sorted(set(MODEL_FEATURE_COLUMNS) - matrix_columns)
    if missing_features:
        raise RuntimeError(f"Research matrix lacks model features: {missing_features}")
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
        raise RuntimeError("Schema V10 requires the exact frozen feature set")
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
    _create_research_matrix(connection)
    _validate_derived_tables(connection)
    table_names = [Path(filename).stem for filename in RUN_FILES] + [
        RESEARCH_MATRIX_TABLE,
        BINARY_OUTCOMES_TABLE,
    ]
    return {
        table_name: int(
            connection.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
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
    parser.add_argument("--runs-root", required=True, help="Folder containing V10 run folders.")
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
    parser = build_parser()
    args = parser.parse_args()
    try:
        feature_columns = feature_columns_for_set(args.feature_set_id)
        validations = validate_runs(
            Path(args.runs_root),
            args.run_id,
            schema_version=args.schema_version,
        )
        totals = {
            filename: sum(validation.row_counts[filename] for validation in validations)
            for filename in RUN_FILES
        }
        if args.validate_only:
            print(
                "schema V10 validation ok | "
                f"runs={len(validations)} | attempts={totals[SIGNAL_ATTEMPTS_FILE]} | "
                f"outcomes={totals[SIGNAL_OUTCOMES_FILE]}"
            )
            return 0
        if not args.dataset_id:
            raise RuntimeError("--dataset-id is required when building a dataset")

        output_dir = prepare_output_dir(Path(args.output_root), args.dataset_id, args.overwrite)
        connection = duckdb.connect(":memory:")
        try:
            counts = create_dataset_tables(
                connection,
                validations,
                args.schema_version,
                feature_columns,
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
    except (SchemaValidationError, RuntimeError, ValueError, duckdb.Error) as exc:
        parser.exit(1, f"pivot V10 dataset build failed: {exc}\n")

    print(
        "pivot V10 dataset build ok | "
        f"dataset={args.dataset_id} | research_rows={counts[RESEARCH_MATRIX_TABLE]} | "
        f"binary_rows={counts[BINARY_OUTCOMES_TABLE]} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
