//+------------------------------------------------------------------+
//|                         trading_signals/pivot_context_features  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_

struct PivotBandEnvelopeSnapshot
{
  ENUM_TIMEFRAMES timeframe;
  bool captured;
  bool complete;
  bool available[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double base_values[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double upper_values[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double lower_values[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  string invalid_reason;

  PivotBandEnvelopeSnapshot()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotBandEnvelopeSnapshot(const PivotBandEnvelopeSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset(const ENUM_TIMEFRAMES source_timeframe)
  {
    timeframe = source_timeframe;
    captured = false;
    complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_FEATURE_RAW_SHIFT_COUNT; i++)
    {
      available[i] = false;
      base_values[i] = 0.0;
      upper_values[i] = 0.0;
      lower_values[i] = 0.0;
    }
  }

  void CopyFrom(const PivotBandEnvelopeSnapshot &other)
  {
    timeframe = other.timeframe;
    captured = other.captured;
    complete = other.complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_FEATURE_RAW_SHIFT_COUNT; i++)
    {
      available[i] = other.available[i];
      base_values[i] = other.base_values[i];
      upper_values[i] = other.upper_values[i];
      lower_values[i] = other.lower_values[i];
    }
  }
};

struct PivotStochasticLinesSnapshot
{
  ENUM_TIMEFRAMES timeframe;
  bool captured;
  bool complete;
  bool main_line_available[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double main_line[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  bool signal_line_available[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double signal_line[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  string invalid_reason;

  PivotStochasticLinesSnapshot()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotStochasticLinesSnapshot(const PivotStochasticLinesSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset(const ENUM_TIMEFRAMES source_timeframe)
  {
    timeframe = source_timeframe;
    captured = false;
    complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_FEATURE_RAW_SHIFT_COUNT; i++)
    {
      main_line_available[i] = false;
      main_line[i] = 0.0;
      signal_line_available[i] = false;
      signal_line[i] = 0.0;
    }
  }

  void CopyFrom(const PivotStochasticLinesSnapshot &other)
  {
    timeframe = other.timeframe;
    captured = other.captured;
    complete = other.complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_FEATURE_RAW_SHIFT_COUNT; i++)
    {
      main_line_available[i] = other.main_line_available[i];
      main_line[i] = other.main_line[i];
      signal_line_available[i] = other.signal_line_available[i];
      signal_line[i] = other.signal_line[i];
    }
  }
};

struct PivotDerivedFeatureSeries
{
  bool complete;
  bool available[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  double raw_values[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  double sma_5_values[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  double sma_slopes[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  PivotPriceSideStates states[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];

  PivotDerivedFeatureSeries()
  {
    Reset();
  }

  PivotDerivedFeatureSeries(const PivotDerivedFeatureSeries &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    complete = false;
    for(int i = 0; i < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; i++)
    {
      available[i] = false;
      raw_values[i] = 0.0;
      sma_5_values[i] = 0.0;
      sma_slopes[i] = 0.0;
      states[i] = PIVOT_PRICE_SIDE_UNAVAILABLE;
    }
  }

  void CopyFrom(const PivotDerivedFeatureSeries &other)
  {
    complete = other.complete;
    for(int i = 0; i < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; i++)
    {
      available[i] = other.available[i];
      raw_values[i] = other.raw_values[i];
      sma_5_values[i] = other.sma_5_values[i];
      sma_slopes[i] = other.sma_slopes[i];
      states[i] = other.states[i];
    }
  }
};

struct PivotBandTrendSnapshot
{
  bool complete;
  bool width_available;
  double width_price_0;
  double width_points_0;
  bool base_line_available[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  double base_line[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];
  double base_line_slope_points[PIVOT_FEATURE_EXPORT_SHIFT_COUNT];

  PivotBandTrendSnapshot()
  {
    Reset();
  }

  PivotBandTrendSnapshot(const PivotBandTrendSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    complete = false;
    width_available = false;
    width_price_0 = 0.0;
    width_points_0 = 0.0;
    for(int i = 0; i < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; i++)
    {
      base_line_available[i] = false;
      base_line[i] = 0.0;
      base_line_slope_points[i] = 0.0;
    }
  }

  void CopyFrom(const PivotBandTrendSnapshot &other)
  {
    complete = other.complete;
    width_available = other.width_available;
    width_price_0 = other.width_price_0;
    width_points_0 = other.width_points_0;
    for(int i = 0; i < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; i++)
    {
      base_line_available[i] = other.base_line_available[i];
      base_line[i] = other.base_line[i];
      base_line_slope_points[i] =
        other.base_line_slope_points[i];
    }
  }
};

struct PivotContextFeatureSnapshot
{
  bool captured;
  bool complete;
  datetime broker_time;
  double trigger_bid;
  double pivot_price;
  PivotBandEnvelopeSnapshot micro_bands;
  PivotBandEnvelopeSnapshot macro_bands;
  PivotStochasticLinesSnapshot micro_stochastic;
  PivotStochasticLinesSnapshot macro_stochastic;
  PivotDerivedFeatureSeries micro_b_percent_features;
  PivotDerivedFeatureSeries macro_b_percent_features;
  PivotDerivedFeatureSeries micro_stochastic_main_line_features;
  PivotDerivedFeatureSeries micro_stochastic_signal_line_features;
  PivotDerivedFeatureSeries macro_stochastic_main_line_features;
  PivotDerivedFeatureSeries macro_stochastic_signal_line_features;
  PivotBandTrendSnapshot micro_band_trend;
  PivotBandTrendSnapshot macro_band_trend;
  bool micro_b_percent_available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double micro_b_percent[PIVOT_B_PERCENT_SHIFT_COUNT];
  bool macro_pivot_b_percent_available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double macro_pivot_b_percent[PIVOT_B_PERCENT_SHIFT_COUNT];
  double micro_band_base_0;
  double micro_band_upper_0;
  double micro_band_lower_0;
  double micro_band_width_0;
  double micro_band_width_percent_0;
  bool micro_complete;
  bool macro_complete;
  string invalid_reason;

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
    pivot_price = 0.0;
    micro_bands.Reset(Micro_Timeframe);
    macro_bands.Reset(Macro_Timeframe);
    micro_stochastic.Reset(Micro_Timeframe);
    macro_stochastic.Reset(Macro_Timeframe);
    micro_b_percent_features.Reset();
    macro_b_percent_features.Reset();
    micro_stochastic_main_line_features.Reset();
    micro_stochastic_signal_line_features.Reset();
    macro_stochastic_main_line_features.Reset();
    macro_stochastic_signal_line_features.Reset();
    micro_band_trend.Reset();
    macro_band_trend.Reset();
    micro_band_base_0 = 0.0;
    micro_band_upper_0 = 0.0;
    micro_band_lower_0 = 0.0;
    micro_band_width_0 = 0.0;
    micro_band_width_percent_0 = 0.0;
    micro_complete = false;
    macro_complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      micro_b_percent_available[i] = false;
      micro_b_percent[i] = 0.0;
      macro_pivot_b_percent_available[i] = false;
      macro_pivot_b_percent[i] = 0.0;
    }
  }

  void CopyFrom(const PivotContextFeatureSnapshot &other)
  {
    captured = other.captured;
    complete = other.complete;
    broker_time = other.broker_time;
    trigger_bid = other.trigger_bid;
    pivot_price = other.pivot_price;
    micro_bands.CopyFrom(other.micro_bands);
    macro_bands.CopyFrom(other.macro_bands);
    micro_stochastic.CopyFrom(other.micro_stochastic);
    macro_stochastic.CopyFrom(other.macro_stochastic);
    micro_b_percent_features.CopyFrom(other.micro_b_percent_features);
    macro_b_percent_features.CopyFrom(other.macro_b_percent_features);
    micro_stochastic_main_line_features.CopyFrom(
      other.micro_stochastic_main_line_features);
    micro_stochastic_signal_line_features.CopyFrom(
      other.micro_stochastic_signal_line_features);
    macro_stochastic_main_line_features.CopyFrom(
      other.macro_stochastic_main_line_features);
    macro_stochastic_signal_line_features.CopyFrom(
      other.macro_stochastic_signal_line_features);
    micro_band_trend.CopyFrom(other.micro_band_trend);
    macro_band_trend.CopyFrom(other.macro_band_trend);
    micro_band_base_0 = other.micro_band_base_0;
    micro_band_upper_0 = other.micro_band_upper_0;
    micro_band_lower_0 = other.micro_band_lower_0;
    micro_band_width_0 = other.micro_band_width_0;
    micro_band_width_percent_0 = other.micro_band_width_percent_0;
    micro_complete = other.micro_complete;
    macro_complete = other.macro_complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      micro_b_percent_available[i] = other.micro_b_percent_available[i];
      micro_b_percent[i] = other.micro_b_percent[i];
      macro_pivot_b_percent_available[i] =
        other.macro_pivot_b_percent_available[i];
      macro_pivot_b_percent[i] = other.macro_pivot_b_percent[i];
    }
  }
};

void AppendPivotFeatureReason(string &reason,
                              const string value)
{
  if(value == "")
    return;
  if(reason != "")
    reason += "|";
  reason += value;
}

int PivotBandsHandleForTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  if(timeframe == Macro_Timeframe)
    return g_macro_bands_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_bands_handle.indicator_handle;
  return INVALID_HANDLE;
}

int PivotStochasticHandleForTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  if(timeframe == Macro_Timeframe)
    return g_macro_stochastic_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_stochastic_handle.indicator_handle;
  return INVALID_HANDLE;
}

bool CopyPivotBandValue(const int handle,
                        const int buffer_index,
                        const int shift,
                        double &value_out)
{
  value_out = 0.0;
  double values[];
  ResetLastError();
  int copied = CopyBuffer(handle, buffer_index, shift, 1, values);
  if(copied != 1 || ArraySize(values) != 1)
    return false;
  value_out = values[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyPivotIndicatorBuffer(const int handle,
                              const int buffer_index,
                              const int count,
                              double &values_out[])
{
  if(handle == INVALID_HANDLE || count <= 0 || ArraySize(values_out) < count)
    return false;

  double copied_values[];
  ResetLastError();
  int copied = CopyBuffer(handle, buffer_index, 0, count, copied_values);
  if(copied != count || ArraySize(copied_values) != count)
    return false;

  // CopyBuffer places the oldest requested value first in physical memory.
  for(int shift = 0; shift < count; shift++)
    values_out[shift] = copied_values[count - 1 - shift];
  return true;
}

bool PivotIndicatorCurrentBarCausal(const ENUM_TIMEFRAMES timeframe,
                                    const datetime broker_time)
{
  datetime current_bar_open = iTime(_Symbol, timeframe, 0);
  return current_bar_open > 0 && current_bar_open <= broker_time;
}

bool CapturePivotBandEnvelope(const ENUM_TIMEFRAMES timeframe,
                              const datetime broker_time,
                              PivotBandEnvelopeSnapshot &snapshot_out)
{
  snapshot_out.Reset(timeframe);
  snapshot_out.captured = true;
  if(broker_time <= 0)
  {
    snapshot_out.invalid_reason = "OBSERVATION_TIME_INVALID";
    return false;
  }

  int handle = PivotBandsHandleForTimeframe(timeframe);
  if(handle == INVALID_HANDLE)
  {
    snapshot_out.invalid_reason = "BANDS_HANDLE_MISSING";
    return false;
  }
  if(BarsCalculated(handle) < PIVOT_FEATURE_RAW_SHIFT_COUNT)
  {
    snapshot_out.invalid_reason = "BANDS_HANDLE_NOT_READY";
    return false;
  }
  if(!PivotIndicatorCurrentBarCausal(timeframe, broker_time))
  {
    snapshot_out.invalid_reason = "BANDS_CURRENT_BAR_NOT_CAUSAL";
    return false;
  }
  if(!CopyPivotIndicatorBuffer(handle,
                               0,
                               PIVOT_FEATURE_RAW_SHIFT_COUNT,
                               snapshot_out.base_values) ||
     !CopyPivotIndicatorBuffer(handle,
                               1,
                               PIVOT_FEATURE_RAW_SHIFT_COUNT,
                               snapshot_out.upper_values) ||
     !CopyPivotIndicatorBuffer(handle,
                               2,
                               PIVOT_FEATURE_RAW_SHIFT_COUNT,
                               snapshot_out.lower_values))
  {
    snapshot_out.invalid_reason = "BANDS_BUFFER_COPY_FAILED";
    return false;
  }

  bool complete = true;
  for(int shift = 0; shift < PIVOT_FEATURE_RAW_SHIFT_COUNT; shift++)
  {
    double base = snapshot_out.base_values[shift];
    double upper = snapshot_out.upper_values[shift];
    double lower = snapshot_out.lower_values[shift];
    if(!MathIsValidNumber(base) ||
       !MathIsValidNumber(upper) ||
       !MathIsValidNumber(lower) ||
       base == EMPTY_VALUE ||
       upper == EMPTY_VALUE ||
       lower == EMPTY_VALUE ||
       base <= 0.0 ||
       upper <= lower)
    {
      complete = false;
      AppendPivotFeatureReason(snapshot_out.invalid_reason,
                               "BAND_SHIFT_" + IntegerToString(shift) +
                               "_INVALID");
      continue;
    }
    snapshot_out.available[shift] = true;
  }

  snapshot_out.complete = complete;
  return complete;
}

bool CapturePivotStochasticLines(
  const ENUM_TIMEFRAMES timeframe,
  const datetime broker_time,
  PivotStochasticLinesSnapshot &snapshot_out)
{
  snapshot_out.Reset(timeframe);
  snapshot_out.captured = true;
  if(broker_time <= 0)
  {
    snapshot_out.invalid_reason = "OBSERVATION_TIME_INVALID";
    return false;
  }

  int handle = PivotStochasticHandleForTimeframe(timeframe);
  if(handle == INVALID_HANDLE)
  {
    snapshot_out.invalid_reason = "STOCHASTIC_HANDLE_MISSING";
    return false;
  }
  if(BarsCalculated(handle) < PIVOT_FEATURE_RAW_SHIFT_COUNT)
  {
    snapshot_out.invalid_reason = "STOCHASTIC_HANDLE_NOT_READY";
    return false;
  }
  if(!PivotIndicatorCurrentBarCausal(timeframe, broker_time))
  {
    snapshot_out.invalid_reason = "STOCHASTIC_CURRENT_BAR_NOT_CAUSAL";
    return false;
  }
  if(!CopyPivotIndicatorBuffer(handle,
                               0,
                               PIVOT_FEATURE_RAW_SHIFT_COUNT,
                               snapshot_out.main_line) ||
     !CopyPivotIndicatorBuffer(handle,
                               1,
                               PIVOT_FEATURE_RAW_SHIFT_COUNT,
                               snapshot_out.signal_line))
  {
    snapshot_out.invalid_reason = "STOCHASTIC_BUFFER_COPY_FAILED";
    return false;
  }

  bool complete = true;
  for(int shift = 0; shift < PIVOT_FEATURE_RAW_SHIFT_COUNT; shift++)
  {
    double main_value = snapshot_out.main_line[shift];
    double signal_value = snapshot_out.signal_line[shift];
    if(!MathIsValidNumber(main_value) ||
       main_value == EMPTY_VALUE ||
       main_value < -PIVOT_FEATURE_STATE_TOLERANCE ||
       main_value > 100.0 + PIVOT_FEATURE_STATE_TOLERANCE)
    {
      complete = false;
      AppendPivotFeatureReason(snapshot_out.invalid_reason,
                               "MAIN_LINE_SHIFT_" +
                               IntegerToString(shift) + "_INVALID");
    }
    else
    {
      snapshot_out.main_line_available[shift] = true;
    }
    if(!MathIsValidNumber(signal_value) ||
       signal_value == EMPTY_VALUE ||
       signal_value < -PIVOT_FEATURE_STATE_TOLERANCE ||
       signal_value > 100.0 + PIVOT_FEATURE_STATE_TOLERANCE)
    {
      complete = false;
      AppendPivotFeatureReason(snapshot_out.invalid_reason,
                               "SIGNAL_LINE_SHIFT_" +
                               IntegerToString(shift) + "_INVALID");
    }
    else
    {
      snapshot_out.signal_line_available[shift] = true;
    }
  }

  snapshot_out.complete = complete;
  return complete;
}

PivotPriceSideStates PivotFeatureState(const double raw_value,
                                       const double sma_value)
{
  double delta = raw_value - sma_value;
  if(delta > PIVOT_FEATURE_STATE_TOLERANCE)
    return PIVOT_PRICE_SIDE_ABOVE;
  if(delta < -PIVOT_FEATURE_STATE_TOLERANCE)
    return PIVOT_PRICE_SIDE_BELOW;
  return PIVOT_PRICE_SIDE_EQUAL;
}

bool DerivePivotFeatureSeries(
  const double &raw_history[],
  const bool &raw_available[],
  PivotDerivedFeatureSeries &series_out)
{
  series_out.Reset();
  if(ArraySize(raw_history) < PIVOT_FEATURE_RAW_SHIFT_COUNT ||
     ArraySize(raw_available) < PIVOT_FEATURE_RAW_SHIFT_COUNT)
    return false;

  double sma_values[PIVOT_FEATURE_SMA_SHIFT_COUNT];
  for(int shift = 0; shift < PIVOT_FEATURE_SMA_SHIFT_COUNT; shift++)
  {
    double sum = 0.0;
    for(int offset = 0; offset < PIVOT_FEATURE_SMA_PERIOD; offset++)
    {
      int raw_shift = shift + offset;
      if(!raw_available[raw_shift] ||
         !MathIsValidNumber(raw_history[raw_shift]) ||
         raw_history[raw_shift] == EMPTY_VALUE)
        return false;
      sum += raw_history[raw_shift];
    }
    sma_values[shift] = sum / (double)PIVOT_FEATURE_SMA_PERIOD;
    if(!MathIsValidNumber(sma_values[shift]))
      return false;
  }

  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    series_out.available[shift] = true;
    series_out.raw_values[shift] = raw_history[shift];
    series_out.sma_5_values[shift] = sma_values[shift];
    series_out.sma_slopes[shift] =
      sma_values[shift] - sma_values[shift + 1];
    series_out.states[shift] =
      PivotFeatureState(raw_history[shift], sma_values[shift]);
  }
  series_out.complete = true;
  return true;
}

bool DerivePivotBandTrend(const PivotBandEnvelopeSnapshot &bands,
                          const double point_size,
                          PivotBandTrendSnapshot &trend_out)
{
  trend_out.Reset();
  if(!bands.complete || point_size <= 0.0)
    return false;

  double width = bands.upper_values[0] - bands.lower_values[0];
  if(width <= 0.0 || !MathIsValidNumber(width))
    return false;
  trend_out.width_available = true;
  trend_out.width_price_0 = width;
  trend_out.width_points_0 = width / point_size;
  if(!MathIsValidNumber(trend_out.width_points_0) ||
     trend_out.width_points_0 <= 0.0)
    return false;

  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    if(!bands.available[shift] || !bands.available[shift + 1])
      return false;
    trend_out.base_line_available[shift] = true;
    trend_out.base_line[shift] = bands.base_values[shift];
    trend_out.base_line_slope_points[shift] =
      (bands.base_values[shift] - bands.base_values[shift + 1]) /
      point_size;
    if(!MathIsValidNumber(trend_out.base_line_slope_points[shift]))
      return false;
  }
  trend_out.complete = true;
  return true;
}

bool CalculatePivotBPercent(const double price,
                            const double upper_band,
                            const double lower_band,
                            double &value_out)
{
  value_out = 0.0;
  if(!MathIsValidNumber(price) ||
     !MathIsValidNumber(upper_band) ||
     !MathIsValidNumber(lower_band) ||
     price <= 0.0 ||
     upper_band <= lower_band)
    return false;

  value_out = 100.0 * (price - lower_band) /
              (upper_band - lower_band);
  return MathIsValidNumber(value_out);
}

bool BuildPivotBPercentSeries(
  const double pivot_price,
  const PivotBandEnvelopeSnapshot &bands,
  PivotDerivedFeatureSeries &series_out)
{
  series_out.Reset();
  if(!bands.complete ||
     !MathIsValidNumber(pivot_price) ||
     pivot_price <= 0.0)
    return false;

  bool available[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  double raw_values[PIVOT_FEATURE_RAW_SHIFT_COUNT];
  for(int shift = 0; shift < PIVOT_FEATURE_RAW_SHIFT_COUNT; shift++)
  {
    available[shift] = false;
    raw_values[shift] = 0.0;
    if(!bands.available[shift] ||
       !CalculatePivotBPercent(pivot_price,
                               bands.upper_values[shift],
                               bands.lower_values[shift],
                               raw_values[shift]))
      return false;
    available[shift] = true;
  }
  return DerivePivotFeatureSeries(raw_values, available, series_out);
}

bool CapturePivotContextFeatureSnapshot(
  const double trigger_bid,
  const datetime broker_time,
  PivotContextFeatureSnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.captured = true;
  snapshot_out.broker_time = broker_time;
  snapshot_out.trigger_bid = trigger_bid;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  bool micro_bands_complete = CapturePivotBandEnvelope(
    Micro_Timeframe,
    broker_time,
    snapshot_out.micro_bands);
  bool macro_bands_complete = CapturePivotBandEnvelope(
    Macro_Timeframe,
    broker_time,
    snapshot_out.macro_bands);
  bool micro_stochastic_complete = CapturePivotStochasticLines(
    Micro_Timeframe,
    broker_time,
    snapshot_out.micro_stochastic);
  bool macro_stochastic_complete = CapturePivotStochasticLines(
    Macro_Timeframe,
    broker_time,
    snapshot_out.macro_stochastic);

  if(!micro_bands_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MICRO_" +
                             snapshot_out.micro_bands.invalid_reason);
  if(!macro_bands_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MACRO_" +
                             snapshot_out.macro_bands.invalid_reason);
  if(!micro_stochastic_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MICRO_" +
                             snapshot_out.micro_stochastic.invalid_reason);
  if(!macro_stochastic_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MACRO_" +
                             snapshot_out.macro_stochastic.invalid_reason);

  bool micro_main_complete = DerivePivotFeatureSeries(
    snapshot_out.micro_stochastic.main_line,
    snapshot_out.micro_stochastic.main_line_available,
    snapshot_out.micro_stochastic_main_line_features);
  bool micro_signal_complete = DerivePivotFeatureSeries(
    snapshot_out.micro_stochastic.signal_line,
    snapshot_out.micro_stochastic.signal_line_available,
    snapshot_out.micro_stochastic_signal_line_features);
  bool macro_main_complete = DerivePivotFeatureSeries(
    snapshot_out.macro_stochastic.main_line,
    snapshot_out.macro_stochastic.main_line_available,
    snapshot_out.macro_stochastic_main_line_features);
  bool macro_signal_complete = DerivePivotFeatureSeries(
    snapshot_out.macro_stochastic.signal_line,
    snapshot_out.macro_stochastic.signal_line_available,
    snapshot_out.macro_stochastic_signal_line_features);
  bool micro_trend_complete = DerivePivotBandTrend(
    snapshot_out.micro_bands,
    point_size,
    snapshot_out.micro_band_trend);
  bool macro_trend_complete = DerivePivotBandTrend(
    snapshot_out.macro_bands,
    point_size,
    snapshot_out.macro_band_trend);

  if(!micro_main_complete || !micro_signal_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MICRO_STOCHASTIC_DERIVATION_INVALID");
  if(!macro_main_complete || !macro_signal_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MACRO_STOCHASTIC_DERIVATION_INVALID");
  if(!micro_trend_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MICRO_BAND_TREND_INVALID");
  if(!macro_trend_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MACRO_BAND_TREND_INVALID");

  if(snapshot_out.micro_band_trend.width_available)
  {
    snapshot_out.micro_band_base_0 =
      snapshot_out.micro_bands.base_values[0];
    snapshot_out.micro_band_upper_0 =
      snapshot_out.micro_bands.upper_values[0];
    snapshot_out.micro_band_lower_0 =
      snapshot_out.micro_bands.lower_values[0];
    snapshot_out.micro_band_width_0 =
      snapshot_out.micro_band_trend.width_price_0;
    if(snapshot_out.micro_band_base_0 > 0.0)
    {
      snapshot_out.micro_band_width_percent_0 =
        100.0 * snapshot_out.micro_band_width_0 /
        snapshot_out.micro_band_base_0;
    }
  }

  snapshot_out.micro_complete =
    micro_bands_complete &&
    micro_stochastic_complete &&
    micro_main_complete &&
    micro_signal_complete &&
    micro_trend_complete;
  snapshot_out.macro_complete =
    macro_bands_complete &&
    macro_stochastic_complete &&
    macro_main_complete &&
    macro_signal_complete &&
    macro_trend_complete;
  snapshot_out.complete =
    snapshot_out.micro_complete && snapshot_out.macro_complete;
  return snapshot_out.complete;
}

bool BuildPivotSignalFeatureSnapshot(
  const PivotContextFeatureSnapshot &shared_snapshot,
  const double pivot_price,
  PivotContextFeatureSnapshot &signal_snapshot_out)
{
  signal_snapshot_out.CopyFrom(shared_snapshot);
  signal_snapshot_out.pivot_price = pivot_price;
  signal_snapshot_out.micro_b_percent_features.Reset();
  signal_snapshot_out.macro_b_percent_features.Reset();
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    signal_snapshot_out.micro_b_percent_available[shift] = false;
    signal_snapshot_out.micro_b_percent[shift] = 0.0;
    signal_snapshot_out.macro_pivot_b_percent_available[shift] = false;
    signal_snapshot_out.macro_pivot_b_percent[shift] = 0.0;
  }

  bool micro_b_percent_complete = BuildPivotBPercentSeries(
    pivot_price,
    signal_snapshot_out.micro_bands,
    signal_snapshot_out.micro_b_percent_features);
  bool macro_b_percent_complete = BuildPivotBPercentSeries(
    pivot_price,
    signal_snapshot_out.macro_bands,
    signal_snapshot_out.macro_b_percent_features);
  if(!micro_b_percent_complete)
    AppendPivotFeatureReason(signal_snapshot_out.invalid_reason,
                             "MICRO_B_PERCENT_INVALID");
  if(!macro_b_percent_complete)
    AppendPivotFeatureReason(signal_snapshot_out.invalid_reason,
                             "MACRO_B_PERCENT_INVALID");

  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    if(signal_snapshot_out.micro_b_percent_features.available[shift])
    {
      signal_snapshot_out.micro_b_percent_available[shift] = true;
      signal_snapshot_out.micro_b_percent[shift] =
        signal_snapshot_out.micro_b_percent_features.raw_values[shift];
    }
    if(signal_snapshot_out.macro_b_percent_features.available[shift])
    {
      signal_snapshot_out.macro_pivot_b_percent_available[shift] = true;
      signal_snapshot_out.macro_pivot_b_percent[shift] =
        signal_snapshot_out.macro_b_percent_features.raw_values[shift];
    }
  }

  signal_snapshot_out.micro_complete =
    shared_snapshot.micro_complete && micro_b_percent_complete;
  signal_snapshot_out.macro_complete =
    shared_snapshot.macro_complete && macro_b_percent_complete;
  signal_snapshot_out.complete =
    signal_snapshot_out.micro_complete &&
    signal_snapshot_out.macro_complete;
  return signal_snapshot_out.complete;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
