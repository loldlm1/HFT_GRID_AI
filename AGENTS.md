# AGENTS Brief · HFT Grid AI EA

This document summarizes the current architecture, workflows, and guardrails for the HFT Grid AI Expert Advisor so agents (and humans) can contribute without wading through outdated roadmap notes.

---

## 1. Quick Facts
- **Entrypoint**: `HFT_Grid_AI.mq5`
- **Services**:
  - `services/trading_management/*`: Input definitions, indicator loader, trend context helpers.
  - `services/trading_management_strategies/*`: Grid trend risk strategy config/helpers and mode-specific glue.
  - `services/trading_signals/market_signal_state.mqh`: Runtime signal arrays, daily budgets, sanity guards.
  - `services/trading_signals/market_signal_indicators.mqh`: Hydrates `SignalParams` with Bollinger/Alligator/Stochastic/body MA datasets per timeframe.
  - `services/trading_signals/market_signal_channel_guards.mqh`: Enforces Alligator-vs-channel gating and the pending stop distance guard shared with the order controller.
  - `services/trading_signals/market_signal_filters.mqh`: Hosts Bollinger/Alligator trigger math plus structure retest/type filtering and slope helpers.
  - `services/trading_signals/market_signal_filters.mqh`: Hosts Bollinger/Alligator trigger math plus structure retest/type filtering, slope helpers, and the shared context evaluators.
  - `services/trading_signals/market_signal_detection.mqh`: Cascaded bullish/bearish admission flow that only evaluates a context when its timeframe prints a new bar, updates the cascade state, runs the grid planner, and registers the signal.
  - `services/trading_signals/market_signal_cleanup.mqh`: Removes chart objects and finalizes state when a grid closes.
  - `services/trading_signals/session_time_filter_manager.mqh`: Parses the Asia/London/NY input windows, blocks new signals outside active sessions, and optionally schedules force-closes when a session ends.
  - `services/trading_signals/*` (remaining files): Grid planner, order controller, protection filter, telemetry.
  - `microservices/*`: Broker helpers, order lifecycle, logging utilities.
  - `services/frontend/*`: Chart overlays and status comment.
- **Constraints**:
  - `Signal_Concurrency_Mode` defaults to `SINGLE_RUNNING_SIGNAL` (one grid per direction) but can be switched to `MULTIPLE_RUNNING_SIGNALS` to authorize concurrent sequences.
  - Include order is fixed; services must not re-include siblings or redeclare globals.

---

