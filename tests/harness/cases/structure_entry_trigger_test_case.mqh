#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_ENTRY_TRIGGER_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_ENTRY_TRIGGER_MQH

#include "../framework.mqh"

bool RunTest_structure_entry_trigger_test(string &errors)
{
  errors = "";
  ClearStructureTouchPolicyState();
  SetStructureTouchPolicyRuntime(ALLOW_RETEST);

  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  StochasticMarketStructure s;
  ArrayResize(s.os_market_structures, 4);

  // Keep a wide range so broker-distance checks expressed in points are
  // satisfied across symbols with large point sizes (e.g. XAUUSD, US30).
  double range_anchor = 10000.0;
  double range_span = 1000.0;
  double current_bottom = range_anchor + 500.0;
  double current_peak = range_anchor + range_span;

  s.os_market_structures[0].is_peak = false;
  s.os_market_structures[0].extremum_low = current_bottom - 100.0;
  s.os_market_structures[1].is_peak = true;
  s.os_market_structures[1].extremum_high = current_peak;
  s.os_market_structures[2].is_peak = false;
  s.os_market_structures[2].extremum_low = current_bottom;
  s.os_market_structures[3].is_peak = true;
  s.os_market_structures[3].extremum_high = current_peak + 100.0;

  StrategyContextIndicators snapshot;
  snapshot.context = CONTEXT_SLOT_BASE;
  snapshot.timeframe = PERIOD_M1;
  snapshot.structure_valid = true;
  snapshot.structure_data = s;

  double peak = 0.0;
  double bottom = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(snapshot.structure_data, peak, bottom, current_is_bottom))
  {
    errors += "reference range unavailable\n";
    return false;
  }

  double close_price = GetFiboTrendBottomPrice(peak, bottom, 31.5);
  double low_price = close_price;
  double high_price = close_price;

  double entry_price = 0.0;
  bool in_zone = false;
  bool entry_is_limit = false;
  bool ok = ResolveStructureFibonacciEntryForPrices(snapshot.structure_data,
                                                    close_price,
                                                    low_price,
                                                    high_price,
                                                    BULLISH,
                                                    LEVELS_AS_LIMITS,
                                                    entry_price,
                                                    in_zone,
                                                    entry_is_limit);

  if(!ok || !in_zone || !entry_is_limit)
    errors += "entry not triggered\n";

  ok = ResolveStructureFibonacciEntryForPrices(snapshot.structure_data,
                                               close_price,
                                               low_price,
                                               high_price,
                                               BEARISH,
                                               LEVELS_AS_LIMITS,
                                               entry_price,
                                               in_zone,
                                               entry_is_limit);

  if(!ok)
    errors += "mismatch resolve failed\n";
  else if(in_zone)
    errors += "mismatch direction should not trigger\n";

  ClearStructureTouchPolicyRuntimeOverride();
  ClearStructureTouchPolicyState();
  return (errors == "");
}

#endif
