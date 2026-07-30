"""Causal offline retest and confluence contracts for strict pivot-fractal V9 data."""

from __future__ import annotations

import csv
import math
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory
from time import perf_counter
from typing import Any

import duckdb

from schema_contract import CONTEXT_TIMEFRAMES, PIVOT_TIMEFRAMES


RETEST_POLICY_VERSION = "pivot_first_touch_retest_context_v1"
RETEST_EQUALITY_TOLERANCE = 1e-8

BUY_RETEST = "BUY_RETEST"
SELL_RETEST = "SELL_RETEST"
EQUAL_NEUTRAL = "EQUAL_NEUTRAL"
UNAVAILABLE = "UNAVAILABLE"
RETEST_TYPES = (BUY_RETEST, SELL_RETEST, EQUAL_NEUTRAL, UNAVAILABLE)

ALIGNED = "ALIGNED"
OPPOSED = "OPPOSED"
NEUTRAL = "NEUTRAL"
ALIGNMENT_UNAVAILABLE = "UNAVAILABLE"
ALIGNMENT_TYPES = (ALIGNED, OPPOSED, NEUTRAL, ALIGNMENT_UNAVAILABLE)

TIMEFRAME_RANK = {timeframe: rank for rank, timeframe in enumerate(CONTEXT_TIMEFRAMES)}

RETEST_CONTEXT_KEY = ("run_id", "config_id", "signal_id", "context_timeframe")
RETEST_CONTEXT_COLUMNS = (
    "schema_version",
    "retest_policy_version",
    "run_id",
    "config_id",
    "signal_id",
    "anchor_window_id",
    "symbol",
    "anchor_pivot_timeframe",
    "anchor_active_bar_open_broker_time",
    "anchor_level_id",
    "anchor_direction",
    "tested_level_price",
    "trigger_broker_time",
    "trigger_analysis_time",
    "trigger_offset_minutes",
    "context_timeframe",
    "context_timeframe_rank",
    "context_window_id",
    "context_active_bar_open_broker_time",
    "context_source_bar_open_broker_time",
    "context_source_close_boundary_broker_time",
    "context_terminal_broker_time",
    "context_previous_close",
    "context_source_range",
    "close_delta_to_level",
    "retest_type",
    "alignment",
    "available",
    "invalid_reason",
)

CONFLUENCE_POLICY_VERSION = "pivot_first_touch_confluence_v1"
CONFLUENCE_MAX_ACTIVE_MEMBERS = len(PIVOT_TIMEFRAMES) * 7
CONFLUENCE_MEMBER_KEY = (
    "run_id",
    "config_id",
    "anchor_signal_id",
    "member_signal_id",
)
CONFLUENCE_MEMBER_COLUMNS = (
    "schema_version",
    "confluence_policy_version",
    "run_id",
    "config_id",
    "symbol",
    "anchor_signal_id",
    "anchor_window_id",
    "anchor_pivot_timeframe",
    "anchor_active_bar_open_broker_time",
    "anchor_level_id",
    "anchor_direction",
    "anchor_trigger_broker_time",
    "anchor_trigger_analysis_time",
    "anchor_trigger_offset_minutes",
    "member_signal_id",
    "member_window_id",
    "member_pivot_timeframe",
    "member_active_bar_open_broker_time",
    "member_level_id",
    "member_direction",
    "member_trigger_broker_time",
    "member_window_terminal_broker_time",
    "member_token",
    "is_anchor",
    "same_trigger_batch",
    "relation_to_anchor",
    "member_age_seconds",
    "research_group_id",
)

CONFLUENCE_SNAPSHOT_COLUMNS = (
    "schema_version",
    "confluence_policy_version",
    "run_id",
    "config_id",
    "symbol",
    "anchor_signal_id",
    "anchor_window_id",
    "anchor_pivot_timeframe",
    "anchor_active_bar_open_broker_time",
    "anchor_level_id",
    "anchor_direction",
    "anchor_trigger_broker_time",
    "anchor_trigger_analysis_time",
    "anchor_trigger_offset_minutes",
    "research_group_id",
    "active_member_count",
    "active_peer_count",
    "active_timeframe_count",
    "active_buy_member_count",
    "active_sell_member_count",
    "active_buy_peer_count",
    "active_sell_peer_count",
    "aligned_peer_count",
    "opposed_peer_count",
    "neutral_peer_count",
    "same_trigger_peer_count",
    "active_m15_peer_count",
    "active_m30_peer_count",
    "active_h1_peer_count",
    "active_h4_peer_count",
    "active_d1_peer_count",
    "canonical_member_tokens",
    "active_from_broker_time",
    "earliest_active_until_broker_time",
)


