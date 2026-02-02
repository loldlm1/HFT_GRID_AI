# Structure Fibonacci Entry Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace channel/MA/alligator/stoch-entry filters with a structure-only Fibonacci entry trigger using a configurable level list and entry trigger mode, while keeping grid execution clean and readable.

**Architecture:** Parse `Structure_Fibonacci_Levels` once at init in the trading_management layer and keep a validated, sorted level list + last-range step. Signal evaluation uses the structure snapshot (stochastic market structure) to resolve the active Fibonacci range and entry price. Grid entry activation uses `Structure_Trigger_Entry` to decide zone vs limit behavior. Remove obsolete inputs, indicator loading, and signal fields for channel/bpercent/alligator/body MA/stoch entry. @mql5-functional

**Tech Stack:** MQL5 (MT5), existing services include pipeline, MetaEditor compile + Strategy Tester for manual validation.

---

## Open Questions / Assumptions (confirm before implementation)
1. **Contexts & timeframes:** Do we keep `Strategy_Timeframe`, `Trend_Strategy_Timeframe`, `Macro_Strategy_Timeframe`, `Session_Strategy_Timeframe` (multi-timeframe contexts), or collapse to base-only context? (Plan assumes we keep contexts but remove non-structure filters.)
2. **Grid channel spacing:** Should channel-based grid spacing remain (`Grid_Base_Strategy_Type` = *BOLLINGER/KELTNER/ATR*)? If yes, we will infer channel type from `Grid_Base_Strategy_Type` and remove `Strategy_Channel_Indicator_Type`. If no, we will force `Grid_Base_Strategy_Type` to `POINTS_RANGE` or `STOCH_STRUCTURE_RANGE` and drop channel indicator loading entirely.
3. **Entry style override:** Should `Structure_Trigger_Entry = LEVELS_AS_LIMITS` force initial entry to behave as a **limit** (price <= level for bullish / >= for bearish) regardless of `Grid_Initial_Entry_Style`? (Plan assumes yes.)
4. **Range detection price:** For fib range detection, should we use (bullish) **low OR close**, (bearish) **high OR close**, as described? (Plan assumes yes.)
5. **Alligator-based trailing/risk:** Remove or hard-disable all alligator-based trailing/risk (Grid_Risk_Trend_Mode, TRAILING_LIPS_MA), or keep with fixed defaults? (Plan assumes hard-disable / fallback to safe modes.)

---

### Task 1: Add Fibonacci entry config + parsing tests

**Files:**
- Create: `services/trading_management/structure_fibonacci_levels.mqh`
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/trading_management.mqh`
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Test: `tests/structure_fibonacci_levels_test.mq5`

**Step 1: Write the failing test**
Create `tests/structure_fibonacci_levels_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

bool AssertClose(const string label, const double actual, const double expected, const double tol, string &errors)
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
  double levels[];
  string err = "";
  bool ok = ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0", levels, err);
  string errors = "";

  if(!ok)
  {
    Print("FAIL parse: ", err);
    return;
  }

  AssertClose("levels[0]", levels[0], 23.6, 0.01, errors);
  AssertClose("levels[5]", levels[5], 100.0, 0.01, errors);

  double lower = 0.0;
  double upper = 0.0;
  bool range_ok = ResolveFibonacciRangeForPercent(levels, ArraySize(levels), 110.0, lower, upper);
  if(!range_ok)
    errors += "range not resolved\n";
  AssertClose("lower", lower, 100.0, 0.01, errors);
  AssertClose("upper", upper, 121.4, 0.01, errors); // 100 + (100-78.6)

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run: compile the script in MetaEditor or Strategy Tester.
Expected: FAIL with missing include or undefined `ParseStructureFibonacciLevels` / `ResolveFibonacciRangeForPercent`.

