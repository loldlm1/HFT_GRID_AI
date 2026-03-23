# Plan: Structure Trailing When TP Mode

**Generated**: 2026-03-22
**Estimated Complexity**: Medium

## Overview
Add a new `TrailingStructureModes` option:
- `TRAILING_BY_STRUCTURE_WHEN_TP`

Requested behavior:
- before the signal reaches its initial TP, do not trail by structure
- when the signal first reaches its initial TP:
  - if `Trailing_TP_Close_Percent > 0`, execute the configured partial close slice at that initial TP event
  - then arm structure-based trailing
- after the mode is armed, behave like the existing `TRAILING_BY_STRUCTURE`

This is simpler than the original structure-trailing addon because it reuses the current trailing engine and only adds a one-time activation gate. The main implementation risk is lifecycle control flow: the EA must keep the legacy initial-TP path alive until the gate is armed, otherwise the mode would disable TP handling too early.

## Working Assumptions
- “Initial TP” means the same TP anchor already used elsewhere in the addon:
  - non-grid signal: the first resolved TP of level `0`
  - grid signal: the original TP of the currently active grid level
- `Trailing_TP_Close_Percent = 0` still arms structure trailing at the initial TP event, but no partial close is executed there
- `Trailing_TP_Close_Percent = 100` is valid; in that case the initial TP event may fully close the signal and structure trailing never becomes active
- no new entitlement is required; this is another mode of the existing structure trailing addon

## Prerequisites
- Preserve the include pipeline and current signal-wide trailing model
- Reuse the existing trailing state and partial-close math where possible
- Keep stop/TP handling local to the EA
- Use the project test flow:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`

## Sprint 1: Add the Mode Contract and Arming State
**Goal**: introduce the new mode cleanly without changing runtime behavior yet.
**Demo/Validation**:
- New enum/input compiles cleanly
- Existing modes behave exactly the same
- New mode remains inert until the lifecycle logic is wired

### Task 1.1: Extend the Trailing Mode Enum and Runtime Sanitizer
- **Location**:
  `services/core/enums.mqh`
  `services/trading_management/trailing_structure_context.mqh`
- **Description**:
  Add `TRAILING_BY_STRUCTURE_WHEN_TP` and update the runtime sanitizers/helpers so the mode is recognized explicitly.

  Add helper predicates to separate:
  - structure trailing configured
  - structure trailing requires initial-TP arming
  - TP/BE variant enabled
- **Dependencies**: none
- **Acceptance Criteria**:
  - enum values stay centralized
  - invalid trailing mode values still clamp safely to `TRAILING_OFF`
  - existing mode helpers remain backward compatible
- **Validation**:
  - compile-only pass
  - unit tests for mode resolution

### Task 1.2: Extend Per-Signal State for Initial-TP Arming
- **Location**:
  `services/trading_signals/signal_params_struct.mqh`
- **Description**:
  Add the minimum state needed to arm structure trailing once:
  - boolean flag: initial TP gate armed
  - datetime: initial TP arm time
  - optional price/time audit fields if needed for logs/frontend

  This mode should not reuse `trailing_last_tp_structure_time` for the gate because that field means “consumed structure extremum,” not “initial TP milestone reached.”
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - constructor/copy-constructor coverage remains correct
  - the arming state is signal-local and independent across concurrent signals
- **Validation**:
  - state copy tests or constructor checks

## Sprint 2: Wire the Initial-TP Gate Into the Lifecycle
**Goal**: keep normal TP behavior before the gate, then switch the signal into structure trailing after the initial TP event.
**Demo/Validation**:
- Before initial TP, no structure-based SL/TP updates occur
- At initial TP, the mode arms and optionally takes the configured partial
- After arming, the signal follows the current structure-trailing engine

### Task 2.1: Separate “Configured” From “Actively Managing” in the Controller
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
  `services/trading_management/trailing_structure_context.mqh`
- **Description**:
  The controller currently treats `StructureTrailingEnabled()` as “disable legacy TP path and let structure trailing take over.”

  For the new mode, that is too coarse. Add explicit controller-level logic for:
  - mode configured
  - mode armed for this signal
  - structure trailing actively managing this signal

  Recommended contract:
  - `TRAILING_BY_STRUCTURE` and `TRAILING_BY_STRUCTURE_TP_BE`: active immediately once the signal has active exposure
  - `TRAILING_BY_STRUCTURE_WHEN_TP`: active only after the initial TP gate has armed
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - legacy initial TP handling remains active before arming
  - structure trailing does not suppress initial TP behavior too early
- **Validation**:
  - controller-focused tests for pre-arm and post-arm branches

### Task 2.2: Implement Initial-TP Gate Detection
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Add a small helper that detects the first initial-TP reach event for the signal using the resolved initial TP anchor.

  On that event:
  - if `Trailing_TP_Close_Percent > 0`, close the configured slice using the existing partial-close flow
  - set the signal’s “structure trailing armed” state
  - record the arm time for later temporal gating

  Important:
  - arming must be one-time only
  - the initial TP event must not be processed twice on later revisits
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - no double partials from the same initial TP event
  - arming occurs exactly once per signal
  - `0%` and `100%` cases behave deterministically
- **Validation**:
  - unit tests for one-time arming and slice execution

### Task 2.3: Reuse the Existing Structure-Trailing Engine After Arming
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Once armed, hand off to the existing structure-trailing logic instead of introducing a second trailing implementation.

  The new mode should:
  - reuse current SL/TP structure updates
  - reuse current partial-close math for structure TP events
  - reuse current stale-structure and lifecycle protections

  The only difference after arming should be “when trailing started,” not “how trailing works.”
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - no forked trailing engine is created
  - post-arm behavior matches `TRAILING_BY_STRUCTURE`
  - current SL-lifecycle fixes remain intact
- **Validation**:
  - regression tests comparing post-arm behavior with the base mode

## Sprint 3: Cover Edge Cases and Frontend Behavior
**Goal**: make the mode predictable in QA and visible on chart.
**Demo/Validation**:
- Chart lines and logs reflect pre-arm vs post-arm behavior clearly
- Edge cases are deterministic and documented

### Task 3.1: Define Frontend Behavior Before and After Arming
- **Location**:
  `services/frontend/grid_visualization.mqh`
- **Description**:
  Freeze the chart behavior:
  - before arming:
    - show the normal initial TP line
    - do not show structure trailing SL/TP lines yet unless there is already a valid carried stop by design
  - after arming:
    - show the structure-based trailing SL/TP lines as normal

  This prevents QA confusion where a signal appears to be trailing before the mode has actually armed.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - visuals match the signal’s real management state
  - pre-arm and post-arm are distinguishable
- **Validation**:
  - manual chart QA after runtime smoke

### Task 3.2: Add Clear Log Events for the Gate
- **Location**:
  `services/trading_signals/grid_order_logging.mqh`
  `services/trading_signals/grid_order_controller.mqh`
- **Description**:
  Add explicit events for:
  - initial TP gate armed
  - initial TP gate partial executed
  - initial TP gate fully closed signal

  The goal is to make QA immediately see whether a signal is:
  - still pre-arm
  - armed and now trailing
  - fully closed at the gate
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - event names are distinct from normal `TRAILING_TP_HIT`
  - logs explain whether the close was the initial TP gate or structure trailing
- **Validation**:
  - inspect terminal/file logs on one controlled repro

## Sprint 4: Regression Matrix and Final Validation
**Goal**: verify the new mode without regressing the existing trailing modes.
**Demo/Validation**:
- compile-only strict gate passes
- runtime matrix smoke passes
- existing modes still behave as before

### Task 4.1: Add Focused Harness Coverage
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh`
  optionally a new focused case if cleaner
