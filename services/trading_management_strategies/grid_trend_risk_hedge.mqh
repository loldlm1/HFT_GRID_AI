//+------------------------------------------------------------------+
//|          trading_management_strategies/grid_trend_risk_hedge.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_HEDGE_MQH_
#define _GRID_TREND_RISK_HEDGE_MQH_

bool GridHedgeModeEnabled()
{
  return (Grid_Risk_Trend_Mode == GRID_RM_TREND_HEDGE);
}

SignalTypes GridResolveHedgeDirection(const SignalParams &signal_params)
{
  return (signal_params.signal_type == BULLISH) ? BEARISH : BULLISH;
}

double GridResolveHedgeDistancePoints(const SignalParams &signal_params)
{
  double distance_points = Grid_Risk_Trend_Hedge_Points;
  if(distance_points <= 0.0)
    distance_points = signal_params.grid_base_distance_points;
  if(distance_points <= 0.0)
    distance_points = signal_params.grid_entry_gap_points;
  return distance_points;
}

bool GridHedgePositionAlive(SignalParams &signal_params)
{
  if(signal_params.hedge_position_ticket <= 0)
    return false;

  if(!PositionSelectByTicket(signal_params.hedge_position_ticket))
  {
    signal_params.hedge_position_ticket = 0;
    return false;
  }

  long position_magic  = PositionGetInteger(POSITION_MAGIC);
  string position_symbol = PositionGetString(POSITION_SYMBOL);
  if(position_magic != g_magic_number || position_symbol != _Symbol)
  {
    signal_params.hedge_position_ticket = 0;
    return false;
  }

  signal_params.hedge_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  return true;
}

bool GridOpenHedgePosition(SignalParams &signal_params,
                           const GridOrderState &state_candidate,
                           const double hedge_distance_points)
{
  if(signal_params.hedge_finalized)
    return false;
  SignalTypes hedge_direction = GridResolveHedgeDirection(signal_params);
  double lot_size = state_candidate.lot_size;
  if(lot_size <= 0.0)
    lot_size = signal_params.grid_base_lot_size;
  if(lot_size <= 0.0)
    lot_size = Grid_Lot_Strategy_Size;

  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, lot_size);
  string guard_reason = "";
  if(!GridGuardrailsAllowOrder(normalized_volume, guard_reason))
  {
    GridLogGuardrailBlock("HEDGE_GUARDRAIL_BLOCK", signal_params, state_candidate, guard_reason);
    return false;
  }

  double entry_price = GridCurrentPriceForDirection(hedge_direction, true);

  string comment = "GRID_HEDGE";
  bool sent = false;
  if(hedge_direction == BULLISH)
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!sent)
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("HEDGE_ORDER_SEND_FAILED", retcode, last_error, false);
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = entry_price;

  ulong deal_ticket = (ulong)g_position.ResultDeal();
  ulong position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  if(position_ticket == 0)
    position_ticket = FindOpenPositionForSignal(hedge_direction, comment);

  signal_params.hedge_position_ticket = position_ticket;
  signal_params.hedge_entry_price     = fill_price;

  double sl_price = 0.0;
  if(Grid_Risk_Trend_Hedge_SL && hedge_distance_points > 0.0)
  {
    double point_size = GridResolvePointSize();
    double offset = hedge_distance_points * point_size;
    if(hedge_direction == BULLISH)
      sl_price = fill_price - offset;
    else
      sl_price = fill_price + offset;
  }
  signal_params.hedge_sl_price  = sl_price;
  signal_params.hedge_sl_active = (sl_price > 0.0);

  GridOrderState hedge_state = state_candidate;
  hedge_state.position_ticket = position_ticket;
  hedge_state.entry_price = fill_price;
  hedge_state.status = GRID_ORDER_ACTIVE;
  GridLogEvent("HEDGE_OPEN", signal_params, hedge_state);
  return true;
}