**Step 3: Write minimal implementation**
Create `services/trading_management/structure_fibonacci_levels.mqh`:
```mq5
//+------------------------------------------------------------------+
//|                trading_management/structure_fibonacci_levels.mqh|
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_

#include "../utils/array_functions.mqh"

struct StructureFibonacciConfig
{
  double levels[];
  double last_step;
  bool   valid;

  StructureFibonacciConfig()
  {
    ArrayResize(levels, 0);
    last_step = 0.0;
    valid = false;
  }
};

bool ParseStructureFibonacciLevels(const string csv,
                                   double &levels_out[],
                                   string &error)
{
  ArrayResize(levels_out, 0);
  error = "";

  string parts[];
  int total = StringSplit(csv, ',', parts);
  if(total <= 0)
  {
    error = "empty levels";
    return false;
  }

  for(int i = 0; i < total; i++)
  {
    string token = parts[i];
    StringTrimLeft(token);
    StringTrimRight(token);
    if(token == "")
      continue;
    double value = StringToDouble(token);
    if(!MathIsValidNumber(value))
    {
      error = StringFormat("invalid level '%s'", token);
      return false;
    }
    AddElementToArray(levels_out, value);
  }

  if(ArraySize(levels_out) < 2)
  {
    error = "need at least 2 levels";
    return false;
  }

  ArraySort(levels_out);

  // Remove duplicates / non-increasing values
  double deduped[];
  for(int i = 0; i < ArraySize(levels_out); i++)
  {
    double v = levels_out[i];
    if(ArraySize(deduped) == 0 || v > deduped[ArraySize(deduped) - 1])
      AddElementToArray(deduped, v);
  }

  if(ArraySize(deduped) < 2)
  {
    error = "levels must be strictly increasing";
    return false;
  }

  ArrayResize(levels_out, 0);
  ArrayCopy(levels_out, deduped);
  return true;
}

bool ResolveFibonacciRangeForPercent(const double &levels[],
                                     const int total,
                                     const double percent,
                                     double &lower_out,
                                     double &upper_out)
{
  lower_out = 0.0;
  upper_out = 0.0;
  if(total < 2)
    return false;

  if(percent < levels[0])
    return false;

  for(int i = 0; i < total - 1; i++)
  {
    double lower = levels[i];
    double upper = levels[i + 1];
    if(percent >= lower && percent < upper)
    {
      lower_out = lower;
      upper_out = upper;
      return true;
    }
  }

  double last = levels[total - 1];
  double step = last - levels[total - 2];
  if(step <= 0.0)
    return false;

  double upper = last;
  while(percent >= upper)
    upper += step;

  lower_out = upper - step;
  upper_out = upper;
  return true;
}

StructureFibonacciConfig g_structure_fibo_config;

bool LoadStructureFibonacciLevels(const string csv,
                                  const string fallback_csv)
{
  string error = "";
  double parsed[];
  if(!ParseStructureFibonacciLevels(csv, parsed, error))
  {
    if(!ParseStructureFibonacciLevels(fallback_csv, parsed, error))
      return false;
  }

  ArrayResize(g_structure_fibo_config.levels, 0);
  ArrayCopy(g_structure_fibo_config.levels, parsed);
  int total = ArraySize(g_structure_fibo_config.levels);
  g_structure_fibo_config.last_step = g_structure_fibo_config.levels[total - 1] -
                                      g_structure_fibo_config.levels[total - 2];
  g_structure_fibo_config.valid = (total >= 2 && g_structure_fibo_config.last_step > 0.0);
  return g_structure_fibo_config.valid;
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
```

Modify `services/core/enums.mqh` (add near other enums):
```mq5
enum StructureTriggerEntryModes
{
  LEVELS_AS_LIMITS = 0,
  LEVEL_AS_ZONE    = 1
};
```

Modify `services/trading_management/ea_inputs.mqh` (Strategy Context group):
```mq5
input string Structure_Fibonacci_Levels = "23.6,38.2,50.0,61.8,78.6,100.0";
input StructureTriggerEntryModes Structure_Trigger_Entry = LEVELS_AS_LIMITS;
```

