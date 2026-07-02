//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
// execution_price_resolver is provided via the trading_signals include cascade
#include "execution_leg_helpers.mqh"

bool g_debug_no_money_abort_pending = false;
const double EXECUTION_VOLUME_EPSILON = 0.0000001;

struct SignalOrderCloseCandidate
{
  int    leg_index;
  double projected_profit;

  SignalOrderCloseCandidate()
  {
    leg_index       = -1;
    projected_profit  = 0.0;
  }
};

double ResolveExecutionLegTrackedVolume(const ExecutionLegState &leg_state)
{
  if(leg_state.position_ticket > 0 && PositionSelectByTicket(leg_state.position_ticket))
  {
    double broker_volume = PositionGetDouble(POSITION_VOLUME);
    if(broker_volume > 0.0)
      return broker_volume;
  }

  return leg_state.lot_size;
}

void RegisterSignalRealizedClose(SignalParams &signal_params,
                                 const ExecutionLegState &leg_state,
                                 const double closed_volume,
                                 const double close_price)
{
  if(closed_volume <= 0.0 || close_price <= 0.0)
    return;

  double entry_price = leg_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = leg_state.entry_reference_price;
  if(entry_price <= 0.0)
    return;

  signal_params.realized_profit += ResolveProjectedExecutionLegProfitAtPrice(signal_params.signal_type,
                                                                          entry_price,
                                                                          close_price,
                                                                          closed_volume);
  signal_params.realized_closed_volume += closed_volume;
}

