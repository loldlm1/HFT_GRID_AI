# Plan: ML Feature Schema V2

**Generated**: 2026-07-05
**Estimated Complexity**: High
**Roadmap Phase**: Phase 3 of `docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, EA/Python/model artifact contract and Strategy Tester data generation

## Overview

Implement Phase 3 of the ML robustness roadmap: replace the active deterministic
signal ML feature contract with schema version 2, generate a fresh deterministic
XAUUSD 2025 dataset, and prove whether the new feature set can produce a robust
positive threshold without overfitting.

This phase starts by freezing the current schema v1 long baseline as a rejection
baseline:

- Dataset: `xauusd_2025_dataset_1`
- Model: `xauusd_2025_xgb_1`
- Result: no accepted FILTER threshold, holdout ROC AUC near `0.495`, no
  selected rows at thresholds `>= 0.50`, and no valid runtime export.

The active development code may move fully from schema v1 to schema v2 in this
phase. Historical v1 artifacts and evidence stay as frozen baseline references,
but the implementation does not need to keep active dual-version runtime support
unless a sprint discovers that doing so is simpler or safer than replacement.

Phase 3 must not proceed to Phase 4 until schema v2 either passes the acceptance
gate or fails with a documented follow-up `$planner` plan for additional Phase 3
diagnostics and feature iteration.

## Accepted Decisions

- Use the current v1 artifacts as the frozen rejection baseline:
  `xauusd_2025_dataset_1` and `xauusd_2025_xgb_1`.
- Generate a fresh schema v2 deterministic dataset from Strategy Tester for
  XAUUSD covering the full 2025 calendar year: start inclusive
  `2025-01-01 00:00:00`, end exclusive `2026-01-01 00:00:00` where the tester
  supports that boundary, or `2025-12-31 23:59:59` if an inclusive end date is
  required.
- Generate raw deterministic features with ML disabled unless a specific sprint
  is validating runtime SHADOW/FILTER parity after model approval.
- Treat S1, S2, and S3 as one signal archetype at increasing depth, not as
  unrelated strategies.
- Use this depth framing in diagnostics:
  - S1: delay `3`, M3 macro confirmation.
  - S2: delay `5`, M5 macro confirmation.
  - S3: delay `10`, M10 macro confirmation.
- Add features in this order:
  1. structure context
  2. previous closed candle ratios
  3. strategy-depth/context features
  4. direction and macro-trend alignment features
  5. optional coarse session bucket only as a secondary ablation candidate
- Prefer a global model by default. Per-strategy or per-direction thresholds or
  models are allowed only if support counts and segment evidence are stronger
  than the global model.
- Export, deploy, and Strategy Tester parity validation are conditional. They
  run only if schema v2 passes the research acceptance gate.
- If schema v2 fails, document the rejection and create a follow-up Phase 3 plan
  instead of moving to ONNX, multi-symbol research, dynamic targets, or live
  rollout.

## External Documentation Notes

- scikit-learn `TimeSeriesSplit` is appropriate for chronological folds where
  each test fold follows its training fold. Its `gap` parameter excludes samples
  between train and test windows for leakage control:
  https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html
- XGBoost's Python sklearn API supports `fit(...)` with `eval_set`,
  `predict_proba(...)`, `predict(...)`, `feature_importances_`, and eval result
  inspection for validation reporting:
  https://xgboost.readthedocs.io/en/latest/python/python_api.html
- DuckDB can query Parquet with `read_parquet(...)` and export query results
  through `COPY (...) TO ... (FORMAT parquet)` or CSV writers:
  https://duckdb.org/docs/current/

## Prerequisites

- Phase 1 validation hardening evidence exists:
  `docs/research/ml-validation-hardening-acceptance.md`.
- Phase 2 signal arbitration evidence exists:
  `docs/research/ml-signal-arbitration-acceptance.md`.
- Current long v1 baseline artifacts exist locally:
  - `artifacts/datasets/xauusd_2025_dataset_1/`
  - `artifacts/models/xauusd_2025_xgb_1/`
- Python dependencies from `tools/deterministic_signal_ml/requirements.txt` are
  installed in the local virtual environment.
- MetaEditor compile follows `docs/environment/mt5-agentic-workflows.md`.
- Human-in-the-loop Strategy Tester is available for the XAUUSD 2025
  calendar-year raw export and any conditional runtime smoke runs.
- Generated datasets, model outputs, exports, Strategy Tester files, logs, and
  Common Files artifacts remain out of git unless a future human explicitly
  changes that policy.

## Planned Evidence Files

Create and update these compact evidence files during implementation:

- `docs/research/ml-feature-schema-v2-acceptance.md`
- `artifacts/datasets/xauusd_2025_schema_v2_dataset_1/`
- `artifacts/models/xauusd_2025_schema_v2_xgb_1/`
- `artifacts/models/xauusd_2025_schema_v2_xgb_1/robustness/`
- `artifacts/models/xauusd_2025_schema_v2_xgb_1/ablation/`
- Conditional, only if research gate passes:
  `artifacts/model_exports/xauusd_2025_schema_v2_xgb_1_export_v1/`
- Conditional runtime artifacts under:
  `DeterministicSignalML/shadow_runs/<shadow_run_id>/`

Do not paste full TSVs, Parquet contents, tree TSVs, model JSON, or compile logs
into documentation or chat. Summarize paths, row counts, file sizes, final
status lines, and selected failure lines.

## Scope

- Freeze and explain the v1 rejection baseline.
- Define schema v2 columns and active feature contract.
- Update MQL5 feature export and runtime shadow scorer feature extraction.
- Update Python validation, dataset builder, training, export, parity, and
  comparison tooling for schema v2.
- Generate a fresh XAUUSD 2025 schema v2 Strategy Tester raw export.
- Build a schema v2 dataset and train candidate models.
- Run baseline-versus-v2 ablation with hardened validation.
- Conditionally export and validate a runtime artifact if the research gate
  passes.
- Update compact workflow docs only after accepted behavior changes.

## Non-Goals

- No live deployment approval.
- No ONNX work.
- No multi-symbol research.
- No dynamic `1:n` target modeling.
- No runtime TP changes.
- No ML mode may create trades, resize lots, alter SL/TP, or bypass
  license/session/spread/stops/freeze/margin/protection/magic-number/broker
  reconciliation guards.
- No custom MQL5 test harness or CI.
- No generated large artifacts committed to git.

## Acceptance Gate

Schema v2 is accepted only when all required conditions pass:

- Fresh XAUUSD schema v2 export covers the 2025 calendar year with the date
  boundary defined in this plan.
- Dataset build joins features and outcomes with no duplicate feature/outcome
  IDs and no unexplained missing outcomes.
- Feature rows with invalid values are either zero or explained with bounded,
  non-systemic causes.
- Threshold selection uses threshold-selection rows or pre-final-holdout
  out-of-fold predictions, never final holdout rows.
- Final holdout remains untouched approval evidence.
- Candidate comparison shows material improvement over the frozen v1 rejection
  baseline.
- A positive threshold candidate exists on threshold-selection evidence.
- Final holdout at the selected threshold remains positive after costs.
- Initial support guards pass:
  - threshold-selection selected rows `>= 100`
  - final-holdout selected rows `>= 50`
  - important strategy-depth segments have `>= 15` selected rows or are marked
    research-only with no promotion claim
  - bullish and bearish selected rows each have `>= 20` rows or are marked
    research-only with no promotion claim
- No critical regression remains unresolved for S1, S2, S3, bullish, bearish,
  source type, or strategy-direction segments.
- Rare-bucket, high-importance concentration, final-holdout reuse, leakage, and
  no-variation warnings are resolved or explicitly accepted as non-blocking.
- If a runtime export is produced, Python/MQL5 scoring parity remains within
  the previously accepted tolerance and Strategy Tester runtime artifacts have
  scored rows, no invalid feature rows, and valid arbitration counters.

If these conditions fail, Phase 3 closes the current attempt as rejected and
creates a follow-up Phase 3 `$planner` plan before any new feature iteration.

## Sprint 1: Baseline Diagnosis And V2 Contract

**Goal**: Freeze the v1 rejection baseline, define the schema v2 contract, and
make the acceptance gate explicit before implementation starts.

**Commit**: `docs: define ml feature schema v2 contract`

**Demo/Validation**:

- Review `docs/research/ml-feature-schema-v2-acceptance.md`.
- Confirm the plan identifies `xauusd_2025_xgb_1` as a rejected v1 baseline,
  not a candidate for runtime promotion.
- Confirm no MQL5 or Python behavior changed in this sprint.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Freeze The V1 Rejection Baseline

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Record the current v1 long baseline dataset/model, row
  counts, validation summary, threshold failure, and reason it is not a valid
  FILTER export.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Evidence names `xauusd_2025_dataset_1` and `xauusd_2025_xgb_1`.
  - Evidence records training rows, encoded feature count, holdout ROC AUC near
    `0.495`, and no selected rows at thresholds `>= 0.50`.
  - Evidence states v1 is the comparison baseline and not a promoted model.
- **Validation**:
  - Inspect `artifacts/datasets/xauusd_2025_dataset_1/dataset_report.md`.
  - Inspect `artifacts/models/xauusd_2025_xgb_1/validation_report.md`.

### Task 1.2: Define The Schema V2 Feature Contract

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Define the schema v2 fields, their source, leakage boundary,
  type, and whether they are required or optional ablation candidates.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Required structure features include:
    `source_structure_type`, `opposite_structure_type`, and
    `same_previous_structure_type`.
  - Required candle features include:
    `prev_body_ratio`, `prev_upper_wick_ratio`, `prev_lower_wick_ratio`,
    `prev_close_location`, and `prev_candle_dir`.
  - Required strategy-depth and direction features include:
    `strategy_delay_period`, `confirmation_timeframe_minutes`,
    `entry_direction_macro_alignment`, and `macro_alignment_score`.
  - Optional features are marked as secondary ablation candidates:
    `source_intern_fib_raw`, `source_extern_fib_raw`,
    `source_extern_structures_broken`, `prev_candle_shape`, and
    `session_bucket`.
  - Contract states all features must be available at entry time and must not
    use terminal outcome, post-entry bars, or blocked-result information.
- **Validation**:
  - Manual contract review against `DeterministicSignalFeatureSnapshot` and
    `SignalParams`.

### Task 1.3: Define Promotion And Rejection Rules

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Document the concrete research gate, support guards, segment
  diagnostics, and follow-up behavior if schema v2 fails.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Gate states the exact XAUUSD 2025 calendar-year range:
    start inclusive `2025-01-01 00:00:00`, end exclusive
    `2026-01-01 00:00:00` where supported, or inclusive
    `2025-12-31 23:59:59` when needed by Strategy Tester.
  - Gate states threshold selection cannot use final holdout.
  - Gate states export/parity/FILTER validation is conditional on research
    acceptance.
  - Gate states failure requires a new Phase 3 follow-up `$planner` plan before
    additional feature iteration.
- **Validation**:
  - Manual doc review.

### Task 1.4: Refresh Active Planning Index

- **Location**:
  - `docs/plans/README.md`
- **Description**: Update the planning index so it no longer says there are no
  active plans while this roadmap and Phase 3 plan are active.
- **Dependencies**: Task 1.3.
- **Acceptance Criteria**:
  - README points to `ml-robustness-and-signal-selection-roadmap.md`.
  - README points to this Phase 3 plan.
  - README keeps archive guidance intact.
- **Validation**:
  - `rg -n "no active|ml-feature-schema-v2|ml-robustness" docs/plans/README.md`

## Sprint 2: MQL5 Schema V2 Feature Export

**Goal**: Replace the active MQL5 feature export contract with schema v2 while
preserving trading behavior and broker/risk gates.

**Commit**: `feat: export deterministic schema v2 features`

**Demo/Validation**:

- Static review of feature snapshot construction.
- Confirm all new features are derived from entry-time state or closed candles.
- Confirm no broker admission, order send, lot sizing, SL/TP, license, session,
  spread, margin, protection, magic-number, or reconciliation behavior changed.

Execution must complete and validate this sprint before moving to Sprint 3.
Do not run MetaEditor compile after every task. Run the phase compile gate after
all planned MQL5 source edits are complete and before Strategy Tester execution.

### Task 2.1: Bump Active Feature Schema Constants

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Move the active feature schema constants and TSV headers to
  version `2`. Keep v1 evidence in docs/artifacts, but do not add active
  compatibility shims unless implementation discovers a simpler safe path.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - `signal_features.tsv` header includes the schema v2 required columns.
  - `shadow_predictions.tsv` can record schema v2 feature columns for parity.
  - Runtime manifest validation expects schema v2 for new exports.
  - Existing default runtime mode remains `ML_INFERENCE_DISABLED`.
- **Validation**:
  - Manual header-to-row field count review.
  - `rg -n "SCHEMA_VERSION|PHASE1_SCHEMA_VERSION|feature_schema_version" services/trading_signals`

### Task 2.2: Add Structure Context Feature Helpers

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - optional helper under `services/trading_signals/`
- **Description**: Add helpers that derive structure type tokens from
  `base_structure_data.os_market_structures` and `extremum_stats` for the
  source, opposite, and previous same-type extrema used by the existing
  Fibonacci range.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Source structure type maps to the source extremum.
  - Opposite structure type maps to the opposite extremum used by the range.
  - Same-previous structure type maps to the same-type previous extremum.
  - Missing or inconsistent structure arrays mark the feature row invalid
    instead of inventing values.
  - Tokens are stable and TSV-safe, such as `HH`, `HL`, `LH`, `LL`, `EQ`.
- **Validation**:
  - Manual review against `StochasticMarketStructure.extremum_stats`.

### Task 2.3: Add Previous Closed Candle Ratio Features

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Add previous closed candle features from
  `DETERMINISTIC_BASE_TIMEFRAME` shift `1`.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `prev_body_ratio`, `prev_upper_wick_ratio`, `prev_lower_wick_ratio`, and
    `prev_close_location` use only the closed candle at shift `1`.
  - Ratios are normalized by candle range and handle zero-range candles safely.
  - `prev_candle_dir` is categorical and uses stable values such as `BULL`,
    `BEAR`, and `DOJI`.
  - No current forming candle or post-entry candle is used.
- **Validation**:
  - Manual no-lookahead review.

### Task 2.4: Add Strategy Depth And Macro Alignment Features

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_management/deterministic_strategy_config.mqh`
- **Description**: Add numeric features that express strategy depth and
  direction/macro alignment without treating S1/S2/S3 as unrelated systems.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `strategy_delay_period` uses `DeterministicStrategyBaseDelay(...)`.
  - `confirmation_timeframe_minutes` maps M3/M5/M10 to `3`, `5`, and `10`.
  - `entry_direction_macro_alignment` expresses whether the entry direction is
    aligned, opposed, or flat against the strategy confirmation timeframe.
  - `macro_alignment_score` summarizes H1/H4/D1 alignment against entry
    direction using only entry-time MA slope values.
  - Values are deterministic across export and shadow scorer paths.
