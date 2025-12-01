//+------------------------------------------------------------------+
//|                          strategy_structure_context.mqh          |
//| Mirrors structure-related inputs for base/trend strategy layers. |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_

struct StrategyStructureLayerContext
{
  int                         min_extern_structures;
  SupportRetestFilterModes    support_filter;
  ResistanceRetestFilterModes resistance_filter;
  int                         support_min_retests;
  int                         resistance_min_retests;
  TrendStructureFilterModes   first_structure_filter;
  TrendStructureFilterModes   second_structure_filter;
  TrendStructureFilterModes   third_structure_filter;
  TrendStructureFilterModes   fourth_structure_filter;
  bool                        enabled;
  bool                        uses_trend_dataset;
};

inline bool StructureFilterIsEnabled(const TrendStructureFilterModes mode)
{
  return !(mode == BULLISH_STRUCT_OFF ||
           mode == BULLISH_STRUCT_OFF_FINAL ||
           mode == BEARISH_STRUCT_OFF ||
           mode == BEARISH_STRUCT_OFF_FINAL);
}

inline StrategyStructureLayerContext BuildBaseStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.min_extern_structures  = Base_Min_Extern_Structures_Broken;
  ctx.support_filter         = Base_Support_Filter;
  ctx.resistance_filter      = Base_Resistance_Filter;
  ctx.support_min_retests    = Base_Support_Retest_Min_Count;
  ctx.resistance_min_retests = Base_Resistance_Retest_Min_Count;
  ctx.first_structure_filter = Base_First_Structure_Filter;
  ctx.second_structure_filter = Base_Second_Structure_Filter;
  ctx.third_structure_filter  = Base_Third_Structure_Filter;
  ctx.fourth_structure_filter = Base_Fourth_Structure_Filter;
  ctx.enabled                = (Stoch_Structure_Period_Type != STOCH_STRUCTURE_PERIOD_OFF);
  ctx.uses_trend_dataset     = false;
  return ctx;
}

inline StrategyStructureLayerContext BuildTrendStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.min_extern_structures  = Trend_Min_Extern_Structures_Broken;
  ctx.support_filter         = Trend_Support_Filter;
  ctx.resistance_filter      = Trend_Resistance_Filter;
  ctx.support_min_retests    = Trend_Support_Retest_Min_Count;
  ctx.resistance_min_retests = Trend_Resistance_Retest_Min_Count;
  ctx.first_structure_filter = Trend_First_Structure_Filter;
  ctx.second_structure_filter = Trend_Second_Structure_Filter;
  ctx.third_structure_filter  = Trend_Third_Structure_Filter;
  ctx.fourth_structure_filter = Trend_Fourth_Structure_Filter;
  ctx.enabled                = (Trend_Strategy_Timeframe != PERIOD_CURRENT) &&
                               (Stoch_Structure_Period_Type != STOCH_STRUCTURE_PERIOD_OFF);
  ctx.uses_trend_dataset     = ctx.enabled && (Trend_Strategy_Timeframe != Strategy_Timeframe);
  return ctx;
}

inline StrategyStructureLayerContext BuildMacroStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.min_extern_structures  = Macro_Min_Extern_Structures_Broken;
  ctx.support_filter         = Macro_Support_Filter;
  ctx.resistance_filter      = Macro_Resistance_Filter;
  ctx.support_min_retests    = Macro_Support_Retest_Min_Count;
  ctx.resistance_min_retests = Macro_Resistance_Retest_Min_Count;
  ctx.first_structure_filter = Macro_First_Structure_Filter;
  ctx.second_structure_filter = Macro_Second_Structure_Filter;
  ctx.third_structure_filter  = Macro_Third_Structure_Filter;
  ctx.fourth_structure_filter = Macro_Fourth_Structure_Filter;
  ctx.enabled                = (Macro_Strategy_Timeframe != PERIOD_CURRENT) &&
                               (Stoch_Structure_Period_Type != STOCH_STRUCTURE_PERIOD_OFF);
  ctx.uses_trend_dataset     = ctx.enabled;
  return ctx;
}

