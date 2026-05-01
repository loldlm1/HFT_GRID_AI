# Plan: Exness Session Filter DST Adaptation

**Generated**: 2026-04-01
**Estimated Complexity**: Medium

## Overview
Add broker-season aware session-window adaptation for the existing session time filter only. The implementation should port the `Session_Time_Dst_*` behavior from `bot/pandora_box_ea` into `main`, but align it to the current `services/*` pipeline and keep the feature narrowly scoped to session windows.

The intended product behavior is:
- Keep named sessions aligned to real market sessions across broker seasonal changes.
- Preserve the Pandora Exness rule exactly: `DST_MODE_AUTO_EXNESS` resolves to `0` minutes during Exness summer and `+60` minutes during Exness winter.
- Default `main` to `DST_MODE_OFF` for backward-compatible behavior.
- Keep manual mode as a free integer minute offset.
- Do not add symbol-tradability enforcement to the session filter; existing market-open and broker guards remain the source of truth.
- Add lightweight chart visibility for the resolved session offset, but keep the UI change compact.

Implementation should remain consistent with the project pipeline:
`inputs -> filters -> signal detection -> protection -> frontend`

## External Facts Captured For This Plan
- Exness trading servers follow `UTC+0`.
- Exness documents summer as the second Sunday in March through the first Sunday in November for most instruments.
- Exness documents New York as `13:30-20:00` in summer and `14:30-21:00` in winter, which matches the one-hour broker-season shift assumed by the Pandora branch.
- Exness documents gold (`XAU`) with summer/winter trading-hour shifts as well, so XAUUSD is also season-affected on Exness.
- Exness also states gold is less affected around rollover because it is not open during that period. This supports keeping this feature symbol-agnostic and limited to session-clock alignment, not instrument-hours validation.

## Prerequisites
- Local branch based on `main`.
- Existing ordered include chain must remain intact:
  - `services/license_service_setup.mqh`
  - `services/trading_tools.mqh`
  - `services/trading_management.mqh`
  - `services/trading_management_strategies.mqh`
  - `services/trading_signals.mqh`
  - `services/frontend.mqh`
- Use `services/utils/*`, not `microservices/*`, for the migrated helper.
- Preserve current runtime behavior when `Session_Time_Dst_Mode == DST_MODE_OFF`.
- Keep any test seam small, deterministic, and effectively zero-cost in normal runtime.

## Sprint 1: Domain Wiring And Safe Defaults
**Goal**: Introduce the enum, inputs, and utility helper with no behavior change under default settings.
**Demo/Validation**:
- Project compiles cleanly with the new enum/input/helper added.
- With default `DST_MODE_OFF`, session filter behavior remains unchanged from current `main`.

### Task 1.1: Add DST Mode Enum To Core Types
- **Location**: `services/core/enums.mqh`
- **Description**: Add `DstOffsetModes` to the current core enum set using the Pandora values:
  - `DST_MODE_OFF = 0`
  - `DST_MODE_AUTO_EXNESS = 1`
  - `DST_MODE_MANUAL = 2`
- **Dependencies**: None
- **Acceptance Criteria**:
  - The enum lives in `services/core/enums.mqh`, not in a feature-local file.
  - Names and values match the Pandora branch exactly.
- **Validation**:
  - Headless compile of `HFT_Grid_AI.mq5`.

### Task 1.2: Add Session DST Inputs With Backward-Compatible Defaults
- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Add the two new inputs to the `Time Filter Session Manager` group:
  - `Session_Time_Dst_Mode`
  - `Session_Time_Dst_Manual_Offset_Minutes`
  Default the mode to `DST_MODE_OFF` on `main`.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Inputs remain centralized in `ea_inputs.mqh`.
  - The new inputs are grouped with the existing session-filter inputs.
  - Default mode is `DST_MODE_OFF`.
- **Validation**:
  - Compile gate only.
  - Visual inspection in MT5 inputs panel.

