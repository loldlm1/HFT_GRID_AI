# AGENTS Brief · HFT Grid AI EA

This document summarizes the current architecture, workflows, and guardrails for the HFT Grid AI Expert Advisor so agents (and humans) can contribute without wading through outdated roadmap notes.

---

## 1. Quick Facts
- **Entrypoint**: `HFT_Grid_AI.mq5`
- **Services**:
  - `services/trading_management/*`: Input definitions, indicator loader, trend context helpers.
  - `services/trading_signals/*`: Signal detection, grid planner, order controller, protection filter.
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
| Base | Executes on `Strategy_Timeframe`. `Strategy_Base_Mode` now lets you pick the Bollinger Percent confirmation style: `TREND_BPERCENT_WINDOW` trades the discount window bias, `TREND_BPERCENT_MEAN` focuses on the mean-trend rejection, and `TREND_BPERCENT_WINDOW_AND_MEAN` requires both, each optionally paired with the shared Alligator branch. The Alligator menu splits into jaws (`TREND_ALLIGATOR_JAWS*`, legacy behaviour) and teeth (`TREND_ALLIGATOR_TEETH*`) branches; the latter enforce `lips > teeth > jaws` (bearish flips the inequality) and automatically reuse `Alligator_Lips_Period` for Bollinger Percent so the base confirmations track the lips MA while the Alligator teeth still reuse `Base_Indicator_Period_Type`. `Base_Indicator_Percent` plus slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) mirror the trend context’s >=/<= guards, while `Alligator_Jaws_Period`/`Alligator_Lips_Period` (declared in the Strategy Context group) drive the Alligator branch. Structure filters, Fibonacci retests, and `Base_Fresh_Structure_Time` gate swings by snapshotting `first_structure_time` by default or `second_structure_time` whenever `Base_Second_Structure_Filter` is active so grids only open once per structure. | `services/trading_management/ea_inputs.mqh` |
| Trend | Optional higher timeframe. Set `Trend_Strategy_Timeframe = PERIOD_CURRENT` to disable. `Strategy_Trend_Mode` mirrors the same expanded menu of Bollinger-window confirmations and jaws/teeth Alligator combinations, so you can enforce window bias only, mean rejection only, both, or any Alligator/BPercent pairing. `Trend_BPercent_Slope_Filter`, `Trend_Stochastic_Slope_Filter`, and `Trend_Alligator_Slope_Filter` gate simple shift-0 slope checks (bullish ≥, bearish ≤). The shared Alligator inputs keep jaws/lips synchronized, and slope/structure/fresh guards mirror the base context, including `Trend_Fresh_Structure_Time` switching to `second_structure_time` when the second structure filter is enabled. | Same |

`EvaluateSignalTrigger()` merges both contexts: Bollinger breakout, slope requirement, structure retests, and the “fresh structure” timestamp guard so each swing is traded once per direction.

