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
    ACTIVE_STATE_CAP,
    BROKER_OUTCOMES_FILE,
    EXECUTION_CHECKS_FILE,
    FIXED_MANIFEST_VALUES,
    FUTURE_ONLY_COLUMNS,
    INITIAL_MATRIX_SIZE,
    MAX_MATRIX_TRIALS_PER_ORIGIN,
    MAX_REENTRY_INDEX,
    MODEL_FEATURE_COLUMNS,
    PIVOT_WINDOWS_FILE,
    RUN_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_ORIGINS_FILE,
    SL_POLICIES,
    SUPPORTED_ENGINE_LABEL,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    TP_R_MULTIPLES,
    VIRTUAL_OUTCOMES_FILE,
    VIRTUAL_TRIALS_FILE,
    SchemaValidationError,
    expected_columns_for,
    feature_columns_for_set,
    validate_run,
)


FIXTURES = Path(__file__).parent / "fixtures"
V11_FIXTURE = FIXTURES / "schema_v11_pivot_trial_matrix"
LEGACY_FIXTURES = tuple(
    fixture for fixture in FIXTURES.iterdir() if fixture != V11_FIXTURE
)
NULL_TOKEN = r"\N"
GEOMETRY_COLUMNS = (
    "requested_risk_distance_price",
    "requested_risk_distance_points",
    "normalized_risk_ticks",
    "normalized_risk_distance_price",
    "normalized_risk_distance_points",
    "stop_loss_price",
    "take_profit_price",
    "geometry_equivalence_id",
    "minimum_risk_distance_points",
)
MONEY_COLUMNS = (
    "risk_budget_amount",
    "requested_volume",
    "normalized_volume",
    "virtual_expected_stop_loss",
    "virtual_expected_take_profit",
    "virtual_expected_reward_risk_ratio",
)


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


def make_gap_through_structural_origin(run_path: Path) -> None:
    origin_path = run_path / SIGNAL_ORIGINS_FILE
    origin_columns, origins = read_rows(origin_path)
    if len(origins) != 1:
        raise AssertionError("Fixture must contain one origin")
    origin = origins[0]
    old_ask = float(origin["trigger_ask"])
    new_bid = 1.0790
    new_ask = 1.0792
    price_shift = new_ask - old_ask
    origin.update(
        trigger_bid=f"{new_bid:.10f}",
        trigger_ask=f"{new_ask:.10f}",
        structural_entry_price=f"{new_ask:.10f}",
        structural_take_profit=f"{2.0 * new_ask - float(origin['structural_sl_price']):.10f}",
        broker_attempt_status="BLOCKED",
    )
    write_rows(origin_path, origin_columns, origins)

    trial_path = run_path / VIRTUAL_TRIALS_FILE
    trial_columns, trials = read_rows(trial_path)
    removed_retry_ids = {
        row["trial_id"]
        for row in trials
        if row["trial_role"] == "MATRIX" and row["reentry_index"] != "0"
    }
    trials = [
        row
        for row in trials
        if row["trial_role"] != "BROKER_PARITY"
        and row["trial_id"] not in removed_retry_ids
    ]
    shifted_trial_ids: set[str] = set()
    structural_trial_ids: set[str] = set()
    for row in trials:
        if row["trial_role"] != "MATRIX" or row["reentry_index"] != "0":
            continue
        row["entry_bid"] = f"{new_bid:.10f}"
        row["entry_ask"] = f"{new_ask:.10f}"
        row["entry_price"] = f"{new_ask:.10f}"
        if row["sl_policy"] == "STRUCTURAL":
            structural_trial_ids.add(row["trial_id"])
            for column in GEOMETRY_COLUMNS + MONEY_COLUMNS:
                row[column] = NULL_TOKEN
            row["distance_eligible"] = "0"
            row["boundary_eligible"] = "0"
            row["virtual_money_plan_complete"] = "0"
            row["eligibility_status"] = "INELIGIBLE_GEOMETRY"
            row["ineligible_reason"] = "STRUCTURAL_STOP_WRONG_SIDE_OF_ORIGIN_ENTRY"
            continue
        shifted_trial_ids.add(row["trial_id"])
        for column in ("stop_loss_price", "take_profit_price"):
            if row[column] != NULL_TOKEN:
                row[column] = f"{float(row[column]) + price_shift:.10f}"
        if row["geometry_equivalence_id"] != NULL_TOKEN:
            row["geometry_equivalence_id"] += "_gap"
    write_rows(trial_path, trial_columns, trials)

    outcome_path = run_path / VIRTUAL_OUTCOMES_FILE
    outcome_columns, outcomes = read_rows(outcome_path)
    outcomes = [
        row
        for row in outcomes
        if row["trial_role"] != "BROKER_PARITY"
        and row["trial_id"] not in structural_trial_ids
        and row["trial_id"] not in removed_retry_ids
    ]
    for row in outcomes:
        if row["trial_id"] not in shifted_trial_ids:
            continue
        for column in (
            "threshold_price",
            "observed_exit_bid",
            "observed_exit_ask",
            "observed_exit_price",
        ):
            if row[column] != NULL_TOKEN:
                row[column] = f"{float(row[column]) + price_shift:.10f}"
        if row["next_trial_id"] in removed_retry_ids:
            row["chain_terminal"] = "1"
            row["chain_terminal_reason"] = "NEXT_PIVOT_BOUNDARY"
            row["continuation_allowed"] = "0"
            row["continuation_reason"] = NULL_TOKEN
            row["next_reentry_index"] = NULL_TOKEN
            row["next_trial_id"] = NULL_TOKEN
    write_rows(outcome_path, outcome_columns, outcomes)

    for filename in (EXECUTION_CHECKS_FILE, BROKER_OUTCOMES_FILE):
        path = run_path / filename
        columns, _ = read_rows(path)
        write_rows(path, columns, [])

    mutate_summary(
        run_path,
        virtual_trial_rows="16",
        matrix_trial_rows="16",
        reentry_trial_rows="0",
        parity_trial_rows="0",
        virtual_active_trial_rows="11",
        virtual_ineligible_geometry_rows="4",
        virtual_outcome_rows="11",
        matrix_tp_rows="8",
        matrix_sl_rows="2",
        parity_outcome_rows="0",
        execution_check_rows="0",
        broker_outcome_rows="0",
        broker_binary_eligible_rows="0",
        broker_binary_tp_rows="0",
        parity_pair_rows="0",
        parity_terminal_match_rows="0",
        chain_tp_complete_rows="8",
        chain_next_pivot_boundary_rows="2",
        chain_ineligible_rows="5",
        active_state_peak="11",
    )


