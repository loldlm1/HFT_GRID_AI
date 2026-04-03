# Plan: EURUSD Immediate Close Patch Findings

**Generated**: 2026-04-02
**Estimated Complexity**: Medium

## Overview
This is a no-code findings plan based on the new `logs/query_debug.txt` only. A working comparison case is not required here because the failing lifecycle is already explicit and internally consistent in the current log.

The close chain is:

1. `SIGNAL_INIT`
2. `LEVEL_REACHED`
3. `NEXT_LEVEL_TRIGGER`
4. `STOP_LIMIT_DECISION`
5. `LEVEL_CLOSE_ALL`
6. `GRID_STOP_LEVEL_LIMIT`

The evidence now points to a specific defect shape:

- the stop-limit close is behaving as designed
- the bad state is that the first "next level" is effectively the same price as the executed entry
- that degenerate next level comes from the current Fibonacci `FIB_LEVEL_RANGE + LEVELS_AS_LIMITS` planning and trigger path

## Evidence Snapshot

### Log Evidence
- `logs/query_debug.txt:9`
  `SIGNAL_INIT ... entry_ref=1.09159|next=1.09159`
- `logs/query_debug.txt:10`
  `LEVEL_CONTEXT ... entry_pct=61.70|level_pct=61.80|fib_price=1.09159|next=1.09159`
- `logs/query_debug.txt:17`
  `LEVEL_REACHED ... entry=1.09159`
- `logs/query_debug.txt:18`
  `NEXT_LEVEL_TRIGGER ... entry_side=1.09159|next=1.09159|entry_ref=1.09159`
- `logs/query_debug.txt:20`
  `STOP_LIMIT_DECISION ... stop_limit=1|blocked=true|action=CLOSE_ALL`

