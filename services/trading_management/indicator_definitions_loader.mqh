
//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
int IndicatorPeriods[];
IndicatorsHandleInfo ExtBandsIndicatorsHandle[];
IndicatorsHandleInfo ExtBPercentIndicatorsHandle[];
IndicatorsHandleInfo ExtAlligatorIndicatorsHandle[];
IndicatorsHandleInfo ExtStochIndicatorsHandle[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtBodyMAIndicatorsHandle[];
IndicatorsHandleInfo ExtATRIndicatorsHandle[];
IndicatorsHandleInfo ExtKeltnerIndicatorsHandle[];
IndicatorsHandleInfo TrendBPercentIndicatorHandle;
IndicatorsHandleInfo TrendAlligatorIndicatorHandle;
IndicatorsHandleInfo TrendStochIndicatorHandle;
IndicatorsHandleInfo TrendStructStochIndicatorHandle;
ENUM_TIMEFRAMES     Trend_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Trend_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Trailing_Indicator_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Risk_Trend_Timeframe = PERIOD_M5;

// TOTAL INDICATORS TO LOAD
int start_bands_indicators_load = 0;
int total_bands_indicators_load = 1;
int total_stoch_indicators_load = 1;
int total_tf_list_load          = 0;

// ── Helpers ─────────────────────────────────────────────────────────────

bool IsStrategyTimeframeSupported(const ENUM_TIMEFRAMES tf)
{
  switch(tf)
  {
    case PERIOD_M1:
    case PERIOD_M2:
    case PERIOD_M3:
    case PERIOD_M4:
    case PERIOD_M5:
    case PERIOD_M6:
    case PERIOD_M10:
    case PERIOD_M12:
    case PERIOD_M15:
    case PERIOD_M20:
    case PERIOD_M30:
    case PERIOD_H1:
    case PERIOD_H2:
    case PERIOD_H3:
    case PERIOD_H4:
      return true;
  }
  return false;
}

void PrepareStrategyTimeframes()
{
  ArrayResize(Strategy_TF_List, 0);

  ENUM_TIMEFRAMES configured_tf = Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Strategy timeframe %d not supported. Falling back to PERIOD_M1.", (int)configured_tf);
    configured_tf = PERIOD_M1;
  }

  ArrayResize(Strategy_TF_List, 1);
  Strategy_TF_List[0] = configured_tf;
  total_tf_list_load = ArraySize(Strategy_TF_List);
}

int ResolveBPercentIndicatorPeriod()
{
  int indicator_period = (int)Stoch_Structure_Period_Type;
  bool teeth_required = StrategyModeUsesTeethAlligator(Strategy_Base_Mode) ||
                        StrategyModeUsesTeethAlligator(Strategy_Trend_Mode);
  if(teeth_required)
    indicator_period = (int)Stoch_Structure_Period_Type;
  return MathMax(indicator_period, 1);
}

void PrepareIndicatorPeriods()
{
  ArrayResize(IndicatorPeriods, 1);
  IndicatorPeriods[0] = ResolveBPercentIndicatorPeriod();
}

inline bool TrendStructureNeedsDedicatedHandle()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  bool filters_active = StructureFiltersRequested(trend_ctx) ||
                        StructureTypeFiltersRequested(trend_ctx) ||
                        Trend_Fresh_Structure_Time;
  if(!trend_ctx.enabled)
    return false;
  return filters_active && trend_ctx.uses_trend_dataset;
}

ENUM_TIMEFRAMES ResolveTrendTimeframe()
{
  ENUM_TIMEFRAMES configured_tf = Trend_Strategy_Timeframe;
  if(configured_tf == PERIOD_CURRENT)
    return Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Trend timeframe %d not supported. Falling back to strategy timeframe %d.",
                (int)configured_tf,
                (int)Strategy_Timeframe);
    configured_tf = Strategy_Timeframe;
  }
  return configured_tf;
}

ENUM_TIMEFRAMES ResolveTrendStructureTimeframe()
{
  return ResolveTrendTimeframe();
}

ENUM_TIMEFRAMES ResolveTrailingStrategyTimeframe()
{
  ENUM_TIMEFRAMES configured_tf = Grid_Trailing_Timeframe;
  if(configured_tf == PERIOD_CURRENT)
    return Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Trailing timeframe %d not supported. Falling back to strategy timeframe %d.",
                (int)configured_tf,
                (int)Strategy_Timeframe);
    configured_tf = Strategy_Timeframe;
  }
  return configured_tf;
}