inline StrategyStructureLayerContext BuildSessionStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.min_extern_structures  = Session_Min_Extern_Structures_Broken;
  ctx.support_filter         = Session_Support_Filter;
  ctx.resistance_filter      = Session_Resistance_Filter;
  ctx.support_min_retests    = Session_Support_Retest_Min_Count;
  ctx.resistance_min_retests = Session_Resistance_Retest_Min_Count;
  ctx.first_structure_filter = Session_First_Structure_Filter;
  ctx.second_structure_filter = Session_Second_Structure_Filter;
  ctx.third_structure_filter  = Session_Third_Structure_Filter;
  ctx.fourth_structure_filter = Session_Fourth_Structure_Filter;
  ctx.enabled                = (Session_Strategy_Timeframe != PERIOD_CURRENT) &&
                               (Stoch_Structure_Period_Type != STOCH_STRUCTURE_PERIOD_OFF);
  ctx.uses_trend_dataset     = ctx.enabled;
  return ctx;
}

inline bool StructureFiltersRequested(const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;
  return (ctx.min_extern_structures > 0) ||
         (ctx.support_filter != SUPPORT_DISABLED) ||
         (ctx.resistance_filter != RESISTANCE_DISABLED);
}

inline bool StructureFiltersRequested(const StrategyStructureLayerContext &ctx,
                                      const SignalTypes signal_type)
{
  if(!ctx.enabled)
    return false;
  if(signal_type == BULLISH)
    return (ctx.support_filter != SUPPORT_DISABLED);
  if(signal_type == BEARISH)
    return (ctx.resistance_filter != RESISTANCE_DISABLED);
  return false;
}

inline bool StructureTypeFiltersRequested(const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;
  return StructureFilterIsEnabled(ctx.first_structure_filter)  ||
         StructureFilterIsEnabled(ctx.second_structure_filter) ||
         StructureFilterIsEnabled(ctx.third_structure_filter)  ||
         StructureFilterIsEnabled(ctx.fourth_structure_filter);
}

inline bool SupportFilterRequiresZone(const SupportRetestFilterModes mode,
                                      const int zone_index)
{
  if(mode == SUPPORT_DISABLED)
    return false;
  if(mode == SUPPORT_61)
    return zone_index == 0;
  if(mode == SUPPORT_78)
    return zone_index == 1;
  return false;
}

inline bool ResistanceFilterRequiresZone(const ResistanceRetestFilterModes mode,
                                         const int zone_index)
{
  if(mode == RESISTANCE_DISABLED)
    return false;
  if(mode == RESISTANCE_61)
    return zone_index == 0;
  if(mode == RESISTANCE_78)
    return zone_index == 1;
  return false;
}

inline int ResolveRetestRequirement(const StrategyStructureLayerContext &ctx,
                                    const SignalTypes signal_type,
                                    const int zone_index)
{
  if(!ctx.enabled)
    return 0;
  if(signal_type == BULLISH)
  {
    if(!SupportFilterRequiresZone(ctx.support_filter, zone_index))
      return 0;
    return MathMax(ctx.support_min_retests, 1);
  }
  if(signal_type == BEARISH)
  {
    if(!ResistanceFilterRequiresZone(ctx.resistance_filter, zone_index))
      return 0;
    return MathMax(ctx.resistance_min_retests, 1);
  }
  return 0;
}

inline bool AnyStructureGuardEnabled()
{
  StrategyStructureLayerContext base_ctx  = BuildBaseStructureLayerContext();
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  StrategyStructureLayerContext macro_ctx = BuildMacroStructureLayerContext();
  StrategyStructureLayerContext session_ctx = BuildSessionStructureLayerContext();
  return StructureFiltersRequested(base_ctx) ||
         StructureFiltersRequested(trend_ctx) ||
         StructureFiltersRequested(macro_ctx) ||
         StructureFiltersRequested(session_ctx) ||
         StructureTypeFiltersRequested(base_ctx) ||
         StructureTypeFiltersRequested(trend_ctx) ||
         StructureTypeFiltersRequested(macro_ctx) ||
         StructureTypeFiltersRequested(session_ctx);
}

