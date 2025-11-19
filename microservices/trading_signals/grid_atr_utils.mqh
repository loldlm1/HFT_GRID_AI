//+------------------------------------------------------------------+
//|                        grid_atr_utils.mqh                       |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_

const int ATR_BUFFER_ROOT_RESISTANCE   = 0;
const int ATR_BUFFER_ROOT_SUPPORT      = 1;
const int ATR_BUFFER_RESISTANCE        = 2;
const int ATR_BUFFER_SUPPORT           = 3;
const int ATR_BUFFER_SMA_RESISTANCE    = 4;
const int ATR_BUFFER_SMA_SUPPORT       = 5;
const int ATR_BUFFER_TRAIL_RESISTANCE  = 6;
const int ATR_BUFFER_TRAIL_SUPPORT     = 7;

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
      price_out = NormalizeDouble(candidate, _Digits);
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
                                 const int shift = 1)
{
  int buffer_index = (direction == BULLISH) ? ATR_BUFFER_TRAIL_SUPPORT : ATR_BUFFER_TRAIL_RESISTANCE;
  return GridCopyAtrBufferValue(timeframe, buffer_index, price_out, shift);
}

bool GridResolveAtrRootPrice(const SignalTypes direction,
                             const ENUM_TIMEFRAMES timeframe,
                             double &price_out,
                             const int shift = 0)
{
  int buffer_index = (direction == BULLISH) ? ATR_BUFFER_ROOT_SUPPORT : ATR_BUFFER_ROOT_RESISTANCE;
  return GridCopyAtrBufferValue(timeframe, buffer_index, price_out, shift);
}

bool GridResolveAtrSmaPrice(const SignalTypes direction,
                            const ENUM_TIMEFRAMES timeframe,
                            double &price_out,
                            const int shift = 0)
{
  int buffer_index = (direction == BULLISH) ? ATR_BUFFER_SMA_SUPPORT : ATR_BUFFER_SMA_RESISTANCE;
  return GridCopyAtrBufferValue(timeframe, buffer_index, price_out, shift);
}

double GridAtrResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

bool GridResolveAtrSmaGuardPoints(const SignalTypes direction,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const double entry_reference_price,
                                  double &distance_points,
                                  double &sma_price,
                                  const int shift = 0)
{
  distance_points = 0.0;
  sma_price = 0.0;

  if(entry_reference_price <= 0.0)
    return false;

  if(!GridResolveAtrSmaPrice(direction, timeframe, sma_price, shift))
    return false;

  double point_size = GridAtrResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double diff = 0.0;
  if(direction == BULLISH)
    diff = entry_reference_price - sma_price;
  else if(direction == BEARISH)
    diff = sma_price - entry_reference_price;

  if(diff <= 0.0)
    return false;

  distance_points = MathAbs(diff) / point_size;
  return (distance_points > 0.0);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ATR_UTILS_MQH_
