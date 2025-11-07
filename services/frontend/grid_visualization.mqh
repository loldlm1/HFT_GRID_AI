#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

#include "chart_style_guide.mqh"
#include "../../microservices/frontend/grid_visual_utils.mqh"
#include "../../microservices/frontend/grid_visual_resolvers.mqh"
#include "../../microservices/frontend/grid_visual_projection.mqh"
#include "../../microservices/frontend/grid_visual_lines.mqh"

extern SignalParams running_bullish_signals[];
extern SignalParams running_bearish_signals[];
extern bool g_ea_running;
extern int  g_magic_number;

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
  GridLevelPlan level_plan = GridLevelPlan();
  if(display_index < ArraySize(signal_params.grid_plan.levels))
    level_plan = signal_params.grid_plan.levels[display_index];

  double pending_points = ResolvePendingPointsForPlan(level_plan);
  double backend_pending = level_state.last_pending_price;
  double plan_pending = level_plan.next_resolved_price;
  double fallback_pending = GridComputeFallbackNextPrice(signal_params,
                                                         level_state,
                                                         display_index,
                                                         point_size);

  double pending_price = backend_pending;
  if(pending_price <= 0.0)
    pending_price = plan_pending;
  if(pending_price <= 0.0)
    pending_price = fallback_pending;

  double predicted_entry_price = ResolvePredictedEntryPrice(signal_params,
                                                            level_plan,
                                                            level_state,
                                                            direction_mult,
                                                            point_size);

  double stop_price = 0.0;
  double entry_price_line = 0.0;
  double tp_price = level_state.take_profit_price;
  double final_price = level_state.final_take_profit_price;
  double final_points = level_plan.final_take_profit_points;
  double trailing_price = 0.0;

  if(level_state.status == GRID_ORDER_ACTIVE)
  {
    entry_price_line = level_state.entry_price;
    if(entry_price_line <= 0.0)
      entry_price_line = predicted_entry_price;

    if(SHOW_STOPS_LINES)
    {
      if(level_state.stop_loss_price > 0.0)
        stop_price = level_state.stop_loss_price;
      else
      {
        double protective_points = level_plan.protective_stop_points;
        if(protective_points <= 0.0)
          protective_points = level_plan.entry_offset_points;
        if(entry_price_line > 0.0 && protective_points > 0.0)
          stop_price = entry_price_line - direction_mult * protective_points * point_size;
      }
    }

    if(tp_price <= 0.0 && level_plan.take_profit_points > 0.0 && entry_price_line > 0.0)
      tp_price = entry_price_line + direction_mult * level_plan.take_profit_points * point_size;

    if(final_points > 0.0)
    {
      double final_reference = entry_price_line;
      if(final_reference <= 0.0)
        final_reference = level_state.entry_price;
      if(final_reference <= 0.0)
        final_reference = predicted_entry_price;
      if(final_reference <= 0.0)
        final_reference = level_state.last_pending_price;
      if(final_reference <= 0.0)
        final_reference = fallback_pending;
      if(final_reference > 0.0)
        final_price = final_reference + direction_mult * final_points * point_size;
      else
        final_price = 0.0;
    }
    else
    {
      final_price = 0.0;
    }
  }
  else
  {
    // Prefer backend-aligned pending over plan projections
    if(level_state.last_pending_price > 0.0)
      entry_price_line = level_state.last_pending_price;
    else if(level_plan.next_resolved_price > 0.0)
      entry_price_line = level_plan.next_resolved_price;
    else
      entry_price_line = pending_price;

    if(SHOW_STOPS_LINES && level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
      stop_price = pending_price;

    if(tp_price <= 0.0 && level_plan.take_profit_points > 0.0 && pending_price > 0.0)
      tp_price = pending_price + direction_mult * level_plan.take_profit_points * point_size;

    if(final_points > 0.0)
    {
      double final_reference = pending_price;
      if(final_reference <= 0.0)
        final_reference = predicted_entry_price;
      if(final_reference <= 0.0)
        final_reference = fallback_pending;
      if(final_reference > 0.0)
        final_price = final_reference + direction_mult * final_points * point_size;
      else
        final_price = 0.0;
    }
    else
    {
      final_price = 0.0;
    }
  }

  if(level_state.is_trailing_active && level_state.trailing_price > 0.0)
    trailing_price = level_state.trailing_price;
  if(trailing_price > 0.0)
    tp_price = 0.0;

  int next_source_index = ResolveNextOverlaySourceIndex(signal_params);
  int next_level_index = ResolveNextOverlayTargetIndex(signal_params, next_source_index);
  double next_price_line = ResolveNextOverlayPrice(signal_params,
                                                   next_source_index,
                                                   next_level_index,
                                                   direction_mult,
                                                   point_size);

  string direction_label = (signal_params.signal_type == BULLISH) ? "BULL" : "BEAR";
  string next_label = "";
  int label_level_index = -1;
  if(next_level_index >= 0)
    label_level_index = next_level_index;
  else if(next_source_index >= 0)
    label_level_index = next_source_index + 1;
  if(label_level_index >= 0 && next_price_line > 0.0)
    next_label = StringFormat("NEXT %s L%d %s",
                              direction_label,
                              label_level_index,
                              DoubleToString(next_price_line, digits));

  string trailing_label = "";
  if(trailing_price > 0.0)
    trailing_label = StringFormat("TRAIL %s L%d %s",
                                  direction_label,
                                  display_index,
                                  DoubleToString(trailing_price, digits));

  if(SHOW_STOPS_LINES)
    UpdateTrackedLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, stop_price, tracked_objects);
  else
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);
  UpdateTrackedLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, tracked_objects);
  UpdateTrackedLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tracked_objects);
  UpdateTrackedLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price, tracked_objects);
  UpdateTrackedLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, trailing_price, tracked_objects, trailing_label, STYLE_SOLID);
  UpdateTrackedLine(chart_id, next_name, COLOR_PROFIT_NEUTRAL, next_price_line, tracked_objects, next_label, STYLE_DASH);
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
