# Plan: Stochastic Structure Trailing Addon

**Generated**: 2026-03-22
**Estimated Complexity**: High

## Overview
Build a new paid input-group addon that adds per-signal trailing management driven by closed stochastic structure extrema.

Requested product behavior, normalized into an implementation contract:
- add a new enum input with:
  - `TRAILING_OFF`
  - `TRAILING_BY_STRUCTURE`
  - `TRAILING_BY_STRUCTURE_TP_BE`
- add one new trailing partial-close percent input where:
  - `0` means no TP-side partials and the whole signal stays open until the trailing SL path closes it,
  - `100` means full close when the resolved trailing TP is hit,
  - intermediate values close that fraction of the original total signal exposure on each new TP event, capped by the remaining open exposure
- use only closed extrema for trailing updates, never the forming `[0]` slot in `os_market_structures[]`
- manage trailing independently per running signal so multiple same-direction signals can coexist without sharing stop/TP state
- once an extremum-driven TP or SL action is consumed, mark that extremum timestamp as processed and require a strictly newer qualifying structure before another trailing action can occur
- wire the feature as a new addon entitlement with the same runtime policy model used by the existing paid input groups

Local codebase conclusions that shape the plan:
- the current grid engine is mostly virtual: it computes `entry_reference_price`, `take_profit_price`, and next-level activation inside the EA and closes positions in code; it does not currently maintain broker-side SL/TP per ticket
- partial closes are not implemented today, so this addon needs new signal-level state, broker-close helpers, and signal-accounting changes
- the current signal outcome accounting uses an approximate `entry_price -> final close_price` model; partial exits would make that inaccurate unless realized PnL is tracked explicitly

Working assumptions used in this draft plan:
- structure trailing starts only after a signal has at least one executed position; pending level-0 signals keep the current entry/activation behavior
- live trailing reads the signal's current context/timeframe structure and ignores `os_market_structures[0]`
- stop/TP management remains 100% local to the EA; do not place broker-side SL/TP levels for this addon
- `TRAILING_BY_STRUCTURE_TP_BE` is interpreted as:
  - only accept a new SL candidate if total signal outcome at that SL would be at least break-even after including already-realized partial profits
  - only accept a new TP candidate if it is at or beyond the signal's initial TP objective
- the TP partial-close percent is interpreted as a percent of the original total signal exposure on each TP event, so `25%` means up to four TP events with the last event closing the remaining exposure
- TP anchor policy is:
  - non-grid signal: use the first resolved TP of the signal when level `0` is executed
  - grid signal: use the original TP of the currently active grid level
- monotonic trailing progression is:
  - bullish: new SL candidates must advance upward relative to the prior accepted SL level and new TP candidates must advance upward from newer peak extrema
  - bearish: inverse of bullish

## Prerequisites
- Keep the ordered include pipeline unchanged:
  `services/license_service_setup.mqh` -> `services/trading_tools.mqh` -> `services/trading_management.mqh` -> `services/trading_management_strategies.mqh` -> `services/trading_signals.mqh` -> `services/frontend.mqh`
- Follow repo conventions:
  2-space indentation, snake_case variables, CamelCase functions, explicit constructors, copy constructors for copied structs, no C++11 features.
- Preserve the functional flow:
  inputs -> indicators -> filters -> signal detection -> grid plan -> order lifecycle -> protection -> frontend
