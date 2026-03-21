# Plan: Support Resistance Retest Chain Addon

**Generated**: 2026-03-21
**Estimated Complexity**: High

## Overview
Build a new licensed input-group addon that acts as a hard pre-entry gate for structure-driven signals. The addon validates the current structure only when:

- the current signal's Fibonacci price lies inside the most recent support/resistance zone anchored to the latest qualifying extremum,
- the current signal price source comes from the resolved entry flow:
  `LEVELS_AS_LIMITS` uses the resolved pending-entry band/price and
  `LEVEL_AS_ZONE` uses the confirmed market-entry zone result,
- that zone is built from the active structure leg and centered on the extremum-side percent (`100%` in the current orientation, with configurable `range_percent / 2` above and below),
- the current touch counts as one confirmation,
- older alternating extrema confirm the chain backward until the configured retest count is satisfied,
- role reversal is allowed, so prior resistance can validate current support and prior support can validate current resistance.

Working addon/product name:
- `support-resistance-retest-chain`

Research conclusion:
- Do **not** adapt the current `fibo_retest_zones` logic in place.
- Add a new dedicated support/resistance chain filter in the signal-filter layer, then remove the legacy `fibo_retest_zones` fields/helpers after migration.

Reasoning:
- `fibo_retest_zones` is hard-coded to fixed bands (`61.8-78.6`, `78.6-100`) and cumulative counters.
- The requested feature is runtime-configurable, direction-aware, anchored to the latest extremum-leg orientation, and uses backward chain semantics rather than static zone statistics.
- Current repository search shows `fibo_retest_zones` is not consumed by runtime signal code, so staged replacement is lower-risk than refactoring it into a new meaning.

## Prerequisites
- Keep the ordered include pipeline unchanged:
  `services/license_service_setup.mqh` -> `services/trading_tools.mqh` -> `services/trading_management.mqh` -> `services/trading_management_strategies.mqh` -> `services/trading_signals.mqh` -> `services/frontend.mqh`
- Follow MQL5 repo style:
  2-space indentation, snake_case variables, CamelCase functions, explicit constructors, no C++11 features.
