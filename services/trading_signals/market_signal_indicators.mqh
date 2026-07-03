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

int FindDeterministicMaLogicHandle(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtDeterministicMaLogicHandles);
  for(int i = 0; i < total; i++)
  {
    if(ExtDeterministicMaLogicHandles[i].indicator_timeframe != timeframe)
      continue;
    if(ExtDeterministicMaLogicHandles[i].indicator_shift != 0)
      continue;
    return ExtDeterministicMaLogicHandles[i].indicator_handle;
  }

  return INVALID_HANDLE;
}

bool CopyDeterministicMaValue(const ENUM_TIMEFRAMES timeframe,
                              const int shift,
                              double &value_out)
{
  value_out = 0.0;

  if(shift < 0)
    return false;

  int handle = FindDeterministicMaLogicHandle(timeframe);
  if(handle == INVALID_HANDLE)
    return false;

  double value_buffer[];
  int copied = CopyBuffer(handle, 0, shift, 1, value_buffer);
  if(copied != 1)
    return false;

  value_out = value_buffer[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyDeterministicMaSlopeValues(const ENUM_TIMEFRAMES timeframe,
                                    const int current_shift,
                                    double &current_value_out,
                                    double &previous_value_out)
{
  current_value_out = 0.0;
  previous_value_out = 0.0;

  if(!CopyDeterministicMaValue(timeframe, current_shift, current_value_out))
    return false;

  if(!CopyDeterministicMaValue(timeframe, current_shift + 1, previous_value_out))
    return false;

  return true;
}

struct DeterministicExtremumSnapshot
{
  bool     valid;
  bool     is_peak;
  datetime extremum_time;
  double   extremum_price;
  double   extremum_high;
  double   extremum_low;

  DeterministicExtremumSnapshot()
  {
    valid          = false;
    is_peak        = false;
    extremum_time  = 0;
    extremum_price = 0.0;
    extremum_high  = 0.0;
    extremum_low   = 0.0;
  }

  DeterministicExtremumSnapshot(const DeterministicExtremumSnapshot &other)
  {
    valid          = other.valid;
    is_peak        = other.is_peak;
    extremum_time  = other.extremum_time;
    extremum_price = other.extremum_price;
    extremum_high  = other.extremum_high;
    extremum_low   = other.extremum_low;
  }
};

bool ResolveLatestConfirmedDeterministicExtremum(const StochasticMarketStructure &structure,
                                                 DeterministicExtremumSnapshot &extremum_out)
{
  extremum_out = DeterministicExtremumSnapshot();

  int total = ArraySize(structure.os_market_structures);
  if(total < 2)
    return false;

  OscillatorMarketStructure latest = structure.os_market_structures[1];
  if(latest.extremum_time <= 0)
    return false;

  extremum_out.is_peak       = latest.is_peak;
  extremum_out.extremum_time = latest.extremum_time;

  if(latest.is_peak)
  {
    if(latest.extremum_high <= 0.0 || latest.extremum_high == -DBL_MAX)
      return false;

    extremum_out.extremum_high  = latest.extremum_high;
    extremum_out.extremum_price = latest.extremum_high;
  }
  else
  {
    if(latest.extremum_low <= 0.0 || latest.extremum_low == DBL_MAX)
      return false;

    extremum_out.extremum_low   = latest.extremum_low;
    extremum_out.extremum_price = latest.extremum_low;
  }

  extremum_out.valid = true;
  return true;
}

bool LoadContextStructureSnapshot(const StrategyContextTypes context,
                                  StochasticMarketStructure &snapshot)
{
  return LoadStructureSnapshotForTimeframe(DETERMINISTIC_BASE_TIMEFRAME, snapshot);
}

bool CaptureContextIndicators(const StrategyContextTypes context,
                              StrategyContextIndicators &snapshot)
{
  snapshot.context   = CONTEXT_SLOT_BASE;
  snapshot.timeframe = DETERMINISTIC_BASE_TIMEFRAME;

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
