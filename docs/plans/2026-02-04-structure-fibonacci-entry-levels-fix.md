# Structure Fibonacci Entry Levels Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure Structure Fibonacci entry triggers only within configured levels and limit-mode entries are placed on the correct fib boundaries so grids do not execute immediately near the current price.

**Architecture:** Add a strict fib range resolver for entry gating (no extrapolation beyond configured levels). Introduce a deterministic entry evaluator that accepts explicit prices and selects the limit boundary on the correct side of price (buy below, sell above) while keeping zone mode as market-at-close. Keep grid extrapolation logic intact for spacing and next-level planning. @mql5-functional

**Tech Stack:** MQL5 (MT5), existing services include pipeline, MetaEditor compile + script-based tests.

---

**Findings (Current Behavior)**
- `ResolveStructureFibonacciEntry` uses `ResolveFibonacciRangeForPercent`, which extrapolates beyond the last configured level, so percents like 150-200 still resolve a range and can trigger entries.
- Limit-mode entries always use the `upper` boundary, which can be above the current price in peak orientation, causing immediate execution on the first tick.

**Decisions (Feb 4, 2026)**
- Signal is created as soon as price enters a configured range.
- Limit entries: bullish below price, bearish above price.
- Limit-mode evaluation uses the previous closed candle (`bar_index = 1`).

---

### Task 1: Add Strict Range Resolver (No Extrapolation)

**Files:**
- Modify: `services/trading_management/structure_fibonacci_levels.mqh`
- Create: `tests/structure_fibonacci_strict_range_test.mq5`

**Step 1: Write the failing test**
Create `tests/structure_fibonacci_strict_range_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

bool AssertClose(const string label,
                 const double actual,
                 const double expected,
                 const double tol,
                 string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.2f got %.2f\n", label, expected, actual);
    return false;
  }
  return true;
}

void OnStart()
{
  string errors = "";
  double levels[];
  string err = "";
  if(!ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0", levels, err))
  {
    Print("FAIL parse: ", err);
    return;
  }

  double lower = 0.0;
  double upper = 0.0;

  if(ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 150.0, lower, upper))
    errors += "strict range should fail above max\n";

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 23.6, lower, upper))
    errors += "strict range failed at min\n";
  else
  {
    AssertClose("lower@min", lower, 23.6, 0.01, errors);
    AssertClose("upper@min", upper, 38.2, 0.01, errors);
  }

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 100.0, lower, upper))
    errors += "strict range failed at max\n";
  else
  {
    AssertClose("lower@max", lower, 78.6, 0.01, errors);
    AssertClose("upper@max", upper, 100.0, 0.01, errors);
  }

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_strict_range_test.mq5" /log:"tests/structure_fibonacci_strict_range_test.log"
```
Expected: FAIL with `ResolveFibonacciRangeForPercentStrict` undefined.

**Step 3: Write minimal implementation**
Update `services/trading_management/structure_fibonacci_levels.mqh`:
```mq5
bool ResolveFibonacciRangeForPercentStrict(const double &levels[],
                                           const int total,
                                           const double percent,
                                           double &lower_out,
                                           double &upper_out)
{
  lower_out = 0.0;
  upper_out = 0.0;
  if(total < 2)
    return false;

  if(percent < levels[0] || percent > levels[total - 1])
    return false;

  for(int i = 0; i < total - 1; i++)
  {
    double lower = levels[i];
    double upper = levels[i + 1];
    if(percent >= lower && percent <= upper)
    {
      lower_out = lower;
      upper_out = upper;
      return true;
    }
  }

  return false;
}
```

**Step 4: Run test to verify it passes**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_strict_range_test.mq5" /log:"tests/structure_fibonacci_strict_range_test.log"
```
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_management/structure_fibonacci_levels.mqh \
  tests/structure_fibonacci_strict_range_test.mq5
git commit -m "feat: add strict fib range resolver for entries"
```

---

### Task 2: Deterministic Entry Evaluation + Boundary Selection Tests

