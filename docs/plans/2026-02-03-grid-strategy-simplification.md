# Grid Strategy Simplification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove grid trend-risk and trailing features, trim base strategy types to ATR/POINTS/FIB_LEVEL_RANGE, and delete unused channel/alligator services while keeping grid behavior stable and fib-level driven.

**Architecture:** Keep the include chain intact and rely on existing structure snapshots to compute FIB_LEVEL_RANGE spacing from the configured `Structure_Fibonacci_Levels`. FIB_LEVEL_RANGE will compute each grid level from consecutive Fibonacci level percents (extended by the last step after the last configured level). Removing risk/trailing means no hedge, SAR, break-even, or trailing TP logic; exits stay via existing grid TP/final TP logic. Use @mql5-functional for MQL5 constraints.

**Tech Stack:** MQL5 EA, MetaTrader 5/MetaEditor64.exe (Wine), services/ include chain.

---

### Task 1: Remove Grid Trend Risk Strategy

**Files:**
- Create: `tests/no_grid_risk_strategy.sh`
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Modify: `services/trading_management_strategies.mqh`
- Modify: `services/trading_signals.mqh`
- Modify: `services/trading_signals/signal_params_struct.mqh`
- Modify: `services/trading_signals/grid_order_controller.mqh`
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/trading_signals/grid_order_lifecycle.mqh`
- Delete: `services/trading_signals/grid_trend_risk_manager.mqh`
- Delete: `services/trading_management_strategies/grid_risk_trend_strategy.mqh`
- Delete: `services/trading_management_strategies/grid_trend_risk_hedge.mqh`
- Delete: `services/trading_management_strategies/grid_trend_risk_breach.mqh`
- Delete: `services/trading_management_strategies/grid_trend_risk_sar.mqh`
- Delete: `services/trading_management_strategies/grid_trend_risk_modes.mqh`

**Step 1: Write the failing test**

Create `tests/no_grid_risk_strategy.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if rg -n "Grid_Risk_|GRID_RM_TREND|GridRiskTrend|hedge_|sar_" services; then
  echo "Risk strategy references still present"
  exit 1
fi

for f in \
  services/trading_signals/grid_trend_risk_manager.mqh \
  services/trading_management_strategies/grid_risk_trend_strategy.mqh \
  services/trading_management_strategies/grid_trend_risk_hedge.mqh \
  services/trading_management_strategies/grid_trend_risk_breach.mqh \
  services/trading_management_strategies/grid_trend_risk_sar.mqh \
  services/trading_management_strategies/grid_trend_risk_modes.mqh; do
  if [ -f "$f" ]; then
    echo "Risk strategy file still present: $f"
    exit 1
  fi
done

echo "OK"
```

**Step 2: Run test to verify it fails**

Run: `bash tests/no_grid_risk_strategy.sh`
Expected: FAIL with "Risk strategy references still present"

**Step 3: Write minimal implementation**

- Remove the entire input group `+= Grid Trend Risk Strategy =+` from `services/trading_management/ea_inputs.mqh`.
- Delete enums `GridRiskTrendModes`, `GridRiskAlligatorReferenceModes`, `GridRiskTrendTimeframeSources` from `services/core/enums.mqh`.
- Strip risk trend timeframe globals and resolvers from `services/trading_management/indicator_definitions_loader.mqh`:
  - Remove `Risk_Trend_Timeframe`.
  - Remove `ResolveRiskTrendSourceTimeframe` and `ResolveRiskTrendTimeframe`.
  - Remove `Risk_Trend_Timeframe = ResolveRiskTrendTimeframe();` in `LoadAllIndicatorDefinitions()`.
- Remove all grid risk includes from `services/trading_signals.mqh` and `services/trading_management_strategies.mqh`.
- Remove SAR/hedge fields from `SignalParams` and update its constructors/copy constructor in `services/trading_signals/signal_params_struct.mqh`:
  - `is_sar_signal`, `sar_cumulative_loss`, `hedge_position_ticket`, `hedge_entry_price`, `hedge_sl_active`, `hedge_sl_price`, `hedge_finalized`, `hedge_reset_done`.
- Remove risk hooks in `services/trading_signals/grid_order_controller.mqh`:
  - Delete calls to `GridEnsureSarSignalInitialized`, `GridApplyTrendRiskManagement`, `GridApplyTrendHedgeManagement`, `GridHedgeHandlePrevCloseOnNextLevel`.
- Remove hedge close logic from `services/trading_signals/grid_order_lifecycle.mqh` (the block that closes `hedge_position_ticket`).
- Remove any remaining `is_sar_signal` checks in `services/trading_signals/grid_order_helpers.mqh`.
- Delete the risk strategy files listed above.

**Step 4: Run test to verify it passes**

Run: `bash tests/no_grid_risk_strategy.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add tests/no_grid_risk_strategy.sh \
  services/trading_management/ea_inputs.mqh \
  services/core/enums.mqh \
  services/trading_management/indicator_definitions_loader.mqh \
  services/trading_management_strategies.mqh \
  services/trading_signals.mqh \
  services/trading_signals/signal_params_struct.mqh \
  services/trading_signals/grid_order_controller.mqh \
  services/trading_signals/grid_order_helpers.mqh \
  services/trading_signals/grid_order_lifecycle.mqh

