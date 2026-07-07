# Plan: ML Feature Schema V2 Follow-Up

**Generated**: 2026-07-06
**Estimated Complexity**: High
**Roadmap Phase**: Phase 3 follow-up of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, offline ML selection criteria and possible future MQL5
feature-export changes

## Overview

The first schema v2 attempt produced a valid XAUUSD 2025 dataset and trained
multiple research candidates, but it failed the Phase 3 promotion gate:

- `xauusd_2025_schema_v2_xgb_1` selected `414` out-of-fold rows at threshold
  `0.50` with `net_profit_r=9.2688`, but selected `0` final-holdout rows.
- `xauusd_2025_schema_v2_structure_xgb_1` and
  `xauusd_2025_schema_v2_structure_candle_xgb_1` produced no eligible threshold.
- The final holdout therefore has no positive selected trade set, no S1/S2/S3
  selected support, and no basis for runtime export.

This follow-up keeps work inside Phase 3. It diagnoses the score-distribution
failure, hardens threshold and calibration analysis, and only then proposes a
small next feature iteration. It must not start ONNX, multi-symbol research,
dynamic targets, live rollout, or runtime FILTER validation unless a later
Phase 3 candidate passes the research gate.

## Prerequisites

- Completed first-attempt evidence:
  `docs/research/ml-feature-schema-v2-acceptance.md`
- Valid schema v2 dataset:
  `artifacts/datasets/xauusd_2025_schema_v2_dataset_1/`
- First-attempt models and robustness reports:
  - `artifacts/models/xauusd_2025_schema_v2_xgb_1/`
  - `artifacts/models/xauusd_2025_schema_v2_structure_xgb_1/`
  - `artifacts/models/xauusd_2025_schema_v2_structure_candle_xgb_1/`
- Python ML environment from
  `tools/deterministic_signal_ml/requirements.txt`
- MetaEditor and human-in-the-loop Strategy Tester only if this follow-up adds
  new MQL5-exported features.

Generated datasets, model outputs, reports, raw Strategy Tester exports, and
runtime exports remain out of git. Commit only source, plan, and compact
evidence updates.

## Non-Goals

- No runtime export or deployment for the failed first-attempt candidates.
- No ONNX work.
- No multi-symbol research.
- No dynamic target model.
- No live deployment approval.
- No weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.

## Sprint 1: Failure Forensics

**Goal**: Explain why out-of-fold threshold evidence does not generalize to the
final holdout.

**Commit**: `ml: diagnose schema v2 holdout collapse`

**Demo/Validation**:

- Produce compact score-distribution and threshold-stability reports for v1,
  v2 full, v2 structure, and v2 structure+candle.
- Show whether the failure is probability compression, temporal regime drift,
  segment-specific collapse, target-cost asymmetry, or insufficient signal
  separability.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Add Score Distribution Diagnostics

- **Location**:
  - `tools/deterministic_signal_ml/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Add or extend an offline report that summarizes classifier
  score quantiles, selected-row counts, and realized R by chronological split.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Reports include train/fold OOF/threshold-selection/final-holdout score
    quantiles.
  - Reports identify whether final-holdout scores are all below the selected
    threshold.
  - No final-holdout rows are used to pick a threshold.
- **Validation**:
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`
  - Run the diagnostic on all first-attempt models.

### Task 1.2: Add Time-Bucket Stability Diagnostics

- **Location**:
  - `tools/deterministic_signal_ml/`
  - `artifacts/models/*/diagnostics/`
- **Description**: Report monthly or quarterly selected-row counts, win rate,
  mean R, net R, and score quantiles.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Diagnostics show whether the OOF-positive behavior is concentrated in
    specific months.
  - Diagnostics show final-holdout months separately.
  - Evidence records the worst unstable periods without dumping Parquet rows.
- **Validation**:
  - Run against `xauusd_2025_schema_v2_xgb_1` and both ablation variants.

### Task 1.3: Record Root-Cause Summary

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Summarize the failure mode and decide whether the next
  sprint should focus on calibration, threshold policy, or new features.
- **Dependencies**: Tasks 1.1 and 1.2.
- **Acceptance Criteria**:
  - Evidence states the primary failure cause.
  - Evidence states which first-attempt candidates remain rejected.
  - Evidence does not claim runtime readiness.
- **Validation**:
  - Manual evidence review.

## Sprint 2: Threshold And Calibration Hardening

**Goal**: Determine whether schema v2 has a usable ranking signal below the
fixed `>= 0.50` probability threshold without overfitting to final holdout.

**Commit**: `ml: harden threshold calibration diagnostics`

**Demo/Validation**:

- Produce calibrated and rank-based threshold research reports.
- Continue to treat final holdout as approval evidence only.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Evaluate Pre-Final Calibration

- **Location**:
  - `tools/deterministic_signal_ml/`
- **Description**: Add optional pre-final calibration diagnostics using only
  training/OOF or threshold-selection predictions.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Calibration does not fit on final holdout.
  - Report compares raw probability thresholding against calibrated probability
    thresholding.
  - Any calibration candidate must still pass final-holdout support guards.
- **Validation**:
  - Run diagnostics on v2 full and ablation variants.

### Task 2.2: Evaluate Rank/Quantile Policies As Research Only

