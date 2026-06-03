# Plan: Chart Magic, Order Comments, Algo Status, And Error Visibility

**Generated**: 2026-06-02
**Estimated Complexity**: Critical / Trading-Sensitive

## Overview
Harden the Pandora Box EA so multiple chart instances in the same MT5 terminal do not interfere with each other, trade comments use the requested `pandora_box_pos_n` format, MT5's Algo Trading state blocks EA trade attempts before broker calls, and the chart panel exposes the current and most recent execution error state.

This plan is critical because it touches magic-number identity, order opening, close/recovery paths, broker retcode handling, daily-result attribution, and live UI diagnostics. Execute one Sprint per batch according to `docs/planner-execution-discipline.md`.

The resolved identity approach is to keep the backend as the source of truth for live trade magic, but change the backend contract so magic is scoped by a stable EA chart instance, not only by the shared license lane. A local random magic is not acceptable for live trading because it can orphan open positions after restart and conflict with daily-results filtering by `DEAL_MAGIC`.

## Current Code Findings
- `HFT_Grid_AI.mq5` initializes `g_magic_number` from `LicenseGetCachedMagicNumber()` in live mode and ignores `Custom_Magic` when the backend magic differs.
- `g_position.SetExpertMagicNumber((ulong)g_magic_number)` is the single trade magic assignment point.
- The backend contract in `services/shared/license_guard_v1/backend-entitlements-contract.md` says a lane returns one stable `magic_number`, daily results dedupe by `broker_account + ea_id + magic_number + UTC day`, and missing/invalid magic must fail closed.
- Position and deal ownership is usually scoped by `g_magic_number + _Symbol`, but `GetActivePositionsCount()` in `microservices/trading_signals/grid_order_lifecycle.mqh` filters by magic and direction without checking `_Symbol`.
- Grid entry comments are centralized through `GridComposeLevelComment()` in `microservices/trading_signals/grid_order_helpers.mqh`.
- Hedge orders previously used the literal comment `GRID_HEDGE` in `services/trading_management_strategies/grid_trend_risk_hedge.mqh`.
- `FindOpenPositionForSignal()` uses symbol, direction, and optional comment, but does not filter magic before returning a ticket.
- `OnTick()` in `HFT_Grid_AI.mq5` monitors symbol trade mode and market status, but there is no explicit pre-trade gate for `MQL_TRADE_ALLOWED`, `TERMINAL_TRADE_ALLOWED`, or account expert-trading allowance before `Main()` / `Main_Tick()`.
- `MarketStatusRegisterBrokerFailure()` records only broker-disabled/market-closed style failures; no-money, invalid stops, margin, requote, or generic trade send failures are not surfaced in the frontend unless they also imply closure.
- The compact frontend panel is built in `services/frontend/pandora_box_panel.mqh`; it already shows EA status, magic, market status, and status reason.

## Resolved Product Decisions
- Magic uniqueness must be per EA chart instance. One chart equals one EA instance; symbol and timeframe are not enough to define ownership.
- The backend must issue and accept chart-instance-scoped trade magic. The EA should not invent a live random magic locally.
- The existing license lane remains important for entitlement, heartbeat, and request de-duplication, but trade ownership needs an additional stable chart/EA `instance_id` inside that lane.
- If two charts run equal or different EAs in the same terminal/account, overlap is avoided by giving each EA instance a distinct backend-issued `magic_number` that is numerically unique for that trading account, and by filtering every order/position/deal path by `magic_number + symbol` where symbol scoping is relevant.
- When MT5 Algo Trading is off, the EA is treated as disabled. It must skip all broker actions, including opens, modifications, partial closes, force closes, and hedge actions. Any existing broker-side SL/TP remains responsible for market protection until Algo Trading is enabled again.