- **Validation**:
  - Manual review of bullish and bearish examples.

### Task 2.5: Wire Schema V2 Snapshot, Row, And Shadow Encoder

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Extend `DeterministicSignalFeatureSnapshot`, feature row
  output, shadow prediction rows, numeric source mapping, and categorical source
  mapping for schema v2.
- **Dependencies**: Tasks 2.2, 2.3, and 2.4.
- **Acceptance Criteria**:
  - Feature row and header column counts match.
  - Shadow prediction row and header column counts match.
  - Unknown schema v2 feature-map source columns fail visibly.
  - Missing required numeric values mark feature rows invalid.
  - Hot path stays bounded: no full-history scans, per-tick handle creation, or
    unbounded logging.
- **Validation**:
  - Manual field-count review.
  - Static lifecycle review for `ML_INFERENCE_DISABLED`, `ML_INFERENCE_SHADOW`,
    and `ML_INFERENCE_FILTER`.

## Sprint 3: Python Schema V2 Dataset And Tooling

**Goal**: Replace the active Python feature contract and local tooling with
schema v2 so new Strategy Tester exports build deterministic datasets and model
artifacts.

**Commit**: `feat: support deterministic schema v2 datasets`

**Demo/Validation**:

- Run Python syntax checks.
- Run a small fixture through validation, dataset build, encoding, artifact map
  generation, and shadow comparison normalization.
