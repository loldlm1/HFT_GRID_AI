# Plan: Pandora First Entry Depth Input

**Generated**: 2026-06-16
**Status**: Completed on 2026-06-16
**Estimated Complexity**: Medium / Trading-Safety Sensitive

## Overview

Replace the public `Pandora_First_Entry_Mode` enum input with an integer depth
input so Strategy Tester optimization can explore more than two deep first-entry
levels.

Target public contract:

- `Pandora_First_Entry_Mode = -1`: local-only compatibility mode, equivalent to
  current `First_Entry_Off`; it admits a local Pandora entry and never opens a
  broker market position.
- `Pandora_First_Entry_Mode = 0`: normal first entry at Pandora breakout,
  equivalent to current `First_Entry_Breakout`.
- `Pandora_First_Entry_Mode = 1`: observe breakout locally and enter real market
  at the first same-direction SL depth, equivalent to current `First_Entry_Sl_1`.
- `Pandora_First_Entry_Mode = 2`: observe breakout locally, advance through SL1,
  and enter real market at SL2, equivalent to current `First_Entry_Sl_2`.
- `Pandora_First_Entry_Mode = N`: for `N > 2`, repeat the same observation step
  pattern until the Nth same-direction SL depth is reached.

The key implementation change is not the input type itself; that part is
simple. The real work is generalizing the current two-level observation state.
Today the code has enum-backed modes and fixed observation stages
(`BREAKOUT_OBSERVE`, `SL1_OBSERVE`) plus a special-case branch for SL2. The new
integer depth should replace those fixed branches with a small depth counter:

- target depth: configured integer depth
- current observation depth: `0` at breakout observation, `1` after SL1 has been
  touched, etc.
- trigger depth: `current + 1`

For each local observation stage, if the observation TP hits before the next
deep trigger, the opportunity is discarded and budget behavior stays equivalent
to the current SL1/SL2 logic. If the next deep trigger hits and it is not yet the
target depth, the observation advances to the next anchor. If it is the target
depth, the real market entry is admitted through the existing broker-realistic
path.

No changes should be made to Pandora lot sizing, broker send/retry, SL/TP
rebasing, session gating, license/magic-number scope, or protection logic.

## Confirmed Product Decisions

- Preserve current `First_Entry_Off` behavior as `Pandora_First_Entry_Mode = -1`.
  This compatibility mode should not open a broker market position.
- Add an internal safety clamp for maximum depth:
  `PANDORA_FIRST_ENTRY_MAX_DEPTH = 20`. Values below `-1` clamp to `-1`; values
  above `20` clamp to `20`.
- Keep the input name `Pandora_First_Entry_Mode` to avoid changing existing set
  file parameter names, but change its type to `input int`. Existing enum-based
  set files will need manual value migration because enum numeric values differ
  from the new contract.

## Prerequisites

- Read `docs/planner-execution-discipline.md` before implementation.
- Execute Sprints in order, with compile validation and one commit per Sprint.
- Keep the include pipeline unchanged.
- Do not add a second public input unless the user revises the plan.
- Use MetaEditor compile after every Sprint and remove `BUILD.log` after
  inspection:

```powershell
if (Test-Path -LiteralPath 'BUILD.log') { Remove-Item -LiteralPath 'BUILD.log' }
& cmd.exe /c '"C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /portable /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"'
Get-Content -LiteralPath 'BUILD.log' | Select-Object -Last 30
Remove-Item -LiteralPath 'BUILD.log'
```

## Sprint 1: Input Contract And Runtime Fields

**Goal**: Introduce the integer depth contract without changing runtime behavior
yet.
**Commit**: `Sprint 1: add Pandora first entry depth input`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- `Pandora_First_Entry_Mode = 0`, `1`, and `2` resolve to behavior-equivalent
  runtime values for current Breakout, SL1, and SL2 paths.

### Task 1.1: Change Public Input Type

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Change `input PandoraFirstEntryModes Pandora_First_Entry_Mode`
  to `input int Pandora_First_Entry_Mode = 0`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Default value `0` preserves current production default breakout behavior.
  - Value `-1` preserves current local-only/no-market behavior.
  - No new public input is introduced.
  - Existing input order remains after `Pandora_Box_Max_Entries`.
- **Validation**:
  - Compile.
  - Manual review of input ordering.

