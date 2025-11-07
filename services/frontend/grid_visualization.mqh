#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

#include "chart_style_guide.mqh"
#include "../../microservices/frontend/grid_visual_utils.mqh"
#include "../../microservices/trading_signals/grid_order_helpers.mqh"
#include "../../microservices/frontend/grid_visual_lines.mqh"

extern SignalParams running_bullish_signals[];
extern SignalParams running_bearish_signals[];
extern bool g_ea_running;
extern int  g_magic_number;

int ResolveDisplayLevelIndex(const SignalParams &signal_params)
{
  int total = ArraySize(signal_params.grid_orders);
  int last_active = -1;
  for(int i = 0; i < total; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_ACTIVE)
      last_active = i;
  }
  if(last_active >= 0)
    return last_active;

  for(int j = 0; j < total; j++)
  {
    GridOrderState state = signal_params.grid_orders[j];
    if(state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
       state.status == GRID_ORDER_WAITING)
      return j;
  }
  return -1;
}

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

  int display_index = ResolveDisplayLevelIndex(signal_params);
  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;

  if(display_index < 0)
  {
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
    UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
    UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
    UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
    UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);
    UpdateHorizontalLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, 0.0);
    return;
  }

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  double direction_mult = (signal_params.signal_type == BULLISH) ? 1.0 : -1.0;

  GridOrderState level_state = signal_params.grid_orders[display_index];
  double stop_price = level_state.next_level_price;
  if(stop_price <= 0.0)
    stop_price = GridResolveStopTriggerPrice(signal_params, level_state, point_size);
  double entry_price_line = (level_state.status == GRID_ORDER_ACTIVE)
                            ? level_state.entry_price
                            : stop_price;
  double tp_price = level_state.take_profit_price;
  double final_price = level_state.final_take_profit_price;
  double trailing_price = level_state.trailing_price;
  double next_price_line = level_state.next_level_price;
  if(next_price_line <= 0.0)
    next_price_line = stop_price;
  if(next_price_line <= 0.0 && level_state.entry_style == GRID_ENTRY_STYLE_STOP)
    next_price_line = stop_price;

  if(SHOW_STOPS_LINES)
    UpdateTrackedLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, stop_price, tracked_objects);
  else
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);

  UpdateTrackedLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, tracked_objects);
  UpdateTrackedLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tracked_objects);
  UpdateTrackedLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price, tracked_objects);
  UpdateTrackedLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, trailing_price, tracked_objects);
  UpdateTrackedLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, next_price_line, tracked_objects);
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

    string header = StringFormat("%s   /   Magic: %d",
                                 g_ea_running ? "Enabled" : "Disabled",
                                 g_magic_number);

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
