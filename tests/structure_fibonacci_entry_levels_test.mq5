#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/ea_inputs.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
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

#include "../services/trading_signals/market_signal_filters.mqh"

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

double PriceForPercent(const StochasticMarketStructure &s, const double percent)
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

double PercentForPrice(const StochasticMarketStructure &s, const double price)
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

void OnStart()
{
  LoadStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  string errors = "";

  // Current bottom orientation
  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = 1.0900;
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = 1.2000;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = 1.1000;

  double close_price = PriceForPercent(s_bottom, 31.5);

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
    AssertClose("bottom/bull limit pct", PercentForPrice(s_bottom, entry_price), 38.2, 0.1, errors);
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
    AssertClose("bottom/bear limit pct", PercentForPrice(s_bottom, entry_price), 23.6, 0.1, errors);
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

  double outside_price = PriceForPercent(s_bottom, 150.0);
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

  // Current peak orientation
  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = 1.1000;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = 1.2000;

  close_price = PriceForPercent(s_peak, 31.5);

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
    AssertClose("peak/bull limit pct", PercentForPrice(s_peak, entry_price), 23.6, 0.1, errors);
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
    AssertClose("peak/bear limit pct", PercentForPrice(s_peak, entry_price), 38.2, 0.1, errors);
    if(!(entry_price > close_price))
      errors += "peak/bear entry not above close\n";
  }

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
