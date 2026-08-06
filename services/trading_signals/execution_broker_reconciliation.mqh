//+------------------------------------------------------------------+
//|               execution_broker_reconciliation                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_

const int PIVOT_ENTRY_HISTORY_LOOKBACK_SECONDS = 3600;
const int PIVOT_CLOSE_HISTORY_LOOKBACK_SECONDS = 86400 * 30;

int CountOwnedPivotPositions()
{
  int count = 0;
  for(int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if((ulong)PositionGetInteger(POSITION_MAGIC) == g_execution_magic)
      count++;
  }
  return count;
}

void ActivatePivotOwnershipEntryBlock(const string reason)
{
  if(g_pivot_startup_positions_block_entries)
    return;
  g_pivot_startup_positions_block_entries = true;
  string message = "reason=" + reason + "|action=entry_blocked_until_flat";
  ExecutionAppendQueryDebugLog("PIVOT_OWNERSHIP_FAILURE", message);
  if(Enable_Logs)
    Print("PIVOT_OWNERSHIP_FAILURE | ", message);
}

string PivotPositionComment(const PivotSignal &signal)
{
  string identity = signal.signal_id;
  if(StringLen(identity) > 24)
    identity = StringSubstr(identity, StringLen(identity) - 24);
  return "PF9_" + identity;
}

bool PivotPositionCommentMatches(const PivotSignal &signal)
{
  return PositionGetString(POSITION_COMMENT) == PivotPositionComment(signal);
}

bool SelectedPivotPositionScopeMatches(const PivotSignal &signal)
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
  return true;
}

bool SelectPivotPositionByOwnedTicket(PivotSignal &signal,
                                      string &reason_out)
{
  reason_out = "";
  if(signal.execution.position_ticket == 0)
  {
    reason_out = "POSITION_TICKET_UNAVAILABLE";
    return false;
  }
  if(!PositionSelectByTicket(signal.execution.position_ticket))
  {
    reason_out = "POSITION_TICKET_NOT_FOUND";
    return false;
  }
  if(!SelectedPivotPositionScopeMatches(signal))
  {
    reason_out = "POSITION_SCOPE_MISMATCH";
    ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }
  if(!PivotPositionCommentMatches(signal))
  {
    reason_out = "POSITION_IDENTITY_COMMENT_MISMATCH";
    ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }
  if(signal.execution.position_identifier > 0 &&
     (ulong)PositionGetInteger(POSITION_IDENTIFIER) !=
       signal.execution.position_identifier)
  {
    reason_out = "POSITION_IDENTIFIER_MISMATCH";
    ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }
  return true;
}

bool SelectPivotEntryPositionByKnownTicket(PivotSignal &signal,
                                           string &reason_out)
{
  reason_out = "";
  if(signal.execution.position_ticket == 0)
  {
    reason_out = "ENTRY_TICKET_UNAVAILABLE";
    return false;
  }
  if(!PositionSelectByTicket(signal.execution.position_ticket))
  {
    reason_out = "ENTRY_TICKET_NOT_FOUND";
    return false;
  }
  if(!SelectedPivotPositionScopeMatches(signal))
  {
    reason_out = "ENTRY_POSITION_SCOPE_MISMATCH";
    ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }
  if(!PivotPositionCommentMatches(signal))
  {
    reason_out = "ENTRY_IDENTITY_COMMENT_MISMATCH";
    ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }
  return true;
}