## 2. Core Concepts
### 2.1 Fractal Strategy Contexts
| Context | Purpose | Inputs |
| --- | --- | --- |
| Base | Executes on `Strategy_Timeframe`. `Strategy_Base_Entry_Evaluation` now selects the channel entry style (`ENTRY_MODE_MA_TREND` / `ENTRY_MODE_REVERSION` / `ENTRY_MODE_BREAKOUT`, or `ENTRY_EVAL_ON_TREND`), while `Strategy_Base_Trend_Mode` toggles the Alligator branch (`TREND_OFF`, jaws, or teeth). Slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) use the same >=/<= guards as the higher contexts, and the trio `Strategy_Channel_Indicator_Type` + `Strategy_Channel_Indicator_Shift` + `Strategy_Global_Channel_Entry_Mode` controls whether every context hydrates Bollinger/Keltner/ATR data, which channel preset (0/50/100) to compare against, and at which bar shift. Structure filters, Fibonacci retests, and `Base_Fresh_Structure_Time` now track up to four swing slots (`Base_First/Second/Third/Fourth_Structure_Filter`). The freshest timestamp comes from the highest-order filter that is enabled so grids only open once per relevant structure; these structure/fresh toggles still impact only the context’s own signals while feeding the cascade guards. Enable `Base_First_Structure_Close_Percent` when you want the first-structure Fibonacci percent to reflect the current close instead of the completed extremum. | `services/trading_management/ea_inputs.mqh` |
| | `Base_Channel_MA_Filter` optionally blocks new signals whenever the Alligator MA used by the base mode (lips for teeth modes, teeth for jaws modes) sits inside the ATR/Keltner channel on the strategy timeframe, so only clean trends spawn grids. |
| Trend | Optional higher timeframe. Set `Trend_Strategy_Timeframe = PERIOD_CURRENT` to disable. `Strategy_Trend_Entry_Evaluation` mirrors the base menu while `Strategy_Trend_Trend_Mode` picks the Alligator branch, so you can enforce window bias only, mean rejection only, both, or any Alligator/percent pairing. `Trend_BPercent_Slope_Filter`, `Trend_Stochastic_Slope_Filter`, `Trend_Alligator_Slope_Filter`, channel MA filters, and the expanded four-slot structure/fresh guards mirror the base context, with `Trend_Fresh_Structure_Time` using whichever structure slot (first through fourth) is currently enabled. Flip on `Trend_First_Structure_Close_Percent` whenever the cascade should reference the live close percent for that trend swing. | Same |
| | Enable `Trend_Channel_MA_Filter` to apply the same Alligator-vs-channel guard on the trend timeframe so SAR/trend confirmations wait until the trend MA escapes the volatility envelope before authorizing a new sequence. |
| Macro | Optional higher timeframe (e.g., swing H1/H4) with its own `Strategy_Macro_Entry_Evaluation` / `Strategy_Macro_Trend_Mode`, slope toggles, channel MA filter, and structure/fresh guards (`Macro_*` inputs mirror the base set). `Macro_Strategy_Timeframe = PERIOD_CURRENT` disables the layer entirely. | Same |
| Session | Optional intraday context (e.g., M15/M30) via `Strategy_Session_Entry_Evaluation` / `Strategy_Session_Trend_Mode`, letting you enforce session-specific confirmations. Includes the same slope/channel/structure/fresh toggles via the `Session_*` inputs and is disabled when `Session_Strategy_Timeframe = PERIOD_CURRENT`. | Same |

`Strategy_Channel_Indicator_Type` chooses whether every context hydrates Bollinger Percent or the Keltner/ATR datasets. `Strategy_Global_Channel_Entry_Mode` maps the breakout / MA-trend / reversion presets to the canonical 0 / 50 / 100 thresholds (with the bullish/bearish inversion baked into the evaluation), and `Strategy_Channel_Indicator_Shift` picks which bar shift feeds the entry math. Set a context’s evaluation to `ENTRY_EVAL_OFF` to keep its cascade trend state without letting it spawn grids, `ENTRY_EVAL_ON_TREND` to let the associated Alligator branch authorize entries on its own, or `ENTRY_EVAL_GLOBAL` whenever that layer should inherit the global channel mode. `Strategy_Global_Stoch_Entry_Mode` adds an optional stochastic overbought/oversold gate shared by every context.

`StrategyContextEvaluateEntry()` applies the context’s Bollinger breakout (when enabled), slope requirements, structure retests, and the “fresh structure” timestamp guard so each swing is traded once per direction before the cascade allows the next grid.

