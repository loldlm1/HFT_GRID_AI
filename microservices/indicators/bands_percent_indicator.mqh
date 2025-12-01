//+------------------------------------------------------------------+
//|              microservices/indicators/bands_percent_indicator.mqh|
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_BANDS_PERCENT_INDICATOR_MQH_
#define _MICROSERVICES_INDICATORS_BANDS_PERCENT_INDICATOR_MQH_

struct BandsPercentStructure
{
  // INDICATOR INFO
  ENUM_TIMEFRAMES indicator_timeframe;
  int             indicator_period;
  // BAND PERCENT VALUES
  double bands_percent_0;
  double bands_percent_1;
  double bands_percent_2;
  double bands_percent_3;
  double bands_percent_4;
  double bands_percent_5;
  double bands_percent_ma_0;
  double bands_percent_ma_1;
  double bands_percent_ma_2;
  double bands_percent_ma_3;
  double bands_percent_ma_4;
  double bands_percent_ma_5;
  // BAND PERCENT SIGNALS
  double bands_percent_signal_0;
  double bands_percent_signal_1;
  double bands_percent_signal_2;
  double bands_percent_signal_3;
  // BAND PERCENT SLOPES
  SlopeTypes bands_percent_slope_0;
  SlopeTypes bands_percent_slope_1;
  SlopeTypes bands_percent_slope_2;
  SlopeTypes bands_percent_slope_3;
  // BAND PERCENT SIGNAL SLOPES
  SlopeTypes bands_percent_signal_slope_0;
  SlopeTypes bands_percent_signal_slope_1;
  SlopeTypes bands_percent_signal_slope_2;
  SlopeTypes bands_percent_signal_slope_3;
  // BAND PERCENT PERCENTILS
  PercentilTypes bands_percent_percentil_0;
  PercentilTypes bands_percent_percentil_1;
  PercentilTypes bands_percent_percentil_2;
  PercentilTypes bands_percent_percentil_3;
  // BAND PERCENT SIGNAL PERCENTILS
  PercentilTypes bands_percent_signal_percentil_0;
  PercentilTypes bands_percent_signal_percentil_1;
  PercentilTypes bands_percent_signal_percentil_2;
  PercentilTypes bands_percent_signal_percentil_3;
  // BAND PERCENT TREND
  SignalTypes bands_percent_trend_0;
  SignalTypes bands_percent_trend_1;
  SignalTypes bands_percent_trend_2;
  SignalTypes bands_percent_trend_3;
  // BB PERCENT OHLC VALUES
  double bb_close_0;
  double bb_close_1;
  double bb_close_2;
  double bb_close_3;
  double bb_open_0;
  double bb_open_1;
  double bb_open_2;
  double bb_open_3;
  double bb_high_0;
  double bb_high_1;
  double bb_high_2;
  double bb_high_3;
  double bb_low_0;
  double bb_low_1;
  double bb_low_2;
  double bb_low_3;
  double bands_percent_window_high;
  double bands_percent_window_low;

