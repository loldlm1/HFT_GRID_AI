//+------------------------------------------------------------------+
//|                           grid_visualization.mqh                |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

#include "chart_style_guide.mqh"
#include "../trading_management/ea_inputs.mqh"
#include "../trading_signals/signal_params_struct.mqh"

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
  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];

    string entry_name = GridLevelObjectName(signal_params, i, "ENTRY");
    string stop_name  = GridLevelObjectName(signal_params, i, "STOP");
    string tp_name    = GridLevelObjectName(signal_params, i, "TP");
    string final_name = GridLevelObjectName(signal_params, i, "TP_FINAL");
    string next_name  = GridLevelObjectName(signal_params, i, "NEXT");

    if(level_state.status == GRID_ORDER_INACTIVE || level_state.status == GRID_ORDER_WAITING)
    {
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);
      continue;
    }

    if(level_state.status == GRID_ORDER_COMPLETED)
    {
      UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
      UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
      UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, 0.0);
      UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, 0.0);
      continue;
    }

    UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, 0.0);
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, level_state.stop_loss_price);
    UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, level_state.take_profit_price);
    UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, level_state.final_take_profit_price);
    UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, level_state.next_level_price);

    if(Enable_Chart_Levels)
    {
      PushObjectName(tracked_objects, stop_name);
      PushObjectName(tracked_objects, tp_name);
      PushObjectName(tracked_objects, final_name);
      PushObjectName(tracked_objects, next_name);
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
