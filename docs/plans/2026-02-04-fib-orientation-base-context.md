# Fibonacci Orientation + Base-Only Context Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align structure-based Fibonacci mapping to the last confirmed extremum pair, simplify strategy context to base-only, and convert the stochastic structure period input to an int with a minimum of 3.

**Architecture:** Use the last confirmed extremum pair (`os_market_structures[1]` + `[2]`) to derive the fib range and a `current_is_bottom` flag based on index `[2]`. All percent/price conversions use that orientation (no direction branching), and all signal evaluation uses the base context only. Inputs and indicator loading are simplified accordingly, while base structure filters remain active. @mql5-functional

**Tech Stack:** MQL5 (MT5), existing services include pipeline, MetaEditor compile + Strategy Tester/manual scripts.

---

**Summary**
- Update Fibonacci reference range and percent mapping to follow the last confirmed bottom/peak pair (indices `[1]` and `[2]`).
- Remove Trend/Macro/Session inputs and evaluation paths; base-only context remains with structure filters.
- Convert `Stoch_Structure_Period_Type` to `input int` with minimum of 3.

**Public API Changes**
- Input change: `Stoch_Structure_Period_Type` becomes `input int` with minimum 3.
- Input removals: `Trend_Strategy_Timeframe`, `Macro_Strategy_Timeframe`, `Session_Strategy_Timeframe`, and all Trend/Macro/Session context input groups.
- Signature changes:
  - `ResolveStructureReferenceRange(...)` adds `bool &current_is_bottom` and uses indices `[1]` and `[2]`.
  - `ResolveStructurePercentForPrice(...)` uses `current_is_bottom` instead of `direction`.
  - `ResolveStructurePriceForPercent(...)` uses `current_is_bottom` instead of `direction`.
  - `ResolveSignalStructureRange(...)` adds `bool &current_is_bottom`.
  - `ResolveFibonacciEntryPercent(...)` adds `bool &current_is_bottom`.
- Context evaluation order becomes base-only.

**Assumptions and Defaults**
- Use `os_market_structures[1]` (last confirmed opposite) and `[2]` (last confirmed same-type as current) for fib range.
- `current_is_bottom = !os_market_structures[2].is_peak`.
- `Stoch_Structure_Period_Type` default is `5`; any value `< 3` clamps to `3`.
- Base structure filters remain active; Trend/Macro/Session filters are removed with their input groups.
- Keep enums and `SignalParams` fields for non-base contexts for compatibility, but disable their evaluation.

**Decision**
- If fewer than 3 extrema are available, fib range resolution fails fast and skips fib logic until a confirmed pair exists.

**Tests and Scenarios**
- `tests/structure_fibonacci_orientation_test.mq5` (new): verifies 0%/100% mapping uses confirmed indices `[1]` and `[2]`.
- `tests/fibonacci_grid_percent_test.mq5`: ensure percent mapping works with grid helpers.
- `tests/structure_entry_trigger_test.mq5`: ensure structure entry still triggers.
- `tests/structure_snapshot_time_test.mq5`: ensure snapshot time resolution still works for base.
- `tests/context_base_only_test.mq5` (new): ensure only base context is enabled.
- Manual: set `Stoch_Structure_Period_Type = 1` and confirm logs show period `3`.

---

### Task 1: Fibonacci Orientation Mapping Using Confirmed Pair

**Files:**
- Create: `tests/structure_fibonacci_orientation_test.mq5`
- Modify: `services/trading_signals/market_signal_filters.mqh`
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/frontend/grid_visualization.mqh`

**Step 1: Write the failing test**
Create `tests/structure_fibonacci_orientation_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_signals/market_signal_filters.mqh"

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

void AssertMapping(const StochasticMarketStructure &s,
                   const double expected_bottom,
                   const double expected_peak,
                   string &errors)
{
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;

  if(!ResolveStructureReferenceRange(s, peak_price, bottom_price, current_is_bottom))
  {
    errors += "range failed\n";
    return;
  }

  double pct = 0.0;
  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, current_is_bottom, bottom_price, pct))
    errors += "bottom percent failed\n";
  else
    AssertClose("bottom pct", pct, expected_bottom, 0.1, errors);

  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, current_is_bottom, peak_price, pct))
    errors += "peak percent failed\n";
  else
    AssertClose("peak pct", pct, expected_peak, 0.1, errors);
}