  // DEFAULT CONSTRUCTOR
  BandsPercentStructure()
  {
    indicator_timeframe              = PERIOD_CURRENT;
    indicator_period                 = 0;
    bands_percent_0                  = 0.0;
    bands_percent_1                  = 0.0;
    bands_percent_2                  = 0.0;
    bands_percent_3                  = 0.0;
    bands_percent_4                  = 0.0;
    bands_percent_5                  = 0.0;
    bands_percent_ma_0               = 0.0;
    bands_percent_ma_1               = 0.0;
    bands_percent_ma_2               = 0.0;
    bands_percent_ma_3               = 0.0;
    bands_percent_ma_4               = 0.0;
    bands_percent_ma_5               = 0.0;
    bands_percent_signal_0           = 0.0;
    bands_percent_signal_1           = 0.0;
    bands_percent_signal_2           = 0.0;
    bands_percent_signal_3           = 0.0;
    bands_percent_slope_0            = NO_SLOPE;
    bands_percent_slope_1            = NO_SLOPE;
    bands_percent_slope_2            = NO_SLOPE;
    bands_percent_slope_3            = NO_SLOPE;
    bands_percent_signal_slope_0     = NO_SLOPE;
    bands_percent_signal_slope_1     = NO_SLOPE;
    bands_percent_signal_slope_2     = NO_SLOPE;
    bands_percent_signal_slope_3     = NO_SLOPE;
    bands_percent_percentil_0        = PERCENTIL_NULL;
    bands_percent_percentil_1        = PERCENTIL_NULL;
    bands_percent_percentil_2        = PERCENTIL_NULL;
    bands_percent_percentil_3        = PERCENTIL_NULL;
    bands_percent_signal_percentil_0 = PERCENTIL_NULL;
    bands_percent_signal_percentil_1 = PERCENTIL_NULL;
    bands_percent_signal_percentil_2 = PERCENTIL_NULL;
    bands_percent_signal_percentil_3 = PERCENTIL_NULL;
    bands_percent_trend_0            = NO_SIGNAL;
    bands_percent_trend_1            = NO_SIGNAL;
    bands_percent_trend_2            = NO_SIGNAL;
    bands_percent_trend_3            = NO_SIGNAL;
    bb_close_0                       = 0.0;
    bb_close_1                       = 0.0;
    bb_close_2                       = 0.0;
    bb_close_3                       = 0.0;
    bb_open_0                        = 0.0;
    bb_open_1                        = 0.0;
    bb_open_2                        = 0.0;
    bb_open_3                        = 0.0;
    bb_high_0                        = 0.0;
    bb_high_1                        = 0.0;
    bb_high_2                        = 0.0;
    bb_high_3                        = 0.0;
    bb_low_0                         = 0.0;
    bb_low_1                         = 0.0;
    bb_low_2                         = 0.0;
    bb_low_3                         = 0.0;
    bands_percent_window_high        = EMPTY_VALUE;
    bands_percent_window_low         = EMPTY_VALUE;
  }

  // COPY CONSTRUCTOR
  BandsPercentStructure(const BandsPercentStructure &bands_percent_structure)
  {
    indicator_timeframe              = bands_percent_structure.indicator_timeframe;
    indicator_period                 = bands_percent_structure.indicator_period;
    bands_percent_0                  = bands_percent_structure.bands_percent_0;
    bands_percent_1                  = bands_percent_structure.bands_percent_1;
    bands_percent_2                  = bands_percent_structure.bands_percent_2;
    bands_percent_3                  = bands_percent_structure.bands_percent_3;
    bands_percent_4                  = bands_percent_structure.bands_percent_4;
    bands_percent_5                  = bands_percent_structure.bands_percent_5;
    bands_percent_ma_0               = bands_percent_structure.bands_percent_ma_0;
    bands_percent_ma_1               = bands_percent_structure.bands_percent_ma_1;
    bands_percent_ma_2               = bands_percent_structure.bands_percent_ma_2;
    bands_percent_ma_3               = bands_percent_structure.bands_percent_ma_3;
    bands_percent_ma_4               = bands_percent_structure.bands_percent_ma_4;
    bands_percent_ma_5               = bands_percent_structure.bands_percent_ma_5;
    bands_percent_signal_0           = bands_percent_structure.bands_percent_signal_0;
    bands_percent_signal_1           = bands_percent_structure.bands_percent_signal_1;
    bands_percent_signal_2           = bands_percent_structure.bands_percent_signal_2;
    bands_percent_signal_3           = bands_percent_structure.bands_percent_signal_3;
    bands_percent_slope_0            = bands_percent_structure.bands_percent_slope_0;
    bands_percent_slope_1            = bands_percent_structure.bands_percent_slope_1;
    bands_percent_slope_2            = bands_percent_structure.bands_percent_slope_2;
    bands_percent_slope_3            = bands_percent_structure.bands_percent_slope_3;
    bands_percent_signal_slope_0     = bands_percent_structure.bands_percent_signal_slope_0;
    bands_percent_signal_slope_1     = bands_percent_structure.bands_percent_signal_slope_1;
    bands_percent_signal_slope_2     = bands_percent_structure.bands_percent_signal_slope_2;
    bands_percent_signal_slope_3     = bands_percent_structure.bands_percent_signal_slope_3;
    bands_percent_percentil_0        = bands_percent_structure.bands_percent_percentil_0;
    bands_percent_percentil_1        = bands_percent_structure.bands_percent_percentil_1;
    bands_percent_percentil_2        = bands_percent_structure.bands_percent_percentil_2;
    bands_percent_percentil_3        = bands_percent_structure.bands_percent_percentil_3;
    bands_percent_signal_percentil_0 = bands_percent_structure.bands_percent_signal_percentil_0;
    bands_percent_signal_percentil_1 = bands_percent_structure.bands_percent_signal_percentil_1;
    bands_percent_signal_percentil_2 = bands_percent_structure.bands_percent_signal_percentil_2;
    bands_percent_signal_percentil_3 = bands_percent_structure.bands_percent_signal_percentil_3;
    bands_percent_trend_0            = bands_percent_structure.bands_percent_trend_0;
    bands_percent_trend_1            = bands_percent_structure.bands_percent_trend_1;
    bands_percent_trend_2            = bands_percent_structure.bands_percent_trend_2;
    bands_percent_trend_3            = bands_percent_structure.bands_percent_trend_3;
    bb_close_0                       = bands_percent_structure.bb_close_0;
    bb_close_1                       = bands_percent_structure.bb_close_1;
    bb_close_2                       = bands_percent_structure.bb_close_2;
    bb_close_3                       = bands_percent_structure.bb_close_3;
    bb_open_0                        = bands_percent_structure.bb_open_0;
    bb_open_1                        = bands_percent_structure.bb_open_1;
    bb_open_2                        = bands_percent_structure.bb_open_2;
    bb_open_3                        = bands_percent_structure.bb_open_3;
    bb_high_0                        = bands_percent_structure.bb_high_0;
    bb_high_1                        = bands_percent_structure.bb_high_1;
    bb_high_2                        = bands_percent_structure.bb_high_2;
    bb_high_3                        = bands_percent_structure.bb_high_3;
    bb_low_0                         = bands_percent_structure.bb_low_0;
    bb_low_1                         = bands_percent_structure.bb_low_1;
    bb_low_2                         = bands_percent_structure.bb_low_2;
    bb_low_3                         = bands_percent_structure.bb_low_3;
    bands_percent_window_high        = bands_percent_structure.bands_percent_window_high;
    bands_percent_window_low         = bands_percent_structure.bands_percent_window_low;
  }

