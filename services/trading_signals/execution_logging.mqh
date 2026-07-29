//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... logging      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_

#include "execution_leg_helpers.mqh"

const string QUERY_DEBUG_FILENAME = "query_debug.txt";
const int QUERY_DEBUG_STATE_RESERVE = 64;
const int QUERY_DEBUG_THROTTLE_RESERVE = 64;
const int QUERY_DEBUG_ENTRY_CONFIRM_THROTTLE_SECONDS = 60;
const int QUERY_DEBUG_ENTRY_ANCHOR_BLOCKED_THROTTLE_SECONDS = 60;
const int QUERY_DEBUG_GUARDRAIL_THROTTLE_SECONDS = 60;
const int QUERY_DEBUG_STATE_MAX = 512;
bool g_query_debug_session_header_logged = false;
string g_query_debug_state_keys[];
string g_query_debug_state_messages[];
string g_query_debug_throttle_keys[];
datetime g_query_debug_throttle_times[];
int g_query_debug_throttle_suppressed[];
int g_query_debug_state_replace_index = 0;
int g_query_debug_throttle_replace_index = 0;

string ExecutionBoolToken(const bool value)
{
  return value ? "true" : "false";
}

string ExecutionMLInferenceModeToken(const MLInferenceModes mode)
{
  switch(mode)
  {
    case ML_INFERENCE_SHADOW:
      return "SHADOW";
    case ML_INFERENCE_FILTER:
      return "FILTER";
  }
  return "DISABLED";
}

void ResetQueryDebugLogSession()
{
  CloseAppendFileLog();
  g_query_debug_session_header_logged = false;
  ArrayResize(g_query_debug_state_keys, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_state_messages, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_throttle_keys, 0, QUERY_DEBUG_THROTTLE_RESERVE);
  ArrayResize(g_query_debug_throttle_times, 0, QUERY_DEBUG_THROTTLE_RESERVE);
  ArrayResize(g_query_debug_throttle_suppressed, 0, QUERY_DEBUG_THROTTLE_RESERVE);
  g_query_debug_state_replace_index = 0;
  g_query_debug_throttle_replace_index = 0;
}

void ExecutionAppendRawQueryDebugLine(const string line)
{
  AppendFileLog(QUERY_DEBUG_FILENAME, line);
}

void ExecutionAppendTimestampedQueryDebug(const string label,
                                     const string message)
{
  AppendTimestampedLog(QUERY_DEBUG_FILENAME, label, message);
}

string ExecutionQueryDebugSignalKey(const SignalParams &signal_params)
{
  if(signal_params.execution_sequence_id != "")
    return signal_params.execution_sequence_id;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string time_token = TimeToString(signal_params.entry_time, TIME_DATE|TIME_SECONDS);
  return direction + "|" + time_token;
}

int ExecutionFindQueryDebugStateIndex(const string state_key)
{
  int total = ArraySize(g_query_debug_state_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_query_debug_state_keys[i] == state_key)
      return i;
  }
  return -1;
}

bool ExecutionShouldLogChangedState(const string state_key,
                               const string message)
{
  int index = ExecutionFindQueryDebugStateIndex(state_key);
  if(index < 0)
  {
    int total = ArraySize(g_query_debug_state_keys);
    if(total < QUERY_DEBUG_STATE_MAX)
    {
      ArrayResize(g_query_debug_state_keys, total + 1, QUERY_DEBUG_STATE_RESERVE);
      ArrayResize(g_query_debug_state_messages, total + 1, QUERY_DEBUG_STATE_RESERVE);
      index = total;
    }
    else
    {
      index = g_query_debug_state_replace_index;
      g_query_debug_state_replace_index =
        (g_query_debug_state_replace_index + 1) % QUERY_DEBUG_STATE_MAX;
    }
    g_query_debug_state_keys[index] = state_key;
    g_query_debug_state_messages[index] = message;
    return true;
  }

  if(g_query_debug_state_messages[index] == message)
    return false;

  g_query_debug_state_messages[index] = message;
  return true;
}

int ExecutionFindQueryDebugThrottleIndex(const string state_key)
{
  int total = ArraySize(g_query_debug_throttle_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_query_debug_throttle_keys[i] == state_key)
      return i;
  }
  return -1;
}

