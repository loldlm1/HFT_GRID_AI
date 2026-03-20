# Plan: Responsive Lightweight Status Panel

**Generated**: 2026-03-20
**Estimated Complexity**: High

## Overview
The current lightweight frontend panel is rendered from `services/frontend/lightweight_status_ui.mqh` and is refreshed through `RenderLightweightStatusTable()` during `RefreshGridVisualization()`. Today it sizes the panel with a fixed character-width estimate (`LIGHTWEIGHT_UI_CHAR_WIDTH_EST = 7`) and width caps (`260..520` px), while `OnChartEvent()` in `HFT_Grid_AI.mq5` only handles button clicks. That combination is fragile across native Windows MT5 and Wine because font metrics, DPI/scaling, and object rendering differ by environment.

This plan replaces the current fixed-width heuristic with a chart-aware layout policy that:
- reads chart width and height from MT5 at runtime,
- selects a `full` or `compact` panel profile based on available space,
- preserves high-priority rows on constrained charts,
- collapses low-priority rows into a compact summary when necessary,
- recalculates on first initialization and on major chart changes.

The goal is readable, predictable rendering on native Windows and Wine without attempting pixel-perfect cross-platform parity.

## Prerequisites
- Keep all changes aligned with the functional include chain in `AGENTS.md`.
- Keep frontend ownership inside `services/frontend/*` and update `services/frontend.mqh` if a new frontend helper file is introduced.
- Respect official MQL5 behavior confirmed from current docs:
  - `OnChartEvent()` can handle `CHARTEVENT_CHART_CHANGE`.
  - `ChartGetInteger(..., CHART_WIDTH_IN_PIXELS/CHART_HEIGHT_IN_PIXELS)` provides chart size for responsive decisions.
  - chart and object property updates are asynchronous, so `ChartRedraw()` is required when immediate repaint is needed.
- Validation scope for this work:
  - strict compile gate,
  - basic harness/runtime smoke,
  - manual visual QA by the user on native Windows and Wine.
- Accepted product assumptions from current clarification:
  - compact mode is acceptable on small charts,
  - low-priority rows may be collapsed or hidden,
  - font family and font size may change for better consistency,
  - live responsiveness only needs to be correct on first initialization and major chart changes,
  - compact mode should still keep one live signal row visible,
  - margins may be reduced and the panel may be slightly repositioned on extremely constrained charts,
  - a simple `More/Details` affordance is acceptable only if it is low-complexity and reuses the existing object/event model cleanly; otherwise it is out of scope for the first pass.

## Sprint 1: Baseline And Layout Contract
**Goal**: Convert the current ad hoc panel behavior into an explicit, testable layout contract before changing rendering code.
**Demo/Validation**:
- New layout rules are documented in code comments and represented by pure helper functions.
- Compile passes with no warnings.
- Layout helper tests can run in the existing harness.

### Task 1.1: Define Panel Information Priority
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Classify panel rows into `always_visible`, `preferred`, and `collapsible` groups. Proposed baseline priority:
  - always visible: toggle/title, Fibonacci EA state, algo trading state, manual toggle, signal gate, market state.
  - preferred: magic number, block source, block reason.
  - collapsible: requested addons, purchased addons, missing required, signal summary rows.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Row priority is explicit in code, not implied by row append order alone.
  - Compact mode has a defined rule for what is dropped or summarized first.
  - Summary rows generated from `BuildSignalSummary()` are treated as low-priority content.
- **Validation**:
  - Code review against the user-approved behavior.
  - Compile gate remains clean.

### Task 1.2: Introduce A Pure Layout Helper Layer
- **Location**: `services/frontend.mqh`, `services/frontend/lightweight_status_layout.mqh` (new), `services/frontend/lightweight_status_ui.mqh`
- **Description**: Extract layout math and profile selection into a pure helper module. Define small structs/enums for chart snapshot, layout profile, typography, panel metrics, and row budget so responsiveness can be tested without creating chart objects.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Layout calculations are isolated from object creation/update calls.
  - The helper layer does not own trading logic and stays frontend-only.
  - `services/frontend.mqh` remains the source of truth for frontend include order.
- **Validation**:
  - Compile gate passes.
  - Helper functions can be called from tests without chart object side effects.

