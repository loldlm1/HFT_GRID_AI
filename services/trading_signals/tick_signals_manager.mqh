
//+------------------------------------------------------------------+
//|                                      tick_signals_manager.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_

void RegisterClosedSignalOutcomeIfBrokerConfirmed(SignalParams &signal_params,
                                                  const SignalTypes direction)
{
  bool broker_outcome = SignalHasBrokerConfirmedOutcome(signal_params);
  signal_params.raw_profit = signal_params.realized_profit;

  if(!broker_outcome && signal_params.deterministic_strategy)
  {
    signal_params.raw_profit = 0.0;
    ExecutionLogDeterministicPendingCanceled(signal_params, "no_broker_outcome");
    return;
  }

  if(MathAbs(signal_params.raw_profit) < 0.0000001 &&
     signal_params.realized_closed_volume <= 0.0)
  {
    signal_params.raw_profit = RawProfitUsd(direction,
                                           signal_params.entry_price,
                                           signal_params.close_price);
  }

  RegisterDailySignalOutcome(direction, signal_params.raw_profit);
  RegisterSignalLotSequenceOutcome(signal_params.raw_profit);
  DeterministicSignalStatsRecordOutcome(signal_params);
  DeterministicSignalMLShadowRecordOutcome(signal_params);
}

void CleanupClosedBullishSignals()
{
  int running_signals_total = ArraySize(running_bullish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    bool lifecycle_closed = (running_bullish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bullish_signals[i]))
    {
      running_bullish_signals[i].close_time  = TimeCurrent();
      running_bullish_signals[i].close_price = g_bid;
      running_bullish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bullish_signals[i],
                                                   BULLISH);
      CloseBullishSignal(running_bullish_signals[i]);
      RemoveElementFromArray(running_bullish_signals, i);
    }
  }
}

void CleanupClosedBearishSignals()
{
  int running_signals_total = ArraySize(running_bearish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    bool lifecycle_closed = (running_bearish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bearish_signals[i]))
    {
      running_bearish_signals[i].close_time  = TimeCurrent();
      running_bearish_signals[i].close_price = g_ask;
      running_bearish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bearish_signals[i],
                                                   BEARISH);
      CloseBearishSignal(running_bearish_signals[i]);
      RemoveElementFromArray(running_bearish_signals, i);
    }
  }
}

bool MLArbitrationSignalCandidateStillValid(SignalParams &signal_params,
                                            const MLArbitrationCandidate &candidate)
{
  if(!candidate.valid)
    return false;
  if(signal_params.signal_state == CLOSED)
    return false;
  if(!signal_params.deterministic_strategy)
    return false;
  if(signal_params.strategy_id != candidate.strategy_id)
    return false;
  if(signal_params.deterministic_source_attempt_index != candidate.source_attempt_index)
    return false;
  if(MLArbitrationResolveSignalId(signal_params) != candidate.signal_id)
    return false;
  if(!MLArbitrationSourceIdentityMatches(candidate,
                                         signal_params,
                                         candidate.activation_time))
    return false;
  if(candidate.leg_index < 0 ||
     candidate.leg_index >= ArraySize(signal_params.execution_legs))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[candidate.leg_index];
  if(leg_state.status != EXECUTION_LEG_PENDING)
    return false;
  if(leg_state.position_ticket > 0 || leg_state.entry_price > 0.0)
    return false;

  return (signal_params.ml_shadow_evaluated &&
          signal_params.ml_shadow_available &&
          signal_params.ml_shadow_feature_valid &&
          signal_params.ml_shadow_classifier_scored &&
          signal_params.ml_shadow_recommendation == "ALLOW");
}

bool MLArbitrationCandidateStillValid(const MLArbitrationCandidate &candidate)
{
  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BULLISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bullish_signals))
      return false;
    return MLArbitrationSignalCandidateStillValid(running_bullish_signals[candidate.signal_index],
                                                 candidate);
  }

  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BEARISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bearish_signals))
      return false;
    return MLArbitrationSignalCandidateStillValid(running_bearish_signals[candidate.signal_index],
                                                 candidate);
  }

  return false;
}

bool ApplyMLArbitrationSelectedSignal(SignalParams &signal_params,
                                      MLArbitrationCandidate &candidate)
{
  if(!MLArbitrationSignalCandidateStillValid(signal_params, candidate))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[candidate.leg_index];
  double requested_lot = leg_state.lot_size;
  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, requested_lot);
  double point_size = ExecutionResolvePointSize();
  ExecutionLegTradeAdmissionContext admission_context;
  if(!PrepareExecutionLegTradeAdmission(signal_params,
                                        leg_state,
                                        point_size,
                                        normalized_volume,
                                        admission_context))
    return false;

  return ApplyDeterministicPreparedEntryAdmission(signal_params,
                                                 candidate.leg_index,
                                                 leg_state,
                                                 admission_context);
}