**Files:**
- Modify: `services/trading_signals/market_signal_filters.mqh`
- Create: `tests/structure_fibonacci_entry_levels_test.mq5`

**Step 1: Write the failing test**
Create `tests/structure_fibonacci_entry_levels_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/ea_inputs.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

struct StrategyContextIndicators
{
  StrategyContextTypes      context;
  ENUM_TIMEFRAMES           timeframe;
  datetime                  bar_time;
  bool                      structure_valid;
  StochasticMarketStructure structure_data;

  StrategyContextIndicators()
  {
    context         = CONTEXT_SLOT_BASE;
    timeframe       = PERIOD_CURRENT;
    bar_time        = 0;
    structure_valid = false;
  }
};

double GridResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

datetime GetLastContextStructureTime(const StrategyContextTypes context,
                                     const SignalTypes direction)
{
  return 0;
}

#include "../services/trading_signals/market_signal_filters.mqh"

SymbolTradingConstraints g_symbol_constraints;

bool AssertClose(const string label,
                 const double actual,
                 const double expected,
                 const double tol,
                 string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.2f got %.2f\n", label, expected, actual);
    return false;
  }
  return true;
}

double PriceForPercent(const StochasticMarketStructure &s, const double percent)
{
  double peak = 0.0;
  double bottom = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(s, peak, bottom, current_is_bottom))
    return 0.0;
  double price = 0.0;
  if(!ResolveStructurePriceForPercent(peak, bottom, current_is_bottom, percent, price))
    return 0.0;
  return price;
}

double PercentForPrice(const StochasticMarketStructure &s, const double price)
{
  double peak = 0.0;
  double bottom = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(s, peak, bottom, current_is_bottom))
    return 0.0;
  double percent = 0.0;
  if(!ResolveStructurePercentForPrice(peak, bottom, current_is_bottom, price, percent))
    return 0.0;
  return percent;
}

void OnStart()
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  string errors = "";

  // Current bottom orientation
  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = 1.0900;
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = 1.2000;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = 1.1000;

  double close_price = PriceForPercent(s_bottom, 31.5);

  double entry_price = 0.0;
  bool in_zone = false;
  bool entry_is_limit = false;

  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              close_price,
                                              close_price,
                                              close_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit) ||
     !in_zone || !entry_is_limit)
  {
    errors += "bottom/bull limit failed\n";
  }
  else
  {
    AssertClose("bottom/bull limit pct", PercentForPrice(s_bottom, entry_price), 38.2, 0.1, errors);
    if(!(entry_price < close_price))
      errors += "bottom/bull entry not below close\n";
  }

  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              close_price,
                                              close_price,
                                              close_price,
                                              BEARISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit) ||
     !in_zone || !entry_is_limit)
  {
    errors += "bottom/bear limit failed\n";
  }
  else
  {
    AssertClose("bottom/bear limit pct", PercentForPrice(s_bottom, entry_price), 23.6, 0.1, errors);
    if(!(entry_price > close_price))
      errors += "bottom/bear entry not above close\n";
  }

  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              close_price,
                                              close_price,
                                              close_price,
                                              BULLISH,
                                              LEVEL_AS_ZONE,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit) ||
     !in_zone || entry_is_limit)
  {
    errors += "bottom/zone failed\n";
  }
  else if(MathAbs(entry_price - close_price) > 0.00001)
  {
    errors += "bottom/zone entry not at close\n";
  }

  double outside_price = PriceForPercent(s_bottom, 150.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              outside_price,
                                              outside_price,
                                              outside_price,
                                              BULLISH,
                                              LEVEL_AS_ZONE,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "outside range returned false\n";
  }
  else if(in_zone)
  {
    errors += "outside range should not trigger\n";
  }

  // Current peak orientation
  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = 1.1000;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = 1.2000;

  close_price = PriceForPercent(s_peak, 31.5);

  if(!ResolveStructureFibonacciEntryForPrices(s_peak,
                                              close_price,
                                              close_price,
                                              close_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit) ||
     !in_zone || !entry_is_limit)
  {
    errors += "peak/bull limit failed\n";
  }
  else
  {
    AssertClose("peak/bull limit pct", PercentForPrice(s_peak, entry_price), 23.6, 0.1, errors);
    if(!(entry_price < close_price))
      errors += "peak/bull entry not below close\n";
  }

  if(!ResolveStructureFibonacciEntryForPrices(s_peak,
                                              close_price,
                                              close_price,
                                              close_price,
                                              BEARISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit) ||
     !in_zone || !entry_is_limit)
  {
    errors += "peak/bear limit failed\n";
  }
  else
  {
    AssertClose("peak/bear limit pct", PercentForPrice(s_peak, entry_price), 38.2, 0.1, errors);
    if(!(entry_price > close_price))
      errors += "peak/bear entry not above close\n";
  }

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_entry_levels_test.mq5" /log:"tests/structure_fibonacci_entry_levels_test.log"
```
Expected: FAIL with `ResolveStructureFibonacciEntryForPrices` undefined.

