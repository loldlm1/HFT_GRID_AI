//+------------------------------------------------------------------+
//|                                           MACD_Structure_GPT.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright @loldlm"
#property link      "https://t.me/loldlm"
#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   1

//--- plot de la estructura (ZigZag)
#property indicator_label1  "MACD Estructura"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MovingAverages.mqh>

enum ENUM_MACD_STRUCT_LOGIC {
   MACD_LOGIC_CROSS,      // Signal Line Cross
   MACD_LOGIC_NORMALIZED  // Normalized Range (0-100)
};

input int                  InpFastPeriod     = 5;
input int                  InpSlowPeriod     = 34;
input int                  InpSignalPeriod   = 5;
input ENUM_APPLIED_PRICE   InpAppliedPrice   = PRICE_WEIGHTED;
input ENUM_MA_METHOD       InpMAMethod       = MODE_EMA;
input ENUM_MACD_STRUCT_LOGIC InpLogicMode    = MACD_LOGIC_CROSS;
input int                  InpNormPeriod     = 89; // Lookback for normalization
input double               InpOverbought     = 80.0;
input double               InpOversold       = 20.0;

//--- buffers
double StructBuffer[];     // ZigZag visual
double PeakBuffer[];       // Solo PEAKs validados
double BottomBuffer[];     // Solo BOTTOMs validados
double MacdExtBuffer[];    // Valor MACD en el extremo

