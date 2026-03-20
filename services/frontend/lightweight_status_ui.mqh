#ifndef _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
#define _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_

#include "../shared/license_guard_v1/core/addon_catalog.mqh"

const uchar LIGHTWEIGHT_UI_PANEL_FILL_ALPHA = 36;

string g_chart_ui_last_button_text = "";
string g_chart_ui_last_details_button_text = "";
string g_chart_ui_last_rows[];
LightweightUiChartSnapshot g_chart_ui_last_snapshot;
LightweightUiProfiles g_chart_ui_last_profile = LIGHTWEIGHT_UI_PROFILE_FULL;
bool g_chart_ui_layout_dirty = true;
bool g_chart_ui_details_expanded = false;
bool g_chart_ui_last_details_visible = false;

string BoolOnOff(const bool enabled)
{
  return enabled ? "ON" : "OFF";
}

string ResolveSignalBlockSourceLabel(const string source)
{
  if(source == "manual_toggle")
    return "Manual Toggle";
  if(source == "algo_trading")
    return "Algo Trading";
  if(source == "protection_risk")
    return "Protection Risk Management";
  if(source == "session_time_filter")
    return "Session Time Filter";
  if(source == "daily_signal_limit")
    return "Daily Signal Limit";
  if(source == "signal_concurrency")
    return "Signal Concurrency";
  if(source == "direction_mode")
    return "Direction Mode";
  if(source == "debug_equity_guard")
    return "Debug Equity Guard";
  if(source == "spread_guard")
    return "Spread Guard";
  if(source == "market_hours")
    return "Market Hours";
  return source;
}

string ClampUiValue(const string value,
                    const int max_chars)
{
  if(max_chars < 4)
    return value;

  int len = StringLen(value);
  if(len <= max_chars)
    return value;

  return StringSubstr(value, 0, max_chars - 3) + "...";
}

string LightweightUiRowObjectName(const int row_index)
{
  if(row_index <= 0)
    return EA_CHART_UI_STATUS;

  return EA_CHART_UI_ROW_PREFIX + IntegerToString(row_index);
}

void InvalidateLightweightUiLayout()
{
  g_chart_ui_layout_dirty = true;
}

void DeleteLightweightUiRows(const long chart_id)
{
  for(int i = 0; i < LIGHTWEIGHT_UI_FULL_MAX_ROWS; i++)
    ObjectDelete(chart_id, LightweightUiRowObjectName(i));
}

void DeleteLightweightUiObjects(const long chart_id)
{
  ObjectDelete(chart_id, EA_CHART_UI_PANEL);
  ObjectDelete(chart_id, EA_CHART_UI_TOGGLE);
  ObjectDelete(chart_id, EA_CHART_UI_DETAILS);
  DeleteLightweightUiRows(chart_id);
}

void ResetLightweightUiCache()
{
  g_chart_ui_last_button_text = "";
  g_chart_ui_last_details_button_text = "";
  ArrayResize(g_chart_ui_last_rows, 0);
  g_chart_ui_last_snapshot = LightweightUiChartSnapshot();
  g_chart_ui_last_profile = LIGHTWEIGHT_UI_PROFILE_FULL;
  g_chart_ui_layout_dirty = true;
  g_chart_ui_details_expanded = false;
  g_chart_ui_last_details_visible = false;
}

color ResolveChartColor(const long chart_id,
                        const ENUM_CHART_PROPERTY_INTEGER chart_prop,
                        const color fallback_color)
{
  long chart_color = 0;
  if(ChartGetInteger(chart_id, chart_prop, 0, chart_color))
    return (color)chart_color;
  return fallback_color;
}

color ResolveUiTextColor(const long chart_id)
{
  return ResolveChartColor(chart_id, CHART_COLOR_FOREGROUND, COLOR_CHART_FOREGROUND);
}

color ResolveUiBorderColor(const long chart_id)
{
  return ResolveUiTextColor(chart_id);
}

