
//+------------------------------------------------------------------+
//|                                       market_signal_dectector.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];

const double BANDS_PERCENT_MID_LEVEL   = 50.0;
const double BANDS_PERCENT_UPPER_LEVEL = 100.0;
const double BANDS_PERCENT_LOWER_LEVEL = 0.0;
const int    BANDS_PERCENT_SHIFT_DEPTH = 5;

// ++ HELPER FUNCTION TO CALCULATE CORRECT SHIFT BASED ON ENTRY TIME ++

void DetectBullishSignal()
{
  if(!CanAttemptSignal(BULLISH)) return;

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

  if(!EvaluateSignalTrigger(signal_bullish, BULLISH))
    return;

  if(!BuildGridOrderForSignal(signal_bullish))
  {
    Print("Grid plan failed for bullish signal, aborting detection.");
    return;
  }
  // unified planner seeds level 0; no separate initializer

  // OPEN THE BULLISH SIGNAL TO THE MARKET
  // ...

  // ADD THE BULLISH SIGNAL TO THE ARRAY
  AddElementToArray(running_bullish_signals, signal_bullish);
}

void DetectBearishSignal()
{
  if(!CanAttemptSignal(BEARISH)) return;

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

  if(!EvaluateSignalTrigger(signal_bearish, BEARISH))
    return;

  if(!BuildGridOrderForSignal(signal_bearish))
  {
    Print("Grid plan failed for bearish signal, aborting detection.");
    return;
  }
  // unified planner seeds level 0; no separate initializer

  // OPEN THE BEARISH SIGNAL TO THE MARKET
  // ...

  // ADD THE BEARISH SIGNAL TO THE ARRAY
  AddElementToArray(running_bearish_signals, signal_bearish);
}

// ++ CLOSE THE SIGNALS ++

void CloseBullishSignal(SignalParams &signal_bullish)
{
  signal_bullish.signal_state = CLOSED;
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bullish);
  //if(Enable_Logs) LogSignalParamsForTF(signal_bullish, PERIOD_M1);

  // MANAGE THE BULLISH SIGNAL STATE
  // if(signal_bullish.signal_state == OPENED) { ... }
}

void CloseBearishSignal(SignalParams &signal_bearish)
{
  signal_bearish.signal_state = CLOSED;
  long chart_id = ChartID();
  RemoveGridLevels(chart_id, signal_bearish);
  //if(Enable_Logs) LogSignalParamsForTF(signal_bearish, PERIOD_M1);

  // MANAGE THE BULLISH SIGNAL STATE
  // if(signal_bearish.signal_state == OPENED) { ... }
}

void RemoveGridLevels(const long chart_id,
                      const SignalParams &signal_params)
{
  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string final_name = GridSignalObjectName(signal_params, "TP_FINAL");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");
  string trailing_name = GridSignalObjectName(signal_params, "TP_TRAILING");

  ObjectDelete(chart_id, stop_name);
  ObjectDelete(chart_id, tp_name);
  ObjectDelete(chart_id, final_name);
  ObjectDelete(chart_id, entry_name);
  ObjectDelete(chart_id, next_name);
  ObjectDelete(chart_id, trailing_name);
}

// SET THE INDICATOR DATA TO THE SIGNAL PARAMS STRUCTURE

void SetTFBandsPercentDataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Bands Percent indicator handle in ExtBPercentIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtBPercentIndicatorsHandle); i++)
  {
    BandsPercentStructure bands_percent_data;
    bands_percent_data = BandsPercentStructure();
    bands_percent_data.InitBandsPercentStructureValues(ExtBPercentIndicatorsHandle[i], 0);

    AddElementToArray(signal_params.bands_percent_data, bands_percent_data);
  }
}

