"""Native tester delivery evidence, issued only through a trusted owner registry.

The registry is an injected internal trust boundary, never an archive field, user
JSON, CLI argument or a filesystem receipt that authenticates itself. The native
owner records original MCP job/artifact and segment pins out of band. Consumers
must authenticate that registry independently. A issued delivery object proves
only the registered LOCAL_CUSTOM_TESTER delivered stream; paired replay and a
reviewed broker/virtual pre-terminal fence still own final acceptance.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
import weakref
import zipfile
from io import BytesIO
from abc import ABC, abstractmethod
from dataclasses import dataclass, replace
from datetime import date
from pathlib import Path
from types import MappingProxyType
from xml.etree import ElementTree as ET

from .continuation_contract import FILES, ZERO, descriptor_digest, source_digest
from .reader import ContractError, integer, require

MAX_NATIVE_ARTIFACT_BYTES = 16 * 1024 * 1024
MAX_REPORT_XML_BYTES = 32 * 1024 * 1024
ARTIFACT_ROLES = frozenset({"prelaunch", "owned_job", "native_result", "report_json", "report_xlsx", "history", "history_anchor"})
HISTORY_SPEC_FIELDS = ("digits", "point", "tick_size", "contract_size", "calculation_mode",
                       "currency_profit", "currency_margin", "trade_mode", "trade_exemode",
                       "trade_order_mode", "trade_filling_mode", "trade_stops_level",
                       "trade_freeze_level", "volume_min", "volume_max", "volume_step")
HISTORY_JOB_FIELDS = frozenset(("kind", "source_origin", "native_run_id", "physical_run_id",
                               "source_id", "session_id", "engine", "symbol",
                               "configuration_proof", "history_anchor_sha256", "date_from",
                               "date_to", "model", "native_custom_symbol",
                               "native_decision_spec_fields", "bounded_observation_pins"))
HASH = re.compile(r"[0-9a-f]{64}\Z")
NATIVE_REPORT_KEYS = frozenset(["run_id","generated_bars","generated_ticks","symbol","initial_deposit","withdrawal","profit","gross_profit","gross_loss","max_profit","max_loss","con_profit_max","max_con_profit","con_loss_max","max_con_loss","balance_min","max_drawdown_balance","drawdown_percent_balance","rel_drawdown_balance","rel_drawdown_percent_balance","equity_min","max_drawdown_equity","drawdown_percent_equity","rel_drawdown_equity","rel_drawdown_percent_equity","expected_payoff","profit_factor","recovery_factor","sharpe_ratio","margin_level","deals","trades","profit_trades","loss_trades","short_trades","long_trades","win_short_trades","win_long_trades","consecutive_profit_max_trades","max_consecutive_profit_trades","consecutive_loss_max_trades","max_consecutive_loss_trades","avg_consecutive_winners","avg_consecutive_losers"])
_ISSUED = weakref.WeakSet()


@dataclass(frozen=True)
class NativeJobScope:
    """Exact native owner authorization; no calendar/budget defaults in the wire."""
    prepared_settings: dict
    loaded_configuration: dict
    report_period: str
    wall_budget_ms: int
    maximum_segments: int


@dataclass(frozen=True)
class NativeJobRegistration:
    """Only trusted owner code constructs this, from original native job results.

    history_anchor_sha256 pins the immutable original source/history receipt.
    history_sha256 pins the separately registered dated physical-job receipt.
    Neither the current dates nor its receipt SHA replace the session anchor.
    artifact_pins maps exact roles to (original regular path, out-of-band SHA256).
    segment_pins maps each original segment path to all six original file SHAs.
    replay_prefix_ticks/input/record come from the previously authenticated cold
    witness, never arithmetic inferred from a new report or caller labels.
    """
    job_key: str
    native_run_id: str
    physical_run_id: str
    engine: str
    program_path: str
    symbol: str
    source_sha256: str
    descriptor_sha256: str
    binary_sha256: str
    history_sha256: str
    history_anchor_sha256: str
    configuration_sha256: str
    parameters: tuple[str, ...]
    artifact_pins: dict
    segment_pins: dict
    scope: NativeJobScope
    replay_prefix_ticks: int = 0
    replay_prefix_input: int = 0
    replay_prefix_record: int = 0
    replay_prefix_chain: str = ZERO
    replay_witness_proof: str | None = None
    native_fence_pin: tuple[Path, str] | None = None


class NativeJobRegistry(ABC):
    """Authenticated internal dependency. Do not deserialize a caller's registry."""
    @abstractmethod
    def lookup(self, job_key: str) -> NativeJobRegistration:
        raise NotImplementedError


