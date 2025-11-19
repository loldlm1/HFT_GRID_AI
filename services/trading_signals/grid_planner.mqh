//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

const int GRID_MAX_LEVELS = 10;

bool GridEvaluateAtrCandidate(const double candidate_price,
                              const double entry_reference_price,
                              const double point_size,
                              const double min_required,
                              double &best_price,
                              double &best_distance,
                              bool &best_meets_min)
{
  if(candidate_price <= 0.0 || entry_reference_price <= 0.0 || point_size <= 0.0)
    return false;

  double candidate_distance = MathAbs(candidate_price - entry_reference_price) / point_size;
  candidate_distance = EnforceBrokerDistance(g_symbol_constraints, candidate_distance);
  if(candidate_distance <= 0.0)
    return false;

  bool meets_min = (min_required <= 0.0) || (candidate_distance >= min_required);

  bool prefer_candidate = false;
  if(best_price <= 0.0)
    prefer_candidate = true;
  else if(meets_min && !best_meets_min)
    prefer_candidate = true;
  else if(meets_min == best_meets_min && candidate_distance > best_distance)
    prefer_candidate = true;

  if(prefer_candidate)
  {
    best_price     = candidate_price;
    best_distance  = candidate_distance;
    best_meets_min = meets_min;
    return true;
  }

  return false;
}

double GridResolveUnifiedStopPercent()
{
  return MathMax(Grid_Positions_Stops_Percent, 0.0);
}

double GridResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double GridResolveDirectionMultiplierSafe(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

bool CalculateBaseGridContext(const SignalParams &signal_params,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &entry_reference_price)
{
  entry_reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);

  double point_size = GridResolvePointSizeSafe();
  double direction_mult = GridResolveDirectionMultiplierSafe(signal_params.signal_type);
  if(point_size <= 0.0 || direction_mult == 0.0 || entry_reference_price <= 0.0)
    return false;

  double atr_price = 0.0;
  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    double min_required = ResolveAtrMinimumBaseDistance(signal_params);
    double best_distance = 0.0;
    double best_price = 0.0;
    bool best_meets_min = false;

    bool attempt_range   = (Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_SUP_RES ||
                            Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_BOTH);
    bool attempt_trail   = (Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_TRAILING ||
                            Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_BOTH);
    bool attempt_root    = (Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_ROOT);
    bool attempt_sma     = (Grid_ATR_Range_Mode == GRID_ATR_REFERENCE_SMA);

    if(attempt_range)
    {
      double range_price = 0.0;
      if(GridResolveAtrReferencePrice(signal_params.signal_type, tf, range_price))
        GridEvaluateAtrCandidate(range_price,
                                 entry_reference_price,
                                 point_size,
                                 min_required,
                                 best_price,
                                 best_distance,
                                 best_meets_min);
    }

    if(attempt_trail)
    {
      double trail_price = 0.0;
      if(GridResolveAtrTrailingPrice(signal_params.signal_type, tf, trail_price))
        GridEvaluateAtrCandidate(trail_price,
                                 entry_reference_price,
                                 point_size,
                                 min_required,
                                 best_price,
                                 best_distance,
                                 best_meets_min);
    }

    if(attempt_root)
    {
      double root_price = 0.0;
      if(GridResolveAtrRootPrice(signal_params.signal_type, tf, root_price))
        GridEvaluateAtrCandidate(root_price,
                                 entry_reference_price,
                                 point_size,
                                 min_required,
                                 best_price,
                                 best_distance,
                                 best_meets_min);
    }

    if(attempt_sma)
    {
      double sma_price = 0.0;
      if(GridResolveAtrSmaPrice(signal_params.signal_type, tf, sma_price))
        GridEvaluateAtrCandidate(sma_price,
                                 entry_reference_price,
                                 point_size,
                                 min_required,
                                 best_price,
                                 best_distance,
                                 best_meets_min);
    }

    if(best_price <= 0.0 || best_distance <= 0.0)
      return false;

    atr_price = best_price;
    distance_points = best_distance;
  }
  else
  {
    double requested_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
    atr_price = entry_reference_price + direction_mult * requested_points * point_size;

    distance_points = MathAbs(atr_price - entry_reference_price) / point_size;
    distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
    return (distance_points > 0.0);
  }

  if(Grid_Base_Strategy_Type == ATR_RANGE)
    return (distance_points > 0.0);

  return true;
}

