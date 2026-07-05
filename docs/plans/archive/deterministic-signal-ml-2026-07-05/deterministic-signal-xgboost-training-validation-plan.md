# Plan: Deterministic Signal XGBoost Training And Validation

**Generated**: 2026-07-04
**Status**: Completed and archived on 2026-07-05
**Estimated Complexity**: Medium-High
**Risk Level**: Low for EA trading behavior; High for ML leakage/overfitting if
validation is weak.

## Overview

Implement Phase 3 of the deterministic signal ML roadmap: local Python training
and validation from Phase 2 Parquet datasets.

This phase trains and evaluates baseline models plus XGBoost classifier/regressor
models. It must produce reproducible training artifacts, validation reports, and
threshold recommendations for a future shadow-inference phase. It must not modify
the EA, export an MT5-readable model artifact, run inference in Strategy Tester,
connect to PostgreSQL, or affect broker admission.

## Current Documentation Basis

- XGBoost Python scikit-learn API supports `XGBClassifier`,
  `XGBRegressor`, `tree_method="hist"`, `eval_set`, early stopping, evaluation
  results, `predict_proba`, and JSON model saving.
- scikit-learn `TimeSeriesSplit` supports ordered train/test folds where each
  training set precedes its test set, with optional `gap`.
- scikit-learn metrics cover ROC AUC, average precision, precision, recall, F1,
  log loss, Brier score, confusion matrix, MAE, MSE/RMSE, and related evaluation
  primitives.

## Recommended Direction

- Keep Phase 3 as Python-only local research tooling under
  `tools/deterministic_signal_ml/`.
- Add `xgboost`, `scikit-learn`, and their required numeric dependencies through
  `requirements.txt`.
- Avoid pandas/Polars unless DuckDB + NumPy becomes insufficient.
- Do not use random train/test splits. Sort by `entry_time` and use
  time-based holdout plus walk-forward folds.
- Do not use XGBoost native categorical handling yet. Use deterministic explicit
  numeric encoding so Phase 4 can export trees to MT5 cleanly.
- Treat `target_is_win` as the primary classifier target.
- Treat `target_profit_r` as the secondary regression target.
- Use built-in XGBoost feature importance first. Defer SHAP unless the first
  model report clearly needs it.
- Emit threshold recommendations only as research metadata. No trade filtering
  exists in this phase.

## Non-Goals

- No MQL5 changes.
- No EA inputs.
- No Strategy Tester inference.
- No Python calls from MQL5.
- No MT5-readable tree artifact yet.
- No PostgreSQL.
- No live trading decisions.
- No generated model artifacts committed to git.
- No random-split performance claims.

## Proposed File Layout

```text
tools/deterministic_signal_ml/
  train_model.py
  model_config.py
  feature_encoder.py
  validation_splits.py
  training_report.py

artifacts/models/<model_id>/
  model_manifest.json
  classifier_xgboost.json
  regressor_xgboost.json
  feature_encoder.json
  validation_report.md
  validation_metrics.json
  threshold_report.tsv
  fold_predictions.parquet
  holdout_predictions.parquet
```

`artifacts/models/` should be ignored by git.

## Input Contract

The training command reads a Phase 2 dataset folder:

```text
artifacts/datasets/<dataset_id>/
  dataset_manifest.json
  dataset_quality.json
  training_matrix.parquet
```

Recommended CLI shape:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-id test_dataset_1 `
  --model-id xgb_test_1
```

Recommended explicit path variant:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-path artifacts\datasets\test_dataset_1 `
  --model-id xgb_test_1
```

## Output Contract

### `model_manifest.json`

Machine-readable model run contract:

- model ID
- dataset ID
- source run IDs
- source config IDs
- Phase 1 schema version
- Phase 2 builder version
- Phase 3 trainer version
- feature columns
- encoded feature names
- target columns
- split policy
- model parameters
- validation summary
- threshold recommendation summary

### `feature_encoder.json`

Deterministic encoding contract:

- numeric passthrough columns
- categorical columns
- ordered category values
- one-hot encoded feature names
- missing-value policy
- encoded feature order

### `validation_metrics.json`

Machine-readable metrics:

- baseline metrics
- decision tree metrics
- XGBoost classifier metrics
- XGBoost regressor metrics
- per-fold metrics
- holdout metrics
- feature importance
- calibration/threshold table summary

