//+------------------------------------------------------------------+
//|                           hedged_swing_utils.mqh                 |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_
#define _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_

IndicatorsHandleInfo HedgedAtrHandles[];

inline bool HedgedSwingModeEnabled()
{
  return Enable_Hedged_Swing_Mode;
}

inline bool HedgedSwingSlEnabled(const SignalTypes direction)
{
  if(direction == BULLISH)
    return Bullish_Swing_SL_Enable;
  if(direction == BEARISH)
    return Bearish_Swing_SL_Enable;
  return false;
}

inline int HedgedSwingBarsToScan()
{
  return 377;
}

inline ENUM_TIMEFRAMES ResolveHedgedPrimaryTimeframe()
{
  ENUM_TIMEFRAMES tf = Trend_Strategy_Timeframe;
  if(tf == PERIOD_CURRENT)
    tf = Strategy_Timeframe;
  return tf;
}

int HedgedAtrPeriod()
{
  int period = (int)Stoch_Structure_Period_Type;
  if(period <= 0)
    period = 5;
  return period;
}

double HedgedResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

bool HedgedFindAtrHandle(const ENUM_TIMEFRAMES tf,
                         IndicatorsHandleInfo &handle_out)
{
  int total = ArraySize(HedgedAtrHandles);
  for(int i = 0; i < total; i++)
  {
    if(HedgedAtrHandles[i].indicator_timeframe != tf)
      continue;
    handle_out = HedgedAtrHandles[i];
    return true;
  }
  return false;
}

bool HedgedEnsureAtrHandle(const ENUM_TIMEFRAMES tf,
                           IndicatorsHandleInfo &handle_out)
{
  if(HedgedFindAtrHandle(tf, handle_out))
  {
    if(handle_out.indicator_handle != INVALID_HANDLE)
      return true;
  }

  IndicatorsHandleInfo handle;
  handle.indicator_timeframe = tf;
  handle.indicator_period    = HedgedAtrPeriod();
  handle.indicator_handle    = iATR(_Symbol, tf, handle.indicator_period);

  if(handle.indicator_handle == INVALID_HANDLE)
  {
    PrintFormat("ERROR loading hedged ATR handle | tf=%s | period=%d | err=%d",
                EnumToString(tf),
                handle.indicator_period,
                GetLastError());
    if(MQLInfoInteger(MQL_TESTER) > 0)
    {
      TesterStop();
      return false;
    }
    return false;
  }

  AddElementToArray(HedgedAtrHandles, handle);
  handle_out = handle;
  return true;
}

bool HedgedCopyAtrPoints(const ENUM_TIMEFRAMES tf,
                         double &atr_points)
{
  atr_points = 0.0;

  IndicatorsHandleInfo handle;
  if(!HedgedEnsureAtrHandle(tf, handle))
    return false;

  double buffer[2];
  int copied = CopyBuffer(handle.indicator_handle, 0, 0, 2, buffer);
  if(copied < 1)
    return false;

  double point_size = HedgedResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double latest = buffer[0];
  double prev   = (copied > 1) ? buffer[1] : buffer[0];
  double max_value = MathMax(latest, prev);
  if(max_value <= 0.0)
    return false;

  atr_points = max_value / point_size;
  return (atr_points > 0.0);
}

double HedgedResolveGuardPoints(const ENUM_TIMEFRAMES primary_tf,
                                const ENUM_TIMEFRAMES fallback_tf)
{
  double atr_points = 0.0;
  double primary_atr = 0.0;
  if(HedgedCopyAtrPoints(primary_tf, primary_atr))
    atr_points = MathMax(atr_points, primary_atr);

  double fallback_atr = 0.0;
  if(fallback_tf != primary_tf && HedgedCopyAtrPoints(fallback_tf, fallback_atr))
    atr_points = MathMax(atr_points, fallback_atr);

  double guard_points = MathMax(Grid_Points_Range_Setup, atr_points);
  guard_points = EnforceBrokerDistance(g_symbol_constraints, guard_points);
  return guard_points;
}

bool HedgedIsFractalHigh(const double &highs[],
                         const int index,
                         const int total)
{
  if(index <= 0 || index >= total - 1)
    return false;
  return (highs[index] >= highs[index - 1] &&
          highs[index] >= highs[index + 1]);
}

bool HedgedIsFractalLow(const double &lows[],
                        const int index,
                        const int total)
{
  if(index <= 0 || index >= total - 1)
    return false;
  return (lows[index] <= lows[index - 1] &&
          lows[index] <= lows[index + 1]);
}

