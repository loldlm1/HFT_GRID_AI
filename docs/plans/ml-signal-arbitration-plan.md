# Plan: ML Signal Arbitration

**Generated**: 2026-07-05
**Estimated Complexity**: High
**Roadmap Phase**: Phase 2 of `docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, Strategy Tester execution behavior immediately before broker send

## Overview

Add deterministic ML signal arbitration for `ML_INFERENCE_FILTER` in Strategy
Tester. The goal is to prevent enabled deterministic strategies such as S1, S2,
and S3 from opening multiple broker positions when they converge on the same
symbol, direction, source extremum, and activation moment.

This phase must preserve the existing broker and risk gate order. Arbitration
must run only after a candidate has passed deterministic entry confirmation,
broker/risk admission preparation, and ML classifier filtering. It must select
one candidate per arbitration group, block non-selected candidates with the
distinct terminal reason `ML_ARBITRATION_BLOCKED`, and record the decisions
separately from `ML_FILTER_BLOCKED`.

The old run data that existed before this phase is not required. Fresh Strategy
Tester smoke evidence must be generated after implementation because old
artifacts cannot contain arbitration group or block evidence.

## Accepted Decisions

- Scope is Strategy Tester `ML_INFERENCE_FILTER` only.
- `ML_INFERENCE_SHADOW` remains observational and must not change broker
  admission.
- Candidate group identity uses symbol, direction, source extremum identity,
  and same activation moment.
- Arbitration runs after existing broker/risk eligibility and after ML FILTER
  allows a candidate.
- Ranking policy:
  1. highest classifier score
  2. highest regressor score
  3. stable strategy priority `S1 > S2 > S3`
- Single-candidate groups pass without being blocked, but summary counters
  should still make single versus multi-candidate groups visible.
- Arbitration decisions are written to a new artifact file instead of
  overloading prediction rows.
- Non-selected candidates close locally with terminal reason
  `ML_ARBITRATION_BLOCKED`, no broker exposure, and no broker-confirmed outcome.
- `Signal_Concurrency_Mode` semantics are not changed in this phase.
- Initial validation uses a short XAUUSD Strategy Tester smoke run. A long
  XAUUSD run is generated only after Phase 2 behavior passes smoke validation.

## Prerequisites

- Phase 1 validation hardening is complete:
  `docs/plans/ml-validation-hardening-plan.md`.
- Active workflow reference exists:
  `docs/workflows/deterministic-signal-ml-inference-flows.md`.
- Current model export `xgb_test_1_export_v1` is available or can be regenerated
  and copied to MT5 Common Files before Strategy Tester smoke validation.
- Python virtual environment dependencies from
  `tools/deterministic_signal_ml/requirements.txt` are installed.
- No old run folder is required; Phase 2 must generate fresh smoke evidence.
- No live deployment approval is implied by this phase.

## Scope

- Add MQL5 arbitration state, grouping, selection, blocking, and telemetry for
  deterministic ML FILTER candidates.
- Add an arbitration artifact file under the existing
  `DeterministicSignalML\shadow_runs\<shadow_run_id>\` folder.
- Extend summary counters and Python summary validation to distinguish
  classifier filter blocks from arbitration blocks.
- Update compact docs and acceptance evidence.

## Non-Goals

- No live trading approval.
- No ONNX work.
- No Feature Schema V2 work.
- No dynamic `1:n` target modeling.
- No change to `ML_INFERENCE_SHADOW` trading behavior.
- No ML mode may create trades, resize lots, alter SL/TP, or bypass
  license/session/spread/stops/freeze/margin/protection/magic-number/broker
  reconciliation guards.
- No broad rewrite of deterministic signal detection.
- No multi-symbol research validation in this phase.

## Sprint 1: Arbitration Contract And Telemetry Schema

**Goal**: Define the behavior contract, group identity, rank policy, terminal
reasons, and artifact schema before runtime behavior changes.

**Commit**: `docs: define ml signal arbitration contract`

**Demo/Validation**:

- Review docs and planned artifact fields.
- Confirm no MQL5 behavior changed.
- Confirm old run data is not a prerequisite.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Document Arbitration Contract

- **Location**:
  - `docs/research/ml-signal-arbitration-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Create a compact acceptance/evidence document describing
  the accepted decisions, group identity, rank order, block reason, and
  tester-only scope.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Contract states arbitration is `ML_INFERENCE_FILTER` and Strategy Tester
    only.
  - Contract states `ML_INFERENCE_SHADOW` remains observational.
  - Contract states the rank policy is classifier score, regressor score, then
    `S1 > S2 > S3`.
  - Contract states old run data is not required and fresh smoke evidence must
    be generated after implementation.
