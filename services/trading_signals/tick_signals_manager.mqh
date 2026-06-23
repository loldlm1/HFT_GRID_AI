
//+------------------------------------------------------------------+
//|                                      tick_signals_manager.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_

void CheckTickOpenBullishSignals()
{
  int running_signals_total = ArraySize(running_bullish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
  {
    UpdateGridLifecycle(running_bullish_signals[i]);

    bool lifecycle_closed = (running_bullish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsGridSignalComplete(running_bullish_signals[i]))
    {
      running_bullish_signals[i].close_time  = TimeCurrent();
      running_bullish_signals[i].close_price = g_bid;
      if(IsPandoraSignal(running_bullish_signals[i]))
      {
        if(running_bullish_signals[i].pandora_local_close_time > 0)
          running_bullish_signals[i].close_time = running_bullish_signals[i].pandora_local_close_time;
        if(running_bullish_signals[i].pandora_local_close_price > 0.0)
          running_bullish_signals[i].close_price = running_bullish_signals[i].pandora_local_close_price;
      }
      double entry_price = running_bullish_signals[i].entry_price;
      if(IsPandoraSignal(running_bullish_signals[i]) &&
         running_bullish_signals[i].pandora_source_entry_price > 0.0)
        entry_price = running_bullish_signals[i].pandora_source_entry_price;
      else if(IsPandoraSignal(running_bullish_signals[i]) &&
         running_bullish_signals[i].pandora_local_entry_price > 0.0)
        entry_price = running_bullish_signals[i].pandora_local_entry_price;
      running_bullish_signals[i].raw_profit  = RawProfitUsd(BULLISH,
                                                            entry_price,
                                                            running_bullish_signals[i].close_price);
      running_bullish_signals[i].signal_state = CLOSED;

      PandoraFinalizeSignalOutcome(running_bullish_signals[i],
                                   running_bullish_signals[i].close_price,
                                   running_bullish_signals[i].raw_profit);
      PandoraXBoostRecordClosedSignal(running_bullish_signals[i], false);
      PandoraXBoostAdvanceAfterClose(running_bullish_signals[i]);
      RegisterDailySignalOutcome(BULLISH, running_bullish_signals[i].raw_profit);
      PandoraRegisterSideOutcome(running_bullish_signals[i]);
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
    UpdateGridLifecycle(running_bearish_signals[i]);

    bool lifecycle_closed = (running_bearish_signals[i].signal_state == CLOSED);
    if(lifecycle_closed || IsGridSignalComplete(running_bearish_signals[i]))
    {
      running_bearish_signals[i].close_time  = TimeCurrent();
      running_bearish_signals[i].close_price = g_ask;
      if(IsPandoraSignal(running_bearish_signals[i]))
      {
        if(running_bearish_signals[i].pandora_local_close_time > 0)
          running_bearish_signals[i].close_time = running_bearish_signals[i].pandora_local_close_time;
        if(running_bearish_signals[i].pandora_local_close_price > 0.0)
          running_bearish_signals[i].close_price = running_bearish_signals[i].pandora_local_close_price;
      }
      double entry_price = running_bearish_signals[i].entry_price;
      if(IsPandoraSignal(running_bearish_signals[i]) &&
         running_bearish_signals[i].pandora_source_entry_price > 0.0)
        entry_price = running_bearish_signals[i].pandora_source_entry_price;
      else if(IsPandoraSignal(running_bearish_signals[i]) &&
         running_bearish_signals[i].pandora_local_entry_price > 0.0)
        entry_price = running_bearish_signals[i].pandora_local_entry_price;
      running_bearish_signals[i].raw_profit  = RawProfitUsd(BEARISH,
                                                            entry_price,
                                                            running_bearish_signals[i].close_price);
      running_bearish_signals[i].signal_state = CLOSED;

      PandoraFinalizeSignalOutcome(running_bearish_signals[i],
                                   running_bearish_signals[i].close_price,
                                   running_bearish_signals[i].raw_profit);
      PandoraXBoostRecordClosedSignal(running_bearish_signals[i], false);
      PandoraXBoostAdvanceAfterClose(running_bearish_signals[i]);
      RegisterDailySignalOutcome(BEARISH, running_bearish_signals[i].raw_profit);
      PandoraRegisterSideOutcome(running_bearish_signals[i]);
      CloseBearishSignal(running_bearish_signals[i]);
      RemoveElementFromArray(running_bearish_signals, i);
    }
  }
}

#endif // _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