git rm services/trading_signals/grid_trend_risk_manager.mqh \
  services/trading_management_strategies/grid_risk_trend_strategy.mqh \
  services/trading_management_strategies/grid_trend_risk_hedge.mqh \
  services/trading_management_strategies/grid_trend_risk_breach.mqh \
  services/trading_management_strategies/grid_trend_risk_sar.mqh \
  services/trading_management_strategies/grid_trend_risk_modes.mqh

git commit -m "refactor: remove grid trend risk strategy"
```

---

### Task 2: Remove Grid Trailing Strategy Settings (Trailing + Break-Even)

**Files:**
- Create: `tests/no_grid_trailing_strategy.sh`
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/indicator_definitions_loader.mqh`
- Modify: `services/trading_signals.mqh`
- Modify: `services/trading_signals/signal_params_struct.mqh`
- Modify: `services/trading_signals/grid_order_controller.mqh`
- Modify: `services/trading_signals/grid_order_lifecycle.mqh`
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/trading_signals/market_signal_cleanup.mqh`
- Modify: `services/frontend/grid_visualization.mqh`
- Delete: `services/trading_signals/grid_break_even_utils.mqh`

**Step 1: Write the failing test**

Create `tests/no_grid_trailing_strategy.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if rg -n "Grid_Trailing_|TrailingStrategy|TrailingExecution|BreakEven|GRID_ORDER_TP_TRAILING_ACTIVE" services; then
  echo "Trailing or break-even references still present"
  exit 1
fi

if [ -f services/trading_signals/grid_break_even_utils.mqh ]; then
  echo "Break-even util still present"
  exit 1
fi

