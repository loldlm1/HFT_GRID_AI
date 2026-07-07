"""Build deterministic feature-pattern audit reports from local datasets."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import duckdb

from model_config import DEFAULT_DATASET_ROOT


DEFAULT_OUTPUT_ROOT = "artifacts/pattern_audits"
DEFAULT_FINAL_HOLDOUT_FRACTION = 0.20
DEFAULT_MIN_TOTAL_ROWS = 150
DEFAULT_MIN_PREFINAL_ROWS = 100
DEFAULT_MIN_FINAL_ROWS = 20
DEFAULT_MAX_CONDITION_COUNT = 5
DEFAULT_MAX_CATALOG_PATTERNS = 300
DEFAULT_MAX_GROUPS_PER_TEMPLATE = 250
DEFAULT_TOP_N_VISUAL = 12

PATTERN_CATALOG_FILE = "pattern_catalog.tsv"
PATTERN_SUMMARY_FILE = "pattern_summary.tsv"
PATTERN_MATCHES_FILE = "pattern_matches.tsv"
PATTERN_REPORT_FILE = "pattern_audit_report.md"
PATTERN_JSON_FILE = "pattern_audit.json"
PATTERN_SELECTION_FILE = "pattern_selection.tsv"

PATTERN_CATALOG_COLUMNS = (
    "audit_id",
    "pattern_id",
    "pattern_label",
    "pattern_source",
    "selected_for_visual",
    "selection_reason",
    "status",
    "condition_count",
    "conditions_text",
    "template_id",
    "template_columns",
)

PATTERN_SUMMARY_COLUMNS = (
    "audit_id",
    "pattern_id",
    "pattern_label",
    "pattern_source",
    "selected_for_visual",
    "status",
    "condition_count",
    "conditions_text",
    "rows",
    "pre_final_rows",
    "pre_final_win_rate",
    "pre_final_mean_r",
    "pre_final_net_r",
    "pre_final_max_drawdown_r",
    "final_holdout_rows",
    "final_holdout_win_rate",
    "final_holdout_mean_r",
    "final_holdout_net_r",
    "final_holdout_max_drawdown_r",
    "month_count",
    "strategy_count",
    "direction_count",
    "warning_codes",
)

PATTERN_MATCH_COLUMNS = (
    "audit_id",
    "pattern_id",
    "pattern_label",
    "pattern_source",
    "selected_for_visual",
    "condition_count",
    "conditions_text",
    "signal_id",
    "source_key",
    "source_family_key",
    "source_attempt_index",
    "symbol",
    "strategy_label",
    "direction",
    "entry_time",
    "source_time",
    "terminal_time",
    "target_terminal_reason",
    "target_profit_r",
    "net_profit",
    "split_name",
)


class PatternAuditError(RuntimeError):
    """Raised when a pattern audit cannot be built."""


@dataclass(frozen=True)
class Condition:
    column: str
    value: Any


@dataclass(frozen=True)
class PatternDefinition:
    pattern_id: str
    pattern_label: str
    pattern_source: str
    conditions: tuple[Condition, ...]
    template_id: str
    template_columns: tuple[str, ...]

    @property
    def conditions_text(self) -> str:
        return "; ".join(
            f"{condition.column}={_display_value(condition.value)}"
            for condition in self.conditions
        )

    @property
    def condition_count(self) -> int:
        return len(self.conditions)


@dataclass(frozen=True)
class PatternMetrics:
    rows: int
    pre_final_rows: int
    pre_final_win_rate: float | None
    pre_final_mean_r: float | None
    pre_final_net_r: float
    pre_final_max_drawdown_r: float
    final_holdout_rows: int
    final_holdout_win_rate: float | None
    final_holdout_mean_r: float | None
    final_holdout_net_r: float
    final_holdout_max_drawdown_r: float
    month_count: int
    strategy_count: int
    direction_count: int
    status: str
    warning_codes: tuple[str, ...]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    dataset_group = parser.add_mutually_exclusive_group(required=True)
    dataset_group.add_argument("--dataset-id", help="Dataset ID under --dataset-root.")
    dataset_group.add_argument("--dataset-path", help="Explicit dataset folder.")
    parser.add_argument("--dataset-root", default=DEFAULT_DATASET_ROOT)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--output-root", default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--final-holdout-fraction", type=float, default=DEFAULT_FINAL_HOLDOUT_FRACTION)
    parser.add_argument("--min-total-rows", type=int, default=DEFAULT_MIN_TOTAL_ROWS)
    parser.add_argument("--min-prefinal-rows", type=int, default=DEFAULT_MIN_PREFINAL_ROWS)
    parser.add_argument("--min-final-rows", type=int, default=DEFAULT_MIN_FINAL_ROWS)
    parser.add_argument("--max-condition-count", type=int, default=DEFAULT_MAX_CONDITION_COUNT)
    parser.add_argument("--max-catalog-patterns", type=int, default=DEFAULT_MAX_CATALOG_PATTERNS)
    parser.add_argument("--max-groups-per-template", type=int, default=DEFAULT_MAX_GROUPS_PER_TEMPLATE)
    parser.add_argument("--top-n-visual", type=int, default=DEFAULT_TOP_N_VISUAL)
    parser.add_argument("--pattern-id", action="append", default=[], help="Pattern ID to force into visual selection.")
    parser.add_argument("--selection-file", default="", help="Optional TSV with a pattern_id column.")
    parser.add_argument(
        "--strategy-label",
        action="append",
        default=[],
        help="Optional strategy_label filter. Repeat for S1/S2/S3 scoped audits.",
    )
    return parser


def resolve_dataset_path(args: argparse.Namespace) -> Path:
    path = Path(args.dataset_path) if args.dataset_path else Path(args.dataset_root) / args.dataset_id
    if not path.is_dir():
        raise PatternAuditError(f"Dataset folder does not exist: {path}")
    matrix = path / "training_matrix.parquet"
    if not matrix.exists():
        raise PatternAuditError(f"Dataset is missing training_matrix.parquet: {matrix}")
    return path


def prepare_output_dir(output_root: Path, audit_id: str, overwrite: bool) -> Path:
    output_dir = output_root / audit_id
    resolved_root = output_root.resolve()
    resolved_output = output_dir.resolve()
    if resolved_root == resolved_output or resolved_root not in resolved_output.parents:
        raise PatternAuditError(f"Refusing pattern output outside output root: {output_dir}")
    if output_dir.exists():
        if not overwrite:
            raise PatternAuditError(f"Pattern audit already exists. Use --overwrite: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    return output_dir


def _sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def _sql_path(path: Path) -> str:
    return path.resolve().as_posix().replace("'", "''")


def _display_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:.8g}"
    return str(value)


def _strategy_filter_clause(strategy_labels: list[str]) -> str:
    labels = sorted({label.strip() for label in strategy_labels if label.strip()})
    if not labels:
        return ""
    values = ", ".join(_sql_literal(label) for label in labels)
    return f"WHERE strategy_label IN ({values})"


def _human_direction(value: Any) -> str:
    token = str(value).upper()
    if token == "BULLISH":
        return "Bullish"
    if token == "BEARISH":
        return "Bearish"
    return str(value)


def _human_slope(value: Any) -> str:
    try:
        slope = int(value)
    except (TypeError, ValueError):
        return str(value)
    if slope > 0:
        return "bullish"
    if slope < 0:
        return "bearish"
    return "flat"


def _human_fib_band(value: Any) -> str:
    parts = str(value).split("_")
    levels: list[str] = []
    index = 0
    while index < len(parts):
        part = parts[index].replace(".0", "")
        if (
            index + 1 < len(parts)
            and "." not in part
            and parts[index + 1] in {"2", "8"}
        ):
            levels.append(f"{part}.{parts[index + 1]}")
            index += 2
        else:
            levels.append(part)
            index += 1
    return "-".join(levels)


def _human_profile(value: Any) -> str:
    return str(value).replace("_", " ").lower()


def _human_condition(condition: Condition) -> str:
    column = condition.column
    value = condition.value

    if column == "strategy_label":
        return str(value)
    if column == "direction":
        return _human_direction(value)
    if column == "structure_0":
        return f"{value}[0]"
    if column == "structure_1":
        return f"{value}[1]"
    if column == "structure_2":
        return f"{value}[2]"
    if column == "macro_h1_slope":
        return f"H1 slope {_human_slope(value)}"
    if column == "macro_h4_slope":
        return f"H4 slope {_human_slope(value)}"
    if column == "macro_d1_slope":
        return f"D1 slope {_human_slope(value)}"
    if column == "fib_sl_band":
        return f"SL Fib {_human_fib_band(value)}"
    if column == "fib_entry_band":
        return f"Entry Fib {_human_fib_band(value)}"
    if column == "high_chain_profile":
        return f"High chain {_human_profile(value)}"
    if column == "low_chain_profile":
        return f"Low chain {_human_profile(value)}"
    if column == "previous_candle_profile":
        return f"Previous candle {_human_profile(value)}"
    if column == "entry_session_bucket":
        return f"Session {value}"
    if column == "entry_weekday":
        return f"Weekday {value}"
    return f"{column} {value}"


def human_pattern_label(conditions: tuple[Condition, ...]) -> str:
    return " | ".join(_human_condition(condition) for condition in conditions)


def _tsv_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:.10g}"
    return str(value)


def _fetch_dicts(connection: duckdb.DuckDBPyConnection, sql: str) -> list[dict[str, Any]]:
    result = connection.execute(sql)
    columns = [column[0] for column in result.description]
    return [dict(zip(columns, row)) for row in result.fetchall()]


def create_audit_table(
    connection: duckdb.DuckDBPyConnection,
    dataset_path: Path,
    final_holdout_fraction: float,
    strategy_labels: list[str],
) -> int:
    if not (0.0 < final_holdout_fraction < 1.0):
        raise PatternAuditError("--final-holdout-fraction must be between 0 and 1")
    matrix_path = dataset_path / "training_matrix.parquet"
    strategy_filter_clause = _strategy_filter_clause(strategy_labels)
    total_rows = int(
        connection.execute(
            f"""
