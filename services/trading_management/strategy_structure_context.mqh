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
};

StructureTouchPolicyModes g_structure_touch_policy_runtime = ALLOW_RETEST;
bool g_structure_touch_policy_runtime_override = false;

inline bool StructureCompoundFilterIsEnabled(const TrendStructureCompoundModes mode)
{
  return (mode != COMPOUND_MODE_OFF);
}

inline int ResolveStochStructurePeriod();

inline StrategyStructureLayerContext BuildDisabledStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.structure_compound_filter = COMPOUND_MODE_OFF;
  ctx.enabled                   = false;
  ctx.uses_trend_dataset        = false;
  return ctx;
}

inline StrategyStructureLayerContext BuildBaseStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.structure_compound_filter = Base_Structure_Compound_Filter;
  ctx.enabled                   = (ResolveStochStructurePeriod() >= 3);
  ctx.uses_trend_dataset        = false;
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

  if(context == CONTEXT_SLOT_BASE && Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
    return true;

  return StructureTypeFiltersRequested(ctx) ||
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

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
