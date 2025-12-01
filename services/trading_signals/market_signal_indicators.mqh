//+------------------------------------------------------------------+
//|                             market_signal_indicators.mqh        |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_

bool LoadBodyMASnapshotFromHandle(IndicatorsHandleInfo &handle,
                                  BodyMAStructure &snapshot)
{
  if(handle.indicator_handle == INVALID_HANDLE)
    return false;
  snapshot = BodyMAStructure();
  snapshot.InitBodyMAStructureValues(handle, 0);
  return true;
}

bool LoadBodyMASnapshotForTimeframe(const ENUM_TIMEFRAMES tf,
                                    BodyMAStructure &snapshot)
{
  int total = ArraySize(ExtBodyMAIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtBodyMAIndicatorsHandle[i].indicator_timeframe != tf)
      continue;
    if(LoadBodyMASnapshotFromHandle(ExtBodyMAIndicatorsHandle[i], snapshot))
      return true;
  }
  return false;
}

bool LoadContextBodyMASnapshot(const StrategyContextTypes context,
                               BodyMAStructure &snapshot)
{
  ENUM_TIMEFRAMES tf = StrategyContextTimeframe(context);
  return LoadBodyMASnapshotForTimeframe(tf, snapshot);
}

bool LoadBandsPercentSnapshotFromHandle(IndicatorsHandleInfo &handle,
                                        BandsPercentStructure &snapshot)
{
  if(handle.indicator_handle == INVALID_HANDLE)
    return false;
  snapshot = BandsPercentStructure();
  snapshot.InitBandsPercentStructureValues(handle, 0);
  return true;
}

bool LoadBPercentSnapshotForTimeframe(const ENUM_TIMEFRAMES tf,
                                      BandsPercentStructure &snapshot)
{
  int total = ArraySize(ExtBPercentIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtBPercentIndicatorsHandle[i].indicator_timeframe != tf)
      continue;
    if(LoadBandsPercentSnapshotFromHandle(ExtBPercentIndicatorsHandle[i], snapshot))
      return true;
  }
  return false;
}

bool LoadAlligatorSnapshotFromHandle(IndicatorsHandleInfo &handle,
                                     AlligatorStructure &snapshot)
{
  if(handle.indicator_handle == INVALID_HANDLE)
    return false;

  int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

  snapshot = AlligatorStructure();
  return snapshot.InitAlligatorStructureValues(handle,
                                               0,
                                               jaws_period,
                                               teeth_period,
                                               lips_period);
}

bool LoadAlligatorSnapshotForTimeframe(const ENUM_TIMEFRAMES tf,
                                       AlligatorStructure &snapshot)
{
  int total = ArraySize(ExtAlligatorIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtAlligatorIndicatorsHandle[i].indicator_timeframe != tf)
      continue;
    if(LoadAlligatorSnapshotFromHandle(ExtAlligatorIndicatorsHandle[i], snapshot))
      return true;
  }
  return false;
}

bool LoadStochasticSnapshotFromHandle(IndicatorsHandleInfo &handle,
                                      StochasticStructure &snapshot)
{
  if(handle.indicator_handle == INVALID_HANDLE)
    return false;
  snapshot = StochasticStructure();
  snapshot.InitStochasticStructureValues(handle, 0);
  return true;
}

bool LoadStochasticSnapshotForTimeframe(const ENUM_TIMEFRAMES tf,
                                        StochasticStructure &snapshot)
{
  int total = ArraySize(ExtStochIndicatorsHandle);
  for(int i = 0; i < total; i++)
  {
    if(ExtStochIndicatorsHandle[i].indicator_timeframe != tf)
      continue;
    if(LoadStochasticSnapshotFromHandle(ExtStochIndicatorsHandle[i], snapshot))
      return true;
  }
  return false;
}

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

