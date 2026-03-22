# Plan: Lightweight Status UI Text-Fit Fix

**Generated**: 2026-03-20
**Estimated Complexity**: High

## Overview
This plan supersedes the earlier responsive-panel plan and is driven by the Wine vs native Windows diagnostic logs:

- `logs/ui_wine_logs.log` shows a readable `FULL` panel on Wine and a clean transition to `COMPACT` at `444x359`.
- `logs/ui_windows_logs.log` shows native Windows staying in `FULL` mode down to `628x1196`, with the full panel already pinned to its minimum width of `260px`.
- In both environments, `actual_panel` matches `panel`, which means object placement is working; the failure is text-fit and content-density, not chart-size retrieval.

The fix should therefore move from simple chart-threshold responsiveness to a content-aware fit model that:
- promotes `COMPACT` earlier when full mode is already width-constrained,
- budgets against total rendered row length, not only the value substring,
- collapses dense secondary content before the panel becomes unreadable,
- hardens typography and spacing for native Windows MT5 without breaking Wine.

Success means the panel remains readable on native Windows and Wine across wide, medium, and constrained charts without relying on pixel-perfect parity.

## Prerequisites
- Keep all work aligned with the include chain defined in `AGENTS.md`.
- Treat `services/frontend/lightweight_status_layout.mqh` and `services/frontend/lightweight_status_ui.mqh` as the primary ownership boundary for this fix.
- Use the current diagnostics in `logs/ui_wine_logs.log` and `logs/ui_windows_logs.log` as the baseline regression evidence.
- Keep the removable `[UI_DIAG]` instrumentation available during implementation until manual QA is accepted.
- Validation scope remains:
  - strict compile gate,
  - basic harness/runtime smoke,
  - manual visual QA by the user on native Windows and Wine.
- Product assumptions carried forward:
  - compact mode is acceptable,
  - low-priority rows may collapse,
  - one live signal row should remain visible in compact mode,
  - margins may shrink slightly on constrained charts,
  - a low-complexity `More/Details` affordance may stay if it still serves the compact model.

## Sprint 1: Reframe Layout Around Fit Pressure
**Goal**: Replace the current chart-size-only layout contract with a fit-pressure contract grounded in the diagnostic logs.
**Demo/Validation**:
- Layout helpers can express why a snapshot becomes `FULL`, `COMPACT`, or “compact-forced”.
- Tests reproduce the known Wine and Windows log cases as deterministic inputs.

### Task 1.1: Capture The Known Failure Envelope In Code-Level Fixtures
- **Location**: `tests/harness/cases/lightweight_status_layout_test_case.mqh`, `services/frontend/lightweight_status_layout.mqh`
- **Description**: Add synthetic fixtures based on the diagnostic logs, including:
  - Wine readable full states such as `1219x359` with `11` rows.
  - Windows constrained full states such as `817x1196`, `776x1196`, and `628x1196` with `14` rows.
  - Windows compact transition at `438x1196`.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Test data mirrors the evidence gathered from the current logs.
  - The failure cases are named explicitly so future regressions can be diagnosed by snapshot.
- **Validation**:
  - Compile-only test gate passes.
  - New tests are visible in the harness output.

### Task 1.2: Introduce A Fit-Pressure Input Model
- **Location**: `services/frontend/lightweight_status_layout.mqh`
- **Description**: Extend the pure layout layer so profile selection can see more than chart width and height. Add inputs such as:
  - total candidate rows,
  - hidden/collapsible row count,
  - longest total row length,
  - presence of multi-signal detail rows,
  - whether full mode has already hit its minimum width.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Profile selection no longer depends on chart dimensions alone.
  - The layout layer can express “this chart is large, but the current content is too dense for full mode”.
- **Validation**:
  - Helper tests compile and exercise the new input model.

### Task 1.3: Define A Stable Compact Escalation Policy
- **Location**: `services/frontend/lightweight_status_layout.mqh`, `docs/plans/lightweight-status-ui-text-fit-fix-plan.md`
- **Description**: Encode explicit escalation rules for when full mode must yield to compact or denser summaries. Candidate rules:
  - force compact if full mode resolves to its minimum width and row count exceeds a safe threshold,
  - force compact if the longest total row materially exceeds the predicted safe row budget,
  - keep full mode only when both width pressure and row-density pressure are below threshold.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - The escalation policy is deterministic and documented in code comments.
  - The policy explains why Windows should compact much earlier than it does now.
