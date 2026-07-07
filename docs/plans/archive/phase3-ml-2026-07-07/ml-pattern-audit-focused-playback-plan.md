# Plan: ML Pattern Audit Focused Playback

**Generated**: 2026-07-06
**Estimated Complexity**: Medium-High
**Roadmap Phase**: Phase 3 pattern-audit follow-up
**Risk Level**: Medium-High, Strategy Tester admission behavior when explicitly
enabled

## Overview

The current pattern audit overlay proves offline-to-tester parity, but it still
lets every deterministic entry trade. This follow-up makes the workflow useful
before a long Strategy Tester run by adding human-readable pattern labels,
bounded visual playback, indexed lookup, chart-panel visibility, and an
explicit Strategy Tester-only mode that admits only selected pattern matches.

The filter is not live approval. It only gates deterministic entries in Strategy
Tester after existing broker/risk eligibility passes and before the local
execution leg is activated.

## Prerequisites

- Existing audit: `xauusd_2025_pattern_audit_1`
- Existing schema v3 dataset: `xauusd_2025_schema_v3_dataset_1`
- Common Files pattern package under
  `DeterministicSignalML/pattern_audits/<audit_id>/`
- MetaEditor compile helper from `docs/environment/mt5-agentic-workflows.md`

## Non-Goals

- No live trading approval.
- No ONNX or runtime model export.
- No pattern promotion to production FILTER.
- No weakening of license, session, spread, broker-distance, volume, margin,
  protection, magic-number, or reconciliation controls.
- No unbounded marker creation or per-signal full-array scans.

## Sprint 1: Focused Playback Contract

**Goal**: Document the distinction between overlay and tester-only pattern
admission before changing behavior.
**Commit**: `docs: plan focused pattern playback`
**Demo/Validation**:

- Plan exists under `docs/plans/`.
- Evidence states that selected-pattern admission is Strategy Tester-only and
  opt-in.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Define Modes

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Define overlay/parity mode versus tester-only selected
  pattern admission.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Overlay remains read-only.
  - Pattern admission is disabled by default and blocked outside Strategy
    Tester.
  - Existing broker/risk gates remain earlier in the pipeline.
- **Validation**:
  - Manual evidence review.

## Sprint 2: Human Labels And Focused Package

**Goal**: Make top patterns readable to humans and prepare a smaller focused
playback package before long Strategy Tester runs.
**Commit**: `ml: add human pattern labels`
**Demo/Validation**:

- Pattern audit output includes human-readable labels.
- A focused audit package can be generated and copied to Common Files.

### Task 2.1: Add Human Label Builder

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Convert condition keys into human labels such as
  `Bearish | HH[0] | LL[1] | H1 slope bearish | Entry Fib 61.8-100`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Machine-readable `conditions_text` is preserved.
  - `pattern_label` is human-readable.
  - Enum/key values remain available through `conditions_text`.
- **Validation**:
  - Python syntax check.
  - Smoke audit with a small catalog.

### Task 2.2: Generate Focused Playback Package

- **Location**:
  - `artifacts/pattern_audits/`
  - MT5 Common Files
- **Description**: Generate a focused audit ID with a smaller `--top-n-visual`
  value for Strategy Tester review.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Package has a bounded selected pattern count.
  - Package remains ignored by git.
  - Common Files path is documented.
- **Validation**:
  - Header/count checks.

## Sprint 3: Indexed Playback And Panel Summary

**Goal**: Avoid slow full-array scans and show the selected top patterns in the
chart panel.
**Commit**: `feat: optimize pattern playback overlay`
**Demo/Validation**:

- MQL5 compile passes.
- Pattern lookup avoids scanning every selected match on every signal.
- Panel shows loaded/observed counts and recent selected pattern label.

### Task 3.1: Add Bounded Lookup Index

- **Location**:
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Store matches sorted by `source_key` and
  `source_attempt_index`, then use binary search to find candidates.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Matching is deterministic.
  - No unbounded per-signal full scan.
  - Duplicate pattern IDs for the same key can still be observed.
- **Validation**:
  - MetaEditor compile.

### Task 3.2: Add Panel Rows And Marker Limits

- **Location**:
  - `services/frontend/lightweight_status_ui.mqh`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Surface audit ID, mode, loaded/observed counts, and recent
  human pattern label in the lightweight panel. Limit visual markers.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Panel remains compact.
  - Markers are bounded.
  - Missing package state is visible when enabled.
- **Validation**:
  - MetaEditor compile.

## Sprint 4: Tester-Only Selected Pattern Admission

**Goal**: Add the intended Strategy Tester mode: admit only entries that match
selected pattern matches.
**Commit**: `feat: gate tester entries by selected patterns`
**Demo/Validation**:

- MQL5 compile passes.
- Filter is opt-in and tester-only.
- Blocked entries close the local deterministic signal without creating broker
  exposure.

### Task 4.1: Add Explicit Admission Input

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add a disabled-by-default input for selected-pattern
  admission, separate from overlay.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Overlay can still run without blocking trades.
  - Admission mode cannot affect non-tester runs.
- **Validation**:
  - MetaEditor compile.

### Task 4.2: Gate Deterministic Admission

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: After existing broker/risk admission preparation passes and
  before `ApplyExecutionLegTradeAdmission`, block entries without a selected
  pattern match.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Existing broker/risk gates still run first.
  - Live/non-tester usage fails closed for the pattern filter.
  - Block reason is explicit and auditable.
- **Validation**:
  - MetaEditor compile.

## Sprint 5: Validation And Run Handoff

**Goal**: Record the focused workflow and exact Strategy Tester inputs for the
next long run.
**Commit**: `docs: record focused pattern playback validation`
**Demo/Validation**:

- Evidence names the focused audit ID and Common Files path.
- Compile and Python checks are recorded.
- Long Strategy Tester run remains human-in-the-loop.

### Task 5.1: Record Validation

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Summarize compile, audit generation, selected count, and
  exact inputs for focused pattern-admission tester runs.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - No runtime/live approval is implied.
  - Next command to compare parity is documented.
- **Validation**:
  - `git diff --check`
  - MetaEditor compile summary.

## Testing Strategy

- Python syntax checks for audit tooling.
- Smoke audit with bounded catalog and focused selected count.
- MetaEditor real compile after MQL5 changes.
- Human-in-the-loop Strategy Tester for runtime visual/admission verification.

## Potential Risks And Gotchas

- Selected patterns can still be broad. Use a focused audit ID or manually
  selected pattern IDs before long runs.
- Filtering changes tester trade count, so compare results only against the
  selected pattern subset.
- `signal_id` includes run ID. Playback matching should continue to use
  `source_key` plus `source_attempt_index`.
- Too many chart markers can slow visual tester. Keep marker count bounded.

## Rollback Plan

- Disable `Enable_Pattern_Audit_Overlay` to remove all focused pattern
  playback/filter behavior.
- Revert the focused playback commits if compile or tester behavior is wrong.
