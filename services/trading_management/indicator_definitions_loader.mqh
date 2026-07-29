//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtDeterministicBandsLogicHandles[];

bool AddStructStochIndicatorHandle(const ENUM_TIMEFRAMES timeframe,
                                   const bool required)
{
  for(int i = 0; i < ArraySize(ExtStructStochIndicatorsHandle); i++)
  {
    if(ExtStructStochIndicatorsHandle[i].indicator_timeframe == timeframe)
      return true;
  }

  IndicatorsHandleInfo handle_info;
  handle_info.indicator_period = DETERMINISTIC_STOCH_K;
  handle_info.indicator_handle = iCustom(_Symbol,
                                         timeframe,
                                         "Examples\\Stochastic_Structure.ex5",
                                         DETERMINISTIC_STOCH_K,
                                         DETERMINISTIC_STOCH_D,
                                         DETERMINISTIC_STOCH_SLOWING,
                                         STO_CLOSECLOSE);
  handle_info.indicator_timeframe = timeframe;

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING STRUCTURE INDICATOR: ",
          EnumToString(timeframe),
          " | PERIOD: ",
          DETERMINISTIC_STOCH_K);
    if(required)
      TesterStop();
    return false;
  }

  if(Enable_Logs)
  {
    Print("LOADED STRUCTURE INDICATOR SUCCESSFULLY: ",
          EnumToString(timeframe),
          " | PERIOD: ",
          DETERMINISTIC_STOCH_K);
  }

  AddElementToArray(ExtStructStochIndicatorsHandle, handle_info);
  return true;
}

void LoadAllStructStochIndicators()
{
  AddStructStochIndicatorHandle(EXTREMUM_ENGINE_TIMEFRAME, true);

  if(!Enable_Signal_Feature_Export)
    return;

  for(int i = 0; i < PIVOT_CONTEXT_TIMEFRAME_COUNT; i++)
  {
    ENUM_TIMEFRAMES timeframe = PivotContextTimeframeAt(i);
    if(timeframe == EXTREMUM_ENGINE_TIMEFRAME)
      continue;
    AddStructStochIndicatorHandle(timeframe, false);
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

bool DeterministicHandleExists(IndicatorsHandleInfo &handles[],
                               const ENUM_TIMEFRAMES timeframe,
                               const int indicator_shift)
{
  int total = ArraySize(handles);
  for(int i = 0; i < total; i++)
  {
    if(handles[i].indicator_timeframe != timeframe)
      continue;
    if(handles[i].indicator_shift != indicator_shift)
      continue;
    return true;
  }

  return false;
}

bool LoadDeterministicBandsBaseLogicHandle(const ENUM_TIMEFRAMES timeframe,
                                           IndicatorsHandleInfo &handle_info,
                                           const bool required = true)
{
  handle_info = IndicatorsHandleInfo();
  handle_info.indicator_period        = DETERMINISTIC_MA_PERIOD;
  handle_info.indicator_shift         = 0;
  handle_info.indicator_ma_method     = MODE_SMA;
  handle_info.indicator_applied_price = PRICE_CLOSE;
  handle_info.indicator_timeframe     = timeframe;
  handle_info.indicator_handle        = iBands(_Symbol,
                                               timeframe,
                                               DETERMINISTIC_MA_PERIOD,
                                               0,
                                               DETERMINISTIC_B_PERCENT_DEVIATION,
                                               PRICE_CLOSE);

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING DETERMINISTIC BANDS BASE: tf=%s | period=%d",
                EnumToString(timeframe),
                DETERMINISTIC_MA_PERIOD);
    if(required)
      TesterStop();
    return false;
  }

  return true;
}

void AddDeterministicBandsBaseLogicHandle(IndicatorsHandleInfo &handles[],
                                          const ENUM_TIMEFRAMES timeframe,
                                          const bool required = true)
{
  if(DeterministicHandleExists(handles, timeframe, 0))
    return;

  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicBandsBaseLogicHandle(timeframe, handle_info, required))
    return;

  AddElementToArray(handles, handle_info);
}

void SetTesterIndicatorHideMode(const bool hide)
{
  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return;

  TesterHideIndicators(hide);
}

void LoadDeterministicBandsLogicIndicators()
{
  ArrayResize(ExtDeterministicBandsLogicHandles, 0);
  SetTesterIndicatorHideMode(true);

  if(Enable_Signal_Feature_Export)
  {
    for(int i = 0; i < PIVOT_CONTEXT_TIMEFRAME_COUNT; i++)
    {
      AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles,
                                           PivotContextTimeframeAt(i),
                                           false);
    }
  }
  else if(ML_Inference_Mode != ML_INFERENCE_DISABLED)
  {
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles,
                                         EXTREMUM_ENGINE_TIMEFRAME);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_H1);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_H4);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_D1);
  }
  SetTesterIndicatorHideMode(false);
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

void ReleaseAllDeterministicBandsIndicators()
{
  ReleaseIndicatorHandleArray(ExtDeterministicBandsLogicHandles);
}

void LoadAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicBandsIndicators();
  LoadAllStructStochIndicators();
  LoadDeterministicBandsLogicIndicators();

  if(Enable_Logs)
  {
    PrintFormat("Extremum engine context | Engine=%s | TF=%s | Stoch=%d,%d,%d",
                ExtremumEngineLabel(EXTREMUM_ENGINE_V1),
                EnumToString(EXTREMUM_ENGINE_TIMEFRAME),
                DETERMINISTIC_STOCH_K,
                DETERMINISTIC_STOCH_D,
                DETERMINISTIC_STOCH_SLOWING);
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicBandsIndicators();
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
