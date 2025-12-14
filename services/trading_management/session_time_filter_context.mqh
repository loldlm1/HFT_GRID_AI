//+------------------------------------------------------------------+
//|                    session_time_filter_context.mqh               |
//| Parses and exposes session time filter inputs.                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_SESSION_TIME_FILTER_CONTEXT_MQH_
#define _SERVICES_TRADING_MANAGEMENT_SESSION_TIME_FILTER_CONTEXT_MQH_

const int _SESSION_TIME_FILTER_SLOT_TOTAL = 3;
const int SESSION_TIME_FILTER_MINUTES_PER_DAY = 24 * 60;

struct SessionTimeFilterConfig
{
  SessionTimeFilterModes mode;
  int                    start_minutes;
  int                    end_minutes;
  bool                   wraps;
  bool                   full_day;
  bool                   valid_range;
  string                 label;
  string                 raw_range;

  SessionTimeFilterConfig()
  {
    mode          = SESSION_FILTER_OFF;
    start_minutes = 0;
    end_minutes   = SESSION_TIME_FILTER_MINUTES_PER_DAY;
    wraps         = false;
    full_day      = true;
    valid_range   = true;
    label         = "";
    raw_range     = "";
  }
};

SessionTimeFilterConfig g_session_time_filter_configs[SESSION_TIME_FILTER_SLOT_TOTAL];
bool g_session_time_filter_initialized = false;

string SessionTimeFilterSlotLabel(const int slot)
{
  switch(slot)
  {
    case SESSION_TIME_FILTER_ASIA:
      return "Asia";
    case SESSION_TIME_FILTER_LONDON:
      return "London";
    case SESSION_TIME_FILTER_NEWYORK:
      return "NewYork";
  }
  return "Session";
}

void SessionTimeFilterSetFullDay(SessionTimeFilterConfig &config)
{
  config.start_minutes = 0;
  config.end_minutes   = SESSION_TIME_FILTER_MINUTES_PER_DAY;
  config.wraps         = false;
  config.full_day      = true;
}

bool SessionTimeFilterParseComponent(string fragment,
                                     int &minutes)
{
  StringTrimLeft(fragment);
  StringTrimRight(fragment);

  int delim = StringFind(fragment, ":");
  if(delim <= 0)
    return false;

  string hours_str = StringSubstr(fragment, 0, delim);
  string mins_str  = StringSubstr(fragment, delim + 1);
  if(StringLen(mins_str) <= 0)
    return false;

  int hours = (int)StringToInteger(hours_str);
  int mins  = (int)StringToInteger(mins_str);

  if(hours < 0 || hours > 23)
    return false;
  if(mins < 0 || mins > 59)
    return false;

  minutes = hours * 60 + mins;
  return true;
}

bool SessionTimeFilterParseRange(string range_str,
                                 int &start_minutes,
                                 int &end_minutes,
                                 bool &wraps,
                                 bool &full_day)
{
  start_minutes = 0;
  end_minutes   = SESSION_TIME_FILTER_MINUTES_PER_DAY;
  wraps         = false;
  full_day      = true;

  StringTrimLeft(range_str);
  StringTrimRight(range_str);
  if(StringLen(range_str) <= 0)
    return false;

  int delim = StringFind(range_str, "-");
  if(delim <= 0)
    return false;

  string start_part = StringSubstr(range_str, 0, delim);
  string end_part   = StringSubstr(range_str, delim + 1);
  if(StringLen(end_part) <= 0)
    return false;

  int parsed_start = 0;
  int parsed_end   = 0;
  if(!SessionTimeFilterParseComponent(start_part, parsed_start))
    return false;
  if(!SessionTimeFilterParseComponent(end_part, parsed_end))
    return false;

  start_minutes = parsed_start;
  end_minutes   = parsed_end;
  full_day      = (parsed_start == parsed_end);
  if(full_day)
  {
    start_minutes = 0;
    end_minutes   = SESSION_TIME_FILTER_MINUTES_PER_DAY;
  }
  wraps = (parsed_start > parsed_end);
  return true;
}

SessionTimeFilterModes SessionTimeFilterResolveMode(const int slot)
{
  switch(slot)
  {
    case SESSION_TIME_FILTER_ASIA:
      return Session_Asia_Filter_Mode;
    case SESSION_TIME_FILTER_LONDON:
      return Session_London_Filter_Mode;
    case SESSION_TIME_FILTER_NEWYORK:
      return Session_NewYork_Filter_Mode;
  }
  return SESSION_FILTER_OFF;
}

