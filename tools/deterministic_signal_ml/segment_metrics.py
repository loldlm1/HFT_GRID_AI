"""Segment diagnostics for deterministic signal ML robustness reports."""

from __future__ import annotations

import math
from collections import defaultdict
from typing import Any, Callable


MIN_SEGMENT_ROWS = 30
MIN_SEGMENT_SELECTED_ROWS = 10


def build_segment_metrics(
    prediction_rows: list[dict[str, Any]],
    threshold: float | None,
    min_rows: int = MIN_SEGMENT_ROWS,
    min_selected_rows: int = MIN_SEGMENT_SELECTED_ROWS,
) -> list[dict[str, Any]]:
    specs: list[tuple[str, Callable[[dict[str, Any]], str]]] = [
        ("strategy_label", lambda row: str(row.get("strategy_label", ""))),
        ("direction", lambda row: str(row.get("direction", ""))),
        (
            "structure_context",
            lambda row: (
                f"{row.get('structure_0', '')}|"
                f"{row.get('structure_1', '')}|"
                f"{row.get('structure_2', '')}"
            ),
        ),
        (
            "macro_slope_context",
            lambda row: (
                f"{row.get('macro_h1_slope', '')}|"
                f"{row.get('macro_h4_slope', '')}|"
                f"{row.get('macro_d1_slope', '')}"
            ),
        ),
        (
            "fib_context",
            lambda row: f"{row.get('fib_sl_band', '')}|{row.get('fib_entry_band', '')}",
        ),
        (
            "chain_context",
            lambda row: f"{row.get('high_chain_profile', '')}|{row.get('low_chain_profile', '')}",
        ),
        ("previous_candle_profile", lambda row: str(row.get("previous_candle_profile", ""))),
        ("entry_session_bucket", lambda row: str(row.get("entry_session_bucket", ""))),
        ("entry_weekday", lambda row: str(row.get("entry_weekday", ""))),
        ("entry_month", lambda row: entry_month(row)),
        ("entry_hour", lambda row: entry_hour(row)),
        ("symbol", lambda row: str(row.get("symbol", ""))),
        (
            "strategy_label_direction",
            lambda row: f"{row.get('strategy_label', '')}|{row.get('direction', '')}",
        ),
        ("score_bucket", lambda row: score_bucket(float(row["xgb_win_probability"]))),
    ]
    append_optional_segment(
        specs,
        prediction_rows,
        "session_id",
        lambda row: str(row.get("session_id", "")),
        "session_id",
    )
    append_optional_segment(
        specs,
        prediction_rows,
        "stoch_structure_raw_percent_bucket",
        lambda row: numeric_bucket(row, "stoch_structure_raw_percent", 10.0),
        "stoch_structure_raw_percent",
    )
    append_optional_segment(
        specs,
        prediction_rows,
        "b_percent_main_base_bucket",
        lambda row: numeric_bucket(row, "b_percent_main_base", 10.0),
        "b_percent_main_base",
    )
    append_optional_segment(
        specs,
        prediction_rows,
        "b_percent_main_base_slope_bucket",
        lambda row: numeric_bucket(row, "b_percent_main_base_slope", 1.0),
        "b_percent_main_base_slope",
    )
    append_optional_segment(
        specs,
        prediction_rows,
        "b_percent_main_macro_bucket",
        lambda row: numeric_bucket(row, "b_percent_main_macro", 10.0),
        "b_percent_main_macro",
    )
    append_optional_segment(
        specs,
        prediction_rows,
        "b_percent_main_macro_slope_bucket",
        lambda row: numeric_bucket(row, "b_percent_main_macro_slope", 1.0),
        "b_percent_main_macro_slope",
    )
    output_rows: list[dict[str, Any]] = []
    for segment_type, key_func in specs:
        grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in prediction_rows:
            grouped[key_func(row)].append(row)
        for segment_value in sorted(grouped):
            rows = grouped[segment_value]
            output_rows.append(
                _metrics_for_segment(
                    segment_type,
                    segment_value,
                    rows,
                    threshold,
                    min_rows,
                    min_selected_rows,
                )
            )
    return output_rows


def append_optional_segment(
    specs: list[tuple[str, Callable[[dict[str, Any]], str]]],
    rows: list[dict[str, Any]],
    segment_type: str,
    key_func: Callable[[dict[str, Any]], str],
    required_column: str,
) -> None:
    if any(row.get(required_column) not in (None, "") for row in rows):
        specs.append((segment_type, key_func))


def entry_month(row: dict[str, Any]) -> str:
    value = str(row.get("entry_time", ""))
    if len(value) >= 7:
        return value[:7]
    return ""


def entry_hour(row: dict[str, Any]) -> str:
    value = str(row.get("entry_time", ""))
    if len(value) >= 13:
        return value[11:13]
    return ""


def numeric_bucket(row: dict[str, Any], column: str, width: float) -> str:
    value = row.get(column)
    if value in (None, ""):
        return ""
    try:
        numeric_value = float(value)
    except (TypeError, ValueError):
        return ""

    lower = math.floor(numeric_value / width) * width
    upper = lower + width
    return f"{format_bucket_edge(lower)}_{format_bucket_edge(upper)}"


def format_bucket_edge(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return f"{value:.6g}"


def score_bucket(score: float) -> str:
    if score < 0.50:
        return "lt_0.50"
    if score < 0.55:
        return "0.50_0.55"
    if score < 0.60:
        return "0.55_0.60"
    if score < 0.70:
        return "0.60_0.70"
    if score < 0.80:
        return "0.70_0.80"
    return "gte_0.80"


def _metrics_for_segment(
    segment_type: str,
    segment_value: str,
    rows: list[dict[str, Any]],
    threshold: float | None,
    min_rows: int,
    min_selected_rows: int,
) -> dict[str, Any]:
    selected = (
        []
        if threshold is None
        else [row for row in rows if float(row["xgb_win_probability"]) >= threshold]
    )
    profits = [float(row["target_profit_r"]) for row in selected]
    wins = sum(1 for row in selected if int(row["target_is_win"]) == 1)
    positives = sum(1 for row in rows if int(row["target_is_win"]) == 1)
    warning_codes: list[str] = []
    if len(rows) < min_rows:
        warning_codes.append("tiny_segment")
    if len(selected) < min_selected_rows:
        warning_codes.append("low_selected_rows")
    return {
        "segment_type": segment_type,
        "segment_value": segment_value,
        "rows": len(rows),
        "positives": positives,
        "selected_rows": len(selected),
        "selected_percent": 0.0 if not rows else len(selected) / len(rows),
        "win_rate": None if not selected else wins / len(selected),
        "mean_profit_r": None if not profits else sum(profits) / len(profits),
        "net_profit_r": sum(profits),
        "max_drawdown_r": _max_drawdown(profits),
        "min_rows": min_rows,
        "min_selected_rows": min_selected_rows,
        "status": "OK" if not warning_codes else "WARN",
        "warning_codes": ",".join(warning_codes),
    }


def _max_drawdown(profits: list[float]) -> float:
    equity = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for profit in profits:
        equity += profit
        peak = max(peak, equity)
        max_drawdown = max(max_drawdown, peak - equity)
    return float(max_drawdown)
