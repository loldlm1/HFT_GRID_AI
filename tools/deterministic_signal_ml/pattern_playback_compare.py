"""Compare offline pattern matches with Strategy Tester playback observations."""

from __future__ import annotations

import argparse
import csv
import json
import os
from collections import Counter
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


DEFAULT_AUDIT_ROOT = "artifacts/pattern_audits"
COMMON_PATTERN_ROOT = Path("DeterministicSignalML") / "pattern_audits"

PATTERN_MATCHES_FILE = "pattern_matches.tsv"
PATTERN_OBSERVATIONS_FILE = "pattern_tester_observations.tsv"
PARITY_JSON_FILE = "pattern_playback_parity.json"
PARITY_REPORT_FILE = "pattern_playback_parity.md"
PARITY_MISMATCHES_FILE = "pattern_playback_mismatches.tsv"

MATCH_REQUIRED_COLUMNS = (
    "pattern_id",
    "selected_for_visual",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "entry_time",
    "pattern_label",
    "conditions_text",
)

OBSERVATION_REQUIRED_COLUMNS = (
    "pattern_id",
    "source_key",
    "source_attempt_index",
    "expected_match",
    "observation_status",
    "pattern_label",
    "conditions_text",
)

MISMATCH_COLUMNS = (
    "mismatch_type",
    "pattern_id",
    "source_key",
    "source_attempt_index",
    "expected_signal_id",
    "observed_signal_id",
    "expected_entry_time",
    "observed_entry_time",
    "observed_runtime_signal_id",
    "observed_runtime_entry_time",
    "expected_status",
    "observed_status",
    "pattern_label",
    "conditions_text",
)


class PatternPlaybackCompareError(RuntimeError):
    """Raised when playback parity cannot be compared."""


@dataclass(frozen=True)
class PatternPlaybackRow:
    pattern_id: str
    signal_id: str
    source_key: str
    source_attempt_index: str
    entry_time: str
    pattern_label: str
    conditions_text: str
    expected_match: str = "true"
    observation_status: str = "EXPECTED"
    runtime_signal_id: str = ""
    runtime_entry_time: str = ""

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.pattern_id, self.source_key, self.source_attempt_index)

    @property
    def entry_key(self) -> tuple[str, str]:
        return (self.source_key, self.source_attempt_index)

    @property
    def direction(self) -> str:
        parts = self.source_key.split("|")
        if len(parts) >= 2 and parts[1]:
            return parts[1].upper()
        return "UNKNOWN"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit-id", help="Pattern audit ID.")
    parser.add_argument("--audit-root", default=DEFAULT_AUDIT_ROOT, help="Root used with --audit-id.")
    parser.add_argument("--audit-path", help="Explicit offline audit folder.")
    parser.add_argument("--matches-path", help="Explicit offline pattern_matches.tsv path.")
    parser.add_argument(
        "--tester-audit-path",
        help="Strategy Tester Common Files pattern audit folder containing pattern_tester_observations.tsv.",
    )
    parser.add_argument("--observations-path", help="Explicit pattern_tester_observations.tsv path.")
    parser.add_argument("--output-dir", help="Output folder for parity reports.")
    parser.add_argument(
        "--include-unselected",
        action="store_true",
        help="Compare all pattern_matches.tsv rows instead of selected_for_visual rows only.",
    )
    parser.add_argument(
        "--require-signal-id-match",
        action="store_true",
        help="Treat signal_id mismatches as parity failures. Disabled by default because signal_id includes run_id.",
    )
    parser.add_argument(
        "--allow-missing-observations",
        action="store_true",
        help="Write a RESEARCH_ONLY_WARN report instead of failing when tester observations are missing.",
    )
    parser.add_argument(
        "--max-mismatch-rows",
        type=int,
        default=1000,
        help="Maximum mismatch TSV rows to write. Use 0 for no limit.",
    )
    parser.add_argument("--max-report-examples", type=int, default=20)
    return parser


def is_true(value: str) -> bool:
    return value.strip().lower() in ("1", "true", "yes")


