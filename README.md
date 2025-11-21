# HFT Grid AI EA

**Version:** 1.10  
**Platform:** MetaTrader 5 (MQL5)  
**Contact:** @loldlm · https://t.me/TradingAlgoritmicoFx

---

## 1. Overview
HFT Grid AI is a tick-driven Expert Advisor that manages bullish and bearish grids per symbol. By default it keeps one active grid per direction, but the `Signal_Concurrency_Mode` input lets you opt into running multiple independent sequences concurrently. Signals combine Bollinger Percent breakouts with stochastic structure filters across two “fractal” contexts:

- **Strategy Base Context** — Executes on the main timeframe, owning directional biases, support/resistance retest rules, slope confirmation, and fresh-structure guards. `Strategy_Base_Mode` now focuses on the Bollinger window bias (`TREND_BPERCENT_WINDOW`), the mean re-entry (`TREND_BPERCENT_MEAN`), or both (`TREND_BPERCENT_WINDOW_AND_MEAN`), and each branch can optionally couple with the shared Alligator trend. The Alligator menu splits into jaws-driven modes (`TREND_ALLIGATOR_JAWS*`) — which keep the historical behaviour of checking that lips/teeth stay on the correct side of the jaws — and the new teeth branch (`TREND_ALLIGATOR_TEETH*`) that enforces `lips > teeth > jaws` (or the inverse for bearish swings). Selecting a teeth-based mode also reuses `Alligator_Lips_Period` for the Bollinger Percent indicator so the base confirmations track the lips MA while the Alligator branch keeps jaws as the structural bias. `Base_Indicator_Percent` feeds the Bollinger branch, and the slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) mirror the trend context’s >=/<= guards. Structure filters, Fibonacci retests, and `Base_Fresh_Structure_Time` gate swings by snapshotting `first_structure_time` by default or `second_structure_time` whenever `Base_Second_Structure_Filter` is active so grids only open once per structure.
- **Strategy Trend Context** — Mirrors the base controls on an optional higher timeframe. Setting `Trend_Strategy_Timeframe = PERIOD_CURRENT` disables the layer entirely. `Strategy_Trend_Mode` exposes the same window/mean menu plus the jaws/teeth Alligator pairings, so you can enforce the desired confirmation mix on the higher timeframe while reusing the shared Alligator inputs, and the grid risk controller can now reuse either the base or trend timeframe depending on how you configure `Grid_Risk_Timeframe_Source`.
- **Strategy Macro Context** — Optional swing timeframe (e.g., H1/H4) with its own `Strategy_Macro_Mode`, slope toggles, channel MA filter, and structure guards. Use it to require higher-timeframe confirmation without sacrificing the faster base/trend views.
- **Strategy Session Context** — Optional intraday lens (e.g., M15/M30) using the same indicator/structure menu so you can gate signals around session-specific orderflow and disable/re-enable it by setting `Session_Strategy_Timeframe = PERIOD_CURRENT`.

Once a signal is admitted, the grid framework calculates level spacing (ATR or points), lot sizing, trailing references, and pushes orders through the unified lifecycle controller.

---

## 2. Architecture Map
| Layer | Responsibilities | Key Files |
| --- | --- | --- |
| **Entry Point** | Handles MT5 events, orchestrates services | `HFT_Grid_AI.mq5` |
| **Tools** | Shared math / money / broker helpers | `microservices/utils/*.mqh`, `microservices/core/enums.mqh` |
| **Signal Engine** | Indicator loading, signal admission, trend/state tracking | `services/trading_management/indicator_definitions_loader.mqh`, `services/trading_signals/market_signal_state.mqh`, `services/trading_signals/market_signal_indicators.mqh`, `services/trading_signals/market_signal_channel_guards.mqh`, `services/trading_signals/market_signal_filters.mqh`, `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/market_signal_cleanup.mqh` |
| **Grid Planning** | Base distance, lot size ladder, ATR clamps | `services/trading_signals/grid_planner.mqh` |
| **Order Lifecycle** | Execute/close logic, guardrails, telemetry | `microservices/trading_signals/grid_order_lifecycle.mqh`, `services/trading_signals/grid_order_controller.mqh` |
| **Protection & Status** | Drawdown locks, market status machine | `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/market_status_controller.mqh` |
| **Frontend** | Chart drawings and comment summary | `services/frontend/grid_visualization.mqh` |

