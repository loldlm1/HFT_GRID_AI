//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtDeterministicMaLogicHandles[];
IndicatorsHandleInfo ExtDeterministicMaVisualHandles[];
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

  ArrayResize(Strategy_TF_List, 1);
  Strategy_TF_List[0] = DETERMINISTIC_BASE_TIMEFRAME;
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
    struct_stoch_indicator_handle_loaded.indicator_period = DETERMINISTIC_STOCH_K;
    struct_stoch_indicator_handle_loaded.indicator_handle = iCustom(_Symbol,
                                                                     trend_timeframe,
                                                                     "Examples\\Stochastic_Structure.ex5",
                                                                     struct_stoch_indicator_handle_loaded.indicator_period,
                                                                     DETERMINISTIC_STOCH_D,
                                                                     DETERMINISTIC_STOCH_SLOWING,
                                                                     STO_CLOSECLOSE);
    struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STRUCTURE INDICATOR: ", EnumToString(trend_timeframe),
            " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      continue;
    }

    if(Enable_Logs)
    {
      Print("LOADED STRUCTURE INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe),
            " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
    }

    AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
  }
}

void ReleaseAllStructStochIndicators()
{
  int total = ArraySize(ExtStructStochIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtStructStochIndicatorsHandle[i].indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(ExtStructStochIndicatorsHandle[i].indicator_handle);
      ExtStructStochIndicatorsHandle[i].indicator_handle = INVALID_HANDLE;
    }

    if(ExtStructStochIndicatorsHandle[i].overlay_indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(ExtStructStochIndicatorsHandle[i].overlay_indicator_handle);
      ExtStructStochIndicatorsHandle[i].overlay_indicator_handle = INVALID_HANDLE;
    }
  }

  ArrayResize(ExtStructStochIndicatorsHandle, 0);
}

bool LoadDeterministicMaHandle(const ENUM_TIMEFRAMES timeframe,
                               const int ma_shift,
                               IndicatorsHandleInfo &handle_info)
{
  handle_info = IndicatorsHandleInfo();
  handle_info.indicator_period        = DETERMINISTIC_MA_PERIOD;
  handle_info.indicator_shift         = ma_shift;
  handle_info.indicator_ma_method     = MODE_SMA;
  handle_info.indicator_applied_price = PRICE_CLOSE;
  handle_info.indicator_timeframe     = timeframe;
  handle_info.indicator_handle        = iMA(_Symbol,
                                            timeframe,
                                            DETERMINISTIC_MA_PERIOD,
                                            ma_shift,
                                            MODE_SMA,
                                            PRICE_CLOSE);

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING DETERMINISTIC MA: tf=%s | period=%d | shift=%d",
                EnumToString(timeframe),
                DETERMINISTIC_MA_PERIOD,
                ma_shift);
    TesterStop();
    return false;
  }

  return true;
}

void AddDeterministicMaHandle(IndicatorsHandleInfo &handles[],
                              const ENUM_TIMEFRAMES timeframe,
                              const int ma_shift)
{
  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicMaHandle(timeframe, ma_shift, handle_info))
    return;

  AddElementToArray(handles, handle_info);
}

void LoadDeterministicMaLogicIndicators()
{
  ArrayResize(ExtDeterministicMaLogicHandles, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M1, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M3, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M5, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M10, 0);
}

void LoadDeterministicMaVisualIndicators()
{
  ArrayResize(ExtDeterministicMaVisualHandles, 0);
  AddDeterministicMaHandle(ExtDeterministicMaVisualHandles,
                           PERIOD_M1,
                           DETERMINISTIC_S1_BASE_DELAY);
  AddDeterministicMaHandle(ExtDeterministicMaVisualHandles,
                           PERIOD_M1,
                           DETERMINISTIC_S2_BASE_DELAY);
  AddDeterministicMaHandle(ExtDeterministicMaVisualHandles,
                           PERIOD_M1,
                           DETERMINISTIC_S3_BASE_DELAY);

  if(!Enable_Show_Indicators)
    return;

  long chart_id = ChartID();
  int total = ArraySize(ExtDeterministicMaVisualHandles);
  for(int i = 0; i < total; i++)
  {
    if(ExtDeterministicMaVisualHandles[i].indicator_handle == INVALID_HANDLE)
      continue;
    ChartIndicatorAdd(chart_id,
                      0,
                      ExtDeterministicMaVisualHandles[i].indicator_handle);
  }
}

void ReleaseIndicatorHandleArray(IndicatorsHandleInfo &handles[])
{
  int total = ArraySize(handles);
  for(int i = 0; i < total; i++)
  {
    if(handles[i].indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(handles[i].indicator_handle);
      handles[i].indicator_handle = INVALID_HANDLE;
    }

    if(handles[i].overlay_indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(handles[i].overlay_indicator_handle);
      handles[i].overlay_indicator_handle = INVALID_HANDLE;
    }
  }

  ArrayResize(handles, 0);
}

void ReleaseAllDeterministicMaIndicators()
{
  ReleaseIndicatorHandleArray(ExtDeterministicMaLogicHandles);
  ReleaseIndicatorHandleArray(ExtDeterministicMaVisualHandles);
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  LoadStructureFibonacciLevels(FOUNDATION_STRUCTURE_FIBONACCI_LEVELS,
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicMaIndicators();
  LoadAllStructStochIndicators();
  LoadDeterministicMaLogicIndicators();
  LoadDeterministicMaVisualIndicators();

  if(Enable_Logs)
  {
    PrintFormat("Deterministic strategy context | BaseTF=%s | Stoch=%d,%d,%d | Direction=%s",
                EnumToString(DETERMINISTIC_BASE_TIMEFRAME),
                DETERMINISTIC_STOCH_K,
                DETERMINISTIC_STOCH_D,
                DETERMINISTIC_STOCH_SLOWING,
                EnumToString(Strategy_Direction_Mode));
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicMaIndicators();
  ArrayResize(Strategy_TF_List, 0);
  total_tf_list_load = 0;
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
