# HFT Grid AI EA

**Version:** 1.10  
**Platform:** MetaTrader 5 (MQL5)  
**Contact:** @loldlm · https://t.me/TradingAlgoritmicoFx

---

## 1. Overview
HFT Grid AI is a tick-driven Expert Advisor that manages bullish and bearish grids per symbol. By default it keeps one active grid per direction, but the `Signal_Concurrency_Mode` input lets you opt into running multiple independent sequences concurrently. Signals combine channel-percent breakouts with stochastic structure filters across two “fractal” contexts:

- **Strategy Base Context** — Executes on the main timeframe, owning directional biases, support/resistance retest rules, slope confirmation, and fresh-structure guards. `Strategy_Base_Entry_Evaluation` selects the confirmation style (Bollinger/Keltner window, mean, both, or `ENTRY_EVAL_ON_TREND` to trade pure trend), while `Strategy_Base_Trend_Mode` picks the Alligator branch (`TREND_OFF`, `TREND_ALLIGATOR_JAWS`, or `TREND_ALLIGATOR_TEETH`). Global inputs (`Strategy_Channel_Indicator_Type`, `Strategy_Global_Entry_Mode`, `Strategy_Global_Entry_Evaluation_Mode`) decide whether every context hydrates Bollinger Percent or Keltner Percent data, whether entries key off breakouts / MA trends / reversion, and optionally override each context’s evaluation mode so sweeps stay consistent. The shared slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) and structure filters behave exactly as before, but each context now evaluates those rules on its own schedule so a base signal does not depend on another layer’s entry settings.
- **Strategy Trend Context** — Mirrors the base controls on an optional higher timeframe. Setting `Trend_Strategy_Timeframe = PERIOD_CURRENT` disables the layer entirely. `Strategy_Trend_Entry_Evaluation` and `Strategy_Trend_Trend_Mode` let you enforce any channel-percent/Alligator pairing on that timeframe, and their outputs now act as both a standalone signal source and the gating state that downstream contexts must respect before opening their own grids. The grid risk controller still reuses this timeframe when `Grid_Risk_Timeframe_Source = GRID_RISK_TF_TREND`.
- **Strategy Macro Context** — Optional swing timeframe (e.g., H1/H4) with its own entry/trend inputs (`Strategy_Macro_Entry_Evaluation`, `Strategy_Macro_Trend_Mode`), slope toggles, channel MA filter, and structure guards. Macro confirmations can now spawn their own grids while simultaneously acting as the cascade prerequisite for the quicker trend/base layers.
- **Strategy Session Context** — Optional intraday lens (e.g., M15/M30) using the same indicator/structure menu so you can gate signals around session-specific orderflow. `Strategy_Session_Entry_Evaluation` and `Strategy_Session_Trend_Mode` behave the same as the other contexts, and disabling the timeframe (`Session_Strategy_Timeframe = PERIOD_CURRENT`) removes the layer from the cascade entirely.

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
- `market_signal_filters.mqh` centralizes the Bollinger/Alligator trigger math plus the context-agnostic helpers (`StrategyContextEvaluateTrend`, `StrategyContextEvaluateEntry`, structure retests, fresh-structure guards) used by detection and the protection modules.
- `market_signal_detection.mqh` sequences the admission workflow (load → filter → guard → grid plan) for bullish/bearish entries, while `market_signal_cleanup.mqh` removes chart objects when a grid closes.

Every context evaluates its own indicator snapshot only when a new bar arrives on that timeframe. Session → macro → trend → base ordering creates a cascade: a macro grid can fire immediately when its entry/trend rules agree, while the trend and base layers must wait for the macro trend state (and, if enabled, the session state) to stay green before their entries can trigger. This per-context scheduling lets multiple grids coexist per direction when `Signal_Concurrency_Mode = MULTIPLE_RUNNING_SIGNALS`, but keeps the default single-grid guardrails intact.

