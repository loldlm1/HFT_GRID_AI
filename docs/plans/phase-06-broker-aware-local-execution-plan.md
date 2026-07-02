# Plan: Phase 6 Broker-Aware Local Execution

**Generated**: 2026-07-02
**Estimated Complexity**: High
**Roadmap Phase**: Phase 6
**Primary Output**: Broker-aware local execution foundation where local decisions apply broker conditions first, and real broker positions become source of truth once present
**Validation Policy**: Static validation per sprint; one MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed
**Status**: Planned

## Overview

Phase 6 formalizes the local-and-broker-conditions-first execution contract.

Before any real broker position exists, the EA should evaluate execution locally and deterministically using the same broker-relevant facts that can block or alter a live order: bid/ask, spread, stops level, freeze level, volume min/max/step, margin availability, market status, terminal algo permission, session filters, protection locks, daily limits, symbol, and magic scope.

After a real broker position exists, local state must stop guessing broker facts. Position ticket, symbol, magic number, type, volume, entry price, and open/closed state must be reconciled from the broker and override local assumptions.

This phase must keep the current strategy mock and range foundation intact. It should not implement final strategy logic or the broader real-tick performance pass. The main goal is to create a stable execution boundary future strategies can use without bypassing broker parity or risk controls.

## Current Baseline

- `HFT_Grid_AI.mq5` refreshes bid/ask/spread on tick through `RefreshCustomSymbolRates()`.
- `services/utils/broker_constraints_helper.mqh` stores symbol constraints and is refreshed on init, but no central per-decision execution snapshot exists.
- `services/trading_signals/market_signal_state.mqh` owns signal-attempt permissions for manual toggle, algo trading, protection, session, daily limit, direction, and concurrency.
- `services/trading_signals/execution_leg_helpers.mqh` has `ExecutionGuardrailsAllowOrder()` for spread and margin, but it is evaluated immediately before send and does not represent a reusable local execution decision.
- `services/trading_signals/execution_controller.mqh` triggers pending and next-leg activation directly from price conditions.
- `services/trading_signals/execution_lifecycle.mqh` sends real orders, resolves tickets from deals/comments, closes positions, and reads broker volume when a ticket is known.
- `services/trading_signals/market_status_controller.mqh` tracks active, close-guard, close-only, and disabled states.
- There is no explicit broker snapshot or reconciliation layer separating local simulated state from real broker state.

## Prerequisites

- Phase 0 through Phase 5 are complete and committed.
- Working tree is clean before execution.
- Do not add custom MQL5 tests, test harnesses, scripts, or CI.
- Compile is run once after all Phase 6 code and docs edits are complete.
- Preserve existing public inputs unless a compile-safe rename is required for the new execution contract.
- Preserve current strategy/range behavior; this phase is about execution truth boundaries, not final strategy design.

## Files Expected To Change

- `services/trading_signals.mqh`
- `services/trading_signals/signal_params_struct.mqh`
- `services/trading_signals/market_signal_state.mqh`
- `services/trading_signals/execution_leg_helpers.mqh`
- `services/trading_signals/execution_lifecycle.mqh`
- `services/trading_signals/execution_controller.mqh`
- `services/trading_signals/execution_logging.mqh`
- `services/trading_signals/tick_signals_manager.mqh`
- `services/trading_signals/market_status_controller.mqh`
- `services/utils/broker_constraints_helper.mqh`
- `HFT_Grid_AI.mq5`
- `ROADMAP.md`
- `docs/architecture/execution-foundation.md`
- `docs/plans/phase-06-broker-aware-local-execution-plan.md`

Expected new files, if the local include order remains clean:

- `services/trading_signals/execution_broker_context.mqh`
- `services/trading_signals/execution_broker_reconciliation.mqh`

## Files Expected To Be Deleted

None expected.

Phase 6 should prefer adding clear execution-boundary helpers and replacing direct guardrail calls over deleting existing lifecycle modules. Delete only if an obsolete helper becomes unreachable and has no safe use under the new contract.

## Non-Goals

