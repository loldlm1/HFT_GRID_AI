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
                    "PANDORA BOX HIGH",
                    Pandora_Box_Line_Style);
  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BOX_LOW"),
                    box_color,
                    g_pandora_box_state.box_low,
                    "PANDORA BOX LOW",
                    Pandora_Box_Line_Style);

  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BREAKOUT_BULL"),
                    Pandora_Box_Breakout_Color,
                    g_pandora_box_state.breakout_high_price,
                    "PANDORA BULL BREAKOUT",
                    Pandora_Box_Breakout_Line_Style);
  UpdateTrackedLine(chart_id,
                    PandoraObjectName("BREAKOUT_BEAR"),
                    Pandora_Box_Breakout_Color,
                    g_pandora_box_state.breakout_low_price,
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
    string sides = "";
    if(g_pandora_box_state.bullish_consumed)
      sides = sides + "BULL_USED ";
    if(g_pandora_box_state.bearish_consumed)
      sides = sides + "BEAR_USED ";
    status = StringFormat("PANDORA READY range=%.1f off=%.1f %s",
                          g_pandora_box_state.box_range_points,
                          display_offset,
                          sides);
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
