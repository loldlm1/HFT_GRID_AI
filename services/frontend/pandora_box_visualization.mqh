//+------------------------------------------------------------------+
//|                   pandora_box_visualization.mqh                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_

string PandoraObjectName(const string suffix)
{
  return "PANDORA_" + suffix;
}

string PandoraHistoryObjectName(const datetime day_anchor,
                                const string suffix)
{
  return PandoraObjectName("DAY_" + CompactTimeIdentifier(day_anchor) + "_" + suffix);
}

string PandoraTradeMarkerObjectName(const PandoraTradeMarkerSnapshot &snapshot,
                                    const string suffix)
{
  if(snapshot.marker_id == "")
    return "";
  return PandoraObjectName("TRADE_" + snapshot.marker_id + "_" + suffix);
}

string PandoraFormatMarkerMoney(const double value)
{
  double rounded_cents = MathRound(value * 100.0) / 100.0;
  double rounded_units = MathRound(rounded_cents);
  if(MathAbs(rounded_cents - rounded_units) < 0.005)
    return IntegerToString((int)rounded_units) + "$";
  return DoubleToString(rounded_cents, 2) + "$";
}

string PandoraTradeMarkerLabel(const PandoraTradeMarkerSnapshot &snapshot)
{
  string execution_label = PandoraPositionExecutionLabel(snapshot.broker_status,
                                                        snapshot.reject_reason);
  return PandoraFormatMarkerMoney(snapshot.raw_profit) + " (" + execution_label + ")";
}

color PandoraTradeMarkerEntryColor(const PandoraTradeMarkerSnapshot &snapshot)
{
  if(snapshot.direction == BULLISH)
    return COLOR_CHART_BULL;
  if(snapshot.direction == BEARISH)
    return COLOR_CHART_BEAR;
  return COLOR_PROFIT_NEUTRAL;
}

color PandoraTradeMarkerCloseColor(const PandoraTradeMarkerSnapshot &snapshot)
{
  if(snapshot.raw_profit > 0.0)
    return COLOR_PROFIT_POSITIVE;
  if(snapshot.raw_profit < 0.0)
    return COLOR_PROFIT_NEGATIVE;
  return COLOR_PROFIT_NEUTRAL;
}

int PandoraTradeMarkerEntryArrow(const PandoraTradeMarkerSnapshot &snapshot)
{
  if(snapshot.direction == BEARISH)
    return 234;
  return 233;
}

int PandoraTradeMarkerCloseArrow(const PandoraTradeMarkerSnapshot &snapshot)
{
  if(snapshot.direction == BEARISH)
    return 233;
  return 234;
}

void PandoraDrawTradeMarkerSnapshot(const long chart_id,
                                    const PandoraTradeMarkerSnapshot &snapshot,
                                    string &tracked_objects[])
{
  if(snapshot.marker_id == "" ||
     snapshot.entry_time <= 0 ||
     snapshot.entry_price <= 0.0)
    return;

  string entry_name = PandoraTradeMarkerObjectName(snapshot, "ENTRY");
  UpdateTrackedTimePriceArrow(chart_id,
                              entry_name,
                              snapshot.entry_time,
                              snapshot.entry_price,
                              PandoraTradeMarkerEntryArrow(snapshot),
                              PandoraTradeMarkerEntryColor(snapshot),
                              tracked_objects,
                              1);

  if(!snapshot.completed ||
     snapshot.close_time <= 0 ||
     snapshot.close_price <= 0.0)
    return;

  color close_color = PandoraTradeMarkerCloseColor(snapshot);
  string segment_name = PandoraTradeMarkerObjectName(snapshot, "SEGMENT");
  UpdateTrackedTimePriceSegment(chart_id,
                                segment_name,
                                snapshot.entry_time,
                                snapshot.entry_price,
                                snapshot.close_time,
                                snapshot.close_price,
                                close_color,
                                tracked_objects,
                                STYLE_DOT,
                                1);

  string close_name = PandoraTradeMarkerObjectName(snapshot, "CLOSE");
  UpdateTrackedTimePriceArrow(chart_id,
                              close_name,
                              snapshot.close_time,
                              snapshot.close_price,
                              PandoraTradeMarkerCloseArrow(snapshot),
                              close_color,
                              tracked_objects,
                              1);

  string label_name = PandoraTradeMarkerObjectName(snapshot, "LABEL");
  UpdateTrackedTimePriceText(chart_id,
                             label_name,
                             snapshot.close_time,
                             snapshot.close_price,
                             PandoraTradeMarkerLabel(snapshot),
                             FRONTEND_PANEL_FONT,
                             8,
                             close_color,
                             tracked_objects);
}