- Use the existing strict test runner:
  `./scripts/run_mql5_tests.sh --compile-only`
  `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
- Treat runtime addon gating as the same product surface used by `addon_candle_structure` and the compound-family addons.

## Sprint 1: Define the Feature Contract and Pure Chain Logic
**Goal**: land a deterministic, testable support/resistance chain evaluator with no dependency on live license state.
**Demo/Validation**:
- New helper tests pass with synthetic structures and deterministic prices.
- Default inputs keep behavior unchanged when the addon is disabled.
- No new indicator handles or `CopyBuffer()` calls are introduced.

### Task 1.1: Add the New Input Group and Sanitized Runtime Contract
- **Location**:
  `services/trading_management/ea_inputs.mqh`
  `services/trading_management/strategy_structure_context.mqh`
- **Description**:
  Add a new input group for the addon with:
  - enable/disable switch,
  - retest count (`int`, sanitized to `>= 1`),
  - range percent (`double`, sanitized to `> 0`).
  Extend structure-context helpers so the filter can read one normalized runtime contract instead of parsing raw inputs repeatedly.
- **Dependencies**: none
- **Acceptance Criteria**:
  - Addon defaults are inert and do not change current behavior.
  - Invalid runtime values are clamped once through helper functions, not ad hoc in multiple call sites.
  - The contract clearly distinguishes "feature enabled" from "input values present but ignored."
- **Validation**:
  - Add/update unit tests for sanitizer behavior.
  - Confirm default input profile still requests zero paid addons.

### Task 1.2: Introduce a Dedicated Support/Resistance Chain Filter Service
- **Location**:
  `services/trading_signals/structure_support_resistance_filter.mqh` (new)
  `services/trading_signals.mqh`
- **Description**:
  Create a new signal-layer helper service responsible for:
  - resolving the current reference range from `StochasticMarketStructure`,
  - computing the most recent support/resistance zone around the qualifying extremum,
  - converting the configured percent band into prices using existing Fibonacci helpers,
  - evaluating whether the current signal Fibonacci price is inside the current zone,
  - recursively building each older local support/resistance zone from its own leg and validating the next older extremum,
  - failing the signal immediately when any required hop in the chain breaks before the requested retest count is reached.

  The new file should be added to the ordered `services/trading_signals.mqh` aggregator before `market_signal_filters.mqh`.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The filter uses existing structure and Fibonacci helpers as source material.
  - The filter does not depend on legacy `fibo_retest_zones`.
  - The scan supports role reversal: peak-based resistance can later validate support, and bottom-based support can later validate resistance.
  - The implementation prefers a generalized alternating scan over hard-coded `3/5/7` indices, but still preserves the current structure ordering expectations.
- **Validation**:
  - Compile-only pass.
  - Code review checklist confirms no sibling-include violations.

### Task 1.3: Formalize the Chain Algorithm with Explicit Helper Boundaries
- **Location**:
  `services/trading_signals/structure_support_resistance_filter.mqh`
  `services/indicators/fibonacci_calculator.mqh` (only if small reusable percent/price helpers are missing)
- **Description**:
  Split the algorithm into explicit helper steps:
  - resolve the active orientation and current reference leg,
  - resolve the current signal price source from the already-evaluated entry mode,
  - resolve the current qualifying extremum for the most recent zone,
  - convert `center_percent +/- (range_percent / 2)` into price bounds,
  - test the current signal Fibonacci price against the most recent zone only,
  - recursively walk backward across alternating extrema and build each historical local zone from its own leg,
  - stop immediately on the first broken hop when the configured chain count has not yet been satisfied,
  - return a compact result struct or tuple with pass/fail, matched count, and reference-zone diagnostics.

  Keep the logic price-based for the zone check and structure-based for chain traversal.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Retest input `1` means current touch alone passes.
  - Retest input `3` means `2 historical + current`.
  - Insufficient historical depth fails cleanly without undefined indexing.
  - `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE` both use the same chain logic, but consume their own resolved entry price source from the existing entry flow.
  - Direction-independent helper logic can evaluate both bullish and bearish cases from the same core path.
- **Validation**:
  - Dedicated unit tests for pass/fail edge cases.
  - Manual review of off-by-one indexing against `os_market_structures[]`.

### Task 1.4: Add Pure Logic Test Coverage for Chain Semantics
- **Location**:
  `tests/harness/cases/support_resistance_retest_chain_test_case.mqh` (new)
  `tests/support_resistance_retest_chain_test.mq5` (new)
  `tests/hft_grid_ai_tests_harness.mq5`
- **Description**:
  Create mock-data tests for:
  - bullish current support validated from a prior peak-based resistance,
  - bearish current resistance validated from a prior bottom-based support,
  - current-touch-only pass (`retest_count = 1`),
  - `retest_count = 3` pass with `2 historical + current`,
  - recursive local-zone chain pass across alternating extrema,
  - failure when a historical chain hop does not validate,
  - failure when structure depth is insufficient,
  - failure when current Fibonacci price is outside the most recent zone,
  - parity coverage for `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE`.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Tests are mock-data driven and do not require broker/chart history.
  - The new tests exercise role reversal and alternating scan behavior.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`

## Sprint 2: Integrate the Gate into Signal Evaluation
**Goal**: make the feature block invalid signals in the real entry flow while preserving current behavior when disabled.
**Demo/Validation**:
- With the addon disabled, signal flow remains unchanged.
- With the addon enabled, failed chains stop signal creation before grid planning.
- Existing touch-policy and candle-filter tests still pass.

