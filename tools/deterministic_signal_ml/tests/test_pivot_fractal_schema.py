from __future__ import annotations

import csv
import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from collections.abc import Callable
from datetime import datetime, timedelta
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parents[1]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

from schema_contract import (
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_REGISTRY_SHA256,
    DEEP_MICRO_FEATURE_COLUMNS,
    DEEP_PIVOT_EVENTS_FILE,
    DEEP_PIVOT_PARENT_LINKS_FILE,
    DEEP_TP_R_MULTIPLES,
    DEEP_VIRTUAL_OUTCOMES_FILE,
    DEEP_VIRTUAL_TRIALS_FILE,
    EXECUTION_CHECKS_FILE,
    FUTURE_ONLY_COLUMNS,
    H1_ENTRY_POLICIES,
    H1_MATRIX_SIZE,
    H1_TP_R_MULTIPLES,
    MODEL_FEATURE_COLUMNS,
    NULL_TOKEN,
    ORIGIN_SIGNAL_FEATURE_COLUMNS,
    RUN_FILES,
    RUN_MANIFEST_FILE,
    RUN_SUMMARY_FILE,
    SIGNAL_ORIGINS_FILE,
    STORAGE_ROOT,
    SUPPORTED_FEATURE_SET_ID,
    SUPPORTED_SCHEMA_VERSION,
    TABLE_COLUMNS,
    VIRTUAL_OUTCOMES_FILE,
    VIRTUAL_TRIALS_FILE,
    SchemaValidationError,
    _validate_broker_outcomes,
    _validate_deep,
    _validate_manifest,
    _normalize_risk_ticks_outward,
    expected_columns_for,
    validate_run,
)
from parent_chronology import audit_run, recover_run

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "schema_v13_hft_deep_pivot_features"
V12_FIXTURE = FIXTURES / "schema_v12_pivot_signal_features"


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def write_rows(path: Path, columns: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def mutate_manifest(run_path: Path, key: str, value: str) -> None:
    columns, rows = read_rows(run_path / RUN_MANIFEST_FILE)
    next(row for row in rows if row["key"] == key)["value"] = value
    write_rows(run_path / RUN_MANIFEST_FILE, columns, rows)


def mutate_row(
    run_path: Path,
    filename: str,
    predicate: Callable[[dict[str, str]], bool],
    **values: str,
) -> None:
    columns, rows = read_rows(run_path / filename)
    matches = [row for row in rows if predicate(row)]
    if len(matches) != 1:
        raise AssertionError(f"Expected one {filename} row, found {len(matches)}")
    matches[0].update(values)
    write_rows(run_path / filename, columns, rows)


def mutate_rows(
    run_path: Path,
    filename: str,
    predicate: Callable[[dict[str, str]], bool],
    **values: str,
) -> None:
    path = run_path / filename
    columns, rows = read_rows(path)
    matches = [row for row in rows if predicate(row)]
    if not matches:
        raise AssertionError(f"Expected at least one {filename} row")
    for row in matches:
        row.update(values)
    write_rows(path, columns, rows)


def make_midpoint_pending(run_path: Path) -> None:
    trial_id = "trial_midpoint_50_tp5"
    mutate_row(
        run_path,
        VIRTUAL_TRIALS_FILE,
        lambda row: row["trial_id"] == trial_id,
        entry_broker_time=NULL_TOKEN,
        entry_analysis_time=NULL_TOKEN,
        entry_offset_minutes=NULL_TOKEN,
        entry_bid=NULL_TOKEN,
        entry_ask=NULL_TOKEN,
        entry_price=NULL_TOKEN,
        entry_quote_side=NULL_TOKEN,
        exit_quote_side=NULL_TOKEN,
        midpoint_touched="0",
        requested_risk_distance_price=NULL_TOKEN,
        requested_risk_distance_points=NULL_TOKEN,
        normalized_risk_ticks=NULL_TOKEN,
        normalized_risk_distance_price=NULL_TOKEN,
        normalized_risk_distance_points=NULL_TOKEN,
        stop_loss_price=NULL_TOKEN,
        take_profit_price=NULL_TOKEN,
        geometry_equivalence_id=NULL_TOKEN,
        spread_points="0.0000000000",
        point_size="0.0000000000",
        trade_tick_size="0.0000000000",
        stops_level_points="0.0000000000",
        freeze_level_points="0.0000000000",
        minimum_risk_distance_points=NULL_TOKEN,
        distance_eligible="0",
        risk_budget_amount=NULL_TOKEN,
        requested_volume=NULL_TOKEN,
        normalized_volume=NULL_TOKEN,
        virtual_expected_stop_loss=NULL_TOKEN,
        virtual_expected_take_profit=NULL_TOKEN,
        virtual_expected_reward_risk_ratio=NULL_TOKEN,
        virtual_money_plan_complete="0",
        eligibility_status="NOT_TRIGGERED",
        ineligible_reason="MIDPOINT_PENDING_TOUCH",
        origin_window_active_at_entry="0",
    )
    mutate_row(
        run_path,
        VIRTUAL_OUTCOMES_FILE,
        lambda row: row["trial_id"] == trial_id,
        terminal_status="NOT_TRIGGERED",
        terminal_reason="STRUCTURAL_LANES_UNAVAILABLE",
        threshold_price=NULL_TOKEN,
        gap_points=NULL_TOKEN,
        h1_structural_lifecycle_seconds=NULL_TOKEN,
        virtual_nominal_r=NULL_TOKEN,
        virtual_quote_gross_profit=NULL_TOKEN,
        virtual_quote_gross_r=NULL_TOKEN,
        virtual_binary_eligible="0",
        virtual_binary_target=NULL_TOKEN,
        virtual_exclusion_reason="NOT_TRIGGERED",
    )
    mutate_row(
        run_path,
        RUN_SUMMARY_FILE,
        lambda row: True,
        h1_sl_rows="0",
        h1_not_triggered_rows="1",
    )


class PivotFractalV13SchemaTests(unittest.TestCase):
    def copy_fixture(self, temp_dir: str) -> tuple[Path, Path]:
        root = Path(temp_dir)
        run_path = root / FIXTURE.name
        shutil.copytree(FIXTURE, run_path)
        return root, run_path

    def assert_mutation_rejected(
        self,
        mutate: Callable[[Path], None],
        expected_error: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            mutate(run_path)
            with self.assertRaisesRegex(SchemaValidationError, expected_error):
                validate_run(root, FIXTURE.name)

    def test_fixture_freezes_exact_v13_contract(self) -> None:
        validation = validate_run(FIXTURES, FIXTURE.name)
        self.assertEqual(SUPPORTED_SCHEMA_VERSION, 13)
        self.assertEqual(SUPPORTED_FEATURE_SET_ID, "schema_v13_hft_deep_pivot_features")
        self.assertEqual(STORAGE_ROOT, r"Common\Files\PivotFractalV13\runs")
        self.assertEqual(len(RUN_FILES), 12)
        self.assertEqual(H1_MATRIX_SIZE, 8)
        self.assertEqual(H1_ENTRY_POLICIES, ("STRUCTURAL", "MIDPOINT_50"))
        self.assertEqual(H1_TP_R_MULTIPLES, (1, 2, 3, 5))
        self.assertEqual(DEEP_TP_R_MULTIPLES, (1, 2, 3))
        self.assertEqual(validation.signal_origin_rows, 1)
        self.assertEqual(validation.virtual_trial_rows, 9)
        self.assertEqual(validation.deep_event_rows, 1)
        self.assertEqual(validation.deep_parent_link_rows, 2)
        self.assertEqual(validation.deep_trial_rows, 3)
        self.assertEqual(validation.deep_outcome_rows, 6)
        self.assertEqual({path.name for path in FIXTURE.glob("*.tsv")}, set(RUN_FILES))
        for filename in RUN_FILES:
            columns, _ = read_rows(FIXTURE / filename)
            self.assertEqual(tuple(columns), TABLE_COLUMNS[filename])
            self.assertEqual(expected_columns_for(filename), TABLE_COLUMNS[filename])

    def test_registry_is_exhaustive_disjoint_and_stable(self) -> None:
        schema_columns = {column for columns in TABLE_COLUMNS.values() for column in columns}
        self.assertEqual(set(COLUMN_TYPE_BY_NAME), schema_columns)
        self.assertEqual(
            COLUMN_TYPE_REGISTRY_SHA256,
            "986c4868fb70b08e18296e8679a5ad2aeebe59849571ef2b7ee58fcab8cde3c1",
        )
        self.assertFalse(set(MODEL_FEATURE_COLUMNS) & set(FUTURE_ONLY_COLUMNS))
        self.assertNotIn("h1_structural_lifecycle_seconds", MODEL_FEATURE_COLUMNS)
        self.assertNotIn("terminal_status", MODEL_FEATURE_COLUMNS)

    def test_features_have_one_native_owner(self) -> None:
        self.assertTrue(set(ORIGIN_SIGNAL_FEATURE_COLUMNS) <= set(TABLE_COLUMNS[SIGNAL_ORIGINS_FILE]))
        self.assertTrue(set(DEEP_MICRO_FEATURE_COLUMNS) <= set(TABLE_COLUMNS[DEEP_PIVOT_EVENTS_FILE]))
        for filename in (
            VIRTUAL_TRIALS_FILE,
            VIRTUAL_OUTCOMES_FILE,
            DEEP_PIVOT_PARENT_LINKS_FILE,
            DEEP_VIRTUAL_TRIALS_FILE,
            DEEP_VIRTUAL_OUTCOMES_FILE,
        ):
            self.assertFalse(set(ORIGIN_SIGNAL_FEATURE_COLUMNS) & set(TABLE_COLUMNS[filename]))
            self.assertFalse(set(DEEP_MICRO_FEATURE_COLUMNS) & set(TABLE_COLUMNS[filename]))

    def test_v12_and_legacy_shapes_are_rejected(self) -> None:
        with self.assertRaisesRegex(SchemaValidationError, "twelve V13 TSV files"):
            validate_run(FIXTURES, V12_FIXTURE.name)
        with self.assertRaisesRegex(ValueError, "Unsupported schema version 12"):
            validate_run(FIXTURES, FIXTURE.name, schema_version=12)

        def add_old_file(run_path: Path) -> None:
            (run_path / "signal_attempts.tsv").write_text("schema_version\n", encoding="ascii")

        self.assert_mutation_rejected(add_old_file, "twelve V13 TSV files")

    def test_manifest_requires_micro_deep_macro_ordering(self) -> None:
        cases = (
            ("deep_timeframe", "PERIOD_M3"),
            ("deep_timeframe", "PERIOD_H1"),
            ("micro_timeframe", "PERIOD_M10"),
            ("macro_timeframe", "PERIOD_M10"),
        )
        for key, value in cases:
            with self.subTest(key=key, value=value):
                self.assert_mutation_rejected(
                    lambda run_path, key=key, value=value: mutate_manifest(run_path, key, value),
                    "Micro < Deep < Macro",
                )

    def test_midpoint_geometry_is_exact(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                SIGNAL_ORIGINS_FILE,
                lambda row: True,
                midpoint_50_price="1.0849000000",
            ),
            "exact midpoint geometry mismatch",
        )

    def test_pending_midpoint_has_no_entry_quote_or_geometry(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            make_midpoint_pending(run_path)
            validation = validate_run(root, FIXTURE.name)
            self.assertEqual(validation.virtual_trial_rows, 9)

        def add_pre_entry_quote_facts(run_path: Path) -> None:
            make_midpoint_pending(run_path)
            mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_midpoint_50_tp5",
                point_size="0.0001000000",
            )

        self.assert_mutation_rejected(
            add_pre_entry_quote_facts,
            "pending midpoint carries pre-entry quote facts",
        )

    def test_h1_lane_matrix_has_no_retry_or_old_band_identity(self) -> None:
        columns = TABLE_COLUMNS[VIRTUAL_TRIALS_FILE]
        for removed in ("reentry_index", "preceding_loss_count", "sl_policy"):
            self.assertNotIn(removed, columns)
        _, rows = read_rows(FIXTURE / VIRTUAL_TRIALS_FILE)
        matrix = [row for row in rows if row["trial_role"] == "H1"]
        self.assertEqual(
            {(row["entry_policy"], int(row["tp_r_multiple"])) for row in matrix},
            {(policy, ratio) for policy in H1_ENTRY_POLICIES for ratio in H1_TP_R_MULTIPLES},
        )
        self.assertFalse(any("MICRO_BW" in value for row in rows for value in row.values()))

        def duplicate_lane(run_path: Path) -> None:
            path = run_path / VIRTUAL_TRIALS_FILE
            columns, rows = read_rows(path)
            source = next(row for row in rows if row["trial_id"] == "trial_structural_tp1")
            rows.append(dict(source, trial_id="duplicate_h1_lane"))
            write_rows(path, columns, rows)
            mutate_row(run_path, RUN_SUMMARY_FILE, lambda row: True, h1_trial_rows="10")

        self.assert_mutation_rejected(duplicate_lane, "exactly eight H1 lane declarations required")

    def test_completed_h1_duration_is_terminal_only(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                h1_structural_lifecycle_seconds=NULL_TOKEN,
            ),
            "completed H1 outcome lacks lifecycle seconds",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                terminal_status="CENSORED_RUN_END",
                h1_structural_lifecycle_seconds="900",
                virtual_binary_eligible="0",
                virtual_binary_target=NULL_TOKEN,
            ),
            "non-completed H1 outcome carries lifecycle seconds",
        )

    def test_parent_age_is_exact_trigger_time_evidence(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                DEEP_PIVOT_PARENT_LINKS_FILE,
                lambda row: row["parent_link_id"] == "link_0",
                m10_parent_age_seconds="901",
            ),
            "m10_parent_age_seconds mismatch",
        )

    def test_same_second_admission_does_not_allow_later_completed_outcomes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                terminal_broker_time="2026.01.12 10:19:00",
                terminal_analysis_time="2026.01.12 10:19:00",
                h1_structural_lifecycle_seconds="840",
            )
            with self.assertRaisesRegex(SchemaValidationError, "completed deep outcome follows parent terminal"):
                validate_run(root, FIXTURE.name)

        def terminate_before_event(run_path: Path) -> None:
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                terminal_broker_time="2026.01.12 10:18:00",
                terminal_analysis_time="2026.01.12 10:18:00",
                h1_structural_lifecycle_seconds="780",
            )

        self.assert_mutation_rejected(
            terminate_before_event,
            "parent link begins after virtual parent terminal",
        )

    def test_same_second_parent_exit_censor_is_accepted(self) -> None:
        def make_same_second_parent_exit(run_path: Path) -> None:
            mutate_row(
                run_path,
                VIRTUAL_OUTCOMES_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                terminal_broker_time="2026.01.12 10:19:00",
                terminal_analysis_time="2026.01.12 10:19:00",
                h1_structural_lifecycle_seconds="840",
            )
            mutate_rows(
                run_path,
                DEEP_VIRTUAL_OUTCOMES_FILE,
                lambda row: row["parent_link_id"] == "link_0",
                terminal_broker_time="2026.01.12 10:19:00",
                terminal_analysis_time="2026.01.12 10:19:00",
                terminal_status="CENSORED_PARENT_EXIT",
                terminal_reason="CENSORED_PARENT_EXIT",
                threshold_price=NULL_TOKEN,
                gap_points=NULL_TOKEN,
                deep_lifecycle_seconds=NULL_TOKEN,
                virtual_nominal_r=NULL_TOKEN,
                virtual_quote_gross_profit=NULL_TOKEN,
                virtual_quote_gross_r=NULL_TOKEN,
                virtual_binary_eligible="0",
                virtual_binary_target=NULL_TOKEN,
                virtual_exclusion_reason="CENSORED_PARENT_EXIT",
            )
            mutate_row(
                run_path,
                RUN_SUMMARY_FILE,
                lambda row: True,
                deep_tp_rows="1",
                deep_sl_rows="1",
                deep_parent_exit_censored_rows="4",
            )

        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            make_same_second_parent_exit(run_path)
            validation = validate_run(root, FIXTURE.name)
            self.assertEqual(validation.deep_outcome_rows, 6)

        def censor_before_event(run_path: Path) -> None:
            make_same_second_parent_exit(run_path)
            mutate_row(
                run_path,
                DEEP_VIRTUAL_OUTCOMES_FILE,
                lambda row: row["parent_link_id"] == "link_0"
                and row["deep_trial_id"] == "deep_trial_s1_r1",
                terminal_broker_time="2026.01.12 10:18:59",
                terminal_analysis_time="2026.01.12 10:18:59",
            )

        self.assert_mutation_rejected(
            censor_before_event,
            "deep outcome terminal precedes event trigger",
        )

    def test_deep_event_must_reference_its_causal_deep_window(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                DEEP_PIVOT_EVENTS_FILE,
                lambda row: True,
                deep_window_id="win_h1_202601121000",
            ),
            "invalid deep event identity",
        )

    def test_deep_m3_feature_formulas_fail_closed(self) -> None:
        cases = (
            (
                {
                    "deep_micro_b_percent_0": "49.0000000000",
                    "deep_micro_b_percent_state_0": "BELOW",
                },
                "B percent shift 0 formula mismatch",
            ),
            (
                {"deep_micro_stochastic_main_line_sma_slope_0": "1.0000000000"},
                "SMA slope mismatch",
            ),
            (
                {"deep_micro_stochastic_main_line_state_0": "ABOVE"},
                "state mismatch",
            ),
        )
        for values, expected_error in cases:
            with self.subTest(values=values):
                self.assert_mutation_rejected(
                    lambda run_path, values=values: mutate_row(
                        run_path,
                        DEEP_PIVOT_EVENTS_FILE,
                        lambda row: True,
                        **values,
                    ),
                    expected_error,
                )

    def test_deep_trial_geometry_and_outcome_arithmetic_fail_closed(self) -> None:
        requested_distance = abs(4053.152 - 4049.480)
        self.assertEqual(
            _normalize_risk_ticks_outward(requested_distance, 0.001),
            3672,
        )
        self.assertEqual(
            _normalize_risk_ticks_outward(requested_distance + 0.000001, 0.001),
            3673,
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                DEEP_VIRTUAL_TRIALS_FILE,
                lambda row: row["tp_r_multiple"] == "2",
                take_profit_price="1.1049000000",
            ),
            "deep trial geometry arithmetic mismatch",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                DEEP_VIRTUAL_OUTCOMES_FILE,
                lambda row: row["parent_link_id"] == "link_0"
                and row["tp_r_multiple"] == "3",
                virtual_nominal_r="2.0000000000",
            ),
            "deep outcome arithmetic mismatch",
        )

    def test_virtual_and_parity_identifiers_match_the_producer_boundary(self) -> None:
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_id"] == "trial_structural_tp1",
                broker_signal_id="broker_sig_s1",
            ),
            "invalid H1 lane identity",
        )
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                VIRTUAL_TRIALS_FILE,
                lambda row: row["trial_role"] == "BROKER_PARITY",
                parity_trial_id="mismatched_parity_id",
            ),
            "parity must shadow structural 1R",
        )

    def test_open_broker_parent_can_end_with_run_censored_deep_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                DEEP_PIVOT_PARENT_LINKS_FILE,
                lambda row: row["parent_link_id"] == "link_1",
                parent_kind="BROKER",
                parent_trial_id="parity_broker_sig_s1",
                parent_broker_signal_id="broker_sig_s1",
                parent_entry_policy="STRUCTURAL",
                parent_tp_r_multiple="1",
                parent_entry_broker_time="2026.01.12 10:05:00",
                m10_parent_age_seconds="840",
            )
            mutate_row(
                run_path,
                DEEP_VIRTUAL_OUTCOMES_FILE,
                lambda row: row["parent_link_id"] == "link_1"
                and row["tp_r_multiple"] == "3",
                terminal_broker_time="2026.01.12 11:00:00",
                terminal_analysis_time="2026.01.12 11:00:00",
                terminal_offset_minutes="0",
                terminal_status="CENSORED_RUN_END",
                terminal_reason="CENSORED_RUN_END",
                virtual_exclusion_reason="CENSORED_RUN_END",
            )
            columns, checks = read_rows(run_path / EXECUTION_CHECKS_FILE)
            check = {column: NULL_TOKEN for column in columns}
            check.update(
                {
                    "schema_version": "13",
                    "run_id": FIXTURE.name,
                    "config_id": "cfg_v13_fixture",
                    "check_id": "check_open_broker_fill",
                    "origin_id": "origin_s1_buy",
                    "broker_signal_id": "broker_sig_s1",
                    "parity_trial_id": "parity_broker_sig_s1",
                    "window_id": "win_h1_202601121000",
                    "broker_time": "2026.01.12 10:05:00",
                    "analysis_time": "2026.01.12 10:05:00",
                    "offset_minutes": "0",
                    "broker_entry_confirmed": "1",
                }
            )
            checks.append(check)
            write_rows(run_path / EXECUTION_CHECKS_FILE, columns, checks)
            mutate_row(
                run_path,
                RUN_SUMMARY_FILE,
                lambda row: True,
                execution_check_rows="1",
                deep_parent_exit_censored_rows="0",
                deep_run_censored_rows="1",
            )
            validation = validate_run(root, FIXTURE.name)
            self.assertEqual(validation.deep_parent_link_rows, 2)

    def test_one_event_has_shared_trials_and_link_scoped_outcomes(self) -> None:
        _, events = read_rows(FIXTURE / DEEP_PIVOT_EVENTS_FILE)
        _, links = read_rows(FIXTURE / DEEP_PIVOT_PARENT_LINKS_FILE)
        _, trials = read_rows(FIXTURE / DEEP_VIRTUAL_TRIALS_FILE)
        _, outcomes = read_rows(FIXTURE / DEEP_VIRTUAL_OUTCOMES_FILE)
        self.assertEqual((len(events), len(links), len(trials), len(outcomes)), (1, 2, 3, 6))
        self.assertEqual(
            {(row["parent_link_id"], row["deep_trial_id"]) for row in outcomes},
            {(link["parent_link_id"], trial["deep_trial_id"]) for link in links for trial in trials},
        )

    def test_deep_censor_is_not_a_binary_loss(self) -> None:
        _, outcomes = read_rows(FIXTURE / DEEP_VIRTUAL_OUTCOMES_FILE)
        censored = next(row for row in outcomes if row["terminal_status"] == "CENSORED_PARENT_EXIT")
        self.assertEqual(censored["virtual_binary_eligible"], "0")
        self.assertEqual(censored["virtual_binary_target"], NULL_TOKEN)
        self.assertEqual(censored["deep_lifecycle_seconds"], NULL_TOKEN)
        self.assert_mutation_rejected(
            lambda run_path: mutate_row(
                run_path,
                DEEP_VIRTUAL_OUTCOMES_FILE,
                lambda row: row["terminal_status"] == "CENSORED_PARENT_EXIT",
                virtual_binary_eligible="1",
                virtual_binary_target="0",
            ),
            "deep binary eligibility/status mismatch",
        )

    def validate_broker_parent_slice(
        self, *, delay_seconds: int = 0, close_time: str = "2026.01.12 10:40:00",
        run_end: bool = False,
    ) -> None:
        tables = {name: read_rows(FIXTURE / name)[1] for name in RUN_FILES}
        link = next(row for row in tables[DEEP_PIVOT_PARENT_LINKS_FILE] if row["parent_link_id"] == "link_1")
        link.update(parent_kind="BROKER", parent_trial_id="parity_broker_sig_s1",
                    parent_broker_signal_id="broker_sig_s1", parent_entry_policy="STRUCTURAL",
                    parent_tp_r_multiple="1", parent_entry_broker_time="2026.01.12 10:05:00",
                    m10_parent_age_seconds="840")
        censored = next(row for row in tables[DEEP_VIRTUAL_OUTCOMES_FILE] if row["terminal_status"] == "CENSORED_PARENT_EXIT")
        observation = datetime.strptime("2026.01.12 10:40:00", "%Y.%m.%d %H:%M:%S") + timedelta(seconds=delay_seconds)
        censored["terminal_broker_time"] = censored["terminal_analysis_time"] = observation.strftime("%Y.%m.%d %H:%M:%S")
        if run_end:
            for column in ("terminal_status", "terminal_reason", "virtual_exclusion_reason"):
                censored[column] = "CENSORED_RUN_END"
        _validate_deep(
            tables, _validate_manifest(tables[RUN_MANIFEST_FILE], FIXTURE.name),
            {row["window_id"]: row for row in tables["pivot_windows.tsv"]},
            {row["origin_id"]: row for row in tables[SIGNAL_ORIGINS_FILE]},
            {row["trial_id"]: row for row in tables[VIRTUAL_TRIALS_FILE]},
            {row["outcome_id"]: row for row in tables[VIRTUAL_OUTCOMES_FILE]},
            {"broker_sig_s1": {"entry_broker_time": "2026.01.12 10:05:00", "close_broker_time": close_time}},
        )

    def test_broker_parent_censor_uses_deal_time_without_latency_tolerance(self) -> None:
        self.validate_broker_parent_slice()
        for delay in (1, 2, 3, 10):
            with self.subTest(delay=delay), self.assertRaisesRegex(SchemaValidationError, "parent-exit censor time mismatch"):
                self.validate_broker_parent_slice(delay_seconds=delay)

    def test_broker_parent_completion_and_run_end_censor_boundaries(self) -> None:
        with self.assertRaisesRegex(SchemaValidationError, "completed deep outcome follows parent terminal"):
            self.validate_broker_parent_slice(close_time="2026.01.12 10:24:59")
        with self.assertRaisesRegex(SchemaValidationError, "run-end censor references completed parent"):
            self.validate_broker_parent_slice(run_end=True)

    def test_direction_is_not_part_of_deep_event_identity(self) -> None:
        def duplicate_opposite_direction(run_path: Path) -> None:
            path = run_path / DEEP_PIVOT_EVENTS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], deep_event_id="opposite_direction", direction="SELL"))
            write_rows(path, columns, rows)
            mutate_row(run_path, RUN_SUMMARY_FILE, lambda row: True, deep_event_rows="2")

        self.assert_mutation_rejected(duplicate_opposite_direction, "duplicate deep event identity")

    def test_capacity_rejection_preserves_required_fanout_without_partial_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root, run_path = self.copy_fixture(temp_dir)
            mutate_row(
                run_path,
                DEEP_PIVOT_EVENTS_FILE,
                lambda row: True,
                admission_status="CAPACITY_REJECTED",
                reserved_link_slots="0",
                reserved_trial_slots="0",
                reserved_outcome_slots="0",
                capacity_rejection_reason="DEEP_FANOUT_CAPACITY_REJECTED",
            )
            for filename in (
                DEEP_PIVOT_PARENT_LINKS_FILE,
                DEEP_VIRTUAL_TRIALS_FILE,
                DEEP_VIRTUAL_OUTCOMES_FILE,
            ):
                columns, _ = read_rows(run_path / filename)
                write_rows(run_path / filename, columns, [])
            mutate_row(
                run_path,
                RUN_SUMMARY_FILE,
                lambda row: True,
                deep_event_admitted_rows="0",
                deep_event_capacity_rejected_rows="1",
                deep_parent_link_rows="0",
                deep_trial_rows="0",
                deep_outcome_rows="0",
                deep_tp_rows="0",
                deep_sl_rows="0",
                deep_parent_exit_censored_rows="0",
            )
            validation = validate_run(root, FIXTURE.name)
            self.assertEqual(validation.deep_event_rows, 1)
            self.assertEqual(validation.deep_parent_link_rows, 0)

            mutate_row(
                run_path,
                DEEP_PIVOT_EVENTS_FILE,
                lambda row: True,
                reserved_link_slots="1",
            )
            with self.assertRaisesRegex(SchemaValidationError, "capacity rejection has partial fan-out"):
                validate_run(root, FIXTURE.name)