- Use the strict project test runner:
  `./scripts/run_mql5_tests.sh --compile-only`
  `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
- Keep stop/TP handling local to the EA and use broker operations only for actual closes.
  Inference from current code plus official MQL5 docs:
  partial and full closes should stay ticket-specific because symbol-wide helpers are unsafe when multiple same-symbol positions exist in hedging mode.
- Confirm the final addon SKU/display name before implementation.
  Working placeholder in this plan:
  `addon_structure_trailing`

## Sprint 1: Freeze the Product Contract and Runtime State
**Goal**: land an inert, compile-safe feature contract with explicit enum/input definitions and per-signal state placeholders.
**Demo/Validation**:
- Default input profile behaves exactly as today.
- New inputs compile, sanitize cleanly, and do not request an addon while the mode is `TRAILING_OFF`.
- No active-signal behavior changes yet.

### Task 1.1: Add the New Trailing Enum and Input Group
- **Location**:
  `services/core/enums.mqh`
  `services/trading_management/ea_inputs.mqh`
- **Description**:
  Add a new trailing mode enum for the three requested modes and a new MT5 input group for:
  - trailing mode
  - trailing TP partial-close percent

  Keep defaults inert:
  - mode defaults to `TRAILING_OFF`
  - percent defaults to `100.0` only if product wants full TP behavior by default, otherwise `0.0`; this needs final product confirmation before implementation
- **Dependencies**: none
- **Acceptance Criteria**:
  - Input declarations are centralized in `ea_inputs.mqh`
  - Enum names match the requested product language
  - No existing behavior changes when mode is off
- **Validation**:
  - Compile-only pass
  - Repository search shows all new enum values referenced from one source of truth

### Task 1.2: Add Sanitized Runtime Accessors for the New Inputs
- **Location**:
  `services/trading_management/trailing_structure_context.mqh` (new)
  `services/trading_management.mqh`
- **Description**:
  Add a small runtime helper layer that normalizes raw inputs into one contract:
  - effective trailing mode
  - TP partial-close percent clamped to `[0.0, 100.0]`
  - helper predicates such as:
    - trailing enabled
    - TP/BE mode enabled
    - TP partials enabled

  This keeps later signal logic out of `ea_inputs.mqh` and avoids repeated ad hoc clamps.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Invalid percent values are clamped once
  - Disabled mode short-circuits all later feature hooks
  - The new helper is inserted into the ordered management aggregator without sibling includes
- **Validation**:
  - Add/update lightweight unit tests for clamping and enablement behavior

### Task 1.3: Extend Signal and Grid State for Per-Signal Trailing
- **Location**:
  `services/trading_signals/signal_params_struct.mqh`
- **Description**:
  Extend `SignalParams` and, if needed, `GridOrderState` so each running signal can track its own structure-trailing lifecycle. The plan should reserve fields for:
  - initial stop/TP anchors used as immutable references
  - current trailing SL and trailing TP
  - last consumed SL extremum timestamp / identity
  - last consumed TP extremum timestamp / identity
  - realized closed volume / remaining volume
  - cumulative realized PnL for the signal
  - last partial-close event timestamp or identity to prevent duplicate TP processing
  - original total signal exposure used to compute fixed TP slices from the initial configured percent
  - protected break-even metadata for signal-level BE checks after partial closes

  Update constructors and copy constructors so the running-signal arrays remain safe.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - New state is fully initialized in constructors
  - Copy constructor remains correct for array-based signal storage
  - The state model can support multiple concurrent signals without global shared trailing variables
- **Validation**:
  - Compile-only pass
  - New state tests verify copy/assignment does not drop trailing fields

### Task 1.4: Define the Addon/Product Naming Contract
- **Location**:
  `docs/plans/stochastic-structure-trailing-addon-plan.md`
  `docs/addons/README.md`
  `services/shared/license_guard_v1/core/addon_catalog.mqh`
- **Description**:
  Freeze the working product name, display label, and SKU format before implementation starts. The repo currently uses human-readable addon labels plus normalized keys; this feature needs the same pattern.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - One working slug/SKU is used across the implementation plan
  - No duplicate or conflicting addon name is introduced
- **Validation**:
  - Review before Sprint 4 coding starts

## Sprint 2: Build the Pure Structure-Trailing Engine
**Goal**: implement deterministic helpers that convert live closed extrema into next SL/TP trailing candidates without mutating broker positions yet.
**Demo/Validation**:
- Mock-data tests can resolve new trailing SL/TP candidates from synthetic structure arrays.
- The helper ignores `[0]` and only reacts to newer closed extrema.
- Bullish and bearish cases produce mirrored behavior.

### Task 2.1: Create a Dedicated Structure-Trailing Service
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh` (new)
  `services/trading_signals.mqh`
