# ML Feature Schema V2 Acceptance

**Date**: 2026-07-06
**Roadmap Phase**: Phase 3 - Feature Schema V2
**Status**: SCHEMA_V3_EXPORT_HANDOFF

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

Current handoff:

- Follow-up Sprint 4 is blocked until the schema v3 raw export and dataset
  exist.
- Recommended run ID: `xauusd_2025_schema_v3_run_1`
- Recommended dataset ID: `xauusd_2025_schema_v3_dataset_1`
- Recommended model IDs:
  - `xauusd_2025_schema_v3_xgb_1`
  - `xauusd_2025_schema_v3_no_context_xgb_1`
- Strategy Tester configuration remains unchanged except for the active schema:
  XAUUSD full calendar year 2025, ML disabled, feature export enabled, S1/S2/S3
  enabled.
