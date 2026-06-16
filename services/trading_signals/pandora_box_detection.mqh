//+------------------------------------------------------------------+
//|                      pandora_box_detection.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_

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

  double offset_points = PandoraResolveConfiguredOffsetPoints(true);
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

bool PandoraWickPriceTriggersSignal(const SignalTypes direction)
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

bool PandoraBodyCloseTriggersSignal(const SignalTypes direction)
{
  double trigger_price = (direction == BULLISH)
                           ? g_pandora_box_state.breakout_high_price
                           : g_pandora_box_state.breakout_low_price;
  if(trigger_price <= 0.0)
    return false;

  ENUM_TIMEFRAMES tf = g_pandora_box_state.entry_body_timeframe;
  if(!PandoraEntryBodyTimeframeSupported(tf))
    tf = PandoraResolveEntryBodyTimeframe();

  datetime close_bar_time = iTime(_Symbol, tf, 1);
  if(close_bar_time <= 0)
    return false;

  if(PandoraBodyCandleAlreadyProcessed(direction, close_bar_time))
    return false;

  double close_price = iClose(_Symbol, tf, 1);
  if(close_price <= 0.0)
    return false;

  bool triggered = (direction == BULLISH)
                     ? (close_price >= trigger_price)
                     : (close_price <= trigger_price);
  if(!triggered)
    return false;

  PandoraMarkBodyCandleProcessed(direction, close_bar_time, close_price);

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_BODY_TRIGGER dir=%s body_tf=%s bar=%s body_close=%.5f trigger=%.5f",
                EnumToString(direction),
                PandoraEntryBodyTimeframeLabel(),
                TimeToString(close_bar_time, TIME_DATE | TIME_MINUTES),
                close_price,
                trigger_price);
  }

  return true;
}

bool PandoraEntryTriggersSignal(const SignalTypes direction)
{
  if(PandoraBodyEntryMode())
    return PandoraBodyCloseTriggersSignal(direction);
  return PandoraWickPriceTriggersSignal(direction);
}

bool PandoraBuildSignal(const SignalTypes direction)
{
  SignalParams signal;
  signal.signal_type            = direction;
  signal.entry_time             = TimeCurrent();
  signal.strategy_context       = CONTEXT_SLOT_BASE;
  signal.strategy_timeframe     = Strategy_Timeframe;
  signal.strategy_context_label = "PANDORA";
  signal.entry_trigger_mode     = ENTRY_EVAL_OFF;
  signal.entry_evaluation_mode  = ENTRY_EVAL_OFF;
  signal.pandora_first_entry_mode = g_pandora_box_state.first_entry_mode;
  signal.pandora_first_entry_target_depth = g_pandora_box_state.first_entry_target_depth;
  signal.pandora_first_entry_observation_depth = 0;

  if(!BuildPandoraOrderForSignal(signal))
  {
    if(Enable_Logs)
      Print("Pandora grid planning failed for direction: ", EnumToString(direction));
    return false;
  }

  double theoretical_entry = signal.grid_entry_reference_price;
  if(theoretical_entry <= 0.0 && ArraySize(signal.grid_orders) > 0)
    theoretical_entry = signal.grid_orders[0].entry_reference_price;
  if(theoretical_entry <= 0.0)
    theoretical_entry = GridCurrentPriceForDirection(direction, true);

  signal.entry_price = theoretical_entry;
  signal.pandora_theoretical_entry_price = theoretical_entry;
  signal.pandora_theoretical_entry_time = signal.entry_time;
  signal.pandora_execution_source = PANDORA_EXECUTION_SOURCE_THEORETICAL;
  signal.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_PENDING;
  signal.pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
  signal.pandora_broker_stop_sync_status = Pandora_Box_Set_Broker_SLTP
                                           ? PANDORA_BROKER_STOPS_PENDING
                                           : PANDORA_BROKER_STOPS_NOT_REQUIRED;

  if(PandoraFirstEntryModeIsDeep(signal.pandora_first_entry_mode))
  {
    if(ArraySize(signal.grid_orders) > 0)
      signal.grid_orders[0].status = GRID_ORDER_WAITING;
    signal.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_NONE;
    signal.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
    if(!PandoraSetFirstEntryObservationTargets(signal,
                                               theoretical_entry,
                                               0))
    {
      if(Enable_Logs)
        Print("Pandora first-entry observation setup failed for direction: ", EnumToString(direction));
      return false;
    }

    if(Enable_Logs)
    {
      PrintFormat("PANDORA_FIRST_ENTRY_OBSERVE dir=%s mode=%s anchor=%.5f trigger=%.5f tp=%.5f",
                  EnumToString(direction),
                  PandoraFirstEntryModeLabel(signal.pandora_first_entry_mode),
                  signal.pandora_observation_anchor_price,
                  signal.pandora_observation_trigger_price,
                  signal.pandora_observation_tp_price);
    }
  }

  if(!PandoraFirstEntryModeIsDeep(signal.pandora_first_entry_mode))
  {
    RegisterDailySignalStart(signal);
    PandoraRegisterEntryTriggered(direction);
    signal.pandora_first_entry_budget_registered = true;
  }

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, signal);
  else
    AddElementToArray(running_bearish_signals, signal);
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

  if(g_pandora_box_state.respect_session_filter)
  {
    bool session_open = SessionTimeFilterWindowIsOpen();
    if(session_open)
      g_pandora_box_state.session_window_seen_active = true;
    else if(g_pandora_box_state.session_window_seen_active)
    {
      g_pandora_box_state.finished = true;
      return;
    }
  }

  if(!PandoraRuntimeRequiresFullTick())
    return;

  bool box_ready = PandoraComputeBoxWindow();
  if(!g_pandora_box_state.window_closed)
    return;

  if(!box_ready && g_pandora_box_state.box_computed)
    return;
  if(!box_ready)
    return;

  PandoraRefreshRearmState();

  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int i = 0; i < 2; i++)
  {
    if(PandoraEntryBudgetReached())
    {
      break;
    }

    SignalTypes dir = directions[i];
    if(!PandoraDirectionAllowed(dir))
      continue;
    if(!PandoraDirectionReadyForEntry(dir))
      continue;
    if(!PandoraEntryTriggersSignal(dir))
      continue;
    if(!PandoraGuardsAllowAttempt(dir))
      continue;

    PandoraBuildSignal(dir);
  }
}

bool BuildPandoraOrderForSignal(SignalParams &signal_params)
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  double base_points = PandoraResolveConfiguredSLPoints(true);
  if(base_points <= 0.0)
    return false;

  bool step_trailing = PandoraRiskStepTrailingEnabled();
  double dir_mult = (signal_params.signal_type == BULLISH) ? 1.0 : -1.0;
  double entry_reference = (signal_params.signal_type == BULLISH)
                             ? g_pandora_box_state.breakout_high_price
                             : g_pandora_box_state.breakout_low_price;
  if(entry_reference <= 0.0)
    entry_reference = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(entry_reference <= 0.0)
    return false;

  double tp_points = PandoraResolveConfiguredTPPoints(true);
  double tp_price = (tp_points > 0.0) ? entry_reference + dir_mult * tp_points * point_size : 0.0;
  if(step_trailing)
    tp_price = 0.0;

  signal_params.lot_size                         = 0.0; // resolved after seeding the order
  signal_params.grid_base_lot_size               = 0.0;
  signal_params.grid_base_distance_points        = base_points;
  signal_params.grid_entry_reference_price       = entry_reference;
  signal_params.grid_entry_gap_points            = base_points;
  signal_params.grid_entry_offset_points         = 0.0;
  signal_params.grid_initial_indicator_distance_points = base_points;
  signal_params.grid_resolved_distance_points    = 0.0;
  signal_params.grid_trailing_points             = 0.0;
  signal_params.pandora_sl_points                = base_points;
  signal_params.pandora_tp_points                = tp_points;
  signal_params.pandora_trailing_step_points     = step_trailing ? base_points : 0.0;
  signal_params.pandora_trailing_step_index      = 0;
  signal_params.pandora_trailing_stop_price      = 0.0;

  GridOrderState state;
  state.level_index             = 0;
  state.status                  = GRID_ORDER_STOP_TRAILING_ACTIVE;
  state.entry_style             = GRID_ENTRY_STYLE_STOP;
  state.entry_reference_price   = entry_reference;
  state.take_profit_price       = tp_price;
  state.final_take_profit_price = 0.0;
  state.trailing_price          = 0.0;
  state.next_level_price        = 0.0;
  state.opens_position          = true;
  state.lot_size                = 0.0;
  state.position_ticket         = 0;

  ArrayResize(signal_params.grid_orders, 1);
  signal_params.grid_orders[0] = state;

  // Resolve lot size using the standard lot logic (respects Pandora_Lot_Type).
  double resolved_lot = ResolveGridOrderLotSize(signal_params, 0);
  if(resolved_lot <= 0.0)
    resolved_lot = ResolveBaseGridLot(base_points);
  if(resolved_lot <= 0.0)
    resolved_lot = NormalizeVolumeForSymbol(_Symbol, Pandora_Lot_Strategy_Size);

  signal_params.lot_size           = resolved_lot;
  signal_params.grid_base_lot_size = resolved_lot;
  signal_params.grid_orders[0].lot_size = resolved_lot;

  signal_params.grid_initialized = true;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_BOX_DETECTION_MQH_
