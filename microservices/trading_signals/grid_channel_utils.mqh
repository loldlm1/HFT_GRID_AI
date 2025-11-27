//+------------------------------------------------------------------+
//|                     microservices/trading_signals/... channel    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_CHANNEL_UTILS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_CHANNEL_UTILS_MQH_

const int ATR_BUFFER_SMA_RESISTANCE = 0;
const int ATR_BUFFER_SMA_MIDDLE     = 2;
const int ATR_BUFFER_SMA_SUPPORT    = 1;

const int KELTNER_BUFFER_RESISTANCE = 0;
const int KELTNER_BUFFER_MIDDLE     = 1;
const int KELTNER_BUFFER_SUPPORT    = 2;

const int BOLLINGER_BUFFER_RESISTANCE = 0;
const int BOLLINGER_BUFFER_MIDDLE     = 1;
const int BOLLINGER_BUFFER_SUPPORT    = 2;

inline GridBaseStrategyTypes ResolveStrategyChannelType()
{
  switch(Strategy_Channel_Indicator_Type)
  {
    case CHANNEL_INDICATOR_KELTNER:
      return KELTNER_RANGE;
    case CHANNEL_INDICATOR_ATR:
      return ATR_RANGE;
    case CHANNEL_INDICATOR_BOLLINGER:
    default:
      return BOLLINGER_RANGE;
  }
}

inline GridBaseStrategyTypes ResolveEffectiveChannelStrategy()
{
  if(Grid_Base_Strategy_Type == CHANNEL_INDICATOR_RANGE)
    return ResolveStrategyChannelType();
  return Grid_Base_Strategy_Type;
}

inline bool GridStrategyUsesChannelIndicator()
{
  return (Grid_Base_Strategy_Type != POINTS_RANGE);
}

inline GridBaseStrategyTypes ResolveActiveChannelStrategy()
{
  if(Grid_Base_Strategy_Type == POINTS_RANGE)
    return ResolveStrategyChannelType();
  return ResolveEffectiveChannelStrategy();
}

double GridChannelResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

bool GridCopyChannelBufferValue(const GridBaseStrategyTypes channel_type,
                                const ENUM_TIMEFRAMES timeframe,
                                const int buffer_index,
                                double &price_out,
                                const int shift)
{
  price_out = 0.0;

  int total_handles = 0;
  IndicatorsHandleInfo info;

  if(channel_type == KELTNER_RANGE)
    total_handles = ArraySize(ExtKeltnerIndicatorsHandle);
  else if(channel_type == BOLLINGER_RANGE)
    total_handles = ArraySize(ExtBandsIndicatorsHandle);
  else
    total_handles = ArraySize(ExtATRIndicatorsHandle);

  if(total_handles <= 0)
    return false;

  for(int i = 0; i < total_handles; i++)
  {
    if(channel_type == KELTNER_RANGE)
      info = ExtKeltnerIndicatorsHandle[i];
    else if(channel_type == BOLLINGER_RANGE)
      info = ExtBandsIndicatorsHandle[i];
    else
      info = ExtATRIndicatorsHandle[i];
    if(info.indicator_timeframe != timeframe)
      continue;

    double buffer_values[];
    if(CopyBuffer(info.indicator_handle,
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

bool GridResolveChannelLinePrice(const GridBaseStrategyTypes channel_type,
                                 const GridChannelLineTypes line_type,
                                 const ENUM_TIMEFRAMES timeframe,
                                 double &price_out,
                                 const int shift = 0)
{
  GridBaseStrategyTypes resolved_type = channel_type;
  if(resolved_type == CHANNEL_INDICATOR_RANGE)
    resolved_type = ResolveStrategyChannelType();

  int buffer_index = ATR_BUFFER_SMA_SUPPORT;
  if(resolved_type == ATR_RANGE)
  {
    if(line_type == GRID_CHANNEL_LINE_RESISTANCE)
      buffer_index = ATR_BUFFER_SMA_RESISTANCE;
    else if(line_type == GRID_CHANNEL_LINE_SUPPORT)
      buffer_index = ATR_BUFFER_SMA_SUPPORT;
    else
      buffer_index = ATR_BUFFER_SMA_MIDDLE;
  }
  else if(resolved_type == KELTNER_RANGE)
  {
    if(line_type == GRID_CHANNEL_LINE_RESISTANCE)
      buffer_index = KELTNER_BUFFER_RESISTANCE;
    else if(line_type == GRID_CHANNEL_LINE_SUPPORT)
      buffer_index = KELTNER_BUFFER_SUPPORT;
    else
      buffer_index = KELTNER_BUFFER_MIDDLE;
  }
  else if(resolved_type == BOLLINGER_RANGE)
  {
    if(line_type == GRID_CHANNEL_LINE_RESISTANCE)
      buffer_index = BOLLINGER_BUFFER_RESISTANCE;
    else if(line_type == GRID_CHANNEL_LINE_SUPPORT)
      buffer_index = BOLLINGER_BUFFER_SUPPORT;
    else
      buffer_index = BOLLINGER_BUFFER_MIDDLE;
  }

  Print(EnumToString(resolved_type) + " | " + EnumToString(line_type) + " | buffer: " + IntegerToString(buffer_index));

  return GridCopyChannelBufferValue(resolved_type,
                                    timeframe,
                                    buffer_index,
                                    price_out,
                                    shift);
}

bool GridResolveChannelGuardPoints(const GridBaseStrategyTypes channel_type,
                                   const SignalTypes direction,
                                   const ENUM_TIMEFRAMES timeframe,
                                   const double entry_reference_price,
                                   double &distance_points,
                                   double &reference_price,
                                   const int shift = 0)
{
  distance_points = 0.0;
  reference_price = 0.0;

  if(entry_reference_price <= 0.0)
    return false;

  GridChannelLineTypes line = (direction == BULLISH)
                                ? GRID_CHANNEL_LINE_SUPPORT
                                : GRID_CHANNEL_LINE_RESISTANCE;

  if(!GridResolveChannelLinePrice(channel_type,
                                  line,
                                  timeframe,
                                  reference_price,
                                  shift))
    return false;

  double point_size = GridChannelResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double diff = (direction == BULLISH)
                  ? (entry_reference_price - reference_price)
                  : (reference_price - entry_reference_price);
  if(diff <= 0.0)
    return false;

  distance_points = MathAbs(diff) / point_size;
  return (distance_points > 0.0);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_CHANNEL_UTILS_MQH_