### 2.2 Grid Framework
- **Spacing**: `ATR_RANGE` vs `POINTS_RANGE`. ATR mode clamps the recalculated base distance so it can’t be smaller than the last realised spacing (prevents hyper-aggressive levels when ATR contracts). When `Strategy_Global_Channel_Entry_Mode` is `ENTRY_MODE_BREAKOUT` or `ENTRY_MODE_REVERSION`, the base distance is measured from price back to the channel midline (MA) because the signal fires at the extremes; `ENTRY_MODE_MA_TREND` keeps using the support/resistance rails.
- `ATR_RANGE` and `KELTNER_RANGE` pull spacing from the respective volatility channel (`ATR_SL_Factor` or `Keltner_Channel`). Use `Grid_Channel_Evaluation_Factor` to scale the percent/evaluation indicators and `Grid_Channel_Volatility_Factor` to scale the grid/trailing channel math (both fall back to `Grid_Channel_Factor` when left at 0). The pending-stop guard still references the smoothed support/resistance lines (ATR SMA bands or the Keltner upper/lower rail).
- `Grid_Points_Range_Setup` keeps its fixed-point meaning for `POINTS_RANGE` but also serves as the minimum distance allowed between the current stop price and the channel anchor whenever a volatility strategy is active. If the pending stop sits closer than that floor, the signal is rejected (or the pending stop is cancelled while still `GRID_ORDER_STOP_TRAILING_ACTIVE`). Once a ladder fills, the original spacing is cached so deeper levels remain consistent even if volatility contracts mid-cycle.
- `Grid_Risk_Trend_Mode` optionally enforces Alligator exits on the timeframe you select via `Grid_Risk_Timeframe_Source` (strategy, trend, macro, or session) or an explicit `Grid_Risk_Trend_Timeframe` override. Pair it with `Grid_Risk_Alligator_Reference` to decide whether the jaws or teeth line acts as the breaker: `GRID_RM_TREND_OFF` disables it, `GRID_RM_TREND_BE` closes the grid (only at ≥ break-even) when the most recent level entry sits beyond that line, `GRID_RM_TREND_SL` turns that comparison into a hard stop, `GRID_RM_TREND_SAR` flips the grid to the opposite direction (reusing the latest level’s lot size) whenever the breach happens, and `GRID_RM_TREND_HEDGE` opens an equal-opposite hedge alongside the first filled level, maintains an optional SL buffer (`Grid_Risk_Trend_Hedge_Points`/`Grid_Risk_Trend_Hedge_SL`), and force-closes the grid + hedge once at least `Grid_Risk_Trend_Hedge_Level_Cover` filled levels leave the grid floating P/L above zero.
- **Trailing strategy**: `Grid_Trailing_Strategy_Mode` picks between price-offset trailing, the volatility channel (ATR SMA or Keltner upper/lower), or Alligator lips MA (shift=1). Indicator-based trailing adds the configured `Grid_Trailing_TP_Percent` offset to the channel/Lips value and clamps with `MathMax`/`MathMin` so the trailing anchor never retreats below (bullish) / above (bearish) the indicator. `Grid_Trailing_Timeframe` can override the indicator timeframe (defaulting to the base strategy TF), and `Grid_Trailing_Execution_Mode` defaults to price-triggered trailing; `TRAILING_EXECUTION_AGGRESIVE` now waits only until the indicator clears the TP reference, so level-cap scenarios follow the same activation rules as every other grid.
- **Break-even strategy**: `Grid_BreakEven_Mode` now owns BE automation. `BE_DISABLE` skips it entirely, `BE_ENABLE` arms BE (using the spread/freeze buffer) once a level’s `Grid_TP_Percent` target is touched and propagates that anchor across every shallower filled level, while `BE_PARTIAL_ENABLE` also closes `Grid_Partial_Take_Percentage` of the triggering level (only when volume permits) so profits are skimmed progressively. Each level contributes at most one partial, and the BE anchor walks inward level-by-level while trailing can still win the race to exit.
- **Exponential spread**: `Grid_Exponential_Multiplier` scales `ComputeLevelDistancePoints()` per level. `Grid_Points_TP` (when > 0) overrides the percent-based TP span with a fixed point value per level, similar to how `Grid_Points_Range_Setup` works for `POINTS_RANGE`.
- **Lot sizing**:
  - Constant size, account %, equity %, currency budget, or `GRID_LOT_CALCULATED` (drawdown recovery using `Grid_Lot_Multiplier`).
  - `GRID_LOT_MAX_MARGIN_SPLIT` spends as much free margin as possible and splits it into `Pandora_Lot_Strategy_Size` chunks (rounded to at least 1) so each level opens with the largest margin-safe lot; volumes are recalculated right before order submission to stay aligned with live prices/margin.
  - All conversions reuse the live entry→TP span from `GridResolveLotReferencePoints()`.
- **Fresh diagnostics**: `GridLogEvent()` and `grid_visualization` surfaces ENTRY/TP/NEXT lines so backend/front-end stay in sync.

### 2.3 Order Lifecycle & Protection
1. `GridExecuteLevelTrade()` enforces spread/margin guardrails. On insufficient funds, `g_debug_no_money_abort_pending` signals the debug stop path.
2. `GridOrderController` transitions STOP→ACTIVE→TRAILING, instantiates deeper levels sequentially, and respects final TP and trailing logic.
3. `ProtectionRiskFilter` (drawdown + daily lock) force-closes all grids and maintains broker status (`market_status_controller`).
4. **Debug stops**:  
   - `Enable_Trend_Filter_Sanity_Stop`: `TesterStop()` when trend inputs are disabled while being stepped in Strategy Tester.  
   - `Debug_Stop_On_Negative_Euity`: Force-closes every grid then `TesterStop()` when equity ≤ 0 **or** the broker rejects an order with “no money”.