bool ExecutionShouldLogThrottledState(const string state_key,
                                      const int throttle_seconds,
                                      int &suppressed_since_last)
{
  suppressed_since_last = 0;
  if(throttle_seconds <= 0)
    return true;

  datetime now = TimeCurrent();
  int index = ExecutionFindQueryDebugThrottleIndex(state_key);
  if(index < 0)
  {
    int total = ArraySize(g_query_debug_throttle_keys);
    if(total < QUERY_DEBUG_STATE_MAX)
    {
      ArrayResize(g_query_debug_throttle_keys,
                  total + 1,
                  QUERY_DEBUG_THROTTLE_RESERVE);
      ArrayResize(g_query_debug_throttle_times,
                  total + 1,
                  QUERY_DEBUG_THROTTLE_RESERVE);
      ArrayResize(g_query_debug_throttle_suppressed,
                  total + 1,
                  QUERY_DEBUG_THROTTLE_RESERVE);
      index = total;
    }
    else
    {
      index = g_query_debug_throttle_replace_index;
      g_query_debug_throttle_replace_index =
        (g_query_debug_throttle_replace_index + 1) % QUERY_DEBUG_STATE_MAX;
    }
    g_query_debug_throttle_keys[index] = state_key;
    g_query_debug_throttle_times[index] = now;
    g_query_debug_throttle_suppressed[index] = 0;
    return true;
  }

  int elapsed_seconds = (int)(now - g_query_debug_throttle_times[index]);
  if(elapsed_seconds >= throttle_seconds)
  {
    suppressed_since_last = g_query_debug_throttle_suppressed[index];
    g_query_debug_throttle_times[index] = now;
    g_query_debug_throttle_suppressed[index] = 0;
    return true;
  }

  g_query_debug_throttle_suppressed[index]++;
  return false;
}

string ExecutionExtremumEngineDescriptor()
{
  return StringFormat("%s(timeframe=%s,source=slot_0)",
                      ExtremumEngineLabel(EXTREMUM_ENGINE_V1),
                      EnumToString(EXTREMUM_ENGINE_TIMEFRAME));
}

void EnsureQueryDebugSessionHeaderLogged()
{
  if(!Enable_File_Logs || g_query_debug_session_header_logged)
    return;

  g_query_debug_session_header_logged = true;
  ExecutionAppendRawQueryDebugLine("");

  double point_size = g_symbol_constraints.point_size;
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  ExecutionAppendTimestampedQueryDebug("QUERY_DEBUG_SESSION",
                                  StringFormat("symbol=%s|period=%s|point=%.5f|digits=%d|spread_pts=%.1f|spread_raw=%.5f|broker_session=%s",
                                               _Symbol,
                                               EnumToString(_Period),
                                               point_size,
                                               Digits(),
                                               g_points_spread,
                                               g_local_spread,
                                               MarketDataTimePolicyToken(Broker_Session)));

  ExecutionAppendTimestampedQueryDebug("INPUTS_ENGINE",
                                  StringFormat("engine=%s|tf=%s|stoch_period=%d|direction=STRUCTURAL|concurrency=UNRESTRICTED",
                                               ExecutionExtremumEngineDescriptor(),
                                               EnumToString(EXTREMUM_ENGINE_TIMEFRAME),
                                               Stoch_Structure_Period_Type));

  ExecutionAppendTimestampedQueryDebug("FOUNDATION_STRUCTURE",
                                  StringFormat("levels=%s|trigger=%s",
                                               FOUNDATION_STRUCTURE_FIBONACCI_LEVELS,
                                               EnumToString(FOUNDATION_STRUCTURE_TRIGGER_MODE)));

  ExecutionAppendTimestampedQueryDebug("INPUTS_EXECUTION",
                                  StringFormat("base=%s|points_range=%.1f|execution_mult=%.2f|level_start=%d|stop_limit=%d|lot_type=%s|lot_size=%.2f",
                                               EnumToString(Strategy_Range_Mode),
                                               Strategy_Range_Points,
                                               ResolveFoundationLevelExponentialMultiplier(),
                                               ResolveFoundationLevelPositionStart(),
                                               ResolveFoundationLevelStopLimit(),
                                               EnumToString(Lot_Type),
                                               Lot_Strategy_Size));

  ExecutionAppendTimestampedQueryDebug("INPUTS_ML",
                                  StringFormat("mode=%s|export_id=%s|artifact_root=%s|policy=shadow_fail_open",
                                               ExecutionMLInferenceModeToken(ML_Inference_Mode),
                                               ML_Model_Export_Id,
                                               "DeterministicSignalML\\model_exports"));
}

