//+------------------------------------------------------------------+
//|                trading_management/pivot_fractal_engine_config   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_
#define _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_

const int PIVOT_FRACTAL_TIMEFRAME_COUNT = 5;
const int PIVOT_CONTEXT_TIMEFRAME_COUNT = 6;
const int PIVOT_LEVEL_COUNT              = 7;
const int PIVOT_WINDOW_RETRY_SECONDS     = 1;
const int PIVOT_STRUCTURE_SLOT_COUNT     = 3;
const int PIVOT_B_PERCENT_SHIFT_COUNT    = 6;

ENUM_TIMEFRAMES PIVOT_FRACTAL_TIMEFRAMES[PIVOT_FRACTAL_TIMEFRAME_COUNT] =
{
  PERIOD_M15,
  PERIOD_M30,
  PERIOD_H1,
  PERIOD_H4,
  PERIOD_D1
};

ENUM_TIMEFRAMES PIVOT_CONTEXT_TIMEFRAMES[PIVOT_CONTEXT_TIMEFRAME_COUNT] =
{
  PERIOD_M1,
  PERIOD_M15,
  PERIOD_M30,
  PERIOD_H1,
  PERIOD_H4,
  PERIOD_D1
};

string PivotFractalEngineLabel(const int engine_id)
{
  if(engine_id == PIVOT_FRACTAL_V1)
    return "PIVOT_FRACTAL_V1";
  return "NONE";
}

bool PivotFractalEngineEnabled(const int engine_id)
{
  return (engine_id == PIVOT_FRACTAL_V1);
}

ENUM_TIMEFRAMES PivotFractalTimeframeAt(const int index)
{
  if(index < 0 || index >= PIVOT_FRACTAL_TIMEFRAME_COUNT)
    return PERIOD_CURRENT;
  return PIVOT_FRACTAL_TIMEFRAMES[index];
}

int PivotFractalTimeframeIndex(const ENUM_TIMEFRAMES timeframe)
{
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    if(PIVOT_FRACTAL_TIMEFRAMES[i] == timeframe)
      return i;
  }
  return -1;
}

ENUM_TIMEFRAMES PivotContextTimeframeAt(const int index)
{
  if(index < 0 || index >= PIVOT_CONTEXT_TIMEFRAME_COUNT)
    return PERIOD_CURRENT;
  return PIVOT_CONTEXT_TIMEFRAMES[index];
}

string PivotLevelLabel(const PivotLevelIds level)
{
  switch(level)
  {
    case PIVOT_LEVEL_S3: return "S3";
    case PIVOT_LEVEL_S2: return "S2";
    case PIVOT_LEVEL_S1: return "S1";
    case PIVOT_LEVEL_PP: return "PP";
    case PIVOT_LEVEL_R1: return "R1";
    case PIVOT_LEVEL_R2: return "R2";
    case PIVOT_LEVEL_R3: return "R3";
  }
  return "UNKNOWN";
}

bool PivotLevelIdAt(const int index, PivotLevelIds &level_out)
{
  if(index < 0 || index >= PIVOT_LEVEL_COUNT)
    return false;
  level_out = (PivotLevelIds)index;
  return true;
}

#endif // _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_