- **Validation**:
  - Manual doc review.

### Task 1.2: Define Arbitration Artifact Schema

- **Location**:
  - `docs/research/ml-signal-arbitration-acceptance.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Define a new TSV artifact, recommended name
  `arbitration_decisions.tsv`, written under the existing shadow/filter run
  folder.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Schema includes group ID, signal ID, source key, source attempt index,
    symbol, strategy ID/label, direction, source type, source extremum identity,
    activation time, classifier score, regressor score, threshold,
    rank position, arbitration action, arbitration reason, and selected signal
    ID.
  - Schema can distinguish `SELECTED`, `BLOCKED`, and optional `OBSERVED`
    records without changing broker behavior in SHADOW.
  - Schema does not duplicate full prediction or outcome rows.
- **Validation**:
  - Manual schema review against existing `shadow_predictions.tsv` columns.

### Task 1.3: Define Summary Counters

- **Location**:
  - `docs/research/ml-signal-arbitration-acceptance.md`
  - `tools/deterministic_signal_ml/summarize_filter_run.py`
- **Description**: Specify counters that future tooling must validate.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Planned counters include total arbitration groups, single-candidate groups,
    multi-candidate groups, selected candidates, arbitration-blocked candidates,
    and tie-breaker usage.
  - Summary distinguishes `ML_FILTER_BLOCKED` from `ML_ARBITRATION_BLOCKED`.
  - Backward compatibility for old filter runs is documented.
- **Validation**:
  - Manual review.

## Sprint 2: MQL5 Candidate Grouping Foundation

**Goal**: Add local MQL5 structures and helper functions that can group and
rank candidates without sending or blocking trades yet.

**Commit**: `feat: add ml arbitration candidate grouping`

**Demo/Validation**:

- Run focused static review of new helper boundaries.
- Confirm include order still follows `services/trading_signals.mqh`.
- Confirm no broker send behavior is wired in this sprint.

Execution must complete and validate this sprint before moving to Sprint 3.

### Task 2.1: Add Arbitration Types And Group ID Builder

- **Location**:
  - new `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
  - `services/trading_signals.mqh`
- **Description**: Add structs for arbitration candidate, group summary, and
  decision rows. Add a deterministic group ID builder based on symbol,
  direction, source extremum slot/time/type/price, and activation moment.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Helpers use existing `SignalParams`, `ExecutionLegState`, and ML score
    fields.
  - Group IDs are stable and safe for TSV/debug output.
  - Source price comparisons use broker point tolerance where needed.
  - No broker order is sent or blocked by these helpers yet.
- **Validation**:
  - Manual MQL5 review for style, array bounds, constructors, and include
    layering.

### Task 2.2: Add Ranking Helper

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
- **Description**: Rank candidates within a group by classifier score,
  regressor score, and stable strategy priority `S1 > S2 > S3`.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Ranking is deterministic for equal scores.
  - Missing regressor score never outranks a valid higher regressor score when
    classifier scores tie.
  - Strategy priority is the final tie-breaker only.
  - Ranking helper does not depend on array iteration order except as a final
    deterministic fallback for exact duplicate candidates.
