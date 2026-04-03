# Plan: Fibonacci Entry Source Of Truth

**Generated**: 2026-04-02
**Estimated Complexity**: Medium

## Overview
The current Fibonacci fix solved the ambiguous EURUSD `61.7 -> 61.8` rounding case, but it introduced a regression for previously valid signals where a resolved `61.8` limit entry is later reinterpreted as `100.0`, causing the next level to jump to `161.8`. The root problem is that grid traversal is still reconstructing intent from normalized `entry_price` instead of preserving the configured Fibonacci entry level that the signal originally resolved to.

The next implementation should make the resolved configured Fibonacci entry level a first-class value in `SignalParams` and use it as the source of truth for grid progression, labels, and debug logs. The key design rule is: for ordinary `LEVELS_AS_LIMITS`, do not infer the logical entry level later from price when the signal creation path already knew which configured Fibonacci band endpoint was selected.

## Prerequisites
- Keep the current immediate-close safety guard in place while refactoring Fibonacci semantics.
- Preserve existing breakout limit anchoring behavior; this plan targets ordinary non-breakout Fibonacci limit entries.
- Work on top of the current branch state without overwriting existing local edits in:
  - `services/trading_signals/grid_order_helpers.mqh`
  - `services/trading_signals/grid_order_logging.mqh`
  - `services/trading_signals/grid_planner.mqh`
  - `services/trading_signals/market_signal_filters.mqh`
  - `tests/harness/cases/fibonacci_grid_percent_test_case.mqh`

## Sprint 1: Capture Entry Intent
**Goal**: Persist the resolved configured Fibonacci entry level at signal creation time so later grid math does not need to guess it from rounded prices.
**Demo/Validation**:
- A new signal can carry both raw market price and resolved configured Fibonacci entry metadata.
- No traversal code needs to reinterpret a non-breakout limit entry band from price alone.

### Task 1.1: Add Stored Fibonacci Entry Metadata To Signal State
- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**:
  Add explicit fields for the resolved Fibonacci entry source of truth, separating:
  - derived market entry price
  - resolved configured entry percent
  - resolved configured entry price
  - whether the resolved configured Fibonacci entry is valid for the signal

  Keep the fields generic enough to support both ordinary limit entries and breakout anchoring without forcing a later refactor.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `SignalParams` can store resolved configured Fibonacci entry intent without relying on post-hoc price inference.
  - Default constructor and copy constructor both initialize/copy the new fields correctly.
- **Validation**:
  - Strict compile remains clean.
  - Harness compile remains clean.

### Task 1.2: Resolve And Return Fibonacci Entry Intent In Entry Resolution
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Extend the Fibonacci entry resolution path so the same code that currently decides `entry_price_out` also returns the resolved configured Fibonacci entry level for non-breakout limit entries.

  The ordinary limit rule should be:
  - if the entry is resolved from the `61.8` configured level, preserve that exact configured level as the logical entry anchor even if reverse-derived price percent later becomes `61.9`

  Non-goals for this task:
  - do not normalize market-zone entries into configured Fibonacci endpoints
  - do not change breakout limit anchoring semantics
- **Dependencies**:
  - Task 1.1
- **Acceptance Criteria**:
  - `ResolveStructureFibonacciEntryForPrices(...)` can return both the actual entry price and the configured Fibonacci entry source of truth.
  - The function still returns the same observable `entry_price_out` semantics for the current supported entry modes unless explicitly required by the stored configured level contract.
- **Validation**:
  - Existing entry-resolution tests compile.
  - Manual reasoning from `query_debug.txt` reproduces:
    - 2024-01-02 signal should preserve logical entry at `61.8`, not `100.0`
    - 2024-01-03 signal should preserve logical entry at `61.8`, not raw `61.7`

