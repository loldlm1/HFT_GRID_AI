//+------------------------------------------------------------------+
//|                           grid_visualization.mqh                |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

#include "chart_style_guide.mqh"

extern SignalParams running_bullish_signals[];
extern SignalParams running_bearish_signals[];
extern bool g_ea_running;
extern int  g_magic_number;

const string GRID_VISUAL_PREFIX = "GRIDVIS_";

bool ContainsObjectName(string &names[], const string name)
{
  int total = ArraySize(names);
  for(int i = 0; i < total; i++)
  {
    if(names[i] == name)
      return true;
  }
  return false;
}

void PushObjectName(string &names[], const string name)
{
  int total = ArraySize(names);
  ArrayResize(names, total + 1);
  names[total] = name;
}

string GridSignalKey(const SignalParams &signal_params)
{
  string dir = (signal_params.signal_type == BULLISH) ? "B" : "S";
  return dir + "_" + TimeToString(signal_params.entry_time, TIME_DATE | TIME_SECONDS);
}

string GridLevelObjectName(const SignalParams &signal_params,
                           const int level_index,
                           const string suffix)
{
  return StringFormat("%s%s_%d_%s",
                      GRID_VISUAL_PREFIX,
                      GridSignalKey(signal_params),
                      level_index,
                      suffix);
}

void UpdateHorizontalLine(const long chart_id,
                          const string name,
                          const color line_color,
                          const double price)
{
  if(price <= 0.0 || !Enable_Chart_Levels)
  {
    if(ObjectFind(chart_id, name) >= 0)
      ObjectDelete(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
  {
    ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
  }

  ObjectSetDouble(chart_id, name, OBJPROP_PRICE, price);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, line_color);
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, STYLE_DASH);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
}

