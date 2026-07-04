# Plan: Deterministic Signal MQL5 Shadow Inference

**Generated**: 2026-07-04
**Status**: Draft
**Estimated Complexity**: High
**Risk Level**: Low for trading behavior when implemented as specified; Medium for runtime correctness and telemetry because model loading, feature parity, and tree scoring must match the Python artifact exactly.

## Overview

Implement Phase 5 of the deterministic signal ML roadmap: load the Phase 4 model export in MT5 and evaluate deterministic broker-entered signals in `SHADOW` mode without changing trading behavior.

This phase must be strictly observational. It may load a model, compute scores, write shadow telemetry, and compare those scores against the Python scorer. It must not filter trades, change entries or exits, alter lot sizing, change SL/TP, bypass risk controls, or affect broker admission.

Execution is ordered. Complete, validate, and commit one sprint before starting the next sprint.

## Confirmed Product Decisions

- First model export ID: `xgb_test_1_export_v1`.
- Runtime artifact location: `Common\Files\DeterministicSignalML\model_exports\<export_id>`.
- EA mode input: `ML_Inference_Mode = DISABLED | SHADOW`, default `DISABLED`.
- Phase 5 does not expose `FILTER`.
- Failure mode in `SHADOW`: fail open for trading, fail visible for diagnostics with `ML_UNAVAILABLE`.
- Scoring boundary: after deterministic broker entry succeeds, not per tick and not before broker admission.
- Classifier is the primary shadow recommendation source.
- Regressor may be loaded and recorded as secondary telemetry when the artifact is valid and runtime cost stays bounded.
- Acceptance platform: Ubuntu/Wine first. Windows compile remains human-in-the-loop before claiming cross-platform parity.

## Documentation Basis

- Roadmap: `docs/plans/deterministic-signal-ml-roadmap.md`
- Phase 4.5 acceptance: `docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`
- Environment runbook: `docs/environment/mt5-agentic-workflows.md`
- Phase 4 artifact contract: `tools/deterministic_signal_ml/model_artifact_contract.py`
- Phase 4 validator/scorer: `tools/deterministic_signal_ml/model_artifact_validator.py`
- MQL5 `FileOpen`: https://www.mql5.com/en/docs/files/fileopen
- MQL5 `FolderCreate`: https://www.mql5.com/en/docs/files/foldercreate
- MQL5 `FileReadString`: https://www.mql5.com/en/docs/files/filereadstring
- MQL5 `FileIsLineEnding`: https://www.mql5.com/en/docs/files/fileislineending
- MetaEditor command-line compile and syntax check: https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide

## Prerequisites

- Phase 4.5 readiness is `PASS` for Ubuntu/Wine.
- `artifacts/model_exports/xgb_test_1_export_v1` exists locally and validates with `model_artifact_validator.py`.
- The export folder is copied or restored to:

```text
Common\Files\DeterministicSignalML\model_exports\xgb_test_1_export_v1
```

- Generated artifacts, logs, `.ex5`, datasets, models, and model exports remain ignored.
- No broker credentials, license tokens, account numbers, private Strategy Tester logs, full `query_debug.txt`, full tree TSVs, or Parquet contents are pasted into chat or committed.
- Validation uses the project compile helper:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework \
  --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 \
  --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase-05-shadow-inference.log \
  --mode compile \
  --timeout 180
