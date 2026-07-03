#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_

void UpdateExecutionLifecycle(SignalParams &signal_params)
{
  if(!signal_params.execution_initialized)
  {
    if(signal_params.deterministic_strategy)
      return;
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
