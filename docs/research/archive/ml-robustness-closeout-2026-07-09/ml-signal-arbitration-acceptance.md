# ML Signal Arbitration Acceptance

**Date**: 2026-07-05
**Roadmap Phase**: Phase 2 - ML Signal Arbitration
**Status**: COMPLETED_AND_ARCHIVED on 2026-07-09

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

Human-in-the-loop smoke gate command for future reruns:

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
.venv/bin/python tools/deterministic_signal_ml/deploy_model_export.py \
  --export-id xgb_test_1_export_v1 \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>" \
  --require-arbitration
```

Acceptance after that run requires either at least one multi-candidate group
with one `SELECTED` row and one or more `BLOCKED` rows, or an explicit note that
the selected smoke date range produced no multi-candidate convergence.

## Manual Smoke Attempt - 2026-07-05

User executed a short human-in-the-loop Strategy Tester run with
`ML_INFERENCE_FILTER`, `ML_Model_Export_Id=xgb_test_1_export_v1`, and
`Signal_Feature_Run_Id=test_run_1`.

Generated artifacts:

- Feature run: `DeterministicSignalML/runs/test_run_1`
- Shadow/filter run: `DeterministicSignalML/shadow_runs/shadow_test_run_1`
- Artifact date range from `shadow_summary.tsv`:
  `2026.06.04 00:00:00` to `2026.07.03 16:59:59`

Python strict summary:

```text
filter run summary PASS | run_id=shadow_test_run_1 | mode=FILTER | export_id=xgb_test_1_export_v1 | predictions=5483 | outcomes=0 | scored=0 | unavailable_rows=5483 | admission_ALLOW=0 | admission_BLOCK=5483 | arbitration_groups=0 | arbitration_SELECTED=0 | arbitration_BLOCKED=0 | export_status=OK
```

Diagnosis:

- `shadow_manifest.tsv` recorded `available=false`.
- `unavailable_reason` was
  `file_open_failed:DeterministicSignalML\model_exports\xgb_test_1_export_v1\model_manifest.tsv:5004`.
- `compare_shadow_predictions.py` correctly failed with
  `No scored shadow prediction rows found`.
- `arbitration_decisions.tsv` existed but contained only the header because no
  candidate reached scored FILTER-allowed arbitration.

Result:

- This run validates that files were written, but it is not Phase 2 behavioral
  acceptance evidence.
- The failure was a runtime export deployment prerequisite issue, not an
  arbitration scorer parity result.

Corrective action completed:

- Local export `xgb_test_1_export_v1` validates as `mt5_runtime_ready=true`.
- `deploy_model_export.py` was added to validate and copy the export to MT5
  Common Files.
- The export was deployed to:
  `DeterministicSignalML/model_exports/xgb_test_1_export_v1`.

Follow-up from this failed attempt:

- The same short XAUUSD Strategy Tester smoke was rerun after deploying the
  export.
- The validated rerun is recorded below.

## Validated Smoke Rerun - 2026-07-05

User reran the short human-in-the-loop Strategy Tester smoke with the deployed
`xgb_test_1_export_v1` export available from MT5 Common Files.

Generated artifacts:

- Feature run: `DeterministicSignalML/runs/test_run_1`
- Shadow/filter run: `DeterministicSignalML/shadow_runs/shadow_test_run_1`
- Artifact date range from `shadow_summary.tsv`:
  `2026.06.04 00:00:00` to `2026.07.03 16:59:59`

Runtime manifest:

- `mode=FILTER`
- `available=true`
- `model_id=xgb_test_1`
- `dataset_id=test_dataset_1`
- `feature_schema_version=1`
- `encoded_feature_count=49`
- `classifier_tree_count=31`
- `regressor_tree_count=30`
- `threshold_probability=0.55000000`

Strict summary:

```text
filter run summary PASS | run_id=shadow_test_run_1 | mode=FILTER | export_id=xgb_test_1_export_v1 | predictions=5329 | outcomes=208 | scored=5329 | unavailable_rows=0 | recommendation_ALLOW=355 | recommendation_BLOCK=4974 | admission_ALLOW=355 | admission_BLOCK=4974 | arbitration_groups=208 | arbitration_multi_groups=112 | arbitration_SELECTED=208 | arbitration_BLOCKED=147 | export_status=OK
```

Python/MQL5 scorer comparison:

```text
shadow prediction comparison PASS | rows=5329 | classifier_max_abs_error=4.99940822074e-09 | classifier_mean_abs_error=2.37523134669e-09 | decision_agreement=1 | regressor_max_abs_error=4.998499999325778e-09
```

Arbitration integrity checks:

- Arbitration groups: `208`
- Single-candidate groups: `96`
- Multi-candidate groups: `112`
- `SELECTED` rows: `208`
- `BLOCKED` rows: `147`
- Groups with more than one selected row: `0`
- Groups without a selected row: `0`
- Candidate-count distribution: `96` groups with one candidate, `77` with two,
  and `35` with three.
- Selected strategy counts: `S1=95`, `S2=71`, `S3=42`
- Feature/outcome export rows: `208` features and `208` outcomes.
- Terminal outcomes from selected rows: `TP=148`, `SL=60`

Result:

- Phase 2 short XAUUSD FILTER smoke acceptance is `PASS`.
- This validates runtime model loading, MQL5/Python scorer parity, FILTER
  scored rows, arbitration artifact generation, one selected candidate per
  group, and separate classifier filter versus arbitration block counters.
- A long XAUUSD run should be generated only if the next phase needs robust
  post-arbitration evidence.

## Long Run Policy

A long XAUUSD run should be generated only after Phase 2 smoke validation
passes. US30 and other symbols remain Phase 5 multi-symbol research unless a
future plan changes scope.