```

## Non-Goals

- No `FILTER` mode.
- No model-controlled broker admission.
- No changes to deterministic candidate detection.
- No changes to entry triggers, exits, lot sizing, SL/TP, session gates, license gates, spread checks, margin checks, protection risk, magic-number scope, or broker reconciliation.
- No Python calls from MQL5 runtime.
- No PostgreSQL.
- No custom MQL5 test harness, CI, or additional Strategy Tester automation.
- No generated `.mqh` model unless a future phase explicitly chooses that path.
- No committed generated artifacts or full logs.

## Proposed Runtime File Contract

Input artifact, under `FILE_COMMON`:

```text
DeterministicSignalML\model_exports\<export_id>\model_manifest.tsv
DeterministicSignalML\model_exports\<export_id>\feature_map.tsv
DeterministicSignalML\model_exports\<export_id>\classifier_trees.tsv
DeterministicSignalML\model_exports\<export_id>\regressor_trees.tsv
DeterministicSignalML\model_exports\<export_id>\threshold_policy.tsv
```

Shadow output, under `FILE_COMMON`:

```text
DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_manifest.tsv
DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_predictions.tsv
DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_outcomes.tsv
DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_summary.tsv
```

Recommended `shadow_predictions.tsv` columns:

```text
schema_version
shadow_run_id
export_id
model_id
dataset_id
feature_schema_version
signal_id
source_key
source_attempt_index
symbol
strategy_id
strategy_label
direction
entry_time
classifier_score
regressor_score
threshold_probability
recommendation
reason
feature_valid
model_available
```

Recommended `shadow_outcomes.tsv` columns:

```text
schema_version
shadow_run_id
export_id
model_id
signal_id
source_key
source_attempt_index
terminal_time
terminal_reason
recommendation
classifier_score
threshold_probability
profit_r
net_profit
duration_seconds
```

## Sprint 1: Shadow Contract And Input Surface

**Goal**: Add the Phase 5 public runtime contract while keeping the default EA behavior unchanged.
**Commit**: `feat: add ml shadow inference contract`
**Demo/Validation**:
- EA compiles with default `ML_Inference_Mode=DISABLED`.
- Static review confirms no broker admission, lifecycle, entry, exit, lot, or risk logic depends on the ML mode.
- Query debug header can identify ML mode/export settings when file logs are enabled.

### Task 1.1: Add ML Inference Mode Enum

- **Location**:
  - `services/core/enums.mqh`
- **Description**: Add `MLInferenceModes` with `ML_INFERENCE_DISABLED = 0` and `ML_INFERENCE_SHADOW = 1`. Do not add `FILTER` in Phase 5.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Enum values are explicit and stable.
  - No existing enum numeric values are changed.
  - No trading decision branches are introduced.
- **Validation**:
  - Static review.
  - Compile at sprint end.

### Task 1.2: Add Sparse ML Inputs

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add a compact input group for shadow inference.
- **Recommended Inputs**:
  - `input MLInferenceModes ML_Inference_Mode = ML_INFERENCE_DISABLED;`
  - `input string ML_Model_Export_Id = "xgb_test_1_export_v1";`
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Default behavior stays disabled.
  - Artifact root stays internal: `DeterministicSignalML\model_exports`.
  - No threshold override input is added; Phase 5 uses artifact metadata.
  - No filter-mode input is added.
- **Validation**:
  - Static review of input defaults.
  - Compile at sprint end.

### Task 1.3: Add Shadow Status To Query Debug Header

- **Location**:
  - `services/trading_signals/execution_logging.mqh`
- **Description**: Extend the existing `QUERY_DEBUG_SESSION` or add an `INPUTS_ML` header line showing mode, export ID, artifact root, and default fail-open policy.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Header logs `mode=DISABLED` by default.
  - Header logs `mode=SHADOW|export_id=xgb_test_1_export_v1` when enabled.
  - Header does not dump manifest, feature map, or tree contents.
- **Validation**:
  - Static review.
  - Human-in-the-loop short `query_debug.txt` check after compile.

### Task 1.4: Document Artifact Install Boundary

- **Location**:
  - `README.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Document that Phase 5 runtime reads from `Common\Files\DeterministicSignalML\model_exports\<export_id>`, not directly from repository `artifacts/model_exports`.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Includes Ubuntu/Wine and Windows copy/restore examples.
  - States generated model exports remain uncommitted.
  - Points operators to `model_artifact_validator.py` before copying.
- **Validation**:
  - `rg "model_exports|ML_Inference_Mode|xgb_test_1_export_v1" README.md docs/environment/mt5-agentic-workflows.md tools/deterministic_signal_ml/README.md`

## Sprint 2: Artifact Loader And Fail-Open Runtime State

**Goal**: Load and validate the Phase 4 TSV artifact once during `OnInit`, with a visible unavailable state when anything is missing or incompatible.
**Commit**: `feat: load ml shadow artifact`
**Demo/Validation**:
- With `ML_Inference_Mode=DISABLED`, no artifact files are opened.
- With `SHADOW` and missing artifact files, EA compile succeeds and runtime logs `ML_UNAVAILABLE` while trading behavior remains unchanged.
- With `SHADOW` and a valid artifact in `Common\Files`, manifest, feature map, threshold policy, classifier trees, and optional regressor trees load once.

