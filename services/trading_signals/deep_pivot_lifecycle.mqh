//+------------------------------------------------------------------+
//|                    trading_signals/deep_pivot_lifecycle         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_

const int DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE = 64;

DeepPivotEvent g_deep_pivot_events[];
DeepPivotFrozenParent g_deep_pivot_frozen_parents[];
DeepPivotParentLink g_deep_pivot_parent_links[];
DeepPivotTrial g_deep_pivot_trials[];
DeepPivotOutcome g_deep_pivot_outcomes[];
int g_deep_pivot_event_peak = 0;
int g_deep_pivot_frozen_parent_peak = 0;
int g_deep_pivot_link_peak = 0;
int g_deep_pivot_trial_peak = 0;
int g_deep_pivot_outcome_peak = 0;
int g_deep_pivot_duplicate_identity_count = 0;
int g_deep_pivot_capacity_rejected_count = 0;
bool g_deep_pivot_state_capacity_failed = false;
bool g_deep_pivot_state_allocation_failed = false;
datetime g_deep_pivot_window_terminal_exported_open = 0;

void MarkDeepPivotStateFailed(const string operation,
                              const string context = "",
                              const int error_code = 0)
{
  g_deep_pivot_state_allocation_failed = true;
  PivotV13MarkFailed(operation, "", error_code, context);
}

string DeepPivotWindowId(const ENUM_TIMEFRAMES timeframe,
                         const datetime active_bar_open)
{
  if(timeframe == PERIOD_CURRENT || active_bar_open <= 0)
    return "";
  return PivotV13WindowId(_Symbol, timeframe, active_bar_open);
}

string DeepPivotEventId(const string deep_window_id,
                        const PivotLevelIds level_id)
{
  if(deep_window_id == "")
    return "";
  string payload = deep_window_id + "|" + PivotLevelLabel(level_id);
  return "deep_event_" + StringFormat("%I64u",
                                       PivotTrialStableHash(payload));
}

