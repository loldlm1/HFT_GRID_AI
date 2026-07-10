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

bool DeterministicRawEntryGeometryValid(const SignalTypes direction,
                                        const double trigger_price,
                                        const double stop_anchor_price)
{
  if(trigger_price <= 0.0 || stop_anchor_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return (trigger_price > stop_anchor_price);
  if(direction == BEARISH)
    return (trigger_price < stop_anchor_price);

  return false;
}

string DeterministicTimeToken(const datetime value)
{
  if(value <= 0)
    return "n/a";

  return TimeToString(value, TIME_DATE|TIME_SECONDS);
}

string DeterministicExtremumSummary(const string prefix,
                                    const DeterministicExtremumSnapshot &extremum)
{
  return StringFormat("%s_valid=%s|%s_slot=%d|%s_confirmed=%s|%s_type=%s|%s_time=%s|%s_price=%.5f|%s_high=%.5f|%s_low=%.5f",
                      prefix,
                      DeterministicBoolToken(extremum.valid),
                      prefix,
                      extremum.source_slot,
                      prefix,
                      DeterministicBoolToken(extremum.confirmed),
                      prefix,
                      DeterministicExtremumTypeToken(extremum),
                      prefix,
                      DeterministicTimeToken(extremum.extremum_time),
                      prefix,
                      extremum.extremum_price,
                      prefix,
                      extremum.extremum_high,
                      prefix,
                      extremum.extremum_low);
}

void LogDeterministicSourceAudit(const StochasticMarketStructure &structure,
                                 const DeterministicExtremumSnapshot &selected)
{
  DeterministicExtremumSnapshot current;
  ResolveCurrentDeterministicExtremum(structure, current);

  DeterministicExtremumSnapshot confirmed;
  ResolveLatestConfirmedDeterministicExtremum(structure, confirmed);

  string message = DeterministicExtremumSummary("selected", selected) + "|" +
                   DeterministicExtremumSummary("current", current) + "|" +
                   DeterministicExtremumSummary("confirmed", confirmed);

  ExecutionAppendQueryDebugChangedLog("DETERMINISTIC_SOURCE_AUDIT",
                                      "BASE",
                                      message);
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
    ResolvedStructureEntryAnchor resolved_entry;
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
                                                                                              FOUNDATION_STRUCTURE_TRIGGER_MODE);
    signal.signal_type            = direction;
    signal.entry_time             = snapshot.bar_time;
    signal.entry_price            = entry_price;
    signal.strategy_context       = context;
    signal.strategy_timeframe     = snapshot.timeframe;
    signal.strategy_context_label = StrategyContextLabel(context);
    signal.entry_trigger_mode     = effective_trigger_mode;
    signal.entry_is_limit         = entry_is_limit;
    signal.resolved_structure_entry = resolved_entry;
    signal.signal_lot_sequence_step = ResolveSignalLotSequenceStepForNewSignal();
    signal.context_structure_snapshot_time = resolved_structure_time;
    signal.execution_sequence_id       = BuildSignalSequenceId(direction,
                                                          signal.entry_time,
                                                          resolved_structure_time);
    AssignContextSnapshotToSignal(snapshot, signal);

    if(!BuildExecutionLegForSignal(signal))
    {
      if(Enable_Logs)
        PrintFormat("Execution planning failed for %s context %s signal.",
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

bool PopulateExtremumEngineSignal(const int engine_id,
                                 const SignalTypes direction,
                                 const DeterministicExtremumSnapshot &extremum,
                                 const StochasticMarketStructure &structure,
                                 SignalParams &signal)
{
  signal = SignalParams();
  signal.signal_type                = direction;
  signal.signal_state               = WAITING;
  signal.engine_id                  = engine_id;
  signal.engine_label               = ExtremumEngineLabel(engine_id);
  signal.engine_timeframe           = ExtremumEngineTimeframe(engine_id);
  signal.deterministic_strategy     = true;
  signal.entry_time                 = TimeCurrent();
  signal.strategy_context           = CONTEXT_SLOT_BASE;
  signal.strategy_timeframe         = signal.engine_timeframe;
  signal.strategy_context_label     = signal.engine_label;
  signal.entry_trigger_mode         = LEVELS_AS_LIMITS;
  signal.entry_is_limit             = false;
  signal.signal_lot_sequence_step   = ResolveSignalLotSequenceStepForNewSignal();
  signal.context_structure_snapshot_time = extremum.extremum_time;
  signal.source_extremum_time       = extremum.extremum_time;
  signal.source_extremum_slot       = extremum.source_slot;
  signal.source_extremum_confirmed  = extremum.confirmed;
  signal.source_extremum_is_peak    = extremum.is_peak;
  signal.source_extremum_price      = extremum.extremum_price;
  signal.source_extremum_high       = extremum.extremum_high;
  signal.source_extremum_low        = extremum.extremum_low;
  signal.raw_stop_anchor_price      = extremum.extremum_price;
  signal.base_structure_valid       = true;
  signal.base_structure_data        = structure;

  double high_1 = iHigh(_Symbol, signal.engine_timeframe, 1);
  double low_1  = iLow(_Symbol, signal.engine_timeframe, 1);
  if(high_1 <= 0.0 || low_1 <= 0.0)
    return false;

  signal.raw_entry_trigger_price = (direction == BULLISH) ? high_1 : low_1;
  signal.entry_price             = signal.raw_entry_trigger_price;
  signal.stop_loss               = signal.raw_stop_anchor_price;
  signal.execution_sequence_id   = BuildExtremumEngineSignalSequenceId(engine_id,
                                                                        direction,
                                                                        signal.entry_time,
                                                                        extremum.extremum_time);
  return true;
}

void LogDeterministicCandidateTelemetry(const SignalParams &signal,
                                        const DeterministicExtremumSnapshot &extremum)
{
  string direction = (signal.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string source_key = signal.deterministic_source_key;
  if(source_key == "")
    source_key = BuildExtremumEngineSignalSourceKey(signal);

  string message = StringFormat("engine=%s|dir=%s|cycle_id=%s|revision_id=%s|attempt_id=%s|cycle_attempt_index=%d|revision_attempt_index=%d|depth=%.4f|range_points=%.2f|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|trigger=%.5f|stop=%.5f",
                                 signal.engine_label,
                                 direction,
                                 signal.extremum_cycle_id,
                                 signal.extremum_revision_id,
                                 signal.extremum_attempt_id,
                                 signal.cycle_attempt_index,
                                 signal.revision_attempt_index,
                                 signal.candidate_depth_percent,
                                 signal.reference_range_points,
                                 source_key,
                                 signal.deterministic_source_attempt_index,
                                extremum.source_slot,
                                DeterministicBoolToken(extremum.confirmed),
                                DeterministicExtremumTypeToken(extremum),
                                DeterministicTimeToken(extremum.extremum_time),
                                extremum.extremum_price,
                                extremum.extremum_high,
                                extremum.extremum_low,
                                signal.raw_entry_trigger_price,
                                signal.raw_stop_anchor_price);

  ExecutionAppendQueryDebugLog("DETERMINISTIC_CANDIDATE", message);
}

void TryCreateExtremumEngineSignal(const SignalTypes direction,
                                  const DeterministicExtremumSnapshot &extremum,
                                  const StochasticMarketStructure &structure)
{
  const int engine_id = EXTREMUM_ENGINE_V1;

  if(!DirectionAllowed(direction))
    return;

  int consumed_attempt_count = 0;
  string consumed_terminal_outcome = "";
  datetime consumed_time = 0;
  if(ResolveDeterministicSourceConsumedAfterTp(engine_id,
                                               direction,
                                               extremum.source_slot,
                                               extremum.extremum_time,
                                               extremum.is_peak,
                                               extremum.extremum_price,
                                               consumed_attempt_count,
                                               consumed_terminal_outcome,
                                               consumed_time))
  {
    ExecutionLogDeterministicSourceReentryBlocked(engine_id,
                                                  direction,
                                                  extremum.source_slot,
                                                  extremum.confirmed,
                                                  extremum.is_peak,
                                                  extremum.extremum_time,
                                                  extremum.extremum_price,
                                                  extremum.extremum_high,
                                                  extremum.extremum_low,
                                                  consumed_attempt_count,
                                                  consumed_terminal_outcome,
                                                  consumed_time);
    return;
  }

  if(HasRunningDeterministicSignal(engine_id,
                                   direction,
                                   extremum.source_slot,
                                   extremum.extremum_time,
                                   extremum.is_peak,
                                   extremum.extremum_price))
    return;

  if(!CanAttemptSignal(direction))
    return;

  SignalParams signal;
  if(!PopulateExtremumEngineSignal(engine_id,
                                   direction,
                                   extremum,
                                   structure,
                                   signal))
    return;

  signal.deterministic_source_key = BuildExtremumEngineSignalSourceKey(signal);
  signal.admission_status = EXECUTION_ADMISSION_CANDIDATE;
  signal.admission_updated_time = TimeCurrent();
  if(!DeterministicRawEntryGeometryValid(direction,
                                         signal.raw_entry_trigger_price,
                                         signal.raw_stop_anchor_price))
  {
    int next_attempt_index =
      ResolveDeterministicSourceAttemptCount(signal.deterministic_source_key) + 1;
    ExecutionLogDeterministicInvalidCandidate(signal,
                                              next_attempt_index,
                                              "invalid_raw_entry_geometry");
    return;
  }

  if(RegisterDeterministicSourceAttempt(signal) <= 0)
    return;
  if(!ExtremumEngineAssignAttemptIdentity(signal))
    return;

  DeterministicSignalStatsRecordAdmissionEvent(signal, "candidate");

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, signal);
  else
    AddElementToArray(running_bearish_signals, signal);

  RegisterDailySignalStart(signal);
  LogDeterministicCandidateTelemetry(signal, extremum);

  if(Enable_Logs)
  {
    PrintFormat("EXTREMUM_ENGINE_CANDIDATE | engine=%s | direction=%s | source_slot=%d | source_type=%s | extremum=%s | trigger=%.5f",
                signal.engine_label,
                EnumToString(direction),
                extremum.source_slot,
                DeterministicExtremumTypeToken(extremum),
                TimeToString(extremum.extremum_time, TIME_DATE|TIME_MINUTES),
                signal.raw_entry_trigger_price);
  }
}

void DetectExtremumEngineSignals()
{
  StochasticMarketStructure structure;
  if(!LoadStructureSnapshotForTimeframe(EXTREMUM_ENGINE_TIMEFRAME, structure))
    return;

  DeterministicExtremumSnapshot extremum;
  if(!ResolveCurrentDeterministicExtremum(structure, extremum))
    return;

  bool cycle_started = false;
  bool revision_created = false;
  bool cycle_finalized = false;
  if(!ExtremumEngineObserve(structure,
                            extremum,
                            cycle_started,
                            revision_created,
                            cycle_finalized))
    return;

  if(revision_created)
  {
    ExtremumEngineRevisionState revision = g_extremum_engine_cycle.current_revision;
    string cycle_message = StringFormat("cycle_id=%s|revision_id=%s|revision_index=%d|type=%s|depth=%.4f|range_points=%.2f|from_first_points=%.2f|from_previous_points=%.2f|depth_delta=%.4f|bars_since_start=%d|cycle_started=%s|prior_cycle_finalized=%s",
                                        g_extremum_engine_cycle.cycle_id,
                                        revision.revision_id,
                                        revision.revision_index,
                                        extremum.is_peak ? "PEAK" : "BOTTOM",
                                        revision.depth_percent_raw,
                                        g_extremum_engine_cycle.reference_range_points,
                                        revision.distance_from_first_points,
                                        revision.distance_from_previous_points,
                                        revision.depth_delta_from_previous_percent,
                                        revision.bars_since_cycle_start,
                                        cycle_started ? "true" : "false",
                                        cycle_finalized ? "true" : "false");
    ExecutionAppendQueryDebugChangedLog("EXTREMUM_ENGINE_REVISION",
                                        revision.revision_id,
                                        cycle_message);
  }

  LogDeterministicSourceAudit(structure, extremum);
  ExpirePendingDeterministicSignalsForSourceExtremum(extremum.source_slot,
                                                     extremum.extremum_time,
                                                     extremum.is_peak,
                                                     extremum.extremum_price);

  SignalTypes direction = extremum.is_peak ? BEARISH : BULLISH;
  TryCreateExtremumEngineSignal(direction, extremum, structure);
}

void DetectStrategySignals()
{
  DetectExtremumEngineSignals();
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
