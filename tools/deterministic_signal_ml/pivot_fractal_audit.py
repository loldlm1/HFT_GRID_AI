"""Audit V10 pivot-band datasets without confluence or trailing analytics."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from build_dataset import BINARY_OUTCOMES_TABLE, RESEARCH_MATRIX_TABLE
from model_config import DEFAULT_DATASET_ROOT
from schema_contract import (
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
)


DEFAULT_AUDIT_ROOT = "artifacts/audits"
REQUIRED_TABLES = tuple(Path(filename).stem for filename in RUN_FILES) + (
    RESEARCH_MATRIX_TABLE,
    BINARY_OUTCOMES_TABLE,
)


class PivotAuditError(RuntimeError):
    """Raised when a dataset cannot support a trustworthy V10 audit."""


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    query: str,
) -> list[dict[str, Any]]:
    relation = connection.execute(query)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def _write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    columns = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def _load_dataset(connection: duckdb.DuckDBPyConnection, dataset_dir: Path) -> None:
    for table_name in REQUIRED_TABLES:
        path = dataset_dir / f"{table_name}.parquet"
        if not path.is_file():
            raise PivotAuditError(f"Missing required dataset table: {path}")
        connection.execute(
            f"CREATE VIEW {table_name} AS "
            f"SELECT * FROM read_parquet({_sql_literal(path.resolve().as_posix())})"
        )


def _validate_dataset_integrity(connection: duckdb.DuckDBPyConnection) -> None:
    duplicate_research = int(
        connection.execute(
            f"""
SELECT COUNT(*)
FROM (
  SELECT run_id, config_id, signal_id
  FROM {RESEARCH_MATRIX_TABLE}
  GROUP BY 1, 2, 3
  HAVING COUNT(*) <> 1
)
"""
        ).fetchone()[0]
    )
    if duplicate_research:
        raise PivotAuditError("Research matrix contains duplicate signal grain")
    invalid_binary = int(
        connection.execute(
            f"""
SELECT COUNT(*)
FROM {BINARY_OUTCOMES_TABLE}
WHERE binary_target NOT IN (0, 1)
   OR NOT binary_eligible
   OR close_broker_time IS NULL
   OR terminal_reason NOT IN ('BROKER_TP', 'BROKER_SL')
"""
        ).fetchone()[0]
    )
    if invalid_binary:
        raise PivotAuditError("Binary cohort contains an excluded or malformed outcome")
    orphan_binary = int(
        connection.execute(
            f"""
SELECT COUNT(*)
FROM {BINARY_OUTCOMES_TABLE} b
LEFT JOIN {RESEARCH_MATRIX_TABLE} r
  USING (run_id, config_id, signal_id)
WHERE r.signal_id IS NULL
"""
        ).fetchone()[0]
    )
    if orphan_binary:
        raise PivotAuditError("Binary cohort contains rows outside the research matrix")
    missing_entry_evidence = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM signal_outcomes o
WHERE NOT EXISTS (
  SELECT 1
  FROM execution_checks c
  WHERE c.run_id = o.run_id
    AND c.config_id = o.config_id
    AND c.signal_id = o.signal_id
    AND c.broker_entry_confirmed
)
"""
        ).fetchone()[0]
    )
    if missing_entry_evidence:
        raise PivotAuditError("Outcome lacks broker entry ownership evidence")
    integrity_rows = int(
        connection.execute(
            """
SELECT COUNT(*)
FROM run_summary
WHERE duplicate_identity_count <> 0
   OR referential_integrity_error_count <> 0
   OR row_integrity_error_count <> 0
   OR export_status <> 'OK'
"""
        ).fetchone()[0]
    )
    if integrity_rows:
        raise PivotAuditError("Run summary reports an integrity or export failure")