### `validation_report.md`

Human-readable report:

- dataset summary
- target distribution
- split ranges
- baseline comparison
- classifier metrics
- regression metrics
- feature importance
- threshold recommendations
- warnings and limitations

### Prediction Outputs

- `fold_predictions.parquet`: out-of-fold predictions with realized outcomes.
- `holdout_predictions.parquet`: final holdout predictions with realized
  outcomes.

These files are for analysis only and are not MT5 model artifacts.

## Sprint 1: Training Contract And Dependencies

**Goal**: Add the Phase 3 training boundary, dependencies, and config skeleton
without training a model yet.
**Commit**: `docs: define deterministic signal xgboost training plan`
**Demo/Validation**:
- Static review confirms no MQL5 or EA runtime changes.
- Python imports for XGBoost/scikit-learn succeed in the local `.venv`.

### Task 1.1: Add Dependency Contract

- **Location**:
  - `tools/deterministic_signal_ml/requirements.txt`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Add XGBoost and scikit-learn dependencies for local training.
- **Dependencies**: Phase 2 dataset builder.
- **Acceptance Criteria**:
  - `duckdb` remains supported.
  - `xgboost` import succeeds.
  - `sklearn` import succeeds.
  - No pandas/Polars/SHAP dependency is added by default.
- **Validation**:
  - `.\.venv\Scripts\python.exe -c "import duckdb, xgboost, sklearn"`

### Task 1.2: Add Trainer Skeleton

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/model_config.py`
- **Description**: Add CLI parsing and model configuration defaults.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Accepts `--dataset-id` or `--dataset-path`.
  - Accepts `--model-id`.
  - Accepts `--output-root`, defaulting to `artifacts/models`.
  - Accepts `--overwrite`.
  - Fails clearly when the dataset folder is missing.
- **Validation**:
  - Run `--help`.
  - Run against missing dataset and confirm clear nonzero error.

### Task 1.3: Add Artifact Ignore Rules

- **Location**:
  - `.gitignore`
- **Description**: Ignore generated model artifacts.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - `artifacts/models/` is ignored.
  - Generated model artifacts are not committed.
- **Validation**:
  - `git check-ignore -v artifacts/models/example/model_manifest.json`

## Sprint 2: Dataset Loading And Feature Encoding

**Goal**: Load Phase 2 datasets and create a deterministic encoded feature
matrix suitable for local models and future MT5 artifact export.
**Commit**: `feat: encode deterministic signal training features`
**Demo/Validation**:
- `test_dataset_1` loads successfully.
- Encoded feature matrix has stable columns and no target leakage.

### Task 2.1: Load Dataset Manifest And Quality

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
- **Description**: Read `dataset_manifest.json`, `dataset_quality.json`, and
  `training_matrix.parquet`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Fails if dataset quality status is not `OK` unless an explicit override is
    later added.
  - Uses manifest feature/target column groups.
  - Confirms required targets exist.
- **Validation**:
  - Load `artifacts/datasets/test_dataset_1`.

### Task 2.2: Build Deterministic Feature Encoder

- **Location**:
  - `tools/deterministic_signal_ml/feature_encoder.py`
- **Description**: Convert Phase 2 features into numeric arrays.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Numeric features pass through as float values.
  - Categorical features are one-hot encoded with stable sorted categories.
  - Missing category policy is explicit.
  - Encoded feature order is deterministic.
  - Outcome/target/audit columns are excluded from model features.
- **Validation**:
  - Generated `feature_encoder.json` lists encoded columns.
  - Encoded matrix row count equals `training_matrix` row count.

### Task 2.3: Add Dataset Minimum Guards

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/model_config.py`
- **Description**: Add minimum row and target-balance checks before training.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Fails clearly when dataset rows are below threshold.
  - Fails clearly when target has one class only.
  - Warns when sample size is too small for high-confidence conclusions.
- **Validation**:
  - `test_dataset_1` passes minimum guards.

## Sprint 3: Time-Based Validation Splits And Baselines

**Goal**: Establish trustworthy validation before training XGBoost.
**Commit**: `feat: add deterministic signal validation baselines`
**Demo/Validation**:
- Reports baseline and simple decision tree performance on time-ordered splits.

### Task 3.1: Build Time Split Policy