ulong ResolvePositionTicketFromDeal(const ulong deal_ticket)
{
  if(deal_ticket <= 0)
    return 0;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return 0;
  if(!HistoryDealSelect(deal_ticket))
    return 0;

  return (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
}

ulong FindOpenPositionForSignal(const SignalTypes direction,
                                const string comment)
{
  int total_positions = PositionsTotal();
  for(int i = 0; i < total_positions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;

    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(direction == BULLISH && pos_type != POSITION_TYPE_BUY)
      continue;
    if(direction == BEARISH && pos_type != POSITION_TYPE_SELL)
      continue;

    if(comment != "")
    {
      string pos_comment = PositionGetString(POSITION_COMMENT);
      if(pos_comment != comment)
        continue;
    }

    return position_ticket;
  }
  return 0;
}

bool ExecutionShouldActivateStopLeg(const SignalParams &signal_params,
                                 const ExecutionLegState &leg_state,
                                 const SignalTypes direction)
{
  double entry_side_price = ExecutionCurrentPriceForDirection(direction, true);

  double stop_trigger = leg_state.entry_reference_price;
  if(stop_trigger <= 0.0)
    return false;
  if(signal_params.entry_is_limit)
  {
    if(SignalUsesBreakoutLimitAnchoring(signal_params))
      return ShouldActivateBreakoutLimitEntry(direction, entry_side_price, stop_trigger);

    return IsLimitTriggerReached(direction, entry_side_price, stop_trigger);
  }
  // BUY STOP: Ask >= stop; SELL STOP: Bid <= stop
  if(direction == BULLISH) return entry_side_price >= stop_trigger;
  if(direction == BEARISH) return entry_side_price <= stop_trigger;
  return false;
}

bool ExecutionShouldActivateNextLegLimit(const SignalParams &signal_params,
                                      const ExecutionLegState &leg_state,
                                      const SignalTypes direction)
{
  double entry_side_price = ExecutionCurrentPriceForDirection(direction, true);
  double reference_price = ExecutionResolveLegReferencePrice(signal_params,
                                                          leg_state);

  // Deeper levels activate on the NEXT level price (averaging on adverse move).
  double next_trigger = leg_state.next_level_price;
  if(next_trigger <= 0.0)
    return false;
  if(reference_price > 0.0 &&
     !ExecutionHasMeaningfulPriceGap(reference_price,
                                next_trigger))
    return false;

  if(SignalUsesBreakoutLimitAnchoring(signal_params))
  {
    if(reference_price <= 0.0)
      reference_price = next_trigger;

    if(direction == BULLISH)
    {
      if(next_trigger <= reference_price)
        return entry_side_price <= next_trigger;
      return entry_side_price >= next_trigger;
    }

    if(direction == BEARISH)
    {
      if(next_trigger >= reference_price)
        return entry_side_price >= next_trigger;
      return entry_side_price <= next_trigger;
    }

    return false;
  }

  // Bullish: trigger when Ask <= next; Bearish: trigger when Bid >= next
  if(direction == BULLISH) return entry_side_price <= next_trigger;
  if(direction == BEARISH) return entry_side_price >= next_trigger;

  return false;
}

bool LimitSignalExpiredOnStructureChange(const SignalParams &signal_params)
{
  if(!signal_params.entry_is_limit)
    return false;

  if(ExecutionSignalHasExecutedLeg(signal_params))
    return false;

  StochasticMarketStructure entry_structure;
  if(!ResolveSignalStructureSnapshot(signal_params, entry_structure))
    return false;

  datetime entry_time = 0;
  if(!ResolveStructureSnapshotTimeForContext(signal_params.strategy_context,
                                             entry_structure,
                                             entry_time))
    return false;

  StochasticMarketStructure current_structure;
  if(!LoadContextStructureSnapshot(signal_params.strategy_context, current_structure))
    return false;

  datetime current_time = 0;
  if(!ResolveStructureSnapshotTimeForContext(signal_params.strategy_context,
                                             current_structure,
                                             current_time))
    return false;

  return (current_time > entry_time);
}

bool ExecuteExecutionLegTrade(SignalParams &signal_params,
                           ExecutionLegState &leg_state,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  string comment = ExecutionComposeLegComment(signal_params, leg_state);

  if(!leg_state.opens_position)
  {
    double fill_price = ExecutionCurrentPriceForDirection(direction, true);
    if(fill_price <= 0.0)
      fill_price = leg_state.entry_reference_price;
    if(fill_price <= 0.0)
      fill_price = ExecutionCurrentPriceForDirection(direction, true);

    leg_state.status            = EXECUTION_LEG_ACTIVE;
    leg_state.entry_price       = fill_price;
    leg_state.position_ticket   = 0;
    leg_state.position_comment  = comment;
    leg_state.last_action_time  = TimeCurrent();
    signal_params.execution_legs[leg_state.level_index] = leg_state;
    return true;
  }

  // Guardrails: spread/margin checks before sending
  string guard_reason = "";
  if(!ExecutionGuardrailsAllowOrder(normalized_volume, guard_reason))
  {
    ExecutionLogGuardrailBlock("GUARDRAIL_BLOCK", signal_params, leg_state, guard_reason);
    if(Debug_Stop_On_Negative_Equity) g_debug_no_money_abort_pending = true;
    return false;
  }

  bool sent = false;
  if(direction == BULLISH)
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!sent)
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    if(Debug_Stop_On_Negative_Equity)
    {
      if(retcode == TRADE_RETCODE_NO_MONEY)
        g_debug_no_money_abort_pending = true;
    }
    MarketStatusRegisterBrokerFailure("ORDER_SEND_FAILED", retcode, last_error, false);
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = ExecutionCurrentPriceForDirection(direction, true);

  leg_state.status = EXECUTION_LEG_ACTIVE;
  leg_state.entry_price = fill_price;
  ulong deal_ticket = (ulong)g_position.ResultDeal();
  leg_state.position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  if(leg_state.position_ticket == 0)
    leg_state.position_ticket = FindOpenPositionForSignal(direction, comment);
  leg_state.position_comment = comment;
  leg_state.last_action_time = TimeCurrent();

  signal_params.execution_legs[leg_state.level_index] = leg_state;
  return sent;
}

bool CloseExecutionLegBrokerPosition(ExecutionLegState &leg_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(leg_state.position_ticket <= 0)
    return true;

  if(!PositionSelectByTicket(leg_state.position_ticket))
    return true;

  if(!g_position.PositionClose(leg_state.position_ticket))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("POSITION_CLOSE_FAILED", retcode, last_error, true);
    return false;
  }

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = ExecutionCurrentPriceForDirection(direction, false);

  leg_state.position_ticket = 0;
  leg_state.lot_size = 0.0;
  return true;
}