def normalize_entry_time(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    return text.replace(".", "-", 2)


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise PatternPlaybackCompareError(f"Missing TSV file: {path}")
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def validate_columns(rows: list[dict[str, str]], required_columns: tuple[str, ...], path: Path) -> None:
    if not rows:
        raise PatternPlaybackCompareError(f"No rows found in TSV file: {path}")
    missing = [column for column in required_columns if column not in rows[0]]
    if missing:
        raise PatternPlaybackCompareError(f"Missing columns in {path}: {', '.join(missing)}")


def resolve_audit_path(args: argparse.Namespace) -> Path | None:
    if args.audit_path:
        return Path(args.audit_path)
    if args.audit_id:
        return Path(args.audit_root) / args.audit_id
    return None


def infer_audit_id(args: argparse.Namespace, audit_path: Path | None, matches_path: Path) -> str:
    if args.audit_id:
        return args.audit_id
    if audit_path is not None:
        return audit_path.name
    return matches_path.parent.name


def resolve_matches_path(args: argparse.Namespace, audit_path: Path | None) -> Path:
    if args.matches_path:
        return Path(args.matches_path)
    if audit_path is None:
        raise PatternPlaybackCompareError("Provide --audit-id, --audit-path, or --matches-path")
    return audit_path / PATTERN_MATCHES_FILE


def resolve_observations_path(args: argparse.Namespace, audit_id: str, audit_path: Path | None) -> Path:
    if args.observations_path:
        return Path(args.observations_path)
    if args.tester_audit_path:
        return Path(args.tester_audit_path) / PATTERN_OBSERVATIONS_FILE

    common_files = os.environ.get("MT5_COMMON_FILES", "")
    if common_files:
        return Path(common_files) / COMMON_PATTERN_ROOT / audit_id / PATTERN_OBSERVATIONS_FILE

    if audit_path is not None:
        return audit_path / PATTERN_OBSERVATIONS_FILE
    return Path(PATTERN_OBSERVATIONS_FILE)


def resolve_output_dir(args: argparse.Namespace, audit_path: Path | None, matches_path: Path) -> Path:
    if args.output_dir:
        return Path(args.output_dir)
    if audit_path is not None:
        return audit_path / "playback_parity"
    return matches_path.parent / "playback_parity"


def load_expected_matches(path: Path, *, include_unselected: bool) -> list[PatternPlaybackRow]:
    rows = read_tsv(path)
    validate_columns(rows, MATCH_REQUIRED_COLUMNS, path)

    matches: list[PatternPlaybackRow] = []
    for row in rows:
        if not include_unselected and not is_true(row.get("selected_for_visual", "")):
            continue
        source_key = row.get("source_key", "")
        pattern_id = row.get("pattern_id", "")
        if not source_key or not pattern_id:
            continue
        matches.append(
            PatternPlaybackRow(
                pattern_id=pattern_id,
                signal_id=row.get("signal_id", ""),
                source_key=source_key,
                source_attempt_index=row.get("source_attempt_index", ""),
                entry_time=normalize_entry_time(row.get("entry_time", "")),
                pattern_label=row.get("pattern_label", ""),
                conditions_text=row.get("conditions_text", ""),
            )
        )
    if not matches:
        raise PatternPlaybackCompareError(f"No expected pattern rows found in {path}")
    return matches


def load_observations(path: Path) -> list[PatternPlaybackRow]:
    rows = read_tsv(path)
    validate_columns(rows, OBSERVATION_REQUIRED_COLUMNS, path)

    observations: list[PatternPlaybackRow] = []
    for row in rows:
        source_key = row.get("source_key", "")
        pattern_id = row.get("pattern_id", "")
        if not source_key or not pattern_id:
            continue
        legacy_signal_id = row.get("signal_id", "")
        legacy_entry_time = row.get("entry_time", "")
        expected_signal_id = row.get("expected_signal_id", legacy_signal_id)
        observed_signal_id = row.get("observed_signal_id", legacy_signal_id)
        expected_entry_time = row.get("expected_entry_time", legacy_entry_time)
        observed_entry_time = row.get("observed_entry_time", legacy_entry_time)
        observations.append(
            PatternPlaybackRow(
                pattern_id=pattern_id,
                signal_id=expected_signal_id,
                source_key=source_key,
                source_attempt_index=row.get("source_attempt_index", ""),
                entry_time=normalize_entry_time(expected_entry_time),
                pattern_label=row.get("pattern_label", ""),
                conditions_text=row.get("conditions_text", ""),
                expected_match=row.get("expected_match", ""),
                observation_status=row.get("observation_status", ""),
                runtime_signal_id=observed_signal_id,
                runtime_entry_time=normalize_entry_time(observed_entry_time),
            )
        )
    return observations


def index_rows(rows: list[PatternPlaybackRow]) -> tuple[dict[tuple[str, str, str], PatternPlaybackRow], list[PatternPlaybackRow]]:
    indexed: dict[tuple[str, str, str], PatternPlaybackRow] = {}
    duplicates: list[PatternPlaybackRow] = []
    for row in rows:
        if row.key in indexed:
            duplicates.append(row)
            continue
        indexed[row.key] = row
    return indexed, duplicates


def index_entries(rows: list[PatternPlaybackRow]) -> dict[tuple[str, str], PatternPlaybackRow]:
    indexed: dict[tuple[str, str], PatternPlaybackRow] = {}
    for row in rows:
        indexed.setdefault(row.entry_key, row)
    return indexed


def entry_pattern_count_histogram(rows: list[PatternPlaybackRow]) -> dict[str, int]:
    entry_counts = Counter(row.entry_key for row in rows)
    histogram = Counter(entry_counts.values())
    return {str(key): histogram[key] for key in sorted(histogram)}


def unique_entries_by_direction(rows: list[PatternPlaybackRow]) -> dict[str, int]:
    entries = index_entries(rows)
    counts = Counter(row.direction for row in entries.values())
    return {key: counts[key] for key in sorted(counts)}


def entry_metrics(
    expected_rows: list[PatternPlaybackRow],
    observed_rows: list[PatternPlaybackRow],
) -> dict[str, Any]:
    expected_entries = index_entries(expected_rows)
    observed_entries = index_entries(observed_rows)

    expected_keys = set(expected_entries)
    observed_keys = set(observed_entries)
    matched_keys = expected_keys & observed_keys
    missing_keys = expected_keys - observed_keys
    extra_keys = observed_keys - expected_keys

    return {
        "unique_expected_trade_entries": len(expected_keys),
        "unique_observed_trade_entries": len(observed_keys),
        "unique_matched_trade_entries": len(matched_keys),
        "unique_missing_trade_entries": len(missing_keys),
        "unique_extra_trade_entries": len(extra_keys),
        "duplicate_expected_pattern_hits": len(expected_rows) - len(expected_keys),
        "duplicate_observed_pattern_hits": len(observed_rows) - len(observed_keys),
        "expected_entries_by_pattern_count": entry_pattern_count_histogram(expected_rows),
        "observed_entries_by_pattern_count": entry_pattern_count_histogram(observed_rows),
        "expected_unique_entries_by_direction": unique_entries_by_direction(expected_rows),
        "observed_unique_entries_by_direction": unique_entries_by_direction(observed_rows),
    }


def mismatch_row(
    mismatch_type: str,
    expected: PatternPlaybackRow | None,
    observed: PatternPlaybackRow | None,
) -> dict[str, str]:
    source = expected if expected is not None else observed
    assert source is not None
    return {
        "mismatch_type": mismatch_type,
        "pattern_id": source.pattern_id,
        "source_key": source.source_key,
        "source_attempt_index": source.source_attempt_index,
        "expected_signal_id": expected.signal_id if expected is not None else "",
        "observed_signal_id": observed.signal_id if observed is not None else "",
        "expected_entry_time": expected.entry_time if expected is not None else "",
        "observed_entry_time": observed.entry_time if observed is not None else "",
        "observed_runtime_signal_id": observed.runtime_signal_id if observed is not None else "",
        "observed_runtime_entry_time": observed.runtime_entry_time if observed is not None else "",
        "expected_status": expected.observation_status if expected is not None else "",
        "observed_status": observed.observation_status if observed is not None else "",
        "pattern_label": source.pattern_label,
        "conditions_text": source.conditions_text,
    }


def compare_rows(
    expected_rows: list[PatternPlaybackRow],
    observed_rows: list[PatternPlaybackRow],
    *,
    require_signal_id_match: bool,
) -> dict[str, Any]:
    expected_index, expected_duplicates = index_rows(expected_rows)
    observed_index, observed_duplicates = index_rows(observed_rows)

    expected_keys = set(expected_index)
    observed_keys = set(observed_index)
    matched_keys = sorted(expected_keys & observed_keys)
    missing_keys = sorted(expected_keys - observed_keys)
    extra_keys = sorted(observed_keys - expected_keys)

    mismatches: list[dict[str, str]] = []
    signal_id_mismatches = 0
    timestamp_mismatches = 0
    runtime_timestamp_mismatches = 0
    runtime_signal_id_nulls = 0
    status_mismatches = 0

    for row in expected_duplicates:
        mismatches.append(mismatch_row("duplicate_expected_key", row, None))
    for row in observed_duplicates:
        mismatches.append(mismatch_row("duplicate_observed_key", None, row))
    for key in missing_keys:
        mismatches.append(mismatch_row("missing_observation", expected_index[key], None))
    for key in extra_keys:
        mismatches.append(mismatch_row("extra_observation", None, observed_index[key]))

    for key in matched_keys:
        expected = expected_index[key]
        observed = observed_index[key]
        if expected.entry_time != observed.entry_time:
            timestamp_mismatches += 1
            mismatches.append(mismatch_row("entry_time_mismatch", expected, observed))
        if expected.signal_id != observed.signal_id:
            signal_id_mismatches += 1
            if require_signal_id_match:
                mismatches.append(mismatch_row("signal_id_mismatch", expected, observed))
        if observed.runtime_entry_time and expected.entry_time != observed.runtime_entry_time:
            runtime_timestamp_mismatches += 1
        if not observed.runtime_signal_id or observed.runtime_signal_id == r"\N":
            runtime_signal_id_nulls += 1
        if not is_true(observed.expected_match) or observed.observation_status != "OBSERVED":
            status_mismatches += 1
            mismatches.append(mismatch_row("observation_status_mismatch", expected, observed))

    hard_failure_count = (
        len(expected_duplicates)
        + len(observed_duplicates)
        + len(missing_keys)
        + len(extra_keys)
        + status_mismatches
    )
    if require_signal_id_match:
        hard_failure_count += signal_id_mismatches

    status = "PASS" if hard_failure_count == 0 else "FAIL"
    decision = "DATA_CLEAR_CONTINUE_TO_PATH_LABELS" if status == "PASS" else "DATA_AMBIGUITY_FIX_REQUIRED"

    report = {
        "status": status,
        "decision": decision,
        "expected_rows": len(expected_rows),
        "observed_rows": len(observed_rows),
        "matched_rows": len(matched_keys),
        "missing_rows": len(missing_keys),
        "extra_rows": len(extra_keys),
        "entry_time_mismatch_rows": timestamp_mismatches,
        "signal_id_mismatch_rows": signal_id_mismatches,
        "signal_id_match_required": require_signal_id_match,
        "runtime_entry_time_mismatch_rows": runtime_timestamp_mismatches,
        "runtime_signal_id_null_rows": runtime_signal_id_nulls,
        "observation_status_mismatch_rows": status_mismatches,
        "duplicate_expected_key_rows": len(expected_duplicates),
        "duplicate_observed_key_rows": len(observed_duplicates),
        "mismatches": mismatches,
    }
    report.update(entry_metrics(expected_rows, observed_rows))
    return report


def build_pending_report(
    audit_id: str,
    matches_path: Path,
    observations_path: Path,
    expected_rows: list[PatternPlaybackRow],
) -> dict[str, Any]:
    report = {
        "status": "PENDING",
        "decision": "RESEARCH_ONLY_WARN",
        "audit_id": audit_id,
        "matches_path": str(matches_path),
        "observations_path": str(observations_path),
        "expected_rows": len(expected_rows),
        "observed_rows": 0,
        "matched_rows": 0,
        "missing_rows": len(expected_rows),
        "extra_rows": 0,
        "entry_time_mismatch_rows": 0,
        "signal_id_mismatch_rows": 0,
        "signal_id_match_required": False,
        "runtime_entry_time_mismatch_rows": 0,
        "runtime_signal_id_null_rows": 0,
        "observation_status_mismatch_rows": 0,
        "duplicate_expected_key_rows": 0,
        "duplicate_observed_key_rows": 0,
        "mismatches": [],
        "warning": "Strategy Tester observations file is missing.",
    }
    report.update(entry_metrics(expected_rows, []))
    return report


def write_mismatch_tsv(output_dir: Path, mismatches: list[dict[str, str]], max_rows: int) -> int:
    output_path = output_dir / PARITY_MISMATCHES_FILE
    selected = mismatches if max_rows == 0 else mismatches[:max_rows]
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MISMATCH_COLUMNS, delimiter="\t")
        writer.writeheader()
        writer.writerows(selected)
    return len(selected)


