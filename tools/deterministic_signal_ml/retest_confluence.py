"""Causal offline retest and confluence contracts for strict pivot-fractal V9 data."""

from __future__ import annotations

import math
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
