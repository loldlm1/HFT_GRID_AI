#ifndef _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_

string g_execution_visual_previous_objects[];
const int EXECUTION_VISUAL_MAX_SIGNALS = 16;
const color EXECUTION_VISUAL_ENTRY_COLOR = clrBlue;
const color EXECUTION_VISUAL_STOP_COLOR = clrTomato;
const color EXECUTION_VISUAL_TARGET_COLOR = clrGreen;

void ResetExecutionVisualizationCache()
{
  ArrayResize(g_execution_visual_previous_objects, 0);
}

void DrawExecutionState(const long chart_id,
                        const PivotSignal &signal,
                        string &tracked_objects[])
{
  if(signal.signal_id == "" ||
     !signal.execution.broker_entry_confirmed ||
     signal.execution.broker_close_confirmed ||
     signal.execution.state != EXECUTION_ORDER_BROKER_ACTIVE)
    return;

  double entry_price = signal.route.intended_entry_price;
  double stop_loss = signal.execution.broker_stop_loss;
  double take_profit = signal.execution.broker_take_profit;
  string identity_label = EnumToString(signal.pivot_timeframe) + " " +
                          PivotLevelLabel(signal.level_id) + " " +
                          (signal.direction == BULLISH ? "BUY" : "SELL");

  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal, "ENTRY"),
                    EXECUTION_VISUAL_ENTRY_COLOR,
                    entry_price,
                    tracked_objects,
                    identity_label + " ENTRY");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal, "SL"),
                    EXECUTION_VISUAL_STOP_COLOR,
                    stop_loss,
                    tracked_objects,
                    identity_label + " SL");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal, "TP"),
                    EXECUTION_VISUAL_TARGET_COLOR,
                    take_profit,
                    tracked_objects,
                    identity_label + " TP");
}

void DrawRecentExecutionStates(const long chart_id,
                               PivotSignal &signals[],
                               string &tracked_objects[])
{
  int total = ArraySize(signals);
  int start = total - EXECUTION_VISUAL_MAX_SIGNALS;
  if(start < 0)
    start = 0;

  for(int i = start; i < total; i++)
    DrawExecutionState(chart_id, signals[i], tracked_objects);
}

void RefreshExecutionVisualization()
{
  if(!FrontendChartWorkEnabled())
  {
    ArrayResize(g_execution_visual_previous_objects, 0);
    return;
  }

  long chart_id = ChartID();
  string current_objects[];
  DrawRecentExecutionStates(chart_id, g_pivot_signals, current_objects);

  for(int p = 0; p < ArraySize(g_execution_visual_previous_objects); p++)
  {
    if(!ContainsObjectName(current_objects,
                           g_execution_visual_previous_objects[p]))
      ObjectDelete(chart_id, g_execution_visual_previous_objects[p]);
  }
  ArrayCopy(g_execution_visual_previous_objects, current_objects);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
