//+------------------------------------------------------------------+
//|                                     Stochastic_Structure_GPT.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   1

//--- plot de la estructura (ZigZag)
#property indicator_label1  "Stoch Estructura"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

input int InpKPeriod   = 5;   // K Period
input int InpDPeriod   = 3;   // D Period
input int InpSlowing   = 3;   // Slowing
input ENUM_STO_PRICE InpPriceMode = STO_LOWHIGH;

//--- buffers para el cálculo del estocástico
double ExtMainBuffer[];       // %K
double ExtSignalBuffer[];     // %D
double ExtHighesBuffer[];     // Highs para cálculo
double ExtLowesBuffer[];      // Lows para cálculo

//--- buffer para la estructura (ZigZag estructural)
//--- buffers para extremos
double StructBuffer[];     // ZigZag visual
double PeakBuffer[];       // Solo PEAKs validados
double BottomBuffer[];     // Solo BOTTOMs validados
double StochExtBuffer[];

// STATIC BUFFERS
double StructStateBuffer[];
double ZoneIsActive[];
double LastExtremumIndex[];
double ExtremumIndex[];
double ExtremumPrice[];

int OnInit()
{
  SetIndexBuffer(0, StructBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, PeakBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(2, BottomBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(3, StochExtBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(4, ExtMainBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(5, ExtSignalBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(6, ExtHighesBuffer,INDICATOR_CALCULATIONS);
  SetIndexBuffer(7, ExtLowesBuffer,INDICATOR_CALCULATIONS);

  // STATIC BUFFERS
  SetIndexBuffer(8, StructStateBuffer,INDICATOR_CALCULATIONS);
  SetIndexBuffer(9, ZoneIsActive,INDICATOR_CALCULATIONS);
  SetIndexBuffer(10, LastExtremumIndex,INDICATOR_CALCULATIONS);
  SetIndexBuffer(11, ExtremumIndex,INDICATOR_CALCULATIONS);
  SetIndexBuffer(12, ExtremumPrice,INDICATOR_CALCULATIONS);


  // Solo el primer plot (StructBuffer) se dibuja
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpKPeriod + InpSlowing + InpDPeriod);

  //--- nombre del indicador y etiqueta
  string short_name = StringFormat("Stoch Struct(%d,%d,%d)", InpKPeriod, InpDPeriod, InpSlowing);
  IndicatorSetString(INDICATOR_SHORTNAME, short_name);
  PlotIndexSetString(0, PLOT_LABEL, "Estructura Estocástica");

  //--- configuramos valores vacíos
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

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
  int i,k,start;
//--- check for bars count
  if(rates_total<=InpKPeriod+InpDPeriod+InpSlowing)
    return(0);

  if(prev_calculated==0)
    {
      // BUFFERS
      ArrayInitialize(StructBuffer, EMPTY_VALUE);
      ArrayInitialize(PeakBuffer, -DBL_MAX);
      ArrayInitialize(BottomBuffer, DBL_MAX);
      ArrayInitialize(StochExtBuffer, EMPTY_VALUE);

      // STATIC BUFFERS
      ArrayInitialize(StructStateBuffer, EMPTY_VALUE);
      ArrayInitialize(ZoneIsActive, 0);
      ArrayInitialize(LastExtremumIndex, EMPTY_VALUE);
      ArrayInitialize(ExtremumIndex, EMPTY_VALUE);
      ArrayInitialize(ExtremumPrice, EMPTY_VALUE);
    }
//---
  start=InpKPeriod-1;
  if(start+1<prev_calculated)
    start=prev_calculated-2;
  else
    {
    for(i=0; i<start; i++)
      {
        ExtLowesBuffer[i]=0.0;
        ExtHighesBuffer[i]=0.0;
      }
    }
//--- calculate HighesBuffer[] and ExtHighesBuffer[]
  for(i=start; i<rates_total && !IsStopped(); i++)
  {
    double dmin=1000000.0;
    double dmax=-1000000.0;
    for(k=i-InpKPeriod+1; k<=i; k++)
    {
        if(InpPriceMode == STO_LOWHIGH)
        {
          if(dmin > low[k])
              dmin = low[k];
          if(dmax < high[k])
              dmax = high[k];
        }
        else // STO_PRICE_CLOSE
        {
          if(dmin > close[k])
              dmin = close[k];
          if(dmax < close[k])
              dmax = close[k];
        }
    }
    ExtLowesBuffer[i]=dmin;
    ExtHighesBuffer[i]=dmax;
  }
//--- %K
  start=InpKPeriod-1+InpSlowing-1;
  if(start+1<prev_calculated)
    start=prev_calculated-2;
  else
    {
    for(i=0; i<start; i++)
        ExtMainBuffer[i]=0.0;
    }
//--- main cycle
  for(i=start; i<rates_total && !IsStopped(); i++)
    {
    double sum_low=0.0;
    double sum_high=0.0;
    for(k=(i-InpSlowing+1); k<=i; k++)
      {
        sum_low +=(close[k]-ExtLowesBuffer[k]);
        sum_high+=(ExtHighesBuffer[k]-ExtLowesBuffer[k]);
      }
    if(sum_high==0.0)
        ExtMainBuffer[i]=100.0;
    else
        ExtMainBuffer[i]=sum_low/sum_high*100;
    }
//--- signal
  start=InpDPeriod-1;
  if(start+1<prev_calculated)
    start=prev_calculated-2;
  else
    {
    for(i=0; i<start; i++)
        ExtSignalBuffer[i]=0.0;
    }
  for(i=start; i<rates_total && !IsStopped(); i++)
    {
      StructBuffer[i]   = EMPTY_VALUE;
      PeakBuffer[i]     = -DBL_MAX;
      BottomBuffer[i]   = DBL_MAX;
      StochExtBuffer[i] = EMPTY_VALUE;

      double sum=0.0;
      for(k=0; k<InpDPeriod; k++)
          sum+=ExtMainBuffer[i-k];
      ExtSignalBuffer[i]=sum/InpDPeriod;
    }

  //--- variables estáticas para seguimiento estructural
  //static int    estado_estructura   = -1; // -1: sin definir, 0: esperando PEAK, 1: esperando BOTTOM
  //static bool   zona_activa         = false;
  //static int    index_extremo       = -1;
  //static double precio_extremo      = 0.0;
  double stoch_max                  = -DBL_MAX;
  double stoch_min                  = DBL_MAX;
  double last_extremum_peak         = -DBL_MAX;
  double last_extremum_bottom       = DBL_MAX;
  int    last_extremum_peak_index   = -1;
  int    last_extremum_bottom_index = -1;

  double last_extremum_index = LastExtremumIndex[rates_total-1];

  // RESET LAST BUFFERS TO NOT REPAIN
  /*
  for(int i = (int)last_extremum_index; i < rates_total-1 && last_extremum_index != EMPTY_VALUE; i++)
  {
    double stoch = NormalizeDouble(ExtMainBuffer[i], 2);
    double estado_estructura = StructStateBuffer[i];

    // LOOKING PEAK WE GET THE MAX STOCH FROM LAST BOTTOM INDEX
    if(estado_estructura == 0)
    {
      if(stoch   > stoch_max)            stoch_max          = stoch;
      if(high[i] > last_extremum_peak) { last_extremum_peak = high[i]; last_extremum_peak_index = i; }
    }
    // LOOKING BOTTOM WE GET THE MIN STOCH FROM LAST PEAK INDEX
    if(estado_estructura == 1)
    {
      if(stoch  < stoch_min)              stoch_min            = stoch;
      if(low[i] < last_extremum_bottom) { last_extremum_bottom = low[i]; last_extremum_bottom_index = i; }
    }
  }
  */

  for(int i = start; i < rates_total-1; i++)
  {
    double stoch = NormalizeDouble(ExtMainBuffer[i], 2);
    double ultimo_peak         = -DBL_MAX;
    double ultimo_bottom       = DBL_MAX;
    int    ultimo_peak_index   = -1;
    int    ultimo_bottom_index = -1;
    bool   found_peak          = false;
    bool   found_bottom        = false;

    // STATIC BUFFERS
    int    static_index      = i == 0 ? i : i-1;
    double estado_estructura = StructStateBuffer[static_index];
    int    l_extremum_index  = (int)LastExtremumIndex[static_index];
    bool   zona_activa       = (bool)ZoneIsActive[static_index];
    double precio_extremo    = ExtremumPrice[static_index];
    int    index_extremo     = (int)ExtremumIndex[static_index];

    // SIEMPRE ACTUALIZAMOS ALTOS/BAJOS
    if(high[i] > ultimo_peak)   { ultimo_peak   = high[i]; ultimo_peak_index   = i; }
    if(low[i]  < ultimo_bottom) { ultimo_bottom = low[i];  ultimo_bottom_index = i; }

    if(estado_estructura == 0 || estado_estructura == EMPTY_VALUE) // Esperando PEAK (estructura previa fue BOTTOM o inciamos con BOTTOM)
    {
      if(stoch > 80)
      {
        if(!zona_activa)
        {
          zona_activa    = true;
          index_extremo  = ultimo_peak_index;
          precio_extremo = ultimo_peak;
          PeakBuffer[index_extremo] = precio_extremo;
        }
        else if(ultimo_peak > PeakBuffer[index_extremo])
        {
          index_extremo  = ultimo_peak_index;
          precio_extremo = ultimo_peak;
          PeakBuffer[index_extremo] = precio_extremo;
        }
        // MAX STOCH VALUE REACHED
        if(stoch > stoch_max) stoch_max = stoch;
      }
      else if(zona_activa && stoch <= 80)
      {
        if(ultimo_peak > PeakBuffer[index_extremo])
        {
          precio_extremo = ultimo_peak;
          index_extremo  = ultimo_peak_index;
          PeakBuffer[index_extremo] = precio_extremo;
        }

        // ESPERAMOS BAJOS CONGRUENTES (ALTO MAS ALTO QUE EL BAJO)
        if(PeakBuffer[index_extremo] > ultimo_bottom && stoch < 20)
        {
          // SOLO CAMBIAMOS DE SECUENCIA AL ENCONTRAR UN BAJO
          found_bottom                  = true;
          StructBuffer[index_extremo]   = PeakBuffer[index_extremo];
          StochExtBuffer[index_extremo] = stoch_max;
          stoch_max                     = -DBL_MAX;

          // SETEAMOS EL BOTTOM CORRESPONDIENTE
          estado_estructura           = 1;
          zona_activa                 = true;
          l_extremum_index            = index_extremo;
          index_extremo               = ultimo_bottom_index;
          precio_extremo              = ultimo_bottom;
          stoch_min                   = stoch;
          BottomBuffer[index_extremo] = precio_extremo;
        }
      }

      // UPDATES STATIC BUFFERS
      StructStateBuffer[i] = estado_estructura;
      ZoneIsActive[i]      = zona_activa;
      LastExtremumIndex[i] = l_extremum_index;
      ExtremumIndex[i]     = index_extremo;
      ExtremumPrice[i]     = precio_extremo;
      if(found_bottom) continue;
    }
    else if(estado_estructura == 1 || estado_estructura == EMPTY_VALUE) // Esperando BOTTOM (estructura previa fue PEAK o inciamos con BOTTOM)
    {
      if(stoch < 20)
      {
        if(!zona_activa)
        {
          zona_activa    = true;
          index_extremo  = ultimo_bottom_index;
          precio_extremo = ultimo_bottom;
          BottomBuffer[index_extremo] = precio_extremo;
        }
        else if(ultimo_bottom < BottomBuffer[index_extremo])
        {
          index_extremo  = ultimo_bottom_index;
          precio_extremo = ultimo_bottom;
          BottomBuffer[index_extremo] = precio_extremo;
        }
        // MAX STOCH VALUE REACHED
        if(stoch < stoch_min) stoch_min = stoch;
      }
      else if(zona_activa && stoch >= 20)
      {
        if(ultimo_bottom < BottomBuffer[index_extremo])
        {
          precio_extremo = ultimo_bottom;
          index_extremo  = ultimo_bottom_index;
          BottomBuffer[index_extremo] = precio_extremo;
        }

        // ESPERAMOS ALTOS CONGRUENTES (BAJO MAS BAJO QUE EL ALTO)
        if(BottomBuffer[index_extremo] < ultimo_peak && stoch > 80)
        {
          // SOLO CAMBIAMOS DE SECUENCIA AL ENCONTRAR UN ALTO
          found_peak                    = true;
          StructBuffer[index_extremo]   = precio_extremo;
          StochExtBuffer[index_extremo] = stoch_min;
          stoch_min                     = DBL_MAX;

          // SETEAMOS NUESTRO PEAK CORRESPONDIENTE
          estado_estructura         = 0;
          zona_activa               = true;
          l_extremum_index          = index_extremo;
          index_extremo             = ultimo_peak_index;
          precio_extremo            = ultimo_peak;
          stoch_max                 = stoch;
          PeakBuffer[index_extremo] = precio_extremo;
        }
      }

      // UPDATES STATIC BUFFERS
      StructStateBuffer[i] = estado_estructura;
      ZoneIsActive[i]      = zona_activa;
      LastExtremumIndex[i] = l_extremum_index;
      ExtremumIndex[i]     = index_extremo;
      ExtremumPrice[i]     = precio_extremo;
      if(found_peak) continue;
    }
  }

  return(rates_total);
}