Modify `services/trading_management.mqh` to include new file:
```mq5
#include "trading_management/structure_fibonacci_levels.mqh"
```

Modify `services/trading_management/indicator_definitions_loader.mqh` to load levels early (near `LoadAllIndicatorDefinitions` start):
```mq5
  LoadStructureFibonacciLevels(Structure_Fibonacci_Levels,
                               "23.6,38.2,50.0,61.8,78.6,100.0");
```

**Step 4: Run test to verify it passes**
Run: compile `tests/structure_fibonacci_levels_test.mq5`.
Expected: PASS log with resolved range `100.0 - 121.4`.

**Step 5: Commit**
```bash
git add services/core/enums.mqh services/trading_management/ea_inputs.mqh \
  services/trading_management/structure_fibonacci_levels.mqh \
  services/trading_management.mqh services/trading_management/indicator_definitions_loader.mqh \
  tests/structure_fibonacci_levels_test.mq5
git commit -m "feat: add structure fibonacci levels parsing"
```

---

### Task 2: Implement Fibonacci range + entry price resolution helpers

**Files:**
- Modify: `services/trading_signals/market_signal_filters.mqh`
- Modify: `services/indicators/fibonacci_calculator.mqh`
- Test: `tests/structure_fibonacci_entry_price_test.mq5`

**Step 1: Write the failing test**
Create `tests/structure_fibonacci_entry_price_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/indicators/fibonacci_calculator.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

bool AssertClose(const string label, const double actual, const double expected, const double tol, string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.5f got %.5f\n", label, expected, actual);
    return false;
  }
  return true;
}

void OnStart()
{
  // Simple reference: peak=1.2000, bottom=1.1000
  double peak = 1.2000;
  double bottom = 1.1000;
  double price_38 = GetFiboTrendBottomPrice(peak, bottom, 38.2);
  string errors = "";
  // 38.2% from peak -> 1.2000 - 0.0382*(0.1000) = 1.19618
  AssertClose("price_38", price_38, 1.19618, 0.0002, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run: compile `tests/structure_fibonacci_entry_price_test.mq5`.
Expected: PASS once helper functions exist; if not, compile errors or wrong expectations.

**Step 3: Write minimal implementation**
Add helper in `services/trading_signals/market_signal_filters.mqh` (new private helpers near top):
```mq5
bool ResolveStructureReferenceRange(const StochasticMarketStructure &structure,
                                    double &peak_price,
                                    double &bottom_price)
{
  peak_price = 0.0;
  bottom_price = 0.0;

  int total = ArraySize(structure.os_market_structures);
  if(total < 4)
    return false;

  bool initial_is_peak = structure.os_market_structures[0].is_peak;
  bool initial_is_bottom = !initial_is_peak;

  int structure_peaks_index   = initial_is_bottom ? 1 : 0;
  int structure_bottoms_index = initial_is_peak   ? 1 : 0;

  if(initial_is_bottom)
  {
    peak_price   = structure.os_market_structures[structure_bottoms_index + 1].extremum_high;
    bottom_price = structure.os_market_structures[structure_bottoms_index + 2].extremum_low;
  }
  else
  {
    peak_price   = structure.os_market_structures[structure_peaks_index + 2].extremum_high;
    bottom_price = structure.os_market_structures[structure_peaks_index + 1].extremum_low;
  }

  return (peak_price > 0.0 && bottom_price > 0.0 && peak_price != bottom_price);
}

bool ResolveStructurePercentForPrice(const double peak_price,
                                     const double bottom_price,
                                     const SignalTypes direction,
                                     const double price,
                                     double &percent_out)
{
  percent_out = 0.0;
  if(direction == BULLISH)
  {
    percent_out = GetFiboTrendBottomPercent(peak_price, bottom_price, price);
    return percent_out > 0.0;
  }
  if(direction == BEARISH)
  {
    percent_out = GetFiboTrendPeakPercent(peak_price, bottom_price, price);
    return percent_out > 0.0;
  }
  return false;
}