### Code Evidence
- [grid_order_lifecycle.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_lifecycle.mqh#L129)
  `GridShouldActivateNextLevelLimit(...)` triggers immediately when current entry-side price already satisfies `next_level_price`.
- [grid_order_controller.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_controller.mqh#L257)
  once next-level is triggered, the controller applies stop-limit logic right away.
- [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L249)
  `Grid_Level_Stop_Limit=1` intentionally blocks progression at display level `L1`.
- [grid_planner.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_planner.mqh#L389)
  the planner stores `grid_base_distance_points` and `fib_level_offset_steps` from `CalculateBaseGridContext(...)`.
- [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L861)
  `ResolveFibonacciGridBaseDistance(...)` uses different distance-selection rules by trigger mode.
- [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L295)
  `GetGridNextLevelPrice(...)` later returns the raw Fibonacci next price for `FIB_LEVEL_RANGE`.

## Confirmed Findings

### Finding 1: This is not a session, DST, protection, or spread guard close
- **Evidence**:
  - The close chain in `query_debug.txt` is entirely grid-lifecycle driven.
  - There is no session-force-close or protection-close event in the failing slice.
  - Spread is `6.0` points with `Max_Spread=20.0`.
- **Impact**:
  - The Exness DST work is not the direct cause in this case.

### Finding 2: The controller and stop-limit helper are behaving consistently with current semantics
- **Evidence**:
  - [grid_order_controller.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_controller.mqh#L257) closes all levels when a next-level trigger occurs and the stop limit is hit.
  - [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L249) returns `true` for `Grid_Level_Stop_Limit=1` at display level `L1`.
- **Interpretation**:
  - Once the next-level trigger fires, the close is expected behavior.
- **Impact**:
  - The stop-limit helper is probably not the primary bug source.

### Finding 3: The immediate close is caused by a degenerate next-level trigger
- **Evidence**:
  - `SIGNAL_INIT`, `LEVEL_CONTEXT`, and `NEXT_LEVEL_TRIGGER` all show `entry_ref=1.09159` and `next=1.09159`.
  - [grid_order_lifecycle.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_lifecycle.mqh#L136) uses `order_state.next_level_price` directly as the trigger threshold.
  - For bullish signals, equality is enough to satisfy the adverse-move branch.
- **Interpretation**:
  - The "next level" is already considered reached on the first active tick because it has collapsed onto the live entry/reference price.
- **Impact**:
  - This is the proximate cause of the immediate close.

### Finding 4: The degenerate next level originates upstream in the Fibonacci planner, not in the stop-limit code
- **Evidence**:
  - [grid_planner.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_planner.mqh#L429) stores `grid_base_distance_points` and `fib_level_offset_steps`.
  - [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L957) shows the `LEVELS_AS_LIMITS` branch of `ResolveFibonacciGridBaseDistance(...)` takes only the first next Fibonacci step, computes a numeric distance, and then clamps that numeric distance via `EnforceBrokerDistance(...)`.
  - [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L923) only scans forward to a farther Fibonacci step when the trigger mode is `LEVEL_AS_ZONE`.
  - [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L301) later emits the raw step-based Fibonacci price from `ResolveFibonacciGridLevelPrice(...)`.
- **Interpretation**:
  - In `LEVELS_AS_LIMITS`, the planner can keep `fib_level_offset_steps=1` even when the first raw Fibonacci step is too close to the entry to produce a distinct market price.
  - The numeric base-distance bookkeeping can therefore diverge from the actual emitted `next_level_price`.
- **Impact**:
  - This is the strongest upstream defect candidate.

### Finding 5: `base_dist=10.00` in the log is not proof that the next level is valid or distinct
- **Evidence**:
  - `GRID_PLAN_BASE` logs `base_dist=10.00`.
  - [broker_constraints_helper.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/utils/broker_constraints_helper.mqh#L93) shows `EnforceBrokerDistance(...)` raises distances to at least the broker minimum or the fallback minimum.
  - `LEVEL_CONTEXT` still shows the raw Fibonacci `fib_price=1.09159` and `next=1.09159`.
- **Interpretation**:
  - `base_dist=10.00` is distance bookkeeping, not proof that the emitted next-level trigger is 10 points away.
  - The planner can report a safe minimum distance while the raw Fibonacci trigger price still collapses to entry.
- **Impact**:
  - The patch should not assume the logged base distance is enough protection by itself.

### Finding 6: The new log is sufficient for patch planning without a passing control case
- **Evidence**:
  - The failing log now captures inputs, spread, Fibonacci resolution, next-level trigger context, and stop-limit decision.
- **Interpretation**:
  - A passing comparator may still be useful later, but it is no longer required to identify the defect class or choose an initial patch.
- **Impact**:
  - Patch planning can proceed immediately.

## Root Cause Hypothesis
The most defensible current hypothesis is:

1. On some EURUSD structures, the first Fibonacci traversal step from the entry percent is too small to create a distinct 5-digit market price.
2. In `FIB_LEVEL_RANGE + LEVELS_AS_LIMITS`, the planner still keeps `fib_level_offset_steps=1` and later emits that raw next-level price.
3. The controller sees `next_level_price` already equal to the entry/reference price and treats the deeper level as reached immediately.
4. Because `Grid_Level_Stop_Limit=1` is intentionally configured as "close once level 1 reaches the next level," the signal closes on the next tick.

This explains:
- why the failure is symbol-sensitive
- why it can appear only on specific structure snapshots or days
- why it closes almost immediately and near break-even
- why the stop-limit path looks correct even though the final behavior is wrong

## Patch Direction

## Sprint 1: Block the invalid trigger at the lifecycle boundary
**Goal**: Prevent immediate deeper-level activation when the emitted next level is not meaningfully separated from the active level.
**Demo/Validation**:
- The failing EURUSD case no longer produces `NEXT_LEVEL_TRIGGER` immediately after `LEVEL_REACHED`.

### Task 1.1: Add a meaningful-separation guard to next-level activation
- **Location**:
  - [grid_order_lifecycle.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_lifecycle.mqh)
  - possibly [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh)
- **Description**:
  - Before accepting `next_level_price` as a valid trigger, require it to be materially different from the active entry/reference price using point-size-aware logic.
- **Acceptance Criteria**:
  - Equality or effective equality does not trigger next-level activation.
  - The rule remains symbol-agnostic and does not hardcode EURUSD.

### Task 1.2: Keep the threshold minimal
- **Description**:
  - Choose the smallest defensible gap that blocks same-price degeneracy without suppressing legitimate nearby levels.
- **Acceptance Criteria**:
  - The threshold is explicitly tied to symbol precision or point size, not raw double comparison.

## Sprint 2: Align Fibonacci planning with emitted next-level semantics
**Goal**: Remove the planner/trigger mismatch for `FIB_LEVEL_RANGE + LEVELS_AS_LIMITS`.
**Demo/Validation**:
- The stored Fibonacci step and the emitted next price both represent a genuinely distinct next level.

### Task 2.1: Audit the `LEVELS_AS_LIMITS` Fibonacci base-distance rule
- **Location**:
  - [grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L861)
  - [grid_planner.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_planner.mqh#L389)
- **Description**:
  - Decide whether `LEVELS_AS_LIMITS` should also scan forward to the first Fibonacci step that produces a meaningful price gap, instead of always keeping step `1`.
- **Acceptance Criteria**:
  - The domain rule is explicit before patching.

### Task 2.2: Choose patch scope deliberately
- **Options**:
  - lifecycle-only guard
  - planner-side fix to skip degenerate Fibonacci steps
  - both, with lifecycle guard as defense-in-depth
- **Acceptance Criteria**:
  - Prefer the smallest safe fix first.
  - If planner semantics are clearly inconsistent, document why a broader fix is justified.

## Sprint 3: Lock the behavior with deterministic regression tests
**Goal**: Make the failure mode reproducible in the harness.
**Demo/Validation**:
- A deterministic test fails before the patch and passes after it.

### Task 3.1: Add a degeneracy regression case
- **Location**:
  - likely a new or existing harness case under `tests/harness/cases/*`
- **Description**:
  - Build a case where:
    - active level is `L1`
    - `Grid_Level_Stop_Limit=1`
    - `next_level_price` resolves effectively equal to the active entry/reference price
- **Acceptance Criteria**:
  - The controller does not treat this as a valid next-level trigger after the patch.

### Task 3.2: Keep a control case for normal stop-limit behavior
- **Description**:
  - Add a case where the next level is genuinely distinct and confirm that `Grid_Level_Stop_Limit=1` still closes as intended when that real next level is reached.
- **Acceptance Criteria**:
  - The fix blocks only the degenerate case.

## Testing Strategy
- Use the current [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt) as the reference failure artifact.
- Keep the new generalized query logging as part of the debugging baseline.
- After the patch:
  - rerun `--compile-only`
  - rerun the targeted EURUSD non-visual repro
  - confirm the failing lifecycle no longer shows `LEVEL_REACHED -> NEXT_LEVEL_TRIGGER -> STOP_LIMIT_DECISION` on the same price
- Add one harness regression for the degenerate case and one control test for normal stop-limit behavior.

## Potential Risks
- A lifecycle-only guard may hide an upstream planner inconsistency without fixing it.
- A planner-side Fibonacci change may alter legitimate grid spacing behavior on other symbols.
- Any price-gap rule must respect symbol precision and broker constraints instead of raw double equality.

## Rollback Plan
- If the planner-side fix is too invasive, keep only the lifecycle guard plus the new diagnostics.
- If the lifecycle guard suppresses legitimate next levels, revert it and revisit the planner semantics with targeted tests.
