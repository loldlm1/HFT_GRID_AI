# Plan: ML Numeric XGBoost Feature Spike

**Generated**: 2026-07-08
**Estimated Complexity**: High
**Roadmap Phase**: Phase 5 of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, EA/Python/model artifact contract, Strategy Tester data
collection, statistical validation, and visual indicator parity. This phase is
research-only unless a later plan explicitly approves runtime FILTER use.

## Overview

This phase researches a compact numeric XGBoost feature contract before the
ONNX shadow spike. The current schema v4 semantic lanes remain valuable for
DuckDB pattern audits, but schema v4 depth-5 XGBoost candidates did not produce
a robust final-holdout threshold. This phase separates the two roles:

- keep schema v4-style semantic lanes available for DuckDB pattern analysis
- add a compact strategy-clock-aligned numeric XGBoost feature set
- train conservative `tree_method=hist`, `max_bin=256`, `max_depth=3`
  candidates
- validate whether the new feature set improves out-of-sample selection before
  any ONNX runtime work

Initial research trains one active strategy at a time and includes `direction`
as a model feature. Direction-aware segment reports remain mandatory so a
single direction cannot hide weak or inverted behavior.

The active numeric XGBoost feature set is:

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

Feature semantics:

- `stoch_structure_raw_percent` is the raw structure percent of the source
  extremum/SL anchor within the Stoch Structure range. It is conceptually the
  raw value currently used before `fib_sl_band`, not the live close percent and
  not the raw oscillator value.
- `b_percent_main_base` derives `%B` from the standard `iBands` logic handle
  on M1, with `period=21`, `deviation=2.0`, `bands_shift=0`, SMA base line,
  and `PRICE_CLOSE`. It reads close at `read_shift` and upper/lower bands at
  `read_shift + candle_shift`, where `candle_shift` is the strategy base delay
  (`3`, `5`, or `10`).
- `b_percent_main_base_slope` is the confirmed absolute delta between derived
  `%B` values at `read_shift=1` and `read_shift=2` from the same base
  timeframe and strategy candle shift.
- `b_percent_main_macro` derives `%B` from the standard `iBands` logic handle
  on the strategy macro timeframe (`M3`, `M5`, or `M10`), with
  `candle_shift=1`, SMA base line, and `PRICE_CLOSE`.
- `b_percent_main_macro_slope` is the confirmed absolute delta between derived
  `%B` values at `read_shift=1` and `read_shift=2` from the same macro
  timeframe.
- `session_id` is the broker-time session bucket, treated as categorical for
  model encoding and as a diagnostic segment.
- `time_sin` and `time_cos` encode broker minute-of-day cyclically.

The visual layer may use `iBands` with `bands_shift` for chart alignment, but
runtime data features must use non-forming confirmed values and must not depend
on chart drawing.

## Prerequisites

- Phase 3 schema v4 closeout is complete.
- Phase 4 dynamic TP/path-ratio labels are available or explicitly deferred for
  the first broker-1R research pass.
- Current accepted workflow reference:
  `docs/workflows/deterministic-signal-ml-inference-flows.md`.
- Current evidence reference:
  `docs/research/ml-feature-schema-v2-acceptance.md`.
- `BB_Percent_Standard.ex5` is available in the same MT5 `Examples` indicator
  path used for `Stochastic_Structure.ex5` only for visual QA subwindows; data
  features derive `%B` directly from `iBands`.
- MetaEditor compile workflow from
  `docs/environment/mt5-agentic-workflows.md`.
- Human-in-the-loop Strategy Tester remains required for fresh XAUUSD 2025
  exports and visual confirmation.
- Current XGBoost documentation confirms `max_bin` applies to histogram bins
  for numeric features under `hist`, and overfit controls should combine lower
  `max_depth`, `min_child_weight`, `gamma`, regularization, subsampling, and
  chronological validation.
- Current MQL5 `iBands` documentation confirms buffer ordering
  `0=BASE_LINE`, `1=UPPER_BAND`, `2=LOWER_BAND`; visual use of `bands_shift`
  must remain separate from runtime feature reads.

Generated raw exports, datasets, models, reports, playback files, screenshots,
and Common Files packages remain out of git.

## Non-Goals

- No live deployment approval.
- No ONNX work in this phase.
- No runtime TP modification.
- No ML FILTER approval unless the research and runtime gates in this plan
  pass.
