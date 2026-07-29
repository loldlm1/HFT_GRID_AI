#ifndef _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_

const string EA_CHART_OBJECT_PREFIX = "HFT_EXEC_AI_";
const int EXECUTION_VISUAL_OBJECT_RESERVE = 16;

bool IsEAOwnedObjectName(const string name)
{
  return (StringFind(name, EA_CHART_OBJECT_PREFIX) == 0);
}

void DeleteEAChartObjects(const long chart_id)
{
  if(FrontendSkippingChartWork())
    return;
  for(int i = ObjectsTotal(chart_id, -1, -1) - 1; i >= 0; i--)
  {
    string object_name = ObjectName(chart_id, i, -1, -1);
    if(IsEAOwnedObjectName(object_name))
      ObjectDelete(chart_id, object_name);
  }
}

bool ContainsObjectName(string &names[], const string name)
{
  for(int i = 0; i < ArraySize(names); i++)
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

string ExecutionSignalIdentifier(const SignalParams &signal_params)
{
  string identity = signal_params.extremum_attempt_id;
  if(identity == "")
    identity = signal_params.execution_sequence_id;
  if(identity == "")
    identity = IntegerToString((int)signal_params.entry_time);
  return identity;
}

string ExecutionSignalObjectName(const SignalParams &signal_params,
                                 const string suffix)
{
  string direction = (signal_params.signal_type == BULLISH) ? "B" : "S";
  return EA_CHART_OBJECT_PREFIX + suffix + "_" + direction + "_" +
         ExecutionSignalIdentifier(signal_params);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUAL_UTILS_MQH_
