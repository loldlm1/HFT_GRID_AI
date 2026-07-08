# ML Numeric XGBoost Feature Spike

**Date**: 2026-07-08
**Roadmap Phase**: Phase 5 - Numeric XGBoost Feature Spike
**Status**: IN_PROGRESS
**Planner plan**: `docs/plans/ml-numeric-xgboost-feature-spike-plan.md`

## Scope

This phase tests whether a compact numeric XGBoost lane can improve robust
signal selection before ONNX work resumes. Schema v4 semantic lanes remain
available for DuckDB pattern audit. Schema v5 is a separate XGBoost feature
contract and must not remove or weaken the pattern-audit workflow.

The first pass trains one active strategy at a time and includes `direction` as
a model feature. Direction is also a mandatory validation segment because it can
consume depth in `max_depth=3` trees and hide asymmetric behavior if only global
metrics are reviewed.

Out of scope:

- live deployment approval
- ONNX work
- runtime TP changes
- use of path-label columns as features
- replacement of DuckDB semantic pattern lanes
- custom MQL5 tests or CI
- weakening license, session, spread, stops/freeze, margin, protection,
  market-status, magic-number, or broker-reconciliation gates

## Schema V5 Feature Contract

Model feature columns:

```text
direction
stoch_structure_raw_percent
b_percent_main_base
b_percent_main_base_slope
b_percent_main_macro
b_percent_main_macro_slope
session_id
time_sin
time_cos
```

Categorical model inputs:

- `direction`: `BULLISH` or `BEARISH`.
- `session_id`: broker-time session bucket.

Numeric model inputs:

- `stoch_structure_raw_percent`: raw structure percent of the source extremum
  used as the SL anchor. It is the raw percent behind the existing
  `fib_sl_band` path, not live close percent and not a raw oscillator value.
- `b_percent_main_base`: `BB_Percent_Standard` buffer `0` (`Main`) on M1.
  Parameters are `InpBandsPeriod=21`, `InpDeviation=2.0`,
  `InpCandleShift=3/5/10` for S1/S2/S3, `MODE_SMA`, and `PRICE_CLOSE`.
- `b_percent_main_base_slope`: confirmed absolute delta
  `base_main[1] - base_main[2]` from the same base `%B` handle.
- `b_percent_main_macro`: `BB_Percent_Standard` buffer `0` (`Main`) on the
  strategy macro timeframe: M3 for S1, M5 for S2, M10 for S3. Parameters are
  `InpBandsPeriod=21`, `InpDeviation=2.0`, `InpCandleShift=1`, `MODE_SMA`, and
  `PRICE_CLOSE`.
- `b_percent_main_macro_slope`: confirmed absolute delta
  `macro_main[1] - macro_main[2]` from the same macro `%B` handle.
- `time_sin` and `time_cos`: broker minute-of-day cyclical encoding.

All `%B` reads must be confirmed non-forming values. Runtime/data extraction
uses `BB_Percent_Standard`, not visual chart handles.

## Precision Policy

Raw exports should keep stable decimal precision instead of aggressive
bucketization:

- `%B` values and slopes: 6 decimal places.
- `stoch_structure_raw_percent`: 6 decimal places.
- `time_sin` and `time_cos`: 9 decimal places.

The trainer may keep the raw numeric values and let XGBoost histogram binning
with `max_bin=256` choose splits. If evidence shows precision noise or
overfit, add an explicit rounding ablation instead of silently changing the
schema.

## Visual QA Rule

Visual `iBands` may be attached with `bands_shift` to inspect delayed base and
macro clocks:

- base M1 visual bands use shifts `3`, `5`, or `10`
- macro visual bands use shift `1`

Those handles are QA-only. They must not drive trading, feature extraction,
risk controls, runtime scoring, or model parity.

## Evidence Layout

Generated raw exports, datasets, models, reports, screenshots, and Common
Files packages remain out of git.

Recommended XAUUSD 2025 run IDs:

| Strategy | Run ID |
| --- | --- |
| S1 | `xauusd_2025_schema_v5_numeric_run_S1` |
| S2 | `xauusd_2025_schema_v5_numeric_run_S2` |
| S3 | `xauusd_2025_schema_v5_numeric_run_S3` |

