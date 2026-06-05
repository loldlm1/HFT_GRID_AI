# Plan: Pandora Local Deterministic Execution

**Generated**: 2026-06-03
**Estimated Complexity**: Critical / Trading-Sensitive

## Overview

Pandora Box must consume or reserve its entry budget from the first eligible
Pandora breakout event, but the statistical source of truth must now be
broker-realistic rather than purely theoretical. The EA should observe the local
signal deterministically, then anchor the active position to broker conditions:
an actual broker fill wins; otherwise a broker-simulated local anchor uses the
current executable side of the quote when spread and market state allow it.

The active source-of-truth entry drives local SL, TP, trailing, markers, and
statistics. If a later broker retry succeeds, the real broker fill replaces any
previous broker-simulated anchor completely. When `Pandora_Box_Set_Broker_SLTP =
true`, broker-side SL/TP remains an additional server protection layer: it may
start wider than the configured local levels if broker stop/freeze rules require
it, and the EA should keep trying to tighten it to the active source-of-truth
local target when it becomes legal. Any broker modification failure must be
non-fatal to the local lifecycle.

This plan applies only to Pandora Box. Non-Pandora grid behavior, license
contracts, magic-number scope, shared backend entitlement logic, and general
grid strategy semantics are out of scope.

## Confirmed Decisions

- Scope is Pandora Box only.
- Source-of-truth priority is:
  1. Real broker fill, including a successful retry.
  2. Broker-simulated local anchor from current executable Bid/Ask when no real
     fill exists.
  3. The theoretical breakout trigger as metadata only, never as the active
     SL/TP anchor.
- A broker-simulated Pandora entry stays alive until local virtual SL/TP closes
  it, even when no broker position exists.
- If a broker-simulated local entry closes by local SL/TP before a retry fills,
  all future retries for that entry are cancelled.
- Spread above range should not create an active broker-realistic local
  position. The breakout/budget may be reserved as pending, but the active local
  anchor is created only after spread returns inside range.
- Broker rejections may trigger a bounded Pandora-only broker retry budget when
  the failure is classified as transient. A successful retry updates the local
  position completely to the actual broker fill and redraws the marker from the
  real entry.
- The retry drift/envelope remains developer-controlled through the existing
  internal symbol-derived multiplier defaults; once an accepted fill occurs, the
  fill is the only active source of truth.
- `Pandora_Box_Max_Entries = 1` means one Pandora source-of-truth entry per
  Pandora day/window, even if the broker never opens a real position.
- `Pandora_Box_Set_Broker_SLTP = true` means "attempt broker protection" only;
  local SL/TP still owns lifecycle and statistics from the active
  source-of-truth entry.
- SL and TP share the same philosophy: compute exact local targets from the
  active source-of-truth entry and configured Pandora points. Broker protection
  may be wider temporarily, then tightened toward those exact targets when broker
  rules allow it.
- Pandora trailing runs from the active source-of-truth entry. For example, with
  `250` configured points, the first step is reached after `250` points from the
  real fill or broker-simulated anchor, not from the old theoretical trigger.
- Market closed, trading disabled, or close-only states should not be simulated
  as normal local trades. Other broker open failures may still create a
  broker-realistic local entry when spread is inside range and the EA can model
  the executable quote.
- Chart labels should stay simple and Spanish ASCII, for example:
  `Posicion local - ERR_Spread` and `Posicion ejecutada`.
- Rejected local entries should avoid backend schema changes. If an existing
  reporting path requires a compatible close outcome, map the rejected-local
  marker to BE while preserving the local rejection reason in EA state, logs,
  and chart UI.
- Execute this plan one Sprint per batch. Complete validation and create one
  brief commit per completed Sprint before continuing, unless the user forbids
  commits or git is unavailable.

## Current Supersession Note

Sprints 1-9 document the completed path that introduced local deterministic
execution, broker diagnostics, and controlled retries. Sprint 10 is a deliberate
revision of the source-of-truth contract. When Sprint 10 conflicts with older
Sprint text about high-spread local creation or preserving the original local
entry after retry fill, Sprint 10 and the current confirmed decisions win.

## Prerequisites

- Read `AGENTS.md` and `docs/planner-execution-discipline.md` before executing.
- Preserve symbol and magic-number scoping for positions, deals, history, and
  cleanup.
- Preserve session, daily budget, protection risk, market status, license, and
  debug-stop guards.
- Use existing broker, price, volume, margin, and chart helper boundaries where
  practical.
- Validate with MetaEditor compile after each code Sprint:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

## Sprint 1: Local Pandora Execution Model

**Goal**: Add explicit local-vs-broker execution state for Pandora without
changing behavior yet.

**Demo/Validation**:
- MetaEditor compile passes.
- Existing Pandora behavior remains unchanged.
- Diff shows only state/model helpers and no execution behavior changes.

