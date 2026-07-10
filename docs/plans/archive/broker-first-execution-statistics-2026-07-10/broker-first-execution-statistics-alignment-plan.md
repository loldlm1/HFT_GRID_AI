# Plan: Broker-First Execution And Statistics Alignment

**Generated**: 2026-07-09
**Estimated Complexity**: Critical
**Risk Class**: Critical, because this touches order admission, position lifecycle, lot sizing, partial closes, broker reconciliation, and deterministic statistics.
**Source Research**: `docs/research/trade-execution-flow-audit-2026-07-09.md`

## Overview

Align the EA around a broker-first but EA-managed execution contract:

- Strategy signals remain deterministic and are captured even when broker admission is blocked by spread or market conditions.
- Spread, market, session, margin, broker-distance, license, protection, and volume rules remain hard admission controls before broker send.
- Broker-confirmed outcomes are recorded only from real broker exposure, positions, deals, or confirmed close operations.
- `EXECUTION_LOT_TARGET_CURRENCY` becomes risk-cap-first: when the user targets 50 account-currency units, expected loss at SL must not exceed 50 after broker volume normalization, except for uncontrollable slippage, gap, commission, swap, or broker execution effects.
- `TP_Percent = 100` should represent a normalized 1:1 money expectation: expected SL loss and expected TP gain should be congruent in account currency whenever broker pricing and volume constraints make it feasible.
- Exits stay EA-managed rather than server-side SL/TP, but all admission, lot sizing, partial TP, and statistics must use broker-realistic prices and broker-confirmed facts where possible.
- Optional partial TP becomes real broker partial closes, controlled by one input, with deterministic internal levels and volumes.

This plan must be implemented sprint by sprint. Complete, validate, and commit one sprint before starting the next sprint.

## Confirmed Requirements

- `Max_Spread` blocks broker admission/send only. It must not globally stop signal capture, broker reconciliation, active lifecycle management, cleanup, or statistics state maintenance.
- Blocked signals keep candidate/admission status. They do not track a hypothetical full path by default.
- Target-money lot sizing depends on `ExecutionLotTypes`, but target-currency mode must be interpreted as a risk cap first.
- EA-managed exits remain the preferred model.
- Partial TP has one new public input: `Partial_TP_Mode`.
- Deterministic partial TP constants are internal for now:
  - levels: `1.0`, `2.0`, `3.0`
  - volume fractions: `0.33`, `0.33`, `0.34`
- Do not parse string inputs on the tick path for partial TP levels or fractions.
- Validation is MetaEditor compile plus human-in-the-loop Strategy Tester/chart verification only.
- Do not add custom MQL5 tests, CI, or a new test harness unless a future human decision reverses the project policy.

## Prerequisites

- Preserve the canonical include flow:

```text
services/license_service_setup.mqh
services/trading_tools.mqh
services/trading_management.mqh
services/trading_management_strategies.mqh
services/trading_signals.mqh
services/frontend.mqh
```

- Start from the current dirty worktree without reverting existing research docs:
  - `docs/research/README.md`
  - `docs/research/trade-execution-flow-audit-2026-07-09.md`
- Before implementation, review the current versions of:
  - `HFT_Grid_AI.mq5`
  - `services/trading_management/ea_inputs.mqh`
  - `services/core/enums.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_lot_math.mqh`
  - `services/trading_signals/execution_planner.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/utils/money_functions.mqh`
- Use official MQL5 references for broker-first calculations and trade retcode semantics:
  - `OrderCalcProfit`: https://www.mql5.com/en/docs/trading/ordercalcprofit
  - `OrderCalcMargin`: https://www.mql5.com/en/docs/trading/ordercalcmargin
  - `OrderCheck`: https://www.mql5.com/en/docs/trading/ordercheck
  - `CTrade::Buy`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy
  - `CTrade::PositionClosePartial`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclosepartial
- Compile implementation sprints with the project helper when available:

```bash
python3 tools/mt5/compile_mt5.py
```

If the helper cannot run in the current environment, use the documented MetaEditor command from `docs/environment/mt5-agentic-workflows.md`.

## Sprint 1: Runtime Lanes And Admission Status

**Goal**: Split the tick flow so lifecycle, reconciliation, protection, cleanup, and signal capture keep running while spread/market gates block only broker admission and send.
**Commit**: `refactor: split broker admission from signal runtime lanes`
**Demo/Validation**:

- MetaEditor compile at sprint end.
- Human Strategy Tester scenario with `Max_Spread` lower than observed spread.
- Verify a deterministic signal candidate is captured with an admission-blocked status and no broker order is sent.
- Verify an already-open broker position still reconciles and can be closed by EA lifecycle while spread is high, subject to broker market availability.
- Verify license, session, protection, market-status, spread, broker-distance, volume, and margin guards still fail closed for broker send.

### Task 1.1: Document Runtime Lane Contract In Code Boundaries

- **Location**: `HFT_Grid_AI.mq5`, `services/trading_signals/tick_signals_manager.mqh`, `services/trading_signals/execution_controller.mqh`
- **Description**: Define the implementation boundary between always-run work, signal-capture work, and broker-admission work. Keep it small and aligned with existing functions before moving logic.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - The intended tick order is clear from function names and nearby comments.
  - No new sibling include cycles are introduced.
  - Existing protection and license checks remain in the broker-send path.
- **Validation**: Code review plus compile at sprint end.

### Task 1.2: Add Candidate And Admission Status Fields

- **Location**: `services/core/enums.mqh`, `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/execution_logging.mqh`
- **Description**: Add explicit status/reason fields for signal candidates and broker admission. Include spread-blocked, market-closed, session-blocked, margin-blocked, volume-blocked, broker-distance-blocked, license-blocked, protection-blocked, and sent/accepted statuses as needed.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - A signal can be represented as captured but not broker-admitted.
  - Admission reasons are deterministic strings/enums, not ad hoc log text.
  - Existing signal lifecycle states are not overloaded to mean admission failure.
- **Validation**: Code review plus compile at sprint end.

### Task 1.3: Refactor `OnTick()` Global Gate

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Remove the broad early return that currently uses `g_points_spread > Max_Spread || !IsMarketOpen()` as a runtime stop. Replace it with a broker-admission flag/snapshot passed to signal processing and execution planning.
- **Dependencies**: Tasks 1.1 and 1.2.
- **Acceptance Criteria**:
  - Broker reconciliation, active lifecycle management, cleanup, and frontend refresh are not skipped solely because spread is high.
  - Signal detection on new base bars can still create a candidate when spread is high.
  - Broker send remains denied when spread or market status fails.
- **Validation**: Strategy Tester high-spread scenario plus compile.

### Task 1.4: Wire Broker Context Denials Into Admission Status

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/tick_signals_manager.mqh`
- **Description**: Convert broker-context denials into structured admission statuses on the signal before returning from the send path.
- **Dependencies**: Tasks 1.2 and 1.3.
- **Acceptance Criteria**:
  - Spread denial records the current spread and `Max_Spread`.
  - Market/session/license/protection/margin/volume/stops/freeze denials record a stable reason.
  - No broker order is attempted after a denial.
- **Validation**: Compile plus debug log review in Strategy Tester.

### Task 1.5: Surface Admission State In Minimal Telemetry

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`, `services/frontend/lightweight_status_ui.mqh`, `services/trading_signals/execution_logging.mqh`
- **Description**: Expose admission state where it helps tester verification without adding noisy per-tick logs.
- **Dependencies**: Tasks 1.2 through 1.4.
- **Acceptance Criteria**:
  - Blocked candidates are visible in export/logs as candidates, not outcomes.
  - UI wording continues to show current spread status without implying lifecycle is stopped.
  - Logging remains gated by existing debug/file-log settings.
- **Validation**: Compile and tester log review.

## Sprint 2: Broker-Confirmed Outcome Contract

**Goal**: Ensure deterministic outcomes and ML shadow outcomes are produced only from real broker exposure or confirmed broker close facts.
**Commit**: `fix: require broker evidence for execution outcomes`
**Demo/Validation**:

- MetaEditor compile at sprint end.
- Human Strategy Tester scenario where a signal is captured but never admitted, then a protection/session/forced-close path runs.
- Verify no broker outcome, realized close volume, or ML outcome is exported for a no-ticket/no-exposure signal.
- Verify a real entered position still exports a broker-confirmed final outcome after actual close.

### Task 2.1: Define Broker Evidence Fields And Predicates