### Task 1.3: Add Harness Coverage For Layout Decisions
- **Location**: `tests/harness/framework.mqh`, `tests/harness/cases/lightweight_status_layout_test_case.mqh` (new), `tests/lightweight_status_layout_test.mq5` (new), `tests/hft_grid_ai_tests_harness.mq5`
- **Description**: Add tests for profile selection and row budgeting using synthetic chart dimensions and representative row counts/content lengths.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Tests cover at least `wide`, `medium`, and `small` chart snapshots.
  - Tests verify that compact mode hides or summarizes low-priority rows before hiding core state rows.
  - Tests verify width/height outputs remain within safe bounds.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - targeted harness inclusion passes compile and runtime smoke.

## Sprint 2: Responsive Layout Engine
**Goal**: Replace the fixed-width estimator with deterministic responsive layout profiles that are readable on small charts and stable across Windows/Wine.
**Demo/Validation**:
- Panel width, height, font size, and row count change according to chart dimensions.
- Small-chart mode renders a readable compact panel instead of truncated dense text.
- Existing button/toggle behavior still works.

### Task 2.1: Replace Fixed Character-Width Sizing With Chart-Aware Metrics
- **Location**: `services/frontend/lightweight_status_layout.mqh`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Stop using the current `LIGHTWEIGHT_UI_CHAR_WIDTH_EST` constant as the primary layout driver. Compute panel width from chart dimensions and layout profile, using bounded percentages and safe minima/maxima. Keep text clamping only as a secondary guard. Add a constrained-chart placement rule that can shrink outer margins and slightly reposition the panel when top-left spacing would otherwise make the layout unreadable.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Panel width depends on chart size, not on a single hardcoded per-character estimate.
  - Layout outputs remain bounded for very narrow and very wide charts.
  - Compact mode uses a narrower width target than full mode.
  - Extremely constrained charts can reduce margins or slightly reposition the panel while remaining anchored in a predictable upper-chart area.
- **Validation**:
  - Layout tests cover boundary sizes.
  - Manual smoke on at least one wide chart and one narrow chart.

### Task 2.2: Implement Full And Compact Profiles
- **Location**: `services/frontend/lightweight_status_layout.mqh`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Implement at least two layout profiles:
  - `full`: current rich panel with prioritized rows and signal summary rows when space allows.
  - `compact`: reduced typography, reduced row budget, condensed addon/signal summary, and only essential rows visible while still preserving one live signal row.
- **Dependencies**: Task 1.1, Task 2.1
- **Acceptance Criteria**:
  - Compact mode is selected automatically from chart width/height thresholds.
  - Full mode remains readable on larger charts.
  - Compact mode never attempts to render the full long-form row set unchanged.
  - Compact mode keeps one live signal row visible and does not stack multiple signal detail rows when space is limited.
- **Validation**:
  - Layout tests validate profile selection by dimension.
  - Manual QA confirms compact mode is visibly different and readable.

### Task 2.3: Standardize Typography And Spacing Tokens
- **Location**: `services/frontend/lightweight_status_layout.mqh`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Centralize font family, font size, row step, padding, and button height per profile. Choose a Windows-safe font strategy rather than assuming current `Consolas` metrics are portable enough by themselves.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Typography and spacing values are no longer scattered through object creation functions.
  - Button height and label row spacing scale with profile.
  - Font choice can be changed in one place if QA shows Windows-specific issues.
- **Validation**:
  - Compile gate passes.
  - Manual QA confirms text is visually readable in both profiles.

### Task 2.4: Condense Secondary Content For Small Charts
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Convert low-priority rows into shorter forms in compact mode. Examples:
  - collapse addon status into one summary line,
  - show one live signal row plus an aggregate count instead of multiple `S1`, `S2`, `S3` rows,
  - clamp long reason strings more aggressively in compact mode.
- **Dependencies**: Task 1.1, Task 2.2
- **Acceptance Criteria**:
  - Compact mode preserves readability without overflowing the available row budget.
  - Low-priority content is summarized, not blindly truncated line by line.
  - Important blocking states remain visible when they exist.
  - Compact signal presentation shows one live row and a summary count rather than stacking multiple signal rows.