### Task 1.1: Define Local/Broker Status Enums

- **Location**:
  - `microservices/core/enums.mqh`
- **Description**: Add Pandora-specific execution status enums for local entry
  state and broker execution state. Keep names explicit and Pandora-scoped,
  such as `PANDORA_LOCAL_ENTRY_ACTIVE`, `PANDORA_BROKER_EXECUTED`, and
  `PANDORA_BROKER_REJECTED`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - New enums are Pandora-specific and do not change existing grid status
    meanings.
  - Existing enum values are not reordered.
- **Validation**:
  - MetaEditor compile.

### Task 1.2: Extend Signal/Grid State With Pandora Execution Fields

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add fields needed to persist deterministic local entry,
  broker result, rejection reason, retcode, last error, local close marker, and
  broker SL/TP sync state.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Constructors initialize all new fields.
  - Copy constructor copies all new fields.
  - Existing non-Pandora signal defaults are unaffected.
- **Validation**:
  - MetaEditor compile.
  - Manual constructor/copy diff review.

### Task 1.3: Add Lightweight Formatting Helpers

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - or nearest existing Pandora helper boundary
- **Description**: Add helper functions to format broker rejection reasons and
  UI labels using Spanish ASCII.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Label strings are ASCII only.
  - Retcode/detail formatting is compact and does not expose account data.
- **Validation**:
  - MetaEditor compile.

## Sprint 2: Deterministic Entry Admission Before Broker Blocks

**Goal**: Ensure Pandora can observe and register a valid local breakout even
when spread blocks broker actions.

**Demo/Validation**:
- With forced high spread, Pandora consumes `Pandora_Box_Max_Entries = 1` when
  the breakout occurs locally.
- No broker send is attempted while spread guard blocks broker actions.
- Existing session/protection/daily/license gates still apply.

### Task 2.1: Split Pandora Observation From Broker Execution

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Introduce a Pandora observation path that can run before the
  early `g_points_spread > Max_Spread` return. It should detect and build the
  local Pandora signal, but defer broker actions to lifecycle code.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Spread no longer prevents deterministic Pandora entry registration.
  - Market closed and platform disabled behavior is not broadened accidentally.
  - Non-Pandora `Main()` and normal broker lifecycle remain gated as before.
- **Validation**:
  - MetaEditor compile.
  - Tester/manual high-spread scenario confirms local entry is registered.

### Task 2.2: Consume Pandora Entry Budget On Local Trigger

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Treat local signal creation as the opened-entry budget event.
  Keep the current `total_entries` budget semantics, but make sure it is reached
  for spread-blocked local entries.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `Pandora_Box_Max_Entries = 1` prevents a second local entry after the first
    deterministic trigger.
  - Re-entry still requires the existing Pandora rearm rules after local close.
- **Validation**:
  - MetaEditor compile.
  - Tester/manual one-entry scenario with high spread then normal spread.

### Task 2.3: Preserve Body Candle One-Shot Semantics

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Confirm body-mode processed candle stamps still prevent
  same-candle reuse when local entry registration succeeds but broker execution
  is blocked.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - The same body candle cannot create a second Pandora entry.
  - A rejected broker send does not reset body candle processing.
- **Validation**:
  - MetaEditor compile.
  - Manual/tester body-mode scenario with repeated ticks.

## Sprint 3: Broker Send Result Classification And No-Retry Behavior

**Goal**: Make Pandora broker execution a one-shot attempt per local entry, with
correct `CTrade` retcode/deal classification.

**Demo/Validation**:
- Broker rejection leaves the local Pandora entry active and does not retry the
  broker send.
- Successful broker execution stores position ticket when available.
- Retcode failures are visible in market error status and local rejection state.

### Task 3.1: Add Pandora Broker Attempt Guard

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Ensure Pandora attempts broker execution at most once for a
  local entry. Store a broker-attempted flag/state before returning from any
  guardrail or trade-send path.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Spread/margin guardrail block marks broker attempt as blocked/rejected.
  - Later ticks do not resend the same local Pandora entry.
  - Non-Pandora grid retry behavior is unchanged unless explicitly shared code
    must be factored with a Pandora condition.
- **Validation**:
  - MetaEditor compile.
  - High-spread tester/manual run shows no repeated `ORDER_SEND_FAILED` spam.

### Task 3.2: Validate `CTrade` Retcode And Deal

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: After `g_position.Buy()` or `g_position.Sell()`, check
  `ResultRetcode()` and `ResultDeal()`/resolved position ticket. Treat only
  successful trade-server completion as broker execution.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - `TRADE_RETCODE_DONE` and valid deal/ticket mark broker executed.
  - `TRADE_RETCODE_DONE_PARTIAL` is handled deliberately, with volume/ticket
    review and clear logging.
  - `INVALID_STOPS`, `INVALID_VOLUME`, `NO_MONEY`, `REJECT`, `PRICE_CHANGED`,
    and similar retcodes mark broker rejected while keeping local active.
  - `CTrade` returning `true` without execution no longer marks local order as
    broker executed.
