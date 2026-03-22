#ifndef _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
#define _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_

#include "../shared/license_guard_v1/core/addon_catalog.mqh"

const uchar LIGHTWEIGHT_UI_PANEL_FILL_ALPHA = 36;
const int LIGHTWEIGHT_UI_FIT_RAW_ROW_MAX_CHARS = 512;

string g_chart_ui_last_button_text = "";
string g_chart_ui_last_details_button_text = "";
string g_chart_ui_last_rows[];
string g_chart_ui_last_diag_signature = "";
LightweightUiChartSnapshot g_chart_ui_last_snapshot;
LightweightUiProfiles g_chart_ui_last_profile = LIGHTWEIGHT_UI_PROFILE_FULL;
bool g_chart_ui_last_pressured = false;
int g_chart_ui_last_fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE;
int g_chart_ui_last_panel_width = 0;
int g_chart_ui_last_row_step = 0;
int g_chart_ui_last_font_size = 0;
int g_chart_ui_last_panel_x = 0;
int g_chart_ui_last_panel_y = 0;
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

enum LightweightUiRowLabelKeys
{
  LIGHTWEIGHT_UI_LABEL_FIBONACCI = 0,
  LIGHTWEIGHT_UI_LABEL_ALGO = 1,
  LIGHTWEIGHT_UI_LABEL_MANUAL = 2,
  LIGHTWEIGHT_UI_LABEL_GATE = 3,
  LIGHTWEIGHT_UI_LABEL_MARKET = 4,
  LIGHTWEIGHT_UI_LABEL_BLOCK_SOURCE = 5,
  LIGHTWEIGHT_UI_LABEL_BLOCK_REASON = 6,
  LIGHTWEIGHT_UI_LABEL_MAGIC = 7,
  LIGHTWEIGHT_UI_LABEL_SIGNAL = 8,
  LIGHTWEIGHT_UI_LABEL_SIGNALS = 9,
  LIGHTWEIGHT_UI_LABEL_ADDONS = 10,
  LIGHTWEIGHT_UI_LABEL_REQUESTED = 11,
  LIGHTWEIGHT_UI_LABEL_PURCHASED = 12,
  LIGHTWEIGHT_UI_LABEL_MISSING = 13
};

