//+------------------------------------------------------------------+
//|                          strategy_structure_context.mqh          |
//| Mirrors structure-related inputs for strategy context layers.    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_

struct StrategyStructureLayerContext
{
  TrendStructureCompoundModes structure_compound_filter;
  bool                        enabled;
  bool                        uses_trend_dataset;
  bool                        support_resistance_retest_chain_enabled;
  int                         support_resistance_retest_chain_count;
  double                      support_resistance_retest_chain_range_percent;

  StrategyStructureLayerContext()
  {
    structure_compound_filter = COMPOUND_MODE_OFF;
    enabled                   = false;
    uses_trend_dataset        = false;
    support_resistance_retest_chain_enabled = false;
    support_resistance_retest_chain_count = 1;
    support_resistance_retest_chain_range_percent = 10.0;
  }
};

StructureTouchPolicyModes g_structure_touch_policy_runtime = ALLOW_RETEST;
bool g_structure_touch_policy_runtime_override = false;
TrendStructureCompoundModes g_structure_compound_filter_runtime = COMPOUND_MODE_OFF;
bool g_structure_compound_filter_runtime_override = false;
bool g_support_resistance_retest_chain_runtime_enabled = false;
int g_support_resistance_retest_chain_runtime_count = 1;
double g_support_resistance_retest_chain_runtime_range_percent = 10.0;
bool g_support_resistance_retest_chain_runtime_override = false;

inline bool StructureCompoundFilterIsEnabled(const TrendStructureCompoundModes mode)
{
  return (mode != COMPOUND_MODE_OFF);
}

inline bool StructureCompoundFilterIsBreakoutMode(const TrendStructureCompoundModes mode)
{
  return (mode == COMPOUND_MODE_BREAKOUT_READY_BUY ||
          mode == COMPOUND_MODE_BREAKOUT_READY_SELL);
}

inline bool SupportResistanceRetestChainEnabled(const bool enabled)
{
  return enabled;
}

inline int ResolveSupportResistanceRetestChainCount(const int count)
{
  if(count <= 0)
    return 1;
  return count;
}

inline double ResolveSupportResistanceRetestChainRangePercent(const double range_percent)
{
  if(!MathIsValidNumber(range_percent) || range_percent <= 0.0)
    return 10.0;
  return range_percent;
}

inline bool ResolveBaseSupportResistanceRetestChainEnabled()
{
  if(g_support_resistance_retest_chain_runtime_override)
    return g_support_resistance_retest_chain_runtime_enabled;

  return SupportResistanceRetestChainEnabled(Support_Resistance_Retest_Chain_Enabled);
}

inline int ResolveBaseSupportResistanceRetestChainCount()
{
  if(g_support_resistance_retest_chain_runtime_override)
    return ResolveSupportResistanceRetestChainCount(g_support_resistance_retest_chain_runtime_count);

  return ResolveSupportResistanceRetestChainCount(Support_Resistance_Retest_Chain_Count);
}

inline double ResolveBaseSupportResistanceRetestChainRangePercent()
{
  if(g_support_resistance_retest_chain_runtime_override)
    return ResolveSupportResistanceRetestChainRangePercent(g_support_resistance_retest_chain_runtime_range_percent);

  return ResolveSupportResistanceRetestChainRangePercent(Support_Resistance_Retest_Chain_Range_Percent);
}

inline void SetSupportResistanceRetestChainRuntime(const bool enabled,
                                                   const int count,
                                                   const double range_percent)
{
  g_support_resistance_retest_chain_runtime_enabled = enabled;
  g_support_resistance_retest_chain_runtime_count = count;
  g_support_resistance_retest_chain_runtime_range_percent = range_percent;
  g_support_resistance_retest_chain_runtime_override = true;
}

inline void ClearSupportResistanceRetestChainRuntimeOverride()
{
  g_support_resistance_retest_chain_runtime_override = false;
}

inline bool SupportResistanceRetestChainFilterRequested(const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;

  return ctx.support_resistance_retest_chain_enabled;
}

inline int ResolveStochStructurePeriod();

inline StrategyStructureLayerContext BuildDisabledStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.structure_compound_filter = COMPOUND_MODE_OFF;
  ctx.enabled                   = false;
  ctx.uses_trend_dataset        = false;
  ctx.support_resistance_retest_chain_enabled = false;
  ctx.support_resistance_retest_chain_count = 1;
  ctx.support_resistance_retest_chain_range_percent = 10.0;
  return ctx;
}

