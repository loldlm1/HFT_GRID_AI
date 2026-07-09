# ML Numeric XGBoost Feature Spike

**Date**: 2026-07-08
**Roadmap Phase**: Phase 5 - Numeric XGBoost Feature Spike
**Status**: COMPLETED_AND_ARCHIVED on 2026-07-09. S1 schema v5 data path
validated; S1 numeric candidates rejected for runtime promotion.
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
- `b_percent_main_base`: `%B` derived from the standard `iBands` logic handle
  on M1, with `period=21`, `deviation=2.0`, `bands_shift=0`, SMA base line,
  and `PRICE_CLOSE`. The feature reads close at `read_shift` and upper/lower
  bands at `read_shift + candle_shift`, where `candle_shift` is `3`, `5`, or
  `10` for S1/S2/S3. Formula:
  `(close - lower_band) / (upper_band - lower_band) * 100`.
- `b_percent_main_base_slope`: confirmed absolute delta between derived `%B`
  values at `read_shift=1` and `read_shift=2` from the same base timeframe and
  strategy candle shift.
- `b_percent_main_macro`: `%B` derived from the standard `iBands` logic handle
  on the strategy macro timeframe: M3 for S1, M5 for S2, M10 for S3. It uses
  `period=21`, `deviation=2.0`, `bands_shift=0`, SMA base line,
  `PRICE_CLOSE`, and `candle_shift=1`.
- `b_percent_main_macro_slope`: confirmed absolute delta between derived `%B`
  values at `read_shift=1` and `read_shift=2` from the same macro timeframe.
- `time_sin` and `time_cos`: broker minute-of-day cyclical encoding.

All `%B` reads must be confirmed non-forming values. Runtime/data extraction
uses standard `iBands` logic handles with `bands_shift=0`, not chart-shifted
visual handles. `BB_Percent_Standard` remains visual-only QA for base and macro
subwindows.

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
| 2. MQL5 Numeric Feature Export | Implementation complete | MetaEditor compile PASS with 0 errors and 0 warnings. S1 one-month Strategy Tester export smoke validates schema v5 after the `iBands` `%B` remediation; S2/S3 fresh exports remain pending. |
| 3. Visual Bands QA | Implementation complete | Visual `iBands` handles compile. Human Strategy Tester screenshot and visual/data row-count comparison remain pending. |
| 4. Python Schema And Trainer | Complete | `py_compile`, schema v5 dataset fixture, and numeric XGBoost smoke training PASS. |
| 5. Fresh Data And Robustness Gate | Tooling complete, S1 long candidate rejected | S1 one-month smoke validates schema v5, and S1 2024-2025 re-export trains end-to-end, but no target family produces an accepted threshold. Full acceptance still requires accepted S1/S2/S3 evidence. |
| 5A. Pre-Run Indicator Cleanup | Complete, human visual gate pending | Deterministic `iMA` logic handles replaced by `iBands` base-line handles; visual `%B` handles added for base and macro QA. |
| 6. Runtime Artifact Gate | Blocked | No accepted numeric candidate exists yet, so runtime export and SHADOW parity are not executed. |

## Sprint 2 Validation

Implemented:

- schema version bumped to `5` for signal feature export and shadow feature
  extraction
- initially cached `BB_Percent_Standard` logic handles for M1 base shifts
  `3`, `5`, `10` and macro M3/M5/M10 shift `1`; this data path was later
  superseded by direct standard `iBands` `%B` derivation after the macro `%B`
  null audit
- confirmed `%B` reads with `read_shift=1` and slopes from
  `read_shift=1` minus `read_shift=2`
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

- repeat schema v5 export smoke for S2 and S3 with one active strategy
- verify generated `signal_features.tsv` has zero unexpected invalid numeric
  rows for S2/S3

## Sprint 3 Validation

Implemented:

- base visual handles now use `iBands` on M1 with strategy shifts `3`, `5`,
  or `10` when `Enable_Show_Indicators` is enabled
- macro visual chart handles now use `iBands` on M3/M5/M10 with shift `1`
- visual handles remain separate from logic/data handles
- trading and feature extraction do not read from chart-shifted visual `iBands`

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
- removed runtime/data dependence on `BB_Percent_Standard`; data `%B` is
  derived from standard `iBands` logic handles
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

