//+------------------------------------------------------------------+
//|              trading_signals/pivot_trial_matrix_lifecycle      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_

bool BuildPivotTrialCensoredOutcome(const PivotTrialEntry &trial,
                                    const MqlTick &tick,
                                    const string terminal_reason,
                                    const string exclusion_reason,
                                    PivotTrialOutcome &outcome_out);

string PivotTrialLaneId(const string origin_id,
                        const PivotTrialEntryPolicies entry_policy,
                        const int tp_r_multiple)
{
  string payload = origin_id + "|" +
                   PivotTrialEntryPolicyLabel(entry_policy) + "|" +
                   IntegerToString(tp_r_multiple);
  return "lane_" + StringFormat("%I64u", PivotTrialStableHash(payload));
}

string PivotTrialId(const string lane_id)
{
  return "trial_" + StringFormat("%I64u", PivotTrialStableHash(lane_id));
}

string PivotTrialOutcomeId(const string trial_id)
{
  return "outcome_" +
         StringFormat("%I64u", PivotTrialStableHash(trial_id + "|TERMINAL"));
}

string PivotTrialParityId(const string broker_signal_id)
{
  return "parity_" + StringFormat("%I64u",
                                   PivotTrialStableHash(broker_signal_id +
                                                        "|BROKER_PARITY_SHADOW"));
}

void PrimePivotTrialQuoteFacts(const SignalTypes direction,
                               const MqlTick &tick,
                               const BrokerExecutionCheck &broker_check,
                               PivotTrialGeometry &geometry)
{
  geometry.Reset();
  geometry.direction = direction;
  geometry.entry_bid = tick.bid;
  geometry.entry_ask = tick.ask;
  geometry.entry_price = PivotTrialEntryPriceFromTick(direction, tick);
  geometry.entry_quote_side = PivotTrialEntryQuoteSide(direction);
  geometry.exit_quote_side = PivotTrialExitQuoteSide(direction);
  geometry.point_size = broker_check.point_size;
  geometry.trade_tick_size = broker_check.trade_tick_size;
  geometry.stops_level_points = broker_check.stops_distance_points;
  geometry.freeze_level_points = broker_check.freeze_distance_points;
  if(geometry.point_size > 0.0 && tick.ask >= tick.bid)
    geometry.spread_points = (tick.ask - tick.bid) / geometry.point_size;
}

bool ResolvePivotTrialMoneyPlan(const PivotTrialGeometry &geometry,
                                PivotTrialMoneyPlan &money_plan)
{
  money_plan.Reset();
  double expected_stop_loss = 0.0;
  double risk_budget_utilization = 0.0;
  string reason = "";
  if(!ResolveExecutionVolumePlan(geometry.direction,
                                 geometry.entry_price,
                                 geometry.stop_loss_price,
                                 geometry.take_profit_price,
                                 money_plan.requested_volume,
                                 money_plan.normalized_volume,
                                 money_plan.risk_budget_amount,
                                 expected_stop_loss,
                                 money_plan.virtual_expected_take_profit,
                                 money_plan.virtual_expected_reward_risk_ratio,
                                 risk_budget_utilization,
                                 reason))
  {
    money_plan.invalid_reason = reason;
    return false;
  }
  money_plan.virtual_expected_stop_loss = -MathAbs(expected_stop_loss);
  money_plan.complete = true;
  return true;
}

bool LoadPivotTrialBrokerFacts(BrokerExecutionCheck &facts_out)
{
  facts_out.Reset();
  if(BrokerConstraintsNeedRefresh() &&
     !RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints))
    return false;
  facts_out.point_size = g_symbol_constraints.point_size;
  facts_out.trade_tick_size = g_symbol_constraints.tick_size;
  facts_out.stops_distance_points =
    g_symbol_constraints.stops_level_points;
  facts_out.freeze_distance_points =
    g_symbol_constraints.freeze_level_points;
  return facts_out.point_size > 0.0 && facts_out.trade_tick_size > 0.0 &&
         facts_out.stops_distance_points >= 0.0 &&
         facts_out.freeze_distance_points >= 0.0;
}