echo "OK"
```

**Step 2: Run test to verify it fails**

Run: `bash tests/no_grid_trailing_strategy.sh`
Expected: FAIL with "Trailing or break-even references still present"

**Step 3: Write minimal implementation**

- Remove the entire input group `+= Grid Trailing Strategy Settings =+` from `services/trading_management/ea_inputs.mqh`.
  - If `Grid_TP_Percent` is still required for TP sizing, move it into `+= Grid Strategy Settings =+` (keep value and name, only change the group).
- Remove enums `BreakEvenModes`, `TrailingStrategyModes`, `TrailingExecutionModes` from `services/core/enums.mqh`.
- Remove trailing timeframe globals and resolvers from `services/trading_management/indicator_definitions_loader.mqh`:
  - Remove `Trailing_Indicator_Timeframe` and `ResolveTrailingStrategyTimeframe()`.
  - Remove `Trailing_Indicator_Timeframe = ResolveTrailingStrategyTimeframe();` in `LoadAllIndicatorDefinitions()`.
- Remove `grid_break_even_utils.mqh` include from `services/trading_signals.mqh` and delete the file.
- Remove trailing/break-even fields from `GridOrderState` in `services/trading_signals/signal_params_struct.mqh`:
  - `trailing_price`, `break_even_price`, `is_trailing_active`, `tp_reached`, `break_even_active`, `partial_take_executed`.
- Remove trailing/break-even handling from `services/trading_signals/grid_order_controller.mqh`:
  - Delete `GridShouldActivateTrailing`, `UpdateTrailingTP`, and break-even processing.
  - Replace trailing start with a direct TP exit (assumption): when `take_profit_price` is reached, close the grid and log `LEVEL_TP_HIT`.
- Remove trailing logic helpers from `services/trading_signals/grid_order_lifecycle.mqh` and `services/trading_signals/grid_order_helpers.mqh`:
  - Delete `GridShouldActivateTrailing`, `UpdateTrailingTP`, `GridResolveTrailingStrategyPrice`.
  - Remove any references to `GRID_ORDER_TP_TRAILING_ACTIVE`.
- Update `services/trading_signals/market_signal_cleanup.mqh` and `services/frontend/grid_visualization.mqh` to remove TP trailing and break-even objects/lines.
- Remove `GRID_ORDER_TP_TRAILING_ACTIVE` from `GridOrderStatuses` in `services/core/enums.mqh` if no longer referenced.

**Step 4: Run test to verify it passes**

Run: `bash tests/no_grid_trailing_strategy.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add tests/no_grid_trailing_strategy.sh \
  services/trading_management/ea_inputs.mqh \
  services/core/enums.mqh \
  services/trading_management/indicator_definitions_loader.mqh \
  services/trading_signals.mqh \
  services/trading_signals/signal_params_struct.mqh \
  services/trading_signals/grid_order_controller.mqh \
  services/trading_signals/grid_order_lifecycle.mqh \
  services/trading_signals/grid_order_helpers.mqh \
  services/trading_signals/market_signal_cleanup.mqh \
  services/frontend/grid_visualization.mqh

git rm services/trading_signals/grid_break_even_utils.mqh

git commit -m "refactor: remove grid trailing and break-even"
```

---

### Task 3: Add FIB_LEVEL_RANGE Base Strategy

**Files:**
- Modify: `services/core/enums.mqh`
- Modify: `services/trading_management/ea_inputs.mqh`
- Modify: `services/trading_management/strategy_structure_context.mqh`
- Modify: `services/trading_signals/market_signal_indicators.mqh`
- Modify: `services/trading_management/structure_fibonacci_levels.mqh`
- Modify: `services/trading_signals/grid_planner.mqh`
- Modify: `services/trading_signals/grid_order_helpers.mqh`
- Modify: `services/trading_signals/signal_params_struct.mqh`
- Test: `tests/fib_level_range_spacing_test.mq5`

**Step 1: Write the failing test**

Create `tests/fib_level_range_spacing_test.mq5`:

```mq5
#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"
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