  // INITIALIZE STRUCTURE VALUES
  void InitBandsPercentStructureValues(IndicatorsHandleInfo &bands_indicator_handle, int index)
  {
    indicator_timeframe          = bands_indicator_handle.indicator_timeframe;
    indicator_period             = bands_indicator_handle.indicator_period;

    const int signal_period = 5;
    int max_shift = MathMax(5, signal_period + 2);
    int total_points = max_shift + 1;

    double percent_values[];
    if(!ComputePercentSeries(bands_indicator_handle, index, total_points, percent_values))
    {
      ResetComputedOutputs();
      return;
    }

    double signal_values[];
    ComputeSignalSeries(percent_values, ArraySize(percent_values), signal_period, signal_values);
    int percent_series_size = ArraySize(percent_values);
    int signal_series_size  = ArraySize(signal_values);

    bands_percent_0 = ResolvePercentValue(percent_values, percent_series_size, 0);
    bands_percent_1 = ResolvePercentValue(percent_values, percent_series_size, 1);
    bands_percent_2 = ResolvePercentValue(percent_values, percent_series_size, 2);
    bands_percent_3 = ResolvePercentValue(percent_values, percent_series_size, 3);
    bands_percent_4 = ResolvePercentValue(percent_values, percent_series_size, 4);
    bands_percent_5 = ResolvePercentValue(percent_values, percent_series_size, 5);

    bands_percent_ma_0 = ResolvePercentValue(signal_values, signal_series_size, 0);
    bands_percent_ma_1 = ResolvePercentValue(signal_values, signal_series_size, 1);
    bands_percent_ma_2 = ResolvePercentValue(signal_values, signal_series_size, 2);
    bands_percent_ma_3 = ResolvePercentValue(signal_values, signal_series_size, 3);
    bands_percent_ma_4 = ResolvePercentValue(signal_values, signal_series_size, 4);
    bands_percent_ma_5 = ResolvePercentValue(signal_values, signal_series_size, 5);

    bands_percent_signal_0 = ResolvePercentValue(signal_values, signal_series_size, 0);
    bands_percent_signal_1 = ResolvePercentValue(signal_values, signal_series_size, 1);
    bands_percent_signal_2 = ResolvePercentValue(signal_values, signal_series_size, 2);
    bands_percent_signal_3 = ResolvePercentValue(signal_values, signal_series_size, 3);

    bands_percent_slope_0 = ResolveSlopeFromSeries(percent_values, percent_series_size, 0);
    bands_percent_slope_1 = ResolveSlopeFromSeries(percent_values, percent_series_size, 1);
    bands_percent_slope_2 = ResolveSlopeFromSeries(percent_values, percent_series_size, 2);
    bands_percent_slope_3 = ResolveSlopeFromSeries(percent_values, percent_series_size, 3);

    bands_percent_signal_slope_0 = ResolveSlopeFromSeries(signal_values, signal_series_size, 0);
    bands_percent_signal_slope_1 = ResolveSlopeFromSeries(signal_values, signal_series_size, 1);
    bands_percent_signal_slope_2 = ResolveSlopeFromSeries(signal_values, signal_series_size, 2);
    bands_percent_signal_slope_3 = ResolveSlopeFromSeries(signal_values, signal_series_size, 3);

    bands_percent_percentil_0 = ResolvePercentilFromValue(bands_percent_0);
    bands_percent_percentil_1 = ResolvePercentilFromValue(bands_percent_1);
    bands_percent_percentil_2 = ResolvePercentilFromValue(bands_percent_2);
    bands_percent_percentil_3 = ResolvePercentilFromValue(bands_percent_3);

    bands_percent_signal_percentil_0 = ResolvePercentilFromValue(bands_percent_signal_0);
    bands_percent_signal_percentil_1 = ResolvePercentilFromValue(bands_percent_signal_1);
    bands_percent_signal_percentil_2 = ResolvePercentilFromValue(bands_percent_signal_2);
    bands_percent_signal_percentil_3 = ResolvePercentilFromValue(bands_percent_signal_3);

    bands_percent_trend_0 = ResolveTrendFromSeries(percent_values, signal_values, 0);
    bands_percent_trend_1 = ResolveTrendFromSeries(percent_values, signal_values, 1);
    bands_percent_trend_2 = ResolveTrendFromSeries(percent_values, signal_values, 2);
    bands_percent_trend_3 = ResolveTrendFromSeries(percent_values, signal_values, 3);

    // WIP: future implementation needed, right now its not necessary
    bb_close_0 = bb_close_1 = bb_close_2 = bb_close_3 = 0.0;
    bb_open_0  = bb_open_1  = bb_open_2  = bb_open_3  = 0.0;
    bb_high_0  = bb_high_1  = bb_high_2  = bb_high_3  = 0.0;
    bb_low_0   = bb_low_1   = bb_low_2   = bb_low_3   = 0.0;

    double window_high;
    double window_low;
    ComputePercentWindow(percent_values, percent_series_size, signal_period, window_high, window_low);
    bands_percent_window_high = window_high;
    bands_percent_window_low  = window_low;
  }