string ResolveLightweightUiRowLabel(const LightweightUiRowLabelKeys label_key,
                                    const bool compact_mode,
                                    const bool pressured_mode)
{
  bool short_labels = (compact_mode || pressured_mode);

  if(label_key == LIGHTWEIGHT_UI_LABEL_FIBONACCI)
    return (short_labels ? "Fib EA" : "Fibonacci EA");
  if(label_key == LIGHTWEIGHT_UI_LABEL_ALGO)
    return (short_labels ? "Algo" : "Algo Trading");
  if(label_key == LIGHTWEIGHT_UI_LABEL_MANUAL)
    return (short_labels ? "Manual" : "Manual Toggle");
  if(label_key == LIGHTWEIGHT_UI_LABEL_GATE)
    return (short_labels ? "Gate" : "Signal Gate");
  if(label_key == LIGHTWEIGHT_UI_LABEL_MARKET)
    return "Market";
  if(label_key == LIGHTWEIGHT_UI_LABEL_BLOCK_SOURCE)
    return (short_labels ? "Block" : "Block Source");
  if(label_key == LIGHTWEIGHT_UI_LABEL_BLOCK_REASON)
    return (short_labels ? "Reason" : "Block Reason");
  if(label_key == LIGHTWEIGHT_UI_LABEL_MAGIC)
    return "Magic";
  if(label_key == LIGHTWEIGHT_UI_LABEL_SIGNAL)
    return "Signal";
  if(label_key == LIGHTWEIGHT_UI_LABEL_SIGNALS)
    return "Signals";
  if(label_key == LIGHTWEIGHT_UI_LABEL_ADDONS)
    return "Addons";
  if(label_key == LIGHTWEIGHT_UI_LABEL_REQUESTED)
    return (short_labels ? "Requested" : "Requested (Inputs)");
  if(label_key == LIGHTWEIGHT_UI_LABEL_PURCHASED)
    return (short_labels ? "Owned" : "Purchased Addons");
  if(label_key == LIGHTWEIGHT_UI_LABEL_MISSING)
    return "Missing";

  return "";
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
  g_chart_ui_last_diag_signature = "";
  ArrayResize(g_chart_ui_last_rows, 0);
  g_chart_ui_last_snapshot = LightweightUiChartSnapshot();
  g_chart_ui_last_profile = LIGHTWEIGHT_UI_PROFILE_FULL;
  g_chart_ui_last_pressured = false;
  g_chart_ui_last_fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE;
  g_chart_ui_last_panel_width = 0;
  g_chart_ui_last_row_step = 0;
  g_chart_ui_last_font_size = 0;
  g_chart_ui_last_panel_x = 0;
  g_chart_ui_last_panel_y = 0;
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
                         const int max_row_chars)
{
  int total = ArraySize(rows);
  ArrayResize(rows, total + 1);
  rows[total] = BuildLightweightUiRowText(label, value, max_row_chars);
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

string ResolveLightweightUiProfileLabel(const LightweightUiProfiles profile)
{
  if(IsLightweightUiCompactProfile(profile))
    return "COMPACT";
  return "FULL";
}

string ResolveLightweightUiFitReasonLabel(const int fit_reason)
{
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_DIMENSION_COMPACT)
    return "DIMENSION_COMPACT";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE)
    return "FULL_SAFE";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_DENSITY)
    return "FULL_PRESSURED_DENSITY";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_TEXT_FIT)
    return "FULL_PRESSURED_TEXT_FIT";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_COMPACT_MIN_WIDTH_DENSE)
    return "COMPACT_MIN_WIDTH_DENSE";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_COMPACT_WIDTH_OVERFLOW)
    return "COMPACT_WIDTH_OVERFLOW";
  if(fit_reason == LIGHTWEIGHT_UI_FIT_REASON_COMPACT_SIGNAL_DENSITY)
    return "COMPACT_SIGNAL_DENSITY";
  return "UNKNOWN";
}

string BuildLightweightUiDiagnosticSignature(const LightweightUiChartSnapshot &snapshot,
                                             const LightweightUiFitDecision &fit_decision,
                                             const LightweightUiLayoutMetrics &layout,
                                             const int row_budget,
                                             const int rows_hidden,
                                             const bool details_expanded,
                                             string &rows[])
{
  string signature = StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
                                  snapshot.chart_width,
                                  snapshot.chart_height,
                                  layout.profile,
                                  layout.pressured,
                                  fit_decision.fit_reason,
                                  layout.panel_width,
                                  layout.row_step,
                                  layout.font_size,
                                  layout.max_row_chars,
                                  fit_decision.longest_row_chars,
                                  fit_decision.over_budget_rows,
                                  fit_decision.total_candidate_rows,
                                  row_budget,
                                  ArraySize(rows),
                                  rows_hidden,
                                  layout.show_details_button,
                                  details_expanded);

  int rows_total = ArraySize(rows);
  for(int i = 0; i < rows_total; i++)
    signature = signature + "|" + rows[i];

  return signature;
}

void LogLightweightUiEventDiagnostic(const string tag,
                                     const string message)
{
  if(!Enable_Chart_Ui_Debug_Logs)
    return;

  PrintFormat("[UI_DIAG] %s | %s",
              tag,
              message);
}

