#ifndef _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_
#define _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_

const string EA_CHART_OBJECT_PREFIX = "HFT_GRID_AI_";
const string EA_CHART_UI_PANEL = "HFT_GRID_AI_UI_PANEL";
const string EA_CHART_UI_STATUS = "HFT_GRID_AI_UI_STATUS";
const string EA_CHART_UI_TOGGLE = "HFT_GRID_AI_UI_TOGGLE";
const string EA_CHART_UI_ROW_PREFIX = "HFT_GRID_AI_UI_ROW_";
const string EA_CHART_ERROR_OBJECT = "HFT_GRID_AI_ERROR_MESSAGE";
string EA_CHART_LEGACY_GRID_OBJECTS[] =
{
  "STOP_BULLISH",
  "TP_BULLISH",
  "ENTRY_BULLISH",
  "NEXT_BULLISH",
  "STOP_BEARISH",
  "TP_BEARISH",
  "ENTRY_BEARISH",
  "NEXT_BEARISH"
};

bool IsLegacyGridObjectName(const string name)
{
  int total = ArraySize(EA_CHART_LEGACY_GRID_OBJECTS);
  for(int i = 0; i < total; i++)
  {
    if(EA_CHART_LEGACY_GRID_OBJECTS[i] == name)
      return true;
  }
  return false;
}

bool IsEAOwnedObjectName(const string name)
{
  if(StringFind(name, EA_CHART_OBJECT_PREFIX) == 0)
    return true;
  return IsLegacyGridObjectName(name);
}

void DeleteEAChartObjects(const long chart_id,
                          const bool preserve_error_object = false)
{
  int total = ObjectsTotal(chart_id, -1, -1);
  for(int i = total - 1; i >= 0; i--)
  {
    string object_name = ObjectName(chart_id, i, -1, -1);
    if(object_name == "")
      continue;
    if(!IsEAOwnedObjectName(object_name))
      continue;
    if(preserve_error_object && object_name == EA_CHART_ERROR_OBJECT)
      continue;
    ObjectDelete(chart_id, object_name);
  }
}

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

  double anchor_price = signal_params.grid_entry_reference_price;
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
  return EA_CHART_OBJECT_PREFIX + suffix + "_" + direction;
}

string GridSignalLineLabel(const SignalParams &signal_params,
                           const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  if(suffix == "")
    return direction;
  return direction + " " + suffix;
}

string FormatFibEntryLabel(const string base_label,
                           const double entry_level_percent,
                           const bool include_actual,
                           const double actual_percent)
{
  if(include_actual)
    return StringFormat("%s %.1f%% (%.2f%%)",
                        base_label,
                        entry_level_percent,
                        actual_percent);

  return StringFormat("%s %.1f%%",
                      base_label,
                      entry_level_percent);
}

int ResolveGridDisplayLevel(const int level_index)
{
  if(level_index < 0)
    return 1;
  return level_index + 1;
}

int ResolveGridNextDisplayLevel(const int level_index)
{
  return ResolveGridDisplayLevel(level_index + 1);
}

string FormatFibNextLabel(const string base_label,
                          const double next_level_percent,
                          const int level_index,
                          const double lot_size)
{
  int display_level = ResolveGridDisplayLevel(level_index);
  return StringFormat("%s %.1f%% L%d lot=%.2f",
                      base_label,
                      next_level_percent,
                      display_level,
                      lot_size);
}

#endif // _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_