### 2.4 Grid Risk Controls
- `Grid_Level_Position_Start`: Defers opening real broker positions until the grid reaches this level index. Lower indices remain “virtual” so spacing, TP references, and channel guards still track price without consuming margin.
- `Grid_Level_Stop_Limit`: Maximum number of grid levels (including level 0). When the next averaging step would exceed this limit, the EA force-closes the entire sequence instead of adding more exposure. `0` keeps the legacy unlimited behaviour.
- `Daily_Signal_Limit` + `Daily_Signal_Limit_Mode`: Daily budget per direction. `STOP_DAILY_SIGNALS` limits total grids started; `STOP_DAILY_SIGNALS_ON_LOSS` only counts losing grids (winners do not consume the quota). Counters reset automatically on the next D1 candle.

---

## 3. Workflow Snapshot
1. **Initialization**
   - `ea_inputs.mqh` defines all inputs.
   - `indicator_definitions_loader.mqh` prepares timeframes, instantiates Bollinger Percent + stochastic structure handles only when required (base and/or trend).
   - `broker_constraints_helper` caches freeze/stop distances per symbol.

2. **Signal Admission**
   - `DetectStrategySignals()` walks the contexts in session → macro → trend → base order. Each layer is evaluated only when `iTime(_Symbol, context_tf, 0)` advances, so higher timeframes no longer spam redundant computations. Per-context runtime state (last bar time, trend ready/pass per direction, fresh-structure timestamp) lives in `market_signal_state.mqh`, so the loop stays stateless and avoids scattered globals.
   - `CaptureContextIndicators()` hydrates a `StrategyContextIndicators` snapshot with Bollinger/Alligator/Stochastic/structure data only when the context’s entry mode, slope toggles, channel MA filter, or fresh-structure guard require them.
   - `StrategyContextEvaluateTrend()` updates the cascade state for that context, `StrategyCascadeAllowsSignal()` ensures lower contexts only fire when upstream trend modes are green, and `StrategyContextEvaluateEntry()` enforces the Bollinger breakout (when enabled), slope checks, structure retests, and fresh-structure timestamps per context. `StrategyContextChannelMaFilterAllowsSignal()` applies the optional Alligator-vs-channel guard on the same timeframe. Upstream trend states are refreshed once per base-context bar to keep the cascade aligned with the latest base bar without reprocessing higher layers every tick.
   - `SessionTimeFilterAllowsSignalAttempt()` (backed by the new manager) runs after protection/debug checks so new grids are only authorized inside enabled session windows. `SESSION_FILTER_FORCE_CLOSE` windows also schedule a force-close when their timer expires, while `SESSION_FILTER_ALLOW_RUN` lets existing grids finish.
   - When the cascade, entry, and channel guard succeed (and `CanAttemptSignal()` approves direction/daily/concurrency limits) the context hands the request to the grid planner.

3. **Grid Planning**
   - `BuildGridSignalPoints()` resolves base distance (ATR or points) using the signal’s context timeframe and clamps ATR spacing relative to the latest realised level. Entry offsets respect broker distances.
   - `ResolveGridOrderLotSize()` calculates lots per level, accounting for percent/currency budgets and the `GRID_LOT_CALCULATED` martingale mode.

4. **Order Lifecycle**
   - `GridExecuteLevelTrade()` sends the order, registers failures via `MarketStatusRegisterBrokerFailure()`, and sets `g_debug_no_money_abort_pending` for no-money retcodes.
   - `GridOrderController` updates trailing references, instantiates deeper levels only after fills, and closes grids on final TP or trailing hits.
   - `GridCloseAllLevels()` is reused by protection filters and debug stops to ensure MT5 reports only realised positions.

