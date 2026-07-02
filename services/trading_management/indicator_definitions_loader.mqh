//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
int total_tf_list_load = 0;
const string FOUNDATION_STRUCTURE_FIBONACCI_LEVELS = "0.0,61.8,100.0";

// ── Helpers ─────────────────────────────────────────────────────────────

bool IsStrategyTimeframeSupported(const ENUM_TIMEFRAMES tf)
{
  switch(tf)
  {
    case PERIOD_M1:
    case PERIOD_M2:
    case PERIOD_M3:
    case PERIOD_M4:
    case PERIOD_M5:
    case PERIOD_M6:
    case PERIOD_M10:
    case PERIOD_M12:
    case PERIOD_M15:
    case PERIOD_M20:
    case PERIOD_M30:
    case PERIOD_H1:
    case PERIOD_H2:
    case PERIOD_H3:
    case PERIOD_H4:
      return true;
  }
  return false;
}

void PrepareStrategyTimeframes()
{
  ArrayResize(Strategy_TF_List, 0);

  ENUM_TIMEFRAMES configured_tf = Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Strategy timeframe %d not supported. Falling back to PERIOD_M1.", (int)configured_tf);
    configured_tf = PERIOD_M1;
  }

  ArrayResize(Strategy_TF_List, 1);
  Strategy_TF_List[0] = configured_tf;
  total_tf_list_load = ArraySize(Strategy_TF_List);
}

void LoadAllStructStochIndicators()
{
  if(ArraySize(Strategy_TF_List) <= 0)
    return;

  int total = ArraySize(Strategy_TF_List);
  for(int i = 0; i < total; i++)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo struct_stoch_indicator_handle_loaded;
    struct_stoch_indicator_handle_loaded.indicator_period = ResolveStochStructurePeriod();
    struct_stoch_indicator_handle_loaded.indicator_handle = iCustom(_Symbol,
                                                                     trend_timeframe,
                                                                     "Examples\\Stochastic_Structure.ex5",
                                                                     struct_stoch_indicator_handle_loaded.indicator_period,
                                                                     3,
                                                                     3,
                                                                     STO_CLOSECLOSE);
    struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STRUCTURE INDICATOR: ", EnumToString(trend_timeframe),
            " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      continue;
    }

    Print("LOADED STRUCTURE INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe),
          " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
  }
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  LoadStructureFibonacciLevels(FOUNDATION_STRUCTURE_FIBONACCI_LEVELS,
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  ArrayResize(ExtStructStochIndicatorsHandle, 0);
  LoadAllStructStochIndicators();

  PrintFormat("Strategy context | TF=%s | StructurePeriod=%d | Direction=%s",
              EnumToString(Strategy_Timeframe),
              ResolveStochStructurePeriod(),
              EnumToString(Strategy_Direction_Mode));
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