bool ResolveStructurePriceForPercent(const double peak_price,
                                     const double bottom_price,
                                     const SignalTypes direction,
                                     const double percent,
                                     double &price_out)
{
  price_out = 0.0;
  if(direction == BULLISH)
  {
    price_out = GetFiboTrendBottomPrice(peak_price, bottom_price, percent);
    return price_out > 0.0;
  }
  if(direction == BEARISH)
  {
    price_out = GetFiboTrendPeakPrice(peak_price, bottom_price, percent);
    return price_out > 0.0;
  }
  return false;
}
```

**Step 4: Run test to verify it passes**
Run: compile `tests/structure_fibonacci_entry_price_test.mq5`.
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_signals/market_signal_filters.mqh \
  tests/structure_fibonacci_entry_price_test.mq5
 git commit -m "feat: add structure fib price helpers"
```

---

### Task 3: Replace entry evaluation with structure Fibonacci trigger

**Files:**
- Modify: `services/trading_signals/market_signal_filters.mqh`
- Modify: `services/trading_signals/market_signal_detection.mqh`
- Modify: `services/trading_signals/signal_params_struct.mqh`
- Modify: `services/trading_signals/grid_order_lifecycle.mqh`
- Modify: `services/trading_signals/grid_planner.mqh`
- Test: `tests/structure_entry_trigger_test.mq5`

**Step 1: Write the failing test**
Create `tests/structure_entry_trigger_test.mq5` with a mocked `StochasticMarketStructure` containing 4 extrema to simulate bullish and verify range detection triggers entry (requires the new entry evaluation function):
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_signals/market_signal_filters.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

