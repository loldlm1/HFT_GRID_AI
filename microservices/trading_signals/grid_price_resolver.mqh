#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_

// Relies on the include cascade to provide SignalParams, GridOrderState,
// GridLevelPlan, Strategy_Timeframe, and ExtATRIndicatorsHandle.

double GridComputeFallbackNextPrice(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const int level_index,
                                    const double point_size)
{
  double resolved_point_size = point_size;
  if(resolved_point_size <= 0.0)
    resolved_point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(resolved_point_size <= 0.0)
    resolved_point_size = 0.0001;

  GridLevelPlan level_plan = GridLevelPlan();
  if(level_index >= 0 && level_index < ArraySize(signal_params.grid_plan.levels))
    level_plan = signal_params.grid_plan.levels[level_index];

  double anchor_price = level_plan.anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = order_state.anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = signal_params.grid_plan.base_anchor_price;

  double distance_points = level_plan.distance_points;
  if(distance_points <= 0.0)
    distance_points = level_plan.baseline_distance_points;
  if(distance_points <= 0.0)
  {
    double base_distance = signal_params.grid_plan.base_distance_points;
    double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
    int effective_index = level_index;
    if(effective_index < 0)
      effective_index = 0;
    distance_points = base_distance * MathPow(exponential_multiplier, effective_index);
  }

  if(anchor_price <= 0.0 || distance_points <= 0.0 || resolved_point_size <= 0.0)
    return 0.0;

  double direction_mult = 0.0;
  if(signal_params.signal_type == BULLISH)
    direction_mult = 1.0;
  else if(signal_params.signal_type == BEARISH)
    direction_mult = -1.0;
  if(direction_mult == 0.0)
    return 0.0;

  return anchor_price + direction_mult * distance_points * resolved_point_size;
}

bool GridResolveAtrAnchorPrice(const SignalTypes direction,
                               const int shift,
                               double &anchor_price)
{
  anchor_price = 0.0;
  if(shift < 0)
    return false;

  int total_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_handles <= 0)
    return false;

  int buffer_index = (direction == BULLISH) ? 1 : 0;
  for(int i = 0; i < total_handles; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe != Strategy_Timeframe)
      continue;

    double atr_buffer[];
    if(CopyBuffer(ExtATRIndicatorsHandle[i].indicator_handle,
                  buffer_index,
                  shift,
                  1,
                  atr_buffer) <= 0)
      return false;

    anchor_price = atr_buffer[0];
    return (anchor_price > 0.0);
  }

  return false;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_
