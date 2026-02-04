#property script_show_inputs
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include "../services/trading_tools.mqh"
#include "../services/trading_management/ea_inputs.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"

struct StrategyContextIndicators
{
  StrategyContextTypes     context;
  ENUM_TIMEFRAMES          timeframe;
  datetime                 bar_time;
  bool                     structure_valid;
  StochasticMarketStructure structure_data;

  StrategyContextIndicators()
  {
    context           = CONTEXT_SLOT_BASE;
    timeframe         = PERIOD_CURRENT;
    bar_time          = 0;
    structure_valid   = false;
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
#include "../services/trading_signals/grid_order_helpers.mqh"

CTrade g_position;
CAccountInfo g_account;
CSymbolInfo g_symbol;
double g_bid = 0.0;
double g_ask = 0.0;
double g_decimal_digits = 1.0;
double g_points_spread = 0.0;
double g_local_spread = 0.0;
int g_magic_number = 0;
string g_dataset_id = "";
bool g_ea_running = false;
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

  SignalParams signal;
  signal.signal_type = BULLISH;
  signal.strategy_context = CONTEXT_SLOT_BASE;
  signal.base_structure_valid = true;
  signal.base_structure_data = s;
  signal.entry_price = 1.1500;
  signal.grid_entry_reference_price = 1.1500;
  signal.fib_level_offset_steps = 1;

  string errors = "";
  double entry_percent = 0.0;
  double range_lower = 0.0;
  double range_upper = 0.0;
  if(!ResolveFibonacciEntryRange(signal,
                                 signal.entry_price,
                                 entry_percent,
                                 range_lower,
                                 range_upper))
    errors += "entry range failed\n";

  AssertClose("entry_percent", entry_percent, 100.0, 0.1, errors);
  AssertClose("range_lower", range_lower, 100.0, 0.1, errors);
  AssertClose("range_upper", range_upper, 121.4, 0.1, errors);

  double next_percent = 0.0;
  if(!ResolveFibonacciGridLevelPercent(signal, 0, next_percent))
    errors += "next percent failed\n";
  AssertClose("next_percent", next_percent, 123.6, 0.1, errors);

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
  AssertClose("bear next percent", next_percent, 0.0, 0.1, errors);

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
  AssertClose("peak bullish next percent", next_percent, 78.6, 0.1, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
