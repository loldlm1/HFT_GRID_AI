# Plan: ML Validation Hardening

**Generated**: 2026-07-05
**Estimated Complexity**: Medium
**Roadmap Phase**: Phase 1 of `docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: Medium, statistical and Python tooling behavior

## Overview

Strengthen the deterministic signal ML research pipeline before adding new
features, changing runtime arbitration, expanding symbols, or testing dynamic
targets. This phase is intentionally Python/docs-only: it must not change MQL5,
EA inputs, Strategy Tester behavior, broker admission, model scoring in MQL5, or
runtime artifacts.

The current one-month `test_dataset_1` / `xgb_test_1` / `xgb_test_1_export_v1`
baseline is acceptable for smoke validation of the new tooling. It is not
accepted as a real model-development dataset. A fresh one-to-two-year Strategy
Tester run should be generated only after this plan's tooling and reports pass
against the short baseline.

The core change is methodological: threshold selection must stop using the same
final holdout that is used to declare model approval. The plan should introduce
clear report contracts, split policies, segment diagnostics, ablation support,
and acceptance evidence so later phases can reject noisy feature candidates
instead of accidentally optimizing overfit.

## Prerequisites

- Existing deterministic signal ML workflow remains available:
  `docs/workflows/deterministic-signal-ml-inference-flows.md`.
- Roadmap parent exists:
  `docs/plans/ml-robustness-and-signal-selection-roadmap.md`.
- Current smoke baseline artifacts exist or can be regenerated:
  - `artifacts/datasets/test_dataset_1/`
  - `artifacts/models/xgb_test_1/`
  - `artifacts/model_exports/xgb_test_1_export_v1/`
- Python virtual environment dependencies from
  `tools/deterministic_signal_ml/requirements.txt` are installed.
- Generated artifacts stay ignored by git unless a future human explicitly
  changes that policy.

## External Documentation Notes

- scikit-learn `TimeSeriesSplit` supports chronological splits where training
  samples precede test samples and includes a `gap` parameter for leakage
  control.
- DuckDB supports direct `read_parquet(...)` queries and `COPY (SELECT ...) TO`
  Parquet/CSV for compact local reports.
- XGBoost sklearn estimators support `eval_set`, early stopping, `predict`,
  `predict_proba`, `best_iteration`, and validation reporting.

## Scope

- Add or adjust Python research tooling under `tools/deterministic_signal_ml/`.
- Add compact documentation and acceptance evidence under `docs/research/`.
- Preserve existing Phase 1-6 runtime behavior.
- Preserve existing training/export commands until a new robust workflow is
  explicitly accepted.
- Use current baseline only as a tooling smoke test.
- Define the point at which a real one-to-two-year Strategy Tester run becomes
  required.

## Non-Goals

- No `.mq5` or `.mqh` changes.
- No MetaEditor compile requirement.
- No Strategy Tester runtime changes.
- No new model features.
- No ONNX work.
- No signal arbitration work.
- No live trading approval.
- No generated large artifacts committed to git.
- No custom MQL5 tests or CI.

## Sprint 1: Baseline Contract And Report Schema

**Goal**: Freeze the current smoke baseline as a reproducible reference and
define the robustness report contract before changing split or threshold logic.

**Commit**: `docs: define ml validation hardening contract`

**Demo/Validation**:

- Run Python syntax checks for touched Python files.
- Inspect the generated baseline contract summary.
- Confirm no MQL5 files changed.
- Confirm the plan still treats `test_dataset_1` as smoke evidence only.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Capture Baseline Inventory Contract

- **Location**:
  - `tools/deterministic_signal_ml/model_validation_config.py` or equivalent new helper
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Define a compact baseline inventory structure that records
  dataset ID, model ID, export ID, source run IDs, config IDs, row counts,
  encoded feature count, current threshold, and artifact paths.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Baseline metadata can be loaded from existing manifest files without reading
    full TSV prediction files into chat.
  - Missing baseline files fail with actionable messages.
  - The helper names `test_dataset_1`, `xgb_test_1`, and `xgb_test_1_export_v1`
    as smoke baseline defaults only.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/model_validation_config.py`
  - Run the helper or planned CLI against current baseline and inspect compact output.

### Task 1.2: Define Robustness Report Output Contract

- **Location**:
  - `tools/deterministic_signal_ml/robustness_report.py`
  - `docs/research/ml-validation-hardening-acceptance.md`
