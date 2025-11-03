//+------------------------------------------------------------------+
//|                                                           BB.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#include <MovingAverages.mqh>
//---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  Silver
#property indicator_width1  2
#property indicator_type2   DRAW_LINE
#property indicator_color2  Red

//--- input parametrs
input int     InpMAPeriod=5;       // Period
input int     InpMAShift=0;         // Shift
//--- global variables
int           ExtBandsPeriod,ExtBandsShift;
double        ExtBandsDeviations;
int           ExtPlotBegin=0;
//--- indicator buffer
double        ExtAvgBuffer[];
double        ExtBodyBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- define buffers
   SetIndexBuffer(0,ExtBodyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1,ExtAvgBuffer, INDICATOR_DATA);
//--- set index labels
   PlotIndexSetString(0,PLOT_LABEL,"Candle Body Oscillator ("+string(InpMAPeriod)+")");
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"Candle Body Oscillator ("+string(InpMAPeriod)+")");
//--- indexes shift settings
   PlotIndexSetInteger(0,PLOT_SHIFT,InpMAShift);
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
  }
//+------------------------------------------------------------------+
//| Candle Body Oscillator                                           |
//+------------------------------------------------------------------+
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
//--- starting calculation
   int pos;
   if(prev_calculated>1)
      pos=prev_calculated-1;
   else
      pos=0;
//--- main cycle
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      ExtBodyBuffer[i] = MathAbs(open[i]-close[i]);
      ExtAvgBuffer[i]  = SimpleMA(i,InpMAPeriod,ExtBodyBuffer);
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