### Task 1.2: Add Depth Runtime Fields

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add integer fields for target/current observation depth:
  `pandora_first_entry_target_depth` and
  `pandora_first_entry_observation_depth`. Keep current enum fields only as
  temporary compatibility during the staged migration if needed.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Constructors initialize target/current depth to `0`.
  - Copy constructor copies both fields.
  - Runtime state stores resolved target depth from the input.
- **Validation**:
  - Compile.
  - Manual constructor/copy review.

### Task 1.3: Add Resolver And Labels

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add helpers:
  - `PandoraResolveFirstEntryDepth()`
  - `PandoraFirstEntryDepthIsDeep(depth)`
  - `PandoraFirstEntryDepthLabel(depth)`
  - optional compatibility helpers mapping old enum labels to depth labels
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - `-1` labels as `OFF`.
  - `0` labels as `BREAKOUT`.
  - `1` labels as `SL1`.
  - `2` labels as `SL2`.
  - `N > 2` labels as `SLN`.
  - Out-of-range values clamp deterministically to `[-1, 20]` and log only when
    existing logging policy allows.
- **Validation**:
  - Compile.
  - Manual label review in frontend/log call sites.

## Sprint 2: Generalized Observation Math

**Goal**: Replace fixed SL1/SL2 observation target math with depth-indexed
target math.
**Commit**: `Sprint 2: generalize Pandora first entry observation targets`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Depth `1` and `2` produce the same trigger/TP levels as current SL1/SL2.
- Depth `3+` computes trigger/TP from the current observation anchor.

### Task 2.1: Replace Stage-Specific Target Builder

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Refactor `PandoraBuildFirstEntryObservationTargets()` and
  `PandoraSetFirstEntryObservationTargets()` to accept a current observation
  depth integer instead of fixed stage enum values.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Breakout observation starts at depth `0` and targets depth `1`.
  - After each unfavorable SL step, the new anchor is the trigger price.
  - TP for each observation is favorable from that current anchor.
  - Points mode and box-percent mode continue using existing
    `PandoraResolveSignalSLPoints()` and `PandoraResolveSignalTPPoints()`.
- **Validation**:
  - Compile.
  - Manual bullish/bearish math review for depths 1, 2, and 3.

