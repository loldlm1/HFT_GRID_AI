//+------------------------------------------------------------------+
//|                        market_conditions_functions.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_

bool ResolveCurrentSessionWindow(datetime &session_from,
                                 datetime &session_to)
{
  string symbol = _Symbol;
  datetime current_time = TimeCurrent();
  MqlDateTime now_struct;
  TimeToStruct(current_time, now_struct);
  ENUM_DAY_OF_WEEK day_of_week = (ENUM_DAY_OF_WEEK)now_struct.day_of_week;
  datetime day_anchor = StructToTime(now_struct)
                        - now_struct.hour * 3600
                        - now_struct.min * 60
                        - now_struct.sec;

  datetime from_time, to_time;
  for(int session = 0; session < 3; session++)
  {
    if(!SymbolInfoSessionTrade(symbol, day_of_week, session, from_time, to_time))
      continue;

    datetime today_from = day_anchor + from_time;
    datetime today_to   = day_anchor + to_time;

    if(today_to < today_from)
      today_to += 24 * 3600;

    if(current_time >= today_from && current_time <= today_to)
    {
      session_from = today_from;
      session_to   = today_to;
      return true;
    }
  }

  return false;
}

bool ResolveSessionPreCloseTrigger(const datetime session_end,
                                   const ENUM_TIMEFRAMES guard_timeframe,
                                   datetime &trigger_time)
{
  ENUM_TIMEFRAMES resolved_timeframe = guard_timeframe;
  if(resolved_timeframe == PERIOD_CURRENT)
    resolved_timeframe = (ENUM_TIMEFRAMES)_Period;

  int guard_seconds = PeriodSeconds(resolved_timeframe);
  if(guard_seconds <= 0)
    return false;

  long session_end_ts = (long)session_end;
  long anchor_ts = session_end_ts - 1;
  if(anchor_ts < 0)
    anchor_ts = 0;

  long guard_span = (long)guard_seconds;
  long aligned_ts = (anchor_ts / guard_span) * guard_span;

  trigger_time = (datetime)aligned_ts;
  return true;
}

bool IsMarketOpen(bool last_check_execution = true)
{
  static datetime last_check_time = 0;
  static bool last_result = false;

  datetime current_time = TimeCurrent();

  if(last_check_execution && current_time - last_check_time < 60)
    return last_result;

  last_check_time = current_time;

  datetime session_from = 0;
  datetime session_to = 0;
  if(!ResolveCurrentSessionWindow(session_from, session_to))
  {
    last_result = false;
    return false;
  }

  if(current_time >= (session_from) && current_time < (session_to))
  {
    last_result = true;
    return true;
  }

  last_result = false;
  return false;
}

#endif // _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_
