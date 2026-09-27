//+------------------------------------------------------------------+
//|                 trading_signals/pivot_signal_lifecycle         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_

void InitializePivotBrokerOwnershipBoundary()
{
  int existing_positions = CountOwnedPivotPositions();
  g_pivot_startup_positions_block_entries = existing_positions > 0;
  if(!g_pivot_startup_positions_block_entries)
    return;

  string message = StringFormat("preexisting_positions=%d|action=entry_blocked_until_flat",
                                existing_positions);
  ExecutionAppendQueryDebugLog("PIVOT_STARTUP_OWNERSHIP", message);
  if(Enable_Logs)
    Print("PIVOT_STARTUP_OWNERSHIP | ", message);
}

void RefreshPivotBrokerOwnershipBoundary()
{
  if(!g_pivot_startup_positions_block_entries)
    return;
  int existing_positions = CountOwnedPivotPositions();
  if(existing_positions > 0)
    return;

  g_pivot_startup_positions_block_entries = false;
  ExecutionAppendQueryDebugLog("PIVOT_STARTUP_OWNERSHIP",
                              "preexisting_positions=0|action=entry_block_released");
  if(Enable_Logs)
    Print("PIVOT_STARTUP_OWNERSHIP | preexisting_positions=0|action=entry_block_released");
}

bool ExportPivotOwnershipExecutionCheckIfNeeded(PivotSignal &signal)
{
  if(!signal.execution.broker_entry_confirmed ||
     signal.execution.entry_check_exported)
    return true;
  if(!Enable_Signal_Feature_Export)
  {
    signal.execution.entry_check_exported = true;
    return true;
  }

  BrokerExecutionCheck check(signal.execution.send_result_check);
  check.phase = "OWNERSHIP";
  check.sequence = NextBrokerExecutionCheckSequence(signal);
  check.broker_time = TimeCurrent();
  check.broker_time_msc = g_model_last_time;
  check.allowed = true;
  check.block_source = "";
  check.block_reason = "";
  return ExportPivotExecutionCheck(signal, check);
}

bool ExportPivotTerminalExecutionCheck(PivotSignal &signal)
{
  if(signal.execution.terminal_check_exported)
    return true;
  bool broker_closed = signal.execution.broker_close_confirmed;
  bool order_terminal = signal.execution.state == EXECUTION_ORDER_CANCELED ||
                        signal.execution.state == EXECUTION_ORDER_FAILED;
  if(!broker_closed && !order_terminal)
    return false;
  if(!Enable_Signal_Feature_Export)
  {
    signal.execution.terminal_check_exported = true;
    return true;
  }

  BrokerExecutionCheck check(signal.execution.send_result_check);
  check.phase = "TERMINAL";
  check.sequence = NextBrokerExecutionCheckSequence(signal);
  check.broker_time = TimeCurrent();
  check.broker_time_msc = g_model_last_time;
  check.allowed = false;
  check.block_source = broker_closed
                       ? "broker_close"
                       : (signal.block_source == ""
                          ? "broker_order"
                          : signal.block_source);
  check.block_reason = signal.execution.terminal_reason;
  bool recorded = ExportPivotExecutionCheck(signal, check);
  if(recorded)
    signal.execution.terminal_check_exported = true;
  return recorded;
}

bool ExportPivotSignalOutcome(PivotSignal &signal)
{
  if(signal.execution.outcome_exported)
    return true;
  if(!Enable_Signal_Feature_Export)
  {
    signal.execution.outcome_exported = true;
    return true;
  }

  bool recorded = PivotDatasetRecordBrokerOutcome(signal);
  if(recorded)
    signal.execution.outcome_exported = true;
  return recorded;
}

void LogPivotSignalTerminal(const PivotSignal &signal)
{
  string message = StringFormat("broker_signal_id=%s|state=%s|entry_confirmed=%s|close_confirmed=%s|reason=%s|position=%I64u|identifier=%I64u|gross=%.10f|net=%.10f|binary=%s",
                                signal.broker_signal_id,
                                EnumToString(signal.execution.state),
                                signal.execution.broker_entry_confirmed
                                ? "true"
                                : "false",
                                signal.execution.broker_close_confirmed
                                ? "true"
                                : "false",
                                signal.execution.terminal_reason,
                                signal.execution.position_ticket,
                                signal.execution.position_identifier,
                                signal.execution.gross_profit,
                                signal.execution.net_profit,
                                signal.execution.binary_eligible
                                ? IntegerToString(
                                    signal.execution.binary_target)
                                : "excluded");
  datetime event_time = signal.execution.broker_close_confirmed
                        ? signal.execution.close_time
                        : signal.execution.last_action_time;
  ExecutionAppendQueryDebugLogAt(event_time,
                                 "PIVOT_TERMINAL",
                                 message);
  if(Enable_Logs)
    Print("PIVOT_TERMINAL | ", message);
}