bool BuildBrokerParityTrial(const PivotSignal &signal,
                            const MqlTick &entry_tick,
                            const MqlTradeRequest &request,
                            const BrokerExecutionCheck &send_check,
                            PivotTrialEntry &trial_out)
{
  trial_out.Reset();
  double point_size = send_check.point_size;
  double trade_tick_size = send_check.trade_tick_size;
  double price_tolerance = MathMin(point_size, trade_tick_size) * 1e-7;
  int macro_seconds = PeriodSeconds(signal.pivot_timeframe);
  datetime origin_expiry = macro_seconds > 0
                           ? signal.active_bar_open + macro_seconds
                           : 0;
  bool trigger_in_origin_window =
    origin_expiry > signal.active_bar_open &&
    signal.trigger_time >= signal.active_bar_open &&
    signal.trigger_time < origin_expiry;
  ENUM_ORDER_TYPE expected_type = signal.direction == BULLISH
                                  ? ORDER_TYPE_BUY
                                  : ORDER_TYPE_SELL;
  if(!send_check.allowed || signal.origin_id == "" ||
     signal.window_id == "" || signal.broker_signal_id == "" ||
     signal.active_bar_open <= 0 || signal.trigger_time <= 0 ||
     !trigger_in_origin_window ||
     (signal.direction != BULLISH && signal.direction != BEARISH) ||
     !PivotTrialQuoteValid(entry_tick) || point_size <= 0.0 ||
     trade_tick_size <= 0.0 || send_check.stops_distance_points < 0.0 ||
     send_check.freeze_distance_points < 0.0 ||
     send_check.broker_time < signal.trigger_time ||
     request.symbol != _Symbol || request.magic != g_execution_magic ||
     request.type != expected_type || request.type_filling != ORDER_FILLING_FOK ||
     request.volume <= 0.0 || request.price <= 0.0 || request.sl <= 0.0 ||
     request.tp <= 0.0 || send_check.requested_volume <= 0.0 ||
     MathAbs(entry_tick.bid - send_check.bid) > price_tolerance ||
     MathAbs(entry_tick.ask - send_check.ask) > price_tolerance ||
     MathAbs(request.price - (signal.direction == BULLISH
                             ? send_check.ask : send_check.bid)) >
       price_tolerance ||
     MathAbs(request.price - send_check.planned_entry_price) > price_tolerance ||
     MathAbs(request.sl - send_check.stop_loss_price) > price_tolerance ||
     MathAbs(request.tp - send_check.take_profit_price) > price_tolerance ||
     MathAbs(request.volume - send_check.normalized_volume) > 1e-8 ||
     send_check.quote_expected_stop_loss <= 0.0 ||
     send_check.quote_expected_take_profit <= 0.0 ||
     send_check.quote_expected_reward_risk_ratio <= 0.0)
  {
    PivotV14MarkFailed("PARITY_SOURCE_FACTS_INVALID", "", 0,
      StringFormat("broker=%s|trigger=%I64d|send=%I64d|origin_window=%d|allowed=%d|type=%d|expected_type=%d|fok=%d|quote_valid=%d|point=%.10f|tick_size=%.10f|tick_bid=%.10f|tick_ask=%.10f|check_bid=%.10f|check_ask=%.10f|request_price=%.10f|planned_price=%.10f|request_sl=%.10f|planned_sl=%.10f|request_tp=%.10f|planned_tp=%.10f|request_volume=%.10f|planned_volume=%.10f|stop_money=%.10f|tp_money=%.10f|money_rr=%.10f",
        signal.broker_signal_id, (long)signal.trigger_time,
        (long)send_check.broker_time, (int)trigger_in_origin_window,
        (int)send_check.allowed, (int)request.type, (int)expected_type,
        (int)(request.type_filling == ORDER_FILLING_FOK),
        (int)PivotTrialQuoteValid(entry_tick), point_size, trade_tick_size,
        entry_tick.bid, entry_tick.ask, send_check.bid, send_check.ask,
        request.price, send_check.planned_entry_price,
        request.sl, send_check.stop_loss_price, request.tp, send_check.take_profit_price,
        request.volume, send_check.normalized_volume, send_check.quote_expected_stop_loss,
        send_check.quote_expected_take_profit, send_check.quote_expected_reward_risk_ratio));
    return false;
  }

  double risk_distance = signal.direction == BULLISH
                         ? request.price - request.sl
                         : request.sl - request.price;
  long risk_ticks = (long)MathRound(risk_distance / trade_tick_size);
  if(risk_distance <= 0.0 || risk_ticks <= 0 ||
     MathAbs(risk_distance - (double)risk_ticks * trade_tick_size) >
       price_tolerance ||
     !PivotTrialExactIntegerR(signal.direction, request.price, request.sl,
                              request.tp, 1, trade_tick_size))
  {
    PivotV14MarkFailed("PARITY_RISK_GEOMETRY_INVALID", "", 0,
      StringFormat("broker=%s|entry=%.16f|sl=%.16f|tp=%.16f|risk=%.16f|ticks=%I64d|tick_size=%.16f|tolerance=%.16f",
        signal.broker_signal_id, request.price, request.sl, request.tp,
        risk_distance, risk_ticks, trade_tick_size, price_tolerance));
    return false;
  }

  trial_out.identity.origin_id = signal.origin_id;
  trial_out.identity.window_id = signal.window_id;
  trial_out.identity.broker_signal_id = signal.broker_signal_id;
  trial_out.identity.parity_trial_id = PivotTrialParityId(signal.broker_signal_id);
  trial_out.identity.trial_id = trial_out.identity.parity_trial_id;
  trial_out.identity.role = PIVOT_TRIAL_ROLE_BROKER_PARITY;
  trial_out.identity.entry_policy = PIVOT_TRIAL_ENTRY_STRUCTURAL;
  trial_out.identity.tp_r_multiple = 1;
  trial_out.level_id = signal.level_id;
  trial_out.direction = signal.direction;
  trial_out.declared_time = send_check.broker_time;
  trial_out.entry_time = send_check.broker_time;
  trial_out.origin_expiry_time = origin_expiry;
  trial_out.midpoint_touched = true;
  trial_out.origin_feature_snapshot_complete = signal.features.complete;

  trial_out.geometry.direction = signal.direction;
  trial_out.geometry.entry_bid = send_check.bid;
  trial_out.geometry.entry_ask = send_check.ask;
  trial_out.geometry.entry_price = request.price;
  trial_out.geometry.entry_quote_side = PivotTrialEntryQuoteSide(signal.direction);
  trial_out.geometry.exit_quote_side = PivotTrialExitQuoteSide(signal.direction);
  trial_out.geometry.requested_risk_distance_price = risk_distance;
  trial_out.geometry.requested_risk_distance_points = risk_distance / point_size;
  trial_out.geometry.normalized_risk_ticks = risk_ticks;
  trial_out.geometry.normalized_risk_distance_price = risk_distance;
  trial_out.geometry.normalized_risk_distance_points = risk_distance / point_size;
  trial_out.geometry.stop_loss_price = request.sl;
  trial_out.geometry.take_profit_price = request.tp;
  trial_out.geometry.spread_points = (send_check.ask - send_check.bid) / point_size;
  trial_out.geometry.point_size = point_size;
  trial_out.geometry.trade_tick_size = trade_tick_size;
  trial_out.geometry.stops_level_points = send_check.stops_distance_points;
  trial_out.geometry.freeze_level_points = send_check.freeze_distance_points;
  if(!CalculateStrictRiskDistancePoints(trial_out.geometry.spread_points,
                                        point_size,
                                        trade_tick_size,
                                        send_check.stops_distance_points,
                                        send_check.freeze_distance_points,
                                        trial_out.geometry.minimum_risk_distance_points))
  {
    PivotV14MarkFailed("PARITY_MINIMUM_DISTANCE_FAILED", "", 0, signal.broker_signal_id);
    return false;
  }
  trial_out.geometry.distance_eligible =
    trial_out.geometry.normalized_risk_distance_points + 1e-7 >=
    trial_out.geometry.minimum_risk_distance_points;
  // Parity copies an accepted request. Preserve research distance eligibility
  // as a fact, but never use its extra tick to veto the broker's shadow.
  trial_out.geometry.geometry_equivalence_id =
    PivotTrialGeometryEquivalenceId(signal.origin_id, signal.direction,
                                    request.price, request.sl, request.tp);
  trial_out.geometry.valid = trial_out.geometry.geometry_equivalence_id != "";
  trial_out.money_plan.risk_budget_amount = send_check.risk_budget_amount;
  trial_out.money_plan.requested_volume = send_check.requested_volume;
  trial_out.money_plan.normalized_volume = request.volume;
  trial_out.money_plan.virtual_expected_stop_loss =
    -MathAbs(send_check.quote_expected_stop_loss);
  trial_out.money_plan.virtual_expected_take_profit =
    MathAbs(send_check.quote_expected_take_profit);
  trial_out.money_plan.virtual_expected_reward_risk_ratio =
    send_check.quote_expected_reward_risk_ratio;
  trial_out.money_plan.complete = trial_out.geometry.valid;
  trial_out.eligibility_status = trial_out.geometry.valid
                                 ? PIVOT_TRIAL_ELIGIBILITY_ACTIVE
                                 : PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
  trial_out.origin_window_active_at_entry =
    origin_expiry > trial_out.entry_time;
  return trial_out.geometry.valid;
}

