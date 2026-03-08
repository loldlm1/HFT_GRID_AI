#ifndef _SERVICES_FRONTEND_PANDORA_BOX_PANEL_MQH_
#define _SERVICES_FRONTEND_PANDORA_BOX_PANEL_MQH_

bool FrontendPanelEnabled()
{
  return (Enable_Chart_Levels &&
          Enable_Chart_Summary &&
          MQLInfoInteger(MQL_TESTER) <= 0);
}

bool FrontendTesterCommentEnabled()
{
  return (Enable_Chart_Summary &&
          MQLInfoInteger(MQL_TESTER) > 0);
}

string FrontendPanelObjectName(const string suffix)
{
  return "PANDORA_PANEL_" + suffix;
}

void FrontendAppendLine(string &lines[],
                        const string line_text)
{
  int total = ArraySize(lines);
  ArrayResize(lines, total + 1);
  lines[total] = line_text;
}

double FrontendCollectFloatingOpenProfit()
{
  double cumulative = 0.0;
  int total_positions = PositionsTotal();
  for(int i = 0; i < total_positions; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket <= 0)
      continue;
    if(!PositionSelectByTicket(ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    cumulative += PositionGetDouble(POSITION_PROFIT);
  }
  return cumulative;
}

string FrontendFormatMoney(const double amount)
{
  string prefix = "";
  if(amount > 0.0)
    prefix = "+";
  return prefix + "$" + DoubleToString(amount, 2);
}

string FrontendFormatCountdown(const int total_seconds)
{
  int safe_seconds = MathMax(total_seconds, 0);
  int hours = safe_seconds / 3600;
  int minutes = (safe_seconds % 3600) / 60;
  int seconds = safe_seconds % 60;
  if(hours > 0)
    return StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
  return StringFormat("%02d:%02d", minutes, seconds);
}

int FrontendResolveBarCountdownSeconds(const datetime now_time)
{
  int period_seconds = PeriodSeconds(_Period);
  if(period_seconds <= 0)
    period_seconds = 60;

  datetime bar_time = iTime(_Symbol, _Period, 0);
  if(bar_time <= 0)
    bar_time = now_time - (now_time % period_seconds);

  int elapsed = (int)(now_time - bar_time);
  if(elapsed < 0)
    elapsed = 0;

  int remaining = period_seconds - elapsed;
  if(remaining < 0)
    remaining = 0;
  if(remaining > period_seconds)
    remaining = period_seconds;
  return remaining;
}

void FrontendBuildPanelLines(const datetime now_time,
                             const string market_status,
                             const string status_reason,
                             string &summary_lines[],
                             string &panel_lines[])
{
  ArrayResize(panel_lines, 0);

  double floating_profit = FrontendCollectFloatingOpenProfit();
  FrontendAppendLine(panel_lines, "PANDORA BOX");
  FrontendAppendLine(panel_lines,
                     StringFormat("Hora: %s | Vela: %s | P/L: %s",
                                  TimeToString(now_time, TIME_SECONDS),
                                  FrontendFormatCountdown(FrontendResolveBarCountdownSeconds(now_time)),
                                  FrontendFormatMoney(floating_profit)));
  FrontendAppendLine(panel_lines,
                     StringFormat("EA: %s | Magic: %I64d | Mercado: %s",
                                  g_ea_running ? "Enabled" : "Disabled",
                                  g_magic_number,
                                  market_status));
  if(status_reason != "")
    FrontendAppendLine(panel_lines, "Motivo: " + status_reason);

  int summary_total = ArraySize(summary_lines);
  int max_summary_lines = 4;
  for(int i = 0; i < summary_total && i < max_summary_lines; i++)
    FrontendAppendLine(panel_lines, summary_lines[i]);

  if(summary_total > max_summary_lines)
  {
    FrontendAppendLine(panel_lines,
                       StringFormat("+%d lineas mas",
                                    summary_total - max_summary_lines));
  }
}

int FrontendResolvePanelWidth(string &panel_lines[])
{
  int max_chars = 0;
  int total = ArraySize(panel_lines);
  for(int i = 0; i < total; i++)
  {
    int line_chars = StringLen(panel_lines[i]);
    if(line_chars > max_chars)
      max_chars = line_chars;
  }

  int width = (FRONTEND_PANEL_PADDING_X * 2) + (max_chars * 6);
  if(width < FRONTEND_PANEL_MIN_WIDTH)
    width = FRONTEND_PANEL_MIN_WIDTH;
  if(width > FRONTEND_PANEL_MAX_WIDTH)
    width = FRONTEND_PANEL_MAX_WIDTH;
  return width;
}

int FrontendResolvePanelHeight(const int line_count)
{
  if(line_count <= 0)
    return 0;
  return (FRONTEND_PANEL_PADDING_Y * 2) + (line_count * FRONTEND_PANEL_LINE_HEIGHT);
}

void RenderFrontendPanel(const long chart_id,
                         const datetime now_time,
                         const string market_status,
                         const string status_reason,
                         string &summary_lines[],
                         string &tracked_objects[])
{
  if(!FrontendPanelEnabled())
    return;

  string panel_lines[];
  FrontendBuildPanelLines(now_time,
                          market_status,
                          status_reason,
                          summary_lines,
                          panel_lines);
  int total_lines = ArraySize(panel_lines);
  if(total_lines <= 0)
    return;

  int panel_width = FrontendResolvePanelWidth(panel_lines);
  int panel_height = FrontendResolvePanelHeight(total_lines);
  UpdateTrackedCornerRectangleLabel(chart_id,
                                    FrontendPanelObjectName("BG"),
                                    FRONTEND_PANEL_CORNER,
                                    FRONTEND_PANEL_MARGIN_LEFT,
                                    FRONTEND_PANEL_MARGIN_TOP,
                                    panel_width,
                                    panel_height,
                                    COLOR_PANEL_BACKGROUND,
                                    COLOR_PANEL_BORDER,
                                    tracked_objects);

  int text_x = FRONTEND_PANEL_MARGIN_LEFT + FRONTEND_PANEL_PADDING_X;
  int text_y = FRONTEND_PANEL_MARGIN_TOP + FRONTEND_PANEL_PADDING_Y;
  for(int i = 0; i < total_lines; i++)
  {
    int font_size = (i == 0) ? FRONTEND_PANEL_TITLE_SIZE : FRONTEND_PANEL_TEXT_SIZE;
    color text_color = (i == 0) ? COLOR_PANEL_TITLE : COLOR_PANEL_TEXT;
    UpdateTrackedCornerLabel(chart_id,
                             FrontendPanelObjectName("LINE_" + IntegerToString(i)),
                             FRONTEND_PANEL_CORNER,
                             text_x,
                             text_y + (i * FRONTEND_PANEL_LINE_HEIGHT),
                             panel_lines[i],
                             FRONTEND_PANEL_FONT,
                             font_size,
                             text_color,
                             tracked_objects);
  }
}

string BuildTesterSummaryComment(const datetime now_time,
                                 const string market_status,
                                 const string status_reason,
                                 string &summary_lines[])
{
  string panel_lines[];
  FrontendBuildPanelLines(now_time,
                          market_status,
                          status_reason,
                          summary_lines,
                          panel_lines);

  string comment_text = "";
  int total = ArraySize(panel_lines);
  for(int i = 0; i < total; i++)
  {
    if(i > 0)
      comment_text = comment_text + "\n";
    comment_text = comment_text + panel_lines[i];
  }
  return comment_text;
}

#endif // _SERVICES_FRONTEND_PANDORA_BOX_PANEL_MQH_
