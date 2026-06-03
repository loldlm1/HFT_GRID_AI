//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
// grid_price_resolver is provided via the trading_signals include cascade
#include "grid_order_helpers.mqh"

bool g_debug_no_money_abort_pending = false;

ulong ResolvePositionTicketFromDeal(const ulong deal_ticket)
{
  if(deal_ticket <= 0)
    return 0;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return 0;
  if(!HistoryDealSelect(deal_ticket))
    return 0;

  return (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
}

ulong FindOpenPositionForSignal(const SignalTypes direction,
                                const string comment)
{
  int total_positions = PositionsTotal();
  for(int i = 0; i < total_positions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(direction == BULLISH && pos_type != POSITION_TYPE_BUY)
      continue;
    if(direction == BEARISH && pos_type != POSITION_TYPE_SELL)
      continue;

    if(comment != "")
    {
      string pos_comment = PositionGetString(POSITION_COMMENT);
      if(pos_comment != comment)
        continue;
    }

    return position_ticket;
  }
  return 0;
}

bool GridShouldActivateStopOrder(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);

  double stop_trigger = order_state.entry_reference_price;
  if(stop_trigger <= 0.0)
    return false;
  // BUY STOP: Ask >= stop; SELL STOP: Bid <= stop
  if(direction == BULLISH) return entry_side_price >= stop_trigger;
  if(direction == BEARISH) return entry_side_price <= stop_trigger;
  return false;

  return false;
}

bool GridShouldActivateNextLevelLimit(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);

  // Deeper levels activate on the NEXT level price (averaging on adverse move).
  double next_trigger = order_state.next_level_price;
  if(next_trigger <= 0.0)
    return false;
  // Bullish: trigger when Ask <= next; Bearish: trigger when Bid >= next
  if(direction == BULLISH) return entry_side_price <= next_trigger;
  if(direction == BEARISH) return entry_side_price >= next_trigger;

  return false;
}