- **Description**:
  Add a new signal-layer service that owns all pure trailing decisions:
  - resolve the live structure snapshot for a signal context
  - read only closed extrema from `os_market_structures[1+]`
  - detect whether a new trailing structure has appeared since the signal last processed one
  - reject stale or already-consumed extrema by timestamp/identity
  - resolve next SL candidate and next TP candidate per direction:
    - bullish:
      - bottom -> SL
      - peak -> TP
    - bearish:
      - peak -> SL
      - bottom -> TP

  Insert the file through the `services/trading_signals.mqh` aggregator instead of sibling includes.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Helper logic is side-effect free
  - It supports both directions from one generalized code path
  - It fails cleanly when the structure depth is insufficient
  - It enforces strict monotonic progression so bullish levels only ratchet upward and bearish levels only ratchet downward
- **Validation**:
  - New helper tests with synthetic `StochasticMarketStructure` payloads

### Task 2.2: Encode the TP/BE Variant Rules as Explicit Predicates
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Implement the `TRAILING_BY_STRUCTURE_TP_BE` branch as explicit rule helpers, not scattered inline checks. Proposed helper boundaries:
  - `CanAdvanceTrailingStopToBreakEven(...)`
  - `CanAdvanceTrailingTpBeyondInitialTarget(...)`
  - `ApplyTrailingModeRules(...)`
  - `ResolveTrailingTpAnchorForSignal(...)`
  - `ResolveNetBreakEvenForSignalAtPrice(...)`

  Keep the inferred interpretation explicit in code comments so it can be corrected easily if product clarification changes the rule.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Plain `TRAILING_BY_STRUCTURE` accepts every newer qualifying extremum
  - `TRAILING_BY_STRUCTURE_TP_BE` rejects candidates that do not preserve the required BE/initial-TP guarantees
  - Rejected candidates leave the current trailing levels unchanged
  - Break-even evaluation includes already-realized partial profits plus the projected close of the remaining exposure at the candidate SL
- **Validation**:
  - Unit tests for pass/reject cases in both bullish and bearish flows

### Task 2.3: Add Partial-Close Volume Math as a Pure Helper
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh`
  `services/utils/broker_constraints_helper.mqh` (only if reusable rounding helpers are needed)
- **Description**:
  Add pure helpers that determine:
  - close volume for a TP partial event based on configured percent
  - remaining volume after the partial
  - configured slice size from the original total signal exposure
  - deterministic distribution of the requested close volume across open grid tickets
  - volume rounding against broker `min/step/max`
  - when a requested partial should collapse into full close because the remainder falls under minimum tradable size

  Keep this math separate from actual `CTrade`/broker calls.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - `0%` yields no TP-side close request
  - `100%` yields full close
  - `25%` yields four equal target slices from the original signal exposure, with the last hit closing the remainder
  - one deterministic ticket-allocation policy is documented and tested
  - intermediate percentages respect broker volume step and minimum volume
  - rounding behavior is deterministic and testable
- **Validation**:
  - New pure tests for `0`, `25`, `50`, `100`, and min-volume edge cases

### Task 2.4: Define the Grid Partial-Close Allocation Policy
- **Location**:
  `services/trading_signals/structure_trailing_manager.mqh`
  `services/trading_signals/grid_order_lifecycle.mqh`
- **Description**:
  Freeze one deterministic way to apply a signal-level partial close across multiple open grid tickets. Recommended default:
  - consume the requested partial-close volume from the most profitable currently open tickets first, then continue until the signal-level target close volume is satisfied

  Reasoning:
  - this better locks in realized gains on reversal-sensitive grids,
  - it keeps the implementation simpler than true proportional slicing,
  - it works naturally with the requirement that the eventual trailing SL can still land at signal-level break-even after including realized partial profits.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - Allocation order is deterministic
  - Allocation never closes tickets from another signal
  - Remaining signal exposure is updated correctly after multi-ticket partial execution
- **Validation**:
  - Unit tests with 2-4 mock open tickets and mixed entry prices

### Task 2.5: Avoid Per-Signal Rebuilding of the Same Structure Snapshot
- **Location**:
  `services/trading_signals/market_signal_state.mqh`
  `services/trading_signals/market_signal_indicators.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Add a lightweight context-level cache or one-pass snapshot loading pattern for active trailing evaluation. The goal is to avoid reinitializing the same stochastic structure snapshot separately for every running signal on the same bar/tick cycle.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Active trailing evaluation does not call into structure initialization redundantly for N same-context signals
  - Cache invalidation is tied to structure timestamp or bar progression
