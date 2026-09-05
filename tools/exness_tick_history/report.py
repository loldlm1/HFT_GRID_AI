"""Integrity reports distinguish observed ticks from unproved market closures."""

from __future__ import annotations

import hashlib
from datetime import date, timedelta

from .config import Profile
from .storage import Store, StorageError, feed_identity, file_hash, identifier, object_hash, read_json


def quality_report(inventory: dict, sources: list[dict], missing: list[dict], parts: list[dict]) -> dict:
    fields = ("source_rows", "retained_rows", "outside_selection_rows", "quarantined_rows", "timestamp_regressions",
              "adjacent_equal_timestamp_rows", "zero_spread_rows", "wide_spread_rows", "large_jump_rows", "millisecond_zero_rows")
    totals = {field: sum(source[field] for source in sources) for field in fields}
    if totals["source_rows"] != totals["retained_rows"] + totals["outside_selection_rows"] + totals["quarantined_rows"]:
        raise StorageError("Source row conservation failed")
    present = {part["date"] for part in parts}
    unknown_days = []
    cursor, end = date.fromisoformat(inventory["requested_start"]), date.fromisoformat(inventory["resolved_end_exclusive"])
    while cursor < end:
        if cursor.isoformat() not in present:
            unknown_days.append(cursor.isoformat())
        cursor += timedelta(days=1)
    return {"data_integrity": "FAIL" if totals["quarantined_rows"] else "INCONCLUSIVE" if missing or unknown_days or not parts else "PASS",
            "row_conservation": {**totals, "selected_source_rows": totals["source_rows"] - totals["outside_selection_rows"], "verified": True},
            "missing_sources": missing, "no_tick_days_unknown_closure": unknown_days,
            "observed_first_utc_msc": parts[0]["first_utc_msc"] if parts else None,
            "observed_last_utc_msc": parts[-1]["last_utc_msc"] if parts else None,
            "coverage_note": "Observed archives cannot alone prove intra-day completeness or market closure on days without ticks.",
            "quality_flag_policy": {"wide_spread": "Ask-Bid > 1% of Bid", "large_jump": "abs(Bid-previous source Bid) > 5% of previous Bid", "action": "report_only"},
            "source_summaries": [{key: value for key, value in source.items() if key != "partitions"} for source in sources],
            "broker_equivalence": "INCONCLUSIVE"}


def load_dataset(store: Store, profile: Profile, dataset_id: str) -> tuple[dict, dict]:
    manifest = read_json(store.path("datasets", identifier(dataset_id), "manifest.json"))
    quality = read_json(store.path("datasets", dataset_id, "quality.json"))
    if manifest.get("schema_version") != 1 or manifest.get("feed") != feed_identity(profile):
        raise StorageError("Dataset schema or feed differs from the selected profile")
    if object_hash({key: value for key, value in manifest.items() if key != "manifest_sha256"}) != manifest.get("manifest_sha256"):
        raise StorageError("Dataset manifest hash mismatch")
    if object_hash(quality) != manifest.get("quality_sha256"):
        raise StorageError("Dataset quality report hash mismatch")
    return manifest, quality


def audit_dataset(profile: Profile, dataset_id: str) -> dict:
    from .sanitize import connection, iter_ticks, quote_line

    with Store(profile.data_root) as store:
        manifest, quality = load_dataset(store, profile, dataset_id)
        con = connection(profile, store.path("audit-spill"))
        total, errors, logical_parts = 0, set(), []
        previous = None
        try:
            for part in manifest["parts"]:
                path = store.path("datasets", dataset_id, "date=" + part["date"], "ticks.parquet")
                if file_hash(path) != part["file_sha256"]:
                    errors.add("PARTITION_CHECKSUM")
                    continue
                activity = read_json(store.path("datasets", dataset_id, "date=" + part["date"], "activity.json"))
                if object_hash(activity) != part["activity_sha256"]:
                    errors.add("ACTIVITY_CHECKSUM")
                digest, count = hashlib.sha256(), 0
                for row in iter_ticks(con, path):
                    stamp, bid, ask, source_id, member, source_row, sequence = row
                    count += 1
                    if sequence != count or previous is not None and stamp < previous or bid <= 0 or ask < bid:
                        errors.add("ROW_CONTRACT")
                    if source_id != part["source_id"] or source_row <= 0:
                        errors.add("PROVENANCE")
                    digest.update(quote_line(stamp, bid, ask))
                    previous = stamp
                if digest.hexdigest() != part["logical_sha256"] or count != part["rows"]:
                    errors.add("LOGICAL_HASH_OR_COUNT")
                logical_parts.append({"date": part["date"], "rows": count, "logical_sha256": digest.hexdigest()})
                total += count
        finally:
            con.close()
        if total != manifest["rows"] or object_hash(logical_parts) != manifest["logical_sha256"]:
            errors.add("DATASET_HASH_OR_COUNT")
        return {"dataset_id": dataset_id, "data_integrity": "FAIL" if errors else quality["data_integrity"],
                "artifact_verification": "FAIL" if errors else "PASS", "errors": sorted(set(errors)),
                "rows": total, "logical_sha256": manifest["logical_sha256"],
                "row_conservation": quality["row_conservation"], "unknown_no_tick_days": len(quality["no_tick_days_unknown_closure"]),
                "mt5_round_trip": "INCONCLUSIVE", "broker_comparison": "INCONCLUSIVE"}
