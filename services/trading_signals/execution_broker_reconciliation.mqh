//+------------------------------------------------------------------+
//|               execution_broker_reconciliation.mqh               |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_

string ExecutionPositionComment(const SignalParams &signal_params)
{
  string identity = signal_params.extremum_attempt_id;
  if(identity == "")
    identity = signal_params.execution_sequence_id;
  if(StringLen(identity) > 20)
    identity = StringSubstr(identity, StringLen(identity) - 20);
  string direction = (signal_params.signal_type == BULLISH) ? "B" : "S";
  return "HFTMD_" + direction + "_" + identity;
}

bool SelectedPositionMatchesExecutionScope(const SignalParams &signal_params,
                                           const string expected_comment)
{
  if(PositionGetString(POSITION_SYMBOL) != _Symbol)
    return false;
  if((ulong)PositionGetInteger(POSITION_MAGIC) != g_execution_magic)
    return false;
  ENUM_POSITION_TYPE position_type =
    (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
  if(signal_params.signal_type == BULLISH && position_type != POSITION_TYPE_BUY)
    return false;
  if(signal_params.signal_type == BEARISH && position_type != POSITION_TYPE_SELL)
    return false;
  ulong selected_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
  if(signal_params.execution.order_ticket > 0 &&
     selected_ticket == signal_params.execution.order_ticket)
    return true;
  ulong selected_identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  if(signal_params.execution.position_identifier > 0 &&
     selected_identifier == signal_params.execution.position_identifier)
    return true;

  if(expected_comment == "")
    return false;

  string actual_comment = PositionGetString(POSITION_COMMENT);
  if(expected_comment != "" && actual_comment != expected_comment)
  {
    // Some brokers truncate comments. Require a meaningful non-empty prefix
    // or suffix before using it as the fallback attempt identity.
    int actual_length = StringLen(actual_comment);
    if(actual_length < 16 ||
       (StringFind(actual_comment, expected_comment) != 0 &&
        StringFind(expected_comment, actual_comment) != 0))
      return false;
  }
  return true;
}

bool SelectExecutionPosition(SignalParams &signal_params)
{
  string expected_comment = ExecutionPositionComment(signal_params);
  if(signal_params.execution.position_ticket > 0 &&
     PositionSelectByTicket(signal_params.execution.position_ticket) &&
     SelectedPositionMatchesExecutionScope(signal_params, expected_comment))
    return true;

  int total = PositionsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket <= 0)
      continue;
    if(!SelectedPositionMatchesExecutionScope(signal_params, expected_comment))
      continue;
    signal_params.execution.position_ticket = ticket;
    return true;
  }
  return false;
}

void ApplySelectedPositionFacts(SignalParams &signal_params)
{
  ExecutionState state = signal_params.execution;
  state.position_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
  state.position_identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  state.position_comment = PositionGetString(POSITION_COMMENT);
  state.broker_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  state.broker_volume = PositionGetDouble(POSITION_VOLUME);
  state.broker_stop_loss = PositionGetDouble(POSITION_SL);
  state.broker_take_profit = PositionGetDouble(POSITION_TP);
  state.broker_entry_time = (datetime)PositionGetInteger(POSITION_TIME);
  state.broker_entry_confirmed = true;
  state.state = EXECUTION_ORDER_BROKER_ACTIVE;
  state.last_action_time = TimeCurrent();
  signal_params.execution = state;

  signal_params.entry_price = state.broker_entry_price;
  signal_params.stop_loss = state.broker_stop_loss;
  signal_params.take_profit = state.broker_take_profit;
  signal_params.lot_size = state.broker_volume;
  signal_params.remaining_open_volume = state.broker_volume;
  signal_params.broker_entry_confirmed = true;
  signal_params.signal_state = OPENED;
  signal_params.admission_status = EXECUTION_ADMISSION_FILLED;
}