- **Validation**:
  - MetaEditor compile.
  - Forced invalid stops/volume scenario if practical.

### Task 3.3: Local Rejected Outcome Compatibility

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - shared daily result paths only if already touched by Pandora close flow
- **Description**: Keep `local_rejected` as local state/UI/log data. Avoid
  backend schema changes. If an existing backend-compatible outcome is required
  for a rejected-local event, map it to BE while preserving the local rejection
  reason outside backend contracts.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - No backend/shared license contract changes are required.
  - Local Pandora counters remain deterministic.
  - Actual broker PnL is not fabricated as a real broker deal.
- **Validation**:
  - MetaEditor compile.
  - Diff review for backend/shared license files.

## Sprint 4: Local SL/TP Lifecycle As Source Of Truth

**Goal**: Make exact local SL/TP close Pandora positions whether or not a broker
position exists, and regardless of `Pandora_Box_Set_Broker_SLTP`.

**Demo/Validation**:
- A broker-rejected local entry closes on virtual SL/TP.
- A broker-executed entry still closes locally when the exact local target is
  reached, even if broker protection is wider.
- Existing Pandora trailing mode remains consistent.

### Task 4.1: Always Evaluate Local Pandora Stops

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Refactor Pandora lifecycle so exact local SL/TP checks run
  for active local entries independently of broker-side SL/TP input.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - `Pandora_Box_Set_Broker_SLTP` no longer disables local SL/TP evaluation.
  - Local-only entries complete without requiring a position ticket.
  - Broker-executed entries request broker close when local SL/TP hits.
- **Validation**:
  - MetaEditor compile.
  - Tester/manual local-only SL and TP closure scenarios.

### Task 4.2: Preserve Step-Trailing Semantics Locally

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure `PANDORA_RISK_TRAILING_STEP_TP` updates the local
  trailing stop and outcome exactly as before, while broker modify remains a
  best-effort protection update.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Step index and local trailing stop update without requiring a broker ticket.
  - Broker modify failure does not block local trailing update.
  - Local close outcome remains deterministic.
- **Validation**:
  - MetaEditor compile.
  - Tester/manual step-trailing scenario if available.

### Task 4.3: Close And Cleanup Local-Only Signals

- **Location**:
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/market_signal_cleanup.mqh`
- **Description**: When local-only Pandora completes, mark close time, local
  close price, local outcome, rearm requirement, and visualization persistence
  without trying to close a non-existent broker position.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - No repeated close attempts for `position_ticket = 0`.
  - Pandora rearm state updates after local-only close.
  - Daily/open/close counters stay coherent.
- **Validation**:
  - MetaEditor compile.
  - Local-only close scenario with `Pandora_Box_Max_Entries = 1`.

## Sprint 5: Broker SL/TP Protection Synchronization

**Goal**: Attach and maintain broker-side protection without altering local
Pandora statistics or lifecycle.

**Demo/Validation**:
- If exact local stops are invalid at entry, broker protection is placed wider
  when possible.
- The EA later tightens broker SL/TP toward exact local targets when legal.
- Rejected broker modifications are logged but do not change local lifecycle.

### Task 5.1: Split Local Target Stops From Broker-Safe Stops

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/utils/broker_constraints_helper.mqh`
  - `microservices/utils/price_math.mqh` if tick rounding helper reuse is needed
- **Description**: Add separate helpers for exact local SL/TP and broker-safe
  SL/TP. Broker-safe levels must respect symbol tick size, stops level, freeze
  level, and the correct current opposite price for Buy/Sell protection.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Local target helpers return exact configured strategy levels.
  - Broker-safe helpers can widen protection but never tighten beyond local
    targets in a way that would alter strategy statistics.
  - Prices are normalized to symbol digits and tick size.
- **Validation**:
  - MetaEditor compile.
  - Unit-style manual calculations for Buy and Sell with known Bid/Ask/spread.

### Task 5.2: Use Broker-Safe Protection On Initial Send

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: When `Pandora_Box_Set_Broker_SLTP = true`, send exact local
  stops only if legal. Otherwise send wider legal protection or no server stops
  if no legal protection can be derived before entry.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Initial `INVALID_STOPS` frequency is reduced.
  - If protection is widened, local target levels remain unchanged.
  - If opening without broker stops is unavoidable, the local lifecycle still
    protects the strategy and an error/status label makes this visible.
- **Validation**:
  - MetaEditor compile.
  - Forced close-stop-distance scenario.

