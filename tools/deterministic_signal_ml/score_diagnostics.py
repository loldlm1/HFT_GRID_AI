"""Score distribution diagnostics for deterministic signal ML candidates."""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any

import duckdb
import numpy as np

from model_config import DEFAULT_MODEL_ROOT


class ScoreDiagnosticsError(RuntimeError):
    """Raised when score diagnostics cannot be produced."""


QUANTILES = (0.0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1.0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    model_group = parser.add_mutually_exclusive_group(required=True)
    model_group.add_argument("--model-id", help="Model ID under --model-root.")
    model_group.add_argument("--model-path", help="Explicit model folder.")
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--output-path", default="", help="Defaults to <model>/diagnostics.")
    parser.add_argument(
        "--threshold",
        type=float,
        default=None,
        help="Optional diagnostic threshold. Defaults to robustness selected threshold or 0.50.",
    )
    return parser


def resolve_model_path(args: argparse.Namespace) -> Path:
    model_path = Path(args.model_path) if args.model_path else Path(args.model_root) / args.model_id
    if not model_path.is_dir():
        raise ScoreDiagnosticsError(f"Model folder does not exist: {model_path}")
    return model_path


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def read_prediction_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise ScoreDiagnosticsError(f"Missing prediction file: {path}")
    escaped = path.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect(":memory:")
    try:
        result = connection.execute(
            f"SELECT * FROM read_parquet('{escaped}') ORDER BY entry_time, row_index"
        )
        columns = [column[0] for column in result.description]
        return [dict(zip(columns, row)) for row in result.fetchall()]
    finally:
        connection.close()


def resolve_threshold(
    args: argparse.Namespace,
    robustness: dict[str, Any],
) -> tuple[float, str]:
    if args.threshold is not None:
        return args.threshold, "explicit_cli"
    threshold_selection = dict(robustness.get("threshold_selection", {}))
    selected = threshold_selection.get("selected_threshold")
    if selected not in (None, ""):
        return float(selected), "robustness_selected_threshold"
    return 0.50, "diagnostic_default_0.50"


def score_quantiles(scores: np.ndarray) -> dict[str, float | None]:
    if scores.size == 0:
        return {f"q{int(q * 100):02d}": None for q in QUANTILES}
    values = np.quantile(scores, QUANTILES)
    return {f"q{int(q * 100):02d}": float(value) for q, value in zip(QUANTILES, values)}


def max_drawdown(profits: list[float]) -> float:
    equity = 0.0
    peak = 0.0
    drawdown = 0.0
    for profit in profits:
        equity += profit
        peak = max(peak, equity)
        drawdown = max(drawdown, peak - equity)
    return float(drawdown)


def split_summary(label: str, rows: list[dict[str, Any]], threshold: float) -> dict[str, Any]:
    scores = np.asarray([float(row["xgb_win_probability"]) for row in rows], dtype=np.float64)
    selected = [row for row in rows if float(row["xgb_win_probability"]) >= threshold]
    profits = [float(row["target_profit_r"]) for row in selected]
    wins = sum(1 for row in selected if int(row["target_is_win"]) == 1)
    positives = sum(1 for row in rows if int(row["target_is_win"]) == 1)
    output: dict[str, Any] = {
        "split": label,
        "rows": len(rows),
        "positive_rows": positives,
        "negative_rows": len(rows) - positives,
        "threshold": threshold,
        "selected_rows": len(selected),
        "selected_percent": 0.0 if not rows else len(selected) / len(rows),
        "selected_win_rate": None if not selected else wins / len(selected),
        "selected_mean_profit_r": None if not profits else sum(profits) / len(profits),
        "selected_net_profit_r": sum(profits),
        "selected_max_drawdown_r": max_drawdown(profits),
        "all_scores_below_threshold": bool(scores.size > 0 and float(np.max(scores)) < threshold),
    }
    output.update(score_quantiles(scores))
    return output


def month_token(value: Any) -> str:
    if isinstance(value, datetime):
        return value.strftime("%Y-%m")
    return str(value)[:7].replace(".", "-")


def time_bucket_rows(
    split_label: str,
    rows: list[dict[str, Any]],
    threshold: float,
) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(month_token(row["entry_time"]), []).append(row)
    return [
        split_summary(split_label + ":" + bucket, bucket_rows, threshold)
        | {"split": split_label, "bucket": bucket}
        for bucket, bucket_rows in sorted(grouped.items())
    ]


def tsv_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.10g}"
    return str(value)


