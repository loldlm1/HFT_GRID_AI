from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

import duckdb


MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from build_dataset import create_dataset_tables, write_parquet_outputs
from pivot_fractal_audit import PivotAuditError, build_audit
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
)
from schema_contract import SUPPORTED_FEATURE_SET_ID, validate_run


FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v11_pivot_trial_matrix"


def build_dataset_artifact(output_dir: Path) -> dict[str, int]:
    validation = validate_run(FIXTURES, FIXTURE.name)
    connection = duckdb.connect(":memory:")
    try:
        counts = create_dataset_tables(connection, [validation])
        output_files = write_parquet_outputs(connection, output_dir, counts)
        quality = build_quality_payload(connection, [validation], counts)
        write_dataset_manifest(
            output_dir,
            "fixture_dataset",
            [validation],
            counts,
            output_files,
            quality,
        )
        write_quality_json(output_dir, quality)
        write_dataset_report(output_dir, "fixture_dataset", quality)
        return counts
    finally:
        connection.close()


def rewrite_parquet(path: Path, projection: str) -> None:
    replacement = path.with_suffix(".replacement.parquet")
    connection = duckdb.connect(":memory:")
    try:
        escaped_source = path.resolve().as_posix().replace("'", "''")
        escaped_target = replacement.resolve().as_posix().replace("'", "''")
        connection.execute(
            f"COPY (SELECT {projection} FROM read_parquet('{escaped_source}')) "
            f"TO '{escaped_target}' (FORMAT PARQUET, COMPRESSION ZSTD)"
        )
    finally:
        connection.close()
    replacement.replace(path)


class PivotFractalAuditTests(unittest.TestCase):
    def test_audit_reports_virtual_chain_broker_and_calibration_separately(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            metadata = build_audit(
                dataset_dir,
                audit_dir,
                "fixture_audit",
                minimum_group_support=30,
            )

            self.assertEqual(metadata["research_status"], "INSUFFICIENT_SUPPORT")
            self.assertEqual(metadata["feature_set_id"], SUPPORTED_FEATURE_SET_ID)
            self.assertEqual(metadata["support"]["unique_origins"], 1)
            self.assertEqual(metadata["support"]["matrix_trial_rows"], 18)
            self.assertEqual(metadata["support"]["eligible_virtual_rows"], 16)
            self.assertEqual(metadata["support"]["broker_outcomes"], 1)
            self.assertEqual(metadata["calibration"]["strict_pairs"], 1)
            self.assertEqual(metadata["calibration"]["terminal_matches"], 1)
            self.assertEqual(metadata["calibration"]["terminal_mismatches"], 0)
            policy = {
                (row["sl_policy"], int(row["tp_r_multiple"])): row
                for row in metadata["policy_performance"]
            }
            self.assertAlmostEqual(policy[("STRUCTURAL", 1)]["break_even_tp_rate"], 0.5)
            self.assertAlmostEqual(policy[("MICRO_BW_13", 3)]["break_even_tp_rate"], 0.25)
            self.assertTrue(
                {
                    "audit.json",
                    "audit_report.md",
                    "policy_performance.tsv",
                    "chain_performance.tsv",
                    "eligibility.tsv",
                    "broker_performance.tsv",
                    "broker_virtual_calibration.tsv",
                }
                <= {path.name for path in audit_dir.iterdir()}
            )

    def test_audit_rejects_broker_outcome_without_ownership_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            rewrite_parquet(
                dataset_dir / "execution_checks.parquet",
                "* REPLACE (false AS broker_entry_confirmed, false AS broker_close_confirmed)",
            )
            with self.assertRaisesRegex(PivotAuditError, "ownership evidence"):
                build_audit(dataset_dir, audit_dir, "ownership_failure")

    def test_audit_rejects_origin_weight_and_parity_integrity_mutations(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            rewrite_parquet(
                dataset_dir / "eligible_virtual_trials.parquet",
                "* REPLACE (0.1::DOUBLE AS origin_sample_weight)",
            )
            with self.assertRaisesRegex(PivotAuditError, "weights do not sum to one"):
                build_audit(dataset_dir, audit_dir, "weight_failure")

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            rewrite_parquet(
                dataset_dir / "broker_virtual_calibration.parquet",
                "* REPLACE (false AS terminal_agreement)",
            )
            with self.assertRaisesRegex(PivotAuditError, "strict TP/SL mismatch"):
                build_audit(dataset_dir, audit_dir, "parity_failure")

    def test_audit_rejects_feature_contract_mutation_and_missing_table(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            manifest_path = dataset_dir / "dataset_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["feature_contract"]["model_features"].append("broker_net_profit")
            manifest_path.write_text(
                json.dumps(manifest, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(PivotAuditError, "feature contract differs"):
                build_audit(dataset_dir, audit_dir, "feature_failure")

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            audit_dir = root / "audit"
            dataset_dir.mkdir()
            audit_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            (dataset_dir / "policy_chains.parquet").unlink()
            with self.assertRaisesRegex(PivotAuditError, "Missing required dataset table"):
                build_audit(dataset_dir, audit_dir, "missing_table")


if __name__ == "__main__":
    unittest.main()
