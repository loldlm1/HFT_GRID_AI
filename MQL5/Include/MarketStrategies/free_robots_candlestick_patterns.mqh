
bool CheckPatternsTrendSignal(
  int direction, ENUM_TIMEFRAMES timeframe,
  int indicator_stoch_handle,
  int indicator_handle_tf_stoch,
  int indicator_handle_b_percent,
  int indicator_handle_tf_b_percent,
  int indicator_handle_stoch_struct,
  int indicator_handle_stoch_struct_tf,
  IndicatorsHandleInfo &filter_indicator_handlers, SignalsDetectionInfo &valid_signal_information
) {
  double   body_ma_buffer[];
  double   real_ma_buffer[];
  bool     is_structure_tf        = true;
  bool     valid_pattern_trend    = false;
  int      indicator_bands_handle = filter_indicator_handlers.indicator_handle;
  datetime time_1                 = iTime(_Symbol, timeframe, 1);
  datetime time_2                 = iTime(_Symbol, timeframe, 2);

  // ++ STOCH VALUES ++
  double stoch_main_1   = StochMain(1, indicator_stoch_handle);
  double stoch_main_2   = StochMain(2, indicator_stoch_handle);
  double stoch_signal_2 = StochSignal(2, indicator_stoch_handle);
  double stoch_signal_1 = StochSignal(1, indicator_stoch_handle);
  double stoch_signal_0 = StochSignal(0, indicator_stoch_handle);
  // TF VALUES
  double tf_stoch_main_0   = StochMain(0, indicator_handle_tf_stoch);
  double tf_stoch_main_1   = StochMain(1, indicator_handle_tf_stoch);
  double tf_stoch_signal_0 = StochSignal(0, indicator_handle_tf_stoch);

  // ++ B % VALUES ++
  double bpercent_main_1   = BPercentMain(1, indicator_handle_b_percent);
  double bpercent_main_2   = BPercentMain(2, indicator_handle_b_percent);
  double bpercent_signal_0 = BPercentSignal(0, indicator_handle_b_percent);
  double bpercent_signal_1 = BPercentSignal(1, indicator_handle_b_percent);
  double bpercent_signal_2 = BPercentSignal(2, indicator_handle_b_percent);
  // TF TREND VALUES
  double tf_bpercent_main_0   = BPercentMain(0, indicator_handle_tf_b_percent);
  double tf_bpercent_main_1   = BPercentMain(1, indicator_handle_tf_b_percent);
  double tf_bpercent_signal_0 = BPercentSignal(0, indicator_handle_tf_b_percent);
  double tf_bpercent_signal_1 = BPercentSignal(1, indicator_handle_tf_b_percent);

  // TF CONFIRMATION MA TREND
  double tf_confirmation_ma_0 = IndicatorFilterMiddle(0, indicator_handle_tf_b_percent);
  double tf_confirmation_ma_1 = IndicatorFilterMiddle(1, indicator_handle_tf_b_percent);

  // BREAKOUT HIGH/LOW CONFIRMATIONS
  double low_2   = iLow(_Symbol, Indicator_Signal_TF, 2);
  double high_2  = iHigh(_Symbol, Indicator_Signal_TF, 2);
  double close_1 = iClose(_Symbol, Indicator_Signal_TF, 1);

  // TIMEFRAMES CONFIRMATIONS
  bool valid_m3_confirmations    = false;
  bool valid_trend_confirmations = false;

  if(
    direction == BULLISH &&
    tf_stoch_main_0    >= tf_stoch_main_1    &&
    tf_bpercent_main_0 >  tf_bpercent_main_1 &&
    tf_stoch_signal_0  <= 30                 &&
    tf_bpercent_main_0 <= 30
  ) valid_m3_confirmations = true;

  if(
    direction == BEARISH &&
    tf_stoch_main_0    <= tf_stoch_main_1    &&
    tf_bpercent_main_0 <  tf_bpercent_main_1 &&
    tf_stoch_signal_0  >= 70                 &&
    tf_bpercent_main_0 >= 70
  ) valid_m3_confirmations = true;

  // ENGINE CONFIRMATIONS
  if(
    direction == BULLISH                                                   &&
    GetOscillatorMarketStructure(direction, Indicator_Signal_TF, indicator_handle_stoch_struct) &&
    GetOscillatorMarketStructure(direction, Indicator_Filter_TF, indicator_handle_stoch_struct_tf, is_structure_tf) &&
    VerifyMarketStructure(direction, valid_signal_information)
  ) { valid_signal_information.trigger_signal_type = 2; valid_pattern_trend = true; } // LOWER BANDS SIGNAL

  if(
    direction == BEARISH                                                   &&
    GetOscillatorMarketStructure(direction, Indicator_Signal_TF, indicator_handle_stoch_struct) &&
    GetOscillatorMarketStructure(direction, Indicator_Filter_TF, indicator_handle_stoch_struct_tf, is_structure_tf) &&
    VerifyMarketStructure(direction, valid_signal_information)
  ) { valid_signal_information.trigger_signal_type = 4; valid_pattern_trend = true; } // UPPER BANDS SIGNAL

  //--- result of checking
  return(valid_pattern_trend && valid_m3_confirmations);
}