inline bool TrendContextEnabled()
{
  return (Trend_Strategy_Timeframe != PERIOD_CURRENT);
}

inline bool MacroContextEnabled()
{
  return (Macro_Strategy_Timeframe != PERIOD_CURRENT);
}

inline bool SessionContextEnabled()
{
  return (Session_Strategy_Timeframe != PERIOD_CURRENT);
}

inline string StrategyContextLabel(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return "BASE";
    case CONTEXT_SLOT_TREND:
      return "TREND";
    case CONTEXT_SLOT_MACRO:
      return "MACRO";
    case CONTEXT_SLOT_SESSION:
      return "SESSION";
  }
  return "BASE";
}

inline bool StrategyContextEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return true;
    case CONTEXT_SLOT_TREND:
      return TrendContextEnabled();
    case CONTEXT_SLOT_MACRO:
      return MacroContextEnabled();
    case CONTEXT_SLOT_SESSION:
      return SessionContextEnabled();
  }
  return false;
}

inline int ResolveStochStructurePeriod()
{
  int period = (int)Stoch_Structure_Period_Type;
  if(period <= 0)
    period = 5;
  return period;
}

inline StrategyEntryChannelModes StrategyContextEntryEvaluation(const StrategyContextTypes context)
{
  StrategyEntryChannelModes context_mode = ENTRY_EVAL_OFF;
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      context_mode = Strategy_Base_Entry_Evaluation;
      break;
    case CONTEXT_SLOT_TREND:
      context_mode = Strategy_Trend_Entry_Evaluation;
      break;
    case CONTEXT_SLOT_MACRO:
      context_mode = Strategy_Macro_Entry_Evaluation;
      break;
    case CONTEXT_SLOT_SESSION:
      context_mode = Strategy_Session_Entry_Evaluation;
      break;
  }

  if(context_mode == ENTRY_EVAL_OFF)
    return ENTRY_EVAL_OFF;

  if(context_mode == ENTRY_EVAL_GLOBAL)
  {
    return Strategy_Global_Channel_Entry_Mode;
  }

  return context_mode;
}

inline StrategyTrendModes StrategyContextTrendMode(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Strategy_Base_Trend_Mode;
    case CONTEXT_SLOT_TREND:
      return Strategy_Trend_Trend_Mode;
    case CONTEXT_SLOT_MACRO:
      return Strategy_Macro_Trend_Mode;
    case CONTEXT_SLOT_SESSION:
      return Strategy_Session_Trend_Mode;
  }
  return TREND_OFF;
}

inline double StrategyContextIndicatorPercent(const StrategyContextTypes context)
{
  switch(Strategy_Global_Channel_Entry_Mode)
  {
    case ENTRY_MODE_BREAKOUT:
      return 0.0;
    case ENTRY_MODE_REVERSION:
      return 100.0;
    case ENTRY_MODE_MA_TREND:
    default:
      return 50.0;
  }
}

inline StrategyEntryChannelModes ResolveGlobalEntryTriggerMode()
{
  switch(Strategy_Global_Channel_Entry_Mode)
  {
    case ENTRY_MODE_BREAKOUT:  return ENTRY_MODE_BREAKOUT;
    case ENTRY_MODE_REVERSION: return ENTRY_MODE_REVERSION;
    case ENTRY_MODE_MA_TREND:
    default:
      return ENTRY_MODE_MA_TREND;
  }
}

inline bool StrategyContextChannelFilterEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_Channel_MA_Filter;
    case CONTEXT_SLOT_TREND:
      return Trend_Channel_MA_Filter;
    case CONTEXT_SLOT_MACRO:
      return Macro_Channel_MA_Filter;
    case CONTEXT_SLOT_SESSION:
      return Session_Channel_MA_Filter;
  }
  return false;
}

inline bool StrategyContextBPercentSlopeEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_BPercent_Slope_Filter;
    case CONTEXT_SLOT_TREND:
      return Trend_BPercent_Slope_Filter;
    case CONTEXT_SLOT_MACRO:
      return Macro_BPercent_Slope_Filter;
    case CONTEXT_SLOT_SESSION:
      return Session_BPercent_Slope_Filter;
  }
  return false;
}

inline bool StrategyContextStochasticSlopeEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_Stochastic_Slope_Filter;
    case CONTEXT_SLOT_TREND:
      return Trend_Stochastic_Slope_Filter;
    case CONTEXT_SLOT_MACRO:
      return Macro_Stochastic_Slope_Filter;
    case CONTEXT_SLOT_SESSION:
      return Session_Stochastic_Slope_Filter;
  }
  return false;
}

inline bool StrategyContextAlligatorSlopeEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_Alligator_Slope_Filter;
    case CONTEXT_SLOT_TREND:
      return Trend_Alligator_Slope_Filter;
    case CONTEXT_SLOT_MACRO:
      return Macro_Alligator_Slope_Filter;
    case CONTEXT_SLOT_SESSION:
      return Session_Alligator_Slope_Filter;
  }
  return false;
}

inline BodyVolumeFilterModes StrategyContextBodyVolumeMode(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_Body_Volume_Filter;
    case CONTEXT_SLOT_TREND:
      return Trend_Body_Volume_Filter;
    case CONTEXT_SLOT_MACRO:
      return Macro_Body_Volume_Filter;
    case CONTEXT_SLOT_SESSION:
      return Session_Body_Volume_Filter;
  }
  return BODY_VOLUME_OFF;
}

inline bool StrategyContextFreshStructureEnabled(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_Fresh_Structure_Time;
    case CONTEXT_SLOT_TREND:
      return Trend_Fresh_Structure_Time;
    case CONTEXT_SLOT_MACRO:
      return Macro_Fresh_Structure_Time;
    case CONTEXT_SLOT_SESSION:
      return Session_Fresh_Structure_Time;
  }
  return false;
}

inline bool StrategyContextFirstStructureUsesClosePercent(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Base_First_Structure_Close_Percent;
    case CONTEXT_SLOT_TREND:
      return Trend_First_Structure_Close_Percent;
    case CONTEXT_SLOT_MACRO:
      return Macro_First_Structure_Close_Percent;
    case CONTEXT_SLOT_SESSION:
      return Session_First_Structure_Close_Percent;
  }
  return false;
}

inline ENUM_TIMEFRAMES StrategyContextTimeframe(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Strategy_Timeframe;
    case CONTEXT_SLOT_TREND:
      return (Trend_Strategy_Timeframe == PERIOD_CURRENT) ? Strategy_Timeframe : Trend_Strategy_Timeframe;
    case CONTEXT_SLOT_MACRO:
      return (Macro_Strategy_Timeframe == PERIOD_CURRENT) ? Strategy_Timeframe : Macro_Strategy_Timeframe;
    case CONTEXT_SLOT_SESSION:
      return (Session_Strategy_Timeframe == PERIOD_CURRENT) ? Strategy_Timeframe : Session_Strategy_Timeframe;
  }
  return Strategy_Timeframe;
}

inline ENUM_TIMEFRAMES StrategyContextStructureTimeframe(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return Strategy_Timeframe;
    case CONTEXT_SLOT_TREND:
      return StrategyContextTimeframe(CONTEXT_SLOT_TREND);
    case CONTEXT_SLOT_MACRO:
      return StrategyContextTimeframe(CONTEXT_SLOT_MACRO);
    case CONTEXT_SLOT_SESSION:
      return StrategyContextTimeframe(CONTEXT_SLOT_SESSION);
  }
  return Strategy_Timeframe;
}

inline StrategyStructureLayerContext BuildStructureLayerForContext(const StrategyContextTypes context)
{
  switch(context)
  {
    case CONTEXT_SLOT_BASE:
      return BuildBaseStructureLayerContext();
    case CONTEXT_SLOT_TREND:
      return BuildTrendStructureLayerContext();
    case CONTEXT_SLOT_MACRO:
      return BuildMacroStructureLayerContext();
    case CONTEXT_SLOT_SESSION:
      return BuildSessionStructureLayerContext();
  }
  return BuildBaseStructureLayerContext();
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
