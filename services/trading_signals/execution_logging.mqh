//+------------------------------------------------------------------+
//|                  trading_signals/execution_logging              |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_

const string QUERY_DEBUG_FILENAME = "query_debug.txt";
const int QUERY_DEBUG_STATE_RESERVE = 64;
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

string ExecutionTimeToken(const datetime value)
{
  return value > 0
         ? TimeToString(value, TIME_DATE | TIME_SECONDS)
         : "n/a";
}

void ResetQueryDebugLogSession()
{
  CloseAppendFileLog();
  g_query_debug_session_header_logged = false;
  ArrayResize(g_query_debug_state_keys, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_state_messages, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_throttle_keys, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_throttle_times, 0, QUERY_DEBUG_STATE_RESERVE);
  ArrayResize(g_query_debug_throttle_suppressed, 0, QUERY_DEBUG_STATE_RESERVE);
  g_query_debug_state_replace_index = 0;
  g_query_debug_throttle_replace_index = 0;
}

int ExecutionFindStateIndex(string &keys[],
                            const string state_key)
{
  for(int i = 0; i < ArraySize(keys); i++)
  {
    if(keys[i] == state_key)
      return i;
  }
  return -1;
}

bool ExecutionShouldLogChangedState(const string state_key,
                                    const string message)
{
  int index = ExecutionFindStateIndex(g_query_debug_state_keys, state_key);
  if(index < 0)
  {
    int total = ArraySize(g_query_debug_state_keys);
    if(total < QUERY_DEBUG_STATE_MAX)
    {
      ArrayResize(g_query_debug_state_keys,
                  total + 1,
                  QUERY_DEBUG_STATE_RESERVE);
      ArrayResize(g_query_debug_state_messages,
                  total + 1,
                  QUERY_DEBUG_STATE_RESERVE);
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

bool ExecutionShouldLogThrottledState(const string state_key,
                                      const int throttle_seconds,
                                      int &suppressed_since_last)
{
  suppressed_since_last = 0;
  if(throttle_seconds <= 0)
    return true;

  datetime now = TimeCurrent();
  int index = ExecutionFindStateIndex(g_query_debug_throttle_keys, state_key);
  if(index < 0)
  {
    int total = ArraySize(g_query_debug_throttle_keys);
    if(total < QUERY_DEBUG_STATE_MAX)
    {
      ArrayResize(g_query_debug_throttle_keys,
                  total + 1,
                  QUERY_DEBUG_STATE_RESERVE);
      ArrayResize(g_query_debug_throttle_times,
                  total + 1,
                  QUERY_DEBUG_STATE_RESERVE);
      ArrayResize(g_query_debug_throttle_suppressed,
                  total + 1,
                  QUERY_DEBUG_STATE_RESERVE);
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

  if((int)(now - g_query_debug_throttle_times[index]) >= throttle_seconds)
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
  AppendTimestampedLog(
    QUERY_DEBUG_FILENAME,
    "QUERY_DEBUG_SESSION",
    StringFormat("symbol=%s|engine=%s|pivot_tfs=M15,M30,H1,H4,D1|broker_session=%s|lot_type=%s|lot_size=%.8f",
                 _Symbol,
                 PivotFractalEngineLabel(PIVOT_FRACTAL_V1),
                 EnumToString(Broker_Session),
                 EnumToString(Lot_Type),
                 Lot_Strategy_Size));
}

void ExecutionAppendQueryDebugLog(const string label,
                                  const string message)
{
  if(!Enable_File_Logs)
    return;
  EnsureQueryDebugSessionHeaderLogged();
  AppendTimestampedLog(QUERY_DEBUG_FILENAME, label, message);
}

void ExecutionAppendQueryDebugChangedLog(const string label,
                                         const string state_key,
                                         const string message)
{
  if(!Enable_File_Logs)
    return;
  EnsureQueryDebugSessionHeaderLogged();
  if(ExecutionShouldLogChangedState(label + "|" + state_key, message))
    AppendTimestampedLog(QUERY_DEBUG_FILENAME, label, message);
}

void ExecutionAppendQueryDebugThrottledLog(const string label,
                                           const string state_key,
                                           const string message,
                                           const int throttle_seconds)
{
  if(!Enable_File_Logs)
    return;
  EnsureQueryDebugSessionHeaderLogged();
  int suppressed = 0;
  if(!ExecutionShouldLogThrottledState(label + "|" + state_key,
                                       throttle_seconds,
                                       suppressed))
    return;
  string output = message;
  if(suppressed > 0)
    output += StringFormat("|suppressed_since_last=%d", suppressed);
  AppendTimestampedLog(QUERY_DEBUG_FILENAME, label, output);
}

void ExecutionLogPivotAttempt(const PivotSignal &signal)
{
  string message = StringFormat("signal_id=%s|window_id=%s|tf=%s|level=%s|direction=%s|previous_m1_close=%.10f|trigger_bid=%.10f|trigger_ask=%.10f|route=%s|attempt=%s|block_source=%s|block_reason=%s",
                                signal.signal_id,
                                signal.window_id,
                                EnumToString(signal.pivot_timeframe),
                                PivotLevelLabel(signal.level_id),
                                signal.direction == BULLISH ? "BUY" : "SELL",
                                signal.previous_m1_bid_close,
                                signal.trigger_bid,
                                signal.trigger_ask,
                                EnumToString(signal.route.status),
                                signal.attempt_status,
                                signal.block_source,
                                signal.block_reason);
  ExecutionAppendQueryDebugLog("PIVOT_ATTEMPT", message);
  if(Enable_Logs)
    Print("PIVOT_ATTEMPT | ", message);
}

void ExecutionLogPivotSendResult(const PivotSignal &signal,
                                 const BrokerExecutionCheck &check)
{
  string message = StringFormat("signal_id=%s|tf=%s|level=%s|direction=%s|allowed=%s|retcode=%I64u|order=%I64u|deal=%I64u|comment=%s|block=%s:%s",
                                signal.signal_id,
                                EnumToString(signal.pivot_timeframe),
                                PivotLevelLabel(signal.level_id),
                                signal.direction == BULLISH ? "BUY" : "SELL",
                                ExecutionBoolToken(check.allowed),
                                check.send_retcode,
                                check.order_ticket,
                                check.deal_ticket,
                                check.send_comment,
                                check.block_source,
                                check.block_reason);
  ExecutionAppendQueryDebugLog("PIVOT_SEND_RESULT", message);
  if(Enable_Logs)
    Print("PIVOT_SEND_RESULT | ", message);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOGGING_MQH_