## S1 2024-2025 Pre-Remediation Export Audit

This section records the rejected export before direct `iBands` `%B`
remediation. The same run ID was later regenerated and audited in the next
section.

Audited run:

- Run ID: `xauusd_2025_dynamic_tp_path_run_S1`
- Date range in manifest/summary: `2024.01.01 00:00:00` through
  `2025.12.31 21:57:58`
- Strategy scope: S1 enabled, S2/S3 disabled
- Schema: `5`
- Feature rows: `23735`
- Outcome rows: `23735`
- Joined rows: `23735`
- Export status: `OK`

Validation results:

- `build_dataset.py --validate-only`: PASS with warnings
- Warnings:
  - `23735` feature rows were marked invalid by Phase 1
  - `4` SL outcome rows had non-negative `net_profit` while `profit_r` was
    negative
- Required schema v5 numeric feature audit:
  - `direction`: `0` missing
  - `stoch_structure_raw_percent`: `11` missing
  - `b_percent_main_base`: `0` missing
  - `b_percent_main_base_slope`: `0` missing
  - `b_percent_main_macro`: `23735` missing
  - `b_percent_main_macro_slope`: `23735` missing
  - `session_id`: `0` missing
  - `time_sin`: `0` missing
  - `time_cos`: `0` missing
- Temporary dataset build for broker-1R produced `training_matrix=0`.

Decision:

- No XGBoost model was trained from this run because the active
  `schema_v5_numeric_xgb` contract requires macro `%B` features.
- The run is useful as failure evidence only. It must not be used to accept,
  export, or compare numeric candidates.

Remediation:

- Data `%B` extraction was changed to derive base and macro `%B` directly from
  standard `iBands` logic handles:
  - close value at `read_shift`
  - upper/lower bands at `read_shift + candle_shift`
  - `(close - lower) / (upper - lower) * 100`
- `BB_Percent_Standard` remains visual-only QA for M1 and macro chart
  inspection.
- MetaEditor compile after remediation: PASS, `0 errors`, `0 warnings`.

Follow-up status:

- Completed by the S1 2024-2025 re-export audit below.
- The regenerated run confirms that `b_percent_main_macro` and
  `b_percent_main_macro_slope` are no longer all-null.

## S1 2026 One-Month Smoke Audit

Audited run:

- Run ID: `xauusd_2025_dataset_1`
- Date range in manifest/summary: `2026.06.07 00:00:00` through
  `2026.07.06 23:59:58`
- Strategy scope: S1 enabled, S2/S3 disabled
- Schema: `5`
- Feature rows: `946`
- Outcome rows: `946`
- Joined rows: `946`
- Export status: `OK`
- Phase 1 invalid rows: `0` feature rows, `1` outcome row

Required schema v5 numeric feature audit:

| Feature | Missing Rows | Observed Range |
| --- | ---: | --- |
| `stoch_structure_raw_percent` | 0 | `14.893430` to `271.773221` |
| `b_percent_main_base` | 0 | `-81.920914` to `183.155623` |
| `b_percent_main_base_slope` | 0 | `-67.281241` to `93.013396` |
| `b_percent_main_macro` | 0 | `-4.121871` to `108.127109` |
| `b_percent_main_macro_slope` | 0 | `-60.460228` to `83.102736` |
| `time_sin` | 0 | `-0.999962` to `1.000000` |
| `time_cos` | 0 | `-0.999990` to `0.999962` |

Categorical support:

- Direction rows: `BEARISH=498`, `BULLISH=448`
- Session rows: `NEWYORK=346`, `ASIA=307`, `LONDON=222`, `OFFHOURS=71`

Outcome support:

- Broker/tester terminal outcomes: `SL=491`, `TP=455`
- Path targets: `1r=444`, `1_5r=343`, `2r=291`, `3r=224`
- Path labels include one non-trainable row from run end/horizon handling.

Datasets built:

| Target Family | Dataset ID | Training Rows |
| --- | --- | ---: |
| `broker_1r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_broker_1r_smoke` | 946 |
| `1r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_1r_smoke` | 945 |
| `1_5r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_1_5r_smoke` | 945 |
| `2r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_2r_smoke` | 945 |
| `3r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_3r_smoke` | 945 |
| `expected_r` | `xauusd_s1_20260607_20260706_schema_v5_numeric_expected_r_smoke` | 945 |