## Backend Contract Direction
- Extend license verify/cache data with a stable EA chart `instance_id` sent by the EA.
- Add a lightweight backend path for instance magic allocation, preferably separate from lane heartbeat/verify traffic, so each chart can request its trade magic without turning every chart into a license heartbeat leader.
- Allocate one supported signed-32-bit `magic_number` per `broker_account + ea_id + instance_id` or equivalent backend key, while enforcing that the numeric magic value is unique across all EA instances on the same broker account.
- Keep lane-level leadership/heartbeat semantics for shared license traffic, but do not reuse one lane magic across all chart instances.
- Preserve fail-closed behavior: if the backend cannot return a valid scoped magic for the current `instance_id`, initialization fails.
- Keep daily-results reporting per chart instance magic. This is simpler than leader aggregation and preserves the existing dedupe model: `broker_account + ea_id + magic_number + UTC day`.
- Add a backend contract update document for backend implementation details before EA code changes start.

## Resolved Implementation Defaults
- Persist `instance_id` with the recommended hybrid approach: optional manual input for support/migration, plus auto-generation and local persistence for normal users, plus duplicate detection/regeneration when a cloned chart/template reuses an active ID.
- Report daily results per chart instance magic. Each EA instance reports only the deals for its own runtime trade magic.
- UI shows only the instance-scoped trade magic in the compact panel. Logs/debug output may include lane and `instance_id` for support.

## Production Rollout Order
1. Backend additive rollout first:
   - Add instance-magic allocation support without breaking legacy `/licenses/verify` responses.
   - Keep current lane magic behavior for already deployed EAs.
   - Feature-flag or version-gate the new behavior until tested.
2. Backend validation:
   - Confirm two instance IDs on the same broker account receive different numeric magic values.
   - Confirm the same instance ID receives the same magic after restart.
   - Confirm daily-results accepts the instance-scoped magic.
3. EA staging rollout:
   - Add `instance_id` generation/persistence.
   - Request backend instance magic after license verification.
   - Fail closed if backend instance magic is missing or invalid.
4. Production EA rollout:
   - Deploy to new/flat charts first.
   - Do not switch an existing chart with open legacy-magic positions unless a migration mode is explicitly implemented and tested.
   - For existing production charts, wait until the chart is flat or close/manage legacy positions intentionally before upgrading to instance magic.
   - Simple/safe default: the new EA refuses to initialize on that symbol if legacy lane-magic positions are still open.
5. Cleanup:
   - After all live charts use instance magic, deprecate the old lane magic as a trade identity while keeping lane identity for license traffic.

## Prerequisites
- Preserve the include pipeline in `HFT_Grid_AI.mq5`.
- Keep license changes inside `services/shared/license_guard_v1/*` and EA profile glue in `services/license_service_setup.mqh`.
- Keep new user inputs, if any, in `services/trading_management/ea_inputs.mqh`.
- Use existing broker, price, money, margin, and volume helpers for order paths.
- Preserve fail-closed license behavior; do not add local/random fallback magic in live mode unless the backend contract is explicitly updated.
- Compile with:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

## Sprint 1: Resolve Runtime Magic Identity And Ownership Scope
**Goal**: Make chart/symbol ownership explicit and safe before changing order behavior.
**Demo/Validation**:
- Two charts in the same terminal can show the intended ownership identity in the panel/logs.
- Existing positions remain discoverable after EA restart.
- Daily-results attribution remains compatible with the chosen magic model.

### Task 1.1: Define Backend Instance-Scoped Magic Contract
- **Location**: `docs/plans/chart-magic-comments-algo-status-plan.md`, `services/shared/license_guard_v1/backend-instance-magic-contract-update.md`, `services/shared/license_guard_v1/backend-entitlements-contract.md`, `services/shared/license_guard_v1/README.md`
- **Description**: Record the backend contract update for one magic per EA chart instance while keeping lane-level entitlement/heartbeat behavior.
- **Dependencies**: Backend implementation decision.
- **Acceptance Criteria**:
  - A backend contract update document exists and describes rollout, endpoint/payload, persistence, uniqueness, daily-results, and compatibility.
  - `verify` or a lightweight instance-magic endpoint accepts a stable EA chart `instance_id`.
  - Backend returns a stable `magic_number` for `broker_account + ea_id + instance_id` or the final agreed key.
  - Backend does not assign the same numeric `magic_number` to two active EA instances on the same broker account, even when the EA IDs differ.
  - The license lane remains available for shared heartbeat/entitlement checks.
  - Daily-results behavior is explicitly defined for instance-scoped magic.
  - No implementation uses `MathRand()` or unstable `ChartID()` as live trade identity.
  - Magic values stay within signed 32-bit safe values (`1..2147483647`).