- **Validation**:
  - Tests cover at least one forced-compact and one full-retained case.

## Sprint 2: Fix Width Budgeting At The Row Level
**Goal**: Stop underestimating text width by budgeting only the value portion of each row.
**Demo/Validation**:
- Long rows no longer escape the width budget because of long labels.
- Compact and pressured full states generate shorter, safer row text before rendering.

### Task 2.1: Replace Value-Only Clamping With Total-Row Budgeting
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `services/frontend/lightweight_status_layout.mqh`
- **Description**: Refactor row construction so width budgeting is applied to the entire visible row, not only to the value substring. This likely means:
  - deriving a per-profile total row character budget,
  - optionally splitting label and value budgets,
  - clamping after the final `label + ": " + value` text is assembled.
- **Dependencies**: Sprint 1 complete
- **Acceptance Criteria**:
  - A row with a long label can no longer exceed the intended budget simply because the value was clamped first.
  - The layout helper exposes the budget used for full and compact rows.
- **Validation**:
  - Tests cover long `Block Reason`, `Purchased Addons`, and signal summary rows.

### Task 2.2: Add Pressure-Specific Short Forms For Dense Rows
- **Location**: `services/frontend/lightweight_status_ui.mqh`
- **Description**: Introduce safer short forms that activate before the panel becomes unreadable. Examples:
  - shorten labels such as `Requested (Inputs)` when under pressure,
  - reduce addon summaries to a compact count/summary form,
  - condense signal detail rows into one live row plus aggregate status earlier than today,
  - shorten block/source labels only in pressured layouts if needed.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - The row builder can produce different text for relaxed full, pressured full, and compact states.
  - Important runtime state remains visible even after summarization.
- **Validation**:
  - Fixture-based tests verify that dense Windows scenarios produce shorter rows than the current implementation.

### Task 2.3: Make Full Mode Degrade Gracefully Before Hard Compact
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `services/frontend/lightweight_status_layout.mqh`
- **Description**: Add an intermediate pressure response inside full mode so it can summarize low-priority rows earlier, instead of staying visually “full” until the compact breakpoint is finally crossed.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Full mode under width pressure shows fewer verbose secondary rows than relaxed full mode.
  - The UI does not jump directly from overloaded full content to compact only at the last moment.
- **Validation**:
  - Tests cover a medium-width Windows-like case where pressured full differs from relaxed full.

## Sprint 3: Harden Typography And Vertical Spacing
**Goal**: Reduce the native Windows rendering penalty from font metrics and fixed row spacing.
**Demo/Validation**:
- The same logical row set yields a safer visual result on native Windows.
- Overlap risk is reduced even when MT5 renders text larger than Wine.

### Task 3.1: Centralize A Safer Typography Profile
- **Location**: `services/frontend/lightweight_status_layout.mqh`
- **Description**: Rework typography tokens so font family, font size, button size, row step, and padding are tuned as a coherent profile. Prefer more conservative defaults than the current `Verdana/9` with `row_step=14` if the new fit model still predicts risk on Windows.
- **Dependencies**: Sprint 2 complete
- **Acceptance Criteria**:
  - Typography and spacing decisions are fully centralized.
  - One change point can tune both Windows and Wine behavior without hunting through object setup code.
- **Validation**:
  - Compile gate passes.
  - Snapshot tests verify updated metrics are used by both full and compact profiles.

### Task 3.2: Increase Vertical Safety Margins For Native Windows-Like Cases
- **Location**: `services/frontend/lightweight_status_layout.mqh`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Introduce a more conservative row-step strategy so rows do not sit on the edge of overlap. Options include:
  - larger default row step,
  - larger row step only when row count is high,
  - a pressured-layout typography profile that sacrifices density for legibility.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - The layout contract explicitly favors readability over squeezing in maximum rows.
  - No layout path assumes Wine-like font height as a universal truth.
- **Validation**:
  - Tests verify panel height math remains valid after row-step changes.
  - Manual QA confirms less vertical collision risk on Windows.

### Task 3.3: Keep Diagnostics Focused On Fit Decisions
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `services/trading_management/ea_inputs.mqh`, `README.md`
- **Description**: Adjust the current debug logs so they continue to expose the inputs and decisions that matter for this fix:
  - fit pressure / compact-forced reason,
  - total-row budget,
  - longest row length,
  - effective row count before and after summarization,
  - typography profile chosen.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Diagnostics explain why a profile was selected.
  - Future QA can compare Wine and Windows with the new fit model using the same log workflow.