### Task 2.1: Wire the Gate into `StrategyContextEvaluateEntry`
- **Location**:
  `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Integrate the new filter into the current evaluation sequence:
  - candle structure filter,
  - structure compound filter,
  - fresh-structure check,
  - structure Fibonacci entry resolution,
  - new support/resistance retest chain gate,
  - final entry allow/block result.

  The gate should evaluate only after a candidate entry price/band exists, because the current signal Fibonacci price is part of the rule. This keeps both `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE` aligned with the same real entry candidate that would otherwise be used to open the signal.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Disabled addon path is a no-op.
  - Failed chain marks `filters_pass = false` and blocks entry cleanly.
  - Successful chain does not mutate entry price behavior.
- **Validation**:
  - Integration tests around `StrategyContextEvaluateEntry`.
  - Existing entry-trigger tests still pass.

### Task 2.2: Use Existing Structure Snapshot Data Only
- **Location**:
  `services/trading_signals/market_signal_filters.mqh`
  `services/trading_signals/structure_support_resistance_filter.mqh`
- **Description**:
  Ensure the new gate consumes `snapshot.structure_data`, already-resolved price context, and existing Fibonacci helpers only. Do not create extra indicator handles, extra buffer copies, or extra chart-history scans beyond what the snapshot already contains.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - No new indicator creation in the filter path.
  - No repeated structure capture in the same bar.
  - Tester performance impact stays bounded to in-memory scans over the existing extrema array.
- **Validation**:
  - Code review against `CaptureContextIndicators()` and `StrategyContextEvaluateEntry()`.
  - Manual profiling notes in the PR/implementation summary.

### Task 2.3: Add Filter-Level Diagnostics
- **Location**:
  `services/trading_signals/structure_support_resistance_filter.mqh`
  `services/trading_signals/market_signal_filters.mqh`
- **Description**:
  Add concise debug logs behind `Enable_Logs` so failed evaluations can report:
  - current direction,
  - current matched zone bounds,
  - required retest count,
  - achieved historical confirmations,
  - reason for failure.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Logs remain concise and removable.
  - No log spam when `Enable_Logs == false`.
- **Validation**:
  - Manual tester smoke with logs enabled.

### Task 2.4: Add End-to-End Signal-Gating Tests
- **Location**:
  `tests/harness/cases/support_resistance_signal_gate_test_case.mqh` (new)
  `tests/support_resistance_signal_gate_test.mq5` (new)
  `tests/hft_grid_ai_tests_harness.mq5`
- **Description**:
  Add tests that run the gate through `StrategyContextEvaluateEntry()` or a thin wrapper so the suite verifies real signal behavior, not only pure helpers.
- **Dependencies**: Tasks 2.1-2.3
- **Acceptance Criteria**:
  - Enabled + failing chain blocks entry.
  - Enabled + passing chain preserves entry.
  - Disabled addon does not change existing behavior.
  - Both `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE` are covered by integration tests.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`

## Sprint 3: Add Licensed Addon Wiring and Product Documentation
**Goal**: ship the feature as a paid addon consistent with the current license/runtime policy model.
**Demo/Validation**:
- Enabling the addon requests exactly one addon key.
- Missing entitlement blocks startup outside the Strategy Tester.
- Addon guide and product copy match the actual trigger rules.

### Task 3.1: Add the New Addon Key and Display Label
- **Location**:
  `services/shared/license_guard_v1/core/addon_catalog.mqh`
- **Description**:
  Add a new addon SKU constant and display label for the `support-resistance-retest-chain` feature.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Key is normalized consistently with the existing catalog.
  - Display label fits current UI summaries.
- **Validation**:
  - Extend addon catalog tests for label rendering.

### Task 3.2: Extend Requested-Addon Collection Rules
- **Location**:
  `services/trading_management/addon_runtime_policy.mqh`
  `tests/harness/cases/addon_runtime_policy_test_case.mqh`
- **Description**:
  Request the new addon when the feature is enabled. Keep the rule simple:
  - addon requested when enable switch is on,
  - addon not requested when disabled, even if count/range inputs are non-default.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Default profile still requests no paid addons.
  - Enabled profile requests exactly the new addon.
  - No duplicate addon keys are emitted.
- **Validation**:
  - Update `addon_runtime_policy_test_case.mqh`.

### Task 3.3: Add User-Facing Addon Docs
- **Location**:
  `docs/addons/README.md`
  `docs/addons/support-resistance-retest-chain.md` (new)
  `docs/product_copy/en/addon-support-resistance-retest-chain.md` (new)
  `docs/product_copy/es/addon-support-resistance-retest-chain.md` (new)
- **Description**:
  Document:
  - addon SKU,
  - inputs in the new group,
  - entitlement trigger rule,
  - example setups,
  - missing-addon behavior,
  - bullish/bearish role-reversal explanation with plain-language examples.
- **Dependencies**: Tasks 3.1-3.2
- **Acceptance Criteria**:
  - README addon matrix includes the new addon.
  - Product copy stays aligned with the actual runtime rule.
- **Validation**:
  - Manual doc review for consistency with code.

## Sprint 4: Remove Legacy Retest-Zone Code and Run Full Regression
**Goal**: finish with one clear support/resistance implementation path and no dead retest subsystem.
**Demo/Validation**:
- Legacy fixed-zone retest fields/helpers are removed or fully isolated from runtime.
- Full strict compile gate passes.
- Fast runtime smoke stays clean.

