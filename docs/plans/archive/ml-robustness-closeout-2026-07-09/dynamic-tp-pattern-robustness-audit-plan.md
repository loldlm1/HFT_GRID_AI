# Plan: Dynamic TP Pattern Robustness Audit

**Generated**: 2026-07-08
**Status**: COMPLETED_AND_ARCHIVED on 2026-07-09
**Estimated Complexity**: Medium
**Roadmap Phase**: Phase 4 follow-up for
`docs/plans/ml-dynamic-tp-path-ratio-plan.md`
**Risk Level**: Low to medium. This is offline research tooling only. It must
not change EA runtime entries, exits, TP, SL, lot sizing, broker/risk guards, or
Pattern Audit playback behavior.

## Overview

The S1 dynamic TP path run proved that DuckDB can find positive-looking
patterns even when XGBoost rejects all thresholds. Those patterns are still
review-only because the current Pattern Audit validates only one chronological
`pre_final`/`final_holdout` split. This follow-up adds calendar-period
robustness diagnostics so a pattern must show stability across months and
quarters before it can be treated as a serious Strategy Tester candidate.

The output is an offline report layer:

- monthly and quarterly pattern metrics
- positive/negative period counts
- worst-period diagnostics
- a stricter robustness status separate from the existing playback status
- regenerated S1 evidence for `2r`, `3r`, and `expected_r`

## Prerequisites

- Existing path-aware S1 datasets under `artifacts/datasets/`.
- Existing Pattern Audit CLI:
  `tools/deterministic_signal_ml/pattern_audit.py`.
- Existing generated artifacts remain ignored under `artifacts/`.
- Human Strategy Tester playback is optional after this follow-up; it is not
  required to validate the offline report changes.

## Non-Goals

- No MQL5 EA behavior changes.
- No new Strategy Tester input.
- No runtime ML FILTER approval.
- No dynamic TP execution policy approval.
- No claim that S1 patterns are robust unless they pass the new period rules.

## Sprint 1: Robustness Contract

**Goal**: Define the robustness audit scope and decision language before code
changes.
**Commit**: `docs: plan pattern robustness audit`
**Demo/Validation**:

- Plan exists under `docs/plans/`.
- Acceptance criteria explicitly separate review-only patterns from robust
  patterns.
- No code behavior changes.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Save Follow-Up Plan

- **Location**:
  - `docs/plans/dynamic-tp-pattern-robustness-audit-plan.md`
- **Description**: Document the four-sprint implementation and validation
  workflow.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Plan lists four ordered sprints.
  - Plan states offline-only scope and non-goals.
  - Plan includes validation and commit discipline.
- **Validation**:
  - Manual review.
  - `git diff --check`.

## Sprint 2: Period Metrics Output

**Goal**: Add machine-readable monthly and quarterly metrics for every catalog
pattern.
**Commit**: `ml: add pattern period metrics`
**Demo/Validation**:

- Pattern Audit writes `pattern_period_metrics.tsv`.
- Rows include `period_type`, `period_id`, row count, win rate, mean R, net R,
  and max drawdown-like R.
- Existing `pattern_matches.tsv` and playback contract remain unchanged.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Calendar Buckets

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Add `entry_quarter` to the DuckDB audit table alongside the
  existing `entry_month`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Audit rows expose stable month and quarter labels.
  - Ordering remains chronological by `entry_time, signal_id`.
- **Validation**:
  - Python syntax check.
  - Existing Pattern Audit smoke.

### Task 2.2: Write Period Metrics TSV

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Export one row per pattern/month and pattern/quarter.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Output file is `pattern_period_metrics.tsv`.
  - File includes selected and non-selected catalog patterns.
  - Metrics use only rows matching the pattern.
- **Validation**:
  - Regenerate one S1 audit and inspect row counts.

## Sprint 3: Robustness Decision Rules

**Goal**: Add stricter, explainable robustness status without changing Pattern
Audit playback semantics.
**Commit**: `ml: score pattern period robustness`
**Demo/Validation**:

- `pattern_summary.tsv` includes period stability fields.
- `pattern_audit_report.md` shows the new status for selected patterns.
- `pattern_audit.json` summarizes robustness status counts.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Add Robustness Fields

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Add positive/negative month/quarter counts, worst month and
  quarter net R, and `robustness_status`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Summary rows include machine-readable period diagnostics.
  - Existing status values remain backward compatible.
  - Playback still loads selected rows from `pattern_matches.tsv`.
- **Validation**:
  - Python syntax check.
  - Pattern Audit smoke.

### Task 3.2: Apply Conservative Rules

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Mark patterns as `ROBUST_PASS`, `ROBUST_REVIEW`, or
  `ROBUST_FAIL` based on pre-final, final holdout, month, and quarter
  diagnostics.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - A pattern cannot pass if final holdout is non-positive.
  - A pattern cannot pass if it has too little month or quarter coverage.
  - Worst-period failures are explicit in warning codes.
- **Validation**:
  - Regenerate S1 audits and compare selected pattern classifications.

## Sprint 4: S1 Regeneration And Evidence

**Goal**: Re-run S1 pattern audits with the robustness layer and record the
result.
**Commit**: `docs: record pattern robustness evidence`
**Demo/Validation**:

- S1 `2r`, `3r`, and `expected_r` audits regenerate successfully.
- Evidence document lists whether prior positive patterns survive.
- Generated artifacts remain out of git.

Execution must complete and validate this sprint before final closeout.

### Task 4.1: Regenerate Dynamic TP S1 Audits

- **Location**:
  - `artifacts/pattern_audits/` generated outputs
- **Description**: Re-run Pattern Audit for `2r`, `3r`, and `expected_r`.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - New TSV files include period metrics and robustness fields.
  - No generated artifacts are committed.
- **Validation**:
  - CLI exits successfully.
  - Summary script confirms robustness status counts.

### Task 4.2: Record Evidence

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Document S1 robustness results and next recommended runs.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Evidence states whether patterns are robust or still review-only.
  - Follow-up recommendation for S2/S3 remains explicit.
- **Validation**:
  - `git diff --check`.

## Testing Strategy

- Run Python syntax checks after code changes.
- Regenerate Pattern Audit on existing S1 datasets.
- Inspect `pattern_summary.tsv`, `pattern_period_metrics.tsv`,
  `pattern_audit_report.md`, and `pattern_audit.json`.
- Confirm `pattern_matches.tsv` columns stay compatible with EA playback.

## Potential Risks And Gotchas

- Calendar windows can be sparse. The robustness status must report sparse
  support instead of pretending the signal is stable.
- Stronger rules may downgrade every S1 pattern. That is acceptable and safer
  than approving a narrow artifact.
- Generated artifacts under `artifacts/` must remain ignored.
- Because this is offline-only, MetaEditor compile is not required unless MQL5
  files are unexpectedly changed.

## Rollback Plan

- Revert the Pattern Audit Python changes if generated reports become invalid.
- Keep existing S1 datasets and raw Common Files run untouched.
- If all S1 patterns fail robustness, proceed with S2/S3 data collection rather
  than loosening the rules.
