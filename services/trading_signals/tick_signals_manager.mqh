
//+------------------------------------------------------------------+
//|                                      tick_signals_manager.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_

void RegisterClosedSignalOutcomeIfBrokerConfirmed(SignalParams &signal_params,
                                                  const SignalTypes direction)
{
  bool broker_outcome = SignalHasBrokerConfirmedOutcome(signal_params);
  signal_params.raw_profit = signal_params.realized_profit;

  if(!broker_outcome && signal_params.deterministic_strategy)
  {
    signal_params.raw_profit = 0.0;
    ExecutionLogDeterministicPendingCanceled(signal_params, "no_broker_outcome");
    return;
  }

  if(MathAbs(signal_params.raw_profit) < 0.0000001 &&
     signal_params.realized_closed_volume <= 0.0)
  {
    signal_params.raw_profit = RawProfitUsd(direction,
                                           signal_params.entry_price,
                                           signal_params.close_price);
  }

  RegisterDailySignalOutcome(direction, signal_params.raw_profit);
  RegisterSignalLotSequenceOutcome(signal_params.raw_profit);
  DeterministicSignalStatsRecordOutcome(signal_params);
}

void CheckTickOpenBullishSignals()
{
  int running_signals_total = ArraySize(running_bullish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    UpdateExecutionLifecycle(running_bullish_signals[i]);

    bool lifecycle_closed = (running_bullish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bullish_signals[i]))
    {
      running_bullish_signals[i].close_time  = TimeCurrent();
      running_bullish_signals[i].close_price = g_bid;
      running_bullish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bullish_signals[i],
                                                   BULLISH);
      CloseBullishSignal(running_bullish_signals[i]);
      RemoveElementFromArray(running_bullish_signals, i);
    }
  }
}

void CheckTickOpenBearishSignals()
{
  int running_signals_total = ArraySize(running_bearish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    UpdateExecutionLifecycle(running_bearish_signals[i]);

    bool lifecycle_closed = (running_bearish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsExecutionSignalComplete(running_bearish_signals[i]))
    {
      running_bearish_signals[i].close_time  = TimeCurrent();
      running_bearish_signals[i].close_price = g_ask;
      running_bearish_signals[i].signal_state = CLOSED;

      RegisterClosedSignalOutcomeIfBrokerConfirmed(running_bearish_signals[i],
                                                   BEARISH);
      CloseBearishSignal(running_bearish_signals[i]);
      RemoveElementFromArray(running_bearish_signals, i);
    }
  }
}

#endif // _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
