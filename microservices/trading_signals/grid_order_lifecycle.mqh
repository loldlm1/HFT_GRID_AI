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

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  string comment = GridComposeLevelComment(signal_params, order_state);

  // Guardrails: spread/margin checks before sending
  string guard_reason = "";
  if(!GridGuardrailsAllowOrder(normalized_volume, guard_reason))
  {
    GridLogGuardrailBlock("GUARDRAIL_BLOCK", signal_params, order_state, guard_reason);
    return false;
  }

  bool sent = false;
  if(direction == BULLISH)
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!sent)
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    if(Debug_Stop_On_Negative_Equity)
    {
      if(retcode == TRADE_RETCODE_NO_MONEY)
        g_debug_no_money_abort_pending = true;
    }
    MarketStatusRegisterBrokerFailure("ORDER_SEND_FAILED", retcode, last_error, false);
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = GridCurrentPriceForDirection(direction, true);

  order_state.status = GRID_ORDER_ACTIVE;
  order_state.entry_price = fill_price;
  ulong deal_ticket = (ulong)g_position.ResultDeal();
  order_state.position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  if(order_state.position_ticket == 0)
    order_state.position_ticket = FindOpenPositionForSignal(direction, comment);
  order_state.position_comment = comment;
  order_state.last_action_time = TimeCurrent();

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

  int bullish_positions = GetActivePositionsCount(BULLISH);
  int bearish_positions = GetActivePositionsCount(BEARISH);

  if(signal_params.signal_type == BULLISH && bullish_positions == 0)
    return true;
  if(signal_params.signal_type == BEARISH && bearish_positions == 0)
    return true;

  return false;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