### Task 2.2: Generalize Observation Stage Labels

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/frontend/grid_visualization.mqh`
- **Description**: Keep terminal stages such as `MARKET`, `DISCARDED`, and
  `EXPIRED`, but display active observation labels from depth integers
  (`OBS_BREAKOUT`, `OBS_SL1`, `OBS_SL2`, etc.).
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Existing chart labels for SL1/SL2 remain understandable.
  - Depth `3+` displays `SL3 entry`, `SL4 entry`, etc.
  - Logs include target depth and current observation depth where helpful.
- **Validation**:
  - Compile.
  - Manual frontend label review.

## Sprint 3: Generalized Lifecycle Admission

**Goal**: Replace the SL2 special case in the grid lifecycle with a loop-like
depth advance/admission decision.
**Commit**: `Sprint 3: generalize Pandora first entry depth lifecycle`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Depth `1` admits at first trigger.
- Depth `2` advances once then admits at second trigger.
- Depth `3+` advances until the configured target depth, then admits.

### Task 3.1: Refactor Observation Update Controller

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Replace the fixed branch:
  `stage == BREAKOUT_OBSERVE && mode == First_Entry_Sl_2`
  with generic logic:
  - on trigger, increment current observation depth
  - if current depth is less than target depth, reset observation targets from
    the trigger anchor
  - if current depth equals target depth, register budget and admit market entry
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - No `for` or `while` loop is needed in hot path; one trigger processes one
    state transition per tick.
  - Budget registration still happens only on discard or final market admission.
  - Broker-realistic market admission path remains unchanged after final depth.
- **Validation**:
  - Compile.
  - Manual diff review of `GridUpdatePandoraFirstEntryObservation()`.

### Task 3.2: Preserve Discard And Expiration Semantics

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure observation TP before next trigger discards exactly as
  current SL1/SL2 logic does, and expiration still closes observation without
  consuming budget when applicable.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Depth `N` discard consumes budget when observation TP is reached.
  - Expiration behavior remains current.
  - `Pandora_Box_Stop_On_First_Win` continues to finish the day after a TP-like
    discard.
- **Validation**:
  - Compile.
  - Manual scenario review for depth 1, 2, and 3.

## Sprint 4: Remove Enum Coupling And Preserve Compatibility

**Goal**: Cleanly retire or isolate old enum coupling so the integer depth is
the source of truth.
**Commit**: `Sprint 4: remove Pandora first entry enum coupling`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- No production logic branches on `First_Entry_Sl_1` or `First_Entry_Sl_2`.

### Task 4.1: Update Signal And Runtime Types

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Remove or deprecate `PandoraFirstEntryModes` from runtime
  state and signals. Keep `PandoraFirstEntryStages` only for terminal lifecycle
  states if still useful, or replace active observation stages with depth fields.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - `pandora_first_entry_target_depth` is the source of truth.
  - Existing Breakout/SL1/SL2 behavior can be expressed by integer depths.
  - `First_Entry_Off` compatibility decision is implemented consistently.
- **Validation**:
  - Compile.
  - `rg "First_Entry_|PandoraFirstEntryModes"` shows no unexpected production
    dependencies.

### Task 4.2: Update First Entry Off Path

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - docs
- **Description**: Preserve local-only compatibility as
  `Pandora_First_Entry_Mode = -1` and update all runtime branches/docs from
  enum-based `First_Entry_Off` checks to integer-depth compatibility checks.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Local-only remains explicit and documented as compatibility.
  - Value `-1` never creates broker history.
  - Normal `0` never calls the local-only path.
- **Validation**:
  - Compile.
  - Manual lifecycle review.

## Sprint 5: Documentation And Regression Matrix

**Goal**: Update user-facing docs and tester checklist for integer-depth first
entry modes.
**Commit**: `Sprint 5: document Pandora first entry depth input`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Docs describe the integer mapping and migration from old enum values.

### Task 5.1: Update Guides

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Replace enum labels with integer-depth mapping. Add migration
  note for old set files:
  - old `First_Entry_Breakout` becomes `0`
  - old `First_Entry_Sl_1` becomes `1`
  - old `First_Entry_Sl_2` becomes `2`
  - old `First_Entry_Off` becomes `-1`
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Docs no longer imply depth is limited to SL2.
  - Deep-entry examples include at least depth `3`.
  - Tester guidance warns that very deep values may rarely trigger.
- **Validation**:
  - Manual docs review.

### Task 5.2: Update Visual/Test Checklist

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/plans/pandora-first-entry-depth-input-plan.md`
- **Description**: Add manual tester scenarios for depths 0, 1, 2, and 3+.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Checklist covers breakout default, SL1 admission, SL2 advance/admission,
    SL3 advance/admission, TP discard at intermediate depth, and expiration.
- **Validation**:
  - Manual review.

## Sprint 6: Final Hardening

**Goal**: Validate final behavior and produce a clear handoff for manual
Strategy Tester runs.
**Commit**: `Sprint 6: validate Pandora first entry depth input`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- `BUILD.log` is inspected and removed.
- Final diff confirms no unrelated order, license, lot, or protection changes.

