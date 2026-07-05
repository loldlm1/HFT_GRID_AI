"""Report helpers for deterministic signal local datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from schema_contract import DatasetColumnGroups, MODEL_FEATURE_COLUMNS, SUPPORTED_SCHEMA_VERSION


BUILDER_VERSION = "phase2.dataset_builder.v1"


def _fetch_dicts(connection: duckdb.DuckDBPyConnection, sql: str) -> list[dict[str, Any]]:
    columns = [column[0] for column in connection.execute(sql).description]
    return [dict(zip(columns, row)) for row in connection.fetchall()]


def _scalar(connection: duckdb.DuckDBPyConnection, sql: str) -> Any:
    return connection.execute(sql).fetchone()[0]


def build_quality_payload(
    connection: duckdb.DuckDBPyConnection,
    validations,
    counts: dict[str, int],
) -> dict[str, Any]:
    null_counts = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            [
                f"SELECT '{column}' AS column_name, COUNT(*) - COUNT({column}) AS null_rows FROM training_matrix"
                for column in MODEL_FEATURE_COLUMNS
            ]
        ),
    )
    feature_ranges = _fetch_dicts(
        connection,
        """
SELECT 'sl_fib_raw' AS column_name, MIN(sl_fib_raw) AS min_value, MAX(sl_fib_raw) AS max_value, AVG(sl_fib_raw) AS avg_value FROM training_matrix
UNION ALL SELECT 'entry_fib_raw', MIN(entry_fib_raw), MAX(entry_fib_raw), AVG(entry_fib_raw) FROM training_matrix
UNION ALL SELECT 'low_chain_score_3', MIN(low_chain_score_3), MAX(low_chain_score_3), AVG(low_chain_score_3) FROM training_matrix
UNION ALL SELECT 'low_chain_score_5', MIN(low_chain_score_5), MAX(low_chain_score_5), AVG(low_chain_score_5) FROM training_matrix
UNION ALL SELECT 'low_chain_score_10', MIN(low_chain_score_10), MAX(low_chain_score_10), AVG(low_chain_score_10) FROM training_matrix
UNION ALL SELECT 'high_chain_score_3', MIN(high_chain_score_3), MAX(high_chain_score_3), AVG(high_chain_score_3) FROM training_matrix
UNION ALL SELECT 'high_chain_score_5', MIN(high_chain_score_5), MAX(high_chain_score_5), AVG(high_chain_score_5) FROM training_matrix
UNION ALL SELECT 'high_chain_score_10', MIN(high_chain_score_10), MAX(high_chain_score_10), AVG(high_chain_score_10) FROM training_matrix
""",
    )
    warnings: list[str] = []
    for validation in validations:
        warnings.extend([f"{validation.run_id}: {warning}" for warning in validation.warnings])
    blocking_null_feature_rows = sum(int(row["null_rows"] or 0) for row in null_counts)

    return {
        "status": "OK" if blocking_null_feature_rows == 0 else "OK_WITH_WARNINGS",
        "warnings": warnings,
        "blocking_null_feature_rows": blocking_null_feature_rows,
        "row_counts": counts,
        "source_runs": [validation.run_id for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "join_integrity": {
            "duplicate_feature_ids": sum(validation.duplicate_feature_ids for validation in validations),
            "duplicate_outcome_ids": sum(validation.duplicate_outcome_ids for validation in validations),
            "missing_outcomes": sum(validation.missing_outcomes for validation in validations),
            "missing_features": sum(validation.missing_features for validation in validations),
        },
        "target_distribution": _fetch_dicts(
            connection,
            "SELECT target_terminal_reason AS terminal_reason, COUNT(*) AS rows FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "win_distribution": _fetch_dicts(
            connection,
            "SELECT target_is_win, COUNT(*) AS rows FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "strategy_distribution": _fetch_dicts(
            connection,
            "SELECT strategy_label, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "direction_distribution": _fetch_dicts(
            connection,
            "SELECT direction, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "source_type_distribution": _fetch_dicts(
            connection,
            "SELECT source_type, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
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
) -> None:
    column_groups = DatasetColumnGroups()
    payload = {
        "dataset_id": dataset_id,
        "builder_version": BUILDER_VERSION,
        "created_at": datetime.now(UTC).isoformat(),
        "phase1_schema_version": SUPPORTED_SCHEMA_VERSION,
        "source_run_ids": [validation.run_id for validation in validations],
        "source_run_folders": [str(validation.run_path) for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "row_counts": counts,
        "output_files": output_files,
        "feature_columns": list(column_groups.feature_columns),
        "target_columns": list(column_groups.target_columns),
        "identity_columns": list(column_groups.identity_columns),
        "audit_columns": list(column_groups.audit_columns),
        "excluded_from_training_columns": [
            "terminal_time",
            "terminal_reason",
            "profit_r",
            "duration_seconds",
            "duration_m1_bars",
            "entry_price",
            "close_price",
            "net_profit",
        ],
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


def _markdown_table(rows: list[dict[str, Any]], columns: tuple[str, ...]) -> list[str]:
    if not rows:
        return ["No rows."]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join(["---"] * len(columns)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(column, "")) for column in columns) + " |")
    return lines


def write_dataset_report(
    output_dir: Path,
    dataset_id: str,
    quality_payload: dict[str, Any],
) -> None:
    lines: list[str] = [
        f"# Dataset Report: {dataset_id}",
        "",
        f"Status: `{quality_payload['status']}`",
        "",
        "## Row Counts",
        "",
    ]
    for key, value in quality_payload["row_counts"].items():
        lines.append(f"- `{key}`: {value}")
    lines.extend(
        [
            "",
            "## Join Integrity",
            "",
        ]
    )
    for key, value in quality_payload["join_integrity"].items():
        lines.append(f"- `{key}`: {value}")

    lines.extend(["", "## Target Distribution", ""])
    lines.extend(_markdown_table(quality_payload["target_distribution"], ("terminal_reason", "rows")))
    lines.extend(["", "## Win Distribution", ""])
    lines.extend(_markdown_table(quality_payload["win_distribution"], ("target_is_win", "rows")))
    lines.extend(["", "## Strategy Summary", ""])
    lines.extend(_markdown_table(quality_payload["strategy_distribution"], ("strategy_label", "rows", "avg_profit_r")))
    lines.extend(["", "## Direction Summary", ""])
    lines.extend(_markdown_table(quality_payload["direction_distribution"], ("direction", "rows", "avg_profit_r")))
    lines.extend(["", "## Source Type Summary", ""])
    lines.extend(_markdown_table(quality_payload["source_type_distribution"], ("source_type", "rows", "avg_profit_r")))
    lines.extend(["", "## Feature Null Counts", ""])
    lines.extend(_markdown_table(quality_payload["feature_null_counts"], ("column_name", "null_rows")))
    lines.extend(["", "## Feature Ranges", ""])
    lines.extend(_markdown_table(quality_payload["feature_ranges"], ("column_name", "min_value", "max_value", "avg_value")))

    if quality_payload["warnings"]:
        lines.extend(["", "## Warnings", ""])
        for warning in quality_payload["warnings"]:
            lines.append(f"- {warning}")

    (output_dir / "dataset_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
