
//+------------------------------------------------------------------+
//|                                       market_signal_dectector.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];

// ++ HELPER FUNCTION TO CALCULATE CORRECT SHIFT BASED ON ENTRY TIME ++

int GetShiftForEntryTime(datetime entry_time, ENUM_TIMEFRAMES tf)
{
  // Find which shift corresponds to the entry_time
  for(int shift = 0; shift < 100; shift++)
  {
    datetime candle_time = iTime(_Symbol, tf, shift);

    // Exact match - this is the candle we want
    if(candle_time == entry_time) return shift;

    // Candle is older than entry_time, so entry_time is between candles
    // Return previous shift (the newer one)
    if(candle_time < entry_time)
    {
      if(shift > 0) return shift - 1;
      return 0;
    }
  }

  // Fallback - should not normally reach here
  if(Enable_Verification_Logs)
  {
    PrintFormat("[WARNING] GetShiftForEntryTime: Could not find shift for entry_time %s on TF %s, using shift 0",
                TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                TimeframeToString(tf));
  }
  return 0;
}

void DetectBullishSignal()
{
  if(GuardStochasticSignalDetection(BULLISH)) return;

  SignalParams signal_bullish;

  // SET THE BULLISH SIGNAL PARAMETERS
  signal_bullish.signal_type = BULLISH;
  signal_bullish.entry_price = g_ask;
  signal_bullish.entry_time   = iTime(_Symbol, PERIOD_CURRENT, 0);

  // SET THE INDICATOR DATA
  SetTFBandsPercentDataToSignalParams(signal_bullish);
  SetTFStochasticDataToSignalParams(signal_bullish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bullish);
  SetTFBodyMADataToSignalParams(signal_bullish);

  // OPEN THE BULLISH SIGNAL TO THE MARKET
  // ...

  // ADD THE BULLISH SIGNAL TO THE ARRAY
  AddElementToArray(running_bullish_signals, signal_bullish);
}

void DetectBearishSignal()
{
  if(GuardStochasticSignalDetection(BEARISH)) return;

  SignalParams signal_bearish;

  // SET THE BEARISH SIGNAL PARAMETERS
  signal_bearish.signal_type = BEARISH;
  signal_bearish.entry_price = g_bid;
  signal_bearish.entry_time   = iTime(_Symbol, PERIOD_CURRENT, 0);

  // SET THE INDICATOR DATA
  SetTFBandsPercentDataToSignalParams(signal_bearish);
  SetTFStochasticDataToSignalParams(signal_bearish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bearish);
  SetTFBodyMADataToSignalParams(signal_bearish);

  // OPEN THE BEARISH SIGNAL TO THE MARKET
  // ...

  // ADD THE BEARISH SIGNAL TO THE ARRAY
  AddElementToArray(running_bearish_signals, signal_bearish);
}

// ++ GUARD CONDITIONS TO OPEN THE SIGNALS ++

bool GuardStochasticSignalDetection(const SignalTypes signal_type)
{
  // VERIFY STOCHASTIC SIGNAL CONDITIONS
  StochasticStructure stochastic_data;
  double stochastic_signal_1 = stochastic_data.GetStochasticSignalValue(ExtStochIndicatorsHandle[0], 1);

  if(signal_type == BULLISH && stochastic_signal_1 <= 30.0) return false;
  if(signal_type == BEARISH && stochastic_signal_1 >= 70.0) return false;

  return true;
}

// ++ CLOSE THE SIGNALS ++

void CloseBullishSignal(SignalParams &signal_bullish)
{
  if(Enable_Logs) LogSignalParamsForTF(signal_bullish, PERIOD_M1);
  if(Enable_Logs) Print("+++##########################################+++");
  if(Enable_Logs) LogSignalParamsForTF(signal_bullish, PERIOD_M3);

  // MANAGE THE BULLISH SIGNAL STATE
  // if(signal_bullish.signal_state == OPENED) { ... }
}

void CloseBearishSignal(SignalParams &signal_bearish)
{
  if(Enable_Logs) LogSignalParamsForTF(signal_bearish, PERIOD_M1);
  if(Enable_Logs) Print("+++##########################################+++");
  if(Enable_Logs) LogSignalParamsForTF(signal_bearish, PERIOD_M3);

  // MANAGE THE BULLISH SIGNAL STATE
  // if(signal_bearish.signal_state == OPENED) { ... }
}

// SET THE INDICATOR DATA TO THE SIGNAL PARAMS STRUCTURE

void SetTFBandsPercentDataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Bands Percent indicator handle in ExtBPercentIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtBPercentIndicatorsHandle); i++)
  {
    ENUM_TIMEFRAMES tf = ExtBPercentIndicatorsHandle[i].indicator_timeframe;

    // Calculate the correct shift based on entry_time
    int correct_shift = GetShiftForEntryTime(signal_params.entry_time, tf);

    // Verification logging for M1 only
    if(Enable_Verification_Logs && tf == PERIOD_M1)
    {
      datetime current_time = iTime(_Symbol, tf, 0);
      datetime shift_time = iTime(_Symbol, tf, correct_shift);
      PrintFormat("[TIMING-CHECK] BandsPct TF=%s | Current time: %s | Entry time: %s | Calculated shift: %d | Shift time: %s",
                  TimeframeToString(tf),
                  TimeToString(current_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                  correct_shift,
                  TimeToString(shift_time, TIME_DATE|TIME_MINUTES));

      // Verify match
      if(shift_time == signal_params.entry_time)
      {
        Print("[OK] Shift time matches entry_time ✓");
      }
      else
      {
        PrintFormat("[WARNING] Shift time mismatch! Expected: %s, Got: %s",
                    TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                    TimeToString(shift_time, TIME_DATE|TIME_MINUTES));
      }
    }

    BandsPercentStructure bands_percent_data;
    bands_percent_data = BandsPercentStructure();
    bands_percent_data.InitBandsPercentStructureValues(ExtBPercentIndicatorsHandle[i], correct_shift);

    // Validate data corresponds to entry_time
    ValidateBandsPercentDataOrder(bands_percent_data, signal_params.entry_time);

    AddElementToArray(signal_params.bands_percent_data, bands_percent_data);
  }
}

void SetTFStochasticDataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Stochastic indicator handle in ExtStochIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtStochIndicatorsHandle); i++)
  {
    ENUM_TIMEFRAMES tf = ExtStochIndicatorsHandle[i].indicator_timeframe;

    // Calculate the correct shift based on entry_time
    int correct_shift = GetShiftForEntryTime(signal_params.entry_time, tf);

    // Verification logging for M1 only
    if(Enable_Verification_Logs && tf == PERIOD_M1)
    {
      datetime current_time = iTime(_Symbol, tf, 0);
      datetime shift_time = iTime(_Symbol, tf, correct_shift);
      PrintFormat("[TIMING-CHECK] Stochastic TF=%s | Current time: %s | Entry time: %s | Calculated shift: %d | Shift time: %s",
                  TimeframeToString(tf),
                  TimeToString(current_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                  correct_shift,
                  TimeToString(shift_time, TIME_DATE|TIME_MINUTES));

      // Verify match
      if(shift_time == signal_params.entry_time)
      {
        Print("[OK] Shift time matches entry_time ✓");
      }
      else
      {
        PrintFormat("[WARNING] Shift time mismatch! Expected: %s, Got: %s",
                    TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                    TimeToString(shift_time, TIME_DATE|TIME_MINUTES));
      }
    }

    StochasticStructure stochastic_data;
    stochastic_data = StochasticStructure();
    stochastic_data.InitStochasticStructureValues(ExtStochIndicatorsHandle[i], correct_shift);

    // Validate data corresponds to entry_time
    ValidateStochasticDataOrder(stochastic_data, signal_params.entry_time);

    AddElementToArray(signal_params.stochastic_data, stochastic_data);
  }
}

void SetTFStochasticMarketStructureDataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Stochastic market structure indicator handle in ExtStructStochIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtStructStochIndicatorsHandle); i++)
  {
    StochasticMarketStructure stoch_market_structure_data;
    stoch_market_structure_data = StochasticMarketStructure();
    stoch_market_structure_data.InitStochMarketStructureValues(ExtStructStochIndicatorsHandle[i]);
    AddElementToArray(signal_params.stoch_market_structure_data, stoch_market_structure_data);
  }
}

void SetTFBodyMADataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Body MA indicator handle in ExtBodyMAIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtBodyMAIndicatorsHandle); i++)
  {
    ENUM_TIMEFRAMES tf = ExtBodyMAIndicatorsHandle[i].indicator_timeframe;

    // Calculate the correct shift based on entry_time
    int correct_shift = GetShiftForEntryTime(signal_params.entry_time, tf);

    // Verification logging for M1 only
    if(Enable_Verification_Logs && tf == PERIOD_M1)
    {
      datetime current_time = iTime(_Symbol, tf, 0);
      datetime shift_time = iTime(_Symbol, tf, correct_shift);
      PrintFormat("[TIMING-CHECK] BodyMA TF=%s | Current time: %s | Entry time: %s | Calculated shift: %d | Shift time: %s",
                  TimeframeToString(tf),
                  TimeToString(current_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                  correct_shift,
                  TimeToString(shift_time, TIME_DATE|TIME_MINUTES));

      // Verify match
      if(shift_time == signal_params.entry_time)
      {
        Print("[OK] Shift time matches entry_time ✓");
      }
      else
      {
        PrintFormat("[WARNING] Shift time mismatch! Expected: %s, Got: %s",
                    TimeToString(signal_params.entry_time, TIME_DATE|TIME_MINUTES),
                    TimeToString(shift_time, TIME_DATE|TIME_MINUTES));
      }
    }

    BodyMAStructure body_ma_data;
    body_ma_data = BodyMAStructure();
    body_ma_data.InitBodyMAStructureValues(ExtBodyMAIndicatorsHandle[i], correct_shift);

    // Validate data corresponds to entry_time
    ValidateBodyMADataOrder(body_ma_data, signal_params.entry_time);

    AddElementToArray(signal_params.body_ma_data, body_ma_data);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