class DerivedResearchError(RuntimeError):
    """Raised when causal derived research facts are incomplete or inconsistent."""


def classify_retest(
    previous_close: float | None,
    tested_level_price: float | None,
    *,
    tolerance: float = RETEST_EQUALITY_TOLERANCE,
) -> str:
    """Classify one completed close against an immutable tested pivot price."""
    if previous_close is None or tested_level_price is None:
        return UNAVAILABLE
    if not math.isfinite(previous_close) or not math.isfinite(tested_level_price):
        return UNAVAILABLE
    delta = previous_close - tested_level_price
    if delta > tolerance:
        return BUY_RETEST
    if delta < -tolerance:
        return SELL_RETEST
    return EQUAL_NEUTRAL


def classify_alignment(retest_type: str, anchor_direction: str) -> str:
    """Relate a retest side to the first-touch direction without changing identity."""
    if retest_type == UNAVAILABLE:
        return ALIGNMENT_UNAVAILABLE
    if retest_type == EQUAL_NEUTRAL:
        return NEUTRAL
    if anchor_direction not in ("BUY", "SELL"):
        raise ValueError(f"Unsupported anchor direction: {anchor_direction}")
    return ALIGNED if retest_type.removesuffix("_RETEST") == anchor_direction else OPPOSED


def _sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _timeframe_values_sql(timeframes: tuple[str, ...]) -> str:
    return ", ".join(
        f"({_sql_literal(timeframe)}, {TIMEFRAME_RANK[timeframe]})"
        for timeframe in timeframes
    )


def create_retest_context_table(connection: duckdb.DuckDBPyConnection) -> None:
    """Materialize six immutable prior-close contexts per validated V9 attempt."""
    macro_timeframes = tuple(
        timeframe for timeframe in CONTEXT_TIMEFRAMES if timeframe in PIVOT_TIMEFRAMES
    )
    connection.execute(
        f"""
CREATE TABLE signal_retest_context AS
WITH anchors AS (
  SELECT
    a.schema_version,
    a.run_id,
    a.config_id,
    a.signal_id,
    a.window_id AS anchor_window_id,
    a.symbol,
    a.pivot_timeframe AS anchor_pivot_timeframe,
    a.active_bar_open_broker_time AS anchor_active_bar_open_broker_time,
    a.level_id AS anchor_level_id,
    a.direction AS anchor_direction,
    l.trade_price AS tested_level_price,
    a.trigger_broker_time,
    a.trigger_analysis_time,
    a.trigger_offset_minutes,
    a.previous_m1_bar_open_broker_time,
    a.previous_m1_close_boundary_broker_time,
    a.previous_m1_bid_close
  FROM signal_attempts a
  JOIN pivot_levels l
    ON l.run_id = a.run_id
   AND l.config_id = a.config_id
   AND l.window_id = a.window_id
   AND l.level_id = a.level_id
),
macro_requests AS (
  SELECT anchors.*, context.context_timeframe, context.context_timeframe_rank
  FROM anchors
  CROSS JOIN (
    VALUES {_timeframe_values_sql(macro_timeframes)}
  ) AS context(context_timeframe, context_timeframe_rank)
),
macro_sources AS (
  SELECT
    request.*,
    context_window.window_id AS context_window_id,
    context_window.active_bar_open_broker_time AS context_active_bar_open_broker_time,
    context_window.source_bar_open_broker_time AS context_source_bar_open_broker_time,
    context_window.source_close_boundary_broker_time AS context_source_close_boundary_broker_time,
    context_window.terminal_broker_time AS context_terminal_broker_time,
    context_window.source_close AS context_previous_close,
    context_window.source_range AS context_source_range
  FROM macro_requests request
  ASOF LEFT JOIN (
    SELECT *
    FROM pivot_windows
    WHERE window_state = 'VALID'
  ) AS context_window
    ON request.run_id = context_window.run_id
   AND request.config_id = context_window.config_id
   AND request.symbol = context_window.symbol
   AND request.context_timeframe = context_window.pivot_timeframe
   AND request.trigger_broker_time >= context_window.active_bar_open_broker_time
),
context_sources AS (
  SELECT
    schema_version,
    run_id,
    config_id,
    signal_id,
    anchor_window_id,
    symbol,
    anchor_pivot_timeframe,
    anchor_active_bar_open_broker_time,
    anchor_level_id,
    anchor_direction,
    tested_level_price,
    trigger_broker_time,
    trigger_analysis_time,
    trigger_offset_minutes,
    'PERIOD_M1' AS context_timeframe,
    {TIMEFRAME_RANK['PERIOD_M1']}::BIGINT AS context_timeframe_rank,
    NULL::VARCHAR AS context_window_id,
    previous_m1_close_boundary_broker_time AS context_active_bar_open_broker_time,
    previous_m1_bar_open_broker_time AS context_source_bar_open_broker_time,
    previous_m1_close_boundary_broker_time AS context_source_close_boundary_broker_time,
    previous_m1_close_boundary_broker_time + INTERVAL 1 MINUTE AS context_terminal_broker_time,
    previous_m1_bid_close AS context_previous_close,
    NULL::DOUBLE AS context_source_range,
    CASE
      WHEN previous_m1_bid_close IS NULL THEN 'MISSING_PREVIOUS_M1_CLOSE'
      WHEN previous_m1_close_boundary_broker_time > trigger_broker_time
        THEN 'M1_SOURCE_CLOSE_AFTER_TRIGGER'
      WHEN trigger_broker_time >= previous_m1_close_boundary_broker_time + INTERVAL 1 MINUTE
        THEN 'M1_CONTEXT_EXPIRED'
      ELSE NULL
    END AS invalid_reason
  FROM anchors

  UNION ALL

  SELECT
    schema_version,
    run_id,
    config_id,
    signal_id,
    anchor_window_id,
    symbol,
    anchor_pivot_timeframe,
    anchor_active_bar_open_broker_time,
    anchor_level_id,
    anchor_direction,
    tested_level_price,
    trigger_broker_time,
    trigger_analysis_time,
    trigger_offset_minutes,
    context_timeframe,
    context_timeframe_rank,
    context_window_id,
    context_active_bar_open_broker_time,
    context_source_bar_open_broker_time,
    context_source_close_boundary_broker_time,
    context_terminal_broker_time,
    context_previous_close,
    context_source_range,
    CASE
      WHEN context_window_id IS NULL THEN 'NO_CAUSAL_VALID_CONTEXT_WINDOW'
      WHEN context_source_close_boundary_broker_time > trigger_broker_time
        THEN 'CONTEXT_SOURCE_CLOSE_AFTER_TRIGGER'
      WHEN trigger_broker_time >= context_terminal_broker_time
        THEN 'CONTEXT_WINDOW_EXPIRED'
      ELSE NULL
    END AS invalid_reason
  FROM macro_sources
),
classified AS (
  SELECT
    *,
    CASE
      WHEN invalid_reason IS NULL
        THEN context_previous_close - tested_level_price
      ELSE NULL
    END AS close_delta_to_level,
    CASE
      WHEN invalid_reason IS NOT NULL THEN '{UNAVAILABLE}'
      WHEN context_previous_close - tested_level_price > {RETEST_EQUALITY_TOLERANCE}
        THEN '{BUY_RETEST}'
      WHEN context_previous_close - tested_level_price < -{RETEST_EQUALITY_TOLERANCE}
        THEN '{SELL_RETEST}'
      ELSE '{EQUAL_NEUTRAL}'
    END AS retest_type
  FROM context_sources
)
SELECT
  schema_version,
  '{RETEST_POLICY_VERSION}' AS retest_policy_version,
  run_id,
  config_id,
  signal_id,
  anchor_window_id,
  symbol,
  anchor_pivot_timeframe,
  anchor_active_bar_open_broker_time,
  anchor_level_id,
  anchor_direction,
  tested_level_price,
  trigger_broker_time,
  trigger_analysis_time,
  trigger_offset_minutes,
  context_timeframe,
  context_timeframe_rank,
  context_window_id,
  context_active_bar_open_broker_time,
  context_source_bar_open_broker_time,
  context_source_close_boundary_broker_time,
  context_terminal_broker_time,
  context_previous_close,
  context_source_range,
  close_delta_to_level,
  retest_type,
  CASE
    WHEN retest_type = '{UNAVAILABLE}' THEN '{ALIGNMENT_UNAVAILABLE}'
    WHEN retest_type = '{EQUAL_NEUTRAL}' THEN '{NEUTRAL}'
    WHEN starts_with(retest_type, anchor_direction) THEN '{ALIGNED}'
    ELSE '{OPPOSED}'
  END AS alignment,
  invalid_reason IS NULL AS available,
  invalid_reason
FROM classified
ORDER BY trigger_broker_time, run_id, config_id, signal_id, context_timeframe_rank
"""
    )