void PandoraDrawTradeMarkers(const long chart_id,
                             string &tracked_objects[])
{
  int total = PandoraTradeMarkerSnapshotCount();
  for(int i = 0; i < total; i++)
  {
    PandoraTradeMarkerSnapshot snapshot = PandoraTradeMarkerSnapshotAt(i);
    PandoraDrawTradeMarkerSnapshot(chart_id, snapshot, tracked_objects);
  }
}

void PandoraDrawHistorySnapshot(const long chart_id,
                                const PandoraHistorySnapshot &snapshot,
                                string &tracked_objects[])
{
  if(snapshot.window_start_time <= 0 ||
     snapshot.window_end_time <= 0 ||
     snapshot.box_high <= 0.0 ||
     snapshot.box_low <= 0.0)
    return;

  string rect_name = PandoraHistoryObjectName(snapshot.day_anchor, "BOX");
  UpdateTrackedTimePriceRectangle(chart_id,
                                  rect_name,
                                  snapshot.window_start_time,
                                  snapshot.box_high,
                                  snapshot.window_end_time,
                                  snapshot.box_low,
                                  COLOR_HISTORY_FILL,
                                  tracked_objects,
                                  STYLE_SOLID,
                                  1);

  string invalid_label_name = PandoraHistoryObjectName(snapshot.day_anchor, "LABEL");
  string invalid_label_text = snapshot.box_valid ? "" : "INV";
  double label_price = snapshot.box_high;
  UpdateTrackedTimePriceText(chart_id,
                             invalid_label_name,
                             snapshot.window_start_time,
                             label_price,
                             invalid_label_text,
                             FRONTEND_PANEL_FONT,
                             7,
                             COLOR_HISTORY_LABEL,
                             tracked_objects);
}

void PandoraDrawHistory(const long chart_id,
                        string &tracked_objects[])
{
  PandoraEnsureHistorySnapshots();
  int total = PandoraHistorySnapshotCount();
  for(int i = total - 1; i >= 0; i--)
  {
    PandoraHistorySnapshot snapshot = PandoraHistorySnapshotAt(i);
    PandoraDrawHistorySnapshot(chart_id, snapshot, tracked_objects);
  }
}

void PandoraDrawVisualization(const long chart_id,
                              string &tracked_objects[])
{
  PandoraSyncRuntimeConfig();
  PandoraEnsureDayAnchor();
  PandoraEnsureWindowParsed();

  if(!PandoraVisualizationEnabled())
    return;

  PandoraDrawHistory(chart_id, tracked_objects);
  PandoraDrawTradeMarkers(chart_id, tracked_objects);

  color box_color = Pandora_Box_Color;
  bool  invalid_box = (g_pandora_box_state.box_computed && !g_pandora_box_state.box_valid);
  if(invalid_box || g_pandora_box_state.invalid_reason != "")
    box_color = Pandora_Box_Invalid_Color;

  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BOX_HIGH"),
                    box_color,
                    g_pandora_box_state.box_high,
                    tracked_objects,
                    "PANDORA BOX HIGH",
                    Pandora_Box_Line_Style);
  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BOX_LOW"),
                    box_color,
                    g_pandora_box_state.box_low,
                    tracked_objects,
                    "PANDORA BOX LOW",
                    Pandora_Box_Line_Style);

  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BREAKOUT_BULL"),
                    Pandora_Box_Breakout_Color,
                    g_pandora_box_state.breakout_high_price,
                    tracked_objects,
                    "PANDORA BULL BREAKOUT",
                    Pandora_Box_Breakout_Line_Style);
  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BREAKOUT_BEAR"),
                    Pandora_Box_Breakout_Color,
                    g_pandora_box_state.breakout_low_price,
                    tracked_objects,
                    "PANDORA BEAR BREAKOUT",
                    Pandora_Box_Breakout_Line_Style);
}

