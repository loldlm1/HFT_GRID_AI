//+------------------------------------------------------------------+
//|                                              Keltner Channel.mq5 |
//|                              Copyright 2009-2025, MetaQuotes Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2009-2025, MetaQuotes Ltd"
#property link        "http://www.mql5.com"
#property description "Keltner Channel"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
//--- labels
#property indicator_label1  "Upper Keltner"
#property indicator_label2  "Middle Keltner"
#property indicator_label3  "Lower Keltner"
#include <MovingAverages.mqh>

//--- input parameters
input int    InpMAPeriod=13;    // Period of MA
input int    InpATRPeriod=5;    // Period of ATR
input int    InpCandleShift=0;   // Shift Candles
input double InpATRFactor=1.0;   // ATR multiplier
input ENUM_MA_METHOD InpMAMethod=MODE_EMA; // Moving Average Method

//--- global variables for parameters
int    ExtEMAPeriod;
int    ExtATRPeriod;
double ExtATRFactor;
int    ExtPeriod;

//--- indicator buffers
double ExtUppBuffer[];
double ExtEMABuffer[];
double ExtDwnBuffer[];

//--- indicator handles
int    ExtEMAHandle;
int    ExtATRHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- check for input values
   if(InpMAPeriod<0)
     {
      ExtEMAPeriod=20;
      PrintFormat("Incorrect value for input variable InpMAPeriod=%d. Indicator will use value=%d for calculations.",
                  InpMAPeriod, ExtEMAPeriod);
     }
   else
      ExtEMAPeriod=InpMAPeriod;

   if(InpATRPeriod<0)
     {
      ExtATRPeriod=10;
      PrintFormat("Incorrect value for input variable InpATRPeriod=%d. Indicator will use value=%d for calculations.",
                  InpATRPeriod, ExtATRPeriod);
     }
   else
      ExtATRPeriod=InpATRPeriod;

   if(InpATRFactor<0)
     {
      ExtATRFactor=2.0;
      PrintFormat("Incorrect value for input variable InpBandsDeviations=%f. Indicator will use value=%f for calculations.",
                  InpATRFactor, ExtATRFactor);
     }
   else
      ExtATRFactor=InpATRFactor;

//--- define buffers
   SetIndexBuffer(0, ExtUppBuffer);
   SetIndexBuffer(1, ExtEMABuffer);
   SetIndexBuffer(2, ExtDwnBuffer);

//--- indexes draw begin settings
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMAPeriod+1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMAPeriod+1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpMAPeriod+1);

//--- set a 1-bar offset for each line
   PlotIndexSetInteger(0, PLOT_SHIFT, InpCandleShift);
   PlotIndexSetInteger(1, PLOT_SHIFT, InpCandleShift);
   PlotIndexSetInteger(2, PLOT_SHIFT, InpCandleShift);

//--- set drawing line empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Keltner Channel");
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- create indicators
   ExtEMAHandle=iMA(NULL, 0, InpMAPeriod, 0, InpMAMethod, PRICE_WEIGHTED);
   ExtATRHandle=iATR(NULL, 0, InpATRPeriod);

   ExtPeriod=PeriodSeconds(_Period);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
//--- if this is the first calculation of the indicator
   if(prev_calculated==0)
     {
      //--- populate the beginning values, for which the indicator cannot be calculated, with empty values
      ArrayFill(ExtUppBuffer, 0, rates_total, 0);
      ArrayFill(ExtEMABuffer, 0, rates_total, 0);
      ArrayFill(ExtDwnBuffer, 0, rates_total, 0);

      //--- get EMA values into the indicator buffer
      if(CopyBuffer(ExtEMAHandle, 0, 0, rates_total, ExtEMABuffer)<0)
         return(0);

      //--- get ATR indicator values into a dynamic array
      double atr[];
      if(CopyBuffer(ExtATRHandle, 0, 0, rates_total, atr)<0)
         return(0);

      //--- shift from the beginning by the required number of bars
      int start=MathMax(InpMAPeriod, InpATRPeriod)+1;

      //--- fill in the values of the upper and lower channel borders
      for(int i=start; i<rates_total; i++)
        {
         ExtUppBuffer[i]=ExtEMABuffer[i]+InpATRFactor*atr[i];
         ExtDwnBuffer[i]=ExtEMABuffer[i]-InpATRFactor*atr[i];
        }

      //--- succesfully calculated
      return(rates_total);
     }

//--- if the indicator has previously been calculated, calculate values for the last 2 bars
   int start=prev_calculated-2;
   for(int i=start; i<rates_total; i++)
     {
      //--- for element-by-element copying from the indicator, use the reverse index
      int reverse_index=rates_total-i;

      //--- get indicator values
      double ema[];
      if(CopyBuffer(ExtEMAHandle, 0, reverse_index, 1, ema)<0)
         return(prev_calculated);
      double atr[];
      if(CopyBuffer(ExtATRHandle, 0, reverse_index, 1, atr)<0)
         return(prev_calculated);

      //--- write values into buffers
      ExtEMABuffer[i]=ema[0];
      ExtUppBuffer[i]=ema[0]+InpATRFactor*atr[0];
      ExtDwnBuffer[i]=ema[0]-InpATRFactor*atr[0];
     }

//--- succesfully calculated
   return(rates_total);
  }


//+------------------------------------------------------------------+
