from __future__ import annotations

import csv
import shutil
import sys
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from schema_contract import (
    EXECUTION_CHECKS_FILE,
    FIXED_LOT_MODE,
    FUTURE_ONLY_COLUMNS,
    MODEL_FEATURE_COLUMNS,
    PIVOT_WINDOWS_FILE,
    REFERENCE_LOT_MODE,
    RUN_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_ATTEMPTS_FILE,
    SIGNAL_OUTCOMES_FILE,
    SUPPORTED_ENGINE_LABEL,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    SchemaValidationError,
    expected_columns_for,
    feature_columns_for_set,
    validate_run,
)


FIXTURES = Path(__file__).parent / "fixtures"
V10_FIXTURE = FIXTURES / "schema_v10_macro_micro_pivot"
V9_FIXTURE = FIXTURES / "schema_v9_pivot_fractal"
NULL_TOKEN = r"\N"


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


def mutate_manifest(run_path: Path, key: str, value: str) -> None:
    path = run_path / RUN_MANIFEST_FILE
    columns, rows = read_rows(path)
    matches = [row for row in rows if row["key"] == key]
    if len(matches) != 1:
        raise AssertionError(f"Expected one manifest key {key}, found {len(matches)}")
    matches[0]["value"] = value
    write_rows(path, columns, rows)


def mutate_summary(run_path: Path, **values: str) -> None:
    path = run_path / RUN_SUMMARY_FILE
    columns, rows = read_rows(path)
    if len(rows) != 1:
        raise AssertionError("Fixture summary must contain one row")
    rows[0].update(values)
    write_rows(path, columns, rows)


def mutate_row(
    run_path: Path,
    filename: str,
    predicate: Callable[[dict[str, str]], bool],
    **values: str,
) -> None:
    path = run_path / filename
    columns, rows = read_rows(path)
    matches = [row for row in rows if predicate(row)]
    if len(matches) != 1:
        raise AssertionError(f"Expected one {filename} row, found {len(matches)}")
    matches[0].update(values)
    write_rows(path, columns, rows)


