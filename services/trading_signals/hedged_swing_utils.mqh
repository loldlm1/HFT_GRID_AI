//+------------------------------------------------------------------+
//|                           hedged_swing_utils.mqh                 |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_
#define _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_

IndicatorsHandleInfo HedgedAtrHandles[];
const int GRID_MAX_LEVELS = 2;

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
  double swing_sequence[2];
  datetime swing_time_sequence[2];
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

        if(swing_count < 2)
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

        if(swing_count < 2)
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

    if(entry_found && target_found && stop_found && swing_count >= 2)
      break;
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

  double guard_point_size = guard_points * point_size;
  double prior_entry_for_target = 0.0;
  HedgedEnsureGuardedSnapshot(direction,
                              guard_points,
                              point_size,
                              entry_price_time,
                              prior_entry_for_target,
                              snapshot);

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

void HedgedEnsureGuardedSnapshot(const SignalTypes direction,
                                 const double guard_points,
                                 const double point_size,
                                 const datetime entry_time_value,
                                 const double prior_entry_price,
                                 HedgedSwingSnapshot &snapshot)
{
  double anchor = snapshot.entry_anchor_price;
  double guard_price = guard_points * point_size;
  if(anchor <= 0.0 || guard_points <= 0.0 || point_size <= 0.0)
    return;

  if(!snapshot.target_valid)
  {
    double target_price = (prior_entry_price > 0.0)
                            ? prior_entry_price
                            : (direction == BULLISH)
                                ? anchor + guard_price
                                : anchor - guard_price;
    snapshot.target_price = target_price;
    snapshot.target_valid = (target_price > 0.0);
  }

  if(!snapshot.stop_valid && HedgedSwingSlEnabled(direction))
  {
    double stop_price_calc = (direction == BULLISH)
                               ? anchor - guard_price
                               : anchor + guard_price;
    snapshot.stop_loss_price = stop_price_calc;
    snapshot.stop_valid = (stop_price_calc > 0.0);
  }

  if(ArraySize(snapshot.swing_levels) < 2)
  {
    ArrayResize(snapshot.swing_levels, 2);
    ArrayResize(snapshot.swing_times, 2);
    double swing1 = (direction == BULLISH)
                      ? anchor - guard_price
                      : anchor + guard_price;
    snapshot.swing_levels[0] = anchor;
    snapshot.swing_levels[1] = swing1;
    snapshot.swing_times[0]  = (entry_time_value > 0) ? entry_time_value : TimeCurrent();
    snapshot.swing_times[1]  = TimeCurrent();
  }
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
  out_signal.hedged_next_swing_index = (state.entry_price > 0.0) ? 1 : 0;
  return true;
}

bool HedgedRefreshSwingsAfterFill(SignalParams &signal_params,
                                  const double last_fill_price,
                                  const datetime last_fill_time)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;

  int filled_count = 0;
  int total_orders = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.entry_price > 0.0)
      filled_count++;
  }

  HedgedSwingSnapshot rebuilt;
  if(!BuildHedgedSwingSnapshotWithEntry(signal_params.signal_type,
                                        last_fill_price,
                                        last_fill_time,
                                        rebuilt))
    return false;

  signal_params.hedged_swing = rebuilt;
  signal_params.hedged_next_swing_index = filled_count;

  return true;
}

bool HedgedGapRequiresRebase(const SignalParams &signal_params,
                             const double current_price)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;

  int swing_total = ArraySize(signal_params.hedged_swing.swing_levels);
  if(swing_total <= 0)
    return false;

  // Find highest filled level index
  int highest_filled = -1;
  int total_orders = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.entry_price > 0.0)
      highest_filled = i;
  }
  if(highest_filled < 0)
    return false;

  int next_idx = highest_filled + 1;
  int after_next_idx = highest_filled + 2;

  double p_next = 0.0;
  double p_after_next = 0.0;

  if(next_idx < swing_total)
    p_next = signal_params.hedged_swing.swing_levels[next_idx];
  else
    p_next = signal_params.hedged_swing.swing_levels[swing_total - 1];

  if(after_next_idx < swing_total)
    p_after_next = signal_params.hedged_swing.swing_levels[after_next_idx];
  else
  {
    // Extrapolate using last spacing
    double last = signal_params.hedged_swing.swing_levels[swing_total - 1];
    double prev = (swing_total >= 2) ? signal_params.hedged_swing.swing_levels[swing_total - 2] : last;
    double spacing = MathAbs(last - prev);
    if(signal_params.signal_type == BULLISH)
      p_after_next = last - spacing;
    else
      p_after_next = last + spacing;
  }

  if(signal_params.signal_type == BULLISH)
    return (current_price <= p_after_next);
  return (current_price >= p_after_next);
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
  opposite_signal.hedged_next_swing_index = 0;

  if(HedgedBuildAndOpenAtAnchor(opposite_direction, anchor_price, filled_signal.entry_time, opposite_signal))
  {
    if(opposite_direction == BULLISH)
      AddElementToArray(running_bullish_signals, opposite_signal);
    else
      AddElementToArray(running_bearish_signals, opposite_signal);
  }
}

bool HedgedActivateInitialPendingLevel(SignalParams &signal_params)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;

  int swing_total = ArraySize(signal_params.hedged_swing.swing_levels);
  if(swing_total <= 0)
    return false;

  if(GridSignalHasExecutedLevel(signal_params))
    return false;

  int total_orders = ArraySize(signal_params.grid_orders);
  if(total_orders == 0)
  {
    BuildGridOrderForSignal(signal_params);
    total_orders = ArraySize(signal_params.grid_orders);
  }

  if(total_orders <= 0)
    return false;

  double trigger_price = signal_params.hedged_swing.swing_levels[0];
  if(trigger_price <= 0.0)
    return false;

  double entry_side_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  bool should_fill = false;
  if(signal_params.signal_type == BULLISH)
    should_fill = (entry_side_price <= trigger_price);
  else
    should_fill = (entry_side_price >= trigger_price);

  if(!should_fill)
    return false;

  GridOrderState state = signal_params.grid_orders[0];
  state.entry_reference_price = trigger_price;

  double point_size = GridResolvePointSize();
  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, state.lot_size);

  if(!GridExecuteLevelTrade(signal_params, state, point_size, normalized_volume))
    return false;

  state.last_action_time = TimeCurrent();
  signal_params.grid_orders[0] = state;
  signal_params.hedged_next_swing_index = 1;

  double filled_price = (state.entry_price > 0.0) ? state.entry_price : trigger_price;
  HedgedRefreshSwingsAfterFill(signal_params, filled_price, state.last_action_time);

  HedgedEnsureOppositePair(signal_params, state);
  return true;
}

bool HedgedActivatePendingLevels(SignalParams &signal_params)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;

  int target_index = signal_params.hedged_next_swing_index;
  if(target_index < 1)
    return false;

  // Ensure we have a grid order slot for this level
  int total_orders = ArraySize(signal_params.grid_orders);
  while(total_orders <= target_index)
  {
    if(!BuildGridOrderForSignal(signal_params))
      return false;
    total_orders = ArraySize(signal_params.grid_orders);
  }

  int swing_total = ArraySize(signal_params.hedged_swing.swing_levels);
  if(swing_total < 2)
    return false;

  // Use the latest swing (index 1) for every deep level
  double trigger_price = signal_params.hedged_swing.swing_levels[1];
  if(trigger_price <= 0.0)
    return false;

  double entry_side_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  bool should_fill = false;
  if(signal_params.signal_type == BULLISH)
    should_fill = (entry_side_price <= trigger_price);
  else
    should_fill = (entry_side_price >= trigger_price);

  if(!should_fill)
    return false;

  GridOrderState state = signal_params.grid_orders[target_index];
  state.entry_reference_price = trigger_price;

  double point_size = GridResolvePointSize();
  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, state.lot_size);

  if(!GridExecuteLevelTrade(signal_params, state, point_size, normalized_volume))
    return false;

  state.last_action_time = TimeCurrent();
  signal_params.grid_orders[target_index] = state;
  signal_params.hedged_next_swing_index = target_index + 1;

  double filled_price = (state.entry_price > 0.0) ? state.entry_price : trigger_price;
  HedgedRefreshSwingsAfterFill(signal_params, filled_price, state.last_action_time);

  if(target_index > 0)
    signal_params.hedged_swing.target_price = signal_params.grid_orders[target_index - 1].entry_price;

  HedgedEnsureOppositePair(signal_params, state);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_HEDGED_SWING_UTILS_MQH_
