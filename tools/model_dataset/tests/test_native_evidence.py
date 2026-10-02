"""Synthetic native-owner evidence adversaries; never native acceptance receipts."""
import hashlib
import json
import os
import tempfile
import unittest
import zipfile
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch
from xml.sax.saxutils import escape

from ..continuation_contract import FILES, descriptor_digest, source_digest
from ..continuation_reader import ContinuationArchive, VerifiedNativeFence
from ..native_evidence import (NativeJobRegistry, NativeJobRegistration, NativeJobScope, VerifiedTesterDelivery,
                               NATIVE_REPORT_KEYS, HISTORY_SPEC_FIELDS, authenticate_tester_delivery, file_sha256)
from ..reader import ContractError
from .test_continuation import SourceFixture


class FixtureRegistry(NativeJobRegistry):
    """Internal test dependency, intentionally synthetic and not authenticated MCP."""
    def __init__(self, registration):
        self.registration = registration

    def lookup(self, key):
        return self.registration if key == self.registration.job_key else None


class NativeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = SourceFixture(self.root / "source", "PIVOT_MACRO_V2")
        spec = dict.fromkeys(HISTORY_SPEC_FIELDS, 0)
        spec.update(point=0.01, tick_size=0.01, contract_size=100.0,
                    calculation_mode="CFD", currency_profit="USD", currency_margin="USD",
                    volume_min=0.001, volume_max=100.0, volume_step=0.001,
                    symbol="XAUUSD", custom_symbol="yes")
        self.anchor = {"source_origin": "LOCAL_CUSTOM_TESTER", "symbol": "XAUUSD",
                       "date_from": "2016-03-14", "date_to": "2016-03-15", "model": 4,
                       "native_custom_symbol": dict(spec, update_time="ORIGINAL_DYNAMIC_TIME"),
                       "native_decision_spec_fields": list(HISTORY_SPEC_FIELDS)}
        self.anchor_path = self.save("anchor.json", self.anchor)
        self.anchor_pin = file_sha256(self.anchor_path)
        self.history = {
            "kind": "NATIVE_PHYSICAL_JOB_HISTORY_V1", "source_origin": "LOCAL_CUSTOM_TESTER",
            "native_run_id": "NATIVE_JOB", "physical_run_id": "PHYSICAL",
            "source_id": "SOURCE", "session_id": "SESSION", "engine": self.source.engine,
            "symbol": "XAUUSD", "configuration_proof": self.source.manifest["configuration_proof"],
            "history_anchor_sha256": self.anchor_pin, "date_from": "2016-03-14",
            "date_to": "2016-03-15", "model": 4, "native_custom_symbol": dict(spec),
            "native_decision_spec_fields": list(HISTORY_SPEC_FIELDS),
            "bounded_observation_pins": {"SYNTHETIC_BOUNDED_OBSERVATION": "d"*64},
        }
        self.history_path = self.save("history.json", self.history)
        self.history_pin = file_sha256(self.history_path)
        self.source.manifest["history_proof"] = self.anchor_pin
        self.segments = self.source.whole()
        self.values = {
            "Broker_Session": "1", "Macro_Timeframe": "16388", "Micro_Timeframe": "3",
            "Lot_Type": "1", "Lot_Strategy_Size": "0.001", "Enable_Signal_Feature_Export": "true",
            "Signal_Feature_Run_Id": "PHYSICAL", "Enable_Intake_Continuation": "true",
            "Intake_Source_Id": "SOURCE", "Intake_Session_Id": "SESSION", "Intake_Source_Proof": "",
            "Intake_Configuration_Proof": "", "Intake_History_Proof": self.anchor_pin,
            "Intake_Segment_Seconds": "3600", "Intake_Replay_Witness_Id": "",
            "Intake_Replay_Witness_Proof": "", "Enable_Logs": "false", "Enable_File_Logs": "false"}
        self.source_pin, self.descriptor_pin = source_digest(), descriptor_digest()
        self.binary_pin = "b" * 64
        self.configuration_pin = self.source.manifest["configuration_proof"]
        self.pre = {
            "source_origin": "LOCAL_CUSTOM_TESTER", "history_anchor_sha256": self.anchor_pin,
            "physical_run_id": "PHYSICAL", "parameters": [k+"="+v for k,v in self.values.items()],
            "configuration": {"Expert": r"HFT_Grid_AI\TEST.ex5", "Model": "4", "Symbol": "XAUUSD",
                "Period": "M3", "FromDate": "2016.03.14", "ToDate": "2016.03.15", "ExecutionMode": "0",
                "Optimization": "0", "ForwardMode": "0", "Visual": "0", "ProfitInPips": "0",
                "Currency": "USD", "Leverage": "500", "Deposit": "10000000.00"},
            "source_binary_pins": {"source_sha256": self.source_pin, "descriptor_sha256": self.descriptor_pin,
                                  "binary_pins": {"Pivot_Macro": {"sha256": self.binary_pin}}}}
        self.launch = {"run_id": "NATIVE_JOB", "ok": True, "status": "started", "timed_out": False}
        self.owned = {"prelaunch": self.pre, "launch": self.launch, "start_epoch_ms": 10,
                      "deadline_epoch_ms": 300010}
        self.native = {
            "physical_run_id": "PHYSICAL", "launch": self.launch,
            "completion": {"run_id": "NATIVE_JOB", "ok": True, "status": "stopped", "timed_out": False},
            "status": {"run_id": "NATIVE_JOB", "tester_status": "stopped"},
            "case_wall_ms": 5, "source_binary_pins": self.pre["source_binary_pins"],
            "configuration": {"run_id": "NATIVE_JOB", "mql5_program_path": r"Experts\HFT_Grid_AI\TEST.ex5",
                "symbol": "XAUUSD", "period": "M3", "model": "real ticks", "tester_mode": "backtest",
                "date_from": "2016-03-14", "date_to": "2016-03-15", "execution_delay": 0,
                "visual_mode": False, "deposit": 10000000, "deposit_currency": "USD",
                "leverage": "1:500", "profit_in_pips": False},
            "journal": {"truncated": False, "records_count": 2, "records": [
                {"message": "0 ticks, 1 bars generated"}, {"message": "Test passed in 0.01 seconds"}]}}
        self.report = {key:0 for key in NATIVE_REPORT_KEYS}
        self.report.update({"run_id": "NATIVE_JOB", "symbol": "XAUUSD", "generated_ticks": 0, "generated_bars": 1})
        self.write_originals()

    def save(self, name, obj):
        path = self.root / name
        path.write_text(json.dumps(obj), encoding="utf-8")
        return path

    def report_xlsx(self, values=None):
        period = "M3 ("+self.pre["configuration"]["FromDate"]+" - "+self.pre["configuration"]["ToDate"]+")"
        cells = ["Symbol:", "XAUUSD", "Period:", period,
                 "History Quality:", "100% real ticks", "Ticks:", "0.000000", "Bars:", "1.000000"]
        cells += [k+"="+v for k,v in (values or self.values).items()]
        strings = '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        strings += "".join("<si><t>"+escape(v)+"</t></si>" for v in cells) + "</sst>"
        sheet = '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row>'
        sheet += "".join(f'<c t="s"><v>{i}</v></c>' for i in range(len(cells))) + "</row></sheetData></worksheet>"
        path = self.root / "report.xlsx"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("xl/sharedStrings.xml", strings)
            archive.writestr("xl/worksheets/sheet1.xml", sheet)
        return path

    def write_originals(self):
        self.history_path = self.save("history.json", self.history)
        self.history_pin = file_sha256(self.history_path)
        paths = {"prelaunch": self.save("prelaunch.json", self.pre),
                 "owned_job": self.save("owned.json", self.owned),
                 "native_result": self.save("native.json", self.native),
                 "report_json": self.save("report.json", self.report),
                 "report_xlsx": self.report_xlsx(), "history": self.history_path,
                 "history_anchor": self.anchor_path}
        self.registration = NativeJobRegistration(
            "SYNTHETIC_JOB", "NATIVE_JOB", "PHYSICAL", self.source.engine,
            r"Experts\HFT_Grid_AI\TEST.ex5", "XAUUSD", self.source_pin, self.descriptor_pin,
            self.binary_pin, self.history_pin, self.anchor_pin, self.configuration_pin,
            tuple(self.pre["parameters"]), {k:(p, file_sha256(p)) for k,p in paths.items()},
            {str(s["path"]): {name: file_sha256(s["path"]/name) for name in FILES} for s in self.segments},
            NativeJobScope(dict(self.pre["configuration"]),
                           {k:v for k,v in self.native["configuration"].items() if k not in {"run_id","mql5_program_path"}},
                           "M3 ("+self.pre["configuration"]["FromDate"]+" - "+self.pre["configuration"]["ToDate"]+")", 300000, 128))
        return FixtureRegistry(self.registration)

    def authenticate(self, registration=None):
        return authenticate_tester_delivery(FixtureRegistry(registration or self.registration), "SYNTHETIC_JOB")


    def extend_synthetic_scope(self, end="2016-03-16"):
        """Synthetic date-step only; no native run or history acquisition."""
        self.history["date_to"] = end
        self.native["configuration"]["date_to"] = end
        self.pre["configuration"]["ToDate"] = end.replace("-", ".")
        self.write_originals()

    def test_dated_history_end_can_extend_without_changing_original_anchor(self):
        original_anchor, original_configuration = self.anchor_pin, self.configuration_pin
        self.extend_synthetic_scope()
        proof = self.authenticate()
        self.assertEqual(proof.registration.history_anchor_sha256, original_anchor)
        self.assertNotEqual(proof.registration.history_sha256, original_anchor)
        self.assertEqual(self.source.manifest["history_proof"], original_anchor)
        self.assertEqual(proof.registration.configuration_sha256, original_configuration)
        with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[proof]) as archive:
            self.assertEqual(archive.identity[6], original_anchor)
            archive.verify_unchanged()
        proof.verify_unchanged()

    def test_current_history_receipt_cannot_substitute_source_session_job_or_config(self):
        original = json.loads(json.dumps(self.history))
        for field in ("native_run_id", "physical_run_id", "source_id", "session_id",
                      "engine", "symbol", "configuration_proof"):
            with self.subTest(field=field):
                self.history = dict(original)
                self.history[field] = "OTHER"
                self.write_originals()
                with self.assertRaisesRegex(ContractError, "substitution"):
                    self.authenticate()
        self.history = original

    def test_current_history_link_and_stable_spec_are_not_caller_equivalence(self):
        original = json.loads(json.dumps(self.history))
        for change in ("anchor_link", "point", "field_set", "model", "dynamic_native_info"):
            with self.subTest(change=change):
                self.history = json.loads(json.dumps(original))
                if change == "anchor_link":
                    self.history["history_anchor_sha256"] = "c"*64
                elif change == "point":
                    self.history["native_custom_symbol"]["point"] = 0.02
                elif change == "field_set":
                    self.history["native_decision_spec_fields"].pop()
                elif change == "model":
                    self.history["model"] = 1
                else:
                    self.history["native_custom_symbol"]["update_time"] = "CURRENT_DYNAMIC_TIME"
                self.write_originals()
                with self.assertRaises(ContractError):
                    self.authenticate()
        self.history = original

    def test_anchor_and_current_receipt_are_both_required_immutable_originals(self):
        proof = self.authenticate()
        for role in ("history_anchor", "history"):
            pins = dict(self.registration.artifact_pins)
            pins.pop(role)
            with self.assertRaisesRegex(ContractError, "inventory"):
                self.authenticate(replace(self.registration, artifact_pins=pins))
        self.anchor["native_custom_symbol"]["point"] = 0.02
        self.save("anchor.json", self.anchor)
        with self.assertRaisesRegex(ContractError, "Substituted original"):
            proof.verify_unchanged()

    def test_extended_history_cannot_change_original_start_or_shrink_end(self):
        self.extend_synthetic_scope()
        self.history["date_from"] = self.native["configuration"]["date_from"] = "2016-03-13"
        self.pre["configuration"]["FromDate"] = "2016.03.13"
        self.write_originals()
        with self.assertRaisesRegex(ContractError, "original anchor"):
            self.authenticate()
        self.history["date_from"] = self.native["configuration"]["date_from"] = "2016-03-14"
        self.pre["configuration"]["FromDate"] = "2016.03.14"
        self.extend_synthetic_scope("2016-03-14")
        with self.assertRaisesRegex(ContractError, "original anchor"):
            self.authenticate()

    def test_current_history_dates_and_unknown_fields_are_exact(self):
        self.history["date_to"] = "2016-03-16"
        self.write_originals()
        with self.assertRaisesRegex(ContractError, "Loaded native tester configuration"):
            self.authenticate()
        self.history["date_to"] = "2016-03-15"
        self.history["caller_certified"] = True
        self.write_originals()
        with self.assertRaisesRegex(ContractError, "Exact dated"):
            self.authenticate()

    def test_registered_cold_is_provisional_and_can_bind_selected_prefix(self):
        proof = self.authenticate()
        self.assertEqual(proof.summary()["delivery_admission"], "PROVISIONAL_NATIVE_REGISTERED")
        self.assertEqual(proof.summary()["paired_fence_acceptance"], "REQUIRED")
        with ContinuationArchive([self.segments[0]["path"]], tester_deliveries=[proof]) as archive:
            self.assertEqual(archive.report()["tester_delivery"][0]["source_quality"],
                             "HISTORICAL_SOURCE_GAPS_UNKNOWN")

    def test_missing_registry_and_caller_proof_cannot_admit_tester(self):
        with self.assertRaisesRegex(ContractError, "registry"):
            authenticate_tester_delivery({"self_claim": True}, "SYNTHETIC_JOB")
        with self.assertRaisesRegex(ContractError, "registration missing"):
            authenticate_tester_delivery(FixtureRegistry(self.registration), "UNKNOWN")
        with self.assertRaisesRegex(ContractError, "registry proof"):
            with ContinuationArchive([self.segments[0]["path"]]):
                pass
        with self.assertRaisesRegex(ContractError, "registry issuance"):
            VerifiedTesterDelivery(object(), self.registration, {}, {}, 0, 0)

    def test_original_artifact_tamper_rejected_even_when_json_shape_valid(self):
        self.report["generated_ticks"] = 1
        self.save("report.json", self.report)
        with self.assertRaisesRegex(ContractError, "Substituted original"):
            self.authenticate()

    def test_same_job_loaded_binary_history_and_completion_are_bound(self):
        for key in ("job", "binary", "history", "timeout", "delay"):
            with self.subTest(key=key):
                original = json.loads(json.dumps(self.native))
                if key == "job":
                    self.native["configuration"]["run_id"] = "OTHER"
                elif key == "binary":
                    self.native["source_binary_pins"]["binary_pins"]["Pivot_Macro"]["sha256"] = "c"*64
                elif key == "history":
                    self.native["configuration"]["date_to"] = "2016-03-16"
                elif key == "timeout":
                    self.native["completion"]["timed_out"] = True
                else:
                    self.native["configuration"]["execution_delay"] = 1
                self.write_originals()
                with self.assertRaises(ContractError):
                    self.authenticate()
                self.native = original
                self.pre["source_binary_pins"]["binary_pins"]["Pivot_Macro"]["sha256"] = self.binary_pin

    def test_natural_native_report_counters_and_original_journal_required(self):
        for field in ("generated_ticks", "generated_bars"):
            old = self.report[field]
            self.report[field] = old + 1
            self.write_originals()
            with self.assertRaisesRegex(ContractError, "counter disagreement"):
                self.authenticate()
            self.report[field] = old
        self.native["journal"]["truncated"] = True
        self.write_originals()
        with self.assertRaisesRegex(ContractError, "Truncated"):
            self.authenticate()

    def test_independent_loaded_set_values_reject_wrong_input(self):
        self.write_originals()
        changed = dict(self.values, Lot_Strategy_Size="1")
        path = self.report_xlsx(changed)
        pins = dict(self.registration.artifact_pins)
        pins["report_xlsx"] = (path, file_sha256(path))
        with self.assertRaisesRegex(ContractError, "Loaded native report inputs"):
            self.authenticate(replace(self.registration, artifact_pins=pins))

    def test_wrong_origin_and_changed_registered_segment_rejected(self):
        self.history["native_custom_symbol"]["custom_symbol"] = "no"
        self.history_path = self.save("history.json", self.history)
        pins = dict(self.registration.artifact_pins)
        pins["history"] = (self.history_path, file_sha256(self.history_path))
        with self.assertRaises(ContractError):
            self.authenticate(replace(self.registration, artifact_pins=pins))
        self.history["native_custom_symbol"]["custom_symbol"] = "yes"
        self.save("history.json", self.history)
        self.write_originals()
        proof = self.authenticate()
        path = self.segments[0]["path"]/"input_events.tsv"
        path.write_bytes(path.read_bytes().replace(b"OBSERVED_CALLBACK_ONLY", b"INVENTED_CALLBACK_ONLY"))
        with self.assertRaisesRegex(ContractError, "Registered original capture changed"):
            proof.verify_unchanged()

    def test_nonregular_files_refused_without_blocking_or_descriptor_leak(self):
        fifo = self.root/"pipe"
        os.mkfifo(fifo)
        directory = self.root/"directory"
        directory.mkdir()
        for path in (fifo, directory, Path("/dev/null")):
            before = len(list(Path("/proc/self/fd").iterdir()))
            with self.assertRaisesRegex(ContractError, "regular file"):
                file_sha256(path)
            self.assertEqual(len(list(Path("/proc/self/fd").iterdir())), before)

    def test_swap_to_fifo_is_nonblocking_and_closes_opened_descriptor(self):
        fifo = self.root/"racing_pipe"
        os.mkfifo(fifo)
        before = len(list(Path("/proc/self/fd").iterdir()))
        info = self.history_path.stat()
        with patch.object(Path, "lstat", return_value=info):
            with self.assertRaisesRegex(ContractError, "regular file"):
                file_sha256(fifo)
        self.assertEqual(len(list(Path("/proc/self/fd").iterdir())), before)

    def test_factory_issuance_and_defensive_snapshot_are_immutable(self):
        proof = self.authenticate()
        with self.assertRaises(AttributeError):
            proof.generated_ticks = 1
        with self.assertRaises(TypeError):
            proof.registration.artifact_pins["report_json"] = ("OTHER", "0"*64)
        self.registration.artifact_pins.clear()
        self.assertEqual(len(proof.registration.artifact_pins), 7)
        forged = object.__new__(VerifiedTesterDelivery)
        self.assertFalse(forged.is_authenticated())
        with self.assertRaisesRegex(ContractError, "registry proof"):
            with ContinuationArchive([self.segments[0]["path"]], tester_deliveries=[forged]):
                pass

    def test_duplicate_json_and_nonfinite_numbers_refused(self):
        for content in (b'{"run_id":"NATIVE_JOB","run_id":"OTHER"}', b'{"value":1e309}'):
            path = self.root / "report.json"
            path.write_bytes(content)
            pins = dict(self.registration.artifact_pins)
            pins["report_json"] = (path, file_sha256(path))
            with self.assertRaisesRegex(ContractError, "Duplicate native JSON|Nonfinite native JSON"):
                self.authenticate(replace(self.registration, artifact_pins=pins))

    def test_registered_segment_negative_or_skewed_callback_partition_refused(self):
        path = self.segments[0]["path"]/"input_events.tsv"
        original = path.read_bytes()
        for key, value in (("tick_count", "-1"), ("fresh_quote_count", "2")):
            rows = original.split(b"\r\n")
            fields = rows[0].decode().split("\t")
            cells = rows[1].decode().split("\t")
            cells[fields.index(key)] = value
            rows[1] = "\t".join(cells).encode()
            path.write_bytes(b"\r\n".join(rows))
            pins = {p:dict(v) for p,v in self.registration.segment_pins.items()}
            pins[str(self.segments[0]["path"])]["input_events.tsv"] = file_sha256(path)
            with self.assertRaisesRegex(ContractError, "count partition"):
                self.authenticate(replace(self.registration, segment_pins=pins))
            path.write_bytes(original)

    def test_final_fence_cannot_be_caller_labels_or_generic_active_count(self):
        proof = self.authenticate()
        class Claim:
            evidence_sha256 = "e"*64
        with self.assertRaisesRegex(ContractError, "Authenticated native terminal fence"):
            proof.verify_native_fence(Claim(), None)


    def owner_fence(self, changes=None):
        """Synthetic registered originals; never a native acceptance verdict."""
        initial = self.authenticate()
        with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[initial]) as archive:
            segment = archive.segments[0]
            fields = {key: self.source.manifest[key] for key in
                      ("descriptor_sha256", "source_proof", "configuration_proof",
                       "history_proof", "core_manifest_sha256")}
            fields.update(paired_terminal_seal=archive.segments[-1]["proofs"]["segment_seal.tsv"].chain,
                          first_terminal_effect_input_ordinal=3,
                          last_safe_input_ordinal=int(segment["seal"]["last_input_ordinal"]))
        audit = {"kind": "NATIVE_TESTER_PREFINALIZATION_FENCE_V1",
                 "native_job_key": self.registration.job_key, "fields": fields,
                 "native_result_sha256": self.registration.artifact_pins["native_result"][1],
                 "pending_broker_objects": 0, "pending_virtual_objects": 0,
                 "pending_broker_parity_objects": 0, "ordinary_segment_ordinal": 1}
        audit.update(changes or {})
        path = self.save("fence.json", audit)
        pin = file_sha256(path)
        proof = self.authenticate(replace(self.registration, native_fence_pin=(path, pin)))
        return proof, VerifiedNativeFence(**fields, evidence_sha256=pin)

    def test_latest_safe_fence_accepts_exact_zero_owned_state(self):
        proof, fence = self.owner_fence()
        with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[proof]) as archive:
            proof.verify_native_fence(fence, archive)
            archive.verify_unchanged()

    def test_safe_fence_refuses_negative_boolean_or_invented_owned_counts(self):
        for field in ("pending_broker_objects", "pending_virtual_objects", "pending_broker_parity_objects"):
            for value in (-1, True, 1):
                with self.subTest(field=field, value=value):
                    proof, fence = self.owner_fence({field: value})
                    with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[proof]) as archive:
                        with self.assertRaises(ContractError):
                            proof.verify_native_fence(fence, archive)

    def test_safe_fence_requires_exact_canonical_ordinary_ordinal(self):
        for value in (0, 2, True, "1"):
            with self.subTest(value=value):
                proof, fence = self.owner_fence({"ordinary_segment_ordinal": value})
                with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[proof]) as archive:
                    with self.assertRaisesRegex(ContractError, "ordinary segment ordinal"):
                        proof.verify_native_fence(fence, archive)

    def test_safe_fence_rechecks_original_owner_audit_bytes(self):
        proof, fence = self.owner_fence()
        path = self.root / "fence.json"
        changed = json.loads(path.read_text())
        changed["pending_broker_objects"] = 1
        self.save("fence.json", changed)
        with ContinuationArchive([s["path"] for s in self.segments], tester_deliveries=[proof]) as archive:
            with self.assertRaisesRegex(ContractError, "Substituted original"):
                proof.verify_native_fence(fence, archive)


if __name__ == "__main__":
    unittest.main()
