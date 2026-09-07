"""Strict native tick/bar intake and independent exact import verification."""

from __future__ import annotations

import csv
import hashlib
import json
import re
from collections import Counter
from decimal import Decimal
from itertools import zip_longest
from pathlib import Path

from .archive import PRICE_PATTERN, SourceError, bounded_lines
from .config import Profile
from .mt5_export import ClockMap, TICK_HEADER, load_export, validate_specification
from .sanitize import DAY_MS, connection, day_milliseconds, exact_price, iter_ticks, quote_line, utc_milliseconds
from .storage import Store, feed_identity, file_hash, object_hash, read_json

PERIOD_MS = {"M1": 60000, "M3": 180000, "M10": 600000, "H1": 3600000}
BAR_HEADER = ["<DATE>", "<TIME>", "<OPEN>", "<HIGH>", "<LOW>", "<CLOSE>", "<TICKVOL>", "<VOL>", "<SPREAD>"]
NATIVE_STAMP = re.compile(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}\.\d{3}", re.ASCII)


def native_milliseconds(text: str) -> int:
    if not isinstance(text, str) or not NATIVE_STAMP.fullmatch(text):
        raise SourceError("Native ticks require dotted dates and explicit millisecond precision")
    return utc_milliseconds(text[:10].replace(".", "-") + text[10:] + "Z")


def native_ticks(path: Path, *, encoding: str = "utf-8-sig"):
    previous = None
    try:
        with path.open(encoding=encoding, newline="") as stream:
            reader = csv.reader(bounded_lines(stream), delimiter="\t", strict=True)
            if next(reader, None) != TICK_HEADER.strip().split("\t"):
                raise SourceError("Unsupported native six-field tick header")
            for row in reader:
                if len(row) != 6:
                    raise SourceError("Native tick field count differs from the six-field contract")
                stamp = native_milliseconds(row[0] + " " + row[1])
                bid, ask = exact_price(row[2]), exact_price(row[3])
                if any(not PRICE_PATTERN.fullmatch(value) for value in row[4:]):
                    raise SourceError("Invalid native Last/Volume values")
                if ask < bid or previous is not None and stamp < previous:
                    raise SourceError("Native quotes are crossed or timestamps regressed")
                previous = stamp
                yield stamp, bid, ask
    except (OSError, UnicodeError, csv.Error) as exc:
        raise SourceError("Cannot read the complete native tick file with the selected encoding") from exc


def quote_bars(ticks, period_ms: int):
    current, values = None, None
    for stamp, bid, ask in ticks:
        opened = stamp // period_ms * period_ms
        if current != opened:
            if values is not None:
                yield current, *values
            current, values = opened, [bid, bid, bid, bid]
        else:
            values[1] = max(values[1], bid)
            values[2] = min(values[2], bid)
            values[3] = bid
    if values is not None:
        yield current, *values


def native_bars(path: Path, period_ms: int, *, encoding: str = "utf-8-sig"):
    previous = None
    try:
        with path.open(encoding=encoding, newline="") as stream:
            reader = csv.reader(bounded_lines(stream), delimiter="\t", strict=True)
            if next(reader, None) != BAR_HEADER:
                raise SourceError("Unsupported native nine-field bar header")
            for row in reader:
                if len(row) != 9 or not re.fullmatch(r"\d{2}:\d{2}:\d{2}", row[1], re.ASCII):
                    raise SourceError("Invalid native bar fields or second-precision bar open")
                stamp = native_milliseconds(row[0] + " " + row[1] + ".000")
                values = tuple(exact_price(text) for text in row[2:6])
                opened, high, low, closed = values
                if stamp % period_ms or previous is not None and stamp <= previous or not low <= min(opened, closed) <= max(opened, closed) <= high:
                    raise SourceError("Native bar alignment/order/OHLC is invalid")
                if any(not re.fullmatch(r"[0-9]+", text, re.ASCII) for text in (row[6], row[8])) or not PRICE_PATTERN.fullmatch(row[7]):
                    raise SourceError("Native volume/spread grammar is invalid")
                previous = stamp
                yield stamp, *values
    except (OSError, UnicodeError, csv.Error) as exc:
        raise SourceError("Cannot read complete native bar data") from exc


def capture_path(root: Path, name: str) -> Path:
    if not isinstance(name, str) or Path(name).is_absolute() or "\\" in name or ".." in Path(name).parts:
        raise SourceError("Capture files must be confined relative paths")
    path = root / name
    if not path.resolve().is_relative_to(root.resolve()) or any(parent.is_symlink() for parent in [path, *path.parents] if parent != root.parent):
        raise SourceError("Capture file escapes its root or follows a symlink")
    return path


def export_ticks(store: Store, export_id: str, manifest: dict):
    for chunk in manifest["chunks"]:
        yield from native_ticks(store.path("exports", export_id, chunk["filename"]))