class ParentChronologyOperationalTests(unittest.TestCase):
    def make_broker_run(self, directory: Path) -> Path:
        run = directory / FIXTURE.name
        shutil.copytree(FIXTURE, run)
        mutate_row(run, DEEP_PIVOT_PARENT_LINKS_FILE, lambda row: row["parent_link_id"] == "link_1",
                   parent_kind="BROKER", parent_trial_id="parity_broker_sig_s1",
                   parent_broker_signal_id="broker_sig_s1", parent_entry_policy="STRUCTURAL",
                   parent_tp_r_multiple="1", parent_entry_broker_time="2026.01.12 10:05:00",
                   m10_parent_age_seconds="840")
        columns, _ = read_rows(run / "broker_outcomes.tsv")
        _, origins = read_rows(run / SIGNAL_ORIGINS_FILE)
        origin = origins[0]
        broker = {column: NULL_TOKEN for column in columns}
        for column in ("schema_version", "run_id", "config_id", "origin_id", "window_id", "symbol",
                       "macro_timeframe", "deep_timeframe", "micro_timeframe", "active_bar_open_broker_time", "level_id", "direction"):
            broker[column] = origin[column]
        broker.update(broker_outcome_id="broker_close_1", broker_signal_id="broker_sig_s1",
                      parity_trial_id="parity_broker_sig_s1", entry_broker_time="2026.01.12 10:05:00",
                      entry_analysis_time="2026.01.12 10:05:00", entry_offset_minutes="0",
                      close_broker_time="2026.01.12 10:40:00", close_analysis_time="2026.01.12 10:40:00",
                      close_offset_minutes="0", h1_structural_lifecycle_seconds="2100",
                      broker_entry_confirmed="1", broker_close_confirmed="1", close_deal_count="1",
                      request_risk_distance_points="100", request_reward_distance_points="100",
                      request_price_reward_risk_ratio="1", broker_terminal_reason="BROKER_TP",
                      close_reason_consistent="1", broker_binary_eligible="1", broker_binary_target="1")
        write_rows(run / "broker_outcomes.tsv", columns, [broker])
        mutate_row(run, RUN_SUMMARY_FILE, lambda row: True, broker_outcome_rows="1", parity_pair_rows="1")
        return run

    def delay_censor(self, run: Path) -> None:
        mutate_row(run, DEEP_VIRTUAL_OUTCOMES_FILE, lambda row: row["terminal_status"] == "CENSORED_PARENT_EXIT",
                   terminal_broker_time="2026.01.12 10:40:02", terminal_analysis_time="2026.01.12 10:40:02")

    def test_audit_and_recovery_preserve_every_nonclock_fact_and_original_byte(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            run = self.make_broker_run(root)
            validate_run(root, run.name)
            self.assertEqual(audit_run(root, run.name)["status"], "PASS")
            self.delay_censor(run)
            hashes = {name: hashlib.sha256((run / name).read_bytes()).hexdigest() for name in RUN_FILES}
            report = audit_run(root, run.name)
            self.assertEqual({k: v for k, v in report["checks"].items() if v}, {"broker_parent_censor_after_close": 1})
            recovered_root = root / "recovered"
            recovered = recover_run(root, run.name, recovered_root, "recovered_clock")
            target = recovered_root / "recovered_clock"
            self.assertEqual(recovered["corrected_rows"], 1)
            self.assertEqual(recovered["audit_after"]["status"], "PASS")
            validate_run(recovered_root, target.name)
            self.assertEqual(set(p.name for p in target.iterdir()), set(RUN_FILES))
            changed = []
            for filename in RUN_FILES:
                self.assertEqual(hashlib.sha256((run / filename).read_bytes()).hexdigest(), hashes[filename])
                columns, old_rows = read_rows(run / filename)
                _, new_rows = read_rows(target / filename)
                self.assertEqual(len(old_rows), len(new_rows))
                for old, new in zip(old_rows, new_rows):
                    if filename == RUN_MANIFEST_FILE:
                        if old["key"] == "run_id":
                            self.assertEqual(new["value"], target.name)
                            new["value"] = old["value"]
                    else:
                        self.assertEqual(new["run_id"], target.name)
                        new["run_id"] = old["run_id"]
                    changed.extend((filename, c) for c in columns if old[c] != new[c])
            self.assertEqual(changed, [(DEEP_VIRTUAL_OUTCOMES_FILE, "terminal_broker_time"),
                                       (DEEP_VIRTUAL_OUTCOMES_FILE, "terminal_analysis_time")])
            corrections = [json.loads(line) for line in Path(recovered["correction_file"]).read_text().splitlines()]
            self.assertEqual(corrections[0]["observation_clock"][0], "2026.01.12 10:40:02")
            self.assertEqual(corrections[0]["after"][0], "2026.01.12 10:40:00")
            self.assertTrue((recovered_root / "recovered_clock.provenance.json").is_file())
            with self.assertRaises(FileExistsError):
                recover_run(root, run.name, recovered_root, "recovered_clock")

    def test_recovery_refuses_completed_children_after_close_and_broken_references(self) -> None:
        for mutation, key in (
            (lambda run: mutate_row(run, "broker_outcomes.tsv", lambda row: True,
                                   close_broker_time="2026.01.12 10:24:59", close_analysis_time="2026.01.12 10:24:59"), "completed_after_parent"),
            (lambda run: mutate_row(run, DEEP_PIVOT_PARENT_LINKS_FILE, lambda row: row["parent_link_id"] == "link_1",
                                   parent_trial_id="unknown_parent"), "parent_identity"),
        ):
            with self.subTest(check=key), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                run = self.make_broker_run(root)
                self.delay_censor(run)
                mutation(run)
                self.assertGreater(audit_run(root, run.name)["checks"][key], 0)
                with self.assertRaisesRegex(SchemaValidationError, "not eligible"):
                    recover_run(root, run.name, root / "recovered", "bad_recovery")
                self.assertFalse((root / "recovered" / "bad_recovery").exists())

    def test_duplicate_identity_partial_clock_and_recovery_path_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            run = self.make_broker_run(root)
            mutate_row(run, "broker_outcomes.tsv", lambda row: True, close_analysis_time=NULL_TOKEN)
            self.assertEqual(audit_run(root, run.name)["checks"]["broker_outcomes.time_triplet"], 1)
            with self.assertRaises(ValueError):
                recover_run(root, run.name, run / "nested", "new_run")
            columns, rows = read_rows(run / DEEP_VIRTUAL_OUTCOMES_FILE)
            rows[1]["deep_outcome_id"] = rows[0]["deep_outcome_id"]
            write_rows(run / DEEP_VIRTUAL_OUTCOMES_FILE, columns, rows)
            report = audit_run(root, run.name)
            self.assertEqual(report["checks"]["deep_virtual_outcomes.primary_key"], 1)
            self.assertIn("relationship_checks_skipped", report)

    def test_null_parent_role_is_not_a_recoverable_timestamp_error(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            run = self.make_broker_run(root)
            self.delay_censor(run)
            mutate_row(run, VIRTUAL_TRIALS_FILE, lambda row: row["trial_role"] == "BROKER_PARITY", trial_role=NULL_TOKEN)
            report = audit_run(root, run.name)
            self.assertEqual(report["checks"]["virtual_trials.required_identity"], 1)
            with self.assertRaisesRegex(SchemaValidationError, "not eligible"):
                recover_run(root, run.name, root / "recovered", "bad_role")

    def test_confirmed_broker_lifecycle_accepts_zero_serialized_seconds(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            run = self.make_broker_run(root)
            tables = {name: read_rows(run / name)[1] for name in RUN_FILES}
            broker = tables["broker_outcomes.tsv"][0]
            broker.update(close_broker_time=broker["entry_broker_time"],
                          close_analysis_time=broker["entry_analysis_time"],
                          h1_structural_lifecycle_seconds="0")
            def validate_broker() -> None:
                _validate_broker_outcomes(
                    [broker], _validate_manifest(tables[RUN_MANIFEST_FILE], run.name),
                    {row["origin_id"]: row for row in tables[SIGNAL_ORIGINS_FILE]},
                    {row["trial_id"]: row for row in tables[VIRTUAL_TRIALS_FILE]},
                    {row["outcome_id"]: row for row in tables[VIRTUAL_OUTCOMES_FILE]},
                )
            validate_broker()
            broker["h1_structural_lifecycle_seconds"] = "1"
            with self.assertRaisesRegex(SchemaValidationError, "incomplete broker lifecycle"):
                validate_broker()
            broker.update(close_broker_time="2026.01.12 10:04:59",
                          close_analysis_time="2026.01.12 10:04:59", h1_structural_lifecycle_seconds="-1")
            with self.assertRaisesRegex(SchemaValidationError, "incomplete broker lifecycle"):
                validate_broker()


if __name__ == "__main__":
    unittest.main()
