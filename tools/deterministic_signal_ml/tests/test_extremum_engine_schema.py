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
    EXECUTION_CHECK_COLUMNS,
    PHASE1_FILES,
    SUPPORTED_SCHEMA_VERSION,
    default_feature_set_for_schema,
    feature_columns_for_set,
)
from validate_phase1_run import Phase1ValidationError, validate_phase1_run, validate_phase1_runs


FIXTURE = Path(__file__).parent / "fixtures" / "schema_v8_extremum_engine"


def mutate_row(run_path: Path, filename: str, identity_field: str, identity: str, field: str, value: str) -> None:
    path = run_path / filename
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    for row in rows:
        if row[identity_field] == identity:
            row[field] = value
            break
    else:
        raise AssertionError(f"Missing fixture row: {filename} {identity}")
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def rewrite_run_id(run_path: Path, run_id: str) -> None:
    for path in run_path.glob("*.tsv"):
        with path.open("r", encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        for row in rows:
            if path.name == "run_manifest.tsv" and row["key"] == "run_id":
                row["value"] = run_id
            elif "run_id" in row:
                row["run_id"] = run_id
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)


class ExtremumEngineSchemaTests(unittest.TestCase):
    def copy_fixture(self, temp_dir: str) -> tuple[Path, Path]:
        runs_root = Path(temp_dir) / "runs"
        run_path = runs_root / "schema_v8_extremum_engine"
        shutil.copytree(FIXTURE, run_path)
        return runs_root, run_path

    def test_schema_v8_is_the_only_active_contract(self) -> None:
        self.assertEqual(SUPPORTED_SCHEMA_VERSION, 8)
        self.assertEqual(default_feature_set_for_schema(8), "schema_v8_extremum_engine_xgb")
        self.assertIn("account_margin_mode_supported", EXECUTION_CHECK_COLUMNS)
        self.assertEqual(
            {path.name for path in FIXTURE.glob("*.tsv")},
            set(PHASE1_FILES),
        )

    def test_fixture_validates_and_builds_typed_parquet(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, _ = self.copy_fixture(temp_dir)
            validation = validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)
            self.assertEqual(validation.cycle_rows, 2)
            self.assertEqual(validation.attempt_rows, 2)
            self.assertEqual(validation.execution_check_rows, 6)

            connection = duckdb.connect(":memory:")
            counts = create_dataset_tables(
                connection,
                [validation],
                "broker_1r",
                8,
                feature_columns_for_set("schema_v8_extremum_engine"),
            )
            self.assertEqual(counts["engine_attempts"], 2)
            self.assertEqual(counts["execution_checks"], 6)
            self.assertEqual(counts["training_matrix"], 1)
            output_dir = Path(temp_dir) / "dataset"
            output_dir.mkdir()
            self.assertEqual(set(write_parquet_outputs(connection, output_dir, counts)), set(counts))

            simulated_connection = duckdb.connect(":memory:")
            simulated_counts = create_dataset_tables(
                simulated_connection,
                [validation],
                "engine_simulated_1r",
                8,
                feature_columns_for_set("schema_v8_extremum_engine_xgb"),
            )
            self.assertEqual(simulated_counts["training_matrix"], 2)
            sources = simulated_connection.execute(
                "SELECT DISTINCT target_source FROM training_matrix"
            ).fetchall()
            self.assertEqual(sources, [("ENGINE_SIMULATION",)])

    def test_multi_run_assembly_scopes_reused_engine_ids_by_run(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, _ = self.copy_fixture(temp_dir)
            second_run_id = "schema_v8_extremum_engine_2"
            second_run_path = runs_root / second_run_id
            shutil.copytree(FIXTURE, second_run_path)
            rewrite_run_id(second_run_path, second_run_id)
            validations = validate_phase1_runs(
                runs_root,
                ["schema_v8_extremum_engine", second_run_id],
                schema_version=8,
            )

            connection = duckdb.connect(":memory:")
            counts = create_dataset_tables(
                connection,
                validations,
                "broker_1r",
                8,
                feature_columns_for_set("schema_v8_extremum_engine_xgb"),
            )
            self.assertEqual(counts["engine_attempts"], 4)
            self.assertEqual(counts["execution_checks"], 12)
            self.assertEqual(counts["training_matrix"], 2)
            self.assertEqual(
                connection.execute(
                    "SELECT run_id, execution_check_count FROM training_matrix ORDER BY run_id"
                ).fetchall(),
                [
                    ("schema_v8_extremum_engine", 5),
                    (second_run_id, 5),
                ],
            )
            with self.assertRaisesRegex(Phase1ValidationError, "Duplicate run_id selection"):
                validate_phase1_runs(
                    runs_root,
                    ["schema_v8_extremum_engine", "schema_v8_extremum_engine"],
                    schema_version=8,
                )

    def test_inconsistent_time_conversion_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                "signal_features.tsv",
                "signal_id",
                "sig_fill",
                "entry_analysis_time",
                "2026.01.12 14:32:00",
            )
            with self.assertRaisesRegex(Phase1ValidationError, "Inconsistent analysis time conversion"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_changed_frozen_anchor_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                "engine_revisions.tsv",
                "revision_id",
                "C_WINTER_R1",
                "reference_peak_price",
                "42100.0",
            )
            with self.assertRaisesRegex(Phase1ValidationError, "Frozen anchors changed"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_orphan_attempt_revision_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "engine_attempts.tsv", "attempt_id", "C_SUMMER_A1", "revision_id", "MISSING")
            with self.assertRaisesRegex(Phase1ValidationError, "Orphan attempt revision"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_attempt_without_observation_check_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "execution_checks.tsv", "signal_id", "sig_block", "check_phase", "OPERATIONAL_BLOCK")
            with self.assertRaisesRegex(Phase1ValidationError, "no ATTEMPT_OBSERVED"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_duplicate_observation_check_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "execution_checks.tsv", "check_sequence", "2", "check_phase", "ATTEMPT_OBSERVED")
            with self.assertRaisesRegex(Phase1ValidationError, "exactly one ATTEMPT_OBSERVED"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_orphan_execution_check_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "execution_checks.tsv", "signal_id", "sig_block", "extremum_attempt_id", "MISSING")
            with self.assertRaisesRegex(Phase1ValidationError, "Orphan execution check"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_send_result_requires_pre_send_chain(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "execution_checks.tsv", "check_sequence", "2", "check_phase", "FILTER_RESULT")
            with self.assertRaisesRegex(Phase1ValidationError, "no PRE_SEND|PRE_SEND"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)

    def test_stale_attempt_broker_flags_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(run_path, "engine_attempts.tsv", "attempt_id", "C_WINTER_A1", "broker_entry_confirmed", "0")
            mutate_row(run_path, "engine_attempts.tsv", "attempt_id", "C_WINTER_A1", "broker_close_confirmed", "0")
            with self.assertRaisesRegex(Phase1ValidationError, "broker entry evidence|Attempt broker flags disagree"):
                validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)


if __name__ == "__main__":
    unittest.main()
