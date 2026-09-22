#ifndef CANDLE_FEATURES_MQH
#define CANDLE_FEATURES_MQH

bool CandleCopyBuffer(const int handle, const int buffer, double &values[])
{
  ArrayInitialize(values, EMPTY_VALUE);
  if(handle == INVALID_HANDLE || BarsCalculated(handle) < CANDLE_RAW_SHIFTS) return false;
  double copied[11];
  if(CopyBuffer(handle, buffer, 0, CANDLE_RAW_SHIFTS, copied) != CANDLE_RAW_SHIFTS) return false;
  for(int shift = 0; shift < CANDLE_RAW_SHIFTS; shift++)
    values[shift] = copied[CANDLE_RAW_SHIFTS - shift - 1];
  return true;
}

bool CandleSeriesCells(string &row, const double &values[])
{
  bool complete = true;
  for(int shift = 0; shift < CANDLE_EXPORT_SHIFTS; shift++)
  {
    double sma = 0.0, previous = 0.0;
    bool available = true;
    for(int offset = 0; offset < CANDLE_SMA_PERIOD; offset++)
    {
      if(!CandleNumberValid(values[shift + offset]) || !CandleNumberValid(values[shift + offset + 1]))
      {
        available = false;
        break;
      }
      sma += values[shift + offset];
      previous += values[shift + offset + 1];
    }
    sma /= CANDLE_SMA_PERIOD;
    previous /= CANDLE_SMA_PERIOD;
    available = available && CandleNumberValid(sma) && CandleNumberValid(previous) &&
                CandleNumberValid(sma - previous);
    if(!available)
    {
      complete = false;
      for(int field = 0; field < 4; field++) CandleCell(row, "\\N");
      continue;
    }
    double difference = values[shift] - sma;
    CandleCell(row, CandleNumber(values[shift]));
    CandleCell(row, CandleNumber(sma));
    CandleCell(row, CandleNumber(sma - previous));
    CandleCell(row, difference > CANDLE_STATE_TOLERANCE ? "ABOVE" :
                     (difference < -CANDLE_STATE_TOLERANCE ? "BELOW" : "EQUAL"));
  }
  return complete;
}

void CandleFeatureCells(string &row, const int slot, const ENUM_TIMEFRAMES timeframe,
                        const MqlTick &tick)
{
  double base[11], upper[11], lower[11], stochastic_main[11], stochastic_signal[11];
  bool causal = iTime(_Symbol, timeframe, 0) > 0 && iTime(_Symbol, timeframe, 0) <= tick.time;
  bool base_ok = CandleCopyBuffer(g_candle_bands[slot], 0, base);
  bool upper_ok = CandleCopyBuffer(g_candle_bands[slot], 1, upper);
  bool lower_ok = CandleCopyBuffer(g_candle_bands[slot], 2, lower);
  bool main_ok = CandleCopyBuffer(g_candle_stochastic[slot], 0, stochastic_main);
  bool signal_ok = CandleCopyBuffer(g_candle_stochastic[slot], 1, stochastic_signal);
  bool bands_ok = causal && base_ok && upper_ok && lower_ok;
  double signal_b[11], pivot_b[11];
  ArrayInitialize(signal_b, EMPTY_VALUE);
  ArrayInitialize(pivot_b, EMPTY_VALUE);
  for(int i = 0; i < CANDLE_RAW_SHIFTS; i++)
  {
    bool band_valid = causal && CandleNumberValid(base[i]) && base[i] > 0.0 &&
                      CandleNumberValid(upper[i]) && CandleNumberValid(lower[i]) && upper[i] > lower[i];
    if(band_valid)
    {
      signal_b[i] = 100.0 * (tick.bid - lower[i]) / (upper[i] - lower[i]);
      if(g_candle_context >= 0 && g_candle_ladder.valid)
        pivot_b[i] = 100.0 * (g_candle_ladder.trade_prices[g_candle_context] - lower[i]) /
                     (upper[i] - lower[i]);
    }
    else bands_ok = false;
    if(!causal || !main_ok || !CandleNumberValid(stochastic_main[i]) ||
       stochastic_main[i] < -CANDLE_STATE_TOLERANCE || stochastic_main[i] > 100.0 + CANDLE_STATE_TOLERANCE)
      stochastic_main[i] = EMPTY_VALUE;
    if(!causal || !signal_ok || !CandleNumberValid(stochastic_signal[i]) ||
       stochastic_signal[i] < -CANDLE_STATE_TOLERANCE || stochastic_signal[i] > 100.0 + CANDLE_STATE_TOLERANCE)
      stochastic_signal[i] = EMPTY_VALUE;
  }
  string features = bands_ok ? CandleNumber((upper[0] - lower[0]) / _Point) : "\\N";
  bool signal_b_ok = CandleSeriesCells(features, signal_b);
  bool pivot_b_ok = CandleSeriesCells(features, pivot_b);
  bool main_series_ok = CandleSeriesCells(features, stochastic_main);
  bool signal_series_ok = CandleSeriesCells(features, stochastic_signal);
  for(int shift = 0; shift < CANDLE_EXPORT_SHIFTS; shift++)
  {
    bool available = bands_ok && CandleNumberValid(base[shift]) && CandleNumberValid(base[shift + 1]);
    CandleCell(features, available ? CandleNumber(base[shift]) : "\\N");
    CandleCell(features, available ? CandleNumber((base[shift] - base[shift + 1]) / _Point) : "\\N");
  }
  CandleCell(row, CandleBoolean(bands_ok && signal_b_ok && main_series_ok && signal_series_ok));
  CandleCell(row, CandleBoolean(bands_ok && pivot_b_ok));
  row += "\t" + features;
}

bool CandleOpenIndicators()
{
  ArrayInitialize(g_candle_bands, INVALID_HANDLE);
  ArrayInitialize(g_candle_stochastic, INVALID_HANDLE);
  if(MQLInfoInteger(MQL_TESTER)) TesterHideIndicators(true);
  g_atr_handle = iATR(_Symbol, Micro_Timeframe, CANDLE_ATR_PERIOD);
  if(g_atr_handle == INVALID_HANDLE) return false;
  if(!Enable_Signal_Feature_Export) return true;
  for(int i = 0; i < 2; i++)
  {
    ENUM_TIMEFRAMES timeframe = i == 0 ? Macro_Timeframe : Micro_Timeframe;
    g_candle_bands[i] = iBands(_Symbol, timeframe, 21, 0, 2.0, PRICE_WEIGHTED);
    g_candle_stochastic[i] = iStochastic(_Symbol, timeframe, 5, 3, 3, MODE_SMA, STO_CLOSECLOSE);
    if(g_candle_bands[i] == INVALID_HANDLE || g_candle_stochastic[i] == INVALID_HANDLE)
      PrintFormat("CANDLE_FEATURE_INCOMPLETE | timeframe=%s | optional indicator unavailable", EnumToString(timeframe));
  }
  return true;
}

void CandleCloseIndicators()
{
  if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
  g_atr_handle = INVALID_HANDLE;
  for(int i = 0; i < 2; i++)
  {
    if(g_candle_bands[i] != INVALID_HANDLE) IndicatorRelease(g_candle_bands[i]);
    if(g_candle_stochastic[i] != INVALID_HANDLE) IndicatorRelease(g_candle_stochastic[i]);
    g_candle_bands[i] = INVALID_HANDLE;
    g_candle_stochastic[i] = INVALID_HANDLE;
  }
}

#endif
