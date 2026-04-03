//+------------------------------------------------------------------+
//|                             market_signal_detection.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_

void AssignContextSnapshotToSignal(const StrategyContextIndicators &snapshot,
                                   SignalParams &signal)
{
  signal.base_structure_valid  = snapshot.structure_valid;
  signal.base_structure_data   = snapshot.structure_data;
}

void RefreshUpstreamTrendsOnBaseBar()
{
  return;
}

void EvaluateContextSignals(const StrategyContextTypes context)
{
  if(context != CONTEXT_SLOT_BASE && !StrategyContextEnabled(context))
    return;

  int runtime_slot = StrategyContextIndex(context);

  StrategyContextIndicators snapshot;
  snapshot.context   = context;
  snapshot.timeframe = StrategyContextTimeframe(context);
  snapshot.bar_time  = iTime(_Symbol, snapshot.timeframe, 0);
  if(snapshot.bar_time <= 0)
    return;

  if(g_context_runtime[runtime_slot].last_bar_time == snapshot.bar_time)
    return;

  if(!CaptureContextIndicators(context, snapshot))
    return;

  g_context_runtime[runtime_slot].last_bar_time = snapshot.bar_time;

  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int dir = 0; dir < 2; dir++)
  {
    SignalTypes direction = directions[dir];
    if(!DirectionAllowed(direction))
      continue;

    datetime structure_time = 0;
    bool entry_allows = false;
    bool filters_pass = false;
    double entry_price = 0.0;
    bool entry_is_limit = false;
    ResolvedFibonacciEntryAnchor resolved_entry;
    if(!StrategyContextEvaluateEntryDetailed(snapshot,
                                            direction,
                                            structure_time,
                                            entry_allows,
                                            filters_pass,
                                            entry_price,
                                            entry_is_limit,
                                            resolved_entry))
      return;

    bool cascade_pass = filters_pass;

    if(!cascade_pass)
      continue;

    if(!StrategyCascadeAllowsSignal(context, direction))
      continue;

    if(!entry_allows)
      continue;

    if(!CanAttemptSignal(direction))
      continue;

    datetime resolved_structure_time = structure_time;
    if(resolved_structure_time <= 0 && snapshot.structure_valid)
    {
      StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);
      resolved_structure_time = ResolveStructureSnapshotTimestamp(snapshot.structure_data,
                                                                  structure_ctx);
    }

    if(HasRunningSignalForStructure(context, direction, resolved_structure_time))
      continue;

    SignalParams signal;
    StructureTriggerEntryModes effective_trigger_mode = ResolveEffectiveStructureTriggerMode(context,
                                                                                              Structure_Trigger_Entry);
    signal.signal_type            = direction;
    signal.entry_time             = snapshot.bar_time;
    signal.entry_price            = entry_price;
    signal.strategy_context       = context;
    signal.strategy_timeframe     = snapshot.timeframe;
    signal.strategy_context_label = StrategyContextLabel(context);
    signal.entry_trigger_mode     = effective_trigger_mode;
    signal.entry_is_limit         = entry_is_limit;
    signal.resolved_fibonacci_entry = resolved_entry;
    signal.signal_lot_sequence_step = ResolveSignalLotSequenceStepForNewSignal();
    signal.context_structure_snapshot_time = resolved_structure_time;
    signal.grid_sequence_id       = BuildSignalSequenceId(direction,
                                                          signal.entry_time,
                                                          resolved_structure_time);
    AssignContextSnapshotToSignal(snapshot, signal);

    if(!BuildGridOrderForSignal(signal))
    {
      if(Enable_Logs)
        PrintFormat("Grid planning failed for %s context %s signal.",
                    EnumToString(direction),
                    signal.strategy_context_label);
      continue;
    }

    if(direction == BULLISH)
      AddElementToArray(running_bullish_signals, signal);
    else
      AddElementToArray(running_bearish_signals, signal);

    RegisterFreshStructureUsage(signal);
    RegisterDailySignalStart(signal);
  }
}

void DetectStrategySignals()
{
  int total = ArraySize(STRATEGY_CONTEXT_EVALUATION_ORDER);
  for(int i = 0; i < total; i++)
    EvaluateContextSignals(STRATEGY_CONTEXT_EVALUATION_ORDER[i]);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