- **Validation**:
  - Layout tests verify compact summaries for long addon/status content.
  - Manual smoke confirms critical runtime state still appears.

### Task 2.5: Evaluate A Minimal `More/Details` Expansion
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Assess whether a simple compact-mode `More/Details` affordance can be added with minimal complexity by reusing the current object/button event flow. If it adds meaningful state complexity, object churn, or confusing interaction, skip it for the initial implementation and document that decision.
- **Dependencies**: Task 2.2, Task 2.4
- **Acceptance Criteria**:
  - The feature is implemented only if it remains low-complexity and fits the existing event model.
  - If implemented, it reveals hidden compact rows without breaking the primary toggle button behavior.
  - If not implemented, compact mode remains shippable without it and the omission is documented.
- **Validation**:
  - Manual click smoke on compact charts.
  - Compile gate passes either with the lightweight affordance or with a documented omission.

## Sprint 3: Event Integration And First-Paint Correctness
**Goal**: Ensure the panel recalculates at the right times and does not remain stuck in a bad initial layout.
**Demo/Validation**:
- Attaching the EA to a chart produces a correct initial panel more reliably.
- Resizing the chart or causing a major chart change recalculates the panel.
- Repeated ticks do not cause unnecessary full object churn when layout inputs have not changed.

### Task 3.1: Add Layout Snapshot Caching And Dirty-State Tracking
- **Location**: `services/frontend/lightweight_status_ui.mqh`
- **Description**: Cache chart width, chart height, active profile, and last rendered row model. Mark the layout dirty only when relevant dimensions, profile, or content change.
- **Dependencies**: Task 1.2, Task 2.2
- **Acceptance Criteria**:
  - Layout recomputation is driven by meaningful changes, not every tick by default.
  - Cache invalidation handles both content changes and chart changes.
  - Switching between `full` and `compact` cleans up stale row objects.
- **Validation**:
  - Compile gate passes.
  - Runtime smoke shows no duplicated/stale row objects after profile changes.

### Task 3.2: Handle `CHARTEVENT_CHART_CHANGE` In The EA Event Flow
- **Location**: `HFT_Grid_AI.mq5`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Extend `OnChartEvent()` so chart-change events trigger layout invalidation and a safe refresh path, while preserving existing button click behavior.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Click handling still toggles the manual state.
  - Chart changes trigger a panel relayout.
  - The implementation avoids heavy redraw loops during resize storms by diffing cached dimensions or using threshold-based updates.
- **Validation**:
  - Manual resize QA on native Windows and Wine.
  - Basic runtime smoke remains stable.

### Task 3.3: Make First Initialization Deterministic
- **Location**: `HFT_Grid_AI.mq5`, `services/frontend/ea_license_light_version.mqh`, `services/frontend/lightweight_status_ui.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Ensure the panel has a reliable initial render path. Use a first-render invalidation on startup, re-check chart dimensions on the first available refresh, and force repaint with `ChartRedraw()` when the first object batch is created or when profile changes.
- **Dependencies**: Task 3.1, Task 3.2
- **Acceptance Criteria**:
  - Initial attach does not depend on an arbitrary sequence of later ticks to correct a broken width assumption.
  - If initial dimensions are unavailable or stale, the panel retries on the next safe refresh.
  - First visible panel is not the legacy narrow/truncated version on supported charts.
- **Validation**:
  - Attach EA to a fresh chart on Windows and Wine and confirm the first rendered panel is readable.
  - Basic runtime smoke remains clean.

## Sprint 4: Validation, Documentation, And Safe Rollout
**Goal**: Ship the responsive panel with measurable verification and a controlled fallback path.
**Demo/Validation**:
- Compile gate passes.
- Basic runtime smoke passes.
- Manual QA checklist is complete for native Windows and Wine.

### Task 4.1: Add Or Update Frontend-Focused Tests
- **Location**: `tests/harness/cases/lightweight_status_layout_test_case.mqh`, `tests/lightweight_status_layout_test.mq5`, `tests/hft_grid_ai_tests_harness.mq5`
- **Description**: Expand the layout tests to cover regression cases discovered during implementation, especially compact-mode row priority and stale-object cleanup assumptions.
- **Dependencies**: Sprint 2 and Sprint 3 implementation complete
- **Acceptance Criteria**:
  - Responsive layout behavior has at least one dedicated automated test entry in the harness.
  - Regression scenarios for long strings and profile transitions are covered.
- **Validation**:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --symbol EURUSD --period M1 --fast`