def _single_int(connection: duckdb.DuckDBPyConnection, sql: str) -> int:
    return int(connection.execute(sql).fetchone()[0])


def retest_context_quality(connection: duckdb.DuckDBPyConnection) -> dict[str, Any]:
    """Return deterministic integrity and distribution evidence for the context table."""
    attempt_rows = _single_int(connection, "SELECT COUNT(*) FROM signal_attempts")
    row_count = _single_int(connection, "SELECT COUNT(*) FROM signal_retest_context")
    duplicate_keys = _single_int(
        connection,
        """
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, signal_id, context_timeframe, COUNT(*) AS rows
  FROM signal_retest_context
  GROUP BY 1, 2, 3, 4
  HAVING rows <> 1
)
""",
    )
    incomplete_signals = _single_int(
        connection,
        f"""
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, signal_id,
         COUNT(*) AS rows,
         COUNT(DISTINCT context_timeframe) AS contexts
  FROM signal_retest_context
  GROUP BY 1, 2, 3
  HAVING rows <> {len(CONTEXT_TIMEFRAMES)} OR contexts <> {len(CONTEXT_TIMEFRAMES)}
)
""",
    )
    unavailable_rows = _single_int(
        connection,
        "SELECT COUNT(*) FROM signal_retest_context WHERE NOT available",
    )
    future_context_rows = _single_int(
        connection,
        """
SELECT COUNT(*)
FROM signal_retest_context
WHERE available
  AND context_active_bar_open_broker_time > trigger_broker_time
""",
    )
    expired_context_rows = _single_int(
        connection,
        """
SELECT COUNT(*)
FROM signal_retest_context
WHERE available
  AND trigger_broker_time >= context_terminal_broker_time
""",
    )
    source_after_trigger_rows = _single_int(
        connection,
        """
SELECT COUNT(*)
FROM signal_retest_context
WHERE available
  AND context_source_close_boundary_broker_time > trigger_broker_time
""",
    )
    m1_direction_mismatches = _single_int(
        connection,
        f"""
SELECT COUNT(*)
FROM signal_retest_context
WHERE context_timeframe = 'PERIOD_M1'
  AND (
    NOT available
    OR (anchor_direction = 'BUY' AND retest_type <> '{BUY_RETEST}')
    OR (anchor_direction = 'SELL' AND retest_type <> '{SELL_RETEST}')
  )
""",
    )
    retest_distribution = [
        {"context_timeframe": row[0], "retest_type": row[1], "rows": int(row[2])}
        for row in connection.execute(
            """
SELECT context_timeframe, retest_type, COUNT(*) AS rows
FROM signal_retest_context
GROUP BY context_timeframe, context_timeframe_rank, retest_type
ORDER BY context_timeframe_rank, retest_type
"""
        ).fetchall()
    ]
    alignment_distribution = [
        {"context_timeframe": row[0], "alignment": row[1], "rows": int(row[2])}
        for row in connection.execute(
            """
SELECT context_timeframe, alignment, COUNT(*) AS rows
FROM signal_retest_context
GROUP BY context_timeframe, context_timeframe_rank, alignment
ORDER BY context_timeframe_rank, alignment
"""
        ).fetchall()
    ]
    invalid_reasons = [
        {"invalid_reason": row[0], "rows": int(row[1])}
        for row in connection.execute(
            """
SELECT invalid_reason, COUNT(*) AS rows
FROM signal_retest_context
WHERE invalid_reason IS NOT NULL
GROUP BY 1
ORDER BY 1
"""
        ).fetchall()
    ]
    return {
        "policy_version": RETEST_POLICY_VERSION,
        "equality_tolerance": RETEST_EQUALITY_TOLERANCE,
        "attempt_rows": attempt_rows,
        "expected_rows": attempt_rows * len(CONTEXT_TIMEFRAMES),
        "row_count": row_count,
        "duplicate_keys": duplicate_keys,
        "incomplete_signals": incomplete_signals,
        "unavailable_rows": unavailable_rows,
        "future_context_rows": future_context_rows,
        "expired_context_rows": expired_context_rows,
        "source_after_trigger_rows": source_after_trigger_rows,
        "m1_direction_mismatches": m1_direction_mismatches,
        "retest_distribution": retest_distribution,
        "alignment_distribution": alignment_distribution,
        "invalid_reasons": invalid_reasons,
    }


