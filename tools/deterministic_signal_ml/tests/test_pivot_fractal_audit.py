from __future__ import annotations

import csv
import shutil
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
from schema_contract import SUPPORTED_FEATURE_SET_ID, feature_columns_for_set, validate_run


FIXTURE = Path(__file__).parent / "fixtures" / "schema_v9_pivot_fractal"


class PivotFractalAuditTests(unittest.TestCase):
    def build_fixture_dataset(self, root: Path) -> Path:
        runs_root = root / "runs"
        run_path = runs_root / "schema_v9_pivot_fractal"
        shutil.copytree(FIXTURE, run_path)
        validation = validate_run(runs_root, "schema_v9_pivot_fractal")
        connection = duckdb.connect(":memory:")
        counts = create_dataset_tables(
            connection,
            [validation],
            "broker_outcome",
            9,
            feature_columns_for_set(SUPPORTED_FEATURE_SET_ID),
        )
        dataset_dir = root / "dataset"
        dataset_dir.mkdir()
        write_parquet_outputs(connection, dataset_dir, counts)
        connection.close()
        return dataset_dir

    def test_audit_separates_structural_break_even_from_realized_profit(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = self.build_fixture_dataset(root)
            first_dir = root / "audit_one"
            metadata = build_audit(dataset_dir, first_dir, "fixture_audit")
            self.assertEqual(metadata["row_counts"]["attempts"], 2)
            self.assertEqual(metadata["row_counts"]["denied_attempts"], 1)
            self.assertEqual(metadata["row_counts"]["broker_outcomes"], 1)
            self.assertFalse(metadata["structural_break_even_is_monetary_break_even"])

            with (first_dir / "milestone_progression.tsv").open(
                encoding="utf-8", newline=""
            ) as handle:
                milestones = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(milestones[0]["structural_break_even"], "true")
            self.assertEqual(float(milestones[0]["realized_profit"]), 153.3)

            second_dir = root / "audit_two"
            build_audit(dataset_dir, second_dir, "fixture_audit")
            self.assertEqual(
                (first_dir / "level_direction_matrix.tsv").read_text(encoding="utf-8"),
                (second_dir / "level_direction_matrix.tsv").read_text(encoding="utf-8"),
            )

    def test_audit_rejects_outcome_without_matching_fill_join(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = self.build_fixture_dataset(root)
            outcome_path = dataset_dir / "signal_outcomes.parquet"
            replacement_path = dataset_dir / "signal_outcomes_bad.parquet"
            connection = duckdb.connect(":memory:")
            connection.execute(
                "COPY (SELECT * REPLACE (9999::UBIGINT AS position_ticket) "
                f"FROM read_parquet('{outcome_path.as_posix()}')) "
                f"TO '{replacement_path.as_posix()}' (FORMAT PARQUET)"
            )
            connection.close()
            outcome_path.unlink()
            replacement_path.rename(outcome_path)
            with self.assertRaisesRegex(PivotAuditError, "outcome without matching fill"):
                build_audit(dataset_dir, root / "bad_audit", "bad_audit")


if __name__ == "__main__":
    unittest.main()
