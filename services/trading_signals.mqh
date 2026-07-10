//+------------------------------------------------------------------+
//|                                  services/trading_signals.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MQH_
#define _SERVICES_TRADING_SIGNALS_MQH_

// INDICATOR SERVICES
#include "indicators/stochastic_market_indicator.mqh"

// SIGNAL SERVICE FILES
#include "trading_signals/signal_params_struct.mqh"
#include "trading_signals/session_time_filter_manager.mqh"
#include "trading_signals/signal_lot_strategy.mqh"
#include "trading_signals/market_signal_state.mqh"
#include "trading_signals/market_signal_indicators.mqh"
#include "trading_signals/market_signal_filters.mqh"
#include "trading_signals/market_signal_cleanup.mqh"
#include "trading_signals/market_signal_detection.mqh"
#include "trading_signals/market_status_controller.mqh"
#include "trading_signals/execution_broker_context.mqh"
#include "trading_signals/execution_price_resolver.mqh"
#include "trading_signals/execution_leg_helpers.mqh"
#include "trading_signals/execution_broker_reconciliation.mqh"
#include "trading_signals/execution_lot_math.mqh"
#include "trading_signals/execution_logging.mqh"
#include "trading_signals/execution_lifecycle.mqh"
#include "trading_signals/execution_indicator_cache.mqh"
#include "trading_signals/deterministic_signal_statistics_export.mqh"
#include "trading_signals/deterministic_signal_pattern_audit_playback.mqh"
#include "trading_signals/deterministic_signal_ml_shadow_inference.mqh"
#include "trading_signals/execution_planner.mqh"
#include "trading_signals/execution_controller.mqh"
#include "trading_signals/tick_signals_manager.mqh"
#include "trading_signals/protection_risk_filter.mqh"

#endif // _SERVICES_TRADING_SIGNALS_MQH_