5. **Protection & Telemetry**
   - `ProtectionRiskFilter` enforces drawdown guard, market close guard, and daily lock.
   - `market_status_controller` coordinates `ACTIVE / CLOSE_GUARD / BROKER_CLOSEONLY / BROKER_DISABLED` transitions and pending force closes.
   - `grid_visualization` mirrors backend state on chart objects; `Comment()` prints status summary (`Enabled/Disabled`, magic number, market status, running grid stats) and now annotates each grid with its context label/timeframe (e.g., `BULL BASE@M1`).

---

## 4. Coding Guidelines
- **Style**: 2 spaces, snake_case variables, CamelCase functions, ALL_CAPS enums/constants. No C++11 features (no `auto`, lambdas, range-for).
- **Guardrails**: Always call `EnforceBrokerDistance()` when manipulating point distances and `NormalizeVolumeForSymbol()` when touching lots.
- **Error Handling**:
  - Check every indicator handle; call `TesterStop()` when a critical handle is invalid during tester runs.
  - Wrap trade operations; log `GetLastError()` and propagate retcodes through `MarketStatusRegisterBrokerFailure()`.
- **Data Safety**: Validate array sizes (`ArraySize()`), clamp indices, and avoid reallocation loops (use `ArrayResize(..., size, reserve)`).
- **Dependencies**:
  - Tools → Signals → Management → Frontend (no circular includes).
  - Services may rely on lower layers only; never re-include aggregator headers.

---

## 5. Testing & Debugging
- **Strategy Tester**: Run “Every tick based on real ticks” for parity with tick-by-tick logic. Enable `Enable_Logs`/`Enable_File_Logs` during development.
- **Debug Flags**:
  - `Enable_Trend_Filter_Sanity_Stop` prevents wasted optimization passes when trend parameters are misconfigured.
  - `Debug_Stop_On_Negative_Equity` terminates hopeless simulations early and ensures all grids are closed so MT5 equity curves reflect realised P/L.
- **Log Files**: `query_debug.txt` captures structured events (grid geometry, guardrail blocks, lifecycle transitions). Clear or rotate the file between long test sessions.
- **Chart Output**: Use `Enable_Chart_Levels` and `Enable_Chart_Summary` to visualize backend state; disable for performance-sensitive optimizations.

---

## 6. Reference Snippets
**Standard error pattern**
```mql5
if(!SomeOperation())
{
  Print("SomeOperation failed: ", GetLastError());
  return false;
}
```

**Critical indicator guard (Strategy Tester)**
```mql5
if(handle == INVALID_HANDLE)
{
  Print("ERROR loading indicator: ", GetLastError());
  TesterStop();
  return INIT_FAILED;
}
```

**Structure-aware guard**
```mql5
if(!snapshot.structure_valid)
  return false;
```

---

## 7. Deliverables Checklist (Live)
Use this checklist when implementing or reviewing features:
- [ ] Inputs documented in `ea_inputs.mqh` with sane defaults.
- [ ] Indicator load logic updated when new contexts or filters are added.
- [ ] Signal gating covers breakout + slope + structure + fresh-structure timestamps.
- [ ] Grid planning enforces broker distances and ATR clamp rules.
- [ ] Order lifecycle guards trade sends and logs failures.
- [ ] Protection filters close grids and maintain market status consistency.
- [ ] Documentation (README + AGENTS) updated after functional changes.

Keeping this brief current ensures new agents can align quickly with the active architecture without sifting through obsolete phase plans.

---

## 8. Shared License Guard Rules
- Canonical implementation lives at `services/shared/license_guard_v1/*`.
- Use direct include + profile macros in EA entrypoints:
  - `services/shared/license_guard_v1/license_service.mqh`
- Do not reimplement verify/heartbeat/daily-results logic in EA-specific files.
- Runtime live magic must come from `LicenseGetCachedMagicNumber()` after successful startup verify.
- Missing/invalid backend `magic_number` is fail-closed and must trigger EA removal.
- Daily results dedupe and aggregation must stay scoped by `ea_id + magic_number` (deal filtering by `DEAL_MAGIC`).
- Add-on entitlements are profile-specific:
  - EAs with required add-ons must set `LICENSE_SHARED_REQUIRED_ADDONS_CSV`.
  - EAs without required add-ons must keep the value empty.
- Migration and rollout instructions are defined in `services/shared/license_guard_v1/license-shared-service-migration-plan.md`.
