# Plan: ML Pattern Audit Strategy Scoped Filter

**Generated**: 2026-07-06
**Estimated Complexity**: Medium-High
**Roadmap Phase**: Phase 3 pattern-audit follow-up
**Risk Level**: Medium-High, Strategy Tester admission behavior

## Overview

Focused pattern playback exposed three issues before a long Strategy Tester run:
chart text labels are noisy, the panel needs clearer human labels, pattern
statistics are still too global across S1/S2/S3, and combined strategy runs can
open several positions from the same structural source.

This follow-up makes `Enable_Pattern_Audit_Overlay=true` the single
Strategy Tester selected-pattern filter switch, removes the redundant
`Pattern_Audit_Admit_Selected_Only` input, scopes pattern mining by
`strategy_label`, and blocks duplicate selected entries from the same source
family during pattern-filtered tester runs.

## Prerequisites

- Existing schema v3 tooling.
- Existing focused pattern audit implementation.
- MetaEditor compile helper from `docs/environment/mt5-agentic-workflows.md`.
- Fresh Strategy Tester data remains human-in-the-loop after this code
  follow-up.

## Non-Goals

- No live deployment approval.
- No runtime ML FILTER approval.
- No ONNX work.
- No hidden fallback to global S1/S2/S3 pattern statistics.
- No weakening of license, session, spread, broker-distance, volume, margin,
  protection, magic-number, or broker reconciliation controls.

## Sprint 1: Contract And Run Policy

**Goal**: Record the new semantics and fresh-run order before code changes.
**Commit**: `docs: plan strategy scoped pattern filter`
**Demo/Validation**:

- Plan exists under `docs/plans/`.
- Evidence states that fresh Strategy Tester data should be generated per
  strategy before long combined runs.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Define Filter Semantics

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Define `Enable_Pattern_Audit_Overlay=true` as the single
  Strategy Tester selected-pattern filter and panel switch.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Redundant input is marked for removal.
  - Outside Strategy Tester, the pattern filter has no live trading effect.
  - Fresh data run order is documented.
- **Validation**:
  - Manual evidence review.

## Sprint 2: Strategy-Scoped Pattern Audit

**Goal**: Make offline pattern mining strategy-scoped so S1/S2/S3 are not mixed
as one statistical sample.
**Commit**: `ml: scope pattern audit by strategy`
**Demo/Validation**:

- Pattern definitions include `strategy_label`.
- Optional `--strategy-label` can generate S1-only, S2-only, or S3-only audits.
- Python syntax check and smoke audit pass.

### Task 2.1: Add Strategy Scope To Templates

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Prefix automatic pattern templates with `strategy_label`
  without counting it against feature depth.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - `conditions_text` includes `strategy_label=S1/S2/S3`.
  - Human labels start with strategy label.
  - Pattern IDs differ by strategy.
- **Validation**:
  - Python syntax check.
  - Smoke audit.

### Task 2.2: Add Optional Strategy Filter

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Add `--strategy-label` filter for per-strategy audits.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Repeated `--strategy-label` values are supported.
  - Filtered audit rows are split chronologically after filtering.
- **Validation**:
  - S1 smoke audit.

## Sprint 3: Single Switch And Panel-Only Display

**Goal**: Remove redundant input and chart text labels; make panel output
clearer.
**Commit**: `feat: simplify pattern audit filter UI`
**Demo/Validation**:

- MQL5 compiles.
- Pattern text is shown in panel only.
- `Enable_Pattern_Audit_Overlay=true` is the only pattern filter switch.

### Task 3.1: Remove Redundant Input

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Remove `Pattern_Audit_Admit_Selected_Only` and make
  `Enable_Pattern_Audit_Overlay=true` imply tester selected-pattern admission.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Outside Strategy Tester, the filter has no live trading effect.
  - Missing audit packages block tester entries only when overlay is enabled.
- **Validation**:
  - MetaEditor compile.

### Task 3.2: Panel Only

- **Location**:
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
  - `services/frontend/lightweight_status_ui.mqh`
- **Description**: Remove pattern `OBJ_TEXT` chart labels and split last pattern
  into short panel rows.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - No pattern audit text labels are drawn on chart.
  - Panel shows strategy/direction and setup details in readable rows.
- **Validation**:
  - MetaEditor compile.

## Sprint 4: Source Family Duplicate Guard

**Goal**: In pattern-filtered tester runs, admit at most one selected entry from
the same structural source family across S1/S2/S3.
**Commit**: `feat: block duplicate pattern source entries`
**Demo/Validation**:

- MQL5 compiles.
- Duplicate source family entries are blocked with explicit reason.

### Task 4.1: Add Source Family Key

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Define source-family identity without `strategy_label` and
  expose it in offline pattern matches.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Family key preserves direction, source slot/type, source time, and source
    price.
  - Strategy label remains available separately.
- **Validation**:
  - Python syntax check.
  - MetaEditor compile.

### Task 4.2: Block Duplicate Families

- **Location**:
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Track admitted source family keys and block later selected
  entries from the same family during pattern-filtered tester runs.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - First admitted selected entry from a family can trade.
  - Later S1/S2/S3 entries from the same family are locally blocked.
  - Block reason is auditable.
- **Validation**:
  - MetaEditor compile.

## Sprint 5: Fresh Run Handoff

**Goal**: Record final validation and the fresh Strategy Tester sequence.
**Commit**: `docs: record strategy scoped pattern runbook`
**Demo/Validation**:

- Evidence includes cleanup steps and ordered Strategy Tester run sequence.
- Compile and smoke checks are recorded.

### Task 5.1: Record Runbook

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Document fresh-data cleanup, then S1-only, S2-only, S3-only,
  per-strategy audits, and only then a combined run if needed.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Commands/inputs are explicit.
  - Generated artifacts stay out of git.
  - No live approval is implied.
- **Validation**:
  - `git diff --check`
  - MetaEditor compile.

## Testing Strategy

- Python syntax checks for audit tooling.
- Smoke audits for strategy-scoped patterns.
- MetaEditor real compile after MQL5 changes.
- Human-in-the-loop Strategy Tester remains required for runtime behavior.

## Potential Risks And Gotchas

- Fresh per-strategy data is required. Reusing mixed S1/S2/S3 data can keep the
  original statistical ambiguity.
- Blocking duplicate source families changes combined tester trade count. This
  is intended only for pattern-filtered tester validation.
- The first admitted strategy wins unless a later sprint adds explicit
  S1/S2/S3 priority selection.
- `source_family_key` uses source time/price; if source construction changes,
  both offline and MQL5 keys must stay aligned.

## Rollback Plan

- Disable `Enable_Pattern_Audit_Overlay` to return to normal deterministic
  strategy behavior.
- Revert these commits if compile or tester behavior is wrong.
