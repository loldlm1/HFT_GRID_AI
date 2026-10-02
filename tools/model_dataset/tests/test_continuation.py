"""Offline adversarial continuation cases. These are not native producer receipts."""
import hashlib
import math
import struct
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from ..continuation_contract import (
    ENGINES, FILES, ORIGIN_POLICIES, PROFILES, TRANSACTION_FIELDS, WITNESS_FILES, ZERO,
    descriptor, descriptor_digest, source_digest,
)
from ..continuation_reader import (
    ContinuationArchive, VerifiedClosure, VerifiedNativeFence, bootstrap_witness, build_witness,
    canonical_state, chain, metadata, native_float64, native_text, unhex, validate_state_value,
    write_metadata, write_rows,
)
from ..reader import ContractError, ModelRun
from ..schema_contract import LEVELS, NULL, SUMMARY_CLOCKS, clock_companions
from ..clock import analysis_clock
from .fixtures import NOW, clocks, make_run, rewrite


def envelope(text):
    return text.encode().hex() if text else "-"


def float64(value):
    return struct.pack(">d", value).hex()


def state_rows(engine, boundary, *, pending=False, terminal=False, completed=False):
    contract = descriptor()
    rows = []
    references = {
        ("SHARED_CONTROL", "g_model_window_id"): "W",
        ("PIVOT_SIGNAL", "origin_id"): "S", ("PIVOT_SIGNAL", "window_id"): "W",
        ("PIVOT_DEFERRED_CLOSE", "origin_id"): "S",
        ("PIVOT_PENDING_ORIGIN", "origin.origin_id"): "S",
        ("PIVOT_PENDING_ORIGIN", "origin.window_id"): "W",
        ("PIVOT_PARITY", "origin_id"): "S",
        ("PIVOT_TRIAL", "trial.identity.origin_id"): "S",
        ("PIVOT_TRIAL", "trial.identity.window_id"): "W",
        ("CANDLE_BROKER", "attempt.id"): "A0", ("CANDLE_BROKER", "attempt.root_id"): "S",
        ("CANDLE_VIRTUAL", "attempt_id"): "A0",
    }
    for component in contract["profiles"][engine]["components"]:
        spec = contract["state_registry"][component]
        count = (1 if pending else 0) if spec.get("indexed") else 1
        if spec.get("indexed"):
            rows.append(dict(boundary=boundary, component=component, object_id="0",
                             field="_count", value_type="INT", value=str(count)))
        for index in range(count):
            for field in spec["fields"]:
                kind = field["value_type"]
                value = "-" if kind == "TEXT" else ZERO if kind == "HASH" else float64(0.0) if kind == "FLOAT64" else "0"
                if pending and (component, field["field"]) in references:
                    value = envelope(references[component, field["field"]])
                if field["field"] in {"g_pivot_run_finalized", "g_candle_stopping"}:
                    value = str(int(terminal))
                if field["field"] in {"g_tester_interval_completed", "g_candle_tester_interval_completed"}:
                    value = str(int(completed))
                rows.append(dict(boundary=boundary, component=component, object_id=str(index),
                                 field=field["field"], value_type=kind, value=value))
    return rows


def state_digest(rows):
    result = ZERO
    for row in rows:
        result = chain(result, canonical_state(row))
    return result


def input_block(first, record, time, previous=ZERO, *, gap=0, stale=False, trade=False):
    quote = envelope(f"{time//1000}\t{time}\t{float64(101.0)}\t{float64(101.1)}\t{float64(0.0)}\t0\t{float64(0.0)}\t6")
    transaction = "-"
    if trade:
        cells = ["-" if kind == "TEXT" else ZERO if kind == "HASH" else float64(0.0) if kind == "FLOAT64" else "0" for _, kind in TRANSACTION_FIELDS]
        cells[16] = "0"
        cells[17:] = [NULL] * (len(cells) - 17)
        transaction = envelope("\t".join(cells))
    callback = "TRADE" if trade else "TIMER"
    canonical = f"{first}\t{callback}\t0\t{time}\t{quote}\t{transaction}\t1\t1\t1\r\n".encode()
    return dict(
        record_ordinal=str(record), first_input_ordinal=str(first), last_input_ordinal=str(first),
        boundary_callback=callback, first_broker_time_msc=str(time), last_broker_time_msc=str(time),
        first_observer_time_msc=str(time), observer_time_msc=str(time),
        first_monotonic_us=str(record*1000000), monotonic_us=str(record*1000000),
        input_count="1", available_count="1", unavailable_count="0",
        tick_count="0", timer_count="0" if trade else "1", trade_count="1" if trade else "0",
        input_chain_sha256=chain(previous, canonical), quote_hex=quote, connected="1", synchronized="1",
        acquisition="TESTER_CALLBACK_ACQUIRED", transaction_hex=transaction,
        maximum_quote_age_msc="4000" if stale else "0", last_quote_age_msc="4000" if stale else "0",
        broker_estimate_time_msc=str(time+(4000 if stale else 0)), history_observations="0", history_chain_sha256=ZERO,
        maximum_observer_gap_msc="0", maximum_monotonic_gap_us="0",
        capture_status="OBSERVED_CALLBACK_ONLY", quote_status="STALE_CACHED_QUOTE" if stale else "FRESH_NATIVE_QUOTE",
        fresh_quote_count="0" if stale else "1", stale_quote_count="1" if stale else "0", missing_quote_count="0",
        stale_tick_count="0", stale_trade_count="1" if stale and trade else "0",
    )