SELECT COUNT(*)
FROM read_parquet('{_sql_path(matrix_path)}')
{strategy_filter_clause}
"""
        ).fetchone()[0]
    )
    if total_rows <= 0:
        raise PatternAuditError(f"Dataset has no training rows: {matrix_path}")
    final_rows = max(1, int(round(total_rows * final_holdout_fraction)))
    pre_final_rows = total_rows - final_rows
    if pre_final_rows <= 0:
        raise PatternAuditError("Dataset is too small for pre-final/final split")

    connection.execute(
        f"""
CREATE OR REPLACE TEMP TABLE audit_rows AS
SELECT
  *,
  CASE WHEN row_index > {pre_final_rows} THEN 'final_holdout' ELSE 'pre_final' END AS split_name,
  strftime(entry_time, '%Y-%m') AS entry_month
FROM (
  SELECT
    row_number() OVER (ORDER BY entry_time, signal_id) AS row_index,
    *
  FROM read_parquet('{_sql_path(matrix_path)}')
  {strategy_filter_clause}
)
ORDER BY entry_time, signal_id
"""
    )
    return total_rows


def pattern_templates(max_condition_count: int) -> list[tuple[str, tuple[str, ...]]]:
    templates = [
        ("direction_structure_2", ("direction", "structure_0")),
        ("direction_structure_3", ("direction", "structure_0", "structure_1")),
        ("direction_structure_stack", ("direction", "structure_0", "structure_1", "structure_2")),
        ("direction_macro_h1_h4", ("direction", "macro_h1_slope", "macro_h4_slope")),
        ("direction_macro_stack", ("direction", "macro_h1_slope", "macro_h4_slope", "macro_d1_slope")),
        ("direction_fib", ("direction", "fib_sl_band", "fib_entry_band")),
        ("direction_structure_fib", ("direction", "structure_0", "fib_sl_band", "fib_entry_band")),
        ("direction_high_chain", ("direction", "high_chain_profile")),
        ("direction_low_chain", ("direction", "low_chain_profile")),
        ("direction_chain_stack", ("direction", "high_chain_profile", "low_chain_profile")),
        ("direction_chain_fib_entry", ("direction", "high_chain_profile", "low_chain_profile", "fib_entry_band")),
        ("direction_candle", ("direction", "previous_candle_profile")),
        ("direction_structure_macro_high_chain", ("direction", "structure_0", "macro_h1_slope", "high_chain_profile")),
        ("direction_structure_macro_low_chain", ("direction", "structure_0", "macro_h1_slope", "low_chain_profile")),
        ("direction_structure_macro_fib", ("direction", "structure_0", "macro_h1_slope", "fib_entry_band")),
        ("direction_session", ("direction", "entry_session_bucket")),
        ("direction_weekday", ("direction", "entry_weekday")),
        ("direction_session_weekday", ("direction", "entry_session_bucket", "entry_weekday")),
    ]
    scoped_templates: list[tuple[str, tuple[str, ...]]] = []
    for template_id, columns in templates:
        scoped_columns = ("strategy_label", *columns)
        if len(scoped_columns) <= max_condition_count:
            scoped_templates.append((f"strategy_{template_id}", scoped_columns))
    return scoped_templates


def _pattern_id(conditions_text: str) -> str:
    digest = hashlib.sha1(conditions_text.encode("utf-8")).hexdigest()[:12]
    return "pat_" + digest


def build_catalog(
    connection: duckdb.DuckDBPyConnection,
    args: argparse.Namespace,
) -> list[PatternDefinition]:
    definitions_by_id: dict[str, PatternDefinition] = {}
    templates = pattern_templates(args.max_condition_count)
    for template_id, columns in templates:
        column_list = ", ".join(columns)
        null_clause = " AND ".join(f"{column} IS NOT NULL" for column in columns)
        rows = _fetch_dicts(
            connection,
            f"""