- Confirm v1 remains only a frozen baseline reference, not the active contract.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Update Python Schema Contract

- **Location**:
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Update supported schema version, feature columns, model
  feature columns, numeric columns, and categorical columns for schema v2.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `SUPPORTED_SCHEMA_VERSION = 2`.
  - Required schema v2 columns are present in `FEATURE_COLUMNS`.
  - Numeric/categorical classification matches the MQL5 feature row contract.
  - Active dataset tooling rejects schema v1 by default or labels it as
    frozen baseline-only.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/schema_contract.py`

### Task 3.2: Update Dataset Builder And Reports

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/report_writer.py`
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
- **Description**: Update TSV parsing, DuckDB table definitions, training matrix
  projection, null counts, feature ranges, and report outputs for schema v2.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Schema v2 `signal_features.tsv` validates.
  - Dataset builder writes `features.parquet`, `outcomes.parquet`, and
    `training_matrix.parquet`.
  - Dataset report includes null counts and ranges for new numeric features.
  - Feature invalid rows are counted and surfaced.
- **Validation**:
  - Run against a minimal deterministic fixture under a temporary directory.
  - `python3 -m py_compile tools/deterministic_signal_ml/build_dataset.py`

### Task 3.3: Update Training, Robustness, And Ablation Tooling

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/validate_model_robustness.py`
  - `tools/deterministic_signal_ml/robustness_report.py`
  - `tools/deterministic_signal_ml/segment_metrics.py`
  - `tools/deterministic_signal_ml/compare_model_candidates.py`
- **Description**: Ensure training and hardened validation understand schema v2
  features, strategy-depth family views, direction views, and feature-set
  ablation groups.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Reports include strategy-depth family diagnostics.
  - Reports keep S1/S2/S3 visible while documenting they are depth variants of
    the same archetype.
  - Ablation can compare v1 rejection baseline, v2 structure-only,
    v2 structure+candle, v2 structure+candle+depth/macro, and optional
    session-bucket candidates.
  - Candidate comparison can reject non-comparable datasets explicitly.
- **Validation**:
  - Run on a temporary fixture or existing v2 fixture once available.
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`

