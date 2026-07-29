"""Research-only threshold, calibration, and rank-policy diagnostics."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

import duckdb
import numpy as np
from sklearn.linear_model import LogisticRegression

from model_config import DEFAULT_MODEL_ROOT


class ThresholdPolicyDiagnosticsError(RuntimeError):
    """Raised when threshold policy diagnostics cannot run."""


RAW_THRESHOLDS = (0.45, 0.46, 0.47, 0.48, 0.49, 0.50, 0.51, 0.52, 0.55)
CALIBRATED_THRESHOLDS = (0.45, 0.46, 0.47, 0.48, 0.49, 0.50, 0.51, 0.52, 0.55)
TOP_PCTS = (0.005, 0.01, 0.02, 0.05, 0.10)
MIN_PREFINAL_SELECTED = 100
MIN_FINAL_SELECTED = 50


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    model_group = parser.add_mutually_exclusive_group(required=True)
    model_group.add_argument("--model-id", help="Model ID under --model-root.")
    model_group.add_argument("--model-path", help="Explicit model folder.")
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--output-path", default="", help="Defaults to <model>/diagnostics.")
    return parser


def resolve_model_path(args: argparse.Namespace) -> Path:
    model_path = Path(args.model_path) if args.model_path else Path(args.model_root) / args.model_id
    if not model_path.is_dir():
        raise ThresholdPolicyDiagnosticsError(f"Model folder does not exist: {model_path}")
    return model_path


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def read_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise ThresholdPolicyDiagnosticsError(f"Missing prediction file: {path}")
    escaped = path.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect(":memory:")
    try:
        result = connection.execute(
            f"SELECT * FROM read_parquet('{escaped}') ORDER BY entry_broker_time, row_index"
        )
        columns = [column[0] for column in result.description]
        return [dict(zip(columns, row)) for row in result.fetchall()]
    finally:
        connection.close()


def max_drawdown(profits: list[float]) -> float:
    equity = 0.0
    peak = 0.0
    drawdown = 0.0
    for profit in profits:
        equity += profit
        peak = max(peak, equity)
        drawdown = max(drawdown, peak - equity)
    return float(drawdown)


def metrics(rows: list[dict[str, Any]], score_column: str, threshold: float) -> dict[str, Any]:
    selected = [row for row in rows if float(row[score_column]) >= threshold]
    profits = [float(row["target_profit_r"]) for row in selected]
    wins = sum(1 for row in selected if int(row["target_is_win"]) == 1)
    return {
        "rows": len(rows),
        "selected_rows": len(selected),
        "selected_percent": 0.0 if not rows else len(selected) / len(rows),
        "win_rate": None if not selected else wins / len(selected),
        "mean_profit_r": None if not profits else sum(profits) / len(profits),
        "net_profit_r": sum(profits),
        "max_drawdown_r": max_drawdown(profits),
    }


def add_calibrated_scores(
    prefinal_rows: list[dict[str, Any]],
    final_rows: list[dict[str, Any]],
) -> None:
    x = np.asarray([[float(row["xgb_win_probability"])] for row in prefinal_rows], dtype=np.float64)
    y = np.asarray([int(row["target_is_win"]) for row in prefinal_rows], dtype=np.int64)
    if sorted(np.unique(y).tolist()) != [0, 1]:
        raise ThresholdPolicyDiagnosticsError("Calibration requires both classes in pre-final rows")
    model = LogisticRegression(random_state=42, solver="lbfgs")
    model.fit(x, y)
    for rows in (prefinal_rows, final_rows):
        values = np.asarray([[float(row["xgb_win_probability"])] for row in rows], dtype=np.float64)
        calibrated = model.predict_proba(values)[:, 1]
        for row, score in zip(rows, calibrated):
            row["calibrated_win_probability"] = float(score)


def policy_row(
    policy_type: str,
    policy_id: str,
    score_column: str,
    threshold: float,
    prefinal_rows: list[dict[str, Any]],
    final_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    pre = metrics(prefinal_rows, score_column, threshold)
    final = metrics(final_rows, score_column, threshold)
    pre_eligible = (
        int(pre["selected_rows"]) >= MIN_PREFINAL_SELECTED
        and pre["mean_profit_r"] is not None
        and float(pre["mean_profit_r"]) > 0.0
        and float(pre["net_profit_r"]) > 0.0
    )
    final_pass = (
        pre_eligible
        and int(final["selected_rows"]) >= MIN_FINAL_SELECTED
        and final["mean_profit_r"] is not None
        and float(final["mean_profit_r"]) > 0.0
        and float(final["net_profit_r"]) > 0.0
    )
    return {
        "policy_type": policy_type,
        "policy_id": policy_id,
        "score_column": score_column,
        "threshold": threshold,
        "prefinal_selected_rows": pre["selected_rows"],
        "prefinal_win_rate": pre["win_rate"],
        "prefinal_mean_profit_r": pre["mean_profit_r"],
        "prefinal_net_profit_r": pre["net_profit_r"],
        "prefinal_max_drawdown_r": pre["max_drawdown_r"],
        "prefinal_eligible": pre_eligible,
        "final_selected_rows": final["selected_rows"],
        "final_win_rate": final["win_rate"],
        "final_mean_profit_r": final["mean_profit_r"],
        "final_net_profit_r": final["net_profit_r"],
        "final_max_drawdown_r": final["max_drawdown_r"],
        "final_pass": final_pass,
    }


def build_policy_rows(
    prefinal_rows: list[dict[str, Any]],
    final_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for threshold in RAW_THRESHOLDS:
        output.append(
            policy_row(
                "raw_threshold",
                f"raw_ge_{threshold:.2f}",
                "xgb_win_probability",
                threshold,
                prefinal_rows,
                final_rows,
            )
        )
    add_calibrated_scores(prefinal_rows, final_rows)
    for threshold in CALIBRATED_THRESHOLDS:
        output.append(
            policy_row(
                "calibrated_threshold",
                f"calibrated_ge_{threshold:.2f}",
                "calibrated_win_probability",
                threshold,
                prefinal_rows,
                final_rows,
            )
        )
    pre_scores = np.asarray(
        [float(row["xgb_win_probability"]) for row in prefinal_rows],
        dtype=np.float64,
    )
    for pct in TOP_PCTS:
        cutoff = float(np.quantile(pre_scores, 1.0 - pct))
        output.append(
            policy_row(
                "rank_quantile",
                f"top_{pct:.3%}_prefinal_cutoff",
                "xgb_win_probability",
                cutoff,
                prefinal_rows,
                final_rows,
            )
        )
    return output


def tsv_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.10g}"
    return str(value)


def write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
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


def best_prefinal(rows: list[dict[str, Any]]) -> dict[str, Any] | None:
    eligible = [row for row in rows if row["prefinal_eligible"]]
    if not eligible:
        return None
    return max(eligible, key=lambda row: float(row["prefinal_net_profit_r"]))


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        f"# Threshold Policy Diagnostics: {payload['model_id']}",
        "",
        f"- Feature set: `{payload.get('feature_set_id', '')}`",
        f"- Dataset: `{payload.get('dataset_id', '')}`",
        f"- Status: `{payload['status']}`",
        f"- Best pre-final policy: `{payload.get('best_prefinal_policy_id', '')}`",
        f"- Final-pass policies: `{payload['final_pass_policy_count']}`",
        "",
        "| Policy | Threshold | Pre-final selected | Pre-final net R | Final selected | Final net R | Final pass |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in payload["policy_rows"]:
        lines.append(
            "| {policy_id} | {threshold} | {prefinal_selected_rows} | {prefinal_net_profit_r} | {final_selected_rows} | {final_net_profit_r} | {final_pass} |".format(
                policy_id=row["policy_id"],
                threshold=tsv_value(row["threshold"]),
                prefinal_selected_rows=row["prefinal_selected_rows"],
                prefinal_net_profit_r=tsv_value(row["prefinal_net_profit_r"]),
                final_selected_rows=row["final_selected_rows"],
                final_net_profit_r=tsv_value(row["final_net_profit_r"]),
                final_pass="yes" if row["final_pass"] else "no",
            )
        )
    return "\n".join(lines) + "\n"


def build_payload(args: argparse.Namespace) -> tuple[dict[str, Any], Path]:
    model_path = resolve_model_path(args)
    output_dir = Path(args.output_path) if args.output_path else model_path / "diagnostics"
    manifest = read_json(model_path / "model_manifest.json")
    prefinal_rows = read_rows(model_path / "fold_predictions.parquet")
    final_rows = read_rows(model_path / "holdout_predictions.parquet")
    rows = build_policy_rows(prefinal_rows, final_rows)
    best = best_prefinal(rows)
    final_pass_count = sum(1 for row in rows if row["final_pass"])
    payload = {
        "model_id": manifest.get("model_id", model_path.name),
        "dataset_id": manifest.get("dataset_id", ""),
        "feature_set_id": manifest.get("feature_set_id", ""),
        "status": "PASS" if final_pass_count > 0 else "FAIL",
        "best_prefinal_policy_id": "" if best is None else best["policy_id"],
        "best_prefinal_policy_type": "" if best is None else best["policy_type"],
        "final_pass_policy_count": final_pass_count,
        "min_prefinal_selected_rows": MIN_PREFINAL_SELECTED,
        "min_final_selected_rows": MIN_FINAL_SELECTED,
        "policy_rows": rows,
    }
    return payload, output_dir


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        payload, output_dir = build_payload(args)
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "threshold_policy_diagnostics.json").write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        write_tsv(output_dir / "threshold_policy_diagnostics.tsv", payload["policy_rows"])
        (output_dir / "threshold_policy_diagnostics.md").write_text(
            render_markdown(payload),
            encoding="utf-8",
        )
    except (
        ThresholdPolicyDiagnosticsError,
        ValueError,
        json.JSONDecodeError,
        duckdb.Error,
    ) as exc:
        parser.exit(1, f"threshold policy diagnostics failed: {exc}\n")

    print(
        "threshold policy diagnostics {status} | "
        "model={model_id} | best_prefinal={best_prefinal_policy_id} | "
        "final_pass_policies={final_pass_policy_count} | output={output}".format(
            output=output_dir,
            **payload,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
