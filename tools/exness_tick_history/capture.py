"""Freeze raw MT5 evidence once and replay a bounded, exact offline audit."""

from __future__ import annotations

import hashlib
import re
from collections import Counter
from itertools import zip_longest
from pathlib import Path

from .archive import SourceError
from .compare import PERIOD_MS, capture_path, mcp_bar_rows, mcp_tick_rows, native_ticks, read_mcp_history, split_capture_interval
from .config import validate_symbol
from .sanitize import DAY_MS, day_milliseconds, iso_milliseconds, quote_line, utc_milliseconds
from .storage import StorageError, atomic_json, file_hash, object_hash, read_json

AUDITOR_VERSION = 1
HASH_PATTERN = re.compile(r"[0-9a-f]{64}", re.ASCII)


def wall_milliseconds(text: str) -> int:
    if not isinstance(text, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?", text, re.ASCII):
        raise SourceError("Capture boundaries require explicit ISO wall time without a timezone suffix")
    return utc_milliseconds(text.replace("T", " ") + (".000" if len(text) == 19 else "") + "Z")


def _hash(value):
    if not isinstance(value, str) or not HASH_PATTERN.fullmatch(value):
        raise SourceError("A complete lowercase SHA-256 is required")
    return value


def _layout(manifest: dict, root: Path, *, frozen: bool):
    if type(manifest.get("schema_version")) is not int or manifest["schema_version"] != 1:
        raise SourceError("Unsupported capture manifest schema")
    if frozen and "bars" not in manifest:
        raise SourceError("Frozen capture requires an explicit timeframe map")
    symbol = validate_symbol(manifest.get("symbol"))
    start, end = (wall_milliseconds(manifest.get(key)) for key in ("requested_from", "requested_to"))
    if start >= end:
        raise SourceError("Capture range must be nonempty and half-open")
    entries, bars = manifest.get("entries"), manifest.get("bars", {})
    if not isinstance(entries, list) or not 1 <= len(entries) <= 100000 or not isinstance(bars, dict) or set(bars) - PERIOD_MS.keys():
        raise SourceError("Invalid capture tick entries or timeframe map")
    cursor, paths = start, set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise SourceError("Capture entries must be objects")
        left, right = (wall_milliseconds(entry.get(key)) for key in ("start", "end"))
        if left != cursor or not left < right <= end:
            raise SourceError("Capture intervals must cover the requested range without gaps, overlaps or reordering")
        cursor = right
        if type(entry.get("rows")) is not int or entry["rows"] < 0 or type(entry.get("limit")) is not int or entry["limit"] <= 0:
            raise SourceError("Tick entries require observed row counts and positive reader limits")
    if cursor != end:
        raise SourceError("Capture does not reach the requested end")
    for period, entry in bars.items():
        if not isinstance(entry, dict):
            raise SourceError("Bar entries must be objects")
        if (wall_milliseconds(entry.get("start")), wall_milliseconds(entry.get("end"))) != (start, end):
            raise SourceError("Bar requests must cover the same range as the ticks")
        if start % PERIOD_MS[period] or end % PERIOD_MS[period]:
            raise SourceError("Capture boundaries must align with each supplied bar timeframe")
        if type(entry.get("rows")) is not int or entry["rows"] < 0:
            raise SourceError("Bar entries require observed row counts")
        if entry.get("limit") is not None and (type(entry["limit"]) is not int or entry["limit"] <= 0):
            raise SourceError("A recorded bar reader limit must be positive")
    for entry in [*entries, *bars.values()]:
        path = capture_path(root, entry.get("path"))
        if path in paths:
            raise SourceError("Each response file must belong to exactly one request")
        paths.add(path)
        if frozen:
            _hash(entry.get("sha256"))
    return symbol, start, end


def freeze_capture(request_path: Path, output: Path) -> dict:
    """Seal supplied request metadata and raw bytes; do not assert acceptance."""
    if request_path.parent.resolve() != output.parent.resolve() or request_path.resolve() == output.resolve():
        raise SourceError("Write a separate frozen manifest beside the capture request manifest")
    request = read_json(request_path)
    symbol, _, _ = _layout(request, request_path.parent, frozen=False)

    def seal(entry, period):
        rows, digest = read_mcp_history(capture_path(request_path.parent, entry["path"]), symbol, period)
        if len(rows) != entry["rows"]:
            raise SourceError("Observed response count differs from the request manifest")
        return {key: entry[key] for key in ("path", "start", "end", "rows")} | {"limit": entry.get("limit"), "sha256": digest}

    result = {"schema_version": 1, "kind": "MT5_MCP_CAPTURE", "symbol": symbol,
              "timestamp_basis": "MT5_WALL_TIME", "requested_from": request["requested_from"], "requested_to": request["requested_to"],
              "request_manifest_sha256": file_hash(request_path),
              "entries": [seal(entry, "tick") for entry in request["entries"]],
              "bars": {period: seal(entry, period) for period, entry in sorted(request.get("bars", {}).items())}}
    result["manifest_sha256"] = object_hash(result)
    atomic_json(output, result, immutable=True)
    return result


class BarAudit:
    """Keep one current Bid candle per timeframe, including every quoted tick."""

    def __init__(self, rows, period, start, end, score_start):
        self.reader = iter(mcp_bar_rows(rows, period))
        self.period, self.start, self.end, self.score_start = period, start, end, score_start
        self.current = None
        self.expected = self.actual = self.mismatches = self.prior = self.scored = 0
        self.examples = []

    def compare(self, expected, actual):
        self.expected += int(expected is not None)
        self.actual += int(actual is not None)
        if actual is not None:
            if not self.start <= actual[0] < self.end:
                raise SourceError("Native bar falls outside its captured interval")
            self.prior += int(self.score_start is not None and actual[0] + PERIOD_MS[self.period] <= self.score_start)
            self.scored += int(self.score_start is not None and self.score_start <= actual[0] < self.score_start + DAY_MS)
        if expected != actual:
            self.mismatches += 1
            if len(self.examples) < 5:
                self.examples.append({"row": max(self.expected, self.actual), "expected": _text_row(expected), "actual": _text_row(actual)})

    def add(self, tick):
        stamp, bid, _ = tick
        opened = stamp // PERIOD_MS[self.period] * PERIOD_MS[self.period]
        if self.current is None or self.current[0] != opened:
            if self.current is not None:
                self.compare(tuple(self.current), next(self.reader, None))
            self.current = [opened, bid, bid, bid, bid, 1]
        else:
            self.current[2] = max(self.current[2], bid)
            self.current[3] = min(self.current[3], bid)
            self.current[4] = bid
            self.current[5] += 1

    def finish(self):
        if self.current is not None:
            self.compare(tuple(self.current), next(self.reader, None))
        for actual in self.reader:
            self.compare(None, actual)
        return {"status": "FAIL" if self.mismatches else "PASS" if self.expected else "INCONCLUSIVE",
                "tick_derived_bars": self.expected, "native_bars": self.actual, "ohlc_or_tick_volume_mismatches": self.mismatches,
                "first_mismatches": self.examples, "prior_completed_bars": self.prior if self.score_start is not None else None,
                "scored_bars": self.scored if self.score_start is not None else None}


def _text_row(row):
    return [str(value) for value in row] if row is not None else None


def audit_capture(manifest_path: Path, *, expected_ticks: Path | None = None, expected_sha256: str | None = None,
                  encoding: str = "utf-8-sig", score_day: str | None = None) -> dict:
    result = {"auditor_version": AUDITOR_VERSION, "capture_audit": "INCONCLUSIVE", "capture_integrity": "INCONCLUSIVE",
              "tick_equality": "INCONCLUSIVE" if expected_ticks else "NOT_REQUESTED", "native_bars": {}, "errors": [], "unresolved": [],
              "timestamp_policy": "Literal supplied wall time; no shifts, rounding, sorting, gap filling or duplicate removal",
              "scope": "Frozen capture integrity and optional TSV equality only; broker/feed/specification acceptance is separate",
              "broker_comparison": "INCONCLUSIVE", "score_day": score_day,
              "expected_encoding": encoding if expected_ticks else None,
              "implementation_sha256": object_hash({path.name: file_hash(path) for path in sorted(Path(__file__).parent.glob("*.py"))})}
    try:
        manifest = read_json(manifest_path)
        digest = object_hash({key: value for key, value in manifest.items() if key != "manifest_sha256"})
        if (manifest.get("kind") != "MT5_MCP_CAPTURE" or manifest.get("timestamp_basis") != "MT5_WALL_TIME"
                or digest != _hash(manifest.get("manifest_sha256"))):
            raise SourceError("Frozen capture manifest identity or checksum mismatch")
        _hash(manifest.get("request_manifest_sha256"))
        symbol, start, end = _layout(manifest, manifest_path.parent, frozen=True)
        result.update(symbol=symbol, capture_manifest_sha256=digest, requested_from=manifest["requested_from"], requested_to=manifest["requested_to"])
        score_start = None
        if score_day is not None:
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", score_day, re.ASCII):
                raise SourceError("Scored day must use YYYY-MM-DD")
            score_start = day_milliseconds(score_day)
            if not start <= score_start < score_start + DAY_MS <= end:
                raise SourceError("Capture must include the whole scored day")
        recapture = []
        for entry in manifest["entries"]:
            if entry["rows"] >= entry["limit"]:
                left, right = wall_milliseconds(entry["start"]), wall_milliseconds(entry["end"])
                intervals = split_capture_interval(left, right, entry["rows"], entry["limit"]) if right - left > 1 else []
                recapture.append({"path": entry["path"], "reason": "READER_LIMIT_REACHED",
                                  "intervals": [[iso_milliseconds(a)[:-1], iso_milliseconds(b)[:-1]] for a, b in intervals],
                                  "native_export_required": not intervals})
        for period, entry in manifest["bars"].items():
            if entry.get("limit") is not None and entry["rows"] >= entry["limit"]:
                recapture.append({"path": entry["path"], "period": period, "reason": "BAR_READER_LIMIT_REACHED"})
        if recapture:
            result.update(recapture_requests=recapture, unresolved=["Potentially truncated capture; split requests without splitting tied timestamps"])
            return result
        if expected_ticks is not None:
            if file_hash(expected_ticks) != _hash(expected_sha256):
                raise SourceError("Expected TSV checksum mismatch")
            result["expected_ticks_sha256"] = expected_sha256
        elif expected_sha256 is not None:
            raise SourceError("Expected checksum requires an expected TSV")
        bar_audits = {}
        for period in PERIOD_MS:
            entry = manifest["bars"].get(period)
            if entry is None:
                result["native_bars"][period] = {"status": "INCONCLUSIVE"}
                result["unresolved"].append(period + "_native_bars_missing")
                continue
            rows, _ = read_mcp_history(capture_path(manifest_path.parent, entry["path"]), symbol, period, entry["sha256"])
            if len(rows) != entry["rows"]:
                raise SourceError("Native bar count differs from the frozen manifest")
            bar_audits[period] = BarAudit(rows, period, start, end, score_start)
        native_count = expected_count = mismatches = ties = 0
        previous, first = None, None
        native_hash, expected_hash = hashlib.sha256(), hashlib.sha256()
        days, examples, empty_intervals = Counter(), [], []

        def captured_ticks():
            for entry in manifest["entries"]:
                rows, _ = read_mcp_history(capture_path(manifest_path.parent, entry["path"]), symbol, "tick", entry["sha256"])
                if len(rows) != entry["rows"]:
                    raise SourceError("Native tick count differs from the frozen manifest")
                left, right = wall_milliseconds(entry["start"]), wall_milliseconds(entry["end"])
                if not rows:
                    empty_intervals.append({"start": entry["start"], "end": entry["end"]})
                for tick in mcp_tick_rows(rows):
                    if not left <= tick[0] < right:
                        raise SourceError("Tick falls outside its requested half-open interval")
                    yield tick

        expected_reader = native_ticks(expected_ticks, encoding=encoding) if expected_ticks else ()
        for expected, actual in zip_longest(expected_reader, captured_ticks()):
            if expected is not None:
                if not start <= expected[0] < end:
                    raise SourceError("Expected TSV contains ticks outside the capture range")
                expected_count += 1
                expected_hash.update(quote_line(*expected))
            if actual is not None:
                stamp = actual[0]
                if previous is not None and stamp < previous:
                    raise SourceError("Native tick order regresses between response files")
                native_count += 1
                ties += int(stamp == previous)
                first = stamp if first is None else first
                previous = stamp
                native_hash.update(quote_line(*actual))
                days[stamp // DAY_MS] += 1
                for audit in bar_audits.values():
                    audit.add(actual)
            if expected_ticks and expected != actual:
                mismatches += 1
                if len(examples) < 5:
                    examples.append({"row": max(expected_count, native_count), "expected": _text_row(expected), "actual": _text_row(actual)})
        if expected_ticks is not None and file_hash(expected_ticks) != expected_sha256:
            raise SourceError("Expected TSV changed during the audit")
        result.update(capture_integrity="PASS", native_rows=native_count, expected_rows=expected_count if expected_ticks else None,
                      mismatched_tick_rows=mismatches if expected_ticks else None, first_tick_mismatches=examples,
                      adjacent_equal_time_rows=ties, first_msc=first, last_msc=previous,
                      native_ordered_quote_sha256=native_hash.hexdigest(),
                      expected_ordered_quote_sha256=expected_hash.hexdigest() if expected_ticks else None,
                      rows_per_day={iso_milliseconds(day * DAY_MS)[:10]: count for day, count in sorted(days.items())},
                      empty_intervals=empty_intervals)
        if expected_ticks:
            result["tick_equality"] = "FAIL" if mismatches else "PASS" if expected_count else "INCONCLUSIVE"
        if empty_intervals:
            result["empty_interval_evidence"] = ("Exact supplied TSV equality; no market-closure assertion" if result["tick_equality"] == "PASS"
                                                  else "Unexplained by independent source equality")
            if result["tick_equality"] != "PASS":
                result["unresolved"].append("unexplained_empty_tick_intervals")
        for period, audit in bar_audits.items():
            result["native_bars"][period] = audit.finish()
            if score_start is not None and (audit.prior < 26 or audit.scored == 0):
                result["unresolved"].append(period + "_warmup_or_scored_bars_incomplete")
        if not native_count:
            result["unresolved"].append("no_tick_support")
        failed = result["tick_equality"] == "FAIL" or any(item["status"] == "FAIL" for item in result["native_bars"].values())
        result["capture_audit"] = "FAIL" if failed else "INCONCLUSIVE" if result["unresolved"] or not native_count else "PASS"
    except (SourceError, StorageError, OSError, ValueError) as exc:
        result.update(capture_audit="FAIL", capture_integrity="FAIL")
        result["errors"].append(str(exc) if isinstance(exc, (SourceError, StorageError)) else "Invalid or unavailable local capture input")
    return result