def validate_retest_context_table(
    connection: duckdb.DuckDBPyConnection,
    *,
    require_complete: bool = True,
) -> dict[str, Any]:
    """Fail closed when derived context grain or causal invariants are violated."""
    quality = retest_context_quality(connection)
    failures = {
        key: quality[key]
        for key in (
            "duplicate_keys",
            "incomplete_signals",
            "future_context_rows",
            "expired_context_rows",
            "source_after_trigger_rows",
            "m1_direction_mismatches",
        )
        if quality[key]
    }
    if quality["row_count"] != quality["expected_rows"]:
        failures["row_count"] = (
            f"{quality['row_count']} expected {quality['expected_rows']}"
        )
    if require_complete and quality["unavailable_rows"]:
        failures["unavailable_rows"] = quality["unavailable_rows"]
    if failures:
        raise DerivedResearchError(f"Retest context integrity failed: {failures}")
    return quality


def confluence_member_token(direction: str, timeframe: str, level_id: str) -> str:
    """Return the stable display token for one first-touch member."""
    if direction not in ("BUY", "SELL"):
        raise ValueError(f"Unsupported member direction: {direction}")
    if timeframe not in PIVOT_TIMEFRAMES:
        raise ValueError(f"Unsupported member timeframe: {timeframe}")
    if level_id not in ("S3", "S2", "S1", "PP", "R1", "R2", "R3"):
        raise ValueError(f"Unsupported member level: {level_id}")
    return f"{direction}:{timeframe}:{level_id}"


def build_research_group_id(symbol: str, d1_active_open: datetime) -> str:
    """Group repeated runs by symbol and causal D1 active broker window."""
    return f"{symbol}|{d1_active_open.strftime('%Y-%m-%dT%H:%M:%S')}"


def sweep_confluence_pairs(
    attempt_rows: list[dict[str, Any]],
) -> tuple[list[tuple[str, str, str, str]], dict[str, Any]]:
    """Emit only bounded anchor/member identity pairs from the chronological sweep."""
    grouped: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in attempt_rows:
        grouped[(row["run_id"], row["config_id"], row["symbol"])].append(row)

    pairs: list[tuple[str, str, str, str]] = []
    maximum_active_members = 0
    active_members_across_anchors = 0
    anchor_count = 0
    for group_key in sorted(grouped):
        attempts = sorted(
            grouped[group_key],
            key=lambda row: (row["trigger_broker_time"], row["signal_id"]),
        )
        active_by_timeframe: dict[str, list[dict[str, Any]]] = defaultdict(list)
        index = 0
        while index < len(attempts):
            trigger = attempts[index]["trigger_broker_time"]
            batch: list[dict[str, Any]] = []
            while index < len(attempts) and attempts[index]["trigger_broker_time"] == trigger:
                batch.append(attempts[index])
                index += 1
            for timeframe, active in tuple(active_by_timeframe.items()):
                active_by_timeframe[timeframe] = [
                    member
                    for member in active
                    if member["window_terminal_broker_time"] > trigger
                ]
            for attempt in batch:
                if attempt["window_terminal_broker_time"] <= trigger:
                    raise DerivedResearchError(
                        f"Anchor has no positive lifecycle interval: {attempt['signal_id']}"
                    )
                active_by_timeframe[attempt["pivot_timeframe"]].append(attempt)

            active_members = [
                member for values in active_by_timeframe.values() for member in values
            ]
            active_count = len(active_members)
            if active_count > CONFLUENCE_MAX_ACTIVE_MEMBERS:
                raise DerivedResearchError(
                    f"Confluence active-member bound exceeded: {active_count} > "
                    f"{CONFLUENCE_MAX_ACTIVE_MEMBERS} at {trigger}"
                )
            maximum_active_members = max(maximum_active_members, active_count)
            active_members_across_anchors += active_count * len(batch)
            anchor_count += len(batch)
            for anchor in batch:
                pairs.extend(
                    (
                        anchor["run_id"],
                        anchor["config_id"],
                        anchor["signal_id"],
                        member["signal_id"],
                    )
                    for member in active_members
                )

    return pairs, {
        "attempt_rows": len(attempt_rows),
        "member_rows": len(pairs),
        "snapshot_rows": anchor_count,
        "maximum_active_members": maximum_active_members,
        "mean_active_members": (
            active_members_across_anchors / anchor_count if anchor_count else 0.0
        ),
        "bound_violations": int(
            maximum_active_members > CONFLUENCE_MAX_ACTIVE_MEMBERS
        ),
    }


