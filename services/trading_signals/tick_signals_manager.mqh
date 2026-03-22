
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
      running_bullish_signals[i].raw_profit  = running_bullish_signals[i].realized_profit;
      if(MathAbs(running_bullish_signals[i].raw_profit) < 0.0000001 &&
         running_bullish_signals[i].realized_closed_volume <= 0.0)
      {
        running_bullish_signals[i].raw_profit = RawProfitUsd(BULLISH,
                                                             running_bullish_signals[i].entry_price,
                                                             running_bullish_signals[i].close_price);
      }
      running_bullish_signals[i].signal_state = CLOSED;

      RegisterDailySignalOutcome(BULLISH, running_bullish_signals[i].raw_profit);
      RegisterSignalLotSequenceOutcome(running_bullish_signals[i].raw_profit);
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
      running_bearish_signals[i].raw_profit  = running_bearish_signals[i].realized_profit;
      if(MathAbs(running_bearish_signals[i].raw_profit) < 0.0000001 &&
         running_bearish_signals[i].realized_closed_volume <= 0.0)
      {
        running_bearish_signals[i].raw_profit = RawProfitUsd(BEARISH,
                                                             running_bearish_signals[i].entry_price,
                                                             running_bearish_signals[i].close_price);
      }
      running_bearish_signals[i].signal_state = CLOSED;

      RegisterDailySignalOutcome(BEARISH, running_bearish_signals[i].raw_profit);
      RegisterSignalLotSequenceOutcome(running_bearish_signals[i].raw_profit);
      CloseBearishSignal(running_bearish_signals[i]);
      RemoveElementFromArray(running_bearish_signals, i);
    }
  }
}

#endif // _SERVICES_TRADING_SIGNALS_TICK_SIGNALS_MANAGER_MQH_