- **Validation**:
  - Manual review with small hand-worked candidate examples in the acceptance
    doc.

### Task 2.3: Add Non-Behavioral Debug Formatting

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
  - optional `services/trading_signals/execution_logging.mqh`
- **Description**: Add compact debug tokens for group ID, rank reason, selected
  signal ID, and arbitration action.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Formatting strips tabs/newlines.
  - Logs are gated by existing debug/log settings.
  - No hot-path unbounded logging is introduced.
- **Validation**:
  - Manual review for logging throttle and output size.

## Sprint 3: FILTER-Mode Arbitration Integration

**Goal**: Integrate arbitration into deterministic FILTER admission so multiple
eligible candidates in one group produce at most one broker admission.

**Commit**: `feat: arbitrate ml filter signal admissions`

**Demo/Validation**:

- Run static lifecycle review.
- Confirm selected candidate still uses existing broker admission application.
- Confirm non-selected candidates close without broker exposure.

Execution must complete and validate this sprint before moving to Sprint 4.

### Task 3.1: Split Deterministic Admission Into Evaluate And Apply Steps

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
- **Description**: Refactor the deterministic pending-entry path so candidates
  can be evaluated for activation/admission and collected before broker send is
  applied.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Existing base and macro confirmation behavior is preserved.
  - Existing `PrepareExecutionLegTradeAdmission(...)` remains the broker/risk
    eligibility gate before arbitration collection.
  - Existing `ApplyExecutionLegTradeAdmission(...)` remains the only broker send
    path for the selected candidate.
  - Non-FILTER modes keep current behavior.
- **Validation**:
  - Manual lifecycle trace for `ML_INFERENCE_DISABLED`, `ML_INFERENCE_SHADOW`,
    and `ML_INFERENCE_FILTER`.

### Task 3.2: Collect FILTER-Allowed Candidates Per Tick

- **Location**:
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
- **Description**: During FILTER mode, collect deterministic candidates that
  have passed broker/risk admission preparation and ML FILTER allow.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Candidates blocked by ML classifier remain `ML_FILTER_BLOCKED`.
  - Candidates that fail broker/risk gates are not considered in arbitration.
  - Candidate references include direction array, signal index, leg index, and
    enough identity to safely revalidate before applying.
  - Collection spans both bullish and bearish running arrays, while group
    identity includes direction.
- **Validation**:
  - Manual review for array-index invalidation and reverse iteration risks.

### Task 3.3: Select Winners And Block Losers

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
- **Description**: For each group, select one candidate by rank policy, apply
  broker admission to the selected signal, and close non-selected candidates
  locally with `ML_ARBITRATION_BLOCKED`.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Multi-candidate group produces at most one broker admission.
  - Losers do not send orders and do not produce broker-confirmed outcomes.
  - Losers set `deterministic_stats_terminal_reason =
    "ML_ARBITRATION_BLOCKED"`.
  - Selected candidate still records feature and ML prediction evidence.
  - If selected candidate becomes invalid before apply, implementation either
    chooses the next valid candidate or marks the group as failed with explicit
    telemetry; it must not silently send a stale signal.
- **Validation**:
  - Manual lifecycle trace with two and three candidates in the same group.

## Sprint 4: Arbitration Artifacts And Python Validation

**Goal**: Persist arbitration decisions and update Python summary tooling so
Strategy Tester evidence can prove the behavioral delta.

**Commit**: `feat: record ml arbitration decisions`

**Demo/Validation**:

- Run Python syntax checks for touched Python files.
- Run summary tooling against a compatible generated or fixture-like smoke
  folder if available.
- Confirm old filter run folders without arbitration files fail only when
  arbitration evidence is explicitly required.

Execution must complete and validate this sprint before moving to Sprint 5.

