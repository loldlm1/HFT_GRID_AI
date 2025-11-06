#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_

double GridResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double GridResolveDirectionMultiplier(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

double GridCurrentPriceForDirection(const SignalTypes direction,
                                    const bool use_entry_side)
{
  if(direction == BULLISH)
    return use_entry_side ? g_ask : g_bid;
  return use_entry_side ? g_bid : g_ask;
}

bool GridGuardrailsAllowOrder(const double normalized_volume,
                              string &reason)
{
  reason = "";
  if(g_points_spread > Max_Spread)
  {
    reason = StringFormat("spread=%.1f>%.1f",
                          g_points_spread,
                          Max_Spread);
    return false;
  }

  double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(free_margin <= 0.0)
    return true;

  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot <= 0.0)
  {
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price         = GridCurrentPriceForDirection(BULLISH, true);
    double leverage      = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(contract_size > 0.0 && leverage > 0.0)
      margin_per_lot = (contract_size * price) / leverage;
  }

  if(margin_per_lot <= 0.0)
    return true;

  double required_margin = margin_per_lot * normalized_volume;
  if(required_margin <= 0.0)
    return true;

  if(free_margin < required_margin)
  {
    reason = StringFormat("margin=%.2f<%.2f",
                          free_margin,
                          required_margin);
    return false;
  }

  return true;
}

bool GridGuardrailsAllowOrder(const double normalized_volume)
{
  string reason = "";
  return GridGuardrailsAllowOrder(normalized_volume, reason);
}

void GridAppendReason(string &target,
                      const string token)
{
  if(token == "")
    return;
  if(target == "")
  {
    target = token;
    return;
  }
  target = target + ";" + token;
}

string GridComposeLevelComment(const SignalParams &signal_params,
                               const GridOrderState &order_state)
{
  string direction_label = (signal_params.signal_type == BULLISH) ? "B" : "S";
  string time_label      = IntegerToString((long)signal_params.entry_time);
  return StringFormat("GRID_%s_%s_L%d", direction_label, time_label, order_state.level_index);
}

void GridEnsureOrderState(SignalParams &signal_params,
                          const int level_index)
{
  if(level_index < 0)
    return;

  int current_total = ArraySize(signal_params.grid_orders);
  if(current_total > level_index)
    return;

  int target_total = level_index + 1;
  ArrayResize(signal_params.grid_orders, target_total);
  for(int i = current_total; i < target_total; i++)
  {
    GridOrderState state = GridOrderState();
    state.level_index = i;
    signal_params.grid_orders[i] = state;
  }
}

void GridResetOrderStateForWaiting(GridOrderState &state,
                                   const GridLevelPlan &level_plan)
{
  int level_index = state.level_index;
  state = GridOrderState();
  state.level_index     = level_index;
  state.status          = GRID_ORDER_WAITING;
  state.trailing_points = level_plan.trailing_points;
  state.resolved_distance_points = level_plan.distance_points;
  state.grid_range_percent = -1.0;
}

void GridScalePlannedLevels(SignalParams &signal_params,
                            const double scaling_factor,
                            const int from_level_index)
{
  if(from_level_index < 0)
    return;
  if(scaling_factor <= 0.0)
    return;
  if(MathAbs(scaling_factor - 1.0) < 1e-6)
    return;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = from_level_index; i < levels_total; i++)
  {
    GridLevelPlan plan = signal_params.grid_plan.levels[i];
    plan.distance_points           *= scaling_factor;
    plan.baseline_distance_points  *= scaling_factor;
    plan.pending_order_points      *= scaling_factor;
    plan.entry_offset_points       *= scaling_factor;
    plan.protective_stop_points    *= scaling_factor;
    plan.activation_points         *= scaling_factor;
    plan.activation_offset_points  *= scaling_factor;
    plan.take_profit_points        *= scaling_factor;
    plan.final_take_profit_points  *= scaling_factor;
    plan.trailing_points           *= scaling_factor;
    plan.next_resolved_price       = 0.0;
    plan.next_price_side           = "";
    plan.next_price_source         = "";
    plan.next_price_clamp_reason   = "";
    signal_params.grid_plan.levels[i] = plan;
  }
}

