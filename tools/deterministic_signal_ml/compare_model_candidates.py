"""Compare deterministic signal ML robustness reports for candidate gating."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from model_validation_config import (
    CandidateManifest,
    ModelValidationConfigError,
    load_candidate_manifest,
)


COMPARISON_REPORT_VERSION = "phase1.candidate_comparison.v1"
COMPARISON_JSON = "candidate_comparison.json"
COMPARISON_MD = "candidate_comparison.md"
DEFAULT_MIN_NET_R_DELTA = 1.0
DEFAULT_MIN_MEAN_R_DELTA = 0.02
DEFAULT_MAX_SEGMENT_NET_R_REGRESSION = -1.0


class CandidateComparisonError(RuntimeError):
    """Raised when candidate comparison cannot proceed."""


@dataclass(frozen=True)
class CandidateInput:
    manifest_path: str
    manifest: CandidateManifest
    report: dict[str, Any]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-manifest", required=True)
    parser.add_argument("--candidate-manifest", required=True)
    parser.add_argument("--output-path", required=True)
    parser.add_argument("--min-net-r-delta", type=float, default=DEFAULT_MIN_NET_R_DELTA)
    parser.add_argument("--min-mean-r-delta", type=float, default=DEFAULT_MIN_MEAN_R_DELTA)
    parser.add_argument(
        "--max-segment-net-r-regression",
        type=float,
        default=DEFAULT_MAX_SEGMENT_NET_R_REGRESSION,
    )
    parser.add_argument("--json", action="store_true")
    return parser


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise CandidateComparisonError(f"Required JSON file does not exist: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _resolve_report_path(manifest_path: Path, report_path: str) -> Path:
    path = Path(report_path)
    if path.is_absolute() or path.exists():
        return path
    candidate = manifest_path.parent / path
    if candidate.exists():
        return candidate
    return path


def load_candidate_input(path: Path) -> CandidateInput:
    manifest = load_candidate_manifest(path)
    report_path = _resolve_report_path(path, manifest.robustness_report_path)
    report = _load_json(report_path)
    report_baseline = dict(report.get("baseline", {}))
    if str(report_baseline.get("dataset_id", "")) != manifest.dataset_id:
        raise CandidateComparisonError(
            f"Report dataset_id does not match manifest {path}: "
            f"{report_baseline.get('dataset_id')} != {manifest.dataset_id}"
        )
    if str(report_baseline.get("model_id", "")) != manifest.model_id:
        raise CandidateComparisonError(
            f"Report model_id does not match manifest {path}: "
            f"{report_baseline.get('model_id')} != {manifest.model_id}"
        )
    return CandidateInput(manifest_path=str(path), manifest=manifest, report=report)


def compare_candidates(
    baseline: CandidateInput,
    candidate: CandidateInput,
    min_net_r_delta: float,
    min_mean_r_delta: float,
    max_segment_net_r_regression: float,
) -> dict[str, Any]:
    comparable_warnings = _comparability_warnings(baseline.manifest, candidate.manifest)
    final_delta = _metric_delta(
        dict(baseline.report.get("final_holdout", {})),
        dict(candidate.report.get("final_holdout", {})),
    )
    threshold_delta = _metric_delta(
        dict(baseline.report.get("threshold_selection", {})),
        dict(candidate.report.get("threshold_selection", {})),
    )
    segment_regressions = _segment_regressions(
        list(baseline.report.get("segment_metrics", [])),
        list(candidate.report.get("segment_metrics", [])),
        max_segment_net_r_regression,
    )

    material_improvement = (
        not comparable_warnings
        and not segment_regressions
        and float(final_delta.get("net_profit_r_delta") or 0.0) >= min_net_r_delta
        and float(final_delta.get("mean_profit_r_delta") or 0.0) >= min_mean_r_delta
    )
    if comparable_warnings:
        decision = "NOT_COMPARABLE"
    elif segment_regressions:
        decision = "REJECT_SEGMENT_REGRESSION"
    elif material_improvement:
        decision = "MATERIAL_IMPROVEMENT"
    else:
        decision = "NO_MATERIAL_IMPROVEMENT"

    return {
        "report_version": COMPARISON_REPORT_VERSION,
        "generated_at": datetime.now(UTC).isoformat(),
        "decision": decision,
        "baseline": _manifest_summary(baseline),
        "candidate": _manifest_summary(candidate),
        "comparability_warnings": comparable_warnings,
        "final_holdout_delta": final_delta,
        "threshold_selection_delta": threshold_delta,
        "segment_regressions": segment_regressions,
        "minimums": {
            "min_net_r_delta": min_net_r_delta,
            "min_mean_r_delta": min_mean_r_delta,
            "max_segment_net_r_regression": max_segment_net_r_regression,
        },
    }


def _manifest_summary(candidate: CandidateInput) -> dict[str, Any]:
    payload = candidate.manifest.to_dict()
    payload["manifest_path"] = candidate.manifest_path
    payload["report_status"] = candidate.report.get("status")
    payload["warning_count"] = len(candidate.report.get("warnings", []))
    return payload


def _comparability_warnings(
    baseline: CandidateManifest,
    candidate: CandidateManifest,
) -> list[dict[str, str]]:
    warnings: list[dict[str, str]] = []
    for field in ("dataset_id", "dataset_grade", "split_policy", "threshold_policy"):
        baseline_value = getattr(baseline, field)
        candidate_value = getattr(candidate, field)
        if baseline_value != candidate_value:
            warnings.append(
                {
                    "code": f"{field}_mismatch",
                    "message": f"{field} differs between baseline and candidate.",
                    "baseline": str(baseline_value),
                    "candidate": str(candidate_value),
                }
            )
    return warnings


def _metric_delta(
    baseline: dict[str, Any],
    candidate: dict[str, Any],
) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for metric in (
        "selected_rows",
        "mean_profit_r",
        "net_profit_r",
        "max_drawdown_r",
        "roc_auc",
    ):
        baseline_value = _optional_float(baseline.get(metric))
        candidate_value = _optional_float(candidate.get(metric))
        output[f"baseline_{metric}"] = baseline_value
        output[f"candidate_{metric}"] = candidate_value
        output[f"{metric}_delta"] = (
            None
            if baseline_value is None or candidate_value is None
            else candidate_value - baseline_value
        )
    return output


def _segment_regressions(
    baseline_rows: list[dict[str, Any]],
    candidate_rows: list[dict[str, Any]],
    max_segment_net_r_regression: float,
) -> list[dict[str, Any]]:
    candidate_by_key = {
        _segment_key(row): row
        for row in candidate_rows
    }
    regressions: list[dict[str, Any]] = []
    for baseline in baseline_rows:
        key = _segment_key(baseline)
        candidate = candidate_by_key.get(key)
        if candidate is None:
            regressions.append(
                {
                    "segment_type": baseline.get("segment_type", ""),
                    "segment_value": baseline.get("segment_value", ""),
                    "code": "missing_candidate_segment",
                    "net_profit_r_delta": None,
                }
            )
            continue
        baseline_net = _optional_float(baseline.get("net_profit_r"))
        candidate_net = _optional_float(candidate.get("net_profit_r"))
        if baseline_net is None or candidate_net is None:
            continue
        delta = candidate_net - baseline_net
        if delta <= max_segment_net_r_regression:
            regressions.append(
                {
                    "segment_type": baseline.get("segment_type", ""),
                    "segment_value": baseline.get("segment_value", ""),
                    "code": "segment_net_r_regression",
                    "baseline_net_profit_r": baseline_net,
                    "candidate_net_profit_r": candidate_net,
                    "net_profit_r_delta": delta,
                }
            )
    return regressions


def _segment_key(row: dict[str, Any]) -> tuple[str, str]:
    return (str(row.get("segment_type", "")), str(row.get("segment_value", "")))


def _optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    return float(value)


def write_outputs(output_path: Path, payload: dict[str, Any]) -> dict[str, str]:
    output_path.mkdir(parents=True, exist_ok=True)
    json_path = output_path / COMPARISON_JSON
    markdown_path = output_path / COMPARISON_MD
    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    markdown_path.write_text(render_markdown(payload), encoding="utf-8")
    return {"json": str(json_path), "markdown": str(markdown_path)}


def render_markdown(payload: dict[str, Any]) -> str:
    final_delta = payload["final_holdout_delta"]
    lines = [
        f"# Candidate Comparison: {payload['candidate']['candidate_id']}",
        "",
        f"Decision: `{payload['decision']}`",
        f"Report version: `{payload['report_version']}`",
        f"Generated at: `{payload['generated_at']}`",
        "",
        "## Inputs",
        "",
        f"- Baseline: `{payload['baseline']['candidate_id']}`",
        f"- Candidate: `{payload['candidate']['candidate_id']}`",
        f"- Dataset: `{payload['candidate']['dataset_id']}`",
        f"- Feature set: `{payload['candidate']['feature_set_id']}`",
        "",
        "## Final Holdout Delta",
        "",
        f"- Selected rows delta: `{final_delta.get('selected_rows_delta')}`",
        f"- Mean R delta: `{final_delta.get('mean_profit_r_delta')}`",
        f"- Net R delta: `{final_delta.get('net_profit_r_delta')}`",
        f"- Drawdown-like R delta: `{final_delta.get('max_drawdown_r_delta')}`",
        f"- ROC AUC delta: `{final_delta.get('roc_auc_delta')}`",
        "",
        "## Comparability Warnings",
        "",
    ]
    if payload["comparability_warnings"]:
        for warning in payload["comparability_warnings"]:
            lines.append(f"- `{warning['code']}`: {warning['message']}")
    else:
        lines.append("No comparability warnings.")
    lines.extend(["", "## Segment Regressions", ""])
    if payload["segment_regressions"]:
        for regression in payload["segment_regressions"]:
            lines.append(
                "- `{segment_type}` `{segment_value}`: {code} ({delta})".format(
                    segment_type=regression.get("segment_type", ""),
                    segment_value=str(regression.get("segment_value", "")).replace("|", "\\|"),
                    code=regression.get("code", ""),
                    delta=regression.get("net_profit_r_delta"),
                )
            )
    else:
        lines.append("No segment regressions.")
    lines.extend(
        [
            "",
            "## Gate Note",
            "",
            "A one-month smoke dataset can validate comparison mechanics only; it cannot approve feature additions or production-like thresholds.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        baseline = load_candidate_input(Path(args.baseline_manifest))
        candidate = load_candidate_input(Path(args.candidate_manifest))
        payload = compare_candidates(
            baseline,
            candidate,
            min_net_r_delta=args.min_net_r_delta,
            min_mean_r_delta=args.min_mean_r_delta,
            max_segment_net_r_regression=args.max_segment_net_r_regression,
        )
        outputs = write_outputs(Path(args.output_path), payload)
    except (
        CandidateComparisonError,
        ModelValidationConfigError,
        ValueError,
        json.JSONDecodeError,
    ) as exc:
        parser.exit(1, f"candidate comparison failed: {exc}\n")

    summary = {
        "decision": payload["decision"],
        "baseline": payload["baseline"]["candidate_id"],
        "candidate": payload["candidate"]["candidate_id"],
        "comparability_warnings": len(payload["comparability_warnings"]),
        "segment_regressions": len(payload["segment_regressions"]),
        "output_path": str(args.output_path),
    }
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(
            "candidate comparison {decision} | baseline={baseline} | candidate={candidate} | "
            "comparability_warnings={comparability_warnings} | segment_regressions={segment_regressions} | "
            "output={output_path}".format(**summary)
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