### 2.2 Grid Framework
- **Spacing**: `ATR_RANGE` vs `POINTS_RANGE`. ATR mode clamps the recalculated base distance so it can’t be smaller than the last realised spacing (prevents hyper-aggressive levels when ATR contracts).
- `Grid_ATR_Range_Mode` decides whether ATR spacing comes from the horizontal HH/LL buffers, the trailing rails, both (safer of the two), the raw ATR envelopes (`BufferMAUpper`/`BufferMALower`), or the new ATR SMA references (simple moving averages of each band so bearish grids reuse the smoothed peaks and bullish grids reuse the smoothed bottoms).
- When `ATR_RANGE` is active, `Grid_Points_Range_Setup` also enforces a hard floor using those ATR SMA references. If the buy-stop or sell-stop sits closer to the ATR SMA than the configured points, the signal is rejected (or pending stop canceled while it’s still `GRID_ORDER_STOP_TRAILING_ACTIVE`). Once level 0 is filled this guard is skipped, but the original spacing is cached so deeper levels can still respect the initial ladder geometry.
- `Grid_Risk_Trend_Mode` optionally enforces Alligator exits on the timeframe you select via `Grid_Risk_Timeframe_Source` (base or trend). Pair it with `Grid_Risk_Alligator_Reference` to decide whether the jaws or teeth line acts as the breaker: `GRID_RM_TREND_OFF` disables it, `GRID_RM_TREND_BE` closes the grid (only at ≥ break-even) when the most recent level entry sits beyond that line, `GRID_RM_TREND_SL` turns that comparison into a hard stop, and `GRID_RM_TREND_SAR` flips the grid to the opposite direction (reusing the latest level’s lot size) whenever the breach happens.
- `Grid_ATR_Factor` configures the ATR helper indicator’s multiplier, while `Grid_Points_Range_Setup` owns the fixed-point spacing used when `POINTS_RANGE` is active.
- **Trailing strategy**: `Grid_Trailing_Strategy_Mode` picks between price-offset trailing, ATR trailing rails (shift=1), or Alligator lips MA (shift=1). Indicator-based trailing adds the configured `Grid_Trailing_TP_Percent` offset to the indicator value and clamps with `MathMax`/`MathMin` so the trailing anchor never retreats below (bullish) / above (bearish) the indicator. `Grid_Trailing_Timeframe` can override the indicator timeframe (defaulting to the base strategy TF), and `Grid_Trailing_Execution_Mode` defaults to price-triggered trailing; `TRAILING_EXECUTION_AGGRESIVE` now waits only until the indicator clears the TP reference, so level-cap scenarios follow the same activation rules as every other grid.
- **Break-even strategy**: `Grid_BreakEven_Mode` now owns BE automation. `BE_DISABLE` skips it entirely, `BE_ENABLE` arms BE (using the spread/freeze buffer) once a level’s `Grid_TP_Percent` target is touched and propagates that anchor across every shallower filled level, while `BE_PARTIAL_ENABLE` also closes `Grid_Partial_Take_Percentage` of the triggering level (only when volume permits) so profits are skimmed progressively. Each level contributes at most one partial, and the BE anchor walks inward level-by-level while trailing can still win the race to exit.
- **Exponential spread**: `Grid_Exponential_Multiplier` scales `ComputeLevelDistancePoints()` per level. `Grid_Points_TP` (when > 0) overrides the percent-based TP span with a fixed point value per level, similar to how `Grid_Points_Range_Setup` works for `POINTS_RANGE`.
- **Lot sizing**:
  - Constant size, account %, equity %, currency budget, or `GRID_LOT_CALCULATED` (drawdown recovery using `Grid_Lot_Multiplier`).
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
- `Grid_Level_Stop_Limit`: Maximum number of grid levels (including level 0). When the next averaging step would exceed this limit, the EA force-closes the entire sequence instead of adding more exposure. `0` keeps the legacy unlimited behaviour.
- `Daily_Signal_Limit` + `Daily_Signal_Limit_Mode`: Daily budget per direction. `STOP_DAILY_SIGNALS` limits total grids started; `STOP_DAILY_SIGNALS_ON_LOSS` only counts losing grids (winners do not consume the quota). Counters reset automatically on the next D1 candle.

---

## 3. Workflow Snapshot
1. **Initialization**
   - `ea_inputs.mqh` defines all inputs.
   - `indicator_definitions_loader.mqh` prepares timeframes, instantiates Bollinger Percent + stochastic structure handles only when required (base and/or trend).
   - `broker_constraints_helper` caches freeze/stop distances per symbol.

2. **Signal Admission**
   - `CanAttemptSignal()` checks protection risk, market status, indicator availability, the selected concurrency mode, and (if enabled) debug equity/insufficient-funds conditions.
   - `LoadTrendStructureData()` seeds `SignalParams` with trend data when the trend layer is active.
   - `EvaluateSignalTrigger()` runs breakout + slope + structure/fresh validations and persists the structure timestamps used to gate future trades.

3. **Grid Planning**
   - `BuildGridSignalPoints()` resolves base distance (ATR or points) and clamps ATR spacing relative to the latest realised level. Entry offsets respect broker distances.
   - `ResolveGridOrderLotSize()` calculates lots per level, accounting for percent/currency budgets and the `GRID_LOT_CALCULATED` martingale mode.

4. **Order Lifecycle**
   - `GridExecuteLevelTrade()` sends the order, registers failures via `MarketStatusRegisterBrokerFailure()`, and sets `g_debug_no_money_abort_pending` for no-money retcodes.
   - `GridOrderController` updates trailing references, instantiates deeper levels only after fills, and closes grids on final TP or trailing hits.
   - `GridCloseAllLevels()` is reused by protection filters and debug stops to ensure MT5 reports only realised positions.

5. **Protection & Telemetry**
   - `ProtectionRiskFilter` enforces drawdown guard, market close guard, and daily lock.
   - `market_status_controller` coordinates `ACTIVE / CLOSE_GUARD / BROKER_CLOSEONLY / BROKER_DISABLED` transitions and pending force closes.
   - `grid_visualization` mirrors backend state on chart objects; `Comment()` prints status summary (`Enabled/Disabled`, magic number, market status, running grid stats).

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

**Structure-aware loop safety**
```mql5
int total = ArraySize(signal_params.stoch_market_structure_data);
if(total <= 0)
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
