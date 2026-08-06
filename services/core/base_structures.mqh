//+------------------------------------------------------------------+
//|                          microservices/core/base_structures.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_CORE_BASE_STRUCTURES_MQH_
#define _MICROSERVICES_CORE_BASE_STRUCTURES_MQH_

struct PivotBandsHandleInfo
{
  int indicator_handle;
  ENUM_TIMEFRAMES timeframe;

  PivotBandsHandleInfo()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotBandsHandleInfo(const PivotBandsHandleInfo &other)
  {
    indicator_handle = other.indicator_handle;
    timeframe = other.timeframe;
  }

  void Reset(const ENUM_TIMEFRAMES source_timeframe)
  {
    indicator_handle = INVALID_HANDLE;
    timeframe = source_timeframe;
  }
};

#endif // _MICROSERVICES_CORE_BASE_STRUCTURES_MQH_