- **Location**:
  - `tools/deterministic_signal_ml/validation_splits.py`
- **Description**: Sort by `entry_time` and create validation folds.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - No random shuffle.
  - Final holdout segment is chronologically after training data.
  - Walk-forward folds train only on past rows and test on future rows.
  - Split metadata records row counts and time ranges.
- **Validation**:
  - Print/record fold ranges for `test_dataset_1`.

### Task 3.2: Add Classification Baselines

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Train simple baselines before XGBoost.
- **Recommended Baselines**:
  - majority-class baseline
  - strategy/direction bucket baseline if practical
  - shallow `DecisionTreeClassifier`
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Baseline metrics include accuracy, balanced accuracy, precision, recall,
    F1, ROC AUC when available, average precision, log loss where valid, and
    confusion matrix.
  - Baseline metrics are recorded per fold and on final holdout.
- **Validation**:
  - Baselines run on `test_dataset_1`.

### Task 3.3: Add Regression Baselines

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Establish non-XGBoost `profit_r` baselines.
- **Recommended Baselines**:
  - global mean prediction
  - strategy/direction bucket mean
  - shallow `DecisionTreeRegressor`
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Metrics include MAE, RMSE, mean predicted R, mean realized R, and simple
    correlation where valid.
  - Baselines are recorded per fold and on holdout.
- **Validation**:
  - Baselines run on `test_dataset_1`.

## Sprint 4: XGBoost Training And Evaluation

**Goal**: Train conservative XGBoost classifier/regressor models and compare
against baselines using time-aware validation.
**Commit**: `feat: train deterministic signal xgboost models`
**Demo/Validation**:
- XGBoost models train on `test_dataset_1` and produce validation metrics,
  feature importance, and saved JSON models.

### Task 4.1: Train XGBoost Classifier

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/model_config.py`
- **Description**: Train `XGBClassifier` for `target_is_win`.
- **Recommended Defaults**:
  - `tree_method="hist"`
  - modest `max_depth`
  - modest `n_estimators`
  - learning rate below `0.1`
  - `eval_metric="logloss"`
  - early stopping against validation/holdout split where appropriate
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Uses only encoded feature columns.
  - Produces holdout probabilities via `predict_proba`.
  - Saves model as JSON under `artifacts/models/<model_id>/`.
  - Records evaluation metrics and eval history.
- **Validation**:
  - Run on `test_dataset_1`.
  - Confirm model JSON file exists.
  - Confirm metrics JSON has classifier section.

### Task 4.2: Train XGBoost Regressor

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/model_config.py`
- **Description**: Train `XGBRegressor` for `target_profit_r`.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Uses the same encoded feature matrix.
  - Records MAE/RMSE and simple directional usefulness metrics.
  - Saves model as JSON.
  - Does not replace classifier as the primary shadow-inference candidate until
    evidence supports it.
- **Validation**:
  - Run on `test_dataset_1`.
  - Confirm model JSON file exists.
  - Confirm metrics JSON has regressor section.

### Task 4.3: Feature Importance And Stability Checks

- **Location**:
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Report feature importance and basic stability across folds.
- **Dependencies**: Tasks 4.1 and 4.2.
- **Acceptance Criteria**:
  - Feature importance lists encoded feature names.
  - Report flags features with no variation in the dataset.
  - Report flags if importance is dominated by one unstable categorical bucket.
  - SHAP is not required in this phase.
- **Validation**:
  - `macro_d1_live_dir` constant in `test_dataset_1` should be flagged as
    no-variation or low-information for this dataset.

## Sprint 5: Threshold Recommendations And Reports

**Goal**: Produce decision-threshold research outputs for future shadow
inference without changing EA behavior.
**Commit**: `docs: document deterministic signal xgboost validation`
**Demo/Validation**:
- Training run produces model artifacts and a validation report clear enough to
  decide whether Phase 4 is justified.

### Task 5.1: Build Threshold Report

- **Location**:
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Evaluate classifier probability thresholds against realized
  outcomes.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - `threshold_report.tsv` includes threshold, selected rows, selected percent,
    win rate, mean `profit_r`, net `profit_r`, and drawdown-like simple loss
    proxy.
  - Report enforces a minimum selected-trades count before recommending a
    threshold.
  - Recommendations are labeled research-only.
