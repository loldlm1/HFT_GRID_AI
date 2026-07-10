//+------------------------------------------------------------------+
//|             trading_signals/execution_broker_reconciliation.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_

struct BrokerPositionSnapshot
{
  bool               found;
  ulong              ticket;
  string             symbol;
  long               magic;
  ENUM_POSITION_TYPE position_type;
  double             volume;
  double             entry_price;
  double             current_price;
  double             profit;
  string             comment;

  BrokerPositionSnapshot()
  {
    found         = false;
    ticket        = 0;
    symbol        = "";
    magic         = 0;
    position_type = POSITION_TYPE_BUY;
    volume        = 0.0;
    entry_price   = 0.0;
    current_price = 0.0;
    profit        = 0.0;
    comment       = "";
  }

  BrokerPositionSnapshot(const BrokerPositionSnapshot &other)
  {
    found         = other.found;
    ticket        = other.ticket;
    symbol        = other.symbol;
    magic         = other.magic;
    position_type = other.position_type;
    volume        = other.volume;
    entry_price   = other.entry_price;
    current_price = other.current_price;
    profit        = other.profit;
    comment       = other.comment;
  }
};

struct BrokerDealCloseSummary
{
  bool     found;
  double   closed_volume;
  double   profit;
  double   close_price;
  datetime close_time;

  BrokerDealCloseSummary()
  {
    found         = false;
    closed_volume = 0.0;
    profit        = 0.0;
    close_price   = 0.0;
    close_time    = 0;
  }
};

bool BrokerPositionTypeMatchesDirection(const ENUM_POSITION_TYPE position_type,
                                        const SignalTypes direction)
{
  if(direction == BULLISH)
    return (position_type == POSITION_TYPE_BUY);
  if(direction == BEARISH)
    return (position_type == POSITION_TYPE_SELL);
  return true;
}

bool CaptureSelectedBrokerPositionSnapshot(BrokerPositionSnapshot &snapshot)
{
  snapshot = BrokerPositionSnapshot();

  string symbol = PositionGetString(POSITION_SYMBOL);
  if(symbol == "")
    return false;

  snapshot.found         = true;
  snapshot.ticket        = (ulong)PositionGetInteger(POSITION_TICKET);
  snapshot.symbol        = symbol;
  snapshot.magic         = PositionGetInteger(POSITION_MAGIC);
  snapshot.position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
  snapshot.volume        = PositionGetDouble(POSITION_VOLUME);
  snapshot.entry_price   = PositionGetDouble(POSITION_PRICE_OPEN);
  snapshot.current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
  snapshot.profit        = PositionGetDouble(POSITION_PROFIT);
  snapshot.comment       = PositionGetString(POSITION_COMMENT);

  return (snapshot.ticket > 0 && snapshot.volume > 0.0);
}

bool BrokerPositionSnapshotMatchesScope(const BrokerPositionSnapshot &snapshot,
                                        const SignalTypes direction,
                                        const string expected_comment,
                                        const bool require_comment)
{
  if(!snapshot.found)
    return false;
  if(snapshot.symbol != _Symbol)
    return false;
  if(snapshot.magic != g_magic_number)
    return false;
  if(!BrokerPositionTypeMatchesDirection(snapshot.position_type, direction))
    return false;
  if(require_comment && expected_comment != "" && snapshot.comment != expected_comment)
    return false;

  return true;
}

bool SelectedBrokerPositionMatchesExecutionScope(const SignalTypes direction)
{
  BrokerPositionSnapshot snapshot;
  if(!CaptureSelectedBrokerPositionSnapshot(snapshot))
    return false;

  return BrokerPositionSnapshotMatchesScope(snapshot, direction, "", false);
}

bool SelectBrokerPositionSnapshotByTicket(const ulong position_ticket,
                                          const SignalTypes direction,
                                          BrokerPositionSnapshot &snapshot)
{
  snapshot = BrokerPositionSnapshot();
  if(position_ticket <= 0)
    return false;
  if(!PositionSelectByTicket(position_ticket))
    return false;
  if(!CaptureSelectedBrokerPositionSnapshot(snapshot))
    return false;

  return BrokerPositionSnapshotMatchesScope(snapshot, direction, "", false);
}