bool LoadContextBPercentSnapshot(const StrategyContextTypes context,
                                 BandsPercentStructure &snapshot)
{
  ENUM_TIMEFRAMES tf = StrategyContextTimeframe(context);
  if(context == CONTEXT_SLOT_TREND)
  {
    if(LoadBandsPercentSnapshotFromHandle(TrendBPercentIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_MACRO)
  {
    if(LoadBandsPercentSnapshotFromHandle(MacroBPercentIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_SESSION)
  {
    if(LoadBandsPercentSnapshotFromHandle(SessionBPercentIndicatorHandle, snapshot))
      return true;
  }

  return LoadBPercentSnapshotForTimeframe(tf, snapshot);
}

bool LoadContextAlligatorSnapshot(const StrategyContextTypes context,
                                  AlligatorStructure &snapshot)
{
  ENUM_TIMEFRAMES tf = StrategyContextTimeframe(context);
  if(context == CONTEXT_SLOT_TREND)
  {
    if(LoadAlligatorSnapshotFromHandle(TrendAlligatorIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_MACRO)
  {
    if(LoadAlligatorSnapshotFromHandle(MacroAlligatorIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_SESSION)
  {
    if(LoadAlligatorSnapshotFromHandle(SessionAlligatorIndicatorHandle, snapshot))
      return true;
  }

  return LoadAlligatorSnapshotForTimeframe(tf, snapshot);
}

bool LoadContextStochasticSnapshot(const StrategyContextTypes context,
                                   StochasticStructure &snapshot)
{
  ENUM_TIMEFRAMES tf = StrategyContextTimeframe(context);
  if(context == CONTEXT_SLOT_TREND)
  {
    if(LoadStochasticSnapshotFromHandle(TrendStochIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_MACRO)
  {
    if(LoadStochasticSnapshotFromHandle(MacroStochIndicatorHandle, snapshot))
      return true;
  }
  else if(context == CONTEXT_SLOT_SESSION)
  {
    if(LoadStochasticSnapshotFromHandle(SessionStochIndicatorHandle, snapshot))
      return true;
  }

  return LoadStochasticSnapshotForTimeframe(tf, snapshot);
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

  StrategyEntryChannelModes entry_mode = StrategyContextEntryEvaluation(context);
  StrategyTrendModes trend_mode = StrategyContextTrendMode(context);

  bool need_bpercent   = EntryEvaluationUsesAnyBPercent(entry_mode) ||
                         StrategyContextBPercentSlopeEnabled(context);
  bool need_alligator  = TrendModeUsesAlligator(trend_mode) ||
                         StrategyContextAlligatorSlopeEnabled(context);
  bool need_stochastic = StrategyContextStochasticSlopeEnabled(context) ||
                         (Strategy_Global_Stoch_Entry_Mode != STOCH_ENTRY_OFF);
  BodyVolumeFilterModes body_volume_mode = StrategyContextBodyVolumeMode(context);

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);

  bool require_structure = StructureFiltersRequested(structure_ctx) ||
                           StructureTypeFiltersRequested(structure_ctx) ||
                           StrategyContextFreshStructureEnabled(context);

  if(Stoch_Structure_Period_Type == STOCH_STRUCTURE_PERIOD_OFF)
    require_structure = false;

  if(Grid_Base_Strategy_Type == STOCH_STRUCTURE_RANGE)
    require_structure = true;

  bool require_body_ma = (body_volume_mode != BODY_VOLUME_OFF);

  if(need_bpercent)
  {
    snapshot.bpercent_valid = LoadContextBPercentSnapshot(context, snapshot.bpercent_data);
    if(!snapshot.bpercent_valid)
      return false;
  }
  else
  {
    snapshot.bpercent_valid = false;
  }

  if(need_alligator)
  {
    snapshot.alligator_valid = LoadContextAlligatorSnapshot(context, snapshot.alligator_data);
    if(!snapshot.alligator_valid)
      return false;
  }
  else
  {
    snapshot.alligator_valid = false;
  }

  if(need_stochastic)
  {
    snapshot.stochastic_valid = LoadContextStochasticSnapshot(context, snapshot.stochastic_data);
    if(!snapshot.stochastic_valid)
      return false;
  }
  else
  {
    snapshot.stochastic_valid = false;
  }

  if(require_body_ma)
  {
    snapshot.body_ma_valid = LoadContextBodyMASnapshot(context, snapshot.body_ma_data);
    if(!snapshot.body_ma_valid)
      return false;
  }
  else
  {
    snapshot.body_ma_valid = false;
  }

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
