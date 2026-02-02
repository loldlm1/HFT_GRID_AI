
bool TestDectectBullishRSIStructure(const double &highs[], const double &lows[], const double &indicator_values[])
{
  bool     valid_bullish_rsi_structure = false;
  bool     rsi_bottom_found            = false;
  bool     rsi_peak_found              = false;
  double   max_high                    = -DBL_MAX;
  double   finish_high                 = -DBL_MAX;
  double   entry_low                   = DBL_MAX;
  double   min_low                     = DBL_MAX;
  datetime entry_low_time              = 0;
  datetime min_low_time                = 0;
  datetime max_high_time               = 0;
  datetime finish_high_time            = 0;
  double   high_1                      = 0;
  double   low_1                       = 0;
  int      bottom_oscilation_count     = 0;
  int      peak_oscilation_count       = 0;


  for(int i = 1; i < 1300; i++)
  {
    // FETCH RSI STRUCTURE HIGHS/LOWS
    high_1 = highs[i];
    low_1  = lows[i];

    // DISCOVER THE REAL STRUCTURE BY OVERSOLD/BOUGHT (BOTTOM-PEAK-BOTTOM-PEAK)
    if(bottom_oscilation_count == 0 && low_1  < entry_low)   { entry_low   = low_1;  entry_low_time   = iTime(_Symbol, Timeframe_Signal, i); }
    if(bottom_oscilation_count == 1 && high_1 > max_high)    { max_high    = high_1; max_high_time    = iTime(_Symbol, Timeframe_Signal, i); }
    if(peak_oscilation_count   == 1 && low_1  < min_low)     { min_low     = low_1;  min_low_time     = iTime(_Symbol, Timeframe_Signal, i); }
    if(bottom_oscilation_count == 2 && high_1 > finish_high) { finish_high = high_1; finish_high_time = iTime(_Symbol, Timeframe_Signal, i); }

    // COMPLETING THE REAL STRUCTURE WHILE LOOKING OVERSOLD/BOUGHT
    if((bottom_oscilation_count == 1 && peak_oscilation_count   == 0) && low_1  < entry_low)   { entry_low   = low_1;  entry_low_time   = iTime(_Symbol, Timeframe_Signal, i); }
    if((peak_oscilation_count   == 1 && bottom_oscilation_count == 1) && high_1 > max_high)    { max_high    = high_1; max_high_time    = iTime(_Symbol, Timeframe_Signal, i); }
    if((bottom_oscilation_count == 2 && peak_oscilation_count   == 1) && low_1  < min_low)     { min_low     = low_1;  min_low_time     = iTime(_Symbol, Timeframe_Signal, i); }
    if((peak_oscilation_count   == 2 && bottom_oscilation_count == 2) && high_1 > finish_high) { finish_high = high_1; finish_high_time = iTime(_Symbol, Timeframe_Signal, i); }

    if(!rsi_bottom_found && indicator_values[i] <= 30) { bottom_oscilation_count += 1; rsi_bottom_found = true; rsi_peak_found   = false; }
    if(!rsi_peak_found   && indicator_values[i] >= 70) { peak_oscilation_count   += 1; rsi_peak_found   = true; rsi_bottom_found = false; }

    if(peak_oscilation_count >= 1 && bottom_oscilation_count == 0) break; // STOP IF WE FOUND A PEAK FIRST

    if(
      bottom_oscilation_count >= 3               &&
      max_high                > finish_high      &&
      entry_low_time          > max_high_time    &&
      max_high_time           > min_low_time     &&
      min_low_time            > finish_high_time
    ) {
      valid_bullish_rsi_structure = true;
      break;
    }

    if(bottom_oscilation_count >= 3) break; // STOP AFTER REACH 3RD BOTTOM AND FOUND NOTHING
  }

  Print(entry_low, " <<->> ", entry_low_time);
  Print(max_high, " <<->> ",max_high_time);
  Print(min_low, " <<->> ", min_low_time);
  Print(finish_high, " <<->> ",finish_high_time);

  return valid_bullish_rsi_structure;
}