### Task 1.3: Migrate And Normalize The Time Offset Helper Into `services/utils`
- **Location**: `services/utils/time_offset_helper.mqh`, `services/trading_tools.mqh`
- **Description**: Port the Pandora `time_offset_helper` into the canonical `services/utils` tree, update header guards/comments to `services/*`, and include it from `services/trading_tools.mqh`.
- **Dependencies**: Task 1.1, Task 1.2
- **Acceptance Criteria**:
  - No `microservices/*` include or shim is introduced.
  - Helper exposes the minimal public functions needed for session filters:
    - DST date calculation for Exness
    - `ExnessDstActive(...)`
    - `ResolveTradingTimeOffsetMinutes()`
  - Helper comments explain the Exness rule clearly.
- **Validation**:
  - Compile gate only.
  - Include-order review against `AGENTS.md`.

## Sprint 2: Session Filter Integration And Deterministic Tests
**Goal**: Apply the offset to session-window evaluation with a minimal test seam and strict regression coverage.
**Demo/Validation**:
- Manual mode shifts evaluated session time by the configured minute offset.
- Auto Exness mode resolves to `0` in summer and `+60` in winter.
- Existing behavior is preserved when mode is `OFF`.

### Task 2.1: Add A Small Injectable Time Seam For Session Filter Tests
- **Location**: `services/trading_management/session_time_filter_context.mqh`
- **Description**: Introduce a minimal abstraction for the current datetime used by session filtering so DST boundaries can be tested deterministically without changing the EA’s wider time model.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Default path still uses `TimeCurrent()`.
  - The seam is isolated to session-filter/DST evaluation.
  - The seam does not add meaningful runtime overhead in live execution.
- **Validation**:
  - Compile gate only.
  - Test case can set a known datetime and reset it cleanly.

### Task 2.2: Apply Resolved Offset In Session Minute Evaluation
- **Location**: `services/trading_management/session_time_filter_context.mqh`
- **Description**: Port the Pandora behavior into current `main` by subtracting the resolved offset from the effective current time before converting it to `MqlDateTime`. Also expose a small accessor for the resolved offset if needed by UI.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - `DST_MODE_OFF` returns zero offset and preserves current behavior.
  - `DST_MODE_MANUAL` returns the raw configured minute offset.
  - `DST_MODE_AUTO_EXNESS` matches Pandora semantics exactly.
  - No additional session-tradability logic is added here.
- **Validation**:
  - New deterministic session-filter tests pass.
  - Existing tests continue to pass.

### Task 2.3: Add Unit-Style Coverage For DST Boundaries And Session Minutes
- **Location**: `tests/harness/cases/session_time_filter_dst_test_case.mqh`, `tests/session_time_filter_dst_test.mq5`, `tests/hft_grid_ai_tests_harness.mq5`
- **Description**: Add a new test case covering:
  - Exness summer/winter boundary dates
  - `DST_MODE_OFF`
  - `DST_MODE_MANUAL`
  - `DST_MODE_AUTO_EXNESS`
  - Minute resolution before and after offset application
- **Dependencies**: Task 2.1, Task 2.2
- **Acceptance Criteria**:
  - Test names and markers integrate with the current harness.
  - Boundary cases are deterministic and do not depend on broker clock or chart history.
  - At least one assertion proves no behavior drift when mode is `OFF`.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --fast --symbols EURUSD,XAUUSD`

### Task 2.4: Add Narrow Regression Coverage For Exness Date Rules
- **Location**: `tests/harness/cases/session_time_filter_dst_test_case.mqh`
- **Description**: Add explicit date assertions for the second Sunday in March and first Sunday in November, using concrete 2026 dates to avoid ambiguity.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - Tests reference exact calendar dates instead of relative wording.
  - Failure messages make the intended Exness season rule obvious.
- **Validation**:
  - Harness run shows deterministic pass/fail markers for these cases.

## Sprint 3: Lightweight UI Visibility, Docs, And Final Regression
**Goal**: Surface the resolved offset simply in the chart UI, document the behavior, and run full regression checks.
**Demo/Validation**:
- The lightweight chart panel exposes the resolved session offset/mode without degrading compact layouts.
- README documents the new session-DST options and Exness behavior.
- Full compile and runtime smoke remain clean.

### Task 3.1: Add A Compact Session Offset Row To The Lightweight UI
- **Location**: `services/frontend/lightweight_status_ui.mqh`
- **Description**: Add a concise UI row for the session DST state, always visible even when the feature is disabled. Prefer a terse label/value pair that fits existing compact and pressured layouts, for example `Session DST: OFF (0m)` or the equivalent compact row-builder output.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - The row remains visible for all modes, including `DST_MODE_OFF`.
  - UI text stays short enough for current compact layout constraints.
  - The row is derived from the resolved runtime offset, not duplicated calculation logic.
  - The row does not make compact mode unreadable or force unnecessary layout regressions.
- **Validation**:
  - Compile gate only.
  - Manual chart check on a normal chart and a compact chart size.

### Task 3.2: Add UI Regression Coverage For The New Row Budget
- **Location**: `tests/harness/cases/lightweight_status_layout_test_case.mqh`
- **Description**: Extend layout tests, or add a targeted UI-format test, to ensure the added session-offset row stays within the row-width/fit assumptions.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - The new row does not break existing fit decisions for representative wide/compact snapshots.
  - Row text stays within clamped width expectations.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`

