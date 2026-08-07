from __future__ import annotations

import csv
import json
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

from build_dataset import (
    BROKER_VIRTUAL_CALIBRATION_TABLE,
    ELIGIBLE_VIRTUAL_TRIALS_TABLE,
    INITIAL_MATRIX_WIDE_TABLE,
    ORIGIN_MATRIX_LONG_TABLE,
    POLICY_CHAINS_TABLE,
    create_dataset_tables,
    write_parquet_outputs,
)
from feature_encoder import FeatureEncoder, MISSING_CATEGORY
from model_config import FEATURE_ABLATIONS
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
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
from validation_splits import (
    GROUPING_POLICY,
    build_time_splits,
    origin_balanced_weights,
)


FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v11_pivot_trial_matrix"


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
        write_quality_json(output_dir, quality)
        write_dataset_report(output_dir, "fixture_dataset", quality)
        return counts
    finally:
        connection.close()


class PivotFractalResearchContractTests(unittest.TestCase):
    def test_builder_emits_all_v11_views_and_exact_grains(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        connection = duckdb.connect(":memory:")
        try:
            counts = create_dataset_tables(connection, [validation])
            self.assertEqual(counts[ORIGIN_MATRIX_LONG_TABLE], 18)
            self.assertEqual(counts[INITIAL_MATRIX_WIDE_TABLE], 1)
            self.assertEqual(counts[ELIGIBLE_VIRTUAL_TRIALS_TABLE], 16)
            self.assertEqual(counts[POLICY_CHAINS_TABLE], 16)
            self.assertEqual(counts[BROKER_VIRTUAL_CALIBRATION_TABLE], 1)
            self.assertEqual(
                connection.execute(
                    """
SELECT policy_id, attempts, losses_before_success, final_reentry_index,
       closed_nominal_r, chain_terminal_reason
FROM policy_chains
WHERE policy_id = 'policy_micro_bw_13_tp3'
"""
                ).fetchone(),
                ("policy_micro_bw_13_tp3", 3, 2, 2, 1.0, "TP_REACHED"),
            )
            self.assertEqual(
                connection.execute(
                    """
SELECT count(*)
FROM origin_matrix_long
WHERE eligibility_status <> 'ACTIVE' OR terminal_status = 'CENSORED'
"""
                ).fetchone()[0],
                2,
            )
            self.assertEqual(
                connection.execute(
                    """
SELECT strict_pair_eligible, terminal_agreement,
       crossing_close_delta_seconds,
       broker_minus_virtual_gross_profit
FROM broker_virtual_calibration
"""
                ).fetchone(),
                (True, True, 1, -1.0),
            )
            weights = connection.execute(
                """
SELECT origin_id, sum(origin_sample_weight)
FROM eligible_virtual_trials
GROUP BY origin_id
"""
            ).fetchall()
            self.assertEqual(weights, [("origin_s1_buy", 1.0)])
            wide_columns = {
                row[0]
                for row in connection.execute("DESCRIBE initial_matrix_wide").fetchall()
            }
            trial_id_columns = {
                column
                for column in wide_columns
                if column.endswith("_trial_id") and "tp" in column
            }
            self.assertEqual(len(trial_id_columns), 16)
        finally:
            connection.close()

    def test_parquet_artifact_contains_raw_and_derived_v11_tables(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            counts = build_dataset_artifact(output_dir)
            expected = {f"{table}.parquet" for table in counts}
            actual = {path.name for path in output_dir.glob("*.parquet")}
            self.assertEqual(actual, expected)
            manifest = json.loads(
                (output_dir / "dataset_manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(manifest["schema_version"], 11)
            self.assertEqual(manifest["feature_set_id"], SUPPORTED_FEATURE_SET_ID)
            self.assertEqual(
                tuple(manifest["feature_contract"]["model_features"]),
                MODEL_FEATURE_COLUMNS,
            )
            self.assertEqual(
                manifest["feature_contract"]["target"],
                "virtual_binary_target",
            )
            self.assertTrue(manifest["feature_contract"]["broker_target_separate"])

    def test_mixed_dataset_configuration_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root = Path(temp_dir) / "runs"
            first = clone_run(runs_root, "fixture_a")
            second = clone_run(runs_root, "fixture_b")
            manifest_path = second / "run_manifest.tsv"
            columns, rows = read_rows(manifest_path)
            for row in rows:
                if row["key"] == "lot_strategy_size":
                    row["value"] = "0.02000000"
            write_rows(manifest_path, columns, rows)
            trial_path = second / "virtual_trials.tsv"
            columns, rows = read_rows(trial_path)
            for row in rows:
                row["lot_strategy_size"] = "0.0200000000"
            write_rows(trial_path, columns, rows)

            validate_run(runs_root, first.name)
            validate_run(runs_root, second.name)
            with self.assertRaisesRegex(
                SchemaValidationError,
                "configuration boundaries",
            ):
                validate_runs(runs_root, [first.name, second.name])

    def test_splits_group_duplicate_runs_purge_future_outcomes_and_balance_origins(self) -> None:
        base = datetime(2026, 1, 1, 0, 0, 0)
        rows: list[dict[str, object]] = []
        for group_index in range(10):
            declared = base + timedelta(hours=group_index)
            for duplicate_index in range(2):
                rows.append(
                    {
                        "run_id": f"run_{duplicate_index}",
                        "origin_id": f"origin_{group_index}",
                        "policy_id": f"policy_{group_index}_{duplicate_index}",
                        "trial_id": f"trial_{group_index}_{duplicate_index}",
                        "symbol": "EURUSD",
                        "macro_timeframe": "PERIOD_H1",
                        "active_bar_open_broker_time": declared,
                        "research_group_id": f"EURUSD|PERIOD_H1|{declared:%Y.%m.%d %H:%M:%S}",
                        "declared_broker_time": declared,
                        "terminal_broker_time": declared + timedelta(minutes=20),
                    }
                )
        rows[0]["terminal_broker_time"] = base + timedelta(hours=9)
        bundle = build_time_splits(
            rows,
            holdout_fraction=0.20,
            n_splits=2,
            gap=1,
            grouping_policy=GROUPING_POLICY,
        )
        train_groups = {rows[index]["research_group_id"] for index in bundle.train_indices}
        holdout_groups = {rows[index]["research_group_id"] for index in bundle.holdout_indices}
        self.assertFalse(train_groups & holdout_groups)
        self.assertNotIn(0, bundle.train_indices)
        for fold in bundle.folds:
            fold_train = {rows[index]["research_group_id"] for index in fold.train_indices}
            fold_test = {rows[index]["research_group_id"] for index in fold.test_indices}
            self.assertFalse(fold_train & fold_test)

        weights = origin_balanced_weights(rows, list(range(len(rows))))
        totals: dict[str, float] = {}
        for row, weight in zip(rows, weights):
            origin_id = str(row["origin_id"])
            totals[origin_id] = totals.get(origin_id, 0.0) + weight
        self.assertTrue(all(abs(total - 1.0) < 1e-12 for total in totals.values()))

    def test_encoder_keeps_unseen_categories_explicit(self) -> None:
        rows = [
            {"symbol": "EURUSD", "sl_policy": "STRUCTURAL", "tp_r_multiple": 1.0},
            {"symbol": "XAUUSD", "sl_policy": "MICRO_BW_13", "tp_r_multiple": 3.0},
        ]
        encoder = FeatureEncoder.fit(
            rows,
            ("symbol", "sl_policy", "tp_r_multiple"),
            ("symbol", "sl_policy"),
        )
        transformed = encoder.transform(
            [{"symbol": "GBPUSD", "sl_policy": None, "tp_r_multiple": 2.0}]
        )
        self.assertEqual(transformed.matrix.shape[0], 1)
        symbol_missing = transformed.encoded_feature_names.index(
            f"symbol={MISSING_CATEGORY}"
        )
        policy_missing = transformed.encoded_feature_names.index(
            f"sl_policy={MISSING_CATEGORY}"
        )
        self.assertEqual(transformed.matrix[0, symbol_missing], 1.0)
        self.assertEqual(transformed.matrix[0, policy_missing], 1.0)

    def test_ablation_order_reconstructs_v11_features_without_leakage(self) -> None:
        previous: set[str] = set()
        for _, columns in FEATURE_ABLATIONS:
            current = set(columns)
            self.assertTrue(previous <= current)
            previous = current
        self.assertEqual(previous, set(MODEL_FEATURE_COLUMNS))
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertIn("sl_policy", MODEL_FEATURE_COLUMNS)
        self.assertIn("tp_r_multiple", MODEL_FEATURE_COLUMNS)
        self.assertIn("reentry_index", MODEL_FEATURE_COLUMNS)
        self.assertIn("preceding_loss_count", MODEL_FEATURE_COLUMNS)

    def test_fixture_training_stops_at_deterministic_support_guard(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dataset_dir = root / "dataset"
            model_dir = root / "model"
            dataset_dir.mkdir()
            model_dir.mkdir()
            build_dataset_artifact(dataset_dir)
            with self.assertRaisesRegex(TrainingError, "Not enough rows"):
                train_candidate(
                    dataset_dir,
                    model_dir,
                    "fixture_model",
                    SUPPORTED_FEATURE_SET_ID,
                )


if __name__ == "__main__":
    unittest.main()
