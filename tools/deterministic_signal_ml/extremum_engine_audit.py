"""Build compact human-readable Fibonacci depth audits for schema v7 datasets."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable

import duckdb


DEFAULT_FIB_LEVELS = (0.0, 23.6, 38.2, 50.0, 61.8, 78.6, 100.0, 123.6, 138.2, 161.8, 178.6, 200.0)
DEFAULT_RANGE_BUCKETS = (250.0, 500.0, 1000.0, 2000.0)
MIN_STRONG_ROWS = 30
MIN_STRONG_CYCLES = 10


def nearest_fibonacci(depth_percent: float, levels: Iterable[float] = DEFAULT_FIB_LEVELS) -> tuple[float, float]:
    candidates = tuple(float(level) for level in levels)
    if not candidates:
        raise ValueError("At least one Fibonacci level is required")
    nearest = min(candidates, key=lambda level: (abs(depth_percent - level), level))
    return nearest, abs(depth_percent - nearest)


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


def _fetch_dicts(connection: duckdb.DuckDBPyConnection, sql: str) -> list[dict[str, Any]]:
    cursor = connection.execute(sql)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def _range_bucket_sql(column: str, buckets: tuple[float, ...]) -> str:
    clauses: list[str] = []
    lower = 0.0
    for upper in buckets:
        clauses.append(f"WHEN {column} < {upper} THEN '{lower:g}_{upper:g}'")
        lower = upper
    return "CASE " + " ".join(clauses) + f" ELSE 'gte_{lower:g}' END"


def _write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def _markdown_table(rows: list[dict[str, Any]], columns: tuple[str, ...], limit: int = 20) -> list[str]:
    if not rows:
        return ["No rows."]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join(["---"] * len(columns)) + " |",
    ]
    for row in rows[:limit]:
        lines.append("| " + " | ".join(str(row.get(column, "")) for column in columns) + " |")
    return lines


def build_audit(
    dataset_dir: Path,
    output_dir: Path,
    audit_id: str,
    fib_levels: tuple[float, ...] = DEFAULT_FIB_LEVELS,
    range_buckets: tuple[float, ...] = DEFAULT_RANGE_BUCKETS,
) -> dict[str, Any]:
    required = ("engine_cycles.parquet", "engine_revisions.parquet", "engine_attempts.parquet", "training_matrix.parquet")
    missing = [filename for filename in required if not (dataset_dir / filename).exists()]
    if missing:
        raise RuntimeError("Missing schema v7 dataset files: " + ", ".join(missing))

    connection = duckdb.connect(":memory:")
    for table in ("engine_cycles", "engine_revisions", "engine_attempts", "training_matrix"):
        connection.execute(
            f"CREATE VIEW {table} AS SELECT * FROM read_parquet({_sql_literal(dataset_dir / f'{table}.parquet')})"
        )
    connection.execute("CREATE TABLE fib_levels(level DOUBLE)")
    connection.executemany("INSERT INTO fib_levels VALUES (?)", [(level,) for level in fib_levels])
    range_bucket = _range_bucket_sql("a.reference_range_points", range_buckets)

    connection.execute(
        f"""
CREATE TABLE enriched_attempts AS
SELECT * EXCLUDE (fib_rank) FROM (
  SELECT
    a.*,
    r.extremum_type,
    r.structure_0,
    r.structure_1,
    r.structure_2,
    r.session_id,
    f.level AS nearest_fib_level,
    ROUND(ABS(a.candidate_depth_percent - f.level), 6) AS fib_distance_percent,
    {range_bucket} AS range_bucket,
    ROW_NUMBER() OVER (
      PARTITION BY a.run_id, a.attempt_id
      ORDER BY ABS(a.candidate_depth_percent - f.level), f.level
    ) AS fib_rank
  FROM engine_attempts a
  JOIN engine_revisions r ON r.run_id = a.run_id AND r.revision_id = a.revision_id
  CROSS JOIN fib_levels f
) WHERE fib_rank = 1
"""
    )
    connection.execute(
        """
