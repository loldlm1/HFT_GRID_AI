//+------------------------------------------------------------------+
//|                         pandora_box_state.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_

const int PANDORA_MINUTES_PER_DAY = 24 * 60;

struct PandoraBoxRuntimeState
{
  bool     enabled;
  bool     respect_session_filter;
  bool     visualization_enabled;
  bool     window_parsed;
  bool     window_valid;
  int      start_minutes;
  int      end_minutes;
  datetime day_anchor;
  datetime window_start_time;
  datetime window_end_time;
  bool     window_closed;
  bool     box_computed;
  bool     box_valid;
  double   box_high;
  double   box_low;
  double   box_range_points;
  double   breakout_high_price;
  double   breakout_low_price;
  double   offset_points;
  double   effective_offset_points;
  double   max_range_points;
  StrategyDirectionTypes direction_mode;
  bool     stop_on_first_win;
  bool     finished;
  bool     session_window_seen_active;
  bool     bullish_consumed;
  bool     bearish_consumed;
  bool     bullish_closed;
  bool     bearish_closed;
  string   invalid_reason;

  PandoraBoxRuntimeState()
  {
    Reset();
  }

  void Reset()
  {
    enabled                = false;
    respect_session_filter = true;
    visualization_enabled  = true;
    window_parsed          = false;
    window_valid           = false;
    start_minutes          = 0;
    end_minutes            = 0;
    day_anchor             = 0;
    window_start_time      = 0;
    window_end_time        = 0;
    window_closed          = false;
    box_computed           = false;
    box_valid              = false;
    box_high               = 0.0;
    box_low                = 0.0;
    box_range_points       = 0.0;
    breakout_high_price    = 0.0;
    breakout_low_price     = 0.0;
    offset_points          = 0.0;
    effective_offset_points = 0.0;
    max_range_points       = 0.0;
    direction_mode         = BOTH_DIRECTION;
    stop_on_first_win      = false;
    finished               = false;
    session_window_seen_active = false;
    bullish_consumed       = false;
    bearish_consumed       = false;
    bullish_closed         = false;
    bearish_closed         = false;
    invalid_reason         = "";
  }
};

PandoraBoxRuntimeState g_pandora_box_state;

bool PandoraStrategyEnabled()
{
  return Pandora_Box_Enable;
}

void PandoraResetDailyState()
{
  g_pandora_box_state.box_computed        = false;
  g_pandora_box_state.box_valid           = false;
  g_pandora_box_state.box_high            = 0.0;
  g_pandora_box_state.box_low             = 0.0;
  g_pandora_box_state.box_range_points    = 0.0;
  g_pandora_box_state.breakout_high_price = 0.0;
  g_pandora_box_state.breakout_low_price  = 0.0;
  g_pandora_box_state.bullish_consumed    = false;
  g_pandora_box_state.bearish_consumed    = false;
  g_pandora_box_state.bullish_closed      = false;
  g_pandora_box_state.bearish_closed      = false;
  g_pandora_box_state.invalid_reason      = "";
  g_pandora_box_state.window_closed       = false;
  g_pandora_box_state.effective_offset_points = 0.0;
  g_pandora_box_state.finished            = false;
  g_pandora_box_state.session_window_seen_active = false;
}

void PandoraSyncRuntimeConfig()
{
  g_pandora_box_state.enabled                = Pandora_Box_Enable;
  g_pandora_box_state.respect_session_filter = Pandora_Box_Use_Session_Filter;
  g_pandora_box_state.visualization_enabled  = Pandora_Box_Enable_Visualization;
  g_pandora_box_state.direction_mode         = Pandora_Box_Direction_Mode;
  g_pandora_box_state.offset_points          = MathMax(Pandora_Box_Offset_Points, 0.0);
  g_pandora_box_state.max_range_points       = MathMax(Pandora_Box_Max_Range_Points, 0.0);
  g_pandora_box_state.stop_on_first_win      = Pandora_Box_Stop_On_First_Win;
}

