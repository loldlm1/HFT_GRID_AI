
//+------------------------------------------------------------------+
//|                                      tick_signals_manager.mqh    |
//+------------------------------------------------------------------+

void CheckTickOpenBullishSignals()
{
  int running_signals_total = ArraySize(running_bullish_signals);

  for(int i = running_signals_total-1; i >= 0; i--)
	{
		SignalStates signal_state  	   = running_bullish_signals[i].signal_state;
		datetime 	   candle_time_0  	 = iTime(_Symbol, PERIOD_CURRENT, 0);
		datetime 	   signal_entry_time = running_bullish_signals[i].entry_time;
		datetime 	   signal_close_time = running_bullish_signals[i].entry_time + 60 * 1; // 1 minutes duration

		if(
			candle_time_0 >= signal_close_time
		) {
			running_bullish_signals[i].close_time  = signal_close_time;
			running_bullish_signals[i].close_price = g_bid;
			running_bullish_signals[i].raw_profit  = RawProfitUsd(running_bullish_signals[i].signal_type, running_bullish_signals[i].entry_price, g_bid);

			// CLOSE THE BULLISH SIGNAL
			CloseBullishSignal(running_bullish_signals[i]);

			// REMOVE THE BULLISH SIGNAL FROM THE ARRAY
			RemoveElementFromArray(running_bullish_signals, i);

			continue;
		}
	}
}

void CheckTickOpenBearishSignals()
{
	int running_signals_total = ArraySize(running_bearish_signals);

	for(int i = running_signals_total-1; i >= 0; i--)
	{
		SignalStates signal_state  	   = running_bearish_signals[i].signal_state;
		datetime 	   candle_time_0  	 = iTime(_Symbol, PERIOD_CURRENT, 0);
		datetime 	   signal_entry_time = running_bearish_signals[i].entry_time;
		datetime 	   signal_close_time = running_bearish_signals[i].entry_time + 60 * 1; // 1 minutes duration

		if(
			candle_time_0 >= signal_close_time
		) {
			running_bearish_signals[i].close_time  = signal_close_time;
			running_bearish_signals[i].close_price = g_ask;
			running_bearish_signals[i].raw_profit  = RawProfitUsd(running_bearish_signals[i].signal_type, running_bearish_signals[i].entry_price, g_ask);

			// CLOSE THE BEARISH SIGNAL
			CloseBearishSignal(running_bearish_signals[i]);

			// REMOVE THE BEARISH SIGNAL FROM THE ARRAY
			RemoveElementFromArray(running_bearish_signals, i);

			continue;
		}
	}
}
