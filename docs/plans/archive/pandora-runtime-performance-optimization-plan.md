# Plan: Pandora Runtime Performance Optimization

**Generated**: 2026-06-16
**Status**: Completed and archived on 2026-06-16
**Estimated Complexity**: High
**Risk Class**: Trading-safety sensitive

## Overview

Optimize Pandora Strategy Tester and idle runtime cost without changing the
current trading behavior. The implementation should stay inside the existing
`OnTick` pipeline and avoid new user inputs. The default behavior remains
functionally equivalent: Pandora must still detect breakouts on tick when it is
inside the valid work window, manage active local/broker positions every tick,
respect protection/session/market guards, and finish the day exactly as it does
now.

The optimization has three safe layers:

- Tester-only frontend throttling: chart objects and `Comment()` should update
  on new chart bars, or immediately when active trading/error state requires it,
  instead of every tick.
- Pandora work-window gating: skip expensive Pandora detection outside the
  relevant preparation and operating windows, while still maintaining daily
  state cheaply.
- Pandora done idle mode: after Pandora has completed the day and no Pandora
  signal, broker position, pending retry, or force-close request remains, skip
  heavy signal/frontend/protection loops until the next relevant day/window.

No new inputs should be added. Internal defaults:

- Prewarm bars: `2`.
- Prewarm timeframe: chart timeframe `_Period`.
- Primary operating window: `Session_Time_Filter` when enabled.
- Pandora box preparation window: `Pandora_Box_Time_Range`, because the EA must
  still compute the box before looking for post-window breakouts.
- Tester visualization throttle: new chart bar on `_Period`; live/demo remains
  responsive unless the EA is fully idle and Pandora done.

## External References

- MQL5 `OnTick`: `NewTick` events are generated for EAs and handled
  sequentially; if a `NewTick` event is already queued or processing, another is
  not added. This supports keeping the per-tick path cheap.
  <https://www.mql5.com/en/docs/event_handlers/ontick>
- MQL5 `EventSetTimer`: timer events use their own queue and are not a good
  replacement for Strategy Tester tick processing in this feature. The plan
  keeps optimization in `OnTick`.
  <https://www.mql5.com/en/docs/eventfunctions/eventsettimer>

## Prerequisites

- Read `docs/planner-execution-discipline.md` before implementation.
- Execute Sprints strictly in order; this is a trading-safety-sensitive plan, so
  prefer one Sprint per batch unless the user explicitly approves more.
- Do not add inputs unless the user revises this plan.
- Do not change include topology or license flow.
- Do not disable per-tick lifecycle management while any Pandora signal or
  matching broker position is active.
- Use the project compile gate after every Sprint:

```powershell
if (Test-Path -LiteralPath 'BUILD.log') { Remove-Item -LiteralPath 'BUILD.log' }
& cmd.exe /c '"C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /portable /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"'
Get-Content -LiteralPath 'BUILD.log' | Select-Object -Last 30
Remove-Item -LiteralPath 'BUILD.log'
```

## Sprint 1: Runtime Classification Helpers

**Goal**: Add cheap, centralized predicates that classify whether Pandora needs
full per-tick work, light maintenance, or idle skipping.
**Commit**: `perf: classify Pandora runtime work states`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Manual review confirms helpers do not open, close, or alter trades.
- Existing default breakout/deep-entry control flow is unchanged.

### Task 1.1: Add Internal Performance Constants

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add internal constants near existing Pandora constants:
  `PANDORA_PERFORMANCE_PREWARM_BARS = 2` and any tiny derived helper needed to
  resolve `_Period` seconds safely.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - No new `input` declarations.
  - `_Period` is used for prewarm calculations.
  - Invalid/zero period seconds fallback to 60 seconds.
- **Validation**:
  - Compile.
  - Manual diff review of constants only.