class PivotFractalSchemaTests(unittest.TestCase):
    def copy_fixture(self, temp_dir: str) -> tuple[Path, Path]:
        runs_root = Path(temp_dir) / "runs"
        run_path = runs_root / V10_FIXTURE.name
        shutil.copytree(V10_FIXTURE, run_path)
        return runs_root, run_path

    def assert_mutation_rejected(
        self,
        mutate: Callable[[Path], None],
        expected_error: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate(run_path)
            with self.assertRaisesRegex(SchemaValidationError, expected_error):
                validate_run(runs_root, V10_FIXTURE.name)

    def test_v10_fixture_freezes_exact_contract(self) -> None:
        validation = validate_run(FIXTURES, V10_FIXTURE.name)

        self.assertEqual(SUPPORTED_SCHEMA_VERSION, 10)
        self.assertEqual(SUPPORTED_ENGINE_LABEL, "PIVOT_FRACTAL_V2")
        self.assertEqual(
            SUPPORTED_FEATURE_SET_ID,
            "schema_v10_macro_micro_pivot_bands",
        )
        self.assertEqual(len(RUN_FILES), 6)
        self.assertEqual({path.name for path in V10_FIXTURE.glob("*.tsv")}, set(RUN_FILES))
        self.assertEqual(validation.pivot_window_rows, 1)
        self.assertEqual(validation.signal_attempt_rows, 4)
        self.assertEqual(validation.execution_check_rows, 7)
        self.assertEqual(validation.signal_outcome_rows, 3)
        self.assertEqual(validation.warnings, ())

        for filename in RUN_FILES:
            columns, _ = read_rows(V10_FIXTURE / filename)
            self.assertEqual(tuple(columns), TABLE_COLUMNS[filename])
            self.assertEqual(expected_columns_for(filename), TABLE_COLUMNS[filename])
        self.assertIn("source_open", TABLE_COLUMNS[PIVOT_WINDOWS_FILE])
        self.assertIn("excluded_manual_rows", TABLE_COLUMNS[RUN_SUMMARY_FILE])
        self.assertEqual(
            feature_columns_for_set(SUPPORTED_FEATURE_SET_ID),
            MODEL_FEATURE_COLUMNS,
        )
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))

    def test_v9_and_non_v10_shapes_are_rejected(self) -> None:
        with self.assertRaisesRegex(SchemaValidationError, "exactly six V10 TSV files"):
            validate_run(FIXTURES, V9_FIXTURE.name)
        with self.assertRaisesRegex(ValueError, "Unsupported schema version 9"):
            validate_run(FIXTURES, V10_FIXTURE.name, schema_version=9)

        def add_unexpected_file(run_path: Path) -> None:
            (run_path / "unexpected.tsv").write_text("unexpected\n", encoding="utf-8")

        self.assert_mutation_rejected(add_unexpected_file, "exactly six V10 TSV files")

        def add_future_header(run_path: Path) -> None:
            path = run_path / SIGNAL_ATTEMPTS_FILE
            columns, rows = read_rows(path)
            columns.append("close_price")
            for row in rows:
                row["close_price"] = "1.2000000000"
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(add_future_header, "Header mismatch")

    def test_manifest_policy_fails_closed(self) -> None:
        cases = (
            ("engine_label", "PIVOT_FRACTAL_V1", "fixed value mismatch"),
            ("bands_applied_price", "PRICE_CLOSE", "fixed value mismatch"),
            ("micro_timeframe", "PERIOD_H1", "Micro timeframe shorter"),
            ("lot_strategy_size", "0", "must be positive"),
        )
        for key, value, expected_error in cases:
            with self.subTest(key=key):
                self.assert_mutation_rejected(
                    lambda run_path, key=key, value=value: mutate_manifest(
                        run_path, key, value
                    ),
                    expected_error,
                )

    def test_macro_window_pivot_pp_and_band_semantics_fail_closed(self) -> None:
        cases: tuple[tuple[str, str, str], ...] = (
            ("source_open", "1.1200000000", "invalid Macro source OHLC"),
            ("raw_pp_price", "1.1010000000", "classic pivot formula mismatch"),
            ("trade_s2_price", "1.0700000000", "unordered trade pivot ladder"),
            ("macro_band_width_1", "0.0500000000", "band width arithmetic mismatch"),
        )
        for column, value, expected_error in cases:
            with self.subTest(column=column):
                self.assert_mutation_rejected(
                    lambda run_path, column=column, value=value: mutate_row(
                        run_path,
                        PIVOT_WINDOWS_FILE,
                        lambda row: row["window_id"] == "win_h1_202601121000",
                        **{column: value},
                    ),
                    expected_error,
                )

        def leave_strict_side_unarmed(run_path: Path) -> None:
            mutate_row(
                run_path,
                PIVOT_WINDOWS_FILE,
                lambda row: True,
                pp_role="UNARMED",
                pp_arm_broker_time=NULL_TOKEN,
                pp_arm_analysis_time=NULL_TOKEN,
                pp_arm_offset_minutes=NULL_TOKEN,
                pp_arm_bid=NULL_TOKEN,
            )

        self.assert_mutation_rejected(leave_strict_side_unarmed, "remained unarmed")

        def delay_initial_arm(run_path: Path) -> None:
            mutate_row(
                run_path,
                PIVOT_WINDOWS_FILE,
                lambda row: True,
                pp_arm_broker_time="2026.01.12 10:00:01",
                pp_arm_analysis_time="2026.01.12 10:00:01",
            )

        self.assert_mutation_rejected(delay_initial_arm, "first causal tick")

    def test_direction_trigger_route_and_one_r_semantics_fail_closed(self) -> None:
        cases = (
            (
                "sig_s1_buy_tp",
                {"direction": "SELL"},
                "support levels are BUY only",
            ),
            (
                "sig_pp_buy_manual",
                {"direction": "SELL"},
                "PP direction differs from armed role",
            ),
            (
                "sig_s1_buy_tp",
                {
                    "trigger_bid": "1.0901000000",
                    "spread_points": "10.0000000000",
                },
                "BUY trigger Bid did not reach pivot",
            ),
            (
                "sig_s1_buy_tp",
                {"structural_sl_price": "1.0700000000"},
                "structural SL matrix mismatch",
            ),
            (
                "sig_s1_buy_tp",
                {"observed_take_profit": "1.1005000000"},
                "invalid observation risk geometry",
            ),
            (
                "sig_s1_buy_tp",
                {"request_take_profit": "1.1005000000"},
                "not exact price-distance 1R",
            ),
        )
        for signal_id, values, expected_error in cases:
            with self.subTest(signal_id=signal_id, values=values):
                self.assert_mutation_rejected(
                    lambda run_path, signal_id=signal_id, values=values: mutate_row(
                        run_path,
                        SIGNAL_ATTEMPTS_FILE,
                        lambda row: row["signal_id"] == signal_id,
                        **values,
                    ),
                    expected_error,
                )

        def duplicate_consumed_identity(run_path: Path) -> None:
            path = run_path / SIGNAL_ATTEMPTS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], signal_id="sig_duplicate_identity"))
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(duplicate_consumed_identity, "duplicate consumed pivot identity")

    def test_denied_wrong_side_geometry_can_remain_a_raw_attempt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                SIGNAL_ATTEMPTS_FILE,
                lambda row: row["signal_id"] == "sig_s2_denied",
                observed_entry_price=NULL_TOKEN,
                observed_stop_loss=NULL_TOKEN,
                observed_take_profit=NULL_TOKEN,
                observed_risk_distance_points=NULL_TOKEN,
                observed_reward_distance_points=NULL_TOKEN,
            )
            validation = validate_run(runs_root, V10_FIXTURE.name)
            self.assertEqual(validation.signal_attempt_rows, 4)

    def test_band_features_are_formula_checked(self) -> None:
        cases = (
            ("micro_b_percent_0", "51.0000000000", "Micro %B shift 0 mismatch"),
            (
                "macro_pivot_b_percent_1",
                "26.0000000000",
                "Macro pivot %B shift 1 mismatch",
            ),
            (
                "micro_band_width_percent_0",
                "2.0000000000",
                "normalized band width mismatch",
            ),
        )
        for column, value, expected_error in cases:
            with self.subTest(column=column):
                self.assert_mutation_rejected(
                    lambda run_path, column=column, value=value: mutate_row(
                        run_path,
                        SIGNAL_ATTEMPTS_FILE,
                        lambda row: row["signal_id"] == "sig_s1_buy_tp",
                        **{column: value},
                    ),
                    expected_error,
                )

    def test_feature_incomplete_tp_is_valid_raw_fact_but_not_binary(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                SIGNAL_ATTEMPTS_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp",
                micro_features_complete="0",
                feature_snapshot_complete="0",
                feature_invalid_reason="MICRO_BANDS_UNAVAILABLE",
            )
            mutate_row(
                run_path,
                SIGNAL_OUTCOMES_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp",
                binary_eligible="0",
                binary_target=NULL_TOKEN,
                exclusion_reason="FEATURE_INCOMPLETE",
            )
            mutate_summary(
                run_path,
                feature_complete_rows="3",
                feature_incomplete_rows="1",
                binary_eligible_rows="1",
                binary_tp_rows="0",
                excluded_outcome_rows="2",
                excluded_feature_incomplete_rows="1",
            )
            validation = validate_run(runs_root, V10_FIXTURE.name)
            self.assertEqual(validation.signal_outcome_rows, 3)

    def test_execution_chain_and_ticket_ownership_fail_closed(self) -> None:
        cases = (
            (
                "sig_s1_buy_tp",
                "PRE_SEND",
                {"entry_price": "1.0902200000"},
                "fresh check differs from attempt",
            ),
            (
                "sig_s1_buy_tp",
                "SEND_RESULT",
                {"send_succeeded": "0"},
                "send result disagrees with attempt",
            ),
            (
                "sig_r1_sell_sl",
                "SEND_RESULT",
                {"position_identifier": "3001"},
                "duplicate position identifier ownership",
            ),
            (
                "sig_s1_buy_tp",
                "SEND_RESULT",
                {"broker_volume": "0.0900000000"},
                "broker entry changed owned broker_volume",
            ),
        )
        for signal_id, phase, values, expected_error in cases:
            with self.subTest(signal_id=signal_id, phase=phase):
                self.assert_mutation_rejected(
                    lambda run_path, signal_id=signal_id, phase=phase, values=values: mutate_row(
                        run_path,
                        EXECUTION_CHECKS_FILE,
                        lambda row: row["signal_id"] == signal_id
                        and row["check_phase"] == phase,
                        **values,
                    ),
                    expected_error,
                )

        def remove_entry_confirmation(run_path: Path) -> None:
            mutate_row(
                run_path,
                EXECUTION_CHECKS_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp"
                and row["check_phase"] == "SEND_RESULT",
                broker_entry_confirmed="0",
            )

        self.assert_mutation_rejected(remove_entry_confirmation, "lacks broker entry confirmation")

    def test_send_failed_attempt_is_a_valid_terminal_raw_fact(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                SIGNAL_ATTEMPTS_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp",
                attempt_status="SEND_FAILED",
                block_source="order_send",
                block_reason="TRADE_RETCODE_REJECT",
                send_succeeded="0",
            )
            mutate_row(
                run_path,
                EXECUTION_CHECKS_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp"
                and row["check_phase"] == "SEND_RESULT",
                allowed="0",
                block_source="order_send",
                block_reason="TRADE_RETCODE_REJECT",
                send_succeeded="0",
                broker_entry_confirmed="0",
                order_ticket=NULL_TOKEN,
                deal_ticket=NULL_TOKEN,
                position_ticket=NULL_TOKEN,
                position_identifier=NULL_TOKEN,
                broker_entry_price=NULL_TOKEN,
                broker_volume=NULL_TOKEN,
                broker_stop_loss=NULL_TOKEN,
                broker_take_profit=NULL_TOKEN,
            )

            outcomes_path = run_path / SIGNAL_OUTCOMES_FILE
            outcome_columns, outcomes = read_rows(outcomes_path)
            outcomes = [
                row for row in outcomes if row["signal_id"] != "sig_s1_buy_tp"
            ]
            write_rows(outcomes_path, outcome_columns, outcomes)
            mutate_summary(
                run_path,
                signal_outcome_rows="2",
                send_succeeded_rows="2",
                broker_filled_rows="2",
                broker_closed_rows="2",
                binary_eligible_rows="1",
                binary_tp_rows="0",
                excluded_outcome_rows="1",
            )

            validation = validate_run(runs_root, V10_FIXTURE.name)
            self.assertEqual(validation.signal_outcome_rows, 2)

    def test_accepted_order_can_end_terminal_without_a_fill(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                SIGNAL_ATTEMPTS_FILE,
                lambda row: row["signal_id"] == "sig_s1_buy_tp",
                attempt_status="SEND_FAILED",
                block_source="broker_order",
                block_reason="BROKER_ORDER_ORDER_STATE_CANCELED",
            )

            checks_path = run_path / EXECUTION_CHECKS_FILE
            check_columns, checks = read_rows(checks_path)
            send_row = next(
                row
                for row in checks
                if row["signal_id"] == "sig_s1_buy_tp"
                and row["check_phase"] == "SEND_RESULT"
            )
            send_row.update(
                deal_ticket=NULL_TOKEN,
                position_identifier=NULL_TOKEN,
                broker_entry_confirmed="0",
                broker_entry_price=NULL_TOKEN,
                broker_volume=NULL_TOKEN,
                broker_stop_loss=NULL_TOKEN,
                broker_take_profit=NULL_TOKEN,
            )
            terminal_row = dict(
                send_row,
                check_sequence="3",
                check_phase="TERMINAL",
                broker_time="2026.01.12 10:05:03",
                analysis_time="2026.01.12 10:05:03",
                allowed="0",
                block_source="broker_order",
                block_reason="BROKER_ORDER_ORDER_STATE_CANCELED",
                send_performed="0",
                send_succeeded="0",
                send_retcode=NULL_TOKEN,
            )
            checks.append(terminal_row)
            write_rows(checks_path, check_columns, checks)

            outcomes_path = run_path / SIGNAL_OUTCOMES_FILE
            outcome_columns, outcomes = read_rows(outcomes_path)
            outcomes = [
                row for row in outcomes if row["signal_id"] != "sig_s1_buy_tp"
            ]
            write_rows(outcomes_path, outcome_columns, outcomes)
            mutate_summary(
                run_path,
                execution_check_rows="8",
                signal_outcome_rows="2",
                broker_filled_rows="2",
                broker_closed_rows="2",
                binary_eligible_rows="1",
                binary_tp_rows="0",
                excluded_outcome_rows="1",
            )

            validation = validate_run(runs_root, V10_FIXTURE.name)
            self.assertEqual(validation.execution_check_rows, 8)

    def test_outcome_cost_slippage_binary_and_ownership_fail_closed(self) -> None:
        cases = (
            (
                "sig_s1_buy_tp",
                {"net_profit": "99.0000000000"},
                "net profit cost arithmetic mismatch",
            ),
            (
                "sig_r1_sell_sl",
                {"entry_slippage_points": "-5.0000000000"},
                "entry slippage sign/arithmetic mismatch",
            ),
            (
                "sig_pp_buy_manual",
                {"binary_target": "0"},
                "nonbinary outcome carries binary target",
            ),
            (
                "sig_s1_buy_tp",
                {"position_identifier": "3999"},
                "changed entry ownership fact",
            ),
        )
        for signal_id, values, expected_error in cases:
            with self.subTest(signal_id=signal_id, values=values):
                self.assert_mutation_rejected(
                    lambda run_path, signal_id=signal_id, values=values: mutate_row(
                        run_path,
                        SIGNAL_OUTCOMES_FILE,
                        lambda row: row["signal_id"] == signal_id,
                        **values,
                    ),
                    expected_error,
                )

    def test_fixed_lot_runs_keep_budget_fields_not_applicable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_manifest(run_path, "lot_mode", FIXED_LOT_MODE)
            mutate_manifest(run_path, "lot_strategy_size", "0.10000000")

            attempts_path = run_path / SIGNAL_ATTEMPTS_FILE
            attempt_columns, attempts = read_rows(attempts_path)
            for row in attempts:
                row["lot_mode"] = FIXED_LOT_MODE
                row["lot_strategy_size"] = "0.10000000"
                row["reference_balance"] = NULL_TOKEN
                row["risk_budget_amount"] = NULL_TOKEN
                row["risk_budget_utilization_ratio"] = NULL_TOKEN
                if row["signal_id"] == "sig_s2_denied":
                    row["block_source"] = "session"
                    row["block_reason"] = "MARKET_SESSION_CLOSED"
            write_rows(attempts_path, attempt_columns, attempts)

            checks_path = run_path / EXECUTION_CHECKS_FILE
            check_columns, checks = read_rows(checks_path)
            for row in checks:
                row["risk_budget_amount"] = NULL_TOKEN
                row["risk_budget_utilization_ratio"] = NULL_TOKEN
                if row["signal_id"] == "sig_s2_denied":
                    row["market_session_open"] = "0"
                    row["block_source"] = "session"
                    row["block_reason"] = "MARKET_SESSION_CLOSED"
            write_rows(checks_path, check_columns, checks)

            outcomes_path = run_path / SIGNAL_OUTCOMES_FILE
            outcome_columns, outcomes = read_rows(outcomes_path)
            for row in outcomes:
                row["risk_budget_amount"] = NULL_TOKEN
                row["risk_budget_utilization_ratio"] = NULL_TOKEN
                row["gross_budget_r"] = NULL_TOKEN
                row["net_budget_r"] = NULL_TOKEN
            write_rows(outcomes_path, outcome_columns, outcomes)

            validation = validate_run(runs_root, V10_FIXTURE.name)
            self.assertEqual(validation.manifest["lot_mode"], FIXED_LOT_MODE)
            self.assertNotEqual(validation.manifest["lot_mode"], REFERENCE_LOT_MODE)

    def test_summary_counts_fail_closed(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_summary(run_path, binary_tp_rows="2"),
            "run summary count mismatch for binary_tp_rows",
        )


if __name__ == "__main__":
    unittest.main()