- No use of path-label columns as model features.
- No replacement of schema v4 DuckDB pattern audit lanes.
- No custom MQL5 tests or CI.
- No weakening of license, session, spread, stops/freeze, margin, protection,
  market-status, magic-number, or broker reconciliation guards.

## Sprint 1: Numeric Feature Contract

**Goal**: Define the schema, feature semantics, validation gates, and evidence
files before code changes.
**Commit**: `docs: define numeric xgboost feature spike`
**Demo/Validation**:

- Contract names all numeric/categorical model inputs.
- Contract distinguishes DuckDB pattern lanes from XGBoost numeric lanes.
- Contract states that direction is a feature for the first strategy-scoped
  pass.
- No MQL5 behavior changes.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Record Phase Contract

- **Location**:
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Document the numeric feature contract, source-of-truth
  calculations, feature precision policy, target-family scope, and acceptance
  gates.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - `stoch_structure_raw_percent` is documented as source-extremum/SL-anchor
    raw percent, not live close percent.
  - `%B` features state the direct `iBands` formula, `PRICE_CLOSE`,
    confirmed reads, and strategy-aligned candle shifts.
  - `direction` and `session_id` are documented as categorical model inputs.
  - Visual `iBands` behavior is documented as QA-only.
- **Validation**:
  - Manual contract review.

### Task 1.2: Define Evidence Layout

- **Location**:
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
  - generated folders under `artifacts/datasets/`, `artifacts/models/`,
    and MT5 Common Files
- **Description**: Define run IDs, dataset IDs, model IDs, report paths, and
  ignored evidence files before producing fresh data.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - S1/S2/S3 one-strategy-at-a-time run IDs are listed.
  - Candidate model IDs distinguish strategy, target family, and feature set.
  - Required reports include validation metrics, robustness reports, threshold
    selection, segment metrics, score diagnostics, and feature importance.
- **Validation**:
  - Manual review against generated-artifact policy.

## Sprint 2: MQL5 Numeric Feature Export

**Goal**: Export the numeric feature set and keep runtime scorer feature
extraction aligned with the new schema.
**Commit**: `feat: export numeric xgboost features`
**Demo/Validation**:

- MetaEditor compile passes with no errors or warnings.
- A short Strategy Tester export writes the new feature columns with zero
  unexpected invalid rows.
- Existing broker/risk behavior is unchanged.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add `%B` Indicator Inputs

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/core/base_structures.mqh` only if handle metadata needs extension
- **Description**: Load and release cached standard `iBands` logic handles for
  enabled strategy base/macro timeframes. The `%B` value is computed from
  close, upper band, and lower band reads instead of a runtime `iCustom`
  `%B` handle.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Handles are created once during indicator loading and released on deinit.
  - Parameters are explicit: period `21`, deviation `2.0`, `bands_shift=0`,
    SMA base line, and `PRICE_CLOSE`.
  - Logic handles are hidden in Strategy Tester where appropriate.
  - No per-tick or per-signal `iCustom` handle creation is introduced.
- **Validation**:
  - MetaEditor compile.

### Task 2.2: Add Confirmed `%B` Read Helpers

- **Location**:
  - `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Add helpers that compute `%B` from standard `iBands` upper
  and lower buffers plus confirmed close reads, then compute absolute slopes.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Base value uses close at `read_shift=1` and M1 bands at
    `read_shift + strategy_delay`.
  - Base slope is derived `%B(read_shift=1) - %B(read_shift=2)`.
  - Macro value uses close at `read_shift=1` and macro bands at
    `read_shift + 1`.
  - Macro slope is derived `%B(read_shift=1) - %B(read_shift=2)`.
  - Missing or `EMPTY_VALUE` data marks features invalid without stopping live
    trading outside tester validation paths.
- **Validation**:
  - MetaEditor compile.
  - Short tester smoke with debug row counts.

### Task 2.3: Export Numeric Snapshot Columns

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Extend the deterministic feature snapshot and shadow source
  lookup with schema v5 numeric columns while preserving schema v4 semantic
  lanes for pattern audit.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - `DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION` and shadow schema version are
    bumped only after schema v5 header support is implemented.
  - `stoch_structure_raw_percent` is derived from the same raw percent source
    used for the SL-anchor Fibonacci band.
  - Numeric feature rows use stable precision suitable for XGBoost binning.
  - `direction`, `session_id`, `time_sin`, and `time_cos` are available in
    both export and shadow normalization paths.
  - Path labels remain outcome-only and excluded from model feature maps.
