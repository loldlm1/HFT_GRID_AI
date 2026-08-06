//+------------------------------------------------------------------+
//|                         trading_signals/pivot_context_features  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_

struct PivotBandEnvelopeSnapshot
{
  ENUM_TIMEFRAMES timeframe;
  bool captured;
  bool complete;
  bool available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double base_values[PIVOT_B_PERCENT_SHIFT_COUNT];
  double upper_values[PIVOT_B_PERCENT_SHIFT_COUNT];
  double lower_values[PIVOT_B_PERCENT_SHIFT_COUNT];
  string invalid_reason;

  PivotBandEnvelopeSnapshot()
  {
    Reset(PERIOD_CURRENT);
  }

  PivotBandEnvelopeSnapshot(const PivotBandEnvelopeSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset(const ENUM_TIMEFRAMES source_timeframe)
  {
    timeframe = source_timeframe;
    captured = false;
    complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      available[i] = false;
      base_values[i] = 0.0;
      upper_values[i] = 0.0;
      lower_values[i] = 0.0;
    }
  }

  void CopyFrom(const PivotBandEnvelopeSnapshot &other)
  {
    timeframe = other.timeframe;
    captured = other.captured;
    complete = other.complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      available[i] = other.available[i];
      base_values[i] = other.base_values[i];
      upper_values[i] = other.upper_values[i];
      lower_values[i] = other.lower_values[i];
    }
  }
};

struct PivotContextFeatureSnapshot
{
  bool captured;
  bool complete;
  datetime broker_time;
  double trigger_bid;
  PivotBandEnvelopeSnapshot micro_bands;
  PivotBandEnvelopeSnapshot macro_bands;
  bool micro_b_percent_available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double micro_b_percent[PIVOT_B_PERCENT_SHIFT_COUNT];
  bool macro_pivot_b_percent_available[PIVOT_B_PERCENT_SHIFT_COUNT];
  double macro_pivot_b_percent[PIVOT_B_PERCENT_SHIFT_COUNT];
  double micro_band_base_0;
  double micro_band_upper_0;
  double micro_band_lower_0;
  double micro_band_width_0;
  double micro_band_width_percent_0;
  bool micro_complete;
  bool macro_complete;
  string invalid_reason;

  PivotContextFeatureSnapshot()
  {
    Reset();
  }

  PivotContextFeatureSnapshot(const PivotContextFeatureSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    captured = false;
    complete = false;
    broker_time = 0;
    trigger_bid = 0.0;
    micro_bands.Reset(Micro_Timeframe);
    macro_bands.Reset(Macro_Timeframe);
    micro_band_base_0 = 0.0;
    micro_band_upper_0 = 0.0;
    micro_band_lower_0 = 0.0;
    micro_band_width_0 = 0.0;
    micro_band_width_percent_0 = 0.0;
    micro_complete = false;
    macro_complete = false;
    invalid_reason = "";
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      micro_b_percent_available[i] = false;
      micro_b_percent[i] = 0.0;
      macro_pivot_b_percent_available[i] = false;
      macro_pivot_b_percent[i] = 0.0;
    }
  }

  void CopyFrom(const PivotContextFeatureSnapshot &other)
  {
    captured = other.captured;
    complete = other.complete;
    broker_time = other.broker_time;
    trigger_bid = other.trigger_bid;
    micro_bands.CopyFrom(other.micro_bands);
    macro_bands.CopyFrom(other.macro_bands);
    micro_band_base_0 = other.micro_band_base_0;
    micro_band_upper_0 = other.micro_band_upper_0;
    micro_band_lower_0 = other.micro_band_lower_0;
    micro_band_width_0 = other.micro_band_width_0;
    micro_band_width_percent_0 = other.micro_band_width_percent_0;
    micro_complete = other.micro_complete;
    macro_complete = other.macro_complete;
    invalid_reason = other.invalid_reason;
    for(int i = 0; i < PIVOT_B_PERCENT_SHIFT_COUNT; i++)
    {
      micro_b_percent_available[i] = other.micro_b_percent_available[i];
      micro_b_percent[i] = other.micro_b_percent[i];
      macro_pivot_b_percent_available[i] =
        other.macro_pivot_b_percent_available[i];
      macro_pivot_b_percent[i] = other.macro_pivot_b_percent[i];
    }
  }
};

void AppendPivotFeatureReason(string &reason,
                              const string value)
{
  if(value == "")
    return;
  if(reason != "")
    reason += "|";
  reason += value;
}

int PivotBandsHandleForTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  if(timeframe == Macro_Timeframe)
    return g_macro_bands_handle.indicator_handle;
  if(timeframe == Micro_Timeframe)
    return g_micro_bands_handle.indicator_handle;
  return INVALID_HANDLE;
}

bool CopyPivotBandValue(const int handle,
                        const int buffer_index,
                        const int shift,
                        double &value_out)
{
  value_out = 0.0;
  double values[];
  ResetLastError();
  int copied = CopyBuffer(handle, buffer_index, shift, 1, values);
  if(copied != 1 || ArraySize(values) != 1)
    return false;
  value_out = values[0];
  return MathIsValidNumber(value_out) && value_out != EMPTY_VALUE;
}

bool CopyPivotWeightedPriceValue(const ENUM_TIMEFRAMES timeframe,
                                 const int shift,
                                 const datetime broker_time,
                                 double &value_out)
{
  value_out = 0.0;
  if(shift <= 0 || broker_time <= 0)
    return false;

  MqlRates values[];
  ArraySetAsSeries(values, true);
  ResetLastError();
  int copied = CopyRates(_Symbol, timeframe, shift, 1, values);
  if(copied != 1 ||
     ArraySize(values) != 1 ||
     values[0].time <= 0 ||
     values[0].time >= broker_time)
    return false;

  value_out = (values[0].high + values[0].low +
               values[0].close + values[0].close) / 4.0;
  return MathIsValidNumber(value_out) && value_out > 0.0;
}

bool CapturePivotBandEnvelope(const ENUM_TIMEFRAMES timeframe,
                              const datetime broker_time,
                              PivotBandEnvelopeSnapshot &snapshot_out)
{
  snapshot_out.Reset(timeframe);
  snapshot_out.captured = true;
  if(broker_time <= 0)
  {
    snapshot_out.invalid_reason = "OBSERVATION_TIME_INVALID";
    return false;
  }

  int handle = PivotBandsHandleForTimeframe(timeframe);
  if(handle == INVALID_HANDLE)
  {
    snapshot_out.invalid_reason = "BANDS_HANDLE_MISSING";
    return false;
  }
  if(BarsCalculated(handle) < PIVOT_B_PERCENT_SHIFT_COUNT)
  {
    snapshot_out.invalid_reason = "BANDS_HANDLE_NOT_READY";
    return false;
  }

  datetime current_bar_open = iTime(_Symbol, timeframe, 0);
  if(current_bar_open <= 0 || current_bar_open > broker_time)
  {
    snapshot_out.invalid_reason = "BANDS_CURRENT_BAR_NOT_CAUSAL";
    return false;
  }

  bool complete = true;
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    double base = 0.0;
    double upper = 0.0;
    double lower = 0.0;
    if(!CopyPivotBandValue(handle, 0, shift, base) ||
       !CopyPivotBandValue(handle, 1, shift, upper) ||
       !CopyPivotBandValue(handle, 2, shift, lower) ||
       base <= 0.0 ||
       upper <= lower)
    {
      complete = false;
      AppendPivotFeatureReason(snapshot_out.invalid_reason,
                               "BAND_SHIFT_" + IntegerToString(shift) +
                               "_INVALID");
      continue;
    }

    snapshot_out.available[shift] = true;
    snapshot_out.base_values[shift] = base;
    snapshot_out.upper_values[shift] = upper;
    snapshot_out.lower_values[shift] = lower;
  }

  snapshot_out.complete = complete;
  return complete;
}

bool CalculatePivotBPercent(const double price,
                            const double upper_band,
                            const double lower_band,
                            double &value_out)
{
  value_out = 0.0;
  if(!MathIsValidNumber(price) ||
     !MathIsValidNumber(upper_band) ||
     !MathIsValidNumber(lower_band) ||
     price <= 0.0 ||
     upper_band <= lower_band)
    return false;

  value_out = 100.0 * (price - lower_band) /
              (upper_band - lower_band);
  return MathIsValidNumber(value_out);
}