The include cascade rooted in `HFT_Grid_AI.mq5` guarantees ordering; individual services must not re-include siblings.

---

## 3. Signal Engine Essentials
### Signal Microservices
- `market_signal_state.mqh` tracks running grids, daily budgets, concurrency guards, and exposes `CanAttemptSignal()` so other services can ask whether a direction is eligible.
- `market_signal_indicators.mqh` hydrates `SignalParams` with every timeframe-dependent indicator and feeds the trend structure dataset loader.
- `market_signal_channel_guards.mqh` owns the Alligator-vs-channel filters plus the pending-order channel floor guard shared by detection and the order controller.
- `market_signal_filters.mqh` centralizes the Bollinger/Alligator trigger math, structure retest/type filters, and the merged `EvaluateSignalTrigger()` orchestration.
- `market_signal_detection.mqh` sequences the admission workflow (load → filter → guard → grid plan) for bullish/bearish entries, while `market_signal_cleanup.mqh` removes chart objects when a grid closes.

1. **Indicator Loading**
   - `Strategy_Timeframe` defines the base timeframe for Bollinger Percent (`BB_Percent_Standard`), stochastic structure, body MA, and optional ATR.
   - `Trend_Strategy_Timeframe` spins up a dedicated Bollinger Percent + stochastic structure pair unless set to `PERIOD_CURRENT`. Invalid TFs fall back to the base TF.

2. **Base Context Inputs**
  - `Strategy_Base_Mode` selects which Bollinger confirmation (window, mean, or both) is required and whether to pair it with the shared Alligator trend. The Alligator branch now exposes jaws modes (legacy behaviour) and teeth modes; the latter enforce the `lips > teeth > jaws` stack for bullish swings, flip the inequality for bearish trades, and automatically reuse `Stoch_Structure_Period_Type` for both the Bollinger Percent indicator and the Alligator lips so the fast references stay in sync with the ATR/stochastic scaffolding. `Base_Indicator_Percent` feeds the Bollinger branch, `Alligator_Jaws_Period` (while the Alligator teeth still reuse `Base_Indicator_Period_Type`) configure the Alligator branch, and the slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) mirror the trend context’s >=/<= slope guards.
   - Set `Base_Channel_MA_Filter` to block fresh signals whenever the Alligator MA used by the base context (lips for teeth modes, teeth for jaws modes) sits inside the volatility channel (ATR/Keltner) on the strategy timeframe—helpful for filtering weak trends when price is oscillating within the channel.
   - Structure filters: `Base_First/Second_Structure_Filter`, `Base_Support_Filter`, `Base_Resistance_Filter`, `Base_Min_Extern_Structures_Broken`.
   - `Base_Fresh_Structure_Time` (and `Trend_Fresh_Structure_Time`) now lock the grid to the structure timestamp that matches the active filter: by default they use `first_structure_time`, but when the second structure filter is enabled they switch to `second_structure_time` so no new grid starts until that snapshot advances for the same direction.

3. **Trend / Macro / Session Context Inputs**
   - `Strategy_Trend_Mode` mirrors the base menu (window, mean, or both) and the jaws/teeth Alligator options so every selected filter must agree before admitting a grid. Teeth selections also provide the `lips > teeth > jaws` guard, letting the trend context validate the teeth branch while the base context can confirm using lips-based Bollinger data.
   - `Trend_Channel_MA_Filter` performs the same Alligator-vs-channel exclusion on the trend timeframe, so SAR/trend confirmations wait for the trend MA to leave the volatility envelope before allowing a new signal.
  - `Trend_Indicator_Percent`, slope toggles for each indicator (`Trend_BPercent_Slope_Filter`, `Trend_Stochastic_Slope_Filter`, `Trend_Alligator_Slope_Filter`), mirrored structure/fresh controls, plus `Trend_Alligator_Jaws_Period` with lips tied to `Stoch_Structure_Period_Type` (teeth still reuse `Base_Indicator_Period_Type`) configure the active trend filter.
   - `Strategy_Macro_Mode`/`Strategy_Session_Mode` reuse the same indicator menus and slope toggles while adding their own `Macro_*` and `Session_*` structure filters, fresh timers, and channel MA guards. Setting either timeframe to `PERIOD_CURRENT` fully disables that layer; otherwise, the EA loads dedicated Bollinger, Alligator, stochastic, and market-structure handles for the context so every signal must clear all enabled layers (base + trend + macro + session) before execution.

