# Trade Execution Flow Audit - 2026-07-09

Status: no-code research.

Scope:

- Audit current trade execution and signal/order flow.
- Identify whether global gates such as `Max_Spread` block signal management or make long Strategy Tester runs inefficient.
- Check deterministic signal boundaries and broker-aware assumptions.
- Review risk/lot calculations for `Lot_Type`, especially `EXECUTION_LOT_TARGET_CURRENCY`.
- Review fixed path-ratio statistics versus broker-confirmed execution facts.

Non-goals:

- No source code changes.
- No compile or Strategy Tester run.
- No new inputs, tests, CI, or custom MQL5 harness.

## Executive Summary

The current EA has a broker-aware local admission layer, ticket-first reconciliation, scoped broker facts, and broker-entered feature export. That is a strong foundation.

The main issue is the global `OnTick()` spread/market-open early return. It blocks not only new entries, but also deterministic signal lifecycle, pending-signal refresh, broker reconciliation, TP/SL lifecycle decisions, and normal cleanup. Protection/risk monitoring still runs before the return, but normal signal management does not. This makes `Max_Spread` a broad runtime stop rather than only an entry/send guard.

There is also a false-positive statistics risk in forced-close paths. `ProtectionRiskForceCloseSignalArray()` calls `CloseAllExecutionLegs()` for initialized signals. `CloseAllExecutionLegs()` can register realized profit and closed volume for legs with no broker ticket, because `CloseExecutionLegBrokerPosition()` returns true when `position_ticket <= 0`. That can satisfy `SignalHasBrokerConfirmedOutcome()` indirectly and allow deterministic outcomes that are projected, not broker-confirmed.

For `EXECUTION_LOT_TARGET_CURRENCY`, the intent is clear: with `Lot_Strategy_Size = 50` and `TP_Percent = 100`, the algorithm targets about 50 account-currency units at the configured TP span. However, current lot conversion uses tick value math and rounds upward to broker volume step. That means actual realized P/L can exceed target by at least one volume step, and the profit estimate may be less broker-exact than `OrderCalcProfit` for some symbols/account modes. Margin admission is also an estimate using `SYMBOL_MARGIN_INITIAL` or contract/leverage math, not `OrderCalcMargin`.

The fixed path-ratio labels (`1R`, `1.5R`, `2R`, `3R`, SL-first) are outcome-side and excluded from model features. They are efficient enough because they are bounded and only tracked after feature export, but they are not broker-side TP2/TP3 facts. They use bid/ask path observation and wait for a broker outcome before writing. This is good for trajectory research, but should be explicitly labeled as path-derived rather than broker-realized.

## Current Flow

Entrypoint and include chain:

- `HFT_Grid_AI.mq5` includes services in the expected project order: license, tools, management, strategies, signals, frontend.
- `services/trading_signals.mqh` includes state, filters, broker context, reconciliation, lot math, lifecycle, statistics, ML, planner, controller, tick manager, and protection risk in order.

Runtime flow in `OnTick()`:

1. Refresh symbol rates.
2. Update deterministic path tracker.
3. Run debug/protection risk guards.
4. Monitor session once per minute.
5. If spread is above `Max_Spread` or market is closed, return early.
6. On new base bar, detect new deterministic strategy signals.
7. On every allowed tick, update/manage running signals.
8. Refresh frontend when due.

Evidence:

- `HFT_Grid_AI.mq5:203` starts `OnTick()`.
- `HFT_Grid_AI.mq5:205` refreshes rates.
- `HFT_Grid_AI.mq5:206` updates path stats before the spread gate.
- `HFT_Grid_AI.mq5:208-209` runs protection monitoring/filtering before the spread gate.
- `HFT_Grid_AI.mq5:230-239` returns early when `g_points_spread > Max_Spread` or `!IsMarketOpen()`.
- `HFT_Grid_AI.mq5:248-257` detects signals only after that gate.
- `HFT_Grid_AI.mq5:259-263` manages running signals only after that gate.

## Finding 1: `Max_Spread` Blocks More Than Entries

Severity: high for backtest determinism and lifecycle correctness.

The spread guard appears twice:

- Global runtime stop in `OnTick()`: `HFT_Grid_AI.mq5:230-239`.
- Local broker-aware admission block: `services/trading_signals/execution_broker_context.mqh:397-405`.

