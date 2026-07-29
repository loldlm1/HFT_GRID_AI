"""Build deterministic pivot-window, admission, trailing, and outcome audits."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from model_config import DEFAULT_DATASET_ROOT


DEFAULT_AUDIT_ROOT = "artifacts/audits"
REQUIRED_TABLES = (
    "pivot_windows",
    "pivot_levels",
    "signal_attempts",
    "signal_features",
    "execution_checks",
    "trailing_events",
    "signal_outcomes",
    "training_matrix",
)


class PivotAuditError(RuntimeError):
    """Raised when a dataset cannot produce a trustworthy audit."""


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    sql: str,
) -> list[dict[str, Any]]:
    result = connection.execute(sql)
    columns = [column[0] for column in result.description]
    return [dict(zip(columns, row)) for row in result.fetchall()]


def _write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    columns = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    column: ""
                    if row.get(column) is None
                    else str(row.get(column)).lower()
                    if isinstance(row.get(column), bool)
                    else row.get(column)
                    for column in columns
                }
            )


def _load_dataset(connection: duckdb.DuckDBPyConnection, dataset_dir: Path) -> None:
    for table_name in REQUIRED_TABLES:
        path = dataset_dir / f"{table_name}.parquet"
        if not path.is_file():
            raise PivotAuditError(f"Missing required dataset table: {path}")
        connection.execute(
            f"CREATE VIEW {table_name} AS "
            f"SELECT * FROM read_parquet({_sql_literal(path.resolve().as_posix())})"
        )


def _validate_dataset_integrity(connection: duckdb.DuckDBPyConnection) -> None:
    duplicate_attempts = connection.execute(
        """
SELECT COUNT(*)
FROM (
  SELECT run_id, signal_id, COUNT(*) AS rows
  FROM signal_attempts
  GROUP BY 1, 2
  HAVING COUNT(*) <> 1
)
"""
    ).fetchone()[0]
    if duplicate_attempts:
        raise PivotAuditError("Dataset contains duplicate signal attempts")

    bad_contexts = connection.execute(
        """
SELECT COUNT(*)
FROM (
  SELECT run_id, signal_id,
         COUNT(*) AS rows,
         COUNT(DISTINCT context_timeframe) AS contexts
  FROM signal_features
  GROUP BY 1, 2
  HAVING rows <> 6 OR contexts <> 6
)
"""
    ).fetchone()[0]
    if bad_contexts:
        raise PivotAuditError("Dataset contains incomplete or duplicate feature contexts")

    orphan_outcomes = connection.execute(
        """
SELECT COUNT(*)
FROM signal_outcomes o
LEFT JOIN signal_attempts a USING (run_id, config_id, signal_id, window_id)
WHERE a.signal_id IS NULL
"""
    ).fetchone()[0]
    if orphan_outcomes:
        raise PivotAuditError("Dataset contains orphan broker outcomes")

    outcomes_without_fill = connection.execute(
        """
SELECT COUNT(*)
FROM signal_outcomes o
WHERE NOT EXISTS (
  SELECT 1
  FROM execution_checks c
  WHERE c.run_id = o.run_id
    AND c.config_id = o.config_id
    AND c.signal_id = o.signal_id
    AND c.broker_entry_confirmed
    AND c.position_ticket = o.position_ticket
    AND c.position_identifier = o.position_identifier
)
"""
    ).fetchone()[0]
    if outcomes_without_fill:
        raise PivotAuditError("Dataset contains an outcome without matching fill evidence")


def _render_report(audit_id: str, metadata: dict[str, Any]) -> str:
    counts = metadata["row_counts"]
    return "\n".join(
        [
            f"# Pivot Fractal Audit: {audit_id}",
            "",
            "Approval: `OFFLINE_RESEARCH_ONLY`",
            "",
            f"- Windows: `{counts['windows']}`",
            f"- Attempts: `{counts['attempts']}`",
            f"- Denied attempts: `{counts['denied_attempts']}`",
            f"- Filled signals: `{counts['filled_signals']}`",
            f"- Trailing events: `{counts['trailing_events']}`",
            f"- Broker outcomes: `{counts['broker_outcomes']}`",
            "",
            "Structural break-even events are reported separately from realized broker profit.",
            "No simulated path or runtime approval is created by this audit.",
        ]
    ) + "\n"


def build_audit(
    dataset_dir: Path,
    output_dir: Path,
    audit_id: str,
) -> dict[str, Any]:
    dataset_dir = dataset_dir.resolve()
    if not dataset_dir.is_dir():
        raise PivotAuditError(f"Dataset folder does not exist: {dataset_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)
    connection = duckdb.connect(":memory:")
    try:
        _load_dataset(connection, dataset_dir)
        _validate_dataset_integrity(connection)

        window_validity = _fetch_dicts(
            connection,
            """