def _group_performance(
    connection: duckdb.DuckDBPyConnection,
    minimum_group_support: int,
) -> list[dict[str, Any]]:
    rows = _fetch_dicts(
        connection,
        f"""
WITH width_bins AS (
  SELECT
    *,
    NTILE(5) OVER (ORDER BY micro_band_width_percent_0) AS micro_width_bin,
    NTILE(5) OVER (ORDER BY macro_band_width_percent_1) AS macro_width_bin,
    NTILE(5) OVER (ORDER BY micro_b_percent_0) AS micro_b0_bin,
    NTILE(5) OVER (ORDER BY macro_pivot_b_percent_1) AS macro_b1_bin
  FROM {BINARY_OUTCOMES_TABLE}
), grouped AS (
  SELECT 'overall' AS group_family, 'ALL' AS group_key, * FROM width_bins
  UNION ALL
  SELECT 'level_direction', concat(level_id, '|', direction), * FROM width_bins
  UNION ALL
  SELECT 'analysis_weekday', analysis_weekday, * FROM width_bins
  UNION ALL
  SELECT 'analysis_session', analysis_session, * FROM width_bins
  UNION ALL
  SELECT 'micro_width_quintile', CAST(micro_width_bin AS VARCHAR), * FROM width_bins
  UNION ALL
  SELECT 'macro_width_quintile', CAST(macro_width_bin AS VARCHAR), * FROM width_bins
  UNION ALL
  SELECT 'micro_b0_quintile', CAST(micro_b0_bin AS VARCHAR), * FROM width_bins
  UNION ALL
  SELECT 'macro_b1_quintile', CAST(macro_b1_bin AS VARCHAR), * FROM width_bins
)
SELECT
  group_family,
  group_key,
  COUNT(*) AS support,
  AVG(binary_target) AS tp_rate,
  AVG(gross_profit) AS average_gross_profit,
  AVG(net_profit) AS average_net_profit,
  AVG(gross_execution_r) AS average_gross_execution_r,
  AVG(net_execution_r) AS average_net_execution_r,
  AVG(entry_slippage_points) AS average_entry_slippage_points,
  AVG(exit_slippage_points) AS average_exit_slippage_points
FROM grouped
GROUP BY 1, 2
ORDER BY 1, 2
""",
    )
    for row in rows:
        row["support_status"] = (
            "SUFFICIENT"
            if int(row["support"]) >= minimum_group_support
            else "LOW_SUPPORT"
        )
    return rows


def _render_report(audit_id: str, metadata: dict[str, Any]) -> str:
    binary = metadata["binary_cohort"]
    return "\n".join(
        [
            f"# Pivot V10 Audit: {audit_id}",
            "",
            "Approval: `OFFLINE_RESEARCH_ONLY`",
            f"Research rows: `{metadata['research_rows']}`",
            f"Binary rows: `{binary['rows']}`",
            f"TP rate: `{binary['tp_rate']}`",
            f"Average gross P&L: `{binary['average_gross_profit']}`",
            f"Average net P&L: `{binary['average_net_profit']}`",
            "",
            "Operational denials and excluded closes are reported separately from binary performance.",
            "Quintiles are human-readable audit bins; XGBoost consumes the continuous values.",
            "No derived multi-signal, stop-management, or runtime-approval analysis is produced.",
            "",
        ]
    )