void LogLightweightUiDiagnostics(const long chart_id,
                                 const LightweightUiChartSnapshot &snapshot,
                                 const LightweightUiFitDecision &fit_decision,
                                 const LightweightUiLayoutMetrics &layout,
                                 const int row_budget,
                                 const int rows_hidden,
                                 const bool details_expanded,
                                 string &rows[])
{
  if(!Enable_Chart_Ui_Debug_Logs)
    return;

  string signature = BuildLightweightUiDiagnosticSignature(snapshot,
                                                           fit_decision,
                                                           layout,
                                                           row_budget,
                                                           rows_hidden,
                                                           details_expanded,
                                                           rows);
  if(signature == g_chart_ui_last_diag_signature)
    return;

  g_chart_ui_last_diag_signature = signature;

  long actual_panel_x = ObjectGetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XDISTANCE);
  long actual_panel_y = ObjectGetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YDISTANCE);
  long actual_panel_w = ObjectGetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XSIZE);
  long actual_panel_h = ObjectGetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YSIZE);
  long actual_toggle_x = ObjectGetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XDISTANCE);
  long actual_toggle_y = ObjectGetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YDISTANCE);
  long actual_toggle_w = ObjectGetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XSIZE);
  long actual_toggle_h = ObjectGetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YSIZE);

  PrintFormat("[UI_DIAG] layout chart=%I64d symbol=%s period=%d valid=%s width=%d height=%d profile=%s pressured=%s fit_reason=%s reduced=%s details_button=%s details_expanded=%s panel=(x=%d y=%d w=%d h=%d) actual_panel=(x=%I64d y=%I64d w=%I64d h=%I64d) toggle=(x=%I64d y=%I64d w=%I64d h=%I64d) font=%s/%d button_font=%d row_step=%d row_budget=%d rows_total=%d hidden_rows=%d row_max_chars=%d value_max_chars=%d longest_row_chars=%d over_budget_rows=%d candidate_rows=%d full_panel_w=%d full_min_width=%s",
              chart_id,
              _Symbol,
              _Period,
              BoolOnOff(snapshot.valid),
              snapshot.chart_width,
              snapshot.chart_height,
              ResolveLightweightUiProfileLabel(layout.profile),
              BoolOnOff(layout.pressured),
              ResolveLightweightUiFitReasonLabel(fit_decision.fit_reason),
              BoolOnOff(layout.reduced_margins),
              BoolOnOff(layout.show_details_button),
              BoolOnOff(details_expanded),
              layout.panel_x,
              layout.panel_y,
              layout.panel_width,
              ResolveLightweightUiPanelHeight(layout, ArraySize(rows)),
              actual_panel_x,
              actual_panel_y,
              actual_panel_w,
              actual_panel_h,
              actual_toggle_x,
              actual_toggle_y,
              actual_toggle_w,
              actual_toggle_h,
              layout.font_name,
              layout.font_size,
              layout.button_font_size,
              layout.row_step,
              row_budget,
              ArraySize(rows),
              rows_hidden,
              layout.max_row_chars,
              layout.max_value_chars,
              fit_decision.longest_row_chars,
              fit_decision.over_budget_rows,
              fit_decision.total_candidate_rows,
              fit_decision.full_panel_width,
              BoolOnOff(fit_decision.full_at_min_width));

  int rows_total = ArraySize(rows);
  for(int i = 0; i < rows_total; i++)
  {
    int row_y = layout.panel_y + layout.first_row_offset + i * layout.row_step;
    PrintFormat("[UI_DIAG] row[%d] y=%d chars=%d text=\"%s\"",
                i,
                row_y,
                StringLen(rows[i]),
                rows[i]);
  }
}

string BuildCompactAddonSummary(const int requested_total,
                                const int granted_total,
                                const int missing_total)
{
  if(requested_total <= 0)
    return "none requested";

  int owned_total = granted_total;
  if(owned_total > requested_total)
    owned_total = requested_total;

  if(missing_total > 0)
    return StringFormat("req=%d own=%d miss=%d",
                        requested_total,
                        owned_total,
                        missing_total);

  return StringFormat("req=%d own=%d",
                      requested_total,
                      owned_total);
}

void BuildFullAddonRows(string &rows[],
                        const bool compact_mode,
                        const bool pressured_mode,
                        const string requested_labels,
                        const string granted_labels,
                        const string missing_labels,
                        const int max_row_chars)
{
  AddLightweightUiRow(rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_REQUESTED,
                                                   compact_mode,
                                                   pressured_mode),
                      requested_labels,
                      max_row_chars);
  AddLightweightUiRow(rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_PURCHASED,
                                                   compact_mode,
                                                   pressured_mode),
                      granted_labels,
                      max_row_chars);
  AddLightweightUiRow(rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_MISSING,
                                                   compact_mode,
                                                   pressured_mode),
                      missing_labels,
                      max_row_chars);
}

