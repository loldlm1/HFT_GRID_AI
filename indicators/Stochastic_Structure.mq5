// Derived from Stochastic_Structure by @loldlm.
#property copyright "Copyright @loldlm"
#property link "https://t.me/loldlm"
#property version "2.00"
#property description "Closed-candle stochastic structure with source-timeframe pivots."
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots 6
#property indicator_type1 DRAW_NONE
#property indicator_type2 DRAW_NONE
#property indicator_type3 DRAW_NONE
#property indicator_type4 DRAW_NONE
#property indicator_type5 DRAW_NONE
#property indicator_type6 DRAW_NONE
#property indicator_label1 "Confirmed pivot price"
#property indicator_label2 "Pivot kind (+1 high/-1 low)"
#property indicator_label3 "Structure class"
#property indicator_label4 "Pivot time"
#property indicator_label5 "Confirmation time"
#property indicator_label6 "Swing stochastic extreme"

enum ENUM_STRUCTURE_CLASS
{
  STRUCTURE_NONE = 0,
  STRUCTURE_HIGH = 1,
  STRUCTURE_LOW = 2,
  STRUCTURE_HH = 3,
  STRUCTURE_LH = 4,
  STRUCTURE_HL = 5,
  STRUCTURE_LL = 6,
  STRUCTURE_EQ = 7
};

struct StructurePivot
{
  datetime time;
  datetime confirmed_at;
  double price;
  double stochastic_extreme;
  int kind;
  ENUM_STRUCTURE_CLASS classification;
};

struct StructureState
{
  int kind;
  datetime last_bar;
  datetime candidate_time;
  double candidate_price;
  double stochastic_extreme;
  bool has_high;
  bool has_low;
  double last_high;
  double last_low;
};

void ResetStructure(StructureState &state)
{
  state.kind = 0;
  state.last_bar = 0;
  state.candidate_time = 0;
  state.candidate_price = 0.0;
  state.stochastic_extreme = 0.0;
  state.has_high = false;
  state.has_low = false;
  state.last_high = 0.0;
  state.last_low = 0.0;
}

void StartStructureLeg(StructureState &state, const int kind,
                       const datetime time, const double price,
                       const double stochastic)
{
  state.kind = kind;
  state.candidate_time = time;
  state.candidate_price = price;
  state.stochastic_extreme = stochastic;
}

ENUM_STRUCTURE_CLASS ClassifyStructure(const StructureState &state,
                                       const double tick_size)
{
  bool has_previous = state.kind == 1 ? state.has_high : state.has_low;
  if(!has_previous)
    return state.kind == 1 ? STRUCTURE_HIGH : STRUCTURE_LOW;

  double previous = state.kind == 1 ? state.last_high : state.last_low;
  double current_ticks = MathRound(state.candidate_price / tick_size);
  double previous_ticks = MathRound(previous / tick_size);
  if(current_ticks == previous_ticks)
    return STRUCTURE_EQ;
  if(state.kind == 1)
    return current_ticks > previous_ticks ? STRUCTURE_HH : STRUCTURE_LH;
  return current_ticks > previous_ticks ? STRUCTURE_HL : STRUCTURE_LL;
}

