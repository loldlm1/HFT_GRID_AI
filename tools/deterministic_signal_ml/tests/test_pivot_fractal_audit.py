from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

import duckdb

MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from pivot_fractal_audit import PivotAuditError, build_audit
from research_test_support import build_fixture_dataset
from schema_contract import (
    COLUMN_TYPE_REGISTRY_SHA256,
    DEEP_PIVOT_EVENTS_FILE,
    DEEP_PIVOT_PARENT_LINKS_FILE,
    DEEP_VIRTUAL_OUTCOMES_FILE,
    DEEP_VIRTUAL_TRIALS_FILE,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    validate_run,
)

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v14_hft_deep_pivot_features"


class PivotFractalV14EvidenceAuditTests(unittest.TestCase):
    def test_fixture_provenance_pins_contract_and_hashes(self) -> None:
        provenance = json.loads(
            (FIXTURE / "fixture_provenance.json").read_text(encoding="ascii")
        )
        self.assertEqual(provenance["schema_version"], SUPPORTED_SCHEMA_VERSION)
        self.assertEqual(provenance["feature_set_id"], SUPPORTED_FEATURE_SET_ID)
        self.assertEqual(provenance["registry_sha256"], COLUMN_TYPE_REGISTRY_SHA256)
        self.assertEqual(set(provenance["files"]), set(RUN_FILES))
        self.assertTrue(all(len(value) == 64 for value in provenance["files"].values()))
        self.assertEqual(
            provenance["files"],
            {
                filename: hashlib.sha256((FIXTURE / filename).read_bytes()).hexdigest()
                for filename in RUN_FILES
            },
        )

    def test_fixture_reconciles_native_evidence_grains(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        self.assertEqual(validation.row_counts[DEEP_PIVOT_EVENTS_FILE], 1)
        self.assertEqual(validation.row_counts[DEEP_PIVOT_PARENT_LINKS_FILE], 3)
        self.assertEqual(validation.row_counts[DEEP_VIRTUAL_TRIALS_FILE], 3)
        self.assertEqual(validation.row_counts[DEEP_VIRTUAL_OUTCOMES_FILE], 9)
        self.assertEqual(validation.warnings, ())

    def test_fixture_build_and_audit_keep_cohorts_separate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            counts = build_fixture_dataset(FIXTURE, dataset_dir)
            audit_dir.mkdir()
            metadata = build_audit(
                dataset_dir,
                audit_dir,
                "fixture_audit",
                minimum_group_support=1,
            )
            self.assertEqual(
                {
                    "h1_lane_long": counts["h1_lane_long"],
                    "eligible_h1_trials": counts["eligible_h1_trials"],
                    "deep_parent_long": counts["deep_parent_long"],
                    "eligible_deep_trials": counts["eligible_deep_trials"],
                    "broker_virtual_calibration": counts[
                        "broker_virtual_calibration"
                    ],
                },
                {
                    "h1_lane_long": 16,
                    "eligible_h1_trials": 8,
                    "deep_parent_long": 9,
                    "eligible_deep_trials": 7,
                    "broker_virtual_calibration": 0,
                },
            )
            self.assertEqual(metadata["research_status"], "AUDIT_COMPLETE")
            self.assertEqual(metadata["support"]["unique_origins"], 2)
            self.assertEqual(metadata["support"]["unique_deep_events"], 1)
            self.assertEqual(
                metadata["support"]["deep_parent_exit_censored_rows"], 1
            )
            self.assertEqual(
                (audit_dir / "broker_virtual_calibration.tsv").read_text(
                    encoding="utf-8"
                ),
                "",
            )
            self.assertTrue((audit_dir / "audit.json").is_file())
            self.assertTrue((audit_dir / "audit_report.md").is_file())

    def test_audit_rejects_manifest_grain_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            build_fixture_dataset(FIXTURE, dataset_dir)
            manifest_path = dataset_dir / "dataset_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            contract = manifest["feature_contracts"][
                "schema_v14_hft_deep_pivot_features.deep_parent"
            ]
            contract["event_features_native_grain"] = False
            manifest_path.write_text(
                json.dumps(manifest, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            audit_dir = root / "audit"
            audit_dir.mkdir()
            with self.assertRaisesRegex(PivotAuditError, "contracts differ"):
                build_audit(dataset_dir, audit_dir, "bad_manifest", 1)

    def test_audit_rejects_deep_features_persisted_at_parent_grain(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            build_fixture_dataset(FIXTURE, dataset_dir)
            original = dataset_dir / "eligible_deep_trials.parquet"
            replacement = dataset_dir / "eligible_deep_trials_replacement.parquet"
            connection = duckdb.connect(":memory:")
            try:
                escaped_original = original.resolve().as_posix().replace("'", "''")
                escaped_replacement = replacement.resolve().as_posix().replace("'", "''")
                connection.execute(
                    f"COPY (SELECT *, 1.0 AS deep_micro_band_width_points_0 "
                    f"FROM read_parquet('{escaped_original}')) "
                    f"TO '{escaped_replacement}' (FORMAT PARQUET)"
                )
            finally:
                connection.close()
            replacement.replace(original)
            audit_dir = root / "audit"
            audit_dir.mkdir()
            with self.assertRaisesRegex(PivotAuditError, "outside event grain"):
                build_audit(dataset_dir, audit_dir, "duplicated_features", 1)

    def test_audit_requires_positive_support_floor(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            build_fixture_dataset(FIXTURE, dataset_dir)
            audit_dir = root / "audit"
            audit_dir.mkdir()
            with self.assertRaisesRegex(PivotAuditError, "at least 1"):
                build_audit(dataset_dir, audit_dir, "bad_support", 0)

    def test_audit_rejects_opposed_outcome_using_event_direction_as_parent(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            build_fixture_dataset(FIXTURE, dataset_dir)
            original = dataset_dir / "deep_virtual_outcomes.parquet"
            replacement = root / "replacement.parquet"
            connection = duckdb.connect(":memory:")
            try:
                connection.execute(
                    "COPY (SELECT * REPLACE (direction AS parent_direction) "
                    "FROM read_parquet($source)) TO $target (FORMAT PARQUET)",
                    {"source": str(original), "target": str(replacement)},
                )
            finally:
                connection.close()
            replacement.replace(original)
            audit_dir = root / "audit"
            audit_dir.mkdir()
            with self.assertRaisesRegex(PivotAuditError, "parent/event direction"):
                build_audit(dataset_dir, audit_dir, "bad_parent_direction", 1)


if __name__ == "__main__":
    unittest.main()
