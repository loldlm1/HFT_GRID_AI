//+------------------------------------------------------------------+
//|                    services/utils/time_offset_helper.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_UTILS_TIME_OFFSET_HELPER_MQH_
#define _SERVICES_UTILS_TIME_OFFSET_HELPER_MQH_

int ComputeNthWeekdayOfMonth(const int year,
                             const int month,
                             const int target_weekday,
                             const int occurrence)
{
  if(occurrence <= 0)
    return -1;

  MqlDateTime month_start;
  ZeroMemory(month_start);
  month_start.year = year;
  month_start.mon  = month;
  month_start.day  = 1;

  datetime first_day_time = StructToTime(month_start);
  if(first_day_time <= 0)
    return -1;

  MqlDateTime first_day_struct;
  ZeroMemory(first_day_struct);
  if(!TimeToStruct(first_day_time, first_day_struct))
    return -1;

  int weekday_offset = target_weekday - first_day_struct.day_of_week;
  if(weekday_offset < 0)
    weekday_offset += 7;

  int candidate_day = 1 + weekday_offset + (occurrence - 1) * 7;

  MqlDateTime candidate_struct;
  ZeroMemory(candidate_struct);
  candidate_struct.year = year;
  candidate_struct.mon  = month;
  candidate_struct.day  = candidate_day;

  datetime candidate_time = StructToTime(candidate_struct);
  if(candidate_time <= 0)
    return -1;

  MqlDateTime resolved_candidate;
  ZeroMemory(resolved_candidate);
  if(!TimeToStruct(candidate_time, resolved_candidate))
    return -1;
  if(resolved_candidate.year != year ||
     resolved_candidate.mon != month ||
     resolved_candidate.day != candidate_day)
    return -1;

  return candidate_day;
}

datetime ExnessDstStart(const int year)
{
  int day = ComputeNthWeekdayOfMonth(year, 3, 0, 2);
  if(day < 0)
    return 0;

  MqlDateTime ts;
  ZeroMemory(ts);
  ts.year = year;
  ts.mon  = 3;
  ts.day  = day;
  return StructToTime(ts);
}

datetime ExnessDstEnd(const int year)
{
  int day = ComputeNthWeekdayOfMonth(year, 11, 0, 1);
  if(day < 0)
    return 0;

  MqlDateTime ts;
  ZeroMemory(ts);
  ts.year = year;
  ts.mon  = 11;
  ts.day  = day;
  return StructToTime(ts);
}

bool ExnessDstActive(const datetime now_time)
{
  MqlDateTime ts;
  ZeroMemory(ts);
  if(!TimeToStruct(now_time, ts))
    return false;

  datetime start = ExnessDstStart(ts.year);
  datetime end   = ExnessDstEnd(ts.year);
  if(start <= 0 || end <= 0)
    return false;

  return (now_time >= start && now_time < end);
}

int ResolveTradingTimeOffsetMinutesForMode(const DstOffsetModes mode,
                                           const int manual_offset_minutes,
                                           const datetime current_time)
{
  if(mode == DST_MODE_MANUAL)
    return manual_offset_minutes;

  if(mode == DST_MODE_AUTO_EXNESS)
  {
    if(ExnessDstActive(current_time))
      return 0;
    return 60;
  }

  return 0;
}

#endif // _SERVICES_UTILS_TIME_OFFSET_HELPER_MQH_