void ExecutionAppendQueryDebugLog(const string label,
                             const string message)
{
  if(!Enable_File_Logs)
    return;

  EnsureQueryDebugSessionHeaderLogged();
  ExecutionAppendTimestampedQueryDebug(label, message);
}

void ExecutionAppendQueryDebugChangedLog(const string label,
                                    const string state_key,
                                    const string message)
{
  if(!Enable_File_Logs)
    return;

  EnsureQueryDebugSessionHeaderLogged();
  if(!ExecutionShouldLogChangedState(label + "|" + state_key, message))
    return;

  ExecutionAppendTimestampedQueryDebug(label, message);
}

void ExecutionAppendQueryDebugThrottledLog(const string label,
                                           const string state_key,
                                           const string message,
                                           const int throttle_seconds)
{
  if(!Enable_File_Logs)
    return;

  EnsureQueryDebugSessionHeaderLogged();

  int suppressed_since_last = 0;
  if(!ExecutionShouldLogThrottledState(label + "|" + state_key,
                                       throttle_seconds,
                                       suppressed_since_last))
    return;

  string throttled_message = message;
  if(suppressed_since_last > 0)
  {
    throttled_message = throttled_message +
                        StringFormat("|suppressed_since_last=%d",
                                     suppressed_since_last);
  }

  ExecutionAppendTimestampedQueryDebug(label, throttled_message);
}

string ExecutionFormatDoubleOrToken(const bool valid,
                               const double value,
                               const int digits)
{
  if(!valid)
    return "n/a";
  return DoubleToString(value, digits);
}

string ExecutionStructureTypeToken(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HH:
      return "HH";
    case OSCILLATOR_STRUCTURE_HL:
      return "HL";
    case OSCILLATOR_STRUCTURE_LH:
      return "LH";
    case OSCILLATOR_STRUCTURE_LL:
      return "LL";
    default:
      return "EQ";
  }
}

string ExecutionComposeStructureSequence(const OscillatorStructureTypes first,
                                    const OscillatorStructureTypes second,
                                    const OscillatorStructureTypes third,
                                    const OscillatorStructureTypes fourth)
{
  return StringFormat("%s,%s,%s,%s",
                      ExecutionStructureTypeToken(first),
                      ExecutionStructureTypeToken(second),
                      ExecutionStructureTypeToken(third),
                      ExecutionStructureTypeToken(fourth));
}

string ExecutionResolveCurrentSignalStructureSequence(const SignalParams &signal_params)
{
  StochasticMarketStructure structure;
  if(!ResolveSignalStructureSnapshot(signal_params, structure))
    return "n/a";

  return ExecutionComposeStructureSequence(structure.first_structure_type,
                                      structure.second_structure_type,
                                      structure.third_structure_type,
                                      structure.fourth_structure_type);
}

string ExecutionResolveStructureAuditSummary(const SignalParams &signal_params)
{
  return ExecutionResolveCurrentSignalStructureSequence(signal_params);
}

bool ExecutionShouldPrintTerminalEvent(const string label)
{
  return (label == "SIGNAL_INIT" ||
          label == "LEVEL_REACHED" ||
          label == "LEVEL_TP_HIT" ||
          label == "EXECUTION_STOP_LEVEL_LIMIT" ||
          label == "LEVEL_ACTIVATION_FAILED_TARGET_LOT" ||
          label == "LEVEL_ACTIVATION_FAILED_SEND" ||
          label == "LIMIT_EXPIRED_STRUCTURE");
}