// Research-only delivery queue. Removing a closed execution record never waits
// for a quote clock to catch up with a delayed broker deal.
PivotSignal g_pivot_deferred_closes[];

bool DeliverPivotClosedSignal(PivotSignal &signal)
{
  ExportPivotOwnershipExecutionCheckIfNeeded(signal);
  ExportPivotTerminalExecutionCheck(signal);
  return FinalizeBrokerParityAtBrokerTerminal(signal) && ExportPivotSignalOutcome(signal);
}

void FlushPivotDeferredCloses()
{
  if(!ModelReady()) return;
  for(int i = ArraySize(g_pivot_deferred_closes) - 1; i >= 0; i--)
  {
    if(g_model_last_time < g_pivot_deferred_closes[i].execution.close_time_msc) continue;
    if(!DeliverPivotClosedSignal(g_pivot_deferred_closes[i]))
    {
      PivotDatasetFail("DEFERRED_CLOSE_DELIVERY_FAILED");
      return;
    }
    int last = ArraySize(g_pivot_deferred_closes) - 1;
    if(i != last) g_pivot_deferred_closes[i].CopyFrom(g_pivot_deferred_closes[last]);
    if(ArrayResize(g_pivot_deferred_closes, last) != last)
    {
      PivotDatasetFail("DEFERRED_CLOSE_REMOVE_FAILED");
      return;
    }
  }
}

void FinalizePivotSignalTerminalStates()
{
  for(int i = ArraySize(g_pivot_signals) - 1; i >= 0; i--)
  {
    if(g_pivot_signals[i].execution.state ==
       EXECUTION_ORDER_BROKER_CLOSED)
    {
      if(!g_pivot_signals[i].execution.broker_close_confirmed ||
         g_pivot_signals[i].execution.close_time <= 0)
        continue;
      if(ModelReady())
      {
        UpdatePivotOrigin(g_pivot_signals[i]);
        bool delivered = false;
        if(g_model_last_time < g_pivot_signals[i].execution.close_time_msc)
        {
          int count = ArraySize(g_pivot_deferred_closes);
          if(count < 2048 && ArrayResize(g_pivot_deferred_closes, count + 1, 16) == count + 1)
          {
            g_pivot_deferred_closes[count].CopyFrom(g_pivot_signals[i]);
            delivered = true;
          }
        }
        else delivered = DeliverPivotClosedSignal(g_pivot_signals[i]);
        if(!delivered)
          PivotDatasetFail("CLOSED_BROKER_RESEARCH_DELIVERY_FAILED", "", 0,
                            g_pivot_signals[i].broker_signal_id);
      }
      LogPivotSignalTerminal(g_pivot_signals[i]);
      if(!PivotSignalRemoveAt(i))
        PivotDatasetFail("CLOSED_BROKER_STATE_REMOVE_FAILED", "", GetLastError());
      continue;
    }
    if(g_pivot_signals[i].execution.state == EXECUTION_ORDER_CANCELED ||
       g_pivot_signals[i].execution.state == EXECUTION_ORDER_FAILED)
    {
      if(ModelReady())
      {
        UpdatePivotOrigin(g_pivot_signals[i]);
        ExportPivotTerminalExecutionCheck(g_pivot_signals[i]);
        if(g_pivot_signals[i].execution.send_result_check.allowed && !g_pivot_signals[i].execution.outcome_exported)
          ExportPivotSignalOutcome(g_pivot_signals[i]);
      }
      LogPivotSignalTerminal(g_pivot_signals[i]);
      PivotSignalRemoveAt(i);
    }
  }
}

void ReconcileAndFinalizePivotSignals()
{
  FlushPivotDeferredCloses();
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
    UpdatePivotOrigin(g_pivot_signals[i]);
    ExportPivotOwnershipExecutionCheckIfNeeded(g_pivot_signals[i]);
  }
  FinalizePivotSignalTerminalStates();
}

void ProcessPivotSignalLifecycle(const MqlTick &tick)
{
  RefreshPivotBrokerOwnershipBoundary();
  ReconcileAndFinalizePivotSignals();
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
    RequestPivotBrokerExpiry(g_pivot_signals[i], tick);
  FinalizePivotSignalTerminalStates();
}

void FinalizePivotSignalAttemptsForExport()
{
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    ExportPivotOwnershipExecutionCheckIfNeeded(g_pivot_signals[i]);
    if(g_pivot_signals[i].execution.send_result_check.allowed && !g_pivot_signals[i].execution.outcome_exported)
    {
      if(PivotDatasetRecordBrokerOutcome(g_pivot_signals[i], true)) g_pivot_signals[i].execution.outcome_exported = true;
    }
    g_pivot_signals[i].attempt_status = "CENSORED";
    g_pivot_signals[i].block_source = "";
    g_pivot_signals[i].block_reason = "";
    UpdatePivotOrigin(g_pivot_signals[i]);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_
