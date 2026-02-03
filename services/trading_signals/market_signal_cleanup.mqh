//+------------------------------------------------------------------+
//|                             market_signal_cleanup.mqh           |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_

void CloseBullishSignal(SignalParams &signal_bullish)
{
  signal_bullish.signal_state = CLOSED;
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bullish);
}

void CloseBearishSignal(SignalParams &signal_bearish)
{
  signal_bearish.signal_state = CLOSED;
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bearish);
}

void RemoveGridLevels(const long chart_id,
                      const SignalParams &signal_params)
{
  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");

  ObjectDelete(chart_id, stop_name);
  ObjectDelete(chart_id, tp_name);
  ObjectDelete(chart_id, entry_name);
  ObjectDelete(chart_id, next_name);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_
