# Plan: Fibonacci Semantics And Debug Logging Improvement

**Generated**: 2026-04-02
**Estimated Complexity**: High

## Overview
The recent EURUSD investigation clarified two distinct problems that should be improved together but implemented separately:

1. **Fibonacci progression semantics are hard to reason about**
   - The engine derives the next level from the exact entry percent inside the active structure range.
   - The UI shows the logical next Fibonacci percent label.
   - The engine may emit a broker-safe fallback next price when the raw Fibonacci level collapses onto the entry price.
   - Those three things are related but not identical, which makes the behavior look inconsistent even when the code is internally coherent.

2. **The debug log has the right raw ingredients but too much repeated noise**
   - `GRID_PLAN_BASE` is being emitted every time `BuildGridSignalPoints(...)` recalculates during the lifecycle.
   - The repeated rows drown out the higher-value state transitions.
   - The log does not yet explain the semantic distinction between:
     - exact entry percent
     - nearest Fibonacci band
     - logical next Fibonacci percent
     - emitted next trigger price

This plan improves both areas without undoing the current safety fix. The intended outcome is:

- the Fibonacci progression rule becomes explicit and testable
- chart labels and debug logs explain the same model
- repeated query-debug spam is reduced to meaningful state changes only
- `LEVELS_AS_LIMITS` advances to the next configured Fibonacci level, not to ambiguous micro-steps near the current entry

## Prerequisites
- Keep the current immediate-close guard and broker-safe next-price fallback in place as safety rails while semantics are refined.
- Use the current `logs/query_debug.txt` failing case and the newly added previous-day passing case as the baseline artifacts.
- Preserve the current include pipeline and keep changes inside existing `services/*` ownership boundaries.

## Sprint 1: Define Canonical Fibonacci Semantics
**Goal**: Turn the current implicit behavior into an explicit domain rule that can be implemented and tested.
**Demo/Validation**:
- A short written rule exists for how `ENTRY`, `NEXT`, and displayed Fibonacci labels are supposed to behave for `FIB_LEVEL_RANGE + LEVELS_AS_LIMITS`.
- The rule can explain both the 2024-01-02 passing signal and the 2024-01-03 degenerate signal without ambiguity.

### Task 1.1: Write the canonical meaning of each Fibonacci concept
- **Location**:
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh)
  - [services/frontend/grid_visualization.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/grid_visualization.mqh)
  - [README.md](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/README.md)
- **Description**:
  - Define the exact meaning of:
    - entry percent
    - entry band
    - logical next Fibonacci percent
    - emitted next trigger price
    - displayed next label
- **Dependencies**: none
- **Acceptance Criteria**:
  - Each concept has a single canonical definition.
  - The definitions explain why a raw `61.7 -> 61.8` transition can exist while the emitted next price may still be broker-safe and farther away.
- **Validation**:
  - Manual trace against the two known EURUSD log slices.

### Task 1.2: Choose the future progression model for `LEVELS_AS_LIMITS`
- **Location**:
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L800)
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L925)
- **Description**:
  - Lock the canonical rule as:
    - **band-to-band progression semantics**
    - the engine should advance to the next configured Fibonacci level rather than ambiguous exact-price micro-steps
    - broker-safe emitted prices may still differ from the raw logical Fibonacci price when symbol precision or broker limits require it
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - A bullish entry effectively inside the `61.8` band logically progresses to `100.0`, not to `61.8` again.
  - The next configured Fibonacci level is always the logical target level for progression.
  - Broker-safe emitted trigger prices are treated as execution adjustments, not as the logical next level itself.
- **Validation**:
  - Cross-check against the chart example and `query_debug.txt`.

### Task 1.3: Decide what the chart should communicate
- **Location**:
  - [services/frontend/grid_visualization.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/grid_visualization.mqh)
  - [services/frontend/grid_visual_utils.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/grid_visual_utils.mqh)
- **Description**:
  - Keep the chart communication simple and useful:
    - avoid noisy, multi-part labels by default
    - prefer a compact label that reflects the logical configured next Fibonacci level
    - only expose richer trigger-price semantics on-chart if that can be done without clutter
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - The chart stays simple enough for normal trading use.
  - The chart does not imply a different logical progression rule than the engine uses.
  - Detailed emitted-trigger semantics can live in `query_debug.txt` rather than being forced into noisy chart text.
- **Validation**:
  - Review a single annotated screenshot example before implementation.

