//+------------------------------------------------------------------+
//|                    trading_signals/pivot_fractal_engine_state   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_

struct PivotFractalWindowState
{
  ENUM_TIMEFRAMES timeframe;
  PivotWindowStates state;
  datetime active_bar_open;
  datetime source_bar_open;
  datetime source_close_boundary;
  datetime next_retry_time;
  int last_error;
  string invalid_reason;
  PivotPriceLadder levels;
  PivotTriggerStates trigger_states[PIVOT_LEVEL_COUNT];

  PivotFractalWindowState()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotFractalWindowState(const PivotFractalWindowState &other)
  {
    CopyFrom(other);
  }

  void Reset(const ENUM_TIMEFRAMES source_timeframe)
  {
    timeframe             = source_timeframe;
    state                 = PIVOT_WINDOW_EMPTY;
    active_bar_open       = 0;
    source_bar_open       = 0;
    source_close_boundary = 0;
    next_retry_time       = 0;
    last_error            = 0;
    invalid_reason        = "";
    levels.Reset();
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
      trigger_states[i] = PIVOT_TRIGGER_AVAILABLE;
  }

  void BeginWindow(const datetime new_active_bar_open)
  {
    active_bar_open       = new_active_bar_open;
    source_bar_open       = 0;
    source_close_boundary = new_active_bar_open;
    next_retry_time       = 0;
    last_error            = 0;
    invalid_reason        = "";
    state                 = PIVOT_WINDOW_PENDING;
    levels.Reset();
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
      trigger_states[i] = PIVOT_TRIGGER_AVAILABLE;
  }

  void CopyFrom(const PivotFractalWindowState &other)
  {
    timeframe             = other.timeframe;
    state                 = other.state;
    active_bar_open       = other.active_bar_open;
    source_bar_open       = other.source_bar_open;
    source_close_boundary = other.source_close_boundary;
    next_retry_time       = other.next_retry_time;
    last_error            = other.last_error;
    invalid_reason        = other.invalid_reason;
    levels.CopyFrom(other.levels);
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
      trigger_states[i] = other.trigger_states[i];
  }
};

PivotFractalWindowState g_pivot_fractal_windows[PIVOT_FRACTAL_TIMEFRAME_COUNT];

void ResetPivotFractalEngineState()
{
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
    g_pivot_fractal_windows[i].Reset(PivotFractalTimeframeAt(i));
}

void MarkPivotWindowPending(PivotFractalWindowState &window,
                            const int error_code,
                            const string reason)
{
  window.state           = PIVOT_WINDOW_PENDING;
  window.last_error      = error_code;
  window.invalid_reason  = reason;
  window.next_retry_time = TimeCurrent() + PIVOT_WINDOW_RETRY_SECONDS;
  window.levels.Reset();
}

void MarkPivotWindowInvalid(PivotFractalWindowState &window,
                            const string reason)
{
  window.state           = PIVOT_WINDOW_INVALID;
  window.last_error      = 0;
  window.invalid_reason  = reason;
  window.next_retry_time = 0;
  window.levels.Reset();
}

bool LoadCompletedPivotSourceRate(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const datetime active_bar_open,
                                  MqlRates &source_out,
                                  int &error_out,
                                  string &reason_out)
{
  ZeroMemory(source_out);
  error_out  = 0;
  reason_out = "";

  MqlRates source_rates[];
  ArraySetAsSeries(source_rates, true);
  ResetLastError();
  int copied = CopyRates(symbol, timeframe, 1, 1, source_rates);
  if(copied != 1)
  {
    error_out  = GetLastError();
    reason_out = "COPY_PREVIOUS_RATE_FAILED";
    return false;
  }

  if(ArraySize(source_rates) != 1 ||
     source_rates[0].time <= 0 ||
     source_rates[0].time >= active_bar_open)
  {
    reason_out = "PREVIOUS_RATE_IDENTITY_INVALID";
    return false;
  }

  source_out = source_rates[0];
  return true;
}

bool RefreshPivotFractalWindowState(PivotFractalWindowState &window,
                                    const int window_index,
                                    const bool force_refresh)
{
  if(window_index < 0 || window_index >= PIVOT_FRACTAL_TIMEFRAME_COUNT)
    return false;

  ENUM_TIMEFRAMES timeframe = PivotFractalTimeframeAt(window_index);
  if(timeframe == PERIOD_CURRENT)
    return false;

  ResetLastError();
  datetime active_bar_open = iTime(_Symbol, timeframe, 0);
  if(active_bar_open <= 0)
  {
    window.timeframe = timeframe;
    MarkPivotWindowPending(window, GetLastError(), "ACTIVE_BAR_UNAVAILABLE");
    return false;
  }

  bool bar_changed = (window.active_bar_open != active_bar_open);
  if(bar_changed)
    window.BeginWindow(active_bar_open);
  else if(window.state == PIVOT_WINDOW_VALID)
    return true;
  else if(window.state == PIVOT_WINDOW_INVALID && !force_refresh)
    return false;
  else if(!force_refresh &&
          window.next_retry_time > 0 &&
          TimeCurrent() < window.next_retry_time)
    return false;

  MqlRates source_rate;
  int source_error = 0;
  string source_reason = "";
  if(!LoadCompletedPivotSourceRate(_Symbol,
                                   timeframe,
                                   active_bar_open,
                                   source_rate,
                                   source_error,
                                   source_reason))
  {
    MarkPivotWindowPending(window, source_error, source_reason);
    return false;
  }

  PivotPriceLadder levels;
  string calculation_reason = "";
  if(!BuildClassicPivotPriceLadder(_Symbol,
                                   source_rate,
                                   levels,
                                   calculation_reason))
  {
    MarkPivotWindowInvalid(window, calculation_reason);
    return false;
  }

  window.timeframe             = timeframe;
  window.state                 = PIVOT_WINDOW_VALID;
  window.source_bar_open       = source_rate.time;
  window.source_close_boundary = active_bar_open;
  window.next_retry_time       = 0;
  window.last_error            = 0;
  window.invalid_reason        = "";
  window.levels.CopyFrom(levels);
  return true;
}

bool RefreshPivotFractalWindow(const int window_index,
                               const bool force_refresh = false)
{
  if(window_index < 0 || window_index >= PIVOT_FRACTAL_TIMEFRAME_COUNT)
    return false;
  return RefreshPivotFractalWindowState(g_pivot_fractal_windows[window_index],
                                        window_index,
                                        force_refresh);
}

int RefreshPivotFractalWindows(const bool force_refresh = false)
{
  int valid_windows = 0;
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    if(RefreshPivotFractalWindow(i, force_refresh))
      valid_windows++;
  }
  return valid_windows;
}

bool PivotFractalWindowAt(const int index,
                          PivotFractalWindowState &window_out)
{
  if(index < 0 || index >= PIVOT_FRACTAL_TIMEFRAME_COUNT)
    return false;
  window_out.CopyFrom(g_pivot_fractal_windows[index]);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_
