# Plan: Structure Trailing SL Lifecycle Fix

**Generated**: 2026-03-22
**Estimated Complexity**: Medium

## Overview
Fix the remaining `TRAILING_BY_STRUCTURE` stop-side failure where a signal can close immediately after a new level opens.

The reproduced log sequence from March 17, 2026 shows the current failure mode clearly:
- `2026-03-17 13:26:44 [LEVEL_REACHED]`
- `2026-03-17 13:26:44 [TRAILING_SL_UPDATE]`
- `2026-03-17 13:26:45 [TRAILING_SL_HIT]`

That sequence proves one concrete bug:
- after a new level executes, the stop-side trailing selector can still adopt a structure extremum that existed before the level activation time

Local code review also shows a second lifecycle risk:
- the EA currently evaluates pending level activation before enforcing existing signal-level trailing stop exits, so a deeper level can still be opened even when the basket should already have been closed by a previously accepted trailing stop

This plan fixes both issues together rather than patching only the visible symptom.

## Scope
- Fix only the stop-side behavior of `TRAILING_BY_STRUCTURE` and `TRAILING_BY_STRUCTURE_TP_BE`
- Keep the current signal-wide trailing model
- Do not change broker-side SL/TP behavior
- Do not change fibonacci entry semantics in this fix

## Non-Goals
- No new addon/product behavior
- No restructuring of grid TP math
- No changes to compound-mode entry rules

## Root Cause Summary
- `FindNextTrailingCandidate(...)` already uses an activation-time floor for TP selection, but SL selection still uses only `trailing_last_sl_structure_time`
- `UpdateGridLifecycle(...)` activates pending levels before applying the trailing stop guard to the already-open basket
- Accepted signal-wide trailing stop state is not reset on new level creation, which is correct, but it makes lifecycle ordering more important

## Prerequisites
- Keep the functional include pipeline unchanged
- Preserve current signal-wide trailing semantics
- Use the strict repo workflow:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`

## Sprint 1: Reproduce Both Failure Classes in Tests
**Goal**: lock the bug down with deterministic harness coverage before touching lifecycle code.
**Demo/Validation**:
- Harness reproduces the exact post-activation SL update failure
- Harness reproduces the stale-existing-stop lifecycle failure
- Existing TP regression remains green

### Task 1.1: Add a Regression for Post-Activation Pre-Existing SL Structures
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh`
- **Description**:
  Add a stop-side twin of the TP regression already implemented:
  - active bullish and bearish signals
  - a newly executed level with `last_action_time`
  - latest qualifying SL extremum timestamp older than that activation time
  - expected result: no SL update and no new consumed SL timestamp
- **Dependencies**: none
- **Acceptance Criteria**:
  - SL candidate selection rejects pre-activation extrema for both directions
  - test names clearly distinguish stop-side gating from TP-side gating
- **Validation**:
  - per-test compile
  - harness runtime pass

### Task 1.2: Add a Lifecycle Regression for Existing Stop Before Next-Level Activation
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh`
  or a dedicated new case if clearer:
  `tests/harness/cases/structure_trailing_lifecycle_test_case.mqh`
- **Description**:
  Model a signal with:
  - one active basket level
  - one pending next level
  - an already-accepted `trailing_stop_price`
  - current price already beyond that stop before the next level activation branch runs

  Expected behavior after the fix:
  - signal closes by trailing stop
  - no new `LEVEL_REACHED` event
  - no new level is opened
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - lifecycle test fails under old ordering and passes under new ordering
  - both full-close state and event ordering are asserted
- **Validation**:
  - compile-only pass
  - runtime harness pass

### Task 1.3: Preserve the “Legitimate Later SL” Case
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh`
- **Description**:
  Add a positive regression where:
  - a level executes
  - a newer qualifying SL extremum forms after the activation time
  - the SL update is accepted and can later trigger normally
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - the new guard does not freeze stop trailing permanently
  - monotonic SL ratcheting still works
- **Validation**:
  - targeted harness assertions

## Sprint 2: Fix the Stop Eligibility Contract
**Goal**: make SL candidate selection obey the same temporal safety model as TP candidate selection.
**Demo/Validation**:
- No stop update is accepted from a structure older than the active level execution time
- Newer post-activation structures continue to ratchet stops normally

### Task 2.1: Generalize Trailing Eligibility Floors Per Side
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Refactor the current eligibility helper so both sides are explicit:
  - TP floor:
    `max(last_tp_structure_time, active_level_activation_time)`
  - SL floor:
    `max(last_sl_structure_time, active_level_activation_time)`

  Keep the comparison strict:
  - extremum timestamp must be `>` the eligibility floor

  This intentionally rejects same-second/same-level ambiguity as the safer default.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - SL and TP use the same temporal contract shape
  - consumed structure timestamps still prevent duplicate reuse
  - no change to bullish/bearish extremum matching rules
- **Validation**:
  - stop-side and TP-side harness tests pass together

