"""Report helpers for deterministic signal local datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from schema_contract import (
    CATEGORICAL_COLUMNS,
    DatasetColumnGroups,
    PATH_RATIO_OUTCOME_COLUMNS,
)


BUILDER_VERSION = "phase5.schema_v5_numeric_dataset_builder.v1"


def _fetch_dicts(connection: duckdb.DuckDBPyConnection, sql: str) -> list[dict[str, Any]]:
    columns = [column[0] for column in connection.execute(sql).description]
    return [dict(zip(columns, row)) for row in connection.fetchall()]


def _scalar(connection: duckdb.DuckDBPyConnection, sql: str) -> Any:
    return connection.execute(sql).fetchone()[0]


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
            [
                f"SELECT '{column}' AS column_name, COUNT(*) - COUNT({column}) AS null_rows FROM training_matrix"
                for column in feature_columns
            ]
        ),
    )
    categorical_set = set(CATEGORICAL_COLUMNS)
    range_columns = [column for column in feature_columns if column not in categorical_set]
    feature_ranges = _fetch_dicts(
        connection,
        " UNION ALL ".join(
            [
                f"SELECT '{column}' AS column_name, MIN({column}) AS min_value, MAX({column}) AS max_value, AVG({column}) AS avg_value FROM training_matrix"
                for column in range_columns
            ]
        ),
    )
    warnings: list[str] = []
    for validation in validations:
        warnings.extend([f"{validation.run_id}: {warning}" for warning in validation.warnings])
    blocking_null_feature_rows = sum(int(row["null_rows"] or 0) for row in null_counts)

    return {
        "status": "OK" if blocking_null_feature_rows == 0 else "OK_WITH_WARNINGS",
        "target_family": target_family,
        "warnings": warnings,
        "blocking_null_feature_rows": blocking_null_feature_rows,
        "row_counts": counts,
        "source_runs": [validation.run_id for validation in validations],
        "config_ids": sorted({validation.config_id for validation in validations}),
        "path_label_columns_present": all(validation.path_label_columns_present for validation in validations),
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
        "path_status_distribution": _fetch_dicts(
            connection,
            "SELECT path_status, COUNT(*) AS rows FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "path_target_support": _fetch_dicts(
            connection,
            """
SELECT
  SUM(CASE WHEN hit_1r_before_sl = 1 THEN 1 ELSE 0 END) AS hit_1r_rows,
  SUM(CASE WHEN hit_1_5r_before_sl = 1 THEN 1 ELSE 0 END) AS hit_1_5r_rows,
  SUM(CASE WHEN hit_2r_before_sl = 1 THEN 1 ELSE 0 END) AS hit_2r_rows,
  SUM(CASE WHEN hit_3r_before_sl = 1 THEN 1 ELSE 0 END) AS hit_3r_rows,
  SUM(CASE WHEN path_status IN ('INVALID', 'RUN_ENDED') OR path_status IS NULL THEN 1 ELSE 0 END) AS invalid_path_rows
FROM training_matrix
""",
        ),
        "strategy_distribution": _fetch_dicts(
            connection,
            "SELECT strategy_label, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "direction_distribution": _fetch_dicts(
            connection,
            "SELECT direction, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "structure_distribution": _fetch_dicts(
            connection,
            """
SELECT
  structure_0,
  structure_1,
  structure_2,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1, 2, 3
ORDER BY 4 DESC, 1, 2, 3
""",
        ),
        "macro_slope_distribution": _fetch_dicts(
            connection,
            """
SELECT
  macro_h1_slope,
  macro_h4_slope,
  macro_d1_slope,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1, 2, 3
ORDER BY 4 DESC, 1, 2, 3
""",
        ),
        "fib_distribution": _fetch_dicts(
            connection,
            """
SELECT
  fib_sl_band,
  fib_entry_band,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1, 2
ORDER BY 1, 2
""",
        ),
        "chain_distribution": _fetch_dicts(
            connection,
            """
SELECT
  high_chain_profile,
  low_chain_profile,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1, 2
ORDER BY 3 DESC, 1, 2
""",
        ),
        "previous_candle_distribution": _fetch_dicts(
            connection,
            "SELECT previous_candle_profile, COUNT(*) AS rows, AVG(target_profit_r) AS avg_profit_r FROM training_matrix GROUP BY 1 ORDER BY 1",
        ),
        "entry_session_distribution": _fetch_dicts(
            connection,
            """
SELECT
  entry_session_bucket,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1
