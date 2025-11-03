//+------------------------------------------------------------------+
//|                                        SecretLabsFXIndicator.mq5 |
//|                          Copyright 2022-2023, Traders Capital Team. |
//|                                  https://t.me/TradingAlgoritmicoFx |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#include <MovingAverages.mqh>
//---
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3
/*
*/
#property indicator_type1   DRAW_LINE
#property indicator_color1  LightSeaGreen
#property indicator_type2   DRAW_LINE
#property indicator_color2  LightSeaGreen
#property indicator_type3   DRAW_LINE
#property indicator_color3  LightSeaGreen

#property indicator_label1  "Indicator M"
#property indicator_label2  "Indicator H"
#property indicator_label3  "Indicator L"
int BULLISH = 1;
int BEARISH = 2;
//--- input parametrs
input int     InpCandlePeriod=21;       // Moving Average Period
input int     InpCandleShift=0;         // Shift Candles
input double  InpCandlesCalculation=2;  // Bands Deviation
input ENUM_MA_METHOD InpMAMethod=MODE_EMA; // Moving Average Method
//--- global variables
int           ExtBandsPeriod,ExtBandsShift;
double        ExtBandsDeviations;
int           ExtPlotBegin=0;
//--- indicator buffer
double        ExtMLBuffer[];
double        ExtTLBuffer[];
double        ExtBLBuffer[];
double        ExtStdDevBuffer[];
double        ExtAtrBuffer[];
int    ExtATRHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input values
   if(InpCandlePeriod<2)
     {
      ExtBandsPeriod=20;
      PrintFormat("Incorrect value for input variable Candles_N_Period=%d. Indicator will use value=%d for calculations.",InpCandlePeriod,ExtBandsPeriod);
     }
   else
      ExtBandsPeriod=InpCandlePeriod;
   if(InpCandleShift<0)
     {
      ExtBandsShift=0;
      PrintFormat("Incorrect value for input variable Back_Candles=%d. Indicator will use value=%d for calculations.",InpCandleShift,ExtBandsShift);
     }
   else
      ExtBandsShift=InpCandleShift;
   if(InpCandlesCalculation==0.0)
     {
      ExtBandsDeviations=2.0;
      PrintFormat("Incorrect value for input variable Candles_MaxMin_Calculation=%f. Indicator will use value=%f for calculations.",InpCandlesCalculation,ExtBandsDeviations);
     }
   else
      ExtBandsDeviations=InpCandlesCalculation;
//--- define buffers
   SetIndexBuffer(0,ExtTLBuffer, INDICATOR_DATA);
   SetIndexBuffer(1,ExtMLBuffer, INDICATOR_DATA);
   SetIndexBuffer(2,ExtBLBuffer, INDICATOR_DATA);
   SetIndexBuffer(3,ExtStdDevBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,ExtAtrBuffer,INDICATOR_CALCULATIONS);
//--- set index labels
   PlotIndexSetString(0,PLOT_LABEL,"BB Standard("+string(ExtBandsPeriod)+") M");
   PlotIndexSetString(1,PLOT_LABEL,"BB Standard("+string(ExtBandsPeriod)+") H");
   PlotIndexSetString(2,PLOT_LABEL,"BB Standard("+string(ExtBandsPeriod)+") L");
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"BB Just Profit");
//--- indexes draw begin settings
   ExtPlotBegin=ExtBandsPeriod-1;
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtBandsPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtBandsPeriod);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,ExtBandsPeriod);
//--- indexes shift settings
   PlotIndexSetInteger(0,PLOT_SHIFT,ExtBandsShift);
   PlotIndexSetInteger(1,PLOT_SHIFT,ExtBandsShift);
   PlotIndexSetInteger(2,PLOT_SHIFT,ExtBandsShift);
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
  }
//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   if(rates_total<ExtPlotBegin)
      return(0);
//--- indexes draw begin settings, when we've recieved previous begin
   if(ExtPlotBegin!=ExtBandsPeriod+begin)
     {
      ExtPlotBegin=ExtBandsPeriod+begin;
      PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtPlotBegin);
      PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtPlotBegin);
      PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,ExtPlotBegin);
     }
//--- starting calculation
   int pos;
   if(prev_calculated>1)
      pos=prev_calculated-1;
   else
      pos=1;

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

//--- main cycle
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      //--- middle line
      ExtMLBuffer[i]=MATypeCalc(i,price);
      //--- calculate and write down StdDev
      ExtStdDevBuffer[i]=StdDev_Func(i,price,ExtMLBuffer,ExtBandsPeriod);
      //--- upper line
      ExtTLBuffer[i]=ExtMLBuffer[i]+ExtBandsDeviations*ExtStdDevBuffer[i];
      //--- lower line
      ExtBLBuffer[i]=ExtMLBuffer[i]-ExtBandsDeviations*ExtStdDevBuffer[i];
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double StdDev_Func(const int position,const double &price[],const double &ma_price[],const int period)
  {
   double std_dev=0.0;
//--- calcualte StdDev
   if(position>=period)
     {
      for(int i=0; i<period; i++)
         std_dev+=MathPow(price[position-i]-ma_price[position],2.0);
      std_dev=MathSqrt(std_dev/period);
     }
//--- return calculated value
   return(std_dev);
  }
//+------------------------------------------------------------------+
double MATypeCalc(const int position,const double &price[])
{
   if(InpMAMethod == MODE_SMA) return SimpleMA(position,ExtBandsPeriod,price);
   if(InpMAMethod == MODE_EMA) return ExponentialMA(position,ExtBandsPeriod,ExtMLBuffer[position-1], price);
   if(InpMAMethod == MODE_SMMA) return SmoothedMA(position,ExtBandsPeriod,ExtMLBuffer[position-1], price);
   if(InpMAMethod == MODE_LWMA) return LinearWeightedMA(position,ExtBandsPeriod, price);

   return 0;
}
//+------------------------------------------------------------------+
double MAAvgColorCalculation(const int position,const int period)
{
  if(ExtMLBuffer[position] > ExtMLBuffer[position-1]) return BULLISH;
  if(ExtMLBuffer[position] < ExtMLBuffer[position-1]) return BEARISH;

  return(0);
}
