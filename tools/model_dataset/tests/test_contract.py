import json
import re
import tempfile
import tracemalloc
import unittest
from dataclasses import FrozenInstanceError
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

from ..reader import ContractError, ModelRun, compatibility_signature, number
from ..schema_contract import TABLES, contract, mql_header
from .fixtures import make_run, rewrite


class RunFixtureCase(unittest.TestCase):
    engine = "CANDLE_PATTERN_ATR_V2"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "SYNTHETIC_RUN"
        self.tables = make_run(self.path, self.engine)

    def validate(self):
        rewrite(self.path, self.tables)
        with ModelRun(self.path) as run:
            return run.report()

    def reject(self, mutate):
        mutate(self.tables)
        with self.assertRaises(ContractError):
            self.validate()


class ContractTests(RunFixtureCase):
    def test_valid_run_and_exact_decimal(self):
        result = self.validate()
        self.assertEqual(result["engine"], self.engine)
        self.assertTrue(result["parity_excluded"])
        self.assertEqual(number("0.10000000000000001"), Decimal("0.10000000000000001"))
        self.assertNotEqual(number("0.10000000000000001"), Decimal("0.1"))

    def test_unsafe_numbers(self):
        for value in ("NaN", "Infinity", "1.7976931348623157e308", " 1", "+1", "1_000", "01"):
            with self.subTest(value=value), self.assertRaises(ContractError):
                number(value)

    def test_typed_descriptors_are_frozen(self):
        with self.assertRaises(FrozenInstanceError):
            TABLES[1].key = "other"
        self.assertEqual(len(json.loads(json.dumps(contract()))["tables"]), 12)
        self.assertEqual(mql_header(), mql_header())
        for table in TABLES:
            self.assertEqual(len(table.columns), len(set(table.columns)))
        self.assertEqual(next(f for f in TABLES[5].fields if f.name == "role").choices, ("BROKER", "VIRTUAL", "PARITY"))

    def test_consumer_profile_declares_conditional_proof_and_native_durations(self):
        descriptor = contract()
        profiles = descriptor['profiles']
        for engine in ('PIVOT_MACRO_V2', 'CANDLE_PATTERN_ATR_V3'):
            proof = profiles[engine]['required_entry_proof']
            fields = {f['name'] for f in descriptor['tables'][proof['table']]['fields']}
            self.assertEqual(proof['when'], 'ADMITTED_OR_COMPUTED_DISTANCE_REJECTION')
            self.assertLessEqual(set(proof['fields']), fields)
            self.assertIn('minimum_risk_distance_points', proof['fields'])
            self.assertIn('distance_eligible', proof['fields'])
            self.assertIn(7200, profiles[engine]['timeframes']['macro_seconds'])
            self.assertEqual(profiles[engine]['timeframes']['ordering'], 'MICRO_LT_MACRO')
        self.assertIn(2592000, profiles['PIVOT_MACRO_V2']['timeframes']['macro_seconds'])
        self.assertNotIn(2592000, profiles['CANDLE_PATTERN_ATR_V3']['timeframes']['macro_seconds'])
        self.assertIsNone(profiles['PIVOT_MACRO_V1']['required_entry_proof'])
        self.assertIsNone(profiles['CANDLE_PATTERN_ATR_V2']['required_entry_proof'])

    def test_generated_field_ids_preserve_table_and_raw_column(self):
        header = mql_header()
        stride = int(re.search(r"MODEL_FIELD_STRIDE = (\d+);", header)[1])
        fields = {name: int(value) for name, value in re.findall(r"(MODEL_F_\w+) = (\d+)", header)}
        self.assertEqual(len(fields), sum(len(t.raw_fields) for t in TABLES))
        self.assertEqual(len(set(fields.values())), len(fields))
        for file, table in enumerate(TABLES):
            prefix = "MODEL_F_" + table.name.removesuffix(".tsv").upper()
            for column, field in enumerate(table.raw_fields):
                self.assertEqual(divmod(fields[f"{prefix}_{field.name.upper()}"], stride), (file, column))
            self.assertLessEqual(len(table.raw_fields), stride)
        for size, body in re.findall(r"const int MODEL_\w+\[(\d+)\] = \{([^}]+)\};", header):
            members = body.split(", ")
            self.assertEqual(len(members), int(size))
            self.assertTrue(all(member in fields for member in members))

    def test_generated_clock_offsets_point_to_exact_companions(self):
        from ..schema_contract import clock_companions
        offsets = {name: int(value) for name, value in re.findall(
            r"case (MODEL_F_\w+): return (\d+);", mql_header())}
        self.assertEqual(len(offsets), sum(len(t.clocks) for t in TABLES))
        for table in TABLES:
            prefix = "MODEL_F_" + table.name.removesuffix(".tsv").upper()
            for field in table.raw_fields:
                name = f"{prefix}_{field.name.upper()}"
                if field.type != "clock":
                    self.assertNotIn(name, offsets)
                    continue
                start = offsets[name]
                self.assertEqual(table.columns[start:start + 3], clock_companions(field.name))
                self.assertEqual(tuple(f.type for f in table.fields[start:start + 3]), ("int", "int", "text"))

    def test_unknown_engine(self):
        self.reject(lambda t: next(r for r in t["run_manifest.tsv"] if r["key"] == "engine").update(value="UNKNOWN"))

    def test_failed_seal(self):
        self.reject(lambda t: next(r for r in t["run_summary.tsv"] if r["key"] == "export_status").update(value="FAILED"))

    def test_future_warmup_rejected(self):
        self.reject(lambda t: next(r for r in t["run_summary.tsv"] if r["key"] == "warmup_last_time_msc").update(value="9439812980000"))

    def test_unknown_eligibility_rejected(self):
        self.reject(lambda t: t["trials.tsv"][2].update(eligibility="UNKNOWN"))

    def test_duplicate_signal(self):
        self.reject(lambda t: t["signal_events.tsv"].append(dict(t["signal_events.tsv"][0])))

    def test_orphan_attempt(self):
        self.reject(lambda t: t["entry_attempts.tsv"][0].update(signal_id="MISSING"))

    def test_omitted_extension_row(self):
        self.reject(lambda t: t["candle_attempts.tsv"].pop())

    def test_parity_cannot_be_target(self):
        self.reject(lambda t: next(r for r in t["outcomes.tsv"] if r["role"] == "PARITY").update(binary_eligible="1", binary_label="1"))

    def test_unknown_header(self):
        file = self.path / "trials.tsv"
        file.write_bytes(file.read_bytes().replace(b"entry_policy", b"entry_policy_unknown", 1))
        with self.assertRaisesRegex(ContractError, "Header mismatch"):
            with ModelRun(self.path): pass

    def test_partial_row(self):
        file = self.path / "outcomes.tsv"
        file.write_bytes(file.read_bytes().rstrip())
        with self.assertRaisesRegex(ContractError, "Partial/oversized"):
            with ModelRun(self.path): pass

    def test_wrong_seal_and_extra_files(self):
        for extra in ("extra.tsv", "FAILED.txt"):
            p = self.path / extra; p.write_text("failure")
            with self.assertRaises(ContractError):
                with ModelRun(self.path): pass
            p.unlink()

    def test_missing_file(self):
        (self.path / "trials.tsv").unlink()
        with self.assertRaises(ContractError):
            with ModelRun(self.path): pass

    def test_symlink_refused(self):
        original = self.path / "trials.tsv"
        retained = self.path.parent / "retained.tsv"
        original.rename(retained); original.symlink_to(retained)
        with self.assertRaisesRegex(ContractError, "regular file"):
            with ModelRun(self.path): pass

    def test_mutation_during_validation(self):
        from ..semantics import validate
        def mutate(run):
            validate(run)
            with (self.path / "trials.tsv").open("ab") as out: out.write(b"\n")
        with patch("tools.model_dataset.semantics.validate", mutate), self.assertRaisesRegex(ContractError, "Source changed"):
            with ModelRun(self.path): pass

    def test_configurations_do_not_silently_combine(self):
        with ModelRun(self.path) as run:
            altered = {**run.manifest, "macro_seconds": "7200"}
            self.assertNotEqual(compatibility_signature(run.manifest), compatibility_signature(altered))

    def test_streamed_index_memory(self):
        p = self.path / "execution_checks.tsv"
        lines = p.read_bytes().splitlines(keepends=True)
        columns = TABLES[6].columns
        template = dict(zip(columns, lines[1].decode().rstrip().split("\t"), strict=True))
        with p.open("ab") as out:
            for i in range(3000):
                values = {**template, "check_id": f"STREAM_{i}", "action": "RECONCILE"}
                out.write(("\t".join(values[c] for c in columns) + "\r\n").encode())
        seal = self.path / "run_summary.tsv"
        seal.write_bytes(seal.read_bytes().replace(b"rows_execution_checks.tsv\t2\r\n", b"rows_execution_checks.tsv\t3002\r\n"))
        tracemalloc.start()
        try:
            with ModelRun(self.path) as run:
                self.assertEqual(run.counts["execution_checks.tsv"], 3002)
                self.assertLess(tracemalloc.get_traced_memory()[1], 8 * 1024 * 1024)
        finally:
            tracemalloc.stop()
