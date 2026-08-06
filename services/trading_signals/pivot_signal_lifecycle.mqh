//+------------------------------------------------------------------+
//|                 trading_signals/pivot_signal_lifecycle         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_

const int PIVOT_TRAILING_RETRY_SECONDS = 5;
const int PIVOT_TRAILING_CONFIRM_RETRY_SECONDS = 1;
const int PIVOT_TRAILING_MAX_RETRY_SECONDS = 60;
const int PIVOT_TRAILING_LOG_THROTTLE_SECONDS = 15;

struct PivotTrailingValidation
{
  bool allowed;
  bool retryable;
  string reason;
  MqlTick tick;
  datetime broker_time;
  double previous_stop;
  double take_profit;
  double point_size;
  double stops_distance_points;
  double freeze_distance_points;

  PivotTrailingValidation()
  {
    Reset();
  }

  void Reset()
  {
    allowed = false;
    retryable = false;
    reason = "";
    ZeroMemory(tick);
    broker_time = 0;
    previous_stop = 0.0;
    take_profit = 0.0;
    point_size = 0.0;
    stops_distance_points = 0.0;
    freeze_distance_points = 0.0;
  }
};

void InitializePivotBrokerOwnershipBoundary()
{
  int existing_positions = CountOwnedPivotPositions();
  g_pivot_startup_positions_block_entries = existing_positions > 0;
  if(!g_pivot_startup_positions_block_entries)
    return;

  string message = StringFormat("preexisting_positions=%d|action=entry_blocked_until_flat",
                                existing_positions);
  ExecutionAppendQueryDebugLog("PIVOT_STARTUP_OWNERSHIP", message);
  if(Enable_Logs)
    Print("PIVOT_STARTUP_OWNERSHIP | ", message);
}

void RefreshPivotBrokerOwnershipBoundary()
{
  if(!g_pivot_startup_positions_block_entries)
    return;
  int existing_positions = CountOwnedPivotPositions();
  if(existing_positions > 0)
    return;

  g_pivot_startup_positions_block_entries = false;
  ExecutionAppendQueryDebugLog("PIVOT_STARTUP_OWNERSHIP",
                              "preexisting_positions=0|action=entry_block_released");
  if(Enable_Logs)
    Print("PIVOT_STARTUP_OWNERSHIP | preexisting_positions=0|action=entry_block_released");
}

double PivotTrailingPriceTolerance()
{
  double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(tick_size <= 0.0)
    tick_size = point_size;
  if(tick_size <= 0.0)
    tick_size = 1e-8;
  return MathMax(tick_size * 0.5, 1e-10);
}

bool PivotTrailingStopAtLeast(const SignalTypes direction,
                              const double current_stop,
                              const double desired_stop)
{
  if(current_stop <= 0.0 || desired_stop <= 0.0)
    return false;
  double tolerance = PivotTrailingPriceTolerance();
  if(direction == BULLISH)
    return current_stop + tolerance >= desired_stop;
  if(direction == BEARISH)
    return current_stop - tolerance <= desired_stop;
  return false;
}

bool PivotTrailingStopStronger(const SignalTypes direction,
                               const double candidate_stop,
                               const double reference_stop)
{
  if(candidate_stop <= 0.0)
    return false;
  if(reference_stop <= 0.0)
    return true;
  double tolerance = PivotTrailingPriceTolerance();
  if(direction == BULLISH)
    return candidate_stop > reference_stop + tolerance;
  if(direction == BEARISH)
    return candidate_stop < reference_stop - tolerance;
  return false;
}

int PivotHighestReachedMilestone(const PivotSignal &signal,
                                 const MqlTick &tick)
{
  return -1;
}

bool PivotStrongestDesiredStop(const PivotSignal &signal,
                               const int highest_index,
                               int &milestone_index_out,
                               double &desired_stop_out)
{
  milestone_index_out = -1;
  desired_stop_out = 0.0;
  return false;
}

void PivotSetPendingStop(PivotSignal &signal,
                         const int milestone_index,
                         const double desired_stop)
{
  if(milestone_index < 0 || desired_stop <= 0.0)
    return;
  if(signal.execution.pending_stop_loss > 0.0 &&
     !PivotTrailingStopStronger(signal.direction,
                                desired_stop,
                                signal.execution.pending_stop_loss))
  {
    if(MathAbs(desired_stop - signal.execution.pending_stop_loss) <=
       PivotTrailingPriceTolerance() &&
       milestone_index > signal.execution.pending_milestone_index)
      signal.execution.pending_milestone_index = milestone_index;
    return;
  }

  signal.execution.pending_stop_loss = desired_stop;
  signal.execution.pending_milestone_index = milestone_index;
  signal.execution.trailing_retry_pending = true;
  signal.execution.trailing_confirmation_pending = false;
  signal.execution.trailing_retry_count = 0;
  signal.execution.next_trailing_retry_time = 0;
}

void PivotClearPendingStop(PivotSignal &signal)
{
  signal.execution.pending_stop_loss = 0.0;
  signal.execution.pending_milestone_index = -1;
  signal.execution.trailing_retry_pending = false;
  signal.execution.trailing_confirmation_pending = false;
  signal.execution.trailing_retry_count = 0;
  signal.execution.next_trailing_retry_time = 0;
}

void PivotScheduleTrailingRetry(PivotSignal &signal,
                                const bool confirmation_pending)
{
  signal.execution.trailing_retry_pending = true;
  signal.execution.trailing_confirmation_pending = confirmation_pending;
  int delay_seconds = PIVOT_TRAILING_CONFIRM_RETRY_SECONDS;
  if(!confirmation_pending)
  {
    signal.execution.trailing_retry_count++;
    delay_seconds = PIVOT_TRAILING_RETRY_SECONDS;
    for(int i = 1; i < signal.execution.trailing_retry_count; i++)
    {
      if(delay_seconds >= PIVOT_TRAILING_MAX_RETRY_SECONDS)
        break;
      delay_seconds *= 2;
    }
    if(delay_seconds > PIVOT_TRAILING_MAX_RETRY_SECONDS)
      delay_seconds = PIVOT_TRAILING_MAX_RETRY_SECONDS;
  }
  signal.execution.next_trailing_retry_time = TimeCurrent() + delay_seconds;
}

void PivotRecordTrailingEvent(PivotSignal &signal,
                              const int milestone_index,
                              const datetime event_time,
                              const double previous_stop,
                              const double desired_stop,
                              const double requested_stop,
                              const double confirmed_stop,
                              const bool request_performed,
                              const bool request_succeeded,
                              const ulong retcode,
                              const string comment,
                              const bool retry_pending,
                              const string event_status)
{
  if(signal.execution.position_ticket == 0 ||
     signal.execution.position_identifier == 0)
    return;

  signal.execution.trailing_event_sequence++;
  PivotV9TrailingPayload payload;
  payload.signal_id = signal.signal_id;
  payload.window_id = signal.window_id;
  payload.event_sequence = signal.execution.trailing_event_sequence;
  payload.event_time = event_time > 0 ? event_time : TimeCurrent();
  payload.direction = signal.direction;
  payload.position_ticket = signal.execution.position_ticket;
  payload.position_identifier = signal.execution.position_identifier;
  payload.milestone_level = signal.level_id;
  payload.milestone_price = signal.route.intended_entry_price;
  payload.previous_confirmed_stop = previous_stop;
  payload.desired_stop = desired_stop;
  payload.requested_stop = requested_stop;
  payload.confirmed_stop = confirmed_stop;
  payload.take_profit = signal.execution.broker_take_profit;
  payload.request_performed = request_performed;
  payload.request_succeeded = request_succeeded;
  payload.retcode = retcode;
  payload.comment = comment;
  payload.retry_pending = retry_pending;
  payload.event_status = event_status;
  if(PivotV9Enabled())
    PivotV9RecordTrailingEvent(payload);

  string message = StringFormat("signal_id=%s|ticket=%I64u|milestone=%s|previous_sl=%.10f|desired_sl=%.10f|requested_sl=%.10f|confirmed_sl=%.10f|request=%s|success=%s|retcode=%I64u|retry=%s|status=%s|comment=%s",
                                signal.signal_id,
                                signal.execution.position_ticket,
                                PivotLevelLabel(payload.milestone_level),
                                previous_stop,
                                desired_stop,
                                requested_stop,
                                confirmed_stop,
                                request_performed ? "true" : "false",
                                request_succeeded ? "true" : "false",
                                retcode,
                                retry_pending ? "true" : "false",
                                event_status,
                                comment);
  bool failure = StringFind(event_status, "BLOCKED") >= 0 ||
                 StringFind(event_status, "REJECTED") >= 0;
  string log_key = signal.signal_id + "|" +
                   DoubleToString(desired_stop, 10) + "|" +
                   IntegerToString((int)retcode);
  if(failure)
    ExecutionAppendQueryDebugThrottledLog("PIVOT_TRAILING",
                                         log_key,
                                         message,
                                         PIVOT_TRAILING_LOG_THROTTLE_SECONDS);
  else
    ExecutionAppendQueryDebugLog("PIVOT_TRAILING", message);
  if(Enable_Logs && (!failure || request_performed))
    Print("PIVOT_TRAILING | ", message);
}

bool PivotDesiredStopBelongsToRoute(const PivotSignal &signal,
                                    const int milestone_index,
                                    const double desired_stop)
{
  return false;
}

bool PreparePivotTrailingModification(PivotSignal &signal,
                                       const double desired_stop,
                                       PivotTrailingValidation &validation)
{
  validation.Reset();
  string ownership_reason = "";
  if(!SelectPivotPositionByOwnedTicket(signal, ownership_reason))
  {
    validation.reason = ownership_reason;
    validation.retryable = ownership_reason == "POSITION_TICKET_NOT_FOUND";
    return false;
  }
  ApplySelectedPivotPositionFacts(signal);
  validation.previous_stop = signal.execution.broker_stop_loss;
  validation.take_profit = signal.execution.broker_take_profit;

  if(!PivotDesiredStopBelongsToRoute(signal,
                                     signal.execution.pending_milestone_index,
                                     desired_stop))
  {
    validation.reason = "DESIRED_STOP_NOT_IN_CAPTURED_ROUTE";
    ActivatePivotOwnershipEntryBlock(validation.reason);
    return false;
  }
  if(PivotTrailingStopAtLeast(signal.direction,
                              validation.previous_stop,
                              desired_stop))
  {
    validation.reason = "DESIRED_STOP_ALREADY_PROTECTED";
    return false;
  }
  if(validation.previous_stop <= 0.0 || validation.take_profit <= 0.0)
  {
    validation.reason = "BROKER_PROTECTION_MISSING";
    ActivatePivotOwnershipEntryBlock(validation.reason);
    return false;
  }

  ZeroMemory(validation.tick);
  ResetLastError();
  if(!SymbolInfoTick(_Symbol, validation.tick) ||
     validation.tick.bid <= 0.0 ||
     validation.tick.ask <= 0.0 ||
     validation.tick.ask < validation.tick.bid)
  {
    validation.reason = "TRAILING_TICK_INVALID";
    validation.retryable = true;
    return false;
  }
  validation.broker_time = validation.tick.time > 0
                           ? validation.tick.time
                           : TimeCurrent();

  if(!RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints))
  {
    validation.reason = "TRAILING_CONSTRAINT_REFRESH_FAILED";
    validation.retryable = true;
    return false;
  }
  validation.point_size = g_symbol_constraints.point_size;
  validation.stops_distance_points = g_symbol_constraints.stops_level_points;
  validation.freeze_distance_points = g_symbol_constraints.freeze_level_points;
  if(validation.point_size <= 0.0)
  {
    validation.reason = "TRAILING_POINT_SIZE_INVALID";
    validation.retryable = true;
    return false;
  }

  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) !=
     ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
  {
    validation.reason = "TRAILING_MARGIN_MODE_UNSUPPORTED";
    validation.retryable = false;
    ActivatePivotOwnershipEntryBlock(validation.reason);
    return false;
  }
  long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
  if(!SymbolTradeModeAllowsExecution(trade_mode, signal.direction))
  {
    validation.reason = "TRAILING_SYMBOL_TRADE_MODE_BLOCKED";
    validation.retryable = true;
    return false;
  }
  if(!IsSymbolTradeSessionOpen(_Symbol, validation.broker_time))
  {
    validation.reason = "TRAILING_SESSION_CLOSED";
    validation.retryable = true;
    return false;
  }
  if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) <= 0 ||
     AccountInfoInteger(ACCOUNT_TRADE_EXPERT) <= 0 ||
     TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) <= 0 ||
     MQLInfoInteger(MQL_TRADE_ALLOWED) <= 0)
  {
    validation.reason = "TRAILING_TRADE_PERMISSION_BLOCKED";
    validation.retryable = true;
    return false;
  }

  double target_tolerance = PivotTrailingPriceTolerance();
  if(MathAbs(validation.take_profit - signal.execution.take_profit_price) >
     target_tolerance)
  {
    validation.reason = "BROKER_TP_CAPTURE_MISMATCH";
    validation.retryable = false;
    ActivatePivotOwnershipEntryBlock(validation.reason);
    return false;
  }
  if(!ExecutionProtectionGeometryValid(signal.direction,
                                       validation.tick.bid,
                                       validation.tick.ask,
                                       desired_stop,
                                       validation.take_profit))
  {
    validation.reason = "TRAILING_DIRECTIONAL_GEOMETRY_INVALID";
    validation.retryable = true;
    return false;
  }

  double protection_reference = signal.direction == BULLISH
                                ? validation.tick.bid
                                : validation.tick.ask;
  double stop_points = ExecutionPriceDistancePoints(protection_reference,
                                                    desired_stop,
                                                    validation.point_size);
  double target_points = ExecutionPriceDistancePoints(protection_reference,
                                                      validation.take_profit,
                                                      validation.point_size);
  if(stop_points + 1e-9 < validation.stops_distance_points ||
     target_points + 1e-9 < validation.stops_distance_points)
  {
    validation.reason = "TRAILING_STOPS_DISTANCE_BLOCKED";
    validation.retryable = true;
    return false;
  }
  if(stop_points + 1e-9 < validation.freeze_distance_points ||
     target_points + 1e-9 < validation.freeze_distance_points)
  {
    validation.reason = "TRAILING_FREEZE_DISTANCE_BLOCKED";
    validation.retryable = true;
    return false;
  }

  validation.allowed = true;
  validation.retryable = false;
  validation.reason = "";
  return true;
}

bool PivotTrailingRetcodeAccepted(const ulong retcode)
{
  return retcode == TRADE_RETCODE_DONE ||
         retcode == TRADE_RETCODE_PLACED ||
         retcode == TRADE_RETCODE_NO_CHANGES;
}

bool PivotTrailingRetcodeRetryable(const ulong retcode)
{
  return retcode == TRADE_RETCODE_REQUOTE ||
         retcode == TRADE_RETCODE_TIMEOUT ||
         retcode == TRADE_RETCODE_PRICE_CHANGED ||
         retcode == TRADE_RETCODE_PRICE_OFF ||
         retcode == TRADE_RETCODE_TOO_MANY_REQUESTS ||
         retcode == TRADE_RETCODE_LOCKED ||
         retcode == TRADE_RETCODE_FROZEN ||
         retcode == TRADE_RETCODE_CONNECTION ||
         retcode == TRADE_RETCODE_INVALID_STOPS ||
         retcode == TRADE_RETCODE_MARKET_CLOSED ||
         retcode == TRADE_RETCODE_TRADE_DISABLED;
}

void ExecutePivotTrailingModification(PivotSignal &signal,
                                       const double desired_stop,
                                       const int milestone_index)
{
  PivotTrailingValidation validation;
  if(!PreparePivotTrailingModification(signal,
                                       desired_stop,
                                       validation))
  {
    bool retry_pending = validation.retryable;
    if(!retry_pending)
      PivotClearPendingStop(signal);
    else
      PivotScheduleTrailingRetry(signal, false);
    PivotRecordTrailingEvent(signal,
                             milestone_index,
                             validation.broker_time,
                             validation.previous_stop,
                             desired_stop,
                             0.0,
                             validation.previous_stop,
                             false,
                             false,
                             0,
                             validation.reason,
                             retry_pending,
                             retry_pending
                             ? "MODIFICATION_BLOCKED_RETRY"
                             : "MODIFICATION_BLOCKED_PERMANENT");
    return;
  }

  MqlTradeRequest request;
  MqlTradeResult result;
  ZeroMemory(request);
  ZeroMemory(result);
  request.action = TRADE_ACTION_SLTP;
  request.symbol = _Symbol;
  request.magic = g_execution_magic;
  request.position = signal.execution.position_ticket;
  request.sl = desired_stop;
  request.tp = validation.take_profit;

  MqlTradeCheckResult check_result;
  ZeroMemory(check_result);
  ResetLastError();
  bool check_api_result = OrderCheck(request, check_result);
  int check_error = GetLastError();
  bool check_allowed = check_api_result &&
                       (ExecutionOrderCheckRetcodeAllowed(check_result.retcode) ||
                        check_result.retcode == TRADE_RETCODE_NO_CHANGES);
  if(!check_allowed)
  {
    bool retry_pending = !check_api_result ||
                         PivotTrailingRetcodeRetryable(check_result.retcode);
    if(retry_pending)
      PivotScheduleTrailingRetry(signal, false);
    else
      PivotClearPendingStop(signal);

    string check_comment = StringFormat("order_check_api=%s|error=%d|comment=%s",
                                        check_api_result ? "true" : "false",
                                        check_error,
                                        check_result.comment);
    PivotRecordTrailingEvent(signal,
                             milestone_index,
                             validation.broker_time,
                             validation.previous_stop,
                             desired_stop,
                             0.0,
                             validation.previous_stop,
                             false,
                             false,
                             check_result.retcode,
                             check_comment,
                             retry_pending,
                             retry_pending
                             ? "MODIFICATION_CHECK_REJECTED_RETRY"
                             : "MODIFICATION_CHECK_REJECTED_PERMANENT");
    return;
  }

  ResetLastError();
  bool api_result = OrderSend(request, result);
  int send_error = GetLastError();
  bool accepted = api_result && PivotTrailingRetcodeAccepted(result.retcode);
  bool confirmed = false;
  double confirmed_stop = validation.previous_stop;
  string reconciliation_reason = "";
  if(accepted && SelectPivotPositionByOwnedTicket(signal,
                                                  reconciliation_reason))
  {
    ApplySelectedPivotPositionFacts(signal);
    confirmed_stop = signal.execution.broker_stop_loss;
    confirmed = PivotTrailingStopAtLeast(signal.direction,
                                         confirmed_stop,
                                         desired_stop);
  }

  if(confirmed)
  {
    PivotClearPendingStop(signal);
    PivotRecordTrailingEvent(signal,
                             milestone_index,
                             validation.broker_time,
                             validation.previous_stop,
                             desired_stop,
                             desired_stop,
                             confirmed_stop,
                             true,
                             true,
                             result.retcode,
                             result.comment,
                             false,
                             "MODIFICATION_CONFIRMED");
    return;
  }

  bool retry_pending = accepted ||
                       PivotTrailingRetcodeRetryable(result.retcode) ||
                       reconciliation_reason == "POSITION_TICKET_NOT_FOUND";
  if(retry_pending)
    PivotScheduleTrailingRetry(signal, accepted);
  else
    PivotClearPendingStop(signal);

  string comment = result.comment;
  if(comment == "")
    comment = StringFormat("api=%s|error=%d|reconcile=%s",
                           api_result ? "true" : "false",
                           send_error,
                           reconciliation_reason);
  PivotRecordTrailingEvent(signal,
                           milestone_index,
                           validation.broker_time,
                           validation.previous_stop,
                           desired_stop,
                           desired_stop,
                           confirmed_stop,
                           true,
                           accepted,
                           result.retcode,
                           comment,
                           retry_pending,
                           accepted
                           ? "MODIFICATION_ACCEPTED_PENDING"
                           : retry_pending
                             ? "MODIFICATION_REJECTED_RETRY"
                             : "MODIFICATION_REJECTED_PERMANENT");
}

void ProcessPivotSignalTrailing(PivotSignal &signal,
                                const MqlTick &tick)
{
  if(!signal.execution.broker_entry_confirmed ||
     signal.execution.broker_close_confirmed ||
     signal.execution.position_ticket == 0)
    return;

  string ownership_reason = "";
  if(!SelectPivotPositionByOwnedTicket(signal, ownership_reason))
  {
    if(ReconcilePivotCloseFromHistory(signal))
      return;
    if(!signal.execution.trailing_ownership_failure_recorded)
    {
      signal.execution.trailing_ownership_failure_recorded = true;
      BrokerExecutionCheck ownership_check(signal.execution.send_result_check);
      ownership_check.phase = "POSITION_OWNERSHIP";
      ownership_check.sequence = NextBrokerExecutionCheckSequence(signal);
      ownership_check.broker_time = tick.time > 0
                                    ? tick.time
                                    : TimeCurrent();
      ownership_check.allowed = false;
      ownership_check.block_source = "position_ownership";
      ownership_check.block_reason = ownership_reason;
      ExportPivotExecutionCheck(signal, ownership_check);
      int event_index = signal.execution.pending_milestone_index >= 0
                        ? signal.execution.pending_milestone_index
                        : signal.execution.highest_milestone_index;
      if(event_index >= 0)
        PivotRecordTrailingEvent(signal,
                                 event_index,
                                 tick.time,
                                 signal.execution.broker_stop_loss,
                                 signal.execution.pending_stop_loss,
                                 0.0,
                                 signal.execution.broker_stop_loss,
                                 false,
                                 false,
                                 0,
                                 ownership_reason,
                                 ownership_reason == "POSITION_TICKET_NOT_FOUND",
                                 "POSITION_OWNERSHIP_FAILED");
    }
    ExecutionAppendQueryDebugThrottledLog("PIVOT_POSITION_OWNERSHIP",
                                         signal.signal_id,
                                         ownership_reason,
                                         PIVOT_TRAILING_LOG_THROTTLE_SECONDS);
    return;
  }

  signal.execution.trailing_ownership_failure_recorded = false;
  ApplySelectedPivotPositionFacts(signal);
  int reached_index = PivotHighestReachedMilestone(signal, tick);
  bool milestone_advanced =
    reached_index > signal.execution.highest_milestone_index;
  if(milestone_advanced)
    signal.execution.highest_milestone_index = reached_index;

  int desired_index = -1;
  double desired_stop = 0.0;
  bool desired_exists = PivotStrongestDesiredStop(signal,
                                                  signal.execution.highest_milestone_index,
                                                  desired_index,
                                                  desired_stop);
  if(!desired_exists)
  {
    if(milestone_advanced)
      PivotRecordTrailingEvent(signal,
                               reached_index,
                               tick.time,
                               signal.execution.broker_stop_loss,
                               0.0,
                               0.0,
                               signal.execution.broker_stop_loss,
                               false,
                               false,
                               0,
                               "",
                               false,
                               "MILESTONE_REACHED_NO_CHANGE");
    return;
  }

  if(PivotTrailingStopAtLeast(signal.direction,
                              signal.execution.broker_stop_loss,
                              desired_stop))
  {
    bool had_pending = signal.execution.pending_stop_loss > 0.0;
    int confirmed_index = signal.execution.pending_milestone_index;
    PivotClearPendingStop(signal);
    if(had_pending || milestone_advanced)
      PivotRecordTrailingEvent(signal,
                               had_pending ? confirmed_index : desired_index,
                               tick.time,
                               signal.execution.broker_stop_loss,
                               desired_stop,
                               0.0,
                               signal.execution.broker_stop_loss,
                               false,
                               false,
                               0,
                               "",
                               false,
                               had_pending
                               ? "PENDING_CONFIRMATION_OBSERVED"
                               : "MILESTONE_ALREADY_PROTECTED");
    return;
  }

  if(signal.execution.pending_stop_loss <= 0.0 ||
     PivotTrailingStopStronger(signal.direction,
                               desired_stop,
                               signal.execution.pending_stop_loss))
    PivotSetPendingStop(signal, desired_index, desired_stop);

  if(signal.execution.pending_stop_loss <= 0.0)
    return;
  datetime now = TimeCurrent();
  if(signal.execution.next_trailing_retry_time > 0 &&
     now < signal.execution.next_trailing_retry_time)
    return;
  if(signal.execution.trailing_confirmation_pending)
  {
    PivotScheduleTrailingRetry(signal, false);
    return;
  }

  ExecutePivotTrailingModification(signal,
                                   signal.execution.pending_stop_loss,
                                   signal.execution.pending_milestone_index);
}

void ExportPivotTerminalExecutionCheck(PivotSignal &signal)
{
  if(signal.execution.terminal_check_exported)
    return;
  signal.execution.terminal_check_exported = true;
  if(!PivotV9Enabled() || signal.signal_id == "")
    return;

  BrokerExecutionCheck check(signal.execution.send_result_check);
  check.phase = "ORDER_TERMINAL";
  check.sequence = NextBrokerExecutionCheckSequence(signal);
  check.broker_time = TimeCurrent();
  check.allowed = false;
  check.block_source = signal.block_source == ""
                       ? "broker_order"
                       : signal.block_source;
  check.block_reason = signal.execution.terminal_reason;
  ExportPivotExecutionCheck(signal, check);
}

bool ExportPivotSignalOutcome(PivotSignal &signal)
{
  if(signal.execution.outcome_exported)
    return true;
  if(!PivotV9Enabled())
  {
    signal.execution.outcome_exported = true;
    return true;
  }

  PivotV9OutcomePayload payload;
  payload.signal_id = signal.signal_id;
  payload.window_id = signal.window_id;
  payload.pivot_timeframe = signal.pivot_timeframe;
  payload.active_bar_open = signal.active_bar_open;
  payload.level_id = signal.level_id;
  payload.direction = signal.direction;
  payload.entry_time = signal.execution.broker_entry_time;
  payload.close_time = signal.execution.close_time;
  payload.order_ticket = signal.execution.order_ticket;
  payload.entry_deal_ticket = signal.execution.entry_deal_ticket;
  payload.close_deal_ticket = signal.execution.close_deal_ticket;
  payload.position_ticket = signal.execution.position_ticket;
  payload.position_identifier = signal.execution.position_identifier;
  payload.broker_entry_price = signal.execution.broker_entry_price;
  payload.broker_volume = signal.execution.broker_volume;
  payload.initial_stop_loss = signal.route.structural_stop_loss;
  payload.terminal_take_profit = signal.execution.take_profit_price;
  payload.final_broker_stop_loss = signal.execution.broker_stop_loss;
  payload.final_broker_take_profit = signal.execution.broker_take_profit;
  payload.close_price = signal.execution.close_price;
  payload.closed_volume = signal.execution.closed_volume;
  payload.realized_profit = signal.execution.realized_profit;
  payload.highest_milestone_level = "NONE";
  payload.terminal_reason = signal.execution.terminal_reason;
  payload.broker_entry_confirmed = signal.execution.broker_entry_confirmed;
  payload.broker_close_confirmed = signal.execution.broker_close_confirmed;
  bool recorded = PivotV9RecordOutcome(payload);
  if(recorded)
    signal.execution.outcome_exported = true;
  return recorded;
}

void LogPivotSignalTerminal(const PivotSignal &signal)
{
  string message = StringFormat("signal_id=%s|state=%s|entry_confirmed=%s|close_confirmed=%s|reason=%s|position=%I64u|identifier=%I64u|profit=%.10f",
                                signal.signal_id,
                                EnumToString(signal.execution.state),
                                signal.execution.broker_entry_confirmed ? "true" : "false",
                                signal.execution.broker_close_confirmed ? "true" : "false",
                                signal.execution.terminal_reason,
                                signal.execution.position_ticket,
                                signal.execution.position_identifier,
                                signal.execution.realized_profit);
  ExecutionAppendQueryDebugLog("PIVOT_TERMINAL", message);
  if(Enable_Logs)
    Print("PIVOT_TERMINAL | ", message);
}

void FinalizePivotSignalTerminalStates()
{
  for(int i = ArraySize(g_pivot_signals) - 1; i >= 0; i--)
  {
    if(g_pivot_signals[i].execution.state == EXECUTION_ORDER_BROKER_CLOSED)
    {
      ExportPivotSignalOutcome(g_pivot_signals[i]);
      LogPivotSignalTerminal(g_pivot_signals[i]);
      PivotSignalRemoveAt(i);
      continue;
    }
    if(g_pivot_signals[i].execution.state == EXECUTION_ORDER_CANCELED ||
       g_pivot_signals[i].execution.state == EXECUTION_ORDER_FAILED)
    {
      ExportPivotTerminalExecutionCheck(g_pivot_signals[i]);
      LogPivotSignalTerminal(g_pivot_signals[i]);
      PivotSignalRemoveAt(i);
    }
  }
}

void ReconcileAndFinalizePivotSignals()
{
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
  FinalizePivotSignalTerminalStates();
}

void ProcessPivotSignalLifecycle(const MqlTick &tick)
{
  RefreshPivotBrokerOwnershipBoundary();
  for(int i = ArraySize(g_pivot_signals) - 1; i >= 0; i--)
  {
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
    if(g_pivot_signals[i].execution.state == EXECUTION_ORDER_BROKER_ACTIVE)
      ProcessPivotSignalTrailing(g_pivot_signals[i], tick);
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
  }
  FinalizePivotSignalTerminalStates();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_LIFECYCLE_MQH_