def build_audit(
    dataset_dir: Path,
    output_dir: Path,
    audit_id: str,
    minimum_group_support: int = 0,
) -> dict[str, Any]:
    manifest_path = dataset_dir / "dataset_manifest.json"
    if not manifest_path.is_file():
        raise PivotAuditError(f"Missing dataset manifest: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if int(manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise PivotAuditError("Dataset schema is incompatible with V10 audit tooling")
    if manifest.get("feature_set_id") != SUPPORTED_FEATURE_SET_ID:
        raise PivotAuditError("Dataset feature set is incompatible with V10 audit tooling")
    if tuple(manifest.get("feature_columns", ())) != MODEL_FEATURE_COLUMNS:
        raise PivotAuditError("Dataset model feature contract is not exact V10")
    leaked = sorted(set(manifest["feature_columns"]) & set(FUTURE_ONLY_COLUMNS))
    if leaked:
        raise PivotAuditError(f"Dataset model features contain future facts: {leaked}")
    if manifest.get("approval_state") != "OFFLINE_RESEARCH_ONLY":
        raise PivotAuditError("Dataset lacks the offline-only boundary")
    if minimum_group_support < 0:
        raise PivotAuditError("minimum_group_support cannot be negative")

    output_dir.mkdir(parents=True, exist_ok=True)
    connection = duckdb.connect(":memory:")
    try:
        _load_dataset(connection, dataset_dir)
        _validate_dataset_integrity(connection)
        binary = _fetch_dicts(
            connection,
            f"""
SELECT
  COUNT(*) AS rows,
  SUM(CASE WHEN binary_target = 1 THEN 1 ELSE 0 END) AS tp_rows,
  SUM(CASE WHEN binary_target = 0 THEN 1 ELSE 0 END) AS sl_rows,
  AVG(binary_target) AS tp_rate,
  AVG(gross_profit) AS average_gross_profit,
  AVG(net_profit) AS average_net_profit,
  AVG(entry_slippage_points) AS average_entry_slippage_points,
  AVG(exit_slippage_points) AS average_exit_slippage_points
FROM {BINARY_OUTCOMES_TABLE}
""",
        )[0]
        operations = _fetch_dicts(
            connection,
            """
SELECT attempt_status, block_source, block_reason, COUNT(*) AS rows
FROM signal_attempts
GROUP BY 1, 2, 3
ORDER BY rows DESC, attempt_status, block_source, block_reason
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
        groups = _group_performance(connection, minimum_group_support)
        research_rows = int(
            connection.execute(f"SELECT COUNT(*) FROM {RESEARCH_MATRIX_TABLE}").fetchone()[0]
        )
    finally:
        connection.close()

    metadata = {
        "audit_id": audit_id,
        "created_at": datetime.now(UTC).isoformat(),
        "dataset_id": manifest["dataset_id"],
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "research_rows": research_rows,
        "binary_cohort": binary,
        "minimum_group_support": minimum_group_support,
        "group_rows": len(groups),
        "operational_rows": operations,
        "excluded_outcomes": exclusions,
        "approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact_emitted": False,
    }
    (output_dir / "audit_summary.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )
    _write_tsv(output_dir / "group_performance.tsv", groups)
    _write_tsv(output_dir / "operational_attempts.tsv", operations)
    _write_tsv(output_dir / "excluded_outcomes.tsv", exclusions)
    (output_dir / "audit_report.md").write_text(
        _render_report(audit_id, metadata),
        encoding="utf-8",
    )
    return metadata


def _prepare_output(root: Path, audit_id: str, overwrite: bool) -> Path:
    if not audit_id or Path(audit_id).name != audit_id or audit_id in (".", ".."):
        raise PivotAuditError(f"Invalid audit ID: {audit_id}")
    root = root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    output_dir = (root / audit_id).resolve()
    if output_dir.parent != root:
        raise PivotAuditError(f"Refusing audit output outside root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise PivotAuditError(f"Audit output already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    return output_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id")
    dataset_group.add_argument("--dataset-path")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--audit-root", default=DEFAULT_AUDIT_ROOT)
    parser.add_argument("--minimum-group-support", type=int, default=0)
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_dir = (
            Path(args.dataset_path)
            if args.dataset_path
            else Path(args.dataset_root) / str(args.dataset_id)
        ).resolve()
        if not dataset_dir.is_dir():
            raise PivotAuditError(f"Dataset folder does not exist: {dataset_dir}")
        output_dir = _prepare_output(Path(args.audit_root), args.audit_id, args.overwrite)
        metadata = build_audit(
            dataset_dir,
            output_dir,
            args.audit_id,
            args.minimum_group_support,
        )
    except (PivotAuditError, ValueError, json.JSONDecodeError, duckdb.Error) as exc:
        parser.exit(1, f"pivot V10 audit failed: {exc}\n")
    print(
        "pivot V10 audit ok | "
        f"audit={args.audit_id} | binary_rows={metadata['binary_cohort']['rows']} | "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
