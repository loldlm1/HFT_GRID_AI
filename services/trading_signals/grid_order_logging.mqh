//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... logging      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_

#include "grid_order_helpers.mqh"

void GridLogEvent(const string label,
                  const SignalParams &signal_params,
                  const GridOrderState &order_state)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double point_size = GridResolvePointSize();
  double stop_price = 0; // SHOULD BE USING THE order_state stop price

  string message = StringFormat("dir=%s|level=%d|status=%s|entry_ref=%.5f|stop=%.5f|limit=%.5f|entry=%.5f|tp=%.5f|lot=%.2f",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                order_state.entry_reference_price,
                                stop_price,
                                order_state.next_level_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                order_state.lot_size);
  AppendTimestampedLog("query_debug.txt", label, message);
}

void GridLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const string reason)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|status=%s|reason=%s",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                reason);
  AppendTimestampedLog("query_debug.txt", label, message);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