class PivotFractalSchemaTests(unittest.TestCase):
    def copy_fixture(self, temp_dir: str) -> tuple[Path, Path]:
        runs_root = Path(temp_dir) / "runs"
        run_path = runs_root / V11_FIXTURE.name
        shutil.copytree(V11_FIXTURE, run_path)
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
                validate_run(runs_root, V11_FIXTURE.name)

    def test_v11_fixture_freezes_exact_contract(self) -> None:
        validation = validate_run(FIXTURES, V11_FIXTURE.name)

        self.assertEqual(SUPPORTED_SCHEMA_VERSION, 11)
        self.assertEqual(SUPPORTED_ENGINE_LABEL, "PIVOT_FRACTAL_V2")
        self.assertEqual(SUPPORTED_FEATURE_SET_ID, "schema_v11_pivot_trial_matrix")
        self.assertEqual(len(RUN_FILES), 8)
        self.assertEqual(INITIAL_MATRIX_SIZE, 16)
        self.assertEqual(MAX_REENTRY_INDEX, 3)
        self.assertEqual(MAX_MATRIX_TRIALS_PER_ORIGIN, 52)
        self.assertEqual(ACTIVE_STATE_CAP, 2048)
        self.assertEqual(
            {path.name for path in V11_FIXTURE.glob("*.tsv")},
            set(RUN_FILES),
        )
        self.assertEqual(validation.pivot_window_rows, 1)
        self.assertEqual(validation.signal_origin_rows, 1)
        self.assertEqual(validation.virtual_trial_rows, 19)
        self.assertEqual(validation.virtual_outcome_rows, 18)
        self.assertEqual(validation.execution_check_rows, 4)
        self.assertEqual(validation.broker_outcome_rows, 1)
        self.assertEqual(validation.warnings, ("run completion is CENSORED",))

        for filename in RUN_FILES:
            columns, _ = read_rows(V11_FIXTURE / filename)
            self.assertEqual(tuple(columns), TABLE_COLUMNS[filename])
            self.assertEqual(expected_columns_for(filename), TABLE_COLUMNS[filename])
        self.assertEqual(
            feature_columns_for_set(SUPPORTED_FEATURE_SET_ID),
            MODEL_FEATURE_COLUMNS,
        )
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertFalse(
            {"broker_commission", "broker_swap", "broker_fee", "broker_net_profit"}
            & set(TABLE_COLUMNS[VIRTUAL_OUTCOMES_FILE])
        )
        self.assertTrue(
            {"broker_gross_profit", "broker_commission", "broker_net_profit"}
            <= set(TABLE_COLUMNS[BROKER_OUTCOMES_FILE])
        )
        self.assertEqual(FIXED_MANIFEST_VALUES["matrix_sl_ratios"], "0.13,0.21,0.34")
        self.assertEqual(FIXED_MANIFEST_VALUES["matrix_tp_multiples"], "1,2,3,5")

        _, trials = read_rows(V11_FIXTURE / VIRTUAL_TRIALS_FILE)
        initial = [
            row
            for row in trials
            if row["trial_role"] == "MATRIX" and row["reentry_index"] == "0"
        ]
        self.assertEqual(
            [(row["sl_policy"], int(row["tp_r_multiple"])) for row in initial],
            [(sl_policy, tp) for sl_policy in SL_POLICIES for tp in TP_R_MULTIPLES],
        )
        self.assertEqual(
            sum(row["eligibility_status"] == "INELIGIBLE_MONEY_PLAN" for row in initial),
            1,
        )
        _, outcomes = read_rows(V11_FIXTURE / VIRTUAL_OUTCOMES_FILE)
        chain = sorted(
            (
                row
                for row in outcomes
                if row["policy_id"] == "policy_micro_bw_13_tp3"
            ),
            key=lambda row: int(row["reentry_index"]),
        )
        self.assertEqual([row["terminal_status"] for row in chain], ["SL_FIRST", "SL_FIRST", "TP_FIRST"])
        self.assertAlmostEqual(sum(float(row["virtual_nominal_r"]) for row in chain), 1.0)
        self.assertEqual(
            sum(row["trial_role"] == "BROKER_PARITY" for row in outcomes),
            1,
        )

    def test_legacy_and_non_v11_shapes_are_rejected(self) -> None:
        for fixture in LEGACY_FIXTURES:
            with self.subTest(fixture=fixture.name):
                with self.assertRaisesRegex(
                    SchemaValidationError,
                    "exactly eight V11 TSV files",
                ):
                    validate_run(FIXTURES, fixture.name)
        with self.assertRaisesRegex(ValueError, "Unsupported schema version 10"):
            validate_run(FIXTURES, V11_FIXTURE.name, schema_version=10)

        def add_unexpected_file(run_path: Path) -> None:
            (run_path / "unexpected.tsv").write_text("unexpected\n", encoding="utf-8")

        self.assert_mutation_rejected(add_unexpected_file, "exactly eight V11 TSV files")

        def reorder_header(run_path: Path) -> None:
            path = run_path / SIGNAL_ORIGINS_FILE
            columns, rows = read_rows(path)
            columns[0], columns[1] = columns[1], columns[0]
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(reorder_header, "Header mismatch")

    def test_manifest_fixed_policies_fail_closed(self) -> None:
        cases = (
            ("engine_label", "PIVOT_FRACTAL_V1", "fixed value mismatch"),
            ("matrix_sl_ratios", "0.12,0.21,0.34", "fixed value mismatch"),
            ("matrix_tp_multiples", "1,2,3,4", "fixed value mismatch"),
            ("reentry_max_index", "4", "fixed value mismatch"),
            ("minimum_distance_policy", "spread_plus_stops_plus_freeze", "fixed value mismatch"),
            ("active_state_cap", "4096", "fixed value mismatch"),
            ("micro_timeframe", "PERIOD_H1", "Micro timeframe shorter"),
            ("lot_strategy_size", "0", "must be positive"),
        )
        for key, value, expected_error in cases:
            with self.subTest(key=key):
                self.assert_mutation_rejected(
                    lambda run_path, key=key, value=value: mutate_manifest(
                        run_path,
                        key,
                        value,
                    ),
                    expected_error,
                )

    def test_window_and_origin_identity_semantics_fail_closed(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                PIVOT_WINDOWS_FILE,
                lambda row: True,
                raw_pp_price="1.1010000000",
            ),
            "classic pivot formula mismatch",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                SIGNAL_ORIGINS_FILE,
                lambda row: True,
                pivot_trade_price="1.0910000000",
            ),
            "pivot_trade_price mismatch",
        )

        def duplicate_origin_identity(run_path: Path) -> None:
            path = run_path / SIGNAL_ORIGINS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], origin_id="origin_duplicate", broker_signal_id="broker_duplicate"))
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(duplicate_origin_identity, "duplicate consumed pivot identity")

    def test_initial_matrix_count_order_and_identity_fail_closed(self) -> None:
        def remove_initial_cell(run_path: Path) -> None:
            path = run_path / VIRTUAL_TRIALS_FILE
            columns, rows = read_rows(path)
            rows = [row for row in rows if row["trial_id"] != "trial_micro_bw_34_tp5_r0"]
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(remove_initial_cell, "exactly sixteen initial matrix cells")

        def reorder_initial_cells(run_path: Path) -> None:
            path = run_path / VIRTUAL_TRIALS_FILE
            columns, rows = read_rows(path)
            rows[0], rows[1] = rows[1], rows[0]
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(reorder_initial_cells, "in policy order")

        def duplicate_policy_identity(run_path: Path) -> None:
            path = run_path / VIRTUAL_TRIALS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], trial_id="duplicate_trial_id"))
            write_rows(path, columns, rows)

        self.assert_mutation_rejected(duplicate_policy_identity, "duplicate matrix policy/retry identity")

    def test_gap_through_structural_cells_are_explicitly_ineligible(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            make_gap_through_structural_origin(run_path)
            validation = validate_run(runs_root, V11_FIXTURE.name)
            self.assertEqual(validation.virtual_trial_rows, 16)
            self.assertEqual(validation.virtual_outcome_rows, 11)
            _, trials = read_rows(run_path / VIRTUAL_TRIALS_FILE)
            structural = [
                row
                for row in trials
                if row["trial_role"] == "MATRIX"
                and row["sl_policy"] == "STRUCTURAL"
            ]
            self.assertEqual(len(structural), 4)
            self.assertTrue(
                all(row["eligibility_status"] == "INELIGIBLE_GEOMETRY" for row in structural)
            )
            self.assertTrue(all(row["stop_loss_price"] == NULL_TOKEN for row in structural))
            self.assertTrue(all(row["virtual_money_plan_complete"] == "0" for row in structural))

        def reflect_structural_stop(run_path: Path) -> None:
            make_gap_through_structural_origin(run_path)
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1_r0",
                requested_risk_distance_price="0.0008000000",
                requested_risk_distance_points="8.0000000000",
                normalized_risk_ticks="8",
                normalized_risk_distance_price="0.0008000000",
                normalized_risk_distance_points="8.0000000000",
                stop_loss_price="1.0784000000",
                take_profit_price="1.0800000000",
                geometry_equivalence_id="geom_reflected_structural_gap",
                minimum_risk_distance_points="8.0000000000",
                distance_eligible="1",
                boundary_eligible="1",
                risk_budget_amount="100.0000000000",
                requested_volume="0.1000000000",
                normalized_volume="0.1000000000",
                virtual_expected_stop_loss="-100.0000000000",
                virtual_expected_take_profit="100.0000000000",
                virtual_expected_reward_risk_ratio="1.0000000000",
                virtual_money_plan_complete="1",
                eligibility_status="ACTIVE",
                ineligible_reason=NULL_TOKEN,
            )

        self.assert_mutation_rejected(
            reflect_structural_stop,
            "wrong-side structural route must be geometry-ineligible",
        )

        def retain_reflected_structural_geometry(run_path: Path) -> None:
            make_gap_through_structural_origin(run_path)
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1_r0",
                requested_risk_distance_price="0.0008000000",
                requested_risk_distance_points="8.0000000000",
                normalized_risk_ticks="8",
                normalized_risk_distance_price="0.0008000000",
                normalized_risk_distance_points="8.0000000000",
                stop_loss_price="1.0784000000",
                take_profit_price="1.0800000000",
                geometry_equivalence_id=NULL_TOKEN,
                minimum_risk_distance_points="8.0000000000",
            )

        self.assert_mutation_rejected(
            retain_reflected_structural_geometry,
            "unavailable geometry carries values",
        )

        def retain_ineligible_structural_money(run_path: Path) -> None:
            make_gap_through_structural_origin(run_path)
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1_r0",
                risk_budget_amount="100.0000000000",
                requested_volume="0.1000000000",
                normalized_volume="0.1000000000",
                virtual_expected_stop_loss="-100.0000000000",
                virtual_expected_take_profit="100.0000000000",
                virtual_expected_reward_risk_ratio="1.0000000000",
            )

        self.assert_mutation_rejected(
            retain_ineligible_structural_money,
            "ineligible trial carries money values",
        )

    def test_retry_chain_invariants_fail_closed(self) -> None:
        def skip_retry_index(run_path: Path) -> None:
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r2",
                reentry_index="3",
                preceding_loss_count="3",
            )
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r2",
                reentry_index="3",
            )

        self.assert_mutation_rejected(skip_retry_index, "retry index gap")

        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r1",
                sl_policy="STRUCTURAL",
                policy_id="policy_structural_tp3",
            ),
            "structural policy cannot re-enter",
        )

        def consume_tp_before_retry(run_path: Path) -> None:
            _, trials = read_rows(run_path / VIRTUAL_TRIALS_FILE)
            trial = next(row for row in trials if row["trial_id"] == "trial_micro_bw_13_tp3_r0")
            tp = trial["take_profit_price"]
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == trial["trial_id"],
                terminal_status="TP_FIRST",
                terminal_reason="TP_THRESHOLD",
                threshold_price=tp,
                observed_exit_bid=tp,
                observed_exit_ask=f"{float(tp) + 0.0002:.10f}",
                observed_exit_price=tp,
                gap_points="0.0000000000",
                virtual_nominal_r="3.0000000000",
                virtual_quote_gross_profit="300.0000000000",
                virtual_quote_gross_r="3.0000000000",
                virtual_binary_target="1",
                chain_terminal="1",
                chain_terminal_reason="TP_REACHED",
                continuation_allowed="0",
                continuation_reason=NULL_TOKEN,
                next_reentry_index=NULL_TOKEN,
                next_trial_id=NULL_TOKEN,
            )

        self.assert_mutation_rejected(consume_tp_before_retry, "retry lacks immediately preceding SL_FIRST")

        def create_two_generations_on_one_tick(run_path: Path) -> None:
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r1",
                declared_broker_time="2026.01.12 10:05:00",
                declared_analysis_time="2026.01.12 10:05:00",
            )
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r1",
                duration_seconds="600",
            )

        self.assert_mutation_rejected(create_two_generations_on_one_tick, "more than one generation per tick")

    def test_quote_geometry_distance_and_boundary_rules_fail_closed(self) -> None:
        cases = (
            (
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp1_r0",
                {"entry_quote_side": "BID"},
                "wrong executable entry quote side",
            ),
            (
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp1_r0",
                {"minimum_risk_distance_points": "9.0000000000"},
                "minimum distance formula mismatch",
            ),
            (
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp1_r0",
                {"normalized_risk_distance_price": "0.0012000000"},
                "normalized tick risk mismatch",
            ),
            (
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_21_tp5_r0",
                {"chain_terminal_reason": "REENTRY_CAP_REACHED"},
                "terminal reason does not match cap/boundary/expiry",
            ),
            (
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_13_tp3_r2",
                {"terminal_status": "SL_FIRST", "terminal_reason": "SL_THRESHOLD"},
                "first-touch threshold mismatch",
            ),
        )
        for filename, predicate, values, expected_error in cases:
            with self.subTest(expected_error=expected_error):
                self.assert_mutation_rejected(
                    lambda run_path, filename=filename, predicate=predicate, values=values: mutate_row(
                        run_path,
                        filename,
                        predicate,
                        **values,
                    ),
                    expected_error,
                )

    def test_virtual_broker_and_parity_lanes_fail_closed(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_micro_bw_34_tp3_r0",
                virtual_binary_target="0",
            ),
            "censored outcome carries virtual_binary_target",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                BROKER_OUTCOMES_FILE,
                lambda row: True,
                broker_net_profit="99.0000000000",
            ),
            "broker net profit cost arithmetic mismatch",
        )

        def mismatch_parity_terminal(run_path: Path) -> None:
            mutate_row(
                run_path,
                BROKER_OUTCOMES_FILE,
                lambda row: True,
                broker_terminal_reason="BROKER_SL",
                broker_binary_target="0",
            )

        self.assert_mutation_rejected(mismatch_parity_terminal, "broker/parity TP/SL terminal mismatch")

    def test_broker_parity_can_declare_at_origin_expiry(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            boundary_time = "2026.01.12 11:00:00"
            terminal_time = "2026.01.12 11:00:01"
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "parity_broker_sig_s1",
                declared_broker_time=boundary_time,
                declared_analysis_time=boundary_time,
                origin_window_active_at_entry="0",
            )
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "parity_broker_sig_s1",
                terminal_broker_time=terminal_time,
                terminal_analysis_time=terminal_time,
                duration_seconds="1",
            )
            for phase, event_time in (
                ("PRE_SEND", boundary_time),
                ("SEND_RESULT", boundary_time),
                ("TERMINAL", terminal_time),
            ):
                mutate_row(
                    run_path,
                    EXECUTION_CHECKS_FILE,
                    lambda row, phase=phase: row["check_phase"] == phase,
                    broker_time=event_time,
                    analysis_time=event_time,
                )
            mutate_row(
                run_path,
                BROKER_OUTCOMES_FILE,
                lambda row: True,
                entry_broker_time=boundary_time,
                entry_analysis_time=boundary_time,
                close_broker_time=terminal_time,
                close_analysis_time=terminal_time,
                duration_seconds="1",
            )
            mutate_summary(
                run_path,
                finished_broker_time=terminal_time,
                finished_analysis_time=terminal_time,
            )

            validate_run(runs_root, V11_FIXTURE.name)

        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "parity_broker_sig_s1",
                origin_window_active_at_entry="0",
            ),
            "broker parity origin-window flag mismatch",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1_r0",
                declared_broker_time="2026.01.12 11:00:00",
                declared_analysis_time="2026.01.12 11:00:00",
            ),
            "trial declaration is outside origin lifetime",
        )

    def test_feature_incomplete_broker_outcome_is_excluded_from_calibration(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            runs_root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                SIGNAL_ORIGINS_FILE,
                lambda row: True,
                origin_macro_features_complete="0",
                origin_feature_snapshot_complete="0",
                origin_feature_invalid_reason="MACRO_BANDS_INCOMPLETE",
            )
            mutate_row(
                run_path,
                BROKER_OUTCOMES_FILE,
                lambda row: True,
                broker_binary_eligible="0",
                broker_binary_target=NULL_TOKEN,
                broker_exclusion_reason="FEATURE_INCOMPLETE",
            )
            mutate_summary(
                run_path,
                broker_binary_eligible_rows="0",
                broker_binary_tp_rows="0",
                broker_excluded_rows="1",
                parity_terminal_match_rows="0",
                parity_excluded_rows="1",
            )

            validate_run(runs_root, V11_FIXTURE.name)

    def test_execution_safety_contract_fails_closed(self) -> None:
        cases = (
            ({"fill_policy": "ORDER_FILLING_IOC"}, "not FOK-only"),
            ({"trade_action": "TRADE_ACTION_SLTP"}, "non-deal trade action"),
            ({"protection_modified": "1"}, "protection was modified"),
        )
        for values, expected_error in cases:
            with self.subTest(values=values):
                self.assert_mutation_rejected(
                    lambda run_path, values=values: mutate_row(
                        run_path,
                        EXECUTION_CHECKS_FILE,
                        lambda row: row["check_phase"] == "SEND_RESULT",
                        **values,
                    ),
                    expected_error,
                )

        def create_second_send(run_path: Path) -> None:
            mutate_row(
                run_path,
                EXECUTION_CHECKS_FILE,
                lambda row: row["check_phase"] == "PRE_SEND",
                send_performed="1",
                send_succeeded="1",
                trade_action="TRADE_ACTION_DEAL",
                send_retcode="10009",
                send_comment="DONE",
            )

        self.assert_mutation_rejected(create_second_send, "multiple sends")

    def test_summary_counts_and_integrity_fail_closed(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_summary(run_path, matrix_tp_rows="14"),
            "run summary count mismatch for matrix_tp_rows",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_summary(run_path, active_state_cap="4096"),
            "active-state cap/peak mismatch",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_summary(run_path, state_capacity_failed="1"),
            "state capacity failure",
        )


if __name__ == "__main__":
    unittest.main()