bool ApplyMLArbitrationSelectedCandidate(MLArbitrationCandidate &candidate)
{
  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BULLISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bullish_signals))
      return false;
    return ApplyMLArbitrationSelectedSignal(running_bullish_signals[candidate.signal_index],
                                            candidate);
  }

  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BEARISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bearish_signals))
      return false;
    return ApplyMLArbitrationSelectedSignal(running_bearish_signals[candidate.signal_index],
                                            candidate);
  }

  return false;
}

bool BlockMLArbitrationSignal(SignalParams &signal_params,
                              const MLArbitrationCandidate &candidate,
                              const string selected_signal_id)
{
  if(!MLArbitrationSignalCandidateStillValid(signal_params, candidate))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[candidate.leg_index];
  leg_state.status = EXECUTION_LEG_COMPLETED;
  leg_state.last_action_time = TimeCurrent();
  signal_params.execution_legs[candidate.leg_index] = leg_state;
  signal_params.signal_state = CLOSED;
  signal_params.deterministic_stats_terminal_reason = "ML_ARBITRATION_BLOCKED";

  ExecutionLogGuardrailBlock("ML_ARBITRATION_BLOCKED",
                             signal_params,
                             leg_state,
                             StringFormat("group=%s|selected_signal_id=%s",
                                          candidate.group_id,
                                          selected_signal_id));
  return true;
}

bool BlockMLArbitrationCandidate(const MLArbitrationCandidate &candidate,
                                 const string selected_signal_id)
{
  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BULLISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bullish_signals))
      return false;
    return BlockMLArbitrationSignal(running_bullish_signals[candidate.signal_index],
                                    candidate,
                                    selected_signal_id);
  }

  if(candidate.direction_array == ML_ARBITRATION_ARRAY_BEARISH)
  {
    if(candidate.signal_index < 0 ||
       candidate.signal_index >= ArraySize(running_bearish_signals))
      return false;
    return BlockMLArbitrationSignal(running_bearish_signals[candidate.signal_index],
                                    candidate,
                                    selected_signal_id);
  }

  return false;
}

void MLArbitrationBuildRankedGroupIndices(MLArbitrationCandidate &candidates[],
                                          int &group_indices[],
                                          int &ranked_indices[])
{
  int group_total = ArraySize(group_indices);
  ArrayResize(ranked_indices, group_total);
  for(int i = 0; i < group_total; i++)
    ranked_indices[i] = group_indices[i];

  for(int i = 0; i < group_total - 1; i++)
  {
    for(int j = 0; j < group_total - i - 1; j++)
    {
      int left_index = ranked_indices[j];
      int right_index = ranked_indices[j + 1];
      if(left_index < 0 || left_index >= ArraySize(candidates) ||
         right_index < 0 || right_index >= ArraySize(candidates))
        continue;

      string rank_reason = "";
      if(MLArbitrationCompareCandidates(candidates[right_index],
                                        candidates[left_index],
                                        rank_reason) > 0)
      {
        int tmp = ranked_indices[j];
        ranked_indices[j] = ranked_indices[j + 1];
        ranked_indices[j + 1] = tmp;
      }
    }
  }
}

string MLArbitrationResolveGroupRankReason(MLArbitrationCandidate &candidates[],
                                           int &ranked_indices[])
{
  int group_total = ArraySize(ranked_indices);
  if(group_total <= 1)
    return ML_ARBITRATION_REASON_SINGLE;

  int best_index = ranked_indices[0];
  int second_index = ranked_indices[1];
  if(best_index < 0 || best_index >= ArraySize(candidates) ||
     second_index < 0 || second_index >= ArraySize(candidates))
    return ML_ARBITRATION_REASON_FALLBACK;

  string rank_reason = "";
  MLArbitrationCompareCandidates(candidates[best_index],
                                 candidates[second_index],
                                 rank_reason);
  if(rank_reason == "")
    return ML_ARBITRATION_REASON_FALLBACK;
  return rank_reason;
}