string SessionTimeFilterResolveRange(const int slot)
{
  switch(slot)
  {
    case SESSION_TIME_FILTER_ASIA:
      return Session_Asia_Filter_Time_Range;
    case SESSION_TIME_FILTER_LONDON:
      return Session_London_Filter_Time_Range;
    case SESSION_TIME_FILTER_NEWYORK:
      return Session_NewYork_Filter_Time_Range;
  }
  return "";
}

void SessionTimeFilterConfigureSlot(const int slot,
                                    SessionTimeFilterConfig &config)
{
  config.label     = SessionTimeFilterSlotLabel(slot);
  config.mode      = SessionTimeFilterResolveMode(slot);
  config.raw_range = SessionTimeFilterResolveRange(slot);
  config.valid_range = true;
  SessionTimeFilterSetFullDay(config);

  int start_minutes = 0;
  int end_minutes   = 0;
  bool wraps        = false;
  bool full_day     = false;

  bool parsed = SessionTimeFilterParseRange(config.raw_range,
                                            start_minutes,
                                            end_minutes,
                                            wraps,
                                            full_day);
  if(parsed)
  {
    config.start_minutes = start_minutes;
    config.end_minutes   = end_minutes;
    config.wraps         = wraps;
    config.full_day      = full_day;
    config.valid_range   = true;
  }
  else
  {
    SessionTimeFilterSetFullDay(config);
    config.valid_range = false;
  }
}

void SessionTimeFilterEnsureInitialized()
{
  if(g_session_time_filter_initialized)
    return;

  for(int slot = 0; slot < SESSION_TIME_FILTER_SLOT_TOTAL; slot++)
    SessionTimeFilterConfigureSlot(slot, g_session_time_filter_configs[slot]);

  g_session_time_filter_initialized = true;
}

bool SessionTimeFilterSlotEnabled(const SessionTimeFilterConfig &config)
{
  return (config.mode != SESSION_FILTER_OFF);
}

bool SessionTimeFilterMinuteInRange(const SessionTimeFilterConfig &config,
                                    const int current_minutes)
{
  if(config.full_day)
    return true;

  if(!config.wraps)
    return (current_minutes >= config.start_minutes &&
            current_minutes < config.end_minutes);

  if(current_minutes >= config.start_minutes)
    return true;
  if(current_minutes < config.end_minutes)
    return true;
  return false;
}

int SessionTimeFilterCurrentMinutes()
{
  MqlDateTime now_struct;
  datetime now_time = TimeCurrent();
  int offset_minutes = ResolveTradingTimeOffsetMinutes();
  now_time -= offset_minutes * 60;
  TimeToStruct(now_time, now_struct);
  return now_struct.hour * 60 + now_struct.min;
}

int SessionTimeFilterOffsetMinutes()
{
  return ResolveTradingTimeOffsetMinutes();
}

void SessionTimeFilterCopySlotConfig(const int slot,
                                     SessionTimeFilterConfig &out_config)
{
  SessionTimeFilterEnsureInitialized();
  int clamped_slot = slot;
  if(clamped_slot < 0)
    clamped_slot = 0;
  if(clamped_slot >= SESSION_TIME_FILTER_SLOT_TOTAL)
    clamped_slot = SESSION_TIME_FILTER_SLOT_TOTAL - 1;
  out_config = g_session_time_filter_configs[clamped_slot];
}

bool SessionTimeFilterAnyEnabled()
{
  SessionTimeFilterEnsureInitialized();
  for(int slot = 0; slot < SESSION_TIME_FILTER_SLOT_TOTAL; slot++)
  {
    if(SessionTimeFilterSlotEnabled(g_session_time_filter_configs[slot]))
      return true;
  }
  return false;
}

bool SessionTimeFilterCurrentWindowActive(int &active_slot)
{
  SessionTimeFilterEnsureInitialized();
  int current_minutes = SessionTimeFilterCurrentMinutes();
  int active = -1;
  for(int slot = 0; slot < SESSION_TIME_FILTER_SLOT_TOTAL; slot++)
  {
    SessionTimeFilterConfig config = g_session_time_filter_configs[slot];
    if(!SessionTimeFilterSlotEnabled(config))
      continue;
    if(SessionTimeFilterMinuteInRange(config, current_minutes))
    {
      active = slot;
      break;
    }
  }
  active_slot = active;
  return (active >= 0);
}

#endif // _SERVICES_TRADING_MANAGEMENT_SESSION_TIME_FILTER_CONTEXT_MQH_
