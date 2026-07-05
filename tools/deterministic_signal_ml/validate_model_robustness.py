"""Validate deterministic signal ML model robustness without changing runtime artifacts."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from model_artifact_contract import DEFAULT_EXPORT_ROOT
from model_config import DEFAULT_DATASET_ROOT, DEFAULT_MODEL_ROOT
from model_validation_config import (
    SMOKE_BASELINE_DATASET_ID,
    SMOKE_BASELINE_EXPORT_ID,
    SMOKE_BASELINE_MODEL_ID,
    SMOKE_DATASET_MAX_ROWS,
    BaselineInventory,
    ModelValidationConfigError,
    build_baseline_inventory,
)
from robustness_report import (
    OVERFIT_WARNINGS_TSV,
    SEGMENT_METRICS_TSV,
    THRESHOLD_SELECTION_TSV,
    RobustnessReportPayload,
    RobustnessWarning,
    warning_rows,
    write_json_report,
    write_markdown_report,
    write_tsv_report,
)
from training_report import (
    MIN_THRESHOLD_RECOMMENDATION_ROWS,
    build_threshold_report_rows,
)
from validation_splits import build_robust_time_splits


DEFAULT_FINAL_HOLDOUT_FRACTION = 0.20
DEFAULT_THRESHOLD_FRACTION = 0.20
DEFAULT_EARLY_STOPPING_FRACTION = 0.10
DEFAULT_WALK_FORWARD_SPLITS = 4
DEFAULT_GAP_GROUPS = 0
MIN_CLASS_COUNT = 20


class RobustnessValidationError(RuntimeError):
    """Raised when robustness validation cannot proceed."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-id", default=SMOKE_BASELINE_DATASET_ID)
    parser.add_argument("--model-id", default=SMOKE_BASELINE_MODEL_ID)
    parser.add_argument("--export-id", default=SMOKE_BASELINE_EXPORT_ID)
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--model-root", default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--export-root", default=DEFAULT_EXPORT_ROOT)
    parser.add_argument("--output-path", default="")
    parser.add_argument("--final-holdout-fraction", type=float, default=DEFAULT_FINAL_HOLDOUT_FRACTION)
    parser.add_argument("--threshold-fraction", type=float, default=DEFAULT_THRESHOLD_FRACTION)
    parser.add_argument("--early-stopping-fraction", type=float, default=DEFAULT_EARLY_STOPPING_FRACTION)
    parser.add_argument("--walk-forward-splits", type=int, default=DEFAULT_WALK_FORWARD_SPLITS)
    parser.add_argument("--gap-groups", type=int, default=DEFAULT_GAP_GROUPS)
    parser.add_argument(
        "--require-gap",
        action="store_true",
        help="Warn when robust partitions are generated with zero entry-time gap groups.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print compact JSON summary instead of text.",
    )
    return parser


def _sql_path(path: Path) -> str:
    return path.resolve().as_posix().replace("'", "''")


def _read_parquet_rows(path: Path, order_by: str) -> list[dict[str, Any]]:
    if not path.exists():
        raise RobustnessValidationError(f"Required Parquet file does not exist: {path}")
    connection = duckdb.connect(":memory:")
    try:
        escaped_path = _sql_path(path)
        result = connection.execute(
            f"SELECT * FROM read_parquet('{escaped_path}') ORDER BY {order_by}"
        )
        columns = [column[0] for column in result.description]
        return [dict(zip(columns, row)) for row in result.fetchall()]
    finally:
        connection.close()


def _read_split_rows(dataset_path: Path) -> list[dict[str, Any]]:
    rows = _read_parquet_rows(dataset_path / "training_matrix.parquet", "entry_time, source_key")
    return [{"entry_time": str(row["entry_time"])} for row in rows]