// STRUCT TREND TYPES

bool VerifyMarketStructure(int direction, SignalsDetectionInfo &valid_signal_information)
{
  double   input_fibonacci_level = GetFibonacciSignalLevel();
  datetime time_1                = iTime(_Symbol, Timeframe_Signal, 1);
  bool     valid_trend_fibonacci = true;
  bool     valid_deep_fibonacci  = false;
  bool     structure_confirmed   = false;

  // ++ CHECK STRUCTURE ++

  if(
    direction == BULLISH &&
    (
      (
        valid_trend_fibonacci                                                    &&
        bullish_signal_structure_tf_info.first_structure_type == OSCILLATOR_STRUCTURE_LL && // HIGH TIMERAME LL (ALSO COULD BE LH OPTIONAL)
        bullish_signal_structure_info.third_structure_type    == OSCILLATOR_STRUCTURE_LL &&
        bullish_signal_structure_info.second_structure_type   == OSCILLATOR_STRUCTURE_HL &&
        bullish_signal_structure_info.first_structure_type    == OSCILLATOR_STRUCTURE_LH
      )
    )
  ) structure_confirmed = true;

  if(
    direction == BEARISH &&
    (
      valid_trend_fibonacci                                                    &&
      bearish_signal_structure_tf_info.first_structure_type == OSCILLATOR_STRUCTURE_HH && // HIGH TIMERAME HH (ALSO COULD BE HL OPTIONAL)
      bearish_signal_structure_info.third_structure_type    == OSCILLATOR_STRUCTURE_HH &&
      bearish_signal_structure_info.second_structure_type   == OSCILLATOR_STRUCTURE_LH &&
      bearish_signal_structure_info.first_structure_type    == OSCILLATOR_STRUCTURE_HL
    )
  ) structure_confirmed = true;

  return structure_confirmed;
}

double GetFibonacciSignalLevel()
{
  if(Indicator_Fibo_Level == Fibonacci_Level_38)  return AllFibonacciLevels[2];
  if(Indicator_Fibo_Level == Fibonacci_Level_61)  return AllFibonacciLevels[3];
  if(Indicator_Fibo_Level == Fibonacci_Level_78)  return AllFibonacciLevels[4];
  if(Indicator_Fibo_Level == Fibonacci_Level_100) return AllFibonacciLevels[5];
  if(Indicator_Fibo_Level == Fibonacci_Level_161) return AllFibonacciLevels[8];
  if(Indicator_Fibo_Level == Fibonacci_Level_261) return AllFibonacciLevels[13];
  if(Indicator_Fibo_Level == Fibonacci_Level_423) return AllFibonacciLevels[21];

  return 0;
}

