#ifndef _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_

const string EA_CHART_OBJECT_PREFIX = "HFT_EXEC_AI_";
const int EXECUTION_VISUAL_OBJECT_RESERVE = 32;

bool IsEAOwnedObjectName(const string name)
{
  if(StringFind(name, EA_CHART_OBJECT_PREFIX) == 0)
    return true;
  return false;
}

void DeleteEAChartObjects(const long chart_id)
{
  if(FrontendSkippingChartWork())
    return;

  int total = ObjectsTotal(chart_id, -1, -1);
  for(int i = total - 1; i >= 0; i--)
  {
    string object_name = ObjectName(chart_id, i, -1, -1);
    if(object_name == "")
      continue;
    if(!IsEAOwnedObjectName(object_name))
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
  ArrayResize(names, total + 1, EXECUTION_VISUAL_OBJECT_RESERVE);
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

string ExecutionSignalIdentifier(const SignalParams &signal_params)
{
  if(signal_params.execution_sequence_id != "")
    return signal_params.execution_sequence_id;

  string time_token = CompactTimeIdentifier(signal_params.entry_time);
  if(time_token != "")
    return time_token;

  double anchor_price = signal_params.execution_entry_reference_price;
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

  return StringFormat("EXEC_%d", signal_params.signal_type);
}

string ExecutionSignalObjectName(const SignalParams &signal_params,
                                 const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string identifier = ExecutionSignalIdentifier(signal_params);
  if(identifier == "")
    return EA_CHART_OBJECT_PREFIX + suffix + "_" + direction;

  return EA_CHART_OBJECT_PREFIX + suffix + "_" + direction + "_" + identifier;
}

string ExecutionSignalLineLabel(const SignalParams &signal_params,
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

int ResolveExecutionDisplayLevel(const int level_index)
{
  if(level_index < 0)
    return 1;
  return level_index + 1;
}

int ResolveExecutionNextDisplayLevel(const int level_index)
{
  return ResolveExecutionDisplayLevel(level_index + 1);
}

string FormatFibNextLabel(const string base_label,
                          const double next_level_percent,
                          const int level_index,
                          const double lot_size)
{
  int display_level = ResolveExecutionDisplayLevel(level_index);
  return StringFormat("%s %.1f%% L%d lot=%.2f",
                      base_label,
                      next_level_percent,
                      display_level,
                      lot_size);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_
