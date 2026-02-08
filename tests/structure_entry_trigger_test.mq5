#property script_show_inputs
#include "../services/core/enums.mqh"
#include "../services/core/base_structures.mqh"
#include "../services/utils/array_functions.mqh"
#include "../services/utils/miscellaneous.mqh"
#include "../services/utils/broker_constraints_helper.mqh"
#include "../services/trading_management/ea_inputs.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/indicators/fibonacci_calculator.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

struct StrategyContextIndicators
{
  StrategyContextTypes      context;
  ENUM_TIMEFRAMES           timeframe;
  datetime                  bar_time;
  bool                      structure_valid;
  StochasticMarketStructure structure_data;

  StrategyContextIndicators()
  {
    context         = CONTEXT_SLOT_BASE;
    timeframe       = PERIOD_CURRENT;
    bar_time        = 0;
    structure_valid = false;
  }
};

double GridResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

datetime GetLastContextStructureTime(const StrategyContextTypes context,
                                     const SignalTypes direction)
{
  return 0;
}

SymbolTradingConstraints g_symbol_constraints;

#include "../services/trading_signals/market_signal_filters.mqh"

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
