//+------------------------------------------------------------------+
//|                         trading_signals/pivot_signal_state      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STATE_MQH_

const int PIVOT_SIGNAL_STATE_RESERVE = 64;

PivotSignal g_pivot_signals[];
bool g_forced_stop_triggered = false;
bool g_debug_no_money_abort_pending = false;
bool g_pivot_startup_positions_block_entries = false;
datetime g_pivot_window_levels_exported_open[PIVOT_FRACTAL_TIMEFRAME_COUNT];
datetime g_pivot_window_terminal_exported_open[PIVOT_FRACTAL_TIMEFRAME_COUNT];

void ResetPivotSignalRuntimeState()
{
  ArrayResize(g_pivot_signals, 0, PIVOT_SIGNAL_STATE_RESERVE);
  g_forced_stop_triggered = false;
  g_debug_no_money_abort_pending = false;
  g_pivot_startup_positions_block_entries = false;
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    g_pivot_window_levels_exported_open[i] = 0;
    g_pivot_window_terminal_exported_open[i] = 0;
  }
}

int FindPivotSignalIndex(const string signal_id)
{
  if(signal_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
  {
    if(g_pivot_signals[i].signal_id == signal_id)
      return i;
  }
  return -1;
}

bool PivotSignalStore(const PivotSignal &signal)
{
  if(signal.signal_id == "" || FindPivotSignalIndex(signal.signal_id) >= 0)
    return false;

  int total = ArraySize(g_pivot_signals);
  int resized = ArrayResize(g_pivot_signals,
                            total + 1,
                            PIVOT_SIGNAL_STATE_RESERVE);
  if(resized != total + 1)
    return false;

  g_pivot_signals[total].CopyFrom(signal);
  return true;
}

bool PivotSignalRemoveAt(const int index)
{
  int total = ArraySize(g_pivot_signals);
  if(index < 0 || index >= total)
    return false;

  for(int i = index; i < total - 1; i++)
    g_pivot_signals[i].CopyFrom(g_pivot_signals[i + 1]);

  int reserve = total > 1 ? PIVOT_SIGNAL_STATE_RESERVE : 0;
  return ArrayResize(g_pivot_signals, total - 1, reserve) == total - 1;
}

bool PivotSignalHasBrokerExposure(const PivotSignal &signal)
{
  if(signal.execution.broker_entry_confirmed &&
     !signal.execution.broker_close_confirmed &&
     signal.execution.position_ticket > 0)
    return true;

  return (signal.execution.state == EXECUTION_ORDER_SEND_ATTEMPTED &&
          signal.execution.send_result_check.allowed);
}

bool PivotSignalHasConfirmedOutcome(const PivotSignal &signal)
{
  return signal.execution.broker_entry_confirmed &&
         signal.execution.broker_close_confirmed;
}

bool PivotSignalExecutionComplete(const PivotSignal &signal)
{
  return signal.execution.state == EXECUTION_ORDER_BROKER_CLOSED ||
         signal.execution.state == EXECUTION_ORDER_CANCELED ||
         signal.execution.state == EXECUTION_ORDER_FAILED;
}

bool DebugEquityGuardAllowsProcessing()
{
  if(!Debug_Stop_On_Negative_Equity || MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  if(g_debug_no_money_abort_pending)
  {
    g_forced_stop_triggered = true;
    g_debug_no_money_abort_pending = false;
    Print("TesterStop triggered: order send rejected due to insufficient funds while the debug equity guard is enabled.");
    TesterStop();
    return false;
  }

  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  if(equity <= 0.0)
  {
    g_forced_stop_triggered = true;
    Print("TesterStop triggered: equity <= 0 while the debug equity guard is enabled.");
    TesterStop();
    return false;
  }
  return true;
}

bool ResolvePivotSignalPermission(const SignalTypes direction,
                                  string &block_source_out,
                                  string &block_reason_out)
{
  block_source_out = "";
  block_reason_out = "";
  if(!DebugEquityGuardAllowsProcessing())
  {
    block_source_out = "debug_equity_guard";
    block_reason_out = "DEBUG_EQUITY_GUARD_STOPPED";
    return false;
  }
  if(direction != BULLISH && direction != BEARISH)
  {
    block_source_out = "direction";
    block_reason_out = "INVALID_DIRECTION";
    return false;
  }
  if(g_pivot_startup_positions_block_entries)
  {
    block_source_out = "startup_ownership";
    block_reason_out = "PREEXISTING_PIVOT_POSITION_UNMANAGED";
    return false;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STATE_MQH_
