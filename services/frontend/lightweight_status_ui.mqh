#ifndef _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
#define _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_

const int LIGHTWEIGHT_UI_PANEL_X = 8;
const int LIGHTWEIGHT_UI_PANEL_Y = 24;
const int LIGHTWEIGHT_UI_PANEL_PADDING_X = 10;
const int LIGHTWEIGHT_UI_PANEL_PADDING_Y = 6;
const int LIGHTWEIGHT_UI_PANEL_MIN_WIDTH = 260;
const int LIGHTWEIGHT_UI_PANEL_MAX_WIDTH = 520;
const int LIGHTWEIGHT_UI_PANEL_FILL_ALPHA = 36;
const int LIGHTWEIGHT_UI_BUTTON_H = 20;
const int LIGHTWEIGHT_UI_BUTTON_TOP_OFFSET = 6;
const int LIGHTWEIGHT_UI_FIRST_ROW_Y = 56;
const int LIGHTWEIGHT_UI_ROW_STEP = 14;
const int LIGHTWEIGHT_UI_MAX_ROWS = 18;
const int LIGHTWEIGHT_UI_MAX_VALUE_CHARS = 52;
const int LIGHTWEIGHT_UI_CHAR_WIDTH_EST = 7;

string g_chart_ui_last_button_text = "";
string g_chart_ui_last_rows[];

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

void DeleteLightweightUiRows(const long chart_id)
{
  for(int i = 0; i < LIGHTWEIGHT_UI_MAX_ROWS; i++)
    ObjectDelete(chart_id, LightweightUiRowObjectName(i));
}

void DeleteLightweightUiObjects(const long chart_id)
{
  ObjectDelete(chart_id, EA_CHART_UI_PANEL);
  ObjectDelete(chart_id, EA_CHART_UI_TOGGLE);
  DeleteLightweightUiRows(chart_id);
}

void ResetLightweightUiCache()
{
  g_chart_ui_last_button_text = "";
  ArrayResize(g_chart_ui_last_rows, 0);
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

int ResolveUiPanelMaxWidth(const long chart_id)
{
  long chart_width = 0;
  if(!ChartGetInteger(chart_id, CHART_WIDTH_IN_PIXELS, 0, chart_width))
    return LIGHTWEIGHT_UI_PANEL_MAX_WIDTH;

  int max_width = (int)chart_width - LIGHTWEIGHT_UI_PANEL_X * 2;
  if(max_width < LIGHTWEIGHT_UI_PANEL_MIN_WIDTH)
    return LIGHTWEIGHT_UI_PANEL_MIN_WIDTH;
  if(max_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH)
    return LIGHTWEIGHT_UI_PANEL_MAX_WIDTH;
  return max_width;
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

void EnsureLightweightUiRowObject(const long chart_id,
                                  const string object_name,
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
    ObjectSetString(chart_id, object_name, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(chart_id, object_name, OBJPROP_FONTSIZE, 9);
  }

  ObjectSetInteger(chart_id, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id,
                   object_name,
                   OBJPROP_XDISTANCE,
                   LIGHTWEIGHT_UI_PANEL_X + LIGHTWEIGHT_UI_PANEL_PADDING_X);
  ObjectSetInteger(chart_id, object_name, OBJPROP_YDISTANCE, row_y);
  ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, text_color);
}

int EstimateUiRowWidth(const string row_value)
{
  int row_chars = StringLen(row_value);
  if(row_chars < 0)
    row_chars = 0;

  return LIGHTWEIGHT_UI_PANEL_PADDING_X * 2 + row_chars * LIGHTWEIGHT_UI_CHAR_WIDTH_EST;
}

void EnsureLightweightUiObjects(const long chart_id,
                                const int panel_width,
                                const int panel_height,
                                const color border_color,
                                const color panel_fill,
                                const color button_text_color)
{
  if(ObjectFind(chart_id, EA_CHART_UI_PANEL) < 0)
    ObjectCreate(chart_id, EA_CHART_UI_PANEL, OBJ_RECTANGLE_LABEL, 0, 0, 0);

  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XDISTANCE, LIGHTWEIGHT_UI_PANEL_X);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YDISTANCE, LIGHTWEIGHT_UI_PANEL_Y);
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XSIZE, panel_width);
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

  int button_x = LIGHTWEIGHT_UI_PANEL_X + LIGHTWEIGHT_UI_PANEL_PADDING_X;
  int button_w = panel_width - LIGHTWEIGHT_UI_PANEL_PADDING_X * 2;
  if(button_w < 120)
    button_w = 120;

  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XDISTANCE, button_x);
  ObjectSetInteger(chart_id,
                   EA_CHART_UI_TOGGLE,
                   OBJPROP_YDISTANCE,
                   LIGHTWEIGHT_UI_PANEL_Y + LIGHTWEIGHT_UI_BUTTON_TOP_OFFSET);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XSIZE, button_w);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YSIZE, LIGHTWEIGHT_UI_BUTTON_H);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_COLOR, button_text_color);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BORDER_COLOR, border_color);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_STATE, false);
  ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_FONT, "Consolas");
}

