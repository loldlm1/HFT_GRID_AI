//+------------------------------------------------------------------+
//|              microservices/indicators/stochastic_indicator.mqh  |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_STOCHASTIC_INDICATOR_MQH_
#define _MICROSERVICES_INDICATORS_STOCHASTIC_INDICATOR_MQH_

#include "../core/enums.mqh"
#include "../core/base_structures.mqh"

struct StochasticStructure
{
  // INDICATOR INFO
  ENUM_TIMEFRAMES indicator_timeframe;
  int             indicator_period;
  // STOCHASTIC VALUES
  double stochastic_0;
  double stochastic_1;
  double stochastic_2;
  double stochastic_3;
  // STOCHASTIC SIGNALS
  double stochastic_signal_0;
  double stochastic_signal_1;
  double stochastic_signal_2;
  double stochastic_signal_3;
  // STOCHASTIC SLOPES
  SlopeTypes stochastic_slope_0;
  SlopeTypes stochastic_slope_1;
  SlopeTypes stochastic_slope_2;
  SlopeTypes stochastic_slope_3;
  // STOCHASTIC SIGNAL SLOPES
  SlopeTypes stochastic_signal_slope_0;
  SlopeTypes stochastic_signal_slope_1;
  SlopeTypes stochastic_signal_slope_2;
  SlopeTypes stochastic_signal_slope_3;
  // STOCHASTIC PERCENTILS
  PercentilTypes stochastic_percentil_0;
  PercentilTypes stochastic_percentil_1;
  PercentilTypes stochastic_percentil_2;
  PercentilTypes stochastic_percentil_3;
  // STOCHASTIC SIGNAL PERCENTILS
  PercentilTypes stochastic_signal_percentil_0;
  PercentilTypes stochastic_signal_percentil_1;
  PercentilTypes stochastic_signal_percentil_2;
  PercentilTypes stochastic_signal_percentil_3;
  // STOCHASTIC TREND
  SignalTypes stochastic_trend_0;
  SignalTypes stochastic_trend_1;
  SignalTypes stochastic_trend_2;
  SignalTypes stochastic_trend_3;

  // DEFAULT CONSTRUCTOR
  StochasticStructure()
  {
    indicator_timeframe           = PERIOD_CURRENT;
    indicator_period              = 0;
    stochastic_0                  = 0.0;
    stochastic_1                  = 0.0;
    stochastic_2                  = 0.0;
    stochastic_3                  = 0.0;
    stochastic_signal_0           = 0.0;
    stochastic_signal_1           = 0.0;
    stochastic_signal_2           = 0.0;
    stochastic_signal_3           = 0.0;
    stochastic_slope_0            = NO_SLOPE;
    stochastic_slope_1            = NO_SLOPE;
    stochastic_slope_2            = NO_SLOPE;
    stochastic_slope_3            = NO_SLOPE;
    stochastic_signal_slope_0     = NO_SLOPE;
    stochastic_signal_slope_1     = NO_SLOPE;
    stochastic_signal_slope_2     = NO_SLOPE;
    stochastic_signal_slope_3     = NO_SLOPE;
    stochastic_percentil_0        = PERCENTIL_NULL;
    stochastic_percentil_1        = PERCENTIL_NULL;
    stochastic_percentil_2        = PERCENTIL_NULL;
    stochastic_percentil_3        = PERCENTIL_NULL;
    stochastic_signal_percentil_0 = PERCENTIL_NULL;
    stochastic_signal_percentil_1 = PERCENTIL_NULL;
    stochastic_signal_percentil_2 = PERCENTIL_NULL;
    stochastic_signal_percentil_3 = PERCENTIL_NULL;
    stochastic_trend_0            = NO_SIGNAL;
    stochastic_trend_1            = NO_SIGNAL;
    stochastic_trend_2            = NO_SIGNAL;
    stochastic_trend_3            = NO_SIGNAL;
  }

