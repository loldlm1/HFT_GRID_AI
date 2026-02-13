//+------------------------------------------------------------------+
//|                    candle_structure_filter_context.mqh          |
//| Normalizes candle-structure filter inputs and defaults.          |
//+------------------------------------------------------------------+
#ifndef _SVC_TM_CANDLE_STRUCTURE_FILTER_CONTEXT_MQH_
#define _SVC_TM_CANDLE_STRUCTURE_FILTER_CONTEXT_MQH_

inline bool CandleStructureFilterEnabled(const CandleStrategyTypes mode)
{
  return (mode != OFF_CANDLE_STRUCTURE);
}

inline bool CandleStructureFilterEnabled()
{
  return CandleStructureFilterEnabled(Candle_Strategy_Type);
}

inline int ResolveCandleStructureShift(const int shift)
{
  return MathMax(shift, 0);
}

inline int ResolveCandleStructureShift()
{
  return ResolveCandleStructureShift(Candle_Strategy_Shift);
}

inline int ResolveCandleStructureDepth(const int depth)
{
  if(depth <= 0)
    return 1;
  return depth;
}

inline int ResolveCandleStructureDepth()
{
  return ResolveCandleStructureDepth(Candle_Strategy_Depth);
}

inline int ResolveCandleStructureRequiredBars(const int shift,
                                              const int depth)
{
  int resolved_shift = ResolveCandleStructureShift(shift);
  int resolved_depth = ResolveCandleStructureDepth(depth);
  return resolved_shift + resolved_depth + 1;
}

inline int ResolveCandleStructureRequiredBars()
{
  return ResolveCandleStructureRequiredBars(ResolveCandleStructureShift(),
                                            ResolveCandleStructureDepth());
}

inline ENUM_TIMEFRAMES ResolveCandleStructureTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  ENUM_TIMEFRAMES resolved_timeframe = timeframe;
  if(resolved_timeframe == PERIOD_CURRENT)
    resolved_timeframe = Strategy_Timeframe;

  if(PeriodSeconds(resolved_timeframe) > 0)
    return resolved_timeframe;

  return PERIOD_M15;
}

inline ENUM_TIMEFRAMES ResolveCandleStructureTimeframe()
{
  return ResolveCandleStructureTimeframe(Candle_Timeframe);
}

#endif // _SVC_TM_CANDLE_STRUCTURE_FILTER_CONTEXT_MQH_
