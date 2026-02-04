# Fibonacci Grid Labels + Limit Expiry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show Fibonacci percent labels on ENTRY/NEXT grid lines (including precise entry percent for `LEVEL_AS_ZONE`) and expire `LEVELS_AS_LIMITS` signals when a newer structure snapshot appears.

**Architecture:** Add Fibonacci percent resolution helpers in `services/trading_signals/grid_order_helpers.mqh`, then format labels in `services/frontend/grid_visualization.mqh` using lightweight formatting helpers in `services/frontend/grid_visual_utils.mqh`. Implement a structure-change expiry check in `services/trading_signals/grid_order_lifecycle.mqh` and call it early in `UpdateGridLifecycle`. @mql5-functional

**Tech Stack:** MQL5 (MT5), existing services include pipeline, MetaEditor compile + Strategy Tester scripts.

---

### Task 1: Fibonacci Percent Resolution Helpers + Tests

**Files:**
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Create: `tests/fibonacci_grid_percent_test.mq5`

**Step 1: Write the failing test**

```mq5
#property script_show_inputs
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include "../services/trading_tools.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"
#include "../services/trading_signals/market_signal_state.mqh"
#include "../services/trading_signals/market_signal_filters.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"
#include "../services/trading_signals/grid_order_helpers.mqh"

CTrade g_position;
CAccountInfo g_account;
CSymbolInfo g_symbol;
double g_bid = 0.0;
double g_ask = 0.0;
double g_decimal_digits = 1.0;
double g_points_spread = 0.0;
double g_local_spread = 0.0;
int g_magic_number = 0;
string g_dataset_id = "";
bool g_ea_running = false;
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

void OnStart()
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

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

  SignalParams signal;
  signal.signal_type = BULLISH;
  signal.strategy_context = CONTEXT_SLOT_BASE;
  signal.base_structure_valid = true;
  signal.base_structure_data = s;
  signal.entry_price = 1.1500;
  signal.grid_entry_reference_price = 1.1500;
  signal.fib_level_offset_steps = 1;

  string errors = "";
  double entry_percent = 0.0;
  double range_lower = 0.0;
  double range_upper = 0.0;
  if(!ResolveFibonacciEntryRange(signal,
                                 signal.entry_price,
                                 entry_percent,
                                 range_lower,
                                 range_upper))
    errors += "entry range failed\n";

  AssertClose("entry_percent", entry_percent, 50.0, 0.1, errors);
  AssertClose("range_lower", range_lower, 50.0, 0.1, errors);
  AssertClose("range_upper", range_upper, 61.8, 0.1, errors);

  double next_percent = 0.0;
  if(!ResolveFibonacciGridLevelPercent(signal, 0, next_percent))
    errors += "next percent failed\n";
  AssertClose("next_percent", next_percent, 61.8, 0.1, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**

Run (Windows):
```
MetaEditor64.exe /compile:"tests/fibonacci_grid_percent_test.mq5" /log:"HFT_Grid_AI_build.log"
```

Run (Linux/Wine):
```
wine "MetaEditor64.exe" /compile:"tests/fibonacci_grid_percent_test.mq5" /log:"HFT_Grid_AI_build.log"
```

Expected: FAIL with undefined `ResolveFibonacciEntryRange` / `ResolveFibonacciGridLevelPercent`.

**Step 3: Write minimal implementation**

Add to `services/trading_signals/grid_order_helpers.mqh`:

```mq5
bool ResolveFibonacciEntryRange(const SignalParams &signal_params,
                                const double entry_price,
                                double &entry_percent_out,
                                double &range_lower_out,
                                double &range_upper_out)
{
  entry_percent_out = 0.0;
  range_lower_out = 0.0;
  range_upper_out = 0.0;

  if(!g_structure_fibo_config.valid)
    return false;

  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  if(!ResolveFibonacciEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price))
    return false;

  double lower = 0.0;
  double upper = 0.0;
  if(!ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                      ArraySize(g_structure_fibo_config.levels),
                                      entry_percent,
                                      lower,
                                      upper))
    return false;

  entry_percent_out = entry_percent;
  range_lower_out = lower;
  range_upper_out = upper;
  return true;
}

