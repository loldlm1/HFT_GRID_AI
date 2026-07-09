# Plan: ML Dynamic TP Path Ratio

**Generated**: 2026-07-07
**Status**: COMPLETED_AND_ARCHIVED on 2026-07-09
**Estimated Complexity**: High
**Roadmap Phase**: Phase 4 of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, research labels, Strategy Tester performance, and future
execution-policy implications. This phase is research-only unless a later plan
explicitly approves runtime TP changes.

## Overview

Phase 3 proved that schema v4 selected-pattern data can be reproduced in
Strategy Tester, but no XGBoost threshold is approved for runtime FILTER. The
next question is not another fixed-TP long run for every `1:n` hypothesis. The
next question is whether one bounded, path-aware export can tell us which
reward ratios were realistically reached before the original stop.

This phase adds dynamic TP/path-ratio research labels:

- record post-entry path behavior once per admitted deterministic entry
- derive target-family labels such as `hit_1r_before_sl`,
  `hit_1_5r_before_sl`, `hit_2r_before_sl`, and `hit_3r_before_sl`
- export `max_favorable_r`, `max_adverse_r`, and bars-to-target diagnostics
- train/evaluate target-family candidates without using path labels as model
  features
- optimize Strategy Tester performance so full-year runs remain practical

The output is a research decision: which ratios, if any, are promising enough
for a later runtime execution plan.

## Prerequisites

- Phase 3 schema v4 closeout is complete.
- Current accepted workflow reference:
  `docs/workflows/deterministic-signal-ml-inference-flows.md`.
- Current evidence reference:
  `docs/research/ml-feature-schema-v2-acceptance.md`.
- Existing Strategy Tester selected-pattern parity proves that source identity
  can match between DuckDB and MT5.
- MetaEditor compile workflow from
  `docs/environment/mt5-agentic-workflows.md`.
- Human-in-the-loop Strategy Tester remains required for fresh path-aware
  exports.

Generated raw exports, datasets, models, reports, playback files, and Common
Files packages remain out of git.

## Non-Goals

- No live deployment approval.
- No runtime TP modification in this phase.
- No ML FILTER approval from schema v4 depth-5 candidates.
- No ONNX work.
- No multi-symbol claim.
- No target-family threshold selection from final holdout.
- No path-label columns may be used as model features.
- No weakening of license, session, spread, stops/freeze, margin, protection,
  market-status, magic-number, or broker reconciliation guards.

## Sprint 1: Path-Ratio Contract

**Goal**: Define the research label contract and tester performance constraints
before code changes.
**Commit**: `docs: define dynamic tp path ratio contract`
**Demo/Validation**:

- Evidence lists all new outcome-only path labels.
- Performance constraints are explicit.
- No MQL5 behavior changes.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Define Outcome Labels

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Add a path-ratio outcome extension separate from schema v4
  pre-entry model features.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Labels include `hit_1r_before_sl`, `hit_1_5r_before_sl`,
    `hit_2r_before_sl`, `hit_3r_before_sl`, `max_favorable_r`,
    `max_adverse_r`, bars-to-target fields, `path_horizon_bars`, and
    `path_status`.
  - Labels are outcome columns only and excluded from model features.
  - Documentation states how original 1:1 outcome remains comparable.
- **Validation**:
  - Manual contract review.

### Task 1.2: Define Tester Performance Budget

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Set constraints for bounded path tracking and fast test
  modes.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Path tracking has a maximum horizon.
  - In-memory path state is bounded and pruned.
  - File logging and chart overlays remain optional and off for bulk export.
  - No per-tick full-history scans are allowed.
- **Validation**:
  - Manual review against MQL5 performance rules.

## Sprint 2: MQL5 Path Export

**Goal**: Add research-only bounded path tracking for admitted deterministic
entries.
**Commit**: `feat: export deterministic path ratio labels`
**Demo/Validation**:

- MetaEditor compile passes with no errors or warnings.
- A short Strategy Tester smoke run writes path-label columns.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Bounded Path State

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - related deterministic signal state only if required
- **Description**: Track post-entry price path for exported deterministic
  entries until SL, target hits, or horizon expiry.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - State is keyed by deterministic signal/source identity.
  - Tracking cannot open, close, resize, or modify broker positions.
  - Closed/expired entries are pruned immediately.
  - State growth is bounded in Strategy Tester.
- **Validation**:
  - MetaEditor compile.

### Task 2.2: Export Path Labels

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Write path-ratio outcome columns to the deterministic
  statistics export.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Labels are emitted only after path status is final or horizon-expired.
  - Labels use R multiples from the original entry and original SL distance.
  - Missing/invalid paths are explicit and countable.
- **Validation**:
  - Short Strategy Tester smoke export.

## Sprint 3: Dataset Target Families

