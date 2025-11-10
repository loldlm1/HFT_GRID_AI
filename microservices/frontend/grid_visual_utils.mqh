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
  return suffix + "_" + direction;
}

string GridSignalLineLabel(const SignalParams &signal_params,
                           const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  if(suffix == "")
    return direction;
  return direction + " " + suffix;
}

#endif // _MICROSERVICES_FRONTEND_GRID_VISUAL_UTILS_MQH_
