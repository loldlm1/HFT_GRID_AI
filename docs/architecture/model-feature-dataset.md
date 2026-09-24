# Shared Model Feature Dataset

This is the versioned producer contract for the
[implementation plan](../../mql5-model-feature-framework-plan.md).
The [project index](../README.md) owns implementation and acceptance status.
Separate Pivot and Candle EAs retain their trading rules and publish immutable
facts through shared data services. Feature availability never controls orders.

## Identities And Ownership

- Family: `MQL5_MODEL_FEATURES`; core schema: `1`.
- Base features: `macro_micro_standard_v1`; extension schema: `1`.
- Engines: `PIVOT_MACRO_V1`, `CANDLE_PATTERN_ATR_V2`; EA versions: `2.00`.
- Storage: `Common/Files/MQL5ModelDatasetV1/runs/<run_id>/`.
- Default roles: Macro H1 and Micro M3, supported native periods with
  `Micro < Macro`. Fixed M1 structure is a separate declared feature source.
- Engine descriptors register exact files, types, extension fields and outcome
  policy. A new engine supplies an adapter and fixtures; it reuses the base
  providers, serializer, clocks and reader. No runtime strategy loader is needed.
- Shared includes accept explicit configuration and observed facts. They cannot
  import engine inputs, lifecycle state or order authorization code.
- New ownership namespaces never adopt positions from previous engine versions.
  Candle execution ATR ownership is independent of optional research indicators.

## Wire Rules

TSV uses UTF-8, a single exact header, CRLF producer records, no quoted cells,
no embedded tab/newline/NUL, and the literal `\N` for null. Decimal values are
finite runtime doubles serialized with 17 significant digits, parsed from their
original tokens as Decimal. Boolean tokens are `0` and `1`; integers use base 10.
Zero is never a missing-value marker. Names ending `_id` are opaque strings unless
explicitly identified as native integer tickets. No global decimal rounding is
applied to prices. Invalid doubles, infinities and native sentinels are rejected.

Each table below lists its ordered raw columns. A field of type `clock` expands
to an integer raw `*_time_msc` column in place. After all raw columns, append,
in the order those clocks occur, its corresponding `*_analysis_time_msc`,
`*_offset_minutes`, and `*_precision`. Precision is `MILLISECOND` or `SECOND`;
bar times and original second-only facts use SECOND even though the unit is ms.
The null clock requires all four cells null. Present clocks must have a valid
analysis clock, offset and precision. Raw clocks own causality and durations.

Field classifications are exactly one of `CAUSAL_FEATURE`, `EXECUTION_FACT`,
`OUTCOME_ONLY`, or `PROVENANCE`. Outcomes and completed durations never enter a
causal feature registry. Identity/time/provenance fields remain auditable without
becoming fitted model inputs. Trial ratios and parity rows cannot multiply the
count of independent signal observations.

## Common Tables

All engines require nine common tables, including empty tables with headers.
The core uses common names for identical facts and nullable audit fields for
facts an engine does not observe. Absence does not assert a successful check.

| File | Primary identity | Meaning |
| --- | --- | --- |
| `run_manifest.tsv` | `key` | Frozen descriptor/configuration/instrument facts |
| `macro_windows.tsv` | `window_id` | Native Macro window and previous completed source candle |
| `signal_events.tsv` | `signal_id` | Engine discovery, observed quote and causal clocks |
| `feature_snapshots.tsv` | `snapshot_id` | Immutable declared capture, shared features and source identities |
| `entry_attempts.tsv` | `attempt_id` | Direction/entry decision and parent/root/snapshot links |
| `trials.tsv` | `trial_id` | Broker, virtual or parity geometry and eligibility |
| `execution_checks.tsv` | `check_id` | Actual request/check/reconciliation evidence |
| `outcomes.tsv` | `trial_id` | One terminal result, cost facts and binary eligibility |
| `run_summary.tsv` | `key` | Successful or failed seal, exact counts and resource evidence |

All event tables begin with `run_id`. Foreign keys are run-local; cross-run
references fail. Every trial links to an attempt; attempts link to signals and
their capture snapshots. A snapshot may be shared only when its stage, observed
sequence, quote and all source identities agree. Tables can be emitted in
different causal phases; the reader validates joins independently of file order.

### Manifest And Seal

Manifest and summary use `key,value` columns. Required manifest facts include
family/core/engine/feature/extension/outcome versions, run/configuration identity,
EA version, compiler build, Macro/Micro seconds, fixed indicator parameters,
warmup/catch-up policy, source symbol, broker/feed identity, instrument mapping
status and specification, session/clock policy, and engine execution constants.
Required manifest keys (no duplicate or undeclared keys) are `dataset_family`,
`schema_version`, `engine`, `feature_set`, `extension_version`, `outcome_policy`,
`run_id`, `config_id`, `producer_version`, `compiler_build`, `symbol`,
`broker`, `feed`, `canonical_symbol`, `mapping_status`, `point`, `digits`,
`tick_size`, `volume_min`, `volume_max`, `volume_step`, `contract_size`,
`calculation_mode`, `chart_mode`, `base_currency`, `profit_currency`,
`margin_currency`, `account_currency`, `macro_seconds`, `micro_seconds`,
`structure_seconds`, `bands_period`, `bands_shift`, `bands_deviation`,
`bands_price`, `stochastic_k`, `stochastic_d`, `stochastic_slowing`,
`stochastic_method`, `stochastic_price`, `atr_period`, `atr_multiplier`,
`average_period`, `feature_shifts`, `warmup_limit`, `catchup_limit`,
`structure_policy`, `broker_session`, `broker_time_basis`,
`analysis_clock_policy`, `lot_type`, `lot_size`, `reference_balance`,
`broker_cap`, `virtual_cap`, `protection`, `expiry`, `reentry`, and `ratios`.
An unknown canonical symbol is the explicit value UNMAPPED, not an inferred name.
Native broker/feed strings must not include account identifiers.

Outcome policy is `PIVOT_MACRO_OUTCOME_V1` or `CANDLE_ATR_OUTCOME_V1` respectively.
Structure policy is `STOCHASTIC_CLOSE_M1_V1` with 4096/256 warmup/catch-up bounds.
Producer measurements and raw source receipts identify available precision;
unknown source provenance is recorded, never silently treated as verified Exness.

Configuration signatures include all effective feature/engine/clock/instrument
inputs. A symbol suffix alone never establishes feed or canonical equivalence.

Instrument facts include point, digits, trade tick size, volume min/max/step,
contract size, calculation/chart modes and base/profit/margin/account currencies.
Bind verified source/specification sidecars and source/include/EX5 hashes in an
immutable external receipt. Do not put account numbers or credentials in exports.
Do not stamp an uncommitted build with an earlier commit or modify a sealed run
after committing its source. The later receipt associates the exact source
digest, real commit, binary and run checksums without altering source data.

Run IDs contain 1-64 ASCII letters/digits/underscore/dash/dot, begin without a dot,
and contain no `..`. Existing nonempty directories are refused. Exact file sets,
headers, scalar types, row counts and referenced identities are strict.
Unknown versions/columns/extensions and unsealed or failed runs are rejected.
Summary includes `export_status`, `completion_status`, failure reason, per-file
counts, feature-gap counts, warmup source bounds/count/fingerprint and state peaks.
The exact summary keys are `export_status`, `completion_status`, `failure`,
`broker_peak`, `virtual_peak`, `handle_peak`, `buffer_peak`, `feature_gap_count`,
`warmup_count`, `warmup_first_time_msc`, `warmup_last_time_msc`,
`warmup_fingerprint`, `warmup_status`, `first_time_msc`, `last_time_msc`, clock
companions for the four clock keys, and `rows_<filename>` for each active
non-summary table. KV metadata uses `NONE` for absent warmup bounds and all their
companions; row-level nullable fields use `\N`. The warmup's last source bar must
precede the first observed run tick. Precision and clock arithmetic apply to these
metadata clocks too. Warmup states are COMPLETE, TRUNCATED, PARTIAL or UNAVAILABLE.
Common enums and each field's classification/nullability are included in the
generated JSON contract. Virtual eligibility uses ELIGIBLE, NOT_TRIGGERED,
CAPACITY_REJECTED or the named INELIGIBLE reason; broker admission uses
ACCEPTED/REJECTED. Terminal status remains separate from admission.
Successful runs have an OK/NATURAL seal; a completed run may contain explicitly
censored terminal trials. SHA-256 source hashes are recorded by the reader;
files changed during validation invalidate its result.

Missing optional features mark the affected family incomplete. Fatal persistence
or referential errors latch the first diagnostic, seal FAILED/CENSORED when
writable and stop only the owned tester. The diagnostic survives research cleanup.
Live broker state stays owned by the engine. A changed instrument specification
invalidates research and requires a new run without becoming an order predicate.

`gross_r` consistently measures signed price movement divided by actual-entry
price risk. Legacy Pivot monetary R remains reproducible from retained raw facts:
`gross_profit / abs(trials.virtual_expected_stop_loss)` for virtual/parity rows,
and `gross_profit / quote_expected_stop_loss` for broker rows. Those monetary
ratios can differ from price R because native profit calculations round money.
They are derived outcomes, not interchangeable feature inputs. Reproducing the
legacy token uses binary64 division; new decimal analysis may keep more precision.
Pivot origin terminal `WINDOW_EXPIRED` maps to `EXPIRED`; identity and lifecycle
boundaries remain unchanged. Immediate ineligible/censor observations now retain
the actual millisecond clock instead of the old synthetic minimum plus one second.

### Ordered Field Specification

The exact ordered field inventory and legacy mapping below are frozen with
Sprint 1. Type suffixes are `s` text, `i` integer, `d` decimal, `b` boolean, `t`
clock; `?` permits null. Clock companions are generated by the wire rule above.
The generated Python/MQL/JSON contract must agree with this inventory.

<!-- ordered-contract:start -->

#### run_manifest.tsv

```text
key:s [PROVENANCE]
value:s [PROVENANCE]
```

#### macro_windows.tsv

```text
run_id:s [PROVENANCE]
window_id:s [PROVENANCE]
open_time_msc:t [PROVENANCE]
source_time_msc:t? [PROVENANCE]
source_close_time_msc:t? [PROVENANCE]
macro_seconds:i [PROVENANCE]
source_open:d? [PROVENANCE]
source_high:d? [PROVENANCE]
source_low:d? [PROVENANCE]
source_close:d? [PROVENANCE]
valid:b [PROVENANCE]
reason:s [PROVENANCE]
raw_s3_price:d? [PROVENANCE]
raw_s2_price:d? [PROVENANCE]
raw_s1_price:d? [PROVENANCE]
raw_pp_price:d? [PROVENANCE]
raw_r1_price:d? [PROVENANCE]
raw_r2_price:d? [PROVENANCE]
raw_r3_price:d? [PROVENANCE]
trade_s3_price:d? [PROVENANCE]
trade_s2_price:d? [PROVENANCE]
trade_s1_price:d? [PROVENANCE]
trade_pp_price:d? [PROVENANCE]
trade_r1_price:d? [PROVENANCE]
trade_r2_price:d? [PROVENANCE]
trade_r3_price:d? [PROVENANCE]
first_observed_time_msc:t? [PROVENANCE]
first_observed_bid:d? [PROVENANCE]
pp_initial_relation:s? [PROVENANCE]
pp_role:s? [PROVENANCE]
pp_arm_time_msc:t? [PROVENANCE]
pp_arm_bid:d? [PROVENANCE]
terminal_time_msc:t? [OUTCOME_ONLY]
terminal_status:s? [OUTCOME_ONLY]
```

#### signal_events.tsv