class SourceFixture:
    """Independent small old typed fixture wrapped in explicitly phased source rows."""
    def __init__(self, root, engine):
        self.root, self.engine = root, engine
        self.legacy = root / "LEGACY"
        tables = make_run(self.legacy, engine)
        window = tables["macro_windows.tsv"][0]
        window.update(first_observed_time_msc=str(NOW), first_observed_bid="101",
                      terminal_time_msc=str(NOW+4000), terminal_status="RUN_END")
        for row in tables["outcomes.tsv"]:
            row["exit_time_msc"] = row["observed_time_msc"] = str(int(row["entry_time_msc"])+1000)
            row["duration_ms"] = "1000"
        summary = {r["key"]: r["value"] for r in tables["run_summary.tsv"]}
        summary["last_time_msc"] = str(NOW+4000)
        for key in SUMMARY_CLOCKS:
            analysis, offset = analysis_clock(int(summary[key]), "FIXED_TIME_SESSIONS")
            summary.update(zip(clock_companions(key), (str(analysis), str(offset), "SECOND")))
        tables["run_summary.tsv"] = [{"key": k, "value": v} for k, v in summary.items()]
        rewrite(self.legacy, tables)
        self.tables = tables
        core = {r["key"]: r["value"] for r in tables["run_manifest.tsv"]}
        core["run_id"] = "SESSION"
        core_raw = "".join(r["key"]+"\t"+core[r["key"]]+"\r\n" for r in tables["run_manifest.tsv"])
        self.manifest = dict(
            family="MQL5_MODEL_CONTINUATION", continuation_version="1", descriptor_sha256=descriptor_digest(),
            engine=engine, origin="TESTER", source_id="SOURCE", session_id="SESSION", physical_run_id="PHYSICAL",
            canonical_run_id="SESSION", source_proof=source_digest(), configuration_proof=hashlib.sha256(core_raw.encode()).hexdigest(), history_proof="3"*64,
            segment_ordinal="1", segment_seconds="3600", predecessor_seal="NONE", predecessor_state_sha256="NONE",
            replay_witness_id=NULL, replay_witness_proof=NULL,
        )
        self.manifest.update({"core_"+r["key"]: core[r["key"]] for r in tables["run_manifest.tsv"]})
        self.manifest.update(
            core_manifest_sha256=hashlib.sha256(core_raw.encode()).hexdigest(),
            weekly_quote_sessions_hex="-", weekly_trade_sessions_hex="-",
            session_schedule_observed_time_msc=str(NOW),
            **ORIGIN_POLICIES["TESTER"], segment_phase="CAPTURE",
        )
        window = tables["macro_windows.tsv"][0]
        birth = {k: window[k] for k in FILES["window_births.tsv"][2:]
                 if k not in {"raw_prices_hex", "trade_prices_hex"}}
        birth.update(birth_ordinal="1", input_ordinal="1",
                     raw_prices_hex=envelope("\t".join(window["raw_"+k.lower()+"_price"] for k in LEVELS)),
                     trade_prices_hex=envelope("\t".join(window["trade_"+k.lower()+"_price"] for k in LEVELS)))
        self.birth = birth
        self.prefix_facts, self.terminal_facts = [], []
        ordinal = 0
        for table in PROFILES[engine].tables:
            if table.name in {"run_manifest.tsv", "run_summary.tsv", "macro_windows.tsv", "outcomes.tsv"}:
                continue
            for row in tables[table.name]:
                ordinal += 1
                self.prefix_facts.append(self.fact(table, row, ordinal, 1, "CAPTURE"))
        for name in ("macro_windows.tsv", "outcomes.tsv"):
            table = next(t for t in PROFILES[engine].tables if t.name == name)
            for row in tables[name]:
                ordinal += 1
                self.terminal_facts.append(self.fact(table, row, ordinal, 2, "TERMINAL"))
        self.summary = {r["key"]: r["value"] for r in tables["run_summary.tsv"]}

    def live(self):
        self.manifest.update(origin="LIVE_DEMO", **ORIGIN_POLICIES["LIVE_DEMO"])
        return self

    @staticmethod
    def fact(table, row, ordinal, input_ordinal, phase):
        complete = clocks(table.name, row, "FIXED_TIME_SESSIONS")
        complete["run_id"] = "SESSION"
        payload = "\t".join(NULL if complete[k] is None else complete[k] for k in table.columns)
        return dict(fact_ordinal=str(ordinal), input_ordinal=str(input_ordinal), phase=phase,
                    table_name=table.name, row_key=envelope(row[table.key]), payload_hex=envelope(payload))

    def segment(self, ordinal, *, completion="ROTATED", previous=None, facts=None, births=None, inputs=None,
                start=None, end=None, physical="PHYSICAL", witness=NULL):
        path = self.root / physical / f"{ordinal:08d}"
        m = dict(self.manifest)
        m.update(segment_ordinal=str(ordinal), physical_run_id=physical,
                 replay_witness_id=witness, replay_witness_proof=NULL if witness == NULL else "4"*64)
        last_input = 0 if previous is None else int(previous["seal"]["last_input_ordinal"])
        last_fact = 0 if previous is None else int(previous["seal"]["last_fact_ordinal"])
        last_birth = 0 if previous is None else int(previous["seal"]["last_birth_ordinal"])
        last_record = 0 if previous is None else int(previous["seal"]["last_record_ordinal"])
        last_chain = ZERO if previous is None else previous["seal"]["input_chain_sha256"]
        if previous:
            m.update(predecessor_seal=previous["seal_chain"], predecessor_state_sha256=previous["end_digest"])
        if inputs is None:
            inputs = [input_block(last_input+1, last_record+1, NOW if previous is None else NOW+1000, last_chain)]
        if m["origin"] == "LIVE_DEMO":
            inputs = [dict(row, acquisition="UNAVAILABLE" if int(row["stale_quote_count"]) else "FRESH_CALLBACK_STREAM",
                           available_count=str(int(row["input_count"])-int(row["stale_quote_count"])),
                           unavailable_count=row["stale_quote_count"]) for row in inputs]
        if facts is None:
            facts = self.prefix_facts if previous is None else []
        if births is None:
            births = [self.birth] if previous is None else []
        if start is None:
            start = state_rows(self.engine, "START") if previous is None else [
                dict(row, boundary="START") for row in previous["end"]]
        if end is None:
            end = state_rows(self.engine, "END", pending=True,
                             terminal=completion in {"TERMINAL", "INTERRUPTED"},
                             completed=completion == "TERMINAL")
        if completion in {"TERMINAL", "INTERRUPTED"}:
            m["segment_phase"] = "TERMINAL"
        proofs = {"segment_manifest.tsv": write_metadata(path/"segment_manifest.tsv", m)}
        for name, rows in (("input_events.tsv", inputs), ("fact_events.tsv", facts),
                           ("window_births.tsv", births), ("state_checkpoint.tsv", start+end)):
            proofs[name] = write_rows(path/name, FILES[name], rows)
        seal = {}
        for name, proof in proofs.items():
            seal.update({f"rows_{name}": str(proof.rows), f"bytes_{name}": str(proof.bytes), f"chain_{name}": proof.chain})
        seal.update(completion=completion, first_input_ordinal=str(last_input+1),
                    last_input_ordinal=str(last_input if not inputs else int(inputs[-1]["last_input_ordinal"])),
                    first_fact_ordinal=str(last_fact+1), last_fact_ordinal=str(last_fact if not facts else int(facts[-1]["fact_ordinal"])),
                    first_birth_ordinal=str(last_birth+1), last_birth_ordinal=str(last_birth if not births else int(births[-1]["birth_ordinal"])),
                    first_record_ordinal=str(last_record+1), last_record_ordinal=str(last_record if not inputs else int(inputs[-1]["record_ordinal"])),
                    input_chain_sha256=last_chain if not inputs else inputs[-1]["input_chain_sha256"], end_state_sha256=state_digest(end))
        if completion in {"TERMINAL", "INTERRUPTED"}:
            seal.update({"core_summary_"+key: value for key, value in self.summary.items()})
            seal["core_summary_buffer_peak"] = "256"  # Physical writer difference, explicitly classified.
        proof = write_metadata(path/"segment_seal.tsv", seal)
        return dict(path=path, seal=seal, seal_chain=proof.chain, end=end, end_digest=state_digest(end), inputs=inputs)

    def fence(self, segments, *, safe_cursor=1, first_effect=3):
        # Synthetic protocol binding only: never a native source-owner receipt.
        return VerifiedNativeFence(descriptor_digest(), self.manifest["source_proof"], self.manifest["configuration_proof"], "3"*64,
                                   self.manifest["core_manifest_sha256"], segments[-1]["seal_chain"],
                                   first_effect, safe_cursor, "a"*64)

    def whole(self):
        first = self.segment(1)
        before = self.segment(2, completion="PRE_FINALIZATION", previous=first,
                              end=state_rows(self.engine, "END", pending=True, completed=True))
        terminal = self.segment(3, completion="TERMINAL", previous=before, inputs=[], facts=self.terminal_facts)
        return [first, before, terminal]


class ContinuationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # These existing fixtures exercise source wire/state only, not native authority.
        # Separate native_evidence tests verify the real registry/parser boundary.
        native = patch.object(ContinuationArchive, "_verify_native_delivery", return_value=None)
        native.start()
        self.addCleanup(native.stop)

    def fixture(self, engine=ENGINES[0]):
        return SourceFixture(self.root / engine, engine)

    def accept(self, segments, **kwargs):
        with ContinuationArchive([s["path"] for s in segments], **kwargs) as archive:
            archive.verify_unchanged()
            return archive.report()

    def reject(self, segments, message=None, **kwargs):
        with self.assertRaisesRegex(ContractError, message or ".*"):
            self.accept(segments, **kwargs)

    def test_native_null_text_remains_distinct_from_empty_checkpoint(self):
        self.assertIsNone(native_text(NULL))
        self.assertEqual(native_text("-"), "")
        for engine in ENGINES:
            f = self.fixture(engine)
            end = state_rows(engine, "END", pending=True)
            target = next(row for row in end if row["component"] == "SHARED_CONTROL"
                          and row["value_type"] == "TEXT" and row["value"] == "-")
            target["value"] = NULL
            a = f.segment(1, end=end)
            b = f.segment(2, previous=a)
            self.assertEqual(self.accept([a, b])["segments"], 2)
            start = [dict(row, boundary="START") for row in end]
            next(row for row in start if row["field"] == target["field"]
                 and row["component"] == target["component"])["value"] = "-"
            f = SourceFixture(self.root / (engine + "_NEG_1"), engine)
            a = f.segment(1, end=end)
            changed = f.segment(2, previous=a, start=start)
            self.reject([a, changed], "Reset/omitted")

    def test_native_null_transaction_symbol_is_typed_not_generic_envelope(self):
        f = self.fixture()
        block = input_block(1, 1, NOW, trade=True)
        cells = unhex(block["transaction_hex"]).split("\t")
        cells[3] = NULL
        block["transaction_hex"] = envelope("\t".join(cells))
        a = f.segment(1, inputs=[block])
        self.assertEqual(self.accept([a])["input_callbacks"], 1)
        with self.assertRaises(ContractError):
            unhex(NULL)
        for kind in ("INT", "HASH", "FLOAT64"):
            with self.subTest(kind=kind), self.assertRaises(ContractError):
                validate_state_value(kind, NULL)

    def test_native_float64_preserves_empty_value_zero_and_smallest_bits(self):
        values = ("0000000000000000", "8000000000000000", "0000000000000001",
                  "3ca0000000000000", "7fefffffffffffff")
        for value in values:
            decoded = native_float64(value)
            self.assertEqual(float64(decoded), value)
        self.assertEqual(math.copysign(1.0, native_float64(values[1])), -1.0)
        self.assertGreater(native_float64(values[2]), 0.0)
        self.assertGreater(native_float64(values[-1]), 1e308)
        for engine in ENGINES:
            f = self.fixture(engine)
            end = state_rows(engine, "END", pending=True)
            fields = [row for row in end if row["value_type"] == "FLOAT64"]
            for row, value in zip(fields, values, strict=False):
                row["value"] = value
            a = f.segment(1, end=end)
            b = f.segment(2, previous=a)
            self.assertEqual(self.accept([a, b])["segments"], 2)
            start = [dict(row, boundary="START") for row in end]
            target = next(row for row in start if row["value_type"] == "FLOAT64")
            target["value"] = "0000000000000001"
            f = SourceFixture(self.root / (engine + "_NEG_2"), engine)
            a = f.segment(1, end=end)
            changed = f.segment(2, previous=a, start=start)
            self.reject([a, changed], "Reset/omitted")

    def test_native_float64_nonfinite_and_alias_forms_refused(self):
        for value in ("7ff0000000000000", "fff0000000000000", "7ff8000000000000",
                      "7FEFFFFFFFFFFFFF", "0", "000000000000000", NULL):
            with self.subTest(value=value), self.assertRaises(ContractError):
                native_float64(value)

    def test_both_typed_profiles_pending_rotation_and_old_readers(self):
        for engine in ENGINES:
            with self.subTest(engine=engine):
                f = self.fixture(engine)
                a = f.segment(1)
                b = f.segment(2, previous=a)
                self.assertEqual(self.accept([a, b])["input_callbacks"], 2)
                with ModelRun(f.legacy) as legacy:
                    self.assertEqual(legacy.profile.engine, engine)

    def test_quiet_callback_capture_is_independent_of_signals(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            a = f.segment(1, facts=[], births=[], end=state_rows(engine, "END"))
            self.assertEqual(self.accept([a])["facts"], 0)

    def test_tester_stale_timer_keeps_raw_quote_status_without_invented_closure(self):
        f = self.fixture()
        a = f.segment(1, inputs=[input_block(1, 1, NOW, stale=True)])
        self.assertEqual(self.accept([a])["input_callbacks"], 1)
        self.assertEqual(a["inputs"][0]["stale_quote_count"], "1")
        self.assertEqual(a["inputs"][0]["available_count"], "1")

    def test_tester_stale_trade_and_bad_quote_partition_refused(self):
        f = self.fixture()
        a = f.segment(1, inputs=[input_block(1, 1, NOW, stale=True, trade=True)])
        self.reject([a], "Unsupported native tester")
        f = SourceFixture(self.root/"BAD_PARTITION", f.engine)
        row = input_block(1, 1, NOW)
        row["stale_quote_count"] = "1"
        a = f.segment(1, inputs=[row])
        self.reject([a], "quote-status count partition")

    def test_clock_and_origin_policy_are_exact_not_caller_labels(self):
        f = self.fixture()
        f.manifest["observer_clock_basis"] = "UTC_SECONDS"
        a = f.segment(1)
        self.reject([a], "acquisition/clock/source-quality")

    def test_changed_tuple_and_exact_inventory(self):
        f = self.fixture()
        a = f.segment(1)
        (a["path"]/"unrecognized.tsv").write_bytes(b"")
        self.reject([a], "Exact six-file")

    def test_partial_seal_is_not_publishable(self):
        f = self.fixture()
        a = f.segment(1)
        (a["path"]/"segment_seal.tsv").rename(a["path"]/"segment_seal.partial")
        self.reject([a], "Exact six-file")

    def test_tampered_payload_and_partial_row(self):
        f = self.fixture()
        a = f.segment(1)
        file = a["path"]/"input_events.tsv"
        file.write_bytes(file.read_bytes().rstrip())
        self.reject([a], "Partial/oversized")

    def test_fork_reset_and_identity_substitution(self):
        f = self.fixture()
        a = f.segment(1)
        b = f.segment(2, previous=a, start=state_rows(f.engine, "START"))
        self.reject([a, b], "Reset/omitted")
        c = f.segment(1, previous=a, physical="RESTART")
        self.reject([a, c], "Unproven native restart")

    def test_explicit_tester_replay_mapping(self):
        f = self.fixture()
        a = f.segment(1)
        b = f.segment(1, previous=a, physical="REPLAY", witness="WITNESS")
        self.assertEqual(self.accept([a, b])["segments"], 2)

    def test_alias_object_and_missing_field_refused(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            end = state_rows(engine, "END", pending=True)
            end[0]["object_id"] = "-0"
            a = f.segment(1, end=end)
            self.reject([a], "noncanonical")

    def test_missing_health_flag_refused(self):
        f = self.fixture()
        end = [r for r in state_rows(f.engine, "END", pending=True) if r["field"] != "g_model_failed"]
        a = f.segment(1, end=end)
        self.reject([a], "Omitted/extra semantic")

    def test_pending_object_reference_refused(self):
        f = self.fixture()
        end = state_rows(f.engine, "END", pending=True)
        next(r for r in end if r["component"] == "PIVOT_PENDING_ORIGIN" and r["field"] == "origin.origin_id")["value"] = envelope("MISSING")
        a = f.segment(1, end=end)
        self.reject([a], "pending-state reference")

    def test_anchor_cannot_reference_future_facts(self):
        f = self.fixture()
        a = f.segment(1, start=state_rows(f.engine, "START", pending=True))
        self.reject([a], "pending-state reference")

    def test_capture_cannot_extend_pre_finalization(self):
        f = self.fixture()
        a = f.segment(1, completion="PRE_FINALIZATION")
        b = f.segment(2, previous=a)
        self.reject([a, b], "Pre-finalization state")

    def test_terminal_health_is_explicit(self):
        f = self.fixture()
        a = f.segment(1, completion="PRE_FINALIZATION", end=state_rows(f.engine, "END", pending=True, completed=True))
        b = f.segment(2, completion="TERMINAL", previous=a, inputs=[], facts=[],
                      end=state_rows(f.engine, "END", pending=True))
        self.reject([a, b], "finalization lifecycle")

    def test_natural_and_interrupted_terminal_need_actual_completion(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            a = f.segment(1, completion="PRE_FINALIZATION")
            interrupted = f.segment(2, completion="INTERRUPTED", previous=a, inputs=[], facts=[])
            self.accept([a, interrupted])
            f = SourceFixture(self.root / (engine + "_NEGATIVE"), engine)
            a = f.segment(1, completion="PRE_FINALIZATION")
            end = state_rows(engine, "END", pending=True, terminal=True, completed=True)
            interrupted = f.segment(2, completion="INTERRUPTED", previous=a, inputs=[], facts=[], end=end)
            self.reject([a, interrupted], "matching tester completion")

    def test_unsupported_acquisition_refused(self):
        f = self.fixture().live()
        a = f.segment(1, inputs=[input_block(1, 1, NOW, stale=True)])
        self.reject([a], "Unsupported feed")

    def test_active_gap_and_independently_evidenced_closure(self):
        f = self.fixture().live()
        a = f.segment(1)
        b = f.segment(2, previous=a, inputs=[input_block(2, 2, NOW+10000, a["seal"]["input_chain_sha256"])])
        self.reject([a, b], "Missing active capture")
        receipt = VerifiedClosure(NOW, NOW+10000, f.manifest["history_proof"], "CALENDAR_R1", "7"*64, "UTC")
        self.assertEqual(self.accept([a, b], closures=[receipt])["calendar_evidence"], 1)
        bad = VerifiedClosure(NOW, NOW+10000, "8"*64, "CALENDAR_R1", "7"*64, "UTC")
        self.reject([a, b], "Missing active capture", closures=[bad])

    def test_missing_canonical_callback_ordinal_refused(self):
        f = self.fixture()
        a = f.segment(1, inputs=[input_block(2, 1, NOW)])
        self.reject([a], "Dropped/repeated canonical")

    def test_consumed_history_checkpoint_binding(self):
        f = self.fixture()
        block = input_block(1, 1, NOW)
        block["history_observations"], block["history_chain_sha256"] = "1", "9"*64
        a = f.segment(1, inputs=[block])
        self.reject([a], "consumed-history prefix")

    def test_full_transaction_envelope_and_unfilled_request(self):
        f = self.fixture()
        a = f.segment(1, inputs=[input_block(1, 1, NOW, trade=True)])
        self.assertEqual(self.accept([a])["input_callbacks"], 1)

    def test_physical_monotonic_reset_inside_first_segment(self):
        f = self.fixture()
        first = input_block(1, 1, NOW)
        second = input_block(2, 2, NOW+1000, first["input_chain_sha256"])
        second["first_monotonic_us"] = second["monotonic_us"] = "0"
        a = f.segment(1, inputs=[first, second])
        self.reject([a], "Unproved process reset")

    def test_new_source_witness_stream_and_immutable_refusal(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            a = f.segment(1)
            with ContinuationArchive([a["path"]]) as archive:
                target = self.root / ("WITNESS_"+engine)
                pin = build_witness(archive, target, native_fence=f.fence([a]))
                proof = {}
                m = metadata(target/"witness_manifest.tsv", proof)
                self.assertEqual(m["legacy_source_proof"], "NONE")
                self.assertEqual(set(p.name for p in target.iterdir()), set(WITNESS_FILES))
                self.assertEqual(proof["witness_manifest.tsv"].rows, len(m))
                self.assertEqual(len(pin), 64)
                with self.assertRaisesRegex(ContractError, "Fresh owned"):
                    build_witness(archive, target, native_fence=f.fence([a]))

    def test_bootstrap_compares_whole_then_only_actual_extendable_prefix(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            segments = f.whole()
            with ContinuationArchive([s["path"] for s in segments]) as archive:
                receipt = bootstrap_witness(archive, f.legacy, 1, self.root/("BOOTSTRAP_"+engine), native_fence=f.fence(segments))
                self.assertTrue(receipt["terminal_branch_retained"])
                self.assertEqual(receipt["whole_source_proof"]["physical_writer_metrics"]["buffer_peak"],
                                 {"legacy": "1", "paired": "256"})
                witness = metadata(self.root/("BOOTSTRAP_"+engine)/"witness_manifest.tsv")
                self.assertEqual(witness["last_input_ordinal"], "1")
                self.assertEqual(witness["legacy_source_proof"], receipt["whole_source_proof"]["proof_sha256"])
                with self.assertRaisesRegex(ContractError, "pre-finalization"):
                    build_witness(archive, self.root/"TERMINAL_WITNESS")
                with self.assertRaisesRegex(ContractError, "earlier ROTATED"):
                    bootstrap_witness(archive, f.legacy, 2, self.root/"FAKE_RETROSPECTIVE")

    def test_whole_legacy_mismatch_is_not_a_valid_bootstrap(self):
        f = self.fixture()
        segments = f.whole()
        with ContinuationArchive([s["path"] for s in segments]) as archive:
            f.tables["signal_events.tsv"][0]["bid"] = "93"
            rewrite(f.legacy, f.tables)
            with self.assertRaises(ContractError):
                bootstrap_witness(archive, f.legacy, 1, self.root/"REJECTED_BOOTSTRAP", native_fence=f.fence(segments))
            self.assertFalse((self.root/"REJECTED_BOOTSTRAP").exists())

    def test_unknown_semantic_profile_refused(self):
        f = self.fixture()
        a = f.segment(1)
        path = a["path"]/"segment_manifest.tsv"
        data = path.read_bytes().replace(b"PIVOT_MACRO_V2", b"PIVOT_MACRO_V1")
        path.write_bytes(data)
        self.reject([a], "Unsupported continuation")

    def test_missing_native_fence_and_tester_end_contamination_refused(self):
        f = self.fixture()
        segments = f.whole()
        with ContinuationArchive([segments[0]["path"]]) as prefix:
            with self.assertRaisesRegex(ContractError, "Independent native"):
                build_witness(prefix, self.root/"NO_NATIVE_PROOF")
        with ContinuationArchive([s["path"] for s in segments]) as archive:
            with self.assertRaisesRegex(ContractError, "Independent native"):
                bootstrap_witness(archive, f.legacy, 1, self.root/"NO_BOOTSTRAP_PROOF")
            with self.assertRaisesRegex(ContractError, "first native"):
                bootstrap_witness(archive, f.legacy, 1, self.root/"TOO_LATE", native_fence=f.fence(segments, safe_cursor=3, first_effect=3))

    def test_minute_block_requires_per_callback_maximum_gap(self):
        f = self.fixture().live()
        block = input_block(1, 1, NOW+60000)
        block.update(first_input_ordinal="1", last_input_ordinal="61", input_count="61", timer_count="61",
                     available_count="61", fresh_quote_count="61", first_broker_time_msc=str(NOW), first_observer_time_msc=str(NOW),
                     first_monotonic_us="0", monotonic_us="60000000",
                     maximum_observer_gap_msc="1000", maximum_monotonic_gap_us="1000000")
        a = f.segment(1, inputs=[block])
        self.assertEqual(self.accept([a])["input_callbacks"], 61)

    def test_hidden_gap_inside_block_refused(self):
        f = self.fixture().live()
        block = input_block(1, 1, NOW+60000)
        block.update(first_input_ordinal="1", last_input_ordinal="61", input_count="61", timer_count="61",
                     available_count="61", fresh_quote_count="61", first_broker_time_msc=str(NOW), first_observer_time_msc=str(NOW),
                     first_monotonic_us="0", monotonic_us="60000000",
                     maximum_observer_gap_msc="10000", maximum_monotonic_gap_us="10000000")
        a = f.segment(1, inputs=[block])
        self.reject([a], "Unobserved interval inside")

    def test_skewed_per_object_state_fields_refused(self):
        f = self.fixture("CANDLE_PATTERN_ATR_V3")
        end = state_rows(f.engine, "END", pending=True)
        spec = descriptor()["state_registry"]["CANDLE_BROKER"]
        extra = [dict(r, object_id="1") for r in end if r["component"] == "CANDLE_BROKER" and r["field"] != "_count"]
        count = next(r for r in end if r["component"] == "CANDLE_BROKER" and r["field"] == "_count")
        count["value"] = "2"
        end.extend(extra)
        # Preserve total count and numeric index coverage while skewing object fields.
        moved = next(r for r in end if r["component"] == "CANDLE_BROKER" and r["object_id"] == "1" and r["field"] == spec["fields"][0]["field"])
        moved["object_id"] = "0"
        a = f.segment(1, end=end)
        self.reject([a], "Duplicate semantic")

    def test_late_outcome_for_old_entry_uses_verified_fact_ordinal(self):
        for engine in ENGINES:
            f = self.fixture(engine)
            a = f.segment(1)
            original = next(row for row in f.terminal_facts if row["table_name"] == "outcomes.tsv")
            late = dict(original, fact_ordinal=str(len(f.prefix_facts)+1), input_ordinal="2", phase="CAPTURE")
            b = f.segment(2, previous=a, facts=[late],
                          inputs=[input_block(2, 2, NOW+2000, a["seal"]["input_chain_sha256"])])
            self.assertEqual(self.accept([a,b])["facts"], len(f.prefix_facts)+1)

    def test_terminal_facts_cannot_be_active_capture(self):
        f = self.fixture()
        a = f.segment(1)
        fact = dict(f.terminal_facts[0], fact_ordinal=str(len(f.prefix_facts)+1), input_ordinal="2")
        b = f.segment(2, previous=a, facts=[fact])
        self.reject([a,b], "Unclassified terminal")

    def test_dataset_callback_accounting_does_not_infer_coverage_from_hash(self):
        f = self.fixture()
        block = input_block(1, 1, NOW)
        block["input_count"] = "2"
        a = f.segment(1, inputs=[block])
        self.reject([a], "Incomplete canonical input")

    def test_unanchored_startup_checkpoint_refused(self):
        for engine in ("PIVOT_MACRO_V2", "CANDLE_PATTERN_ATR_V3"):
            f = self.fixture(engine)
            start = state_rows(engine, "START")
            next(row for row in start if row["field"] == "g_cont_anchor_pending")["value"] = "1"
            a = f.segment(1, start=start)
            self.reject([a], "Unanchored startup checkpoint")

    def test_startup_policy_cannot_adopt_another_origin(self):
        f = self.fixture()
        f.manifest["startup_state_policy"] = ORIGIN_POLICIES["LIVE_DEMO"]["startup_state_policy"]
        self.reject([f.segment(1)])

    def test_descriptor_explicit_tables_state_and_source_pins(self):
        d = descriptor()
        self.assertFalse(d["operational"])
        self.assertEqual(len(d["files"]), 6)
        self.assertEqual(len(d["transaction_fields"]), 44)
        self.assertEqual(len(d["state_registry"]), 19)
        for engine in ENGINES:
            self.assertEqual([t["name"] for t in d["profiles"][engine]["tables"]],
                             [t.name for t in PROFILES[engine].tables if t.name not in {"run_manifest.tsv", "run_summary.tsv"}])
            self.assertIn("core_summary_buffer_peak", d["seal_keys"][engine]["TERMINAL"])
        self.assertIn("tools/model_dataset/continuation_reader.py", d["semantic_source_sha256"])
        self.assertNotIn("services/model_features/continuation_schema.mqh", d["semantic_source_sha256"])


if __name__ == "__main__":
    unittest.main()