### Task 5.3: Tighten Broker Stops Opportunistically

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: During active Pandora lifecycle, check whether broker SL/TP
  can be modified closer to the exact local target. Run from `OnTick()` lifecycle
  with throttling to avoid trade-server spam; one-second throttling is acceptable
  if implemented with existing time fields or a Pandora-specific timestamp.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Exact target modification is attempted only when local validation says it is
    legal.
  - Server rejection remains non-fatal and is retried later with throttling.
  - Modification checks do not run for local-only rejected entries with no
    broker ticket.
  - No noisy per-tick `Print` output unless existing logs/debug are enabled.
- **Validation**:
  - MetaEditor compile.
  - Tester/manual scenario where stops become legal after price movement.

## Sprint 6: Pandora Trade Markers And Daily Visual Persistence

**Goal**: Draw simple Spanish ASCII markers for local and broker-executed
Pandora operations, and keep them visible for the current day/session.

**Demo/Validation**:
- Local rejected entry draws an entry marker, projected/actual local close
  segment, and label like `10$ (Posicion local - ERR_Spread)`.
- Broker executed entry draws equivalent marker and label like
  `20$ (Posicion ejecutada)`.
- Objects persist after signal cleanup and are removed on day rollover/deinit.

### Task 6.1: Add Persistent Pandora Marker State

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Store enough marker snapshot data at local entry and local
  close to draw closed operations after the running signal is removed.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Marker snapshots have unique names using day/time/direction/sequence data.
  - Snapshots do not depend on broker ticket existence.
  - Snapshot count is bounded to avoid unbounded chart/object growth.
- **Validation**:
  - MetaEditor compile.
  - Diff review for array resizing and cleanup.

### Task 6.2: Draw Entry/Close Marker Objects

- **Location**:
  - `services/frontend/grid_visualization.mqh`
  - `services/frontend/pandora_box_visualization.mqh`
  - `microservices/frontend/chart_panel_utils.mqh`
  - `microservices/frontend/grid_visual_utils.mqh`
- **Description**: Add minimal chart objects for entry arrow, close arrow, dotted
  segment, and close label. Use existing tracked object helpers where practical.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - UI labels are Spanish ASCII.
  - Object names are unique and do not collide with current direction-only grid
    line names.
  - Chart object churn stays low; no per-tick recreation when object state is
    unchanged.
- **Validation**:
  - MetaEditor compile.
  - Visual check in Strategy Tester or live demo chart.

