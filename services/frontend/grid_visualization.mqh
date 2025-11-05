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

string CompactTimeIdentifier(const datetime time_value)
{
  if(time_value <= 0)
    return "";

  MqlDateTime ts;
  if(!TimeToStruct(time_value, ts))
    return "";

  return StringFormat("%04d%02d%02d_%02d%02d%02d",
                      ts.year,
                      ts.mon,
                      ts.day,
                      ts.hour,
                      ts.min,
                      ts.sec);
}

string GridSignalIdentifier(const SignalParams &signal_params)
{
  string time_token = CompactTimeIdentifier(signal_params.entry_time);
  if(time_token != "")
    return time_token;

  double anchor_price = signal_params.grid_plan.base_anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = signal_params.grid_plan.entry_side_price_initial;
  if(anchor_price <= 0.0)
    anchor_price = (signal_params.signal_type == BULLISH) ? g_bid : g_ask;

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;

  if(anchor_price > 0.0)
  {
    string anchor_token = DoubleToString(anchor_price, digits);
    StringReplace(anchor_token, ".", "");
    StringReplace(anchor_token, ",", "");
    if(anchor_token != "")
      return anchor_token;
  }

  return StringFormat("GRID_%d", signal_params.signal_type);
}

string GridSignalObjectName(const SignalParams &signal_params,
                            const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string identifier = GridSignalIdentifier(signal_params);
  return suffix + "_" + identifier + "_" + direction;
}

int ResolveDisplayLevelIndex(const SignalParams &signal_params)
{
  int total_orders = ArraySize(signal_params.grid_orders);
  if(total_orders <= 0)
    return -1;

  int highest_active = -1;
  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_ACTIVE)
      highest_active = i;
  }
  if(highest_active >= 0)
    return highest_active;

  int highest_pending = -1;
  for(int j = 0; j < total_orders; j++)
  {
    GridOrderState state = signal_params.grid_orders[j];
    if(state.status == GRID_ORDER_PENDING)
      highest_pending = j;
  }
  if(highest_pending >= 0)
    return highest_pending;

  if(total_orders > 0 && signal_params.grid_orders[0].status == GRID_ORDER_WAITING)
    return 0;

  for(int k = 0; k < total_orders; k++)
  {
    GridOrderState state = signal_params.grid_orders[k];
    if(state.status == GRID_ORDER_WAITING)
      return k;
  }

  for(int m = 0; m < total_orders; m++)
  {
    GridOrderState state = signal_params.grid_orders[m];
    if(state.status != GRID_ORDER_INACTIVE)
      return m;
  }

  return -1;
}

