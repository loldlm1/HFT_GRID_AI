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

  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = 1.0900;
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = 1.2000;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = 1.1000;
  AssertMapping(s_bottom, 100.0, 0.0, errors);

  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100;
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
