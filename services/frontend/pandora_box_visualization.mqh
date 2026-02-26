//+------------------------------------------------------------------+
//|                   pandora_box_visualization.mqh                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_

string PandoraObjectName(const string suffix)
{
  return "PANDORA_" + suffix;
}

void PandoraDrawVisualization(const long chart_id,
                              string &tracked_objects[])
{
  PandoraSyncRuntimeConfig();
  PandoraEnsureDayAnchor();
  PandoraEnsureWindowParsed();

  if(!PandoraVisualizationEnabled())
    return;

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
  if(!g_pandora_box_state.window_valid)
  {
    status = status + " INVALID WINDOW " + Pandora_Box_Time_Range;
    if(g_pandora_box_state.invalid_reason != "")
      status = status + " (" + g_pandora_box_state.invalid_reason + ")";
  }
  else if(!g_pandora_box_state.window_closed)
  {
    status = StringFormat("PANDORA WAIT %s", PandoraWindowLabel());
  }
  else if(g_pandora_box_state.box_computed && !g_pandora_box_state.box_valid)
  {
    status = StringFormat("PANDORA INVALID BOX range=%.1f limit=%.1f",
                          g_pandora_box_state.box_range_points,
                          g_pandora_box_state.max_range_points);
    if(g_pandora_box_state.invalid_reason != "")
      status = status + " (" + g_pandora_box_state.invalid_reason + ")";
  }
  else if(PandoraDailyCompleted())
  {
    status = "PANDORA DONE";
  }
  else if(g_pandora_box_state.box_computed && g_pandora_box_state.box_valid)
  {
    double display_offset = g_pandora_box_state.effective_offset_points;
    if(display_offset <= 0.0)
      display_offset = g_pandora_box_state.offset_points;

    string count_mode = EnumToString(g_pandora_box_state.entry_count_mode);
    string count_limit = "INF";
    if(g_pandora_box_state.max_entries > 0)
      count_limit = IntegerToString(g_pandora_box_state.max_entries);

    string rearm_status = "";
    if(g_pandora_box_state.bullish_rearm_required &&
       !g_pandora_box_state.bullish_rearm_ready)
      rearm_status = rearm_status + "WAIT_BULL ";
    if(g_pandora_box_state.bearish_rearm_required &&
       !g_pandora_box_state.bearish_rearm_ready)
      rearm_status = rearm_status + "WAIT_BEAR ";

    status = StringFormat("PANDORA READY range=%.1f off=%.1f mode=%s cnt=%d/%s %s",
                          g_pandora_box_state.box_range_points,
                          display_offset,
                          count_mode,
                          g_pandora_box_state.counted_entries,
                          count_limit,
                          rearm_status);
  }
  else
  {
    status = StringFormat("PANDORA ARMED %s", PandoraWindowLabel());
  }

  int idx = ArraySize(summary_lines);
  ArrayResize(summary_lines, idx + 1);
  summary_lines[idx] = status;
}

#endif // _SERVICES_FRONTEND_PANDORA_BOX_VISUALIZATION_MQH_