bool CapturePivotMicroFeatures(const double trigger_bid,
                               const datetime broker_time,
                               PivotContextFeatureSnapshot &snapshot)
{
  bool envelope_complete = CapturePivotBandEnvelope(Micro_Timeframe,
                                                     broker_time,
                                                     snapshot.micro_bands);
  if(!envelope_complete)
  {
    AppendPivotFeatureReason(snapshot.invalid_reason,
                             "MICRO_" + snapshot.micro_bands.invalid_reason);
  }

  bool complete = envelope_complete;
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    double price = trigger_bid;
    if(shift > 0 &&
       !CopyPivotWeightedPriceValue(Micro_Timeframe,
                                    shift,
                                    broker_time,
                                    price))
    {
      complete = false;
      AppendPivotFeatureReason(snapshot.invalid_reason,
                               "MICRO_WEIGHTED_PRICE_SHIFT_" +
                               IntegerToString(shift) + "_INVALID");
      continue;
    }
    if(!snapshot.micro_bands.available[shift] ||
       !CalculatePivotBPercent(price,
                               snapshot.micro_bands.upper_values[shift],
                               snapshot.micro_bands.lower_values[shift],
                               snapshot.micro_b_percent[shift]))
    {
      complete = false;
      continue;
    }
    snapshot.micro_b_percent_available[shift] = true;
  }

  if(snapshot.micro_bands.available[0])
  {
    snapshot.micro_band_base_0 = snapshot.micro_bands.base_values[0];
    snapshot.micro_band_upper_0 = snapshot.micro_bands.upper_values[0];
    snapshot.micro_band_lower_0 = snapshot.micro_bands.lower_values[0];
    snapshot.micro_band_width_0 =
      snapshot.micro_band_upper_0 - snapshot.micro_band_lower_0;
    if(snapshot.micro_band_base_0 <= 0.0 ||
       snapshot.micro_band_width_0 <= 0.0)
    {
      complete = false;
      AppendPivotFeatureReason(snapshot.invalid_reason,
                               "MICRO_BAND_WIDTH_INVALID");
    }
    else
    {
      snapshot.micro_band_width_percent_0 =
        100.0 * snapshot.micro_band_width_0 /
        snapshot.micro_band_base_0;
      if(!MathIsValidNumber(snapshot.micro_band_width_percent_0))
      {
        complete = false;
        AppendPivotFeatureReason(snapshot.invalid_reason,
                                 "MICRO_BAND_WIDTH_PERCENT_INVALID");
      }
    }
  }
  else
  {
    complete = false;
  }

  snapshot.micro_complete = complete;
  return complete;
}

bool CapturePivotContextFeatureSnapshot(const double trigger_bid,
                                        const datetime broker_time,
                                        PivotContextFeatureSnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.captured = true;
  snapshot_out.broker_time = broker_time;
  snapshot_out.trigger_bid = trigger_bid;

  CapturePivotMicroFeatures(trigger_bid, broker_time, snapshot_out);
  bool macro_envelope_complete =
    CapturePivotBandEnvelope(Macro_Timeframe,
                             broker_time,
                             snapshot_out.macro_bands);
  if(!macro_envelope_complete)
  {
    AppendPivotFeatureReason(snapshot_out.invalid_reason,
                             "MACRO_" +
                             snapshot_out.macro_bands.invalid_reason);
  }
  return snapshot_out.micro_complete && macro_envelope_complete;
}

bool BuildPivotSignalFeatureSnapshot(
  const PivotContextFeatureSnapshot &shared_snapshot,
  const double pivot_price,
  PivotContextFeatureSnapshot &signal_snapshot_out)
{
  signal_snapshot_out.CopyFrom(shared_snapshot);
  bool complete = shared_snapshot.macro_bands.complete;
  if(!MathIsValidNumber(pivot_price) || pivot_price <= 0.0)
  {
    complete = false;
    AppendPivotFeatureReason(signal_snapshot_out.invalid_reason,
                             "MACRO_PIVOT_PRICE_INVALID");
  }

  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    if(!signal_snapshot_out.macro_bands.available[shift] ||
       !CalculatePivotBPercent(
         pivot_price,
         signal_snapshot_out.macro_bands.upper_values[shift],
         signal_snapshot_out.macro_bands.lower_values[shift],
         signal_snapshot_out.macro_pivot_b_percent[shift]))
    {
      complete = false;
      continue;
    }
    signal_snapshot_out.macro_pivot_b_percent_available[shift] = true;
  }

  signal_snapshot_out.macro_complete = complete;
  signal_snapshot_out.complete =
    signal_snapshot_out.micro_complete &&
    signal_snapshot_out.macro_complete;
  return signal_snapshot_out.complete;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_CONTEXT_FEATURES_MQH_