Recommended dataset IDs:

| Strategy | Dataset ID |
| --- | --- |
| S1 | `xauusd_2025_schema_v5_numeric_dataset_S1` |
| S2 | `xauusd_2025_schema_v5_numeric_dataset_S2` |
| S3 | `xauusd_2025_schema_v5_numeric_dataset_S3` |

Recommended model IDs:

```text
xauusd_2025_schema_v5_numeric_S1_broker_1r_xgb
xauusd_2025_schema_v5_numeric_S2_broker_1r_xgb
xauusd_2025_schema_v5_numeric_S3_broker_1r_xgb
```

If Phase 4 path-ratio labels are available, append the target family:

```text
xauusd_2025_schema_v5_numeric_S1_path_1_5r_xgb
xauusd_2025_schema_v5_numeric_S2_path_2r_xgb
xauusd_2025_schema_v5_numeric_S3_path_3r_xgb
```

Required generated reports per candidate:

- dataset manifest and dataset report
- validation metrics
- threshold-selection report
- robustness report
- segment metrics by direction, session, time bucket, strategy, `%B`
  value/slope buckets, and raw structure percent buckets
- score diagnostics
- feature importance
- model manifest
- runtime artifact validation report only for accepted candidates
- SHADOW parity report only after artifact export

## Strategy Tester Export Contract

Run one strategy at a time with these shared controls:

- `Enable_Signal_Feature_Export = true`
- `Signal_Feature_Run_Id = <schema v5 run ID>`
- `ML_Inference_Mode = ML_INFERENCE_DISABLED`
- `Enable_Pattern_Audit_Overlay = false`
- `Pattern_Audit_Set_Id = ""`
- `Enable_Logs = false`
- `Enable_File_Logs = false`

Keep symbol, date range, spread/cost, session, risk, and execution settings the
same across S1/S2/S3 except strategy booleans and run IDs.

## Research Gate

A numeric candidate can advance to runtime artifact export only when:

- schema v5 exports contain no unexplained invalid feature rows
- dataset validation passes with no stale schema v4 raw files
- path-label columns remain outcome-only and absent from model feature maps
- threshold selection excludes the final holdout
- final holdout remains positive after costs at the selected threshold
- selected rows have enough support overall, by direction, and by important
  session segments
- evidence is not concentrated in one month, one session, or one direction
- schema v5 candidates compare favorably against schema v4 baselines and simple
  baselines

## Runtime Gate

Runtime export is blocked until the research gate accepts a candidate.

For an accepted candidate:

- export the existing TSV tree scorer artifact with schema v5 feature map
- keep `mt5_runtime_ready=false` until Python artifact validation and SHADOW
  parity pass
- require nonzero scored rows
- require zero invalid feature rows or a bounded, explained exception
- require Python/MQL5 classifier and regressor parity within accepted tolerance
- keep `ML_INFERENCE_FILTER` Strategy Tester-only
- keep live deployment blocked pending a future explicit rollout plan

## Sprint Status

| Sprint | Status | Notes |
| --- | --- | --- |
| 1. Numeric Feature Contract | Complete | Contract, evidence layout, and workflow references defined. |
| 2. MQL5 Numeric Feature Export | Implementation complete | MetaEditor compile PASS with 0 errors and 0 warnings. Short Strategy Tester export smoke remains pending human run. |
| 3. Visual Bands QA | Implementation complete | Visual `iBands` handles compile. Human Strategy Tester screenshot and visual/data row-count comparison remain pending. |
| 4. Python Schema And Trainer | Complete | `py_compile`, schema v5 dataset fixture, and numeric XGBoost smoke training PASS. |
| 5. Fresh Data And Robustness Gate | Tooling complete, data gate blocked | Segment diagnostics and research-only manifests validate on the schema v5 fixture. Full acceptance requires human Strategy Tester full-year exports. |
| 5A. Pre-Run Indicator Cleanup | Complete, human visual gate pending | Deterministic `iMA` logic handles replaced by `iBands` base-line handles; visual `%B` handles added for base and macro QA. |
| 6. Runtime Artifact Gate | Blocked | No accepted numeric candidate exists yet, so runtime export and SHADOW parity are not executed. |

