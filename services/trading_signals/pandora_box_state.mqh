//+------------------------------------------------------------------+
//|                         pandora_box_state.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_

const int PANDORA_MINUTES_PER_DAY = 24 * 60;
const double PANDORA_EPSILON_EXTREME_BOX_RATIO = 5.0;
const int PANDORA_HISTORY_DAYS = 8;
const string PANDORA_INVALID_PREVIOUS_D1_ANCHOR = "No previous D1 anchor for Pandora wrapped window";

struct PandoraBoxRuntimeState
{
  bool     enabled;
  bool     respect_session_filter;
  bool     visualization_enabled;
  bool     window_parsed;
  bool     window_valid;
  int      start_minutes;
  int      end_minutes;
  bool     window_wraps;
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
  PandoraEntryCountModes entry_count_mode;
  int      max_entries;
  int      counted_entries;
  int      total_entries;
  int      closed_entries;
  bool     finished;
  bool     session_window_seen_active;
  bool     bullish_rearm_required;
  bool     bearish_rearm_required;
  bool     bullish_rearm_ready;
  bool     bearish_rearm_ready;
  datetime last_rearm_close_bar_time;
  string   invalid_reason;

  PandoraBoxRuntimeState()
  {
    Reset();
  }

  void Reset()
  {
    enabled                   = false;
    respect_session_filter    = true;
    visualization_enabled     = true;
    window_parsed             = false;
    window_valid              = false;
    start_minutes             = 0;
    end_minutes               = 0;
    window_wraps              = false;
    day_anchor                = 0;
    window_start_time         = 0;
    window_end_time           = 0;
    window_closed             = false;
    box_computed              = false;
    box_valid                 = false;
    box_high                  = 0.0;
    box_low                   = 0.0;
    box_range_points          = 0.0;
    breakout_high_price       = 0.0;
    breakout_low_price        = 0.0;
    offset_points             = 0.0;
    effective_offset_points   = 0.0;
    max_range_points          = 0.0;
    direction_mode            = BOTH_DIRECTION;
    stop_on_first_win         = false;
    entry_count_mode          = COUNT_BOX_ENTRY_OFF;
    max_entries               = 0;
    counted_entries           = 0;
    total_entries             = 0;
    closed_entries            = 0;
    finished                  = false;
    session_window_seen_active = false;
    bullish_rearm_required    = false;
    bearish_rearm_required    = false;
    bullish_rearm_ready       = false;
    bearish_rearm_ready       = false;
    last_rearm_close_bar_time = 0;
    invalid_reason            = "";
  }
};

struct PandoraHistorySnapshot
{
  datetime day_anchor;
  datetime window_start_time;
  datetime window_end_time;
  datetime data_end_time;
  bool     is_current_day;
  bool     window_valid;
  bool     box_computed;
  bool     box_valid;
  double   box_high;
  double   box_low;
  double   box_range_points;
  double   breakout_high_price;
  double   breakout_low_price;
  string   invalid_reason;

  PandoraHistorySnapshot()
  {
    Reset();
  }

  PandoraHistorySnapshot(const PandoraHistorySnapshot &snapshot)
  {
    day_anchor          = snapshot.day_anchor;
    window_start_time   = snapshot.window_start_time;
    window_end_time     = snapshot.window_end_time;
    data_end_time       = snapshot.data_end_time;
    is_current_day      = snapshot.is_current_day;
    window_valid        = snapshot.window_valid;
    box_computed        = snapshot.box_computed;
    box_valid           = snapshot.box_valid;
    box_high            = snapshot.box_high;
    box_low             = snapshot.box_low;
    box_range_points    = snapshot.box_range_points;
    breakout_high_price = snapshot.breakout_high_price;
    breakout_low_price  = snapshot.breakout_low_price;
    invalid_reason      = snapshot.invalid_reason;
  }

  void Reset()
  {
    day_anchor          = 0;
    window_start_time   = 0;
    window_end_time     = 0;
    data_end_time       = 0;
    is_current_day      = false;
    window_valid        = false;
    box_computed        = false;
    box_valid           = false;
    box_high            = 0.0;
    box_low             = 0.0;
    box_range_points    = 0.0;
    breakout_high_price = 0.0;
    breakout_low_price  = 0.0;
    invalid_reason      = "";
  }
};

PandoraBoxRuntimeState g_pandora_box_state;
PandoraHistorySnapshot g_pandora_history_snapshots[];
datetime               g_pandora_history_last_day_anchor = 0;
datetime               g_pandora_history_last_previous_day_anchor = 0;
datetime               g_pandora_history_last_oldest_anchor = 0;
datetime               g_pandora_history_last_bar_time = 0;
string                 g_pandora_history_last_signature = "";

bool PandoraStrategyEnabled()
{
  return Pandora_Box_Enable;
}

ENUM_TIMEFRAMES PandoraResolveBoxTimeframe()
{
  ENUM_TIMEFRAMES tf = Strategy_Timeframe;
  if(tf == PERIOD_CURRENT)
    tf = PERIOD_M1;
  if(!IsStrategyTimeframeSupported(tf))
    tf = PERIOD_M1;
  return tf;
}

bool IsPandoraSignal(const SignalParams &signal_params)
{
  return (signal_params.strategy_context_label == "PANDORA");
}

double PandoraResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