### Task 2.2: Keep Signal-Wide Stop State Stable Across Level Changes
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh`
  `services/trading_signals/signal_params_struct.mqh`
- **Description**:
  Confirm the stop-state behavior explicitly:
  - do not clear an already-accepted signal-wide trailing stop just because a deeper level becomes active
  - only advance it when a newer valid structure appears

  If the code needs clarifying comments or helper boundaries, add them here.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - no regression where deeper levels erase valid existing protection
  - accepted stop state remains monotonic and signal-scoped
- **Validation**:
  - lifecycle regression plus positive later-structure regression

## Sprint 3: Fix Lifecycle Ordering
**Goal**: ensure trailing protection is enforced before the EA expands the basket with a new level.
**Demo/Validation**:
- If the current basket is already stop-invalidated, the EA closes it before any new level can open
- A just-opened level does not trigger same-tick stop management from stale structures

### Task 3.1: Split Trailing Processing Into Pre-Activation and Hit-Handling Phases
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Separate the current `ProcessSignalStructureTrailing(...)` responsibilities into clearer phases:
  - refresh/apply eligible trailing targets for the currently active basket
  - evaluate stop/TP hit handling
  - return whether the signal lifecycle is complete for this tick

  The important architectural change:
  - run trailing management before pending level activation logic whenever the signal already has an active position
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - existing stop hits block new level activation
  - trailing updates are computed from the pre-activation active level, not from a just-opened level on the same tick
- **Validation**:
  - lifecycle regression passes

### Task 3.2: Prevent Same-Tick Reprocessing After `LEVEL_REACHED`
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
- **Description**:
  After a successful `LEVEL_REACHED`, avoid re-running trailing hit handling in the same lifecycle pass.

  Recommended behavior:
  - pre-activation trailing enforcement happens first
  - level activation may happen after that
  - any new stop/TP eligibility for the newly active level starts on the next tick

  This keeps the temporal model simple and removes “open level then instantly close it from the same pass” behavior.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - no duplicate same-tick trailing path after a successful level execution
  - first valid post-activation trailing structure is processed on a later tick only
- **Validation**:
  - ordered event assertions in harness tests

### Task 3.3: Preserve TP Partial Behavior Under the New Ordering
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
- **Description**:
  Confirm the reordering does not accidentally suppress valid TP partial processing for already-active baskets.

  The intended model:
  - active basket management happens before expansion
  - a valid TP partial can still occur on ticks where the basket is already active
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - TP partial-close behavior remains unchanged for normal active-basket ticks
  - no regression in the previous TP timing fix
- **Validation**:
  - existing structure trailing tests plus smoke suite

## Sprint 4: Improve Diagnostics and Run the Full Matrix
**Goal**: make future QA failures easy to classify and verify the fix across the supported strategy matrix.
**Demo/Validation**:
- Logs distinguish “new stale structure update” from “existing stop already invalid”
- Runtime matrix stays green

### Task 4.1: Enrich Debug/File Logs With Trailing Eligibility Context
- **Location**:
  `services/trading_signals/grid_order_logging.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Extend file/debug logging so QA can see:
  - active level activation time
  - SL/TP eligibility floor
  - accepted candidate extremum timestamp
  - whether an event was caused by a fresh update or an already-held trailing stop

  Terminal logs can stay compact; the detailed audit can live in file logs.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - future reproductions can be classified from logs without re-reading code
  - no noisy terminal-log regression unless explicitly desired
- **Validation**:
  - inspect `query_debug.txt` and runtime logs on one controlled repro

### Task 4.2: Run Full Regression Matrix for Structure Trailing
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh`
  `logs/test-runner/latest/*`
- **Description**:
  Re-run the existing suite plus the new SL regressions with focus on:
  - all `TrendStructureCompoundModes`
  - both `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE`
  - symbols used in the project smoke matrix

  Even though the root cause is not entry-mode specific, this matrix protects against accidental behavioral coupling.
- **Dependencies**: Sprint 4.1
- **Acceptance Criteria**:
  - compile-only strict gate passes
  - fast runtime matrix smoke passes
  - no trailing regressions in breakout modes from the earlier TP fix
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`

## Testing Strategy
- Start with narrow harness cases that assert event ordering and state transitions
- Then run compile-only strict gate
- Then run runtime matrix smoke on `EURUSD`, `XAUUSD`, `US30`, and `USDJPY`
- Manual QA after automation:
  - confirm a new level does not immediately close from a stale SL structure
  - confirm an already-invalid basket closes before a deeper level opens
  - confirm later legitimate SL structures still trail correctly

## Potential Risks & Gotchas
- If the same tick both breaches an existing trailing stop and reaches a new level trigger, the lifecycle order must prefer closing the basket over opening the new level.
- `TimeCurrent()` is second-granularity in logs; equality-edge cases should be treated as ineligible rather than trying to infer intrasecond ordering.
- Reordering trailing processing can accidentally change TP partial timing if stop/TP handling is not split cleanly.
- Existing signal-wide trailing stop state should not be cleared on level activation; otherwise the fix would weaken real protection.

## Rollback Plan
- Revert the lifecycle ordering change in `grid_order_controller.mqh`
- Revert the SL activation-time eligibility floor in `structure_trailing_manager.mqh`
- Keep the added harness tests and mark them pending only if product behavior is intentionally changed
