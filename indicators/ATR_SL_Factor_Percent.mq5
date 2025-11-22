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
input int                InpPercentRangeWindow = 5;            // Percent range window

int    ExtAtrPeriod;
int    ExtBandsShift;
int    ExtPercentRangeWindow;
int    ExtPlotBegin = 0;

double BLGBuffer[];
double BBPMABuffer[];
double ExtAppliedPriceBuffer[];
double ExtBLBuffer[];
double ExtMLBuffer[];
double ExtTLBuffer[];
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
double ExtTRBuffer[];

int OnInit()
{
  ExtAtrPeriod = MathMax(InpAtrPeriod, 1);
  ExtBandsShift = MathMax(InpCandleShift, 0);
  ExtPercentRangeWindow = (InpPercentRangeWindow <= 0) ? 5 : InpPercentRangeWindow;

  SetIndexBuffer(0, BLGBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, BBPMABuffer, INDICATOR_DATA);
  SetIndexBuffer(2, ExtAppliedPriceBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(3, ExtBLBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(4, ExtATRBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(5, ExtMLBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(6, ExtTLBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(7, ExtBBCloseBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(8, ExtBBOpenBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(9, ExtBBHighBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(10, ExtBBLowBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(11, ExtPercentRangeHigh, INDICATOR_CALCULATIONS);
  SetIndexBuffer(12, ExtPercentRangeLow, INDICATOR_CALCULATIONS);
  SetIndexBuffer(13, ChannelUpperBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(14, ChannelMiddleBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(15, ChannelLowerBuffer, INDICATOR_CALCULATIONS);

  ArrayResize(ExtTRBuffer, 0);
  ArrayResize(ExtATRBuffer, 0);

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

  if(ArraySize(ExtTRBuffer) < rates_total)
    ArrayResize(ExtTRBuffer, rates_total);
  if(ArraySize(ExtATRBuffer) < rates_total)
    ArrayResize(ExtATRBuffer, rates_total);

  int start = (prev_calculated == 0) ? ExtAtrPeriod + 1 : prev_calculated - 1;
  if(start < 1)
    start = 1;

  if(prev_calculated == 0)
  {
    ExtTRBuffer[0] = 0.0;
    ExtATRBuffer[0] = 0.0;

    for(int i = 1; i < rates_total; i++)
      ExtTRBuffer[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

    double first_value = 0.0;
    for(int k = 1; k <= ExtAtrPeriod; k++)
      first_value += ExtTRBuffer[k];
    first_value /= ExtAtrPeriod;
    ExtATRBuffer[ExtAtrPeriod] = first_value;
  }

  for(int i = start; i < rates_total; i++)
  {
    ExtTRBuffer[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
    ExtATRBuffer[i] = ExtATRBuffer[i-1] +
                      (ExtTRBuffer[i] - ExtTRBuffer[i-ExtAtrPeriod]) / ExtAtrPeriod;
  }

  int pos = (prev_calculated > 1) ? prev_calculated - 1 : ExtAtrPeriod;
  for(int i = pos; i < rates_total && !IsStopped(); i++)
  {
    ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);

    double body_high = MathMax(open[i], close[i]);
    double body_low  = MathMin(open[i], close[i]);
    double body_range = body_high - body_low;
    double lower_wick = body_low - low[i];
    double upper_wick = high[i] - body_high;
    double lower_denom = MathMax(body_range + lower_wick, _Point);
    double upper_denom = MathMax(body_range + upper_wick, _Point);
    double lower_weight = lower_wick / lower_denom;
    double upper_weight = upper_wick / upper_denom;
    double long_anchor  = close[i] - (1.0 - lower_weight) * body_range;
    double short_anchor = close[i] + (1.0 - upper_weight) * body_range;

    double atr_value = ExtATRBuffer[i];
    double upper = NormalizeDouble(short_anchor + atr_value * InpAtrFactor, _Digits);
    double lower = NormalizeDouble(long_anchor  - atr_value * InpAtrFactor, _Digits);
    double middle = NormalizeDouble((upper + lower) * 0.5, _Digits);

    ExtTLBuffer[i] = upper;
    ExtBLBuffer[i] = lower;
    ExtMLBuffer[i] = middle;
    ChannelUpperBuffer[i] = upper;
    ChannelLowerBuffer[i] = lower;
    ChannelMiddleBuffer[i] = middle;

    double range = upper - lower;
    if(range == 0.0)
      range = _Point;

    BLGBuffer[i] = NormalizeDouble((ExtAppliedPriceBuffer[i] - lower) / range * 100.0, 2);
    BBPMABuffer[i] = SimpleMA(i, InpPercentMAPeriod, BLGBuffer);

    ExtBBCloseBuffer[i] = NormalizeDouble((close[i] - lower) / range * 100.0, 2);
    ExtBBOpenBuffer[i]  = NormalizeDouble((open[i]  - lower) / range * 100.0, 2);
    ExtBBHighBuffer[i]  = NormalizeDouble((high[i]  - lower) / range * 100.0, 2);
    ExtBBLowBuffer[i]   = NormalizeDouble((low[i]   - lower) / range * 100.0, 2);

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

double MATypeCalc(const int position,const double &price[])
{
  if(InpMAMethod == MODE_SMA) { return SimpleMA(position,ExtAtrPeriod,price); }
  if(InpMAMethod == MODE_EMA) { return ExponentialMA(position,ExtAtrPeriod,ExtMLBuffer[position-1], price); }
  if(InpMAMethod == MODE_SMMA) { return SmoothedMA(position,ExtAtrPeriod,ExtMLBuffer[position-1], price); }
  if(InpMAMethod == MODE_LWMA) { return LinearWeightedMA(position,ExtAtrPeriod, price); }

  return price[position];
}

double GetAppliedPrice(int i,const double &open[],const double &close[],const double &high[],const double &low[])
{
  switch(InpAppliedPrice)
  {
    case PRICE_CLOSE:     return(close[i]);
    case PRICE_OPEN:      return(open[i]);
    case PRICE_HIGH:      return(high[i]);
    case PRICE_LOW:       return(low[i]);
    case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
    case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
    case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
  }

  return(close[i]);
}
