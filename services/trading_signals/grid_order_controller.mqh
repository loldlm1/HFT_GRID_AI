#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  // Refresh pending geometry (entry_reference/next_level) before lifecycle steps
  UpdateGridOrderForSignal(signal_params);

  double      point_size   = GridResolvePointSize();
  SignalTypes direction    = signal_params.signal_type;
  int         total_levels = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState grid_order        = signal_params.grid_orders[i];
    double         normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);

    switch(grid_order.status)
    {
      case GRID_ORDER_STOP_TRAILING_ACTIVE:
      {
        if(GridShouldActivatePendingLevel(signal_params, grid_order, direction, point_size))
        {
          if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
          {
            BuildGridOrderForSignal(signal_params);
            GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
          }
        }
      }

      case GRID_ORDER_ACTIVE:
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
            break;
          }
        }
        if(ShouldSwitchToTrailingTP(direction, grid_order, current_price))
        {
          grid_order.status = GRID_ORDER_TP_TRAILING_ACTIVE;
          grid_order.tp_reached = true;
          grid_order.is_trailing_active = true;
          UpdateTrailingTP(signal_params, grid_order, current_price, point_size);
          GridLogEvent("TP_TRAILING_START", signal_params, grid_order);
        }
      }

      case GRID_ORDER_TP_TRAILING_ACTIVE:
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
            break;
          }
        }
        UpdateTrailingTP(signal_params, grid_order, current_price, point_size);

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
          GridFinalizeLevel(direction, grid_order, point_size, current_price);
          GridLogEvent("GRID_ORDER_TP_TRAILING_ACTIVE -> GRID_ORDER_COMPLETED", signal_params, grid_order);
        }
      }

      default:
        break;
    }

    signal_params.grid_orders[i] = grid_order;
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
