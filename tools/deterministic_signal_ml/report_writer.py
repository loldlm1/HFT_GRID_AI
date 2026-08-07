"""Deterministic manifests and quality reports for V11 trial-matrix datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from schema_contract import (
    CATEGORICAL_COLUMNS,
    DATASET_CONFIG_KEYS,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    NUMERIC_FEATURE_COLUMNS,
    SUPPORTED_ENGINE_LABEL,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    RunValidation,
)


BUILDER_VERSION = "pivot_fractal.schema_v11_trial_matrix_builder.v1"


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    query: str,
) -> list[dict[str, Any]]:
    relation = connection.execute(query)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def build_quality_payload(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    counts: dict[str, int],
) -> dict[str, Any]:
    support = _fetch_dicts(
        connection,
        """
SELECT
  count(DISTINCT origin_id) AS unique_origins,
  count(*) AS matrix_trial_rows,
  sum(CASE WHEN reentry_index > 0 THEN 1 ELSE 0 END) AS retry_rows,
  sum(CASE WHEN eligibility_status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_rows,
  sum(CASE WHEN eligibility_status <> 'ACTIVE' THEN 1 ELSE 0 END) AS ineligible_rows,
  sum(CASE WHEN terminal_status = 'CENSORED' THEN 1 ELSE 0 END) AS censored_rows
FROM origin_matrix_long
""",
    )[0]
    eligibility = _fetch_dicts(
        connection,
        """
SELECT eligibility_status, ineligible_reason, count(*) AS trial_rows,
       count(DISTINCT origin_id) AS unique_origins
FROM origin_matrix_long
GROUP BY ALL
ORDER BY trial_rows DESC, eligibility_status, ineligible_reason
""",
    )
    policy_performance = _fetch_dicts(
        connection,
        """
SELECT
  sl_policy,
  tp_r_multiple,
  count(*) AS eligible_trial_rows,
  count(DISTINCT origin_id) AS unique_origins,
  avg(virtual_binary_target) AS tp_rate,
  1.0 / (tp_r_multiple + 1.0) AS break_even_tp_rate,
  avg(CASE WHEN virtual_binary_target = 1 THEN tp_r_multiple ELSE -1.0 END)
    AS expected_nominal_r,
  avg(virtual_quote_gross_r) AS average_virtual_quote_gross_r
FROM eligible_virtual_trials
GROUP BY sl_policy, tp_r_multiple
ORDER BY sl_policy, tp_r_multiple
""",
    )
    chain_performance = _fetch_dicts(
        connection,
        """
SELECT
  sl_policy,
  tp_r_multiple,
  count(*) AS policy_chains,
  count(DISTINCT origin_id) AS unique_origins,
  avg(attempts) AS average_attempts,
  avg(losses_before_success) AS average_losses_before_success,
  avg(closed_nominal_r) AS average_closed_nominal_r,
  avg(virtual_quote_gross_r) AS average_virtual_quote_gross_r,
  sum(CASE WHEN censored THEN 1 ELSE 0 END) AS censored_chains,
  sum(CASE WHEN reached_tp THEN 1 ELSE 0 END) AS tp_chains
FROM policy_chains
GROUP BY sl_policy, tp_r_multiple
ORDER BY sl_policy, tp_r_multiple
""",
    )
    broker = _fetch_dicts(
        connection,
        """
SELECT
  count(*) AS broker_outcomes,
  sum(CASE WHEN broker_binary_eligible THEN 1 ELSE 0 END) AS binary_eligible_rows,
  sum(CASE WHEN broker_binary_target = 1 THEN 1 ELSE 0 END) AS tp_rows,
  sum(CASE WHEN broker_binary_target = 0 THEN 1 ELSE 0 END) AS sl_rows,
  avg(broker_gross_profit) AS average_broker_gross_profit,
  avg(broker_net_profit) AS average_broker_net_profit,
  avg(broker_commission) AS average_commission,
  avg(broker_swap) AS average_swap,
  avg(broker_fee) AS average_fee
FROM broker_outcomes
""",
    )[0]
    calibration = _fetch_dicts(
        connection,
        """
SELECT
  count(*) AS paired_rows,
  sum(CASE WHEN strict_pair_eligible THEN 1 ELSE 0 END) AS strict_pairs,
  sum(CASE WHEN strict_pair_eligible AND terminal_agreement THEN 1 ELSE 0 END)
    AS terminal_matches,
  sum(CASE WHEN strict_pair_eligible AND NOT terminal_agreement THEN 1 ELSE 0 END)
    AS terminal_mismatches,
  avg(crossing_close_delta_seconds) AS average_crossing_close_delta_seconds,
  avg(broker_entry_slippage_points) AS average_broker_entry_slippage_points,
  avg(broker_minus_virtual_exit_points) AS average_broker_minus_virtual_exit_points,
  avg(broker_minus_virtual_gross_profit) AS average_broker_minus_virtual_gross_profit,
  avg(broker_minus_virtual_gross_execution_r)
    AS average_broker_minus_virtual_gross_execution_r
FROM broker_virtual_calibration
""",
    )[0]
    calibration_exclusions = _fetch_dicts(
        connection,
        """
SELECT calibration_exclusion_reason, count(*) AS rows
FROM broker_virtual_calibration
WHERE NOT strict_pair_eligible
GROUP BY calibration_exclusion_reason
ORDER BY rows DESC, calibration_exclusion_reason
""",
    )
    chain_terminal_reasons = _fetch_dicts(
        connection,
        """
SELECT
  coalesce(chain_terminal_reason, final_eligibility_status) AS terminal_reason,
  count(*) AS policy_chains,
  count(DISTINCT origin_id) AS unique_origins
FROM policy_chains
GROUP BY ALL
ORDER BY policy_chains DESC, terminal_reason
""",
    )
    return {
        "builder_version": BUILDER_VERSION,
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "research_approval_state": "OFFLINE_RESEARCH_ONLY",
        "outcome_lanes": {
            "virtual": "counterfactual nominal R and OrderCalcProfit gross only",
            "broker": "deal-history gross, costs, and net only",
            "calibration": "broker-parity comparison only; excluded from ML targets",
        },
        "support_warning": (
            "Trial rows are correlated within origins and Macro windows; report unique-origin "
            "support and trial-row support separately."
        ),
        "multiple_comparison_warning": (
            "Policy leaderboards are exploratory until chronological holdout support and "
            "uncertainty are reviewed."
        ),
        "counts": counts,
        "run_ids": [validation.run_id for validation in validations],
        "warnings": [warning for validation in validations for warning in validation.warnings],
        "support": support,
        "eligibility": eligibility,
        "policy_performance": policy_performance,
        "chain_performance": chain_performance,
        "chain_terminal_reasons": chain_terminal_reasons,
        "broker_performance": broker,
        "broker_virtual_calibration": calibration,
        "calibration_exclusions": calibration_exclusions,
    }


def write_dataset_manifest(
    output_dir: Path,
    dataset_id: str,
    validations: list[RunValidation],
    counts: dict[str, int],
    output_files: dict[str, str],
    quality_payload: dict[str, Any],
) -> None:
    baseline = validations[0].manifest
    payload = {
        "dataset_id": dataset_id,
        "created_at_utc": datetime.now(UTC).isoformat(),
        "builder_version": BUILDER_VERSION,
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "research_approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact": False,
        "run_ids": [validation.run_id for validation in validations],
        "configuration": {key: baseline[key] for key in DATASET_CONFIG_KEYS},
        "feature_contract": {
            "model_features": list(MODEL_FEATURE_COLUMNS),
            "categorical_features": list(CATEGORICAL_COLUMNS),
            "numeric_features": list(NUMERIC_FEATURE_COLUMNS),
            "future_only_columns": list(FUTURE_ONLY_COLUMNS),
            "target": "virtual_binary_target",
            "broker_target_separate": True,
            "origin_weight_policy": "sum_to_one_per_origin_within_each_training_subset",
            "grouping_policy": "macro_window_identity_across_runs",
        },
        "counts": counts,
        "files": output_files,
        "quality_summary": {
            "support": quality_payload["support"],
            "broker_virtual_calibration": quality_payload[
                "broker_virtual_calibration"
            ],
        },
    }
    (output_dir / "dataset_manifest.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )


def write_quality_json(output_dir: Path, quality_payload: dict[str, Any]) -> None:
    (output_dir / "quality_report.json").write_text(
        json.dumps(quality_payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )


def write_dataset_report(
    output_dir: Path,
    dataset_id: str,
    quality_payload: dict[str, Any],
) -> None:
    support = quality_payload["support"]
    calibration = quality_payload["broker_virtual_calibration"]
    lines = [
        f"# Dataset Report: {dataset_id}",
        "",
        "- Status: `OFFLINE_RESEARCH_ONLY`",
        f"- Schema: `{quality_payload['schema_version']}`",
        f"- Feature set: `{quality_payload['feature_set_id']}`",
        f"- Unique origins: `{support['unique_origins']}`",
        f"- Matrix trial rows: `{support['matrix_trial_rows']}`",
        f"- Retry rows: `{support['retry_rows']}`",
        f"- Ineligible rows: `{support['ineligible_rows']}`",
        f"- Censored rows: `{support['censored_rows']}`",
        "",
        "## Outcome Boundaries",
        "",
        "Virtual policy targets, broker outcomes, and parity calibration remain separate. ",
        "Virtual gross values are counterfactual and never include broker commission, swap, fee, or net profit.",
        "",
        "## Calibration",
        "",
        f"- Paired rows: `{calibration['paired_rows']}`",
        f"- Strict pairs: `{calibration['strict_pairs']}`",
        f"- Terminal matches: `{calibration['terminal_matches']}`",
        f"- Terminal mismatches: `{calibration['terminal_mismatches']}`",
        "",
        "## Statistical Caution",
        "",
        quality_payload["support_warning"],
        "",
        quality_payload["multiple_comparison_warning"],
        "",
    ]
    (output_dir / "dataset_report.md").write_text("\n".join(lines), encoding="utf-8")
