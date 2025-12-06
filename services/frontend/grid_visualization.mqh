#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

double ResolveBreakEvenLinePrice(const SignalParams &signal_params)
{
  if(Grid_BreakEven_Mode == BE_DISABLE)
    return 0.0;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return 0.0;

  for(int i = total_levels - 1; i >= 0; i--)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.break_even_active &&
       state.break_even_price > 0.0 &&
       state.status == GRID_ORDER_ACTIVE)
      return state.break_even_price;
  }

  return 0.0;
}

string FormatTimeframeLabel(const ENUM_TIMEFRAMES tf_value)
{
  string label = EnumToString(tf_value);
  int pos = StringFind(label, "_");
  if(pos >= 0 && pos + 1 < StringLen(label))
    label = StringSubstr(label, pos + 1);
  return label;
}

void DrawGridLevels(const long chart_id,
                    const SignalParams &signal_params,
                    string &tracked_objects[])
{
  if(!signal_params.grid_initialized)
    return;

  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string final_name = GridSignalObjectName(signal_params, "TP_FINAL");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");
  string trailing_name = GridSignalObjectName(signal_params, "TP_TRAILING");
  string break_even_name = GridSignalObjectName(signal_params, "BREAK_EVEN");

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;
  if(grid_order_level < 0)
    return;
  GridOrderState level_state = signal_params.grid_orders[grid_order_level];

  double entry_price_line = level_state.entry_reference_price;
  double tp_price         = level_state.take_profit_price;
  double final_price      = level_state.final_take_profit_price;
  double next_level_price = level_state.next_level_price;
  double trailing_price   = level_state.trailing_price;

  string entry_label    = GridSignalLineLabel(signal_params, "ENTRY");
  string tp_label       = GridSignalLineLabel(signal_params, "TP");
  string final_label    = GridSignalLineLabel(signal_params, "FINAL TP");
  string next_label     = GridSignalLineLabel(signal_params, "NEXT");
  string trailing_label = GridSignalLineLabel(signal_params, "TP TRAILING");
  string break_even_label = GridSignalLineLabel(signal_params, "BREAK EVEN");

  int level_index = level_state.level_index;
  double level_lot_size = level_state.lot_size;
  next_label = StringFormat("%s L%d lot=%.2f",
                            next_label,
                            level_index,
                            level_lot_size);

  UpdateTrackedLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, tracked_objects, entry_label);
  UpdateTrackedLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tracked_objects, tp_label);
  UpdateTrackedLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price, tracked_objects, final_label);
  UpdateTrackedLine(chart_id, next_name, COLOR_PROFIT_NEGATIVE, next_level_price, tracked_objects, next_label);

  // Trailing active: swap TP for trailing; keep final visible
  if(level_state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    UpdateTrackedLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0, tracked_objects);
    UpdateTrackedLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, trailing_price, tracked_objects, trailing_label);
  }

  if(Grid_BreakEven_Mode != BE_DISABLE)
  {
    double break_even_price = ResolveBreakEvenLinePrice(signal_params);
    UpdateTrackedLine(chart_id, break_even_name, COLOR_PROFIT_NEUTRAL, break_even_price, tracked_objects, break_even_label, STYLE_DASHDOT);
  }
  else
  {
    UpdateTrackedLine(chart_id, break_even_name, COLOR_PROFIT_NEUTRAL, 0.0, tracked_objects);
  }

  if(signal_params.hedged_swing.hedged_mode)
  {
    int swing_total = ArraySize(signal_params.hedged_swing.swing_levels);
    for(int idx = 0; idx < swing_total; idx++)
    {
      double swing_price = signal_params.hedged_swing.swing_levels[idx];
      if(swing_price <= 0.0)
        continue;
      string swing_name = GridSignalObjectName(signal_params, StringFormat("SWING_L%d", idx));
      datetime swing_time = (idx < ArraySize(signal_params.hedged_swing.swing_times))
                              ? signal_params.hedged_swing.swing_times[idx]
                              : 0;
      string time_label = (swing_time > 0)
                            ? TimeToString(swing_time, TIME_DATE|TIME_MINUTES)
                            : "";
      string swing_label = StringFormat("L%d %s", idx, time_label);
      UpdateTrackedLine(chart_id, swing_name, COLOR_PROFIT_NEUTRAL, swing_price, tracked_objects, swing_label, STYLE_DOT);
    }
  }
}

void BuildSignalSummary(const SignalParams &signal_params,
                        string &summary_lines[],
                        const datetime now_time)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  int active_levels = 0;
  int pending_levels = 0;

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];
    if(level_state.status == GRID_ORDER_ACTIVE)
      active_levels++;
    else if(level_state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
            level_state.status == GRID_ORDER_WAITING)
      pending_levels++;
  }

  string direction_label = (signal_params.signal_type == BULLISH) ? "BULL" : "BEAR";
  string context_label = signal_params.strategy_context_label;
  ENUM_TIMEFRAMES tf = signal_params.strategy_timeframe;
  if(tf == PERIOD_CURRENT)
    tf = Strategy_Timeframe;
  string timeframe_label = FormatTimeframeLabel(tf);

  int summary_index = ArraySize(summary_lines);
  ArrayResize(summary_lines, summary_index + 1);

  summary_lines[summary_index] = StringFormat("%s %s@%s | act=%d pend=%d tot=%d",
                                              direction_label,
                                              context_label,
                                              timeframe_label,
                                              active_levels,
                                              pending_levels,
                                              total_levels);
}

void RefreshGridVisualization()
{
  long chart_id = ChartID();
  static string previous_objects[];
  string current_objects[];

  datetime now_time = TimeCurrent();
  string summary_lines[];

  if(Enable_Chart_Levels)
  {
    int bullish_total = ArraySize(running_bullish_signals);
    for(int i = 0; i < bullish_total; i++)
      DrawGridLevels(chart_id, running_bullish_signals[i], current_objects);

    int bearish_total = ArraySize(running_bearish_signals);
    for(int j = 0; j < bearish_total; j++)
      DrawGridLevels(chart_id, running_bearish_signals[j], current_objects);
  }
  else
  {
    int prev_total = ArraySize(previous_objects);
    for(int k = 0; k < prev_total; k++)
      ObjectDelete(chart_id, previous_objects[k]);
  }

  if(Enable_Chart_Summary)
  {
    int bullish_total = ArraySize(running_bullish_signals);
    for(int i = 0; i < bullish_total; i++)
      BuildSignalSummary(running_bullish_signals[i], summary_lines, now_time);

    int bearish_total = ArraySize(running_bearish_signals);
    for(int j = 0; j < bearish_total; j++)
      BuildSignalSummary(running_bearish_signals[j], summary_lines, now_time);

    string market_status = MarketStatusToString(MarketStatusGet());
    string header = StringFormat("%s   /   Magic: %d   /   Market: %s",
                                 g_ea_running ? "Enabled" : "Disabled",
                                 g_magic_number,
                                 market_status);
    string status_reason = MarketStatusReason();
    if(status_reason != "")
      header = header + " (" + status_reason + ")";

    string comment_text = header;
    int summary_total = ArraySize(summary_lines);
    for(int idx = 0; idx < summary_total; idx++)
      comment_text = comment_text + "\n" + summary_lines[idx];

    Comment(comment_text);
  }

  int previous_total = ArraySize(previous_objects);
  for(int p = 0; p < previous_total; p++)
  {
    if(!ContainsObjectName(current_objects, previous_objects[p]))
      ObjectDelete(chart_id, previous_objects[p]);
  }

  ArrayCopy(previous_objects, current_objects);
}

#endif // _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
