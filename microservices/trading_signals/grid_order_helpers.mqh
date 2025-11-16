//+------------------------------------------------------------------+
//|                               microservices/trading_signals/... |
//+------------------------------------------------------------------+
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

ENUM_TIMEFRAMES GridResolvePrimaryStrategyTimeframe()
{
  int total = ArraySize(Strategy_TF_List);
  if(total > 0)
    return Strategy_TF_List[0];
  return Strategy_Timeframe;
}

bool GridResolveAlligatorLipsTrailingPrice(const SignalParams &signal_params,
                                           double &price_out)
{
  price_out = 0.0;
  int total = ArraySize(signal_params.alligator_data);
  if(total <= 0)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolvePrimaryStrategyTimeframe();

  for(int i = 0; i < total; i++)
  {
    AlligatorStructure data = signal_params.alligator_data[i];
    if(data.indicator_timeframe != target_tf)
      continue;
    double candidate = data.lips_prev_value;
    if(candidate > 0.0)
    {
      price_out = candidate;
      return true;
    }
  }

  double fallback = signal_params.alligator_data[0].lips_prev_value;
  if(fallback > 0.0)
  {
    price_out = fallback;
    return true;
  }
  return false;
}

bool GridResolveTrailingStrategyPrice(const SignalParams &signal_params,
                                      double &price_out)
{
  price_out = 0.0;

  if(Grid_Trailing_Strategy_Mode == TRAILING_ATR_BASED)
  {
    ENUM_TIMEFRAMES tf = GridResolvePrimaryStrategyTimeframe();
    return GridResolveAtrTrailingPrice(signal_params.signal_type, tf, price_out, 1);
  }

  if(Grid_Trailing_Strategy_Mode == TRAILING_LIPS_MA)
    return GridResolveAlligatorLipsTrailingPrice(signal_params, price_out);

  return false;
}

void GridResetOrderStateForWaiting(GridOrderState &state,
                                   const GridOrderState &template_state)
{
  int level_index = state.level_index;
  state = template_state;
  state.level_index        = level_index;
  state.status             = GRID_ORDER_WAITING;
  state.entry_price        = 0.0;
  state.take_profit_price  = 0.0;
  state.final_take_profit_price = 0.0;
  state.trailing_price     = 0.0;
  state.next_level_price   = template_state.next_level_price;
  state.last_action_time   = 0;
  state.is_trailing_active = false;
  state.tp_reached         = false;
  state.break_even_active  = false;
  state.break_even_price   = 0.0;
  state.position_ticket    = 0;
  state.position_comment   = "";
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

double GetGridStopReferencePrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double base_entry_price = GridCurrentPriceForDirection(direction, true);
  double stop_entry_price = grid_order_state.entry_reference_price;

  if(direction == BULLISH)
  {
    base_entry_price = base_entry_price + (signal_params.grid_entry_offset_points / g_decimal_digits);

    if(base_entry_price < stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE FALLS

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }
  if(direction == BEARISH)
  {
    base_entry_price = base_entry_price - (signal_params.grid_entry_offset_points / g_decimal_digits);

    if(base_entry_price > stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE ROCKET

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }

  return base_entry_price;
}

double GetGridNextLevelPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_pending_price  = 0;
  double grid_atr_fallback_price = 0;
  double grid_base_entry_price   = grid_order_state.entry_reference_price;
  double grid_next_level_price   = grid_order_state.next_level_price;
  // Recompute from entry_reference_price each tick using per-level distance
  double level_distance_pts      = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);

  if(direction == BULLISH)
  {
    grid_raw_pending_price = grid_base_entry_price - (level_distance_pts / g_decimal_digits);

    if(grid_raw_pending_price < grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE FALLS

    return grid_next_level_price == 0 ? grid_raw_pending_price : grid_next_level_price;
  }
  if(direction == BEARISH)
  {
    grid_raw_pending_price = grid_base_entry_price + (level_distance_pts / g_decimal_digits);

    if(grid_raw_pending_price > grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE ROCKET

    return grid_next_level_price == 0 ? grid_raw_pending_price : grid_next_level_price;
  }

  return grid_raw_pending_price;
}

double GetGridTakeProfitPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_tp_price            = 0;
  double grid_atr_fallback_price      = 0;
  int    grid_level_index             = grid_order_state.level_index;
  double grid_base_entry_price        = grid_order_state.entry_reference_price;
  double grid_take_profit_price       = grid_order_state.take_profit_price;
  // Per-level TP span based on exponential distance
  double level_distance_pts           = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);
  double tp_span_pts;
  if(Grid_Points_TP > 0.0)
    tp_span_pts = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_TP);
  else
    tp_span_pts = level_distance_pts * (Grid_TP_Percent / 100.0);

  if(direction == BULLISH)
  {
    grid_raw_tp_price = grid_base_entry_price + (tp_span_pts / g_decimal_digits);

    if(grid_raw_tp_price > grid_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE ROCKET
    } else {
      grid_raw_tp_price = grid_take_profit_price == 0 ? grid_raw_tp_price : grid_take_profit_price;
    }
  }
  if(direction == BEARISH)
  {
    grid_raw_tp_price = grid_base_entry_price - (tp_span_pts / g_decimal_digits);

    if(grid_raw_tp_price < grid_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE FALLS
    } else {
      grid_raw_tp_price = grid_take_profit_price == 0 ? grid_raw_tp_price : grid_take_profit_price;
    }
  }

  if(Grid_Enable_Robust_TP)
    EnsureGridTakeProfitRobustness(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Scalper_TP)
    EnsureGridTakeProfitScalper(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Aggressive_TP)
    EnsureGridTakeProfitAggressive(
      signal_params, grid_level_index, false, grid_raw_tp_price
    );

  return grid_raw_tp_price;
}

double GetGridTakeProfitFinalPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_tp_price            = 0;
  double grid_atr_fallback_price      = 0;
  int    grid_level_index             = grid_order_state.level_index;
  double grid_base_entry_price        = grid_order_state.entry_reference_price;
  double grid_final_take_profit_price = grid_order_state.final_take_profit_price;
  // Per-level final TP span based on exponential distance
  double level_distance_pts           = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);
  double final_span_pts               = level_distance_pts * (Grid_Final_TP_Percent / 100.0);

  if(direction == BULLISH)
  {
    grid_raw_tp_price = grid_base_entry_price + (final_span_pts / g_decimal_digits);

    if(grid_raw_tp_price > grid_final_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE ROCKET
    } else {
      grid_raw_tp_price = grid_final_take_profit_price == 0 ? grid_raw_tp_price : grid_final_take_profit_price;
    }
  }
  if(direction == BEARISH)
  {
    grid_raw_tp_price = grid_base_entry_price - (final_span_pts / g_decimal_digits);

    if(grid_raw_tp_price < grid_final_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE FALLS
    } else {
      grid_raw_tp_price = grid_final_take_profit_price == 0 ? grid_raw_tp_price : grid_final_take_profit_price;
    }
  }

  if(Grid_Enable_Robust_TP)
    EnsureGridTakeProfitRobustness(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Aggressive_TP)
    EnsureGridTakeProfitAggressive(
      signal_params, grid_level_index, true, grid_raw_tp_price
    );

  return grid_raw_tp_price;
}

void EnsureGridTakeProfitRobustness(
  SignalTypes direction, SignalParams &signal_params, int grid_level_index, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price = signal_params.grid_orders[0].entry_price;
    double latest_grid_price  = signal_params.grid_orders[grid_level_index - 1].entry_price;

    if(direction == BULLISH)
    {
      if(grid_raw_tp_price < latest_grid_price)
        grid_raw_tp_price = latest_grid_price;
      if(grid_raw_tp_price > initial_grid_price)
        grid_raw_tp_price = initial_grid_price;
    }
    if(direction == BEARISH)
    {
      if(grid_raw_tp_price > latest_grid_price)
        grid_raw_tp_price = latest_grid_price;
      if(grid_raw_tp_price < initial_grid_price)
        grid_raw_tp_price = initial_grid_price;
    }
  }
}

void EnsureGridTakeProfitScalper(
  SignalTypes direction, SignalParams &signal_params, int grid_level_index, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price = signal_params.grid_orders[0].entry_price;
    double latest_grid_price  = signal_params.grid_orders[grid_level_index - 1].entry_price;

    if(direction == BULLISH) grid_raw_tp_price = latest_grid_price;
    if(direction == BEARISH) grid_raw_tp_price = latest_grid_price;
  }
}

void EnsureGridTakeProfitAggressive(
  SignalParams &signal_params, int grid_level_index, bool is_final_tp, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price    = signal_params.grid_orders[0].entry_price;
    double initial_grid_tp       = signal_params.grid_orders[0].take_profit_price;
    double initial_grid_final_tp = signal_params.grid_orders[0].final_take_profit_price;

    if(!is_final_tp) grid_raw_tp_price = initial_grid_tp;
    if(is_final_tp)  grid_raw_tp_price = initial_grid_final_tp;
  }
}

