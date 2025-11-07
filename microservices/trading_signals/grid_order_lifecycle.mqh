//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
// grid_price_resolver is provided via the trading_signals include cascade
#include "grid_order_helpers.mqh"

double GridResolveStopTriggerPrice(const SignalParams &signal_params,
                                   const GridOrderState &state,
                                   const double point_size);

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

void GridScheduleNextLevel(SignalParams &signal_params,
                           const int level_index)
{
  if(!GridEnsureLevelState(signal_params, level_index))
    return;

  if(level_index >= ArraySize(signal_params.grid_orders))
    return;

  GridOrderState state = signal_params.grid_orders[level_index];
  if(state.status == GRID_ORDER_INACTIVE)
    state.status = GRID_ORDER_WAITING;
  signal_params.grid_orders[level_index] = state;
}

void GridInitializePendingLevel(SignalParams &signal_params,
                                const SignalTypes direction,
                                GridOrderState &order_state,
                                const double point_size)
{
  order_state.status = GRID_ORDER_STOP_TRAILING_ACTIVE;
  order_state.last_action_time = TimeCurrent();
  order_state.entry_reference_price = GridResolveEntryReferencePrice(signal_params, order_state);

  if(order_state.entry_style == GRID_ENTRY_STYLE_LIMIT)
  {
    double direction_mult = GridResolveDirectionMultiplier(direction);
    double pending_points = GridPlanResolvePendingPoints(order_state);
    if(direction_mult != 0.0 && pending_points > 0.0)
    {
      order_state.next_level_price = order_state.entry_reference_price - direction_mult * pending_points * point_size;
    }
  }
  else
  {
    order_state.next_level_price = GridResolveStopTriggerPrice(signal_params, order_state, point_size);
  }

  signal_params.grid_orders[order_state.level_index] = order_state;
}

bool GridShouldActivatePendingLevel(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  double trigger_price = GridResolveStopTriggerPrice(signal_params, order_state, point_size);
  if(trigger_price <= 0.0)
    return false;

  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(entry_side_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return entry_side_price >= trigger_price;
  return entry_side_price <= trigger_price;
}

void GridUpdateActiveTargets(const SignalParams &signal_params,
                             GridOrderState &order_state,
                             const double point_size)
{
  double reference_points = order_state.base_distance_points;
  if(reference_points <= 0.0)
    reference_points = order_state.pending_distance_points;

  if(reference_points <= 0.0)
    return;

  double tp_points = 0.0;
  double final_points = 0.0;

  if(Grid_TP_Percent > 0.0)
    tp_points = reference_points * (Grid_TP_Percent / 100.0);
  if(Grid_Final_TP_Percent > 0.0)
    final_points = reference_points * (Grid_Final_TP_Percent / 100.0);

  if(tp_points > 0.0)
    tp_points = EnforceBrokerDistance(g_symbol_constraints, tp_points);
  if(final_points > 0.0)
    final_points = EnforceBrokerDistance(g_symbol_constraints, final_points);

  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);
  order_state.tp_reference_points = reference_points;
  order_state.take_profit_points  = tp_points;
  order_state.final_take_profit_points = final_points;

  if(order_state.entry_price > 0.0 && point_size > 0.0)
  {
    if(tp_points > 0.0)
      order_state.take_profit_price = order_state.entry_price + direction_mult * tp_points * point_size;
    if(final_points > 0.0)
      order_state.final_take_profit_price = order_state.entry_price + direction_mult * final_points * point_size;
  }
}

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  string comment = GridComposeLevelComment(signal_params, order_state);

  bool sent = false;
  if(direction == BULLISH)
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!sent)
    return false;

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
  order_state.resolved_distance_points = order_state.base_distance_points;

  GridUpdateActiveTargets(signal_params, order_state, point_size);
  signal_params.grid_orders[order_state.level_index] = order_state;
  return true;
}

void GridFinalizeLevel(const SignalTypes direction,
                       GridOrderState &order_state,
                       const double point_size,
                       const double close_price_override)
{
  double close_price = close_price_override;
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.status = GRID_ORDER_COMPLETED;
  order_state.last_action_time = TimeCurrent();
  order_state.position_ticket  = 0;
  order_state.position_comment = "";
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.trailing_price     = 0.0;
  order_state.final_take_profit_price = 0.0;
  order_state.take_profit_price       = 0.0;
  order_state.next_level_price        = 0.0;
  order_state.entry_reference_price   = 0.0;
  order_state.entry_price             = close_price;
  order_state.resolved_distance_points = 0.0;
}

bool GridCloseBrokerPosition(GridOrderState &order_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(order_state.position_ticket <= 0)
    return false;

  if(!PositionSelectByTicket(order_state.position_ticket))
    return false;

  if(!g_position.PositionClose(order_state.position_ticket))
    return false;

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.position_ticket = 0;
  return true;
}

void GridCloseAllLevels(SignalParams &signal_params,
                        const double point_size)
{
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = 0.0;
      GridCloseBrokerPosition(state, direction, close_price);
      GridFinalizeLevel(direction, state, point_size, close_price);
      GridLogEvent("LEVEL_CLOSE_ALL", signal_params, state);
    }
    else if(state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
            state.status == GRID_ORDER_WAITING)
    {
      state.status = GRID_ORDER_COMPLETED;
      state.last_action_time = TimeCurrent();
      GridLogEvent("LEVEL_CANCELLED", signal_params, state);
    }
    signal_params.grid_orders[i] = state;
  }
}

bool IsGridSignalComplete(const SignalParams &signal_params)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
       state.status == GRID_ORDER_ACTIVE)
      return false;
  }
  return true;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