def _create_confluence_tables_from_pairs(
    connection: duckdb.DuckDBPyConnection,
    pairs: list[tuple[str, str, str, str]],
) -> None:
    with TemporaryDirectory(prefix="pivot-confluence-pairs-") as temp_dir:
        pair_path = Path(temp_dir) / "confluence_pairs.tsv"
        with pair_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
            writer.writerow(
                ("run_id", "config_id", "anchor_signal_id", "member_signal_id")
            )
            writer.writerows(pairs)
        connection.execute(
            """
CREATE TEMP TABLE confluence_pairs (
  run_id VARCHAR,
  config_id VARCHAR,
  anchor_signal_id VARCHAR,
  member_signal_id VARCHAR
)
"""
        )
        connection.execute(
            f"COPY confluence_pairs FROM {_sql_literal(pair_path.resolve().as_posix())} "
            "(FORMAT CSV, HEADER true, DELIMITER '\t')"
        )

    connection.execute(
        f"""
CREATE TABLE confluence_members AS
SELECT
  anchor.schema_version,
  '{CONFLUENCE_POLICY_VERSION}' AS confluence_policy_version,
  anchor.run_id,
  anchor.config_id,
  anchor.symbol,
  anchor.signal_id AS anchor_signal_id,
  anchor.window_id AS anchor_window_id,
  anchor.pivot_timeframe AS anchor_pivot_timeframe,
  anchor.active_bar_open_broker_time AS anchor_active_bar_open_broker_time,
  anchor.level_id AS anchor_level_id,
  anchor.direction AS anchor_direction,
  anchor.trigger_broker_time AS anchor_trigger_broker_time,
  anchor.trigger_analysis_time AS anchor_trigger_analysis_time,
  anchor.trigger_offset_minutes AS anchor_trigger_offset_minutes,
  member.signal_id AS member_signal_id,
  member.window_id AS member_window_id,
  member.pivot_timeframe AS member_pivot_timeframe,
  member.active_bar_open_broker_time AS member_active_bar_open_broker_time,
  member.level_id AS member_level_id,
  member.direction AS member_direction,
  member.trigger_broker_time AS member_trigger_broker_time,
  member_window.terminal_broker_time AS member_window_terminal_broker_time,
  member.direction || ':' || member.pivot_timeframe || ':' || member.level_id
    AS member_token,
  member.signal_id = anchor.signal_id AS is_anchor,
  member.trigger_broker_time = anchor.trigger_broker_time AS same_trigger_batch,
  CASE
    WHEN member.direction = anchor.direction THEN '{ALIGNED}'
    ELSE '{OPPOSED}'
  END AS relation_to_anchor,
  date_diff('second', member.trigger_broker_time, anchor.trigger_broker_time)::DOUBLE
    AS member_age_seconds,
  anchor.symbol || '|' ||
    strftime(d1.context_active_bar_open_broker_time, '%Y-%m-%dT%H:%M:%S')
    AS research_group_id
FROM confluence_pairs pair
JOIN signal_attempts anchor
  ON anchor.run_id = pair.run_id
 AND anchor.config_id = pair.config_id
 AND anchor.signal_id = pair.anchor_signal_id
JOIN signal_attempts member
  ON member.run_id = pair.run_id
 AND member.config_id = pair.config_id
 AND member.signal_id = pair.member_signal_id
JOIN pivot_windows member_window
  ON member_window.run_id = member.run_id
 AND member_window.config_id = member.config_id
 AND member_window.window_id = member.window_id
JOIN signal_retest_context d1
  ON d1.run_id = anchor.run_id
 AND d1.config_id = anchor.config_id
 AND d1.signal_id = anchor.signal_id
 AND d1.context_timeframe = 'PERIOD_D1'
 AND d1.available
ORDER BY anchor.trigger_broker_time, anchor.run_id, anchor.signal_id,
         member.trigger_broker_time, member.signal_id
"""
    )
    connection.execute(
        f"""
CREATE TABLE confluence_snapshots AS
SELECT
  schema_version,
  '{CONFLUENCE_POLICY_VERSION}' AS confluence_policy_version,
  run_id,
  config_id,
  symbol,
  anchor_signal_id,
  anchor_window_id,
  anchor_pivot_timeframe,
  anchor_active_bar_open_broker_time,
  anchor_level_id,
  anchor_direction,
  anchor_trigger_broker_time,
  anchor_trigger_analysis_time,
  anchor_trigger_offset_minutes,
  research_group_id,
  COUNT(*)::BIGINT AS active_member_count,
  COUNT(*) FILTER (WHERE NOT is_anchor)::BIGINT AS active_peer_count,
  COUNT(DISTINCT member_pivot_timeframe)::BIGINT AS active_timeframe_count,
  COUNT(*) FILTER (WHERE member_direction = 'BUY')::BIGINT
    AS active_buy_member_count,
  COUNT(*) FILTER (WHERE member_direction = 'SELL')::BIGINT
    AS active_sell_member_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_direction = 'BUY')::BIGINT
    AS active_buy_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_direction = 'SELL')::BIGINT
    AS active_sell_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND relation_to_anchor = '{ALIGNED}')::BIGINT
    AS aligned_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND relation_to_anchor = '{OPPOSED}')::BIGINT
    AS opposed_peer_count,
  0::BIGINT AS neutral_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND same_trigger_batch)::BIGINT
    AS same_trigger_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_pivot_timeframe = 'PERIOD_M15')::BIGINT
    AS active_m15_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_pivot_timeframe = 'PERIOD_M30')::BIGINT
    AS active_m30_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_pivot_timeframe = 'PERIOD_H1')::BIGINT
    AS active_h1_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_pivot_timeframe = 'PERIOD_H4')::BIGINT
    AS active_h4_peer_count,
  COUNT(*) FILTER (WHERE NOT is_anchor AND member_pivot_timeframe = 'PERIOD_D1')::BIGINT
    AS active_d1_peer_count,
  string_agg(
    member_token,
    ',' ORDER BY
      CASE member_pivot_timeframe
        WHEN 'PERIOD_M15' THEN 1 WHEN 'PERIOD_M30' THEN 2
        WHEN 'PERIOD_H1' THEN 3 WHEN 'PERIOD_H4' THEN 4
        WHEN 'PERIOD_D1' THEN 5 ELSE 99
      END,
      CASE member_level_id
        WHEN 'S3' THEN 0 WHEN 'S2' THEN 1 WHEN 'S1' THEN 2
        WHEN 'PP' THEN 3 WHEN 'R1' THEN 4 WHEN 'R2' THEN 5
        WHEN 'R3' THEN 6 ELSE 99
      END,
      member_direction
  ) AS canonical_member_tokens,
  MIN(member_trigger_broker_time) AS active_from_broker_time,
  MIN(member_window_terminal_broker_time) AS earliest_active_until_broker_time
FROM confluence_members
GROUP BY
  schema_version, run_id, config_id, symbol, anchor_signal_id, anchor_window_id,
  anchor_pivot_timeframe, anchor_active_bar_open_broker_time, anchor_level_id,
  anchor_direction, anchor_trigger_broker_time, anchor_trigger_analysis_time,
  anchor_trigger_offset_minutes, research_group_id
ORDER BY anchor_trigger_broker_time, run_id, anchor_signal_id
"""
    )