string ExecutionBuildLegResolutionSummary(const SignalParams &signal_params,
                                       const ExecutionLegState &leg_state)
{
  if(!StrategyRangeUsesStructure())
  {
    double distance_points = ResolveExecutionLegDistancePoints(signal_params, leg_state);
    return StringFormat("source=%s|next=%.5f|entry_ref=%.5f|distance_pts=%.2f",
                        EnumToString(Strategy_Range_Mode),
                        leg_state.next_level_price,
                        leg_state.entry_reference_price,
                        distance_points);
  }

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.execution_entry_reference_price;
  if(entry_price <= 0.0)
    entry_price = leg_state.entry_reference_price;
  if(entry_price <= 0.0)
  {
    return StringFormat("source=STRUCTURE|resolved=false|reason=entry_price|next=%.5f",
                        leg_state.next_level_price);
  }

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  double entry_percent = 0.0;
  double band_lower = 0.0;
  double band_upper = 0.0;
  double resolved_entry_percent = 0.0;
  double resolved_entry_price = 0.0;
  bool band_target_used = false;
  bool entry_ok = ResolveStructureRangeCanonicalEntryContext(signal_params,
                                                        entry_price,
                                                        entry_percent,
                                                        band_lower,
                                                        band_upper,
                                                        resolved_entry_percent,
                                                        resolved_entry_price,
                                                        peak_price,
                                                        bottom_price,
                                                        current_is_bottom,
                                                        band_target_used);
  if(!entry_ok)
  {
    return StringFormat("source=STRUCTURE|resolved=false|reason=entry_percent|entry=%.5f|next=%.5f",
                        entry_price,
                        leg_state.next_level_price);
  }

  double level_percent = 0.0;
  bool level_percent_ok = ResolveStructureExecutionLevelPercent(signal_params,
                                                           leg_state.level_index,
                                                           level_percent);
  double structure_level_price = 0.0;
  bool level_price_ok = ResolveStructureExecutionLevelPrice(signal_params,
                                                       leg_state.level_index,
                                                       structure_level_price);
  string band_label = "n/a";
  if(band_lower != 0.0 || band_upper != 0.0)
    band_label = StringFormat("%.2f-%.2f", band_lower, band_upper);

  string next_source = "LOGICAL";
  if(level_price_ok && leg_state.next_level_price > 0.0)
  {
    double next_gap_points = ExecutionAbsolutePriceDistancePoints(leg_state.next_level_price,
                                                             structure_level_price);
    if(next_gap_points > 0.1)
      next_source = "BROKER_SAFE";
  }

  int structure_steps = signal_params.structure_range_step_offset + leg_state.level_index;
  if(structure_steps <= 0)
    structure_steps = 1;

  string entry_anchor_source = "RAW";
  if(SignalHasResolvedStructureEntryAnchor(signal_params))
    entry_anchor_source = "SIGNAL";
  else if(band_target_used)
    entry_anchor_source = "INFERRED";

  return StringFormat("source=STRUCTURE|resolved=%s|entry=%.5f|entry_pct=%s|entry_band=%s|resolved_entry_pct=%s|resolved_entry_price=%s|entry_anchor_src=%s|level_pct=%s|logical_next_price=%s|emitted_next_price=%.5f|next_src=%s|structure_steps=%d|peak=%.5f|bottom=%.5f|current_is_bottom=%s",
                      ExecutionBoolToken(level_percent_ok && level_price_ok),
                      entry_price,
                      ExecutionFormatDoubleOrToken(true, entry_percent, 2),
                      band_label,
                      ExecutionFormatDoubleOrToken(band_target_used, resolved_entry_percent, 2),
                      ExecutionFormatDoubleOrToken(band_target_used, resolved_entry_price, 5),
                      entry_anchor_source,
                      ExecutionFormatDoubleOrToken(level_percent_ok, level_percent, 2),
                      ExecutionFormatDoubleOrToken(level_price_ok, structure_level_price, 5),
                      leg_state.next_level_price,
                      next_source,
                      structure_steps,
                      peak_price,
                      bottom_price,
                      ExecutionBoolToken(current_is_bottom));
}

void ExecutionLogLegResolutionContext(const string label,
                                   const SignalParams &signal_params,
                                   const ExecutionLegState &leg_state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("dir=%s|L%d|%s",
                                direction,
                                display_level,
                                ExecutionBuildLegResolutionSummary(signal_params, leg_state));
  ExecutionAppendQueryDebugLog(label, message);
}

