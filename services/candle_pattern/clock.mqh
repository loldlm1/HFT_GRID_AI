#ifndef CANDLE_CLOCK_MQH
#define CANDLE_CLOCK_MQH

// Export-only US rules effective from 2007, independent of symbol and host time.
bool CandleDstTransition(const int year, const int month, const int sunday,
                         const int utc_hour, datetime &transition)
{
  MqlDateTime date;
  ZeroMemory(date);
  date.year = year;
  date.mon = month;
  date.day = 1;
  date.hour = utc_hour;
  datetime first = StructToTime(date);
  if(first <= 0 || !TimeToStruct(first, date)) return false;
  transition = first + ((7 - date.day_of_week) % 7 + 7 * (sunday - 1)) * 86400;
  return true;
}

bool CandleAnalysisClock(const long broker_msc, long &analysis_msc, int &offset_minutes)
{
  analysis_msc = broker_msc;
  offset_minutes = 0;
  if(broker_msc <= 0) return false;
  if(Broker_Session == FIXED_TIME_SESSIONS) return true;
  if(Broker_Session != EXNESS_SESSION) return false;
  MqlDateTime date;
  datetime broker_time = (datetime)(broker_msc / 1000);
  if(!TimeToStruct(broker_time, date) || date.year < 2007 || date.year > 2099) return false;
  static int cached_year = 0;
  static datetime summer_start = 0, summer_end = 0;
  if(cached_year != date.year)
  {
    if(!CandleDstTransition(date.year, 3, 2, 7, summer_start) ||
       !CandleDstTransition(date.year, 11, 1, 6, summer_end)) return false;
    cached_year = date.year;
  }
  offset_minutes = broker_time >= summer_start && broker_time < summer_end ? 0 : -60;
  analysis_msc = broker_msc + (long)offset_minutes * 60000;
  return true;
}

#endif