### Task 3.4: Update Export, Deployment, And Parity Tooling

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/model_artifact_contract.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - `tools/deterministic_signal_ml/deploy_model_export.py`
- **Description**: Update feature-map generation, artifact validation, Python
  runtime scorer input normalization, and deployment checks for schema v2.
- **Dependencies**: Task 3.3.
- **Acceptance Criteria**:
  - Feature map source columns match schema v2 exactly.
  - Artifact manifest records `phase1_schema_version=2` or a renamed compact
    equivalent if the implementation cleans up legacy naming.
  - Validator rejects artifacts without a positive threshold recommendation
    unless explicitly run in research-only mode.
  - `compare_shadow_predictions.py` normalizes schema v2 rows for Python/MQL5
    parity.
- **Validation**:
  - Run export validator on a minimal generated v2 artifact fixture.
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`

## Sprint 4: Fresh XAUUSD 2025 Schema V2 Dataset

**Goal**: Compile the EA once after planned MQL5 edits, generate a fresh
schema v2 Strategy Tester export, and build the XAUUSD 2025 dataset.

**Commit**: `data: record xauusd schema v2 dataset evidence`

**Demo/Validation**:

- MetaEditor real compile produces `0 errors, 0 warnings`.
- Human-in-the-loop Strategy Tester generates schema v2 raw features/outcomes.
- Dataset builder creates `xauusd_2025_schema_v2_dataset_1`.
- Acceptance evidence records date range, run ID, config ID, row counts, and
  validation status.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Compile After MQL5 Schema Edits

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/**/*.mqh`
  - `logs/compile/`