  // COPY CONSTRUCTOR
  StochasticStructure(StochasticStructure &stochastic_structure)
  {
    indicator_timeframe           = stochastic_structure.indicator_timeframe;
    indicator_period              = stochastic_structure.indicator_period;
    stochastic_0                  = stochastic_structure.stochastic_0;
    stochastic_1                  = stochastic_structure.stochastic_1;
    stochastic_2                  = stochastic_structure.stochastic_2;
    stochastic_3                  = stochastic_structure.stochastic_3;
    stochastic_signal_0           = stochastic_structure.stochastic_signal_0;
    stochastic_signal_1           = stochastic_structure.stochastic_signal_1;
    stochastic_signal_2           = stochastic_structure.stochastic_signal_2;
    stochastic_signal_3           = stochastic_structure.stochastic_signal_3;
    stochastic_slope_0            = stochastic_structure.stochastic_slope_0;
    stochastic_slope_1            = stochastic_structure.stochastic_slope_1;
    stochastic_slope_2            = stochastic_structure.stochastic_slope_2;
    stochastic_slope_3            = stochastic_structure.stochastic_slope_3;
    stochastic_signal_slope_0     = stochastic_structure.stochastic_signal_slope_0;
    stochastic_signal_slope_1     = stochastic_structure.stochastic_signal_slope_1;
    stochastic_signal_slope_2     = stochastic_structure.stochastic_signal_slope_2;
    stochastic_signal_slope_3     = stochastic_structure.stochastic_signal_slope_3;
    stochastic_percentil_0        = stochastic_structure.stochastic_percentil_0;
    stochastic_percentil_1        = stochastic_structure.stochastic_percentil_1;
    stochastic_percentil_2        = stochastic_structure.stochastic_percentil_2;
    stochastic_percentil_3        = stochastic_structure.stochastic_percentil_3;
    stochastic_signal_percentil_0 = stochastic_structure.stochastic_signal_percentil_0;
    stochastic_signal_percentil_1 = stochastic_structure.stochastic_signal_percentil_1;
    stochastic_signal_percentil_2 = stochastic_structure.stochastic_signal_percentil_2;
    stochastic_signal_percentil_3 = stochastic_structure.stochastic_signal_percentil_3;
    stochastic_trend_0            = stochastic_structure.stochastic_trend_0;
    stochastic_trend_1            = stochastic_structure.stochastic_trend_1;
    stochastic_trend_2            = stochastic_structure.stochastic_trend_2;
    stochastic_trend_3            = stochastic_structure.stochastic_trend_3;
  }

  // INITIALIZE STRUCTURE VALUES
  void InitStochasticStructureValues(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    indicator_timeframe       = stochastic_indicator_handle.indicator_timeframe;
    indicator_period          = stochastic_indicator_handle.indicator_period;
    stochastic_0              = GetStochasticValue(stochastic_indicator_handle, index);
    stochastic_1              = GetStochasticValue(stochastic_indicator_handle, index+1);
    stochastic_2              = GetStochasticValue(stochastic_indicator_handle, index+2);
    stochastic_3              = GetStochasticValue(stochastic_indicator_handle, index+3);

    stochastic_signal_0       = GetStochasticSignalValue(stochastic_indicator_handle, index);
    stochastic_signal_1       = GetStochasticSignalValue(stochastic_indicator_handle, index+1);
    stochastic_signal_2       = GetStochasticSignalValue(stochastic_indicator_handle, index+2);
    stochastic_signal_3       = GetStochasticSignalValue(stochastic_indicator_handle, index+3);

    stochastic_slope_0        = GetStochasticSlope(stochastic_indicator_handle, index);
    stochastic_slope_1        = GetStochasticSlope(stochastic_indicator_handle, index+1);
    stochastic_slope_2        = GetStochasticSlope(stochastic_indicator_handle, index+2);
    stochastic_slope_3        = GetStochasticSlope(stochastic_indicator_handle, index+3);

    stochastic_signal_slope_0 = GetStochasticSignalSlope(stochastic_indicator_handle, index);
    stochastic_signal_slope_1 = GetStochasticSignalSlope(stochastic_indicator_handle, index+1);
    stochastic_signal_slope_2 = GetStochasticSignalSlope(stochastic_indicator_handle, index+2);
    stochastic_signal_slope_3 = GetStochasticSignalSlope(stochastic_indicator_handle, index+3);

    stochastic_percentil_0      = GetStochasticPercentil(stochastic_indicator_handle, index);
    stochastic_percentil_1      = GetStochasticPercentil(stochastic_indicator_handle, index+1);
    stochastic_percentil_2      = GetStochasticPercentil(stochastic_indicator_handle, index+2);
    stochastic_percentil_3      = GetStochasticPercentil(stochastic_indicator_handle, index+3);

    stochastic_signal_percentil_0 = GetStochasticSignalPercentil(stochastic_indicator_handle, index);
    stochastic_signal_percentil_1 = GetStochasticSignalPercentil(stochastic_indicator_handle, index+1);
    stochastic_signal_percentil_2 = GetStochasticSignalPercentil(stochastic_indicator_handle, index+2);
    stochastic_signal_percentil_3 = GetStochasticSignalPercentil(stochastic_indicator_handle, index+3);

    stochastic_trend_0        = GetStochasticTrend(stochastic_indicator_handle, index);
    stochastic_trend_1        = GetStochasticTrend(stochastic_indicator_handle, index+1);
    stochastic_trend_2        = GetStochasticTrend(stochastic_indicator_handle, index+2);
    stochastic_trend_3        = GetStochasticTrend(stochastic_indicator_handle, index+3);
  }

