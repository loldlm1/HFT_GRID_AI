//+------------------------------------------------------------------+
//|                                      execution_controller       |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_

double ExecutionEntryPriceFromTick(const SignalTypes direction,
                                   const MqlTick &tick)
{
  if(direction == BULLISH)
    return tick.ask;
  if(direction == BEARISH)
    return tick.bid;
  return 0.0;
}

void PivotSignalTriggerTick(const PivotSignal &signal,
                            MqlTick &tick_out)
{
  ZeroMemory(tick_out);
  tick_out.time = signal.trigger_time;
  tick_out.bid = signal.trigger_bid;
  tick_out.ask = signal.trigger_ask;
}

bool LoadFreshExecutionTick(MqlTick &tick_out)
{
  ZeroMemory(tick_out);
  ResetLastError();
  return SymbolInfoTick(_Symbol, tick_out);
}

void AppendExecutionBlockReason(BrokerExecutionCheck &check,
                                const string source,
                                const string reason)
{
  if(reason == "")
    return;
  if(check.block_source == "")
  {
    ExecutionCheckBlock(check, source, reason);
    return;
  }
  check.block_reason += "|" + source + "=" + reason;
  check.allowed = false;
}

void BuildPivotV9AttemptPayload(const PivotSignal &signal,
                                PivotV9AttemptPayload &payload)
{
  payload.signal_id = signal.signal_id;
  payload.window_id = signal.window_id;
  payload.pivot_timeframe = signal.pivot_timeframe;
  payload.active_bar_open = signal.active_bar_open;
  payload.level_id = signal.level_id;
  payload.direction = signal.direction;
  payload.trigger_time = signal.trigger_time;
  payload.trigger_bid = signal.trigger_bid;
  payload.trigger_ask = signal.trigger_ask;
  payload.spread_points = signal.trigger_spread_points;
  payload.intended_entry_price = signal.route.intended_entry_price;
  payload.initial_stop_loss = signal.route.initial_stop_loss;
  payload.terminal_take_profit = signal.route.terminal_take_profit;
  payload.route_status = signal.route.status;
  payload.attempt_status = signal.attempt_status;
  payload.block_source = signal.block_source;
  payload.block_reason = signal.block_reason;
  payload.feature_snapshot_complete = signal.features.complete;
  payload.send_attempted = signal.execution.send_attempted;
}

void ExportPivotExecutionCheck(const PivotSignal &signal,
                               const BrokerExecutionCheck &check)
{
  if(!PivotV9Enabled())
    return;
  PivotV9ExecutionPayload payload;
  payload.signal_id = signal.signal_id;
  payload.window_id = signal.window_id;
  payload.check.CopyFrom(check);
  payload.position_ticket = signal.execution.position_ticket;
  payload.position_identifier = signal.execution.position_identifier;
  payload.broker_entry_confirmed = signal.execution.broker_entry_confirmed;
  payload.broker_close_confirmed = signal.execution.broker_close_confirmed;
  payload.broker_entry_price = signal.execution.broker_entry_price;
  payload.broker_volume = signal.execution.broker_volume;
  payload.broker_stop_loss = signal.execution.broker_stop_loss;
  payload.broker_take_profit = signal.execution.broker_take_profit;
  payload.close_price = signal.execution.close_price;
  payload.closed_volume = signal.execution.closed_volume;
  payload.realized_profit = signal.execution.realized_profit;
  payload.terminal_reason = signal.execution.terminal_reason;
  PivotV9RecordExecutionCheck(payload);
}

void ExportPivotAttempt(PivotSignal &signal)
{
  if(signal.attempt_exported || !PivotV9Enabled())
    return;
  PivotV9AttemptPayload payload;
  BuildPivotV9AttemptPayload(signal, payload);
  PivotV9RecordAttempt(payload);
  signal.attempt_exported = true;
}

void ExportPivotFeatures(const PivotSignal &signal)
{
  if(!PivotV9Enabled())
    return;
  PivotV9AttemptPayload payload;
  BuildPivotV9AttemptPayload(signal, payload);
  PivotV9RecordFeatures(payload, signal.features);
}

void ApplyFailedEligibilityDebugSideEffect(const BrokerExecutionCheck &check)
{
  if(Debug_Stop_On_Negative_Equity && check.block_source == "margin")
    g_debug_no_money_abort_pending = true;
}

