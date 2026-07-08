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
IndicatorsHandleInfo ExtDeterministicBPercentLogicHandles[];
int total_tf_list_load = 0;
const string FOUNDATION_STRUCTURE_FIBONACCI_LEVELS = "0.0,61.8,100.0";

struct DeterministicMacroVisualChartState
{
  int             strategy_id;
  ENUM_TIMEFRAMES timeframe;
  long            chart_id;
  int             indicator_handle;
  bool            chart_owned;
  bool            indicator_added;

  DeterministicMacroVisualChartState()
  {
    strategy_id      = DETERMINISTIC_STRATEGY_NONE;
    timeframe        = PERIOD_CURRENT;
    chart_id         = 0;
    indicator_handle = INVALID_HANDLE;
    chart_owned      = false;
    indicator_added  = false;
  }

  DeterministicMacroVisualChartState(const DeterministicMacroVisualChartState &source)
  {
    strategy_id      = source.strategy_id;
    timeframe        = source.timeframe;
    chart_id         = source.chart_id;
    indicator_handle = source.indicator_handle;
    chart_owned      = source.chart_owned;
    indicator_added  = source.indicator_added;
  }
};

DeterministicMacroVisualChartState ExtDeterministicMacroVisualCharts[];

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
                               IndicatorsHandleInfo &handle_info,
                               const bool required = true)
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
    if(required)
      TesterStop();
    return false;
  }

  return true;
}

void AddDeterministicMaHandle(IndicatorsHandleInfo &handles[],
                              const ENUM_TIMEFRAMES timeframe,
                              const int ma_shift,
                              const bool required = true)
{
  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicMaHandle(timeframe, ma_shift, handle_info, required))
    return;

  AddElementToArray(handles, handle_info);
}

bool DeterministicBPercentFeaturesRequired()
{
  return Enable_Signal_Feature_Export || ML_Inference_Mode != ML_INFERENCE_DISABLED;
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

void LoadDeterministicMaLogicIndicators()
{
  ArrayResize(ExtDeterministicMaLogicHandles, 0);
  SetTesterIndicatorHideMode(true);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M1, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M3, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M5, 0);
  AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_M10, 0);
  if(Enable_Signal_Feature_Export)
  {
    AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_H1, 0);
    AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_H4, 0);
    AddDeterministicMaHandle(ExtDeterministicMaLogicHandles, PERIOD_D1, 0);
  }
  SetTesterIndicatorHideMode(false);
}

void LoadDeterministicBPercentLogicIndicators()
{
  ArrayResize(ExtDeterministicBPercentLogicHandles, 0);
  if(!DeterministicBPercentFeaturesRequired())
    return;

  bool required = (Enable_Signal_Feature_Export && MQLInfoInteger(MQL_TESTER) > 0);
  SetTesterIndicatorHideMode(true);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M1,
                                 DETERMINISTIC_S1_BASE_DELAY,
                                 required);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M1,
                                 DETERMINISTIC_S2_BASE_DELAY,
                                 required);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M1,
                                 DETERMINISTIC_S3_BASE_DELAY,
                                 required);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M3,
                                 DETERMINISTIC_MACRO_DELAY,
                                 required);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M5,
                                 DETERMINISTIC_MACRO_DELAY,
                                 required);
  AddDeterministicBPercentHandle(ExtDeterministicBPercentLogicHandles,
                                 PERIOD_M10,
                                 DETERMINISTIC_MACRO_DELAY,
                                 required);
  SetTesterIndicatorHideMode(false);
}

void CollectOpenChartIds(long &chart_ids[])
{
  ArrayResize(chart_ids, 0);

  long chart_id = ChartFirst();
  while(chart_id >= 0)
  {
    long current_chart_id = chart_id;
    AddElementToArray(chart_ids, current_chart_id);
    chart_id = ChartNext(chart_id);
  }
}

bool ChartIdWasOpenBefore(long &chart_ids[], const long chart_id)
{
  int total = ArraySize(chart_ids);
  for(int i = 0; i < total; i++)
  {
    if(chart_ids[i] == chart_id)
      return true;
  }

  return false;
}

bool ChartMatchesIndicatorContext(const long chart_id,
                                  const ENUM_TIMEFRAMES timeframe)
{
  if(chart_id <= 0)
    return false;

  string chart_symbol = ChartSymbol(chart_id);
  ENUM_TIMEFRAMES chart_timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chart_id);

  return (chart_symbol == _Symbol && chart_timeframe == timeframe);
}

