"""Validate strict pivot-fractal V9 runs and build leakage-safe Parquet datasets."""

from __future__ import annotations

import argparse
import shutil
from time import perf_counter
from pathlib import Path

import duckdb

from retest_confluence import (
    CONFLUENCE_RESEARCH_FEATURE_SET_ID,
    DerivedResearchError,
    create_confluence_tables,
    create_retest_context_table,
    research_feature_columns_for_set,
    validate_retest_context_table,
)
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
)
from schema_contract import (
    CONTEXT_PREFIXES,
    CONTEXT_TIMEFRAMES,
    DATASET_TARGET_FAMILIES,
    EXECUTION_CHECKS_FILE,
    FEATURE_SET_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    NULL_TOKEN,
    PIVOT_LEVELS_FILE,
    PIVOT_WINDOWS_FILE,
    RUN_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_ATTEMPTS_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    TRAILING_EVENTS_FILE,
    RunValidation,
    SchemaValidationError,
    feature_columns_for_set,
    validate_runs,
)


DEFAULT_DATASET_ROOT = "artifacts/datasets"

BOOLEAN_COLUMNS = {
    "feature_snapshot_complete",
    "send_attempted",
    "structure_complete",
    "b_percent_complete",
    "feature_complete",
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
    "broker_entry_confirmed",
    "broker_close_confirmed",
    "request_performed",
    "request_succeeded",
    "retry_pending",
}

INTEGER_COLUMNS = {
    "schema_version",
    "active_bar_open_offset_minutes",
    "source_bar_open_offset_minutes",
    "source_close_boundary_offset_minutes",
    "terminal_offset_minutes",
    "trigger_offset_minutes",
    "check_sequence",
    "offset_minutes",
    "event_sequence",
    "event_offset_minutes",
    "entry_offset_minutes",
    "close_offset_minutes",
    "level_order",
    "account_margin_mode",
    "symbol_trade_mode",
    "duration_seconds",
    "pivot_window_rows",
    "pivot_level_rows",
    "signal_attempt_rows",
    "signal_feature_rows",
    "execution_check_rows",
    "trailing_event_rows",
    "signal_outcome_rows",
    "feature_incomplete_rows",
    "duplicate_identity_count",
    "referential_integrity_error_count",
    "row_integrity_error_count",
}

UNSIGNED_INTEGER_COLUMNS = {
    "order_check_retcode",
    "send_retcode",
    "order_ticket",
    "deal_ticket",
    "entry_deal_ticket",
    "close_deal_ticket",
    "position_ticket",
    "position_identifier",
    "retcode",
}

DOUBLE_COLUMNS = {
    "source_high",
    "source_low",
    "source_close",
    "source_range",
    "raw_price",
    "trade_price",
    "previous_m1_bid_close",
    "trigger_bid",
    "trigger_ask",
    "spread_points",
    "intended_entry_price",
    "initial_stop_loss",
    "terminal_take_profit",
    "bid",
    "ask",
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
    "account_balance",
    "free_margin",
    "required_margin",
    "broker_entry_price",
    "broker_volume",
    "broker_stop_loss",
    "broker_take_profit",
    "close_price",
    "closed_volume",
    "realized_profit",
    "milestone_price",
    "previous_confirmed_stop",
    "desired_stop",
    "requested_stop",
    "confirmed_stop",
    "final_broker_stop_loss",
    "final_broker_take_profit",
    *(f"b_percent_{shift}" for shift in range(6)),
}