void ResetDeepPivotRuntimeState()
{
  int resized = ArrayResize(g_deep_pivot_events,
                            0,
                            DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
  int parent_resized = ArrayResize(g_deep_pivot_frozen_parents,
                                   0,
                                   DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
  int link_resized = ArrayResize(g_deep_pivot_parent_links,
                                 0,
                                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
  int trial_resized = ArrayResize(g_deep_pivot_trials,
                                  0,
                                  DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
  int outcome_resized = ArrayResize(g_deep_pivot_outcomes,
                                    0,
                                    DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
  g_deep_pivot_event_peak = 0;
  g_deep_pivot_frozen_parent_peak = 0;
  g_deep_pivot_link_peak = 0;
  g_deep_pivot_trial_peak = 0;
  g_deep_pivot_outcome_peak = 0;
  g_deep_pivot_duplicate_identity_count = 0;
  g_deep_pivot_capacity_rejected_count = 0;
  g_deep_pivot_state_capacity_failed = false;
  g_deep_pivot_window_terminal_exported_open = 0;
  g_deep_pivot_state_allocation_failed = resized != 0 ||
                                        parent_resized != 0 ||
                                        link_resized != 0 ||
                                        trial_resized != 0 ||
                                        outcome_resized != 0;
  if(g_deep_pivot_state_allocation_failed)
    PivotV13MarkFailed("DEEP_STATE_RESET", "", GetLastError());
}

int DeepPivotEventCount()
{
  return ArraySize(g_deep_pivot_events);
}

int DeepPivotEventPeak()
{
  return g_deep_pivot_event_peak;
}

int DeepPivotDuplicateIdentityCount()
{
  return g_deep_pivot_duplicate_identity_count;
}

int DeepPivotFrozenParentCount()
{
  return ArraySize(g_deep_pivot_frozen_parents);
}

int DeepPivotParentLinkCount()
{
  return ArraySize(g_deep_pivot_parent_links);
}

int DeepPivotTrialCount()
{
  return ArraySize(g_deep_pivot_trials);
}

int DeepPivotOutcomeCount()
{
  return ArraySize(g_deep_pivot_outcomes);
}

bool DeepPivotHasOutstandingOutcomes()
{
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
    if(g_deep_pivot_outcomes[i].active)
      return true;
  for(int i = 0; i < DeepPivotParentLinkCount(); i++)
    if(g_deep_pivot_parent_links[i].active)
      return true;
  for(int i = 0; i < DeepPivotTrialCount(); i++)
    if(g_deep_pivot_trials[i].active)
      return true;
  for(int i = 0; i < DeepPivotEventCount(); i++)
    if(!g_deep_pivot_events[i].terminal)
      return true;
  return false;
}

int DeepPivotParentLinkPeak()
{
  return g_deep_pivot_link_peak;
}

int DeepPivotTrialPeak()
{
  return g_deep_pivot_trial_peak;
}

int DeepPivotOutcomePeak()
{
  return g_deep_pivot_outcome_peak;
}

string DeepPivotParentLinkId(const string deep_event_id,
                            const string parent_trial_id)
{
  if(deep_event_id == "" || parent_trial_id == "")
    return "";
  return "deep_link_" + StringFormat("%I64u",
                                     PivotTrialStableHash(deep_event_id + "|" +
                                                          parent_trial_id));
}

string DeepPivotTrialId(const string deep_event_id,
                        const int tp_r_multiple)
{
  if(deep_event_id == "" ||
     (tp_r_multiple != 1 && tp_r_multiple != 2 && tp_r_multiple != 3))
    return "";
  return "deep_trial_" + StringFormat("%I64u",
                                      PivotTrialStableHash(
                                        deep_event_id + "|" +
                                        IntegerToString(tp_r_multiple)));
}

string DeepPivotOutcomeId(const string parent_link_id,
                          const string deep_trial_id)
{
  if(parent_link_id == "" || deep_trial_id == "")
    return "";
  return "deep_outcome_" + StringFormat("%I64u",
                                        PivotTrialStableHash(
                                          parent_link_id + "|" +
                                          deep_trial_id));
}

bool DeepPivotTpMultipleAt(const int index,
                           int &multiple_out)
{
  multiple_out = 0;
  if(index < 0 || index >= 3)
    return false;
  multiple_out = index + 1;
  return true;
}

void RecordDeepPivotBrokerParentClose(const PivotSignal &signal)
{
  if(!Enable_Signal_Feature_Export ||
     !signal.execution.broker_close_confirmed ||
     signal.execution.close_time <= 0)
    return;

  // Transfer the deal clock before broker cleanup removes the signal. Only
  // existing bounded research links retain it; execution never waits for them.
  for(int i = 0; i < DeepPivotParentLinkCount(); i++)
  {
    if(!g_deep_pivot_parent_links[i].active ||
       g_deep_pivot_parent_links[i].parent_kind != DEEP_PIVOT_PARENT_BROKER ||
       g_deep_pivot_parent_links[i].parent_broker_signal_id !=
         signal.broker_signal_id)
      continue;
    datetime existing_time = g_deep_pivot_parent_links[i].parent_terminal_time;
    if(signal.execution.close_time <
         g_deep_pivot_parent_links[i].event_trigger_time ||
       (existing_time > 0 && existing_time != signal.execution.close_time))
    {
      g_deep_pivot_state_allocation_failed = true;
      PivotV13RejectReference("DEEP_BROKER_PARENT_TERMINAL_INVALID",
        StringFormat("broker=%s|link=%s|trigger=%I64d|close=%I64d|retained_close=%I64d",
          signal.broker_signal_id, g_deep_pivot_parent_links[i].parent_link_id,
          (long)g_deep_pivot_parent_links[i].event_trigger_time,
          (long)signal.execution.close_time, (long)existing_time));
      continue;
    }
    g_deep_pivot_parent_links[i].parent_terminal_time =
      signal.execution.close_time;
  }
}

bool DeepPivotParentStillActive(const DeepPivotParentLink &link)
{
  if(!link.active || link.parent_trial_id == "" || link.parent_terminal_time > 0)
    return false;
  if(link.parent_kind == DEEP_PIVOT_PARENT_H1_VIRTUAL)
  {
    int index = FindPivotTrialActiveStateByTrialId(link.parent_trial_id);
    if(index < 0)
      return false;
    PivotTrialActiveState state;
    return CopyPivotTrialActiveStateAt(index, state) && state.active &&
           !state.pending_entry &&
           state.trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  }
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    PivotSignal signal(g_pivot_signals[i]);
    if(signal.broker_signal_id == link.parent_broker_signal_id &&
       signal.execution.broker_entry_confirmed &&
       !signal.execution.broker_close_confirmed)
      return true;
  }
  return false;
}

int FindDeepPivotParentLink(const string parent_link_id)
{
  if(parent_link_id == "")
    return -1;
  for(int i = 0; i < DeepPivotParentLinkCount(); i++)
    if(g_deep_pivot_parent_links[i].parent_link_id == parent_link_id)
      return i;
  return -1;
}

int FindDeepPivotTrial(const string deep_trial_id)
{
  if(deep_trial_id == "")
    return -1;
  for(int i = 0; i < DeepPivotTrialCount(); i++)
    if(g_deep_pivot_trials[i].deep_trial_id == deep_trial_id)
      return i;
  return -1;
}

bool DeepPivotResearchIntegrityFailed()
{
  return g_deep_pivot_state_capacity_failed ||
         g_deep_pivot_state_allocation_failed ||
         g_deep_pivot_duplicate_identity_count > 0;
}

int FindDeepPivotEventByIdentity(const string deep_window_id,
                                 const PivotLevelIds level_id)
{
  if(deep_window_id == "")
    return -1;
  for(int i = 0; i < DeepPivotEventCount(); i++)
  {
    if(g_deep_pivot_events[i].identity.deep_window_id == deep_window_id &&
       g_deep_pivot_events[i].identity.level_id == level_id)
      return i;
  }
  return -1;
}

int FindDeepPivotEventById(const string deep_event_id)
{
  if(deep_event_id == "")
    return -1;
  for(int i = 0; i < DeepPivotEventCount(); i++)
    if(g_deep_pivot_events[i].identity.deep_event_id == deep_event_id)
      return i;
  return -1;
}

bool DeepPivotParentCandidateDuplicate(
  const DeepPivotParentCandidate &candidate,
  const DeepPivotParentCandidate &parents[],
  const int total)
{
  for(int i = 0; i < total; i++)
  {
    if(parents[i].parent_trial_id == candidate.parent_trial_id &&
       candidate.parent_trial_id != "")
      return true;
  }
  return false;
}

int CollectDeepPivotParentSnapshot(const SignalTypes direction,
                                   const datetime event_time,
                                   DeepPivotParentCandidate &parents[])
{
  if(ArrayResize(parents, 0, DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != 0)
  {
    MarkDeepPivotStateFailed("DEEP_SNAPSHOT_RESET", "", GetLastError());
    return -1;
  }
  if(event_time <= 0)
    return 0;

  int total = 0;
  for(int i = 0; i < PivotTrialActiveStateCount(); i++)
  {
    PivotTrialActiveState state;
    if(!CopyPivotTrialActiveStateAt(i, state) || !state.active ||
       state.pending_entry ||
       state.trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
       state.trial.direction != direction || state.trial.entry_time <= 0 ||
       state.trial.entry_time > event_time ||
       state.trial.identity.trial_id == "")
      continue;

    DeepPivotParentCandidate candidate;
    if(state.trial.identity.role != PIVOT_TRIAL_ROLE_H1)
      continue;
    candidate.parent_kind = DEEP_PIVOT_PARENT_H1_VIRTUAL;
    candidate.origin_id = state.trial.identity.origin_id;
    candidate.parent_trial_id = state.trial.identity.trial_id;
    candidate.parent_broker_signal_id = state.trial.identity.broker_signal_id;
    candidate.parent_entry_policy = state.trial.identity.entry_policy;
    candidate.parent_tp_r_multiple = state.trial.identity.tp_r_multiple;
    candidate.direction = state.trial.direction;
    candidate.parent_entry_time = state.trial.entry_time;
    if(DeepPivotParentCandidateDuplicate(candidate, parents, total))
      continue;

    if(total >= PIVOT_DEEP_LINK_ACTIVE_CAP)
    {
      g_deep_pivot_state_capacity_failed = true;
      PivotV13MarkFailed("DEEP_SNAPSHOT_CAP", "", 0, candidate.parent_trial_id);
      return -1;
    }
    if(ArrayResize(parents,
                   total + 1,
                   DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
    {
      MarkDeepPivotStateFailed("DEEP_SNAPSHOT_RESIZE", candidate.parent_trial_id,
                              GetLastError());
      return -1;
    }
    parents[total].CopyFrom(candidate);
    total++;
  }

  // Broker parents are admitted only after a confirmed fill. The parity
  // shadow is deliberately not used as a proxy for broker exposure.
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    PivotSignal signal(g_pivot_signals[i]);
    if(!signal.execution.broker_entry_confirmed ||
       signal.execution.broker_close_confirmed ||
       signal.direction != direction ||
       signal.execution.broker_entry_time <= 0 ||
       signal.execution.broker_entry_time > event_time ||
       signal.broker_signal_id == "")
      continue;
    DeepPivotParentCandidate candidate;
    candidate.parent_kind = DEEP_PIVOT_PARENT_BROKER;
    candidate.origin_id = signal.origin_id;
    candidate.parent_trial_id = signal.parity_trial_id != ""
                                ? signal.parity_trial_id
                                : signal.broker_signal_id;
    candidate.parent_broker_signal_id = signal.broker_signal_id;
    candidate.parent_entry_policy = signal.broker_entry_policy;
    candidate.parent_tp_r_multiple = signal.broker_tp_r_multiple;
    candidate.direction = signal.direction;
    candidate.parent_entry_time = signal.execution.broker_entry_time;
    if(DeepPivotParentCandidateDuplicate(candidate, parents, total))
      continue;
    if(total >= PIVOT_DEEP_LINK_ACTIVE_CAP)
    {
      g_deep_pivot_state_capacity_failed = true;
      PivotV13MarkFailed("DEEP_SNAPSHOT_CAP", "", 0, candidate.parent_trial_id);
      return -1;
    }
    if(ArrayResize(parents,
                   total + 1,
                   DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
    {
      MarkDeepPivotStateFailed("DEEP_SNAPSHOT_RESIZE", candidate.parent_trial_id,
                              GetLastError());
      return -1;
    }
    parents[total].CopyFrom(candidate);
    total++;
  }
  return total;
}

bool BuildDeepPivotEventFromCandidate(const PivotTouchCandidate &candidate,
                                      const MqlTick &tick,
                                      const int active_parent_count,
                                      DeepPivotEvent &event_out)
{
  event_out.Reset();
  if(active_parent_count <= 0 || !PivotTrialQuoteValid(tick) ||
     candidate.window.active_bar_open <= 0 || candidate.level_price <= 0.0)
    return false;

  event_out.identity.deep_window_id =
    DeepPivotWindowId(candidate.window.timeframe,
                      candidate.window.active_bar_open);
  event_out.identity.deep_event_id =
    DeepPivotEventId(event_out.identity.deep_window_id,
                     candidate.level_id);
  event_out.identity.symbol = _Symbol;
  event_out.identity.deep_timeframe = candidate.window.timeframe;
  event_out.identity.active_deep_bar_open = candidate.window.active_bar_open;
  event_out.identity.level_id = candidate.level_id;
  event_out.direction = candidate.direction;
  event_out.trigger_time = tick.time;
  event_out.trigger_bid = tick.bid;
  event_out.trigger_ask = tick.ask;
  event_out.identity_consumed = true;
  event_out.active_parent_count = active_parent_count;
  event_out.levels.CopyFrom(candidate.window.levels);
  int level_index = (int)candidate.level_id;
  if(level_index < 0 || level_index >= PIVOT_LEVEL_COUNT)
    return false;
  event_out.pivot_raw_price = candidate.window.levels.raw_prices[level_index];
  event_out.pivot_trade_price = candidate.window.levels.trade_prices[level_index];
  event_out.deep_micro_features_complete =
    CapturePivotMicroFeatureSnapshot(tick.bid,
                                     event_out.pivot_trade_price,
                                     tick.time,
                                     event_out.features);
  event_out.deep_feature_invalid_reason = event_out.features.invalid_reason;
  bool boundary_available = false;
  double boundary_price = 0.0;
  if(PivotTrialNextOutwardBoundary(candidate.direction,
                                  candidate.level_id,
                                  candidate.window.levels,
                                  boundary_available,
                                  boundary_price) &&
     boundary_available)
    event_out.next_outward_pivot_price = boundary_price;
  event_out.point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE,
                   event_out.trade_tick_size);
  event_out.spread_points = event_out.point_size > 0.0
                            ? (tick.ask - tick.bid) / event_out.point_size
                            : 0.0;
  if(BrokerConstraintsNeedRefresh())
    RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints);
  event_out.stops_level_points = g_symbol_constraints.stops_level_points;
  event_out.freeze_level_points = g_symbol_constraints.freeze_level_points;
  event_out.required_link_slots = active_parent_count;
  event_out.required_trial_slots = 3;
  event_out.required_outcome_slots = active_parent_count * 3;
  event_out.reserved_link_slots = event_out.required_link_slots;
  event_out.reserved_trial_slots = event_out.required_trial_slots;
  event_out.reserved_outcome_slots = event_out.required_outcome_slots;
  return event_out.identity.deep_event_id != "" &&
         event_out.point_size > 0.0 && event_out.trade_tick_size > 0.0;
}

bool BuildDeepPivotTrial(const DeepPivotEvent &event,
                         const MqlTick &tick,
                         const int tp_r_multiple,
                         DeepPivotTrial &trial_out)
{
  trial_out.Reset();
  trial_out.deep_trial_id = DeepPivotTrialId(event.identity.deep_event_id,
                                             tp_r_multiple);
  trial_out.deep_event_id = event.identity.deep_event_id;
  trial_out.tp_r_multiple = tp_r_multiple;
  trial_out.level_id = event.identity.level_id;
  trial_out.direction = event.direction;
  trial_out.declared_time = event.trigger_time;
  if(trial_out.deep_trial_id == "" || !PivotTrialQuoteValid(tick) ||
     event.next_outward_pivot_price <= 0.0)
  {
    trial_out.ineligible_reason = "DEEP_STOP_GEOMETRY_UNAVAILABLE";
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }

  if(!BuildPivotTrialGeometryAtStop(
       event.identity.deep_event_id,
       event.direction,
       tick,
       event.next_outward_pivot_price,
       tp_r_multiple,
       event.point_size,
       event.trade_tick_size,
       event.stops_level_points,
       event.freeze_level_points,
       true,
       trial_out.geometry))
  {
    trial_out.ineligible_reason = trial_out.geometry.invalid_reason == ""
                                  ? "DEEP_GEOMETRY_INVALID"
                                  : trial_out.geometry.invalid_reason;
    trial_out.eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    return true;
  }
  if(!trial_out.geometry.distance_eligible)
  {
    trial_out.ineligible_reason = "DEEP_MINIMUM_RISK_DISTANCE_NOT_MET";
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

bool BuildDeepPivotOutcomeBase(const DeepPivotParentLink &link,
                               const DeepPivotTrial &trial,
                               const MqlTick &tick,
                               const string terminal_status,
                               const string terminal_reason,
                               const PivotTrialFirstTouchOutcomes first_touch,
                               DeepPivotOutcome &outcome_out)
{
  outcome_out.Reset();
  if(link.parent_link_id == "" || trial.deep_trial_id == "" ||
     !PivotTrialQuoteValid(tick) || terminal_status == "" ||
     terminal_reason == "")
    return false;
  outcome_out.deep_outcome_id = DeepPivotOutcomeId(link.parent_link_id,
                                                   trial.deep_trial_id);
  outcome_out.parent_link_id = link.parent_link_id;
  outcome_out.deep_trial_id = trial.deep_trial_id;
  outcome_out.deep_event_id = link.deep_event_id;
  outcome_out.origin_id = link.origin_id;
  outcome_out.tp_r_multiple = trial.tp_r_multiple;
  outcome_out.direction = trial.direction;
  outcome_out.terminal_time = tick.time > link.event_trigger_time
                              ? tick.time
                              : link.event_trigger_time + 1;
  outcome_out.first_touch = first_touch;
  outcome_out.terminal_status = terminal_status;
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
  return outcome_out.deep_outcome_id != "";
}

bool BuildDeepPivotIneligibleOutcome(const DeepPivotParentLink &link,
                                     const DeepPivotTrial &trial,
                                     const MqlTick &tick,
                                     DeepPivotOutcome &outcome_out)
{
  return BuildDeepPivotOutcomeBase(link,
                                   trial,
                                   tick,
                                   "INELIGIBLE",
                                   trial.ineligible_reason == ""
                                   ? "DEEP_GEOMETRY_INVALID"
                                   : trial.ineligible_reason,
                                   PIVOT_TRIAL_FIRST_TOUCH_INELIGIBLE,
                                   outcome_out);
}

bool ResolveDeepPivotOutcome(const DeepPivotParentLink &link,
                             const DeepPivotTrial &trial,
                             const MqlTick &tick,
                             DeepPivotOutcome &outcome_out)
{
  if(trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
     !trial.geometry.valid || !trial.money_plan.complete ||
     !PivotTrialQuoteValid(tick) || tick.time <= link.event_trigger_time)
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
  if(!BuildDeepPivotOutcomeBase(link,
                                trial,
                                tick,
                                tp_touched ? "TP_FIRST" : "SL_FIRST",
                                tp_touched ? "TP_THRESHOLD" : "SL_THRESHOLD",
                                tp_touched ? PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST
                                            : PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST,
                                outcome_out))
    return false;
  outcome_out.threshold_price = tp_touched
                               ? trial.geometry.take_profit_price
                               : trial.geometry.stop_loss_price;
  outcome_out.gap_points = MathAbs(exit_price - outcome_out.threshold_price) /
                           trial.geometry.point_size;
  outcome_out.lifecycle_seconds = (long)(tick.time - link.event_trigger_time);
  outcome_out.lifecycle_seconds_available = true;
  outcome_out.virtual_nominal_r = tp_touched
                                  ? (double)trial.tp_r_multiple
                                  : -1.0;
  outcome_out.virtual_quote_gross_available =
    ResolveExecutionQuoteProfit(trial.direction,
                                trial.money_plan.normalized_volume,
                                trial.geometry.entry_price,
                                exit_price,
                                outcome_out.virtual_quote_gross_profit);
  if(outcome_out.virtual_quote_gross_available)
    outcome_out.virtual_quote_gross_r =
      outcome_out.virtual_quote_gross_profit /
      MathAbs(trial.money_plan.virtual_expected_stop_loss);
  outcome_out.virtual_binary_eligible = true;
  outcome_out.virtual_binary_target = tp_touched ? 1 : 0;
  outcome_out.virtual_exclusion_reason = "";
  return true;
}

bool BuildDeepPivotParentExitOutcome(const DeepPivotParentLink &link,
                                     const DeepPivotTrial &trial,
                                     const MqlTick &tick,
                                     DeepPivotOutcome &outcome_out)
{
  datetime terminal_time = link.parent_kind == DEEP_PIVOT_PARENT_BROKER
                           ? link.parent_terminal_time
                           : tick.time;
  if(terminal_time <= 0 || terminal_time < link.event_trigger_time)
    return false;
  if(!BuildDeepPivotOutcomeBase(link,
                                trial,
                                tick,
                                "CENSORED_PARENT_EXIT",
                                "CENSORED_PARENT_EXIT",
                                PIVOT_TRIAL_FIRST_TOUCH_CENSORED,
                                outcome_out))
    return false;

  // Censor at the parent's actual terminal clock. The observed quote remains
  // an observation, with no completed return or duration assigned to a censor.
  outcome_out.terminal_time = terminal_time;
  return true;
}

bool BuildDeepPivotRunEndOutcome(const DeepPivotParentLink &link,
                                 const DeepPivotTrial &trial,
                                 const MqlTick &tick,
                                 DeepPivotOutcome &outcome_out)
{
  return BuildDeepPivotOutcomeBase(link,
                                   trial,
                                   tick,
                                   "CENSORED_RUN_END",
                                   "CENSORED_RUN_END",
                                   PIVOT_TRIAL_FIRST_TOUCH_CENSORED,
                                   outcome_out);
}

bool QueueDeepPivotOutcomeForExport(const DeepPivotOutcome &outcome)
{
  // Sprint 5 owns the TSV writer; keeping this boundary explicit prevents
  // deep state from ever becoming an execution decision.
  return outcome.deep_outcome_id != "";
}

bool DeepPivotLinkHasActiveOutcome(const string parent_link_id)
{
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
    if(g_deep_pivot_outcomes[i].parent_link_id == parent_link_id &&
       g_deep_pivot_outcomes[i].active)
      return true;
  return false;
}

bool DeepPivotEventHasActiveOutcome(const string deep_event_id)
{
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
    if(g_deep_pivot_outcomes[i].deep_event_id == deep_event_id &&
       g_deep_pivot_outcomes[i].active)
      return true;
  return false;
}

int DeepPivotTrialActiveOutcomeCount(const string deep_trial_id)
{
  int count = 0;
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
    if(g_deep_pivot_outcomes[i].deep_trial_id == deep_trial_id &&
       g_deep_pivot_outcomes[i].active)
      count++;
  return count;
}

void RefreshDeepPivotTerminalFlags()
{
  for(int i = 0; i < DeepPivotTrialCount(); i++)
  {
    int remaining = DeepPivotTrialActiveOutcomeCount(
      g_deep_pivot_trials[i].deep_trial_id);
    g_deep_pivot_trials[i].remaining_parent_count = remaining;
    g_deep_pivot_trials[i].active = remaining > 0;
  }
  for(int i = 0; i < DeepPivotParentLinkCount(); i++)
  {
    if(!DeepPivotLinkHasActiveOutcome(
         g_deep_pivot_parent_links[i].parent_link_id))
    {
      g_deep_pivot_parent_links[i].active = false;
      if(g_deep_pivot_parent_links[i].link_status == DEEP_PIVOT_LINK_ACTIVE)
        g_deep_pivot_parent_links[i].link_status = DEEP_PIVOT_LINK_COMPLETE;
    }
  }
  for(int i = 0; i < DeepPivotEventCount(); i++)
  {
    if(!DeepPivotEventHasActiveOutcome(
         g_deep_pivot_events[i].identity.deep_event_id))
      g_deep_pivot_events[i].terminal = true;
  }
}

bool RemoveDeepPivotOutcomeAt(const int index)
{
  int total = DeepPivotOutcomeCount();
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_deep_pivot_outcomes[i].CopyFrom(g_deep_pivot_outcomes[i + 1]);
  int reserve = total - 1 > 0 ? DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE : 0;
  return ArrayResize(g_deep_pivot_outcomes, total - 1, reserve) == total - 1;
}

bool RemoveDeepPivotParentLinkAt(const int index)
{
  int total = DeepPivotParentLinkCount();
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_deep_pivot_parent_links[i].CopyFrom(g_deep_pivot_parent_links[i + 1]);
  int reserve = total - 1 > 0 ? DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE : 0;
  return ArrayResize(g_deep_pivot_parent_links,
                     total - 1,
                     reserve) == total - 1;
}

bool RemoveDeepPivotTrialAt(const int index)
{
  int total = DeepPivotTrialCount();
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_deep_pivot_trials[i].CopyFrom(g_deep_pivot_trials[i + 1]);
  int reserve = total - 1 > 0 ? DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE : 0;
  return ArrayResize(g_deep_pivot_trials, total - 1, reserve) == total - 1;
}

bool RemoveDeepPivotFrozenParentAt(const int index)
{
  int total = DeepPivotFrozenParentCount();
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_deep_pivot_frozen_parents[i].CopyFrom(
      g_deep_pivot_frozen_parents[i + 1]);
  int reserve = total - 1 > 0 ? DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE : 0;
  return ArrayResize(g_deep_pivot_frozen_parents,
                     total - 1,
                     reserve) == total - 1;
}

bool RemoveDeepPivotEventAt(const int index)
{
  int total = DeepPivotEventCount();
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_deep_pivot_events[i].CopyFrom(g_deep_pivot_events[i + 1]);
  int reserve = total - 1 > 0 ? DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE : 0;
  return ArrayResize(g_deep_pivot_events, total - 1, reserve) == total - 1;
}

bool ReleaseTerminalDeepPivotState()
{
  for(int event_index = DeepPivotEventCount() - 1;
      event_index >= 0;
      event_index--)
  {
    const string deep_event_id =
      g_deep_pivot_events[event_index].identity.deep_event_id;
    if(!g_deep_pivot_events[event_index].terminal ||
       DeepPivotEventHasActiveOutcome(deep_event_id))
      continue;

    for(int i = DeepPivotOutcomeCount() - 1; i >= 0; i--)
    {
      if(g_deep_pivot_outcomes[i].deep_event_id == deep_event_id &&
         !RemoveDeepPivotOutcomeAt(i))
        return false;
    }
    for(int i = DeepPivotParentLinkCount() - 1; i >= 0; i--)
    {
      if(g_deep_pivot_parent_links[i].deep_event_id == deep_event_id &&
         !RemoveDeepPivotParentLinkAt(i))
        return false;
    }
    for(int i = DeepPivotTrialCount() - 1; i >= 0; i--)
    {
      if(g_deep_pivot_trials[i].deep_event_id == deep_event_id &&
         !RemoveDeepPivotTrialAt(i))
        return false;
    }
    for(int i = DeepPivotFrozenParentCount() - 1; i >= 0; i--)
    {
      if(g_deep_pivot_frozen_parents[i].deep_event_id == deep_event_id &&
         !RemoveDeepPivotFrozenParentAt(i))
        return false;
    }
    if(!RemoveDeepPivotEventAt(event_index))
      return false;
  }
  return true;
}

void ResolveDeepPivotActiveOutcomes(const MqlTick &tick)
{
  if(!PivotTrialQuoteValid(tick))
    return;
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
  {
    DeepPivotOutcome active_outcome(g_deep_pivot_outcomes[i]);
    if(!active_outcome.active)
      continue;
    int link_index = FindDeepPivotParentLink(active_outcome.parent_link_id);
    int trial_index = FindDeepPivotTrial(active_outcome.deep_trial_id);
    if(link_index < 0 || trial_index < 0)
    {
      MarkDeepPivotStateFailed("DEEP_OUTCOME_ASSOCIATION", active_outcome.deep_outcome_id);
      continue;
    }
    DeepPivotParentLink link(g_deep_pivot_parent_links[link_index]);
    DeepPivotTrial trial(g_deep_pivot_trials[trial_index]);
    DeepPivotOutcome resolved;
    bool resolved_now = false;
    if(!DeepPivotParentStillActive(link))
    {
      resolved_now = BuildDeepPivotParentExitOutcome(link,
                                                      trial,
                                                      tick,
                                                      resolved);
      if(!resolved_now)
      {
        g_deep_pivot_state_allocation_failed = true;
        PivotV13RejectReference("DEEP_PARENT_TERMINAL_UNAVAILABLE",
          StringFormat("broker=%s|link=%s|trial=%s|kind=%d|trigger=%I64d|retained_close=%I64d",
            link.parent_broker_signal_id, link.parent_link_id, trial.deep_trial_id,
            (int)link.parent_kind, (long)link.event_trigger_time,
            (long)link.parent_terminal_time));
      }
      g_deep_pivot_parent_links[link_index].link_status =
        DEEP_PIVOT_LINK_PARENT_EXIT;
    }
    else
    {
      resolved_now = ResolveDeepPivotOutcome(link,
                                             trial,
                                             tick,
                                             resolved);
    }
    if(!resolved_now)
      continue;
    if(!PivotV13RecordDeepPivotOutcome(resolved) ||
       !QueueDeepPivotOutcomeForExport(resolved))
    {
      MarkDeepPivotStateFailed("DEEP_OUTCOME_RECORD", resolved.deep_outcome_id);
      continue;
    }
    g_deep_pivot_outcomes[i].CopyFrom(resolved);
    g_deep_pivot_outcomes[i].active = false;
    if(g_deep_pivot_trials[trial_index].remaining_parent_count > 0)
      g_deep_pivot_trials[trial_index].remaining_parent_count--;
    if(g_deep_pivot_trials[trial_index].remaining_parent_count <= 0)
      g_deep_pivot_trials[trial_index].active = false;
  }
  RefreshDeepPivotTerminalFlags();
  if(!ReleaseTerminalDeepPivotState())
    MarkDeepPivotStateFailed("DEEP_TERMINAL_RELEASE", "", GetLastError());
}

bool AppendDeepPivotCapacityRejectedEvent(const DeepPivotEvent &event,
                                          const string rejection_reason)
{
  if(event.identity.deep_event_id == "" ||
     event.identity.deep_window_id == "" ||
     rejection_reason == "")
    return false;
  if(FindDeepPivotEventByIdentity(event.identity.deep_window_id,
                                  event.identity.level_id) >= 0)
  {
    g_deep_pivot_duplicate_identity_count++;
    PivotV13MarkFailed("DEEP_EVENT_DUPLICATE", "", 0, event.identity.deep_event_id);
    return false;
  }
  DeepPivotEvent rejected;
  rejected.CopyFrom(event);
  rejected.admission_status = DEEP_PIVOT_ADMISSION_CAPACITY_REJECTED;
  rejected.capacity_rejection_reason = rejection_reason;
  rejected.reserved_link_slots = 0;
  rejected.reserved_trial_slots = 0;
  rejected.reserved_outcome_slots = 0;
  rejected.terminal = true;
  if(!PivotV13RecordDeepPivotEvent(rejected))
    return false;
  return true;
}

bool AppendDeepPivotEvent(const DeepPivotEvent &event,
                          const DeepPivotParentCandidate &parents[],
                          const int parent_count)
{
  if(event.identity.deep_event_id == "" || parent_count <= 0 ||
     parent_count != ArraySize(parents) ||
     event.required_link_slots != parent_count ||
     event.required_trial_slots != 3 ||
     event.required_outcome_slots != parent_count * 3)
    return false;
  if(FindDeepPivotEventByIdentity(event.identity.deep_window_id,
                                  event.identity.level_id) >= 0)
  {
    g_deep_pivot_duplicate_identity_count++;
    PivotV13MarkFailed("DEEP_EVENT_DUPLICATE", "", 0, event.identity.deep_event_id);
    return false;
  }
  if(DeepPivotEventCount() >= PIVOT_DEEP_EVENT_ACTIVE_CAP ||
     DeepPivotFrozenParentCount() + parent_count >
       PIVOT_DEEP_LINK_ACTIVE_CAP ||
     DeepPivotParentLinkCount() + parent_count >
       PIVOT_DEEP_LINK_ACTIVE_CAP ||
     DeepPivotTrialCount() + 3 > PIVOT_DEEP_TRIAL_ACTIVE_CAP ||
     DeepPivotOutcomeCount() + parent_count * 3 >
       PIVOT_DEEP_OUTCOME_ACTIVE_CAP)
  {
    g_deep_pivot_capacity_rejected_count++;
    return AppendDeepPivotCapacityRejectedEvent(
      event,
      "DEEP_FANOUT_CAPACITY_REJECTED");
  }

  DeepPivotTrial trials[3];
  MqlTick event_tick;
  ZeroMemory(event_tick);
  event_tick.time = event.trigger_time;
  event_tick.bid = event.trigger_bid;
  event_tick.ask = event.trigger_ask;
  for(int trial_index = 0; trial_index < 3; trial_index++)
  {
    int ratio = 0;
    if(!DeepPivotTpMultipleAt(trial_index, ratio) ||
       !BuildDeepPivotTrial(event,
                            event_tick,
                            ratio,
                            trials[trial_index]))
      return false;
    trials[trial_index].remaining_parent_count =
      trials[trial_index].eligibility_status ==
      PIVOT_TRIAL_ELIGIBILITY_ACTIVE ? parent_count : 0;
    trials[trial_index].active = trials[trial_index].remaining_parent_count > 0;
  }

  int total = DeepPivotEventCount();
  int parents_start = DeepPivotFrozenParentCount();
  int links_start = DeepPivotParentLinkCount();
  int trials_start = DeepPivotTrialCount();
  int outcomes_start = DeepPivotOutcomeCount();
  if(ArrayResize(g_deep_pivot_events,
                 total + 1,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
  {
    MarkDeepPivotStateFailed("DEEP_EVENT_RESIZE", event.identity.deep_event_id,
                            GetLastError());
    return false;
  }
  if(ArrayResize(g_deep_pivot_frozen_parents,
                 parents_start + parent_count,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) !=
     parents_start + parent_count ||
     ArrayResize(g_deep_pivot_parent_links,
                 links_start + parent_count,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) !=
       links_start + parent_count ||
     ArrayResize(g_deep_pivot_trials,
                 trials_start + 3,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != trials_start + 3 ||
     ArrayResize(g_deep_pivot_outcomes,
                 outcomes_start + parent_count * 3,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) !=
       outcomes_start + parent_count * 3)
  {
    MarkDeepPivotStateFailed("DEEP_FANOUT_RESIZE", event.identity.deep_event_id,
                            GetLastError());
    ArrayResize(g_deep_pivot_events,
                total,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    ArrayResize(g_deep_pivot_frozen_parents,
                parents_start,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    ArrayResize(g_deep_pivot_parent_links,
                links_start,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    ArrayResize(g_deep_pivot_trials,
                trials_start,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    ArrayResize(g_deep_pivot_outcomes,
                outcomes_start,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    return false;
  }
  g_deep_pivot_events[total].CopyFrom(event);
  if(!PivotV13RecordDeepPivotEvent(g_deep_pivot_events[total]))
  {
    MarkDeepPivotStateFailed("DEEP_EVENT_RECORD", event.identity.deep_event_id);
    return false;
  }
  for(int i = 0; i < parent_count; i++)
  {
    g_deep_pivot_frozen_parents[parents_start + i].deep_event_id =
      event.identity.deep_event_id;
    g_deep_pivot_frozen_parents[parents_start + i].parent.CopyFrom(parents[i]);

    DeepPivotParentLink link;
    link.Reset();
    link.parent_link_id = DeepPivotParentLinkId(
      event.identity.deep_event_id,
      parents[i].parent_trial_id);
    link.deep_event_id = event.identity.deep_event_id;
    link.origin_id = parents[i].origin_id;
    link.parent_kind = parents[i].parent_kind;
    link.parent_trial_id = parents[i].parent_trial_id;
    link.parent_broker_signal_id = parents[i].parent_broker_signal_id;
    link.parent_entry_policy = parents[i].parent_entry_policy;
    link.parent_tp_r_multiple = parents[i].parent_tp_r_multiple;
    link.direction = parents[i].direction;
    link.parent_entry_time = parents[i].parent_entry_time;
    link.event_trigger_time = event.trigger_time;
    link.parent_age_seconds = event.trigger_time >= parents[i].parent_entry_time
                              ? (long)(event.trigger_time -
                                       parents[i].parent_entry_time)
                              : 0;
    g_deep_pivot_parent_links[links_start + i].CopyFrom(link);
    if(!PivotV13RecordDeepPivotParentLink(link))
    {
      MarkDeepPivotStateFailed("DEEP_LINK_RECORD", link.parent_link_id);
      return false;
    }
  }
  bool event_active = false;
  for(int trial_index = 0; trial_index < 3; trial_index++)
  {
    g_deep_pivot_trials[trials_start + trial_index].CopyFrom(
      trials[trial_index]);
    if(!PivotV13RecordDeepPivotTrial(
         g_deep_pivot_trials[trials_start + trial_index]))
    {
      MarkDeepPivotStateFailed("DEEP_TRIAL_RECORD", trials[trial_index].deep_trial_id);
      return false;
    }
    if(trials[trial_index].eligibility_status ==
       PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
      event_active = true;
    for(int parent_index = 0; parent_index < parent_count; parent_index++)
    {
      int outcome_index = outcomes_start +
                          trial_index * parent_count + parent_index;
      DeepPivotOutcome outcome;
      DeepPivotParentLink link(
        g_deep_pivot_parent_links[links_start + parent_index]);
      if(trials[trial_index].eligibility_status !=
         PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
      {
        if(!BuildDeepPivotIneligibleOutcome(link,
                                            trials[trial_index],
                                            event_tick,
                                            outcome))
        {
          MarkDeepPivotStateFailed("DEEP_INELIGIBLE_OUTCOME_BUILD", link.parent_link_id);
          ArrayResize(g_deep_pivot_events, total,
                      DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
          ArrayResize(g_deep_pivot_frozen_parents, parents_start,
                      DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
          ArrayResize(g_deep_pivot_parent_links, links_start,
                      DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
          ArrayResize(g_deep_pivot_trials, trials_start,
                      DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
          ArrayResize(g_deep_pivot_outcomes, outcomes_start,
                      DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
          return false;
        }
        outcome.active = false;
        g_deep_pivot_outcomes[outcome_index].CopyFrom(outcome);
        if(!PivotV13RecordDeepPivotOutcome(outcome))
        {
          MarkDeepPivotStateFailed("DEEP_INELIGIBLE_OUTCOME_RECORD", outcome.deep_outcome_id);
          return false;
        }
      }
      else
      {
        outcome.deep_outcome_id = DeepPivotOutcomeId(
          link.parent_link_id,
          trials[trial_index].deep_trial_id);
        outcome.parent_link_id = link.parent_link_id;
        outcome.deep_trial_id = trials[trial_index].deep_trial_id;
        outcome.deep_event_id = event.identity.deep_event_id;
        outcome.origin_id = link.origin_id;
        outcome.tp_r_multiple = trials[trial_index].tp_r_multiple;
        outcome.direction = trials[trial_index].direction;
        outcome.active = true;
        g_deep_pivot_outcomes[outcome_index].CopyFrom(outcome);
      }
    }
  }
  g_deep_pivot_events[total].terminal = !event_active;
  if(total + 1 > g_deep_pivot_event_peak)
    g_deep_pivot_event_peak = total + 1;
  if(parents_start + parent_count > g_deep_pivot_link_peak)
    g_deep_pivot_link_peak = parents_start + parent_count;
  if(parents_start + parent_count > g_deep_pivot_frozen_parent_peak)
    g_deep_pivot_frozen_parent_peak = parents_start + parent_count;
  if(trials_start + 3 > g_deep_pivot_trial_peak)
    g_deep_pivot_trial_peak = trials_start + 3;
  if(outcomes_start + parent_count * 3 > g_deep_pivot_outcome_peak)
    g_deep_pivot_outcome_peak = outcomes_start + parent_count * 3;
  RefreshDeepPivotTerminalFlags();
  if(!ReleaseTerminalDeepPivotState())
  {
    MarkDeepPivotStateFailed("DEEP_TERMINAL_RELEASE", event.identity.deep_event_id,
                            GetLastError());
    return false;
  }
  return true;
}

bool RefreshDeepPivotWindowForRuntime(const datetime observation_time)
{
  if(observation_time <= 0)
    return false;
  datetime current_open = iTime(_Symbol, Deep_Timeframe, 0);
  PivotFractalWindowState previous(g_deep_pivot_window);
  if(current_open > 0 && current_open <= observation_time &&
     previous.state == PIVOT_WINDOW_VALID && previous.levels.valid &&
     previous.active_bar_open > 0 &&
     previous.active_bar_open != current_open &&
     g_deep_pivot_window_terminal_exported_open !=
       previous.active_bar_open)
  {
    int deep_seconds = PeriodSeconds(previous.timeframe);
    datetime terminal_time = deep_seconds > 0
                             ? previous.active_bar_open + deep_seconds
                             : current_open;
    if(!PivotV13RecordWindow(previous, terminal_time, "EXPIRED"))
      return false;
    g_deep_pivot_window_terminal_exported_open = previous.active_bar_open;
  }
  return RefreshDeepPivotFractalWindow(observation_time);
}

void FinalizeDeepPivotWindowForExport()
{
  if(!PivotV13Enabled() ||
     g_deep_pivot_window.state != PIVOT_WINDOW_VALID ||
     !g_deep_pivot_window.levels.valid ||
     g_deep_pivot_window.active_bar_open <= 0 ||
     g_deep_pivot_window_terminal_exported_open ==
       g_deep_pivot_window.active_bar_open)
    return;
  datetime terminal_time = TimeCurrent();
  string terminal_status = "RUN_FINISHED";
  datetime current_open = iTime(_Symbol, Deep_Timeframe, 0);
  if(current_open > g_deep_pivot_window.active_bar_open &&
     current_open <= terminal_time)
  {
    int deep_seconds = PeriodSeconds(g_deep_pivot_window.timeframe);
    terminal_time = deep_seconds > 0
                    ? g_deep_pivot_window.active_bar_open + deep_seconds
                    : current_open;
    terminal_status = "EXPIRED";
  }
  if(PivotV13RecordWindow(g_deep_pivot_window,
                          terminal_time,
                          terminal_status))
  {
    g_deep_pivot_window_terminal_exported_open =
      g_deep_pivot_window.active_bar_open;
  }
}

void ProcessDeepPivotTick(const MqlTick &tick)
{
  if(!PivotV13Ready() || !PivotTrialQuoteValid(tick) ||
     DeepPivotResearchIntegrityFailed())
    return;

  // Parent terminal transitions are observed before any new M10 event is
  // admitted, so a same-tick parent exit censors only its own links.
  ResolveDeepPivotActiveOutcomes(tick);

  // Freeze eligible parents before discovering any M10 level. A later lane
  // entry cannot be linked retroactively to an already-triggered event.
  DeepPivotParentCandidate buy_parents[];
  DeepPivotParentCandidate sell_parents[];
  int buy_parent_count = CollectDeepPivotParentSnapshot(BULLISH,
                                                         tick.time,
                                                         buy_parents);
  int sell_parent_count = CollectDeepPivotParentSnapshot(BEARISH,
                                                          tick.time,
                                                          sell_parents);
  if(buy_parent_count < 0 || sell_parent_count < 0 ||
     (buy_parent_count <= 0 && sell_parent_count <= 0))
    return;
  if(!RefreshDeepPivotWindowForRuntime(tick.time))
    return;

  PivotTouchCandidate candidates[PIVOT_TOUCH_CANDIDATE_MAX];
  int total = DiscoverPivotTouchCandidatesFromWindow(g_deep_pivot_window,
                                                     tick,
                                                     candidates,
                                                     false);
  for(int i = 0; i < total; i++)
  {
    int parent_count = candidates[i].direction == BULLISH
                       ? buy_parent_count
                       : sell_parent_count;
    if(parent_count <= 0)
      continue;
    DeepPivotEvent event;
    if(!BuildDeepPivotEventFromCandidate(candidates[i],
                                         tick,
                                         parent_count,
                                         event))
      continue;
    if(!ConsumePivotTouchIdentity(g_deep_pivot_window,
                                  candidates[i].level_id))
      continue;
    bool appended = candidates[i].direction == BULLISH
                    ? AppendDeepPivotEvent(event, buy_parents, buy_parent_count)
                    : AppendDeepPivotEvent(event, sell_parents, sell_parent_count);
    if(!appended)
      MarkDeepPivotStateFailed("DEEP_EVENT_ADMISSION_FAILED", event.identity.deep_event_id);
  }
}

void FinalizeDeepPivotForExport()
{
  if(!Enable_Signal_Feature_Export)
    return;
  if(DeepPivotOutcomeCount() <= 0)
  {
    FinalizeDeepPivotWindowForExport();
    return;
  }
  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick) || !PivotTrialQuoteValid(tick))
  {
    // Preserve run-end censoring even when the terminal quote is unavailable.
    for(int i = 0; i < DeepPivotOutcomeCount(); i++)
    {
      if(!g_deep_pivot_outcomes[i].active)
        continue;
      int link_index = FindDeepPivotParentLink(
        g_deep_pivot_outcomes[i].parent_link_id);
      int event_index = link_index >= 0
                        ? FindDeepPivotEventById(
                            g_deep_pivot_parent_links[link_index].deep_event_id)
                        : -1;
      if(link_index < 0 || event_index < 0)
      {
        MarkDeepPivotStateFailed("DEEP_FINAL_QUOTE_ASSOCIATION",
                                g_deep_pivot_outcomes[i].deep_outcome_id);
        continue;
      }
      tick.time = TimeCurrent();
      tick.bid = g_deep_pivot_events[event_index].trigger_bid;
      tick.ask = g_deep_pivot_events[event_index].trigger_ask;
      break;
    }
    if(!PivotTrialQuoteValid(tick))
      return;
  }
  if(tick.time <= 0)
    tick.time = TimeCurrent();
  for(int i = 0; i < DeepPivotOutcomeCount(); i++)
  {
    if(!g_deep_pivot_outcomes[i].active)
      continue;
    int link_index = FindDeepPivotParentLink(
      g_deep_pivot_outcomes[i].parent_link_id);
    int trial_index = FindDeepPivotTrial(
      g_deep_pivot_outcomes[i].deep_trial_id);
    if(link_index < 0 || trial_index < 0)
    {
      MarkDeepPivotStateFailed("DEEP_FINAL_OUTCOME_ASSOCIATION",
                              g_deep_pivot_outcomes[i].deep_outcome_id);
      continue;
    }
    DeepPivotOutcome outcome;
    bool parent_closed =
      g_deep_pivot_parent_links[link_index].parent_terminal_time > 0;
    bool built = parent_closed
                 ? BuildDeepPivotParentExitOutcome(
                     g_deep_pivot_parent_links[link_index],
                     g_deep_pivot_trials[trial_index], tick, outcome)
                 : BuildDeepPivotRunEndOutcome(
                     g_deep_pivot_parent_links[link_index],
                     g_deep_pivot_trials[trial_index], tick, outcome);
    if(!built ||
       !PivotV13RecordDeepPivotOutcome(outcome) ||
       !QueueDeepPivotOutcomeForExport(outcome))
      continue;
    g_deep_pivot_outcomes[i].CopyFrom(outcome);
    g_deep_pivot_outcomes[i].active = false;
    g_deep_pivot_parent_links[link_index].link_status =
      parent_closed ? DEEP_PIVOT_LINK_PARENT_EXIT : DEEP_PIVOT_LINK_RUN_END;
  }
  RefreshDeepPivotTerminalFlags();
  if(!ReleaseTerminalDeepPivotState())
    MarkDeepPivotStateFailed("DEEP_TERMINAL_RELEASE", "", GetLastError());
  FinalizeDeepPivotWindowForExport();
}

#endif // _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_
