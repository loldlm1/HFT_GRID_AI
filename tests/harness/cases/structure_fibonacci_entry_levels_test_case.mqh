#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ENTRY_LEVELS_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ENTRY_LEVELS_MQH

#include "../framework.mqh"

bool EntryLevels_AssertClose(const string label,
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

double EntryLevels_PriceForPercent(const StochasticMarketStructure &s, const double percent)
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

double EntryLevels_PercentForPrice(const StochasticMarketStructure &s, const double price)
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

bool RunTest_structure_fibonacci_entry_levels_test(string &errors)
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  errors = "";

  // Keep wide ranges so point-based minimum-range checks remain symbol-agnostic.
  double range_anchor = 10000.0;
  double range_span = 1000.0;
  double current_bottom = range_anchor;
  double current_peak = range_anchor + range_span;

  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = current_bottom - 100.0;
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = current_peak;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = current_bottom;

  double close_price = EntryLevels_PriceForPercent(s_bottom, 31.5);

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
    EntryLevels_AssertClose("bottom/bull limit pct", EntryLevels_PercentForPrice(s_bottom, entry_price), 38.2, 0.1, errors);
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
    EntryLevels_AssertClose("bottom/bear limit pct", EntryLevels_PercentForPrice(s_bottom, entry_price), 23.6, 0.1, errors);
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

  double outside_price = EntryLevels_PriceForPercent(s_bottom, 150.0);
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

  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = current_peak + 100.0;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = current_bottom;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = current_peak;

  close_price = EntryLevels_PriceForPercent(s_peak, 31.5);

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
    EntryLevels_AssertClose("peak/bull limit pct", EntryLevels_PercentForPrice(s_peak, entry_price), 23.6, 0.1, errors);
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
    EntryLevels_AssertClose("peak/bear limit pct", EntryLevels_PercentForPrice(s_peak, entry_price), 38.2, 0.1, errors);
    if(!(entry_price > close_price))
      errors += "peak/bear entry not above close\n";
  }

  // Scoped guard: block terminal limit bands that require extrapolated stop anchors.
  ClearStructureLimitTerminalBandGuardRuntimeOverride();
  ClearStructureCompoundFilterRuntimeOverride();
  LoadStructureFibonacciLevels("0.0,61.8,100.0",
                               "0.0,61.8,100.0");

  SetStructureLimitTerminalBandGuardRuntime(true);

  double first_band_price = EntryLevels_PriceForPercent(s_bottom, 30.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              first_band_price,
                                              first_band_price,
                                              first_band_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "terminal guard first band resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "terminal guard should allow first band\n";
  }

  double terminal_band_price = EntryLevels_PriceForPercent(s_bottom, 80.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              terminal_band_price,
                                              terminal_band_price,
                                              terminal_band_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "terminal guard terminal band resolve failed\n";
  }
  else if(in_zone)
  {
    errors += "terminal guard should block terminal band\n";
  }

  ClearStructureLimitTerminalBandGuardRuntimeOverride();
  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              terminal_band_price,
                                              terminal_band_price,
                                              terminal_band_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "terminal guard control resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "terminal guard control should keep legacy behavior\n";
  }

  // Breakout limit anchoring bypasses terminal-band blocking so 0/100 works as
  // dynamic endpoint setup.
  SetStructureCompoundFilterRuntime(COMPOUND_MODE_BREAKOUT_READY_BUY);
  LoadStructureFibonacciLevels("0.0,100.0",
                               "0.0,100.0");
  SetStructureLimitTerminalBandGuardRuntime(true);
  if(!ResolveStructureFibonacciEntryForPrices(s_bottom,
                                              terminal_band_price,
                                              terminal_band_price,
                                              terminal_band_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "breakout terminal guard resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "breakout terminal guard should allow entry\n";
  }

  // Breakout + dynamic levels anchors bullish entries to the upper endpoint of
  // the active band.
  LoadStructureFibonacciLevels("-61.8,0.0,100.0,161.8",
                               "-61.8,0.0,100.0,161.8");

  double breakout_mid_price = EntryLevels_PriceForPercent(s_peak, 70.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_peak,
                                              breakout_mid_price,
                                              breakout_mid_price,
                                              breakout_mid_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "breakout dynamic first band resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "breakout dynamic first band should allow entry\n";
  }
  else
  {
    EntryLevels_AssertClose("breakout dynamic first band entry pct",
                            EntryLevels_PercentForPrice(s_peak, entry_price),
                            100.0,
                            0.1,
                            errors);
  }

  double breakout_upper_price = EntryLevels_PriceForPercent(s_peak, 130.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_peak,
                                              breakout_upper_price,
                                              breakout_upper_price,
                                              breakout_upper_price,
                                              BULLISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "breakout dynamic upper band resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "breakout dynamic upper band should allow entry\n";
  }
  else
  {
    EntryLevels_AssertClose("breakout dynamic upper band entry pct",
                            EntryLevels_PercentForPrice(s_peak, entry_price),
                            161.8,
                            0.1,
                            errors);
  }

  SetStructureCompoundFilterRuntime(COMPOUND_MODE_BREAKOUT_READY_SELL);
  double breakout_sell_mid_price = EntryLevels_PriceForPercent(s_peak, 70.0);
  if(!ResolveStructureFibonacciEntryForPrices(s_peak,
                                              breakout_sell_mid_price,
                                              breakout_sell_mid_price,
                                              breakout_sell_mid_price,
                                              BEARISH,
                                              LEVELS_AS_LIMITS,
                                              entry_price,
                                              in_zone,
                                              entry_is_limit))
  {
    errors += "breakout dynamic bearish resolve failed\n";
  }
  else if(!in_zone || !entry_is_limit)
  {
    errors += "breakout dynamic bearish should allow entry\n";
  }
  else
  {
    EntryLevels_AssertClose("breakout dynamic bearish entry pct",
                            EntryLevels_PercentForPrice(s_peak, entry_price),
                            0.0,
                            0.1,
                            errors);
  }

  ClearStructureCompoundFilterRuntimeOverride();
  ClearStructureLimitTerminalBandGuardRuntimeOverride();

  return (errors == "");
}

#endif
