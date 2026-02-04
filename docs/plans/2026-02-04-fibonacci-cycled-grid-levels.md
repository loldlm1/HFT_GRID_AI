# Fibonacci Cycled Grid Levels Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend Fibonacci grid spacing to reuse configured levels cyclically beyond the range, with direction-aware stepping, implicit 0/100 pairing when either is present (grid extensions only), and visible negative percent labels; entry triggers remain strict to configured levels.

**Architecture:** Normalize a cycle-level list at load time (inject 0/100 if either is present) and store it alongside parsed levels. Add a cycled stepper that walks the normalized list forward/backward and can extend into negative space while skipping 0 when it’s not allowed. Use the stepper in grid level percent/price/base-distance calculations, with step direction derived from signal side + structure orientation. Entry gating continues to use strict range checks on the original configured levels. @mql5-functional

**Tech Stack:** MQL5 (MT5), existing services include pipeline, MetaEditor compile + script tests.

---

## Decisions (Feb 4, 2026)
- 0.0 and 100.0 should be implicitly paired **only** when either is present in `Structure_Fibonacci_Levels`.
- 0/100 are for **grid extensions only**, not for entry triggers.
- If the list does **not** include 0/100, the cycle must **wrap without outputting 0**.
- Negative percent labels should be displayed in the UI (raw values acceptable).
- Structure mapping remains anchored to 0/100 at extrema even if the user provides custom levels (e.g., 48.5,161.8,250.0).

---

## Proposed Logic (Summary)
- Use `Structure_Fibonacci_Levels` as the repeating template for grid spacing.
- Build `cycle_levels[]` from the configured list:
  - If the list includes **0** or **100**, ensure **both 0 and 100 are present** in `cycle_levels` (for grid extension only).
  - Otherwise, keep the list unchanged (no implicit 0/100).
- **Upward cycling** (toward larger percent): `... 78.6, 100, 123.6, 138.2, 150.0, 161.8, 178.6, 200.0 ...` (adds `max_level` each cycle).
- **Downward cycling** (toward smaller percent): `... 100, 78.6, 61.8, 50, 38.2, 23.6, 0, -23.6, -38.2, -50, -61.8, -78.6, -100, -123.6 ...` when 0/100 are allowed; otherwise skip 0 and continue to the next valid level.
- Direction for grid spacing uses adverse move logic:
  - `BULLISH`: step **down in price** → percent increases if `current_is_bottom`, else decreases.
  - `BEARISH`: step **up in price** → percent decreases if `current_is_bottom`, else increases.

## Limitations / Notes
- Assumes `Structure_Fibonacci_Levels` are positive and ascending after parsing.
- Negative percent values are allowed for **grid spacing only** (extensions beyond peak/bottom).
- Entry triggers remain strict to configured levels; no new entry ranges are introduced.
- Negative labels display is already supported by formatting; a guard test ensures the sign is preserved.

---

### Task 1: Normalize Cycle Levels + Robust Cycled Step Tests

**Files:**
- Modify: `services/trading_management/structure_fibonacci_levels.mqh`
- Create: `tests/fibonacci_cycled_levels_cases_test.mq5`

**Step 1: Write the failing test**
Create `tests/fibonacci_cycled_levels_cases_test.mq5`:
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

void RunCase(const string label,
             const string csv,
             const double start_percent,
             const int steps,
             const int direction,
             const double expected,
             string &errors)
{
  double levels[];
  string err = "";
  if(!ParseStructureFibonacciLevels(csv, levels, err))
  {
    errors += StringFormat("%s parse failed: %s\n", label, err);
    return;
  }

  double next = 0.0;
  if(!ResolveFibonacciNextPercentCycled(levels, ArraySize(levels), start_percent, steps, direction, next))
  {
    errors += StringFormat("%s cycle failed\n", label);
    return;
  }

  AssertClose(label, next, expected, 0.1, errors);
}

