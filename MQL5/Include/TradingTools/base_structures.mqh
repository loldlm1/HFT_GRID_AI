//+------------------------------------------------------------------+
//|               TradingTools/base_structures.mqh                    |
//+------------------------------------------------------------------+

struct IndicatorsHandleInfo
{
  int                 indicator_handle;
  int                 indicator_period;
  int                 indicator_shift;
  ENUM_MA_METHOD      indicator_ma_method;
  ENUM_APPLIED_PRICE  indicator_applied_price;
  ENUM_TIMEFRAMES     indicator_timeframe;

  IndicatorsHandleInfo()
  {
    indicator_handle        = INVALID_HANDLE;
    indicator_period        = 0;
    indicator_shift         = 0;
    indicator_ma_method     = -1;
    indicator_applied_price = -1;
    indicator_timeframe     = PERIOD_CURRENT;
  }
};