// MACD Calculation Buffers
double MacdBuffer[];
double SignalBuffer[];
double FastMaBuffer[];
double SlowMaBuffer[];
double ExtPriceBuffer[];

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
  SetIndexBuffer(3, MacdExtBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(4, MacdBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(5, SignalBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(6, FastMaBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(7, SlowMaBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(8, ExtPriceBuffer, INDICATOR_CALCULATIONS);

  // STATIC BUFFERS
  SetIndexBuffer(9, StructStateBuffer, INDICATOR_CALCULATIONS);
  SetIndexBuffer(10, ZoneIsActive, INDICATOR_CALCULATIONS);
  SetIndexBuffer(11, LastExtremumIndex, INDICATOR_CALCULATIONS);
  SetIndexBuffer(12, ExtremumIndex, INDICATOR_CALCULATIONS);
  SetIndexBuffer(13, ExtremumPrice, INDICATOR_CALCULATIONS);

  // Solo el primer plot (StructBuffer) se dibuja
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpSlowPeriod + InpSignalPeriod);

  //--- nombre del indicador y etiqueta
  string short_name = StringFormat("MACD Struct(%d,%d,%d)", InpFastPeriod, InpSlowPeriod, InpSignalPeriod);
  IndicatorSetString(INDICATOR_SHORTNAME, short_name);
  PlotIndexSetString(0, PLOT_LABEL, "Estructura MACD");

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
  if(rates_total <= InpSlowPeriod + InpSignalPeriod)
    return(0);

  if(prev_calculated == 0)
  {
     ArrayInitialize(StructBuffer, EMPTY_VALUE);
     ArrayInitialize(PeakBuffer, -DBL_MAX);
     ArrayInitialize(BottomBuffer, DBL_MAX);
     ArrayInitialize(MacdExtBuffer, EMPTY_VALUE);

     ArrayInitialize(MacdBuffer, 0.0);
     ArrayInitialize(SignalBuffer, 0.0);
     ArrayInitialize(FastMaBuffer, 0.0);
     ArrayInitialize(SlowMaBuffer, 0.0);
     ArrayInitialize(ExtPriceBuffer, 0.0);

     ArrayInitialize(StructStateBuffer, EMPTY_VALUE);
     ArrayInitialize(ZoneIsActive, 0);
     ArrayInitialize(LastExtremumIndex, EMPTY_VALUE);
     ArrayInitialize(ExtremumIndex, EMPTY_VALUE);
     ArrayInitialize(ExtremumPrice, EMPTY_VALUE);
  }

  int start = prev_calculated - 1;
  if(start < 0) start = 0;

  // 1. Calculate Price Buffer
  int price_start = start;
  if(price_start > 0) price_start--; // Recalculate last bar just in case

  for(int i = price_start; i < rates_total; i++)
  {
     switch(InpAppliedPrice)
     {
        case PRICE_CLOSE: ExtPriceBuffer[i] = close[i]; break;
        case PRICE_OPEN:  ExtPriceBuffer[i] = open[i]; break;
        case PRICE_HIGH:  ExtPriceBuffer[i] = high[i]; break;
        case PRICE_LOW:   ExtPriceBuffer[i] = low[i]; break;
        case PRICE_MEDIAN: ExtPriceBuffer[i] = (high[i] + low[i]) / 2.0; break;
        case PRICE_TYPICAL: ExtPriceBuffer[i] = (high[i] + low[i] + close[i]) / 3.0; break;
        case PRICE_WEIGHTED: ExtPriceBuffer[i] = (high[i] + low[i] + close[i] + close[i]) / 4.0; break;
        default: ExtPriceBuffer[i] = close[i]; break;
     }
  }

  // 2. Calculate Fast MA
  switch(InpMAMethod)
  {
     case MODE_SMA:  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, ExtPriceBuffer, FastMaBuffer); break;
     case MODE_EMA:  ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, ExtPriceBuffer, FastMaBuffer); break;
     case MODE_SMMA: SmoothedMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, ExtPriceBuffer, FastMaBuffer); break;
     case MODE_LWMA: LinearWeightedMAOnBuffer(rates_total, prev_calculated, 0, InpFastPeriod, ExtPriceBuffer, FastMaBuffer); break;
  }

  // 3. Calculate Slow MA
  switch(InpMAMethod)
  {
     case MODE_SMA:  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, ExtPriceBuffer, SlowMaBuffer); break;
     case MODE_EMA:  ExponentialMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, ExtPriceBuffer, SlowMaBuffer); break;
     case MODE_SMMA: SmoothedMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, ExtPriceBuffer, SlowMaBuffer); break;
     case MODE_LWMA: LinearWeightedMAOnBuffer(rates_total, prev_calculated, 0, InpSlowPeriod, ExtPriceBuffer, SlowMaBuffer); break;
  }

  // 4. Calculate MACD Buffer
  int macd_start = start;
  if(macd_start < InpSlowPeriod) macd_start = InpSlowPeriod;

  for(int i = macd_start; i < rates_total; i++)
  {
     MacdBuffer[i] = FastMaBuffer[i] - SlowMaBuffer[i];
  }

  // 5. Calculate Signal Line (SMA of MACD)
  SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSignalPeriod, MacdBuffer, SignalBuffer);

  // 6. Structure Logic

  // Prepare loop variables
  double stoch_max                  = -DBL_MAX;
  double stoch_min                  = DBL_MAX;
  // Note: We use 'stoch_max/min' naming to keep consistency with logic source,
  // but these represent MACD values (or normalized MACD).

  int struct_loop_start = start;
  if(struct_loop_start < InpSlowPeriod + InpSignalPeriod) struct_loop_start = InpSlowPeriod + InpSignalPeriod;

  // Adjust start to not overwrite history if not needed, but ensure continuity
  if(prev_calculated > 0) struct_loop_start = prev_calculated - 1;

  for(int i = struct_loop_start; i < rates_total - 1; i++)
  {
     // --- Logic for Zones ---
     bool is_hunting_peak = false;
     bool is_hunting_bottom = false;
     double current_value_for_ext = MacdBuffer[i]; // Value to store in MacdExtBuffer

     if(InpLogicMode == MACD_LOGIC_CROSS)
     {
        if(MacdBuffer[i] > SignalBuffer[i]) is_hunting_peak = true;
        if(MacdBuffer[i] < SignalBuffer[i]) is_hunting_bottom = true;
     }
     else if(InpLogicMode == MACD_LOGIC_NORMALIZED)
     {
        // Normalize MACD
        double min_val = DBL_MAX;
        double max_val = -DBL_MAX;
        int lookback_start = i - InpNormPeriod + 1;
        if(lookback_start < 0) lookback_start = 0;

        for(int k = lookback_start; k <= i; k++)
        {
           if(MacdBuffer[k] < min_val) min_val = MacdBuffer[k];
           if(MacdBuffer[k] > max_val) max_val = MacdBuffer[k];
        }

        double range = max_val - min_val;
        double normalized = 50.0; // Default mid
        if(range != 0)
           normalized = (MacdBuffer[i] - min_val) / range * 100.0;

        current_value_for_ext = normalized; // Store normalized value? Or raw?
        // Stoch struct stores Stoch value (0-100). So here we store Normalized.

        if(normalized > InpOverbought) is_hunting_peak = true;
        if(normalized < InpOversold) is_hunting_bottom = true;
     }

     // --- ZigZag State Machine (Ported from Stoch_Structure) ---

     double ultimo_peak         = -DBL_MAX;
     double ultimo_bottom       = DBL_MAX;
     int    ultimo_peak_index   = -1;
     int    ultimo_bottom_index = -1;
     bool   found_peak          = false;
     bool   found_bottom        = false;

     // Initialize from previous state
     int    static_index      = i == 0 ? i : i - 1;
     double estado_estructura = StructStateBuffer[static_index];
     int    l_extremum_index  = (int)LastExtremumIndex[static_index];
     bool   zona_activa       = (bool)ZoneIsActive[static_index];
     double precio_extremo    = ExtremumPrice[static_index];
     int    index_extremo     = (int)ExtremumIndex[static_index];

     // SIEMPRE ACTUALIZAMOS ALTOS/BAJOS
     if(high[i] > ultimo_peak)   { ultimo_peak   = high[i]; ultimo_peak_index   = i; }
     if(low[i]  < ultimo_bottom) { ultimo_bottom = low[i];  ultimo_bottom_index = i; }

     // Use tracked max/min for MACD value within the swing
     // Note: In the loop, stoch_max/min logic in original code was inside the if blocks
     // We need to maintain local max/min for the current swing if we are traversing bars
     // But here we process one bar 'i'. The original code had a bug/feature where stoch_max was reset
     // locally inside the loop. We need to ensure stoch_max/min persists if we are in a swing.
     // However, the original code reset stoch_max = -DBL_MAX when a bottom was found.
     // We need to check if we need static storage for stoch_max/min if we were doing tick-by-tick
     // But here we recalculate history on every tick usually? No, we use prev_calculated.
     // So we need to store current swing max/min in a buffer?
     // The original code didn't store stoch_max/min in a buffer!
     // It seems the original code relied on re-scanning or just current loop scope variables which is risky for incremental calculation.
     // Looking at original code:
     // double stoch_max = -DBL_MAX; initialized at start of OnCalculate.
     // This means it resets every time OnCalculate runs?
     // If OnCalculate runs for only new bars (prev_calculated > 0), stoch_max is -DBL_MAX.
     // This implies the stoch_max finding logic in original code is BROKEN for incremental calculation
     // unless it re-scans the current swing.
     // OR, the logic is: when a new peak is found, we just take the current bar's stoch if it's higher.
     // But if we process bar N, and peak was at N-5, we don't know the max stoch of N-5...N without storage.
     // However, we will follow the original code structure strictly as requested ("clone this stoch structure indicator logic").
     // The original code logic:
     // if(stoch > stoch_max) stoch_max = stoch;
     // This variable is local to OnCalculate.
     // If we start from prev_calculated, 'stoch_max' starts at -DBL_MAX.
     // This effectively means for the current *active* swing calculation on the new bar, it only considers the NEW bar's stoch value against -DBL_MAX.
     // It does not remember the max stoch of the *previous* bars in the same swing if they were processed in a previous OnCalculate call.
     // This looks like a bug in the original indicator, but I must follow instructions.
     // "clone this stoch structure indicator logic"
     // I will preserve the logic.

     if(estado_estructura == 0 || estado_estructura == EMPTY_VALUE) // Esperando PEAK
     {
        if(is_hunting_peak)
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
           if(current_value_for_ext > stoch_max) stoch_max = current_value_for_ext;
        }
        else if(zona_activa && !is_hunting_peak) // Exited zone
        {
           if(ultimo_peak > PeakBuffer[index_extremo])
           {
              precio_extremo = ultimo_peak;
              index_extremo  = ultimo_peak_index;
              PeakBuffer[index_extremo] = precio_extremo;
           }

           // Confirm Peak if we find a Bottom logic condition (or similar 'valid low' check)
           // Original: if(PeakBuffer[index_extremo] > ultimo_bottom && stoch < 20)
           // Here: if(PeakBuffer... && is_hunting_bottom)

           if(PeakBuffer[index_extremo] > ultimo_bottom && is_hunting_bottom)
           {
              found_bottom                  = true;
              StructBuffer[index_extremo]   = PeakBuffer[index_extremo];
              MacdExtBuffer[index_extremo]  = stoch_max; // Value at the peak (or max value seen)
              stoch_max                     = -DBL_MAX;

              estado_estructura           = 1;
              zona_activa                 = true;
              l_extremum_index            = index_extremo;
              index_extremo               = ultimo_bottom_index;
              precio_extremo              = ultimo_bottom;
              // stoch_min should be tracked for the new bottom search?
              // In original: stoch_min = stoch;
              stoch_min                   = current_value_for_ext;
              BottomBuffer[index_extremo] = precio_extremo;
           }
        }

        // UPDATE STATIC BUFFERS
        StructStateBuffer[i] = estado_estructura;
        ZoneIsActive[i]      = zona_activa;
        LastExtremumIndex[i] = l_extremum_index;
        ExtremumIndex[i]     = index_extremo;
        ExtremumPrice[i]     = precio_extremo;
        if(found_bottom) continue;
     }
     else if(estado_estructura == 1 || estado_estructura == EMPTY_VALUE) // Esperando BOTTOM
     {
        if(is_hunting_bottom)
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
           if(current_value_for_ext < stoch_min) stoch_min = current_value_for_ext;
        }
        else if(zona_activa && !is_hunting_bottom)
        {
           if(ultimo_bottom < BottomBuffer[index_extremo])
           {
              precio_extremo = ultimo_bottom;
              index_extremo  = ultimo_bottom_index;
              BottomBuffer[index_extremo] = precio_extremo;
           }

           if(BottomBuffer[index_extremo] < ultimo_peak && is_hunting_peak)
           {
              found_peak                    = true;
              StructBuffer[index_extremo]   = precio_extremo;
              MacdExtBuffer[index_extremo]  = stoch_min;
              stoch_min                     = DBL_MAX;

              estado_estructura         = 0;
              zona_activa               = true;
              l_extremum_index          = index_extremo;
              index_extremo             = ultimo_peak_index;
              precio_extremo            = ultimo_peak;
              stoch_max                 = current_value_for_ext;
              PeakBuffer[index_extremo] = precio_extremo;
           }
        }

        // UPDATE STATIC BUFFERS
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
