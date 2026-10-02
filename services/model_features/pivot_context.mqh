#ifndef MODEL_PIVOT_CONTEXT_MQH
#define MODEL_PIVOT_CONTEXT_MQH

datetime g_model_macro_open = 0;
string g_model_window_id = "";
PivotPriceLadder g_model_ladder;
MqlRates g_model_macro_source;
bool g_model_source_available = false;
bool g_model_window_written = false;
string g_model_window_reason = "SOURCE_UNAVAILABLE";
long g_model_touch_time[7];
long g_model_touch_sequence[7];
int g_model_touch_role[7];
bool g_model_reclaimed[7];
bool g_model_gap_cross[7];
int g_model_pp_arm = 0;
long g_model_pp_arm_time = 0;
double g_model_pp_arm_bid = 0.0;
long g_model_window_first_time = 0;
double g_model_window_first_bid = 0.0;
double g_model_previous_bid = 0.0;
int g_model_tested = -1;

void ModelCloseWindow(const long terminal_time, const string status)
{
  if(!ModelReady() || g_model_macro_open <= 0 || g_model_window_written) return;
  ModelRow row;
  row.Init(MODEL_MACRO_WINDOWS);
  row.Set(MODEL_F_MACRO_WINDOWS_WINDOW_ID, g_model_window_id);
  row.Clock(MODEL_F_MACRO_WINDOWS_OPEN_TIME_MSC, (long)g_model_macro_open * 1000, true);
  row.Integer(MODEL_F_MACRO_WINDOWS_MACRO_SECONDS, PeriodSeconds(g_model_config.macro));
  if(g_model_source_available)
  {
    row.Clock(MODEL_F_MACRO_WINDOWS_SOURCE_TIME_MSC, (long)g_model_macro_source.time * 1000, true);
    row.Clock(MODEL_F_MACRO_WINDOWS_SOURCE_CLOSE_TIME_MSC, (long)g_model_macro_open * 1000, true);
    row.Number(MODEL_F_MACRO_WINDOWS_SOURCE_OPEN, g_model_macro_source.open);
    row.Number(MODEL_F_MACRO_WINDOWS_SOURCE_HIGH, g_model_macro_source.high);
    row.Number(MODEL_F_MACRO_WINDOWS_SOURCE_LOW, g_model_macro_source.low);
    row.Number(MODEL_F_MACRO_WINDOWS_SOURCE_CLOSE, g_model_macro_source.close);
  }
  row.Flag(MODEL_F_MACRO_WINDOWS_VALID, g_model_ladder.valid);
  row.Set(MODEL_F_MACRO_WINDOWS_REASON, g_model_ladder.valid ? "OK" : g_model_window_reason);
  if(g_model_ladder.valid)
  {
    for(int i = 0; i < 7; i++)
    {
      row.Number(MODEL_WINDOW_RAW[i], g_model_ladder.raw_prices[i]);
      row.Number(MODEL_WINDOW_TRADE[i], g_model_ladder.trade_prices[i]);
    }
    double pp = g_model_ladder.trade_prices[3];
    row.Set(MODEL_F_MACRO_WINDOWS_PP_INITIAL_RELATION, g_model_window_first_bid > pp ? "ABOVE" : (g_model_window_first_bid < pp ? "BELOW" : "EQUAL"));
    row.Set(MODEL_F_MACRO_WINDOWS_PP_ROLE, g_model_pp_arm > 0 ? "SUPPORT" : (g_model_pp_arm < 0 ? "RESISTANCE" : "NEUTRAL"));
    if(g_model_pp_arm_time > 0)
    {
      row.Clock(MODEL_F_MACRO_WINDOWS_PP_ARM_TIME_MSC, g_model_pp_arm_time);
      row.Number(MODEL_F_MACRO_WINDOWS_PP_ARM_BID, g_model_pp_arm_bid);
    }
  }
  row.Clock(MODEL_F_MACRO_WINDOWS_FIRST_OBSERVED_TIME_MSC, g_model_window_first_time);
  row.Number(MODEL_F_MACRO_WINDOWS_FIRST_OBSERVED_BID, g_model_window_first_bid);
  row.Clock(MODEL_F_MACRO_WINDOWS_TERMINAL_TIME_MSC, terminal_time);
  row.Set(MODEL_F_MACRO_WINDOWS_TERMINAL_STATUS, status);
  if(ModelWrite(row)) g_model_window_written = true;
}


