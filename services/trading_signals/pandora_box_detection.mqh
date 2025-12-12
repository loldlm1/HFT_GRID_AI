//+------------------------------------------------------------------+
//|                      pandora_box_detection.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_

double PandoraResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

ENUM_TIMEFRAMES PandoraResolveBoxTimeframe()
{
  ENUM_TIMEFRAMES tf = Strategy_Timeframe;
  if(tf == PERIOD_CURRENT)
    tf = PERIOD_M1;
  if(!IsStrategyTimeframeSupported(tf))
    tf = PERIOD_M1;
  return tf;
}

bool PandoraComputeBoxWindow()
{
  if(!PandoraEnsureWindowParsed())
    return false;

  if(!PandoraWindowCompleted())
    return false;

  if(g_pandora_box_state.box_computed)
    return g_pandora_box_state.box_valid;

  g_pandora_box_state.box_computed = true;
  g_pandora_box_state.box_valid    = false;
  g_pandora_box_state.invalid_reason = "";

  ENUM_TIMEFRAMES tf = PandoraResolveBoxTimeframe();
  MqlRates rates[];
  int copied = CopyRates(_Symbol,
                         tf,
                         g_pandora_box_state.window_start_time,
                         g_pandora_box_state.window_end_time,
                         rates);
  if(copied <= 0)
  {
    g_pandora_box_state.invalid_reason = "No data for Pandora box window";
    return false;
  }

  double box_high = rates[0].high;
  double box_low  = rates[0].low;
  for(int i = 1; i < copied; i++)
  {
    if(rates[i].high > box_high)
      box_high = rates[i].high;
    if(rates[i].low < box_low || box_low <= 0.0)
      box_low = rates[i].low;
  }

  double point_size   = PandoraResolvePointSizeSafe();
  double range_points = 0.0;
  if(point_size > 0.0 && box_high > 0.0 && box_low > 0.0)
    range_points = MathAbs(box_high - box_low) / point_size;

  g_pandora_box_state.box_high         = box_high;
  g_pandora_box_state.box_low          = box_low;
  g_pandora_box_state.box_range_points = range_points;

  double offset_points = g_pandora_box_state.offset_points;
  if(offset_points > 0.0)
    offset_points = EnforceBrokerDistance(g_symbol_constraints, offset_points);
  double offset_price = offset_points * point_size;
  g_pandora_box_state.effective_offset_points = offset_points;

  g_pandora_box_state.breakout_high_price = (box_high > 0.0) ? box_high + offset_price : 0.0;
  g_pandora_box_state.breakout_low_price  = (box_low > 0.0)  ? box_low  - offset_price : 0.0;

  if(box_high <= 0.0 || box_low <= 0.0 || range_points <= 0.0)
  {
    g_pandora_box_state.invalid_reason = "Failed to resolve Pandora box prices";
    return false;
  }

  if(g_pandora_box_state.max_range_points > 0.0 &&
     range_points > g_pandora_box_state.max_range_points)
  {
    g_pandora_box_state.box_valid = false;
    g_pandora_box_state.invalid_reason = "Pandora box range exceeded";
    return false;
  }

  g_pandora_box_state.box_valid = true;
  return true;
}

bool PandoraGuardsAllowAttempt(const SignalTypes direction)
{
  if(!ProtectionRiskAllowsSignalAttempt())
    return false;

  if(!DebugEquityGuardAllowsProcessing())
    return false;

  if(g_pandora_box_state.respect_session_filter && !SessionTimeFilterAllowsSignalAttempt())
    return false;

  if(!DailySignalLimitAllowsAttempt(direction))
  {
    if(Enable_Logs)
      Print("Pandora box daily limit reached for direction: ", EnumToString(direction));
    return false;
  }

  if(!SignalConcurrencyAllowsAttempt(direction))
    return false;

  return true;
}

bool PandoraPriceTriggersSignal(const SignalTypes direction)
{
  double trigger_price = (direction == BULLISH)
                           ? g_pandora_box_state.breakout_high_price
                           : g_pandora_box_state.breakout_low_price;
  if(trigger_price <= 0.0)
    return false;

  double current_price = GridCurrentPriceForDirection(direction, true);
  if(direction == BULLISH)
    return current_price >= trigger_price;
  return current_price <= trigger_price;
}

bool PandoraBuildSignal(const SignalTypes direction)
{
  SignalParams signal;
  signal.signal_type            = direction;
  signal.entry_time             = TimeCurrent();
  signal.entry_price            = GridCurrentPriceForDirection(direction, true);
  signal.strategy_context       = CONTEXT_SLOT_BASE;
  signal.strategy_timeframe     = Strategy_Timeframe;
  signal.strategy_context_label = "PANDORA";
  signal.entry_trigger_mode     = ENTRY_EVAL_OFF;
  signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;

  if(!BuildGridOrderForSignal(signal))
  {
    if(Enable_Logs)
      Print("Pandora grid planning failed for direction: ", EnumToString(direction));
    return false;
  }

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, signal);
  else
    AddElementToArray(running_bearish_signals, signal);

  RegisterDailySignalStart(signal);
  PandoraMarkSideTriggered(direction);
  return true;
}

void PandoraDetectSignals()
{
  PandoraSyncRuntimeConfig();

  if(!PandoraStrategyEnabled())
    return;

  PandoraEnsureDayAnchor();
  PandoraEnsureWindowParsed();
  PandoraWindowCompleted();

  if(PandoraFinishedForDay())
    return;

  if(g_pandora_box_state.respect_session_filter && !SessionTimeFilterWindowIsOpen())
  {
    g_pandora_box_state.finished = true;
    return;
  }

  bool box_ready = PandoraComputeBoxWindow();
  if(!g_pandora_box_state.window_closed)
    return;

  if(!box_ready && g_pandora_box_state.box_computed)
    return;
  if(!box_ready)
    return;

  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int i = 0; i < 2; i++)
  {
    SignalTypes dir = directions[i];
    if(!PandoraDirectionAllowed(dir))
      continue;
    if(PandoraSideConsumed(dir))
      continue;
    if(!PandoraPriceTriggersSignal(dir))
      continue;
    if(!PandoraGuardsAllowAttempt(dir))
      continue;

    PandoraBuildSignal(dir);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_
