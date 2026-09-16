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
  PivotBandEnvelopeSnapshot lower_bands;
  PivotBandEnvelopeSnapshot own_bands;
  PivotStochasticLinesSnapshot lower_stochastic;
  PivotStochasticLinesSnapshot own_stochastic;
  PivotDerivedFeatureSeries lower_b_percent_features;
  PivotDerivedFeatureSeries own_b_percent_features;
  PivotDerivedFeatureSeries lower_stochastic_main_line_features;
  PivotDerivedFeatureSeries lower_stochastic_signal_line_features;
  PivotDerivedFeatureSeries own_stochastic_main_line_features;
  PivotDerivedFeatureSeries own_stochastic_signal_line_features;
  PivotBandTrendSnapshot lower_band_trend;
  PivotBandTrendSnapshot own_band_trend;
  bool lower_complete;
  bool own_complete;
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
    lower_bands.Reset(PERIOD_CURRENT);
    own_bands.Reset(PERIOD_CURRENT);
    lower_stochastic.Reset(PERIOD_CURRENT);
    own_stochastic.Reset(PERIOD_CURRENT);
    lower_b_percent_features.Reset();
    own_b_percent_features.Reset();
    lower_stochastic_main_line_features.Reset();
    lower_stochastic_signal_line_features.Reset();
    own_stochastic_main_line_features.Reset();
    own_stochastic_signal_line_features.Reset();
    lower_band_trend.Reset();
    own_band_trend.Reset();
    lower_complete = false;
    own_complete = false;
    invalid_reason = "";
  }

  void CopyFrom(const PivotContextFeatureSnapshot &other)
  {
    captured = other.captured;
    complete = other.complete;
    broker_time = other.broker_time;
    trigger_bid = other.trigger_bid;
    pivot_price = other.pivot_price;
    lower_bands.CopyFrom(other.lower_bands);
    own_bands.CopyFrom(other.own_bands);
    lower_stochastic.CopyFrom(other.lower_stochastic);
    own_stochastic.CopyFrom(other.own_stochastic);
    lower_b_percent_features.CopyFrom(other.lower_b_percent_features);
    own_b_percent_features.CopyFrom(other.own_b_percent_features);
    lower_stochastic_main_line_features.CopyFrom(
      other.lower_stochastic_main_line_features);
    lower_stochastic_signal_line_features.CopyFrom(
      other.lower_stochastic_signal_line_features);
    own_stochastic_main_line_features.CopyFrom(
      other.own_stochastic_main_line_features);
    own_stochastic_signal_line_features.CopyFrom(
      other.own_stochastic_signal_line_features);
    lower_band_trend.CopyFrom(other.lower_band_trend);
    own_band_trend.CopyFrom(other.own_band_trend);
    lower_complete = other.lower_complete;
    own_complete = other.own_complete;
    invalid_reason = other.invalid_reason;
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
  if(timeframe == Deep_Timeframe)
    return g_deep_bands_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_bands_handle.indicator_handle;
  return INVALID_HANDLE;
}

int PivotStochasticHandleForTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  if(timeframe == Macro_Timeframe)
    return g_macro_stochastic_handle.indicator_handle;
  if(timeframe == Deep_Timeframe)
    return g_deep_stochastic_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_stochastic_handle.indicator_handle;
  return INVALID_HANDLE;
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
  const ENUM_TIMEFRAMES own_timeframe,
  const ENUM_TIMEFRAMES lower_timeframe,
  const double trigger_bid,
  const datetime broker_time,
  PivotContextFeatureSnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.captured = true;
  snapshot_out.broker_time = broker_time;
  snapshot_out.trigger_bid = trigger_bid;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  bool lower_bands_complete = CapturePivotBandEnvelope(
    lower_timeframe,
    broker_time,
    snapshot_out.lower_bands);
  bool own_bands_complete = CapturePivotBandEnvelope(
    own_timeframe,
    broker_time,
    snapshot_out.own_bands);
  bool lower_stochastic_complete = CapturePivotStochasticLines(
    lower_timeframe,
    broker_time,
    snapshot_out.lower_stochastic);
  bool own_stochastic_complete = CapturePivotStochasticLines(
    own_timeframe,
    broker_time,
    snapshot_out.own_stochastic);

  if(!lower_bands_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "LOWER_" +
                             snapshot_out.lower_bands.invalid_reason);
  if(!own_bands_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "OWN_" +
                             snapshot_out.own_bands.invalid_reason);
  if(!lower_stochastic_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "LOWER_" +
                             snapshot_out.lower_stochastic.invalid_reason);
  if(!own_stochastic_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "OWN_" +
                             snapshot_out.own_stochastic.invalid_reason);

  bool lower_main_complete = DerivePivotFeatureSeries(
    snapshot_out.lower_stochastic.main_line,
    snapshot_out.lower_stochastic.main_line_available,
    snapshot_out.lower_stochastic_main_line_features);
  bool lower_signal_complete = DerivePivotFeatureSeries(
    snapshot_out.lower_stochastic.signal_line,
    snapshot_out.lower_stochastic.signal_line_available,
    snapshot_out.lower_stochastic_signal_line_features);
  bool own_main_complete = DerivePivotFeatureSeries(
    snapshot_out.own_stochastic.main_line,
    snapshot_out.own_stochastic.main_line_available,
    snapshot_out.own_stochastic_main_line_features);
  bool own_signal_complete = DerivePivotFeatureSeries(
    snapshot_out.own_stochastic.signal_line,
    snapshot_out.own_stochastic.signal_line_available,
    snapshot_out.own_stochastic_signal_line_features);
  bool lower_trend_complete = DerivePivotBandTrend(
    snapshot_out.lower_bands,
    point_size,
    snapshot_out.lower_band_trend);
  bool own_trend_complete = DerivePivotBandTrend(
    snapshot_out.own_bands,
    point_size,
    snapshot_out.own_band_trend);

  if(!lower_main_complete || !lower_signal_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "LOWER_STOCHASTIC_DERIVATION_INVALID");
  if(!own_main_complete || !own_signal_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "OWN_STOCHASTIC_DERIVATION_INVALID");
  if(!lower_trend_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "LOWER_BAND_TREND_INVALID");
  if(!own_trend_complete)
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "OWN_BAND_TREND_INVALID");

  snapshot_out.lower_complete =
    lower_bands_complete &&
    lower_stochastic_complete &&
    lower_main_complete &&
    lower_signal_complete &&
    lower_trend_complete;
  snapshot_out.own_complete =
    own_bands_complete &&
    own_stochastic_complete &&
    own_main_complete &&
    own_signal_complete &&
    own_trend_complete;
  snapshot_out.complete =
    snapshot_out.lower_complete && snapshot_out.own_complete;
  return snapshot_out.complete;
}

bool BuildPivotSignalFeatureSnapshot(
  const PivotContextFeatureSnapshot &shared_snapshot,
  const double pivot_price,
  PivotContextFeatureSnapshot &signal_snapshot_out)
{
  signal_snapshot_out.CopyFrom(shared_snapshot);
  signal_snapshot_out.pivot_price = pivot_price;
  signal_snapshot_out.lower_b_percent_features.Reset();
  signal_snapshot_out.own_b_percent_features.Reset();

  bool lower_b_percent_complete = BuildPivotBPercentSeries(
    pivot_price,
    signal_snapshot_out.lower_bands,
    signal_snapshot_out.lower_b_percent_features);
  bool own_b_percent_complete = BuildPivotBPercentSeries(
    pivot_price,
    signal_snapshot_out.own_bands,
    signal_snapshot_out.own_b_percent_features);
  if(!lower_b_percent_complete)
    AppendPivotFeatureReason(signal_snapshot_out.invalid_reason,
                             "LOWER_B_PERCENT_INVALID");
  if(!own_b_percent_complete)
    AppendPivotFeatureReason(signal_snapshot_out.invalid_reason,
                             "OWN_B_PERCENT_INVALID");

  signal_snapshot_out.lower_complete =
    shared_snapshot.lower_complete && lower_b_percent_complete;
  signal_snapshot_out.own_complete =
    shared_snapshot.own_complete && own_b_percent_complete;
  signal_snapshot_out.complete =
    signal_snapshot_out.lower_complete &&
    signal_snapshot_out.own_complete;
  return signal_snapshot_out.complete;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
