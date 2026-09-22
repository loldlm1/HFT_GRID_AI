#ifndef CANDLE_CONTEXT_MQH
#define CANDLE_CONTEXT_MQH

datetime g_candle_macro_open = 0;
string g_candle_window_id = "";
PivotPriceLadder g_candle_ladder;
long g_candle_touch_time[7];
long g_candle_touch_sequence[7];
int g_candle_touch_role[7];
bool g_candle_reclaimed[7];
bool g_candle_gap_cross[7];
int g_candle_pp_arm = 0;
double g_candle_previous_bid = 0.0;
int g_candle_context = -1;

void CandleRefreshContext(const MqlTick &tick)
{
  if(!Enable_Signal_Feature_Export || g_candle_export_failed) return;
  datetime bar_open = iTime(_Symbol, Macro_Timeframe, 0);
  if(bar_open <= 0 || bar_open > tick.time) return;
  if(bar_open != g_candle_macro_open)
  {
    g_candle_macro_open = bar_open;
    g_candle_window_id = _Symbol + ":" + CandleInteger(g_macro_seconds) + ":" + CandleInteger(bar_open);
    g_candle_ladder.Reset();
    ArrayInitialize(g_candle_touch_time, 0);
    ArrayInitialize(g_candle_touch_sequence, 0);
    ArrayInitialize(g_candle_touch_role, 0);
    ArrayInitialize(g_candle_reclaimed, false);
    ArrayInitialize(g_candle_gap_cross, false);
    g_candle_pp_arm = 0;
    g_candle_previous_bid = 0.0;
    g_candle_context = -1;
    MqlRates source[1];
    string reason = "SOURCE_UNAVAILABLE";
    bool available = CopyRates(_Symbol, Macro_Timeframe, 1, 1, source) == 1;
    bool valid = available && source[0].time < bar_open &&
                 BuildClassicPivotPriceLadder(_Symbol, source[0], g_candle_ladder, reason);
    string row = Signal_Feature_Run_Id;
    CandleCell(row, g_candle_window_id);
    CandleCell(row, CandleInteger((long)bar_open * 1000));
    CandleCell(row, available ? CandleInteger((long)source[0].time * 1000) : "\\N");
    CandleCell(row, CandleInteger(g_macro_seconds));
    CandleCell(row, available ? CandleNumber(source[0].open) : "\\N");
    CandleCell(row, available ? CandleNumber(source[0].high) : "\\N");
    CandleCell(row, available ? CandleNumber(source[0].low) : "\\N");
    CandleCell(row, available ? CandleNumber(source[0].close) : "\\N");
    CandleCell(row, CandleBoolean(valid));
    CandleCell(row, valid ? "OK" : reason);
    for(int i = 0; i < 7; i++) CandleCell(row, valid ? CandleNumber(g_candle_ladder.trade_prices[i]) : "\\N");
    CandleWrite(CANDLE_WINDOWS, row);
  }
  if(!g_candle_ladder.valid) return;
  double pp = g_candle_ladder.trade_prices[3];
  if(g_candle_pp_arm == 0)
  {
    if(tick.bid > pp) g_candle_pp_arm = 1;
    else if(tick.bid < pp) g_candle_pp_arm = -1;
  }
  for(int i = 0; i < 7; i++)
  {
    double level = g_candle_ladder.trade_prices[i];
    int role = i < 3 ? 1 : (i > 3 ? -1 : g_candle_pp_arm);
    bool beyond = role > 0 ? tick.bid <= level : (role < 0 && tick.bid >= level);
    bool approached = g_candle_previous_bid > 0.0 &&
                      (role > 0 ? g_candle_previous_bid > level : g_candle_previous_bid < level);
    if(beyond && (approached || (i != 3 && g_candle_previous_bid == 0.0)))
    {
      g_candle_touch_time[i] = tick.time_msc;
      g_candle_touch_sequence[i] = g_candle_sequence;
      g_candle_touch_role[i] = role;
      g_candle_gap_cross[i] = tick.bid != level;
      g_candle_reclaimed[i] = false;
      if(g_candle_context < 0 || g_candle_touch_sequence[g_candle_context] < g_candle_sequence ||
         (g_candle_touch_sequence[g_candle_context] == g_candle_sequence &&
          MathAbs(i - 3) > MathAbs(g_candle_context - 3))) g_candle_context = i;
    }
    if(g_candle_touch_time[i] > 0 &&
       (g_candle_touch_role[i] > 0 ? tick.bid > level : tick.bid < level))
      g_candle_reclaimed[i] = true;
  }
  g_candle_previous_bid = tick.bid;
}

string CandleInterval(const double price)
{
  if(!g_candle_ladder.valid) return "\\N";
  if(price < g_candle_ladder.trade_prices[0]) return "BELOW_S3";
  for(int i = 0; i < 7; i++)
  {
    if(price == g_candle_ladder.trade_prices[i]) return "AT_" + CandleLevel(i);
    if(i < 6 && price < g_candle_ladder.trade_prices[i + 1])
      return CandleLevel(i) + "_TO_" + CandleLevel(i + 1);
  }
  return "ABOVE_R3";
}

void CandleContextCells(string &row, const MqlTick &tick, const int direction)
{
  CandleCell(row, CandleInterval(direction > 0 ? tick.ask : tick.bid));
  CandleCell(row, CandleNullable(CandleLevel(g_candle_context)));
  CandleCell(row, g_candle_context < 0 ? "\\N" :
                   (g_candle_touch_role[g_candle_context] > 0 ? "SUPPORT" : "RESISTANCE"));
  CandleCell(row, g_candle_context < 0 ? "\\N" :
                   CandleNumber(((direction > 0 ? tick.ask : tick.bid) -
                                 g_candle_ladder.trade_prices[g_candle_context]) / _Point));
  CandleCell(row, g_candle_context < 0 ? "\\N" :
                   CandleInteger(tick.time_msc - g_candle_touch_time[g_candle_context]));
  for(int i = 0; i < 7; i++)
  {
    CandleCell(row, g_candle_ladder.valid ? CandleNumber(g_candle_ladder.trade_prices[i]) : "\\N");
    CandleCell(row, g_candle_touch_time[i] > 0 ? CandleInteger(g_candle_touch_time[i]) : "\\N");
    CandleCell(row, g_candle_touch_time[i] > 0 ? CandleInteger(g_candle_touch_sequence[i]) : "\\N");
    CandleCell(row, g_candle_touch_time[i] == 0 ? "\\N" :
                     (g_candle_touch_role[i] > 0 ? "SUPPORT" : "RESISTANCE"));
    CandleCell(row, CandleBoolean(g_candle_reclaimed[i]));
    CandleCell(row, CandleBoolean(g_candle_gap_cross[i]));
  }
}

#endif