```text
run_id:s [PROVENANCE]
signal_id:s [PROVENANCE]
sequence:i [PROVENANCE]
symbol:s [PROVENANCE]
direction:s [PROVENANCE]
signal_time_msc:t [PROVENANCE]
source_time_msc:t? [PROVENANCE]
macro_window_id:s? [PROVENANCE]
bid:d [PROVENANCE]
ask:d [PROVENANCE]
admission:s [PROVENANCE]
```

#### feature_snapshots.tsv

```text
run_id:s [PROVENANCE]
snapshot_id:s [PROVENANCE]
signal_id:s [PROVENANCE]
sequence:i [PROVENANCE]
capture_stage:s [PROVENANCE]
observed_time_msc:t [PROVENANCE]
macro_window_id:s? [PROVENANCE]
bid:d [PROVENANCE]
ask:d [PROVENANCE]
point:d [PROVENANCE]
tick_size:d [PROVENANCE]
macro_seconds:i [PROVENANCE]
micro_seconds:i [PROVENANCE]
complete:b [PROVENANCE]
macro_complete:b [PROVENANCE]
macro_reason:s [PROVENANCE]
macro_stochastic_complete:b [PROVENANCE]
macro_percent_b_complete:b [PROVENANCE]
macro_atr_complete:b [PROVENANCE]
macro_source_0_time_msc:t? [PROVENANCE]
macro_source_1_time_msc:t? [PROVENANCE]
macro_source_2_time_msc:t? [PROVENANCE]
macro_source_3_time_msc:t? [PROVENANCE]
macro_source_4_time_msc:t? [PROVENANCE]
macro_source_5_time_msc:t? [PROVENANCE]
macro_stochastic_k_0:d? [CAUSAL_FEATURE]
macro_stochastic_k_1:d? [CAUSAL_FEATURE]
macro_stochastic_k_2:d? [CAUSAL_FEATURE]
macro_stochastic_k_3:d? [CAUSAL_FEATURE]
macro_stochastic_k_4:d? [CAUSAL_FEATURE]
macro_stochastic_k_5:d? [CAUSAL_FEATURE]
macro_stochastic_d_0:d? [CAUSAL_FEATURE]
macro_stochastic_d_1:d? [CAUSAL_FEATURE]
macro_stochastic_d_2:d? [CAUSAL_FEATURE]
macro_stochastic_d_3:d? [CAUSAL_FEATURE]
macro_stochastic_d_4:d? [CAUSAL_FEATURE]
macro_stochastic_d_5:d? [CAUSAL_FEATURE]
macro_percent_b_0:d? [CAUSAL_FEATURE]
macro_percent_b_1:d? [CAUSAL_FEATURE]
macro_percent_b_2:d? [CAUSAL_FEATURE]
macro_percent_b_3:d? [CAUSAL_FEATURE]
macro_percent_b_4:d? [CAUSAL_FEATURE]
macro_percent_b_5:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_0:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_1:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_2:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_3:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_4:d? [CAUSAL_FEATURE]
macro_percent_b_sma_5_5:d? [CAUSAL_FEATURE]
macro_atr_13_0:d? [CAUSAL_FEATURE]
macro_atr_13_1:d? [CAUSAL_FEATURE]
macro_atr_13_2:d? [CAUSAL_FEATURE]
macro_atr_13_3:d? [CAUSAL_FEATURE]
macro_atr_13_4:d? [CAUSAL_FEATURE]
macro_atr_13_5:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_0:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_1:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_2:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_3:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_4:d? [CAUSAL_FEATURE]
macro_atr_13_sma_5_5:d? [CAUSAL_FEATURE]
micro_complete:b [PROVENANCE]
micro_reason:s [PROVENANCE]
micro_stochastic_complete:b [PROVENANCE]
micro_percent_b_complete:b [PROVENANCE]
micro_atr_complete:b [PROVENANCE]
micro_source_0_time_msc:t? [PROVENANCE]
micro_source_1_time_msc:t? [PROVENANCE]
micro_source_2_time_msc:t? [PROVENANCE]
micro_source_3_time_msc:t? [PROVENANCE]
micro_source_4_time_msc:t? [PROVENANCE]
micro_source_5_time_msc:t? [PROVENANCE]
micro_stochastic_k_0:d? [CAUSAL_FEATURE]
micro_stochastic_k_1:d? [CAUSAL_FEATURE]
micro_stochastic_k_2:d? [CAUSAL_FEATURE]
micro_stochastic_k_3:d? [CAUSAL_FEATURE]
micro_stochastic_k_4:d? [CAUSAL_FEATURE]
micro_stochastic_k_5:d? [CAUSAL_FEATURE]
micro_stochastic_d_0:d? [CAUSAL_FEATURE]
micro_stochastic_d_1:d? [CAUSAL_FEATURE]
micro_stochastic_d_2:d? [CAUSAL_FEATURE]
micro_stochastic_d_3:d? [CAUSAL_FEATURE]
micro_stochastic_d_4:d? [CAUSAL_FEATURE]
micro_stochastic_d_5:d? [CAUSAL_FEATURE]
micro_percent_b_0:d? [CAUSAL_FEATURE]
micro_percent_b_1:d? [CAUSAL_FEATURE]
micro_percent_b_2:d? [CAUSAL_FEATURE]
micro_percent_b_3:d? [CAUSAL_FEATURE]
micro_percent_b_4:d? [CAUSAL_FEATURE]
micro_percent_b_5:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_0:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_1:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_2:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_3:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_4:d? [CAUSAL_FEATURE]
micro_percent_b_sma_5_5:d? [CAUSAL_FEATURE]
micro_atr_13_0:d? [CAUSAL_FEATURE]
micro_atr_13_1:d? [CAUSAL_FEATURE]
micro_atr_13_2:d? [CAUSAL_FEATURE]
micro_atr_13_3:d? [CAUSAL_FEATURE]
micro_atr_13_4:d? [CAUSAL_FEATURE]
micro_atr_13_5:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_0:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_1:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_2:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_3:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_4:d? [CAUSAL_FEATURE]
micro_atr_13_sma_5_5:d? [CAUSAL_FEATURE]
pivot_complete:b [PROVENANCE]
signal_zone:s? [CAUSAL_FEATURE]
signal_vs_tested_pivot:s? [CAUSAL_FEATURE]
zone_lower_price:d? [CAUSAL_FEATURE]
zone_upper_price:d? [CAUSAL_FEATURE]
tested_level:s? [CAUSAL_FEATURE]
tested_price:d? [CAUSAL_FEATURE]
tested_role:s? [CAUSAL_FEATURE]
tested_distance_price:d? [CAUSAL_FEATURE]
tested_distance_points:d? [CAUSAL_FEATURE]
tested_age_ms:i? [CAUSAL_FEATURE]
tested_touch_time_msc:t? [PROVENANCE]
tested_sequence:i? [PROVENANCE]
tested_reclaimed:b? [CAUSAL_FEATURE]
tested_gap_cross:b? [CAUSAL_FEATURE]
pivot_s3_price:d? [PROVENANCE]
pivot_s3_touch_time_msc:t? [PROVENANCE]
pivot_s3_touch_sequence:i? [PROVENANCE]
pivot_s3_role:s? [PROVENANCE]
pivot_s3_reclaimed:b [PROVENANCE]
pivot_s3_gap_cross:b [PROVENANCE]
pivot_s2_price:d? [PROVENANCE]
pivot_s2_touch_time_msc:t? [PROVENANCE]
pivot_s2_touch_sequence:i? [PROVENANCE]
pivot_s2_role:s? [PROVENANCE]
pivot_s2_reclaimed:b [PROVENANCE]
pivot_s2_gap_cross:b [PROVENANCE]
pivot_s1_price:d? [PROVENANCE]
pivot_s1_touch_time_msc:t? [PROVENANCE]
pivot_s1_touch_sequence:i? [PROVENANCE]
pivot_s1_role:s? [PROVENANCE]
pivot_s1_reclaimed:b [PROVENANCE]
pivot_s1_gap_cross:b [PROVENANCE]
pivot_pp_price:d? [PROVENANCE]
pivot_pp_touch_time_msc:t? [PROVENANCE]
pivot_pp_touch_sequence:i? [PROVENANCE]
pivot_pp_role:s? [PROVENANCE]
pivot_pp_reclaimed:b [PROVENANCE]
pivot_pp_gap_cross:b [PROVENANCE]
pivot_r1_price:d? [PROVENANCE]
pivot_r1_touch_time_msc:t? [PROVENANCE]
pivot_r1_touch_sequence:i? [PROVENANCE]
pivot_r1_role:s? [PROVENANCE]
pivot_r1_reclaimed:b [PROVENANCE]
pivot_r1_gap_cross:b [PROVENANCE]
pivot_r2_price:d? [PROVENANCE]
pivot_r2_touch_time_msc:t? [PROVENANCE]
pivot_r2_touch_sequence:i? [PROVENANCE]
pivot_r2_role:s? [PROVENANCE]
pivot_r2_reclaimed:b [PROVENANCE]
pivot_r2_gap_cross:b [PROVENANCE]
pivot_r3_price:d? [PROVENANCE]
pivot_r3_touch_time_msc:t? [PROVENANCE]
pivot_r3_touch_sequence:i? [PROVENANCE]
pivot_r3_role:s? [PROVENANCE]
pivot_r3_reclaimed:b [PROVENANCE]
pivot_r3_gap_cross:b [PROVENANCE]
structure_complete:b [PROVENANCE]
structure_reason:s [PROVENANCE]
structure_last_closed_time_msc:t? [PROVENANCE]
structure_observed_bar_time_msc:t? [PROVENANCE]
confirmed_high_kind:s? [CAUSAL_FEATURE]
confirmed_high_class:s? [CAUSAL_FEATURE]
confirmed_high_price:d? [CAUSAL_FEATURE]
confirmed_high_pivot_time_msc:t? [PROVENANCE]
confirmed_high_confirmation_time_msc:t? [PROVENANCE]
confirmed_low_kind:s? [CAUSAL_FEATURE]
confirmed_low_class:s? [CAUSAL_FEATURE]
confirmed_low_price:d? [CAUSAL_FEATURE]
confirmed_low_pivot_time_msc:t? [PROVENANCE]
confirmed_low_confirmation_time_msc:t? [PROVENANCE]
confirmed_event_kind:s? [CAUSAL_FEATURE]
confirmed_event_class:s? [CAUSAL_FEATURE]
confirmed_event_price:d? [CAUSAL_FEATURE]
confirmed_event_pivot_time_msc:t? [PROVENANCE]
confirmed_event_confirmation_time_msc:t? [PROVENANCE]
forming_status:s [CAUSAL_FEATURE]
forming_kind:s? [CAUSAL_FEATURE]
forming_class:s? [CAUSAL_FEATURE]
forming_price:d? [CAUSAL_FEATURE]
forming_pivot_time_msc:t? [PROVENANCE]
```

#### entry_attempts.tsv

```text
run_id:s [PROVENANCE]
attempt_id:s [PROVENANCE]
signal_id:s [PROVENANCE]
snapshot_id:s [PROVENANCE]
parent_attempt_id:s? [PROVENANCE]
sequence:i [EXECUTION_FACT]
entry_type:s [EXECUTION_FACT]
direction:s [EXECUTION_FACT]
decision_time_msc:t [EXECUTION_FACT]
macro_window_id:s? [PROVENANCE]
bid:d [EXECUTION_FACT]
ask:d [EXECUTION_FACT]
```

#### trials.tsv