color ResolveUiPanelFillColor(const long chart_id)
{
  color chart_background = ResolveChartColor(chart_id,
                                             CHART_COLOR_BACKGROUND,
                                             COLOR_CHART_BACKGROUND);
  return (color)ColorToARGB(chart_background, LIGHTWEIGHT_UI_PANEL_FILL_ALPHA);
}

color ResolveUiButtonTextColor(const long chart_id)
{
  return ResolveChartColor(chart_id, CHART_COLOR_BACKGROUND, COLOR_CHART_BACKGROUND);
}

color ResolveUiButtonBackground(const long chart_id,
                                const bool fib_ea_enabled)
{
  if(fib_ea_enabled)
    return ResolveChartColor(chart_id, CHART_COLOR_CHART_UP, COLOR_PROFIT_POSITIVE);

  return ResolveChartColor(chart_id, CHART_COLOR_CHART_DOWN, COLOR_PROFIT_NEGATIVE);
}

color ResolveUiDetailsButtonBackground(const long chart_id)
{
  return ResolveChartColor(chart_id, CHART_COLOR_FOREGROUND, COLOR_CHART_FOREGROUND);
}

void EnsureLightweightUiRowObject(const long chart_id,
                                  const string object_name,
                                  const LightweightUiLayoutMetrics &layout,
                                  const int row_y,
                                  const color text_color)
{
  if(ObjectFind(chart_id, object_name) < 0)
  {
    ObjectCreate(chart_id, object_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
  }

  ObjectSetInteger(chart_id, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id,
                   object_name,
                   OBJPROP_XDISTANCE,
                   layout.panel_x + layout.panel_padding_x);
  ObjectSetInteger(chart_id, object_name, OBJPROP_YDISTANCE, row_y);
  ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, text_color);
  ObjectSetString(chart_id, object_name, OBJPROP_FONT, layout.font_name);
  ObjectSetInteger(chart_id, object_name, OBJPROP_FONTSIZE, layout.font_size);
}

void EnsureLightweightUiObjects(const long chart_id,
                                const LightweightUiLayoutMetrics &layout,
                                const int panel_height,
                                const color border_color,
                                const color panel_fill,
                                const color button_text_color,
                                const color details_button_bg)
{
  if(ObjectFind(chart_id, EA_CHART_UI_PANEL) < 0)
    ObjectCreate(chart_id, EA_CHART_UI_PANEL, OBJ_RECTANGLE_LABEL, 0, 0, 0);

  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XDISTANCE, layout.panel_x);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YDISTANCE, layout.panel_y);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XSIZE, layout.panel_width);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YSIZE, panel_height);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BORDER_TYPE, BORDER_FLAT);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_COLOR, border_color);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BGCOLOR, panel_fill);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_HIDDEN, false);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BACK, false);

  if(ObjectFind(chart_id, EA_CHART_UI_TOGGLE) < 0)
    ObjectCreate(chart_id, EA_CHART_UI_TOGGLE, OBJ_BUTTON, 0, 0, 0);

  int button_x = layout.panel_x + layout.panel_padding_x;
  int button_w = layout.panel_width - layout.panel_padding_x * 2;
  if(button_w < 120)
    button_w = 120;

  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XDISTANCE, button_x);
  ObjectSetInteger(chart_id,
                   EA_CHART_UI_TOGGLE,
                   OBJPROP_YDISTANCE,
                   layout.panel_y + layout.button_top_offset);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XSIZE, button_w);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YSIZE, layout.button_h);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_COLOR, button_text_color);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BORDER_COLOR, border_color);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_STATE, false);
  ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_FONT, layout.font_name);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_FONTSIZE, layout.button_font_size);

  if(layout.show_details_button)
  {
    if(ObjectFind(chart_id, EA_CHART_UI_DETAILS) < 0)
      ObjectCreate(chart_id, EA_CHART_UI_DETAILS, OBJ_BUTTON, 0, 0, 0);

    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_XDISTANCE, button_x);
    ObjectSetInteger(chart_id,
                     EA_CHART_UI_DETAILS,
                     OBJPROP_YDISTANCE,
                     layout.panel_y +
                     layout.button_top_offset +
                     layout.button_h +
                     LIGHTWEIGHT_UI_BUTTON_GAP_Y);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_XSIZE, button_w);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_YSIZE, layout.details_button_h);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_COLOR, button_text_color);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_BORDER_COLOR, border_color);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_BGCOLOR, details_button_bg);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_STATE, false);
    ObjectSetString(chart_id, EA_CHART_UI_DETAILS, OBJPROP_FONT, layout.font_name);
    ObjectSetInteger(chart_id, EA_CHART_UI_DETAILS, OBJPROP_FONTSIZE, layout.font_size);
  }
  else
  {
    ObjectDelete(chart_id, EA_CHART_UI_DETAILS);
  }
}