### Task 2.1: Add Shadow Runtime State Structs

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/trading_signals.mqh`
- **Description**: Add a new trading-signals module included after `deterministic_signal_statistics_export.mqh` and before `execution_controller.mqh`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Include order follows the service aggregator pipeline.
  - Runtime state tracks `enabled`, `available`, `unavailable_reason`, `export_id`, `model_id`, `dataset_id`, schema versions, feature count, tree counts, threshold, and load timestamps.
  - State resets deterministically on init/deinit.
  - No circular includes are introduced.
- **Validation**:
  - Static include-order review.
  - Compile at sprint end.

### Task 2.2: Implement Common Files Artifact Path Resolution

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Resolve artifact paths relative to `FILE_COMMON` using internal constants.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Path shape is `DeterministicSignalML\model_exports\<ML_Model_Export_Id>\<filename>`.
  - Export ID is sanitized using rules compatible with statistics run IDs.
  - Empty or unsafe export IDs produce `ML_UNAVAILABLE`, not `INIT_FAILED`.
  - Loader does not read repository-relative paths.
- **Validation**:
  - Static review.
  - Runtime query debug check for resolved export ID only, not full file contents.

### Task 2.3: Add TSV Reader Helpers

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add simple TSV reading helpers for small manifest/threshold files and bounded tree/feature files.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Uses `FileOpen(... FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, '\t')` or an equivalent sandbox-safe text parsing approach.
  - Checks `INVALID_HANDLE`, `GetLastError()`, and file ending.
  - Does not load or log full files into query debug.
  - Applies row count caps derived from manifest counts plus safety margins.
  - Handles `\N`, empty cells, and numeric parse failures explicitly.
- **Validation**:
  - Static review against MQL5 file API docs.
  - Compile at sprint end.

### Task 2.4: Validate Manifest And Threshold Policy

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Load `model_manifest.tsv` and `threshold_policy.tsv`, then validate required keys.
- **Dependencies**: Task 2.3.
- **Acceptance Criteria**:
  - Requires `artifact_schema_version=1`.
  - Requires `phase1_schema_version=1`.
  - Requires `mt5_runtime_ready=true`.
  - Requires `research_only=true`.
  - Requires classifier availability and nonzero tree count.
  - Reads `threshold_probability` from manifest or threshold policy and stores it once.
  - Missing optional regressor data disables regressor telemetry only, not classifier shadow scoring.
- **Validation**:
  - Static review.
  - Query debug emits one compact load status line.

### Task 2.5: Load Feature Map And Tree Nodes

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Load `feature_map.tsv`, `classifier_trees.tsv`, and optionally `regressor_trees.tsv` into flat MQL5 arrays.
- **Dependencies**: Task 2.4.
- **Acceptance Criteria**:
  - Feature indices are contiguous and match manifest `encoded_feature_count`.
  - Tree rows validate `model_role`, `tree_index`, `node_index`, node type, child references, and feature index bounds.
  - Every tree has root node `0`.
  - Uses explicit structs with constructors and copy constructors where arrays require them.
  - Dynamic arrays use bounded `ArrayResize(..., size, reserve)`.
- **Validation**:
  - Static review.
  - Compile at sprint end.

### Task 2.6: Wire Init And Deinit

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Call `DeterministicSignalMLShadowInit()` after deterministic statistics init, and `DeterministicSignalMLShadowDeinit()` during deinit.
- **Dependencies**: Task 2.5.
- **Acceptance Criteria**:
  - `DISABLED` returns success without file I/O.
  - `SHADOW` load failure does not return `INIT_FAILED`.
  - `SHADOW` load failure logs a compact `ML_UNAVAILABLE` reason.
  - Arrays are released/reset on deinit.
- **Validation**:
  - Compile.
  - Short tester/chart run with missing artifact confirms EA still runs and no trades are blocked by ML.

## Sprint 3: Feature Snapshot And Encoding Parity

**Goal**: Build the exact Phase 1 feature vector in MQL5 and encode it using the Phase 4 feature map without duplicating incompatible logic.
**Commit**: `feat: encode deterministic ml features`
**Demo/Validation**:
- Statistics export headers remain unchanged.
- Shadow encoding uses the same source values as Phase 1 feature export.
- Missing or invalid feature values produce a visible no-score reason, not a crash or trade block.

### Task 3.1: Extract Shared Feature Snapshot Builder

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Introduce a `DeterministicSignalFeatureSnapshot` helper boundary that collects the current Phase 1 model feature columns once.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Snapshot covers all `MODEL_FEATURE_COLUMNS`:
    - `strategy_id`
    - `strategy_label`
    - `direction`
    - `source_type`
    - `macro_h1_live_dir`
    - `macro_h4_live_dir`
    - `macro_d1_live_dir`
    - `sl_fib_raw`
    - `sl_fib_band`
    - `entry_fib_raw`
    - `entry_fib_band`
    - `low_chain_score_3`
    - `low_chain_score_5`
    - `low_chain_score_10`
    - `high_chain_score_3`
    - `high_chain_score_5`
    - `high_chain_score_10`
  - Existing `signal_features.tsv` output remains byte-compatible except for timestamp/order effects from runtime.
  - Invalid values are tagged per field.
- **Validation**:
  - Static diff of feature header and builder.
  - Compile at sprint end.

### Task 3.2: Preserve Statistics Export Behavior

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Update `DeterministicSignalStatsBuildFeatureRow()` to format rows from the shared snapshot without changing schema version or column order.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - `DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION` remains `1`.
  - `DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER` remains unchanged.
  - `DeterministicSignalStatsRecordFeature()` is still called only after broker entry succeeds.
  - Existing Phase 1 dataset builder remains compatible.
- **Validation**:
  - `rg "DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER|MODEL_FEATURE_COLUMNS" services tools`
  - Compile at sprint end.
  - Optional human-in-the-loop short export run confirms `signal_features.tsv` still validates with Phase 2 tooling.

### Task 3.3: Encode Numeric And One-Hot Features

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Encode one signal snapshot into the loaded feature map.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Numeric features are converted to `double`.
  - One-hot features compare source column and category exactly as exported in `feature_map.tsv`.
  - Missing categorical values only match `__MISSING__` when that category exists.
  - Missing numeric values are represented in a way the scorer can route by `default_left`.
  - Encoded vector size equals manifest `encoded_feature_count`.
- **Validation**:
  - Static review against `model_artifact_validator.py::encode_rows`.
  - Compile at sprint end.

### Task 3.4: Add Per-Signal Shadow State

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add fields to keep shadow prediction state from entry through terminal outcome.
- **Recommended Fields**:
  - `ml_shadow_signal_id`
  - `ml_shadow_evaluated`
  - `ml_shadow_available`
  - `ml_shadow_feature_valid`
  - `ml_shadow_model_id`
  - `ml_shadow_export_id`
  - `ml_shadow_classifier_score`
  - `ml_shadow_regressor_score`
  - `ml_shadow_threshold`
  - `ml_shadow_recommendation`
  - `ml_shadow_reason`
  - `ml_shadow_outcome_exported`
- **Dependencies**: Task 3.3.
- **Acceptance Criteria**:
  - Default constructor initializes all fields.
  - Copy constructor copies all fields.
  - No aggregate initialization is introduced.
  - Fields do not affect signal lifecycle predicates.
- **Validation**:
  - Static constructor/copy-constructor review.
  - Compile at sprint end.

### Task 3.5: Build Stable Shadow Signal Identity

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Reuse or extract deterministic signal ID logic so shadow telemetry can identify signals even when statistics export is disabled.
- **Dependencies**: Task 3.4.
- **Acceptance Criteria**:
  - If statistics export is active and has assigned a `signal_id`, shadow telemetry uses the same ID.
  - If statistics export is disabled, shadow telemetry builds a stable ID from shadow run ID, source key, and attempt index.
  - Source key and attempt index are always recorded.
- **Validation**:
  - Static review.
  - Query debug sample shows non-empty `signal_id` or explicit fallback ID.

## Sprint 4: Shadow Scoring And Telemetry

**Goal**: Score deterministic broker-entered signals once, log the recommendation, and join it to broker-confirmed outcomes without influencing trade execution.
**Commit**: `feat: record ml shadow scores`
**Demo/Validation**:
- With `SHADOW` and a valid artifact, a broker-entered deterministic signal emits one shadow prediction.
- The score is recorded after `ExecuteExecutionLegTrade()` succeeds.
- Broker admission and execution remain unchanged by score/recommendation.
- Terminal outcome records join back to the prediction by signal ID.

### Task 4.1: Implement Tree Scoring

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Traverse loaded classifier trees and optional regressor trees using the encoded feature vector.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Starts classifier margin from manifest `classifier_base_score`.
  - Adds each classifier leaf value and applies logistic probability.
  - Starts regressor margin from manifest `regressor_base_score` and records raw regression score when available.
  - Uses `default_left` routing for missing numeric values.
  - Does not allocate or read files during scoring.
  - Handles invalid tree references by marking model unavailable for future scores, not by blocking trades.
- **Validation**:
  - Static review against `model_artifact_validator.py::score_margin`.
  - Compile at sprint end.

### Task 4.2: Score At Broker-Entered Boundary

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Call the shadow scorer only after `ExecuteExecutionLegTrade()` succeeds and after the signal has enough broker entry context.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - No scoring before spread, session, license, market-status, margin, broker stops/freeze, volume normalization, or protection gates.
  - No scoring for expired or pending-only candidates.
  - No scoring every tick.
  - Scoring result does not affect return values, leg status, or broker operations.
- **Validation**:
  - Static lifecycle review.
  - Compile at sprint end.
  - Query debug sample confirms `DETERMINISTIC_ENTRY` still appears regardless of recommendation.

### Task 4.3: Add Shadow Prediction Export

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Write buffered `shadow_predictions.tsv` rows under `Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>`.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - File I/O is gated by `ML_INFERENCE_SHADOW`.
  - Output writes manifest/header before rows.
  - Rows include model identity, feature schema version, signal identity, score, threshold, recommendation, reason, and validity flags.
  - Buffering avoids one file open per tick.
  - Full feature vectors are not written unless needed by the parity validator; if included, keep columns bounded to Phase 1 `MODEL_FEATURE_COLUMNS`.
- **Validation**:
  - Static review.
  - Short Strategy Tester run confirms files are created only in `SHADOW`.

### Task 4.4: Add Query Debug Shadow Logs

- **Location**:
  - `services/trading_signals/execution_logging.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Emit compact logs for model load, unavailable state, and per-signal score.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - `ML_MODEL_LOAD` logs one compact load result.
  - `ML_UNAVAILABLE` logs first occurrence and then throttles repeated reasons.
  - `ML_SHADOW_SCORE` logs one line per scored signal.
  - Logs include `signal_id`, `source_key`, `score`, `threshold`, `recommendation`, and `reason`.
  - Logs do not dump tree rows, feature map rows, full artifacts, or long arrays.