### Task 1.2: Add Active Entity Predicate

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - optional helper reuse from `services/trading_signals/protection_risk_filter.mqh`
- **Description**: Add a cheap predicate such as
  `PandoraHasRuntimeActiveEntities()` that returns true when any Pandora signal
  is active, a Pandora first-entry observation is active, a broker retry is
  pending, or a matching symbol/magic broker position exists.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Symbol and magic-number scope are preserved.
  - Position scanning is only used in predicates that must prove no broker
    position remains.
  - Running signal arrays are checked before broker position scans.
- **Validation**:
  - Compile.
  - Manual review against `PandoraHasActiveSignals()` and existing magic/symbol
    filtering patterns.

### Task 1.3: Add Work Window Predicate

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/session_time_filter_manager.mqh` only if a small
    reusable session-window helper is needed
- **Description**: Add a predicate such as `PandoraRuntimeWorkWindowActive()`
  that returns true when current time is near or inside the relevant Pandora
  work window. The predicate should combine:
  - Pandora box preparation around `Pandora_Box_Time_Range`.
  - Session filter operating windows when any session filter is enabled.
  - All-hours behavior when session filters are disabled.
  - Two `_Period` bars of prewarm before relevant start/end boundaries.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Wrapped Pandora windows continue to work.
  - Invalid Pandora window returns conservative true rather than skipping work.
  - If session filters are off, Pandora is not incorrectly disabled after box
    close before day completion.
- **Validation**:
  - Compile.
  - Manual time math review for normal and wrapped windows.

### Task 1.4: Add Runtime Mode Predicate

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a final predicate such as `PandoraRuntimeRequiresFullTick()`
  and/or `PandoraRuntimeCanUseIdleFastPath()` that combines active entities,
  force-close pending state, daily completion, work-window activity, market
  status, and day reset needs.
- **Dependencies**: Tasks 1.1-1.3.
- **Acceptance Criteria**:
  - Full tick remains true if active Pandora lifecycle work exists.
  - Idle fast path is allowed only when Pandora is done for the day and no
    active entities or force-close requests exist.
  - Helper is cheap enough to call from `OnTick`.
- **Validation**:
  - Compile.
  - Manual review against `PandoraFinishedForDay()` and `MarketStatusHasPendingForceClose()`.

## Sprint 2: Tester Frontend Throttle

**Goal**: Reduce Strategy Tester chart/comment overhead first, with no trading
behavior changes.
**Commit**: `perf: throttle Pandora tester visualization`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- In tester, frontend updates only on new `_Period` bar while idle.
- Live/demo chart behavior remains unchanged unless Pandora is fully idle and
  done.

### Task 2.1: Add Frontend Refresh Decision

- **Location**:
  - `services/frontend/grid_visualization.mqh`
- **Description**: Add a helper that decides whether frontend refresh should run
  on the current tick. It should return true when:
  - Not in tester.
  - A new `_Period` bar appears in tester.
  - Any running signal exists.
  - Market status/error state changed.
  - Pandora has active runtime entities.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - No `OnTimer` dependency.
  - Tester throttle is based on chart-bar time, not wall-clock timer.
  - No chart/comment refresh is skipped while active trades need visual tracking.
- **Validation**:
  - Compile.
  - Manual tester run can confirm comments change on new bars.

### Task 2.2: Gate `RefreshGridVisualization()`

- **Location**:
  - `services/frontend/grid_visualization.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Either make `RefreshGridVisualization()` internally return
  early when not due, or wrap the calls in `OnTick()` with the frontend refresh
  predicate.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Existing object cleanup still runs when visualization is disabled or state
    changes.
  - `Comment("")` is not called every tick unnecessarily in tester.
  - Live panel behavior stays current.
- **Validation**:
  - Compile.
  - Visual smoke in tester: summary still appears and updates per new bar.

### Task 2.3: Keep Active Signal Visualization Immediate

- **Location**:
  - `services/frontend/grid_visualization.mqh`
  - `services/frontend/pandora_box_visualization.mqh`
- **Description**: Ensure active local observation, broker retry, live trade, or
  close marker states bypass the idle tester throttle.
