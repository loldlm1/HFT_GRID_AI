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
int    ExtATRHandle = INVALID_HANDLE;

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

  ExtATRHandle = iCustom(NULL,
                         0,
                         "Examples\\ATR_SL_Factor",
                         ExtAtrPeriod,
                         InpAtrFactor,
                         ExtBandsShift);
  if(ExtATRHandle == INVALID_HANDLE)
  {
    Print("Failed to create ATR SL Factor handle for percent indicator: ", GetLastError());
    return INIT_FAILED;
  }

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

  double upper_buffer[];
  double lower_buffer[];
  double middle_buffer[];

  if(CopyBuffer(ExtATRHandle, 0, 0, rates_total, upper_buffer) <= 0)
    return prev_calculated;
  if(CopyBuffer(ExtATRHandle, 1, 0, rates_total, lower_buffer) <= 0)
    return prev_calculated;
  if(CopyBuffer(ExtATRHandle, 2, 0, rates_total, middle_buffer) <= 0)
    return prev_calculated;

  if(ExtPlotBegin != ExtAtrPeriod + 1)
  {
    ExtPlotBegin = ExtAtrPeriod + 1;
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPlotBegin);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPlotBegin);
  }

  int start = (prev_calculated > 1) ? prev_calculated - 1 : ExtAtrPeriod;
  if(start < ExtAtrPeriod)
    start = ExtAtrPeriod;

  for(int i = start; i < rates_total && !IsStopped(); i++)
  {
    double upper = upper_buffer[i];
    double lower = lower_buffer[i];
    double middle = middle_buffer[i];

    ExtTLBuffer[i] = upper;
    ExtBLBuffer[i] = lower;
    ExtMLBuffer[i] = middle;
    ChannelUpperBuffer[i]  = upper;
    ChannelLowerBuffer[i]  = lower;
    ChannelMiddleBuffer[i] = middle;

    if(upper == EMPTY_VALUE || lower == EMPTY_VALUE || middle == EMPTY_VALUE)
    {
      BLGBuffer[i]        = EMPTY_VALUE;
      BBPMABuffer[i]      = EMPTY_VALUE;
      ExtBBCloseBuffer[i] = EMPTY_VALUE;
      ExtBBOpenBuffer[i]  = EMPTY_VALUE;
      ExtBBHighBuffer[i]  = EMPTY_VALUE;
      ExtBBLowBuffer[i]   = EMPTY_VALUE;
      ExtPercentRangeHigh[i] = EMPTY_VALUE;
      ExtPercentRangeLow[i]  = EMPTY_VALUE;
      continue;
    }

    double range = upper - lower;
    if(range == 0.0)
      range = _Point;

    ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);
    ExtATRBuffer[i]          = range;

    BLGBuffer[i] = NormalizeDouble((close[i] - lower) / range * 100.0, 2);
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

void OnDeinit(const int reason)
{
  if(ExtATRHandle != INVALID_HANDLE)
  {
    IndicatorRelease(ExtATRHandle);
    ExtATRHandle = INVALID_HANDLE;
  }
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