**Goal**: Build datasets that derive multiple reward-ratio targets from one
path-aware run.
**Commit**: `ml: build path ratio target datasets`
**Demo/Validation**:

- Dataset builder validates path-label columns.
- Dataset reports support counts for each ratio family.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Extend Dataset Builder

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Add explicit target-family selection for `1r`, `1_5r`,
  `2r`, `3r`, and expected-R research.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Target family is stored in dataset manifests.
  - Path labels are excluded from feature matrices.
  - Support counts and invalid-path counts are reported.
- **Validation**:
  - Python syntax checks.
  - Small fixture or validate-only dataset smoke.

### Task 3.2: Generate XAUUSD Path Dataset

- **Location**:
  - MT5 Common Files generated run folder
  - `artifacts/datasets/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Use one fresh XAUUSD 2025 path-aware Strategy Tester run to
  build target-family datasets.
- **Dependencies**: Task 3.1 and human Strategy Tester run.
- **Acceptance Criteria**:
  - Dataset row counts match exported admitted entries.
  - Target families have enough support or are explicitly rejected.
  - Generated artifacts remain out of git.
- **Validation**:
  - Dataset validation command.

## Sprint 4: Target-Family Training Gate

**Goal**: Evaluate whether any dynamic TP/path-ratio target family has robust
out-of-sample edge.
**Commit**: `ml: evaluate dynamic tp path ratios`
**Demo/Validation**:

- Robustness reports exist for accepted target families.
- Evidence states accept/reject decisions clearly.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Train Ratio Candidates

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/validate_model_robustness.py`
- **Description**: Train conservative XGBoost candidates for each supported
  target family using schema v4 pre-entry features only.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Threshold selection excludes final holdout.
  - Reports include fold/holdout metrics by strategy and direction.
  - Small selected-trade counts reject the candidate.
- **Validation**:
  - Training and robustness commands.

### Task 4.2: Decide Research Outcome

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - optional next runtime plan under `docs/plans/`
- **Description**: Decide whether a ratio family is promising enough for a
  later runtime execution phase.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Accepted ratio, dataset, model, and threshold source are exact.
  - Rejected ratios list blocking evidence.
  - Runtime TP changes remain blocked unless a new execution plan is created.
- **Validation**:
  - Manual gate review.

## Sprint 5: Strategy Tester Speed Optimization

**Goal**: Reduce full-year research run time if path-aware runs become too slow.
**Commit**: `perf: optimize deterministic research exports`
**Demo/Validation**:

- Short and full-year research runs do not slow down progressively from
  unbounded memory, logging, or chart object growth.
- Any optimization keeps exported labels equivalent.

Execution must complete and validate this sprint before final phase closeout.

### Task 5.1: Profile Research Hot Paths

- **Location**:
  - MQL5 export/path tracking modules
  - Common Files generated debug summaries
- **Description**: Identify whether slowdown comes from arrays, file writes,
  chart objects, logs, indicator calls, or path-state pruning.
- **Dependencies**: Sprint 2 or Sprint 3 evidence.
- **Acceptance Criteria**:
  - Profile summary names the dominant bottleneck.
  - No optimization is applied without preserving exported label counts.
- **Validation**:
  - Short controlled Strategy Tester timing comparison.

### Task 5.2: Apply Bounded Optimizations

- **Location**:
  - MQL5 path export modules
  - Python tooling only if report generation is the bottleneck
- **Description**: Apply minimal changes such as batched writes, bounded
  reserves, disabled chart labels, pruned path state, or reduced debug output.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - MetaEditor compile passes.
  - Short run label parity is unchanged.
  - Full-year run is practical enough for human-in-the-loop workflow.
- **Validation**:
  - MetaEditor compile.
  - Strategy Tester timing smoke.

## Testing Strategy

- Validate docs/contracts before MQL5 changes.
- Compile after MQL5 changes.
- Use short Strategy Tester smoke before any full-year run.
- Build one path-aware full-year dataset, then derive ratio targets in Python.
- Compare target families with the same chronological split policy and final
  holdout discipline used by Phase 3.

## Potential Risks And Gotchas

- Path labels can leak future information if accidentally included as features.
- A 3R target may be too rare for robust training.
- Continuing path tracking after the original 1:1 close can be expensive unless
  horizon and pruning are strict.
- A promising ratio in one year of XAUUSD does not prove multi-symbol or live
  validity.
- Speed optimizations must preserve label counts and not change broker
  admission.

## Rollback Plan

- If MQL5 path tracking fails compile or slows Strategy Tester severely, revert
  the export commit and keep Phase 3 schema v4 as the accepted research
  baseline.
- If target-family datasets fail validation, keep generated exports out of git
  and fix only the dataset/tooling contract.
- If all ratio targets fail the robustness gate, keep runtime TP behavior
  unchanged and plan a new research direction before further model work.