void BuildBrokerParityActiveState(const PivotTrialEntry &trial,
                                  PivotTrialActiveState &state_out)
{
  state_out.Reset();
  state_out.trial.CopyFrom(trial);
  state_out.parity.origin_id = trial.identity.origin_id;
  state_out.parity.broker_signal_id = trial.identity.broker_signal_id;
  state_out.parity.parity_trial_id = trial.identity.parity_trial_id;
  state_out.parity.accepted_request_copied = true;
  state_out.export_recorded = true;
  state_out.active = true;
}

bool DeclareBrokerParityShadow(PivotSignal &signal,
                               const MqlTick &entry_tick,
                               const MqlTradeRequest &request,
                               const BrokerExecutionCheck &send_check)
{
  if(!PivotV14Enabled())
    return true;
  if(!PivotV14Ready() || PivotTrialResearchIntegrityFailed() ||
     signal.parity_trial_id != "")
    return false;

  PivotTrialEntry trial;
  if(!BuildBrokerParityTrial(signal, entry_tick, request, send_check, trial) ||
     !PivotV14RecordVirtualTrial(trial))
    return false;
  PivotTrialActiveState state;
  BuildBrokerParityActiveState(trial, state);
  string reason = "";
  if(!AppendPivotTrialActiveState(state, reason))
    return false;
  signal.parity_trial_id = trial.identity.parity_trial_id;
  return true;
}