  // ++ STOCHASTIC INDICATOR FUNCTIONS ++

  double GetStochasticValue(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double stochastic_value[];

    if(CopyBuffer(stochastic_indicator_handle.indicator_handle, 0, 0, index+1, stochastic_value) <= 0)
    {
      Print("ERROR READING STOCHASTIC INDICATOR DATA");
    }

    ArraySetAsSeries(stochastic_value, true);

    // ROUNDS TO 2 DECIMALS FOR PERCENTAGE VALUES
    double value = NormalizeDouble(stochastic_value[index], 2);

    // TIMESTAMP VERIFICATION LOGGING (M1 ONLY)
    if(Enable_Verification_Logs && stochastic_indicator_handle.indicator_timeframe == PERIOD_M1)
    {
      datetime candle_time = iTime(_Symbol, stochastic_indicator_handle.indicator_timeframe, index);
      PrintFormat("[VERIFY-Stochastic] TF=%s, Shift=%d, Time=%s, Value=%.2f",
                  TimeframeToString(stochastic_indicator_handle.indicator_timeframe),
                  index,
                  TimeToString(candle_time, TIME_DATE|TIME_MINUTES),
                  value);
    }

    return value;
  }

  double GetStochasticSignalValue(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double stochastic_signal_value[];

    if(CopyBuffer(stochastic_indicator_handle.indicator_handle, 1, 0, index+1, stochastic_signal_value) <= 0)
    {
      Print("ERROR READING STOCHASTIC SIGNAL INDICATOR DATA");
    }

    ArraySetAsSeries(stochastic_signal_value, true);

    // ROUNDS TO 2 DECIMALS FOR PERCENTAGE VALUES
    double value = NormalizeDouble(stochastic_signal_value[index], 2);

    // TIMESTAMP VERIFICATION LOGGING (M1 ONLY)
    if(Enable_Verification_Logs && stochastic_indicator_handle.indicator_timeframe == PERIOD_M1)
    {
      datetime candle_time = iTime(_Symbol, stochastic_indicator_handle.indicator_timeframe, index);
      PrintFormat("[VERIFY-StochSignal] TF=%s, Shift=%d, Time=%s, Value=%.2f",
                  TimeframeToString(stochastic_indicator_handle.indicator_timeframe),
                  index,
                  TimeToString(candle_time, TIME_DATE|TIME_MINUTES),
                  value);
    }

    return value;
  }

