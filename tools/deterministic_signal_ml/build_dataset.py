"""Build local deterministic signal datasets from Phase 1 TSV exports."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import duckdb

from schema_contract import (
    FEATURE_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    OUTCOME_COLUMNS,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
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


def _insert_features_sql(path: Path) -> str:
    source = _read_tsv_sql(path, FEATURE_COLUMNS)
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
  CAST(strategy_id AS INTEGER) AS strategy_id,
  strategy_label,
  direction,
  strptime(entry_time, '{TIMESTAMP_FORMAT}') AS entry_time,
  strptime(source_time, '{TIMESTAMP_FORMAT}') AS source_time,
  source_type,
  source_structure_type,
  opposite_structure_type,
  same_previous_structure_type,
  CAST(macro_h1_live_dir AS INTEGER) AS macro_h1_live_dir,
  CAST(macro_h4_live_dir AS INTEGER) AS macro_h4_live_dir,
  CAST(macro_d1_live_dir AS INTEGER) AS macro_d1_live_dir,
  CAST(strategy_delay_period AS INTEGER) AS strategy_delay_period,
  CAST(confirmation_timeframe_minutes AS INTEGER) AS confirmation_timeframe_minutes,
  CAST(entry_direction_macro_alignment AS INTEGER) AS entry_direction_macro_alignment,
  CAST(macro_alignment_score AS INTEGER) AS macro_alignment_score,
  CAST(prev_body_ratio AS DOUBLE) AS prev_body_ratio,
  CAST(prev_upper_wick_ratio AS DOUBLE) AS prev_upper_wick_ratio,
  CAST(prev_lower_wick_ratio AS DOUBLE) AS prev_lower_wick_ratio,
  CAST(prev_close_location AS DOUBLE) AS prev_close_location,
  prev_candle_dir,
  CAST(sl_fib_raw AS DOUBLE) AS sl_fib_raw,
  sl_fib_band,
  CAST(entry_fib_raw AS DOUBLE) AS entry_fib_raw,
  entry_fib_band,
  CAST(low_chain_score_3 AS INTEGER) AS low_chain_score_3,
  CAST(low_chain_score_5 AS INTEGER) AS low_chain_score_5,
  CAST(low_chain_score_10 AS INTEGER) AS low_chain_score_10,
  CAST(high_chain_score_3 AS INTEGER) AS high_chain_score_3,
  CAST(high_chain_score_5 AS INTEGER) AS high_chain_score_5,
  CAST(high_chain_score_10 AS INTEGER) AS high_chain_score_10
FROM {source}
"""


def _insert_outcomes_sql(path: Path) -> str:
    source = _read_tsv_sql(path, OUTCOME_COLUMNS)
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
  CAST(net_profit AS DOUBLE) AS net_profit
FROM {source}
"""


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations,
) -> dict[str, int]:
    required_feature_clause = " AND\n  ".join(
        f"f.{column} IS NOT NULL" for column in MODEL_FEATURE_COLUMNS
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
  strategy_id INTEGER,
  strategy_label VARCHAR,
  direction VARCHAR,
  entry_time TIMESTAMP,
  source_time TIMESTAMP,
  source_type VARCHAR,
  source_structure_type VARCHAR,
  opposite_structure_type VARCHAR,
  same_previous_structure_type VARCHAR,
  macro_h1_live_dir INTEGER,
  macro_h4_live_dir INTEGER,
  macro_d1_live_dir INTEGER,
  strategy_delay_period INTEGER,
  confirmation_timeframe_minutes INTEGER,
  entry_direction_macro_alignment INTEGER,
  macro_alignment_score INTEGER,
  prev_body_ratio DOUBLE,
  prev_upper_wick_ratio DOUBLE,
  prev_lower_wick_ratio DOUBLE,
  prev_close_location DOUBLE,
  prev_candle_dir VARCHAR,
  sl_fib_raw DOUBLE,
  sl_fib_band VARCHAR,
  entry_fib_raw DOUBLE,
  entry_fib_band VARCHAR,
  low_chain_score_3 INTEGER,
  low_chain_score_5 INTEGER,
  low_chain_score_10 INTEGER,
  high_chain_score_3 INTEGER,
  high_chain_score_5 INTEGER,
  high_chain_score_10 INTEGER
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
  net_profit DOUBLE
)
"""
    )

    for validation in validations:
        connection.execute(_insert_features_sql(validation.run_path / SIGNAL_FEATURES_FILE))
        connection.execute(_insert_outcomes_sql(validation.run_path / SIGNAL_OUTCOMES_FILE))

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
  f.strategy_id,
  f.strategy_label,
  f.direction,
  f.entry_time,
  f.source_time,
  f.source_type,
  f.source_structure_type,
  f.opposite_structure_type,
  f.same_previous_structure_type,
  f.macro_h1_live_dir,
  f.macro_h4_live_dir,
  f.macro_d1_live_dir,
  f.strategy_delay_period,
  f.confirmation_timeframe_minutes,
  f.entry_direction_macro_alignment,
  f.macro_alignment_score,
  f.prev_body_ratio,
  f.prev_upper_wick_ratio,
  f.prev_lower_wick_ratio,
  f.prev_close_location,
  f.prev_candle_dir,
  f.sl_fib_raw,
  f.sl_fib_band,
  f.entry_fib_raw,
  f.entry_fib_band,
  f.low_chain_score_3,
  f.low_chain_score_5,
  f.low_chain_score_10,
  f.high_chain_score_3,
  f.high_chain_score_5,
  f.high_chain_score_10,
  o.terminal_time,
  o.terminal_reason,
  o.profit_r,
  o.duration_seconds,
  o.duration_m1_bars,
  o.entry_price,
  o.close_price,
  o.net_profit,
  CASE WHEN o.net_profit > 0 THEN 1 ELSE 0 END AS target_is_win,
  o.profit_r AS target_profit_r,
  o.terminal_reason AS target_terminal_reason
FROM features f
INNER JOIN outcomes o ON o.signal_id = f.signal_id
WHERE
  {required_feature_clause}
ORDER BY f.entry_time, f.signal_id
"""
    )

    feature_count = connection.execute("SELECT COUNT(*) FROM features").fetchone()[0]
    outcome_count = connection.execute("SELECT COUNT(*) FROM outcomes").fetchone()[0]
    matrix_count = connection.execute("SELECT COUNT(*) FROM training_matrix").fetchone()[0]
    return {
        "features": int(feature_count),
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
) -> dict[str, str]:
    output_files = {
        "features": str(output_dir / "features.parquet"),
        "outcomes": str(output_dir / "outcomes.parquet"),
        "training_matrix": str(output_dir / "training_matrix.parquet"),
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

    try:
        validations = validate_phase1_runs(
            Path(args.runs_root),
            args.run_id,
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
    counts = create_dataset_tables(connection, validations)
    print(
        "assembly ok | "
        f"features={counts['features']} | "
        f"outcomes={counts['outcomes']} | "
        f"training_matrix={counts['training_matrix']}"
    )
    try:
        output_dir = prepare_output_dir(Path(args.output_root), args.dataset_id, args.overwrite)
        output_files = write_parquet_outputs(connection, output_dir)
        quality_payload = build_quality_payload(connection, validations, counts)
        write_dataset_manifest(output_dir, args.dataset_id, validations, counts, output_files)
        write_quality_json(output_dir, quality_payload)
        write_dataset_report(output_dir, args.dataset_id, quality_payload)
    except RuntimeError as exc:
        parser.exit(1, f"build failed: {exc}\n")

    print(f"dataset written | path={output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