bool AddIndicatorToChart(const long chart_id,
                         const int indicator_handle,
                         const ENUM_TIMEFRAMES timeframe,
                         const string context_label)
{
  if(indicator_handle == INVALID_HANDLE)
    return false;

  if(!ChartMatchesIndicatorContext(chart_id, timeframe))
  {
    if(Enable_Logs)
    {
      PrintFormat("Skipping visual indicator attachment | context=%s | chart=%I64d | expected_symbol=%s | expected_tf=%s",
                  context_label,
                  chart_id,
                  _Symbol,
                  EnumToString(timeframe));
    }
    return false;
  }

  ResetLastError();
  if(!ChartIndicatorAdd(chart_id, 0, indicator_handle))
  {
    if(Enable_Logs)
    {
      PrintFormat("ChartIndicatorAdd failed | context=%s | chart=%I64d | tf=%s | err=%d",
                  context_label,
                  chart_id,
                  EnumToString(timeframe),
                  GetLastError());
    }
    return false;
  }

  ChartRedraw(chart_id);
  return true;
}

bool DeleteIndicatorFromChartByHandle(const long chart_id,
                                      const int target_handle,
                                      const string context_label)
{
  if(chart_id <= 0 || target_handle == INVALID_HANDLE)
    return false;

  long windows_total = ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);
  for(int window_index = 0; window_index < (int)windows_total; window_index++)
  {
    int indicator_total = ChartIndicatorsTotal(chart_id, window_index);
    for(int indicator_index = indicator_total - 1; indicator_index >= 0; indicator_index--)
    {
      string indicator_name = ChartIndicatorName(chart_id, window_index, indicator_index);
      if(indicator_name == "")
        continue;

      int chart_handle = ChartIndicatorGet(chart_id, window_index, indicator_name);
      if(chart_handle == INVALID_HANDLE)
        continue;

      bool handle_matches = (chart_handle == target_handle);
      IndicatorRelease(chart_handle);

      if(!handle_matches)
        continue;

      ResetLastError();
      if(!ChartIndicatorDelete(chart_id, window_index, indicator_name))
      {
        if(Enable_Logs)
        {
          PrintFormat("ChartIndicatorDelete failed | context=%s | chart=%I64d | name=%s | err=%d",
                      context_label,
                      chart_id,
                      indicator_name,
                      GetLastError());
        }
        return false;
      }

      ChartRedraw(chart_id);
      return true;
    }
  }

  return false;
}

void LoadDeterministicBaseVisualIndicators()
{
  for(int strategy_index = 0; strategy_index < DETERMINISTIC_STRATEGY_TOTAL; strategy_index++)
  {
    int strategy_id = DETERMINISTIC_STRATEGY_NONE;
    if(!DeterministicStrategyIdByIndex(strategy_index, strategy_id))
      continue;
    if(!DeterministicStrategyEnabled(strategy_id))
      continue;

    AddDeterministicBandsVisualHandle(ExtDeterministicMaVisualHandles,
                                      DETERMINISTIC_BASE_TIMEFRAME,
                                      DeterministicStrategyBaseDelay(strategy_id));
  }
}

void AddDeterministicBaseVisualIndicatorsToChart()
{
  long chart_id = ChartID();
  int total = ArraySize(ExtDeterministicMaVisualHandles);
  for(int i = 0; i < total; i++)
  {
    string context_label = "Base iBands shift " + IntegerToString(ExtDeterministicMaVisualHandles[i].indicator_shift);
    AddIndicatorToChart(chart_id,
                        ExtDeterministicMaVisualHandles[i].indicator_handle,
                        DETERMINISTIC_BASE_TIMEFRAME,
                        context_label);
  }
}

void LoadDeterministicMacroVisualChart(const int strategy_id)
{
  ENUM_TIMEFRAMES macro_timeframe = DeterministicStrategyMacroTimeframe(strategy_id);
  if(macro_timeframe == PERIOD_CURRENT)
    return;

  IndicatorsHandleInfo handle_info;
  if(!LoadDeterministicBandsVisualHandle(macro_timeframe,
                                         DETERMINISTIC_MACRO_DELAY,
                                         handle_info))
    return;

  long previous_chart_ids[];
  CollectOpenChartIds(previous_chart_ids);

  ResetLastError();
  long chart_id = ChartOpen(_Symbol, macro_timeframe);
  if(chart_id <= 0)
  {
    if(Enable_Logs)
    {
      PrintFormat("ChartOpen failed for deterministic macro visual | strategy=%s | tf=%s | err=%d",
                  DeterministicStrategyLabel(strategy_id),
                  EnumToString(macro_timeframe),
                  GetLastError());
    }
    IndicatorRelease(handle_info.indicator_handle);
    return;
  }

  DeterministicMacroVisualChartState state;
  state.strategy_id      = strategy_id;
  state.timeframe        = macro_timeframe;
  state.chart_id         = chart_id;
  state.indicator_handle = handle_info.indicator_handle;
  state.chart_owned      = !ChartIdWasOpenBefore(previous_chart_ids, chart_id);
  state.indicator_added  = false;

  int state_index = ArraySize(ExtDeterministicMacroVisualCharts);
  AddElementToArray(ExtDeterministicMacroVisualCharts, state);

  string context_label = "Macro iBands " + DeterministicStrategyLabel(strategy_id);
  if(AddIndicatorToChart(chart_id,
                         handle_info.indicator_handle,
                         macro_timeframe,
                         context_label))
  {
    ExtDeterministicMacroVisualCharts[state_index].indicator_added = true;
  }
}

