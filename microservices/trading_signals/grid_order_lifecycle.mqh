//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
// grid_price_resolver is provided via the trading_signals include cascade
#include "grid_order_helpers.mqh"

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

bool GridShouldActivatePendingLevel(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  // Activate using the entry_reference_price (BUY/SELL STOP line), not next_level_price
  double trigger_price    = order_state.entry_reference_price;
  double entry_side_price = GridCurrentPriceForDirection(direction, true);

  // Broker semantics:
  // - BUY STOP triggers when Ask >= stop price
  // - SELL STOP triggers when Bid <= stop price
  if(direction == BULLISH) return entry_side_price >= trigger_price;
  if(direction == BEARISH) return entry_side_price <= trigger_price;

  return false;
}

void GridUpdateActiveTargets(const SignalParams &signal_params,
                             GridOrderState &order_state,
                             const double point_size)
{
  // Compute TP and Final TP based on entry→next snapshot captured on fill
  double tp_reference_pts = ComputeLevelDistancePoints(signal_params, order_state.level_index + 1);
  if(tp_reference_pts <= 0.0)
    tp_reference_pts = signal_params.grid_base_distance_points;
  if(tp_reference_pts <= 0.0 || point_size <= 0.0)
    return;

  double tp_span_pts    = tp_reference_pts * (Grid_TP_Percent / 100.0);
  double final_span_pts = tp_reference_pts * (Grid_Final_TP_Percent / 100.0);

  if(signal_params.signal_type == BULLISH)
  {
    order_state.take_profit_price       = order_state.entry_price + tp_span_pts * point_size;
    order_state.final_take_profit_price = order_state.entry_price + final_span_pts * point_size;
  }
  else if(signal_params.signal_type == BEARISH)
  {
    order_state.take_profit_price       = order_state.entry_price - tp_span_pts * point_size;
    order_state.final_take_profit_price = order_state.entry_price - final_span_pts * point_size;
  }

  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.trailing_price     = 0.0;
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

void UpdateTrailingTP(const SignalParams &signal_params,
                      GridOrderState &order_state,
                      const double current_price,
                      const double point_size)
{
  // Derive tp_reference_pts from the TP span and percent to stay consistent post-fill
  double tp_span_pts = 0.0;
  if(point_size > 0.0)
    tp_span_pts = MathAbs(order_state.take_profit_price - order_state.entry_price) / point_size;
  double tp_ref_pts = tp_span_pts;
  if(Grid_TP_Percent > 0.0)
    tp_ref_pts = tp_span_pts / (Grid_TP_Percent / 100.0);
  if(tp_ref_pts <= 0.0)
    tp_ref_pts = signal_params.grid_base_distance_points;
  if(tp_ref_pts <= 0.0 || point_size <= 0.0)
    return;

  double offset_pts = tp_ref_pts * (1.0 - (Grid_Trailing_TP_Percent / 100.0));
  if(offset_pts < 0.0)
    offset_pts = 0.0;

  double candidate = order_state.trailing_price;
  if(signal_params.signal_type == BULLISH)
    candidate = current_price - offset_pts * point_size;
  else if(signal_params.signal_type == BEARISH)
    candidate = current_price + offset_pts * point_size;

  // Move trailing only in favorable direction
  if(order_state.trailing_price <= 0.0)
  {
    order_state.trailing_price = candidate;
    return;
  }

  if(signal_params.signal_type == BULLISH)
  {
    if(candidate > order_state.trailing_price)
      order_state.trailing_price = candidate;
  }
  else if(signal_params.signal_type == BEARISH)
  {
    if(candidate < order_state.trailing_price)
      order_state.trailing_price = candidate;
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

  GridUpdateActiveTargets(signal_params, order_state, point_size);
  signal_params.grid_orders[order_state.level_index] = order_state;

  // Stage the next grid level after a confirmed fill (sequential expansion)
  int next_index = order_state.level_index + 1;
  if(next_index < GRID_MAX_LEVELS)
  {
    int total_levels = ArraySize(signal_params.grid_orders);
    if(total_levels <= next_index)
    {
      GridOrderState next_state;
      AddElementToArray(signal_params.grid_orders, next_state);
    }

    GridOrderState staged = signal_params.grid_orders[next_index];
    if(staged.status == GRID_ORDER_INACTIVE || staged.level_index != next_index)
    {
      staged.level_index = next_index;
      staged.status      = GRID_ORDER_WAITING;
      double base_lot = signal_params.grid_base_lot_size;
      if(base_lot <= 0.0)
        base_lot = 0.01;
      double scaled = base_lot * MathPow(Grid_Multiplier, (double)next_index);
      staged.lot_size = NormalizeVolumeForSymbol(_Symbol, scaled);
      signal_params.grid_orders[next_index] = staged;
      GridLogEvent("LEVEL_PENDING_INIT", signal_params, staged);
    }
  }
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
