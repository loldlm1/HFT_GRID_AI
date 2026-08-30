"""Typed loading boundary for strict Pivot Fractal V13 research runs."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import duckdb

from schema_contract import (
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_GROUPS,
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
H1_LANE_LONG_TABLE = "h1_lane_long"
H1_LANE_WIDE_TABLE = "h1_lane_wide"
ELIGIBLE_H1_TRIALS_TABLE = "eligible_h1_trials"
DEEP_PARENT_LONG_TABLE = "deep_parent_long"
ELIGIBLE_DEEP_TRIALS_TABLE = "eligible_deep_trials"
BROKER_VIRTUAL_CALIBRATION_TABLE = "broker_virtual_calibration"

# Transitional aliases keep generic report imports stable while active V12
# policy-chain semantics are intentionally absent.
ORIGIN_MATRIX_LONG_TABLE = H1_LANE_LONG_TABLE
INITIAL_MATRIX_WIDE_TABLE = H1_LANE_WIDE_TABLE
ELIGIBLE_VIRTUAL_TRIALS_TABLE = ELIGIBLE_H1_TRIALS_TABLE
POLICY_CHAINS_TABLE = "h1_lane_outcomes"

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


def create_dataset_tables(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    schema_version: int = SUPPORTED_SCHEMA_VERSION,
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS,
) -> dict[str, int]:
    if schema_version != SUPPORTED_SCHEMA_VERSION:
        raise RuntimeError("Only schema 13 dataset assembly is active")
    if tuple(feature_columns) != MODEL_FEATURE_COLUMNS:
        raise RuntimeError("Schema V13 requires an explicit evidence-grain feature set")
    create_raw_tables(connection, validations)
    raise RuntimeError("V13 derived dataset assembly is intentionally deferred to Sprint 6")


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
            create_dataset_tables(
                connection,
                validations,
                schema_version=args.schema_version,
                feature_columns=feature_columns,
            )
        finally:
            connection.close()
        print(f"dataset_id={args.dataset_id} output={output_dir}")
        return 0
    except (RuntimeError, ValueError, SchemaValidationError, duckdb.Error) as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
