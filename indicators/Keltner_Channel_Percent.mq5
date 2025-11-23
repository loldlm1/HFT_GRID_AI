//+------------------------------------------------------------------+
//|                                       Keltner_Channel_Percent.mq5|
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

input int                InpMAPeriod           = 21;           // Channel period
input int                InpATRPeriod          = 14;           // ATR period
input int                InpCandleShift        = 0;            // MA shift
input double             InpAtrFactor          = 2.0;          // ATR factor
input int                InpPercentMAPeriod    = 5;            // Percent MA period
input ENUM_MA_METHOD     InpMAMethod           = MODE_EMA;     // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice       = PRICE_TYPICAL;// Applied price

int    ExtBandsPeriod;
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
int    ExtKeltnerHandle = INVALID_HANDLE;

int OnInit()
{
  if(InpMAPeriod < 2)
  {
    ExtBandsPeriod = 21;
    PrintFormat("Incorrect value for input variable Candles_N_Period=%d. Using %d.",
                InpMAPeriod,
                ExtBandsPeriod);
  }
  else
  {
    ExtBandsPeriod = InpMAPeriod;
  }

  if(InpCandleShift < 0)
  {
    ExtBandsShift = 0;
    PrintFormat("Incorrect value for input variable Back_Candles=%d. Using %d.",
                InpCandleShift,
                ExtBandsShift);
  }
  else
  {
    ExtBandsShift = InpCandleShift;
  }

  if(InpPercentMAPeriod <= 0)
  {
    ExtPercentRangeWindow = 5;
    PrintFormat("Incorrect value for Percent Range Window=%d. Using %d.",
                InpPercentMAPeriod,
                ExtPercentRangeWindow);
  }
  else
  {
    ExtPercentRangeWindow = InpPercentMAPeriod;
  }

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
                     "Keltner Percent (" + string(ExtBandsPeriod) + "/" + string(InpPercentMAPeriod) + ")");

  ExtPlotBegin = ExtBandsPeriod - 1;
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtBandsPeriod);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtBandsPeriod);
  PlotIndexSetInteger(0, PLOT_SHIFT, ExtBandsShift);
  PlotIndexSetInteger(1, PLOT_SHIFT, ExtBandsShift);

  IndicatorSetInteger(INDICATOR_DIGITS, 2);

  ExtKeltnerHandle = iCustom(NULL,
                             0,
                             "Examples\\Keltner_Channel",
                             ExtBandsPeriod,
                             InpATRPeriod,
                             ExtBandsShift,
                             InpAtrFactor,
                             InpMAMethod,
                             InpAppliedPrice);
  if(ExtKeltnerHandle == INVALID_HANDLE)
  {
    Print("Failed to create Keltner Channel handle for percent indicator: ", GetLastError());
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
  if(rates_total < ExtBandsPeriod)
    return 0;

  int calculated = BarsCalculated(ExtKeltnerHandle);
  if(calculated < rates_total)
    return 0;

  if(ExtPlotBegin != ExtBandsPeriod + 1)
  {
    ExtPlotBegin = ExtBandsPeriod + 1;
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPlotBegin);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPlotBegin);
  }

  //--- we can copy not all data
  int to_copy;
  if(prev_calculated>rates_total || prev_calculated<0)
    to_copy=rates_total;
  else
    {
      to_copy=rates_total-prev_calculated;
      if(prev_calculated>0)
        to_copy++;
    }
  //--- get ma buffers
  if(IsStopped()) // checking for stop flag
    return(0);

  if(CopyBuffer(ExtKeltnerHandle, 0, 0, to_copy, ChannelUpperBuffer)<=0)
    return(0);
  if(CopyBuffer(ExtKeltnerHandle, 1, 0, to_copy, ChannelMiddleBuffer)<=0)
    return(0);
  if(CopyBuffer(ExtKeltnerHandle, 2, 0, to_copy, ChannelLowerBuffer)<=0)
    return(0);

  //--- first calculation or number of bars was changed
  int start;
  if(prev_calculated<ExtBandsPeriod)
    start=ExtBandsPeriod;
  else
    start=prev_calculated-1;

  for(int i = start; i < rates_total && !IsStopped(); i++)
  {
    double range = ChannelUpperBuffer[i] - ChannelLowerBuffer[i];
    if(range == 0.0)
      range = _Point;

    ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);
    ExtATRBuffer[i]          = range;

    BLGBuffer[i] = NormalizeDouble((close[i] - ChannelLowerBuffer[i]) / range * 100.0, 2);
    BBPMABuffer[i] = SimpleMA(i, InpPercentMAPeriod, BLGBuffer);

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

  return(rates_total);
}

void OnDeinit(const int reason)
{
  if(ExtKeltnerHandle != INVALID_HANDLE)
  {
    IndicatorRelease(ExtKeltnerHandle);
    ExtKeltnerHandle = INVALID_HANDLE;
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
