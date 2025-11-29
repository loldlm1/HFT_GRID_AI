//+------------------------------------------------------------------+
//|                                           MACD_Histogram_GPT.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- plot del MACD
#property indicator_label1  "MACD"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot de la Signal
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MovingAverages.mqh>

input int                  InpFastPeriod     = 5;
input int                  InpSlowPeriod     = 34;
input int                  InpSignalPeriod   = 5;
input ENUM_APPLIED_PRICE   InpAppliedPrice   = PRICE_WEIGHTED;
input ENUM_MA_METHOD       InpMAMethod       = MODE_EMA;

// MACD Calculation Buffers
double MacdBuffer[];
double SignalBuffer[];
double FastMaBuffer[];
double SlowMaBuffer[];

int OnInit()
{
  SetIndexBuffer(0, MacdBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, SignalBuffer, INDICATOR_DATA);
  SetIndexBuffer(2, FastMaBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(3, SlowMaBuffer, INDICATOR_CALCULATIONS);

  // Configurar inicio de dibujo
  int draw_begin = InpSlowPeriod + InpSignalPeriod;
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

  //--- nombre del indicador y etiqueta
  string short_name = StringFormat("MACD Histogram(%d,%d,%d)", InpFastPeriod, InpSlowPeriod, InpSignalPeriod);
  IndicatorSetString(INDICATOR_SHORTNAME, short_name);
  PlotIndexSetString(0, PLOT_LABEL, "MACD");
  PlotIndexSetString(1, PLOT_LABEL, "Signal");

  //--- configuramos valores vacíos
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

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
  if(rates_total <= InpSlowPeriod + InpSignalPeriod)
    return(0);

  if(prev_calculated == 0)
  {
     ArrayInitialize(MacdBuffer, 0.0);
     ArrayInitialize(SignalBuffer, 0.0);
     ArrayInitialize(FastMaBuffer, 0.0);
     ArrayInitialize(SlowMaBuffer, 0.0);
  }

  // 1. Calculate Fast MA
  switch(InpMAMethod)
  {
     case MODE_SMA:  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, close, FastMaBuffer); break;
     case MODE_EMA:  ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, close, FastMaBuffer); break;
     case MODE_SMMA: SmoothedMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, close, FastMaBuffer); break;
     case MODE_LWMA: LinearWeightedMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, close, FastMaBuffer); break;
  }

  // 2. Calculate Slow MA
  switch(InpMAMethod)
  {
     case MODE_SMA:  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, close, SlowMaBuffer); break;
     case MODE_EMA:  ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, close, SlowMaBuffer); break;
     case MODE_SMMA: SmoothedMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, close, SlowMaBuffer); break;
     case MODE_LWMA: LinearWeightedMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, close, SlowMaBuffer); break;
  }

  // 3. Calculate MACD Buffer
  int start = prev_calculated - 1;
  if(start < InpSlowPeriod) start = InpSlowPeriod;

  for(int i = start; i < rates_total; i++)
  {
     MacdBuffer[i] = FastMaBuffer[i] - SlowMaBuffer[i];
  }

  // 4. Calculate Signal Line (SMA of MACD)
  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSignalPeriod, MacdBuffer, SignalBuffer);

  return(rates_total);
}