- Do not implement the final production strategy.
- Do not redesign Stoch Structure, strategy range, lot sizing formulas, or target-profit semantics.
- Do not add tests, harnesses, scripts, or CI.
- Do not run compile after every sprint.
- Do not do the Phase 7 real-tick performance pass, indicator-handle refactor, or broad logging optimization.
- Do not weaken license, protection risk, session, daily signal, spread, market status, margin, broker-distance, symbol, or magic-number safeguards.
- Do not let chart/frontend/UI state affect trading decisions.
- Do not create compatibility shims for removed legacy feature names.

## Target Contract

Use these concepts consistently:

- `BrokerExecutionSnapshot`: cheap current facts needed for local execution decisions.
- `BrokerExecutionEligibility`: deterministic allow/block result with a source and reason.
- `BrokerPositionSnapshot`: real broker position facts scoped by symbol and magic number.
- `local execution`: simulated activation/fill state before a broker position exists.
- `broker source of truth`: real position facts once a ticket or scoped matching position exists.
- `reconciliation`: one-way refresh from broker facts into execution legs.

## Sprint 1: Broker Execution Context Contract

**Goal**: Add a central broker-aware execution snapshot and eligibility contract without changing order behavior yet.
**Commit**: `feat: add broker execution context contract`
**Demo/Validation**:
- Static scan confirms new context helpers are included once through `services/trading_signals.mqh`.
- Existing direct permission helpers still compile by symbol.
- `git diff --check`

### Task 1.1: Add Broker Execution Snapshot Types

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/signal_params_struct.mqh` only if leg/signal fields are needed
- **Description**: Define small structs for current broker facts and decision results. Keep them default-constructible for MQL5 array/assignment compatibility.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Snapshot includes symbol, bid, ask, spread points, point size, constraints timestamp, market status, terminal algo permission, session permission, protection permission, daily/concurrency permission, normalized volume, and margin estimate fields.
  - Eligibility includes `allowed`, `block_source`, and `block_reason`.
  - Structs use explicit constructors and no aggregate initialization.
- **Validation**:
  - `rg "struct BrokerExecution|BrokerExecutionEligibility|BrokerPositionSnapshot" services/trading_signals`
  - `git diff --check`

### Task 1.2: Capture Broker Facts Through One Helper

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/utils/broker_constraints_helper.mqh`
- **Description**: Add `CaptureBrokerExecutionSnapshot()` or equivalent. It should read already-refreshed globals where possible and only refresh symbol constraints when stale or invalid.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Uses `g_bid`, `g_ask`, `g_points_spread`, `g_symbol_constraints`, `MarketStatusGet()`, `TerminalAlgoTradingEnabled()`, and existing permission helpers.
  - Does not scan positions.
  - Does not send orders or mutate execution legs.
  - Has a cheap invalid-snapshot failure path with a clear reason.
- **Validation**:
  - `rg "CaptureBrokerExecutionSnapshot|RefreshSymbolTradingConstraints|g_symbol_constraints" services/trading_signals services/utils`

### Task 1.3: Wire Include Order Cleanly

- **Location**: `services/trading_signals.mqh`
- **Description**: Include the new broker context file after state/permission dependencies are available and before helpers that consume it.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - No sibling include cycle is introduced.
  - Aggregator remains the single source of truth for include order.
  - Existing modules do not directly include sibling `.mqh` files except the already established local cascade pattern.
- **Validation**:
  - `Get-Content services/trading_signals.mqh`
  - `rg "#include .*execution_broker_context" services`

### Task 1.4: Keep Sprint 1 Behavior-Preserving

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Ensure new helpers are available but not yet changing activation or order-send behavior.
- **Dependencies**: Tasks 1.1-1.3.
- **Acceptance Criteria**:
  - Existing `CanAttemptSignal()` and `ExecutionGuardrailsAllowOrder()` remain callable.
  - No order lifecycle branch is changed in Sprint 1.
  - Static validation passes.
- **Validation**:
  - `rg "CanAttemptSignal|ExecutionGuardrailsAllowOrder|CaptureBrokerExecutionSnapshot" services/trading_signals`
  - `git diff --check`

## Sprint 2: Local Broker-Aware Activation Gate

