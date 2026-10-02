"""Strict, bounded validation of source-candidate continuation segments.

This validates exact wire bytes, typed facts, full state and declared coverage.
It never certifies a producer build, broker/feed equivalence or calendar provenance.
Those independent source-owner receipts remain required before operational intake.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sqlite3
import tempfile
from contextlib import AbstractContextManager
from dataclasses import dataclass
from pathlib import Path

from .clock import analysis_clock
from .continuation_contract import (
    ENGINES, FAMILY, FILES, MAX_PAYLOAD_BYTES, MAX_ROW_BYTES, ORIGIN_POLICIES, VERSION, WITNESS_FILES,
    ZERO, MANIFEST_KEYS_CONTINUATION, PHYSICAL_SUMMARY_KEYS, SEAL_KEYS, TRANSACTION_FIELDS, WITNESS_KEYS,
    descriptor, descriptor_digest, manifest_keys, proof_keys, seal_keys, source_digest,
)
from .native_evidence import VerifiedTesterDelivery
from .reader import ContractError, ModelRun, integer, number, require
from .schema_contract import MANIFEST_KEYS, NULL, PROFILES, SUMMARY_KEYS, SUMMARY_CLOCKS, clock_companions

ID = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9_.-]{0,63}\Z")
HEX = re.compile(r"(?:[0-9a-f]{2})*\Z")
HASH = re.compile(r"[0-9a-f]{64}\Z")



def safe_id(value: str) -> bool:
    return bool(ID.fullmatch(value)) and ".." not in value


def unhex(value: str) -> str:
    if value == "-":
        return ""
    require(isinstance(value, str) and len(value) <= MAX_PAYLOAD_BYTES * 2 and HEX.fullmatch(value),
            "Invalid/bounded hexadecimal cell")
    try:
        return bytes.fromhex(value).decode("utf-8")
    except (ValueError, UnicodeError) as exc:
        raise ContractError("Invalid UTF-8 envelope") from exc


def native_float64(value: str) -> float:
    """Exact finite IEEE754 bits, including DBL_MAX/EMPTY_VALUE and signed zero."""
    require(re.fullmatch(r"[0-9a-f]{16}", value) is not None, "Invalid native float64 bits")
    decoded = struct.unpack(">d", bytes.fromhex(value))[0]
    require(math.isfinite(decoded), "Nonfinite native float64 bits")
    return decoded


def native_text(value: str) -> str | None:
    """Decode only typed MQL5 text; native NULL stays distinct from explicit empty."""
    return None if value == NULL else unhex(value)

def chain(previous: str, raw: bytes) -> str:
    require(bool(HASH.fullmatch(previous)), "Invalid chain digest")
    return hashlib.sha256(bytes.fromhex(previous) + raw).hexdigest()


@dataclass(frozen=True)
class FileProof:
    rows: int
    bytes: int
    chain: str
    sha256: str


def records(path: Path, columns: tuple[str, ...], proofs: dict | None = None):
    require(path.is_file() and not path.is_symlink(), "Expected regular protocol file")
    before = path.stat()
    state, total, count = ZERO, 0, 0
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        header = stream.readline(MAX_ROW_BYTES + 1)
        require(header == ("\t".join(columns) + "\r\n").encode(), "Protocol header mismatch")
        state, total = chain(state, header), len(header)
        sha.update(header)
        while raw := stream.readline(MAX_ROW_BYTES + 1):
            require(len(raw) <= MAX_ROW_BYTES and raw.endswith(b"\r\n"), "Partial/oversized protocol row")
            try:
                values = raw[:-2].decode("utf-8").split("\t")
            except UnicodeError as exc:
                raise ContractError("Invalid protocol UTF-8") from exc
            require(len(values) == len(columns) and all(v != "" and "\x00" not in v and "\r" not in v and "\n" not in v for v in values),
                    "Protocol row width/cell mismatch")
            state, total, count = chain(state, raw), total + len(raw), count + 1
            sha.update(raw)
            yield dict(zip(columns, values, strict=True))
    after = path.stat()
    require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) ==
            (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns), "Protocol source changed")
    if proofs is not None:
        proofs[path.name] = FileProof(count, total, state, sha.hexdigest())


def metadata(path: Path, proofs: dict | None = None) -> dict:
    result = {}
    for row in records(path, ("key", "value"), proofs):
        require(row["key"] not in result, "Duplicate protocol metadata")
        result[row["key"]] = row["value"]
    return result


def expected_proof_keys(files) -> set[str]:
    return set(proof_keys(files))


def verify_proofs(seal: dict, proofs: dict, files):
    for name in files:
        proof = proofs[name]
        require(seal[f"rows_{name}"] == str(proof.rows) and seal[f"bytes_{name}"] == str(proof.bytes)
                and seal[f"chain_{name}"] == proof.chain, "Protocol seal proof mismatch")


@dataclass(frozen=True)
class VerifiedClosure:
    """Caller supplies independently verified calendar/feed evidence, never a source assertion."""
    first_time_msc: int
    last_time_msc: int
    history_proof: str
    calendar_revision: str
    evidence_sha256: str
    clock_basis: str

    def covers(self, first: int, last: int, source: str, basis: str) -> bool:
        return (self.first_time_msc <= first <= last <= self.last_time_msc and
                self.history_proof == source and self.clock_basis == basis and
                safe_id(self.calendar_revision) and bool(HASH.fullmatch(self.evidence_sha256)))



@dataclass(frozen=True)
class VerifiedNativeFence:
    """Trusted source owner supplies a reviewed native receipt; labels alone are not acceptance.

    The terminal broker/journal audit proves the first tester-end effect, including
    forced closes before OnTester. The platform must independently verify the
    receipt and original source. This class only validates its exact wire binding.
    """
    descriptor_sha256: str
    source_proof: str
    configuration_proof: str
    history_proof: str
    core_manifest_sha256: str
    paired_terminal_seal: str
    first_terminal_effect_input_ordinal: int
    last_safe_input_ordinal: int
    evidence_sha256: str

    def verify(self, archive, *, whole=False):
        require(all(bool(HASH.fullmatch(getattr(self, key))) for key in
                    ("descriptor_sha256", "source_proof", "configuration_proof", "history_proof",
                     "core_manifest_sha256", "paired_terminal_seal", "evidence_sha256")),
                "Missing independent native terminal fence receipt")
        m = archive.segments[0]["manifest"]
        if archive.tester_deliveries:
            original = next((p for p in archive.tester_deliveries
                             if p.registration.physical_run_id == m["physical_run_id"]), None)
            require(original is not None, "Registered native fence job missing")
            original.verify_native_fence(self, archive)
        require(all(getattr(self, key) == m[key] for key in
                    ("descriptor_sha256", "source_proof", "configuration_proof", "history_proof", "core_manifest_sha256")),
                "Native terminal fence source/configuration/history binding mismatch")
        require(0 < self.last_safe_input_ordinal < self.first_terminal_effect_input_ordinal,
                "Unproven first native tester-end effect")
        if whole:
            require(archive.segments[-1]["seal"]["completion"] == "TERMINAL" and
                    self.paired_terminal_seal == archive.segments[-1]["proofs"]["segment_seal.tsv"].chain and
                    self.first_terminal_effect_input_ordinal <= archive.last_input + 1,
                    "Substituted whole native terminal evidence")
        else:
            require(0 < archive.last_input <= self.last_safe_input_ordinal,
                    "Checkpoint includes native tester-end effects")

def canonical_state(row: dict) -> bytes:
    return ("\t".join(row[c] for c in FILES["state_checkpoint.tsv"][1:]) + "\r\n").encode()


def validate_state_value(kind: str, value: str):
    if kind == "TEXT":
        native_text(value)
    elif kind == "HASH":
        require(bool(HASH.fullmatch(value)), "Invalid private state digest")
    elif kind == "BOOL":
        require(value in {"0", "1"}, "Invalid state boolean")
    elif kind == "FLOAT64":
        native_float64(value)
    elif kind == "INT":
        integer(value)
    elif kind == "UINT":
        require(re.fullmatch(r"(?:0|[1-9][0-9]{0,19})", value) is not None and int(value) < 2**64,
                "Invalid unsigned state")
    else:
        raise ContractError("Unknown state type")


def validate_fact(row: dict, profile, core: dict) -> tuple[str, dict]:
    tables = {t.name: t for t in profile.tables if t.name not in {"run_manifest.tsv", "run_summary.tsv"}}
    require(row["table_name"] in tables, "Unknown exact engine table")
    table = tables[row["table_name"]]
    payload = unhex(row["payload_hex"])
    require(len(payload.encode()) <= MAX_PAYLOAD_BYTES and "\r" not in payload and "\n" not in payload and "\x00" not in payload,
            "Invalid canonical fact payload")
    values = payload.split("\t")
    require(len(values) == len(table.fields), "Canonical typed fact width")
    for field, value in zip(table.fields, values, strict=True):
        require(value != "" and len(value) <= 65536, "Invalid canonical fact cell")
        if value == NULL:
            require(field.nullable, "Required canonical fact is null")
        elif field.type in {"int", "clock"}:
            integer(value)
        elif field.type == "decimal":
            number(value)
        elif field.type == "bool":
            require(value in {"0", "1"}, "Invalid canonical fact boolean")
        require(value == NULL or not field.choices or value in field.choices, "Unknown canonical fact value")
    fact = {f.name: None if value == NULL else value for f, value in zip(table.fields, values, strict=True)}
    require(fact["run_id"] == core["run_id"] and unhex(row["row_key"]) == fact[table.key], "Unmapped canonical fact identity")
    for field in table.clocks:
        companions = clock_companions(field.name)
        if fact[field.name] is None:
            require(all(fact[n] is None for n in companions), "Partial canonical clock")
        else:
            raw = integer(fact[field.name])
            expected, offset = analysis_clock(raw, core["broker_session"])
            require(fact[companions[0]] == str(expected) and fact[companions[1]] == str(offset), "Canonical analysis clock mismatch")
            require(fact[companions[2]] in {"SECOND", "MILLISECOND"} and
                    (fact[companions[2]] != "SECOND" or raw % 1000 == 0), "Canonical precision mismatch")
    return payload, fact


class ContinuationArchive(AbstractContextManager):
    """Disk-indexed explicit ordered chain. No schema inference or path discovery."""

    def __init__(self, paths, *, closures=(), tester_deliveries=()):
        self.paths = [Path(p) for p in paths]
        self.closures = tuple(closures)
        self.tester_deliveries = tuple(tester_deliveries)
        self.temp = None
        self.db = None
        self.segments = []
        self.identity = None
        self.core = None
        self.profile = None
        self.last_input = self.last_fact = self.last_birth = self.last_record = 0
        self.previous_state = None
        self.anchor_state = None
        self.last_observer = None
        self.last_monotonic = None
        self.last_physical_run = None
        self.input_physical_run = None
        self.last_history_count = 0
        self.last_history_chain = ZERO
        self.contract = descriptor()

    def __enter__(self):
        require(bool(self.paths), "Missing explicit continuation chain")
        self.temp = tempfile.TemporaryDirectory(prefix="model-continuation-")
        self.db = sqlite3.connect(Path(self.temp.name) / "index.sqlite3")
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA cache_size=-8192")
        self.db.execute("PRAGMA temp_store=FILE")
        self.db.executescript("""
            CREATE TABLE facts (table_name TEXT, row_key TEXT, ordinal INTEGER PRIMARY KEY,
              input_ordinal INTEGER, phase TEXT, payload TEXT, observed_time TEXT);
            CREATE INDEX fact_key ON facts(table_name,row_key);
            CREATE TABLE births (window_id TEXT PRIMARY KEY,payload TEXT,ordinal INTEGER,input_ordinal INTEGER);
            CREATE TABLE states (segment INTEGER,boundary TEXT,component TEXT,object_id TEXT,
              field TEXT,kind TEXT,value TEXT, PRIMARY KEY(segment,boundary,component,object_id,field));
        """)
        try:
            for path in self.paths:
                self._segment(path)
            self._verify_native_delivery()
            self._references()
            self.db.commit()
        except Exception:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if self.db:
            self.db.close()
            self.db = None
        if self.temp:
            self.temp.cleanup()
            self.temp = None

    def _verify_native_delivery(self):
        if self.identity[1] != "TESTER":
            require(not self.tester_deliveries, "Wrong-origin native tester evidence")
            return
        require(self.tester_deliveries and all(type(p) is VerifiedTesterDelivery and p.is_authenticated() for p in self.tester_deliveries),
                "Authenticated native tester delivery registry proof required")
        indexed = {p.registration.physical_run_id: p for p in self.tester_deliveries}
        require(len(indexed) == len(self.tester_deliveries) and
                set(indexed) == {s["manifest"]["physical_run_id"] for s in self.segments},
                "Missing/duplicate/wrong native job registration")
        for proof in self.tester_deliveries:
            proof.verify_unchanged()
        for segment in self.segments:
            indexed[segment["manifest"]["physical_run_id"]].verify_segment(
                segment["manifest"], segment["proofs"], segment["seal"])

    def _manifest(self, m: dict, path: Path):
        require(set(m) == set(manifest_keys()),
                "Continuation manifest key mismatch")
        require(m["family"] == FAMILY and m["continuation_version"] == VERSION and
                m["descriptor_sha256"] == descriptor_digest() and m["engine"] in ENGINES, "Unsupported continuation tuple")
        for field in ("source_id", "session_id", "physical_run_id", "canonical_run_id"):
            require(safe_id(m[field]), "Unsafe continuation identity")
        require(m["canonical_run_id"] == m["session_id"], "Missing explicit canonical session mapping")
        for field in ("source_proof", "configuration_proof", "history_proof", "core_manifest_sha256"):
            require(bool(HASH.fullmatch(m[field])), "Missing independent source/configuration/history pin")
        require(m["origin"] in {"TESTER", "LIVE_DEMO"} and integer(m["segment_seconds"]) in {3600, 14400, 86400},
                "Unsupported capture origin/interval")
        require(all(m[key] == value for key, value in ORIGIN_POLICIES[m["origin"]].items()) and
                m["segment_phase"] in {"CAPTURE", "TERMINAL"}, "Unsupported acquisition/clock/source-quality policy")
        require(integer(m["session_schedule_observed_time_msc"]) > 0, "Missing native session observation clock")
        for key in ("weekly_quote_sessions_hex", "weekly_trade_sessions_hex"):
            values = unhex(m[key]).split("\t") if m[key] != "-" else []
            require(len(values) % 4 == 0 and len(values) <= 7 * 16 * 4, "Invalid bounded native weekly sessions")
            for index in range(0, len(values), 4):
                require(0 <= integer(values[index]) < 7 and 0 <= integer(values[index + 1]) < 16 and
                        integer(values[index + 2]) >= 0 and integer(values[index + 3]) >= 0, "Invalid native session sample")
        core_raw = "".join(key.removeprefix("core_") + "\t" + value + "\r\n"
                           for key, value in m.items() if key.removeprefix("core_") in MANIFEST_KEYS and key.startswith("core_"))
        require(hashlib.sha256(core_raw.encode()).hexdigest() == m["core_manifest_sha256"] ==
                m["configuration_proof"], "Observed configuration hash mismatch")
        require(m["source_proof"] == source_digest(), "Unproved source-owned semantic byte pin")
        core = {key: m["core_" + key] for key in MANIFEST_KEYS}
        probe = ModelRun(Path(m["session_id"]))
        probe.manifest = core
        probe._manifest()
        require(core["engine"] == m["engine"] and core["run_id"] == m["session_id"], "Core profile/session mismatch")
        require(m["replay_witness_id"] == NULL or safe_id(m["replay_witness_id"]), "Unsafe replay witness identity")
        require((m["replay_witness_id"] == NULL) == (m["replay_witness_proof"] == NULL), "Partial replay witness binding")
        if m["replay_witness_proof"] != NULL:
            require(m["origin"] == "TESTER" and bool(HASH.fullmatch(m["replay_witness_proof"])), "Unsupported replay origin/pin")
        identity = tuple(m[key] for key in ("engine", "origin", "source_id", "session_id", "source_proof",
                                           "configuration_proof", "history_proof", "core_manifest_sha256"))
        if self.identity is None:
            require(m["predecessor_seal"] == "NONE" and m["predecessor_state_sha256"] == "NONE" and m["replay_witness_id"] == NULL,
                    "Archive requires original anchor, never an inferred predecessor")
            self.identity, self.core, self.profile = identity, core, probe.profile
        else:
            require(identity == self.identity and core == self.core, "Changed source/profile/configuration/session")
            previous = self.segments[-1]
            require(previous["seal"]["completion"] in {"ROTATED", "PRE_FINALIZATION"} and
                    m["predecessor_seal"] == previous["proofs"]["segment_seal.tsv"].chain and
                    m["predecessor_state_sha256"] == previous["seal"]["end_state_sha256"], "Fork/substituted/terminal predecessor")
            if previous["seal"]["completion"] == "PRE_FINALIZATION":
                require(m["segment_phase"] == "TERMINAL" and m["physical_run_id"] == self.last_physical_run,
                        "Pre-finalization state cannot authorize continued capture")
            if m["physical_run_id"] != self.last_physical_run:
                require(m["origin"] == "TESTER" and m["replay_witness_id"] != NULL, "Unproven native restart")
        require(path.name == f'{integer(m["segment_ordinal"]):08d}', "Segment directory identity mismatch")
        if self.last_physical_run == m["physical_run_id"]:
            require(integer(m["segment_ordinal"]) == integer(self.segments[-1]["manifest"]["segment_ordinal"]) + 1,
                    "Nonconsecutive physical segment")
        else:
            require(integer(m["segment_ordinal"]) == 1, "Fresh physical run must start at segment one")
        if m["segment_phase"] == "TERMINAL":
            require(bool(self.segments) and self.segments[-1]["seal"]["completion"] == "PRE_FINALIZATION",
                    "Terminal branch requires explicit pre-finalization predecessor")
        elif self.segments:
            require(self.segments[-1]["seal"]["completion"] == "ROTATED", "Capture cannot extend terminal branch")
        return core

    def _segment(self, path: Path):
        require(path.is_dir() and not path.is_symlink() and all(not p.is_symlink() for p in path.parents),
                "Expected owned regular segment path")
        require({p.name for p in path.iterdir()} == set(FILES) and all(p.is_file() and not p.is_symlink() for p in path.iterdir()),
                "Exact six-file inventory required")
        proofs = {}
        m = metadata(path / "segment_manifest.tsv", proofs)
        self._manifest(m, path)
        seal = metadata(path / "segment_seal.tsv", proofs)
        completion = seal.get("completion")
        require(completion in {"ROTATED", "PRE_FINALIZATION", "TERMINAL", "INTERRUPTED"} and
                set(seal) == set(seal_keys(self.profile.engine, completion)), "Segment seal key/status mismatch")
        require((m["segment_phase"] == "TERMINAL") == (seal["completion"] in {"TERMINAL", "INTERRUPTED"}), "Unclassified terminal segment")
        starts = {
            "input": self.last_input, "fact": self.last_fact, "birth": self.last_birth, "record": self.last_record,
        }
        for kind, previous in starts.items():
            require(integer(seal[f"first_{kind}_ordinal"]) == previous + 1, "Unproven prefix/suppression cursor")
        self._inputs(path, m, proofs)
        self._births(path, proofs, starts["input"] + 1)
        self._facts(path, proofs, terminal=m["segment_phase"] == "TERMINAL", first_input=starts["input"] + 1)
        start_state, end_state = self._state(path, proofs, len(self.segments), completion)
        require(end_state == seal["end_state_sha256"], "END state digest mismatch")
        if self.previous_state is not None:
            require(start_state == self.previous_state, "Reset/omitted/reordered boundary state")
            require(self.db.execute("""
                SELECT component,object_id,field,kind,value FROM states WHERE segment=? AND boundary='START'
                EXCEPT SELECT component,object_id,field,kind,value FROM states WHERE segment=? AND boundary='END'
            """, (len(self.segments), len(self.segments) - 1)).fetchone() is None, "Boundary state byte mismatch")
        else:
            self.anchor_state = start_state
        self.previous_state = end_state
        for kind in starts:
            require(integer(seal[f"last_{kind}_ordinal"]) == getattr(self, "last_" + kind), "Segment ordinal/count mismatch")
        if self.last_input:
            row = self._last_input_row
            require(seal["input_chain_sha256"] == row["input_chain_sha256"], "Complete input prefix mismatch")
        else:
            require(seal["input_chain_sha256"] == ZERO, "Invented empty input prefix")
        verify_proofs(seal, proofs, list(FILES)[:-1])
        self.segments.append({"path": path, "manifest": m, "seal": seal, "proofs": proofs,
                              "start_state": start_state, "end_state": end_state})
        self.last_physical_run = m["physical_run_id"]
        self.db.commit()

    def _inputs(self, path, m, proofs):
        basis = "BROKER" if m["origin"] == "TESTER" else "UTC"
        for row in records(path / "input_events.tsv", FILES["input_events.tsv"], proofs):
            first, last = integer(row["first_input_ordinal"]), integer(row["last_input_ordinal"])
            require(integer(row["record_ordinal"]) == self.last_record + 1 and first == self.last_input + 1 and last >= first,
                    "Dropped/repeated canonical input ordinal")
            total = integer(row["input_count"])
            require(0 < total <= 65536 and total == last - first + 1 and
                    total == sum(integer(row[k]) for k in ("tick_count", "timer_count", "trade_count")) and
                    total == integer(row["available_count"]) + integer(row["unavailable_count"]), "Incomplete canonical input accounting")
            require(all(integer(row[k]) >= 0 for k in ("tick_count", "timer_count", "trade_count", "available_count")) and
                    integer(row["unavailable_count"]) >= 0, "Invalid actual capture accounting")
            require(row["boundary_callback"] in {"TIMER", "TRADE", "BOUNDARY"} and
                    row["connected"] in {"0", "1"} and row["synchronized"] in {"0", "1"} and
                    row["acquisition"] in {("TESTER_CALLBACK_ACQUIRED" if m["origin"] == "TESTER" else "FRESH_CALLBACK_STREAM"), "UNAVAILABLE"} and
                    bool(HASH.fullmatch(row["input_chain_sha256"])), "Missing acquisition/input proof")
            require(row["boundary_callback"] != "TIMER" or integer(row["timer_count"]) > 0, "Invented heartbeat")
            require(row["boundary_callback"] != "TRADE" or integer(row["trade_count"]) > 0, "Invented transaction observation")
            require(0 < integer(row["first_broker_time_msc"]) <= integer(row["last_broker_time_msc"]), "Invalid broker input bounds")
            quote = unhex(row["quote_hex"]).split("\t")
            require(len(quote) == 8 and integer(quote[0]) > 0 and integer(quote[1]) >= integer(quote[0]) * 1000,
                    "Invalid acquired quote proof")
            bid, ask, _last = (native_float64(value) for value in quote[2:5])
            require(bid > 0 and ask >= bid, "Invalid acquired quote")
            require(re.fullmatch(r"(?:0|[1-9][0-9]{0,19})", quote[5]) is not None and int(quote[5]) < 2**64,
                    "Invalid quote volume")
            native_float64(quote[6]); integer(quote[7])
            transaction = unhex(row["transaction_hex"])
            if transaction:
                cells = transaction.split("\t")
                require(len(cells) == len(TRANSACTION_FIELDS) and cells[16] in {"0", "1"}, "Incomplete transaction input")
                for index, ((_name, kind), value) in enumerate(zip(TRANSACTION_FIELDS, cells, strict=True)):
                    if index > 16 and cells[16] == "0":
                        require(value == NULL, "Unfilled native request/result cannot be causal data")
                    else:
                        validate_state_value(kind, value)
                require(row["boundary_callback"] == "TRADE" or integer(row["trade_count"]) > 0,
                        "Unattributed transaction callback")
            require(row["boundary_callback"] != "TRADE" or transaction != "", "Missing trade transaction proof")
            first_observer, observer = integer(row["first_observer_time_msc"]), integer(row["observer_time_msc"])
            first_monotonic, monotonic = integer(row["first_monotonic_us"]), integer(row["monotonic_us"])
            require(0 < first_observer <= observer and 0 <= first_monotonic <= monotonic, "Invalid acquisition clocks")
            history_count, history_chain = integer(row["history_observations"]), row["history_chain_sha256"]
            require(history_count >= self.last_history_count and bool(HASH.fullmatch(history_chain)) and
                    (history_count != self.last_history_count or history_chain == self.last_history_chain),
                    "Missing/substituted observed consumed-history proof")
            self.last_history_count, self.last_history_chain = history_count, history_chain
            require(integer(row["broker_estimate_time_msc"]) > 0 and
                    integer(row["last_quote_age_msc"]) == integer(row["broker_estimate_time_msc"]) - integer(quote[1]) and
                    integer(row["maximum_quote_age_msc"]) >= integer(row["last_quote_age_msc"]), "Invalid quote-age proof")
            quote_counts = {key: integer(row[key]) for key in
                            ("fresh_quote_count", "stale_quote_count", "missing_quote_count",
                             "stale_tick_count", "stale_trade_count")}
            require(row["capture_status"] == "OBSERVED_CALLBACK_ONLY" and
                    row["quote_status"] in {"FRESH_NATIVE_QUOTE", "STALE_CACHED_QUOTE", "MISSING_NATIVE_QUOTE"} and
                    all(value >= 0 for value in quote_counts.values()) and
                    sum(quote_counts[k] for k in ("fresh_quote_count", "stale_quote_count", "missing_quote_count")) == total and
                    quote_counts["stale_tick_count"] <= integer(row["tick_count"]) and
                    quote_counts["stale_trade_count"] <= integer(row["trade_count"]) and
                    quote_counts["stale_tick_count"] + quote_counts["stale_trade_count"] <= quote_counts["stale_quote_count"],
                    "Incomplete quote-status count partition")
            last_fresh = -1000 <= integer(row["last_quote_age_msc"]) <= 3000
            require((row["quote_status"] == "FRESH_NATIVE_QUOTE") == last_fresh and
                    quote_counts["fresh_quote_count" if last_fresh else "stale_quote_count"] > 0,
                    "Contradictory last native quote classification")
            unavailable = (integer(row["unavailable_count"]) > 0 or row["acquisition"] == "UNAVAILABLE" or
                           row["connected"] != "1" or row["synchronized"] != "1")
            if m["origin"] == "TESTER":
                require(not unavailable and quote_counts["missing_quote_count"] == 0 and
                        quote_counts["stale_tick_count"] == quote_counts["stale_trade_count"] == 0,
                        "Unsupported native tester missing/stale TICK/TRADE acquisition")
                require(first_observer == integer(row["first_broker_time_msc"]) and
                        observer == integer(row["last_broker_time_msc"]), "Incorrect tester simulated quote clock")
            elif (unavailable or integer(row["maximum_quote_age_msc"]) > 3000 or
                  integer(row["last_quote_age_msc"]) < -1000):
                require(any(c.covers(first_observer, observer, m["history_proof"], basis) for c in self.closures),
                        "Unsupported feed availability/closure proof")
            maximum_observer_gap, maximum_monotonic_gap = integer(row["maximum_observer_gap_msc"]), integer(row["maximum_monotonic_gap_us"])
            require(maximum_observer_gap >= 0 and maximum_monotonic_gap >= 0 and
                    maximum_observer_gap <= observer - first_observer and
                    maximum_monotonic_gap <= monotonic - first_monotonic, "Invalid bounded block gap proof")
            require(observer - first_observer <= 63000 and
                    (m["origin"] == "TESTER" or maximum_observer_gap <= 3000 or
                     any(c.covers(first_observer, observer, m["history_proof"], basis) for c in self.closures)),
                    "Unobserved interval inside input block")
            if m["origin"] == "LIVE_DEMO":
                require(monotonic - first_monotonic <= 63_000_000 and
                        (maximum_monotonic_gap <= 3_000_000 or
                         any(c.covers(first_observer, observer, m["history_proof"], basis) for c in self.closures)),
                        "Unobserved physical interval inside input block")
            if self.last_observer is not None:
                require(first_observer >= self.last_observer, "Backward capture observer clock")
                gap = first_observer - self.last_observer
                require(m["origin"] == "TESTER" or gap <= 3000 or any(c.covers(self.last_observer, first_observer, m["history_proof"], basis) for c in self.closures),
                        "Missing active capture or unproved session/holiday closure")
                if m["physical_run_id"] == self.input_physical_run and self.last_monotonic is not None:
                    require(first_monotonic >= self.last_monotonic, "Unproved process reset")
                    if m["origin"] == "LIVE_DEMO":
                        require(first_monotonic - self.last_monotonic <= 3_000_000 or
                                any(c.covers(self.last_observer, observer, m["history_proof"], basis) for c in self.closures),
                                "Unobserved physical live capture interval")
            self.last_observer, self.last_monotonic = observer, monotonic
            self.input_physical_run = m["physical_run_id"]
            self.last_input, self.last_record = last, integer(row["record_ordinal"])
            self._last_input_row = row

    def _births(self, path, proofs, first_input):
        for row in records(path / "window_births.tsv", FILES["window_births.tsv"], proofs):
            require(integer(row["birth_ordinal"]) == self.last_birth + 1 and
                    first_input <= integer(row["input_ordinal"]) <= self.last_input, "Unproven window birth cursor")
            require(row["valid"] in {"0", "1"} and integer(row["macro_seconds"]) == integer(self.core["macro_seconds"]),
                    "Invalid window birth")
            require(0 < integer(row["open_time_msc"]) <= integer(row["first_observed_time_msc"]) and
                    number(row["first_observed_bid"]) > 0, "Noncausal window birth")
            raw, trade = unhex(row["raw_prices_hex"]).split("\t"), unhex(row["trade_prices_hex"]).split("\t")
            require(len(raw) == len(trade) == 7, "Incomplete typed ladder birth")
            for value in (*raw, *trade, *(row[k] for k in ("source_open", "source_high", "source_low", "source_close"))):
                number(value)
            if row["valid"] == "1":
                require(row["reason"] == "OK" and integer(row["source_time_msc"]) < integer(row["source_close_time_msc"]) ==
                        integer(row["open_time_msc"]) and all(number(v) is not None for v in (*raw, *trade)),
                        "Unproven completed window source")
            payload = "\t".join(row[k] for k in FILES["window_births.tsv"][2:])
            try:
                self.db.execute("INSERT INTO births VALUES (?,?,?,?)",
                                (row["window_id"], payload, integer(row["birth_ordinal"]), integer(row["input_ordinal"])))
            except sqlite3.IntegrityError as exc:
                raise ContractError("Conflicting/repeated immutable window birth") from exc
            self.last_birth += 1

    def _facts(self, path, proofs, *, terminal, first_input):
        for row in records(path / "fact_events.tsv", FILES["fact_events.tsv"], proofs):
            require(integer(row["fact_ordinal"]) == self.last_fact + 1 and
                    0 < integer(row["input_ordinal"]) <= self.last_input, "Unproven fact prefix/cursor")
            require(row["phase"] == ("TERMINAL" if terminal else "CAPTURE"), "Unclassified terminal artifact")
            require(integer(row["input_ordinal"]) == self.last_input if terminal else
                    first_input <= integer(row["input_ordinal"]) <= self.last_input, "Fact outside actual segment callback prefix")
            payload, fact = validate_fact(row, self.profile, self.core)
            key = unhex(row["row_key"])
            previous = self.db.execute("SELECT payload,observed_time FROM facts WHERE table_name=? AND row_key=? ORDER BY ordinal DESC LIMIT 1",
                                       (row["table_name"], key)).fetchone()
            observed = fact.get("observed_time_msc")
            if previous:
                # Only outcomes may add later immutable observations; previous knowledge remains.
                require(row["table_name"] == "outcomes.tsv" and previous["payload"] != payload and
                        observed is not None and previous["observed_time"] is not None and
                        integer(observed) > integer(previous["observed_time"]), "Conflicting/repeated immutable fact")
                old_values = previous["payload"].split("\t")
                outcome = next(t for t in self.profile.tables if t.name == "outcomes.tsv")
                old = dict(zip(outcome.columns, old_values, strict=True))
                require(old["status"] == "CENSORED_RUN_END" and fact["status"] != "CENSORED_RUN_END" and
                        all(old[k] == (NULL if fact[k] is None else fact[k]) for k in ("trial_id", "attempt_id", "role", "rr")),
                        "Invalid late observation transition")
            self.db.execute("INSERT INTO facts VALUES (?,?,?,?,?,?,?)", (row["table_name"], key, integer(row["fact_ordinal"]),
                            integer(row["input_ordinal"]), row["phase"], payload, observed))
            self.last_fact += 1

    def _state(self, path, proofs, segment, completion):
        registry = self.contract["state_registry"]
        components = self.contract["profiles"][self.profile.engine]["components"]
        hashes = {"START": ZERO, "END": ZERO}
        seen_end = False
        counts = {}
        for row in records(path / "state_checkpoint.tsv", FILES["state_checkpoint.tsv"], proofs):
            boundary, component, field = row["boundary"], row["component"], row["field"]
            require(boundary in {"START", "END"} and (not seen_end or boundary == "END"), "Unordered state boundary")
            seen_end |= boundary == "END"
            require(component in components, "Unknown/foreign engine state component")
            spec = registry[component]
            index = integer(row["object_id"])
            require(str(index) == row["object_id"] and 0 <= index < spec["maximum"], "Unbounded/noncanonical state object")
            if field == "_count":
                require(spec.get("indexed", False) and index == 0 and row["value_type"] == "INT" and
                        0 <= integer(row["value"]) <= spec["maximum"], "Invalid state extent")
                counts[boundary, component] = integer(row["value"])
            else:
                declared = next((f for f in spec["fields"] if f["field"] == field), None)
                require(declared is not None and declared["value_type"] == row["value_type"], "Missing/unknown state field/type")
                validate_state_value(row["value_type"], row["value"])
            try:
                self.db.execute("INSERT INTO states VALUES (?,?,?,?,?,?,?)",
                                (segment, boundary, component, row["object_id"], field, row["value_type"], row["value"]))
            except sqlite3.IntegrityError as exc:
                raise ContractError("Duplicate semantic state field") from exc
            hashes[boundary] = chain(hashes[boundary], canonical_state(row))
        for boundary in hashes:
            for component in components:
                spec = registry[component]
                count = counts.get((boundary, component)) if spec.get("indexed") else 1
                require(count is not None, "Omitted pending-state extent")
                actual = self.db.execute("SELECT COUNT(*) FROM states WHERE segment=? AND boundary=? AND component=? AND field!='_count'",
                                         (segment, boundary, component)).fetchone()[0]
                require(actual == count * len(spec["fields"]), "Omitted/extra semantic state")
                if spec.get("indexed"):
                    indices = self.db.execute("SELECT DISTINCT CAST(object_id AS INTEGER) FROM states WHERE segment=? AND boundary=? AND component=? AND field!='_count' ORDER BY 1",
                                              (segment, boundary, component)).fetchall()
                    require([r[0] for r in indices] == list(range(count)), "Omitted/reindexed pending state")
            # Enforce every object's exact fields in source serialization order.
            cursor = self.db.execute("SELECT component,object_id,field,kind FROM states WHERE segment=? AND boundary=? ORDER BY rowid",
                                     (segment, boundary))
            for component in components:
                spec = registry[component]
                count = counts.get((boundary, component)) if spec.get("indexed") else 1
                if spec.get("indexed"):
                    actual = cursor.fetchone()
                    require(actual is not None and tuple(actual) == (component, "0", "_count", "INT"), "State extent/order mismatch")
                for index in range(count):
                    for field in spec["fields"]:
                        actual = cursor.fetchone()
                        require(actual is not None and tuple(actual) ==
                                (component, str(index), field["field"], field["value_type"]), "Per-object semantic state/order mismatch")
            require(cursor.fetchone() is None, "Extra semantic state object")
        def value(boundary, component, field):
            found = self.db.execute("SELECT value FROM states WHERE segment=? AND boundary=? AND component=? AND object_id='0' AND field=?",
                                    (segment, boundary, component, field)).fetchone()
            require(found is not None, "Missing mandatory healthy lifecycle proof")
            return found["value"]
        for boundary in ("START", "END"):
            require(value(boundary, "SHARED_CONTROL", "g_model_failed") == "0", "Unhealthy capture checkpoint")
            require(value(boundary, "SHARED_CONTROL", "g_cont_anchor_pending") == "0", "Unanchored startup checkpoint")
            if self.profile.engine == "PIVOT_MACRO_V2":
                finalized = value(boundary, "PIVOT_CONTROL", "g_pivot_run_finalized")
                require(finalized == ("1" if boundary == "END" and completion in {"TERMINAL", "INTERRUPTED"} else "0"),
                        "Invalid Pivot finalization lifecycle")
                if completion == "ROTATED":
                    require(value(boundary, "PIVOT_CONTROL", "g_tester_interval_completed") == "0",
                            "Completed tester cannot authorize capture continuation")
                if completion in {"TERMINAL", "INTERRUPTED"}:
                    require(value(boundary, "PIVOT_CONTROL", "g_tester_interval_completed") ==
                            ("1" if completion == "TERMINAL" else "0"),
                            "Natural/interrupted terminal lacks matching tester completion")
            else:
                require(value(boundary, "CANDLE_CONTROL", "g_candle_stopping") ==
                        ("1" if boundary == "END" and completion in {"TERMINAL", "INTERRUPTED"} else "0"),
                        "Invalid Candle stopping lifecycle")
                completed = value(boundary, "CANDLE_CONTROL", "g_candle_tester_interval_completed")
                if completion == "ROTATED":
                    require(completed == "0", "Completed tester cannot authorize capture continuation")
                if completion in {"TERMINAL", "INTERRUPTED"}:
                    require(completed == ("1" if completion == "TERMINAL" else "0"),
                            "Natural/interrupted terminal lacks matching tester completion")
        require(value("END", "SHARED_CONTROL", "g_cont_history_chain") == self.last_history_chain and
                value("END", "SHARED_CONTROL", "g_cont_history_observations") == str(self.last_history_count),
                "Checkpoint does not bind complete consumed-history prefix")
        return hashes["START"], hashes["END"]

    def _references(self):
        # Enumerated current-family relationships. Extensions cannot invent core types.
        mapping = {
            "signal_events.tsv": (("macro_window_id", "WINDOW"),),
            "feature_snapshots.tsv": (("signal_id", "signal_events.tsv"), ("macro_window_id", "WINDOW")),
            "entry_attempts.tsv": (("signal_id", "signal_events.tsv"), ("snapshot_id", "feature_snapshots.tsv"),
                                   ("parent_attempt_id", "entry_attempts.tsv"), ("macro_window_id", "WINDOW")),
            "execution_checks.tsv": (("attempt_id", "entry_attempts.tsv"),),
            "trials.tsv": (("attempt_id", "entry_attempts.tsv"),),
            "outcomes.tsv": (("trial_id", "trials.tsv"), ("attempt_id", "entry_attempts.tsv")),
            "pivot_origins.tsv": (("signal_id", "signal_events.tsv"),),
            "candle_signals.tsv": (("signal_id", "signal_events.tsv"),),
            "candle_attempts.tsv": (("attempt_id", "entry_attempts.tsv"),),
        }
        tables = {t.name: t for t in self.profile.tables}
        for row in self.db.execute("SELECT table_name,payload,input_ordinal FROM facts ORDER BY ordinal"):
            table = tables[row["table_name"]]
            fact = dict(zip(table.columns, row["payload"].split("\t"), strict=True))
            for field, target in mapping.get(table.name, ()):
                value = fact.get(field, NULL)
                if value == NULL:
                    continue
                if target == "WINDOW":
                    exists = self.db.execute("SELECT 1 FROM births WHERE window_id=? AND input_ordinal<=?", (value, row["input_ordinal"])).fetchone()
                else:
                    exists = self.db.execute("SELECT 1 FROM facts WHERE table_name=? AND row_key=? AND input_ordinal<=?",
                                             (target, value, row["input_ordinal"])).fetchone()
                require(exists is not None, "Missing canonical typed reference")
            if table.name == "macro_windows.tsv":
                birth = self.db.execute("SELECT payload FROM births WHERE window_id=?", (fact["window_id"],)).fetchone()
                require(birth is not None, "Terminal window lacks authoritative birth")
                birth_row = dict(zip(FILES["window_births.tsv"][2:], birth["payload"].split("\t"), strict=True))
                for name in ("open_time_msc", "source_time_msc", "source_close_time_msc", "macro_seconds",
                             "source_open", "source_high", "source_low", "source_close", "valid", "reason",
                             "first_observed_time_msc", "first_observed_bid"):
                    require(fact[name] == birth_row[name], "Conflicting immutable window source")
        for component, field, target in (
            ("SHARED_CONTROL", "g_model_window_id", "WINDOW"),
            ("PIVOT_SIGNAL", "window_id", "WINDOW"),
            ("PIVOT_SIGNAL", "origin_id", "signal_events.tsv"),
            ("PIVOT_DEFERRED_CLOSE", "origin_id", "signal_events.tsv"),
            ("PIVOT_PENDING_ORIGIN", "origin.origin_id", "signal_events.tsv"),
            ("PIVOT_PENDING_ORIGIN", "origin.window_id", "WINDOW"),
            ("PIVOT_TRIAL", "trial.identity.origin_id", "signal_events.tsv"),
            ("PIVOT_TRIAL", "trial.identity.window_id", "WINDOW"),
            ("PIVOT_PARITY", "origin_id", "signal_events.tsv"),
            ("CANDLE_BROKER", "attempt.id", "entry_attempts.tsv"),
            ("CANDLE_BROKER", "attempt.root_id", "signal_events.tsv"),
            ("CANDLE_BROKER", "attempt.parent_id", "entry_attempts.tsv"),
            ("CANDLE_VIRTUAL", "attempt_id", "entry_attempts.tsv"),
        ):
            for row in self.db.execute("SELECT value,segment,boundary FROM states WHERE component=? AND field=?", (component, field)):
                value = native_text(row["value"])
                if not value:
                    continue
                prefix = row["segment"] - (row["boundary"] == "START")
                maximum_fact = integer(self.segments[prefix]["seal"]["last_fact_ordinal"]) if prefix >= 0 else 0
                maximum_birth = integer(self.segments[prefix]["seal"]["last_birth_ordinal"]) if prefix >= 0 else 0
                exists = (self.db.execute("SELECT 1 FROM births WHERE window_id=? AND ordinal<=?",
                                         (value, maximum_birth)).fetchone() if target == "WINDOW" else
                          self.db.execute("SELECT 1 FROM facts WHERE table_name=? AND row_key=? AND ordinal<=?",
                                          (target, value, maximum_fact)).fetchone())
                require(exists is not None, "Omitted typed pending-state reference")

    def verify_unchanged(self):
        for segment in self.segments:
            proofs = {}
            for name, columns in FILES.items():
                for _row in records(segment["path"] / name, columns, proofs):
                    pass
            require(proofs == segment["proofs"], "Accepted source bytes replaced")

    def report(self) -> dict:
        return {"family": FAMILY, "version": VERSION, "descriptor_sha256": descriptor_digest(), "operational": False,
                "segments": len(self.segments), "input_callbacks": self.last_input, "input_blocks": self.last_record,
                "facts": self.last_fact, "window_births": self.last_birth,
                "source_owner_acceptance": "REQUIRED", "calendar_evidence": len(self.closures),
                "tester_delivery": [p.summary() for p in self.tester_deliveries]}


def write_rows(path: Path, columns, rows) -> FileProof:
    require(not path.exists(), "Immutable output already exists")
    state, sha, size, count = ZERO, hashlib.sha256(), 0, 0
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        header = ("\t".join(columns) + "\r\n").encode()
        stream.write(header); sha.update(header); state, size = chain(state, header), len(header)
        for row in rows:
            raw = ("\t".join(str(row[c]) for c in columns) + "\r\n").encode()
            require(len(raw) <= MAX_ROW_BYTES, "Witness output row cap")
            stream.write(raw); sha.update(raw); state, size, count = chain(state, raw), size + len(raw), count + 1
    return FileProof(count, size, state, sha.hexdigest())


def write_metadata(path: Path, values: dict) -> FileProof:
    return write_rows(path, ("key", "value"), ({"key": k, "value": v} for k, v in values.items()))


def _write_witness(archive: ContinuationArchive, output: Path, legacy_source_proof: str, native_fence: VerifiedNativeFence) -> str:
    """Only an already validated complete anchored nonterminal prefix can be suppressed."""
    require(archive.db is not None and archive.segments and archive.segments[-1]["seal"]["completion"] == "ROTATED",
            "Witness requires actual pre-finalization checkpoint")
    require(isinstance(native_fence, VerifiedNativeFence), "Independent native terminal fence receipt required")
    native_fence.verify(archive)
    require(not output.exists() and safe_id(output.name), "Fresh owned witness directory required")
    require(legacy_source_proof == "NONE" or bool(HASH.fullmatch(legacy_source_proof)), "Invalid whole legacy comparison proof")
    archive.verify_unchanged()
    for component, field in (("PIVOT_CONTROL", "g_tester_interval_completed"),
                             ("PIVOT_CONTROL", "g_pivot_run_finalized"), ("CANDLE_CONTROL", "g_candle_stopping")):
        state = archive.db.execute("SELECT value FROM states WHERE segment=? AND boundary='END' AND component=? AND field=?",
                                   (len(archive.segments) - 1, component, field)).fetchone()
        require(state is None or state["value"] == "0", "Terminal lifecycle cannot authorize replay")
    first, last = archive.segments[0], archive.segments[-1]
    m = first["manifest"]
    require(m["origin"] == "TESTER", "Native demo broker-state restoration is unsupported")
    values = {
        "family": "MQL5_MODEL_CONTINUATION_WITNESS", "version": "1", "descriptor_sha256": descriptor_digest(),
        "engine": m["engine"], "origin": m["origin"], "source_id": m["source_id"], "session_id": m["session_id"],
        "source_proof": m["source_proof"], "configuration_proof": m["configuration_proof"],
        "history_proof": m["history_proof"], "core_manifest_sha256": m["core_manifest_sha256"],
        "last_input_ordinal": str(archive.last_input), "last_fact_ordinal": str(archive.last_fact),
        "last_birth_ordinal": str(archive.last_birth), "predecessor_seal": last["proofs"]["segment_seal.tsv"].chain,
        "anchor_state_sha256": archive.anchor_state, "end_state_sha256": archive.previous_state,
        "legacy_source_proof": legacy_source_proof, "native_fence_proof": native_fence.evidence_sha256,
    }
    proofs = {"witness_manifest.tsv": write_metadata(output / "witness_manifest.tsv", values)}
    for target, source in (("input_prefix.tsv", "input_events.tsv"), ("fact_prefix.tsv", "fact_events.tsv"), ("window_prefix.tsv", "window_births.tsv")):
        def merged(source=source):
            for segment in archive.segments:
                yield from records(segment["path"] / source, FILES[source])
        proofs[target] = write_rows(output / target, WITNESS_FILES[target], merged())
    def states():
        for segment, boundary in ((first, "START"), (last, "END")):
            for row in records(segment["path"] / "state_checkpoint.tsv", FILES["state_checkpoint.tsv"]):
                if row["boundary"] == boundary:
                    yield row
    proofs["state_checkpoint.tsv"] = write_rows(output / "state_checkpoint.tsv", WITNESS_FILES["state_checkpoint.tsv"], states())
    seal = {}
    for name, proof in proofs.items():
        seal.update({f"rows_{name}": str(proof.rows), f"bytes_{name}": str(proof.bytes), f"chain_{name}": proof.chain})
    result = write_metadata(output / "witness_seal.tsv", seal)
    archive.verify_unchanged()
    return result.chain


def build_witness(archive: ContinuationArchive, output: Path, *, native_fence: VerifiedNativeFence | None = None) -> str:
    """New continuous source only; legacy binding can only come from whole comparison."""
    return _write_witness(archive, output, "NONE", native_fence)


def compare_legacy_whole(archive: ContinuationArchive, legacy_path: Path) -> dict:
    """Independent whole source comparison; no retrospective checkpoint synthesis."""
    require(archive.segments[-1]["seal"]["completion"] == "TERMINAL", "Missing actual complete paired replay witness")
    with ModelRun(legacy_path) as legacy:
        require(legacy.profile.engine == archive.profile.engine, "Legacy engine mismatch")
        core = dict(legacy.manifest)
        physical = core["run_id"]
        core["run_id"] = archive.core["run_id"]
        require(core == archive.core, "Legacy source/configuration differs from paired replay")
        for table in legacy.profile.tables:
            if table.name in {"run_manifest.tsv", "run_summary.tsv"}:
                continue
            observed = archive.db.execute("SELECT payload FROM facts WHERE table_name=? ORDER BY ordinal", (table.name,))
            for row in legacy.rows(table.name):
                row["run_id"] = archive.core["run_id"]
                payload = "\t".join(NULL if row[c] is None else row[c] for c in table.columns)
                actual = observed.fetchone()
                require(actual is not None and actual["payload"] == payload, "Whole legacy source mismatch")
            require(observed.fetchone() is None, "Extra paired replay fact")
        summary = {k.removeprefix("core_summary_"): v for k, v in archive.segments[-1]["seal"].items() if k.startswith("core_summary_")}
        require(set(summary) == set(legacy.summary), "Whole legacy terminal summary key mismatch")
        require(all(summary[k] == legacy.summary[k] for k in summary if k not in PHYSICAL_SUMMARY_KEYS),
                "Whole legacy terminal artifact mismatch")
        physical_metrics = {}
        for key in PHYSICAL_SUMMARY_KEYS:
            require(0 <= integer(summary[key]) <= 256 and 0 <= integer(legacy.summary[key]) <= 256,
                    "Invalid physical writer metric")
            physical_metrics[key] = {"legacy": legacy.summary[key], "paired": summary[key]}
        legacy.verify_unchanged()
        archive.verify_unchanged()
        # Source identity is explicit; only the declared run_id mapping is normalized.
        proof = {"physical_run_id": physical, "canonical_run_id": archive.core["run_id"], "files": legacy.hashes,
                 "paired_terminal_seal": archive.segments[-1]["proofs"]["segment_seal.tsv"].chain,
                 "classification": "CAPTURE_AND_ACTUAL_TERMINAL_PHASE_V1",
                 "physical_writer_metrics": physical_metrics}
        proof["proof_sha256"] = hashlib.sha256(json.dumps(proof, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        return proof



def bootstrap_witness(whole: ContinuationArchive, legacy_path: Path, prefix_segments: int, output: Path,
                      *, native_fence: VerifiedNativeFence | None = None) -> dict:
    """Compare retained complete legacy branch, then export its healthy actual prefix."""
    require(0 < prefix_segments < len(whole.segments) and
            whole.segments[prefix_segments - 1]["seal"]["completion"] == "ROTATED",
            "Bootstrap requires explicitly selected earlier ROTATED checkpoint")
    require(isinstance(native_fence, VerifiedNativeFence), "Independent native terminal fence receipt required")
    native_fence.verify(whole, whole=True)
    evidence = compare_legacy_whole(whole, legacy_path)
    paths = [s["path"] for s in whole.segments[:prefix_segments]]
    with ContinuationArchive(paths, closures=whole.closures,
                             tester_deliveries=whole.tester_deliveries) as prefix:
        require(prefix.segments[-1]["proofs"]["segment_seal.tsv"] ==
                whole.segments[prefix_segments - 1]["proofs"]["segment_seal.tsv"], "Bootstrap prefix substituted")
        witness = _write_witness(prefix, output, evidence["proof_sha256"], native_fence)
    whole.verify_unchanged()
    return {"whole_source_proof": evidence, "predecessor_seal": whole.segments[prefix_segments - 1]["proofs"]["segment_seal.tsv"].chain,
            "witness_seal_chain": witness, "terminal_branch_retained": True, "prefix_segments": prefix_segments}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("segments", nargs="+", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    with ContinuationArchive(args.segments) as archive:
        report = archive.report()
        archive.verify_unchanged()
        if args.report:
            require(not any(args.report.is_relative_to(p) for p in args.segments), "Report cannot alter a sealed source")
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
