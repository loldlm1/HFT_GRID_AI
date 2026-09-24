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
  row.Set("window_id", g_model_window_id);
  row.Clock("open_time_msc", (long)g_model_macro_open * 1000, true);
  row.Integer("macro_seconds", PeriodSeconds(g_model_config.macro));
  if(g_model_source_available)
  {
    row.Clock("source_time_msc", (long)g_model_macro_source.time * 1000, true);
    row.Clock("source_close_time_msc", (long)(g_model_macro_source.time + PeriodSeconds(g_model_config.macro)) * 1000, true);
    row.Number("source_open", g_model_macro_source.open);
    row.Number("source_high", g_model_macro_source.high);
    row.Number("source_low", g_model_macro_source.low);
    row.Number("source_close", g_model_macro_source.close);
  }
  row.Flag("valid", g_model_ladder.valid);
  row.Set("reason", g_model_ladder.valid ? "OK" : g_model_window_reason);
  if(g_model_ladder.valid)
  {
    for(int i = 0; i < 7; i++)
    {
      row.Number("raw_" + ModelLowerLevel(i) + "_price", g_model_ladder.raw_prices[i]);
      row.Number("trade_" + ModelLowerLevel(i) + "_price", g_model_ladder.trade_prices[i]);
    }
    double pp = g_model_ladder.trade_prices[3];
    row.Set("pp_initial_relation", g_model_window_first_bid > pp ? "ABOVE" : (g_model_window_first_bid < pp ? "BELOW" : "EQUAL"));
    row.Set("pp_role", g_model_pp_arm > 0 ? "SUPPORT" : (g_model_pp_arm < 0 ? "RESISTANCE" : "NEUTRAL"));
    if(g_model_pp_arm_time > 0)
    {
      row.Clock("pp_arm_time_msc", g_model_pp_arm_time);
      row.Number("pp_arm_bid", g_model_pp_arm_bid);
    }
  }
  row.Clock("first_observed_time_msc", g_model_window_first_time);
  row.Number("first_observed_bid", g_model_window_first_bid);
  row.Clock("terminal_time_msc", terminal_time);
  row.Set("terminal_status", status);
  if(ModelWrite(row)) g_model_window_written = true;
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
      if(source[0].time >= bar_open) g_model_window_reason = "NON_CAUSAL_SOURCE";
      else if(!BuildClassicPivotPriceLadder(g_model_config.symbol, source[0], g_model_ladder, g_model_window_reason))
        g_model_ladder.valid = false;
    }
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
  row.Flag("pivot_complete", valid);
  for(int i = 0; i < 7; i++)
  {
    string prefix = "pivot_" + ModelLowerLevel(i);
    row.Flag(prefix + "_reclaimed", valid && g_model_reclaimed[i]);
    row.Flag(prefix + "_gap_cross", valid && g_model_gap_cross[i]);
    if(!valid) continue;
    row.Number(prefix + "_price", g_model_ladder.trade_prices[i]);
    if(g_model_touch_time[i] > 0)
    {
      row.Clock(prefix + "_touch_time_msc", g_model_touch_time[i]);
      row.Integer(prefix + "_touch_sequence", g_model_touch_sequence[i]);
      row.Set(prefix + "_role", g_model_touch_role[i] > 0 ? "SUPPORT" : "RESISTANCE");
    }
  }
  if(!valid) return false;
  double lower, upper;
  row.Set("signal_zone", ModelInterval(tick.bid, lower, upper));
  row.Number("zone_lower_price", lower);
  row.Number("zone_upper_price", upper);
  if(g_model_tested < 0) { row.Set("signal_vs_tested_pivot", "UNTESTED"); return true; }
  int selected = g_model_tested;
  double price = g_model_ladder.trade_prices[selected];
  string role = g_model_touch_role[selected] > 0 ? "SUPPORT" : "RESISTANCE";
  string side = tick.bid > price ? "ABOVE" : (tick.bid < price ? "BELOW" : "AT");
  row.Set("signal_vs_tested_pivot", side + "_" + role);
  row.Set("tested_level", ModelLevel(selected));
  row.Number("tested_price", price);
  row.Set("tested_role", role);
  row.Number("tested_distance_price", tick.bid - price);
  row.Number("tested_distance_points", (tick.bid - price) / g_model_point);
  row.Clock("tested_touch_time_msc", g_model_touch_time[selected]);
  row.Integer("tested_sequence", g_model_touch_sequence[selected]);
  row.Integer("tested_age_ms", tick.time_msc - g_model_touch_time[selected]);
  row.Flag("tested_reclaimed", g_model_reclaimed[selected]);
  row.Flag("tested_gap_cross", g_model_gap_cross[selected]);
  return true;
}

#endif