//+------------------------------------------------------------------+
//| Returns the middle body price for the specified bar              |
//+------------------------------------------------------------------+
double MidPoint(ENUM_TIMEFRAMES timeframe, int index)
{
  return(High(timeframe, index)+Low(timeframe, index))/2.;
}
//+------------------------------------------------------------------+
//| Returns the middle price of the range for the specified bar      |
//+------------------------------------------------------------------+
double MidOpenClose(ENUM_TIMEFRAMES timeframe, int index)
{
  return((Open(timeframe, index)+Close(timeframe, index))/2.);
}
//+------------------------------------------------------------------+
//| Returns the open price of the specified bar                      |
//+------------------------------------------------------------------+
double Open(ENUM_TIMEFRAMES timeframe, int index)
{
  double val=iOpen(_Symbol, timeframe, index);

  return(val);
}
//+------------------------------------------------------------------+
//| Returns the close price of the specified bar                     |
//+------------------------------------------------------------------+
double Close(ENUM_TIMEFRAMES timeframe, int index)
{
  double val=iClose(_Symbol, timeframe, index);

  return(val);
}
//+------------------------------------------------------------------+
//| Returns the low price of the specified bar                       |
//+------------------------------------------------------------------+
double Low(ENUM_TIMEFRAMES timeframe, int index)
{
  double val=iLow(_Symbol, timeframe, index);

  return(val);
}
//+------------------------------------------------------------------+
//| Returns the high price of the specified bar                      |
//+------------------------------------------------------------------+
double High(ENUM_TIMEFRAMES timeframe, int index)
{
  double val=iHigh(_Symbol, timeframe, index);

  return(val);
}
//+------------------------------------------------------------------+
//| Candle Body MA value at the specified bar                                   |
//+------------------------------------------------------------------+
double CandleBodyMA(int indicator_handle, double &indicator_values[])
{
  int total_values = CopyBuffer(indicator_handle, 1, 0, 10, indicator_values);

  if(total_values < 0) { Print("[ERROR] CandleBodyMA NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(total_values);
}
double CandleRealCandleMA(int indicator_handle, double &indicator_values[])
{
  int total_values = CopyBuffer(indicator_handle, 1, 0, 10, indicator_values);

  if(total_values < 0) { Print("[ERROR] CandleRealCandleMA NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(total_values);
}
//+------------------------------------------------------------------+
//| Candle Body MA value at the specified bar                                   |
//+------------------------------------------------------------------+
double CandleBodyPoints(int indicator_handle, double &indicator_values[])
{
  int total_values = CopyBuffer(indicator_handle, 0, 0, 10, indicator_values);

  if(total_values < 0) return EMPTY_VALUE;

  ArraySetAsSeries(indicator_values, true);

  return(total_values);
}
//+------------------------------------------------------------------+
//| MACD AWESOME STATES                                              |
//+------------------------------------------------------------------+
int CheckMACDAwesomeStateType(int indicator_handle)
{
  double indicator_values[];
  double color_indicator_values[];

  if(indicator_handle == INVALID_HANDLE) return 0;

  // MACD VALUES
  int total_values    = CopyBuffer(indicator_handle, 0, 0, 5, indicator_values);
  int total_ma_values = CopyBuffer(indicator_handle, 1, 0, 5, color_indicator_values);

  ArraySetAsSeries(indicator_values, true);
  ArraySetAsSeries(color_indicator_values, true);

  if(total_values <= 0 && total_ma_values <= 0)
  {
    PrintFormat("Failed to copy data from the AO indicator, error code %d", GetLastError());
    TesterStop();
  }

  int macd_trend_type_0 = 0;
  int macd_trend_type_1 = -1;
  int macd_trend_type_2 = -1;
  int macd_trend_type_3 = -1;

  // MACD TREND TYPE
  if(indicator_values[0] > 0 && color_indicator_values[0] == 1.0) macd_trend_type_0 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[0] > 0 && color_indicator_values[0] == 2.0) macd_trend_type_0 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[0] < 0 && color_indicator_values[0] == 1.0) macd_trend_type_0 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[0] < 0 && color_indicator_values[0] == 2.0) macd_trend_type_0 = 4; // MACD NEGATIVE DOWNTREND

  if(indicator_values[1] > 0 && color_indicator_values[1] == 1.0) macd_trend_type_1 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[1] > 0 && color_indicator_values[1] == 2.0) macd_trend_type_1 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[1] < 0 && color_indicator_values[1] == 1.0) macd_trend_type_1 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[1] < 0 && color_indicator_values[1] == 2.0) macd_trend_type_1 = 4; // MACD NEGATIVE DOWNTREND

  if(indicator_values[2] > 0 && color_indicator_values[2] == 1.0) macd_trend_type_2 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[2] > 0 && color_indicator_values[2] == 2.0) macd_trend_type_2 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[2] < 0 && color_indicator_values[2] == 1.0) macd_trend_type_2 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[2] < 0 && color_indicator_values[2] == 2.0) macd_trend_type_2 = 4; // MACD NEGATIVE DOWNTREND

  if(indicator_values[3] > 0 && color_indicator_values[3] == 1.0) macd_trend_type_3 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[3] > 0 && color_indicator_values[3] == 2.0) macd_trend_type_3 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[3] < 0 && color_indicator_values[3] == 1.0) macd_trend_type_3 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[3] < 0 && color_indicator_values[3] == 2.0) macd_trend_type_3 = 4; // MACD NEGATIVE DOWNTREND

  return (int)GenerateMACDSetupID(macd_trend_type_3, macd_trend_type_2, macd_trend_type_1);
}
//+------------------------------------------------------------------+
//| Indicator BB/ATR Volume at the specified bar                                   |
//+------------------------------------------------------------------+
double IndicatorBBATRVolume(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 0, 0, index+1, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
double IndicatorBBATRMAVolume(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 1, 0, index+1, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
//+------------------------------------------------------------------+
//| Indicator FIlter value at the specified bar                                   |
//+------------------------------------------------------------------+
double IndicatorFilterUpper(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 0, 0, index+5, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
double IndicatorFilterMiddle(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 1, 0, index+5, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
double IndicatorFilterLower(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 2, 0, index+5, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
double IndicatorFilterATR(int index, int indicator_handle)
{
  double indicator_values[];
  int    filter_total = -1;

  filter_total = CopyBuffer(indicator_handle, 8, 0, index+1, indicator_values);

  if(filter_total == -1) { Print("[ERROR] NOT LOADED FILTER DATA..."); TesterStop(); }

  ArraySetAsSeries(indicator_values, true);

  return(NormalizeDouble(indicator_values[index], _Digits+1));
}
//+------------------------------------------------------------------+