void OnStart()
{
  string errors = "";

  // Standard list (100 present => implicit 0)
  RunCase("std up from 100",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          100.0, 1, 1, 123.6, errors);
  RunCase("std up step6 from 100",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          100.0, 6, 1, 200.0, errors);
  RunCase("std down from 23.6",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          23.6, 1, -1, 0.0, errors);
  RunCase("std down step2 from 23.6",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          23.6, 2, -1, -23.6, errors);
  RunCase("std up from -23.6",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          -23.6, 1, 1, 0.0, errors);
  RunCase("std up step2 from -23.6",
          "23.6,38.2,50.0,61.8,78.6,100.0",
          -23.6, 2, 1, 23.6, errors);

  // List with 0 but missing 100 => implicit 100
  RunCase("implicit 100 up from 78.6",
          "0.0,23.6,38.2,78.6",
          78.6, 1, 1, 100.0, errors);
  RunCase("implicit 100 up from 100",
          "0.0,23.6,38.2,78.6",
          100.0, 1, 1, 123.6, errors);
  RunCase("implicit 100 down from 0",
          "0.0,23.6,38.2,78.6",
          0.0, 1, -1, -23.6, errors);

  // List with 100 but missing 0 => implicit 0
  RunCase("implicit 0 down from 23.6",
          "23.6,50.0,100.0",
          23.6, 1, -1, 0.0, errors);

  // Custom list without 0/100 (no implicit pairing, skip 0)
  RunCase("custom up from 250",
          "48.5,161.8,250.0",
          250.0, 1, 1, 298.5, errors);
  RunCase("custom down from 48.5 skip 0",
          "48.5,161.8,250.0",
          48.5, 1, -1, -48.5, errors);
  RunCase("custom down step2",
          "48.5,161.8,250.0",
          48.5, 2, -1, -161.8, errors);
  RunCase("custom down step3",
          "48.5,161.8,250.0",
          48.5, 3, -1, -250.0, errors);
  RunCase("custom up from -48.5",
          "48.5,161.8,250.0",
          -48.5, 1, 1, 48.5, errors);

  // Unsorted + duplicate list
  RunCase("unsorted duplicate up",
          "100.0,38.2,23.6,38.2",
          100.0, 1, 1, 123.6, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/fibonacci_cycled_levels_cases_test.mq5" /log:"tests/fibonacci_cycled_levels_cases_test.log"
```
Expected: FAIL with `ResolveFibonacciNextPercentCycled` undefined.

**Step 3: Write minimal implementation**
Update `services/trading_management/structure_fibonacci_levels.mqh`:
```mq5
struct StructureFibonacciConfig
{
  double levels[];
  double cycle_levels[];
  double last_step;
  bool   valid;
  bool   cycle_valid;
  bool   cycle_allow_zero;

  StructureFibonacciConfig()
  {
    ArrayResize(levels, 0);
    ArrayResize(cycle_levels, 0);
    last_step = 0.0;
    valid = false;
    cycle_valid = false;
    cycle_allow_zero = false;
  }
};

bool HasLevelValue(const double &levels[], const int total, const double value)
{
  for(int i = 0; i < total; i++)
  {
    if(MathAbs(levels[i] - value) < 0.0001)
      return true;
  }
  return false;
}

bool BuildCycleLevels(const double &levels[],
                      const int total,
                      double &cycle_out[],
                      bool &allow_zero_out)
{
  ArrayResize(cycle_out, 0);
  allow_zero_out = false;
  if(total < 2)
    return false;

  double tmp[];
  ArrayCopy(tmp, levels);
  int tmp_total = ArraySize(tmp);
  bool has_zero = HasLevelValue(tmp, tmp_total, 0.0);
  bool has_hundred = HasLevelValue(tmp, tmp_total, 100.0);

  allow_zero_out = (has_zero || has_hundred);
  if(allow_zero_out)
  {
    if(!has_zero)
      AddElementToArray(tmp, 0.0);
    if(!has_hundred)
      AddElementToArray(tmp, 100.0);
  }

  ArraySort(tmp);

  double deduped[];
  for(int i = 0; i < ArraySize(tmp); i++)
  {
    double value = tmp[i];
    if(ArraySize(deduped) == 0 || value > deduped[ArraySize(deduped) - 1])
      AddElementToArray(deduped, value);
  }

  ArrayCopy(cycle_out, deduped);
  return (ArraySize(cycle_out) >= 2);
}

bool ResolveFibonacciNextPercentCycledUp(const double &levels[],
                                         const int total,
                                         const double percent,
                                         double &next_out)
{
  if(total < 2)
    return false;

  double max_level = levels[total - 1];
  if(max_level <= 0.0)
    return false;

  if(percent < 0.0)
  {
    double abs_value = MathAbs(percent);
    if(abs_value <= levels[0])
    {
      next_out = 0.0;
      return true;
    }

    double prev = levels[0];
    for(int i = 1; i < total; i++)
    {
      if(levels[i] >= abs_value)
        break;
      prev = levels[i];
    }

    next_out = -prev;
    return true;
  }

  double base = MathFloor(percent / max_level) * max_level;
  double cursor = percent - base;

  for(int i = 0; i < total; i++)
  {
    if(levels[i] > cursor)
    {
      next_out = base + levels[i];
      return true;
    }
  }

  next_out = base + max_level + levels[0];
  return true;
}

bool ResolveFibonacciNextPercentCycledDown(const double &levels[],
                                           const int total,
                                           const double percent,
                                           double &next_out)
{
  if(total < 2)
    return false;

  double max_level = levels[total - 1];
  if(max_level <= 0.0)
    return false;

  if(percent <= 0.0)
  {
    double abs_value = MathAbs(percent);
    if(abs_value < 0.0000001)
    {
      int first_positive = 0;
      while(first_positive < total && levels[first_positive] <= 0.0)
        first_positive++;
      if(first_positive >= total)
        return false;
      next_out = -levels[first_positive];
      return true;
    }

    double base = MathFloor(abs_value / max_level) * max_level;
    double cursor = abs_value - base;
    if(cursor < 0.0000001)
    {
      next_out = -(base + levels[0]);
      return true;
    }

    for(int i = 0; i < total; i++)
    {
      if(levels[i] > cursor)
      {
        next_out = -(base + levels[i]);
        return true;
      }
    }

    next_out = -(base + max_level + levels[0]);
    return true;
  }

  double base = MathFloor(percent / max_level) * max_level;
  double cursor = percent - base;
  if(cursor < 0.0000001)
  {
    base -= max_level;
    cursor = max_level;
  }

  if(cursor <= levels[0])
  {
    next_out = base;
    return true;
  }

  double prev = levels[0];
  for(int i = 1; i < total; i++)
  {
    if(levels[i] >= cursor)
      break;
    prev = levels[i];
  }

  next_out = base + prev;
  return true;
}

bool ResolveFibonacciNextPercentCycledWithCycle(const double &cycle_levels[],
                                                const int total,
                                                const bool allow_zero,
                                                const double percent,
                                                const int steps,
                                                const int direction,
                                                double &next_out)
{
  next_out = 0.0;
  if(total < 2 || steps <= 0)
    return false;

  int step_dir = (direction < 0) ? -1 : 1;
  double cursor = percent;
  for(int i = 0; i < steps; i++)
  {
    if(step_dir > 0)
    {
      if(!ResolveFibonacciNextPercentCycledUp(cycle_levels, total, cursor, cursor))
        return false;
    }
    else
    {
      if(!ResolveFibonacciNextPercentCycledDown(cycle_levels, total, cursor, cursor))
        return false;
    }

    if(!allow_zero && MathAbs(cursor) < 0.0000001)
    {
      if(step_dir > 0)
      {
        if(!ResolveFibonacciNextPercentCycledUp(cycle_levels, total, cursor, cursor))
          return false;
      }
      else
      {
        if(!ResolveFibonacciNextPercentCycledDown(cycle_levels, total, cursor, cursor))
          return false;
      }
    }
  }

  next_out = cursor;
  return true;
}

bool ResolveFibonacciNextPercentCycled(const double &levels[],
                                       const int total,
                                       const double percent,
                                       const int steps,
                                       const int direction,
                                       double &next_out)
{
  next_out = 0.0;
  double cycle_levels[];
  bool allow_zero = false;
  if(!BuildCycleLevels(levels, total, cycle_levels, allow_zero))
    return false;

  return ResolveFibonacciNextPercentCycledWithCycle(cycle_levels,
                                                    ArraySize(cycle_levels),
                                                    allow_zero,
                                                    percent,
                                                    steps,
                                                    direction,
                                                    next_out);
}
```

Update `LoadStructureFibonacciLevels` to populate cycle levels:
```mq5
  ArrayResize(g_structure_fibo_config.levels, 0);
  ArrayCopy(g_structure_fibo_config.levels, parsed);
  int total = ArraySize(g_structure_fibo_config.levels);
  g_structure_fibo_config.last_step = g_structure_fibo_config.levels[total - 1] -
                                      g_structure_fibo_config.levels[total - 2];
  g_structure_fibo_config.valid = (total >= 2 && g_structure_fibo_config.last_step > 0.0);

  g_structure_fibo_config.cycle_valid = BuildCycleLevels(g_structure_fibo_config.levels,
                                                         total,
                                                         g_structure_fibo_config.cycle_levels,
                                                         g_structure_fibo_config.cycle_allow_zero);
  return g_structure_fibo_config.valid && g_structure_fibo_config.cycle_valid;
```

**Step 4: Run test to verify it passes**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/fibonacci_cycled_levels_cases_test.mq5" /log:"tests/fibonacci_cycled_levels_cases_test.log"
```
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_management/structure_fibonacci_levels.mqh \
  tests/fibonacci_cycled_levels_cases_test.mq5
git commit -m "feat: add cycled fibonacci stepping with implicit 0/100 pairing"
```

---

### Task 2: Direction-Aware Cycling in Grid Spacing + Multi-Context Tests

**Files:**
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `tests/fibonacci_grid_percent_test.mq5`

**Step 1: Write the failing test**
Update `tests/fibonacci_grid_percent_test.mq5` to cover bullish/bearish and bottom/peak orientations:
```mq5
  double next_percent = 0.0;
  if(!ResolveFibonacciGridLevelPercent(signal, 0, next_percent))
    errors += "next percent failed\n";
  AssertClose("next_percent", next_percent, 123.6, 0.1, errors);

  // Bearish case at 23.6 (current bottom orientation)
  double peak = 0.0;
  double bottom = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(s, peak, bottom, current_is_bottom))
    errors += "range failed\n";
  double bear_entry_price = 0.0;
  if(!ResolveStructurePriceForPercent(peak, bottom, current_is_bottom, 23.6, bear_entry_price))
    errors += "bear entry price failed\n";

  SignalParams bear_signal = signal;
  bear_signal.signal_type = BEARISH;
  bear_signal.entry_price = bear_entry_price;
  bear_signal.grid_entry_reference_price = bear_entry_price;
  if(!ResolveFibonacciGridLevelPercent(bear_signal, 0, next_percent))
    errors += "bear next percent failed\n";
  AssertClose("bear next percent", next_percent, 0.0, 0.1, errors);

  // Peak orientation (current_is_bottom = false)
  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = 1.1000;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = 1.2000;

  SignalParams peak_signal = signal;
  peak_signal.signal_type = BULLISH;
  peak_signal.base_structure_data = s_peak;
  peak_signal.entry_price = 1.1800;
  peak_signal.grid_entry_reference_price = 1.1800;
  if(!ResolveFibonacciGridLevelPercent(peak_signal, 0, next_percent))
    errors += "peak next percent failed\n";
  // When current_is_bottom=false, bullish should step down in percent
  if(next_percent >= 100.0)
    errors += "peak bullish step direction wrong\n";
```

**Step 2: Run test to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/fibonacci_grid_percent_test.mq5" /log:"tests/fibonacci_grid_percent_test.log"
```
Expected: FAIL until grid helpers use cycled, direction-aware stepping.

**Step 3: Write minimal implementation**
Update `services/trading_signals/grid_order_helpers.mqh`:
```mq5
int ResolveFibonacciStepDirection(const SignalTypes signal_type,
                                  const bool current_is_bottom)
{
  if(signal_type == BULLISH)
    return current_is_bottom ? 1 : -1;
  if(signal_type == BEARISH)
    return current_is_bottom ? -1 : 1;
  return 1;
}
```

Replace `ResolveFibonacciNextPercent` calls with the cycled variant using the prebuilt cycle levels:
```mq5
  int step_dir = ResolveFibonacciStepDirection(signal_params.signal_type, current_is_bottom);
  if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                 ArraySize(g_structure_fibo_config.cycle_levels),
                                                 g_structure_fibo_config.cycle_allow_zero,
                                                 entry_percent,
                                                 steps,
                                                 step_dir,
                                                 level_percent))
    return false;
```
Apply the same change in:
- `ResolveFibonacciGridLevelPrice`
- `ResolveFibonacciGridBaseDistance`

**Step 4: Run tests to verify they pass**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/fibonacci_cycled_levels_cases_test.mq5" /log:"tests/fibonacci_cycled_levels_cases_test.log"
"MetaEditor64.exe" /compile:"tests/fibonacci_grid_percent_test.mq5" /log:"tests/fibonacci_grid_percent_test.log"
```
Expected: PASS.

**Step 5: Commit**
```bash
git add services/trading_signals/grid_order_helpers.mqh \
  tests/fibonacci_grid_percent_test.mq5
git commit -m "fix: cycle fib grid levels by direction and orientation"
```

---

### Task 3: UI Negative Label Guard

**Files:**
- Create: `tests/fibonacci_negative_label_test.mq5`

**Step 1: Write the failing test**
Create `tests/fibonacci_negative_label_test.mq5`:
```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"
#include "../services/frontend/grid_visual_utils.mqh"

void OnStart()
{
  SignalParams signal;
  string label = GridSignalLineLabel(signal, "NEXT");
  string formatted = FormatFibNextLabel(label, -23.6, 1, 0.01);
  if(StringFind(formatted, "-23.6") < 0)
    Print("FAIL: negative label missing");
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**
Run:
```bash
"MetaEditor64.exe" /compile:"tests/fibonacci_negative_label_test.mq5" /log:"tests/fibonacci_negative_label_test.log"
```
Expected: PASS (guard only).

**Step 3: Commit**
```bash
git add tests/fibonacci_negative_label_test.mq5
git commit -m "test: guard negative fib label formatting"
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
- Attach EA with default inputs.
- Test a current bottom case and confirm:
  - Bullish limit placed at the upper boundary in range (e.g., 38.2).
  - Bearish limit placed at the lower boundary (e.g., 23.6).
  - Next grid level for bearish side progresses to `0.0` then negative levels.
  - Negative labels are visible in chart annotations.
- Test a custom list **without** 0/100 (e.g., `48.5,161.8,250.0`):
  - Confirm next levels wrap without ever outputting 0.

**Step 2: Record results**
- Log symbol, timestamp, and screenshots if any unexpected behavior persists.

---

## Open Questions
- None.
