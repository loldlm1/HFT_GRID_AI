//+------------------------------------------------------------------+
//|                        market_conditions_functions.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_

datetime BrokerDayAnchor(const datetime broker_time)
{
  MqlDateTime parts;
  ZeroMemory(parts);
  if(!TimeToStruct(broker_time, parts))
    return 0;
  parts.hour = 0;
  parts.min = 0;
  parts.sec = 0;
  return StructToTime(parts);
}

bool BrokerSessionContainsTime(const datetime day_anchor,
                               const datetime from_time,
                               const datetime to_time,
                               const datetime broker_time)
{
  long from_seconds = (long)from_time % 86400;
  long to_seconds = (long)to_time % 86400;
  datetime session_from = (datetime)(day_anchor + from_seconds);
  datetime session_to = (datetime)(day_anchor + to_seconds);
  if(to_seconds <= from_seconds)
    session_to += 86400;
  return (broker_time >= session_from && broker_time < session_to);
}

bool IsSymbolTradeSessionOpen(const string symbol,
                              const datetime broker_time)
{
  if(symbol == "" || broker_time <= 0)
    return false;

  datetime day_anchor = BrokerDayAnchor(broker_time);
  if(day_anchor <= 0)
    return false;

  MqlDateTime current_parts;
  ZeroMemory(current_parts);
  if(!TimeToStruct(broker_time, current_parts))
    return false;

  datetime from_time = 0;
  datetime to_time = 0;
  ENUM_DAY_OF_WEEK current_day = (ENUM_DAY_OF_WEEK)current_parts.day_of_week;
  for(int session = 0; session < 32; session++)
  {
    if(!SymbolInfoSessionTrade(symbol, current_day, session, from_time, to_time))
      continue;
    if(BrokerSessionContainsTime(day_anchor, from_time, to_time, broker_time))
      return true;
  }

  datetime previous_time = broker_time - 86400;
  MqlDateTime previous_parts;
  ZeroMemory(previous_parts);
  if(!TimeToStruct(previous_time, previous_parts))
    return false;

  ENUM_DAY_OF_WEEK previous_day = (ENUM_DAY_OF_WEEK)previous_parts.day_of_week;
  for(int previous_session = 0; previous_session < 32; previous_session++)
  {
    if(!SymbolInfoSessionTrade(symbol,
                               previous_day,
                               previous_session,
                               from_time,
                               to_time))
      continue;
    long from_seconds = (long)from_time % 86400;
    long to_seconds = (long)to_time % 86400;
    if(to_seconds > from_seconds)
      continue;
    if(BrokerSessionContainsTime(day_anchor - 86400,
                                 from_time,
                                 to_time,
                                 broker_time))
      return true;
  }

  return false;
}

bool IsMarketOpen()
{
  return IsSymbolTradeSessionOpen(_Symbol, TimeCurrent());
}

#endif // _SERVICES_TRADING_MANAGEMENT_MARKET_CONDITIONS_FUNCTIONS_MQH_