void OnStart()
{
  string errors = "";

  // Current bottom (index 0), confirmed peak at [1], confirmed bottom at [2]
  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = 1.0900; // current, unconfirmed
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = 1.2000;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = 1.1000;
  AssertMapping(s_bottom, 100.0, 0.0, errors);

  // Current peak (index 0), confirmed bottom at [1], confirmed peak at [2]
  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100; // current, unconfirmed
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = 1.1000;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = 1.2000;
  AssertMapping(s_peak, 0.0, 100.0, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run: compile in MetaEditor or CLI
`MetaEditor64.exe /compile:"tests/structure_fibonacci_orientation_test.mq5" /log:"tests/structure_fibonacci_orientation_test.log"`
Expected: FAIL with wrong-parameter or missing function signature errors.

**Step 3: Write minimal implementation**
Update `services/trading_signals/market_signal_filters.mqh`:
```mq5
bool ResolveStructureReferenceRange(const StochasticMarketStructure &structure,
                                    double &peak_price,
                                    double &bottom_price,
                                    bool &current_is_bottom)
{
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  int total = ArraySize(structure.os_market_structures);
  if(total < 3)
    return false;

  bool first_is_peak = structure.os_market_structures[1].is_peak;
  bool second_is_peak = structure.os_market_structures[2].is_peak;
  if(first_is_peak == second_is_peak)
    return false;

  current_is_bottom = !second_is_peak;

  if(current_is_bottom)
  {
    peak_price   = structure.os_market_structures[1].extremum_high;
    bottom_price = structure.os_market_structures[2].extremum_low;
  }
  else
  {
    peak_price   = structure.os_market_structures[2].extremum_high;
    bottom_price = structure.os_market_structures[1].extremum_low;
  }

  return (peak_price > 0.0 && bottom_price > 0.0 && peak_price != bottom_price);
}

bool ResolveStructurePercentForPrice(const double peak_price,
                                     const double bottom_price,
                                     const bool current_is_bottom,
                                     const double price,
                                     double &percent_out)
{
  percent_out = 0.0;

  if(current_is_bottom)
    percent_out = GetFiboTrendBottomPercent(peak_price, bottom_price, price);
  else
    percent_out = GetFiboTrendPeakPercent(peak_price, bottom_price, price);

  return MathIsValidNumber(percent_out) && percent_out >= 0.0;
}

bool ResolveStructurePriceForPercent(const double peak_price,
                                     const double bottom_price,
                                     const bool current_is_bottom,
                                     const double percent,
                                     double &price_out)
{
  price_out = 0.0;

  if(current_is_bottom)
    price_out = GetFiboTrendBottomPrice(peak_price, bottom_price, percent);
  else
    price_out = GetFiboTrendPeakPrice(peak_price, bottom_price, percent);

  return price_out > 0.0;
}
```

Update `ResolveStructureFibonacciEntry` and other call sites to pass `current_is_bottom` instead of `direction` for percent/price mapping.

Update `services/trading_signals/grid_order_helpers.mqh`:
```mq5
bool ResolveSignalStructureRange(const SignalParams &signal_params,
                                 double &peak_price,
                                 double &bottom_price,
                                 bool &current_is_bottom)
{
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  StochasticMarketStructure structure;
  if(!ResolveSignalStructureSnapshot(signal_params, structure))
    return false;

  return ResolveStructureReferenceRange(structure, peak_price, bottom_price, current_is_bottom);
}

bool ResolveFibonacciEntryPercent(const SignalParams &signal_params,
                                  const double entry_price,
                                  double &entry_percent,
                                  double &peak_price,
                                  double &bottom_price,
                                  bool &current_is_bottom)
{
  entry_percent = 0.0;
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  if(entry_price <= 0.0)
    return false;

  if(!ResolveSignalStructureRange(signal_params, peak_price, bottom_price, current_is_bottom))
    return false;

  return ResolveStructurePercentForPrice(peak_price,
                                         bottom_price,
                                         current_is_bottom,
                                         entry_price,
                                         entry_percent);
}
```

Update `services/frontend/grid_visualization.mqh` to pass `current_is_bottom` when resolving entry level prices.

**Step 4: Run test to verify it passes**
Run:
- `MetaEditor64.exe /compile:"tests/structure_fibonacci_orientation_test.mq5" /log:"tests/structure_fibonacci_orientation_test.log"`
- `MetaEditor64.exe /compile:"tests/fibonacci_grid_percent_test.mq5" /log:"tests/fibonacci_grid_percent_test.log"`
Expected: PASS with no compile errors.

**Step 5: Commit**
```bash
git add tests/structure_fibonacci_orientation_test.mq5 \
  services/trading_signals/market_signal_filters.mqh \
  services/trading_signals/grid_order_helpers.mqh \
  services/frontend/grid_visualization.mqh
git commit -m "feat: use confirmed fib pair for structure mapping"
```

---

### Task 2: Inputs + Context API Cleanup (Base-Only + Stoch Period Int)

**Files:**
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/trading_management/strategy_structure_context.mqh`
- Create: `tests/context_base_only_test.mq5`

**Step 1: Write the test guard**
Create `tests/context_base_only_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"

void OnStart()
{
  string errors = "";

  if(!StrategyContextEnabled(CONTEXT_SLOT_BASE))
    errors += "base context disabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_TREND))
    errors += "trend context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_MACRO))
    errors += "macro context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_SESSION))
    errors += "session context enabled\n";

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run: compile in MetaEditor
`MetaEditor64.exe /compile:"tests/context_base_only_test.mq5" /log:"tests/context_base_only_test.log"`
Expected: PASS once refactor is applied; treat as a guard.

**Step 3: Write minimal implementation**
Update `services/core/enums.mqh` by deleting the `StochStructurePeriodTypes` enum block.

Update `services/trading_management/ea_inputs.mqh`:
```mq5
input group  "+= Strategy Context =+";
input ENUM_TIMEFRAMES           Strategy_Timeframe          = PERIOD_M1;
input int                       Stoch_Structure_Period_Type = 5;
input string                    Structure_Fibonacci_Levels = "23.6,38.2,50.0,61.8,78.6,100.0";
input StructureTriggerEntryModes Structure_Trigger_Entry   = LEVELS_AS_LIMITS;
input StrategyDirectionTypes    Strategy_Direction_Mode     = BOTH_DIRECTION;
input SignalConcurrencyModes    Signal_Concurrency_Mode     = SINGLE_RUNNING_SIGNAL;

input group "+= Strategy Base Context =+";
input TrendStructureFilterModes   Base_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Base_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input TrendStructureFilterModes   Base_Third_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Base_Fourth_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Base_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Base_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Base_Support_Retest_Min_Count     = 1;
input int                         Base_Resistance_Retest_Min_Count  = 1;
input int                         Base_Min_Extern_Structures_Broken = 0;
input bool                        Base_First_Structure_Close_Percent = false;
input bool                        Base_Fresh_Structure_Time         = false;
```
Delete the entire Trend/Macro/Session context groups.

Update `services/trading_management/strategy_structure_context.mqh` to disable non-base contexts and clamp period to `>= 3` (see plan in prior response).

**Step 4: Run test to verify it passes**
Run:
- `MetaEditor64.exe /compile:"tests/context_base_only_test.mq5" /log:"tests/context_base_only_test.log"`
- `MetaEditor64.exe /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"`
Expected: PASS, no missing symbol errors.

**Step 5: Commit**
```bash
git add services/core/enums.mqh \
  services/trading_management/ea_inputs.mqh \
  services/trading_management/strategy_structure_context.mqh \
  tests/context_base_only_test.mq5
git commit -m "refactor: base-only context inputs and int stoch period"
```

---

### Task 3: Base-Only Indicator Loading + Signal Pipeline

**Files:**
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Modify: `services/trading_signals/market_signal_indicators.mqh`
- Modify: `services/trading_signals/market_signal_detection.mqh`
- Modify: `services/trading_signals/market_signal_state.mqh`

**Step 1: Write a compile gate**
No new unit test; use compile checks for the EA and existing tests.

**Step 2: Run compile to verify it fails**
Run: `MetaEditor64.exe /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"`
Expected: FAIL until loader and indicator pipeline are simplified.

**Step 3: Write minimal implementation**
Update `services/trading_management/indicator_definitions_loader.mqh` to base-only by removing Trend/Macro/Session handles and loader logic (see plan in prior response for exact code). Ensure only `Strategy_Timeframe` is used.

Update `services/trading_signals/market_signal_indicators.mqh` to always load base snapshot and to ignore non-base contexts.

Update `services/trading_signals/market_signal_detection.mqh` to assign only base snapshot.

Update `services/trading_signals/market_signal_state.mqh` so `STRATEGY_CONTEXT_EVALUATION_ORDER` contains only `CONTEXT_SLOT_BASE`.

**Step 4: Run compile and key tests**
Run:
- `MetaEditor64.exe /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"`
- `MetaEditor64.exe /compile:"tests/structure_entry_trigger_test.mq5" /log:"tests/structure_entry_trigger_test.log"`
- `MetaEditor64.exe /compile:"tests/structure_snapshot_time_test.mq5" /log:"tests/structure_snapshot_time_test.log"`
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_management/indicator_definitions_loader.mqh \
  services/trading_signals/market_signal_indicators.mqh \
  services/trading_signals/market_signal_detection.mqh \
  services/trading_signals/market_signal_state.mqh
git commit -m "refactor: base-only context indicator loading and evaluation"
```