void ModelContinuationWindowBirth()
{
  if(!g_cont_enabled || !ModelReady()) return;
  string row = g_model_window_id;
  ModelCell(row, ModelInteger((long)g_model_macro_open * 1000));
  ModelCell(row, g_model_source_available ? ModelInteger((long)g_model_macro_source.time * 1000) : MODEL_NULL);
  ModelCell(row, g_model_source_available ? ModelInteger((long)g_model_macro_open * 1000) : MODEL_NULL);
  ModelCell(row, ModelInteger(PeriodSeconds(g_model_config.macro)));
  ModelCell(row, g_model_source_available ? ModelNumber(g_model_macro_source.open) : MODEL_NULL);
  ModelCell(row, g_model_source_available ? ModelNumber(g_model_macro_source.high) : MODEL_NULL);
  ModelCell(row, g_model_source_available ? ModelNumber(g_model_macro_source.low) : MODEL_NULL);
  ModelCell(row, g_model_source_available ? ModelNumber(g_model_macro_source.close) : MODEL_NULL);
  ModelCell(row, ModelBoolean(g_model_ladder.valid));
  ModelCell(row, g_model_ladder.valid ? "OK" : g_model_window_reason);
  string raw = "", trade = "";
  for(int i = 0; i < 7; i++)
  {
    ModelCell(raw, g_model_ladder.valid ? ModelNumber(g_model_ladder.raw_prices[i]) : MODEL_NULL);
    ModelCell(trade, g_model_ladder.valid ? ModelNumber(g_model_ladder.trade_prices[i]) : MODEL_NULL);
  }
  ModelCell(row, ModelContinuationHex(raw)); ModelCell(row, ModelContinuationHex(trade));
  ModelCell(row, ModelInteger(g_model_window_first_time));
  ModelCell(row, ModelNumber(g_model_window_first_bid));
  if(!ModelContinuationBirth(row) && !g_model_failed) ModelFail("CONTINUATION_WINDOW_BIRTH");
}

void ModelRefreshContext(const MqlTick &tick, const long sequence)
{
  if(!ModelReady()) return;
  datetime bar_open = iTime(g_model_config.symbol, g_model_config.macro, 0);
  if(bar_open <= 0 || bar_open > tick.time) return;
  if(bar_open != g_model_macro_open)
  {
    ModelCloseWindow(tick.time_msc, "ROLLED_OVER");
    g_model_macro_open = bar_open;
    g_model_window_id = g_model_config.symbol + ":" + ModelInteger(PeriodSeconds(g_model_config.macro)) + ":" + ModelInteger(bar_open);
    g_model_window_written = false;
    g_model_ladder.Reset();
    ArrayInitialize(g_model_touch_time, 0);
    ArrayInitialize(g_model_touch_sequence, 0);
    ArrayInitialize(g_model_touch_role, 0);
    ArrayInitialize(g_model_reclaimed, false);
    ArrayInitialize(g_model_gap_cross, false);
    g_model_pp_arm = 0;
    g_model_pp_arm_time = 0;
    g_model_previous_bid = 0.0;
    g_model_tested = -1;
    g_model_window_first_time = tick.time_msc;
    g_model_window_first_bid = tick.bid;
    MqlRates source[1];
    g_model_window_reason = "SOURCE_UNAVAILABLE";
    g_model_source_available = CopyRates(g_model_config.symbol, g_model_config.macro, 1, 1, source) == 1;
    if(g_model_source_available)
    {
      g_model_macro_source = source[0];
      if(g_cont_enabled) ModelContinuationHistory("MACRO_SOURCE", ModelContinuationRate(source[0]));
      if(source[0].time >= bar_open) g_model_window_reason = "NON_CAUSAL_SOURCE";
      else if(!BuildClassicPivotPriceLadder(g_model_config.symbol, source[0], g_model_ladder, g_model_window_reason))
        g_model_ladder.valid = false;
    }
    ModelContinuationWindowBirth();
  }
  if(!g_model_ladder.valid) return;
  double pp = g_model_ladder.trade_prices[3];
  if(g_model_pp_arm == 0)
  {
    if(tick.bid > pp) g_model_pp_arm = 1;
    else if(tick.bid < pp) g_model_pp_arm = -1;
    if(g_model_pp_arm != 0)
    {
      g_model_pp_arm_time = tick.time_msc;
      g_model_pp_arm_bid = tick.bid;
    }
  }
  for(int i = 0; i < 7; i++)
  {
    double price = g_model_ladder.trade_prices[i];
    int role = i < 3 ? 1 : (i > 3 ? -1 : g_model_pp_arm);
    bool beyond = role > 0 ? tick.bid <= price : (role < 0 && tick.bid >= price);
    bool approached = g_model_previous_bid > 0.0 && (role > 0 ? g_model_previous_bid > price : g_model_previous_bid < price);
    if(beyond && (approached || (i != 3 && g_model_previous_bid == 0.0)))
    {
      g_model_touch_time[i] = tick.time_msc;
      g_model_touch_sequence[i] = sequence;
      g_model_touch_role[i] = role;
      g_model_gap_cross[i] = tick.bid != price;
      g_model_reclaimed[i] = false;
      if(g_model_tested < 0 || g_model_touch_sequence[g_model_tested] < sequence ||
         (g_model_touch_sequence[g_model_tested] == sequence && MathAbs(i - 3) > MathAbs(g_model_tested - 3))) g_model_tested = i;
    }
    if(g_model_touch_time[i] > 0 && (g_model_touch_role[i] > 0 ? tick.bid > price : tick.bid < price))
      g_model_reclaimed[i] = true;
  }
  g_model_previous_bid = tick.bid;
}

