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

  bool pandora_forces_points = PandoraStrategyEnabled();
  bool uses_channel_strategy = GridStrategyUsesChannelIndicator();
  if(pandora_forces_points)
    uses_channel_strategy = false;

  if(pandora_forces_points)
  {
    double requested_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
    double projected_price = entry_reference_price + direction_mult * requested_points * point_size;

    distance_points = MathAbs(projected_price - entry_reference_price) / point_size;
    distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
    return (distance_points > 0.0);
  }

  if(uses_channel_strategy)
  {
    GridBaseStrategyTypes channel_type = ResolveActiveChannelStrategy();
    bool use_midline = (signal_params.entry_trigger_mode == ENTRY_MODE_BREAKOUT);
    GridChannelLineTypes line_type = use_midline
                                       ? GRID_CHANNEL_LINE_MIDDLE
                                       : ((signal_params.signal_type == BULLISH)
                                            ? GRID_CHANNEL_LINE_SUPPORT
                                            : GRID_CHANNEL_LINE_RESISTANCE);
    double channel_price = 0.0;
    if(!GridResolveChannelLinePrice(channel_type, line_type, tf, channel_price, 1))
    {
      if(use_midline)
      {
        line_type = (signal_params.signal_type == BULLISH)
                      ? GRID_CHANNEL_LINE_SUPPORT
                      : GRID_CHANNEL_LINE_RESISTANCE;
        if(!GridResolveChannelLinePrice(channel_type, line_type, tf, channel_price, 1))
          return false;
      }
      else
      {
        return false;
      }
    }

    distance_points = MathAbs(channel_price - entry_reference_price) / point_size;
    distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
    return (distance_points > 0.0);
  }

  if(Grid_Base_Strategy_Type == STOCH_STRUCTURE_RANGE)
  {
    distance_points = ResolveStochStructureDistancePoints(signal_params, entry_reference_price);
    return (distance_points > 0.0);
  }

  if(Grid_Base_Strategy_Type == ATR_MA_RANGE)
  {
    double atr_value = 0.0;
    double atr_ma_value = 0.0;
    bool atr_loaded = GridCopyChannelBufferValue(ATR_RANGE, tf, 0, atr_value, 1);
    bool ma_loaded  = GridCopyChannelBufferValue(ATR_RANGE, tf, 1, atr_ma_value, 1);
    double stored   = signal_params.grid_initial_indicator_distance_points;

    if(!signal_params.grid_initialized)
    {
      if(!atr_loaded || !ma_loaded)
        return false;
      double atr_points = atr_value / point_size;
      if(atr_points <= 0.0)
        return false;
      if(atr_ma_value > 0.0 && atr_value <= atr_ma_value)
        return false;
      double guard_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
      if(guard_points > 0.0 && guard_points > atr_points)
        return false;
      distance_points = EnforceBrokerDistance(g_symbol_constraints, atr_points);
      return (distance_points > 0.0);
    }

    // Grid running: allow only non-decreasing spacing; fallback to stored on failures.
    if(!atr_loaded && stored > 0.0)
    {
      distance_points = EnforceBrokerDistance(g_symbol_constraints, stored);
      return (distance_points > 0.0);
    }

    double atr_points = atr_value / point_size;
    if(atr_points <= 0.0 && stored > 0.0)
      atr_points = stored;
    if(stored > 0.0 && atr_points < stored)
      atr_points = stored;

    distance_points = EnforceBrokerDistance(g_symbol_constraints, atr_points);
    return (distance_points > 0.0);
  }

  double requested_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
  double projected_price = entry_reference_price + direction_mult * requested_points * point_size;

  distance_points = MathAbs(projected_price - entry_reference_price) / point_size;
  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
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
  if(!state.opens_position)
    return 0.0;
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
    if(!level_state.opens_position)
      continue;
    cumulative_amount += GridComputeLevelDrawdownCurrency(signal_params, level_state);
  }
  return cumulative_amount;
}

double ResolveIndicatorMinimumBaseDistance(const SignalParams &signal_params)
{
  if(!GridStrategyUsesChannelIndicator())
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
  bool level_opens_position = level_state.opens_position;

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
  else if(effective_lot_type == GRID_LOT_MAX_MARGIN_SPLIT)
  {
    double aggressive = GridResolveAggressiveLotSize(signal_params.signal_type);
    if(aggressive > 0.0)
      resolved_lot = aggressive;
  }
  else
  {
    resolved_lot = fallback_lot;
  }

  if(effective_lot_type != GRID_LOT_CALCULATED &&
     effective_lot_type != GRID_LOT_MAX_MARGIN_SPLIT &&
     level_opens_position)
  {
    int executed_index = ResolveExecutedPositionIndex(signal_params, level_index);
    if(executed_index < 0)
      executed_index = 0;
    resolved_lot = ApplyGridLotMultiplier(resolved_lot, executed_index);
  }

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
  double min_base_distance_from_trailing = ResolveIndicatorMinimumBaseDistance(signal_params);

  ENUM_TIMEFRAMES grid_tf = signal_params.strategy_timeframe;
  if(grid_tf == PERIOD_CURRENT)
    grid_tf = Strategy_Timeframe;

  if(!CalculateBaseGridContext(signal_params,
                               grid_tf,
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

  if(Grid_Base_Strategy_Type == ATR_MA_RANGE)
  {
    if(signal_params.grid_initial_indicator_distance_points > 0.0 &&
       base_distance_points < signal_params.grid_initial_indicator_distance_points)
    {
      base_distance_points = signal_params.grid_initial_indicator_distance_points;
    }
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

  if(signal_params.grid_initial_indicator_distance_points <= 0.0 &&
     base_distance_points > 0.0)
  {
    signal_params.grid_initial_indicator_distance_points = base_distance_points;
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
