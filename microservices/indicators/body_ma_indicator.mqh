//+------------------------------------------------------------------+
//|              microservices/indicators/body_ma_indicator.mqh      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_BODY_MA_INDICATOR_MQH_
#define _MICROSERVICES_INDICATORS_BODY_MA_INDICATOR_MQH_

#include "../core/enums.mqh"
#include "../core/base_structures.mqh"

struct BodyMAStructure
{
  // INDICATOR INFO
  ENUM_TIMEFRAMES indicator_timeframe;
  int             indicator_period;
  // BODY VALUES
  double body_value_0;
  double body_value_1;
  double body_value_2;
  double body_value_3;
  // BODY MA VALUES
  double body_ma_0;
  double body_ma_1;
  double body_ma_2;
  double body_ma_3;
  // BODY TRENDS
  BodyTrendTypes body_trend_0;
  BodyTrendTypes body_trend_1;
  BodyTrendTypes body_trend_2;
  BodyTrendTypes body_trend_3;
  // BODY MA STATES
  BodyMATypes body_ma_state_0;
  BodyMATypes body_ma_state_1;
  BodyMATypes body_ma_state_2;
  BodyMATypes body_ma_state_3;

  // DEFAULT CONSTRUCTOR
  BodyMAStructure()
  {
    indicator_timeframe = PERIOD_CURRENT;
    indicator_period    = 0;
    body_value_0        = 0.0;
    body_value_1        = 0.0;
    body_value_2        = 0.0;
    body_value_3        = 0.0;
    body_ma_0           = 0.0;
    body_ma_1           = 0.0;
    body_ma_2           = 0.0;
    body_ma_3           = 0.0;
    body_trend_0        = BODY_UNDEFINED;
    body_trend_1        = BODY_UNDEFINED;
    body_trend_2        = BODY_UNDEFINED;
    body_trend_3        = BODY_UNDEFINED;
    body_ma_state_0     = BODY_UNDEFINED_MA;
    body_ma_state_1     = BODY_UNDEFINED_MA;
    body_ma_state_2     = BODY_UNDEFINED_MA;
    body_ma_state_3     = BODY_UNDEFINED_MA;
  }

  // COPY CONSTRUCTOR
  BodyMAStructure(const BodyMAStructure &body_ma_structure)
  {
    indicator_timeframe = body_ma_structure.indicator_timeframe;
    indicator_period    = body_ma_structure.indicator_period;
    body_value_0        = body_ma_structure.body_value_0;
    body_value_1        = body_ma_structure.body_value_1;
    body_value_2        = body_ma_structure.body_value_2;
    body_value_3        = body_ma_structure.body_value_3;
    body_ma_0           = body_ma_structure.body_ma_0;
    body_ma_1           = body_ma_structure.body_ma_1;
    body_ma_2           = body_ma_structure.body_ma_2;
    body_ma_3           = body_ma_structure.body_ma_3;
    body_trend_0        = body_ma_structure.body_trend_0;
    body_trend_1        = body_ma_structure.body_trend_1;
    body_trend_2        = body_ma_structure.body_trend_2;
    body_trend_3        = body_ma_structure.body_trend_3;
    body_ma_state_0     = body_ma_structure.body_ma_state_0;
    body_ma_state_1     = body_ma_structure.body_ma_state_1;
    body_ma_state_2     = body_ma_structure.body_ma_state_2;
    body_ma_state_3     = body_ma_structure.body_ma_state_3;
  }

  // INITIALIZE STRUCTURE VALUES
  void InitBodyMAStructureValues(IndicatorsHandleInfo &body_ma_indicator_handle, int index)
  {
    indicator_timeframe = body_ma_indicator_handle.indicator_timeframe;
    indicator_period    = body_ma_indicator_handle.indicator_period;
    body_value_0        = GetBodyValue(body_ma_indicator_handle, index);
    body_value_1        = GetBodyValue(body_ma_indicator_handle, index+1);
    body_value_2        = GetBodyValue(body_ma_indicator_handle, index+2);
    body_value_3        = GetBodyValue(body_ma_indicator_handle, index+3);

    body_ma_0           = GetBodyMAValue(body_ma_indicator_handle, index);
    body_ma_1           = GetBodyMAValue(body_ma_indicator_handle, index+1);
    body_ma_2           = GetBodyMAValue(body_ma_indicator_handle, index+2);
    body_ma_3           = GetBodyMAValue(body_ma_indicator_handle, index+3);

    body_trend_0        = GetBodyTrend(body_ma_indicator_handle, index);
    body_trend_1        = GetBodyTrend(body_ma_indicator_handle, index+1);
    body_trend_2        = GetBodyTrend(body_ma_indicator_handle, index+2);
    body_trend_3        = GetBodyTrend(body_ma_indicator_handle, index+3);

    body_ma_state_0     = GetBodyMAState(body_ma_indicator_handle, index);
    body_ma_state_1     = GetBodyMAState(body_ma_indicator_handle, index+1);
    body_ma_state_2     = GetBodyMAState(body_ma_indicator_handle, index+2);
    body_ma_state_3     = GetBodyMAState(body_ma_indicator_handle, index+3);
  }

