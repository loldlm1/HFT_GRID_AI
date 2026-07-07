# Plan: ML Pattern Audit Follow-Up

**Generated**: 2026-07-06
**Estimated Complexity**: High
**Roadmap Phase**: Phase 3 follow-up of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: Medium-High, offline research tooling plus optional Strategy
Tester visual/parity overlay

## Overview

Schema v2 and schema v3 produced valid XAUUSD 2025 datasets, but final-holdout
promotion still failed. Before changing the target labels or adding more
features, this follow-up adds a deterministic Pattern Audit layer with DuckDB.

The audit has three goals:

- Confirm that the feature data is semantically clear and not ambiguous.
- Find controlled, human-readable feature combinations with enough support
  across chronological splits.
- Verify selected offline pattern matches in Strategy Tester without changing
  trading behavior.

This plan should run before deeper target-family work in
`docs/plans/ml-target-path-labels-follow-up-plan.md`. If pattern audit finds
feature ambiguity, path-label work should pause until the data contract is
corrected.

## Prerequisites

- Valid schema v3 dataset:
  `artifacts/datasets/xauusd_2025_schema_v3_dataset_1/`
- Rejected schema v3 evidence:
  `docs/research/ml-feature-schema-v2-acceptance.md`
- Python ML environment from
  `tools/deterministic_signal_ml/requirements.txt`
- MetaEditor compile workflow from
  `docs/environment/mt5-agentic-workflows.md`
- Human-in-the-loop Strategy Tester only for the visual/parity playback sprint.

Generated pattern audit reports, match files, tester playback logs, datasets,
models, raw exports, and compile logs remain out of git. Commit only source,
plans, and compact evidence summaries.

## Non-Goals

- No runtime FILTER export from pattern audit results.
- No live deployment approval.
- No ONNX work.
- No target-family training in this plan.
- No manual promotion of a pattern just because it looks good on all of 2025.
- No unrestricted combinatorial mining across every possible feature bucket.
- No per-pattern trading input explosion.
- No changes to broker admission, order send, lot sizing, SL/TP, exits, session
  gates, spread gates, margin gates, protection controls, magic-number scope, or
  broker reconciliation.

## Pattern Audit Contract

The offline audit writes an ignored folder such as:

```text
artifacts/pattern_audits/<audit_id>/
```

Required outputs:

- `pattern_catalog.tsv`: controlled pattern definitions and selection metadata.
- `pattern_summary.tsv`: aggregate metrics by pattern and chronological split.
- `pattern_matches.tsv`: row-level matches used by Strategy Tester playback.
- `pattern_audit_report.md`: compact human-readable report.
- `pattern_audit.json`: machine-readable summary for agentic checks.

`pattern_matches.tsv` must make the tested combination explicit on every row:

```text
audit_id
pattern_id
pattern_label
pattern_source
selected_for_visual
condition_count
conditions_text
signal_id
source_key
source_attempt_index
symbol
strategy_label
direction
entry_time
source_time
terminal_time
target_terminal_reason
target_profit_r
net_profit
split_name
```

`conditions_text` should be readable without opening any model file, for
example:

```text
direction=BEARISH; source_structure_type=HL; opposite_structure_type=LL;
macro_h1_live_dir=-1; high_chain_score_3=-3; sl_fib_band=61.8_100;
entry_fib_band=61.8_100
```

Manual review stays simple. A human can select patterns by editing a small
ignored `pattern_selection.tsv` or by passing repeated `--pattern-id` values to
the audit tool. The EA should not require a long list of pattern inputs; it
should only need an audit set ID and an overlay enable flag.

## Sprint 1: Pattern Audit Contract

**Goal**: Define the controlled pattern lanes, output files, support guards, and
manual selection mechanism before implementation.
**Commit**: `docs: define ml pattern audit contract`
**Demo/Validation**:

- Plan/evidence documents the audit contract.
- Manual and automatic pattern selection are explicitly research-only.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Define Pattern Lanes

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - optional `docs/research/ml-pattern-audit.md`
- **Description**: Define controlled lanes for combinations:
  - direction lane
  - structure lane
  - Fibonacci lane
  - macro slope/alignment lane
  - chain-score lane
  - previous-candle lane
  - optional context/session lane as diagnostic only
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Lanes are human-readable and map directly to existing schema v3 columns.
  - Maximum automatic combination depth is bounded, recommended `2` to `5`
    conditions.
  - Final holdout is not used to choose promoted patterns.
- **Validation**:
  - Manual evidence review.

### Task 1.2: Define Output TSV Schemas

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `tools/deterministic_signal_ml/`
- **Description**: Define `pattern_catalog.tsv`, `pattern_summary.tsv`, and
  `pattern_matches.tsv` schemas.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - `pattern_matches.tsv` includes clear `conditions_text`.
  - Every match row carries `signal_id`, `source_key`, `entry_time`, outcome,
    and split name.
  - The schema supports both auto-selected and manually selected patterns.
