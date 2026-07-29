//+------------------------------------------------------------------+
//|                                      tick_signals_manager.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_

void ReconcileRunningSignalsAfterTradeTransaction()
{
  for(int i = 0; i < ArraySize(running_bullish_signals); i++)
    ReconcileSignalBrokerPosition(running_bullish_signals[i]);
  for(int j = 0; j < ArraySize(running_bearish_signals); j++)
    ReconcileSignalBrokerPosition(running_bearish_signals[j]);
}

void RegisterFinishedSignal(SignalParams &signal_params)
{
  if(SignalHasBrokerConfirmedOutcome(signal_params))
  {
    signal_params.raw_profit = signal_params.execution.realized_profit;
    if(!signal_params.deterministic_stats_feature_exported)
      DeterministicSignalStatsRecordFeature(signal_params, signal_params.execution);
    if(signal_params.execution.terminal_reason == "broker_tp")
    {
      int source_attempt_count = 0;
      if(RegisterDeterministicSourceConsumedTp(signal_params,
                                               source_attempt_count))
      {
        ExecutionLogDeterministicSourceConsumed(signal_params,
                                                signal_params.execution,
                                                source_attempt_count,
                                                "TP");
      }
    }
    DeterministicSignalStatsRecordOutcome(signal_params);
    DeterministicSignalMLShadowRecordOutcome(signal_params);
    return;
  }

  signal_params.raw_profit = 0.0;
  DeterministicSignalStatsRecordDecisionCheck(signal_params,
                                              "LIFECYCLE_CANCELED",
                                              false,
                                              signal_params.admission_block_source,
                                              signal_params.execution.terminal_reason);
  ExecutionLogDeterministicPendingCanceled(signal_params,
                                           signal_params.execution.terminal_reason);
}

void CheckRunningSignalArray(SignalParams &signals[],
                             const bool bullish)
{
  for(int i = ArraySize(signals) - 1; i >= 0; i--)
  {
    UpdateExecutionLifecycle(signals[i]);
    if(!IsExecutionSignalComplete(signals[i]))
      continue;

    if(!signals[i].broker_close_confirmed)
    {
      signals[i].close_time = TimeCurrent();
      signals[i].close_price = bullish ? g_bid : g_ask;
      signals[i].signal_state = CLOSED;
    }
    RegisterFinishedSignal(signals[i]);
    signals[i].signal_state = CLOSED;
    RemoveElementFromArray(signals, i);
  }
}

void CheckTickOpenSignals()
{
  CheckRunningSignalArray(running_bullish_signals, true);
  CheckRunningSignalArray(running_bearish_signals, false);
}

#endif // _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
