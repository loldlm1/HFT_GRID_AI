//+------------------------------------------------------------------+
//|                                  services/trading_signals.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MQH_
#define _SERVICES_TRADING_SIGNALS_MQH_

// INDICATOR SERVICES
#include "indicators/stochastic_market_indicator.mqh"
#include "indicators/pivot_points_calculator.mqh"

// SIGNAL SERVICE FILES
#include "trading_signals/signal_params_struct.mqh"
#include "trading_signals/market_signal_state.mqh"
#include "trading_signals/market_signal_indicators.mqh"
#include "trading_signals/pivot_context_features.mqh"
#include "trading_signals/extremum_engine_state.mqh"
#include "trading_signals/pivot_fractal_engine_state.mqh"
#include "trading_signals/market_signal_detection.mqh"
#include "trading_signals/market_status_controller.mqh"
#include "trading_signals/execution_broker_context.mqh"
#include "trading_signals/execution_broker_reconciliation.mqh"
#include "trading_signals/execution_lot_math.mqh"
#include "trading_signals/execution_logging.mqh"
#include "trading_signals/deterministic_signal_statistics_export.mqh"
#include "trading_signals/deterministic_signal_pattern_audit_playback.mqh"
#include "trading_signals/deterministic_signal_ml_shadow_inference.mqh"
#include "trading_signals/execution_controller.mqh"
#include "trading_signals/tick_signals_manager.mqh"

#endif // _SERVICES_TRADING_SIGNALS_MQH_