void LoadDeterministicMacroVisualCharts()
{
  for(int strategy_index = 0; strategy_index < DETERMINISTIC_STRATEGY_TOTAL; strategy_index++)
  {
    int strategy_id = DETERMINISTIC_STRATEGY_NONE;
    if(!DeterministicStrategyIdByIndex(strategy_index, strategy_id))
      continue;
    if(!DeterministicStrategyEnabled(strategy_id))
      continue;

    LoadDeterministicMacroVisualChart(strategy_id);
  }
}

void LoadDeterministicMaVisualIndicators()
{
  ArrayResize(ExtDeterministicMaVisualHandles, 0);
  ArrayResize(ExtDeterministicMacroVisualCharts, 0);

  if(!Enable_Show_Indicators)
    return;

  LoadDeterministicBaseVisualIndicators();
  AddDeterministicBaseVisualIndicatorsToChart();
  LoadDeterministicMacroVisualCharts();
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

void ReleaseDeterministicBaseVisualIndicators()
{
  long chart_id = ChartID();
  int total = ArraySize(ExtDeterministicMaVisualHandles);
  for(int i = 0; i < total; i++)
  {
    string context_label = "Base iBands shift " + IntegerToString(ExtDeterministicMaVisualHandles[i].indicator_shift);
    DeleteIndicatorFromChartByHandle(chart_id,
                                     ExtDeterministicMaVisualHandles[i].indicator_handle,
                                     context_label);
  }

  ReleaseIndicatorHandleArray(ExtDeterministicMaVisualHandles);
}

void ReleaseAllDeterministicMaIndicators()
{
  int macro_total = ArraySize(ExtDeterministicMacroVisualCharts);
  for(int i = 0; i < macro_total; i++)
  {
    string context_label = "Macro iBands " + DeterministicStrategyLabel(ExtDeterministicMacroVisualCharts[i].strategy_id);
    if(ExtDeterministicMacroVisualCharts[i].indicator_added)
    {
      DeleteIndicatorFromChartByHandle(ExtDeterministicMacroVisualCharts[i].chart_id,
                                       ExtDeterministicMacroVisualCharts[i].indicator_handle,
                                       context_label);
    }

    if(ExtDeterministicMacroVisualCharts[i].indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(ExtDeterministicMacroVisualCharts[i].indicator_handle);
      ExtDeterministicMacroVisualCharts[i].indicator_handle = INVALID_HANDLE;
    }

    if(ExtDeterministicMacroVisualCharts[i].chart_owned &&
       ExtDeterministicMacroVisualCharts[i].chart_id > 0)
    {
      ResetLastError();
      if(!ChartClose(ExtDeterministicMacroVisualCharts[i].chart_id) && Enable_Logs)
      {
        PrintFormat("ChartClose failed for deterministic macro visual | chart=%I64d | strategy=%s | err=%d",
                    ExtDeterministicMacroVisualCharts[i].chart_id,
                    DeterministicStrategyLabel(ExtDeterministicMacroVisualCharts[i].strategy_id),
                    GetLastError());
      }
    }

    ExtDeterministicMacroVisualCharts[i].chart_id        = 0;
    ExtDeterministicMacroVisualCharts[i].chart_owned     = false;
    ExtDeterministicMacroVisualCharts[i].indicator_added = false;
  }

  ArrayResize(ExtDeterministicMacroVisualCharts, 0);
  ReleaseIndicatorHandleArray(ExtDeterministicMaLogicHandles);
  ReleaseIndicatorHandleArray(ExtDeterministicBPercentLogicHandles);
  ReleaseDeterministicBaseVisualIndicators();
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
  LoadDeterministicBPercentLogicIndicators();
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