def create_confluence_tables(connection: duckdb.DuckDBPyConnection) -> dict[str, Any]:
    """Fetch validated source facts, sweep them, and create both confluence tables."""
    attempt_result = connection.execute(
        """
SELECT a.schema_version, a.run_id, a.config_id, a.signal_id, a.window_id,
       a.symbol, a.pivot_timeframe, a.active_bar_open_broker_time,
       a.level_id, a.direction, a.trigger_broker_time,
       a.trigger_analysis_time, a.trigger_offset_minutes,
       l.level_order, w.terminal_broker_time AS window_terminal_broker_time
FROM signal_attempts a
JOIN pivot_levels l
  ON l.run_id = a.run_id AND l.config_id = a.config_id
 AND l.window_id = a.window_id AND l.level_id = a.level_id
JOIN pivot_windows w
  ON w.run_id = a.run_id AND w.config_id = a.config_id
 AND w.window_id = a.window_id
ORDER BY a.run_id, a.config_id, a.symbol, a.trigger_broker_time, a.signal_id
"""
    )
    attempt_columns = [column[0] for column in attempt_result.description]
    attempt_rows = [dict(zip(attempt_columns, row)) for row in attempt_result.fetchall()]
    sweep_started = perf_counter()
    pairs, quality = sweep_confluence_pairs(attempt_rows)
    quality["sweep_duration_seconds"] = perf_counter() - sweep_started
    persistence_started = perf_counter()
    _create_confluence_tables_from_pairs(connection, pairs)
    quality["persistence_duration_seconds"] = perf_counter() - persistence_started
    quality.update(validate_confluence_tables(connection, require_complete=True))
    return quality


