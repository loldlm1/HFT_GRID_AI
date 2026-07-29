//+------------------------------------------------------------------+
//|                                      execution_controller.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_

const int EXECUTION_PRE_SEND_RETRY_SECONDS = 1;

double CurrentExecutionEntryPrice(const SignalTypes direction)
{
  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick))
    return 0.0;
  if(direction == BULLISH)
    return tick.ask;
  if(direction == BEARISH)
    return tick.bid;
  return 0.0;
}

bool ExecutionBreakoutReached(const SignalParams &signal_params)
{
  double trigger_price = signal_params.execution.planned_entry_price;
  if(trigger_price <= 0.0)
    return false;

  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick))
    return false;
  if(signal_params.signal_type == BULLISH)
    return (tick.ask >= trigger_price);
  if(signal_params.signal_type == BEARISH)
    return (tick.bid <= trigger_price);
  return false;
}

void ApplyExecutionCheckToAdmission(SignalParams &signal_params,
                                    const BrokerExecutionCheck &check,
                                    const bool final_decision)
{
  signal_params.admission_spread_points = check.spread_points;
  signal_params.admission_market_status =
    MarketStatusFromSymbolTradeMode(check.symbol_trade_mode);
  signal_params.admission_updated_time = check.broker_time;
  if(!final_decision)
    return;

  signal_params.admission_status = check.allowed
    ? EXECUTION_ADMISSION_ALLOWED
    : EXECUTION_ADMISSION_BLOCKED;
  signal_params.admission_block_source = check.block_source;
  signal_params.admission_block_reason = check.block_reason;
}

bool BuildExecutionOrderForSignal(SignalParams &signal_params)
{
  double planned_entry = signal_params.raw_entry_trigger_price;
  double stop_loss = signal_params.raw_stop_anchor_price;
  double take_profit = ResolveExecutionOneRTarget(signal_params.signal_type,
                                                  planned_entry,
                                                  stop_loss);
  if(take_profit <= 0.0)
  {
    signal_params.execution_risk_plan_reason = "invalid_structural_geometry";
    return false;
  }

  signal_params.execution = ExecutionState();
  signal_params.execution.state = EXECUTION_ORDER_WAITING;
  signal_params.execution.planned_entry_price = planned_entry;
  signal_params.execution.stop_loss_price = stop_loss;
  signal_params.execution.take_profit_price = take_profit;
  signal_params.execution.risk_distance = MathAbs(planned_entry - stop_loss);
  signal_params.execution.last_action_time = TimeCurrent();
  signal_params.execution_initialized = true;
  signal_params.stop_loss = stop_loss;
  signal_params.take_profit = take_profit;
  signal_params.raw_take_profit_price = take_profit;
  signal_params.raw_risk_distance = signal_params.execution.risk_distance;

  double observation_entry = CurrentExecutionEntryPrice(signal_params.signal_type);
  double observation_target = ResolveExecutionOneRTarget(signal_params.signal_type,
                                                          observation_entry,
                                                          stop_loss);
  double requested_volume = 0.0;
  double normalized_volume = 0.0;
  string volume_reason = "";
  ResolveExecutionVolumePlan(signal_params,
                             observation_entry,
                             stop_loss,
                             requested_volume,
                             normalized_volume,
                             volume_reason);
  signal_params.execution.requested_volume = requested_volume;
  signal_params.execution.normalized_volume = normalized_volume;

  CaptureBrokerExecutionCheck(signal_params,
                              "ATTEMPT_OBSERVED",
                              1,
                              observation_entry,
                              stop_loss,
                              observation_target,
                              requested_volume,
                              normalized_volume,
                              false,
                              signal_params.execution.observation_check);
  if(volume_reason != "" &&
     signal_params.execution.observation_check.block_source == "")
  {
    ExecutionCheckBlock(signal_params.execution.observation_check,
                        "lot_plan",
                        volume_reason);
  }
  else if(volume_reason != "")
  {
    signal_params.execution.observation_check.block_reason +=
      "|lot_plan=" + volume_reason;
  }
  ApplyExecutionCheckToAdmission(signal_params,
                                 signal_params.execution.observation_check,
                                 false);
  return true;
}