void OnStart()
{
  // Configure levels
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  // Build a minimal structure: bottom -> peak -> bottom -> peak
  StochasticMarketStructure s;
  ArrayResize(s.os_market_structures, 4);

  s.os_market_structures[0].is_peak = false;
  s.os_market_structures[0].extremum_low = 1.1000;
  s.os_market_structures[1].is_peak = true;
  s.os_market_structures[1].extremum_high = 1.2000;
  s.os_market_structures[2].is_peak = false;
  s.os_market_structures[2].extremum_low = 1.1500;
  s.os_market_structures[3].is_peak = true;
  s.os_market_structures[3].extremum_high = 1.2100;

  StrategyContextIndicators snapshot;
  snapshot.context = CONTEXT_SLOT_BASE;
  snapshot.timeframe = PERIOD_M1;
  snapshot.structure_valid = true;
  snapshot.structure_data = s;

  double entry_price = 0.0;
  bool in_zone = false;
  bool ok = ResolveStructureFibonacciEntry(snapshot,
                                           BULLISH,
                                           entry_price,
                                           in_zone);

  if(!ok || !in_zone)
    Print("FAIL: entry not triggered");
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run: compile the test script.
Expected: FAIL due to missing `ResolveStructureFibonacciEntry`.

**Step 3: Write minimal implementation**
Update `services/trading_signals/market_signal_filters.mqh` to add:
```mq5
bool ResolveStructureFibonacciEntry(const StrategyContextIndicators &snapshot,
                                    const SignalTypes direction,
                                    double &entry_price_out,
                                    bool &in_zone)
{
  entry_price_out = 0.0;
  in_zone = false;

  if(!snapshot.structure_valid)
    return false;

  double peak_price = 0.0;
  double bottom_price = 0.0;
  if(!ResolveStructureReferenceRange(snapshot.structure_data, peak_price, bottom_price))
    return false;

  double close_price = iClose(_Symbol, snapshot.timeframe, 0);
  double low_price   = iLow(_Symbol, snapshot.timeframe, 0);
  double high_price  = iHigh(_Symbol, snapshot.timeframe, 0);

  double close_percent = 0.0;
  double extreme_percent = 0.0;

  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, close_price, close_percent))
    return false;

  if(direction == BULLISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, low_price, extreme_percent))
      extreme_percent = close_percent;
  }
  else if(direction == BEARISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, high_price, extreme_percent))
      extreme_percent = close_percent;
  }

  double lower = 0.0;
  double upper = 0.0;
  bool range_ok = ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                                  ArraySize(g_structure_fibo_config.levels),
                                                  close_percent,
                                                  lower,
                                                  upper);
  if(!range_ok)
    return false;

  bool close_in = (close_percent >= lower && close_percent <= upper);
  bool extreme_in = (extreme_percent >= lower && extreme_percent <= upper);
  if(!close_in && !extreme_in)
    return true; // no trigger but not fatal

  if(!ResolveStructurePriceForPercent(peak_price, bottom_price, direction, upper, entry_price_out))
    return false;

  in_zone = true;
  return true;
}
```

Then replace `StrategyContextEvaluateEntry` body in `market_signal_filters.mqh` with structure-only checks + new entry trigger:
```mq5
bool StrategyContextEvaluateEntry(const StrategyContextIndicators &snapshot,
                                  const SignalTypes direction,
                                  datetime &structure_capture_time,
                                  bool &entry_allows,
                                  bool &filters_pass)
{
  structure_capture_time = 0;
  entry_allows = false;
  filters_pass = true;

  StrategyContextTypes context = snapshot.context;
  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);

  if(!EvaluateStructureRetestTrigger(snapshot, direction, structure_ctx))
  {
    filters_pass = false;
    return true;
  }

  if(!EvaluateStructureTypeFilters(snapshot, structure_ctx, direction))
  {
    filters_pass = false;
    return true;
  }

  bool enforce_fresh = StrategyContextFreshStructureEnabled(context) && structure_ctx.enabled;
  if(enforce_fresh)
  {
    if(!ValidateFreshStructureTimestamp(context,
                                        snapshot,
                                        structure_ctx,
                                        direction,
                                        structure_capture_time))
    {
      filters_pass = false;
      return true;
    }
  }

  double entry_price = 0.0;
  bool in_zone = false;
  if(!ResolveStructureFibonacciEntry(snapshot, direction, entry_price, in_zone))
    return false;

  entry_allows = in_zone;
  return true;
}
```

Update `services/trading_signals/signal_params_struct.mqh`:
- Replace `StrategyEntryChannelModes entry_trigger_mode;` with `StructureTriggerEntryModes entry_trigger_mode;`
- Remove `entry_evaluation_mode` field entirely.
- Initialize `entry_trigger_mode = Structure_Trigger_Entry;` in constructor.

Update `services/trading_signals/market_signal_detection.mqh` to set:
```mq5
signal.entry_trigger_mode = Structure_Trigger_Entry;
```
Remove `entry_evaluation_mode` assignment.

Update `services/trading_signals/grid_planner.mqh` to allow using a precomputed fib entry price when in LIMIT mode:
```mq5
  if(signal_params.entry_trigger_mode == LEVELS_AS_LIMITS && signal_params.entry_price > 0.0)
    entry_reference_price = signal_params.entry_price;
```
Place this after `CalculateBaseGridContext` returns entry_reference_price so it can override the reference when needed.

Update `services/trading_signals/grid_order_lifecycle.mqh` to use trigger mode for initial entry activation:
```mq5
bool GridShouldActivateStopOrder(...)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  double trigger = order_state.entry_reference_price;
  if(trigger <= 0.0)
    return false;

  if(signal_params.entry_trigger_mode == LEVELS_AS_LIMITS)
  {
    if(direction == BULLISH) return entry_side_price <= trigger;
    if(direction == BEARISH) return entry_side_price >= trigger;
    return false;
  }

  if(direction == BULLISH) return entry_side_price >= trigger;
  if(direction == BEARISH) return entry_side_price <= trigger;
  return false;
}
```

**Step 4: Run test to verify it passes**
Run: compile `tests/structure_entry_trigger_test.mq5`.
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_signals/market_signal_filters.mqh \
  services/trading_signals/market_signal_detection.mqh \
  services/trading_signals/signal_params_struct.mqh \
  services/trading_signals/grid_planner.mqh \
  services/trading_signals/grid_order_lifecycle.mqh \
  tests/structure_entry_trigger_test.mq5
 git commit -m "feat: fibonacci-based entry trigger"
```

---

### Task 4: Remove legacy filters/indicators and simplify context snapshots

**Files:**
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/strategy_structure_context.mqh`
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Modify: `services/trading_signals/market_signal_state.mqh`
- Modify: `services/trading_signals/market_signal_indicators.mqh`
- Modify: `services/trading_signals/market_signal_channel_guards.mqh`
- Modify: `services/trading_signals/grid_channel_utils.mqh`
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/trading_signals/market_signal_detection.mqh`
- Modify: `services/trading_signals.mqh`

**Step 1: Write the failing test**
Run a compile of `HFT_Grid_AI.mq5` after removing inputs/enums (expected to fail initially):
- Expected: missing identifiers for removed enums/inputs.

**Step 2: Run test to verify it fails**
Run: compile `HFT_Grid_AI.mq5` in MetaEditor.
Expected: FAIL with undefined identifiers (this is intentional before cleanup).

**Step 3: Write minimal implementation**
- Remove these inputs from `services/trading_management/ea_inputs.mqh`:
  - `Base_Indicator_Period_Type`
  - `Base_Indicator_MA_Method`
  - `Strategy_Channel_Indicator_Type`
  - `Strategy_Channel_Indicator_Shift`
  - `Strategy_Global_Channel_Entry_Mode`
  - `Strategy_Global_Stoch_Entry_Mode`
  - `Alligator_Jaws_Period`
  - Entire non-structure inputs inside Base/Trend/Macro/Session groups (trend modes, entry eval, body volume, slope filters, channel MA, etc.).

- In `services/core/enums.mqh`, remove unused enums and helpers after refactor:
  - `BaseIndicatorPeriodTypes`, `IndicatorShiftTypes`, `ChannelIndicatorTypes`, `StrategyEntryChannelModes`, `StrategyGlobalStochEntryModes`, `StrategyTrendModes`, and the `EntryEvaluationUses*` helpers.
  - Keep only enums still referenced (support/resistance, trend structure, grid risk, etc.).

- Simplify `services/trading_management/strategy_structure_context.mqh`:
  - Remove `StrategyContextEntryEvaluation`, `StrategyContextTrendMode`, `StrategyContextIndicatorPercent`, `ResolveGlobalEntryTriggerMode`, `StrategyContextChannelFilterEnabled`, `StrategyContextBPercentSlopeEnabled`, `StrategyContextStochasticSlopeEnabled`, `StrategyContextAlligatorSlopeEnabled`, `StrategyContextBodyVolumeMode`.
  - Keep only structure-related helpers and `StrategyContextTimeframe` functions.

- Simplify `services/trading_signals/market_signal_state.mqh`:
  - Remove fields from `StrategyContextIndicators` that are no longer used (bpercent/alligator/stochastic/body_ma).
  - Remove `BANDS_PERCENT_*` constants if unused.

- Simplify `services/trading_signals/market_signal_indicators.mqh`:
  - `CaptureContextIndicators` should only load structure snapshot when required.
  - Remove bpercent/alligator/stochastic/body MA load branches.

- Simplify `services/trading_signals/market_signal_channel_guards.mqh`:
  - Remove `StrategyContextChannelMaFilterAllowsSignal` and related alligator MA filter logic.
  - Keep `ChannelGuardAllowsPendingSignal` if grid channel spacing remains (depends on Q2).

- Update `services/trading_signals/grid_channel_utils.mqh`:
  - Remove reliance on `Strategy_Channel_Indicator_Type`.
  - If keeping channels, map `ResolveEffectiveChannelStrategy()` to `Grid_Base_Strategy_Type` directly (or define a default channel type).

- Update `services/trading_signals/grid_order_helpers.mqh`:
  - Remove `GridResolveActiveRiskMode` branches referencing `Strategy_*_Trend_Mode` if those inputs are removed.
  - If alligator-based risk is removed, guard `Grid_Risk_Trend_Mode` to `GRID_RM_TREND_OFF` or return a safe default.

- Update `services/trading_signals/market_signal_detection.mqh` to remove references to removed filters (channel state, trend evaluation). Ensure the cascade uses only structure filters + fib entry.

- Update `services/trading_signals.mqh` to drop indicator includes that are no longer used (bands_percent, alligator, stochastic_indicator, body_ma) if all related logic removed.

**Step 4: Run test to verify it passes**
Run: compile `HFT_Grid_AI.mq5`.
Expected: PASS (0 errors).

**Step 5: Commit**
```bash
git add services/trading_management/ea_inputs.mqh services/core/enums.mqh \
  services/trading_management/strategy_structure_context.mqh \
  services/trading_management/indicator_definitions_loader.mqh \
  services/trading_signals/market_signal_state.mqh \
  services/trading_signals/market_signal_indicators.mqh \
  services/trading_signals/market_signal_channel_guards.mqh \
  services/trading_signals/grid_channel_utils.mqh \
  services/trading_signals/grid_order_helpers.mqh \
  services/trading_signals/market_signal_detection.mqh \
  services/trading_signals.mqh
git commit -m "refactor: remove legacy channel/alligator/stoch filters"
```

---

### Task 5: Align indicator loading to structure-only + safe fallbacks

**Files:**
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Modify: `services/trading_signals/grid_trend_risk_manager.mqh`
- Modify: `services/trading_management_strategies/grid_trend_risk_*.mqh`

**Step 1: Write the failing test**
Compile `HFT_Grid_AI.mq5` after removing indicator load branches to surface missing references.

**Step 2: Run test to verify it fails**
Expected: FAIL due to removed handles or functions still referenced by grid risk/trailing.

**Step 3: Write minimal implementation**
- In `indicator_definitions_loader.mqh`, keep only:
  - `PrepareStrategyTimeframes()`, `PrepareIndicatorPeriods()` (if still needed)
  - Structure indicator loaders (`LoadAllStructStochIndicators`) + any channel indicators still required for grid spacing (per Q2)
  - Remove alligator/bpercent/stoch/body MA loaders and related overlay logic

- In grid risk modules, guard alligator-dependent logic:
  - If `Grid_Risk_Trend_Mode` is set to an alligator-based mode, short-circuit with `GRID_RM_TREND_OFF` or log and skip.
  - Ensure `GridResolveAlligatorRiskReferencePrice` and similar functions are not called when alligator handles are absent.

**Step 4: Run test to verify it passes**
Run: compile `HFT_Grid_AI.mq5`.
Expected: PASS (0 errors).

**Step 5: Commit**
```bash
git add services/trading_management/indicator_definitions_loader.mqh \
  services/trading_signals/grid_trend_risk_manager.mqh \
  services/trading_management_strategies/grid_trend_risk_*.mqh
git commit -m "refactor: simplify indicator loading and risk fallbacks"
```

---

### Task 6: Manual smoke test (Strategy Tester)

**Files:**
- No code changes.

**Step 1: Run manual test**
- Attach `HFT_Grid_AI.mq5` to a chart or Strategy Tester.
- Set `Structure_Fibonacci_Levels` to default and test both `LEVELS_AS_LIMITS` and `LEVEL_AS_ZONE`.
- Confirm entry trigger logs and grid activation behave as expected when price moves into fib ranges.

**Step 2: Record results**
- Log whether entry triggers at expected fib ranges and whether limit/zone behavior matches the requirement.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-02-structure-fibonacci-entry-refactor.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch fresh subagent per task, review between tasks, fast iteration
2. Parallel Session (separate) - Open new session with executing-plans, batch execution with checkpoints

Which approach?
