# Plan: ML Target Path Labels Follow-Up

**Generated**: 2026-07-06
**Estimated Complexity**: High
**Roadmap Phase**: Phase 3 follow-up of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, research labels and possible MQL5 statistics-export
changes

## Overview

Schema v2 and schema v3 produced valid XAUUSD 2025 datasets, but neither
produced a final-holdout-positive FILTER candidate. Schema v3 added a small
pre-entry market-context feature set; the best pre-final evidence still selected
zero final-holdout rows.

This follow-up stops feature iteration and threshold tuning until the target
assumption is tested. The current labels come from the existing 1:1 terminal
outcome. A possible 1:2 or 1:3 edge cannot be claimed from 1:1 exits unless the
export records counterfactual path labels, such as whether price would have
reached 2R or 3R before hitting the original stop.

The goal is to export and validate research-only path labels, rebuild the
dataset, and compare reward targets without using final holdout for selection.
Runtime export remains blocked unless a later candidate passes the same robust
gate.

## Prerequisites

- Rejected schema v3 evidence:
  `docs/research/ml-feature-schema-v2-acceptance.md`
- Valid schema v3 dataset:
  `artifacts/datasets/xauusd_2025_schema_v3_dataset_1/`
- Rejected schema v3 models:
  - `artifacts/models/xauusd_2025_schema_v3_xgb_1/`
  - `artifacts/models/xauusd_2025_schema_v3_no_context_xgb_1/`
- MetaEditor compile workflow from
  `docs/environment/mt5-agentic-workflows.md`
- Human-in-the-loop Strategy Tester for any MQL5 export-contract change.

Generated raw exports, datasets, models, diagnostics, and compile logs remain
out of git. Commit only source, plan, and compact evidence.

## Non-Goals

- No runtime export from rejected schema v3 candidates.
- No ONNX work.
- No live deployment approval.
- No multi-symbol claim.
- No increasing tree depth as a first response.
- No per-day/per-session bucket mining without support guards.
- No claim that a 1:1 loser/winner would be profitable at 1:2 or 1:3 without
  counterfactual path evidence.
- No weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.

## Sprint 1: Freeze Schema V3 Rejection

**Goal**: Close the schema v3 feature iteration with compact evidence and define
the target-label question.
**Commit**: `docs: freeze schema v3 ml rejection`
**Demo/Validation**:

- Evidence records the rejected candidates, final-holdout blockers, and no
  runtime eligibility.
- Evidence states why further feature/threshold iteration is not the next step.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Record V3 Gate Summary

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Summarize schema v3 dataset counts, candidate metrics,
  threshold diagnostics, and final-holdout failures.
- **Dependencies**: Existing schema v3 training artifacts.
- **Acceptance Criteria**:
  - V3 full and no-context candidates are explicitly rejected.
  - Final holdout remains approval evidence only.
  - No runtime export is approved.
- **Validation**:
  - Manual evidence review.

### Task 1.2: Define Target-Label Hypothesis

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: State that the next research question is whether alternate
  reward paths such as 1:2 or 1:3 have edge, not whether the current 1:1 target
  can be threshold-tuned.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Evidence rejects unsupported 1:3 claims from 1:1 labels.
  - Evidence lists required path labels before target-model work.
- **Validation**:
  - Manual evidence review.

## Sprint 2: Counterfactual Path Export Contract

**Goal**: Define and implement a research-only outcome contract that can answer
whether alternate R targets were reached before the original stop.
**Commit**: `feat: export deterministic signal path labels`
**Demo/Validation**:

- Feature/schema contract documents the new path-label columns.
- EA compiles with `0 errors, 0 warnings`.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Define Path Label Columns

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Add a separate research outcome extension for path labels,
  such as `hit_1r_before_sl`, `hit_2r_before_sl`, `hit_3r_before_sl`,
  `max_favorable_r`, `max_adverse_r`, `bars_to_1r`, `bars_to_2r`,
  `bars_to_3r`, and `path_horizon_bars`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Labels are computed only from post-entry market path, never from final
    holdout selection.
  - Labels are clearly outcome labels, not model features.
  - The contract distinguishes original terminal outcome from counterfactual
    path outcomes.
- **Validation**:
  - Static header/contract check.

### Task 2.2: Implement Research-Only Path Tracking

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - related lower-level deterministic signal state only if required.
- **Description**: Track each exported deterministic signal after entry long
  enough to determine whether 1R, 2R, or 3R targets would be hit before the
  original SL, or until a bounded horizon expires.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Tracking is statistics-only and cannot change broker admission, order send,
    lot sizing, SL/TP, exits, session gates, spread gates, margin gates,
    protection controls, magic-number scope, or broker reconciliation.
  - Horizon and path state are bounded to avoid unbounded tester memory growth.
  - Original 1:1 outcome export remains available for comparison.
