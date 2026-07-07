# ML Feature Schema V2 Acceptance

**Date**: 2026-07-06
**Roadmap Phase**: Phase 3 - Feature Schema V2
**Status**: REJECT_WITH_FOLLOW_UP

## Scope

This phase replaces the active deterministic signal ML feature contract with
schema version 2, then validates whether the new feature set can produce a
robust positive XAUUSD threshold without overfitting.

Accepted implementation scope:

- MQL5 feature export and shadow-scorer feature extraction.
- Python schema validation, dataset build, training, export, parity, and
  comparison tooling.
- Fresh human-in-the-loop Strategy Tester raw export for XAUUSD calendar year
  2025.
- Runtime export/parity validation only if the research acceptance gate passes.

Out of scope:

- Live deployment approval.
- ONNX work.
- Multi-symbol research.
- Dynamic `1:n` target modeling.
- Any weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.

## Frozen Schema V1 Rejection Baseline

The current long XAUUSD schema v1 baseline is frozen as the rejection baseline
for Phase 3 comparison:

- Dataset ID: `xauusd_2025_dataset_1`
- Model ID: `xauusd_2025_xgb_1`
- Source run IDs: `test_run_1`
- Config IDs: `cfg_12150440574703104362`
- Feature schema version: `1`
- Dataset training matrix rows: `36862`
- Model train rows: `29490`
- Model holdout rows: `7372`
- Encoded features: `69`
- Holdout classifier ROC AUC: `0.495134`
- Holdout classifier precision/recall/F1 at default decision boundary:
  `0.000000` / `0.000000` / `0.000000`
- Holdout regressor correlation: `0.006745`
- Threshold recommendation: none
- Threshold rows selected at thresholds `>= 0.50`: `0`

Result:

- The v1 long baseline is not a promoted model.
- No v1 runtime export is approved from this baseline.
- Phase 3 must show material improvement over this frozen rejection baseline
  before creating a schema v2 runtime export.

## Schema V2 Feature Contract

Schema v2 features must be available at entry time. They must not use terminal
outcomes, post-entry bars, blocked-result information, future macro bars, or
final-holdout tuning.

Required structure features:

- `source_structure_type`: categorical token for the source extremum structure.
- `opposite_structure_type`: categorical token for the opposite extremum used
  by the execution range.
- `same_previous_structure_type`: categorical token for the previous same-type
  extremum used by the execution range.

Required previous closed candle features from `DETERMINISTIC_BASE_TIMEFRAME`
shift `1`:

- `prev_body_ratio`: absolute body divided by candle range.
- `prev_upper_wick_ratio`: upper wick divided by candle range.
- `prev_lower_wick_ratio`: lower wick divided by candle range.
- `prev_close_location`: close location within candle range, normalized `0..1`.
- `prev_candle_dir`: categorical direction token such as `BULL`, `BEAR`, or
  `DOJI`.

Required strategy-depth and directional features:

- `strategy_delay_period`: S1/S2/S3 depth delay, expected `3`, `5`, or `10`.
- `confirmation_timeframe_minutes`: macro confirmation timeframe, expected
  `3`, `5`, or `10`.
- `entry_direction_macro_alignment`: entry direction aligned/opposed/flat
  against the strategy confirmation timeframe slope.
- `macro_alignment_score`: H1/H4/D1 alignment score against entry direction.

Secondary ablation candidates:

- `source_intern_fib_raw`
- `source_extern_fib_raw`
- `source_extern_structures_broken`
- `prev_candle_shape`
- `session_bucket`

Structure type tokens must be stable and categorical, for example `HH`, `HL`,
`LH`, `LL`, and `EQ`. They must not be treated as ordinal numeric values.

S1, S2, and S3 are one signal archetype at increasing depth:

- S1: delay `3`, M3 macro confirmation.
- S2: delay `5`, M5 macro confirmation.
- S3: delay `10`, M10 macro confirmation.

The default promotion target is a global depth-aware model. Per-strategy or
per-direction thresholds/models require stronger support counts and segment
evidence than the global policy.

## XAUUSD 2025 Run Contract

Generate the schema v2 raw export with human-in-the-loop Strategy Tester:

- Symbol: XAUUSD
- Date range: full 2025 calendar year
- Start: `2025-01-01 00:00:00`
- End: exclusive `2026-01-01 00:00:00` when supported, or inclusive
  `2025-12-31 23:59:59` if Strategy Tester requires an inclusive end.
- Runtime mode: `ML_INFERENCE_DISABLED`
- Feature export: enabled
- Strategies: S1, S2, and S3 enabled
- Recommended run ID: `xauusd_2025_schema_v2_run_1`
- Recommended dataset ID: `xauusd_2025_schema_v2_dataset_1`
- Recommended model ID: `xauusd_2025_schema_v2_xgb_1`

Generated files remain outside git and should be summarized only by row counts,
paths, final status lines, and selected warnings.

## Promotion Gate

Schema v2 can advance to runtime export only when all required gates pass:

- Fresh XAUUSD schema v2 export covers the 2025 calendar-year range.
- Dataset build has no duplicate feature/outcome IDs.
- Dataset build has no unexplained missing outcomes.
- Feature invalid rows are zero or bounded and explained.
- Threshold selection uses threshold-selection rows or pre-final-holdout
  out-of-fold predictions, never final holdout rows.
- Final holdout remains approval evidence only.
- Candidate comparison shows material improvement over the frozen v1 rejection
  baseline.
- A positive threshold candidate exists on threshold-selection evidence.
- Final holdout at the selected threshold remains positive after costs.
- Threshold-selection selected rows are `>= 100`.
- Final-holdout selected rows are `>= 50`.
- Important strategy-depth segments have `>= 15` selected rows, or the result
  remains research-only with no promotion claim.
- Bullish and bearish selected rows each have `>= 20` rows, or the result
  remains research-only with no promotion claim.
- No unresolved critical regression remains for S1, S2, S3, bullish, bearish,
  source type, or strategy-direction segments.
- Rare-bucket, high-importance concentration, final-holdout reuse, leakage, and
  no-variation warnings are resolved or explicitly accepted as non-blocking.

If the research gate fails, Phase 3 must create a follow-up Phase 3 `$planner`
plan before additional feature iteration. Do not move to ONNX, multi-symbol
research, dynamic targets, or live rollout.

## Runtime Gate

Runtime export is conditional on research acceptance.

If a runtime export is produced for a promoted follow-up schema:

- Artifact validation must record the promoted feature schema version.
- The export must include a positive threshold policy.
- The deployed Common Files copy must validate.
- SHADOW mode must produce scored rows and Python/MQL5 parity within accepted
  tolerance.
- FILTER mode must preserve broker/risk gate order and Phase 2 arbitration
  counters.
- Invalid feature rows must be zero or explicitly explained.
- No live deployment approval is implied.

## Sprint 1 Validation

Sprint 1 is documentation-only.

Validated inputs:

- `artifacts/datasets/xauusd_2025_dataset_1/dataset_report.md`
- `artifacts/datasets/xauusd_2025_dataset_1/dataset_manifest.json`
- `artifacts/models/xauusd_2025_xgb_1/validation_report.md`
- `artifacts/models/xauusd_2025_xgb_1/model_manifest.json`

Result:

- V1 rejection baseline is frozen for comparison.
- Schema v2 contract and gates are defined.
- MQL5 and Python implementation remains pending.

## Sprint 2 Validation

Sprint 2 updates the active MQL5 feature export and shadow-scorer feature
contract to schema v2.

Changed files:

- `services/trading_management/deterministic_strategy_config.mqh`
- `services/trading_signals/deterministic_signal_statistics_export.mqh`
- `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`

Implemented:

- `DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 2`
- `ML_SHADOW_PHASE1_SCHEMA_VERSION = 2`
- Schema v2 `signal_features.tsv` columns:
  - `source_structure_type`
  - `opposite_structure_type`
  - `same_previous_structure_type`
  - `strategy_delay_period`
  - `confirmation_timeframe_minutes`
  - `entry_direction_macro_alignment`
  - `macro_alignment_score`
  - `prev_body_ratio`
  - `prev_upper_wick_ratio`
  - `prev_lower_wick_ratio`
  - `prev_close_location`
  - `prev_candle_dir`