- **Description**: Specify machine-readable and human-readable report outputs
  before implementing metrics. Recommended generated files:
  - `robustness_metrics.json`
  - `robustness_report.md`
  - `threshold_selection.tsv`
  - `segment_metrics.tsv`
  - `overfit_warnings.tsv`
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Report schema separates threshold-selection evidence from final holdout
    approval evidence.
  - Report schema records whether the dataset is smoke-only or real-research
    grade.
  - Documentation states that current one-month baseline is not enough for real
    feature acceptance.
- **Validation**:
  - Review report field names for deterministic ordering.
  - Confirm large generated files remain under `artifacts/`.

### Task 1.3: Add Baseline Reproduction Command Shape

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `docs/research/ml-validation-hardening-acceptance.md`
- **Description**: Document the intended command shape for baseline robustness
  validation without committing generated outputs.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - README shows a command using `--dataset-id test_dataset_1`,
    `--model-id xgb_test_1`, and `--export-id xgb_test_1_export_v1`.
  - Acceptance doc includes placeholders for command, status, row counts,
    threshold split policy, warnings, and result.
- **Validation**:
  - Manual doc review.

## Sprint 2: Split And Threshold Hardening

**Goal**: Add a robust chronological split policy that keeps threshold selection
separate from final approval and makes leakage risk visible.

**Commit**: `feat: harden ml validation splits`

**Demo/Validation**:

- Run syntax checks for touched Python files.
- Run split validation against `test_dataset_1`.
- Confirm rows sharing an `entry_time` stay in the same split group.
- Confirm report identifies the current baseline as smoke-only.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Robust Split Metadata

- **Location**:
  - `tools/deterministic_signal_ml/validation_splits.py`
- **Description**: Extend or add a split builder that produces explicit
  partitions for:
  - training core
  - early-stopping validation
  - threshold selection
  - final holdout
  - optional walk-forward folds over pre-final-holdout data
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Split metadata includes row counts, entry-time ranges, unique entry-time
    groups, and gap setting.
  - Split builder keeps equal `entry_time` groups together.
  - Split builder fails clearly when the dataset is too small for requested
    partitions.
  - Default policy remains conservative for short smoke datasets.
- **Validation**:
  - Add focused Python-level validation through a small deterministic in-memory
    row set.
  - `python3 -m py_compile tools/deterministic_signal_ml/validation_splits.py`

### Task 2.2: Move Threshold Recommendation Off Final Holdout

- **Location**:
  - `tools/deterministic_signal_ml/training_report.py`
  - new `tools/deterministic_signal_ml/validate_model_robustness.py`
- **Description**: Compute threshold candidates from threshold-selection rows or
  out-of-fold pre-holdout predictions, not from final holdout predictions.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Final holdout rows are not used to pick the threshold.
  - Output records the threshold source, row count, selected count, mean R, net
    R, win rate, drawdown-like R, and minimum selected rows.
  - If only old `holdout_predictions.parquet` exists, the command emits a
    warning and treats the result as legacy/smoke evidence.
- **Validation**:
  - Run on current `xgb_test_1` artifacts.
  - Confirm report marks any legacy threshold source explicitly.

### Task 2.3: Add Leakage And Sample-Size Warnings

- **Location**:
  - `tools/deterministic_signal_ml/validate_model_robustness.py`
  - `tools/deterministic_signal_ml/robustness_report.py`
- **Description**: Add warnings for short datasets, small selected-trade counts,
  no gap where gap is required, final holdout reuse, and insufficient class
  counts.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Current one-month baseline produces a smoke/short-dataset warning.
  - Warnings are machine-readable and included in the markdown report.
  - Warning logic does not block smoke validation unless required files are
    missing or inconsistent.
- **Validation**:
  - Run robustness command against current baseline and inspect warnings.

## Sprint 3: Segment Diagnostics

**Goal**: Make aggregate improvements harder to overread by reporting model
behavior across strategy, direction, source type, symbol, and score buckets.

**Commit**: `feat: add ml segment diagnostics`

**Demo/Validation**:

- Run robustness command against current baseline.
- Confirm segment reports exist and include row counts, selected counts, win
  rate, mean R, net R, and drawdown-like R where applicable.
- Confirm no segment with too few rows is silently treated as reliable.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Add Segment Metric Builder

- **Location**:
  - `tools/deterministic_signal_ml/robustness_report.py`
  - optional helper `tools/deterministic_signal_ml/segment_metrics.py`
- **Description**: Compute segment metrics for:
  - `strategy_label`
  - `direction`
  - `source_type`
  - `symbol`
  - `strategy_label + direction`
  - score buckets
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Segment rows include total rows, positives, selected rows, selected percent,
    win rate, mean R, net R, and max drawdown-like R.
  - Empty or tiny segments are marked with warning status.
  - Segment output is deterministic and TSV-friendly.