4. **Admission Flow**
   1. `CanAttemptSignal()` checks protection risk, market status, indicator availability for every enabled context (trend/macro/session), fresh-structure state (equity <= 0 or insufficient funds -> force-close + `TesterStop()` when `Debug_Stop_On_Negative_Equity` is true), signal concurrency (`SINGLE_RUNNING_SIGNAL` blocks new ones per direction, `MULTIPLE_RUNNING_SIGNALS` lifts the cap), and optional daily signal budgets (either cap total attempts or halt only after `Daily_Signal_Limit` losses).
   2. `LoadTrendStructureData()` seeds trend snapshots when required.
   3. `EvaluateSignalTrigger()` enforces breakout, slope, structure filters (base + trend), and captures the structure timestamps that gate future trades.
   4. Approved signals call `BuildGridOrderForSignal()`, seeding level 0 and pushing telemetry.

---

## 4. Grid Framework & Lot Sizing
- **Distance Modes**
  - `ATR_RANGE` and `KELTNER_RANGE` both pull their spacing from a volatility channel (`ATR_SL_Factor` or `Keltner_Channel`, respectively). `Grid_Channel_Factor` feeds the multiplier used by either indicator. When a grid already has levels, the freshly computed base distance is clamped so it never falls below the last realised spacing—preventing ultra-tight ladders if volatility contracts mid-cycle.
  - `POINTS_RANGE` uses `Grid_Points_Range_Setup` as fixed points.
  - Channel strategies (ATR or Keltner) always read the smoothed support/resistance lines (ATR SMA bands or Keltner upper/lower). `Grid_Points_Range_Setup` doubles as a hard floor against those references: if the pending stop sits closer to the channel than the configured points, the signal is blocked (or the pending stop is cancelled while still pending). Once level 0 fills the guard is skipped, but the original channel-derived distance is cached for deeper levels.
  - `Grid_Exponential_Multiplier` multiplies each level’s distance, while `Grid_Positions_Stops_Percent` defines the initial stop/entry offset.
  - `Grid_Points_TP` (optional) overrides `Grid_TP_Percent` with a fixed point span for every level’s take-profit distance, mirroring how `Grid_Points_Range_Setup` behaves in `POINTS_RANGE`.
- **Trailing Modes**
  - `Grid_Trailing_Strategy_Mode` picks the trailing source: default price-offset, the volatility channel (ATR SMA or Keltner upper/lower), or Alligator lips MA (shift=1). `Grid_Trailing_TP_Percent` still defines the offset but, in indicator modes, it is added on top of the channel/Lips value and clamped with `MathMax/MathMin` so the trailing line never moves backwards relative to the indicator. `Grid_Trailing_Timeframe` lets you pick a dedicated timeframe for the trailing indicator (default `PERIOD_CURRENT`, which maps to `Strategy_Timeframe`).
  - `Grid_Trailing_Execution_Mode` controls when trailing activates. `TRAILING_EXECUTION_DEFAULT` mirrors the legacy behaviour (trigger on `Grid_TP_Percent`). `TRAILING_EXECUTION_AGGRESIVE` simply waits until the selected indicator clears the TP reference before enabling trailing, so every grid follows the same gating regardless of `Grid_Level_Stop_Limit` caps.
