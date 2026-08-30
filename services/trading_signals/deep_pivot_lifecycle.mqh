//+------------------------------------------------------------------+
//|                    trading_signals/deep_pivot_lifecycle         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_

const int DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE = 64;

DeepPivotEvent g_deep_pivot_events[];
DeepPivotFrozenParent g_deep_pivot_frozen_parents[];
int g_deep_pivot_event_peak = 0;
int g_deep_pivot_link_peak = 0;
int g_deep_pivot_duplicate_identity_count = 0;
int g_deep_pivot_capacity_rejected_count = 0;
bool g_deep_pivot_state_capacity_failed = false;
bool g_deep_pivot_state_allocation_failed = false;

string DeepPivotWindowId(const ENUM_TIMEFRAMES timeframe,
                         const datetime active_bar_open)
{
  if(timeframe == PERIOD_CURRENT || active_bar_open <= 0)
    return "";
  return "deep_window_" + EnumToString(timeframe) + "_" +
         StringFormat("%I64d", active_bar_open);
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
  g_deep_pivot_event_peak = 0;
  g_deep_pivot_link_peak = 0;
  g_deep_pivot_duplicate_identity_count = 0;
  g_deep_pivot_capacity_rejected_count = 0;
  g_deep_pivot_state_capacity_failed = false;
  g_deep_pivot_state_allocation_failed = resized != 0 || parent_resized != 0;
}

int DeepPivotEventCount()
{
  return ArraySize(g_deep_pivot_events);
}

int DeepPivotEventPeak()
{
  return g_deep_pivot_event_peak;
}

int DeepPivotEventCapacityRejectedCount()
{
  return g_deep_pivot_capacity_rejected_count;
}

int DeepPivotFrozenParentCount()
{
  return ArraySize(g_deep_pivot_frozen_parents);
}

int DeepPivotFrozenParentPeak()
{
  return g_deep_pivot_link_peak;
}

int DeepPivotFrozenParentCountForEvent(const string deep_event_id)
{
  int count = 0;
  for(int i = 0; i < DeepPivotFrozenParentCount(); i++)
    if(g_deep_pivot_frozen_parents[i].deep_event_id == deep_event_id)
      count++;
  return count;
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
    g_deep_pivot_state_allocation_failed = true;
    return 0;
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
      break;
    }
    if(ArrayResize(parents,
                   total + 1,
                   DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
    {
      g_deep_pivot_state_allocation_failed = true;
      break;
    }
    parents[total].CopyFrom(candidate);
    total++;
  }

  // Broker parents are admitted only after a confirmed fill. The parity
  // shadow is deliberately not used as a proxy for broker exposure.
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    PivotSignal &signal = g_pivot_signals[i];
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
      break;
    }
    if(ArrayResize(parents,
                   total + 1,
                   DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
    {
      g_deep_pivot_state_allocation_failed = true;
      break;
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
    return false;
  }
  if(DeepPivotEventCount() >= PIVOT_DEEP_EVENT_ACTIVE_CAP ||
     DeepPivotFrozenParentCount() + parent_count >
       PIVOT_DEEP_LINK_ACTIVE_CAP)
  {
    g_deep_pivot_capacity_rejected_count++;
    return false;
  }
  int total = DeepPivotEventCount();
  if(ArrayResize(g_deep_pivot_events,
                 total + 1,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) != total + 1)
  {
    g_deep_pivot_state_allocation_failed = true;
    return false;
  }
  int parent_start = DeepPivotFrozenParentCount();
  if(ArrayResize(g_deep_pivot_frozen_parents,
                 parent_start + parent_count,
                 DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE) !=
     parent_start + parent_count)
  {
    ArrayResize(g_deep_pivot_events,
                total,
                DEEP_PIVOT_PARENT_SNAPSHOT_RESERVE);
    g_deep_pivot_state_allocation_failed = true;
    return false;
  }
  g_deep_pivot_events[total].CopyFrom(event);
  for(int i = 0; i < parent_count; i++)
  {
    g_deep_pivot_frozen_parents[parent_start + i].deep_event_id =
      event.identity.deep_event_id;
    g_deep_pivot_frozen_parents[parent_start + i].parent.CopyFrom(parents[i]);
  }
  if(total + 1 > g_deep_pivot_event_peak)
    g_deep_pivot_event_peak = total + 1;
  if(parent_start + parent_count > g_deep_pivot_link_peak)
    g_deep_pivot_link_peak = parent_start + parent_count;
  return true;
}

void ProcessDeepPivotTick(const MqlTick &tick)
{
  if(!Enable_Signal_Feature_Export || !PivotTrialQuoteValid(tick) ||
     DeepPivotResearchIntegrityFailed())
    return;

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
  if(buy_parent_count <= 0 && sell_parent_count <= 0)
    return;
  if(!RefreshDeepPivotFractalWindow(tick.time))
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
    if(candidates[i].direction == BULLISH)
      AppendDeepPivotEvent(event, buy_parents, buy_parent_count);
    else
      AppendDeepPivotEvent(event, sell_parents, sell_parent_count);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_LIFECYCLE_MQH_