  // ++ BODY MA INDICATOR FUNCTIONS ++

  double GetBodyValue(IndicatorsHandleInfo &body_ma_indicator_handle, int index)
  {
    double body_value[];

    if(CopyBuffer(body_ma_indicator_handle.indicator_handle, 0, 0, index+1, body_value) <= 0)
    {
      Print("ERROR READING BODY VALUE INDICATOR DATA");
    }

    ArraySetAsSeries(body_value, true);

    // Use _Digits for price-based values
    double value = NormalizeDouble(body_value[index], _Digits);

    // TIMESTAMP VERIFICATION LOGGING (M1 ONLY)
    if(Enable_Verification_Logs && body_ma_indicator_handle.indicator_timeframe == PERIOD_M1)
    {
      datetime candle_time = iTime(_Symbol, body_ma_indicator_handle.indicator_timeframe, index);
      PrintFormat("[VERIFY-BodyValue] TF=%s, Shift=%d, Time=%s, Value=%s",
                  TimeframeToString(body_ma_indicator_handle.indicator_timeframe),
                  index,
                  TimeToString(candle_time, TIME_DATE|TIME_MINUTES),
                  DoubleToString(value, _Digits));
    }

    return value;
  }

  double GetBodyMAValue(IndicatorsHandleInfo &body_ma_indicator_handle, int index)
  {
    double body_ma_value[];

    if(CopyBuffer(body_ma_indicator_handle.indicator_handle, 1, 0, index+1, body_ma_value) <= 0)
    {
      Print("ERROR READING BODY MA INDICATOR DATA");
    }

    ArraySetAsSeries(body_ma_value, true);

    // Use _Digits for price-based values
    double value = NormalizeDouble(body_ma_value[index], _Digits);

    // TIMESTAMP VERIFICATION LOGGING (M1 ONLY)
    if(Enable_Verification_Logs && body_ma_indicator_handle.indicator_timeframe == PERIOD_M1)
    {
      datetime candle_time = iTime(_Symbol, body_ma_indicator_handle.indicator_timeframe, index);
      PrintFormat("[VERIFY-BodyMA] TF=%s, Shift=%d, Time=%s, Value=%s",
                  TimeframeToString(body_ma_indicator_handle.indicator_timeframe),
                  index,
                  TimeToString(candle_time, TIME_DATE|TIME_MINUTES),
                  DoubleToString(value, _Digits));
    }

    return value;
  }

  BodyTrendTypes GetBodyTrend(IndicatorsHandleInfo &body_ma_indicator_handle, int index)
  {
    double current_value  = GetBodyValue(body_ma_indicator_handle, index);
    double previous_value = GetBodyValue(body_ma_indicator_handle, index + 1);

    if(current_value > previous_value) return(STRONG_BODY_TREND);
    if(current_value < previous_value) return(WEAK_BODY_TREND);

    return(BODY_UNDEFINED);
  }

  BodyMATypes GetBodyMAState(IndicatorsHandleInfo &body_ma_indicator_handle, int index)
  {
    double body_value = GetBodyValue(body_ma_indicator_handle, index);
    double body_ma_value = GetBodyMAValue(body_ma_indicator_handle, index);

    if(body_value > body_ma_value) return(BODY_BULLISH_MA);
    if(body_value < body_ma_value) return(BODY_BEARISH_MA);

    return(BODY_UNDEFINED_MA);
  }
};

#endif // _MICROSERVICES_INDICATORS_BODY_MA_INDICATOR_MQH_