1. **Indicator Loading**
   - `Strategy_Timeframe` defines the base timeframe for the channel-percent indicator (Bollinger or Keltner depending on `Strategy_Channel_Indicator_Type`), stochastic structure, body MA, and optional ATR.
   - `Trend_Strategy_Timeframe` spins up a dedicated channel-percent + stochastic structure pair unless set to `PERIOD_CURRENT`. Invalid TFs fall back to the base TF.

2. **Base Context Inputs**
  - `Strategy_Base_Entry_Evaluation` selects which channel-percent confirmation (window, mean, both) or whether to delegate entries to the Alligator trend only (`ENTRY_EVAL_ON_TREND`). `Strategy_Base_Trend_Mode` still toggles the Alligator branch (`TREND_OFF`, jaws, or teeth), enforcing `lips > teeth > jaws` on bullish swings (and the inverse for bearish trades) while reusing `Stoch_Structure_Period_Type` so the fast references stay aligned with ATR/stochastic inputs. `Strategy_Channel_Indicator_Type`, `Strategy_Global_Entry_Mode` (breakout / MA-trend / reversion presets), and the optional `Strategy_Global_Entry_Evaluation_Mode` override apply to every context so you can sweep behaviours without editing four separate input sets. The slope toggles (`Base_BPercent_Slope_Filter`, `Base_Stochastic_Slope_Filter`, `Base_Alligator_Slope_Filter`) mirror the trend context’s >=/<= slope guards.
   - Set `Base_Channel_MA_Filter` to block fresh signals whenever the Alligator MA used by the base context (lips for teeth modes, teeth for jaws modes) sits inside the volatility channel (ATR/Keltner) on the strategy timeframe—helpful for filtering weak trends when price is oscillating within the channel.
   - Structure filters: `Base_First/Second_Structure_Filter`, `Base_Support_Filter`, `Base_Resistance_Filter`, `Base_Min_Extern_Structures_Broken`. These filters (and the fresh-structure toggles) only control whether the context can open its own grid—they do not block downstream contexts in the cascade.
   - `Base_Fresh_Structure_Time` (and `Trend_Fresh_Structure_Time`) lock the grid to the structure timestamp that matches the active filter: by default they use `first_structure_time`, but when the second structure filter is enabled they switch to `second_structure_time` so no new grid starts until that snapshot advances for the same direction.

3. **Trend / Macro / Session Context Inputs**
   - `Strategy_Trend_Entry_Evaluation` / `Strategy_Trend_Trend_Mode` mirror the base menu and enforce their confirmations independently on the selected timeframe. Use `ENTRY_EVAL_ON_TREND` when you want a context to spawn signals solely when its Alligator trend is active; `ENTRY_EVAL_OFF` keeps the context in the cascade without authorising its own trades. Trend, macro, and session contexts now produce their own signals while simultaneously feeding the cascade gate that lower contexts must satisfy before triggering.
   - `Trend_Channel_MA_Filter` performs the same Alligator-vs-channel exclusion on the trend timeframe, so SAR/trend confirmations wait for the trend MA to leave the volatility envelope before allowing a new signal.
  - Context-specific slope toggles (`Trend_BPercent_Slope_Filter`, `Trend_Stochastic_Slope_Filter`, `Trend_Alligator_Slope_Filter`), mirrored structure/fresh controls, plus `Trend_Alligator_Jaws_Period` with lips tied to `Stoch_Structure_Period_Type` (teeth still reuse `Base_Indicator_Period_Type`) configure the active trend filter.
  - `Strategy_Macro_Entry_Evaluation` / `Strategy_Macro_Trend_Mode` and `Strategy_Session_Entry_Evaluation` / `Strategy_Session_Trend_Mode` reuse the same indicator menus and slope toggles while adding their own `Macro_*` and `Session_*` structure filters, fresh timers, and channel MA guards. Setting the timeframe to `PERIOD_CURRENT` fully disables that layer; otherwise, each context is evaluated on its own bar schedule (`iTime(_Symbol, context_tf, 0)`) so base signals (for example) can coexist with slower trend/macro grids when the cascade permits it.

