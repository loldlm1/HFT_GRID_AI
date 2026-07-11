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
    SCHEMA_V6_ADMISSION_COLUMNS,
    SCHEMA_V7_ATTEMPT_COLUMNS,
    SUPPORTED_SCHEMA_VERSION,
    default_feature_set_for_schema,
    feature_columns_for_set,
)
from validate_phase1_run import Phase1ValidationError, validate_phase1_run


FIXTURE = Path(__file__).parent / "fixtures" / "schema_v7_extremum_engine"


def mutate_attempt(run_path: Path, attempt_id: str, field: str, value: str) -> None:
    attempts_path = run_path / "engine_attempts.tsv"
    with attempts_path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    for row in rows:
        if row["attempt_id"] == attempt_id:
            row[field] = value
            break
    else:
        raise AssertionError(f"Missing fixture attempt: {attempt_id}")
    with attempts_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


class ExtremumEngineSchemaTests(unittest.TestCase):
    def test_schema_v7_is_active_and_v6_contract_is_preserved(self) -> None:
        self.assertEqual(SUPPORTED_SCHEMA_VERSION, 7)
        self.assertEqual(default_feature_set_for_schema(7), "schema_v7_extremum_engine_xgb")
        self.assertIn("admission_source", SCHEMA_V6_ADMISSION_COLUMNS)
        self.assertIn("simulated_outcome_source", SCHEMA_V7_ATTEMPT_COLUMNS)

    def test_fixture_validates_and_builds_parquet(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            validation = validate_phase1_run(runs_root, "fixture_v7", schema_version=7)
            self.assertEqual(validation.cycle_rows, 1)
            self.assertEqual(validation.revision_rows, 2)
            self.assertEqual(validation.attempt_rows, 2)

            connection = duckdb.connect(":memory:")
            counts = create_dataset_tables(
                connection,
                [validation],
                "broker_1r",
                7,
                feature_columns_for_set("schema_v7_extremum_engine"),
            )
            self.assertEqual(counts["engine_attempts"], 2)
            self.assertEqual(counts["training_matrix"], 1)
            output_dir = Path(temp_dir) / "dataset"
            output_dir.mkdir()
            outputs = write_parquet_outputs(connection, output_dir, counts)
            self.assertEqual(set(outputs), set(counts))

            simulated_connection = duckdb.connect(":memory:")
            simulated_counts = create_dataset_tables(
                simulated_connection,
                [validation],
                "engine_simulated_1r",
                7,
                feature_columns_for_set("schema_v7_extremum_engine_xgb"),
            )
            self.assertEqual(simulated_counts["training_matrix"], 2)
            sources = simulated_connection.execute(
                "SELECT DISTINCT target_source FROM training_matrix"
            ).fetchall()
            self.assertEqual(sources, [("ENGINE_SIMULATION",)])

    def test_changed_frozen_anchor_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            revisions_path = run_path / "engine_revisions.tsv"
            with revisions_path.open("r", encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle, delimiter="\t"))
            rows[1]["reference_peak_price"] = "1.12000"
            with revisions_path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t")
                writer.writeheader()
                writer.writerows(rows)
            with self.assertRaisesRegex(Phase1ValidationError, "Frozen anchors changed"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_invalid_simulated_provenance_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            attempts_path = run_path / "engine_attempts.tsv"
            text = attempts_path.read_text(encoding="utf-8").replace(
                "ENGINE_SIMULATION", "BROKER_CONFIRMED", 1
            )
            attempts_path.write_text(text, encoding="utf-8")
            with self.assertRaisesRegex(Phase1ValidationError, "Invalid simulated provenance"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_orphan_attempt_revision_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            attempts_path = run_path / "engine_attempts.tsv"
            text = attempts_path.read_text(encoding="utf-8").replace("C_1_R2", "C_1_RX", 1)
            attempts_path.write_text(text, encoding="utf-8")
            with self.assertRaisesRegex(Phase1ValidationError, "Orphan attempt revision"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_zero_attempt_target_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            mutate_attempt(run_path, "C_1_A1", "take_profit_price", "0")
            with self.assertRaisesRegex(Phase1ValidationError, "Invalid attempt geometry"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_wrong_side_attempt_target_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            mutate_attempt(run_path, "C_1_A2", "take_profit_price", "1.10300")
            with self.assertRaisesRegex(Phase1ValidationError, "Wrong-side attempt target"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_simulated_target_r_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            mutate_attempt(run_path, "C_1_A2", "simulated_profit_r", "99")
            with self.assertRaisesRegex(Phase1ValidationError, "Simulated target R mismatch"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)

    def test_stale_attempt_broker_flags_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            run_path = runs_root / "fixture_v7"
            shutil.copytree(FIXTURE, run_path)
            mutate_attempt(run_path, "C_1_A2", "broker_entry_confirmed", "0")
            mutate_attempt(run_path, "C_1_A2", "broker_close_confirmed", "0")
            with self.assertRaisesRegex(Phase1ValidationError, "Attempt broker flags disagree"):
                validate_phase1_run(runs_root, "fixture_v7", schema_version=7)


if __name__ == "__main__":
    unittest.main()
