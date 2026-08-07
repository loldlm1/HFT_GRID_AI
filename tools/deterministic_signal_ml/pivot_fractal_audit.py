"""Audit V11 pivot trial-matrix datasets with separate virtual and broker lanes."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from build_dataset import DERIVED_TABLES
from model_config import DEFAULT_DATASET_ROOT
from schema_contract import (
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
)


DEFAULT_AUDIT_ROOT = "artifacts/audits"
REQUIRED_TABLES = tuple(Path(filename).stem for filename in RUN_FILES) + DERIVED_TABLES


class PivotAuditError(RuntimeError):
    """Raised when a dataset cannot support a trustworthy V11 audit."""


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
    duplicate_long = int(
        connection.execute(
            """
SELECT count(*)
FROM (
  SELECT run_id, config_id, trial_id
  FROM origin_matrix_long
  GROUP BY ALL
  HAVING count(*) <> 1
)
"""
        ).fetchone()[0]
    )
    if duplicate_long:
        raise PivotAuditError("Origin matrix long contains duplicate trial grain")
    orphan_long = int(
        connection.execute(
            """
SELECT count(*)
FROM origin_matrix_long oml
LEFT JOIN virtual_trials vt
  USING (run_id, config_id, trial_id)
WHERE vt.trial_id IS NULL
"""
        ).fetchone()[0]
    )
    if orphan_long:
        raise PivotAuditError("Origin matrix long contains rows outside virtual_trials")
    invalid_eligible = int(
        connection.execute(
            """
SELECT count(*)
FROM eligible_virtual_trials
WHERE virtual_binary_target NOT IN (0, 1)
   OR NOT virtual_binary_eligible
   OR eligibility_status <> 'ACTIVE'
   OR terminal_status NOT IN ('TP_FIRST', 'SL_FIRST')
"""
        ).fetchone()[0]
    )
    if invalid_eligible:
        raise PivotAuditError("Eligible virtual cohort contains excluded or malformed rows")
    bad_origin_weights = int(
        connection.execute(
            """
SELECT count(*)
FROM (
  SELECT run_id, config_id, origin_id, sum(origin_sample_weight) AS total_weight
  FROM eligible_virtual_trials
  GROUP BY ALL
  HAVING abs(total_weight - 1.0) > 1e-9
)
"""
        ).fetchone()[0]
    )
    if bad_origin_weights:
        raise PivotAuditError("Origin-balanced weights do not sum to one")
    missing_broker_ownership = int(
        connection.execute(
            """
SELECT count(*)
FROM broker_outcomes bo
WHERE NOT EXISTS (
  SELECT 1
  FROM execution_checks ec
  WHERE ec.run_id = bo.run_id
    AND ec.config_id = bo.config_id
    AND ec.broker_signal_id = bo.broker_signal_id
    AND ec.position_identifier = bo.position_identifier
    AND ec.broker_entry_confirmed
)
OR NOT EXISTS (
  SELECT 1
  FROM execution_checks ec
  WHERE ec.run_id = bo.run_id
    AND ec.config_id = bo.config_id
    AND ec.broker_signal_id = bo.broker_signal_id
    AND ec.position_identifier = bo.position_identifier
    AND ec.broker_close_confirmed
)
"""
        ).fetchone()[0]
    )
    if missing_broker_ownership:
        raise PivotAuditError("Broker outcome lacks execution-check ownership evidence")
    summary_failures = int(
        connection.execute(
            """
SELECT count(*)
FROM run_summary
WHERE duplicate_identity_count <> 0
   OR referential_integrity_error_count <> 0
   OR row_integrity_error_count <> 0
   OR state_capacity_failed
   OR export_status <> 'OK'
"""
        ).fetchone()[0]
    )
    if summary_failures:
        raise PivotAuditError("Run summary contains integrity/export/capacity failure")
    parity_mismatches = int(
        connection.execute(
            """
SELECT count(*)
FROM broker_virtual_calibration
WHERE strict_pair_eligible AND NOT terminal_agreement
"""
        ).fetchone()[0]
    )
    if parity_mismatches:
        raise PivotAuditError("Calibration contains unexplained strict TP/SL mismatch")
    leaked_features = sorted(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
    if leaked_features:
        raise PivotAuditError(f"Future-only fields leaked into model features: {leaked_features}")
    matrix_columns = {
        row[0] for row in connection.execute("DESCRIBE eligible_virtual_trials").fetchall()
    }
    missing_features = sorted(set(MODEL_FEATURE_COLUMNS) - matrix_columns)
    if missing_features:
        raise PivotAuditError(f"Eligible virtual cohort lacks model features: {missing_features}")


def _policy_performance(connection: duckdb.DuckDBPyConnection) -> list[dict[str, Any]]:
    return _fetch_dicts(
        connection,
        """
SELECT
  sl_policy,
  tp_r_multiple,
  count(*) AS trial_rows,
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