double ResolvePendingPointsForPlan(const GridLevelPlan &plan)
{
  double pending_points = plan.pending_order_points;
  double distance_points = plan.distance_points;
  double entry_offset = plan.entry_offset_points;

  if(pending_points <= 0.0)
  {
    if(plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
      pending_points = distance_points - entry_offset;
    else
      pending_points = distance_points + entry_offset;
    if(pending_points <= 0.0)
      pending_points = distance_points;
  }

  return pending_points;
}

double ResolveEffectiveDistancePoints(const GridLevelPlan &plan,
                                      const GridOrderState &state)
{
  if(state.resolved_distance_points > 0.0)
    return state.resolved_distance_points;
  if(plan.distance_points > 0.0)
    return plan.distance_points;
  return 0.0;
}

int ResolveNextOverlaySourceIndex(const SignalParams &signal_params)
{
  int orders_total = ArraySize(signal_params.grid_orders);

  int highest_active = -1;
  for(int k = 0; k < orders_total; k++)
  {
    GridOrderState order_state = signal_params.grid_orders[k];
    if(order_state.status == GRID_ORDER_ACTIVE)
      highest_active = k;
  }

  if(highest_active >= 0)
  {
    return highest_active;
  }

  for(int i = 0; i < orders_total; i++)
  {
    GridOrderState order_state = signal_params.grid_orders[i];
    if(order_state.status == GRID_ORDER_PENDING)
      return i;
  }

  for(int j = 0; j < orders_total; j++)
  {
    GridOrderState order_state = signal_params.grid_orders[j];
    if(order_state.status == GRID_ORDER_WAITING)
      return j;
  }

  if(orders_total > 0)
    return 0;

  return -1;
}

int ResolveNextOverlayTargetIndex(const SignalParams &signal_params,
                                  const int source_index)
{
  int levels_total = ArraySize(signal_params.grid_plan.levels);
  if(levels_total <= 0)
    return -1;

  if(source_index >= 0)
  {
    int candidate = source_index + 1;
    if(candidate < levels_total)
      return candidate;
    return -1;
  }

  return 0;
}

double ResolveNextOverlayPrice(const SignalParams &signal_params,
                               const int source_index,
                               const int target_index,
                               const double direction_mult,
                               const double point_size)
{
  GridOrderState source_state = GridOrderState();
  if(source_index >= 0 && source_index < ArraySize(signal_params.grid_orders))
    source_state = signal_params.grid_orders[source_index];

  if(source_state.next_level_price > 0.0)
    return source_state.next_level_price;

  if(target_index >= 0 && target_index < ArraySize(signal_params.grid_plan.levels))
  {
    GridLevelPlan plan = signal_params.grid_plan.levels[target_index];
    double next_price = plan.next_resolved_price;
    if(next_price <= 0.0)
      next_price = plan.next_blueprint_price;
    if(next_price <= 0.0)
    {
      double pending_points = ResolvePendingPointsForPlan(plan);
      double anchor_price = plan.anchor_price;
      if(anchor_price <= 0.0 && source_state.anchor_price > 0.0)
        anchor_price = source_state.anchor_price;
      if(anchor_price <= 0.0)
        anchor_price = signal_params.grid_plan.base_anchor_price;
      if(anchor_price > 0.0 && pending_points > 0.0 && point_size > 0.0)
        next_price = anchor_price + direction_mult * pending_points * point_size;
    }
    if(next_price > 0.0)
      return next_price;
  }

  if(source_state.last_pending_price > 0.0)
    return source_state.last_pending_price;

  return 0.0;
}

double ResolvePredictedEntryPrice(const SignalParams &signal_params,
                                  const GridLevelPlan &level_plan,
                                  const GridOrderState &level_state,
                                  const double direction_mult,
                                  const double point_size)
{
  if(level_state.status == GRID_ORDER_ACTIVE && level_state.entry_price > 0.0)
    return level_state.entry_price;

  if(level_state.last_pending_price > 0.0)
    return level_state.last_pending_price;

  double anchor = level_plan.anchor_price;
  if(anchor <= 0.0)
    anchor = level_state.anchor_price;
  if(anchor <= 0.0)
    anchor = signal_params.grid_plan.base_anchor_price;

  double pending_points = ResolvePendingPointsForPlan(level_plan);
  if(anchor > 0.0 && pending_points > 0.0 && point_size > 0.0)
    return anchor + direction_mult * pending_points * point_size;

  double entry_side_price = signal_params.grid_plan.entry_side_price_initial;
  double offset_points = signal_params.grid_plan.entry_side_offset_pts_initial;
  if(entry_side_price > 0.0 && offset_points > 0.0 && point_size > 0.0)
    return entry_side_price + direction_mult * offset_points * point_size;

  return anchor;
}

double ResolveProjectedNextPrice(const SignalParams &signal_params,
                                 const GridLevelPlan &level_plan,
                                 const GridOrderState &level_state,
                                 const double direction_mult,
                                 const double point_size,
                                 const int level_index,
                                 const double predicted_entry_price)
{
  double backend_next = level_state.next_level_price;
  if(backend_next > 0.0)
    return backend_next;

  if(predicted_entry_price <= 0.0 || point_size <= 0.0)
    return 0.0;

  double effective_distance = ResolveEffectiveDistancePoints(level_plan, level_state);
  if(effective_distance <= 0.0)
    return 0.0;

  double next_anchor = predicted_entry_price - direction_mult * effective_distance * point_size;

  int next_index = level_index + 1;
  GridLevelPlan next_plan = GridLevelPlan();
  if(next_index < ArraySize(signal_params.grid_plan.levels))
  {
    next_plan = signal_params.grid_plan.levels[next_index];
    if(next_plan.anchor_price <= 0.0)
      next_plan.anchor_price = next_anchor;
  }
  else
  {
    double base_distance = signal_params.grid_plan.base_distance_points;
    double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
    if(base_distance <= 0.0)
      base_distance = effective_distance;
    double computed_distance = base_distance * MathPow(exponential_multiplier, next_index);
    if(computed_distance <= 0.0)
      computed_distance = effective_distance * exponential_multiplier;

    double entry_percent = MathMax((next_index == 0) ? Grid_Initial_Stops_Percent
                                                    : Grid_Positions_Stops_Percent,
                                   0.0);
    double entry_offset = computed_distance * (entry_percent / 100.0);

    next_plan.level_index       = next_index;
    next_plan.anchor_price      = next_anchor;
    next_plan.distance_points   = computed_distance;
    next_plan.entry_offset_points = entry_offset;
    next_plan.entry_style       = (next_index == 0) ? Grid_Initial_Entry_Style : Grid_Deep_Entry_Style;
    if(next_plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
      next_plan.pending_order_points = computed_distance - entry_offset;
    else
      next_plan.pending_order_points = computed_distance + entry_offset;
    if(next_plan.pending_order_points <= 0.0)
      next_plan.pending_order_points = computed_distance;
  }

  double pending_points = ResolvePendingPointsForPlan(next_plan);
  if(pending_points <= 0.0)
    return 0.0;

  return next_plan.anchor_price + direction_mult * pending_points * point_size;
}

void UpdateHorizontalLine(const long chart_id,
                          const string name,
                          const color line_color,
                          const double price,
                          const string label_text = "",
                          const int line_style = STYLE_DASH,
                          const int line_width = 1)
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
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, line_style);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, line_width);
  if(label_text != "")
    ObjectSetString(chart_id, name, OBJPROP_TEXT, label_text);
  else
    ObjectSetString(chart_id, name, OBJPROP_TEXT, "");
}