### Task 6.3: Cleanup And Rollover

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/frontend/grid_visualization.mqh`
  - `services/trading_signals/market_signal_cleanup.mqh`
- **Description**: Keep markers during the active Pandora day, then clear them
  on day reset/deinit along with other frontend objects.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Closed markers remain visible after signal arrays remove completed entries.
  - Markers do not persist across a new Pandora day unless explicitly stored as
    historical snapshots.
  - `ClearFrontendVisualization()` removes marker objects.
- **Validation**:
  - MetaEditor compile.
  - Manual day-reset/deinit cleanup check.

## Sprint 7: Documentation, Manual Checklist, And Final Verification

**Goal**: Document the new Pandora-local semantics and validate the full flow
against expected trading behavior.

**Demo/Validation**:
- Documentation explains local-vs-broker execution clearly.
- MetaEditor compile passes.
- Manual/tester checklist covers spread, invalid stops, broker success, and
  local SL/TP closure. This is not a headless MT5 test matrix.

### Task 7.1: Update Pandora User Documentation

- **Location**:
  - `README.md`
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Document that `Pandora_Box_Max_Entries` counts deterministic
  local entries; broker SL/TP is best-effort protection; rejected broker entries
  can remain active locally until virtual SL/TP.
- **Dependencies**: Sprints 1-6.
- **Acceptance Criteria**:
  - Docs do not promise broker execution when local entry exists.
  - Docs explain `local_rejected` and chart marker labels.
  - Docs explain that broker stops may be wider temporarily.
- **Validation**:
  - Proofread docs.

### Task 7.2: Add Tester/Manual Regression Checklist

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - or a new focused checklist under `docs/guides/` if the existing guide would
    become too long
- **Description**: Add a concrete manual validation checklist for high spread,
  invalid stops, invalid volume/no money, broker success, local-only SL,
  local-only TP, and broker stop tightening.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - Each scenario lists inputs/setup, expected logs/status, expected chart label,
    and expected entry budget/counter behavior.
  - Checklist distinguishes local statistics from broker history.
- **Validation**:
  - Proofread checklist.

### Task 7.3: Final Compile And Diff Review

- **Location**:
  - Entire project
- **Description**: Run final MetaEditor compile, inspect `BUILD.log`, inspect
  git diff, and verify no unrelated files or backend/license contracts changed.
- **Dependencies**: Task 7.2.
- **Acceptance Criteria**:
  - Compile has no errors.
  - Warnings are reviewed and either resolved or explicitly accepted.
  - Diff is scoped to Pandora lifecycle, broker stop safety, chart markers, and
    docs.
- **Validation**:
  - MetaEditor compile command from this plan.
  - `git diff --check`.
  - Manual diff review.

## Sprint 8: Broker Send Failure Diagnostics

**Goal**: Make failed broker open attempts explainable without changing Pandora
entry decisions, broker retry behavior, local deterministic lifecycle, or
statistics.

**Demo/Validation**:
- A failed broker open records a concise panel label plus a richer file/journal
  diagnostic with retcode, runtime error, broker comment, CTrade description,
  request snapshot, symbol constraints, and account/market context.
- `TRADE_RETCODE_ERROR` + `ERR_TRADE_SEND_FAILED` is classified as a generic
  broker/terminal send failure instead of an ambiguous local strategy error.
- MetaEditor compile passes, `BUILD.log` is inspected, and `BUILD.log` is removed
  after verification.
- No headless Strategy Tester matrix tests are added or required.

### Task 8.1: Add Broker Failure Diagnostic Snapshot

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `microservices/trading_signals/grid_order_logging.mqh`
  - supporting helpers only if an existing local boundary clearly fits
- **Description**: On failed `g_position.Buy()` / `g_position.Sell()`, log a
  compact diagnostic snapshot that includes direction, symbol, volume, requested
  SL/TP, local entry reference, bid/ask/spread, magic, comment, retcode,
  `GetLastError()`, `ResultRetcodeDescription()`, and `ResultComment()`.
- **Dependencies**: Sprints 1-7.
- **Acceptance Criteria**:
  - No change to whether a Pandora local entry is opened, blocked, rejected,
    retried, or closed.
  - Full diagnostic output is gated through existing logging/file-log paths so
    the hot path is not noisy by default.
  - Logs do not include account numbers, license keys, backend tokens, or
    proprietary optimization sets.
- **Validation**:
  - MetaEditor compile.
  - Manual diff review of open-order failure paths.

### Task 8.2: Add Pre-Send OrderCheck Diagnostics

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - existing broker/order helper modules if a reusable request builder is needed
- **Description**: Before Pandora broker sends, run an `OrderCheck()` diagnostic
  for the same market order parameters when feasible and record `check.retcode`,
  `check.comment`, `check.margin`, `check.margin_free`, and
  `check.margin_level`. Treat the result as diagnostics only; do not block a send
  unless the existing guardrails already block it.
- **Dependencies**: Task 8.1.
- **Acceptance Criteria**:
  - `OrderCheck()` diagnostics help distinguish no-money, invalid parameter,
    invalid stops, trade-disabled, and generic broker-processing errors.
  - A failed or inconclusive `OrderCheck()` does not alter local deterministic
    Pandora state by itself.
  - Request fields match the broker send path closely enough for useful
    diagnosis: action, symbol, type, volume, price side, SL, TP, magic, comment,
    filling, and time type.
- **Validation**:
  - MetaEditor compile.
  - Manual log review in Strategy Tester or demo chart when a broker rejection
    can be reproduced.

### Task 8.3: Improve Concise Error Classification

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/market_status_controller.mqh` only if needed for
    panel summary formatting
- **Description**: Add a clearer short reason for generic send failures such as
  `TRADE_RETCODE_ERROR` plus `ERR_TRADE_SEND_FAILED`, for example
  `ERR_Send_Failed` or `ERR_Broker_Common`, while keeping the raw `ret` and
  `err` values visible.
- **Dependencies**: Task 8.1.
- **Acceptance Criteria**:
  - The panel stays compact and does not overflow the existing status summary.
  - Raw codes remain available for exact broker/support escalation.
  - Existing specific mappings (`ERR_Stops`, `ERR_Volumen`, `ERR_Margen`,
    `ERR_Spread`, etc.) are preserved.
- **Validation**:
  - MetaEditor compile.
  - Review sample formatted strings against the current panel width.

### Task 8.4: Validation And Build Log Hygiene

- **Location**:
  - Entire project
  - `AGENTS.md`
- **Description**: Compile with the project MetaEditor command, inspect
  `BUILD.log`, report errors/warnings, then remove `BUILD.log` after verification.
  Do not add automated/headless MT5 Strategy Tester matrix tests.
- **Dependencies**: Tasks 8.1-8.3.
- **Acceptance Criteria**:
  - Compile has no errors.
  - Warnings are reviewed and either resolved or explicitly accepted.
  - `BUILD.log` is absent after the verified compile result is recorded.
  - Diff is scoped to broker-send diagnostics and documentation/instructions.