### Task 4.1: Write Arbitration Decision TSV

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/trading_signals/deterministic_signal_ml_arbitration.mqh`
- **Description**: Add `arbitration_decisions.tsv` under the existing shadow
  run folder and queue rows with the existing file-buffering pattern.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - File has a stable header and no duplicate header rows.
  - Rows include selected and blocked candidates for multi-candidate groups.
  - Single-candidate groups are counted in summary; row logging can be compact
    if needed.
  - File writing failures mark export status visibly without affecting live
    behavior because FILTER remains tester-only.
- **Validation**:
  - Manual review of file open/flush/deinit lifecycle.

### Task 4.2: Extend Shadow Summary Counters

- **Location**:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add arbitration counters to `shadow_summary.tsv`.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Counters include arbitration groups, single-candidate groups,
    multi-candidate groups, selected rows, blocked rows, and tie-breaker usage.
  - Existing filter counters continue to match `shadow_predictions.tsv`.
  - Summary still writes on deinit.
- **Validation**:
  - Manual summary-row review.

### Task 4.3: Update Python Summary Tooling

- **Location**:
  - `tools/deterministic_signal_ml/summarize_filter_run.py`
  - optional new `tools/deterministic_signal_ml/summarize_arbitration_run.py`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Validate arbitration artifacts and print compact counts.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Tool validates required files, duplicate headers, prediction counts,
    filter counts, arbitration counts, and selected/blocked consistency.
  - Tool reports `ML_FILTER_BLOCKED` and `ML_ARBITRATION_BLOCKED` separately.
  - Tool remains backward-compatible unless an explicit
    `--require-arbitration` flag is used.
  - No full TSV content is printed.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/summarize_filter_run.py`

## Sprint 5: Compile And Strategy Tester Smoke Evidence

**Goal**: Prove the full Phase 2 behavior compiles and works in Strategy Tester
on a short XAUUSD smoke run before any long dataset run is attempted.

**Commit**: `docs: record ml signal arbitration evidence`

**Demo/Validation**:

- Run MetaEditor compile at phase end.
- Run short XAUUSD Strategy Tester smoke validation with `ML_INFERENCE_FILTER`.
- Run Python summary tooling against the generated shadow/filter run folder.
- Record compact evidence and remaining limitations.

Execution must complete and validate this sprint before Phase 2 is accepted.

### Task 5.1: Final MetaEditor Compile

- **Location**:
  - `HFT_Grid_AI.mq5`
  - compile logs under `logs/compile/`
- **Description**: Compile the EA after all Phase 2 MQL5 changes are in place.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Compile exits successfully.
  - Warnings and errors are treated as failures unless a documented exception
    is explicitly accepted.
  - No generated compile logs are pasted into chat.
- **Validation**:
  - Prefer `python3 tools/mt5/compile_mt5.py` or the environment runbook's
    MetaEditor command.

### Task 5.2: Run XAUUSD FILTER Smoke Test

- **Location**:
  - generated ignored outputs under MT5 Common Files
  - `docs/research/ml-signal-arbitration-acceptance.md`
- **Description**: Run a short XAUUSD Strategy Tester smoke test with
  `ML_INFERENCE_FILTER` and all three deterministic strategies enabled.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Run folder contains shadow/filter artifacts and arbitration artifacts.
  - At least one multi-candidate group should be observed, or the evidence must
    explicitly state that the selected date range did not produce convergence.
  - Multi-candidate groups produce at most one selected broker admission.
  - Non-selected candidates are counted as `ML_ARBITRATION_BLOCKED`.
  - Existing `ML_FILTER_BLOCKED` counts remain separate.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py --shadow-run-path <path> --require-arbitration`
  - Optional Python/MQL5 scorer comparison remains available through
    `compare_shadow_predictions.py`.

### Task 5.3: Record Phase 2 Evidence And Run Policy

- **Location**:
  - `docs/research/ml-signal-arbitration-acceptance.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Record compact evidence and define when the long XAUUSD run
  should be generated.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Evidence records run ID, symbol, date range, export ID, predictions,
    filter allow/block counts, arbitration groups, selected rows, blocked rows,
    and result.
  - Document states old run data was intentionally not reused.
  - Document states a long XAUUSD run should be generated only after this smoke
    validation passes.
  - Document states US30 or other symbols remain Phase 5 multi-symbol research
    unless a separate plan changes scope.