void OnStart()
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  double next = 0.0;
  string errors = "";

  // Entry percent inside 23.6-38.2 should resolve next to 38.2
  if(!ResolveFibonacciNextPercent(g_structure_fibo_config.levels,
                                  ArraySize(g_structure_fibo_config.levels),
                                  30.0,
                                  1,
                                  next))
    errors += "ResolveFibonacciNextPercent failed\n";
  AssertClose("next", next, 38.2, 0.01, errors);

  // Step beyond last level should extend by last step (100-78.6 = 21.4)
  if(!ResolveFibonacciNextPercent(g_structure_fibo_config.levels,
                                  ArraySize(g_structure_fibo_config.levels),
                                  110.0,
                                  1,
                                  next))
    errors += "ResolveFibonacciNextPercent extension failed\n";
  AssertClose("next_ext", next, 121.4, 0.01, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
```

**Step 2: Run test to verify it fails**

Run (syntax compile):

```bash
wine "MetaEditor64.exe" /s /compile:"tests/fib_level_range_spacing_test.mq5" /log:"tests/fib_level_range_spacing_test.log"
```

Expected: FAIL with missing symbol `ResolveFibonacciNextPercent`.

**Step 3: Write minimal implementation**

- Update `GridBaseStrategyTypes` in `services/core/enums.mqh` to only:
  - `ATR_RANGE`, `POINTS_RANGE`, `FIB_LEVEL_RANGE`.
- Add helpers in `services/trading_management/structure_fibonacci_levels.mqh`:

```mq5
bool ResolveFibonacciNextPercent(const double &levels[],
                                 const int total,
                                 const double percent,
                                 const int steps,
                                 double &next_out)
{
  next_out = 0.0;
  if(total < 2 || steps <= 0)
    return false;

  double cursor = percent;
  double lower = 0.0;
  double upper = 0.0;
  for(int i = 0; i < steps; i++)
  {
    if(!ResolveFibonacciRangeForPercent(levels, total, cursor, lower, upper))
      return false;
    cursor = upper;
  }

  next_out = cursor;
  return true;
}
```

- Require structure when using FIB_LEVEL_RANGE:
  - `services/trading_management/strategy_structure_context.mqh`:
    - Replace `Grid_Base_Strategy_Type == STOCH_STRUCTURE_RANGE` with `Grid_Base_Strategy_Type == FIB_LEVEL_RANGE`.
  - `services/trading_signals/market_signal_indicators.mqh`:
    - Same change for `require_structure`.
- Update `services/trading_signals/grid_planner.mqh` to allow FIB_LEVEL_RANGE:
  - In `CalculateBaseGridContext`, map base strategy to `POINTS_RANGE`, `ATR_RANGE`, or `FIB_LEVEL_RANGE` only.
  - For `FIB_LEVEL_RANGE`, compute `distance_points` via a new helper that uses structure snapshots + fib levels.
- Add a fib-level distance helper in `services/trading_signals/grid_order_helpers.mqh`:

```mq5
bool ResolveFibonacciGridDistancePoints(const SignalParams &signal_params,
                                        const double entry_reference_price,
                                        const int level_index,
                                        double &distance_points)
{
  distance_points = 0.0;
  if(!g_structure_fibo_config.valid)
    return false;

  StochasticMarketStructure stoch;
  bool structure_valid = false;
  switch(signal_params.strategy_context)
  {
    case CONTEXT_SLOT_TREND:
      structure_valid = signal_params.trend_structure_valid;
      stoch = signal_params.trend_structure_data;
      break;
    case CONTEXT_SLOT_MACRO:
      structure_valid = signal_params.macro_structure_valid;
      stoch = signal_params.macro_structure_data;
      break;
    case CONTEXT_SLOT_SESSION:
      structure_valid = signal_params.session_structure_valid;
      stoch = signal_params.session_structure_data;
      break;
    case CONTEXT_SLOT_BASE:
    default:
      structure_valid = signal_params.base_structure_valid;
      stoch = signal_params.base_structure_data;
      break;
  }

  if(!structure_valid)
    return false;

  double peak = 0.0;
  double bottom = 0.0;
  if(!ResolveStructureReferenceRange(stoch, peak, bottom))
    return false;

  double entry_percent = 0.0;
  if(!ResolveStructurePercentForPrice(peak, bottom, signal_params.signal_type,
                                      entry_reference_price, entry_percent))
    return false;

  double next_percent = 0.0;
  if(!ResolveFibonacciNextPercent(g_structure_fibo_config.levels,
                                  ArraySize(g_structure_fibo_config.levels),
                                  entry_percent,
                                  level_index + 1,
                                  next_percent))
    return false;

  double next_price = 0.0;
  if(!ResolveStructurePriceForPercent(peak, bottom, signal_params.signal_type,
                                      next_percent, next_price))
    return false;

  double point_size = GridResolvePointSizeSafe();
  if(point_size <= 0.0)
    return false;

  distance_points = MathAbs(next_price - entry_reference_price) / point_size;
  return distance_points > 0.0;
}
```

- Update `ComputeLevelDistancePoints` in `services/trading_signals/grid_order_helpers.mqh`:
  - If `Grid_Base_Strategy_Type == FIB_LEVEL_RANGE`, call `ResolveFibonacciGridDistancePoints`.
- Update `services/trading_signals/signal_params_struct.mqh` only if you need to store fib entry metadata; otherwise keep unchanged.

**Step 4: Run test to verify it passes**

```bash
wine "MetaEditor64.exe" /s /compile:"tests/fib_level_range_spacing_test.mq5" /log:"tests/fib_level_range_spacing_test.log"
```

Expected: PASS with log showing 0 errors.

**Step 5: Commit**

```bash
git add services/core/enums.mqh \
  services/trading_management/ea_inputs.mqh \
  services/trading_management/structure_fibonacci_levels.mqh \
  services/trading_management/strategy_structure_context.mqh \
  services/trading_signals/market_signal_indicators.mqh \
  services/trading_signals/grid_planner.mqh \
  services/trading_signals/grid_order_helpers.mqh \
  tests/fib_level_range_spacing_test.mq5

git commit -m "feat: add fib level range grid strategy"
```

---

### Task 4: Remove Unused Channel/Alligator Services

**Files:**
- Create: `tests/no_channel_alligator.sh`
- Delete: `services/trading_signals/grid_channel_utils.mqh`
- Delete: `services/trading_signals/market_signal_channel_guards.mqh`
- Delete: `services/indicators/alligator_indicator.mqh`
- Delete: `services/indicators/bands_percent_indicator.mqh`
- Delete: `services/indicators/body_ma_indicator.mqh`
- Delete: `services/indicators/stochastic_indicator.mqh`

**Step 1: Write the failing test**

Create `tests/no_channel_alligator.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if rg -n "CHANNEL_INDICATOR_RANGE|alligator|bands_percent|body_ma" services; then
  echo "Channel/alligator references still present"
  exit 1
fi

for f in \
  services/trading_signals/grid_channel_utils.mqh \
  services/trading_signals/market_signal_channel_guards.mqh \
  services/indicators/alligator_indicator.mqh \
  services/indicators/bands_percent_indicator.mqh \
  services/indicators/body_ma_indicator.mqh \
  services/indicators/stochastic_indicator.mqh; do
  if [ -f "$f" ]; then
    echo "Unused file still present: $f"
    exit 1
  fi
done

echo "OK"
```

**Step 2: Run test to verify it fails**

Run: `bash tests/no_channel_alligator.sh`
Expected: FAIL with "Channel/alligator references still present"

**Step 3: Write minimal implementation**

- Delete the unused files listed above.
- Ensure no includes reference them (the risk/trailing cleanup should already remove most includes).

**Step 4: Run test to verify it passes**

Run: `bash tests/no_channel_alligator.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add tests/no_channel_alligator.sh

git rm services/trading_signals/grid_channel_utils.mqh \
  services/trading_signals/market_signal_channel_guards.mqh \
  services/indicators/alligator_indicator.mqh \
  services/indicators/bands_percent_indicator.mqh \
  services/indicators/body_ma_indicator.mqh \
  services/indicators/stochastic_indicator.mqh

git commit -m "chore: remove unused channel and alligator services"
```

---

### Task 5: Compile and Sanity Check

**Files:**
- Verify: `HFT_Grid_AI.mq5`
- Verify: `tests/*.mq5`

**Step 1: Write the failing test**

Run the compile before fixes (expected to fail if any missing symbols remain):

```bash
wine "MetaEditor64.exe" /s /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_syntax.log"
```

**Step 2: Run test to verify it fails**

Expected: FAIL if any missing symbol remains.

**Step 3: Write minimal implementation**

Fix any remaining compile errors (missing includes, removed enums, or dangling references). Keep the include chain in `AGENTS.md` intact.

**Step 4: Run test to verify it passes**

```bash
wine "MetaEditor64.exe" /s /compile:"HFT_Grid_AI.mq5" /log:"HFT_Grid_AI_syntax.log"
```

Expected: PASS with 0 errors and 0 warnings.

**Step 5: Commit**

```bash
git add HFT_Grid_AI_syntax.log

git commit -m "chore: compile after grid strategy cleanup"
```
