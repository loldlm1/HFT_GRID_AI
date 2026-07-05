# ML Signal Arbitration Acceptance

**Date**: 2026-07-05
**Roadmap Phase**: Phase 2 - ML Signal Arbitration
**Status**: Implementation compile-clean; Strategy Tester smoke pending human-in-loop run

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

Hand-worked ranking examples:

- `S2 classifier=0.81` beats `S1 classifier=0.79` even though `S1` has higher
  strategy priority.
- If `S1 classifier=0.80 regressor=1.4` and `S3 classifier=0.80 regressor=1.1`,
  `S1` wins by regressor score.
- If classifier and regressor scores tie, `S1` wins over `S2`, and `S2` wins
  over `S3`.
- A missing regressor score never outranks a valid higher regressor score when
  classifier scores tie.

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

## Implementation Evidence - 2026-07-05

Completed commits:

- `28f64ff docs: plan ml signal arbitration`
- `483b56b docs: define ml signal arbitration contract`
- `f527080 feat: add ml arbitration candidate grouping`
- `ff4de4d feat: arbitrate ml filter signal admissions`
- `7ba86b9 feat: record ml arbitration decisions`

Validation completed:

- MetaEditor real compile via `tools/mt5/compile_mt5.py --mode compile`.
- Compile log:
  `logs/compile/ml-arbitration-phase2-build.log`.
- Compile result: `0 errors, 0 warnings`.
- Generated EX5:
  `HFT_Grid_AI.ex5`, 507642 bytes, timestamp `2026-07-05 12:31:48 -0400`.
- Python validation:
  `python3 -m py_compile tools/deterministic_signal_ml/summarize_filter_run.py`.
- Fixture validation:
  `summarize_filter_run.py --require-arbitration` passed on a minimal
  temporary run folder with one `ALLOW` prediction and one `SELECTED`
  arbitration row.
- Model export validation:
  `xgb_test_1_export_v1`, model `xgb_test_1`, dataset `test_dataset_1`,
  49 encoded features, 31 classifier trees, 30 regressor trees,
  `mt5_runtime_ready=true`.
- The validated export was copied to Wine Common Files under
  `DeterministicSignalML/model_exports/xgb_test_1_export_v1`.

Strategy Tester smoke status:

- Attempted an agentic non-visual XAUUSD M1 FILTER smoke using the existing
  tester preset
  `MQL5/Profiles/Tester/HFT_Grid_AI.XAUUSD.M1.20260604_20260704.400.ini`.
- The preset has all three deterministic strategies enabled,
  `ML_Inference_Mode=2`, and `ML_Model_Export_Id=xgb_test_1_export_v1`.
- `terminal64.exe /portable /config:<temp config>` opened the terminal under
  Wine but did not create a tester report or a
  `DeterministicSignalML/shadow_runs/<shadow_run_id>` folder.
- The orphaned terminal process from the CLI attempt was closed.
- Because no `shadow_run` was generated, Phase 2 runtime acceptance remains
  pending human-in-the-loop Strategy Tester execution.

Required human-in-the-loop smoke gate:

```bash
.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>" \
  --require-arbitration
```

Acceptance after that run requires either at least one multi-candidate group
with one `SELECTED` row and one or more `BLOCKED` rows, or an explicit note that
the selected smoke date range produced no multi-candidate convergence.

## Long Run Policy

A long XAUUSD run should be generated only after Phase 2 smoke validation
passes. US30 and other symbols remain Phase 5 multi-symbol research unless a
future plan changes scope.