- Matching schema v2 `shadow_predictions.tsv` columns for runtime parity
  evidence.
- SHADOW numeric/category source-column mapping for schema v2 feature maps.

Static validation:

- `signal_features.tsv` header: `38` columns.
- `shadow_predictions.tsv` header: `50` columns.
- V2 feature columns are present in both headers.
- No broker admission, order-send, lot sizing, SL/TP, license, session,
  spread, margin, protection, magic-number, or broker reconciliation behavior
  was intentionally changed.

Compile status:

- MetaEditor compile is deferred to Sprint 4 after Python schema/tooling edits,
  per the phase plan.

## Sprint 3 Validation

Sprint 3 updates the active Python dataset, reporting, training, robustness
segment, comparison, export-map, and shadow-normalization tooling for schema v2.

Changed files:

- `tools/deterministic_signal_ml/schema_contract.py`
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/segment_metrics.py`
- `tools/deterministic_signal_ml/train_model.py`
- `tools/deterministic_signal_ml/compare_model_candidates.py`

Implemented:

- `SUPPORTED_SCHEMA_VERSION = 2`
- Active feature/model feature columns include all required schema v2 fields.
- Numeric/categorical classifications include structure, depth, macro
  alignment, and previous-candle fields.
- Dataset builder writes schema v2 fields into `features`, `outcomes`, and
  `training_matrix`.
- Dataset manifest records both `phase1_schema_version=2` and
  `feature_schema_version=2`.
- Dataset report includes strategy-depth, structure-type, previous-candle, and
  macro-alignment summaries.
- Training rejects datasets whose manifest schema version or feature columns do
  not match the active schema v2 contract.
- Candidate comparison marks differing `schema_version` values as
  `NOT_COMPARABLE`.
- Export feature-map generation and shadow prediction normalization continue to
  derive source columns from the schema v2 contract.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`: PASS.
- Temporary schema v2 fixture run built successfully:
  - Features: `4`
  - Outcomes: `4`
  - Training matrix rows: `4`
  - Encoded features / feature-map rows: `37`
  - Fixture root: `/tmp/tmp.MVpNVtpvon`
- Fixture dataset report contains:
  - `Strategy Depth Summary`
  - `Structure Type Summary`
  - `Previous Candle Summary`
  - `Macro Alignment Summary`
- Fixture manifest records `feature_schema_version=2`.
- Matching schema v1 fixture was rejected by default:
  `Unsupported schema_version in run_manifest.tsv row 1: 1`.
- `git diff --check`: PASS.

Compile status:

- MetaEditor compile remains deferred to Sprint 4.

## Sprint 4 Validation

Task 4.1 compile validation is complete.

Compile evidence:

- Command shape:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase3-schema-v2-sprint4-compile.log --mode compile --timeout 240`
- Log:
  `logs/compile/phase3-schema-v2-sprint4-compile.log`
- Result:
  `Result: 0 errors, 0 warnings, 45896 ms elapsed, cpu='X64 Regular'`
- Generated EX5:
  `HFT_Grid_AI.ex5`
- EX5 size:
  `518950` bytes
- EX5 timestamp:
  `2026-07-05 21:27:24.413641770 -0400`

Human-in-the-loop Strategy Tester configuration for Task 4.2/4.3:

- Expert: `HFT_Grid_AI.ex5`
- Symbol: `XAUUSD`
- Period: `M1`
- Date range:
  - Start: `2025-01-01 00:00:00`
  - End: exclusive `2026-01-01 00:00:00` where supported, or inclusive
    `2025-12-31 23:59:59` when Strategy Tester requires an inclusive end.
- `ML_Inference_Mode = ML_INFERENCE_DISABLED`
- `Enable_Signal_Feature_Export = true`
- `Signal_Feature_Run_Id = xauusd_2025_schema_v2_run_1`
- `Enable_Strategy_1 = true`
- `Enable_Strategy_2 = true`
- `Enable_Strategy_3 = true`
- `Strategy_Direction_Mode = BOTH_DIRECTION`
- `Signal_Concurrency_Mode = MULTIPLE_RUNNING_SIGNALS`

Expected raw export folder after the Strategy Tester run:

```text
/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs/xauusd_2025_schema_v2_run_1/
```

Expected files:

- `run_manifest.tsv`
- `signal_features.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

Post-run validation/build commands:

```bash
export DETERMINISTIC_RUNS_ROOT="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id xauusd_2025_schema_v2_run_1 \
  --dataset-id xauusd_2025_schema_v2_dataset_1 \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id xauusd_2025_schema_v2_run_1 \
  --dataset-id xauusd_2025_schema_v2_dataset_1 \
  --overwrite
```

Human-in-the-loop Strategy Tester raw export validation:

- Run ID:
  `xauusd_2025_schema_v2_run_1`
- Config ID:
  `cfg_17016375182198205791`
- Raw folder:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs/xauusd_2025_schema_v2_run_1/`
- `run_manifest.tsv`:
  `466` bytes, `16` rows, header OK.
- `signal_features.tsv`:
  `11959086` bytes, `36878` rows, `38` columns, header OK.
- `signal_outcomes.tsv`:
  `7311358` bytes, `36878` rows, `14` columns, header OK.
- `run_summary.tsv`:
  `254` bytes, `1` row, header OK.
- Raw run summary:
  - `schema_version=2`
  - `started_at=2025.01.01 00:00:00`
  - `finished_at=2025.12.31 21:57:59`
  - `feature_rows=36878`
  - `outcome_rows=36878`
  - `feature_invalid_rows=16`
  - `outcome_invalid_rows=0`
  - `export_status=OK`

Dataset validation/build:

- Validate-only command:
  `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root "$DETERMINISTIC_RUNS_ROOT" --run-id xauusd_2025_schema_v2_run_1 --dataset-id xauusd_2025_schema_v2_dataset_1 --validate-only`
- Validate-only result:
  `validation ok | runs=1 | features=36878 | outcomes=36878 | joined=36878`
- Dataset build result:
  `assembly ok | features=36878 | outcomes=36878 | training_matrix=36862`
- Dataset path:
  `artifacts/datasets/xauusd_2025_schema_v2_dataset_1/`
- Dataset files:
  - `features.parquet`: `2688008` bytes
  - `outcomes.parquet`: `1933740` bytes
  - `training_matrix.parquet`: `3647615` bytes
  - `dataset_manifest.json`: `2346` bytes
  - `dataset_quality.json`: `14493` bytes
  - `dataset_report.md`: `5513` bytes
- Dataset manifest:
  - `feature_schema_version=2`
  - `builder_version=phase3.schema_v2_dataset_builder.v1`
  - `source_run_ids=xauusd_2025_schema_v2_run_1`
  - `config_ids=cfg_17016375182198205791`
- Dataset quality:
  - `status=OK`
  - `blocking_null_feature_rows=0`
  - `duplicate_feature_ids=0`
  - `duplicate_outcome_ids=0`
  - `missing_features=0`
  - `missing_outcomes=0`
  - warnings: `1` expected warning for `16` feature rows marked invalid by
    Phase 1.

Sprint 4 result:

- PASS. Fresh XAUUSD 2025 schema v2 raw export exists, validates, and builds
  `xauusd_2025_schema_v2_dataset_1`.

## Sprint 5 Validation

Sprint 5 trained schema v2 candidates, ran hardened robustness validation, and
applied the Phase 3 research gate.

Tooling updates made during Sprint 5:

- `tools/deterministic_signal_ml/train_model.py`
  - Added `--feature-set-id` support for schema v2 ablation:
    `schema_v2_structure`, `schema_v2_structure_candle`, and
    `schema_v2_full`.
  - Model manifests now record `feature_set_id`.
- `tools/deterministic_signal_ml/validate_model_robustness.py`
  - Added `--allow-missing-export` for research-only models before runtime
    export exists.
- `tools/deterministic_signal_ml/segment_metrics.py`
  - Allows absent thresholds so rejected models can still produce segment
    support diagnostics instead of failing.

Python validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/train_model.py`
  PASS.
- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/segment_metrics.py tools/deterministic_signal_ml/validate_model_robustness.py`
  PASS.

Trained schema v2 candidates:

| Candidate | Feature set | Encoded features | Holdout ROC AUC | Holdout F1 | Regressor corr | Threshold | OOF selected | OOF net R | Final selected | Final net R | Warnings |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `xauusd_2025_schema_v2_structure_xgb_1` | `schema_v2_structure` | 84 | 0.5017751585928488 | 0.0 | 0.00811156548088697 | none | 0 | 0.0 | 0 | 0.0 | 5 |
| `xauusd_2025_schema_v2_structure_candle_xgb_1` | `schema_v2_structure_candle` | 91 | 0.4999128817691493 | 0.0 | -0.000014364471757778179 | none | 0 | 0.0 | 0 | 0.0 | 5 |
| `xauusd_2025_schema_v2_xgb_1` | `schema_v2_full` | 95 | 0.4999128817691493 | 0.0 | 0.0010643570853138577 | 0.50 | 414 | 9.2688 | 0 | 0.0 | 3 |

Frozen v1 rejection baseline under the same robustness validator:

| Candidate | Encoded features | Holdout ROC AUC | Holdout F1 | Regressor corr | Threshold | OOF selected | OOF net R | Final selected | Final net R | Warnings |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `xauusd_2025_xgb_1` | 69 | 0.4951344154163595 | 0.0 | 0.006745125078834843 | none | 0 | 0.0 | 0 | 0.0 | 6 |

Gate decision:

- `xauusd_2025_schema_v2_xgb_1` shows a small positive
  walk-forward out-of-fold threshold-selection result at `0.50`, but that
  threshold selects `0` rows in final holdout.
- Structure-only and structure+candle ablations produce no eligible threshold.
- S1/S2/S3, bullish/bearish, source type, and strategy-depth-direction final
  holdout segments all have `0` selected rows under the candidate policies.
- The required final-holdout selected-row, profitability, and segment-support
  gates fail.
- No runtime export, deployment, SHADOW parity, or FILTER validation is
  approved from these candidates.

Result:

- `REJECT_WITH_FOLLOW_UP`
- Follow-up Phase 3 plan:
  `docs/plans/ml-feature-schema-v2-follow-up-plan.md`
- Sprint 6 and Sprint 7 of the first-attempt plan are skipped because runtime
  export is conditional on Sprint 5 acceptance.

## Follow-Up Sprint 1 Validation

Follow-up Sprint 1 added offline score-distribution and time-bucket diagnostics
for the rejected first-attempt models.

Changed files:

- `tools/deterministic_signal_ml/score_diagnostics.py`

Generated local diagnostics:

- `artifacts/models/xauusd_2025_xgb_1/diagnostics/`
- `artifacts/models/xauusd_2025_schema_v2_structure_xgb_1/diagnostics/`
- `artifacts/models/xauusd_2025_schema_v2_structure_candle_xgb_1/diagnostics/`
- `artifacts/models/xauusd_2025_schema_v2_xgb_1/diagnostics/`

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/score_diagnostics.py`:
  PASS.
- Score diagnostics ran for v1 baseline and all three schema v2 first-attempt
  candidates.

Score distribution summary:

| Candidate | Threshold | OOF q99 | OOF max | OOF selected | OOF net R | Final q99 | Final max | Final selected | Final all below threshold |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `xauusd_2025_xgb_1` | 0.50 | 0.492369 | 0.526814 | 46 | -7.767 | 0.467343 | 0.469584 | 0 | true |
| `xauusd_2025_schema_v2_structure_xgb_1` | 0.50 | 0.487206 | 0.508536 | 14 | -9.2315 | 0.467541 | 0.480867 | 0 | true |
| `xauusd_2025_schema_v2_structure_candle_xgb_1` | 0.50 | 0.507467 | 0.544856 | 447 | -19.5991 | 0.467402 | 0.470788 | 0 | true |
| `xauusd_2025_schema_v2_xgb_1` | 0.50 | 0.506522 | 0.559462 | 414 | 9.2688 | 0.467402 | 0.470788 | 0 | true |

Time-bucket summary for the v2 full candidate:

- OOF selected rows occur only in:
  - `2025-04`: `17` selected, `net_r=-9.6178`
  - `2025-05`: `234` selected, `net_r=27.3839`
  - `2025-06`: `163` selected, `net_r=-8.4973`
- Final holdout months have zero selected rows:
  - `2025-10`: max score `0.4707875848`
  - `2025-11`: max score `0.4707875848`
  - `2025-12`: max score `0.4707875848`

Root-cause summary:

- The first-attempt schema v2 failure is primarily probability compression plus
  temporal instability.
- The only positive OOF result is concentrated in May 2025 and does not
  generalize to the final holdout period.
- The final holdout scores for every first-attempt candidate are entirely below
  the selected/default threshold, so runtime FILTER would have no eligible
  rows.
- No first-attempt candidate is runtime-ready.

## Follow-Up Sprint 2 Validation

Follow-up Sprint 2 added research-only threshold, calibration, and rank-policy
diagnostics.

Changed files:

- `tools/deterministic_signal_ml/threshold_policy_diagnostics.py`

Generated local diagnostics:

- `artifacts/models/xauusd_2025_schema_v2_structure_xgb_1/diagnostics/threshold_policy_diagnostics.*`
- `artifacts/models/xauusd_2025_schema_v2_structure_candle_xgb_1/diagnostics/threshold_policy_diagnostics.*`
- `artifacts/models/xauusd_2025_schema_v2_xgb_1/diagnostics/threshold_policy_diagnostics.*`

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/threshold_policy_diagnostics.py`:
  PASS.
- Threshold policy diagnostics ran for all three schema v2 first-attempt
  candidates.
- Calibration was fitted only on pre-final OOF rows and then evaluated on final
  holdout.
- Rank/quantile score cutoffs were chosen only from pre-final OOF rows and then
  evaluated on final holdout.

Best pre-final policies:

| Candidate | Best pre-final policy | Pre-final selected | Pre-final net R | Final selected | Final mean R | Final net R | Final pass |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `xauusd_2025_schema_v2_structure_xgb_1` | none | 0 | 0.0 | 0 | n/a | 0.0 | false |
| `xauusd_2025_schema_v2_structure_candle_xgb_1` | `raw_ge_0.51` | 173 | 1.2068 | 0 | n/a | 0.0 | false |
| `xauusd_2025_schema_v2_xgb_1` | `calibrated_ge_0.49` | 124 | 27.9714 | 0 | n/a | 0.0 | false |

Lower raw thresholds are not a solution:

- For the v2 full candidate, `raw_ge_0.45` selects `7372` final-holdout rows
  but has `final_net_r=-567.485`.
- For the v2 full candidate, `raw_ge_0.47` selects `27` final-holdout rows but
  has `final_net_r=-2.0894`.
- Similar lower-threshold behavior appears in the structure and
  structure+candle variants.

Decision:

- `REQUIRE_SCHEMA_V3_FEATURE_ITERATION`
- The existing schema v2 dataset is useful evidence, but it is not sufficient
  to continue toward runtime export.
- Calibration and rank/quantile policies do not fix the final-holdout collapse.
- The next sprint should define a minimal schema iteration focused on
  pre-entry regime/context features, not on threshold tuning.

## Follow-Up Sprint 3 Validation

Follow-up Sprint 3 implemented the minimal schema v3 feature iteration and
compiled the EA. The sprint cannot fully complete dataset regeneration until a
human-in-the-loop Strategy Tester run creates the new raw export.

Changed files:

- `services/trading_signals/deterministic_signal_statistics_export.mqh`
- `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- `tools/deterministic_signal_ml/schema_contract.py`
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/train_model.py`
- `tools/deterministic_signal_ml/README.md`

Implemented:

- `DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 3`
- `ML_SHADOW_PHASE1_SCHEMA_VERSION = 3`
- `SUPPORTED_SCHEMA_VERSION = 3`
- New pre-entry context features:
  - `recent_m1_range_points`
  - `recent_m1_body_ratio_avg`
  - `recent_m1_directional_balance`
  - `entry_spread_points`
  - `spread_to_recent_range_ratio`
  - `entry_session_bucket`
- New training feature-set IDs:
  - `schema_v3_full`
  - `schema_v3_no_context`
  - `schema_v3_structure`
  - `schema_v3_structure_candle`

Leakage boundary:

- Recent M1 features use only closed `DETERMINISTIC_BASE_TIMEFRAME` bars from
  shift `1`.
- Spread features use the current pre-entry symbol spread and its ratio to the
  recent closed-bar range.
- Session bucket is derived from the pre-entry server-time hour.
- No terminal outcome, post-entry bar, blocked-result status, future macro bar,
  or final-holdout information is used.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`: PASS.
