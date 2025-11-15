//+------------------------------------------------------------------+
//|                                              stoploss_factor.mq5 |
//|                                       Copyright 2022, mr_schmidt |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#property indicator_chart_window

// --- Aumentamos buffers y plots para HH/LL basados en las bandas
#property indicator_buffers   8
#property indicator_plots     6

// --- Plot 1: Banda Superior
#property indicator_type1  DRAW_LINE
#property indicator_label1 "Stop Loss Upper"
#property indicator_color1 LightPink
#property indicator_style1 STYLE_DOT
#property indicator_width1 0

// --- Plot 2: Banda Inferior
#property indicator_type2  DRAW_LINE
#property indicator_label2 "Stop Loss Lower"
#property indicator_color2 LightPink
#property indicator_style2 STYLE_DOT
#property indicator_width2 0

// --- Plot 3: Resistencia (Highest High de la banda superior)
#property indicator_type3  DRAW_LINE
#property indicator_label3 "Resistance (HH of Upper)"
#property indicator_color3 DodgerBlue
#property indicator_style3 STYLE_DASH
#property indicator_width3 2

// --- Plot 4: Soporte (Lowest Low de la banda inferior)
#property indicator_type4  DRAW_LINE
#property indicator_label4 "Support (LL of Lower)"
#property indicator_color4 Orange
#property indicator_style4 STYLE_DASH
#property indicator_width4 2

// --- Plot 5: Resistencia cercana (tipo trailing)
#property indicator_type5  DRAW_LINE
#property indicator_label5 "Trailing Resistance"
#property indicator_color5 MediumVioletRed
#property indicator_style5 STYLE_SOLID
#property indicator_width5 1

// --- Plot 6: Soporte cercano (tipo trailing)
#property indicator_type6  DRAW_LINE
#property indicator_label6 "Trailing Support"
#property indicator_color6 Lime
#property indicator_style6 STYLE_SOLID
#property indicator_width6 1

//--- input parameters
input    int                 InpATRPeriod   = 13;      // ATR period
input    double              InpATRPercent  = 1.0;     // ATR factor
input    int                 InpATRShift    = 0;       // ATR Shift

//-- indicator buffers (existentes)
double   ExtATRBuffer[];
double   ExtTRBuffer[];
double   BufferMAUpper[];
double   BufferMALower[];

//-- NUEVOS buffers visibles para S/R horizontales basados en las bandas
double   BufferResHH[];      // Highest High de BufferMAUpper en ventana InpATRPeriod
double   BufferSupLL[];      // Lowest  Low  de BufferMALower en ventana InpATRPeriod
double   BufferResTrail[];   // Resistencia más cercana al precio actual dentro de la ventana
double   BufferSupTrail[];   // Soporte más cercano al precio actual dentro de la ventana

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

   // Buffers originales
   SetIndexBuffer(0, BufferMAUpper, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMALower, INDICATOR_DATA);
   SetIndexBuffer(2, BufferResHH,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferSupLL,   INDICATOR_DATA);
   SetIndexBuffer(4, BufferResTrail, INDICATOR_DATA);
   SetIndexBuffer(5, BufferSupTrail, INDICATOR_DATA);
   SetIndexBuffer(6, ExtATRBuffer,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, ExtTRBuffer,   INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetInteger(INDICATOR_LEVELS, _Digits);

   // Shift visual para todos los plots visibles
   PlotIndexSetInteger(0, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(1, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(2, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(3, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(4, PLOT_SHIFT, InpATRShift);
   PlotIndexSetInteger(5, PLOT_SHIFT, InpATRShift);

   MaxPeriod = (int)MathMax(InpATRPeriod, InpATRPercent);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MaxPeriod);

   // Comienzo de dibujo para HH/LL cuando existe ventana suficiente
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtPeriodATR);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, ExtPeriodATR);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, ExtPeriodATR);
   PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, ExtPeriodATR);

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

   // >>> NUEVO: Highest High de la banda superior y Lowest Low de la banda inferior
   //     Ventana = ExtPeriodATR (InpATRPeriod). Se calculan como "líneas horizontales por tramos".
   int from;
   for(i=start; i<rates_total; i++)
   {
      from = i - ExtPeriodATR + 1;
      if(from < 0)
      {
         BufferResHH[i] = EMPTY_VALUE;
         BufferSupLL[i] = EMPTY_VALUE;
         BufferResTrail[i] = EMPTY_VALUE;
         BufferSupTrail[i] = EMPTY_VALUE;
         continue;
      }

      double hh = BufferMAUpper[from];
      double ll = BufferMALower[from];
      double price = close[i];
      bool trail_res_found = false;
      bool trail_sup_found = false;
      double trail_res = 0.0;
      double trail_sup = 0.0;

      for(int j=from; j<=i; j++)
      {
         double upper = BufferMAUpper[j];
         double lower = BufferMALower[j];

         if(upper > hh) hh = upper;
         if(lower < ll) ll = lower;

         if(upper >= price)
         {
            if(!trail_res_found || upper < trail_res)
            {
               trail_res = upper;
               trail_res_found = true;
            }
         }

         if(lower <= price)
         {
            if(!trail_sup_found || lower > trail_sup)
            {
               trail_sup = lower;
               trail_sup_found = true;
            }
         }
      }

      BufferResHH[i] = NormalizeDouble(hh, _Digits);
      BufferSupLL[i] = NormalizeDouble(ll, _Digits);
      BufferResTrail[i] = trail_res_found ? NormalizeDouble(trail_res, _Digits) : EMPTY_VALUE;
      BufferSupTrail[i] = trail_sup_found ? NormalizeDouble(trail_sup, _Digits) : EMPTY_VALUE;
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