void BuildPressuredAddonRows(string &summary_rows[],
                             string &detail_rows[],
                             const int requested_total,
                             const int granted_total,
                             const int missing_total,
                             const string missing_labels,
                             const int max_row_chars)
{
  AddLightweightUiRow(summary_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_ADDONS,
                                                   false,
                                                   true),
                      BuildCompactAddonSummary(requested_total,
                                              granted_total,
                                              missing_total),
                      max_row_chars);

  if(missing_total > 0)
  {
    AddLightweightUiRow(detail_rows,
                        ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_MISSING,
                                                     false,
                                                     true),
                        missing_labels,
                        max_row_chars);
  }
}

void BuildCompactAddonRows(string &compact_rows[],
                           string &detail_rows[],
                           const int requested_total,
                           const int granted_total,
                           const int missing_total,
                           const string requested_labels,
                           const string granted_labels,
                           const string missing_labels,
                           const int max_row_chars)
{
  AddLightweightUiRow(compact_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_ADDONS,
                                                   true,
                                                   false),
                      BuildCompactAddonSummary(requested_total,
                                              granted_total,
                                              missing_total),
                      max_row_chars);
  BuildFullAddonRows(detail_rows,
                     true,
                     false,
                     requested_labels,
                     granted_labels,
                     missing_labels,
                     max_row_chars);
}

void BuildCompactSignalRows(string &compact_rows[],
                            string &detail_rows[],
                            string &summary_lines[],
                            const int max_row_chars)
{
  int summary_total = ArraySize(summary_lines);
  if(summary_total <= 0)
    return;

  AddLightweightUiRow(compact_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_SIGNAL,
                                                   true,
                                                   false),
                      summary_lines[0],
                      max_row_chars);

  if(summary_total > 1)
  {
    AddLightweightUiRow(compact_rows,
                        ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_SIGNALS,
                                                     true,
                                                     false),
                        StringFormat("%d total", summary_total),
                        max_row_chars);

    for(int i = 1; i < summary_total; i++)
      AddLightweightUiRow(detail_rows,
                          StringFormat("S%d", i + 1),
                          summary_lines[i],
                          max_row_chars);
  }
}

void BuildPressuredSignalRows(string &rows[],
                              string &summary_lines[],
                              const int max_row_chars)
{
  int summary_total = ArraySize(summary_lines);
  if(summary_total <= 0)
    return;

  AddLightweightUiRow(rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_SIGNAL,
                                                   false,
                                                   true),
                      summary_lines[0],
                      max_row_chars);

  if(summary_total > 1)
  {
    AddLightweightUiRow(rows,
                        ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_SIGNALS,
                                                     false,
                                                     true),
                        StringFormat("%d total", summary_total),
                        max_row_chars);
  }
}

void BuildFullSignalRows(string &rows[],
                         const bool compact_mode,
                         const bool pressured_mode,
                         string &summary_lines[],
                         const int max_row_chars)
{
  int summary_total = ArraySize(summary_lines);
  if(summary_total <= 0)
    return;

  int summary_limit = summary_total;
  if(summary_limit > 3)
    summary_limit = 3;

  AddLightweightUiRow(rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_SIGNALS,
                                                   compact_mode,
                                                   pressured_mode),
                      IntegerToString(summary_total) + " row(s)",
                      max_row_chars);

  for(int i = 0; i < summary_limit; i++)
    AddLightweightUiRow(rows,
                        StringFormat("S%d", i + 1),
                        summary_lines[i],
                        max_row_chars);
}

void AccumulateLightweightUiRowStats(string &rows[],
                                     const int row_max_chars,
                                     int &total_rows,
                                     int &longest_row_chars,
                                     int &over_budget_rows)
{
  int rows_total = ArraySize(rows);
  total_rows += rows_total;

  for(int i = 0; i < rows_total; i++)
  {
    int row_chars = StringLen(rows[i]);
    if(row_chars > longest_row_chars)
      longest_row_chars = row_chars;
    if(row_max_chars > 0 && row_chars > row_max_chars)
      over_budget_rows++;
  }
}

