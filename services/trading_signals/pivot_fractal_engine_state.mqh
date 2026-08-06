//+------------------------------------------------------------------+
//|                    trading_signals/pivot_fractal_engine_state   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_

struct PivotMacroBandCache
{
  bool complete;
  double base_1;
  double upper_1;
  double lower_1;
  double width_1;
  double width_percent_1;
  datetime next_retry_time;
  int last_error;
  string invalid_reason;

  PivotMacroBandCache()
  {
    Reset();
  }

  PivotMacroBandCache(const PivotMacroBandCache &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    complete = false;
    base_1 = 0.0;
    upper_1 = 0.0;
    lower_1 = 0.0;
    width_1 = 0.0;
    width_percent_1 = 0.0;
    next_retry_time = 0;
    last_error = 0;
    invalid_reason = "";
  }

  void CopyFrom(const PivotMacroBandCache &other)
  {
    complete = other.complete;
    base_1 = other.base_1;
    upper_1 = other.upper_1;
    lower_1 = other.lower_1;
    width_1 = other.width_1;
    width_percent_1 = other.width_percent_1;
    next_retry_time = other.next_retry_time;
    last_error = other.last_error;
    invalid_reason = other.invalid_reason;
  }
};

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
  datetime first_observed_time;
  double first_observed_bid;
  PivotPriceSideStates pp_initial_relation;
  PivotPpArmStates pp_arm_state;
  datetime pp_arm_time;
  double pp_arm_bid;
  PivotMacroBandCache macro_band;

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
    timeframe = source_timeframe;
    state = PIVOT_WINDOW_EMPTY;
    active_bar_open = 0;
    source_bar_open = 0;
    source_close_boundary = 0;
    next_retry_time = 0;
    last_error = 0;
    invalid_reason = "";
    levels.Reset();
    first_observed_time = 0;
    first_observed_bid = 0.0;
    pp_initial_relation = PIVOT_PRICE_SIDE_UNAVAILABLE;
    pp_arm_state = PIVOT_PP_UNARMED;
    pp_arm_time = 0;
    pp_arm_bid = 0.0;
    macro_band.Reset();
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
      trigger_states[i] = PIVOT_TRIGGER_AVAILABLE;
  }

  void BeginWindow(const datetime new_active_bar_open)
  {
    Reset(timeframe);
    active_bar_open = new_active_bar_open;
    source_close_boundary = new_active_bar_open;
    state = PIVOT_WINDOW_PENDING;
  }

  void CopyFrom(const PivotFractalWindowState &other)
  {
    timeframe = other.timeframe;
    state = other.state;
    active_bar_open = other.active_bar_open;
    source_bar_open = other.source_bar_open;
    source_close_boundary = other.source_close_boundary;
    next_retry_time = other.next_retry_time;
    last_error = other.last_error;
    invalid_reason = other.invalid_reason;
    levels.CopyFrom(other.levels);
    first_observed_time = other.first_observed_time;
    first_observed_bid = other.first_observed_bid;
    pp_initial_relation = other.pp_initial_relation;
    pp_arm_state = other.pp_arm_state;
    pp_arm_time = other.pp_arm_time;
    pp_arm_bid = other.pp_arm_bid;
    macro_band.CopyFrom(other.macro_band);
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
      trigger_states[i] = other.trigger_states[i];
  }
};

PivotFractalWindowState g_pivot_fractal_window;

void ResetPivotFractalEngineState()
{
  g_pivot_fractal_window.Reset(Macro_Timeframe);
}

void MarkPivotWindowPending(PivotFractalWindowState &window,
                            const int error_code,
                            const string reason,
                            const datetime observation_time)
{
  datetime retry_base_time = observation_time > 0
                             ? observation_time
                             : TimeCurrent();
  window.state = PIVOT_WINDOW_PENDING;
  window.last_error = error_code;
  window.invalid_reason = reason;
  window.next_retry_time = retry_base_time + PIVOT_WINDOW_RETRY_SECONDS;
  window.levels.Reset();
  window.macro_band.Reset();
}

void MarkPivotWindowInvalid(PivotFractalWindowState &window,
                            const string reason)
{
  window.state = PIVOT_WINDOW_INVALID;
  window.last_error = 0;
  window.invalid_reason = reason;
  window.next_retry_time = 0;
  window.levels.Reset();
  window.macro_band.Reset();
}

