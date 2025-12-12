//+------------------------------------------------------------------+
//|              hedged_stoch_structure_loader.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_HEDGED_STOCH_STRUCTURE_LOADER_MQH_
#define _SERVICES_TRADING_SIGNALS_HEDGED_STOCH_STRUCTURE_LOADER_MQH_

struct HedgedStochStructHandle
{
  ENUM_TIMEFRAMES tf;
  int             k_period;
  int             handle;

  HedgedStochStructHandle()
  {
    tf = PERIOD_CURRENT;
    k_period = 0;
    handle = INVALID_HANDLE;
  }
};

HedgedStochStructHandle g_hedged_stoch_struct_handles[];

int HedgedResolveStochStructK(const HedgedSwingModes mode)
{
  if(mode == STOCH_STRUCT_5)
    return 5;
  return 3;
}

bool HedgedFindStochStructHandle(const ENUM_TIMEFRAMES tf,
                                 const int k_period,
                                 HedgedStochStructHandle &out_handle)
{
  int total = ArraySize(g_hedged_stoch_struct_handles);
  for(int i = 0; i < total; i++)
  {
    HedgedStochStructHandle handle = g_hedged_stoch_struct_handles[i];
    if(handle.tf == tf && handle.k_period == k_period)
    {
      out_handle = handle;
      return true;
    }
  }
  return false;
}

bool HedgedEnsureStochStructHandle(const ENUM_TIMEFRAMES tf,
                                   const HedgedSwingModes mode,
                                   HedgedStochStructHandle &out_handle)
{
  int k_period = HedgedResolveStochStructK(mode);
  if(HedgedFindStochStructHandle(tf, k_period, out_handle))
  {
    if(out_handle.handle != INVALID_HANDLE)
      return true;
  }

  HedgedStochStructHandle handle;
  handle.tf = tf;
  handle.k_period = k_period;
  handle.handle = iCustom(_Symbol,
                          tf,
                          "Examples\\Stochastic_Structure",
                          k_period,
                          3,
                          3,
                          STO_CLOSECLOSE);
  if(handle.handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR loading hedged stoch structure | tf=%s | k=%d | err=%d",
                EnumToString(tf),
                k_period,
                GetLastError());
    if(MQLInfoInteger(MQL_TESTER) > 0)
      TesterStop();
    return false;
  }

  AddElementToArray(g_hedged_stoch_struct_handles, handle);
  out_handle = handle;
  return true;
}

bool HedgedCopyStochStruct(const ENUM_TIMEFRAMES tf,
                           const HedgedSwingModes mode,
                           const int bars_required,
                           double &struct_buffer[],
                           double &peak_buffer[],
                           double &bottom_buffer[])
{
  HedgedStochStructHandle handle;
  if(!HedgedEnsureStochStructHandle(tf, mode, handle))
    return false;

  int copied_struct = CopyBuffer(handle.handle, 0, 0, bars_required, struct_buffer);
  int copied_peak = CopyBuffer(handle.handle, 1, 0, bars_required, peak_buffer);
  int copied_bottom = CopyBuffer(handle.handle, 2, 0, bars_required, bottom_buffer);
  ArraySetAsSeries(struct_buffer, true);
  ArraySetAsSeries(peak_buffer, true);
  ArraySetAsSeries(bottom_buffer, true);

  return (copied_struct >= bars_required &&
          copied_peak >= bars_required &&
          copied_bottom >= bars_required);
}

bool HedgedIsValidStochPeak(const double peak_value,
                            const double struct_value)
{
  return (struct_value != EMPTY_VALUE &&
          struct_value != -DBL_MAX &&
          struct_value != DBL_MAX &&
          peak_value == struct_value);
}

bool HedgedIsValidStochBottom(const double bottom_value,
                              const double struct_value)
{
  return (struct_value != EMPTY_VALUE &&
          struct_value != -DBL_MAX &&
          struct_value != DBL_MAX &&
          bottom_value == struct_value);
}

#endif // _SERVICES_TRADING_SIGNALS_HEDGED_STOCH_STRUCTURE_LOADER_MQH_