- **Validation**:
  - MetaEditor compile command from this plan.
  - Read `BUILD.log`, then delete `BUILD.log`.
  - `git diff --check`.
  - Manual diff review.

## Sprint 9: Controlled Pandora Broker Retry Budget

**Goal**: Add a bounded broker execution retry layer for Pandora local entries
without changing the deterministic local entry lifecycle or local statistics.

**Demo/Validation**:
- MetaEditor compile passes with `0 errors, 0 warnings`.
- `BUILD.log` is removed after verification.
- A transient broker open failure can move to retry-pending state and later
  execute within the configured budget/window.
- Permanent failures still become final local-only broker rejections.
- Local entry time/price, local SL/TP, and `Pandora_Box_Max_Entries` semantics
  remain unchanged.

### Task 9.1: Add Retry Developer Defaults And State

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
  - `microservices/core/enums.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add Pandora-only developer defaults for total broker open
  attempts, minimum seconds between attempts, maximum retry window, and current
  symbol-derived maximum entry drift. Add retry-pending state and per-signal
  counters/timestamps.
- **Dependencies**: Sprint 8.
- **Acceptance Criteria**:
  - Defaults are conservative: 3 total attempts, 1 second minimum spacing,
    5 second window, and bounded price drift.
  - Constructors initialize all new state and copy constructors preserve it.
  - Non-Pandora state and inputs are unaffected.
- **Validation**:
  - MetaEditor compile.
  - Manual constructor/copy diff review.

### Task 9.2: Classify Retryable And Final Broker Failures

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Treat only transient failures as retryable: common send
  error, price changed/off, requote, timeout, connection, too many requests, and
  spread guard blocks inside the retry window. Keep invalid volume, no money,
  disabled/closed market, invalid fill, and persistent invalid stops final.
- **Dependencies**: Task 9.1.
- **Acceptance Criteria**:
  - A retryable failure marks broker status as retry-pending, not final rejected.
  - Final failures still produce local-only rejection labels and do not retry.
  - Retry decisions keep raw retcode/error diagnostics visible.
- **Validation**:
  - MetaEditor compile.
  - Manual diff review of failure branches.

### Task 9.3: Execute Eligible Retries From Active Local Lifecycle

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: While a Pandora local entry remains active and has no broker
  ticket, retry broker open only when the retry budget, spacing, window, spread,
  drift, and no-duplicate-position checks pass. A successful retry attaches the
  broker ticket without moving local entry statistics.
- **Dependencies**: Task 9.2.
- **Acceptance Criteria**:
  - Retries do not happen after local SL/TP closes.
  - Retries do not happen when a matching broker position already exists.
  - Retry success marks broker executed while preserving local entry price/time.
  - Retry exhaustion or drift/window expiry finalizes the broker side as
    local-only rejected.
- **Validation**:
  - MetaEditor compile.
  - Manual Strategy Tester/demo review for transient failure when practical.

### Task 9.4: Document Retry Developer Defaults And Hygiene

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - optional language guides if touched by the public input table
- **Description**: Document the retry developer defaults, default policy, and
  the fact that retries affect broker execution only, not local statistics. Keep
  ASCII text.
- **Dependencies**: Tasks 9.1-9.3.
- **Acceptance Criteria**:
  - Public guide describes internal total attempts, spacing, window, and
    symbol-derived drift defaults without exposing them as MT5 inputs.
  - Regression checklist includes controlled retry expectations.
  - `BUILD.log` is deleted after verified compilation.
- **Validation**:
  - MetaEditor compile.
  - Read and delete `BUILD.log`.
  - `git diff --check`.

## Sprint 10: Broker-Realistic Source Of Truth

**Goal**: Rebase Pandora local lifecycle, SL/TP, trailing, statistics, and
markers to broker-realistic execution conditions instead of the theoretical
breakout anchor.

**Sprint 10 Supersession Note**:
- Sprint 9 intentionally preserved the local deterministic entry after a retry.
  Sprint 10 revises that contract: bounded retry controls remain, but a
  successful broker fill now becomes the only active source of truth.
- Earlier local-only semantics remain useful only when no real broker fill
  exists. In that case, the local anchor must be a broker-simulated executable
  quote, not the theoretical trigger.

**Demo/Validation**:
- MetaEditor compile passes with `0 errors, 0 warnings`.
- `BUILD.log` is inspected and removed after verification.
- A high-spread breakout reserves/prevents duplicate Pandora entry behavior but
  does not create an active local position until spread returns inside range.
- A broker-simulated local entry uses the current executable quote side as
  entry: Ask for buy, Bid for sell.
- A retry fill replaces the broker-simulated entry, recalculates exact local
  SL/TP from the real fill, resets trailing anchors as needed, and redraws the
  visual marker from the real entry.
- The US30-style case is corrected: if a sell fills at `49196.3` with `250`
  points and `_Point = 0.1`, exact local SL should be based around `49221.3`
  unless broker-side protection must be wider temporarily.

### Task 10.1: Add Pandora Source-Of-Truth State

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add explicit Pandora execution-source state and anchor fields
  for theoretical trigger price, broker-simulated entry, broker fill entry,
  active source-of-truth entry, source timestamp, and pending spread admission.
- **Dependencies**: Sprint 9.
- **Acceptance Criteria**:
  - Constructors initialize all new fields.
  - Copy constructors preserve all source-of-truth and pending-admission state.
  - The theoretical trigger remains available for logs/debugging but does not
    drive active SL/TP after Sprint 10.
  - Non-Pandora signals remain unaffected.
- **Validation**:
  - MetaEditor compile.
  - Manual constructor/copy diff review.

### Task 10.2: Create Broker-Realistic Local Admission

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: When a valid Pandora breakout occurs, reserve the entry
  budget deterministically. If spread is outside range, keep the event pending
  and do not create an active local position. Once spread and market state are
  valid, create the active local position from the current executable broker
  quote side and compute exact local SL/TP from that anchor.
- **Dependencies**: Task 10.1.
- **Acceptance Criteria**:
  - High spread cannot create a second Pandora entry while the first breakout is
    pending.
  - No active local SL/TP or chart entry marker is created until a
    broker-realistic anchor exists.
  - Buy anchors use Ask; sell anchors use Bid.
  - Market closed, trading disabled, and close-only states do not create normal
    local simulated trades.
  - Other broker open failures can still leave a broker-realistic local entry
    active when spread is inside range and the executable quote was known.
- **Validation**:
  - MetaEditor compile.
  - Manual/tester high-spread then normal-spread scenario.
  - Diff review for session, daily budget, license, and protection gates.

### Task 10.3: Rebase On Real Broker Fill Or Retry Fill

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/frontend/*` or existing Pandora marker helper boundaries if marker
    snapshots are stored there