## Sprint 2 Validation

Implemented:

- schema version bumped to `5` for signal feature export and shadow feature
  extraction
- cached `BB_Percent_Standard` logic handles for M1 base shifts `3`, `5`, `10`
  and macro M3/M5/M10 shift `1`
- confirmed `%B` buffer `0` reads with `main[1] - main[2]` slopes
- exported schema v5 numeric columns:
  - `stoch_structure_raw_percent`
  - `b_percent_main_base`
  - `b_percent_main_base_slope`
  - `b_percent_main_macro`
  - `b_percent_main_macro_slope`
  - `session_id`
  - `time_sin`
  - `time_cos`
- shadow feature lookup for the same numeric/categorical columns

Validation:

- `git diff --check`: PASS
- `python3 tools/mt5/compile_mt5.py --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --wine --timeout 120`: PASS, `0 errors`, `0 warnings`

Pending human gate:

- short Strategy Tester schema v5 export smoke with one active strategy
- verify generated `signal_features.tsv` has zero unexpected invalid numeric
  rows

## Sprint 3 Validation

Implemented:

- base visual handles now use `iBands` on M1 with strategy shifts `3`, `5`,
  or `10` when `Enable_Show_Indicators` is enabled
- macro visual chart handles now use `iBands` on M3/M5/M10 with shift `1`
- visual handles remain separate from `BB_Percent_Standard` logic handles
- trading and feature extraction do not read from visual `iBands`

Validation:

- `git diff --check`: PASS
- `python3 tools/mt5/compile_mt5.py --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --wine --timeout 120`: PASS, `0 errors`, `0 warnings`

Pending human gate:

- visual Strategy Tester screenshot review
- compare a short run with visuals enabled and disabled for matching feature
  row counts and candidate counts

## Sprint 4 Validation

Implemented:

- Python schema contract defaults to schema v5 and keeps schema v4 available
  through explicit `--schema-version 4 --feature-set-id schema_v4_full`
- dataset builder accepts schema v5 feature exports and stores
  `schema_v5_numeric_xgb` in the dataset manifest
- model feature columns are explicit and exclude path-ratio outcome columns
- trainer supports `schema_v5_numeric_xgb`
- classifier and regressor numeric configs use `tree_method=hist`,
  `max_depth=3`, and `max_bin=256`
- model manifests record selected feature columns, encoded feature count,
  params, target family, and feature set

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`: PASS
- schema v5 fixture dataset build: PASS, `520` feature rows, `520` outcome
  rows, `520` training rows
- schema v5 numeric smoke training: PASS, `13` encoded features, `104`
  holdout rows, `4` folds
- smoke manifest confirmed classifier/regressor `max_depth=3` and
  `max_bin=256`

Strategy-scoped command pattern:

```bash
MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$MT5_COMMON_FILES/DeterministicSignalML/runs" \
  --run-id xauusd_2025_schema_v5_numeric_run_S1 \
  --dataset-id xauusd_2025_schema_v5_numeric_dataset_S1 \
  --schema-version 5 \
  --feature-set-id schema_v5_numeric_xgb \
  --target-family broker_1r \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id xauusd_2025_schema_v5_numeric_dataset_S1 \
  --model-id xauusd_2025_schema_v5_numeric_S1_broker_1r_xgb \
  --feature-set-id schema_v5_numeric_xgb \
  --overwrite