### Task 6.1: Final Static Review

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/frontend/grid_visualization.mqh`
  - docs
- **Description**: Review final code for fixed SL1/SL2 assumptions, hot-path
  cost, and trading safety invariants.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - No remaining SL2 hard-coded lifecycle branch.
  - No unbounded loops are added to per-tick lifecycle.
  - Broker-realistic admission still uses existing order send/retry path.
  - Budget registration still happens exactly once.
- **Validation**:
  - `git diff --check`
  - MetaEditor compile.

### Task 6.2: Manual Tester Handoff

- **Location**:
  - `docs/plans/pandora-first-entry-depth-input-plan.md`
- **Description**: Add execution notes with commits, compile result, and manual
  tester scenario list after implementation.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Handoff includes exact mapping and known migration risks.
  - User can run depth `0`, `1`, `2`, and `3+` in Strategy Tester.
- **Validation**:
  - Manual docs review.

## Testing Strategy

- Compile after every Sprint with MetaEditor and delete `BUILD.log` after
  inspection.
- Manual Strategy Tester scenarios:
  - `Pandora_First_Entry_Mode = -1`: local-only/no broker market position.
  - `Pandora_First_Entry_Mode = 0`: default breakout behavior.
  - `Pandora_First_Entry_Mode = 1`: current SL1-equivalent admission.
  - `Pandora_First_Entry_Mode = 2`: current SL2-equivalent staged observation.
  - `Pandora_First_Entry_Mode = 3`: two observation advances, then market
    admission at SL3.
  - Intermediate TP discard before target depth.
  - Session expiration while observing.
  - Step trailing enabled: local observations still use fixed TP; trailing only
    starts after real market admission.
- Compare depth 1 and 2 against known current behavior before trusting depth 3+.

## Execution Notes

- Sprint batch executed in order from Sprint 1 through Sprint 6.
- Sprint 1 completed in commit `e8a8fe8`:
  `Sprint 1: add Pandora first entry depth input`.
- Sprint 2 completed in commit `f88be0c`:
  `Sprint 2: generalize Pandora first entry observation targets`.
- Sprint 3 completed in commit `15a51dd`:
  `Sprint 3: generalize Pandora first entry depth lifecycle`.
- Sprint 4 completed in commit `a77fe9a`:
  `Sprint 4: remove Pandora first entry enum coupling`.
- Sprint 5 completed in commit `bfd91fe`:
  `Sprint 5: document Pandora first entry depth input`.
- Sprint 6 final hardening validates this plan state and the final MetaEditor
  compile gate.
- Final compile gate on 2026-06-16 passed with `0 errors, 0 warnings`; the
  generated `BUILD.log` was inspected and removed.
- Final public mapping:
  - `Pandora_First_Entry_Mode = -1`: local-only compatibility, no broker market
    position.
  - `Pandora_First_Entry_Mode = 0`: default breakout admission.
  - `Pandora_First_Entry_Mode = 1`: SL1 deep admission.
  - `Pandora_First_Entry_Mode = 2`: SL2 staged observation/admission.
  - `Pandora_First_Entry_Mode = N`: repeat same-direction staged observation up
    to the internal clamp of `20`.
- Migration risk: old enum-based `.set` files must be updated manually. The old
  enum numeric values do not match the new integer-depth contract.
- Recommended manual Strategy Tester scenarios:
  - Depth `0`: confirm normal breakout admission remains unchanged.
  - Depth `1`: confirm breakout observation admits at SL1 and discards on
    observation TP.
  - Depth `2`: confirm one `PANDORA_FIRST_ENTRY_OBSERVE_ADVANCE`, then market
    admission at SL2 or discard on intermediate TP.
  - Depth `3+`: confirm chart/log labels advance dynamically (`SL1 entry`,
    `SL2 entry`, `SL3 entry`) and market admission occurs only at target depth.
  - Depth `-1`: confirm local-only compatibility creates no broker history.
  - Session expiration while observing: confirm observation closes with the
    existing expiration path.
  - Step trailing enabled: confirm observation still uses fixed TP and trailing
    starts only after real broker market admission.

## Potential Risks & Gotchas

- This is not just an input type change. Current runtime logic is hard-coded to
  SL1/SL2 through enum modes and fixed observation stages.
- Existing `.set` files using enum numeric values will not map cleanly:
  current enum values are `First_Entry_Off = 0`, `First_Entry_Breakout = 1`,
  `First_Entry_Sl_1 = 2`, `First_Entry_Sl_2 = 3`; the proposed integer contract
  is `-1 = Off/local-only`, `0 = Breakout`, `1 = SL1`, `2 = SL2`.
- `-1` must remain clearly documented as compatibility/local-only and not as
  part of the positive depth sequence.
- Very deep values may almost never trigger and can keep a day observing until
  expiration. This is useful for research but should be documented.
- Box-percent mode compounds the practical meaning of deep levels because each
  SL step is derived from the resolved SL points at the current anchor.
- Chart labels and logs must be generated dynamically for SL3+ to avoid
  misleading tester review.

## Rollback Plan

- Revert Sprint commits in reverse order.
- If depth generalization causes missed entries, revert Sprints 2-4 first and
  restore enum-based SL1/SL2 behavior.
- If only docs/migration wording is wrong, revert Sprint 5/6 docs commits.
- After rollback, run MetaEditor compile, inspect `BUILD.log`, delete it, and
  manually confirm current `First_Entry_Breakout`, `First_Entry_Sl_1`, and
  `First_Entry_Sl_2` behavior remains unchanged.
