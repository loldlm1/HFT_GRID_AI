"""Deterministic manifests and quality reports for V14 research datasets."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from model_config import EVENT_WEIGHT_POLICY, ORIGIN_WEIGHT_POLICY
from schema_contract import (
    DATASET_CONFIG_KEYS,
    DEEP_CATEGORICAL_COLUMNS,
    DEEP_FEATURE_SET_ID,
    DEEP_SIGNAL_FEATURE_COLUMNS,
    DEEP_MODEL_FEATURE_COLUMNS,
    FUTURE_ONLY_COLUMNS,
    H1_CATEGORICAL_COLUMNS,
    H1_FEATURE_SET_ID,
    H1_MODEL_FEATURE_COLUMNS,
    ORIGIN_SIGNAL_FEATURE_COLUMNS,
    SUPPORTED_ENGINE_LABEL,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    RunValidation,
)

BUILDER_VERSION = "pivot_fractal.schema_v14_hft_deep_pivot_features_builder.v1"


def _quoted(column: str) -> str:
    return '"' + column.replace('"', '""') + '"'


def _fetch_dicts(
    connection: duckdb.DuckDBPyConnection,
    query: str,
) -> list[dict[str, Any]]:
    relation = connection.execute(query)
    columns = [column[0] for column in relation.description]
    return [dict(zip(columns, row)) for row in relation.fetchall()]


def _feature_availability(
    connection: duckdb.DuckDBPyConnection,
    table_name: str,
    grain: str,
    identity_column: str,
    feature_columns: tuple[str, ...],
) -> list[dict[str, Any]]:
    total_rows = int(connection.execute(f"SELECT count(*) FROM {table_name}").fetchone()[0])
    total_identities = int(
        connection.execute(
            f"SELECT count(DISTINCT {_quoted(identity_column)}) FROM {table_name}"
        ).fetchone()[0]
    )
    rows: list[dict[str, Any]] = []
    for column in feature_columns:
        available_rows = int(
            connection.execute(
                f"SELECT count({_quoted(column)}) FROM {table_name}"
            ).fetchone()[0]
        )
        rows.append(
            {
                "grain": grain,
                "feature": column,
                "available_rows": available_rows,
                "total_rows": total_rows,
                "total_identities": total_identities,
                "availability_rate": available_rows / total_rows if total_rows else None,
            }
        )
    return rows


def build_quality_payload(
    connection: duckdb.DuckDBPyConnection,
    validations: list[RunValidation],
    counts: dict[str, int],
) -> dict[str, Any]:
    feature_availability = {
        "h1_origin": _feature_availability(
            connection,
            "signal_origins",
            "H1_ORIGIN",
            "origin_id",
            ORIGIN_SIGNAL_FEATURE_COLUMNS,
        ),
        "deep_event": _feature_availability(
            connection,
            "deep_pivot_events",
            "DEEP_EVENT",
            "deep_event_id",
            DEEP_SIGNAL_FEATURE_COLUMNS,
        ),
    }
    support = _fetch_dicts(
        connection,
        """
SELECT
  (SELECT count(DISTINCT origin_id) FROM signal_origins) AS unique_origins,
  (SELECT count(*) FROM h1_lane_long) AS h1_lane_rows,
  (SELECT count(*) FROM eligible_h1_trials) AS eligible_h1_rows,
  (SELECT count(*) FROM h1_lane_long
    WHERE h1_structural_lifecycle_seconds IS NOT NULL) AS completed_h1_duration_rows,
  (SELECT count(*) FROM h1_lane_long
    WHERE terminal_status = 'NOT_TRIGGERED') AS h1_not_triggered_rows,
  (SELECT count(*) FROM h1_lane_long
    WHERE terminal_status = 'INELIGIBLE') AS h1_ineligible_rows,
  (SELECT count(*) FROM h1_lane_long
    WHERE terminal_status = 'CENSORED_RUN_END') AS h1_run_censored_rows,
  (SELECT count(*) FROM deep_pivot_events) AS deep_event_rows,
  (SELECT count(DISTINCT deep_event_id) FROM deep_pivot_events)
    AS unique_deep_events,
  (SELECT count(*) FROM deep_pivot_events
    WHERE admission_status = 'CAPACITY_REJECTED') AS deep_capacity_rejected_rows,
  (SELECT count(*) FROM deep_pivot_parent_links) AS deep_parent_link_rows,
  (SELECT count(*) FROM deep_parent_long) AS deep_parent_outcome_rows,
  (SELECT count(*) FROM eligible_deep_trials) AS eligible_deep_rows,
  (SELECT count(DISTINCT origin_id) FROM eligible_deep_trials) AS eligible_deep_origins,
  (SELECT count(*) FROM deep_parent_long
    WHERE terminal_status = 'CENSORED_PARENT_EXIT') AS deep_parent_exit_censored_rows,
  (SELECT count(*) FROM deep_parent_long
    WHERE terminal_status = 'CENSORED_RUN_END') AS deep_run_censored_rows,
  (SELECT count(*) FROM broker_outcomes) AS broker_outcomes,
  (SELECT count(*) FROM broker_virtual_calibration) AS calibration_rows