  void ResetComputedOutputs()
  {
    bands_percent_0 = bands_percent_1 = bands_percent_2 = bands_percent_3 = bands_percent_4 = bands_percent_5 = EMPTY_VALUE;
    bands_percent_ma_0 = bands_percent_ma_1 = bands_percent_ma_2 = bands_percent_ma_3 = bands_percent_ma_4 = bands_percent_ma_5 = EMPTY_VALUE;
    bands_percent_signal_0 = bands_percent_signal_1 = bands_percent_signal_2 = bands_percent_signal_3 = EMPTY_VALUE;
    bands_percent_slope_0 = bands_percent_slope_1 = bands_percent_slope_2 = bands_percent_slope_3 = NO_SLOPE;
    bands_percent_signal_slope_0 = bands_percent_signal_slope_1 = bands_percent_signal_slope_2 = bands_percent_signal_slope_3 = NO_SLOPE;
    bands_percent_percentil_0 = bands_percent_percentil_1 = bands_percent_percentil_2 = bands_percent_percentil_3 = PERCENTIL_NULL;
    bands_percent_signal_percentil_0 = bands_percent_signal_percentil_1 = bands_percent_signal_percentil_2 = bands_percent_signal_percentil_3 = PERCENTIL_NULL;
    bands_percent_trend_0 = bands_percent_trend_1 = bands_percent_trend_2 = bands_percent_trend_3 = NO_SIGNAL;
    bands_percent_window_high = bands_percent_window_low = EMPTY_VALUE;
    bb_close_0 = bb_close_1 = bb_close_2 = bb_close_3 = 0.0;
    bb_open_0  = bb_open_1  = bb_open_2  = bb_open_3  = 0.0;
    bb_high_0  = bb_high_1  = bb_high_2  = bb_high_3  = 0.0;
    bb_low_0   = bb_low_1   = bb_low_2   = bb_low_3   = 0.0;
  }