def validate_confluence_tables(
    connection: duckdb.DuckDBPyConnection,
    *,
    require_complete: bool = True,
) -> dict[str, Any]:
    """Validate member/snapshot grain, half-open intervals, and bounded counts."""
    member_count = int(connection.execute("SELECT COUNT(*) FROM confluence_members").fetchone()[0])
    snapshot_count = int(
        connection.execute("SELECT COUNT(*) FROM confluence_snapshots").fetchone()[0]
    )
    active_stats = connection.execute(
        "SELECT COALESCE(MAX(active_member_count), 0), "
        "COALESCE(AVG(active_member_count), 0.0) FROM confluence_snapshots"
    ).fetchone()
    duplicate_keys = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, anchor_signal_id, member_signal_id, COUNT(*) AS rows
  FROM confluence_members
  GROUP BY 1, 2, 3, 4
  HAVING rows <> 1
)
"""
        ).fetchone()[0]
    )
    anchor_counts = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, anchor_signal_id,
         SUM(CASE WHEN is_anchor THEN 1 ELSE 0 END) AS anchors,
         COUNT(*) AS members
  FROM confluence_members
  GROUP BY 1, 2, 3
  HAVING anchors <> 1
)
"""
        ).fetchone()[0]
    )
    count_mismatches = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM confluence_snapshots s
LEFT JOIN (
  SELECT run_id, config_id, anchor_signal_id, COUNT(*) AS members
  FROM confluence_members
  GROUP BY 1, 2, 3
) m USING (run_id, config_id, anchor_signal_id)
WHERE m.members IS NULL
   OR s.active_member_count <> m.members
   OR s.active_peer_count <> m.members - 1
"""
        ).fetchone()[0]
    )
    future_members = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM confluence_members
WHERE member_trigger_broker_time > anchor_trigger_broker_time
"""
        ).fetchone()[0]
    )
    expired_members = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM confluence_members
WHERE member_trigger_broker_time <= anchor_trigger_broker_time
  AND anchor_trigger_broker_time >= member_window_terminal_broker_time
"""
        ).fetchone()[0]
    )
    bound_violations = int(
        connection.execute(
            f"SELECT COUNT(*) FROM confluence_snapshots WHERE active_member_count > {CONFLUENCE_MAX_ACTIVE_MEMBERS}"
        ).fetchone()[0]
    )
    invalid_snapshot_intervals = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM confluence_snapshots
WHERE active_from_broker_time > anchor_trigger_broker_time
   OR earliest_active_until_broker_time <= anchor_trigger_broker_time
"""
        ).fetchone()[0]
    )
    group_nulls = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM confluence_snapshots
WHERE research_group_id IS NULL OR research_group_id = ''
"""
        ).fetchone()[0]
    )
    failures = {
        "duplicate_keys": duplicate_keys,
        "anchor_counts": anchor_counts,
        "count_mismatches": count_mismatches,
        "future_members": future_members,
        "expired_members": expired_members,
        "bound_violations": bound_violations,
        "invalid_snapshot_intervals": invalid_snapshot_intervals,
        "group_nulls": group_nulls,
    }
    if require_complete and any(failures.values()):
        raise DerivedResearchError(f"Confluence integrity failed: {failures}")
    return {
        "member_rows": member_count,
        "snapshot_rows": snapshot_count,
        "maximum_active_members": int(active_stats[0]),
        "mean_active_members": float(active_stats[1]),
        "duplicate_member_keys": duplicate_keys,
        "anchor_count_violations": anchor_counts,
        "count_mismatches": count_mismatches,
        "future_member_rows": future_members,
        "expired_member_rows": expired_members,
        "bound_violations": bound_violations,
        "invalid_snapshot_intervals": invalid_snapshot_intervals,
        "group_nulls": group_nulls,
    }