TIMESTAMP_COLUMNS = {
    column
    for columns in TABLE_COLUMNS.values()
    for column in columns
    if column.endswith("_time")
    or column.endswith("_broker_time")
    or column.endswith("_analysis_time")
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
        return f"CAST({nullified} AS BOOLEAN) AS {quoted}"
    if column in UNSIGNED_INTEGER_COLUMNS:
        return f"CAST({nullified} AS UBIGINT) AS {quoted}"
    if column in INTEGER_COLUMNS:
        return f"CAST({nullified} AS BIGINT) AS {quoted}"
    if column in DOUBLE_COLUMNS:
        return f"CAST({nullified} AS DOUBLE) AS {quoted}"
    return f"{nullified} AS {quoted}"


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
  nullstr='__PIVOT_V9_NO_AUTOMATIC_NULL__'
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


def _create_feature_snapshots(connection: duckdb.DuckDBPyConnection) -> None:
    aggregates: list[str] = []
    for timeframe in CONTEXT_TIMEFRAMES:
        prefix = CONTEXT_PREFIXES[timeframe]
        for slot in range(3):
            aggregates.append(
                "MAX(CASE WHEN context_timeframe = "
                f"{_sql_literal(timeframe)} THEN structure_{slot} END) "
                f"AS {prefix}_structure_{slot}"
            )
        for shift in range(6):
            aggregates.append(
                "MAX(CASE WHEN context_timeframe = "
                f"{_sql_literal(timeframe)} THEN b_percent_{shift} END) "
                f"AS {prefix}_b_percent_{shift}"
            )
    connection.execute(
        f"""
CREATE TEMP TABLE feature_snapshots AS
SELECT
  run_id,
  config_id,
  signal_id,
  {",\n  ".join(aggregates)}
FROM signal_features
GROUP BY run_id, config_id, signal_id
"""
    )


def _create_entry_evidence(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute(
        """
CREATE TEMP TABLE entry_evidence AS
SELECT
  run_id,
  config_id,
  signal_id,
  BOOL_OR(broker_entry_confirmed) AS target_admitted,
  MAX(CASE WHEN broker_entry_confirmed THEN broker_entry_price END) AS confirmed_entry_price,
  MAX(CASE WHEN broker_entry_confirmed THEN position_ticket END) AS position_ticket,
  MAX(CASE WHEN broker_entry_confirmed THEN position_identifier END) AS position_identifier
FROM execution_checks
GROUP BY run_id, config_id, signal_id
"""
    )


def _target_projection(target_family: str) -> tuple[str, str]:
    if target_family == "broker_outcome":
        return (
            "JOIN signal_outcomes o USING (run_id, config_id, signal_id)",
            """
TRUE AS target_admitted,
CASE WHEN o.realized_profit > 0.0 THEN 1 ELSE 0 END AS target_is_profit,
o.realized_profit AS target_realized_profit,
o.terminal_reason AS target_terminal_reason,
o.duration_seconds AS target_duration_seconds,
o.broker_entry_price,
o.close_price,
o.highest_milestone_level
""",
        )
    if target_family == "admission":
        return (
            "LEFT JOIN signal_outcomes o USING (run_id, config_id, signal_id)",
            """
COALESCE(e.target_admitted, FALSE) AS target_admitted,
NULL::BIGINT AS target_is_profit,
NULL::DOUBLE AS target_realized_profit,
COALESCE(o.terminal_reason, a.block_reason, a.attempt_status) AS target_terminal_reason,
o.duration_seconds AS target_duration_seconds,
o.broker_entry_price,
o.close_price,
o.highest_milestone_level
""",
        )
    raise RuntimeError(f"Unsupported target family: {target_family}")


def _create_training_matrix(
    connection: duckdb.DuckDBPyConnection,
    target_family: str,
    research_feature_set_id: str = "",
) -> None:
    outcome_join, target_columns = _target_projection(target_family)
    context_columns = ",\n  ".join(
        f"f.{column}"
        for column in MODEL_FEATURE_COLUMNS
        if column not in {
            "symbol",
            "pivot_timeframe",
            "level_id",
            "direction",
            "analysis_weekday",
            *[column for column in MODEL_FEATURE_COLUMNS if column in {
                "trigger_offset_minutes",
                "analysis_hour",
                "analysis_minute",
                "time_sin",
                "time_cos",
                "source_range",
                "level_trade_price",
                "level_order",
                "previous_m1_bid_close",
                "trigger_bid",
                "trigger_ask",
                "spread_points",
                "intended_entry_price",
                "initial_stop_loss",
                "terminal_take_profit",
                "previous_close_delta_to_level",
                "trigger_delta_to_level",
                "risk_distance",
                "reward_distance",
                "previous_close_delta_to_range",
                "trigger_delta_to_range",
                "risk_to_range",
                "reward_to_range",
            }],
        }
    )
    # The context set above intentionally leaves only the six-timeframe feature columns.
    connection.execute(
        f"""
CREATE TEMP TABLE base_training_matrix AS
SELECT
  a.schema_version,
  a.run_id,
  a.config_id,
  a.signal_id,
  a.window_id,
  a.symbol,
  a.pivot_timeframe,
  a.active_bar_open_broker_time,
  a.level_id,
  a.direction,
  a.trigger_broker_time,
  a.trigger_analysis_time,
  a.trigger_offset_minutes,
  strftime(a.trigger_analysis_time, '%w') AS analysis_weekday,
  EXTRACT(hour FROM a.trigger_analysis_time)::BIGINT AS analysis_hour,
  EXTRACT(minute FROM a.trigger_analysis_time)::BIGINT AS analysis_minute,
  sin(2.0 * pi() * (
    EXTRACT(hour FROM a.trigger_analysis_time) * 60.0 +
    EXTRACT(minute FROM a.trigger_analysis_time)
  ) / 1440.0) AS time_sin,
  cos(2.0 * pi() * (
    EXTRACT(hour FROM a.trigger_analysis_time) * 60.0 +
    EXTRACT(minute FROM a.trigger_analysis_time)
  ) / 1440.0) AS time_cos,
  w.source_range,
  l.trade_price AS level_trade_price,
  l.level_order,
  a.previous_m1_bid_close,
  a.trigger_bid,
  a.trigger_ask,
  a.spread_points,
  a.intended_entry_price,
  a.initial_stop_loss,
  a.terminal_take_profit,
  CASE
    WHEN a.direction = 'BUY' THEN a.previous_m1_bid_close - l.trade_price
    ELSE l.trade_price - a.previous_m1_bid_close
  END AS previous_close_delta_to_level,
  CASE
    WHEN a.direction = 'BUY' THEN l.trade_price - a.trigger_bid
    ELSE a.trigger_bid - l.trade_price
  END AS trigger_delta_to_level,
  abs(a.intended_entry_price - a.initial_stop_loss) AS risk_distance,
  abs(a.terminal_take_profit - a.intended_entry_price) AS reward_distance,
  previous_close_delta_to_level / NULLIF(w.source_range, 0.0) AS previous_close_delta_to_range,
  trigger_delta_to_level / NULLIF(w.source_range, 0.0) AS trigger_delta_to_range,
  risk_distance / NULLIF(w.source_range, 0.0) AS risk_to_range,
  reward_distance / NULLIF(w.source_range, 0.0) AS reward_to_range,
  {context_columns},
  a.attempt_status,
  a.block_source,
  a.block_reason,
  {_sql_literal(target_family)} AS target_family,
  {target_columns}
FROM signal_attempts a
JOIN pivot_windows w USING (run_id, config_id, window_id)
JOIN pivot_levels l
  ON l.run_id = a.run_id
 AND l.config_id = a.config_id
 AND l.window_id = a.window_id
 AND l.level_id = a.level_id
JOIN feature_snapshots f USING (run_id, config_id, signal_id)
JOIN entry_evidence e USING (run_id, config_id, signal_id)
{outcome_join}
ORDER BY a.trigger_broker_time, a.run_id, a.signal_id
"""
    )
    if not research_feature_set_id:
        connection.execute(
            "CREATE TABLE training_matrix AS SELECT * FROM base_training_matrix"
        )
        return
    if research_feature_set_id != CONFLUENCE_RESEARCH_FEATURE_SET_ID:
        raise RuntimeError(
            f"Unsupported offline research feature set: {research_feature_set_id}"
        )
    connection.execute(
        """
CREATE TEMP TABLE retest_model_features AS
SELECT
  run_id,
  config_id,
  signal_id,
  MAX(CASE WHEN context_timeframe = 'PERIOD_M15' THEN retest_type END)
    AS m15_retest_type,
  MAX(CASE WHEN context_timeframe = 'PERIOD_M30' THEN retest_type END)
    AS m30_retest_type,
  MAX(CASE WHEN context_timeframe = 'PERIOD_H1' THEN retest_type END)
    AS h1_retest_type,
  MAX(CASE WHEN context_timeframe = 'PERIOD_H4' THEN retest_type END)
    AS h4_retest_type,
  MAX(CASE WHEN context_timeframe = 'PERIOD_D1' THEN retest_type END)
    AS d1_retest_type,
  SUM(CASE WHEN context_timeframe <> 'PERIOD_M1'
                AND retest_type = 'BUY_RETEST' THEN 1 ELSE 0 END)::BIGINT
    AS macro_buy_retest_count,
  SUM(CASE WHEN context_timeframe <> 'PERIOD_M1'
                AND retest_type = 'SELL_RETEST' THEN 1 ELSE 0 END)::BIGINT
    AS macro_sell_retest_count,
  SUM(CASE WHEN context_timeframe <> 'PERIOD_M1'
                AND retest_type = 'EQUAL_NEUTRAL' THEN 1 ELSE 0 END)::BIGINT
    AS macro_neutral_count
FROM signal_retest_context
GROUP BY 1, 2, 3
"""
    )
    connection.execute(
        """
CREATE TABLE training_matrix AS
SELECT
  base.*,
  retest.m15_retest_type,
  retest.m30_retest_type,
  retest.h1_retest_type,
  retest.h4_retest_type,
  retest.d1_retest_type,
  retest.macro_buy_retest_count,
  retest.macro_sell_retest_count,
  retest.macro_neutral_count,
  snapshot.active_peer_count,
  snapshot.active_timeframe_count,
  snapshot.active_buy_peer_count,
  snapshot.active_sell_peer_count,
  snapshot.aligned_peer_count,
  snapshot.opposed_peer_count,
  snapshot.neutral_peer_count,
  snapshot.same_trigger_peer_count,
  snapshot.research_group_id
FROM base_training_matrix base
JOIN retest_model_features retest USING (run_id, config_id, signal_id)
JOIN confluence_snapshots snapshot
  ON snapshot.run_id = base.run_id
 AND snapshot.config_id = base.config_id
 AND snapshot.anchor_signal_id = base.signal_id
ORDER BY base.trigger_broker_time, base.run_id, base.signal_id
"""
    )
    base_rows = int(connection.execute("SELECT COUNT(*) FROM base_training_matrix").fetchone()[0])
    derived_rows = int(connection.execute("SELECT COUNT(*) FROM training_matrix").fetchone()[0])
    if base_rows != derived_rows:
        raise DerivedResearchError(
            f"Confluence feature join changed training grain: {derived_rows} != {base_rows}"
        )


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    target_family: str,
    schema_version: int,
    feature_columns: tuple[str, ...],
    research_feature_set_id: str = "",
) -> dict[str, int]:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise RuntimeError(
            f"Only schema {SUPPORTED_SCHEMA_VERSION} dataset assembly is active"
        )
    if target_family not in DATASET_TARGET_FAMILIES:
        raise RuntimeError(f"Unsupported target family: {target_family}")
    if tuple(feature_columns) != MODEL_FEATURE_COLUMNS:
        raise RuntimeError("Schema V9 training requires the exact frozen feature set")
    if any(column in MODEL_FEATURE_COLUMNS for column in FUTURE_ONLY_COLUMNS):
        raise RuntimeError("Future-only fields leaked into the model feature contract")
    selected_feature_columns = research_feature_columns_for_set(research_feature_set_id)
    feature_denylist = {
        *FUTURE_ONLY_COLUMNS,
        "signal_id",
        "window_id",
        "research_group_id",
        "canonical_member_tokens",
        "target_admitted",
        "target_is_profit",
        "target_realized_profit",
        "target_terminal_reason",
        "target_duration_seconds",
    }
    leaked_columns = sorted(set(selected_feature_columns) & feature_denylist)
    if leaked_columns:
        raise RuntimeError(f"Denied fields leaked into research features: {leaked_columns}")

    for filename in RUN_FILES:
        table_name = Path(filename).stem
        _load_typed_table(
            connection,
            table_name,
            [validation.run_path / filename for validation in validations],
            TABLE_COLUMNS[filename],
        )
    connection.execute(
        "CREATE TEMP TABLE derived_build_metrics (stage VARCHAR, duration_seconds DOUBLE)"
    )
    stage_started = perf_counter()
    create_retest_context_table(connection)
    validate_retest_context_table(connection)
    connection.execute(
        "INSERT INTO derived_build_metrics VALUES ('retest_context', ?)",
        [perf_counter() - stage_started],
    )
    confluence_quality = create_confluence_tables(connection)
    connection.executemany(
        "INSERT INTO derived_build_metrics VALUES (?, ?)",
        [
            ("confluence_sweep", confluence_quality["sweep_duration_seconds"]),
            (
                "confluence_persistence",
                confluence_quality["persistence_duration_seconds"],
            ),
        ],
    )
    _create_feature_snapshots(connection)
    _create_entry_evidence(connection)
    _create_training_matrix(connection, target_family, research_feature_set_id)

    table_names = [Path(filename).stem for filename in RUN_FILES] + [
        "signal_retest_context",
        "confluence_members",
        "confluence_snapshots",
        "training_matrix",
    ]
    return {
        table_name: int(connection.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0])
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
    parser.add_argument("--runs-root", required=True, help="Folder containing V9 run folders.")
    parser.add_argument(
        "--run-id",
        action="append",
        required=True,
        help="Run folder name. Repeat to assemble multiple runs.",
    )
    parser.add_argument("--dataset-id", default="", help="Required unless --validate-only is used.")
    parser.add_argument("--output-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--schema-version", type=int, default=SUPPORTED_SCHEMA_VERSION)
    parser.add_argument("--feature-set-id", default=SUPPORTED_FEATURE_SET_ID)
    parser.add_argument("--research-feature-set-id", default="")
    parser.add_argument(
        "--target-family",
        choices=DATASET_TARGET_FAMILIES,
        default="broker_outcome",
    )
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        feature_columns = feature_columns_for_set(args.feature_set_id)
        selected_feature_columns = research_feature_columns_for_set(
            args.research_feature_set_id
        )
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
                "schema V9 validation ok | "
                f"runs={len(validations)} | attempts={totals[SIGNAL_ATTEMPTS_FILE]} | "
                f"features={totals[SIGNAL_FEATURES_FILE]} | "
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
                args.target_family,
                args.schema_version,
                feature_columns,
                args.research_feature_set_id,
            )
            output_files = write_parquet_outputs(connection, output_dir, counts)
            quality = build_quality_payload(
                connection,
                validations,
                counts,
                args.target_family,
                selected_feature_columns,
                output_dir,
            )
            write_dataset_manifest(
                output_dir,
                args.dataset_id,
                validations,
                counts,
                output_files,
                args.target_family,
                args.schema_version,
                args.feature_set_id,
                selected_feature_columns,
                args.research_feature_set_id,
            )
            write_quality_json(output_dir, quality)
            write_dataset_report(output_dir, args.dataset_id, quality)
        finally:
            connection.close()
    except (
        SchemaValidationError,
        DerivedResearchError,
        RuntimeError,
        ValueError,
        duckdb.Error,
    ) as exc:
        parser.exit(1, f"pivot V9 dataset build failed: {exc}\n")

    print(
        "pivot V9 dataset build ok | "
        f"dataset={args.dataset_id} | target={args.target_family} | "
        f"rows={counts['training_matrix']} | research_features={args.research_feature_set_id or 'base'} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
