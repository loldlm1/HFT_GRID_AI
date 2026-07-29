//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtPivotBandsHandles[];

bool AddStructStochIndicatorHandle(const ENUM_TIMEFRAMES timeframe,
                                   const bool required)
{
  for(int i = 0; i < ArraySize(ExtStructStochIndicatorsHandle); i++)
  {
    if(ExtStructStochIndicatorsHandle[i].indicator_timeframe == timeframe)
      return true;
  }

  IndicatorsHandleInfo handle_info;
  handle_info.indicator_period = PIVOT_CONTEXT_STOCH_K;
  handle_info.indicator_handle = iCustom(_Symbol,
                                         timeframe,
                                         "Examples\\Stochastic_Structure.ex5",
                                         PIVOT_CONTEXT_STOCH_K,
                                         PIVOT_CONTEXT_STOCH_D,
                                         PIVOT_CONTEXT_STOCH_SLOWING,
                                         STO_CLOSECLOSE);
  handle_info.indicator_timeframe = timeframe;

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING STRUCTURE INDICATOR: ",
          EnumToString(timeframe),
          " | PERIOD: ",
          PIVOT_CONTEXT_STOCH_K);
    if(required)
      TesterStop();
    return false;
  }

  if(Enable_Logs)
  {
    Print("LOADED STRUCTURE INDICATOR SUCCESSFULLY: ",
          EnumToString(timeframe),
          " | PERIOD: ",
          PIVOT_CONTEXT_STOCH_K);
  }

  AddElementToArray(ExtStructStochIndicatorsHandle, handle_info);
  return true;
}

void LoadAllStructStochIndicators()
{
  if(!Enable_Signal_Feature_Export)
    return;

  for(int i = 0; i < PIVOT_CONTEXT_TIMEFRAME_COUNT; i++)
    AddStructStochIndicatorHandle(PivotContextTimeframeAt(i), false);
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

bool PivotIndicatorHandleExists(IndicatorsHandleInfo &handles[],
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

bool LoadPivotBandsHandle(const ENUM_TIMEFRAMES timeframe,
                          IndicatorsHandleInfo &handle_info,
                          const bool required = true)
{
  handle_info = IndicatorsHandleInfo();
  handle_info.indicator_period        = PIVOT_CONTEXT_BANDS_PERIOD;
  handle_info.indicator_shift         = 0;
  handle_info.indicator_ma_method     = MODE_SMA;
  handle_info.indicator_applied_price = PRICE_CLOSE;
  handle_info.indicator_timeframe     = timeframe;
  handle_info.indicator_handle        = iBands(_Symbol,
                                               timeframe,
                                               PIVOT_CONTEXT_BANDS_PERIOD,
                                               0,
                                               PIVOT_CONTEXT_B_PERCENT_DEVIATION,
                                               PRICE_CLOSE);

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING DETERMINISTIC BANDS BASE: tf=%s | period=%d",
                EnumToString(timeframe),
                PIVOT_CONTEXT_BANDS_PERIOD);
    if(required)
      TesterStop();
    return false;
  }

  return true;
}

void AddPivotBandsHandle(IndicatorsHandleInfo &handles[],
                         const ENUM_TIMEFRAMES timeframe,
                         const bool required = true)
{
  if(PivotIndicatorHandleExists(handles, timeframe, 0))
    return;

  IndicatorsHandleInfo handle_info;
  if(!LoadPivotBandsHandle(timeframe, handle_info, required))
    return;

  AddElementToArray(handles, handle_info);
}

void SetTesterIndicatorHideMode(const bool hide)
{
  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return;

  TesterHideIndicators(hide);
}

void LoadPivotBandsIndicators()
{
  ArrayResize(ExtPivotBandsHandles, 0);
  SetTesterIndicatorHideMode(true);

  if(Enable_Signal_Feature_Export)
  {
    for(int i = 0; i < PIVOT_CONTEXT_TIMEFRAME_COUNT; i++)
    {
      AddPivotBandsHandle(ExtPivotBandsHandles,
                          PivotContextTimeframeAt(i),
                          false);
    }
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

void ReleaseAllPivotBandsIndicators()
{
  ReleaseIndicatorHandleArray(ExtPivotBandsHandles);
}

void LoadAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllPivotBandsIndicators();
  LoadAllStructStochIndicators();
  LoadPivotBandsIndicators();

  if(Enable_Logs)
  {
    PrintFormat("Pivot context handles | Engine=%s | Contexts=M1,M15,M30,H1,H4,D1 | Stoch=%d,%d,%d",
                PivotFractalEngineLabel(PIVOT_FRACTAL_V1),
                PIVOT_CONTEXT_STOCH_K,
                PIVOT_CONTEXT_STOCH_D,
                PIVOT_CONTEXT_STOCH_SLOWING);
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllPivotBandsIndicators();
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
