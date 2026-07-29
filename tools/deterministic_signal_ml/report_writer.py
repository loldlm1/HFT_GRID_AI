"""Compact report helpers for schema v8 research datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from schema_contract import CATEGORICAL_COLUMNS, DatasetColumnGroups, PATH_RATIO_OUTCOME_COLUMNS


BUILDER_VERSION = "extremum_engine.schema_v8_dataset_builder.v1"


def _fetch_dicts(connection: duckdb.DuckDBPyConnection, sql: str) -> list[dict[str, Any]]:
    relation = connection.execute(sql)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def build_quality_payload(
    connection: duckdb.DuckDBPyConnection,
    validations,
    counts: dict[str, int],
    target_family: str,
    feature_columns: tuple[str, ...],
) -> dict[str, Any]:
    null_counts = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            f"SELECT '{column}' AS column_name, COUNT(*) - COUNT({column}) AS null_rows FROM training_matrix"
            for column in feature_columns
        ),
    )
    categorical = set(CATEGORICAL_COLUMNS)
    numeric_features = [column for column in feature_columns if column not in categorical]
    feature_ranges = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            f"SELECT '{column}' AS column_name, MIN({column}) AS min_value, MAX({column}) AS max_value, AVG({column}) AS avg_value FROM training_matrix"
            for column in numeric_features
        ),
    )
    warnings = [
        f"{validation.run_id}: {warning}"
        for validation in validations
        for warning in validation.warnings
    ]
    blocking_nulls = sum(int(row["null_rows"] or 0) for row in null_counts)
    return {
        "status": "OK" if not warnings and blocking_nulls == 0 else "OK_WITH_WARNINGS",
        "target_family": target_family,
        "warnings": warnings,
        "blocking_null_feature_rows": blocking_nulls,
        "row_counts": counts,
        "source_runs": [validation.run_id for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "path_label_columns_present": True,
        "join_integrity": {
            "duplicate_feature_ids": sum(validation.duplicate_feature_ids for validation in validations),
            "duplicate_outcome_ids": sum(validation.duplicate_outcome_ids for validation in validations),
            "missing_outcomes": sum(validation.missing_outcomes for validation in validations),
            "missing_features": sum(validation.missing_features for validation in validations),
        },
        "genealogy": _fetch_dicts(
            connection,
            """
SELECT
  COUNT(DISTINCT extremum_cycle_id) AS distinct_cycles,
  COUNT(DISTINCT revision_id) AS distinct_revisions,
  COUNT(DISTINCT attempt_id) AS distinct_attempts,
  SUM(CASE WHEN simulated_path_status = 'CENSORED' THEN 1 ELSE 0 END) AS censored_attempts,
  SUM(CASE WHEN broker_entry_confirmed = 1 THEN 1 ELSE 0 END) AS broker_entered_attempts,
  SUM(CASE WHEN broker_close_confirmed = 1 THEN 1 ELSE 0 END) AS broker_closed_attempts,
  MIN(candidate_depth_percent) AS min_depth_percent,
  MAX(candidate_depth_percent) AS max_depth_percent
FROM engine_attempts
""",
        ),
        "target_distribution": _fetch_dicts(
            connection,
            "SELECT target_terminal_reason AS terminal_reason, COUNT(*) AS rows FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "win_distribution": _fetch_dicts(
            connection,
            "SELECT target_is_win, COUNT(*) AS rows FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "broker_check_support": _fetch_dicts(
            connection,
            """
SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT extremum_attempt_id) AS checked_attempts,
  SUM(CASE WHEN account_margin_mode_supported = 1 THEN 1 ELSE 0 END) AS hedging_rows,
  SUM(CASE WHEN order_check_performed = 1 AND order_check_allowed = 1 THEN 1 ELSE 0 END) AS order_check_allowed_rows,
  SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) AS blocked_rows
FROM execution_checks
""",
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
) -> None:
    groups = DatasetColumnGroups(feature_columns=feature_columns)
    payload = {
        "dataset_id": dataset_id,
        "builder_version": BUILDER_VERSION,
        "target_family": target_family,
        "feature_set_id": feature_set_id,
        "created_at": datetime.now(UTC).isoformat(),
        "phase1_schema_version": schema_version,
        "feature_schema_version": schema_version,
        "source_run_ids": [validation.run_id for validation in validations],
        "source_run_folders": [str(validation.run_path) for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "row_counts": counts,
        "output_files": output_files,
        "feature_columns": list(groups.feature_columns),
        "target_columns": list(groups.target_columns),
        "identity_columns": [
            "schema_version",
            "run_id",
            "config_id",
            "symbol",
            "engine_id",
            "engine_timeframe",
            "extremum_cycle_id",
            "extremum_revision_id",
            "extremum_attempt_id",
            "signal_id",
        ],
        "audit_columns": list(groups.audit_columns),
        "path_ratio_outcome_columns": list(PATH_RATIO_OUTCOME_COLUMNS),
        "excluded_from_training_columns": [
            "terminal_broker_time",
            "terminal_analysis_time",
            "terminal_reason",
            "profit_r",
            "duration_seconds",
            "duration_m1_bars",
            "entry_price",
            "close_price",
            "net_profit",
            "cycle_finalized_broker_time",
            "final_depth_percent",
            "cycle_status",
            *PATH_RATIO_OUTCOME_COLUMNS,
        ],
        "engine_contract": {
            "engine_id": 1,
            "engine_label": "EXTREMUM_V1",
            "engine_timeframe": "PERIOD_M1",
            "cycle_group_columns": ["symbol", "engine_timeframe", "extremum_cycle_id"],
            "point_in_time_only": True,
        },
        "time_contract": {
            "causal_order_column": "entry_broker_time",
            "calendar_feature_column": "entry_analysis_time",
            "conversion": "analysis_time=broker_time+offset_minutes",
        },
        "runtime_approval": "RESEARCH_ONLY_NOT_APPROVED",
    }
    (output_dir / "dataset_manifest.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def write_quality_json(output_dir: Path, quality_payload: dict[str, Any]) -> None:
    (output_dir / "dataset_quality.json").write_text(
        json.dumps(quality_payload, indent=2, sort_keys=True),
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
        "",
        "## Row Counts",
        "",
    ]
    lines.extend(
        f"- `{table}`: {count}"
        for table, count in quality_payload["row_counts"].items()
    )
    lines.extend(["", "## Warnings", ""])
    lines.extend(
        [f"- {warning}" for warning in quality_payload["warnings"]]
        or ["None."]
    )
    (output_dir / "dataset_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