- Static contract check:
  - `signal_features.tsv` header: `44` columns.
  - Python `FEATURE_COLUMNS`: `44` columns.
  - `shadow_predictions.tsv` header: `56` columns.
  - Python `MODEL_FEATURE_COLUMNS`: `35` columns, all present in SHADOW output.
- Dataset SQL smoke:
  - `features=0`
  - `outcomes=0`
  - `training_matrix=0`
  - `training_matrix_columns=55`
  - Required schema v3 columns present.
- `git diff --check`: PASS.
- MetaEditor compile:
  - Command:
    `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase3-schema-v3-followup-sprint3-compile.log --mode compile --timeout 240`
  - Result: `0 errors, 0 warnings`.

Sprint 3 handoff:

- Follow-up Sprint 4 was blocked until the schema v3 raw export and dataset
  existed.
- Recommended run ID: `xauusd_2025_schema_v3_run_1`
- Recommended dataset ID: `xauusd_2025_schema_v3_dataset_1`
- Recommended model IDs:
  - `xauusd_2025_schema_v3_xgb_1`
  - `xauusd_2025_schema_v3_no_context_xgb_1`
- Strategy Tester configuration remains unchanged except for the active schema:
  XAUUSD full calendar year 2025, ML disabled, feature export enabled, S1/S2/S3
  enabled.

## Follow-Up Sprint 4 Validation

Follow-up Sprint 4 validated the schema v3 raw export, built the schema v3
dataset, trained the minimum candidate set, and ran the robustness gate.

Raw export:

- Run ID: `xauusd_2025_schema_v3_run_1`
- Source folder:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs/xauusd_2025_schema_v3_run_1/`
- Validation command:
  `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root /home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs --run-id xauusd_2025_schema_v3_run_1 --dataset-id xauusd_2025_schema_v3_dataset_1 --validate-only`
- Result:
  - `features=36878`
  - `outcomes=36878`
  - `joined=36878`
  - Warning: `22` feature rows were marked invalid by Phase 1.

Dataset:

- Dataset ID: `xauusd_2025_schema_v3_dataset_1`
- Builder: `phase3.schema_v3_dataset_builder.v1`
- Feature schema version: `3`
- Row counts:
  - `features=36878`
  - `outcomes=36878`
  - `training_matrix=36856`
- Dataset quality: `OK`
- Blocking null feature rows: `0`

Trained candidates:

| Candidate | Feature set | Encoded features | Holdout ROC AUC | Holdout F1 | Regressor corr | Threshold | Pre-final selected | Pre-final net R | Final selected | Final net R | Warnings |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `xauusd_2025_schema_v3_xgb_1` | `schema_v3_full` | 104 | 0.5055827209483965 | 0.0 | 0.02349312001336015 | 0.50 | 93 | 8.7797 | 0 | 0.0 | 4 |
| `xauusd_2025_schema_v3_no_context_xgb_1` | `schema_v3_no_context` | 95 | 0.49794951891323064 | 0.0 | 0.014481507475988191 | none | 0 | 0.0 | 0 | 0.0 | 5 |

Diagnostics:

- `xauusd_2025_schema_v3_xgb_1`
  - OOF threshold `0.50` selected `93` rows with `net_profit_r=8.7797`.
  - Final holdout max score was `0.4903321266`; final selected rows were `0`.
  - Best pre-final policy was `top_0.500%_prefinal_cutoff`, selecting `133`
    pre-final rows with `net_profit_r=4.3974`, but `0` final rows.
  - Final pass policies: `0`.
- `xauusd_2025_schema_v3_no_context_xgb_1`
  - OOF threshold `0.50` selected `315` rows, but final holdout max score was
    `0.4674401581`; final selected rows were `0`.
  - Best pre-final policy was `top_2.000%_prefinal_cutoff`, selecting `473`
    pre-final rows with `net_profit_r=7.3214`, but `0` final rows.
  - Final pass policies: `0`.

Decision:

- `REJECT_WITH_FOLLOW_UP`
- Schema v3 context features improved neither the final-holdout support nor the
  runtime eligibility gate.
- The failure remains a temporal generalization problem: pre-final selected
  evidence does not survive the final holdout.
- No runtime export, SHADOW parity, FILTER validation, ONNX work, or live
  deployment is approved from these candidates.
- Next follow-up plan:
  `docs/plans/ml-pattern-audit-follow-up-plan.md`
- Target path-label research remains planned after pattern semantics are
  audited:
  `docs/plans/ml-target-path-labels-follow-up-plan.md`

## Pattern Audit Sprint 1 Validation

Pattern Audit Sprint 1 defined the research-only pattern audit contract before
adding tooling or Strategy Tester playback.

Changed files:

- `docs/plans/ml-pattern-audit-follow-up-plan.md`
- `docs/research/ml-pattern-audit.md`

Defined:

- Controlled pattern lanes for direction, structure, Fibonacci, macro
  slope/alignment, chain scores, previous candle, and context/session.
- Required audit artifacts:
  - `pattern_catalog.tsv`
  - `pattern_summary.tsv`
  - `pattern_matches.tsv`
  - `pattern_audit_report.md`
  - `pattern_audit.json`
- `pattern_matches.tsv` must include readable `conditions_text` and identifiers
  needed for Strategy Tester playback.
- Guardrail statuses:
  - `AUDIT_PASS`
  - `REVIEW`
  - `RARE_BUCKET_IGNORE`
  - `FINAL_HOLDOUT_FAIL`
  - `DATA_AMBIGUITY`
- Strategy Tester playback is research-only and must not alter trading
  behavior.

Validation:

- Manual contract review: PASS.

## Strategy-Scoped Pattern Filter Sprint 2 Validation

Strategy-Scoped Pattern Filter Sprint 2 changed offline pattern mining so
patterns are strategy-scoped.

Changed files:

- `tools/deterministic_signal_ml/pattern_audit.py`

Implemented:

- Automatic pattern templates are prefixed with `strategy_label`.
- `strategy_label` does not count against feature-depth filtering.
- `pattern_label` starts with the strategy, for example:
  `S2 | Bullish | H1 slope bullish | H4 slope bearish | D1 slope bullish`.
- `conditions_text` includes the exact scope, for example:
  `strategy_label=S2; direction=BULLISH; macro_h1_live_dir=1; macro_h4_live_dir=-1; macro_d1_live_dir=1`.
- Added optional repeated `--strategy-label` for S1-only, S2-only, or S3-only
  audits.
- Chronological pre-final/final split is computed after any strategy filter.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py`:
  PASS.
- Strategy-scoped smoke:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_strategy_scoped_smoke --overwrite --top-n-visual 3 --max-catalog-patterns 80`
  - Patterns: `80`
  - Selected: `3`
  - Matches: `1088`
- S1-only smoke:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_strategy_s1_smoke --overwrite --strategy-label S1 --top-n-visual 3 --max-catalog-patterns 80`
  - Patterns: `80`
  - Selected: `3`
  - Matches: `560`

## Strategy-Scoped Pattern Filter Sprint 3 Validation

Strategy-Scoped Pattern Filter Sprint 3 simplified the Strategy Tester pattern
filter UI and removed chart text labels.

Changed files:

- `services/trading_management/ea_inputs.mqh`
- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- `services/frontend/lightweight_status_ui.mqh`
- `docs/plans/ml-pattern-audit-focused-playback-plan.md`

