# AGENTS Instructions for HFT Grid AI EA (MQL5)

## Project Overview
This is a HFT Grid AI Expert Advisor designed to execute high frequency positions with a robust grid and risk managment logic. The EA operates tick-by-tick, capturing multi-timeframe indicator data for pattern analysis.

## Phase Plan & Deliverables

### Phase 0 – Foundation Setup
- Inventory current services, indicator wrappers, and enums; document gaps or refactors required
- Normalize logging toggles, default `input` parameters, and indicator handles for the new strategy
- Capture broker freeze/stop constraints per symbol in a shared helper within `trading_tools`
- Draft UX rules for chart objects (naming, color palette, layering) to reuse in later phases
- Exit Criteria: baseline documentation updated, helper scaffolding merged, no runtime regressions in existing signals
- Completed: centralized inputs in `services/trading_management/ea_inputs.mqh`, broker constraints helper (`microservices/utils/broker_constraints_helper.mqh`), single `Strategy_Timeframe` loading, and chart style constants in `services/frontend/chart_style_guide.mqh`

### Phase 1 – Signal Engine Upgrade
- Add mirrored strategy context inputs (global indicator periods/MAs plus fractal base & trend layers for percents, structure filters, fresh-structure toggles, and Fibonacci selectors)
- Refactor signal detection to event-driven triggers tied to indicator buffer updates; remove time-only logic
- Implement combinable BB Percent and Stochastic Extrema triggers with clear validation paths
- Enforce single active grid per direction by centralizing signal admission checks
- Exit Criteria: deterministic signal firing in Strategy Tester, logging traces confirming trigger combinations
- Completed: indicator inputs exposed via `ea_inputs.mqh`, loader honors the shared period/MA across both layers, the base/trend contexts each own Bollinger percent ladders plus structure filters, fresh-structure guards, and slope filters, `EvaluateSignalTrigger()` now merges the breakout, extrema logic, dual-layer retest requirements, fresh-structure gating, and slope confirmation, and `CanAttemptSignal()` restricts grids to one per direction while validating all required indicator handles

### Phase 2 – Grid Framework
- Build grid configuration structures covering ATR-based and point-based spacing with multiplier controls
- Calculate exponential spacing and initial stop distances, ensuring broker freeze/stop compliance
- Persist grid metadata to memory containers designed for quick iteration and recovery
- Exit Criteria: simulated grids open with correct spacing, no broker rule violations, state snapshot logged
- Completed: grid inputs exposed, ATR handles loaded on demand with fallbacks, grid plans attached to signals with ATR shift-0 anchors (spacing, offsets, TP, final TP) while enforcing broker constraints. Per-level spacing uses `Grid_Exponential_Multiplier`, and lot sizing modes now recompute during `UpdateGridOrderForSignal()` so percentage/currency budgets use the live entry_reference→TP span right before `GridExecuteLevelTrade()`. `GRID_LOT_CALCULATED` extends this flow by multiplying the cumulative drawdown (sum of every older level’s entry_reference→next range) by `Grid_Lot_Multiplier` to size the next martingale order dynamically.

### Phase 3 – Order Lifecycle Control
- Automate buy/sell stop placement that trails adverse price action using the unified Grid_Positions_Stops_Percent gap
- Implement TP activation, trailing adjustments, and profit lock logic from the entry→next snapshot while referencing bid/ask as required
- Apply Grid_Positions_Stops_Percent to deeper grid layers while respecting exponential spacing
- Add guardrails for margin, slippage, and spread thresholds to halt grid expansion safely
- Exit Criteria: full trade cycle executed in tester with correct order stack, protective stops adapt as configured
- Completed: grid order controller stages levels sequentially, only instantiates the next grid level after a confirmed fill, fires `CTrade` market orders as soon as tagged stops are hit, records deal-linked tickets/activation time for telemetry, trails adverse moves, and enforces spread/margin guardrails with flexible lot sizing. For all pending levels, `next_level_price` trails adverse-only from `entry_reference_price`; TP and Final TP are computed from `entry_reference_price` with per-level spans and move favorable-only pre-fill.