- **Validation**:
  - Static review.
  - Short query-debug run confirms log size remains bounded.

### Task 4.5: Add Shadow Outcome Export

- **Location**:
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Record shadow outcomes when a broker-confirmed deterministic signal closes or is forced closed.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - Outcome rows are written only for signals with a prior shadow prediction.
  - Outcome rows join by `signal_id`, `source_key`, and attempt index.
  - Existing `DeterministicSignalStatsRecordOutcome()` behavior remains unchanged.
  - Forced-close/protection outcomes record terminal reason without changing protection behavior.
- **Validation**:
  - Static lifecycle review.
  - Short Strategy Tester run with at least one closed signal, if human-in-the-loop conditions allow.

### Task 4.6: Write Shadow Summary On Deinit

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Flush buffers and write summary counts during EA deinit.
- **Dependencies**: Task 4.5.
- **Acceptance Criteria**:
  - Summary includes prediction rows, outcome rows, unavailable count, invalid feature count, and export status.
  - Deinit flush failures are logged compactly.
  - Runtime arrays are cleared.
- **Validation**:
  - Static review.
  - Compile at sprint end.

## Sprint 5: Python Parity Validator And Acceptance Evidence

**Goal**: Prove that MQL5 shadow predictions match the Python artifact scorer within a documented tolerance, without adding a custom MQL5 test harness.
**Commit**: `test: add ml shadow parity validation`
**Demo/Validation**:
- Python can read `shadow_predictions.tsv`, reload the same export artifact, recompute scores, and report pass/fail compactly.
- Acceptance evidence records row counts, max absolute error, decision agreement, compile status, and remaining Windows validation state.