- **Validation**:
  - Manual review against `AGENTS.md` license rules and backend contract.

### Task 1.2: Add Persistent EA Chart Instance ID
- **Location**: `HFT_Grid_AI.mq5`, `services/license_service_setup.mqh`, `services/shared/license_guard_v1/*`
- **Description**: Add a stable `instance_id` for the EA chart instance and send it to the backend before magic resolution.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - The `instance_id` survives EA restart/recompile for the same configured instance.
  - The `instance_id` does not depend only on volatile `ChartID()`.
  - The `instance_id` is unique enough that two chart EAs do not accidentally request the same magic.
  - The `instance_id` contains no account numbers, license tokens, secrets, or broker credentials in logs.
- **Validation**:
  - Compile.
  - Manual attach/restart test confirms the same chart instance requests the same backend magic.

### Task 1.3: Add Explicit Runtime Magic Helper
- **Location**: `HFT_Grid_AI.mq5`, possibly `services/license_service_setup.mqh`
- **Description**: Replace inline magic initialization with a single helper such as `ResolveRuntimeTradeMagicNumber()` that returns the backend-issued instance-scoped live magic and a reason on failure.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Live mode fails closed when backend scoped magic is invalid.
  - Tester mode can still use `Custom_Magic > 0`; otherwise it uses deterministic, documented test identity rather than weak random behavior.
  - `g_position.SetExpertMagicNumber()` receives only the resolved runtime trade magic.
- **Validation**:
  - Compile.
  - Manual init test with valid live license and with invalid/missing scoped magic.

### Task 1.4: Audit All Position/Deal Ownership Filters
- **Location**: `microservices/trading_signals/grid_order_lifecycle.mqh`, `microservices/trading_signals/grid_order_helpers.mqh`, `services/trading_signals/protection_risk_filter.mqh`, `services/trading_management_strategies/grid_trend_risk_hedge.mqh`, `services/trading_signals/pandora_box_state.mqh`, `services/frontend/pandora_box_panel.mqh`, `services/shared/license_guard_v1/daily_results_online.mqh`
- **Description**: Ensure every position/deal path that opens, finds, counts, closes, reports, or displays positions uses the approved runtime magic and correct symbol scope.
- **Dependencies**: Task 1.3.
- **Acceptance Criteria**:
  - `GetActivePositionsCount()` filters `_Symbol` before counting.
  - `FindOpenPositionForSignal()` filters magic as well as symbol/direction/comment.
  - Daily-results deal filtering uses the same trade magic that orders actually use.
  - Hedge close/find paths preserve magic+symbol scoping.
- **Validation**:
  - `rg "POSITION_MAGIC|DEAL_MAGIC|PositionsTotal|HistoryDeal" -n` review confirms no unscoped risky path remains.
  - Compile.
  - Manual multi-symbol smoke: attach to at least two pairs and confirm each chart ignores the other's positions.

## Sprint 2: Rename Trade Comments Without Breaking Recovery
**Goal**: Use the requested `pandora_box_pos_n` comment format while preserving position recovery, history outcome resolution, and hedge handling.
**Demo/Validation**:
- New Pandora entries show comments like `pandora_box_pos_1`, `pandora_box_pos_2`, etc.
- Existing lifecycle code can still find, close, and resolve outcomes for opened positions.

### Task 2.1: Replace Grid Level Comment Composer
- **Location**: `microservices/trading_signals/grid_order_helpers.mqh`
- **Description**: Update `GridComposeLevelComment()` for Pandora/grid position levels to return `pandora_box_pos_n`, where `n` maps to the position-opening sequence rather than raw zero-based internal index if needed.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Comments are lowercase exactly as requested.
  - The numbering is stable for each signal's level state.
  - Comment length remains safe for broker/deal history display.