**Goal**: Evaluate local execution eligibility before a pending leg can become actionable or send a real order.
**Commit**: `feat: gate local execution with broker facts`
**Demo/Validation**:
- Pending leg activation flows through the new local eligibility result.
- Order send still happens only after broker-aware local checks pass.
- `git diff --check`

### Task 2.1: Add Local Leg Eligibility Evaluation

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_leg_helpers.mqh`
- **Description**: Add `EvaluateLocalExecutionLegEligibility()` or equivalent. It should decide whether a leg may activate locally before broker send or simulated local fill.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Blocks invalid bid/ask, spread over `Max_Spread`, inactive market status, terminal algo disabled, protection/session/daily/concurrency blocks, invalid lot, invalid broker constraints, and invalid entry prices.
  - Applies broker min distance for entry reference, next level, and take-profit where applicable.
  - Produces a deterministic block source and reason for logging.
  - Does not call `g_position.Buy()`, `g_position.Sell()`, or close functions.
- **Validation**:
  - `rg "EvaluateLocalExecutionLegEligibility|BrokerExecutionEligibility|Max_Spread|MinBrokerDistancePoints" services/trading_signals`

### Task 2.2: Replace Direct Pre-Send Guardrails

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/execution_leg_helpers.mqh`
- **Description**: Route `ExecuteExecutionLegTrade()` through the eligibility contract before either simulated local activation or real order send.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `opens_position == false` legs still simulate locally, but only after passing broker-aware local activation conditions.
  - `opens_position == true` legs cannot reach broker send unless eligibility is allowed.
  - Old guardrail helper is removed or reduced to a compatibility-free internal implementation if still useful.
  - Failure logging keeps retcode-free local block reasons distinct from broker send failures.
- **Validation**:
  - `rg "ExecutionGuardrailsAllowOrder|EvaluateLocalExecutionLegEligibility|GUARDRAIL_BLOCK|LOCAL_EXECUTION_BLOCK" services/trading_signals`

### Task 2.3: Normalize Volume And Margin Before Activation

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Move volume normalization and margin feasibility into the local eligibility result used by activation.
- **Dependencies**: Tasks 2.1-2.2.
- **Acceptance Criteria**:
  - Normalized volume respects symbol min/max/step.
  - Target-profit lot mode still fails closed when a required lot is infeasible.
  - Margin is checked with current broker/account facts before send.
  - If a broker-compatible local check cannot be computed, the decision blocks with a reason rather than allowing ambiguity.
- **Validation**:
  - `rg "NormalizeVolumeForSymbol|NormalizeVolumeUpForSymbol|AccountInfoDouble|ACCOUNT_MARGIN_FREE|BrokerExecutionEligibility" services/trading_signals`

### Task 2.4: Add Immediate Pre-Send Broker Parity Check

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/market_status_controller.mqh`
- **Description**: Add a final cheap broker-parity check immediately before send. Prefer existing local facts and margin calculation; use stricter platform preflight only if it remains local and does not open an order.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance Criteria**:
  - Broker send failures are still registered through `MarketStatusRegisterBrokerFailure()`.
  - Local block reasons and broker retcodes are logged separately.
  - No repeated expensive preflight is run unless the activation trigger is reached.
- **Validation**:
  - `rg "ResultRetcode|MarketStatusRegisterBrokerFailure|LOCAL_EXECUTION_BLOCK|BROKER_SEND_FAILED" services/trading_signals`

## Sprint 3: Broker Position Reconciliation

**Goal**: Make real broker positions override local execution leg facts once present.
**Commit**: `feat: reconcile broker positions as execution truth`
**Demo/Validation**:
- Real position snapshots are selected by ticket first, then by symbol/magic/comment fallback.
- Active execution legs refresh from broker volume and entry price before lifecycle decisions.
- Missing broker positions close or downgrade local state deterministically.
- `git diff --check`

### Task 3.1: Add Broker Position Snapshot Helpers

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Add helpers that read broker position facts into `BrokerPositionSnapshot`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Selection by `position_ticket` validates symbol and magic number.
  - Fallback by composed comment validates symbol, magic number, and direction.
  - Snapshot captures ticket, symbol, magic, position type, volume, entry price, current price, profit, and comment.
  - No unscoped position can attach to a signal.
- **Validation**:
  - `rg "BrokerPositionSnapshot|PositionSelectByTicket|POSITION_MAGIC|POSITION_SYMBOL|POSITION_COMMENT" services/trading_signals`

### Task 3.2: Reconcile Active Legs Before Decisions

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/tick_signals_manager.mqh`
- **Description**: Reconcile active/opening legs from broker state before TP, next-level activation, partial close, or signal completion decisions.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Real broker volume overrides local `lot_size` for active legs.
  - Real broker open price overrides local `entry_price`.
  - Missing broker position for a previously attached ticket transitions the leg to completed or closed according to existing lifecycle semantics.
  - Local simulated legs without broker ticket remain local and do not claim broker truth.
