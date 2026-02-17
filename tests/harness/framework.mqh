#ifndef HFT_GRID_AI_TESTS_HARNESS_FRAMEWORK_MQH
#define HFT_GRID_AI_TESTS_HARNESS_FRAMEWORK_MQH

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

#include "../../services/core/enums.mqh"
#include "../../services/core/base_structures.mqh"
#include "../../services/utils/array_functions.mqh"
#include "../../services/utils/miscellaneous.mqh"
#include "../../services/utils/money_functions.mqh"
#include "../../services/utils/broker_constraints_helper.mqh"
#include "../../services/trading_management/ea_inputs.mqh"
#include "../../services/trading_management/candle_structure_filter_context.mqh"
#include "../../services/trading_management/strategy_structure_context.mqh"
#include "../../services/indicators/stochastic_market_indicator.mqh"
#include "../../services/indicators/fibonacci_calculator.mqh"
#include "../../services/trading_management/structure_fibonacci_levels.mqh"
#include "../../services/trading_signals/signal_params_struct.mqh"
#include "../../services/trading_signals/signal_lot_strategy.mqh"
#include "../../services/trading_signals/structure_compound_modes.mqh"
#include "../../services/frontend/grid_visual_utils.mqh"

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

#include "../../services/trading_signals/market_signal_filters.mqh"
#include "../../services/trading_signals/grid_order_helpers.mqh"
#include "../../services/trading_signals/grid_order_math.mqh"

#endif
