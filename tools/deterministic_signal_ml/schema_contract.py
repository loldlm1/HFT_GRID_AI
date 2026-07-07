"""Schema contract for deterministic signal feature exports."""

from __future__ import annotations

from dataclasses import dataclass


SUPPORTED_SCHEMA_VERSION = 4
NULL_TOKEN = r"\N"

RUN_MANIFEST_FILE = "run_manifest.tsv"
SIGNAL_FEATURES_FILE = "signal_features.tsv"
SIGNAL_OUTCOMES_FILE = "signal_outcomes.tsv"
RUN_SUMMARY_FILE = "run_summary.tsv"
PHASE1_FILES = (
    RUN_MANIFEST_FILE,
    SIGNAL_FEATURES_FILE,
    SIGNAL_OUTCOMES_FILE,
    RUN_SUMMARY_FILE,
)

MANIFEST_COLUMNS = ("schema_version", "key", "value")

SUMMARY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "started_at",
    "finished_at",
    "feature_rows",
    "outcome_rows",
    "feature_invalid_rows",
    "outcome_invalid_rows",
    "export_status",
)

FEATURE_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "symbol",
    "strategy_label",
    "direction",
    "entry_time",
    "source_time",
    "structure_0",
    "structure_1",
    "structure_2",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
)

OUTCOME_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
    "terminal_time",
    "terminal_reason",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
)

PATH_RATIO_OUTCOME_COLUMNS = (
    "hit_1r_before_sl",
    "hit_1_5r_before_sl",
    "hit_2r_before_sl",
    "hit_3r_before_sl",
    "max_favorable_r",
    "max_adverse_r",
    "bars_to_1r",
    "bars_to_1_5r",
    "bars_to_2r",
    "bars_to_3r",
    "bars_to_sl",
    "path_horizon_bars",
    "path_status",
)

OUTCOME_COLUMNS_WITH_PATH = OUTCOME_COLUMNS + PATH_RATIO_OUTCOME_COLUMNS

IDENTITY_COLUMNS = (
    "schema_version",
    "run_id",
    "config_id",
    "signal_id",
    "source_key",
    "source_attempt_index",
)

MODEL_FEATURE_COLUMNS = (
    "strategy_label",
    "direction",
    "structure_0",
    "structure_1",
    "structure_2",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
)

TARGET_COLUMNS = (
    "target_is_win",
    "target_profit_r",
    "target_terminal_reason",
)

PATH_RATIO_TARGET_FAMILIES = (
    "1r",
    "1_5r",
    "2r",
    "3r",
    "expected_r",
)

AUDIT_COLUMNS = (
    "symbol",
    "entry_time",
    "source_time",
    "terminal_time",
    "entry_price",
    "close_price",
    "net_profit",
    "duration_seconds",
    "duration_m1_bars",
)

NUMERIC_COLUMNS = (
    "schema_version",
    "source_attempt_index",
    "macro_h1_slope",
    "macro_h4_slope",
    "macro_d1_slope",
    "profit_r",
    "duration_seconds",
    "duration_m1_bars",
    "entry_price",
    "close_price",
    "net_profit",
    *PATH_RATIO_OUTCOME_COLUMNS,
)

CATEGORICAL_COLUMNS = (
    "strategy_label",
    "direction",
    "structure_0",
    "structure_1",
    "structure_2",
    "fib_sl_band",
    "fib_entry_band",
    "high_chain_profile",
    "low_chain_profile",
    "previous_candle_profile",
    "entry_session_bucket",
    "entry_weekday",
    "terminal_reason",
)


@dataclass(frozen=True)
class DatasetColumnGroups:
    feature_columns: tuple[str, ...] = MODEL_FEATURE_COLUMNS
    target_columns: tuple[str, ...] = TARGET_COLUMNS
    identity_columns: tuple[str, ...] = IDENTITY_COLUMNS
    audit_columns: tuple[str, ...] = AUDIT_COLUMNS


def expected_columns_for(filename: str) -> tuple[str, ...]:
    """Return the expected TSV header for a Phase 1 export file."""
    if filename == RUN_MANIFEST_FILE:
        return MANIFEST_COLUMNS
    if filename == SIGNAL_FEATURES_FILE:
        return FEATURE_COLUMNS
    if filename == SIGNAL_OUTCOMES_FILE:
        return OUTCOME_COLUMNS
    if filename == RUN_SUMMARY_FILE:
        return SUMMARY_COLUMNS
    raise ValueError(f"Unknown Phase 1 file: {filename}")