void ExecutionLogNextLegTriggerDecision(const SignalParams &signal_params,
                                     const ExecutionLegState &leg_state,
                                     const SignalTypes direction)
{
  string direction_label = (direction == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  double entry_side_price = ExecutionCurrentPriceForDirection(direction, true);
  double reference_price = leg_state.entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.entry_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.execution_entry_reference_price;

  string message = StringFormat("dir=%s|L%d|entry_side=%.5f|next=%.5f|entry_ref=%.5f|limit_armed=%s|breakout=%s|spread_pts=%.1f",
                                direction_label,
                                display_level,
                                entry_side_price,
                                leg_state.next_level_price,
                                reference_price,
                                ExecutionBoolToken(leg_state.limit_activation_armed),
                                ExecutionBoolToken(SignalUsesBreakoutLimitAnchoring(signal_params)),
                                g_points_spread);
  ExecutionAppendQueryDebugLog("NEXT_LEVEL_TRIGGER", message);
  ExecutionLogLegResolutionContext("NEXT_LEVEL_CONTEXT", signal_params, leg_state);
}

void ExecutionLogStopLimitDecision(const SignalParams &signal_params,
                              const ExecutionLegState &leg_state,
                              const int level_stop_limit,
                              const bool level_limit_hit)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string action = level_limit_hit ? "CLOSE_ALL" : "BUILD_NEXT_LEVEL";
  string message = StringFormat("dir=%s|L%d|stop_limit=%d|blocked=%s|action=%s|next=%.5f|entry_ref=%.5f|spread_pts=%.1f",
                                direction,
                                display_level,
                                level_stop_limit,
                                ExecutionBoolToken(level_limit_hit),
                                action,
                                leg_state.next_level_price,
                                leg_state.entry_reference_price,
                                g_points_spread);
  ExecutionAppendQueryDebugLog("STOP_LIMIT_DECISION", message);
}

string ExecutionSourceExtremumTypeToken(const SignalParams &signal_params)
{
  if(signal_params.source_extremum_time <= 0)
    return "n/a";

  return signal_params.source_extremum_is_peak ? "PEAK" : "BOTTOM";
}

string ExecutionSourceExtremumTimeToken(const SignalParams &signal_params)
{
  if(signal_params.source_extremum_time <= 0)
    return "n/a";

  return TimeToString(signal_params.source_extremum_time, TIME_DATE|TIME_SECONDS);
}

string ExecutionDeterministicSourceKey(const SignalParams &signal_params)
{
  if(signal_params.deterministic_source_key != "")
    return signal_params.deterministic_source_key;

  return BuildExtremumEngineSignalSourceKey(signal_params);
}

string ExecutionTimeToken(const datetime value)
{
  if(value <= 0)
    return "n/a";

  return TimeToString(value, TIME_DATE|TIME_SECONDS);
}

void ExecutionLogDeterministicSourceConsumed(const SignalParams &signal_params,
                                             const ExecutionLegState &leg_state,
                                             const int source_attempt_count,
                                             const string terminal_outcome)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("strategy=%s|dir=%s|L%d|source_key=%s|source_attempt_index=%d|source_attempt_count=%d|terminal_outcome=%s|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|signal_ts=%s|entry_ref=%.5f|entry=%.5f|tp=%.5f|raw_trigger=%.5f|raw_stop=%.5f",
                                signal_params.engine_label,
                                direction,
                                display_level,
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                source_attempt_count,
                                terminal_outcome,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                ExecutionTimeToken(signal_params.entry_time),
                                leg_state.entry_reference_price,
                                leg_state.entry_price,
                                leg_state.take_profit_price,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price);

  ExecutionAppendQueryDebugLog("DETERMINISTIC_SOURCE_CONSUMED", message);
}

