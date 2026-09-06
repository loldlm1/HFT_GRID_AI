"""Native six-field tick packages under a frozen specification and clock map."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal, localcontext

from .archive import PRICE_PATTERN, SourceError
from .config import Profile, validate_symbol
from .report import load_dataset
from .sanitize import EPOCH, connection, exact_price, iter_ticks, quote_line, utc_milliseconds
from .storage import Store, StorageError, atomic_json, feed_identity, file_hash, identifier, object_hash, read_json

TICK_HEADER = "<DATE>\t<TIME>\t<BID>\t<ASK>\t<LAST>\t<VOLUME>\n"
SPEC_PROPERTIES = {"digits", "point", "tick_size", "tick_value", "chart_mode", "contract_size", "currency_base",
                   "currency_profit", "currency_margin", "calculation_mode", "volume_min", "volume_max", "volume_step",
                   "margin_initial", "margin_maintenance", "stops_level", "freeze_level", "quote_sessions", "trade_sessions"}


@dataclass(frozen=True)
class ClockMap:
    periods: tuple[tuple[int, int, int], ...]
    raw: dict

    @classmethod
    def parse(cls, raw: dict):
        if (type(raw.get("schema_version")) is not int or raw.get("schema_version") != 1 or raw.get("operator_verified") is not True
                or not raw.get("evidence_id") or not isinstance(raw.get("periods"), list)
                or not 1 <= len(raw["periods"]) <= 1000):
            raise SourceError("Clock mapping requires explicit verified periods and evidence")
        identifier(raw["evidence_id"])
        periods = []
        for period in raw["periods"]:
            if not isinstance(period, dict) or set(period) != {"start_utc", "end_utc", "offset_seconds"}:
                raise SourceError("Invalid clock period fields")
            if not all(isinstance(period[key], str) for key in ("start_utc", "end_utc")):
                raise SourceError("Clock boundaries require UTC millisecond strings")
            start = utc_milliseconds(period["start_utc"].replace("T", " "))
            end = utc_milliseconds(period["end_utc"].replace("T", " "))
            seconds = period["offset_seconds"]
            if type(seconds) is not int or abs(seconds) > 14 * 3600 or start >= end:
                raise SourceError("Invalid clock interval or offset")
            offset = seconds * 1000
            if periods and (periods[-1][1] != start or periods[-1][1] + periods[-1][2] > start + offset):
                raise SourceError("Clock mapping is discontinuous, ambiguous or non-monotonic")
            periods.append((start, end, offset))
        return cls(tuple(periods), raw)

    def forward(self, utc_msc: int) -> int:
        for start, end, offset in self.periods:
            if start <= utc_msc < end:
                return utc_msc + offset
        raise SourceError("Tick is outside the verified clock regimes")

    def inverse(self, broker_msc: int) -> int:
        for start, end, offset in self.periods:
            if start + offset <= broker_msc < end + offset:
                return broker_msc - offset
        raise SourceError("Broker time has no unambiguous verified UTC mapping")


def validate_specification(raw: dict, profile: Profile) -> dict:
    if (type(raw.get("schema_version")) is not int or raw.get("schema_version") != 1 or raw.get("operator_verified") is not True
            or raw.get("feed_sha256") != object_hash(feed_identity(profile))
            or raw.get("broker_symbol") != profile.instrument.broker_symbol
            or not raw.get("evidence_id") or not isinstance(raw.get("properties"), dict)):
        raise SourceError("Specification requires a verified snapshot for this exact profile/feed")
    identifier(raw["evidence_id"])
    if not isinstance(raw.get("captured_at_utc"), str):
        raise SourceError("Specification capture time is required")
    utc_milliseconds(raw["captured_at_utc"].replace("T", " "))
    props = raw["properties"]
    if not SPEC_PROPERTIES <= props.keys():
        raise SourceError("Specification snapshot is missing required broker properties")
    digits = props["digits"]
    if type(digits) is not int or not 0 <= digits <= 12 or props["chart_mode"] != "bid":
        raise SourceError("Unsupported digits or chart mode; quote-derived Bid bars are required")
    for key in ("point", "tick_size", "tick_value", "contract_size", "volume_min", "volume_max", "volume_step"):
        if not isinstance(props[key], str):
            raise SourceError("Specification exact numbers must be decimal strings")
        exact_price(props[key])
    with localcontext() as context:
        context.prec = 50
        point = Decimal(props["point"])
        if point != Decimal(1).scaleb(-digits) or Decimal(props["tick_size"]) % point:
            raise SourceError("Specification digits, point and positive trade-tick grid disagree")
    if Decimal(props["volume_max"]) < Decimal(props["volume_min"]):
        raise SourceError("Invalid symbol volume limits")
    for key in ("currency_base", "currency_profit", "currency_margin", "calculation_mode"):
        if not isinstance(props[key], str) or not props[key]:
            raise SourceError("Incomplete symbol calculation/currency specification")
    for key in ("margin_initial", "margin_maintenance"):
        value = props[key]
        if not isinstance(value, str) or len(value) > 64 or not PRICE_PATTERN.fullmatch(value):
            raise SourceError("Invalid margin specification")
        if Decimal(value) != 0:
            exact_price(value)
    for key in ("stops_level", "freeze_level"):
        if type(props[key]) is not int or props[key] < 0:
            raise SourceError("Invalid stops/freeze specification")
    for key in ("quote_sessions", "trade_sessions"):
        if not isinstance(props[key], list) or not props[key]:
            raise SourceError("Explicit native session snapshot is required")
        for session in props[key]:
            if (not isinstance(session, dict) or set(session) != {"weekday", "from_seconds", "to_seconds"}
                    or any(type(value) is not int for value in session.values())
                    or not 0 <= session["weekday"] <= 6
                    or not 0 <= session["from_seconds"] < session["to_seconds"] <= 86400):
                raise SourceError("Sessions use weekday 0=Monday and nonempty intervals within one day")
    if (not isinstance(raw.get("existing_symbols"), list)
            or profile.instrument.broker_symbol not in raw["existing_symbols"]
            or any(not isinstance(value, str) for value in raw["existing_symbols"])):
        raise SourceError("A captured symbol-name inventory is required for collision checking")
    return raw


def compatible_quote(bid: Decimal, ask: Decimal, spec: dict) -> None:
    props = spec["properties"]
    digits, tick = props["digits"], Decimal(props["tick_size"])
    with localcontext() as context:
        context.prec = 50
        for value in (bid, ask):
            if value <= 0 or value % tick or value != value.quantize(Decimal(1).scaleb(-digits)):
                raise SourceError("Historical quote is incompatible with target digits/trade-tick grid; no rounding applied")
            # MT5 stores doubles. Verify the native displayed precision can retain this decimal quote.
            if Decimal(format(float(value), f".{digits}f")) != value:
                raise SourceError("Quote cannot round-trip through MT5 double storage at the pinned digits")
    if ask < bid:
        raise SourceError("Crossed quote cannot be exported")


def load_export(store: Store, profile: Profile, export_id: str) -> dict:
    result = read_json(store.path("exports", identifier(export_id), "import-manifest.json"))
    if result.get("schema_version") != 1 or result.get("feed") != feed_identity(profile):
        raise StorageError("Export schema or feed mismatch")
    if object_hash({key: value for key, value in result.items() if key != "manifest_sha256"}) != result.get("manifest_sha256"):
        raise StorageError("Export manifest hash mismatch")
    for chunk in result["chunks"]:
        path = store.path("exports", export_id, chunk["filename"])
        if file_hash(path) != chunk["file_sha256"]:
            raise StorageError("Export chunk hash mismatch")
    return result


def export_mt5(profile: Profile, dataset_id: str, export_id: str, spec: dict, clock: dict,
               *, custom_symbol: str | None = None, chunk_rows: int = 1_000_000) -> dict:
    identifier(export_id)
    if export_id.endswith("-partial") or type(chunk_rows) is not int or not 1 <= chunk_rows <= 10_000_000:
        raise SourceError("Invalid export ID or chunk_rows (1..10000000)")
    spec = validate_specification(spec, profile)
    mapping = ClockMap.parse(clock)
    name = validate_symbol(custom_symbol or f"{profile.instrument.base_symbol[:18]}_EXN_{object_hash(export_id)[:8]}")
    if name in spec["existing_symbols"] or name == profile.instrument.broker_symbol:
        raise SourceError("Custom-symbol name collides with an existing symbol")
    if profile.instrument.base_symbol.startswith(("XAU", "XAG", "XPT", "XPD")) and not name.startswith(profile.instrument.base_symbol[:3]):
        raise SourceError("Custom metal symbol must retain its metal prefix for the EA classification")
    with Store(profile.data_root) as store:
        dataset, quality = load_dataset(store, profile, dataset_id)
        if dataset["data_integrity"] == "FAIL" or not dataset["rows"]:
            raise SourceError("Quarantined or empty dataset cannot produce an import package")
        contract = {"dataset_manifest_sha256": dataset["manifest_sha256"], "specification_sha256": object_hash(spec),
                    "clock_sha256": object_hash(clock), "custom_symbol": name, "chunk_rows": chunk_rows, "format_version": 1}
        final = store.path("exports", export_id)
        if final.exists():
            existing = load_export(store, profile, export_id)
            if existing["input_sha256"] != object_hash(contract):
                raise StorageError("Export ID belongs to other inputs; use a new ID and symbol")
            return existing
        stage = store.path("exports", export_id + "-partial")
        stage.mkdir(parents=True, exist_ok=True)
        atomic_json(store.path("exports", stage.name, "input.json"), contract, immutable=True)
        store.disk_check(dataset["rows"] * 160, profile.limits.disk_reserve_bytes)
        con = connection(profile, store.path("exports", stage.name, "spill"))
        chunks, stream, chunk, previous, count = [], None, None, None, 0
        ordered = hashlib.sha256()
        chunk_digest = None

        def close_chunk():
            if stream is not None:
                stream.flush()
                os.fsync(stream.fileno())
                stream.close()
                chunk["logical_sha256"] = chunk_digest.hexdigest()
                chunk["file_sha256"] = file_hash(store.path("exports", stage.name, chunk["filename"]))
                chunks.append(chunk)

        try:
            for part in dataset["parts"]:
                path = store.path("datasets", dataset_id, "date=" + part["date"], "ticks.parquet")
                if file_hash(path) != part["file_sha256"]:
                    raise StorageError("Dataset partition checksum mismatch")
                for row in iter_ticks(con, path):
                    utc_stamp, bid, ask = row[:3]
                    compatible_quote(bid, ask, spec)
                    stamp = mapping.forward(utc_stamp)
                    if previous is not None and stamp < previous:
                        raise SourceError("Export mapping regressed; no import package published")
                    if stream is None or chunk["rows"] >= chunk_rows and stamp != previous:
                        close_chunk()
                        filename = f"ticks-{len(chunks):06d}.tsv"
                        stream = store.path("exports", stage.name, filename).open("w", encoding="ascii", newline="")
                        stream.write(TICK_HEADER)
                        chunk = {"filename": filename, "rows": 0, "first_mapped_msc": stamp, "last_mapped_msc": stamp}
                        chunk_digest = hashlib.sha256()
                    formatted = EPOCH + timedelta(milliseconds=stamp)
                    line = f"{formatted:%Y.%m.%d}\t{formatted:%H:%M:%S}.{stamp % 1000:03d}\t{bid:.{spec['properties']['digits']}f}\t{ask:.{spec['properties']['digits']}f}\t0\t0\n"
                    stream.write(line)
                    logical = quote_line(stamp, bid, ask)
                    ordered.update(logical)
                    chunk_digest.update(logical)
                    count += 1
                    chunk["rows"] += 1
                    chunk["last_mapped_msc"] = stamp
                    previous = stamp
                    if count % 65536 == 0:
                        store.disk_check(1024 * 1024, profile.limits.disk_reserve_bytes)
            close_chunk()
        finally:
            if stream is not None and not stream.closed:
                stream.close()
            con.close()
        if count != dataset["rows"]:
            raise StorageError("Export row conservation failed")
        result = {"schema_version": 1, "export_id": export_id, "dataset_id": dataset_id, "feed": feed_identity(profile),
                  **contract, "input_sha256": object_hash(contract), "specification": spec, "clock": clock,
                  "format": {"encoding": "ascii", "separator": "TAB", "skip_header_rows": 1, "shift": 0,
                             "fields": TICK_HEADER.strip().split("\t"), "last_volume": "source_unsupplied_zero", "flags": "terminal_calculated"},
                  "chunks": chunks, "rows": count, "ordered_quote_sha256": ordered.hexdigest(),
                  "data_integrity": quality["data_integrity"], "mt5_round_trip": "INCONCLUSIVE",
                  "native_bar_path": "PENDING_OPERATOR", "required_native_periods": ["M1", "M3", "M10", "H1"]}
        result["manifest_sha256"] = object_hash(result)
        atomic_json(store.path("exports", stage.name, "import-manifest.json"), result, immutable=True)
        os.replace(stage, final)
        return result
