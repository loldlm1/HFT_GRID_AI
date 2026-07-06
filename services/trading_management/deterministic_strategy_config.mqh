//+------------------------------------------------------------------+
//|                 trading_management/deterministic_strategy_config |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_DETERMINISTIC_STRATEGY_CONFIG_MQH_
#define _SERVICES_TRADING_MANAGEMENT_DETERMINISTIC_STRATEGY_CONFIG_MQH_

const int DETERMINISTIC_STRATEGY_TOTAL = 3;

string DeterministicStrategyLabel(const int strategy_id)
{
  switch(strategy_id)
  {
    case DETERMINISTIC_STRATEGY_1: return "S1";
    case DETERMINISTIC_STRATEGY_2: return "S2";
    case DETERMINISTIC_STRATEGY_3: return "S3";
  }
  return "BASE";
}

bool DeterministicStrategyEnabled(const int strategy_id)
{
  switch(strategy_id)
  {
    case DETERMINISTIC_STRATEGY_1: return Enable_Strategy_1;
    case DETERMINISTIC_STRATEGY_2: return Enable_Strategy_2;
    case DETERMINISTIC_STRATEGY_3: return Enable_Strategy_3;
  }
  return false;
}

int DeterministicStrategyBaseDelay(const int strategy_id)
{
  switch(strategy_id)
  {
    case DETERMINISTIC_STRATEGY_1: return DETERMINISTIC_S1_BASE_DELAY;
    case DETERMINISTIC_STRATEGY_2: return DETERMINISTIC_S2_BASE_DELAY;
    case DETERMINISTIC_STRATEGY_3: return DETERMINISTIC_S3_BASE_DELAY;
  }
  return 0;
}

ENUM_TIMEFRAMES DeterministicStrategyMacroTimeframe(const int strategy_id)
{
  switch(strategy_id)
  {
    case DETERMINISTIC_STRATEGY_1: return PERIOD_M3;
    case DETERMINISTIC_STRATEGY_2: return PERIOD_M5;
    case DETERMINISTIC_STRATEGY_3: return PERIOD_M10;
  }
  return PERIOD_CURRENT;
}

int DeterministicStrategyTimeframeMinutes(const ENUM_TIMEFRAMES timeframe)
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

bool DeterministicStrategyIdByIndex(const int index,
                                    int &strategy_id_out)
{
  strategy_id_out = DETERMINISTIC_STRATEGY_NONE;

  if(index == 0)
  {
    strategy_id_out = DETERMINISTIC_STRATEGY_1;
    return true;
  }
  if(index == 1)
  {
    strategy_id_out = DETERMINISTIC_STRATEGY_2;
    return true;
  }
  if(index == 2)
  {
    strategy_id_out = DETERMINISTIC_STRATEGY_3;
    return true;
  }

  return false;
}

#endif // _SERVICES_TRADING_MANAGEMENT_DETERMINISTIC_STRATEGY_CONFIG_MQH_