- **Validation**:
  - Compile.
  - Manual tester/live demo order shows the new comment.

### Task 2.2: Define Hedge Comment Policy
- **Location**: `services/trading_management_strategies/grid_trend_risk_hedge.mqh`
- **Description**: Decide whether hedge orders are part of the requested numbering. If yes, compose a deterministic `pandora_box_pos_n` comment for hedge orders; if no, use a documented companion comment such as `pandora_box_hedge`.
- **Dependencies**: Task 2.1.
- **Chosen Policy**: Hedge orders use `GridComposeHedgeComment()` and reserve a deterministic `pandora_box_pos_n` index outside normal level numbering. Finite grids use `Grid_Level_Stop_Limit + 1`; unlimited grids reserve `pandora_box_pos_9999`.
- **Acceptance Criteria**:
  - Hedge recovery through `FindOpenPositionForSignal()` still works.
  - Hedge comments cannot collide with normal level comments for the same signal.
- **Validation**:
  - Compile.
  - Manual hedge-mode tester scenario if hedge mode is used in production.

### Task 2.3: Preserve History Outcome Matching
- **Location**: `services/trading_signals/pandora_box_state.mqh`, `services/trading_signals/grid_order_controller.mqh`
- **Description**: Confirm `PandoraResolveHistoryOutcomeByComment()` still receives the exact stored `position_comment` and matches by symbol, magic, and comment.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Closed TP/SL outcomes still resolve after comment rename.
  - Existing open positions created before the rename are either supported through stored state or intentionally documented as legacy.
- **Validation**:
  - Manual tester cycle: open, close by TP/SL, confirm Pandora outcome state updates.

## Sprint 3: Synchronize MT5 Algo Trading Permission With EA Flow
**Goal**: Stop trade attempts before broker calls whenever MT5 or account trading permissions are disabled.
**Demo/Validation**:
- Turning off MT5 Algo Trading changes the panel status and prevents new order attempts.
- Turning Algo Trading back on restores normal processing without stale broker-disabled state.

### Task 3.1: Add Platform Trade Permission Status
- **Location**: `microservices/core/enums.mqh`, `services/trading_signals/market_status_controller.mqh`
- **Description**: Add a platform-disabled status or separate helper that detects terminal/MQL/account trading permission with `MQLInfoInteger`, `TerminalInfoInteger`, and `AccountInfoInteger`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - The status distinguishes platform/Algo disabled from broker symbol disabled when possible.
  - Status reason is readable, for example `Algo Trading disabled`.
  - Status returns to active only after permissions and symbol trade mode are valid.
- **Validation**:
  - Compile.
  - Manual toggle of MT5 Algo Trading while EA is attached.

### Task 3.2: Gate OnTick Trade Work Before Signal/Order Calls
- **Location**: `HFT_Grid_AI.mq5`, `services/trading_signals/protection_risk_filter.mqh`
- **Description**: Run permission monitoring near the start of `OnTick()` and skip `Main()`, `Main_Tick()`, order sends, position closes, and force-close attempts when platform trading is disabled.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - The EA still refreshes rates and frontend visualization.
  - No `g_position.Buy()`, `Sell()`, `PositionClose()`, `PositionClosePartial()`, SL/TP modification, hedge open, or force-close attempt runs while Algo Trading is disabled.
  - Existing broker-side SL/TP remains the only protection mechanism while the EA is disabled by the MT5 button.
  - Existing broker-disabled/close-only handling remains intact.
- **Validation**:
  - Compile.
  - Manual live/demo chart: toggle Algo Trading off, trigger conditions, confirm no repeated trade errors.