- **Validation**:
  - Static schema review.

### Task 1.3: Define Guardrails

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Define statuses such as `AUDIT_PASS`, `REVIEW`,
  `RARE_BUCKET_IGNORE`, `FINAL_HOLDOUT_FAIL`, and `DATA_AMBIGUITY`.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Pattern status depends on support counts and split stability, not only net R.
  - Rare buckets are marked as audit-only.
  - Manual selection cannot imply runtime eligibility.
- **Validation**:
  - Manual evidence review.

## Sprint 2: DuckDB Pattern Audit Tool

**Goal**: Implement a deterministic offline tool that mines controlled patterns
from `training_matrix.parquet` and writes compact audit artifacts.
**Commit**: `ml: add deterministic pattern audit tooling`
**Demo/Validation**:

- The tool runs against `xauusd_2025_schema_v3_dataset_1`.
- Output files are generated under `artifacts/pattern_audits/<audit_id>/`.
- Python syntax checks pass.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Pattern Catalog Builder

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Build a bounded catalog of pattern definitions from schema v3
  columns. Include auto-generated combinations and optional manual
  `--pattern-id` selection.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Automatic combinations are bounded by `--max-condition-count`.
  - Unsupported columns fail fast with a clear error.
  - Manual pattern IDs can be emitted even when they are not top-ranked.
