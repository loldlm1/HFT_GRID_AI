#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

void DrawGridLevels(const long chart_id,
                    const SignalParams &signal_params,
                    string &tracked_objects[])
{
  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string final_name = GridSignalObjectName(signal_params, "TP_FINAL");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");
  string trailing_name = GridSignalObjectName(signal_params, "TP_TRAILING");

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;
  int display_index    = grid_order_level;
  GridOrderState level_state = signal_params.grid_orders[display_index];

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

  int level_index = level_state.level_index;
  double level_lot_size = level_state.lot_size;
  next_label = StringFormat("%s L%d lot=%.2f",
                            next_label,
                            level_index,
                            level_lot_size);

  UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, entry_label);
  UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tp_label);
  UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price, final_label);
  UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_POSITIVE, next_level_price, next_label);

  // Trailing active: swap TP for trailing; keep final visible
  if(level_state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
    UpdateHorizontalLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, trailing_price, trailing_label);
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

  int summary_index = ArraySize(summary_lines);
  ArrayResize(summary_lines, summary_index + 1);

  summary_lines[summary_index] = StringFormat("%s | act=%d pend=%d tot=%d",
                                              direction_label,
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
