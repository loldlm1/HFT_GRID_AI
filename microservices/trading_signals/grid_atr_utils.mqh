//+------------------------------------------------------------------+
//|                        grid_atr_utils.mqh                       |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_

bool GridResolveAtrReferencePrice(const SignalTypes direction,
                                  const ENUM_TIMEFRAMES timeframe,
                                  double &price_out,
                                  const int shift = 0)
{
  price_out = 0.0;
  int total_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_handles <= 0)
    return false;

  int buffer_index = (direction == BULLISH) ? 3 : 2; // BufferResHH or BufferSupLL
  for(int i = 0; i < total_handles; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe != timeframe)
      continue;

    double buffer_values[];
    if(CopyBuffer(ExtATRIndicatorsHandle[i].indicator_handle,
                  buffer_index,
                  shift,
                  1,
                  buffer_values) <= 0)
      continue;

    double candidate = buffer_values[0];
    if(candidate > 0.0)
    {
      price_out = candidate;
      return true;
    }
  }

  return false;
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