bool CapturePivotEligibility(PivotSignal &signal,
                             const string phase,
                             const MqlTick &tick,
                             const datetime broker_time,
                             const bool require_order_check,
                             BrokerExecutionCheck &check_out)
{
  double entry_price = ExecutionEntryPriceFromTick(signal.direction, tick);
  double requested_volume = 0.0;
  double normalized_volume = 0.0;
  double risk_target_amount = 0.0;
  double expected_stop_loss = 0.0;
  string volume_reason = "";
  bool volume_ok = ResolveExecutionVolumePlan(signal.direction,
                                              entry_price,
                                              signal.route.initial_stop_loss,
                                              requested_volume,
                                              normalized_volume,
                                              risk_target_amount,
                                              expected_stop_loss,
                                              volume_reason);

  CaptureBrokerExecutionCheck(signal.direction,
                              phase,
                              NextBrokerExecutionCheckSequence(signal),
                              broker_time,
                              tick,
                              entry_price,
                              signal.route.initial_stop_loss,
                              signal.route.terminal_take_profit,
                              requested_volume,
                              normalized_volume,
                              require_order_check,
                              check_out);
  if(!volume_ok)
    AppendExecutionBlockReason(check_out, "lot_plan", volume_reason);

  signal.execution.planned_entry_price = entry_price;
  signal.execution.stop_loss_price = signal.route.initial_stop_loss;
  signal.execution.take_profit_price = signal.route.terminal_take_profit;
  signal.execution.risk_distance = MathAbs(entry_price - signal.route.initial_stop_loss);
  signal.execution.requested_volume = requested_volume;
  signal.execution.normalized_volume = normalized_volume;
  signal.execution.risk_target_amount = risk_target_amount;
  signal.execution.expected_stop_loss = expected_stop_loss;
  signal.execution.last_action_time = broker_time;
  return check_out.allowed;
}

void ApplyPivotAttemptBlock(PivotSignal &signal,
                            const string source,
                            const string reason)
{
  signal.admission_status = EXECUTION_ADMISSION_BLOCKED;
  signal.attempt_status = "DENIED";
  signal.block_source = source;
  signal.block_reason = reason;
  signal.execution.state = EXECUTION_ORDER_CANCELED;
  signal.execution.terminal_reason = source + ":" + reason;
}

bool PivotSendRetcodeAccepted(const ulong retcode)
{
  return retcode == TRADE_RETCODE_DONE ||
         retcode == TRADE_RETCODE_PLACED ||
         retcode == TRADE_RETCODE_DONE_PARTIAL;
}

bool SendPivotMarketOrder(PivotSignal &signal)
{
  MqlTick pre_send_tick;
  bool tick_loaded = LoadFreshExecutionTick(pre_send_tick);
  datetime broker_time = tick_loaded && pre_send_tick.time > 0
                         ? pre_send_tick.time
                         : TimeCurrent();
  if(!tick_loaded)
    ZeroMemory(pre_send_tick);

  CapturePivotEligibility(signal,
                          "PRE_SEND",
                          pre_send_tick,
                          broker_time,
                          true,
                          signal.execution.pre_send_check);
  ExportPivotExecutionCheck(signal, signal.execution.pre_send_check);
  if(!signal.execution.pre_send_check.allowed)
  {
    ApplyFailedEligibilityDebugSideEffect(signal.execution.pre_send_check);
    ApplyPivotAttemptBlock(signal,
                           signal.execution.pre_send_check.block_source,
                           signal.execution.pre_send_check.block_reason);
    return false;
  }

  MqlTradeRequest request;
  MqlTradeResult result;
  ZeroMemory(request);
  ZeroMemory(result);
  request.action = TRADE_ACTION_DEAL;
  request.symbol = _Symbol;
  request.magic = g_execution_magic;
  request.volume = signal.execution.pre_send_check.normalized_volume;
  request.price = signal.execution.pre_send_check.planned_entry_price;
  request.sl = signal.route.initial_stop_loss;
  request.tp = signal.route.terminal_take_profit;
  request.type = ExecutionOrderType(signal.direction);
  request.type_filling = ResolveExecutionFillingMode(_Symbol);
  request.type_time = ORDER_TIME_GTC;
  request.comment = PivotPositionComment(signal);

  signal.execution.send_attempted = true;
  signal.execution.state = EXECUTION_ORDER_SEND_ATTEMPTED;
  signal.execution.position_comment = request.comment;
  signal.execution.last_action_time = broker_time;

  ResetLastError();
  bool api_result = OrderSend(request, result);
  int send_error = GetLastError();
  BrokerExecutionCheck send_check(signal.execution.pre_send_check);
  send_check.phase = "SEND_RESULT";
  send_check.sequence = NextBrokerExecutionCheckSequence(signal);
  send_check.broker_time = TimeCurrent();
  send_check.send_retcode = result.retcode;
  send_check.send_comment = result.comment;
  send_check.order_ticket = result.order;
  send_check.deal_ticket = result.deal;
  bool accepted = api_result && PivotSendRetcodeAccepted(result.retcode);
  send_check.allowed = accepted;
  if(!accepted)
  {
    send_check.block_source = "";
    send_check.block_reason = "";
    ExecutionCheckBlock(send_check,
                        "order_send",
                        StringFormat("api=%s|retcode=%I64u|error=%d|comment=%s",
                                     api_result ? "true" : "false",
                                     result.retcode,
                                     send_error,
                                     result.comment));
  }

  signal.execution.send_result_check.CopyFrom(send_check);
  signal.execution.order_ticket = result.order;
  signal.execution.entry_deal_ticket = result.deal;
  signal.execution.position_ticket = result.order;
  if(!accepted)
  {
    signal.execution.state = EXECUTION_ORDER_FAILED;
    signal.execution.terminal_reason = send_check.block_reason;
    signal.admission_status = EXECUTION_ADMISSION_SEND_FAILED;
    signal.attempt_status = "SEND_FAILED";
    signal.block_source = send_check.block_source;
    signal.block_reason = send_check.block_reason;
    ExportPivotExecutionCheck(signal, send_check);
    ExecutionLogPivotSendResult(signal, send_check);
    MarketStatusRegisterBrokerFailure("PIVOT_SEND_FAILED",
                                      result.retcode,
                                      send_error);
    return false;
  }

  signal.admission_status = EXECUTION_ADMISSION_SENT;
  signal.attempt_status = "SENT";
  signal.block_source = "";
  signal.block_reason = "";
  ReconcilePivotSignalBrokerPosition(signal);
  ExportPivotExecutionCheck(signal, send_check);
  ExecutionLogPivotSendResult(signal, send_check);
  return true;
}

bool ProcessPivotSignalAttempt(PivotSignal &signal)
{
  if(PivotV9Enabled())
    ExportPivotFeatures(signal);

  BuildPivotSignalRoute(_Symbol,
                        signal.direction,
                        signal.level_id,
                        signal.levels,
                        signal.route);

  string permission_source = "";
  string permission_reason = "";
  bool permission_allowed = ResolvePivotSignalPermission(signal.direction,
                                                         permission_source,
                                                         permission_reason);

  MqlTick observation_tick;
  PivotSignalTriggerTick(signal, observation_tick);
  CapturePivotEligibility(signal,
                          "ATTEMPT_OBSERVED",
                          observation_tick,
                          signal.trigger_time,
                          false,
                          signal.execution.observation_check);

  if(signal.route.status != PIVOT_ROUTE_ALLOWED)
  {
    AppendExecutionBlockReason(signal.execution.observation_check,
                               "route",
                               signal.route.denial_reason);
    ApplyPivotAttemptBlock(signal, "route", signal.route.denial_reason);
  }
  else if(!permission_allowed)
  {
    AppendExecutionBlockReason(signal.execution.observation_check,
                               permission_source,
                               permission_reason);
    ApplyPivotAttemptBlock(signal, permission_source, permission_reason);
  }
  else if(!signal.execution.observation_check.allowed)
  {
    ApplyFailedEligibilityDebugSideEffect(signal.execution.observation_check);
    ApplyPivotAttemptBlock(signal,
                           signal.execution.observation_check.block_source,
                           signal.execution.observation_check.block_reason);
  }
  else
  {
    signal.admission_status = EXECUTION_ADMISSION_CANDIDATE;
  }

  ExportPivotExecutionCheck(signal, signal.execution.observation_check);
  if(signal.admission_status == EXECUTION_ADMISSION_BLOCKED)
  {
    ExportPivotAttempt(signal);
    ExecutionLogPivotAttempt(signal);
    return false;
  }

  if(!PivotSignalStore(signal))
  {
    ApplyPivotAttemptBlock(signal,
                           "signal_state",
                           "ACTIVE_SIGNAL_STORAGE_FAILED");
    ExportPivotAttempt(signal);
    ExecutionLogPivotAttempt(signal);
    return false;
  }

  int signal_index = FindPivotSignalIndex(signal.signal_id);
  if(signal_index < 0)
  {
    ApplyPivotAttemptBlock(signal,
                           "signal_state",
                           "ACTIVE_SIGNAL_LOOKUP_FAILED");
    ExportPivotAttempt(signal);
    ExecutionLogPivotAttempt(signal);
    return false;
  }

  bool sent = SendPivotMarketOrder(g_pivot_signals[signal_index]);
  ExportPivotAttempt(g_pivot_signals[signal_index]);
  ExecutionLogPivotAttempt(g_pivot_signals[signal_index]);
  if(!sent)
    PivotSignalRemoveAt(signal_index);
  return sent;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