ENUM_TIMEFRAMES ResolveRiskTrendTimeframe()
{
  ENUM_TIMEFRAMES strategy_tf = Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(strategy_tf))
    strategy_tf = PERIOD_M1;

  ENUM_TIMEFRAMES trend_tf = ResolveTrendTimeframe();

  if(Grid_Risk_Timeframe_Source == GRID_RISK_TF_STRATEGY)
    return strategy_tf;

  // Default to trend timeframe but fall back to strategy when unsupported.
  if(IsStrategyTimeframeSupported(trend_tf))
    return trend_tf;

  return strategy_tf;
}

void ResetTrendIndicators()
{
  TrendBPercentIndicatorHandle = IndicatorsHandleInfo();
  TrendAlligatorIndicatorHandle = IndicatorsHandleInfo();
  TrendStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetTrendStructureIndicator()
{
  TrendStructStochIndicatorHandle = IndicatorsHandleInfo();
}

bool LoadTrendBPercentIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  IndicatorsHandleInfo trend_handle;
  trend_handle.indicator_period        = ResolveBPercentIndicatorPeriod();
  trend_handle.indicator_ma_method     = Base_Indicator_MA_Method;
  trend_handle.indicator_applied_price = PRICE_WEIGHTED;
  trend_handle.indicator_handle        = iCustom(_Symbol,
                                                 trend_tf,
                                                 "Examples\\BB_Percent_Standard.ex5",
                                                 trend_handle.indicator_period,
                                                 0,
                                                 2.0,
                                                 5,
                                                 Base_Indicator_MA_Method,
                                                 PRICE_WEIGHTED,
                                                 (int)Stoch_Structure_Period_Type);
  trend_handle.indicator_timeframe     = trend_tf;

  if(trend_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING TREND BOLLINGER PERCENT INDICATOR | tf=%s | period=%d",
                EnumToString(trend_tf),
                trend_handle.indicator_period);
    return false;
  }

  TrendBPercentIndicatorHandle = trend_handle;
  PrintFormat("Trend Bollinger Percent indicator loaded | tf=%s | period=%d",
              EnumToString(trend_tf),
              trend_handle.indicator_period);
  return true;
}

bool LoadTrendAlligatorIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

  IndicatorsHandleInfo alligator_handle;
  alligator_handle.indicator_period        = jaws_period;
  alligator_handle.indicator_ma_method     = Base_Indicator_MA_Method;
  alligator_handle.indicator_applied_price = PRICE_WEIGHTED;
  alligator_handle.indicator_handle        = iAlligator(_Symbol,
                                                        trend_tf,
                                                        jaws_period,
                                                        0,
                                                        teeth_period,
                                                        0,
                                                        lips_period,
                                                        0,
                                                        Base_Indicator_MA_Method,
                                                        PRICE_WEIGHTED);
  alligator_handle.indicator_timeframe     = trend_tf;

  if(alligator_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING TREND ALLIGATOR INDICATOR | tf=%s | jaws=%d | teeth=%d | lips=%d",
                EnumToString(trend_tf),
                jaws_period,
                teeth_period,
                lips_period);
    return false;
  }

  TrendAlligatorIndicatorHandle = alligator_handle;
  PrintFormat("Trend Alligator indicator loaded | tf=%s | jaws=%d | teeth=%d | lips=%d",
              EnumToString(trend_tf),
              jaws_period,
              teeth_period,
              lips_period);
  return true;
}

bool LoadTrendStochasticIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  IndicatorsHandleInfo stoch_handle;
  stoch_handle.indicator_period    = (int)Stoch_Structure_Period_Type;
  stoch_handle.indicator_handle    = iCustom(_Symbol,
                                             trend_tf,
                                             "Examples\\Stochastic",
                                             stoch_handle.indicator_period,
                                             3,
                                             3,
                                             STO_CLOSECLOSE);
  stoch_handle.indicator_timeframe = trend_tf;

  if(stoch_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING TREND STOCHASTIC INDICATOR | tf=%s | period=%d",
                EnumToString(trend_tf),
                stoch_handle.indicator_period);
    return false;
  }

  TrendStochIndicatorHandle = stoch_handle;
  PrintFormat("Trend stochastic indicator loaded | tf=%s | period=%d",
              EnumToString(trend_tf),
              stoch_handle.indicator_period);
  return true;
}