- **Validation**:
  - MetaEditor compile using `tools/mt5/compile_mt5.py --mode compile`.

### Task 2.3: Update Dataset Builder For Target Families

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/report_writer.py`
  - `tools/deterministic_signal_ml/train_model.py`
- **Description**: Build target columns for 1:1, 1:2, and 1:3 research
  families from path labels.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Target family is explicit in dataset/model manifests.
  - Path labels are excluded from model features by default.
  - Dataset reports include support counts for each target family.
- **Validation**:
  - Python syntax checks.
  - Dataset SQL smoke with a tiny fixture.

## Sprint 3: XAUUSD 2025 Path Dataset

**Goal**: Regenerate XAUUSD 2025 with path labels and build the first path-label
dataset.
**Commit**: `data: record xauusd path label dataset evidence`
**Demo/Validation**:

- Fresh human-in-the-loop Strategy Tester export exists.
- Dataset validates and records path-label support counts.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Human Strategy Tester Export

- **Location**:
  - MT5 Common Files under `DeterministicSignalML/runs/`
- **Description**: Run XAUUSD full calendar year 2025 with ML disabled, feature
  export enabled, S1/S2/S3 enabled, and path-label export enabled.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Run uses the same date range and strategy set as schema v3.
  - Export status is `OK`.
  - Generated files remain out of git.
- **Validation**:
  - Validate-only dataset command.

### Task 3.2: Build Path Dataset

- **Location**:
  - `artifacts/datasets/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Build the path-label dataset and record row counts, invalid
  rows, target family support, and quality status.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - No duplicate IDs or missing joins.
  - Blocking null target rows are zero or bounded and explained.
  - 1:2 and 1:3 support counts are large enough to train, or the plan stops.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --validate-only`
  - Dataset build command.

## Sprint 4: Target-Family Training And Gate Decision

**Goal**: Compare 1:1, 1:2, and 1:3 target families with the same temporal gate
and decide whether Phase 3 can proceed or must stop.
**Commit**: `ml: evaluate target path label candidates`
**Demo/Validation**:

- Robust reports exist for each target family candidate.
- Evidence states `ACCEPT_FOR_RUNTIME_SPIKE`, `REJECT_WITH_FOLLOW_UP`, or
  `RESEARCH_ONLY_WARN`.

Execution must complete and validate this sprint before any runtime export.

### Task 4.1: Train Target-Family Candidates

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `artifacts/models/`
- **Description**: Train the minimum candidate set for the target families with
  conservative defaults.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Model manifests record target family, schema version, dataset ID, feature
    set, encoded feature count, and threshold source.
  - Threshold selection uses pre-final rows only.
- **Validation**:
  - Training command for each target family.

### Task 4.2: Run Robustness Gate

- **Location**:
  - `artifacts/models/*/robustness/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Apply the same final-holdout and segment-support gates to
  each target family.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Final holdout has positive selected rows after costs for the selected target
    family.
  - Selected support guards pass for S1/S2/S3, bullish/bearish, and
    strategy-direction views.
  - Rare-bucket and feature-concentration warnings are resolved or explicitly
    non-blocking.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py ...`

### Task 4.3: Decide Runtime Eligibility

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - optional next plan under `docs/plans/`
- **Description**: Decide whether any target-family candidate is eligible for a
  runtime spike.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Accepted candidate names exact dataset/model/target family.
  - Rejected candidates list blocking gate failures.
  - If all target families fail, no further feature iteration starts without a
    new plan.
- **Validation**:
  - Manual gate review.

## Testing Strategy

- Use Python syntax checks after tooling changes.
- Use static header/contract checks after export-contract changes.
- Use MetaEditor compile after MQL5 changes.
- Use human-in-the-loop Strategy Tester only after compile succeeds.
- Use compact evidence only: row counts, schema versions, support counts,
  threshold summaries, final-holdout metrics, and selected warnings.
- Do not paste full TSVs, Parquet contents, compile logs, tree TSVs, or model
  JSON into chat.

## Potential Risks And Gotchas

- A 1:3 target may have too few positive labels to train robustly.
- Path labels can become lookahead leakage if accidentally used as features.
- Continuing virtual path tracking after the original 1:1 close can be expensive
  in Strategy Tester if state is not bounded.
- Session/day buckets can look predictive by chance; they need support guards
  and final-holdout confirmation.
- If target-family candidates still fail, the issue may be signal absence rather
  than feature or reward-shape weakness.

## Rollback Plan

- If path-label MQL5 changes fail compile, revert the export-contract commit and
  keep schema v3 as the latest compiled baseline.
- If dataset build fails, keep generated raw exports out of git and fix only the
  source contract/tooling.
- If all target families fail, keep runtime export disabled and stop Phase 3
  iteration until a new research direction is explicitly planned.
