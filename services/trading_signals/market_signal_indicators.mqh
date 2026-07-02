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
  return LoadStructureSnapshotForTimeframe(Strategy_Timeframe, snapshot);
}

bool CaptureContextIndicators(const StrategyContextTypes context,
                              StrategyContextIndicators &snapshot)
{
  snapshot.context   = CONTEXT_SLOT_BASE;
  snapshot.timeframe = Strategy_Timeframe;

  StrategyStructureLayerContext structure_ctx = BuildBaseStructureLayerContext();
  bool require_structure = ContextRequiresStructure(CONTEXT_SLOT_BASE, structure_ctx);

  if(StrategyRangeUsesStructure())
    require_structure = true;

  if(require_structure)
  {
    snapshot.structure_valid = LoadContextStructureSnapshot(CONTEXT_SLOT_BASE, snapshot.structure_data);
    if(!snapshot.structure_valid)
      return false;
  }
  else
  {
    snapshot.structure_valid = false;
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
