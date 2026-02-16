#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;
  if(signal_params.signal_state == CLOSED)
    return;

  double         point_size        = GridResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            grid_order_level  = ArraySize(signal_params.grid_orders)-1;
  GridOrderState grid_order        = signal_params.grid_orders[grid_order_level];

  if(LimitSignalExpiredOnStructureChange(signal_params))
  {
    signal_params.signal_state = CLOSED;
    GridLogEvent("LIMIT_EXPIRED_STRUCTURE", signal_params, grid_order);
    return;
  }

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    if(UpdateGridOrderForSignal(signal_params))
      grid_order = signal_params.grid_orders[grid_order_level];

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);
    double entry_side_price = GridCurrentPriceForDirection(direction, true);
    bool use_limit_edge_activation = UsesNonBreakoutLimitEdgeActivation(signal_params, grid_order);

    if(use_limit_edge_activation && !grid_order.limit_activation_armed)
    {
      if(ShouldArmNonBreakoutLimitActivation(signal_params, grid_order, entry_side_price))
      {
        grid_order.limit_activation_armed = true;
        signal_params.grid_orders[grid_order_level] = grid_order;
        GridLogEvent("LIMIT_EDGE_ARMED", signal_params, grid_order);
      }
    }

    bool can_activate = (!use_limit_edge_activation || grid_order.limit_activation_armed);
    if(can_activate &&
       GridShouldActivateStopOrder(signal_params, grid_order, direction))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        grid_order = signal_params.grid_orders[grid_order_level];
        GridLogEvent("LEVEL_REACHED", signal_params, grid_order);
      }
    }
  }

  grid_order = signal_params.grid_orders[grid_order_level];

  if(grid_order.status == GRID_ORDER_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    if(grid_order.take_profit_price > 0.0)
    {
      bool hit_tp = (direction == BULLISH && current_price >= grid_order.take_profit_price) ||
                    (direction == BEARISH && current_price <= grid_order.take_profit_price);
      if(hit_tp)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_TP_HIT", signal_params, grid_order);
        return;
      }
    }
    if(GridShouldActivateNextLevelLimit(signal_params, grid_order, direction))
    {
      bool level_limit_hit = ShouldBlockNextLevelByStopLimit(Grid_Level_Stop_Limit,
                                                             grid_order.level_index);

      if(level_limit_hit)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("GRID_STOP_LEVEL_LIMIT", signal_params, grid_order);
      }
      else
      {
        BuildGridOrderForSignal(signal_params);
        GridLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, grid_order);
      }
    }
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