double ResolveBaseGridLot(const double base_distance_points)
{
  double base_lot = Grid_Lot_Strategy_Size;

  if(Grid_Lot_Type == GRID_LOT_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double reference_points = base_distance_points;
  if(Grid_TP_Percent > 0.0)
    reference_points = base_distance_points * (Grid_TP_Percent / 100.0);
  if(reference_points <= 0.0)
    reference_points = base_distance_points;

  double target_amount = 0.0;
  if(Grid_Lot_Type == GRID_LOT_PERCENTAGE_BASED ||
     Grid_Lot_Type == GRID_LOT_EQUITY_PERCENT_BASED)
  {
    double account_reference = Account_Size;
    double account_value = (Grid_Lot_Type == GRID_LOT_EQUITY_PERCENT_BASED)
                             ? AccountInfoDouble(ACCOUNT_EQUITY)
                             : AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_value > 0.0)
      account_reference = account_value;
    target_amount = account_reference * (Grid_Lot_Strategy_Size / 100.0);
  }
  else if(Grid_Lot_Type == GRID_LOT_CURRENCY_BASED)
  {
    target_amount = Grid_Lot_Strategy_Size;
  }

  target_amount = MathAbs(target_amount);

  if(target_amount <= 0.0 || reference_points <= 0.0)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double resolved_lot = ConvertAmountToLots(_Symbol, target_amount, reference_points);
  if(resolved_lot <= 0.0)
    resolved_lot = base_lot;
  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

double ApplyGridLotMultiplier(const double lot_size,
                              const int level_index)
{
  if(level_index <= 0)
    return lot_size;

  double multiplier = Grid_Lot_Multiplier;
  if(multiplier <= 0.0)
    multiplier = 1.0;

  double scaled = lot_size * MathPow(multiplier, (double)level_index);
  return NormalizeVolumeForSymbol(_Symbol, scaled);
}

double GridResolveLotReferencePoints(const SignalParams &signal_params,
                                     const GridOrderState &state)
{
  double point_size = GridResolvePointSizeSafe();
  if(point_size <= 0.0)
    return signal_params.grid_base_distance_points;

  double entry_reference = state.entry_reference_price;
  double tp_price        = state.take_profit_price;
  if(entry_reference > 0.0 && tp_price > 0.0)
  {
    double span_points = MathAbs(tp_price - entry_reference) / point_size;
    if(span_points > 0.0)
      return span_points;
  }

  double fallback_points = ComputeLevelDistancePoints(signal_params, state.level_index);
  if(fallback_points <= 0.0)
    fallback_points = signal_params.grid_base_distance_points;
  if(fallback_points <= 0.0)
    fallback_points = signal_params.grid_entry_gap_points;
  if(fallback_points <= 0.0)
    fallback_points = EnforceBrokerDistance(g_symbol_constraints, 1.0);
  return fallback_points;
}

double GridComputeLevelDrawdownPoints(const SignalParams &signal_params,
                                      const GridOrderState &state)
{
  double point_size = GridResolvePointSizeSafe();
  if(point_size <= 0.0)
    return 0.0;

  double entry_reference = state.entry_reference_price;
  double next_level      = state.next_level_price;

  if(entry_reference <= 0.0)
    return 0.0;

  if(next_level <= 0.0)
  {
    double fallback_points = ComputeLevelDistancePoints(signal_params, state.level_index);
    return MathMax(fallback_points, 0.0);
  }

  double range_points = MathAbs(entry_reference - next_level) / point_size;
  return MathMax(range_points, 0.0);
}

double GridComputeLevelDrawdownCurrency(const SignalParams &signal_params,
                                        const GridOrderState &state)
{
  if(state.lot_size <= 0.0)
    return 0.0;

  double drawdown_points = GridComputeLevelDrawdownPoints(signal_params, state);
  if(drawdown_points <= 0.0)
    return 0.0;

  return ConvertLotsToAmount(_Symbol, state.lot_size, drawdown_points);
}

double GridComputeSequenceDrawdownCurrency(const SignalParams &signal_params,
                                           const int upto_level_index)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(upto_level_index <= 0 || total_levels <= 0)
    return 0.0;

  int limit = upto_level_index;
  if(limit > total_levels)
    limit = total_levels;

  double cumulative_amount = 0.0;
  for(int i = 0; i < limit; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];
    cumulative_amount += GridComputeLevelDrawdownCurrency(signal_params, level_state);
  }
  return cumulative_amount;
}