### Phase 4 – Visualization & Telemetry
- Render signal, stop, limit, and trailing lines with profit-colored styles and minimal clutter
- Provide on-chart summaries plus optional verbose logging controlled by inputs like `Enable_Logs`
- Create lightweight file logging (e.g., `query_debug.txt`) for post-run analysis without flooding the terminal
- Track per-grid stats (duration, excursion, profit factor) for future analytics modules
- Exit Criteria: chart artifacts align with live orders, logs expose actionable diagnostics
- Completed: next/lot updates logged concisely (`NEXT_UPDATE`, `LOT_RESOLVED`), chart NEXT mirrors backend trailing `next_level_price`.

### Phase 5 – Persistence & Resilience
- Serialize active grid state (orders, trailing levels, indicators) to survive reconnects and timeframe changes
- On `OnInit()`, reconcile broker order book with stored state and redraw chart elements accordingly
- Revalidate indicator buffers after reload; handle invalid handles with graceful degradation
- Exit Criteria: manual terminal reconnect retains grid logic without manual intervention, no dangling chart objects

### Phase 6 – Optimization & Release Prep
- Profile tick execution time and memory use; optimize array operations and indicator calls
- Run Strategy Tester suites across symbols to stress ATR vs point modes and trailing variants
- Tune default `input` presets and document recommended scenarios (scalping, trend, range)
- Finalize README, changelog, and deployment checklist; confirm packaging of required dependencies
- Exit Criteria: performance budgets met, documentation current, release candidate tagged

### Ongoing Tasks
- Keep README and AGENTS synchronized after each phase
- Maintain coding conventions listed below; highlight deviations with `FIXME:` in code reviews
- Review broker constraint data quarterly or whenever a symbol/market is added
- Reference MQL5 Standard Library documentation when reusing built-in classes:
  * Mathematics — Include\\Math\\ — https://www.mql5.com/en/docs/standardlibrary/mathematics
  * OpenCL — Include\\OpenCL\\ — https://www.mql5.com/en/docs/standardlibrary/copencl
  * Basic Class CObject — Include\\ — https://www.mql5.com/en/docs/standardlibrary/cobject
  * Data Collections — Include\\Arrays\\ — https://www.mql5.com/en/docs/standardlibrary/datastructures
  * Generic Data Collections — Include\\Generic\\ — https://www.mql5.com/en/docs/standardlibrary/generic
  * Files — Include\\Files\\ — https://www.mql5.com/en/docs/standardlibrary/fileoperations
  * Strings — Include\\Strings\\ — https://www.mql5.com/en/docs/standardlibrary/stringoperations
  * Graphic Objects — Include\\Objects\\ — https://www.mql5.com/en/docs/standardlibrary/chart_object_classes
  * Custom Graphics — Include\\Canvas\\ — https://www.mql5.com/en/docs/standardlibrary/canvasgraphics
  * 3D Graphics — Include\\Canvas\\ — https://www.mql5.com/en/docs/standardlibrary/3dgraphics
  * Price Charts — Include\\Charts\\ — https://www.mql5.com/en/docs/standardlibrary/cchart
  * Scientific Charts — Include\\Graphics\\ — https://www.mql5.com/en/docs/standardlibrary/graphics
  * Indicators — Include\\Indicators\\ — https://www.mql5.com/en/docs/standardlibrary/technicalindicators
  * Trade Classes — Include\\Trade\\ — https://www.mql5.com/en/docs/standardlibrary/tradeclasses
  * Strategy Modules — Include\\Expert\\ — https://www.mql5.com/en/docs/standardlibrary/expertclasses
  * Panels and Dialogs — Include\\Controls\\ — https://www.mql5.com/en/docs/standardlibrary/controls

## Strategy Trend Settings
- Inputs live in `services/trading_management/ea_inputs.mqh` under the `+= Strategy Trend Context =+` group.
- `Trend_Strategy_Timeframe` selects the dedicated confirmation timeframe. Set it to `PERIOD_CURRENT` to disable the trend layer (the EA falls back to base confirmations). Unsupported TFs fall back to the main `Strategy_Timeframe`.
- `Strategy_Trend_Mode`: `TREND_OFF` or `TREND_BPERCENT`.
  - `LoadTrendIndicators()` only instantiates the Bollinger Percent handle when the mode is enabled; `TREND_OFF` skips the entire flow.
  - Trend confirmation now evaluates **only shift 1** (`main_shift_1 >= signal_shift_1` for bullish, `<=` for bearish) to keep the guard lightweight.