// One chronological closed candle per call. A confirming candle starts the new
// leg; its unknown intrabar high/low ordering cannot replace the outgoing pivot.
bool AdvanceStructure(StructureState &state, const datetime time,
                      const datetime confirmed_at, const double upper_price,
                      const double lower_price, const double stochastic,
                      const double tick_size, StructurePivot &pivot)
{
  pivot.kind = 0;
  if(time <= state.last_bar || confirmed_at <= time ||
     !MathIsValidNumber(upper_price) || !MathIsValidNumber(lower_price) ||
     upper_price < lower_price || !MathIsValidNumber(stochastic) ||
     stochastic < 0.0 || stochastic > 100.0 ||
     !MathIsValidNumber(tick_size) || tick_size <= 0.0)
    return false;

  state.last_bar = time;
  if(state.kind == 0)
  {
    if(stochastic > 80.0)
      StartStructureLeg(state, 1, time, upper_price, stochastic);
    else if(stochastic < 20.0)
      StartStructureLeg(state, -1, time, lower_price, stochastic);
    return true;
  }

  bool reversal = state.kind == 1
                  ? stochastic < 20.0 && state.candidate_price > lower_price
                  : stochastic > 80.0 && state.candidate_price < upper_price;
  if(reversal)
  {
    pivot.time = state.candidate_time;
    pivot.confirmed_at = confirmed_at;
    pivot.price = state.candidate_price;
    pivot.stochastic_extreme = state.stochastic_extreme;
    pivot.kind = state.kind;
    pivot.classification = ClassifyStructure(state, tick_size);
    if(state.kind == 1)
    {
      state.last_high = pivot.price;
      state.has_high = true;
    }
    else
    {
      state.last_low = pivot.price;
      state.has_low = true;
    }
    int next_kind = -state.kind;
    StartStructureLeg(state, next_kind, time,
                      next_kind == 1 ? upper_price : lower_price, stochastic);
    return true;
  }

  double price = state.kind == 1 ? upper_price : lower_price;
  bool improved = state.kind == 1 ? price > state.candidate_price
                                  : price < state.candidate_price;
  if(improved)
  {
    state.candidate_price = price;
    state.candidate_time = time;
  }
  state.stochastic_extreme = state.kind == 1
                            ? MathMax(state.stochastic_extreme, stochastic)
                            : MathMin(state.stochastic_extreme, stochastic);
  return true;
}

input int InpKPeriod = 5;
input int InpDPeriod = 3;
input int InpSlowing = 3;
input ENUM_STO_PRICE InpPriceMode = STO_LOWHIGH;
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT;
input bool InpShowLabels = true;
input int InpMaxPivots = 300; // Maximum drawn pivots (2..2000)

double pivot_price_buffer[];
double pivot_kind_buffer[];
double structure_class_buffer[];
double pivot_time_buffer[];
double confirmation_time_buffer[];
double stochastic_extreme_buffer[];

int stochastic_handle = INVALID_HANDLE;
ENUM_TIMEFRAMES source_timeframe;
double price_tick_size = 0.0;
StructureState structure_state;
StructurePivot visible_pivots[];
int visible_count = 0;
int visible_head = 0;
string object_prefix = "";
bool draw_enabled = false;
bool ready = false;
bool diagnostic_reported = false;
datetime processed_source_open = 0;
datetime last_chart_open = 0;
datetime source_first_date = 0;
int processed_source_bars = 0;
MqlRates source_rates[];
double source_stochastic[];
const int COPY_BATCH_SIZE = 4096;

void ReportFailure(const string operation)
{
  if(!diagnostic_reported)
  {
    PrintFormat("Stochastic Structure: %s (error %d)", operation, GetLastError());
    diagnostic_reported = true;
  }
}

string StructureLabel(const ENUM_STRUCTURE_CLASS classification)
{
  switch(classification)
  {
    case STRUCTURE_HIGH: return "H";
    case STRUCTURE_LOW: return "L";
    case STRUCTURE_HH: return "HH";
    case STRUCTURE_LH: return "LH";
    case STRUCTURE_HL: return "HL";
    case STRUCTURE_LL: return "LL";
    case STRUCTURE_EQ: return "EQ";
    default: return "";
  }
}

string PivotObjectName(const StructurePivot &pivot, const string suffix)
{
  return object_prefix + IntegerToString((long)pivot.time) + suffix;
}

void DeletePivotObjects(const StructurePivot &pivot)
{
  if(InpShowLabels && !ObjectDelete(0, PivotObjectName(pivot, "_label")))
    ReportFailure("cannot queue label removal");
}