- **Description**: When initial broker send or any eligible retry fills, replace
  the current local anchor with the actual broker fill price/time/ticket. Recompute
  exact local SL/TP from the fill, refresh broker protection against the new
  targets, reset trailing anchors that depend on entry, and redraw the marker
  from the real entry.
- **Dependencies**: Task 10.2.
- **Acceptance Criteria**:
  - `PandoraMarkBrokerExecuted` and retry success paths no longer preserve an
    older broker-simulated or theoretical entry.
  - The accepted retry drift/envelope still limits whether a retry can fill, but
    after acceptance the real fill wins completely.
  - Existing broker ticket, symbol, magic, and comment scoping remain intact.
  - Visual labels remain simple Spanish ASCII and do not expose extra backend
    fields.
- **Validation**:
  - MetaEditor compile.
  - Manual diff review of retry success and marker update paths.

### Task 10.4: Align Local SL/TP, TP, And Trailing To Active Anchor

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_management_strategies/*` only if Pandora trailing glue
    requires it
- **Description**: Ensure local stop, take-profit, and trailing checks always
  use the active source-of-truth entry. If a broker-simulated local entry reaches
  SL/TP before a retry fills, close it locally and cancel future retries.
- **Dependencies**: Task 10.3.
- **Acceptance Criteria**:
  - Local SL/TP never close from the old theoretical entry after a broker fill or
    broker-simulated anchor exists.
  - Fixed TP uses the same source-of-truth philosophy as SL.
  - `PANDORA_RISK_TRAILING_STEP_TP` starts from the active anchor and activates
    only after the configured points threshold from that anchor.
  - Once trailing has legitimately moved the stop to BE/profit, the initial SL
    distance is no longer enforced as a separate close rule.
  - A local SL/TP close before retry fill cancels the retry state.
- **Validation**:
  - MetaEditor compile.
  - Manual review of SL/TP and trailing calculations against points mode.

### Task 10.5: Update Documentation And Validation Checklist

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
  - `docs/plans/pandora-local-deterministic-execution-plan.md`
- **Description**: Document the broker-realistic source-of-truth model, retry
  rebase behavior, spread-pending admission, and temporary wider broker
  protection policy. Keep Spanish UI text ASCII where examples are shown.
- **Dependencies**: Tasks 10.1-10.4.
- **Acceptance Criteria**:
  - Docs no longer promise that retry success preserves the original local
    entry.
  - Docs explain that theoretical trigger price is diagnostic metadata only.
  - Regression checklist includes the US30 fill-vs-SL distance scenario.
  - `BUILD.log` is deleted after verified compilation.
- **Validation**:
  - MetaEditor compile.
  - Read and delete `BUILD.log`.
  - `git diff --check`.
  - Manual doc proofread.

## Testing Strategy

- **Compile gate**: Run MetaEditor compile after every implementation Sprint.
- **Focused manual tester/demo scenarios**:
  - Do not build or require headless MT5 matrix tests; MT5 Strategy Tester
    validation is manual/visual unless a future local runner is explicitly added.
  - `Pandora_Box_Max_Entries = 1`, high spread at breakout, normal spread later:
    one Pandora entry is reserved/pending only; the active local anchor is
    created from the current executable quote only after spread returns inside
    range.
  - Broker invalid stops: local entry remains active from the broker-realistic
    anchor, broker rejection is recorded, local SL/TP closes from the active
    anchor, and broker protection can start wider then tighten when legal.
  - Broker success with widened protection: local close triggers at exact local
    target from the real fill or broker-simulated anchor before any wider broker
    TP/SL can alter statistics.
  - Broker retry success: accepted retry fill replaces previous local anchor,
    recalculates local SL/TP, and redraws the entry marker from the real fill.
  - Broker stop tightening: initial wide stop later tightens to exact local
    level when valid; rejection is non-fatal and retried with throttle.
  - US30 points scenario: with `250` points and `_Point = 0.1`, a sell fill at
    `49196.3` should derive exact local SL around `49221.3`, not from an older
    theoretical trigger.
  - Body entry mode: same closed candle cannot be reused after local entry.
  - `Pandora_Box_Set_Broker_SLTP = false`: local lifecycle still works with no
    broker stop attempts.
- **Visual QA**:
  - Verify entry/close arrows, dotted segment, and Spanish ASCII label.
  - Verify markers persist after signal cleanup and clear on deinit/day reset.
- **Safety QA**:
  - Confirm magic-number and symbol filtering are preserved.
  - Confirm session, daily signal limit, protection risk, market status, and
    license fail-closed paths are not loosened.
  - Confirm no backend/license shared contract changes unless explicitly
    requested later.

## Potential Risks & Gotchas

- Running Pandora observation before the spread return can accidentally bypass
  other safety gates. Mitigation: only move spread out of the local observation
  path; keep license, platform permission, session, daily budget, protection
  risk, and concurrency gates explicit.
- A local-only entry has no real broker PnL. Mitigation: keep broker/backend
  reporting separate from local Pandora statistics and expose `local_rejected`
  only in local state/UI/logs unless a compatible BE mapping is required.
- If local SL/TP closes a real broker position while broker TP/SL is wider, the
  close request can fail. Mitigation: preserve existing broker close failure
  handling and keep market status/error visibility.
- Broker stop validation can pass locally and still fail server-side because
  price changed. Mitigation: treat modify failure as expected/non-fatal and
  retry with throttling while local lifecycle remains active.
- Chart object names currently use direction-only names for some grid lines.
  Mitigation: marker objects must include a unique Pandora signal identifier to
  avoid collisions.
- Widened broker TP can theoretically close later than local TP; widened broker
  SL can close later than local SL. Mitigation: local lifecycle must close the
  broker position at exact local levels before the wider server protection is
  reached in normal tick flow.
- No-tick periods mean local lifecycle cannot close until a tick arrives.
  Mitigation: document this as normal EA behavior; broker protection remains the
  only server-side protection while no ticks are processed.
- Strategy Tester may not reproduce all broker retcodes. Mitigation: include
  controllable guardrail scenarios plus manual demo-account validation for
  broker-specific behavior; do not model these as required headless matrix tests.
- Broker retry can improve real execution capture but can also create fill-price
  drift versus the original theoretical trigger. Mitigation: keep retry
  attempts, spacing, time window, and symbol-derived max drift bounded; once an
  accepted delayed broker fill occurs, rebase the local anchor and markers to the
  real fill so statistics match broker reality.
- Generic `TRADE_RETCODE_ERROR` / `ERR_TRADE_SEND_FAILED` results can be caused
  by broker-side rules that MT5 does not expose precisely. Mitigation: capture
  request, symbol, account, CTrade result, and OrderCheck diagnostics before
  escalating to broker support.
- Waiting for spread to return before creating the active local anchor can delay
  statistical entry versus the theoretical breakout. Mitigation: reserve the
  Pandora entry/budget while pending so no duplicate entry is created, and record
  the theoretical trigger as metadata for review.

## Rollback Plan

- Revert Sprint commits in reverse order.
- If only broker SL/TP sync causes issues, disable the new tightening behavior
  while preserving local deterministic entry state.
- If local visualization causes chart issues, disable marker drawing while
  preserving local lifecycle.
- If local deterministic behavior must be disabled urgently, restore the old
  `OnTick()` spread return ordering and Pandora broker execution path, then
  recompile and validate `Pandora_Box_Max_Entries` legacy behavior.
