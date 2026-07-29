//+------------------------------------------------------------------+
//|                            frontend/runtime_guard.mqh           |
//+------------------------------------------------------------------+
#ifndef _SVC_FE_RT_GUARD_MQH_
#define _SVC_FE_RT_GUARD_MQH_

const int FRONTEND_REFRESH_INTERVAL_SECONDS = 1;
datetime g_frontend_next_refresh_time = 0;

inline bool FrontendChartWorkEnabled()
{
  bool runtime_is_testing = (MQLInfoInteger(MQL_TESTER) > 0);
  bool runtime_is_visual_mode = (MQLInfoInteger(MQL_VISUAL_MODE) > 0);
  return !(runtime_is_testing && !runtime_is_visual_mode);
}

void FrontendResetRefreshThrottle()
{
  g_frontend_next_refresh_time = 0;
}

bool FrontendRefreshDue(const datetime now_time)
{
  if(!FrontendChartWorkEnabled())
    return false;

  if(now_time <= 0)
    return true;

  if(g_frontend_next_refresh_time <= 0 || now_time >= g_frontend_next_refresh_time)
  {
    g_frontend_next_refresh_time = now_time + FRONTEND_REFRESH_INTERVAL_SECONDS;
    return true;
  }

  return false;
}

#endif // _SVC_FE_RT_GUARD_MQH_
