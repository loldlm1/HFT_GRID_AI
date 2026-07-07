# Plan: ML Phase 3 Closeout Reporting

**Generated**: 2026-07-07
**Estimated Complexity**: Medium
**Roadmap Phase**: Phase 3 closeout of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: Medium, research reporting and Strategy Tester playback
metadata. No broker admission, risk, lot sizing, SL/TP, or live runtime behavior
changes are intended.

## Overview

Close Phase 3 after schema v4 selected-pattern parity by making the reporting
contract unambiguous:

- Pattern playback reports must distinguish selected pattern observation rows
  from unique Strategy Tester trade entries.
- Metadata diagnostics such as runtime `signal_id` and entry timestamp
  differences must be explicit and non-blocking when hard identity matches.
- Future playback TSVs should write expected and observed metadata separately
  so `\N` runtime fields do not look like data corruption.
- Current follow-up plans should be archived or superseded so `docs/plans/`
  clearly shows Phase 3 completion and the next phase.

The next roadmap phase will be dynamic TP/path-ratio research plus Strategy
Tester speed optimization, so Phase 3 must end with clean evidence and no
runtime ML FILTER approval implied.

## Prerequisites

- Schema v4 S1/S2/S3 Strategy Tester playback observations already exist under
  MT5 Common Files.
- Existing pattern audits:
  - `xauusd_2025_schema_v4_audit_S1`
  - `xauusd_2025_schema_v4_audit_S2`
  - `xauusd_2025_schema_v4_audit_S3`
- MetaEditor compile workflow from
  `docs/environment/mt5-agentic-workflows.md`.
- Generated Strategy Tester exports, datasets, models, playback files, and
  Common Files packages remain out of git.

## Non-Goals

- No live deployment approval.
- No ML FILTER approval from schema v4 depth-5 research exports.
- No change to trade admission, order send, lot sizing, SL/TP, position
  lifecycle, broker/risk guards, magic-number scope, or broker reconciliation.
- No implementation of dynamic TP/path-ratio labels in this closeout plan.
- No deletion of generated research artifacts from Common Files.

## Sprint 1: Closeout Plan

**Goal**: Freeze the ordered closeout work before code/documentation changes.
**Commit**: `docs: plan phase 3 closeout reporting`
**Demo/Validation**:

- This plan exists under `docs/plans/`.
- Sprint order, validation, commits, and non-goals are explicit.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Write Closeout Plan

- **Location**: `docs/plans/ml-phase3-closeout-reporting-plan.md`
- **Description**: Define the Phase 3 reporting closeout scope.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Plan states that pattern rows and unique trade entries are different
    metrics.
  - Plan states that metadata diagnostics are not hard parity failures when
    hard identity matches.
  - Plan includes roadmap cleanup and next-phase handoff.
- **Validation**:
  - Manual review.
  - `git diff --check`.

## Sprint 2: Playback Report Semantics

**Goal**: Update Python playback comparison reports to show both selected
pattern rows and unique Strategy Tester trade entries.
**Commit**: `ml: clarify pattern playback trade counts`
**Demo/Validation**:

- S1/S2/S3 playback comparisons pass.
- Reports list `pattern_observation_rows`, `unique_trade_entries`,
  duplicate pattern hits, entry-count histograms, and per-direction unique
  entry counts.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Unique-Entry Metrics

- **Location**: `tools/deterministic_signal_ml/pattern_playback_compare.py`
- **Description**: Calculate unique entries from
  `source_key + source_attempt_index` separately from pattern-row parity.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Pattern-row PASS/FAIL behavior remains based on
    `pattern_id + source_key + source_attempt_index`.
  - Reports expose unique expected, observed, matched, missing, and extra
    entries.
  - Reports expose duplicate pattern hits and pattern-count histograms per
    entry.
- **Validation**:
  - Python syntax check.
  - S1/S2/S3 playback comparison commands.

### Task 2.2: Clarify Metadata Diagnostics

- **Location**: `tools/deterministic_signal_ml/pattern_playback_compare.py`
- **Description**: Keep signal ID and entry-time differences diagnostic unless
  explicitly required, and explain the hard identity in JSON/Markdown output.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `entry_time_mismatch_rows` and `signal_id_mismatch_rows` are reported as
    metadata diagnostics.
  - Markdown explains why MT5 trade totals can be lower than pattern rows when
    multiple selected patterns match the same entry.
- **Validation**:
  - S1/S2/S3 playback reports regenerate successfully.

## Sprint 3: Playback TSV Metadata Contract

**Goal**: Make future MQL5 playback observation rows less ambiguous by writing
expected and observed metadata separately.
**Commit**: `feat: clarify pattern playback metadata`
**Demo/Validation**:

- EA compiles with no errors or warnings.
- Python comparison remains backward-compatible with old observation files.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Extend Playback Match Metadata