- **Location**: `services/trading_signals/market_signal_state.mqh`, `services/trading_signals/signal_params_struct.mqh`
- **Description**: Tighten the definition of broker entry and broker outcome evidence. Prefer facts such as broker ticket, confirmed deal/order identifiers, broker entry price, live position volume, realized closed volume from a real close, or history-derived close data.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Candidate/admission status cannot satisfy broker-outcome predicates.
  - Locally projected `raw_profit` cannot make a no-ticket signal broker-confirmed.
  - Predicates are named clearly enough for statistics and ML modules to use consistently.
- **Validation**: Code review plus compile at sprint end.

### Task 2.2: Harden `CloseAllExecutionLegs()` And Realized Close Registration

- **Location**: `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Prevent `CloseAllExecutionLegs()` and realized-close registration from adding closed volume/profit for legs that never had broker exposure. Split no-op local cleanup from broker close confirmation.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `position_ticket <= 0` cannot produce realized broker volume or profit.
  - A failed or unavailable broker close does not mark the signal as broker-closed.
  - Existing real broker close paths still register confirmed close facts.
- **Validation**: Compile plus forced-close tester scenario.

### Task 2.3: Repair Protection Forced-Close Outcome Flow

- **Location**: `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/tick_signals_manager.mqh`, `services/trading_signals/execution_controller.mqh`
- **Description**: Ensure forced-close logic distinguishes real broker positions from pending/admission-blocked signals. Pending signals should be canceled or marked blocked/expired, not assigned projected P/L.
- **Dependencies**: Tasks 2.1 and 2.2.
- **Acceptance Criteria**:
  - Protection force-close still closes real broker positions.
  - No-exposure signals are not counted as wins/losses.
  - Daily risk and lot sequence accounting use broker-confirmed outcome facts only where required.
- **Validation**: Compile plus tester scenario that triggers forced-close with pending and active signals.

### Task 2.4: Align Statistics And ML Outcome Gates

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`, `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Route outcome export through the hardened broker-evidence predicates. Keep candidate and admission records separate from outcome rows.
- **Dependencies**: Tasks 2.1 through 2.3.
- **Acceptance Criteria**:
  - Blocked or canceled signals can be exported as candidates/admission rows if enabled.
  - Broker outcome rows require broker evidence.
  - ML shadow/filter behavior remains non-invasive and does not alter broker admission beyond its approved Strategy Tester filter contract.
- **Validation**: Compile and inspect generated tester artifacts from a small run.

### Task 2.5: Add History Reconciliation Fallback For Missing Live Position

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: When a tracked position disappears, attempt to reconcile with broker history using ticket/position identifiers before marking close facts. If history is unavailable, mark outcome evidence as unknown rather than projected.
- **Dependencies**: Tasks 2.1 through 2.4.
- **Acceptance Criteria**:
  - Broker history enriches close price/profit when available.
  - Missing history does not invent realized P/L.
  - Logs identify reconciliation gaps without noisy per-tick retries.
- **Validation**: Compile and tester review after normal TP/SL close.

## Sprint 3: Broker-First Risk And Lot Math

**Goal**: Make target-currency sizing and broker admission use broker account calculations, with risk cap semantics and transparent expected P/L telemetry.
**Commit**: `feat: add broker-first risk capped lot sizing`
**Demo/Validation**:

- MetaEditor compile at sprint end.
- Human Strategy Tester cases for `EXECUTION_LOT_TARGET_CURRENCY` with target amount 50 and `TP_Percent = 100`.
- Verify expected SL loss is less than or equal to 50 after volume normalization when feasible.
- Verify expected TP profit is congruent with expected SL loss for a 1:1 setup within broker volume step and price constraints.
- Verify infeasible min-volume cases are blocked or clearly marked as infeasible rather than silently oversizing risk.

### Task 3.1: Introduce A Risk Plan Result Structure

- **Location**: `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_planner.mqh`, `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add a compact result structure for planned entry price, SL price, TP price, target risk, expected SL loss, expected TP profit, raw volume, normalized volume, target error, and infeasibility reason.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - The risk plan can be logged/exported without recomputing broker math on every tick.
  - Existing fixed-lot and balance/equity percentage modes keep their current semantics unless explicitly touched by broker validation.
  - Target-currency mode has enough fields to explain every admission decision.
- **Validation**: Code review plus compile.

### Task 3.2: Add Broker Profit Calculation Helper With Fail-Closed Semantics