- **Validation**:
  - Static header check.
  - MetaEditor compile.
  - Short Strategy Tester feature export.

## Sprint 3: Visual Bands QA

**Goal**: Provide optional chart verification that the strategy base and macro
contexts align with delayed Bollinger bands without changing trading behavior.
**Commit**: `feat: add visual bands for deterministic qa`
**Demo/Validation**:

- In visual Strategy Tester, the active strategy shows delayed Bollinger bands
  aligned to the same base and macro clocks used by `%B`.
- Logic handles remain independent from chart drawing.
- Visual changes do not alter feature rows or trade decisions.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Add Base Visual `iBands`

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - optional frontend/chart helper files if existing visual lifecycle requires
    it
- **Description**: Add visual-only M1 `iBands` handles for active strategy
  base shifts, using `bands_period=21`, `bands_shift=3/5/10`, `deviation=2.0`,
  and `PRICE_CLOSE`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Visual bands replace or complement the existing visual shifted SMA for the
    active strategy.
  - Visual handles are attached only when `Enable_Show_Indicators` is true.
  - Visual handles are released cleanly.
  - Trading and feature extraction do not read from visual `iBands` handles.
- **Validation**:
  - MetaEditor compile.
  - Human visual Strategy Tester screenshot review.

### Task 3.2: Add Macro Visual `iBands`

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Add visual-only macro chart `iBands` handles for M3/M5/M10
  with `bands_shift=1`.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - S1 opens or reuses M3 visual context, S2 M5, and S3 M10.
  - Macro visual bands follow the same timeframe and shift as macro
    confirmation.
  - Closing/deinit cleanup handles chart-owned resources safely.
- **Validation**:
  - MetaEditor compile.
  - Human visual Strategy Tester screenshot review.

### Task 3.3: Verify Visual/Data Separation

- **Location**:
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
  - generated visual QA screenshots outside git
- **Description**: Record evidence that visual `iBands` alignment is QA-only
  and does not affect numeric feature rows.
- **Dependencies**: Tasks 3.1 and 3.2.
- **Acceptance Criteria**:
  - One short run with visuals disabled and one with visuals enabled produce
    matching feature row counts and candidate counts.
  - Evidence states that `%B` features come from direct `iBands` data reads,
    not chart-shifted visual handles.
- **Validation**:
  - Short Strategy Tester comparison.

## Sprint 4: Python Schema And Trainer

**Goal**: Build schema v5 datasets and train conservative numeric XGBoost
candidates.
**Commit**: `ml: train numeric xgboost candidates`
**Demo/Validation**:

- Python syntax checks pass.
- A fixture or small smoke dataset builds with schema v5 columns.
- Training reports show numeric feature importances and direction/session
  diagnostics.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Extend Schema Contract

- **Location**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Add schema v5 feature columns, numeric/categorical
  classifications, and dataset report sections for the numeric XGBoost lane.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Schema v5 accepts fresh numeric feature exports and rejects stale schema v4
    exports by default.
  - Model feature columns for the numeric feature set are explicit.
  - `direction` and `session_id` are categorical.
  - `stoch_structure_raw_percent`, `%B` values, slopes, `time_sin`, and
    `time_cos` are numeric.
  - Path ratio outcome columns remain excluded from `MODEL_FEATURE_COLUMNS`.
