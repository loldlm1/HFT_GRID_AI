from __future__ import annotations

import csv
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
from report_writer import build_quality_payload, write_dataset_manifest
from schema_contract import validate_run


FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v10_macro_micro_pivot"


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


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
        return counts
    finally:
        connection.close()


class PivotFractalAuditTests(unittest.TestCase):
    def test_audit_separates_operations_exclusions_and_binary_performance(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "dataset"
            audit_dir = Path(temp_dir) / "audit"
            dataset_dir.mkdir()
            build_dataset_artifact(dataset_dir)

            metadata = build_audit(
                dataset_dir,
                audit_dir,
                "fixture_audit",
                minimum_group_support=2,
            )
            self.assertEqual(metadata["research_rows"], 4)
            self.assertEqual(metadata["binary_cohort"]["rows"], 2)
            self.assertEqual(metadata["binary_cohort"]["tp_rows"], 1)
            self.assertEqual(metadata["binary_cohort"]["sl_rows"], 1)
            self.assertAlmostEqual(metadata["binary_cohort"]["tp_rate"], 0.5)
            self.assertAlmostEqual(
                metadata["binary_cohort"]["average_gross_profit"],
                -1.0,
            )
            self.assertAlmostEqual(
                metadata["binary_cohort"]["average_net_profit"],
                -2.0,
            )
            self.assertEqual(
                metadata["excluded_outcomes"],
                [
                    {
                        "terminal_reason": "MANUAL",
                        "exclusion_reason": "NONBINARY_MANUAL",
                        "rows": 1,
                    }
                ],
            )

            groups = read_tsv(audit_dir / "group_performance.tsv")
            overall = [
                row
                for row in groups
                if row["group_family"] == "overall" and row["group_key"] == "ALL"
            ]
            self.assertEqual(len(overall), 1)
            self.assertEqual(overall[0]["support"], "2")
            self.assertEqual(overall[0]["support_status"], "SUFFICIENT")
            report = (audit_dir / "audit_report.md").read_text(encoding="utf-8")
            self.assertNotIn("confluence", report.lower())
            self.assertNotIn("trailing", report.lower())
            self.assertIn("continuous values", report)

    def test_audit_rejects_outcome_without_entry_ownership_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "dataset"
            dataset_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            checks_path = dataset_dir / "execution_checks.parquet"
            replacement = dataset_dir / "execution_checks.replacement.parquet"
            connection = duckdb.connect(":memory:")
            try:
                source = checks_path.resolve().as_posix().replace("'", "''")
                target = replacement.resolve().as_posix().replace("'", "''")
                connection.execute(
                    f"""
COPY (
  SELECT * REPLACE (FALSE AS broker_entry_confirmed)
  FROM read_parquet('{source}')
) TO '{target}' (FORMAT PARQUET)
"""
                )
            finally:
                connection.close()
            replacement.replace(checks_path)

            with self.assertRaisesRegex(PivotAuditError, "entry ownership evidence"):
                build_audit(
                    dataset_dir,
                    Path(temp_dir) / "audit",
                    "invalid_audit",
                )

    def test_audit_rejects_feature_contract_mutation_and_missing_table(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "dataset"
            dataset_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            manifest_path = dataset_dir / "dataset_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["feature_columns"].append("close_price")
            manifest_path.write_text(
                json.dumps(manifest, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(PivotAuditError, "feature contract"):
                build_audit(
                    dataset_dir,
                    Path(temp_dir) / "audit_contract",
                    "invalid_contract",
                )

        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "dataset"
            dataset_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            (dataset_dir / "binary_outcomes.parquet").unlink()
            with self.assertRaisesRegex(PivotAuditError, "Missing required dataset table"):
                build_audit(
                    dataset_dir,
                    Path(temp_dir) / "audit_missing",
                    "missing_table",
                )


if __name__ == "__main__":
    unittest.main()
