//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

const int GRID_MAX_LEVELS = 10;

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

bool ResolveAtrRangeDistancePoints(const ENUM_TIMEFRAMES tf,
                                   double &distance_points)
{
  distance_points = 0.0;

  ENUM_TIMEFRAMES atr_tf = tf;
  if(atr_tf == PERIOD_CURRENT)
    atr_tf = Strategy_Timeframe;
  if(atr_tf == PERIOD_CURRENT)
    atr_tf = PERIOD_M1;

  int atr_handle = iATR(_Symbol, atr_tf, 5);
  if(atr_handle == INVALID_HANDLE)
    return false;

  double atr_values[];
  ArraySetAsSeries(atr_values, true);
  int copied = CopyBuffer(atr_handle, 0, 1, 1, atr_values); // closed candle: shift=1
  IndicatorRelease(atr_handle);

  if(copied < 1)
    return false;

  double atr_price = atr_values[0];
  if(!MathIsValidNumber(atr_price) || atr_price <= 0.0)
    return false;

  double point_size = GridResolvePointSizeSafe();
  if(point_size <= 0.0)
    return false;

  distance_points = atr_price / point_size;
  if(!MathIsValidNumber(distance_points) || distance_points <= 0.0)
    return false;

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
}

bool CalculateBaseGridContext(const SignalParams &signal_params,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &entry_reference_price,
                              int &fibo_steps_out)
{
  fibo_steps_out = 1;
  entry_reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(signal_params.entry_price > 0.0 &&
     (signal_params.entry_is_limit || signal_params.entry_trigger_mode == LEVEL_AS_ZONE))
    entry_reference_price = signal_params.entry_price;

  double point_size = GridResolvePointSizeSafe();
  double direction_mult = GridResolveDirectionMultiplierSafe(signal_params.signal_type);
  if(point_size <= 0.0 || direction_mult == 0.0 || entry_reference_price <= 0.0)
    return false;

  GridBaseStrategyTypes base_strategy = Grid_Base_Strategy_Type;
  if(base_strategy == FIB_LEVEL_RANGE)
  {
    int fibo_steps = 1;
    double fibo_distance = 0.0;
    if(!ResolveFibonacciGridBaseDistance(signal_params,
                                         entry_reference_price,
                                         fibo_steps,
                                         fibo_distance))
      return false;
    fibo_steps_out = fibo_steps;
    distance_points = fibo_distance;
    return (distance_points > 0.0);
  }

  if(base_strategy != POINTS_RANGE && base_strategy != ATR_RANGE)
    base_strategy = POINTS_RANGE;

  double requested_points = 0.0;
  if(base_strategy == ATR_RANGE)
  {
    if(!ResolveAtrRangeDistancePoints(tf, requested_points))
      return false;
  }
  else
  {
    requested_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
  }

  double projected_price = entry_reference_price + direction_mult * requested_points * point_size;

  distance_points = MathAbs(projected_price - entry_reference_price) / point_size;
  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
}

double ResolveLotAccountBalanceReference()
{
  double account_balance = MathAbs(AccountInfoDouble(ACCOUNT_BALANCE));
  if(account_balance > 0.0)
    return account_balance;
  return MathAbs(Account_Size);
}

