"""Audit strict V13 H1, deep-parent, broker, and calibration research artifacts."""

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
from report_writer import build_feature_contracts
from schema_contract import (
    DEEP_FEATURE_SET_ID,
    DEEP_MICRO_FEATURE_COLUMNS,
    DEEP_MODEL_FEATURE_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    H1_FEATURE_SET_ID,
    H1_MODEL_FEATURE_COLUMNS,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
)

DEFAULT_AUDIT_ROOT = "artifacts/audits"
REQUIRED_TABLES = tuple(Path(filename).stem for filename in RUN_FILES) + DERIVED_TABLES


class PivotAuditError(RuntimeError):
    """Raised when a V13 dataset cannot support a trustworthy audit."""


def _sql_literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _quoted(column: str) -> str:
    return '"' + column.replace('"', '""') + '"'


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
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(rows[0]),
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


def _count(connection: duckdb.DuckDBPyConnection, query: str) -> int:
    return int(connection.execute(query).fetchone()[0])


def _require_zero(
    connection: duckdb.DuckDBPyConnection,
    query: str,
    message: str,
) -> None:
    if _count(connection, query):
        raise PivotAuditError(message)


def _validate_manifest_contract(manifest: dict[str, Any]) -> None:
    if int(manifest.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
        raise PivotAuditError("Dataset schema version is incompatible with V13 audit")
    if manifest.get("feature_set_id") != SUPPORTED_FEATURE_SET_ID:
        raise PivotAuditError("Dataset feature set is incompatible with V13 audit")
    if manifest.get("research_approval_state") != "OFFLINE_RESEARCH_ONLY":
        raise PivotAuditError("Dataset is missing the offline-only research boundary")
    if manifest.get("available_feature_set_ids") != [
        H1_FEATURE_SET_ID,
        DEEP_FEATURE_SET_ID,
    ]:
        raise PivotAuditError("Dataset evidence-grain list is incompatible")
    if manifest.get("feature_contracts") != build_feature_contracts():
        raise PivotAuditError("Dataset evidence-grain contracts differ from strict V13")
    expected_files = {table: f"{table}.parquet" for table in REQUIRED_TABLES}
    if manifest.get("files") != expected_files:
        raise PivotAuditError("Dataset file manifest differs from strict V13")
    counts = manifest.get("counts")
    if not isinstance(counts, dict) or set(counts) != set(REQUIRED_TABLES):
        raise PivotAuditError("Dataset count manifest differs from strict V13")


def _validate_dataset_integrity(
    connection: duckdb.DuckDBPyConnection,
    manifest: dict[str, Any],
) -> None:
    for table_name in REQUIRED_TABLES:
        actual = _count(connection, f"SELECT count(*) FROM {table_name}")
        expected = int(manifest["counts"][table_name])
        if actual != expected:
            raise PivotAuditError(
                f"Dataset manifest count mismatch for {table_name}: {actual} != {expected}"
            )
    expected_h1_rows = _count(
        connection,
        "SELECT count(*) FROM virtual_trials WHERE trial_role = 'H1'",
    )
    if _count(connection, "SELECT count(*) FROM h1_lane_long") != expected_h1_rows:
        raise PivotAuditError("H1 lane long does not reconcile to H1 trials")
    expected_deep_rows = _count(connection, "SELECT count(*) FROM deep_virtual_outcomes")
    if _count(connection, "SELECT count(*) FROM deep_parent_long") != expected_deep_rows:
        raise PivotAuditError("Deep parent long does not reconcile to deep outcomes")
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT run_id, config_id, trial_id
  FROM h1_lane_long
  GROUP BY ALL
  HAVING count(*) <> 1
)
""",
        "H1 lane long contains duplicate trial grain",
    )
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT run_id, config_id, origin_id
  FROM h1_lane_long
  GROUP BY ALL
  HAVING count(*) <> 8
)
""",
        "H1 origin does not contain exactly eight lane outcomes",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM eligible_h1_trials
WHERE virtual_binary_target NOT IN (0, 1)
   OR NOT virtual_binary_eligible
   OR eligibility_status <> 'ACTIVE'
   OR terminal_status NOT IN ('TP_FIRST', 'SL_FIRST')
   OR NOT origin_feature_snapshot_complete
