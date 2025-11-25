//+------------------------------------------------------------------+
//|                                            Keltner_Channel.mq5   |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_label1  "Keltner Upper"
#property indicator_label2  "Keltner Middle"
#property indicator_label3  "Keltner Lower"
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_type3   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_color2  clrSilver
#property indicator_color3  clrTomato

#include <MovingAverages.mqh>

input int                InpMAPeriod     = 21;            // EMA period
input int                InpATRPeriod    = 14;            // ATR period
input int                InpCandleShift  = 0;             // Shift
input double             InpATRFactor    = 2.0;           // ATR multiplier
input ENUM_MA_METHOD     InpMAMethod     = MODE_EMA;      // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL; // Applied price

double ExtUpperBuffer[];
double ExtMiddleBuffer[];
double ExtLowerBuffer[];
double ExtAppliedPriceBuffer[];
double ExtATRBuffer[];
double ExtTRBuffer[];

int OnInit()
{
  SetIndexBuffer(0, ExtUpperBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, ExtMiddleBuffer, INDICATOR_DATA);
  SetIndexBuffer(2, ExtLowerBuffer, INDICATOR_DATA);
  SetIndexBuffer(3, ExtAppliedPriceBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(4, ExtATRBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(5, ExtTRBuffer, INDICATOR_CALCULATIONS);

  PlotIndexSetInteger(0, PLOT_SHIFT, InpCandleShift);
  PlotIndexSetInteger(1, PLOT_SHIFT, InpCandleShift);
  PlotIndexSetInteger(2, PLOT_SHIFT, InpCandleShift);

  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMAPeriod);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMAPeriod);
  PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpMAPeriod);

  IndicatorSetString(INDICATOR_SHORTNAME,
                     "Keltner Channel (" + string(InpMAPeriod) + "," + string(InpATRPeriod) + ")");
  IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

  return INIT_SUCCEEDED;
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
  int ma_period  = MathMax(InpMAPeriod, 1);
  int atr_period = MathMax(InpATRPeriod, 1);
  int min_rates  = MathMax(ma_period, atr_period);

  if(rates_total <= min_rates)
    return 0;

  EnsureBufferSize(ExtAppliedPriceBuffer, rates_total);
  EnsureBufferSize(ExtATRBuffer, rates_total);
  EnsureBufferSize(ExtTRBuffer, rates_total);

  int begin = (prev_calculated == 0) ? 0 : prev_calculated - 1;
  if(begin < 0)
    begin = 0;

  for(int i = begin; i < rates_total; i++)
    ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);

  int ma_start = MathMax(ma_period - 1, begin);
  for(int i = begin; i < ma_start; i++)
    ExtMiddleBuffer[i] = EMPTY_VALUE;

  for(int i = ma_start; i < rates_total; i++)
    ExtMiddleBuffer[i] = CalculateMAValue(i, ma_period, ExtAppliedPriceBuffer, ExtMiddleBuffer);

  int tr_start = (prev_calculated == 0) ? 1 : begin;
  if(tr_start < 1)
    tr_start = 1;
  for(int i = tr_start; i < rates_total; i++)
    ExtTRBuffer[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

  int atr_clear_end = MathMin(atr_period, rates_total);
  for(int i = begin; i < atr_clear_end; i++)
    ExtATRBuffer[i] = EMPTY_VALUE;

  int atr_start;
  if(prev_calculated == 0)
  {
    double first_atr = 0.0;
    for(int i = 1; i <= atr_period; i++)
      first_atr += ExtTRBuffer[i];
    first_atr /= atr_period;
    ExtATRBuffer[atr_period] = first_atr;
    atr_start = atr_period + 1;
  }
  else
  {
    atr_start = MathMax(begin, atr_period + 1);
  }

  for(int i = atr_start; i < rates_total; i++)
    ExtATRBuffer[i] = ExtATRBuffer[i-1] + (ExtTRBuffer[i] - ExtTRBuffer[i-atr_period]) / atr_period;

  int channel_start = MathMax(ma_start, atr_period);
  for(int i = begin; i < channel_start; i++)
  {
    ExtUpperBuffer[i]  = EMPTY_VALUE;
    ExtLowerBuffer[i]  = EMPTY_VALUE;
  }

  for(int i = channel_start; i < rates_total; i++)
  {
    double middle = ExtMiddleBuffer[i];
    double atr    = ExtATRBuffer[i];
    if(middle == EMPTY_VALUE || atr == EMPTY_VALUE)
    {
      ExtUpperBuffer[i]  = EMPTY_VALUE;
      ExtMiddleBuffer[i] = EMPTY_VALUE;
      ExtLowerBuffer[i]  = EMPTY_VALUE;
      continue;
    }

    double offset = atr * InpATRFactor;
    ExtUpperBuffer[i]  = middle + offset;
    ExtLowerBuffer[i]  = middle - offset;
  }

  return rates_total;
}

void EnsureBufferSize(double &buffer[], const int required)
{
  if(ArraySize(buffer) >= required)
    return;
  ArrayResize(buffer, required);
}

double CalculateMAValue(const int index,
                        const int period,
                        const double &price[],
                        double &ma_buffer[])
{
  if(index < period - 1)
    return EMPTY_VALUE;

  switch(InpMAMethod)
  {
    case MODE_SMA:
      return SimpleMA(index, period, price);
    case MODE_EMA:
    {
      double prev_value = (index == 0) ? price[index] : ma_buffer[index - 1];
      if(prev_value == EMPTY_VALUE)
        prev_value = SimpleMA(index, period, price);
      return ExponentialMA(index, period, prev_value, price);
    }
    case MODE_SMMA:
    {
      double prev_value = (index == 0) ? price[index] : ma_buffer[index - 1];
      if(prev_value == EMPTY_VALUE)
        prev_value = SimpleMA(index, period, price);
      return SmoothedMA(index, period, prev_value, price);
    }
    case MODE_LWMA:
      return LinearWeightedMA(index, period, price);
  }
  return SimpleMA(index, period, price);
}

double GetAppliedPrice(const int index,
                       const double &open[],
                       const double &close[],
                       const double &high[],
                       const double &low[])
{
  switch(InpAppliedPrice)
  {
    case PRICE_CLOSE:   return close[index];
    case PRICE_OPEN:    return open[index];
    case PRICE_HIGH:    return high[index];
    case PRICE_LOW:     return low[index];
    case PRICE_MEDIAN:  return (high[index] + low[index]) / 2.0;
    case PRICE_TYPICAL: return (high[index] + low[index] + close[index]) / 3.0;
    case PRICE_WEIGHTED:return (open[index] + high[index] + low[index] + close[index]) / 4.0;
    default:
      return close[index];
  }
}