""",
    )[0]
    h1_performance = _fetch_dicts(
        connection,
        """
WITH per_group AS (
  SELECT entry_policy, tp_r_multiple,
         count(*) AS eligible_rows,
         count(DISTINCT origin_id) AS unique_origins
  FROM eligible_h1_trials
  GROUP BY entry_policy, tp_r_multiple
), per_origin AS (
  SELECT entry_policy, tp_r_multiple, origin_id,
         avg(virtual_binary_target) AS tp_rate,
         avg(CASE WHEN virtual_binary_target = 1 THEN tp_r_multiple ELSE -1.0 END)
           AS expected_nominal_r,
         avg(virtual_quote_gross_r) AS virtual_quote_gross_r
  FROM eligible_h1_trials
  GROUP BY entry_policy, tp_r_multiple, origin_id
)
SELECT
  grouped.entry_policy,
  grouped.tp_r_multiple,
  grouped.eligible_rows,
  grouped.unique_origins,
  avg(per_origin.tp_rate) AS origin_balanced_tp_rate,
  1.0 / (grouped.tp_r_multiple + 1.0) AS break_even_tp_rate,
  avg(per_origin.expected_nominal_r) AS origin_balanced_expected_nominal_r,
  avg(per_origin.virtual_quote_gross_r)
    AS origin_balanced_virtual_quote_gross_r
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
         count(*) AS eligible_rows,
         count(DISTINCT origin_id) AS unique_origins,
         count(DISTINCT deep_event_id) AS unique_deep_events
  FROM eligible_deep_trials
  GROUP BY parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple
), per_origin AS (
  SELECT parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple,
         origin_id,
         avg(virtual_binary_target) AS tp_rate,
         avg(CASE WHEN virtual_binary_target = 1 THEN tp_r_multiple ELSE -1.0 END)
           AS expected_nominal_r,
         avg(virtual_quote_gross_r) AS virtual_quote_gross_r
  FROM eligible_deep_trials
  GROUP BY parent_kind, parent_entry_policy, parent_tp_r_multiple,
           tp_r_multiple, origin_id
)
SELECT
  grouped.parent_kind,
  grouped.parent_entry_policy,
  grouped.parent_tp_r_multiple,
  grouped.tp_r_multiple,
  grouped.eligible_rows,
  grouped.unique_origins,
  grouped.unique_deep_events,
  avg(per_origin.tp_rate) AS origin_balanced_tp_rate,
  1.0 / (grouped.tp_r_multiple + 1.0) AS break_even_tp_rate,
  avg(per_origin.expected_nominal_r) AS origin_balanced_expected_nominal_r,
  avg(per_origin.virtual_quote_gross_r)
    AS origin_balanced_virtual_quote_gross_r
FROM per_group grouped
JOIN per_origin USING (
  parent_kind, parent_entry_policy, parent_tp_r_multiple, tp_r_multiple
)
GROUP BY ALL
ORDER BY grouped.parent_kind, grouped.parent_entry_policy,
         grouped.parent_tp_r_multiple, grouped.tp_r_multiple
""",
    )
    h1_terminal_support = _fetch_dicts(
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
    deep_terminal_support = _fetch_dicts(
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
    broker = _fetch_dicts(
        connection,
        """
SELECT
  count(*) AS broker_outcomes,
  sum(CASE WHEN broker_binary_eligible THEN 1 ELSE 0 END) AS binary_eligible_rows,
  sum(CASE WHEN broker_binary_target = 1 THEN 1 ELSE 0 END) AS tp_rows,
  sum(CASE WHEN broker_binary_target = 0 THEN 1 ELSE 0 END) AS sl_rows,
  avg(broker_gross_profit) AS average_broker_gross_profit,
  avg(broker_net_profit) AS average_broker_net_profit
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
  avg(broker_minus_virtual_gross_profit) AS average_broker_minus_virtual_gross_profit