void DrawGridLevels(const long chart_id,
                    const SignalParams &signal_params,
                    string &tracked_objects[])
{
  int levels_total = ArraySize(signal_params.grid_orders);
  int plan_total   = ArraySize(signal_params.grid_plan.levels);
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  int active_max_index = -1;
  for(int idx = 0; idx < levels_total; idx++)
  {
    GridOrderState state_scan = signal_params.grid_orders[idx];
    if(state_scan.status == GRID_ORDER_ACTIVE)
      active_max_index = idx;
  }

  int depth_limit = Enable_Chart_Levels_Depth;
  int max_visible_index = levels_total - 1;
  if(depth_limit > 0)
  {
    int base_index = (active_max_index >= 0) ? active_max_index : 0;
    max_visible_index = base_index + depth_limit;
    if(max_visible_index >= levels_total)
      max_visible_index = levels_total - 1;
  }

  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];

    string stop_name  = GridLevelObjectName(signal_params, i, "STOP");
    string tp_name    = GridLevelObjectName(signal_params, i, "TP");
    string final_name = GridLevelObjectName(signal_params, i, "TP_FINAL");
    string next_name  = GridLevelObjectName(signal_params, i, "NEXT");
    string entry_name = GridLevelObjectName(signal_params, i, "ENTRY");

    if(level_state.status == GRID_ORDER_INACTIVE)
    {
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      continue;
    }

    if(depth_limit > 0 && i > max_visible_index)
    {
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      continue;
    }

    GridLevelPlan level_plan = (i < plan_total) ? signal_params.grid_plan.levels[i] : GridLevelPlan();
    double direction_mult = (signal_params.signal_type == BULLISH) ? 1.0 : -1.0;
    double pending_points = level_plan.pending_order_points;
    if(pending_points <= 0.0)
    {
      if(level_plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
        pending_points = level_plan.distance_points - level_plan.entry_offset_points;
      else
        pending_points = level_plan.distance_points + level_plan.entry_offset_points;
    }
    if(pending_points <= 0.0)
      pending_points = level_plan.distance_points;
    double plan_anchor = level_plan.anchor_price;
    if(plan_anchor <= 0.0)
      plan_anchor = level_state.anchor_price;

    double predicted_entry_price = 0.0;
    double stop_price  = 0.0;
    double tp_price    = level_state.take_profit_price;
    double final_price = level_state.final_take_profit_price;

    if(level_state.status == GRID_ORDER_WAITING)
    {
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      predicted_entry_price = plan_anchor + direction_mult * pending_points * point_size;
    }
    else if(level_state.status == GRID_ORDER_PENDING)
    {
      predicted_entry_price = level_state.last_pending_price;
      if(predicted_entry_price <= 0.0)
        predicted_entry_price = plan_anchor + direction_mult * pending_points * point_size;
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, predicted_entry_price);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price);
    }
    else if(level_state.status == GRID_ORDER_ACTIVE)
    {
      predicted_entry_price = level_state.entry_price;
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      if(level_state.stop_loss_price > 0.0)
        stop_price = level_state.stop_loss_price;
      else if(predicted_entry_price > 0.0 && level_plan.protective_stop_points > 0.0)
        stop_price = predicted_entry_price - direction_mult * level_plan.protective_stop_points * point_size;
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, stop_price);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price);
    }
    else if(level_state.status == GRID_ORDER_COMPLETED)
    {
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      predicted_entry_price = level_state.anchor_price;
    }

    double next_price = level_state.next_level_price;
    if(next_price <= 0.0)
    {
      if(predicted_entry_price <= 0.0)
        predicted_entry_price = plan_anchor + direction_mult * pending_points * point_size;

      if((i + 1) < plan_total)
      {
        GridLevelPlan next_plan = signal_params.grid_plan.levels[i + 1];
        double next_pending = next_plan.pending_order_points;
        if(next_pending <= 0.0)
        {
          if(next_plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
            next_pending = next_plan.distance_points - next_plan.entry_offset_points;
          else
            next_pending = next_plan.distance_points + next_plan.entry_offset_points;
        }
        if(next_pending <= 0.0)
          next_pending = next_plan.distance_points;
        double previous_distance = level_plan.distance_points;
        double predicted_anchor = predicted_entry_price - direction_mult * previous_distance * point_size;
        double next_anchor = next_plan.anchor_price;
        if(next_anchor <= 0.0)
          next_anchor = predicted_anchor;
        next_price = next_anchor + direction_mult * next_pending * point_size;
      }
    }

    if(next_price > 0.0)
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, next_price);
    else
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);

    if(Enable_Chart_Levels)
    {
      PushObjectName(tracked_objects, stop_name);
      PushObjectName(tracked_objects, tp_name);
      PushObjectName(tracked_objects, final_name);
      PushObjectName(tracked_objects, next_name);
      PushObjectName(tracked_objects, entry_name);
    }
  }
}

void BuildSignalSummary(const SignalParams &signal_params,
                        string &summary_lines[],
                        const datetime now_time)
{
  int total_levels = ArraySize(signal_params.grid_plan.levels);
  int active_levels = 0;
  int pending_levels = 0;

  int tracked_orders = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < tracked_orders; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];
    if(level_state.status == GRID_ORDER_ACTIVE)
      active_levels++;
    else if(level_state.status == GRID_ORDER_PENDING)
      pending_levels++;
  }

  GridTelemetryStats stats = signal_params.grid_stats;
  string direction_label = (signal_params.signal_type == BULLISH) ? "BULL" : "BEAR";

  int summary_index = ArraySize(summary_lines);
  ArrayResize(summary_lines, summary_index + 1);

  int duration_seconds = 0;
  if(stats.activation_time > 0)
    duration_seconds = (int)(now_time - stats.activation_time);

  summary_lines[summary_index] = StringFormat("%s | act=%d pend=%d tot=%d | PF=%.2f | MaxF=%.1f | MaxA=%.1f | Dur=%ds",
                                              direction_label,
                                              active_levels,
                                              pending_levels,
                                              total_levels,
                                              stats.ProfitFactor(),
                                              stats.max_favorable_points,
                                              stats.max_adverse_points,
                                              duration_seconds);
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