- **Validation**:
  - `rg "Reconcile.*Execution|ResolveExecutionLegTrackedVolume|IsExecutionSignalComplete|UpdateExecutionLifecycle" services/trading_signals`

### Task 3.3: Reconcile After Successful Send

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`
- **Description**: After `g_position.Buy()` or `g_position.Sell()`, resolve the real position and immediately refresh leg facts from broker state.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance Criteria**:
  - Deal-to-position resolution remains supported.
  - Comment fallback remains scoped by symbol, magic number, and direction.
  - If a sent order cannot be reconciled to a broker position, the send is treated as ambiguous and logged.
  - Broker entry price and volume become the stored leg values when available.
- **Validation**:
  - `rg "ResolvePositionTicketFromDeal|FindOpenPositionForSignal|Reconcile.*Broker|position_ticket" services/trading_signals/execution_lifecycle.mqh services/trading_signals/execution_broker_reconciliation.mqh`

### Task 3.4: Preserve Realized Outcome Semantics

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/tick_signals_manager.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Keep daily signal and lot-sequence outcomes tied to broker-confirmed close facts when available, falling back to local projection only when no real position ever existed.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - `realized_profit`, `realized_closed_volume`, and `remaining_open_volume` are refreshed from broker-aware lifecycle paths.
  - Existing fallback raw-profit projection remains only for fully local/no-broker scenarios.
  - Daily signal limits and signal lot sequence outcomes are not weakened.
- **Validation**:
  - `rg "realized_profit|realized_closed_volume|remaining_open_volume|RegisterDailySignalOutcome|RegisterSignalLotSequenceOutcome" services/trading_signals`

## Sprint 4: Final Sweep, Compile Gate, And Documentation

**Goal**: Run final static sweeps, compile once, and document Phase 6 completion evidence.
**Commit**: `docs: record phase 6 compile result`
**Demo/Validation**:
- Static sweeps show the local execution and broker reconciliation contract is wired through active source.
- MetaEditor compile reports `0 errors, 0 warnings`.
- `git status --short` is clean after final commit.

### Task 4.1: Static Source Sweep

- **Location**: Active production source and active docs.
- **Description**: Confirm that old direct pre-send checks have been replaced by the broker-aware local execution contract and that broker reconciliation is centralized.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - Local eligibility helpers are used before send.
  - Real broker reconciliation helpers are used before lifecycle decisions.
  - No unscoped position attach path remains.
  - No tests, harnesses, scripts, or CI were added.
- **Validation**:
  ```powershell
  rg "BrokerExecutionSnapshot|BrokerExecutionEligibility|EvaluateLocalExecution|BrokerPositionSnapshot|Reconcile" services/trading_signals
  rg "PositionGetTicket|PositionSelectByTicket|POSITION_MAGIC|POSITION_SYMBOL" services/trading_signals
  rg "run_mql5_tests|TEST_PASS|TEST_FAIL|harness" services HFT_Grid_AI.mq5
  git diff --check
  ```

### Task 4.2: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile once after all Phase 6 code and docs edits.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Compile reports `0 errors, 0 warnings`.
  - No custom tests or harnesses are run.
- **Validation**:
  ```powershell
  $mt5Root = "C:\Program Files\MetaTrader 5-1"
  $metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
  $entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
  $logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
  $log = Join-Path $logDir "phase-06-build.log"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  if(Test-Path $log) { Remove-Item -LiteralPath $log -Force }
  $argString = "/portable /s /compile:`"$entrypoint`" /log:`"$log`""
  $proc = Start-Process -FilePath $metaeditor -ArgumentList $argString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.3: Fallback Compile Only If Evidence Is Missing Or Fails

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run normal MetaEditor compile only if portable compile fails or does not produce usable evidence.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback result is parsed for warnings/errors.
- **Validation**:
  ```powershell
  $fallbackLog = Join-Path $logDir "phase-06-build-fallback.log"
  $fallbackArgString = "/s /compile:`"$entrypoint`" /log:`"$fallbackLog`""
  $fallbackProc = Start-Process -FilePath $metaeditor -ArgumentList $fallbackArgString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.4: Record Phase 6 Result

