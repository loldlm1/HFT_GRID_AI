//+------------------------------------------------------------------+
//|                                     ATR_SL_Factor_Percent.mq5   |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#include <MovingAverages.mqh>

#property indicator_separate_window
#property indicator_buffers 16
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  LightSeaGreen
#property indicator_type2   DRAW_LINE
#property indicator_color2  Red
#property indicator_style2  STYLE_DOT
#property indicator_level1  0.0
#property indicator_level2 50.0
#property indicator_level3 100.0

input int                InpAtrPeriod          = 13;           // ATR period
input int                InpCandleShift        = 0;            // Shift
input double             InpAtrFactor          = 1.0;          // ATR factor
input int                InpPercentMAPeriod    = 5;            // Percent MA period
input ENUM_MA_METHOD     InpMAMethod           = MODE_EMA;     // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_TYPICAL;// Applied price

int    ExtAtrPeriod;
int    ExtBandsShift;
int    ExtPercentRangeWindow;
int    ExtPlotBegin = 0;

double BLGBuffer[];
double BBPMABuffer[];
double ExtAppliedPriceBuffer[];
double ChannelRawUpperBuffer[];
double ChannelRawLowerBuffer[];
double ExtTRBuffer[];
double ExtBBCloseBuffer[];
double ExtBBOpenBuffer[];
double ExtBBHighBuffer[];
double ExtBBLowBuffer[];
double ExtPercentRangeHigh[];
double ExtPercentRangeLow[];
double ChannelUpperBuffer[];
double ChannelMiddleBuffer[];
double ChannelLowerBuffer[];
double ExtATRBuffer[];

