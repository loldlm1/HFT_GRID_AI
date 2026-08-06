from __future__ import annotations

import csv
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

import duckdb


MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from build_dataset import create_dataset_tables, write_parquet_outputs
from feature_encoder import FeatureEncoder, MISSING_CATEGORY
from model_config import FEATURE_ABLATIONS
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
)
from schema_contract import (
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    RUN_FILES,
    SUPPORTED_FEATURE_SET_ID,
    SchemaValidationError,
    validate_run,
    validate_runs,
)
from train_model import TrainingError, train_candidate
from validation_splits import GROUPING_POLICY, build_time_splits


FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v10_macro_micro_pivot"


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def write_rows(path: Path, columns: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def clone_run(runs_root: Path, run_id: str) -> Path:
    run_path = runs_root / run_id
    shutil.copytree(FIXTURE, run_path)
    for filename in RUN_FILES:
        path = run_path / filename
        columns, rows = read_rows(path)
        if filename == "run_manifest.tsv":
            for row in rows:
                if row["key"] == "run_id":
                    row["value"] = run_id
        else:
            for row in rows:
                row["run_id"] = run_id
        write_rows(path, columns, rows)
    return run_path


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


class PivotFractalResearchContractTests(unittest.TestCase):
    def test_builder_emits_one_complete_attempt_row_and_strict_binary_cohort(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        connection = duckdb.connect(":memory:")
        try:
            counts = create_dataset_tables(connection, [validation])
            self.assertEqual(counts["pivot_windows"], 1)
            self.assertEqual(counts["signal_attempts"], 4)
            self.assertEqual(counts["research_matrix"], 4)
            self.assertEqual(counts["binary_outcomes"], 2)
            self.assertEqual(
                connection.execute(
                    "SELECT signal_id, binary_target FROM binary_outcomes ORDER BY signal_id"
                ).fetchall(),
                [("sig_r1_sell_sl", 0), ("sig_s1_buy_tp", 1)],
            )
            self.assertEqual(
                connection.execute(
                    """
SELECT signal_id, level_id, direction, binary_target
FROM research_matrix
ORDER BY trigger_broker_time
"""
                ).fetchall(),
                [
                    ("sig_s1_buy_tp", "S1", "BUY", 1),
                    ("sig_r1_sell_sl", "R1", "SELL", 0),
                    ("sig_pp_buy_manual", "PP", "BUY", None),
                    ("sig_s2_denied", "S2", "BUY", None),
                ],
            )
            derived = connection.execute(
                """
SELECT trigger_gap_to_risk, spread_to_risk, macro_range_to_band_width,
       analysis_session
FROM research_matrix
WHERE signal_id = 'sig_s1_buy_tp'
"""
            ).fetchone()
            self.assertAlmostEqual(derived[0], 0.0)
            self.assertAlmostEqual(derived[1], 20.0 / 1020.0)
            self.assertAlmostEqual(derived[2], 0.5)
            self.assertEqual(derived[3], "SESSION_06_11")
            columns = {
                row[0] for row in connection.execute("DESCRIBE research_matrix").fetchall()
            }
            self.assertTrue(set(MODEL_FEATURE_COLUMNS).issubset(columns))
            self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        finally:
            connection.close()

    def test_mixed_dataset_configuration_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            runs_root.mkdir()
            clone_run(runs_root, "run_a")
            run_b = clone_run(runs_root, "run_b")

            manifest_path = run_b / "run_manifest.tsv"
            columns, rows = read_rows(manifest_path)
            for row in rows:
                if row["key"] == "micro_timeframe":
                    row["value"] = "PERIOD_M5"
            write_rows(manifest_path, columns, rows)
            for filename in ("pivot_windows.tsv", "signal_attempts.tsv", "signal_outcomes.tsv"):
                path = run_b / filename
                table_columns, table_rows = read_rows(path)
                for row in table_rows:
                    row["micro_timeframe"] = "PERIOD_M5"
                write_rows(path, table_columns, table_rows)

            with self.assertRaisesRegex(
                SchemaValidationError,
                "configuration boundaries",
            ):
                validate_runs(runs_root, ["run_a", "run_b"])

    def test_splits_group_duplicate_runs_and_purge_unavailable_outcomes(self) -> None:
        rows: list[dict[str, object]] = []
        start = datetime(2026, 1, 1, 10, 0)
        for group_index in range(12):
            trigger = start + timedelta(days=group_index)
            close = trigger + timedelta(hours=1)
            if group_index == 0:
                close = start + timedelta(days=20)
            for run_id in ("run_a", "run_b"):
                rows.append(
                    {
                        "run_id": run_id,
                        "symbol": "EURUSD",
                        "macro_timeframe": "PERIOD_H1",
                        "active_bar_open_broker_time": trigger.replace(minute=0),
                        "research_group_id": f"EURUSD|PERIOD_H1|{trigger:%Y.%m.%d %H:00:00}",
                        "trigger_broker_time": trigger,
                        "close_broker_time": close,
                    }
                )

        bundle = build_time_splits(
            rows,
            holdout_fraction=0.25,
            n_splits=2,
            gap=0,
            grouping_policy=GROUPING_POLICY,
        )
        self.assertGreater(bundle.metadata["purged_train_rows"], 0)
        for fold in bundle.folds:
            train_groups = {rows[index]["research_group_id"] for index in fold.train_indices}
            test_groups = {rows[index]["research_group_id"] for index in fold.test_indices}
            self.assertFalse(train_groups & test_groups)
            boundary = datetime.fromisoformat(fold.metadata["validation_boundary"])
            self.assertTrue(
                all(rows[index]["close_broker_time"] < boundary for index in fold.train_indices)
            )
        final_train_groups = {
            rows[index]["research_group_id"] for index in bundle.train_indices
        }
        holdout_groups = {
            rows[index]["research_group_id"] for index in bundle.holdout_indices
        }
        self.assertFalse(final_train_groups & holdout_groups)

    def test_encoder_keeps_unseen_categories_explicit(self) -> None:
        feature_columns = ("level_id", "micro_band_width_percent_0")
        encoder = FeatureEncoder.fit(
            [{"level_id": "S1", "micro_band_width_percent_0": 1.2}],
            feature_columns,
            ("level_id",),
        )
        encoded = encoder.transform(
            [{"level_id": "R3", "micro_band_width_percent_0": 2.4}]
        )
        missing_index = encoded.encoded_feature_names.index(
            f"level_id={MISSING_CATEGORY}"
        )
        self.assertEqual(encoded.matrix[0, missing_index], 1.0)
        self.assertEqual(encoder.categories["level_id"], ["S1", MISSING_CATEGORY])

    def test_ablation_order_is_incremental_and_reconstructs_v10_features(self) -> None:
        ablation_ids = [ablation_id for ablation_id, _ in FEATURE_ABLATIONS]
        self.assertEqual(
            ablation_ids,
            ["base", "widths", "micro_b_percent", "macro_b_percent"],
        )
        previous: set[str] = set()
        for _, columns in FEATURE_ABLATIONS:
            current = set(columns)
            self.assertTrue(previous <= current)
            previous = current
        self.assertEqual(previous, set(MODEL_FEATURE_COLUMNS))

    def test_fixture_training_stops_at_deterministic_support_guard(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_dir = Path(temp_dir) / "dataset"
            model_dir = Path(temp_dir) / "model"
            dataset_dir.mkdir()
            model_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            with self.assertRaisesRegex(TrainingError, "Not enough rows: 2 < 500"):
                train_candidate(
                    dataset_dir,
                    model_dir,
                    "fixture_model",
                    SUPPORTED_FEATURE_SET_ID,
                )


if __name__ == "__main__":
    unittest.main()
