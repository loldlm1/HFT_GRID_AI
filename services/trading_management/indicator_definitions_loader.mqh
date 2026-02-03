//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo TrendStructStochIndicatorHandle;
IndicatorsHandleInfo MacroStructStochIndicatorHandle;
IndicatorsHandleInfo SessionStructStochIndicatorHandle;
ENUM_TIMEFRAMES     Trend_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Macro_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Session_Structure_Filter_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Trailing_Indicator_Timeframe = PERIOD_M5;
ENUM_TIMEFRAMES     Risk_Trend_Timeframe = PERIOD_M5;
int total_tf_list_load = 0;

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

ENUM_TIMEFRAMES ResolveRiskTrendSourceTimeframe()
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

ENUM_TIMEFRAMES ResolveRiskTrendTimeframe()
{
  ENUM_TIMEFRAMES configured_tf = Grid_Risk_Trend_Timeframe;
  if(configured_tf != PERIOD_CURRENT)
  {
    if(IsStrategyTimeframeSupported(configured_tf))
      return configured_tf;
    PrintFormat("Risk trend timeframe %d not supported. Falling back to context source %s.",
                (int)configured_tf,
                EnumToString(Grid_Risk_Timeframe_Source));
  }
  return ResolveRiskTrendSourceTimeframe();
}

void ResetTrendStructureIndicator()
{
  TrendStructStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetMacroStructureIndicator()
{
  MacroStructStochIndicatorHandle = IndicatorsHandleInfo();
}

void ResetSessionStructureIndicator()
{
  SessionStructStochIndicatorHandle = IndicatorsHandleInfo();
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

bool LoadTrendStructureIndicator(const ENUM_TIMEFRAMES trend_tf)
{
  return LoadContextStructureIndicator(trend_tf,
                                       TrendStructStochIndicatorHandle,
                                       "Trend");
}

bool LoadMacroStructureIndicator(const ENUM_TIMEFRAMES macro_tf)
{
  return LoadContextStructureIndicator(macro_tf,
                                       MacroStructStochIndicatorHandle,
                                       "Macro");
}

bool LoadSessionStructureIndicator(const ENUM_TIMEFRAMES session_tf)
{
  return LoadContextStructureIndicator(session_tf,
                                       SessionStructStochIndicatorHandle,
                                       "Session");
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

void LoadTrendStructureFilterIndicator()
{
  if(!TrendStructureNeedsDedicatedHandle())
  {
    ResetTrendStructureIndicator();
    return;
  }

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
  if(!MacroStructureNeedsDedicatedHandle())
  {
    ResetMacroStructureIndicator();
    return;
  }

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
  if(!SessionStructureNeedsDedicatedHandle())
  {
    ResetSessionStructureIndicator();
    return;
  }

  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  if(Session_Structure_Filter_Timeframe == strategy_tf)
  {
    Print("Session structure timeframe matches strategy timeframe; reusing strategy structure handles.");
    return;
  }

  if(!LoadSessionStructureIndicator(Session_Structure_Filter_Timeframe))
    ResetSessionStructureIndicator();
}

void LoadAllStructStochIndicators()
{
  if(ArraySize(Strategy_TF_List) <= 0)
    return;

  int total = ArraySize(Strategy_TF_List);
  for(int i = 0; i < total; i++)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo struct_stoch_indicator_handle_loaded;
    struct_stoch_indicator_handle_loaded.indicator_period = ResolveStochStructurePeriod();
    struct_stoch_indicator_handle_loaded.indicator_handle = iCustom(_Symbol,
                                                                     trend_timeframe,
                                                                     "Examples\\Stochastic_Structure.ex5",
                                                                     struct_stoch_indicator_handle_loaded.indicator_period,
                                                                     3,
                                                                     3,
                                                                     STO_CLOSECLOSE);
    struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STRUCTURE INDICATOR: ", EnumToString(trend_timeframe),
            " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      continue;
    }

    Print("LOADED STRUCTURE INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe),
          " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
  }
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  LoadStructureFibonacciLevels(Structure_Fibonacci_Levels,
                               "23.6,38.2,50.0,61.8,78.6,100.0");

  ENUM_TIMEFRAMES strategy_tf = Strategy_TF_List[0];
  Trend_Structure_Filter_Timeframe = ResolveTrendStructureTimeframe();
  Macro_Structure_Filter_Timeframe = ResolveMacroStructureTimeframe();
  Session_Structure_Filter_Timeframe = ResolveSessionStructureTimeframe();
  Trailing_Indicator_Timeframe = ResolveTrailingStrategyTimeframe();
  Risk_Trend_Timeframe = ResolveRiskTrendTimeframe();

  bool stoch_structure_enabled = (Stoch_Structure_Period_Type != STOCH_STRUCTURE_PERIOD_OFF);
  ArrayResize(ExtStructStochIndicatorsHandle, 0);

  if(stoch_structure_enabled)
  {
    LoadAllStructStochIndicators();
  }
  else
  {
    Print("Structure indicators skipped (structure period off).");
  }

  LoadTrendStructureFilterIndicator();
  LoadMacroStructureFilterIndicator();
  LoadSessionStructureFilterIndicator();

  PrintFormat("Strategy context | TF=%s | StructurePeriod=%d | Direction=%s",
              EnumToString(Strategy_Timeframe),
              (int)Stoch_Structure_Period_Type,
              EnumToString(Strategy_Direction_Mode));
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