### Task 5.1: Include Feature Columns Required For Parity

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Ensure `shadow_predictions.tsv` contains enough raw model feature columns to let Python recompute the score.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Includes the 17 `MODEL_FEATURE_COLUMNS` or an explicitly versioned companion feature file.
  - Does not include full encoded vector unless required.
  - Does not include account credentials, license data, or broker-private identifiers.
- **Validation**:
  - Static header review.
  - Python validator dry run after Strategy Tester output exists.

### Task 5.2: Add Python Shadow Prediction Validator

- **Location**:
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Add a local Python command that loads the Phase 4 export and the MQL5 shadow predictions, then recomputes classifier/regressor outputs with the existing artifact scorer.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Supports `--export-id` or `--export-path`.
  - Supports `--shadow-run-path`.
  - Uses existing `model_artifact_validator.py` scoring functions where practical.
  - Reports row count, classifier max abs error, classifier mean abs error, threshold decision agreement, and regressor max abs error when present.
  - Exits nonzero when tolerance fails.
  - Prints compact output only.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - Run against available shadow output after a human-in-the-loop Strategy Tester run.

### Task 5.3: Define Parity Tolerances

- **Location**:
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - `docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`
- **Description**: Set explicit tolerances that account for MQL5/Python float differences while catching real scoring drift.
- **Dependencies**: Task 5.2.
- **Recommended Tolerances**:
  - Classifier max absolute error: `<= 1e-6`.
  - Regressor max absolute error: `<= 1e-6` when regressor is loaded.
  - Threshold decision agreement: `1.0`.
