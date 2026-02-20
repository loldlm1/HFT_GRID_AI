#ifndef _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_
#define _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_UI_MQH_

string g_chart_ui_last_status_text = "";
string g_chart_ui_last_button_text = "";

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

void DeleteLightweightUiObjects(const long chart_id)
{
  ObjectDelete(chart_id, EA_CHART_UI_PANEL);
  ObjectDelete(chart_id, EA_CHART_UI_STATUS);
  ObjectDelete(chart_id, EA_CHART_UI_TOGGLE);
}

void ResetLightweightUiCache()
{
  g_chart_ui_last_status_text = "";
  g_chart_ui_last_button_text = "";
}

void EnsureLightweightUiObjects(const long chart_id,
                                const int panel_height)
{
  if(ObjectFind(chart_id, EA_CHART_UI_PANEL) < 0)
  {
    ObjectCreate(chart_id, EA_CHART_UI_PANEL, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XDISTANCE, 8);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YDISTANCE, 24);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_XSIZE, 440);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BGCOLOR, clrWhiteSmoke);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_COLOR, clrDimGray);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_HIDDEN, false);
    ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_BACK, false);
  }
  ObjectSetInteger(chart_id, EA_CHART_UI_PANEL, OBJPROP_YSIZE, panel_height);

  if(ObjectFind(chart_id, EA_CHART_UI_STATUS) < 0)
  {
    ObjectCreate(chart_id, EA_CHART_UI_STATUS, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_XDISTANCE, 16);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_YDISTANCE, 54);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, EA_CHART_UI_STATUS, OBJPROP_HIDDEN, false);
    ObjectSetString(chart_id, EA_CHART_UI_STATUS, OBJPROP_FONT, "Consolas");
  }

  if(ObjectFind(chart_id, EA_CHART_UI_TOGGLE) < 0)
  {
    ObjectCreate(chart_id, EA_CHART_UI_TOGGLE, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XDISTANCE, 16);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_XSIZE, 210);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_YSIZE, 20);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BGCOLOR, clrForestGreen);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_BORDER_COLOR, clrDimGray);
    ObjectSetInteger(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_STATE, false);
    ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_FONT, "Consolas");
  }
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
  if(summary_limit > 4)
    summary_limit = 4;

  int panel_height = 180 + summary_limit * 16;
  EnsureLightweightUiObjects(chart_id, panel_height);

  string status_text = StringFormat("Magic: %d\n"
                                    "Fibonacci EA State: %s\n"
                                    "Algo Trading: %s\n"
                                    "Manual Toggle: %s\n"
                                    "Signal Gate: %s\n"
                                    "Market: %s\n"
                                    "Requested Addons: %s\n"
                                    "Granted Addons: %s\n"
                                    "Missing Addons: %s",
                                    magic_number,
                                    BoolOnOff(fib_ea_enabled && ea_running),
                                    BoolOnOff(algo_enabled),
                                    BoolOnOff(manual_enabled),
                                    signal_gate_enabled ? "ENABLED" : "DISABLED",
                                    market_status,
                                    requested_labels,
                                    granted_labels,
                                    missing_labels);

  if(effective_source != "" || effective_reason != "")
  {
    status_text += "\nBlock Source: " + effective_source;
    if(effective_reason != "")
      status_text += "\nBlock Reason: " + effective_reason;
  }

  if(Enable_Chart_Summary && summary_limit > 0)
  {
    status_text += "\nSignals:";
    for(int i = 0; i < summary_limit; i++)
      status_text += "\n - " + summary_lines[i];
  }

  string button_text = ResolveFibEaButtonText();

  if(status_text != g_chart_ui_last_status_text)
  {
    ObjectSetString(chart_id, EA_CHART_UI_STATUS, OBJPROP_TEXT, status_text);
    g_chart_ui_last_status_text = status_text;
  }

  if(button_text != g_chart_ui_last_button_text)
  {
    ObjectSetString(chart_id, EA_CHART_UI_TOGGLE, OBJPROP_TEXT, button_text);
    g_chart_ui_last_button_text = button_text;
  }

  color button_bg = (fib_ea_enabled ? clrForestGreen : clrIndianRed);
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
