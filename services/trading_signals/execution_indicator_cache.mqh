//+------------------------------------------------------------------+
//|                 trading_signals/execution_indicator_cache.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_INDICATOR_CACHE_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_INDICATOR_CACHE_MQH_

struct ExecutionAtrHandleCache
{
  string         symbol;
  ENUM_TIMEFRAMES timeframe;
  int            period;
  int            handle;

  ExecutionAtrHandleCache()
  {
    symbol    = "";
    timeframe = PERIOD_CURRENT;
    period    = 0;
    handle    = INVALID_HANDLE;
  }
};

ExecutionAtrHandleCache g_execution_atr_cache;

void ResetExecutionAtrHandleCache()
{
  g_execution_atr_cache.symbol    = "";
  g_execution_atr_cache.timeframe = PERIOD_CURRENT;
  g_execution_atr_cache.period    = 0;
  g_execution_atr_cache.handle    = INVALID_HANDLE;
}

void ReleaseExecutionAtrHandle()
{
  if(g_execution_atr_cache.handle != INVALID_HANDLE)
    IndicatorRelease(g_execution_atr_cache.handle);

  ResetExecutionAtrHandleCache();
}

int ResolveExecutionAtrHandle(const ENUM_TIMEFRAMES timeframe,
                              const int period)
{
  ENUM_TIMEFRAMES resolved_timeframe = timeframe;
  if(resolved_timeframe == PERIOD_CURRENT)
    resolved_timeframe = Strategy_Timeframe;
  if(resolved_timeframe == PERIOD_CURRENT)
    resolved_timeframe = PERIOD_M1;

  int resolved_period = period;
  if(resolved_period <= 0)
    resolved_period = 5;

  if(g_execution_atr_cache.handle != INVALID_HANDLE &&
     g_execution_atr_cache.symbol == _Symbol &&
     g_execution_atr_cache.timeframe == resolved_timeframe &&
     g_execution_atr_cache.period == resolved_period)
  {
    return g_execution_atr_cache.handle;
  }

  ReleaseExecutionAtrHandle();

  int atr_handle = iATR(_Symbol, resolved_timeframe, resolved_period);
  if(atr_handle == INVALID_HANDLE)
  {
    if(Enable_Logs)
    {
      PrintFormat("ERROR LOADING ATR INDICATOR: %s | PERIOD: %d",
                  EnumToString(resolved_timeframe),
                  resolved_period);
    }
    return INVALID_HANDLE;
  }

  g_execution_atr_cache.symbol    = _Symbol;
  g_execution_atr_cache.timeframe = resolved_timeframe;
  g_execution_atr_cache.period    = resolved_period;
  g_execution_atr_cache.handle    = atr_handle;

  return g_execution_atr_cache.handle;
}

void ReleaseExecutionIndicatorCache()
{
  ReleaseExecutionAtrHandle();
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_INDICATOR_CACHE_MQH_
