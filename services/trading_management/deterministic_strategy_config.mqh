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