- **Location**: `services/utils/money_functions.mqh`, `services/trading_signals/execution_lot_math.mqh`
- **Description**: Use `OrderCalcProfit()` to estimate account-currency P/L for planned entry-to-SL and entry-to-TP prices. For target-currency risk mode, do not silently fall back to tick-value approximation when broker calculation fails.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Buy plans use broker-realistic open/close price basis for Ask entry and Bid-side close levels.
  - Sell plans use broker-realistic open/close price basis for Bid entry and Ask-side close levels.
  - Failure to calculate expected SL loss blocks target-currency admission with a structured reason.
  - Commission, swap, slippage, and gaps are documented as realized P/L differences, not pre-trade guarantees.
- **Validation**: Compile plus tester log review for target-currency plans.

### Task 3.3: Implement Risk-Cap-First Volume Solver

- **Location**: `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_planner.mqh`
- **Description**: For `EXECUTION_LOT_TARGET_CURRENCY`, solve volume from expected SL loss per lot and normalize to the largest broker-valid volume that does not exceed the risk cap. If the broker minimum volume would exceed the cap, block the trade as infeasible unless a future input explicitly allows min-volume overshoot.
- **Dependencies**: Tasks 3.1 and 3.2.
- **Acceptance Criteria**:
  - Normalization rounds down for risk-cap compliance in target-currency mode.
  - Volume min/max/step constraints are respected.
  - Expected SL loss after normalization is `<= Lot_Strategy_Size` for feasible trades.
  - Expected TP profit is recorded after normalization and compared to expected SL loss for ratio telemetry.
- **Validation**: Compile plus tester case around volume step boundaries.

### Task 3.4: Replace Margin Estimate Admission With Broker-Aware Checks

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_controller.mqh`
- **Description**: Use `OrderCalcMargin()` and, where practical before send, `OrderCheck()` with a populated `MqlTradeRequest` to validate margin and trade-server preconditions. Keep existing broker snapshot fields as telemetry/fallback context, not the sole admission source.
- **Dependencies**: Task 3.3.
- **Acceptance Criteria**:
  - Margin denial is based on broker account calculation when available.
  - `OrderCheck()` retcode/comment are captured for denial diagnostics.
  - Broker send is not attempted after a failed precheck unless the failure is explicitly classified as non-blocking and safe.
- **Validation**: Compile plus tester scenario with insufficient margin or deliberately oversized target.

### Task 3.5: Reconcile Planned Risk With Actual Broker Entry

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: After broker fill, recalculate expected SL loss and TP profit from actual broker entry price and final EA-managed SL/TP levels for telemetry and statistics. Do not resize the position after fill in this sprint.
- **Dependencies**: Tasks 3.1 through 3.4.
- **Acceptance Criteria**:
  - Planned and actual-entry expected risk/reward are distinguishable.
  - Statistics can audit slippage/entry drift without conflating it with sizing bugs.
  - Existing EA-managed TP/SL lifecycle uses actual entry where it already does today.
- **Validation**: Compile and inspect a small Strategy Tester export.

## Sprint 4: EA-Managed Broker-Realistic Partial TP

**Goal**: Add optional deterministic partial TP using real broker partial closes, while keeping exits EA-managed and avoiding tick-path string parsing.
**Commit**: `feat: add broker-confirmed partial tp mode`
**Demo/Validation**:

- MetaEditor compile at sprint end.
- Human Strategy Tester scenario with `Partial_TP_Mode` enabled and price reaching 1R, 2R, and 3R.
- Verify the EA sends real partial closes for 33%, 33%, and remaining volume.
- Verify each partial is confirmed by broker retcode/position or deal evidence before statistics mark it realized.
- Verify `Partial_TP_Mode` off preserves the current full-position lifecycle.

### Task 4.1: Add `Partial_TP_Mode` Input And Internal Constants

- **Location**: `services/core/enums.mqh`, `services/trading_management/ea_inputs.mqh`
- **Description**: Add one public input with default off. Suggested enum values: `PARTIAL_TP_OFF = 0` and `PARTIAL_TP_R_MULTIPLES = 1`. Store deterministic levels and fractions as compile-time constants or once-initialized arrays, not parsed strings.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Public configuration has exactly one new partial TP input.
  - Constants represent levels `1.0`, `2.0`, `3.0` and fractions `0.33`, `0.33`, `0.34`.
  - Default behavior is unchanged when the mode is off.
- **Validation**: Compile.

### Task 4.2: Add Partial TP State To Signals/Legs

- **Location**: `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Track which deterministic partial TP levels have been triggered, requested, confirmed, skipped, or closed. Keep this state tied to real broker entry and leg/ticket facts.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Partial TP state resets deterministically for new signals.
  - State cannot mark a level as confirmed without broker close evidence.
  - State supports one active position/leg now without blocking future extension.