- **Validation**:
  - Code review of snapshot-loading paths
  - Manual debug logs showing one snapshot resolution per context cycle

## Sprint 3: Integrate Trailing into the Active Signal Lifecycle
**Goal**: make the addon manage real running signals, partial closes, and signal completion semantics without breaking the current grid engine.
**Demo/Validation**:
- Disabled mode is a no-op.
- Executed signals update their SL/TP trail from closed structure changes.
- TP events can partially close while leaving the remaining signal alive.
- Signal close/outcome accounting remains coherent after partial exits.

### Task 3.1: Wire Structure Trailing into Active Signal Updates
- **Location**:
  `services/trading_signals/grid_order_controller.mqh`
  `services/trading_signals/tick_signals_manager.mqh`
  `services/trading_signals/structure_trailing_manager.mqh`
- **Description**:
  Insert a new trailing-management step into the running-signal lifecycle. The update should:
  - run only when the addon is enabled
  - run only for signals with at least one executed/opened position
  - apply new structure-derived trailing SL/TP candidates
  - avoid reprocessing the same structure event twice
  - persist consumed TP and SL extremum timestamps separately

  Keep the current entry-pending stop activation logic intact for non-executed signals.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Pending entries still use current activation rules
  - Executed signals can advance their trailing state independently
  - Multiple running signals of the same direction do not overwrite each other
- **Validation**:
  - Integration tests covering at least two concurrent bullish signals and two concurrent bearish signals

### Task 3.2: Add Ticket-Based Partial and Full Close Helpers
- **Location**:
  `services/trading_signals/grid_order_lifecycle.mqh`
  `services/trading_signals/grid_order_helpers.mqh`
- **Description**:
  Extend broker action helpers so a signal can:
  - fully close all its tickets on trailing SL
  - partially close only the tickets attached to that signal on trailing TP
  - avoid symbol-wide ambiguity when multiple same-symbol positions exist

  Use stored `position_ticket` and signal-owned comments as the identity boundary. Do not rely on symbol-only overloads for operations that can touch multiple tickets. Keep SL/TP decision logic local to the EA; broker calls are only the execution mechanism for `PositionClosePartial` / full closes after a local trigger fires.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Partial close affects only the intended signal tickets
  - Full close still works for protection and manual shutdown flows
  - Broker action failures surface through existing logging/error channels
  - Re-visiting the same TP extremum cannot trigger another partial close
- **Validation**:
  - Focused lifecycle tests with mockable close helpers where possible
  - Manual tester smoke if broker interaction cannot be fully unit-tested

### Task 3.3: Redefine Signal Completion and Remaining-Exposure State
- **Location**:
  `services/trading_signals/signal_params_struct.mqh`
  `services/trading_signals/grid_order_lifecycle.mqh`
  `services/trading_signals/grid_order_controller.mqh`
- **Description**:
  Update signal completion logic so a signal is considered closed only when its remaining exposure is fully flat. This requires revisiting:
  - `GridCloseAllLevels(...)`
  - `IsGridSignalComplete(...)`
  - any helper that assumes TP means immediate full close

  Preserve compatibility with current non-addon behavior.
- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - Signals remain active after a partial TP if volume remains open
  - Signals fully close on trailing SL or final TP exhaustion
  - Existing non-addon full-close behavior remains unchanged
- **Validation**:
  - Lifecycle tests for partial-then-stop and partial-then-final-TP paths

### Task 3.4: Replace Approximate Signal Outcome Accounting with Realized Tracking
- **Location**:
  `services/trading_signals/tick_signals_manager.mqh`
  `services/trading_signals/protection_risk_filter.mqh`
  `services/trading_signals/signal_lot_strategy.mqh`
  `services/trading_signals/signal_params_struct.mqh`
- **Description**:
  Stop deriving signal outcome purely from `entry_price -> close_price`. Add explicit realized PnL accumulation so:
  - each partial close contributes realized profit/loss
  - final signal outcome uses cumulative realized value plus any final close component
  - daily signal limits and signal lot-sequence logic remain meaningful after partial exits
- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - Partial-close signals produce accurate `raw_profit`
  - Protection-risk forced closes still register a final outcome
  - Outcome tracking stays backward compatible when the addon is off