""",
        "Eligible H1 cohort contains excluded or malformed rows",
    )
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT origin_id, sum(origin_sample_weight) AS weight
  FROM eligible_h1_trials
  GROUP BY origin_id
  HAVING abs(weight - 1.0) > 1e-9
)
""",
        "Eligible H1 origin weights do not sum to one",
    )
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT run_id, config_id, parent_link_id, deep_trial_id
  FROM deep_parent_long
  GROUP BY ALL
  HAVING count(*) <> 1
)
""",
        "Deep parent long contains duplicate link/trial grain",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM eligible_deep_trials
WHERE virtual_binary_target NOT IN (0, 1)
   OR NOT virtual_binary_eligible
   OR eligibility_status <> 'ACTIVE'
   OR terminal_status NOT IN ('TP_FIRST', 'SL_FIRST')
   OR NOT deep_micro_features_complete
""",
        "Eligible deep cohort contains excluded or malformed rows",
    )
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT origin_id, sum(origin_sample_weight) AS weight
  FROM eligible_deep_trials
  GROUP BY origin_id
  HAVING abs(weight - 1.0) > 1e-9
)
""",
        "Eligible deep origin weights do not sum to one",
    )
    _require_zero(
        connection,
        """
SELECT count(*) FROM (
  SELECT deep_event_id, sum(event_sample_weight) AS weight
  FROM eligible_deep_trials
  GROUP BY deep_event_id
  HAVING abs(weight - 1.0) > 1e-9
)
""",
        "Eligible deep event weights do not sum to one",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM deep_parent_long
WHERE parent_lifecycle_complete IS NULL
   OR (parent_lifecycle_complete AND h1_structural_lifecycle_seconds IS NULL)
   OR (NOT parent_lifecycle_complete AND h1_structural_lifecycle_seconds IS NOT NULL)
   OR (terminal_status = 'CENSORED_PARENT_EXIT'
       AND terminal_broker_time IS DISTINCT FROM parent_terminal_broker_time)
""",
        "Deep parent lifecycle duration/censor evidence is inconsistent",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM run_summary
WHERE duplicate_identity_count <> 0
   OR referential_integrity_error_count <> 0
   OR row_integrity_error_count <> 0
   OR export_status <> 'OK'
   OR h1_active_state_peak > h1_active_state_cap
   OR deep_event_active_peak > deep_event_active_cap
   OR deep_link_active_peak > deep_link_active_cap
   OR deep_trial_active_peak > deep_trial_active_cap
   OR deep_outcome_active_peak > deep_outcome_active_cap
""",
        "Run summary contains integrity, export, or capacity failure",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM broker_outcomes bo
WHERE NOT EXISTS (
  SELECT 1 FROM execution_checks ec
  WHERE ec.run_id = bo.run_id
    AND ec.config_id = bo.config_id
    AND ec.broker_signal_id = bo.broker_signal_id
    AND ec.position_identifier = bo.position_identifier
    AND ec.broker_entry_confirmed
)
OR NOT EXISTS (
  SELECT 1 FROM execution_checks ec
  WHERE ec.run_id = bo.run_id
    AND ec.config_id = bo.config_id
    AND ec.broker_signal_id = bo.broker_signal_id
    AND ec.position_identifier = bo.position_identifier
    AND ec.broker_close_confirmed
)
""",
        "Broker outcome lacks execution-check ownership evidence",
    )
    _require_zero(
        connection,
        """
SELECT count(*)
FROM broker_virtual_calibration
WHERE strict_pair_eligible AND NOT terminal_agreement
""",
        "Calibration contains unexplained strict TP/SL mismatch",
    )
    if set(H1_MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS):
        raise PivotAuditError("Future-only fields leaked into H1 model features")
    if set(DEEP_MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS):
        raise PivotAuditError("Future-only fields leaked into deep model features")
    deep_parent_columns = {
        row[0] for row in connection.execute("DESCRIBE deep_parent_long").fetchall()
    }
    eligible_deep_columns = {
        row[0]
        for row in connection.execute("DESCRIBE eligible_deep_trials").fetchall()
    }
    duplicated = sorted(
        set(DEEP_MICRO_FEATURE_COLUMNS)
        & (deep_parent_columns | eligible_deep_columns)
    )
    if duplicated:
        raise PivotAuditError(f"Deep features persisted outside event grain: {duplicated}")
    event_columns = {
        row[0] for row in connection.execute("DESCRIBE deep_pivot_events").fetchall()
    }
    missing_event_features = sorted(set(DEEP_MICRO_FEATURE_COLUMNS) - event_columns)
    if missing_event_features:
        raise PivotAuditError(
            f"Deep event grain lacks model features: {missing_event_features}"
        )
    h1_columns = {
        row[0] for row in connection.execute("DESCRIBE eligible_h1_trials").fetchall()
    }
    missing_h1_features = sorted(set(H1_MODEL_FEATURE_COLUMNS) - h1_columns)
    if missing_h1_features:
        raise PivotAuditError(
            f"Eligible H1 cohort lacks model features: {missing_h1_features}"
        )
    h1_missing_predicate = " OR ".join(
        f"{_quoted(column)} IS NULL" for column in H1_MODEL_FEATURE_COLUMNS
    )
    _require_zero(
        connection,
        f"SELECT count(*) FROM eligible_h1_trials WHERE {h1_missing_predicate}",
        "Eligible H1 cohort contains incomplete model features",
    )
    deep_parent_features = set(DEEP_MODEL_FEATURE_COLUMNS) - set(
        DEEP_MICRO_FEATURE_COLUMNS
    )
    missing_deep_parent_features = sorted(deep_parent_features - eligible_deep_columns)
    if missing_deep_parent_features:
        raise PivotAuditError(
            "Eligible deep cohort lacks parent-grain model features: "
            f"{missing_deep_parent_features}"
        )
    deep_parent_missing_predicate = " OR ".join(
        f"{_quoted(column)} IS NULL" for column in sorted(deep_parent_features)
    )
    _require_zero(
        connection,
        "SELECT count(*) FROM eligible_deep_trials WHERE "
        f"{deep_parent_missing_predicate}",
        "Eligible deep cohort contains incomplete parent-grain features",
    )
    deep_event_missing_predicate = " OR ".join(
        f"{_quoted(column)} IS NULL" for column in DEEP_MICRO_FEATURE_COLUMNS
    )
    _require_zero(
        connection,
        "SELECT count(*) FROM deep_pivot_events "
        "WHERE deep_micro_features_complete AND "
        f"({deep_event_missing_predicate})",
        "Complete deep event contains incomplete model features",
    )
    joined_deep_rows = _count(
        connection,
        """
SELECT count(*)
FROM eligible_deep_trials cohort
JOIN deep_pivot_events event
  USING (run_id, config_id, deep_event_id)
""",
    )
    if joined_deep_rows != _count(connection, "SELECT count(*) FROM eligible_deep_trials"):
        raise PivotAuditError("Deep event feature join changes eligible cohort cardinality")