- **Location**:
  - `tools/deterministic_signal_ml/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Test top-percentile or top-N policies selected only from
  pre-final rows to see whether the model ranks profitable trades even when
  probabilities are compressed.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Report clearly labels rank/quantile policies as research-only unless they
    can be converted into a robust threshold policy.
  - Final-holdout selected rows must meet the same support and profitability
    guards before any runtime work is considered.
- **Validation**:
  - Run against v2 full and the best ablation variant.

### Task 2.3: Decide Whether Existing Dataset Can Continue

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Decide whether calibration/threshold hardening is enough, or
  whether another schema iteration and Strategy Tester export is required.
- **Dependencies**: Tasks 2.1 and 2.2.
- **Acceptance Criteria**:
  - Decision is `CONTINUE_WITH_EXISTING_DATASET` or
    `REQUIRE_SCHEMA_V3_FEATURE_ITERATION`.
  - If existing dataset is insufficient, proposed new features are listed with
    leakage boundaries.
- **Validation**:
  - Manual gate review.

## Sprint 3: Minimal Feature Iteration If Needed

**Goal**: Add only the smallest new feature set needed by the Sprint 1-2
diagnosis, then regenerate data if the feature contract changes.

**Commit**: `feat: iterate deterministic ml feature context`

**Demo/Validation**:

- If no new MQL5 features are needed, skip this sprint and record why.
- If new features are needed, compile the EA, run a fresh human-in-the-loop
  XAUUSD 2025 Strategy Tester export, and build a new dataset.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Define Minimal Next Feature Contract

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Define only features justified by the failure diagnosis,
  such as volatility/range regime, spread/cost context, or coarse session
  context.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Each feature is available before entry.
  - No outcome, future bar, blocked-result, or final-holdout information is
    used.
  - Schema version and Python/MQL5 headers remain aligned.
- **Validation**:
  - Header-count/static contract checks.

### Task 3.2: Implement And Compile If Schema Changes

- **Location**:
  - `services/**/*.mqh`
  - `tools/deterministic_signal_ml/*.py`
  - `logs/compile/`
- **Description**: Implement MQL5/Python schema changes only if Task 3.1
  requires them.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Real MetaEditor compile returns `0 errors, 0 warnings`.
  - Python syntax checks pass.
  - No broker/risk/live execution guard is weakened.
- **Validation**:
  - `python3 tools/mt5/compile_mt5.py --mode compile`
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`

### Task 3.3: Regenerate Dataset If Schema Changes

- **Location**:
  - MT5 Common Files under `DeterministicSignalML/runs/`
  - `artifacts/datasets/`
- **Description**: Run human-in-the-loop Strategy Tester only if schema changed.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - XAUUSD 2025 run uses ML disabled and feature export enabled.
  - Dataset validates with no duplicate IDs or missing joins.
  - Evidence records row counts, config ID, and bounded invalid rows.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --validate-only`
  - Dataset build command.

## Sprint 4: Candidate Retraining And Gate Decision

**Goal**: Retrain the best candidate set from this follow-up and decide whether
Phase 3 can proceed to runtime export or needs another follow-up plan.

**Commit**: `ml: evaluate schema v2 follow-up candidates`

**Demo/Validation**:

- Robust reports exist for all follow-up candidates.
- Evidence states `ACCEPT_FOR_RUNTIME_SPIKE`, `REJECT_WITH_FOLLOW_UP`, or
  `RESEARCH_ONLY_WARN`.

Execution must complete and validate this sprint before any runtime export.

### Task 4.1: Train Follow-Up Candidates

- **Location**:
  - `artifacts/models/`
  - `tools/deterministic_signal_ml/train_model.py`
- **Description**: Train the minimum candidate set required by prior sprints.
- **Dependencies**: Sprint 2 or Sprint 3.
- **Acceptance Criteria**:
  - Model manifests record dataset ID, feature set, schema version, encoded
    feature count, and threshold source.
  - Threshold selection does not use final holdout.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/train_model.py ...`

### Task 4.2: Run Robustness Gate

- **Location**:
  - `artifacts/models/*/robustness/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Apply the same acceptance gate used by the first schema v2
  attempt.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Final holdout has positive selected rows after costs.
  - Selected support guards pass for total rows, S1/S2/S3, bullish/bearish, and
    strategy-direction views.
  - Segment regressions and concentration warnings are resolved or explicitly
    non-blocking.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py ...`

### Task 4.3: Decide Runtime Eligibility

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - optional additional follow-up plan under `docs/plans/`
- **Description**: Decide whether to continue to runtime export/parity or stop.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - If accepted, evidence names the exact model/export candidate for runtime
    spike.
  - If rejected, evidence names the blocking gate failures and creates another
    Phase 3 follow-up plan before further iteration.
  - If research-only, evidence states what support is missing.
- **Validation**:
  - Manual gate review.

## Testing Strategy

- Use Python syntax checks after each tooling sprint.
- Use compact artifact summaries only: row counts, file sizes, final statuses,
  and selected warnings.
- Use real MetaEditor compile only if MQL5 schema code changes.
- Use human-in-the-loop Strategy Tester only if a new raw export is required.
- Do not run runtime SHADOW/FILTER validation unless Sprint 4 accepts a
  candidate for runtime spike.

## Potential Risks And Gotchas

- Final-holdout collapse may be a true absence of signal, not only calibration.
- Rank/quantile policies can overfit easily; they must remain research-only
  unless they generalize with support.
- Adding features without a clear failure diagnosis can increase bucket
  sparsity and worsen overfit.
- A new Strategy Tester export is costly and human-in-the-loop; avoid it unless
  a schema change is justified.

## Rollback Plan

- If tooling changes regress existing reports, revert the affected Python
  commits and keep the first-attempt artifacts as evidence.
- If a new schema iteration fails compile, revert MQL5 schema edits and return
  to the compiled schema v2 baseline.
- If follow-up candidates still fail the acceptance gate, keep runtime export
  disabled and create another Phase 3 follow-up plan before further feature
  work.