void ExecutionLogDeterministicSourceReentryBlocked(const int engine_id,
                                                   const SignalTypes direction,
                                                   const int source_slot,
                                                   const bool source_confirmed,
                                                   const bool source_is_peak,
                                                   const datetime source_time,
                                                   const double source_price,
                                                   const double source_high,
                                                   const double source_low,
                                                   const int source_attempt_count,
                                                   const string terminal_outcome,
                                                   const datetime consumed_time)
{
  string direction_label = (direction == BULLISH) ? "BULLISH" : "BEARISH";
  string source_type = source_is_peak ? "PEAK" : "BOTTOM";
  string source_key = BuildExtremumEngineSourceKey(engine_id,
                                                  direction,
                                                  source_slot,
                                                  source_time,
                                                  source_is_peak,
                                                  source_price);
  string message = StringFormat("strategy=%s|dir=%s|source_key=%s|blocked_next_attempt_index=%d|previous_attempt_count=%d|terminal_outcome=%s|consumed_time=%s|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|reason=source_consumed_after_tp",
                                ExtremumEngineLabel(engine_id),
                                direction_label,
                                source_key,
                                source_attempt_count + 1,
                                source_attempt_count,
                                terminal_outcome,
                                ExecutionTimeToken(consumed_time),
                                source_slot,
                                ExecutionBoolToken(source_confirmed),
                                source_type,
                                ExecutionTimeToken(source_time),
                                source_price,
                                source_high,
                                source_low);

  ExecutionAppendQueryDebugChangedLog("DETERMINISTIC_SOURCE_REENTRY_BLOCKED",
                                      source_key,
                                      message);
}

void ExecutionLogDeterministicInvalidCandidate(const SignalParams &signal_params,
                                               const int blocked_next_attempt_index,
                                               const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("strategy=%s|dir=%s|source_key=%s|blocked_next_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|trigger=%.5f|stop=%.5f|reason=%s",
                                signal_params.engine_label,
                                direction,
                                ExecutionDeterministicSourceKey(signal_params),
                                blocked_next_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                reason);

  ExecutionAppendQueryDebugLog("DETERMINISTIC_INVALID_CANDIDATE", message);
}

void ExecutionLogDeterministicEntryAnchorBlocked(const SignalParams &signal_params,
                                                 const ExecutionLegState &leg_state,
                                                 const double close_0,
                                                 const double high_1,
                                                 const double low_1,
                                                 const double current_anchor,
                                                 const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("strategy=%s|dir=%s|L%d|status=%s|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|raw_trigger=%.5f|current_anchor=%.5f|raw_stop=%.5f|entry_ref=%.5f|close_0=%.5f|high_1=%.5f|low_1=%.5f|reason=%s",
                                signal_params.engine_label,
                                direction,
                                display_level,
                                EnumToString(leg_state.status),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.raw_entry_trigger_price,
                                current_anchor,
                                signal_params.raw_stop_anchor_price,
                                leg_state.entry_reference_price,
                                close_0,
                                high_1,
                                low_1,
                                reason);

  string state_key = ExecutionQueryDebugSignalKey(signal_params) + "|L" +
                     IntegerToString(display_level) + "|ENTRY_ANCHOR_BLOCKED";
  ExecutionAppendQueryDebugThrottledLog("DETERMINISTIC_ENTRY_ANCHOR_BLOCKED",
                                        state_key,
                                        message,
                                        QUERY_DEBUG_ENTRY_ANCHOR_BLOCKED_THROTTLE_SECONDS);
}

void ExecutionLogDeterministicEntryRefresh(const SignalParams &signal_params,
                                           const ExecutionLegState &leg_state,
                                           const double old_trigger,
                                           const double candidate_trigger,
                                           const double new_trigger,
                                           const double close_0,
                                           const double high_1,
                                           const double low_1,
                                           const double risk_before_points,
                                           const double risk_after_points,
                                           const double tp_before,
                                           const double tp_after,
                                           const double lot_before,
                                           const double lot_after,
                                           const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("strategy=%s|dir=%s|L%d|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|old_trigger=%.5f|candidate_trigger=%.5f|new_trigger=%.5f|stop=%.5f|close_0=%.5f|high_1=%.5f|low_1=%.5f|risk_before_pts=%.2f|risk_after_pts=%.2f|tp_before=%.5f|tp_after=%.5f|lot_before=%.2f|lot_after=%.2f|reason=%s",
                                signal_params.engine_label,
                                direction,
                                display_level,
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                old_trigger,
                                candidate_trigger,
                                new_trigger,
                                signal_params.raw_stop_anchor_price,
                                close_0,
                                high_1,
                                low_1,
                                risk_before_points,
                                risk_after_points,
                                tp_before,
                                tp_after,
                                lot_before,
                                lot_after,
                                reason);

  string state_key = ExecutionQueryDebugSignalKey(signal_params) + "|L" + IntegerToString(display_level);
  ExecutionAppendQueryDebugChangedLog("DETERMINISTIC_ENTRY_REFRESH",
                                      state_key,
                                      message);
}

