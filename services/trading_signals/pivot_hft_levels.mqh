//+------------------------------------------------------------------+
//|                         pivot_hft_levels.mqh                     |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_

bool PivotHftTimeframesValid()
{
  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  int pivot_seconds = PeriodSeconds(Pivot_HFT_Pivot_Timeframe);

  if(micro_seconds <= 0 || pivot_seconds <= 0)
    return false;
  if(micro_seconds > pivot_seconds)
    return false;
  return true;
}

double PivotHftPointSize()
{
  double point_size = g_symbol_constraints.point_size;
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double PivotHftTickSize()
{
  double tick_size = g_symbol_constraints.tick_size;
  if(tick_size <= 0.0)
    tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  if(tick_size <= 0.0)
    tick_size = PivotHftPointSize();
  return tick_size;
}

double PivotHftNormalizePrice(const double price)
{
  if(price <= 0.0)
    return 0.0;

  double tick_size = PivotHftTickSize();
  if(tick_size <= 0.0)
    return price;

  double rounded = MathRound(price / tick_size) * tick_size;
  int digits = _Digits;
  if(digits < 0)
    digits = 0;
  return NormalizeDouble(rounded, digits);
}

double PivotHftDistanceToPrice(const double points)
{
  if(points <= 0.0)
    return 0.0;
  return points * PivotHftPointSize();
}

bool PivotHftReadPreviousMacroBar(datetime &bar_time,
                                  double &bar_high,
                                  double &bar_low,
                                  double &bar_close)
{
  bar_time  = iTime(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_high  = iHigh(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_low   = iLow(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_close = iClose(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);

  if(bar_time <= 0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
    return false;
  if(bar_high < bar_low)
    return false;
  return true;
}

bool PivotHftRefreshPivotSnapshot(const bool force_refresh = false)
{
  if(!PivotHftTimeframesValid())
    return false;

  datetime current_macro_bar = iTime(_Symbol, Pivot_HFT_Pivot_Timeframe, 0);
  if(current_macro_bar <= 0)
    return false;

  if(!force_refresh &&
     current_macro_bar == g_pivot_hft_last_macro_bar &&
     g_pivot_hft_pivots.valid)
    return true;

  datetime source_bar_time = 0;
  double bar_high = 0.0;
  double bar_low = 0.0;
  double bar_close = 0.0;
  if(!PivotHftReadPreviousMacroBar(source_bar_time,
                                   bar_high,
                                   bar_low,
                                   bar_close))
    return false;

  double pivot = (bar_high + bar_low + bar_close) / 3.0;
  PivotHftPivotSnapshot snapshot;
  snapshot.source_bar_time = source_bar_time;
  snapshot.pivot           = PivotHftNormalizePrice(pivot);
  snapshot.resistance_1   = PivotHftNormalizePrice(2.0 * pivot - bar_low);
  snapshot.resistance_2   = PivotHftNormalizePrice(pivot + bar_high - bar_low);
  snapshot.resistance_3   = PivotHftNormalizePrice(bar_high + 2.0 * (pivot - bar_low));
  snapshot.support_1      = PivotHftNormalizePrice(2.0 * pivot - bar_high);
  snapshot.support_2      = PivotHftNormalizePrice(pivot - bar_high + bar_low);
  snapshot.support_3      = PivotHftNormalizePrice(bar_low - 2.0 * (bar_high - pivot));
  snapshot.valid           = (snapshot.pivot > 0.0 &&
                             snapshot.resistance_1 > 0.0 &&
                             snapshot.support_1 > 0.0);

  if(!snapshot.valid)
    return false;

  g_pivot_hft_pivots = snapshot;
  g_pivot_hft_last_macro_bar = current_macro_bar;
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
    PivotHftResetCampaign();
  return true;
}

double PivotHftResolveLevelPrice(const PivotHftPivotLevels level,
                                 const PivotHftPivotSnapshot &snapshot)
{
  switch(level)
  {
    case PIVOT_HFT_LEVEL_P:
      return snapshot.pivot;
    case PIVOT_HFT_LEVEL_R1:
      return snapshot.resistance_1;
    case PIVOT_HFT_LEVEL_R2:
      return snapshot.resistance_2;
    case PIVOT_HFT_LEVEL_R3:
      return snapshot.resistance_3;
    case PIVOT_HFT_LEVEL_S1:
      return snapshot.support_1;
    case PIVOT_HFT_LEVEL_S2:
      return snapshot.support_2;
    case PIVOT_HFT_LEVEL_S3:
      return snapshot.support_3;
    case PIVOT_HFT_LEVEL_NONE:
    default:
      return 0.0;
  }
}

string PivotHftLevelLabel(const PivotHftPivotLevels level)
{
  switch(level)
  {
    case PIVOT_HFT_LEVEL_P:
      return "P";
    case PIVOT_HFT_LEVEL_R1:
      return "R1";
    case PIVOT_HFT_LEVEL_R2:
      return "R2";
    case PIVOT_HFT_LEVEL_R3:
      return "R3";
    case PIVOT_HFT_LEVEL_S1:
      return "S1";
    case PIVOT_HFT_LEVEL_S2:
      return "S2";
    case PIVOT_HFT_LEVEL_S3:
      return "S3";
    case PIVOT_HFT_LEVEL_NONE:
    default:
      return "NONE";
  }
}

bool PivotHftDirectionAllowed(const SignalTypes direction)
{
  if(direction == BULLISH)
    return (Pivot_HFT_Direction_Mode == BOTH_DIRECTION ||
            Pivot_HFT_Direction_Mode == BULLISH_DIRECTION);
  if(direction == BEARISH)
    return (Pivot_HFT_Direction_Mode == BOTH_DIRECTION ||
            Pivot_HFT_Direction_Mode == BEARISH_DIRECTION);
  return false;
}

bool PivotHftLatestResistanceTouched(const double close_price,
                                     PivotHftPivotLevels &level,
                                     double &level_price)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(!g_pivot_hft_pivots.valid || close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_R1,
                                       PIVOT_HFT_LEVEL_R2,
                                       PIVOT_HFT_LEVEL_R3};
  for(int i = 2; i >= 0; i--)
  {
    double candidate_price = PivotHftResolveLevelPrice(candidates[i],
                                                       g_pivot_hft_pivots);
    if(candidate_price > 0.0 && close_price >= candidate_price)
    {
      level = candidates[i];
      level_price = candidate_price;
      return true;
    }
  }
  return false;
}

bool PivotHftLatestSupportTouched(const double close_price,
                                  PivotHftPivotLevels &level,
                                  double &level_price)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(!g_pivot_hft_pivots.valid || close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_S1,
                                       PIVOT_HFT_LEVEL_S2,
                                       PIVOT_HFT_LEVEL_S3};
  for(int i = 2; i >= 0; i--)
  {
    double candidate_price = PivotHftResolveLevelPrice(candidates[i],
                                                       g_pivot_hft_pivots);
    if(candidate_price > 0.0 && close_price <= candidate_price)
    {
      level = candidates[i];
      level_price = candidate_price;
      return true;
    }
  }
  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_