double UpdateTrailingTP(SignalParams &signal_params, GridOrderState &order_state)
{
  double current_price       = GridCurrentPriceForDirection(signal_params.signal_type, false);
  double digit_scale         = (g_decimal_digits > 0.0) ? g_decimal_digits : 1.0;
  double trailing_span_pts   = MathAbs(order_state.take_profit_price - order_state.entry_price) * digit_scale;
  double offset_pts          = trailing_span_pts * (Grid_Trailing_TP_Percent / 100.0);
  double offset_price        = offset_pts / digit_scale;
  double grid_trailing_price = order_state.trailing_price;
  double indicator_price     = 0.0;
  bool   indicator_mode      = (Grid_Trailing_Strategy_Mode != TRAILING_DEFAULT) &&
                               GridResolveTrailingStrategyPrice(signal_params, indicator_price);

  if(indicator_mode && indicator_price > 0.0)
  {
    double broker_price = EnforceBrokerDistance(g_symbol_constraints) / digit_scale;
    if(broker_price < 0.0)
      broker_price = 0.0;

    if(signal_params.signal_type == BULLISH)
    {
      double candidate = indicator_price + offset_price;
      if(grid_trailing_price > 0.0)
        candidate = MathMax(candidate, grid_trailing_price);

      double cap_price = current_price - broker_price;
      if(cap_price > 0.0 && candidate > cap_price)
        candidate = cap_price;
      return candidate;
    }
    if(signal_params.signal_type == BEARISH)
    {
      double candidate = indicator_price - offset_price;
      if(grid_trailing_price > 0.0)
        candidate = MathMin(candidate, grid_trailing_price);

      double floor_price = current_price + broker_price;
      if(floor_price > 0.0 && candidate < floor_price)
        candidate = floor_price;
      return candidate;
    }
  }

  double safe_fallback_price = 0.0;
  double candidate           = 0.0;

  if(signal_params.signal_type == BULLISH)
  {
    safe_fallback_price = current_price - (EnforceBrokerDistance(g_symbol_constraints) / digit_scale);
    candidate           = current_price - (offset_pts / digit_scale);

    if(candidate > grid_trailing_price)
      return candidate;
    return grid_trailing_price == 0 ? safe_fallback_price : grid_trailing_price;
  }
  if(signal_params.signal_type == BEARISH)
  {
    safe_fallback_price = current_price + (EnforceBrokerDistance(g_symbol_constraints) / digit_scale);
    candidate           = current_price + (offset_pts / digit_scale);

    if(candidate < grid_trailing_price)
      return candidate;
    return grid_trailing_price == 0 ? candidate : grid_trailing_price;
  }

  return safe_fallback_price;
}

void ResetGridOrderPricesByDirection(SignalParams &signal_params, int grid_order_level)
{
  if(signal_params.signal_type == BULLISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].final_take_profit_price = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].trailing_price          = -DBL_MAX;
  }
  if(signal_params.signal_type == BEARISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = DBL_MAX;
    signal_params.grid_orders[grid_order_level].final_take_profit_price = DBL_MAX;
    signal_params.grid_orders[grid_order_level].trailing_price          = DBL_MAX;
  }
  signal_params.grid_orders[grid_order_level].break_even_active = false;
  signal_params.grid_orders[grid_order_level].break_even_price  = 0.0;
}

// --- New pricing helpers (points-based, broker-safe) ---

double ComputeLevelDistancePoints(const SignalParams &signal_params,
                                  const int level_index)
{
  double base_pts = signal_params.grid_base_distance_points;
  if(base_pts <= 0.0)
    return 0.0;
  double mult = Grid_Exponential_Multiplier;
  if(mult <= 0.0)
    mult = 1.0;
  double distance_pts = base_pts * MathPow(mult, (double)level_index);
  distance_pts = EnforceBrokerDistance(g_symbol_constraints, distance_pts);
  return distance_pts;
}

double ComputeEntryReferencePrice(const SignalParams &signal_params,
                                  const GridOrderState &state)
{
  double point_size = GridResolvePointSize();
  double entry_side = GridCurrentPriceForDirection(signal_params.signal_type, true);
  double offset_pts = signal_params.grid_entry_offset_points;
  if(offset_pts < 0.0)
    offset_pts = 0.0;

  double candidate = entry_side;
  if(signal_params.signal_type == BULLISH)
    candidate = entry_side + offset_pts * point_size;
  else if(signal_params.signal_type == BEARISH)
    candidate = entry_side - offset_pts * point_size;

  // Trail adverse only
  double prev = state.entry_reference_price;
  if(prev > 0.0)
  {
    if(signal_params.signal_type == BULLISH && candidate < prev)
      return candidate;
    if(signal_params.signal_type == BEARISH && candidate > prev)
      return candidate;
    return prev;
  }
  return candidate;
}

double ComputeNextLevelPrice(const SignalParams &signal_params,
                             const double entry_reference_price,
                             const double level_distance_points)
{
  double point_size = GridResolvePointSize();
  if(level_distance_points <= 0.0 || point_size <= 0.0 || entry_reference_price <= 0.0)
    return 0.0;
  if(signal_params.signal_type == BULLISH)
    return entry_reference_price - level_distance_points * point_size;
  if(signal_params.signal_type == BEARISH)
    return entry_reference_price + level_distance_points * point_size;
  return 0.0;
}

double ClampPointsToBroker(const double points_value)
{
  return EnforceBrokerDistance(g_symbol_constraints, points_value);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