def write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    columns: list[str] = []
    for row in rows:
        for key in row:
            if key not in columns:
                columns.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: tsv_value(row.get(column)) for column in columns})


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        f"# Score Diagnostics: {payload['model_id']}",
        "",
        f"- Feature set: `{payload.get('feature_set_id', '')}`",
        f"- Dataset: `{payload.get('dataset_id', '')}`",
        f"- Threshold: `{payload['threshold']}`",
        f"- Threshold source: `{payload['threshold_source']}`",
        "",
        "## Split Summary",
        "",
        "| Split | Rows | Q50 | Q95 | Q99 | Max | Selected | Net R | All Below Threshold |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in payload["split_summary"]:
        lines.append(
            "| {split} | {rows} | {q50} | {q95} | {q99} | {q100} | {selected_rows} | {net_r} | {below} |".format(
                split=row["split"],
                rows=row["rows"],
                q50=tsv_value(row.get("q50")),
                q95=tsv_value(row.get("q95")),
                q99=tsv_value(row.get("q99")),
                q100=tsv_value(row.get("q100")),
                selected_rows=row["selected_rows"],
                net_r=tsv_value(row.get("selected_net_profit_r")),
                below="yes" if row.get("all_scores_below_threshold") else "no",
            )
        )
    lines.extend(
        [
            "",
            "## Time Buckets",
            "",
            "| Split | Bucket | Rows | Q95 | Max | Selected | Net R |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for row in payload["time_bucket_summary"]:
        lines.append(
            "| {split} | {bucket} | {rows} | {q95} | {q100} | {selected_rows} | {net_r} |".format(
                split=row["split"],
                bucket=row["bucket"],
                rows=row["rows"],
                q95=tsv_value(row.get("q95")),
                q100=tsv_value(row.get("q100")),
                selected_rows=row["selected_rows"],
                net_r=tsv_value(row.get("selected_net_profit_r")),
            )
        )
    return "\n".join(lines) + "\n"


def build_payload(args: argparse.Namespace) -> tuple[dict[str, Any], Path]:
    model_path = resolve_model_path(args)
    output_dir = Path(args.output_path) if args.output_path else model_path / "diagnostics"
    manifest = read_json(model_path / "model_manifest.json")
    robustness = read_json(model_path / "robustness" / "robustness_metrics.json")
    threshold, threshold_source = resolve_threshold(args, robustness)
    fold_rows = read_prediction_rows(model_path / "fold_predictions.parquet")
    holdout_rows = read_prediction_rows(model_path / "holdout_predictions.parquet")

    split_rows = [
        split_summary("walk_forward_oof", fold_rows, threshold),
        split_summary("final_holdout", holdout_rows, threshold),
    ]
    buckets = time_bucket_rows("walk_forward_oof", fold_rows, threshold)
    buckets.extend(time_bucket_rows("final_holdout", holdout_rows, threshold))
    payload = {
        "model_id": manifest.get("model_id", model_path.name),
        "dataset_id": manifest.get("dataset_id", ""),
        "feature_set_id": manifest.get("feature_set_id", ""),
        "threshold": threshold,
        "threshold_source": threshold_source,
        "split_policy": robustness.get("split_policy", {}),
        "split_summary": split_rows,
        "time_bucket_summary": buckets,
    }
    return payload, output_dir


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        payload, output_dir = build_payload(args)
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "score_diagnostics.json").write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        write_tsv(output_dir / "score_split_summary.tsv", list(payload["split_summary"]))
        write_tsv(output_dir / "score_time_buckets.tsv", list(payload["time_bucket_summary"]))
        (output_dir / "score_diagnostics.md").write_text(render_markdown(payload), encoding="utf-8")
    except (ScoreDiagnosticsError, ValueError, json.JSONDecodeError, duckdb.Error) as exc:
        parser.exit(1, f"score diagnostics failed: {exc}\n")

    final = next(row for row in payload["split_summary"] if row["split"] == "final_holdout")
    oof = next(row for row in payload["split_summary"] if row["split"] == "walk_forward_oof")
    print(
        "score diagnostics ok | "
        f"model={payload['model_id']} | "
        f"threshold={payload['threshold']} | "
        f"oof_selected={oof['selected_rows']} | "
        f"oof_max={oof.get('q100')} | "
        f"final_selected={final['selected_rows']} | "
        f"final_max={final.get('q100')} | "
        f"final_below_threshold={final['all_scores_below_threshold']} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