void UpdateTrackedLine(const long chart_id,
                       const string name,
                       const color line_color,
                       const double price,
                       string &tracked_objects[],
                       const string label_text = "",
                       const int line_style = STYLE_DASH,
                       const int line_width = 1)
{
  UpdateHorizontalLine(chart_id, name, line_color, price, label_text, line_style, line_width);
  if(!Enable_Chart_Levels)
    return;
  if(price <= 0.0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
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
  GridLevelPlan level_plan = GridLevelPlan();
  if(display_index < ArraySize(signal_params.grid_plan.levels))
    level_plan = signal_params.grid_plan.levels[display_index];

  double pending_points = ResolvePendingPointsForPlan(level_plan);
  double pending_price = level_plan.next_resolved_price;
  if(pending_price <= 0.0)
    pending_price = level_state.last_pending_price;
  if(pending_price <= 0.0 && pending_points > 0.0)
  {
    double anchor_price = level_plan.anchor_price;
    if(anchor_price <= 0.0)
      anchor_price = level_state.anchor_price;
    if(anchor_price <= 0.0)
      anchor_price = signal_params.grid_plan.base_anchor_price;
    if(anchor_price > 0.0)
      pending_price = anchor_price + direction_mult * pending_points * point_size;
  }

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
        final_reference = level_plan.anchor_price;
      if(final_reference <= 0.0)
        final_reference = signal_params.grid_plan.base_anchor_price;
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
    if(level_plan.next_resolved_price > 0.0)
      entry_price_line = level_plan.next_resolved_price;
    else if(level_state.last_pending_price > 0.0)
      entry_price_line = level_state.last_pending_price;
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
        final_reference = level_plan.anchor_price;
      if(final_reference <= 0.0)
        final_reference = signal_params.grid_plan.base_anchor_price;
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
