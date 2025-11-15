# HFT Grid AI EA

**Version:** 1.10  
**Platform:** MetaTrader 5 (MQL5)  
**Contact:** @loldlm · https://t.me/TradingAlgoritmicoFx

---

## 1. Overview
HFT Grid AI is a tick-driven Expert Advisor that manages a single bullish and bearish grid per symbol. Signals combine Bollinger Percent breakouts with stochastic structure filters across two “fractal” contexts:

- **Strategy Base Context** — Executes on the main timeframe, owning directional biases, support/resistance retest rules, slope confirmation, and fresh-structure guards.
- **Strategy Trend Context** — Mirrors the base controls on an optional higher timeframe. Setting `Trend_Strategy_Timeframe = PERIOD_CURRENT` disables the layer entirely.

Once a signal is admitted, the grid framework calculates level spacing (ATR or points), lot sizing, trailing references, and pushes orders through the unified lifecycle controller.

---

## 2. Architecture Map
| Layer | Responsibilities | Key Files |
| --- | --- | --- |
| **Entry Point** | Handles MT5 events, orchestrates services | `HFT_Grid_AI.mq5` |
| **Tools** | Shared math / money / broker helpers | `microservices/utils/*.mqh`, `microservices/core/enums.mqh` |
| **Signal Engine** | Indicator loading, signal admission, trend/state tracking | `services/trading_management/indicator_definitions_loader.mqh`, `services/trading_signals/market_signal_detector.mqh` |
| **Grid Planning** | Base distance, lot size ladder, ATR clamps | `services/trading_signals/grid_planner.mqh` |
| **Order Lifecycle** | Execute/close logic, guardrails, telemetry | `microservices/trading_signals/grid_order_lifecycle.mqh`, `services/trading_signals/grid_order_controller.mqh` |
| **Protection & Status** | Drawdown locks, market status machine | `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/market_status_controller.mqh` |
| **Frontend** | Chart drawings and comment summary | `services/frontend/grid_visualization.mqh` |

The include cascade rooted in `HFT_Grid_AI.mq5` guarantees ordering; individual services must not re-include siblings.

---

## 3. Signal Engine Essentials
1. **Indicator Loading**
   - `Strategy_Timeframe` defines the base timeframe for Bollinger Percent (`BB_Percent_Standard`), stochastic structure, body MA, and optional ATR.
   - `Trend_Strategy_Timeframe` spins up a dedicated Bollinger Percent + stochastic structure pair unless set to `PERIOD_CURRENT`. Invalid TFs fall back to the base TF.

2. **Base Context Inputs**
   - `Strategy_Base_Mode` selects whether the engine checks Bollinger Percent, Alligator, or `TREND_BOTH` (requires both). `Base_Indicator_Percent` + `Base_Slope_Filter` still govern the Bollinger branch, while `Base_Alligator_Jaws_Period`/`Base_Alligator_Lips_Period` (teeth reuse `Base_Indicator_Period_Type`) configure the Alligator branch.
   - Structure filters: `Base_First/Second_Structure_Filter`, `Base_Support_Filter`, `Base_Resistance_Filter`, `Base_Min_Extern_Structures_Broken`.
   - `Base_Fresh_Structure_Time` forces a newer structure timestamp before another grid may open in the same direction.

3. **Trend Context Inputs**
   - `Strategy_Trend_Mode` now supports `TREND_BPERCENT`, `TREND_ALLIGATOR`, or `TREND_BOTH` (requires both filters to agree before admitting a grid).
   - `Trend_Indicator_Percent`, slope toggles for each indicator (`Trend_BPercent_Slope_Filter`, `Trend_Stochastic_Slope_Filter`, `Trend_Alligator_Slope_Filter`), mirrored structure/fresh controls, plus `Trend_Alligator_Jaws_Period`/`Trend_Alligator_Lips_Period` (teeth reuse `Base_Indicator_Period_Type`) configure the active trend filter.

4. **Admission Flow**
   1. `CanAttemptSignal()` checks protection risk, market status, indicator availability, fresh-structure state (equity <= 0 or insufficient funds -> force-close + `TesterStop()` when `Debug_Stop_On_Negative_Equity` is true), and optional daily signal budgets (either cap total attempts or halt only after `Daily_Signal_Limit` losses).
   2. `LoadTrendStructureData()` seeds trend snapshots when required.
   3. `EvaluateSignalTrigger()` enforces breakout, slope, structure filters (base + trend), and captures the structure timestamps that gate future trades.
   4. Approved signals call `BuildGridOrderForSignal()`, seeding level 0 and pushing telemetry.

---

## 4. Grid Framework & Lot Sizing
- **Distance Modes**
  - `ATR_RANGE`: Pulls ATR-based anchor points. When a grid already has levels, the freshly computed base distance is clamped so it never falls below the last realised spacing—preventing ultra-tight ladders if ATR contracts mid-cycle.
  - `POINTS_RANGE`: Uses `Grid_ATR_Points_Setup` as fixed points.
  - `Grid_Exponential_Multiplier` multiplies each level’s distance, while `Grid_Positions_Stops_Percent` defines the initial stop/entry offset.
  - `Grid_Points_TP` (optional) overrides `Grid_TP_Percent` with a fixed point span for every level’s take-profit distance, mirroring how `Grid_ATR_Points_Setup` behaves in `POINTS_RANGE`.

- **Lot Modes**
  - `GRID_LOT_SIZE`, `GRID_LOT_PERCENTAGE_BASED`, `GRID_LOT_CURRENCY_BASED`, `GRID_LOT_CALCULATED`.
  - Percentage/currency modes convert current balance (or input size) into lots using the live entry→TP span.
  - `GRID_LOT_CALCULATED` sums drawdown of previously filled levels, multiplies by `Grid_Lot_Multiplier`, and back-solves lots so the next TP can recover the accumulated loss.

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
| **Grid Strategy** | `Grid_Base_Strategy_Type`, ATR/point setup, exponential multiplier, TP/stop percentages, ATR clamp is automatic. |
| **Grid Risk** | `Grid_Lot_Type`, `Grid_Lot_Strategy_Size`, `Grid_Lot_Multiplier` (martingale/ladder), `Grid_Level_Stop_Limit` (max depth before force-close), `Daily_Signal_Limit` + mode (caps total or losing grids per day). |
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