- **Description**: Run the project compile helper after all planned MQL5 schema
  v2 edits are complete.
- **Dependencies**: Sprints 2 and 3.
- **Acceptance Criteria**:
  - Compile command uses `tools/mt5/compile_mt5.py` or the documented
    MetaEditor fallback.
  - Compile result is `0 errors, 0 warnings`.
  - Evidence records log path, result line, and generated EX5 size/timestamp.
- **Validation**:
  - `python3 tools/mt5/compile_mt5.py --mode compile`

### Task 4.2: Prepare XAUUSD 2025 Tester Configuration

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - MT5 tester preset under `MQL5/Profiles/Tester/` if tracked or documented
    as a local generated artifact
- **Description**: Define the human-in-the-loop Strategy Tester configuration
  for raw schema v2 data generation.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Symbol is XAUUSD.
  - Date range covers the 2025 calendar year: start inclusive
    `2025-01-01 00:00:00`, end exclusive `2026-01-01 00:00:00` where
    supported, or inclusive `2025-12-31 23:59:59` if required by Strategy
    Tester.
  - `ML_Inference_Mode = ML_INFERENCE_DISABLED`.
  - `Enable_Signal_Feature_Export = true`.
  - S1, S2, and S3 are enabled.
  - Run ID is distinct, recommended:
    `xauusd_2025_schema_v2_run_1`.
- **Validation**:
  - Manual preset review before running Strategy Tester.

### Task 4.3: Run Strategy Tester Raw Export

- **Location**:
  - MT5 Common Files:
    `DeterministicSignalML/runs/xauusd_2025_schema_v2_run_1/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Generate the schema v2 feature/outcome export through a
  human-in-the-loop Strategy Tester run.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Run folder contains `run_manifest.tsv`, `signal_features.tsv`,
    `signal_outcomes.tsv`, and `run_summary.tsv`.
  - Summary records `export_status=OK`.
  - Feature and outcome row counts are non-zero and large enough for
    chronological splits.
  - No full TSV contents are copied into docs or chat.
- **Validation**:
  - Inspect run summary and manifest.

### Task 4.4: Validate And Build Dataset

- **Location**:
  - `artifacts/datasets/xauusd_2025_schema_v2_dataset_1/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Validate the raw run and build the schema v2 dataset.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - Phase run validator passes for schema v2.
  - Dataset build succeeds.
  - `features.parquet`, `outcomes.parquet`, and `training_matrix.parquet`
    exist under the dataset artifact folder.
  - Dataset report includes row counts, target distribution, strategy-depth
    distribution, direction distribution, null counts, feature ranges, and
    warnings.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/validate_phase1_run.py ...`
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py ...`