## Sprint 2: Align Fibonacci Resolution With The Chosen Semantics
**Goal**: Refactor Fibonacci planning so the engine’s logical next level, emitted next price, and UI meaning no longer drift apart.
**Demo/Validation**:
- The known EURUSD edge case can be described consistently by both logs and chart labels.

### Task 2.1: Separate logical next Fibonacci level from emitted next trigger price
- **Location**:
  - [services/trading_signals/signal_params_struct.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/signal_params_struct.mqh)
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh)
  - [services/trading_signals/grid_planner.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_planner.mqh)
- **Description**:
  - Introduce an explicit distinction between:
    - logical next Fibonacci percent / price
    - actual emitted next trigger price after broker-safe adjustments
  - Avoid overloading a single `next_level_price` field to mean both.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Debug logs and frontend can reference either the logical next level or the emitted trigger price intentionally.
  - Future fixes do not need to reverse-engineer meaning from one overloaded value.
- **Validation**:
  - Unit-style harness checks for both logical and emitted next values.

### Task 2.2: Refine `LEVELS_AS_LIMITS` traversal to match the chosen domain rule
- **Location**:
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L763)
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh#L925)
- **Description**:
  - Implement the selected rule from Sprint 1:
    - band-to-band progression as the logical source of truth
    - explicit mapping from current entry band to next configured Fibonacci level
    - broker-safe trigger-price adjustment as a separate execution concern
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - The planner no longer relies on accidental percent rounding behavior to decide whether the next level is meaningful.
  - The planner no longer uses ambiguous raw `61.7 -> 61.8` micro-progression as the logical next level when the configured next band should be `100.0`.
  - The 2024-01-02 and 2024-01-03 EURUSD cases are both explainable by the same rule.
- **Validation**:
  - Deterministic harness cases for both scenarios.

### Task 2.3: Keep the current safety rails as defense-in-depth
- **Location**:
  - [services/trading_signals/grid_order_lifecycle.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_lifecycle.mqh)
  - [services/trading_signals/grid_order_helpers.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_helpers.mqh)
- **Description**:
  - Preserve a minimal same-price / no-gap guard even after upstream semantics are cleaned up.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - A bad future structure snapshot or math edge case still cannot reopen the immediate-close failure mode.
- **Validation**:
  - Existing regression tests continue to pass.

## Sprint 3: Improve Query Debug Signal Quality
**Goal**: Make `query_debug.txt` compact, readable, and focused on state changes rather than recomputation spam.
**Demo/Validation**:
- A single failing or passing signal can be understood quickly without scrolling through hundreds of repeated base-plan lines.

### Task 3.1: Change `GRID_PLAN_BASE` to log only on meaningful change
- **Location**:
  - [services/trading_signals/grid_planner.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_planner.mqh)
  - [services/trading_signals/grid_order_logging.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_logging.mqh)
- **Description**:
  - Suppress repeated `GRID_PLAN_BASE` rows unless one of these changes:
    - entry reference
    - base distance
    - Fibonacci traversal step
    - logical next level
    - emitted next trigger price
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Identical consecutive `GRID_PLAN_BASE` rows are no longer emitted.
  - The first initialization row is always preserved.
  - No optional verbose replay mode is required for this work; the default query debug should stay compact.
- **Validation**:
  - Non-visual tester run produces compact logs for both a passing and a failing signal.

### Task 3.2: Add explicit Fibonacci semantics fields to debug output
- **Location**:
  - [services/trading_signals/grid_order_logging.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_logging.mqh)
- **Description**:
  - Expand the level-resolution log to include compact fields such as:
    - `entry_band`
    - `logical_next_pct`
    - `logical_next_price`
    - `emitted_next_price`
    - `next_price_source=RAW_FIB|BROKER_SAFE`
    - `range_span_pts`
    - `fib_steps`
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - A future reader can tell whether the chart label and the armed trigger refer to the same thing or not.
- **Validation**:
  - Review one passing and one degenerate log slice for readability.

### Task 3.3: Promote lifecycle events over recomputation events
- **Location**:
  - [services/trading_signals/grid_order_controller.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_controller.mqh)
  - [services/trading_signals/grid_order_logging.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/trading_signals/grid_order_logging.mqh)
- **Description**:
  - Keep high-value event rows prominent:
    - signal init
    - pending init
    - limit armed
    - level reached
    - next trigger
    - stop limit decision
    - close reason
  - Move lower-value recomputation logs behind change-based logging or optional debug verbosity.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - The log reads as a lifecycle narrative first, math trace second.
- **Validation**:
  - Manual readability review on a full tester artifact.

