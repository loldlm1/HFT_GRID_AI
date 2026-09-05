"""Strict native tick/bar intake and independent exact import verification."""

from __future__ import annotations

import csv
import re
from datetime import datetime
from decimal import Decimal
from itertools import zip_longest
from pathlib import Path

from .archive import PRICE_PATTERN, SourceError
from .config import Profile
from .mt5_export import TICK_HEADER, load_export
from .sanitize import EPOCH, exact_price, utc_milliseconds
from .storage import Store, StorageError, file_hash

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
            reader = csv.reader(stream, delimiter="\t", strict=True)
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
            reader = csv.reader(stream, delimiter="\t", strict=True)
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
                "expected_rows": manifest["rows"], "native_rows_read": actual_count, "mismatched_rows": mismatch_count,
                "first_mismatches": differences, "parse_error": parse_error, "metadata_failures": metadata_failures,
                "unresolved": unresolved, "native_bars": bar_results, "export_manifest_sha256": manifest["manifest_sha256"],
                "data_integrity": manifest["data_integrity"], "broker_comparison": "INCONCLUSIVE"}
