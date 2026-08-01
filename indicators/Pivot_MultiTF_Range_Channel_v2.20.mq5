//+------------------------------------------------------------------+
//|                              Pivot Multi-TF Range Channel.mq5     |
//| Based on the MetaQuotes "Pivot Channel" indicator sample.       |
//| Shows only the latest closed-candle pivots for three TFs.        |
//+------------------------------------------------------------------+
#property copyright   "2000-2026, MetaQuotes Ltd.; customized version"
#property link        "https://www.mql5.com"
#property version     "2.20"
#property description "Current-only multi-timeframe pivots with tested-level macro direction markers"

#property indicator_chart_window
#property indicator_buffers 75
#property indicator_plots   75

input group "Daily display window (broker server time)"
input int InpRangeStartHour   = 12; // Display start hour
input int InpRangeStartMinute = 30; // Display start minute
input int InpRangeEndHour     = 14; // Display end hour
input int InpRangeEndMinute   = 30; // Display end minute

input group "Pivot candle timeframes"
input ENUM_TIMEFRAMES InpPivotTF1 = PERIOD_M30;
input ENUM_TIMEFRAMES InpPivotTF2 = PERIOD_H1;
input ENUM_TIMEFRAMES InpPivotTF3 = PERIOD_H4;

input group "Visible history and levels"
input int  InpMaxDays     = 10;   // 0 = all loaded chart history
input int  InpMaxSRLevel  = 3;    // 0=PP only, 1-10=R/S depth
input bool InpShowLevelsM = false;// Show intermediate M1-M4
input bool InpShowLabels  = true; // Show TF + pivot type for current levels

input group "Line appearance"
input color InpColorPP = clrDodgerBlue;
input color InpColorR1 = clrLightCoral;
input color InpColorR2 = clrOrangeRed;
input color InpColorR3 = clrCrimson;
input color InpColorS1 = clrMediumAquamarine;
input color InpColorS2 = clrSeaGreen;
input color InpColorS3 = clrDarkGreen;
input color InpColorM  = clrGold;
input int   InpLineWidth = 1; // 1-5

#define TF_COUNT     3
#define LEVEL_COUNT 25

// Level indexes inside each timeframe block.
#define LEVEL_PP  0
#define LEVEL_R1  1
#define LEVEL_R10 10
#define LEVEL_S1  11
#define LEVEL_S10 20
#define LEVEL_M1  21
#define LEVEL_M4  24

//--- TF1 indicator buffers
double ExtTF1PPBuffer[];
double ExtTF1R1Buffer[];
double ExtTF1R2Buffer[];
double ExtTF1R3Buffer[];
double ExtTF1R4Buffer[];
double ExtTF1R5Buffer[];
double ExtTF1R6Buffer[];
double ExtTF1R7Buffer[];
double ExtTF1R8Buffer[];
double ExtTF1R9Buffer[];
double ExtTF1R10Buffer[];
double ExtTF1S1Buffer[];
double ExtTF1S2Buffer[];
double ExtTF1S3Buffer[];
double ExtTF1S4Buffer[];
double ExtTF1S5Buffer[];
double ExtTF1S6Buffer[];
double ExtTF1S7Buffer[];
double ExtTF1S8Buffer[];
double ExtTF1S9Buffer[];
double ExtTF1S10Buffer[];
double ExtTF1M1Buffer[];
double ExtTF1M2Buffer[];
double ExtTF1M3Buffer[];
double ExtTF1M4Buffer[];

//--- TF2 indicator buffers
double ExtTF2PPBuffer[];
double ExtTF2R1Buffer[];
double ExtTF2R2Buffer[];
double ExtTF2R3Buffer[];
double ExtTF2R4Buffer[];
double ExtTF2R5Buffer[];
double ExtTF2R6Buffer[];
double ExtTF2R7Buffer[];
double ExtTF2R8Buffer[];
double ExtTF2R9Buffer[];
double ExtTF2R10Buffer[];
double ExtTF2S1Buffer[];
double ExtTF2S2Buffer[];
double ExtTF2S3Buffer[];
double ExtTF2S4Buffer[];
double ExtTF2S5Buffer[];
double ExtTF2S6Buffer[];
double ExtTF2S7Buffer[];
double ExtTF2S8Buffer[];
double ExtTF2S9Buffer[];
double ExtTF2S10Buffer[];
double ExtTF2M1Buffer[];
double ExtTF2M2Buffer[];
double ExtTF2M3Buffer[];
double ExtTF2M4Buffer[];

//--- TF3 indicator buffers
double ExtTF3PPBuffer[];
double ExtTF3R1Buffer[];
double ExtTF3R2Buffer[];
double ExtTF3R3Buffer[];
double ExtTF3R4Buffer[];
double ExtTF3R5Buffer[];
double ExtTF3R6Buffer[];
double ExtTF3R7Buffer[];
double ExtTF3R8Buffer[];
double ExtTF3R9Buffer[];
double ExtTF3R10Buffer[];
double ExtTF3S1Buffer[];
double ExtTF3S2Buffer[];
double ExtTF3S3Buffer[];
double ExtTF3S4Buffer[];
double ExtTF3S5Buffer[];
double ExtTF3S6Buffer[];
double ExtTF3S7Buffer[];
double ExtTF3S8Buffer[];
double ExtTF3S9Buffer[];
double ExtTF3S10Buffer[];
double ExtTF3M1Buffer[];
double ExtTF3M2Buffer[];
double ExtTF3M3Buffer[];
double ExtTF3M4Buffer[];

//--- normalized inputs and timeframe state
int ExtRangeStartSeconds = 0;
int ExtRangeEndSeconds   = 0;
int ExtRangeDuration     = 0;

ENUM_TIMEFRAMES ExtTF[TF_COUNT];
int             ExtTFSeconds[TF_COUNT];
string          ExtTFName[TF_COUNT];
datetime        ExtNextRefresh[TF_COUNT];
datetime        ExtLoadedFrom[TF_COUNT];
bool            ExtRatesReady[TF_COUNT];

MqlRates ExtRatesTF1[];
MqlRates ExtRatesTF2[];
MqlRates ExtRatesTF3[];

string   ExtPrefixUniq;
long     ExtChartScale    = 2;
bool     ExtLabelsShown   = false;
datetime ExtLastLabelTime = 0;
datetime ExtLabelSession = 0;
datetime ExtLastLabelSourceOpen[TF_COUNT];
bool     ExtCopyPending   = false;
datetime ExtNextCopyError = 0;
datetime ExtLastCalculatedSession = 0;

struct SPivotLevels
  {
   double value[LEVEL_COUNT];
  };

#define TEST_NONE     0
#define TEST_BULLISH  1
#define TEST_BEARISH -1

struct SPivotSnapshot
  {
   bool     valid;
   datetime source_open;
   datetime activation_time;
   double   reference_close;
   double   value[LEVEL_COUNT];
   bool     tested[LEVEL_COUNT];
  };

