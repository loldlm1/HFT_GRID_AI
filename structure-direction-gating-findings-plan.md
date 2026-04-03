# Plan: Structure Direction Gating Findings

**Generated**: 2026-04-03
**Estimated Complexity**: Medium

## Overview
The new `query_debug.txt` shows a clear semantic drift from the EA's intended behavior: bullish Fibonacci structure signals are still being initialized while `current_is_bottom=false`, which means the active structure orientation is peak-led even though the strategy intent is to keep bullish entries aligned to bottom-led structures and bearish entries aligned to peak-led structures.

This plan does not change code yet. It defines the research and implementation shape needed to restore the direction contract without breaking the already-fixed Fibonacci entry anchoring, limit-entry progression, breakout handling, touch policy behavior, or compact debug logging.

The current evidence is strong enough to treat this as an upstream signal-eligibility problem, not a grid-planning problem:
- `logs/query_debug.txt` shows multiple bullish `SIGNAL_INIT` and `LEVEL_CONTEXT` lines with `current_is_bottom=false`
- `services/trading_signals/market_signal_filters.mqh` currently resolves structure range and Fibonacci entry math for both orientations, but it does not reject an orientation that is semantically opposite to the requested signal direction
- `services/trading_signals/market_signal_detection.mqh` accepts `entry_allows` from the filter layer directly, so once the filter layer returns `in_zone=true`, the signal is allowed to become tradable