void AddLightweightUiRow(string &rows[],
                         const string label,
                         const string value,
                         const int max_value_chars)
{
  int total = ArraySize(rows);
  ArrayResize(rows, total + 1);
  rows[total] = label + ": " + ClampUiValue(value, max_value_chars);
}

void AppendUiRowText(string &rows[],
                     const string row_value)
{
  int total = ArraySize(rows);
  ArrayResize(rows, total + 1);
  rows[total] = row_value;
}

void AppendUiRowsWithLimit(string &target_rows[],
                           string &source_rows[],
                           const int row_limit)
{
  int source_total = ArraySize(source_rows);
  for(int i = 0; i < source_total; i++)
  {
    if(ArraySize(target_rows) >= row_limit)
      return;
    AppendUiRowText(target_rows, source_rows[i]);
  }
}

void CollectAddonUiState(string &requested_addons[],
                         string &granted_addons[],
                         string &missing_addons[])
{
  LicenseCopyRequestedAddons(requested_addons);
  LicenseCopyGrantedAddons(granted_addons);
  LicenseCopyMissingAddons(missing_addons);
}

string ResolveRuntimeTickBlockSource()
{
  if(g_points_spread > Max_Spread)
    return "spread_guard";

  if(!IsMarketOpen())
    return "market_hours";

  return "";
}

string BuildCompactAddonSummary(const int requested_total,
                                const int granted_total,
                                const int missing_total)
{
  if(requested_total <= 0)
    return "none requested";

  int covered_total = granted_total;
  if(covered_total > requested_total)
    covered_total = requested_total;

  if(missing_total > 0)
    return StringFormat("requested=%d missing=%d",
                        requested_total,
                        missing_total);

  return StringFormat("requested=%d covered=%d",
                      requested_total,
                      covered_total);
}

void BuildFullAddonRows(string &rows[],
                        const string requested_labels,
                        const string granted_labels,
                        const string missing_labels,
                        const int max_value_chars)
{
  AddLightweightUiRow(rows, "Requested (Inputs)", requested_labels, max_value_chars);
  AddLightweightUiRow(rows, "Purchased Addons", granted_labels, max_value_chars);
  AddLightweightUiRow(rows, "Missing Required", missing_labels, max_value_chars);
}

void BuildCompactAddonRows(string &compact_rows[],
                           string &detail_rows[],
                           const int requested_total,
                           const int granted_total,
                           const int missing_total,
                           const string requested_labels,
                           const string granted_labels,
                           const string missing_labels,
                           const int max_value_chars)
{
  AddLightweightUiRow(compact_rows,
                      "Addons",
                      BuildCompactAddonSummary(requested_total,
                                              granted_total,
                                              missing_total),
                      max_value_chars);
  BuildFullAddonRows(detail_rows,
                     requested_labels,
                     granted_labels,
                     missing_labels,
                     max_value_chars);
}

void BuildCompactSignalRows(string &compact_rows[],
                            string &detail_rows[],
                            string &summary_lines[],
                            const int max_value_chars)
{
  int summary_total = ArraySize(summary_lines);
  if(summary_total <= 0)
    return;

  AddLightweightUiRow(compact_rows, "Signal", summary_lines[0], max_value_chars);

  if(summary_total > 1)
  {
    AddLightweightUiRow(compact_rows,
                        "Signals",
                        StringFormat("%d total", summary_total),
                        max_value_chars);

    for(int i = 1; i < summary_total; i++)
      AddLightweightUiRow(detail_rows,
                          StringFormat("S%d", i + 1),
                          summary_lines[i],
                          max_value_chars);
  }
}