void BuildLightweightUiFitInputs(const LightweightUiLayoutMetrics &full_layout,
                                 string &core_rows[],
                                 string &compact_rows[],
                                 string &preferred_rows[],
                                 string &detail_rows[],
                                 const int signal_detail_rows,
                                 LightweightUiFitInputs &fit_inputs)
{
  fit_inputs = LightweightUiFitInputs();
  fit_inputs.signal_detail_rows = signal_detail_rows;
  fit_inputs.full_panel_width = full_layout.panel_width;
  fit_inputs.full_row_max_chars = full_layout.max_row_chars;
  fit_inputs.full_at_min_width = IsLightweightUiPanelAtMinWidth(full_layout);

  AccumulateLightweightUiRowStats(core_rows,
                                  full_layout.max_row_chars,
                                  fit_inputs.total_candidate_rows,
                                  fit_inputs.longest_row_chars,
                                  fit_inputs.over_budget_rows);
  AccumulateLightweightUiRowStats(compact_rows,
                                  full_layout.max_row_chars,
                                  fit_inputs.total_candidate_rows,
                                  fit_inputs.longest_row_chars,
                                  fit_inputs.over_budget_rows);
  AccumulateLightweightUiRowStats(preferred_rows,
                                  full_layout.max_row_chars,
                                  fit_inputs.total_candidate_rows,
                                  fit_inputs.longest_row_chars,
                                  fit_inputs.over_budget_rows);
  AccumulateLightweightUiRowStats(detail_rows,
                                  full_layout.max_row_chars,
                                  fit_inputs.total_candidate_rows,
                                  fit_inputs.longest_row_chars,
                                  fit_inputs.over_budget_rows);
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

void BuildLightweightUiRowSets(const bool compact_mode,
                               const bool pressured_mode,
                               const int row_max_chars,
                               const bool ea_running,
                               const bool fib_ea_enabled,
                               const bool algo_enabled,
                               const bool manual_enabled,
                               const bool signal_gate_enabled,
                               const string market_status,
                               const string effective_source,
                               const string effective_reason,
                               const int magic_number,
                               string &summary_lines[],
                               const int requested_total,
                               const int granted_total,
                               const int missing_total,
                               const string requested_labels,
                               const string granted_labels,
                               const string missing_labels,
                               string &core_rows[],
                               string &compact_rows[],
                               string &preferred_rows[],
                               string &detail_rows[])
{
  ArrayResize(core_rows, 0);
  ArrayResize(compact_rows, 0);
  ArrayResize(preferred_rows, 0);
  ArrayResize(detail_rows, 0);

  AddLightweightUiRow(core_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_FIBONACCI,
                                                   compact_mode,
                                                   pressured_mode),
                      BoolOnOff(fib_ea_enabled && ea_running),
                      row_max_chars);
  AddLightweightUiRow(core_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_ALGO,
                                                   compact_mode,
                                                   pressured_mode),
                      BoolOnOff(algo_enabled),
                      row_max_chars);
  AddLightweightUiRow(core_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_MANUAL,
                                                   compact_mode,
                                                   pressured_mode),
                      BoolOnOff(manual_enabled),
                      row_max_chars);
  AddLightweightUiRow(core_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_GATE,
                                                   compact_mode,
                                                   pressured_mode),
                      (signal_gate_enabled ? "ENABLED" : "DISABLED"),
                      row_max_chars);
  AddLightweightUiRow(core_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_MARKET,
                                                   compact_mode,
                                                   pressured_mode),
                      market_status,
                      row_max_chars);

  if(effective_source != "")
  {
    AddLightweightUiRow(core_rows,
                        ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_BLOCK_SOURCE,
                                                     compact_mode,
                                                     pressured_mode),
                        effective_source,
                        row_max_chars);
  }
  if(effective_reason != "")
  {
    AddLightweightUiRow(core_rows,
                        ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_BLOCK_REASON,
                                                     compact_mode,
                                                     pressured_mode),
                        effective_reason,
                        row_max_chars);
  }

  AddLightweightUiRow(preferred_rows,
                      ResolveLightweightUiRowLabel(LIGHTWEIGHT_UI_LABEL_MAGIC,
                                                   compact_mode,
                                                   pressured_mode),
                      IntegerToString(magic_number),
                      row_max_chars);

  if(compact_mode)
  {
    if(Enable_Chart_Summary)
      BuildCompactSignalRows(compact_rows,
                             detail_rows,
                             summary_lines,
                             row_max_chars);

    BuildCompactAddonRows(compact_rows,
                          detail_rows,
                          requested_total,
                          granted_total,
                          missing_total,
                          requested_labels,
                          granted_labels,
                          missing_labels,
                          row_max_chars);
    return;
  }

  if(pressured_mode)
  {
    if(Enable_Chart_Summary)
      BuildPressuredSignalRows(compact_rows,
                               summary_lines,
                               row_max_chars);

    BuildPressuredAddonRows(compact_rows,
                            detail_rows,
                            requested_total,
                            granted_total,
                            missing_total,
                            missing_labels,
                            row_max_chars);
    return;
  }

  if(Enable_Chart_Summary)
    BuildFullSignalRows(detail_rows,
                        compact_mode,
                        pressured_mode,
                        summary_lines,
                        row_max_chars);

  BuildFullAddonRows(detail_rows,
                     compact_mode,
                     pressured_mode,
                     requested_labels,
                     granted_labels,
                     missing_labels,
                     row_max_chars);
}

