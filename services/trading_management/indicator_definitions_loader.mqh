//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

PivotBandsHandleInfo g_macro_bands_handle;
PivotBandsHandleInfo g_deep_bands_handle;
PivotBandsHandleInfo g_micro_bands_handle;
PivotStochasticHandleInfo g_macro_stochastic_handle;
PivotStochasticHandleInfo g_deep_stochastic_handle;
PivotStochasticHandleInfo g_micro_stochastic_handle;

void SetTesterIndicatorHideMode(const bool hide)
{
  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return;

  TesterHideIndicators(hide);
}

bool LoadPivotBandsHandle(const ENUM_TIMEFRAMES timeframe,
                          const string context_label,
                          PivotBandsHandleInfo &handle_out)
{
  handle_out.Reset(timeframe);
  ResetLastError();
  handle_out.indicator_handle = iBands(_Symbol,
                                       timeframe,
                                       PIVOT_CONTEXT_BANDS_PERIOD,
                                       0,
                                       PIVOT_CONTEXT_B_PERCENT_DEVIATION,
                                       PRICE_WEIGHTED);
  if(handle_out.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("Weighted Bands handle unavailable | context=%s | timeframe=%s | period=%d | error=%d",
                context_label,
                EnumToString(timeframe),
                PIVOT_CONTEXT_BANDS_PERIOD,
                GetLastError());
    return false;
  }

  if(Enable_Logs)
  {
    PrintFormat("Weighted Bands handle loaded | context=%s | timeframe=%s | period=%d | deviation=%.2f",
                context_label,
                EnumToString(timeframe),
                PIVOT_CONTEXT_BANDS_PERIOD,
                PIVOT_CONTEXT_B_PERCENT_DEVIATION);
  }
  return true;
}

bool LoadPivotStochasticHandle(const ENUM_TIMEFRAMES timeframe,
                               const string context_label,
                               PivotStochasticHandleInfo &handle_out)
{
  handle_out.Reset(timeframe);
  ResetLastError();
  handle_out.indicator_handle = iStochastic(
    _Symbol,
    timeframe,
    PIVOT_CONTEXT_STOCHASTIC_K_PERIOD,
    PIVOT_CONTEXT_STOCHASTIC_D_PERIOD,
    PIVOT_CONTEXT_STOCHASTIC_SLOWING,
    MODE_SMA,
    STO_CLOSECLOSE);
  if(handle_out.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("Stochastic handle unavailable | context=%s | timeframe=%s | K=%d | D=%d | slowing=%d | error=%d",
                context_label,
                EnumToString(timeframe),
                PIVOT_CONTEXT_STOCHASTIC_K_PERIOD,
                PIVOT_CONTEXT_STOCHASTIC_D_PERIOD,
                PIVOT_CONTEXT_STOCHASTIC_SLOWING,
                GetLastError());
    return false;
  }

  if(Enable_Logs)
  {
    PrintFormat("Stochastic handle loaded | context=%s | timeframe=%s | K=%d | D=%d | slowing=%d | method=MODE_SMA | price=STO_CLOSECLOSE",
                context_label,
                EnumToString(timeframe),
                PIVOT_CONTEXT_STOCHASTIC_K_PERIOD,
                PIVOT_CONTEXT_STOCHASTIC_D_PERIOD,
                PIVOT_CONTEXT_STOCHASTIC_SLOWING);
  }
  return true;
}

void ReleasePivotBandsHandle(PivotBandsHandleInfo &handle_info)
{
  if(handle_info.indicator_handle != INVALID_HANDLE)
    IndicatorRelease(handle_info.indicator_handle);
  handle_info.Reset(handle_info.timeframe);
}

void ReleasePivotStochasticHandle(
  PivotStochasticHandleInfo &handle_info)
{
  if(handle_info.indicator_handle != INVALID_HANDLE)
    IndicatorRelease(handle_info.indicator_handle);
  handle_info.Reset(handle_info.timeframe);
}

void LoadAllIndicatorDefinitions()
{
  ReleasePivotBandsHandle(g_macro_bands_handle);
  ReleasePivotBandsHandle(g_deep_bands_handle);
  ReleasePivotBandsHandle(g_micro_bands_handle);
  ReleasePivotStochasticHandle(g_macro_stochastic_handle);
  ReleasePivotStochasticHandle(g_deep_stochastic_handle);
  ReleasePivotStochasticHandle(g_micro_stochastic_handle);
  g_macro_bands_handle.Reset(Macro_Timeframe);
  g_deep_bands_handle.Reset(Deep_Timeframe);
  g_micro_bands_handle.Reset(Micro_Timeframe);
  g_macro_stochastic_handle.Reset(Macro_Timeframe);
  g_deep_stochastic_handle.Reset(Deep_Timeframe);
  g_micro_stochastic_handle.Reset(Micro_Timeframe);

  if(!Enable_Signal_Feature_Export)
    return;

  SetTesterIndicatorHideMode(true);
  LoadPivotBandsHandle(Macro_Timeframe, "Macro", g_macro_bands_handle);
  LoadPivotBandsHandle(Deep_Timeframe, "Deep", g_deep_bands_handle);
  LoadPivotBandsHandle(Micro_Timeframe, "Micro", g_micro_bands_handle);
  LoadPivotStochasticHandle(Macro_Timeframe,
                            "Macro",
                            g_macro_stochastic_handle);
  LoadPivotStochasticHandle(Deep_Timeframe,
                            "Deep",
                            g_deep_stochastic_handle);
  LoadPivotStochasticHandle(Micro_Timeframe,
                            "Micro",
                            g_micro_stochastic_handle);
  SetTesterIndicatorHideMode(false);

  if(Enable_Logs)
  {
    PrintFormat("Pivot feature contexts | Engine=%s | Macro=%s | Deep=%s | Micro=%s | Bands=PRICE_WEIGHTED | Stochastic=MAIN_LINE,SIGNAL_LINE",
                PivotFractalEngineLabel(PIVOT_FRACTAL_V2),
                EnumToString(Macro_Timeframe),
                EnumToString(Deep_Timeframe),
                EnumToString(Micro_Timeframe));
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleasePivotBandsHandle(g_macro_bands_handle);
  ReleasePivotBandsHandle(g_deep_bands_handle);
  ReleasePivotBandsHandle(g_micro_bands_handle);
  ReleasePivotStochasticHandle(g_macro_stochastic_handle);
  ReleasePivotStochasticHandle(g_deep_stochastic_handle);
  ReleasePivotStochasticHandle(g_micro_stochastic_handle);
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