SELECT
  {column_list},
  COUNT(*) AS rows
FROM audit_rows
WHERE {null_clause}
GROUP BY {column_list}
HAVING COUNT(*) >= {int(args.min_total_rows)}
ORDER BY rows DESC, {column_list}
LIMIT {int(args.max_groups_per_template)}
""",
        )
        for row in rows:
            conditions = tuple(Condition(column, row[column]) for column in columns)
            conditions_text = "; ".join(
                f"{condition.column}={_display_value(condition.value)}"
                for condition in conditions
            )
            pattern_id = _pattern_id(conditions_text)
            if pattern_id in definitions_by_id:
                continue
            definitions_by_id[pattern_id] = PatternDefinition(
                pattern_id=pattern_id,
                pattern_label=human_pattern_label(conditions),
                pattern_source="auto_template",
                conditions=conditions,
                template_id=template_id,
                template_columns=columns,
            )

    definitions = list(definitions_by_id.values())
    definitions.sort(key=lambda item: (item.template_id, item.conditions_text))
    return definitions


def where_clause(definition: PatternDefinition) -> str:
    clauses = []
    for condition in definition.conditions:
        if condition.value is None:
            clauses.append(f"{condition.column} IS NULL")
        else:
            clauses.append(f"{condition.column} = {_sql_literal(condition.value)}")
    return " AND ".join(clauses)


def _max_drawdown(profits: list[float]) -> float:
    equity = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for profit in profits:
        equity += profit
        peak = max(peak, equity)
        max_drawdown = max(max_drawdown, peak - equity)
    return float(max_drawdown)


def _split_metrics(
    connection: duckdb.DuckDBPyConnection,
    definition: PatternDefinition,
    split_name: str,
) -> tuple[int, float | None, float | None, float, float]:
    rows = _fetch_dicts(
        connection,
        f"""
