//+------------------------------------------------------------------+
//|              trading_signals/pivot_trial_matrix_lifecycle      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_

string PivotTrialPolicyId(const string origin_id,
                          const PivotTrialSlPolicies sl_policy,
                          const int tp_r_multiple)
{
  string payload = origin_id + "|" + PivotTrialSlPolicyLabel(sl_policy) +
                   "|" + IntegerToString(tp_r_multiple);
  return "policy_" +
         StringFormat("%I64u", PivotTrialStableHash(payload));
}

string PivotTrialId(const string policy_id,
                    const int reentry_index)
{
  string payload = policy_id + "|" + IntegerToString(reentry_index);
  return "trial_" + StringFormat("%I64u", PivotTrialStableHash(payload));
}

string PivotTrialOutcomeId(const string trial_id)
{
  return "outcome_" +
         StringFormat("%I64u",
                      PivotTrialStableHash(trial_id + "|TERMINAL"));
}

void PrimePivotTrialQuoteFacts(const SignalTypes direction,
                               const MqlTick &tick,
                               const BrokerExecutionCheck &broker_check,
                               const bool boundary_available,
                               const double boundary_price,
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
  geometry.boundary_available = boundary_available;
  geometry.boundary_price = boundary_price;
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

bool BuildInitialPivotTrial(const PivotSignal &signal,
                            const MqlTick &origin_tick,
                            const PivotTrialSlPolicies sl_policy,
                            const int tp_r_multiple,
                            PivotTrialEntry &trial_out)
{
  trial_out.Reset();
  trial_out.identity.origin_id = signal.origin_id;
  trial_out.identity.window_id = signal.window_id;
  trial_out.identity.policy_id =
    PivotTrialPolicyId(signal.origin_id, sl_policy, tp_r_multiple);
  trial_out.identity.trial_id =
    PivotTrialId(trial_out.identity.policy_id, 0);
  trial_out.identity.role = PIVOT_TRIAL_ROLE_MATRIX;
  trial_out.identity.sl_policy = sl_policy;
  trial_out.identity.tp_r_multiple = tp_r_multiple;
  trial_out.identity.reentry_index = 0;
  trial_out.level_id = signal.level_id;
  trial_out.direction = signal.direction;
  trial_out.declared_time = signal.trigger_time;
  trial_out.preceding_loss_count = 0;
  trial_out.origin_micro_band_width_available =
    signal.features.micro_complete &&
    signal.features.micro_band_width_0 > 0.0;
  trial_out.origin_micro_band_width_0 =
    trial_out.origin_micro_band_width_available
    ? signal.features.micro_band_width_0
    : 0.0;
  int origin_level_index = (int)signal.level_id;
  if(origin_level_index >= 0 && origin_level_index < PIVOT_LEVEL_COUNT)
  {
    trial_out.origin_pivot_price =
      signal.levels.trade_prices[origin_level_index];
  }
  trial_out.entry_features.CopyFrom(signal.features);
  trial_out.origin_window_active_at_entry = true;

  bool boundary_available = false;
  double boundary_price = 0.0;
  if(!PivotTrialNextOutwardBoundary(signal.direction,
                                    signal.level_id,
                                    signal.levels,
                                    boundary_available,
                                    boundary_price))
  {
    trial_out.ineligible_reason = "NEXT_PIVOT_BOUNDARY_INVALID";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }

  PrimePivotTrialQuoteFacts(signal.direction,
                            origin_tick,
                            signal.execution.observation_check,
                            boundary_available,
                            boundary_price,
                            trial_out.geometry);

  if(sl_policy != PIVOT_TRIAL_SL_STRUCTURAL &&
     !trial_out.origin_micro_band_width_available)
  {
    trial_out.ineligible_reason = "ORIGIN_MICRO_BAND_WIDTH_UNAVAILABLE";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_FEATURE;
    return true;
  }

  double requested_risk_distance = 0.0;
  if(!PivotTrialRequestedRiskDistance(
       sl_policy,
       PivotTrialEntryPriceFromTick(signal.direction, origin_tick),
       signal.route.structural_stop_loss,
       trial_out.origin_micro_band_width_available,
       trial_out.origin_micro_band_width_0,
       requested_risk_distance) ||
     !BuildPivotTrialGeometry(signal.origin_id,
                              signal.direction,
                              origin_tick,
                              requested_risk_distance,
                              tp_r_multiple,
                              signal.execution.observation_check.point_size,
                              signal.execution.observation_check.trade_tick_size,
                              signal.execution.observation_check.stops_distance_points,
                              signal.execution.observation_check.freeze_distance_points,
                              boundary_available,
                              boundary_price,
                              0,
                              trial_out.geometry))
  {
    trial_out.ineligible_reason = trial_out.geometry.invalid_reason == ""
                                  ? "TRIAL_GEOMETRY_UNAVAILABLE"
                                  : trial_out.geometry.invalid_reason;
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }

  if(!trial_out.geometry.distance_eligible)
  {
    trial_out.ineligible_reason = "MINIMUM_RISK_DISTANCE_NOT_MET";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE;
    return true;
  }

  if(!ResolvePivotTrialMoneyPlan(trial_out.geometry,
                                 trial_out.money_plan))
  {
    trial_out.ineligible_reason = trial_out.money_plan.invalid_reason == ""
                                  ? "VIRTUAL_MONEY_PLAN_UNAVAILABLE"
                                  : trial_out.money_plan.invalid_reason;
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY;
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
  state_out.chain.origin_id = trial.identity.origin_id;
  state_out.chain.policy_id = trial.identity.policy_id;
  state_out.chain.current_trial_id = trial.identity.trial_id;
  state_out.chain.sl_policy = trial.identity.sl_policy;
  state_out.chain.tp_r_multiple = trial.identity.tp_r_multiple;
  state_out.chain.current_reentry_index = 0;
  state_out.chain.preceding_loss_count = 0;
  state_out.chain.last_generation_time = trial.declared_time;
  state_out.chain.active = true;
  state_out.active = true;
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
  return facts_out.point_size > 0.0 &&
         facts_out.trade_tick_size > 0.0 &&
         facts_out.stops_distance_points >= 0.0 &&
         facts_out.freeze_distance_points >= 0.0;
}

void CapturePivotTrialRetryFeatures(const PivotTrialEntry &previous_trial,
                                    const PivotContextFeatureSnapshot &shared_features,
                                    PivotContextFeatureSnapshot &features_out)
{
  BuildPivotSignalFeatureSnapshot(shared_features,
                                  previous_trial.origin_pivot_price,
                                  features_out);
}

bool BuildPivotTrialReentry(const PivotTrialActiveState &previous_state,
                            const MqlTick &tick,
                            const int reentry_index,
                            const PivotContextFeatureSnapshot &shared_features,
                            PivotTrialEntry &trial_out)
{
  PivotTrialEntry previous(previous_state.trial);
  trial_out.Reset();
  if(previous.identity.role != PIVOT_TRIAL_ROLE_MATRIX ||
     !PivotTrialSlPolicyAllowsReentry(previous.identity.sl_policy) ||
     reentry_index != previous.identity.reentry_index + 1 ||
     reentry_index <= 0 ||
     reentry_index > PIVOT_TRIAL_MAX_REENTRY_INDEX)
    return false;

  trial_out.identity.origin_id = previous.identity.origin_id;
  trial_out.identity.window_id = previous.identity.window_id;
  trial_out.identity.policy_id = previous.identity.policy_id;
  trial_out.identity.trial_id =
    PivotTrialId(previous.identity.policy_id, reentry_index);
  trial_out.identity.role = PIVOT_TRIAL_ROLE_MATRIX;
  trial_out.identity.sl_policy = previous.identity.sl_policy;
  trial_out.identity.tp_r_multiple = previous.identity.tp_r_multiple;
  trial_out.identity.reentry_index = reentry_index;
  trial_out.level_id = previous.level_id;
  trial_out.direction = previous.direction;
  trial_out.declared_time = tick.time;
  trial_out.preceding_loss_count = reentry_index;
  trial_out.origin_micro_band_width_available =
    previous.origin_micro_band_width_available;
  trial_out.origin_micro_band_width_0 =
    previous.origin_micro_band_width_0;
  trial_out.origin_pivot_price = previous.origin_pivot_price;
  trial_out.parent_trial_id = previous.identity.trial_id;
  trial_out.continuation_source_outcome_id =
    PivotTrialOutcomeId(previous.identity.trial_id);
  trial_out.origin_window_active_at_entry = true;
  CapturePivotTrialRetryFeatures(previous,
                                 shared_features,
                                 trial_out.entry_features);

  BrokerExecutionCheck broker_facts;
  bool broker_facts_complete = LoadPivotTrialBrokerFacts(broker_facts);
  if(!broker_facts_complete)
  {
    broker_facts.point_size = previous.geometry.point_size;
    broker_facts.trade_tick_size = previous.geometry.trade_tick_size;
    broker_facts.stops_distance_points =
      previous.geometry.stops_level_points;
    broker_facts.freeze_distance_points =
      previous.geometry.freeze_level_points;
  }
  PrimePivotTrialQuoteFacts(previous.direction,
                            tick,
                            broker_facts,
                            previous.geometry.boundary_available,
                            previous.geometry.boundary_price,
                            trial_out.geometry);
  if(!broker_facts_complete)
  {
    trial_out.ineligible_reason = "REENTRY_BROKER_FACTS_UNAVAILABLE";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  double contract_tolerance =
    MathMin(previous.geometry.point_size,
            previous.geometry.trade_tick_size) * 1e-7;
  if(MathAbs(broker_facts.point_size - previous.geometry.point_size) >
       contract_tolerance ||
     MathAbs(broker_facts.trade_tick_size -
             previous.geometry.trade_tick_size) > contract_tolerance)
  {
    trial_out.ineligible_reason = "REENTRY_PRICE_CONTRACT_CHANGED";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  if(!trial_out.origin_micro_band_width_available ||
     trial_out.origin_micro_band_width_0 <= 0.0)
  {
    trial_out.ineligible_reason = "ORIGIN_MICRO_BAND_WIDTH_UNAVAILABLE";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_FEATURE;
    return true;
  }

  double requested_risk_distance = 0.0;
  if(!PivotTrialRequestedRiskDistance(
       previous.identity.sl_policy,
       0.0,
       0.0,
       true,
       trial_out.origin_micro_band_width_0,
       requested_risk_distance) ||
     !BuildPivotTrialGeometry(previous.identity.origin_id,
                              previous.direction,
                              tick,
                              requested_risk_distance,
                              previous.identity.tp_r_multiple,
                              broker_facts.point_size,
                              broker_facts.trade_tick_size,
                              broker_facts.stops_distance_points,
                              broker_facts.freeze_distance_points,
                              previous.geometry.boundary_available,
                              previous.geometry.boundary_price,
                              reentry_index,
                              trial_out.geometry))
  {
    trial_out.ineligible_reason = trial_out.geometry.invalid_reason == ""
                                  ? "REENTRY_GEOMETRY_UNAVAILABLE"
                                  : trial_out.geometry.invalid_reason;
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  if(!trial_out.geometry.distance_eligible)
  {
    trial_out.ineligible_reason = "MINIMUM_RISK_DISTANCE_NOT_MET";
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE;
    return true;
  }
  if(!ResolvePivotTrialMoneyPlan(trial_out.geometry,
                                 trial_out.money_plan))
  {
    trial_out.ineligible_reason = trial_out.money_plan.invalid_reason == ""
                                  ? "VIRTUAL_MONEY_PLAN_UNAVAILABLE"
                                  : trial_out.money_plan.invalid_reason;
    trial_out.eligibility_status =
      PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY;
    return true;
  }

  trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  trial_out.ineligible_reason = "";
  return true;
}

bool PivotTrialOriginWindowActive(const PivotTrialEntry &trial)
{
  if(trial.identity.window_id == "" ||
     g_pivot_fractal_window.active_bar_open <= 0)
    return false;
  string current_window_id =
    PivotV11WindowId(_Symbol,
                     Macro_Timeframe,
                     g_pivot_fractal_window.active_bar_open);
  return current_window_id == trial.identity.window_id;
}

bool PivotTrialReentryBoundaryEligible(const PivotTrialEntry &trial,
                                       const MqlTick &tick,
                                       const int next_reentry_index)
{
  double proposed_entry =
    PivotTrialEntryPriceFromTick(trial.direction, tick);
  double proposed_stop = trial.direction == BULLISH
                         ? proposed_entry -
                           trial.geometry.normalized_risk_distance_price
                         : proposed_entry +
                           trial.geometry.normalized_risk_distance_price;
  return PivotTrialBoundaryEligible(
           trial.direction,
           next_reentry_index,
           trial.geometry.boundary_available,
           trial.geometry.boundary_price,
           proposed_entry,
           proposed_stop,
           trial.geometry.trade_tick_size);
}

void SetPivotTrialTerminalChain(PivotTrialOutcome &outcome,
                                const PivotTrialChainTerminalReasons reason)
{
  outcome.chain_terminal = true;
  outcome.chain_terminal_reason = reason;
  outcome.continuation_allowed = false;
  outcome.continuation_reason = "";
  outcome.next_reentry_index = -1;
  outcome.next_trial_id = "";
}

bool ConfigurePivotTrialContinuation(
  const PivotTrialActiveState &previous_state,
  const MqlTick &tick,
  PivotTrialOutcome &outcome,
  bool &retry_features_captured,
  PivotContextFeatureSnapshot &shared_retry_features,
  bool &next_trial_declared_out,
  PivotTrialEntry &next_trial_out)
{
  next_trial_declared_out = false;
  next_trial_out.Reset();
  PivotTrialEntry previous(previous_state.trial);
  if(outcome.first_touch != PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST ||
     !PivotTrialSlPolicyAllowsReentry(previous.identity.sl_policy))
    return true;

  int next_reentry_index = previous.identity.reentry_index + 1;
  if(!PivotTrialOriginWindowActive(previous))
  {
    SetPivotTrialTerminalChain(outcome,
                               PIVOT_TRIAL_CHAIN_ORIGIN_EXPIRED);
    return true;
  }
  if(!PivotTrialReentryBoundaryEligible(previous,
                                        tick,
                                        next_reentry_index))
  {
    SetPivotTrialTerminalChain(
      outcome,
      PIVOT_TRIAL_CHAIN_NEXT_PIVOT_BOUNDARY);
    return true;
  }
  if(previous.identity.reentry_index >= PIVOT_TRIAL_MAX_REENTRY_INDEX)
  {
    SetPivotTrialTerminalChain(
      outcome,
      PIVOT_TRIAL_CHAIN_REENTRY_CAP_REACHED);
    return true;
  }
  if(!retry_features_captured)
  {
    CapturePivotContextFeatureSnapshot(tick.bid,
                                       tick.time,
                                       shared_retry_features);
    retry_features_captured = true;
  }
  if(!BuildPivotTrialReentry(previous_state,
                             tick,
                             next_reentry_index,
                             shared_retry_features,
                             next_trial_out))
    return false;

  outcome.chain_terminal = false;
  outcome.chain_terminal_reason = PIVOT_TRIAL_CHAIN_NOT_TERMINAL;
  outcome.continuation_allowed = true;
  outcome.continuation_reason = "REENTRY_ALLOWED";
  outcome.next_reentry_index = next_reentry_index;
  outcome.next_trial_id = next_trial_out.identity.trial_id;
  next_trial_declared_out = true;
  return true;
}

void BuildPivotTrialReentryActiveState(
  const PivotTrialActiveState &previous_state,
  const PivotTrialOutcome &previous_outcome,
  const PivotTrialEntry &next_trial,
  PivotTrialActiveState &state_out)
{
  state_out.Reset();
  state_out.trial.CopyFrom(next_trial);
  state_out.chain.CopyFrom(previous_state.chain);
  state_out.chain.current_trial_id = next_trial.identity.trial_id;
  state_out.chain.last_outcome_id = previous_outcome.outcome_id;
  state_out.chain.current_reentry_index =
    next_trial.identity.reentry_index;
  state_out.chain.preceding_loss_count =
    next_trial.preceding_loss_count;
  state_out.chain.last_generation_time = next_trial.declared_time;
  state_out.chain.closed_nominal_r += previous_outcome.virtual_nominal_r;
  state_out.chain.closed_virtual_gross_r +=
    previous_outcome.virtual_quote_gross_r;
  state_out.chain.active = true;
  state_out.chain.terminal = false;
  state_out.chain.terminal_reason = PIVOT_TRIAL_CHAIN_NOT_TERMINAL;
  state_out.active = true;
}

bool DeclareInitialPivotTrialMatrix(PivotSignal &signal,
                                    const MqlTick &origin_tick)
{
  if(!PivotV11Enabled())
    return true;
  if(PivotTrialResearchIntegrityFailed())
    return false;
  if(!signal.origin_registered || signal.matrix_declared ||
     signal.origin_id == "" || !PivotTrialQuoteValid(origin_tick))
    return false;

  bool rows_complete = true;
  int declaration_count = 0;
  for(int policy_index = 0;
      policy_index < PIVOT_TRIAL_SL_POLICY_COUNT;
      policy_index++)
  {
    PivotTrialSlPolicies sl_policy;
    if(!PivotTrialSlPolicyAt(policy_index, sl_policy))
      return false;
    for(int tp_index = 0;
        tp_index < PIVOT_TRIAL_TP_MULTIPLE_COUNT;
        tp_index++)
    {
      int tp_r_multiple = 0;
      if(!PivotTrialTpMultipleAt(tp_index, tp_r_multiple))
        return false;

      PivotTrialEntry trial;
      if(!BuildInitialPivotTrial(signal,
                                 origin_tick,
                                 sl_policy,
                                 tp_r_multiple,
                                 trial) ||
         !PivotV11RecordVirtualTrial(trial))
      {
        rows_complete = false;
        continue;
      }
      declaration_count++;

      if(trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
      {
        PivotTrialActiveState state;
        BuildInitialPivotTrialActiveState(trial, state);
        string state_reason = "";
        if(!AppendPivotTrialActiveState(state, state_reason))
          return false;
      }
    }
  }

  if(rows_complete && declaration_count == PIVOT_TRIAL_INITIAL_MATRIX_SIZE)
  {
    signal.matrix_declared = true;
    PivotV11MarkOriginMatrixDeclared(signal.origin_id);
  }
  return rows_complete && signal.matrix_declared;
}

bool ResolvePivotTrialFirstTouch(const PivotTrialEntry &trial,
                                 const MqlTick &tick,
                                 PivotTrialOutcome &outcome_out)
{
  outcome_out.Reset();
  if(trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
     !trial.geometry.valid || !trial.money_plan.complete ||
     !PivotTrialQuoteValid(tick) || tick.time <= trial.declared_time)
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

  outcome_out.outcome_id =
    PivotTrialOutcomeId(trial.identity.trial_id);
  outcome_out.identity.CopyFrom(trial.identity);
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time;
  outcome_out.first_touch = tp_touched
                            ? PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST
                            : PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  outcome_out.terminal_reason = tp_touched
                                ? "TP_THRESHOLD"
                                : "SL_THRESHOLD";
  outcome_out.threshold_price = tp_touched
                                ? trial.geometry.take_profit_price
                                : trial.geometry.stop_loss_price;
  outcome_out.observed_exit_bid = tick.bid;
  outcome_out.observed_exit_ask = tick.ask;
  outcome_out.observed_exit_price = exit_price;
  outcome_out.exit_quote_side = PivotTrialExitQuoteSide(trial.direction);
  outcome_out.gap_points =
    MathAbs(exit_price - outcome_out.threshold_price) /
    trial.geometry.point_size;
  outcome_out.duration_seconds =
    (long)(outcome_out.terminal_time - trial.declared_time);
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
  {
    outcome_out.virtual_quote_gross_r =
      outcome_out.virtual_quote_gross_profit /
      MathAbs(trial.money_plan.virtual_expected_stop_loss);
  }
  outcome_out.virtual_binary_eligible = trial.entry_features.complete;
  outcome_out.virtual_binary_target =
    outcome_out.virtual_binary_eligible ? (tp_touched ? 1 : 0) : -1;
  outcome_out.virtual_exclusion_reason =
    outcome_out.virtual_binary_eligible
    ? ""
    : "ENTRY_FEATURE_SNAPSHOT_INCOMPLETE";
  outcome_out.first_touch_consistent = true;
  if(tp_touched)
  {
    SetPivotTrialTerminalChain(outcome_out,
                               PIVOT_TRIAL_CHAIN_TP_REACHED);
  }
  else if(trial.identity.sl_policy == PIVOT_TRIAL_SL_STRUCTURAL)
  {
    SetPivotTrialTerminalChain(outcome_out,
                               PIVOT_TRIAL_CHAIN_STRUCTURAL_SL);
  }
  return true;
}

bool BuildPivotTrialRunEndOutcome(const PivotTrialEntry &trial,
                                  const MqlTick &tick,
                                  PivotTrialOutcome &outcome_out)
{
  outcome_out.Reset();
  if(trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
     !PivotTrialQuoteValid(tick))
    return false;

  outcome_out.outcome_id =
    PivotTrialOutcomeId(trial.identity.trial_id);
  outcome_out.identity.CopyFrom(trial.identity);
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time;
  if(outcome_out.terminal_time <= trial.declared_time)
    outcome_out.terminal_time = trial.declared_time + 1;
  outcome_out.first_touch = PIVOT_TRIAL_FIRST_TOUCH_CENSORED;
  outcome_out.terminal_reason = "RUN_END";
  outcome_out.observed_exit_bid = tick.bid;
  outcome_out.observed_exit_ask = tick.ask;
  outcome_out.observed_exit_price =
    PivotTrialExitPriceFromTick(trial.direction, tick);
  outcome_out.exit_quote_side = PivotTrialExitQuoteSide(trial.direction);
  outcome_out.duration_seconds =
    (long)(outcome_out.terminal_time - trial.declared_time);
  outcome_out.virtual_binary_eligible = false;
  outcome_out.virtual_binary_target = -1;
  outcome_out.virtual_exclusion_reason = "CENSORED_RUN_END";
  outcome_out.first_touch_consistent = true;
  outcome_out.chain_terminal = true;
  outcome_out.chain_terminal_reason =
    PIVOT_TRIAL_CHAIN_RUN_END_CENSORED;
  return true;
}

void ProcessPivotTrialMatrixTick(const MqlTick &tick)
{
  if(!PivotV11Enabled() || !PivotTrialQuoteValid(tick))
    return;
  if(PivotTrialResearchIntegrityFailed())
    return;

  bool retry_features_captured = false;
  PivotContextFeatureSnapshot shared_retry_features;

  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialActiveState previous_state;
    previous_state.CopyFrom(g_pivot_trial_active_states[i]);
    PivotTrialOutcome outcome;
    if(!ResolvePivotTrialFirstTouch(previous_state.trial,
                                    tick,
                                    outcome))
      continue;

    bool next_trial_declared = false;
    PivotTrialEntry next_trial;
    if(!ConfigurePivotTrialContinuation(previous_state,
                                        tick,
                                        outcome,
                                        retry_features_captured,
                                        shared_retry_features,
                                        next_trial_declared,
                                        next_trial))
    {
      PivotV11MarkFailed("VIRTUAL_REENTRY_TRANSITION_FAILED");
    }

    bool outcome_recorded = PivotV11RecordVirtualOutcome(outcome);
    RemovePivotTrialActiveStateAt(i);
    if(!outcome_recorded || !next_trial_declared)
      continue;

    if(!PivotV11RecordVirtualTrial(next_trial))
      continue;
    if(next_trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
    {
      PivotTrialActiveState next_state;
      BuildPivotTrialReentryActiveState(previous_state,
                                        outcome,
                                        next_trial,
                                        next_state);
      string state_reason = "";
      AppendPivotTrialActiveState(next_state, state_reason);
    }
  }
}

void FinalizePivotTrialMatrixForExport()
{
  if(!PivotV11Enabled() || !PivotTrialMatrixHasOutstandingState())
    return;

  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick) || !PivotTrialQuoteValid(tick))
  {
    PivotV11MarkFailed("VIRTUAL_CENSOR_QUOTE_UNAVAILABLE");
    return;
  }
  if(tick.time <= 0)
    tick.time = TimeCurrent();

  for(int i = PivotTrialActiveStateCount() - 1; i >= 0; i--)
  {
    PivotTrialOutcome outcome;
    if(BuildPivotTrialRunEndOutcome(g_pivot_trial_active_states[i].trial,
                                    tick,
                                    outcome))
      PivotV11RecordVirtualOutcome(outcome);
    RemovePivotTrialActiveStateAt(i);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_LIFECYCLE_MQH_