### Task 1.3: Store The Resolved Entry Source Of Truth When Building Signals
- **Location**:
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Wire the newly resolved Fibonacci entry metadata through `StrategyContextEvaluateEntry(...)` into `SignalParams` creation, so the signal owns the logical entry intent from birth.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
- **Acceptance Criteria**:
  - A newly created signal stores both its actual entry price and its resolved configured Fibonacci entry metadata.
  - The source-of-truth values are present before `BuildGridOrderForSignal(...)` runs.
- **Validation**:
  - New signal creation compiles and runs through the harness without introducing initialization errors.

## Sprint 2: Rebase Grid Progression On Stored Entry Intent
**Goal**: Make grid next-level traversal use the stored configured Fibonacci entry metadata instead of reverse-derived price semantics for ordinary non-breakout limit entries.
**Demo/Validation**:
- The January 2-style signal stays `61.8 -> 100.0`.
- The January 3 rounding case also stays `61.8 -> 100.0`.

### Task 2.1: Replace Post-Hoc Canonicalization In Grid Traversal
- **Location**:
  - `services/trading_signals/grid_order_helpers.mqh`
- **Description**:
  Refactor the traversal helpers so non-breakout limit progression uses the stored resolved configured Fibonacci entry percent directly.

  Expected behavior:
  - ordinary limit entries use stored configured entry percent as traversal start
  - breakout entries keep their anchored-opposite-endpoint logic
  - `LEVEL_AS_ZONE` remains governed by its own current semantics

  This task should remove or sharply reduce the need for broad band-based post-hoc “canonical entry” guessing.
- **Dependencies**:
  - Sprint 1 complete
- **Acceptance Criteria**:
  - `ResolveFibonacciGridLevelPercent(...)`, `ResolveFibonacciGridLevelPrice(...)`, and `ResolveFibonacciGridBaseDistance(...)` all read from the same stored configured entry source of truth when appropriate.
  - Ordinary `61.8` limit entries no longer jump to `161.8` just because reverse-derived `entry_pct` rounded to `61.9`.
  - The earlier immediate-close protection remains intact.
- **Validation**:
  - `tests/harness/cases/fibonacci_grid_percent_test_case.mqh`
  - `tests/harness/cases/grid_order_lifecycle_level_stop_limit_test_case.mqh`

### Task 2.2: Decide Whether Entry Price Itself Should Be Snapped Or Only The Logical Anchor
- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - `services/trading_signals/grid_order_helpers.mqh`
  - `services/trading_signals/grid_planner.mqh`
- **Description**:
  Make an explicit implementation choice and document it in code/comments/tests:
  - Option A: keep `entry_price` as the real resolved execution price and only use stored configured entry percent for progression
  - Option B: snap `entry_price` itself to the configured Fibonacci entry price for non-breakout limit entries

  Based on current findings, Option A is the safer default because it preserves actual pricing while still fixing progression semantics.
- **Dependencies**:
  - Task 2.1
- **Acceptance Criteria**:
  - The code clearly distinguishes actual entry price vs logical Fibonacci anchor.
  - No remaining helper silently conflates the two concepts.
- **Validation**:
  - `query_debug.txt` semantics can explain both values without ambiguity.

## Sprint 3: Align Logging And Regression Tests
**Goal**: Make the logs explain the fixed semantics clearly and lock the behavior with deterministic tests.
**Demo/Validation**:
- `query_debug.txt` shows why a signal progressed to its next level without needing visual chart interpretation.
- The regression matrix covers both the old bad case and the old good case.

### Task 3.1: Update Debug Logs To Show Stored Entry Intent Explicitly
- **Location**:
  - `services/trading_signals/grid_order_logging.mqh`
  - `services/trading_signals/grid_planner.mqh`
- **Description**:
  Replace the ambiguous “logical entry” presentation with explicit fields that separate:
  - reverse-derived `entry_pct`
  - resolved configured entry percent
  - resolved configured entry price
  - actual entry price
  - logical next Fibonacci percent
  - emitted next trigger price

  Keep `GRID_PLAN_BASE` change-based only.
- **Dependencies**:
  - Sprint 2 complete