void BuildFullSignalRows(string &rows[],
                         string &summary_lines[],
                         const int max_value_chars)
{
  int summary_total = ArraySize(summary_lines);
  if(summary_total <= 0)
    return;

  int summary_limit = summary_total;
  if(summary_limit > 3)
    summary_limit = 3;

  AddLightweightUiRow(rows,
                      "Signals",
                      IntegerToString(summary_total) + " row(s)",
                      max_value_chars);

  for(int i = 0; i < summary_limit; i++)
    AddLightweightUiRow(rows,
                        StringFormat("S%d", i + 1),
                        summary_lines[i],
                        max_value_chars);
}

void ComposeVisibleRows(string &visible_rows[],
                        string &core_rows[],
                        string &compact_rows[],
                        string &preferred_rows[],
                        string &detail_rows[],
                        const int row_budget,
                        const bool compact_mode,
                        const bool details_expanded,
                        int &hidden_rows)
{
  ArrayResize(visible_rows, 0);

  int safe_row_budget = row_budget;
  int core_total = ArraySize(core_rows);
  if(safe_row_budget < core_total)
    safe_row_budget = core_total;

  AppendUiRowsWithLimit(visible_rows, core_rows, safe_row_budget);
  AppendUiRowsWithLimit(visible_rows, compact_rows, safe_row_budget);

  if(compact_mode)
  {
    AppendUiRowsWithLimit(visible_rows, preferred_rows, safe_row_budget);
    if(details_expanded)
      AppendUiRowsWithLimit(visible_rows, detail_rows, safe_row_budget);
  }
  else
  {
    AppendUiRowsWithLimit(visible_rows, preferred_rows, safe_row_budget);
    AppendUiRowsWithLimit(visible_rows, detail_rows, safe_row_budget);
  }

  int total_candidates = ArraySize(core_rows) +
                         ArraySize(compact_rows) +
                         ArraySize(preferred_rows) +
                         ArraySize(detail_rows);

  hidden_rows = total_candidates - ArraySize(visible_rows);
  if(hidden_rows < 0)
    hidden_rows = 0;
}

string ResolveDetailsButtonText(const int hidden_rows,
                                const bool details_expanded)
{
  if(details_expanded)
    return "LESS DETAILS";
  return StringFormat("MORE DETAILS (+%d)", hidden_rows);
}

string ResolveRuntimeTickBlockReason()
{
  if(g_points_spread > Max_Spread)
    return StringFormat("Spread %.1f exceeds max %.1f", g_points_spread, Max_Spread);

  if(!IsMarketOpen())
    return "Market is closed";

  return "";
}

string ResolveFibEaButtonText()
{
  bool fib_ea_enabled = ManualSignalEntryEnabled() && TerminalAlgoTradingEnabled();
  return "FIBONACCI EA: " + BoolOnOff(fib_ea_enabled);
}

