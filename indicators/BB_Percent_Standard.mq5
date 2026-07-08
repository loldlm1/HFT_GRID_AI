//+------------------------------------------------------------------+
//|                                        SecretLabsFXIndicator.mq5 |
//|                        Copyright 2022-2023, BB Dynamic Full Data |
//|                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#include <MovingAverages.mqh>
//---
#property indicator_buffers 5
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

//--- input parametrs
input int     InpBandsPeriod             = 21;           // Bands Period
input int     InpCandleShift             = 0;            // Bands Shift
input double  InpDeviation               = 2.0;          // Deviation
input int     InpPercentMAPeriod         = 5;            // B Percent Period
input ENUM_MA_METHOD InpMAMethod         = MODE_EMA;     // MA Method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL;// Applied price

//--- global variables
int           ExtBandsPeriod,ExtBandsShift;
int           ExtPercentMAPeriod;
double        ExtBandsDeviations;
int           ExtPlotBegin=0;
int           ExtSignalPlotBegin=0;
//--- indicator buffer
double        BLGBuffer[];
double        BBPMABuffer[];
double        ExtAppliedPriceBuffer[];
double        ExtMLBuffer[];
double        ExtStdDevBuffer[];

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
   if(InpDeviation<=0.0)
     {
      ExtBandsDeviations=2.0;
      PrintFormat("Incorrect value for input variable Candles_MaxMin_Calculation=%f. Indicator will use value=%f for calculations.",InpDeviation,ExtBandsDeviations);
     }
   else
      ExtBandsDeviations=InpDeviation;
   if(InpPercentMAPeriod<=0)
     {
      ExtPercentMAPeriod=5;
      PrintFormat("Incorrect value for B Percent Period=%d. Indicator will use value=%d for calculations.", InpPercentMAPeriod, ExtPercentMAPeriod);
     }
   else
      ExtPercentMAPeriod=InpPercentMAPeriod;

   //--- B Percent buffers
   SetIndexBuffer(0,BLGBuffer, INDICATOR_DATA);
   SetIndexBuffer(1,BBPMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2,ExtAppliedPriceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ExtMLBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,ExtStdDevBuffer,INDICATOR_CALCULATIONS);

//--- set index labels
   PlotIndexSetString(0,PLOT_LABEL,"Main");
   PlotIndexSetString(1,PLOT_LABEL,"Signal");
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"BB Percent " + "(" +string(ExtBandsPeriod)+"/"+string(ExtPercentMAPeriod)+ ")");
//--- indexes draw begin settings
   ExtPlotBegin=ExtBandsPeriod+ExtBandsShift;
   ExtSignalPlotBegin=ExtPlotBegin+ExtPercentMAPeriod-1;
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtPlotBegin);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtSignalPlotBegin);
//--- the input shift selects the bands used by %B; it does not move the plot
   PlotIndexSetInteger(0,PLOT_SHIFT,0);
   PlotIndexSetInteger(1,PLOT_SHIFT,0);
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
   if(rates_total<=ExtPlotBegin)
      return(0);
//--- starting calculation
   int pos;
   if(prev_calculated>1 && prev_calculated<=rates_total)
      pos=prev_calculated-1;
   else
      pos=1;
//--- main cycle
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      ExtAppliedPriceBuffer[i] = GetAppliedPrice(i, open, close, high, low);

      //--- middle line
      ExtMLBuffer[i]=MATypeCalc(i,ExtAppliedPriceBuffer);
      //--- calculate and write down StdDev
      ExtStdDevBuffer[i]=StdDev_Func(i,ExtAppliedPriceBuffer,ExtMLBuffer,ExtBandsPeriod);

      BLGBuffer[i]=EMPTY_VALUE;
      BBPMABuffer[i]=EMPTY_VALUE;

      const int band_position=i-ExtBandsShift;
      if(band_position<ExtBandsPeriod)
         continue;

      const double std_dev=ExtStdDevBuffer[band_position];
      const double deviation=ExtBandsDeviations*std_dev;
      const double lower_band=ExtMLBuffer[band_position]-deviation;
      const double upper_band=ExtMLBuffer[band_position]+deviation;
      const double band_range=upper_band-lower_band;
      if(band_range==0.0)
         continue;

      //--- %B: current close relative to the selected Bollinger Bands window
      BLGBuffer[i]=(close[i]-lower_band)/band_range*100.0;
      if(i>=ExtSignalPlotBegin)
         BBPMABuffer[i]=SimpleMAValid(i,ExtPercentMAPeriod,BLGBuffer);
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
        {
         double delta=price[position-i]-ma_price[position];
         std_dev+=delta*delta;
        }
      std_dev=MathSqrt(std_dev/period);
     }
//--- return calculated value
   return(std_dev);
  }
//+------------------------------------------------------------------+
double MATypeCalc(const int position,const double &price[])
  {
   if(InpMAMethod==MODE_SMA)
      return SimpleMA(position,ExtBandsPeriod,price);
   if(InpMAMethod==MODE_EMA)
      return ExponentialMA(position,ExtBandsPeriod,ExtMLBuffer[position-1],price);
   if(InpMAMethod==MODE_SMMA)
      return SmoothedMA(position,ExtBandsPeriod,ExtMLBuffer[position-1],price);
   if(InpMAMethod==MODE_LWMA)
      return LinearWeightedMA(position,ExtBandsPeriod,price);

   return(0);
  }
//+------------------------------------------------------------------+
double SimpleMAValid(const int position,const int period,const double &price[])
  {
   if(position<period-1)
      return(EMPTY_VALUE);

   double sum=0.0;
   for(int i=0; i<period; i++)
     {
      const double value=price[position-i];
      if(value==EMPTY_VALUE)
         return(EMPTY_VALUE);
      sum+=value;
     }

   return(sum/period);
  }
//+------------------------------------------------------------------+

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
