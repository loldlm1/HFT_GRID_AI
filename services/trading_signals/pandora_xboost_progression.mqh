//+------------------------------------------------------------------+
//|                  pandora_xboost_progression.mqh                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_PROGRESSION_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_PROGRESSION_MQH_

double PandoraXBoostResolveBranchAnchorPrice(const SignalParams &parent_signal,
                                             const SignalTypes candidate_side)
{
  double anchor = parent_signal.close_price;
  if(anchor <= 0.0)
    anchor = parent_signal.pandora_local_close_price;
  if(anchor <= 0.0)
    anchor = GridCurrentPriceForDirection(candidate_side, true);
  return anchor;
}

bool PandoraXBoostBuildLocalBranchSignal(const SignalParams &parent_signal,
                                         const SignalTypes candidate_side,
                                         const PandoraXBoostCloseEvents parent_event,
                                         const int next_depth,
                                         SignalParams &branch_signal)
{
  branch_signal.signal_type            = candidate_side;
  branch_signal.entry_time             = TimeCurrent();
  branch_signal.strategy_context       = CONTEXT_SLOT_BASE;
  branch_signal.strategy_timeframe     = Strategy_Timeframe;
  branch_signal.strategy_context_label = "PANDORA";
  branch_signal.entry_trigger_mode     = ENTRY_EVAL_OFF;
  branch_signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;
  branch_signal.pandora_first_entry_target_depth = PANDORA_FIRST_ENTRY_OFF_DEPTH;
  branch_signal.pandora_first_entry_observation_depth = 0;

  if(!BuildPandoraOrderForSignal(branch_signal))
    return false;

  double anchor = PandoraXBoostResolveBranchAnchorPrice(parent_signal, candidate_side);
  if(anchor <= 0.0)
    return false;

  branch_signal.entry_price = anchor;
  branch_signal.pandora_theoretical_entry_price = anchor;
  branch_signal.pandora_theoretical_entry_time = branch_signal.entry_time;
  branch_signal.pandora_execution_source = PANDORA_EXECUTION_SOURCE_THEORETICAL;
  branch_signal.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_PENDING;
  branch_signal.pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
  branch_signal.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;

  if(ArraySize(branch_signal.grid_orders) > 0)
  {
    branch_signal.grid_orders[0].entry_reference_price = anchor;
    branch_signal.grid_orders[0].entry_price = 0.0;
    branch_signal.grid_orders[0].position_ticket = 0;
    branch_signal.grid_orders[0].status = GRID_ORDER_STOP_TRAILING_ACTIVE;
  }

  string strategy_key = parent_signal.pandora_xboost_strategy_key;
  if(strategy_key == "")
    strategy_key = PandoraXBoostBuildStrategyKey();

  datetime root_date = g_pandora_xboost_root.root_date;
  if(root_date <= 0)
    root_date = g_pandora_box_state.day_anchor;
  if(root_date <= 0)
    root_date = ResolveCurrentDayStart();

  SignalTypes root_side = parent_signal.pandora_xboost_root_side;
  if(root_side == NO_SIGNAL)
    root_side = parent_signal.signal_type;

  string root_id = parent_signal.pandora_xboost_root_id;
  if(root_id == "")
    root_id = g_pandora_xboost_root.root_id;

  PandoraXBoostPrepareSignalMetadata(branch_signal,
                                     strategy_key,
                                     root_id,
                                     root_date,
                                     root_side,
                                     parent_event,
                                     next_depth,
                                     true,
                                     parent_signal.pandora_xboost_node_path);
  PandoraXBoostApplyBrokerDecision(branch_signal);
  return true;
}

bool PandoraXBoostAddLocalBranch(const SignalParams &parent_signal,
                                 const SignalTypes candidate_side,
                                 const PandoraXBoostCloseEvents parent_event,
                                 const int next_depth)
{
  SignalParams branch_signal;
  if(!PandoraXBoostBuildLocalBranchSignal(parent_signal,
                                          candidate_side,
                                          parent_event,
                                          next_depth,
                                          branch_signal))
    return false;

  if(candidate_side == BULLISH)
    AddElementToArray(running_bullish_signals, branch_signal);
  else if(candidate_side == BEARISH)
    AddElementToArray(running_bearish_signals, branch_signal);
  else
    return false;

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_LOCAL_BRANCH depth=%d id=%s node=%s",
                next_depth,
                branch_signal.pandora_xboost_display_id,
                branch_signal.pandora_xboost_node_key);
  }
  PandoraXBoostLogEvent("PANDORA_XBOOST_LOCAL_BRANCH",
                        StringFormat("depth=%d id=%s local=%s broker=%s node=%s",
                                     next_depth,
                                     branch_signal.pandora_xboost_display_id,
                                     branch_signal.pandora_xboost_local_only ? "1" : "0",
                                     branch_signal.pandora_xboost_broker_selected ? "1" : "0",
                                     branch_signal.pandora_xboost_node_key));
  return true;
}

bool PandoraXBoostAdvanceAfterClose(const SignalParams &closed_signal)
{
  if(!PandoraXBoostEnabled())
    return false;
  if(!closed_signal.pandora_xboost_enabled)
    return false;

  PandoraXBoostCloseEvents close_event = closed_signal.pandora_xboost_close_event;
  if(close_event == PANDORA_XBOOST_EVENT_NONE ||
     close_event == PANDORA_XBOOST_EVENT_FORCE_CLOSE)
    return false;

  int current_depth = closed_signal.pandora_xboost_depth;
  if(current_depth <= 0)
    current_depth = 1;

  int max_depth = PandoraXBoostClampDepth(Pandora_XBoost_Max_Depth);
  int next_depth = current_depth + 1;
  if(next_depth > max_depth)
    return false;

  g_pandora_xboost_root.active = true;
  g_pandora_xboost_root.current_depth = next_depth;
  g_pandora_xboost_root.last_event = close_event;
  PandoraXBoostBuildNextCandidatesFromClosedSignal(closed_signal,
                                                   close_event,
                                                   next_depth);

  bool bullish_added = PandoraXBoostAddLocalBranch(closed_signal,
                                                   BULLISH,
                                                   close_event,
                                                   next_depth);
  bool bearish_added = PandoraXBoostAddLocalBranch(closed_signal,
                                                   BEARISH,
                                                   close_event,
                                                   next_depth);
  return bullish_added || bearish_added;
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_PROGRESSION_MQH_
