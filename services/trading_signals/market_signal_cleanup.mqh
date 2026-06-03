//+------------------------------------------------------------------+
//|                             market_signal_cleanup.mqh           |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_

void CloseBullishSignal(SignalParams &signal_bullish)
{
  signal_bullish.signal_state = CLOSED;
  PandoraUpsertTradeMarkerSnapshot(signal_bullish);
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bullish);
}

void CloseBearishSignal(SignalParams &signal_bearish)
{
  signal_bearish.signal_state = CLOSED;
  PandoraUpsertTradeMarkerSnapshot(signal_bearish);
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bearish);
}

void RemoveGridLevels(const long chart_id,
                      const SignalParams &signal_params)
{
  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string final_name = GridSignalObjectName(signal_params, "TP_FINAL");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");
  string trailing_name = GridSignalObjectName(signal_params, "TP_TRAILING");
  string break_even_name = GridSignalObjectName(signal_params, "BREAK_EVEN");

  ObjectDelete(chart_id, stop_name);
  ObjectDelete(chart_id, tp_name);
  ObjectDelete(chart_id, final_name);
  ObjectDelete(chart_id, entry_name);
  ObjectDelete(chart_id, next_name);
  ObjectDelete(chart_id, trailing_name);
  ObjectDelete(chart_id, break_even_name);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CLEANUP_MQH_