CREATE TABLE audit_lanes AS
SELECT
  run_id, symbol, engine_timeframe, extremum_cycle_id, revision_id, attempt_id,
  attempt_created_time, direction, extremum_type, cycle_attempt_index,
  revision_attempt_index, candidate_depth_percent, nearest_fib_level,
  fib_distance_percent, reference_range_points, range_bucket,
  trigger_reached, broker_entry_confirmed, broker_close_confirmed,
  simulated_path_status AS terminal_status, simulated_profit_r AS profit_r,
  simulated_max_favorable_r AS max_favorable_r,
  simulated_max_adverse_r AS max_adverse_r,
  'ENGINE_SIMULATION' AS outcome_source
FROM enriched_attempts
UNION ALL
SELECT
  a.run_id, a.symbol, a.engine_timeframe, a.extremum_cycle_id, a.revision_id,
  a.attempt_id, a.attempt_created_time, a.direction, a.extremum_type,
  a.cycle_attempt_index, a.revision_attempt_index, a.candidate_depth_percent,
  a.nearest_fib_level, a.fib_distance_percent, a.reference_range_points,
  a.range_bucket, a.trigger_reached, a.broker_entry_confirmed,
  a.broker_close_confirmed, t.target_terminal_reason AS terminal_status,
  t.target_profit_r AS profit_r, NULL::DOUBLE AS max_favorable_r,
  NULL::DOUBLE AS max_adverse_r, 'BROKER_CONFIRMED' AS outcome_source
FROM enriched_attempts a
JOIN training_matrix t ON t.run_id = a.run_id AND t.extremum_attempt_id = a.attempt_id
"""
    )

    attempt_metrics = _fetch_dicts(
        connection,
        """
SELECT
  engine_timeframe, direction, extremum_type, cycle_attempt_index,
  nearest_fib_level, range_bucket, outcome_source,
  COUNT(*) AS attempt_count,
  COUNT(DISTINCT extremum_cycle_id) AS distinct_cycle_count,
  AVG(trigger_reached) AS trigger_rate,
  AVG(broker_entry_confirmed) AS broker_entry_rate,
  AVG(CASE WHEN profit_r IS NOT NULL THEN CASE WHEN profit_r > 0 THEN 1.0 ELSE 0.0 END END) AS win_rate,
  AVG(profit_r) AS avg_profit_r,
  MEDIAN(profit_r) AS median_profit_r,
  SUM(profit_r) AS total_profit_r,
  SUM(CASE WHEN profit_r > 0 THEN profit_r ELSE 0 END) /
    NULLIF(ABS(SUM(CASE WHEN profit_r < 0 THEN profit_r ELSE 0 END)), 0) AS profit_factor,
  AVG(max_favorable_r) AS avg_max_favorable_r,
  AVG(max_adverse_r) AS avg_max_adverse_r,
  SUM(CASE WHEN terminal_status IN ('CENSORED', 'NOT_TRIGGERED') THEN 1 ELSE 0 END) AS censored_rows,
  CASE WHEN COUNT(*) >= 30 AND COUNT(DISTINCT extremum_cycle_id) >= 10
       THEN 'SUPPORTED' ELSE 'SPARSE' END AS support_status
FROM audit_lanes
GROUP BY ALL
ORDER BY outcome_source, distinct_cycle_count DESC, attempt_count DESC,
         cycle_attempt_index, nearest_fib_level, range_bucket
""",
    )
    cycle_sequences = _fetch_dicts(
        connection,
        """
SELECT
  l.run_id, l.symbol, l.engine_timeframe, l.extremum_cycle_id, c.extremum_type,
  c.cycle_status, c.revision_count, c.attempt_count, l.outcome_source,
  STRING_AGG(
    'attempt=' || l.cycle_attempt_index ||
    ',depth=' || ROUND(l.candidate_depth_percent, 2) ||
    ',fib=' || ROUND(l.nearest_fib_level, 2) ||
    ',status=' || l.terminal_status ||
    ',r=' || COALESCE(ROUND(l.profit_r, 4)::VARCHAR, 'NA'),
    ' -> ' ORDER BY l.cycle_attempt_index
  ) AS attempt_sequence,
  SUM(l.profit_r) AS cycle_total_profit_r,
  COUNT(*) AS lane_attempt_count