- **Description**:
  Add regressions for:
  - new mode stays inactive before initial TP
  - initial TP gate arms exactly once
  - `0%` partial: no close at gate, trailing starts afterward
  - `25%` partial: one initial slice at gate, later structure TP events continue using the existing slice logic
  - `100%` partial: gate fully closes signal and trailing never starts
  - post-arm behavior matches `TRAILING_BY_STRUCTURE`
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - all meaningful mode branches are covered
  - existing `TRAILING_BY_STRUCTURE` and `TRAILING_BY_STRUCTURE_TP_BE` tests remain green
- **Validation**:
  - compile-only pass
  - runtime harness pass

### Task 4.2: Run Compatibility Matrix Across Existing Trigger/Compound Combinations
- **Location**:
  `logs/test-runner/latest/*`
- **Description**:
  Re-run the standard matrix with emphasis on:
  - `LEVELS_AS_LIMITS`
  - `LEVEL_AS_ZONE`
  - representative `TrendStructureCompoundModes`

  The new mode should be largely independent of entry mode because it arms on the initial TP milestone, but this matrix confirms controller integration did not create hidden coupling.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - compile-only strict gate passes
  - matrix smoke passes on `EURUSD`, `XAUUSD`, `US30`, `USDJPY`
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`

## Testing Strategy
- Add unit/harness coverage before changing controller behavior
- Verify one-time gate semantics separately from normal post-arm trailing
- Keep all current trailing regressions active
- Run full compile and runtime matrix at the end

## Potential Risks & Gotchas
- The biggest bug risk is disabling the legacy initial TP path too early. The new mode must not act like “trailing enabled immediately.”
- `100%` partial at the gate is logically valid but means the mode never actually trails; that is expected and should be documented.
- Grid signals need a stable definition of “initial TP” at the arming moment. Reusing the current active-level TP anchor is the simplest and most consistent option.
- Frontend labels can be misleading if pre-arm and post-arm are not visually distinguished.

## Rollback Plan
- Remove the new enum value and runtime helper branches
- Remove the signal arming state
- Revert controller changes that split pre-arm and post-arm behavior
- Keep any added tests as pending only if product decides not to ship the mode