bool GridUpdateHedgeStopLoss(SignalParams &signal_params,
                             const GridOrderState &state_candidate,
                             const double hedge_distance_points)
{
  if(signal_params.hedge_finalized)
    return false;
  if(!GridHedgePositionAlive(signal_params))
    return false;
  if(!Grid_Risk_Trend_Hedge_SL)
  {
    signal_params.hedge_sl_active = false;
    signal_params.hedge_sl_price = 0.0;
    return true;
  }

  double next_level_price = state_candidate.next_level_price;
  double entry_price = signal_params.hedge_entry_price;
  if(entry_price <= 0.0 && PositionSelectByTicket(signal_params.hedge_position_ticket))
    entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  if(entry_price <= 0.0)
    return false;

  bool keep_sl = (hedge_distance_points > 0.0);
  if(next_level_price > 0.0 && hedge_distance_points > 0.0)
  {
    double point_size = GridResolvePointSize();
    double distance_to_next = MathAbs(next_level_price - entry_price) / point_size;
    if(distance_to_next > hedge_distance_points)
      keep_sl = false;
  }

  double sl_price = 0.0;
  if(keep_sl && hedge_distance_points > 0.0)
  {
    double point_size = GridResolvePointSize();
    double offset = hedge_distance_points * point_size;
    SignalTypes hedge_direction = GridResolveHedgeDirection(signal_params);
    if(hedge_direction == BULLISH)
      sl_price = entry_price - offset;
    else
      sl_price = entry_price + offset;
  }

  signal_params.hedge_sl_active = (sl_price > 0.0);
  signal_params.hedge_sl_price  = sl_price;
  return true;
}

bool GridHedgeStopHit(const SignalParams &signal_params)
{
  if(signal_params.hedge_finalized)
    return false;
  if(!signal_params.hedge_sl_active || signal_params.hedge_sl_price <= 0.0)
    return false;
  double current_price = GridCurrentPriceForDirection(GridResolveHedgeDirection(signal_params), false);
  if(GridResolveHedgeDirection(signal_params) == BULLISH)
    return (current_price <= signal_params.hedge_sl_price);
  return (current_price >= signal_params.hedge_sl_price);
}

bool GridCloseHedgePosition(SignalParams &signal_params,
                            const string log_label,
                            const bool finalize)
{
  if(!GridHedgePositionAlive(signal_params))
    return false;

  ulong ticket = signal_params.hedge_position_ticket;
  double close_price = 0.0;
  if(PositionSelectByTicket(ticket))
    close_price = PositionGetDouble(POSITION_PRICE_CURRENT);

  bool closed = g_position.PositionClose(ticket);
  if(!closed)
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("HEDGE_CLOSE_FAILED", retcode, last_error, true);
    return false;
  }

  signal_params.hedge_position_ticket = 0;
  signal_params.hedge_sl_active = false;
  signal_params.hedge_sl_price = 0.0;
  signal_params.hedge_finalized = true;

  GridOrderState hedge_state;
  hedge_state.entry_price = signal_params.hedge_entry_price;
  hedge_state.position_ticket = ticket;
  hedge_state.status = GRID_ORDER_COMPLETED;
  GridLogEvent(log_label, signal_params, hedge_state);
  if(finalize)
    signal_params.hedge_finalized = true;
  return true;
}