SELECT target_is_win, target_profit_r
FROM audit_rows
WHERE {where_clause(definition)}
  AND split_name = {_sql_literal(split_name)}
ORDER BY entry_time, signal_id
""",
    )
    count = len(rows)
    if count == 0:
        return 0, None, None, 0.0, 0.0
    profits = [float(row["target_profit_r"]) for row in rows]
    wins = sum(1 for row in rows if int(row["target_is_win"]) == 1)
    return (
        count,
        wins / count,
        sum(profits) / count,
        sum(profits),
        _max_drawdown(profits),
    )


def _distinct_count(
    connection: duckdb.DuckDBPyConnection,
    definition: PatternDefinition,
    column: str,
) -> int:
    return int(
        connection.execute(
            f"SELECT COUNT(DISTINCT {column}) FROM audit_rows WHERE {where_clause(definition)}"
        ).fetchone()[0]
    )


def evaluate_pattern(
    connection: duckdb.DuckDBPyConnection,
    definition: PatternDefinition,
    args: argparse.Namespace,
) -> PatternMetrics:
    rows = int(
        connection.execute(
            f"SELECT COUNT(*) FROM audit_rows WHERE {where_clause(definition)}"
        ).fetchone()[0]
    )
    pre_rows, pre_win, pre_mean, pre_net, pre_dd = _split_metrics(connection, definition, "pre_final")
    final_rows, final_win, final_mean, final_net, final_dd = _split_metrics(connection, definition, "final_holdout")
    month_count = _distinct_count(connection, definition, "entry_month")
    strategy_count = _distinct_count(connection, definition, "strategy_label")
    direction_count = _distinct_count(connection, definition, "direction")

    warnings: list[str] = []
    if rows < args.min_total_rows or pre_rows < args.min_prefinal_rows:
        status = "RARE_BUCKET_IGNORE"
        warnings.append("low_prefinal_support")
    elif pre_net <= 0.0 or pre_mean is None or pre_mean <= 0.0:
        status = "REVIEW"
        warnings.append("non_positive_prefinal")
    elif final_rows < args.min_final_rows:
        status = "FINAL_HOLDOUT_FAIL"
        warnings.append("low_final_support")
    elif final_net <= 0.0 or final_mean is None or final_mean <= 0.0:
        status = "FINAL_HOLDOUT_FAIL"
        warnings.append("non_positive_final")
    elif strategy_count < 2 or direction_count < 1:
        status = "REVIEW"
        warnings.append("narrow_segment_support")
    else:
        status = "AUDIT_PASS"

    if month_count < 3:
        warnings.append("low_month_coverage")

    return PatternMetrics(
        rows=rows,
        pre_final_rows=pre_rows,
        pre_final_win_rate=pre_win,
        pre_final_mean_r=pre_mean,
        pre_final_net_r=pre_net,
        pre_final_max_drawdown_r=pre_dd,
        final_holdout_rows=final_rows,
        final_holdout_win_rate=final_win,
        final_holdout_mean_r=final_mean,
        final_holdout_net_r=final_net,
        final_holdout_max_drawdown_r=final_dd,
        month_count=month_count,
        strategy_count=strategy_count,
        direction_count=direction_count,
        status=status,
        warning_codes=tuple(warnings),
    )


def load_manual_pattern_ids(args: argparse.Namespace) -> set[str]:
    pattern_ids = set(args.pattern_id or [])
    if args.selection_file:
        path = Path(args.selection_file)
        if not path.exists():
            raise PatternAuditError(f"Selection file does not exist: {path}")
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if not reader.fieldnames or "pattern_id" not in reader.fieldnames:
                raise PatternAuditError("Selection file must include a pattern_id column")
            for row in reader:
                pattern_id = (row.get("pattern_id") or "").strip()
                if pattern_id:
                    pattern_ids.add(pattern_id)
    return pattern_ids


def select_patterns(
    definitions: list[PatternDefinition],
    metrics_by_id: dict[str, PatternMetrics],
    manual_pattern_ids: set[str],
    top_n_visual: int,
) -> dict[str, str]:
    eligible = [
        definition
        for definition in definitions
        if metrics_by_id[definition.pattern_id].status != "RARE_BUCKET_IGNORE"
    ]
    eligible.sort(
        key=lambda definition: (
            metrics_by_id[definition.pattern_id].pre_final_net_r,
            metrics_by_id[definition.pattern_id].final_holdout_rows,
            metrics_by_id[definition.pattern_id].rows,
        ),
        reverse=True,
    )
    selected: dict[str, str] = {}
    for definition in eligible[: max(0, top_n_visual)]:
        selected[definition.pattern_id] = "auto_top_prefinal_net_r"
    for pattern_id in sorted(manual_pattern_ids):
        selected[pattern_id] = "manual_review"
    missing = sorted(pattern_id for pattern_id in manual_pattern_ids if pattern_id not in metrics_by_id)
    if missing:
        raise PatternAuditError("Manual pattern IDs were not found: " + ", ".join(missing))
    return selected


def write_tsv(path: Path, columns: tuple[str, ...], rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(columns), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: _tsv_value(row.get(column, "")) for column in columns})


def catalog_rows(
    audit_id: str,
    definitions: list[PatternDefinition],
    metrics_by_id: dict[str, PatternMetrics],
    selected: dict[str, str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for definition in definitions:
        metrics = metrics_by_id[definition.pattern_id]
        rows.append(
            {
                "audit_id": audit_id,
                "pattern_id": definition.pattern_id,
                "pattern_label": definition.pattern_label,
                "pattern_source": definition.pattern_source,
                "selected_for_visual": definition.pattern_id in selected,
                "selection_reason": selected.get(definition.pattern_id, ""),
                "status": metrics.status,
                "condition_count": definition.condition_count,
                "conditions_text": definition.conditions_text,
                "template_id": definition.template_id,
                "template_columns": ",".join(definition.template_columns),
            }
        )
    return rows


def summary_rows(
    audit_id: str,
    definitions: list[PatternDefinition],
    metrics_by_id: dict[str, PatternMetrics],
    selected: dict[str, str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for definition in definitions:
        metrics = metrics_by_id[definition.pattern_id]
        rows.append(
            {
                "audit_id": audit_id,
                "pattern_id": definition.pattern_id,
                "pattern_label": definition.pattern_label,
                "pattern_source": definition.pattern_source,
                "selected_for_visual": definition.pattern_id in selected,
                "status": metrics.status,
                "condition_count": definition.condition_count,
                "conditions_text": definition.conditions_text,
                "rows": metrics.rows,
                "pre_final_rows": metrics.pre_final_rows,
                "pre_final_win_rate": metrics.pre_final_win_rate,
                "pre_final_mean_r": metrics.pre_final_mean_r,
                "pre_final_net_r": metrics.pre_final_net_r,
                "pre_final_max_drawdown_r": metrics.pre_final_max_drawdown_r,
                "final_holdout_rows": metrics.final_holdout_rows,
                "final_holdout_win_rate": metrics.final_holdout_win_rate,
                "final_holdout_mean_r": metrics.final_holdout_mean_r,
                "final_holdout_net_r": metrics.final_holdout_net_r,
                "final_holdout_max_drawdown_r": metrics.final_holdout_max_drawdown_r,
                "month_count": metrics.month_count,
                "strategy_count": metrics.strategy_count,
                "direction_count": metrics.direction_count,
                "warning_codes": ",".join(metrics.warning_codes),
            }
        )
    rows.sort(
        key=lambda row: (
            row["selected_for_visual"],
            row["pre_final_net_r"],
            row["final_holdout_rows"],
            row["rows"],
        ),
        reverse=True,
    )
    return rows


def match_rows(
    connection: duckdb.DuckDBPyConnection,
    audit_id: str,
    definitions: list[PatternDefinition],
    selected: dict[str, str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    selected_definitions = [
        definition for definition in definitions if definition.pattern_id in selected
    ]
    selected_definitions.sort(key=lambda definition: definition.pattern_id)
    for definition in selected_definitions:
        matches = _fetch_dicts(
            connection,
            f"""