bool LoadTrendStructureIndicator(const ENUM_TIMEFRAMES structure_tf)
{
  IndicatorsHandleInfo structure_handle;
  structure_handle.indicator_period    = (int)Stoch_Structure_Period_Type;
  structure_handle.indicator_handle    = iCustom(_Symbol,
                                                 structure_tf,
                                                 "Examples\\Stochastic_Structure",
                                                 structure_handle.indicator_period,
                                                 3,
                                                 3,
                                                 STO_CLOSECLOSE);
  structure_handle.indicator_timeframe = structure_tf;

  if(structure_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING TREND STRUCTURE INDICATOR | tf=%s | period=%d",
                EnumToString(structure_tf),
                structure_handle.indicator_period);
    return false;
  }

  TrendStructStochIndicatorHandle = structure_handle;
  PrintFormat("Trend structure indicator loaded | tf=%s | period=%d",
              EnumToString(structure_tf),
              structure_handle.indicator_period);
  return true;
}

bool AlligatorIndicatorHandleExists(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtAlligatorIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtAlligatorIndicatorsHandle[i].indicator_timeframe == timeframe)
      return true;
  }
  return false;
}

bool LoadAlligatorIndicatorForTimeframe(const ENUM_TIMEFRAMES trend_tf)
{
  if(AlligatorIndicatorHandleExists(trend_tf))
    return true;

  int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

  IndicatorsHandleInfo alligator_handle;
  alligator_handle.indicator_period        = jaws_period;
  alligator_handle.indicator_ma_method     = Base_Indicator_MA_Method;
  alligator_handle.indicator_applied_price = PRICE_WEIGHTED;
  alligator_handle.indicator_handle        = iAlligator(_Symbol,
                                                        trend_tf,
                                                        jaws_period,
                                                        0,
                                                        teeth_period,
                                                        0,
                                                        lips_period,
                                                        0,
                                                        Base_Indicator_MA_Method,
                                                        PRICE_WEIGHTED);
  alligator_handle.indicator_timeframe     = trend_tf;

  if(alligator_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING ALLIGATOR INDICATOR | tf=%s | jaws=%d | teeth=%d | lips=%d",
                EnumToString(trend_tf),
                jaws_period,
                teeth_period,
                lips_period);
    TesterStop();
    return false;
  }

  PrintFormat("LOADED ALLIGATOR INDICATOR SUCCESSFULLY: tf=%s | jaws=%d | teeth=%d | lips=%d",
              EnumToString(trend_tf),
              jaws_period,
              teeth_period,
              lips_period);

  AddElementToArray(ExtAlligatorIndicatorsHandle, alligator_handle);
  return true;
}

bool AtrIndicatorHandleExists(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtATRIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe == timeframe)
      return true;
  }
  return false;
}

bool KeltnerIndicatorHandleExists(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtKeltnerIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtKeltnerIndicatorsHandle[i].indicator_timeframe == timeframe)
      return true;
  }
  return false;
}

bool LoadAtrIndicatorForTimeframe(const ENUM_TIMEFRAMES trend_timeframe)
{
  if(AtrIndicatorHandleExists(trend_timeframe))
    return true;

  IndicatorsHandleInfo atr_indicator_handle_loaded;

  atr_indicator_handle_loaded.indicator_period    = (int)Stoch_Structure_Period_Type;
  double atr_factor = Grid_Channel_Factor;
  if(atr_factor <= 0.0)
    atr_factor = 1.0;
  atr_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                            trend_timeframe,
                                                            "Examples\\ATR_SL_Factor.ex5",
                                                            atr_indicator_handle_loaded.indicator_period,
                                                            atr_factor,
                                                            0);
  atr_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

  if(atr_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING ATR FACTOR INDICATOR: ", EnumToString(trend_timeframe), " | PERIOD: ", atr_indicator_handle_loaded.indicator_period);
    TesterStop();
    return false;
  }

  Print("LOADED ATR FACTOR INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe), " | PERIOD: ", atr_indicator_handle_loaded.indicator_period);

  AddElementToArray(ExtATRIndicatorsHandle, atr_indicator_handle_loaded);
  return true;
}

bool LoadKeltnerIndicatorForTimeframe(const ENUM_TIMEFRAMES trend_timeframe)
{
  if(KeltnerIndicatorHandleExists(trend_timeframe))
    return true;

  IndicatorsHandleInfo keltner_handle;
  keltner_handle.indicator_period    = (int)Stoch_Structure_Period_Type;
  double channel_factor = Grid_Channel_Factor;
  if(channel_factor <= 0.0)
    channel_factor = 1.0;
  keltner_handle.indicator_handle    = iCustom(_Symbol,
                                               trend_timeframe,
                                               "Examples\\Keltner_Channel.ex5",
                                               keltner_handle.indicator_period,
                                               keltner_handle.indicator_period,
                                               0,
                                               channel_factor,
                                               Base_Indicator_MA_Method);
  keltner_handle.indicator_timeframe = trend_timeframe;

  if(keltner_handle.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING KELTNER CHANNEL INDICATOR: ", EnumToString(trend_timeframe), " | PERIOD: ", keltner_handle.indicator_period);
    TesterStop();
    return false;
  }

  Print("LOADED KELTNER CHANNEL INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe), " | PERIOD: ", keltner_handle.indicator_period);

  AddElementToArray(ExtKeltnerIndicatorsHandle, keltner_handle);
  return true;
}

bool LoadChannelIndicatorForTimeframe(const GridBaseStrategyTypes channel_type,
                                      const ENUM_TIMEFRAMES trend_timeframe)
{
  if(channel_type == KELTNER_RANGE)
    return LoadKeltnerIndicatorForTimeframe(trend_timeframe);
  return LoadAtrIndicatorForTimeframe(trend_timeframe);
}

void EnsureTrailingIndicatorDependencies(const bool requires_channel_indicator,
                                         const bool trailing_requires_alligator,
                                         const bool risk_requires_alligator,
                                         const GridBaseStrategyTypes channel_type)
{
  ENUM_TIMEFRAMES trailing_tf = Trailing_Indicator_Timeframe;
  ENUM_TIMEFRAMES base_tf     = Strategy_TF_List[0];

  if(trailing_requires_alligator && trailing_tf != base_tf)
    LoadAlligatorIndicatorForTimeframe(trailing_tf);
  if(requires_channel_indicator && trailing_tf != base_tf)
    LoadChannelIndicatorForTimeframe(channel_type, trailing_tf);

  if(risk_requires_alligator)
    LoadAlligatorIndicatorForTimeframe(Risk_Trend_Timeframe);
}

void LoadTrendIndicators()
{
  ResetTrendIndicators();

  if(!TrendContextEnabled())
  {
    Print("Trend context disabled; skipping trend indicator loading.");
    return;
  }

  if(Strategy_Trend_Mode == TREND_OFF)
  {
    Print("Trend filter disabled; skipping trend indicator loading.");
    return;
  }

  Trend_Filter_Timeframe = ResolveTrendTimeframe();

  bool need_bpercent  = (StrategyModeUsesAnyBPercent(Strategy_Trend_Mode) ||
                         Trend_BPercent_Slope_Filter);
  bool need_alligator = (StrategyModeUsesAlligator(Strategy_Trend_Mode) ||
                         Trend_Alligator_Slope_Filter);
  bool need_stochastic = Trend_Stochastic_Slope_Filter;

  bool bpercent_loaded  = true;
  bool alligator_loaded = true;
  bool stoch_loaded     = true;

  if(need_bpercent)
    bpercent_loaded = LoadTrendBPercentIndicator(Trend_Filter_Timeframe);

  if(need_alligator)
    alligator_loaded = LoadTrendAlligatorIndicator(Trend_Filter_Timeframe);

  if(need_stochastic)
    stoch_loaded = LoadTrendStochasticIndicator(Trend_Filter_Timeframe);

  if((need_bpercent && !bpercent_loaded) ||
     (need_alligator && !alligator_loaded) ||
     (need_stochastic && !stoch_loaded))
  {
    if(!bpercent_loaded)
      TrendBPercentIndicatorHandle = IndicatorsHandleInfo();
    if(!alligator_loaded)
      TrendAlligatorIndicatorHandle = IndicatorsHandleInfo();
    if(!stoch_loaded)
      TrendStochIndicatorHandle = IndicatorsHandleInfo();
  }
}

bool TrendFilterIndicatorsAvailable()
{
  if(!TrendContextEnabled() || Strategy_Trend_Mode == TREND_OFF)
    return true;
  bool need_bpercent  = (StrategyModeUsesAnyBPercent(Strategy_Trend_Mode) ||
                         Trend_BPercent_Slope_Filter);
  bool need_alligator = (StrategyModeUsesAlligator(Strategy_Trend_Mode) ||
                         Trend_Alligator_Slope_Filter);
  bool need_stochastic = Trend_Stochastic_Slope_Filter;

  if(need_bpercent && TrendBPercentIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_alligator && TrendAlligatorIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_stochastic && TrendStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  return true;
}

void LoadTrendStructureFilterIndicator()
{
  ResetTrendStructureIndicator();

  if(!TrendStructureNeedsDedicatedHandle())
    return;

  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  if(Trend_Structure_Filter_Timeframe == strategy_tf)
  {
    Print("Trend structure timeframe matches strategy timeframe; reusing strategy structure handles.");
    return;
  }

  if(!LoadTrendStructureIndicator(Trend_Structure_Filter_Timeframe))
    ResetTrendStructureIndicator();
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  PrepareIndicatorPeriods();

  bool base_mode_uses_bpercent  = StrategyModeUsesAnyBPercent(Strategy_Base_Mode);
  bool base_mode_uses_alligator = StrategyModeUsesAlligator(Strategy_Base_Mode);
  bool base_bpercent_required   = base_mode_uses_bpercent || Base_BPercent_Slope_Filter;
  bool trailing_requires_alligator = (Grid_Trailing_Strategy_Mode == TRAILING_LIPS_MA);
  bool trailing_requires_channel   = (Grid_Trailing_Strategy_Mode == TRAILING_ATR_BASED);
  bool risk_requires_alligator     = (Grid_Risk_Trend_Mode != GRID_RM_TREND_OFF);
  bool base_alligator_required  = base_mode_uses_alligator || Base_Alligator_Slope_Filter ||
                                  trailing_requires_alligator || risk_requires_alligator;
  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  Trend_Structure_Filter_Timeframe = ResolveTrendStructureTimeframe();
  Trailing_Indicator_Timeframe = ResolveTrailingStrategyTimeframe();
  Risk_Trend_Timeframe = ResolveRiskTrendTimeframe();

  bool require_structure_indicators = true;

  bool strategy_uses_channel = (Grid_Base_Strategy_Type == ATR_RANGE ||
                                Grid_Base_Strategy_Type == KELTNER_RANGE);
  bool load_channel_indicators = strategy_uses_channel || trailing_requires_channel;
  GridBaseStrategyTypes channel_strategy_type = (Grid_Base_Strategy_Type == KELTNER_RANGE)
                                                  ? KELTNER_RANGE
                                                  : ATR_RANGE;

  if(base_mode_uses_bpercent && Base_Indicator_Percent <= 0.0)
    Print("WARNING: Base Bollinger Percent indicator disabled; percent threshold <= 0.");

  TesterHideIndicators(!Enable_Show_Indicators);

  int resolved_bpercent_period = IndicatorPeriods[0];
  PrintFormat("Strategy context | TF=%s | BasePercent=%.2f | TrendPercent=%.2f | BasePeriod=%d | BPercentPeriod=%d | SolidPeriod=%d | Direction=%s",
              EnumToString(Strategy_Timeframe),
              Base_Indicator_Percent,
              Trend_Indicator_Percent,
              (int)Base_Indicator_Period_Type,
              resolved_bpercent_period,
              (int)Stoch_Structure_Period_Type,
              EnumToString(Strategy_Direction_Mode));

  ArrayResize(ExtBandsIndicatorsHandle, 0);
  ArrayResize(ExtBPercentIndicatorsHandle, 0);
  ArrayResize(ExtAlligatorIndicatorsHandle, 0);
  ArrayResize(ExtStochIndicatorsHandle, 0);
  ArrayResize(ExtStructStochIndicatorsHandle, 0);
  ArrayResize(ExtBodyMAIndicatorsHandle, 0);
  ArrayResize(ExtATRIndicatorsHandle, 0);
  ArrayResize(ExtKeltnerIndicatorsHandle, 0);

  if(base_bpercent_required)
  {
    LoadAllBPercentIndicators();
  }
  else
  {
    Print("Base Bollinger Percent indicator loading skipped (mode and slope filters disabled).");
  }

  if(base_alligator_required)
  {
    LoadAllAlligatorIndicators();
  }
  else
  {
    Print("Base Alligator indicator loading skipped (mode, slope filters, and trailing settings disabled).");
  }

  if(require_structure_indicators)
  {
    LoadAllStochIndicators();
    LoadAllStructStochIndicators();
  }
  else
  {
    Print("Solid indicator strategy disabled and no structure filters configured; skipping stochastic indicator loading.");
  }

  if(load_channel_indicators)
  {
    if(channel_strategy_type == KELTNER_RANGE)
      LoadAllKeltnerIndicators();
    else
      LoadAllATRIndicators();

    if(Trend_Channel_MA_Filter)
    {
      ENUM_TIMEFRAMES trend_channel_tf = Trend_Strategy_Timeframe;
      if(trend_channel_tf == PERIOD_CURRENT)
        trend_channel_tf = Strategy_Timeframe;
      if(trend_channel_tf != strategy_tf)
        LoadChannelIndicatorForTimeframe(channel_strategy_type, trend_channel_tf);
    }
  }
  else
  {
    Print("Volatility indicator strategy disabled and trailing indicator mode inactive; skipping channel indicator loading.");
  }

  LoadAllBodyMAIndicators();
  LoadTrendIndicators();
  LoadTrendStructureFilterIndicator();
  EnsureTrailingIndicatorDependencies(trailing_requires_channel,
                                      trailing_requires_alligator,
                                      risk_requires_alligator,
                                      channel_strategy_type);
}

// ++ LOAD ALL INDICATORS VARIANTS FUNCTIONS ++

void LoadAllBandsIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    int total_periods_load = ArraySize(IndicatorPeriods);
    int limit = start_bands_indicators_load + total_bands_indicators_load;
    if(total_periods_load > limit)
      total_periods_load = limit;

    for(int period_index = start_bands_indicators_load; period_index < total_periods_load; period_index++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[period_index];
      bands_indicator_handle_loaded.indicator_ma_method  = Base_Indicator_MA_Method;
      bands_indicator_handle_loaded.indicator_applied_price = PRICE_WEIGHTED;
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                                  trend_timeframe,
                                                                  "Examples\\BB_Standard.ex5",
                                                                  bands_indicator_handle_loaded.indicator_period,
                                                                  0,
                                                                  2.0,
                                                                  Base_Indicator_MA_Method,
                                                                  PRICE_WEIGHTED);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);

      AddElementToArray(ExtBandsIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllBPercentIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    int total_periods_load = ArraySize(IndicatorPeriods);
    int limit = start_bands_indicators_load + total_bands_indicators_load;
    if(total_periods_load > limit)
      total_periods_load = limit;

    for(int period_index = start_bands_indicators_load; period_index < total_periods_load; period_index++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[period_index];
      bands_indicator_handle_loaded.indicator_ma_method  = Base_Indicator_MA_Method;
      bands_indicator_handle_loaded.indicator_applied_price = PRICE_WEIGHTED;
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                                  trend_timeframe,
                                                                  "Examples\\BB_Percent_Standard.ex5",
                                                                  bands_indicator_handle_loaded.indicator_period,
                                                                  0,
                                                                  2.0,
                                                                  5,
                                                                  Base_Indicator_MA_Method,
                                                                  PRICE_WEIGHTED,
                                                                  (int)Stoch_Structure_Period_Type);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS PERCENT INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS PERCENT INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);

      AddElementToArray(ExtBPercentIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllAlligatorIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES timeframe = Strategy_TF_List[i];
    if(!LoadAlligatorIndicatorForTimeframe(timeframe))
      break;
  }
}

void LoadAllStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo stoch_indicator_handle_loaded;

    stoch_indicator_handle_loaded.indicator_period    = (int)Stoch_Structure_Period_Type;
    stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic", stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
    stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      break;
    }

    Print("LOADED STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStochIndicatorsHandle, stoch_indicator_handle_loaded);
  }
}

void LoadAllStructStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo struct_stoch_indicator_handle_loaded;

    struct_stoch_indicator_handle_loaded.indicator_period    = (int)Stoch_Structure_Period_Type;
    struct_stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic_Structure", struct_stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
    struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STRUCT STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      break;
    }

    Print("LOADED STRUCT STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
  }
}

void LoadAllATRIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    if(!LoadAtrIndicatorForTimeframe(trend_timeframe))
      break;
  }
}

void LoadAllKeltnerIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    if(!LoadKeltnerIndicatorForTimeframe(trend_timeframe))
      break;
  }
}

void LoadAllBodyMAIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo body_ma_indicator_handle_loaded;

    body_ma_indicator_handle_loaded.indicator_period    = 5;
    body_ma_indicator_handle_loaded.indicator_shift     = 0;
    body_ma_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Body_MA.ex5", 5, 0);
    body_ma_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(body_ma_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING BODY MA INDICATOR: ", EnumToString(trend_timeframe), " | PERIOD: 5");
      TesterStop();
      break;
    }

    Print("LOADED BODY MA INDICATOR SUCCESFULLY: ", EnumToString(trend_timeframe), " | PERIOD: 5");

    AddElementToArray(ExtBodyMAIndicatorsHandle, body_ma_indicator_handle_loaded);
  }
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
