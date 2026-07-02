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
    expected_comment = ExecutionComposeLegComment(signal_params, leg_state);

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
  BrokerPositionSnapshot snapshot;
  if(FindBrokerPositionForExecutionLeg(signal_params, leg_state, snapshot))
  {
    ApplyBrokerPositionSnapshotToExecutionLeg(leg_state, snapshot);
    signal_params.execution_legs[leg_index] = leg_state;
    return true;
  }

  if(had_broker_ticket)
  {
    leg_state.position_ticket  = 0;
    leg_state.position_comment = "";
    leg_state.lot_size         = 0.0;
    leg_state.status           = EXECUTION_LEG_COMPLETED;
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