FROM broker_virtual_calibration
""",
    )[0]
    return {
        "builder_version": BUILDER_VERSION,
        "schema_version": SUPPORTED_SCHEMA_VERSION,
        "engine_label": SUPPORTED_ENGINE_LABEL,
        "feature_set_id": SUPPORTED_FEATURE_SET_ID,
        "available_feature_set_ids": [H1_FEATURE_SET_ID, DEEP_FEATURE_SET_ID],
        "research_approval_state": "OFFLINE_RESEARCH_ONLY",
        "counts": counts,
        "run_ids": [validation.run_id for validation in validations],
        "warnings": [warning for validation in validations for warning in validation.warnings],
        "feature_availability": feature_availability,
        "support": support,
        "h1_performance": h1_performance,
        "deep_performance": deep_performance,
        "h1_terminal_support": h1_terminal_support,
        "deep_terminal_support": deep_terminal_support,
        "broker_performance": broker,
        "broker_virtual_calibration": calibration,
        "outcome_boundaries": {
            "h1_virtual": "H1 structural/midpoint counterfactual evidence only",
            "deep_virtual": "parent-scoped deep 1R/2R/3R evidence only",
            "broker": "deal-history broker facts only",
            "calibration": "accepted-request parity comparison only",
        },
        "duration_policy": (
            "h1_structural_lifecycle_seconds is retrospective and non-null only for "
            "confirmed completed H1 parents; m10_parent_age_seconds is causal at trigger"
        ),
        "support_warning": (
            "Deep rows are correlated within events, parents, origins, and Macro windows; "
            "report row, event, and unique-origin support separately."
        ),
    }


def build_feature_contracts() -> dict[str, Any]:
    return {
        H1_FEATURE_SET_ID: {
            "source_grain": "H1_LANE",
            "training_table": "eligible_h1_trials",
            "model_features": list(H1_MODEL_FEATURE_COLUMNS),
            "categorical_features": list(H1_CATEGORICAL_COLUMNS),
            "target": "virtual_binary_target",
            "origin_weight_policy": ORIGIN_WEIGHT_POLICY,
            "grouping_policy": "macro_window_identity_across_runs",
        },
        DEEP_FEATURE_SET_ID: {
            "source_grain": "DEEP_PARENT_LINK_X_RATIO",
            "training_table": "eligible_deep_trials",
            "event_feature_source": "deep_pivot_events",
            "event_feature_join": ["run_id", "config_id", "deep_event_id"],
            "event_features_native_grain": True,
            "event_features_persisted_in_training_table": False,
            "model_features": list(DEEP_MODEL_FEATURE_COLUMNS),
            "categorical_features": list(DEEP_CATEGORICAL_COLUMNS),
            "target": "virtual_binary_target",
            "origin_weight_policy": ORIGIN_WEIGHT_POLICY,
            "event_weight_policy": EVENT_WEIGHT_POLICY,
            "grouping_policy": "macro_window_identity_across_runs",
        },
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
        "available_feature_set_ids": [H1_FEATURE_SET_ID, DEEP_FEATURE_SET_ID],
        "research_approval_state": "OFFLINE_RESEARCH_ONLY",
        "runtime_artifact": False,
        "run_ids": [validation.run_id for validation in validations],
        "configuration": {key: baseline[key] for key in DATASET_CONFIG_KEYS},
        "feature_contracts": build_feature_contracts(),
        "future_only_columns": list(FUTURE_ONLY_COLUMNS),
        "duration_research_contract": {
            "h1_filter_column": "h1_structural_lifecycle_seconds",
            "deep_age_filter_column": "m10_parent_age_seconds",
            "public_operator": "<=",
            "minutes_conversion": "minutes * 60 without rounding",
            "completed_h1_duration_required": True,
            "implicit_cap": False,
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
        f"# Pivot V14 Dataset Report: {dataset_id}",
        "",
        "- Status: `OFFLINE_RESEARCH_ONLY`",
        f"- Unique H1 origins: `{support['unique_origins']}`",
        f"- H1 lane rows / eligible: `{support['h1_lane_rows']}` / `{support['eligible_h1_rows']}`",
        f"- Deep events / parent outcomes / eligible: `{support['deep_event_rows']}` / "
        f"`{support['deep_parent_outcome_rows']}` / `{support['eligible_deep_rows']}`",
        f"- Unique deep event identities: `{support['unique_deep_events']}`",
        f"- Completed H1 duration rows: `{support['completed_h1_duration_rows']}`",
        f"- Capacity-rejected deep events: `{support['deep_capacity_rejected_rows']}`",
        "",
        "## Evidence Boundaries",
        "",
        "H1 lanes, shared M10 events, parent-scoped deep outcomes, broker outcomes, and parity calibration remain separate grains.",
        "Deep indicator features stay in `deep_pivot_events`; parent/ratio Parquet rows join them only for explicit model loading.",
        "Censored, ineligible, and not-triggered rows remain support evidence and are never target-zero losses.",
        "",
        "## Duration Semantics",
        "",
        quality_payload["duration_policy"],
        "There is no 30/60/120-minute cap; downstream research applies exact `<= minutes * 60` predicates.",
        "",
        "## Calibration",
        "",
        f"- Paired rows: `{calibration['paired_rows']}`",
        f"- Strict pairs: `{calibration['strict_pairs']}`",
        f"- Terminal mismatches: `{calibration['terminal_mismatches']}`",
        "",
        "## Statistical Caution",
        "",
        quality_payload["support_warning"],
        "",
    ]
    (output_dir / "dataset_report.md").write_text("\n".join(lines), encoding="utf-8")