```text
run_id:s [PROVENANCE]
trial_id:s [PROVENANCE]
attempt_id:s [PROVENANCE]
role:s [EXECUTION_FACT]
entry_policy:s [EXECUTION_FACT]
rr:i [EXECUTION_FACT]
declared_time_msc:t [EXECUTION_FACT]
entry_time_msc:t? [EXECUTION_FACT]
deadline_time_msc:t? [EXECUTION_FACT]
entry_price:d? [EXECUTION_FACT]
sl:d? [EXECUTION_FACT]
tp:d? [EXECUTION_FACT]
volume:d? [EXECUTION_FACT]
eligibility:s [EXECUTION_FACT]
reason:s? [EXECUTION_FACT]
entry_bid:d? [EXECUTION_FACT]
entry_ask:d? [EXECUTION_FACT]
entry_quote_side:s? [EXECUTION_FACT]
exit_quote_side:s? [EXECUTION_FACT]
midpoint_50_price:d? [EXECUTION_FACT]
midpoint_touched:b? [EXECUTION_FACT]
requested_risk_distance_price:d? [EXECUTION_FACT]
requested_risk_distance_points:d? [EXECUTION_FACT]
normalized_risk_ticks:i? [EXECUTION_FACT]
normalized_risk_distance_price:d? [EXECUTION_FACT]
normalized_risk_distance_points:d? [EXECUTION_FACT]
geometry_equivalence_id:s? [PROVENANCE]
spread_points:d? [EXECUTION_FACT]
point_size:d? [EXECUTION_FACT]
trade_tick_size:d? [EXECUTION_FACT]
stops_level_points:d? [EXECUTION_FACT]
freeze_level_points:d? [EXECUTION_FACT]
minimum_risk_distance_points:d? [EXECUTION_FACT]
distance_eligible:b? [EXECUTION_FACT]
lot_mode:s? [EXECUTION_FACT]
lot_strategy_size:d? [EXECUTION_FACT]
reference_balance:d? [EXECUTION_FACT]
account_currency:s? [EXECUTION_FACT]
risk_budget_amount:d? [EXECUTION_FACT]
requested_volume:d? [EXECUTION_FACT]
virtual_expected_stop_loss:d? [EXECUTION_FACT]
virtual_expected_take_profit:d? [EXECUTION_FACT]
virtual_expected_reward_risk_ratio:d? [EXECUTION_FACT]
virtual_money_plan_complete:b? [EXECUTION_FACT]
origin_window_active_at_entry:b? [EXECUTION_FACT]
```

#### execution_checks.tsv

```text
run_id:s [PROVENANCE]
check_id:s [PROVENANCE]
attempt_id:s [PROVENANCE]
action:s [EXECUTION_FACT]
time_msc:t [EXECUTION_FACT]
sequence:i [EXECUTION_FACT]
allowed:b [EXECUTION_FACT]
reason:s [EXECUTION_FACT]
bid:d? [EXECUTION_FACT]
ask:d? [EXECUTION_FACT]
volume:d? [EXECUTION_FACT]
entry_price:d? [EXECUTION_FACT]
sl:d? [EXECUTION_FACT]
tp:d? [EXECUTION_FACT]
margin:d? [EXECUTION_FACT]
stop_profit:d? [EXECUTION_FACT]
check_retcode:i? [EXECUTION_FACT]
send_retcode:i? [EXECUTION_FACT]
order_ticket:i? [EXECUTION_FACT]
deal_ticket:i? [EXECUTION_FACT]
position_id:i? [PROVENANCE]
account_margin_mode:i? [EXECUTION_FACT]
account_margin_mode_supported:b? [EXECUTION_FACT]
symbol_trade_mode:i? [EXECUTION_FACT]
symbol_trade_mode_allowed:b? [EXECUTION_FACT]
market_session_open:b? [EXECUTION_FACT]
account_trade_allowed:b? [EXECUTION_FACT]
account_expert_trade_allowed:b? [EXECUTION_FACT]
terminal_trade_allowed:b? [EXECUTION_FACT]
mql_trade_allowed:b? [EXECUTION_FACT]
spread_points:d? [EXECUTION_FACT]
point_size:d? [EXECUTION_FACT]
trade_tick_size:d? [EXECUTION_FACT]
stops_distance_points:d? [EXECUTION_FACT]
freeze_distance_points:d? [EXECUTION_FACT]
risk_distance_points:d? [EXECUTION_FACT]
reward_distance_points:d? [EXECUTION_FACT]
risk_budget_amount:d? [EXECUTION_FACT]
requested_volume:d? [EXECUTION_FACT]
volume_min:d? [EXECUTION_FACT]
volume_max:d? [EXECUTION_FACT]
volume_step:d? [EXECUTION_FACT]
volume_valid:b? [EXECUTION_FACT]
fok_supported:b? [EXECUTION_FACT]
fill_policy:s? [EXECUTION_FACT]
quote_expected_take_profit:d? [EXECUTION_FACT]
quote_expected_reward_risk_ratio:d? [EXECUTION_FACT]
risk_budget_utilization_ratio:d? [EXECUTION_FACT]
account_balance:d? [EXECUTION_FACT]
free_margin:d? [EXECUTION_FACT]
margin_valid:b? [EXECUTION_FACT]
geometry_valid:b? [EXECUTION_FACT]
stop_distance_valid:b? [EXECUTION_FACT]
freeze_distance_valid:b? [EXECUTION_FACT]
order_check_performed:b? [EXECUTION_FACT]
order_check_allowed:b? [EXECUTION_FACT]
order_check_comment:s? [EXECUTION_FACT]
block_source:s? [EXECUTION_FACT]
send_performed:b? [EXECUTION_FACT]
send_succeeded:b? [EXECUTION_FACT]
trade_action:s? [EXECUTION_FACT]
send_comment:s? [EXECUTION_FACT]
position_ticket:i? [EXECUTION_FACT]
broker_entry_confirmed:b? [EXECUTION_FACT]
broker_close_confirmed:b? [EXECUTION_FACT]
broker_entry_price:d? [EXECUTION_FACT]
broker_volume:d? [EXECUTION_FACT]
broker_stop_loss:d? [EXECUTION_FACT]
broker_take_profit:d? [EXECUTION_FACT]
close_price:d? [EXECUTION_FACT]
closed_volume:d? [EXECUTION_FACT]
terminal_reason:s? [EXECUTION_FACT]
protection_modified:b? [EXECUTION_FACT]
```

#### outcomes.tsv

```text
run_id:s [PROVENANCE]
trial_id:s [PROVENANCE]
attempt_id:s [PROVENANCE]
role:s [OUTCOME_ONLY]
rr:i [OUTCOME_ONLY]
status:s [OUTCOME_ONLY]
broker_reason:s? [OUTCOME_ONLY]
entry_time_msc:t? [OUTCOME_ONLY]
entry_macro_open_time_msc:t? [OUTCOME_ONLY]
deadline_time_msc:t? [OUTCOME_ONLY]
exit_time_msc:t? [OUTCOME_ONLY]
observed_time_msc:t [OUTCOME_ONLY]
entry_price:d? [OUTCOME_ONLY]
exit_price:d? [OUTCOME_ONLY]
sl:d? [OUTCOME_ONLY]
tp:d? [OUTCOME_ONLY]
volume:d? [OUTCOME_ONLY]
gross_profit:d? [OUTCOME_ONLY]
costs:d? [OUTCOME_ONLY]
net_profit:d? [OUTCOME_ONLY]
gross_r:d? [OUTCOME_ONLY]
binary_label:i? [OUTCOME_ONLY]
binary_eligible:b [OUTCOME_ONLY]
exclusion_reason:s? [OUTCOME_ONLY]
position_id:i? [PROVENANCE]
fill_deviation_points:d? [OUTCOME_ONLY]
duration_ms:i? [OUTCOME_ONLY]
threshold_price:d? [OUTCOME_ONLY]
observed_exit_bid:d? [OUTCOME_ONLY]
observed_exit_ask:d? [OUTCOME_ONLY]
observed_exit_price:d? [OUTCOME_ONLY]
exit_quote_side:s? [OUTCOME_ONLY]
gap_points:d? [OUTCOME_ONLY]
nominal_r:d? [OUTCOME_ONLY]
first_touch_consistent:b? [OUTCOME_ONLY]
order_ticket:i? [OUTCOME_ONLY]
entry_deal_ticket:i? [OUTCOME_ONLY]
last_close_deal_ticket:i? [OUTCOME_ONLY]
close_deal_count:i? [OUTCOME_ONLY]
position_ticket:i? [OUTCOME_ONLY]
submitted_request_price:d? [OUTCOME_ONLY]
broker_closed_volume:d? [OUTCOME_ONLY]
request_risk_distance_points:d? [OUTCOME_ONLY]
request_reward_distance_points:d? [OUTCOME_ONLY]
request_price_reward_risk_ratio:d? [OUTCOME_ONLY]
risk_budget_amount:d? [OUTCOME_ONLY]
quote_expected_stop_loss:d? [OUTCOME_ONLY]
quote_expected_take_profit:d? [OUTCOME_ONLY]
quote_expected_reward_risk_ratio:d? [OUTCOME_ONLY]
risk_budget_utilization_ratio:d? [OUTCOME_ONLY]
exit_slippage_points:d? [OUTCOME_ONLY]
broker_commission:d? [OUTCOME_ONLY]
broker_swap:d? [OUTCOME_ONLY]
broker_fee:d? [OUTCOME_ONLY]
broker_gross_budget_r:d? [OUTCOME_ONLY]
broker_net_budget_r:d? [OUTCOME_ONLY]
broker_net_execution_r:d? [OUTCOME_ONLY]
close_reason_consistent:b? [OUTCOME_ONLY]
broker_entry_confirmed:b? [OUTCOME_ONLY]
broker_close_confirmed:b? [OUTCOME_ONLY]
```

#### run_summary.tsv

```text
key:s [PROVENANCE]
value:s [PROVENANCE]
```

#### pivot_origins.tsv

```text
run_id:s [PROVENANCE]
signal_id:s [PROVENANCE]
broker_signal_id:s? [PROVENANCE]
level_id:s [PROVENANCE]
pivot_raw_price:d [CAUSAL_FEATURE]
pivot_trade_price:d [CAUSAL_FEATURE]
next_outward_pivot_price:d [CAUSAL_FEATURE]
midpoint_50_price:d [CAUSAL_FEATURE]
structural_entry_price:d? [CAUSAL_FEATURE]
structural_sl_price:d? [CAUSAL_FEATURE]
structural_take_profit:d? [PROVENANCE]
stops_level_points:d [PROVENANCE]
freeze_level_points:d [PROVENANCE]
identity_consumed:b [PROVENANCE]
h1_lanes_declared:b [PROVENANCE]
broker_attempt_status:s [OUTCOME_ONLY]
origin_terminal_status:s [OUTCOME_ONLY]
```

#### candle_signals.tsv

```text
run_id:s [PROVENANCE]
signal_id:s [PROVENANCE]
pattern:s [CAUSAL_FEATURE]
pattern_direction:s [CAUSAL_FEATURE]
previous_open:d [CAUSAL_FEATURE]
previous_high:d [CAUSAL_FEATURE]
previous_low:d [CAUSAL_FEATURE]
previous_close:d [CAUSAL_FEATURE]
pattern_open:d [CAUSAL_FEATURE]
pattern_high:d [CAUSAL_FEATURE]
pattern_low:d [CAUSAL_FEATURE]
pattern_close:d [CAUSAL_FEATURE]
```

#### candle_attempts.tsv

```text
run_id:s [PROVENANCE]
attempt_id:s [PROVENANCE]
pattern:s [EXECUTION_FACT]
category:s [EXECUTION_FACT]
generation:i [EXECUTION_FACT]
atr_0:d? [EXECUTION_FACT]
atr_1:d? [EXECUTION_FACT]
atr_source_time_msc:t? [EXECUTION_FACT]
atr_shift:i [EXECUTION_FACT]
atr_multiplier:d [EXECUTION_FACT]
requested_volume:d? [EXECUTION_FACT]
entry_interval:s? [EXECUTION_FACT]
context_distance_points:d? [EXECUTION_FACT]
reentry_cause:s? [EXECUTION_FACT]
expiry_policy:s [EXECUTION_FACT]
```

