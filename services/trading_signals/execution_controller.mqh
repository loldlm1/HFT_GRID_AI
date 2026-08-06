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

bool BuildExecutionOneRGeometry(const string symbol,
                                const SignalTypes direction,
                                const MqlTick &tick,
                                const double structural_stop_loss,
                                double &entry_price_out,
                                double &take_profit_out,
                                string &reason_out)
{
  entry_price_out = 0.0;
  take_profit_out = 0.0;
  reason_out = "";
  if(symbol == "" ||
     (direction != BULLISH && direction != BEARISH) ||
     tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid ||
     structural_stop_loss <= 0.0)
  {
    reason_out = "QUOTE_OR_STRUCTURAL_STOP_INVALID";
    return false;
  }

  entry_price_out = ExecutionEntryPriceFromTick(direction, tick);
  double risk_distance = direction == BULLISH
                         ? entry_price_out - structural_stop_loss
                         : structural_stop_loss - entry_price_out;
  if(risk_distance <= 0.0 || !MathIsValidNumber(risk_distance))
  {
    reason_out = "STRUCTURAL_STOP_WRONG_SIDE_OF_FRESH_ENTRY";
    return false;
  }

  double raw_take_profit = direction == BULLISH
                           ? entry_price_out + risk_distance
                           : entry_price_out - risk_distance;
  if(!NormalizePivotTradePrice(symbol,
                               raw_take_profit,
                               take_profit_out))
  {
    reason_out = "ONE_R_TAKE_PROFIT_NORMALIZATION_FAILED";
    return false;
  }

  double point_size = 0.0;
  if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point_size) || point_size <= 0.0)
  {
    reason_out = "POINT_SIZE_UNAVAILABLE";
    return false;
  }
  double risk_points =
    ExecutionPriceDistancePoints(entry_price_out,
                                 structural_stop_loss,
                                 point_size);
  double reward_points =
    ExecutionPriceDistancePoints(entry_price_out,
                                 take_profit_out,
                                 point_size);
  double ratio = risk_points > 0.0 ? reward_points / risk_points : 0.0;
  if(!ExecutionPriceDistanceOneRValid(risk_points, reward_points, ratio))
  {
    reason_out = "NORMALIZED_TAKE_PROFIT_NOT_EXACT_PRICE_DISTANCE_ONE_R";
    return false;
  }
  return true;
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

bool ExportPivotExecutionCheck(PivotSignal &signal,
                               const BrokerExecutionCheck &check)
{
  if(!PivotV10Enabled())
    return true;
  bool recorded = PivotV10RecordExecutionCheck(signal, check);
  if(recorded && check.phase != "TERMINAL" &&
     signal.execution.broker_entry_confirmed)
    signal.execution.entry_check_exported = true;
  return recorded;
}

void ExportPivotAttempt(PivotSignal &signal)
{
  if(signal.attempt_exported)
    return;
  if(!PivotV10Enabled())
  {
    signal.attempt_exported = true;
    return;
  }
  if(PivotV10RecordAttempt(signal))
    signal.attempt_exported = true;
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
  double entry_price = 0.0;
  double take_profit_price = 0.0;
  string geometry_reason = "";
  bool geometry_ok = BuildExecutionOneRGeometry(_Symbol,
                                                signal.direction,
                                                tick,
                                                signal.route.structural_stop_loss,
                                                entry_price,
                                                take_profit_price,
                                                geometry_reason);
  double requested_volume = 0.0;
  double normalized_volume = 0.0;
  double risk_budget_amount = 0.0;
  double quote_expected_stop_loss = 0.0;
  double quote_expected_take_profit = 0.0;
  double quote_expected_ratio = 0.0;
  double risk_budget_utilization = 0.0;
  string volume_reason = "";
  bool volume_ok = geometry_ok &&
                   ResolveExecutionVolumePlan(signal.direction,
                                              entry_price,
                                              signal.route.structural_stop_loss,
                                              take_profit_price,
                                              requested_volume,
                                              normalized_volume,
                                              risk_budget_amount,
                                              quote_expected_stop_loss,
                                              quote_expected_take_profit,
                                              quote_expected_ratio,
                                              risk_budget_utilization,
                                              volume_reason);

  CaptureBrokerExecutionCheck(signal.direction,
                              phase,
                              NextBrokerExecutionCheckSequence(signal),
                              broker_time,
                              tick,
                              entry_price,
                              signal.route.structural_stop_loss,
                              take_profit_price,
                              requested_volume,
                              normalized_volume,
                              risk_budget_amount,
                              quote_expected_stop_loss,
                              quote_expected_take_profit,
                              quote_expected_ratio,
                              risk_budget_utilization,
                              require_order_check,
                              check_out);
  if(!geometry_ok)
    AppendExecutionBlockReason(check_out, "one_r_geometry", geometry_reason);
  if(!volume_ok)
  {
    if(volume_reason != "")
      AppendExecutionBlockReason(check_out, "lot_plan", volume_reason);
  }
  if(require_order_check && check_out.allowed)
    RunExecutionOrderCheck(check_out);

  signal.execution.planned_entry_price = check_out.planned_entry_price;
  signal.execution.stop_loss_price = check_out.stop_loss_price;
  signal.execution.take_profit_price = check_out.take_profit_price;
  signal.execution.risk_distance_points = check_out.risk_distance_points;
  signal.execution.reward_distance_points = check_out.reward_distance_points;
  signal.execution.price_reward_risk_ratio =
    check_out.price_reward_risk_ratio;
  signal.execution.requested_volume = check_out.requested_volume;
  signal.execution.normalized_volume = check_out.normalized_volume;
  signal.execution.risk_budget_amount = check_out.risk_budget_amount;
  signal.execution.quote_expected_stop_loss =
    check_out.quote_expected_stop_loss;
  signal.execution.quote_expected_take_profit =
    check_out.quote_expected_take_profit;
  signal.execution.quote_expected_reward_risk_ratio =
    check_out.quote_expected_reward_risk_ratio;
  signal.execution.risk_budget_utilization_ratio =
    check_out.risk_budget_utilization_ratio;
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
         retcode == TRADE_RETCODE_PLACED;
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
  request.sl = signal.execution.pre_send_check.stop_loss_price;
  request.tp = signal.execution.pre_send_check.take_profit_price;
  request.type = ExecutionOrderType(signal.direction);
  request.type_filling = ORDER_FILLING_FOK;
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
                          "OBSERVATION",
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
  ExecutionLogPivotAttempt(g_pivot_signals[signal_index]);
  if(!sent)
  {
    ExportPivotAttempt(g_pivot_signals[signal_index]);
    PivotSignalRemoveAt(signal_index);
  }
  return sent;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
