//+------------------------------------------------------------------+
//|                        microservices/trading_signals/... math    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_MATH_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_MATH_MQH_
// grid_price_resolver is provided earlier in the trading_signals cascade

double GridResolvePendingPoints(const GridOrderState &state)
{
  return GridPlanResolvePendingPoints(state);
}

double GridResolveTrailingStopPrice(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size,
                                    const double close_price,
                                    double &resolved_offset_points,
                                    string &basis_out,
                                    string &reason_out)
{
  resolved_offset_points = 0.0;
  basis_out = "";
  reason_out = "";

  double trailing_percent = MathMax(Grid_Trailing_TP_Percent, 0.0);
  if(trailing_percent <= 0.0)
    return 0.0;

  double reference_points = order_state.tp_reference_points;
  if(reference_points <= 0.0 && order_state.entry_price > 0.0 && point_size > 0.0)
  {
    double reference_price = order_state.take_profit_price;
    if(reference_price <= 0.0)
      reference_price = order_state.next_level_price;
    if(reference_price <= 0.0)
      reference_price = GridComputeFallbackNextPrice(signal_params,
                                                     order_state,
                                                     order_state.level_index,
                                                     point_size);
    if(reference_price > 0.0)
      reference_points = MathAbs(order_state.entry_price - reference_price) / point_size;
  }

  if(reference_points <= 0.0)
    return 0.0;

  double offset_fraction = 1.0 - (trailing_percent / 100.0);
  if(offset_fraction < 0.0)
    offset_fraction = 0.0;

  resolved_offset_points = reference_points * offset_fraction;
  if(resolved_offset_points <= 0.0)
    resolved_offset_points = reference_points;

  basis_out = "TP";
  GridAppendReason(reason_out, "tp_reference");
  if(trailing_percent > 0.0)
    GridAppendReason(reason_out, "tp_percent");

  double requested_offset = resolved_offset_points;
  resolved_offset_points = EnforceBrokerDistance(g_symbol_constraints, resolved_offset_points);
  if(resolved_offset_points > requested_offset + 1e-9)
    GridAppendReason(reason_out, "broker_min");

  if(resolved_offset_points <= 0.0 || point_size <= 0.0 || close_price <= 0.0)
    return 0.0;

  double direction_mult = GridResolveDirectionMultiplier(direction);
  double requested_price = close_price - direction_mult * resolved_offset_points * point_size;
  double rounded_price = requested_price;

  double effective_tick = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                                   g_symbol_constraints.point_size);
  if(effective_tick > 0.0 && requested_price > 0.0)
  {
    double ticks = requested_price / effective_tick;
    if(direction == BULLISH)
      rounded_price = MathFloor(ticks + 1e-9) * effective_tick;
    else
      rounded_price = MathCeil(ticks - 1e-9) * effective_tick;
    if(MathAbs(rounded_price - requested_price) > 1e-9)
      GridAppendReason(reason_out, "tick_round");
  }

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;
  double trailing_price = NormalizeDouble(rounded_price, digits);

  return trailing_price;
}

void GridUpdateNextLevelPrice(const SignalTypes direction,
                              GridOrderState &order_state,
                              const double point_size,
                              const double current_price)
{
  double direction_mult = GridResolveDirectionMultiplier(direction);
  double reference_distance = order_state.base_distance_points;
  if(reference_distance <= 0.0)
    reference_distance = order_state.pending_distance_points;

  if(reference_distance <= 0.0 || point_size <= 0.0 || direction_mult == 0.0)
    return;

  double candidate_price = current_price - direction_mult * reference_distance * point_size;

  if(order_state.next_level_price == 0.0)
  {
    order_state.next_level_price = candidate_price;
    return;
  }

  if(direction == BULLISH)
  {
    if(candidate_price < order_state.next_level_price)
      order_state.next_level_price = candidate_price;
  }
  else if(direction == BEARISH)
  {
    if(candidate_price > order_state.next_level_price)
      order_state.next_level_price = candidate_price;
  }
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_MATH_MQH_
