//+------------------------------------------------------------------+
//|                             market_signal_indicators.mqh        |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_

bool LoadStructureSnapshotFromHandle(IndicatorsHandleInfo &handle,
                                     StochasticMarketStructure &snapshot)
{
  if(handle.indicator_handle == INVALID_HANDLE)
    return false;
  snapshot = StochasticMarketStructure();
  return snapshot.InitStochMarketStructureValues(handle);
}

bool LoadStructureSnapshotForTimeframe(const ENUM_TIMEFRAMES tf,
                                       StochasticMarketStructure &snapshot)
{
  int total = ArraySize(ExtStructStochIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtStructStochIndicatorsHandle[i].indicator_timeframe != tf)
      continue;
    if(LoadStructureSnapshotFromHandle(ExtStructStochIndicatorsHandle[i], snapshot))
      return true;
  }
  return false;
}

bool LoadContextStructureSnapshot(const StrategyContextTypes context,
                                  StochasticMarketStructure &snapshot)
{
  ENUM_TIMEFRAMES tf = StrategyContextStructureTimeframe(context);
  if(context == CONTEXT_SLOT_TREND)
  {
    if(LoadStructureSnapshotFromHandle(TrendStructStochIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_MACRO)
  {
    if(LoadStructureSnapshotFromHandle(MacroStructStochIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_SESSION)
  {
    if(LoadStructureSnapshotFromHandle(SessionStructStochIndicatorHandle, snapshot))
      return true;
  }

  return LoadStructureSnapshotForTimeframe(tf, snapshot);
}

bool CaptureContextIndicators(const StrategyContextTypes context,
                              StrategyContextIndicators &snapshot)
{
  snapshot.context   = context;
  snapshot.timeframe = StrategyContextTimeframe(context);

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);
  bool require_structure = ContextRequiresStructure(context, structure_ctx);

  if(Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
    require_structure = true;

  if(require_structure)
  {
    snapshot.structure_valid = LoadContextStructureSnapshot(context, snapshot.structure_data);
    if(!snapshot.structure_valid)
      return false;
    if(StrategyContextFirstStructureUsesClosePercent(context))
    {
      double close_percent = snapshot.structure_data.first_structure_close_percent;
      if(close_percent > 0.0)
        snapshot.structure_data.first_fibonacci_level = close_percent;
    }
  }
  else
  {
    snapshot.structure_valid = false;
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
