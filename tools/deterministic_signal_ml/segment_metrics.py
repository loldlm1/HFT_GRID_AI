"""Segment diagnostics for deterministic signal ML robustness reports."""

from __future__ import annotations

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
    specs: tuple[tuple[str, Callable[[dict[str, Any]], str]], ...] = (
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
        ("symbol", lambda row: str(row.get("symbol", ""))),
        (
            "strategy_label_direction",
            lambda row: f"{row.get('strategy_label', '')}|{row.get('direction', '')}",
        ),
        ("score_bucket", lambda row: score_bucket(float(row["xgb_win_probability"]))),
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