bool ReconcileExecutionEntryFromHistory(SignalParams &signal_params)
{
  if(signal_params.execution.broker_entry_confirmed)
    return true;
  if(signal_params.execution.order_ticket <= 0 &&
     signal_params.execution.deal_ticket <= 0)
    return false;

  datetime from_time = signal_params.entry_time;
  if(from_time <= 0)
    from_time = TimeCurrent() - 86400;
  else
    from_time -= 3600;
  if(!HistorySelect(from_time, TimeCurrent() + 60))
    return false;

  bool found = false;
  datetime entry_time = 0;
  double entry_price = 0.0;
  double entry_volume = 0.0;
  ulong position_identifier = 0;
  int total = HistoryDealsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket <= 0)
      continue;
    ulong deal_order = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    bool matches_result_deal =
      (signal_params.execution.deal_ticket > 0 &&
       deal_ticket == signal_params.execution.deal_ticket);
    bool matches_order =
      (signal_params.execution.order_ticket > 0 &&
       deal_order == signal_params.execution.order_ticket);
    if(!matches_result_deal && !matches_order)
      continue;
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      continue;
    if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_execution_magic)
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(!found || deal_time < entry_time)
    {
      entry_time = deal_time;
      entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    }
    entry_volume += HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    position_identifier =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    signal_params.execution.deal_ticket = deal_ticket;
    found = true;
  }

  if(!found || position_identifier <= 0 || entry_price <= 0.0)
    return false;

  signal_params.execution.position_identifier = position_identifier;
  if(signal_params.execution.position_ticket <= 0)
    signal_params.execution.position_ticket = signal_params.execution.order_ticket;
  signal_params.execution.broker_entry_price = entry_price;
  signal_params.execution.broker_entry_time = entry_time;
  signal_params.execution.broker_volume = entry_volume;
  signal_params.execution.broker_stop_loss = signal_params.execution.stop_loss_price;
  signal_params.execution.broker_take_profit = signal_params.execution.take_profit_price;
  signal_params.execution.broker_entry_confirmed = true;
  signal_params.execution.state = EXECUTION_ORDER_BROKER_ACTIVE;
  signal_params.execution.last_action_time = TimeCurrent();

  signal_params.entry_price = entry_price;
  signal_params.entry_time = entry_time;
  signal_params.stop_loss = signal_params.execution.broker_stop_loss;
  signal_params.take_profit = signal_params.execution.broker_take_profit;
  signal_params.lot_size = entry_volume;
  signal_params.remaining_open_volume = entry_volume;
  signal_params.broker_entry_confirmed = true;
  signal_params.signal_state = OPENED;
  signal_params.admission_status = EXECUTION_ADMISSION_FILLED;
  return true;
}