SPivotSnapshot ExtLiveSnapshot[TF_COUNT];
ulong          ExtLastLabelTestMask[TF_COUNT];
string         ExtCurrentLabelPrefix;
string         ExtTestPrefix;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   // A chart period longer than the display window can skip the empty
   // interval and visually connect independent daily sessions.
   if(PeriodSeconds() > ExtRangeDuration)
     {
      Alert("Chart timeframe must be equal to or shorter than the display-window duration.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   ExtTF[0] = NormalizeTimeframe(InpPivotTF1);
   ExtTF[1] = NormalizeTimeframe(InpPivotTF2);
   ExtTF[2] = NormalizeTimeframe(InpPivotTF3);

   for(int slot = 0; slot < TF_COUNT; slot++)
     {
      ExtTFSeconds[slot] = PeriodSeconds(ExtTF[slot]);
      if(ExtTFSeconds[slot] <= 0)
        {
         Alert(StringFormat("Invalid pivot timeframe in TF%d.", slot + 1));
         return(INIT_PARAMETERS_INCORRECT);
        }

      // The close-time test uses the fixed duration returned by
      // PeriodSeconds(), so this implementation intentionally supports
      // intraday periods and D1, not calendar-variable monthly candles.
      if(ExtTFSeconds[slot] > PeriodSeconds(PERIOD_D1))
        {
         Alert(StringFormat("TF%d must be D1 or lower.", slot + 1));
         return(INIT_PARAMETERS_INCORRECT);
        }

      ExtTFName[slot]     = TimeframeName(ExtTF[slot]);
      ExtNextRefresh[slot]= 0;
      ExtLoadedFrom[slot] = 0;
      ExtRatesReady[slot] = false;
      ExtLastLabelSourceOpen[slot] = 0;
      ExtLastLabelTestMask[slot]   = 0;
      ResetSnapshot(ExtLiveSnapshot[slot]);
     }

   for(int left = 0; left < TF_COUNT; left++)
      for(int right = left + 1; right < TF_COUNT; right++)
         if(ExtTF[left] == ExtTF[right])
            Print("Warning: TF", left + 1, " and TF", right + 1,
                  " use the same timeframe ", ExtTFName[left], ".");


   SetIndexBuffer(0, ExtTF1PPBuffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1PPBuffer, false);
   SetIndexBuffer(1, ExtTF1R1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R1Buffer, false);
   SetIndexBuffer(2, ExtTF1R2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R2Buffer, false);
   SetIndexBuffer(3, ExtTF1R3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R3Buffer, false);
   SetIndexBuffer(4, ExtTF1R4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R4Buffer, false);
   SetIndexBuffer(5, ExtTF1R5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R5Buffer, false);
   SetIndexBuffer(6, ExtTF1R6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R6Buffer, false);
   SetIndexBuffer(7, ExtTF1R7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R7Buffer, false);
   SetIndexBuffer(8, ExtTF1R8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R8Buffer, false);
   SetIndexBuffer(9, ExtTF1R9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R9Buffer, false);
   SetIndexBuffer(10, ExtTF1R10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1R10Buffer, false);
   SetIndexBuffer(11, ExtTF1S1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S1Buffer, false);
   SetIndexBuffer(12, ExtTF1S2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S2Buffer, false);
   SetIndexBuffer(13, ExtTF1S3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S3Buffer, false);
   SetIndexBuffer(14, ExtTF1S4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S4Buffer, false);
   SetIndexBuffer(15, ExtTF1S5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S5Buffer, false);
   SetIndexBuffer(16, ExtTF1S6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S6Buffer, false);
   SetIndexBuffer(17, ExtTF1S7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S7Buffer, false);
   SetIndexBuffer(18, ExtTF1S8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S8Buffer, false);
   SetIndexBuffer(19, ExtTF1S9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S9Buffer, false);
   SetIndexBuffer(20, ExtTF1S10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1S10Buffer, false);
   SetIndexBuffer(21, ExtTF1M1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1M1Buffer, false);
   SetIndexBuffer(22, ExtTF1M2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1M2Buffer, false);
   SetIndexBuffer(23, ExtTF1M3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1M3Buffer, false);
   SetIndexBuffer(24, ExtTF1M4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF1M4Buffer, false);

   SetIndexBuffer(25, ExtTF2PPBuffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2PPBuffer, false);
   SetIndexBuffer(26, ExtTF2R1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R1Buffer, false);
   SetIndexBuffer(27, ExtTF2R2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R2Buffer, false);
   SetIndexBuffer(28, ExtTF2R3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R3Buffer, false);
   SetIndexBuffer(29, ExtTF2R4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R4Buffer, false);
   SetIndexBuffer(30, ExtTF2R5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R5Buffer, false);
   SetIndexBuffer(31, ExtTF2R6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R6Buffer, false);
   SetIndexBuffer(32, ExtTF2R7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R7Buffer, false);
   SetIndexBuffer(33, ExtTF2R8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R8Buffer, false);
   SetIndexBuffer(34, ExtTF2R9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R9Buffer, false);
   SetIndexBuffer(35, ExtTF2R10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2R10Buffer, false);
   SetIndexBuffer(36, ExtTF2S1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S1Buffer, false);
   SetIndexBuffer(37, ExtTF2S2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S2Buffer, false);
   SetIndexBuffer(38, ExtTF2S3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S3Buffer, false);
   SetIndexBuffer(39, ExtTF2S4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S4Buffer, false);
   SetIndexBuffer(40, ExtTF2S5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S5Buffer, false);
   SetIndexBuffer(41, ExtTF2S6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S6Buffer, false);
   SetIndexBuffer(42, ExtTF2S7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S7Buffer, false);
   SetIndexBuffer(43, ExtTF2S8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S8Buffer, false);
   SetIndexBuffer(44, ExtTF2S9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S9Buffer, false);
   SetIndexBuffer(45, ExtTF2S10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2S10Buffer, false);
   SetIndexBuffer(46, ExtTF2M1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2M1Buffer, false);
   SetIndexBuffer(47, ExtTF2M2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2M2Buffer, false);
   SetIndexBuffer(48, ExtTF2M3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2M3Buffer, false);
   SetIndexBuffer(49, ExtTF2M4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF2M4Buffer, false);

   SetIndexBuffer(50, ExtTF3PPBuffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3PPBuffer, false);
   SetIndexBuffer(51, ExtTF3R1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R1Buffer, false);
   SetIndexBuffer(52, ExtTF3R2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R2Buffer, false);
   SetIndexBuffer(53, ExtTF3R3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R3Buffer, false);
   SetIndexBuffer(54, ExtTF3R4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R4Buffer, false);
   SetIndexBuffer(55, ExtTF3R5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R5Buffer, false);
   SetIndexBuffer(56, ExtTF3R6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R6Buffer, false);
   SetIndexBuffer(57, ExtTF3R7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R7Buffer, false);
   SetIndexBuffer(58, ExtTF3R8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R8Buffer, false);
   SetIndexBuffer(59, ExtTF3R9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R9Buffer, false);
   SetIndexBuffer(60, ExtTF3R10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3R10Buffer, false);
   SetIndexBuffer(61, ExtTF3S1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S1Buffer, false);
   SetIndexBuffer(62, ExtTF3S2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S2Buffer, false);
   SetIndexBuffer(63, ExtTF3S3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S3Buffer, false);
   SetIndexBuffer(64, ExtTF3S4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S4Buffer, false);
   SetIndexBuffer(65, ExtTF3S5Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S5Buffer, false);
   SetIndexBuffer(66, ExtTF3S6Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S6Buffer, false);
   SetIndexBuffer(67, ExtTF3S7Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S7Buffer, false);
   SetIndexBuffer(68, ExtTF3S8Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S8Buffer, false);
   SetIndexBuffer(69, ExtTF3S9Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S9Buffer, false);
   SetIndexBuffer(70, ExtTF3S10Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3S10Buffer, false);
   SetIndexBuffer(71, ExtTF3M1Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3M1Buffer, false);
   SetIndexBuffer(72, ExtTF3M2Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3M2Buffer, false);
   SetIndexBuffer(73, ExtTF3M3Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3M3Buffer, false);
   SetIndexBuffer(74, ExtTF3M4Buffer, INDICATOR_DATA);
   ArraySetAsSeries(ExtTF3M4Buffer, false);

   // TF1=solid, TF2=dash, TF3=dot. This differentiates overlapping
   // timeframes without adding more inputs or changing pivot colors.
   ENUM_LINE_STYLE tf_styles[TF_COUNT];
   tf_styles[0] = STYLE_SOLID;
   tf_styles[1] = STYLE_DASH;
   tf_styles[2] = STYLE_DOT;

   for(int slot = 0; slot < TF_COUNT; slot++)
     {
      int base = slot * LEVEL_COUNT;
      ConfigurePlot(base + LEVEL_PP,
                    InpColorPP,
                    tf_styles[slot],
                    InpLineWidth,
                    true,
                    ExtTFName[slot] + " PP");

      for(int level = 1; level <= 10; level++)
        {
         color resistance_color = ResistanceColor(level);
         color support_color    = SupportColor(level);
         bool visible           = (InpMaxSRLevel >= level);

         ConfigurePlot(base + level,
                       resistance_color,
                       tf_styles[slot],
                       InpLineWidth,
                       visible,
                       ExtTFName[slot] + " R" + IntegerToString(level));

         ConfigurePlot(base + 10 + level,
                       support_color,
                       tf_styles[slot],
                       InpLineWidth,
                       visible,
                       ExtTFName[slot] + " S" + IntegerToString(level));
        }

      for(int middle = 1; middle <= 4; middle++)
         ConfigurePlot(base + 20 + middle,
                       InpColorM,
                       tf_styles[slot],
                       InpLineWidth,
                       InpShowLevelsM,
                       ExtTFName[slot] + " M" + IntegerToString(middle));
     }

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("Pivot Multi-TF %02d:%02d-%02d:%02d [%s,%s,%s] R/S%d",
                                   InpRangeStartHour,
                                   InpRangeStartMinute,
                                   InpRangeEndHour,
                                   InpRangeEndMinute,
                                   ExtTFName[0],
                                   ExtTFName[1],
                                   ExtTFName[2],
                                   InpMaxSRLevel));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   string number = StringFormat("%I64d", GetTickCount64());
   int prefix_start = StringLen(number) - 6;
   if(prefix_start < 0)
      prefix_start = 0;
   ExtPrefixUniq        = "PMTF_" + StringSubstr(number, prefix_start) + "_";
   ExtCurrentLabelPrefix = ExtPrefixUniq + "CUR_";
   ExtTestPrefix         = ExtPrefixUniq + "TEST_";

   ChartGetInteger(0, CHART_SCALE, 0, ExtChartScale);

   Print("Pivot Multi-TF started. Window=",
         StringFormat("%02d:%02d-%02d:%02d",
                      InpRangeStartHour,
                      InpRangeStartMinute,
                      InpRangeEndHour,
                      InpRangeEndMinute),
         ", TFs=", ExtTFName[0], ",", ExtTFName[1], ",", ExtTFName[2],
         ", max R/S=", InpMaxSRLevel,
         ", days=", InpMaxDays,
         ", labels=", (InpShowLabels ? "on" : "off"),
         ", tested-level markers=on");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Validate inputs                                                  |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(InpRangeStartHour < 0 || InpRangeStartHour > 23 ||
      InpRangeEndHour   < 0 || InpRangeEndHour   > 23 ||
      InpRangeStartMinute < 0 || InpRangeStartMinute > 59 ||
      InpRangeEndMinute   < 0 || InpRangeEndMinute   > 59)
     {
      Alert("Range hours must be 0-23 and minutes must be 0-59.");
      return(false);
     }

   if(InpLineWidth < 1 || InpLineWidth > 5)
     {
      Alert("InpLineWidth must be between 1 and 5.");
      return(false);
     }

   if(InpMaxDays < 0)
     {
      Alert("InpMaxDays cannot be negative.");
      return(false);
     }

   if(InpMaxSRLevel < 0 || InpMaxSRLevel > 10)
     {
      Alert("InpMaxSRLevel must be between 0 and 10.");
      return(false);
     }

   ExtRangeStartSeconds = InpRangeStartHour * 3600 + InpRangeStartMinute * 60;
   ExtRangeEndSeconds   = InpRangeEndHour   * 3600 + InpRangeEndMinute   * 60;

   if(ExtRangeStartSeconds == ExtRangeEndSeconds)
     {
      Alert("Display start and end cannot be equal. A 24-hour window is not supported.");
      return(false);
     }

   ExtRangeDuration = ExtRangeEndSeconds - ExtRangeStartSeconds;
   if(ExtRangeDuration < 0)
      ExtRangeDuration += 86400;

   return(true);
  }