```

Repeat for `S2` and `S3` by replacing the run, dataset, and model IDs. If Phase
4 path-ratio labels are present, repeat dataset/training with
`--target-family 1r`, `1_5r`, `2r`, `3r`, or `expected_r` and include the
target family in the model ID.

## Sprint 5 Validation

Implemented:

- robustness segment diagnostics now include schema v5-specific cuts when the
  source columns exist:
  - `session_id`
  - `entry_month`
  - `entry_hour`
  - `stoch_structure_raw_percent_bucket`
  - `b_percent_main_base_bucket`
  - `b_percent_main_base_slope_bucket`
  - `b_percent_main_macro_bucket`
  - `b_percent_main_macro_slope_bucket`
- schema v5 segment cuts are omitted for rows without those columns, so legacy
  schema v4 reports do not get empty v5 bucket segments
- candidate manifest generation now supports explicit
  `--allow-missing-export` for research-only candidates before Sprint 6 runtime
  artifact export

Validation:

- `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`: PASS
- schema v5 fixture segment smoke: PASS, `332` prediction rows and `50`
  segment rows
- schema-v4-compatible segment smoke: PASS, v5-only segment types are omitted
  when v5 columns are absent
- research-only candidate manifest smoke with `--allow-missing-export`: PASS
- missing export without `--allow-missing-export`: fails as expected, preserving
  the runtime artifact gate
- full robustness validation on the small fixture: fails as expected with
  `Not enough rows for robust train_core partition: 260 < 500`

Pending human gate:

- generate full-year XAUUSD 2025 schema v5 Strategy Tester exports for S1, S2,
  and S3
- build strategy-scoped datasets from those exports
- train broker-1R and any selected path-ratio candidates
- run robustness validation and candidate comparison against schema v4
  baselines
- accept or reject each numeric candidate based on final-holdout, support, and
  concentration evidence

## Sprint 6 Gate

Sprint 6 is intentionally blocked. There is no accepted schema v5 numeric
candidate, so no TSV runtime artifact was exported, no Common Files deployment
was performed, and no SHADOW/FILTER Strategy Tester validation was run.

Runtime export can resume only after Sprint 5 accepts an exact dataset/model
candidate and records its threshold source. Until then, `ML_INFERENCE_FILTER`
remains Strategy Tester-only, live deployment remains blocked, and ONNX remains
deferred.

## Sprint 5A Validation

Implemented:

- removed the active deterministic `iMA` logic load path
- replaced deterministic base/macro confirmation reads with `iBands` buffer `0`
  (`BASE_LINE`) using `bands_shift=0`
- scoped deterministic bands logic handles to enabled strategy base/macro
  contexts, plus H1/H4/D1 export diagnostics while feature export is active
- scoped `BB_Percent_Standard` logic handles to enabled strategy base/macro
  contexts when feature export or ML inference requires them
- added visual-only `BB_Percent_Standard` handles for active strategy M1 and
  macro contexts
- attached visual `%B` handles to chart subwindows while keeping data/logic
  handles hidden and separate
- kept visual `iBands` handles for price-chart delayed band QA

Validation:

- `rg` check for active `iMA`, `LoadDeterministicMaLogicIndicators`,
  `CopyDeterministicMaSlopeValues`, and `ExtDeterministicMaLogicHandles`: PASS,
  no active matches
- `python3 tools/mt5/compile_mt5.py --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --wine --timeout 120`:
  PASS, `0 errors`, `0 warnings`

Required human-in-the-loop checks before the long XAUUSD 2025 export:

- run one active strategy at a time on M1 with `Enable_Show_Indicators=true`
- S1 visual check:
  - M1 chart shows delayed `iBands` shift `3`
  - M1 chart has `BB_Percent_Standard` shift `3` in a separate window
  - M3 chart shows delayed `iBands` shift `1`
  - M3 chart has `BB_Percent_Standard` shift `1` in a separate window
- S2 visual check:
  - M1 chart shows delayed `iBands` shift `5`
  - M1 chart has `BB_Percent_Standard` shift `5` in a separate window
  - M5 chart shows delayed `iBands` shift `1`
  - M5 chart has `BB_Percent_Standard` shift `1` in a separate window
- S3 visual check:
  - M1 chart shows delayed `iBands` shift `10`
  - M1 chart has `BB_Percent_Standard` shift `10` in a separate window
  - M10 chart shows delayed `iBands` shift `1`
  - M10 chart has `BB_Percent_Standard` shift `1` in a separate window
- run a short visual-on/off parity smoke for the same strategy and settings:
  - feature row counts match
  - candidate counts match
  - no unexpected invalid `%B` feature rows
- keep `ML_Inference_Mode = ML_INFERENCE_DISABLED` for the long export
- keep pattern audit overlay and heavy logs disabled for bulk export
- do not proceed to Sprint 6 until Sprint 5 full-year research accepts an exact
  dataset/model/threshold candidate