- **Location**: `ROADMAP.md`, `docs/architecture/execution-foundation.md`, `docs/plans/phase-06-broker-aware-local-execution-plan.md`
- **Description**: Record status, compile command, log/evidence path, process exit code, and result line.
- **Dependencies**: Task 4.2 or 4.3.
- **Acceptance Criteria**:
  - Phase 6 status is documented.
  - Compile result is documented.
  - Architecture doc reflects the implemented local/broker source-of-truth boundary.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 6 Acceptance Criteria

- Local execution can decide deterministically without opening a real broker position.
- Local activation applies broker-relevant conditions before marking a leg actionable.
- Real broker positions, once present, become source of truth for ticket, symbol, magic, type, volume, entry price, and open/closed state.
- Broker constraints remain centralized and cheap to refresh.
- Position attach/reconciliation is scoped by symbol and magic number.
- Existing license, protection risk, session, daily signal, spread, market status, volume, margin, and broker-distance safeguards are not weakened.
- No custom tests, scripts, harnesses, or CI are added.
- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.

## Validation Strategy

Use static validation per sprint:

```powershell
rg "BrokerExecutionSnapshot|BrokerExecutionEligibility|BrokerPositionSnapshot|Reconcile" services/trading_signals
rg "ExecutionGuardrailsAllowOrder|LOCAL_EXECUTION_BLOCK|BROKER_SEND_FAILED" services/trading_signals
rg "PositionSelectByTicket|POSITION_MAGIC|POSITION_SYMBOL|POSITION_COMMENT" services/trading_signals
rg "run_mql5_tests|TEST_PASS|TEST_FAIL|harness" services HFT_Grid_AI.mq5
git diff --check
git status --short
```

Run the MT5 compile gate once after all Phase 6 code and docs edits are complete. Do not run custom MQL5 tests.

## Potential Risks And Gotchas

- Local checks can accidentally duplicate or diverge from live broker checks. Keep one eligibility helper and route activation through it.
- `OrderCheck`-style preflight may be too expensive if called every tick. If used, run it only at activation/send boundary, not on every idle tick.
- Position fallback by comment is risky. Always scope by symbol, magic number, and direction before attaching.
- Broker positions may be closed manually or by server-side events. Reconciliation must handle missing tickets without leaving local active legs stuck forever.
- Close-only and disabled trade modes are different. Close-only should allow protective closes but block new opens.
- Margin calculation can be broker-specific. If margin cannot be computed deterministically, block or fall back to existing safe behavior rather than allowing ambiguous opens.
- Netting and hedging accounts may expose position selection differently. Keep reconciliation ticket-first and scoped.
- Realized profit can be ambiguous if history is unavailable. Preserve current local fallback only when no broker-confirmed close facts exist.
- New snapshot helpers can become hot-path overhead. Keep capture cheap now and leave deeper caching/performance work for Phase 7.

## Rollback Plan

- Revert sprint commits in reverse order.
- If compile fails after include changes, first check `services/trading_signals.mqh` ordering and missing forward dependencies.
- If local activation blocks too aggressively, revert Sprint 2 while preserving Sprint 1 context structs for a narrower retry.
- If broker reconciliation attaches the wrong position or leaves signals stuck, revert Sprint 3 immediately and restore ticket/comment resolution from the previous lifecycle implementation.
- If protection, session, daily limits, or market status behavior changes unexpectedly, revert the sprint that touched the relevant gate before attempting additional cleanup.