bool BuildInitialPivotTrial(const PivotSignal &signal,
                            const MqlTick &origin_tick,
                            const PivotTrialEntryPolicies entry_policy,
                            const int tp_r_multiple,
                            PivotTrialEntry &trial_out)
{
  trial_out.Reset();
  trial_out.identity.origin_id = signal.origin_id;
  trial_out.identity.window_id = signal.window_id;
  trial_out.identity.trial_id = PivotTrialId(PivotTrialLaneId(
    signal.origin_id, entry_policy, tp_r_multiple));
  trial_out.identity.role = PIVOT_TRIAL_ROLE_H1;
  trial_out.identity.entry_policy = entry_policy;
  trial_out.identity.tp_r_multiple = tp_r_multiple;
  trial_out.level_id = signal.level_id;
  trial_out.direction = signal.direction;
  trial_out.declared_time = signal.trigger_time;
  int pivot_seconds = PeriodSeconds(signal.pivot_timeframe);
  trial_out.origin_expiry_time = pivot_seconds > 0
                                 ? signal.active_bar_open + pivot_seconds
                                 : 0;
  if(entry_policy == PIVOT_TRIAL_ENTRY_STRUCTURAL)
  {
    PrimePivotTrialQuoteFacts(signal.direction,
                              origin_tick,
                              signal.execution.observation_check,
                              trial_out.geometry);
    trial_out.entry_time = signal.trigger_time;
    trial_out.midpoint_touched = true;
    trial_out.origin_window_active_at_entry =
      trial_out.origin_expiry_time > trial_out.entry_time;
  }
  double pivot_price = 0.0;
  if(!PivotTradePrice(signal.levels, signal.level_id, pivot_price))
  {
    trial_out.ineligible_reason = "TOUCHED_PIVOT_PRICE_INVALID";
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  trial_out.midpoint_50_price = pivot_price;
  trial_out.origin_feature_snapshot_complete = signal.features.complete;

  bool boundary_available = false;
  double boundary_price = 0.0;
  if(!PivotTrialNextOutwardBoundary(signal.direction, signal.level_id,
                                    signal.levels, boundary_available,
                                    boundary_price))
  {
    trial_out.ineligible_reason = "NEXT_PIVOT_BOUNDARY_INVALID";
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  trial_out.boundary_available = boundary_available;
  trial_out.boundary_price = boundary_price;
  if(!PivotTrialMidpointPrice(signal.direction,
                              pivot_price,
                              boundary_price,
                              trial_out.midpoint_50_price))
  {
    trial_out.ineligible_reason = "MIDPOINT_GEOMETRY_INVALID";
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }

  if(entry_policy == PIVOT_TRIAL_ENTRY_MIDPOINT_50)
  {
    trial_out.midpoint_touched = false;
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED;
    trial_out.ineligible_reason = "MIDPOINT_PENDING_TOUCH";
    return true;
  }

  double entry_price = PivotTrialEntryPriceFromTick(signal.direction, origin_tick);
  double stop_price = signal.route.structural_stop_loss;
  double requested_risk = MathAbs(entry_price - stop_price);
  if(entry_price <= 0.0 || stop_price <= 0.0 || requested_risk <= 0.0 ||
     !BuildPivotTrialGeometryAtStop(
       signal.origin_id,
       signal.direction,
       origin_tick,
       stop_price,
       tp_r_multiple,
       signal.execution.observation_check.point_size,
       signal.execution.observation_check.trade_tick_size,
       signal.execution.observation_check.stops_distance_points,
       signal.execution.observation_check.freeze_distance_points,
       false,
       trial_out.geometry))
  {
    if(trial_out.geometry.entry_bid <= 0.0 ||
       trial_out.geometry.point_size <= 0.0)
      PrimePivotTrialQuoteFacts(signal.direction,
                                origin_tick,
                                signal.execution.observation_check,
                                trial_out.geometry);
    trial_out.ineligible_reason = trial_out.geometry.invalid_reason == ""
                                  ? "STRUCTURAL_GEOMETRY_INVALID"
                                  : trial_out.geometry.invalid_reason;
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  if(!trial_out.geometry.distance_eligible)
  {
    trial_out.ineligible_reason = "MINIMUM_RISK_DISTANCE_NOT_MET";
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE;
    return true;
  }
  if(!ResolvePivotTrialMoneyPlan(trial_out.geometry, trial_out.money_plan))
  {
    trial_out.ineligible_reason = trial_out.money_plan.invalid_reason;
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY;
    return true;
  }
  trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  trial_out.ineligible_reason = "";
  return true;
}

void BuildInitialPivotTrialActiveState(const PivotTrialEntry &trial,
                                       PivotTrialActiveState &state_out)
{
  state_out.Reset();
  state_out.trial.CopyFrom(trial);
  state_out.pending_entry = trial.identity.entry_policy ==
                            PIVOT_TRIAL_ENTRY_MIDPOINT_50 &&
                            !trial.midpoint_touched;
  state_out.export_recorded = !state_out.pending_entry;
  state_out.active = true;
}

bool RecordPivotTrialOutcome(const PivotTrialOutcome &outcome)
{
  if(PivotV14RecordVirtualOutcome(outcome))
    return true;
  PivotV14MarkFailed("VIRTUAL_OUTCOME_RECORD_FAILED");
  return false;
}

bool BuildPivotTrialIneligibleOutcome(const PivotTrialEntry &trial,
                                     const MqlTick &tick,
                                     const string terminal_reason,
                                     PivotTrialOutcome &outcome_out)
{
  outcome_out.Reset();
  if(!PivotTrialQuoteValid(tick) || trial.identity.trial_id == "" ||
     terminal_reason == "")
    return false;
  outcome_out.outcome_id = PivotTrialOutcomeId(trial.identity.trial_id);
  outcome_out.identity.CopyFrom(trial.identity);
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time > trial.declared_time
                              ? tick.time : trial.declared_time + 1;
  outcome_out.first_touch = PIVOT_TRIAL_FIRST_TOUCH_INELIGIBLE;
  outcome_out.terminal_reason = terminal_reason;
  outcome_out.observed_exit_bid = tick.bid;
  outcome_out.observed_exit_ask = tick.ask;
  outcome_out.observed_exit_price = PivotTrialExitPriceFromTick(trial.direction,
                                                                 tick);
  outcome_out.exit_quote_side = PivotTrialExitQuoteSide(trial.direction);
  outcome_out.virtual_binary_eligible = false;
  outcome_out.virtual_binary_target = -1;
  outcome_out.virtual_exclusion_reason = terminal_reason;
  outcome_out.first_touch_consistent = true;
  return true;
}

bool FinalizePendingMidpointIneligibleAt(
  const int index,
  const PivotTrialActiveState &state,
  const MqlTick &tick,
  const BrokerExecutionCheck &facts,
  const PivotTrialEligibilityStatuses eligibility_status,
  const string terminal_reason)
{
  if(index < 0 || index >= PivotTrialActiveStateCount() ||
     terminal_reason == "")
    return false;
  PivotTrialEntry trial(state.trial);
  trial.entry_time = tick.time;
  trial.midpoint_touched = true;
  trial.origin_window_active_at_entry = trial.origin_expiry_time > tick.time;
  PrimePivotTrialQuoteFacts(trial.direction, tick, facts, trial.geometry);
  trial.money_plan.Reset();
  trial.eligibility_status = eligibility_status;
  trial.ineligible_reason = terminal_reason;

  PivotTrialOutcome outcome;
  if(!PivotV14RecordVirtualTrial(trial) ||
     !BuildPivotTrialIneligibleOutcome(trial,
                                       tick,
                                       terminal_reason,
                                       outcome) ||
     !RecordPivotTrialOutcome(outcome))
    return false;
  return RemovePivotTrialActiveStateAt(index);
}

bool FinalizePendingMidpointLaneAt(const int index,
                                   const MqlTick &tick,
                                   const string terminal_reason)
{
  if(index < 0 || index >= PivotTrialActiveStateCount())
    return false;
  PivotTrialActiveState state;
  if(!CopyPivotTrialActiveStateAt(index, state) || !state.active ||
     !state.pending_entry ||
     state.trial.identity.role != PIVOT_TRIAL_ROLE_H1 ||
     state.trial.identity.entry_policy != PIVOT_TRIAL_ENTRY_MIDPOINT_50)
    return true;

  PivotTrialOutcome outcome;
  if((!state.export_recorded &&
      !PivotV14RecordVirtualTrial(state.trial)) ||
     !BuildPivotTrialCensoredOutcome(state.trial,
                                     tick,
                                     terminal_reason,
                                     "NOT_TRIGGERED",
                                     outcome) ||
     !RecordPivotTrialOutcome(outcome))
    return false;
  return RemovePivotTrialActiveStateAt(index);
}

void FinalizePendingMidpointLanesForOrigin(const string origin_id,
                                          const SignalTypes direction,
                                          const MqlTick &tick,
                                          const string terminal_reason)
{
  if(origin_id == "" ||
     PivotTrialOriginHasActiveStructuralLane(origin_id, direction))
    return;
  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialActiveState state;
    if(!CopyPivotTrialActiveStateAt(i, state) || !state.active ||
       !state.pending_entry || state.trial.identity.origin_id != origin_id ||
       state.trial.direction != direction)
      continue;
    if(!FinalizePendingMidpointLaneAt(i, tick, terminal_reason))
      PivotV14MarkFailed("PENDING_MIDPOINT_FINALIZATION_FAILED");
  }
}

bool ActivatePendingMidpointLanesAtTick(const MqlTick &tick)
{
  if(!PivotTrialQuoteValid(tick))
    return false;

  bool complete = true;
  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialActiveState state;
    if(!CopyPivotTrialActiveStateAt(i, state) || !state.active ||
       !state.pending_entry)
      continue;
    if(!PivotTrialOriginHasActiveStructuralLane(state.trial.identity.origin_id,
                                                state.trial.direction) ||
       !PivotTrialMidpointTouched(state.trial.direction,
                                  tick.bid,
                                  state.trial.midpoint_50_price))
      continue;

    BrokerExecutionCheck facts;
    if(!LoadPivotTrialBrokerFacts(facts))
    {
      complete = false;
      continue;
    }
    double entry_price = PivotTrialEntryPriceFromTick(state.trial.direction,
                                                      tick);
    bool entry_before_boundary =
      state.trial.boundary_available &&
      ((state.trial.direction == BULLISH &&
        entry_price > state.trial.boundary_price) ||
       (state.trial.direction == BEARISH &&
        entry_price < state.trial.boundary_price));
    if(!entry_before_boundary)
    {
      if(!FinalizePendingMidpointIneligibleAt(
           i,
           state,
           tick,
           facts,
           PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY,
           "MIDPOINT_GAP_THROUGH_BOUNDARY"))
        complete = false;
      continue;
    }

    PivotTrialGeometry geometry;
    if(!BuildPivotTrialGeometryAtStop(
         state.trial.identity.origin_id,
         state.trial.direction,
         tick,
         state.trial.boundary_price,
         state.trial.identity.tp_r_multiple,
         facts.point_size,
         facts.trade_tick_size,
         facts.stops_distance_points,
         facts.freeze_distance_points,
         true,
         geometry))
    {
      if(!FinalizePendingMidpointIneligibleAt(
           i,
           state,
           tick,
           facts,
           PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY,
           "MIDPOINT_GEOMETRY_INVALID"))
        complete = false;
      continue;
    }
    if(!geometry.distance_eligible)
    {
      if(!FinalizePendingMidpointIneligibleAt(
           i,
           state,
           tick,
           facts,
           PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE,
           "MIDPOINT_DISTANCE_NOT_MET"))
        complete = false;
      continue;
    }

    PivotTrialMoneyPlan money_plan;
    if(!ResolvePivotTrialMoneyPlan(geometry, money_plan))
    {
      if(!FinalizePendingMidpointIneligibleAt(
           i,
           state,
           tick,
           facts,
           PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY,
           "MIDPOINT_MONEY_PLAN_INVALID"))
        complete = false;
      continue;
    }

    state.trial.geometry.CopyFrom(geometry);
    state.trial.money_plan.CopyFrom(money_plan);
    state.trial.entry_time = tick.time;
    state.trial.midpoint_touched = true;
    state.trial.origin_window_active_at_entry =
      state.trial.origin_expiry_time > tick.time;
    state.trial.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
    state.trial.ineligible_reason = "";
    state.pending_entry = false;
    if(!PivotV14RecordVirtualTrial(state.trial))
    {
      complete = false;
      continue;
    }
    state.export_recorded = true;
    g_pivot_trial_active_states[i].CopyFrom(state);
  }
  return complete;
}

bool DeclareInitialPivotTrialLanes(PivotSignal &signal,
                                   const MqlTick &origin_tick)
{
  if(!PivotV14Enabled())
    return true;
  if(PivotTrialResearchIntegrityFailed() || !signal.origin_registered ||
     signal.h1_lanes_declared || signal.origin_id == "" ||
     !PivotTrialQuoteValid(origin_tick))
    return false;
  if(PivotTrialActiveStateCount() + PIVOT_TRIAL_INITIAL_LANE_COUNT >
     PIVOT_TRIAL_ACTIVE_STATE_CAP)
  {
    g_pivot_trial_state_capacity_failed = true;
    PivotV14MarkFailed("H1_LANE_RESERVATION_CAP", "", 0, signal.origin_id);
    return false;
  }

  bool complete = true;
  int declared = 0;
  for(int policy_index = 0;
      policy_index < PIVOT_TRIAL_ENTRY_POLICY_COUNT;
      policy_index++)
  {
    PivotTrialEntryPolicies policy;
    if(!PivotTrialEntryPolicyAt(policy_index, policy))
      return false;
    for(int ratio_index = 0;
        ratio_index < PIVOT_TRIAL_TP_MULTIPLE_COUNT;
        ratio_index++)
    {
      int ratio = 0;
      if(!PivotTrialTpMultipleAt(ratio_index, ratio))
        return false;
      PivotTrialEntry trial;
      if(!BuildInitialPivotTrial(signal, origin_tick, policy, ratio, trial))
      {
        complete = false;
        continue;
      }
      bool pending_midpoint =
        trial.identity.entry_policy == PIVOT_TRIAL_ENTRY_MIDPOINT_50 &&
        trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED;
      if(!pending_midpoint && !PivotV14RecordVirtualTrial(trial))
      {
        complete = false;
        continue;
      }
      if(trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE &&
         !pending_midpoint)
      {
        PivotTrialOutcome ineligible_outcome;
        if(!BuildPivotTrialIneligibleOutcome(trial,
                                             origin_tick,
                                             trial.ineligible_reason == ""
                                             ? "TRIAL_INELIGIBLE"
                                             : trial.ineligible_reason,
                                             ineligible_outcome) ||
           !RecordPivotTrialOutcome(ineligible_outcome))
        {
          complete = false;
          continue;
        }
      }
      declared++;
      if(trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
         trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED)
      {
        PivotTrialActiveState state;
        BuildInitialPivotTrialActiveState(trial, state);
        string reason = "";
        if(!AppendPivotTrialActiveState(state, reason))
          return false;
      }
    }
  }
  if(complete && declared == PIVOT_TRIAL_INITIAL_LANE_COUNT)
  {
    signal.h1_lanes_declared = true;
    PivotV14MarkOriginMatrixDeclared(signal.origin_id);
    if(!ActivatePendingMidpointLanesAtTick(origin_tick))
      PivotV14MarkFailed("MIDPOINT_TOUCH_ACTIVATION_FAILED");
    FinalizePendingMidpointLanesForOrigin(signal.origin_id,
                                          signal.direction,
                                          origin_tick,
                                          "STRUCTURAL_LANES_UNAVAILABLE");
  }
  return complete && signal.h1_lanes_declared;
}

bool ResolvePivotTrialFirstTouch(const PivotTrialEntry &trial,
                                 const MqlTick &tick,
                                 PivotTrialOutcome &outcome_out)
{
  outcome_out.Reset();
  if(trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
     !trial.geometry.valid || !trial.money_plan.complete ||
     !PivotTrialQuoteValid(tick) || trial.entry_time <= 0 ||
     tick.time <= trial.entry_time)
    return false;
  double exit_price = PivotTrialExitPriceFromTick(trial.direction, tick);
  bool tp_touched = trial.direction == BULLISH
                    ? exit_price >= trial.geometry.take_profit_price
                    : exit_price <= trial.geometry.take_profit_price;
  bool sl_touched = trial.direction == BULLISH
                    ? exit_price <= trial.geometry.stop_loss_price
                    : exit_price >= trial.geometry.stop_loss_price;
  if(tp_touched == sl_touched)
    return false;
  outcome_out.outcome_id = PivotTrialOutcomeId(trial.identity.trial_id);
  outcome_out.identity.CopyFrom(trial.identity);
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time;
  outcome_out.first_touch = tp_touched
                            ? PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST
                            : PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  outcome_out.terminal_reason = tp_touched ? "TP_THRESHOLD" : "SL_THRESHOLD";
  outcome_out.threshold_price = tp_touched
                               ? trial.geometry.take_profit_price
                               : trial.geometry.stop_loss_price;
  outcome_out.observed_exit_bid = tick.bid;
  outcome_out.observed_exit_ask = tick.ask;
  outcome_out.observed_exit_price = exit_price;
  outcome_out.exit_quote_side = PivotTrialExitQuoteSide(trial.direction);
  outcome_out.gap_points = MathAbs(exit_price - outcome_out.threshold_price) /
                           trial.geometry.point_size;
  outcome_out.duration_seconds = (long)(tick.time - trial.entry_time);
  outcome_out.lifecycle_seconds_available = true;
  outcome_out.virtual_nominal_r = tp_touched
                                  ? (double)trial.identity.tp_r_multiple
                                  : -1.0;
  outcome_out.virtual_quote_gross_available =
    ResolveExecutionQuoteProfit(trial.direction,
                                trial.money_plan.normalized_volume,
                                trial.geometry.entry_price,
                                exit_price,
                                outcome_out.virtual_quote_gross_profit);
  if(outcome_out.virtual_quote_gross_available)
    outcome_out.virtual_quote_gross_r = outcome_out.virtual_quote_gross_profit /
                                        MathAbs(trial.money_plan.virtual_expected_stop_loss);
  outcome_out.virtual_binary_eligible = true;
  outcome_out.virtual_binary_target = tp_touched ? 1 : 0;
  outcome_out.virtual_exclusion_reason = "";
  outcome_out.first_touch_consistent = true;
  return true;
}

bool BuildPivotTrialCensoredOutcome(const PivotTrialEntry &trial,
                                    const MqlTick &tick,
                                    const string terminal_reason,
                                    const string exclusion_reason,
                                    PivotTrialOutcome &outcome_out)
{
  outcome_out.Reset();
  if(!PivotTrialQuoteValid(tick) || terminal_reason == "" ||
     exclusion_reason == "")
    return false;
  outcome_out.outcome_id = PivotTrialOutcomeId(trial.identity.trial_id);
  outcome_out.identity.CopyFrom(trial.identity);
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time > trial.declared_time
                              ? tick.time : trial.declared_time + 1;
  outcome_out.first_touch = trial.eligibility_status ==
                            PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED
                            ? PIVOT_TRIAL_FIRST_TOUCH_NOT_TRIGGERED
                            : PIVOT_TRIAL_FIRST_TOUCH_CENSORED;
  outcome_out.terminal_reason = terminal_reason;
  outcome_out.observed_exit_bid = tick.bid;
  outcome_out.observed_exit_ask = tick.ask;
  outcome_out.observed_exit_price = PivotTrialExitPriceFromTick(trial.direction,
                                                                 tick);
  outcome_out.exit_quote_side = PivotTrialExitQuoteSide(trial.direction);
  outcome_out.virtual_binary_eligible = false;
  outcome_out.virtual_binary_target = -1;
  outcome_out.virtual_exclusion_reason = exclusion_reason;
  outcome_out.first_touch_consistent = true;
  return true;
}

bool BuildPivotTrialRunEndOutcome(const PivotTrialEntry &trial,
                                  const MqlTick &tick,
                                  PivotTrialOutcome &outcome_out)
{
  return BuildPivotTrialCensoredOutcome(trial, tick, "RUN_END",
                                        trial.eligibility_status ==
                                        PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED
                                        ? "NOT_TRIGGERED" : "CENSORED_RUN_END",
                                        outcome_out);
}

bool BuildBrokerParityTerminalCensorOutcome(const PivotTrialEntry &trial,
                                            const MqlTick &tick,
                                            PivotTrialOutcome &outcome_out)
{
  if(trial.identity.role != PIVOT_TRIAL_ROLE_BROKER_PARITY)
    return false;
  return BuildPivotTrialCensoredOutcome(trial, tick,
                                        "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH",
                                        "BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH",
                                        outcome_out);
}

bool FinalizeBrokerParityAtBrokerTerminal(const PivotSignal &signal)
{
  if(!PivotV14Enabled() || signal.parity_trial_id == "")
    return true;
  if(!PivotV14Ready() || !signal.execution.broker_close_confirmed ||
     signal.execution.close_time <= 0)
    return false;
  int state_index = FindPivotTrialActiveStateByParityId(signal.parity_trial_id);
  if(state_index < 0)
    return PivotV14ParityHasVirtualOutcome(signal.parity_trial_id);
  PivotTrialActiveState state;
  if(!CopyPivotTrialActiveStateAt(state_index, state))
    return false;
  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick) || !PivotTrialQuoteValid(tick))
    return false;
  if(tick.time < signal.execution.close_time)
    return false;
  PivotTrialOutcome outcome;
  bool threshold = tick.time == signal.execution.close_time &&
                   ResolvePivotTrialFirstTouch(state.trial, tick, outcome);
  bool recorded = threshold
                  ? RecordPivotTrialOutcome(outcome)
                  : (BuildBrokerParityTerminalCensorOutcome(state.trial, tick,
                                                            outcome) &&
                     RecordPivotTrialOutcome(outcome));
  if(!recorded)
    return false;
  return RemovePivotTrialActiveStateAt(state_index);
}

