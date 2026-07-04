#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_

bool ResolveDeterministicM1Rates(double &close_0_out,
                                 double &high_1_out,
                                 double &low_1_out)
{
  static long   cached_tick_msc = -1;
  static double cached_close_0 = 0.0;
  static double cached_high_1 = 0.0;
  static double cached_low_1 = 0.0;

  MqlTick latest_tick;
  long tick_msc = 0;
  if(SymbolInfoTick(_Symbol, latest_tick))
    tick_msc = (long)latest_tick.time_msc;

  if(tick_msc > 0 && tick_msc == cached_tick_msc)
  {
    close_0_out = cached_close_0;
    high_1_out  = cached_high_1;
    low_1_out   = cached_low_1;
    return (close_0_out > 0.0 && high_1_out > 0.0 && low_1_out > 0.0);
  }

  close_0_out = iClose(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 0);
  high_1_out  = iHigh(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1);
  low_1_out   = iLow(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1);

  cached_tick_msc = tick_msc;
  cached_close_0  = close_0_out;
  cached_high_1   = high_1_out;
  cached_low_1    = low_1_out;

  return (close_0_out > 0.0 && high_1_out > 0.0 && low_1_out > 0.0);
}

double ResolveDeterministicTpPrice(const SignalTypes direction,
                                   const double entry_price,
                                   const double stop_anchor_price)
{
  if(entry_price <= 0.0 || stop_anchor_price <= 0.0)
    return 0.0;

  double risk_distance = MathAbs(entry_price - stop_anchor_price);
  if(risk_distance <= 0.0)
    return 0.0;

  double tp_factor = (TP_Percent > 0.0) ? (TP_Percent / 100.0) : 1.0;
  double tp_distance = risk_distance * tp_factor;

  if(direction == BULLISH)
    return entry_price + tp_distance;
  if(direction == BEARISH)
    return entry_price - tp_distance;

  return 0.0;
}

bool EnsureDeterministicExecutionLeg(SignalParams &signal_params)
{
  if(!signal_params.deterministic_strategy)
    return false;

  if(ArraySize(signal_params.execution_legs) > 0)
  {
    signal_params.execution_initialized = true;
    return true;
  }

  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double entry_reference = signal_params.raw_entry_trigger_price;
  double stop_anchor = signal_params.raw_stop_anchor_price;
  if(entry_reference <= 0.0 || stop_anchor <= 0.0)
    return false;

  double risk_points = MathAbs(entry_reference - stop_anchor) / point_size;
  risk_points = EnforceBrokerDistance(g_symbol_constraints, risk_points);
  if(risk_points <= 0.0)
    return false;

  ExecutionLegState leg_state;
  leg_state.level_index               = 0;
  leg_state.status                    = EXECUTION_LEG_PENDING;
  leg_state.entry_style               = EXECUTION_ENTRY_STYLE_STOP;
  leg_state.entry_reference_price     = entry_reference;
  leg_state.next_level_price          = stop_anchor;
  leg_state.take_profit_price         = ResolveDeterministicTpPrice(signal_params.signal_type,
                                                                    entry_reference,
                                                                    stop_anchor);
  leg_state.initial_take_profit_price = leg_state.take_profit_price;
  leg_state.lot_size                  = ResolveBaseExecutionLot(risk_points);
  leg_state.initial_lot_size          = leg_state.lot_size;
  leg_state.opens_position            = true;
  leg_state.limit_activation_armed    = true;

  if(leg_state.lot_size <= 0.0 || leg_state.take_profit_price <= 0.0)
    return false;

  AddElementToArray(signal_params.execution_legs, leg_state);
  signal_params.execution_initialized = true;
  signal_params.execution_base_distance_points = risk_points;
  signal_params.execution_initial_indicator_distance_points = risk_points;
  signal_params.execution_resolved_distance_points = risk_points;
  signal_params.execution_base_lot_size = leg_state.lot_size;
  signal_params.execution_entry_reference_price = entry_reference;
  signal_params.raw_risk_distance = MathAbs(entry_reference - stop_anchor);
  signal_params.raw_take_profit_price = leg_state.take_profit_price;

  ExecutionLogEvent("DETERMINISTIC_SIGNAL_INIT", signal_params, leg_state);
  return true;
}

