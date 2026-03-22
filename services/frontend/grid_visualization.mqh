#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

string g_grid_visual_previous_objects[];

void ResetGridVisualizationCache()
{
  ArrayResize(g_grid_visual_previous_objects, 0);
}

string FormatTimeframeLabel(const ENUM_TIMEFRAMES tf_value)
{
  string label = EnumToString(tf_value);
  int pos = StringFind(label, "_");
  if(pos >= 0 && pos + 1 < StringLen(label))
    label = StringSubstr(label, pos + 1);
  return label;
}

bool ResolveGridNextLevelLotPreview(const SignalParams &signal_params,
                                    const GridOrderState &current_level_state,
                                    int &next_level_index_out,
                                    double &next_lot_out)
{
  next_level_index_out = current_level_state.level_index + 1;
  next_lot_out = current_level_state.lot_size;

  if(next_level_index_out < 0 || !signal_params.grid_initialized)
    return false;

  SignalParams preview_signal = signal_params;
  int total_levels = ArraySize(preview_signal.grid_orders);
  if(total_levels <= next_level_index_out)
    ArrayResize(preview_signal.grid_orders, next_level_index_out + 1);

  GridOrderState preview_state;
  preview_state.level_index = next_level_index_out;
  preview_state.status      = GRID_ORDER_STOP_TRAILING_ACTIVE;

  int level_position_start = Grid_Level_Position_Start;
  if(level_position_start < 0)
    level_position_start = 0;
  preview_state.opens_position = (next_level_index_out >= level_position_start);

  preview_signal.grid_orders[next_level_index_out] = preview_state;

  double preview_lot = ResolveGridOrderLotSize(preview_signal, next_level_index_out);
  if(preview_lot <= 0.0)
    return false;

  next_lot_out = preview_lot;
  return true;
}

void DrawGridLevels(const long chart_id,
                    const SignalParams &signal_params,
                    string &tracked_objects[])
{
  if(!signal_params.grid_initialized)
    return;

  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;
  if(grid_order_level < 0)
    return;
  GridOrderState level_state = signal_params.grid_orders[grid_order_level];

  double entry_price_line = level_state.entry_reference_price;
  if(entry_price_line <= 0.0)
  {
    entry_price_line = signal_params.entry_price;
    if(entry_price_line <= 0.0)
      entry_price_line = signal_params.grid_entry_reference_price;
  }
  double stop_price       = 0.0;
  double tp_price         = level_state.take_profit_price;
  double next_level_price = level_state.next_level_price;

  if(StructureTrailingEnabled() && signal_params.trailing_stop_price > 0.0)
    stop_price = signal_params.trailing_stop_price;
  if(StructureTrailingEnabled() && signal_params.trailing_take_profit_price > 0.0)
    tp_price = signal_params.trailing_take_profit_price;

  string stop_label     = GridSignalLineLabel(signal_params, "STOP");
  string entry_label    = GridSignalLineLabel(signal_params, "ENTRY");
  string tp_label       = GridSignalLineLabel(signal_params, "TP");
  string next_label     = GridSignalLineLabel(signal_params, "NEXT");

  int level_index = level_state.level_index;
  int next_level_index = level_index + 1;
  double next_level_lot_size = level_state.lot_size;
  ResolveGridNextLevelLotPreview(signal_params,
                                 level_state,
                                 next_level_index,
                                 next_level_lot_size);

  double entry_percent = 0.0;
  double range_lower = 0.0;
  double range_upper = 0.0;
  bool fib_entry_ok = false;
  if(entry_price_line > 0.0)
  {
    fib_entry_ok = ResolveFibonacciEntryRange(signal_params,
                                              entry_price_line,
                                              entry_percent,
                                              range_lower,
                                              range_upper);
  }

  double next_percent = 0.0;
  bool fib_next_ok = ResolveFibonacciGridLevelPercent(signal_params,
                                                      level_index,
                                                      next_percent);

  if(fib_entry_ok)
  {
    double entry_level_percent = entry_percent;
    bool include_actual = false;
    if(signal_params.entry_trigger_mode == LEVEL_AS_ZONE)
    {
      entry_level_percent = range_upper;
      include_actual = true;
      double peak_price = 0.0;
      double bottom_price = 0.0;
      bool current_is_bottom = false;
      if(ResolveSignalStructureRange(signal_params,
                                     peak_price,
                                     bottom_price,
                                     current_is_bottom))
      {
        double level_price = 0.0;
        if(ResolveStructurePriceForPercent(peak_price,
                                           bottom_price,
                                           current_is_bottom,
                                           entry_level_percent,
                                           level_price))
          entry_price_line = level_price;
      }
    }
    entry_label = FormatFibEntryLabel(entry_label,
                                      entry_level_percent,
                                      include_actual,
                                      entry_percent);
  }

  if(fib_next_ok)
  {
    next_label = FormatFibNextLabel(next_label,
                                    next_percent,
                                    next_level_index,
                                    next_level_lot_size);
  }
  else
  {
    int display_level = ResolveGridNextDisplayLevel(level_index);
    next_label = StringFormat("%s L%d lot=%.2f",
                              next_label,
                              display_level,
                              next_level_lot_size);
  }

  UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, stop_price, stop_label);
  UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, entry_label);
  UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tp_label);
  UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_POSITIVE, next_level_price, next_label);
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
  if(FrontendSkippingChartWork())
  {
    ArrayResize(g_grid_visual_previous_objects, 0);
    return;
  }

  long chart_id = ChartID();
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
    int prev_total = ArraySize(g_grid_visual_previous_objects);
    for(int k = 0; k < prev_total; k++)
      ObjectDelete(chart_id, g_grid_visual_previous_objects[k]);
    ArrayResize(g_grid_visual_previous_objects, 0);
  }

  if(Enable_Chart_Summary)
  {
    int bullish_total = ArraySize(running_bullish_signals);
    for(int i = 0; i < bullish_total; i++)
      BuildSignalSummary(running_bullish_signals[i], summary_lines, now_time);

    int bearish_total = ArraySize(running_bearish_signals);
    for(int j = 0; j < bearish_total; j++)
      BuildSignalSummary(running_bearish_signals[j], summary_lines, now_time);
  }

  RenderLightweightStatusTable(g_ea_running, g_magic_number, summary_lines);

  int previous_total = ArraySize(g_grid_visual_previous_objects);
  for(int p = 0; p < previous_total; p++)
  {
    if(!ContainsObjectName(current_objects, g_grid_visual_previous_objects[p]))
      ObjectDelete(chart_id, g_grid_visual_previous_objects[p]);
  }

  ArrayCopy(g_grid_visual_previous_objects, current_objects);
}

#endif // _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