## Sprint 5: Training, Ablation, And Segment Decisions

**Goal**: Train schema v2 candidates, compare against the frozen v1 rejection
baseline, and decide whether a runtime export is justified.

**Commit**: `ml: evaluate xauusd schema v2 candidates`

**Demo/Validation**:

- Training and robustness reports exist for schema v2 candidates.
- Ablation report shows whether each feature group helps or hurts.
- Final decision is `ACCEPT_FOR_RUNTIME_SPIKE`, `REJECT_WITH_FOLLOW_UP`, or
  `RESEARCH_ONLY_WARN`.

Execution must complete and validate this sprint before moving to Sprint 6.

### Task 5.1: Train The Initial Global V2 Candidate

- **Location**:
  - `artifacts/models/xauusd_2025_schema_v2_xgb_1/`
  - `tools/deterministic_signal_ml/train_model.py`
- **Description**: Train the initial global schema v2 classifier/regressor on
  `xauusd_2025_schema_v2_dataset_1` using hardened chronological validation.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Model manifest records dataset ID, run ID, schema version, feature count,
    split policy, and threshold source.
  - Threshold selection does not use final holdout.
  - Validation report includes global classification/regression metrics,
    threshold table, fold ranges, and top feature diagnostics.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/train_model.py ...`

### Task 5.2: Run Hardened Robustness Validation

- **Location**:
  - `artifacts/models/xauusd_2025_schema_v2_xgb_1/robustness/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Run hardened robustness reporting against the v2 candidate.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Report includes threshold-selection source, final holdout status, segment
    metrics, warning rows, feature concentration, and selected-row counts.
  - Segment metrics include S1, S2, S3, bullish, bearish, source type, and
    strategy-direction views.
  - Report status is `PASS` or `WARN` only if the warnings are explicitly
    non-blocking for promotion.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py ...`

### Task 5.3: Run Feature-Group Ablation

- **Location**:
  - `artifacts/models/xauusd_2025_schema_v2_xgb_1/ablation/`
  - `tools/deterministic_signal_ml/compare_model_candidates.py`
- **Description**: Compare feature groups to determine whether schema v2
  improvement is robust or driven by noisy buckets.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Ablation includes v1 rejection baseline as frozen reference.
  - Ablation includes at least:
    - v2 structure-only
    - v2 structure plus candle ratios
    - v2 structure plus candle plus strategy-depth and macro alignment
  - Optional session bucket is evaluated only after primary feature groups.
  - Any accepted feature group improves threshold and segment evidence without
    unresolved critical regressions.
- **Validation**:
  - Candidate comparison command exits successfully.
  - Evidence records PASS/WARN/FAIL per feature group.

### Task 5.4: Evaluate Global, Depth-Aware, And Direction-Aware Policies

- **Location**:
  - `artifacts/models/xauusd_2025_schema_v2_xgb_1/segments/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Compare global model behavior against per-strategy-depth and
  direction-aware threshold/model policies.
- **Dependencies**: Task 5.3.
- **Acceptance Criteria**:
  - S1/S2/S3 are evaluated as depth variants of the same archetype.
  - Per-strategy or per-direction artifacts are not promoted unless support
    counts are large enough and segment results beat the global policy.
  - Aggregate improvement cannot hide a critical S1/S2/S3 or direction
    regression.
- **Validation**:
  - Segment report review.
  - Candidate comparison summary.

### Task 5.5: Decide Phase 3 Research Outcome

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - optional follow-up plan under `docs/plans/`
- **Description**: Apply the acceptance gate and decide whether to continue to
  runtime export/parity or stop for follow-up planning.
- **Dependencies**: Task 5.4.
- **Acceptance Criteria**:
  - If accepted, evidence states `ACCEPT_FOR_RUNTIME_SPIKE` and names the exact
    model/export candidate.
  - If rejected, evidence states `REJECT_WITH_FOLLOW_UP`, explains why, and a
    new Phase 3 follow-up `$planner` plan is created before further feature
    iteration.
  - If research-only, evidence states what is missing before runtime export.
- **Validation**:
  - Manual gate review.

## Sprint 6: Conditional Runtime Export And Parity

**Goal**: Only if Sprint 5 passes, export a schema v2 runtime artifact and
validate Python/MQL5 parity plus Strategy Tester SHADOW/FILTER behavior.

**Commit**: `ml: validate schema v2 runtime export`

**Demo/Validation**:

- Runtime export validates as MT5-ready.
- Export deploy helper copies the artifact to MT5 Common Files.
- Strategy Tester runtime run produces scored rows and parity agreement.
- FILTER smoke preserves broker/risk gates and arbitration counters.

Execution must complete and validate this sprint before moving to Sprint 7.
Skip this sprint if Sprint 5 rejects schema v2.

### Task 6.1: Export Schema V2 Artifact

- **Location**:
  - `artifacts/model_exports/xauusd_2025_schema_v2_xgb_1_export_v1/`
  - `tools/deterministic_signal_ml/export_model_artifact.py`
- **Description**: Export the accepted schema v2 model into MT5-readable TSV
  artifacts.
- **Dependencies**: Sprint 5 accepted outcome.
- **Acceptance Criteria**:
  - Export folder includes `model_manifest.tsv`, `feature_map.tsv`,
    `classifier_trees.tsv`, `regressor_trees.tsv`, and `threshold_policy.tsv`.
  - Manifest records schema version `2`, positive threshold, encoded feature
    count, and `mt5_runtime_ready=true`.
  - Export rejects research-only or threshold-negative models.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/export_model_artifact.py ...`
  - `.venv/bin/python tools/deterministic_signal_ml/model_artifact_validator.py ...`

### Task 6.2: Deploy Export To Common Files

- **Location**:
  - MT5 Common Files:
    `DeterministicSignalML/model_exports/xauusd_2025_schema_v2_xgb_1_export_v1/`
- **Description**: Deploy the validated export to the Common Files root used by
  MT5/Wine.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Deploy helper validates source and deployed copy.
  - Existing deployed folder is overwritten only with explicit `--overwrite`.
  - Evidence records Common Files path and validation status.
- **Validation**:
  - `MT5_COMMON_FILES=<path> .venv/bin/python tools/deterministic_signal_ml/deploy_model_export.py --export-id xauusd_2025_schema_v2_xgb_1_export_v1 --overwrite`

### Task 6.3: Run SHADOW Parity Smoke

- **Location**:
  - MT5 Common Files:
    `DeterministicSignalML/shadow_runs/<shadow_run_id>/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Run Strategy Tester in `ML_INFERENCE_SHADOW` with schema v2
  artifact loaded and compare MQL5 predictions against Python scoring.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Runtime manifest records `available=true`.
  - Prediction rows are non-zero.
  - Invalid feature rows are zero or explained.
  - Python/MQL5 classifier and regressor max absolute error remain within
    accepted tolerance.
  - SHADOW mode does not affect broker admission.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py ...`

### Task 6.4: Run FILTER Arbitration Smoke

- **Location**:
  - MT5 Common Files:
    `DeterministicSignalML/shadow_runs/<shadow_run_id>/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Run Strategy Tester in `ML_INFERENCE_FILTER` to validate the
  schema v2 artifact under the Phase 2 arbitration path.
- **Dependencies**: Task 6.3.
- **Acceptance Criteria**:
  - Runtime manifest records `mode=FILTER` and `available=true`.
  - Prediction rows are scored.
  - FILTER allow/block counters are present.
  - Arbitration decisions exist and at most one candidate is selected per
    group.
  - Existing broker/risk gates still run before broker send.
  - No live deployment approval is implied.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py --require-arbitration ...`
  - `.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py ...`

## Sprint 7: Closeout, Workflow Update, And Commit Discipline

**Goal**: Record Phase 3 outcome, update compact docs only where behavior has
changed, and leave the repo ready for either follow-up Phase 3 work or Phase 4.

**Commit**: `docs: record ml feature schema v2 outcome`

**Demo/Validation**:

- Acceptance evidence clearly says PASS, FAIL, WARN, or follow-up required.
- Compact workflow reflects schema v2 only if accepted.
- Generated artifacts remain ignored.
- Git status shows only intentional docs/code changes.

Execution must complete and validate this sprint before starting any later
roadmap phase.

### Task 7.1: Record Final Phase 3 Evidence

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Summarize the final research and runtime outcome.
- **Dependencies**: Sprint 5, and Sprint 6 if runtime export ran.
- **Acceptance Criteria**:
  - Evidence includes dataset ID, model ID, export ID if any, row counts,
    threshold source, selected-row counts, segment decisions, warnings, and
    final outcome.
  - Evidence states whether schema v2 is accepted, rejected, or needs a
    follow-up plan.
  - Evidence includes only compact summaries and paths, not raw logs or large
    generated data.
- **Validation**:
  - Manual evidence review.

### Task 7.2: Update Compact Workflow Reference

- **Location**:
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
  - `README.md` if a compact top-level note is needed
- **Description**: Update the active workflow only if schema v2 changes the
  accepted operational process.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - Accepted schema version and artifact ID are clear if Phase 3 passes.
  - Rejection or follow-up status is clear if Phase 3 fails.
  - Workflow remains compact and does not duplicate the full plan.
- **Validation**:
  - `rg -n "schema v2|xauusd_2025_schema_v2|Feature Schema V2|FILTER" README.md docs/workflows`

### Task 7.3: Verify Generated Artifacts Stay Out Of Git

- **Location**:
  - repository root
  - `artifacts/`
  - `logs/`
- **Description**: Confirm only intentional source/docs changes are tracked.
- **Dependencies**: Task 7.2.
- **Acceptance Criteria**:
  - Large generated artifacts are ignored or explicitly untracked.
  - Compile logs are summarized in evidence but not pasted into docs.
  - No model JSON, Parquet, tree TSV, full shadow TSV, or query debug file is
    committed.
- **Validation**:
  - `rtk git status --short`
  - `rtk git diff --stat`

### Task 7.4: Create Follow-Up Plan If Needed

- **Location**:
  - `docs/plans/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: If schema v2 does not meet acceptance, create a targeted
  Phase 3 follow-up `$planner` plan before any additional feature iteration.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - Follow-up plan names the failure mode, such as insufficient selected rows,
    direction regression, rare-bucket dominance, feature leakage risk, or weak
    threshold-selection evidence.
  - Follow-up plan stays within Phase 3 and does not start ONNX, multi-symbol,
    dynamic targets, or live rollout.
  - Acceptance evidence links to the follow-up plan.