### Task 3.3: Document Behavior And Usage
- **Location**: `README.md`
- **Description**: Add a short section documenting:
  - the new DST inputs
  - default `DST_MODE_OFF` behavior
  - Exness auto mode semantics
  - manual offset behavior
  - scope limitation to session filters only
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Documentation uses exact mode names found in code.
  - The scope limitation is explicit so users do not assume broader symbol-hours enforcement.
- **Validation**:
  - README review in diff.

### Task 3.4: Run Final Compile And Smoke Regression
- **Location**: `scripts/run_mql5_tests.sh`, `logs/test-runner/latest/*`
- **Description**: Run the repo’s standard two-step verification and review only the canonical logs.
- **Dependencies**: Sprint 1, Sprint 2, Sprint 3
- **Acceptance Criteria**:
  - Compile gate is clean.
  - Harness runtime is clean.
  - Smoke covers at least `EURUSD` and `XAUUSD`.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --fast --symbols EURUSD,XAUUSD`
  - Review:
    - `logs/test-runner/latest/summary.log`
    - `logs/test-runner/latest/compile/*.metaeditor.log`
    - `logs/test-runner/latest/runtime/*.terminal.log`
    - `logs/test-runner/latest/runtime/*.mql.log`

## Testing Strategy
- Prefer deterministic harness tests over live-clock assumptions.
- Keep the test seam local to session-DST evaluation so the rest of the EA continues to use its current time model.
- Verify three modes independently:
  - `DST_MODE_OFF`
  - `DST_MODE_MANUAL`
  - `DST_MODE_AUTO_EXNESS`
- Verify exact 2026 boundary dates:
  - DST start: `2026-03-08`
  - DST end: `2026-11-01`
- Include a regression assertion that current `main` behavior is unchanged when the mode is left at default `OFF`.
- Include at least one smoke run that mentions `XAUUSD`, not because the feature is symbol-specific, but because Exness gold hours also shift seasonally.

## Potential Risks & Gotchas
- `TimeCurrent()` semantics: MQL5 defines this as the last known server time, not a continuously advancing wall clock. Do not replace it globally with `TimeTradeServer()` unless there is a deliberate product decision, because the current EA already relies on `TimeCurrent()` behavior.
- Boundary ambiguity: DST rules should be tested with exact dates, not relative phrases like “today” or “winter,” to avoid accidental off-by-one mistakes.
- UI density risk: adding even one more row can push small charts into compact mode sooner. Keep the row terse and prefer existing row-building helpers.
- Hidden scope creep: the feature should not evolve into instrument-hours validation. Market tradability already belongs to existing market/broker guards.
- Include-order drift: the migrated helper must enter through `services/trading_tools.mqh`, not through direct sibling includes.
- Test harness friction: the current harness framework does not already include session-filter DST helpers, so test wiring should stay narrow and avoid broad framework churn.

## Rollback Plan
- Revert the new enum and session DST inputs if the feature must be disabled entirely.
- Remove `services/utils/time_offset_helper.mqh` and its aggregator include if the utility approach proves too invasive.
- Revert the `SessionTimeFilterCurrentMinutes()` offset application while keeping default `DST_MODE_OFF` inputs if staged rollback is needed.
- Remove the lightweight UI row independently if layout pressure becomes unacceptable.
- Keep test cases until the final rollback decision is complete, so regressions remain observable during rollback validation.
