#ifndef MODEL_CLOCK_MQH
#define MODEL_CLOCK_MQH

// Export-only New York policy. The raw clock remains authoritative.
bool ModelDstTransition(const int year, const int month, const int sunday,
                        const int utc_hour, datetime &transition)
{
  MqlDateTime date = {};
  date.year = year;
  date.mon = month;
  date.day = 1;
  date.hour = utc_hour;
  datetime first = StructToTime(date);
  if(first <= 0 || !TimeToStruct(first, date)) return false;
  transition = first + ((7 - date.day_of_week) % 7 + 7 * (sunday - 1)) * 86400;
  return true;
}

bool ModelAnalysisClock(const long raw_msc, const bool exness,
                        long &analysis_msc, int &offset_minutes)
{
  analysis_msc = raw_msc;
  offset_minutes = 0;
  if(raw_msc <= 0) return false;
  if(!exness) return true;
  MqlDateTime date = {};
  datetime raw = (datetime)(raw_msc / 1000);
  if(!TimeToStruct(raw, date) || date.year < 2007 || date.year > 2099) return false;
  static int cached_year = 0;
  static datetime summer_start = 0, summer_end = 0;
  if(cached_year != date.year)
  {
    if(!ModelDstTransition(date.year, 3, 2, 7, summer_start) ||
       !ModelDstTransition(date.year, 11, 1, 6, summer_end)) return false;
    cached_year = date.year;
  }
  offset_minutes = raw >= summer_start && raw < summer_end ? 0 : -60;
  analysis_msc = raw_msc + (long)offset_minutes * 60000;
  return true;
}

#endif
