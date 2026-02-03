#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_signals/market_signal_filters.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

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
    Print("FAIL: entry not triggered");
  else
    Print("PASS");
}