- **Acceptance Criteria**:
  - Tolerances are documented.
  - Failures print first few signal IDs and differences only.
  - Full prediction files are not pasted into chat.
- **Validation**:
  - Python validator run.

### Task 5.4: Record Phase 5 Acceptance Evidence

- **Location**:
  - `docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`
- **Description**: Add compact evidence for Ubuntu/Wine compile, artifact load, shadow run, and parity.
- **Dependencies**: Task 5.3.
- **Acceptance Criteria**:
  - Records OS, MT5 root, Common Files artifact path, export ID, model ID, compile log path, final compile status, `.ex5` timestamp, shadow run path, prediction rows, outcome rows, parity result, and known gaps.
  - Windows validation remains pending unless a human supplies Windows compile evidence.
  - No full logs, full TSVs, JSON trees, or Parquet contents are included.
- **Validation**:
  - Static review.
  - `rg "Phase 5|shadow|parity|xgb_test_1_export_v1|0 errors, 0 warnings" docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`

## Sprint 6: Final Documentation And Phase 6 Handoff

**Goal**: Document how to operate Phase 5 safely and prepare a clear handoff for future `FILTER` mode without implementing it.
**Commit**: `docs: document ml shadow inference handoff`
**Demo/Validation**:
- A future agent can run Phase 5 in shadow mode from the runbook.
- README and AGENTS make the no-filter boundary explicit.
- Phase 6 remains blocked until shadow parity and human review are accepted.

### Task 6.1: Update Operator Workflow Docs