double ResolveAtrMinimumBaseDistance(const SignalParams &signal_params)
{
  if(Grid_Base_Strategy_Type != ATR_RANGE)
    return 0.0;

  int existing_levels = ArraySize(signal_params.grid_orders);
  if(existing_levels <= 0)
    return 0.0;

  double stored_base = signal_params.grid_base_distance_points;
  if(stored_base <= 0.0)
    return 0.0;

  double previous_distance = ComputeLevelDistancePoints(signal_params, existing_levels - 1);
  if(previous_distance <= 0.0)
    return 0.0;

  double multiplier = Grid_Exponential_Multiplier;
  if(multiplier <= 0.0)
    multiplier = 1.0;

  double pow_factor = MathPow(multiplier, (double)existing_levels);
  if(pow_factor <= 0.0)
    pow_factor = 1.0;

  double min_base = previous_distance / pow_factor;
  return EnforceBrokerDistance(g_symbol_constraints, min_base);
}

double ResolveGridOrderLotSize(SignalParams &signal_params,
                               const int level_index)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(level_index < 0 || level_index >= total_levels)
    return 0.0;

  GridOrderState level_state = signal_params.grid_orders[level_index];

  double fallback_lot = signal_params.grid_base_lot_size;
  if(fallback_lot <= 0.0)
    fallback_lot = Grid_Lot_Strategy_Size;
  if(fallback_lot <= 0.0)
  {
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    fallback_lot = min_vol;
  }

  double movement_points = GridResolveLotReferencePoints(signal_params, level_state);
  if(movement_points <= 0.0)
    movement_points = signal_params.grid_base_distance_points;
  if(movement_points <= 0.0)
    movement_points = 1.0;

  double resolved_lot = fallback_lot;

  GridLotTypes effective_lot_type = Grid_Lot_Type;
  if(signal_params.is_sar_signal)
    effective_lot_type = GRID_LOT_CALCULATED;

  bool percent_type  = (effective_lot_type == GRID_LOT_PERCENTAGE_BASED ||
                        effective_lot_type == GRID_LOT_EQUITY_PERCENT_BASED);
  bool currency_type = (effective_lot_type == GRID_LOT_CURRENCY_BASED);

  if(percent_type || currency_type)
  {
    double target_amount = 0.0;
    if(percent_type)
    {
      double account_reference = Account_Size;
      double account_value = (effective_lot_type == GRID_LOT_EQUITY_PERCENT_BASED)
                               ? AccountInfoDouble(ACCOUNT_EQUITY)
                               : AccountInfoDouble(ACCOUNT_BALANCE);
      if(account_value > 0.0)
        account_reference = account_value;
      target_amount = account_reference * (Grid_Lot_Strategy_Size / 100.0);
    }
    else
    {
      target_amount = MathAbs(Grid_Lot_Strategy_Size);
    }

    if(target_amount > 0.0)
    {
      double converted = ConvertAmountToLots(_Symbol, target_amount, movement_points);
      if(converted > 0.0)
        resolved_lot = converted;
    }
  }
  else if(effective_lot_type == GRID_LOT_CALCULATED)
  {
    if(level_index == 0)
    {
      resolved_lot = fallback_lot;
    }
    else
    {
      double drawdown_amount = GridComputeSequenceDrawdownCurrency(signal_params, level_index);
      if(drawdown_amount > 0.0)
      {
        double multiplier = Grid_Lot_Multiplier;
        if(multiplier <= 0.0)
          multiplier = 1.0;
        double target_amount = drawdown_amount * multiplier;
        double calculated = ConvertAmountToLots(_Symbol, target_amount, movement_points);
        if(calculated > 0.0)
          resolved_lot = calculated;
      }
    }
  }
  else
  {
    resolved_lot = fallback_lot;
  }

  if(effective_lot_type != GRID_LOT_CALCULATED)
    resolved_lot = ApplyGridLotMultiplier(resolved_lot, level_index);

  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