def _profit_metrics(
    prediction_rows: list[dict[str, Any]],
    threshold: float | None,
    min_selected_rows: int = MIN_THRESHOLD_RECOMMENDATION_ROWS,
) -> dict[str, Any]:
    if threshold is None:
        return {
            "rows": len(prediction_rows),
            "threshold": None,
            "selected_rows": 0,
            "selected_percent": 0.0,
            "positive_rows": _class_count(prediction_rows, 1),
            "negative_rows": _class_count(prediction_rows, 0),
            "win_rate": None,
            "mean_profit_r": None,
            "net_profit_r": 0.0,
            "max_drawdown_r": 0.0,
            "min_selected_rows": min_selected_rows,
        }
    selected = [
        row for row in prediction_rows if float(row["xgb_win_probability"]) >= threshold
    ]
    profits = [float(row["target_profit_r"]) for row in selected]
    wins = sum(1 for row in selected if int(row["target_is_win"]) == 1)
    return {
        "rows": len(prediction_rows),
        "threshold": threshold,
        "selected_rows": len(selected),
        "selected_percent": 0.0 if not prediction_rows else len(selected) / len(prediction_rows),
        "positive_rows": _class_count(prediction_rows, 1),
        "negative_rows": _class_count(prediction_rows, 0),
        "win_rate": None if not selected else wins / len(selected),
        "mean_profit_r": None if not profits else sum(profits) / len(profits),
        "net_profit_r": sum(profits),
        "max_drawdown_r": _max_drawdown(profits),
        "min_selected_rows": min_selected_rows,
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


def _class_count(rows: list[dict[str, Any]], target: int) -> int:
    return sum(1 for row in rows if int(row["target_is_win"]) == target)


def _threshold_rows_with_source(
    threshold_rows: list[dict[str, Any]],
    threshold_source: str,
    source_rows: int,
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for row in threshold_rows:
        enriched = {
            "threshold_source": threshold_source,
            "source_rows": source_rows,
        }
        enriched.update(row)
        output.append(enriched)
    return output


def _load_threshold_source(model_path: Path) -> tuple[str, list[dict[str, Any]], bool]:
    fold_path = model_path / "fold_predictions.parquet"
    if fold_path.exists():
        return (
            "walk_forward_oof_pre_final_holdout",
            _read_parquet_rows(fold_path, "entry_time, row_index"),
            False,
        )

    holdout_path = model_path / "holdout_predictions.parquet"
    if holdout_path.exists():
        return (
            "legacy_final_holdout_predictions",
            _read_parquet_rows(holdout_path, "entry_time, row_index"),
            True,
        )
    raise RobustnessValidationError(
        f"Neither fold_predictions.parquet nor holdout_predictions.parquet exists in {model_path}"
    )


def _warning(
    severity: str,
    code: str,
    message: str,
    detail: str = "",
) -> RobustnessWarning:
    return RobustnessWarning(severity=severity, code=code, message=message, detail=detail)


def _build_warnings(
    inventory: BaselineInventory,
    split_metadata: dict[str, Any],
    threshold_selection: dict[str, Any],
    final_holdout: dict[str, Any],
    final_holdout_used_for_selection: bool,
    require_gap: bool,
) -> list[RobustnessWarning]:
    warnings = [
        _warning("WARN", warning.split(":", 1)[0], warning)
        for warning in inventory.warnings
    ]
    training_rows = int(inventory.row_counts.get("training_matrix", 0))
    if training_rows < SMOKE_DATASET_MAX_ROWS:
        warnings.append(
            _warning(
                "WARN",
                "short_dataset",
                "Dataset is smoke-only and cannot approve new features or thresholds.",
                f"training_matrix_rows={training_rows}",
            )
        )
    if "holdout" in inventory.threshold_source.lower():
        warnings.append(
            _warning(
                "WARN",
                "legacy_export_threshold_uses_holdout",
                "Exported threshold metadata came from the legacy holdout research flow.",
                f"threshold_source={inventory.threshold_source}",
            )
        )
    if final_holdout_used_for_selection:
        warnings.append(
            _warning(
                "WARN",
                "final_holdout_used_for_threshold_selection",
                "Only legacy holdout predictions were available for threshold selection.",
            )
        )
    if require_gap and int(split_metadata.get("gap_entry_time_groups", 0)) == 0:
        warnings.append(
            _warning(
                "WARN",
                "required_gap_missing",
                "Robust split policy was requested with a gap requirement, but gap is zero.",
            )
        )
    for label, metrics in (
        ("threshold_selection", threshold_selection),
        ("final_holdout", final_holdout),
    ):
        selected_rows = int(metrics.get("selected_rows") or 0)
        min_selected_rows = int(metrics.get("min_selected_rows") or MIN_THRESHOLD_RECOMMENDATION_ROWS)
        if selected_rows < min_selected_rows:
            warnings.append(
                _warning(
                    "WARN",
                    f"{label}_small_selected_count",
                    f"{label} has fewer selected rows than the minimum guard.",
                    f"selected_rows={selected_rows}; min_selected_rows={min_selected_rows}",
                )
            )
        positive_rows = int(metrics.get("positive_rows") or 0)
        negative_rows = int(metrics.get("negative_rows") or 0)
        if positive_rows < MIN_CLASS_COUNT or negative_rows < MIN_CLASS_COUNT:
            warnings.append(
                _warning(
                    "WARN",
                    f"{label}_insufficient_class_count",
                    f"{label} has low class support.",
                    f"positive_rows={positive_rows}; negative_rows={negative_rows}",
                )
            )
    return warnings


def build_payload(args: argparse.Namespace) -> tuple[RobustnessReportPayload, list[dict[str, Any]], Path]:
    dataset_root = Path(args.dataset_root)
    model_root = Path(args.model_root)
    export_root = Path(args.export_root)
    inventory = build_baseline_inventory(
        dataset_id=args.dataset_id,
        model_id=args.model_id,
        export_id=args.export_id,
        dataset_root=dataset_root,
        model_root=model_root,
        export_root=export_root,
    )
    dataset_path = dataset_root / args.dataset_id
    model_path = model_root / args.model_id
    output_dir = Path(args.output_path) if args.output_path else model_path / "robustness"

    split_rows = _read_split_rows(dataset_path)
    robust_splits = build_robust_time_splits(
        split_rows,
        final_holdout_fraction=args.final_holdout_fraction,
        threshold_fraction=args.threshold_fraction,
        early_stopping_fraction=args.early_stopping_fraction,
        n_splits=args.walk_forward_splits,
        gap=args.gap_groups,
    )

    threshold_source, threshold_prediction_rows, final_used_for_selection = _load_threshold_source(
        model_path
    )
    threshold_rows, recommendation = build_threshold_report_rows(threshold_prediction_rows)
    source_row_count = len(threshold_prediction_rows)
    selected_threshold = (
        float(recommendation["threshold"])
        if recommendation is not None
        else inventory.threshold_probability
    )
    threshold_selection = _profit_metrics(threshold_prediction_rows, selected_threshold)
    threshold_selection.update(
        {
            "source": threshold_source,
            "source_rows": source_row_count,
            "selected_threshold": selected_threshold,
            "final_holdout_used_for_selection": final_used_for_selection,
            "recommendation": None if recommendation is None else dict(recommendation),
        }
    )

    final_holdout_rows = _read_parquet_rows(
        model_path / "holdout_predictions.parquet",
        "entry_time, row_index",
    )
    final_holdout = _profit_metrics(final_holdout_rows, selected_threshold)

    warnings = _build_warnings(
        inventory=inventory,
        split_metadata=robust_splits.metadata,
        threshold_selection=threshold_selection,
        final_holdout=final_holdout,
        final_holdout_used_for_selection=final_used_for_selection,
        require_gap=bool(args.require_gap),
    )
    status = "PASS" if not warnings else "WARN"
    payload = RobustnessReportPayload(
        status=status,
        generated_at=datetime.now(UTC).isoformat(),
        report_version="phase1.validation_hardening.v2",
        baseline=inventory.to_dict(),
        split_policy=robust_splits.metadata,
        threshold_selection=threshold_selection,
        final_holdout=final_holdout,
        warnings=[asdict(warning) for warning in warnings],
    )
    threshold_output_rows = _threshold_rows_with_source(
        threshold_rows,
        threshold_source,
        source_row_count,
    )
    return payload, threshold_output_rows, output_dir


def write_outputs(
    output_dir: Path,
    payload: RobustnessReportPayload,
    threshold_rows: list[dict[str, Any]],
) -> dict[str, str]:
    json_path = write_json_report(output_dir, payload)
    markdown_path = write_markdown_report(output_dir, payload)
    threshold_path = write_tsv_report(output_dir, THRESHOLD_SELECTION_TSV, threshold_rows)
    warnings_path = write_tsv_report(output_dir, OVERFIT_WARNINGS_TSV, warning_rows(payload.warnings))
    segment_path = write_tsv_report(output_dir, SEGMENT_METRICS_TSV, [])
    return {
        "metrics": str(json_path),
        "report": str(markdown_path),
        "threshold_selection": str(threshold_path),
        "overfit_warnings": str(warnings_path),
        "segment_metrics": str(segment_path),
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        payload, threshold_rows, output_dir = build_payload(args)
        outputs = write_outputs(output_dir, payload, threshold_rows)
    except (
        ModelValidationConfigError,
        RobustnessValidationError,
        ValueError,
        json.JSONDecodeError,
        duckdb.Error,
    ) as exc:
        parser.exit(1, f"robustness validation failed: {exc}\n")

    summary = {
        "status": payload.status,
        "dataset_id": args.dataset_id,
        "model_id": args.model_id,
        "export_id": args.export_id,
        "dataset_grade": payload.baseline.get("dataset_grade"),
        "threshold_source": payload.threshold_selection.get("source"),
        "selected_threshold": payload.threshold_selection.get("selected_threshold"),
        "final_holdout_selected_rows": payload.final_holdout.get("selected_rows"),
        "warning_count": len(payload.warnings),
        "output_path": str(output_dir),
    }
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(
            "robustness validation {status} | dataset={dataset_id} | model={model_id} | "
            "export={export_id} | grade={dataset_grade} | threshold_source={threshold_source} | "
            "threshold={selected_threshold} | final_selected={final_holdout_selected_rows} | "
            "warnings={warning_count} | output={output_path}".format(**summary)
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