bool ResolveFibonacciGridLevelPercent(const SignalParams &signal_params,
                                      const int level_index,
                                      double &level_percent_out)
{
  level_percent_out = 0.0;

  if(!g_structure_fibo_config.valid)
    return false;

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.grid_entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  if(!ResolveFibonacciEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price))
    return false;

  int steps = signal_params.fib_level_offset_steps + level_index;
  if(steps <= 0)
    steps = 1;

  double level_percent = 0.0;
  if(!ResolveFibonacciNextPercent(g_structure_fibo_config.levels,
                                  ArraySize(g_structure_fibo_config.levels),
                                  entry_percent,
                                  steps,
                                  level_percent))
    return false;

  level_percent_out = level_percent;
  return true;
}
```

**Step 4: Run test to verify it passes**

Run the same compile command as Step 2.

Expected: PASS.

**Step 5: Commit**

```bash
git add services/trading_signals/grid_order_helpers.mqh tests/fibonacci_grid_percent_test.mq5
git commit -m "feat: add fibonacci percent helpers for grid labels"
```

---

### Task 2: Label Formatting + DrawGridLevels Update

**Files:**
- Modify: `services/frontend/grid_visual_utils.mqh`
- Modify: `services/frontend/grid_visualization.mqh`
- Create: `tests/grid_visual_label_format_test.mq5`

**Step 1: Write the failing test**

```mq5
#property script_show_inputs
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"
#include "../services/frontend/grid_visual_utils.mqh"

double g_bid = 1.0;
double g_ask = 1.0;