bool GridApplyTrendHedgeManagement(SignalParams &signal_params,
                                   const GridOrderState &override_state,
                                   const bool has_override)
{
  if(!GridHedgeModeEnabled())
    return false;
  if(signal_params.hedge_finalized)
    return false;

  GridOrderState state_candidate = override_state;
  if(!has_override)
  {
    if(!GridFindLatestFilledOrder(signal_params, state_candidate))
      return false;
  }

  if(state_candidate.status != GRID_ORDER_ACTIVE &&
     state_candidate.status != GRID_ORDER_TP_TRAILING_ACTIVE)
    return false;

  // Close prior leg whenever spacing is inside the hedge distance so the new level acts as the base.
  if(Grid_Risk_Trend_Hedge_SL &&
     state_candidate.level_index >= 1)
  {
    double hedge_distance_points = GridResolveHedgeDistancePoints(signal_params);
    GridOrderState prev_state = signal_params.grid_orders[state_candidate.level_index - 1];
    double point_size = GridResolvePointSize();
    double level_spacing = 0.0;
    if(prev_state.entry_price > 0.0 && state_candidate.entry_price > 0.0 && point_size > 0.0)
      level_spacing = MathAbs(state_candidate.entry_price - prev_state.entry_price) / point_size;

    bool close_previous = true;
    if(hedge_distance_points > 0.0 && level_spacing > hedge_distance_points)
    {
      close_previous = false;
      signal_params.hedge_reset_done = true;
    }

    if(close_previous)
    {
      if(prev_state.position_ticket > 0)
      {
        double close_price = 0.0;
        if(GridCloseBrokerPosition(prev_state, signal_params.signal_type, close_price))
        {
          prev_state.status = GRID_ORDER_COMPLETED;
          prev_state.opens_position = false;
          signal_params.grid_orders[state_candidate.level_index - 1] = prev_state;
          GridLogEvent("HEDGE_RESET_CLOSE_PREV", signal_params, prev_state);
        }
      }
      else
      {
        prev_state.opens_position = false;
        signal_params.grid_orders[state_candidate.level_index - 1] = prev_state;
      }

      signal_params.grid_base_lot_size = Grid_Lot_Strategy_Size;
      signal_params.grid_orders[state_candidate.level_index].lot_size = Grid_Lot_Strategy_Size;
      // Reset executed count so lot multiplier restarts from base
      int executed_levels = ArraySize(signal_params.grid_orders);
      for(int i = 0; i < executed_levels; i++)
      {
        if(!signal_params.grid_orders[i].opens_position)
          continue;
        if(signal_params.grid_orders[i].status == GRID_ORDER_COMPLETED)
        {
          signal_params.grid_orders[i].status = GRID_ORDER_INACTIVE;
          signal_params.grid_orders[i].opens_position = false;
        }
      }
    }
  }

  double hedge_distance_points = GridResolveHedgeDistancePoints(signal_params);
  if(!GridHedgePositionAlive(signal_params))
  {
    if(!GridOpenHedgePosition(signal_params, state_candidate, hedge_distance_points))
      return false;
  }
  else
  {
    GridUpdateHedgeStopLoss(signal_params, state_candidate, hedge_distance_points);
    if(GridHedgeStopHit(signal_params))
    {
      GridCloseHedgePosition(signal_params, "HEDGE_STOP_HIT", false);
      signal_params.hedge_position_ticket = 0;
      signal_params.hedge_sl_active = false;
      signal_params.hedge_sl_price = 0.0;
      return false;
    }
  }

  int cover_level = Grid_Risk_Trend_Hedge_Level_Cover;
  if(cover_level > 0)
  {
    int filled_open_levels = 0;
    int total_levels = ArraySize(signal_params.grid_orders);
    for(int i = 0; i < total_levels; i++)
    {
      GridOrderState state = signal_params.grid_orders[i];
      if(!state.opens_position)
        continue;
      if(state.position_ticket > 0 &&
         (state.status == GRID_ORDER_ACTIVE || state.status == GRID_ORDER_TP_TRAILING_ACTIVE))
        filled_open_levels++;
    }

    if(filled_open_levels >= cover_level)
    {
      double grid_profit = GridCollectSignalFloatingProfitWithoutHedge(signal_params);
      if(grid_profit > 0.0)
      {
        double point_size = GridResolvePointSize();
        GridCloseAllLevels(signal_params, point_size);
        GridCloseHedgePosition(signal_params, "HEDGE_COVER_CLOSE", true);
        signal_params.signal_state = CLOSED;
        return true;
      }
    }
  }

  return false;
}

#endif // _GRID_TREND_RISK_HEDGE_MQH_
