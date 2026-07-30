"""Query exact unordered first-touch confluence patterns from offline Parquet facts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import duckdb

from model_config import DEFAULT_DATASET_ROOT
from retest_confluence import confluence_member_token


TOKEN_PATTERN = re.compile(
    r"^(BUY|SELL):(PERIOD_(?:M15|M30|H1|H4|D1)):(S3|S2|S1|PP|R1|R2|R3)$"
)
REQUIRED_TABLES = ("confluence_members", "confluence_snapshots", "signal_outcomes")


class ConfluenceQueryError(RuntimeError):
    """Raised when a requested pattern or dataset cannot be trusted."""


def parse_member_token(token: str) -> str:
    """Validate and normalize one DIRECTION:TIMEFRAME:LEVEL token."""
    if not isinstance(token, str) or TOKEN_PATTERN.fullmatch(token) is None:
        raise ConfluenceQueryError(f"Invalid confluence member token: {token!r}")
    direction, timeframe, level_id = token.split(":")
    return confluence_member_token(direction, timeframe, level_id)


def normalize_member_tokens(tokens: list[str] | tuple[str, ...]) -> tuple[str, ...]:
    normalized = sorted({parse_member_token(token) for token in tokens})
    if not normalized:
        raise ConfluenceQueryError("At least one confluence member is required")
    return tuple(normalized)


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _validate_id(value: str, label: str) -> None:
    if not value or Path(value).name != value or value in (".", ".."):
        raise ConfluenceQueryError(f"Invalid {label}: {value!r}")


def _load_dataset(connection: duckdb.DuckDBPyConnection, dataset_dir: Path) -> None:
    dataset_dir = dataset_dir.resolve()
    if not dataset_dir.is_dir():
        raise ConfluenceQueryError(f"Dataset folder does not exist: {dataset_dir}")
    for table_name in REQUIRED_TABLES:
        path = dataset_dir / f"{table_name}.parquet"
        if not path.is_file():
            raise ConfluenceQueryError(f"Missing required dataset table: {path}")
        connection.execute(
            f"CREATE VIEW {table_name} AS SELECT * FROM read_parquet({_sql_literal(path)})"
        )


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    sql: str,
    parameters: list[Any] | tuple[Any, ...] = (),
) -> list[dict[str, Any]]:
    relation = connection.execute(sql, parameters)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def query_pattern(
    connection: duckdb.DuckDBPyConnection,
    member_tokens: list[str] | tuple[str, ...],
    *,
    anchor_member: str | None = None,
    minimum_group_support: int = 0,
) -> list[dict[str, Any]]:
    """Return anchors containing an exact unordered token set and causal overlap."""
    tokens = normalize_member_tokens(member_tokens)
    if minimum_group_support < 0:
        raise ConfluenceQueryError("minimum_group_support cannot be negative")
    normalized_anchor = parse_member_token(anchor_member) if anchor_member else None

    connection.execute("CREATE TEMP TABLE requested_confluence_tokens (token VARCHAR PRIMARY KEY)")
    connection.executemany(
        "INSERT INTO requested_confluence_tokens VALUES (?)",
        [(token,) for token in tokens],
    )
    anchor_filter = ""
    parameters: list[Any] = []
    if normalized_anchor is not None:
        anchor_filter = """
  AND EXISTS (
    SELECT 1
    FROM confluence_members anchor_member_row
    WHERE anchor_member_row.run_id = m.run_id
      AND anchor_member_row.config_id = m.config_id
      AND anchor_member_row.anchor_signal_id = m.anchor_signal_id
      AND anchor_member_row.is_anchor
      AND anchor_member_row.member_token = ?
  )
        """
        parameters.append(normalized_anchor)
    parameters.append(len(tokens))

    rows = _fetch_dicts(
        connection,
        f"""
WITH selected AS (
  SELECT
    m.run_id,
    m.config_id,
    m.symbol,
    m.anchor_signal_id,
    m.anchor_window_id,
    m.anchor_pivot_timeframe,
    m.anchor_active_bar_open_broker_time,
    m.anchor_level_id,
    m.anchor_direction,
    m.anchor_trigger_broker_time,
    m.anchor_trigger_analysis_time,
    m.anchor_trigger_offset_minutes,
    m.research_group_id,
    MAX(m.member_trigger_broker_time) AS pattern_active_from,
    MIN(m.member_window_terminal_broker_time) AS pattern_active_until,
    COUNT(DISTINCT m.member_token) AS matched_tokens
  FROM confluence_members m
  JOIN requested_confluence_tokens requested
    ON requested.token = m.member_token
  WHERE TRUE
    {anchor_filter}
  GROUP BY ALL
  HAVING matched_tokens = ?
),
causal AS (
  SELECT *
  FROM selected
  WHERE pattern_active_from < pattern_active_until
),
supported AS (
  SELECT
    causal.*,
    COUNT(DISTINCT causal.research_group_id) OVER () AS group_support,
    COUNT(*) OVER () AS anchor_support
  FROM causal
),
outcome_aggregates AS (
  SELECT run_id, config_id, signal_id,
         COUNT(*) AS broker_outcome_support,
         SUM(CASE WHEN realized_profit > 0.0 THEN 1 ELSE 0 END)
           AS profitable_outcome_count,
         AVG(realized_profit) AS mean_realized_profit,
         SUM(realized_profit) AS total_realized_profit
  FROM signal_outcomes
  GROUP BY 1, 2, 3
)
SELECT
  c.*,
  COALESCE(o.broker_outcome_support, 0) AS broker_outcome_support,
  COALESCE(o.profitable_outcome_count, 0) AS profitable_outcome_count,
  o.mean_realized_profit,
  o.total_realized_profit
FROM supported c
LEFT JOIN outcome_aggregates o
  ON o.run_id = c.run_id
 AND o.config_id = c.config_id
 AND o.signal_id = c.anchor_signal_id
WHERE c.group_support >= {minimum_group_support}
ORDER BY c.pattern_active_from, c.research_group_id, c.anchor_signal_id
""",
        parameters,
    )
    connection.execute("DROP TABLE requested_confluence_tokens")
    return rows


def resolve_dataset_path(
    *,
    dataset_root: str | Path = DEFAULT_DATASET_ROOT,
    dataset_id: str | None = None,
    dataset_path: str | Path | None = None,
) -> Path:
    if (dataset_id is None) == (dataset_path is None):
        raise ConfluenceQueryError("Choose exactly one of dataset_id or dataset_path")
    if dataset_id is not None:
        _validate_id(dataset_id, "dataset ID")
        return (Path(dataset_root) / dataset_id).resolve()
    return Path(dataset_path).resolve()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id")
    dataset_group.add_argument("--dataset-path")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--member", action="append", required=True)
    parser.add_argument("--anchor-member")
    parser.add_argument("--minimum-group-support", type=int, default=0)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_dir = resolve_dataset_path(
            dataset_root=args.dataset_root,
            dataset_id=args.dataset_id,
            dataset_path=args.dataset_path,
        )
        connection = duckdb.connect(":memory:")
        try:
            _load_dataset(connection, dataset_dir)
            rows = query_pattern(
                connection,
                args.member,
                anchor_member=args.anchor_member,
                minimum_group_support=args.minimum_group_support,
            )
        finally:
            connection.close()
    except (ConfluenceQueryError, ValueError, duckdb.Error) as exc:
        parser.exit(1, f"confluence query failed: {exc}\n")
    print(json.dumps({"rows": rows, "row_count": len(rows)}, default=str, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