- **Validation**:
  - Run segment builder against `test_dataset_1` model predictions.
  - Inspect known segments: S1/S2/S3, BULLISH/BEARISH, PEAK/BOTTOM, XAUUSD.

### Task 3.2: Add Feature Importance Concentration Checks

- **Location**:
  - `tools/deterministic_signal_ml/robustness_report.py`
  - `tools/deterministic_signal_ml/training_report.py`
- **Description**: Extend existing diagnostics to flag one-hot/category
  concentration, no-variation features, rare bucket dominance, and top-N feature
  dependence.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Warnings identify feature name, importance share, encoded bucket frequency,
    and affected model role where possible.
  - Current baseline can pass with no blocking warning or emit advisory warnings
    only.
  - Future schema v2 categorical features can reuse the same checks.
- **Validation**:
  - Run against current `feature_encoder.json` and validation metrics.

### Task 3.3: Add Human-Readable Robustness Report

- **Location**:
  - `tools/deterministic_signal_ml/robustness_report.py`
- **Description**: Render a markdown report that summarizes baseline metadata,
  split policy, threshold source, final holdout status, segment diagnostics,
  feature warnings, and final recommendation status.
- **Dependencies**: Tasks 3.1 and 3.2.
- **Acceptance Criteria**:
  - Report starts with PASS/WARN/FAIL.
  - Report does not include full prediction rows.
  - Report states whether evidence is smoke-only or research-grade.
- **Validation**:
  - Generate report under `artifacts/models/xgb_test_1/robustness/` or an
    equivalent ignored folder.

## Sprint 4: Ablation And Candidate Comparison Framework

**Goal**: Prepare the validation machinery needed to judge future feature
candidates without implementing schema v2 yet.

**Commit**: `feat: add ml ablation comparison framework`

**Demo/Validation**:

- Compare the baseline model against itself as a no-op candidate.
- Confirm the comparison report marks identical candidates as no material
  improvement.
- Confirm candidate comparison can reject a model with worse or insufficient
  evidence.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Define Candidate Manifest Contract

- **Location**:
  - `tools/deterministic_signal_ml/model_validation_config.py`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Define a lightweight manifest format for comparing model
  candidates by dataset, feature set, model ID, export ID, split policy, and
  threshold policy.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Candidate manifests can represent the current baseline and future schema v2
    candidates.
  - Manifest includes `feature_set_id`, `schema_version`, `dataset_grade`, and
    `notes`.
  - Missing fields fail clearly.
- **Validation**:
  - Create an ignored sample manifest under `artifacts/` or generate one during
    command execution.

### Task 4.2: Add Candidate Comparison Command

- **Location**:
  - `tools/deterministic_signal_ml/compare_model_candidates.py`
- **Description**: Compare two robustness report outputs and summarize
  improvement or degradation by final holdout, threshold-selection evidence, and
  required segments.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Supports baseline versus candidate inputs.
  - Reports metric deltas for selected rows, mean R, net R, drawdown-like R,
    ROC AUC when available, and segment-level regressions.
  - Fails or warns when datasets/splits are not comparable.
  - Produces compact JSON and markdown comparison outputs.
- **Validation**:
  - Compare baseline report against itself and confirm neutral/no-op result.

### Task 4.3: Define Feature Acceptance Gate

- **Location**:
  - `docs/research/ml-validation-hardening-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Document the gate future feature plans must satisfy before a
  feature set can be accepted.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Gate requires threshold chosen outside final holdout.
  - Gate requires no critical segment regression.
  - Gate requires minimum selected rows overall and by important segments.
  - Gate requires no unresolved leakage or rare-bucket dominance warning.
  - Gate states that one-month smoke datasets cannot approve feature additions.
- **Validation**:
  - Manual review against roadmap Phase 3 expectations.

## Sprint 5: Baseline Acceptance Evidence And Real-Run Gate

**Goal**: Prove the validation hardening tooling works on the current short
baseline and define when to generate the real one-to-two-year run.

**Commit**: `docs: record ml validation hardening evidence`

**Demo/Validation**:

- Run all new robustness commands against current baseline.
- Save generated reports under ignored `artifacts/`.
- Summarize compact evidence in `docs/research/ml-validation-hardening-acceptance.md`.
- Confirm no MQL5 compile is required.

Execution must complete and validate this sprint before Phase 2 or Phase 3 work
begins.

### Task 5.1: Run Smoke Baseline Robustness Validation

- **Location**:
  - generated ignored outputs under `artifacts/models/xgb_test_1/robustness/`
  - `docs/research/ml-validation-hardening-acceptance.md`
- **Description**: Run the robustness validator against current smoke baseline.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Command exits successfully.
  - Report status is PASS or WARN, not FAIL, unless an existing artifact is
    genuinely inconsistent.
  - Acceptance evidence records the smoke-only limitation.
  - Full prediction rows are not pasted into docs or chat.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`
  - `.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py ...`

