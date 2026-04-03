#ifndef HFT_GRID_AI_TESTS_HARNESS_FRAMEWORK_MQH
#define HFT_GRID_AI_TESTS_HARNESS_FRAMEWORK_MQH

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

#include "../../services/core/enums.mqh"
#include "../../services/core/base_structures.mqh"
#include "../../services/shared/license_guard_v1/core/addon_catalog.mqh"
#include "../../services/utils/array_functions.mqh"
#include "../../services/utils/miscellaneous.mqh"
#include "../../services/utils/money_functions.mqh"
#include "../../services/utils/broker_constraints_helper.mqh"
#include "../../services/utils/time_offset_helper.mqh"
#include "../../services/license_service_setup.mqh"
#include "../../services/trading_management/ea_inputs.mqh"
#include "../../services/trading_management/candle_structure_filter_context.mqh"
#include "../../services/trading_management/session_time_filter_context.mqh"
#include "../../services/trading_management/strategy_structure_context.mqh"
#include "../../services/trading_management/trailing_structure_context.mqh"
#include "../../services/trading_management/addon_runtime_policy.mqh"
#include "../../services/indicators/stochastic_market_indicator.mqh"
#include "../../services/indicators/fibonacci_calculator.mqh"
#include "../../services/trading_management/structure_fibonacci_levels.mqh"
#include "../../services/trading_signals/signal_params_struct.mqh"
#include "../../services/trading_signals/signal_lot_strategy.mqh"
#include "../../services/trading_signals/structure_compound_modes.mqh"
#include "../../services/trading_signals/structure_support_resistance_filter.mqh"
#include "../../services/frontend/runtime_guard.mqh"
#include "../../services/frontend/grid_visual_utils.mqh"
#include "../../services/frontend/lightweight_status_layout.mqh"

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

bool LoadStructureSnapshotForTimeframe(const ENUM_TIMEFRAMES,
                                       StochasticMarketStructure &snapshot)
{
  snapshot = StochasticMarketStructure();
  return false;
}

bool g_test_context_structure_snapshot_valid = false;
StochasticMarketStructure g_test_context_structure_snapshot;
int g_test_grid_log_count = 0;
string g_test_grid_log_last_label = "";
int g_test_build_grid_order_count = 0;
int g_test_update_grid_order_count = 0;
bool g_test_build_grid_order_result = true;
bool g_test_update_grid_order_result = true;

void ResetGridControllerTestStubs()
{
  g_test_context_structure_snapshot_valid = false;
  g_test_context_structure_snapshot = StochasticMarketStructure();
  g_test_grid_log_count = 0;
  g_test_grid_log_last_label = "";
  g_test_build_grid_order_count = 0;
  g_test_update_grid_order_count = 0;
  g_test_build_grid_order_result = true;
  g_test_update_grid_order_result = true;
}

bool LoadContextStructureSnapshot(const StrategyContextTypes,
                                  StochasticMarketStructure &snapshot)
{
  snapshot = StochasticMarketStructure();
  if(!g_test_context_structure_snapshot_valid)
    return false;

  snapshot = g_test_context_structure_snapshot;
  return true;
}

void GridLogEvent(const string label,
                  const SignalParams &,
                  const GridOrderState &)
{
  g_test_grid_log_count++;
  g_test_grid_log_last_label = label;
}

void GridLogGuardrailBlock(const string,
                           const SignalParams &,
                           const GridOrderState &,
                           const string)
{
}

void GridLogNextLevelTriggerDecision(const SignalParams &,
                                     const GridOrderState &,
                                     const SignalTypes)
{
}

void GridLogStopLimitDecision(const SignalParams &,
                              const GridOrderState &,
                              const int,
                              const bool)
{
}

void GridAppendQueryDebugLog(const string,
                             const string)
{
}

void GridAppendQueryDebugChangedLog(const string,
                                    const string,
                                    const string)
{
}

void MarketStatusRegisterBrokerFailure(const string,
                                       const ulong,
                                       const int,
                                       const bool)
{
}

bool BuildGridOrderForSignal(SignalParams &)
{
  g_test_build_grid_order_count++;
  return g_test_build_grid_order_result;
}

bool UpdateGridOrderForSignal(SignalParams &)
{
  g_test_update_grid_order_count++;
  return g_test_update_grid_order_result;
}

#include "../../services/trading_signals/market_signal_filters.mqh"
#include "../../services/trading_signals/grid_order_helpers.mqh"
#include "../../services/trading_signals/grid_order_math.mqh"
#include "../../services/trading_signals/structure_trailing_manager.mqh"
#include "../../services/trading_signals/grid_order_lifecycle.mqh"
#include "../../services/trading_signals/grid_order_controller.mqh"

#endif
