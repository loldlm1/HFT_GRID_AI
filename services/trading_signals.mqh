//+------------------------------------------------------------------+
//|                                  services/trading_signals.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MQH_
#define _SERVICES_TRADING_SIGNALS_MQH_

// INDICATOR MICROSERVICES
#include "../microservices/indicators/bands_percent_indicator.mqh"
#include "../microservices/indicators/alligator_indicator.mqh"
#include "../microservices/indicators/stochastic_indicator.mqh"
#include "../microservices/indicators/stochastic_market_indicator.mqh"
#include "../microservices/indicators/body_ma_indicator.mqh"

// SIGNAL SERVICE FILES
#include "../microservices/trading_signals/grid_channel_utils.mqh"
#include "trading_signals/signal_params_struct.mqh"
#include "trading_signals/session_time_filter_manager.mqh"
#include "trading_signals/market_signal_state.mqh"
#include "trading_signals/market_signal_indicators.mqh"
#include "trading_signals/market_signal_channel_guards.mqh"
#include "trading_signals/market_signal_filters.mqh"
#include "trading_signals/market_signal_cleanup.mqh"
#include "trading_signals/market_signal_detection.mqh"
#include "trading_signals/market_status_controller.mqh"
#include "../microservices/trading_signals/grid_price_resolver.mqh"
#include "../microservices/trading_signals/grid_order_helpers.mqh"
#include "../microservices/trading_signals/grid_break_even_utils.mqh"
#include "../microservices/trading_signals/grid_order_math.mqh"
#include "../microservices/trading_signals/grid_order_logging.mqh"
#include "../microservices/trading_signals/grid_order_lifecycle.mqh"
#include "trading_signals/grid_planner.mqh"
#include "trading_signals/grid_trend_risk_manager.mqh"
#include "trading_signals/grid_order_controller.mqh"
#include "trading_signals/tick_signals_manager.mqh"
#include "trading_signals/protection_risk_filter.mqh"

#endif // _SERVICES_TRADING_SIGNALS_MQH_