- **Validation**:
  - Compile gate passes.
  - Manual dry run confirms the log output remains grep-friendly.

## Sprint 4: Validate, Document, And De-Risk Rollout
**Goal**: Confirm the new fit model solves the observed Windows failure cases without regressing Wine.
**Demo/Validation**:
- Compile gate passes cleanly.
- Runtime smoke passes.
- Manual visual QA confirms readable output on both environments.

### Task 4.1: Expand Automated Regression Coverage Around Logged Cases
- **Location**: `tests/harness/cases/lightweight_status_layout_test_case.mqh`, `tests/hft_grid_ai_tests_harness.mq5`
- **Description**: Turn the current Wine and Windows log snapshots into persistent regression tests, especially:
  - Windows width `628` should no longer remain overloaded full,
  - full-mode minimum-width cases should trigger pressure behavior,
  - long addon/signal rows should not bypass total-row budgets.
- **Dependencies**: Sprints 1-3 complete
- **Acceptance Criteria**:
  - The bug evidence is directly represented in automated tests.
  - A future refactor cannot silently restore the old late-compact behavior.
- **Validation**:
  - `bash ./scripts/run_mql5_tests.sh --compile-only`
  - `bash ./scripts/run_mql5_tests.sh --symbol EURUSD --period M1 --fast`

### Task 4.2: Run Manual QA Matrix Against Wine And Native Windows
- **Location**: `README.md` or `docs/research/` run notes if needed
- **Description**: Re-run the user’s visual QA matrix with diagnostics available:
  - native Windows MT5,
  - Wine on Ubuntu 22.04,
  - wide chart,
  - medium chart,
  - constrained/laptop-sized chart,
  - initial attach,
  - major chart resize,
  - compact expansion control if retained.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Both environments have before/after observations for the logged regression cases.
  - Any residual edge cases are documented with screenshots or logs before the next iteration.
- **Validation**:
  - User-provided screenshots and `[UI_DIAG]` blocks.

### Task 4.3: Remove Or Downgrade Temporary Diagnostics After Signoff
- **Location**: `services/frontend/lightweight_status_ui.mqh`, `README.md`, `docs/plans/archive/lightweight-status-ui-responsive-plan-2026-03-20.md`
- **Description**: Once the new fit model is accepted, reduce the diagnostic surface:
  - keep the flag but shorten log output, or
  - document removal if the instrumentation is no longer needed.
  Also record that this plan replaced the archived chart-threshold-only plan.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - The repo does not keep verbose debug logging enabled by default after rollout.
  - The plan lineage is documented clearly enough for future maintainers.
- **Validation**:
  - Compile gate passes after the final diagnostic posture is chosen.

## Testing Strategy
- Keep the automated focus on deterministic fit decisions, not screenshot comparisons.
- Cover these dimensions in the harness:
  - chart width and height,
  - total candidate row count,
  - longest total row length,
  - full-mode minimum-width pressure,
  - signal density,
  - addon-summary density,
  - profile transitions between relaxed full, pressured full, and compact.
- Continue using the project runner:
  - `bash ./scripts/run_mql5_tests.sh --compile-only`
  - `bash ./scripts/run_mql5_tests.sh --symbol EURUSD --period M1 --fast`
- Keep manual QA focused on the exact environments that exposed the regression: native Windows MT5 and Wine on Ubuntu 22.04.

## Potential Risks & Gotchas
- MT5 does not expose reliable real text measurement for these objects, so the fix still depends on safer heuristics rather than true font metrics.
- Over-correcting toward compact mode could make wide charts look unnecessarily sparse if thresholds are too aggressive.
- Shortening whole rows may hide too much context unless priority and summary rules are explicit and tested.
- Typography changes that help Windows could visually regress Wine if spacing is not validated on both platforms.
- If the compact expansion control remains, its behavior must stay low-complexity and not create stale-object or event-handling regressions.

## Rollback Plan
- Keep the current responsive implementation available in git history via the archived plan and isolated frontend commits.
- If the new fit model regresses readability, revert the layout/profile-selection changes in:
  - `services/frontend/lightweight_status_layout.mqh`
  - `services/frontend/lightweight_status_ui.mqh`
  - related layout tests
- Retain the diagnostic flag until native Windows and Wine QA both pass, so rollback decisions can be evidence-based rather than screenshot-only.
