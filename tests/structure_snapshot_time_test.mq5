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

void OnStart()
{
  StochasticMarketStructure s;
  s.first_structure_time = D'2026.02.03 00:00';
  s.second_structure_time = D'2026.02.03 01:00';

  datetime resolved = 0;
  if(!ResolveStructureSnapshotTimeForContext(CONTEXT_SLOT_BASE, s, resolved))
  {
    Print("FAIL: resolve snapshot time");
    return;
  }

  if(resolved != s.second_structure_time)
    Print("FAIL: expected second structure time");
  else
    Print("PASS");
}