**Step 3: Write minimal implementation**
Update `services/trading_signals/market_signal_filters.mqh` by adding a deterministic helper and using the strict range resolver:
```mq5
bool ResolveStructureFibonacciEntryForPrices(const StochasticMarketStructure &structure,
                                             const double close_price,
                                             const double low_price,
                                             const double high_price,
                                             const SignalTypes direction,
                                             const StructureTriggerEntryModes trigger_mode,
                                             double &entry_price_out,
                                             bool &in_zone,
                                             bool &entry_is_limit)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;

  if(!g_structure_fibo_config.valid)
    return false;

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(structure, peak_price, bottom_price, current_is_bottom))
    return false;

  double close_percent = 0.0;
  double extreme_percent = 0.0;
  if(!ResolveStructurePercentForPrice(peak_price,
                                      bottom_price,
                                      current_is_bottom,
                                      close_price,
                                      close_percent))
    return false;

  if(direction == BULLISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        low_price,
                                        extreme_percent))
      extreme_percent = close_percent;
  }
  else if(direction == BEARISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        high_price,
                                        extreme_percent))
      extreme_percent = close_percent;
  }
  else
  {
    extreme_percent = close_percent;
  }

  double lower = 0.0;
  double upper = 0.0;
  bool close_ok = ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                                        ArraySize(g_structure_fibo_config.levels),
                                                        close_percent,
                                                        lower,
                                                        upper);
  bool close_in = close_ok && close_percent >= lower && close_percent <= upper;
  bool extreme_in = false;

  if(close_in)
  {
    extreme_in = (extreme_percent >= lower && extreme_percent <= upper);
  }
  else
  {
    double ext_lower = 0.0;
    double ext_upper = 0.0;
    if(ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                             ArraySize(g_structure_fibo_config.levels),
                                             extreme_percent,
                                             ext_lower,
                                             ext_upper))
    {
      if(extreme_percent >= ext_lower && extreme_percent <= ext_upper)
      {
        lower = ext_lower;
        upper = ext_upper;
        extreme_in = true;
      }
    }
  }

  if(!close_in && !extreme_in)
    return true;

  double required_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
  if(required_points > 0.0)
  {
    double lower_price = 0.0;
    double upper_price = 0.0;
    if(ResolveStructurePriceForPercent(peak_price,
                                       bottom_price,
                                       current_is_bottom,
                                       lower,
                                       lower_price) &&
       ResolveStructurePriceForPercent(peak_price,
                                       bottom_price,
                                       current_is_bottom,
                                       upper,
                                       upper_price))
    {
      double point_size = GridResolvePointSizeSafe();
      double range_points = (point_size > 0.0)
                              ? MathAbs(lower_price - upper_price) / point_size
                              : 0.0;
      if(range_points < required_points)
        return true;
    }
  }

  in_zone = true;
  entry_is_limit = (trigger_mode == LEVELS_AS_LIMITS);

  if(entry_is_limit)
  {
    double lower_price = 0.0;
    double upper_price = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        lower,
                                        lower_price) ||
       !ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        upper,
                                        upper_price))
      return false;

    double min_price = MathMin(lower_price, upper_price);
    double max_price = MathMax(lower_price, upper_price);

    if(direction == BULLISH)
      entry_price_out = min_price;
    else if(direction == BEARISH)
      entry_price_out = max_price;
    else
      entry_price_out = close_price;

    if(direction == BULLISH && entry_price_out > close_price)
      return false;
    if(direction == BEARISH && entry_price_out < close_price)
      return false;
  }
  else
  {
    entry_price_out = close_price;
  }

  return true;
}
```