bool SelectPivotEntryPositionByIdentity(PivotSignal &signal,
                                        string &reason_out)
{
  reason_out = "";
  int matched_ticket_count = 0;
  ulong matched_ticket = 0;
  bool identity_comment_mismatch = false;
  int total = PositionsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket == 0 || !SelectedPivotPositionScopeMatches(signal))
      continue;

    ulong selected_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    bool identifier_matches = signal.execution.position_identifier > 0 &&
                              selected_identifier ==
                                signal.execution.position_identifier;
    bool comment_matches = PivotPositionCommentMatches(signal);
    if(identifier_matches && !comment_matches)
      identity_comment_mismatch = true;
    if(!identifier_matches || !comment_matches)
      continue;

    matched_ticket_count++;
    matched_ticket = ticket;
  }

  if(matched_ticket_count != 1)
  {
    if(identity_comment_mismatch)
      reason_out = "ENTRY_IDENTITY_COMMENT_MISMATCH";
    else
      reason_out = matched_ticket_count == 0
                   ? "ENTRY_IDENTITY_NOT_FOUND"
                   : "ENTRY_IDENTITY_NOT_UNIQUE";
    if(identity_comment_mismatch || matched_ticket_count > 1)
      ActivatePivotOwnershipEntryBlock(reason_out);
    return false;
  }

  if(!PositionSelectByTicket(matched_ticket))
  {
    reason_out = "ENTRY_IDENTITY_SELECT_FAILED";
    return false;
  }
  signal.execution.position_ticket = matched_ticket;
  return true;
}

void ApplySelectedPivotPositionFacts(PivotSignal &signal)
{
  double selected_volume = PositionGetDouble(POSITION_VOLUME);
  signal.execution.position_ticket =
    (ulong)PositionGetInteger(POSITION_TICKET);
  signal.execution.position_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  signal.execution.position_comment = PositionGetString(POSITION_COMMENT);
  signal.execution.broker_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  if(selected_volume > signal.execution.broker_volume)
    signal.execution.broker_volume = selected_volume;
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

bool PivotHistoryOrderIdentityMatches(const PivotSignal &signal,
                                      const ulong order_ticket)
{
  if(order_ticket == 0 || !HistoryOrderSelect(order_ticket))
    return false;
  if(HistoryOrderGetString(order_ticket, ORDER_SYMBOL) != _Symbol ||
     (ulong)HistoryOrderGetInteger(order_ticket, ORDER_MAGIC) !=
       g_execution_magic ||
     HistoryOrderGetString(order_ticket, ORDER_COMMENT) !=
       PivotPositionComment(signal))
    return false;

  ENUM_ORDER_TYPE order_type =
    (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order_ticket, ORDER_TYPE);
  if(signal.direction == BULLISH)
    return order_type == ORDER_TYPE_BUY;
  if(signal.direction == BEARISH)
    return order_type == ORDER_TYPE_SELL;
  return false;
}

bool PivotHistoryDealIdentityMatches(const PivotSignal &signal,
                                     const ulong deal_ticket,
                                     const ulong order_ticket)
{
  if(PivotHistoryOrderIdentityMatches(signal, order_ticket))
    return true;
  return HistoryDealGetString(deal_ticket, DEAL_COMMENT) ==
         PivotPositionComment(signal);
}

bool ReconcilePivotEntryFromHistory(PivotSignal &signal)
{
  if(signal.execution.broker_entry_confirmed)
    return true;
  if(signal.execution.order_ticket == 0 &&
     signal.execution.entry_deal_ticket == 0)
    return false;

  datetime from_time = signal.trigger_time > 0
                       ? signal.trigger_time - PIVOT_ENTRY_HISTORY_LOOKBACK_SECONDS
                       : TimeCurrent() - 86400;
  if(!HistorySelect(from_time, TimeCurrent() + 60))
    return false;

  bool found = false;
  datetime entry_time = 0;
  double entry_value = 0.0;
  double entry_volume = 0.0;
  ulong position_identifier = 0;
  ulong entry_deal_ticket = 0;
  ulong entry_order_ticket = signal.execution.order_ticket;
  int total = HistoryDealsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket == 0)
      continue;
    ulong deal_order =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    bool matches_deal = signal.execution.entry_deal_ticket > 0 &&
                        deal_ticket == signal.execution.entry_deal_ticket;
    bool matches_order = entry_order_ticket > 0 &&
                         deal_order == entry_order_ticket;
    if(!matches_deal && !matches_order)
      continue;
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) !=
         g_execution_magic ||
       !PivotDealDirectionMatches(deal_ticket, signal.direction) ||
       !PivotHistoryDealIdentityMatches(signal, deal_ticket, deal_order))
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(!found || deal_time < entry_time ||
       (deal_time == entry_time && deal_ticket < entry_deal_ticket))
    {
      entry_time = deal_time;
      entry_deal_ticket = deal_ticket;
    }
    double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    ulong deal_position_identifier =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    if(deal_volume <= 0.0 || deal_price <= 0.0 ||
       deal_position_identifier == 0 ||
       (position_identifier > 0 &&
        position_identifier != deal_position_identifier) ||
       (entry_order_ticket > 0 && deal_order != entry_order_ticket))
      return false;
    entry_value += deal_price * deal_volume;
    entry_volume += deal_volume;
    position_identifier = deal_position_identifier;
    entry_order_ticket = deal_order;
    found = true;
  }

  double entry_price = entry_volume > 0.0
                       ? entry_value / entry_volume
                       : 0.0;
  if(!found ||
     entry_order_ticket == 0 ||
     position_identifier == 0 ||
     entry_time <= 0 ||
     entry_price <= 0.0 ||
     entry_volume <= 0.0)
    return false;

  signal.execution.order_ticket = entry_order_ticket;
  signal.execution.position_identifier = position_identifier;
  signal.execution.entry_deal_ticket = entry_deal_ticket;
  if(signal.execution.position_ticket == 0)
    signal.execution.position_ticket = entry_order_ticket;
  signal.execution.broker_entry_price = entry_price;
  signal.execution.broker_entry_time = entry_time;
  signal.execution.broker_volume = entry_volume;
  if(PivotHistoryOrderIdentityMatches(signal, entry_order_ticket))
  {
    signal.execution.broker_stop_loss =
      HistoryOrderGetDouble(entry_order_ticket, ORDER_SL);
    signal.execution.broker_take_profit =
      HistoryOrderGetDouble(entry_order_ticket, ORDER_TP);
  }
  signal.execution.broker_entry_confirmed = true;
  signal.execution.state = EXECUTION_ORDER_BROKER_ACTIVE;
  signal.execution.last_action_time = TimeCurrent();
  signal.admission_status = EXECUTION_ADMISSION_FILLED;
  return true;
}

