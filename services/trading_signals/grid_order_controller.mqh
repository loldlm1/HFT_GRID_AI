#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
  {
    GridOrderState grid_order;
    AddElementToArray(signal_params.grid_orders, grid_order);
  }

  // INITIAL GRID START AT 0 ARRAY INDEX
  signal_params.grid_orders[0].level_index             = 0; // INITIAL GRID POSITION, NEXT LEVEL IS 1..N
  signal_params.grid_orders[0].status                  = GRID_ORDER_STOP_TRAILING_ACTIVE; // INITIAL ORDER STARTS WITH BUY/SELL STOP
  signal_params.grid_orders[0].lot_size                = signal_params.grid_base_lot_size;
  signal_params.grid_orders[0].entry_reference_price   = GetGridStopReferencePrice(signal_params.signal_type, signal_params, signal_params.grid_orders[0]);
  signal_params.grid_orders[0].next_level_price        = GetGridNextLevelPrice(signal_params.signal_type, signal_params, signal_params.grid_orders[0]);
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  double      point_size   = GridResolvePointSize();
  SignalTypes direction    = signal_params.signal_type;
  int         total_levels = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState grid_order        = signal_params.grid_orders[i];
    double         normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);

    switch(grid_order.status)
    {
      case GRID_ORDER_WAITING:
      {
        string guardrail_reason = "";
        if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
        {
          grid_order.status = GRID_ORDER_STOP_TRAILING_ACTIVE;
          GridLogEvent("GRID_ORDER_WAITING -> GRID_ORDER_STOP_TRAILING_ACTIVE", signal_params, grid_order);
        }
        else if(guardrail_reason != "")
        {
          GridLogGuardrailBlock("GRID_ORDER_WAITING -> ACTIVATION_BLOCKED", signal_params, grid_order, guardrail_reason);
        }
      }

      case GRID_ORDER_STOP_TRAILING_ACTIVE:
      {
        if(GridShouldActivatePendingLevel(signal_params, grid_order, direction, point_size))
        {
          if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
          {
            GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
          }
        }
      }

      case GRID_ORDER_ACTIVE:
      {
        double current_price = GridCurrentPriceForDirection(direction, false);
        bool   close_order   = false;

        if(grid_order.take_profit_price > 0.0)
        {
          if(direction == BULLISH && current_price >= grid_order.take_profit_price)
            close_order = true;
          if(direction == BEARISH && current_price <= grid_order.take_profit_price)
            close_order = true;
        }

        if(close_order)
        {
          GridFinalizeLevel(direction, grid_order, point_size, current_price);
          GridLogEvent("GRID_ORDER_ACTIVE -> GRID_ORDER_COMPLETED", signal_params, grid_order);
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
