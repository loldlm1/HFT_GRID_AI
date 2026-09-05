"""Exact source parsing, row conservation and bounded UTC-date partitions."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import time
import zipfile
from collections import Counter, OrderedDict
from datetime import date, datetime, timedelta
from decimal import Decimal, localcontext
from functools import lru_cache
from pathlib import Path

from .archive import ArchiveKey, PRICE_PATTERN, SOURCE_HEADER, STAMP_PATTERN, SourceError, zip_member
from .config import Profile
from .download import request_identity
from .storage import Store, StorageError, atomic_json, feed_identity, file_hash, identifier, load_inventory, object_hash, read_json

TRANSFORM_VERSION = 1
EPOCH = datetime(1970, 1, 1)
DAY_MS = 86_400_000


def utc_milliseconds(text: str) -> int:
    if not STAMP_PATTERN.fullmatch(text):
        raise SourceError("TIMESTAMP_GRAMMAR")
    try:
        stamp = datetime.fromisoformat(text[:-1])
    except ValueError as exc:
        raise SourceError("TIMESTAMP_CALENDAR") from exc
    delta = stamp - EPOCH
    return delta.days * DAY_MS + delta.seconds * 1000 + delta.microseconds // 1000


def iso_milliseconds(value: int) -> str:
    return (EPOCH + timedelta(milliseconds=value)).isoformat(timespec="milliseconds") + "Z"


def day_milliseconds(value: date | str) -> int:
    day = date.fromisoformat(value) if isinstance(value, str) else value
    return (day - EPOCH.date()).days * DAY_MS


@lru_cache(maxsize=8192)
def exact_price(text: str) -> Decimal:
    if not PRICE_PATTERN.fullmatch(text):
        raise SourceError("PRICE_GRAMMAR")
    integer, _, fractional = text.partition(".")
    if len(integer.lstrip("0")) > 26 or len(fractional) > 12:
        raise SourceError("PRICE_PRECISION_OR_RANGE")
    value = Decimal(text)
    if value <= 0:
        raise SourceError("NON_POSITIVE_PRICE")
    return value


def decimal_text(value: Decimal) -> str:
    text = format(value, "f")
    return text.rstrip("0").rstrip(".") if "." in text else text


def quote_line(stamp: int, bid: Decimal, ask: Decimal) -> bytes:
    return f"{stamp}\t{decimal_text(bid)}\t{decimal_text(ask)}\n".encode("ascii")


@lru_cache(maxsize=256)
def _archive_milliseconds(key: ArchiveKey) -> tuple[int, int]:
    return tuple(day_milliseconds(day) for day in key.bounds)


def parse_row(row: list[str], key: ArchiveKey) -> tuple[int, Decimal, Decimal]:
    if len(row) != 5:
        raise SourceError("FIELD_COUNT")
    if row[0] != "exness" or row[1] != key.symbol:
        raise SourceError("VENDOR_OR_SYMBOL")
    stamp = utc_milliseconds(row[2])
    start, end = _archive_milliseconds(key)
    if not start <= stamp < end:
        raise SourceError("ARCHIVE_INTERVAL")
    bid, ask = exact_price(row[3]), exact_price(row[4])
    if ask < bid:
        raise SourceError("CROSSED_QUOTE")
    return stamp, bid, ask


def connection(profile: Profile, temporary: Path):
    import duckdb
    temporary.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute(f"SET memory_limit='{profile.limits.memory_limit_mb}MB'")
    con.execute(f"SET max_temp_directory_size='{profile.limits.temp_limit_mb}MB'")
    con.execute("SET temp_directory=?", [str(temporary)])
    con.execute("SET threads=1")
    con.execute("SET preserve_insertion_order=false")
    return con


def iter_ticks(con, path: Path):
    cursor = con.execute("SELECT time_utc_msc,bid,ask,source_id,source_member,source_row_number,sequence_in_partition "
                         "FROM read_parquet(?) ORDER BY sequence_in_partition", [str(path)])
    while batch := cursor.fetchmany(4096):
        yield from batch


def _source_partitions(store: Store, profile: Profile, stage: Path, owner: dict, source: dict) -> dict:
    source_id = source["sha256"]
    key = ArchiveKey(**owner["key"])
    work = store.path("datasets", stage.name, source_id)
    work.mkdir(parents=True, exist_ok=True)
    completed = store.path("datasets", stage.name, source_id, "source-summary.json")
    if completed.exists():
        result = read_json(completed)
        for part in result["partitions"]:
            path = store.path("datasets", stage.name, "date=" + part["date"], "ticks.parquet")
            if file_hash(path) != part["file_sha256"]:
                raise StorageError("Completed staging partition changed; preserve it and use a new dataset ID")
        return result
    archive_path = store.path("archives", source_id, source["filename"])
    if file_hash(archive_path) != source_id:
        raise StorageError("Raw archive hash differs from the ledger")
    # Spool contains only time/prices/source row; provenance is added once per partition.
    store.disk_check(source["csv_bytes"] * 2, profile.limits.disk_reserve_bytes)
    parsed = store.path("datasets", stage.name, source_id, "parsed.json")
    quarantine_path = store.path("datasets", stage.name, source_id, "rejected_rows.jsonl")
    if parsed.exists():
        stats = read_json(parsed)
        for spool in stats["spools"]:
            if file_hash(store.path("datasets", stage.name, source_id, spool["name"])) != spool["sha256"]:
                raise StorageError("Parse checkpoint changed; use a new dataset ID")
    else:
        stats = {"source_id": source_id, "source_member": source["csv_member"], "source_rows": 0,
                 "retained_rows": 0, "outside_selection_rows": 0, "quarantined_rows": 0,
                 "timestamp_regressions": 0, "adjacent_equal_timestamp_rows": 0,
                 "zero_spread_rows": 0, "wide_spread_rows": 0, "large_jump_rows": 0,
                 "millisecond_zero_rows": 0, "max_price_scale": 0}
        reasons, handles, days = Counter(), OrderedDict(), set()
        previous = previous_bid = None
        start, end = day_milliseconds(owner["start"]), day_milliseconds(owner["end"])
        # Incomplete spools belong to this source attempt, never to a published dataset.
        for path in work.glob("*.tsv"):
            if path.is_symlink():
                raise StorageError("Symlink spool refused")
            path.unlink()
        try:
            with zipfile.ZipFile(archive_path) as archive, quarantine_path.open("w", encoding="utf-8") as rejected:
                member = zip_member(archive, key, profile.limits)
                with io.TextIOWrapper(archive.open(member), encoding="utf-8-sig", newline="") as stream:
                    reader = csv.reader(stream, strict=True)
                    if tuple(next(reader, ())) != SOURCE_HEADER:
                        raise SourceError("Unsupported source CSV header; no dataset published")
                    with localcontext() as context:
                        context.prec = 50
                        for number, row in enumerate(reader, 1):
                            stats["source_rows"] += 1
                            try:
                                stamp, bid, ask = parse_row(row, key)
                            except SourceError as exc:
                                reason = str(exc)
                                reasons[reason] += 1
                                stats["quarantined_rows"] += 1
                                rejected.write(json.dumps({"source_row_number": number, "reason": reason, "fields": row}) + "\n")
                                continue
                            if not start <= stamp < end:
                                stats["outside_selection_rows"] += 1
                                continue
                            stats["retained_rows"] += 1
                            stats["timestamp_regressions"] += int(previous is not None and stamp < previous)
                            stats["adjacent_equal_timestamp_rows"] += int(stamp == previous)
                            stats["zero_spread_rows"] += int(bid == ask)
                            stats["wide_spread_rows"] += int(ask - bid > bid / 100)
                            stats["large_jump_rows"] += int(previous_bid is not None and abs(bid - previous_bid) > previous_bid / 20)
                            stats["millisecond_zero_rows"] += int(stamp % 1000 == 0)
                            stats["max_price_scale"] = max(stats["max_price_scale"], -bid.as_tuple().exponent, -ask.as_tuple().exponent)
                            previous, previous_bid = stamp, bid
                            day = row[2][:10]
                            days.add(day)
                            if day not in handles:
                                if len(handles) == 4:
                                    handles.popitem(last=False)[1].close()
                                handles[day] = store.path("datasets", stage.name, source_id, day + ".tsv").open("a", encoding="ascii", newline="")
                            handles.move_to_end(day)
                            handles[day].write(f"{stamp}\t{row[3]}\t{row[4]}\t{number}\n")
                            if number % 65536 == 0:
                                store.disk_check(1024 * 1024, profile.limits.disk_reserve_bytes)
        except (OSError, zipfile.BadZipFile, UnicodeError, csv.Error) as exc:
            raise SourceError("Source CRC, encoding or CSV structure failed; no dataset published") from exc
        finally:
            for handle in handles.values():
                handle.close()
        stats["quarantine_reasons"] = dict(reasons)
        stats["quarantine_sha256"] = file_hash(quarantine_path)
        stats["spools"] = [{"date": day, "name": day + ".tsv", "sha256": file_hash(work / (day + ".tsv"))} for day in sorted(days)]
        atomic_json(parsed, stats, immutable=True)

    parts = []
    con = connection(profile, store.path("datasets", stage.name, source_id, "spill"))
    try:
        for spool in stats["spools"]:
            day = spool["date"]
            directory = store.path("datasets", stage.name, "date=" + day)
            directory.mkdir(parents=True, exist_ok=True)
            path = store.path("datasets", stage.name, "date=" + day, "ticks.parquet")
            receipt = store.path("datasets", stage.name, "date=" + day, "partition.json")
            if receipt.exists():
                part = read_json(receipt)
                if part["source_id"] != source_id or file_hash(path) != part["file_sha256"]:
                    raise StorageError("Ambiguous ownership or changed staging partition")
                parts.append(part)
                continue
            temporary = store.path("datasets", stage.name, "date=" + day, "ticks.parquet.part")
            con.execute("CREATE OR REPLACE TEMP TABLE selected AS SELECT *, ?::VARCHAR source_id, ?::VARCHAR source_member "
                        "FROM read_csv(?, delim='\\t', header=false, columns={'time_utc_msc':'BIGINT','bid':'DECIMAL(38,12)',"
                        "'ask':'DECIMAL(38,12)','source_row_number':'BIGINT'})", [source_id, source["csv_member"], str(store.path("datasets", stage.name, source_id, spool["name"]))])
            con.execute("COPY (SELECT time_utc_msc,bid,ask,source_id,source_member,source_row_number,"
                        "row_number() OVER (ORDER BY time_utc_msc,source_row_number)::BIGINT sequence_in_partition "
                        "FROM selected ORDER BY time_utc_msc,source_row_number) TO ? (FORMAT PARQUET, COMPRESSION ZSTD)", [str(temporary)])
            digest, count, first, last, ties = hashlib.sha256(), 0, None, None, 0
            minute_counts, hour_counts, gaps = Counter(), Counter(), []
            previous_quote, repeated = None, 0
            for row in iter_ticks(con, temporary):
                stamp, bid, ask = row[:3]
                digest.update(quote_line(stamp, bid, ask))
                count += 1
                ties += int(stamp == last)
                repeated += int((stamp, bid, ask) == previous_quote)
                previous_quote = (stamp, bid, ask)
                minute_counts[str(stamp // 60000)] += 1
                hour_counts[str(stamp // 3600000)] += 1
                if last is not None and stamp - last > 60000:
                    gaps.append({"after_utc_msc": last, "before_utc_msc": stamp, "duration_ms": stamp - last})
                first = stamp if first is None else first
                last = stamp
            activity = {"date": day, "minute_counts": dict(minute_counts), "hour_counts": dict(hour_counts),
                        "gaps_over_60_seconds": gaps, "gap_classification": "UNREVIEWED"}
            atomic_json(store.path("datasets", stage.name, "date=" + day, "activity.json"), activity, immutable=True)
            part = {"date": day, "rows": count, "source_id": source_id, "logical_sha256": digest.hexdigest(),
                    "file_sha256": file_hash(temporary), "bytes": temporary.stat().st_size,
                    "first_utc_msc": first, "last_utc_msc": last, "equal_timestamp_rows": ties,
                    "identical_adjacent_ticks": repeated, "activity_sha256": object_hash(activity)}
            os.replace(temporary, path)
            atomic_json(receipt, part, immutable=True)
            parts.append(part)
    finally:
        con.close()
    result = {key: value for key, value in stats.items() if key != "spools"}
    result["partitions"] = parts
    if sum(part["rows"] for part in parts) != result["retained_rows"]:
        raise StorageError("Partition row conservation failed")
    atomic_json(completed, result, immutable=True)
    for spool in stats["spools"]:
        store.path("datasets", stage.name, source_id, spool["name"]).unlink()
    return result


def build_dataset(profile: Profile, inventory_id: str, dataset_id: str) -> dict:
    from .report import quality_report

    identifier(dataset_id)
    if dataset_id.endswith("-partial"):
        raise StorageError("Dataset IDs ending in -partial are reserved for staging")
    started = time.monotonic()
    with Store(profile.data_root) as store:
        inv = load_inventory(store, inventory_id, profile)
        sources, missing = [], []
        cursor = inv["requested_start"]
        for owner in inv["owners"]:
            if owner["start"] != cursor or owner["end"] <= owner["start"]:
                raise StorageError("Inventory ownership is overlapping or incomplete")
            cursor = owner["end"]
            record = store.object(request_identity(owner)) if owner["state"] == "AVAILABLE_CANDIDATE" else None
            if record is None:
                missing.append({"start": owner["start"], "end": owner["end"], "state": owner["state"] if owner["state"] != "AVAILABLE_CANDIDATE" else "NOT_DOWNLOADED"})
            else:
                sources.append((owner, record))
        if cursor != inv["resolved_end_exclusive"]:
            raise StorageError("Inventory ownership does not reach the requested cutoff")
        contract = {"schema_version": 1, "transform_version": TRANSFORM_VERSION, "inventory_id": inventory_id,
                    "feed": feed_identity(profile), "sources": [{"sha256": item["sha256"], "owner_start": owner["start"],
                    "owner_end": owner["end"]} for owner, item in sources], "missing_sources": missing}
        destination = store.path("datasets", dataset_id)
        stage = store.path("datasets", dataset_id + "-partial")
        if destination.exists():
            from .report import load_dataset
            existing, _ = load_dataset(store, profile, dataset_id)
            if existing["input_sha256"] != object_hash(contract):
                raise StorageError("Dataset ID belongs to different inputs; use a new ID")
            return existing
        stage.mkdir(parents=True, exist_ok=True)
        atomic_json(store.path("datasets", stage.name, "input.json"), contract, immutable=True)
        summaries = [_source_partitions(store, profile, stage, owner, source) for owner, source in sources]
        parts = sorted((part for summary in summaries for part in summary["partitions"]), key=lambda part: part["date"])
        quality = quality_report(inv, summaries, missing, parts)
        manifest = {**contract, "dataset_id": dataset_id, "input_sha256": object_hash(contract),
                    "requested_start": inv["requested_start"], "resolved_end_exclusive": inv["resolved_end_exclusive"],
                    "canonical_schema": "time_utc_msc BIGINT; bid/ask DECIMAL(38,12); source_id/source_member VARCHAR; source_row_number/sequence_in_partition BIGINT",
                    "order": "UTC millisecond, authoritative source row number", "time_mapping": "UTC_UNMODIFIED",
                    "parts": parts, "rows": sum(part["rows"] for part in parts),
                    "logical_sha256": object_hash([{key: part[key] for key in ("date", "rows", "logical_sha256")} for part in parts]),
                    "quality_sha256": object_hash(quality), "data_integrity": quality["data_integrity"]}
        manifest["manifest_sha256"] = object_hash(manifest)
        atomic_json(store.path("datasets", stage.name, "quality.json"), quality, immutable=True)
        atomic_json(store.path("datasets", stage.name, "manifest.json"), manifest, immutable=True)
        os.replace(stage, destination)
        atomic_json(store.path("runs", inventory_id, dataset_id + "-build.json"),
                    {"elapsed_seconds": round(time.monotonic() - started, 3), "dataset_id": dataset_id,
                     "peak_rss_kib": peak_rss_kib(), "memory_limit_mb": profile.limits.memory_limit_mb,
                     "spill_limit_mb": profile.limits.temp_limit_mb, "rows": manifest["rows"]})
        return manifest


def peak_rss_kib() -> int | None:
    try:
        import resource
        return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    except ImportError:
        return None