void ProcessPivotTrialLanesTick(const MqlTick &tick)
{
  if(!PivotV14Ready() || !PivotTrialQuoteValid(tick) ||
     PivotTrialResearchIntegrityFailed())
    return;
  // Resolve entered lanes before considering midpoint touches. This makes a
  // same-tick structural exit own the boundary for still-pending midpoints.
  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialActiveState state;
    if(!CopyPivotTrialActiveStateAt(i, state) || !state.active ||
       state.pending_entry)
      continue;
    PivotTrialOutcome outcome;
    if(!ResolvePivotTrialFirstTouch(state.trial, tick, outcome))
      continue;
    if(!RecordPivotTrialOutcome(outcome))
      continue;
    RemovePivotTrialActiveStateAt(i);
  }

  // A pending midpoint is valid only while at least one structural H1 lane
  // remains active for the same origin and direction.
  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialActiveState state;
    if(!CopyPivotTrialActiveStateAt(i, state) || !state.active ||
       !state.pending_entry)
      continue;
    if(!PivotTrialOriginHasActiveStructuralLane(
         state.trial.identity.origin_id,
         state.trial.direction) &&
       !FinalizePendingMidpointLaneAt(i,
                                      tick,
                                      "STRUCTURAL_LANES_EXITED"))
      PivotV14MarkFailed("PENDING_MIDPOINT_FINALIZATION_FAILED");
  }

  // Touches create a new lane entry clock; the touch tick cannot also resolve
  // its TP/SL because first-touch observation requires a later quote.
  if(!ActivatePendingMidpointLanesAtTick(tick))
    PivotV14MarkFailed("MIDPOINT_TOUCH_ACTIVATION_FAILED");
}

void FinalizePivotTrialLanesForExport()
{
  if(!PivotV14Enabled() || !PivotTrialLanesHaveOutstandingState())
    return;
  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick) || !PivotTrialQuoteValid(tick))
    return;
  if(tick.time <= 0)
    tick.time = TimeCurrent();
  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    if(!g_pivot_trial_active_states[i].export_recorded &&
       !PivotV14RecordVirtualTrial(g_pivot_trial_active_states[i].trial))
    {
      PivotV14MarkFailed("PENDING_TRIAL_RECORD_FAILED");
      continue;
    }
    PivotTrialOutcome outcome;
    if(BuildPivotTrialRunEndOutcome(g_pivot_trial_active_states[i].trial,
                                    tick, outcome))
      RecordPivotTrialOutcome(outcome);
    RemovePivotTrialActiveStateAt(i);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_