void RenderLightweightStatusTable(const bool ea_running,
                                  const int magic_number,
                                  string &summary_lines[])
{
  long chart_id = ChartID();

  if(!Enable_Chart_Lightweight_UI)
  {
    DeleteLightweightUiObjects(chart_id);
    ResetLightweightUiCache();
    return;
  }

  LightweightUiChartSnapshot snapshot;
  ResolveLightweightUiChartSnapshot(chart_id, snapshot);

  LightweightUiLayoutMetrics base_layout;
  ResolveLightweightUiLayoutMetrics(snapshot, false, base_layout);
  int max_value_chars = ResolveLightweightUiValueMaxChars(base_layout);

  string requested_addons[];
  string granted_addons[];
  string missing_addons[];
  CollectAddonUiState(requested_addons, granted_addons, missing_addons);

  string requested_labels = AddonCatalogJoinDisplayLabels(requested_addons);
  string granted_labels = AddonCatalogJoinDisplayLabels(granted_addons);
  string missing_labels = AddonCatalogJoinDisplayLabels(missing_addons);

  if(requested_labels == "")
    requested_labels = "None";
  if(granted_labels == "")
    granted_labels = "None";
  if(missing_labels == "")
    missing_labels = "None";
  if(ArraySize(requested_addons) <= 0)
    missing_labels = "N/A (no addon requested)";

  string gate_source = "";
  string gate_reason = "";
  bool signal_gate_enabled = ResolveAnyDirectionAttemptPermission(gate_source, gate_reason);

  string runtime_source = ResolveRuntimeTickBlockSource();
  string runtime_reason = ResolveRuntimeTickBlockReason();

  string effective_source = "";
  string effective_reason = "";

  if(!signal_gate_enabled)
  {
    effective_source = ResolveSignalBlockSourceLabel(gate_source);
    effective_reason = gate_reason;
  }
  else if(runtime_source != "")
  {
    effective_source = ResolveSignalBlockSourceLabel(runtime_source);
    effective_reason = runtime_reason;
  }

  bool fib_ea_enabled = (effective_source == "");
  bool algo_enabled = TerminalAlgoTradingEnabled();
  bool manual_enabled = ManualSignalEntryEnabled();

  string market_status = MarketStatusToString(MarketStatusGet());
  string market_reason = MarketStatusReason();
  if(market_reason != "")
    market_status = market_status + " (" + market_reason + ")";

  string core_rows[];
  string compact_rows[];
  string preferred_rows[];
  string detail_rows[];
  bool compact_mode = IsLightweightUiCompactProfile(base_layout.profile);

  AddLightweightUiRow(core_rows,
                      "Fibonacci EA",
                      BoolOnOff(fib_ea_enabled && ea_running),
                      max_value_chars);
  AddLightweightUiRow(core_rows,
                      "Algo Trading",
                      BoolOnOff(algo_enabled),
                      max_value_chars);
  AddLightweightUiRow(core_rows,
                      "Manual Toggle",
                      BoolOnOff(manual_enabled),
                      max_value_chars);
  AddLightweightUiRow(core_rows,
                      "Signal Gate",
                      (signal_gate_enabled ? "ENABLED" : "DISABLED"),
                      max_value_chars);
  AddLightweightUiRow(core_rows,
                      "Market",
                      market_status,
                      max_value_chars);

  if(effective_source != "")
    AddLightweightUiRow(core_rows, "Block Source", effective_source, max_value_chars);
  if(effective_reason != "")
    AddLightweightUiRow(core_rows, "Block Reason", effective_reason, max_value_chars);

  AddLightweightUiRow(preferred_rows,
                      "Magic",
                      IntegerToString(magic_number),
                      max_value_chars);

  if(compact_mode)
  {
    if(Enable_Chart_Summary)
      BuildCompactSignalRows(compact_rows,
                             detail_rows,
                             summary_lines,
                             max_value_chars);

    BuildCompactAddonRows(compact_rows,
                          detail_rows,
                          ArraySize(requested_addons),
                          ArraySize(granted_addons),
                          ArraySize(missing_addons),
                          requested_labels,
                          granted_labels,
                          missing_labels,
                          max_value_chars);
  }
  else
  {
    if(Enable_Chart_Summary)
      BuildFullSignalRows(detail_rows,
                          summary_lines,
                          max_value_chars);

    BuildFullAddonRows(detail_rows,
                       requested_labels,
                       granted_labels,
                       missing_labels,
                       max_value_chars);
  }

  int default_row_budget = ResolveLightweightUiRowBudget(snapshot, base_layout);
  int hidden_rows_default = 0;
  string default_rows[];
  ComposeVisibleRows(default_rows,
                     core_rows,
                     compact_rows,
                     preferred_rows,
                     detail_rows,
                     default_row_budget,
                     compact_mode,
                     false,
                     hidden_rows_default);

  bool show_details_button = ShouldShowLightweightUiDetailsButton(base_layout.profile,
                                                                  hidden_rows_default > 0);
  if(!show_details_button)
    g_chart_ui_details_expanded = false;

  LightweightUiLayoutMetrics layout;
  ResolveLightweightUiLayoutMetrics(snapshot, show_details_button, layout);
  int row_budget = ResolveLightweightUiRowBudget(snapshot, layout);
  int rows_hidden = 0;
  bool details_expanded = (layout.show_details_button && g_chart_ui_details_expanded);
  string rows[];
  ComposeVisibleRows(rows,
                     core_rows,
                     compact_rows,
                     preferred_rows,
                     detail_rows,
                     row_budget,
                     compact_mode,
                     details_expanded,
                     rows_hidden);

  int rows_total = ArraySize(rows);
  if(rows_total <= 0)
  {
    AddLightweightUiRow(rows, "Status", "No data", max_value_chars);
    rows_total = ArraySize(rows);
  }

  color text_color = ResolveUiTextColor(chart_id);
  color border_color = ResolveUiBorderColor(chart_id);
  color panel_fill = ResolveUiPanelFillColor(chart_id);
  color button_text = ResolveUiButtonTextColor(chart_id);
  color details_button_bg = ResolveUiDetailsButtonBackground(chart_id);

  bool layout_changed = g_chart_ui_layout_dirty ||
                        snapshot.chart_width != g_chart_ui_last_snapshot.chart_width ||
                        snapshot.chart_height != g_chart_ui_last_snapshot.chart_height ||
                        layout.profile != g_chart_ui_last_profile ||
                        layout.show_details_button != g_chart_ui_last_details_visible;

  int panel_height = ResolveLightweightUiPanelHeight(layout, rows_total);
  EnsureLightweightUiObjects(chart_id,
                             layout,
                             panel_height,
                             border_color,
                             panel_fill,
                             button_text,
                             details_button_bg);

  int cached_total = ArraySize(g_chart_ui_last_rows);
  if(cached_total < rows_total)
  {
    int previous_size = cached_total;
    ArrayResize(g_chart_ui_last_rows, rows_total);
    for(int i = previous_size; i < rows_total; i++)
      g_chart_ui_last_rows[i] = "";
  }

  for(int i = 0; i < rows_total; i++)
  {
    string row_name = LightweightUiRowObjectName(i);
    int row_y = layout.panel_y + layout.first_row_offset + i * layout.row_step;

    EnsureLightweightUiRowObject(chart_id, row_name, layout, row_y, text_color);
    if(g_chart_ui_last_rows[i] != rows[i])
    {
      ObjectSetString(chart_id, row_name, OBJPROP_TEXT, rows[i]);
      g_chart_ui_last_rows[i] = rows[i];
      layout_changed = true;
    }
  }

  if(cached_total > rows_total)
  {
    for(int i = rows_total; i < cached_total; i++)
    {
      ObjectDelete(chart_id, LightweightUiRowObjectName(i));
      layout_changed = true;
    }
  }
  ArrayResize(g_chart_ui_last_rows, rows_total);

  string button_text_value = ResolveFibEaButtonText();
  if(button_text_value != g_chart_ui_last_button_text)
  {
    ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_TEXT, button_text_value);
    g_chart_ui_last_button_text = button_text_value;
    layout_changed = true;
  }

  color button_bg = ResolveUiButtonBackground(chart_id, fib_ea_enabled);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BGCOLOR, button_bg);

  if(layout.show_details_button)
  {
    string details_button_text = ResolveDetailsButtonText(rows_hidden, details_expanded);
    if(details_button_text != g_chart_ui_last_details_button_text)
    {
      ObjectSetString(chart_id, EA_CHART_UI_DETAILS, OBJPROP_TEXT, details_button_text);
      g_chart_ui_last_details_button_text = details_button_text;
      layout_changed = true;
    }
  }
  else if(g_chart_ui_last_details_button_text != "")
  {
    g_chart_ui_last_details_button_text = "";
    layout_changed = true;
  }

  g_chart_ui_last_snapshot = snapshot;
  g_chart_ui_last_profile = layout.profile;
  g_chart_ui_last_details_visible = layout.show_details_button;
  g_chart_ui_layout_dirty = false;

  if(layout_changed)
    ChartRedraw(chart_id);
}