<!-- ordered-contract:end -->

## Shared Features

For Macro and Micro capture shifts 0 through 5 of native Stochastic %K/%D
(5/3/3, SMA, Close/Close), weighted-price %B/SMA5, and native ATR13/SMA5.
%D is the native period-3 signal, not an extra SMA5. ATR multiplier is 1.0.
For each shift `%B = 100 * (weighted - lower) / (upper - lower)` with
`weighted = (high + low + 2 * close) / 4` and native Bands 21/0/2.0/SMA/WEIGHTED.
Each shift uses its own candle. SMA5 uses shifts `s..s+4`; ten raw values support
six averaged outputs. %B is unclipped; zero-width envelopes are unavailable.
No bandwidth, baseline, slopes or old frozen-pivot/Bid aliases are defaults.

Shift 0 is the current candle at the captured signal instant. Source-bar and
observed quote identities must be consistent around reads. A rollover or pending
buffer cannot be filled later under the earlier clock. Handles are cached, at
most seven distinct research handles with M1 deduplication, and safely released
on partial initialization. Export-off creates no research handles or state.

### Macro Zones

Use adjacent trade-normalized levels from the previous completed Macro candle.
`signal_zone` is BELOW_S3, AT_S3, S3_TO_S2, AT_S2, S2_TO_S1, AT_S1, S1_TO_PP,
AT_PP, PP_TO_R1, AT_R1, R1_TO_R2, AT_R2, R2_TO_R3, AT_R3 or ABOVE_R3.
`signal_vs_tested_pivot` is ABOVE/AT/BELOW_SUPPORT or
ABOVE/AT/BELOW_RESISTANCE, or UNTESTED. Unavailable ladder data is distinct from
UNTESTED. Trigger Bid owns both classifications in both directions; executable
Ask/Bid and engine-origin levels remain separate facts.

Retain finite/open interval bounds, selected level price/role, signed price and
point distances, touch clocks/sequence/age, reclaim/gap flags and all seven
level audit states. Preserve Candle's latest touch, outermost simultaneous tie,
first-observed-beyond-level, PP strict departure/return and Macro reset rules.
A crossing does not relabel the role recorded at the test. Do not round away a
strict comparison or invent a thickness parameter.

### M1 Structure

Reuse the standalone Stochastic Structure indicator's transition semantics and
attribution: strict 80/20 transitions, Close/Close candidate prices, confirming
candle starting the next leg, and trade-tick equality. Classify HIGH/LOW initial
candidates and HH/LH/HL/LL/EQ, retaining high/low kind for EQ.

Commit only closed-M1 state: last high and low classes/prices/pivot and
confirmation clocks, plus the latest confirmed event. Forming state is a new
projection of the current M1 Close/K(0) from a copy of committed state on every
capture, including an undrawn candidate. Temporary intrabar crossings cannot
advance committed history or survive through a previous projection. Mark this
view FORMING; freeze it with the signal even if it later changes or confirms.

Warmup uses at most 4,096 available closed M1 bars before the first observed tick.
Record the actual prefix bounds/count/fingerprint and completeness. Missing native
warmup values, absent comparator and truncated history remain explicit; unlimited
chart-history equivalence is not promised. Runtime processes closed bars once
in order in batches of at most 256 per callback. Gaps, history changes and pending
catch-up mark the affected view incomplete. No chart objects, future replay or
unbounded scans populate earlier snapshots.

## Clock And Instrument Contract

`BROKER_FIXED_V1` exports raw clocks and zero offset. Explicit Exness mode uses
`EXNESS_NEW_YORK_V1` only with documented UTC/Shift=0 input: US DST for all
symbols, summer zero offset and winter -60 minutes, supported years 2007..2099.
Analysis time is a normalized research wall clock, not another UTC instant.
It cannot reorder events across a backward fold. Preserve actual fill/close
clocks separately from request/reconciliation observations and raw bar clocks.
Use a per-run observed sequence for ties; later reconciliation does not imply
earlier knowledge. Completed duration is `exit_time_msc-entry_time_msc`, zero
allowed, null for unentered/censored results. Never include it as a causal feature.

Canonical instruments require verified source/specification mappings. Raw symbol
and mapping status remain available when unmapped. No silent suffix stripping,
cross-symbol concatenation, fitted scaler or model training belongs here.

## Engine Policies And Legacy Mapping

Pivot keeps direction-independent first consumption, Bid/PP triggers, one fresh
structural 1R FOK broker request, immutable SL/TP and eight virtual Macro lanes:
STRUCTURAL/MIDPOINT_50 x 1/2/3/5R. Midpoints trigger on Bid, then enter at Ask
for buys and Bid for sells, preserving the existing producer's spread behavior.
They retain their observed touch time,
rollover and last-structural-exit NOT_TRIGGERED behavior. They reference the
origin snapshot, not an invented entry-time feature vector. Exact request parity
exists even if stricter research distance eligibility is false. Deep input,
discovery, parent fan-out, trials, outcomes and parent-age selectors are removed.
Generic M10 remains a supported role period. Macro broker checks remain intact.

Candle keeps completed Micro Harami/Engulfing signals, ALIGNED/OPPOSED originals,
ATR13 x 1 shift-1 stops, both broker directions, one confirmed original-SL
re-entry before its deadline, per-entry Macro-duration expiry, actual expiry
closure, virtual R2/R3 and exact R1 parity. Execution ATR remains independent.
The decision snapshot freezes before submission. Submission refreshes the quote;
the trial declaration and entry check share that refreshed timestamp, which can
follow the decision time. Actual broker fills retain their separate deal time.
Symbol-scoped ownership uses the `0x43414e44` namespace plus the low 32 bits of
the UTF-8 symbol FNV-1a fingerprint; the entry comment is `CANDLE_PATTERN_ATR_V2`.

Shared research indicators are cached once: Bands, Stochastic and ATR for each
role, plus M1 Stochastic when Micro is not M1. Candle owns its separate execution
ATR. Partial handle availability leaves the corresponding feature family null;
it cannot gate an entry. Handles are released once on teardown or research failure.
Tester-only source audits retain the first 32 captures and at most 8,192 M1
observations outside the sealed run, under `MQL5ModelDatasetV1/diagnostics/`.
These bounded input receipts support independent feature comparison.

Broker costs and actual fills never become assumed virtual facts. Unknown virtual
costs/net remain null. Rejections, ineligibility, capacity refusal, no-touch, time
exits and run censors retain explicit statuses and engine-specific binary rules.
Parity is excluded from target cohorts. Failed capture cannot create a loss.

Legacy Pivot V14 and Candle 1/2/3 readers/fixtures/source runs remain intact.
Old source/binaries are recoverable through Git and retained receipts. There is
no automatic conversion, dual writer or fabricated historical milliseconds or
forming structure. Sprint 3 relocates the byte-identical legacy Candle MQL header
to its test fixtures and updates its generator comparison without changing it.

<!-- legacy-map:start -->