4. **Admission Flow**
   1. `DetectStrategySignals()` walks the contexts from session → macro → trend → base, only re-evaluating a layer when its own `iTime(_Symbol, context_tf, 0)` advances. Each evaluation captures a `StrategyContextIndicators` snapshot (only loading Bollinger/Alligator/Stochastic data when the entry mode, slopes, or channel filters need them).
   2. `StrategyContextEvaluateTrend()` updates the trend state for the active context, while `StrategyCascadeAllowsSignal()` ensures lower timeframes only fire when every upstream context with an enabled trend mode is currently green.
   3. `StrategyContextEvaluateEntry()` runs the Bollinger confirmation (when enabled), slope filters, structure retests, and the fresh-structure timestamp guard so each context can throttle signals independently. `StrategyContextChannelMaFilterAllowsSignal()` enforces the optional Alligator-vs-channel block using the same context metadata.
   4. When the cascade, entry, channel guard, and `CanAttemptSignal()` (protection/daily/concurrency) all agree, `BuildGridOrderForSignal()` seeds a new grid using the context’s timeframe for ATR/Keltner spacing. `ChannelGuardAllowsPendingSignal()` still clamps pending stops against the channel floor before registering the signal.

---

## 4. Grid Framework & Lot Sizing
- **Distance Modes**
  - `ATR_RANGE` and `KELTNER_RANGE` both pull their spacing from a volatility channel (`ATR_SL_Factor` or `Keltner_Channel`, respectively). `Grid_Channel_Factor` feeds the multiplier used by either indicator. When `Strategy_Global_Entry_Mode` is set to breakout or reversion, the base distance is measured from price back to the channel midline (MA) because signals occur at the extremes; `ENTRY_MODE_MA_TREND` keeps using the support/resistance rails. Once a grid already has levels, the freshly computed base distance is clamped so it never falls below the last realised spacing—preventing ultra-tight ladders if volatility contracts mid-cycle.
  - `POINTS_RANGE` uses `Grid_Points_Range_Setup` as fixed points.
  - Channel strategies (ATR or Keltner) still feed the pending-order guard from the smoothed support/resistance lines (ATR SMA bands or Keltner upper/lower). `Grid_Points_Range_Setup` doubles as a hard floor against those references: if the pending stop sits closer to the channel than the configured points, the signal is blocked (or the pending stop is cancelled while still pending). Once level 0 fills the guard is skipped, but the original channel-derived distance is cached for deeper levels.
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

5. **Session Time Filter**
   - Three configurable windows (Asia/London/NewYork) let you constrain new grids to HH:MM-HH:MM ranges. `SESSION_FILTER_ALLOW_RUN` blocks fresh entries outside the chosen windows but lets existing grids finish, while `SESSION_FILTER_FORCE_CLOSE` also schedules a force close the moment its session ends. Leave every mode `SESSION_FILTER_OFF` to trade around the clock.

---

## 6. Input Reference (abridged)
| Group | Highlights |
| --- | --- |
| **Account / Protection** | `Custom_Magic`, `Max_Spread`, `Protection_Risk_Mode`, drawdown inputs, `Market_Close_Guard_Timeframe`. |
| **Session Time Filters** | `Session_*_Filter_Mode` (OFF / allow-run / force-close) and `Session_*_Filter_Time_Range` (HH:MM-HH:MM strings for Asia, London, NewYork). When any session is enabled, new grids only spawn inside at least one active window; FORCE_CLOSE also liquidates every running grid the moment its session closes. Leave all modes OFF to keep the EA running 24/7. |
| **Strategy Context** | `Strategy_Timeframe`, `Trend/Macro/Session_Strategy_Timeframe`, `Strategy_*_Entry_Evaluation`, `Strategy_*_Trend_Mode`, `Strategy_Channel_Indicator_Type`, `Strategy_Global_Entry_Mode`, `Strategy_Global_Entry_Evaluation_Mode`, indicator period/MA, `Strategy_Direction_Mode`. |
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