void PandoraAppendSummary(string &summary_lines[])
{
  if(!PandoraStrategyEnabled())
    return;

  PandoraSyncRuntimeConfig();
  PandoraEnsureDayAnchor();
  PandoraEnsureWindowParsed();
  PandoraWindowCompleted();

  string status = "PANDORA";
  string entry_label = PandoraEntryTypeLabel();
  string body_tf_label = PandoraEntryBodyTimeframeLabel();
  string first_entry_label = PandoraFirstEntryModeLabel(g_pandora_box_state.first_entry_mode);
  if(!g_pandora_box_state.window_valid)
  {
    status = StringFormat("PANDORA entry=%s first=%s body_tf=%s INVALID WINDOW %s",
                          entry_label,
                          first_entry_label,
                          body_tf_label,
                          Pandora_Box_Time_Range);
    if(g_pandora_box_state.invalid_reason != "")
      status = status + " (" + g_pandora_box_state.invalid_reason + ")";
  }
  else if(!g_pandora_box_state.window_closed)
  {
    status = StringFormat("PANDORA WAIT %s entry=%s first=%s body_tf=%s",
                          PandoraWindowLabel(),
                          entry_label,
                          first_entry_label,
                          body_tf_label);
  }
  else if(g_pandora_box_state.box_computed && !g_pandora_box_state.box_valid)
  {
    status = StringFormat("PANDORA entry=%s first=%s body_tf=%s INVALID BOX range=%.1f limit=%.1f",
                          entry_label,
                          first_entry_label,
                          body_tf_label,
                          g_pandora_box_state.box_range_points,
                          g_pandora_box_state.max_range_points);
    if(g_pandora_box_state.invalid_reason != "")
      status = status + " (" + g_pandora_box_state.invalid_reason + ")";
  }
  else if(PandoraDailyCompleted())
  {
    status = StringFormat("PANDORA DONE entry=%s first=%s body_tf=%s",
                          entry_label,
                          first_entry_label,
                          body_tf_label);
  }
  else if(g_pandora_box_state.box_computed && g_pandora_box_state.box_valid)
  {
    double display_offset = g_pandora_box_state.effective_offset_points;
    if(display_offset <= 0.0)
      display_offset = g_pandora_box_state.offset_points;

    string count_mode = EnumToString(g_pandora_box_state.entry_count_mode);
    string count_limit = PandoraLimitLabel();
    string lifecycle_label = PandoraWaitClosePending() ? "WAIT_CLOSE" : "READY";

    string rearm_status = "";
    if(g_pandora_box_state.bullish_rearm_required &&
       !g_pandora_box_state.bullish_rearm_ready)
      rearm_status = rearm_status + "WAIT_BULL ";
    if(g_pandora_box_state.bearish_rearm_required &&
       !g_pandora_box_state.bearish_rearm_ready)
      rearm_status = rearm_status + "WAIT_BEAR ";

    status = StringFormat("PANDORA %s entry=%s first=%s body_tf=%s range=%.1f off=%.1f mode=%s open=%d/%s close=%d/%s counted=%d/%s %s",
                          lifecycle_label,
                          entry_label,
                          first_entry_label,
                          body_tf_label,
                          g_pandora_box_state.box_range_points,
                          display_offset,
                          count_mode,
                          g_pandora_box_state.total_entries,
                          count_limit,
                          g_pandora_box_state.closed_entries,
                          count_limit,
                          g_pandora_box_state.counted_entries,
                          count_limit,
                          rearm_status);
  }
  else
  {
    status = StringFormat("PANDORA ARMED %s entry=%s first=%s body_tf=%s",
                          PandoraWindowLabel(),
                          entry_label,
                          first_entry_label,
                          body_tf_label);
  }

  int idx = ArraySize(summary_lines);
  ArrayResize(summary_lines, idx + 1);
  summary_lines[idx] = status;
}

#endif // _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_