- **Acceptance Criteria**:
  - The January 2-style signal can be read as “actual entry price happened near 61.9, but resolved configured entry level is 61.8, so next level is 100.0.”
  - The January 3-style signal can be read as “raw reverse-derived entry is 61.7, but resolved configured entry level is 61.8, so next level is 100.0.”
- **Validation**:
  - Manual inspection of `query_debug.txt` after a targeted repro.

### Task 3.2: Expand Fibonacci Regression Tests Around Stored Entry Semantics
- **Location**:
  - `tests/harness/cases/fibonacci_grid_percent_test_case.mqh`
  - `tests/harness/cases/structure_fibonacci_entry_levels_test_case.mqh`
  - `tests/harness/cases/structure_entry_trigger_test_case.mqh`
  - `tests/harness/cases/support_resistance_signal_gate_test_case.mqh`
- **Description**:
  Add deterministic tests for:
  - valid non-breakout `61.8` entry whose reverse-derived percent becomes `61.9`
  - rounding-collapse `61.7` case that should still anchor logically to `61.8`
  - confirmation that ordinary entry-resolution behavior still works for non-grid consumers

  Also tighten any previously fragile expectations so the new source-of-truth model is asserted directly.
- **Dependencies**:
  - Task 3.1
- **Acceptance Criteria**:
  - `fibonacci_grid_percent_test` covers both preserved-good and fixed-bad scenarios.
  - Entry-resolution related tests are updated to the intended semantics rather than the previous inferred-price semantics.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --fast --symbols EURUSD`

### Task 3.3: Run A Focused EURUSD Query-Debug Repro
- **Location**:
  - `logs/query_debug.txt`
  - `logs/test-runner/latest/runtime/*.mql.log`
- **Description**:
  Re-run the exact style of EURUSD non-visual repro that produced the current findings and confirm the new log semantics on:
  - the previously good January 2 case
  - the previously bad January 3 case
- **Dependencies**:
  - Task 3.1
- **Acceptance Criteria**:
  - January 2 no longer shows `logical_entry_pct=100.00` and `level_pct=161.80` for the relevant ordinary limit entries.
  - January 3 still shows a logical `61.8 -> 100.0` progression.
- **Validation**:
  - Manual review of the refreshed `query_debug.txt`
  - Compare only the compact signal lifecycle lines, not full tick logs

## Testing Strategy
- Keep the compile gate strict:
  - `./scripts/run_mql5_tests.sh --compile-only`
- Use the fast EURUSD smoke after each behavior-changing sprint:
  - `./scripts/run_mql5_tests.sh --fast --symbols EURUSD`
- Treat these tests as the minimum regression set for this work:
  - `fibonacci_grid_percent_test`
  - `grid_order_lifecycle_level_stop_limit_test`
  - `structure_fibonacci_entry_levels_test`
  - `structure_entry_trigger_test`
  - `support_resistance_signal_gate_test`
- Validate with one focused `query_debug.txt` repro after the code passes harness expectations.

## Potential Risks & Gotchas
- The stored configured entry level must not break breakout anchoring, which intentionally uses opposite-endpoint semantics.
- `LEVEL_AS_ZONE` should not inherit limit-entry source-of-truth behavior unless explicitly intended; otherwise market-entry semantics may drift.
- If both configured entry percent and actual entry price are stored, logs must label them clearly or the new state will become more confusing instead of less.
- Existing entry-resolution tests already show fragility around Fibonacci semantics. Expect to update those tests intentionally rather than treating every failure as a regression.
- The working tree already contains uncommitted Fibonacci/logging edits; implementation should refine those changes instead of resetting them.

## Rollback Plan
- Revert the new stored Fibonacci entry metadata from `SignalParams`.
- Restore traversal to the prior behavior that derives progression from `entry_price`.
- Keep the existing immediate-close safety guard even if the entry source-of-truth refactor is rolled back.
- Preserve the improved debug header and change-based log deduplication unless they are proven to obscure diagnosis.
