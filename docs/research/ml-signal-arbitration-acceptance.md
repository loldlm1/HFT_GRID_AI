# ML Signal Arbitration Acceptance

**Date**: 2026-07-05
**Roadmap Phase**: Phase 2 - ML Signal Arbitration
**Status**: Draft, implementation in progress

## Scope

This phase adds deterministic signal arbitration for Strategy Tester
`ML_INFERENCE_FILTER` runs. The goal is to keep simultaneous deterministic
strategy candidates from opening multiple broker positions when they converge on
the same source context.

Accepted implementation scope:

- MQL5 Strategy Tester behavior for `ML_INFERENCE_FILTER` only.
- Python summary tooling for compact arbitration evidence.
- Compact documentation and acceptance evidence.
- Fresh Strategy Tester smoke evidence after implementation.

Out of scope:

- Live deployment approval.
- `ML_INFERENCE_SHADOW` behavior changes.
- Feature Schema V2, ONNX, multi-symbol research, or dynamic `1:n` targets.
- Any weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.

## Accepted Arbitration Contract

Arbitration runs only after an otherwise deterministic entry candidate has:

- passed deterministic entry trigger and confirmation checks,
- passed existing broker/risk admission preparation,
- passed `ML_INFERENCE_FILTER` classifier admission.

The selected candidate remains subject to the existing broker-send path. ML does
not create trades, resize lots, alter SL/TP, bypass broker/risk gates, or affect
live deployment.

Candidate group identity:

- `symbol`
- `direction`
- `source_extremum_slot`
- `source_extremum_time`
- `source_extremum_is_peak`
- `source_extremum_price`
- same activation moment

Ranking policy:

1. Highest classifier score.
2. Highest regressor score.
3. Stable strategy priority `S1 > S2 > S3`.

Non-selected candidates:

- are locally closed without broker send,
- use terminal reason `ML_ARBITRATION_BLOCKED`,
- must not produce broker-confirmed outcomes,
- are counted separately from `ML_FILTER_BLOCKED`.

Single-candidate groups:

- pass without being blocked,
- are counted in summary evidence.

The old pre-arbitration run data is not required and should not be reused as
Phase 2 acceptance evidence.

## Arbitration Artifact Schema

Planned file:

`DeterministicSignalML\shadow_runs\<shadow_run_id>\arbitration_decisions.tsv`

Planned columns:

- `schema_version`
- `shadow_run_id`
- `export_id`
- `model_id`
- `arbitration_group_id`
- `selected_signal_id`
- `signal_id`
- `source_key`
- `source_attempt_index`
- `symbol`
- `strategy_id`
- `strategy_label`
- `direction`
- `source_type`
- `source_extremum_slot`
- `source_extremum_time`
- `source_extremum_is_peak`
- `source_extremum_price`
- `activation_time`
- `classifier_score`
- `regressor_score`
- `threshold_probability`
- `rank_position`
- `rank_reason`
- `arbitration_action`
- `arbitration_reason`

`arbitration_action` values:

- `SELECTED`
- `BLOCKED`
- optional future `OBSERVED`

`arbitration_reason` values should stay compact and machine-readable, for
example:

- `single_candidate`
- `highest_classifier_score`
- `classifier_tie_regressor_score`
- `score_tie_strategy_priority`
- `selected_candidate_invalid`

## Summary Counters

Planned `shadow_summary.tsv` additions:

- `arbitration_group_rows`
- `arbitration_single_candidate_groups`
- `arbitration_multi_candidate_groups`
- `arbitration_selected_rows`
- `arbitration_blocked_rows`
- `arbitration_classifier_tie_rows`
- `arbitration_regressor_tie_rows`
- `arbitration_strategy_tie_break_rows`

Python summary tooling must distinguish:

- `ML_FILTER_BLOCKED`: classifier/model/feature admission block.
- `ML_ARBITRATION_BLOCKED`: FILTER-allowed candidate lost to another candidate
  in the same arbitration group.

Backward compatibility:

- Existing filter run folders without arbitration artifacts should remain
  summarizable by default.
- New strict validation should require arbitration evidence only when an
  explicit `--require-arbitration` flag is used.

## Planned Smoke Validation

After MQL5 and Python implementation:

```bash
.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>" \
  --require-arbitration
```

Expected evidence:

- XAUUSD short Strategy Tester run.
- `ML_INFERENCE_FILTER`.
- All three deterministic strategies enabled.
- At least one multi-candidate group if the chosen range produces convergence.
- At most one selected broker admission per arbitration group.
- Non-selected candidates counted as `ML_ARBITRATION_BLOCKED`.

If the first smoke range has no multi-candidate group, the run can validate file
shape and counters but cannot complete behavioral acceptance. A second smoke
range should then be selected before Phase 2 is accepted.

## Long Run Policy

A long XAUUSD run should be generated only after Phase 2 smoke validation
passes. US30 and other symbols remain Phase 5 multi-symbol research unless a
future plan changes scope.
