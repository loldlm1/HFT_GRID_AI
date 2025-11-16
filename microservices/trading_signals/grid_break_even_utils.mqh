#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_BREAK_EVEN_UTILS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_BREAK_EVEN_UTILS_MQH_

double GridResolveBreakEvenBufferPoints()
{
  double buffer_points = g_points_spread +
                         g_symbol_constraints.freeze_level_points +
                         g_symbol_constraints.stops_level_points;

  if(buffer_points <= 0.0)
  {
    double fallback = g_symbol_constraints.min_stop_distance_points;
    if(fallback <= 0.0)
      fallback = EnforceBrokerDistance(g_symbol_constraints, 1.0);
    buffer_points = fallback;
  }
  return buffer_points;
}

bool GridBreakEvenTriggered(GridOrderState &state,
                            const SignalTypes direction,
                            const double current_price)
{
  if(!state.break_even_active || state.break_even_price <= 0.0)
    return false;
  if(state.status != GRID_ORDER_ACTIVE)
    return false;

  if(direction == BULLISH)
    return (current_price <= state.break_even_price);
  if(direction == BEARISH)
    return (current_price >= state.break_even_price);
  return false;
}

void GridApplyBreakEven(SignalParams &signal_params,
                        const double point_size)
{
  if(!Grid_Enable_Spread_BreakEven)
    return;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return;
  if(point_size <= 0.0)
    return;

  // Clear stale flags on inactive levels
  for(int idx = 0; idx < total_levels; idx++)
  {
    if(signal_params.grid_orders[idx].status != GRID_ORDER_ACTIVE)
    {
      signal_params.grid_orders[idx].break_even_active = false;
      signal_params.grid_orders[idx].break_even_price  = 0.0;
    }
  }

  double buffer_points = GridResolveBreakEvenBufferPoints();
  if(buffer_points <= 0.0)
    return;

  double price_offset = buffer_points * point_size;
  SignalTypes direction = signal_params.signal_type;
  double current_price  = GridCurrentPriceForDirection(direction, false);

  int target_level = -1;
  double target_break_even_price = 0.0;

  for(int i = total_levels - 1; i >= 0; i--)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status != GRID_ORDER_ACTIVE)
      continue;
    if(state.entry_price <= 0.0)
      continue;

    double candidate = (direction == BULLISH)
                       ? state.entry_price + price_offset
                       : state.entry_price - price_offset;

    bool triggered = (direction == BULLISH)
                     ? (current_price >= candidate)
                     : (current_price <= candidate);
    if(triggered)
    {
      target_level = i;
      target_break_even_price = candidate;
      break;
    }
  }

  if(target_level < 0 || target_break_even_price <= 0.0)
    return;

  if(Grid_BreakEven_Deep_Mode == CONSERVATIVE_DEEP_LEVELS_BE)
  {
    for(int j = 0; j <= target_level && j < total_levels; j++)
    {
      signal_params.grid_orders[j].break_even_active = true;
      signal_params.grid_orders[j].break_even_price  = target_break_even_price;
    }
  }
  else
  {
    bool assigned = false;
    if(total_levels > 0)
    {
      GridOrderState root_state = signal_params.grid_orders[0];
      if(root_state.status == GRID_ORDER_ACTIVE && root_state.entry_price > 0.0)
      {
        signal_params.grid_orders[0].break_even_active = true;
        signal_params.grid_orders[0].break_even_price  = target_break_even_price;
        assigned = true;
      }
    }
    if(assigned)
    {
      for(int j = 1; j < total_levels; j++)
      {
        signal_params.grid_orders[j].break_even_active = false;
        signal_params.grid_orders[j].break_even_price  = 0.0;
      }
    }
  }
}

bool GridCheckBreakEvenExit(SignalParams &signal_params)
{
  if(!Grid_Enable_Spread_BreakEven)
    return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return false;

  SignalTypes direction = signal_params.signal_type;
  double current_price  = GridCurrentPriceForDirection(direction, false);

  bool should_close = false;

  if(Grid_BreakEven_Deep_Mode == CONSERVATIVE_DEEP_LEVELS_BE)
  {
    for(int i = total_levels - 1; i >= 0; i--)
    {
      GridOrderState state = signal_params.grid_orders[i];
      if(GridBreakEvenTriggered(state, direction, current_price))
      {
        should_close = true;
        break;
      }
    }
  }
  else if(total_levels > 0)
  {
    GridOrderState root_state = signal_params.grid_orders[0];
    if(GridBreakEvenTriggered(root_state, direction, current_price))
      should_close = true;
  }

  if(should_close)
  {
    double point_size = GridResolvePointSize();
    GridCloseAllLevels(signal_params, point_size);
    GridLogEvent("BREAK_EVEN_EXIT", signal_params, signal_params.grid_orders[total_levels-1]);
    return true;
  }

  return false;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_BREAK_EVEN_UTILS_MQH_
