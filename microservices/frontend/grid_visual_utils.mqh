#ifndef _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_
#define _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_

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
  if(!signal_params.pandora_xboost_enabled)
    return suffix + "_" + direction;

  string identity_source = signal_params.pandora_xboost_node_path;
  if(identity_source == "")
    identity_source = signal_params.pandora_xboost_node_key;
  if(identity_source == "")
    identity_source = signal_params.pandora_xboost_display_id;
  if(identity_source == "")
    identity_source = GridSignalIdentifier(signal_params);

  int depth = signal_params.pandora_xboost_depth;
  if(depth < 1)
    depth = 1;

  long identity_hash = (long)(PandoraXBoostHashKey(identity_source) % 100000000);
  string xboost_token = StringFormat("%s_XB_D%d_%I64d",
                                     direction,
                                     depth,
                                     identity_hash);
  return suffix + "_" + xboost_token;
}

string GridSignalLineLabel(const SignalParams &signal_params,
                           const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string label_prefix = direction;
  if(signal_params.pandora_xboost_enabled)
  {
    int depth = signal_params.pandora_xboost_depth;
    if(depth < 1)
      depth = 1;

    string execution_label = "WATCH";
    if(signal_params.pandora_xboost_broker_selected)
      execution_label = "BROKER";
    else if(signal_params.pandora_xboost_local_only)
      execution_label = "LOCAL";

    string display_id = signal_params.pandora_xboost_display_id;
    if(display_id == "")
      display_id = "XB";

    label_prefix = StringFormat("%s XB d%d %s %s",
                                direction,
                                depth,
                                display_id,
                                execution_label);
  }

  string resolved_suffix = suffix;
  if(signal_params.pandora_xboost_enabled &&
     suffix == "TP TRAILING" &&
     signal_params.pandora_trailing_step_index > 0)
  {
    resolved_suffix = suffix + " step=" +
                      IntegerToString(signal_params.pandora_trailing_step_index);
  }

  if(resolved_suffix == "")
    return label_prefix;
  return label_prefix + " " + resolved_suffix;
}

#endif // _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_