int OnInit()
{
  ExtAtrPeriod = MathMax(InpAtrPeriod, 1);
  ExtBandsShift = MathMax(InpCandleShift, 0);
  ExtPercentRangeWindow = (InpPercentMAPeriod <= 0) ? 5 : InpPercentMAPeriod;

  SetIndexBuffer(0, BLGBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, BBPMABuffer, INDICATOR_DATA);
  SetIndexBuffer(2, ExtAppliedPriceBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(3, ChannelRawUpperBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(4, ExtATRBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(5, ChannelRawLowerBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(6, ExtTRBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(7, ExtBBCloseBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(8, ExtBBOpenBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(9, ExtBBHighBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(10, ExtBBLowBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(11, ExtPercentRangeHigh, INDICATOR_CALCULATIONS);
  SetIndexBuffer(12, ExtPercentRangeLow, INDICATOR_CALCULATIONS);
  SetIndexBuffer(13, ChannelUpperBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(14, ChannelMiddleBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(15, ChannelLowerBuffer, INDICATOR_CALCULATIONS);

  PlotIndexSetString(0, PLOT_LABEL, "Main");
  PlotIndexSetString(1, PLOT_LABEL, "Signal");

  IndicatorSetString(INDICATOR_SHORTNAME,
                     "ATR Percent (" + string(ExtAtrPeriod) + "/" + string(InpPercentMAPeriod) + ")");
  ExtPlotBegin = ExtAtrPeriod - 1;
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtAtrPeriod);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtAtrPeriod);
  PlotIndexSetInteger(0, PLOT_SHIFT, ExtBandsShift);
  PlotIndexSetInteger(1, PLOT_SHIFT, ExtBandsShift);

  IndicatorSetInteger(INDICATOR_DIGITS, 2);

  return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
  if(rates_total <= ExtAtrPeriod)
    return 0;

  if(ExtPlotBegin != ExtAtrPeriod + 1)
  {
    ExtPlotBegin = ExtAtrPeriod + 1;
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPlotBegin);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPlotBegin);
  }

  if(IsStopped())
    return 0;

  int start;
  if(prev_calculated == 0)
  {
    ExtTRBuffer[0]  = 0.0;
    ExtATRBuffer[0] = 0.0;

    for(int i = 1; i < rates_total && !IsStopped(); i++)
      ExtTRBuffer[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

    double first_value = 0.0;
    int init_limit = MathMin(rates_total - 1, ExtAtrPeriod);
    for(int i = 1; i <= init_limit; i++)
      first_value += ExtTRBuffer[i];
    first_value /= ExtAtrPeriod;
    ExtATRBuffer[ExtAtrPeriod] = first_value;
    start = ExtAtrPeriod + 1;
  }
  else
  {
    start = prev_calculated - 1;
  }

  if(start < ExtAtrPeriod + 1)
    start = ExtAtrPeriod + 1;

  for(int i = start; i < rates_total && !IsStopped(); i++)
  {
    ExtTRBuffer[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
    int history_index = i - ExtAtrPeriod;
    double prev_atr   = ExtATRBuffer[i-1];
    double tr_remove  = ExtTRBuffer[history_index];
    ExtATRBuffer[i]   = prev_atr + (ExtTRBuffer[i] - tr_remove) / ExtAtrPeriod;
  }

  for(int i = start; i < rates_total && !IsStopped(); i++)
  {
    double body_high   = MathMax(open[i], close[i]);
    double body_low    = MathMin(open[i], close[i]);
    double body_range  = body_high - body_low;
    double lower_wick  = body_low - low[i];
    double upper_wick  = high[i] - body_high;
    double lower_denom = MathMax(body_range + lower_wick, _Point);
    double upper_denom = MathMax(body_range + upper_wick, _Point);
    double lower_weight = lower_wick / lower_denom;
    double upper_weight = upper_wick / upper_denom;
    double long_anchor  = close[i] - (1.0 - lower_weight) * body_range;
    double short_anchor = close[i] + (1.0 - upper_weight) * body_range;

    ChannelRawUpperBuffer[i] = NormalizeDouble(short_anchor + ExtATRBuffer[i]*InpAtrFactor, _Digits);
    ChannelRawLowerBuffer[i] = NormalizeDouble(long_anchor  - ExtATRBuffer[i]*InpAtrFactor, _Digits);
  }

  int sma_period = MathMax(ExtAtrPeriod, 1);
  int sma_start  = (prev_calculated == 0) ? 0 : prev_calculated - 1;
  if(sma_start < 0)
    sma_start = 0;

  for(int i = sma_start; i < rates_total && !IsStopped(); i++)
  {
    if(i < sma_period - 1 || i < start)
    {
      ChannelUpperBuffer[i]  = EMPTY_VALUE;
      ChannelLowerBuffer[i]  = EMPTY_VALUE;
      ChannelMiddleBuffer[i] = EMPTY_VALUE;
      continue;
    }

    double sma_upper = SimpleMA(i, sma_period, ChannelRawUpperBuffer);
    double sma_lower = SimpleMA(i, sma_period, ChannelRawLowerBuffer);
    ChannelUpperBuffer[i] = NormalizeDouble(sma_upper, _Digits);
    ChannelLowerBuffer[i] = NormalizeDouble(sma_lower, _Digits);
    if(ChannelUpperBuffer[i] == EMPTY_VALUE || ChannelLowerBuffer[i] == EMPTY_VALUE)
      ChannelMiddleBuffer[i] = EMPTY_VALUE;
    else
      ChannelMiddleBuffer[i] = NormalizeDouble((ChannelUpperBuffer[i] + ChannelLowerBuffer[i]) * 0.5, _Digits);
  }

  int percent_start = (prev_calculated < ExtAtrPeriod) ? ExtAtrPeriod : prev_calculated - 1;
  if(percent_start < sma_period - 1)
    percent_start = sma_period - 1;

  for(int i = percent_start; i < rates_total && !IsStopped(); i++)
  {
    if(ChannelUpperBuffer[i] == EMPTY_VALUE || ChannelLowerBuffer[i] == EMPTY_VALUE)
    {
      ExtAppliedPriceBuffer[i] = EMPTY_VALUE;
      BLGBuffer[i]             = EMPTY_VALUE;
      BBPMABuffer[i]           = EMPTY_VALUE;
      ExtBBCloseBuffer[i]      = EMPTY_VALUE;
      ExtBBOpenBuffer[i]       = EMPTY_VALUE;
      ExtBBHighBuffer[i]       = EMPTY_VALUE;
      ExtBBLowBuffer[i]        = EMPTY_VALUE;
      ExtPercentRangeHigh[i]   = EMPTY_VALUE;
      ExtPercentRangeLow[i]    = EMPTY_VALUE;
      continue;
    }

    double range = ChannelUpperBuffer[i] - ChannelLowerBuffer[i];
    if(range == 0.0)
      range = _Point;

    ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);

    BLGBuffer[i]    = NormalizeDouble((close[i] - ChannelLowerBuffer[i]) / range * 100.0, 2);
    BBPMABuffer[i]  = SimpleMA(i, InpPercentMAPeriod, BLGBuffer);

    ExtBBCloseBuffer[i] = NormalizeDouble((close[i] - ChannelLowerBuffer[i]) / range * 100.0, 2);
    ExtBBOpenBuffer[i]  = NormalizeDouble((open[i]  - ChannelLowerBuffer[i]) / range * 100.0, 2);
    ExtBBHighBuffer[i]  = NormalizeDouble((high[i]  - ChannelLowerBuffer[i]) / range * 100.0, 2);
    ExtBBLowBuffer[i]   = NormalizeDouble((low[i]   - ChannelLowerBuffer[i]) / range * 100.0, 2);

    int range_from = i - ExtPercentRangeWindow + 1;
    if(range_from < 0)
    {
      ExtPercentRangeHigh[i] = EMPTY_VALUE;
      ExtPercentRangeLow[i]  = EMPTY_VALUE;
    }
    else
    {
      double range_high = BLGBuffer[range_from];
      double range_low  = BLGBuffer[range_from];
      for(int j = range_from + 1; j <= i; j++)
      {
        if(BLGBuffer[j] > range_high)
          range_high = BLGBuffer[j];
        if(BLGBuffer[j] < range_low)
          range_low = BLGBuffer[j];
      }
      ExtPercentRangeHigh[i] = NormalizeDouble(range_high, 2);
      ExtPercentRangeLow[i]  = NormalizeDouble(range_low, 2);
    }
  }

  return rates_total;
}

double GetAppliedPrice(const int index,
                       const double &open[],
                       const double &close[],
                       const double &high[],
                       const double &low[])
{
  switch(InpAppliedPrice)
  {
    case PRICE_CLOSE:     return close[index];
    case PRICE_OPEN:      return open[index];
    case PRICE_HIGH:      return high[index];
    case PRICE_LOW:       return low[index];
    case PRICE_MEDIAN:    return (high[index] + low[index]) / 2.0;
    case PRICE_TYPICAL:   return (high[index] + low[index] + close[index]) / 3.0;
    case PRICE_WEIGHTED:  return (high[index] + low[index] + close[index] + close[index]) / 4.0;
  }

  return close[index];
}
