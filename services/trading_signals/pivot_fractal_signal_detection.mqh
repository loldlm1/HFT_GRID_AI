//+------------------------------------------------------------------+
//|                trading_signals/pivot_fractal_signal_detection  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_

enum PivotTouchFixedCounts
{
  PIVOT_TOUCH_CANDIDATE_MAX = 4
};

struct PivotTouchCandidate
{
  int path_order;
  PivotLevelIds level_id;
  SignalTypes direction;
  double level_price;
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
    path_order = -1;
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    level_price = 0.0;
    window.Reset(PERIOD_CURRENT);
  }

  void CopyFrom(const PivotTouchCandidate &other)
  {
    path_order = other.path_order;
    level_id = other.level_id;
    direction = other.direction;
    level_price = other.level_price;
    window.CopyFrom(other.window);
  }
};

void FinalizeExpiredPivotWindow(const PivotFractalWindowState &window,
                                const datetime terminal_time)
{
  if(!PivotV11Enabled() ||
     window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     window.active_bar_open <= 0 ||
     g_pivot_window_terminal_exported_open == window.active_bar_open)
    return;
  if(!PivotV11RecordWindow(window, terminal_time, "EXPIRED"))
    return;
  string window_id = PivotV11WindowId(_Symbol,
                                      window.timeframe,
                                      window.active_bar_open);
  MarkPivotSignalOriginsExportFinalized(window_id);
  g_pivot_window_terminal_exported_open = window.active_bar_open;
}

bool RefreshPivotWindowForRuntime(const datetime observation_time,
                                  const bool force_refresh = false)
{
  if(observation_time <= 0)
    return false;

  ResetLastError();
  datetime current_open = iTime(_Symbol, Macro_Timeframe, 0);
  if(current_open <= 0)
  {
    if(g_pivot_fractal_window.state != PIVOT_WINDOW_VALID)
    {
      g_pivot_fractal_window.timeframe = Macro_Timeframe;
      MarkPivotWindowPending(g_pivot_fractal_window,
                             GetLastError(),
                             "ACTIVE_BAR_UNAVAILABLE",
                             observation_time);
    }
    return false;
  }

  PivotFractalWindowState previous_window(g_pivot_fractal_window);
  if(current_open <= observation_time &&
     previous_window.active_bar_open > 0 &&
     previous_window.active_bar_open <= observation_time &&
     current_open != previous_window.active_bar_open)
  {
    FinalizeExpiredPivotWindow(previous_window, current_open);
  }

  return RefreshPivotFractalWindow(current_open,
                                   observation_time,
                                   force_refresh);
}

void FinalizeActivePivotWindowsForExport()
{
  if(!PivotV11Enabled() ||
     g_pivot_fractal_window.state != PIVOT_WINDOW_VALID ||
     !g_pivot_fractal_window.levels.valid ||
     g_pivot_fractal_window.active_bar_open <= 0 ||
     g_pivot_window_terminal_exported_open ==
       g_pivot_fractal_window.active_bar_open)
    return;

  if(!PivotV11RecordWindow(g_pivot_fractal_window,
                           TimeCurrent(),
                           "RUN_FINISHED"))
    return;
  string window_id = PivotV11WindowId(_Symbol,
                                      g_pivot_fractal_window.timeframe,
                                      g_pivot_fractal_window.active_bar_open);
  MarkPivotSignalOriginsExportFinalized(window_id);
  g_pivot_window_terminal_exported_open =
    g_pivot_fractal_window.active_bar_open;
}

void InitializePivotFractalRuntime()
{
  ResetPivotFractalEngineState();
  ResetPivotSignalRuntimeState();
}

bool RefreshPivotFractalRuntimeContext(const datetime observation_time)
{
  return RefreshPivotWindowForRuntime(observation_time, false);
}

PivotPriceSideStates PivotBidSide(const double bid,
                                  const double level_price)
{
  if(!MathIsValidNumber(bid) ||
     !MathIsValidNumber(level_price) ||
     bid <= 0.0 ||
     level_price <= 0.0)
    return PIVOT_PRICE_SIDE_UNAVAILABLE;
  if(bid < level_price)
    return PIVOT_PRICE_SIDE_BELOW;
  if(bid > level_price)
    return PIVOT_PRICE_SIDE_ABOVE;
  return PIVOT_PRICE_SIDE_EQUAL;
}

void ArmPivotPpFromTick(PivotFractalWindowState &window,
                        const MqlTick &tick)
{
  if(window.pp_arm_state != PIVOT_PP_UNARMED ||
     window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     tick.time <= 0 ||
     tick.time < window.active_bar_open ||
     tick.bid <= 0.0)
    return;

  double pp_price = window.levels.trade_prices[PIVOT_LEVEL_PP];
  PivotPriceSideStates side = PivotBidSide(tick.bid, pp_price);
  if(window.first_observed_time <= 0)
  {
    window.first_observed_time = tick.time;
    window.first_observed_bid = tick.bid;
    window.pp_initial_relation = side;
  }

  if(side == PIVOT_PRICE_SIDE_ABOVE)
    window.pp_arm_state = PIVOT_PP_BUY_ARMED;
  else if(side == PIVOT_PRICE_SIDE_BELOW)
    window.pp_arm_state = PIVOT_PP_SELL_ARMED;
  else
    return;

  window.pp_arm_time = tick.time;
  window.pp_arm_bid = tick.bid;
}

bool AppendPivotTouchCandidate(const PivotLevelIds level_id,
                               const SignalTypes direction,
                               const int path_order,
                               PivotTouchCandidate &candidates[],
                               int &total)
{
  int level_index = (int)level_id;
  if(level_index < 0 ||
     level_index >= PIVOT_LEVEL_COUNT ||
     g_pivot_fractal_window.trigger_states[level_index] !=
       PIVOT_TRIGGER_AVAILABLE)
    return false;

  // First observation owns the identity even if later routing or broker
  // checks deny the attempt.
  g_pivot_fractal_window.trigger_states[level_index] =
    PIVOT_TRIGGER_CONSUMED;
  if(total >= PIVOT_TOUCH_CANDIDATE_MAX)
  {
    PivotV11RegisterDuplicateIdentity();
    return false;
  }

  candidates[total].path_order = path_order;
  candidates[total].level_id = level_id;
  candidates[total].direction = direction;
  candidates[total].level_price =
    g_pivot_fractal_window.levels.trade_prices[level_index];
  total++;
  return true;
}

int DiscoverPivotTouchCandidates(const MqlTick &tick,
                                 PivotTouchCandidate &candidates[])
{
  if(tick.time <= 0 ||
     tick.bid <= 0.0 ||
     tick.ask <= 0.0 ||
     tick.ask < tick.bid ||
     g_pivot_fractal_window.state != PIVOT_WINDOW_VALID ||
     !g_pivot_fractal_window.levels.valid ||
     g_pivot_fractal_window.active_bar_open <= 0 ||
     g_pivot_fractal_window.active_bar_open > tick.time ||
     g_pivot_fractal_window.source_close_boundary > tick.time)
    return 0;

  ArmPivotPpFromTick(g_pivot_fractal_window, tick);
  int total = 0;
  double bid = tick.bid;
  double pp = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_PP];
  double s1 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_S1];
  double s2 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_S2];
  double s3 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_S3];
  double r1 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_R1];
  double r2 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_R2];
  double r3 = g_pivot_fractal_window.levels.trade_prices[PIVOT_LEVEL_R3];

  if(g_pivot_fractal_window.pp_arm_state == PIVOT_PP_BUY_ARMED &&
     bid <= pp)
  {
    AppendPivotTouchCandidate(PIVOT_LEVEL_PP,
                              BULLISH,
                              0,
                              candidates,
                              total);
  }
  if(bid <= s1)
    AppendPivotTouchCandidate(PIVOT_LEVEL_S1, BULLISH, 1, candidates, total);
  if(bid <= s2)
    AppendPivotTouchCandidate(PIVOT_LEVEL_S2, BULLISH, 2, candidates, total);
  if(bid <= s3)
    AppendPivotTouchCandidate(PIVOT_LEVEL_S3, BULLISH, 3, candidates, total);

  if(g_pivot_fractal_window.pp_arm_state == PIVOT_PP_SELL_ARMED &&
     bid >= pp)
  {
    AppendPivotTouchCandidate(PIVOT_LEVEL_PP,
                              BEARISH,
                              0,
                              candidates,
                              total);
  }
  if(bid >= r1)
    AppendPivotTouchCandidate(PIVOT_LEVEL_R1, BEARISH, 1, candidates, total);
  if(bid >= r2)
    AppendPivotTouchCandidate(PIVOT_LEVEL_R2, BEARISH, 2, candidates, total);
  if(bid >= r3)
    AppendPivotTouchCandidate(PIVOT_LEVEL_R3, BEARISH, 3, candidates, total);

  for(int i = 0; i < total; i++)
    candidates[i].window.CopyFrom(g_pivot_fractal_window);
  return total;
}

void BuildPivotSignalFromCandidate(
  const PivotTouchCandidate &candidate,
  const MqlTick &tick,
  const PivotContextFeatureSnapshot &shared_features,
  PivotSignal &signal_out)
{
  signal_out.Reset();
  signal_out.window_id = PivotV11WindowId(_Symbol,
                                          candidate.window.timeframe,
                                          candidate.window.active_bar_open);
  signal_out.origin_id = PivotV11OriginId(_Symbol,
                                          candidate.window.timeframe,
                                          candidate.window.active_bar_open,
                                          candidate.level_id);
  signal_out.broker_signal_id =
    PivotV11BrokerSignalId(signal_out.origin_id);
  signal_out.pivot_timeframe = candidate.window.timeframe;
  signal_out.active_bar_open = candidate.window.active_bar_open;
  signal_out.source_bar_open = candidate.window.source_bar_open;
  signal_out.source_close_boundary =
    candidate.window.source_close_boundary;
  signal_out.level_id = candidate.level_id;
  signal_out.direction = candidate.direction;
  signal_out.trigger_time = tick.time > 0 ? tick.time : TimeCurrent();
  signal_out.trigger_bid = tick.bid;
  signal_out.trigger_ask = tick.ask;
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size > 0.0)
    signal_out.trigger_spread_points = (tick.ask - tick.bid) / point_size;
  signal_out.levels.CopyFrom(candidate.window.levels);
  if(shared_features.captured)
  {
    BuildPivotSignalFeatureSnapshot(shared_features,
                                    candidate.level_price,
                                    signal_out.features);
  }
}

void ProcessPivotTouchCandidates(PivotTouchCandidate &candidates[],
                                 const int total,
                                 const MqlTick &tick)
{
  PivotContextFeatureSnapshot shared_features;
  if(Enable_Signal_Feature_Export)
  {
    CapturePivotContextFeatureSnapshot(tick.bid,
                                       tick.time,
                                       shared_features);
  }

  for(int i = 0; i < total; i++)
  {
    PivotSignal signal;
    BuildPivotSignalFromCandidate(candidates[i],
                                  tick,
                                  shared_features,
                                  signal);
    if(FindPivotSignalIndex(signal.broker_signal_id) >= 0)
    {
      PivotV11RegisterDuplicateIdentity();
      continue;
    }
    ProcessPivotSignalAttempt(signal);
  }
}

void ProcessPreparedPivotFractalTick(const MqlTick &tick)
{
  if(tick.time <= 0)
    return;
  PivotTouchCandidate candidates[PIVOT_TOUCH_CANDIDATE_MAX];
  int total = DiscoverPivotTouchCandidates(tick, candidates);
  if(total > 0)
    ProcessPivotTouchCandidates(candidates, total, tick);
}

void ProcessPivotFractalTick(const MqlTick &tick)
{
  if(tick.time <= 0 || !RefreshPivotFractalRuntimeContext(tick.time))
    return;
  ProcessPreparedPivotFractalTick(tick);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_SIGNAL_DETECTION_MQH_
