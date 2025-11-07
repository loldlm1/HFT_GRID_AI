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

void GridEnsureOrderState(SignalParams &signal_params,
                          const int level_index)
{
  GridEnsureLevelState(signal_params, level_index);
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
  state.tp_reference_points = 0.0;
  state.resolved_distance_points = 0.0;
  state.next_level_price   = template_state.next_level_price;
  state.last_action_time   = 0;
  state.is_trailing_active = false;
  state.tp_reached         = false;
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

double GridResolveEntryReferencePrice(const SignalParams &signal_params,
                                      const GridOrderState &state)
{
  double reference_price = state.entry_reference_price;
  if(state.level_index > 0 && reference_price <= 0.0)
  {
    int previous_index = state.level_index - 1;
    if(previous_index >= 0 && previous_index < ArraySize(signal_params.grid_orders))
    {
      GridOrderState previous_state = signal_params.grid_orders[previous_index];
      if(previous_state.entry_price > 0.0)
        reference_price = previous_state.entry_price;
    }
  }

  if(reference_price <= 0.0)
    reference_price = signal_params.grid_entry_reference_price;

  if(reference_price <= 0.0)
    reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);

  return reference_price;
}

double GridResolveStopTriggerPrice(const SignalParams &signal_params,
                                   const GridOrderState &state,
                                   const double point_size)
{
  if(state.next_level_price > 0.0)
    return state.next_level_price;

  double reference_price = GridResolveEntryReferencePrice(signal_params, state);
  double pending_points = GridPlanResolvePendingPoints(state);
  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);

  if(reference_price <= 0.0 || pending_points <= 0.0 || direction_mult == 0.0 || point_size <= 0.0)
    return 0.0;

  return reference_price + direction_mult * pending_points * point_size;
}

bool GridRefreshStopTriggerFromAtr(SignalParams &signal_params,
                                   GridOrderState &state,
                                   const double point_size)
{
  double atr_price = 0.0;
  bool atr_resolved = GridResolveAtrReferencePrice(signal_params.signal_type,
                                                   Strategy_Timeframe,
                                                   atr_price);
  double entry_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(entry_price <= 0.0)
    entry_price = signal_params.grid_entry_reference_price;

  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);
  if(direction_mult == 0.0 || point_size <= 0.0 || entry_price <= 0.0)
    return false;

  double distance_points = 0.0;
  if(atr_resolved && atr_price > 0.0)
    distance_points = MathAbs(atr_price - entry_price) / point_size;
  else
    distance_points = MinBrokerDistancePoints(g_symbol_constraints);

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  if(distance_points <= 0.0)
    return false;

  if(!atr_resolved || atr_price <= 0.0)
    atr_price = entry_price + direction_mult * distance_points * point_size;

  state.entry_reference_price    = entry_price;
  state.base_distance_points     = distance_points;
  state.pending_distance_points  = distance_points;
  state.next_level_price         = atr_price;
  return true;
}

double GetGridStopReferencePrice(SignalTypes direction, GridOrderState &grid_order_state)
{
  double base_entry_price = GridCurrentPriceForDirection(direction, true);
  double stop_entry_price = grid_order_state.entry_reference_price;

  if(direction == BULLISH)
  {
    base_entry_price = base_entry_price + (grid_order_state.entry_offset_points / g_decimal_digits);

    if(stop_entry_price > 0 && base_entry_price < stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE FALLS

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }
  if(direction == BEARISH)
  {
    base_entry_price = base_entry_price - (grid_order_state.entry_offset_points / g_decimal_digits);

    if(stop_entry_price > 0 && base_entry_price > stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE ROCKET

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }

  return base_entry_price;
}

double GetGridNextLevelPrice(SignalTypes direction, GridOrderState &grid_order_state)
{
  double grid_raw_pending_price  = 0;
  double grid_atr_fallback_price = 0;
  double grid_base_entry_price   = grid_order_state.entry_reference_price;
  double grid_next_level_price   = grid_order_state.next_level_price;
  GridResolveAtrReferencePrice(direction, Strategy_Timeframe, grid_atr_fallback_price);

  if(direction == BULLISH)
  {
    grid_raw_pending_price = grid_base_entry_price - (grid_order_state.pending_distance_points / g_decimal_digits);

    if(grid_next_level_price > 0 && grid_raw_pending_price < grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE FALLS

    return grid_next_level_price == 0 ? grid_atr_fallback_price : grid_raw_pending_price;
  }
  if(direction == BEARISH)
  {
    grid_raw_pending_price = grid_base_entry_price + (grid_order_state.pending_distance_points / g_decimal_digits);

    if(grid_next_level_price > 0 && grid_raw_pending_price > grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE ROCKET

    return grid_next_level_price == 0 ? grid_atr_fallback_price : grid_raw_pending_price;
  }

  return grid_atr_fallback_price;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
