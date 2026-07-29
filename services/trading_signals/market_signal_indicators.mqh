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

int FindDeterministicBandsLogicHandle(const ENUM_TIMEFRAMES timeframe)
{
  int total = ArraySize(ExtDeterministicBandsLogicHandles);
  for(int i = 0; i < total; i++)
  {
    if(ExtDeterministicBandsLogicHandles[i].indicator_timeframe != timeframe)
      continue;
    if(ExtDeterministicBandsLogicHandles[i].indicator_shift != 0)
      continue;
    return ExtDeterministicBandsLogicHandles[i].indicator_handle;
  }

  return INVALID_HANDLE;
}

bool CopyDeterministicBandsBaseValue(const ENUM_TIMEFRAMES timeframe,
                                     const int shift,
                                     double &value_out)
{
  value_out = 0.0;

  if(shift < 0)
    return false;

  int handle = FindDeterministicBandsLogicHandle(timeframe);
  if(handle == INVALID_HANDLE)
    return false;

  double value_buffer[];
  int copied = CopyBuffer(handle, 0, shift, 1, value_buffer);
  if(copied != 1)
    return false;

  value_out = value_buffer[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyDeterministicBandsBufferValue(const ENUM_TIMEFRAMES timeframe,
                                       const int buffer_index,
                                       const int shift,
                                       double &value_out)
{
  value_out = 0.0;

  if(buffer_index < 0 || shift < 0)
    return false;

  int handle = FindDeterministicBandsLogicHandle(timeframe);
  if(handle == INVALID_HANDLE)
    return false;

  double value_buffer[];
  int copied = CopyBuffer(handle, buffer_index, shift, 1, value_buffer);
  if(copied != 1)
    return false;

  value_out = value_buffer[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyDeterministicCloseValue(const ENUM_TIMEFRAMES timeframe,
                                 const int shift,
                                 double &value_out)
{
  value_out = 0.0;

  if(shift < 0)
    return false;

  double close_buffer[];
  int copied = CopyClose(_Symbol, timeframe, shift, 1, close_buffer);
  if(copied != 1)
    return false;

  value_out = close_buffer[0];
  return MathIsValidNumber(value_out) && value_out > 0.0;
}

bool CopyDeterministicBandsBaseSlopeValues(const ENUM_TIMEFRAMES timeframe,
                                           const int current_shift,
                                           double &current_value_out,
                                           double &previous_value_out)
{
  current_value_out = 0.0;
  previous_value_out = 0.0;

  if(!CopyDeterministicBandsBaseValue(timeframe, current_shift, current_value_out))
    return false;

  if(!CopyDeterministicBandsBaseValue(timeframe, current_shift + 1, previous_value_out))
    return false;

  return true;
}

bool CopyDeterministicBPercentMainValue(const ENUM_TIMEFRAMES timeframe,
                                        const int candle_shift,
                                        const int read_shift,
                                        double &value_out)
{
  value_out = 0.0;

  if(candle_shift < 0 || read_shift < 0)
    return false;

  int band_shift = read_shift + candle_shift;

  double close_value = 0.0;
  if(!CopyDeterministicCloseValue(timeframe, read_shift, close_value))
    return false;

  double upper_band = 0.0;
  if(!CopyDeterministicBandsBufferValue(timeframe, 1, band_shift, upper_band))
    return false;

  double lower_band = 0.0;
  if(!CopyDeterministicBandsBufferValue(timeframe, 2, band_shift, lower_band))
    return false;

  double band_range = upper_band - lower_band;
  if(band_range == 0.0)
    return false;

  value_out = (close_value - lower_band) / band_range * 100.0;
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyDeterministicBPercentMainSlopeValues(const ENUM_TIMEFRAMES timeframe,
                                              const int candle_shift,
                                              double &current_value_out,
                                              double &previous_value_out,
                                              double &slope_out)
{
  current_value_out = 0.0;
  previous_value_out = 0.0;
  slope_out = 0.0;

  if(!CopyDeterministicBPercentMainValue(timeframe,
                                         candle_shift,
                                         1,
                                         current_value_out))
    return false;

  if(!CopyDeterministicBPercentMainValue(timeframe,
                                         candle_shift,
                                         2,
                                         previous_value_out))
    return false;

  slope_out = current_value_out - previous_value_out;
  return MathIsValidNumber(slope_out);
}

struct DeterministicExtremumSnapshot
{
  bool     valid;
  int      source_slot;
  bool     confirmed;
  bool     is_peak;
  datetime extremum_time;
  double   extremum_price;
  double   extremum_high;
  double   extremum_low;

  DeterministicExtremumSnapshot()
  {
    valid          = false;
    source_slot    = -1;
    confirmed      = false;
    is_peak        = false;
    extremum_time  = 0;
    extremum_price = 0.0;
    extremum_high  = 0.0;
    extremum_low   = 0.0;
  }

  DeterministicExtremumSnapshot(const DeterministicExtremumSnapshot &other)
  {
    valid          = other.valid;
    source_slot    = other.source_slot;
    confirmed      = other.confirmed;
    is_peak        = other.is_peak;
    extremum_time  = other.extremum_time;
    extremum_price = other.extremum_price;
    extremum_high  = other.extremum_high;
    extremum_low   = other.extremum_low;
  }
};

string DeterministicExtremumTypeToken(const DeterministicExtremumSnapshot &extremum)
{
  if(!extremum.valid)
    return "INVALID";

  return extremum.is_peak ? "PEAK" : "BOTTOM";
}

string DeterministicBoolToken(const bool value)
{
  return value ? "true" : "false";
}

bool ResolveDeterministicExtremumBySlot(const StochasticMarketStructure &structure,
                                        const int source_slot,
                                        const bool confirmed,
                                        DeterministicExtremumSnapshot &extremum_out)
{
  extremum_out = DeterministicExtremumSnapshot();

  int total = ArraySize(structure.os_market_structures);
  if(source_slot < 0 || source_slot >= total)
    return false;

  OscillatorMarketStructure latest = structure.os_market_structures[source_slot];
  if(latest.extremum_time <= 0)
    return false;

  extremum_out.source_slot    = source_slot;
  extremum_out.confirmed      = confirmed;
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

bool ResolveLatestConfirmedDeterministicExtremum(const StochasticMarketStructure &structure,
                                                 DeterministicExtremumSnapshot &extremum_out)
{
  return ResolveDeterministicExtremumBySlot(structure,
                                            1,
                                            true,
                                            extremum_out);
}

bool ResolveCurrentDeterministicExtremum(const StochasticMarketStructure &structure,
                                         DeterministicExtremumSnapshot &extremum_out)
{
  return ResolveDeterministicExtremumBySlot(structure,
                                            0,
                                            false,
                                            extremum_out);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
