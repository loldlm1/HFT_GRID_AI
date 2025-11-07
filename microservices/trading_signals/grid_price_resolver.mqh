#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_

// Relies on the include cascade to provide SignalParams, GridOrderState, etc.

double GridComputeFallbackNextPrice(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const int level_index,
                                    const double point_size)
{
  int ignore_index = level_index;

  double reference_price = order_state.entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);

  double resolved_point_size = point_size;
  if(resolved_point_size <= 0.0)
    resolved_point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(resolved_point_size <= 0.0)
    resolved_point_size = 0.0001;

  if(order_state.next_level_price > 0.0)
    return order_state.next_level_price;

  double distance_points = order_state.base_distance_points;
  if(distance_points <= 0.0)
    distance_points = order_state.pending_distance_points;
  if(distance_points <= 0.0)
    distance_points = EnforceBrokerDistance(g_symbol_constraints, signal_params.grid_base_distance_points);

  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);
  if(direction_mult == 0.0 || reference_price <= 0.0)
    return 0.0;

  return reference_price + direction_mult * distance_points * resolved_point_size;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_PRICE_RESOLVER_MQH_
