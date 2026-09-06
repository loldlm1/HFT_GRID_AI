"""Integrity reports distinguish observed ticks from unproved market closures."""

from __future__ import annotations

import hashlib
from datetime import date, timedelta

from .config import Profile
from .storage import Store, StorageError, atomic_json, feed_identity, file_hash, identifier, object_hash, read_json


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


def save_comparison(profile: Profile, result: dict, comparison_id: str | None = None) -> dict:
    comparison_id = identifier(comparison_id or "cmp-" + object_hash(result)[:24])
    value = {**result, "comparison_id": comparison_id}
    with Store(profile.data_root) as store:
        atomic_json(store.path("comparisons", comparison_id, "report.json"), value, immutable=True)
        path = store.path("comparisons", comparison_id, "report.md")
        lines = ["# Exness Comparison", "", f"Comparison: `{comparison_id}`", ""]
        for key in ("data_integrity", "mt5_round_trip", "tick_equality", "broker_comparison", "day", "purpose"):
            if key in result:
                lines.append(f"- {key}: `{result[key]}`")
        lines.extend(["", "Detailed metrics, supports, independent gates and hashes are in `report.json`.", ""])
        text = "\n".join(lines)
        if path.exists() and path.read_text(encoding="utf-8") != text:
            raise StorageError("Comparison text already exists with different content")
        path.write_text(text, encoding="utf-8")
    return value


def seasonal_schedule(year: int) -> dict:
    if type(year) is not int or not 1970 <= year <= 9998:
        raise StorageError("Schedule year must be 1970..9998")

    def nth_weekday(month, weekday, number):
        first = date(year, month, 1)
        return first + timedelta(days=(weekday - first.weekday()) % 7 + 7 * (number - 1))

    def last_sunday(month):
        next_month = date(year + (month == 12), month % 12 + 1, 1)
        last = next_month - timedelta(days=1)
        return last - timedelta(days=(last.weekday() - 6) % 7)

    boundaries = {"us_spring": nth_weekday(3, 6, 2), "uk_spring": last_sunday(3),
                  "uk_autumn": last_sunday(10), "us_autumn": nth_weekday(11, 6, 1)}
    return {"schema_version": 1, "year": year, "winter": nth_weekday(1, 2, 2).isoformat(),
            "summer": nth_weekday(7, 2, 3).isoformat(),
            "transition_days": {name: {"before": (day - timedelta(days=2)).isoformat(), "after": (day + timedelta(days=1)).isoformat()}
                                for name, day in boundaries.items()},
            "selection_rule": "Second January Wednesday; third July Wednesday; Friday/Monday around US/UK DST Sundays. Verify actual market availability before freezing replacements.",
            "scope": "Diagnostic dates; these calendars do not assert the broker changes its historical UTC clock."}


def seasonal_report(profile: Profile, year: int, comparison_ids: list[str]) -> dict:
    from .compare import comparison_profile_hash
    schedule = seasonal_schedule(year)
    reports, mismatches = {}, []
    with Store(profile.data_root) as store:
        for comparison_id in comparison_ids:
            result = read_json(store.path("comparisons", identifier(comparison_id), "report.json"))
            if result.get("comparison_profile_sha256") != comparison_profile_hash(profile) or result.get("feed_sha256") != object_hash(feed_identity(profile)):
                mismatches.append(comparison_id)
            key = result.get("day")
            if key in reports:
                raise StorageError("Provide one frozen report per day; do not select the most favorable result")
            reports[key] = result
    required = {schedule["winter"]: "winter", schedule["summer"]: "summer"}
    for dates in schedule["transition_days"].values():
        required.update({value: "transition" for value in dates.values()})
    gates = {}
    for day, purpose in required.items():
        result = reports.get(day, {})
        gates[day] = result.get("broker_comparison", "INCONCLUSIVE") if result.get("purpose") == purpose else "INCONCLUSIVE"
    seasonal = [gates[schedule["winter"]], gates[schedule["summer"]]]
    state = "FAIL" if mismatches or "FAIL" in seasonal else "PASS" if set(seasonal) == {"PASS"} else "INCONCLUSIVE"
    clock_state = "FAIL" if mismatches or "FAIL" in gates.values() else "PASS" if set(gates.values()) == {"PASS"} else "INCONCLUSIVE"
    return {"seasonal_acceptance": state, "clock_regime_acceptance": clock_state, "year": year, "day_gates": gates, "profile_or_feed_mismatches": mismatches,
            "comparison_ids": comparison_ids, "schedule": schedule, "scope": "Accepted samples only; no full-history broker equivalence or deployment claim."}
