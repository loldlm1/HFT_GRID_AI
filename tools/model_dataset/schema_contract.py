"""Canonical schema, engine descriptors and deterministic MQL/JSON generation."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from types import MappingProxyType

FAMILY = "MQL5_MODEL_FEATURES"
SCHEMA_VERSION = "1"
FEATURE_SET = "macro_micro_standard_v1"
NULL = r"\N"
LEVELS = ("S3", "S2", "S1", "PP", "R1", "R2", "R3")
CLASSIFICATIONS = frozenset({"PROVENANCE", "EXECUTION_FACT", "CAUSAL_FEATURE", "OUTCOME_ONLY"})
KINDS = frozenset({"text", "int", "decimal", "bool", "clock"})
IDENTIFIER = re.compile(r"[a-z][a-z0-9_]*\Z")


@dataclass(frozen=True)
class Field:
    name: str
    type: str
    nullable: bool = False
    classification: str = "PROVENANCE"
    choices: tuple[str, ...] = ()

    def __post_init__(self):
        if not IDENTIFIER.fullmatch(self.name) or self.type not in KINDS or self.classification not in CLASSIFICATIONS:
            raise ValueError("Invalid field descriptor")
        if self.type == "clock" and self.name != "time_msc" and not self.name.endswith("_time_msc"):
            raise ValueError("Clock field requires a _time_msc suffix")
        if len(self.choices) != len(set(self.choices)) or any(not c or any(x in c for x in "\r\n\t|\x00") for c in self.choices):
            raise ValueError("Invalid field choices")


def clock_companions(name: str) -> tuple[str, str, str]:
    if name == "time_msc":
        return "analysis_time_msc", "offset_minutes", "precision"
    prefix = name.removesuffix("_time_msc")
    return f"{prefix}_analysis_time_msc", f"{prefix}_offset_minutes", f"{prefix}_precision"


@dataclass(frozen=True)
class Table:
    name: str
    raw_fields: tuple[Field, ...]
    key: str

    def __post_init__(self):
        if not re.fullmatch(r"[a-z][a-z0-9_]*\.tsv", self.name):
            raise ValueError("Unsafe table name")
        names = [f.name for f in self.fields]
        if len(names) != len(set(names)) or self.key not in names:
            raise ValueError("Duplicate fields or missing table key")

    @property
    def clocks(self) -> tuple[Field, ...]:
        return tuple(f for f in self.raw_fields if f.type == "clock")

    @property
    def fields(self) -> tuple[Field, ...]:
        companions = tuple(
            Field(name, kind, field.nullable, field.classification, ("SECOND", "MILLISECOND") if kind == "text" else ())
            for field in self.clocks
            for name, kind in zip(clock_companions(field.name), ("int", "int", "text"), strict=True)
        )
        return self.raw_fields + companions

    @property
    def columns(self) -> tuple[str, ...]:
        return tuple(f.name for f in self.fields)


@dataclass(frozen=True)
class EngineProfile:
    engine: str
    extension_version: str
    outcome_policy: str
    extensions: tuple[Table, ...]

    def __post_init__(self):
        if not re.fullmatch(r"[A-Z][A-Z0-9_]+", self.engine) or self.extension_version != "1":
            raise ValueError("Invalid engine identity/version")
        names = [t.name for t in (*COMMON_TABLES, *self.extensions)]
        if len(names) != len(set(names)):
            raise ValueError("An extension cannot replace a core table")
        for table in self.extensions:
            if table.key not in {"signal_id", "attempt_id", "snapshot_id", "trial_id"}:
                raise ValueError("Extension must declare a core grain")
            if not {"run_id", table.key} <= set(table.columns):
                raise ValueError("Extension lacks core identity")

    @property
    def tables(self) -> tuple[Table, ...]:
        return COMMON_TABLES + self.extensions

# Frozen ordered schema 1 inventory; see docs/architecture/model-feature-dataset.md.
_SPEC = {
    'run_manifest.tsv': (
        'key:s:P '
        'value:s:P '
    ),
    'macro_windows.tsv': (
        'run_id:s:P '
        'window_id:s:P '
        'open_time_msc:t:P '
        'source_time_msc:t?:P '
        'source_close_time_msc:t?:P '
        'macro_seconds:i:P '
        'source_open:d?:P '
        'source_high:d?:P '
        'source_low:d?:P '
        'source_close:d?:P '
        'valid:b:P '
        'reason:s:P '
        'raw_s3_price:d?:P '
        'raw_s2_price:d?:P '
        'raw_s1_price:d?:P '
        'raw_pp_price:d?:P '
        'raw_r1_price:d?:P '
        'raw_r2_price:d?:P '
        'raw_r3_price:d?:P '
        'trade_s3_price:d?:P '
        'trade_s2_price:d?:P '
        'trade_s1_price:d?:P '
        'trade_pp_price:d?:P '
        'trade_r1_price:d?:P '
        'trade_r2_price:d?:P '
        'trade_r3_price:d?:P '
        'first_observed_time_msc:t?:P '
        'first_observed_bid:d?:P '
        'pp_initial_relation:s?:P '
        'pp_role:s?:P '
        'pp_arm_time_msc:t?:P '
        'pp_arm_bid:d?:P '
        'terminal_time_msc:t?:O '
        'terminal_status:s?:O '
    ),
    'signal_events.tsv': (
        'run_id:s:P '
        'signal_id:s:P '
        'sequence:i:P '
        'symbol:s:P '
        'direction:s:P '
        'signal_time_msc:t:P '
        'source_time_msc:t?:P '
        'macro_window_id:s?:P '
        'bid:d:P '
        'ask:d:P '
        'admission:s:P '
    ),
    'feature_snapshots.tsv': (
        'run_id:s:P '
        'snapshot_id:s:P '
        'signal_id:s:P '
        'sequence:i:P '
        'capture_stage:s:P '
        'observed_time_msc:t:P '
        'macro_window_id:s?:P '
        'bid:d:P '
        'ask:d:P '
        'point:d:P '
        'tick_size:d:P '
        'macro_seconds:i:P '
        'micro_seconds:i:P '
        'complete:b:P '
        'macro_complete:b:P '
        'macro_reason:s:P '
        'macro_stochastic_complete:b:P '
        'macro_percent_b_complete:b:P '
        'macro_atr_complete:b:P '
        'macro_source_0_time_msc:t?:P '
        'macro_source_1_time_msc:t?:P '
        'macro_source_2_time_msc:t?:P '
        'macro_source_3_time_msc:t?:P '
        'macro_source_4_time_msc:t?:P '
        'macro_source_5_time_msc:t?:P '
        'macro_stochastic_k_0:d?:C '
        'macro_stochastic_k_1:d?:C '
        'macro_stochastic_k_2:d?:C '
        'macro_stochastic_k_3:d?:C '
        'macro_stochastic_k_4:d?:C '
        'macro_stochastic_k_5:d?:C '
        'macro_stochastic_d_0:d?:C '
        'macro_stochastic_d_1:d?:C '
        'macro_stochastic_d_2:d?:C '
        'macro_stochastic_d_3:d?:C '
        'macro_stochastic_d_4:d?:C '
        'macro_stochastic_d_5:d?:C '
        'macro_percent_b_0:d?:C '
        'macro_percent_b_1:d?:C '
        'macro_percent_b_2:d?:C '
        'macro_percent_b_3:d?:C '
        'macro_percent_b_4:d?:C '
        'macro_percent_b_5:d?:C '
        'macro_percent_b_sma_5_0:d?:C '
        'macro_percent_b_sma_5_1:d?:C '
        'macro_percent_b_sma_5_2:d?:C '
        'macro_percent_b_sma_5_3:d?:C '
        'macro_percent_b_sma_5_4:d?:C '
        'macro_percent_b_sma_5_5:d?:C '
        'macro_atr_13_0:d?:C '
        'macro_atr_13_1:d?:C '
        'macro_atr_13_2:d?:C '
        'macro_atr_13_3:d?:C '
        'macro_atr_13_4:d?:C '
        'macro_atr_13_5:d?:C '
        'macro_atr_13_sma_5_0:d?:C '
        'macro_atr_13_sma_5_1:d?:C '
        'macro_atr_13_sma_5_2:d?:C '
        'macro_atr_13_sma_5_3:d?:C '
        'macro_atr_13_sma_5_4:d?:C '
        'macro_atr_13_sma_5_5:d?:C '
        'micro_complete:b:P '
        'micro_reason:s:P '
        'micro_stochastic_complete:b:P '
        'micro_percent_b_complete:b:P '
        'micro_atr_complete:b:P '
        'micro_source_0_time_msc:t?:P '
        'micro_source_1_time_msc:t?:P '
        'micro_source_2_time_msc:t?:P '
        'micro_source_3_time_msc:t?:P '
        'micro_source_4_time_msc:t?:P '
        'micro_source_5_time_msc:t?:P '
        'micro_stochastic_k_0:d?:C '
        'micro_stochastic_k_1:d?:C '
        'micro_stochastic_k_2:d?:C '
        'micro_stochastic_k_3:d?:C '
        'micro_stochastic_k_4:d?:C '
        'micro_stochastic_k_5:d?:C '
        'micro_stochastic_d_0:d?:C '
        'micro_stochastic_d_1:d?:C '
        'micro_stochastic_d_2:d?:C '
        'micro_stochastic_d_3:d?:C '
        'micro_stochastic_d_4:d?:C '
        'micro_stochastic_d_5:d?:C '
        'micro_percent_b_0:d?:C '
        'micro_percent_b_1:d?:C '
        'micro_percent_b_2:d?:C '
        'micro_percent_b_3:d?:C '
        'micro_percent_b_4:d?:C '
        'micro_percent_b_5:d?:C '
        'micro_percent_b_sma_5_0:d?:C '
        'micro_percent_b_sma_5_1:d?:C '
        'micro_percent_b_sma_5_2:d?:C '
        'micro_percent_b_sma_5_3:d?:C '
        'micro_percent_b_sma_5_4:d?:C '
        'micro_percent_b_sma_5_5:d?:C '
        'micro_atr_13_0:d?:C '
        'micro_atr_13_1:d?:C '
        'micro_atr_13_2:d?:C '
        'micro_atr_13_3:d?:C '
        'micro_atr_13_4:d?:C '
        'micro_atr_13_5:d?:C '
        'micro_atr_13_sma_5_0:d?:C '
        'micro_atr_13_sma_5_1:d?:C '
        'micro_atr_13_sma_5_2:d?:C '
        'micro_atr_13_sma_5_3:d?:C '
        'micro_atr_13_sma_5_4:d?:C '
        'micro_atr_13_sma_5_5:d?:C '
        'pivot_complete:b:P '
        'signal_zone:s?:C '
        'signal_vs_tested_pivot:s?:C '
        'zone_lower_price:d?:C '
        'zone_upper_price:d?:C '
        'tested_level:s?:C '
        'tested_price:d?:C '
        'tested_role:s?:C '
        'tested_distance_price:d?:C '
        'tested_distance_points:d?:C '
        'tested_age_ms:i?:C '
        'tested_touch_time_msc:t?:P '
        'tested_sequence:i?:P '
        'tested_reclaimed:b?:C '
        'tested_gap_cross:b?:C '
        'pivot_s3_price:d?:P '
        'pivot_s3_touch_time_msc:t?:P '
        'pivot_s3_touch_sequence:i?:P '
        'pivot_s3_role:s?:P '
        'pivot_s3_reclaimed:b:P '
        'pivot_s3_gap_cross:b:P '
        'pivot_s2_price:d?:P '
        'pivot_s2_touch_time_msc:t?:P '
        'pivot_s2_touch_sequence:i?:P '
        'pivot_s2_role:s?:P '
        'pivot_s2_reclaimed:b:P '
        'pivot_s2_gap_cross:b:P '
        'pivot_s1_price:d?:P '
        'pivot_s1_touch_time_msc:t?:P '
        'pivot_s1_touch_sequence:i?:P '
        'pivot_s1_role:s?:P '
        'pivot_s1_reclaimed:b:P '
        'pivot_s1_gap_cross:b:P '
        'pivot_pp_price:d?:P '
        'pivot_pp_touch_time_msc:t?:P '
        'pivot_pp_touch_sequence:i?:P '
        'pivot_pp_role:s?:P '
        'pivot_pp_reclaimed:b:P '
        'pivot_pp_gap_cross:b:P '
        'pivot_r1_price:d?:P '
        'pivot_r1_touch_time_msc:t?:P '
        'pivot_r1_touch_sequence:i?:P '
        'pivot_r1_role:s?:P '
        'pivot_r1_reclaimed:b:P '
        'pivot_r1_gap_cross:b:P '
        'pivot_r2_price:d?:P '
        'pivot_r2_touch_time_msc:t?:P '
        'pivot_r2_touch_sequence:i?:P '
        'pivot_r2_role:s?:P '
        'pivot_r2_reclaimed:b:P '
        'pivot_r2_gap_cross:b:P '
        'pivot_r3_price:d?:P '
        'pivot_r3_touch_time_msc:t?:P '
        'pivot_r3_touch_sequence:i?:P '
        'pivot_r3_role:s?:P '
        'pivot_r3_reclaimed:b:P '
        'pivot_r3_gap_cross:b:P '
        'structure_complete:b:P '
        'structure_reason:s:P '
        'structure_last_closed_time_msc:t?:P '
        'structure_observed_bar_time_msc:t?:P '
        'confirmed_high_kind:s?:C '
        'confirmed_high_class:s?:C '
        'confirmed_high_price:d?:C '
        'confirmed_high_pivot_time_msc:t?:P '
        'confirmed_high_confirmation_time_msc:t?:P '
        'confirmed_low_kind:s?:C '
        'confirmed_low_class:s?:C '
        'confirmed_low_price:d?:C '
        'confirmed_low_pivot_time_msc:t?:P '
        'confirmed_low_confirmation_time_msc:t?:P '
        'confirmed_event_kind:s?:C '
        'confirmed_event_class:s?:C '
        'confirmed_event_price:d?:C '
        'confirmed_event_pivot_time_msc:t?:P '
        'confirmed_event_confirmation_time_msc:t?:P '
        'forming_status:s:C '
        'forming_kind:s?:C '
        'forming_class:s?:C '
        'forming_price:d?:C '
        'forming_pivot_time_msc:t?:P '
    ),
    'entry_attempts.tsv': (
        'run_id:s:P '
        'attempt_id:s:P '
        'signal_id:s:P '
        'snapshot_id:s:P '
        'parent_attempt_id:s?:P '
        'sequence:i:E '
        'entry_type:s:E '
        'direction:s:E '
        'decision_time_msc:t:E '
        'macro_window_id:s?:P '
        'bid:d:E '
        'ask:d:E '
    ),
    'trials.tsv': (
        'run_id:s:P '
        'trial_id:s:P '
        'attempt_id:s:P '
        'role:s:E '
        'entry_policy:s:E '
        'rr:i:E '
        'declared_time_msc:t:E '
        'entry_time_msc:t?:E '
        'deadline_time_msc:t?:E '
        'entry_price:d?:E '
        'sl:d?:E '
        'tp:d?:E '
        'volume:d?:E '
        'eligibility:s:E '
        'reason:s?:E '
        'entry_bid:d?:E '
        'entry_ask:d?:E '
        'entry_quote_side:s?:E '
        'exit_quote_side:s?:E '
        'midpoint_50_price:d?:E '
        'midpoint_touched:b?:E '
        'requested_risk_distance_price:d?:E '
        'requested_risk_distance_points:d?:E '
        'normalized_risk_ticks:i?:E '
        'normalized_risk_distance_price:d?:E '
        'normalized_risk_distance_points:d?:E '
        'geometry_equivalence_id:s?:P '
        'spread_points:d?:E '
        'point_size:d?:E '
        'trade_tick_size:d?:E '
        'stops_level_points:d?:E '
        'freeze_level_points:d?:E '
        'minimum_risk_distance_points:d?:E '
        'distance_eligible:b?:E '
        'lot_mode:s?:E '
        'lot_strategy_size:d?:E '
        'reference_balance:d?:E '
        'account_currency:s?:E '
        'risk_budget_amount:d?:E '
        'requested_volume:d?:E '
        'virtual_expected_stop_loss:d?:E '
        'virtual_expected_take_profit:d?:E '
        'virtual_expected_reward_risk_ratio:d?:E '
        'virtual_money_plan_complete:b?:E '
        'origin_window_active_at_entry:b?:E '
    ),
    'execution_checks.tsv': (
        'run_id:s:P '
        'check_id:s:P '
        'attempt_id:s:P '
        'action:s:E '
        'time_msc:t:E '
        'sequence:i:E '
        'allowed:b:E '
        'reason:s:E '
        'bid:d?:E '
        'ask:d?:E '
        'volume:d?:E '
        'entry_price:d?:E '
        'sl:d?:E '
        'tp:d?:E '
        'margin:d?:E '
        'stop_profit:d?:E '
        'check_retcode:i?:E '
        'send_retcode:i?:E '
        'order_ticket:i?:E '
        'deal_ticket:i?:E '
        'position_id:i?:P '
        'account_margin_mode:i?:E '
        'account_margin_mode_supported:b?:E '
        'symbol_trade_mode:i?:E '
        'symbol_trade_mode_allowed:b?:E '
        'market_session_open:b?:E '
        'account_trade_allowed:b?:E '
        'account_expert_trade_allowed:b?:E '
        'terminal_trade_allowed:b?:E '
        'mql_trade_allowed:b?:E '
        'spread_points:d?:E '
        'point_size:d?:E '
        'trade_tick_size:d?:E '
        'stops_distance_points:d?:E '
        'freeze_distance_points:d?:E '
        'risk_distance_points:d?:E '
        'reward_distance_points:d?:E '
        'risk_budget_amount:d?:E '
        'requested_volume:d?:E '
        'volume_min:d?:E '
        'volume_max:d?:E '
        'volume_step:d?:E '
        'volume_valid:b?:E '
        'fok_supported:b?:E '
        'fill_policy:s?:E '
        'quote_expected_take_profit:d?:E '
        'quote_expected_reward_risk_ratio:d?:E '
        'risk_budget_utilization_ratio:d?:E '
        'account_balance:d?:E '
        'free_margin:d?:E '
        'margin_valid:b?:E '
        'geometry_valid:b?:E '
        'stop_distance_valid:b?:E '
        'freeze_distance_valid:b?:E '
        'order_check_performed:b?:E '
        'order_check_allowed:b?:E '
        'order_check_comment:s?:E '
        'block_source:s?:E '
        'send_performed:b?:E '
        'send_succeeded:b?:E '
        'trade_action:s?:E '
        'send_comment:s?:E '
        'position_ticket:i?:E '
        'broker_entry_confirmed:b?:E '
        'broker_close_confirmed:b?:E '
        'broker_entry_price:d?:E '
        'broker_volume:d?:E '
        'broker_stop_loss:d?:E '
        'broker_take_profit:d?:E '
        'close_price:d?:E '
        'closed_volume:d?:E '
        'terminal_reason:s?:E '
        'protection_modified:b?:E '
    ),
    'outcomes.tsv': (
        'run_id:s:P '
        'trial_id:s:P '
        'attempt_id:s:P '
        'role:s:O '
        'rr:i:O '
        'status:s:O '
        'broker_reason:s?:O '
        'entry_time_msc:t?:O '
        'entry_macro_open_time_msc:t?:O '
        'deadline_time_msc:t?:O '
        'exit_time_msc:t?:O '
        'observed_time_msc:t:O '
        'entry_price:d?:O '
        'exit_price:d?:O '
        'sl:d?:O '
        'tp:d?:O '
        'volume:d?:O '
        'gross_profit:d?:O '
        'costs:d?:O '
        'net_profit:d?:O '
        'gross_r:d?:O '
        'binary_label:i?:O '
        'binary_eligible:b:O '
        'exclusion_reason:s?:O '
        'position_id:i?:P '
        'fill_deviation_points:d?:O '
        'duration_ms:i?:O '
        'threshold_price:d?:O '
        'observed_exit_bid:d?:O '
        'observed_exit_ask:d?:O '
        'observed_exit_price:d?:O '
        'exit_quote_side:s?:O '
        'gap_points:d?:O '
        'nominal_r:d?:O '
        'first_touch_consistent:b?:O '
        'order_ticket:i?:O '
        'entry_deal_ticket:i?:O '
        'last_close_deal_ticket:i?:O '
        'close_deal_count:i?:O '
        'position_ticket:i?:O '
        'submitted_request_price:d?:O '
        'broker_closed_volume:d?:O '
        'request_risk_distance_points:d?:O '
        'request_reward_distance_points:d?:O '
        'request_price_reward_risk_ratio:d?:O '
        'risk_budget_amount:d?:O '
        'quote_expected_stop_loss:d?:O '
        'quote_expected_take_profit:d?:O '
        'quote_expected_reward_risk_ratio:d?:O '
        'risk_budget_utilization_ratio:d?:O '
        'exit_slippage_points:d?:O '
        'broker_commission:d?:O '
        'broker_swap:d?:O '
        'broker_fee:d?:O '
        'broker_gross_budget_r:d?:O '
        'broker_net_budget_r:d?:O '
        'broker_net_execution_r:d?:O '
        'close_reason_consistent:b?:O '
        'broker_entry_confirmed:b?:O '
        'broker_close_confirmed:b?:O '
    ),
    'run_summary.tsv': (
        'key:s:P '
        'value:s:P '
    ),
    'pivot_origins.tsv': (
        'run_id:s:P '
        'signal_id:s:P '
        'broker_signal_id:s?:P '
        'level_id:s:P '
        'pivot_raw_price:d:C '
        'pivot_trade_price:d:C '
        'next_outward_pivot_price:d:C '
        'midpoint_50_price:d:C '
        'structural_entry_price:d?:C '
        'structural_sl_price:d?:C '
        'structural_take_profit:d?:P '
        'stops_level_points:d:P '
        'freeze_level_points:d:P '
        'identity_consumed:b:P '
        'h1_lanes_declared:b:P '
        'broker_attempt_status:s:O '
        'origin_terminal_status:s:O '
    ),
    'candle_signals.tsv': (
        'run_id:s:P '
        'signal_id:s:P '
        'pattern:s:C '
        'pattern_direction:s:C '
        'previous_open:d:C '
        'previous_high:d:C '
        'previous_low:d:C '
        'previous_close:d:C '
        'pattern_open:d:C '
        'pattern_high:d:C '
        'pattern_low:d:C '
        'pattern_close:d:C '
    ),
    'candle_attempts.tsv': (
        'run_id:s:P '
        'attempt_id:s:P '
        'pattern:s:E '
        'category:s:E '
        'generation:i:E '
        'atr_0:d?:E '
        'atr_1:d?:E '
        'atr_source_time_msc:t?:E '
        'atr_shift:i:E '
        'atr_multiplier:d:E '
        'requested_volume:d?:E '
        'entry_interval:s?:E '
        'context_distance_points:d?:E '
        'reentry_cause:s?:E '
        'expiry_policy:s:E '
    ),
}

_KEYS = ("key", "window_id", "signal_id", "snapshot_id", "attempt_id", "trial_id",
         "check_id", "trial_id", "key", "signal_id", "signal_id", "attempt_id")

CHOICES = {
    "direction": ("BUY", "SELL"),
    "role": ("BROKER", "VIRTUAL", "PARITY"),
    "capture_stage": ("CANDLE_DECISION", "PIVOT_ORIGIN"),
    "entry_type": ("ORIGINAL", "REENTRY", "PIVOT_ORIGIN"),
    "entry_policy": ("ORIGINAL", "REENTRY", "STRUCTURAL", "MIDPOINT_50"),
    "eligibility": ("ACCEPTED", "REJECTED", "ELIGIBLE", "NOT_TRIGGERED", "CAPACITY_REJECTED", "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY", "INELIGIBLE_MONEY_PLAN"),
    "status": ("TP_FIRST", "SL_FIRST", "TIME_EXIT", "OTHER_CLOSE", "CENSORED_RUN_END", "REJECTED", "NOT_TRIGGERED", "CAPACITY_REJECTED", "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY", "INELIGIBLE_MONEY_PLAN"),
    "admission": ("DISCOVERED", "CONSUMED", "CAPACITY_REJECTED"),
    "pattern": ("HARAMI", "ENGULFING"),
    "pattern_direction": ("BULLISH", "BEARISH"),
    "category": ("ALIGNED", "OPPOSED"),
    "level_id": LEVELS,
    "tested_level": LEVELS,
    "forming_status": ("FORMING", "INITIAL", "UNAVAILABLE"),
    "signal_zone": ("BELOW_S3", "AT_S3", "S3_TO_S2", "AT_S2", "S2_TO_S1", "AT_S1", "S1_TO_PP", "AT_PP", "PP_TO_R1", "AT_R1", "R1_TO_R2", "AT_R2", "R2_TO_R3", "AT_R3", "ABOVE_R3"),
    "signal_vs_tested_pivot": ("UNTESTED", "ABOVE_SUPPORT", "AT_SUPPORT", "BELOW_SUPPORT", "ABOVE_RESISTANCE", "AT_RESISTANCE", "BELOW_RESISTANCE"),
    "tested_role": ("SUPPORT", "RESISTANCE"),
}
CHOICES.update({f"pivot_{level.lower()}_role": ("SUPPORT", "RESISTANCE") for level in LEVELS})
CHOICES.update({f"{prefix}_kind": ("HIGH", "LOW") for prefix in ("confirmed_high", "confirmed_low", "confirmed_event", "forming")})
CHOICES.update({f"{prefix}_class": ("HIGH", "LOW", "HH", "LH", "HL", "LL", "EQ") for prefix in ("confirmed_high", "confirmed_low", "confirmed_event", "forming")})


def _parse_fields(spec: str) -> tuple[Field, ...]:
    kinds = dict(s="text", i="int", d="decimal", b="bool", t="clock")
    classes = dict(P="PROVENANCE", E="EXECUTION_FACT", C="CAUSAL_FEATURE", O="OUTCOME_ONLY")
    return tuple(Field(name, kinds[kind.rstrip("?")], kind.endswith("?"), classes[group], CHOICES.get(name, ()))
                 for name, kind, group in (token.split(":") for token in spec.split()))


TABLES = tuple(Table(name, _parse_fields(spec), key) for (name, spec), key in zip(_SPEC.items(), _KEYS, strict=True))
COMMON_TABLES = TABLES[:9]
TABLE_BY_NAME = MappingProxyType({table.name: table for table in TABLES})
PROFILES = MappingProxyType({
    "PIVOT_MACRO_V1": EngineProfile("PIVOT_MACRO_V1", "1", "PIVOT_MACRO_OUTCOME_V1", (TABLES[9],)),
    "CANDLE_PATTERN_ATR_V2": EngineProfile("CANDLE_PATTERN_ATR_V2", "1", "CANDLE_ATR_OUTCOME_V1", TABLES[10:]),
})
MANIFEST_KEYS = tuple("""
dataset_family schema_version engine feature_set extension_version outcome_policy
run_id config_id producer_version compiler_build symbol broker feed canonical_symbol
mapping_status point digits tick_size volume_min volume_max volume_step contract_size
calculation_mode chart_mode base_currency profit_currency margin_currency account_currency
macro_seconds micro_seconds structure_seconds bands_period bands_shift bands_deviation
bands_price stochastic_k stochastic_d stochastic_slowing stochastic_method stochastic_price
atr_period atr_multiplier average_period feature_shifts warmup_limit catchup_limit
structure_policy broker_session broker_time_basis analysis_clock_policy lot_type lot_size
reference_balance broker_cap virtual_cap protection expiry reentry ratios
""".split())
FIXED_MANIFEST = MappingProxyType(dict(
    dataset_family=FAMILY, schema_version=SCHEMA_VERSION, feature_set=FEATURE_SET,
    extension_version="1", producer_version="2.00", structure_seconds="60",
    bands_period="21", bands_shift="0", bands_deviation="2", bands_price="PRICE_WEIGHTED",
    stochastic_k="5", stochastic_d="3", stochastic_slowing="3", stochastic_method="MODE_SMA",
    stochastic_price="STO_CLOSECLOSE", atr_period="13", atr_multiplier="1", average_period="5",
    feature_shifts="6", warmup_limit="4096", catchup_limit="256",
    structure_policy="STOCHASTIC_CLOSE_M1_V1", reference_balance="1000000", broker_cap="2048",
    protection="FIXED_SUBMITTED",
))
SUMMARY_KEYS = tuple("""
export_status completion_status failure broker_peak virtual_peak handle_peak buffer_peak
feature_gap_count warmup_count warmup_first_time_msc warmup_last_time_msc
warmup_fingerprint warmup_status first_time_msc last_time_msc
""".split())
SUMMARY_CLOCKS = ("warmup_first_time_msc", "warmup_last_time_msc", "first_time_msc", "last_time_msc")
SUMMARY_KEYS += tuple(name for clock in SUMMARY_CLOCKS for name in clock_companions(clock))


def contract() -> dict:
    return {
        "dataset_family": FAMILY, "schema_version": SCHEMA_VERSION, "feature_set": FEATURE_SET,
        "manifest_keys": MANIFEST_KEYS, "fixed_manifest": dict(FIXED_MANIFEST), "summary_keys": SUMMARY_KEYS,
        "profiles": {name: {"extension_version": p.extension_version, "outcome_policy": p.outcome_policy,
                             "files": [t.name for t in p.tables]} for name, p in PROFILES.items()},
        "tables": {t.name: {"key": t.key, "fields": [asdict(f) for f in t.fields]} for t in TABLES},
    }


def mql_header() -> str:
    lines = ["// Generated by tools.model_dataset.schema_contract; do not edit.",
             "#ifndef MODEL_SCHEMA_MQH", "#define MODEL_SCHEMA_MQH", "",
             "enum ModelFileIds {", ",\n".join(f"  MODEL_{t.name.removesuffix('.tsv').upper()} = {i}"
                                            for i, t in enumerate(TABLES)),
             f",  MODEL_FILE_COUNT = {len(TABLES)}", "};", ""]
    def emit(name, kind, values):
        lines.extend([f"{kind} {name}(const int file)", "{", "  switch(file)", "  {"])
        for i, value in enumerate(values):
            literal = json.dumps(value, ensure_ascii=True) if isinstance(value, str) else str(value)
            lines.append(f"    case {i}: return {literal};")
        lines.extend(["  }", '  return "";' if kind == "string" else "  return 0;", "}", ""])
    emit("ModelFileName", "string", [t.name for t in TABLES])
    emit("ModelHeader", "string", ["\t".join(t.columns) for t in TABLES])
    emit("ModelRawColumnCount", "int", [len(t.raw_fields) for t in TABLES])
    emit("ModelTypes", "string", ["".join({"text":"s", "int":"i", "decimal":"d", "bool":"b", "clock":"t"}[f.type] for f in t.fields) for t in TABLES])
    emit("ModelNullability", "string", ["".join("1" if f.nullable else "0" for f in t.fields) for t in TABLES])
    lines.extend(["string ModelAllowedValues(const int file, const int column)", "{", "  switch(file)", "  {"])
    for i, table in enumerate(TABLES):
        lines.extend([f"    case {i}:", "      switch(column)", "      {"])
        for j, field in enumerate(table.fields):
            if field.choices:
                lines.append(f'        case {j}: return "|{"|".join(field.choices)}|";')
        lines.extend(["      }", "      break;"])
    lines.extend(["  }", '  return "";', "}", ""])
    lines.extend(["bool ModelEngineFile(const int file, const string engine)", "{"])
    for name, profile in PROFILES.items():
        indices = [TABLES.index(table) for table in profile.tables]
        condition = " || ".join(f"file == {i}" for i in indices)
        lines.extend([f'  if(engine == "{name}")', f"    return {condition};"])
    lines.extend(["  return false;", "}", "", "#endif", ""])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-mql-header", type=Path)
    parser.add_argument("--check-mql-header", type=Path)
    parser.add_argument("--write-json", type=Path)
    args = parser.parse_args()
    if not any(vars(args).values()):
        parser.error("Select at least one output/check")
    for path, content in ((args.write_mql_header, mql_header()),
                          (args.write_json, json.dumps(contract(), indent=2) + "\n")):
        if path:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="ascii")
    if args.check_mql_header and args.check_mql_header.read_bytes() != mql_header().encode("ascii"):
        parser.exit(1, "Generated MQL header differs from canonical contract\n")


if __name__ == "__main__":
    main()