SELECT pivot_timeframe, window_state, terminal_status,
       COUNT(*) AS windows,
       AVG(source_range) AS mean_source_range
FROM pivot_windows
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
""",
        )
        level_direction_matrix = _fetch_dicts(
            connection,
            """
WITH fill AS (
  SELECT run_id, signal_id, BOOL_OR(broker_entry_confirmed) AS filled
  FROM execution_checks
  GROUP BY 1, 2
)
SELECT a.pivot_timeframe, a.level_id, a.direction,
       COUNT(*) AS attempts,
       SUM(CASE WHEN a.attempt_status <> 'SENT' THEN 1 ELSE 0 END) AS denied_attempts,
       SUM(CASE WHEN COALESCE(f.filled, FALSE) THEN 1 ELSE 0 END) AS filled_signals,
       SUM(CASE WHEN o.signal_id IS NOT NULL THEN 1 ELSE 0 END) AS broker_outcomes,
       AVG(o.realized_profit) AS mean_realized_profit
FROM signal_attempts a
LEFT JOIN fill f USING (run_id, signal_id)
LEFT JOIN signal_outcomes o USING (run_id, config_id, signal_id)
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
""",
        )
        confluence = _fetch_dicts(
            connection,
            """
SELECT run_id, symbol, trigger_broker_time,
       COUNT(*) AS attempts,
       COUNT(DISTINCT pivot_timeframe) AS pivot_timeframes,
       COUNT(DISTINCT level_id) AS levels,
       string_agg(DISTINCT pivot_timeframe, ',' ORDER BY pivot_timeframe) AS timeframe_set
FROM signal_attempts
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
ORDER BY trigger_broker_time, run_id, symbol
""",
        )
        denials = _fetch_dicts(
            connection,
            """
SELECT pivot_timeframe, level_id, direction, route_status,
       block_source, block_reason, COUNT(*) AS attempts
FROM signal_attempts
WHERE attempt_status <> 'SENT'
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY attempts DESC, pivot_timeframe, level_id, direction
""",
        )
        milestones = _fetch_dicts(
            connection,
            """
SELECT t.run_id, t.signal_id, a.pivot_timeframe, a.level_id, a.direction,
       t.event_sequence, t.milestone_level, t.event_status,
       t.previous_confirmed_stop, t.desired_stop, t.confirmed_stop,
       abs(t.confirmed_stop - a.intended_entry_price) <= 1e-8 AS structural_break_even,
       o.terminal_reason, o.realized_profit
FROM trailing_events t
JOIN signal_attempts a USING (run_id, config_id, signal_id, window_id)
LEFT JOIN signal_outcomes o USING (run_id, config_id, signal_id)
ORDER BY t.event_broker_time, t.run_id, t.signal_id, t.event_sequence
""",
        )
        outcomes = _fetch_dicts(
            connection,
            """
SELECT terminal_reason,
       COUNT(*) AS outcomes,
       SUM(CASE WHEN realized_profit > 0 THEN 1 ELSE 0 END) AS profitable_outcomes,
       AVG(realized_profit) AS mean_realized_profit,
       SUM(realized_profit) AS total_realized_profit,
       AVG(duration_seconds) AS mean_duration_seconds
FROM signal_outcomes
GROUP BY 1
ORDER BY 1
""",
        )
        execution_quality = _fetch_dicts(
            connection,
            """