void GridRecalculateRangeMetrics(SignalParams &signal_params,
                                 const double point_size)
{
  int total_orders = ArraySize(signal_params.grid_orders);
  double range_high_price = 0.0;
  double range_low_price  = 0.0;
  bool   has_active       = false;
  int    active_levels    = 0;

  double temp_percents[];
  ArrayResize(temp_percents, total_orders);
  ArrayInitialize(temp_percents, -1.0);

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status != GRID_ORDER_ACTIVE || state.entry_price <= 0.0)
      continue;

    if(!has_active)
    {
      range_high_price = state.entry_price;
      range_low_price  = state.entry_price;
      has_active       = true;
    }
    else
    {
      if(state.entry_price > range_high_price)
        range_high_price = state.entry_price;
      if(state.entry_price < range_low_price)
        range_low_price = state.entry_price;
    }

    active_levels++;
  }

  if(!has_active)
  {
    signal_params.grid_plan.range_high_price = 0.0;
    signal_params.grid_plan.range_low_price  = 0.0;
    signal_params.grid_stats.current_range_points = 0.0;

    for(int i = 0; i < total_orders; i++)
    {
      GridOrderState state = signal_params.grid_orders[i];
      state.grid_range_percent = -1.0;
      signal_params.grid_orders[i] = state;

      if(i < ArraySize(signal_params.grid_plan.levels))
      {
        GridLevelPlan plan = signal_params.grid_plan.levels[i];
        plan.grid_range_percent = -1.0;
        signal_params.grid_plan.levels[i] = plan;
      }
    }
    return;
  }

  signal_params.grid_plan.range_high_price = range_high_price;
  signal_params.grid_plan.range_low_price  = range_low_price;

  double range_span_price = range_high_price - range_low_price;
  if(range_span_price <= 0.0 || active_levels < 2)
  {
    signal_params.grid_stats.current_range_points = 0.0;
    for(int i = 0; i < total_orders; i++)
    {
      GridOrderState state = signal_params.grid_orders[i];
      state.grid_range_percent = -1.0;
      signal_params.grid_orders[i] = state;

      if(i < ArraySize(signal_params.grid_plan.levels))
      {
        GridLevelPlan plan = signal_params.grid_plan.levels[i];
        plan.grid_range_percent = state.grid_range_percent;
        signal_params.grid_plan.levels[i] = plan;
      }
    }
    return;
  }

  double range_span_points = 0.0;
  if(point_size > 0.0)
    range_span_points = range_span_price / point_size;
  signal_params.grid_stats.current_range_points = MathAbs(range_span_points);

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status != GRID_ORDER_ACTIVE || state.entry_price <= 0.0)
      continue;

    double percent = (state.entry_price - range_low_price) / range_span_price * 100.0;
    if(percent < 0.0)
      percent = 0.0;
    if(percent > 100.0)
      percent = 100.0;
    temp_percents[i] = percent;
  }

  bool should_invert = false;
  if(total_orders > 0)
  {
    GridOrderState base_state = signal_params.grid_orders[0];
    if(base_state.status == GRID_ORDER_ACTIVE &&
       temp_percents[0] >= 0.0 &&
       temp_percents[0] < 50.0)
      should_invert = true;
  }

  if(should_invert)
  {
    for(int i = 0; i < total_orders; i++)
    {
      if(temp_percents[i] >= 0.0)
        temp_percents[i] = 100.0 - temp_percents[i];
    }
  }

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(temp_percents[i] >= 0.0)
      state.grid_range_percent = temp_percents[i];
    else
      state.grid_range_percent = -1.0;
    signal_params.grid_orders[i] = state;

    if(i < ArraySize(signal_params.grid_plan.levels))
    {
      GridLevelPlan plan = signal_params.grid_plan.levels[i];
      plan.grid_range_percent = state.grid_range_percent;
      signal_params.grid_plan.levels[i] = plan;
    }
  }
}

double GridPointsBetween(const SignalTypes direction,
                         const double reference_price,
                         const double candidate_price,
                         const double point_size)
{
  if(point_size <= 0.0)
    return 0.0;

  if(direction == BULLISH)
    return (reference_price - candidate_price) / point_size;
  return (candidate_price - reference_price) / point_size;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