- **Dependencies**: Tasks 2.1-2.2.
- **Acceptance Criteria**:
  - `First_Entry_Sl_1` and `First_Entry_Sl_2` observation lines remain visible
    while active.
  - Close markers do not disappear due to throttling.
- **Validation**:
  - Compile.
  - Manual Strategy Tester visual check on one deep-entry scenario.

## Sprint 3: Pandora Detection Work-Window Gate

**Goal**: Skip Pandora signal detection outside relevant work windows while
preserving breakout timing inside the active window.
**Commit**: `perf: gate Pandora detection by runtime window`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Pandora detection still runs tick-by-tick when the box is closed and the
  session/work window allows entries.
- Detection is skipped while far outside session/box windows and no active
  Pandora work exists.

### Task 3.1: Add Detection Gate Entry Point

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Add a small gate near the top of `PandoraDetectSignals()` that
  uses Sprint 1 predicates to return early outside work windows.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - `PandoraSyncRuntimeConfig()`, day anchor reset, and window parsing still run
    when required for daily state maintenance.
  - The gate returns conservative true when state is invalid or ambiguous.
  - Active observations and open positions always keep detection/lifecycle
    available.
- **Validation**:
  - Compile.
  - Manual review against `PandoraComputeBoxWindow()` and `PandoraWindowCompleted()`.

### Task 3.2: Preserve Box Preparation

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure `PandoraComputeBoxWindow()` still runs when the box
  window closes, even if the session filter operating window starts later.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Box values are ready before breakout detection.
  - Box range invalidation still happens once per day.
  - Wrapped boxes remain valid.
- **Validation**:
  - Compile.
  - Manual tester check around the exact box close minute.

### Task 3.3: Preserve Session Filter Semantics

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/session_time_filter_manager.mqh`
- **Description**: Confirm the new detection gate does not bypass
  `Pandora_Box_Use_Session_Filter`, session entry permissions, or force-close
  behavior.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance Criteria**:
  - If session filter is enabled, entries are only attempted inside session.
  - If the session closes after being active, Pandora still marks the day
    finished as currently implemented.
  - Pending force-close queues are not skipped.
- **Validation**:
  - Compile.
  - Manual review of `SessionTimeFilterAllowsSignalAttempt()` and
    `SessionTimeFilterMonitorRuntime()` call sites.

## Sprint 4: Pandora Done Idle Fast Path

**Goal**: After Pandora completes the day and no active work remains, run only
minimal maintenance until the next relevant day/window.
**Commit**: `perf: add Pandora done idle fast path`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- After `PANDORA DONE`, no heavy signal detection, lifecycle, UI, or protection
  scans run every tick when no active entities exist.
- New day resets still occur and Pandora can trade the next day.

### Task 4.1: Add Minimal Maintenance Function

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - optional call site in `HFT_Grid_AI.mq5`
- **Description**: Add a lightweight maintenance function for idle mode that
  refreshes runtime config, ensures day anchor reset, and parses the window only
  when needed.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - New D1 anchor resets `finished`, counters, markers, and box state.
  - Maintenance does not run `CopyRates()` history scans unless needed.
  - Invalid window state remains visible for frontend when refreshed.
- **Validation**:
  - Compile.
  - Manual review around `PandoraResetDailyState()`.

### Task 4.2: Add `OnTick()` Idle Branch

- **Location**:
  - `HFT_Grid_AI.mq5`
- **Description**: Add an early branch after essential price/license/platform
  state has been maintained. If Pandora is done, no active entities exist, and
  no force-close is pending, skip `Main()`, `Main_Tick()`, and heavy frontend
  refresh until the frontend/new-day predicates require them.
- **Dependencies**: Task 4.1 and Sprint 2.
- **Acceptance Criteria**:
  - No early return while running signal arrays are non-empty.
  - No early return while matching symbol/magic broker positions exist.
  - No early return while market force close is pending.
  - Daily reset remains possible on the next day.
- **Validation**:
  - Compile.
  - Manual walkthrough of `OnTick()` order.

### Task 4.3: Preserve Market Closed And Spread Behavior

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/market_status_controller.mqh`
- **Description**: Ensure the idle branch does not change current spread block,
  market-open block, or market-status behavior when active trading work exists.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Active positions still process close/protection logic during spread blocks as
    currently intended.
  - The EA does not silently skip broker error/close-only states during active
    lifecycle.