**Step 4: Run test to verify it passes**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_entry_levels_test.mq5" /log:"tests/structure_fibonacci_entry_levels_test.log"
```
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_signals/market_signal_filters.mqh \
  tests/structure_fibonacci_entry_levels_test.mq5
git commit -m "test: add deterministic fib entry boundary coverage"
```

---

### Task 3: Wire Helper Into Live Entry Path

**Files:**
- Modify: `services/trading_signals/market_signal_filters.mqh`

**Step 1: Write the failing test**
No new unit test; compile the EA and existing tests to confirm the live path uses the new helper.

**Step 2: Run compile to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"
```
Expected: PASS before change, but we still treat this as a safety gate for integration.

**Step 3: Write minimal implementation**
Update `ResolveStructureFibonacciEntry` to call the new helper with explicit prices:
```mq5
bool ResolveStructureFibonacciEntry(const StrategyContextIndicators &snapshot,
                                    const SignalTypes direction,
                                    const StructureTriggerEntryModes trigger_mode,
                                    double &entry_price_out,
                                    bool &in_zone,
                                    bool &entry_is_limit)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;

  if(!snapshot.structure_valid)
    return false;
  if(!g_structure_fibo_config.valid)
    return false;

  int bar_index = (trigger_mode == LEVELS_AS_LIMITS) ? 1 : 0;
  double close_price = iClose(_Symbol, snapshot.timeframe, bar_index);
  double low_price   = iLow(_Symbol, snapshot.timeframe, bar_index);
  double high_price  = iHigh(_Symbol, snapshot.timeframe, bar_index);

  return ResolveStructureFibonacciEntryForPrices(snapshot.structure_data,
                                                 close_price,
                                                 low_price,
                                                 high_price,
                                                 direction,
                                                 trigger_mode,
                                                 entry_price_out,
                                                 in_zone,
                                                 entry_is_limit);
}
```

**Step 4: Run compile and key tests**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_strict_range_test.mq5" /log:"tests/structure_fibonacci_strict_range_test.log"
"MetaEditor64.exe" /compile:"tests/structure_fibonacci_entry_levels_test.mq5" /log:"tests/structure_fibonacci_entry_levels_test.log"
"MetaEditor64.exe" /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"
```
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_signals/market_signal_filters.mqh
git commit -m "fix: strict fib entry gating and limit boundary selection"
```

---

### Task 4: Manual QA (Default Inputs)

**Files:**
- No code changes.

**Step 1: Run manual test**
- Compile EA:
```bash
"MetaEditor64.exe" /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"
```
- Attach to a chart with default inputs.
- Test both `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE` on M1.

**Step 2: Verify behaviors**
- `LEVELS_AS_LIMITS`: When price is between 23.6 and 38.2, a bullish limit should be placed on the boundary below price and a bearish limit above price (no immediate fill).
- `LEVELS_AS_LIMITS` uses the previous closed candle for evaluation (index 1), so the first tick of a new candle should not trigger entries.
- `LEVEL_AS_ZONE`: Signal can trigger at the current price inside the range.
- If the live percent is between 150 and 200 (outside configured levels), no signal triggers.

**Step 3: Record results**
- Note symbol, timestamp, and screenshots if any unexpected behavior persists.

---

## Open Questions
- None.