### Task 4.1: Remove the Unused `fibo_retest_zones` Payload
- **Location**:
  `services/indicators/structure_classifier.mqh`
  `services/indicators/extremum_statistics_calculator.mqh`
- **Description**:
  Delete:
  - `RetestZoneStatistics`,
  - `fibo_retest_zones`,
  - fixed-zone constants,
  - `UpdateRetestCounters()`,
  - related per-zone fields and initialization paths.

  Keep the remaining structure classification data only if still useful. Do not expand this sprint into a broader `extremum_stats[]` redesign unless the removal exposes a compile dependency.
- **Dependencies**: Sprint 2, Sprint 3
- **Acceptance Criteria**:
  - No runtime or test code references the removed retest-zone fields.
  - Remaining extremum statistics compile cleanly.
- **Validation**:
  - Repository-wide `rg` confirms no residual references.
  - Compile-only test run passes.

### Task 4.2: Re-check `StochasticMarketStructure` for Dead Fields
- **Location**:
  `services/indicators/stochastic_market_indicator.mqh`
  `services/indicators/structure_classifier.mqh`
- **Description**:
  Review whether the retained `extremum_stats[]` payload is still justified after the fixed-zone removal. If it remains unused, capture a scoped follow-up issue; do not silently expand the feature scope unless the cleanup is trivial and low-risk.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - No accidental broad refactor is mixed into this feature.
  - Any further cleanup is clearly deferred or intentionally completed.
- **Validation**:
  - Review `rg` results and compile impact.

### Task 4.3: Run Final Regression Gates
- **Location**:
  `scripts/run_mql5_tests.sh`
  `logs/test-runner/latest/summary.log`
  `logs/test-runner/latest/compile/*.metaeditor.log`
  `logs/test-runner/latest/runtime/*.terminal.log`
  `logs/test-runner/latest/runtime/*.mql.log`
- **Description**:
  Run the recommended two-step validation flow:
  1. `./scripts/run_mql5_tests.sh --compile-only`
  2. `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
- **Dependencies**: Sprint 4 complete
- **Acceptance Criteria**:
  - No warnings or errors in compile gate.
  - Harness emits clean `TEST_PASS` / `TEST_FAIL` markers.
  - New feature tests pass alongside existing structure/filter tests.
- **Validation**:
  - Review only the repo-standard latest log set.

## Testing Strategy
- Prefer mock-data unit tests for the chain algorithm and keep wrapper `.mq5` files thin.
- Add two layers of tests:
  - pure helper tests for zone math and backward chain traversal,
  - integration tests for `StrategyContextEvaluateEntry()`.
- Preserve and rerun current tests related to:
  - structure Fibonacci orientation,
  - structure entry trigger resolution,
  - structure touch policy,
  - structure context requirements,
  - addon runtime policy.
- Validate disabled-addon behavior explicitly so the feature does not change the base EA profile.

## Potential Risks & Gotchas
- **Current Fibonacci price source must stay tied to the real entry mode**:
  the gate should use the resolved signal entry candidate from the existing flow, not `first_structure_close_percent` alone. Otherwise `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE` can diverge from actual trading behavior.
- **Recursive chain semantics can drift if indexing is implicit**:
  define explicit helper boundaries and test the walk direction against synthetic alternating structures to prevent off-by-one mistakes.
- **Range percent can cross `0` or `100`**:
  the helper must intentionally support extension-space prices (for example `95-105`) instead of silently clamping unless product rules later require clamping.
- **Legacy cleanup can expand too far**:
  remove `fibo_retest_zones`, but avoid turning this feature into a full `extremum_stats[]` redesign unless the compile graph forces it.
- **Addon docs and runtime policy must stay aligned**:
  the entitlement rule should remain a single boolean trigger on enablement, not a mixed "non-default values" rule, unless product requirements change.

## Rollback Plan
- Revert the new signal gate file and its aggregator include.
- Remove the new input group and addon runtime-policy hook.
- Restore the previous `market_signal_filters.mqh` entry flow.
- If Sprint 4 was completed, restore the deleted legacy retest-zone code as one isolated revert.
- Re-run `./scripts/run_mql5_tests.sh --compile-only` to confirm the baseline is restored.