## Sprint 4: Align Frontend Labels With Engine Semantics
**Goal**: Remove ambiguity between what the chart says and what the engine is actually armed to do.
**Demo/Validation**:
- The NEXT line text can be understood without opening `query_debug.txt`.

### Task 4.1: Update NEXT label wording
- **Location**:
  - [services/frontend/grid_visualization.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/grid_visualization.mqh)
  - [services/frontend/grid_visual_utils.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/grid_visual_utils.mqh)
- **Description**:
  - Keep NEXT label wording minimal and useful.
  - Prefer showing the logical next configured Fibonacci level by default.
  - Only add trigger-price detail if it can be expressed compactly without making the chart noisy.
- **Dependencies**: Sprint 1 and Sprint 2
- **Acceptance Criteria**:
  - The chart remains readable in normal use.
  - The chart cannot misleadingly suggest a wrong logical next Fibonacci level.
  - Detailed execution semantics are available in logs even if not all of them are shown on-chart.
- **Validation**:
  - Chart screenshot review on the known EURUSD example.

### Task 4.2: Add a lightweight semantic summary row if needed
- **Location**:
  - [services/frontend/lightweight_status_ui.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/services/frontend/lightweight_status_ui.mqh)
- **Description**:
  - If the label alone is still ambiguous, add a short summary such as:
    - `Next Logic: 61.8% -> armed 1.09157`
  - Default preference is to avoid adding this row unless the simpler chart wording is still genuinely misleading.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - The extra row is compact and only added if it reduces ambiguity materially.
- **Validation**:
  - Manual UI review on desktop and tester chart.

## Sprint 5: Regression Coverage And Rollout
**Goal**: Lock the clarified semantics and logging behavior with deterministic coverage.
**Demo/Validation**:
- Tests describe the intended semantics instead of only guarding against the old bug.

### Task 5.1: Add semantic Fibonacci progression tests
- **Location**:
  - [tests/harness/cases/fibonacci_grid_percent_test_case.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/tests/harness/cases/fibonacci_grid_percent_test_case.mqh)
  - `tests/harness/cases/*` as needed
- **Description**:
  - Add explicit tests for:
    - exact-price entry near a band edge
    - expected logical next percent
    - expected emitted next price
    - passing-day style case where next logical level is `100.0`
    - edge case where adjacent levels normalize to the same market price
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - The intended progression rule is encoded directly in tests.
- **Validation**:
  - Harness passes on at least EURUSD and XAUUSD smoke runs.

### Task 5.2: Add logging-shape assertions where feasible
- **Location**:
  - [tests/harness/framework.mqh](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/tests/harness/framework.mqh)
  - dedicated logging-oriented harness case if useful
- **Description**:
  - Add lightweight tests or stubs that verify:
    - high-value labels are still emitted
    - repeated identical `GRID_PLAN_BASE` spam is suppressed
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - Logging improvements do not silently regress later.
- **Validation**:
  - Harness assertions or focused tester replay.

### Task 5.3: Verify on real symbol controls
- **Location**:
  - test runner and non-visual tester artifacts
- **Description**:
  - Re-run targeted non-visual checks on:
    - EURUSD degenerate case
    - EURUSD passing case
    - XAUUSD control
- **Dependencies**: Sprints 2 through 4
- **Acceptance Criteria**:
  - The new semantics do not reintroduce immediate-close behavior.
  - Logs are materially smaller and easier to scan.
- **Validation**:
  - `--compile-only`
  - `--fast --symbols EURUSD,XAUUSD`
  - targeted file-log replay when needed

## Testing Strategy
- Keep semantic decisions explicit before editing the Fibonacci traversal code.
- Preserve the current immediate-close fix while introducing semantic refactors.
- Validate each sprint with deterministic harness coverage before relying on tester screenshots.
- Use chart screenshots only as confirmation, not as the primary source of truth.

## Potential Risks & Gotchas
- The biggest ambiguity is domain intent:
  - Should progression be based on exact entry percent or on canonical Fibonacci bands?
- Changing progression semantics may alter behavior on symbols that were not failing.
- UI labels can become more confusing if they try to compress both logical and emitted states into one short string without a clear format.
- Logging deduplication can hide useful evidence if the change key is too aggressive.

## Rollback Plan
- If semantic refactoring proves too invasive, keep the current safety fix and implement only logging and label clarification.
- If logging deduplication removes useful evidence, fall back to change-based throttling instead of hard suppression.
- If frontend wording becomes noisy, keep the chart line simple and move richer explanation to `query_debug.txt` and the status panel.
