# HFT Grid AI EA

**Version:** 1.10
**Platform:** MetaTrader 5 (MQL5)
**Copyright:** Traders Capital Team
**Contact:** @loldlm | https://t.me/TradingAlgoritmicoFx

---

## Overview

The **HFT Grid AI EA** is a specialized Expert Advisor designed to execute high frequency positions with a robust grid and risk managment logic. The EA operates tick-by-tick, capturing multi-timeframe indicator data for pattern analysis.

## Development Roadmap

### Phase 0 – Foundation Setup
- Audit current services, enums, and input declarations to confirm compatibility with new grid workflow
- Stabilize logging toggles, default inputs, and indicator handles required for the new strategy
- Document broker freeze/stop constraints for each supported symbol and store them in a reusable helper
- Define visual style guidelines for on-chart elements and confirm shared color constants

### Phase 1 – Signal Engine Upgrade
- Introduce single-timeframe signal inputs (period, MA method, strategy enums) and enforce validation
- Refactor signal detection to trigger on indicator conditions rather than scheduled time slices
- Combine BB Percent and Stochastic Extrema signals according to selected strategy mix
- Gate simultaneous grids so only one long and one short structure can exist at any time

### Phase 2 – Grid Framework
- Build grid configuration model covering ATR and fixed-point spacing, multipliers, and exponential scaling
- Generate stop-limit scaffolding for initial orders using Grid_Initial_Stops_Percent rules
- Validate grid spacing against broker freeze/stop levels before placing or adjusting any order
- Persist grid metadata in memory structures to simplify recovery and chart rendering

### Phase 3 – Order Lifecycle Control
- Implement buy/sell stop orchestration that follows price when adverse movement continues
- Manage TP calculation, activation, and trailing using Grid_TP_Percent and Grid_Trailing_TP_Percent inputs
- Apply Grid_Positions_Stops_Percent rules to deeper grid layers with exponential spacing support
- Introduce safeguards to pause expansion when margin, slippage, or spread constraints fail

### Phase 4 – Visualization & Telemetry
- Draw signal, grid, stop, and trailing lines with profit-sensitive coloring for quick diagnosis
- Add concise on-chart summaries and optional verbose logging controlled by inputs
- Provide file-based debug tracing for Strategy Tester reviews without overwhelming the log
- Capture per-grid statistics (win rate, average excursion, time-in-trade) for future analytics

### Phase 5 – Persistence & Resilience
- Serialize active grid state so reconnects or timeframe changes rehydrate the EA seamlessly
- Reconcile live orders and pending stops with in-memory state during `OnInit()` reloads
- Validate indicator buffers after reconnection and resync chart objects to avoid drift
- Harden error handling to degrade gracefully when indicators or trading functions fail

### Phase 6 – Optimization & Release Prep
- Profile tick execution time and memory churn; optimize hot paths and array usage
- Run Strategy Tester campaigns across representative symbols and volatility regimes
- Calibrate default inputs and document scenario-based presets for end users
- Finalize documentation, changelog, and deployment checklist for release candidates

### Phase 0 – Current Deliverables
- Centralized all EA inputs (license, account, strategy, debug) in `services/trading_management/ea_inputs.mqh`
- Broker constraint helper `microservices/utils/broker_constraints_helper.mqh` populates `g_symbol_constraints` during `OnInit()`
- Indicator loaders now respect the single `Strategy_Timeframe` input while remaining scalable for future expansions
- Chart styling consolidated through `ApplyDefaultChartStyle()` in `services/frontend/chart_style_guide.mqh` for consistent visuals

### Phase 1 – Current Deliverables
- Added selectable indicator enums (`Base_Indicator_Period_Type`, `Base_Indicator_MA_Method`, `Base_Indicator_Strategy_Type`, `Solid_Indicator_Strategy_Type`) exposed via `ea_inputs.mqh`
- Refined indicator loading to honor the chosen Bollinger period/MA while keeping a single-strategy timeframe
- Introduced `Solid_Indicator_Period_Type` and `Strategy_Direction_Mode` inputs to configure stochastic structure depth and directional bias
- Signal engine now evaluates Bollinger Percent crossings (50/100 levels) and stochastic extrema combinations per configured strategies
- `CanAttemptSignal()` guard ensures only one active grid per direction and validates indicator availability before triggers fire
- Detection functions require `EvaluateSignalTrigger()` approval, enabling MA-only, bands-only, or combined extrema logic without time-based scheduling