void RenderLightweightStatusTable(const bool ea_running,
                                  const int magic_number,
                                  string &summary_lines[])
{
  if(FrontendSkippingChartWork())
  {
    ResetLightweightUiCache();
    return;
  }

  long chart_id = ChartID();

  if(!Enable_Chart_Lightweight_UI)
  {
    DeleteLightweightUiObjects(chart_id);
    ResetLightweightUiCache();
    return;
  }

  LightweightUiChartSnapshot snapshot;
  ResolveLightweightUiChartSnapshot(chart_id, snapshot);

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

  LightweightUiLayoutMetrics provisional_full_layout;
  ResolveLightweightUiLayoutMetricsForProfile(snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_FULL,
                                              false,
                                              false,
                                              provisional_full_layout);

  string fit_core_rows[];
  string fit_compact_rows[];
  string fit_preferred_rows[];
  string fit_detail_rows[];
  BuildLightweightUiRowSets(false,
                            false,
                            LIGHTWEIGHT_UI_FIT_RAW_ROW_MAX_CHARS,
                            ea_running,
                            fib_ea_enabled,
                            algo_enabled,
                            manual_enabled,
                            signal_gate_enabled,
                            market_status,
                            effective_source,
                            effective_reason,
                            magic_number,
                            summary_lines,
                            ArraySize(requested_addons),
                            ArraySize(granted_addons),
                            ArraySize(missing_addons),
                            requested_labels,
                            granted_labels,
                            missing_labels,
                            fit_core_rows,
                            fit_compact_rows,
                            fit_preferred_rows,
                            fit_detail_rows);

  LightweightUiFitInputs fit_inputs;
  BuildLightweightUiFitInputs(provisional_full_layout,
                              fit_core_rows,
                              fit_compact_rows,
                              fit_preferred_rows,
                              fit_detail_rows,
                              ArraySize(summary_lines),
                              fit_inputs);

  LightweightUiFitDecision fit_decision;
  ResolveLightweightUiFitDecision(snapshot, fit_inputs, fit_decision);

  LightweightUiLayoutMetrics base_layout;
  ResolveLightweightUiLayoutMetricsForProfile(snapshot,
                                              fit_decision.profile,
                                              fit_decision.pressured,
                                              false,
                                              base_layout);
  base_layout.fit_reason = fit_decision.fit_reason;

  string core_rows[];
  string compact_rows[];
  string preferred_rows[];
  string detail_rows[];
  bool compact_mode = IsLightweightUiCompactProfile(fit_decision.profile);
  BuildLightweightUiRowSets(compact_mode,
                            fit_decision.pressured,
                            base_layout.max_row_chars,
                            ea_running,
                            fib_ea_enabled,
                            algo_enabled,
                            manual_enabled,
                            signal_gate_enabled,
                            market_status,
                            effective_source,
                            effective_reason,
                            magic_number,
                            summary_lines,
                            ArraySize(requested_addons),
                            ArraySize(granted_addons),
                            ArraySize(missing_addons),
                            requested_labels,
                            granted_labels,
                            missing_labels,
                            core_rows,
                            compact_rows,
                            preferred_rows,
                            detail_rows);

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
  ResolveLightweightUiLayoutMetricsForProfile(snapshot,
                                              fit_decision.profile,
                                              fit_decision.pressured,
                                              show_details_button,
                                              layout);
  layout.fit_reason = fit_decision.fit_reason;
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
    AddLightweightUiRow(rows, "Status", "No data", layout.max_row_chars);
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
                        layout.pressured != g_chart_ui_last_pressured ||
                        layout.fit_reason != g_chart_ui_last_fit_reason ||
                        layout.panel_width != g_chart_ui_last_panel_width ||
                        layout.row_step != g_chart_ui_last_row_step ||
                        layout.font_size != g_chart_ui_last_font_size ||
                        layout.panel_x != g_chart_ui_last_panel_x ||
                        layout.panel_y != g_chart_ui_last_panel_y ||
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
  g_chart_ui_last_pressured = layout.pressured;
  g_chart_ui_last_fit_reason = layout.fit_reason;
  g_chart_ui_last_panel_width = layout.panel_width;
  g_chart_ui_last_row_step = layout.row_step;
  g_chart_ui_last_font_size = layout.font_size;
  g_chart_ui_last_panel_x = layout.panel_x;
  g_chart_ui_last_panel_y = layout.panel_y;
  g_chart_ui_last_details_visible = layout.show_details_button;
  g_chart_ui_layout_dirty = false;

  LogLightweightUiDiagnostics(chart_id,
                              snapshot,
                              fit_decision,
                              layout,
                              row_budget,
                              rows_hidden,
                              details_expanded,
                              rows);

  if(layout_changed)
    ChartRedraw(chart_id);
}