bool LoadCompletedPivotSourceRate(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const datetime active_bar_open,
                                  MqlRates &source_out,
                                  int &error_out,
                                  string &reason_out)
{
  ZeroMemory(source_out);
  error_out = 0;
  reason_out = "";

  MqlRates source_rates[];
  ArraySetAsSeries(source_rates, true);
  ResetLastError();
  int copied = CopyRates(symbol, timeframe, 1, 1, source_rates);
  if(copied != 1)
  {
    error_out = GetLastError();
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

bool CapturePivotMacroBandCache(PivotFractalWindowState &window,
                                const datetime observation_time)
{
  window.macro_band.Reset();
  if(!Enable_Signal_Feature_Export)
  {
    window.macro_band.invalid_reason = "FEATURE_EXPORT_DISABLED";
    return false;
  }
  if(observation_time <= 0 ||
     window.active_bar_open <= 0 ||
     window.source_bar_open <= 0)
  {
    window.macro_band.invalid_reason = "MACRO_BAND_WINDOW_IDENTITY_INVALID";
    return false;
  }

  int handle = g_macro_bands_handle.indicator_handle;
  if(handle == INVALID_HANDLE)
  {
    window.macro_band.invalid_reason = "MACRO_BANDS_HANDLE_MISSING";
    window.macro_band.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }
  if(BarsCalculated(handle) < 2)
  {
    window.macro_band.invalid_reason = "MACRO_BANDS_HANDLE_NOT_READY";
    window.macro_band.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  datetime active_bar_open = iTime(_Symbol, Macro_Timeframe, 0);
  if(active_bar_open != window.active_bar_open ||
     active_bar_open > observation_time)
  {
    window.macro_band.invalid_reason = "MACRO_BANDS_WINDOW_NOT_CAUSAL";
    window.macro_band.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  double base = 0.0;
  double upper = 0.0;
  double lower = 0.0;
  if(!CopyPivotBandValue(handle, 0, 1, base))
  {
    window.macro_band.last_error = GetLastError();
    window.macro_band.invalid_reason = "MACRO_BAND_BASE_SHIFT_1_UNAVAILABLE";
  }
  else if(!CopyPivotBandValue(handle, 1, 1, upper))
  {
    window.macro_band.last_error = GetLastError();
    window.macro_band.invalid_reason = "MACRO_BAND_UPPER_SHIFT_1_UNAVAILABLE";
  }
  else if(!CopyPivotBandValue(handle, 2, 1, lower))
  {
    window.macro_band.last_error = GetLastError();
    window.macro_band.invalid_reason = "MACRO_BAND_LOWER_SHIFT_1_UNAVAILABLE";
  }
  else if(base <= 0.0 || !MathIsValidNumber(base))
  {
    window.macro_band.invalid_reason = "MACRO_BAND_BASE_SHIFT_1_INVALID";
  }
  else if(upper <= lower)
  {
    window.macro_band.invalid_reason = "MACRO_BAND_WIDTH_SHIFT_1_INVALID";
  }

  if(window.macro_band.invalid_reason != "")
  {
    window.macro_band.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  window.macro_band.base_1 = base;
  window.macro_band.upper_1 = upper;
  window.macro_band.lower_1 = lower;
  window.macro_band.width_1 = upper - lower;
  window.macro_band.width_percent_1 = 100.0 *
    window.macro_band.width_1 / base;
  if(window.macro_band.width_1 <= 0.0 ||
     !MathIsValidNumber(window.macro_band.width_percent_1))
  {
    window.macro_band.Reset();
    window.macro_band.invalid_reason =
      "MACRO_BAND_WIDTH_PERCENT_SHIFT_1_INVALID";
    window.macro_band.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  window.macro_band.complete = true;
  return true;
}

bool RefreshPivotFractalWindowState(PivotFractalWindowState &window,
                                    const datetime active_bar_open,
                                    const datetime observation_time,
                                    const bool force_refresh)
{
  if(active_bar_open <= 0 ||
     observation_time <= 0 ||
     Macro_Timeframe == PERIOD_CURRENT)
    return false;

  // Tester series may advertise the next bar before the observed tick reaches
  // it, so an already-causal window remains authoritative in that interval.
  if(active_bar_open > observation_time)
  {
    return window.state == PIVOT_WINDOW_VALID &&
           window.active_bar_open > 0 &&
           window.active_bar_open <= observation_time &&
           window.source_close_boundary <= observation_time;
  }

  bool bar_changed = window.active_bar_open != active_bar_open;
  if(bar_changed)
    window.BeginWindow(active_bar_open);
  else if(window.state == PIVOT_WINDOW_VALID)
  {
    if(Enable_Signal_Feature_Export &&
       !window.macro_band.complete &&
       (force_refresh ||
        window.macro_band.next_retry_time <= 0 ||
        observation_time >= window.macro_band.next_retry_time))
      CapturePivotMacroBandCache(window, observation_time);
    return true;
  }
  else if(window.state == PIVOT_WINDOW_INVALID && !force_refresh)
    return false;
  else if(!force_refresh &&
          window.next_retry_time > 0 &&
          observation_time < window.next_retry_time)
    return false;

  MqlRates source_rate;
  int source_error = 0;
  string source_reason = "";
  if(!LoadCompletedPivotSourceRate(_Symbol,
                                   Macro_Timeframe,
                                   active_bar_open,
                                   source_rate,
                                   source_error,
                                   source_reason))
  {
    MarkPivotWindowPending(window,
                           source_error,
                           source_reason,
                           observation_time);
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

  window.timeframe = Macro_Timeframe;
  window.state = PIVOT_WINDOW_VALID;
  window.source_bar_open = source_rate.time;
  window.source_close_boundary = active_bar_open;
  window.next_retry_time = 0;
  window.last_error = 0;
  window.invalid_reason = "";
  window.levels.CopyFrom(levels);
  CapturePivotMacroBandCache(window, observation_time);
  return true;
}

bool RefreshPivotFractalWindow(const datetime active_bar_open,
                               const datetime observation_time,
                               const bool force_refresh = false)
{
  return RefreshPivotFractalWindowState(g_pivot_fractal_window,
                                        active_bar_open,
                                        observation_time,
                                        force_refresh);
}

bool PivotFractalWindow(PivotFractalWindowState &window_out)
{
  window_out.CopyFrom(g_pivot_fractal_window);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_ENGINE_STATE_MQH_