def _chain_performance(connection: duckdb.DuckDBPyConnection) -> list[dict[str, Any]]:
    return _fetch_dicts(
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
  sum(CASE WHEN reached_tp THEN 1 ELSE 0 END) AS tp_chains,
  sum(CASE WHEN censored THEN 1 ELSE 0 END) AS censored_chains
FROM policy_chains
GROUP BY sl_policy, tp_r_multiple
ORDER BY sl_policy, tp_r_multiple
""",
    )


def _render_report(audit_id: str, metadata: dict[str, Any]) -> str:
    support = metadata["support"]
    calibration = metadata["calibration"]
    return "\n".join(
        [
            f"# Pivot Trial Matrix Audit: {audit_id}",
            "",
            f"- Research status: `{metadata['research_status']}`",
            f"- Unique origins: `{support['unique_origins']}`",
            f"- Matrix trial rows: `{support['matrix_trial_rows']}`",
            f"- Eligible virtual rows: `{support['eligible_virtual_rows']}`",
            f"- Broker outcomes: `{support['broker_outcomes']}`",
            f"- Calibration strict pairs: `{calibration['strict_pairs']}`",
            f"- Calibration terminal mismatches: `{calibration['terminal_mismatches']}`",
            "",
            "## Interpretation",
            "",
            "Virtual TP/SL targets, broker outcomes, and parity calibration are separate cohorts.",
            "Unique-origin support and trial-row support are both reported because retries and policy cells are correlated.",
            "Policy comparisons remain exploratory and require chronological holdout support and uncertainty review.",
            "",
        ]
    )


def build_audit(
    dataset_dir: Path,
    output_dir: Path,
    audit_id: str,
    minimum_group_support: int = 30,
) -> dict[str, Any]:
    manifest_path = dataset_dir / "dataset_manifest.json"
    if not manifest_path.is_file():
        raise PivotAuditError(f"Missing dataset manifest: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if int(manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise PivotAuditError("Dataset schema version is incompatible with V11 audit")
    if manifest.get("feature_set_id") != SUPPORTED_FEATURE_SET_ID:
        raise PivotAuditError("Dataset feature set is incompatible with V11 audit")
    feature_contract = manifest.get("feature_contract", {})
    if tuple(feature_contract.get("model_features", ())) != MODEL_FEATURE_COLUMNS:
        raise PivotAuditError("Dataset feature contract differs from strict V11")
    connection = duckdb.connect(":memory:")
    try:
        _load_dataset(connection, dataset_dir)
        _validate_dataset_integrity(connection)
        policy = _policy_performance(connection)
        chains = _chain_performance(connection)
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
        broker = _fetch_dicts(
            connection,
            """
SELECT broker_terminal_reason, broker_binary_eligible,
       count(*) AS rows, avg(broker_gross_profit) AS average_gross_profit,
       avg(broker_net_profit) AS average_net_profit
FROM broker_outcomes
GROUP BY ALL
ORDER BY rows DESC, broker_terminal_reason
""",
        )
        calibration_rows = _fetch_dicts(
            connection,
            """
SELECT *
FROM broker_virtual_calibration
ORDER BY broker_close_time, run_id, broker_signal_id
""",
        )
        support = _fetch_dicts(
            connection,
            """
SELECT
  (SELECT count(DISTINCT origin_id) FROM signal_origins) AS unique_origins,
  (SELECT count(*) FROM origin_matrix_long) AS matrix_trial_rows,
  (SELECT count(*) FROM eligible_virtual_trials) AS eligible_virtual_rows,
  (SELECT count(*) FROM policy_chains) AS policy_chains,
  (SELECT count(*) FROM broker_outcomes) AS broker_outcomes
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
  avg(broker_minus_virtual_gross_profit) AS average_broker_minus_virtual_gross_profit
FROM broker_virtual_calibration
""",
        )[0]
    finally:
        connection.close()

    low_support = [
        row
        for row in policy
        if int(row["unique_origins"] or 0) < minimum_group_support
    ]
    metadata = {
        "audit_id": audit_id,
        "created_at_utc": datetime.now(UTC).isoformat(),
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "minimum_group_support": minimum_group_support,
        "research_status": "INSUFFICIENT_SUPPORT" if low_support else "AUDIT_COMPLETE",
        "support": support,
        "policy_performance": policy,
        "chain_performance": chains,
        "eligibility": eligibility,
        "broker_performance": broker,
        "calibration": calibration,
        "low_support_policy_groups": low_support,
        "warnings": [
            "Virtual and broker targets are separate.",
            "Trial rows are correlated within origins and Macro windows.",
            "Multiple policy comparisons require holdout support and uncertainty review.",
        ],
    }
    _write_tsv(output_dir / "policy_performance.tsv", policy)
    _write_tsv(output_dir / "chain_performance.tsv", chains)
    _write_tsv(output_dir / "eligibility.tsv", eligibility)
    _write_tsv(output_dir / "broker_performance.tsv", broker)
    _write_tsv(output_dir / "broker_virtual_calibration.tsv", calibration_rows)
    (output_dir / "audit.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True, default=str),
        encoding="utf-8",
    )
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
    parser.add_argument("--dataset-id", required=True)
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--audit-root", default=DEFAULT_AUDIT_ROOT)
    parser.add_argument("--minimum-group-support", type=int, default=30)
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        dataset_dir = (Path(args.dataset_root) / args.dataset_id).resolve()
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
        parser.exit(1, f"pivot V11 audit failed: {exc}\n")
    print(
        "pivot V11 audit ok | "
        f"status={metadata['research_status']} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