- **Validation**:
  - Manual plan review.

## Testing Strategy

- Documentation-only validation for Sprint 1.
- Static MQL5 lifecycle review for Sprint 2.
- Python syntax and fixture validation for Sprint 3:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`
- MetaEditor compile gate before Strategy Tester data generation in Sprint 4:
  - `python3 tools/mt5/compile_mt5.py --mode compile`
- Human-in-the-loop Strategy Tester raw export for Sprint 4.
- Dataset validation and build commands for Sprint 4.
- Training, robustness, candidate comparison, and ablation commands for Sprint
  5.
- Conditional export validator, deploy helper, SHADOW parity, and FILTER
  arbitration summary for Sprint 6.
- Git hygiene and compact doc review for Sprint 7.

## Potential Risks And Gotchas

- Retiring active v1 compatibility simplifies development but means the last
  accepted v1 smoke export is rollback evidence, not an active dual-supported
  runtime path. Rollback should use git, not compatibility shims.
- Structure type features are categorical. Treating `HH`, `HL`, `LH`, `LL`, and
  `EQ` as ordinal numbers can create misleading splits.
- Candle labels can overfit. Numeric candle ratios should be the primary
  representation; labels such as `prev_candle_shape` must remain optional until
  ablation proves value.
- Previous closed candle features must use shift `1`; using shift `0` can
  introduce lookahead or unstable current-bar behavior.
- Session buckets can memorize the 2025 XAUUSD regime. Keep them optional and
  reject them if support is thin or fold behavior is inconsistent.
- Macro alignment features must be derived from entry-time MA slopes only.
  They must not use future macro bar outcomes.
- A positive threshold on threshold-selection rows can still fail final holdout.
  That is a valid rejection and should lead to follow-up planning, not threshold
  tuning on final holdout.
- Per-strategy models may look attractive because S1/S2/S3 have different
  depths, but they are the same archetype. Prefer global depth-aware features
  unless segment evidence clearly supports separate policies.
- A short runtime smoke can prove parity but not robust profitability. Research
  approval still comes from the XAUUSD 2025 hardened validation gate.
- Strategy Tester CLI automation may not produce run artifacts reliably under
  Wine. Human-in-the-loop Strategy Tester remains the accepted runtime
  validation path.

## Rollback Plan

- Keep `ML_INFERENCE_DISABLED` as the default.
- If schema v2 MQL5 export breaks compile or raw data generation, revert the
  Phase 3 MQL5 schema edits and return to the last compiled baseline.
- If schema v2 Python tooling breaks dataset creation, revert the Python schema
  migration and keep v1 artifacts as frozen rejection evidence only.
- If schema v2 trains but fails the research gate, do not export a runtime
  artifact. Record rejection and create a follow-up Phase 3 plan.
- If runtime export/parity fails after research acceptance, keep the model as
  research-only and fix export/scorer parity in a follow-up Phase 3 plan.
- Do not delete historical v1 artifacts or archived evidence as part of
  rollback.
- Do not move to Phase 4 until Phase 3 has accepted evidence or an explicit
  human decision changes the roadmap.