bool DrawPivot(const StructurePivot &pivot, const StructurePivot &previous,
               const bool has_previous)
{
  if(has_previous)
  {
    string line_name = PivotObjectName(pivot, "_line");
    if(!ObjectCreate(0, line_name, OBJ_TREND, 0, previous.time, previous.price,
                     pivot.time, pivot.price) ||
       !ObjectSetInteger(0, line_name, OBJPROP_RAY_LEFT, false) ||
       !ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false) ||
       !ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrRed) ||
       !ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2) ||
       !ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false) ||
       !ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true))
      return false;
  }
  if(!InpShowLabels)
    return true;

  string label_name = PivotObjectName(pivot, "_label");
  string tooltip = StringFormat("%s %s | pivot %s | confirmed %s | price %s",
                                EnumToString(source_timeframe), StructureLabel(pivot.classification),
                                TimeToString(pivot.time, TIME_DATE | TIME_MINUTES),
                                TimeToString(pivot.confirmed_at, TIME_DATE | TIME_MINUTES),
                                DoubleToString(pivot.price, _Digits));
  return ObjectCreate(0, label_name, OBJ_TEXT, 0, pivot.time, pivot.price) &&
         ObjectSetString(0, label_name, OBJPROP_TEXT, StructureLabel(pivot.classification)) &&
         ObjectSetString(0, label_name, OBJPROP_TOOLTIP, tooltip) &&
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR,
                          pivot.kind == 1 ? ANCHOR_LOWER : ANCHOR_UPPER) &&
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed) &&
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 9) &&
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false) &&
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
}

void RememberPivot(const StructurePivot &pivot, const bool render)
{
  int previous_index = (visible_head + visible_count - 1) % InpMaxPivots;
  StructurePivot previous = {};
  bool has_previous = visible_count > 0;
  if(has_previous)
    previous = visible_pivots[previous_index];
  int write_index = (visible_head + visible_count) % InpMaxPivots;
  if(visible_count == InpMaxPivots)
  {
    if(render)
      DeletePivotObjects(visible_pivots[visible_head]);
    visible_head = (visible_head + 1) % InpMaxPivots;
    if(render && !ObjectDelete(0, PivotObjectName(visible_pivots[visible_head], "_line")))
      ReportFailure("cannot queue oldest segment removal");
  }
  else
    visible_count++;
  visible_pivots[write_index] = pivot;
  if(render && !DrawPivot(pivot, previous, has_previous))
    ReportFailure("cannot queue pivot drawing");
}

void DrawHistory()
{
  if(!draw_enabled)
    return;
  StructurePivot previous = {};
  for(int i = 0; i < visible_count && !IsStopped(); i++)
  {
    int index = (visible_head + i) % InpMaxPivots;
    if(!DrawPivot(visible_pivots[index], previous, i > 0))
      ReportFailure("cannot queue history drawing");
    previous = visible_pivots[index];
  }
  ChartRedraw();
}

void ClearOutputBar(const int index)
{
  pivot_price_buffer[index] = EMPTY_VALUE;
  pivot_kind_buffer[index] = EMPTY_VALUE;
  structure_class_buffer[index] = EMPTY_VALUE;
  pivot_time_buffer[index] = EMPTY_VALUE;
  confirmation_time_buffer[index] = EMPTY_VALUE;
  stochastic_extreme_buffer[index] = EMPTY_VALUE;
}

void ResetCalculation()
{
  ResetStructure(structure_state);
  ready = false;
  processed_source_open = 0;
  processed_source_bars = 0;
  source_first_date = 0;
  visible_count = 0;
  visible_head = 0;
  ArrayInitialize(pivot_price_buffer, EMPTY_VALUE);
  ArrayInitialize(pivot_kind_buffer, EMPTY_VALUE);
  ArrayInitialize(structure_class_buffer, EMPTY_VALUE);
  ArrayInitialize(pivot_time_buffer, EMPTY_VALUE);
  ArrayInitialize(confirmation_time_buffer, EMPTY_VALUE);
  ArrayInitialize(stochastic_extreme_buffer, EMPTY_VALUE);
  if(draw_enabled && ObjectsDeleteAll(0, object_prefix) < 0)
    ReportFailure("cannot clear owned drawings");
}