- `Base_Fresh_Structure_Time` and `Trend_Fresh_Structure_Time` ensure we don't re-enter on the same structure timestamp by requiring a strictly newer structure before arming another grid in the same direction. `Base_Slope_Filter`/`Trend_Slope_Filter` optionally demand a specific `bands_percent_slope_1` (UP/DOWN) on the confirmation candle; `NO_SLOPE` skips the guard.
- `CanAttemptSignal()` short-circuits when the requested trend indicator handle is unavailable, preventing partially initialized grids. `LoadTrendFilterData()` fetches the latest values during detection and `TrendFilterAllowsSignal()` blocks signals that violate the rule.

## Trend Structure Settings
- The trend context mirrors the base structure inputs (structure-type filters, support/resistance selectors, extern counts). When `Trend_Strategy_Timeframe` differs from the strategy timeframe, `LoadTrendStructureFilterIndicator()` loads a dedicated `TrendStructStochIndicatorHandle`; otherwise the EA reuses the strategy handles.
- `Trend_First_Structure_Filter`: Bullish-only guard. Options `BULLISH_STRUCT_OFF`, `BULLISH_STRUCT_LL`, `BULLISH_STRUCT_LH`, `BULLISH_STRUCT_LL_LH` (`OSCILLATOR_STRUCTURE_EQ` always passes).
- `Trend_Second_Structure_Filter`: Bearish-only guard. Options `BEARISH_STRUCT_OFF`, `BEARISH_STRUCT_HH`, `BEARISH_STRUCT_HL`, `BEARISH_STRUCT_HH_HL` (`EQ` passes).
- The mirrored structure filters (base/trend extern counts plus the new support/resistance enums, fresh-structure guards, and slope filters) evaluate on their respective timeframes, letting a higher-timeframe trend context gate the lower-timeframe grid while still enforcing strategy-level structure rules.
- `LoadTrendStructureData()` seeds the snapshot stored in `SignalParams`, `FetchStructureForFilters()` picks the correct dataset at evaluation time, and `EvaluateTrendStructureTypeFilters()` applies the directional reversion checks.

## Developer Debug Settings
- `Enable_Trend_Filter_Sanity_Stop`: Tester helper. When enabled (and `MQL_TESTER` is true) the EA calls `TesterStop()` if a trend/trend-structure filter is disabled while the corresponding timeframe parameter is stepped, preventing wasted optimization cycles. Default `false`.

## Protection Risk Filter
- Service lives in `services/trading_signals/protection_risk_filter.mqh` and runs on every tick plus during signal admission.
- Inputs:
  - `Protection_Risk_Mode`: `ENABLED_OFF`, `ENABLED_GRID_PROTECTION`, `ENABLED_GRID_PROTECTION_DAILY` (daily mode blocks new grids until the next `PERIOD_D1` candle).
  - `Protection_Risk_Drawdown_Type`: `PROTECTION_RISK_ACCOUNT_SIZE_PERCENT`, `PROTECTION_RISK_ACCOUNT_BALANCE_PERCENT`, `PROTECTION_RISK_FIXED_CURRENCY`.
  - `Protection_Risk_Drawdown_Value`: Magnitude interpreted according to the selected type.
  - `Market_Close_Guard_Timeframe`: Timeframe that defines when the EA must flatten before the broker session closes; the guard rounds down to the start of the last candle before the close (e.g., `PERIOD_M10` closes at 22:50 for a 22:58 close).