- **Location**:
  `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Load expected `entry_time` from `pattern_matches.tsv` and
  keep expected `signal_id` separately from runtime observed fields.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Existing selected-pattern admission still matches only source identity.
  - Loaded expected metadata does not affect trading decisions.
- **Validation**:
  - MetaEditor compile.

### Task 3.2: Version Observation Output

- **Location**:
  `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Increment the observation schema and write
  `expected_signal_id`, `observed_signal_id`, `expected_entry_time`, and
  `observed_entry_time` columns.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Future TSV rows no longer overload one `signal_id` and one `entry_time`
    column.
  - Old observation files remain readable by Python tooling.
- **Validation**:
  - MetaEditor compile.

## Sprint 4: Documentation And Roadmap Cleanup

**Goal**: Close Phase 3 in docs, archive superseded follow-up plans, and make
the next phase explicit.
**Commit**: `docs: close phase 3 ml roadmap`
**Demo/Validation**:

- Roadmap marks Phase 3 complete.
- `docs/plans/README.md` shows no stale current follow-up plan.
- Completed/superseded follow-up plans are moved under `docs/plans/archive/`.
- Next phase is dynamic TP/path-ratio labels with Strategy Tester speed
  optimization.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Update Evidence And Workflow

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Replace pattern-row-only parity summaries with pattern row
  plus unique-trade-entry summaries.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - S1/S2/S3 expected unique trade entries match MT5 totals where available.
  - Documentation states that schema v4 research did not approve runtime ML
    FILTER.
- **Validation**:
  - Manual documentation review.

### Task 4.2: Update Roadmap And Plan Index

- **Location**:
  - `docs/plans/ml-robustness-and-signal-selection-roadmap.md`
  - `docs/plans/README.md`
- **Description**: Mark Phase 3 complete and define the next phase as dynamic
  TP/path-ratio research plus Strategy Tester speed optimization.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Phase 3 has a completion summary.
  - Phase 4 is not ONNX anymore; ONNX is deferred.
  - Next-phase plan points to a schema v4 baseline, not stale schema v3 wording.
- **Validation**:
  - Manual documentation review.

### Task 4.3: Archive Superseded Follow-Up Plans

- **Location**:
  - `docs/plans/`
  - `docs/plans/archive/phase3-ml-2026-07-07/`
- **Description**: Move completed or superseded Phase 3 follow-up plans out of
  the active plans directory.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Current active plans are limited to roadmap and the next dynamic TP phase
    plan.
  - Archived plans remain available for history.
- **Validation**:
  - `rtk ls docs/plans`
  - `git diff --check`

## Sprint 5: Final Gate And Repo Cleanliness

**Goal**: Validate the closeout end to end and leave the repository clean.
**Commit**: commit only if Sprint 5 produces source/doc changes.
**Demo/Validation**:

- Python syntax check passes.
- S1/S2/S3 playback comparisons pass.
- MetaEditor compile passes if MQL5 changed.
- `git status --short` is clean after commits.

Execution must complete and validate this sprint before final handoff.

### Task 5.1: Run Validation

- **Location**: repo root.
- **Description**: Run focused Python, playback, docs, and MQL5 compile checks.
- **Dependencies**: Sprints 1-4.
- **Acceptance Criteria**:
  - Validation results are summarized in the final response.
  - Any human-in-the-loop Strategy Tester gap is explicit.
- **Validation**:
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`
  - `pattern_playback_compare.py` for S1/S2/S3.
  - `git diff --check`.
  - `tools/mt5/compile_mt5.py`.

## Testing Strategy

- Keep runtime trading behavior unchanged.
- Use existing S1/S2/S3 playback observations for report validation.
- Keep MQL5 validation at compile level for the TSV schema change; the new TSV
  columns need the next human Strategy Tester run to produce fresh rows.
- Do not paste full TSVs, query logs, compile logs, Parquet, model JSON, or tree
  TSV files into chat.

## Potential Risks And Gotchas

- Old observation TSVs have the schema v1 header, so Python must remain
  backward-compatible.
- Multiple selected patterns can match the same source entry; this is expected
  and should not be counted as extra MT5 trades.
- Runtime `signal_id` is often `\N` when feature export is disabled; it is
  useful metadata, not the admission identity.
- Entry timestamps can differ by representation or runtime event time; source
  identity remains the hard parity key.
- Dynamic TP/path-ratio labels can be expensive if implemented with unbounded
  path tracking; the next phase must include Strategy Tester performance
  controls from the start.

## Rollback Plan

- Revert the report/tooling commit if playback comparison semantics regress.
- Revert the MQL5 metadata commit if compile fails or future Strategy Tester
  output is not readable.
- Restore archived plan files from git history if a historical plan needs to be
  reopened.