## Prerequisites
- Keep the current Fibonacci source-of-truth implementation intact while this work is investigated.
- Treat the existing `query_debug.txt` evidence as the baseline repro artifact:
  - bullish signal with `current_is_bottom=false` at [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt#L9)
  - same issue repeated at [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt#L20)
  - contrast with bottom-led bullish cases at [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt#L26) and [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt#L55)
- Preserve the current EA goal behavior:
  - bullish structure entries should be bottom-led
  - bearish structure entries should be peak-led
  - Fibonacci anchoring should stay explicit and non-ambiguous

## Sprint 1: Lock The Direction Contract
**Goal**: Convert the current intuition into an explicit code-level contract so the eventual fix is narrow and testable.
**Demo/Validation**:
- The contract identifies which structure orientation is valid for each signal direction.
- The plan distinguishes signal eligibility from grid lifecycle behavior.

### Task 1.1: Define The Orientation Contract At The Signal Layer
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**:
  Document the intended eligibility contract in terms the code already exposes:
  - bullish structure entries are only valid when `current_is_bottom=true`
  - bearish structure entries are only valid when `current_is_bottom=false`

  Make this contract explicit before touching any Fibonacci traversal logic so the eventual change does not get buried inside grid helpers.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The contract is stated in the plan and maps directly to existing code concepts.
  - The scope is clearly signal eligibility, not next-level progression.
- **Validation**:
  - Manual review of `ResolveStructureReferenceRange(...)`
  - Manual review of `StrategyContextEvaluateEntryDetailed(...)`

### Task 1.2: Identify The Earliest Safe Gate
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Trace where the new direction/orientation gate should live with the least collateral impact. The likely candidates are:
  - immediately after `ResolveStructureReferenceRange(...)`
  - before `close_percent` / `extreme_percent` are used to resolve `in_zone`
  - after entry resolution but before `entry_allows=true`

  The preferred design should fail early enough to keep logs and tests simple, while not bypassing other filters that still need to run for observability.
- **Dependencies**:
  - Task 1.1
- **Acceptance Criteria**:
  - One gate location is selected as the source of truth.
  - The plan explains why other candidate locations are weaker.
- **Validation**:
  - Reasoning against the current call chain:
    - `ResolveStructureReferenceRange(...)`
    - `ResolveStructureFibonacciEntryForPricesDetailed(...)`
    - `StrategyContextEvaluateEntryDetailed(...)`
    - `EvaluateContextSignals(...)`

### Task 1.3: Decide Scope Across Trigger Modes
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - `tests/harness/cases/*`
- **Description**:
  Confirm whether the direction/orientation gate applies to all structure-trigger entry modes, or only to the current Fibonacci structure path. The default assumption should be:
  - apply to all structure-trigger entries that depend on `ResolveStructureReferenceRange(...)`
  - keep breakout anchoring math intact, but do not let breakout semantics bypass the direction gate unless the strategy explicitly wants reversal entries
- **Dependencies**:
  - Task 1.1
- **Acceptance Criteria**:
  - The plan names the intended scope explicitly.
  - Breakout logic is called out as a risk area, not silently changed.
- **Validation**:
  - Review `ResolveEffectiveStructureTriggerMode(...)`
  - Review `StructureBreakoutLimitAnchoringEnabled(...)`

## Sprint 2: Design The Minimal Behavioral Fix
**Goal**: Shape the fix so it restores the intended direction semantics without undoing the recent Fibonacci improvements.
**Demo/Validation**:
- A bullish signal on peak-led structure is rejected before it reaches `SIGNAL_INIT`.
- A valid bottom-led bullish signal still behaves the same.

### Task 2.1: Add A Direction-Orientation Eligibility Check
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Add a small, explicit helper for orientation eligibility rather than embedding direction rules inline. The helper should accept:
  - `SignalTypes direction`
  - `bool current_is_bottom`

  and return whether the structure orientation is valid for signal creation.

  The main implementation goal is clarity:
  - bullish + `current_is_bottom=false` => reject
  - bearish + `current_is_bottom=true` => reject
- **Dependencies**:
  - Sprint 1 complete
- **Acceptance Criteria**:
  - The gate is readable and isolated.
  - No grid or order-lifecycle code needs to understand this rule.
- **Validation**:
  - Compile-only harness remains clean.

### Task 2.2: Preserve Existing Fibonacci Entry Source Of Truth
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/grid_order_helpers.mqh`
- **Description**:
  Ensure the direction gate happens without disturbing the stored resolved Fibonacci entry anchor. If a signal is eligible, it should still preserve:
  - actual entry price
  - resolved configured entry percent
  - resolved configured entry price

  This is a compatibility task, not a new feature.
- **Dependencies**:
  - Task 2.1
- **Acceptance Criteria**:
  - The signal-creation path still carries the same anchor fields for valid signals.
  - The recent `61.8 -> 100.0` fixes remain untouched in intent.
- **Validation**:
  - Re-check the existing Fibonacci regression cases after the gate is in place.

### Task 2.3: Reject Invalid Orientation Before Signal Registration
- **Location**:
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**:
  Confirm that invalid-orientation signals are stopped before:
  - `BuildGridOrderForSignal(...)`
  - `AddElementToArray(...)`
  - fresh-structure usage registration

  This prevents invalid structures from polluting lifecycle logs or consuming structure slots.
- **Dependencies**:
  - Task 2.1
- **Acceptance Criteria**:
  - Invalid-orientation signals do not produce `SIGNAL_INIT`.
  - Valid signals keep the current lifecycle behavior.
- **Validation**:
  - Manual query-debug inspection after targeted repro.

## Sprint 3: Make The Logs And Tests Prove The Contract
**Goal**: Ensure the next debugging cycle can verify direction correctness quickly and without noisy inference.
**Demo/Validation**:
- `query_debug.txt` clearly shows why a candidate signal was accepted or rejected.
- Harness coverage proves the orientation contract directly.

### Task 3.1: Add Compact Direction-Gate Logging
- **Location**:
  - `services/trading_signals/grid_order_logging.mqh`
  - `services/trading_signals/market_signal_filters.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**:
  Add one compact signal-evaluation log for rejected structure orientation cases. The log should capture only:
  - signal direction
  - `current_is_bottom`
  - peak/bottom prices when useful
  - reject reason token such as `STRUCTURE_DIRECTION_MISMATCH`

  Keep the output sparse. The objective is one decisive line per rejected candidate, not a verbose trace.
- **Dependencies**:
  - Sprint 2 complete
- **Acceptance Criteria**:
  - A rejected bullish-on-peak candidate is visible in `query_debug.txt` without requiring chart inspection.
  - No repeated `GRID_PLAN_BASE` noise is reintroduced.
- **Validation**:
  - Manual review of a targeted repro log.

### Task 3.2: Add Deterministic Orientation Eligibility Tests
- **Location**:
  - `tests/harness/cases/structure_fibonacci_orientation_test_case.mqh`
  - `tests/harness/cases/structure_fibonacci_entry_levels_test_case.mqh`
  - `tests/harness/cases/structure_entry_trigger_test_case.mqh`
  - `tests/harness/cases/support_resistance_signal_gate_test_case.mqh`
- **Description**:
  Add direct tests that prove:
  - bullish entry is rejected when `current_is_bottom=false`
  - bearish entry is rejected when `current_is_bottom=true`
  - valid-orientation cases still resolve entries normally
  - the stored Fibonacci entry anchor still behaves correctly for valid signals
- **Dependencies**:
  - Task 3.1
- **Acceptance Criteria**:
  - Tests express the direction contract directly, not indirectly through later grid behavior.
  - Existing valid Fibonacci semantics remain covered.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --fast --symbols XAUUSD,EURUSD`

### Task 3.3: Run A Focused Query-Debug Validation
- **Location**:
  - `logs/query_debug.txt`
  - `logs/test-runner/latest/runtime/*.mql.log`
- **Description**:
  Run one focused repro with the same compact query-debug mode and verify:
  - previous invalid bullish-on-peak cases no longer reach `SIGNAL_INIT`
  - valid bullish-on-bottom cases still initialize and progress
  - the recent Fibonacci anchor fields remain readable and consistent
- **Dependencies**:
  - Task 3.2
- **Acceptance Criteria**:
  - The invalid cases from the current XAUUSD log disappear from `SIGNAL_INIT` / `LEVEL_CONTEXT`.
  - Valid cases still show coherent `resolved_entry_pct`, `resolved_entry_price`, and `logical_next_pct`.
- **Validation**:
  - Manual review of refreshed `query_debug.txt`

## Testing Strategy
- Keep the strict compile gate as the first pass:
  - `./scripts/run_mql5_tests.sh --compile-only`
- Use a focused fast smoke on the symbols already involved in recent findings:
  - `./scripts/run_mql5_tests.sh --fast --symbols XAUUSD,EURUSD`
- Treat these as the minimum regression set:
  - `structure_fibonacci_orientation_test`
  - `structure_fibonacci_entry_levels_test`
  - `structure_entry_trigger_test`
  - `support_resistance_signal_gate_test`
  - `fibonacci_grid_percent_test`
- Validate one compact `query_debug.txt` repro after code and tests pass.

## Potential Risks & Gotchas
- `current_is_bottom` is a structure-orientation flag, not a full market-trend verdict. The fix should use it only for the entry-direction contract it actually represents.
- If breakout modes intentionally support reversal-style entries in some contexts, a universal direction gate may be too broad. That needs to be decided explicitly instead of assumed.
- Rejecting earlier in the pipeline may affect fresh-structure usage, retest-chain accounting, or touch-policy progress if those paths currently rely on entry evaluation side effects.
- Existing tests may encode the current permissive behavior implicitly. Expect some test updates to be legitimate behavior corrections, not regressions.
- The logging fix must stay compact. The goal is one decisive rejection line, not a new noisy trace category.

## Rollback Plan
- Remove the new orientation eligibility gate and restore the current permissive signal-entry behavior.
- Keep the Fibonacci entry source-of-truth changes isolated so they do not need to be reverted with the direction-gating work.
