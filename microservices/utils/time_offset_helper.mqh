//+------------------------------------------------------------------+
//|                         time_offset_helper.mqh                   |
//| Resolves trading time offsets (DST) for session/Pandora windows. |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_TIME_OFFSET_HELPER_MQH_
#define _MICROSERVICES_UTILS_TIME_OFFSET_HELPER_MQH_

int ComputeNthWeekdayOfMonth(const int year,
                             const int month,
                             const int target_weekday,
                             const int occurrence)
{
  // occurrence: 1=first, 2=second, etc.
  int day = 1;
  MqlDateTime ts;
  ts.year = year;
  ts.mon  = month;
  ts.hour = 0;
  ts.min  = 0;
  ts.sec  = 0;
  while(true)
  {
    ts.day = day;
    datetime candidate = StructToTime(ts);
    if(candidate <= 0)
      return -1;
    MqlDateTime candidate_ts;
    if(!TimeToStruct(candidate, candidate_ts))
      return -1;
    int dow = candidate_ts.day_of_week;
    if(dow == target_weekday)
    {
      if(occurrence <= 1)
        return day;
      int remaining = occurrence - 1;
      return day + remaining * 7;
    }
    day++;
  }
  return -1;
}

datetime ExnessDstStart(const int year)
{
  // second Sunday of March (Sunday = 0)
  int day = ComputeNthWeekdayOfMonth(year, 3, 0, 2);
  if(day < 0)
    return 0;
  MqlDateTime ts;
  ts.year = year;
  ts.mon  = 3;
  ts.day  = day;
  ts.hour = 0;
  ts.min  = 0;
  ts.sec  = 0;
  return StructToTime(ts);
}

datetime ExnessDstEnd(const int year)
{
  // first Sunday of November (Sunday = 0)
  int day = ComputeNthWeekdayOfMonth(year, 11, 0, 1);
  if(day < 0)
    return 0;
  MqlDateTime ts;
  ts.year = year;
  ts.mon  = 11;
  ts.day  = day;
  ts.hour = 0;
  ts.min  = 0;
  ts.sec  = 0;
  return StructToTime(ts);
}

bool ExnessDstActive(const datetime now_time)
{
  MqlDateTime ts;
  if(!TimeToStruct(now_time, ts))
    return false;
  int year = ts.year;
  datetime start = ExnessDstStart(year);
  datetime end   = ExnessDstEnd(year);
  if(start <= 0 || end <= 0)
    return false;
  // Active from start inclusive until end exclusive
  return (now_time >= start && now_time < end);
}

int ResolveTradingTimeOffsetMinutesAt(const datetime reference_time)
{
  if(Session_Time_Dst_Mode == DST_MODE_MANUAL)
    return Session_Time_Dst_Manual_Offset_Minutes;

  if(Session_Time_Dst_Mode == DST_MODE_AUTO_EXNESS)
  {
    // Exness: summer opens one hour earlier (13:30) and winter opens one hour later (14:30).
    // Apply +60 only during winter (DST inactive), no offset during summer (DST active).
    if(ExnessDstActive(reference_time))
      return 0;
    return 60;
  }

  return 0;
}

int ResolveTradingTimeOffsetMinutes()
{
  return ResolveTradingTimeOffsetMinutesAt(TimeCurrent());
}

#endif // _MICROSERVICES_UTILS_TIME_OFFSET_HELPER_MQH_