def compare_roundtrip(profile: Profile, export_id: str, native_export: Path, *, encoding="utf-8-sig",
                      evidence: dict | None = None, evidence_root: Path | None = None) -> dict:
    with Store(profile.data_root) as store:
        manifest = load_export(store, profile, export_id)
        differences, actual_count, expected_count = [], 0, 0
        parse_error = None
        mismatch_count = 0
        try:
            for index, (expected, actual) in enumerate(zip_longest(export_ticks(store, export_id, manifest),
                                                                 native_ticks(native_export, encoding=encoding)), 1):
                expected_count += int(expected is not None)
                actual_count += int(actual is not None)
                if expected != actual:
                    mismatch_count += 1
                    if len(differences) < 5:
                        differences.append({"row": index, "expected": [str(value) for value in expected] if expected else None,
                                            "actual": [str(value) for value in actual] if actual else None})
        except SourceError as exc:
            parse_error = str(exc)
        tick_status = "FAIL" if mismatch_count else "INCONCLUSIVE" if parse_error else "PASS"
        evidence = evidence or {}
        metadata_failures, unresolved = [], []
        if evidence.get("schema_version") != 1:
            unresolved.append("native_evidence_schema")
        checks = {"export_manifest_sha256": manifest["manifest_sha256"],
                  "native_specification_sha256": manifest["specification_sha256"],
                  "custom_symbol": manifest["custom_symbol"], "native_ticks_sha256": file_hash(native_export)}
        for field, expected in checks.items():
            if field not in evidence:
                unresolved.append(field)
            elif evidence[field] != expected:
                metadata_failures.append(field)
        if evidence.get("complete") is not True or evidence.get("operator_verified") is not True:
            unresolved.append("native_capture_completeness")
        bar_results = {}
        if not isinstance(evidence.get("native_bars", {}), dict):
            raise SourceError("native_bars evidence must be a period-to-file mapping")
        for period, milliseconds in PERIOD_MS.items():
            entry = evidence.get("native_bars", {}).get(period)
            if not isinstance(entry, dict) or evidence_root is None:
                bar_results[period] = {"status": "INCONCLUSIVE"}
                unresolved.append(period + "_native_bars")
                continue
            path = capture_path(evidence_root, entry.get("path"))
            if file_hash(path) != entry.get("sha256"):
                bar_results[period] = {"status": "FAIL", "reason": "CHECKSUM"}
                continue
            try:
                pairs = zip_longest(quote_bars(export_ticks(store, export_id, manifest), milliseconds),
                                   native_bars(path, milliseconds, encoding=entry.get("encoding", "utf-8-sig")))
                bars, mismatches = 0, 0
                for expected, actual in pairs:
                    bars += 1
                    mismatches += int(expected != actual)
                bar_results[period] = {"status": "PASS" if bars and not mismatches else "FAIL", "bars": bars, "mismatches": mismatches}
            except SourceError as exc:
                bar_results[period] = {"status": "INCONCLUSIVE", "reason": str(exc)}
                unresolved.append(period + "_native_parser")
        failed = tick_status == "FAIL" or metadata_failures or any(item["status"] == "FAIL" for item in bar_results.values())
        result = "FAIL" if failed else "INCONCLUSIVE" if unresolved or tick_status != "PASS" else "PASS"
        return {"export_id": export_id, "mt5_round_trip": result, "tick_equality": tick_status,
                "dataset_id": manifest["dataset_id"], "specification_sha256": manifest["specification_sha256"],
                "clock_sha256": manifest["clock_sha256"],
                "expected_rows": manifest["rows"], "native_rows_read": actual_count, "mismatched_rows": mismatch_count,
                "first_mismatches": differences, "parse_error": parse_error, "metadata_failures": metadata_failures,
                "unresolved": unresolved, "native_bars": bar_results, "export_manifest_sha256": manifest["manifest_sha256"],
                "data_integrity": manifest["data_integrity"], "broker_comparison": "INCONCLUSIVE"}


def comparison_profile_hash(profile: Profile) -> str:
    return object_hash({"status": profile.comparison_status, "limits": dict(profile.comparison_limits),
                        "provenance": dict(profile.comparison_provenance)})


def mcp_ticks(path: Path):
    """JSONL rows preserve the observed MCP time_ms string and decimal lexemes."""
    previous = None
    try:
        with path.open(encoding="utf-8") as stream:
            for line in bounded_lines(stream):
                row = json.loads(line, parse_float=Decimal)
                if not isinstance(row, dict) or not {"time_ms", "bid", "ask"} <= row.keys():
                    raise SourceError("MCP tick row lacks required fields")
                stamp = native_milliseconds(row["time_ms"])
                if any(type(row[key]) not in (str, int, Decimal) for key in ("bid", "ask")):
                    raise SourceError("MCP quote values must preserve exact JSON numeric lexemes")
                bid, ask = (exact_price(str(row[key])) for key in ("bid", "ask"))
                if ask < bid or previous is not None and stamp < previous:
                    raise SourceError("MCP quotes crossed or timestamps regressed")
                previous = stamp
                yield stamp, bid, ask
    except (OSError, UnicodeError, ValueError) as exc:
        if isinstance(exc, SourceError):
            raise
        raise SourceError("Invalid MCP JSONL capture") from exc