Implemented:

- Removed the redundant `Pattern_Audit_Admit_Selected_Only` input.
- `Enable_Pattern_Audit_Overlay=true` is now the single Strategy Tester
  selected-pattern filter and panel switch.
- Outside Strategy Tester, pattern audit filtering has no live trading effect.
- Removed pattern audit `OBJ_TEXT` chart labels.
- Panel rows now split the last observed pattern into:
  - `Pattern Last`
  - `Pattern Setup`
  - `Pattern Extra`

Validation:

- `git diff --check`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-strategy-sprint3-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

## Strategy-Scoped Pattern Filter Sprint 4 Validation

Strategy-Scoped Pattern Filter Sprint 4 added source-family identity and
duplicate selected-entry blocking.

Changed files:

- `services/trading_signals/signal_params_struct.mqh`
- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- `tools/deterministic_signal_ml/pattern_audit.py`

Implemented:

- Added MQL5 `BuildDeterministicSignalSourceFamilyKey`, which excludes
  `strategy_label` but preserves direction, source slot, source type, source
  time, and source price.
- Added `source_family_key` to `pattern_matches.tsv`.
- Pattern-filtered tester admission now blocks later selected entries from an
  already admitted source family with reason:
  `duplicate_source_family|source_family_key=<key>`.
- The first admitted selected entry from a source family wins. Explicit S1/S2/S3
  priority selection is intentionally left for a later sprint if the separate
  strategy runs show it is needed.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py`:
  PASS.
- Source-family smoke:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_strategy_family_smoke --overwrite --strategy-label S1 --top-n-visual 2 --max-catalog-patterns 40`
  - Patterns: `40`
  - Selected: `2`
  - Matches: `362`
  - `pattern_matches.tsv` includes `source_family_key`.
- `git diff --check`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-strategy-sprint4-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

## Strategy-Scoped Pattern Filter Sprint 5 Validation

Strategy-Scoped Pattern Filter Sprint 5 records the fresh-run handoff before
the next long Strategy Tester validation.

Current code state:

- `Enable_Pattern_Audit_Overlay=true` is the only Strategy Tester pattern
  filter switch.
- `Pattern_Audit_Admit_Selected_Only` has been removed from code.
- Pattern audit chart text labels have been removed; pattern state is panel-only.
- Offline pattern mining is strategy-scoped through `strategy_label`.
- Pattern-filtered combined tester runs block later selected entries from an
  already admitted `source_family_key`.

Recommended fresh-data cleanup before the next human Strategy Tester run:

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

# Close MetaTrader before deleting generated Common Files outputs.
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/runs/xauusd_2025_strategy_s1_fresh_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/runs/xauusd_2025_strategy_s2_fresh_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/runs/xauusd_2025_strategy_s3_fresh_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s1_audit_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s2_audit_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s3_audit_1"
rm -rf "$MT5_COMMON_FILES/DeterministicSignalML/pattern_audits/xauusd_2025_strategy_combined_audit_1"

rm -rf artifacts/datasets/xauusd_2025_strategy_s1_dataset_1
rm -rf artifacts/datasets/xauusd_2025_strategy_s2_dataset_1
rm -rf artifacts/datasets/xauusd_2025_strategy_s3_dataset_1
rm -rf artifacts/pattern_audits/xauusd_2025_strategy_s1_audit_1
rm -rf artifacts/pattern_audits/xauusd_2025_strategy_s2_audit_1
rm -rf artifacts/pattern_audits/xauusd_2025_strategy_s3_audit_1
rm -rf artifacts/pattern_audits/xauusd_2025_strategy_combined_audit_1
```

Fresh Strategy Tester order:

1. **S1 data export only**
   - `Enable_Strategy_1 = true`
   - `Enable_Strategy_2 = false`
   - `Enable_Strategy_3 = false`
   - `Enable_Signal_Feature_Export = true`
   - `Signal_Feature_Run_Id = xauusd_2025_strategy_s1_fresh_1`
   - `Enable_Pattern_Audit_Overlay = false`
   - `ML_Inference_Mode = ML_INFERENCE_DISABLED`
   - XAUUSD M1, `2025-01-01` through `2026-01-01`.
2. Build S1 dataset from the fresh run, then audit with:
   `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_strategy_s1_dataset_1 --audit-id xauusd_2025_strategy_s1_audit_1 --overwrite --strategy-label S1 --top-n-visual 3`
3. **S1 pattern-filter validation**
   - `Enable_Strategy_1 = true`
   - `Enable_Strategy_2 = false`
   - `Enable_Strategy_3 = false`
   - `Enable_Signal_Feature_Export = false`
   - `Enable_Pattern_Audit_Overlay = true`
   - `Pattern_Audit_Set_Id = xauusd_2025_strategy_s1_audit_1`
4. Repeat the same export, build, audit, and pattern-filter validation for S2
   and S3 using:
   - `xauusd_2025_strategy_s2_fresh_1`
   - `xauusd_2025_strategy_s2_dataset_1`
   - `xauusd_2025_strategy_s2_audit_1`
   - `xauusd_2025_strategy_s3_fresh_1`
   - `xauusd_2025_strategy_s3_dataset_1`
   - `xauusd_2025_strategy_s3_audit_1`
5. Only after S1/S2/S3 are clear, run a combined S1+S2+S3 tester validation
   with a combined strategy-scoped audit package. The duplicate source-family
   guard will prevent multiple selected entries from the same structural source.

After each pattern-filter run, compare parity:

```bash
MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files" \
.venv/bin/python tools/deterministic_signal_ml/pattern_playback_compare.py \
  --audit-id <strategy_audit_id>
```

Validation:

- Code search: no `Pattern_Audit_Admit_Selected_Only` references remain in
  `services/`, `tools/`, or `HFT_Grid_AI.mq5`.
- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py tools/deterministic_signal_ml/pattern_playback_compare.py`:
  PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-strategy-sprint5-final-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

Decision:

- `READY_FOR_FRESH_STRATEGY_TESTER_DATA_RUNS`
- Start with S1-only, then S2-only, then S3-only before any combined long run.
- No live deployment or runtime ML FILTER approval is implied.
- `git diff --check`: PASS.

## Strategy-Scoped Pattern Filter Fresh S1/S2/S3 Handoff

The human Strategy Tester export runs were generated separately for S1, S2,
and S3, then converted into per-strategy datasets and pattern audit packages.

Source Strategy Tester runs:

| Strategy | Run ID | Feature rows | Outcome rows | Invalid feature rows |
| --- | --- | ---: | ---: | ---: |
| S1 | `xauusd_2025_schema_v3_run_S1` | 11906 | 11906 | 8 |
| S2 | `xauusd_2025_schema_v3_run_S2` | 12896 | 12896 | 10 |
| S3 | `xauusd_2025_schema_v3_run_S3` | 12232 | 12232 | 4 |

Dataset build results:

| Strategy | Dataset ID | Training rows | Notes |
| --- | --- | ---: | --- |
| S1 | `xauusd_2025_strategy_s1_dataset_1` | 11898 | 1 SL row had zero `net_profit` with negative `profit_r`; accepted as a loss and warned. |
| S2 | `xauusd_2025_strategy_s2_dataset_1` | 12886 | 1 SL row had zero `net_profit` with negative `profit_r`; accepted as a loss and warned. |
| S3 | `xauusd_2025_strategy_s3_dataset_1` | 12228 | No SL zero-net anomaly. |

The Phase 1 validator now treats SL rows as invalid only when `profit_r >= 0`
or `net_profit > 0`. An SL row with `profit_r < 0` and rounded/zero
`net_profit` is still a losing outcome for the R-multiple target, so it is
accepted with a warning instead of blocking dataset generation.

Pattern audit packages:

| Strategy | Audit ID | Catalog patterns | Selected patterns | Expected selected matches |
| --- | --- | ---: | ---: | ---: |
| S1 | `xauusd_2025_strategy_s1_audit_1` | 253 | 3 | 900 |
| S2 | `xauusd_2025_strategy_s2_audit_1` | 271 | 3 | 1091 |
| S3 | `xauusd_2025_strategy_s3_audit_1` | 280 | 3 | 1095 |