void PublishPivot(const StructurePivot &pivot, const datetime &chart_time[],
                  const int rates_total)
{
  if(pivot.confirmed_at < chart_time[0])
    return;
  int lower = 0;
  int upper = rates_total;
  while(lower < upper)
  {
    int middle = lower + (upper - lower) / 2;
    if(chart_time[middle] <= pivot.confirmed_at)
      lower = middle + 1;
    else
      upper = middle;
  }
  int index = lower - 1;
  // For a source TF below the chart TF, the latest confirmation in that chart
  // candle wins in the buffers. Objects retain every visible source pivot.
  pivot_price_buffer[index] = pivot.price;
  pivot_kind_buffer[index] = pivot.kind;
  structure_class_buffer[index] = pivot.classification;
  pivot_time_buffer[index] = (double)pivot.time;
  confirmation_time_buffer[index] = (double)pivot.confirmed_at;
  stochastic_extreme_buffer[index] = pivot.stochastic_extreme;
}

int OnInit()
{
  if(InpKPeriod < 1 || InpDPeriod < 1 || InpSlowing < 1 ||
     (long)InpKPeriod + InpDPeriod + InpSlowing > INT_MAX - 2 ||
     InpMaxPivots < 2 || InpMaxPivots > 2000 ||
     (InpPriceMode != STO_LOWHIGH && InpPriceMode != STO_CLOSECLOSE))
  {
    Print("Stochastic Structure: positive periods and 2..2000 visible pivots required.");
    return INIT_PARAMETERS_INCORRECT;
  }
  source_timeframe = InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe;
  if(PeriodSeconds(source_timeframe) <= 0 ||
     !SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, price_tick_size) ||
     !MathIsValidNumber(price_tick_size) || price_tick_size <= 0.0)
    return INIT_PARAMETERS_INCORRECT;

  if(!SetIndexBuffer(0, pivot_price_buffer, INDICATOR_DATA) ||
     !SetIndexBuffer(1, pivot_kind_buffer, INDICATOR_DATA) ||
     !SetIndexBuffer(2, structure_class_buffer, INDICATOR_DATA) ||
     !SetIndexBuffer(3, pivot_time_buffer, INDICATOR_DATA) ||
     !SetIndexBuffer(4, confirmation_time_buffer, INDICATOR_DATA) ||
     !SetIndexBuffer(5, stochastic_extreme_buffer, INDICATOR_DATA) ||
     ArrayResize(visible_pivots, InpMaxPivots) != InpMaxPivots)
    return INIT_FAILED;
  for(int plot = 0; plot < 6; plot++)
    if(!PlotIndexSetDouble(plot, PLOT_EMPTY_VALUE, EMPTY_VALUE))
      return INIT_FAILED;
  if(!IndicatorSetInteger(INDICATOR_DIGITS, _Digits) ||
     !IndicatorSetString(INDICATOR_SHORTNAME,
                         StringFormat("Stoch Structure 2.00 (%s,%d,%d,%d,%s)",
                                      EnumToString(source_timeframe), InpKPeriod,
                                      InpDPeriod, InpSlowing,
                                      InpPriceMode == STO_LOWHIGH ? "High/Low" : "Close/Close")))
    return INIT_FAILED;

  stochastic_handle = iStochastic(_Symbol, source_timeframe, InpKPeriod,
                                  InpDPeriod, InpSlowing, MODE_SMA, InpPriceMode);
  if(stochastic_handle == INVALID_HANDLE)
  {
    ReportFailure("cannot create stochastic handle");
    return INIT_FAILED;
  }
  draw_enabled = !MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE);
  object_prefix = StringFormat("SST_%I64u_%I64u_", GetTickCount64(), GetMicrosecondCount());
  ResetStructure(structure_state);
  return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
  if(rates_total < 1 || !ArraySetAsSeries(time, false))
    return 0;
  bool rebuild = prev_calculated == 0 || prev_calculated > rates_total || !ready;
  if(rebuild)
    ResetCalculation();
  else
  {
    for(int i = prev_calculated; i < rates_total; i++)
      ClearOutputBar(i);
    // MT5 can roll its history window without increasing rates_total.
    if(time[rates_total - 1] != last_chart_open)
      ClearOutputBar(rates_total - 1);
  }
  last_chart_open = time[rates_total - 1];

  int source_bars = Bars(_Symbol, source_timeframe);
  datetime current_open = iTime(_Symbol, source_timeframe, 0);
  long first_date = 0;
  if(source_bars <= InpKPeriod + InpSlowing || current_open == 0 ||
     BarsCalculated(stochastic_handle) < source_bars ||
     !SeriesInfoInteger(_Symbol, source_timeframe, SERIES_FIRSTDATE, first_date))
    return rebuild ? 0 : rates_total;

  if(!rebuild && ((datetime)first_date < source_first_date ||
                  source_bars < processed_source_bars))
  {
    ResetCalculation();
    rebuild = true;
  }
  if(!rebuild && current_open == processed_source_open &&
     source_bars == processed_source_bars)
    return rates_total;

  int oldest_shift = source_bars - 1 - (InpKPeriod + InpSlowing - 2);
  if(!rebuild)
  {
    int previous_shift = iBarShift(_Symbol, source_timeframe, structure_state.last_bar, true);
    if(previous_shift < 1 || source_bars - processed_source_bars > previous_shift - 1)
    {
      ResetCalculation();
      rebuild = true;
    }
    else
      oldest_shift = previous_shift - 1;
  }

  bool new_pivot = false;
  for(int oldest = oldest_shift; oldest >= 1 && !IsStopped();)
  {
    int count = MathMin(COPY_BATCH_SIZE, oldest);
    int newest = oldest - count + 1;
    // Include the following bar solely for the real confirmation clock. It is
    // never used for stochastic decisions or candidate prices.
    if(CopyRates(_Symbol, source_timeframe, newest - 1, count + 1, source_rates) != count + 1 ||
       CopyBuffer(stochastic_handle, MAIN_LINE, newest, count, source_stochastic) != count ||
       iTime(_Symbol, source_timeframe, 0) != current_open)
    {
      ready = false;
      return 0;
    }
    for(int i = 0; i < count && !IsStopped(); i++)
    {
      double upper_price = InpPriceMode == STO_CLOSECLOSE ? source_rates[i].close : source_rates[i].high;
      double lower_price = InpPriceMode == STO_CLOSECLOSE ? source_rates[i].close : source_rates[i].low;
      StructurePivot pivot;
      if(!AdvanceStructure(structure_state, source_rates[i].time, source_rates[i + 1].time,
                            upper_price, lower_price, source_stochastic[i], price_tick_size, pivot))
      {
        ReportFailure("invalid source candle or stochastic value");
        ready = false;
        return 0;
      }
      if(pivot.kind != 0)
      {
        PublishPivot(pivot, time, rates_total);
        RememberPivot(pivot, draw_enabled && !rebuild);
        new_pivot = true;
      }
    }
    oldest = newest - 1;
  }
  if(IsStopped())
    return 0;
  if(rebuild)
    DrawHistory();
  else if(draw_enabled && new_pivot)
    ChartRedraw();
  ready = true;
  processed_source_open = current_open;
  processed_source_bars = source_bars;
  source_first_date = (datetime)first_date;
  return rates_total;
}

void OnDeinit(const int reason)
{
  if(stochastic_handle != INVALID_HANDLE)
  {
    // The tester owns indicator-handle teardown; release is a live-terminal API.
    if(!MQLInfoInteger(MQL_TESTER) && !IndicatorRelease(stochastic_handle))
      ReportFailure("cannot release stochastic handle");
    stochastic_handle = INVALID_HANDLE;
  }
  if(draw_enabled && object_prefix != "" && ObjectsDeleteAll(0, object_prefix) < 0)
    ReportFailure("cannot remove owned drawings");
}