def _identity(info):
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def _open_regular(path: Path):
    require(all(not p.is_symlink() for p in (path, *path.parents)),
            "Native evidence requires regular owned files")
    fd = None
    try:
        require(stat.S_ISREG(path.lstat().st_mode), "Native evidence requires a regular file")
        # NONBLOCK prevents a replacement FIFO from blocking between lstat/open.
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode), "Native evidence requires a regular file")
        return fd, info
    except (OSError, ContractError) as exc:
        if fd is not None:
            os.close(fd)
        if isinstance(exc, ContractError):
            raise
        raise ContractError("Native evidence file unavailable") from exc


def _close_identity(path, fd, before):
    after, current = os.fstat(fd), path.stat(follow_symlinks=False)
    require(_identity(before) == _identity(after) == _identity(current),
            "Native evidence changed while read")


def file_sha256(path: Path) -> str:
    fd, before = _open_regular(path)
    sha = hashlib.sha256()
    try:
        with os.fdopen(fd, "rb", closefd=False) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                sha.update(block)
        _close_identity(path, fd, before)
    finally:
        os.close(fd)
    return sha.hexdigest()


def _verified_bytes(path: Path, expected: str, cap=MAX_NATIVE_ARTIFACT_BYTES) -> bytes:
    require(bool(HASH.fullmatch(expected)), "Invalid original native artifact pin")
    fd, before = _open_regular(path)
    try:
        require(before.st_size <= cap, "Native artifact byte cap")
        with os.fdopen(fd, "rb", closefd=False) as stream:
            raw = stream.read(cap + 1)
        require(len(raw) <= cap, "Native artifact byte cap")
        _close_identity(path, fd, before)
        require(hashlib.sha256(raw).hexdigest() == expected, "Substituted original native artifact")
        return raw
    finally:
        os.close(fd)


def _artifact(registration, role):
    path, expected = registration.artifact_pins[role]
    return _verified_bytes(Path(path), expected)


def _pairs(values):
    result = {}
    for key, value in values:
        require(key not in result, "Duplicate native JSON key")
        result[key] = value
    return result


def _finite_float(value):
    parsed = float(value)
    require(math.isfinite(parsed), "Nonfinite native JSON number")
    return parsed