| Legacy owner | Disposition | Exact old columns |
| --- | --- | --- |
| Pivot V14 `run_manifest.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version` |
| Pivot V14 `run_manifest.tsv` | MAPPED: versioned manifest/seal keys, counts and policy facts; Deep counters removed | `key`, `value` |
| Pivot V14 `pivot_windows.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id`, `symbol` |
| Pivot V14 `pivot_windows.tsv` | MAPPED: macro_windows.tsv, normalized millisecond clocks; raw/trade ladders and terminal facts retained | `run_id`, `window_id`, `window_scope`, `timeframe`, `active_bar_open_broker_time`, `source_bar_open_broker_time`, `source_close_boundary_broker_time`, `source_open`, `source_high`, `source_low`, `source_close`, `source_range`, `raw_s3_price`, `raw_s2_price`, `raw_s1_price`, `raw_pp_price`, `raw_r1_price`, `raw_r2_price`, `raw_r3_price`, `trade_s3_price`, `trade_s2_price`, `trade_s1_price`, `trade_pp_price`, `trade_r1_price`, `trade_r2_price`, `trade_r3_price`, `first_observed_broker_time`, `first_observed_bid`, `pp_initial_relation`, `pp_role`, `pp_arm_broker_time`, `pp_arm_bid`, `window_state`, `invalid_reason`, `terminal_broker_time`, `terminal_status` |
| Pivot V14 `pivot_windows.tsv` | REPLACED: matching new clock companions under manifest clock policy | `active_bar_open_analysis_time`, `active_bar_open_offset_minutes`, `source_bar_open_analysis_time`, `source_bar_open_offset_minutes`, `source_close_boundary_analysis_time`, `source_close_boundary_offset_minutes`, `first_observed_analysis_time`, `first_observed_offset_minutes`, `pp_arm_analysis_time`, `pp_arm_offset_minutes`, `terminal_analysis_time`, `terminal_offset_minutes` |
| Pivot V14 `signal_origins.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id`, `symbol`, `macro_timeframe`, `micro_timeframe`, `point_size`, `trade_tick_size` |
| Pivot V14 `signal_origins.tsv` | MAPPED: signal_events/entry_attempts/pivot_origins, with ladder via macro_window_id; consumed origin snapshot frozen separately | `run_id`, `origin_id`, `window_id`, `broker_signal_id`, `active_bar_open_broker_time`, `level_id`, `direction`, `trigger_broker_time`, `trigger_bid`, `trigger_ask`, `spread_points`, `stops_level_points`, `freeze_level_points`, `raw_s3_price`, `raw_s2_price`, `raw_s1_price`, `raw_pp_price`, `raw_r1_price`, `raw_r2_price`, `raw_r3_price`, `trade_s3_price`, `trade_s2_price`, `trade_s1_price`, `trade_pp_price`, `trade_r1_price`, `trade_r2_price`, `trade_r3_price`, `pivot_raw_price`, `pivot_trade_price`, `next_outward_pivot_price`, `midpoint_50_price`, `structural_entry_price`, `structural_sl_price`, `structural_take_profit`, `identity_consumed`, `h1_lanes_declared`, `broker_attempt_status`, `origin_terminal_status` |
| Pivot V14 `signal_origins.tsv` | REMOVED: Deep research | `deep_timeframe` |
| Pivot V14 `signal_origins.tsv` | REPLACED: matching new clock companions under manifest clock policy | `trigger_analysis_time`, `trigger_offset_minutes` |
| Pivot V14 `signal_origins.tsv` | REPLACED: new named shared features/completeness in feature_snapshots.tsv; old semantics remain historical | `origin_macro_band_width_points_0`, `origin_macro_b_percent_0`, `origin_macro_b_percent_sma_5_0`, `origin_macro_b_percent_sma_slope_0`, `origin_macro_b_percent_state_0`, `origin_macro_b_percent_1`, `origin_macro_b_percent_sma_5_1`, `origin_macro_b_percent_sma_slope_1`, `origin_macro_b_percent_state_1`, `origin_macro_b_percent_2`, `origin_macro_b_percent_sma_5_2`, `origin_macro_b_percent_sma_slope_2`, `origin_macro_b_percent_state_2`, `origin_macro_b_percent_3`, `origin_macro_b_percent_sma_5_3`, `origin_macro_b_percent_sma_slope_3`, `origin_macro_b_percent_state_3`, `origin_macro_b_percent_4`, `origin_macro_b_percent_sma_5_4`, `origin_macro_b_percent_sma_slope_4`, `origin_macro_b_percent_state_4`, `origin_macro_b_percent_5`, `origin_macro_b_percent_sma_5_5`, `origin_macro_b_percent_sma_slope_5`, `origin_macro_b_percent_state_5`, `origin_macro_stochastic_main_line_0`, `origin_macro_stochastic_main_line_sma_5_0`, `origin_macro_stochastic_main_line_sma_slope_0`, `origin_macro_stochastic_main_line_state_0`, `origin_macro_stochastic_main_line_1`, `origin_macro_stochastic_main_line_sma_5_1`, `origin_macro_stochastic_main_line_sma_slope_1`, `origin_macro_stochastic_main_line_state_1`, `origin_macro_stochastic_main_line_2`, `origin_macro_stochastic_main_line_sma_5_2`, `origin_macro_stochastic_main_line_sma_slope_2`, `origin_macro_stochastic_main_line_state_2`, `origin_macro_stochastic_main_line_3`, `origin_macro_stochastic_main_line_sma_5_3`, `origin_macro_stochastic_main_line_sma_slope_3`, `origin_macro_stochastic_main_line_state_3`, `origin_macro_stochastic_main_line_4`, `origin_macro_stochastic_main_line_sma_5_4`, `origin_macro_stochastic_main_line_sma_slope_4`, `origin_macro_stochastic_main_line_state_4`, `origin_macro_stochastic_main_line_5`, `origin_macro_stochastic_main_line_sma_5_5`, `origin_macro_stochastic_main_line_sma_slope_5`, `origin_macro_stochastic_main_line_state_5`, `origin_macro_stochastic_signal_line_0`, `origin_macro_stochastic_signal_line_sma_5_0`, `origin_macro_stochastic_signal_line_sma_slope_0`, `origin_macro_stochastic_signal_line_state_0`, `origin_macro_stochastic_signal_line_1`, `origin_macro_stochastic_signal_line_sma_5_1`, `origin_macro_stochastic_signal_line_sma_slope_1`, `origin_macro_stochastic_signal_line_state_1`, `origin_macro_stochastic_signal_line_2`, `origin_macro_stochastic_signal_line_sma_5_2`, `origin_macro_stochastic_signal_line_sma_slope_2`, `origin_macro_stochastic_signal_line_state_2`, `origin_macro_stochastic_signal_line_3`, `origin_macro_stochastic_signal_line_sma_5_3`, `origin_macro_stochastic_signal_line_sma_slope_3`, `origin_macro_stochastic_signal_line_state_3`, `origin_macro_stochastic_signal_line_4`, `origin_macro_stochastic_signal_line_sma_5_4`, `origin_macro_stochastic_signal_line_sma_slope_4`, `origin_macro_stochastic_signal_line_state_4`, `origin_macro_stochastic_signal_line_5`, `origin_macro_stochastic_signal_line_sma_5_5`, `origin_macro_stochastic_signal_line_sma_slope_5`, `origin_macro_stochastic_signal_line_state_5`, `origin_macro_band_base_line_0`, `origin_macro_band_base_line_slope_points_0`, `origin_macro_band_base_line_1`, `origin_macro_band_base_line_slope_points_1`, `origin_macro_band_base_line_2`, `origin_macro_band_base_line_slope_points_2`, `origin_macro_band_base_line_3`, `origin_macro_band_base_line_slope_points_3`, `origin_macro_band_base_line_4`, `origin_macro_band_base_line_slope_points_4`, `origin_macro_band_base_line_5`, `origin_macro_band_base_line_slope_points_5`, `origin_deep_band_width_points_0`, `origin_deep_b_percent_0`, `origin_deep_b_percent_sma_5_0`, `origin_deep_b_percent_sma_slope_0`, `origin_deep_b_percent_state_0`, `origin_deep_b_percent_1`, `origin_deep_b_percent_sma_5_1`, `origin_deep_b_percent_sma_slope_1`, `origin_deep_b_percent_state_1`, `origin_deep_b_percent_2`, `origin_deep_b_percent_sma_5_2`, `origin_deep_b_percent_sma_slope_2`, `origin_deep_b_percent_state_2`, `origin_deep_b_percent_3`, `origin_deep_b_percent_sma_5_3`, `origin_deep_b_percent_sma_slope_3`, `origin_deep_b_percent_state_3`, `origin_deep_b_percent_4`, `origin_deep_b_percent_sma_5_4`, `origin_deep_b_percent_sma_slope_4`, `origin_deep_b_percent_state_4`, `origin_deep_b_percent_5`, `origin_deep_b_percent_sma_5_5`, `origin_deep_b_percent_sma_slope_5`, `origin_deep_b_percent_state_5`, `origin_deep_stochastic_main_line_0`, `origin_deep_stochastic_main_line_sma_5_0`, `origin_deep_stochastic_main_line_sma_slope_0`, `origin_deep_stochastic_main_line_state_0`, `origin_deep_stochastic_main_line_1`, `origin_deep_stochastic_main_line_sma_5_1`, `origin_deep_stochastic_main_line_sma_slope_1`, `origin_deep_stochastic_main_line_state_1`, `origin_deep_stochastic_main_line_2`, `origin_deep_stochastic_main_line_sma_5_2`, `origin_deep_stochastic_main_line_sma_slope_2`, `origin_deep_stochastic_main_line_state_2`, `origin_deep_stochastic_main_line_3`, `origin_deep_stochastic_main_line_sma_5_3`, `origin_deep_stochastic_main_line_sma_slope_3`, `origin_deep_stochastic_main_line_state_3`, `origin_deep_stochastic_main_line_4`, `origin_deep_stochastic_main_line_sma_5_4`, `origin_deep_stochastic_main_line_sma_slope_4`, `origin_deep_stochastic_main_line_state_4`, `origin_deep_stochastic_main_line_5`, `origin_deep_stochastic_main_line_sma_5_5`, `origin_deep_stochastic_main_line_sma_slope_5`, `origin_deep_stochastic_main_line_state_5`, `origin_deep_stochastic_signal_line_0`, `origin_deep_stochastic_signal_line_sma_5_0`, `origin_deep_stochastic_signal_line_sma_slope_0`, `origin_deep_stochastic_signal_line_state_0`, `origin_deep_stochastic_signal_line_1`, `origin_deep_stochastic_signal_line_sma_5_1`, `origin_deep_stochastic_signal_line_sma_slope_1`, `origin_deep_stochastic_signal_line_state_1`, `origin_deep_stochastic_signal_line_2`, `origin_deep_stochastic_signal_line_sma_5_2`, `origin_deep_stochastic_signal_line_sma_slope_2`, `origin_deep_stochastic_signal_line_state_2`, `origin_deep_stochastic_signal_line_3`, `origin_deep_stochastic_signal_line_sma_5_3`, `origin_deep_stochastic_signal_line_sma_slope_3`, `origin_deep_stochastic_signal_line_state_3`, `origin_deep_stochastic_signal_line_4`, `origin_deep_stochastic_signal_line_sma_5_4`, `origin_deep_stochastic_signal_line_sma_slope_4`, `origin_deep_stochastic_signal_line_state_4`, `origin_deep_stochastic_signal_line_5`, `origin_deep_stochastic_signal_line_sma_5_5`, `origin_deep_stochastic_signal_line_sma_slope_5`, `origin_deep_stochastic_signal_line_state_5`, `origin_deep_band_base_line_0`, `origin_deep_band_base_line_slope_points_0`, `origin_deep_band_base_line_1`, `origin_deep_band_base_line_slope_points_1`, `origin_deep_band_base_line_2`, `origin_deep_band_base_line_slope_points_2`, `origin_deep_band_base_line_3`, `origin_deep_band_base_line_slope_points_3`, `origin_deep_band_base_line_4`, `origin_deep_band_base_line_slope_points_4`, `origin_deep_band_base_line_5`, `origin_deep_band_base_line_slope_points_5`, `origin_macro_features_complete`, `origin_deep_features_complete`, `origin_feature_snapshot_complete`, `origin_feature_invalid_reason` |
| Pivot V14 `virtual_trials.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id`, `point_size`, `trade_tick_size`, `account_currency` |
| Pivot V14 `virtual_trials.tsv` | MAPPED: trials.tsv, origin via attempt; lane/trial_role becomes role, entry_policy retained; exact geometry/eligibility retained | `run_id`, `trial_id`, `parity_trial_id`, `origin_id`, `window_id`, `broker_signal_id`, `trial_role`, `entry_policy`, `tp_r_multiple`, `level_id`, `direction`, `declared_broker_time`, `entry_broker_time`, `entry_bid`, `entry_ask`, `entry_price`, `entry_quote_side`, `exit_quote_side`, `midpoint_50_price`, `midpoint_touched`, `requested_risk_distance_price`, `requested_risk_distance_points`, `normalized_risk_ticks`, `normalized_risk_distance_price`, `normalized_risk_distance_points`, `stop_loss_price`, `take_profit_price`, `geometry_equivalence_id`, `spread_points`, `stops_level_points`, `freeze_level_points`, `minimum_risk_distance_points`, `distance_eligible`, `lot_mode`, `lot_strategy_size`, `reference_balance`, `risk_budget_amount`, `requested_volume`, `normalized_volume`, `virtual_expected_stop_loss`, `virtual_expected_take_profit`, `virtual_expected_reward_risk_ratio`, `virtual_money_plan_complete`, `eligibility_status`, `ineligible_reason`, `origin_window_active_at_entry` |
| Pivot V14 `virtual_trials.tsv` | REPLACED: matching new clock companions under manifest clock policy | `declared_analysis_time`, `declared_offset_minutes`, `entry_analysis_time`, `entry_offset_minutes` |
| Pivot V14 `virtual_outcomes.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id` |
| Pivot V14 `virtual_outcomes.tsv` | MAPPED: outcomes.tsv and linked trial/attempt; exact costs, labels, reason and clocks; duration upgraded to explicit milliseconds | `run_id`, `outcome_id`, `trial_id`, `parity_trial_id`, `origin_id`, `window_id`, `trial_role`, `entry_policy`, `tp_r_multiple`, `direction`, `terminal_broker_time`, `terminal_status`, `terminal_reason`, `threshold_price`, `observed_exit_bid`, `observed_exit_ask`, `observed_exit_price`, `exit_quote_side`, `gap_points`, `h1_structural_lifecycle_seconds`, `virtual_nominal_r`, `virtual_quote_gross_profit`, `virtual_quote_gross_r`, `virtual_binary_eligible`, `virtual_binary_target`, `virtual_exclusion_reason`, `first_touch_consistent` |
| Pivot V14 `virtual_outcomes.tsv` | REPLACED: matching new clock companions under manifest clock policy | `terminal_analysis_time`, `terminal_offset_minutes` |
| Pivot V14 `deep_pivot_events.tsv` | REMOVED: Deep research | `schema_version`, `run_id`, `config_id`, `deep_event_id`, `deep_window_id`, `symbol`, `deep_timeframe`, `micro_timeframe`, `active_deep_bar_open_broker_time`, `level_id`, `direction`, `trigger_broker_time`, `trigger_analysis_time`, `trigger_offset_minutes`, `trigger_bid`, `trigger_ask`, `spread_points`, `point_size`, `trade_tick_size`, `stops_level_points`, `freeze_level_points`, `pivot_raw_price`, `pivot_trade_price`, `next_outward_pivot_price`, `deep_deep_band_width_points_0`, `deep_deep_b_percent_0`, `deep_deep_b_percent_sma_5_0`, `deep_deep_b_percent_sma_slope_0`, `deep_deep_b_percent_state_0`, `deep_deep_b_percent_1`, `deep_deep_b_percent_sma_5_1`, `deep_deep_b_percent_sma_slope_1`, `deep_deep_b_percent_state_1`, `deep_deep_b_percent_2`, `deep_deep_b_percent_sma_5_2`, `deep_deep_b_percent_sma_slope_2`, `deep_deep_b_percent_state_2`, `deep_deep_b_percent_3`, `deep_deep_b_percent_sma_5_3`, `deep_deep_b_percent_sma_slope_3`, `deep_deep_b_percent_state_3`, `deep_deep_b_percent_4`, `deep_deep_b_percent_sma_5_4`, `deep_deep_b_percent_sma_slope_4`, `deep_deep_b_percent_state_4`, `deep_deep_b_percent_5`, `deep_deep_b_percent_sma_5_5`, `deep_deep_b_percent_sma_slope_5`, `deep_deep_b_percent_state_5`, `deep_deep_stochastic_main_line_0`, `deep_deep_stochastic_main_line_sma_5_0`, `deep_deep_stochastic_main_line_sma_slope_0`, `deep_deep_stochastic_main_line_state_0`, `deep_deep_stochastic_main_line_1`, `deep_deep_stochastic_main_line_sma_5_1`, `deep_deep_stochastic_main_line_sma_slope_1`, `deep_deep_stochastic_main_line_state_1`, `deep_deep_stochastic_main_line_2`, `deep_deep_stochastic_main_line_sma_5_2`, `deep_deep_stochastic_main_line_sma_slope_2`, `deep_deep_stochastic_main_line_state_2`, `deep_deep_stochastic_main_line_3`, `deep_deep_stochastic_main_line_sma_5_3`, `deep_deep_stochastic_main_line_sma_slope_3`, `deep_deep_stochastic_main_line_state_3`, `deep_deep_stochastic_main_line_4`, `deep_deep_stochastic_main_line_sma_5_4`, `deep_deep_stochastic_main_line_sma_slope_4`, `deep_deep_stochastic_main_line_state_4`, `deep_deep_stochastic_main_line_5`, `deep_deep_stochastic_main_line_sma_5_5`, `deep_deep_stochastic_main_line_sma_slope_5`, `deep_deep_stochastic_main_line_state_5`, `deep_deep_stochastic_signal_line_0`, `deep_deep_stochastic_signal_line_sma_5_0`, `deep_deep_stochastic_signal_line_sma_slope_0`, `deep_deep_stochastic_signal_line_state_0`, `deep_deep_stochastic_signal_line_1`, `deep_deep_stochastic_signal_line_sma_5_1`, `deep_deep_stochastic_signal_line_sma_slope_1`, `deep_deep_stochastic_signal_line_state_1`, `deep_deep_stochastic_signal_line_2`, `deep_deep_stochastic_signal_line_sma_5_2`, `deep_deep_stochastic_signal_line_sma_slope_2`, `deep_deep_stochastic_signal_line_state_2`, `deep_deep_stochastic_signal_line_3`, `deep_deep_stochastic_signal_line_sma_5_3`, `deep_deep_stochastic_signal_line_sma_slope_3`, `deep_deep_stochastic_signal_line_state_3`, `deep_deep_stochastic_signal_line_4`, `deep_deep_stochastic_signal_line_sma_5_4`, `deep_deep_stochastic_signal_line_sma_slope_4`, `deep_deep_stochastic_signal_line_state_4`, `deep_deep_stochastic_signal_line_5`, `deep_deep_stochastic_signal_line_sma_5_5`, `deep_deep_stochastic_signal_line_sma_slope_5`, `deep_deep_stochastic_signal_line_state_5`, `deep_deep_band_base_line_0`, `deep_deep_band_base_line_slope_points_0`, `deep_deep_band_base_line_1`, `deep_deep_band_base_line_slope_points_1`, `deep_deep_band_base_line_2`, `deep_deep_band_base_line_slope_points_2`, `deep_deep_band_base_line_3`, `deep_deep_band_base_line_slope_points_3`, `deep_deep_band_base_line_4`, `deep_deep_band_base_line_slope_points_4`, `deep_deep_band_base_line_5`, `deep_deep_band_base_line_slope_points_5`, `deep_micro_band_width_points_0`, `deep_micro_b_percent_0`, `deep_micro_b_percent_sma_5_0`, `deep_micro_b_percent_sma_slope_0`, `deep_micro_b_percent_state_0`, `deep_micro_b_percent_1`, `deep_micro_b_percent_sma_5_1`, `deep_micro_b_percent_sma_slope_1`, `deep_micro_b_percent_state_1`, `deep_micro_b_percent_2`, `deep_micro_b_percent_sma_5_2`, `deep_micro_b_percent_sma_slope_2`, `deep_micro_b_percent_state_2`, `deep_micro_b_percent_3`, `deep_micro_b_percent_sma_5_3`, `deep_micro_b_percent_sma_slope_3`, `deep_micro_b_percent_state_3`, `deep_micro_b_percent_4`, `deep_micro_b_percent_sma_5_4`, `deep_micro_b_percent_sma_slope_4`, `deep_micro_b_percent_state_4`, `deep_micro_b_percent_5`, `deep_micro_b_percent_sma_5_5`, `deep_micro_b_percent_sma_slope_5`, `deep_micro_b_percent_state_5`, `deep_micro_stochastic_main_line_0`, `deep_micro_stochastic_main_line_sma_5_0`, `deep_micro_stochastic_main_line_sma_slope_0`, `deep_micro_stochastic_main_line_state_0`, `deep_micro_stochastic_main_line_1`, `deep_micro_stochastic_main_line_sma_5_1`, `deep_micro_stochastic_main_line_sma_slope_1`, `deep_micro_stochastic_main_line_state_1`, `deep_micro_stochastic_main_line_2`, `deep_micro_stochastic_main_line_sma_5_2`, `deep_micro_stochastic_main_line_sma_slope_2`, `deep_micro_stochastic_main_line_state_2`, `deep_micro_stochastic_main_line_3`, `deep_micro_stochastic_main_line_sma_5_3`, `deep_micro_stochastic_main_line_sma_slope_3`, `deep_micro_stochastic_main_line_state_3`, `deep_micro_stochastic_main_line_4`, `deep_micro_stochastic_main_line_sma_5_4`, `deep_micro_stochastic_main_line_sma_slope_4`, `deep_micro_stochastic_main_line_state_4`, `deep_micro_stochastic_main_line_5`, `deep_micro_stochastic_main_line_sma_5_5`, `deep_micro_stochastic_main_line_sma_slope_5`, `deep_micro_stochastic_main_line_state_5`, `deep_micro_stochastic_signal_line_0`, `deep_micro_stochastic_signal_line_sma_5_0`, `deep_micro_stochastic_signal_line_sma_slope_0`, `deep_micro_stochastic_signal_line_state_0`, `deep_micro_stochastic_signal_line_1`, `deep_micro_stochastic_signal_line_sma_5_1`, `deep_micro_stochastic_signal_line_sma_slope_1`, `deep_micro_stochastic_signal_line_state_1`, `deep_micro_stochastic_signal_line_2`, `deep_micro_stochastic_signal_line_sma_5_2`, `deep_micro_stochastic_signal_line_sma_slope_2`, `deep_micro_stochastic_signal_line_state_2`, `deep_micro_stochastic_signal_line_3`, `deep_micro_stochastic_signal_line_sma_5_3`, `deep_micro_stochastic_signal_line_sma_slope_3`, `deep_micro_stochastic_signal_line_state_3`, `deep_micro_stochastic_signal_line_4`, `deep_micro_stochastic_signal_line_sma_5_4`, `deep_micro_stochastic_signal_line_sma_slope_4`, `deep_micro_stochastic_signal_line_state_4`, `deep_micro_stochastic_signal_line_5`, `deep_micro_stochastic_signal_line_sma_5_5`, `deep_micro_stochastic_signal_line_sma_slope_5`, `deep_micro_stochastic_signal_line_state_5`, `deep_micro_band_base_line_0`, `deep_micro_band_base_line_slope_points_0`, `deep_micro_band_base_line_1`, `deep_micro_band_base_line_slope_points_1`, `deep_micro_band_base_line_2`, `deep_micro_band_base_line_slope_points_2`, `deep_micro_band_base_line_3`, `deep_micro_band_base_line_slope_points_3`, `deep_micro_band_base_line_4`, `deep_micro_band_base_line_slope_points_4`, `deep_micro_band_base_line_5`, `deep_micro_band_base_line_slope_points_5`, `deep_deep_features_complete`, `deep_micro_features_complete`, `deep_feature_snapshot_complete`, `deep_feature_invalid_reason`, `identity_consumed`, `admission_status`, `active_parent_count`, `required_link_slots`, `required_trial_slots`, `required_outcome_slots`, `reserved_link_slots`, `reserved_trial_slots`, `reserved_outcome_slots`, `capacity_rejection_reason` |
| Pivot V14 `deep_pivot_parent_links.tsv` | REMOVED: Deep research | `schema_version`, `run_id`, `config_id`, `parent_link_id`, `deep_event_id`, `origin_id`, `parent_kind`, `parent_trial_id`, `parent_broker_signal_id`, `parent_entry_policy`, `parent_tp_r_multiple`, `parent_direction`, `deep_direction`, `direction_relationship`, `parent_entry_broker_time`, `event_trigger_broker_time`, `m10_parent_age_seconds`, `link_status` |
| Pivot V14 `deep_virtual_trials.tsv` | REMOVED: Deep research | `schema_version`, `run_id`, `config_id`, `deep_trial_id`, `deep_event_id`, `tp_r_multiple`, `level_id`, `direction`, `declared_broker_time`, `declared_analysis_time`, `declared_offset_minutes`, `entry_bid`, `entry_ask`, `entry_price`, `entry_quote_side`, `exit_quote_side`, `requested_risk_distance_price`, `requested_risk_distance_points`, `normalized_risk_ticks`, `normalized_risk_distance_price`, `normalized_risk_distance_points`, `stop_loss_price`, `take_profit_price`, `geometry_equivalence_id`, `spread_points`, `point_size`, `trade_tick_size`, `stops_level_points`, `freeze_level_points`, `minimum_risk_distance_points`, `distance_eligible`, `eligibility_status`, `ineligible_reason` |
| Pivot V14 `deep_virtual_outcomes.tsv` | REMOVED: Deep research | `schema_version`, `run_id`, `config_id`, `deep_outcome_id`, `parent_link_id`, `deep_trial_id`, `deep_event_id`, `origin_id`, `tp_r_multiple`, `direction`, `parent_direction`, `terminal_broker_time`, `terminal_analysis_time`, `terminal_offset_minutes`, `terminal_status`, `terminal_reason`, `threshold_price`, `observed_exit_bid`, `observed_exit_ask`, `observed_exit_price`, `exit_quote_side`, `gap_points`, `deep_lifecycle_seconds`, `virtual_nominal_r`, `virtual_quote_gross_profit`, `virtual_quote_gross_r`, `virtual_binary_eligible`, `virtual_binary_target`, `virtual_exclusion_reason`, `first_touch_consistent` |
| Pivot V14 `execution_checks.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id`, `symbol`, `point_size`, `trade_tick_size` |
| Pivot V14 `execution_checks.tsv` | MAPPED: execution_checks.tsv; shared quote/request names and nullable preserved engine checks; origin/window resolved via attempt | `run_id`, `check_id`, `origin_id`, `broker_signal_id`, `parity_trial_id`, `window_id`, `check_sequence`, `check_phase`, `broker_time`, `direction`, `account_margin_mode`, `account_margin_mode_supported`, `symbol_trade_mode`, `symbol_trade_mode_allowed`, `market_session_open`, `account_trade_allowed`, `account_expert_trade_allowed`, `terminal_trade_allowed`, `mql_trade_allowed`, `bid`, `ask`, `spread_points`, `stops_distance_points`, `freeze_distance_points`, `entry_price`, `stop_loss_price`, `take_profit_price`, `risk_distance_points`, `reward_distance_points`, `risk_budget_amount`, `requested_volume`, `normalized_volume`, `volume_min`, `volume_max`, `volume_step`, `volume_valid`, `fok_supported`, `fill_policy`, `quote_expected_stop_loss`, `quote_expected_take_profit`, `quote_expected_reward_risk_ratio`, `risk_budget_utilization_ratio`, `account_balance`, `free_margin`, `required_margin`, `margin_valid`, `geometry_valid`, `stop_distance_valid`, `freeze_distance_valid`, `order_check_performed`, `order_check_allowed`, `order_check_retcode`, `order_check_comment`, `allowed`, `block_source`, `block_reason`, `send_performed`, `send_succeeded`, `trade_action`, `send_retcode`, `send_comment`, `order_ticket`, `deal_ticket`, `position_ticket`, `position_identifier`, `broker_entry_confirmed`, `broker_close_confirmed`, `broker_entry_price`, `broker_volume`, `broker_stop_loss`, `broker_take_profit`, `close_price`, `closed_volume`, `terminal_reason`, `protection_modified` |
| Pivot V14 `execution_checks.tsv` | REPLACED: matching new clock companions under manifest clock policy | `analysis_time`, `offset_minutes` |
| Pivot V14 `broker_outcomes.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id`, `symbol`, `macro_timeframe`, `micro_timeframe` |
| Pivot V14 `broker_outcomes.tsv` | MAPPED: outcomes.tsv and linked trial/attempt; exact costs, labels, reason and clocks; duration upgraded to explicit milliseconds | `run_id`, `broker_outcome_id`, `origin_id`, `broker_signal_id`, `parity_trial_id`, `window_id`, `active_bar_open_broker_time`, `level_id`, `direction`, `entry_broker_time`, `close_broker_time`, `order_ticket`, `entry_deal_ticket`, `last_close_deal_ticket`, `close_deal_count`, `position_ticket`, `position_identifier`, `submitted_request_price`, `broker_entry_price`, `broker_volume`, `immutable_stop_loss`, `immutable_take_profit`, `broker_close_price`, `broker_closed_volume`, `request_risk_distance_points`, `request_reward_distance_points`, `request_price_reward_risk_ratio`, `risk_budget_amount`, `quote_expected_stop_loss`, `quote_expected_take_profit`, `quote_expected_reward_risk_ratio`, `risk_budget_utilization_ratio`, `entry_slippage_points`, `exit_slippage_points`, `broker_gross_profit`, `broker_commission`, `broker_swap`, `broker_fee`, `broker_net_profit`, `broker_gross_budget_r`, `broker_net_budget_r`, `broker_gross_execution_r`, `broker_net_execution_r`, `broker_terminal_reason`, `close_reason_consistent`, `broker_binary_eligible`, `broker_binary_target`, `broker_exclusion_reason`, `h1_structural_lifecycle_seconds`, `broker_entry_confirmed`, `broker_close_confirmed` |
| Pivot V14 `broker_outcomes.tsv` | REMOVED: Deep research | `deep_timeframe` |
| Pivot V14 `broker_outcomes.tsv` | REPLACED: matching new clock companions under manifest clock policy | `entry_analysis_time`, `entry_offset_minutes`, `close_analysis_time`, `close_offset_minutes` |
| Pivot V14 `run_summary.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `schema_version`, `config_id` |
| Pivot V14 `run_summary.tsv` | MAPPED: versioned manifest/seal keys, counts and policy facts; Deep counters removed | `run_id`, `started_broker_time`, `finished_broker_time`, `pivot_window_rows`, `macro_window_rows`, `signal_origin_rows`, `h1_trial_rows`, `h1_structural_trial_rows`, `h1_midpoint_trial_rows`, `parity_trial_rows`, `h1_outcome_rows`, `h1_tp_rows`, `h1_sl_rows`, `h1_not_triggered_rows`, `h1_ineligible_rows`, `h1_run_censored_rows`, `execution_check_rows`, `broker_outcome_rows`, `parity_pair_rows`, `h1_active_state_peak`, `h1_active_state_cap`, `duplicate_identity_count`, `referential_integrity_error_count`, `row_integrity_error_count`, `export_status`, `completion_status` |
| Pivot V14 `run_summary.tsv` | REPLACED: matching new clock companions under manifest clock policy | `started_analysis_time`, `started_offset_minutes`, `finished_analysis_time`, `finished_offset_minutes` |
| Pivot V14 `run_summary.tsv` | REMOVED: Deep research | `deep_window_rows`, `deep_event_rows`, `deep_event_admitted_rows`, `deep_event_capacity_rejected_rows`, `deep_parent_link_rows`, `deep_trial_rows`, `deep_outcome_rows`, `deep_tp_rows`, `deep_sl_rows`, `deep_parent_exit_censored_rows`, `deep_run_censored_rows`, `deep_ineligible_rows`, `deep_event_active_peak`, `deep_event_active_cap`, `deep_link_active_peak`, `deep_link_active_cap`, `deep_trial_active_peak`, `deep_trial_active_cap`, `deep_outcome_active_peak`, `deep_outcome_active_cap` |
| Candle 1/2/3 `run_manifest.tsv` | MAPPED: versioned manifest/seal keys, counts and policy facts; Deep counters removed | `key`, `value` |
| Candle 1/2/3 `macro_windows.tsv` | MAPPED: macro_windows.tsv, normalized millisecond clocks; raw/trade ladders and terminal facts retained | `run_id`, `window_id`, `open_time_msc`, `source_time_msc`, `source_open`, `source_high`, `source_low`, `source_close`, `valid`, `reason`, `pivot_s3`, `pivot_s2`, `pivot_s1`, `pivot_pp`, `pivot_r1`, `pivot_r2`, `pivot_r3` |
| Candle 1/2/3 `macro_windows.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `macro_seconds` |
| Candle 1/2/3 `macro_windows.tsv` | REPLACED: matching new clock companions under manifest clock policy | `open_analysis_time_msc`, `open_analysis_offset_minutes`, `source_analysis_time_msc`, `source_analysis_offset_minutes` |
| Candle 1/2/3 `signal_events.tsv` | MAPPED: signal_events/candle_signals, root_id becomes signal_id | `run_id`, `root_id`, `sequence`, `pattern`, `pattern_direction`, `signal_bar_time_msc`, `decision_time_msc`, `admission`, `previous_open`, `previous_high`, `previous_low`, `previous_close`, `pattern_open`, `pattern_high`, `pattern_low`, `pattern_close` |
| Candle 1/2/3 `signal_events.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `symbol`, `micro_seconds` |
| Candle 1/2/3 `signal_events.tsv` | REPLACED: matching new clock companions under manifest clock policy | `signal_bar_analysis_time_msc`, `signal_bar_analysis_offset_minutes`, `decision_analysis_time_msc`, `decision_analysis_offset_minutes` |
| Candle 1/2/3 `entry_attempts.tsv` | MAPPED: entry_attempts/candle_attempts; pivot audit fields in feature_snapshots, executable interval retained in candle_attempts | `run_id`, `attempt_id`, `root_id`, `parent_attempt_id`, `sequence`, `entry_type`, `pattern`, `category`, `direction`, `decision_time_msc`, `macro_window_id`, `macro_open_time_msc`, `bid`, `ask`, `atr_0`, `atr_1`, `atr_source_time_msc`, `atr_shift`, `atr_multiplier`, `requested_volume`, `entry_interval`, `context_level`, `context_role`, `context_distance_points`, `context_age_ms`, `pivot_s3_price`, `pivot_s3_touch_time_msc`, `pivot_s3_touch_sequence`, `pivot_s3_role`, `pivot_s3_reclaimed`, `pivot_s3_gap_cross`, `pivot_s2_price`, `pivot_s2_touch_time_msc`, `pivot_s2_touch_sequence`, `pivot_s2_role`, `pivot_s2_reclaimed`, `pivot_s2_gap_cross`, `pivot_s1_price`, `pivot_s1_touch_time_msc`, `pivot_s1_touch_sequence`, `pivot_s1_role`, `pivot_s1_reclaimed`, `pivot_s1_gap_cross`, `pivot_pp_price`, `pivot_pp_touch_time_msc`, `pivot_pp_touch_sequence`, `pivot_pp_role`, `pivot_pp_reclaimed`, `pivot_pp_gap_cross`, `pivot_r1_price`, `pivot_r1_touch_time_msc`, `pivot_r1_touch_sequence`, `pivot_r1_role`, `pivot_r1_reclaimed`, `pivot_r1_gap_cross`, `pivot_r2_price`, `pivot_r2_touch_time_msc`, `pivot_r2_touch_sequence`, `pivot_r2_role`, `pivot_r2_reclaimed`, `pivot_r2_gap_cross`, `pivot_r3_price`, `pivot_r3_touch_time_msc`, `pivot_r3_touch_sequence`, `pivot_r3_role`, `pivot_r3_reclaimed`, `pivot_r3_gap_cross` |
| Candle 1/2/3 `entry_attempts.tsv` | MAPPED: manifest identity/specification; contextual copies in common rows where declared | `macro_seconds`, `micro_seconds`, `point`, `tick_size` |
| Candle 1/2/3 `entry_attempts.tsv` | REPLACED: new named shared features/completeness in feature_snapshots.tsv; old semantics remain historical | `macro_complete`, `macro_pivot_complete`, `macro_band_width_points_0`, `macro_b_percent_0`, `macro_b_percent_sma_5_0`, `macro_b_percent_sma_slope_0`, `macro_b_percent_state_0`, `macro_b_percent_1`, `macro_b_percent_sma_5_1`, `macro_b_percent_sma_slope_1`, `macro_b_percent_state_1`, `macro_b_percent_2`, `macro_b_percent_sma_5_2`, `macro_b_percent_sma_slope_2`, `macro_b_percent_state_2`, `macro_b_percent_3`, `macro_b_percent_sma_5_3`, `macro_b_percent_sma_slope_3`, `macro_b_percent_state_3`, `macro_b_percent_4`, `macro_b_percent_sma_5_4`, `macro_b_percent_sma_slope_4`, `macro_b_percent_state_4`, `macro_b_percent_5`, `macro_b_percent_sma_5_5`, `macro_b_percent_sma_slope_5`, `macro_b_percent_state_5`, `macro_pivot_b_percent_0`, `macro_pivot_b_percent_sma_5_0`, `macro_pivot_b_percent_sma_slope_0`, `macro_pivot_b_percent_state_0`, `macro_pivot_b_percent_1`, `macro_pivot_b_percent_sma_5_1`, `macro_pivot_b_percent_sma_slope_1`, `macro_pivot_b_percent_state_1`, `macro_pivot_b_percent_2`, `macro_pivot_b_percent_sma_5_2`, `macro_pivot_b_percent_sma_slope_2`, `macro_pivot_b_percent_state_2`, `macro_pivot_b_percent_3`, `macro_pivot_b_percent_sma_5_3`, `macro_pivot_b_percent_sma_slope_3`, `macro_pivot_b_percent_state_3`, `macro_pivot_b_percent_4`, `macro_pivot_b_percent_sma_5_4`, `macro_pivot_b_percent_sma_slope_4`, `macro_pivot_b_percent_state_4`, `macro_pivot_b_percent_5`, `macro_pivot_b_percent_sma_5_5`, `macro_pivot_b_percent_sma_slope_5`, `macro_pivot_b_percent_state_5`, `macro_stochastic_main_line_0`, `macro_stochastic_main_line_sma_5_0`, `macro_stochastic_main_line_sma_slope_0`, `macro_stochastic_main_line_state_0`, `macro_stochastic_main_line_1`, `macro_stochastic_main_line_sma_5_1`, `macro_stochastic_main_line_sma_slope_1`, `macro_stochastic_main_line_state_1`, `macro_stochastic_main_line_2`, `macro_stochastic_main_line_sma_5_2`, `macro_stochastic_main_line_sma_slope_2`, `macro_stochastic_main_line_state_2`, `macro_stochastic_main_line_3`, `macro_stochastic_main_line_sma_5_3`, `macro_stochastic_main_line_sma_slope_3`, `macro_stochastic_main_line_state_3`, `macro_stochastic_main_line_4`, `macro_stochastic_main_line_sma_5_4`, `macro_stochastic_main_line_sma_slope_4`, `macro_stochastic_main_line_state_4`, `macro_stochastic_main_line_5`, `macro_stochastic_main_line_sma_5_5`, `macro_stochastic_main_line_sma_slope_5`, `macro_stochastic_main_line_state_5`, `macro_stochastic_signal_line_0`, `macro_stochastic_signal_line_sma_5_0`, `macro_stochastic_signal_line_sma_slope_0`, `macro_stochastic_signal_line_state_0`, `macro_stochastic_signal_line_1`, `macro_stochastic_signal_line_sma_5_1`, `macro_stochastic_signal_line_sma_slope_1`, `macro_stochastic_signal_line_state_1`, `macro_stochastic_signal_line_2`, `macro_stochastic_signal_line_sma_5_2`, `macro_stochastic_signal_line_sma_slope_2`, `macro_stochastic_signal_line_state_2`, `macro_stochastic_signal_line_3`, `macro_stochastic_signal_line_sma_5_3`, `macro_stochastic_signal_line_sma_slope_3`, `macro_stochastic_signal_line_state_3`, `macro_stochastic_signal_line_4`, `macro_stochastic_signal_line_sma_5_4`, `macro_stochastic_signal_line_sma_slope_4`, `macro_stochastic_signal_line_state_4`, `macro_stochastic_signal_line_5`, `macro_stochastic_signal_line_sma_5_5`, `macro_stochastic_signal_line_sma_slope_5`, `macro_stochastic_signal_line_state_5`, `macro_band_base_line_0`, `macro_band_base_line_slope_points_0`, `macro_band_base_line_1`, `macro_band_base_line_slope_points_1`, `macro_band_base_line_2`, `macro_band_base_line_slope_points_2`, `macro_band_base_line_3`, `macro_band_base_line_slope_points_3`, `macro_band_base_line_4`, `macro_band_base_line_slope_points_4`, `macro_band_base_line_5`, `macro_band_base_line_slope_points_5`, `micro_complete`, `micro_pivot_complete`, `micro_band_width_points_0`, `micro_b_percent_0`, `micro_b_percent_sma_5_0`, `micro_b_percent_sma_slope_0`, `micro_b_percent_state_0`, `micro_b_percent_1`, `micro_b_percent_sma_5_1`, `micro_b_percent_sma_slope_1`, `micro_b_percent_state_1`, `micro_b_percent_2`, `micro_b_percent_sma_5_2`, `micro_b_percent_sma_slope_2`, `micro_b_percent_state_2`, `micro_b_percent_3`, `micro_b_percent_sma_5_3`, `micro_b_percent_sma_slope_3`, `micro_b_percent_state_3`, `micro_b_percent_4`, `micro_b_percent_sma_5_4`, `micro_b_percent_sma_slope_4`, `micro_b_percent_state_4`, `micro_b_percent_5`, `micro_b_percent_sma_5_5`, `micro_b_percent_sma_slope_5`, `micro_b_percent_state_5`, `micro_pivot_b_percent_0`, `micro_pivot_b_percent_sma_5_0`, `micro_pivot_b_percent_sma_slope_0`, `micro_pivot_b_percent_state_0`, `micro_pivot_b_percent_1`, `micro_pivot_b_percent_sma_5_1`, `micro_pivot_b_percent_sma_slope_1`, `micro_pivot_b_percent_state_1`, `micro_pivot_b_percent_2`, `micro_pivot_b_percent_sma_5_2`, `micro_pivot_b_percent_sma_slope_2`, `micro_pivot_b_percent_state_2`, `micro_pivot_b_percent_3`, `micro_pivot_b_percent_sma_5_3`, `micro_pivot_b_percent_sma_slope_3`, `micro_pivot_b_percent_state_3`, `micro_pivot_b_percent_4`, `micro_pivot_b_percent_sma_5_4`, `micro_pivot_b_percent_sma_slope_4`, `micro_pivot_b_percent_state_4`, `micro_pivot_b_percent_5`, `micro_pivot_b_percent_sma_5_5`, `micro_pivot_b_percent_sma_slope_5`, `micro_pivot_b_percent_state_5`, `micro_stochastic_main_line_0`, `micro_stochastic_main_line_sma_5_0`, `micro_stochastic_main_line_sma_slope_0`, `micro_stochastic_main_line_state_0`, `micro_stochastic_main_line_1`, `micro_stochastic_main_line_sma_5_1`, `micro_stochastic_main_line_sma_slope_1`, `micro_stochastic_main_line_state_1`, `micro_stochastic_main_line_2`, `micro_stochastic_main_line_sma_5_2`, `micro_stochastic_main_line_sma_slope_2`, `micro_stochastic_main_line_state_2`, `micro_stochastic_main_line_3`, `micro_stochastic_main_line_sma_5_3`, `micro_stochastic_main_line_sma_slope_3`, `micro_stochastic_main_line_state_3`, `micro_stochastic_main_line_4`, `micro_stochastic_main_line_sma_5_4`, `micro_stochastic_main_line_sma_slope_4`, `micro_stochastic_main_line_state_4`, `micro_stochastic_main_line_5`, `micro_stochastic_main_line_sma_5_5`, `micro_stochastic_main_line_sma_slope_5`, `micro_stochastic_main_line_state_5`, `micro_stochastic_signal_line_0`, `micro_stochastic_signal_line_sma_5_0`, `micro_stochastic_signal_line_sma_slope_0`, `micro_stochastic_signal_line_state_0`, `micro_stochastic_signal_line_1`, `micro_stochastic_signal_line_sma_5_1`, `micro_stochastic_signal_line_sma_slope_1`, `micro_stochastic_signal_line_state_1`, `micro_stochastic_signal_line_2`, `micro_stochastic_signal_line_sma_5_2`, `micro_stochastic_signal_line_sma_slope_2`, `micro_stochastic_signal_line_state_2`, `micro_stochastic_signal_line_3`, `micro_stochastic_signal_line_sma_5_3`, `micro_stochastic_signal_line_sma_slope_3`, `micro_stochastic_signal_line_state_3`, `micro_stochastic_signal_line_4`, `micro_stochastic_signal_line_sma_5_4`, `micro_stochastic_signal_line_sma_slope_4`, `micro_stochastic_signal_line_state_4`, `micro_stochastic_signal_line_5`, `micro_stochastic_signal_line_sma_5_5`, `micro_stochastic_signal_line_sma_slope_5`, `micro_stochastic_signal_line_state_5`, `micro_band_base_line_0`, `micro_band_base_line_slope_points_0`, `micro_band_base_line_1`, `micro_band_base_line_slope_points_1`, `micro_band_base_line_2`, `micro_band_base_line_slope_points_2`, `micro_band_base_line_3`, `micro_band_base_line_slope_points_3`, `micro_band_base_line_4`, `micro_band_base_line_slope_points_4`, `micro_band_base_line_5`, `micro_band_base_line_slope_points_5` |
| Candle 1/2/3 `entry_attempts.tsv` | REPLACED: matching new clock companions under manifest clock policy | `decision_analysis_time_msc`, `decision_analysis_offset_minutes`, `macro_open_analysis_time_msc`, `macro_open_analysis_offset_minutes`, `atr_source_analysis_time_msc`, `atr_source_analysis_offset_minutes`, `pivot_s3_touch_analysis_time_msc`, `pivot_s3_touch_analysis_offset_minutes`, `pivot_s2_touch_analysis_time_msc`, `pivot_s2_touch_analysis_offset_minutes`, `pivot_s1_touch_analysis_time_msc`, `pivot_s1_touch_analysis_offset_minutes`, `pivot_pp_touch_analysis_time_msc`, `pivot_pp_touch_analysis_offset_minutes`, `pivot_r1_touch_analysis_time_msc`, `pivot_r1_touch_analysis_offset_minutes`, `pivot_r2_touch_analysis_time_msc`, `pivot_r2_touch_analysis_offset_minutes`, `pivot_r3_touch_analysis_time_msc`, `pivot_r3_touch_analysis_offset_minutes` |
| Candle 1/2/3 `trials.tsv` | MAPPED: trials.tsv, origin via attempt; lane/trial_role becomes role, entry_policy retained; exact geometry/eligibility retained | `run_id`, `trial_id`, `attempt_id`, `lane`, `rr`, `reference_entry_time_msc`, `reference_deadline_msc`, `entry_price`, `sl`, `tp`, `volume`, `eligibility` |
| Candle 1/2/3 `trials.tsv` | REPLACED: matching new clock companions under manifest clock policy | `reference_entry_analysis_time_msc`, `reference_entry_analysis_offset_minutes`, `reference_deadline_analysis_time_msc`, `reference_deadline_analysis_offset_minutes` |
| Candle 1/2/3 `execution_checks.tsv` | MAPPED: execution_checks.tsv; shared quote/request names and nullable preserved engine checks; origin/window resolved via attempt | `run_id`, `attempt_id`, `action`, `time_msc`, `sequence`, `allowed`, `reason`, `bid`, `ask`, `volume`, `entry_price`, `sl`, `tp`, `margin`, `stop_profit`, `check_retcode`, `send_retcode`, `order_ticket`, `deal_ticket`, `position_id` |
| Candle 1/2/3 `execution_checks.tsv` | REPLACED: matching new clock companions under manifest clock policy | `analysis_time_msc`, `analysis_offset_minutes` |
| Candle 1/2/3 `outcomes.tsv` | MAPPED: outcomes.tsv and linked trial/attempt; exact costs, labels, reason and clocks; duration upgraded to explicit milliseconds | `run_id`, `trial_id`, `attempt_id`, `lane`, `rr`, `status`, `broker_reason`, `entry_time_msc`, `entry_macro_open_time_msc`, `deadline_msc`, `exit_time_msc`, `observed_time_msc`, `entry_price`, `exit_price`, `sl`, `tp`, `volume`, `gross_profit`, `costs`, `net_profit`, `gross_r`, `binary_label`, `position_id`, `fill_deviation_points` |
| Candle 1/2/3 `outcomes.tsv` | REPLACED: matching new clock companions under manifest clock policy | `entry_analysis_time_msc`, `entry_analysis_offset_minutes`, `entry_macro_open_analysis_time_msc`, `entry_macro_open_analysis_offset_minutes`, `deadline_analysis_time_msc`, `deadline_analysis_offset_minutes`, `exit_analysis_time_msc`, `exit_analysis_offset_minutes`, `observed_analysis_time_msc`, `observed_analysis_offset_minutes` |
| Candle 1/2/3 `run_summary.tsv` | MAPPED: versioned manifest/seal keys, counts and policy facts; Deep counters removed | `key`, `value` |

<!-- legacy-map:end -->

## Validation And Downstream Handoff

The plan owns exact sprint gates and commands. Validate types, immutable headers,
foreign keys, source hashes, clocks, label leakage, feature prefixes and engine
geometry with existing unittest workflows and independent calculations. Native
EA compile gates require zero errors/warnings and a matching regenerated EX5.
Use real-tick export-on/off and baseline comparisons including ordered trades,
prices, volumes, SL/TP, timestamps and costs; profit totals alone are insufficient.
Record faults, feature gaps, handle/state bounds and sustained resource evidence.

The final producer handoff includes exact machine contract/source/binary/run pins,
representative evidence, legacy mapping and unresolved operational gates. Django
is outside this repository's execution. Human chart acceptance, full-history and
broker-source equivalence remain separate; this work authorizes no live rollout.
