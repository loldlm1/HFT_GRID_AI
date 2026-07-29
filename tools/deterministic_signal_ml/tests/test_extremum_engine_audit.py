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
from extremum_engine_audit import build_audit, nearest_fibonacci
from schema_contract import feature_columns_for_set
from validate_phase1_run import validate_phase1_run


FIXTURE = Path(__file__).parent / "fixtures" / "schema_v8_extremum_engine"


class ExtremumEngineAuditTests(unittest.TestCase):
    def test_nearest_fibonacci_keeps_raw_depth_semantics(self) -> None:
        level, delta = nearest_fibonacci(39.0)
        self.assertEqual(level, 38.2)
        self.assertAlmostEqual(delta, 0.8)
        self.assertAlmostEqual(nearest_fibonacci(63.0)[0], 61.8)
        self.assertEqual(nearest_fibonacci(-5.0), (0.0, 5.0))
        self.assertEqual(nearest_fibonacci(161.8), (161.8, 0.0))
        self.assertEqual(nearest_fibonacci(205.0), (200.0, 5.0))

    def test_audit_keeps_simulated_and_broker_lanes_separate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            runs_root = root / "runs"
            run_path = runs_root / "schema_v8_extremum_engine"
            shutil.copytree(FIXTURE, run_path)
            validation = validate_phase1_run(runs_root, "schema_v8_extremum_engine", schema_version=8)
            connection = duckdb.connect(":memory:")
            counts = create_dataset_tables(
                connection,
                [validation],
                "broker_1r",
                8,
                feature_columns_for_set("schema_v8_extremum_engine"),
            )
            dataset_dir = root / "datasets" / "fixture_dataset"
            dataset_dir.mkdir(parents=True)
            write_parquet_outputs(connection, dataset_dir, counts)

            audit_dir = root / "audits" / "fixture_audit"
            metadata = build_audit(dataset_dir, audit_dir, "fixture_audit")
            self.assertEqual(metadata["outcome_lanes"], ["ENGINE_SIMULATION", "BROKER_CONFIRMED"])

            with (audit_dir / "fibonacci_proximity.tsv").open(encoding="utf-8", newline="") as handle:
                proximity = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(
                sorted(float(row["nearest_fib_level"]) for row in proximity),
                [38.2, 61.8],
            )

            with (audit_dir / "cycle_sequences.tsv").open(encoding="utf-8", newline="") as handle:
                sequences = list(csv.DictReader(handle, delimiter="\t"))
            simulated = [row for row in sequences if row["outcome_source"] == "ENGINE_SIMULATION"]
            broker = [row for row in sequences if row["outcome_source"] == "BROKER_CONFIRMED"]
            self.assertEqual(len(simulated), 2)
            self.assertEqual(len(broker), 1)
            self.assertEqual(
                sorted(float(row["cycle_total_profit_r"]) for row in simulated),
                [-1.0, 2.0],
            )
            self.assertAlmostEqual(float(broker[0]["cycle_total_profit_r"]), 2.0)


if __name__ == "__main__":
    unittest.main()