void ProcessMLArbitrationGroup(MLArbitrationCandidate &candidates[],
                               int &group_indices[])
{
  int group_total = ArraySize(group_indices);
  if(group_total <= 0)
    return;

  int ranked_indices[];
  MLArbitrationBuildRankedGroupIndices(candidates,
                                       group_indices,
                                       ranked_indices);
  string rank_reason = MLArbitrationResolveGroupRankReason(candidates,
                                                           ranked_indices);
  MLArbitrationRegisterGroupCounters(group_total,
                                     rank_reason);

  int selected_index = -1;
  int selected_rank_position = 0;
  string selected_signal_id = "";
  for(int i = 0; i < group_total; i++)
  {
    int candidate_index = ranked_indices[i];
    if(!MLArbitrationCandidateStillValid(candidates[candidate_index]))
    {
      ExecutionAppendQueryDebugLog("ML_ARBITRATION_INVALID",
                                   MLArbitrationCandidateDebugToken(candidates[candidate_index]));
      continue;
    }

    selected_index = candidate_index;
    selected_rank_position = i + 1;
    selected_signal_id = candidates[selected_index].signal_id;
    bool selected_applied = ApplyMLArbitrationSelectedCandidate(candidates[selected_index]);
    string selected_reason = selected_applied ? rank_reason : ML_ARBITRATION_REASON_SELECTED_APPLY_FAILED;
    MLArbitrationRecordDecision(candidates[selected_index],
                                selected_signal_id,
                                selected_rank_position,
                                rank_reason,
                                ML_ARBITRATION_ACTION_SELECTED,
                                selected_reason);

    if(!selected_applied)
    {
      ExecutionAppendQueryDebugLog("ML_ARBITRATION_SELECTED_APPLY_FAILED",
                                   MLArbitrationCandidateDebugToken(candidates[selected_index]));
    }
    break;
  }

  if(selected_index < 0)
    return;

  for(int i = 0; i < group_total; i++)
  {
    int candidate_index = ranked_indices[i];
    if(candidate_index == selected_index)
      continue;
    if(candidate_index < 0 || candidate_index >= ArraySize(candidates))
      continue;

    if(BlockMLArbitrationCandidate(candidates[candidate_index],
                                   selected_signal_id))
    {
      MLArbitrationRecordDecision(candidates[candidate_index],
                                  selected_signal_id,
                                  i + 1,
                                  rank_reason,
                                  ML_ARBITRATION_ACTION_BLOCKED,
                                  rank_reason);
    }
  }
}

void ProcessMLArbitrationCandidates(MLArbitrationCandidate &candidates[])
{
  int total = ArraySize(candidates);
  if(total <= 0)
    return;

  bool processed[];
  ArrayResize(processed, total);
  for(int i = 0; i < total; i++)
    processed[i] = false;

  for(int i = 0; i < total; i++)
  {
    if(processed[i] || !candidates[i].valid)
      continue;

    int group_indices[];
    for(int j = i; j < total; j++)
    {
      if(processed[j] || !MLArbitrationSameGroup(candidates[i], candidates[j]))
        continue;
      AddElementToArray(group_indices, j);
      processed[j] = true;
    }

    ProcessMLArbitrationGroup(candidates, group_indices);
  }
}

void CheckTickOpenSignalsWithMLArbitration()
{
  MLArbitrationCandidate candidates[];
  datetime activation_time = TimeCurrent();

  int bullish_total = ArraySize(running_bullish_signals);
  for(int i = bullish_total-1; i >= 0; i--)
  {
    MLArbitrationCandidate candidate;
    if(UpdateDeterministicExecutionLifecycleForMLArbitration(running_bullish_signals[i],
                                                             ML_ARBITRATION_ARRAY_BULLISH,
                                                             i,
                                                             activation_time,
                                                             candidate))
      AddElementToArray(candidates, candidate);
  }

  int bearish_total = ArraySize(running_bearish_signals);
  for(int i = bearish_total-1; i >= 0; i--)
  {
    MLArbitrationCandidate candidate;
    if(UpdateDeterministicExecutionLifecycleForMLArbitration(running_bearish_signals[i],
                                                             ML_ARBITRATION_ARRAY_BEARISH,
                                                             i,
                                                             activation_time,
                                                             candidate))
      AddElementToArray(candidates, candidate);
  }

  ProcessMLArbitrationCandidates(candidates);
  CleanupClosedBullishSignals();
  CleanupClosedBearishSignals();
}

void CheckTickOpenBullishSignals()
{
  int running_signals_total = ArraySize(running_bullish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    UpdateExecutionLifecycle(running_bullish_signals[i]);

    bool lifecycle_closed = (running_bullish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bullish_signals[i]))
    {
      running_bullish_signals[i].close_time  = TimeCurrent();
      running_bullish_signals[i].close_price = g_bid;
      running_bullish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bullish_signals[i],
                                                   BULLISH);
      CloseBullishSignal(running_bullish_signals[i]);
      RemoveElementFromArray(running_bullish_signals, i);
    }
  }
}

void CheckTickOpenBearishSignals()
{
  int running_signals_total = ArraySize(running_bearish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    UpdateExecutionLifecycle(running_bearish_signals[i]);

    bool lifecycle_closed = (running_bearish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bearish_signals[i]))
    {
      running_bearish_signals[i].close_time  = TimeCurrent();
      running_bearish_signals[i].close_price = g_ask;
      running_bearish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bearish_signals[i],
                                                   BEARISH);
      CloseBearishSignal(running_bearish_signals[i]);
      RemoveElementFromArray(running_bearish_signals, i);
    }
  }
}

void CheckTickOpenSignals()
{
  if(DeterministicSignalMLFilterMode())
  {
    CheckTickOpenSignalsWithMLArbitration();
    return;
  }

  CheckTickOpenBullishSignals();
  CheckTickOpenBearishSignals();
}

#endif // _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