bool ExecutionFilterAllowsSend(SignalParams &signal_params,
                               string &block_source_out,
                               string &block_reason_out)
{
  block_source_out = "";
  block_reason_out = "";

  DeterministicSignalMLShadowRecordPrediction(signal_params, signal_params.execution);

  if(!PatternAuditSelectedAdmissionAllowsEntry(signal_params,
                                               signal_params.execution,
                                               block_reason_out))
  {
    block_source_out = "pattern_audit";
    return false;
  }

  if(!DeterministicSignalMLFilterAllowsEntry(signal_params,
                                             signal_params.execution,
                                             block_reason_out))
  {
    block_source_out = "ml_filter";
    return false;
  }
  return true;
}

bool CaptureCurrentSendEligibility(SignalParams &signal_params,
                                   const string phase,
                                   const int sequence,
                                   BrokerExecutionCheck &check_out)
{
  double entry_price = CurrentExecutionEntryPrice(signal_params.signal_type);
  double stop_loss = signal_params.execution.stop_loss_price;
  double take_profit = ResolveExecutionOneRTarget(signal_params.signal_type,
                                                  entry_price,
                                                  stop_loss);
  double requested_volume = 0.0;
  double normalized_volume = 0.0;
  string volume_reason = "";
  bool volume_ok = ResolveExecutionVolumePlan(signal_params,
                                              entry_price,
                                              stop_loss,
                                              requested_volume,
                                              normalized_volume,
                                              volume_reason);

  CaptureBrokerExecutionCheck(signal_params,
                              phase,
                              sequence,
                              entry_price,
                              stop_loss,
                              take_profit,
                              requested_volume,
                              normalized_volume,
                              true,
                              check_out);
  if(!volume_ok && check_out.block_source == "")
    ExecutionCheckBlock(check_out, "lot_plan", volume_reason);
  else if(!volume_ok && volume_reason != "")
    check_out.block_reason += "|lot_plan=" + volume_reason;
  return check_out.allowed;
}

void ApplyFailedEligibilityDebugSideEffect(const BrokerExecutionCheck &check)
{
  if(Debug_Stop_On_Negative_Equity && check.block_source == "margin")
    g_debug_no_money_abort_pending = true;
}

bool SendExecutionOrderAfterPrecheck(SignalParams &signal_params)
{
  CaptureCurrentSendEligibility(signal_params,
                                "PRE_FILTER",
                                2,
                                signal_params.execution.filter_gate_check);
  ApplyExecutionCheckToAdmission(signal_params,
                                 signal_params.execution.filter_gate_check,
                                 true);
  signal_params.execution.last_action_time = TimeCurrent();
  if(!signal_params.execution.filter_gate_check.allowed)
  {
    ApplyFailedEligibilityDebugSideEffect(signal_params.execution.filter_gate_check);
    return false;
  }

  string filter_source = "";
  string filter_reason = "";
  if(!ExecutionFilterAllowsSend(signal_params, filter_source, filter_reason))
  {
    signal_params.admission_status = EXECUTION_ADMISSION_BLOCKED;
    signal_params.admission_block_source = filter_source;
    signal_params.admission_block_reason = filter_reason;
    signal_params.admission_updated_time = TimeCurrent();
    signal_params.execution.state = EXECUTION_ORDER_CANCELED;
    signal_params.execution.terminal_reason = filter_source + ":" + filter_reason;
    DeterministicSignalStatsRecordAdmissionEvent(signal_params, "filter_blocked");
    return false;
  }

  CaptureCurrentSendEligibility(signal_params,
                                "PRE_SEND",
                                3,
                                signal_params.execution.pre_send_check);
  ApplyExecutionCheckToAdmission(signal_params,
                                 signal_params.execution.pre_send_check,
                                 true);
  signal_params.execution.last_action_time = TimeCurrent();
  if(!signal_params.execution.pre_send_check.allowed)
  {
    ApplyFailedEligibilityDebugSideEffect(signal_params.execution.pre_send_check);
    return false;
  }

  double entry_price = signal_params.execution.pre_send_check.planned_entry_price;
  double stop_loss = signal_params.execution.pre_send_check.stop_loss_price;
  double take_profit = signal_params.execution.pre_send_check.take_profit_price;
  double requested_volume = signal_params.execution.pre_send_check.requested_volume;
  double normalized_volume = signal_params.execution.pre_send_check.normalized_volume;

  MqlTradeRequest request;
  MqlTradeResult result;
  ZeroMemory(request);
  ZeroMemory(result);
  request.action = TRADE_ACTION_DEAL;
  request.symbol = _Symbol;
  request.magic = g_execution_magic;
  request.volume = normalized_volume;
  request.price = entry_price;
  request.sl = stop_loss;
  request.tp = take_profit;
  request.type = ExecutionOrderType(signal_params.signal_type);
  request.type_filling = ResolveExecutionFillingMode(_Symbol);
  request.type_time = ORDER_TIME_GTC;
  request.comment = ExecutionPositionComment(signal_params);

  signal_params.execution.send_attempted = true;
  signal_params.execution.state = EXECUTION_ORDER_SEND_ATTEMPTED;
  signal_params.execution.requested_volume = requested_volume;
  signal_params.execution.normalized_volume = normalized_volume;
  signal_params.execution.take_profit_price = take_profit;
  signal_params.execution.last_action_time = TimeCurrent();

  bool api_result = OrderSend(request, result);
  BrokerExecutionCheck send_check = signal_params.execution.pre_send_check;
  send_check.phase = "SEND_RESULT";
  send_check.sequence = 4;
  send_check.broker_time = TimeCurrent();
  send_check.send_retcode = result.retcode;
  send_check.send_comment = result.comment;
  send_check.order_ticket = result.order;
  send_check.deal_ticket = result.deal;
  bool accepted = api_result &&
                  (result.retcode == TRADE_RETCODE_DONE ||
                   result.retcode == TRADE_RETCODE_PLACED ||
                   result.retcode == TRADE_RETCODE_DONE_PARTIAL);
  send_check.allowed = accepted;
  if(!accepted)
  {
    ExecutionCheckBlock(send_check,
                        "order_send",
                        StringFormat("api=%s|retcode=%I64u|error=%d|comment=%s",
                                     api_result ? "true" : "false",
                                     result.retcode,
                                     GetLastError(),
                                     result.comment));
  }
  signal_params.execution.send_result_check = send_check;
  signal_params.execution.order_ticket = result.order;
  signal_params.execution.deal_ticket = result.deal;
  signal_params.admission_updated_time = send_check.broker_time;

  if(!accepted)
  {
    signal_params.execution.state = EXECUTION_ORDER_FAILED;
    signal_params.execution.terminal_reason = send_check.block_reason;
    signal_params.admission_status = EXECUTION_ADMISSION_SEND_FAILED;
    signal_params.admission_block_source = send_check.block_source;
    signal_params.admission_block_reason = send_check.block_reason;
    DeterministicSignalStatsRecordAdmissionEvent(signal_params, "broker_send_failed");
    MarketStatusRegisterBrokerFailure("BROKER_SEND_FAILED",
                                      result.retcode,
                                      GetLastError());
    return false;
  }

  signal_params.admission_status = EXECUTION_ADMISSION_SENT;
  signal_params.admission_block_source = "";
  signal_params.admission_block_reason = "";
  PatternAuditPlaybackRecordSignal(signal_params, signal_params.execution);
  DeterministicSignalStatsRecordAdmissionEvent(signal_params, "broker_send_accepted");
  ReconcileSignalBrokerPosition(signal_params);
  return true;
}

void UpdateExecutionLifecycle(SignalParams &signal_params)
{
  ReconcileSignalBrokerPosition(signal_params);
  if(signal_params.execution.state == EXECUTION_ORDER_BROKER_ACTIVE &&
     !signal_params.deterministic_stats_feature_exported)
  {
    DeterministicSignalStatsRecordFeature(signal_params,
                                          signal_params.execution);
  }
  if(signal_params.execution.state == EXECUTION_ORDER_BROKER_ACTIVE ||
     signal_params.execution.state == EXECUTION_ORDER_BROKER_CLOSED ||
     signal_params.execution.state == EXECUTION_ORDER_CANCELED ||
     signal_params.execution.state == EXECUTION_ORDER_FAILED)
    return;

  if(signal_params.execution.state == EXECUTION_ORDER_SEND_ATTEMPTED)
    return;
  if(!ExecutionBreakoutReached(signal_params))
    return;
  if(TimeCurrent() - signal_params.execution.last_action_time <
     EXECUTION_PRE_SEND_RETRY_SECONDS)
    return;

  SendExecutionOrderAfterPrecheck(signal_params);
}

bool IsExecutionSignalComplete(const SignalParams &signal_params)
{
  return (signal_params.execution.state == EXECUTION_ORDER_BROKER_CLOSED ||
          signal_params.execution.state == EXECUTION_ORDER_CANCELED ||
          signal_params.execution.state == EXECUTION_ORDER_FAILED);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