bool FindBrokerPositionSnapshotByComment(const SignalTypes direction,
                                         const string expected_comment,
                                         BrokerPositionSnapshot &snapshot)
{
  snapshot = BrokerPositionSnapshot();
  if(expected_comment == "")
    return false;

  int total_positions = PositionsTotal();
  for(int i = 0; i < total_positions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;

    BrokerPositionSnapshot candidate;
    if(!CaptureSelectedBrokerPositionSnapshot(candidate))
      continue;
    if(!BrokerPositionSnapshotMatchesScope(candidate, direction, expected_comment, true))
      continue;

    snapshot = candidate;
    return true;
  }

  return false;
}

bool FindBrokerPositionForExecutionLeg(const SignalParams &signal_params,
                                       const ExecutionLegState &leg_state,
                                       BrokerPositionSnapshot &snapshot)
{
  snapshot = BrokerPositionSnapshot();
  if(!leg_state.opens_position)
    return false;

  if(SelectBrokerPositionSnapshotByTicket(leg_state.position_ticket,
                                          signal_params.signal_type,
                                          snapshot))
    return true;

  string expected_comment = leg_state.position_comment;
  if(expected_comment == "")
  {
    if(leg_state.status != EXECUTION_LEG_ACTIVE)
      return false;

    expected_comment = ExecutionComposeLegComment(signal_params, leg_state);
  }

  return FindBrokerPositionSnapshotByComment(signal_params.signal_type,
                                             expected_comment,
                                             snapshot);
}

bool ApplyBrokerPositionSnapshotToExecutionLeg(ExecutionLegState &leg_state,
                                               const BrokerPositionSnapshot &snapshot)
{
  if(!snapshot.found)
    return false;

  leg_state.position_ticket  = snapshot.ticket;
  leg_state.position_comment = snapshot.comment;
  if(snapshot.entry_price > 0.0)
    leg_state.entry_price = snapshot.entry_price;
  if(snapshot.volume > 0.0)
    leg_state.lot_size = snapshot.volume;
  if(leg_state.initial_lot_size <= 0.0 && snapshot.volume > 0.0)
    leg_state.initial_lot_size = snapshot.volume;
  if(leg_state.status == EXECUTION_LEG_PENDING ||
     leg_state.status == EXECUTION_LEG_WAITING)
    leg_state.status = EXECUTION_LEG_ACTIVE;

	  return true;
	}

void MarkExecutionLegCloseFacts(ExecutionLegState &leg_state,
                                const ulong position_ticket,
                                const double closed_volume,
                                const double realized_profit,
                                const double close_price,
                                const datetime close_time,
                                const string close_source)
{
  if(position_ticket > 0)
    leg_state.closed_position_ticket = position_ticket;
  if(closed_volume > 0.0)
    leg_state.closed_volume += closed_volume;
  if(MathIsValidNumber(realized_profit))
    leg_state.realized_profit += realized_profit;
  if(close_price > 0.0)
    leg_state.close_price = close_price;
  if(close_time > 0)
    leg_state.close_time = close_time;
  else
    leg_state.close_time = TimeCurrent();

  leg_state.broker_close_confirmed = true;
  leg_state.close_source = close_source;
}

bool ExecutionLegClosedOnTakeProfitSide(const SignalParams &signal_params,
                                        const ExecutionLegState &leg_state,
                                        const double close_price,
                                        const double realized_profit)
{
  if(close_price <= 0.0 || leg_state.take_profit_price <= 0.0)
    return (realized_profit > 0.0);

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0000001;

  double tolerance = point_size * 2.0;
  if(signal_params.signal_type == BULLISH)
    return (close_price + tolerance >= leg_state.take_profit_price);
  if(signal_params.signal_type == BEARISH)
    return (close_price - tolerance <= leg_state.take_profit_price);

  return (realized_profit > 0.0);
}