- **Break-Even Modes**
  - `Grid_BreakEven_Mode` governs automated BE handling. `BE_DISABLE` leaves stops untouched, `BE_ENABLE` arms break-even once price reaches a level’s `Grid_TP_Percent` target and propagates the new break-even anchor across all shallower/positive levels. `BE_PARTIAL_ENABLE` adds profit taking: when a level hits TP the EA closes `Grid_Partial_Take_Percentage` of that position (only if the broker allows the partial size) before shifting every filled level’s break-even to that anchor. Each level donates a single partial, and the anchor walks forward level-by-level while trailing logic still races to close everything if it’s hit first.

- **Lot Modes**
  - `GRID_LOT_SIZE`, `GRID_LOT_PERCENTAGE_BASED`, `GRID_LOT_EQUITY_PERCENT_BASED`, `GRID_LOT_CURRENCY_BASED`, `GRID_LOT_CALCULATED`.
  - Percentage/equity/currency modes convert the selected account metric (balance, equity, or explicit currency) into lots using the live entry→TP span.
  - `GRID_LOT_CALCULATED` sums drawdown of previously filled levels, multiplies by `Grid_Lot_Multiplier`, and back-solves lots so the next TP can recover the accumulated loss.
  - `GRID_LOT_MAX_MARGIN_SPLIT` aggressively allocates available margin: it computes the maximum lot size the current free margin can sustain, then splits that exposure across `Grid_Lot_Strategy_Size` segments (rounded to at least 1). Each new level recomputes the per-split lot just before sending, so it always pushes the largest order the account can afford without triggering margin guardrails.
- **Trend Risk Guard**
- `Grid_Risk_Trend_Mode` compares the most recent grid level entry price against the Alligator reference you pick via `Grid_Risk_Alligator_Reference` (jaws or teeth) and on the timeframe selected through `Grid_Risk_Timeframe_Source` (strategy/trend/macro/session). `GRID_RM_TREND_OFF` disables it, `GRID_RM_TREND_BE` closes the sequence (only when aggregate floating P/L is ≥ 0) once the latest filled level sits on the wrong side of the reference line, `GRID_RM_TREND_SL` treats that line as a hard stop, and `GRID_RM_TREND_SAR` flips the grid into the opposite direction (using the latest level’s lot size) whenever the breach occurs so the sequence “s.ar”s between bullish and bearish states until price trends back.

- **Telemetry & Visualization**
  - `GridLogEvent()` entries label each lifecycle change (`LOT_RESOLVED`, `NEXT_UPDATE`, etc.).
  - Chart overlays show ENTRY/TP/FINAL/NEXT lines; levels trail adverse-only, mirroring backend state.

---

## 5. Order Lifecycle & Protection
1. **Execution**
   - `GridGuardrailsAllowOrder()` blocks sends when spread or margin limits fail.
   - `GridExecuteLevelTrade()` handles `CTrade` sends; insufficient-funds retcodes flag a debug abort when `Debug_Stop_On_Negative_Equity` is enabled.

2. **Lifecycle States**
   - `GRID_ORDER_STOP_TRAILING_ACTIVE` → `GRID_ORDER_ACTIVE` → `GRID_ORDER_TP_TRAILING_ACTIVE` → `GRID_ORDER_COMPLETED`.
   - `GridOrderController` trails NEXT/TP lines, instantiates deeper levels sequentially, and can close the entire grid when final TP or trailing conditions hit.

3. **Protection Risk Filter**
   - Modes: `ENABLED_OFF`, `ENABLED_GRID_PROTECTION`, `ENABLED_GRID_PROTECTION_DAILY`.
   - Drawdown definitions: account size %, balance %, or fixed currency.
   - On breach, all grids are force-closed, chart objects removed, and any stray positions with the EA magic are liquidated.
   - Market status machine (`services/trading_signals/market_status_controller.mqh`) tracks `ACTIVE`, `CLOSE_GUARD`, `BROKER_CLOSEONLY`, `BROKER_DISABLED`, coordinating forced closures and broker outages.

