//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtDeterministicBandsLogicHandles[];
IndicatorsHandleInfo ExtDeterministicBandsVisualHandles[];
IndicatorsHandleInfo ExtDeterministicBPercentVisualHandles[];
int total_tf_list_load = 0;
const string FOUNDATION_STRUCTURE_FIBONACCI_LEVELS = "0.0,61.8,100.0";

struct DeterministicMacroVisualChartState
{
  int             strategy_id;
  ENUM_TIMEFRAMES timeframe;
  long            chart_id;
  int             bands_indicator_handle;
  int             b_percent_indicator_handle;
  bool            chart_owned;
  bool            bands_indicator_added;
  bool            b_percent_indicator_added;

  DeterministicMacroVisualChartState()
  {
    strategy_id                = DETERMINISTIC_STRATEGY_NONE;
    timeframe                  = PERIOD_CURRENT;
    chart_id                   = 0;
    bands_indicator_handle     = INVALID_HANDLE;
    b_percent_indicator_handle = INVALID_HANDLE;
    chart_owned                = false;
    bands_indicator_added      = false;
    b_percent_indicator_added  = false;
  }

  DeterministicMacroVisualChartState(const DeterministicMacroVisualChartState &source)
  {
    strategy_id                = source.strategy_id;
    timeframe                  = source.timeframe;
    chart_id                   = source.chart_id;
    bands_indicator_handle     = source.bands_indicator_handle;
    b_percent_indicator_handle = source.b_percent_indicator_handle;
    chart_owned                = source.chart_owned;
    bands_indicator_added      = source.bands_indicator_added;
    b_percent_indicator_added  = source.b_percent_indicator_added;
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

  for(int strategy_index = 0; strategy_index < DETERMINISTIC_STRATEGY_TOTAL; strategy_index++)
  {
    int strategy_id = DETERMINISTIC_STRATEGY_NONE;
    if(!DeterministicStrategyIdByIndex(strategy_index, strategy_id))
      continue;
    if(!DeterministicStrategyEnabled(strategy_id))
      continue;

    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles,
                                         DETERMINISTIC_BASE_TIMEFRAME);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles,
                                         DeterministicStrategyMacroTimeframe(strategy_id));
  }

  if(Enable_Signal_Feature_Export)
  {
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_H1);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_H4);
    AddDeterministicBandsBaseLogicHandle(ExtDeterministicBandsLogicHandles, PERIOD_D1);
  }
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

bool AddIndicatorToChartWindow(const long chart_id,
                               const int sub_window,
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
  if(!ChartIndicatorAdd(chart_id, sub_window, indicator_handle))
  {
    if(Enable_Logs)
    {
      PrintFormat("ChartIndicatorAdd failed | context=%s | chart=%I64d | tf=%s | window=%d | err=%d",
                  context_label,
                  chart_id,
                  EnumToString(timeframe),
                  sub_window,
                  GetLastError());
    }
    return false;
  }

  ChartRedraw(chart_id);
  return true;
}

bool AddIndicatorToMainChart(const long chart_id,
                             const int indicator_handle,
                             const ENUM_TIMEFRAMES timeframe,
                             const string context_label)
{
  return AddIndicatorToChartWindow(chart_id,
                                   0,
                                   indicator_handle,
                                   timeframe,
                                   context_label);
}

bool AddIndicatorToNewSubwindow(const long chart_id,
                                const int indicator_handle,
                                const ENUM_TIMEFRAMES timeframe,
                                const string context_label)
{
  int sub_window = (int)ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);
  if(sub_window < 1)
    sub_window = 1;

  return AddIndicatorToChartWindow(chart_id,
                                   sub_window,
                                   indicator_handle,
                                   timeframe,
                                   context_label);
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

    AddDeterministicBandsVisualHandle(ExtDeterministicBandsVisualHandles,
                                      DETERMINISTIC_BASE_TIMEFRAME,
                                      DeterministicStrategyBaseDelay(strategy_id));
    AddDeterministicBPercentHandle(ExtDeterministicBPercentVisualHandles,
                                   DETERMINISTIC_BASE_TIMEFRAME,
                                   DeterministicStrategyBaseDelay(strategy_id));
  }
}

void AddDeterministicBaseVisualIndicatorsToChart()
{
  long chart_id = ChartID();
  int total = ArraySize(ExtDeterministicBandsVisualHandles);
  for(int i = 0; i < total; i++)
  {
    string context_label = "Base iBands shift " + IntegerToString(ExtDeterministicBandsVisualHandles[i].indicator_shift);
    AddIndicatorToMainChart(chart_id,
                            ExtDeterministicBandsVisualHandles[i].indicator_handle,
                            DETERMINISTIC_BASE_TIMEFRAME,
                            context_label);
  }

  total = ArraySize(ExtDeterministicBPercentVisualHandles);
  for(int j = 0; j < total; j++)
  {
    string context_label = "Base BB Percent shift " + IntegerToString(ExtDeterministicBPercentVisualHandles[j].indicator_shift);
    AddIndicatorToNewSubwindow(chart_id,
                               ExtDeterministicBPercentVisualHandles[j].indicator_handle,
                               DETERMINISTIC_BASE_TIMEFRAME,
                               context_label);
  }
}

