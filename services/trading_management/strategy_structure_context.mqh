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
  bool                        enabled;
  bool                        uses_trend_dataset;
};

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
  ctx.enabled                = true;
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
  ctx.enabled                = (Trend_Strategy_Timeframe != PERIOD_CURRENT);
  ctx.uses_trend_dataset     = ctx.enabled && (Trend_Strategy_Timeframe != Strategy_Timeframe);
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

inline bool StructureTypeFiltersRequested(const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;
  bool bullish_active =
    (ctx.first_structure_filter == BULLISH_STRUCT_LL) ||
    (ctx.first_structure_filter == BULLISH_STRUCT_LH) ||
    (ctx.first_structure_filter == BULLISH_STRUCT_LL_LH);

  bool bearish_active =
    (ctx.second_structure_filter == BEARISH_STRUCT_HH) ||
    (ctx.second_structure_filter == BEARISH_STRUCT_HL) ||
    (ctx.second_structure_filter == BEARISH_STRUCT_HH_HL);

  return bullish_active || bearish_active;
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
  return StructureFiltersRequested(base_ctx) ||
         StructureFiltersRequested(trend_ctx) ||
         StructureTypeFiltersRequested(base_ctx) ||
         StructureTypeFiltersRequested(trend_ctx);
}

inline bool TrendContextEnabled()
{
  return (Trend_Strategy_Timeframe != PERIOD_CURRENT);
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