### Task 3.3: Ensure Restoration Does Not Clear Real Broker Locks Incorrectly
- **Location**: `services/trading_signals/market_status_controller.mqh`, `services/trading_signals/protection_risk_filter.mqh`
- **Description**: Prevent the platform permission monitor from overwriting a true broker-disabled, close-only, market-close guard, or drawdown force-close state.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Algo-disabled status is reversible.
  - Broker-disabled and close-only statuses still require symbol/broker conditions to recover.
  - Pending force-close state is not dropped silently while trading is disabled.
- **Validation**:
  - Manual state transition review and compile.

## Sprint 4: Add Error Telemetry And Frontend Error Label
**Goal**: Track current/last EA trade errors and surface them compactly in the chart UI.
**Demo/Validation**:
- The panel shows whether an error exists now or occurred recently.
- Errors include order-send failures, margin/no-money, invalid stops, broker disabled, close failures, and guardrail blocks.

### Task 4.1: Add Error State Storage
- **Location**: `services/trading_signals/market_status_controller.mqh` or a narrowly scoped existing telemetry module
- **Description**: Add state for current error code/context, last error code/context, retcode, `GetLastError()`, timestamp, and whether the error is active or historical.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Error state is cheap to update and does not allocate on every tick.
  - Error state can be cleared when trading is restored or after a successful broker action, while preserving last-error history.
  - No sensitive account/license data is logged or displayed.
- **Validation**:
  - Compile.
  - Manual code review for hot-path overhead.

### Task 4.2: Register Trade And Guardrail Failures
- **Location**: `microservices/trading_signals/grid_order_lifecycle.mqh`, `microservices/trading_signals/grid_break_even_utils.mqh`, `services/trading_management_strategies/grid_trend_risk_hedge.mqh`, `services/trading_signals/protection_risk_filter.mqh`, `microservices/trading_signals/grid_order_helpers.mqh`
- **Description**: Record errors at the existing failure points: `ORDER_SEND_FAILED`, no-money, invalid stops/SLTP correction failures, close failures, partial close failures, hedge send failures, guardrail blocks, and platform-disabled blocks.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Each registered error includes a concise context and retcode/error values when available.
  - Guardrail blocks use reason tokens already produced by `GridGuardrailsAllowOrder()`.
  - Error telemetry does not change whether an order is allowed.
- **Validation**:
  - Compile.
  - Manual forced failure scenarios: too-low margin/no-money in tester, invalid stops if safely reproducible, Algo disabled.