bool CloseExecutionLegBrokerPositionVolume(ExecutionLegState &leg_state,
                                   const SignalTypes direction,
                                   const double requested_volume,
                                   double &close_price,
                                   double &closed_volume_out,
                                   bool &fully_closed_out)
{
  close_price = 0.0;
  closed_volume_out = 0.0;
  fully_closed_out = false;

  if(leg_state.position_ticket <= 0)
    return true;

  if(!PositionSelectByTicket(leg_state.position_ticket))
  {
    leg_state.position_ticket = 0;
    leg_state.lot_size = 0.0;
    fully_closed_out = true;
    return true;
  }

  double current_volume = PositionGetDouble(POSITION_VOLUME);
  if(current_volume <= 0.0)
  {
    leg_state.position_ticket = 0;
    leg_state.lot_size = 0.0;
    fully_closed_out = true;
    return true;
  }

  double target_volume = requested_volume;
  if(target_volume <= 0.0)
    target_volume = current_volume;

  target_volume = NormalizeVolumeForSymbol(_Symbol, target_volume);
  if(target_volume <= 0.0 || target_volume >= current_volume - EXECUTION_VOLUME_EPSILON)
  {
    bool close_all_result = CloseExecutionLegBrokerPosition(leg_state, direction, close_price);
    if(close_all_result)
    {
      closed_volume_out = current_volume;
      fully_closed_out = true;
    }
    return close_all_result;
  }

  if(!g_position.PositionClosePartial(leg_state.position_ticket, target_volume))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("POSITION_CLOSE_PARTIAL_FAILED", retcode, last_error, true);
    return false;
  }

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = ExecutionCurrentPriceForDirection(direction, false);

  closed_volume_out = target_volume;
  if(PositionSelectByTicket(leg_state.position_ticket))
  {
    double remaining_volume = PositionGetDouble(POSITION_VOLUME);
    if(remaining_volume <= EXECUTION_VOLUME_EPSILON)
    {
      leg_state.position_ticket = 0;
      leg_state.lot_size = 0.0;
      fully_closed_out = true;
    }
    else
    {
      leg_state.lot_size = remaining_volume;
      fully_closed_out = false;
    }
  }
  else
  {
    leg_state.position_ticket = 0;
    leg_state.lot_size = 0.0;
    fully_closed_out = true;
  }

  return true;
}

bool ResolveSignalTrailingPartialCloseCandidates(const SignalParams &signal_params,
                                                 SignalOrderCloseCandidate &candidates[])
{
  ArrayResize(candidates, 0);

  double current_close_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, false);
  if(current_close_price <= 0.0)
    return false;

  int total_levels = ArraySize(signal_params.execution_legs);
  for(int idx = 0; idx < total_levels; idx++)
  {
    ExecutionLegState state = signal_params.execution_legs[idx];
    if(!state.opens_position)
      continue;
    if(state.status != EXECUTION_LEG_ACTIVE)
      continue;
    if(state.position_ticket <= 0)
      continue;
    if(state.lot_size <= 0.0)
      continue;

    double entry_price = state.entry_price;
    if(entry_price <= 0.0)
      entry_price = state.entry_reference_price;
    if(entry_price <= 0.0)
      continue;

    SignalOrderCloseCandidate candidate;
    candidate.leg_index = idx;
    candidate.projected_profit = ResolveProjectedExecutionLegProfitAtPrice(signal_params.signal_type,
                                                                        entry_price,
                                                                        current_close_price,
                                                                        state.lot_size);

    AddElementToArray(candidates, candidate);
  }

  int total_candidates = ArraySize(candidates);
  for(int i = 0; i < total_candidates - 1; i++)
  {
    for(int j = 0; j < total_candidates - i - 1; j++)
    {
      if(candidates[j].projected_profit < candidates[j + 1].projected_profit)
      {
        SignalOrderCloseCandidate tmp = candidates[j];
        candidates[j] = candidates[j + 1];
        candidates[j + 1] = tmp;
      }
    }
  }

  return (ArraySize(candidates) > 0);
}