def read_mcp_history(path: Path, symbol: str, period: str, sha256: str | None = None):
    """Read one bounded raw response without converting JSON prices to floats."""
    def unique_fields(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise SourceError("Duplicate MCP JSON field")
            result[key] = value
        return result

    def invalid_constant(value):
        raise SourceError("Non-finite MCP JSON number")

    try:
        with path.open("rb") as stream:
            raw = stream.read(16 * 1024 * 1024 + 1)
        if len(raw) > 16 * 1024 * 1024:
            raise SourceError("MCP response exceeds 16 MiB; capture smaller intervals")
        digest = hashlib.sha256(raw).hexdigest()
        if sha256 is not None and digest != sha256:
            raise SourceError("MCP response checksum mismatch")
        data = json.loads(raw, parse_float=Decimal, parse_constant=invalid_constant, object_pairs_hook=unique_fields)
        if (not isinstance(data, dict) or data.get("symbol") != symbol or data.get("period") != period
                or not isinstance(data.get("history"), list) or len(data["history"]) > 100000):
            raise SourceError("MCP response symbol, period or history differs from the capture contract")
        return data["history"], digest
    except (OSError, ValueError, UnicodeError, RecursionError) as exc:
        if isinstance(exc, SourceError):
            raise
        raise SourceError("Cannot read a valid bounded MCP history response") from exc


def mcp_tick_rows(rows):
    previous = None
    for row in rows:
        if not isinstance(row, dict) or not {"time_ms", "bid", "ask"} <= row.keys():
            raise SourceError("MCP tick row lacks required fields")
        stamp = native_milliseconds(row["time_ms"])
        if any(type(row[key]) not in (str, int, Decimal) for key in ("bid", "ask")):
            raise SourceError("MCP prices require exact numeric lexemes")
        bid, ask = (exact_price(str(row[key])) for key in ("bid", "ask"))
        if ask < bid or previous is not None and stamp < previous:
            raise SourceError("MCP quotes crossed or timestamps regressed")
        previous = stamp
        yield stamp, bid, ask


def mcp_bar_rows(rows, period: str):
    previous = None
    for row in rows:
        if not isinstance(row, dict) or not {"time", "open", "high", "low", "close", "tick_volume"} <= row.keys():
            raise SourceError("MCP bar row lacks required fields")
        if not isinstance(row["time"], str) or not re.fullmatch(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}", row["time"], re.ASCII):
            raise SourceError("MCP bars require dotted second-precision timestamps")
        stamp = native_milliseconds(row["time"] + ".000")
        if any(type(row[key]) not in (str, int, Decimal) for key in ("open", "high", "low", "close")):
            raise SourceError("MCP OHLC requires exact numeric lexemes")
        opened, high, low, closed = (exact_price(str(row[key])) for key in ("open", "high", "low", "close"))
        volume = row["tick_volume"]
        if (stamp % PERIOD_MS[period] or previous is not None and stamp <= previous
                or not low <= min(opened, closed) <= max(opened, closed) <= high
                or type(volume) is not int or volume <= 0):
            raise SourceError("Invalid MCP bar alignment, order, OHLC or tick volume")
        previous = stamp
        yield stamp, opened, high, low, closed, volume


def reference_ticks(reference: dict, root: Path, start: int, end: int, issues: set[str]):
    cursor = start
    entries = reference.get("ticks")
    if not isinstance(entries, list) or not entries:
        issues.add("missing_tick_captures")
        return
    for entry in entries:
        if not isinstance(entry, dict):
            raise SourceError("Tick capture manifest entries must be objects")
        left, right = entry.get("start_broker_msc"), entry.get("end_broker_msc")
        if type(left) is not int or type(right) is not int or left != cursor or not left < right <= end:
            raise SourceError("Capture intervals must own the whole broker day exactly without overlap")
        path = capture_path(root, entry.get("path"))
        if file_hash(path) != entry.get("sha256"):
            raise SourceError("Reference tick checksum mismatch")
        mode = entry.get("format")
        if mode not in ("native_tsv", "mcp_jsonl", "mcp_json"):
            raise SourceError("Unknown reference tick capture format")
        if mode == "mcp_json":
            rows, _ = read_mcp_history(path, reference["specification"]["broker_symbol"], "tick", entry["sha256"])
            reader = mcp_tick_rows(rows)
        else:
            reader = mcp_ticks(path) if mode == "mcp_jsonl" else native_ticks(path, encoding=entry.get("encoding", "utf-8-sig"))
        count = 0
        for tick in reader:
            if not left <= tick[0] < right:
                raise SourceError("Tick falls outside its capture interval; boundary ownership is not exhaustive")
            count += 1
            yield tick
        if type(entry.get("rows")) is not int or count != entry["rows"]:
            raise SourceError("Reference tick count differs from its capture manifest")
        if entry.get("complete") is not True:
            issues.add("unverified_capture_completeness")
        limit = entry.get("limit")
        if mode in ("mcp_jsonl", "mcp_json"):
            if type(limit) is not int or limit <= 0 or count >= limit:
                issues.add("potentially_truncated_mcp_capture")
            if entry.get("millisecond_and_all_quotes_verified") is not True:
                issues.add("mcp_precision_or_quote_semantics_unverified")
        if not count and not entry.get("empty_interval_evidence"):
            issues.add("unexplained_empty_capture_interval")
        cursor = right
    if cursor != end:
        issues.add("capture_does_not_reach_day_end")


def match_ticks(left, right, max_delta_ms: int):
    """Earliest eligible pair: one-to-one, order-preserving, maximum cardinality."""
    left, right = iter(left), iter(right)
    a, b = next(left, None), next(right, None)
    while a is not None or b is not None:
        if a is not None and b is not None and abs(a[0] - b[0]) <= max_delta_ms:
            yield a, b
            a, b = next(left, None), next(right, None)
        elif b is None or a is not None and a[0] < b[0]:
            yield a, None
            a = next(left, None)
        else:
            yield None, b
            b = next(right, None)


def split_capture_interval(start: int, end: int, returned_rows: int, limit: int) -> list[tuple[int, int]]:
    if any(type(value) is not int for value in (start, end, returned_rows, limit)) or start >= end or returned_rows < 0 or limit <= 0:
        raise SourceError("Invalid capture interval/count/limit")
    if returned_rows < limit:
        return [(start, end)]
    if end - start == 1:
        raise SourceError("One millisecond reaches the reader limit; use a complete native export to preserve the tied group")
    middle = start + (end - start) // 2
    return [(start, middle), (middle, end)]


def _spooled_ticks(path: Path):
    with path.open(encoding="ascii") as stream:
        for line in stream:
            stamp, bid, ask = line.rstrip("\n").split("\t")
            yield int(stamp), Decimal(bid), Decimal(ask)


def _spool_ticks(ticks, path: Path, groups_path: Path, store: Store, profile: Profile) -> dict:
    minutes, hours, count, first, last = Counter(), Counter(), 0, None, None
    group_time, group_count, group_sum = None, 0, 0
    group_order, logical = hashlib.sha256(), hashlib.sha256()
    with path.open("wb") as stream, groups_path.open("w", encoding="ascii") as groups:
        def close_group():
            if group_count:
                groups.write(f"{group_time}\t{group_count}\t{group_order.hexdigest()}\t{group_sum:064x}\n")

        for stamp, bid, ask in ticks:
            if last is not None and stamp < last:
                raise SourceError("Comparison stream regressed")
            if stamp != group_time:
                close_group()
                group_time, group_count, group_sum, group_order = stamp, 0, 0, hashlib.sha256()
            encoded = quote_line(stamp, bid, ask)
            stream.write(encoded)
            logical.update(encoded)
            group_order.update(encoded)
            group_sum = (group_sum + int.from_bytes(hashlib.sha256(encoded).digest(), "big")) % (1 << 256)
            group_count += 1
            count += 1
            first = stamp if first is None else first
            last = stamp
            minutes[stamp // 60000] += 1
            hours[stamp // 3600000] += 1
            if count % 65536 == 0:
                store.disk_check(1024 * 1024, profile.limits.disk_reserve_bytes)
        close_group()
    return {"rows": count, "first_msc": first, "last_msc": last, "minute_counts": dict(minutes),
            "hour_counts": dict(hours), "ordered_quote_sha256": logical.hexdigest()}


def _active_segments(minutes) -> list[list[int]]:
    result = []
    for minute in sorted(minutes):
        if result and result[-1][1] == minute:
            result[-1][1] = minute + 1
        else:
            result.append([minute, minute + 1])
    return result


def _jaccard(a, b) -> float:
    a, b = set(a), set(b)
    return len(a & b) / len(a | b) if a or b else 0.0


def _decimal_result(value):
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (tuple, list)):
        return [_decimal_result(item) for item in value]
    return value


def _distributions(con, path: Path, tick_size: Decimal) -> dict:
    if not path.stat().st_size:
        return {"support": 0, "overall": {}, "by_broker_hour": {}}
    con.execute("CREATE OR REPLACE TEMP TABLE errors AS SELECT * FROM read_csv(?,header=false,delim='\\t',"
                "columns={'hour':'BIGINT','lag_ms':'BIGINT','bid':'DECIMAL(38,12)','ask':'DECIMAL(38,12)','spread':'DECIMAL(38,12)'})", [str(path)])
    columns = ["lag_ms", "bid", "ask", "spread"]
    result = {"support": con.execute("SELECT count(*) FROM errors").fetchone()[0], "overall": {}, "by_broker_hour": {}}
    from decimal import localcontext
    with localcontext() as context:
        context.prec = 50
        for column in columns:
            query = f"SELECT quantile_disc({column},[0.5,0.95,0.99]),min({column}),max({column}),count(*) FROM errors"
            quantiles, minimum, maximum, support = con.execute(query).fetchone()
            item = {"median": str(quantiles[0]), "p95": str(quantiles[1]), "p99": str(quantiles[2]),
                    "min": str(minimum), "max": str(maximum), "support": support}
            if column != "lag_ms":
                item["p99_ticks"] = str(quantiles[2] / tick_size)
                item["max_ticks"] = str(maximum / tick_size)
            result["overall"][column] = item
            rows = con.execute(f"SELECT hour,quantile_disc({column},[0.5,0.95,0.99]),max({column}),count(*) FROM errors GROUP BY hour ORDER BY hour").fetchall()
            result["by_broker_hour"][column] = [{"hour": hour, "quantiles": _decimal_result(q), "max": str(mx), "support": n} for hour, q, mx, n in rows]
    return result


def _bar_comparison(expected: list, actual: list, tick_size: Decimal) -> dict:
    left, right = {row[0]: row[1:] for row in expected}, {row[0]: row[1:] for row in actual}
    common = sorted(left.keys() & right.keys())
    from decimal import localcontext
    errors = {field: [] for field in ("open", "high", "low", "close", "pivot_pp", "pivot_s1", "pivot_r1", "pivot_s2", "pivot_r2", "pivot_s3", "pivot_r3")}
    with localcontext() as context:
        context.prec = 50
        for stamp in common:
            a, b = left[stamp], right[stamp]
            for index, field in enumerate(("open", "high", "low", "close")):
                errors[field].append(abs(a[index] - b[index]) / tick_size)
            pa, pb = (a[1] + a[2] + a[3]) / 3, (b[1] + b[2] + b[3]) / 3
            for field, va, vb in (("pivot_pp", pa, pb), ("pivot_s1", 2 * pa - a[1], 2 * pb - b[1]), ("pivot_r1", 2 * pa - a[2], 2 * pb - b[2]),
                                 ("pivot_s2", pa - (a[1] - a[2]), pb - (b[1] - b[2])), ("pivot_r2", pa + a[1] - a[2], pb + b[1] - b[2]),
                                 ("pivot_s3", a[2] - 2 * (a[1] - pa), b[2] - 2 * (b[1] - pb)), ("pivot_r3", a[1] + 2 * (pa - a[2]), b[1] + 2 * (pb - b[2]))):
                errors[field].append(abs(va - vb) / tick_size)
        metrics = {}
        for field, values in errors.items():
            values.sort()
            metrics[field] = {"support": len(values), "p99_ticks": str(values[max(0, (len(values) * 99 + 99) // 100 - 1)]) if values else None,
                              "max_ticks": str(values[-1]) if values else None}
    return {"matched_bars": len(common), "missing_broker_bars": len(left.keys() - right.keys()),
            "extra_broker_bars": len(right.keys() - left.keys()), "errors": metrics,
            "pivot_note": "PP/S1..S3/R1..R3 derive from these completed bars for the next native bar; no future bar activation."}


def compare_broker(profile: Profile, dataset_id: str, reference_path: Path, *, roundtrip: dict | None = None) -> dict:
    from .report import load_dataset
    from decimal import localcontext

    reference = read_json(reference_path)
    root = reference_path.parent
    issues, gates = set(), {}
    base = {"comparator_version": 1, "dataset_id": dataset_id, "reference_sha256": object_hash(reference),
            "comparison_profile_sha256": comparison_profile_hash(profile), "comparison_limits": dict(profile.comparison_limits),
            "feed_sha256": object_hash(feed_identity(profile)), "broker_comparison": "INCONCLUSIVE"}
    if reference.get("schema_version") != 1 or reference.get("feed_sha256") != base["feed_sha256"]:
        return {**base, "broker_comparison": "FAIL", "gates": {"reference_feed": "FAIL"}, "unresolved": []}
    if (profile.instrument.account_mode == "unverified" or not profile.instrument.server_alias
            or profile.instrument.feed_mapping_status != "operator_confirmed"):
        issues.add("unverified_account_or_archive_feed_mapping")
    if reference.get("operator_verified") is not True or reference.get("all_quotes_verified") is not True or not reference.get("terminal_build"):
        issues.add("unverified_reference_capture")
    try:
        mapping = ClockMap.parse(reference.get("clock", {}))
        spec = validate_specification(reference.get("specification", {}), profile)
        day = reference.get("day")
        if not isinstance(day, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", day, re.ASCII):
            raise SourceError("A whole broker day is required")
        start, end = day_milliseconds(day), day_milliseconds(day) + DAY_MS
        utc_start, utc_last = mapping.inverse(start), mapping.inverse(end - 1)
        captured = utc_milliseconds(reference.get("captured_at_utc", "").replace("T", " "))
    except (SourceError, ValueError, TypeError, AttributeError):
        return {**base, "gates": {"clock_spec_or_day": "INCONCLUSIVE"}, "unresolved": ["verified_clock_specification_and_capture_day"]}
    purpose = reference.get("purpose")
    if purpose not in ("pilot", "winter", "summer", "transition"):
        issues.add("unfrozen_seasonal_purpose")
    if reference.get("selection_frozen") is not True or not reference.get("selection_reason"):
        issues.add("unfrozen_day_selection")
    if captured <= utc_last:
        issues.add("reference_captured_before_day_completed")
    provenance = profile.comparison_provenance
    pinned = profile.comparison_status == "PINNED" and len(provenance) == 4
    if not pinned or reference.get("comparison_profile_sha256") != base["comparison_profile_sha256"]:
        issues.add("comparison_profile_not_pinned_for_capture")
    elif utc_milliseconds(provenance["pinned_at_utc"].replace("T", " ")) > captured:
        issues.add("profile_pinned_after_reference_capture")
    if purpose in ("winter", "summer", "transition") and day in provenance.get("pilot_dates", []):
        issues.add("acceptance_day_used_for_profile_tuning")
    if reference.get("clock_alignment_verified") is not True or reference.get("unexplained_clock_offset_seconds") != 0:
        issues.add("clock_alignment_evidence")
    if type(reference.get("unexplained_clock_offset_seconds")) is int and reference["unexplained_clock_offset_seconds"] != 0:
        gates["documented_clock_offset"] = "FAIL"
    tick_size = Decimal(spec["properties"]["tick_size"])
    with Store(profile.data_root) as store:
        dataset, quality = load_dataset(store, profile, dataset_id)
        base.update({"dataset_manifest_sha256": dataset["manifest_sha256"], "day": day, "purpose": purpose,
                     "clock_sha256": object_hash(reference["clock"]), "specification_sha256": object_hash(spec),
                     "data_integrity": dataset["data_integrity"]})
        if dataset["data_integrity"] != "PASS":
            issues.add("dataset_integrity_or_coverage_unaccepted")
        if day_milliseconds(dataset["requested_start"]) > utc_start or day_milliseconds(dataset["resolved_end_exclusive"]) <= utc_last:
            issues.add("dataset_does_not_cover_complete_broker_day")
        if roundtrip is None or roundtrip.get("mt5_round_trip") != "PASS":
            issues.add("native_roundtrip_pending")
        else:
            exported = load_export(store, profile, roundtrip.get("export_id", ""))
            if (exported["dataset_manifest_sha256"] != dataset["manifest_sha256"]
                    or roundtrip.get("export_manifest_sha256") != exported["manifest_sha256"]
                    or exported["clock_sha256"] != base["clock_sha256"] or exported["specification_sha256"] != base["specification_sha256"]):
                gates["roundtrip_input_identity"] = "FAIL"
        scratch_id = "broker-" + object_hash({"dataset": dataset["manifest_sha256"], "reference": base["reference_sha256"]})[:24]
        scratch = store.path("comparison-work", scratch_id)
        scratch.mkdir(parents=True, exist_ok=True)
        a_path, b_path = store.path("comparison-work", scratch_id, "source.tsv"), store.path("comparison-work", scratch_id, "broker.tsv")
        a_groups, b_groups = store.path("comparison-work", scratch_id, "source-groups.tsv"), store.path("comparison-work", scratch_id, "broker-groups.tsv")
        error_path = store.path("comparison-work", scratch_id, "errors.tsv")
        con = connection(profile, store.path("comparison-work", scratch_id, "spill"))
        source_bars = {period: [] for period in PERIOD_MS}
        # Keep at most 26 preceding bars per timeframe and the scored day's bars.
        from collections import deque
        warmup = {period: deque(maxlen=26) for period in PERIOD_MS}
        current_bars = {}

        def source_ticks():
            for part in dataset["parts"]:
                if part["last_utc_msc"] < utc_start - 7 * DAY_MS or part["first_utc_msc"] > utc_last:
                    continue
                path = store.path("datasets", dataset_id, "date=" + part["date"], "ticks.parquet")
                if file_hash(path) != part["file_sha256"]:
                    raise SourceError("Dataset partition checksum mismatch")
                for row in iter_ticks(con, path):
                    stamp, bid, ask = row[:3]
                    mapped = mapping.forward(stamp)
                    if mapped >= end:
                        continue
                    for period, milliseconds in PERIOD_MS.items():
                        opened = mapped // milliseconds * milliseconds
                        bar = current_bars.get(period)
                        if bar is None or bar[0] != opened:
                            if bar is not None:
                                (warmup[period] if bar[0] < start else source_bars[period]).append(tuple(bar))
                            current_bars[period] = [opened, bid, bid, bid, bid]
                        else:
                            bar[2], bar[3], bar[4] = max(bar[2], bid), min(bar[3], bid), bid
                    if start <= mapped < end:
                        yield mapped, bid, ask
            for period, bar in current_bars.items():
                (warmup[period] if bar[0] < start else source_bars[period]).append(tuple(bar))

        try:
            source_activity = _spool_ticks(source_ticks(), a_path, a_groups, store, profile)
            broker_activity = _spool_ticks(reference_ticks(reference, root, start, end, issues), b_path, b_groups, store, profile)
            matched, exact, unmatched_a, unmatched_b = 0, 0, 0, 0
            with error_path.open("w", encoding="ascii") as stream, localcontext() as context:
                context.prec = 50
                for a, b in match_ticks(_spooled_ticks(a_path), _spooled_ticks(b_path), profile.comparison_limits["max_match_delta_ms"]):
                    if a is None:
                        unmatched_b += 1
                    elif b is None:
                        unmatched_a += 1
                    else:
                        matched += 1
                        exact += int(a == b)
                        stream.write(f"{a[0] // 3600000}\t{b[0]-a[0]}\t{abs(a[1]-b[1])}\t{abs(a[2]-b[2])}\t{abs((a[2]-a[1])-(b[2]-b[1]))}\n")
            distribution = _distributions(con, error_path, tick_size)
            tied_reversals = multiplicity_mismatches = 0
            if a_groups.stat().st_size and b_groups.stat().st_size:
                columns = "{'t':'BIGINT','n':'BIGINT','ordered':'VARCHAR','bag':'VARCHAR'}"
                tied_reversals = con.execute(f"SELECT count(*) FROM read_csv(?,header=false,delim='\\t',columns={columns}) a "
                                            f"JOIN read_csv(?,header=false,delim='\\t',columns={columns}) b ON a.t=b.t "
                                            "WHERE a.n=b.n AND a.bag=b.bag AND a.ordered<>b.ordered", [str(a_groups), str(b_groups)]).fetchone()[0]
                multiplicity_mismatches = con.execute(f"SELECT count(*) FROM read_csv(?,header=false,delim='\\t',columns={columns}) a "
                                                     f"FULL OUTER JOIN read_csv(?,header=false,delim='\\t',columns={columns}) b ON a.t=b.t "
                                                     "WHERE (coalesce(a.n,0)>1 OR coalesce(b.n,0)>1) AND coalesce(a.n,0)<>coalesce(b.n,0)", [str(a_groups), str(b_groups)]).fetchone()[0]
            exact_ordinal = sum(a == b for a, b in zip(_spooled_ticks(a_path), _spooled_ticks(b_path)))
        except SourceError as exc:
            return {**base, "gates": {"reference_or_source_integrity": "INCONCLUSIVE"}, "unresolved": [str(exc)]}
        finally:
            con.close()
        if not source_activity["rows"] or not broker_activity["rows"]:
            issues.add("no_tick_support")
        matched_a = matched / source_activity["rows"] if source_activity["rows"] else 0
        matched_b = matched / broker_activity["rows"] if broker_activity["rows"] else 0
        jaccard = _jaccard(source_activity["minute_counts"], broker_activity["minute_counts"])
        gates["equal_time_order"] = "FAIL" if tied_reversals else "PASS"
        gates["session_segments"] = "PASS" if _active_segments(source_activity["minute_counts"]) == _active_segments(broker_activity["minute_counts"]) else "FAIL"
        limits = profile.comparison_limits
        numerical = {"matched_source_fraction": matched_a >= limits["min_matched_fraction_each_feed"],
                     "matched_broker_fraction": matched_b >= limits["min_matched_fraction_each_feed"],
                     "active_minute_jaccard": jaccard >= limits["min_active_minute_jaccard"]}
        for field in ("bid", "ask", "spread"):
            numerical[field + "_p99_error"] = bool(distribution["support"]) and Decimal(distribution["overall"][field]["p99_ticks"]) <= Decimal(str(limits["max_p99_" + field + "_error_ticks"]))
        for key, passed in numerical.items():
            gates[key] = "INCONCLUSIVE" if not pinned else "PASS" if passed else "FAIL"
        if source_activity["rows"] and broker_activity["rows"]:
            boundaries = {key: broker_activity[key] - source_activity[key] for key in ("first_msc", "last_msc")}
            gates["day_boundaries"] = "PASS" if all(abs(value) <= limits["max_match_delta_ms"] for value in boundaries.values()) else "FAIL"
        else:
            boundaries = {}
            gates["day_boundaries"] = "INCONCLUSIVE"
        bars, broker_m1 = {}, []
        entries = reference.get("bars", {})
        for period, milliseconds in PERIOD_MS.items():
            entry = entries.get(period) if isinstance(entries, dict) else None
            if not isinstance(entry, dict):
                issues.add(period + "_native_bars_missing")
                continue
            path = capture_path(root, entry.get("path"))
            if file_hash(path) != entry.get("sha256"):
                gates[period + "_bar_checksum"] = "FAIL"
                continue
            native, prior = [], deque(maxlen=26)
            try:
                if entry.get("format") == "mcp_json":
                    rows, _ = read_mcp_history(path, spec["broker_symbol"], period, entry["sha256"])
                    reader = (bar[:5] for bar in mcp_bar_rows(rows, period))
                    if type(entry.get("limit")) is not int or entry["limit"] <= 0 or len(rows) >= entry["limit"]:
                        issues.add(period + "_native_bar_capture_limit_unverified")
                        issues.add("native_bar_capture_incomplete")
                        continue
                elif entry.get("format", "native_tsv") == "native_tsv":
                    reader = native_bars(path, milliseconds, encoding=entry.get("encoding", "utf-8-sig"))
                else:
                    raise SourceError("Unknown reference bar capture format")
                for bar in reader:
                    if bar[0] < start:
                        prior.append(bar)
                    elif bar[0] < end:
                        native.append(bar)
            except SourceError:
                issues.add(period + "_native_bar_parser")
                continue
            if len(prior) < 26 or len(warmup[period]) < 26:
                issues.add(period + "_warmup_incomplete")
            bars[period] = _bar_comparison(source_bars[period], native, tick_size)
            bars[period]["warmup"] = _bar_comparison(list(warmup[period]), list(prior), tick_size)
            bar_result = bars[period]
            gates[period + "_bar_opens"] = "PASS" if bar_result["matched_bars"] and not bar_result["missing_broker_bars"] and not bar_result["extra_broker_bars"] else "FAIL"
            for field in ("open", "high", "low", "close"):
                error = bar_result["errors"][field]["p99_ticks"]
                gates[period + "_" + field] = "INCONCLUSIVE" if not pinned or error is None else "PASS" if Decimal(error) <= Decimal(str(limits["max_p99_m1_ohlc_error_ticks"])) else "FAIL"
            if period == "M1":
                broker_m1 = native
        diagnostics = []
        expected_m1 = {bar[0]: bar[1:] for bar in source_bars["M1"]}
        for seconds in (-3600, 0, 3600):
            shifted = {bar[0] + seconds * 1000: bar[1:] for bar in broker_m1}
            common = expected_m1.keys() & shifted.keys()
            diagnostics.append({"diagnostic_shift_seconds": seconds, "matching_bar_opens": len(common),
                                "exact_bid_ohlc_bars": sum(expected_m1[key] == shifted[key] for key in common),
                                "active_minute_jaccard": _jaccard(source_activity["minute_counts"],
                                                                  (key + seconds // 60 for key in broker_activity["minute_counts"]))})
        zero = diagnostics[1]["exact_bid_ohlc_bars"]
        gates["clock_shift_diagnostic"] = "FAIL" if any(item["diagnostic_shift_seconds"] and item["exact_bid_ohlc_bars"] > zero for item in diagnostics) else "PASS"
        incomplete_capture = {"no_tick_support", "missing_tick_captures", "potentially_truncated_mcp_capture",
                              "unverified_capture_completeness", "capture_does_not_reach_day_end",
                              "reference_captured_before_day_completed", "native_bar_capture_incomplete"}
        result = ("INCONCLUSIVE" if issues & incomplete_capture else "FAIL" if "FAIL" in gates.values()
                  else "INCONCLUSIVE" if issues or "INCONCLUSIVE" in gates.values() else "PASS")
        return {**base, "broker_comparison": result, "gates": gates, "unresolved": sorted(issues),
                "matching_policy": "earliest eligible one-to-one pair in timestamp/source order; no tick reuse",
                "matched_pairs": matched, "exact_matched_pairs": exact, "exact_match_fraction": exact / max(source_activity["rows"], broker_activity["rows"], 1),
                "exact_sequence_equal": source_activity["rows"] > 0 and source_activity["rows"] == broker_activity["rows"] and source_activity["ordered_quote_sha256"] == broker_activity["ordered_quote_sha256"],
                "exact_ordinal_match_fraction": exact_ordinal / max(source_activity["rows"], broker_activity["rows"], 1),
                "duplicate_timestamp_multiplicity_mismatches": multiplicity_mismatches,
                "unmatched_source": unmatched_a, "unmatched_broker": unmatched_b, "matched_source_fraction": matched_a,
                "matched_broker_fraction": matched_b, "active_minute_jaccard": jaccard,
                "reversed_equal_time_groups": tied_reversals, "boundary_differences_ms": boundaries,
                "source_activity": source_activity, "broker_activity": broker_activity, "quote_errors": distribution,
                "bars": bars, "clock_diagnostics": diagnostics, "mt5_round_trip": roundtrip.get("mt5_round_trip", "INCONCLUSIVE") if roundtrip else "INCONCLUSIVE",
                "scope": "This named broker-day sample only; historical specifications, fills and full-history equivalence are unproved."}
