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
  if(index <= 1 || index >= total - 1)
    return false;
  return (highs[index] >= highs[index - 1] &&
          highs[index] >= highs[index + 1]);
}

bool HedgedIsFractalLow(const double &lows[],
                        const int index,
                        const int total)
{
  if(index <= 1 || index >= total - 1)
    return false;
  return (lows[index] <= lows[index - 1] &&
          lows[index] <= lows[index + 1]);
}

bool HedgedScanTimeframeForSwings(const SignalTypes direction,
                                  const ENUM_TIMEFRAMES tf,
                                  const double guard_points,
                                  HedgedSwingSnapshot &snapshot,
                                  const bool preset_entry = false,
                                  const double preset_entry_price = 0.0,
                                  const datetime preset_entry_time = 0)
{
  int bars_available = Bars(_Symbol, tf);
  if(bars_available < 3)
    return false;

  int scan_total = HedgedSwingBarsToScan();
  int grid_max_levels = 10;
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
  double entry_price          = (preset_entry && preset_entry_price > 0.0) ? preset_entry_price : 0.0;
  double target_price         = 0.0;
  double stop_price           = 0.0;
  bool   stop_found           = false;
  bool   target_found         = false;
  bool   entry_found          = (preset_entry && preset_entry_price > 0.0);
  double swing_sequence[10];
  datetime swing_time_sequence[10];
  int    swing_count          = entry_found ? 1 : 0;
  datetime entry_price_time   = preset_entry_time;
  datetime target_price_time  = 0;
  datetime stop_price_time    = 0;

  if(entry_found)
  {
    swing_sequence[0] = entry_price;
    swing_time_sequence[0] = (preset_entry_time > 0) ? preset_entry_time : TimeCurrent();
  }

  for(int i = 0; i < scan_total; i++)
  {
    bool fractal_high = HedgedIsFractalHigh(highs, i, copied_highs);
    bool fractal_low  = HedgedIsFractalLow(lows, i, copied_lows);

    if(direction == BULLISH)
    {
      double entry_distance_pts = (entry_side_price - lows[i]) / point_size;
      if(!entry_found && !preset_entry && entry_distance_pts >= guard_points && entry_distance_pts < entry_best_distance)
      {
        entry_best_distance = entry_distance_pts;
        entry_price = lows[i];
        entry_price_time = times[i];
        entry_found = true;
        target_found = false;
        stop_found = false;
        target_best_distance = DBL_MAX;
        swing_count = 0;
        swing_sequence[swing_count] = entry_price;
        swing_time_sequence[swing_count] = entry_price_time;
        swing_count++;
      }

      if(entry_found)
      {
        double target_distance_pts = (highs[i] - entry_price) / point_size;
        if(!target_found && target_distance_pts >= guard_points && target_distance_pts < target_best_distance)
        {
          target_best_distance = target_distance_pts;
          target_price = highs[i];
          target_found = true;
          target_price_time = times[i];
        }

        if(!stop_found && fractal_low)
        {
          double stop_distance_pts = (entry_price - lows[i]) / point_size;
          if(stop_distance_pts >= guard_points)
          {
            stop_price = lows[i];
            stop_found = true;
            stop_price_time = times[i];
          }
        }

        if(swing_count < 10)
        {
          double last_swing = swing_sequence[swing_count - 1];
          double swing_distance_pts = (last_swing - lows[i]) / point_size;
          if(swing_distance_pts >= guard_points)
          {
            swing_sequence[swing_count] = lows[i];
            swing_time_sequence[swing_count] = times[i];
            swing_count++;
          }
        }
      }
    }
    else if(direction == BEARISH)
    {
      double entry_distance_pts = (highs[i] - entry_side_price) / point_size;
      if(!entry_found && !preset_entry && entry_distance_pts >= guard_points && entry_distance_pts < entry_best_distance)
      {
        entry_best_distance = entry_distance_pts;
        entry_price = highs[i];
        entry_price_time = times[i];
        entry_found = true;
        target_found = false;
        stop_found = false;
        target_best_distance = DBL_MAX;
        swing_count = 0;
        swing_sequence[swing_count] = entry_price;
        swing_time_sequence[swing_count] = entry_price_time;
        swing_count++;
      }

      if(entry_found)
      {
        double target_distance_pts = (entry_price - lows[i]) / point_size;
        if(!target_found && target_distance_pts >= guard_points && target_distance_pts < target_best_distance)
        {
          target_best_distance = target_distance_pts;
          target_price = lows[i];
          target_found = true;
          target_price_time = times[i];
        }

        if(!stop_found && fractal_high)
        {
          double stop_distance_pts = (highs[i] - entry_price) / point_size;
          if(stop_distance_pts >= guard_points)
          {
            stop_price = highs[i];
            stop_found = true;
            stop_price_time = times[i];
          }
        }

        if(swing_count < 10)
        {
          double last_swing = swing_sequence[swing_count - 1];
          double swing_distance_pts = (highs[i] - last_swing) / point_size;
          if(swing_distance_pts >= guard_points)
          {
            swing_sequence[swing_count] = highs[i];
            swing_time_sequence[swing_count] = times[i];
            swing_count++;
          }
        }
      }
    }

    if(entry_found && target_found && stop_found && swing_count == grid_max_levels)
    {
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
    ArrayResize(snapshot.swing_times, swing_count);
    for(int s = 0; s < swing_count; s++)
    {
      snapshot.swing_levels[s] = swing_sequence[s];
      snapshot.swing_times[s]  = swing_time_sequence[s];
    }
  }

  return true;
}

bool BuildHedgedSwingSnapshot(const SignalTypes direction,
                              HedgedSwingSnapshot &snapshot)
{
  snapshot = HedgedSwingSnapshot();
  snapshot.hedged_mode = HedgedSwingModeEnabled();

  ENUM_TIMEFRAMES primary_tf  = ResolveHedgedPrimaryTimeframe();
  double guard_points = HedgedResolveGuardPoints(Strategy_Timeframe, primary_tf);
  snapshot.guard_points = guard_points;
  snapshot.source_timeframe = primary_tf;

  HedgedScanTimeframeForSwings(direction, primary_tf, guard_points, snapshot);

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
    ArrayResize(snapshot.swing_times, 1);
    snapshot.swing_times[0] = TimeCurrent();
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

  int swing_total = ArraySize(snapshot.swing_levels);
  if(swing_total < 10 && snapshot.entry_anchor_price > 0.0)
  {
    double last_swing = snapshot.swing_levels[swing_total - 1];
    for(int idx = swing_total; idx < 10; idx++)
    {
      double synthetic = (direction == BULLISH)
                           ? last_swing - guard_points * point_size
                           : last_swing + guard_points * point_size;
      datetime synth_time = TimeCurrent();
      AddElementToArray(snapshot.swing_levels, synthetic);
      AddElementToArray(snapshot.swing_times, synth_time);
      last_swing = synthetic;
    }
  }

  if(ArraySize(snapshot.swing_levels) <= 0 && snapshot.entry_anchor_price > 0.0)
  {
    ArrayResize(snapshot.swing_levels, 1);
    snapshot.swing_levels[0] = snapshot.entry_anchor_price;
    ArrayResize(snapshot.swing_times, 1);
    snapshot.swing_times[0] = TimeCurrent();
  }

  return true;
}

bool BuildHedgedSwingSnapshotWithEntry(const SignalTypes direction,
                                       const double entry_price,
                                       const datetime entry_time,
                                       HedgedSwingSnapshot &snapshot)
{
  snapshot = HedgedSwingSnapshot();
  snapshot.hedged_mode = HedgedSwingModeEnabled();

  ENUM_TIMEFRAMES primary_tf  = ResolveHedgedPrimaryTimeframe();
  double guard_points = HedgedResolveGuardPoints(Strategy_Timeframe, primary_tf);
  snapshot.guard_points = guard_points;
  snapshot.source_timeframe = primary_tf;
  snapshot.entry_anchor_price = entry_price;
  snapshot.anchor_from_fallback = false;

  HedgedScanTimeframeForSwings(direction,
                               primary_tf,
                               guard_points,
                               snapshot,
                               true,
                               entry_price,
                               entry_time);

  double point_size = HedgedResolvePointSize();

  if(!snapshot.target_valid)
  {
    double target_price_calc = (direction == BULLISH)
                                 ? entry_price + guard_points * point_size
                                 : entry_price - guard_points * point_size;
    snapshot.target_price = target_price_calc;
    snapshot.target_valid = (target_price_calc > 0.0);
  }

  if(!snapshot.stop_valid && HedgedSwingSlEnabled(direction))
  {
    double stop_price_calc = (direction == BULLISH)
                               ? entry_price - guard_points * point_size
                               : entry_price + guard_points * point_size;
    snapshot.stop_loss_price = stop_price_calc;
    snapshot.stop_valid = (stop_price_calc > 0.0);
  }
  else
  {
    int swing_total = ArraySize(snapshot.swing_levels);
    if(swing_total < 10)
    {
      double last_swing = snapshot.swing_levels[swing_total - 1];
      for(int idx = swing_total; idx < 10; idx++)
      {
        double synthetic = (direction == BULLISH)
                             ? last_swing - guard_points * point_size
                             : last_swing + guard_points * point_size;
        datetime synth_time = TimeCurrent();
        AddElementToArray(snapshot.swing_levels, synthetic);
        AddElementToArray(snapshot.swing_times, synth_time);
        last_swing = synthetic;
      }
    }
  }

  if(ArraySize(snapshot.swing_levels) <= 0 && snapshot.entry_anchor_price > 0.0)
  {
    ArrayResize(snapshot.swing_levels, 1);
    snapshot.swing_levels[0] = snapshot.entry_anchor_price;
    ArrayResize(snapshot.swing_times, 1);
    snapshot.swing_times[0] = (entry_time > 0) ? entry_time : TimeCurrent();
  }

  snapshot.trailing_price = 0.0;
  snapshot.trailing_bar_time = 0;

  return true;
}

double HedgedCollectDirectionFloatingProfit(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    if(ArraySize(running_bullish_signals) <= 0)
      return 0.0;
    return GridCollectSignalFloatingProfit(running_bullish_signals[0]);
  }
  if(direction == BEARISH)
  {
    if(ArraySize(running_bearish_signals) <= 0)
      return 0.0;
    return GridCollectSignalFloatingProfit(running_bearish_signals[0]);
  }
  return 0.0;
}