### Task 4.2: Run Manual Visual QA Matrix
- **Location**: `README.md` or a short run note under `docs/research/` if needed
- **Description**: Perform and record a manual QA checklist for:
  - native Windows MT5,
  - Wine on Ubuntu 22.04,
  - wide chart,
  - medium chart,
  - small/laptop-sized chart,
  - initial attach,
  - major chart resize,
  - manual toggle click after relayout.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Each target scenario has a pass/fail observation.
  - Any remaining edge cases are documented before release.
- **Validation**:
  - Screenshot-based QA by the user.
  - Final compile/runtime smoke rerun if fixes are applied after QA.

### Task 4.3: Add A Temporary Fallback And Document Expected Behavior
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `README.md`
- **Description**: Keep a temporary internal rollback path during rollout, such as a small isolated legacy layout branch or a guarded fallback constant, until native Windows QA is accepted. Add a brief README note describing that the lightweight panel now auto-selects a compact layout on constrained charts.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - Rollback can be performed without undoing unrelated frontend cleanup.
  - README briefly describes the new responsive behavior and validation expectation.
- **Validation**:
  - Compile gate passes with fallback path present.
  - Fallback path is removable after manual QA signoff.

## Testing Strategy
- Keep tests focused on deterministic layout decisions, not pixel-perfect screenshots.
- Add pure-function tests around:
  - profile selection by chart width/height,
  - width/height bounds,
  - constrained-chart margin reduction / placement fallback,
  - row-priority reduction for compact mode,
  - long-string compaction behavior,
  - single-live-signal compact behavior,
  - stale row cleanup decisions across profile switches.
- Use the project runner for strict compile and basic harness smoke:
  - `./scripts/run_mql5_tests.sh --compile-only`
  - `./scripts/run_mql5_tests.sh --symbol EURUSD --period M1 --fast`
- Reserve visual fidelity verification for manual QA on:
  - native Windows MT5,
  - Wine on Ubuntu 22.04,
  - small and wide charts.

## Potential Risks & Gotchas
- `ChartSetInteger`, `ChartSetString`, and similar chart operations are asynchronous.
  - **Mitigation**: use `ChartRedraw()` after initial object creation and profile transitions.
- `CHARTEVENT_CHART_CHANGE` may fire repeatedly during resize.
  - **Mitigation**: diff cached chart dimensions/profile and ignore no-op changes.
- Native Windows font rendering may still differ from Wine even with the same font name.
  - **Mitigation**: avoid relying on a single per-character pixel heuristic; prefer profile-based layout and aggressive compact summaries.
- Chart dimensions may not be stable at the earliest startup moment.
  - **Mitigation**: treat first render as retryable and re-evaluate on the next safe refresh cycle.
- Existing object names are stable, so switching layout profiles can leave stale rows if cleanup is incomplete.
  - **Mitigation**: explicitly delete rows beyond the active compact/full row count and invalidate caches on profile change.
- Adding a second interactive compact-mode control can complicate the event model and create accidental toggle ambiguity.
  - **Mitigation**: implement `More/Details` only if it can reuse the current click handling cleanly; otherwise defer it.
- There may be no reliable chart-object-specific text measurement API that matches final rendered width on every platform.
  - **Mitigation**: keep the layout deterministic and robust without requiring pixel-perfect text measurement.

## Rollback Plan
- Keep the responsive layout work isolated to frontend files and event wiring:
  - `HFT_Grid_AI.mq5`
  - `services/frontend.mqh`
  - `services/frontend/lightweight_status_layout.mqh` if added
  - `services/frontend/lightweight_status_ui.mqh`
  - related test files
- During rollout, preserve a small temporary fallback path to the pre-responsive layout logic until native Windows QA passes.
- If release QA fails, disable the new profile-selection branch, keep the existing click/toggle behavior, and revert only the responsive layout files and associated tests in a dedicated rollback commit.
