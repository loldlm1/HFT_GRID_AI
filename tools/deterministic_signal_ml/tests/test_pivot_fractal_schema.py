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
from retest_confluence import (
    BUY_RETEST,
    EQUAL_NEUTRAL,
    OPPOSED,
    SELL_RETEST,
    classify_retest,
)
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

    def make_same_trigger_batch(self, run_path: Path) -> None:
        attempts_path = run_path / SIGNAL_ATTEMPTS_FILE
        attempt_columns, attempts = read_rows(attempts_path)
        shared_attempt_values = {
            column: attempts[0][column]
            for column in (
                "trigger_broker_time",
                "trigger_analysis_time",
                "trigger_offset_minutes",
                "previous_m1_bar_open_broker_time",
                "previous_m1_close_boundary_broker_time",
                "trigger_bid",
                "trigger_ask",
                "spread_points",
            )
        }
        shared_attempt_values["previous_m1_bid_close"] = "1.1160000000"
        for attempt in attempts:
            attempt.update(shared_attempt_values)
        write_rows(attempts_path, attempt_columns, attempts)

        features_path = run_path / SIGNAL_FEATURES_FILE
        feature_columns, features = read_rows(features_path)
        reference_by_context = {
            row["context_timeframe"]: row
            for row in features
            if row["signal_id"] == "sig_fill"
        }
        shared_feature_columns = (
            "trigger_broker_time",
            "trigger_analysis_time",
            "trigger_offset_minutes",
            "structure_0",
            "structure_1",
            "structure_2",
            "b_percent_0",
            "b_percent_1",
            "b_percent_2",
            "b_percent_3",
            "b_percent_4",
            "b_percent_5",
            "structure_complete",
            "b_percent_complete",
            "feature_complete",
            "invalid_reason",
        )
        for feature in features:
            if feature["signal_id"] != "sig_deny":
                continue
            reference = reference_by_context[feature["context_timeframe"]]
            for column in shared_feature_columns:
                feature[column] = reference[column]
        write_rows(features_path, feature_columns, features)

    def test_v9_fixture_validates_and_builds_both_research_lanes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, _ = self.copy_fixture(temp_dir)
            validation = validate_run(runs_root, "schema_v9_pivot_fractal")
            self.assertEqual(SUPPORTED_SCHEMA_VERSION, 9)
            self.assertEqual(validation.pivot_window_rows, 5)
            self.assertEqual(validation.pivot_level_rows, 35)
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
            self.assertEqual(counts["signal_retest_context"], 12)
            self.assertEqual(
                broker.execute(
                    """
                    SELECT context_timeframe, retest_type, alignment
                    FROM signal_retest_context
                    WHERE signal_id = 'sig_fill'
                    ORDER BY context_timeframe_rank
                    """
                ).fetchall(),
                [
                    ("PERIOD_M1", BUY_RETEST, "ALIGNED"),
                    ("PERIOD_M15", BUY_RETEST, "ALIGNED"),
                    ("PERIOD_M30", SELL_RETEST, OPPOSED),
                    ("PERIOD_H1", EQUAL_NEUTRAL, "NEUTRAL"),
                    ("PERIOD_H4", BUY_RETEST, "ALIGNED"),
                    ("PERIOD_D1", SELL_RETEST, OPPOSED),
                ],
            )
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

    def test_retest_classifier_is_symmetric_and_neutral_within_tolerance(self) -> None:
        self.assertEqual(classify_retest(1.1001, 1.1000), BUY_RETEST)
        self.assertEqual(classify_retest(1.0999, 1.1000), SELL_RETEST)
        self.assertEqual(classify_retest(1.100000005, 1.1000), EQUAL_NEUTRAL)
        self.assertEqual(classify_retest(None, 1.1000), "UNAVAILABLE")

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

    def test_future_context_and_pre_open_attempt_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            path = run_path / SIGNAL_ATTEMPTS_FILE
            columns, rows = read_rows(path)
            rows[0]["previous_m1_close_boundary_broker_time"] = "2026.01.12 10:04:00"
            write_rows(path, columns, rows)
            with self.assertRaisesRegex(SchemaValidationError, "previous M1 context is not causal"):
                validate_run(runs_root, "schema_v9_pivot_fractal")

        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            path = run_path / SIGNAL_ATTEMPTS_FILE
            columns, rows = read_rows(path)
            rows[0]["trigger_broker_time"] = "2026.01.12 09:59:59"
            rows[0]["trigger_analysis_time"] = "2026.01.12 09:59:59"
            write_rows(path, columns, rows)
            with self.assertRaisesRegex(SchemaValidationError, "outside its active pivot window"):
                validate_run(runs_root, "schema_v9_pivot_fractal")

    def test_same_trigger_batch_requires_one_frozen_feature_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            self.make_same_trigger_batch(run_path)
            validate_run(runs_root, "schema_v9_pivot_fractal")

            path = run_path / SIGNAL_FEATURES_FILE
            columns, rows = read_rows(path)
            for row in rows:
                if row["signal_id"] == "sig_deny" and row["context_timeframe"] == "PERIOD_M1":
                    row["b_percent_0"] = "55.1"
                    break
            write_rows(path, columns, rows)
            with self.assertRaisesRegex(SchemaValidationError, "feature snapshot divergence"):
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