void ExecutionLogDeterministicSignalExpired(const SignalParams &signal_params,
                                            const int new_source_slot,
                                            const datetime new_source_time,
                                            const bool new_source_is_peak,
                                            const double new_source_price,
                                            const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string new_source_type = (new_source_time > 0) ? (new_source_is_peak ? "PEAK" : "BOTTOM") : "n/a";
  string new_source_time_token = (new_source_time > 0) ? TimeToString(new_source_time, TIME_DATE|TIME_SECONDS) : "n/a";
  string leg_status = "n/a";
  int total_legs = ArraySize(signal_params.execution_legs);
  if(total_legs > 0)
    leg_status = EnumToString(signal_params.execution_legs[0].status);

  string message = StringFormat("strategy=%s|dir=%s|status=%s|sequence=%s|source_key=%s|source_attempt_index=%d|old_source_slot=%d|old_source_confirmed=%s|old_source_type=%s|old_source_time=%s|old_source_price=%.5f|old_source_high=%.5f|old_source_low=%.5f|new_source_slot=%d|new_source_type=%s|new_source_time=%s|new_source_price=%.5f|raw_trigger=%.5f|raw_stop=%.5f|reason=%s",
                                signal_params.engine_label,
                                direction,
                                leg_status,
                                ExecutionQueryDebugSignalKey(signal_params),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                new_source_slot,
                                new_source_type,
                                new_source_time_token,
                                new_source_price,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                reason);

  ExecutionAppendQueryDebugLog("DETERMINISTIC_SIGNAL_EXPIRED", message);
}

void ExecutionLogDeterministicPendingCanceled(const SignalParams &signal_params,
                                              const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string first_leg_status = "n/a";
  int total_legs = ArraySize(signal_params.execution_legs);
  if(total_legs > 0)
    first_leg_status = EnumToString(signal_params.execution_legs[0].status);

  string message = StringFormat("strategy=%s|dir=%s|signal_state=%s|first_leg_status=%s|sequence=%s|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|raw_trigger=%.5f|raw_stop=%.5f|realized_volume=%.2f|realized_profit=%.2f|close_price=%.5f|reason=%s",
                                signal_params.engine_label,
                                direction,
                                EnumToString(signal_params.signal_state),
                                first_leg_status,
                                ExecutionQueryDebugSignalKey(signal_params),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                signal_params.realized_closed_volume,
                                signal_params.realized_profit,
                                signal_params.close_price,
                                reason);

  ExecutionAppendQueryDebugLog("DETERMINISTIC_PENDING_CANCELED", message);
}

void ExecutionLogExtremumEngineEntryConfirmation(const SignalParams &signal_params,
                                                 const ExecutionLegState &leg_state,
                                                 const double close_0,
                                                 const double high_1,
                                                 const double low_1)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("engine=%s|dir=%s|L%d|status=%s|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|raw_trigger=%.5f|raw_stop=%.5f|entry_ref=%.5f|close_0=%.5f|high_1=%.5f|low_1=%.5f",
                                signal_params.engine_label,
                                direction,
                                display_level,
                                EnumToString(leg_state.status),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                leg_state.entry_reference_price,
                                close_0,
                                high_1,
                                low_1);

  string state_key = ExecutionQueryDebugSignalKey(signal_params) + "|L" +
                     IntegerToString(display_level) + "|ENTRY_CONFIRM";
  ExecutionAppendQueryDebugThrottledLog("EXTREMUM_ENGINE_ENTRY_CONFIRM",
                                        state_key,
                                        message,
                                        QUERY_DEBUG_ENTRY_CONFIRM_THROTTLE_SECONDS);
}