- Drawdown is evaluated only on positions that match `_Symbol` and `g_magic_number`. On breach, the service force-closes every `SignalParams` entry (bullish and bearish), removes their chart objects, and then closes any leftover broker positions tagged with the EA magic to keep the sequence consistent.
- Daily locks reset automatically when `iTime(_Symbol, PERIOD_D1, 0)` advances, so devs do not need to manually clear state between backtests.
- The market close guard runs on every tick regardless of the drawdown mode and uses `IsMarketOpen()` session data to determine the next close. Once the guard window begins it force-closes all grids/positions and blocks new signals until the session end timestamp advances.
- `services/trading_signals/market_status_controller.mqh` owns the runtime status machine (`ACTIVE`, `CLOSE_GUARD`, `BROKER_CLOSEONLY`, `BROKER_DISABLED`) used across signals, protection, and frontend. Helper functions (`MarketStatusAllowsSignalAttempts()`, `MarketStatusAllowsBrokerActions()`, etc.) gate new work.
- `ProtectionRiskMonitorTradeMode()` polls `SYMBOL_TRADE_MODE` every tick. `CLOSEONLY` immediately schedules force-closes (still allowed to execute), while `DISABLED` parks the grids and keeps retrying once the broker reopens. No third-party APIs are required; all data comes from MT5.
- Any `CTrade` send/close failure that returns `TRADE_RETCODE_MARKET_CLOSED`, `TRADE_RETCODE_TRADE_DISABLED`, `TRADE_RETCODE_TRADE_TIMEOUT`, `ERR_MARKET_CLOSED`, or `ERR_TRADE_DISABLED` flows through `MarketStatusRegisterBrokerFailure()`, elevating the status to `BROKER_DISABLED` and flagging a pending force-close when needed.
- Pending force-close requests persist while the broker blocks trading. `ProtectionRiskProcessPendingForceClose()` retries automatically as soon as `MarketStatusAllowsBrokerActions()` returns true, preventing broken sequences after unexpected halts.
- The frontend summary comment now prints the current market status and reason so manual monitoring lines up with the backend state transitions.

## MQL5 Language Conventions

### C++ Feature Restrictions
- **No C++11 features**: Do not use `auto`, lambdas, local references, range-based for loops, or heavy templates
- **No pointer arithmetic**: Use array indexing instead
- **Use explicit types**: Always declare variable types explicitly (int, double, string, datetime, etc.)
- **Simple inline helpers**: Keep functions straightforward; avoid complex template metaprogramming

### Code Style
- **Indentation**: 2 spaces (no tabs)
- **Variable naming**: `snake_case` (e.g., `signal_entry_time`, `g_decimal_digits`)
- **Function naming**: `CamelCase` (e.g., `DetectBullishSignal()`, `SaveFullSignalTransaction()`)
- **Global variables**: Prefix with `g_` (e.g., `g_symbol`, `g_ask`, `g_bid`)
- **Enum values**: ALL_CAPS or CamelCase (e.g., `BULLISH`, `PERIOD_M1`)
- **Constants**: ALL_CAPS with underscores (e.g., `INVALID_HANDLE`, `DEF_OSC_STRUCT_TYPE`)

### File Organization
- **One file = one responsibility**: Each .mqh file should have a single, clear purpose
- **Modular services**: Group related functionality into service directories
- **No complex macro chains**: Avoid nested or complex #define macros

## Include Path Conventions

### Standard MQL5 Libraries (Angle Brackets)
Use angle brackets for files in the MQL5/Include directory:
```mql5
#include <Trade/Trade.mqh>
#include <Generic/HashMap.mqh>
#include <MarketIndicatorStructures/stochastic_structure.mqh>
```

### Custom Project Services (Quotes)
Use relative paths with quotes for project-specific files:
```mql5
#include "services/trading_tools/array_functions.mqh"
#include "services/trading_database/initial_database_setup.mqh"
#include "services/trading_signals/market_signal_crawler.mqh"
```

### Include Order
1. Standard MQL5 libraries first (grouped logically)
2. Custom services second (grouped by service type)
3. Within custom services, order by dependency (tools → signals → database → management → frontend)
- **IMPORTANT**: Maintain a single, top-to-bottom include cascade rooted in `HFT_Grid_AI.mq5`; services must not re-include dependencies or redeclare extern globals—always rely on the orchestrated order in the main entry point.

## Service Architecture