void LogGridPlanDiagnostics(const SignalParams &signal_params,
                            const double point_size,
                            const double base_distance_points)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string header = StringFormat("dir=%s|entry=%.5f|ask=%.5f|bid=%.5f|point=%.5f|base_dist=%.2f|entry_ref=%.5f|entry_offset_pts=%.2f",
                               direction,
                               signal_params.entry_price,
                               g_ask,
                               g_bid,
                               point_size,
                               base_distance_points,
                               signal_params.grid_entry_reference_price,
                               signal_params.grid_entry_offset_points);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_BASE", header);
}

void LogGridPlanLevelDetail(const SignalParams &signal_params,
                            const GridOrderState &state)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double pending_points = 0; // SHOULD BE USING THE signal_params pending_points
  double tick_size = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                              g_symbol_constraints.point_size);
  string detail = StringFormat("dir=%s|level=%d|dist=%.2f|pending=%.2f|entry_offset=%.2f|activation=%.2f|tp=%.2f|tp_final=%.2f|trail=%.2f|lot=%.2f|style=%s|next_limit=%.5f|tick=%.5f|spread_pts=%.1f",
                               direction,
                               state.level_index,
                               signal_params.grid_base_distance_points,
                               pending_points,
                               signal_params.grid_entry_offset_points,
                               0,
                               0, // SHOULD BE CALCULATED TP
                               0, // SHOULD BE CALCULATED TP FINAL
                               0, // SHOULD BE CALCULATED TRAILING POINTS
                               state.lot_size,
                               EnumToString(state.entry_style),
                               state.next_level_price,
                               tick_size,
                               g_points_spread);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_LEVEL", detail);
}

