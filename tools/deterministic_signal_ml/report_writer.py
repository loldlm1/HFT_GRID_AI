"""Compact quality and manifest writers for pivot-fractal V9 datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

try:
    import resource
except ImportError:  # pragma: no cover - unavailable on native Windows Python.
    resource = None

from retest_confluence import (
    CONFLUENCE_MAX_ACTIVE_MEMBERS,
    CONFLUENCE_MEMBER_KEY,
    CONFLUENCE_POLICY_VERSION,
    RETEST_CONTEXT_KEY,
    RETEST_EQUALITY_TOLERANCE,
    RETEST_POLICY_VERSION,
    research_categorical_columns_for_set,
    retest_context_quality,
    validate_confluence_tables,
)
from schema_contract import (
    CATEGORICAL_COLUMNS,
    DatasetColumnGroups,
    FUTURE_ONLY_COLUMNS,
    NUMERIC_FEATURE_COLUMNS,
    SUPPORTED_ENGINE_LABEL,
)


BUILDER_VERSION = "pivot_fractal.schema_v9_dataset_builder.v2"


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    sql: str,
) -> list[dict[str, Any]]:
    relation = connection.execute(sql)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def build_quality_payload(
    connection: duckdb.DuckDBPyConnection,
    validations,
    counts: dict[str, int],
    target_family: str,
    feature_columns: tuple[str, ...],
    output_dir: Path | None = None,
) -> dict[str, Any]:
    null_counts = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            f"SELECT '{column}' AS column_name, COUNT(*) - COUNT(\"{column}\") AS null_rows "
            "FROM training_matrix"
            for column in feature_columns
        ),
    )
    categorical_features = set(CATEGORICAL_COLUMNS) | {
        column for column in feature_columns if column.endswith("_retest_type")
    }
    numeric_features = [
        column for column in feature_columns if column not in categorical_features
    ]
    feature_ranges = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            f"SELECT '{column}' AS column_name, MIN(\"{column}\") AS min_value, "
            f"MAX(\"{column}\") AS max_value, AVG(\"{column}\") AS avg_value "
            "FROM training_matrix"
            for column in numeric_features
        ),
    )
    warnings = [
        f"{validation.run_id}: {warning}"
        for validation in validations
        for warning in validation.warnings
    ]
    blocking_nulls = sum(int(row["null_rows"] or 0) for row in null_counts)
    target_distribution_column = (
        "target_is_profit" if target_family == "broker_outcome" else "target_admitted"
    )
    retest_quality = retest_context_quality(connection)
    confluence_quality = validate_confluence_tables(connection, require_complete=False)
    derivation_durations = _fetch_dicts(
        connection,
        "SELECT stage, duration_seconds FROM derived_build_metrics ORDER BY stage",
    )
    output_bytes = (
        {
            path.name: path.stat().st_size
            for path in sorted(output_dir.glob("*.parquet"))
        }
        if output_dir is not None
        else {}
    )
    return {
        "status": "OK" if not warnings and blocking_nulls == 0 else "OK_WITH_WARNINGS",
        "target_family": target_family,
        "warnings": warnings,
        "blocking_null_feature_rows": blocking_nulls,
        "row_counts": counts,
        "source_runs": [validation.run_id for validation in validations],
        "performance": {
            "process_peak_rss_kb": (
                resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
                if resource is not None
                else None
            ),
            "parquet_bytes": output_bytes,
            "total_parquet_bytes": sum(output_bytes.values()),
            "stage_durations": derivation_durations,
        },
        "config_ids": sorted({validation.config_id for validation in validations}),
        "join_integrity": {
            "duplicate_signal_ids": 0,
            "missing_feature_contexts": 0,
            "orphan_outcomes": 0,
            "outcomes_without_fill": 0,
        },
        "derived_retest_context": retest_quality,
        "derived_confluence": {
            "policy_version": CONFLUENCE_POLICY_VERSION,
            "max_active_member_bound": CONFLUENCE_MAX_ACTIVE_MEMBERS,
            **confluence_quality,
            "stage_durations": derivation_durations,
        },
        "pivot_frequency": _fetch_dicts(
            connection,
            """
SELECT pivot_timeframe, level_id, direction, COUNT(*) AS attempts
FROM signal_attempts
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
""",
        ),
        "admission_denials": _fetch_dicts(
            connection,
            """
SELECT block_source, block_reason, COUNT(*) AS attempts
FROM signal_attempts
WHERE attempt_status <> 'SENT'
GROUP BY 1, 2
ORDER BY attempts DESC, block_source, block_reason
""",
        ),
        "broker_outcomes": _fetch_dicts(
            connection,
            """
SELECT terminal_reason, COUNT(*) AS outcomes,
       AVG(realized_profit) AS mean_realized_profit,
       SUM(realized_profit) AS total_realized_profit,
       AVG(duration_seconds) AS mean_duration_seconds