def write_json_report(output_dir: Path, report: dict[str, Any]) -> None:
    serializable = {key: value for key, value in report.items() if key != "mismatches"}
    serializable["mismatch_rows_written"] = report.get("mismatch_rows_written", 0)
    (output_dir / PARITY_JSON_FILE).write_text(
        json.dumps(serializable, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def write_markdown_report(output_dir: Path, report: dict[str, Any], max_examples: int) -> None:
    lines = [
        "# Pattern Playback Parity",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Audit ID: `{report['audit_id']}`",
        f"- Status: `{report['status']}`",
        f"- Decision: `{report['decision']}`",
        f"- Matches path: `{report['matches_path']}`",
        f"- Observations path: `{report['observations_path']}`",
        "",
        "## Counts",
        "",
        "Pattern rows are selected-pattern observations. Unique trade entries",
        "are MT5-admissible source entries keyed by",
        "`source_key + source_attempt_index`.",
        "",
        "### Pattern Row Parity",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
    ]
    pattern_count_fields = (
        "expected_rows",
        "observed_rows",
        "matched_rows",
        "missing_rows",
        "extra_rows",
        "entry_time_mismatch_rows",
        "signal_id_mismatch_rows",
        "runtime_entry_time_mismatch_rows",
        "runtime_signal_id_null_rows",
        "observation_status_mismatch_rows",
        "duplicate_expected_key_rows",
        "duplicate_observed_key_rows",
        "mismatch_rows_written",
    )
    for field in pattern_count_fields:
        lines.append(f"| `{field}` | {report.get(field, 0)} |")

    lines.extend(
        [
            "",
            "### Unique Trade Entries",
            "",
            "| Metric | Value |",
            "| --- | ---: |",
        ]
    )
    entry_count_fields = (
        "unique_expected_trade_entries",
        "unique_observed_trade_entries",
        "unique_matched_trade_entries",
        "unique_missing_trade_entries",
        "unique_extra_trade_entries",
        "duplicate_expected_pattern_hits",
        "duplicate_observed_pattern_hits",
    )
    for field in entry_count_fields:
        lines.append(f"| `{field}` | {report.get(field, 0)} |")

    lines.extend(
        [
            "",
            "### Entry Pattern Count Histogram",
            "",
            "| Patterns per entry | Expected entries | Observed entries |",
            "| ---: | ---: | ---: |",
        ]
    )
    expected_hist = report.get("expected_entries_by_pattern_count", {})
    observed_hist = report.get("observed_entries_by_pattern_count", {})
    histogram_keys = sorted(set(expected_hist) | set(observed_hist), key=int)
    for key in histogram_keys:
        lines.append(f"| {key} | {expected_hist.get(key, 0)} | {observed_hist.get(key, 0)} |")

    lines.extend(
        [
            "",
            "### Unique Entries By Direction",
            "",
            "| Direction | Expected entries | Observed entries |",
            "| --- | ---: | ---: |",
        ]
    )
    expected_direction = report.get("expected_unique_entries_by_direction", {})
    observed_direction = report.get("observed_unique_entries_by_direction", {})
    direction_keys = sorted(set(expected_direction) | set(observed_direction))
    for key in direction_keys:
        lines.append(f"| `{key}` | {expected_direction.get(key, 0)} | {observed_direction.get(key, 0)} |")

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- Hard pattern parity uses `pattern_id + source_key + source_attempt_index`.",
            "- MT5 trade totals should be compared with `unique_observed_trade_entries`,",
            "  not with selected pattern observation rows.",
            "- Multiple selected patterns can match one trade entry; those extra",
            "  pattern hits are counted as duplicate pattern hits, not extra trades.",
            "- `signal_id` can include a stats run ID, and may be `\\N` when feature",
            "  export is disabled. It is diagnostic unless `--require-signal-id-match` is used.",
            "- Entry-time fields are metadata diagnostics when hard identity matches.",
            "- Runtime FILTER approval is not part of this report.",
        ]
    )
    if report.get("warning"):
        lines.extend(["", f"Warning: {report['warning']}"])

    mismatches = report.get("mismatches", [])
    if mismatches:
        lines.extend(["", "## Mismatch Examples", ""])
        for row in mismatches[:max_examples]:
            lines.append(
                "- "
                f"{row['mismatch_type']} | {row['pattern_id']} | "
                f"{row['source_key']} | attempt={row['source_attempt_index']}"
            )

    (output_dir / PARITY_REPORT_FILE).write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_reports(output_dir: Path, report: dict[str, Any], *, max_mismatch_rows: int, max_examples: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    report["mismatch_rows_written"] = write_mismatch_tsv(
        output_dir,
        report.get("mismatches", []),
        max_mismatch_rows,
    )
    write_json_report(output_dir, report)
    write_markdown_report(output_dir, report, max_examples)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        audit_path = resolve_audit_path(args)
        matches_path = resolve_matches_path(args, audit_path)
        audit_id = infer_audit_id(args, audit_path, matches_path)
        observations_path = resolve_observations_path(args, audit_id, audit_path)
        output_dir = resolve_output_dir(args, audit_path, matches_path)

        expected_rows = load_expected_matches(matches_path, include_unselected=args.include_unselected)
        if observations_path.exists():
            observed_rows = load_observations(observations_path)
            report = compare_rows(
                expected_rows,
                observed_rows,
                require_signal_id_match=args.require_signal_id_match,
            )
        elif args.allow_missing_observations:
            report = build_pending_report(audit_id, matches_path, observations_path, expected_rows)
        else:
            raise PatternPlaybackCompareError(f"Missing tester observations: {observations_path}")

        report.update(
            {
                "audit_id": audit_id,
                "matches_path": str(matches_path),
                "observations_path": str(observations_path),
                "generated_at": datetime.now(UTC).isoformat(),
                "output_dir": str(output_dir),
            }
        )
        write_reports(
            output_dir,
            report,
            max_mismatch_rows=args.max_mismatch_rows,
            max_examples=args.max_report_examples,
        )
    except PatternPlaybackCompareError as exc:
        parser.exit(1, f"pattern playback comparison failed: {exc}\n")

    print(
        "pattern playback comparison "
        f"{report['status']} | decision={report['decision']} | "
        f"expected={report['expected_rows']} | observed={report['observed_rows']} | "
        f"matched={report['matched_rows']} | missing={report['missing_rows']} | "
        f"extra={report['extra_rows']} | unique_trades={report['unique_observed_trade_entries']} | "
        f"duplicate_pattern_hits={report['duplicate_observed_pattern_hits']} | "
        f"entry_time_mismatches={report['entry_time_mismatch_rows']} | "
        f"signal_id_mismatches={report['signal_id_mismatch_rows']} | output={output_dir}"
    )
    return 0 if report["status"] in ("PASS", "PENDING") else 1


if __name__ == "__main__":
    raise SystemExit(main())
