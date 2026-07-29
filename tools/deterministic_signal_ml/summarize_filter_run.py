"""Summarize and validate an MQL5 ML shadow/filter run folder."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path


NULL_TOKEN = r"\N"
REQUIRED_FILES = (
    "shadow_manifest.tsv",
    "shadow_predictions.tsv",
    "shadow_outcomes.tsv",
    "shadow_summary.tsv",
)
ARBITRATION_FILE = "arbitration_decisions.tsv"


class FilterRunSummaryError(RuntimeError):
    """Raised when a run folder is missing or internally inconsistent."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shadow-run-path", required=True, help="Folder containing shadow/filter TSV files.")
    parser.add_argument(
        "--require-arbitration",
        action="store_true",
        help="Require and validate arbitration_decisions.tsv plus arbitration summary counters.",
    )
    parser.add_argument(
        "--execution-checks-path",
        help="Optional schema v8 execution_checks.tsv used to report broker blocks separately.",
    )
    return parser


def duplicate_header_count(path: Path) -> int:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise FilterRunSummaryError(f"Empty TSV file: {path}")
    header = lines[0]
    return sum(1 for line in lines[1:] if line == header)


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def read_manifest(path: Path) -> dict[str, str]:
    rows = read_tsv(path)
    if not rows:
        raise FilterRunSummaryError("Manifest has no rows")
    values: dict[str, str] = {}
    for row in rows:
        key = row.get("key", "")
        if key:
            values[key] = row.get("value", "")
    return values


def require_int(row: dict[str, str], field: str) -> int:
    value = row.get(field)
    if value is None or value == "":
        raise FilterRunSummaryError(f"Missing summary field: {field}")
    try:
        return int(value)
    except ValueError as exc:
        raise FilterRunSummaryError(f"Invalid integer for {field}: {value}") from exc


def optional_int(row: dict[str, str], field: str) -> int | None:
    value = row.get(field)
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError as exc:
        raise FilterRunSummaryError(f"Invalid integer for {field}: {value}") from exc


def is_true(value: str) -> bool:
    return value.lower() == "true"


def validate_required_files(run_path: Path, *, require_arbitration: bool) -> dict[str, Path]:
    if not run_path.is_dir():
        raise FilterRunSummaryError(f"Run folder does not exist: {run_path}")
    paths = {name: run_path / name for name in REQUIRED_FILES}
    arbitration_path = run_path / ARBITRATION_FILE
    if require_arbitration or arbitration_path.exists():
        paths[ARBITRATION_FILE] = arbitration_path
    missing = [str(path) for path in paths.values() if not path.exists()]
    if missing:
        raise FilterRunSummaryError("Missing run files: " + ", ".join(missing))
    duplicate_headers = {name: duplicate_header_count(path) for name, path in paths.items()}
    bad_headers = [f"{name}={count}" for name, count in duplicate_headers.items() if count > 0]
    if bad_headers:
        raise FilterRunSummaryError("Duplicate header rows: " + ", ".join(bad_headers))
    return paths