bool ReconcileExecutionCloseFromHistory(SignalParams &signal_params)
{
  if(!signal_params.execution.broker_entry_confirmed ||
     signal_params.execution.position_ticket <= 0)
    return false;

  datetime from_time = signal_params.execution.broker_entry_time;
  if(from_time <= 0)
    from_time = signal_params.entry_time;
  if(from_time <= 0)
    from_time = TimeCurrent() - 86400 * 30;
  else
    from_time -= 86400;

  if(!HistorySelect(from_time, TimeCurrent() + 60))
    return false;

  ulong position_identifier = signal_params.execution.position_identifier;
  if(position_identifier <= 0)
    position_identifier = signal_params.execution.position_ticket;

  double realized_profit = 0.0;
  double closed_volume = 0.0;
  double close_price = 0.0;
  datetime close_time = 0;
  bool close_found = false;
  int total = HistoryDealsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket <= 0)
      continue;
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      continue;
    if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_execution_magic)
      continue;
    if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) !=
       position_identifier)
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_OUT_BY)
      continue;

    close_found = true;
    closed_volume += HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(deal_time >= close_time)
    {
      close_time = deal_time;
      close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      signal_params.execution.deal_ticket = deal_ticket;
      ENUM_DEAL_REASON close_reason =
        (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      if(close_reason == DEAL_REASON_TP)
        signal_params.execution.terminal_reason = "broker_tp";
      else if(close_reason == DEAL_REASON_SL)
        signal_params.execution.terminal_reason = "broker_sl";
      else
        signal_params.execution.terminal_reason = "broker_history_close";
    }
  }

  if(!close_found)
    return false;

  signal_params.execution.closed_position_ticket =
    signal_params.execution.position_ticket;
  signal_params.execution.close_price = close_price;
  signal_params.execution.close_time = close_time;
  signal_params.execution.closed_volume = closed_volume;
  signal_params.execution.realized_profit = realized_profit;
  signal_params.execution.broker_close_confirmed = true;
  signal_params.execution.state = EXECUTION_ORDER_BROKER_CLOSED;
  if(signal_params.execution.terminal_reason == "")
    signal_params.execution.terminal_reason = "broker_history_close";
  signal_params.execution.last_action_time = TimeCurrent();

  signal_params.close_price = close_price;
  signal_params.close_time = close_time;
  signal_params.realized_profit = realized_profit;
  signal_params.realized_closed_volume = closed_volume;
  signal_params.remaining_open_volume = 0.0;
  signal_params.raw_profit = realized_profit;
  signal_params.broker_close_confirmed = true;
  signal_params.broker_close_source = "history_deal";
  signal_params.signal_state = CLOSED;
  return true;
}

bool ReconcileExecutionOrderTerminalState(SignalParams &signal_params)
{
  if(signal_params.execution.order_ticket <= 0)
    return false;
  if(!HistoryOrderSelect(signal_params.execution.order_ticket))
    return false;

  ENUM_ORDER_STATE order_state =
    (ENUM_ORDER_STATE)HistoryOrderGetInteger(signal_params.execution.order_ticket,
                                             ORDER_STATE);
  if(order_state != ORDER_STATE_CANCELED &&
     order_state != ORDER_STATE_REJECTED &&
     order_state != ORDER_STATE_EXPIRED &&
     order_state != ORDER_STATE_REQUEST_CANCEL)
    return false;

  signal_params.execution.state = order_state == ORDER_STATE_REJECTED
                                  ? EXECUTION_ORDER_FAILED
                                  : EXECUTION_ORDER_CANCELED;
  signal_params.execution.terminal_reason =
    StringFormat("broker_order_%s", EnumToString(order_state));
  signal_params.execution.last_action_time = TimeCurrent();
  signal_params.admission_status = EXECUTION_ADMISSION_SEND_FAILED;
  signal_params.admission_block_source = "broker_order";
  signal_params.admission_block_reason = signal_params.execution.terminal_reason;
  signal_params.admission_updated_time = TimeCurrent();
  return true;
}

void ReconcileSignalBrokerPosition(SignalParams &signal_params)
{
  if(SelectExecutionPosition(signal_params))
  {
    ApplySelectedPositionFacts(signal_params);
    return;
  }
  ReconcileExecutionEntryFromHistory(signal_params);
  if(ReconcileExecutionCloseFromHistory(signal_params))
    return;
  ReconcileExecutionOrderTerminalState(signal_params);
}

bool SignalHasBrokerExposure(const SignalParams &signal_params)
{
  if(signal_params.execution.broker_entry_confirmed &&
     !signal_params.execution.broker_close_confirmed &&
     signal_params.execution.position_ticket > 0)
    return true;

  // An accepted market request remains owned by this attempt until a broker
  // transaction confirms either a fill or a terminal order failure. Keep the
  // ownership even when a broker omits ticket ids in the immediate response.
  return (signal_params.execution.state == EXECUTION_ORDER_SEND_ATTEMPTED &&
          signal_params.execution.send_result_check.allowed);
}

bool SignalHasBrokerConfirmedOutcome(const SignalParams &signal_params)
{
  return (signal_params.execution.broker_entry_confirmed &&
          signal_params.execution.broker_close_confirmed);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
