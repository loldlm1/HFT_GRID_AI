//+------------------------------------------------------------------+
//|                  trading_signals/execution_logging.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_

const string QUERY_DEBUG_FILENAME = "query_debug.txt";
const int QUERY_DEBUG_STATE_RESERVE = 64;
const int QUERY_DEBUG_THROTTLE_RESERVE = 64;
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
  return direction + "|" + TimeToString(signal_params.entry_time, TIME_DATE|TIME_SECONDS);
}

int ExecutionFindQueryDebugStateIndex(const string state_key)
{
  for(int i = 0; i < ArraySize(g_query_debug_state_keys); i++)
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
  for(int i = 0; i < ArraySize(g_query_debug_throttle_keys); i++)
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
      ArrayResize(g_query_debug_throttle_keys, total + 1, QUERY_DEBUG_THROTTLE_RESERVE);
      ArrayResize(g_query_debug_throttle_times, total + 1, QUERY_DEBUG_THROTTLE_RESERVE);
      ArrayResize(g_query_debug_throttle_suppressed, total + 1, QUERY_DEBUG_THROTTLE_RESERVE);
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

void EnsureQueryDebugSessionHeaderLogged()
{
  if(!Enable_File_Logs || g_query_debug_session_header_logged)
    return;

  g_query_debug_session_header_logged = true;
  ExecutionAppendRawQueryDebugLine("");
  ExecutionAppendTimestampedQueryDebug(
    "QUERY_DEBUG_SESSION",
    StringFormat("symbol=%s|period=%s|broker_session=%s|lot_type=%s|lot_size=%.8f|ml_mode=%s",
                 _Symbol,
                 EnumToString(EXTREMUM_ENGINE_TIMEFRAME),
                 EnumToString(Broker_Session),
                 EnumToString(Lot_Type),
                 Lot_Strategy_Size,
                 ExecutionMLInferenceModeToken(ML_Inference_Mode)));
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
  if(ExecutionShouldLogChangedState(label + "|" + state_key, message))
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

  string output = message;
  if(suppressed_since_last > 0)
    output += StringFormat("|suppressed_since_last=%d", suppressed_since_last);
  ExecutionAppendTimestampedQueryDebug(label, output);
}

string ExecutionSourceExtremumTypeToken(const SignalParams &signal_params)
{
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
                                             const ExecutionState &execution_state,
                                             const int source_attempt_count,
                                             const string terminal_outcome)
{
  string message = StringFormat("strategy=%s|dir=%s|source_key=%s|source_attempt_index=%d|source_attempt_count=%d|terminal_outcome=%s|entry=%.5f|tp=%.5f|signal_ts=%s",
                                signal_params.engine_label,
                                signal_params.signal_type == BULLISH ? "BULLISH" : "BEARISH",
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                source_attempt_count,
                                terminal_outcome,
                                execution_state.broker_entry_price > 0.0
                                  ? execution_state.broker_entry_price
                                  : execution_state.planned_entry_price,
                                execution_state.take_profit_price,
                                ExecutionTimeToken(signal_params.entry_time));
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
  string source_key = BuildExtremumEngineSourceKey(engine_id,
                                                    direction,
                                                    source_slot,
                                                    source_time,
                                                    source_is_peak,
                                                    source_price);
  string message = StringFormat("strategy=%s|dir=%s|source_key=%s|blocked_next_attempt_index=%d|previous_attempt_count=%d|terminal_outcome=%s|consumed_time=%s|source_confirmed=%s|source_high=%.5f|source_low=%.5f|reason=source_consumed_after_tp",
                                ExtremumEngineLabel(engine_id),
                                direction == BULLISH ? "BULLISH" : "BEARISH",
                                source_key,
                                source_attempt_count + 1,
                                source_attempt_count,
                                terminal_outcome,
                                ExecutionTimeToken(consumed_time),
                                ExecutionBoolToken(source_confirmed),
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
  string message = StringFormat("strategy=%s|dir=%s|source_key=%s|blocked_next_attempt_index=%d|source_slot=%d|source_confirmed=%s|source_type=%s|source_time=%s|source_price=%.5f|trigger=%.5f|stop=%.5f|reason=%s",
                                signal_params.engine_label,
                                signal_params.signal_type == BULLISH ? "BULLISH" : "BEARISH",
                                ExecutionDeterministicSourceKey(signal_params),
                                blocked_next_attempt_index,
                                signal_params.source_extremum_slot,
                                ExecutionBoolToken(signal_params.source_extremum_confirmed),
                                ExecutionSourceExtremumTypeToken(signal_params),
                                ExecutionSourceExtremumTimeToken(signal_params),
                                signal_params.source_extremum_price,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                reason);
  ExecutionAppendQueryDebugLog("DETERMINISTIC_INVALID_CANDIDATE", message);
}

void ExecutionLogDeterministicSignalExpired(const SignalParams &signal_params,
                                            const int new_source_slot,
                                            const datetime new_source_time,
                                            const bool new_source_is_peak,
                                            const double new_source_price,
                                            const string reason)
{
  string new_time = new_source_time > 0
                    ? TimeToString(new_source_time, TIME_DATE|TIME_SECONDS)
                    : "n/a";
  string message = StringFormat("strategy=%s|dir=%s|state=%s|sequence=%s|source_key=%s|old_source_slot=%d|old_source_time=%s|new_source_slot=%d|new_source_type=%s|new_source_time=%s|new_source_price=%.5f|reason=%s",
                                signal_params.engine_label,
                                signal_params.signal_type == BULLISH ? "BULLISH" : "BEARISH",
                                EnumToString(signal_params.execution.state),
                                ExecutionQueryDebugSignalKey(signal_params),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.source_extremum_slot,
                                ExecutionSourceExtremumTimeToken(signal_params),
                                new_source_slot,
                                new_source_is_peak ? "PEAK" : "BOTTOM",
                                new_time,
                                new_source_price,
                                reason);
  ExecutionAppendQueryDebugLog("DETERMINISTIC_SIGNAL_EXPIRED", message);
}

void ExecutionLogDeterministicPendingCanceled(const SignalParams &signal_params,
                                              const string reason)
{
  string message = StringFormat("strategy=%s|dir=%s|signal_state=%s|execution_state=%s|sequence=%s|source_key=%s|source_attempt_index=%d|raw_trigger=%.5f|raw_stop=%.5f|realized_volume=%.8f|realized_profit=%.2f|close_price=%.5f|reason=%s",
                                signal_params.engine_label,
                                signal_params.signal_type == BULLISH ? "BULLISH" : "BEARISH",
                                EnumToString(signal_params.signal_state),
                                EnumToString(signal_params.execution.state),
                                ExecutionQueryDebugSignalKey(signal_params),
                                ExecutionDeterministicSourceKey(signal_params),
                                signal_params.deterministic_source_attempt_index,
                                signal_params.raw_entry_trigger_price,
                                signal_params.raw_stop_anchor_price,
                                signal_params.realized_closed_volume,
                                signal_params.realized_profit,
                                signal_params.close_price,
                                reason);
  ExecutionAppendQueryDebugLog("DETERMINISTIC_PENDING_CANCELED", message);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
