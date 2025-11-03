//+------------------------------------------------------------------+
//|                          microservices/utils/logs_helper.mqh   |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_LOGS_HELPER_MQH_
#define _MICROSERVICES_UTILS_LOGS_HELPER_MQH_

#include "../core/enums.mqh"
#include "../indicators/structure_classifier.mqh"

// Forward declarations - these will be resolved when indicator structures are included
struct SignalParams;
struct BandsPercentStructure;
struct StochasticStructure;
struct StochasticMarketStructure;
struct BodyMAStructure;
struct ExtremumStatistics;
struct RetestZoneStatistics;
struct OscillatorMarketStructure;

// External globals that will be defined in the main EA or service layer
extern string g_dataset_id;

// ── Helpers ─────────────────────────────────────────────────────────────

void Log_Custom(string text)
{
  if(Enable_Logs) Print(text);
}

string TimeframeToString(const ENUM_TIMEFRAMES tf)
{
  switch (tf)
  {
    case PERIOD_M1:  return "M1";
    case PERIOD_M2:  return "M2";
    case PERIOD_M3:  return "M3";
    case PERIOD_M4:  return "M4";
    case PERIOD_M5:  return "M5";
    case PERIOD_M6:  return "M6";
    case PERIOD_M10: return "M10";
    case PERIOD_M12: return "M12";
    case PERIOD_M15: return "M15";
    case PERIOD_M20: return "M20";
    case PERIOD_M30: return "M30";
    case PERIOD_H1:  return "H1";
    case PERIOD_H2:  return "H2";
    case PERIOD_H3:  return "H3";
    case PERIOD_H4:  return "H4";
    case PERIOD_H6:  return "H6";
    case PERIOD_H8:  return "H8";
    case PERIOD_H12: return "H12";
    case PERIOD_D1:  return "D1";
    case PERIOD_W1:  return "W1";
    case PERIOD_MN1: return "MN1";
  }
  return StringFormat("TF(%d)", (int)tf);
}

string OscillatorStructureTypesToString(const OscillatorStructureTypes t)
{
  switch (t)
  {
    case OSCILLATOR_STRUCTURE_EQ: return "EQ";
    case OSCILLATOR_STRUCTURE_HH: return "HH";
    case OSCILLATOR_STRUCTURE_HL: return "HL";
    case OSCILLATOR_STRUCTURE_LH: return "LH";
    case OSCILLATOR_STRUCTURE_LL: return "LL";
  }
  return StringFormat("T(%d)", (int)t);
}

string SignalTypeToString(const SignalTypes s)
{
  switch (s)
  {
    case NO_SIGNAL: return "NO_SIGNAL";
    case BULLISH:   return "BULLISH";
    case BEARISH:   return "BEARISH";
  }
  return StringFormat("SIG(%d)", (int)s);
}

// Ajusta si tienes un enum de estados con etiquetas propias
string SignalStateToString(const SignalStates st)
{
  return StringFormat("STATE(%s)", EnumToString(st));
}

string BodyTrendTypeToString(const BodyTrendTypes t)
{
  switch (t)
  {
    case BODY_UNDEFINED:     return "BODY_UNDEFINED";
    case STRONG_BODY_TREND:  return "STRONG_BODY_TREND";
    case WEAK_BODY_TREND:    return "WEAK_BODY_TREND";
  }
  return StringFormat("BODY_TREND(%d)", (int)t);
}

string BodyMATypeToString(const BodyMATypes t)
{
  switch (t)
  {
    case BODY_UNDEFINED_MA: return "BODY_UNDEFINED_MA";
    case BODY_BULLISH_MA:   return "BODY_BULLISH_MA";
    case BODY_BEARISH_MA:   return "BODY_BEARISH_MA";
  }
  return StringFormat("BODY_MA(%d)", (int)t);
}

string DtToStr(const datetime t)
{
  return TimeToString(t, TIME_DATE | TIME_SECONDS);
}

// Default no-const: usamos -1 y caemos al dígito del símbolo
string P(const double v, const int digits = -1)
{
  int use_digits = digits;
  if (use_digits < 0)
    use_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  return DoubleToString(v, use_digits);
}

// ── Validation Functions ────────────────────────────────────────────────

bool ValidateBandsPercentDataOrder(const BandsPercentStructure &bands_data, datetime entry_time = 0)
{
  // Only validate M1 timeframe when verification logs are enabled
  if(!Enable_Verification_Logs || bands_data.indicator_timeframe != PERIOD_M1) return true;

  // If entry_time provided, validate that data corresponds to entry_time candle
  // Otherwise just validate the order
  if(entry_time > 0)
  {
    // Find shift for entry_time
    int entry_shift = 0;
    for(int s = 0; s < 100; s++)
    {
      if(iTime(_Symbol, bands_data.indicator_timeframe, s) == entry_time)
      {
        entry_shift = s;
        break;
      }
    }

    // Get expected timestamps
    datetime expected_time_0 = iTime(_Symbol, bands_data.indicator_timeframe, entry_shift);
    datetime expected_time_1 = iTime(_Symbol, bands_data.indicator_timeframe, entry_shift + 1);
    datetime expected_time_2 = iTime(_Symbol, bands_data.indicator_timeframe, entry_shift + 2);
    datetime expected_time_3 = iTime(_Symbol, bands_data.indicator_timeframe, entry_shift + 3);

    // Verify the first timestamp matches entry_time
    bool valid = (expected_time_0 == entry_time);

    if(valid)
    {
      PrintFormat("[OK] BandsPct data matches entry_time for TF=%s: entry=%s, data_times=[%s, %s, %s, %s]",
                  TimeframeToString(bands_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(expected_time_0, TIME_MINUTES),
                  TimeToString(expected_time_1, TIME_MINUTES),
                  TimeToString(expected_time_2, TIME_MINUTES),
                  TimeToString(expected_time_3, TIME_MINUTES));
    }
    else
    {
      PrintFormat("[ERROR] BandsPct data MISMATCH with entry_time for TF=%s! entry=%s, shift=%d, shift_time=%s",
                  TimeframeToString(bands_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  entry_shift,
                  TimeToString(expected_time_0, TIME_DATE|TIME_MINUTES));
    }

    return valid;
  }
  else
  {
    // Legacy validation - just check order
    datetime time_0 = iTime(_Symbol, bands_data.indicator_timeframe, 0);
    datetime time_1 = iTime(_Symbol, bands_data.indicator_timeframe, 1);
    datetime time_2 = iTime(_Symbol, bands_data.indicator_timeframe, 2);
    datetime time_3 = iTime(_Symbol, bands_data.indicator_timeframe, 3);

    bool order_valid = (time_0 > time_1) && (time_1 > time_2) && (time_2 > time_3);

    if(order_valid)
    {
      PrintFormat("[OK] BandsPct timestamp order VALID for TF=%s: %s > %s > %s > %s",
                  TimeframeToString(bands_data.indicator_timeframe),
                  TimeToString(time_0, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_1, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_2, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_3, TIME_DATE|TIME_MINUTES));
    }

    return order_valid;
  }
}

bool ValidateStochasticDataOrder(const StochasticStructure &stoch_data, datetime entry_time = 0)
{
  // Only validate M1 timeframe when verification logs are enabled
  if(!Enable_Verification_Logs || stoch_data.indicator_timeframe != PERIOD_M1) return true;

  // If entry_time provided, validate that data corresponds to entry_time candle
  // Otherwise just validate the order
  if(entry_time > 0)
  {
    // Find shift for entry_time
    int entry_shift = 0;
    for(int s = 0; s < 100; s++)
    {
      if(iTime(_Symbol, stoch_data.indicator_timeframe, s) == entry_time)
      {
        entry_shift = s;
        break;
      }
    }

    // Get expected timestamps
    datetime expected_time_0 = iTime(_Symbol, stoch_data.indicator_timeframe, entry_shift);
    datetime expected_time_1 = iTime(_Symbol, stoch_data.indicator_timeframe, entry_shift + 1);
    datetime expected_time_2 = iTime(_Symbol, stoch_data.indicator_timeframe, entry_shift + 2);
    datetime expected_time_3 = iTime(_Symbol, stoch_data.indicator_timeframe, entry_shift + 3);

    // Verify the first timestamp matches entry_time
    bool valid = (expected_time_0 == entry_time);

    if(valid)
    {
      PrintFormat("[OK] Stochastic data matches entry_time for TF=%s: entry=%s, data_times=[%s, %s, %s, %s]",
                  TimeframeToString(stoch_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(expected_time_0, TIME_MINUTES),
                  TimeToString(expected_time_1, TIME_MINUTES),
                  TimeToString(expected_time_2, TIME_MINUTES),
                  TimeToString(expected_time_3, TIME_MINUTES));
    }
    else
    {
      PrintFormat("[ERROR] Stochastic data MISMATCH with entry_time for TF=%s! entry=%s, shift=%d, shift_time=%s",
                  TimeframeToString(stoch_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  entry_shift,
                  TimeToString(expected_time_0, TIME_DATE|TIME_MINUTES));
    }

    return valid;
  }
  else
  {
    // Legacy validation - just check order
    datetime time_0 = iTime(_Symbol, stoch_data.indicator_timeframe, 0);
    datetime time_1 = iTime(_Symbol, stoch_data.indicator_timeframe, 1);
    datetime time_2 = iTime(_Symbol, stoch_data.indicator_timeframe, 2);
    datetime time_3 = iTime(_Symbol, stoch_data.indicator_timeframe, 3);

    bool order_valid = (time_0 > time_1) && (time_1 > time_2) && (time_2 > time_3);

    if(order_valid)
    {
      PrintFormat("[OK] Stochastic timestamp order VALID for TF=%s: %s > %s > %s > %s",
                  TimeframeToString(stoch_data.indicator_timeframe),
                  TimeToString(time_0, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_1, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_2, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_3, TIME_DATE|TIME_MINUTES));
    }

    return order_valid;
  }
}

bool ValidateBodyMADataOrder(const BodyMAStructure &body_ma_data, datetime entry_time = 0)
{
  // Only validate M1 timeframe when verification logs are enabled
  if(!Enable_Verification_Logs || body_ma_data.indicator_timeframe != PERIOD_M1) return true;

  // If entry_time provided, validate that data corresponds to entry_time candle
  // Otherwise just validate the order
  if(entry_time > 0)
  {
    // Find shift for entry_time
    int entry_shift = 0;
    for(int s = 0; s < 100; s++)
    {
      if(iTime(_Symbol, body_ma_data.indicator_timeframe, s) == entry_time)
      {
        entry_shift = s;
        break;
      }
    }

    // Get expected timestamps
    datetime expected_time_0 = iTime(_Symbol, body_ma_data.indicator_timeframe, entry_shift);
    datetime expected_time_1 = iTime(_Symbol, body_ma_data.indicator_timeframe, entry_shift + 1);
    datetime expected_time_2 = iTime(_Symbol, body_ma_data.indicator_timeframe, entry_shift + 2);
    datetime expected_time_3 = iTime(_Symbol, body_ma_data.indicator_timeframe, entry_shift + 3);

    // Verify the first timestamp matches entry_time
    bool valid = (expected_time_0 == entry_time);

    if(valid)
    {
      PrintFormat("[OK] BodyMA data matches entry_time for TF=%s: entry=%s, data_times=[%s, %s, %s, %s]",
                  TimeframeToString(body_ma_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  TimeToString(expected_time_0, TIME_MINUTES),
                  TimeToString(expected_time_1, TIME_MINUTES),
                  TimeToString(expected_time_2, TIME_MINUTES),
                  TimeToString(expected_time_3, TIME_MINUTES));
    }
    else
    {
      PrintFormat("[ERROR] BodyMA data MISMATCH with entry_time for TF=%s! entry=%s, shift=%d, shift_time=%s",
                  TimeframeToString(body_ma_data.indicator_timeframe),
                  TimeToString(entry_time, TIME_DATE|TIME_MINUTES),
                  entry_shift,
                  TimeToString(expected_time_0, TIME_DATE|TIME_MINUTES));
    }

    return valid;
  }
  else
  {
    // Legacy validation - just check order
    datetime time_0 = iTime(_Symbol, body_ma_data.indicator_timeframe, 0);
    datetime time_1 = iTime(_Symbol, body_ma_data.indicator_timeframe, 1);
    datetime time_2 = iTime(_Symbol, body_ma_data.indicator_timeframe, 2);
    datetime time_3 = iTime(_Symbol, body_ma_data.indicator_timeframe, 3);

    bool order_valid = (time_0 > time_1) && (time_1 > time_2) && (time_2 > time_3);

    if(order_valid)
    {
      PrintFormat("[OK] BodyMA timestamp order VALID for TF=%s: %s > %s > %s > %s",
                  TimeframeToString(body_ma_data.indicator_timeframe),
                  TimeToString(time_0, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_1, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_2, TIME_DATE|TIME_MINUTES),
                  TimeToString(time_3, TIME_DATE|TIME_MINUTES));
    }

    return order_valid;
  }
}

// ── Logger filtrado por timeframe ───────────────────────────────────────

void LogSignalParamsForTF(const SignalParams &signal_params,
                          const ENUM_TIMEFRAMES timeframe,
                          const int max_slots = -1)
{
  const string tf_str = TimeframeToString(timeframe);

  const int n_bands  = ArraySize(signal_params.bands_percent_data);
  const int n_stoch  = ArraySize(signal_params.stochastic_data);
  const int n_struct = ArraySize(signal_params.stoch_market_structure_data);
  const int n_body_ma = ArraySize(signal_params.body_ma_data);

  Print("────────────────────────────────────────────────────────────────────────");
  PrintFormat("SIGNAL PARAMS  [TF=%s]  [DATASET_ID=%s]", tf_str, g_dataset_id);
  PrintFormat(" type=%s  state=%s  ticket=%s",
              SignalTypeToString(signal_params.signal_type),
              SignalStateToString(signal_params.signal_state),
              signal_params.ticket_id);
  PrintFormat(" entry=%s  close=%s  sl=%s  tp=%s  lot=%.2f  raw_profit=%s",
              P(signal_params.entry_price),
              P(signal_params.close_price),
              P(signal_params.stop_loss),
              P(signal_params.take_profit),
              signal_params.lot_size,
              P(signal_params.raw_profit, 2));
  PrintFormat(" entry_time=%s  close_time=%s",
              DtToStr(signal_params.entry_time),
              DtToStr(signal_params.close_time));
  PrintFormat(" arrays: bands=%d  stochastic=%d  stoch_struct=%d  body_ma=%d",
              n_bands, n_stoch, n_struct, n_body_ma);
  Print("────────────────────────────────────────────────────────────────────────");

  // BandsPercentStructure
  {
    int printed = 0;
    bool any = false;
    for (int i = 0; i < n_bands; ++i)
    {
      const BandsPercentStructure b = signal_params.bands_percent_data[i];
      if(b.indicator_timeframe != timeframe) continue;
      any = true;

      // Get timestamps based on entry_time (what the stored data should represent)
      // Find the shift for entry_time, then get timestamps for that shift and following ones
      int entry_shift = 0;
      for(int s = 0; s < 100; s++)
      {
        if(iTime(_Symbol, timeframe, s) == signal_params.entry_time)
        {
          entry_shift = s;
          break;
        }
      }

      datetime time_0 = iTime(_Symbol, timeframe, entry_shift);     // entry_time candle
      datetime time_1 = iTime(_Symbol, timeframe, entry_shift + 1); // 1 candle before entry_time
      datetime time_2 = iTime(_Symbol, timeframe, entry_shift + 2); // 2 candles before entry_time
      datetime time_3 = iTime(_Symbol, timeframe, entry_shift + 3); // 3 candles before entry_time

      PrintFormat("▼ Bands[%d] (tf = %s)  (period = %d)", i, tf_str, b.indicator_period);
      PrintFormat("  values:      [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(b.bands_percent_0, 2), TimeToString(time_0, TIME_MINUTES),
                  P(b.bands_percent_1, 2), TimeToString(time_1, TIME_MINUTES),
                  P(b.bands_percent_2, 2), TimeToString(time_2, TIME_MINUTES),
                  P(b.bands_percent_3, 2), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  signals:     [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(b.bands_percent_signal_0, 2), TimeToString(time_0, TIME_MINUTES),
                  P(b.bands_percent_signal_1, 2), TimeToString(time_1, TIME_MINUTES),
                  P(b.bands_percent_signal_2, 2), TimeToString(time_2, TIME_MINUTES),
                  P(b.bands_percent_signal_3, 2), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  slopes:      [%s, %s, %s, %s]",
                  EnumToString(b.bands_percent_slope_0), EnumToString(b.bands_percent_slope_1),
                  EnumToString(b.bands_percent_slope_2), EnumToString(b.bands_percent_slope_3));
      PrintFormat("  sig_slopes:  [%s, %s, %s, %s]",
                  EnumToString(b.bands_percent_signal_slope_0), EnumToString(b.bands_percent_signal_slope_1),
                  EnumToString(b.bands_percent_signal_slope_2), EnumToString(b.bands_percent_signal_slope_3));
      PrintFormat("  percentil:   [%s, %s, %s, %s]",
                  EnumToString(b.bands_percent_percentil_0), EnumToString(b.bands_percent_percentil_1),
                  EnumToString(b.bands_percent_percentil_2), EnumToString(b.bands_percent_percentil_3));
      PrintFormat("  sig_percentil:[%s, %s, %s, %s]",
                  EnumToString(b.bands_percent_signal_percentil_0), EnumToString(b.bands_percent_signal_percentil_1),
                  EnumToString(b.bands_percent_signal_percentil_2), EnumToString(b.bands_percent_signal_percentil_3));
      PrintFormat("  trend:       [%s, %s, %s, %s]",
                  SignalTypeToString(b.bands_percent_trend_0),
                  SignalTypeToString(b.bands_percent_trend_1),
                  SignalTypeToString(b.bands_percent_trend_2),
                  SignalTypeToString(b.bands_percent_trend_3));
      PrintFormat("  bb_close:    [%s, %s, %s, %s]",
                  P(b.bb_close_0, 2), P(b.bb_close_1, 2),
                  P(b.bb_close_2, 2), P(b.bb_close_3, 2));
      PrintFormat("  bb_open:     [%s, %s, %s, %s]",
                  P(b.bb_open_0, 2), P(b.bb_open_1, 2),
                  P(b.bb_open_2, 2), P(b.bb_open_3, 2));
      PrintFormat("  bb_high:     [%s, %s, %s, %s]",
                  P(b.bb_high_0, 2), P(b.bb_high_1, 2),
                  P(b.bb_high_2, 2), P(b.bb_high_3, 2));
      PrintFormat("  bb_low:      [%s, %s, %s, %s]",
                  P(b.bb_low_0, 2), P(b.bb_low_1, 2),
                  P(b.bb_low_2, 2), P(b.bb_low_3, 2));
      Print("  ────────────────────────────────────────────────────────────────────");

      ++printed;
      if (max_slots > 0 && printed >= max_slots) break;
    }
    if (!any) PrintFormat("Bands: <no data for TF=%s>", tf_str);
  }

  // StochasticStructure
  {
    int printed = 0;
    bool any = false;
    for (int i = 0; i < n_stoch; ++i)
    {
      const StochasticStructure s = signal_params.stochastic_data[i];
      if(s.indicator_timeframe != timeframe) continue;
      any = true;

      // Get timestamps based on entry_time (what the stored data should represent)
      // Find the shift for entry_time, then get timestamps for that shift and following ones
      int entry_shift = 0;
      for(int sh = 0; sh < 100; sh++)
      {
        if(iTime(_Symbol, timeframe, sh) == signal_params.entry_time)
        {
          entry_shift = sh;
          break;
        }
      }

      datetime time_0 = iTime(_Symbol, timeframe, entry_shift);     // entry_time candle
      datetime time_1 = iTime(_Symbol, timeframe, entry_shift + 1); // 1 candle before entry_time
      datetime time_2 = iTime(_Symbol, timeframe, entry_shift + 2); // 2 candles before entry_time
      datetime time_3 = iTime(_Symbol, timeframe, entry_shift + 3); // 3 candles before entry_time

      PrintFormat("▼ Stochastic[%d] (tf = %s)  (period = %d)", i, tf_str, s.indicator_period);
      PrintFormat("  values:      [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(s.stochastic_0, 2), TimeToString(time_0, TIME_MINUTES),
                  P(s.stochastic_1, 2), TimeToString(time_1, TIME_MINUTES),
                  P(s.stochastic_2, 2), TimeToString(time_2, TIME_MINUTES),
                  P(s.stochastic_3, 2), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  signals:     [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(s.stochastic_signal_0, 2), TimeToString(time_0, TIME_MINUTES),
                  P(s.stochastic_signal_1, 2), TimeToString(time_1, TIME_MINUTES),
                  P(s.stochastic_signal_2, 2), TimeToString(time_2, TIME_MINUTES),
                  P(s.stochastic_signal_3, 2), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  slopes:      [%s, %s, %s, %s]",
                  EnumToString(s.stochastic_slope_0), EnumToString(s.stochastic_slope_1),
                  EnumToString(s.stochastic_slope_2), EnumToString(s.stochastic_slope_3));
      PrintFormat("  sig_slopes:  [%s, %s, %s, %s]",
                  EnumToString(s.stochastic_signal_slope_0), EnumToString(s.stochastic_signal_slope_1),
                  EnumToString(s.stochastic_signal_slope_2), EnumToString(s.stochastic_signal_slope_3));
      PrintFormat("  percentil:   [%s, %s, %s, %s]",
                  EnumToString(s.stochastic_percentil_0), EnumToString(s.stochastic_percentil_1),
                  EnumToString(s.stochastic_percentil_2), EnumToString(s.stochastic_percentil_3));
      PrintFormat("  sig_percentil:[%s, %s, %s, %s]",
                  EnumToString(s.stochastic_signal_percentil_0), EnumToString(s.stochastic_signal_percentil_1),
                  EnumToString(s.stochastic_signal_percentil_2), EnumToString(s.stochastic_signal_percentil_3));
      PrintFormat("  trend:       [%s, %s, %s, %s]",
                  SignalTypeToString(s.stochastic_trend_0),
                  SignalTypeToString(s.stochastic_trend_1),
                  SignalTypeToString(s.stochastic_trend_2),
                  SignalTypeToString(s.stochastic_trend_3));
      Print("  ────────────────────────────────────────────────────────────────────");

      ++printed;
      if (max_slots > 0 && printed >= max_slots) break;
    }
    if (!any) PrintFormat("Stochastic: <no data for TF=%s>", tf_str);
  }

  // BodyMAStructure
  {
    int printed = 0;
    bool any = false;
    for (int i = 0; i < n_body_ma; ++i)
    {
      const BodyMAStructure bm = signal_params.body_ma_data[i];
      if(bm.indicator_timeframe != timeframe) continue;
      any = true;

      // Get timestamps based on entry_time (what the stored data should represent)
      // Find the shift for entry_time, then get timestamps for that shift and following ones
      int entry_shift = 0;
      for(int sh = 0; sh < 100; sh++)
      {
        if(iTime(_Symbol, timeframe, sh) == signal_params.entry_time)
        {
          entry_shift = sh;
          break;
        }
      }

      datetime time_0 = iTime(_Symbol, timeframe, entry_shift);     // entry_time candle
      datetime time_1 = iTime(_Symbol, timeframe, entry_shift + 1); // 1 candle before entry_time
      datetime time_2 = iTime(_Symbol, timeframe, entry_shift + 2); // 2 candles before entry_time
      datetime time_3 = iTime(_Symbol, timeframe, entry_shift + 3); // 3 candles before entry_time

      PrintFormat("▼ BodyMA[%d] (tf = %s)  (period = %d)", i, tf_str, bm.indicator_period);
      PrintFormat("  body_value:  [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(bm.body_value_0), TimeToString(time_0, TIME_MINUTES),
                  P(bm.body_value_1), TimeToString(time_1, TIME_MINUTES),
                  P(bm.body_value_2), TimeToString(time_2, TIME_MINUTES),
                  P(bm.body_value_3), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  body_ma:     [%s@%s, %s@%s, %s@%s, %s@%s]",
                  P(bm.body_ma_0), TimeToString(time_0, TIME_MINUTES),
                  P(bm.body_ma_1), TimeToString(time_1, TIME_MINUTES),
                  P(bm.body_ma_2), TimeToString(time_2, TIME_MINUTES),
                  P(bm.body_ma_3), TimeToString(time_3, TIME_MINUTES));
      PrintFormat("  body_trend:  [%s, %s, %s, %s]",
                  BodyTrendTypeToString(bm.body_trend_0),
                  BodyTrendTypeToString(bm.body_trend_1),
                  BodyTrendTypeToString(bm.body_trend_2),
                  BodyTrendTypeToString(bm.body_trend_3));
      PrintFormat("  body_ma_state:[%s, %s, %s, %s]",
                  BodyMATypeToString(bm.body_ma_state_0),
                  BodyMATypeToString(bm.body_ma_state_1),
                  BodyMATypeToString(bm.body_ma_state_2),
                  BodyMATypeToString(bm.body_ma_state_3));
      Print("  ────────────────────────────────────────────────────────────────────");

      ++printed;
      if (max_slots > 0 && printed >= max_slots) break;
    }
    if (!any) PrintFormat("BodyMA: <no data for TF=%s>", tf_str);
  }

  // StochasticMarketStructure
  {
    int printed = 0;
    bool any = false;
    for (int i = 0; i < n_struct; ++i)
    {
      const StochasticMarketStructure m = signal_params.stoch_market_structure_data[i];
      if(m.indicator_timeframe != timeframe) continue;
      any = true;

      PrintFormat("▼ StochMarketStructure[%d] (tf = %s)  (period = %d)", i, tf_str, m.indicator_period);
      PrintFormat("  types:  [%s, %s, %s, %s, %s, %s]",
                  OscillatorStructureTypesToString(m.first_structure_type),
                  OscillatorStructureTypesToString(m.second_structure_type),
                  OscillatorStructureTypesToString(m.third_structure_type),
                  OscillatorStructureTypesToString(m.fourth_structure_type),
                  OscillatorStructureTypesToString(m.fifth_structure_type),
                  OscillatorStructureTypesToString(m.six_structure_type));
      PrintFormat("  first:   time = %s  price = %s",
            DtToStr(m.first_structure_time),
            P(m.first_structure_price));
      PrintFormat("  second:  time = %s  price = %s",
                  DtToStr(m.second_structure_time),
                  P(m.second_structure_price));
      PrintFormat("  third:   time = %s  price = %s",
                  DtToStr(m.third_structure_time),
                  P(m.third_structure_price));
      PrintFormat("  fourth:  time = %s  price = %s",
                  DtToStr(m.fourth_structure_time),
                  P(m.fourth_structure_price));
      PrintFormat("  fibo:   first=%.2f  second=%.2f  third=%.2f  fourth=%.2f",
                  m.first_fibonacci_level, m.second_fibonacci_level, m.third_fibonacci_level, m.fourth_fibonacci_level);
      Print("  ────────────────────────────────────────────────────────────────────");

      ++printed;
      if (max_slots > 0 && printed >= max_slots) break;
    }
    if (!any) PrintFormat("StochMarketStructure: <no data for TF=%s>", tf_str);
  }

  // ExtremumStatistics (NEW - v1.10)
  {
    int printed = 0;
    bool any = false;
    for (int i = 0; i < n_struct; ++i)
    {
      const StochasticMarketStructure m = signal_params.stoch_market_structure_data[i];
      if(m.indicator_timeframe != timeframe) continue;

      int n_extrema = ArraySize(m.extremum_stats);
      if(n_extrema == 0) continue;

      any = true;

      PrintFormat("▼ ExtremumStatistics[%d] (tf = %s)  (period = %d)  [%d extrema]",
                  i, tf_str, m.indicator_period, n_extrema);

      // Log first 2 extrema (most recent)
      int max_log = MathMin(2, n_extrema);
      for(int j = 0; j < max_log; j++)
      {
        const ExtremumStatistics es = m.extremum_stats[j];
        string type_str = m.os_market_structures[j].is_peak ? "Peak" : "Bottom";
        double price = m.os_market_structures[j].is_peak ?
                       m.os_market_structures[j].extremum_high :
                       m.os_market_structures[j].extremum_low;

        PrintFormat("  [%d] %s @ %s (price=%.5f)",
                    es.extremum_index,
                    type_str,
                    DtToStr(m.os_market_structures[j].extremum_time),
                    price);
        PrintFormat("      INTERN: %.2f%% (ref=%.5f) %s",
                    es.intern_fibo_level,
                    es.intern_reference_price,
                    es.intern_is_extension ? "[EXTENSION]" : "");

        if(es.extern_is_active)
        {
          // Find timestamps of the reference extrema
          datetime ref_high_time = 0;
          datetime ref_low_time = 0;

          for(int k = 0; k < n_extrema; k++)
          {
            if(m.os_market_structures[k].is_peak &&
               MathAbs(m.os_market_structures[k].extremum_high - es.extern_oldest_high) < 0.00001)
            {
              ref_high_time = m.os_market_structures[k].extremum_time;
            }
            if(!m.os_market_structures[k].is_peak &&
               MathAbs(m.os_market_structures[k].extremum_low - es.extern_oldest_low) < 0.00001)
            {
              ref_low_time = m.os_market_structures[k].extremum_time;
            }
          }

          PrintFormat("      EXTERN: %.2f%% broken=%d [ACTIVE]",
                      es.extern_fibo_level,
                      es.extern_structures_broken);
          PrintFormat("             Range: H=%.5f @ %s",
                      es.extern_oldest_high,
                      ref_high_time > 0 ? DtToStr(ref_high_time) : "unknown");
          PrintFormat("                    L=%.5f @ %s",
                      es.extern_oldest_low,
                      ref_low_time > 0 ? DtToStr(ref_low_time) : "unknown");
        }

        PrintFormat("      Structure: %s",
                    OscillatorStructureTypesToString(es.structure_type));
        PrintFormat("      Retest Context: type=%s extern_active=%s extern_level=%.2f%% raw=%.2f%% price=%s",
                    type_str,
                    es.extern_is_active ? "true" : "false",
                    es.extern_fibo_level,
                    es.extern_fibo_raw_level,
                    P(price));

        for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
        {
          const RetestZoneStatistics zone = es.fibo_retest_zones[z];
          double display_start = zone.zone_start_level;
          double display_end   = zone.zone_end_level;

          if(zone.zone_price_low > 0.0 || zone.zone_price_high > 0.0)
          {
            string zone_state = zone.zone_hit ? "[HIT]" : "[MISS]";
            PrintFormat("      Retest Zone %d [%.1f%%, %.1f%%): %s %.5f → %.5f",
                        z + 1,
                        display_start,
                        display_end,
                        zone_state,
                        zone.zone_price_low,
                        zone.zone_price_high);
          }
          else
          {
            PrintFormat("      Retest Zone %d [%.1f%%, %.1f%%): <no range>",
                        z + 1,
                        display_start,
                        display_end);
          }

          string support_tag = zone.support_retest_trigger ? " (+)" : "";
          string resistance_tag = zone.resistance_retest_trigger ? " (+)" : "";

          string focus_side = m.os_market_structures[j].is_peak ? "resistance" : "support";
          PrintFormat("        Counts (%s focus): support=%d%s  resistance=%d%s",
                      focus_side,
                      zone.support_retest_count,
                      support_tag,
                      zone.resistance_retest_count,
                      resistance_tag);

          // MANUAL QA TESTING
          //if(zone.support_retest_count >= 3) TesterStop();
          //if(zone.resistance_retest_count >= 2) TesterStop();
        }
      }

      if(n_extrema > 2)
        PrintFormat("  ... and %d more extrema (showing first 2 only)", n_extrema - 2);

      Print("  ────────────────────────────────────────────────────────────────────");

      ++printed;
      if (max_slots > 0 && printed >= max_slots) break;
    }
    if (!any) PrintFormat("ExtremumStatistics: <no data for TF=%s>", tf_str);
  }

  Print("────────────────────────────────────────────────────────────────────────");
}

#endif // _MICROSERVICES_UTILS_LOGS_HELPER_MQH_
