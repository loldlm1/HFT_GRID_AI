//+------------------------------------------------------------------+
//|                        grid_atr_utils.mqh                       |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_

const int ATR_BUFFER_RESISTANCE       = 2;
const int ATR_BUFFER_SUPPORT          = 3;
const int ATR_BUFFER_TRAIL_RESISTANCE = 4;
const int ATR_BUFFER_TRAIL_SUPPORT    = 5;

bool GridCopyAtrBufferValue(const ENUM_TIMEFRAMES timeframe,
                            const int buffer_index,
                            double &price_out,
                            const int shift)
{
  price_out = 0.0;
  int total_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_handles <= 0)
    return false;

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

bool GridResolveAtrReferencePrice(const SignalTypes direction,
                                  const ENUM_TIMEFRAMES timeframe,
                                  double &price_out,
                                  const int shift = 0)
{
  int buffer_index = (direction == BULLISH) ? ATR_BUFFER_SUPPORT : ATR_BUFFER_RESISTANCE;
  return GridCopyAtrBufferValue(timeframe, buffer_index, price_out, shift);
}

bool GridResolveAtrTrailingPrice(const SignalTypes direction,
                                 const ENUM_TIMEFRAMES timeframe,
                                 double &price_out,
                                 const int shift = 0)
{
  int buffer_index = (direction == BULLISH) ? ATR_BUFFER_TRAIL_SUPPORT : ATR_BUFFER_TRAIL_RESISTANCE;
  return GridCopyAtrBufferValue(timeframe, buffer_index, price_out, shift);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