bool HandleLightweightChartUiEvent(const int id,
                                   const long &,
                                   const double &,
                                   const string &sparam)
{
  if(id == CHARTEVENT_CHART_CHANGE)
  {
    LightweightUiChartSnapshot current_snapshot;
    ResolveLightweightUiChartSnapshot(ChartID(), current_snapshot);
    if(HasLightweightUiMajorChartChange(g_chart_ui_last_snapshot, current_snapshot))
    {
      InvalidateLightweightUiLayout();
      return true;
    }
    return false;
  }

  if(!Enable_Chart_Lightweight_UI)
    return false;

  if(id != CHARTEVENT_OBJECT_CLICK)
    return false;

  if(sparam == EA_CHART_UI_DETAILS)
  {
    g_chart_ui_details_expanded = !g_chart_ui_details_expanded;
    InvalidateLightweightUiLayout();
    return true;
  }

  if(sparam != EA_CHART_UI_TOGGLE)
    return false;

  if(!TerminalAlgoTradingEnabled())
  {
    Print("[UI] Cannot enable FIBONACCI EA while MT5 Algo Trading is OFF.");
    return false;
  }

  SetManualSignalEntryEnabled(!ManualSignalEntryEnabled());
  PrintFormat("[UI] Manual signal toggle set to %s.",
              (ManualSignalEntryEnabled() ? "ON" : "OFF"));

  InvalidateLightweightUiLayout();
  return true;
}

