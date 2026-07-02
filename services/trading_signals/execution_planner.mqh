//+------------------------------------------------------------------+
//|                                       trading_signals/execution_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_PLANNER_MQH_

const int EXECUTION_MAX_LEGS = 10;

double ExecutionResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double ExecutionResolveDirectionMultiplierSafe(const SignalTypes direction)
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

  double point_size = ExecutionResolvePointSizeSafe();
  if(point_size <= 0.0)
    return false;

  distance_points = atr_price / point_size;
  if(!MathIsValidNumber(distance_points) || distance_points <= 0.0)
    return false;

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
}

bool CalculateBaseExecutionContext(const SignalParams &signal_params,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &entry_reference_price,
                              int &fibo_steps_out)
{
  fibo_steps_out = 1;
  entry_reference_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, true);
  if(signal_params.entry_price > 0.0 &&
     (signal_params.entry_is_limit || signal_params.entry_trigger_mode == LEVEL_AS_ZONE))
    entry_reference_price = signal_params.entry_price;

  double point_size = ExecutionResolvePointSizeSafe();
  double direction_mult = ExecutionResolveDirectionMultiplierSafe(signal_params.signal_type);
  if(point_size <= 0.0 || direction_mult == 0.0 || entry_reference_price <= 0.0)
    return false;

  RangeStrategyTypes base_strategy = Base_Strategy_Type;
  if(base_strategy == FIB_LEVEL_RANGE)
  {
    int fibo_steps = 1;
    double fibo_distance = 0.0;
    if(!ResolveFibonacciExecutionBaseDistance(signal_params,
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
    requested_points = EnforceBrokerDistance(g_symbol_constraints, Points_Range_Setup);
  }

  double projected_price = entry_reference_price + direction_mult * requested_points * point_size;

  distance_points = MathAbs(projected_price - entry_reference_price) / point_size;
  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
}

double ResolveBaseExecutionLot(const double base_distance_points)
{
  ExecutionLotTypes effective_lot_type = ResolveEffectiveExecutionLotType(Lot_Type);
  double base_lot = MathAbs(Lot_Strategy_Size);

  if(effective_lot_type == EXECUTION_LOT_FIXED_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  if(!IsExecutionTargetProfitLotType(effective_lot_type))
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double tp_factor = ResolveTargetProfitFactorFromPercent(TP_Percent);
  double reference_points = base_distance_points * tp_factor;
  if(reference_points <= 0.0)
    reference_points = base_distance_points;

  double target_amount = ResolveExecutionRuntimeTargetProfitAmount(effective_lot_type);
  if(target_amount <= 0.0 || reference_points <= 0.0)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double resolved_lot = ConvertAmountToLots(_Symbol, target_amount, reference_points);
  if(resolved_lot <= 0.0)
    resolved_lot = base_lot;

  if(resolved_lot <= 0.0)
  {
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    resolved_lot = min_vol;
  }

  return NormalizeVolumeUpForSymbol(_Symbol, resolved_lot);
}

double ApplyExecutionLotMultiplier(const double lot_size,
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
  int total_levels = ArraySize(signal_params.execution_legs);
  if(level_index < 0 || level_index >= total_levels)
    return -1;

  ExecutionLegState state = signal_params.execution_legs[level_index];
  if(!state.opens_position)
    return -1;

  int executed_index = 0;
  for(int i = 0; i < level_index; i++)
  {
    ExecutionLegState prior_state = signal_params.execution_legs[i];
    if(!prior_state.opens_position)
      continue;
    if(prior_state.status == EXECUTION_LEG_COMPLETED ||
       prior_state.status == EXECUTION_LEG_INACTIVE)
      continue;
    executed_index++;
  }
  return executed_index;
}

double ExecutionResolveLotReferencePoints(const SignalParams &signal_params,
                                     const ExecutionLegState &state)
{
  double point_size = ExecutionResolvePointSizeSafe();
  if(point_size <= 0.0)
    return signal_params.execution_base_distance_points;

  double entry_reference = state.entry_reference_price;
  double tp_price        = state.take_profit_price;
  if(entry_reference > 0.0 && tp_price > 0.0)
  {
    double span_points = MathAbs(tp_price - entry_reference) / point_size;
    if(span_points > 0.0)
      return span_points;
  }

  double fallback_points = ResolveExecutionLegDistancePoints(signal_params, state);
  if(fallback_points <= 0.0)
    fallback_points = signal_params.execution_base_distance_points;
  if(fallback_points <= 0.0)
    fallback_points = signal_params.execution_entry_gap_points;
  if(fallback_points <= 0.0)
    fallback_points = EnforceBrokerDistance(g_symbol_constraints, 1.0);
  return fallback_points;
}

double ResolveIndicatorMinimumBaseDistance(const SignalParams &signal_params)
{
  return 0.0;
}

bool ResolveTargetModeLotForExecutionLeg(SignalParams &signal_params,
                                      const int level_index,
                                      const ExecutionLegState &level_state,
                                      const double target_amount,
                                      double &lot_out)
{
  lot_out = 0.0;

  if(!level_state.opens_position)
    return true;

  if(level_index < 0 || level_index >= ArraySize(signal_params.execution_legs))
    return false;

  if(target_amount <= 0.0)
  {
    signal_params.execution_legs[level_index].opens_position = false;
    lot_out = 0.0;
    return true;
  }

  double tp_price = level_state.take_profit_price;
  double candidate_entry_price = level_state.entry_reference_price;
  if(candidate_entry_price <= 0.0)
    candidate_entry_price = signal_params.execution_entry_reference_price;
  if(candidate_entry_price <= 0.0)
    candidate_entry_price = signal_params.entry_price;

  if(tp_price <= 0.0 || candidate_entry_price <= 0.0)
  {
    signal_params.execution_legs[level_index].opens_position = true;
    lot_out = -1.0;
    return false;
  }

  double required_raw_lot = 0.0;
  if(!ResolveRequiredLotForTargetAtPrice(signal_params,
                                         level_index,
                                         candidate_entry_price,
                                         tp_price,
                                         target_amount,
                                         required_raw_lot))
  {
    signal_params.execution_legs[level_index].opens_position = true;
    lot_out = -1.0;
    return false;
  }

  if(required_raw_lot <= 0.0)
  {
    signal_params.execution_legs[level_index].opens_position = false;
    lot_out = 0.0;
    return true;
  }

  double normalized_lot = 0.0;
  bool infeasible = false;
  if(!NormalizeTargetModeRequiredLot(_Symbol,
                                     required_raw_lot,
                                     normalized_lot,
                                     infeasible))
  {
    signal_params.execution_legs[level_index].opens_position = true;
    lot_out = -1.0;
    return false;
  }

  signal_params.execution_legs[level_index].opens_position = true;
  lot_out = normalized_lot;
  return true;
}

double ResolveExecutionLegLotSize(SignalParams &signal_params,
                               const int level_index)
{
  int total_levels = ArraySize(signal_params.execution_legs);
  if(level_index < 0 || level_index >= total_levels)
    return 0.0;

  ExecutionLegState level_state = signal_params.execution_legs[level_index];

  double fallback_lot = signal_params.execution_base_lot_size;
  if(fallback_lot <= 0.0)
    fallback_lot = MathAbs(Lot_Strategy_Size);
  if(fallback_lot <= 0.0)
  {
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    fallback_lot = min_vol;
  }

  double resolved_lot = fallback_lot;

  ExecutionLotTypes effective_lot_type = ResolveEffectiveExecutionLotType(Lot_Type);
  if(IsExecutionTargetProfitLotType(effective_lot_type))
  {
    double target_amount = ResolveExecutionRuntimeTargetProfitAmount(effective_lot_type);
    double target_mode_lot = 0.0;
    bool resolved_target_mode = ResolveTargetModeLotForExecutionLeg(signal_params,
                                                                 level_index,
                                                                 level_state,
                                                                 target_amount,
                                                                 target_mode_lot);
    if(!resolved_target_mode && target_mode_lot >= 0.0)
      target_mode_lot = -1.0;
    return target_mode_lot;
  }

  resolved_lot = fallback_lot;
  bool level_opens_position = signal_params.execution_legs[level_index].opens_position;
  if(level_opens_position && ExecutionShouldApplyLotMultiplier(effective_lot_type))
  {
    int executed_index = ResolveExecutedPositionIndex(signal_params, level_index);
    if(executed_index < 0)
      executed_index = 0;

    int signal_sequence_step = signal_params.signal_lot_sequence_step;
    if(signal_sequence_step < 0)
      signal_sequence_step = 0;
    int multiplier_step = signal_sequence_step + executed_index;
    resolved_lot = ApplyExecutionLotMultiplier(resolved_lot, multiplier_step);
  }

  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

void LogExecutionPlanDiagnostics(const SignalParams &signal_params,
                            const double base_distance_points)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string header = StringFormat("dir=%s|entry=%.5f|base_dist=%.2f|entry_ref=%.5f",
                               direction,
                               signal_params.entry_price,
                               base_distance_points,
                               signal_params.execution_entry_reference_price);

  if(Base_Strategy_Type == FIB_LEVEL_RANGE)
  {
    bool resolved_entry_ok = SignalHasResolvedFibonacciEntryAnchor(signal_params);
    double resolved_entry_percent = signal_params.resolved_fibonacci_entry.percent;
    double resolved_entry_price = signal_params.resolved_fibonacci_entry.price;
    double logical_next_percent = 0.0;
    bool logical_next_percent_ok = ResolveFibonacciExecutionLevelPercent(signal_params,
                                                                    0,
                                                                    logical_next_percent);
    double logical_next_price = 0.0;
    bool logical_next_price_ok = ResolveFibonacciExecutionLevelPrice(signal_params,
                                                                0,
                                                                logical_next_price);

    SignalParams preview_signal = signal_params;
    ExecutionLegState preview_state;
    preview_state.level_index = 0;
    preview_state.entry_reference_price = signal_params.execution_entry_reference_price;
    double emitted_next_price = GetExecutionNextLevelPrice(signal_params.signal_type,
                                                      preview_signal,
                                                      preview_state);
    string next_source = "LOGICAL";
    if(logical_next_price_ok)
    {
      double next_gap_points = ExecutionAbsolutePriceDistancePoints(emitted_next_price,
                                                               logical_next_price);
      if(next_gap_points > 0.1)
        next_source = "BROKER_SAFE";
    }

    header = header + StringFormat("|fib_steps=%d|logical_next_pct=%s|logical_next_price=%s|emitted_next=%s|next_src=%s",
                                   signal_params.fib_level_offset_steps,
                                   ExecutionFormatDoubleOrToken(logical_next_percent_ok,
                                                           logical_next_percent,
                                                           2),
                                   ExecutionFormatDoubleOrToken(logical_next_price_ok,
                                                           logical_next_price,
                                                           5),
                                   ExecutionFormatDoubleOrToken(emitted_next_price > 0.0,
                                                           emitted_next_price,
                                                           5),
                                   next_source);
    header = header + StringFormat("|resolved_entry_pct=%s|resolved_entry_price=%s|entry_anchor_src=%s",
                                   ExecutionFormatDoubleOrToken(resolved_entry_ok,
                                                           resolved_entry_percent,
                                                           2),
                                   ExecutionFormatDoubleOrToken(resolved_entry_ok,
                                                           resolved_entry_price,
                                                           5),
                                   resolved_entry_ok ? "SIGNAL" : "RAW");
  }

  ExecutionAppendQueryDebugChangedLog("EXECUTION_PLAN_BASE",
                                 ExecutionQueryDebugSignalKey(signal_params),
                                 header);
}

void LogExecutionPlanLegDetail(const SignalParams &signal_params,
                            const ExecutionLegState &state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(state.level_index);
  string detail = StringFormat("dir=%s|L%d|entry_ref=%.5f|next=%.5f|tp=%.5f|lot=%.2f|status=%s",
                               direction,
                               display_level,
                               state.entry_reference_price,
                               state.next_level_price,
                               state.take_profit_price,
                               state.lot_size,
                               EnumToString(state.status));
  ExecutionAppendQueryDebugLog("EXECUTION_PLAN_LEG", detail);
}

bool BuildExecutionSignalPoints(SignalParams &signal_params)
{
  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  int fibo_steps = 1;
  double min_base_distance_from_trailing = ResolveIndicatorMinimumBaseDistance(signal_params);

  ENUM_TIMEFRAMES execution_tf = signal_params.strategy_timeframe;
  if(execution_tf == PERIOD_CURRENT)
    execution_tf = Strategy_Timeframe;

  if(!CalculateBaseExecutionContext(signal_params,
                               execution_tf,
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

  if(ExecutionSignalHasExecutedLeg(signal_params) &&
     signal_params.execution_initial_indicator_distance_points > 0.0 &&
     base_distance_points < signal_params.execution_initial_indicator_distance_points)
  {
    base_distance_points = signal_params.execution_initial_indicator_distance_points;
  }

  double base_lot = signal_params.lot_size;
  if(base_lot <= 0.0)
    base_lot = ResolveBaseExecutionLot(base_distance_points);
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

  double entry_offset_points = 0.0;

  signal_params.execution_base_distance_points      = base_distance_points;
  signal_params.execution_resolved_distance_points  = 0.0;
  signal_params.execution_base_lot_size             = base_lot;
  signal_params.execution_entry_reference_price     = entry_reference_price;
  signal_params.execution_entry_gap_points          = base_distance_points;
  signal_params.execution_entry_offset_points       = entry_offset_points;
  if(Base_Strategy_Type == FIB_LEVEL_RANGE)
  {
    if(fibo_steps <= 0)
      fibo_steps = 1;
    signal_params.fib_level_offset_steps = fibo_steps;
  }
  else
  {
    signal_params.fib_level_offset_steps = 1;
  }

  if(signal_params.execution_initial_indicator_distance_points <= 0.0 &&
     base_distance_points > 0.0)
  {
    signal_params.execution_initial_indicator_distance_points = base_distance_points;
  }

  signal_params.execution_initialized = true;

  LogExecutionPlanDiagnostics(signal_params, base_distance_points);

  return true;
}

// Unified entry point to build (init) or refresh (tick) grid geometry and pending levels
bool BuildExecutionLegForSignal(SignalParams &signal_params)
{
  if(!BuildExecutionSignalPoints(signal_params)) return false;

  int total_levels = ArraySize(signal_params.execution_legs);
  ExecutionLegState execution_leg;

  int execution_leg_index = AddElementToArray(signal_params.execution_legs, execution_leg)-1;

  if(execution_leg_index < 0)
  {
    Print("ERROR CREATING NEW GRID ORDER LEVEL");
    TesterStop();
    return false;
  }

  // Seed level n
  signal_params.execution_legs[execution_leg_index].level_index = execution_leg_index;
  signal_params.execution_legs[execution_leg_index].status      = EXECUTION_LEG_PENDING;
  ResetExecutionLegPricesByDirection(signal_params, execution_leg_index);
  int level_position_start = ResolveFoundationLevelPositionStart();
  signal_params.execution_legs[execution_leg_index].opens_position = (execution_leg_index >= level_position_start);

  // Calculate trailing entry reference and next level activation
  signal_params.execution_legs[execution_leg_index].entry_reference_price  = GetExecutionStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].next_level_price       = GetExecutionNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].take_profit_price      = GetExecutionTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].lot_size = ResolveExecutionLegLotSize(signal_params, execution_leg_index);
  signal_params.execution_legs[execution_leg_index].initial_lot_size = signal_params.execution_legs[execution_leg_index].lot_size;
  signal_params.execution_legs[execution_leg_index].initial_take_profit_price =
    signal_params.execution_legs[execution_leg_index].take_profit_price;
  signal_params.execution_legs[execution_leg_index].limit_activation_armed = true;
  if(UsesNonBreakoutLimitEdgeActivation(signal_params, signal_params.execution_legs[execution_leg_index]))
  {
    double entry_side_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, true);
    signal_params.execution_legs[execution_leg_index].limit_activation_armed =
      ShouldArmNonBreakoutLimitActivation(signal_params,
                                          signal_params.execution_legs[execution_leg_index],
                                          entry_side_price);
  }

  if(execution_leg_index == 0)
  {
    ExecutionLogEvent("SIGNAL_INIT", signal_params, signal_params.execution_legs[execution_leg_index]);
  }
  else
    ExecutionLogEvent("LEVEL_PENDING_INIT", signal_params, signal_params.execution_legs[execution_leg_index]);
  LogExecutionPlanLegDetail(signal_params, signal_params.execution_legs[execution_leg_index]);
  int display_level = ExecutionDisplayLegNumber(signal_params.execution_legs[execution_leg_index].level_index);
  ExecutionAppendQueryDebugLog("LEVEL_PENDING_INIT",
                          StringFormat("L%d|entry_ref=%.5f|next=%.5f|armed=%s",
                                       display_level,
                                       signal_params.execution_legs[execution_leg_index].entry_reference_price,
                                       signal_params.execution_legs[execution_leg_index].next_level_price,
                                       signal_params.execution_legs[execution_leg_index].limit_activation_armed ? "true" : "false"));
  return true;
}

bool UpdateExecutionLegForSignal(SignalParams &signal_params)
{
  if(!BuildExecutionSignalPoints(signal_params)) return false;

  int execution_leg_index = ArraySize(signal_params.execution_legs)-1;

  // Calculate trailing entry reference and next level activation
  signal_params.execution_legs[execution_leg_index].entry_reference_price  = GetExecutionStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].next_level_price       = GetExecutionNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].take_profit_price      = GetExecutionTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.execution_legs[execution_leg_index]);
  signal_params.execution_legs[execution_leg_index].lot_size = ResolveExecutionLegLotSize(signal_params, execution_leg_index);

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_PLANNER_MQH_
