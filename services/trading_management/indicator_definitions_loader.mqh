//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

PivotBandsHandleInfo g_macro_bands_handle;
PivotBandsHandleInfo g_micro_bands_handle;

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

bool PivotBandsHandleReady(const PivotBandsHandleInfo &handle_info)
{
  return handle_info.indicator_handle != INVALID_HANDLE &&
         BarsCalculated(handle_info.indicator_handle) > 0;
}

void ReleasePivotBandsHandle(PivotBandsHandleInfo &handle_info)
{
  if(handle_info.indicator_handle != INVALID_HANDLE)
    IndicatorRelease(handle_info.indicator_handle);
  handle_info.Reset(handle_info.timeframe);
}

void LoadAllIndicatorDefinitions()
{
  ReleasePivotBandsHandle(g_macro_bands_handle);
  ReleasePivotBandsHandle(g_micro_bands_handle);
  g_macro_bands_handle.Reset(Macro_Timeframe);
  g_micro_bands_handle.Reset(Micro_Timeframe);

  if(!Enable_Signal_Feature_Export)
    return;

  SetTesterIndicatorHideMode(true);
  LoadPivotBandsHandle(Macro_Timeframe, "Macro", g_macro_bands_handle);
  LoadPivotBandsHandle(Micro_Timeframe, "Micro", g_micro_bands_handle);
  SetTesterIndicatorHideMode(false);

  if(Enable_Logs)
  {
    PrintFormat("Pivot Bands contexts | Engine=%s | Macro=%s | Micro=%s | applied_price=PRICE_WEIGHTED",
                PivotFractalEngineLabel(PIVOT_FRACTAL_V2),
                EnumToString(Macro_Timeframe),
                EnumToString(Micro_Timeframe));
  }
}

void ReleaseAllIndicatorDefinitions()
{
  ReleasePivotBandsHandle(g_macro_bands_handle);
  ReleasePivotBandsHandle(g_micro_bands_handle);
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