- **Validation**:
  - Compile.
  - Manual diff review of early-return ordering.

## Sprint 5: Idle-Only Protection And Market Status Throttle

**Goal**: Reduce per-tick protection/market scans only when the EA is completely
idle, without weakening safety while trades are active.
**Commit**: `perf: throttle idle Pandora protection checks`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Protection remains per-tick while any signal/position/force-close exists.
- When idle and far outside work windows, protection/status checks run only on
  new minute or new chart bar.

### Task 5.1: Add Idle Throttle Predicate

- **Location**:
  - `HFT_Grid_AI.mq5`
  - optional helper in `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a static timestamp/bar-time gate for idle-only checks.
  Use existing `next_minute_bar_open` style where possible.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - No new timer.
  - No throttling while active entities exist.
  - No throttling while market force close is pending.
- **Validation**:
  - Compile.
  - Manual review of all paths that call `ProtectionRiskFilterTick()`.

### Task 5.2: Gate Idle Protection Calls

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/protection_risk_filter.mqh` only if a pure helper
    is needed
- **Description**: Apply the idle throttle to `ProtectionRiskMonitorTradeMode()`
  and `ProtectionRiskFilterTick()` only when fully idle.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Drawdown protection remains unchanged when positions exist.
  - Broker disabled/close-only force-close remains unchanged when positions
    exist.
  - Daily/weekly protection lock reset still happens before new signal attempts.
- **Validation**:
  - Compile.
  - Manual risk review against `ProtectionRiskHasActiveEntities()`.

### Task 5.3: Ensure Signal Attempt Gates Stay Fresh