- **Validation**:
  - New accounting tests for:
    - one-shot full close
    - one partial TP + final SL
    - multiple partial TPs + final close

### Task 3.5: Update Visualization and Diagnostics for Trailing State
- **Location**:
  `services/frontend/grid_visualization.mqh`
  `services/frontend/grid_visual_utils.mqh`
  `services/trading_signals/grid_order_logging.mqh`
- **Description**:
  Make the active trailing state inspectable:
  - show or repurpose chart lines for current trailing stop and trailing TP
  - ensure those frontend objects follow every accepted structure trailing update
  - reflect consumed TP/SL structure advancement clearly enough to debug why a level did or did not move
  - log structure-driven updates and partial-close events
  - keep output concise behind `Enable_Logs` / `Enable_File_Logs`

  The current frontend already has object naming for `STOP`, but the stop line is not actively rendered from the live signal state.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Users can tell where the active trailing stop and TP are
  - Logs expose why a trailing update or partial close happened
  - No UI spam when chart UI is disabled
- **Validation**:
  - Manual chart verification in tester
  - Compile-only pass

## Sprint 4: Ship the Addon Surface, Docs, and Regression Coverage
**Goal**: finish the feature as a licensed addon with docs, tests, and regression gates aligned to repo standards.
**Demo/Validation**:
- Enabled input profile requests exactly one new addon entitlement.
- Addon docs and product copy match runtime rules.
- Strict compile gate and fast smoke run remain clean.

### Task 4.1: Add the New Addon Key Everywhere the Catalog Exists
- **Location**:
  `services/shared/license_guard_v1/core/addon_catalog.mqh`
  `services/shared/license_guard_v1/license_guard_online.mqh`
  `services/shared/license_guard_v1/backend-entitlements-contract.md`
- **Description**:
  Add the new addon key, display label, and backend-facing contract references in every current source-of-truth location that lists add-ons.
- **Dependencies**: Sprint 1 naming decision
- **Acceptance Criteria**:
  - Catalog and online-license fallback macros stay in sync
  - Backend contract doc lists the new addon consistently
  - UI display labels render correctly
- **Validation**:
  - Addon label tests
  - Repository-wide search shows one consistent key string

### Task 4.2: Extend Runtime Addon Policy and Coverage
- **Location**:
  `services/trading_management/addon_runtime_policy.mqh`
  `tests/harness/cases/addon_runtime_policy_test_case.mqh`
- **Description**:
  Request the new addon when the trailing mode is anything other than `TRAILING_OFF`. Keep the rule simple:
  - mode off -> no addon request
  - any trailing mode on -> request the new addon

  The partial-close percent alone must not request the addon if the mode is off.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Default profile still requests zero paid addons
  - Enabled profile requests exactly the new addon
  - No duplicate keys are emitted
- **Validation**:
  - Update `addon_runtime_policy_test_case.mqh`

### Task 4.3: Add User-Facing Addon Docs and Product Copy
- **Location**:
  `docs/addons/README.md`
  `docs/addons/structure-trailing.md` (new, final slug may change after SKU confirmation)
  `docs/product_copy/en/addon-structure-trailing.md` (new)
  `docs/product_copy/es/addon-structure-trailing.md` (new)
- **Description**:
  Document:
  - the addon SKU
  - the new enum modes
  - the trailing TP partial-close percent input
  - the entitlement trigger rule
  - examples for bullish and bearish trailing
  - examples for `0%`, `25%`, and `100%`
  - missing-addon behavior outside Strategy Tester
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - Addon guide and product copy match actual runtime behavior
  - `docs/addons/README.md` includes the new addon in the matrix
- **Validation**:
  - Manual doc review against code behavior

### Task 4.4: Add the Test Matrix for Trailing Logic, Lifecycle, and Addon Policy
- **Location**:
  `tests/harness/cases/structure_trailing_logic_test_case.mqh` (new)
  `tests/harness/cases/structure_trailing_lifecycle_test_case.mqh` (new)
  `tests/harness/cases/structure_trailing_accounting_test_case.mqh` (new)
  `tests/structure_trailing_logic_test.mq5` (new)
  `tests/structure_trailing_lifecycle_test.mq5` (new)
  `tests/structure_trailing_accounting_test.mq5` (new)
  `tests/hft_grid_ai_tests_harness.mq5`