void LoadDeterministicMacroVisualChart(const int strategy_id)
{
  ENUM_TIMEFRAMES macro_timeframe = DeterministicStrategyMacroTimeframe(strategy_id);
  if(macro_timeframe == PERIOD_CURRENT)
    return;

  IndicatorsHandleInfo bands_handle_info;
  if(!LoadDeterministicBandsVisualHandle(macro_timeframe,
                                         DETERMINISTIC_MACRO_DELAY,
                                         bands_handle_info))
    return;

  IndicatorsHandleInfo b_percent_handle_info;
  if(!LoadDeterministicBPercentHandle(macro_timeframe,
                                      DETERMINISTIC_MACRO_DELAY,
                                      b_percent_handle_info))
  {
    IndicatorRelease(bands_handle_info.indicator_handle);
    return;
  }

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
    IndicatorRelease(bands_handle_info.indicator_handle);
    IndicatorRelease(b_percent_handle_info.indicator_handle);
    return;
  }

  DeterministicMacroVisualChartState state;
  state.strategy_id                = strategy_id;
  state.timeframe                  = macro_timeframe;
  state.chart_id                   = chart_id;
  state.bands_indicator_handle     = bands_handle_info.indicator_handle;
  state.b_percent_indicator_handle = b_percent_handle_info.indicator_handle;
  state.chart_owned                = !ChartIdWasOpenBefore(previous_chart_ids, chart_id);
  state.bands_indicator_added      = false;
  state.b_percent_indicator_added  = false;

  int state_index = ArraySize(ExtDeterministicMacroVisualCharts);
  AddElementToArray(ExtDeterministicMacroVisualCharts, state);

  string context_label = "Macro iBands " + DeterministicStrategyLabel(strategy_id);
  if(AddIndicatorToMainChart(chart_id,
                             bands_handle_info.indicator_handle,
                             macro_timeframe,
                             context_label))
  {
    ExtDeterministicMacroVisualCharts[state_index].bands_indicator_added = true;
  }

  context_label = "Macro BB Percent " + DeterministicStrategyLabel(strategy_id);
  if(AddIndicatorToNewSubwindow(chart_id,
                                b_percent_handle_info.indicator_handle,
                                macro_timeframe,
                                context_label))
  {
    ExtDeterministicMacroVisualCharts[state_index].b_percent_indicator_added = true;
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

void LoadDeterministicBandsVisualIndicators()
{
  ArrayResize(ExtDeterministicBandsVisualHandles, 0);
  ArrayResize(ExtDeterministicBPercentVisualHandles, 0);
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
  int total = ArraySize(ExtDeterministicBandsVisualHandles);
  for(int i = 0; i < total; i++)
  {
    string context_label = "Base iBands shift " + IntegerToString(ExtDeterministicBandsVisualHandles[i].indicator_shift);
    DeleteIndicatorFromChartByHandle(chart_id,
                                     ExtDeterministicBandsVisualHandles[i].indicator_handle,
                                     context_label);
  }

  total = ArraySize(ExtDeterministicBPercentVisualHandles);
  for(int j = 0; j < total; j++)
  {
    string context_label = "Base BB Percent shift " + IntegerToString(ExtDeterministicBPercentVisualHandles[j].indicator_shift);
    DeleteIndicatorFromChartByHandle(chart_id,
                                     ExtDeterministicBPercentVisualHandles[j].indicator_handle,
                                     context_label);
  }

  ReleaseIndicatorHandleArray(ExtDeterministicBandsVisualHandles);
  ReleaseIndicatorHandleArray(ExtDeterministicBPercentVisualHandles);
}

void ReleaseAllDeterministicBandsIndicators()
{
  int macro_total = ArraySize(ExtDeterministicMacroVisualCharts);
  for(int i = 0; i < macro_total; i++)
  {
    string context_label = "Macro iBands " + DeterministicStrategyLabel(ExtDeterministicMacroVisualCharts[i].strategy_id);
    if(ExtDeterministicMacroVisualCharts[i].bands_indicator_added)
    {
      DeleteIndicatorFromChartByHandle(ExtDeterministicMacroVisualCharts[i].chart_id,
                                       ExtDeterministicMacroVisualCharts[i].bands_indicator_handle,
                                       context_label);
    }

    context_label = "Macro BB Percent " + DeterministicStrategyLabel(ExtDeterministicMacroVisualCharts[i].strategy_id);
    if(ExtDeterministicMacroVisualCharts[i].b_percent_indicator_added)
    {
      DeleteIndicatorFromChartByHandle(ExtDeterministicMacroVisualCharts[i].chart_id,
                                       ExtDeterministicMacroVisualCharts[i].b_percent_indicator_handle,
                                       context_label);
    }

    if(ExtDeterministicMacroVisualCharts[i].bands_indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(ExtDeterministicMacroVisualCharts[i].bands_indicator_handle);
      ExtDeterministicMacroVisualCharts[i].bands_indicator_handle = INVALID_HANDLE;
    }

    if(ExtDeterministicMacroVisualCharts[i].b_percent_indicator_handle != INVALID_HANDLE)
    {
      IndicatorRelease(ExtDeterministicMacroVisualCharts[i].b_percent_indicator_handle);
      ExtDeterministicMacroVisualCharts[i].b_percent_indicator_handle = INVALID_HANDLE;
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

    ExtDeterministicMacroVisualCharts[i].chart_id                  = 0;
    ExtDeterministicMacroVisualCharts[i].chart_owned               = false;
    ExtDeterministicMacroVisualCharts[i].bands_indicator_added     = false;
    ExtDeterministicMacroVisualCharts[i].b_percent_indicator_added = false;
  }

  ArrayResize(ExtDeterministicMacroVisualCharts, 0);
  ReleaseIndicatorHandleArray(ExtDeterministicBandsLogicHandles);
  ReleaseDeterministicBaseVisualIndicators();
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
  LoadDeterministicBandsVisualIndicators();

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
  ReleaseAllDeterministicBandsIndicators();
  ArrayResize(Strategy_TF_List, 0);
  total_tf_list_load = 0;
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
