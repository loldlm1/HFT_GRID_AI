//+------------------------------------------------------------------+
//|              microservices/indicators/alligator_indicator.mqh    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_ALLIGATOR_INDICATOR_MQH_
#define _MICROSERVICES_INDICATORS_ALLIGATOR_INDICATOR_MQH_

struct AlligatorStructure
{
  ENUM_TIMEFRAMES indicator_timeframe;
  int             jaws_period;
  int             teeth_period;
  int             lips_period;
  double          jaws_value;
  double          teeth_value;
  double          lips_value;

  AlligatorStructure()
  {
    indicator_timeframe = PERIOD_CURRENT;
    jaws_period         = 0;
    teeth_period        = 0;
    lips_period         = 0;
    jaws_value          = 0.0;
    teeth_value         = 0.0;
    lips_value          = 0.0;
  }

  AlligatorStructure(const AlligatorStructure &other)
  {
    indicator_timeframe = other.indicator_timeframe;
    jaws_period         = other.jaws_period;
    teeth_period        = other.teeth_period;
    lips_period         = other.lips_period;
    jaws_value          = other.jaws_value;
    teeth_value         = other.teeth_value;
    lips_value          = other.lips_value;
  }

  bool InitAlligatorStructureValues(IndicatorsHandleInfo &alligator_handle,
                                    const int index,
                                    const int configured_jaws_period,
                                    const int configured_teeth_period,
                                    const int configured_lips_period)
  {
    indicator_timeframe = alligator_handle.indicator_timeframe;
    jaws_period         = configured_jaws_period;
    teeth_period        = configured_teeth_period;
    lips_period         = configured_lips_period;

    if(!ReadAlligatorBuffer(alligator_handle, 0, index, jaws_value))
      return false;
    if(!ReadAlligatorBuffer(alligator_handle, 1, index, teeth_value))
      return false;
    if(!ReadAlligatorBuffer(alligator_handle, 2, index, lips_value))
      return false;
    return true;
  }

  bool ReadAlligatorBuffer(IndicatorsHandleInfo &alligator_handle,
                           const int buffer_index,
                           const int index,
                           double &value)
  {
    double buffer_data[];
    int needed = index + 1;
    if(CopyBuffer(alligator_handle.indicator_handle,
                  buffer_index,
                  0,
                  needed,
                  buffer_data) <= 0)
    {
      Print("ERROR READING ALLIGATOR INDICATOR DATA | buffer=", buffer_index);
      return false;
    }

    ArraySetAsSeries(buffer_data, true);
    value = NormalizeDouble(buffer_data[index], _Digits);
    return true;
  }
};

#endif // _MICROSERVICES_INDICATORS_ALLIGATOR_INDICATOR_MQH_
