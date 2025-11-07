#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return;

  // INITIAL GRID START AT 0 ARRAY INDEX
  signal_params.grid_orders[0].level_index             = 0; // INITIAL GRID POSITION, NEXT LEVEL IS 1..N
  signal_params.grid_orders[0].status                  = GRID_ORDER_STOP_TRAILING_ACTIVE; // INITIAL ORDER STARTS WITH BUY/SELL STOP
  signal_params.grid_orders[0].base_distance_points    = signal_params.grid_base_distance_points;
  signal_params.grid_orders[0].pending_distance_points = signal_params.grid_base_distance_points;
  signal_params.grid_orders[0].entry_offset_points     = signal_params.grid_entry_offset_points;
  signal_params.grid_orders[0].lot_size                = signal_params.grid_base_lot_size;
  signal_params.grid_orders[0].entry_reference_price   = GetGridStopReferencePrice(signal_params.signal_type, signal_params.grid_orders[0]);
  signal_params.grid_orders[0].next_level_price        = GetGridNextLevelPrice(signal_params.signal_type, signal_params.grid_orders[0]);
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  double point_size = GridResolvePointSize();
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, state.lot_size);

    switch(state.status)
    {
      case GRID_ORDER_WAITING:
      {
        string guardrail_reason = "";
        if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
        {
          GridInitializePendingLevel(signal_params, direction, state, point_size);
          GridLogEvent("LEVEL_PENDING", signal_params, state);
        }
        else if(guardrail_reason != "")
        {
          GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, state, guardrail_reason);
        }
        break;
      }

      case GRID_ORDER_STOP_TRAILING_ACTIVE:
      {
        double previous_stop = state.next_level_price;
        if(GridRefreshStopTriggerFromAtr(signal_params, state, point_size))
        {
          if(previous_stop > 0.0 &&
             MathAbs(state.next_level_price - previous_stop) >= point_size)
          {
            GridLogEvent("LEVEL_PENDING_UPDATE", signal_params, state);
          }
        }

        if(GridShouldActivatePendingLevel(signal_params, state, direction, point_size))
        {
          if(GridExecuteLevelTrade(signal_params, state, point_size, normalized_volume))
          {
            GridLogEvent("LEVEL_FILLED", signal_params, state);
            GridScheduleNextLevel(signal_params, i + 1);
          }
        }
        break;
      }

      case GRID_ORDER_ACTIVE:
      {
        double current_price = GridCurrentPriceForDirection(direction, false);
        bool close_order = false;

        if(state.take_profit_price > 0.0)
        {
          if(direction == BULLISH && current_price >= state.take_profit_price)
            close_order = true;
          if(direction == BEARISH && current_price <= state.take_profit_price)
            close_order = true;
        }

        if(close_order)
        {
          GridFinalizeLevel(direction, state, point_size, current_price);
          GridLogEvent("LEVEL_COMPLETED", signal_params, state);
        }
        break;
      }

      default:
        break;
    }

    signal_params.grid_orders[i] = state;
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