inline StrategyStructureLayerContext BuildBaseStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.structure_compound_filter = g_structure_compound_filter_runtime_override
                                    ? g_structure_compound_filter_runtime
                                    : Base_Structure_Compound_Filter;
  ctx.enabled                   = (ResolveStochStructurePeriod() >= 3);
  ctx.uses_trend_dataset        = false;
  ctx.support_resistance_retest_chain_enabled = ResolveBaseSupportResistanceRetestChainEnabled();
  ctx.support_resistance_retest_chain_count = ResolveBaseSupportResistanceRetestChainCount();
  ctx.support_resistance_retest_chain_range_percent = ResolveBaseSupportResistanceRetestChainRangePercent();
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

inline bool StructureFiltersRequested(const StrategyStructureLayerContext &)
{
  // Legacy retest/external-break filters were removed in the compound migration.
  return false;
}

inline bool StructureFiltersRequested(const StrategyStructureLayerContext &,
                                      const SignalTypes)
{
  return false;
}

inline bool StructureTypeFiltersRequested(const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return false;
  return StructureCompoundFilterIsEnabled(ctx.structure_compound_filter);
}

inline int ResolveRetestRequirement(const StrategyStructureLayerContext &,
                                    const SignalTypes,
                                    const int)
{
  return 0;
}

inline bool AnyStructureGuardEnabled()
{
  StrategyStructureLayerContext base_ctx = BuildBaseStructureLayerContext();
  return StructureTypeFiltersRequested(base_ctx) ||
         SupportResistanceRetestChainFilterRequested(base_ctx) ||
         StrategyContextFreshStructureEnabled(CONTEXT_SLOT_BASE);
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

  // Current entry trigger modes are structure-driven and always need a snapshot.
  if(context == CONTEXT_SLOT_BASE &&
     (Structure_Trigger_Entry == LEVELS_AS_LIMITS ||
      Structure_Trigger_Entry == LEVEL_AS_ZONE))
    return true;

  if(context == CONTEXT_SLOT_BASE && Base_Strategy_Type == FIB_LEVEL_RANGE)
    return true;

  return StructureTypeFiltersRequested(ctx) ||
         SupportResistanceRetestChainFilterRequested(ctx) ||
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

inline void SetStructureTouchPolicyRuntime(const StructureTouchPolicyModes mode)
{
  g_structure_touch_policy_runtime = mode;
  g_structure_touch_policy_runtime_override = true;
}

inline void ClearStructureTouchPolicyRuntimeOverride()
{
  g_structure_touch_policy_runtime_override = false;
}

inline void SetStructureCompoundFilterRuntime(const TrendStructureCompoundModes mode)
{
  g_structure_compound_filter_runtime = mode;
  g_structure_compound_filter_runtime_override = true;
}

inline void ClearStructureCompoundFilterRuntimeOverride()
{
  g_structure_compound_filter_runtime_override = false;
}

inline StructureTouchPolicyModes ResolveBaseStructureTouchPolicy()
{
  return g_structure_touch_policy_runtime_override
           ? g_structure_touch_policy_runtime
           : Structure_Touch_Policy;
}

inline StructureTouchPolicyModes StrategyContextTouchPolicy(const StrategyContextTypes context)
{
  return (context == CONTEXT_SLOT_BASE) ? ResolveBaseStructureTouchPolicy() : ALLOW_RETEST;
}

inline bool StrategyContextFirstTouchOnly(const StrategyContextTypes context)
{
  return (StrategyContextTouchPolicy(context) == FIRST_TOUCH_ONLY);
}

inline bool StrategyContextFirstStructureUsesClosePercent(const StrategyContextTypes)
{
  return false;
}

inline ENUM_TIMEFRAMES StrategyContextTimeframe(const StrategyContextTypes)
{
  return Strategy_Timeframe;
}

inline ENUM_TIMEFRAMES StrategyContextStructureTimeframe(const StrategyContextTypes)
{
  return Strategy_Timeframe;
}

inline StrategyStructureLayerContext BuildStructureLayerForContext(const StrategyContextTypes context)
{
  return (context == CONTEXT_SLOT_BASE)
           ? BuildBaseStructureLayerContext()
           : BuildDisabledStructureLayerContext();
}

inline bool StrategyContextUsesBreakoutCompoundMode(const StrategyContextTypes context)
{
  StrategyStructureLayerContext ctx = BuildStructureLayerForContext(context);
  if(!ctx.enabled)
    return false;
  return StructureCompoundFilterIsBreakoutMode(ctx.structure_compound_filter);
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