Selected pattern labels:

| Strategy | Pattern ID | Human label | Pre-final net R | Final holdout net R |
| --- | --- | --- | ---: | ---: |
| S1 | `pat_793b226cf9f9` | `S1 \| Bearish \| Session ASIA \| Spread/range SPREAD_LOW` | 22.2113 | 6.8675 |
| S1 | `pat_471ae11c2899` | `S1 \| Bullish \| 3-bar lows score -3 \| 5-bar lows score -1 \| 10-bar lows score -2` | 18.2165 | 0.0741 |
| S1 | `pat_e0a59345d1bb` | `S1 \| Bullish \| H1 slope bullish \| H4 slope bearish \| D1 slope bullish` | 15.7928 | -18.1266 |
| S2 | `pat_0ccbb9c6bffe` | `S2 \| Bullish \| H1 slope bullish \| H4 slope bearish \| D1 slope bullish` | 33.8496 | -23.4202 |
| S2 | `pat_b57b3091233a` | `S2 \| Bearish \| HH[0] \| LL[1] \| H1 slope bearish \| Entry Fib 61.8-100` | 21.0734 | 0.7927 |
| S2 | `pat_4675830fd294` | `S2 \| Bearish \| LH[0] \| HL[1] \| H1 slope bearish \| Entry Fib 38.2-61.8` | 17.4783 | -7.0983 |
| S3 | `pat_eac857571edd` | `S3 \| Bearish \| LH[0] \| HL[1] \| LH[2]` | 19.1974 | -9.0292 |
| S3 | `pat_9e7cd1652914` | `S3 \| Bearish \| 3-bar lows score -1` | 16.7737 | 5.7709 |
| S3 | `pat_8b3163964183` | `S3 \| Bullish \| LL[0] \| H1 slope bullish \| 3-bar lows score 1` | 12.7105 | -14.0901 |

The three audit packages were copied to Strategy Tester Common Files under:

```text
DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s1_audit_1/
DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s2_audit_1/
DeterministicSignalML/pattern_audits/xauusd_2025_strategy_s3_audit_1/
```

Initial parity checks before Strategy Tester playback are pending by design:

| Audit ID | Expected | Observed | Status |
| --- | ---: | ---: | --- |
| `xauusd_2025_strategy_s1_audit_1` | 900 | 0 | `PENDING` |
| `xauusd_2025_strategy_s2_audit_1` | 1091 | 0 | `PENDING` |
| `xauusd_2025_strategy_s3_audit_1` | 1095 | 0 | `PENDING` |

Next human Strategy Tester order:

1. S1 pattern-filter validation with
   `Pattern_Audit_Set_Id = xauusd_2025_strategy_s1_audit_1`.
2. S2 pattern-filter validation with
   `Pattern_Audit_Set_Id = xauusd_2025_strategy_s2_audit_1`.
3. S3 pattern-filter validation with
   `Pattern_Audit_Set_Id = xauusd_2025_strategy_s3_audit_1`.
4. Run `pattern_playback_compare.py` for each audit after its tester
   observation file exists.
5. Prepare a combined S1/S2/S3 audit only after per-strategy parity is clear.

## Schema V4 Semantic Lanes Contract

The schema v3 pattern audit proved selected-pattern admission can match offline
expectations, but several v3 features are too ambiguous for the next robust
research pass. Schema v4 therefore replaces the active research feature set
with a smaller semantic-lane contract.

Active schema v4 model and pattern-audit lanes:

| Lane | Column | Values / source |
| --- | --- | --- |
| Strategy | `strategy_label` | `S1`, `S2`, `S3`; keep for combined datasets, exclude if constant in single-strategy training. |
| Direction | `direction` | `BULLISH`, `BEARISH`. |
| Structure | `structure_0` | Current source extremum structure. |
| Structure | `structure_1` | Most recent opposite extremum structure. |
| Structure | `structure_2` | Previous same-side extremum structure. |
| Macro slope | `macro_h1_slope` | H1 MA slope direction at entry. |
| Macro slope | `macro_h4_slope` | H4 MA slope direction at entry. |
| Macro slope | `macro_d1_slope` | D1 MA slope direction at entry. |
| Fibonacci | `fib_sl_band` | Categorical stop-anchor Fibonacci band. |
| Fibonacci | `fib_entry_band` | Categorical entry-reference Fibonacci band. |
| Chain | `high_chain_profile` | Longest strict high-continuity profile. |
| Chain | `low_chain_profile` | Longest strict low-continuity profile. |
| Candle | `previous_candle_profile` | One profile for closed `candle_1`. |
| Session | `entry_session_bucket` | Existing broker-time session bucket. |
| Calendar | `entry_weekday` | Broker-time weekday at entry. |

The current broker-time session buckets remain unchanged:

- `ASIA`: hour `00:00` through `06:59`.
- `LONDON`: hour `07:00` through `11:59`.
- `NEWYORK`: hour `12:00` through `20:59`.
- `OFFHOURS`: hour `21:00` through `23:59`.

Structure lane semantics:

- `structure_0` replaces `source_structure_type`.
- `structure_1` replaces `opposite_structure_type`.
- `structure_2` replaces `same_previous_structure_type`.
- Human labels may render this as `LH[0] | HL[1] | LH[2]`.

Chain lane semantics:

- `high_chain_profile` and `low_chain_profile` are independent lanes.
- A pattern may validly combine both lanes, for example
  `high_chain_profile=HIGH_UP_10 && low_chain_profile=LOW_UP_5`.
- One lane cannot carry two values for the same signal.
- Longest strict match wins inside each lane: `10`, then `5`, then `3`.
- `UP` means the most recent closed values are rising relative to older closed
  values, for example `high_1 > high_2 > ...`.
- `DOWN` means the most recent closed values are falling relative to older
  closed values, for example `high_1 < high_2 < ...`.
- High lane values:
  `HIGH_UP_10`, `HIGH_UP_5`, `HIGH_UP_3`, `HIGH_DOWN_10`,
  `HIGH_DOWN_5`, `HIGH_DOWN_3`, `HIGH_MIXED`.
- Low lane values:
  `LOW_UP_10`, `LOW_UP_5`, `LOW_UP_3`, `LOW_DOWN_10`,
  `LOW_DOWN_5`, `LOW_DOWN_3`, `LOW_MIXED`.

Previous candle profile semantics:

- The profile uses only closed `candle_1` from `DETERMINISTIC_BASE_TIMEFRAME`.
- Compute body, upper wick, lower wick, and close location from the same candle.
- `DOJI` is selected when `body_ratio < 0.10`.
- For non-doji candles, direction is `BULL` when close is above open and `BEAR`
  when close is below open.
- Dominant upper wick profile is selected when
  `upper_wick_ratio >= 0.50` and `upper_wick_ratio >= lower_wick_ratio * 1.50`.
- Dominant lower wick profile is selected when
  `lower_wick_ratio >= 0.50` and `lower_wick_ratio >= upper_wick_ratio * 1.50`.
- Otherwise body tiers are:
  - `BODY_HIGH` when `body_ratio >= 0.60`.
  - `BODY_MID` when `body_ratio >= 0.25`.
  - `BODY_LOW` otherwise.
- Output tokens are `BULL_UPPER_WICK`, `BULL_LOWER_WICK`,
  `BULL_BODY_HIGH`, `BULL_BODY_MID`, `BULL_BODY_LOW`,
  `BEAR_UPPER_WICK`, `BEAR_LOWER_WICK`, `BEAR_BODY_HIGH`,
  `BEAR_BODY_MID`, `BEAR_BODY_LOW`, or `DOJI`.

Retired active ML/pattern features:

- `source_type`, because it is redundant with `direction`.
- `strategy_id`, `strategy_delay_period`, and
  `confirmation_timeframe_minutes` as active model features; these may remain
  operational metadata.
- `entry_direction_macro_alignment` and `macro_alignment_score`, because they
  duplicate `direction + macro_h1/h4/d1`.