### Service Modules
- **trading_tools**: Utility functions (arrays, math, enums, logging)
- **trading_signals**: Signal detection and management logic
- **trading_database**: SQLite database operations
- **trading_management**: Market conditions and indicator loaders
- **frontend**: UI components and display logic

### Dependency Rules
- **Tools** should have no dependencies on other services
- **Signals** can depend on tools
- **Database** can depend on tools and signals
- **Management** can depend on tools
- **Frontend** can depend on all services
- **No circular dependencies**: A service must never include a file that includes it

## Error Handling Patterns

### Standard Error Check
```mql5
if(!SomeOperation())
{
  Print("OperationName failed: ", GetLastError());
  return false;
}
```

### Critical Errors (Strategy Tester)
```mql5
if(indicator_handle == INVALID_HANDLE)
{
  Print("ERROR LOADING INDICATOR: ", GetLastError());
  TesterStop();
  return INIT_FAILED;
}
```

### Defensive Coding
- Always validate array sizes before iteration
- Check for division by zero
- Verify handle validity before use
- Bounds-check array access when using dynamic indices

## Testing Considerations

### Important Limitations
- **No unit testing framework**: MQL5 does not support traditional unit tests
- **Testing method**: Use Strategy Tester with historical data
- **Manual verification**: Visual inspection and log analysis required
- **Performance testing**: Monitor execution time with `GetTickCount()`

### Test Mode Support
- Implement `Test_Mode` input parameter to reduce indicator load
- Use conditional compilation where appropriate
- Enable verbose logging during development
- Disable indicator visualization with `TesterHideIndicators(true)`

### Debugging Approaches
- Liberal use of `Print()` statements
- Enable `Enable_Logs` parameter for detailed logging
- Write debug queries to files (e.g., `query_debug.txt`)
- Use `Comment()` for real-time on-chart debugging

## Data Structure Conventions

### Struct Design
- Provide default constructor that initializes all members
- Provide copy constructor for deep copying
- Use arrays of structs sparingly (can be slow)
- Keep structs focused on data, not behavior

### Array Management
- Use template functions for type-safe operations
- Reserve capacity with `ArrayResize(array, size, reserved_size)`
- Clear arrays with `ArrayResize(array, 0, 0)` to free memory
- Use reverse iteration (`i >= 0`) when removing elements during loop

## Performance Guidelines

### Indicator Management
- Load indicators once in `OnInit()`, not in `OnTick()`
- Reuse indicator handles across calls
- Use `CopyBuffer()` for efficient data retrieval
- Minimize indicator calculations per tick

### Memory Management
- Avoid excessive dynamic allocations in hot paths
- Clear temporary arrays after use
- Be mindful of struct copying (pass by reference when possible)
- Use reserved size in `ArrayResize()` to reduce reallocations

### Database Performance
- Batch inserts within transactions
- Use prepared statements for repeated queries
- Create indices on columns used in WHERE clauses
- Monitor database file growth

## Common Patterns

### Signal Lifecycle
1. Detect signal condition in `Main()` (on new bar)
2. Create `SignalParams` struct
3. Populate indicator data from all timeframes
4. Add to running signals array
5. Monitor in `Main_Tick()` (every tick)
6. Close and store to database when conditions met
7. Remove from running array

### Multi-Timeframe Data Collection
```mql5
for(int i = 0; i < ArraySize(ExtIndicatorHandles); i++)
{
  SomeStructure data;
  data.InitValues(ExtIndicatorHandles[i], 0);
  AddElementToArray(signal.indicator_data, data);
}
```

## Prohibited Practices

- Do not use `goto` statements
- Do not write deeply nested code (max 3-4 levels)
- Do not use global state when local scope suffices
- Do not ignore function return values
- Do not mix business logic with UI code
- Do not hardcode magic numbers (use named constants or enums)
- Do not create temporary helper scripts (keep everything in proper services)

## Documentation Standards

- Add brief comment headers to major functions
- Document function parameters and return values for complex functions
- Explain non-obvious business logic with inline comments
- Keep comments up-to-date with code changes
- Use `FIXME:` for known issues that need addressing
