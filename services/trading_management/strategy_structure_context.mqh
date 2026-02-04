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
           mode == BEARISH_STRUCT_OFF);
}

inline int ResolveStochStructurePeriod();

inline StrategyStructureLayerContext BuildDisabledStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.min_extern_structures   = 0;
  ctx.support_filter          = SUPPORT_DISABLED;
  ctx.resistance_filter       = RESISTANCE_DISABLED;
  ctx.support_min_retests     = 0;
  ctx.resistance_min_retests  = 0;
  ctx.first_structure_filter  = BULLISH_STRUCT_OFF;
  ctx.second_structure_filter = BEARISH_STRUCT_OFF;
  ctx.third_structure_filter  = BULLISH_STRUCT_OFF;
  ctx.fourth_structure_filter = BEARISH_STRUCT_OFF;
  ctx.enabled                 = false;
  ctx.uses_trend_dataset      = false;
  return ctx;
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
  ctx.enabled                = (ResolveStochStructurePeriod() >= 3);
  ctx.uses_trend_dataset     = false;
  return ctx;
}

inline StrategyStructureLayerContext BuildTrendStructureLayerContext()
{
  return BuildDisabledStructureLayerContext();
}

inline StrategyStructureLayerContext BuildMacroStructureLayerContext()
{
  return BuildDisabledStructureLayerContext();
}

inline StrategyStructureLayerContext BuildSessionStructureLayerContext()
{
  return BuildDisabledStructureLayerContext();
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
  StrategyStructureLayerContext base_ctx = BuildBaseStructureLayerContext();
  return StructureFiltersRequested(base_ctx) ||
         StructureTypeFiltersRequested(base_ctx);
}

inline bool TrendContextEnabled()
{
  return false;
}

inline bool MacroContextEnabled()
{
  return false;
}

inline bool SessionContextEnabled()
{
  return false;
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
  return (context == CONTEXT_SLOT_BASE);
}

inline bool ContextRequiresStructure(const StrategyContextTypes context,
                                     const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;

  // Base spacing needs structure distances when using the fib level grid mode
  if(context == CONTEXT_SLOT_BASE && Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
    return true;

  return StructureFiltersRequested(ctx) ||
         StructureTypeFiltersRequested(ctx) ||
         StrategyContextFreshStructureEnabled(context);
}

inline int ResolveStochStructurePeriod()
{
  int period = (int)Stoch_Structure_Period_Type;
  if(period < 3)
    period = 3;
  return period;
}

inline bool StrategyContextFreshStructureEnabled(const StrategyContextTypes context)
{
  return (context == CONTEXT_SLOT_BASE) ? Base_Fresh_Structure_Time : false;
}

inline bool StrategyContextFirstStructureUsesClosePercent(const StrategyContextTypes context)
{
  return (context == CONTEXT_SLOT_BASE) ? Base_First_Structure_Close_Percent : false;
}

inline ENUM_TIMEFRAMES StrategyContextTimeframe(const StrategyContextTypes context)
{
  return Strategy_Timeframe;
}

inline ENUM_TIMEFRAMES StrategyContextStructureTimeframe(const StrategyContextTypes context)
{
  return Strategy_Timeframe;
}

inline StrategyStructureLayerContext BuildStructureLayerForContext(const StrategyContextTypes context)
{
  return (context == CONTEXT_SLOT_BASE)
           ? BuildBaseStructureLayerContext()
           : BuildDisabledStructureLayerContext();
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