double ResolveBaseGridLot(const double base_distance_points)
{
  double base_lot = MathAbs(Lot_Strategy_Size);

  if(Lot_Type != GRID_LOT_PERCENTAGE_BASED &&
     Lot_Type != GRID_LOT_CURRENCY_BASED &&
     Lot_Type != GRID_LOT_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  if(Lot_Type == GRID_LOT_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double reference_points = base_distance_points;
  if(TP_Percent > 0.0)
    reference_points = base_distance_points * (TP_Percent / 100.0);
  if(reference_points <= 0.0)
    reference_points = base_distance_points;

  double target_amount = 0.0;
  if(Lot_Type == GRID_LOT_PERCENTAGE_BASED)
  {
    double account_reference = ResolveLotAccountBalanceReference();
    target_amount = account_reference * (Lot_Strategy_Size / 100.0);
  }
  else if(Lot_Type == GRID_LOT_CURRENCY_BASED)
  {
    target_amount = Lot_Strategy_Size;
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
                              const int multiplier_step)
{
  if(multiplier_step <= 0)
    return lot_size;

  double multiplier = MathAbs(Lot_Multiplier);
  if(multiplier <= 0.0)
    multiplier = 1.0;

  double scaled = lot_size * MathPow(multiplier, (double)multiplier_step);
  return NormalizeVolumeForSymbol(_Symbol, scaled);
}

int ResolveExecutedPositionIndex(const SignalParams &signal_params,
                                 const int level_index)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(level_index < 0 || level_index >= total_levels)
    return -1;

  GridOrderState state = signal_params.grid_orders[level_index];
  if(!state.opens_position)
    return -1;

  int executed_index = 0;
  for(int i = 0; i < level_index; i++)
  {
    GridOrderState prior_state = signal_params.grid_orders[i];
    if(!prior_state.opens_position)
      continue;
    if(prior_state.status == GRID_ORDER_COMPLETED ||
       prior_state.status == GRID_ORDER_INACTIVE)
      continue;
    executed_index++;
  }
  return executed_index;
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

  double fallback_points = ResolveGridLevelDistancePoints(signal_params, state);
  if(fallback_points <= 0.0)
    fallback_points = signal_params.grid_base_distance_points;
  if(fallback_points <= 0.0)
    fallback_points = signal_params.grid_entry_gap_points;
  if(fallback_points <= 0.0)
    fallback_points = EnforceBrokerDistance(g_symbol_constraints, 1.0);
  return fallback_points;
}

double ResolveIndicatorMinimumBaseDistance(const SignalParams &signal_params)
{
  return 0.0;
}

double ResolveGridOrderLotSize(SignalParams &signal_params,
                               const int level_index)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(level_index < 0 || level_index >= total_levels)
    return 0.0;

  GridOrderState level_state = signal_params.grid_orders[level_index];
  bool level_opens_position = level_state.opens_position;

  double fallback_lot = signal_params.grid_base_lot_size;
  if(fallback_lot <= 0.0)
    fallback_lot = MathAbs(Lot_Strategy_Size);
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

  GridLotTypes effective_lot_type = Lot_Type;
  if(effective_lot_type != GRID_LOT_PERCENTAGE_BASED &&
     effective_lot_type != GRID_LOT_CURRENCY_BASED &&
     effective_lot_type != GRID_LOT_SIZE)
  {
    effective_lot_type = GRID_LOT_SIZE;
  }

  bool percent_type  = (effective_lot_type == GRID_LOT_PERCENTAGE_BASED);
  bool currency_type = (effective_lot_type == GRID_LOT_CURRENCY_BASED);

  if(percent_type || currency_type)
  {
    double target_amount = 0.0;
    if(percent_type)
    {
      double account_reference = ResolveLotAccountBalanceReference();
      target_amount = account_reference * (Lot_Strategy_Size / 100.0);
    }
    else
    {
      target_amount = MathAbs(Lot_Strategy_Size);
    }

    if(target_amount > 0.0)
    {
      double converted = ConvertAmountToLots(_Symbol, target_amount, movement_points);
      if(converted > 0.0)
        resolved_lot = converted;
    }
  }
  else
  {
    resolved_lot = fallback_lot;
  }

  if(level_opens_position)
  {
    int executed_index = ResolveExecutedPositionIndex(signal_params, level_index);
    if(executed_index < 0)
      executed_index = 0;

    int signal_sequence_step = signal_params.signal_lot_sequence_step;
    if(signal_sequence_step < 0)
      signal_sequence_step = 0;
    int multiplier_step = signal_sequence_step + executed_index;
    resolved_lot = ApplyGridLotMultiplier(resolved_lot, multiplier_step);
  }

  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

void LogGridPlanDiagnostics(const SignalParams &signal_params,
                            const double base_distance_points)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string header = StringFormat("dir=%s|entry=%.5f|base_dist=%.2f|entry_ref=%.5f|entry_offset_pts=%.2f",
                               direction,
                               signal_params.entry_price,
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
  int display_level = GridDisplayLevelNumber(state.level_index);
  string detail = StringFormat("dir=%s|L%d|entry_ref=%.5f|next=%.5f|tp=%.5f|lot=%.2f|status=%s",
                               direction,
                               display_level,
                               state.entry_reference_price,
                               state.next_level_price,
                               state.take_profit_price,
                               state.lot_size,
                               EnumToString(state.status));
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_LEVEL", detail);
}

bool BuildGridSignalPoints(SignalParams &signal_params)
{
  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  int fibo_steps = 1;
  double min_base_distance_from_trailing = ResolveIndicatorMinimumBaseDistance(signal_params);

  ENUM_TIMEFRAMES grid_tf = signal_params.strategy_timeframe;
  if(grid_tf == PERIOD_CURRENT)
    grid_tf = Strategy_Timeframe;

  if(!CalculateBaseGridContext(signal_params,
                               grid_tf,
                               base_distance_points,
                               entry_reference_price,
                               fibo_steps))
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
     signal_params.grid_initial_indicator_distance_points > 0.0 &&
     base_distance_points < signal_params.grid_initial_indicator_distance_points)
  {
    base_distance_points = signal_params.grid_initial_indicator_distance_points;
  }

  double base_lot = signal_params.lot_size;
  if(base_lot <= 0.0)
    base_lot = ResolveBaseGridLot(base_distance_points);
  // Hedge reset sequences can mark previous levels as non-opening; ensure we retain the
  // configured base lot as the starting point for multiplier calculations.
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
  GridEntryStyles effective_entry_style = Grid_Initial_Entry_Style;
  if(signal_params.entry_is_limit || signal_params.entry_trigger_mode == LEVEL_AS_ZONE)
    effective_entry_style = GRID_ENTRY_STYLE_LIMIT;
  if(effective_entry_style == GRID_ENTRY_STYLE_STOP && unified_stop_percent > 0.0)
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
  if(Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
  {
    if(fibo_steps <= 0)
      fibo_steps = 1;
    signal_params.fib_level_offset_steps = fibo_steps;
  }
  else
  {
    signal_params.fib_level_offset_steps = 1;
  }

  if(signal_params.grid_initial_indicator_distance_points <= 0.0 &&
     base_distance_points > 0.0)
  {
    signal_params.grid_initial_indicator_distance_points = base_distance_points;
  }

  signal_params.grid_initialized = true;

  LogGridPlanDiagnostics(signal_params, base_distance_points);

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
  int level_position_start = Grid_Level_Position_Start;
  if(level_position_start < 0)
    level_position_start = 0;
  signal_params.grid_orders[grid_order_level].opens_position = (grid_order_level >= level_position_start);

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
  signal_params.grid_orders[grid_order_level].lot_size = ResolveGridOrderLotSize(signal_params, grid_order_level);
  signal_params.grid_orders[grid_order_level].limit_activation_armed = true;
  if(UsesNonBreakoutLimitEdgeActivation(signal_params, signal_params.grid_orders[grid_order_level]))
  {
    double entry_side_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
    signal_params.grid_orders[grid_order_level].limit_activation_armed =
      ShouldArmNonBreakoutLimitActivation(signal_params,
                                          signal_params.grid_orders[grid_order_level],
                                          entry_side_price);
  }

  if(grid_order_level == 0)
    GridLogEvent("SIGNAL_INIT", signal_params, signal_params.grid_orders[grid_order_level]);
  else
    GridLogEvent("LEVEL_PENDING_INIT", signal_params, signal_params.grid_orders[grid_order_level]);
  LogGridPlanLevelDetail(signal_params, signal_params.grid_orders[grid_order_level]);
  if(Enable_File_Logs)
  {
    int display_level = GridDisplayLevelNumber(signal_params.grid_orders[grid_order_level].level_index);
    AppendTimestampedLog("query_debug.txt", "LEVEL_PENDING_INIT",
                         StringFormat("L%d|entry_ref=%.5f|next=%.5f|armed=%s",
                                      display_level,
                                      signal_params.grid_orders[grid_order_level].entry_reference_price,
                                      signal_params.grid_orders[grid_order_level].next_level_price,
                                      signal_params.grid_orders[grid_order_level].limit_activation_armed ? "true" : "false"));
  }
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
  signal_params.grid_orders[grid_order_level].lot_size = ResolveGridOrderLotSize(signal_params, grid_order_level);

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
