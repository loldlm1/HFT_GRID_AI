//+------------------------------------------------------------------+
//|                trading_signals/pivot_fractal_signal_detection  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_

const int PIVOT_TOUCH_CANDIDATE_MAX =
  PIVOT_FRACTAL_TIMEFRAME_COUNT * PIVOT_LEVEL_COUNT;

struct PivotTouchCandidate
{
  int timeframe_order;
  int level_order;
  PivotLevelIds level_id;
  SignalTypes direction;
  double level_price;
  double distance_from_previous_close;
  PivotFractalWindowState window;

  PivotTouchCandidate()
  {
    Reset();
  }

  PivotTouchCandidate(const PivotTouchCandidate &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    timeframe_order = -1;
    level_order = -1;
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    level_price = 0.0;
    distance_from_previous_close = 0.0;
    window.Reset(PERIOD_CURRENT);
  }

  void CopyFrom(const PivotTouchCandidate &other)
  {
    timeframe_order = other.timeframe_order;
    level_order = other.level_order;
    level_id = other.level_id;
    direction = other.direction;
    level_price = other.level_price;
    distance_from_previous_close = other.distance_from_previous_close;
    window.CopyFrom(other.window);
  }
};

bool PivotWindowRetryDue(const datetime now_time)
{
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    if(g_pivot_fractal_windows[i].state == PIVOT_WINDOW_EMPTY)
      return true;
    if(g_pivot_fractal_windows[i].state == PIVOT_WINDOW_PENDING &&
       (g_pivot_fractal_windows[i].next_retry_time <= 0 ||
        now_time >= g_pivot_fractal_windows[i].next_retry_time))
      return true;
  }
  return false;
}

void FinalizeExpiredPivotWindow(const int window_index,
                                const PivotFractalWindowState &window,
                                const datetime terminal_time)
{
  if(!PivotV9Enabled() ||
     window_index < 0 ||
     window_index >= PIVOT_FRACTAL_TIMEFRAME_COUNT ||
     window.active_bar_open <= 0 ||
     g_pivot_window_terminal_exported_open[window_index] ==
       window.active_bar_open)
    return;
  PivotV9RecordWindow(window, terminal_time, "EXPIRED");
  g_pivot_window_terminal_exported_open[window_index] =
    window.active_bar_open;
}

void ExportPivotWindowLevelsIfNeeded(const int window_index)
{
  if(!PivotV9Enabled() ||
     window_index < 0 ||
     window_index >= PIVOT_FRACTAL_TIMEFRAME_COUNT)
    return;
  PivotFractalWindowState window;
  if(!PivotFractalWindowAt(window_index, window) ||
     window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     g_pivot_window_levels_exported_open[window_index] ==
       window.active_bar_open)
    return;
  PivotV9RecordLevels(window);
  g_pivot_window_levels_exported_open[window_index] =
    window.active_bar_open;
}

void RefreshPivotWindowsForRuntime(const bool force_refresh = false)
{
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    PivotFractalWindowState previous_window;
    PivotFractalWindowAt(i, previous_window);
    ENUM_TIMEFRAMES timeframe = PivotFractalTimeframeAt(i);
    datetime current_open = iTime(_Symbol, timeframe, 0);
    if(current_open > 0 &&
       previous_window.active_bar_open > 0 &&
       current_open != previous_window.active_bar_open)
    {
      FinalizeExpiredPivotWindow(i,
                                 previous_window,
                                 current_open);
      g_pivot_window_levels_exported_open[i] = 0;
    }

    RefreshPivotFractalWindow(i, force_refresh);
    ExportPivotWindowLevelsIfNeeded(i);
  }
}

void FinalizeActivePivotWindowsForExport(const string terminal_status)
{
  if(!PivotV9Enabled())
    return;
  datetime terminal_time = TimeCurrent();
  for(int i = 0; i < PIVOT_FRACTAL_TIMEFRAME_COUNT; i++)
  {
    PivotFractalWindowState window;
    if(!PivotFractalWindowAt(i, window) ||
       window.active_bar_open <= 0 ||
       g_pivot_window_terminal_exported_open[i] ==
         window.active_bar_open)
      continue;
    PivotV9RecordWindow(window, terminal_time, terminal_status);
    g_pivot_window_terminal_exported_open[i] = window.active_bar_open;
  }
}

void InitializePivotFractalRuntime()
{
  ResetPivotM1SideContext();
  ResetPivotFractalEngineState();
  ResetPivotSignalRuntimeState();
  RefreshPivotM1SideContext(true);
  RefreshPivotWindowsForRuntime(true);
}

void RefreshPivotFractalRuntimeContext()
{
  datetime previous_boundary = g_pivot_m1_side_context.close_boundary;
  RefreshPivotM1SideContext(false);
  bool m1_bar_changed = g_pivot_m1_side_context.close_boundary > 0 &&
                        g_pivot_m1_side_context.close_boundary !=
                          previous_boundary;
  if(m1_bar_changed || PivotWindowRetryDue(TimeCurrent()))
    RefreshPivotWindowsForRuntime(false);
}

SignalTypes ResolvePivotTouchDirection(const PivotPriceSideStates side,
                                       const double live_bid,
                                       const double level_price)
{
  if(side == PIVOT_PRICE_SIDE_ABOVE && live_bid <= level_price)
    return BULLISH;
  if(side == PIVOT_PRICE_SIDE_BELOW && live_bid >= level_price)
    return BEARISH;
  return NO_SIGNAL;
}

int DiscoverPivotTouchCandidates(const MqlTick &tick,
                                 PivotTouchCandidate &candidates[])
{
  if(!g_pivot_m1_side_context.valid ||
     tick.bid <= 0.0 ||
     tick.ask <= 0.0 ||
     tick.ask < tick.bid)
    return 0;

  int total = 0;
  for(int window_index = 0;
      window_index < PIVOT_FRACTAL_TIMEFRAME_COUNT;
      window_index++)
  {
    if(g_pivot_fractal_windows[window_index].state != PIVOT_WINDOW_VALID ||
       !g_pivot_fractal_windows[window_index].levels.valid)
      continue;

    for(int level_index = 0;
        level_index < PIVOT_LEVEL_COUNT;
        level_index++)
    {
      if(g_pivot_fractal_windows[window_index].trigger_states[level_index] !=
         PIVOT_TRIGGER_AVAILABLE)
        continue;
      double level_price =
        g_pivot_fractal_windows[window_index].levels.trade_prices[level_index];
      PivotPriceSideStates side = PivotM1SideRelativeToLevel(level_price);
      SignalTypes direction = ResolvePivotTouchDirection(side,
                                                         tick.bid,
                                                         level_price);
      if(direction == NO_SIGNAL)
        continue;

      g_pivot_fractal_windows[window_index].trigger_states[level_index] =
        PIVOT_TRIGGER_CONSUMED;
      if(total >= PIVOT_TOUCH_CANDIDATE_MAX)
      {
        PivotV9RegisterDuplicateIdentity();
        continue;
      }

      candidates[total].timeframe_order = window_index;
      candidates[total].level_order = level_index;
      candidates[total].level_id = (PivotLevelIds)level_index;
      candidates[total].direction = direction;
      candidates[total].level_price = level_price;
      candidates[total].distance_from_previous_close =
        MathAbs(level_price - g_pivot_m1_side_context.previous_bid_close);
      candidates[total].window.CopyFrom(
        g_pivot_fractal_windows[window_index]);
      total++;
    }
  }
  return total;
}

bool PivotTouchCandidateComesBefore(const PivotTouchCandidate &left,
                                    const PivotTouchCandidate &right)
{
  if(left.distance_from_previous_close + 1e-12 <
     right.distance_from_previous_close)
    return true;
  if(right.distance_from_previous_close + 1e-12 <
     left.distance_from_previous_close)
    return false;
  if(left.timeframe_order != right.timeframe_order)
    return left.timeframe_order < right.timeframe_order;
  return left.level_order < right.level_order;
}

void SortPivotTouchCandidates(PivotTouchCandidate &candidates[],
                              const int total)
{
  for(int i = 1; i < total; i++)
  {
    PivotTouchCandidate current(candidates[i]);
    int j = i - 1;
    while(j >= 0 && PivotTouchCandidateComesBefore(current,
                                                   candidates[j]))
    {
      candidates[j + 1].CopyFrom(candidates[j]);
      j--;
    }
    candidates[j + 1].CopyFrom(current);
  }
}

void BuildPivotSignalFromCandidate(const PivotTouchCandidate &candidate,
                                   const MqlTick &tick,
                                   PivotSignal &signal_out)
{
  signal_out.Reset();
  signal_out.window_id = PivotV9WindowId(_Symbol,
                                         candidate.window.timeframe,
                                         candidate.window.active_bar_open);
  signal_out.signal_id = PivotV9SignalId(_Symbol,
                                         candidate.window.timeframe,
                                         candidate.window.active_bar_open,
                                         candidate.level_id);
  signal_out.pivot_timeframe = candidate.window.timeframe;
  signal_out.active_bar_open = candidate.window.active_bar_open;
  signal_out.source_bar_open = candidate.window.source_bar_open;
  signal_out.source_close_boundary =
    candidate.window.source_close_boundary;
  signal_out.level_id = candidate.level_id;
  signal_out.direction = candidate.direction;
  signal_out.trigger_time = tick.time > 0 ? tick.time : TimeCurrent();
  signal_out.previous_m1_bar_open =
    g_pivot_m1_side_context.previous_bar_open;
  signal_out.previous_m1_close_boundary =
    g_pivot_m1_side_context.close_boundary;
  signal_out.previous_m1_bid_close =
    g_pivot_m1_side_context.previous_bid_close;
  signal_out.trigger_bid = tick.bid;
  signal_out.trigger_ask = tick.ask;
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size > 0.0)
    signal_out.trigger_spread_points = (tick.ask - tick.bid) / point_size;
  signal_out.touch_distance = candidate.distance_from_previous_close;
  signal_out.levels.CopyFrom(candidate.window.levels);
}

void ProcessPivotTouchCandidates(PivotTouchCandidate &candidates[],
                                 const int total,
                                 const MqlTick &tick)
{
  SortPivotTouchCandidates(candidates, total);
  for(int i = 0; i < total; i++)
  {
    PivotSignal signal;
    BuildPivotSignalFromCandidate(candidates[i], tick, signal);
    if(FindPivotSignalIndex(signal.signal_id) >= 0)
    {
      PivotV9RegisterDuplicateIdentity();
      continue;
    }
    ProcessPivotSignalAttempt(signal);
  }
}

void ProcessPivotFractalTick(const MqlTick &tick)
{
  RefreshPivotFractalRuntimeContext();
  PivotTouchCandidate candidates[PIVOT_TOUCH_CANDIDATE_MAX];
  int total = DiscoverPivotTouchCandidates(tick, candidates);
  if(total > 0)
    ProcessPivotTouchCandidates(candidates, total, tick);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_
