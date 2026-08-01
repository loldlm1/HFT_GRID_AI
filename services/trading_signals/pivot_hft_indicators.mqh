//+------------------------------------------------------------------+
//|                      pivot_hft_indicators.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_INDICATORS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_INDICATORS_MQH_

int      g_pivot_hft_bands_handle = INVALID_HANDLE;
datetime g_pivot_hft_bands_bar = 0;
double   g_pivot_hft_bands_upper = 0.0;
double   g_pivot_hft_bands_lower = 0.0;
datetime g_pivot_hft_next_indicator_retry = 0;
const int PIVOT_HFT_BANDS_SOURCE_SHIFT = 1;

bool PivotHftCreateIndicators()
{
  if(!PivotHftTimeframesValid())
  {
    PrintFormat("Pivot HFT invalid timeframe pair | micro=%s | pivot=%s",
                EnumToString(Pivot_HFT_Micro_Timeframe),
                EnumToString(Pivot_HFT_Pivot_Timeframe));
    return false;
  }

  if(g_pivot_hft_bands_handle != INVALID_HANDLE)
    IndicatorRelease(g_pivot_hft_bands_handle);

  g_pivot_hft_bands_handle = iBands(_Symbol,
                                    Pivot_HFT_Micro_Timeframe,
                                    21,
                                    0,
                                    2.0,
                                    PRICE_CLOSE);
  if(g_pivot_hft_bands_handle == INVALID_HANDLE)
  {
    PrintFormat("Pivot HFT Bollinger handle failed | tf=%s | err=%d",
                EnumToString(Pivot_HFT_Micro_Timeframe),
                GetLastError());
    if((bool)MQLInfoInteger(MQL_TESTER))
      TesterStop();
    return false;
  }

  g_pivot_hft_bands_bar = 0;
  g_pivot_hft_bands_upper = 0.0;
  g_pivot_hft_bands_lower = 0.0;
  g_pivot_hft_next_indicator_retry = 0;
  return true;
}

void PivotHftReleaseIndicators()
{
  if(g_pivot_hft_bands_handle != INVALID_HANDLE)
  {
    IndicatorRelease(g_pivot_hft_bands_handle);
    g_pivot_hft_bands_handle = INVALID_HANDLE;
  }
  g_pivot_hft_bands_bar = 0;
  g_pivot_hft_bands_upper = 0.0;
  g_pivot_hft_bands_lower = 0.0;
}

bool PivotHftSetSignalResourcesActive(const bool should_be_active)
{
  if(!should_be_active)
  {
    if(g_pivot_hft_bands_handle != INVALID_HANDLE)
      PivotHftReleaseIndicators();
    if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
      PivotHftResetCampaign();
    return true;
  }

  if(g_pivot_hft_bands_handle != INVALID_HANDLE)
    return true;

  datetime current_time = TimeCurrent();
  if(g_pivot_hft_next_indicator_retry > current_time)
    return false;
  if(PivotHftCreateIndicators())
    return true;

  g_pivot_hft_next_indicator_retry = current_time + 60;
  return false;
}

bool PivotHftRefreshBandsSnapshot(const bool force_refresh = false)
{
  if(g_pivot_hft_bands_handle == INVALID_HANDLE)
    return false;

  datetime source_bar = iTime(_Symbol,
                              Pivot_HFT_Micro_Timeframe,
                              PIVOT_HFT_BANDS_SOURCE_SHIFT);
  if(source_bar <= 0)
    return false;

  if(!force_refresh &&
     source_bar == g_pivot_hft_bands_bar &&
     g_pivot_hft_bands_upper > 0.0 &&
     g_pivot_hft_bands_lower > 0.0)
    return true;

  double upper_values[1];
  double lower_values[1];

  int copied_upper = CopyBuffer(g_pivot_hft_bands_handle,
                                1,
                                PIVOT_HFT_BANDS_SOURCE_SHIFT,
                                1,
                                upper_values);
  int copied_lower = CopyBuffer(g_pivot_hft_bands_handle,
                                2,
                                PIVOT_HFT_BANDS_SOURCE_SHIFT,
                                1,
                                lower_values);
  if(copied_upper != 1 || copied_lower != 1)
    return false;
  if(upper_values[0] <= 0.0 || lower_values[0] <= 0.0)
    return false;

  g_pivot_hft_bands_upper = PivotHftNormalizePrice(upper_values[0]);
  g_pivot_hft_bands_lower = PivotHftNormalizePrice(lower_values[0]);
  g_pivot_hft_bands_bar = source_bar;
  return true;
}

bool PivotHftIndicatorsReady()
{
  return (g_pivot_hft_bands_handle != INVALID_HANDLE &&
          g_pivot_hft_bands_upper > 0.0 &&
          g_pivot_hft_bands_lower > 0.0);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_INDICATORS_MQH_