void AddLightweightUiRow(string &rows[],
                         const string label,
                         const string value)
{
  int total = ArraySize(rows);
  if(total >= LIGHTWEIGHT_UI_MAX_ROWS)
    return;

  string safe_value = ClampUiValue(value, LIGHTWEIGHT_UI_MAX_VALUE_CHARS);
  ArrayResize(rows, total + 1);
  rows[total] = label + ": " + safe_value;
}

void CollectAddonUiState(string &requested_addons[],
                         string &granted_addons[],
                         string &missing_addons[])
{
  bool require_any_compound_family = false;
  AddonPolicyCollectRequestedAddons(requested_addons, require_any_compound_family);

  if(require_any_compound_family)
    AddonPolicyAppendUnique(requested_addons, ADDON_KEY_COMPOUND_ANY_FAMILY);

  LicenseCopyGrantedAddons(granted_addons);
  AddonPolicyResolveMissingAddons(requested_addons,
                                  require_any_compound_family,
                                  missing_addons);
}

string ResolveRuntimeTickBlockSource()
{
  if(g_points_spread > Max_Spread)
    return "spread_guard";

  if(!IsMarketOpen())
    return "market_hours";

  return "";
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

  int summary_total = ArraySize(summary_lines);
  int summary_limit = summary_total;
  if(summary_limit > 3)
    summary_limit = 3;

  string rows[];
  AddLightweightUiRow(rows, "Magic", IntegerToString(magic_number));
  AddLightweightUiRow(rows, "Fibonacci EA", BoolOnOff(fib_ea_enabled && ea_running));
  AddLightweightUiRow(rows, "Algo Trading", BoolOnOff(algo_enabled));
  AddLightweightUiRow(rows, "Manual Toggle", BoolOnOff(manual_enabled));
  AddLightweightUiRow(rows, "Signal Gate", (signal_gate_enabled ? "ENABLED" : "DISABLED"));
  AddLightweightUiRow(rows, "Market", market_status);
  AddLightweightUiRow(rows, "Requested (Inputs)", requested_labels);
  AddLightweightUiRow(rows, "Purchased Addons", granted_labels);
  AddLightweightUiRow(rows, "Missing Required", missing_labels);

  if(effective_source != "")
    AddLightweightUiRow(rows, "Block Source", effective_source);
  if(effective_reason != "")
    AddLightweightUiRow(rows, "Block Reason", effective_reason);

  if(Enable_Chart_Summary && summary_limit > 0)
  {
    AddLightweightUiRow(rows, "Signals", IntegerToString(summary_limit) + " row(s)");
    for(int i = 0; i < summary_limit; i++)
      AddLightweightUiRow(rows, StringFormat("S%d", i + 1), summary_lines[i]);
  }

  int rows_total = ArraySize(rows);
  if(rows_total <= 0)
  {
    AddLightweightUiRow(rows, "Status", "No data");
    rows_total = ArraySize(rows);
  }

  int panel_width_cap = ResolveUiPanelMaxWidth(chart_id);

  int panel_width = LIGHTWEIGHT_UI_PANEL_MIN_WIDTH;
  for(int i = 0; i < rows_total; i++)
  {
    int row_width = EstimateUiRowWidth(rows[i]);
    if(row_width > panel_width)
      panel_width = row_width;
  }
  if(panel_width > panel_width_cap)
    panel_width = panel_width_cap;

  color text_color = ResolveUiTextColor(chart_id);
  color border_color = ResolveUiBorderColor(chart_id);
  color panel_fill = ResolveUiPanelFillColor(chart_id);
  color button_text = ResolveUiButtonTextColor(chart_id);

  int panel_height = LIGHTWEIGHT_UI_FIRST_ROW_Y + rows_total * LIGHTWEIGHT_UI_ROW_STEP + LIGHTWEIGHT_UI_PANEL_PADDING_Y;
  EnsureLightweightUiObjects(chart_id,
                             panel_width,
                             panel_height,
                             border_color,
                             panel_fill,
                             button_text);

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
    int row_y = LIGHTWEIGHT_UI_FIRST_ROW_Y + i * LIGHTWEIGHT_UI_ROW_STEP;

    EnsureLightweightUiRowObject(chart_id, row_name, row_y, text_color);
    if(g_chart_ui_last_rows[i] != rows[i])
    {
      ObjectSetString(chart_id, row_name, OBJPROP_TEXT, rows[i]);
      g_chart_ui_last_rows[i] = rows[i];
    }
  }

  if(cached_total > rows_total)
  {
    for(int i = rows_total; i < cached_total; i++)
      ObjectDelete(chart_id, LightweightUiRowObjectName(i));
  }
  ArrayResize(g_chart_ui_last_rows, rows_total);

  string button_text_value = ResolveFibEaButtonText();
  if(button_text_value != g_chart_ui_last_button_text)
  {
    ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_TEXT, button_text_value);
    g_chart_ui_last_button_text = button_text_value;
  }

  color button_bg = ResolveUiButtonBackground(chart_id, fib_ea_enabled);
  ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BGCOLOR, button_bg);
}

