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

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    if(UpdateGridOrderForSignal(signal_params))
      grid_order = signal_params.grid_orders[grid_order_level];

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);
    if(Grid_Lot_Type == GRID_LOT_MAX_MARGIN_SPLIT)
    {
      double aggressive_lot = GridResolveAggressiveLotSize(direction);
      if(aggressive_lot > 0.0)
      {
        normalized_volume = aggressive_lot;
        signal_params.grid_orders[grid_order_level].lot_size = aggressive_lot;
        grid_order.lot_size = aggressive_lot;
      }
    }

    if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        grid_order = signal_params.grid_orders[grid_order_level];
        GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
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
    if(GridShouldActivateNextLevelLimit(signal_params, grid_order, direction, point_size))
    {
      int current_levels = ArraySize(signal_params.grid_orders);
      int position_levels = GridCountPositionOpeningLevels(signal_params);
      bool next_level_opens_position = GridNextLevelOpensPosition(signal_params);
      bool level_limit_hit = (Grid_Level_Stop_Limit > 0 &&
                              next_level_opens_position &&
                              position_levels >= Grid_Level_Stop_Limit);

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