- **Location**:
  - `README.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Document the full Phase 5 workflow: validate export, copy artifact to Common Files, enable `SHADOW`, run tester, validate parity, inspect compact evidence.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Includes Ubuntu/Wine command sequence.
  - Includes Windows command shape but marks Windows evidence as human-in-the-loop if not validated.
  - States `SHADOW` never blocks trades.
  - States generated shadow outputs are ignored.
- **Validation**:
  - Static review.
  - `rg "ML_Inference_Mode|SHADOW|compare_shadow_predictions|shadow_runs" README.md docs/environment/mt5-agentic-workflows.md tools/deterministic_signal_ml/README.md`

### Task 6.2: Update Agent Guardrails

- **Location**:
  - `AGENTS.md`
- **Description**: Add compact Phase 5 guardrails for future Codex agents.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - States Phase 5 is shadow-only.
  - States `FILTER` is not available until a future explicit Phase 6 plan.
  - States ML must not weaken license, session, spread, margin, protection, magic-number, or broker reconciliation controls.
  - States full shadow TSVs and tree files must not be pasted into chat.
- **Validation**:
  - Static review.
  - `rg "Phase 5|SHADOW|FILTER|shadow TSV|broker reconciliation" AGENTS.md`

### Task 6.3: Add Phase 6 Readiness Notes

- **Location**:
  - `docs/plans/deterministic-signal-ml-roadmap.md`
  - `docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`
- **Description**: Record what evidence is required before planning `FILTER` mode.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Requires clean compile.
  - Requires successful artifact load.
  - Requires parity validator pass.
  - Requires enough shadow rows/outcomes for human review.
  - Requires explicit human approval before any model affects broker admission.
- **Validation**:
  - Static review.
  - `rg "Phase 6|FILTER|human approval|parity" docs/plans/deterministic-signal-ml-roadmap.md docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`

### Task 6.4: Final Compile And Handoff

- **Location**:
  - `logs/compile/phase-05-shadow-inference.log`
  - `docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`
- **Description**: Run final Ubuntu/Wine real compile and update acceptance evidence.
- **Dependencies**: Tasks 6.1 through 6.3.
- **Acceptance Criteria**:
  - Compile helper reports `0 errors, 0 warnings`.
  - `.ex5` timestamp changes.
  - Evidence doc names remaining runtime validation gaps, if any.
  - Sprint-specific commit is made only after validation.
- **Validation**:
  - Preferred compile command from this plan.

## Testing Strategy

- Use static review for include order, input defaults, enum stability, file path sandboxing, and no trading-behavior dependencies.
- Use Python syntax checks for new Python validator scripts.
- Use `model_artifact_validator.py` before copying artifacts into `Common\Files`.
- Use MetaEditor real compile at each implementation sprint end, not after every atomic task.
- Use human-in-the-loop Strategy Tester runs for runtime shadow output.
- Use `compare_shadow_predictions.py` to validate MQL5 scores against the Python scorer.
- Treat compiler warnings as failures.
- Keep evidence compact: paths, row counts, status lines, timestamps, and selected failures only.

## Safety Gate

Phase 5 passes only if all of the following are true:

- Default `ML_Inference_Mode=DISABLED` preserves current behavior.
- `SHADOW` mode cannot block, open, close, resize, delay, or alter trades.
- Missing/bad artifacts produce `ML_UNAVAILABLE` and fail open.
- Model scoring happens only after broker entry succeeds.
- Feature schema version, feature map, and tree counts match the artifact manifest.
- Shadow prediction and outcome rows join by signal identity.
- Python parity validator passes within tolerance.
- Ubuntu/Wine compile is clean.
- Windows status is either validated or explicitly documented as pending human validation.

## Potential Risks And Gotchas

- **Feature drift**: If MQL5 shadow scoring uses a different feature builder than Phase 1 export, scores will be meaningless. Mitigation: extract a shared feature snapshot helper and keep Phase 1 header/schema unchanged.
- **Signal ID drift when stats export is disabled**: Existing stats signal IDs depend on stats run state. Mitigation: define a shadow run ID fallback and prefer the stats signal ID only when it already exists.
- **Artifact path mismatch**: Repository artifacts are not runtime artifacts. Mitigation: load only from `FILE_COMMON` and document the copy/restore step.
- **Tree parsing cost or memory growth**: Tree TSVs are small today but should still be bounded. Mitigation: validate manifest counts, reserve arrays, load once on init, and never allocate per tick.
- **MQL5 floating point differences**: Python parity is already near `1e-7`; MQL5 may differ slightly. Mitigation: use explicit tolerance and threshold agreement checks.
- **Hidden trading behavior change**: A score result might accidentally influence a branch. Mitigation: keep scorer calls side-effect-free except telemetry and review every callsite.
- **Log blowup**: Per-tick unavailable logs or feature dumps can recreate `query_debug.txt` bloat. Mitigation: one load log, one score log per signal, throttled unavailable reasons, no full artifact dumps.
- **Regressor complexity**: Regressor scoring is useful telemetry but secondary. Mitigation: if regressor load or parity is risky, classifier-only shadow is acceptable for Phase 5 with the regressor marked unavailable.
- **Windows parity gap**: Phase 4.5 has Ubuntu/Wine readiness but Windows compile remains pending. Mitigation: do not claim cross-platform completion until Windows compile evidence is added.

No unresolved product questions remain after the approved recommendations. If implementation discovers that MQL5 cannot safely parse or score the exported TSV within bounded runtime cost, stop and choose between classifier-only runtime, generated `.mqh`, or a revised artifact format before proceeding.

## Rollback Plan

- Revert Phase 5 MQL5 files and includes:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - related additions in `services/trading_signals.mqh`
  - `HFT_Grid_AI.mq5` init/deinit calls
  - `SignalParams` shadow fields
  - ML enum/input additions
- Revert Phase 5 Python validator files under `tools/deterministic_signal_ml/`.
- Revert Phase 5 docs and acceptance evidence.
- Remove generated shadow output folders from `Common\Files` manually if desired.
- Keep Phase 1-4 datasets, models, exports, and Phase 4.5 runbook intact.
- Because Phase 5 is shadow-only, rollback should not require broker-state repair.