- **Validation**:
  - Manual doc review.

## Testing Strategy

- Documentation-only sprint validation for Sprint 1.
- Manual MQL5 lifecycle and include-order review for Sprints 2 and 3.
- Python syntax validation for touched Python files in Sprint 4:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`
- Final MetaEditor compile in Sprint 5, following
  `docs/environment/mt5-agentic-workflows.md`.
- Human-in-the-loop Strategy Tester smoke validation in Sprint 5.
- Generated artifacts stay ignored under MT5 Common Files or `artifacts/` and
  are summarized compactly only.

## Acceptance Gate

Phase 2 is accepted only when:

- FILTER-mode simultaneous candidates produce at most one broker admission per
  arbitration group.
- Non-selected candidates are locally closed with
  `ML_ARBITRATION_BLOCKED` and no broker order.
- Selected candidates still pass all existing broker/risk gates.
- `ML_FILTER_BLOCKED` and `ML_ARBITRATION_BLOCKED` are distinct in artifacts
  and summary tooling.
- Strategy Tester smoke evidence demonstrates the behavioral delta or clearly
  records that the smoke range did not produce multi-candidate convergence.
- No live deployment behavior is approved.
- No Feature Schema V2, ONNX, multi-symbol, or dynamic target work is included.

## Long Run Policy After Phase 2

After Phase 2 smoke validation passes, generate a fresh long XAUUSD Strategy
Tester run if the next work requires robust post-arbitration evidence. Recommended
policy:

- Use ML mode according to the research objective:
  - `ML_INFERENCE_DISABLED` for raw deterministic feature/outcome generation.
  - `ML_INFERENCE_FILTER` when specifically measuring post-arbitration filter
    behavior.
- Use a distinct run ID for each symbol and date range.
- Do not reuse old pre-arbitration run folders as Phase 2 evidence.
- Keep US30 or other symbols out of Phase 2 acceptance unless a future
  multi-symbol plan explicitly brings them in.

## Potential Risks And Gotchas

- Current deterministic lifecycle sends a broker order inside per-signal update.
  Arbitration requires a two-phase collect/rank/apply path in FILTER mode so
  one candidate cannot send before peers are evaluated.
- Running bullish and bearish arrays are processed separately today. Candidate
  collection must span both arrays while grouping by direction.
- Array indices can become stale if blocked/closed signals are removed before
  all decisions are applied. Candidate references must be revalidated before
  broker send or local block.
- `ml_shadow_evaluated` is currently used to avoid double scoring. Arbitration
  must not accidentally skip scoring or reuse stale decisions after entry
  anchors refresh.
- Adding columns to existing TSV headers can break strict validators. Prefer a
  new arbitration TSV and optional backward-compatible summary validation.
- If no multi-candidate group appears in a short smoke range, the code may still
  compile and run but acceptance evidence will be incomplete. Choose a date
  range likely to produce S1/S2/S3 convergence, or record the gap and rerun.
- The current model is XAUUSD-only. US30 evidence is not valid Phase 2 model
  evidence unless Phase 5 multi-symbol research later approves symbol scope.

## Rollback Plan

- Disable the new arbitration path by reverting the Sprint 2-4 MQL5 helper and
  integration changes.
- Keep `ML_INFERENCE_DISABLED` as the default runtime mode.
- Keep `ML_INFERENCE_SHADOW` observational and fail-open.
- If artifact validation fails, continue using existing Phase 1-6 FILTER
  behavior only for its previously accepted Strategy Tester scope.
- Do not modify or delete accepted model exports as part of rollback.