- **Validation**:
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`
  - Small fixture dataset build.

### Task 4.2: Add Numeric Feature Set Training

- **Location**:
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Add a `schema_v5_numeric_xgb` feature set and conservative
  XGBoost configuration for compact numeric training.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Classifier and regressor use `tree_method=hist`, `max_bin=256`, and
    `max_depth=3`.
  - Training manifests record numeric feature set, params, encoded feature
    count, and target family.
  - Reports include feature importances, probability distribution, and
    direction/session segment summaries.
  - Existing schema v4 training paths remain available unless explicitly
    retired in a later plan.
- **Validation**:
  - Python syntax checks.
  - Fixture training smoke.

### Task 4.3: Add Strategy-Scoped Candidate Commands

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
- **Description**: Document commands for S1, S2, and S3 strategy-scoped
  datasets and model candidates with `direction` included as a feature.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Commands cover `broker_1r` and any available Phase 4 path target families.
  - Model IDs distinguish strategy and target family.
  - Per-direction model ablation is documented as optional research follow-up,
    not the first-pass default.
- **Validation**:
  - Manual command review.

## Sprint 5: Fresh Data And Robustness Gate

**Goal**: Generate fresh XAUUSD 2025 numeric datasets, train candidates, and
decide whether the feature set improves robust out-of-sample selection.
**Commit**: `ml: evaluate numeric xgboost feature spike`
**Demo/Validation**:

- Fresh S1/S2/S3 datasets build from Strategy Tester exports.
- Robustness reports compare numeric candidates against schema v4 research
  baselines.
- Evidence records accept/reject decisions without using final holdout for
  threshold selection.

Execution must complete and validate this sprint before moving to Sprint 6.

Current status:

- S1 2024-2025 re-export builds schema v5 datasets and trains all target
  families, but every model is rejected: no target produces a selected
  threshold and final holdout selected rows are zero.
- Sprint 6 remains blocked for S1.
- S2 and S3 full exports are still required before deciding whether the phase
  is fully rejected or whether a non-S1 strategy has an acceptable candidate.

### Task 5.1: Generate Fresh Strategy Exports

- **Location**:
  - MT5 Common Files generated run folders
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
- **Description**: Run one strategy at a time with ML disabled and feature
  export enabled for XAUUSD 2025.
- **Dependencies**: Sprint 4 and human Strategy Tester run.
- **Acceptance Criteria**:
  - S1, S2, and S3 exports use identical symbol, date range, spread/cost,
    session, risk, and execution settings except strategy booleans and run IDs.
  - `ML_Inference_Mode = ML_INFERENCE_DISABLED`.
  - Pattern audit overlay and heavy logs are disabled for bulk export.
  - Feature invalid rows are zero or bounded and explained.
- **Validation**:
  - Dataset validate-only command per run.

### Task 5.2: Build Numeric Datasets

- **Location**:
  - `artifacts/datasets/`
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
- **Description**: Build strategy-scoped datasets for the broker-1R target and
  any Phase 4 path target family under review.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Training matrix rows match valid feature/outcome joins.
  - Dataset manifests record schema v5 and feature set.
  - Reports include direction, session, time, `%B`, and raw structure percent
    distributions.
- **Validation**:
  - Dataset build commands.

### Task 5.3: Train And Validate Candidates

- **Location**:
  - `artifacts/models/`
  - `tools/deterministic_signal_ml/validate_model_robustness.py`
  - `tools/deterministic_signal_ml/compare_model_candidates.py`
  - optional score diagnostics tooling
- **Description**: Train strategy-scoped numeric candidates and run hardened
  robustness validation.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Threshold selection uses pre-final out-of-fold or threshold-selection rows,
    never final holdout.
  - Final holdout selected rows, mean R, net R, and drawdown are reported.
  - Reports include bullish/bearish, session, and score-bucket diagnostics.
  - Numeric candidates are compared against schema v4 research baselines and
    simple baselines.
  - Candidates fail if selected evidence is concentrated in one month, one
    session bucket, or one direction without support.
- **Validation**:
  - Training command per candidate.
  - Robustness command per candidate.
  - Candidate comparison command.

### Task 5.4: Decide Research Outcome

- **Location**:
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
  - optional follow-up plan under `docs/plans/`
- **Description**: Decide whether the numeric feature set is accepted,
  rejected, or requires a narrower follow-up.
- **Dependencies**: Task 5.3.
- **Acceptance Criteria**:
  - Accepted candidates list exact dataset, model, target family, feature set,
    params, and threshold source.
  - Rejected candidates list blocking evidence.
  - Runtime FILTER remains blocked unless the runtime gate in Sprint 6 passes.
  - ONNX remains blocked until this phase concludes.
- **Validation**:
  - Manual gate review.

## Sprint 5A: Pre-Run Indicator Cleanup

**Goal**: Remove redundant deterministic `iMA` logic handles before the long
Strategy Tester export and add visual `%B` QA for the active strategy base and
macro clocks.
**Commit**: `refactor: align deterministic bands indicators`
**Demo/Validation**:

- MetaEditor compile passes with no errors or warnings.
- A short visual Strategy Tester run for one active strategy shows:
  - delayed `iBands` on M1
  - delayed `iBands` on the strategy macro chart
  - `BB_Percent_Standard` on M1 in a separate window
  - `BB_Percent_Standard` on the macro chart in a separate window
- Visual-enabled and visual-disabled short runs produce matching feature row
  counts and candidate counts.
- Broker/risk/order lifecycle behavior remains unchanged.

This sprint is a pre-run cleanup and must not promote any runtime model.

### Task 5A.1: Replace Logic `iMA` Handles With Bands Base-Line

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**: Replace deterministic logic `iMA` handles with `iBands`
  handles using `bands_shift=0` and read buffer `0` (`BASE_LINE`) as the SMA
  source.
- **Dependencies**: Sprint 5 tooling.
- **Acceptance Criteria**:
  - No `LoadDeterministicMaLogicIndicators()` path remains active.
  - Base and macro confirmation still read the same logical shifts as before.
  - Only active strategy base/macro timeframes are loaded, plus explicitly
    required export diagnostics.
- **Validation**:
  - MetaEditor compile.
  - Short Strategy Tester parity run.

### Task 5A.2: Keep `%B` Data Reads Strategy-Scoped

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Keep standard `iBands` data handles scoped to enabled
  strategy base and macro timeframes when feature export or ML inference
  requires `%B`.
- **Dependencies**: Task 5A.1.
- **Acceptance Criteria**:
  - S1 computes M1 candle shift `3` and M3 candle shift `1`.
  - S2 computes M1 candle shift `5` and M5 candle shift `1`.
  - S3 computes M1 candle shift `10` and M10 candle shift `1`.
  - Duplicate handles are avoided when strategies share a timeframe/shift.
- **Validation**:
  - MetaEditor compile.
  - Short schema v5 export smoke.

### Task 5A.3: Add Visual `%B` QA Handles

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Add visual-only `BB_Percent_Standard` handles for the active
  strategy base and macro contexts and attach them to chart subwindows.
- **Dependencies**: Task 5A.2.
- **Acceptance Criteria**:
  - Visual `%B` handles are not hidden with `TesterHideIndicators`.
  - Base `%B` attaches to the current M1 chart in a separate window.
  - Macro `%B` attaches to the opened macro chart in a separate window.
  - Logic/data extraction handles remain separate from visual handles.
  - Deinit removes visual indicators and releases all handles.
- **Validation**:
  - MetaEditor compile.
  - Human visual Strategy Tester screenshot review.

### Task 5A.4: Record Manual Run Gates

- **Location**:
  - `docs/research/ml-numeric-xgboost-feature-spike.md`
- **Description**: Record the manual visual/parity checklist required before
  the long XAUUSD 2025 export run and before Sprint 6 can resume.
- **Dependencies**: Tasks 5A.1 through 5A.3.
- **Acceptance Criteria**:
  - Human-in-the-loop visual checks are listed by strategy.
  - Visual-on/off row-count parity is required.
  - Runtime FILTER, live deployment, and ONNX remain blocked.
- **Validation**:
  - Manual documentation review.

## Sprint 6: Runtime Artifact Gate

**Goal**: Export only accepted numeric candidates to the existing TSV scorer
path and prove Python/MQL5 parity before ONNX work.
**Commit**: `ml: validate numeric xgboost runtime artifact`
**Demo/Validation**:

- Exported TSV artifacts validate against Python scorer.
- Strategy Tester SHADOW parity passes.
- FILTER remains Strategy Tester-only and is approved only if the research
  threshold and runtime gates pass.

Execution must complete and validate this sprint before phase closeout.

### Task 6.1: Export Accepted Numeric Artifact

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
  - Common Files model export folder
- **Description**: Export an accepted numeric candidate using the existing TSV
  tree scorer contract.
- **Dependencies**: Sprint 5 acceptance.
- **Acceptance Criteria**:
  - Export includes schema v5 feature map and positive threshold policy.
  - Artifact validator passes Python scorer parity.
  - `mt5_runtime_ready` remains false unless all gates pass.
- **Validation**:
  - Model artifact validator command.

### Task 6.2: Run SHADOW Parity

- **Location**:
  - MT5 Common Files shadow run folder
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
- **Description**: Run Strategy Tester in SHADOW mode and compare MQL5 scores
  against Python predictions.
- **Dependencies**: Task 6.1 and human Strategy Tester run.
- **Acceptance Criteria**:
  - Scored rows are nonzero.
  - Invalid feature rows are zero or explicitly explained.
  - Python/MQL5 classifier and regressor parity remain within accepted
    tolerance.
  - Runtime diagnostics fail visibly without affecting trading behavior.
- **Validation**:
  - Shadow prediction comparison command.

### Task 6.3: Optional FILTER Smoke

- **Location**:
  - MT5 Common Files shadow/filter run folder
  - `tools/deterministic_signal_ml/summarize_filter_run.py`
- **Description**: If SHADOW parity and research thresholds pass, run a
  Strategy Tester-only FILTER smoke validation.
- **Dependencies**: Task 6.2 and explicit research acceptance.
- **Acceptance Criteria**:
  - FILTER remains blocked outside Strategy Tester.
  - Existing broker/risk gates run before ML admission.
  - Arbitration counters remain valid.
  - FILTER decisions agree with Python threshold decisions.
- **Validation**:
  - Filter summary and Python/MQL5 decision comparison commands.

## Testing Strategy

- Documentation-only sprint: manual contract review.
- MQL5 implementation sprints: `git diff --check` plus MetaEditor real compile
  once per sprint end.
- Short Strategy Tester smoke before full-year exports.
- Full-year XAUUSD 2025 Strategy Tester data collection one strategy at a time.
- Python tooling: `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`.
- Dataset validation: `build_dataset.py --validate-only` before writing
  datasets.
- Model validation: chronological holdout, walk-forward folds, threshold
  selection outside final holdout, segment diagnostics, score diagnostics, and
  candidate comparison.
- Runtime validation only for accepted research candidates: artifact validator,
  SHADOW parity, and optional Strategy Tester-only FILTER smoke.

## Acceptance Criteria

- Schema v5 numeric datasets build from fresh Strategy Tester exports.
- Numeric feature rows use only pre-entry deterministic information.
- `direction` is included as a first-pass feature and reported as a required
  segment.
- `%B` features use confirmed non-forming reads and strategy-aligned shifts.
- Visual `iBands` handles do not affect feature extraction or trading behavior.
- A candidate is promoted only when threshold-selection evidence is positive
  and final holdout remains acceptable after costs.
- Selected rows clear support guards overall, by direction, and by important
  session segments.
- No model is accepted if edge is concentrated in a single month, session, or
  direction without enough support.
- Python/MQL5 parity remains within accepted tolerance before any runtime use.

## Potential Risks And Gotchas

- `direction` may consume tree depth in `max_depth=3` models. Mitigation:
  report direction segments and keep per-direction artifacts as a follow-up
  ablation if the first pass is weak or asymmetric.
- `iBands` visual `bands_shift` can align chart drawing differently from
  runtime feature reads. Mitigation: visual handles are QA-only and `%B`
  features come only from standard `iBands` logic handles with
  `bands_shift=0`.
- `stoch_structure_raw_percent` can be confused with live close percent or raw
  oscillator value. Mitigation: derive it from the SL-anchor/source-extremum
  raw percent path and test fixture values explicitly.
- `session_id` can memorize market regimes. Mitigation: require session segment
  support across folds and final holdout.
- Higher numeric precision may expose noise. Mitigation: use conservative
  XGBoost params and compare precision/rounding ablations if needed.
- Fresh schema v5 exports will not be comparable to schema v4 raw files without
  explicit candidate comparison logic. Mitigation: preserve schema v4 datasets
  as baselines and compare via candidate manifests.
- Path-target families can leak if path labels enter features. Mitigation:
  schema contract and dataset builder must keep path columns outcome-only.

## Rollback Plan

- Keep `ML_INFERENCE_DISABLED` as the default runtime mode.
- Keep schema v4 DuckDB pattern audit packages and research evidence intact.
- Keep the existing TSV scorer and accepted smoke export available.
- If schema v5 fails, archive evidence as rejected research and keep ONNX
  blocked until a separate accepted artifact exists.
- If visual `iBands` causes chart or tester instability, revert only the visual
  handles and keep numeric export/training work independent.