- **Validation**: Code review plus compile.

### Task 4.3: Implement Partial TP Trigger Logic

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/execution_controller.mqh`
- **Description**: When mode is enabled and a real broker position exists, compare exit-side price to 1R/2R/3R levels derived from broker entry and SL risk distance. Request `PositionClosePartial()` for valid intermediate fractions and close the remaining volume at the final level.
- **Dependencies**: Tasks 4.1 and 4.2.
- **Acceptance Criteria**:
  - No partial close is attempted before broker entry confirmation.
  - Close volume is normalized to broker min/max/step.
  - Intermediate partials do not intentionally leave invalid below-min residual volume.
  - The 3R level closes all remaining volume.
  - If volume constraints make a partial invalid, the EA logs a structured skip/defer reason and does not invent a partial outcome.
- **Validation**: Compile plus Strategy Tester partial TP run.

### Task 4.4: Confirm Partial Close Results Through Broker Facts

- **Location**: `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`
- **Description**: Treat `PositionClosePartial()` return value as a local request check only. Confirm close volume, remaining volume, close price, and realized P/L through trade result retcode/deal fields and/or broker reconciliation/history.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - Partial realized volume/profit is recorded only after broker confirmation.
  - Failed, rejected, or partial-fill close requests do not advance the deterministic partial level.
  - Magic-number and symbol scoping are preserved.
- **Validation**: Compile and log review for successful and rejected partial close cases where feasible.

### Task 4.5: Arbitrate Partial TP With Existing TP/SL Lifecycle

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/protection_risk_filter.mqh`
- **Description**: Define ordering between partial TP, final TP, SL, trailing/BE logic if present, and protection forced-close. Protection and SL must be allowed to close remaining volume at any time; partial TP must not reopen or resize positions.
- **Dependencies**: Tasks 4.2 through 4.4.
- **Acceptance Criteria**:
  - SL closes all remaining volume if hit before later partial levels.
  - Protection force-close closes all remaining real broker volume and records no unconfirmed partials.
  - Final TP does not double-close after the 3R partial closes the remainder.
  - Existing trailing partial close code, if still active, is not allowed to conflict with deterministic partial TP state.
- **Validation**: Compile plus tester paths for TP-first, SL-after-partial, and protection close.

## Sprint 5: Statistics Schema Separation

**Goal**: Make exported statistics distinguish candidates, admission decisions, broker entries, real partial closes, final broker outcomes, and hypothetical path labels.
**Commit**: `feat: separate candidate broker and path statistics`
**Demo/Validation**:

- MetaEditor compile at sprint end.
- Human Strategy Tester export review across blocked, admitted, partial TP, SL, and forced-close scenarios.
- Verify blocked signals appear as candidates/admission records but not broker outcomes.
- Verify broker outcome rows require broker entry/close evidence.
- Verify path-ratio labels remain explicitly path-derived and are not presented as broker-realized TP2/TP3 unless a real partial close occurred.

### Task 5.1: Define Statistics Event Taxonomy

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`, `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Define stable event categories: candidate, admission, broker_entry, broker_partial_close, broker_final_outcome, path_label, and lifecycle_cancel.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Each event category has a clear source of truth.
  - Candidate/admission records do not require broker exposure.
  - Broker outcome and partial-close records require broker facts.
- **Validation**: Documentation review plus compile after code changes.

### Task 5.2: Add Or Version Export Columns

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Add backward-compatible columns or a schema-versioned export path for admission status, admission reason, broker evidence flags, planned risk, actual-entry expected risk, expected reward, partial TP state, and path-derived labels.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Old path labels are renamed or clearly prefixed as `path_*` in the new schema.
  - New broker partial fields are populated only from real partial close confirmations.
  - Schema/manifest metadata identifies the new contract.
- **Validation**: Compile and inspect a small export file.

### Task 5.3: Update ML Shadow/Filter Consumers