void OnStart()
{
  string errors = "";
  string entry = FormatFibEntryLabel("BULLISH ENTRY", 61.8, true, 59.32);
  if(entry != "BULLISH ENTRY 61.8% (59.32%)")
    errors += "entry label mismatch\n";

  string next = FormatFibNextLabel("BULLISH NEXT", 78.6, 1, 0.12);
  if(next != "BULLISH NEXT 78.6% L1 lot=0.12")
    errors += "next label mismatch\n";

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**

Compile the script; expect undefined formatting helpers.

**Step 3: Implement formatting helpers**

Add to `services/frontend/grid_visual_utils.mqh`:

```mq5
string FormatFibEntryLabel(const string base_label,
                           const double entry_level_percent,
                           const bool include_actual,
                           const double actual_percent)
{
  if(include_actual)
    return StringFormat("%s %.1f%% (%.2f%%)",
                        base_label,
                        entry_level_percent,
                        actual_percent);

  return StringFormat("%s %.1f%%",
                      base_label,
                      entry_level_percent);
}

string FormatFibNextLabel(const string base_label,
                          const double next_level_percent,
                          const int level_index,
                          const double lot_size)
{
  return StringFormat("%s %.1f%% L%d lot=%.2f",
                      base_label,
                      next_level_percent,
                      level_index,
                      lot_size);
}
```

**Step 4: Update DrawGridLevels**

Update `services/frontend/grid_visualization.mqh` to compute entry/next percents and format labels. Keep the TP label unchanged.

**Step 5: Run tests**

Compile:
- `tests/fibonacci_grid_percent_test.mq5`
- `tests/grid_visual_label_format_test.mq5`

Expected: PASS.

**Step 6: Commit**

```bash
git add services/frontend/grid_visual_utils.mqh services/frontend/grid_visualization.mqh tests/grid_visual_label_format_test.mq5
git commit -m "feat: show fib percents on grid chart labels"
```

---

### Task 3: Limit Signal Expiry on Structure Change

**Files:**
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/trading_signals/grid_order_lifecycle.mqh`
- Modify: `services/trading_signals/grid_order_controller.mqh`
- Create: `tests/structure_snapshot_time_test.mq5`

**Step 1: Write the failing test**

```mq5
#property script_show_inputs
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include "../services/trading_tools.mqh"
#include "../services/trading_management/ea_inputs.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_signals/market_signal_state.mqh"
#include "../services/trading_signals/market_signal_filters.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"
#include "../services/trading_signals/grid_order_helpers.mqh"

CTrade g_position;
CAccountInfo g_account;
CSymbolInfo g_symbol;
double g_bid = 0.0;
double g_ask = 0.0;
double g_decimal_digits = 1.0;
double g_points_spread = 0.0;
double g_local_spread = 0.0;
int g_magic_number = 0;
string g_dataset_id = "";
bool g_ea_running = false;
SymbolTradingConstraints g_symbol_constraints;

void OnStart()
{
  StochasticMarketStructure s;
  s.first_structure_time = D'2026.02.03 00:00';
  s.second_structure_time = D'2026.02.03 01:00';

  datetime resolved = 0;
  if(!ResolveStructureSnapshotTimeForContext(CONTEXT_SLOT_BASE, s, resolved))
  {
    Print("FAIL: resolve snapshot time");
    return;
  }

  if(resolved != s.second_structure_time)
    Print("FAIL: expected second structure time");
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**

Compile the script; expect undefined `ResolveStructureSnapshotTimeForContext`.

**Step 3: Implement helpers**

Add to `services/trading_signals/grid_order_helpers.mqh`:

```mq5
bool ResolveStructureSnapshotTimeForContext(const StrategyContextTypes context,
                                            const StochasticMarketStructure &structure,
                                            datetime &time_out)
{
  time_out = 0;

  StrategyStructureLayerContext ctx = BuildStructureLayerForContext(context);
  datetime resolved = ResolveStructureSnapshotTimestamp(structure, ctx);
  if(resolved <= 0)
    return false;

  time_out = resolved;
  return true;
}
```

Add to `services/trading_signals/grid_order_lifecycle.mqh`:

```mq5
bool LimitSignalExpiredOnStructureChange(const SignalParams &signal_params)
{
  if(!signal_params.entry_is_limit)
    return false;

  if(GridSignalHasExecutedLevel(signal_params))
    return false;

  StochasticMarketStructure entry_structure;
  if(!ResolveSignalStructureSnapshot(signal_params, entry_structure))
    return false;

  datetime entry_time = 0;
  if(!ResolveStructureSnapshotTimeForContext(signal_params.strategy_context,
                                             entry_structure,
                                             entry_time))
    return false;

  StochasticMarketStructure current_structure;
  if(!LoadContextStructureSnapshot(signal_params.strategy_context, current_structure))
    return false;

  datetime current_time = 0;
  if(!ResolveStructureSnapshotTimeForContext(signal_params.strategy_context,
                                             current_structure,
                                             current_time))
    return false;

  return (current_time > entry_time);
}
```

**Step 4: Wire into lifecycle**

Modify `services/trading_signals/grid_order_controller.mqh` in `UpdateGridLifecycle`:

```mq5
  if(LimitSignalExpiredOnStructureChange(signal_params))
  {
    signal_params.signal_state = CLOSED;
    GridLogEvent("LIMIT_EXPIRED_STRUCTURE", signal_params, grid_order);
    return;
  }
```

**Step 5: Run tests and compile EA**

Compile:
- `tests/structure_snapshot_time_test.mq5`
- `tests/fibonacci_grid_percent_test.mq5`
- `tests/grid_visual_label_format_test.mq5`

Then compile EA (Windows):
```
MetaEditor64.exe /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"
```

Or (Linux/Wine):
```
wine "MetaEditor64.exe" /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_build.log"
```

Expected: PASS.

**Step 6: Commit**

```bash
git add services/trading_signals/grid_order_helpers.mqh services/trading_signals/grid_order_lifecycle.mqh services/trading_signals/grid_order_controller.mqh tests/structure_snapshot_time_test.mq5
git commit -m "feat: expire limit signals on structure change"
```