### Task 4.3: Render Error Label In Panel And Tester Comment
- **Location**: `services/frontend/pandora_box_panel.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Add one compact line to the panel/tester comment, such as `Error: OK`, `Error: ACTIVE ORDER_SEND_FAILED ret=...`, or `Last error: ...`.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Live panel and Strategy Tester comment both show error state.
  - Panel remains compact and respects existing width/height helpers.
  - The label is state display only and never influences trading decisions.
- **Validation**:
  - Compile.
  - Manual chart review on normal and small chart sizes.

## Sprint 5: Regression, Documentation, And Handoff
**Goal**: Verify the complete behavior across multi-chart, permission, and failure scenarios, then document user-facing changes.
**Demo/Validation**:
- The EA compiles cleanly.
- Multi-symbol charts show unique approved magic/scope and do not affect each other's positions.
- MT5 Algo Trading off prevents trade attempts and shows a clear panel status.
- New comments and error label are visible.

### Task 5.1: Run Final Compile And Parse Build Log
- **Location**: `BUILD.log`
- **Description**: Run the project MetaEditor compile command and inspect `BUILD.log` for warnings/errors.
- **Dependencies**: Sprints 1-4.
- **Acceptance Criteria**:
  - Build has zero errors.
  - Warnings are either zero or explicitly triaged.
- **Validation**:
  - MetaEditor compile command from `AGENTS.md`.

### Task 5.2: Manual Multi-Chart MT5 Smoke
- **Location**: MT5 terminal, two or more charts
- **Description**: Attach the EA to at least two different pairs in the same terminal and validate the ownership, UI, and no cross-chart interference.
- **Dependencies**: Sprints 1-4.
- **Acceptance Criteria**:
  - Each chart shows its approved magic/scope.
  - A position opened on one symbol is not counted, closed, or displayed as floating P/L by the other symbol.
  - Daily-result logic still sees deals for the runtime trade magic.
- **Validation**:
  - Manual terminal observation and logs.

### Task 5.3: Manual Algo Toggle And Failure Smoke
- **Location**: MT5 terminal, Strategy Tester if needed
- **Description**: Toggle Algo Trading off/on and create at least one safe broker rejection scenario.
- **Dependencies**: Sprints 3-4.
- **Acceptance Criteria**:
  - Algo off: no order/close attempts are made; panel explains status.
  - Algo on: normal signal/order processing resumes.
  - Rejection: panel shows active/last error with useful context.
- **Validation**:
  - Manual terminal observation, tester logs, and `query_debug.txt` if file logs are enabled.

### Task 5.4: Update User Documentation
- **Location**: `README.md`, `docs/guides/pandora-box-strategy-inputs.md`, `docs/guides/pandora_box_guide_en.md`, `docs/guides/pandora_box_guide_es.md`
- **Description**: Document the approved magic behavior, order comment format, Algo Trading synchronization, and error label meaning.
- **Dependencies**: Sprints 1-4.
- **Acceptance Criteria**:
  - Docs explain how to validate multi-chart setup.
  - Docs do not imply random live magic.
  - Docs state that the error label is informational.
- **Validation**:
  - Proofread changed sections.

## Testing Strategy
- Start each Sprint with `git status --short` and inspect related diffs before editing.
- Use focused `rg` audits for ownership filters and broker action calls.
- Run MetaEditor compile after each code Sprint.
- Use Strategy Tester "Every tick based on real ticks" for order lifecycle and failure scenarios.
- Use live/demo terminal manual checks for MT5 Algo Trading toggle because the platform button behavior is not fully represented by pure code review.
- Keep `query_debug.txt` compact or rotate it before long validation runs.

## Potential Risks And Gotchas
- A truly random magic per attach is unsafe because restart/recompile can orphan open positions and break close/recovery logic.
- `ChartID()` is not a stable long-term trade identity. It should not be the only live magic source.
- Changing trade magic without updating daily-results deal filtering will cause reported daily P/L to miss the EA's own deals.
- Reusing `pandora_box_pos_n` comments across multiple simultaneous signals can collide unless magic+symbol+ticket/state matching remains authoritative.
- Some brokers truncate or alter comments; recovery should prefer stored ticket/deal IDs when available and use comments as a fallback.
- MT5 Algo Trading disabled intentionally prevents emergency EA closes. The EA should show the disabled state clearly and preserve pending force-close intent until trading is enabled.
- A local instance ID that is not persistent enough will still create magic rotation after restart. Treat persistence as a first-class acceptance criterion.
- If users clone chart templates that include an already-generated instance ID, two charts can collide. The implementation needs either explicit duplicate detection or a regeneration workflow.
- Upgrading a chart while it has open positions under the old lane magic can leave those positions outside the new instance magic scope. Production rollout must gate upgrades to flat charts unless explicit legacy migration support is added.
- Adding too many panel lines can make the UI too wide on small charts; keep the error label terse.

## Rollback Plan
- Revert the runtime magic helper and restore the previous `g_magic_number = LicenseGetCachedMagicNumber()` path if scoped magic causes attribution or recovery issues.
- Revert `GridComposeLevelComment()` and hedge comment changes if broker history matching fails.
- Remove the Algo Trading pre-gate only if it blocks required recovery behavior; keep broker status handling intact.
- Remove frontend error label independently if UI layout regresses; keep backend error telemetry if it is otherwise useful.
- Always compile after rollback and manually confirm existing positions remain discoverable by magic+symbol.

## Resolved Migration Default
- Do not implement a temporary legacy-position migration mode in the first rollout.
- The new EA should refuse to initialize when legacy lane-magic positions are still open on the chart symbol.
- Existing production charts should be upgraded only after they are flat, or after legacy positions are intentionally closed/managed outside the new instance-magic EA.