- Separate candle ratios and direction:
  `prev_body_ratio`, `prev_upper_wick_ratio`, `prev_lower_wick_ratio`,
  `prev_close_location`, `prev_candle_dir`.
- Raw Fibonacci values: `sl_fib_raw`, `entry_fib_raw`.
- Chain score stacks:
  `low_chain_score_3`, `low_chain_score_5`, `low_chain_score_10`,
  `high_chain_score_3`, `high_chain_score_5`, `high_chain_score_10`.
- Context and spread features:
  `recent_m1_range_points`, `recent_m1_body_ratio_avg`,
  `recent_m1_directional_balance`, `entry_spread_points`,
  `spread_to_recent_range_ratio`.

Decision:

- `READY_FOR_SCHEMA_V4_IMPLEMENTATION`
- Schema v4 supersedes schema v3 for new Phase 3 research.
- Fresh S1/S2/S3 Strategy Tester exports are required after the code compiles.
- No live deployment or runtime FILTER approval is implied.

## Pattern Audit Sprint 2 Validation

Pattern Audit Sprint 2 added deterministic DuckDB tooling for controlled
pattern scans.

Changed files:

- `.gitignore`
- `tools/deterministic_signal_ml/pattern_audit.py`

Implemented:

- Bounded pattern templates from schema v3 lanes.
- Pre-final and final-holdout split-aware metrics.
- Generated audit artifacts:
  - `pattern_catalog.tsv`
  - `pattern_summary.tsv`
  - `pattern_matches.tsv`
  - `pattern_selection.tsv`
  - `pattern_audit_report.md`
  - `pattern_audit.json`
- Manual pattern selection via `--pattern-id` or `--selection-file`.
- Generated artifacts are ignored under `artifacts/pattern_audits/`.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py`:
  PASS.
- `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --help`:
  PASS.
- Smoke command:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_pattern_audit_sprint2_smoke --overwrite --top-n-visual 5 --max-catalog-patterns 80`
- Smoke result:
  - Patterns: `80`
  - Selected for visual review: `5`
  - Matches: `2973`
  - Catalog columns/rows: `11` / `80`
  - Summary columns/rows: `23` / `80`
  - Matches columns/rows: `20` / `2973`
  - Status counts: `AUDIT_PASS=9`, `FINAL_HOLDOUT_FAIL=17`, `REVIEW=54`
- Re-running the same command produced stable hashes for catalog, summary, and
  matches TSV files.

## Pattern Audit Sprint 3 Validation

Pattern Audit Sprint 3 ran the default bounded audit on the schema v3 dataset
and prepared the Strategy Tester playback package.

Audit:

- Audit ID: `xauusd_2025_pattern_audit_1`
- Dataset ID: `xauusd_2025_schema_v3_dataset_1`
- Command:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_pattern_audit_1 --overwrite`
- Result:
  - Catalog patterns: `300`
  - Selected visual patterns: `12`
  - Match rows: `6008`
  - `pattern_catalog.tsv`: `11` columns, `300` rows
  - `pattern_summary.tsv`: `23` columns, `300` rows
  - `pattern_matches.tsv`: `20` columns, `6008` rows
  - `pattern_selection.tsv`: `2` columns, `12` rows
- Status counts:
  - `AUDIT_PASS=9`
  - `FINAL_HOLDOUT_FAIL=17`
  - `REVIEW=274`

Selected pattern IDs:

- `pat_5340e3393fcd`
- `pat_5599d37ee5d7`
- `pat_6781e1971c65`
- `pat_797497dad1b7`
- `pat_7cef9225abbd`
- `pat_91f96dc6eb50`
- `pat_95208b4d6ffb`
- `pat_9d114d94d418`
- `pat_b01ef3517449`
- `pat_b4bb7659ae98`
- `pat_c3230ed8f77c`
- `pat_df3ca3961b09`

Playback package:

- Common Files folder:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/pattern_audits/xauusd_2025_pattern_audit_1/`
- Copied files:
  - `pattern_catalog.tsv`
  - `pattern_summary.tsv`
  - `pattern_matches.tsv`
  - `pattern_selection.tsv`
  - `pattern_audit.json`

Notes:

- Selected patterns are for Strategy Tester playback only.
- No pattern is approved as runtime FILTER.
- Selection includes both `AUDIT_PASS` and final-holdout-failing patterns so
  visual review can compare stable and unstable pattern families.

## Pattern Audit Sprint 4 Validation

Pattern Audit Sprint 4 added Strategy Tester-only playback for selected offline
pattern matches.

Changed files:

- `HFT_Grid_AI.mq5`
- `services/trading_management/ea_inputs.mqh`
- `services/trading_signals.mqh`
- `services/trading_signals/execution_controller.mqh`
- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`

Implemented:

- Disabled-by-default inputs:
  - `Enable_Pattern_Audit_Overlay`
  - `Pattern_Audit_Set_Id`
- Loader for
  `Common\Files\DeterministicSignalML\pattern_audits\<audit_id>\pattern_matches.tsv`.
- Selected-match playback keyed by `source_key` plus
  `source_attempt_index`, because `signal_id` can change with run IDs.
- Compact tester output:
  `pattern_tester_observations.tsv`.
- Optional visual `OBJ_TEXT` markers in Strategy Tester visual mode.

Safety:

- Playback is gated by `MQL_TESTER` and the disabled-by-default overlay input.
- It only records observed selected matches and optional chart markers.
- It does not block entries, create trades, resize lots, alter SL/TP, change
  exits, bypass license/session/spread/margin/protection controls, change
  magic-number scope, or affect broker reconciliation.

Validation:

- `git diff --check`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-sprint4-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.
- Human-in-the-loop Strategy Tester visual/parity smoke is pending until a run
  creates
  `Common\Files\DeterministicSignalML\pattern_audits\xauusd_2025_pattern_audit_1\pattern_tester_observations.tsv`.

## Pattern Audit Sprint 5 Validation

Pattern Audit Sprint 5 added offline parity comparison between DuckDB pattern
matches and Strategy Tester playback observations.

Changed files:

- `tools/deterministic_signal_ml/pattern_playback_compare.py`

Implemented:

- Compares expected selected rows from `pattern_matches.tsv` against observed
  rows from `pattern_tester_observations.tsv`.
- Uses `pattern_id`, `source_key`, and `source_attempt_index` as the stable
  parity key.
- Reports expected, observed, matched, missing, extra, duplicate-key,
  `entry_time`, `signal_id`, and observation-status mismatch counts.
- Writes compact ignored outputs:
  - `pattern_playback_parity.json`
  - `pattern_playback_parity.md`
  - `pattern_playback_mismatches.tsv`
- Keeps `signal_id` mismatch diagnostic by default because `signal_id` includes
  the deterministic stats run ID.

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_playback_compare.py`:
  PASS.
- `.venv/bin/python tools/deterministic_signal_ml/pattern_playback_compare.py --help`:
  PASS.
- Synthetic fixture smoke:
  - Expected rows: `20`
  - Observed rows: `20`
  - Matched rows: `20`
  - Missing rows: `0`
  - Extra rows: `0`
  - Entry-time mismatches: `0`
  - Result: `PASS`

Current real playback status:

- Command:
  `MT5_COMMON_FILES=/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files .venv/bin/python tools/deterministic_signal_ml/pattern_playback_compare.py --audit-id xauusd_2025_pattern_audit_1 --allow-missing-observations`
- Result:
  - Status: `PENDING`
  - Decision: `RESEARCH_ONLY_WARN`
  - Expected selected match rows: `6008`
  - Observed tester rows: `0`
  - Missing rows: `6008`