### Task 5.2: Define Real One-To-Two-Year Run Checklist

- **Location**:
  - `docs/research/ml-validation-hardening-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Add the explicit gate for when a real Strategy Tester run is
  required.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Checklist says a real one-to-two-year run is required before accepting new
    feature sets, thresholds, cross-symbol claims, or dynamic target work.
  - Checklist specifies ML mode should be disabled for raw data generation
    unless the future plan intentionally studies FILTER behavior.
  - Checklist specifies exported run should include enough rows for folds,
    threshold selection, final holdout, and per-segment validation.
  - Checklist references the environment runbook for MT5/Wine paths.
- **Validation**:
  - Manual doc review.

### Task 5.3: Update Workflow Reference If Needed

- **Location**:
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Add a compact note only if the validation hardening flow
  changes how humans should approve future models.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Workflow update remains compact.
  - It does not duplicate the full plan.
  - It states final model approval requires hardened validation.
- **Validation**:
  - Manual doc review.

## Testing Strategy

- Python syntax validation:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`
- Dataset/tooling smoke validation:
  - use current `artifacts/datasets/test_dataset_1/`
  - use current `artifacts/models/xgb_test_1/`
  - use current `artifacts/model_exports/xgb_test_1_export_v1/`
- Robustness command validation:
  - generated reports under ignored `artifacts/`
  - compact evidence summarized under `docs/research/`
- No MetaEditor compile is required because this phase must not touch MQL5.
- No Strategy Tester run is required to implement the tooling, but a future
  one-to-two-year run is required before accepting new feature sets or robust
  production-like thresholds.

## Acceptance Gate

This phase is accepted only when:

- Current smoke baseline can be reproduced by the new robustness tooling.
- Threshold selection is separated from final approval in the accepted workflow.
- Reports include split metadata, threshold source, final holdout status,
  segment metrics, feature concentration warnings, and smoke/research-grade
  status.
- Candidate comparison can compare baseline versus candidate reports and reject
  weak or non-comparable evidence.
- Documentation states that the current one-month dataset is smoke-only.
- Real one-to-two-year Strategy Tester run requirements are documented.
- No MQL5 files or runtime behavior changed.

## Real Run Requirement

Generate a real one-to-two-year Strategy Tester data run after this plan passes
and before any of the following:

- accepting Feature Schema V2 additions
- approving a new threshold as more than research smoke evidence
- comparing symbol-specific versus multi-symbol model claims
- evaluating dynamic `1:n` target policies
- considering any future live rollout plan

Recommended real-run policy:

- run with ML disabled for raw deterministic feature/outcome generation
- keep strategy config stable and documented
- export enough rows for train, early-stopping validation, threshold selection,
  final holdout, folds, and per-segment metrics
- preserve the generated run ID and config ID in acceptance evidence
- do not tune thresholds or features on the final holdout run

## Potential Risks And Gotchas

- The stronger validation policy may make the current model look weaker. This is
  expected and useful because the current one-month dataset is smoke evidence.
- The current `train_model.py` uses holdout for early stopping and threshold
  reporting. The hardened workflow must either isolate final holdout properly or
  mark legacy evidence as smoke/legacy.
- Small selected-trade counts can make high mean R look attractive. Reports
  must show selected rows and segment rows clearly.
- Segment metrics can be noisy on short datasets. The report should warn rather
  than overstate confidence.
- Future schema v2 categorical features can create rare one-hot buckets. The
  feature concentration checks should be ready before those features exist.
- Candidate comparison is only meaningful when datasets, split policies, target
  definitions, and cost assumptions are comparable.

## Rollback Plan

- Leave existing Phase 1-6 ML workflow and model export commands unchanged until
  the hardened workflow is accepted.
- If new validation tooling fails, keep using existing artifacts only for the
  previously accepted Strategy Tester FILTER scope.
- Remove newly added Python validation helpers and docs if they prove
  misleading before adoption.
- Do not alter or regenerate accepted model exports as part of rollback.
- Keep `ML_INFERENCE_DISABLED` as the default EA runtime mode.
