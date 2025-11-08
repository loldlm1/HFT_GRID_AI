#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  double         point_size        = GridResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            grid_order_level  = ArraySize(signal_params.grid_orders)-1;
  GridOrderState grid_order        = signal_params.grid_orders[grid_order_level];
  double         normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    UpdateGridOrderForSignal(signal_params);

    if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
      }
    }
  }

  if(grid_order.status == GRID_ORDER_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid
    if(grid_order.final_take_profit_price > 0.0)
    {
      bool hit_final = (direction == BULLISH && current_price >= grid_order.final_take_profit_price) ||
                        (direction == BEARISH && current_price <= grid_order.final_take_profit_price);
      if(hit_final)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_FINAL_TP", signal_params, grid_order);
      }
    }
    if(ShouldSwitchToTrailingTP(direction, grid_order, current_price))
    {
      grid_order.status             = GRID_ORDER_TP_TRAILING_ACTIVE;
      grid_order.tp_reached         = true;
      grid_order.is_trailing_active = true;
      UpdateTrailingTP(signal_params, grid_order, grid_order_level, current_price, point_size);
      GridLogEvent("TP_TRAILING_START", signal_params, grid_order);
    }
    if(GridShouldActivateNextLevelLimit(signal_params, grid_order, direction, point_size))
    {
      BuildGridOrderForSignal(signal_params);
      GridLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, grid_order);
    }
  }

  if(grid_order.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid even while trailing
    if(grid_order.final_take_profit_price > 0.0)
    {
      bool hit_final = (direction == BULLISH && current_price >= grid_order.final_take_profit_price) ||
                        (direction == BEARISH && current_price <= grid_order.final_take_profit_price);
      if(hit_final)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_FINAL_TP", signal_params, grid_order);
      }
    }
    UpdateTrailingTP(signal_params, grid_order, grid_order_level, current_price, point_size);
    Print(grid_order.trailing_price);

    bool exit_on_trail = false;
    if(grid_order.trailing_price > 0.0)
    {
      if(direction == BULLISH && current_price <= grid_order.trailing_price)
        exit_on_trail = true;
      if(direction == BEARISH && current_price >= grid_order.trailing_price)
        exit_on_trail = true;
    }
    if(exit_on_trail)
    {
      GridCloseAllLevels(signal_params, point_size);
      GridLogEvent("EXIT_ON_TRAILING", signal_params, grid_order);
    }
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