string NormalizeRemovalReason(const string removal_message)
{
  string normalized = removal_message;
  StringTrimLeft(normalized);
  StringTrimRight(normalized);

  if(normalized == "")
    return "";

  string lower = normalized;
  StringToLower(lower);

  string hft_prefix = "hft grid ai removed:";
  if(StringFind(lower, hft_prefix) == 0)
  {
    normalized = StringSubstr(normalized, StringLen(hft_prefix));
    StringTrimLeft(normalized);
    StringTrimRight(normalized);
  }

  lower = normalized;
  StringToLower(lower);
  string fib_prefix = "fibonacci ea removed:";
  if(StringFind(lower, fib_prefix) == 0)
  {
    normalized = StringSubstr(normalized, StringLen(fib_prefix));
    StringTrimLeft(normalized);
    StringTrimRight(normalized);
  }

  return normalized;
}

int ResolveErrorMessageMaxChars(const long chart_id)
{
  LightweightUiChartSnapshot snapshot;
  ResolveLightweightUiChartSnapshot(chart_id, snapshot);

  LightweightUiLayoutMetrics layout;
  ResolveLightweightUiLayoutMetrics(snapshot, false, layout);

  int max_chars = ResolveLightweightUiValueMaxChars(layout) + 12;
  if(max_chars < 48)
    max_chars = 48;
  if(max_chars > 160)
    max_chars = 160;
  return max_chars;
}

void RenderPersistentChartError(const string error_message)
{
  long chart_id = ChartID();
  string reason_message = NormalizeRemovalReason(error_message);
  if(reason_message == "")
    reason_message = "unknown error.";

  string header = "FIBONACCI EA REMOVED";
  string prefix = header + " | ";
  int max_line_chars = ResolveErrorMessageMaxChars(chart_id);
  int reason_max_chars = max_line_chars - StringLen(prefix);
  if(reason_max_chars < 12)
    reason_max_chars = 12;

  string final_text = prefix + ClampUiValue(reason_message, reason_max_chars);

  ObjectDelete(chart_id, EA_CHART_ERROR_OBJECT);
  ObjectCreate(chart_id, EA_CHART_ERROR_OBJECT, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_XDISTANCE, 12);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_YDISTANCE, 24);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_COLOR, clrTomato);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_FONTSIZE, 9);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_HIDDEN, false);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
  ObjectSetString(chart_id,
                  EA_CHART_ERROR_OBJECT,
                  OBJPROP_FONT,
                  "Consolas");
  ObjectSetString(chart_id,
                  EA_CHART_ERROR_OBJECT,
                  OBJPROP_TEXT,
                  final_text);
}

void ClearPersistentChartError()
{
  ObjectDelete(ChartID(), EA_CHART_ERROR_OBJECT);
}

#endif // _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
