//+------------------------------------------------------------------+
//|               execution_broker_reconciliation                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_

string PivotPositionComment(const PivotSignal &signal)
{
  string identity = signal.signal_id;
  if(StringLen(identity) > 24)
    identity = StringSubstr(identity, StringLen(identity) - 24);
  return "PF9_" + identity;
}

bool SelectedPivotPositionMatches(const PivotSignal &signal)
{
  if(PositionGetString(POSITION_SYMBOL) != _Symbol)
    return false;
  if((ulong)PositionGetInteger(POSITION_MAGIC) != g_execution_magic)
    return false;

  ENUM_POSITION_TYPE position_type =
    (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
  if(signal.direction == BULLISH && position_type != POSITION_TYPE_BUY)
    return false;
  if(signal.direction == BEARISH && position_type != POSITION_TYPE_SELL)
    return false;

  ulong selected_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
  if(signal.execution.position_ticket > 0 &&
     selected_ticket == signal.execution.position_ticket)
    return true;
  if(signal.execution.order_ticket > 0 &&
     selected_ticket == signal.execution.order_ticket)
    return true;

  ulong selected_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  if(signal.execution.position_identifier > 0 &&
     selected_identifier == signal.execution.position_identifier)
    return true;

  string expected_comment = PivotPositionComment(signal);
  string actual_comment = PositionGetString(POSITION_COMMENT);
  if(expected_comment == actual_comment)
    return true;
  if(actual_comment == "" || StringLen(actual_comment) < 12)
    return false;
  return StringFind(expected_comment, actual_comment) == 0 ||
         StringFind(actual_comment, expected_comment) == 0;
}

bool SelectPivotPositionByOwnedTicket(PivotSignal &signal)
{
  if(signal.execution.position_ticket > 0 &&
     PositionSelectByTicket(signal.execution.position_ticket) &&
     SelectedPivotPositionMatches(signal))
    return true;

  if(signal.execution.order_ticket > 0 &&
     signal.execution.order_ticket != signal.execution.position_ticket &&
     PositionSelectByTicket(signal.execution.order_ticket) &&
     SelectedPivotPositionMatches(signal))
  {
    signal.execution.position_ticket =
      (ulong)PositionGetInteger(POSITION_TICKET);
    return true;
  }

  int total = PositionsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket == 0 || !SelectedPivotPositionMatches(signal))
      continue;
    signal.execution.position_ticket = ticket;
    return true;
  }
  return false;
}

void ApplySelectedPivotPositionFacts(PivotSignal &signal)
{
  signal.execution.position_ticket =
    (ulong)PositionGetInteger(POSITION_TICKET);
  signal.execution.position_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  signal.execution.position_comment = PositionGetString(POSITION_COMMENT);
  signal.execution.broker_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  signal.execution.broker_volume = PositionGetDouble(POSITION_VOLUME);
  signal.execution.broker_stop_loss = PositionGetDouble(POSITION_SL);
  signal.execution.broker_take_profit = PositionGetDouble(POSITION_TP);
  signal.execution.broker_entry_time =
    (datetime)PositionGetInteger(POSITION_TIME);
  signal.execution.broker_entry_confirmed = true;
  signal.execution.state = EXECUTION_ORDER_BROKER_ACTIVE;
  signal.execution.last_action_time = TimeCurrent();
  signal.admission_status = EXECUTION_ADMISSION_FILLED;
}

bool PivotDealDirectionMatches(const ulong deal_ticket,
                               const SignalTypes direction)
{
  ENUM_DEAL_TYPE deal_type =
    (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
  if(direction == BULLISH)
    return deal_type == DEAL_TYPE_BUY;
  if(direction == BEARISH)
    return deal_type == DEAL_TYPE_SELL;
  return false;
}

bool ReconcilePivotEntryFromHistory(PivotSignal &signal)
{
  if(signal.execution.broker_entry_confirmed)
    return true;
  if(signal.execution.order_ticket == 0 &&
     signal.execution.deal_ticket == 0)
    return false;

  datetime from_time = signal.trigger_time > 0
                       ? signal.trigger_time - 3600
                       : TimeCurrent() - 86400;
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
    if(deal_ticket == 0)
      continue;
    ulong deal_order =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    bool matches_deal = signal.execution.deal_ticket > 0 &&
                        deal_ticket == signal.execution.deal_ticket;
    bool matches_order = signal.execution.order_ticket > 0 &&
                         deal_order == signal.execution.order_ticket;
    if(!matches_deal && !matches_order)
      continue;
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) !=
       g_execution_magic ||
       !PivotDealDirectionMatches(deal_ticket, signal.direction))
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(!found || deal_time < entry_time)
    {
      entry_time = deal_time;
      entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    }
    entry_volume += HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    position_identifier =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    signal.execution.deal_ticket = deal_ticket;
    found = true;
  }

  if(!found ||
     position_identifier == 0 ||
     entry_time <= 0 ||
     entry_price <= 0.0 ||
     entry_volume <= 0.0)
    return false;

  signal.execution.position_identifier = position_identifier;
  if(signal.execution.position_ticket == 0)
    signal.execution.position_ticket = signal.execution.order_ticket;
  signal.execution.broker_entry_price = entry_price;
  signal.execution.broker_entry_time = entry_time;
  signal.execution.broker_volume = entry_volume;
  signal.execution.broker_entry_confirmed = true;
  signal.execution.state = EXECUTION_ORDER_BROKER_ACTIVE;
  signal.execution.last_action_time = TimeCurrent();
  signal.admission_status = EXECUTION_ADMISSION_FILLED;
  return true;
}

bool ReconcilePivotOrderTerminalState(PivotSignal &signal)
{
  if(signal.execution.order_ticket == 0 ||
     !HistoryOrderSelect(signal.execution.order_ticket))
    return false;

  ENUM_ORDER_STATE order_state =
    (ENUM_ORDER_STATE)HistoryOrderGetInteger(signal.execution.order_ticket,
                                             ORDER_STATE);
  if(order_state != ORDER_STATE_CANCELED &&
     order_state != ORDER_STATE_REJECTED &&
     order_state != ORDER_STATE_EXPIRED &&
     order_state != ORDER_STATE_REQUEST_CANCEL)
    return false;

  signal.execution.state = order_state == ORDER_STATE_REJECTED
                           ? EXECUTION_ORDER_FAILED
                           : EXECUTION_ORDER_CANCELED;
  signal.execution.terminal_reason =
    StringFormat("BROKER_ORDER_%s", EnumToString(order_state));
  signal.execution.last_action_time = TimeCurrent();
  signal.admission_status = EXECUTION_ADMISSION_SEND_FAILED;
  signal.block_source = "broker_order";
  signal.block_reason = signal.execution.terminal_reason;
  return true;
}

void ReconcilePivotSignalBrokerPosition(PivotSignal &signal)
{
  if(SelectPivotPositionByOwnedTicket(signal))
  {
    ApplySelectedPivotPositionFacts(signal);
    return;
  }
  if(ReconcilePivotEntryFromHistory(signal) &&
     SelectPivotPositionByOwnedTicket(signal))
  {
    ApplySelectedPivotPositionFacts(signal);
    return;
  }
  ReconcilePivotOrderTerminalState(signal);
}

void ReconcilePivotSignalsAfterTradeTransaction()
{
  for(int i = 0; i < ArraySize(g_pivot_signals); i++)
    ReconcilePivotSignalBrokerPosition(g_pivot_signals[i]);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