bool ShouldSwitchToTrailingTP(const SignalTypes direction,
                              const GridOrderState &order_state,
                              const double current_price)
{
  if(order_state.take_profit_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return current_price >= order_state.take_profit_price;
  if(direction == BEARISH)
    return current_price <= order_state.take_profit_price;
  return false;
}

bool GridShouldActivateTrailing(SignalParams &signal_params,
                                const GridOrderState &order_state,
                                const double current_price)
{
  if(PandoraStrategyEnabled())
    return false;

  SignalTypes direction = signal_params.signal_type;
  if(Grid_Trailing_Execution_Mode != TRAILING_EXECUTION_AGGRESIVE)
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  double indicator_price = 0.0;
  if(!GridResolveTrailingStrategyPrice(signal_params, indicator_price))
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  double reference_price = order_state.take_profit_price;
  if(reference_price <= 0.0)
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  if(direction == BULLISH)
    return indicator_price >= reference_price;
  if(direction == BEARISH)
    return indicator_price <= reference_price;
  return false;
}

bool GridRefreshPandoraStopsAfterFill(const SignalParams &signal_params,
                                      GridOrderState &order_state)
{
  if(!IsPandoraSignal(signal_params))
    return true;

  double corrected_sl = 0.0;
  double corrected_tp = 0.0;
  if(!PandoraResolveBrokerStops(signal_params, order_state, corrected_sl, corrected_tp))
  {
    MarketStatusRegisterExecutionError("PANDORA_INITIAL_SLTP_RESOLVE_FAILED", "post_fill", 0, GetLastError());
    return false;
  }

  order_state.take_profit_price = corrected_tp;

  if(!Pandora_Box_Set_Broker_SLTP)
    return true;
  if(order_state.position_ticket <= 0)
  {
    MarketStatusRegisterExecutionError("PANDORA_INITIAL_SLTP_CORRECT_FAILED", "missing_position_ticket", 0, 0);
    return false;
  }
  if(!PositionSelectByTicket(order_state.position_ticket))
  {
    MarketStatusRegisterExecutionError("PANDORA_INITIAL_SLTP_CORRECT_FAILED", "position_not_found", 0, GetLastError());
    return false;
  }

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.00001;
  double tolerance = point_size * 0.1;

  double current_sl = PositionGetDouble(POSITION_SL);
  double current_tp = PositionGetDouble(POSITION_TP);
  bool sl_matches = (MathAbs(current_sl - corrected_sl) <= tolerance);
  bool tp_matches = (MathAbs(current_tp - corrected_tp) <= tolerance);
  if(sl_matches && tp_matches)
    return true;

  if(!g_position.PositionModify(order_state.position_ticket, corrected_sl, corrected_tp))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("PANDORA_INITIAL_SLTP_CORRECT_FAILED", retcode, last_error, true);
    if(Enable_Logs)
    {
      PrintFormat("PANDORA_INITIAL_SLTP_CORRECT_FAILED ticket=%I64u entry=%.5f sl=%.5f tp=%.5f retcode=%I64u error=%d",
                  order_state.position_ticket,
                  order_state.entry_price,
                  corrected_sl,
                  corrected_tp,
                  retcode,
                  last_error);
    }
    return false;
  }
  MarketStatusClearExecutionError("PANDORA_INITIAL_SLTP_CORRECTED");

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_INITIAL_SLTP_CORRECTED ticket=%I64u entry=%.5f sl=%.5f tp=%.5f prev_sl=%.5f prev_tp=%.5f",
                order_state.position_ticket,
                order_state.entry_price,
                corrected_sl,
                corrected_tp,
                current_sl,
                current_tp);
  }

  return true;
}

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  string comment = GridComposeLevelComment(signal_params, order_state);
  bool pandora_signal = IsPandoraSignal(signal_params);

  if(!order_state.opens_position)
  {
    double fill_price = GridCurrentPriceForDirection(direction, true);
    if(fill_price <= 0.0)
      fill_price = order_state.entry_reference_price;
    if(fill_price <= 0.0)
      fill_price = GridCurrentPriceForDirection(direction, true);

    order_state.status            = GRID_ORDER_ACTIVE;
    order_state.entry_price       = fill_price;
    order_state.position_ticket   = 0;
    order_state.position_comment  = comment;
    order_state.last_action_time  = TimeCurrent();
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  if(pandora_signal && PandoraBrokerAttemptAlreadyFinished(signal_params))
  {
    if(signal_params.pandora_broker_execution_status != PANDORA_BROKER_EXECUTED &&
       order_state.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
    {
      PandoraEnsureLocalEntryActive(signal_params, order_state, comment);
      signal_params.grid_orders[order_state.level_index] = order_state;
    }
    return true;
  }

  // Guardrails: spread/margin checks before sending
  string guard_reason = "";
  if(!GridGuardrailsAllowOrder(normalized_volume, guard_reason))
  {
    GridLogGuardrailBlock("GUARDRAIL_BLOCK", signal_params, order_state, guard_reason);
    if(Debug_Stop_On_Negative_Equity) g_debug_no_money_abort_pending = true;
    if(pandora_signal)
    {
      PandoraMarkBrokerBlocked(signal_params,
                               order_state,
                               "GUARDRAIL_BLOCK",
                               guard_reason,
                               comment);
      signal_params.grid_orders[order_state.level_index] = order_state;
      return true;
    }
    return false;
  }

  bool sent = false;
  double sl_price = 0.0;
  double tp_price = 0.0;
  if(Pandora_Box_Set_Broker_SLTP)
  {
    GridOrderState broker_seed_state = order_state;
    if(IsPandoraSignal(signal_params) && broker_seed_state.entry_price <= 0.0)
    {
      broker_seed_state.entry_price = GridCurrentPriceForDirection(direction, true);
      if(broker_seed_state.entry_price <= 0.0)
        broker_seed_state.entry_price = order_state.entry_reference_price;
    }
    if(!PandoraResolveBrokerStops(signal_params, broker_seed_state, sl_price, tp_price))
      MarketStatusRegisterExecutionError("PANDORA_BROKER_STOPS_RESOLVE_FAILED", "pre_send", 0, GetLastError());
  }

  if(direction == BULLISH)
  {
    ResetLastError();
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, sl_price, tp_price, comment);
  }
  else
  {
    ResetLastError();
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, sl_price, tp_price, comment);
  }

  ulong retcode = g_position.ResultRetcode();
  int last_error = GetLastError();
  if(!sent)
  {
    if(Debug_Stop_On_Negative_Equity)
    {
      if(retcode == TRADE_RETCODE_NO_MONEY)
        g_debug_no_money_abort_pending = true;
    }
    MarketStatusRegisterBrokerFailure("ORDER_SEND_FAILED", retcode, last_error, false);
    if(pandora_signal)
    {
      string reject_detail = PandoraBrokerRejectSummary("ORDER_SEND_FAILED", "", retcode, last_error);
      PandoraMarkBrokerRejected(signal_params,
                                order_state,
                                "ORDER_SEND_FAILED",
                                reject_detail,
                                retcode,
                                last_error,
                                comment);
      signal_params.grid_orders[order_state.level_index] = order_state;
      return true;
    }
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = GridCurrentPriceForDirection(direction, true);

  ulong deal_ticket = (ulong)g_position.ResultDeal();
  ulong position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  if(position_ticket == 0)
    position_ticket = FindOpenPositionForSignal(direction, comment);

  bool broker_executed = (retcode == TRADE_RETCODE_DONE ||
                          retcode == TRADE_RETCODE_DONE_PARTIAL);
  if(pandora_signal && (!broker_executed || position_ticket == 0))
  {
    string context = broker_executed ? "ORDER_SEND_POSITION_MISSING" : "ORDER_SEND_REJECTED";
    string reject_detail = PandoraBrokerRejectSummary(context, "", retcode, last_error);
    if(retcode == TRADE_RETCODE_DONE_PARTIAL)
      reject_detail = reject_detail + StringFormat(" volume=%.2f", g_position.ResultVolume());
    MarketStatusRegisterBrokerFailure(context, retcode, last_error, false);
    PandoraMarkBrokerRejected(signal_params,
                              order_state,
                              context,
                              reject_detail,
                              retcode,
                              last_error,
                              comment);
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  MarketStatusClearExecutionError("ORDER_SEND_OK");

  order_state.status = GRID_ORDER_ACTIVE;
  order_state.entry_price = fill_price;
  order_state.position_ticket = position_ticket;
  order_state.position_comment = comment;
  order_state.last_action_time = TimeCurrent();

  if(pandora_signal)
  {
    if(retcode == TRADE_RETCODE_DONE_PARTIAL && Enable_Logs)
    {
      PrintFormat("PANDORA_BROKER_PARTIAL_FILL ticket=%I64u retcode=%I64u volume=%.2f requested=%.2f",
                  order_state.position_ticket,
                  retcode,
                  g_position.ResultVolume(),
                  normalized_volume);
    }
    PandoraMarkBrokerExecuted(signal_params,
                              order_state,
                              retcode,
                              last_error,
                              comment);
  }

  GridRefreshPandoraStopsAfterFill(signal_params, order_state);

  signal_params.grid_orders[order_state.level_index] = order_state;
  return sent;
}

bool GridCloseBrokerPosition(GridOrderState &order_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(order_state.position_ticket <= 0)
    return true;

  if(!PositionSelectByTicket(order_state.position_ticket))
    return true;

  if(!g_position.PositionClose(order_state.position_ticket))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("POSITION_CLOSE_FAILED", retcode, last_error, true);
    return false;
  }
  MarketStatusClearExecutionError("POSITION_CLOSE_OK");

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.position_ticket = 0;
  return true;
}