4. **Debug Helpers**
   - `Enable_Trend_Filter_Sanity_Stop`: Stops tester if trend inputs are disabled during optimizations.
   - `Debug_Stop_On_Negative_Euity`: Stops tester (after force-closing) when equity ≤ 0 or the broker rejects an order with “no money”.
   - File logging via `query_debug.txt` and on-chart comments provide additional diagnostics.

---

## 6. Input Reference (abridged)
| Group | Highlights |
| --- | --- |
| **Account / Protection** | `Custom_Magic`, `Max_Spread`, `Protection_Risk_Mode`, drawdown inputs, `Market_Close_Guard_Timeframe`. |
| **Strategy Context** | `Strategy_Timeframe`, `Trend_Strategy_Timeframe`, indicator period/MA, `Strategy_Direction_Mode`. |
| **Strategy Base Context** | Percent, slope, structure filters, retest selectors, fresh-structure toggle. |
| **Strategy Trend Context** | Mirrors base context plus trend mode toggles. |
| **Grid Strategy** | `Grid_Base_Strategy_Type`, `Grid_Points_Range_Setup`, `Grid_Channel_Factor`, exponential multiplier, TP/stop percentages, volatility clamp is automatic. |
| **Trailing Strategy** | `Grid_TP_Percent`, `Grid_Trailing_TP_Percent`, `Grid_Trailing_Strategy_Mode` (price, ATR rail, Lips MA), `Grid_Trailing_Timeframe`, `Grid_Trailing_Execution_Mode` (price-triggered vs indicator-gated aggressive that watches the TP reference), `Grid_BreakEven_Mode`, and `Grid_Partial_Take_Percentage` (for partial BE). ATR/MA trailing remains available even when `Grid_Base_Strategy_Type = POINTS_RANGE` thanks to dedicated indicator loads. |
| **Grid Risk** | `Grid_Lot_Type`, `Grid_Lot_Strategy_Size`, `Grid_Lot_Multiplier` (martingale/ladder), `Grid_Level_Stop_Limit` (max depth before force-close), `Daily_Signal_Limit` + mode (caps total or losing grids per day), `Grid_Risk_Trend_Mode` (off / BE / SL / SAR), `Grid_Risk_Alligator_Reference` (pick jaws or teeth for the comparison), and `Grid_Risk_Timeframe_Source` (choose base, trend, macro, or session timeframe for the protective line). `GRID_LOT_EQUITY_PERCENT_BASED` mirrors the percentage mode but uses live equity. |
| **Developer Debug** | Logging toggles, chart options, `Enable_Trend_Filter_Sanity_Stop`, `Debug_Stop_On_Negative_Euity`. |

Refer to `services/trading_management/ea_inputs.mqh` for defaults and descriptions.

---

## 7. Developer Notes & Conventions
- **Code Style**: 2-space indentation, snake_case vars, CamelCase functions, ALL_CAPS enums/constants. Avoid C++11 features (no `auto`, lambdas, range-for, etc.).
- **Error Handling**: Always check indicator handles and trade routines; call `TesterStop()` for critical tester-only failures.
- **Data Safety**: Validate array sizes before access, clamp broker distances via `EnforceBrokerDistance()`, and normalize lot sizes with `NormalizeVolumeForSymbol()`.
- **Testing**:
  - Use MT5 Strategy Tester (visual + log review). Enable `Enable_Logs`/`Enable_File_Logs` for deeper traces.
  - Use `Debug_Stop_On_Negative_Euity` during optimization campaigns to skip doomed parameter sets early.
  - `ProtectionRiskModes` + `MarketStatus` watchers should always remain active during tests to ensure consistent cleanup.

---

## 8. Getting Started
1. Configure inputs in MT5 (or via `.set` file) with consistent base/trend contexts.
2. Compile `HFT_Grid_AI.mq5` (ensuring the include directory structure is preserved).
3. Run Strategy Tester with “Every tick based on real ticks” for best fidelity; monitor `query_debug.txt` and on-chart comments for live diagnostics.
4. For production deployment, disable debug stops/logs and confirm broker constraints via `broker_constraints_helper`.

The codebase intentionally favors explicit, modular services so agents and contributors can reason about each layer independently while maintaining strict include order and dependency rules.