FROM audit_lanes l
JOIN engine_cycles c USING (run_id, extremum_cycle_id)
GROUP BY ALL
ORDER BY l.run_id, l.extremum_cycle_id, l.outcome_source
""",
    )
    stability = _fetch_dicts(
        connection,
        """
SELECT
  STRFTIME(attempt_created_time, '%Y-%m') AS period,
  outcome_source, cycle_attempt_index, nearest_fib_level, range_bucket,
  COUNT(*) AS attempt_count,
  COUNT(DISTINCT extremum_cycle_id) AS distinct_cycle_count,
  AVG(profit_r) AS avg_profit_r,
  SUM(profit_r) AS total_profit_r,
  AVG(CASE WHEN profit_r IS NOT NULL THEN CASE WHEN profit_r > 0 THEN 1.0 ELSE 0.0 END END) AS win_rate
FROM audit_lanes
GROUP BY ALL
ORDER BY period, outcome_source, cycle_attempt_index, nearest_fib_level, range_bucket
""",
    )
    proximity = _fetch_dicts(
        connection,
        """
SELECT attempt_id, candidate_depth_percent, nearest_fib_level, fib_distance_percent,
       reference_range_points, range_bucket
FROM enriched_attempts
ORDER BY run_id, cycle_attempt_index
""",
    )

    output_dir.mkdir(parents=True, exist_ok=False)
    _write_tsv(output_dir / "attempt_profitability.tsv", attempt_metrics)
    _write_tsv(output_dir / "cycle_sequences.tsv", cycle_sequences)
    _write_tsv(output_dir / "stability.tsv", stability)
    _write_tsv(output_dir / "fibonacci_proximity.tsv", proximity)
    metadata = {
        "audit_id": audit_id,
        "dataset_id": dataset_dir.name,
        "schema_version": 7,
        "created_at": datetime.now(UTC).isoformat(),
        "outcome_lanes": ["ENGINE_SIMULATION", "BROKER_CONFIRMED"],
        "fibonacci_levels": list(fib_levels),
        "range_bucket_upper_bounds_points": list(range_buckets),
        "support_policy": {"min_rows": MIN_STRONG_ROWS, "min_distinct_cycles": MIN_STRONG_CYCLES},
        "row_counts": {
            "attempt_profitability": len(attempt_metrics),
            "cycle_sequences": len(cycle_sequences),
            "stability": len(stability),
            "fibonacci_proximity": len(proximity),
        },
    }
    (output_dir / "audit_metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True), encoding="utf-8"
    )
    lines = [
        f"# Extremum Engine Audit: {audit_id}", "",
        f"Dataset: `{dataset_dir.name}`", "",
        "Simulated and broker-confirmed profitability are separate lanes.", "",
        "## Executive Attempt View", "",
    ]
    lines.extend(
        _markdown_table(
            attempt_metrics,
            (
                "outcome_source", "cycle_attempt_index", "nearest_fib_level",
                "range_bucket", "attempt_count", "distinct_cycle_count",
                "win_rate", "avg_profit_r", "total_profit_r", "support_status",
            ),
        )
    )
    lines.extend(["", "## Cycle Sequences", ""])
    lines.extend(
        _markdown_table(
            cycle_sequences,
            ("extremum_cycle_id", "outcome_source", "attempt_sequence", "cycle_total_profit_r", "cycle_status"),
        )
    )
    lines.extend(["", "## Fibonacci Proximity", ""])
    lines.extend(
        _markdown_table(
            proximity,
            ("attempt_id", "candidate_depth_percent", "nearest_fib_level", "fib_distance_percent", "reference_range_points", "range_bucket"),
        )
    )
    (output_dir / "audit_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return metadata


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-id", required=True)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--dataset-root", default="artifacts/datasets")
    parser.add_argument("--audit-root", default="artifacts/audits")
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    dataset_dir = Path(args.dataset_root) / args.dataset_id
    output_dir = Path(args.audit_root) / args.audit_id
    if output_dir.exists():
        if not args.overwrite:
            raise SystemExit(f"Audit output exists; use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    metadata = build_audit(dataset_dir, output_dir, args.audit_id)
    print(
        "audit written | "
        f"path={output_dir} | "
        f"attempt_groups={metadata['row_counts']['attempt_profitability']} | "
        f"cycle_rows={metadata['row_counts']['cycle_sequences']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
