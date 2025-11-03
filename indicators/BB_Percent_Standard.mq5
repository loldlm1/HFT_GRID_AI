//+------------------------------------------------------------------+
//|                                        SecretLabsFXIndicator.mq5 |
//|                        Copyright 2022-2023, BB Dynamic Full Data |
//|                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#include <MovingAverages.mqh>
//---
#property indicator_buffers 11
#property indicator_plots   2
#property indicator_separate_window
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_color1  LightSeaGreen
#property indicator_color2  Red
#property indicator_style2  STYLE_DOT
#property indicator_level1 0.0
#property indicator_level2 50.0
#property indicator_level3 100.0
int BULLISH = 1;
int BEARISH = 2;

//--- input parametrs
input int     InpBandsPeriod             = 21;           // Bands Period
input int     InpCandleShift             = 0;            // MA Shift
input double  InpDeviation               = 2.0;          // Deviation
input int     InpPercentMAPeriod         = 5;            // B Percent Period
input ENUM_MA_METHOD InpMAMethod         = MODE_EMA;     // MA Method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL;// Applied price
//--- global variables
int           ExtBandsPeriod,ExtBandsShift;
double        ExtBandsDeviations;
int           ExtPlotBegin=0;
//--- indicator buffer
double        BLGBuffer[];
double        BBPMABuffer[];
double        ExtAppliedPriceBuffer[];
double        ExtMLBuffer[];
double        ExtTLBuffer[];
double        ExtBLBuffer[];
double        ExtStdDevBuffer[];
double        ExtBBCloseBuffer[];
double        ExtBBOpenBuffer[];
double        ExtBBHighBuffer[];
double        ExtBBLowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input values
   if(InpBandsPeriod<2)
     {
      ExtBandsPeriod=20;
      PrintFormat("Incorrect value for input variable Candles_N_Period=%d. Indicator will use value=%d for calculations.",InpBandsPeriod,ExtBandsPeriod);
     }
   else
      ExtBandsPeriod=InpBandsPeriod;
   if(InpCandleShift<0)
     {
      ExtBandsShift=0;
      PrintFormat("Incorrect value for input variable Back_Candles=%d. Indicator will use value=%d for calculations.",InpCandleShift,ExtBandsShift);
     }
   else
      ExtBandsShift=InpCandleShift;
   if(InpDeviation==0.0)
     {
      ExtBandsDeviations=2.0;
      PrintFormat("Incorrect value for input variable Candles_MaxMin_Calculation=%f. Indicator will use value=%f for calculations.",InpDeviation,ExtBandsDeviations);
     }
   else
      ExtBandsDeviations=InpDeviation;

   //--- STANDARD BB Buffers
   SetIndexBuffer(0,BLGBuffer, INDICATOR_DATA);
   SetIndexBuffer(1,BBPMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2,ExtAppliedPriceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ExtBLBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,ExtStdDevBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,ExtMLBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,ExtTLBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,ExtBBCloseBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,ExtBBOpenBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,ExtBBHighBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,ExtBBLowBuffer, INDICATOR_CALCULATIONS);

//--- set index labels
   PlotIndexSetString(0,PLOT_LABEL,"Main");
   PlotIndexSetString(1,PLOT_LABEL,"Signal");
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"BB Percent " + "(" +string(InpBandsPeriod)+"/"+string(InpPercentMAPeriod)+ ")");
//--- indexes draw begin settings
   ExtPlotBegin=ExtBandsPeriod-1;
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtBandsPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtBandsPeriod);
//--- indexes shift settings
   PlotIndexSetInteger(0,PLOT_SHIFT,ExtBandsShift);
   PlotIndexSetInteger(1,PLOT_SHIFT,ExtBandsShift);
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS,2);
  }
//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
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
   if(rates_total<ExtPlotBegin)
      return(0);
//--- indexes draw begin settings, when we've recieved previous begin
   if(ExtPlotBegin!=ExtBandsPeriod+1)
     {
      ExtPlotBegin=ExtBandsPeriod+1;
      PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtPlotBegin);
      PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtPlotBegin);
      PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,ExtPlotBegin);
     }
//--- starting calculation
   double middle_fast = 0;
   double upper_fast  = 0;
   double lower_fast  = 0;
   double middle_slow = 0;
   double upper_slow  = 0;
   double lower_slow  = 0;

   double middle_both = 0;
   double upper_both  = 0;
   double lower_both  = 0;

   int pos;
   if(prev_calculated>1)
      pos=prev_calculated-1;
   else
      pos=1;
//--- main cycle
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);

      //--- FAST middle line ---
      ExtMLBuffer[i]=MATypeCalc(i,ExtAppliedPriceBuffer);
      //--- calculate and write down StdDev
      ExtStdDevBuffer[i]=StdDev_Func(i,ExtAppliedPriceBuffer,ExtMLBuffer,InpBandsPeriod);
      //--- upper line
      ExtTLBuffer[i]=ExtMLBuffer[i]+ExtBandsDeviations*ExtStdDevBuffer[i];
      //--- lower line
      ExtBLBuffer[i]=ExtMLBuffer[i]-ExtBandsDeviations*ExtStdDevBuffer[i];

      //--- Percent B
      BLGBuffer[i]=NormalizeDouble((GetAppliedPrice(i, open, close, high, low)-ExtBLBuffer[i])/(ExtTLBuffer[i]-ExtBLBuffer[i]) * 100, 2);
      BBPMABuffer[i]=SimpleMA(i,InpPercentMAPeriod,BLGBuffer);

      //--- BB Percent Prices
      ExtBBCloseBuffer[i] = NormalizeDouble((close[i]-ExtBLBuffer[i])/(ExtTLBuffer[i]-ExtBLBuffer[i]) * 100, 2);
      ExtBBOpenBuffer[i]  = NormalizeDouble((open[i]-ExtBLBuffer[i])/(ExtTLBuffer[i]-ExtBLBuffer[i]) * 100, 2);
      ExtBBHighBuffer[i]  = NormalizeDouble((high[i]-ExtBLBuffer[i])/(ExtTLBuffer[i]-ExtBLBuffer[i]) * 100, 2);
      ExtBBLowBuffer[i]   = NormalizeDouble((low[i]-ExtBLBuffer[i])/(ExtTLBuffer[i]-ExtBLBuffer[i]) * 100, 2);
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
   if(InpMAMethod == MODE_SMA) { return SimpleMA(position,InpBandsPeriod,price); }
   if(InpMAMethod == MODE_EMA) { return ExponentialMA(position,InpBandsPeriod,ExtMLBuffer[position-1], price); }
   if(InpMAMethod == MODE_SMMA) { return SmoothedMA(position,InpBandsPeriod,ExtMLBuffer[position-1], price); }
   if(InpMAMethod == MODE_LWMA) { return LinearWeightedMA(position,InpBandsPeriod, price); }

   return 0;
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

  return(0);
}