- **Description**:
  Cover:
  - bullish trailing by newer closed bottoms/peaks
  - bearish trailing by newer closed peaks/bottoms
  - ignore `[0]` and duplicate structure events
  - consumed extremum timestamps prevent repeated TP/SL actions on the same structure
  - bullish SL/TP levels only ratchet upward and bearish levels only ratchet downward
  - TP/BE mode accept/reject behavior
  - partial-close percent math and broker rounding
  - signal-level BE accounting includes realized partial profits
  - multiple concurrent signals with independent trailing state
  - default no-op behavior when the addon is off
  - addon runtime policy for the new entitlement
- **Dependencies**: Sprint 2 and Sprint 3
- **Acceptance Criteria**:
  - Tests remain mock-data driven
  - Wrappers stay thin and harness is the single runtime orchestrator
  - Coverage includes both pure helpers and integrated lifecycle paths
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`

### Task 4.5: Run Final Regression Gates
- **Location**:
  `scripts/run_mql5_tests.sh`
  `logs/test-runner/latest/summary.log`
  `logs/test-runner/latest/compile/*.metaeditor.log`
  `logs/test-runner/latest/runtime/*.terminal.log`
  `logs/test-runner/latest/runtime/*.mql.log`
- **Description**:
  Run the repo-standard two-step validation flow:
  1. `./scripts/run_mql5_tests.sh --compile-only`
  2. `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
- **Dependencies**: Sprint 4 complete
- **Acceptance Criteria**:
  - No warnings or errors in compile gate
  - Harness emits clean pass/fail markers
  - New addon tests pass alongside existing signal/grid tests
- **Validation**:
  - Review only the repo-standard latest logs

## Testing Strategy
- Prefer pure helper tests for:
  - structure-event resolution
  - TP/BE gating
  - partial-close volume math
  - realized-PnL accounting math
- Add lifecycle integration tests for:
  - first execution then trailing activation
  - one partial TP then trailing SL close
  - repeated trailing TP events
  - multiple concurrent same-direction signals
- Preserve and rerun existing tests related to:
  - grid order lifecycle
  - addon runtime policy
  - signal lot sequence logic
  - structure Fibonacci orientation/range helpers
- Validate disabled-addon behavior explicitly so the base EA profile stays unchanged

## Potential Risks & Gotchas
- **Partial exits break the current profit model**:
  without explicit realized-PnL tracking, daily signal limits and lot-sequence logic will misclassify outcomes.
- **Signal-level BE is not just a price comparison**:
  after partial closes, the protected break-even condition must include realized partial profits plus the projected close of the remaining exposure.
- **Current engine is virtual, not broker-SL/TP driven**:
  mixing structure trailing into the current design must keep one source of truth for stop/TP state, and that source should remain local EA state rather than broker-side stop/TP placement.
- **`os_market_structures[0]` is mutable**:
  using it would cause unstable trailing levels and duplicate event processing.
- **Extremum consumption must be tracked separately for TP and SL**:
  otherwise one side can incorrectly block the other or repeated revisits can retrigger closes.
- **Hedging vs netting matters**:
  multi-position grids imply ticket-aware operations; symbol-wide modify/close helpers are unsafe for this addon when several same-symbol positions exist.
- **Trailing update frequency can become expensive**:
  reloading the same stochastic snapshot once per running signal per tick will not scale well; cache by context/timestamp.
- **TP anchor rules differ between non-grid and grid flows**:
  tests must lock the non-grid and active-grid-level anchor behaviors independently to avoid silent regressions.
- **Frontend line semantics need a small redesign**:
  the current chart code draws `ENTRY`, `TP`, and `NEXT`, but not an active trailing stop from the live signal state.

## Rollback Plan
- Remove the new trailing enum and input group.
- Remove the trailing runtime-context helper and the structure-trailing signal service.
- Remove the new addon key from runtime policy and addon catalogs.
- Revert lifecycle/accounting changes back to the current full-close-only behavior.
- Delete the new trailing test wrappers/cases and addon docs.
- Re-run `./scripts/run_mql5_tests.sh --compile-only` to verify the baseline is restored.