def _render_report(audit_id: str, metadata: dict[str, Any]) -> str:
    support = metadata["support"]
    return "\n".join(
        [
            f"# Pivot V13 Evidence Audit: {audit_id}",
            "",
            f"- Research status: `{metadata['research_status']}`",
            f"- Unique origins: `{support['unique_origins']}`",
            f"- H1 lane / eligible rows: `{support['h1_lane_rows']}` / `{support['eligible_h1_rows']}`",
            f"- Deep event / parent outcome / eligible rows: `{support['deep_event_rows']}` / "
            f"`{support['deep_parent_outcome_rows']}` / `{support['eligible_deep_rows']}`",
            f"- Unique deep event identities: `{support['unique_deep_events']}`",
            f"- Deep parent-exit censors: `{support['deep_parent_exit_censored_rows']}`",
            "",
            "H1, deep-parent, broker, and parity evidence remain separate cohorts. "
            "Censored, ineligible, and not-triggered rows are support facts, not losses.",
            "H1 lifecycle duration is retrospective; M10 parent age is causal at event trigger.",
            "",
        ]
    )


def build_audit(
    dataset_dir: Path,
    output_dir: Path,
    audit_id: str,
    minimum_group_support: int = 30,
) -> dict[str, Any]:
    if minimum_group_support < 1:
        raise PivotAuditError("minimum_group_support must be at least 1")
    manifest_path = dataset_dir / "dataset_manifest.json"
    if not manifest_path.is_file():
        raise PivotAuditError(f"Missing dataset manifest: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    _validate_manifest_contract(manifest)

    connection = duckdb.connect(":memory:")
    try:
        _load_dataset(connection, dataset_dir)
        _validate_dataset_integrity(connection, manifest)
        h1_performance = _fetch_dicts(
            connection,
            """
WITH per_group AS (
  SELECT entry_policy, tp_r_multiple, count(*) AS rows,
         count(DISTINCT origin_id) AS unique_origins
  FROM eligible_h1_trials
  GROUP BY entry_policy, tp_r_multiple
), per_origin AS (
  SELECT entry_policy, tp_r_multiple, origin_id,
         avg(virtual_binary_target) AS tp_rate,
         avg(virtual_quote_gross_r) AS quote_gross_r
  FROM eligible_h1_trials
  GROUP BY entry_policy, tp_r_multiple, origin_id
)
SELECT grouped.*, avg(per_origin.tp_rate) AS origin_balanced_tp_rate,
       avg(per_origin.quote_gross_r) AS origin_balanced_quote_gross_r
FROM per_group grouped
JOIN per_origin USING (entry_policy, tp_r_multiple)
GROUP BY ALL
ORDER BY grouped.entry_policy, grouped.tp_r_multiple
""",
        )
        deep_performance = _fetch_dicts(
            connection,
            """
WITH per_group AS (
  SELECT parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple,
         count(*) AS rows, count(DISTINCT origin_id) AS unique_origins,
         count(DISTINCT deep_event_id) AS unique_deep_events
  FROM eligible_deep_trials
  GROUP BY parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple
), per_origin AS (
  SELECT parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple,
         origin_id, avg(virtual_binary_target) AS tp_rate,
         avg(virtual_quote_gross_r) AS quote_gross_r
  FROM eligible_deep_trials
  GROUP BY parent_kind, parent_entry_policy, parent_tp_r_multiple,
           tp_r_multiple, origin_id
)
SELECT grouped.*, avg(per_origin.tp_rate) AS origin_balanced_tp_rate,
       avg(per_origin.quote_gross_r) AS origin_balanced_quote_gross_r
FROM per_group grouped
JOIN per_origin USING (
  parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple
)
GROUP BY ALL
ORDER BY grouped.parent_kind, grouped.parent_entry_policy,
         grouped.parent_tp_r_multiple, grouped.tp_r_multiple
""",
        )
        h1_terminal = _fetch_dicts(
            connection,
            """
SELECT terminal_status, entry_policy, tp_r_multiple,
       count(*) AS rows, count(DISTINCT origin_id) AS unique_origins,
       count(h1_structural_lifecycle_seconds) AS completed_duration_rows
FROM h1_lane_long
GROUP BY ALL
ORDER BY terminal_status, entry_policy, tp_r_multiple
""",
        )
        deep_terminal = _fetch_dicts(
            connection,
            """
SELECT terminal_status, parent_kind, tp_r_multiple,
       count(*) AS rows, count(DISTINCT origin_id) AS unique_origins,
       count(DISTINCT deep_event_id) AS unique_deep_events
FROM deep_parent_long
GROUP BY ALL
ORDER BY terminal_status, parent_kind, tp_r_multiple
""",
        )
        support = _fetch_dicts(
            connection,
            """
SELECT
  (SELECT count(DISTINCT origin_id) FROM signal_origins) AS unique_origins,
  (SELECT count(*) FROM h1_lane_long) AS h1_lane_rows,
  (SELECT count(*) FROM eligible_h1_trials) AS eligible_h1_rows,
  (SELECT count(*) FROM deep_pivot_events) AS deep_event_rows,
  (SELECT count(DISTINCT deep_event_id) FROM deep_pivot_events)
    AS unique_deep_events,
  (SELECT count(*) FROM deep_parent_long) AS deep_parent_outcome_rows,
  (SELECT count(*) FROM eligible_deep_trials) AS eligible_deep_rows,
  (SELECT count(*) FROM deep_parent_long
    WHERE terminal_status = 'CENSORED_PARENT_EXIT') AS deep_parent_exit_censored_rows,
  (SELECT count(*) FROM broker_outcomes) AS broker_outcomes,
  (SELECT count(*) FROM broker_virtual_calibration) AS calibration_rows
""",
        )[0]
        calibration_rows = _fetch_dicts(
            connection,
            "SELECT * FROM broker_virtual_calibration ORDER BY broker_close_time",
        )
    finally:
        connection.close()

    low_support = [
        {"cohort": "H1", **row}
        for row in h1_performance
        if int(row["unique_origins"] or 0) < minimum_group_support
    ] + [
        {"cohort": "DEEP", **row}
        for row in deep_performance
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
        "h1_performance": h1_performance,
        "deep_performance": deep_performance,
        "h1_terminal_support": h1_terminal,
        "deep_terminal_support": deep_terminal,
        "low_support_groups": low_support,
        "warnings": [
            "H1 and deep target cohorts are never combined.",
            "Lifecycle duration is retrospective and excluded from model features.",
            "Deep row counts do not replace unique-event and unique-origin support.",
        ],
    }
    _write_tsv(output_dir / "h1_performance.tsv", h1_performance)
    _write_tsv(output_dir / "deep_performance.tsv", deep_performance)
    _write_tsv(output_dir / "h1_terminal_support.tsv", h1_terminal)
    _write_tsv(output_dir / "deep_terminal_support.tsv", deep_terminal)
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
        parser.exit(1, f"pivot V13 audit failed: {exc}\n")
    print(
        "pivot V13 audit ok | "
        f"status={metadata['research_status']} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