void ExecutionLogEvent(const string label,
                  const SignalParams &signal_params,
                  const ExecutionLegState &leg_state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string direction_short = (signal_params.signal_type == BULLISH) ? "B" : "S";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string event_timestamp = TimeToString(TimeCurrent(),
                                        TIME_DATE|TIME_SECONDS);
  string event_timestamp_min = TimeToString(TimeCurrent(),
                                            TIME_DATE|TIME_MINUTES);
  string signal_timestamp = "n/a";
  string signal_timestamp_min = "n/a";
  if(signal_params.entry_time > 0)
  {
    signal_timestamp = TimeToString(signal_params.entry_time,
                                    TIME_DATE|TIME_SECONDS);
    signal_timestamp_min = TimeToString(signal_params.entry_time,
                                        TIME_DATE|TIME_MINUTES);
  }
  string structure_timestamp = "n/a";
  string structure_timestamp_min = "n/a";
  if(signal_params.context_structure_snapshot_time > 0)
  {
    structure_timestamp = TimeToString(signal_params.context_structure_snapshot_time,
                                       TIME_DATE|TIME_SECONDS);
    structure_timestamp_min = TimeToString(signal_params.context_structure_snapshot_time,
                                           TIME_DATE|TIME_MINUTES);
  }
  string structure_audit = ExecutionResolveStructureAuditSummary(signal_params);

  string message = StringFormat("dir=%s|L%d|status=%s|source_key=%s|source_attempt_index=%d|entry_ref=%.5f|next=%.5f|entry=%.5f|tp=%.5f|lot=%.2f|event_ts=%s|signal_ts=%s|structure_ts=%s|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|source_high=%.5f|source_low=%.5f|raw_trigger=%.5f|raw_stop=%.5f|structure=%s",
                                direction,
                                display_level,
                                EnumToString(leg_state.status),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                leg_state.entry_reference_price,
                                leg_state.next_level_price,
                                leg_state.entry_price,
                                leg_state.take_profit_price,
                                leg_state.lot_size,
                                event_timestamp,
                                signal_timestamp,
                                structure_timestamp,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.source_extremum_high,
                                signal_params.source_extremum_low,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                structure_audit);

  ExecutionAppendQueryDebugLog(label, message);

  if(label == "SIGNAL_INIT" || label == "LEVEL_PENDING_INIT")
    ExecutionLogLegResolutionContext("LEVEL_CONTEXT", signal_params, leg_state);

  if(Enable_Logs && ExecutionShouldPrintTerminalEvent(label))
  {
    PrintFormat("[%s] %s L%d ev=%s sg=%s st=%s",
                label,
                direction_short,
                display_level,
                event_timestamp_min,
                signal_timestamp_min,
                structure_timestamp_min);
    PrintFormat("[STRUCT] %s", structure_audit);
  }
}

void ExecutionLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const ExecutionLegState &leg_state,
                           const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  string message = StringFormat("strategy=%s|dir=%s|L%d|status=%s|sequence=%s|source_key=%s|source_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|raw_trigger=%.5f|raw_stop=%.5f|admission=%s|admission_source=%s|admission_reason=%s|admission_spread=%.1f|max_spread=%.1f|market_status=%s|reason=%s",
                                signal_params.engine_label,
                                direction,
                                display_level,
                                EnumToString(leg_state.status),
                                ExecutionQueryDebugSignalKey(signal_params),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                EnumToString(signal_params.admission_status),
                                signal_params.admission_block_source,
                                signal_params.admission_block_reason,
                                signal_params.admission_spread_points,
                                signal_params.admission_max_spread,
                                MarketStatusToString(signal_params.admission_market_status),
                                reason);

  if(label == "LOCAL_EXECUTION_BLOCK")
  {
    string reason_key = reason;
    int separator = StringFind(reason_key, ":");
    if(separator > 0)
      reason_key = StringSubstr(reason_key, 0, separator);

    string state_key = ExecutionQueryDebugSignalKey(signal_params) + "|L" +
                       IntegerToString(display_level) + "|" + reason_key;
    ExecutionAppendQueryDebugThrottledLog(label,
                                          state_key,
                                          message,
                                          QUERY_DEBUG_GUARDRAIL_THROTTLE_SECONDS);
    return;
  }

  ExecutionAppendQueryDebugLog(label, message);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