bool DeterministicEntryTriggered(const SignalTypes direction,
                                 const double close_0,
                                 const double trigger_price)
{
  if(trigger_price <= 0.0 || close_0 <= 0.0)
    return false;

  if(direction == BULLISH)
    return close_0 > trigger_price;
  if(direction == BEARISH)
    return close_0 < trigger_price;

  return false;
}

bool DeterministicStopTriggered(const SignalParams &signal_params,
                                const double close_0)
{
  if(close_0 <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return close_0 < signal_params.raw_stop_anchor_price;
  if(signal_params.signal_type == BEARISH)
    return close_0 > signal_params.raw_stop_anchor_price;

  return false;
}

bool DeterministicTakeProfitTriggered(const SignalParams &signal_params,
                                      const ExecutionLegState &leg_state)
{
  if(leg_state.take_profit_price <= 0.0)
    return false;

  double exit_side_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, false);
  if(exit_side_price <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return exit_side_price >= leg_state.take_profit_price;
  if(signal_params.signal_type == BEARISH)
    return exit_side_price <= leg_state.take_profit_price;

  return false;
}

bool DeterministicMacroStillConfirms(const SignalParams &signal_params)
{
  double macro_now = 0.0;
  double macro_prev = 0.0;
  return EvaluateDeterministicMacroConfirmation(signal_params.strategy_id,
                                                signal_params.signal_type,
                                                macro_now,
                                                macro_prev);
}

int ResolveDeterministicEntryBaseShift(const SignalParams &signal_params)
{
  int base_shift = signal_params.strategy_base_delay;
  if(base_shift <= 0)
    base_shift = DeterministicStrategyBaseDelay(signal_params.strategy_id);
  return base_shift;
}

double ResolveDeterministicPendingEntryCandidate(const SignalTypes direction,
                                                 const double high_1,
                                                 const double low_1)
{
  if(direction == BULLISH)
    return high_1;
  if(direction == BEARISH)
    return low_1;

  return 0.0;
}

bool DeterministicPendingEntryAnchorImproves(const SignalTypes direction,
                                            const double current_trigger,
                                            const double candidate_trigger,
                                            const double stop_anchor,
                                            const double point_size)
{
  if(current_trigger <= 0.0 || candidate_trigger <= 0.0 || stop_anchor <= 0.0)
    return false;

  double tolerance = point_size;
  if(tolerance <= 0.0)
    tolerance = 0.0000001;

  if(direction == BULLISH)
  {
    if(candidate_trigger <= stop_anchor + tolerance)
      return false;
    return (candidate_trigger < current_trigger - tolerance);
  }

  if(direction == BEARISH)
  {
    if(candidate_trigger >= stop_anchor - tolerance)
      return false;
    return (candidate_trigger > current_trigger + tolerance);
  }

  return false;
}

bool DeterministicPendingEntryRiskBrokerSafe(const double entry_trigger,
                                            const double stop_anchor,
                                            const double point_size,
                                            double &risk_points_out)
{
  risk_points_out = 0.0;

  if(entry_trigger <= 0.0 || stop_anchor <= 0.0 || point_size <= 0.0)
    return false;

  double raw_risk_points = MathAbs(entry_trigger - stop_anchor) / point_size;
  if(raw_risk_points <= 0.0)
    return false;

  double broker_safe_points = EnforceBrokerDistance(g_symbol_constraints,
                                                    raw_risk_points);
  if(broker_safe_points > raw_risk_points + 0.0000001)
    return false;

  risk_points_out = broker_safe_points;
  return (risk_points_out > 0.0);
}

bool RefreshDeterministicPendingEntryAnchor(SignalParams &signal_params,
                                            const int leg_index,
                                            const double close_0,
                                            const double high_1,
                                            const double low_1)
{
  if(!signal_params.deterministic_strategy)
    return false;
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return false;
  if(DeterministicSignalHasBrokerExposure(signal_params))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(leg_state.status != EXECUTION_LEG_PENDING)
    return false;
  if(leg_state.position_ticket > 0 || leg_state.entry_price > 0.0)
    return false;

  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double current_trigger = signal_params.raw_entry_trigger_price;
  if(current_trigger <= 0.0)
    current_trigger = leg_state.entry_reference_price;

  double stop_anchor = signal_params.raw_stop_anchor_price;
  double candidate_trigger = ResolveDeterministicPendingEntryCandidate(signal_params.signal_type,
                                                                      high_1,
                                                                      low_1);
  if(!DeterministicPendingEntryAnchorImproves(signal_params.signal_type,
                                             current_trigger,
                                             candidate_trigger,
                                             stop_anchor,
                                             point_size))
    return false;

  double risk_before_points = MathAbs(current_trigger - stop_anchor) / point_size;
  double risk_after_points = 0.0;
  if(!DeterministicPendingEntryRiskBrokerSafe(candidate_trigger,
                                             stop_anchor,
                                             point_size,
                                             risk_after_points))
    return false;

  double tp_price = ResolveDeterministicTpPrice(signal_params.signal_type,
                                               candidate_trigger,
                                               stop_anchor);
  if(tp_price <= 0.0)
    return false;

  double lot_size = ResolveBaseExecutionLot(risk_after_points);
  if(lot_size <= 0.0)
    return false;

  double tp_before = leg_state.take_profit_price;
  double lot_before = leg_state.lot_size;

  signal_params.raw_entry_trigger_price = candidate_trigger;
  signal_params.entry_price = candidate_trigger;
  signal_params.stop_loss = stop_anchor;
  signal_params.execution_entry_reference_price = candidate_trigger;
  signal_params.execution_base_distance_points = risk_after_points;
  signal_params.execution_initial_indicator_distance_points = risk_after_points;
  signal_params.execution_resolved_distance_points = risk_after_points;
  signal_params.execution_base_lot_size = lot_size;
  signal_params.raw_risk_distance = MathAbs(candidate_trigger - stop_anchor);
  signal_params.raw_take_profit_price = tp_price;

  leg_state.entry_reference_price = candidate_trigger;
  leg_state.next_level_price = stop_anchor;
  leg_state.take_profit_price = tp_price;
  leg_state.initial_take_profit_price = tp_price;
  leg_state.lot_size = lot_size;
  leg_state.initial_lot_size = lot_size;
  signal_params.execution_legs[leg_index] = leg_state;

  ExecutionLogDeterministicEntryRefresh(signal_params,
                                        leg_state,
                                        current_trigger,
                                        candidate_trigger,
                                        candidate_trigger,
                                        close_0,
                                        high_1,
                                        low_1,
                                        risk_before_points,
                                        risk_after_points,
                                        tp_before,
                                        tp_price,
                                        lot_before,
                                        lot_size,
                                        "closer_to_stop");
  return true;
}

void RefreshDeterministicTpFromBrokerEntry(SignalParams &signal_params,
                                           const int leg_index)
{
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  double entry_price = leg_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = leg_state.entry_reference_price;

  double tp_price = ResolveDeterministicTpPrice(signal_params.signal_type,
                                                entry_price,
                                                signal_params.raw_stop_anchor_price);
  if(tp_price <= 0.0)
    return;

  leg_state.take_profit_price = tp_price;
  leg_state.initial_take_profit_price = tp_price;
  signal_params.raw_take_profit_price = tp_price;
  signal_params.execution_legs[leg_index] = leg_state;
}

void UpdateDeterministicExecutionLifecycle(SignalParams &signal_params)
{
  if(signal_params.signal_state == CLOSED)
    return;

  if(!EnsureDeterministicExecutionLeg(signal_params))
  {
    signal_params.signal_state = CLOSED;
    return;
  }

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);

  int leg_index = 0;
  if(ArraySize(signal_params.execution_legs) <= leg_index)
    return;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  double close_0 = 0.0;
  double high_1 = 0.0;
  double low_1 = 0.0;
  if(!ResolveDeterministicM1Rates(close_0, high_1, low_1))
    return;

  if(leg_state.status == EXECUTION_LEG_PENDING)
  {
    RefreshDeterministicPendingEntryAnchor(signal_params,
                                           leg_index,
                                           close_0,
                                           high_1,
                                           low_1);
    leg_state = signal_params.execution_legs[leg_index];

    if(!DeterministicEntryTriggered(signal_params.signal_type,
                                    close_0,
                                    signal_params.raw_entry_trigger_price))
      return;

    double current_entry_anchor = ResolveDeterministicPendingEntryCandidate(signal_params.signal_type,
                                                                           high_1,
                                                                           low_1);
    if(!DeterministicEntryTriggered(signal_params.signal_type,
                                    close_0,
                                    current_entry_anchor))
    {
      ExecutionLogDeterministicEntryAnchorBlocked(signal_params,
                                                  leg_state,
                                                  close_0,
                                                  high_1,
                                                  low_1,
                                                  current_entry_anchor,
                                                  "current_anchor_not_broken");
      return;
    }

    double base_ma_now = 0.0;
    double base_ma_prev = 0.0;
    double macro_ma_now = 0.0;
    double macro_ma_prev = 0.0;
    int base_shift = ResolveDeterministicEntryBaseShift(signal_params);
    bool base_confirms = EvaluateDeterministicCurrentBaseConfirmation(signal_params.strategy_id,
                                                                      signal_params.signal_type,
                                                                      base_ma_now,
                                                                      base_ma_prev);
    bool macro_confirms = EvaluateDeterministicMacroConfirmation(signal_params.strategy_id,
                                                                 signal_params.signal_type,
                                                                 macro_ma_now,
                                                                 macro_ma_prev);

    if(!base_confirms)
    {
      leg_state.status = EXECUTION_LEG_COMPLETED;
      signal_params.execution_legs[leg_index] = leg_state;
      signal_params.signal_state = CLOSED;
      ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_BASE_EXPIRED",
                                                 signal_params,
                                                 leg_state,
                                                 base_shift,
                                                 base_confirms,
                                                 base_ma_now,
                                                 base_ma_prev,
                                                 DETERMINISTIC_MACRO_DELAY,
                                                 macro_confirms,
                                                 macro_ma_now,
                                                 macro_ma_prev,
                                                 close_0,
                                                 high_1,
                                                 low_1);
      return;
    }

    if(!macro_confirms)
    {
      leg_state.status = EXECUTION_LEG_COMPLETED;
      signal_params.execution_legs[leg_index] = leg_state;
      signal_params.signal_state = CLOSED;
      ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_MACRO_EXPIRED",
                                                 signal_params,
                                                 leg_state,
                                                 base_shift,
                                                 base_confirms,
                                                 base_ma_now,
                                                 base_ma_prev,
                                                 DETERMINISTIC_MACRO_DELAY,
                                                 macro_confirms,
                                                 macro_ma_now,
                                                 macro_ma_prev,
                                                 close_0,
                                                 high_1,
                                                 low_1);
      return;
    }

    ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_ENTRY_CONFIRM",
                                               signal_params,
                                               leg_state,
                                               base_shift,
                                               base_confirms,
                                               base_ma_now,
                                               base_ma_prev,
                                               DETERMINISTIC_MACRO_DELAY,
                                               macro_confirms,
                                               macro_ma_now,
                                               macro_ma_prev,
                                               close_0,
                                               high_1,
                                               low_1);

    double requested_lot = leg_state.lot_size;
    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, requested_lot);
    if(ExecuteExecutionLegTrade(signal_params,
                                leg_state,
                                ExecutionResolvePointSize(),
                                normalized_volume))
    {
      RefreshDeterministicTpFromBrokerEntry(signal_params, leg_index);
      DeterministicSignalStatsRecordFeature(signal_params,
                                            signal_params.execution_legs[leg_index]);
      ExecutionLogEvent("DETERMINISTIC_ENTRY", signal_params, signal_params.execution_legs[leg_index]);
    }
    return;
  }

  if(leg_state.status != EXECUTION_LEG_ACTIVE)
    return;

  if(DeterministicStopTriggered(signal_params, close_0))
  {
    CloseAllExecutionLegs(signal_params, ExecutionResolvePointSize());
    signal_params.deterministic_stats_terminal_reason = "SL";
    ExecutionLogEvent("DETERMINISTIC_SL", signal_params, leg_state);
    return;
  }

  if(DeterministicTakeProfitTriggered(signal_params, leg_state))
  {
    CloseAllExecutionLegs(signal_params, ExecutionResolvePointSize());
    signal_params.deterministic_stats_terminal_reason = "TP";
    int source_attempt_count = 0;
    bool newly_consumed = RegisterDeterministicSourceConsumedTp(signal_params,
                                                               source_attempt_count);
    ExecutionLogEvent("DETERMINISTIC_TP", signal_params, leg_state);
    if(newly_consumed)
    {
      ExecutionLogDeterministicSourceConsumed(signal_params,
                                              leg_state,
                                              source_attempt_count,
                                              "TP");
    }
    return;
  }

  if(IsExecutionSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

void UpdateExecutionLifecycle(SignalParams &signal_params)
{
  if(signal_params.deterministic_strategy)
  {
    UpdateDeterministicExecutionLifecycle(signal_params);
    return;
  }

  if(!signal_params.execution_initialized)
  {
    return;
  }
  if(signal_params.signal_state == CLOSED)
    return;

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);

  double         point_size        = ExecutionResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            execution_leg_index  = ArraySize(signal_params.execution_legs)-1;
  ExecutionLegState execution_leg        = signal_params.execution_legs[execution_leg_index];

  if(LimitSignalExpiredOnStructureChange(signal_params))
  {
    signal_params.signal_state = CLOSED;
    ExecutionLogEvent("LIMIT_EXPIRED_STRUCTURE", signal_params, execution_leg);
    return;
  }

  if(execution_leg.status == EXECUTION_LEG_PENDING)
  {
    if(UpdateExecutionLegForSignal(signal_params))
      execution_leg = signal_params.execution_legs[execution_leg_index];

    double requested_lot = execution_leg.lot_size;
    double normalized_volume = 0.0;
    if(execution_leg.opens_position && requested_lot > 0.0)
      normalized_volume = NormalizeVolumeForSymbol(_Symbol, requested_lot);
    double entry_side_price = ExecutionCurrentPriceForDirection(direction, true);
    bool use_limit_edge_activation = UsesNonBreakoutLimitEdgeActivation(signal_params, execution_leg);

    if(use_limit_edge_activation && !execution_leg.limit_activation_armed)
    {
      if(ShouldArmNonBreakoutLimitActivation(signal_params, execution_leg, entry_side_price))
      {
        execution_leg.limit_activation_armed = true;
        signal_params.execution_legs[execution_leg_index] = execution_leg;
        ExecutionLogEvent("LIMIT_EDGE_ARMED", signal_params, execution_leg);
      }
    }

    bool can_activate = (!use_limit_edge_activation || execution_leg.limit_activation_armed);
    if(can_activate &&
       ExecutionShouldActivateStopLeg(signal_params, execution_leg, direction))
    {
      if(execution_leg.opens_position &&
         ExecutionUsesTargetProfitLotMode() &&
         requested_lot <= 0.0)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_ACTIVATION_FAILED_TARGET_LOT", signal_params, execution_leg);
        return;
      }

      if(ExecuteExecutionLegTrade(signal_params, execution_leg, point_size, normalized_volume))
      {
        UpdateExecutionLegForSignal(signal_params);
        execution_leg = signal_params.execution_legs[execution_leg_index];
        ExecutionLogEvent("LEVEL_REACHED", signal_params, execution_leg);
      }
      else if(execution_leg.opens_position && ExecutionUsesTargetProfitLotMode())
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_ACTIVATION_FAILED_SEND", signal_params, execution_leg);
        return;
      }
    }
  }

  execution_leg = signal_params.execution_legs[execution_leg_index];

  if(execution_leg.status == EXECUTION_LEG_ACTIVE)
  {
    double current_price = ExecutionCurrentPriceForDirection(direction, false);
    if(execution_leg.take_profit_price > 0.0)
    {
      bool hit_tp = (direction == BULLISH && current_price >= execution_leg.take_profit_price) ||
                    (direction == BEARISH && current_price <= execution_leg.take_profit_price);
      if(hit_tp)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_TP_HIT", signal_params, execution_leg);
        return;
      }
    }
    bool next_level_triggered = ExecutionShouldActivateNextLegLimit(signal_params,
                                                                 execution_leg,
                                                                 direction);
    if(next_level_triggered)
    {
      ExecutionLogNextLegTriggerDecision(signal_params, execution_leg, direction);
      int level_stop_limit = ResolveFoundationLevelStopLimit();
      bool level_limit_hit = ShouldBlockNextLevelByStopLimit(level_stop_limit,
                                                             execution_leg.level_index);
      ExecutionLogStopLimitDecision(signal_params,
                               execution_leg,
                               level_stop_limit,
                               level_limit_hit);

      if(level_limit_hit)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("EXECUTION_STOP_LEVEL_LIMIT", signal_params, execution_leg);
      }
      else
      {
        BuildExecutionLegForSignal(signal_params);
        ExecutionLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, execution_leg);
      }
    }
  }

  if(IsExecutionSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