bool ResolveBrokerCloseSummaryForPosition(const ulong position_ticket,
                                          const datetime entry_time,
                                          BrokerDealCloseSummary &summary)
{
  summary = BrokerDealCloseSummary();
  if(position_ticket <= 0)
    return false;

  datetime to_time = TimeCurrent() + 86400;
  datetime from_time = to_time - 86400 * 30;
  if(entry_time > 0)
    from_time = entry_time - 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return false;

  double weighted_close_price = 0.0;
  int total_deals = HistoryDealsTotal();
  for(int i = 0; i < total_deals; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket <= 0)
      continue;

    ulong deal_position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    if(deal_position_id != position_ticket)
      continue;

    string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    if(deal_symbol != _Symbol)
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT &&
       deal_entry != DEAL_ENTRY_OUT_BY &&
       deal_entry != DEAL_ENTRY_INOUT)
      continue;

    double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    if(deal_volume <= 0.0 || deal_price <= 0.0)
      continue;

    summary.found = true;
    summary.closed_volume += deal_volume;
    summary.profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    summary.profit += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    summary.profit += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
    weighted_close_price += deal_price * deal_volume;

    datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    if(deal_time > summary.close_time)
      summary.close_time = deal_time;
  }

  if(summary.closed_volume > 0.0)
    summary.close_price = weighted_close_price / summary.closed_volume;

  return summary.found;
}

bool ReconcileExecutionLegWithBrokerPosition(SignalParams &signal_params,
                                             const int leg_index)
{
  int total_legs = ArraySize(signal_params.execution_legs);
  if(leg_index < 0 || leg_index >= total_legs)
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(!leg_state.opens_position)
    return true;

  bool had_broker_ticket = (leg_state.position_ticket > 0);
  bool entry_was_confirmed = signal_params.broker_entry_confirmed;
  BrokerPositionSnapshot snapshot;
  if(FindBrokerPositionForExecutionLeg(signal_params, leg_state, snapshot))
  {
    ApplyBrokerPositionSnapshotToExecutionLeg(leg_state, snapshot);
    signal_params.broker_entry_confirmed = true;
    signal_params.admission_status = EXECUTION_ADMISSION_FILLED;
    signal_params.admission_block_source = "";
    signal_params.admission_block_reason = "";
    signal_params.admission_updated_time = TimeCurrent();
    signal_params.execution_legs[leg_index] = leg_state;
    if(!entry_was_confirmed)
      DeterministicSignalStatsRecordAdmissionEvent(signal_params, "broker_entry");
    return true;
  }

  if(had_broker_ticket)
  {
    BrokerDealCloseSummary close_summary;
    if(ResolveBrokerCloseSummaryForPosition(leg_state.position_ticket,
                                            signal_params.entry_time,
                                            close_summary))
    {
      ulong closed_ticket = leg_state.position_ticket;
      signal_params.realized_profit += close_summary.profit;
      signal_params.realized_closed_volume += close_summary.closed_volume;
      signal_params.broker_close_confirmed = true;
      signal_params.broker_close_source = "history_deal";
      MarkExecutionLegCloseFacts(leg_state,
                                 closed_ticket,
                                 close_summary.closed_volume,
                                 close_summary.profit,
                                 close_summary.close_price,
                                 close_summary.close_time,
                                 "history_deal");
      if(Partial_TP_Mode == PARTIAL_TP_R_MULTIPLES &&
         leg_index >= 0 &&
         leg_index < PARTIAL_TP_LEVELS_TOTAL &&
         ExecutionLegClosedOnTakeProfitSide(signal_params,
                                            leg_state,
                                            close_summary.close_price,
                                            close_summary.profit))
      {
        MarkPartialTPLevelConfirmed(signal_params,
                                    leg_index,
                                    close_summary.closed_volume,
                                    close_summary.close_price);
      }
      if(close_summary.close_price > 0.0)
        signal_params.close_price = close_summary.close_price;
      if(close_summary.close_time > 0)
        signal_params.close_time = close_summary.close_time;
    }

    leg_state.position_ticket = 0;
    leg_state.lot_size = 0.0;
    leg_state.status = EXECUTION_LEG_COMPLETED;
    signal_params.execution_legs[leg_index] = leg_state;
  }

  return true;
}

int ReconcileSignalBrokerPositions(SignalParams &signal_params)
{
  int reconciled = 0;
  int total_legs = ArraySize(signal_params.execution_legs);
  for(int idx = 0; idx < total_legs; idx++)
  {
    if(ReconcileExecutionLegWithBrokerPosition(signal_params, idx))
      reconciled++;
  }
  return reconciled;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_RECONCILIATION_MQH_
