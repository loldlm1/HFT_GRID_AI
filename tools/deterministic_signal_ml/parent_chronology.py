"""Bounded V14 parent chronology audit and provenance-preserving censor repair.

This is a focused operational gate, not a replacement for the full semantic
validator. It never modifies its source run or reclassifies a censored outcome.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
from pathlib import Path

import duckdb

from schema_contract import (
    COLUMN_TYPE_BY_NAME, NULL_TOKEN, RUN_FILES, TABLE_COLUMNS,
    SchemaValidationError, _read_tsv, _resolve_run_path, _validate_manifest,
)

COMMON = ("schema_version", "run_id", "config_id")
PROJECTIONS = {
    "virtual_trials": "trial_id origin_id broker_signal_id trial_role entry_policy tp_r_multiple direction entry_broker_time eligibility_status",
    "virtual_outcomes": "outcome_id trial_id terminal_broker_time terminal_status",
    "deep_pivot_events": "deep_event_id symbol deep_timeframe micro_timeframe direction trigger_broker_time admission_status active_parent_count",
    "deep_pivot_parent_links": "parent_link_id deep_event_id origin_id parent_kind parent_trial_id parent_broker_signal_id parent_entry_policy parent_tp_r_multiple parent_direction deep_direction direction_relationship parent_entry_broker_time event_trigger_broker_time m10_parent_age_seconds",
    "deep_virtual_trials": "deep_trial_id deep_event_id tp_r_multiple direction eligibility_status",
    "deep_virtual_outcomes": "deep_outcome_id parent_link_id deep_trial_id deep_event_id origin_id tp_r_multiple direction parent_direction terminal_broker_time terminal_analysis_time terminal_offset_minutes terminal_status terminal_reason deep_lifecycle_seconds virtual_binary_eligible virtual_binary_target threshold_price gap_points virtual_nominal_r virtual_quote_gross_profit virtual_quote_gross_r virtual_exclusion_reason observed_exit_bid observed_exit_ask observed_exit_price exit_quote_side first_touch_consistent",
    "broker_outcomes": "broker_outcome_id origin_id broker_signal_id entry_broker_time close_broker_time close_analysis_time close_offset_minutes broker_entry_confirmed broker_close_confirmed",
    "execution_checks": "check_id origin_id broker_signal_id broker_time broker_entry_confirmed broker_close_confirmed",
}
COUNT_KEYS = dict(zip(PROJECTIONS, (
    "h1_trial_rows", "h1_outcome_rows", "deep_event_rows", "deep_parent_link_rows",
    "deep_trial_rows", "deep_outcome_rows", "broker_outcome_rows", "execution_check_rows",
)))
PRIMARY_KEYS = dict(zip(PROJECTIONS, (
    "trial_id", "outcome_id", "deep_event_id", "parent_link_id", "deep_trial_id",
    "deep_outcome_id", "broker_outcome_id", "check_id",
)))
REQUIRED_IDENTITIES = {
    "virtual_trials": "origin_id trial_role entry_policy tp_r_multiple direction eligibility_status",
    "virtual_outcomes": "trial_id terminal_broker_time terminal_status",
    "deep_pivot_events": "symbol deep_timeframe micro_timeframe direction trigger_broker_time admission_status active_parent_count",
    "deep_pivot_parent_links": "deep_event_id origin_id parent_kind parent_trial_id parent_entry_policy parent_tp_r_multiple parent_direction deep_direction direction_relationship parent_entry_broker_time event_trigger_broker_time m10_parent_age_seconds",
    "deep_virtual_trials": "deep_event_id tp_r_multiple direction eligibility_status",
    "deep_virtual_outcomes": "parent_link_id deep_trial_id deep_event_id origin_id tp_r_multiple direction parent_direction terminal_status virtual_binary_eligible",
    "broker_outcomes": "origin_id broker_signal_id entry_broker_time close_broker_time broker_entry_confirmed broker_close_confirmed",
}
REPAIRABLE_CHECK = "broker_parent_censor_after_close"
MAX_REPAIR_ROWS = 100_000


def _literal(value: str | Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _snapshot(run: Path) -> dict:
    return {name: {"bytes": (run / name).stat().st_size,
                   "mtime_ns": (run / name).stat().st_mtime_ns}
            for name in RUN_FILES}


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def _inspect(run: Path) -> tuple[dict, dict]:
    for name in RUN_FILES:
        with (run / name).open(encoding="utf-8", newline="") as handle:
            if tuple(handle.readline().rstrip("\r\n").split("\t")) != TABLE_COLUMNS[name]:
                raise SchemaValidationError(f"Header mismatch: {name}")
    manifest = _validate_manifest(_read_tsv(run / "run_manifest.tsv", TABLE_COLUMNS["run_manifest.tsv"]), run.name)
    summaries = _read_tsv(run / "run_summary.tsv", TABLE_COLUMNS["run_summary.tsv"])
    if len(summaries) != 1:
        raise SchemaValidationError("Expected one sealed run summary")
    summary = summaries[0]
    if (summary["run_id"] != run.name or summary["config_id"] != manifest["config_id"]
            or summary["schema_version"] != "14" or summary["export_status"] != "OK"
            or summary["completion_status"] not in ("NATURAL", "CENSORED")):
        raise SchemaValidationError("Run summary is not a compatible successful export seal")
    for key in ("duplicate_identity_count", "referential_integrity_error_count", "row_integrity_error_count"):
        if summary[key] != "0":
            raise SchemaValidationError(f"Producer integrity failure: {key}")
    return manifest, summary


def _load(db: duckdb.DuckDBPyConnection, run: Path) -> None:
    for table, selected in PROJECTIONS.items():
        columns = (*COMMON, *selected.split())
        types = "{" + ",".join(f"{_literal(c)}:'VARCHAR'" for c in TABLE_COLUMNS[table + ".tsv"]) + "}"
        expressions = []
        for column in columns:
            dtype = COLUMN_TYPE_BY_NAME[column]
            if dtype == "TIMESTAMP":
                expression = f"strptime({column}, '%Y.%m.%d %H:%M:%S')"
            elif dtype in ("BIGINT", "DOUBLE"):
                expression = f"CAST({column} AS {dtype})"
            else:
                expression = column
            expressions.append(f"{expression} AS {column}")
        db.execute(f"""CREATE TABLE {table} AS SELECT {','.join(expressions)}
          FROM read_csv({_literal(run / (table + '.tsv'))}, delim='\t', header=true,
          columns={types}, auto_detect=false, nullstr={_literal(NULL_TOKEN)},
          strict_mode=true, null_padding=false, quote='', escape='')""")


def _audit(db: duckdb.DuckDBPyConnection, run: Path, manifest: dict, summary: dict) -> dict:
    report = {"run_id": run.name, "config_id": manifest["config_id"],
              "scope": "Parent chronology and required relationship/label checks; full semantic validation remains separate",
              "checks": {}, "row_counts": {}, "repairable_rows": 0}

    def check(label: str, query: str) -> None:
        report["checks"][label] = int(db.execute(query).fetchone()[0])

    for table in PROJECTIONS:
        count = int(db.execute(f"SELECT count(*) FROM {table}").fetchone()[0])
        report["row_counts"][table] = count
        report["checks"][table + ".summary_count"] = int(count != int(summary[COUNT_KEYS[table]]))
        check(table + ".run_identity", f"SELECT count(*) FROM {table} WHERE schema_version IS DISTINCT FROM 14 OR run_id IS DISTINCT FROM {_literal(run.name)} OR config_id IS DISTINCT FROM {_literal(manifest['config_id'])}")
        key = PRIMARY_KEYS[table]
        check(table + ".primary_key", f"SELECT count(*) - count(DISTINCT {key}) FROM {table}")
        if table in REQUIRED_IDENTITIES:
            missing = " OR ".join(f"{column} IS NULL" for column in REQUIRED_IDENTITIES[table].split())
            check(table + ".required_identity", f"SELECT count(*) FROM {table} WHERE {missing}")
    check("one_outcome_per_h1_trial", "SELECT count(*)-count(DISTINCT trial_id) FROM virtual_outcomes")
    check("one_close_per_broker_parent", "SELECT count(*)-count(DISTINCT broker_signal_id) FROM broker_outcomes")
    if any(report["checks"].values()):
        report["status"] = "FAIL"
        report["relationship_checks_skipped"] = "Invalid counts or primary identities make joins unsafe"
        return report

    db.execute("""CREATE TABLE fills AS SELECT origin_id,broker_signal_id,
      min(broker_time) FILTER (WHERE broker_entry_confirmed='1') first_fill_observed,
      max(broker_close_confirmed='1') close_confirmed
      FROM execution_checks GROUP BY origin_id,broker_signal_id""")
    db.execute("""CREATE TABLE parents AS SELECT l.*,
      t.trial_id referenced_trial, t.origin_id trial_origin, t.direction trial_direction,
      t.broker_signal_id trial_broker_signal, t.trial_role, t.entry_policy,
      t.tp_r_multiple, t.entry_broker_time trial_entry, t.eligibility_status,
      e.deep_event_id referenced_event, e.direction event_direction,
      e.trigger_broker_time trigger_time, e.admission_status,
      b.broker_signal_id referenced_broker, b.origin_id broker_origin,
      b.entry_broker_time broker_entry, b.broker_entry_confirmed, b.broker_close_confirmed,
      f.first_fill_observed, f.close_confirmed,
      CASE WHEN l.parent_kind='VIRTUAL' THEN h.terminal_broker_time
           ELSE b.close_broker_time END parent_terminal,
      CASE WHEN l.parent_kind='VIRTUAL' THEN h.terminal_status IN ('TP_FIRST','SL_FIRST')
           ELSE b.close_broker_time IS NOT NULL END parent_completed,
      b.close_analysis_time,b.close_offset_minutes
      FROM deep_pivot_parent_links l
      LEFT JOIN virtual_trials t ON l.parent_trial_id=t.trial_id
      LEFT JOIN virtual_outcomes h ON l.parent_trial_id=h.trial_id
      LEFT JOIN deep_pivot_events e ON l.deep_event_id=e.deep_event_id
      LEFT JOIN broker_outcomes b ON l.parent_broker_signal_id=b.broker_signal_id
      LEFT JOIN fills f ON l.origin_id=f.origin_id AND l.parent_broker_signal_id=f.broker_signal_id""")
    checks = {
        "parent_identity": """SELECT count(*) FROM parents WHERE referenced_trial IS NULL OR referenced_event IS NULL
          OR parent_kind IS NULL OR parent_kind NOT IN ('VIRTUAL','BROKER')
          OR origin_id IS DISTINCT FROM trial_origin OR parent_direction IS DISTINCT FROM trial_direction
          OR deep_direction IS DISTINCT FROM event_direction OR parent_entry_policy IS DISTINCT FROM entry_policy
          OR parent_tp_r_multiple IS DISTINCT FROM tp_r_multiple
          OR parent_broker_signal_id IS DISTINCT FROM trial_broker_signal OR admission_status IS DISTINCT FROM 'ADMITTED'
          OR parent_direction NOT IN ('BUY','SELL') OR deep_direction NOT IN ('BUY','SELL')
          OR direction_relationship IS DISTINCT FROM CASE WHEN parent_direction=deep_direction THEN 'ALIGNED' ELSE 'OPPOSED' END
          OR (parent_kind='VIRTUAL' AND (trial_role IS DISTINCT FROM 'H1' OR eligibility_status IS DISTINCT FROM 'ACTIVE' OR parent_terminal IS NULL
              OR parent_entry_broker_time IS DISTINCT FROM trial_entry))
          OR (parent_kind='BROKER' AND (trial_role IS DISTINCT FROM 'BROKER_PARITY' OR parent_entry_policy IS DISTINCT FROM 'STRUCTURAL' OR parent_tp_r_multiple IS DISTINCT FROM 1))""",
        "broker_lifecycle": "SELECT count(*) FROM broker_outcomes WHERE close_broker_time<entry_broker_time OR broker_entry_confirmed IS DISTINCT FROM '1' OR broker_close_confirmed IS DISTINCT FROM '1'",
        "broker_parent_evidence": """SELECT count(*) FROM parents WHERE parent_kind='BROKER' AND
          ((referenced_broker IS NOT NULL AND (parent_entry_broker_time IS DISTINCT FROM broker_entry
            OR origin_id IS DISTINCT FROM broker_origin OR broker_entry_confirmed IS DISTINCT FROM '1'
            OR broker_close_confirmed IS DISTINCT FROM '1'))
          OR (referenced_broker IS NULL AND (first_fill_observed IS NULL OR first_fill_observed>event_trigger_broker_time OR close_confirmed)))""",
        "parent_admission_interval": """SELECT count(*) FROM parents WHERE parent_entry_broker_time IS NULL
          OR event_trigger_broker_time IS NULL OR event_trigger_broker_time IS DISTINCT FROM trigger_time
          OR parent_entry_broker_time>event_trigger_broker_time OR event_trigger_broker_time>parent_terminal
          OR m10_parent_age_seconds IS DISTINCT FROM date_diff('second',parent_entry_broker_time,event_trigger_broker_time)""",
        "event_profile": f"SELECT count(*) FROM deep_pivot_events WHERE symbol IS DISTINCT FROM {_literal(manifest['symbol'])} OR deep_timeframe IS DISTINCT FROM {_literal(manifest['deep_timeframe'])} OR micro_timeframe IS DISTINCT FROM {_literal(manifest['micro_timeframe'])}",
        "event_parent_count": "SELECT count(*) FROM deep_pivot_events e LEFT JOIN (SELECT deep_event_id,count(*) n FROM parents GROUP BY deep_event_id) p USING(deep_event_id) WHERE (admission_status='ADMITTED' AND active_parent_count IS DISTINCT FROM n) OR (admission_status='CAPACITY_REJECTED' AND coalesce(n,0)<>0)",
        "outcome_identity": """SELECT count(*) FROM deep_virtual_outcomes d LEFT JOIN parents p USING(parent_link_id)
          LEFT JOIN deep_virtual_trials t USING(deep_trial_id) WHERE p.parent_link_id IS NULL OR t.deep_trial_id IS NULL
          OR d.deep_event_id IS DISTINCT FROM p.deep_event_id OR d.deep_event_id IS DISTINCT FROM t.deep_event_id
          OR d.origin_id IS DISTINCT FROM p.origin_id OR d.direction IS DISTINCT FROM p.deep_direction OR d.parent_direction IS DISTINCT FROM p.parent_direction
          OR d.direction IS DISTINCT FROM t.direction OR d.tp_r_multiple IS DISTINCT FROM t.tp_r_multiple""",
        "outcome_unique_link_trial": "SELECT count(*)-count(DISTINCT (parent_link_id,deep_trial_id)) FROM deep_virtual_outcomes",
        "three_outcomes_per_link": "SELECT count(*) FROM parents p LEFT JOIN (SELECT parent_link_id,count(*) n,count(DISTINCT tp_r_multiple) ratios,min(tp_r_multiple) lo,max(tp_r_multiple) hi FROM deep_virtual_outcomes GROUP BY parent_link_id) d USING(parent_link_id) WHERE n IS DISTINCT FROM 3 OR ratios IS DISTINCT FROM 3 OR lo IS DISTINCT FROM 1 OR hi IS DISTINCT FROM 3",
        "completed_after_parent": "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status IN ('TP_FIRST','SL_FIRST') AND d.terminal_broker_time>p.parent_terminal",
        "run_censored_closed_parent": "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status='CENSORED_RUN_END' AND p.parent_completed",
        "censor_parent_missing": "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status='CENSORED_PARENT_EXIT' AND p.parent_terminal IS NULL",
        "censor_before_parent": "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status='CENSORED_PARENT_EXIT' AND d.terminal_broker_time<p.parent_terminal",
        "virtual_parent_censor_after_close": "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status='CENSORED_PARENT_EXIT' AND p.parent_kind='VIRTUAL' AND d.terminal_broker_time>p.parent_terminal",
        REPAIRABLE_CHECK: "SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id) WHERE d.terminal_status='CENSORED_PARENT_EXIT' AND p.parent_kind='BROKER' AND d.terminal_broker_time>p.parent_terminal",
        "outcome_terminal_interval": """SELECT count(*) FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id)
          WHERE d.terminal_broker_time IS NULL OR d.terminal_broker_time<p.event_trigger_broker_time
          OR (d.terminal_broker_time=p.event_trigger_broker_time AND d.terminal_status<>'CENSORED_PARENT_EXIT')
          OR (d.terminal_status IN ('TP_FIRST','SL_FIRST') AND d.deep_lifecycle_seconds IS DISTINCT FROM date_diff('second',p.event_trigger_broker_time,d.terminal_broker_time))""",
        "binary_labels": """SELECT count(*) FROM deep_virtual_outcomes WHERE terminal_status IS NULL
          OR terminal_status NOT IN ('TP_FIRST','SL_FIRST','CENSORED_PARENT_EXIT','CENSORED_RUN_END','INELIGIBLE')
          OR virtual_binary_eligible IS DISTINCT FROM CASE WHEN terminal_status IN ('TP_FIRST','SL_FIRST') THEN '1' ELSE '0' END
          OR virtual_binary_target IS DISTINCT FROM CASE WHEN terminal_status='TP_FIRST' THEN 1 WHEN terminal_status='SL_FIRST' THEN 0 ELSE NULL END
          OR (terminal_status NOT IN ('TP_FIRST','SL_FIRST') AND (deep_lifecycle_seconds IS NOT NULL
            OR threshold_price IS NOT NULL OR gap_points IS NOT NULL OR virtual_nominal_r IS NOT NULL
            OR virtual_quote_gross_profit IS NOT NULL OR virtual_quote_gross_r IS NOT NULL OR virtual_exclusion_reason IS NULL))""",
        "censor_observation": """SELECT count(*) FROM deep_virtual_outcomes WHERE terminal_status='CENSORED_PARENT_EXIT'
          AND (terminal_reason IS DISTINCT FROM 'CENSORED_PARENT_EXIT' OR first_touch_consistent IS DISTINCT FROM '1'
            OR observed_exit_bid IS NULL OR observed_exit_ask IS NULL OR observed_exit_price IS NULL
            OR NOT isfinite(observed_exit_bid) OR NOT isfinite(observed_exit_ask) OR NOT isfinite(observed_exit_price)
            OR observed_exit_bid<=0 OR observed_exit_ask<observed_exit_bid
            OR observed_exit_price IS DISTINCT FROM CASE WHEN direction='BUY' THEN observed_exit_bid ELSE observed_exit_ask END
            OR exit_quote_side IS DISTINCT FROM CASE WHEN direction='BUY' THEN 'BID' ELSE 'ASK' END)""",
    }
    for label, query in checks.items():
        check(label, query)
    for table, prefix in (("deep_virtual_outcomes", "terminal"), ("broker_outcomes", "close")):
        check(table + ".time_triplet", f"SELECT count(*) FROM {table} WHERE {prefix}_broker_time IS NULL OR {prefix}_analysis_time IS NULL OR {prefix}_offset_minutes IS NULL OR {prefix}_analysis_time IS DISTINCT FROM {prefix}_broker_time+{prefix}_offset_minutes*INTERVAL '1 minute'")
    report["repairable_rows"] = report["checks"][REPAIRABLE_CHECK]
    report["status"] = "FAIL" if any(report["checks"].values()) else "PASS"
    return report


def audit_run(runs_root: Path, run_id: str, *, memory_limit_mb: int = 2048,
              include_repair_candidates: bool = False) -> dict:
    if memory_limit_mb < 128:
        raise ValueError("memory_limit_mb must be at least 128")
    run = _resolve_run_path(runs_root, run_id)
    before = _snapshot(run)
    manifest, summary = _inspect(run)
    with tempfile.TemporaryDirectory(prefix="v14-parent-audit-") as temporary:
        db = duckdb.connect(config={"memory_limit": f"{memory_limit_mb}MB", "threads": "4",
                                    "temp_directory": temporary, "preserve_insertion_order": "false"})
        try:
            _load(db, run)
            report = _audit(db, run, manifest, summary)
            if include_repair_candidates and 0 < report["repairable_rows"] <= MAX_REPAIR_ROWS:
                result = db.execute("""SELECT d.deep_outcome_id,d.parent_link_id,p.parent_broker_signal_id,
                  d.terminal_broker_time,d.terminal_analysis_time,d.terminal_offset_minutes,
                  p.parent_terminal,p.close_analysis_time,p.close_offset_minutes
                  FROM deep_virtual_outcomes d JOIN parents p USING(parent_link_id)
                  WHERE d.terminal_status='CENSORED_PARENT_EXIT' AND p.parent_kind='BROKER'
                    AND d.terminal_broker_time>p.parent_terminal ORDER BY d.deep_outcome_id""").fetchall()
                report["repair_candidates"] = {
                    row[0]: {"parent_link_id": row[1], "broker_signal_id": row[2],
                             "before": [row[3].strftime("%Y.%m.%d %H:%M:%S"), row[4].strftime("%Y.%m.%d %H:%M:%S"), str(row[5])],
                             "after": [row[6].strftime("%Y.%m.%d %H:%M:%S"), row[7].strftime("%Y.%m.%d %H:%M:%S"), str(row[8])]}
                    for row in result}
        finally:
            db.close()
    if before != _snapshot(run):
        raise SchemaValidationError("Source run changed during audit")
    report["source_snapshot"] = before
    report["sources_unchanged"] = True
    report["memory_limit_mb"] = memory_limit_mb
    return report


def recover_run(runs_root: Path, run_id: str, recovered_runs_root: Path,
                recovered_run_id: str, *, memory_limit_mb: int = 2048) -> dict:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,95}", recovered_run_id) or recovered_run_id == run_id:
        raise ValueError("Recovery requires a distinct, safe run ID")
    source = _resolve_run_path(runs_root, run_id)
    recovered_runs_root = recovered_runs_root.resolve()
    target = recovered_runs_root / recovered_run_id
    if recovered_runs_root == source or source in recovered_runs_root.parents:
        raise ValueError("Recovery output must be outside the original run")
    correction_path = recovered_runs_root / (recovered_run_id + ".corrections.jsonl")
    provenance_path = recovered_runs_root / (recovered_run_id + ".provenance.json")
    if any(path.exists() or path.is_symlink() for path in (target, correction_path, provenance_path)):
        raise FileExistsError("Recovery destination or provenance already exists; nothing overwritten")
    manifest, summary = _inspect(source)
    if summary["completion_status"] != "NATURAL":
        raise SchemaValidationError("Automatic recovery requires a naturally completed source run")
    before = audit_run(runs_root, run_id, memory_limit_mb=memory_limit_mb, include_repair_candidates=True)
    failures = {name for name, count in before["checks"].items() if count}
    if failures != {REPAIRABLE_CHECK} or not 0 < before["repairable_rows"] <= MAX_REPAIR_ROWS:
        raise SchemaValidationError("Run is not eligible for timestamp-only recovery: " + ", ".join(sorted(failures or {"no corrections"})))
    candidates = before.pop("repair_candidates")
    recovered_runs_root.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".parent-clock-recovery-", dir=recovered_runs_root))
    work = staging / recovered_run_id
    work.mkdir()
    published = False
    correction_created = False
    provenance_created = False
    hashes = {}
    corrected = set()
    old_id, new_id = run_id.encode("utf-8"), recovered_run_id.encode("utf-8")
    clock_columns = ("terminal_broker_time", "terminal_analysis_time", "terminal_offset_minutes")
    try:
        with correction_path.open("x", encoding="utf-8") as corrections:
            correction_created = True
            for filename in RUN_FILES:
                source_hash, target_hash = hashlib.sha256(), hashlib.sha256()
                columns = TABLE_COLUMNS[filename]
                with (source / filename).open("rb") as reader, (work / filename).open("xb") as writer:
                    for index, line in enumerate(reader):
                        source_hash.update(line)
                        rewritten = line
                        if index and filename == "run_manifest.tsv":
                            parts = line.rstrip(b"\r\n").split(b"\t")
                            if parts[1] == b"run_id":
                                ending = line[len(line.rstrip(b"\r\n")):]
                                rewritten = b"\t".join((parts[0], parts[1], new_id)) + ending
                        elif index:
                            prefix = line.split(b"\t", 2)
                            if len(prefix) != 3 or prefix[0] != b"14" or prefix[1] != old_id:
                                raise SchemaValidationError(f"Unexpected source row identity: {filename}:{index + 1}")
                            rewritten = b"14\t" + new_id + b"\t" + prefix[2]
                            if filename == "deep_virtual_outcomes.tsv":
                                outcome_id = prefix[2].split(b"\t", 2)[1].decode("utf-8")
                                candidate = candidates.get(outcome_id)
                                if candidate is not None:
                                    parts = rewritten.rstrip(b"\r\n").split(b"\t")
                                    original_clock = [parts[columns.index(c)].decode("utf-8") for c in clock_columns]
                                    if original_clock != candidate["before"] or outcome_id in corrected:
                                        raise SchemaValidationError("Correction source changed or outcome identity repeated")
                                    evidence = {"deep_outcome_id": outcome_id, **candidate,
                                                "observation_clock": candidate["before"],
                                                "observation_clock_basis": "Original exported terminal tick; retained without reclassifying it as an observation at the corrected close",
                                                "preserved_quote": {c: parts[columns.index(c)].decode("utf-8")
                                                    for c in ("observed_exit_bid", "observed_exit_ask", "observed_exit_price", "exit_quote_side")}}
                                    for column, value in zip(clock_columns, candidate["after"]):
                                        parts[columns.index(column)] = value.encode("utf-8")
                                    ending = rewritten[len(rewritten.rstrip(b"\r\n")):]
                                    rewritten = b"\t".join(parts) + ending
                                    corrections.write(json.dumps(evidence, sort_keys=True) + "\n")
                                    corrected.add(outcome_id)
                        writer.write(rewritten)
                        target_hash.update(rewritten)
                hashes[filename] = {"source_sha256": source_hash.hexdigest(), "recovered_sha256": target_hash.hexdigest()}
        if len(corrected) != before["repairable_rows"] or before["source_snapshot"] != _snapshot(source):
            raise SchemaValidationError("Recovery did not consume every correction or the original run changed")
        after = audit_run(staging, recovered_run_id, memory_limit_mb=memory_limit_mb)
        if after["status"] != "PASS":
            raise SchemaValidationError("Recovered chronology failed validation; no run published")
        if target.exists() or target.is_symlink():
            raise FileExistsError("Recovery destination appeared during processing")
        result = {"status": "RECOVERED_PARENT_CHRONOLOGY", "source_run": str(source),
                  "recovered_run": str(target), "source_config_id": manifest["config_id"],
                  "corrected_rows": len(corrected), "source_unchanged": True,
                  "correction_file": str(correction_path), "hashes": hashes,
                  "allowed_changes": ["run_id labels identifying the derivative", "broker-parent censor terminal time triplets"],
                  "unchanged_facts": "Outcome statuses, binary eligibility/targets, durations, quotes, prices, IDs, features and row counts",
                  "provenance": "Deterministic derivative of the original export; not a new Strategy Tester run or an export from the corrected binary",
                  "full_semantic_validation": "NOT_RUN; parent chronology validation is scoped separately",
                  "audit_before": before, "audit_after": after,
                  "tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        staged_provenance = staging / "provenance.json"
        _write_json(staged_provenance, result)
        os.link(staged_provenance, provenance_path)
        provenance_created = True
        os.rename(work, target)
        published = True
        return result
    finally:
        shutil.rmtree(staging)
        if correction_created and not published:
            correction_path.unlink(missing_ok=True)
        if provenance_created and not published:
            provenance_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs-root", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--memory-limit-mb", type=int, default=2048)
    parser.add_argument("--recover-run-id")
    parser.add_argument("--recovered-runs-root", type=Path)
    args = parser.parse_args()
    try:
        source = _resolve_run_path(args.runs_root, args.run_id)
        report_path = args.report.resolve()
        if source == report_path or source in report_path.parents or report_path.exists():
            raise ValueError("Report must be a new file outside the source run")
        if bool(args.recover_run_id) != bool(args.recovered_runs_root):
            raise ValueError("Supply both --recover-run-id and --recovered-runs-root")
        if args.recover_run_id:
            target = (args.recovered_runs_root / args.recover_run_id).resolve()
            sidecars = {target.parent / (target.name + suffix) for suffix in (".provenance.json", ".corrections.jsonl")}
            if target == report_path or target in report_path.parents or report_path in sidecars:
                raise ValueError("Report must be outside the recovered run")
            report = recover_run(args.runs_root, args.run_id, args.recovered_runs_root,
                                 args.recover_run_id, memory_limit_mb=args.memory_limit_mb)
        else:
            report = audit_run(args.runs_root, args.run_id, memory_limit_mb=args.memory_limit_mb)
        _write_json(report_path, report)
        failures = {name: count for name, count in report.get("checks", {}).items() if count}
        print(json.dumps({"status": report["status"], "report": str(report_path), "failures": failures}))
        return 1 if report["status"] == "FAIL" else 0
    except (OSError, ValueError, RuntimeError, duckdb.Error) as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
