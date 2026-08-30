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
    COLUMN_TYPE_BY_NAME,
    COLUMN_TYPE_REGISTRY_SHA256,
    DEEP_MICRO_FEATURE_COLUMNS,
    DEEP_PIVOT_EVENTS_FILE,
    DEEP_PIVOT_PARENT_LINKS_FILE,
    DEEP_TP_R_MULTIPLES,
    DEEP_VIRTUAL_OUTCOMES_FILE,
    DEEP_VIRTUAL_TRIALS_FILE,
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
    expected_columns_for,
    validate_run,
)

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

    def test_direction_is_not_part_of_deep_event_identity(self) -> None:
        def duplicate_opposite_direction(run_path: Path) -> None:
            path = run_path / DEEP_PIVOT_EVENTS_FILE
            columns, rows = read_rows(path)
            rows.append(dict(rows[0], deep_event_id="opposite_direction", direction="SELL"))
            write_rows(path, columns, rows)
            mutate_row(run_path, RUN_SUMMARY_FILE, lambda row: True, deep_event_rows="2")

        self.assert_mutation_rejected(duplicate_opposite_direction, "duplicate deep event identity")


if __name__ == "__main__":
    unittest.main()
