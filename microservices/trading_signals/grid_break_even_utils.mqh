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

bool GridBreakEvenTriggered(const GridOrderState &state,
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

bool GridLevelReachedTakeProfit(const GridOrderState &state,
                                const SignalTypes direction,
                                const double current_price)
{
  if(state.take_profit_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return current_price >= state.take_profit_price;
  if(direction == BEARISH)
    return current_price <= state.take_profit_price;
  return false;
}

double GridResolveBreakEvenPrice(const GridOrderState &state,
                                 const SignalTypes direction,
                                 const double point_size)
{
  if(state.entry_price <= 0.0 || point_size <= 0.0)
    return 0.0;

  double buffer_points = GridResolveBreakEvenBufferPoints();
  double price_offset  = buffer_points * point_size;

  if(direction == BULLISH)
    return state.entry_price + price_offset;
  if(direction == BEARISH)
    return state.entry_price - price_offset;
  return 0.0;
}

void GridAssignBreakEvenToLevels(SignalParams &signal_params,
                                 const int upto_index,
                                 const double break_even_price)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(break_even_price <= 0.0 || total_levels <= 0)
    return;

  int limit = (upto_index < total_levels) ? upto_index : (total_levels - 1);
  for(int idx = 0; idx <= limit; idx++)
  {
    if(signal_params.grid_orders[idx].status != GRID_ORDER_ACTIVE)
      continue;
    signal_params.grid_orders[idx].break_even_active = true;
    signal_params.grid_orders[idx].break_even_price  = break_even_price;
  }
}

void GridAttemptPartialTake(SignalParams &signal_params,
                            const int level_index)
{
  if(level_index < 0 || level_index >= ArraySize(signal_params.grid_orders))
    return;

  GridOrderState state = signal_params.grid_orders[level_index];
  if(state.partial_take_executed)
  {
    signal_params.grid_orders[level_index] = state;
    return;
  }

  state.partial_take_executed = true;
  signal_params.grid_orders[level_index] = state;

  double partial_ratio = MathMax(MathMin(Grid_Partial_Take_Percentage, 100.0), 0.0) / 100.0;
  if(partial_ratio <= 0.0)
    return;
  if(state.position_ticket <= 0)
    return;
  if(!PositionSelectByTicket(state.position_ticket))
    return;

  double current_volume = PositionGetDouble(POSITION_VOLUME);
  if(current_volume <= 0.0)
    return;

  double desired_volume = current_volume * partial_ratio;
  double normalized_partial = NormalizeVolumeForSymbol(_Symbol, desired_volume);
  double volume_step = g_symbol_constraints.volume_step;
  if(volume_step <= 0.0)
    volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  if(volume_step <= 0.0)
    volume_step = 0.01;

  if(normalized_partial < volume_step)
    return;

  double min_volume = g_symbol_constraints.min_volume;
  if(min_volume <= 0.0)
    min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  if(min_volume <= 0.0)
    min_volume = volume_step;

  double remaining = current_volume - normalized_partial;
  if(remaining > 0.0 && remaining < min_volume)
    return;
  if(remaining < 0.0 || normalized_partial >= current_volume)
    return;

  if(!g_position.PositionClosePartial(state.position_ticket, normalized_partial))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("BREAK_EVEN_PARTIAL_FAIL", retcode, last_error, true);
    return;
  }

  if(PositionSelectByTicket(state.position_ticket))
  {
    double new_volume = PositionGetDouble(POSITION_VOLUME);
    signal_params.grid_orders[level_index].lot_size = new_volume;
  }

  GridLogEvent("BREAK_EVEN_PARTIAL_TAKE", signal_params, signal_params.grid_orders[level_index]);
}

void GridProcessBreakEven(SignalParams &signal_params)
{
  if(Grid_BreakEven_Mode == BE_DISABLE)
    return;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return;

  double point_size = GridResolvePointSize();
  if(point_size <= 0.0)
    return;

  for(int idx = 0; idx < total_levels; idx++)
  {
    if(signal_params.grid_orders[idx].status != GRID_ORDER_ACTIVE)
    {
      signal_params.grid_orders[idx].break_even_active = false;
      signal_params.grid_orders[idx].break_even_price  = 0.0;
    }
  }

  SignalTypes direction = signal_params.signal_type;
  double current_price  = GridCurrentPriceForDirection(direction, false);
  double tolerance      = point_size * 0.1;
  if(tolerance <= 0.0)
    tolerance = 0.00001;

  for(int level = total_levels - 1; level >= 0; level--)
  {
    GridOrderState current_state = signal_params.grid_orders[level];
    if(current_state.status != GRID_ORDER_ACTIVE)
      continue;
    if(current_state.entry_price <= 0.0 || current_state.take_profit_price <= 0.0)
      continue;

    if(!GridLevelReachedTakeProfit(current_state, direction, current_price))
      continue;

    double break_even_price = GridResolveBreakEvenPrice(current_state, direction, point_size);
    if(break_even_price <= 0.0)
      break;

    bool needs_update = !current_state.break_even_active ||
                        MathAbs(current_state.break_even_price - break_even_price) > tolerance;
    bool needs_partial = (Grid_BreakEven_Mode == BE_PARTIAL_ENABLE &&
                          !current_state.partial_take_executed);

    if(!needs_update && !needs_partial)
      continue;

    GridAssignBreakEvenToLevels(signal_params, level, break_even_price);
    if(needs_update)
      GridLogEvent("BREAK_EVEN_ARMED", signal_params, current_state);

    if(Grid_BreakEven_Mode == BE_PARTIAL_ENABLE)
      GridAttemptPartialTake(signal_params, level);
    break;
  }
}

bool GridCheckBreakEvenExit(SignalParams &signal_params)
{
  if(Grid_BreakEven_Mode == BE_DISABLE)
    return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return false;

  SignalTypes direction = signal_params.signal_type;
  double current_price  = GridCurrentPriceForDirection(direction, false);

  for(int i = total_levels - 1; i >= 0; i--)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(GridBreakEvenTriggered(state, direction, current_price))
    {
      double point_size = GridResolvePointSize();
      GridCloseAllLevels(signal_params, point_size);
      GridLogEvent("BREAK_EVEN_EXIT", signal_params, state);
      return true;
    }
  }

  return false;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_BREAK_EVEN_UTILS_MQH_