  SlopeTypes GetStochasticSlope(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double current_value  = GetStochasticValue(stochastic_indicator_handle, index);
    double previous_value = GetStochasticValue(stochastic_indicator_handle, index + 1);

    if(current_value > previous_value) return(UP_SLOPE);
    if(current_value < previous_value) return(DOWN_SLOPE);

    return(NO_SLOPE);
  }

  SlopeTypes GetStochasticSignalSlope(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double current_value  = GetStochasticSignalValue(stochastic_indicator_handle, index);
    double previous_value = GetStochasticSignalValue(stochastic_indicator_handle, index + 1);

    if(current_value > previous_value) return(UP_SLOPE);
    if(current_value < previous_value) return(DOWN_SLOPE);

    return(NO_SLOPE);
  }

  PercentilTypes GetStochasticPercentil(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double stochastic_value = GetStochasticValue(stochastic_indicator_handle, index);

    if(stochastic_value >=  0.0 && stochastic_value < 10.0)   return(PERCENTIL_0);
    if(stochastic_value >= 10.0 && stochastic_value < 20.0)   return(PERCENTIL_10);
    if(stochastic_value >= 20.0 && stochastic_value < 30.0)   return(PERCENTIL_20);
    if(stochastic_value >= 30.0 && stochastic_value < 40.0)   return(PERCENTIL_30);
    if(stochastic_value >= 40.0 && stochastic_value < 50.0)   return(PERCENTIL_40);
    if(stochastic_value >= 50.0 && stochastic_value < 60.0)   return(PERCENTIL_50);
    if(stochastic_value >= 60.0 && stochastic_value < 70.0)   return(PERCENTIL_60);
    if(stochastic_value >= 70.0 && stochastic_value < 80.0)   return(PERCENTIL_70);
    if(stochastic_value >= 80.0 && stochastic_value < 90.0)   return(PERCENTIL_80);
    if(stochastic_value >= 90.0 && stochastic_value <= 100.0) return(PERCENTIL_90);

    return(PERCENTIL_NULL);
  }

  PercentilTypes GetStochasticSignalPercentil(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double stochastic_signal_value = GetStochasticSignalValue(stochastic_indicator_handle, index);

    if(stochastic_signal_value >=  0.0 && stochastic_signal_value < 10.0)   return(PERCENTIL_0);
    if(stochastic_signal_value >= 10.0 && stochastic_signal_value < 20.0)   return(PERCENTIL_10);
    if(stochastic_signal_value >= 20.0 && stochastic_signal_value < 30.0)   return(PERCENTIL_20);
    if(stochastic_signal_value >= 30.0 && stochastic_signal_value < 40.0)   return(PERCENTIL_30);
    if(stochastic_signal_value >= 40.0 && stochastic_signal_value < 50.0)   return(PERCENTIL_40);
    if(stochastic_signal_value >= 50.0 && stochastic_signal_value < 60.0)   return(PERCENTIL_50);
    if(stochastic_signal_value >= 60.0 && stochastic_signal_value < 70.0)   return(PERCENTIL_60);
    if(stochastic_signal_value >= 70.0 && stochastic_signal_value < 80.0)   return(PERCENTIL_70);
    if(stochastic_signal_value >= 80.0 && stochastic_signal_value < 90.0)   return(PERCENTIL_80);
    if(stochastic_signal_value >= 90.0 && stochastic_signal_value <= 100.0) return(PERCENTIL_90);

    return(PERCENTIL_NULL);
  }

  SignalTypes GetStochasticTrend(IndicatorsHandleInfo &stochastic_indicator_handle, int index)
  {
    double stochastic_value        = GetStochasticValue(stochastic_indicator_handle, index);
    double stochastic_signal_value = GetStochasticSignalValue(stochastic_indicator_handle, index);

    if(stochastic_value > stochastic_signal_value) return(BULLISH);
    if(stochastic_value < stochastic_signal_value) return(BEARISH);

    return(NO_SIGNAL);
  }
};

#endif // _MICROSERVICES_INDICATORS_STOCHASTIC_INDICATOR_MQH_