bool HedgedScanTimeframeForSwings(const SignalTypes direction,
                                  const ENUM_TIMEFRAMES tf,
                                  const double guard_points,
                                  HedgedSwingSnapshot &snapshot)
{
  int bars_available = Bars(_Symbol, tf);
  if(bars_available < 3)
    return false;

  int scan_total = HedgedSwingBarsToScan();
  if(scan_total + 2 > bars_available)
    scan_total = bars_available - 2;
  if(scan_total < 3)
    return false;

  double highs[], lows[]; datetime times[];
  int copied_highs = CopyHigh(_Symbol, tf, 0, scan_total + 2, highs);
  int copied_lows  = CopyLow(_Symbol, tf, 0, scan_total + 2, lows);
  int copied_times = CopyTime(_Symbol, tf, 0, scan_total + 2, times);
  ArraySetAsSeries(highs, true);
  ArraySetAsSeries(lows, true);
  ArraySetAsSeries(times, true);
  if(copied_highs < 3 || copied_lows < 3)
    return false;

  double point_size = HedgedResolvePointSize();
  double entry_side_price = (direction == BULLISH) ? g_ask : g_bid;
  double exit_side_price  = (direction == BULLISH) ? g_bid : g_ask;

  double entry_best_distance  = DBL_MAX;
  double target_best_distance = DBL_MAX;
  double entry_price          = 0.0;
  double target_price         = 0.0;
  double stop_price           = 0.0;
  bool   stop_found           = false;
  bool   target_found         = false;
  bool   entry_found          = false;
  double swing_sequence[10];
  int    swing_count          = 0;
  datetime entry_price_time   = 0;
  datetime target_price_time  = 0;
  datetime stop_price_time    = 0;

  for(int i = 1; i < scan_total; i++)
  {
    bool fractal_high = HedgedIsFractalHigh(highs, i, copied_highs);
    bool fractal_low  = HedgedIsFractalLow(lows, i, copied_lows);

    if(direction == BULLISH)
    {
      double entry_distance_pts = (entry_side_price - lows[i]) / point_size;
      if(entry_distance_pts >= guard_points && entry_distance_pts < entry_best_distance)
      {
        entry_best_distance = entry_distance_pts;
        entry_price = lows[i];
        entry_price_time = times[i];
        entry_found = true;
        target_found = false;
        stop_found = false;
        target_best_distance = DBL_MAX;
        swing_count = 0;
        swing_sequence[swing_count++] = entry_price;
      }

      if(entry_found)
      {
        double target_distance_pts = (highs[i] - entry_price) / point_size;
        if(target_distance_pts >= guard_points && target_distance_pts < target_best_distance)
        {
          target_best_distance = target_distance_pts;
          target_price = highs[i];
          target_found = true;
          target_price_time = times[i];
        }

        if(fractal_low)
        {
          double stop_distance_pts = (entry_price - lows[i]) / point_size;
          if(stop_distance_pts >= guard_points &&
             (!stop_found || stop_distance_pts < (entry_price - stop_price) / point_size))
          {
            stop_price = lows[i];
            stop_found = true;
            stop_price_time = times[i];
          }
        }

        double swing_distance_pts = (entry_price - lows[i]) / point_size;
        if(swing_distance_pts >= guard_points && swing_count < GRID_MAX_LEVELS)
        {
          bool far_enough = (swing_distance_pts >= guard_points);
          if(far_enough)
            swing_sequence[swing_count++] = lows[i];
        }
      }
    }
    else if(direction == BEARISH)
    {
      double entry_distance_pts = (highs[i] - entry_side_price) / point_size;
      if(entry_distance_pts >= guard_points && entry_distance_pts < entry_best_distance)
      {
        entry_best_distance = entry_distance_pts;
        entry_price = highs[i];
        entry_price_time = times[i];
        entry_found = true;
        target_found = false;
        stop_found = false;
        target_best_distance = DBL_MAX;
        swing_count = 0;
        swing_sequence[swing_count++] = entry_price;
      }

      if(entry_found)
      {
        double target_distance_pts = (entry_price - lows[i]) / point_size;
        if(target_distance_pts >= guard_points && target_distance_pts < target_best_distance)
        {
          target_best_distance = target_distance_pts;
          target_price = lows[i];
          target_found = true;
          target_price_time = times[i];
        }

        if(fractal_high)
        {
          double stop_distance_pts = (highs[i] - entry_price) / point_size;
          if(stop_distance_pts >= guard_points &&
             (!stop_found || stop_distance_pts < (stop_price - entry_price) / point_size))
          {
            stop_price = highs[i];
            stop_found = true;
            stop_price_time = times[i];
          }
        }

        double swing_distance_pts = (highs[i] - entry_price) / point_size;
        if(swing_distance_pts >= guard_points && swing_count < GRID_MAX_LEVELS)
        {
          bool far_enough = (swing_distance_pts >= guard_points);
          if(far_enough)
            swing_sequence[swing_count++] = highs[i];
        }
      }
    }

    if(entry_found && target_found && stop_found)
    {
      Print(EnumToString(direction), " | ", entry_price_time, " |entry| ", entry_price,
            " || ", target_price_time, " |target| ", target_price,
            " || ", stop_price_time, " |stop| ", stop_price);
      break;
    }
  }

  if(entry_found && entry_price > 0.0)
  {
    snapshot.entry_anchor_price = entry_price;
    snapshot.anchor_from_fallback = false;
    snapshot.source_timeframe = tf;
  }

  if(target_found && target_price > 0.0)
  {
    snapshot.target_price = target_price;
    snapshot.target_valid = true;
  }

  if(stop_found && stop_price > 0.0)
  {
    snapshot.stop_loss_price = stop_price;
    snapshot.stop_valid = true;
  }

  ArrayResize(snapshot.swing_levels, 0);
  if(entry_found && swing_count > 0)
  {
    ArrayResize(snapshot.swing_levels, swing_count);
    for(int s = 0; s < swing_count; s++)
      snapshot.swing_levels[s] = swing_sequence[s];
  }

  return true;
}

bool BuildHedgedSwingSnapshot(const SignalTypes direction,
                              HedgedSwingSnapshot &snapshot)
{
  snapshot = HedgedSwingSnapshot();
  snapshot.hedged_mode = HedgedSwingModeEnabled();

  ENUM_TIMEFRAMES primary_tf  = ResolveHedgedPrimaryTimeframe();
  ENUM_TIMEFRAMES fallback_tf = Strategy_Timeframe;
  double guard_points = HedgedResolveGuardPoints(primary_tf, fallback_tf);
  snapshot.guard_points = guard_points;
  snapshot.source_timeframe = primary_tf;

  HedgedScanTimeframeForSwings(direction, primary_tf, guard_points, snapshot);

  if((snapshot.entry_anchor_price <= 0.0 || !snapshot.target_valid || !snapshot.stop_valid) &&
     fallback_tf != primary_tf)
  {
    HedgedSwingSnapshot fallback_snapshot = snapshot;
    HedgedScanTimeframeForSwings(direction, fallback_tf, guard_points, fallback_snapshot);

    if(snapshot.entry_anchor_price <= 0.0 && fallback_snapshot.entry_anchor_price > 0.0)
    {
      snapshot.entry_anchor_price = fallback_snapshot.entry_anchor_price;
      snapshot.source_timeframe   = fallback_tf;
      snapshot.anchor_from_fallback = false;
    }

    if(!snapshot.target_valid && fallback_snapshot.target_valid)
    {
      snapshot.target_price = fallback_snapshot.target_price;
      snapshot.target_valid = true;
    }

    if(!snapshot.stop_valid && fallback_snapshot.stop_valid)
    {
      snapshot.stop_loss_price = fallback_snapshot.stop_loss_price;
      snapshot.stop_valid = true;
    }
  }

  double point_size = HedgedResolvePointSize();
  double entry_price_side = (direction == BULLISH) ? g_ask : g_bid;
  double exit_price_side  = (direction == BULLISH) ? g_bid : g_ask;

  if(snapshot.entry_anchor_price <= 0.0)
  {
    double anchor_price = (direction == BULLISH)
                            ? entry_price_side - guard_points * point_size
                            : entry_price_side + guard_points * point_size;
    snapshot.entry_anchor_price = anchor_price;
    snapshot.anchor_from_fallback = true;
    ArrayResize(snapshot.swing_levels, 1);
    snapshot.swing_levels[0] = anchor_price;
  }

  if(!snapshot.target_valid)
  {
    double target_price = (direction == BULLISH)
                            ? exit_price_side + guard_points * point_size
                            : exit_price_side - guard_points * point_size;
    snapshot.target_price = target_price;
    snapshot.target_valid = (target_price > 0.0);
  }

  if(!snapshot.stop_valid && HedgedSwingSlEnabled(direction))
  {
    double stop_price = (direction == BULLISH)
                          ? snapshot.entry_anchor_price - guard_points * point_size
                          : snapshot.entry_anchor_price + guard_points * point_size;
    snapshot.stop_loss_price = stop_price;
    snapshot.stop_valid = (stop_price > 0.0);
  }

  if(ArraySize(snapshot.swing_levels) <= 0 && snapshot.entry_anchor_price > 0.0)
  {
    ArrayResize(snapshot.swing_levels, 1);
    snapshot.swing_levels[0] = snapshot.entry_anchor_price;
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_
