#ifndef HFT_GRID_AI_TEST_CASE_FIBONACCI_GRID_PERCENT_MQH
#define HFT_GRID_AI_TEST_CASE_FIBONACCI_GRID_PERCENT_MQH

#include "../framework.mqh"

bool FibonacciGridPercent_AssertClose(const string label,
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

bool FibonacciGridPercent_AssertMeaningfulEmission(const string label,
                                                   const double entry_price,
                                                   const double logical_next_price,
                                                   const double emitted_next_price,
                                                   const bool expect_below_entry,
                                                   string &errors)
{
  double point_size = GridResolvePointSizeSafe();
  double tolerance = point_size * 0.5;
  if(tolerance <= 0.0)
    tolerance = 0.00001;

  if(GridHasMeaningfulPriceGap(entry_price, logical_next_price))
  {
    if(MathAbs(emitted_next_price - logical_next_price) > tolerance)
      errors += label + " should match logical next price when gap is meaningful\n";
    return (errors == "");
  }

  if(!GridHasMeaningfulPriceGap(entry_price, emitted_next_price))
    errors += label + " should emit a meaningful fallback gap\n";

  if(expect_below_entry && !(emitted_next_price < entry_price))
    errors += label + " should stay below bullish entry\n";
  if(!expect_below_entry && !(emitted_next_price > entry_price))
    errors += label + " should stay above bearish entry\n";

  return (errors == "");
}

bool RunTest_fibonacci_grid_percent_test(string &errors)
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  // Use wide synthetic ranges so expectations are stable across symbols with
  // very different point sizes/digits (FX, metals, indices).
  double range_anchor = 10000.0;
  double range_span = 1000.0;
  double current_bottom = range_anchor + 500.0;
  double current_peak = range_anchor + range_span;

  StochasticMarketStructure s;
  ArrayResize(s.os_market_structures, 4);

  s.os_market_structures[0].is_peak = false;
  s.os_market_structures[0].extremum_low = current_bottom - 100.0;
  s.os_market_structures[1].is_peak = true;
  s.os_market_structures[1].extremum_high = current_peak;
  s.os_market_structures[2].is_peak = false;
  s.os_market_structures[2].extremum_low = current_bottom;
  s.os_market_structures[3].is_peak = true;
  s.os_market_structures[3].extremum_high = current_peak + 100.0;

  SignalParams signal;
  signal.signal_type = BULLISH;
  signal.strategy_context = CONTEXT_SLOT_BASE;
  signal.base_structure_valid = true;
  signal.base_structure_data = s;
  signal.entry_price = current_bottom;
  signal.grid_entry_reference_price = current_bottom;
  signal.fib_level_offset_steps = 1;

  errors = "";
  double entry_percent = 0.0;
  double range_lower = 0.0;
  double range_upper = 0.0;
  if(!ResolveFibonacciEntryRange(signal,
                                 signal.entry_price,
                                 entry_percent,
                                 range_lower,
                                 range_upper))
    errors += "entry range failed\n";

  FibonacciGridPercent_AssertClose("entry_percent", entry_percent, 100.0, 0.1, errors);
  FibonacciGridPercent_AssertClose("range_lower", range_lower, 100.0, 0.1, errors);
  FibonacciGridPercent_AssertClose("range_upper", range_upper, 121.4, 0.1, errors);

  double next_percent = 0.0;
  if(!ResolveFibonacciGridLevelPercent(signal, 0, next_percent))
    errors += "next percent failed\n";
  FibonacciGridPercent_AssertClose("next_percent", next_percent, 123.6, 0.1, errors);

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveSignalStructureRange(signal,
                                  peak_price,
                                  bottom_price,
                                  current_is_bottom))
    errors += "range failed\n";

  double bear_entry_price = 0.0;
  if(!ResolveStructurePriceForPercent(peak_price,
                                      bottom_price,
                                      current_is_bottom,
                                      23.6,
                                      bear_entry_price))
    errors += "bear entry price failed\n";

  SignalParams bear_signal = signal;
  bear_signal.signal_type = BEARISH;
  bear_signal.entry_price = bear_entry_price;
  bear_signal.grid_entry_reference_price = bear_entry_price;
  if(!ResolveFibonacciGridLevelPercent(bear_signal, 0, next_percent))
    errors += "bear next percent failed\n";
  FibonacciGridPercent_AssertClose("bear next percent", next_percent, 0.0, 0.1, errors);

  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = current_peak + 100.0;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = range_anchor;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = current_peak;

  SignalParams peak_signal = signal;
  peak_signal.signal_type = BULLISH;
  peak_signal.base_structure_data = s_peak;
  peak_signal.entry_price = range_anchor + 800.0;
  peak_signal.grid_entry_reference_price = range_anchor + 800.0;

  double peak_entry_percent = 0.0;
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;
  if(!ResolveFibonacciEntryPercent(peak_signal,
                                   peak_signal.entry_price,
                                   peak_entry_percent,
                                   peak_price,
                                   bottom_price,
                                   current_is_bottom))
    errors += "peak entry percent failed\n";

  if(!ResolveFibonacciGridLevelPercent(peak_signal, 0, next_percent))
    errors += "peak next percent failed\n";
  FibonacciGridPercent_AssertClose("peak bullish next percent", next_percent, 78.6, 0.1, errors);

  SetStructureCompoundFilterRuntime(COMPOUND_MODE_BREAKOUT_READY_BUY);
  LoadStructureFibonacciLevels("0.0,100.0",
                               "0.0,100.0");

  SignalParams breakout_signal = signal;
  breakout_signal.entry_is_limit = true;
  breakout_signal.entry_trigger_mode = LEVELS_AS_LIMITS;
  if(!ResolveFibonacciGridLevelPercent(breakout_signal, 0, next_percent))
    errors += "breakout next percent failed\n";
  FibonacciGridPercent_AssertClose("breakout anchored next percent", next_percent, 0.0, 0.1, errors);

  LoadStructureFibonacciLevels("0.0,61.8,100.0",
                               "0.0,61.8,100.0");

  SignalParams breakout_boundary_signal = signal;
  breakout_boundary_signal.signal_type = BULLISH;
  breakout_boundary_signal.entry_is_limit = true;
  breakout_boundary_signal.entry_trigger_mode = LEVELS_AS_LIMITS;
  breakout_boundary_signal.base_structure_data = s_peak;
  breakout_boundary_signal.fib_level_offset_steps = 1;

  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;
  if(!ResolveSignalStructureRange(breakout_boundary_signal,
                                  peak_price,
                                  bottom_price,
                                  current_is_bottom))
  {
    errors += "breakout boundary range failed\n";
  }
  else
  {
    double breakout_boundary_entry = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        100.0,
                                        breakout_boundary_entry))
    {
      errors += "breakout boundary entry price failed\n";
    }
    else
    {
      breakout_boundary_signal.entry_price = breakout_boundary_entry;
      breakout_boundary_signal.grid_entry_reference_price = breakout_boundary_entry;

      double level0 = 0.0;
      double level1 = 0.0;
      double level2 = 0.0;
      double level3 = 0.0;
      double level4 = 0.0;

      if(!ResolveFibonacciGridLevelPercent(breakout_boundary_signal, 0, level0))
        errors += "breakout boundary level0 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout boundary level0", level0, 61.8, 0.1, errors);

      if(!ResolveFibonacciGridLevelPercent(breakout_boundary_signal, 1, level1))
        errors += "breakout boundary level1 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout boundary level1", level1, 0.0, 0.1, errors);

      if(!ResolveFibonacciGridLevelPercent(breakout_boundary_signal, 2, level2))
        errors += "breakout boundary level2 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout boundary level2", level2, -61.8, 0.1, errors);

      if(!ResolveFibonacciGridLevelPercent(breakout_boundary_signal, 3, level3))
        errors += "breakout boundary level3 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout boundary level3", level3, -100.0, 0.1, errors);

      if(!ResolveFibonacciGridLevelPercent(breakout_boundary_signal, 4, level4))
        errors += "breakout boundary level4 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout boundary level4", level4, -161.8, 0.1, errors);

      if(MathAbs(level4 - level3) < 0.0001)
        errors += "breakout boundary level progression stalled\n";
    }
  }

  LoadStructureFibonacciLevels("-61.8,0.0,100.0,161.8",
                               "-61.8,0.0,100.0,161.8");

  SignalParams breakout_multi_signal = signal;
  breakout_multi_signal.signal_type = BULLISH;
  breakout_multi_signal.entry_is_limit = true;
  breakout_multi_signal.entry_trigger_mode = LEVELS_AS_LIMITS;
  breakout_multi_signal.base_structure_data = s_peak;

  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;
  if(!ResolveSignalStructureRange(breakout_multi_signal,
                                  peak_price,
                                  bottom_price,
                                  current_is_bottom))
  {
    errors += "breakout multi range failed\n";
  }
  else
  {
    double breakout_entry_price = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        100.0,
                                        breakout_entry_price))
    {
      errors += "breakout multi entry price failed\n";
    }
    else
    {
      breakout_multi_signal.entry_price = breakout_entry_price;
      breakout_multi_signal.grid_entry_reference_price = breakout_entry_price;
      breakout_multi_signal.fib_level_offset_steps = 1;

      if(!ResolveFibonacciGridLevelPercent(breakout_multi_signal, 0, next_percent))
        errors += "breakout multi level0 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout multi level0", next_percent, 0.0, 0.1, errors);

      if(!ResolveFibonacciGridLevelPercent(breakout_multi_signal, 1, next_percent))
        errors += "breakout multi level1 failed\n";
      else
        FibonacciGridPercent_AssertClose("breakout multi level1", next_percent, -61.8, 0.1, errors);
    }
  }

  ClearStructureCompoundFilterRuntimeOverride();

  SymbolTradingConstraints saved_constraints = g_symbol_constraints;
  g_symbol_constraints = SymbolTradingConstraints();
  g_symbol_constraints.point_size = 0.00001;
  g_symbol_constraints.tick_size = 0.00001;

  StochasticMarketStructure tight_range_structure;
  ArrayResize(tight_range_structure.os_market_structures, 3);
  tight_range_structure.os_market_structures[0].is_peak = false;
  tight_range_structure.os_market_structures[0].extremum_low = 1.09080;
  tight_range_structure.os_market_structures[1].is_peak = true;
  tight_range_structure.os_market_structures[1].extremum_high = 1.09262;
  tight_range_structure.os_market_structures[2].is_peak = false;
  tight_range_structure.os_market_structures[2].extremum_low = 1.09095;

  SignalParams tight_signal;
  tight_signal.signal_type = BULLISH;
  tight_signal.strategy_context = CONTEXT_SLOT_BASE;
  tight_signal.entry_trigger_mode = LEVELS_AS_LIMITS;
  tight_signal.entry_is_limit = true;
  tight_signal.base_structure_valid = true;
  tight_signal.base_structure_data = tight_range_structure;
  tight_signal.fib_level_offset_steps = 1;

  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;
  if(!ResolveSignalStructureRange(tight_signal,
                                  peak_price,
                                  bottom_price,
                                  current_is_bottom))
  {
    errors += "tight fib range failed\n";
  }
  else
  {
    double resolved_anchor_price = 0.0;
    double actual_entry_above_anchor = 0.0;
    double actual_entry_below_anchor = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        61.8,
                                        resolved_anchor_price))
    {
      errors += "tight fib resolved anchor price failed\n";
    }
    else if(!ResolveStructurePriceForPercent(peak_price,
                                             bottom_price,
                                             current_is_bottom,
                                             61.9,
                                             actual_entry_above_anchor))
    {
      errors += "tight fib actual entry above anchor price failed\n";
    }
    else if(!ResolveStructurePriceForPercent(peak_price,
                                             bottom_price,
                                             current_is_bottom,
                                             61.7,
                                             actual_entry_below_anchor))
    {
      errors += "tight fib actual entry below anchor price failed\n";
    }
    else
    {
      LoadStructureFibonacciLevels("0.0,61.8,100.0",
                                   "0.0,61.8,100.0");

      tight_signal.entry_price = actual_entry_above_anchor;
      tight_signal.grid_entry_reference_price = actual_entry_above_anchor;
      tight_signal.resolved_fibonacci_entry.valid = true;
      tight_signal.resolved_fibonacci_entry.percent = 61.8;
      tight_signal.resolved_fibonacci_entry.price = resolved_anchor_price;

      double next_percent = 0.0;
      if(!ResolveFibonacciGridLevelPercent(tight_signal, 0, next_percent))
      {
        errors += "default fib next percent from stored anchor failed\n";
      }
      else
      {
        FibonacciGridPercent_AssertClose("default fib next percent from stored anchor", next_percent, 100.0, 0.1, errors);
      }

      double logical_next_price = 0.0;
      double expected_next_price = 0.0;
      if(!ResolveStructurePriceForPercent(peak_price,
                                          bottom_price,
                                          current_is_bottom,
                                          100.0,
                                          expected_next_price))
      {
        errors += "default fib expected next price failed\n";
      }

      if(!ResolveFibonacciGridLevelPrice(tight_signal, 0, logical_next_price))
      {
        errors += "default fib next price from stored anchor failed\n";
      }
      else if(MathAbs(logical_next_price - expected_next_price) > 0.00001)
      {
        errors += StringFormat("default fib next price from stored anchor expected %.5f got %.5f\n",
                               expected_next_price,
                               logical_next_price);
      }

      GridOrderState default_state;
      default_state.level_index = 0;
      default_state.entry_reference_price = actual_entry_above_anchor;
      double emitted_next_price = GetGridNextLevelPrice(BULLISH,
                                                        tight_signal,
                                                        default_state);
      FibonacciGridPercent_AssertMeaningfulEmission("default fib emitted next price from stored anchor",
                                                    actual_entry_above_anchor,
                                                    logical_next_price,
                                                    emitted_next_price,
                                                    true,
                                                    errors);

      SignalParams rounded_down_signal = tight_signal;
      rounded_down_signal.entry_price = actual_entry_below_anchor;
      rounded_down_signal.grid_entry_reference_price = actual_entry_below_anchor;
      default_state.entry_reference_price = actual_entry_below_anchor;
      if(!ResolveFibonacciGridLevelPercent(rounded_down_signal, 0, next_percent))
      {
        errors += "default fib rounded-down next percent from stored anchor failed\n";
      }
      else
      {
        FibonacciGridPercent_AssertClose("default fib rounded-down next percent from stored anchor", next_percent, 100.0, 0.1, errors);
      }

      logical_next_price = 0.0;
      if(!ResolveFibonacciGridLevelPrice(rounded_down_signal, 0, logical_next_price))
      {
        errors += "default fib rounded-down next price from stored anchor failed\n";
      }
      else if(MathAbs(logical_next_price - expected_next_price) > 0.00001)
      {
        errors += StringFormat("default fib rounded-down next price from stored anchor expected %.5f got %.5f\n",
                               expected_next_price,
                               logical_next_price);
      }

      emitted_next_price = GetGridNextLevelPrice(BULLISH,
                                                 rounded_down_signal,
                                                 default_state);
      FibonacciGridPercent_AssertMeaningfulEmission("default fib rounded-down emitted next price from stored anchor",
                                                    actual_entry_below_anchor,
                                                    logical_next_price,
                                                    emitted_next_price,
                                                    true,
                                                    errors);

      LoadStructureFibonacciLevels("61.7,61.8,78.6,100.0",
                                   "61.7,61.8,78.6,100.0");

      tight_signal.entry_price = actual_entry_above_anchor;
      tight_signal.grid_entry_reference_price = actual_entry_above_anchor;
      default_state.entry_reference_price = actual_entry_above_anchor;
      next_percent = 0.0;
      if(!ResolveFibonacciGridLevelPercent(tight_signal, 0, next_percent))
      {
        errors += "tight fib band next percent from stored anchor failed\n";
      }
      else
      {
        FibonacciGridPercent_AssertClose("tight fib band next percent from stored anchor", next_percent, 78.6, 0.1, errors);
      }

      logical_next_price = 0.0;
      if(!ResolveFibonacciGridLevelPrice(tight_signal, 0, logical_next_price))
      {
        errors += "tight fib band next price from stored anchor failed\n";
      }
      else
      {
        double expected_tight_next_price = 0.0;
        if(!ResolveStructurePriceForPercent(peak_price,
                                            bottom_price,
                                            current_is_bottom,
                                            78.6,
                                            expected_tight_next_price))
        {
          errors += "tight fib expected next price failed\n";
        }
        else if(MathAbs(logical_next_price - expected_tight_next_price) > 0.00001)
        {
          errors += StringFormat("tight fib band next price from stored anchor expected %.5f got %.5f\n",
                                 expected_tight_next_price,
                                 logical_next_price);
        }

        emitted_next_price = GetGridNextLevelPrice(BULLISH,
                                                   tight_signal,
                                                   default_state);
        FibonacciGridPercent_AssertMeaningfulEmission("tight fib emitted next price from stored anchor",
                                                      actual_entry_above_anchor,
                                                      logical_next_price,
                                                      emitted_next_price,
                                                      true,
                                                      errors);
      }
    }
  }

  g_symbol_constraints = saved_constraints;
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  return (errors == "");
}

#endif