ORDER BY 1
""",
        ),
        "session_id_distribution": _fetch_dicts(
            connection,
            """
SELECT
  session_id,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1
ORDER BY 1
""",
        ),
        "entry_weekday_distribution": _fetch_dicts(
            connection,
            """
SELECT
  entry_weekday,
  COUNT(*) AS rows,
  AVG(target_profit_r) AS avg_profit_r
FROM training_matrix
GROUP BY 1
ORDER BY 1
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
    column_groups = DatasetColumnGroups(feature_columns=feature_columns)
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
        "feature_columns": list(column_groups.feature_columns),
        "target_columns": list(column_groups.target_columns),
        "identity_columns": list(column_groups.identity_columns),
        "audit_columns": list(column_groups.audit_columns),
        "path_ratio_outcome_columns": list(PATH_RATIO_OUTCOME_COLUMNS),
        "excluded_from_training_columns": [
            "terminal_time",
            "terminal_reason",
            "profit_r",
            "duration_seconds",
            "duration_m1_bars",
            "entry_price",
            "close_price",
            "net_profit",
            *PATH_RATIO_OUTCOME_COLUMNS,
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
        f"Target family: `{quality_payload.get('target_family', '')}`",
        f"Path labels present: `{quality_payload.get('path_label_columns_present', False)}`",
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
    lines.extend(["", "## Path Status Distribution", ""])
    lines.extend(_markdown_table(quality_payload["path_status_distribution"], ("path_status", "rows")))
    lines.extend(["", "## Path Target Support", ""])
    lines.extend(
        _markdown_table(
            quality_payload["path_target_support"],
            (
                "hit_1r_rows",
                "hit_1_5r_rows",
                "hit_2r_rows",
                "hit_3r_rows",
                "invalid_path_rows",
            ),
        )
    )
    lines.extend(["", "## Strategy Summary", ""])
    lines.extend(_markdown_table(quality_payload["strategy_distribution"], ("strategy_label", "rows", "avg_profit_r")))
    lines.extend(["", "## Direction Summary", ""])
    lines.extend(_markdown_table(quality_payload["direction_distribution"], ("direction", "rows", "avg_profit_r")))
    lines.extend(["", "## Structure Summary", ""])
    lines.extend(
        _markdown_table(
            quality_payload["structure_distribution"],
            (
                "structure_0",
                "structure_1",
                "structure_2",
                "rows",
                "avg_profit_r",
            ),
        )
    )
    lines.extend(["", "## Macro Slope Summary", ""])
    lines.extend(
        _markdown_table(
            quality_payload["macro_slope_distribution"],
            ("macro_h1_slope", "macro_h4_slope", "macro_d1_slope", "rows", "avg_profit_r"),
        )
    )
    lines.extend(["", "## Fibonacci Summary", ""])
    lines.extend(_markdown_table(quality_payload["fib_distribution"], ("fib_sl_band", "fib_entry_band", "rows", "avg_profit_r")))
    lines.extend(["", "## Chain Summary", ""])
    lines.extend(_markdown_table(quality_payload["chain_distribution"], ("high_chain_profile", "low_chain_profile", "rows", "avg_profit_r")))
    lines.extend(["", "## Previous Candle Summary", ""])
    lines.extend(_markdown_table(quality_payload["previous_candle_distribution"], ("previous_candle_profile", "rows", "avg_profit_r")))
    lines.extend(["", "## Entry Session Summary", ""])
    lines.extend(_markdown_table(quality_payload["entry_session_distribution"], ("entry_session_bucket", "rows", "avg_profit_r")))
    lines.extend(["", "## Session ID Summary", ""])
    lines.extend(_markdown_table(quality_payload["session_id_distribution"], ("session_id", "rows", "avg_profit_r")))
    lines.extend(["", "## Entry Weekday Summary", ""])
    lines.extend(_markdown_table(quality_payload["entry_weekday_distribution"], ("entry_weekday", "rows", "avg_profit_r")))
    lines.extend(["", "## Feature Null Counts", ""])
    lines.extend(_markdown_table(quality_payload["feature_null_counts"], ("column_name", "null_rows")))
    lines.extend(["", "## Feature Ranges", ""])
    lines.extend(_markdown_table(quality_payload["feature_ranges"], ("column_name", "min_value", "max_value", "avg_value")))

    if quality_payload["warnings"]:
        lines.extend(["", "## Warnings", ""])
        for warning in quality_payload["warnings"]:
            lines.append(f"- {warning}")

    (output_dir / "dataset_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