def validate_arbitration_rows(
    rows: list[dict[str, str]],
    summary: dict[str, str],
    *,
    require_arbitration: bool,
) -> dict[str, object]:
    actions = Counter(row.get("arbitration_action", "") or NULL_TOKEN for row in rows)
    group_counts = Counter(row.get("arbitration_group_id", "") for row in rows if row.get("arbitration_group_id", ""))
    selected_rows = [row for row in rows if row.get("arbitration_action") == "SELECTED"]

    selected_by_group = Counter(row.get("arbitration_group_id", "") for row in selected_rows)
    bad_selected_groups = [group_id for group_id in group_counts if selected_by_group[group_id] != 1]
    if bad_selected_groups:
        raise FilterRunSummaryError("Arbitration groups without exactly one selected row: " + ", ".join(bad_selected_groups))

    if require_arbitration and rows and not selected_rows:
        raise FilterRunSummaryError("Arbitration rows exist but no SELECTED rows were found")

    group_rows = optional_int(summary, "arbitration_group_rows")
    single_groups = optional_int(summary, "arbitration_single_candidate_groups")
    multi_groups = optional_int(summary, "arbitration_multi_candidate_groups")
    selected_count = optional_int(summary, "arbitration_selected_rows")
    blocked_count = optional_int(summary, "arbitration_blocked_rows")
    classifier_ties = optional_int(summary, "arbitration_classifier_tie_rows")
    regressor_ties = optional_int(summary, "arbitration_regressor_tie_rows")
    strategy_ties = optional_int(summary, "arbitration_strategy_tie_break_rows")

    if require_arbitration:
        required_fields = {
            "arbitration_group_rows": group_rows,
            "arbitration_single_candidate_groups": single_groups,
            "arbitration_multi_candidate_groups": multi_groups,
            "arbitration_selected_rows": selected_count,
            "arbitration_blocked_rows": blocked_count,
        }
        missing_fields = [name for name, value in required_fields.items() if value is None]
        if missing_fields:
            raise FilterRunSummaryError("Missing arbitration summary fields: " + ", ".join(missing_fields))

    row_group_rows = len(group_counts)
    row_single_groups = sum(1 for count in group_counts.values() if count == 1)
    row_multi_groups = sum(1 for count in group_counts.values() if count > 1)

    if group_rows is not None and group_rows != row_group_rows:
        raise FilterRunSummaryError("Summary arbitration_group_rows does not match arbitration TSV")
    if single_groups is not None and single_groups != row_single_groups:
        raise FilterRunSummaryError("Summary arbitration_single_candidate_groups does not match arbitration TSV")
    if multi_groups is not None and multi_groups != row_multi_groups:
        raise FilterRunSummaryError("Summary arbitration_multi_candidate_groups does not match arbitration TSV")
    if selected_count is not None and selected_count != actions["SELECTED"]:
        raise FilterRunSummaryError("Summary arbitration_selected_rows does not match arbitration TSV")
    if blocked_count is not None and blocked_count != actions["BLOCKED"]:
        raise FilterRunSummaryError("Summary arbitration_blocked_rows does not match arbitration TSV")

    selected_rank_reasons = Counter(row.get("rank_reason", "") for row in selected_rows)
    row_classifier_ties = (
        selected_rank_reasons["classifier_tie_regressor_score"]
        + selected_rank_reasons["score_tie_strategy_priority"]
        + selected_rank_reasons["deterministic_fallback"]
    )
    row_regressor_ties = selected_rank_reasons["score_tie_strategy_priority"] + selected_rank_reasons["deterministic_fallback"]
    row_strategy_ties = selected_rank_reasons["score_tie_strategy_priority"]
    if classifier_ties is not None and classifier_ties != row_classifier_ties:
        raise FilterRunSummaryError("Summary arbitration_classifier_tie_rows does not match arbitration TSV")
    if regressor_ties is not None and regressor_ties != row_regressor_ties:
        raise FilterRunSummaryError("Summary arbitration_regressor_tie_rows does not match arbitration TSV")
    if strategy_ties is not None and strategy_ties != row_strategy_ties:
        raise FilterRunSummaryError("Summary arbitration_strategy_tie_break_rows does not match arbitration TSV")

    return {
        "arbitration_rows": len(rows),
        "arbitration_groups": row_group_rows,
        "arbitration_single_groups": row_single_groups,
        "arbitration_multi_groups": row_multi_groups,
        "arbitration_actions": actions,
    }