void GridCloseAllLevels(SignalParams &signal_params,
                        const double point_size)
{
  bool result = false;
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    double close_price = 0.0;
    result = GridCloseBrokerPosition(state, direction, close_price);
    if(result) state.status = GRID_ORDER_COMPLETED;
    GridLogEvent("LEVEL_CLOSE_ALL", signal_params, state);
    signal_params.grid_orders[i] = state;
  }

  if(signal_params.hedge_position_ticket > 0 &&
     PositionSelectByTicket(signal_params.hedge_position_ticket))
  {
    long position_magic = PositionGetInteger(POSITION_MAGIC);
    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_magic == g_magic_number && position_symbol == _Symbol)
    {
      if(!g_position.PositionClose(signal_params.hedge_position_ticket))
      {
        ulong retcode = g_position.ResultRetcode();
        int last_error = GetLastError();
        MarketStatusRegisterBrokerFailure("HEDGE_CLOSE_ALL_FAILED", retcode, last_error, true);
      }
      else
      {
        MarketStatusClearExecutionError("HEDGE_CLOSE_ALL_OK");
      }
      GridOrderState hedge_state;
      hedge_state.position_ticket = signal_params.hedge_position_ticket;
      hedge_state.status = GRID_ORDER_COMPLETED;
      hedge_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      GridLogEvent("HEDGE_CLOSE_ALL", signal_params, hedge_state);
    }
    signal_params.hedge_position_ticket = 0;
    signal_params.hedge_sl_active = false;
    signal_params.hedge_sl_price = 0.0;
  }
  signal_params.hedge_finalized = true;
}

int GetActivePositionsCount(const SignalTypes direction)
{
  int count = 0;
  int total_positions = PositionsTotal();

  for(int i = 0; i < total_positions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;

    if(!PositionSelectByTicket(position_ticket))
      continue;

    // Validar magic number
    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_symbol != _Symbol)
      continue;

    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    if(direction == BULLISH && pos_type == POSITION_TYPE_BUY)
      count++;
    else if(direction == BEARISH && pos_type == POSITION_TYPE_SELL)
      count++;
  }

  return count;
}

bool IsGridSignalComplete(const SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
       state.status == GRID_ORDER_ACTIVE ||
       state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
      return false;
  }

  int attached_positions = 0;
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.position_ticket > 0 && PositionSelectByTicket(state.position_ticket))
    {
      long position_magic = PositionGetInteger(POSITION_MAGIC);
      string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(position_magic == g_magic_number && position_symbol == _Symbol)
        attached_positions++;
    }
  }

  return (attached_positions == 0);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