WITH fill AS (
  SELECT run_id, config_id, signal_id,
         MAX(CASE WHEN broker_entry_confirmed THEN broker_entry_price END) AS broker_entry_price
  FROM execution_checks
  GROUP BY 1, 2, 3
)
SELECT a.run_id, a.signal_id, a.pivot_timeframe, a.level_id, a.direction,
       a.spread_points, a.intended_entry_price, f.broker_entry_price,
       CASE
         WHEN a.direction = 'BUY' THEN f.broker_entry_price - a.intended_entry_price
         ELSE a.intended_entry_price - f.broker_entry_price
       END AS adverse_entry_slippage,
       o.close_price, o.realized_profit, o.duration_seconds
FROM signal_attempts a
JOIN fill f USING (run_id, config_id, signal_id)
LEFT JOIN signal_outcomes o USING (run_id, config_id, signal_id)
WHERE f.broker_entry_price IS NOT NULL
ORDER BY a.trigger_broker_time, a.run_id, a.signal_id
""",
        )

        outputs = {
            "window_validity.tsv": window_validity,
            "level_direction_matrix.tsv": level_direction_matrix,
            "confluence.tsv": confluence,
            "admission_denials.tsv": denials,
            "milestone_progression.tsv": milestones,
            "broker_outcomes.tsv": outcomes,
            "execution_quality.tsv": execution_quality,
        }
        for filename, rows in outputs.items():
            _write_tsv(output_dir / filename, rows)

        row_counts = {
            "windows": int(connection.execute("SELECT COUNT(*) FROM pivot_windows").fetchone()[0]),
            "attempts": int(connection.execute("SELECT COUNT(*) FROM signal_attempts").fetchone()[0]),
            "denied_attempts": int(
                connection.execute(
                    "SELECT COUNT(*) FROM signal_attempts WHERE attempt_status <> 'SENT'"
                ).fetchone()[0]
            ),
            "filled_signals": int(
                connection.execute(
                    "SELECT COUNT(DISTINCT (run_id, signal_id)) FROM execution_checks "
                    "WHERE broker_entry_confirmed"
                ).fetchone()[0]
            ),
            "trailing_events": int(
                connection.execute("SELECT COUNT(*) FROM trailing_events").fetchone()[0]
            ),
            "broker_outcomes": int(
                connection.execute("SELECT COUNT(*) FROM signal_outcomes").fetchone()[0]
            ),
        }
    finally:
        connection.close()

    metadata = {
        "audit_id": audit_id,
        "generated_at": datetime.now(UTC).isoformat(),
        "dataset_path": str(dataset_dir),
        "row_counts": row_counts,
        "output_files": sorted(outputs),
        "outcome_policy": "broker_confirmed_only",
        "structural_break_even_is_monetary_break_even": False,
        "approval_state": "OFFLINE_RESEARCH_ONLY",
    }
    (output_dir / "audit_metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    (output_dir / "audit_report.md").write_text(
        _render_report(audit_id, metadata),
        encoding="utf-8",
    )
    return metadata


def _prepare_output(root: Path, audit_id: str, overwrite: bool) -> Path:
    if not audit_id or Path(audit_id).name != audit_id or audit_id in (".", ".."):
        raise PivotAuditError(f"Invalid audit ID: {audit_id}")
    root = root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    output_dir = (root / audit_id).resolve()
    if output_dir.parent != root:
        raise PivotAuditError(f"Refusing audit output outside audit root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise PivotAuditError(f"Audit output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    return output_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id")
    dataset_group.add_argument("--dataset-path")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--audit-root", default=DEFAULT_AUDIT_ROOT)
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    dataset_dir = (
        Path(args.dataset_path)
        if args.dataset_path
        else Path(args.dataset_root) / str(args.dataset_id)
    )
    try:
        output_dir = _prepare_output(Path(args.audit_root), args.audit_id, args.overwrite)
        metadata = build_audit(dataset_dir, output_dir, args.audit_id)
    except (PivotAuditError, RuntimeError, duckdb.Error) as exc:
        parser.exit(1, f"pivot audit failed: {exc}\n")
    print(
        "pivot audit ok | "
        f"audit={args.audit_id} | attempts={metadata['row_counts']['attempts']} | "
        f"outcomes={metadata['row_counts']['broker_outcomes']} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
