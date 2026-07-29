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
from schema_contract import (
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    RUN_FILES,
    SIGNAL_ATTEMPTS_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    SchemaValidationError,
    feature_columns_for_set,
    validate_run,
)


FIXTURE = Path(__file__).parent / "fixtures" / "schema_v9_pivot_fractal"


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def write_rows(path: Path, columns: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def mutate_summary(run_path: Path, column: str, value: str) -> None:
    path = run_path / "run_summary.tsv"
    columns, rows = read_rows(path)
    rows[0][column] = value
    write_rows(path, columns, rows)


class PivotFractalSchemaTests(unittest.TestCase):
    def copy_fixture(self, temp_dir: str) -> tuple[Path, Path]:
        runs_root = Path(temp_dir) / "runs"
        run_path = runs_root / "schema_v9_pivot_fractal"
        shutil.copytree(FIXTURE, run_path)
        return runs_root, run_path

    def test_v9_fixture_validates_and_builds_both_research_lanes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, _ = self.copy_fixture(temp_dir)
            validation = validate_run(runs_root, "schema_v9_pivot_fractal")
            self.assertEqual(SUPPORTED_SCHEMA_VERSION, 9)
            self.assertEqual(validation.pivot_window_rows, 1)
            self.assertEqual(validation.pivot_level_rows, 7)
            self.assertEqual(validation.signal_attempt_rows, 2)
            self.assertEqual(validation.signal_feature_rows, 12)
            self.assertEqual(validation.execution_check_rows, 4)
            self.assertEqual(validation.trailing_event_rows, 1)
            self.assertEqual(validation.signal_outcome_rows, 1)
            self.assertEqual({path.name for path in FIXTURE.glob("*.tsv")}, set(RUN_FILES))

            broker = duckdb.connect(":memory:")
            counts = create_dataset_tables(
                broker,
                [validation],
                "broker_outcome",
                9,
                feature_columns_for_set(SUPPORTED_FEATURE_SET_ID),
            )
            self.assertEqual(counts["training_matrix"], 1)
            self.assertEqual(
                broker.execute(
                    "SELECT signal_id, target_is_profit, target_realized_profit "
                    "FROM training_matrix"
                ).fetchall(),
                [("sig_fill", 1, 153.3)],
            )
            output_dir = Path(temp_dir) / "dataset"
            output_dir.mkdir()
            self.assertEqual(set(write_parquet_outputs(broker, output_dir, counts)), set(counts))
            broker.close()

            admission = duckdb.connect(":memory:")
            admission_counts = create_dataset_tables(
                admission,
                [validation],
                "admission",
                9,
                feature_columns_for_set(SUPPORTED_FEATURE_SET_ID),
            )
            self.assertEqual(admission_counts["training_matrix"], 2)
            self.assertEqual(
                admission.execute(
                    "SELECT signal_id, target_admitted FROM training_matrix ORDER BY signal_id"
                ).fetchall(),
                [("sig_deny", False), ("sig_fill", True)],
            )
            admission.close()

    def test_duplicate_identity_and_missing_context_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            path = run_path / SIGNAL_ATTEMPTS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], signal_id="sig_duplicate"))
            write_rows(path, columns, rows)
            with self.assertRaisesRegex(SchemaValidationError, "Duplicate signal or first-touch identity"):
                validate_run(runs_root, "schema_v9_pivot_fractal")

        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            path = run_path / SIGNAL_FEATURES_FILE
            columns, rows = read_rows(path)
            write_rows(path, columns, rows[:-1])
            with self.assertRaisesRegex(SchemaValidationError, "exactly six|Missing feature contexts"):
                validate_run(runs_root, "schema_v9_pivot_fractal")

    def test_future_feature_header_and_older_schema_are_rejected(self) -> None:
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            path = run_path / SIGNAL_FEATURES_FILE
            columns, rows = read_rows(path)
            columns.append("close_price")
            for row in rows:
                row["close_price"] = "1.2000000000"
            write_rows(path, columns, rows)
            with self.assertRaisesRegex(SchemaValidationError, "Header mismatch"):
                validate_run(runs_root, "schema_v9_pivot_fractal")

        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, _ = self.copy_fixture(temp_dir)
            with self.assertRaisesRegex(ValueError, "Unsupported schema version 8"):
                validate_run(runs_root, "schema_v9_pivot_fractal", schema_version=8)

    def test_outcome_without_fill_evidence_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            checks_path = run_path / "execution_checks.tsv"
            columns, rows = read_rows(checks_path)
            for row in rows:
                row["broker_entry_confirmed"] = "0"
                row["position_ticket"] = r"\N"
                row["position_identifier"] = r"\N"
            write_rows(checks_path, columns, rows)

            trailing_path = run_path / "trailing_events.tsv"
            trailing_columns, _ = read_rows(trailing_path)
            write_rows(trailing_path, trailing_columns, [])
            mutate_summary(run_path, "trailing_event_rows", "0")
            with self.assertRaisesRegex(SchemaValidationError, "outcome exists without matching fill evidence"):
                validate_run(runs_root, "schema_v9_pivot_fractal")


if __name__ == "__main__":
    unittest.main()