The local admission block is the right place to deny new broker entries. It applies after the signal and execution leg exist and before broker send.

The global `OnTick()` return is broader. It prevents:

- new signal detection on new M1 bars;
- pending deterministic entry anchor refresh;
- entry trigger confirmation;
- broker reconciliation;
- active TP/SL lifecycle close decisions;
- cleanup of completed normal lifecycles.

Protection force-close logic still runs before the return, but normal lifecycle management does not.

Impact:

- Backtests can miss deterministic signals that would have existed under the strategy rules but were skipped because a spread spike occurred at the bar-open management point.
- Open broker positions can remain unmanaged by the normal deterministic TP/SL lifecycle while spread is high.
- Statistics become conditional on the global runtime gate rather than only broker admissibility.
- Performance may improve during high-spread windows, but by skipping trading lifecycle work rather than by making the work cheaper.

Research conclusion:

`Max_Spread` currently acts as a global runtime throttle. For deterministic signal research, it should be treated as an entry/admission guard, not as a full signal-management kill switch, unless that behavior is explicitly desired.

## Finding 2: Forced-Close Path Can Create Projected Broker Outcomes

Severity: high for false-positive statistics.

`ProtectionRiskForceCloseSignalArray()` force-closes every running signal:

- It calls `CloseAllExecutionLegs()` when `execution_initialized` is true.
- It sets signal state to `CLOSED`.
- It sets `raw_profit` from `realized_profit`, with a fallback to `RawProfitUsd`.
- It records daily outcome, lot sequence outcome, deterministic stats outcome, and ML shadow outcome.

Evidence:

- `services/trading_signals/protection_risk_filter.mqh:107-150`.
- `services/trading_signals/protection_risk_filter.mqh:153-158`.

`CloseAllExecutionLegs()`:

- Iterates all execution legs.
- Calls `ResolveExecutionLegTrackedVolume()`.
- Calls `CloseExecutionLegBrokerPosition()`.
- If the close result is true, calls `RegisterSignalRealizedClose()`.

Evidence:

- `services/trading_signals/execution_lifecycle.mqh:605-628`.

The problem is that `CloseExecutionLegBrokerPosition()` returns true immediately when `position_ticket <= 0`, and `RegisterSignalRealizedClose()` does not require a broker ticket or a previously selected broker position.

Evidence:

- `services/trading_signals/execution_lifecycle.mqh:354-392`.
- `services/trading_signals/execution_lifecycle.mqh:89-108`.

Then `SignalHasBrokerConfirmedOutcome()` treats `realized_closed_volume > 0`, non-zero `realized_profit`, `position_ticket > 0`, `ACTIVE`, or `entry_price > 0` as broker-confirmed.

Evidence:

- `services/trading_signals/market_signal_state.mqh:501-520`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:2070-2081`.

Impact:

- A pending deterministic signal that never opened a broker position can be force-closed and assigned projected P/L.
- That projected P/L can pass the stats broker-outcome check because the forced-close path already populated `realized_closed_volume`.
- This can create false positives in deterministic outcomes and ML shadow outcomes during risk/session/market-status forced-close paths.

Research conclusion:

Broker-confirmed outcome status should be tied to actual broker exposure or historical deals, not to locally projected close math. The current normal cleanup path is more conservative for canceled deterministic signals, but force-close paths need a stricter broker exposure check.

## Finding 3: Target Currency Lot Sizing Is Directionally Correct But Not Broker-Exact

Severity: medium-high for risk precision.

Current `EXECUTION_LOT_TARGET_CURRENCY` flow:

1. `ResolveExecutionRuntimeTargetProfitAmount()` maps `Lot_Strategy_Size` and `TP_Percent` to a target amount.
2. `ResolveBaseExecutionLot()` converts the target amount over the TP reference points into lots.
3. `ConvertAmountToLots()` uses `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_TICK_SIZE`, and `SYMBOL_POINT`.
4. `NormalizeVolumeUpForSymbol()` rounds upward to the broker step.

Evidence:

- `services/trading_signals/execution_lot_math.mqh:46-82`.
- `services/trading_signals/execution_planner.mqh:133-165`.
- `services/utils/money_functions.mqh:92-115`.
- `services/trading_signals/execution_lot_math.mqh:258-324`.

Example:

- `Lot_Type = EXECUTION_LOT_TARGET_CURRENCY`
- `Lot_Strategy_Size = 50`
- `TP_Percent = 100`

The current intended target is approximately 50 account-currency units at 1R/TP. This is not guaranteed to be exactly 50:

- volume is rounded up to broker step, so target can be exceeded;
- min volume can force oversizing;
- max volume can make the target infeasible;
- tick-value math may differ from broker profit calculation on some instruments;
- spread/slippage/commission/swap are not part of the pre-trade target math;
- after broker fill, deterministic TP is refreshed from broker entry price, but the lot is not recalculated from the fill price.

Official MQL5 API relevance:

- `OrderCalcProfit` calculates estimated profit for the current account and market conditions and returns it in account currency.
- `OrderCalcMargin` calculates required margin for a planned operation in account currency.

Research conclusion:

The current calculation is coherent as an approximation and intentionally conservative by rounding lots upward. It is not "impeccable" in the strict broker-exact sense. For exact target-currency semantics, future work should size lots by solving against `OrderCalcProfit()` at the planned entry/TP prices and validate margin with `OrderCalcMargin()` or `OrderCheck()`.

## Finding 4: Margin Guard Uses An Estimate, Not Broker Margin Calculation

Severity: medium.

`CaptureBrokerExecutionSnapshot()` estimates margin by:

- reading `SYMBOL_MARGIN_INITIAL`, or
- falling back to `contract_size * price / leverage`.

Evidence:

- `services/trading_signals/execution_broker_context.mqh:181-204`.
- `services/trading_signals/execution_broker_context.mqh:283-289`.
- `services/trading_signals/execution_broker_context.mqh:448-472`.

This is useful but incomplete for broker-exact validation because symbol/account margin rules can vary by instrument, account mode, hedging offsets, leverage tiers, and broker settings.

Research conclusion:

For production-grade broker determinism, margin should be checked with broker-aware APIs before send. The current send still depends on broker retcode failure handling, but the local pre-admission decision may allow or deny trades differently from the trade server.

## Finding 5: Broker Constraints Are Present But Mostly Used As Local Geometry Guards

Severity: medium.

Strengths:

- Constraints are loaded on init and refreshed every 60 seconds.
- The snapshot includes bid/ask, spread, stops, freeze, volume normalization, margin, session, protection, direction and concurrency flags.
- Distances are validated before admission.

Evidence:

- `services/utils/broker_constraints_helper.mqh:44-78`.
- `services/trading_signals/execution_broker_context.mqh:222-293`.
- `services/trading_signals/execution_broker_context.mqh:314-337`.
- `services/trading_signals/execution_broker_context.mqh:339-477`.

Limit:

- Real broker orders are market `Buy/Sell` with `sl=0.0` and `tp=0.0`.
- TP/SL are managed by EA-side lifecycle closes, not broker-side SL/TP.

Evidence:

- `services/trading_signals/execution_lifecycle.mqh:283-289`.
- `services/trading_signals/execution_controller.mqh:565-588`.

Research conclusion:

Broker constraints are respected before entry decisions, but exits are not server-side protected. This can be intentional for deterministic research, but it means "broker-side deterministic TP/SL" is not current behavior.

## Finding 6: Path Ratio Statistics Are Path-Derived, Not Broker-Side TP2/TP3

Severity: medium for interpretation, low for leakage.

The current fixed path stats:

- are created only after broker entry feature export;
- use entry price, stop price, and risk distance;
- update every tick using `g_bid` for bullish and `g_ask` for bearish;
- label hits for 1R, 1.5R, 2R, 3R, SL-first and horizon expiry;
- write only after a broker outcome is available or on run finalization.

Evidence:

- `services/trading_signals/deterministic_signal_statistics_export.mqh:1675-1732`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:779-892`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:1951-1975`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:2021-2050`.

Strength:

- Path labels are excluded from model features by workflow contract.
- They are bounded by `DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS = 2880`.

Evidence:

- `docs/workflows/deterministic-signal-ml-inference-flows.md:178-192`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:17`.

Limit:

- They do not prove that TP2/TP3 would have been executed by the broker.
- They do not account for broker order server execution, partial fills, real exit deals, commission, swap, or slippage.
- They update before the global spread gate, so path labels continue during periods where normal lifecycle management is blocked.

Research conclusion:

These labels are valid as path outcomes, not as broker-realized TP2/TP3 outcomes. If future research enables dynamic TP2/TP3 management, those stats should come from the same broker execution/risk basis as the actual position lifecycle, or be explicitly separated as hypothetical path labels.

## Finding 7: Backtest Performance Is Bounded But Has Known Hotspots

Severity: medium.

Efficient/currently good:

- Indicator handles are created on init or cached, not per tick.
- Frontend chart work is disabled in non-visual tester.
- Visual frontend refresh is throttled to one second.
- Stoch Structure buffer reads are bounded.
- Deterministic M1 rates are cached by tick timestamp.

Evidence:

- `services/trading_management/indicator_definitions_loader.mqh:89-126`.
- `services/trading_management/indicator_definitions_loader.mqh:314-340`.
- `services/trading_signals/execution_indicator_cache.mqh:41-87`.
- `services/frontend/runtime_guard.mqh:10-20`.
- `services/frontend/runtime_guard.mqh:44-59`.
- `services/indicators/extrema_detector.mqh:7-29`.
- `services/trading_signals/execution_controller.mqh:4-36`.

Hotspots:

- Each structure evaluation copies 5 buffers up to 2048 bars and scans until it finds configured extrema.
- `DetectDeterministicStrategySignals()` runs on new base bars after the global gate.
- Path tracker runs every tick when stats are enabled and iterates all tracked states.
- Protection risk scans all positions every tick when enabled.
- File logging can become expensive if `Enable_File_Logs` is on.

Evidence:

- `services/indicators/extrema_detector.mqh:106-132`.
- `services/trading_signals/market_signal_detection.mqh:394-424`.
- `services/trading_signals/deterministic_signal_statistics_export.mqh:2021-2050`.
- `services/trading_signals/protection_risk_filter.mqh:49-77`.
- `services/trading_signals/execution_logging.mqh:278-307`.

Research conclusion:

The current performance profile is acceptable for normal tester mode but can degrade with feature export, ML/filter, path tracking, file logs, visual mode, and many concurrent signals. The global spread gate can make tests faster, but by skipping lifecycle work that affects determinism.

## Recommended Future Plan

No code was changed in this research. If the team decides to implement follow-up work, create a new `$planner` plan under `docs/plans/`.

Recommended phases:

1. Split global runtime gating into lifecycle-safe lanes.
   - Always run broker reconciliation, active-position risk/TP/SL management, cleanup, and forced-close queues.
   - Apply spread guard only to new broker entry/admission.
   - Decide explicitly whether high spread should block new signal creation or only broker send.

2. Harden broker-confirmed outcomes.
   - Do not let `CloseAllExecutionLegs()` register realized close for legs without broker ticket/exposure.
   - Require actual broker position/deal evidence for deterministic outcome export.
   - Keep canceled pending signals as canceled/invalid, not profit/loss.

3. Make target-currency lot sizing broker-exact.
   - Use `OrderCalcProfit()` to solve required lots at planned entry/TP.
   - Round according to broker volume step and report expected overshoot/undershoot.
   - Revalidate after broker fill if TP is recalculated from actual entry.
   - Use `OrderCalcMargin()` or `OrderCheck()` for margin admission.

4. Clarify path stats contract.
   - Keep current labels as `path_*` hypothetical trajectory labels.
   - Add broker-side TP2/TP3 stats only if actual broker lifecycle supports those exits.
   - Separate simulated/path labels from broker-realized outcomes in filenames or manifest fields.

5. Profile long tester runs before optimizing.
   - Compare normal tester, visual tester, feature export, ML shadow/filter, and file logging on/off.
   - Measure Stoch Structure copy depth and path state counts.
   - Avoid adding CI/custom MQL5 tests per project policy.

## Validation Notes

No compile was run because this is documentation-only research.

External API references used:

- MQL5 `OrderCalcProfit`: https://www.mql5.com/en/docs/trading/ordercalcprofit
- MQL5 `OrderCalcMargin`: https://www.mql5.com/en/docs/trading/ordercalcmargin
- MQL5 `CTrade::Buy`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy
