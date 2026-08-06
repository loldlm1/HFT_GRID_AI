//+------------------------------------------------------------------+
//|                         trading_signals/pivot_context_features  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_

struct PivotM1SideContext
{
  bool valid;
  datetime previous_bar_open;
  datetime close_boundary;
  datetime next_retry_time;
  double previous_bid_close;
  int last_error;
  string invalid_reason;

  PivotM1SideContext()
  {
    Reset();
  }

  PivotM1SideContext(const PivotM1SideContext &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    valid = false;
    previous_bar_open = 0;
    close_boundary = 0;
    next_retry_time = 0;
    previous_bid_close = 0.0;
    last_error = 0;
    invalid_reason = "";
  }

  void CopyFrom(const PivotM1SideContext &other)
  {
    valid = other.valid;
    previous_bar_open = other.previous_bar_open;
    close_boundary = other.close_boundary;
    next_retry_time = other.next_retry_time;
    previous_bid_close = other.previous_bid_close;
    last_error = other.last_error;
    invalid_reason = other.invalid_reason;
  }
};

struct PivotContextFeatureRow
{
  ENUM_TIMEFRAMES timeframe;
  bool b_percent_complete;
  bool b_percent_available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double b_percent_values[PIVOT_B_PERCENT_SHIFT_COUNT];
  string invalid_reason;

  PivotContextFeatureRow()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotContextFeatureRow(const PivotContextFeatureRow &other)
  {
    CopyFrom(other);
  }

  void Reset(const ENUM_TIMEFRAMES context_timeframe)
  {
    timeframe = context_timeframe;
    b_percent_complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      b_percent_available[i] = false;
      b_percent_values[i] = 0.0;
    }
  }

  void CopyFrom(const PivotContextFeatureRow &other)
  {
    timeframe = other.timeframe;
    b_percent_complete = other.b_percent_complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      b_percent_available[i] = other.b_percent_available[i];
      b_percent_values[i] = other.b_percent_values[i];
    }
  }
};

struct PivotContextFeatureSnapshot
{
  bool captured;
  bool complete;
  datetime broker_time;
  double trigger_bid;
  PivotContextFeatureRow micro;
  PivotContextFeatureRow macro;

  PivotContextFeatureSnapshot()
  {
    Reset();
  }

  PivotContextFeatureSnapshot(const PivotContextFeatureSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    captured = false;
    complete = false;
    broker_time = 0;
    trigger_bid = 0.0;
    micro.Reset(Micro_Timeframe);
    macro.Reset(Macro_Timeframe);
  }

  void CopyFrom(const PivotContextFeatureSnapshot &other)
  {
    captured = other.captured;
    complete = other.complete;
    broker_time = other.broker_time;
    trigger_bid = other.trigger_bid;
    micro.CopyFrom(other.micro);
    macro.CopyFrom(other.macro);
  }
};

PivotM1SideContext g_pivot_m1_side_context;

void ResetPivotM1SideContext()
{
  g_pivot_m1_side_context.Reset();
}

bool RefreshPivotM1SideContext(const datetime observation_time,
                               const bool force_refresh = false)
{
  if(observation_time <= 0)
    return false;

  ResetLastError();
  datetime current_bar_open = iTime(_Symbol, PERIOD_M1, 0);
  if(current_bar_open <= 0)
  {
    g_pivot_m1_side_context.valid = false;
    g_pivot_m1_side_context.last_error = GetLastError();
    g_pivot_m1_side_context.invalid_reason = "M1_ACTIVE_BAR_UNAVAILABLE";
    g_pivot_m1_side_context.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  // Keep only an already-causal M1 boundary if tester series are ahead of the
  // observed tick.
  if(current_bar_open > observation_time)
  {
    return g_pivot_m1_side_context.valid &&
           g_pivot_m1_side_context.close_boundary > 0 &&
           g_pivot_m1_side_context.close_boundary <= observation_time;
  }

  if(g_pivot_m1_side_context.valid &&
     g_pivot_m1_side_context.close_boundary == current_bar_open)
    return true;

  if(!force_refresh &&
     g_pivot_m1_side_context.next_retry_time > 0 &&
     observation_time < g_pivot_m1_side_context.next_retry_time)
    return false;

  g_pivot_m1_side_context.valid = false;
  g_pivot_m1_side_context.previous_bar_open = 0;
  g_pivot_m1_side_context.close_boundary = current_bar_open;
  g_pivot_m1_side_context.previous_bid_close = 0.0;
  g_pivot_m1_side_context.invalid_reason = "";

  MqlRates previous_rates[];
  ArraySetAsSeries(previous_rates, true);
  ResetLastError();
  int copied = CopyRates(_Symbol, PERIOD_M1, 1, 1, previous_rates);
  if(copied != 1 || ArraySize(previous_rates) != 1)
  {
    g_pivot_m1_side_context.last_error = GetLastError();
    g_pivot_m1_side_context.invalid_reason = "M1_PREVIOUS_RATE_UNAVAILABLE";
    g_pivot_m1_side_context.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  MqlRates previous_rate = previous_rates[0];
  if(previous_rate.time <= 0 ||
     previous_rate.time >= current_bar_open ||
     !MathIsValidNumber(previous_rate.close) ||
     previous_rate.close <= 0.0)
  {
    g_pivot_m1_side_context.last_error = 0;
    g_pivot_m1_side_context.invalid_reason = "M1_PREVIOUS_RATE_INVALID";
    g_pivot_m1_side_context.next_retry_time =
      observation_time + PIVOT_WINDOW_RETRY_SECONDS;
    return false;
  }

  g_pivot_m1_side_context.valid = true;
  g_pivot_m1_side_context.previous_bar_open = previous_rate.time;
  g_pivot_m1_side_context.previous_bid_close = previous_rate.close;
  g_pivot_m1_side_context.last_error = 0;
  g_pivot_m1_side_context.invalid_reason = "";
  g_pivot_m1_side_context.next_retry_time = 0;
  return true;
}

PivotPriceSideStates PivotM1SideRelativeToLevel(const double level_price)
{
  if(!g_pivot_m1_side_context.valid ||
     !MathIsValidNumber(level_price) ||
     level_price <= 0.0)
    return PIVOT_PRICE_SIDE_UNAVAILABLE;

  if(g_pivot_m1_side_context.previous_bid_close < level_price)
    return PIVOT_PRICE_SIDE_BELOW;
  if(g_pivot_m1_side_context.previous_bid_close > level_price)
    return PIVOT_PRICE_SIDE_ABOVE;
  return PIVOT_PRICE_SIDE_EQUAL;
}

int FindPivotBandsHandle(const ENUM_TIMEFRAMES timeframe)
{
  if(timeframe == Macro_Timeframe)
    return g_macro_bands_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_bands_handle.indicator_handle;
  return INVALID_HANDLE;
}

bool CopyPivotBandValue(const int handle,
                        const int buffer_index,
                        const int shift,
                        double &value_out)
{
  value_out = 0.0;
  double values[];
  int copied = CopyBuffer(handle, buffer_index, shift, 1, values);
  if(copied != 1 || ArraySize(values) != 1)
    return false;
  value_out = values[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyPivotWeightedPriceValue(const ENUM_TIMEFRAMES timeframe,
                                 const int shift,
                                 double &value_out)
{
  value_out = 0.0;
  MqlRates values[];
  ArraySetAsSeries(values, true);
  int copied = CopyRates(_Symbol, timeframe, shift, 1, values);
  if(copied != 1 || ArraySize(values) != 1)
    return false;

  value_out = (values[0].high + values[0].low +
               values[0].close + values[0].close) / 4.0;
  return MathIsValidNumber(value_out) && value_out > 0.0;
}

bool CapturePivotBPercentValues(const ENUM_TIMEFRAMES timeframe,
                                const double trigger_bid,
                                PivotContextFeatureRow &row,
                                string &reason_out)
{
  reason_out = "";
  int handle = FindPivotBandsHandle(timeframe);
  if(handle == INVALID_HANDLE || BarsCalculated(handle) <= 0)
  {
    reason_out = "BANDS_HANDLE_NOT_READY";
    return false;
  }

  bool complete = true;
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    double upper_band = 0.0;
    double lower_band = 0.0;
    double price = trigger_bid;
    if(!CopyPivotBandValue(handle, 1, shift, upper_band) ||
       !CopyPivotBandValue(handle, 2, shift, lower_band) ||
       (shift > 0 &&
        !CopyPivotWeightedPriceValue(timeframe, shift, price)) ||
       !MathIsValidNumber(price) ||
       price <= 0.0 ||
       upper_band <= lower_band)
    {
      complete = false;
      continue;
    }

    row.b_percent_values[shift] =
      100.0 * (price - lower_band) / (upper_band - lower_band);
    row.b_percent_available[shift] =
      MathIsValidNumber(row.b_percent_values[shift]);
    if(!row.b_percent_available[shift])
      complete = false;
  }

  row.b_percent_complete = complete;
  if(!complete)
    reason_out = "B_PERCENT_INCOMPLETE";
  return complete;
}

bool CapturePivotContextFeatureRow(const ENUM_TIMEFRAMES timeframe,
                                   const double trigger_bid,
                                   PivotContextFeatureRow &row_out)
{
  row_out.Reset(timeframe);
  string reason = "";
  CapturePivotBPercentValues(timeframe, trigger_bid, row_out, reason);
  row_out.invalid_reason = reason;
  return row_out.b_percent_complete;
}

bool CapturePivotContextFeatureSnapshot(const double trigger_bid,
                                        const datetime broker_time,
                                        PivotContextFeatureSnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.captured = true;
  snapshot_out.broker_time = broker_time;
  snapshot_out.trigger_bid = trigger_bid;

  bool micro_complete = CapturePivotContextFeatureRow(Micro_Timeframe,
                                                       trigger_bid,
                                                       snapshot_out.micro);
  bool macro_complete = CapturePivotContextFeatureRow(Macro_Timeframe,
                                                       trigger_bid,
                                                       snapshot_out.macro);
  snapshot_out.complete = micro_complete && macro_complete;
  return snapshot_out.complete;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
