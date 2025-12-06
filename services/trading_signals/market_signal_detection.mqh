//+------------------------------------------------------------------+
//|                             market_signal_detection.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_

void AssignContextSnapshotToSignal(const StrategyContextIndicators &snapshot,
                                   SignalParams &signal)
{
  StrategyTrendModes trend_mode = StrategyContextTrendMode(snapshot.context);

  if(snapshot.context == CONTEXT_SLOT_TREND)
  {
    signal.trend_filter_mode    = trend_mode;
    signal.trend_bpercent_valid = snapshot.bpercent_valid;
    signal.trend_bpercent_data  = snapshot.bpercent_data;
    signal.trend_alligator_valid = snapshot.alligator_valid;
    signal.trend_alligator_data  = snapshot.alligator_data;
    signal.trend_stochastic_valid = snapshot.stochastic_valid;
    signal.trend_stochastic_data  = snapshot.stochastic_data;
    signal.trend_structure_valid  = snapshot.structure_valid;
    signal.trend_structure_data   = snapshot.structure_data;
  }
  else if(snapshot.context == CONTEXT_SLOT_MACRO)
  {
    signal.macro_filter_mode    = trend_mode;
    signal.macro_bpercent_valid = snapshot.bpercent_valid;
    signal.macro_bpercent_data  = snapshot.bpercent_data;
    signal.macro_alligator_valid = snapshot.alligator_valid;
    signal.macro_alligator_data  = snapshot.alligator_data;
    signal.macro_stochastic_valid = snapshot.stochastic_valid;
    signal.macro_stochastic_data  = snapshot.stochastic_data;
    signal.macro_structure_valid  = snapshot.structure_valid;
    signal.macro_structure_data   = snapshot.structure_data;
  }
  else if(snapshot.context == CONTEXT_SLOT_SESSION)
  {
    signal.session_filter_mode    = trend_mode;
    signal.session_bpercent_valid = snapshot.bpercent_valid;
    signal.session_bpercent_data  = snapshot.bpercent_data;
    signal.session_alligator_valid = snapshot.alligator_valid;
    signal.session_alligator_data  = snapshot.alligator_data;
    signal.session_stochastic_valid = snapshot.stochastic_valid;
    signal.session_stochastic_data  = snapshot.stochastic_data;
    signal.session_structure_valid  = snapshot.structure_valid;
    signal.session_structure_data   = snapshot.structure_data;
  }
  else
  {
    signal.base_bpercent_valid   = snapshot.bpercent_valid;
    signal.base_bpercent_data    = snapshot.bpercent_data;
    signal.base_alligator_valid  = snapshot.alligator_valid;
    signal.base_alligator_data   = snapshot.alligator_data;
    signal.base_stochastic_valid = snapshot.stochastic_valid;
    signal.base_stochastic_data  = snapshot.stochastic_data;
    signal.base_structure_valid  = snapshot.structure_valid;
    signal.base_structure_data   = snapshot.structure_data;
    signal.base_body_ma_valid    = snapshot.body_ma_valid;
    signal.base_body_ma_data     = snapshot.body_ma_data;
  }
}

void RefreshUpstreamTrendsOnBaseBar()
{
  StrategyContextTypes upstream_contexts[] = {CONTEXT_SLOT_TREND,
                                              CONTEXT_SLOT_MACRO,
                                              CONTEXT_SLOT_SESSION};

  int total = ArraySize(upstream_contexts);
  for(int i = 0; i < total; i++)
  {
    StrategyContextTypes ctx = upstream_contexts[i];
    if(!StrategyContextEnabled(ctx))
      continue;

    ResetContextTrendState(ctx);

    StrategyTrendModes trend_mode = StrategyContextTrendMode(ctx);
    if(!TrendModeUsesAlligator(trend_mode))
      continue;

    StrategyContextIndicators trend_snapshot;
    if(!CaptureContextTrendOnly(ctx, trend_snapshot))
      continue;

    SignalTypes directions[2] = {BULLISH, BEARISH};
    for(int d = 0; d < 2; d++)
    {
      SignalTypes dir = directions[d];
      if(!DirectionAllowed(dir))
        continue;
      bool ready = false;
      bool pass = false;
      if(!StrategyContextEvaluateTrend(trend_snapshot, dir, ready, pass))
        continue;
      if(ready)
        UpdateContextTrendState(ctx, dir, true, pass);
    }
  }
}

void EvaluateContextSignals(const StrategyContextTypes context)
{
  if(context != CONTEXT_SLOT_BASE && !StrategyContextEnabled(context))
    return;

  int runtime_slot = StrategyContextIndex(context);

  StrategyContextIndicators snapshot;
  snapshot.context   = context;
  snapshot.timeframe = StrategyContextTimeframe(context);
  snapshot.bar_time  = iTime(_Symbol, snapshot.timeframe, 0);
  if(snapshot.bar_time <= 0)
    return;

  if(g_context_runtime[runtime_slot].last_bar_time == snapshot.bar_time)
    return;

  ResetContextTrendState(context);

  if(!CaptureContextIndicators(context, snapshot))
    return;

  g_context_runtime[runtime_slot].last_bar_time = snapshot.bar_time;

  bool channel_state = StrategyContextChannelMaFilterAllowsSignal(context, snapshot);

  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int dir = 0; dir < 2; dir++)
  {
    SignalTypes direction = directions[dir];
    if(!DirectionAllowed(direction))
      continue;

    bool trend_ready = false;
    bool trend_pass  = false;
    if(!StrategyContextEvaluateTrend(snapshot, direction, trend_ready, trend_pass))
      return;

    datetime structure_time = 0;
    bool entry_allows = false;
    bool filters_pass = false;
    if(!StrategyContextEvaluateEntry(snapshot,
                                     direction,
                                     structure_time,
                                     entry_allows,
                                     filters_pass))
      return;

    bool cascade_pass = trend_pass && channel_state && filters_pass;
    if(trend_ready)
      UpdateContextTrendState(context, direction, true, cascade_pass);

    if(context == CONTEXT_SLOT_BASE)
      RefreshUpstreamTrendsOnBaseBar();

    if(!cascade_pass)
      continue;

    if(!StrategyCascadeAllowsSignal(context, direction))
      continue;

    if(!entry_allows)
      continue;

    if(!CanAttemptSignal(direction))
      continue;

    SignalParams signal;
    signal.signal_type            = direction;
    signal.entry_time             = snapshot.bar_time;
    signal.entry_price            = (direction == BULLISH) ? g_ask : g_bid;
    signal.strategy_context       = context;
    signal.strategy_timeframe     = snapshot.timeframe;
    signal.strategy_context_label = StrategyContextLabel(context);
    signal.entry_trigger_mode     = ResolveGlobalEntryTriggerMode();
    signal.entry_evaluation_mode  = StrategyContextEntryEvaluation(context);
    signal.context_structure_snapshot_time = structure_time;
    AssignContextSnapshotToSignal(snapshot, signal);

    if(!BuildGridOrderForSignal(signal))
    {
      if(Enable_Logs)
        PrintFormat("Grid planning failed for %s context %s signal.",
                    EnumToString(direction),
                    signal.strategy_context_label);
      continue;
    }

    string guard_label = StringFormat("%s %s",
                                      signal.strategy_context_label,
                                      EnumToString(direction));
    if(!ChannelGuardAllowsPendingSignal(signal, guard_label))
      continue;

    if(direction == BULLISH)
      AddElementToArray(running_bullish_signals, signal);
    else
      AddElementToArray(running_bearish_signals, signal);

    RegisterFreshStructureUsage(signal);
    RegisterDailySignalStart(signal);
  }
}

bool BuildHedgedSignalParams(const SignalTypes direction,
                             const datetime bar_time,
                             SignalParams &signal)
{
  HedgedSwingSnapshot swing_snapshot;
  if(!BuildHedgedSwingSnapshot(direction, swing_snapshot))
    return false;

  signal = SignalParams();
  signal.signal_type            = direction;
  signal.entry_time             = bar_time;
  signal.entry_price            = (direction == BULLISH) ? g_ask : g_bid;
  signal.strategy_context       = CONTEXT_SLOT_BASE;
  signal.strategy_timeframe     = ResolveHedgedPrimaryTimeframe();
  signal.strategy_context_label = "HEDGED";
  signal.entry_trigger_mode     = ENTRY_MODE_MA_TREND;
  signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;
  signal.hedged_swing           = swing_snapshot;
  signal.grid_entry_reference_price = swing_snapshot.entry_anchor_price;
  return true;
}

void CloseExistingHedgedSignals()
{
  double point_size = GridResolvePointSize();

  int bullish_total = ArraySize(running_bullish_signals);
  for(int i = 0; i < bullish_total; i++)
    GridCloseAllLevels(running_bullish_signals[i], point_size);
  ArrayResize(running_bullish_signals, 0);

  int bearish_total = ArraySize(running_bearish_signals);
  for(int j = 0; j < bearish_total; j++)
    GridCloseAllLevels(running_bearish_signals[j], point_size);
  ArrayResize(running_bearish_signals, 0);
}

void DetectHedgedSwingSignals()
{
  ENUM_TIMEFRAMES eval_tf = ResolveHedgedPrimaryTimeframe();
  if(eval_tf == PERIOD_CURRENT)
    eval_tf = _Period;

  datetime bar_time = iTime(_Symbol, eval_tf, 0);
  if(bar_time <= 0)
    return;

  int base_slot = StrategyContextIndex(CONTEXT_SLOT_BASE);
  if(g_context_runtime[base_slot].last_bar_time > 0 &&
     g_context_runtime[base_slot].last_bar_time != bar_time)
  {
    CloseExistingHedgedSignals();
  }
  if(g_context_runtime[base_slot].last_bar_time == bar_time)
    return;
  g_context_runtime[base_slot].last_bar_time = bar_time;

  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int idx = 0; idx < 2; idx++)
  {
    SignalTypes direction = directions[idx];
    if(!CanAttemptSignal(direction))
      continue;

    SignalParams signal;
    if(!BuildHedgedSignalParams(direction, bar_time, signal))
      continue;

    if(!BuildGridOrderForSignal(signal))
      continue;

    if(direction == BULLISH)
      AddElementToArray(running_bullish_signals, signal);
    else
      AddElementToArray(running_bearish_signals, signal);

    RegisterDailySignalStart(signal);
  }
}

void DetectStrategySignals()
{
  if(HedgedSwingModeEnabled())
  {
    DetectHedgedSwingSignals();
    return;
  }

  int total = ArraySize(STRATEGY_CONTEXT_EVALUATION_ORDER);
  for(int i = 0; i < total; i++)
    EvaluateContextSignals(STRATEGY_CONTEXT_EVALUATION_ORDER[i]);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
