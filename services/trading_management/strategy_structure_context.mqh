//+------------------------------------------------------------------+
//|                          strategy_structure_context.mqh          |
//| Base strategy context for the refounded structure pipeline.       |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRATEGY_STRUCTURE_CONTEXT_MQH_

struct StrategyStructureLayerContext
{
  bool enabled;
  bool uses_trend_dataset;

  StrategyStructureLayerContext()
  {
    enabled            = false;
    uses_trend_dataset = false;
  }
};

inline int ResolveStochStructurePeriod();

inline StrategyStructureLayerContext BuildDisabledStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.enabled            = false;
  ctx.uses_trend_dataset = false;
  return ctx;
}

inline StrategyStructureLayerContext BuildBaseStructureLayerContext()
{
  StrategyStructureLayerContext ctx;
  ctx.enabled            = (ResolveStochStructurePeriod() >= 3);
  ctx.uses_trend_dataset = false;
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
  return false;
}

inline bool StructureFiltersRequested(const StrategyStructureLayerContext &,
                                      const SignalTypes)
{
  return false;
}

inline bool StructureTypeFiltersRequested(const StrategyStructureLayerContext &)
{
  return false;
}

inline bool AnyStructureGuardEnabled()
{
  return (ResolveStochStructurePeriod() >= 3);
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

  return (context == CONTEXT_SLOT_BASE);
}

inline int ResolveStochStructurePeriod()
{
  int period = (int)Stoch_Structure_Period_Type;
  if(period < 3)
    period = 3;
  return period;
}

inline bool StrategyContextFreshStructureEnabled(const StrategyContextTypes)
{
  return false;
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