- **Location**: `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`, `services/trading_signals/deterministic_signal_ml_arbitration.mqh`, `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Ensure ML shadow/filter keeps its approved boundaries. Candidate/admission changes and partial TP stats must not make ML modify lot size, SL/TP, broker reconciliation, live deployment behavior, or existing risk gates.
- **Dependencies**: Tasks 5.1 and 5.2.
- **Acceptance Criteria**:
  - `ML_INFERENCE_SHADOW` remains shadow-only.
  - `ML_INFERENCE_FILTER` remains Strategy Tester only and only denies otherwise admissible deterministic entries after existing broker/risk eligibility passes.
  - Outcome fields used for offline labels are not used as model features.
- **Validation**: Compile and workflow doc review.

### Task 5.4: Add Export Guardrails For False Positives

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Add final export checks that prevent broker outcome rows from being written when broker evidence is missing, even if local lifecycle state says closed.
- **Dependencies**: Tasks 5.1 through 5.3.
- **Acceptance Criteria**:
  - No-ticket/no-deal/no-position signals cannot become broker outcome rows.
  - Canceled/admission-blocked signals are visible only in their proper category.
  - Forced-close projected values cannot leak into broker outcome fields.
- **Validation**: Compile plus tester artifact review.

### Task 5.5: Document Interpretation Rules

- **Location**: `docs/workflows/deterministic-signal-ml-inference-flows.md`, `docs/research/README.md`
- **Description**: Update workflow docs so future analysis correctly separates broker-realized outcomes from path-derived trajectory labels.
- **Dependencies**: Tasks 5.1 through 5.4.
- **Acceptance Criteria**:
  - Docs state that path labels are hypothetical trajectory labels.
  - Docs state that partial TP fields are broker-realized only when confirmed by broker facts.
  - Docs preserve the current no-custom-MQL5-tests validation policy.
- **Validation**: Documentation review.

## Sprint 6: Performance And Tester Readiness

**Goal**: Keep long Strategy Tester runs efficient after lifecycle lanes, broker-first sizing, and partial TP are added.
**Commit**: `perf: harden tester flow for broker-first execution`
**Demo/Validation**:

- MetaEditor compile at sprint end with zero errors and zero warnings.
- Human Strategy Tester matrix covering high spread, target-currency risk cap, partial TP, forced close, normal TP/SL, insufficient margin, and export review.
- Verify no new per-tick string parsing, handle creation, full-history scans, or unbounded logs.

### Task 6.1: Audit Hot Paths After Behavioral Changes

- **Location**: `HFT_Grid_AI.mq5`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Inspect the final tick path for repeated broker API calls, string formatting, file writes, full history scans, and loops over inactive signals.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - `OrderCalcProfit()`, `OrderCalcMargin()`, and `OrderCheck()` are used during planning/admission/reconciliation, not repeatedly for unchanged active positions every tick.
  - Partial TP checks are bounded by active broker positions and the three deterministic levels.
  - Export/log writes stay gated and event-driven where possible.
- **Validation**: Code review plus tester run observation.

### Task 6.2: Gate Debug And File Logging

- **Location**: `services/trading_signals/execution_logging.mqh`, `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Ensure new admission/risk/partial logs are concise and controlled by existing debug/file-log settings.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - No per-tick repeated denial spam for the same signal/reason.
  - Logs include enough broker retcode and reason detail to debug without full trace output.
  - File logging remains optional and does not become a hidden optimization cost.
- **Validation**: Tester log review.

### Task 6.3: Create Human Strategy Tester Verification Matrix

- **Location**: `docs/workflows/deterministic-signal-ml-inference-flows.md` or a new focused doc under `docs/research/`
- **Description**: Document the manual scenarios used to verify the implementation because the project does not use custom MQL5 tests or CI for this scope.
- **Dependencies**: Tasks 6.1 and 6.2.
- **Acceptance Criteria**:
  - Matrix includes setup, expected observation, and artifact/log fields to inspect.
  - Matrix covers high-spread admission block, normal admission, target-currency cap, min-volume infeasible target, partial TP 1R/2R/3R, SL after partial, forced close with no exposure, forced close with exposure, and insufficient margin/precheck denial.
  - Matrix includes tester modeling-mode notes for EA-managed exits.
- **Validation**: Documentation review.

### Task 6.4: Run Final Compile Gate