- **Validation**:
  - Threshold report generated for `test_dataset_1`.

### Task 5.2: Write Training Artifacts

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Write model manifest, metrics JSON, reports, predictions, and
  encoder contract.
- **Dependencies**: Sprint 4 and Task 5.1.
- **Acceptance Criteria**:
  - `model_manifest.json` links dataset ID, model ID, feature encoder, source
    config IDs, and validation summaries.
  - `validation_metrics.json` includes per-fold and holdout metrics.
  - `fold_predictions.parquet` and `holdout_predictions.parquet` are readable by
    DuckDB.
  - Generated model artifacts are ignored by git.
- **Validation**:
  - Read back generated Parquet prediction files.
  - Inspect manifest and report.

### Task 5.3: Document Operator Workflow And Acceptance Evidence

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `README.md`
  - optional `docs/research/`
- **Description**: Document the local training command, outputs, limitations,
  and accepted validation run.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Documentation states Phase 3 is research-only.
  - Documentation states no EA inference/filtering exists yet.
  - Documentation explains why random split metrics are not used.
  - Acceptance evidence records dataset ID, model ID, row counts, split policy,
    and key metrics.
- **Validation**:
  - `git status --short` shows no generated model artifacts.

## Testing Strategy

- No MT5 compile is required because Phase 3 should not touch MQL5.
- No Strategy Tester run is required if a validated Phase 2 dataset exists.
- Use the current real dataset:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-id test_dataset_1 `
  --model-id xgb_test_1 `
  --overwrite
```

- Required validation:
  - Python syntax compile for all Phase 3 modules.
  - Dependency imports for DuckDB, XGBoost, and scikit-learn.
  - Dataset quality must be `OK`.
  - Encoded matrix row count equals `training_matrix.parquet` row count.
  - Time splits are chronological.
  - Baseline metrics are generated before XGBoost metrics.
  - XGBoost models save to JSON.
  - Prediction Parquet files read back successfully.
  - Generated model artifacts remain ignored by git.

## Potential Risks And Gotchas

- **Time leakage**: Random splits can make the model look better than it is.
  Mitigation: sort by `entry_time`, use final holdout and walk-forward folds.
- **Feature leakage**: Outcome columns can accidentally enter model input.
  Mitigation: use Phase 2 manifest feature columns and explicit encoder.
- **Categorical export complexity**: XGBoost native categorical splits may be
  harder to export to MQL5 later. Mitigation: deterministic one-hot encoding.
- **Small sample overfitting**: `test_dataset_1` has 2821 rows, which is useful
  for pipeline validation but not enough for robust conclusions alone.
  Mitigation: require more runs before treating thresholds as production-grade.
- **Constant features**: Some macro features can be constant in a short run.
  Mitigation: report no-variation features and do not overinterpret importance.
- **Threshold overfitting**: Selecting the best threshold from the same holdout
  can overstate expected performance. Mitigation: mark recommendations as
  research-only and require later shadow validation.
- **Artifact confusion**: XGBoost JSON model is not yet MT5-readable. Mitigation:
  label Phase 3 artifacts as Python training artifacts only.
- **Dependency size**: XGBoost/scikit-learn are heavier than Phase 2. Mitigation:
  keep them isolated in local `.venv`, never in EA runtime.

## Open Questions With Recommendations

1. **Primary success target**
   - **Recommendation**: optimize first for `target_is_win` classifier and use
     `target_profit_r` regression as secondary interpretation.
   - **Alternative**: optimize directly for `profit_r` and derive allow/block
     from predicted R.

2. **Split policy**
   - **Recommendation**: final chronological holdout of 20% plus walk-forward
     folds on the earlier 80%.
   - **Alternative**: pure walk-forward over the full dataset with no separate
     final holdout.

3. **Categorical encoding**
   - **Recommendation**: deterministic one-hot encoding, even if it creates more
     columns, because it is easier to audit and export later.
   - **Alternative**: native XGBoost categorical features for Python-only speed,
     deferred export handling later.

## Rollback Plan

- Remove Phase 3 Python files from `tools/deterministic_signal_ml/`.
- Remove XGBoost/scikit-learn lines from `requirements.txt`.
- Delete generated `artifacts/models/` output.
- Revert README/research documentation updates.
- No EA rollback is needed because Phase 3 should not modify MQL5 runtime code.
