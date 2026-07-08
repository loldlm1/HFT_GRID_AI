# ML Pattern Audit Contract

**Date**: 2026-07-06
**Roadmap Phase**: Phase 3 follow-up
**Status**: CONTRACT_DEFINED

## Purpose

Pattern Audit is a research-only layer for validating deterministic signal
feature semantics before more ML target work. It uses DuckDB on the built
`training_matrix.parquet` dataset and must not alter trading decisions.

The audit answers:

- Do feature combinations exist exactly as expected?
- Do they have enough support across chronological splits?
- Are apparent patterns concentrated in one short regime?
- Can selected offline matches be reproduced in Strategy Tester by `signal_id`
  or `source_key`?

It does not approve runtime FILTER, live trading, ONNX export, or manual pattern
promotion.

## Pattern Lanes

Automatic pattern generation is bounded and uses controlled lanes mapped to
schema v3 columns.

| Lane | Columns | Notes |
| --- | --- | --- |
| Direction | `direction` | Bullish/bearish support is mandatory for promotion claims. |
| Structure | `source_structure_type`, `opposite_structure_type`, `same_previous_structure_type` | Tokens are categorical and must not be treated as ordinal values. |
| Fibonacci | `sl_fib_band`, `entry_fib_band` | Raw Fibonacci values can be used for range checks later, but first audit uses bands. |
| Macro slope/alignment | `macro_h1_live_dir`, `macro_h4_live_dir`, `macro_d1_live_dir`, `entry_direction_macro_alignment`, `macro_alignment_score` | These describe slope/alignment, not calendar time buckets. |
| Chain score | `low_chain_score_3`, `low_chain_score_5`, `low_chain_score_10`, `high_chain_score_3`, `high_chain_score_5`, `high_chain_score_10` | Extreme values such as `-3` or `3` can represent continuous lower/higher behavior. |
| Previous candle | `prev_body_ratio`, `prev_upper_wick_ratio`, `prev_lower_wick_ratio`, `prev_close_location`, `prev_candle_dir` | Numeric ratios should be bucketed conservatively for pattern scans. |
| Context/session | `recent_m1_range_points`, `recent_m1_body_ratio_avg`, `recent_m1_directional_balance`, `entry_spread_points`, `spread_to_recent_range_ratio`, `entry_session_bucket` | Diagnostic only unless support and final-holdout stability are strong. |

Default automatic combinations should use `2` to `5` conditions. Manual
pattern IDs can be requested for visual review, but manual selection never
implies runtime eligibility.

## Output Files

Pattern audit outputs are generated under an ignored folder:

```text
artifacts/pattern_audits/<audit_id>/
```

Required files:

- `pattern_catalog.tsv`
- `pattern_summary.tsv`
- `pattern_matches.tsv`
- `pattern_period_metrics.tsv`
- `pattern_audit_report.md`
- `pattern_audit.json`

Generated artifacts stay out of git. Evidence documents only compact counts,
selected pattern IDs, and warnings.

## `pattern_matches.tsv`

Each match row must carry the full condition text so a human can inspect the
pattern without opening model artifacts.

Required columns:

```text
audit_id
pattern_id
pattern_label
pattern_source
selected_for_visual
condition_count
conditions_text
signal_id
source_key
source_attempt_index
symbol
strategy_label
direction
entry_time
source_time
terminal_time
target_terminal_reason
target_profit_r
net_profit
split_name
```

Example `conditions_text`:

```text
direction=BEARISH; source_structure_type=HL; opposite_structure_type=LL; macro_h1_live_dir=-1; high_chain_score_3=-3; sl_fib_band=61.8_100; entry_fib_band=61.8_100
```

## `pattern_period_metrics.tsv`

Pattern robustness adds monthly and quarterly diagnostics for every catalog
pattern. These metrics are offline evidence only and do not change Strategy
Tester playback.

Required columns:

```text
audit_id
pattern_id
pattern_label
selected_for_visual
period_type
period_id
rows
win_rate
mean_r
net_r
max_drawdown_r
positive_net
```

`period_type` is either `month` or `quarter`. `period_id` is formatted as
`YYYY-MM` or `YYYY-Qn`.

`pattern_summary.tsv` also includes robustness fields:

```text
positive_month_count
negative_month_count
worst_month_net_r
quarter_count
positive_quarter_count
negative_quarter_count
worst_quarter_net_r
robustness_status
robust_warning_codes
```

Robustness statuses:

| Status | Meaning |
| --- | --- |
| `ROBUST_PASS` | Pre-final and final holdout are positive and calendar coverage meets the configured month/quarter guards. |
| `ROBUST_REVIEW` | Core evidence is positive, but one or more calendar guards require human review. |
| `ROBUST_FAIL` | Core support, pre-final, final holdout, or stability requirements fail. |

## Guardrail Statuses

| Status | Meaning |
| --- | --- |
| `AUDIT_PASS` | Enough support and split stability for continued research review. |
| `REVIEW` | Interesting pattern but not promotable without more support or playback evidence. |
| `RARE_BUCKET_IGNORE` | Too few rows or too much bucket sparsity. |
| `FINAL_HOLDOUT_FAIL` | Pre-final pattern does not survive the final holdout. |
| `DATA_AMBIGUITY` | Offline pattern cannot be cleanly matched to Strategy Tester facts. |

Pattern ranking uses pre-final evidence only. Final holdout remains approval
evidence and may reject a pattern, but it must not be used to mine or tune a
pattern.

## Strategy Tester Playback

Strategy Tester playback is research-only. The EA should load selected matches
from Common Files, observe whether expected `signal_id` or `source_key` hits
occur, and optionally draw visual markers in tester visual mode.

Recommended minimal inputs:

- `Enable_Pattern_Audit_Overlay`
- `Pattern_Audit_Set_Id`

The EA must not create, block, resize, close, or reprioritize trades based on
pattern audit data.

Playback outputs should include a compact `pattern_tester_observations.tsv`
with expected/observed status so Python can compare it against
`pattern_matches.tsv`.
