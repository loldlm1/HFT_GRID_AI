#ifndef _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_

string g_execution_visual_previous_objects[];

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
                    COLOR_PROFIT_NEUTRAL,
                    entry_price,
                    tracked_objects,
                    "ENTRY");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal_params, "SL"),
                    COLOR_PROFIT_NEGATIVE,
                    stop_loss,
                    tracked_objects,
                    "SL");
  UpdateTrackedLine(chart_id,
                    ExecutionSignalObjectName(signal_params, "TP"),
                    COLOR_PROFIT_POSITIVE,
                    take_profit,
                    tracked_objects,
                    "TP 1R");
}

void RefreshExecutionVisualization()
{
  if(FrontendSkippingChartWork())
  {
    ArrayResize(g_execution_visual_previous_objects, 0);
    return;
  }

  long chart_id = ChartID();
  string current_objects[];
  if(Enable_Chart_Levels)
  {
    for(int i = 0; i < ArraySize(running_bullish_signals); i++)
      DrawExecutionState(chart_id, running_bullish_signals[i], current_objects);
    for(int j = 0; j < ArraySize(running_bearish_signals); j++)
      DrawExecutionState(chart_id, running_bearish_signals[j], current_objects);
  }

  for(int p = 0; p < ArraySize(g_execution_visual_previous_objects); p++)
  {
    if(!ContainsObjectName(current_objects,
                           g_execution_visual_previous_objects[p]))
      ObjectDelete(chart_id, g_execution_visual_previous_objects[p]);
  }
  ArrayCopy(g_execution_visual_previous_objects, current_objects);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUALIZATION_MQH_
