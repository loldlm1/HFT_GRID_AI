//+------------------------------------------------------------------+
//|                                  services/trading_signals.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MQH_
#define _SERVICES_TRADING_SIGNALS_MQH_

// INDICATOR MICROSERVICES
#include "../microservices/indicators/bands_percent_indicator.mqh"
#include "../microservices/indicators/stochastic_indicator.mqh"
#include "../microservices/indicators/stochastic_market_indicator.mqh"
#include "../microservices/indicators/body_ma_indicator.mqh"

// SIGNAL SERVICE FILES
#include "trading_signals/signal_params_struct.mqh"
#include "trading_signals/grid_planner.mqh"
#include "trading_signals/grid_order_controller.mqh"
#include "trading_signals/market_signal_detector.mqh"
#include "trading_signals/tick_signals_manager.mqh"

#endif // _SERVICES_TRADING_SIGNALS_MQH_