def _json(raw):
    try:
        result = json.loads(raw, object_pairs_hook=_pairs, parse_float=_finite_float,
                            parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
        require(isinstance(result, dict), "Native JSON object required")
        return result
    except ContractError:
        raise
    except (ValueError, UnicodeError) as exc:
        raise ContractError("Invalid original native JSON") from exc


def report_cells(raw: bytes) -> list[str]:
    """Parse only SHA-verified bytes of the two exact native XLSX XML members."""
    try:
        with zipfile.ZipFile(BytesIO(raw)) as archive:
            names = archive.namelist()
            require(len(names) == len(set(names)) and len(names) <= 64, "Duplicate/bounded native report members")
            require(sum(i.file_size for i in archive.infolist()) <= MAX_REPORT_XML_BYTES,
                    "Native report uncompressed cap")
            parts = []
            for name in ("xl/sharedStrings.xml", "xl/worksheets/sheet1.xml"):
                data = archive.read(name)
                require(b"<!DOCTYPE" not in data and b"<!ENTITY" not in data, "Native report entity declaration")
                parts.append(ET.fromstring(data))
    except (KeyError, ValueError, zipfile.BadZipFile, ET.ParseError) as exc:
        raise ContractError("Invalid exact native XLSX") from exc
    strings = ["".join(item.itertext()) for item in parts[0]]
    ns = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    cells = []
    for cell in parts[1].findall(".//s:c", ns):
        value = cell.find("s:v", ns)
        if value is None:
            continue
        text = value.text or ""
        if cell.attrib.get("t") == "s":
            require(text.isdigit() and int(text) < len(strings), "Invalid native report string index")
            text = strings[int(text)]
        require(len(text) <= 65536, "Native report cell cap")
        cells.append(text)
    return cells


def _label(cells, key):
    positions = [i for i, value in enumerate(cells) if value == key]
    require(len(positions) == 1 and positions[0] + 1 < len(cells), "Missing/ambiguous native report field")
    return cells[positions[0] + 1]


def _parameters(reg, pre, cells):
    expected = dict(item.split("=", 1) for item in reg.parameters)
    require(len(expected) == len(reg.parameters) == (18 if reg.engine == "PIVOT_MACRO_V2" else 17),
            "Exact registered native input inventory required")
    require(pre["parameters"] == list(reg.parameters), "Changed native prepared inputs")
    loaded = {}
    for value in cells:
        if "=" not in value:
            continue
        name, content = value.split("=", 1)
        if name in expected:
            require(name not in loaded, "Duplicate loaded native input")
            loaded[name] = content
    require(loaded == expected, "Loaded native report inputs differ from registered SET")
    require(expected["Enable_Intake_Continuation"] == "true" and
            expected["Signal_Feature_Run_Id"] == reg.physical_run_id and
            expected["Intake_History_Proof"] == reg.history_anchor_sha256 and
            expected["Intake_Source_Proof"] in {"", reg.source_sha256} and
            expected["Intake_Configuration_Proof"] in {"", reg.configuration_sha256},
            "Native capture/input identity mismatch")
    require(expected["Intake_Replay_Witness_Proof"] == (reg.replay_witness_proof or "") and
            bool(expected["Intake_Replay_Witness_Id"]) == bool(reg.replay_witness_proof),
            "Native replay witness binding mismatch")
    return expected


def _history_date(value):
    require(type(value) is str, "Native history date must be canonical")
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise ContractError("Invalid native history date") from exc
    require(parsed.isoformat() == value, "Noncanonical native history date")
    return parsed


def _history_binding(reg, pre, anchor, history):
    """The trusted registry owns both original pins; JSON cannot certify itself."""
    require(set(history) == HISTORY_JOB_FIELDS and
            history["kind"] == "NATIVE_PHYSICAL_JOB_HISTORY_V1",
            "Exact dated native history receipt required")
    require(pre["source_origin"] == anchor["source_origin"] == history["source_origin"] ==
            "LOCAL_CUSTOM_TESTER" and
            pre["history_anchor_sha256"] == history["history_anchor_sha256"] ==
            reg.history_anchor_sha256 == reg.artifact_pins["history_anchor"][1] and
            reg.history_sha256 == reg.artifact_pins["history"][1],
            "Unproved original history anchor or current native history receipt")
    expected = dict(item.split("=", 1) for item in reg.parameters)
    require(history["native_run_id"] == reg.native_run_id and
            history["physical_run_id"] == reg.physical_run_id and
            history["engine"] == reg.engine and
            history["source_id"] == expected["Intake_Source_Id"] and
            history["session_id"] == expected["Intake_Session_Id"] and
            history["configuration_proof"] == reg.configuration_sha256 and
            history["symbol"] == anchor["symbol"] == reg.symbol,
            "Native history source/session/job/configuration substitution")
    require(type(history["model"]) is int and history["model"] == 4 and
            type(anchor["model"]) is int and anchor["model"] == 4 and
            history["native_decision_spec_fields"] == anchor["native_decision_spec_fields"] ==
            list(HISTORY_SPEC_FIELDS),
            "Exact native history model/specification fields required")
    current, original = history["native_custom_symbol"], anchor["native_custom_symbol"]
    require(type(current) is dict and type(original) is dict and
            set(current) == set(HISTORY_SPEC_FIELDS) | {"symbol", "custom_symbol"} and
            current["symbol"] == original["symbol"] == reg.symbol and
            current["custom_symbol"] == original["custom_symbol"] == "yes" and
            all(type(current[key]) is type(original[key]) and current[key] == original[key]
                for key in HISTORY_SPEC_FIELDS),
            "Changed native custom source or stable decision specification")
    # Informational references inside the trusted registry-pinned whole receipt;
    # their checksum shape does not independently authenticate observations.
    require(type(history["bounded_observation_pins"]) is dict and
            bool(history["bounded_observation_pins"]) and
            all(type(role) is str and role and type(pin) is str and HASH.fullmatch(pin)
                for role, pin in history["bounded_observation_pins"].items()),
            "Missing native bounded history observations")
    start, end = _history_date(history["date_from"]), _history_date(history["date_to"])
    anchor_start, anchor_end = _history_date(anchor["date_from"]), _history_date(anchor["date_to"])
    require(start == anchor_start and start < end and end >= anchor_end,
            "Historical continuation requires the original anchor and nonshrinking end")


class VerifiedTesterDelivery:
    """Opaque issued proof. This is provisional delivery evidence, never P01."""
    __slots__ = ("registration", "segments", "totals", "generated_ticks", "generated_bars", "__weakref__")

    def __new__(cls, *args, **kwargs):
        raise ContractError("Native delivery proof requires authenticated registry issuance")

    def __setattr__(self, name, value):
        raise AttributeError("Native delivery evidence is immutable")

    def is_authenticated(self):
        return type(self) is VerifiedTesterDelivery and self in _ISSUED

    def verify_segment(self, manifest, proofs, seal):
        reg = self.registration
        require(self.is_authenticated() and manifest["origin"] == "TESTER" and
                manifest["physical_run_id"] == reg.physical_run_id and manifest["engine"] == reg.engine and
                manifest["source_proof"] == reg.source_sha256 and
                manifest["descriptor_sha256"] == reg.descriptor_sha256 and
                manifest["history_proof"] == reg.history_anchor_sha256 and
                manifest["configuration_proof"] == reg.configuration_sha256,
                "Native delivery origin/source/configuration/history binding mismatch")
        key = integer(manifest["segment_ordinal"])
        require(key in self.segments and {name: p.sha256 for name, p in proofs.items()} ==
                dict(self.segments[key]), "Missing/substituted registered native segment")
        require(manifest["replay_witness_proof"] == (reg.replay_witness_proof or r"\N"),
                "Native delivery replay binding mismatch")

    def verify_unchanged(self):
        require(self.is_authenticated(), "Factory-issued native delivery evidence required")
        for role in ARTIFACT_ROLES:
            _artifact(self.registration, role)
        for path, pins in self.registration.segment_pins.items():
            require(all(file_sha256(Path(path) / name) == digest for name, digest in pins.items()),
                    "Registered original capture changed")

    def verify_native_fence(self, fence, archive):
        """Bind the owner audit and exact owned state at a safe ordinary boundary.

        Zero owned objects are valid for a new replay checkpoint. The separate
        mechanism acceptance case must still demonstrate positive pending roles.
        """
        require(self.is_authenticated(), "Factory-issued native delivery evidence required")
        pin = self.registration.native_fence_pin
        require(pin is not None and fence.evidence_sha256 == pin[1],
                "Authenticated native terminal fence audit required")
        audit = _json(_verified_bytes(Path(pin[0]), pin[1]))
        expected = {key: getattr(fence, key) for key in (
            "descriptor_sha256", "source_proof", "configuration_proof", "history_proof",
            "core_manifest_sha256", "paired_terminal_seal",
            "first_terminal_effect_input_ordinal", "last_safe_input_ordinal")}
        require(audit["kind"] == "NATIVE_TESTER_PREFINALIZATION_FENCE_V1" and
                audit["native_job_key"] == self.registration.job_key and audit["fields"] == expected and
                audit["native_result_sha256"] == self.registration.artifact_pins["native_result"][1] and
                type(audit["pending_broker_objects"]) is int and audit["pending_broker_objects"] >= 0 and
                type(audit["pending_virtual_objects"]) is int and audit["pending_virtual_objects"] >= 0,
                "Native terminal fence audit binding/owned state mismatch")
        selected = [(index, s) for index, s in enumerate(archive.segments)
                    if integer(s["seal"]["last_input_ordinal"]) == fence.last_safe_input_ordinal and
                    s["seal"]["completion"] == "ROTATED"]
        require(len(selected) == 1, "Native fence must bind an actual ordinary checkpoint")
        index, segment = selected[0]
        require(type(audit["ordinary_segment_ordinal"]) is int and
                audit["ordinary_segment_ordinal"] == integer(segment["manifest"]["segment_ordinal"]),
                "Native fence ordinary segment ordinal mismatch")
        objects = {}
        for row in archive.db.execute(
                "SELECT component,object_id,field,value FROM states WHERE segment=? AND boundary='END'", (index,)):
            objects.setdefault((row["component"], row["object_id"]), {})[row["field"]] = row["value"]
        if self.registration.engine == "PIVOT_MACRO_V2":
            broker = sum(values.get("execution.broker_entry_confirmed") == "1" and
                         values.get("execution.broker_close_confirmed") == "0" and
                         integer(values.get("execution.position_identifier", "0")) > 0
                         for (component, _), values in objects.items() if component == "PIVOT_SIGNAL")
            virtual = sum((values.get("active") == "1" or values.get("pending_entry") == "1") and
                          values.get("trial.identity.role") == "0"
                          for (component, _), values in objects.items() if component == "PIVOT_TRIAL")
            parity = sum((values.get("active") == "1" or values.get("pending_entry") == "1") and
                         values.get("trial.identity.role") == "1"
                         for (component, _), values in objects.items() if component == "PIVOT_TRIAL")
            require(type(audit["pending_broker_parity_objects"]) is int and
                    audit["pending_broker_parity_objects"] == parity,
                    "Native broker-parity fence evidence mismatch")
        else:
            broker = sum(values.get("active") == values.get("filled") == "1" and
                         integer(values.get("position_id", "0")) > 0
                         for (component, _), values in objects.items() if component == "CANDLE_BROKER")
            virtual = sum(values.get("active") == "1" for (component, _), values in objects.items()
                          if component == "CANDLE_VIRTUAL")
            require(audit["pending_broker_parity_objects"] is None,
                    "Candle native fence must exclude Pivot broker parity")
        require(audit["pending_broker_objects"] == broker and
                audit["pending_virtual_objects"] == virtual,
                "Native fence counts do not match distinct owned broker/virtual state")


    def summary(self):
        return {"delivery_admission": "PROVISIONAL_NATIVE_REGISTERED",
                "history_anchor_sha256": self.registration.history_anchor_sha256,
                "physical_history_receipt_sha256": self.registration.history_sha256,
                "origin_scope": "LOCAL_CUSTOM_TESTER", "generated_ticks": self.generated_ticks,
                "generated_bars": self.generated_bars, "captured_callback_counts": dict(self.totals),
                "source_quality": "HISTORICAL_SOURCE_GAPS_UNKNOWN",
                "timer_trade_queue_completeness": "UNSUPPORTED",
                "external_feed_completeness": "UNSUPPORTED", "paired_fence_acceptance": "REQUIRED"}


def _authenticate_tester_delivery(registry: NativeJobRegistry, job_key: str) -> VerifiedTesterDelivery:
    """Verify an out-of-band owner registration against unchanged original artifacts."""
    require(isinstance(registry, NativeJobRegistry), "Authenticated native job registry required")
    reg = registry.lookup(job_key)
    require(isinstance(reg, NativeJobRegistration) and reg.job_key == job_key,
            "Native owner registration missing")
    require(type(reg.scope) is NativeJobScope and reg.scope.wall_budget_ms > 0 and
            reg.scope.maximum_segments > 0 and set(reg.artifact_pins) == ARTIFACT_ROLES and
            0 < len(reg.segment_pins) <= reg.scope.maximum_segments, "Exact native evidence inventory/scope required")
    require(reg.engine in {"PIVOT_MACRO_V2", "CANDLE_PATTERN_ATR_V3"} and
            reg.source_sha256 == source_digest() and reg.descriptor_sha256 == descriptor_digest() and
            all(bool(HASH.fullmatch(v)) for v in
                (reg.binary_sha256, reg.history_sha256, reg.history_anchor_sha256, reg.configuration_sha256)),
            "Registered native source/build pin mismatch")
    reg = replace(reg, parameters=tuple(reg.parameters),
                  native_fence_pin=None if reg.native_fence_pin is None else
                  (Path(reg.native_fence_pin[0]), reg.native_fence_pin[1]),
                  artifact_pins=MappingProxyType({key: (Path(pin[0]), pin[1])
                                                 for key, pin in reg.artifact_pins.items()}),
                  segment_pins=MappingProxyType({str(p): MappingProxyType(dict(pins))
                                                for p, pins in reg.segment_pins.items()}),
                  scope=replace(reg.scope, prepared_settings=MappingProxyType(dict(reg.scope.prepared_settings)),
                                loaded_configuration=MappingProxyType(dict(reg.scope.loaded_configuration))))

    artifacts = {role: _artifact(reg, role) for role in ARTIFACT_ROLES}
    pre, owned, native, report, history, anchor = (_json(artifacts[role]) for role in
                                         ("prelaunch", "owned_job", "native_result", "report_json", "history", "history_anchor"))
    require(set(report) == NATIVE_REPORT_KEYS and isinstance(report["run_id"], str) and
            isinstance(report["symbol"], str) and
            all(type(value) in {int, float} and math.isfinite(value) for key, value in report.items()
                if key not in {"run_id", "symbol"}), "Native report JSON field/type mismatch")
    _history_binding(reg, pre, anchor, history)
    require(owned["prelaunch"] == pre and owned["launch"] == native["launch"] and
            all(item["run_id"] == reg.native_run_id for item in
                (native["launch"], native["completion"], native["status"], native["configuration"], report)),
            "Native artifacts do not belong to the same registered job")
    require(native["completion"]["ok"] is True and native["completion"]["status"] == "stopped" and
            native["completion"]["timed_out"] is False and native["status"]["tester_status"] == "stopped" and
            type(native["case_wall_ms"]) is int and 0 <= native["case_wall_ms"] <= reg.scope.wall_budget_ms and
            owned["deadline_epoch_ms"] - owned["start_epoch_ms"] == reg.scope.wall_budget_ms,
            "Native job did not complete naturally within the approved deadline")
    require(native["physical_run_id"] == pre["physical_run_id"] == reg.physical_run_id and
            native["source_binary_pins"] == pre["source_binary_pins"] and
            pre["source_binary_pins"]["source_sha256"] == reg.source_sha256 and
            pre["source_binary_pins"]["descriptor_sha256"] == reg.descriptor_sha256,
            "Changed native source/build/physical identity")
    binary_name = "Pivot_Macro" if reg.engine == "PIVOT_MACRO_V2" else "Candle_Pattern_Discovery"
    require(pre["source_binary_pins"]["binary_pins"][binary_name]["sha256"] == reg.binary_sha256,
            "Changed registered native EX5 pin")
    cfg = native["configuration"]
    require(cfg["mql5_program_path"] == reg.program_path and
            {key: value for key, value in cfg.items() if key not in {"run_id", "mql5_program_path", "mql5_program_name"}} ==
            dict(reg.scope.loaded_configuration) and cfg["symbol"] == history["symbol"] == reg.symbol and
            cfg["date_from"] == history["date_from"] and cfg["date_to"] == history["date_to"],
            "Loaded native tester configuration changed")
    ini = pre["configuration"]
    require(cfg["tester_mode"] == "backtest" and cfg["model"] == "real ticks" and ini["Model"] == "4" and
            ini["Optimization"] == ini["ForwardMode"] == "0" and
            cfg["symbol"] == ini["Symbol"] and cfg["period"] == ini["Period"] and
            cfg["date_from"].replace("-", ".") == ini["FromDate"] and
            cfg["date_to"].replace("-", ".") == ini["ToDate"] and
            cfg["execution_delay"] == integer(ini["ExecutionMode"]) and
            cfg["visual_mode"] is (ini["Visual"] == "1") and
            cfg["profit_in_pips"] is (ini["ProfitInPips"] == "1") and
            cfg["deposit_currency"] == ini["Currency"] and cfg["leverage"] == "1:" + ini["Leverage"],
            "Prepared/loaded native setting inconsistency")
    require(ini == dict(reg.scope.prepared_settings) and
            reg.program_path == "Experts\\" + ini["Expert"],
            "Prepared/loaded native INI or program changed")
    cells = report_cells(artifacts["report_xlsx"])
    parameters = _parameters(reg, pre, cells)
    require(_label(cells, "Symbol:") == reg.symbol and
            _label(cells, "Period:") == reg.scope.report_period and
            _label(cells, "History Quality:") == "100% real ticks", "Native XLSX scope/quality changed")
    ticks, bars = report["generated_ticks"], report["generated_bars"]
    require(type(ticks) is int and ticks >= 0 and type(bars) is int and bars >= 0 and
            report["symbol"] == reg.symbol and _label(cells, "Ticks:") == f"{ticks}.000000" and
            _label(cells, "Bars:") == f"{bars}.000000", "Native generated counter disagreement")
    journal = native["journal"]
    require(journal["truncated"] is False and journal["records_count"] == len(journal["records"]),
            "Truncated native job journal")
    messages = [row["message"] for row in journal["records"]]
    counters = [match.groups() for message in messages for match in
                re.finditer(r"\b([0-9]+) ticks, ([0-9]+) bars generated\b", message)]
    require(counters == [(str(ticks), str(bars))] and
            sum(bool(re.search(r"\btest passed\b", message, re.I)) for message in messages) == 1 and
            not any(re.search(r"\btest (?:stopped|aborted|cancelled)\b", message, re.I) for message in messages),
            "Native natural-completion/generated journal evidence missing")
    # Imports are local to avoid an import cycle; wire parsing remains source-owned.
    from .continuation_reader import metadata, records
    totals = dict.fromkeys(("input_count", "tick_count", "timer_count", "trade_count",
                            "fresh_quote_count", "stale_quote_count", "missing_quote_count",
                            "stale_tick_count", "stale_trade_count", "unavailable_count"), 0)
    last_input, last_record = reg.replay_prefix_input, reg.replay_prefix_record
    last_chain = reg.replay_prefix_chain
    segments = {}
    original_paths = sorted((Path(p) for p in reg.segment_pins), key=lambda p: p.name)
    for ordinal, path in enumerate(original_paths, 1):
        expected = reg.segment_pins[str(path)] if str(path) in reg.segment_pins else reg.segment_pins[path]
        require(path.name == f"{ordinal:08d}" and set(expected) == set(FILES) and
                {p.name for p in path.iterdir()} == set(FILES), "Registered full native segment inventory changed")
        actual = {name: file_sha256(path / name) for name in FILES}
        require(actual == expected, "Substituted original native capture bytes")
        manifest, seal = metadata(path / "segment_manifest.tsv"), metadata(path / "segment_seal.tsv")
        require(manifest["physical_run_id"] == reg.physical_run_id and manifest["origin"] == "TESTER" and
                manifest["core_run_id"] == parameters["Intake_Session_Id"] and
                manifest["source_id"] == parameters["Intake_Source_Id"] and
                manifest["configuration_proof"] == reg.configuration_sha256,
                "Native original source/configuration mapping changed")
        for row in records(path / "input_events.tsv", FILES["input_events.tsv"]):
            first, last = integer(row["first_input_ordinal"]), integer(row["last_input_ordinal"])
            require(first == last_input + 1 and integer(row["record_ordinal"]) == last_record + 1 and
                    last >= first and integer(row["input_count"]) == last - first + 1,
                    "Registered native capture dropped/repeated input")
            values = {key: integer(row[key]) for key in totals}
            require(all(value >= 0 for value in values.values()) and
                    values["input_count"] == values["tick_count"] + values["timer_count"] + values["trade_count"] and
                    values["input_count"] == values["fresh_quote_count"] + values["stale_quote_count"] + values["missing_quote_count"] and
                    values["input_count"] == integer(row["available_count"]) + values["unavailable_count"] and
                    integer(row["available_count"]) >= 0 and
                    values["stale_tick_count"] <= values["tick_count"] and
                    values["stale_trade_count"] <= values["trade_count"] and
                    values["stale_tick_count"] + values["stale_trade_count"] <= values["stale_quote_count"],
                    "Native input type/quote count partition mismatch")
            for key in totals:
                totals[key] += values[key]
            last_input, last_record, last_chain = last, integer(row["record_ordinal"]), row["input_chain_sha256"]
        require(integer(seal["last_input_ordinal"]) == last_input and
                integer(seal["last_record_ordinal"]) == last_record and seal["input_chain_sha256"] == last_chain,
                "Native whole-input chain/ordinal mismatch")
        segments[ordinal] = MappingProxyType(actual)
    require(seal["completion"] == "TERMINAL" and manifest["segment_phase"] == "TERMINAL" and
            seal["core_summary_export_status"] == "OK" and
            seal["core_summary_completion_status"] == "NATURAL" and seal["core_summary_failure"] == "NONE" and
            totals["tick_count"] + reg.replay_prefix_ticks == ticks and
            totals["input_count"] == totals["tick_count"] + totals["timer_count"] + totals["trade_count"] and
            totals["missing_quote_count"] == totals["stale_tick_count"] ==
            totals["stale_trade_count"] == totals["unavailable_count"] == 0,
            "Native completed delivered stream is missing/duplicated/unavailable")
    require(reg.replay_prefix_ticks >= 0 and reg.replay_prefix_input >= reg.replay_prefix_ticks and
            (reg.replay_witness_proof is not None or
             (reg.replay_prefix_input == reg.replay_prefix_record == reg.replay_prefix_ticks == 0)),
            "Unauthenticated replay prefix counter")
    result = object.__new__(VerifiedTesterDelivery)
    for key, value in (("registration", reg), ("segments", MappingProxyType(segments)),
                       ("totals", MappingProxyType(totals)), ("generated_ticks", ticks), ("generated_bars", bars)):
        object.__setattr__(result, key, value)
    _ISSUED.add(result)
    return result


def authenticate_tester_delivery(registry: NativeJobRegistry, job_key: str) -> VerifiedTesterDelivery:
    try:
        return _authenticate_tester_delivery(registry, job_key)
    except (KeyError, TypeError, AttributeError, IndexError, OSError) as exc:
        raise ContractError("Malformed original native evidence or registration") from exc

