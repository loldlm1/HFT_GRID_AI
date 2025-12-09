//+------------------------------------------------------------------+
//|                                              stoploss_factor.mq5 |
//|                                       Copyright 2022, mr_schmidt |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#property indicator_chart_window
#include <MovingAverages.mqh>

// --- Aumentamos buffers y plots para HH/LL basados en las bandas
#property indicator_buffers   7
#property indicator_plots     3

// --- Plot 1: ATR SMA Upper
#property indicator_type1  DRAW_LINE
#property indicator_label1 "ATR SMA Upper"
#property indicator_color1 MediumVioletRed
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

// --- Plot 2: ATR SMA Lower
#property indicator_type2  DRAW_LINE
#property indicator_label2 "ATR SMA Lower"
#property indicator_color2 Lime
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1

// --- Plot 3: Línea media entre SMA superior/inferior
#property indicator_type3  DRAW_LINE
#property indicator_label3 "ATR SMA Mid"
#property indicator_color3 Silver
#property indicator_style3 STYLE_DASH
#property indicator_width3 1

//--- input parameters
input    int                 InpATRPeriod   = 13;      // ATR period
input    double              InpATRPercent  = 1.0;     // ATR factor
input    int                 InpATRShift    = 0;       // ATR Shift

//-- indicator buffers (existentes)
double   ExtATRBuffer[];
double   ExtTRBuffer[];
double   BufferMAUpper[];
double   BufferMALower[];

double   BufferSmaUpper[];   // Media simple de la banda superior (referencia bajista)
double   BufferSmaLower[];   // Media simple de la banda inferior (referencia alcista)
double   BufferSmaMid[];     // Línea media entre las dos bandas

int      MaxPeriod;
int      ExtPeriodATR;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpATRPeriod<=0)
   {
      ExtPeriodATR=14;
      PrintFormat("Incorrect input parameter InpATRPeriod = %d. Indicator will use value %d for calculations.",InpATRPeriod,ExtPeriodATR);
   }
   else
      ExtPeriodATR=InpATRPeriod;

   // Buffers visibles
   SetIndexBuffer(0, BufferSmaUpper, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSmaLower, INDICATOR_DATA);
   SetIndexBuffer(2, BufferSmaMid,   INDICATOR_DATA);
   // Buffers de cálculo
   SetIndexBuffer(3, BufferMAUpper,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferMALower,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, ExtATRBuffer,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, ExtTRBuffer,    INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetInteger(INDICATOR_LEVELS, _Digits);

   // Shift visual para todos los plots visibles
   PlotIndexSetInteger(0, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(1, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(2, PLOT_SHIFT, InpATRShift);

   MaxPeriod = (int)MathMax(InpATRPeriod, InpATRPercent);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MaxPeriod);

   // Comienzo de dibujo para las medias suavizadas
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPeriodATR);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPeriodATR);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtPeriodATR);

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
   if(rates_total<=ExtPeriodATR)
      return(0);

   int i,start;

   if(prev_calculated==0)
   {
      ExtTRBuffer[0]=0.0;
      ExtATRBuffer[0]=0.0;

      for(i=1; i<rates_total && !IsStopped(); i++)
         ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);

      double firstValue=0.0;
      for(i=1; i<=ExtPeriodATR; i++)
      {
         ExtATRBuffer[i]=0.0;
         firstValue+=ExtTRBuffer[i];
      }
      firstValue/=ExtPeriodATR;
      ExtATRBuffer[ExtPeriodATR]=firstValue;
      start=ExtPeriodATR+1;
   }
   else
      start=prev_calculated-1;

   for(i=start; i<rates_total && !IsStopped(); i++)
   {
      ExtTRBuffer[i]=MathMax(high[i],close[i-1])-MathMin(low[i],close[i-1]);
      ExtATRBuffer[i]=ExtATRBuffer[i-1]+(ExtTRBuffer[i]-ExtTRBuffer[i-ExtPeriodATR])/ExtPeriodATR;
   }

   // >>> Cálculo de bandas ponderadas por wicks (lógica existente, NO modificada)
   for(i=start; i<rates_total; i++)
   {
      double body_high = MathMax(open[i], close[i]);
      double body_low = MathMin(open[i], close[i]);
      double body_range = body_high - body_low;
      double lower_wick = body_low - low[i];
      double upper_wick = high[i] - body_high;
      double lower_denom = MathMax(body_range + lower_wick, _Point);
      double upper_denom = MathMax(body_range + upper_wick, _Point);
      double lower_weight = lower_wick / lower_denom;
      double upper_weight = upper_wick / upper_denom;
      double long_anchor = close[i] - (1.0 - lower_weight) * body_range;
      double short_anchor = close[i] + (1.0 - upper_weight) * body_range;

      BufferMAUpper[i] = NormalizeDouble(short_anchor + ExtATRBuffer[i]*InpATRPercent, _Digits);
      BufferMALower[i] = NormalizeDouble(long_anchor  - ExtATRBuffer[i]*InpATRPercent, _Digits);
   }

   // >>> SMA sobre las bandas para obtener referencias suavizadas (usando SimpleMA)
   int sma_period = MathMax(ExtPeriodATR, 1);
   int sma_start = (prev_calculated == 0) ? 0 : prev_calculated-1;
   for(i=sma_start; i<rates_total; i++)
   {
      if(i < sma_period - 1)
      {
         BufferSmaUpper[i] = EMPTY_VALUE;
         BufferSmaLower[i] = EMPTY_VALUE;
         BufferSmaMid[i]   = EMPTY_VALUE;
         continue;
      }

      double sma_upper = SimpleMA(i, sma_period, BufferMAUpper);
      double sma_lower = SimpleMA(i, sma_period, BufferMALower);
      BufferSmaUpper[i] = NormalizeDouble(sma_upper, _Digits);
      BufferSmaLower[i] = NormalizeDouble(sma_lower, _Digits);
      if(BufferSmaUpper[i] == EMPTY_VALUE || BufferSmaLower[i] == EMPTY_VALUE)
         BufferSmaMid[i] = EMPTY_VALUE;
      else
         BufferSmaMid[i] = NormalizeDouble((BufferSmaUpper[i] + BufferSmaLower[i]) * 0.5, _Digits);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
