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

  string message = StringFormat("dir=%s|level=%d|status=%s|entry_ref=%.5f|stop=%.5f|limit=%.5f|entry=%.5f|tp=%.5f|tp_final=%.5f|lot=%.2f",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                order_state.entry_reference_price,
                                stop_price,
                                order_state.next_level_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                order_state.final_take_profit_price,
                                order_state.lot_size);
  AppendTimestampedLog("query_debug.txt", label, message);
}

void GridLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const string reason)
{
  MarketStatusRegisterExecutionError(label, reason, 0, 0);

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

void GridLogBrokerSendDiagnostic(const string label,
                                 const SignalParams &signal_params,
                                 const GridOrderState &order_state,
                                 const MqlTradeRequest &request,
                                 const MqlTradeCheckResult &check_result,
                                 const bool check_available,
                                 const bool check_sent,
                                 const int check_error,
                                 const ulong retcode,
                                 const int last_error,
                                 const string result_description,
                                 const string result_comment)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string check_status = check_available ? (check_sent ? "sent" : "failed") : "none";

  string message = StringFormat("dir=%s|symbol=%s|level=%d|status=%s|vol=%.2f|req_price=%.5f|sl=%.5f|tp=%.5f|entry_ref=%.5f|entry=%.5f|bid=%.5f|ask=%.5f|spread=%.1f|max_spread=%.1f|magic=%I64u|comment=%s|ret=%I64u|err=%d|ret_desc=%s|result_comment=%s|check=%s|check_ret=%u|check_err=%d|check_margin=%.2f|check_free=%.2f|check_level=%.2f|check_comment=%s|trade_mode=%d|exec_mode=%d|filling=%d|order_mode=%d|vol_min=%.2f|vol_max=%.2f|vol_step=%.2f|freeze=%.1f|stops=%.1f",
                                direction,
                                request.symbol,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                request.volume,
                                request.price,
                                request.sl,
                                request.tp,
                                order_state.entry_reference_price,
                                order_state.entry_price,
                                g_bid,
                                g_ask,
                                g_points_spread,
                                Max_Spread,
                                request.magic,
                                request.comment,
                                retcode,
                                last_error,
                                result_description,
                                result_comment,
                                check_status,
                                check_result.retcode,
                                check_error,
                                check_result.margin,
                                check_result.margin_free,
                                check_result.margin_level,
                                check_result.comment,
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE),
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE),
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE),
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE),
                                g_symbol_constraints.min_volume,
                                g_symbol_constraints.max_volume,
                                g_symbol_constraints.volume_step,
                                g_symbol_constraints.freeze_level_points,
                                g_symbol_constraints.stops_level_points);
  AppendTimestampedLog("query_debug.txt", label, message);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
