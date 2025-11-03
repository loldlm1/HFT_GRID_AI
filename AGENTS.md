# AGENTS Instructions for HFT Grid AI EA (MQL5)

## Project Overview
This is a HFT Grid AI Expert Advisor designed to execute high frequency positions with a robust grid and risk managment logic. The EA operates tick-by-tick, capturing multi-timeframe indicator data for pattern analysis.

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
