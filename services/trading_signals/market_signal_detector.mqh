
//+------------------------------------------------------------------+
//|                                       market_signal_dectector.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];
datetime g_last_base_structure_time[2]  = {0, 0};
datetime g_last_trend_structure_time[2] = {0, 0};

struct DailySignalStats
{
  datetime day_start;
  int total_signals;
  int losing_signals;

  DailySignalStats()
  {
    day_start      = 0;
    total_signals  = 0;
    losing_signals = 0;
  }
};

DailySignalStats g_daily_signal_stats[2];

const double BANDS_PERCENT_MID_LEVEL   = 50.0;
const double BANDS_PERCENT_UPPER_LEVEL = 100.0;
const double BANDS_PERCENT_LOWER_LEVEL = 0.0;
const int    BANDS_PERCENT_SHIFT_DEPTH = 5;

void DebugForceCloseAllGrids()
{
  double point_size = GridResolvePointSize();

  int bullish_total = ArraySize(running_bullish_signals);
  for(int i = 0; i < bullish_total; i++)
    GridCloseAllLevels(running_bullish_signals[i], point_size);

  int bearish_total = ArraySize(running_bearish_signals);
  for(int j = 0; j < bearish_total; j++)
    GridCloseAllLevels(running_bearish_signals[j], point_size);
}

datetime ResolveCurrentDayStart()
{
  datetime day = iTime(_Symbol, PERIOD_D1, 0);
  if(day <= 0)
  {
    datetime now = TimeCurrent();
    day = (datetime)((long)now - ((long)now % 86400));
  }
  return day;
}

void DailySignalStatsEnsureDay(const SignalTypes direction)
{
  int idx = DirectionIndex(direction);
  datetime day = ResolveCurrentDayStart();
  if(g_daily_signal_stats[idx].day_start != day)
  {
    g_daily_signal_stats[idx].day_start      = day;
    g_daily_signal_stats[idx].total_signals  = 0;
    g_daily_signal_stats[idx].losing_signals = 0;
  }
}

bool DailySignalLimitAllowsAttempt(const SignalTypes direction)
{
  if(Daily_Signal_Limit <= 0)
    return true;

  DailySignalStatsEnsureDay(direction);
  DailySignalStats stats = g_daily_signal_stats[DirectionIndex(direction)];

  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS_ON_LOSS)
    return stats.losing_signals < Daily_Signal_Limit;

  return stats.total_signals < Daily_Signal_Limit;
}

void RegisterDailySignalStart(const SignalParams &signal_params)
{
  if(Daily_Signal_Limit <= 0)
    return;

  DailySignalStatsEnsureDay(signal_params.signal_type);

  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS)
    g_daily_signal_stats[DirectionIndex(signal_params.signal_type)].total_signals++;
}

void RegisterDailySignalOutcome(const SignalTypes direction,
                                const double raw_profit)
{
  if(Daily_Signal_Limit <= 0)
    return;

  if(Daily_Signal_Limit_Mode != STOP_DAILY_SIGNALS_ON_LOSS)
    return;

  DailySignalStatsEnsureDay(direction);
  if(raw_profit < 0.0)
    g_daily_signal_stats[DirectionIndex(direction)].losing_signals++;
}

bool TrendStructureFiltersRequested()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  return StructureFiltersRequested(trend_ctx);
}

bool TrendStructureTypeFiltersRequested()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  return StructureTypeFiltersRequested(trend_ctx);
}

bool TrendStructureDataRequired()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  if(!trend_ctx.enabled)
    return false;
  bool needs_data = StructureFiltersRequested(trend_ctx) ||
                    StructureTypeFiltersRequested(trend_ctx) ||
                    Trend_Fresh_Structure_Time;
  if(!needs_data)
    return false;
  return trend_ctx.uses_trend_dataset;
}
// ++ HELPER FUNCTION TO CALCULATE CORRECT SHIFT BASED ON ENTRY TIME ++

bool TrendSanityCheck(const string reason)
{
  if(!Enable_Trend_Filter_Sanity_Stop)
    return true;

  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  Print("Trend sanity check triggered: ", reason);
  TesterStop();
  return false;
}

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
  SetTFAlligatorDataToSignalParams(signal_bullish);
  SetTFStochasticDataToSignalParams(signal_bullish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bullish);
  SetTFBodyMADataToSignalParams(signal_bullish);

  if(!LoadTrendStructureData(signal_bullish))
    return;

  if(!EvaluateSignalTrigger(signal_bullish, BULLISH))
    return;

  if(!LoadTrendFilterData(signal_bullish))
    return;
  if(!TrendFilterAllowsSignal(signal_bullish, BULLISH))
  {
    if(Enable_Logs)
      Print("Trend filter blocked bullish signal.");
    return;
  }

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
  RegisterFreshStructureUsage(signal_bullish);
  RegisterDailySignalStart(signal_bullish);
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
  SetTFAlligatorDataToSignalParams(signal_bearish);
  SetTFStochasticDataToSignalParams(signal_bearish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bearish);
  SetTFBodyMADataToSignalParams(signal_bearish);

  if(!LoadTrendStructureData(signal_bearish))
    return;

  if(!EvaluateSignalTrigger(signal_bearish, BEARISH))
    return;

  if(!LoadTrendFilterData(signal_bearish))
    return;
  if(!TrendFilterAllowsSignal(signal_bearish, BEARISH))
  {
    if(Enable_Logs)
      Print("Trend filter blocked bearish signal.");
    return;
  }

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
  RegisterFreshStructureUsage(signal_bearish);
  RegisterDailySignalStart(signal_bearish);
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

void SetTFAlligatorDataToSignalParams(SignalParams &signal_params)
{
  int jaws_period  = MathMax(Base_Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax(Base_Alligator_Lips_Period, 1);

  for(int i = 0; i < ArraySize(ExtAlligatorIndicatorsHandle); i++)
  {
    AlligatorStructure alligator_data;
    alligator_data = AlligatorStructure();
    if(!alligator_data.InitAlligatorStructureValues(ExtAlligatorIndicatorsHandle[i],
                                                    0,
                                                    jaws_period,
                                                    teeth_period,
                                                    lips_period))
    {
      if(Enable_Logs)
        Print("Failed to initialize base Alligator data for timeframe: ",
              EnumToString(ExtAlligatorIndicatorsHandle[i].indicator_timeframe));
      continue;
    }
    AddElementToArray(signal_params.alligator_data, alligator_data);
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

bool LoadTrendFilterData(SignalParams &signal_params)
{
  if(!TrendContextEnabled() || Strategy_Trend_Mode == TREND_OFF)
  {
    signal_params.trend_filter_mode    = TREND_OFF;
    signal_params.trend_bpercent_valid = false;
    signal_params.trend_alligator_valid = false;
    signal_params.trend_stochastic_valid = false;
    return true;
  }

  signal_params.trend_filter_mode    = Strategy_Trend_Mode;
  signal_params.trend_bpercent_valid = false;
  signal_params.trend_alligator_valid = false;
  signal_params.trend_stochastic_valid = false;

  bool require_bpercent   = (Strategy_Trend_Mode == TREND_BPERCENT || Strategy_Trend_Mode == TREND_BOTH);
  bool require_alligator  = (Strategy_Trend_Mode == TREND_ALLIGATOR || Strategy_Trend_Mode == TREND_BOTH);
  bool slope_bpercent     = Trend_BPercent_Slope_Filter;
  bool slope_alligator    = Trend_Alligator_Slope_Filter;

  if(require_bpercent || slope_bpercent)
  {
    if(TrendBPercentIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend Bollinger Percent indicator unavailable.");
      return false;
    }

    signal_params.trend_bpercent_data = BandsPercentStructure();
    signal_params.trend_bpercent_data.InitBandsPercentStructureValues(TrendBPercentIndicatorHandle, 0);
    signal_params.trend_bpercent_valid = true;
  }

  if(require_alligator || slope_alligator)
  {
    if(TrendAlligatorIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend Alligator indicator unavailable.");
      return false;
    }

    int jaws_period  = MathMax(Trend_Alligator_Jaws_Period, 1);
    int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
    int lips_period  = MathMax(Trend_Alligator_Lips_Period, 1);

    signal_params.trend_alligator_data = AlligatorStructure();
    if(!signal_params.trend_alligator_data.InitAlligatorStructureValues(TrendAlligatorIndicatorHandle,
                                                                        0,
                                                                        jaws_period,
                                                                        teeth_period,
                                                                        lips_period))
    {
      if(Enable_Logs)
        Print("Trend Alligator data initialization failed.");
      return false;
    }
    signal_params.trend_alligator_valid = true;
  }

  if(Trend_Stochastic_Slope_Filter)
  {
    if(TrendStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend stochastic indicator unavailable.");
      return false;
    }
    signal_params.trend_stochastic_data = StochasticStructure();
    signal_params.trend_stochastic_data.InitStochasticStructureValues(TrendStochIndicatorHandle, 0);
    signal_params.trend_stochastic_valid = true;
  }

  return true;
}

bool TrendFilterAllowsSignal(const SignalParams &signal_params,
                             const SignalTypes direction)
{
  if(!TrendContextEnabled() || signal_params.trend_filter_mode == TREND_OFF)
    return true;
  bool filter_ok = true;

  if(signal_params.trend_filter_mode == TREND_BPERCENT)
  {
    if(Trend_Indicator_Percent < 0.0)
      filter_ok = true;
    else
    {
      if(!signal_params.trend_bpercent_valid)
        return false;
      filter_ok = EvaluateBandsPercentTrigger(signal_params.trend_bpercent_data,
                                              direction,
                                              Trend_Indicator_Percent,
                                              NO_SLOPE);
    }
  }
  else if(signal_params.trend_filter_mode == TREND_ALLIGATOR)
  {
    if(!signal_params.trend_alligator_valid)
      return false;
    filter_ok = EvaluateAlligatorTrend(signal_params.trend_alligator_data, direction);
  }
  else if(signal_params.trend_filter_mode == TREND_BOTH)
  {
    bool percent_ok = true;
    if(Trend_Indicator_Percent >= 0.0)
    {
      if(!signal_params.trend_bpercent_valid)
        return false;
      percent_ok = EvaluateBandsPercentTrigger(signal_params.trend_bpercent_data,
                                               direction,
                                               Trend_Indicator_Percent,
                                               NO_SLOPE);
    }

    if(!signal_params.trend_alligator_valid)
      return false;

    bool alligator_ok = EvaluateAlligatorTrend(signal_params.trend_alligator_data, direction);
    filter_ok = percent_ok && alligator_ok;
  }

  if(!filter_ok)
    return false;

  if(Trend_BPercent_Slope_Filter)
  {
    if(!signal_params.trend_bpercent_valid)
      return false;
    double current = signal_params.trend_bpercent_data.bands_percent_0;
    double previous = signal_params.trend_bpercent_data.bands_percent_1;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  if(Trend_Stochastic_Slope_Filter)
  {
    if(!signal_params.trend_stochastic_valid)
      return false;

    double current = signal_params.trend_stochastic_data.stochastic_0;
    double previous = signal_params.trend_stochastic_data.stochastic_1;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  if(Trend_Alligator_Slope_Filter)
  {
    if(!signal_params.trend_alligator_valid)
      return false;
    double current = signal_params.trend_alligator_data.lips_value;
    double previous = signal_params.trend_alligator_data.lips_prev_value;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  return true;
}

bool LoadTrendStructureData(SignalParams &signal_params)
{
  signal_params.trend_structure_valid = false;

  if(!TrendStructureDataRequired())
    return true;

  if(TrendStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
  {
    if(Enable_Logs)
      Print("Trend structure indicator unavailable.");
    return false;
  }

  signal_params.trend_structure_data = StochasticMarketStructure();
  if(!signal_params.trend_structure_data.InitStochMarketStructureValues(TrendStructStochIndicatorHandle))
  {
    if(Enable_Logs)
      Print("Trend structure data initialization failed.");
    return false;
  }

  signal_params.trend_structure_valid = true;
  return true;
}

// ++ HELPER FUNCTIONS FOR SIGNAL DECISIONS ++

bool CanAttemptSignal(const SignalTypes signal_type)
{
  if(!ProtectionRiskAllowsSignalAttempt())
    return false;
  if(!TrendFilterIndicatorsAvailable())
    return false;

  if(Debug_Stop_On_Negative_Equity && MQLInfoInteger(MQL_TESTER) > 0)
  {
    if(g_debug_no_money_abort_pending)
    {
      g_debug_no_money_abort_pending = false;
      Print("TesterStop triggered: order send rejected due to insufficient funds while Debug_Stop_On_Negative_Equity is enabled.");
      DebugForceCloseAllGrids();
      TesterStop();
      return false;
    }

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity <= 0.0)
    {
      Print("TesterStop triggered: equity <= 0 and Debug_Stop_On_Negative_Equity is enabled.");
      DebugForceCloseAllGrids();
      TesterStop();
      return false;
    }
  }

  if(!DailySignalLimitAllowsAttempt(signal_type))
  {
    if(Enable_Logs)
      Print("Daily signal limit reached for direction: ", EnumToString(signal_type));
    return false;
  }

  bool base_mode_uses_bpercent  = (Strategy_Base_Mode == TREND_BPERCENT || Strategy_Base_Mode == TREND_BOTH);
  bool base_mode_uses_alligator = (Strategy_Base_Mode == TREND_ALLIGATOR || Strategy_Base_Mode == TREND_BOTH);
  bool base_bpercent_active     = base_mode_uses_bpercent && (Base_Indicator_Percent > 0.0);
  bool require_structure_data = true;

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

  if(base_bpercent_active && ArraySize(ExtBPercentIndicatorsHandle) <= 0)
    return false;

  if(base_mode_uses_alligator && ArraySize(ExtAlligatorIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStochIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStructStochIndicatorsHandle) <= 0)
    return false;

  if(TrendStructureDataRequired())
  {
    if(TrendStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
      return false;
  }


  return true;
}

bool ValidateBandsPercentBreakout(const double &shift_values[],
                                  const SignalTypes signal_type,
                                  const double percent_threshold)
{
  double zone_start = percent_threshold;
  double zone_end   = percent_threshold;

  if(signal_type == BULLISH) { zone_start = 100 - percent_threshold; zone_end = zone_start - 20.0; }
  if(signal_type == BEARISH) { zone_start = percent_threshold; zone_end = zone_start + 20.0; }

  bool has_origin   = false;
  bool in_the_zone  = signal_type == BULLISH ? shift_values[0] <= zone_start : shift_values[0] >= zone_start;
  bool crossed_zone = false;

  for(int i = 0; i < BANDS_PERCENT_SHIFT_DEPTH; i++)
  {
    double shift_value = shift_values[i];

    if(signal_type == BULLISH)
    {
      if(shift_value >= zone_start) has_origin   = true;
      if(shift_value <  zone_end)   crossed_zone = true;
    }
    if(signal_type == BEARISH)
    {
      if(shift_value <= zone_start) has_origin   = true;
      if(shift_value > zone_end)    crossed_zone = true;
    }
  }

  return has_origin && in_the_zone && !crossed_zone;
}

bool EvaluateBandsPercentTrigger(const BandsPercentStructure &bands_data,
                                 const SignalTypes signal_type,
                                 const double percent_threshold,
                                 const SlopeTypes slope_filter)
{
  double shift_values[];
  ArrayResize(shift_values, BANDS_PERCENT_SHIFT_DEPTH);
  shift_values[0] = bands_data.bands_percent_1;
  shift_values[1] = bands_data.bands_percent_2;
  shift_values[2] = bands_data.bands_percent_3;
  shift_values[3] = bands_data.bands_percent_4;
  shift_values[4] = bands_data.bands_percent_5;

  bool breakout = ValidateBandsPercentBreakout(shift_values, signal_type, percent_threshold);
  if(!breakout)
    return false;

  if(slope_filter == NO_SLOPE)
    return true;

  return (bands_data.bands_percent_slope_1 == slope_filter);
}

bool EvaluateAlligatorTrend(const AlligatorStructure &alligator_data,
                            const SignalTypes signal_type)
{
  double jaws_value  = alligator_data.jaws_value;
  double teeth_value = alligator_data.teeth_value;
  double lips_value  = alligator_data.lips_value;

  if(signal_type == BULLISH)
    return (lips_value > teeth_value && teeth_value > jaws_value);
  if(signal_type == BEARISH)
    return (lips_value < teeth_value && teeth_value < jaws_value);
  return false;
}

bool EvaluateDirectionalSlope(const double current_value,
                              const double previous_value,
                              const SignalTypes signal_type)
{
  if(signal_type == BULLISH)
    return current_value >= previous_value;
  if(signal_type == BEARISH)
    return current_value <= previous_value;
  return true;
}

bool EvaluateBaseIndicatorTrigger(const SignalParams &signal_params,
                                  const SignalTypes signal_type,
                                  const double percent_threshold,
                                  const SlopeTypes slope_filter)
{
  bool uses_bpercent  = (Strategy_Base_Mode == TREND_BPERCENT || Strategy_Base_Mode == TREND_BOTH);
  bool uses_alligator = (Strategy_Base_Mode == TREND_ALLIGATOR || Strategy_Base_Mode == TREND_BOTH);

  bool bpercent_pass  = true;
  bool alligator_pass = true;

  if(uses_bpercent)
  {
    if(percent_threshold >= 0.0)
    {
      int total_entries = ArraySize(signal_params.bands_percent_data);
      if(total_entries <= 0)
        return false;

      BandsPercentStructure bands_data = signal_params.bands_percent_data[0];
      bpercent_pass = EvaluateBandsPercentTrigger(bands_data,
                                                  signal_type,
                                                  percent_threshold,
                                                  slope_filter);
    }
    else
    {
      bpercent_pass = true;
    }
  }

  if(uses_alligator)
  {
    int total_alligator_entries = ArraySize(signal_params.alligator_data);
    if(total_alligator_entries <= 0)
      return false;

    AlligatorStructure alligator_data = signal_params.alligator_data[0];
    alligator_pass = EvaluateAlligatorTrend(alligator_data, signal_type);
  }

  if(Strategy_Base_Mode == TREND_BPERCENT)
    return bpercent_pass;
  if(Strategy_Base_Mode == TREND_ALLIGATOR)
    return alligator_pass;
  if(Strategy_Base_Mode == TREND_BOTH)
    return bpercent_pass && alligator_pass;

  if(percent_threshold < 0.0)
    return true;

  int total_entries = ArraySize(signal_params.bands_percent_data);
  if(total_entries <= 0)
    return false;

  BandsPercentStructure bands_data = signal_params.bands_percent_data[0];
  return EvaluateBandsPercentTrigger(bands_data,
                                     signal_type,
                                     percent_threshold,
                                     slope_filter);
}

bool FetchStructureForFilters(const SignalParams &signal_params,
                              StochasticMarketStructure &structure,
                              const StrategyStructureLayerContext &ctx)
{
  if(ctx.enabled && ctx.uses_trend_dataset)
  {
    if(signal_params.trend_structure_valid)
    {
      structure = signal_params.trend_structure_data;
      return true;
    }
    return false;
  }

  int total_structures = ArraySize(signal_params.stoch_market_structure_data);
  if(total_structures <= 0)
    return false;

  structure = signal_params.stoch_market_structure_data[0];
  return true;
}

int DirectionIndex(const SignalTypes direction)
{
  return (direction == BEARISH) ? 1 : 0;
}

datetime ExtractStructureFreshTimestamp(const StochasticMarketStructure &structure)
{
  datetime freshest = 0;
  if(structure.first_structure_time > freshest)
    freshest = structure.first_structure_time;
  if(structure.second_structure_time > freshest)
    freshest = structure.second_structure_time;
  if(structure.third_structure_time > freshest)
    freshest = structure.third_structure_time;
  if(structure.fourth_structure_time > freshest)
    freshest = structure.fourth_structure_time;
  return freshest;
}

bool ValidateFreshStructureTimestamp(const SignalParams &signal_params,
                                     const StrategyStructureLayerContext &ctx,
                                     const SignalTypes direction,
                                     const bool is_trend_context,
                                     datetime &captured_time)
{
  captured_time = 0;
  if(!ctx.enabled)
    return true;

  bool enforce = is_trend_context ? Trend_Fresh_Structure_Time : Base_Fresh_Structure_Time;
  if(!enforce)
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
    return false;

  datetime structure_time = ExtractStructureFreshTimestamp(structure);
  if(structure_time <= 0)
    return false;

  int idx = DirectionIndex(direction);
  datetime last_time = is_trend_context ? g_last_trend_structure_time[idx]
                                        : g_last_base_structure_time[idx];
  if(last_time > 0 && structure_time <= last_time)
    return false;

  captured_time = structure_time;
  return true;
}

void RegisterFreshStructureUsage(const SignalParams &signal_params)
{
  int idx = DirectionIndex(signal_params.signal_type);

  if(Base_Fresh_Structure_Time && signal_params.base_structure_snapshot_time > 0)
    g_last_base_structure_time[idx] = signal_params.base_structure_snapshot_time;

  if(Trend_Fresh_Structure_Time && signal_params.trend_structure_snapshot_time > 0)
    g_last_trend_structure_time[idx] = signal_params.trend_structure_snapshot_time;
}

bool ValidateExternStructuresRequirement(const ExtremumStatistics &latest_stats,
                                         const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return true;
  if(ctx.min_extern_structures <= 0)
    return true;
  return latest_stats.extern_structures_broken >= ctx.min_extern_structures;
}

bool ValidateRetestRequirements(const ExtremumStatistics &latest_stats,
                                const SignalTypes signal_type,
                                const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return true;
  for(int zone_index = 0; zone_index < FIBO_RETEST_ZONES_TOTAL; zone_index++)
  {
    int required = ResolveRetestRequirement(ctx, signal_type, zone_index);
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
  int total_structures = ArraySize(signal_params.stoch_market_structure_data);
  if(total_structures <= 0)
    return false;

  StochasticMarketStructure structure       = signal_params.stoch_market_structure_data[0];
  OscillatorMarketStructure latest_extremum = structure.os_market_structures[0];

  if(signal_type == BULLISH)
  {
    return !latest_extremum.is_peak;
  }
  if(signal_type == BEARISH)
  {
    return latest_extremum.is_peak;
  }

  return false;
}

bool EvaluateStructureRetestTrigger(const SignalParams &signal_params,
                                    const SignalTypes signal_type,
                                    const StrategyStructureLayerContext &ctx)
{
  if(!StructureFiltersRequested(ctx))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
    return false;

  if(ArraySize(structure.extremum_stats) <= 0)
    return false;

  ExtremumStatistics latest_stats = structure.extremum_stats[0];

  if(!ValidateExternStructuresRequirement(latest_stats, ctx))
    return false;

  if(!ValidateRetestRequirements(latest_stats, signal_type, ctx))
    return false;

  return true;
}

bool TrendStructureFilterMatches(const TrendStructureFilterModes filter_mode,
                                 const OscillatorStructureTypes structure_type)
{
  if(filter_mode == BULLISH_STRUCT_OFF || filter_mode == BEARISH_STRUCT_OFF)
    return true;

  if(filter_mode == BULLISH_STRUCT_OFF_FINAL || filter_mode == BEARISH_STRUCT_OFF_FINAL)
    return true;

  if(structure_type == OSCILLATOR_STRUCTURE_EQ)
    return true;

  switch(filter_mode)
  {
    case BULLISH_STRUCT_LL:
      return (structure_type == OSCILLATOR_STRUCTURE_LL);
    case BULLISH_STRUCT_LH:
      return (structure_type == OSCILLATOR_STRUCTURE_LH);
    case BULLISH_STRUCT_LL_LH:
      return (structure_type == OSCILLATOR_STRUCTURE_LL ||
              structure_type == OSCILLATOR_STRUCTURE_LH);
    case BEARISH_STRUCT_HH:
      return (structure_type == OSCILLATOR_STRUCTURE_HH);
    case BEARISH_STRUCT_HL:
      return (structure_type == OSCILLATOR_STRUCTURE_HL);
    case BEARISH_STRUCT_HH_HL:
      return (structure_type == OSCILLATOR_STRUCTURE_HH ||
              structure_type == OSCILLATOR_STRUCTURE_HL);
  }
  return true;
}

bool EvaluateStructureTypeFilters(const SignalParams &signal_params,
                                  const StrategyStructureLayerContext &ctx)
{
  if(!StructureTypeFiltersRequested(ctx))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
    return false;

  bool first_pass  = TrendStructureFilterMatches(ctx.first_structure_filter,
                                                 structure.first_structure_type);
  bool second_pass = TrendStructureFilterMatches(ctx.second_structure_filter,
                                                 structure.second_structure_type);

  return first_pass && second_pass;
}

bool EvaluateSignalTrigger(SignalParams &signal_params, const SignalTypes signal_type)
{
  StrategyStructureLayerContext base_ctx  = BuildBaseStructureLayerContext();
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();

  datetime base_fresh_time  = 0;
  datetime trend_fresh_time = 0;

  if(!ValidateFreshStructureTimestamp(signal_params,
                                      base_ctx,
                                      signal_type,
                                      false,
                                      base_fresh_time))
    return false;

  if(!ValidateFreshStructureTimestamp(signal_params,
                                      trend_ctx,
                                      signal_type,
                                      true,
                                      trend_fresh_time))
    return false;

  bool base_trigger             = EvaluateBaseIndicatorTrigger(signal_params,
                                                               signal_type,
                                                               Base_Indicator_Percent,
                                                               Base_Slope_Filter);
  bool solid_trigger            = EvaluateSolidIndicatorTrigger(signal_params, signal_type);
  bool base_structure_filters   = EvaluateStructureRetestTrigger(signal_params,
                                                                 signal_type,
                                                                 base_ctx);
  bool trend_structure_filters  = EvaluateStructureRetestTrigger(signal_params,
                                                                 signal_type,
                                                                 trend_ctx);
  bool base_structure_types     = EvaluateStructureTypeFilters(signal_params, base_ctx);
  bool trend_structure_types    = EvaluateStructureTypeFilters(signal_params, trend_ctx);

  signal_params.base_structure_snapshot_time  = base_fresh_time;
  signal_params.trend_structure_snapshot_time = trend_fresh_time;

  return base_trigger &&
         solid_trigger &&
         base_structure_filters &&
         trend_structure_filters &&
         base_structure_types &&
         trend_structure_types;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CRAWLER_MQH_