void SetTFStochasticDataToSignalParams(SignalParams &signal_params)
{
  // Iterate over each timeframe's Stochastic indicator handle in ExtStochIndicatorsHandle
  for(int i = 0; i < ArraySize(ExtStochIndicatorsHandle); i++)
  {
    StochasticStructure stochastic_data;
    stochastic_data = StochasticStructure();
    stochastic_data.InitStochasticStructureValues(ExtStochIndicatorsHandle[i], 0);

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
    BodyMAStructure body_ma_data;
    body_ma_data = BodyMAStructure();
    body_ma_data.InitBodyMAStructureValues(ExtBodyMAIndicatorsHandle[i], 0);

    AddElementToArray(signal_params.body_ma_data, body_ma_data);
  }
}

// ++ HELPER FUNCTIONS FOR SIGNAL DECISIONS ++

bool CanAttemptSignal(const SignalTypes signal_type)
{
  bool use_base_indicator  = (Base_Indicator_Percent > 0.0);
  bool use_solid_indicator = (Solid_Indicator_Strategy_Type != SOLID_NONE_TYPE);
  bool structure_filters_enabled =
    (Min_Extern_Structures_Broken > 0) ||
    (FiboZone1_Support_Retest_Min > 0) ||
    (FiboZone1_Resistance_Retest_Min > 0) ||
    (FiboZone2_Support_Retest_Min > 0) ||
    (FiboZone2_Resistance_Retest_Min > 0);
  bool require_structure_data = (Solid_Indicator_Strategy_Type == EXTREMA_TYPE) || structure_filters_enabled;

  if(Strategy_Direction_Mode == BULLISH_DIRECTION && signal_type == BEARISH)
  {
    return false;
  }
  if(Strategy_Direction_Mode == BEARISH_DIRECTION && signal_type == BULLISH)
  {
    return false;
  }

  if(signal_type == BULLISH && ArraySize(running_bullish_signals) >= 1)
    return false;
  if(signal_type == BEARISH && ArraySize(running_bearish_signals) >= 1)
    return false;

  if(use_base_indicator && ArraySize(ExtBPercentIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStochIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStructStochIndicatorsHandle) <= 0)
    return false;

  if(!use_base_indicator && !use_solid_indicator)
    return false;


  return true;
}

bool ValidateBandsPercentBreakout(const double &shift_values[], const SignalTypes signal_type)
{
  double zone_start = Base_Indicator_Percent;
  double zone_end   = Base_Indicator_Percent;

  if(signal_type == BULLISH) { zone_start = 100-Base_Indicator_Percent; zone_end = zone_start - 20.0; }
  if(signal_type == BEARISH) { zone_start = Base_Indicator_Percent; zone_end = zone_start + 20.0; }

  bool has_origin   = false;
  bool in_the_zone  = false;
  bool crossed_zone = false;

  for(int i = 0; i < BANDS_PERCENT_SHIFT_DEPTH; i++)
  {
    double shift_value = shift_values[i];

    if(signal_type == BULLISH)
    {
      if(shift_value >= zone_start) has_origin   = true;
      if(shift_value <= zone_start) in_the_zone  = true;
      if(shift_value <  zone_end)   crossed_zone = true;
    }
    if(signal_type == BEARISH)
    {
      if(shift_value <= zone_start) has_origin   = true;
      if(shift_value >= zone_start) in_the_zone  = true;
      if(shift_value > zone_end)    crossed_zone = true;
    }
  }

  return has_origin && in_the_zone && !crossed_zone;
}

bool EvaluateBaseIndicatorTrigger(const SignalParams &signal_params, const SignalTypes signal_type)
{
  if(Base_Indicator_Percent <= 0.0)
    return true;

  int total_entries = ArraySize(signal_params.bands_percent_data);
  if(total_entries <= 0)
    return false;

  BandsPercentStructure bands_data = signal_params.bands_percent_data[0];
  double shift_values[];
  ArrayResize(shift_values, BANDS_PERCENT_SHIFT_DEPTH);
  shift_values[0] = bands_data.bands_percent_1;
  shift_values[1] = bands_data.bands_percent_2;
  shift_values[2] = bands_data.bands_percent_3;
  shift_values[3] = bands_data.bands_percent_4;
  shift_values[4] = bands_data.bands_percent_5;

  return ValidateBandsPercentBreakout(shift_values, signal_type);
}

int GetZoneRetestRequirement(const SignalTypes signal_type, const int zone_index)
{
  switch(zone_index)
  {
    case 0:
      if(signal_type == BULLISH)
        return FiboZone1_Support_Retest_Min;
      return FiboZone1_Resistance_Retest_Min;
    case 1:
      if(signal_type == BULLISH)
        return FiboZone2_Support_Retest_Min;
      return FiboZone2_Resistance_Retest_Min;
  }
  return 0;
}

bool ValidateExternStructuresRequirement(const ExtremumStatistics &latest_stats)
{
  if(Min_Extern_Structures_Broken <= 0)
    return true;
  return latest_stats.extern_structures_broken >= Min_Extern_Structures_Broken;
}

bool ValidateRetestRequirements(const ExtremumStatistics &latest_stats, const SignalTypes signal_type)
{
  for(int zone_index = 0; zone_index < FIBO_RETEST_ZONES_TOTAL; zone_index++)
  {
    int required = GetZoneRetestRequirement(signal_type, zone_index);
    if(required <= 0)
      continue;

    int available = 0;
    if(signal_type == BULLISH)
      available = latest_stats.fibo_retest_zones[zone_index].support_retest_count;
    if(signal_type == BEARISH)
      available = latest_stats.fibo_retest_zones[zone_index].resistance_retest_count;

    if(available < required)
      return false;
  }

  return true;
}

bool EvaluateSolidIndicatorTrigger(const SignalParams &signal_params, const SignalTypes signal_type)
{
  if(Solid_Indicator_Strategy_Type == SOLID_NONE_TYPE)
    return true;

  int total_structures = ArraySize(signal_params.stoch_market_structure_data);
  if(total_structures <= 0)
    return false;

  StochasticMarketStructure structure       = signal_params.stoch_market_structure_data[0];
  OscillatorMarketStructure latest_extremum = structure.os_market_structures[0];

  if(signal_type == BULLISH)
  {
    return (
      structure.first_structure_type == OSCILLATOR_STRUCTURE_LH ||
      structure.first_structure_type == OSCILLATOR_STRUCTURE_LL
    );
  }
  if(signal_type == BEARISH)
  {
    return (
      structure.first_structure_type == OSCILLATOR_STRUCTURE_HL ||
      structure.first_structure_type == OSCILLATOR_STRUCTURE_HH
    );
  }

  return latest_extremum.is_peak;
}

bool EvaluateStructureRetestTrigger(const SignalParams &signal_params, const SignalTypes signal_type)
{
  bool filters_requested =
    (Min_Extern_Structures_Broken > 0) ||
    (FiboZone1_Support_Retest_Min > 0) ||
    (FiboZone1_Resistance_Retest_Min > 0) ||
    (FiboZone2_Support_Retest_Min > 0) ||
    (FiboZone2_Resistance_Retest_Min > 0);

  if(!filters_requested)
    return true;

  int total_structures = ArraySize(signal_params.stoch_market_structure_data);
  if(total_structures <= 0)
    return false;

  StochasticMarketStructure structure    = signal_params.stoch_market_structure_data[0];
  ExtremumStatistics        latest_stats = structure.extremum_stats[0];

  if(!ValidateExternStructuresRequirement(latest_stats))
    return false;

  if(!ValidateRetestRequirements(latest_stats, signal_type))
    return false;

  return true;
}

bool EvaluateSignalTrigger(const SignalParams &signal_params, const SignalTypes signal_type)
{
  bool base_trigger      = EvaluateBaseIndicatorTrigger(signal_params, signal_type);
  bool solid_trigger     = EvaluateSolidIndicatorTrigger(signal_params, signal_type);
  bool structure_filters = EvaluateStructureRetestTrigger(signal_params, signal_type);

  return base_trigger && solid_trigger && structure_filters;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