bool HandleLightweightChartUiEvent(const int id,
                                   const long &,
                                   const double &,
                                   const string &sparam)
{
  if(FrontendSkippingChartWork())
    return false;

  if(id == CHARTEVENT_CHART_CHANGE)
  {
    LightweightUiChartSnapshot current_snapshot;
    ResolveLightweightUiChartSnapshot(ChartID(), current_snapshot);
    LogLightweightUiEventDiagnostic("chart_change",
                                    StringFormat("prev=%dx%d next=%dx%d prev_profile=%s prev_fit_reason=%s next_dimension_profile=%s",
                                                 g_chart_ui_last_snapshot.chart_width,
                                                 g_chart_ui_last_snapshot.chart_height,
                                                 current_snapshot.chart_width,
                                                 current_snapshot.chart_height,
                                                 ResolveLightweightUiProfileLabel(g_chart_ui_last_profile),
                                                 ResolveLightweightUiFitReasonLabel(g_chart_ui_last_fit_reason),
                                                 ResolveLightweightUiProfileLabel(ResolveLightweightUiDimensionProfile(current_snapshot))));
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
    LogLightweightUiEventDiagnostic("details_click",
                                    StringFormat("details_expanded=%s",
                                                 BoolOnOff(g_chart_ui_details_expanded)));
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
  LogLightweightUiEventDiagnostic("toggle_click",
                                  StringFormat("manual_toggle=%s",
                                               BoolOnOff(ManualSignalEntryEnabled())));

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
  if(FrontendSkippingChartWork())
    return;

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

  string final_text = prefix + ClampLightweightUiText(reason_message, reason_max_chars);

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
  if(FrontendSkippingChartWork())
    return;

  ObjectDelete(ChartID(), EA_CHART_ERROR_OBJECT);
}

#endif // _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