def summarize(
    run_path: Path,
    *,
    require_arbitration: bool = False,
    execution_checks_path: Path | None = None,
) -> dict[str, object]:
    paths = validate_required_files(run_path, require_arbitration=require_arbitration)
    manifest = read_manifest(paths["shadow_manifest.tsv"])
    predictions = read_tsv(paths["shadow_predictions.tsv"])
    outcomes = read_tsv(paths["shadow_outcomes.tsv"])
    summary_rows = read_tsv(paths["shadow_summary.tsv"])
    if len(summary_rows) != 1:
        raise FilterRunSummaryError(f"Expected exactly one summary row, found {len(summary_rows)}")
    summary = summary_rows[0]

    prediction_rows = len(predictions)
    outcome_rows = len(outcomes)
    if require_int(summary, "prediction_rows") != prediction_rows:
        raise FilterRunSummaryError("Summary prediction_rows does not match predictions TSV")
    if require_int(summary, "outcome_rows") != outcome_rows:
        raise FilterRunSummaryError("Summary outcome_rows does not match outcomes TSV")

    invalid_feature_rows = sum(1 for row in predictions if not is_true(row.get("feature_valid", "false")))
    summary_invalid = require_int(summary, "invalid_feature_rows")
    if summary_invalid != invalid_feature_rows:
        raise FilterRunSummaryError("Summary invalid_feature_rows does not match predictions TSV")

    recommendations = Counter(row.get("recommendation", "") or NULL_TOKEN for row in predictions)
    admission_actions = Counter(row.get("admission_action", "") or "LEGACY" for row in predictions)
    filter_reasons = Counter(row.get("filter_reason", "") or NULL_TOKEN for row in predictions)
    unavailable_rows = sum(1 for row in predictions if not is_true(row.get("model_available", "false")))
    scored_rows = sum(1 for row in predictions if row.get("classifier_score", "") not in ("", NULL_TOKEN))

    filter_allow_rows = optional_int(summary, "filter_allow_rows")
    filter_block_rows = optional_int(summary, "filter_block_rows")
    filter_invalid_feature_blocks = optional_int(summary, "filter_invalid_feature_blocks")
    filter_unavailable_blocks = optional_int(summary, "filter_unavailable_blocks")

    if filter_allow_rows is not None and filter_allow_rows != admission_actions["ALLOW"]:
        raise FilterRunSummaryError("Summary filter_allow_rows does not match prediction actions")
    if filter_block_rows is not None and filter_block_rows != admission_actions["BLOCK"]:
        raise FilterRunSummaryError("Summary filter_block_rows does not match prediction actions")
    if filter_invalid_feature_blocks is not None:
        row_invalid_blocks = sum(
            1
            for row in predictions
            if row.get("admission_action") == "BLOCK" and not is_true(row.get("feature_valid", "false"))
        )
        if filter_invalid_feature_blocks != row_invalid_blocks:
            raise FilterRunSummaryError("Summary filter_invalid_feature_blocks does not match prediction actions")
    if filter_unavailable_blocks is not None:
        row_unavailable_blocks = sum(
            1
            for row in predictions
            if row.get("admission_action") == "BLOCK" and not is_true(row.get("model_available", "false"))
        )
        if filter_unavailable_blocks != row_unavailable_blocks:
            raise FilterRunSummaryError("Summary filter_unavailable_blocks does not match prediction actions")

    arbitration_rows = read_tsv(paths[ARBITRATION_FILE]) if ARBITRATION_FILE in paths else []
    arbitration_report = validate_arbitration_rows(
        arbitration_rows,
        summary,
        require_arbitration=require_arbitration,
    )
    broker_block_reasons: Counter[str] = Counter()
    tester_policy_block_reasons: Counter[str] = Counter()
    if execution_checks_path is not None:
        if not execution_checks_path.is_file():
            raise FilterRunSummaryError(f"Execution checks file does not exist: {execution_checks_path}")
        for row in read_tsv(execution_checks_path):
            if row.get("allowed") == "0":
                reason = row.get("block_source", "") or row.get("block_reason", "") or NULL_TOKEN
                if row.get("check_phase") == "FILTER_RESULT" or row.get("block_source") in {
                    "ml_filter",
                    "pattern_audit",
                }:
                    tester_policy_block_reasons[reason] += 1
                else:
                    broker_block_reasons[reason] += 1

    return {
        "shadow_run_id": manifest.get("shadow_run_id", ""),
        "export_id": manifest.get("export_id", ""),
        "model_id": manifest.get("model_id", ""),
        "mode": manifest.get("mode", ""),
        "prediction_rows": prediction_rows,
        "outcome_rows": outcome_rows,
        "scored_rows": scored_rows,
        "unavailable_rows": unavailable_rows,
        "recommendations": recommendations,
        "admission_actions": admission_actions,
        "filter_reasons": filter_reasons,
        "broker_block_reasons": broker_block_reasons,
        "tester_policy_block_reasons": tester_policy_block_reasons,
        "export_status": summary.get("export_status", ""),
        **arbitration_report,
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        report = summarize(
            Path(args.shadow_run_path),
            require_arbitration=args.require_arbitration,
            execution_checks_path=(Path(args.execution_checks_path) if args.execution_checks_path else None),
        )
    except FilterRunSummaryError as exc:
        parser.exit(1, f"filter run summary FAIL | {exc}\n")

    recommendations = report["recommendations"]
    admission_actions = report["admission_actions"]
    arbitration_actions = report["arbitration_actions"]
    broker_blocks = report["broker_block_reasons"]
    tester_policy_blocks = report["tester_policy_block_reasons"]
    print(
        "filter run summary PASS | "
        f"run_id={report['shadow_run_id']} | "
        f"mode={report['mode']} | "
        f"export_id={report['export_id']} | "
        f"predictions={report['prediction_rows']} | "
        f"outcomes={report['outcome_rows']} | "
        f"scored={report['scored_rows']} | "
        f"unavailable_rows={report['unavailable_rows']} | "
        f"recommendation_ALLOW={recommendations['ALLOW']} | "
        f"recommendation_BLOCK={recommendations['BLOCK']} | "
        f"admission_ALLOW={admission_actions['ALLOW']} | "
        f"admission_BLOCK={admission_actions['BLOCK']} | "
        f"arbitration_groups={report['arbitration_groups']} | "
        f"arbitration_multi_groups={report['arbitration_multi_groups']} | "
        f"arbitration_SELECTED={arbitration_actions['SELECTED']} | "
        f"arbitration_BLOCKED={arbitration_actions['BLOCKED']} | "
        f"broker_check_blocks={sum(broker_blocks.values())} | "
        f"tester_policy_blocks={sum(tester_policy_blocks.values())} | "
        f"tester_filter_blocks={admission_actions['BLOCK']} | "
        f"export_status={report['export_status']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