bool PandoraParseTimeComponent(string fragment,
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

bool PandoraParseWindowMinutes(string range_str,
                               int &start_minutes,
                               int &end_minutes)
{
  start_minutes = 0;
  end_minutes   = 0;

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
  if(!PandoraParseTimeComponent(start_part, parsed_start))
    return false;
  if(!PandoraParseTimeComponent(end_part, parsed_end))
    return false;

  if(parsed_start >= parsed_end)
    return false;

  start_minutes = parsed_start;
  end_minutes   = parsed_end;
  return true;
}

void PandoraEnsureDayAnchor()
{
  datetime day = ResolveCurrentDayStart();
  if(g_pandora_box_state.day_anchor != day)
  {
    g_pandora_box_state.day_anchor   = day;
    g_pandora_box_state.window_parsed = false;
    g_pandora_box_state.window_valid  = false;
    PandoraResetDailyState();
  }
}

bool PandoraEnsureWindowParsed()
{
  if(g_pandora_box_state.window_parsed)
    return g_pandora_box_state.window_valid;

  g_pandora_box_state.window_parsed = true;
  g_pandora_box_state.window_valid  = PandoraParseWindowMinutes(Pandora_Box_Time_Range,
                                                                g_pandora_box_state.start_minutes,
                                                                g_pandora_box_state.end_minutes);
  if(!g_pandora_box_state.window_valid)
  {
    g_pandora_box_state.window_start_time = 0;
    g_pandora_box_state.window_end_time   = 0;
    g_pandora_box_state.invalid_reason    = "Invalid Pandora box time range";
    return false;
  }

  int offset_minutes = ResolveTradingTimeOffsetMinutes();
  g_pandora_box_state.window_start_time = g_pandora_box_state.day_anchor +
                                          ((g_pandora_box_state.start_minutes + offset_minutes) * 60);
  g_pandora_box_state.window_end_time   = g_pandora_box_state.day_anchor +
                                          ((g_pandora_box_state.end_minutes + offset_minutes) * 60);
  return true;
}

bool PandoraDirectionAllowed(const SignalTypes direction)
{
  StrategyDirectionTypes mode = g_pandora_box_state.direction_mode;
  if(mode == BOTH_DIRECTION)
    return true;
  if(mode == BULLISH_DIRECTION)
    return (direction == BULLISH);
  if(mode == BEARISH_DIRECTION)
    return (direction == BEARISH);
  return true;
}

bool PandoraSideConsumed(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_consumed;
  return g_pandora_box_state.bearish_consumed;
}

bool PandoraDailyCompleted()
{
  if(g_pandora_box_state.finished)
    return true;
  if(!Pandora_Box_Stop_After_Sides)
    return false;
  StrategyDirectionTypes mode = g_pandora_box_state.direction_mode;
  if(mode == BOTH_DIRECTION)
    return g_pandora_box_state.bullish_consumed && g_pandora_box_state.bearish_consumed;
  if(mode == BULLISH_DIRECTION)
    return g_pandora_box_state.bullish_consumed;
  if(mode == BEARISH_DIRECTION)
    return g_pandora_box_state.bearish_consumed;
  return false;
}

void PandoraMarkSideTriggered(const SignalTypes direction)
{
  if(direction == BULLISH)
    g_pandora_box_state.bullish_consumed = true;
  else
    g_pandora_box_state.bearish_consumed = true;
}

void PandoraMarkSideClosed(const SignalTypes direction)
{
  if(direction == BULLISH)
    g_pandora_box_state.bullish_closed = true;
  else
    g_pandora_box_state.bearish_closed = true;
}

void PandoraRegisterSideOutcome(const SignalTypes direction,
                                const double raw_profit)
{
  PandoraMarkSideClosed(direction);
  if(raw_profit > 0.0 && g_pandora_box_state.stop_on_first_win)
  {
    g_pandora_box_state.finished = true;
    return;
  }

  if(PandoraDailyCompleted())
    g_pandora_box_state.finished = true;
}

bool PandoraFinishedForDay()
{
  if(g_pandora_box_state.finished)
    return true;
  return PandoraDailyCompleted();
}

bool PandoraWindowCompleted()
{
  if(!g_pandora_box_state.window_valid)
    return false;

  datetime now_time = TimeCurrent();
  g_pandora_box_state.window_closed = (g_pandora_box_state.window_end_time > 0 &&
                                       now_time >= g_pandora_box_state.window_end_time);
  return g_pandora_box_state.window_closed;
}

bool PandoraBoxReady()
{
  if(!g_pandora_box_state.enabled)
    return false;
  if(!g_pandora_box_state.box_computed)
    return false;
  if(!g_pandora_box_state.box_valid)
    return false;
  if(PandoraDailyCompleted())
    return false;
  return true;
}

bool PandoraVisualizationEnabled()
{
  return g_pandora_box_state.enabled && g_pandora_box_state.visualization_enabled;
}

string PandoraWindowLabel()
{
  if(!g_pandora_box_state.window_valid)
    return Pandora_Box_Time_Range;
  return StringFormat("%02d:%02d-%02d:%02d",
                      g_pandora_box_state.start_minutes / 60,
                      g_pandora_box_state.start_minutes % 60,
                      g_pandora_box_state.end_minutes / 60,
                      g_pandora_box_state.end_minutes % 60);
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