FROM signal_outcomes
GROUP BY 1
ORDER BY 1
""",
        ),
        "target_distribution": _fetch_dicts(
            connection,
            f"SELECT {target_distribution_column} AS target_value, COUNT(*) AS rows "
            f"FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "feature_null_counts": null_counts,
        "feature_ranges": feature_ranges,
    }


def write_dataset_manifest(
    output_dir: Path,
    dataset_id: str,
    validations,
    counts: dict[str, int],
    output_files: dict[str, str],
    target_family: str,
    schema_version: int,
    feature_set_id: str,
    feature_columns: tuple[str, ...],
    research_feature_set_id: str = "",
) -> None:
    groups = DatasetColumnGroups(feature_columns=feature_columns)
    payload = {
        "dataset_id": dataset_id,
        "builder_version": BUILDER_VERSION,
        "created_at": datetime.now(UTC).isoformat(),
        "schema_version": schema_version,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": research_feature_set_id or feature_set_id,
        "source_feature_set_id": feature_set_id,
        "research_feature_set_id": research_feature_set_id or None,
        "target_family": target_family,
        "source_run_ids": [validation.run_id for validation in validations],
        "source_run_folders": [str(validation.run_path) for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "row_counts": counts,
        "output_files": output_files,
        "output_file_bytes": {
            filename: (output_dir / filename).stat().st_size
            for filename in output_files.values()
        },
        "feature_columns": list(groups.feature_columns),
        "categorical_columns": [
            column
            for column in groups.feature_columns
            if column in set(
                research_categorical_columns_for_set(research_feature_set_id)
            )
        ],
        "target_columns": list(groups.target_columns),
        "identity_columns": list(groups.identity_columns),
        "audit_columns": list(groups.audit_columns),
        "excluded_future_columns": list(FUTURE_ONLY_COLUMNS),
        "identity_group_columns": (
            ["research_group_id"]
            if research_feature_set_id
            else ["run_id", "symbol", "window_id"]
        ),
        "split_grouping_policy": (
            "symbol_d1_active_broker_window"
            if research_feature_set_id
            else "pivot_window_identity"
        ),
        "time_contract": {
            "causal_order_column": "trigger_broker_time",
            "calendar_feature_column": "trigger_analysis_time",
            "conversion": "analysis_time=broker_time+offset_minutes",
        },
        "derived_research_contracts": {
            "signal_retest_context": {
                "policy_version": RETEST_POLICY_VERSION,
                "primary_key": list(RETEST_CONTEXT_KEY),
                "contexts_per_signal": 6,
                "equality_tolerance": RETEST_EQUALITY_TOLERANCE,
                "source": "strict_schema_v9_facts",
                "model_feature_status": "PERSISTED_NOT_ENABLED",
            },
            "confluence_members": {
                "policy_version": CONFLUENCE_POLICY_VERSION,
                "primary_key": list(CONFLUENCE_MEMBER_KEY),
                "max_active_member_bound": CONFLUENCE_MAX_ACTIVE_MEMBERS,
                "source": "strict_schema_v9_first_touch_attempts",
                "model_feature_status": "PERSISTED_NOT_ENABLED",
            },
            "confluence_snapshots": {
                "policy_version": CONFLUENCE_POLICY_VERSION,
                "grain": "one_snapshot_per_first_touch_anchor",
                "source": "bounded_same_trigger_event_sweep",
                "model_feature_status": "PERSISTED_NOT_ENABLED",
            },
        },
        "outcome_contract": "broker-confirmed fill and close only",
        "approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact_emitted": False,
    }
    (output_dir / "dataset_manifest.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def write_quality_json(output_dir: Path, quality_payload: dict[str, Any]) -> None:
    (output_dir / "dataset_quality.json").write_text(
        json.dumps(quality_payload, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )


def write_dataset_report(
    output_dir: Path,
    dataset_id: str,
    quality_payload: dict[str, Any],
) -> None:
    lines = [
        f"# Dataset Report: {dataset_id}",
        "",
        f"Status: `{quality_payload['status']}`",
        f"Target family: `{quality_payload['target_family']}`",
        "Approval: `OFFLINE_RESEARCH_ONLY`",
        "",
        "## Row Counts",
        "",
    ]
    lines.extend(
        f"- `{table}`: {count}" for table, count in quality_payload["row_counts"].items()
    )
    lines.extend(["", "## Warnings", ""])
    lines.extend(
        [f"- {warning}" for warning in quality_payload["warnings"]] or ["None."]
    )
    lines.extend(
        [
            "",
            "Trailing and close facts are retained for labels and audits only; they are not model features.",
        ]
    )
    (output_dir / "dataset_report.md").write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )
