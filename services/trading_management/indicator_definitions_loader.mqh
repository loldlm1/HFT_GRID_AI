
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
IndicatorsHandleInfo MacroBPercentIndicatorHandle;
IndicatorsHandleInfo MacroAlligatorIndicatorHandle;
IndicatorsHandleInfo MacroStochIndicatorHandle;
IndicatorsHandleInfo MacroStructStochIndicatorHandle;
IndicatorsHandleInfo SessionBPercentIndicatorHandle;
IndicatorsHandleInfo SessionAlligatorIndicatorHandle;
IndicatorsHandleInfo SessionStochIndicatorHandle;
IndicatorsHandleInfo SessionStructStochIndicatorHandle;
ENUM_TIMEFRAMES     Trend_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Trend_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Macro_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Macro_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Session_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Session_Structure_Filter_Timeframe = PERIOD_M5;
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

string ResolveChannelPercentIndicatorPath()
{
  if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_ATR)
    return "Examples\\ATR_SL_Factor_Percent.ex5";
  if(Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_KELTNER)
    return "Examples\\Keltner_Channel_Percent.ex5";
  return "Examples\\BB_Percent_Standard.ex5";
}

string StrategyChannelIndicatorLabel()
{
  return (Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_KELTNER)
           ? "KELTNER"
           : (Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_ATR)
               ? "ATR"
               : "BOLLINGER";
}

GridBaseStrategyTypes ResolveChannelStrategyFromInputs()
{
  GridBaseStrategyTypes configured_type = Grid_Base_Strategy_Type;
  if(configured_type == CHANNEL_INDICATOR_RANGE || configured_type == POINTS_RANGE)
  {
    switch(Strategy_Channel_Indicator_Type)
    {
      case CHANNEL_INDICATOR_KELTNER:
        return KELTNER_RANGE;
      case CHANNEL_INDICATOR_ATR:
        return ATR_RANGE;
      case CHANNEL_INDICATOR_BOLLINGER:
      default:
        return BOLLINGER_RANGE;
    }
  }
  return configured_type;
}

double ResolveChannelFactor()
{
  double channel_factor = Grid_Channel_Factor;
  if(channel_factor <= 0.0)
    channel_factor = 1.0;
  return channel_factor;
}

double ResolveBollingerDeviationFactor()
{
  return 1.0 + ResolveChannelFactor();
}

int ResolveBPercentIndicatorPeriod()
{
  int indicator_period = (int)Base_Indicator_Period_Type;
  bool teeth_required = TrendModeUsesTeethAlligator(Strategy_Base_Trend_Mode) ||
                        TrendModeUsesTeethAlligator(Strategy_Trend_Trend_Mode) ||
                        TrendModeUsesTeethAlligator(Strategy_Macro_Trend_Mode) ||
                        TrendModeUsesTeethAlligator(Strategy_Session_Trend_Mode);
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

inline bool MacroStructureNeedsDedicatedHandle()
{
  StrategyStructureLayerContext macro_ctx = BuildMacroStructureLayerContext();
  bool filters_active = StructureFiltersRequested(macro_ctx) ||
                        StructureTypeFiltersRequested(macro_ctx) ||
                        Macro_Fresh_Structure_Time;
  if(!macro_ctx.enabled)
    return false;
  return filters_active;
}

inline bool SessionStructureNeedsDedicatedHandle()
{
  StrategyStructureLayerContext session_ctx = BuildSessionStructureLayerContext();
  bool filters_active = StructureFiltersRequested(session_ctx) ||
                        StructureTypeFiltersRequested(session_ctx) ||
                        Session_Fresh_Structure_Time;
  if(!session_ctx.enabled)
    return false;
  return filters_active;
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

ENUM_TIMEFRAMES ResolveMacroTimeframe()
{
  ENUM_TIMEFRAMES configured_tf = Macro_Strategy_Timeframe;
  if(configured_tf == PERIOD_CURRENT)
    return Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Macro timeframe %d not supported. Falling back to strategy timeframe %d.",
                (int)configured_tf,
                (int)Strategy_Timeframe);
    configured_tf = Strategy_Timeframe;
  }
  return configured_tf;
}

ENUM_TIMEFRAMES ResolveMacroStructureTimeframe()
{
  return ResolveMacroTimeframe();
}

ENUM_TIMEFRAMES ResolveSessionTimeframe()
{
  ENUM_TIMEFRAMES configured_tf = Session_Strategy_Timeframe;
  if(configured_tf == PERIOD_CURRENT)
    return Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Session timeframe %d not supported. Falling back to strategy timeframe %d.",
                (int)configured_tf,
                (int)Strategy_Timeframe);
    configured_tf = Strategy_Timeframe;
  }
  return configured_tf;
}

ENUM_TIMEFRAMES ResolveSessionStructureTimeframe()
{
  return ResolveSessionTimeframe();
}

bool LoadContextBPercentIndicator(const ENUM_TIMEFRAMES context_tf,
                                  IndicatorsHandleInfo &target_handle,
                                  const string context_label)
{
  IndicatorsHandleInfo handle;
  handle.indicator_period        = ResolveBPercentIndicatorPeriod();
  handle.indicator_ma_method     = Base_Indicator_MA_Method;
  handle.indicator_applied_price = PRICE_WEIGHTED;
  double channel_factor = ResolveChannelFactor();
  double percent_factor = (Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_BOLLINGER)
                            ? ResolveBollingerDeviationFactor()
                            : channel_factor;
  handle.indicator_handle        = iCustom(_Symbol,
                                           context_tf,
                                           ResolveChannelPercentIndicatorPath(),
                                           handle.indicator_period,
                                           0,
                                           percent_factor,
                                           5,
                                           Base_Indicator_MA_Method,
                                           handle.indicator_applied_price,
                                           (int)Stoch_Structure_Period_Type);
  handle.indicator_timeframe     = context_tf;

  if(handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING %s %s CHANNEL PERCENT INDICATOR | tf=%s | period=%d",
                context_label,
                StrategyChannelIndicatorLabel(),
                EnumToString(context_tf),
                handle.indicator_period);
    return false;
  }

  target_handle = handle;
  PrintFormat("%s %s channel percent indicator loaded | tf=%s | period=%d",
              context_label,
              StrategyChannelIndicatorLabel(),
              EnumToString(context_tf),
              handle.indicator_period);
  return true;
}

bool LoadContextAlligatorIndicator(const ENUM_TIMEFRAMES context_tf,
                                   IndicatorsHandleInfo &target_handle,
                                   const string context_label)
{
  int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

  IndicatorsHandleInfo alligator_handle;
  alligator_handle.indicator_period        = jaws_period;
  alligator_handle.indicator_ma_method     = Base_Indicator_MA_Method;
  alligator_handle.indicator_applied_price = PRICE_WEIGHTED;
  alligator_handle.indicator_handle        = iAlligator(_Symbol,
                                                        context_tf,
                                                        jaws_period,
                                                        0,
                                                        teeth_period,
                                                        0,
                                                        lips_period,
                                                        0,
                                                        Base_Indicator_MA_Method,
                                                        PRICE_WEIGHTED);
  alligator_handle.indicator_timeframe     = context_tf;

  if(alligator_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING %s ALLIGATOR INDICATOR | tf=%s | jaws=%d | teeth=%d | lips=%d",
                context_label,
                EnumToString(context_tf),
                jaws_period,
                teeth_period,
                lips_period);
    return false;
  }

  target_handle = alligator_handle;
  PrintFormat("%s Alligator indicator loaded | tf=%s | jaws=%d | teeth=%d | lips=%d",
              context_label,
              EnumToString(context_tf),
              jaws_period,
              teeth_period,
              lips_period);
  return true;
}

bool LoadContextStochasticIndicator(const ENUM_TIMEFRAMES context_tf,
                                    IndicatorsHandleInfo &target_handle,
                                    const string context_label)
{
  IndicatorsHandleInfo stoch_handle;
  stoch_handle.indicator_period    = (int)Stoch_Structure_Period_Type;
  stoch_handle.indicator_handle    = iCustom(_Symbol,
                                             context_tf,
                                             "Examples\\Stochastic",
                                             stoch_handle.indicator_period,
                                             3,
                                             3,
                                             STO_CLOSECLOSE);
  stoch_handle.indicator_timeframe = context_tf;

  if(stoch_handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR LOADING %s STOCHASTIC INDICATOR | tf=%s | period=%d",
                context_label,
                EnumToString(context_tf),
                stoch_handle.indicator_period);
    return false;
  }

  target_handle = stoch_handle;
  PrintFormat("%s stochastic indicator loaded | tf=%s | period=%d",
              context_label,
              EnumToString(context_tf),
              stoch_handle.indicator_period);
  return true;
}

bool LoadContextStructureIndicator(const ENUM_TIMEFRAMES structure_tf,
                                   IndicatorsHandleInfo &target_handle,
                                   const string context_label)
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
    PrintFormat("ERROR LOADING %s STRUCTURE INDICATOR | tf=%s | period=%d",
                context_label,
                EnumToString(structure_tf),
                structure_handle.indicator_period);
    return false;
  }

  target_handle = structure_handle;
  PrintFormat("%s structure indicator loaded | tf=%s | period=%d",
              context_label,
              EnumToString(structure_tf),
              structure_handle.indicator_period);
  return true;
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

  if(Grid_Risk_Timeframe_Source == GRID_RISK_TF_TREND)
  {
    if(IsStrategyTimeframeSupported(trend_tf))
      return trend_tf;
    return strategy_tf;
  }

  if(Grid_Risk_Timeframe_Source == GRID_RISK_TF_MACRO)
  {
    ENUM_TIMEFRAMES macro_tf = ResolveMacroTimeframe();
    if(IsStrategyTimeframeSupported(macro_tf))
      return macro_tf;
    return strategy_tf;
  }

  if(Grid_Risk_Timeframe_Source == GRID_RISK_TF_SESSION)
  {
    ENUM_TIMEFRAMES session_tf = ResolveSessionTimeframe();
    if(IsStrategyTimeframeSupported(session_tf))
      return session_tf;
    return strategy_tf;
  }

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

void ResetMacroIndicators()
{
  MacroBPercentIndicatorHandle = IndicatorsHandleInfo();
  MacroAlligatorIndicatorHandle = IndicatorsHandleInfo();
  MacroStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetMacroStructureIndicator()
{
  MacroStructStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetSessionIndicators()
{
  SessionBPercentIndicatorHandle = IndicatorsHandleInfo();
  SessionAlligatorIndicatorHandle = IndicatorsHandleInfo();
  SessionStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetSessionStructureIndicator()
{
  SessionStructStochIndicatorHandle = IndicatorsHandleInfo();
}

bool LoadTrendBPercentIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  return LoadContextBPercentIndicator(trend_tf,
                                      TrendBPercentIndicatorHandle,
                                      "Trend");
}

bool LoadTrendAlligatorIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  return LoadContextAlligatorIndicator(trend_tf,
                                       TrendAlligatorIndicatorHandle,
                                       "Trend");
}

bool LoadTrendStochasticIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  return LoadContextStochasticIndicator(trend_tf,
                                        TrendStochIndicatorHandle,
                                        "Trend");
}

bool LoadTrendStructureIndicator(const ENUM_TIMEFRAMES structure_tf)
{
  return LoadContextStructureIndicator(structure_tf,
                                       TrendStructStochIndicatorHandle,
                                       "Trend");
}

bool LoadMacroBPercentIndicator(const ENUM_TIMEFRAMES macro_tf)
{
  return LoadContextBPercentIndicator(macro_tf,
                                      MacroBPercentIndicatorHandle,
                                      "Macro");
}

bool LoadMacroAlligatorIndicator(const ENUM_TIMEFRAMES macro_tf)
{
  return LoadContextAlligatorIndicator(macro_tf,
                                       MacroAlligatorIndicatorHandle,
                                       "Macro");
}

bool LoadMacroStochasticIndicator(const ENUM_TIMEFRAMES macro_tf)
{
  return LoadContextStochasticIndicator(macro_tf,
                                        MacroStochIndicatorHandle,
                                        "Macro");
}

bool LoadMacroStructureIndicator(const ENUM_TIMEFRAMES structure_tf)
{
  return LoadContextStructureIndicator(structure_tf,
                                       MacroStructStochIndicatorHandle,
                                       "Macro");
}

bool LoadSessionBPercentIndicator(const ENUM_TIMEFRAMES session_tf)
{
  return LoadContextBPercentIndicator(session_tf,
                                      SessionBPercentIndicatorHandle,
                                      "Session");
}

bool LoadSessionAlligatorIndicator(const ENUM_TIMEFRAMES session_tf)
{
  return LoadContextAlligatorIndicator(session_tf,
                                       SessionAlligatorIndicatorHandle,
                                       "Session");
}

bool LoadSessionStochasticIndicator(const ENUM_TIMEFRAMES session_tf)
{
  return LoadContextStochasticIndicator(session_tf,
                                        SessionStochIndicatorHandle,
                                        "Session");
}

bool LoadSessionStructureIndicator(const ENUM_TIMEFRAMES structure_tf)
{
  return LoadContextStructureIndicator(structure_tf,
                                       SessionStructStochIndicatorHandle,
                                       "Session");
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

bool BollingerIndicatorHandleExists(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtBandsIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtBandsIndicatorsHandle[i].indicator_timeframe == timeframe)
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
                                               (int)Stoch_Structure_Period_Type,
                                               0,
                                               channel_factor,
                                               Base_Indicator_MA_Method,
                                               PRICE_WEIGHTED);
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

bool LoadBollingerIndicatorForTimeframe(const ENUM_TIMEFRAMES trend_timeframe)
{
  if(BollingerIndicatorHandleExists(trend_timeframe))
    return true;

  IndicatorsHandleInfo bands_indicator_handle_loaded;
  bands_indicator_handle_loaded.indicator_period        = ResolveBPercentIndicatorPeriod();
  bands_indicator_handle_loaded.indicator_ma_method     = Base_Indicator_MA_Method;
  bands_indicator_handle_loaded.indicator_applied_price = PRICE_WEIGHTED;
  double deviation_factor = ResolveBollingerDeviationFactor();
  bands_indicator_handle_loaded.indicator_handle        = iCustom(_Symbol,
                                                                  trend_timeframe,
                                                                  "Examples\\BB_Standard.ex5",
                                                                  bands_indicator_handle_loaded.indicator_period,
                                                                  0,
                                                                  deviation_factor,
                                                                  Base_Indicator_MA_Method,
                                                                  PRICE_WEIGHTED);
  bands_indicator_handle_loaded.indicator_timeframe     = trend_timeframe;

  if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING BOLLINGER INDICATOR: ", EnumToString(trend_timeframe),
          " | PERIOD: ", bands_indicator_handle_loaded.indicator_period);
    TesterStop();
    return false;
  }

  AddElementToArray(ExtBandsIndicatorsHandle, bands_indicator_handle_loaded);
  return true;
}

bool LoadChannelIndicatorForTimeframe(const GridBaseStrategyTypes channel_type,
                                      const ENUM_TIMEFRAMES trend_timeframe)
{
  if(channel_type == KELTNER_RANGE)
    return LoadKeltnerIndicatorForTimeframe(trend_timeframe);
  if(channel_type == BOLLINGER_RANGE)
    return LoadBollingerIndicatorForTimeframe(trend_timeframe);
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

  if(Strategy_Trend_Trend_Mode == TREND_OFF)
  {
    Print("Trend filter disabled; skipping trend indicator loading.");
    return;
  }

  Trend_Filter_Timeframe = ResolveTrendTimeframe();

  StrategyEntryEvaluationModes trend_entry_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_TREND);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(trend_entry_eval) ||
                         Trend_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Trend_Trend_Mode) ||
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

void LoadMacroIndicators()
{
  ResetMacroIndicators();

  if(!MacroContextEnabled())
  {
    Print("Macro context disabled; skipping macro indicator loading.");
    return;
  }

  StrategyEntryEvaluationModes macro_entry_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_MACRO);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(macro_entry_eval) ||
                          Macro_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Macro_Trend_Mode) ||
                          Macro_Alligator_Slope_Filter);
  bool need_stochastic = Macro_Stochastic_Slope_Filter;

  if(!need_bpercent && !need_alligator && !need_stochastic)
  {
    Print("Macro filters disabled; skipping macro indicator loading.");
    return;
  }

  Macro_Filter_Timeframe = ResolveMacroTimeframe();

  bool bpercent_loaded  = true;
  bool alligator_loaded = true;
  bool stoch_loaded     = true;

  if(need_bpercent)
    bpercent_loaded = LoadMacroBPercentIndicator(Macro_Filter_Timeframe);

  if(need_alligator)
    alligator_loaded = LoadMacroAlligatorIndicator(Macro_Filter_Timeframe);

  if(need_stochastic)
    stoch_loaded = LoadMacroStochasticIndicator(Macro_Filter_Timeframe);

  if((need_bpercent && !bpercent_loaded) ||
     (need_alligator && !alligator_loaded) ||
     (need_stochastic && !stoch_loaded))
  {
    if(!bpercent_loaded)
      MacroBPercentIndicatorHandle = IndicatorsHandleInfo();
    if(!alligator_loaded)
      MacroAlligatorIndicatorHandle = IndicatorsHandleInfo();
    if(!stoch_loaded)
      MacroStochIndicatorHandle = IndicatorsHandleInfo();
  }
}

void LoadSessionIndicators()
{
  ResetSessionIndicators();

  if(!SessionContextEnabled())
  {
    Print("Session context disabled; skipping session indicator loading.");
    return;
  }

  StrategyEntryEvaluationModes session_entry_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_SESSION);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(session_entry_eval) ||
                          Session_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Session_Trend_Mode) ||
                          Session_Alligator_Slope_Filter);
  bool need_stochastic = Session_Stochastic_Slope_Filter;

  if(!need_bpercent && !need_alligator && !need_stochastic)
  {
    Print("Session filters disabled; skipping session indicator loading.");
    return;
  }

  Session_Filter_Timeframe = ResolveSessionTimeframe();

  bool bpercent_loaded  = true;
  bool alligator_loaded = true;
  bool stoch_loaded     = true;

  if(need_bpercent)
    bpercent_loaded = LoadSessionBPercentIndicator(Session_Filter_Timeframe);

  if(need_alligator)
    alligator_loaded = LoadSessionAlligatorIndicator(Session_Filter_Timeframe);

  if(need_stochastic)
    stoch_loaded = LoadSessionStochasticIndicator(Session_Filter_Timeframe);

  if((need_bpercent && !bpercent_loaded) ||
     (need_alligator && !alligator_loaded) ||
     (need_stochastic && !stoch_loaded))
  {
    if(!bpercent_loaded)
      SessionBPercentIndicatorHandle = IndicatorsHandleInfo();
    if(!alligator_loaded)
      SessionAlligatorIndicatorHandle = IndicatorsHandleInfo();
    if(!stoch_loaded)
      SessionStochIndicatorHandle = IndicatorsHandleInfo();
  }
}

bool TrendFilterIndicatorsAvailable()
{
  if(!TrendContextEnabled() || Strategy_Trend_Trend_Mode == TREND_OFF)
    return true;
  StrategyEntryEvaluationModes trend_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_TREND);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(trend_eval) ||
                         Trend_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Trend_Trend_Mode) ||
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

bool MacroFilterIndicatorsAvailable()
{
  if(!MacroContextEnabled() || Strategy_Macro_Trend_Mode == TREND_OFF)
  {
    if(!Macro_BPercent_Slope_Filter &&
       !Macro_Stochastic_Slope_Filter &&
       !Macro_Alligator_Slope_Filter)
      return true;
  }

  if(!MacroContextEnabled())
    return true;

  StrategyEntryEvaluationModes macro_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_MACRO);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(macro_eval) ||
                         Macro_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Macro_Trend_Mode) ||
                         Macro_Alligator_Slope_Filter);
  bool need_stochastic = Macro_Stochastic_Slope_Filter;

  if(need_bpercent && MacroBPercentIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_alligator && MacroAlligatorIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_stochastic && MacroStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  return true;
}

bool SessionFilterIndicatorsAvailable()
{
  if(!SessionContextEnabled() || Strategy_Session_Trend_Mode == TREND_OFF)
  {
    if(!Session_BPercent_Slope_Filter &&
       !Session_Stochastic_Slope_Filter &&
       !Session_Alligator_Slope_Filter)
      return true;
  }

  if(!SessionContextEnabled())
    return true;

  StrategyEntryEvaluationModes session_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_SESSION);
  bool need_bpercent  = (EntryEvaluationUsesAnyBPercent(session_eval) ||
                         Session_BPercent_Slope_Filter);
  bool need_alligator = (TrendModeUsesAlligator(Strategy_Session_Trend_Mode) ||
                         Session_Alligator_Slope_Filter);
  bool need_stochastic = Session_Stochastic_Slope_Filter;

  if(need_bpercent && SessionBPercentIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_alligator && SessionAlligatorIndicatorHandle.indicator_handle == INVALID_HANDLE)
    return false;
  if(need_stochastic && SessionStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
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

void LoadMacroStructureFilterIndicator()
{
  ResetMacroStructureIndicator();

  if(!MacroStructureNeedsDedicatedHandle())
    return;

  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  if(Macro_Structure_Filter_Timeframe == strategy_tf)
  {
    Print("Macro structure timeframe matches strategy timeframe; reusing strategy structure handles.");
    return;
  }

  if(!LoadMacroStructureIndicator(Macro_Structure_Filter_Timeframe))
    ResetMacroStructureIndicator();
}

void LoadSessionStructureFilterIndicator()
{
  ResetSessionStructureIndicator();

  if(!SessionStructureNeedsDedicatedHandle())
    return;

  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  if(Session_Structure_Filter_Timeframe == strategy_tf)
  {
    Print("Session structure timeframe matches strategy timeframe; reusing strategy structure handles.");
    return;
  }

  if(!LoadSessionStructureIndicator(Session_Structure_Filter_Timeframe))
    ResetSessionStructureIndicator();
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  PrepareIndicatorPeriods();

  StrategyEntryEvaluationModes base_entry_eval = StrategyContextEntryEvaluation(CONTEXT_SLOT_BASE);
  bool base_mode_uses_bpercent  = EntryEvaluationUsesAnyBPercent(base_entry_eval);
  bool base_mode_uses_alligator = TrendModeUsesAlligator(Strategy_Base_Trend_Mode);
  bool base_bpercent_required   = base_mode_uses_bpercent || Base_BPercent_Slope_Filter;
  bool trailing_requires_alligator = (Grid_Trailing_Strategy_Mode == TRAILING_LIPS_MA);
  bool trailing_requires_channel   = (Grid_Trailing_Strategy_Mode == TRAILING_ATR_BASED);
  bool risk_requires_alligator     = (Grid_Risk_Trend_Mode != GRID_RM_TREND_OFF);
  bool base_alligator_required  = base_mode_uses_alligator || Base_Alligator_Slope_Filter ||
                                  trailing_requires_alligator || risk_requires_alligator;
  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  Trend_Structure_Filter_Timeframe = ResolveTrendStructureTimeframe();
  Macro_Structure_Filter_Timeframe = ResolveMacroStructureTimeframe();
  Session_Structure_Filter_Timeframe = ResolveSessionStructureTimeframe();
  Trailing_Indicator_Timeframe = ResolveTrailingStrategyTimeframe();
  Risk_Trend_Timeframe = ResolveRiskTrendTimeframe();

  bool require_structure_indicators = true;

  bool strategy_uses_channel = (Grid_Base_Strategy_Type != POINTS_RANGE);
  bool require_channel_filters = Base_Channel_MA_Filter || Trend_Channel_MA_Filter ||
                                 Macro_Channel_MA_Filter || Session_Channel_MA_Filter;
  bool load_channel_indicators = strategy_uses_channel ||
                                 trailing_requires_channel ||
                                 require_channel_filters;

  GridBaseStrategyTypes channel_strategy_type = ResolveChannelStrategyFromInputs();
  if(channel_strategy_type == POINTS_RANGE)
    channel_strategy_type = ResolveChannelStrategyFromInputs();

  bool overlay_bollinger_required = (Enable_Show_Indicators &&
                                     Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_BOLLINGER);
  bool overlay_keltner_required = (Enable_Show_Indicators &&
                                   Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_KELTNER);
  bool overlay_atr_required = (Enable_Show_Indicators &&
                               Strategy_Channel_Indicator_Type == CHANNEL_INDICATOR_ATR);

  TesterHideIndicators(!Enable_Show_Indicators);

  int resolved_bpercent_period = IndicatorPeriods[0];
  PrintFormat("Strategy context | TF=%s | Channel=%s | EntryMode=%s | EntryEval=%s | BasePeriod=%d | ChannelPeriod=%d | SolidPeriod=%d | Direction=%s",
              EnumToString(Strategy_Timeframe),
              StrategyChannelIndicatorLabel(),
              EnumToString(Strategy_Global_Entry_Mode),
              EnumToString(StrategyContextEntryEvaluation(CONTEXT_SLOT_BASE)),
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

  bool need_bollinger_channels = ((channel_strategy_type == BOLLINGER_RANGE) && load_channel_indicators) ||
                                 overlay_bollinger_required;
  bool need_keltner_channels   = ((channel_strategy_type == KELTNER_RANGE) && load_channel_indicators) ||
                                 overlay_keltner_required;
  bool need_atr_channels       = ((channel_strategy_type == ATR_RANGE) && load_channel_indicators) ||
                                 overlay_atr_required;

  if(need_bollinger_channels)
    LoadAllBandsIndicators();
  if(need_keltner_channels)
    LoadAllKeltnerIndicators();
  if(need_atr_channels)
    LoadAllATRIndicators();

  if(load_channel_indicators)
  {
    if(Trend_Channel_MA_Filter)
    {
      ENUM_TIMEFRAMES trend_channel_tf = Trend_Strategy_Timeframe;
      if(trend_channel_tf == PERIOD_CURRENT)
        trend_channel_tf = Strategy_Timeframe;
      if(trend_channel_tf != strategy_tf)
        LoadChannelIndicatorForTimeframe(channel_strategy_type, trend_channel_tf);
    }
    if(Macro_Channel_MA_Filter)
    {
      ENUM_TIMEFRAMES macro_channel_tf = Macro_Strategy_Timeframe;
      if(macro_channel_tf == PERIOD_CURRENT)
        macro_channel_tf = Strategy_Timeframe;
      if(macro_channel_tf != strategy_tf)
        LoadChannelIndicatorForTimeframe(channel_strategy_type, macro_channel_tf);
    }
    if(Session_Channel_MA_Filter)
    {
      ENUM_TIMEFRAMES session_channel_tf = Session_Strategy_Timeframe;
      if(session_channel_tf == PERIOD_CURRENT)
        session_channel_tf = Strategy_Timeframe;
      if(session_channel_tf != strategy_tf)
        LoadChannelIndicatorForTimeframe(channel_strategy_type, session_channel_tf);
    }
  }
  else if(!overlay_bollinger_required && !overlay_keltner_required && !overlay_atr_required)
  {
    Print("Volatility indicator strategy disabled and trailing indicator mode inactive; skipping channel indicator loading.");
  }

  LoadAllBodyMAIndicators();
  LoadTrendIndicators();
  LoadMacroIndicators();
  LoadSessionIndicators();
  LoadTrendStructureFilterIndicator();
  LoadMacroStructureFilterIndicator();
  LoadSessionStructureFilterIndicator();
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
                                                                  ResolveChannelPercentIndicatorPath(),
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
        Print("ERROR LOADING ",
              StrategyChannelIndicatorLabel(),
              " CHANNEL PERCENT INDICATOR: ",
              EnumToString(trend_timeframe),
              " | PERIOD: ",
              IndicatorPeriods[period_index]);
        TesterStop();
        break;
      }

      Print("LOADED ",
            StrategyChannelIndicatorLabel(),
            " CHANNEL PERCENT INDICATOR SUCCESSFULLY: ",
            EnumToString(trend_timeframe),
            " | PERIOD: ",
            IndicatorPeriods[period_index]);

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
