//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtDeterministicBandsLogicHandles[];
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
  Strategy_TF_List[0] = EXTREMUM_ENGINE_TIMEFRAME;
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

bool LoadDeterministicBPercentHandle(const ENUM_TIMEFRAMES timeframe,
                                     const int candle_shift,
                                     IndicatorsHandleInfo &handle_info,
                                     const bool required = false)
{
  handle_info = IndicatorsHandleInfo();
  handle_info.indicator_period        = DETERMINISTIC_MA_PERIOD;
  handle_info.indicator_shift         = candle_shift;
  handle_info.indicator_ma_method     = MODE_SMA;
  handle_info.indicator_applied_price = PRICE_CLOSE;
  handle_info.indicator_timeframe     = timeframe;
  handle_info.indicator_handle        = iCustom(_Symbol,
                                                timeframe,
                                                "Examples\\BB_Percent_Standard.ex5",
                                                DETERMINISTIC_MA_PERIOD,
                                                candle_shift,
                                                DETERMINISTIC_B_PERCENT_DEVIATION,
                                                DETERMINISTIC_B_PERCENT_SIGNAL_PERIOD,
                                                MODE_SMA,
                                                PRICE_CLOSE);

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING DETERMINISTIC B_PERCENT: tf=%s | period=%d | shift=%d",
                EnumToString(timeframe),
                DETERMINISTIC_MA_PERIOD,
                candle_shift);
    if(required)
      TesterStop();
    return false;
  }

  return true;
}

void AddDeterministicBPercentHandle(IndicatorsHandleInfo &handles[],
                                    const ENUM_TIMEFRAMES timeframe,
                                    const int candle_shift,
                                    const bool required = false)
{
  if(DeterministicHandleExists(handles, timeframe, candle_shift))
    return;

  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicBPercentHandle(timeframe, candle_shift, handle_info, required))
    return;

  AddElementToArray(handles, handle_info);
}

bool LoadDeterministicBandsVisualHandle(const ENUM_TIMEFRAMES timeframe,
                                        const int bands_shift,
                                        IndicatorsHandleInfo &handle_info)
{
  handle_info = IndicatorsHandleInfo();
  handle_info.indicator_period        = DETERMINISTIC_MA_PERIOD;
  handle_info.indicator_shift         = bands_shift;
  handle_info.indicator_ma_method     = MODE_SMA;
  handle_info.indicator_applied_price = PRICE_CLOSE;
  handle_info.indicator_timeframe     = timeframe;

  ResetLastError();
  handle_info.indicator_handle        = iBands(_Symbol,
                                               timeframe,
                                               DETERMINISTIC_MA_PERIOD,
                                               bands_shift,
                                               DETERMINISTIC_B_PERCENT_DEVIATION,
                                               PRICE_CLOSE);

  if(handle_info.indicator_handle == INVALID_HANDLE)
  {
    if(Enable_Logs)
    {
      PrintFormat("ERROR LOADING DETERMINISTIC VISUAL BANDS: tf=%s | period=%d | shift=%d | err=%d",
                  EnumToString(timeframe),
                  DETERMINISTIC_MA_PERIOD,
                  bands_shift,
                  GetLastError());
    }
    return false;
  }

  return true;
}

void AddDeterministicBandsVisualHandle(IndicatorsHandleInfo &handles[],
                                       const ENUM_TIMEFRAMES timeframe,
                                       const int bands_shift)
{
  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicBandsVisualHandle(timeframe, bands_shift, handle_info))
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

  if(Enable_Signal_Feature_Export || ML_Inference_Mode != ML_INFERENCE_DISABLED)
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
  PrepareStrategyTimeframes();
  LoadStructureFibonacciLevels(FOUNDATION_STRUCTURE_FIBONACCI_LEVELS,
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicBandsIndicators();
  LoadAllStructStochIndicators();
  LoadDeterministicBandsLogicIndicators();

  if(Enable_Logs)
  {
    PrintFormat("Extremum engine context | Engine=%s | TF=%s | Stoch=%d,%d,%d | Direction=%s",
                ExtremumEngineLabel(EXTREMUM_ENGINE_V1),
                EnumToString(EXTREMUM_ENGINE_TIMEFRAME),
                DETERMINISTIC_STOCH_K,
                DETERMINISTIC_STOCH_D,
                DETERMINISTIC_STOCH_SLOWING,
                EnumToString(Strategy_Direction_Mode));
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleaseAllStructStochIndicators();
  ReleaseAllDeterministicBandsIndicators();
  ArrayResize(Strategy_TF_List, 0);
  total_tf_list_load = 0;
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
