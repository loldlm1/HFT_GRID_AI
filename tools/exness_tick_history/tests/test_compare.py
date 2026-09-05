import csv
import shutil
import unittest
from datetime import timedelta

from tools.exness_tick_history.compare import BAR_HEADER, PERIOD_MS, compare_roundtrip, native_ticks, quote_bars
from tools.exness_tick_history.mt5_export import export_mt5
from tools.exness_tick_history.sanitize import EPOCH, build_dataset
from tools.exness_tick_history.storage import file_hash
from tools.exness_tick_history.tests import test_pipeline as fixtures, test_mt5_export as exports


class RoundtripTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PipelineTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.temp.cleanup)
        self.profile = self.fixture.profile
        rows = [self.fixture.row(), self.fixture.row(bid="1.001", ask="1.002"), self.fixture.row(ms="002")]
        inv = self.fixture.seed(rows)
        build_dataset(self.profile, inv, "input")
        self.manifest = export_mt5(self.profile, "input", "export", exports.specification(self.profile), exports.clock_map())
        self.native = self.profile.data_root / "native.tsv"
        shutil.copyfile(self.profile.data_root / "exports/export/ticks-000000.tsv", self.native)

    def evidence(self):
        evidence = {"schema_version": 1, "operator_verified": True, "complete": True,
                    "export_manifest_sha256": self.manifest["manifest_sha256"],
                    "native_specification_sha256": self.manifest["specification_sha256"],
                    "custom_symbol": self.manifest["custom_symbol"], "native_ticks_sha256": file_hash(self.native), "native_bars": {}}
        for period, milliseconds in PERIOD_MS.items():
            path = self.profile.data_root / (period + ".tsv")
            with path.open("w", newline="") as stream:
                writer = csv.writer(stream, delimiter="\t")
                writer.writerow(BAR_HEADER)
                for stamp, *ohlc in quote_bars(native_ticks(self.native), milliseconds):
                    dt = EPOCH + timedelta(milliseconds=stamp)
                    writer.writerow([f"{dt:%Y.%m.%d}", f"{dt:%H:%M:%S}", *ohlc, 3, 0, 1])
            evidence["native_bars"][period] = {"path": path.name, "sha256": file_hash(path)}
        return evidence

    def compare(self, evidence=None):
        return compare_roundtrip(self.profile, "export", self.native, evidence=evidence, evidence_root=self.profile.data_root)

    def test_exact_ticks_need_native_metadata_and_bars(self):
        result = self.compare()
        self.assertEqual(result["tick_equality"], "PASS")
        self.assertEqual(result["mt5_round_trip"], "INCONCLUSIVE")
        self.assertEqual(self.compare(self.evidence())["mt5_round_trip"], "PASS")

    def test_deleted_duplicated_reversed_tie_and_perturbed_ticks_fail(self):
        original = self.native.read_text().splitlines(keepends=True)
        cases = [original[:-1], original + original[-1:], [original[0], original[2], original[1], original[3]],
                 [original[0], original[1].replace("00.001", "00.000"), *original[2:]],
                 [original[0], original[1].replace("1.000", "0.999"), *original[2:]]]
        for lines in cases:
            with self.subTest(lines=lines):
                self.native.write_text("".join(lines))
                self.assertEqual(self.compare()["tick_equality"], "FAIL")

    def test_precision_loss_is_inconclusive_and_wrong_spec_fails(self):
        evidence = self.evidence()
        evidence["native_specification_sha256"] = "wrong"
        self.assertEqual(self.compare(evidence)["mt5_round_trip"], "FAIL")
        self.native.write_text(self.native.read_text().replace(".001\t", "\t").replace(".002\t", "\t"))
        self.assertEqual(self.compare()["tick_equality"], "INCONCLUSIVE")

    def test_missing_or_changed_native_bars_cannot_pass(self):
        evidence = self.evidence()
        (self.profile.data_root / "M10.tsv").write_text("corrupted")
        self.assertEqual(self.compare(evidence)["mt5_round_trip"], "FAIL")