double HedgedComputeProfitAtPrice(const SignalParams &signal_params,
                                  const double exit_price)
{
  double total = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  if(contract_size <= 0.0)
    contract_size = 100000.0;

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.position_ticket <= 0)
      continue;
    if(!PositionSelectByTicket(state.position_ticket))
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;

    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    long pos_type = PositionGetInteger(POSITION_TYPE);
    double diff = (pos_type == POSITION_TYPE_BUY)
                    ? (exit_price - open_price)
                    : (open_price - exit_price);
    total += diff * volume * contract_size;
  }
  return total;
}

datetime HedgedResolveLastFilledTime(const SignalParams &signal_params)
{
  datetime latest = signal_params.entry_time;
  int total = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.entry_price <= 0.0)
      continue;
    if(state.last_action_time > latest)
      latest = state.last_action_time;
  }
  return latest;
}

double HedgedResolveSwingTrailingAnchor(const SignalParams &signal_params,
                                        const GridOrderState &grid_order,
                                        const double point_size,
                                        const bool require_profit_guard,
                                        double &anchor_profit,
                                        const bool require_fractal)
{
  anchor_profit = 0.0;
  ENUM_TIMEFRAMES tf = ResolveHedgedPrimaryTimeframe();
  int bars_available = Bars(_Symbol, tf);
  if(bars_available < 3)
    return 0.0;

  datetime cutoff = HedgedResolveLastFilledTime(signal_params);
  int scan_total = HedgedSwingBarsToScan();
  if(scan_total + 2 > bars_available)
    scan_total = bars_available - 2;
  if(scan_total < 3)
    return 0.0;

  double highs[], lows[];
  datetime times[];
  int copied_highs = CopyHigh(_Symbol, tf, 0, scan_total + 2, highs);
  int copied_lows  = CopyLow(_Symbol, tf, 0, scan_total + 2, lows);
  int copied_times = CopyTime(_Symbol, tf, 0, scan_total + 2, times);
  ArraySetAsSeries(highs, true);
  ArraySetAsSeries(lows, true);
  ArraySetAsSeries(times, true);
  if(copied_highs < 3 || copied_lows < 3 || copied_times < 3)
    return 0.0;

  SignalTypes direction = signal_params.signal_type;
  double entry_price = grid_order.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.hedged_swing.entry_anchor_price;
  double current_price = GridCurrentPriceForDirection(direction, false);

  for(int i = 1; i < scan_total; i++)
  {
    datetime bar_time = times[i];
    if(bar_time <= cutoff)
      continue;
    // Completed bar only
    if(bar_time >= times[0])
      continue;

    if(direction == BULLISH)
    {
      if(require_fractal && !HedgedIsFractalLow(lows, i, copied_lows))
        continue;
      double swing = lows[i];
      if(swing >= current_price)
        continue;
      if(require_profit_guard)
      {
        double hypothetical = HedgedComputeProfitAtPrice(signal_params, swing);
        if(hypothetical <= 0.0)
          continue;
        anchor_profit = hypothetical;
      }
      return swing;
    }
    else if(direction == BEARISH)
    {
      if(require_fractal && !HedgedIsFractalHigh(highs, i, copied_highs))
        continue;
      double swing = highs[i];
      if(swing <= current_price)
        continue;
      if(require_profit_guard)
      {
        double hypothetical = HedgedComputeProfitAtPrice(signal_params, swing);
        if(hypothetical <= 0.0)
          continue;
        anchor_profit = hypothetical;
      }
      return swing;
    }
  }
  return 0.0;
}