void HandleLightweightChartUiEvent(const int id,
                                   const long &,
                                   const double &,
                                   const string &sparam)
{
  if(!Enable_Chart_Lightweight_UI)
    return;

  if(id != CHARTEVENT_OBJECT_CLICK)
    return;

  if(sparam != EA_CHART_UI_TOGGLE)
    return;

  if(!TerminalAlgoTradingEnabled())
  {
    Print("[UI] Cannot enable FIBONACCI EA while MT5 Algo Trading is OFF.");
    return;
  }

  SetManualSignalEntryEnabled(!ManualSignalEntryEnabled());
  PrintFormat("[UI] Manual signal toggle set to %s.",
              (ManualSignalEntryEnabled() ? "ON" : "OFF"));

  ResetLightweightUiCache();
  ChartRedraw();
}

void RenderPersistentChartError(const string error_message)
{
  long chart_id = ChartID();
  string safe_message = error_message;
  if(safe_message == "")
    safe_message = "HFT Grid AI removed: unknown error.";

  ObjectDelete(chart_id, EA_CHART_ERROR_OBJECT);
  ObjectCreate(chart_id, EA_CHART_ERROR_OBJECT, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_XDISTANCE, 12);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_YDISTANCE, 24);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_COLOR, clrTomato);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_FONTSIZE, 10);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, EA_CHART_ERROR_OBJECT, OBJPROP_HIDDEN, false);
  ObjectSetString(chart_id,
                  EA_CHART_ERROR_OBJECT,
                  OBJPROP_FONT,
                  "Consolas");
  ObjectSetString(chart_id,
                  EA_CHART_ERROR_OBJECT,
                  OBJPROP_TEXT,
                  "FIBONACCI EA REMOVED\n" + safe_message);
}

void ClearPersistentChartError()
{
  ObjectDelete(ChartID(), EA_CHART_ERROR_OBJECT);
}

#endif // _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