bool CloseSignalVolumeByExecutionPriority(SignalParams &signal_params,
                                     const double requested_volume,
                                     double &closed_volume_out)
{
  closed_volume_out = 0.0;

  if(requested_volume <= 0.0)
    return true;

  SignalOrderCloseCandidate candidates[];
  if(!ResolveSignalTrailingPartialCloseCandidates(signal_params, candidates))
    return false;

  double remaining_to_close = requested_volume;
  int total_candidates = ArraySize(candidates);
  for(int idx = 0; idx < total_candidates && remaining_to_close > EXECUTION_VOLUME_EPSILON; idx++)
  {
    int leg_index = candidates[idx].leg_index;
    if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
      continue;

    ExecutionLegState state = signal_params.execution_legs[leg_index];
    double tracked_volume = ResolveExecutionLegTrackedVolume(state);
    if(tracked_volume <= 0.0)
      continue;

    double volume_to_close = remaining_to_close;
    if(volume_to_close > tracked_volume)
      volume_to_close = tracked_volume;

    double close_price = 0.0;
    double closed_volume = 0.0;
    bool fully_closed = false;
    if(!CloseExecutionLegBrokerPositionVolume(state,
                                      signal_params.signal_type,
                                      volume_to_close,
                                      close_price,
                                      closed_volume,
                                      fully_closed))
    {
      return false;
    }

    if(closed_volume <= 0.0)
      continue;

    RegisterSignalRealizedClose(signal_params, state, closed_volume, close_price);
    if(fully_closed)
      state.status = EXECUTION_LEG_COMPLETED;
    else
      state.status = EXECUTION_LEG_ACTIVE;

    signal_params.execution_legs[leg_index] = state;
    remaining_to_close -= closed_volume;
    closed_volume_out += closed_volume;
  }

  RefreshSignalExposureState(signal_params);
  return true;
}

void CloseAllExecutionLegs(SignalParams &signal_params,
                        const double point_size)
{
  bool result = false;
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_levels; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    double tracked_volume = ResolveExecutionLegTrackedVolume(state);
    double close_price = 0.0;
    result = CloseExecutionLegBrokerPosition(state, direction, close_price);
    if(result)
    {
      RegisterSignalRealizedClose(signal_params, state, tracked_volume, close_price);
      state.status = EXECUTION_LEG_COMPLETED;
    }
    ExecutionLogEvent("LEVEL_CLOSE_ALL", signal_params, state);
    signal_params.execution_legs[i] = state;
  }

  signal_params.remaining_open_volume = 0.0;

  return;
}

int GetActivePositionsCount(const SignalTypes direction)
{
  int count = 0;
  int total_positions = PositionsTotal();

  for(int i = 0; i < total_positions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;

    if(!PositionSelectByTicket(position_ticket))
      continue;

    // Validar magic number
    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;

    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    if(direction == BULLISH && pos_type == POSITION_TYPE_BUY)
      count++;
    else if(direction == BEARISH && pos_type == POSITION_TYPE_SELL)
      count++;
  }

  return count;
}

bool IsExecutionSignalComplete(const SignalParams &signal_params)
{
  if(!signal_params.execution_initialized)
    return false;

  int total_levels = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_levels; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(state.status == EXECUTION_LEG_WAITING ||
       state.status == EXECUTION_LEG_PENDING ||
       state.status == EXECUTION_LEG_ACTIVE)
      return false;
  }

  int attached_positions = 0;
  for(int i = 0; i < total_levels; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(state.position_ticket > 0 && PositionSelectByTicket(state.position_ticket))
    {
      long position_magic = PositionGetInteger(POSITION_MAGIC);
      string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(position_magic == g_magic_number && position_symbol == _Symbol)
        attached_positions++;
    }
  }

  return (attached_positions == 0);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
