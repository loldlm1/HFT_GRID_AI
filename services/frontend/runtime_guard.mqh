//+------------------------------------------------------------------+
//|                            frontend/runtime_guard.mqh           |
//+------------------------------------------------------------------+
#ifndef _SVC_FE_RT_GUARD_MQH_
#define _SVC_FE_RT_GUARD_MQH_

inline bool FrontendChartWorkEnabledForRuntime(const bool runtime_is_testing,
                                               const bool runtime_is_visual_mode)
{
  return !(runtime_is_testing && !runtime_is_visual_mode);
}

inline bool FrontendChartWorkEnabled()
{
  bool runtime_is_testing = (MQLInfoInteger(MQL_TESTER) > 0);
  bool runtime_is_visual_mode = (MQLInfoInteger(MQL_VISUAL_MODE) > 0);
  return FrontendChartWorkEnabledForRuntime(runtime_is_testing, runtime_is_visual_mode);
}

inline bool FrontendSkippingChartWorkForRuntime(const bool runtime_is_testing,
                                                const bool runtime_is_visual_mode)
{
  return !FrontendChartWorkEnabledForRuntime(runtime_is_testing, runtime_is_visual_mode);
}

inline bool FrontendSkippingChartWork()
{
  return !FrontendChartWorkEnabled();
}

#endif // _SVC_FE_RT_GUARD_MQH_