- **Location**:
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/market_status_controller.mqh`
- **Description**: Confirm that throttling idle checks cannot leave stale status
  that blocks valid signal attempts when entering the work window.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Work-window re-entry forces fresh market/protection status before detection.
  - `ProtectionRiskAllowsSignalAttempt()` still refreshes daily lock state.
- **Validation**:
  - Compile.
  - Manual tester transition from outside session to session prewarm.

## Sprint 6: Documentation And Final Hardening

**Goal**: Document the optimization behavior, validate the final diff, and hand
off manual Strategy Tester checks.
**Commit**: `docs: document Pandora performance gates`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- `BUILD.log` is inspected and removed.
- Final diff review confirms no order-entry, lot sizing, license, or broker
  stop semantics changed.

### Task 6.1: Document Performance Behavior

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Add a short note that Strategy Tester visualization is
  throttled by chart bar while idle, and Pandora runtime work is skipped after
  daily completion when no active lifecycle work remains.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - No new user configuration is documented.
  - Notes clearly state trading lifecycle remains per-tick while active.
- **Validation**:
  - Manual docs review.

### Task 6.2: Final Diff And Hot-Path Review

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/frontend/grid_visualization.mqh`
  - `services/frontend/pandora_box_visualization.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
- **Description**: Review the final code for hot-path cost, early-return order,
  and trading safety invariants.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - No full-history scans added to `OnTick`.
  - No unbounded `ArrayResize`, logging, or object churn added.
  - No license, magic-number, order-send, or broker-close semantics changed.
- **Validation**:
  - `git diff --check`
  - MetaEditor compile.

### Task 6.3: Manual Strategy Tester Handoff Checklist

- **Location**:
  - `docs/plans/pandora-runtime-performance-optimization-plan.md`
- **Description**: Add execution notes after implementation with exact commits,
  compile results, and recommended manual tester scenarios.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Checklist includes default breakout, `First_Entry_Off`, SL1/SL2 observation,
    day done, session outside/inside transition, and tester visualization.
  - The user can compare tester speed manually with the same symbol/date/config.
- **Validation**:
  - Manual docs review.

## Execution Notes

- Sprint batch executed in order from Sprint 1 through Sprint 6.
- Sprint 1 commit: `9f5c5e9` (`Sprint 1: classify Pandora runtime work states`).
- Sprint 2 commit: `297edeb` (`Sprint 2: throttle Pandora tester visualization`).
- Sprint 3 commit: `6a07529` (`Sprint 3: gate Pandora detection by runtime window`).
- Sprint 4 commit: `a34df03` (`Sprint 4: add Pandora done idle fast path`).
- Sprint 5 commit: `ebc9c79` (`Sprint 5: throttle idle Pandora protection checks`).
- MetaEditor compile gate passed after every implementation Sprint with
  `0 errors, 0 warnings`; `BUILD.log` was inspected and removed after each run.
- Sprint 6 final compile gate passed on 2026-06-16 with `0 errors, 0 warnings`.
- Manual Strategy Tester speed comparison remains a user handoff item. Use the
  same symbol, date range, model, inputs, and visual/comment settings before and
  after this batch when comparing runtime.
- Recommended manual tester scenarios for this exact batch:
  - Long range with most ticks outside the configured session filter.
  - Pandora day completes early with `Pandora_Box_Stop_On_First_Win = true`.
  - Default `First_Entry_Breakout` near session activation.
  - `First_Entry_Off` local-only close.
  - `First_Entry_Sl_1` observation discard and market admission.
  - `First_Entry_Sl_2` stage advance and market admission.
  - Session transition from outside window to prewarm to active.
  - Tester visual mode with `Enable_Chart_Summary = true`.

## Testing Strategy

- Run MetaEditor compile after each Sprint and remove `BUILD.log` after reading
  the result.
- Use focused Strategy Tester visual checks when runtime behavior matters. No CI
  matrix is required.
- Recommended manual tester scenarios:
  - Long range with most ticks outside session filter.
  - Pandora day completes early with `Pandora_Box_Stop_On_First_Win = true`.
  - Default `First_Entry_Breakout` near session start.
  - `First_Entry_Off` local-only close.
  - `First_Entry_Sl_1` observation discard and market admission.
  - `First_Entry_Sl_2` stage advance and market admission.
  - Session filter transition from outside to prewarm to active.
  - Tester visual mode with chart summary enabled.
- Validation target is functional preservation first, speed second. The user will
  perform the final before/after Strategy Tester speed comparison manually.

## Potential Risks & Gotchas

- `Pandora_Box_Time_Range` is not the full operating window. It defines the box
  window; breakout trading happens after the box closes and is filtered by
  session logic. The gate must account for both.
- If session filters are disabled, treating the EA as outside operating hours
  would be a behavior bug. Default to all-hours after box preparation until
  Pandora completes the day.
- `First_Entry_Sl_1` and `First_Entry_Sl_2` can be active local observations
  with no broker position. These must count as active lifecycle work.
- `OnTimer` should not be introduced for tester performance. Keep this feature
  in `OnTick` with new-bar gates.
- UI throttling must not delete active observation lines or close markers.
- Protection throttling must only apply while fully idle; any active position,
  signal, retry, local observation, or force-close request restores per-tick
  safety checks.
- Daily reset is easy to break if the done-idle branch returns too early. Idle
  maintenance must still call the minimal day-anchor/window maintenance needed
  to rearm the next day.

## Rollback Plan

- Revert Sprint commits in reverse order.
- If only UI throttling causes issues, revert Sprint 2 and keep runtime helpers
  unused.
- If work-window gating causes missed entries, revert Sprints 3-5 first and keep
  documentation/helper commits only if harmless.
- After rollback, run MetaEditor compile, inspect `BUILD.log`, delete it, and
  manually confirm default `First_Entry_Breakout` behavior still matches current
  production behavior.
