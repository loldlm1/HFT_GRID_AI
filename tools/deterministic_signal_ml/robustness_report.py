"""Render deterministic signal ML robustness reports."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from model_validation_config import BaselineInventory


ROBUSTNESS_REPORT_VERSION = "phase1.validation_hardening.v1"
ROBUSTNESS_METRICS_JSON = "robustness_metrics.json"
ROBUSTNESS_REPORT_MD = "robustness_report.md"
THRESHOLD_SELECTION_TSV = "threshold_selection.tsv"
SEGMENT_METRICS_TSV = "segment_metrics.tsv"
OVERFIT_WARNINGS_TSV = "overfit_warnings.tsv"


@dataclass(frozen=True)
class RobustnessWarning:
    severity: str
    code: str
    message: str
    detail: str = ""


@dataclass(frozen=True)
class RobustnessReportPayload:
    status: str
    generated_at: str
    report_version: str
    baseline: dict[str, Any]
    split_policy: dict[str, Any] = field(default_factory=dict)
    threshold_selection: dict[str, Any] = field(default_factory=dict)
    final_holdout: dict[str, Any] = field(default_factory=dict)
    segment_metrics: list[dict[str, Any]] = field(default_factory=list)
    feature_diagnostics: dict[str, Any] = field(default_factory=dict)
    warnings: list[dict[str, Any]] = field(default_factory=list)


def warnings_from_inventory(inventory: BaselineInventory) -> list[RobustnessWarning]:
    return [
        RobustnessWarning(
            severity="WARN",
            code=warning.split(":", 1)[0],
            message=warning,
        )
        for warning in inventory.warnings
    ]


def build_initial_payload(inventory: BaselineInventory) -> RobustnessReportPayload:
    warnings = warnings_from_inventory(inventory)
    status = "PASS" if not warnings else "WARN"
    return RobustnessReportPayload(
        status=status,
        generated_at=datetime.now(UTC).isoformat(),
        report_version=ROBUSTNESS_REPORT_VERSION,
        baseline=inventory.to_dict(),
        threshold_selection={
            "source": inventory.threshold_source,
            "threshold_probability": inventory.threshold_probability,
            "final_holdout_used_for_selection": "unknown_legacy",
        },
        warnings=[asdict(warning) for warning in warnings],
    )


def write_json_report(output_dir: Path, payload: RobustnessReportPayload) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / ROBUSTNESS_METRICS_JSON
    path.write_text(json.dumps(asdict(payload), indent=2, sort_keys=True), encoding="utf-8")
    return path


def tsv_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.10g}"
    return str(value)


def write_tsv_report(output_dir: Path, filename: str, rows: list[dict[str, Any]]) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / filename
    if not rows:
        path.write_text("", encoding="utf-8")
        return path
    columns: list[str] = []
    for row in rows:
        for key in row:
            if key not in columns:
                columns.append(key)
    lines = ["\t".join(columns)]
    for row in rows:
        lines.append("\t".join(tsv_value(row.get(column)) for column in columns))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def warning_rows(warnings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "severity": warning.get("severity", ""),
            "code": warning.get("code", ""),
            "message": warning.get("message", ""),
            "detail": warning.get("detail", ""),
        }
        for warning in warnings
    ]


def markdown_cell(value: Any) -> str:
    return tsv_value(value).replace("|", "\\|")


def render_markdown_report(payload: RobustnessReportPayload) -> str:
    baseline = payload.baseline
    row_counts = baseline.get("row_counts", {})
    split_policy = payload.split_policy
    threshold_selection = payload.threshold_selection
    final_holdout = payload.final_holdout
    feature_diagnostics = payload.feature_diagnostics
    segment_warning_count = sum(
        1 for row in payload.segment_metrics if row.get("status") == "WARN"
    )
    lines = [
        f"# Robustness Report: {baseline.get('model_id', '')}",
        "",
        f"Status: `{payload.status}`",
        f"Report version: `{payload.report_version}`",
        f"Generated at: `{payload.generated_at}`",
        "",
        "## Baseline",
        "",
        f"- Dataset: `{baseline.get('dataset_id', '')}`",
        f"- Model: `{baseline.get('model_id', '')}`",
        f"- Export: `{baseline.get('export_id', '')}`",
        f"- Dataset grade: `{baseline.get('dataset_grade', '')}`",
        f"- Training matrix rows: `{row_counts.get('training_matrix', 0)}`",
        f"- Encoded features: `{baseline.get('encoded_feature_count', '')}`",
        f"- Threshold probability: `{baseline.get('threshold_probability', '')}`",
        f"- Threshold source: `{baseline.get('threshold_source', '')}`",
        "",
        "## Split Policy",
        "",
        f"- Policy: `{split_policy.get('policy', '')}`",
        f"- Gap entry-time groups: `{split_policy.get('gap_entry_time_groups', '')}`",
        f"- Train core rows: `{split_policy.get('train_core', {}).get('row_count', '')}`",
        f"- Early-stopping validation rows: `{split_policy.get('early_stopping_validation', {}).get('row_count', '')}`",
        f"- Threshold-selection rows: `{split_policy.get('threshold_selection', {}).get('row_count', '')}`",
        f"- Final holdout rows: `{split_policy.get('final_holdout', {}).get('row_count', '')}`",
        "",
        "## Threshold Selection",
        "",
        f"- Source: `{threshold_selection.get('source', '')}`",
        f"- Source rows: `{threshold_selection.get('source_rows', '')}`",
        f"- Selected threshold: `{threshold_selection.get('selected_threshold', '')}`",
        f"- Selected rows: `{threshold_selection.get('selected_rows', '')}`",
        f"- Mean R: `{threshold_selection.get('mean_profit_r', '')}`",
        f"- Net R: `{threshold_selection.get('net_profit_r', '')}`",
        f"- Final holdout used for selection: `{threshold_selection.get('final_holdout_used_for_selection', '')}`",
        "",
        "## Final Holdout",
        "",
        f"- Rows: `{final_holdout.get('rows', '')}`",
        f"- Evaluation threshold: `{final_holdout.get('threshold', '')}`",
        f"- Selected rows: `{final_holdout.get('selected_rows', '')}`",
        f"- Win rate: `{final_holdout.get('win_rate', '')}`",
        f"- Mean R: `{final_holdout.get('mean_profit_r', '')}`",
        f"- Net R: `{final_holdout.get('net_profit_r', '')}`",
        f"- Max drawdown-like R: `{final_holdout.get('max_drawdown_r', '')}`",
        "",
        "## Segment Diagnostics",
        "",
        f"- Segment rows: `{len(payload.segment_metrics)}`",
        f"- Segment warnings: `{segment_warning_count}`",
        "",
        "| Segment Type | Value | Rows | Selected | Win Rate | Mean R | Net R | Status |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in payload.segment_metrics[:20]:
        lines.append(
            "| {segment_type} | {segment_value} | {rows} | {selected_rows} | {win_rate} | {mean_profit_r} | {net_profit_r} | {status} |".format(
                segment_type=markdown_cell(row.get("segment_type", "")),
                segment_value=markdown_cell(row.get("segment_value", "")),
                rows=row.get("rows", ""),
                selected_rows=row.get("selected_rows", ""),
                win_rate=tsv_value(row.get("win_rate")),
                mean_profit_r=tsv_value(row.get("mean_profit_r")),
                net_profit_r=tsv_value(row.get("net_profit_r")),
                status=row.get("status", ""),
            )
        )
    if len(payload.segment_metrics) > 20:
        lines.append("| ... | additional rows omitted from markdown |  |  |  |  |  |  |")
    lines.extend(
        [
            "",
            "## Feature Diagnostics",
            "",
            f"- No-variation encoded features: `{feature_diagnostics.get('no_variation_feature_count', '')}`",
            f"- Top classifier importance share: `{feature_diagnostics.get('top_classifier_importance_share', '')}`",
            f"- Top regressor importance share: `{feature_diagnostics.get('top_regressor_importance_share', '')}`",
            f"- Rare bucket warnings: `{feature_diagnostics.get('rare_bucket_warning_count', '')}`",
            "",
            "## Warnings",
            "",
        ]
    )
    if payload.warnings:
        for warning in payload.warnings:
            lines.append(
                f"- `{warning.get('severity', '')}` `{warning.get('code', '')}`: {warning.get('message', '')}"
            )
    else:
        lines.append("No warnings.")

    lines.extend(
        [
            "",
            "## Evidence Grade",
            "",
            "This report can validate tooling behavior. A one-to-two-year Strategy Tester run is required before approving new feature sets, production-like thresholds, multi-symbol claims, or dynamic target policies.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_markdown_report(output_dir: Path, payload: RobustnessReportPayload) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / ROBUSTNESS_REPORT_MD
    path.write_text(render_markdown_report(payload), encoding="utf-8")
    return path