string ModelInterval(const double price, double &lower, double &upper)
{
  lower = EMPTY_VALUE;
  upper = EMPTY_VALUE;
  if(!g_model_ladder.valid) return MODEL_NULL;
  if(price < g_model_ladder.trade_prices[0]) { upper = g_model_ladder.trade_prices[0]; return "BELOW_S3"; }
  for(int i = 0; i < 7; i++)
  {
    if(price == g_model_ladder.trade_prices[i])
    {
      lower = price; upper = price;
      return "AT_" + ModelLevel(i);
    }
    if(i < 6 && price < g_model_ladder.trade_prices[i + 1])
    {
      lower = g_model_ladder.trade_prices[i]; upper = g_model_ladder.trade_prices[i + 1];
      return ModelLevel(i) + "_TO_" + ModelLevel(i + 1);
    }
  }
  lower = g_model_ladder.trade_prices[6];
  return "ABOVE_R3";
}

bool ModelCaptureContext(ModelRow &row, const MqlTick &tick)
{
  bool valid = g_model_ladder.valid && g_model_macro_open > 0 && g_model_macro_open <= tick.time;
  row.Flag(MODEL_F_FEATURE_SNAPSHOTS_PIVOT_COMPLETE, valid);
  for(int i = 0; i < 7; i++)
  {
    row.Flag(MODEL_PIVOT_RECLAIMED[i], valid && g_model_reclaimed[i]);
    row.Flag(MODEL_PIVOT_GAP_CROSS[i], valid && g_model_gap_cross[i]);
    if(!valid) continue;
    row.Number(MODEL_PIVOT_PRICE[i], g_model_ladder.trade_prices[i]);
    if(g_model_touch_time[i] > 0)
    {
      row.Clock(MODEL_PIVOT_TOUCH_TIME_MSC[i], g_model_touch_time[i]);
      row.Integer(MODEL_PIVOT_TOUCH_SEQUENCE[i], g_model_touch_sequence[i]);
      row.Set(MODEL_PIVOT_ROLE[i], g_model_touch_role[i] > 0 ? "SUPPORT" : "RESISTANCE");
    }
  }
  if(!valid) return false;
  double lower, upper;
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_SIGNAL_ZONE, ModelInterval(tick.bid, lower, upper));
  row.Number(MODEL_F_FEATURE_SNAPSHOTS_ZONE_LOWER_PRICE, lower);
  row.Number(MODEL_F_FEATURE_SNAPSHOTS_ZONE_UPPER_PRICE, upper);
  if(g_model_tested < 0) { row.Set(MODEL_F_FEATURE_SNAPSHOTS_SIGNAL_VS_TESTED_PIVOT, "UNTESTED"); return true; }
  int selected = g_model_tested;
  double price = g_model_ladder.trade_prices[selected];
  string role = g_model_touch_role[selected] > 0 ? "SUPPORT" : "RESISTANCE";
  string side = tick.bid > price ? "ABOVE" : (tick.bid < price ? "BELOW" : "AT");
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_SIGNAL_VS_TESTED_PIVOT, side + "_" + role);
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_TESTED_LEVEL, ModelLevel(selected));
  row.Number(MODEL_F_FEATURE_SNAPSHOTS_TESTED_PRICE, price);
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_TESTED_ROLE, role);
  row.Number(MODEL_F_FEATURE_SNAPSHOTS_TESTED_DISTANCE_PRICE, tick.bid - price);
  row.Number(MODEL_F_FEATURE_SNAPSHOTS_TESTED_DISTANCE_POINTS, (tick.bid - price) / g_model_point);
  row.Clock(MODEL_F_FEATURE_SNAPSHOTS_TESTED_TOUCH_TIME_MSC, g_model_touch_time[selected]);
  row.Integer(MODEL_F_FEATURE_SNAPSHOTS_TESTED_SEQUENCE, g_model_touch_sequence[selected]);
  row.Integer(MODEL_F_FEATURE_SNAPSHOTS_TESTED_AGE_MS, tick.time_msc - g_model_touch_time[selected]);
  row.Flag(MODEL_F_FEATURE_SNAPSHOTS_TESTED_RECLAIMED, g_model_reclaimed[selected]);
  row.Flag(MODEL_F_FEATURE_SNAPSHOTS_TESTED_GAP_CROSS, g_model_gap_cross[selected]);
  return true;
}

#endif