bool TestDectectBearishRSIStructure(const double &highs[], const double &lows[], const double &indicator_values[])
{
  bool     valid_bearish_rsi_structure = false;
  bool     rsi_bottom_found            = false;
  bool     rsi_peak_found              = false;
  double   entry_high                  = -DBL_MAX;
  double   max_high                    = -DBL_MAX;
  double   min_low                     = DBL_MAX;
  double   finish_low                  = DBL_MAX;
  datetime entry_high_time             = 0;
  datetime min_low_time                = 0;
  datetime max_high_time               = 0;
  datetime finish_low_time             = 0;
  double   high_1                      = 0;
  double   low_1                       = 0;
  int      bottom_oscilation_count     = 0;
  int      peak_oscilation_count       = 0;

  for(int i = 1; i < 1300; i++)
  {
    // FETCH RSI STRUCTURE HIGHS/LOWS
    high_1 = highs[i];
    low_1  = lows[i];

    // DISCOVER THE REAL STRUCTURE BY OVERSOLD/BOUGHT (PEAK-BOTTOM-PEAK-BOTTOM)
    if(peak_oscilation_count   == 0 && high_1 > entry_high) { entry_high = high_1; entry_high_time = iTime(_Symbol, Timeframe_Signal, i); }
    if(peak_oscilation_count   == 1 && low_1  < min_low)    { min_low    = low_1;  min_low_time    = iTime(_Symbol, Timeframe_Signal, i); }
    if(bottom_oscilation_count == 1 && high_1 > max_high)   { max_high   = high_1; max_high_time   = iTime(_Symbol, Timeframe_Signal, i); }
    if(peak_oscilation_count   == 2 && low_1  < finish_low) { finish_low = low_1;  finish_low_time = iTime(_Symbol, Timeframe_Signal, i); }

    // COMPLETING THE REAL STRUCTURE WHILE LOOKING OVERSOLD/BOUGHT
    if((peak_oscilation_count   == 1 && bottom_oscilation_count == 0) && high_1 > entry_high) { entry_high = high_1; entry_high_time = iTime(_Symbol, Timeframe_Signal, i); }
    if((bottom_oscilation_count == 1 && peak_oscilation_count   == 1) && low_1  < min_low)    { min_low    = low_1;  min_low_time    = iTime(_Symbol, Timeframe_Signal, i); }
    if((peak_oscilation_count   == 2 && bottom_oscilation_count == 1) && high_1 > max_high)   { max_high   = high_1; max_high_time   = iTime(_Symbol, Timeframe_Signal, i); }
    if((bottom_oscilation_count == 2 && peak_oscilation_count   == 2) && low_1  < finish_low) { finish_low = low_1;  finish_low_time = iTime(_Symbol, Timeframe_Signal, i); }

    // AFTER REACH PEAK >= 1 WE COULD CHECK HIGHERS HIGH WHILE LOOKING FOR THE >= 1 BOTTOM

    if(!rsi_peak_found   && indicator_values[i] >= 70) { peak_oscilation_count   += 1; rsi_peak_found   = true; rsi_bottom_found = false; }
    if(!rsi_bottom_found && indicator_values[i] <= 30) { bottom_oscilation_count += 1; rsi_bottom_found = true; rsi_peak_found   = false; }

    if(bottom_oscilation_count >= 1 && peak_oscilation_count == 0) break; // STOP IF WE FOUND A BOTTOM FIRST

    if(
      peak_oscilation_count >= 3              &&
      min_low               < finish_low      &&
      entry_high_time       > min_low_time    &&
      min_low_time          > max_high_time   &&
      max_high_time         > finish_low_time
    ) {
      valid_bearish_rsi_structure = true;
      break;
    }

    if(peak_oscilation_count >= 3) break; // STOP AFTER REACH 3RD PEAK AND FOUND NOTHING
  }

  Print(entry_high, " <<->> ", entry_high_time);
  Print(min_low, " <<->> ",min_low_time);
  Print(max_high, " <<->> ", max_high_time);
  Print(finish_low, " <<->> ",finish_low_time);

  return valid_bearish_rsi_structure;
}

void GenerateFakeNormalRSIPeak(double &highs[], double &lows[], double &indicator_values[], double max_peak_price)
{
  int    total_values    = ArraySize(highs)-1;
  double base_price      = 1.150;
  double base_rsi        = 50;
  double base_price_plus = 0;
  double base_price_sub  = 0;
  double delta_rsi       = 0;

  if(total_values < 0) total_values = 0;

  for(int i = total_values; i < total_values+50; i++)
  {
    base_price_plus = base_price + double(MathRand() % 10 * 0.001); // Variación aleatoria 0.000..0.009
    base_price_sub  = base_price - double(MathRand() % 10 * 0.001); // Variación aleatoria 0.000..0.009
    delta_rsi       = base_rsi   + double(MathRand() % 20); // Variación aleatoria 0..19

    AddElementToArray(highs, base_price_plus);
    AddElementToArray(lows,  base_price_sub);
    AddElementToArray(indicator_values, delta_rsi);
  }

  // MOCKING NORMAL RSI PEAK DATA
  double normal_highs[]            = {1.155,1.158,max_peak_price,1.158,1.155};
  double normal_lows[]             = {1.155,1.154,1.153,1.154,1.155};
  double normal_indicator_values[] = {60.00,65.00,75.00,65.00,60.00};

  for(int i = 0; i < ArraySize(normal_highs); i++)
  {
    AddElementToArray(highs, normal_highs[i]);
    AddElementToArray(lows,  normal_lows[i]);
    AddElementToArray(indicator_values, normal_indicator_values[i]);
  }
}

void GenerateFakeNormalRSIBottom(double &highs[], double &lows[], double &indicator_values[], double min_bottom_price)
{
  int    total_values    = ArraySize(highs)-1;
  double base_price      = 1.150;
  double base_rsi        = 50;
  double base_price_plus = 0;
  double base_price_sub  = 0;
  double delta_rsi       = 0;

  if(total_values < 0) total_values = 0;

  for(int i = total_values; i < total_values+50; i++)
  {
    base_price_plus = base_price + double(MathRand() % 10 * 0.001); // Variación aleatoria 0.000..0.009
    base_price_sub  = base_price - double(MathRand() % 10 * 0.001); // Variación aleatoria 0.000..0.009
    delta_rsi       = base_rsi   - double(MathRand() % 20); // Variación aleatoria 0..19

    AddElementToArray(highs, base_price_plus);
    AddElementToArray(lows,  base_price_sub);
    AddElementToArray(indicator_values, delta_rsi);
  }

  // MOCKING NORMAL RSI PEAK DATA
  double normal_highs[]            = {1.155,1.156,1.157,1.156,1.155};
  double normal_lows[]             = {1.158,1.155,min_bottom_price,1.155,1.158};
  double normal_indicator_values[] = {40.00,35.00,25.00,35.00,40.00};

  for(int i = 0; i < ArraySize(normal_highs); i++)
  {
    AddElementToArray(highs, normal_highs[i]);
    AddElementToArray(lows,  normal_lows[i]);
    AddElementToArray(indicator_values, normal_indicator_values[i]);
  }
}

void RunBullishRSITests()
{
  // (BOTTOM-PEAK-BOTTOM-PEAK) - (BASE PRICE 1.150)
  double max_peak_price   = 1.170;
  double min_bottom_price = 1.130;
  bool   result           = false;
  double highs[];
  double lows[];
  double indicator_values[];

  Print("Caso 1: [BULLISH] Estructura alcista válida completa (BOTTOM → PEAK → BOTTOM → PEAK)");
  // 1ST (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // ENTRY LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price + 0.010); // MAX HIGH

  // 2ND (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // MIN LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // FINISH HIGH

  // 3RD (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);

  result = TestDectectBullishRSIStructure(highs, lows, indicator_values);
  if(result)  Print("Caso 1: [BULLISH] Paso con exito!");
  if(!result) Print("Caso 1: [BULLISH] Ha fallado...");

  Print("Caso 2: [BULLISH] Estructura alcista con altos mas altos y bajos mas bajos válida completa (BOTTOM → PEAK → PEAK → BOTTOM → BOTTOM → PEAK)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // ENTRY LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price + 0.010); // MAX HIGH
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price + 0.030); // MAX/MAX HIGH

  // 2ND (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, NormalizeDouble(min_bottom_price - 0.010, 3)); // MIN LOW
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, NormalizeDouble(min_bottom_price - 0.030, 3)); // MIN/MIN LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // FINISH HIGH

  // 3RD (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);

  result = TestDectectBullishRSIStructure(highs, lows, indicator_values);
  if(result)  Print("Caso 2: [BULLISH] Paso con exito!");
  if(!result) Print("Caso 2: [BULLISH] Ha fallado...");

  Print("Caso 3: [BULLISH] Estructura inválida consiguiendo peak al inicio (PEAK → BOTTOM)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // MAX HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // ENTRY LOW

  result = TestDectectBullishRSIStructure(highs, lows, indicator_values);
  if(!result) Print("Caso 3: [BULLISH] Paso con exito!");
  if(result)  Print("Caso 3: [BULLISH] Ha fallado...");

  Print("Caso 4: [BULLISH] Estructura alcista inválida MAX HIGH <= FINISH HIGH (BOTTOM → PEAK → BOTTOM → PEAK)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // ENTRY LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // MAX HIGH

  // 2ND (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // MIN LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // FINISH HIGH

  // 3RD (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);

  result = TestDectectBullishRSIStructure(highs, lows, indicator_values);
  if(!result) Print("Caso 4: [BULLISH] Paso con exito!");
  if(result)  Print("Caso 4: [BULLISH] Ha fallado...");
}

void RunBearishRSITests()
{
  // (PEAK-BOTTOM-PEAK-BOTTOM) - (BASE PRICE 1.150)
  double max_peak_price   = 1.170;
  double min_bottom_price = 1.130;
  bool   result           = false;
  double highs[];
  double lows[];
  double indicator_values[];

  Print("Caso 1: [BEARISH] Estructura bajista válida completa (PEAK → BOTTOM → PEAK → BOTTOM)");
  // 1ST (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // ENTRY HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, NormalizeDouble(min_bottom_price - 0.010, 3)); // MIN LOW

  // 2ND (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // MAX HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // FINISH LOW

  // 3RD (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);

  result = TestDectectBearishRSIStructure(highs, lows, indicator_values);
  if(result)  Print("Caso 1: [BEARISH] Paso con exito!");
  if(!result) Print("Caso 1: [BEARISH] Ha fallado...");

  Print("Caso 2: [BEARISH] Estructura bajista con bajos mas bajos y altos mas altos válida completa (PEAK → BOTTOM → BOTTOM → PEAK → PEAK → BOTTOM)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // ENTRY HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, NormalizeDouble(min_bottom_price - 0.010, 3)); // MIN LOW
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, NormalizeDouble(min_bottom_price - 0.030, 3)); // MIN LOW

  // 2ND (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price + 0.010); // MAX HIGH
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price + 0.030); // MAX HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // FINISH LOW

  // 3RD (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);

  result = TestDectectBearishRSIStructure(highs, lows, indicator_values);
  if(result)  Print("Caso 2: [BEARISH] Paso con exito!");
  if(!result) Print("Caso 2: [BEARISH] Ha fallado...");

  Print("Caso 3: [BEARISH] Estructura inválida consiguiendo bottom al inicio (BOTTOM → PEAK)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (BOTTOM-PEAK)
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // ENTRY LOW
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // MAX HIGH

  result = TestDectectBearishRSIStructure(highs, lows, indicator_values);
  if(!result) Print("Caso 3: [BEARISH] Paso con exito!");
  if(result)  Print("Caso 3: [BEARISH] Ha fallado...");

  Print("Caso 4: [BEARISH] Estructura bajista inválida MIN LOW >= FINISH LOW (PEAK → BOTTOM → PEAK → BOTTOM)");
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  ArrayResize(indicator_values, 0);

  // 1ST (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // ENTRY HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // MIN LOW

  // 2ND (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price); // MAX HIGH
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price); // FINISH LOW

  // 3RD (PEAK-BOTTOM)
  GenerateFakeNormalRSIPeak(highs, lows, indicator_values, max_peak_price);
  GenerateFakeNormalRSIBottom(highs, lows, indicator_values, min_bottom_price);

  result = TestDectectBearishRSIStructure(highs, lows, indicator_values);
  if(result)  Print("Caso 4: [BEARISH] Paso con exito!");
  if(!result) Print("Caso 4: [BEARISH] Ha fallado...");
}
