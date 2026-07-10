//+------------------------------------------------------------------+
//|                     trading_management/extremum_engine_config    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EXTREMUM_ENGINE_CONFIG_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EXTREMUM_ENGINE_CONFIG_MQH_

string ExtremumEngineLabel(const int engine_id)
{
  if(engine_id == EXTREMUM_ENGINE_V1)
    return "EXTREMUM_V1";
  return "NONE";
}

bool ExtremumEngineEnabled(const int engine_id)
{
  return (engine_id == EXTREMUM_ENGINE_V1);
}

ENUM_TIMEFRAMES ExtremumEngineTimeframe(const int engine_id)
{
  if(engine_id == EXTREMUM_ENGINE_V1)
    return EXTREMUM_ENGINE_TIMEFRAME;
  return PERIOD_CURRENT;
}

int ExtremumEngineTimeframeMinutes(const ENUM_TIMEFRAMES timeframe)
{
  switch(timeframe)
  {
    case PERIOD_M1:  return 1;
    case PERIOD_M2:  return 2;
    case PERIOD_M3:  return 3;
    case PERIOD_M4:  return 4;
    case PERIOD_M5:  return 5;
    case PERIOD_M6:  return 6;
    case PERIOD_M10: return 10;
    case PERIOD_M12: return 12;
    case PERIOD_M15: return 15;
    case PERIOD_M20: return 20;
    case PERIOD_M30: return 30;
    case PERIOD_H1:  return 60;
    case PERIOD_H2:  return 120;
    case PERIOD_H3:  return 180;
    case PERIOD_H4:  return 240;
    case PERIOD_H6:  return 360;
    case PERIOD_H8:  return 480;
    case PERIOD_H12: return 720;
    case PERIOD_D1:  return 1440;
    case PERIOD_W1:  return 10080;
    case PERIOD_MN1: return 43200;
  }
  return 0;
}

#endif // _SERVICES_TRADING_MANAGEMENT_EXTREMUM_ENGINE_CONFIG_MQH_