SELECT
  signal_id,
  source_key,
  regexp_replace(source_key, '^[^|]+\\|', '') AS source_family_key,
  source_attempt_index,
  symbol,
  strategy_label,
  direction,
  entry_time,
  source_time,
  terminal_time,
  target_terminal_reason,
  target_profit_r,
  net_profit,
  split_name
FROM audit_rows
WHERE {where_clause(definition)}
ORDER BY entry_time, signal_id
""",
        )
        for match in matches:
            output = {
                "audit_id": audit_id,
                "pattern_id": definition.pattern_id,
                "pattern_label": definition.pattern_label,
                "pattern_source": definition.pattern_source,
                "selected_for_visual": True,
                "condition_count": definition.condition_count,
                "conditions_text": definition.conditions_text,
            }
            output.update(match)
            rows.append(output)
    return rows


def render_report(
    audit_id: str,
    dataset_id: str,
    total_rows: int,
    definitions: list[PatternDefinition],
    metrics_by_id: dict[str, PatternMetrics],
    selected: dict[str, str],
) -> str:
    status_counts: dict[str, int] = {}
    for metrics in metrics_by_id.values():
        status_counts[metrics.status] = status_counts.get(metrics.status, 0) + 1
    selected_rows = [
        (definition, metrics_by_id[definition.pattern_id], selected[definition.pattern_id])
        for definition in definitions
        if definition.pattern_id in selected
    ]
    selected_rows.sort(
        key=lambda item: (item[1].pre_final_net_r, item[1].final_holdout_rows, item[1].rows),
        reverse=True,
    )
    lines = [
        f"# Pattern Audit: {audit_id}",
        "",
        f"- Dataset: `{dataset_id}`",
        f"- Training rows: `{total_rows}`",
        f"- Catalog patterns: `{len(definitions)}`",
        f"- Selected visual patterns: `{len(selected)}`",
        "",
        "## Status Counts",
        "",
    ]
    for status in sorted(status_counts):
        lines.append(f"- `{status}`: {status_counts[status]}")
    lines.extend(["", "## Selected Patterns", ""])
    if not selected_rows:
        lines.append("No selected patterns.")
    else:
        lines.extend(
            [
                "| Pattern | Reason | Status | Conditions | Pre-Final Rows | Pre-Final Net R | Final Rows | Final Net R |",
                "| --- | --- | --- | --- | ---: | ---: | ---: | ---: |",
            ]
        )
        for definition, metrics, reason in selected_rows[:30]:
            conditions = definition.conditions_text.replace("|", "\\|")
            lines.append(
                "| `{}` | `{}` | `{}` | {} | {} | {:.4f} | {} | {:.4f} |".format(
                    definition.pattern_id,
                    reason,
                    metrics.status,
                    conditions,
                    metrics.pre_final_rows,
                    metrics.pre_final_net_r,
                    metrics.final_holdout_rows,
                    metrics.final_holdout_net_r,
                )
            )
    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- Pattern ranking uses pre-final evidence only.",
            "- Final holdout is approval evidence only.",
            "- Selected patterns are for Strategy Tester playback, not runtime FILTER.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_selection_file(output_dir: Path, selected: dict[str, str]) -> None:
    rows = [
        {"pattern_id": pattern_id, "selection_reason": reason}
        for pattern_id, reason in sorted(selected.items())
    ]
    write_tsv(output_dir / PATTERN_SELECTION_FILE, ("pattern_id", "selection_reason"), rows)


def build_payload(
    audit_id: str,
    dataset_id: str,
    total_rows: int,
    definitions: list[PatternDefinition],
    metrics_by_id: dict[str, PatternMetrics],
    selected: dict[str, str],
) -> dict[str, Any]:
    status_counts: dict[str, int] = {}
    for metrics in metrics_by_id.values():
        status_counts[metrics.status] = status_counts.get(metrics.status, 0) + 1
    selected_ids = sorted(selected)
    return {
        "audit_id": audit_id,
        "dataset_id": dataset_id,
        "generated_at": datetime.now(UTC).isoformat(),
        "training_rows": total_rows,
        "catalog_pattern_count": len(definitions),
        "selected_pattern_count": len(selected),
        "selected_pattern_ids": selected_ids,
        "status_counts": status_counts,
        "selection_reasons": selected,
        "runtime_filter_approved": False,
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    dataset_path = resolve_dataset_path(args)
    dataset_id = dataset_path.name
    output_dir = prepare_output_dir(Path(args.output_root), args.audit_id, args.overwrite)

    connection = duckdb.connect(":memory:")
    try:
        total_rows = create_audit_table(
            connection,
            dataset_path,
            args.final_holdout_fraction,
            args.strategy_label,
        )
        definitions = build_catalog(connection, args)
        if not definitions:
            raise PatternAuditError("No patterns met the catalog support guard")
        metrics_by_id: dict[str, PatternMetrics] = {}
        for definition in definitions:
            metrics_by_id[definition.pattern_id] = evaluate_pattern(connection, definition, args)
        definitions.sort(
            key=lambda definition: (
                metrics_by_id[definition.pattern_id].pre_final_net_r,
                metrics_by_id[definition.pattern_id].final_holdout_rows,
                metrics_by_id[definition.pattern_id].rows,
                definition.pattern_id,
            ),
            reverse=True,
        )
        definitions = definitions[: int(args.max_catalog_patterns)]
        metrics_by_id = {
            definition.pattern_id: metrics_by_id[definition.pattern_id]
            for definition in definitions
        }
        manual_pattern_ids = load_manual_pattern_ids(args)
        selected = select_patterns(definitions, metrics_by_id, manual_pattern_ids, args.top_n_visual)
        write_tsv(
            output_dir / PATTERN_CATALOG_FILE,
            PATTERN_CATALOG_COLUMNS,
            catalog_rows(args.audit_id, definitions, metrics_by_id, selected),
        )
        write_tsv(
            output_dir / PATTERN_SUMMARY_FILE,
            PATTERN_SUMMARY_COLUMNS,
            summary_rows(args.audit_id, definitions, metrics_by_id, selected),
        )
        matches = match_rows(connection, args.audit_id, definitions, selected)
        write_tsv(output_dir / PATTERN_MATCHES_FILE, PATTERN_MATCH_COLUMNS, matches)
        write_selection_file(output_dir, selected)
        report = render_report(args.audit_id, dataset_id, total_rows, definitions, metrics_by_id, selected)
        (output_dir / PATTERN_REPORT_FILE).write_text(report, encoding="utf-8")
        payload = build_payload(args.audit_id, dataset_id, total_rows, definitions, metrics_by_id, selected)
        (output_dir / PATTERN_JSON_FILE).write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
    except (duckdb.Error, PatternAuditError, ValueError, json.JSONDecodeError) as exc:
        parser.exit(1, f"pattern audit failed: {exc}\n")
    finally:
        connection.close()

    print(
        "pattern audit ok | "
        f"audit={args.audit_id} | dataset={dataset_id} | patterns={len(definitions)} | "
        f"selected={len(selected)} | matches={len(matches)} | output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
