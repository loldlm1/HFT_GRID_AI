#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_ENTRY_TRIGGER_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_ENTRY_TRIGGER_MQH

#include "../framework.mqh"

bool RunTest_structure_entry_trigger_test(string &errors)
{
  errors = "";

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

  StrategyContextIndicators snapshot;
  snapshot.context = CONTEXT_SLOT_BASE;
  snapshot.timeframe = PERIOD_M1;
  snapshot.structure_valid = true;
  snapshot.structure_data = s;

  double entry_price = 0.0;
  bool in_zone = false;
  bool entry_is_limit = false;
  bool ok = ResolveStructureFibonacciEntry(snapshot,
                                           BULLISH,
                                           LEVELS_AS_LIMITS,
                                           entry_price,
                                           in_zone,
                                           entry_is_limit);

  if(!ok || !in_zone || !entry_is_limit)
    errors += "entry not triggered\n";

  return (errors == "");
}

#endif
