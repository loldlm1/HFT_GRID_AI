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

### Phase 2 – Current Deliverables
- Centralized grid inputs (`Grid_Base_Strategy_Type`, ATR/points setup, multipliers, percentages, direction) with validation and logging of the active context
- Added ATR factor indicator loading on demand and fallback handling for points-based grids
- Grid plan builder now derives level spacing and the initial anchor price from the `ATR_SL_Factor` (shift 1) so every level shares consistent point references while honoring broker freeze/stop rules
- Introduced `Grid_Final_TP_Percent` to pre-compute full-grid take-profit offsets alongside base, trailing, and next-level projections
- Directional filter now blocks disallowed trend signals while providing debug output when logging is enabled

### Phase 3 – Current Deliverables
- Grid order controller now promotes levels sequentially and fires `CTrade` market orders the moment tagged stops are reached, persisting deal-linked position tickets and activation timestamps for telemetry while seeding the next grid level only after a confirmed fill
- Resolved entry-to-anchor distances are recorded per level, scaling the remaining grid plan from the live base distance so pending stops and offsets honor real market fills instead of projected ATR ranges
- Each active level maintains its relative range percentage inside the broadened grid envelope, updating metadata (`range_high_price`, `range_low_price`, `current_range_points`) for downstream analytics and guardrail logic
- Pending buy/sell stops trail adverse price action while their next-level projections recompute from live bid/ask quotes each tick, keeping deeper grid anchors aligned until fills occur
- Active positions refresh TP, final TP, and trailing protection from live prices, enabling shared close-outs once profit targets or trailing blocks are tagged
- Dynamic lot sizing still supports fixed, percentage-based, or currency-based risk targets, all gated by spread/margin guardrails to prevent unsafe grid expansion

### Phase 4 – Current Deliverables
- On-chart grid rendering now highlights the pending stop line, projected TP, optional `TP_FINAL`, and the dynamically updated next grid level sourced directly from `SignalParams`—hiding the stop after fill and swapping TP for the trailing line when protection engages
- Dashboard summary comment highlights active grids, level states, duration, and profit factor when `Enable_Chart_Summary` is true
- Lightweight telemetry logs append lifecycle events to `query_debug.txt` when `Enable_File_Logs` is enabled for post-run analysis
- Telemetry now captures the live grid span in points alongside per-level range percentages, unlocking upcoming Fibonacci-style visual overlays and improved range diagnostics
- Grid telemetry tracks max favorable/adverse excursion, completed levels, and cumulative point statistics for future analytics modules

## Next Steps

- Mirror this roadmap in `AGENTS.md` with actionable subtasks for each service owner
- Align all new development with the MQL5 conventions and architectural rules documented for the project
- Schedule periodic reviews after each phase to evaluate readiness before proceeding
