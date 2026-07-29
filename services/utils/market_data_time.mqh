//+------------------------------------------------------------------+
//|                    services/utils/market_data_time.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_UTILS_MARKET_DATA_TIME_MQH_
#define _SERVICES_UTILS_MARKET_DATA_TIME_MQH_

int MarketDataNthWeekday(const int year,
                         const int month,
                         const int weekday,
                         const int occurrence)
{
  if(occurrence <= 0)
    return -1;

  MqlDateTime first;
  ZeroMemory(first);
  first.year = year;
  first.mon  = month;
  first.day  = 1;
  datetime first_time = StructToTime(first);
  if(first_time <= 0)
    return -1;

  MqlDateTime first_resolved;
  ZeroMemory(first_resolved);
  if(!TimeToStruct(first_time, first_resolved))
    return -1;

  int offset = weekday - first_resolved.day_of_week;
  if(offset < 0)
    offset += 7;
  return 1 + offset + (occurrence - 1) * 7;
}

int MarketDataLastWeekday(const int year,
                          const int month,
                          const int weekday)
{
  MqlDateTime next_month;
  ZeroMemory(next_month);
  next_month.year = year;
  next_month.mon = month + 1;
  if(next_month.mon > 12)
  {
    next_month.year++;
    next_month.mon = 1;
  }
  next_month.day = 1;

  datetime next_month_time = StructToTime(next_month);
  if(next_month_time <= 86400)
    return -1;

  MqlDateTime last_day;
  ZeroMemory(last_day);
  if(!TimeToStruct(next_month_time - 86400, last_day))
    return -1;

  int offset = last_day.day_of_week - weekday;
  if(offset < 0)
    offset += 7;
  return last_day.day - offset;
}

datetime MarketDataDateAt(const int year,
                          const int month,
                          const int day,
                          const int hour,
                          const int minute,
                          const int second)
{
  MqlDateTime value;
  ZeroMemory(value);
  value.year = year;
  value.mon  = month;
  value.day  = day;
  value.hour = hour;
  value.min  = minute;
  value.sec  = second;
  return StructToTime(value);
}

bool MarketDataSymbolHasPrefix(const string symbol,
                               const string prefix)
{
  string upper = symbol;
  StringToUpper(upper);
  string upper_prefix = prefix;
  StringToUpper(upper_prefix);
  return (StringFind(upper, upper_prefix) == 0);
}

bool MarketDataUsesUnitedKingdomDst(const string symbol)
{
  // Exness metals use the London calendar; suffixes such as "m" or ".r"
  // do not change the base-symbol classification.
  return (MarketDataSymbolHasPrefix(symbol, "XAU") ||
          MarketDataSymbolHasPrefix(symbol, "XAG") ||
          MarketDataSymbolHasPrefix(symbol, "XPT") ||
          MarketDataSymbolHasPrefix(symbol, "XPD"));
}

bool MarketDataUsesUnitedStatesDst(const string symbol)
{
  // Exness instruments default to the US calendar. Keep this explicit helper
  // so the documented UK metal exceptions remain auditable.
  return !MarketDataUsesUnitedKingdomDst(symbol);
}

datetime MarketDataUsDstStart(const int year)
{
  int day = MarketDataNthWeekday(year, 3, 0, 2);
  return (day > 0) ? MarketDataDateAt(year, 3, day, 2, 0, 0) : 0;
}

datetime MarketDataUsDstEnd(const int year)
{
  int day = MarketDataNthWeekday(year, 11, 0, 1);
  return (day > 0) ? MarketDataDateAt(year, 11, day, 2, 0, 0) : 0;
}

datetime MarketDataUkDstStart(const int year)
{
  int day = MarketDataLastWeekday(year, 3, 0);
  return (day > 0) ? MarketDataDateAt(year, 3, day, 1, 0, 0) : 0;
}

datetime MarketDataUkDstEnd(const int year)
{
  int day = MarketDataLastWeekday(year, 10, 0);
  return (day > 0) ? MarketDataDateAt(year, 10, day, 1, 0, 0) : 0;
}

bool MarketDataDstActive(const string symbol,
                         const datetime broker_time,
                         int &offset_minutes_out)
{
  offset_minutes_out = 0;
  MqlDateTime value;
  ZeroMemory(value);
  if(!TimeToStruct(broker_time, value))
    return false;

  bool uk_calendar = MarketDataUsesUnitedKingdomDst(symbol);
  datetime start = uk_calendar ? MarketDataUkDstStart(value.year)
                               : MarketDataUsDstStart(value.year);
  datetime end = uk_calendar ? MarketDataUkDstEnd(value.year)
                             : MarketDataUsDstEnd(value.year);
  if(start <= 0 || end <= 0)
    return false;

  if(broker_time < start || broker_time >= end)
  {
    offset_minutes_out = -60;
    return false;
  }

  offset_minutes_out = 0;
  return true;
}

datetime MarketDataNormalizeAnalysisTime(const datetime broker_time,
                                         const BrokerSessionTimeModes mode,
                                         const string symbol,
                                         int &offset_minutes_out)
{
  offset_minutes_out = 0;
  if(broker_time <= 0 || mode == FIXED_TIME_SESSIONS)
    return broker_time;

  // Exness US-DST instruments use the fixed analysis clock in winter. The
  // broker timestamp remains untouched; only the research timestamp shifts.
  MqlDateTime value;
  ZeroMemory(value);
  if(!TimeToStruct(broker_time, value))
    return broker_time;

  bool uk_calendar = MarketDataUsesUnitedKingdomDst(symbol);
  datetime start = uk_calendar ? MarketDataUkDstStart(value.year)
                               : MarketDataUsDstStart(value.year);
  datetime end = uk_calendar ? MarketDataUkDstEnd(value.year)
                             : MarketDataUsDstEnd(value.year);
  if(start <= 0 || end <= 0 || (broker_time >= start && broker_time < end))
    return broker_time;

  offset_minutes_out = -60;
  return broker_time + offset_minutes_out * 60;
}

string MarketDataTimePolicyToken(const BrokerSessionTimeModes mode)
{
  return (mode == EXNESS_SESSION) ? "EXNESS_SESSION" : "FIXED_TIME_SESSIONS";
}

#endif // _SERVICES_UTILS_MARKET_DATA_TIME_MQH_