bool BuildGridSignalPoints(SignalParams &signal_params)
{
  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  double min_base_distance_from_trailing = ResolveAtrMinimumBaseDistance(signal_params);

  if(!CalculateBaseGridContext(signal_params,
                               Strategy_Timeframe,
                               base_distance_points,
                               entry_reference_price))
  {
    Print("Grid plan aborted: base distance not available.");
    return false;
  }

  if(min_base_distance_from_trailing > 0.0 && base_distance_points < min_base_distance_from_trailing)
  {
    base_distance_points = min_base_distance_from_trailing;
    base_distance_points = EnforceBrokerDistance(g_symbol_constraints, base_distance_points);
  }

  if(GridSignalHasExecutedLevel(signal_params) &&
     signal_params.grid_initial_atr_sma_distance_points > 0.0 &&
     base_distance_points < signal_params.grid_initial_atr_sma_distance_points)
  {
    base_distance_points = signal_params.grid_initial_atr_sma_distance_points;
  }

  double base_lot = signal_params.lot_size;
  if(base_lot <= 0.0)
    base_lot = ResolveBaseGridLot(base_distance_points);
  if(base_lot <= 0.0)
  {
    double min_vol = g_symbol_constraints.min_volume;
    if(min_vol <= 0.0)
      min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    base_lot = min_vol;
  }

  double unified_stop_percent = GridResolveUnifiedStopPercent();
  double entry_offset_points = 0.0;
  if(Grid_Initial_Entry_Style == GRID_ENTRY_STYLE_STOP && unified_stop_percent > 0.0)
  {
    entry_offset_points = base_distance_points * (unified_stop_percent / 100.0);
    if(entry_offset_points > 0.0)
      entry_offset_points = EnforceBrokerDistance(g_symbol_constraints, entry_offset_points);
  }

  signal_params.grid_base_distance_points      = base_distance_points;
  signal_params.grid_resolved_distance_points  = 0.0;
  signal_params.grid_base_lot_size             = base_lot;
  signal_params.grid_entry_reference_price     = entry_reference_price;
  signal_params.grid_entry_gap_points          = base_distance_points;
  signal_params.grid_entry_offset_points       = entry_offset_points;

  if(signal_params.grid_initial_atr_sma_distance_points <= 0.0 &&
     base_distance_points > 0.0)
  {
    signal_params.grid_initial_atr_sma_distance_points = base_distance_points;
  }

  signal_params.grid_initialized = true;

  double point_size = GridResolvePointSizeSafe();
  LogGridPlanDiagnostics(signal_params, point_size, base_distance_points);

  if(Enable_Logs)
  {
    PrintFormat("Grid plan ready | direction=%s | base_distance=%.2f pts | levels=%d",
                EnumToString(signal_params.signal_type),
                signal_params.grid_base_distance_points,
                ArraySize(signal_params.grid_orders));
  }

  return true;
}

// Unified entry point to build (init) or refresh (tick) grid geometry and pending levels
bool BuildGridOrderForSignal(SignalParams &signal_params)
{
  if(!BuildGridSignalPoints(signal_params)) return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  GridOrderState grid_order;

  int grid_order_level = AddElementToArray(signal_params.grid_orders, grid_order)-1;

  if(grid_order_level < 0)
  {
    Print("ERROR CREATING NEW GRID ORDER LEVEL");
    TesterStop();
    return false;
  }

  // Seed level n
  signal_params.grid_orders[grid_order_level].level_index = grid_order_level;
  signal_params.grid_orders[grid_order_level].status      = GRID_ORDER_STOP_TRAILING_ACTIVE;
  ResetGridOrderPricesByDirection(signal_params, grid_order_level);

  // Calculate trailing entry reference and next level activation
  signal_params.grid_orders[grid_order_level].entry_reference_price  = GetGridStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].next_level_price       = GetGridNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].take_profit_price      = GetGridTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].final_take_profit_price = GetGridTakeProfitFinalPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].lot_size = ResolveGridOrderLotSize(signal_params, grid_order_level);

  // Telemetry
  GridLogEvent("LOT_RESOLVED", signal_params, signal_params.grid_orders[grid_order_level]);
  LogGridPlanLevelDetail(signal_params, signal_params.grid_orders[0]);
  if(Enable_File_Logs)
    AppendTimestampedLog("query_debug.txt", "LEVEL_PENDING_INIT",
                          StringFormat("level=%d|entry_ref=%.5f|next=%.5f",
                                      0,
                                      signal_params.grid_orders[0].entry_reference_price,
                                      signal_params.grid_orders[0].next_level_price));
  return true;
}

bool UpdateGridOrderForSignal(SignalParams &signal_params)
{
  if(!BuildGridSignalPoints(signal_params)) return false;

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;

  // Calculate trailing entry reference and next level activation
  signal_params.grid_orders[grid_order_level].entry_reference_price  = GetGridStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].next_level_price       = GetGridNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].take_profit_price      = GetGridTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].final_take_profit_price = GetGridTakeProfitFinalPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].lot_size = ResolveGridOrderLotSize(signal_params, grid_order_level);

  GridLogEvent("NEXT_UPDATE", signal_params, signal_params.grid_orders[grid_order_level]);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