bool HedgedBuildAndOpenAtAnchor(const SignalTypes direction,
                                const double anchor_price,
                                const datetime anchor_time,
                                SignalParams &out_signal)
{
  out_signal = SignalParams();
  out_signal.signal_type            = direction;
  out_signal.entry_time             = anchor_time;
  out_signal.entry_price            = GridCurrentPriceForDirection(direction, true);
  out_signal.strategy_context       = CONTEXT_SLOT_BASE;
  out_signal.strategy_timeframe     = ResolveHedgedPrimaryTimeframe();
  out_signal.strategy_context_label = "HEDGED";
  out_signal.entry_trigger_mode     = ENTRY_MODE_MA_TREND;
  out_signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;

  if(!BuildHedgedSwingSnapshotWithEntry(direction,
                                        anchor_price,
                                        anchor_time,
                                        out_signal.hedged_swing))
    return false;

  out_signal.grid_entry_reference_price = out_signal.hedged_swing.entry_anchor_price;

  if(!BuildGridOrderForSignal(out_signal))
    return false;

  int level_index = ArraySize(out_signal.grid_orders) - 1;
  if(level_index < 0)
    return false;
  GridOrderState state = out_signal.grid_orders[level_index];
  double point_size = GridResolvePointSize();
  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, state.lot_size);

  if(!GridExecuteLevelTrade(out_signal, state, point_size, normalized_volume))
    return false;

  out_signal.grid_orders[level_index] = state;
  return true;
}

void HedgedEnsureOppositePair(const SignalParams &filled_signal,
                              const GridOrderState &filled_state)
{
  if(!filled_signal.hedged_swing.hedged_mode)
    return;
  if(filled_state.level_index != 0)
    return;

  SignalTypes opposite_direction = (filled_signal.signal_type == BULLISH) ? BEARISH : BULLISH;
  if(!CloseExistingHedgedSignals(opposite_direction)) return;

  SignalParams opposite_signal = SignalParams();
  opposite_signal.signal_type            = opposite_direction;
  opposite_signal.entry_time             = filled_signal.entry_time;
  opposite_signal.entry_price            = GridCurrentPriceForDirection(opposite_direction, true);
  opposite_signal.strategy_context       = filled_signal.strategy_context;
  opposite_signal.strategy_timeframe     = filled_signal.strategy_timeframe;
  opposite_signal.strategy_context_label = filled_signal.strategy_context_label;
  opposite_signal.entry_trigger_mode     = ENTRY_MODE_MA_TREND;
  opposite_signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;

  double anchor_price = filled_state.entry_price;
  if(anchor_price <= 0.0)
    anchor_price = opposite_signal.entry_price;

  BuildHedgedSwingSnapshotWithEntry(opposite_direction,
                                    anchor_price,
                                    filled_signal.entry_time,
                                    opposite_signal.hedged_swing);
  opposite_signal.grid_entry_reference_price = opposite_signal.hedged_swing.entry_anchor_price;

  if(HedgedBuildAndOpenAtAnchor(opposite_direction, anchor_price, filled_signal.entry_time, opposite_signal))
  {
    if(opposite_direction == BULLISH)
      AddElementToArray(running_bullish_signals, opposite_signal);
    else
      AddElementToArray(running_bearish_signals, opposite_signal);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_
