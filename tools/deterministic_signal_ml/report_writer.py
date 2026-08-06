"""Deterministic manifests and compact quality reports for V10 datasets."""

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


BUILDER_VERSION = "pivot_fractal.schema_v10_dataset_builder.v1"


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
    attempt_status = _fetch_dicts(
        connection,
        """
SELECT attempt_status, COUNT(*) AS rows
FROM signal_attempts
GROUP BY 1
ORDER BY 1
""",
    )
    block_reasons = _fetch_dicts(
        connection,
        """
SELECT block_source, block_reason, COUNT(*) AS rows
FROM signal_attempts
WHERE block_reason IS NOT NULL
GROUP BY 1, 2
ORDER BY rows DESC, block_source, block_reason
""",
    )
    exclusions = _fetch_dicts(
        connection,
        """
SELECT terminal_reason, exclusion_reason, COUNT(*) AS rows
FROM signal_outcomes
WHERE NOT binary_eligible
GROUP BY 1, 2
ORDER BY rows DESC, terminal_reason, exclusion_reason
""",
    )
    binary = _fetch_dicts(
        connection,
        """
SELECT
  COUNT(*) AS rows,
  SUM(CASE WHEN binary_target = 1 THEN 1 ELSE 0 END) AS tp_rows,
  SUM(CASE WHEN binary_target = 0 THEN 1 ELSE 0 END) AS sl_rows,
  AVG(binary_target) AS tp_rate,
  AVG(gross_profit) AS average_gross_profit,
  AVG(net_profit) AS average_net_profit,
  AVG(entry_slippage_points) AS average_entry_slippage_points,
  AVG(exit_slippage_points) AS average_exit_slippage_points
FROM binary_outcomes
""",
    )[0]
    feature_completeness = _fetch_dicts(
        connection,
        """
SELECT
  COUNT(*) AS attempts,
  SUM(CASE WHEN feature_snapshot_complete THEN 1 ELSE 0 END) AS complete_rows,
  SUM(CASE WHEN NOT feature_snapshot_complete THEN 1 ELSE 0 END) AS incomplete_rows
FROM signal_attempts
""",
    )[0]
    return {
        "builder_version": BUILDER_VERSION,
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "run_ids": [validation.run_id for validation in validations],
        "table_counts": counts,
        "feature_completeness": feature_completeness,
        "binary_cohort": binary,
        "attempt_status": attempt_status,
        "block_reasons": block_reasons,
        "excluded_outcomes": exclusions,
        "integrity": {
            "duplicate_identity_count": 0,
            "referential_integrity_error_count": 0,
            "row_integrity_error_count": 0,
            "future_feature_overlap": sorted(
                set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS)
            ),
        },
    }


def write_dataset_manifest(
    output_dir: Path,
    dataset_id: str,
    validations: list[RunValidation],
    counts: dict[str, int],
    output_files: dict[str, str],
    quality: dict[str, Any],
) -> dict[str, Any]:
    baseline = validations[0].manifest
    manifest = {
        "dataset_id": dataset_id,
        "builder_version": BUILDER_VERSION,
        "created_at": datetime.now(UTC).isoformat(),
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "feature_columns": list(MODEL_FEATURE_COLUMNS),
        "categorical_columns": list(CATEGORICAL_COLUMNS),
        "numeric_feature_columns": list(NUMERIC_FEATURE_COLUMNS),
        "future_only_columns": list(FUTURE_ONLY_COLUMNS),
        "target_column": "binary_target",
        "target_policy": "feature_complete_consistent_broker_tp_or_sl_only",
        "split_grouping_policy": "macro_window_identity_across_runs",
        "split_group_columns": [
            "symbol",
            "macro_timeframe",
            "active_bar_open_broker_time",
        ],
        "close_time_purge_policy": (
            "train_close_broker_time_strictly_before_validation_min_trigger_broker_time"
        ),
        "run_ids": [validation.run_id for validation in validations],
        "config": {key: baseline[key] for key in DATASET_CONFIG_KEYS},
        "table_counts": counts,
        "output_files": output_files,
        "binary_rows": quality["binary_cohort"]["rows"],
        "approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact_emitted": False,
    }
    (output_dir / "dataset_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    return manifest


def write_quality_json(output_dir: Path, quality_payload: dict[str, Any]) -> None:
    (output_dir / "data_quality.json").write_text(
        json.dumps(quality_payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )


def write_dataset_report(
    output_dir: Path,
    dataset_id: str,
    quality_payload: dict[str, Any],
) -> None:
    binary = quality_payload["binary_cohort"]
    completeness = quality_payload["feature_completeness"]
    lines = [
        f"# Pivot V10 Dataset: {dataset_id}",
        "",
        "Approval: `OFFLINE_RESEARCH_ONLY`",
        f"Runs: `{len(quality_payload['run_ids'])}`",
        f"Research rows: `{quality_payload['table_counts']['research_matrix']}`",
        f"Binary TP/SL rows: `{binary['rows']}`",
        f"Binary TP rate: `{binary['tp_rate']}`",
        "",
        "## Completeness",
        "",
        f"- Complete attempts: `{completeness['complete_rows']}`",
        f"- Incomplete attempts: `{completeness['incomplete_rows']}`",
        "",
        "## Boundaries",
        "",
        "- Model inputs are trigger-time categorical and normalized continuous facts only.",
        "- Denied, failed, censored, manual, mixed, stop-out, expert, and other outcomes remain audit facts.",
        "- Only feature-complete broker TP/SL outcomes enter `binary_outcomes.parquet`.",
        "- This dataset does not authorize or emit any MT5 runtime model.",
    ]
    (output_dir / "dataset_report.md").write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )
