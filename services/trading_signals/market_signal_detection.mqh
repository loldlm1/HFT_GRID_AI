//+------------------------------------------------------------------+
//|                             market_signal_detection.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_

void EvaluateContextDirection(const StrategyContextIndicators &snapshot,
                              const StrategyContextTypes context,
                              const SignalTypes direction)
{
  if(!DirectionAllowed(direction))
    return;

  StrategyTrendModes trend_mode = StrategyContextTrendMode(context);
  if(TrendModeUsesAlligator(trend_mode) && !ContextTrendSatisfied(context, direction))
    return;

  if(!StrategyCascadeAllowsSignal(context, direction))
    return;

  datetime structure_time = 0;
  bool entry_allows = false;
  if(!StrategyContextEvaluateEntry(snapshot, direction, structure_time, entry_allows))
    return;

  if(!entry_allows)
    return;

  if(!StrategyContextChannelMaFilterAllowsSignal(context, snapshot))
    return;

  if(!CanAttemptSignal(direction))
    return;

  SignalParams signal;
  signal.signal_type            = direction;
  signal.entry_time             = snapshot.bar_time;
  signal.entry_price            = (direction == BULLISH) ? g_ask : g_bid;
  signal.strategy_context       = context;
  signal.strategy_timeframe     = snapshot.timeframe;
  signal.strategy_context_label = StrategyContextLabel(context);
  signal.context_structure_snapshot_time = structure_time;

  if(!BuildGridOrderForSignal(signal))
  {
    if(Enable_Logs)
      PrintFormat("Grid planning failed for %s context %s signal.",
                  EnumToString(direction),
                  signal.strategy_context_label);
    return;
  }

  string guard_label = StringFormat("%s %s",
                                    signal.strategy_context_label,
                                    EnumToString(direction));
  if(!ChannelGuardAllowsPendingSignal(signal, guard_label))
    return;

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, signal);
  else
    AddElementToArray(running_bearish_signals, signal);

  RegisterFreshStructureUsage(signal);
  RegisterDailySignalStart(signal);
}

void EvaluateContextSignals(const StrategyContextTypes context)
{
  if(context != CONTEXT_SLOT_BASE && !StrategyContextEnabled(context))
    return;

  StrategyContextIndicators snapshot;
  snapshot.context   = context;
  snapshot.timeframe = StrategyContextTimeframe(context);
  snapshot.bar_time  = iTime(_Symbol, snapshot.timeframe, 0);
  if(snapshot.bar_time <= 0)
    return;

  int slot = StrategyContextIndex(context);
  if(g_context_last_bar_time[slot] == snapshot.bar_time)
    return;

  if(!CaptureContextIndicators(context, snapshot))
  {
    ResetContextTrendState(context);
    return;
  }

  g_context_last_bar_time[slot] = snapshot.bar_time;

  for(int dir = 0; dir < 2; dir++)
  {
    SignalTypes direction = (dir == 0) ? BULLISH : BEARISH;
    bool trend_ready = false;
    bool trend_pass  = false;
    if(!StrategyContextEvaluateTrend(snapshot, direction, trend_ready, trend_pass))
    {
      ResetContextTrendState(context);
      return;
    }
    if(trend_ready)
      UpdateContextTrendState(context, direction, true, trend_pass);
  }

  EvaluateContextDirection(snapshot, context, BULLISH);
  EvaluateContextDirection(snapshot, context, BEARISH);
}

void DetectStrategySignals()
{
  int total = ArraySize(STRATEGY_CONTEXT_EVALUATION_ORDER);
  for(int i = 0; i < total; i++)
    EvaluateContextSignals(STRATEGY_CONTEXT_EVALUATION_ORDER[i]);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
