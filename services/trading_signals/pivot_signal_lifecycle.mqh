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
  if(!PivotV11Enabled())
  {
    signal.execution.entry_check_exported = true;
    return true;
  }

  BrokerExecutionCheck check(signal.execution.send_result_check);
  check.phase = "OWNERSHIP";
  check.sequence = NextBrokerExecutionCheckSequence(signal);
  check.broker_time = TimeCurrent();
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
  if(!PivotV11Enabled())
  {
    signal.execution.terminal_check_exported = true;
    return true;
  }

  BrokerExecutionCheck check(signal.execution.send_result_check);
  check.phase = "TERMINAL";
  check.sequence = NextBrokerExecutionCheckSequence(signal);
  check.broker_time = TimeCurrent();
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
  if(!PivotV11Enabled())
  {
    signal.execution.outcome_exported = true;
    return true;
  }

  bool recorded = PivotV11RecordBrokerOutcome(signal);
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

void FinalizePivotSignalTerminalStates()
{
  for(int i = ArraySize(g_pivot_signals) - 1; i >= 0; i--)
  {
    if(g_pivot_signals[i].execution.state ==
       EXECUTION_ORDER_BROKER_CLOSED)
    {
      UpdatePivotOrigin(g_pivot_signals[i]);
      ExportPivotOwnershipExecutionCheckIfNeeded(g_pivot_signals[i]);
      ExportPivotTerminalExecutionCheck(g_pivot_signals[i]);
      ExportPivotSignalOutcome(g_pivot_signals[i]);
      LogPivotSignalTerminal(g_pivot_signals[i]);
      PivotSignalRemoveAt(i);
      continue;
    }
    if(g_pivot_signals[i].execution.state == EXECUTION_ORDER_CANCELED ||
       g_pivot_signals[i].execution.state == EXECUTION_ORDER_FAILED)
    {
      UpdatePivotOrigin(g_pivot_signals[i]);
      ExportPivotTerminalExecutionCheck(g_pivot_signals[i]);
      LogPivotSignalTerminal(g_pivot_signals[i]);
      PivotSignalRemoveAt(i);
    }
  }
}

void ReconcileAndFinalizePivotSignals()
{
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
    UpdatePivotOrigin(g_pivot_signals[i]);
    ExportPivotOwnershipExecutionCheckIfNeeded(g_pivot_signals[i]);
  }
  FinalizePivotSignalTerminalStates();
}

void ProcessPivotSignalLifecycle()
{
  RefreshPivotBrokerOwnershipBoundary();
  ReconcileAndFinalizePivotSignals();
}

bool PivotSignalLifecycleHasOutstandingAttempts()
{
  return ArraySize(g_pivot_signals) > 0;
}

void FinalizePivotSignalAttemptsForExport()
{
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    ExportPivotOwnershipExecutionCheckIfNeeded(g_pivot_signals[i]);
    g_pivot_signals[i].attempt_status = "CENSORED";
    g_pivot_signals[i].block_source = "";
    g_pivot_signals[i].block_reason = "";
    UpdatePivotOrigin(g_pivot_signals[i]);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_