//+------------------------------------------------------------------+
//| Normalize PERIOD_CURRENT                                         |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES NormalizeTimeframe(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe == PERIOD_CURRENT)
      return((ENUM_TIMEFRAMES)_Period);
   return(timeframe);
  }

//+------------------------------------------------------------------+
//| Compact timeframe label                                          |
//+------------------------------------------------------------------+
string TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   string name = EnumToString(timeframe);
   StringReplace(name, "PERIOD_", "");
   return(name);
  }

//+------------------------------------------------------------------+
//| Configure one plot                                               |
//+------------------------------------------------------------------+
void ConfigurePlot(const int plot,
                   const color line_color,
                   const ENUM_LINE_STYLE line_style,
                   const int line_width,
                   const bool visible,
                   const string label)
  {
   PlotIndexSetDouble(plot, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(plot, PLOT_LINE_COLOR, line_color);
   PlotIndexSetInteger(plot, PLOT_LINE_STYLE, line_style);
   PlotIndexSetInteger(plot, PLOT_LINE_WIDTH, line_width);
   PlotIndexSetInteger(plot, PLOT_DRAW_TYPE, visible ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(plot, PLOT_SHOW_DATA, visible);
   PlotIndexSetString(plot, PLOT_LABEL, label);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration                                       |
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
   if(rates_total <= 0)
      return(0);

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

   // On ticks inside the same chart candle, perform only the inexpensive
   // active-level touch check. Full history and CopyRates work remains
   // restricted to new chart candles.
   if(prev_calculated == rates_total && !ExtCopyPending)
     {
      bool changed = ProcessIntrabarTests(rates_total,
                                          time,
                                          open,
                                          high,
                                          low,
                                          close);
      if(changed && InpShowLabels)
         UpdateCurrentLabels(time[rates_total - 1], rates_total - 1);
      return(rates_total);
     }

   datetime latest_time    = time[rates_total - 1];
   datetime latest_session = SessionStartForTime(latest_time);
   datetime oldest_session = 0;

   if(InpMaxDays > 0)
      oldest_session = latest_session - (InpMaxDays - 1) * 86400;

   datetime load_from = (oldest_session > 0) ? oldest_session : time[0];
   int max_tf_seconds = ExtTFSeconds[0];
   if(ExtTFSeconds[1] > max_tf_seconds)
      max_tf_seconds = ExtTFSeconds[1];
   if(ExtTFSeconds[2] > max_tf_seconds)
      max_tf_seconds = ExtTFSeconds[2];
   load_from -= 2 * max_tf_seconds;

   ExtCopyPending = false;
   for(int slot = 0; slot < TF_COUNT; slot++)
     {
      if(!EnsureRateData(slot, load_from, latest_time))
        {
         HideCurrentLabels();
         return(prev_calculated > 0 ? prev_calculated : 0);
        }
     }

   int start = 0;

   if(prev_calculated == 0)
     {
      InitializeAllBuffers();
      if(oldest_session > 0)
         start = FirstIndexAtOrAfter(time, rates_total, oldest_session);
     }
   else
     {
      datetime refresh_from = latest_session;
      if(InpMaxDays > 0 && ExtLastCalculatedSession != latest_session)
        {
         refresh_from = oldest_session - 86400;
         DeleteTestMarkersForSession(oldest_session - 86400);
        }

      start = FirstIndexAtOrAfter(time, rates_total, refresh_from);
      if(start >= rates_total)
         start = rates_total - 1;
     }

   datetime cached_session = 0;
   SPivotSnapshot cached_snapshot[TF_COUNT];
   for(int slot = 0; slot < TF_COUNT; slot++)
      ResetSnapshot(cached_snapshot[slot]);

   for(int i = start; i < rates_total; i++)
     {
      ClearAllTFBuffers(i);

      datetime session_start = SessionStartForTime(time[i]);
      datetime session_end   = session_start + ExtRangeDuration;

      if(oldest_session > 0 && session_start < oldest_session)
         continue;

      if(!IsInsideDisplayWindow(time[i], session_start, session_end))
         continue;

      if(cached_session != session_start)
        {
         cached_session = session_start;

         datetime evaluation_time = session_end - 1;
         if(session_start == latest_session && latest_time < session_end)
            evaluation_time = latest_time;

         for(int slot = 0; slot < TF_COUNT; slot++)
           {
            PrepareSessionSnapshot(slot,
                                   session_start,
                                   session_end,
                                   evaluation_time,
                                   rates_total,
                                   time,
                                   open,
                                   high,
                                   low,
                                   close,
                                   cached_snapshot[slot]);

            if(session_start == latest_session)
               CopySnapshot(cached_snapshot[slot], ExtLiveSnapshot[slot]);
           }
        }

      for(int slot = 0; slot < TF_COUNT; slot++)
         if(cached_snapshot[slot].valid)
            WriteTFLevels(slot, i, cached_snapshot[slot]);
     }

   if(InpShowLabels)
      UpdateCurrentLabels(time[rates_total - 1], rates_total - 1);
   else
      HideCurrentLabels();

   ExtLastCalculatedSession = latest_session;
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Load/refresh one timeframe series                                |
//+------------------------------------------------------------------+
bool EnsureRateData(const int slot,
                    const datetime load_from,
                    const datetime through)
  {
   if(ExtRatesReady[slot] &&
      load_from >= ExtLoadedFrom[slot] &&
      through < ExtNextRefresh[slot])
      return(true);

   int copied = 0;
   ResetLastError();

   switch(slot)
     {
      case 0:
         ArraySetAsSeries(ExtRatesTF1, false);
         copied = CopyRates(_Symbol, ExtTF[slot], load_from, through, ExtRatesTF1);
         break;
      case 1:
         ArraySetAsSeries(ExtRatesTF2, false);
         copied = CopyRates(_Symbol, ExtTF[slot], load_from, through, ExtRatesTF2);
         break;
      case 2:
         ArraySetAsSeries(ExtRatesTF3, false);
         copied = CopyRates(_Symbol, ExtTF[slot], load_from, through, ExtRatesTF3);
         break;
     }

   if(copied <= 0)
     {
      ExtCopyPending = true;
      int error = GetLastError();
      if(TimeCurrent() >= ExtNextCopyError)
        {
         ExtNextCopyError = TimeCurrent() + 60;
         Print("CopyRates failed for ", ExtTFName[slot],
               " from ", TimeToString(load_from, TIME_DATE | TIME_MINUTES),
               " through ", TimeToString(through, TIME_DATE | TIME_MINUTES),
               ". Error ", error);
        }
      return(false);
     }

   datetime first_open = RateTimeAt(slot, 0);
   datetime last_open  = RateTimeAt(slot, copied - 1);

   ExtLoadedFrom[slot] = first_open;
   ExtNextRefresh[slot]= last_open + ExtTFSeconds[slot];
   if(ExtNextRefresh[slot] <= through)
      {
       int chart_seconds = PeriodSeconds();
       if(chart_seconds < 1)
          chart_seconds = 1;
       ExtNextRefresh[slot] = through + chart_seconds;
      }

   ExtRatesReady[slot] = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Time of a cached source bar                                      |
//+------------------------------------------------------------------+
datetime RateTimeAt(const int slot, const int index)
  {
   switch(slot)
     {
      case 0: return(ExtRatesTF1[index].time);
      case 1: return(ExtRatesTF2[index].time);
      case 2: return(ExtRatesTF3[index].time);
     }
   return(0);
  }

//+------------------------------------------------------------------+
//| Copy one cached source bar                                       |
//+------------------------------------------------------------------+
bool RateAt(const int slot, const int index, MqlRates &rate)
  {
   switch(slot)
     {
      case 0:
         if(index < 0 || index >= ArraySize(ExtRatesTF1)) return(false);
         rate = ExtRatesTF1[index];
         return(true);
      case 1:
         if(index < 0 || index >= ArraySize(ExtRatesTF2)) return(false);
         rate = ExtRatesTF2[index];
         return(true);
      case 2:
         if(index < 0 || index >= ArraySize(ExtRatesTF3)) return(false);
         rate = ExtRatesTF3[index];
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Number of cached bars for one slot                               |
//+------------------------------------------------------------------+
int RateCount(const int slot)
  {
   switch(slot)
     {
      case 0: return(ArraySize(ExtRatesTF1));
      case 1: return(ArraySize(ExtRatesTF2));
      case 2: return(ArraySize(ExtRatesTF3));
     }
   return(0);
  }

//+------------------------------------------------------------------+
//| Last source candle fully closed by evaluation_time               |
//+------------------------------------------------------------------+
int FindLastClosedRateIndex(const int slot,
                            const datetime evaluation_time)
  {
   int count = RateCount(slot);
   if(count <= 0)
      return(-1);

   datetime latest_allowed_open = evaluation_time - ExtTFSeconds[slot];

   int left = 0;
   int right = count;
   while(left < right)
     {
      int middle = left + (right - left) / 2;
      if(RateTimeAt(slot, middle) <= latest_allowed_open)
         left = middle + 1;
      else
         right = middle;
     }

   return(left - 1);
  }

//+------------------------------------------------------------------+
//| Last source candle fully closed by evaluation_time               |
//+------------------------------------------------------------------+
bool FindLastClosedRate(const int slot,
                        const datetime evaluation_time,
                        MqlRates &rate)
  {
   int index = FindLastClosedRateIndex(slot, evaluation_time);
   if(index < 0)
      return(false);
   return(RateAt(slot, index, rate));
  }

//+------------------------------------------------------------------+
//| Build classic pivots from one completed source candle            |
//+------------------------------------------------------------------+
void BuildPivotLevels(const double candle_high,
                      const double candle_low,
                      const double candle_close,
                      SPivotLevels &levels)
  {
   for(int i = 0; i < LEVEL_COUNT; i++)
      levels.value[i] = EMPTY_VALUE;

   double range = candle_high - candle_low;
   double pp    = (candle_high + candle_low + candle_close) / 3.0;

   levels.value[LEVEL_PP] = pp;
   levels.value[1]  = 2.0 * pp - candle_low;
   levels.value[2]  = pp + range;
   levels.value[3]  = candle_high + 2.0 * (pp - candle_low);
   levels.value[11] = 2.0 * pp - candle_high;
   levels.value[12] = pp - range;
   levels.value[13] = candle_low - 2.0 * (candle_high - pp);

   // R4-R10 and S4-S10 continue deterministically from R3/S3 using
   // full source-candle ranges, matching the previous indicator version.
   for(int level = 4; level <= InpMaxSRLevel; level++)
     {
      levels.value[level]      = levels.value[3]  + (level - 3) * range;
      levels.value[10 + level] = levels.value[13] - (level - 3) * range;
     }

   levels.value[21] = (levels.value[11] + levels.value[12]) / 2.0;
   levels.value[22] = (levels.value[11] + pp) / 2.0;
   levels.value[23] = (levels.value[1]  + pp) / 2.0;
   levels.value[24] = (levels.value[1]  + levels.value[2]) / 2.0;
  }

//+------------------------------------------------------------------+
//| Session start associated with a chart bar                        |
//+------------------------------------------------------------------+
datetime SessionStartForTime(const datetime bar_time)
  {
   datetime candidate = DayStart(bar_time) + ExtRangeStartSeconds;
   if(bar_time < candidate)
      candidate -= 86400;
   return(candidate);
  }

//+------------------------------------------------------------------+
//| Whether a bar belongs to the daily display span                  |
//+------------------------------------------------------------------+
bool IsInsideDisplayWindow(const datetime bar_time,
                           const datetime session_start,
                           const datetime session_end)
  {
   // Include the exact ending timestamp as a terminal line anchor.
   return(bar_time >= session_start && bar_time <= session_end);
  }

//+------------------------------------------------------------------+
//| Resistance color hierarchy                                       |
//+------------------------------------------------------------------+
color ResistanceColor(const int level)
  {
   if(level <= 1) return(InpColorR1);
   if(level == 2) return(InpColorR2);
   return(InpColorR3);
  }

//+------------------------------------------------------------------+
//| Support color hierarchy                                          |
//+------------------------------------------------------------------+
color SupportColor(const int level)
  {
   if(level <= 1) return(InpColorS1);
   if(level == 2) return(InpColorS2);
   return(InpColorS3);
  }

//+------------------------------------------------------------------+
//| First ascending time index at or after target                    |
//+------------------------------------------------------------------+
int FirstIndexAtOrAfter(const datetime &time[],
                        const int count,
                        const datetime target)
  {
   int left = 0;
   int right = count;

   while(left < right)
     {
      int middle = left + (right - left) / 2;
      if(time[middle] < target)
         left = middle + 1;
      else
         right = middle;
     }

   return(left);
  }

//+------------------------------------------------------------------+
//| Midnight corresponding to a timestamp                            |
//+------------------------------------------------------------------+
datetime DayStart(const datetime value)
  {
   return(value - (value % 86400));
  }

//+------------------------------------------------------------------+
//| Write enabled levels for one timeframe                          |
//+------------------------------------------------------------------+
bool IsLevelEnabled(const int level)
  {
   if(level == LEVEL_PP)
      return(true);
   if(level >= LEVEL_R1 && level <= LEVEL_R10)
      return(level <= InpMaxSRLevel);
   if(level >= LEVEL_S1 && level <= LEVEL_S10)
      return((level - 10) <= InpMaxSRLevel);
   if(level >= LEVEL_M1 && level <= LEVEL_M4)
      return(InpShowLevelsM);
   return(false);
  }

//+------------------------------------------------------------------+
//| Human-readable level name                                        |
//+------------------------------------------------------------------+
string LevelName(const int level)
  {
   if(level == LEVEL_PP)
      return("PP");
   if(level >= LEVEL_R1 && level <= LEVEL_R10)
      return("R" + IntegerToString(level));
   if(level >= LEVEL_S1 && level <= LEVEL_S10)
      return("S" + IntegerToString(level - 10));
   if(level >= LEVEL_M1 && level <= LEVEL_M4)
      return("M" + IntegerToString(level - 20));
   return("?");
  }

//+------------------------------------------------------------------+
//| Write one arbitrary TF/level buffer value                         |
//+------------------------------------------------------------------+
void SetBufferValue(const int slot,
                    const int level,
                    const int index,
                    const double value)
  {
   switch(slot)
     {
      case 0:
         switch(level)
           {
            case 0: ExtTF1PPBuffer[index]=value; break;
            case 1: ExtTF1R1Buffer[index]=value; break;
            case 2: ExtTF1R2Buffer[index]=value; break;
            case 3: ExtTF1R3Buffer[index]=value; break;
            case 4: ExtTF1R4Buffer[index]=value; break;
            case 5: ExtTF1R5Buffer[index]=value; break;
            case 6: ExtTF1R6Buffer[index]=value; break;
            case 7: ExtTF1R7Buffer[index]=value; break;
            case 8: ExtTF1R8Buffer[index]=value; break;
            case 9: ExtTF1R9Buffer[index]=value; break;
            case 10: ExtTF1R10Buffer[index]=value; break;
            case 11: ExtTF1S1Buffer[index]=value; break;
            case 12: ExtTF1S2Buffer[index]=value; break;
            case 13: ExtTF1S3Buffer[index]=value; break;
            case 14: ExtTF1S4Buffer[index]=value; break;
            case 15: ExtTF1S5Buffer[index]=value; break;
            case 16: ExtTF1S6Buffer[index]=value; break;
            case 17: ExtTF1S7Buffer[index]=value; break;
            case 18: ExtTF1S8Buffer[index]=value; break;
            case 19: ExtTF1S9Buffer[index]=value; break;
            case 20: ExtTF1S10Buffer[index]=value; break;
            case 21: ExtTF1M1Buffer[index]=value; break;
            case 22: ExtTF1M2Buffer[index]=value; break;
            case 23: ExtTF1M3Buffer[index]=value; break;
            case 24: ExtTF1M4Buffer[index]=value; break;
           }
         break;
      case 1:
         switch(level)
           {
            case 0: ExtTF2PPBuffer[index]=value; break;
            case 1: ExtTF2R1Buffer[index]=value; break;
            case 2: ExtTF2R2Buffer[index]=value; break;
            case 3: ExtTF2R3Buffer[index]=value; break;
            case 4: ExtTF2R4Buffer[index]=value; break;
            case 5: ExtTF2R5Buffer[index]=value; break;
            case 6: ExtTF2R6Buffer[index]=value; break;
            case 7: ExtTF2R7Buffer[index]=value; break;
            case 8: ExtTF2R8Buffer[index]=value; break;
            case 9: ExtTF2R9Buffer[index]=value; break;
            case 10: ExtTF2R10Buffer[index]=value; break;
            case 11: ExtTF2S1Buffer[index]=value; break;
            case 12: ExtTF2S2Buffer[index]=value; break;
            case 13: ExtTF2S3Buffer[index]=value; break;
            case 14: ExtTF2S4Buffer[index]=value; break;
            case 15: ExtTF2S5Buffer[index]=value; break;
            case 16: ExtTF2S6Buffer[index]=value; break;
            case 17: ExtTF2S7Buffer[index]=value; break;
            case 18: ExtTF2S8Buffer[index]=value; break;
            case 19: ExtTF2S9Buffer[index]=value; break;
            case 20: ExtTF2S10Buffer[index]=value; break;
            case 21: ExtTF2M1Buffer[index]=value; break;
            case 22: ExtTF2M2Buffer[index]=value; break;
            case 23: ExtTF2M3Buffer[index]=value; break;
            case 24: ExtTF2M4Buffer[index]=value; break;
           }
         break;
      case 2:
         switch(level)
           {
            case 0: ExtTF3PPBuffer[index]=value; break;
            case 1: ExtTF3R1Buffer[index]=value; break;
            case 2: ExtTF3R2Buffer[index]=value; break;
            case 3: ExtTF3R3Buffer[index]=value; break;
            case 4: ExtTF3R4Buffer[index]=value; break;
            case 5: ExtTF3R5Buffer[index]=value; break;
            case 6: ExtTF3R6Buffer[index]=value; break;
            case 7: ExtTF3R7Buffer[index]=value; break;
            case 8: ExtTF3R8Buffer[index]=value; break;
            case 9: ExtTF3R9Buffer[index]=value; break;
            case 10: ExtTF3R10Buffer[index]=value; break;
            case 11: ExtTF3S1Buffer[index]=value; break;
            case 12: ExtTF3S2Buffer[index]=value; break;
            case 13: ExtTF3S3Buffer[index]=value; break;
            case 14: ExtTF3S4Buffer[index]=value; break;
            case 15: ExtTF3S5Buffer[index]=value; break;
            case 16: ExtTF3S6Buffer[index]=value; break;
            case 17: ExtTF3S7Buffer[index]=value; break;
            case 18: ExtTF3S8Buffer[index]=value; break;
            case 19: ExtTF3S9Buffer[index]=value; break;
            case 20: ExtTF3S10Buffer[index]=value; break;
            case 21: ExtTF3M1Buffer[index]=value; break;
            case 22: ExtTF3M2Buffer[index]=value; break;
            case 23: ExtTF3M3Buffer[index]=value; break;
            case 24: ExtTF3M4Buffer[index]=value; break;
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//| Write only untested levels for one timeframe                     |
//+------------------------------------------------------------------+
void WriteTFLevels(const int slot,
                   const int index,
                   const SPivotSnapshot &snapshot)
  {
   for(int level = 0; level < LEVEL_COUNT; level++)
     {
      if(!IsLevelEnabled(level) || snapshot.tested[level])
         continue;
      if(snapshot.value[level] == EMPTY_VALUE)
         continue;
      SetBufferValue(slot, level, index, snapshot.value[level]);
     }
  }

//+------------------------------------------------------------------+
//| Initialize all buffers                                           |
//+------------------------------------------------------------------+
void InitializeAllBuffers()
  {
   ArrayInitialize(ExtTF1PPBuffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1R10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1S10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1M1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1M2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1M3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF1M4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2PPBuffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2R10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2S10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2M1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2M2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2M3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF2M4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3PPBuffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3R10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S4Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S5Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S6Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S7Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S8Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S9Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3S10Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3M1Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3M2Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3M3Buffer, EMPTY_VALUE);
   ArrayInitialize(ExtTF3M4Buffer, EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//| Clear enabled buffers at one chart index                          |
//+------------------------------------------------------------------+
void ClearAllTFBuffers(const int index)
  {
   ExtTF1PPBuffer[index] = EMPTY_VALUE;
   if(InpMaxSRLevel >= 1)
     {
      ExtTF1R1Buffer[index] = EMPTY_VALUE;
      ExtTF1S1Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 2)
     {
      ExtTF1R2Buffer[index] = EMPTY_VALUE;
      ExtTF1S2Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 3)
     {
      ExtTF1R3Buffer[index] = EMPTY_VALUE;
      ExtTF1S3Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 4)
     {
      ExtTF1R4Buffer[index] = EMPTY_VALUE;
      ExtTF1S4Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 5)
     {
      ExtTF1R5Buffer[index] = EMPTY_VALUE;
      ExtTF1S5Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 6)
     {
      ExtTF1R6Buffer[index] = EMPTY_VALUE;
      ExtTF1S6Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 7)
     {
      ExtTF1R7Buffer[index] = EMPTY_VALUE;
      ExtTF1S7Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 8)
     {
      ExtTF1R8Buffer[index] = EMPTY_VALUE;
      ExtTF1S8Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 9)
     {
      ExtTF1R9Buffer[index] = EMPTY_VALUE;
      ExtTF1S9Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 10)
     {
      ExtTF1R10Buffer[index] = EMPTY_VALUE;
      ExtTF1S10Buffer[index] = EMPTY_VALUE;
     }
   if(InpShowLevelsM)
     {
      ExtTF1M1Buffer[index] = EMPTY_VALUE;
      ExtTF1M2Buffer[index] = EMPTY_VALUE;
      ExtTF1M3Buffer[index] = EMPTY_VALUE;
      ExtTF1M4Buffer[index] = EMPTY_VALUE;
     }
   ExtTF2PPBuffer[index] = EMPTY_VALUE;
   if(InpMaxSRLevel >= 1)
     {
      ExtTF2R1Buffer[index] = EMPTY_VALUE;
      ExtTF2S1Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 2)
     {
      ExtTF2R2Buffer[index] = EMPTY_VALUE;
      ExtTF2S2Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 3)
     {
      ExtTF2R3Buffer[index] = EMPTY_VALUE;
      ExtTF2S3Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 4)
     {
      ExtTF2R4Buffer[index] = EMPTY_VALUE;
      ExtTF2S4Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 5)
     {
      ExtTF2R5Buffer[index] = EMPTY_VALUE;
      ExtTF2S5Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 6)
     {
      ExtTF2R6Buffer[index] = EMPTY_VALUE;
      ExtTF2S6Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 7)
     {
      ExtTF2R7Buffer[index] = EMPTY_VALUE;
      ExtTF2S7Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 8)
     {
      ExtTF2R8Buffer[index] = EMPTY_VALUE;
      ExtTF2S8Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 9)
     {
      ExtTF2R9Buffer[index] = EMPTY_VALUE;
      ExtTF2S9Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 10)
     {
      ExtTF2R10Buffer[index] = EMPTY_VALUE;
      ExtTF2S10Buffer[index] = EMPTY_VALUE;
     }
   if(InpShowLevelsM)
     {
      ExtTF2M1Buffer[index] = EMPTY_VALUE;
      ExtTF2M2Buffer[index] = EMPTY_VALUE;
      ExtTF2M3Buffer[index] = EMPTY_VALUE;
      ExtTF2M4Buffer[index] = EMPTY_VALUE;
     }
   ExtTF3PPBuffer[index] = EMPTY_VALUE;
   if(InpMaxSRLevel >= 1)
     {
      ExtTF3R1Buffer[index] = EMPTY_VALUE;
      ExtTF3S1Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 2)
     {
      ExtTF3R2Buffer[index] = EMPTY_VALUE;
      ExtTF3S2Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 3)
     {
      ExtTF3R3Buffer[index] = EMPTY_VALUE;
      ExtTF3S3Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 4)
     {
      ExtTF3R4Buffer[index] = EMPTY_VALUE;
      ExtTF3S4Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 5)
     {
      ExtTF3R5Buffer[index] = EMPTY_VALUE;
      ExtTF3S5Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 6)
     {
      ExtTF3R6Buffer[index] = EMPTY_VALUE;
      ExtTF3S6Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 7)
     {
      ExtTF3R7Buffer[index] = EMPTY_VALUE;
      ExtTF3S7Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 8)
     {
      ExtTF3R8Buffer[index] = EMPTY_VALUE;
      ExtTF3S8Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 9)
     {
      ExtTF3R9Buffer[index] = EMPTY_VALUE;
      ExtTF3S9Buffer[index] = EMPTY_VALUE;
     }
   if(InpMaxSRLevel >= 10)
     {
      ExtTF3R10Buffer[index] = EMPTY_VALUE;
      ExtTF3S10Buffer[index] = EMPTY_VALUE;
     }
   if(InpShowLevelsM)
     {
      ExtTF3M1Buffer[index] = EMPTY_VALUE;
      ExtTF3M2Buffer[index] = EMPTY_VALUE;
      ExtTF3M3Buffer[index] = EMPTY_VALUE;
      ExtTF3M4Buffer[index] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//| Reset one pivot snapshot                                         |
//+------------------------------------------------------------------+
void ResetSnapshot(SPivotSnapshot &snapshot)
  {
   snapshot.valid           = false;
   snapshot.source_open     = 0;
   snapshot.activation_time = 0;
   snapshot.reference_close = 0.0;
   for(int level = 0; level < LEVEL_COUNT; level++)
     {
      snapshot.value[level]  = EMPTY_VALUE;
      snapshot.tested[level] = false;
     }
  }

//+------------------------------------------------------------------+
//| Copy one snapshot without relying on aggregate struct assignment |
//+------------------------------------------------------------------+
void CopySnapshot(const SPivotSnapshot &source,
                  SPivotSnapshot &target)
  {
   target.valid           = source.valid;
   target.source_open     = source.source_open;
   target.activation_time = source.activation_time;
   target.reference_close = source.reference_close;
   for(int level = 0; level < LEVEL_COUNT; level++)
     {
      target.value[level]  = source.value[level];
      target.tested[level] = source.tested[level];
     }
  }

//+------------------------------------------------------------------+
//| Copy calculated levels into a snapshot                           |
//+------------------------------------------------------------------+
void CopyLevelsToSnapshot(const SPivotLevels &levels,
                          SPivotSnapshot &snapshot)
  {
   for(int level = 0; level < LEVEL_COUNT; level++)
      snapshot.value[level] = levels.value[level];
  }

//+------------------------------------------------------------------+
//| Determine the direction from which price first tests a level     |
//+------------------------------------------------------------------+
int TestDirection(const double previous_close,
                  const double bar_open,
                  const double bar_high,
                  const double bar_low,
                  const double level)
  {
   if(bar_low > level || bar_high < level)
      return(TEST_NONE);

   if(previous_close > level)
      return(TEST_BULLISH);
   if(previous_close < level)
      return(TEST_BEARISH);
   if(bar_open > level)
      return(TEST_BULLISH);
   if(bar_open < level)
      return(TEST_BEARISH);

   return(TEST_NONE);
  }

//+------------------------------------------------------------------+
//| Find the first test of one level during one pivot-set lifetime   |
//+------------------------------------------------------------------+
bool FindFirstLevelTest(const datetime active_from,
                        const datetime active_until_exclusive,
                        const double initial_reference_close,
                        const double level,
                        const int rates_total,
                        const datetime &time[],
                        const double &open[],
                        const double &high[],
                        const double &low[],
                        const double &close[],
                        datetime &touch_time,
                        int &direction)
  {
   if(active_until_exclusive <= active_from)
      return(false);

   int start = FirstIndexAtOrAfter(time, rates_total, active_from);

   // Macro direction is anchored to the close of the same-TF candle that
   // generated the pivot set. Example: an M30 candle closing above S1 and
   // a later touch of S1 is recorded as an M30 bullish support test.
   for(int i = start; i < rates_total && time[i] < active_until_exclusive; i++)
     {
      int detected = TestDirection(initial_reference_close,
                                   open[i],
                                   high[i],
                                   low[i],
                                   level);
      if(detected != TEST_NONE)
        {
         touch_time = time[i];
         direction  = detected;
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Marker duration: compact, but never shorter than one chart bar   |
//+------------------------------------------------------------------+
int TestMarkerDurationSeconds()
  {
   int chart_seconds = PeriodSeconds();
   if(chart_seconds < 1)
      chart_seconds = 60;

   int duration = ExtRangeDuration / 8;
   if(duration > 15 * 60)
      duration = 15 * 60;
   if(duration < chart_seconds)
      duration = chart_seconds;
   return(duration);
  }

//+------------------------------------------------------------------+
//| Deterministic object prefix for one session                      |
//+------------------------------------------------------------------+
string TestSessionPrefix(const datetime session_start)
  {
   return(ExtTestPrefix + StringFormat("%I64d_", (long)session_start));
  }

//+------------------------------------------------------------------+
//| Draw one compact tested-level marker and macro-direction label   |
//+------------------------------------------------------------------+
void CreateTestMarker(const datetime session_start,
                      const datetime session_end,
                      const int slot,
                      const datetime source_open,
                      const int level_index,
                      const datetime touch_time,
                      const double price,
                      const int direction)
  {
   if(direction == TEST_NONE)
      return;

   string key = TestSessionPrefix(session_start) +
                IntegerToString(slot) + "_" +
                StringFormat("%I64d_", (long)source_open) +
                IntegerToString(level_index);
   string line_name = key + "_LINE";
   string text_name = key + "_TEXT";

   datetime marker_end = touch_time + TestMarkerDurationSeconds();
   if(marker_end > session_end)
      marker_end = session_end;
   if(marker_end <= touch_time)
      marker_end = touch_time + 1;

   color marker_color = (direction == TEST_BULLISH) ? clrLimeGreen : clrTomato;
   string macro_text  = (direction == TEST_BULLISH) ? "BULL" : "BEAR";

   if(ObjectFind(0, line_name) < 0)
     {
      if(ObjectCreate(0,
                      line_name,
                      OBJ_TREND,
                      0,
                      touch_time,
                      price,
                      marker_end,
                      price))
        {
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, marker_color);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE,
                          slot == 0 ? STYLE_SOLID : (slot == 1 ? STYLE_DASH : STYLE_DOT));
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
        }
     }

   if(ObjectFind(0, text_name) < 0)
     {
      if(ObjectCreate(0, text_name, OBJ_TEXT, 0, marker_end, price))
        {
         ObjectSetString(0,
                         text_name,
                         OBJPROP_TEXT,
                         ExtTFName[slot] + " " + LevelName(level_index) + " " + macro_text);
         ObjectSetString(0, text_name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, text_name, OBJPROP_COLOR, marker_color);
         ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
         ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, text_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
        }
     }
  }

//+------------------------------------------------------------------+
//| Delete markers belonging to one expired daily session            |
//+------------------------------------------------------------------+
void DeleteTestMarkersForSession(const datetime session_start)
  {
   if(session_start <= 0)
      return;
   string prefix = TestSessionPrefix(session_start);
   ObjectsDeleteAll(0, prefix, 0, OBJ_TREND);
   ObjectsDeleteAll(0, prefix, 0, OBJ_TEXT);
  }

//+------------------------------------------------------------------+
//| Scan every pivot set that became active during a daily window    |
//+------------------------------------------------------------------+
void BuildTestMarkersForSession(const int slot,
                                const datetime session_start,
                                const datetime session_end,
                                const datetime evaluation_time,
                                const int rates_total,
                                const datetime &time[],
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[])
  {
   int first_index = FindLastClosedRateIndex(slot, session_start);
   if(first_index < 0)
      return;

   int count = RateCount(slot);
   datetime through_exclusive = evaluation_time + 1;
   if(through_exclusive > session_end)
      through_exclusive = session_end;

   for(int source_index = first_index; source_index < count; source_index++)
     {
      MqlRates source_bar;
      if(!RateAt(slot, source_index, source_bar))
         break;

      datetime active_from = source_bar.time + ExtTFSeconds[slot];
      if(active_from < session_start)
         active_from = session_start;
      if(active_from >= through_exclusive)
         break;

      datetime active_until = through_exclusive;
      if(source_index + 1 < count)
        {
         datetime next_activation = RateTimeAt(slot, source_index + 1) + ExtTFSeconds[slot];
         if(next_activation < active_until)
            active_until = next_activation;
        }

      SPivotLevels levels;
      BuildPivotLevels(source_bar.high,
                       source_bar.low,
                       source_bar.close,
                       levels);

      for(int level = 0; level < LEVEL_COUNT; level++)
        {
         if(!IsLevelEnabled(level) || levels.value[level] == EMPTY_VALUE)
            continue;

         datetime touch_time = 0;
         int direction = TEST_NONE;
         if(FindFirstLevelTest(active_from,
                               active_until,
                               source_bar.close,
                               levels.value[level],
                               rates_total,
                               time,
                               open,
                               high,
                               low,
                               close,
                               touch_time,
                               direction))
            CreateTestMarker(session_start,
                             session_end,
                             slot,
                             source_bar.time,
                             level,
                             touch_time,
                             levels.value[level],
                             direction);
        }
     }
  }

//+------------------------------------------------------------------+
//| Build the latest snapshot and identify which levels are tested   |
//+------------------------------------------------------------------+
void PrepareSessionSnapshot(const int slot,
                            const datetime session_start,
                            const datetime session_end,
                            const datetime evaluation_time,
                            const int rates_total,
                            const datetime &time[],
                            const double &open[],
                            const double &high[],
                            const double &low[],
                            const double &close[],
                            SPivotSnapshot &snapshot)
  {
   ResetSnapshot(snapshot);

   BuildTestMarkersForSession(slot,
                              session_start,
                              session_end,
                              evaluation_time,
                              rates_total,
                              time,
                              open,
                              high,
                              low,
                              close);

   MqlRates source_bar;
   if(!FindLastClosedRate(slot, evaluation_time, source_bar))
      return;

   SPivotLevels levels;
   BuildPivotLevels(source_bar.high,
                    source_bar.low,
                    source_bar.close,
                    levels);

   snapshot.valid           = true;
   snapshot.source_open     = source_bar.time;
   snapshot.activation_time = source_bar.time + ExtTFSeconds[slot];
   snapshot.reference_close = source_bar.close;
   if(snapshot.activation_time < session_start)
      snapshot.activation_time = session_start;
   CopyLevelsToSnapshot(levels, snapshot);

   datetime through_exclusive = evaluation_time + 1;
   if(through_exclusive > session_end)
      through_exclusive = session_end;

   for(int level = 0; level < LEVEL_COUNT; level++)
     {
      if(!IsLevelEnabled(level) || snapshot.value[level] == EMPTY_VALUE)
         continue;

      datetime touch_time = 0;
      int direction = TEST_NONE;
      if(FindFirstLevelTest(snapshot.activation_time,
                            through_exclusive,
                            source_bar.close,
                            snapshot.value[level],
                            rates_total,
                            time,
                            open,
                            high,
                            low,
                            close,
                            touch_time,
                            direction))
        {
         snapshot.tested[level] = true;
         CreateTestMarker(session_start,
                          session_end,
                          slot,
                          source_bar.time,
                          level,
                          touch_time,
                          snapshot.value[level],
                          direction);
        }
     }
  }

//+------------------------------------------------------------------+
//| Clear one tested level across the currently displayed session    |
//+------------------------------------------------------------------+
void ClearLevelAcrossSession(const int slot,
                             const int level,
                             const datetime session_start,
                             const int rates_total,
                             const datetime &time[])
  {
   datetime session_end = session_start + ExtRangeDuration;
   int start = FirstIndexAtOrAfter(time, rates_total, session_start);
   for(int i = start; i < rates_total && time[i] <= session_end; i++)
      SetBufferValue(slot, level, i, EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//| Cheap tick-by-tick test for the active chart candle              |
//+------------------------------------------------------------------+
bool ProcessIntrabarTests(const int rates_total,
                          const datetime &time[],
                          const double &open[],
                          const double &high[],
                          const double &low[],
                          const double &close[])
  {
   if(rates_total <= 0)
      return(false);

   int last = rates_total - 1;
   datetime current_time = time[last];
   datetime session_start = SessionStartForTime(current_time);
   datetime session_end   = session_start + ExtRangeDuration;

   if(!IsInsideDisplayWindow(current_time, session_start, session_end))
      return(false);

   bool changed = false;

   for(int slot = 0; slot < TF_COUNT; slot++)
     {
      if(!ExtLiveSnapshot[slot].valid ||
         current_time < ExtLiveSnapshot[slot].activation_time)
         continue;

      bool slot_changed = false;
      for(int level = 0; level < LEVEL_COUNT; level++)
        {
         if(!IsLevelEnabled(level) ||
            ExtLiveSnapshot[slot].tested[level] ||
            ExtLiveSnapshot[slot].value[level] == EMPTY_VALUE)
            continue;

         int direction = TestDirection(ExtLiveSnapshot[slot].reference_close,
                                       open[last],
                                       high[last],
                                       low[last],
                                       ExtLiveSnapshot[slot].value[level]);
         if(direction == TEST_NONE)
            continue;

         ExtLiveSnapshot[slot].tested[level] = true;
         ClearLevelAcrossSession(slot,
                                 level,
                                 session_start,
                                 rates_total,
                                 time);
         CreateTestMarker(session_start,
                          session_end,
                          slot,
                          ExtLiveSnapshot[slot].source_open,
                          level,
                          current_time,
                          ExtLiveSnapshot[slot].value[level],
                          direction);
         slot_changed = true;
         changed      = true;
        }

      if(slot_changed)
        {
         DeleteCurrentLabelsForTF(slot);
         ExtLastLabelSourceOpen[slot] = 0;
         ExtLastLabelTestMask[slot]   = 0;
        }
     }

   return(changed);
  }

//+------------------------------------------------------------------+
//| Compact mask used to avoid unnecessary current-label work        |
//+------------------------------------------------------------------+
ulong SnapshotTestMask(const SPivotSnapshot &snapshot)
  {
   ulong mask = 0;
   for(int level = 0; level < LEVEL_COUNT; level++)
      if(snapshot.tested[level])
         mask |= ((ulong)1 << level);
   return(mask);
  }

//+------------------------------------------------------------------+
//| Delete only the current active labels for one timeframe          |
//+------------------------------------------------------------------+
void DeleteCurrentLabelsForTF(const int slot)
  {
   string prefix = ExtCurrentLabelPrefix + IntegerToString(slot) + "_";
   ObjectsDeleteAll(0, prefix, 0, OBJ_TEXT);
  }

//+------------------------------------------------------------------+
//| Update current on-chart labels                                   |
//+------------------------------------------------------------------+
void UpdateCurrentLabels(const datetime current_time, const int last_index)
  {
   datetime session_start = SessionStartForTime(current_time);
   datetime session_end   = session_start + ExtRangeDuration;

   if(!IsInsideDisplayWindow(current_time, session_start, session_end))
     {
      HideCurrentLabels();
      return;
     }

   // Recreate the small current-label set at the start of each daily window.
   if(ExtLabelSession != session_start)
     {
      HideCurrentLabels();
      ExtLabelSession = session_start;
      for(int slot = 0; slot < TF_COUNT; slot++)
        {
         ExtLastLabelSourceOpen[slot] = 0;
         ExtLastLabelTestMask[slot]   = 0;
        }
     }

   // The exact end timestamp is only a visual terminal anchor. It retains
   // the levels that were active immediately before the exclusive end.
   datetime evaluation_time = current_time;
   if(evaluation_time == session_end)
      evaluation_time--;

   // Move a TF's labels only when that TF has actually closed a new source
   // candle. M30 labels update every 30 minutes, H1 hourly, H4 every 4 hours;
   // no object work is repeated on every M1 candle.
   for(int slot = 0; slot < TF_COUNT; slot++)
     {
      MqlRates source_bar;
      if(!FindLastClosedRate(slot, evaluation_time, source_bar))
         continue;

      ulong test_mask = SnapshotTestMask(ExtLiveSnapshot[slot]);
      if(ExtLastLabelSourceOpen[slot] == source_bar.time &&
         ExtLastLabelTestMask[slot] == test_mask &&
         ExtLabelsShown)
         continue;

      DeleteCurrentLabelsForTF(slot);
      ShowLabelsForTF(slot, current_time, last_index);
      ExtLastLabelSourceOpen[slot] = source_bar.time;
      ExtLastLabelTestMask[slot]   = test_mask;
     }

   ExtLabelsShown   = true;
   ExtLastLabelTime = current_time;
  }

//+------------------------------------------------------------------+
//| Show labels for one timeframe                                    |
//+------------------------------------------------------------------+
void ShowLabelsForTF(const int slot,
                     const datetime label_time,
                     const int index)
  {
   double pp = BufferValue(slot, LEVEL_PP, index);
   if(pp != EMPTY_VALUE)
      ShowTextLabel(slot, "PP", label_time, pp, InpColorPP);

   for(int level = 1; level <= InpMaxSRLevel; level++)
     {
      double resistance = BufferValue(slot, level, index);
      double support    = BufferValue(slot, 10 + level, index);

      if(resistance != EMPTY_VALUE)
         ShowTextLabel(slot,
                       "R" + IntegerToString(level),
                       label_time,
                       resistance,
                       ResistanceColor(level));

      if(support != EMPTY_VALUE)
         ShowTextLabel(slot,
                       "S" + IntegerToString(level),
                       label_time,
                       support,
                       SupportColor(level));
     }

   if(InpShowLevelsM)
      for(int middle = 1; middle <= 4; middle++)
        {
         double value = BufferValue(slot, 20 + middle, index);
         if(value != EMPTY_VALUE)
            ShowTextLabel(slot,
                          "M" + IntegerToString(middle),
                          label_time,
                          value,
                          InpColorM);
        }
  }

//+------------------------------------------------------------------+
//| Read a buffer value by TF slot and level index                    |
//+------------------------------------------------------------------+
double BufferValue(const int slot, const int level, const int index)
  {
   switch(slot)
     {

      case 0:
         switch(level)
           {
            case 0: return(ExtTF1PPBuffer[index]);
            case 1: return(ExtTF1R1Buffer[index]);
            case 2: return(ExtTF1R2Buffer[index]);
            case 3: return(ExtTF1R3Buffer[index]);
            case 4: return(ExtTF1R4Buffer[index]);
            case 5: return(ExtTF1R5Buffer[index]);
            case 6: return(ExtTF1R6Buffer[index]);
            case 7: return(ExtTF1R7Buffer[index]);
            case 8: return(ExtTF1R8Buffer[index]);
            case 9: return(ExtTF1R9Buffer[index]);
            case 10: return(ExtTF1R10Buffer[index]);
            case 11: return(ExtTF1S1Buffer[index]);
            case 12: return(ExtTF1S2Buffer[index]);
            case 13: return(ExtTF1S3Buffer[index]);
            case 14: return(ExtTF1S4Buffer[index]);
            case 15: return(ExtTF1S5Buffer[index]);
            case 16: return(ExtTF1S6Buffer[index]);
            case 17: return(ExtTF1S7Buffer[index]);
            case 18: return(ExtTF1S8Buffer[index]);
            case 19: return(ExtTF1S9Buffer[index]);
            case 20: return(ExtTF1S10Buffer[index]);
            case 21: return(ExtTF1M1Buffer[index]);
            case 22: return(ExtTF1M2Buffer[index]);
            case 23: return(ExtTF1M3Buffer[index]);
            case 24: return(ExtTF1M4Buffer[index]);
           }
         break;
      case 1:
         switch(level)
           {
            case 0: return(ExtTF2PPBuffer[index]);
            case 1: return(ExtTF2R1Buffer[index]);
            case 2: return(ExtTF2R2Buffer[index]);
            case 3: return(ExtTF2R3Buffer[index]);
            case 4: return(ExtTF2R4Buffer[index]);
            case 5: return(ExtTF2R5Buffer[index]);
            case 6: return(ExtTF2R6Buffer[index]);
            case 7: return(ExtTF2R7Buffer[index]);
            case 8: return(ExtTF2R8Buffer[index]);
            case 9: return(ExtTF2R9Buffer[index]);
            case 10: return(ExtTF2R10Buffer[index]);
            case 11: return(ExtTF2S1Buffer[index]);
            case 12: return(ExtTF2S2Buffer[index]);
            case 13: return(ExtTF2S3Buffer[index]);
            case 14: return(ExtTF2S4Buffer[index]);
            case 15: return(ExtTF2S5Buffer[index]);
            case 16: return(ExtTF2S6Buffer[index]);
            case 17: return(ExtTF2S7Buffer[index]);
            case 18: return(ExtTF2S8Buffer[index]);
            case 19: return(ExtTF2S9Buffer[index]);
            case 20: return(ExtTF2S10Buffer[index]);
            case 21: return(ExtTF2M1Buffer[index]);
            case 22: return(ExtTF2M2Buffer[index]);
            case 23: return(ExtTF2M3Buffer[index]);
            case 24: return(ExtTF2M4Buffer[index]);
           }
         break;
      case 2:
         switch(level)
           {
            case 0: return(ExtTF3PPBuffer[index]);
            case 1: return(ExtTF3R1Buffer[index]);
            case 2: return(ExtTF3R2Buffer[index]);
            case 3: return(ExtTF3R3Buffer[index]);
            case 4: return(ExtTF3R4Buffer[index]);
            case 5: return(ExtTF3R5Buffer[index]);
            case 6: return(ExtTF3R6Buffer[index]);
            case 7: return(ExtTF3R7Buffer[index]);
            case 8: return(ExtTF3R8Buffer[index]);
            case 9: return(ExtTF3R9Buffer[index]);
            case 10: return(ExtTF3R10Buffer[index]);
            case 11: return(ExtTF3S1Buffer[index]);
            case 12: return(ExtTF3S2Buffer[index]);
            case 13: return(ExtTF3S3Buffer[index]);
            case 14: return(ExtTF3S4Buffer[index]);
            case 15: return(ExtTF3S5Buffer[index]);
            case 16: return(ExtTF3S6Buffer[index]);
            case 17: return(ExtTF3S7Buffer[index]);
            case 18: return(ExtTF3S8Buffer[index]);
            case 19: return(ExtTF3S9Buffer[index]);
            case 20: return(ExtTF3S10Buffer[index]);
            case 21: return(ExtTF3M1Buffer[index]);
            case 22: return(ExtTF3M2Buffer[index]);
            case 23: return(ExtTF3M3Buffer[index]);
            case 24: return(ExtTF3M4Buffer[index]);
           }
         break;
     }
   return(EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//| Create or update one TF/type text label                          |
//+------------------------------------------------------------------+
bool ShowTextLabel(const int slot,
                   const string pivot_type,
                   const datetime label_time,
                   const double price,
                   const color label_color)
  {
   string name = ExtCurrentLabelPrefix + IntegerToString(slot) + "_" + pivot_type;
   bool created = false;

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, label_time, price))
        {
         Print(__FUNCTION__, ": ObjectCreate failed for ", name,
               ". Error ", GetLastError());
         return(false);
        }
      created = true;
     }
   else if(!ObjectMove(0, name, 0, label_time, price))
     {
      Print(__FUNCTION__, ": ObjectMove failed for ", name,
            ". Error ", GetLastError());
      return(false);
     }

   ObjectSetString(0, name, OBJPROP_TEXT, ExtTFName[slot] + " " + pivot_type);

   if(created)
     {
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Hide all current on-chart labels                                 |
//+------------------------------------------------------------------+
void HideCurrentLabels()
  {
   // Avoid ObjectsTotal(): it is synchronous and can be expensive in the
   // visual tester. Our own state is sufficient for these private objects.
   if(!ExtLabelsShown && ExtLabelSession == 0)
      return;

   ObjectsDeleteAll(0, ExtCurrentLabelPrefix, 0, OBJ_TEXT);
   ExtLabelsShown   = false;
   ExtLastLabelTime = 0;
   ExtLabelSession  = 0;
   for(int slot = 0; slot < TF_COUNT; slot++)
      {
       ExtLastLabelSourceOpen[slot] = 0;
       ExtLastLabelTestMask[slot]   = 0;
      }
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, ExtPrefixUniq);
   Print("Pivot Multi-TF stopped. Deleted objects with prefix=", ExtPrefixUniq);
  }

//+------------------------------------------------------------------+
//| Track chart scale                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      ChartGetInteger(0, CHART_SCALE, 0, ExtChartScale);
      ExtLastLabelTime = 0;
     }
  }
//+------------------------------------------------------------------+
