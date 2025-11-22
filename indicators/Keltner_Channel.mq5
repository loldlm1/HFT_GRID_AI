//+------------------------------------------------------------------+
//|                                            Keltner_Channel.mq5   |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"

#property indicator_chart_window
#property indicator_buffers 3
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

input int                InpMAPeriod     = 21;            // EMA period
input int                InpATRPeriod    = 14;            // ATR period
input int                InpCandleShift  = 0;             // Shift
input double             InpATRFactor    = 2.0;           // ATR multiplier
input ENUM_MA_METHOD     InpMAMethod     = MODE_EMA;      // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL; // Applied price

double ExtUpperBuffer[];
double ExtMiddleBuffer[];
double ExtLowerBuffer[];

int    ExtEMAHandle = INVALID_HANDLE;
int    ExtATRHandle = INVALID_HANDLE;

int OnInit()
{
  SetIndexBuffer(0, ExtUpperBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, ExtMiddleBuffer, INDICATOR_DATA);
  SetIndexBuffer(2, ExtLowerBuffer, INDICATOR_DATA);

  PlotIndexSetInteger(0, PLOT_SHIFT, InpCandleShift);
  PlotIndexSetInteger(1, PLOT_SHIFT, InpCandleShift);
  PlotIndexSetInteger(2, PLOT_SHIFT, InpCandleShift);

  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMAPeriod);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMAPeriod);
  PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpMAPeriod);

  IndicatorSetString(INDICATOR_SHORTNAME,
                     "Keltner Channel (" + string(InpMAPeriod) + "," + string(InpATRPeriod) + ")");
  IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

  ExtEMAHandle = iMA(NULL,
                     0,
                     MathMax(InpMAPeriod, 1),
                     0,
                     InpMAMethod,
                     InpAppliedPrice);
  ExtATRHandle = iATR(NULL, 0, MathMax(InpATRPeriod, 1));

  if(ExtEMAHandle == INVALID_HANDLE || ExtATRHandle == INVALID_HANDLE)
  {
    Print("Failed to create Keltner Channel indicator handles.");
    return INIT_FAILED;
  }

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
  if(rates_total <= InpMAPeriod || rates_total <= InpATRPeriod)
    return 0;

  int start = (prev_calculated == 0) ? MathMax(InpMAPeriod, InpATRPeriod) : prev_calculated - 1;
  if(start < 0)
    start = 0;

  double ema_buffer[];
  double atr_buffer[];
  int request_count = rates_total;

  if(CopyBuffer(ExtEMAHandle, 0, 0, request_count, ema_buffer) <= 0)
    return prev_calculated;
  if(CopyBuffer(ExtATRHandle, 0, 0, request_count, atr_buffer) <= 0)
    return prev_calculated;

  for(int i = start; i < rates_total; i++)
  {
    double middle = ema_buffer[i];
    double atr    = atr_buffer[i];

    if(middle == EMPTY_VALUE || atr == EMPTY_VALUE)
    {
      ExtUpperBuffer[i]  = EMPTY_VALUE;
      ExtMiddleBuffer[i] = EMPTY_VALUE;
      ExtLowerBuffer[i]  = EMPTY_VALUE;
      continue;
    }

    double offset = atr * InpATRFactor;
    ExtUpperBuffer[i]  = middle + offset;
    ExtMiddleBuffer[i] = middle;
    ExtLowerBuffer[i]  = middle - offset;
  }

  return rates_total;
}

void OnDeinit(const int reason)
{
  if(ExtEMAHandle != INVALID_HANDLE)
    IndicatorRelease(ExtEMAHandle);
  if(ExtATRHandle != INVALID_HANDLE)
    IndicatorRelease(ExtATRHandle);
}