string PivotCloseReasonToken(const ENUM_DEAL_REASON reason)
{
  if(reason == DEAL_REASON_TP)
    return "broker_tp";
  if(reason == DEAL_REASON_SL)
    return "broker_sl";
  if(reason == DEAL_REASON_CLIENT ||
     reason == DEAL_REASON_MOBILE ||
     reason == DEAL_REASON_WEB)
    return "manual_close";
  if(reason == DEAL_REASON_SO)
    return "stop_out";
  if(reason == DEAL_REASON_EXPERT)
    return "expert_or_other_close";
  return "broker_history_close";
}

bool PivotPositionIdentifierStillOpen(PivotSignal &signal)
{
  if(signal.execution.position_identifier == 0)
    return false;
  for(int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket == 0 ||
       PositionGetString(POSITION_SYMBOL) != _Symbol ||
       (ulong)PositionGetInteger(POSITION_MAGIC) != g_execution_magic ||
       (ulong)PositionGetInteger(POSITION_IDENTIFIER) !=
         signal.execution.position_identifier)
      continue;
    ActivatePivotOwnershipEntryBlock("POSITION_TICKET_CHANGED_OR_UNOWNED");
    return true;
  }
  return false;
}

bool ReconcilePivotCloseFromHistory(PivotSignal &signal)
{
  if(!signal.execution.broker_entry_confirmed ||
     signal.execution.position_identifier == 0)
    return false;
  if(signal.execution.broker_close_confirmed)
    return true;
  if(PivotPositionIdentifierStillOpen(signal))
    return false;

  datetime from_time = signal.execution.broker_entry_time > 0
                       ? signal.execution.broker_entry_time -
                         PIVOT_CLOSE_HISTORY_LOOKBACK_SECONDS
                       : TimeCurrent() - PIVOT_CLOSE_HISTORY_LOOKBACK_SECONDS;
  if(!HistorySelect(from_time, TimeCurrent() + 60))
    return false;

  double realized_profit = 0.0;
  double closed_volume = 0.0;
  double close_value = 0.0;
  datetime close_time = 0;
  ulong close_deal_ticket = 0;
  double close_deal_stop_loss = 0.0;
  double close_deal_take_profit = 0.0;
  ENUM_DEAL_REASON close_reason = DEAL_REASON_EXPERT;
  bool close_found = false;
  int total = HistoryDealsTotal();
  for(int i = 0; i < total; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket == 0 ||
       HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) !=
         g_execution_magic ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) !=
         signal.execution.position_identifier)
      continue;

    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    realized_profit += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT &&
       deal_entry != DEAL_ENTRY_OUT_BY &&
       deal_entry != DEAL_ENTRY_INOUT)
      continue;

    close_found = true;
    double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    if(deal_volume <= 0.0 || deal_price <= 0.0)
      return false;
    closed_volume += deal_volume;
    close_value += deal_price * deal_volume;
    datetime deal_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(deal_time > close_time ||
       (deal_time == close_time && deal_ticket > close_deal_ticket))
    {
      close_time = deal_time;
      close_deal_ticket = deal_ticket;
      close_deal_stop_loss = HistoryDealGetDouble(deal_ticket, DEAL_SL);
      close_deal_take_profit = HistoryDealGetDouble(deal_ticket, DEAL_TP);
      close_reason =
        (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
    }
  }

  double close_price = closed_volume > 0.0
                       ? close_value / closed_volume
                       : 0.0;
  if(!close_found ||
     close_time <= 0 ||
     close_price <= 0.0 ||
     closed_volume <= 0.0 ||
     (signal.execution.broker_volume > 0.0 &&
      closed_volume + 1e-9 < signal.execution.broker_volume))
    return false;

  signal.execution.close_deal_ticket = close_deal_ticket;
  signal.execution.close_price = close_price;
  signal.execution.close_time = close_time;
  signal.execution.closed_volume = closed_volume;
  signal.execution.realized_profit = realized_profit;
  if(close_deal_stop_loss > 0.0)
    signal.execution.broker_stop_loss = close_deal_stop_loss;
  if(close_deal_take_profit > 0.0)
    signal.execution.broker_take_profit = close_deal_take_profit;
  signal.execution.broker_close_confirmed = true;
  signal.execution.state = EXECUTION_ORDER_BROKER_CLOSED;
  signal.execution.terminal_reason = PivotCloseReasonToken(close_reason);
  signal.execution.last_action_time = TimeCurrent();
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
     order_state != ORDER_STATE_EXPIRED)
    return false;
  if(!PivotHistoryOrderIdentityMatches(signal,
                                       signal.execution.order_ticket))
  {
    signal.execution.state = EXECUTION_ORDER_FAILED;
    signal.execution.terminal_reason = "BROKER_ORDER_IDENTITY_MISMATCH";
    signal.execution.last_action_time = TimeCurrent();
    signal.admission_status = EXECUTION_ADMISSION_SEND_FAILED;
    signal.block_source = "broker_order";
    signal.block_reason = signal.execution.terminal_reason;
    return true;
  }

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
  string reason = "";
  if(signal.execution.broker_entry_confirmed)
  {
    if(SelectPivotPositionByOwnedTicket(signal, reason))
    {
      ApplySelectedPivotPositionFacts(signal);
      return;
    }
    ReconcilePivotCloseFromHistory(signal);
    return;
  }

  if(SelectPivotEntryPositionByKnownTicket(signal, reason))
  {
    ApplySelectedPivotPositionFacts(signal);
    return;
  }

  if(ReconcilePivotEntryFromHistory(signal))
  {
    if(SelectPivotEntryPositionByIdentity(signal, reason) &&
       SelectPivotPositionByOwnedTicket(signal, reason))
    {
      ApplySelectedPivotPositionFacts(signal);
      return;
    }
    ReconcilePivotCloseFromHistory(signal);
    return;
  }

  ReconcilePivotOrderTerminalState(signal);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