Model smoke results:

| Target Family | Model ID Suffix | Holdout AUC | Holdout F1 | Threshold Candidate |
| --- | --- | ---: | ---: | --- |
| `broker_1r` | `broker_1r_xgb_smoke` | 0.6032 | 0.5587 | yes, threshold `0.55`, 35 selected rows |
| `1r` | `1r_xgb_smoke` | 0.5800 | 0.4940 | yes, threshold `0.50`, 74 selected rows |
| `1_5r` | `1_5r_xgb_smoke` | 0.5724 | 0.0000 | no |
| `2r` | `2r_xgb_smoke` | 0.5509 | 0.0294 | no |
| `3r` | `3r_xgb_smoke` | 0.5341 | 0.0000 | no |
| `expected_r` | `expected_r_xgb_smoke` | 0.5171 | 0.0000 | no |

Feature diagnostics:

- All models encoded `13` features after deterministic one-hot encoding.
- No encoded feature had zero variation.
- The leading classifier features are aligned with the intended contract:
  `stoch_structure_raw_percent`, `%B` base, `%B` base slope, `%B` macro,
  session, and time features.
- `direction` appears as a meaningful feature in `expected_r`, but the model is
  not accepted because the holdout target quality is weak.

Robustness validation:

- Default robustness validation failed for all target families with
  `Not enough rows for robust train_core partition: 473 < 500`.
- A relaxed smoke-only robustness pass was generated only for `broker_1r` and
  `1r`:
  - `broker_1r`: `WARN`, threshold `0.60`, final-holdout selected rows `13`,
    warnings include short dataset, missing runtime export, small selected
    final-holdout count, feature-importance concentration, and segment support.
  - `1r`: `WARN`, threshold `0.50`, final-holdout selected rows `74`,
    warnings include short dataset, missing runtime export,
    feature-importance concentration, and segment support.

Decision:

- The short S1 smoke validates the schema v5 data path after the direct
  `iBands` `%B` remediation: macro `%B` is no longer all-null.
- XGBoost training works end-to-end for broker and path target families.
- The run is smoke-only and must not be used to accept, export, or deploy a
  model.
- Sprint 6 remains blocked until full-year S1/S2/S3 exports produce a candidate
  that passes the default robustness gate and segment support requirements.

## S1 2024-2025 Re-Export Candidate Audit

Audited run:

- Run ID: `xauusd_2025_dynamic_tp_path_run_S1`
- Date range in manifest/summary: `2024.01.01 00:00:00` through
  `2025.12.31 21:57:58`
- Strategy scope: S1 enabled, S2/S3 disabled
- Schema: `5`
- Feature rows: `23746`
- Outcome rows: `23746`
- Joined rows: `23746`
- Export status: `OK`
- Phase 1 invalid rows: `11` feature rows, `0` outcome rows

Validation results:

- `build_dataset.py --validate-only`: PASS with warnings
- Warnings:
  - `11` feature rows were marked invalid by Phase 1
  - `2` TP outcome rows had non-positive `net_profit` while `profit_r` was
    positive
  - `4` SL outcome rows had non-negative `net_profit` while `profit_r` was
    negative

Required schema v5 numeric feature audit:

| Feature | Missing Rows | Observed Range |
| --- | ---: | --- |
| `stoch_structure_raw_percent` | 11 | `13.357809` to `908.547009` |
| `b_percent_main_base` | 0 | `-253.273649` to `361.257059` |
| `b_percent_main_base_slope` | 0 | `-355.154179` to `219.728507` |
| `b_percent_main_macro` | 0 | `-29.492783` to `186.111471` |
| `b_percent_main_macro_slope` | 0 | `-147.671555` to `218.167410` |
| `time_sin` | 0 | `-1.000000` to `1.000000` |
| `time_cos` | 0 | `-1.000000` to `0.999990` |

Categorical support:

- Direction rows: `BULLISH=12573`, `BEARISH=11173`
- Session rows: `NEWYORK=9383`, `ASIA=7380`, `LONDON=5368`,
  `OFFHOURS=1615`

Outcome support:

- Broker/tester terminal outcomes: `SL=13329`, `TP=10417`
- Path targets: `1r=9940`, `1_5r=8083`, `2r=6802`, `3r=5124`
- Path statuses: `SL_FIRST=18609`, `TARGET_3R=5124`,
  `HORIZON_EXPIRED=13`
- Mean broker `profit_r`: `-0.173713`

Datasets built:

| Target Family | Dataset ID | Training Rows |
| --- | --- | ---: |
| `broker_1r` | `xauusd_s1_2024_2025_schema_v5_numeric_broker_1r` | 23735 |
| `1r` | `xauusd_s1_2024_2025_schema_v5_numeric_1r` | 23735 |
| `1_5r` | `xauusd_s1_2024_2025_schema_v5_numeric_1_5r` | 23735 |
| `2r` | `xauusd_s1_2024_2025_schema_v5_numeric_2r` | 23735 |
| `3r` | `xauusd_s1_2024_2025_schema_v5_numeric_3r` | 23735 |
| `expected_r` | `xauusd_s1_2024_2025_schema_v5_numeric_expected_r` | 23735 |

Model results:

| Target Family | Holdout AUC | Holdout F1 | Holdout Max Score | Threshold Candidate |
| --- | ---: | ---: | ---: | --- |
| `broker_1r` | 0.5088 | 0.0000 | 0.452669 | no |
| `1r` | 0.5060 | 0.0000 | 0.414091 | no |
| `1_5r` | 0.4992 | 0.0000 | 0.348207 | no |
| `2r` | 0.4977 | 0.0000 | 0.297827 | no |
| `3r` | 0.4920 | 0.0000 | 0.219700 | no |
| `expected_r` | 0.4924 | 0.0000 | 0.220213 | no |

Feature diagnostics:

- All models encoded `13` features after deterministic one-hot encoding.
- No encoded feature had zero variation.
- No rare categorical bucket warning was emitted.
- Top classifier features remain plausible schema v5 signals, but they do not
  generalize into useful selection:
  - `broker_1r`: `b_percent_main_macro_slope`,
    `stoch_structure_raw_percent`, `b_percent_main_macro`
  - `1r`: `b_percent_main_base`, `b_percent_main_base_slope`,
    `direction=BEARISH`
  - higher path targets: mostly `session_id=ASIA`, time features, direction,
    and `%B` macro/base fields
- Robustness diagnostics warn about feature-importance concentration in all
  targets. This is not the primary failure; the primary failure is that no
  threshold selects rows.

Robustness validation:

- Default robustness validation ran for all target families and produced
  `research_candidate` grade datasets.
- All target families returned `WARN`, `selected_threshold=null`, and
  `final_holdout_selected_rows=0`.
- Warning codes were consistent across all targets:
  - `runtime_export_missing`
  - `threshold_selection_small_selected_count`
  - `final_holdout_small_selected_count`
  - `feature_importance_concentration`
  - `segment_support_warnings`
- Score diagnostics confirm that final-holdout probabilities are below `0.50`
  for every target. Example final max scores:
  - `broker_1r`: `0.452669`
  - `1r`: `0.414091`
  - `3r`: `0.219700`

Implementation note:

- The exporter manifest label was corrected from the old
  `BB_Percent_Standard` data-source text to the current direct `iBands`
  `%B` source:
  `iBands:upper_lower_close:period_21:deviation_2.0:bands_shift_0:PRICE_CLOSE`
- Validation after the manifest-label fix:
  - `git diff --check`: PASS
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`: PASS
  - `python3 tools/mt5/compile_mt5.py --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --wine --timeout 120`:
    PASS, `0 errors`, `0 warnings`

Decision:

- The S1 2024-2025 re-export validates that the schema v5 data path is now
  technically healthy: macro `%B` is non-null and datasets train end-to-end.
- No S1 target family is accepted because the model does not produce an
  admissible threshold candidate and the final holdout selects zero rows.
- Sprint 6 runtime artifact export, SHADOW parity, and FILTER smoke remain
  blocked.
- Next evidence needed before revisiting runtime export:
  - full S2 and S3 schema v5 exports
  - optional S1 ablation outside this phase gate, such as per-direction models
    or threshold-policy research, if the product decision is to keep exploring
    S1 despite this rejection
