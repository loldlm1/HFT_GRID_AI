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

// ── Logger filtrado por timeframe ───────────────────────────────────────

void LogSignalParamsForTF(const SignalParams &signal_params,
                          const ENUM_TIMEFRAMES timeframe,
                          const int max_slots = -1)
{
  const string tf_str = TimeframeToString(timeframe);

  const int n_bands  = ArraySize(signal_params.bands_percent_data);
  const int n_stoch  = ArraySize(signal_params.stochastic_data);
  const int n_struct = ArraySize(signal_params.stoch_market_structure_data);

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
  PrintFormat(" arrays: bands=%d  stochastic=%d  stoch_struct=%d",
              n_bands, n_stoch, n_struct);
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

      PrintFormat("▼ Bands[%d] (tf = %s)  (period = %d)", i, tf_str, b.indicator_period);
      PrintFormat("  values:      [%s, %s, %s, %s]",
                  P(b.bands_percent_0, 2), P(b.bands_percent_1, 2),
                  P(b.bands_percent_2, 2), P(b.bands_percent_3, 2));
      PrintFormat("  signals:     [%s, %s, %s, %s]",
                  P(b.bands_percent_signal_0, 2), P(b.bands_percent_signal_1, 2),
                  P(b.bands_percent_signal_2, 2), P(b.bands_percent_signal_3, 2));
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

      PrintFormat("▼ Stochastic[%d] (tf = %s)  (period = %d)", i, tf_str, s.indicator_period);
      PrintFormat("  values:      [%s, %s, %s, %s]",
                  P(s.stochastic_0, 2), P(s.stochastic_1, 2),
                  P(s.stochastic_2, 2), P(s.stochastic_3, 2));
      PrintFormat("  signals:     [%s, %s, %s, %s]",
                  P(s.stochastic_signal_0, 2), P(s.stochastic_signal_1, 2),
                  P(s.stochastic_signal_2, 2), P(s.stochastic_signal_3, 2));
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

  Print("────────────────────────────────────────────────────────────────────────");
}