  int ResolveChannelUpperBufferIndex()
  {
    if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_ATR)
      return 0;
    if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_KELTNER)
      return 0;
    return 0;
  }

  int ResolveChannelLowerBufferIndex()
  {
    if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_ATR)
      return 1;
    if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_KELTNER)
      return 2;
    return 2;
  }

  bool CopyChannelBufferValues(IndicatorsHandleInfo &bands_indicator_handle,
                               const int buffer_index,
                               const int index,
                               const int total_points,
                               double &values[])
  {
    if(CopyBuffer(bands_indicator_handle.indicator_handle,
                  buffer_index,
                  index,
                  total_points,
                  values) <= 0)
    {
      Print("ERROR READING CHANNEL DATA FOR PERCENT COMPUTATION | tf=",
            EnumToString(bands_indicator_handle.indicator_timeframe));
      return false;
    }

    ArraySetAsSeries(values, true);
    return true;
  }

  bool ComputePercentSeries(IndicatorsHandleInfo &bands_indicator_handle,
                            const int index,
                            const int total_points,
                            double &percent_values[])
  {
    if(bands_indicator_handle.indicator_handle == INVALID_HANDLE)
    {
      Print("INVALID CHANNEL HANDLE FOR PERCENT COMPUTATION | tf=",
            EnumToString(bands_indicator_handle.indicator_timeframe));
      return false;
    }

    ArrayResize(percent_values, total_points);

    double upper_values[];
    double lower_values[];
    int upper_buffer_index = ResolveChannelUpperBufferIndex();
    int lower_buffer_index = ResolveChannelLowerBufferIndex();

    if(!CopyChannelBufferValues(bands_indicator_handle,
                                upper_buffer_index,
                                index,
                                total_points,
                                upper_values))
    {
      return false;
    }

    if(!CopyChannelBufferValues(bands_indicator_handle,
                                lower_buffer_index,
                                index,
                                total_points,
                                lower_values))
    {
      return false;
    }

    double close_series[];
    if(CopyClose(_Symbol,
                 bands_indicator_handle.indicator_timeframe,
                 index,
                 total_points,
                 close_series) <= 0)
    {
      Print("ERROR READING CLOSE PRICES FOR PERCENT COMPUTATION | tf=",
            EnumToString(bands_indicator_handle.indicator_timeframe));
      return false;
    }
    ArraySetAsSeries(close_series, true);

    for(int i = 0; i < total_points; i++)
    {
      double upper = upper_values[i];
      double lower = lower_values[i];
      double close_price = close_series[i];
      if(upper == EMPTY_VALUE || lower == EMPTY_VALUE || close_price == EMPTY_VALUE)
      {
        percent_values[i] = EMPTY_VALUE;
        continue;
      }
      double range = upper - lower;
      if(range <= 0.0)
      {
        percent_values[i] = EMPTY_VALUE;
        continue;
      }
      double normalized = (close_price - lower) / range * 100.0;
      percent_values[i] = NormalizeDouble(normalized, 2);
    }

    return true;
  }

  void ComputeSignalSeries(const double &percent_values[],
                           const int percent_series_size,
                           const int signal_period,
                           double &signal_values[])
  {
    int required = 4;
    ArrayResize(signal_values, required);
    for(int shift = 0; shift < required; shift++)
    {
      if(signal_period <= 0 || shift + signal_period > percent_series_size)
      {
        signal_values[shift] = EMPTY_VALUE;
        continue;
      }

      bool valid = true;
      double sum = 0.0;
      for(int offset = 0; offset < signal_period; offset++)
      {
        double value = percent_values[shift + offset];
        if(value == EMPTY_VALUE)
        {
          valid = false;
          break;
        }
        sum += value;
      }

      if(!valid)
        signal_values[shift] = EMPTY_VALUE;
      else
        signal_values[shift] = NormalizeDouble(sum / signal_period, 2);
    }
  }

  double ResolvePercentValue(const double &series[], const int total, const int shift)
  {
    if(shift >= total || shift < 0)
      return EMPTY_VALUE;
    return series[shift];
  }

  SlopeTypes ResolveSlopeFromSeries(const double &series[], const int total, const int shift)
  {
    if(shift + 1 >= total)
      return NO_SLOPE;
    double current_value  = series[shift];
    double previous_value = series[shift + 1];
    if(current_value == EMPTY_VALUE || previous_value == EMPTY_VALUE)
      return NO_SLOPE;
    if(current_value > previous_value)
      return UP_SLOPE;
    if(current_value < previous_value)
      return DOWN_SLOPE;
    return NO_SLOPE;
  }

  PercentilTypes ResolvePercentilFromValue(const double value)
  {
    if(value == EMPTY_VALUE)
      return PERCENTIL_NULL;
    if(value <= 0.0)                                         return(PERCENTIL_MIN);
    if(value >  0.0 && value < 10.0)   return(PERCENTIL_0);
    if(value >= 10.0 && value < 20.0)  return(PERCENTIL_10);
    if(value >= 20.0 && value < 30.0)  return(PERCENTIL_20);
    if(value >= 30.0 && value < 40.0)  return(PERCENTIL_30);
    if(value >= 40.0 && value < 50.0)  return(PERCENTIL_40);
    if(value >= 50.0 && value < 60.0)  return(PERCENTIL_50);
    if(value >= 60.0 && value < 70.0)  return(PERCENTIL_60);
    if(value >= 70.0 && value < 80.0)  return(PERCENTIL_70);
    if(value >= 80.0 && value < 90.0)  return(PERCENTIL_80);
    if(value >= 90.0 && value < 100.0) return(PERCENTIL_90);
    if(value >= 100.0)                 return(PERCENTIL_MAX);
    return(PERCENTIL_NULL);
  }

  SignalTypes ResolveTrendFromSeries(const double &percent_series[],
                                     const double &signal_series[],
                                     const int shift)
  {
    int percent_total = ArraySize(percent_series);
    int signal_total  = ArraySize(signal_series);
    if(shift >= percent_total || shift >= signal_total)
      return NO_SIGNAL;

    double percent_value = percent_series[shift];
    double signal_value  = signal_series[shift];
    if(percent_value == EMPTY_VALUE || signal_value == EMPTY_VALUE)
      return NO_SIGNAL;

    if(percent_value > signal_value)
      return BULLISH;
    if(percent_value < signal_value)
      return BEARISH;
    return NO_SIGNAL;
  }

  void ComputePercentWindow(const double &percent_series[],
                            const int percent_series_size,
                            const int window,
                            double &window_high,
                            double &window_low)
  {
    if(window <= 0 || window > percent_series_size)
    {
      window_high = EMPTY_VALUE;
      window_low  = EMPTY_VALUE;
      return;
    }

    window_high = percent_series[0];
    window_low  = percent_series[0];

    for(int i = 0; i < window; i++)
    {
      double value = percent_series[i];
      if(value == EMPTY_VALUE)
      {
        window_high = EMPTY_VALUE;
        window_low  = EMPTY_VALUE;
        return;
      }
      if(value > window_high)
        window_high = value;
      if(value < window_low)
        window_low = value;
    }
  }

};

#endif // _MICROSERVICES_INDICATORS_BANDS_PERCENT_INDICATOR_MQH_