- **Location**: `HFT_Grid_AI.mq5`, compile logs under the documented project log path.
- **Description**: Run the project compile helper or documented MetaEditor compile command after all implementation changes are complete.
- **Dependencies**: Tasks 6.1 through 6.3.
- **Acceptance Criteria**:
  - Compile exits successfully.
  - Compile log has zero errors and zero warnings unless a documented, approved temporary exception exists.
  - Generated artifacts are not pasted into chat; summarize paths and final status only.
- **Validation**: MetaEditor compile log parsing.

### Task 6.5: Final Human-In-The-Loop Tester Pass

- **Location**: Strategy Tester, chart/log/export artifacts.
- **Description**: Execute the matrix from Task 6.3 and capture a concise result note for each scenario.
- **Dependencies**: Task 6.4.
- **Acceptance Criteria**:
  - All critical safety scenarios pass before considering the plan complete.
  - Any broker/modeling limitation is documented as residual risk rather than hidden in code.
  - Sprint 6 commit is created only after compile and tester review.
- **Validation**: Human Strategy Tester signoff.

## Testing Strategy

- Documentation-only changes do not require MT5 compile.
- Each implementation sprint compiles once at sprint end, not after every atomic task.
- Treat compile warnings as sprint failures unless a human explicitly approves an exception.
- Use the project-preferred helper first:

```bash
python3 tools/mt5/compile_mt5.py
```

- If the helper cannot compile in the current environment, use the portable/headless MetaEditor flow from `docs/environment/mt5-agentic-workflows.md`.
- Human Strategy Tester verification is required for behavior-changing sprints:
  - High-spread block captures candidate/admission status and sends no order.
  - Existing broker position lifecycle still runs while spread is high.
  - No-exposure forced close does not create broker outcome stats.
  - Target-currency risk plan respects expected loss cap after volume normalization.
  - `TP_Percent = 100` produces normalized 1:1 expected money ratio when feasible.
  - Broker margin/precheck denial is structured and prevents send.
  - Partial TP mode off preserves current behavior.
  - Partial TP mode on performs real broker partial closes at 1R/2R/3R when volume constraints allow.
  - SL/protection can close remaining volume after partial TP.
  - Exported statistics separate candidate/admission/path/broker outcome categories.

## Potential Risks And Gotchas

- `OrderCalcProfit()` estimates account-currency P/L under current market/account conditions, but realized P/L can differ because of slippage, gaps, commission, swap, partial-fill behavior, and broker execution.
- `OrderCalcMargin()` and `OrderCheck()` can still differ from final server execution. Final `CTrade` result retcodes and broker reconciliation remain authoritative.
- Rounding down in target-currency mode protects the risk cap but may under-target reward. Min volume can make small targets infeasible; the correct default is to block rather than exceed the cap.
- EA-managed exits can miss exact price touches in sparse ticks or different Strategy Tester modeling modes. This is a tester/modeling limitation and must be documented in the verification matrix.
- Partial close volume normalization is high risk. Intermediate closes can accidentally leave invalid residual volume if min/step rules are not handled carefully.
- `CTrade::PositionClosePartial()` success does not by itself prove final broker execution. Retcode, deal, position volume, and/or history reconciliation must confirm it.
- The EA appears to rely on hedging-compatible behavior for partial position management. Preserve account-mode checks and fail closed if the account mode cannot support the intended lifecycle.
- Broker history can be unavailable or delayed in tester/live contexts. Missing history must produce unknown/unconfirmed broker evidence, not projected profit.
- Splitting the global spread gate may make long tests slower because lifecycle work runs more consistently. Optimize real hot paths instead of reintroducing lifecycle skips.
- Existing trailing partial-close logic must be reviewed so deterministic partial TP does not double-close or conflict with older close candidates.
- New statistics fields can break downstream notebooks/scripts if schema changes are not versioned or documented.

## Rollback Plan

- Roll back one sprint commit at a time in reverse order.
- Because each sprint must be validated and committed independently, the safest rollback point is the last validated sprint.
- If Sprint 4 partial TP causes broker-close instability, disable it by default with `PARTIAL_TP_OFF` and revert only the partial TP commit if needed.
- If Sprint 3 risk sizing causes admission instability, revert target-currency solver changes while preserving Sprint 1 and Sprint 2 outcome-contract fixes where possible.
- If Sprint 1 runtime lane split causes unexpected lifecycle behavior, restore the prior tick order only after confirming no active broker positions can be left unmanaged by the rollback.
- Do not revert unrelated research docs or user-owned changes during rollback.