void PandoraResetDailyState()
{
  g_pandora_box_state.box_computed            = false;
  g_pandora_box_state.box_valid               = false;
  g_pandora_box_state.box_high                = 0.0;
  g_pandora_box_state.box_low                 = 0.0;
  g_pandora_box_state.box_range_points        = 0.0;
  g_pandora_box_state.breakout_high_price     = 0.0;
  g_pandora_box_state.breakout_low_price      = 0.0;
  g_pandora_box_state.invalid_reason          = "";
  g_pandora_box_state.window_closed           = false;
  g_pandora_box_state.window_wraps            = false;
  g_pandora_box_state.effective_offset_points = 0.0;
  g_pandora_box_state.finished                = false;
  g_pandora_box_state.session_window_seen_active = false;
  g_pandora_box_state.counted_entries         = 0;
  g_pandora_box_state.total_entries           = 0;
  g_pandora_box_state.closed_entries          = 0;
  g_pandora_box_state.bullish_rearm_required  = false;
  g_pandora_box_state.bearish_rearm_required  = false;
  g_pandora_box_state.bullish_rearm_ready     = false;
  g_pandora_box_state.bearish_rearm_ready     = false;
  g_pandora_box_state.last_rearm_close_bar_time = 0;
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
  g_pandora_box_state.entry_count_mode       = Pandora_Box_Entry_Count_Mode;
  g_pandora_box_state.max_entries            = MathMax(Pandora_Box_Max_Entries, 0);
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

// Pandora wrapped windows are owned by the day they close. When start > end,
// the start side uses the last known closed D1 candle anchor.
bool PandoraParseWindowMinutes(string range_str,
                               int &start_minutes,
                               int &end_minutes,
                               bool &wraps)
{
  start_minutes = 0;
  end_minutes   = 0;
  wraps          = false;

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

  if(parsed_start == parsed_end)
    return false;

  start_minutes = parsed_start;
  end_minutes   = parsed_end;
  wraps          = (parsed_start > parsed_end);
  return true;
}

bool PandoraResolveWindowTimes(const datetime close_day_anchor,
                               const datetime previous_day_anchor,
                               const int start_minutes,
                               const int end_minutes,
                               const bool wraps,
                               datetime &window_start_time,
                               datetime &window_end_time,
                               string &invalid_reason)
{
  window_start_time = 0;
  window_end_time   = 0;
  invalid_reason    = "";

  if(close_day_anchor <= 0)
  {
    invalid_reason = "Invalid Pandora close day anchor";
    return false;
  }

  datetime start_day_anchor = close_day_anchor;
  if(wraps)
  {
    if(previous_day_anchor <= 0)
    {
      invalid_reason = PANDORA_INVALID_PREVIOUS_D1_ANCHOR;
      return false;
    }
    start_day_anchor = previous_day_anchor;
  }

  int start_offset_minutes = ResolveTradingTimeOffsetMinutesAt(start_day_anchor);
  int end_offset_minutes   = ResolveTradingTimeOffsetMinutesAt(close_day_anchor);

  window_start_time = start_day_anchor +
                      ((start_minutes + start_offset_minutes) * 60);
  window_end_time   = close_day_anchor +
                      ((end_minutes + end_offset_minutes) * 60);

  if(window_start_time >= window_end_time)
  {
    invalid_reason = "Invalid resolved Pandora box window";
    window_start_time = 0;
    window_end_time   = 0;
    return false;
  }

  return true;
}

void PandoraEnsureDayAnchor()
{
  datetime day = ResolveCurrentDayStart();
  if(g_pandora_box_state.day_anchor != day)
  {
    g_pandora_box_state.day_anchor    = day;
    g_pandora_box_state.window_parsed = false;
    g_pandora_box_state.window_valid  = false;
    PandoraResetDailyState();
  }
}

bool PandoraEnsureWindowParsed()
{
  if(g_pandora_box_state.window_parsed)
  {
    if(g_pandora_box_state.window_valid)
      return true;

    if(g_pandora_box_state.window_wraps &&
       g_pandora_box_state.invalid_reason == PANDORA_INVALID_PREVIOUS_D1_ANCHOR &&
       iTime(_Symbol, PERIOD_D1, 1) > 0)
    {
      g_pandora_box_state.window_parsed = false;
    }
    else
    {
      return false;
    }
  }

  g_pandora_box_state.window_parsed = true;
  g_pandora_box_state.window_valid  = PandoraParseWindowMinutes(Pandora_Box_Time_Range,
                                                                g_pandora_box_state.start_minutes,
                                                                g_pandora_box_state.end_minutes,
                                                                g_pandora_box_state.window_wraps);
  if(!g_pandora_box_state.window_valid)
  {
    g_pandora_box_state.window_start_time = 0;
    g_pandora_box_state.window_end_time   = 0;
    g_pandora_box_state.window_wraps      = false;
    g_pandora_box_state.invalid_reason    = "Invalid Pandora box time range";
    return false;
  }

  datetime previous_day_anchor = 0;
  if(g_pandora_box_state.window_wraps)
    previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);

  string invalid_reason = "";
  g_pandora_box_state.window_valid = PandoraResolveWindowTimes(g_pandora_box_state.day_anchor,
                                                               previous_day_anchor,
                                                               g_pandora_box_state.start_minutes,
                                                               g_pandora_box_state.end_minutes,
                                                               g_pandora_box_state.window_wraps,
                                                               g_pandora_box_state.window_start_time,
                                                               g_pandora_box_state.window_end_time,
                                                               invalid_reason);
  if(!g_pandora_box_state.window_valid)
  {
    g_pandora_box_state.invalid_reason = invalid_reason;
    if(g_pandora_box_state.invalid_reason == "")
      g_pandora_box_state.invalid_reason = "Invalid Pandora box time range";
    return false;
  }

  g_pandora_box_state.invalid_reason = "";
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

bool PandoraDirectionHasActiveSignal(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    int total_bullish = ArraySize(running_bullish_signals);
    for(int i = total_bullish - 1; i >= 0; i--)
    {
      if(!IsPandoraSignal(running_bullish_signals[i]))
        continue;
      if(running_bullish_signals[i].signal_state != CLOSED)
        return true;
    }
    return false;
  }

  int total_bearish = ArraySize(running_bearish_signals);
  for(int j = total_bearish - 1; j >= 0; j--)
  {
    if(!IsPandoraSignal(running_bearish_signals[j]))
      continue;
    if(running_bearish_signals[j].signal_state != CLOSED)
      return true;
  }
  return false;
}

bool PandoraHasActiveSignals()
{
  if(PandoraDirectionHasActiveSignal(BULLISH))
    return true;
  return PandoraDirectionHasActiveSignal(BEARISH);
}

string PandoraLimitLabel()
{
  if(g_pandora_box_state.max_entries > 0)
    return IntegerToString(g_pandora_box_state.max_entries);
  return "INF";
}

bool PandoraEntryBudgetReached()
{
  if(g_pandora_box_state.max_entries <= 0)
    return false;
  return (g_pandora_box_state.total_entries >= g_pandora_box_state.max_entries);
}

bool PandoraCloseBudgetReached()
{
  if(g_pandora_box_state.max_entries <= 0)
    return false;
  return (g_pandora_box_state.closed_entries >= g_pandora_box_state.max_entries);
}

bool PandoraDailyCompleted()
{
  if(g_pandora_box_state.finished)
    return true;
  if(!PandoraEntryBudgetReached())
    return false;
  if(!PandoraCloseBudgetReached())
    return false;
  return !PandoraHasActiveSignals();
}

bool PandoraWaitClosePending()
{
  if(!PandoraEntryBudgetReached())
    return false;
  return !PandoraDailyCompleted();
}

bool PandoraDirectionNeedsRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_rearm_required;
  return g_pandora_box_state.bearish_rearm_required;
}

bool PandoraDirectionRearmReady(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_rearm_ready;
  return g_pandora_box_state.bearish_rearm_ready;
}

void PandoraClearDirectionRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    g_pandora_box_state.bullish_rearm_required = false;
    g_pandora_box_state.bullish_rearm_ready    = false;
  }
  else
  {
    g_pandora_box_state.bearish_rearm_required = false;
    g_pandora_box_state.bearish_rearm_ready    = false;
  }
}

void PandoraRequireDirectionRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    g_pandora_box_state.bullish_rearm_required = true;
    g_pandora_box_state.bullish_rearm_ready    = false;
  }
  else
  {
    g_pandora_box_state.bearish_rearm_required = true;
    g_pandora_box_state.bearish_rearm_ready    = false;
  }
}

bool PandoraPreviousCloseInsideBox()
{
  if(!g_pandora_box_state.box_valid)
    return false;

  ENUM_TIMEFRAMES tf = PandoraResolveBoxTimeframe();
  double close_1 = iClose(_Symbol, tf, 1);
  if(close_1 <= 0.0)
    return false;

  return (close_1 >= g_pandora_box_state.box_low &&
          close_1 <= g_pandora_box_state.box_high);
}

void PandoraRefreshRearmState()
{
  if(!g_pandora_box_state.window_closed ||
     !g_pandora_box_state.box_computed ||
     !g_pandora_box_state.box_valid)
    return;

  if(!g_pandora_box_state.bullish_rearm_required &&
     !g_pandora_box_state.bearish_rearm_required)
    return;

  ENUM_TIMEFRAMES tf = PandoraResolveBoxTimeframe();
  datetime close_bar_time = iTime(_Symbol, tf, 1);
  if(close_bar_time <= 0)
    return;

  if(g_pandora_box_state.last_rearm_close_bar_time == close_bar_time)
    return;

  g_pandora_box_state.last_rearm_close_bar_time = close_bar_time;
  if(!PandoraPreviousCloseInsideBox())
    return;

  if(g_pandora_box_state.bullish_rearm_required)
    g_pandora_box_state.bullish_rearm_ready = true;
  if(g_pandora_box_state.bearish_rearm_required)
    g_pandora_box_state.bearish_rearm_ready = true;
}

bool PandoraDirectionReadyForEntry(const SignalTypes direction)
{
  if(PandoraDirectionHasActiveSignal(direction))
    return false;

  if(!PandoraDirectionNeedsRearm(direction))
    return true;

  return PandoraDirectionRearmReady(direction);
}

void PandoraRegisterEntryTriggered(const SignalTypes direction)
{
  g_pandora_box_state.total_entries++;
  PandoraClearDirectionRearm(direction);

  if(!Enable_Logs)
    return;

  string limit_label = PandoraLimitLabel();
  PrintFormat("PANDORA_ENTRY_OPEN dir=%s open=%d/%s close=%d/%s counted=%d/%s",
              EnumToString(direction),
              g_pandora_box_state.total_entries,
              limit_label,
              g_pandora_box_state.closed_entries,
              limit_label,
              g_pandora_box_state.counted_entries,
              limit_label);

  if(PandoraEntryBudgetReached())
  {
    PrintFormat("PANDORA_BUDGET_REACHED open=%d/%s close=%d/%s active=%s",
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                PandoraHasActiveSignals() ? "true" : "false");
    if(PandoraWaitClosePending())
      PrintFormat("PANDORA_WAIT_CLOSE open=%d/%s close=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label);
  }
}

bool PandoraOutcomeCountsEntry(const PandoraCloseOutcomes outcome)
{
  if(outcome == PANDORA_CLOSE_NONE)
    return false;

  if(g_pandora_box_state.entry_count_mode == COUNT_BOX_ENTRY_ON_SL)
    return (outcome == PANDORA_CLOSE_SL || outcome == PANDORA_CLOSE_BE);

  if(g_pandora_box_state.entry_count_mode == COUNT_BOX_ENTRY_ON_TP)
    return (outcome == PANDORA_CLOSE_TP || outcome == PANDORA_CLOSE_BE);

  return (outcome == PANDORA_CLOSE_SL ||
          outcome == PANDORA_CLOSE_TP ||
          outcome == PANDORA_CLOSE_BE);
}

bool PandoraRiskStepTrailingEnabled()
{
  return (Pandora_Risk_Trailing_Mode == PANDORA_RISK_TRAILING_STEP_TP);
}

double PandoraResolveConfiguredDistancePoints(const double configured_value,
                                              const bool enforce_broker_distance)
{
  return PandoraResolveDistancePointsForRange(configured_value,
                                              g_pandora_box_state.box_range_points,
                                              enforce_broker_distance);
}

double PandoraResolveDistancePointsForRange(const double configured_value,
                                            const double box_range_points,
                                            const bool enforce_broker_distance)
{
  double requested_points = MathMax(configured_value, 0.0);
  if(requested_points <= 0.0)
    return 0.0;

  if(Pandora_Points_Value_Mode == PANDORA_VALUE_MODE_BOX_PERCENT)
  {
    if(box_range_points <= 0.0)
      return 0.0;
    requested_points = box_range_points * (requested_points / 100.0);
  }

  if(requested_points <= 0.0)
    return 0.0;

  if(enforce_broker_distance)
    return EnforceBrokerDistance(g_symbol_constraints, requested_points);
  return requested_points;
}

double PandoraResolveConfiguredSLPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Points_SL,
                                                enforce_broker_distance);
}

double PandoraResolveConfiguredTPPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Points_TP,
                                                enforce_broker_distance);
}

double PandoraResolveConfiguredOffsetPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Box_Offset_Points,
                                                enforce_broker_distance);
}

double PandoraResolveSignalSLPoints(const SignalParams &signal_params,
                                    const bool enforce_broker_distance = true)
{
  double cached_points = signal_params.pandora_sl_points;
  if(cached_points > 0.0)
    return cached_points;
  return PandoraResolveConfiguredSLPoints(enforce_broker_distance);
}

double PandoraResolveSignalTPPoints(const SignalParams &signal_params,
                                    const bool enforce_broker_distance = true)
{
  double cached_points = signal_params.pandora_tp_points;
  if(cached_points > 0.0)
    return cached_points;
  return PandoraResolveConfiguredTPPoints(enforce_broker_distance);
}

double PandoraResolveSignalTrailingStepPoints(const SignalParams &signal_params)
{
  if(signal_params.pandora_trailing_step_points > 0.0)
    return signal_params.pandora_trailing_step_points;
  return PandoraResolveSignalSLPoints(signal_params, true);
}

bool PandoraResolveBrokerStops(const SignalParams &signal_params,
                               const GridOrderState &order_state,
                               double &sl_price,
                               double &tp_price)
{
  sl_price = 0.0;
  tp_price = 0.0;
  if(!IsPandoraSignal(signal_params))
    return false;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    return false;

  double entry_ref = order_state.entry_price;
  if(entry_ref <= 0.0)
    entry_ref = order_state.entry_reference_price;
  if(entry_ref <= 0.0)
    entry_ref = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(entry_ref <= 0.0)
    return false;

  bool step_trailing = PandoraRiskStepTrailingEnabled();
  double sl_points = PandoraResolveSignalSLPoints(signal_params, true);
  double tp_points = step_trailing ? 0.0 : PandoraResolveSignalTPPoints(signal_params, true);
  if(sl_points <= 0.0 && signal_params.pandora_trailing_stop_price <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
  {
    sl_price = (signal_params.pandora_trailing_stop_price > 0.0)
                 ? signal_params.pandora_trailing_stop_price
                 : entry_ref - sl_points * point_size;
    tp_price = (tp_points > 0.0) ? entry_ref + tp_points * point_size : 0.0;
  }
  else
  {
    sl_price = (signal_params.pandora_trailing_stop_price > 0.0)
                 ? signal_params.pandora_trailing_stop_price
                 : entry_ref + sl_points * point_size;
    tp_price = (tp_points > 0.0) ? entry_ref - tp_points * point_size : 0.0;
  }

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  sl_price = NormalizeDouble(sl_price, digits);
  tp_price = NormalizeDouble(tp_price, digits);
  return true;
}

double PandoraResolveSignalEpsilonPoints(const SignalParams &signal_params)
{
  double sl_points = PandoraResolveSignalSLPoints(signal_params, true);
  double tp_points = PandoraResolveSignalTPPoints(signal_params, true);
  if(PandoraRiskStepTrailingEnabled())
    tp_points = 0.0;

  double trade_ref_points = MathMax(sl_points, tp_points);
  double box_range_points = MathMax(g_pandora_box_state.box_range_points, 0.0);
  double raw_ref_points = MathMax(trade_ref_points, box_range_points);
  if(raw_ref_points <= 0.0)
    raw_ref_points = MathMax(sl_points, 1.0);
  if(trade_ref_points <= 0.0)
    trade_ref_points = raw_ref_points;

  double structural_points = 0.01 * raw_ref_points;

  double spread_floor = 0.20 * MathMax(g_points_spread, 0.0);
  double freeze_floor = 0.10 * MathMax(g_symbol_constraints.freeze_level_points +
                                       g_symbol_constraints.stops_level_points,
                                       0.0);

  double min_stop_points = g_symbol_constraints.min_stop_distance_points;
  if(min_stop_points <= 0.0)
    min_stop_points = MinBrokerDistancePoints(g_symbol_constraints);
  double min_stop_floor = 0.25 * MathMax(min_stop_points, 0.0);

  double execution_floor = MathMax(2.0,
                                   MathMax(spread_floor,
                                           MathMax(freeze_floor, min_stop_floor)));

  double box_ratio = 0.0;
  if(trade_ref_points > 0.0)
    box_ratio = box_range_points / trade_ref_points;
  bool is_extreme_box = (box_ratio >= PANDORA_EPSILON_EXTREME_BOX_RATIO);

  double cap_points = is_extreme_box
                      ? MathMax(5.0, 0.10 * trade_ref_points)
                      : MathMax(5.0, 0.20 * trade_ref_points);

  double bounded_structural = MathMin(structural_points, cap_points);
  double epsilon_points = MathCeil(MathMax(execution_floor, bounded_structural));
  if(epsilon_points < 1.0)
    epsilon_points = 1.0;

  return epsilon_points;
}

double PandoraResolveSignalEpsilonMoney(const SignalParams &signal_params,
                                        const GridOrderState &order_state,
                                        const double epsilon_points)
{
  if(epsilon_points <= 0.0)
    return 0.0;

  double volume = order_state.lot_size;
  if(volume <= 0.0)
    volume = signal_params.lot_size;
  if(volume <= 0.0)
    volume = NormalizeVolumeForSymbol(_Symbol, Pandora_Lot_Strategy_Size);
  if(volume <= 0.0)
    return 0.0;

  double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  if(tick_value <= 0.0 || tick_size <= 0.0 || point_size <= 0.0)
    return 0.0;

  double point_value_per_lot = tick_value * (point_size / tick_size);
  if(point_value_per_lot <= 0.0)
    return 0.0;

  return epsilon_points * point_value_per_lot * volume;
}

double PandoraResolveOutcomeEntryAnchorPrice(const SignalParams &signal_params,
                                             const GridOrderState &order_state)
{
  double entry_anchor = order_state.entry_price;
  if(entry_anchor <= 0.0)
    entry_anchor = signal_params.entry_price;
  if(entry_anchor <= 0.0)
    entry_anchor = order_state.entry_reference_price;
  return entry_anchor;
}

double PandoraResolveStopAnchorPrice(const SignalParams &signal_params,
                                     const GridOrderState &order_state,
                                     const double entry_anchor,
                                     const double point_size)
{
  if(point_size <= 0.0 || entry_anchor <= 0.0)
    return 0.0;

  if(signal_params.pandora_trailing_stop_price > 0.0)
    return signal_params.pandora_trailing_stop_price;

  double sl_points = PandoraResolveSignalSLPoints(signal_params, true);
  if(sl_points <= 0.0)
    return 0.0;

  if(signal_params.signal_type == BULLISH)
    return entry_anchor - sl_points * point_size;
  return entry_anchor + sl_points * point_size;
}

double PandoraResolveTakeProfitAnchorPrice(const SignalParams &signal_params,
                                           const GridOrderState &order_state,
                                           const double entry_anchor,
                                           const double point_size)
{
  if(order_state.take_profit_price > 0.0)
    return order_state.take_profit_price;

  if(PandoraRiskStepTrailingEnabled())
    return 0.0;

  double tp_points = PandoraResolveSignalTPPoints(signal_params, true);
  if(tp_points <= 0.0 || point_size <= 0.0 || entry_anchor <= 0.0)
    return 0.0;

  if(signal_params.signal_type == BULLISH)
    return entry_anchor + tp_points * point_size;
  return entry_anchor - tp_points * point_size;
}

PandoraCloseOutcomes PandoraResolveOutcomeFromDealProfit(const double deal_profit)
{
  if(deal_profit > 0.0)
    return PANDORA_CLOSE_TP;
  if(deal_profit < 0.0)
    return PANDORA_CLOSE_SL;
  return PANDORA_CLOSE_BE;
}

PandoraCloseOutcomes PandoraResolveHistoryOutcomeByPosition(const ulong position_ticket)
{
  if(position_ticket <= 0)
    return PANDORA_CLOSE_NONE;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 5 * 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return PANDORA_CLOSE_NONE;

  int total_deals = HistoryDealsTotal();
  datetime latest_time = 0;
  PandoraCloseOutcomes resolved = PANDORA_CLOSE_NONE;

  for(int i = total_deals - 1; i >= 0; i--)
  {
    ulong ticket = HistoryDealGetTicket(i);
    if(ticket <= 0)
      continue;

    ulong deal_position = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
    if(deal_position != position_ticket)
      continue;

    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
    if(deal_time < latest_time)
      continue;

    latest_time = deal_time;
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
    if(reason == DEAL_REASON_TP)
      resolved = PANDORA_CLOSE_TP;
    else if(reason == DEAL_REASON_SO)
      resolved = PANDORA_CLOSE_SL;
    else if(reason == DEAL_REASON_SL)
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
    else
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
  }

  return resolved;
}

PandoraCloseOutcomes PandoraResolveHistoryOutcomeByComment(const string position_comment)
{
  if(position_comment == "")
    return PANDORA_CLOSE_NONE;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 5 * 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return PANDORA_CLOSE_NONE;

  int total_deals = HistoryDealsTotal();
  datetime latest_time = 0;
  PandoraCloseOutcomes resolved = PANDORA_CLOSE_NONE;

  for(int i = total_deals - 1; i >= 0; i--)
  {
    ulong ticket = HistoryDealGetTicket(i);
    if(ticket <= 0)
      continue;

    string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
    if(deal_symbol != _Symbol)
      continue;

    long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
    if(deal_magic != g_magic_number)
      continue;

    string deal_comment = HistoryDealGetString(ticket, DEAL_COMMENT);
    if(deal_comment != position_comment)
      continue;

    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
    if(deal_time < latest_time)
      continue;

    latest_time = deal_time;
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
    if(reason == DEAL_REASON_TP)
      resolved = PANDORA_CLOSE_TP;
    else if(reason == DEAL_REASON_SO)
      resolved = PANDORA_CLOSE_SL;
    else if(reason == DEAL_REASON_SL)
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
    else
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
  }

  return resolved;
}

PandoraCloseOutcomes PandoraResolveSignalCloseOutcome(const SignalParams &signal_params,
                                                      const double close_price,
                                                      const double raw_profit,
                                                      double &epsilon_points_out)
{
  epsilon_points_out = 0.0;

  if(!IsPandoraSignal(signal_params))
    return PANDORA_CLOSE_NONE;

  if(signal_params.pandora_close_outcome != PANDORA_CLOSE_NONE)
  {
    epsilon_points_out = signal_params.pandora_close_epsilon_points;
    return signal_params.pandora_close_outcome;
  }

  int last_index = ArraySize(signal_params.grid_orders) - 1;
  if(last_index < 0)
  {
    if(raw_profit > 0.0)
      return PANDORA_CLOSE_TP;
    if(raw_profit < 0.0)
      return PANDORA_CLOSE_SL;
    return PANDORA_CLOSE_BE;
  }

  GridOrderState order_state = signal_params.grid_orders[last_index];
  if(order_state.position_ticket > 0)
  {
    PandoraCloseOutcomes history_outcome = PandoraResolveHistoryOutcomeByPosition(order_state.position_ticket);
    if(history_outcome != PANDORA_CLOSE_NONE)
      return history_outcome;
  }

  double point_size = GridResolvePointSize();
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  epsilon_points_out = PandoraResolveSignalEpsilonPoints(signal_params);
  double epsilon_price = epsilon_points_out * point_size;

  double entry_anchor = PandoraResolveOutcomeEntryAnchorPrice(signal_params, order_state);
  double be_anchor = entry_anchor;
  double sl_anchor = PandoraResolveStopAnchorPrice(signal_params,
                                                   order_state,
                                                   entry_anchor,
                                                   point_size);
  double tp_anchor = PandoraResolveTakeProfitAnchorPrice(signal_params,
                                                         order_state,
                                                         entry_anchor,
                                                         point_size);

  if(be_anchor > 0.0 && close_price > 0.0 &&
     MathAbs(close_price - be_anchor) <= epsilon_price)
  {
    return PANDORA_CLOSE_BE;
  }

  if(tp_anchor > 0.0 && close_price > 0.0)
  {
    if(signal_params.signal_type == BULLISH && close_price >= (tp_anchor - epsilon_price))
      return PANDORA_CLOSE_TP;
    if(signal_params.signal_type == BEARISH && close_price <= (tp_anchor + epsilon_price))
      return PANDORA_CLOSE_TP;
  }

  if(sl_anchor > 0.0 && close_price > 0.0)
  {
    bool hit_stop = false;
    if(signal_params.signal_type == BULLISH)
      hit_stop = (close_price <= (sl_anchor + epsilon_price));
    else
      hit_stop = (close_price >= (sl_anchor - epsilon_price));

    if(hit_stop)
    {
      if(entry_anchor > 0.0)
      {
        if(signal_params.signal_type == BULLISH && sl_anchor > (entry_anchor + epsilon_price))
          return PANDORA_CLOSE_TP;
        if(signal_params.signal_type == BEARISH && sl_anchor < (entry_anchor - epsilon_price))
          return PANDORA_CLOSE_TP;
      }
      return PANDORA_CLOSE_SL;
    }
  }

  double epsilon_money = PandoraResolveSignalEpsilonMoney(signal_params,
                                                          order_state,
                                                          epsilon_points_out);
  if(epsilon_money <= 0.0)
    epsilon_money = 0.01;

  if(MathAbs(raw_profit) <= epsilon_money)
    return PANDORA_CLOSE_BE;
  if(raw_profit > epsilon_money)
    return PANDORA_CLOSE_TP;
  if(raw_profit < -epsilon_money)
    return PANDORA_CLOSE_SL;

  return PANDORA_CLOSE_BE;
}

void PandoraFinalizeSignalOutcome(SignalParams &signal_params,
                                  const double close_price,
                                  const double raw_profit)
{
  if(!IsPandoraSignal(signal_params))
    return;

  double epsilon_points = 0.0;
  PandoraCloseOutcomes outcome = PandoraResolveSignalCloseOutcome(signal_params,
                                                                  close_price,
                                                                  raw_profit,
                                                                  epsilon_points);
  signal_params.pandora_close_outcome = outcome;
  signal_params.pandora_close_epsilon_points = epsilon_points;
}

void PandoraRegisterSideOutcome(const SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;

  PandoraRequireDirectionRearm(signal_params.signal_type);
  g_pandora_box_state.closed_entries++;

  if(signal_params.raw_profit > 0.0 && g_pandora_box_state.stop_on_first_win)
  {
    g_pandora_box_state.finished = true;
    if(Enable_Logs)
    {
      string limit_label = PandoraLimitLabel();
      PrintFormat("PANDORA_DONE_FIRST_WIN open=%d/%s close=%d/%s counted=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label,
                  g_pandora_box_state.counted_entries,
                  limit_label);
    }
    return;
  }

  if(PandoraOutcomeCountsEntry(signal_params.pandora_close_outcome))
    g_pandora_box_state.counted_entries++;

  if(Enable_Logs)
  {
    string limit_label = PandoraLimitLabel();
    PrintFormat("PANDORA_ENTRY_CLOSE dir=%s outcome=%s open=%d/%s close=%d/%s counted=%d/%s",
                EnumToString(signal_params.signal_type),
                EnumToString(signal_params.pandora_close_outcome),
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }

  if(PandoraDailyCompleted())
  {
    g_pandora_box_state.finished = true;
    if(Enable_Logs)
    {
      string limit_label = PandoraLimitLabel();
      PrintFormat("PANDORA_DONE open=%d/%s close=%d/%s counted=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label,
                  g_pandora_box_state.counted_entries,
                  limit_label);
    }
    return;
  }

  if(PandoraWaitClosePending() && Enable_Logs)
  {
    string limit_label = PandoraLimitLabel();
    PrintFormat("PANDORA_WAIT_CLOSE open=%d/%s close=%d/%s counted=%d/%s",
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }
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

string PandoraHistoryConfigSignature()
{
  return StringFormat("%s|%d|%d|%d|%d|%.4f|%.4f|%d",
                      Pandora_Box_Time_Range,
                      (int)PandoraResolveBoxTimeframe(),
                      (int)Session_Time_Dst_Mode,
                      Session_Time_Dst_Manual_Offset_Minutes,
                      ResolveTradingTimeOffsetMinutes(),
                      Pandora_Box_Offset_Points,
                      Pandora_Box_Max_Range_Points,
                      (int)Pandora_Points_Value_Mode);
}

void PandoraClearHistorySnapshots()
{
  ArrayResize(g_pandora_history_snapshots, 0);
  g_pandora_history_last_day_anchor          = 0;
  g_pandora_history_last_previous_day_anchor = 0;
  g_pandora_history_last_oldest_anchor       = 0;
  g_pandora_history_last_bar_time            = 0;
  g_pandora_history_last_signature           = "";
}

bool PandoraResolveWindowForDay(const datetime day_anchor,
                                const datetime previous_day_anchor,
                                datetime &window_start_time,
                                datetime &window_end_time,
                                string &invalid_reason)
{
  int start_minutes = 0;
  int end_minutes   = 0;
  bool wraps         = false;
  if(!PandoraParseWindowMinutes(Pandora_Box_Time_Range, start_minutes, end_minutes, wraps))
  {
    window_start_time = 0;
    window_end_time   = 0;
    invalid_reason    = "Invalid Pandora box time range";
    return false;
  }

  return PandoraResolveWindowTimes(day_anchor,
                                   previous_day_anchor,
                                   start_minutes,
                                   end_minutes,
                                   wraps,
                                   window_start_time,
                                   window_end_time,
                                   invalid_reason);
}

bool PandoraBuildHistorySnapshot(const datetime day_anchor,
                                 const int day_shift,
                                 const bool is_current_day,
                                 PandoraHistorySnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.day_anchor     = day_anchor;
  snapshot_out.is_current_day = is_current_day;
  datetime previous_day_anchor = iTime(_Symbol, PERIOD_D1, day_shift + 1);
  string invalid_reason = "";
  snapshot_out.window_valid   = PandoraResolveWindowForDay(day_anchor,
                                                           previous_day_anchor,
                                                           snapshot_out.window_start_time,
                                                           snapshot_out.window_end_time,
                                                           invalid_reason);
  if(!snapshot_out.window_valid)
  {
    snapshot_out.invalid_reason = invalid_reason;
    if(snapshot_out.invalid_reason == "")
      snapshot_out.invalid_reason = "Invalid Pandora box time range";
    return false;
  }

  datetime query_end_time = snapshot_out.window_end_time;
  if(is_current_day)
  {
    datetime now_time = TimeCurrent();
    if(now_time < query_end_time)
      query_end_time = now_time;
  }

  snapshot_out.data_end_time = query_end_time;
  if(query_end_time <= snapshot_out.window_start_time)
  {
    snapshot_out.invalid_reason = "Pandora window pending";
    return false;
  }

  ENUM_TIMEFRAMES tf = PandoraResolveBoxTimeframe();
  MqlRates rates[];
  int copied = CopyRates(_Symbol,
                         tf,
                         snapshot_out.window_start_time,
                         query_end_time,
                         rates);
  if(copied <= 0)
  {
    snapshot_out.invalid_reason = "No data for Pandora box window";
    return false;
  }

  double box_high = rates[0].high;
  double box_low  = rates[0].low;
  for(int i = 1; i < copied; i++)
  {
    if(rates[i].high > box_high)
      box_high = rates[i].high;
    if(rates[i].low < box_low || box_low <= 0.0)
      box_low = rates[i].low;
  }

  double point_size = PandoraResolvePointSizeSafe();
  double range_points = 0.0;
  if(point_size > 0.0 && box_high > 0.0 && box_low > 0.0)
    range_points = MathAbs(box_high - box_low) / point_size;

  snapshot_out.box_computed     = true;
  snapshot_out.box_high         = box_high;
  snapshot_out.box_low          = box_low;
  snapshot_out.box_range_points = range_points;

  if(box_high <= 0.0 || box_low <= 0.0 || range_points <= 0.0)
  {
    snapshot_out.invalid_reason = "Failed to resolve Pandora box prices";
    snapshot_out.box_valid      = false;
    return false;
  }

  double offset_points = PandoraResolveDistancePointsForRange(Pandora_Box_Offset_Points,
                                                              snapshot_out.box_range_points,
                                                              true);
  double offset_price = offset_points * point_size;
  snapshot_out.breakout_high_price = box_high + offset_price;
  snapshot_out.breakout_low_price  = box_low - offset_price;

  snapshot_out.box_valid = true;
  if(Pandora_Box_Max_Range_Points > 0.0 &&
     range_points > Pandora_Box_Max_Range_Points)
  {
    snapshot_out.box_valid      = false;
    snapshot_out.invalid_reason = "Pandora box range exceeded";
  }

  return true;
}

bool PandoraHistoryNeedsRefresh()
{
  if(!PandoraStrategyEnabled())
    return (ArraySize(g_pandora_history_snapshots) > 0);

  string signature = PandoraHistoryConfigSignature();
  if(signature != g_pandora_history_last_signature)
    return true;

  datetime day_anchor = ResolveCurrentDayStart();
  if(day_anchor != g_pandora_history_last_day_anchor)
    return true;

  datetime previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);
  if(previous_day_anchor != g_pandora_history_last_previous_day_anchor)
    return true;

  datetime oldest_anchor = iTime(_Symbol, PERIOD_D1, PANDORA_HISTORY_DAYS);
  if(oldest_anchor != g_pandora_history_last_oldest_anchor)
    return true;

  datetime bar_time = iTime(_Symbol, PandoraResolveBoxTimeframe(), 0);
  if(bar_time != g_pandora_history_last_bar_time)
    return true;

  return false;
}

void PandoraRebuildHistorySnapshots()
{
  if(!PandoraStrategyEnabled())
  {
    PandoraClearHistorySnapshots();
    return;
  }

  ArrayResize(g_pandora_history_snapshots, PANDORA_HISTORY_DAYS);

  int stored = 0;
  for(int shift = 0; shift < PANDORA_HISTORY_DAYS; shift++)
  {
    datetime day_anchor = iTime(_Symbol, PERIOD_D1, shift);
    if(day_anchor <= 0)
      continue;

    PandoraHistorySnapshot snapshot;
    PandoraBuildHistorySnapshot(day_anchor, shift, (shift == 0), snapshot);
    g_pandora_history_snapshots[stored] = snapshot;
    stored++;
  }

  ArrayResize(g_pandora_history_snapshots, stored);
  g_pandora_history_last_day_anchor          = ResolveCurrentDayStart();
  g_pandora_history_last_previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);
  g_pandora_history_last_oldest_anchor       = iTime(_Symbol, PERIOD_D1, PANDORA_HISTORY_DAYS);
  g_pandora_history_last_bar_time            = iTime(_Symbol, PandoraResolveBoxTimeframe(), 0);
  g_pandora_history_last_signature           = PandoraHistoryConfigSignature();
}

void PandoraEnsureHistorySnapshots()
{
  if(!PandoraHistoryNeedsRefresh())
    return;
  PandoraRebuildHistorySnapshots();
}

int PandoraHistorySnapshotCount()
{
  PandoraEnsureHistorySnapshots();
  return ArraySize(g_pandora_history_snapshots);
}

PandoraHistorySnapshot PandoraHistorySnapshotAt(const int index)
{
  PandoraHistorySnapshot snapshot;
  if(index < 0 || index >= ArraySize(g_pandora_history_snapshots))
    return snapshot;
  return g_pandora_history_snapshots[index];
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