## Input Reference

### Strategy Context
- `Strategy_Timeframe`: Single timeframe used to load and read all indicators (scalable later).
- `Base_Indicator_Period_Type`: Period for Bollinger indicators (`BB_Percent_Standard`, `BB_Standard`). Options: 5, 8, 13, 21, 34, 55.
- `Base_Indicator_MA_Method`: MA method applied inside Bollinger (default `MODE_EMA`). Applied price is fixed to `PRICE_WEIGHTED`.
- `Base_Indicator_Strategy_Type`: Base trigger source.
  - `MA_TYPE`: Crosses around 50% of BB Percent (e.g., buy if `bb_percent_2 > 50` and `bb_percent_1 <= 50`).
  - `BANDS_TYPE`: Crosses of 0%/100% band edges (e.g., buy if `bb_percent_2 > 100` and `bb_percent_1 <= 100`).
  - `BB_NONE_TYPE`: Disable base trigger.
- `Solid_Indicator_Strategy_Type`: Stochastic structure trigger.
  - `EXTREMA_TYPE`: Buy at current bottom, sell at current peak using `Stochastic_Structure`.
  - `SOLID_NONE_TYPE`: Disable solid trigger.
- `Solid_Indicator_Period_Type`: Period for `Stochastic_Structure` (5, 8, 13, 21, 34, 55).
- `Strategy_Direction_Mode`: Directional filter; `BOTH_DIRECTION`, `BULLISH_DIRECTION`, or `BEARISH_DIRECTION`.

### Grid Strategy Settings
- `Grid_Base_Strategy_Type`: Chooses base spacing mode.
  - `ATR_RANGE`: Uses `ATR_SL_Factor` anchors (shift 1 for L0, shift 0 for deeper levels) to derive distances in points. `Grid_ATR_Points_Setup` configures the indicator factor but no longer scales distances post-fetch.
  - `POINTS_RANGE`: Uses `Grid_ATR_Points_Setup` as fixed points distance.
- `Grid_ATR_Points_Setup`: ATR factor (ATR mode) or absolute points (Points mode).
- `Grid_Multiplier`: Lot scaling per level (default 2.0).
- `Grid_Exponential_Multiplier`: Expands level spacing smoothly (default 1.1). Distance L(n) = base_distance × multiplier^n.
- `Grid_Initial_Stops_Percent`: Legacy preset input; behaviour now aliases to `Grid_Positions_Stops_Percent`.
- `Grid_Positions_Stops_Percent`: Percent of the entry→baseline gap applied to protective offsets for every level.
- `Grid_TP_Percent`: Percent of the entry→next snapshot captured on fill; defines the primary take-profit span.
- `Grid_TP_Reference_Mode`: Legacy toggle (ignored); TP always references the entry→next snapshot distance.
- `Grid_Trailing_TP_Percent`: Portion of the TP span converted to realised profit before trailing — trailing offset = `(1 - percent/100)` × TP reference.

Notes
- All distances are clamped to broker freeze/stops via `SymbolTradingConstraints` and helper functions.
- ATR handles are only loaded when `ATR_RANGE` is selected; otherwise the EA skips ATR loading to reduce overhead.
- Chart overlays render a single STOP/ENTRY/TP/TP_FINAL/NEXT stack per signal; the NEXT line mirrors the trailing backend `next_level_price` derived from `entry_reference_price` (no hysteresis), and `Enable_Chart_Levels_Depth` is ignored in this mode.

## Next Steps

- Finalize the Grid Framework refactor:
  * Validate the ATR_SL_Factor buffers and document which outputs map to bullish/bearish anchors
  * Rebuild `GridOrderState` geometry using the new baseline/offset fields and enforce broker constraints consistently
  * Per-level spacing uses `Grid_Exponential_Multiplier`, and per-level lot sizing uses `Grid_Multiplier`
  * NEXT trails adverse-only from `entry_reference_price` for all pending levels; TP and Final TP are computed from `entry_reference_price` with per-level spans and move favorable-only pre-fill
  * Promote broker-side pending orders (Phase 3 dependency) once the Phase 2 geometry is confirmed in Strategy Tester logs
- Mirror this roadmap in `AGENTS.md` with actionable subtasks for each service owner
- Align all new development with the MQL5 conventions and architectural rules documented for the project
- Schedule periodic reviews after each phase to evaluate readiness before proceeding