- Pending file:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/pattern_audits/xauusd_2025_pattern_audit_1/pattern_tester_observations.tsv`

Decision:

- `RESEARCH_ONLY_WARN`
- The comparator is ready, but data semantics cannot be declared
  `DATA_CLEAR_CONTINUE_TO_PATH_LABELS` until a human-in-the-loop Strategy
  Tester playback run creates `pattern_tester_observations.tsv` and the
  comparator passes against that real file.
- No pattern is approved as runtime FILTER.

## Focused Pattern Playback Sprint 1 Validation

Focused Pattern Playback Sprint 1 defined the follow-up contract before adding
tester-admission behavior.

Plan:

- `docs/plans/ml-pattern-audit-focused-playback-plan.md`

Contract:

- `Enable_Pattern_Audit_Overlay` remains overlay/parity only.
- Selected-pattern admission must be a separate disabled-by-default input.
- Selected-pattern admission is Strategy Tester-only.
- Existing license, session, spread, broker-distance, volume, margin,
  protection, magic-number, and broker reconciliation gates must stay earlier
  in the pipeline.
- No selected pattern is approved for live deployment or runtime ML FILTER.

Validation:

- Manual contract review: PASS.

## Focused Pattern Playback Sprint 2 Validation

Focused Pattern Playback Sprint 2 added human-readable pattern labels and
created a smaller focused playback package.

Changed files:

- `tools/deterministic_signal_ml/pattern_audit.py`

Implemented:

- `pattern_label` now uses human-readable tokens such as:
  - `Bearish | LH[0] | HL[1] | H1 slope bearish | Entry Fib 38.2-61.8`
  - `Bullish | H1 slope bullish | H4 slope bearish | D1 slope bullish`
- `conditions_text` remains unchanged as the exact machine-readable pattern
  contract.
- `pattern_id` remains derived from `conditions_text`, so existing pattern keys
  stay stable.

Generated focus audit:

- Audit ID: `xauusd_2025_pattern_audit_focus_1`
- Dataset ID: `xauusd_2025_schema_v3_dataset_1`
- Command:
  `.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py --dataset-id xauusd_2025_schema_v3_dataset_1 --audit-id xauusd_2025_pattern_audit_focus_1 --overwrite --top-n-visual 3`
- Result:
  - Catalog patterns: `300`
  - Selected visual patterns: `3`
  - Selected match rows: `2611`

Selected focus patterns:

- `pat_95208b4d6ffb`: `Bullish | H1 slope bullish | H4 slope bearish | D1 slope bullish`
- `pat_9d114d94d418`: `Bearish | LH[0] | HL[1] | H1 slope bearish | Entry Fib 38.2-61.8`
- `pat_b01ef3517449`: `Bearish | 3-bar lows score 1 | 5-bar lows score -1 | 10-bar lows score -2`

Common Files package:

- `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/pattern_audits/xauusd_2025_pattern_audit_focus_1/`

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py`:
  PASS.
- Focus smoke with `--top-n-visual 3 --max-catalog-patterns 80`:
  `patterns=80`, `selected=3`, `matches=2611`, PASS.

## Focused Pattern Playback Sprint 3 Validation

Focused Pattern Playback Sprint 3 optimized Strategy Tester playback lookup and
made focused pattern state visible in the chart panel.

Changed files:

- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- `services/frontend/lightweight_status_ui.mqh`

Implemented:

- Selected matches are sorted once at load time.
- Runtime lookup uses a binary-search index by `source_key` plus
  `source_attempt_index`.
- Per-signal full-array scan was removed from playback matching.
- Visual markers are capped at `150` objects per run.
- Lightweight panel can show:
  - pattern mode
  - audit ID
  - observed/loaded hit counts
  - last observed human-readable pattern label

Validation:

- `git diff --check`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-focused-sprint3-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

## Focused Pattern Playback Sprint 4 Validation

Focused Pattern Playback Sprint 4 added explicit Strategy Tester-only admission
by selected pattern matches.

Changed files:

- `services/trading_management/ea_inputs.mqh`
- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- `services/trading_signals/execution_controller.mqh`

Implemented:

- New disabled-by-default input:
  - `Pattern_Audit_Admit_Selected_Only`
- Superseded by Strategy-Scoped Pattern Filter Sprint 3: this input has been
  removed, and `Enable_Pattern_Audit_Overlay=true` is now the single
  Strategy Tester selected-pattern filter switch.
- At the time of this sprint, `Pattern_Audit_Admit_Selected_Only=true` loaded
  the selected pattern package even if visual overlay was not needed.
- Selected-pattern admission is checked after existing prepared broker/risk
  admission passes and before `ApplyExecutionLegTradeAdmission`.
- Non-matching entries are locally closed with:
  - terminal reason `PATTERN_AUDIT_FILTER_BLOCKED`
  - guardrail source `PATTERN_AUDIT_FILTER_BLOCKED`
- Superseded non-tester behavior: the current filter has no live trading effect
  outside Strategy Tester.

Safety:

- The filter cannot create trades.
- It cannot resize lots, alter SL/TP, alter exits, bypass license/session/spread
  or broker checks, change magic-number scope, or affect broker reconciliation.
- It only denies otherwise prepared deterministic entries when explicitly
  enabled.

Validation:

- `git diff --check`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-focused-sprint4-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

## Focused Pattern Playback Sprint 5 Validation

Focused Pattern Playback Sprint 5 recorded the final validation and the exact
Strategy Tester handoff for a shorter selected-pattern run.

Focused audit package:

- Use audit ID: `xauusd_2025_pattern_audit_focus_1`
- Common Files path:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/pattern_audits/xauusd_2025_pattern_audit_focus_1/`
- Selected patterns: `3`
- Selected match rows: `2611`

Recommended Strategy Tester inputs:

- `Enable_Signal_Feature_Export = false`
- `ML_Inference_Mode = ML_INFERENCE_DISABLED`
- `Enable_Logs = false`
- `Enable_File_Logs = false`
- `Enable_Pattern_Audit_Overlay = true`
- `Pattern_Audit_Set_Id = xauusd_2025_pattern_audit_focus_1`

Expected behavior:

- Only deterministic entries matching selected pattern rows from the focus
  audit are admitted.
- Non-matching deterministic entries are closed locally with
  `PATTERN_AUDIT_FILTER_BLOCKED`.
- The panel shows pattern mode, audit ID, hit count, and last observed human
  label.
- Superseded by Strategy-Scoped Pattern Filter Sprint 3: pattern text is shown
  in the panel only; no pattern text labels are drawn on the chart.

Post-run parity command:

```bash
MT5_COMMON_FILES=/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files \
.venv/bin/python tools/deterministic_signal_ml/pattern_playback_compare.py \
  --audit-id xauusd_2025_pattern_audit_focus_1
```

Current parity status before the human Strategy Tester run:

- Status: `PENDING`
- Decision: `RESEARCH_ONLY_WARN`
- Expected rows: `2611`
- Observed rows: `0`
- Missing rows: `2611`

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py tools/deterministic_signal_ml/pattern_playback_compare.py`:
  PASS.
- Pending parity report command with `--allow-missing-observations`: PASS.
- MetaEditor real compile:
  `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/pattern-audit-focused-sprint5-final-compile.log --mode compile --timeout 240`
- Compile result: `0 errors, 0 warnings`.

Decision:

- `READY_FOR_HUMAN_STRATEGY_TESTER_FOCUSED_RUN`
- No live deployment or runtime ML FILTER approval is implied.

## Strategy-Scoped Pattern Filter Sprint 1 Validation

Strategy-Scoped Pattern Filter Sprint 1 defined the corrected workflow before
long Strategy Tester runs.

Plan:

- `docs/plans/ml-pattern-audit-strategy-scoped-filter-plan.md`

Contract:

- `Enable_Pattern_Audit_Overlay=true` becomes the single Strategy Tester
  selected-pattern filter and panel switch.
- The redundant `Pattern_Audit_Admit_Selected_Only` input will be removed.
- Pattern audit statistics must be scoped by `strategy_label` so S1, S2, and S3
  are not mixed as one statistical sample.
- Pattern-filtered combined tester runs must admit at most one selected entry
  from the same structural source family.
- Pattern audit remains Strategy Tester research only and gives no live
  deployment approval.

Fresh-run policy:

- Start from fresh generated tester data before trusting a long run.
- Generate and validate S1-only, S2-only, and S3-only data first.
- Build per-strategy pattern audits from those fresh runs.
- Run combined S1+S2+S3 only after per-strategy patterns and duplicate-source
  behavior are clear.

Validation:

- Manual contract review: PASS.
