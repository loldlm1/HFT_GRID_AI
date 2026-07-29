#ifndef _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_

string g_execution_visual_previous_objects[];
const int EXECUTION_VISUAL_MAX_PER_DIRECTION = 8;
const color EXECUTION_VISUAL_ENTRY_COLOR = clrBlue;
const color EXECUTION_VISUAL_STOP_COLOR = clrTomato;
const color EXECUTION_VISUAL_TARGET_COLOR = clrGreen;

void ResetExecutionVisualizationCache()
{
  ArrayResize(g_execution_visual_previous_objects, 0);
}

void DrawExecutionState(const long chart_id,
                        const SignalParams &signal_params,
                        string &tracked_objects[])
{
  if(!signal_params.execution_initialized)
    return;

  double entry_price = signal_params.execution.broker_entry_confirmed
    ? signal_params.execution.broker_entry_price
    : signal_params.execution.planned_entry_price;
  double stop_loss = signal_params.execution.broker_entry_confirmed
    ? signal_params.execution.broker_stop_loss
    : signal_params.execution.stop_loss_price;
  double take_profit = signal_params.execution.broker_entry_confirmed
    ? signal_params.execution.broker_take_profit
    : signal_params.execution.take_profit_price;

  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal_params, "ENTRY"),
                    EXECUTION_VISUAL_ENTRY_COLOR,
                    entry_price,
                    tracked_objects,
                    "ENTRY");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal_params, "SL"),
                    EXECUTION_VISUAL_STOP_COLOR,
                    stop_loss,
                    tracked_objects,
                    "SL");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal_params, "TP"),
                    EXECUTION_VISUAL_TARGET_COLOR,
                    take_profit,
                    tracked_objects,
                    "TP 1R");
}

void DrawRecentExecutionStates(const long chart_id,
                               SignalParams &signals[],
                               string &tracked_objects[])
{
  int total = ArraySize(signals);
  int start = total - EXECUTION_VISUAL_MAX_PER_DIRECTION;
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
  DrawRecentExecutionStates(chart_id, running_bullish_signals, current_objects);
  DrawRecentExecutionStates(chart_id, running_bearish_signals, current_objects);

  for(int p = 0; p < ArraySize(g_execution_visual_previous_objects); p++)
  {
    if(!ContainsObjectName(current_objects,
                           g_execution_visual_previous_objects[p]))
      ObjectDelete(chart_id, g_execution_visual_previous_objects[p]);
  }
  ArrayCopy(g_execution_visual_previous_objects, current_objects);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