- **Validation**:
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/pattern_audit.py`
  - Run with `--help`.

### Task 2.2: Compute Split-Aware Pattern Metrics

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Use DuckDB to compute row counts, win rate, mean R, net R,
  drawdown-like R, month coverage, S1/S2/S3 support, bullish/bearish support,
  and split-specific metrics.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Metrics are available for pre-final rows and final holdout separately.
  - Pattern ranking uses pre-final evidence only.
  - Final holdout is reported as approval evidence only.
- **Validation**:
  - Run against `xauusd_2025_schema_v3_dataset_1`.
  - Confirm output row counts are plausible and deterministic across repeated
    runs.

### Task 2.3: Write Pattern Match Artifacts

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
  - `artifacts/pattern_audits/<audit_id>/`
- **Description**: Write `pattern_catalog.tsv`, `pattern_summary.tsv`,
  `pattern_matches.tsv`, `pattern_audit_report.md`, and `pattern_audit.json`.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - `pattern_matches.tsv` includes explicit `conditions_text` on each match row.
  - Match rows include identifiers needed for Strategy Tester playback.
  - Generated artifacts are ignored by git.
- **Validation**:
  - TSV header checks.
  - Compact report review.

## Sprint 3: Offline Audit Evidence

**Goal**: Run the audit on the schema v3 dataset and decide which patterns are
worth visual/parity playback in Strategy Tester.
**Commit**: `docs: record schema v3 pattern audit evidence`
**Demo/Validation**:

- Evidence records top supported patterns, rejected rare patterns, and manual
  selections.
- The output names the exact audit ID and selected pattern IDs for playback.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Run Default Pattern Audit

- **Location**:
  - `artifacts/pattern_audits/`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Run the default bounded audit on
  `xauusd_2025_schema_v3_dataset_1`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Report includes total patterns scanned, top pre-final supported patterns,
    final-holdout survival, and rare-bucket counts.
  - Evidence does not claim runtime readiness.
- **Validation**:
  - Manual evidence review.

### Task 3.2: Select Visual Playback Patterns

- **Location**:
  - `artifacts/pattern_audits/<audit_id>/pattern_selection.tsv`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Select a small set of patterns for visual playback. Include
  both statistically interesting auto-selected patterns and optional manual
  `pattern_id` choices.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Selected patterns are capped, recommended `5` to `20`.
  - Each selected pattern has a plain-language reason.
  - Manual choices are clearly marked `manual_review`, not promoted.
- **Validation**:
  - Pattern selection report review.

### Task 3.3: Export Tester Playback Package

- **Location**:
  - MT5 Common Files under `DeterministicSignalML/pattern_audits/<audit_id>/`
- **Description**: Copy or generate the selected `pattern_matches.tsv` package
  for Strategy Tester playback.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Package includes only selected patterns unless explicitly requested.
  - Paths are documented for Windows and Ubuntu/Wine.
  - No generated package is committed.
- **Validation**:
  - File existence and header check.

## Sprint 4: Strategy Tester Pattern Playback

**Goal**: Add research-only Strategy Tester overlay/parity playback for selected
pattern matches.
**Commit**: `feat: add pattern audit tester playback`
**Demo/Validation**:

- EA compiles with `0 errors, 0 warnings`.
- Strategy Tester can draw or log selected pattern hits without changing trade
  behavior.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Add Minimal Playback Inputs

- **Location**:
  - `services/**/*.mqh`
  - `HFT_Grid_AI.mq5` only if inputs live there
- **Description**: Add the smallest input surface, recommended:
  - `Enable_Pattern_Audit_Overlay`
  - `Pattern_Audit_Set_Id`
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - No per-pattern input list is required.
  - Manual pattern selection remains in `pattern_selection.tsv` or the generated
    playback package.
  - Inputs are disabled by default.
- **Validation**:
  - MetaEditor compile.

### Task 4.2: Load Selected Pattern Matches

- **Location**:
  - `services/trading_signals/`
  - `services/frontend/` only if chart objects are owned there
- **Description**: Load selected `pattern_matches.tsv` from Common Files and
  index matches by `signal_id` or by `source_key` plus attempt index.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Loading is Strategy Tester/research-only.
  - Missing file disables overlay with a clear debug message.
  - Load cost is bounded and not repeated every tick.
- **Validation**:
  - MetaEditor compile.
  - Tester startup log review.

### Task 4.3: Record Playback Parity

- **Location**:
  - MT5 Common Files under `DeterministicSignalML/pattern_audits/<audit_id>/`
- **Description**: During Strategy Tester, record observed pattern hits to a
  compact TSV such as `pattern_tester_observations.tsv`.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Observed rows include `pattern_id`, `signal_id`, `source_key`,
    `entry_time`, `expected_match`, and `observation_status`.
  - The EA does not recompute pattern profitability or filter trades.
  - The output supports post-run parity comparison against
    `pattern_matches.tsv`.
- **Validation**:
  - MetaEditor compile.
  - Human-in-the-loop Strategy Tester smoke run.

### Task 4.4: Add Visual Markers

- **Location**:
  - `services/frontend/`
  - chart helper modules if present
- **Description**: Draw simple markers for selected pattern hits in visual mode,
  with tooltip text containing `pattern_id` and `pattern_label`.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Visual markers are debug/research-only and disabled by default.
  - Markers do not affect trading decisions.
  - Marker creation is bounded and cleaned up on deinit.
- **Validation**:
  - MetaEditor compile.
  - Human visual review in Strategy Tester.

## Sprint 5: Playback Parity And Decision

**Goal**: Compare offline pattern matches with Strategy Tester observations and
decide whether data semantics are clear enough to continue to target path
labels.
**Commit**: `docs: record pattern audit tester parity`
**Demo/Validation**:

- Parity report compares expected offline matches vs observed tester hits.
- Evidence states `DATA_CLEAR_CONTINUE_TO_PATH_LABELS`,
  `DATA_AMBIGUITY_FIX_REQUIRED`, or `RESEARCH_ONLY_WARN`.

Execution must complete and validate this sprint before resuming target-family
work.

### Task 5.1: Add Playback Parity Comparator

- **Location**:
  - `tools/deterministic_signal_ml/pattern_playback_compare.py`
- **Description**: Compare `pattern_matches.tsv` against
  `pattern_tester_observations.tsv`.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Report counts expected, observed, missing, extra, and timestamp mismatches.
  - Mismatches include enough identifiers to inspect a chart case.
  - Comparator writes JSON, Markdown, and TSV outputs.
- **Validation**:
  - Python syntax check.
  - Run against the human-in-the-loop tester output.

### Task 5.2: Record Pattern Audit Decision

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Record audit ID, selected patterns, offline metrics, playback
  parity status, and next-step decision.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - If parity is clean, path-label follow-up can continue.
  - If parity fails, the blocking ambiguity is named before more ML work.
  - No pattern is promoted to runtime FILTER.
- **Validation**:
  - Manual evidence review.

## Testing Strategy

- Use Python syntax checks for all new tooling.
- Use deterministic DuckDB queries and stable ordering for repeatable outputs.
- Run the audit twice on the same dataset and verify stable summaries.
- Use MetaEditor compile after MQL5 playback/overlay changes.
- Use human-in-the-loop Strategy Tester only after compile succeeds.
- Use compact summaries only: row counts, selected pattern IDs, split metrics,
  parity counts, and selected warning lines.

## Potential Risks And Gotchas

- Pattern mining can overfit if it scans too many combinations. Keep the catalog
  bounded and rank on pre-final evidence only.
- Manual selection is useful for visual understanding but must not imply runtime
  eligibility.
- Rare patterns may look excellent by chance. Mark them explicitly and avoid
  promotion claims.
- `signal_id` or `source_key` mismatches between offline dataset and Strategy
  Tester playback could reveal a real data-contract issue.
- Visual markers can become noisy. Keep the selected playback set small and
  disabled by default.
- The pattern audit can prove data clarity, but it cannot prove edge unless the
  pattern also survives the same final-holdout and support gates.

## Rollback Plan

- If offline tooling is wrong, revert the pattern audit tooling commit and keep
  generated artifacts out of git.
- If Strategy Tester playback fails compile, revert the playback commit and keep
  offline audit evidence as research-only.
- If parity reveals data ambiguity, stop target-label work until the feature or
  identifier contract is fixed.
- If parity is clean but no patterns have stable support, continue to target
  path labels without promoting any pattern filter.
