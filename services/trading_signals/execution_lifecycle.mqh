//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
// execution_price_resolver is provided via the trading_signals include cascade
#include "execution_leg_helpers.mqh"

bool g_debug_no_money_abort_pending = false;
const double EXECUTION_VOLUME_EPSILON = 0.0000001;
const int    PARTIAL_TP_LEVELS_TOTAL = 3;
const double PARTIAL_TP_LEVEL_1_R = 1.0;
const double PARTIAL_TP_LEVEL_2_R = 2.0;
const double PARTIAL_TP_LEVEL_3_R = 3.0;
const double PARTIAL_TP_VOLUME_1 = 0.33;
const double PARTIAL_TP_VOLUME_2 = 0.33;
const double PARTIAL_TP_VOLUME_3 = 0.34;

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

bool PartialTPEnabled()
{
  return (Partial_TP_Mode == PARTIAL_TP_R_MULTIPLES);
}

double PartialTPLevelR(const int level_index)
{
  if(level_index == 0)
    return PARTIAL_TP_LEVEL_1_R;
  if(level_index == 1)
    return PARTIAL_TP_LEVEL_2_R;
  return PARTIAL_TP_LEVEL_3_R;
}

double PartialTPVolumeFraction(const int level_index)
{
  if(level_index == 0)
    return PARTIAL_TP_VOLUME_1;
  if(level_index == 1)
    return PARTIAL_TP_VOLUME_2;
  return PARTIAL_TP_VOLUME_3;
}

bool PartialTPLevelConfirmed(const SignalParams &signal_params,
                             const int level_index)
{
  if(level_index == 0)
    return signal_params.partial_tp1_confirmed;
  if(level_index == 1)
    return signal_params.partial_tp2_confirmed;
  return signal_params.partial_tp3_confirmed;
}

void MarkPartialTPLevelConfirmed(SignalParams &signal_params,
                                 const int level_index,
                                 const double closed_volume,
                                 const double close_price)
{
  datetime close_time = TimeCurrent();
  if(level_index == 0)
  {
    signal_params.partial_tp1_confirmed = true;
    signal_params.partial_tp1_closed_volume += closed_volume;
    signal_params.partial_tp1_close_price = close_price;
    signal_params.partial_tp1_close_time = close_time;
    return;
  }
  if(level_index == 1)
  {
    signal_params.partial_tp2_confirmed = true;
    signal_params.partial_tp2_closed_volume += closed_volume;
    signal_params.partial_tp2_close_price = close_price;
    signal_params.partial_tp2_close_time = close_time;
    return;
  }

  signal_params.partial_tp3_confirmed = true;
  signal_params.partial_tp3_closed_volume += closed_volume;
  signal_params.partial_tp3_close_price = close_price;
  signal_params.partial_tp3_close_time = close_time;
}

double ResolvePartialTPPrice(const SignalParams &signal_params,
                             const ExecutionLegState &leg_state,
                             const int level_index)
{
  double entry_price = leg_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = leg_state.entry_reference_price;
  if(entry_price <= 0.0 || signal_params.raw_stop_anchor_price <= 0.0)
    return 0.0;

  double risk_distance = MathAbs(entry_price - signal_params.raw_stop_anchor_price);
  if(risk_distance <= 0.0)
    return 0.0;

  double level_r = PartialTPLevelR(level_index);
  if(signal_params.signal_type == BULLISH)
    return entry_price + risk_distance * level_r;
  if(signal_params.signal_type == BEARISH)
    return entry_price - risk_distance * level_r;
  return 0.0;
}

bool PartialTPPriceTriggered(const SignalParams &signal_params,
                             const double target_price)
{
  if(target_price <= 0.0)
    return false;

  double exit_side_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, false);
  if(exit_side_price <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return exit_side_price >= target_price;
  if(signal_params.signal_type == BEARISH)
    return exit_side_price <= target_price;
  return false;
}

bool ResolvePartialTPCloseVolume(const double current_volume,
                                 const double initial_volume,
                                 const int level_index,
                                 double &close_volume_out,
                                 string &reason_out)
{
  close_volume_out = 0.0;
  reason_out = "";
  if(current_volume <= 0.0)
  {
    reason_out = "current_volume_invalid";
    return false;
  }

  bool final_level = (level_index == PARTIAL_TP_LEVELS_TOTAL - 1);
  if(final_level)
  {
    close_volume_out = current_volume;
    return true;
  }

  double base_volume = initial_volume;
  if(base_volume <= 0.0)
    base_volume = current_volume;

  double requested_volume = base_volume * PartialTPVolumeFraction(level_index);
  double normalized_volume = NormalizeVolumeDownForSymbol(_Symbol, requested_volume);
  if(normalized_volume <= 0.0)
  {
    reason_out = "partial_volume_below_min";
    return false;
  }

  double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double remaining_volume = current_volume - normalized_volume;
  if(min_vol > 0.0 && remaining_volume > EXECUTION_VOLUME_EPSILON && remaining_volume < min_vol)
  {
    double adjusted_volume = NormalizeVolumeDownForSymbol(_Symbol, current_volume - min_vol);
    if(adjusted_volume <= 0.0)
    {
      reason_out = "partial_residual_below_min";
      return false;
    }
    normalized_volume = adjusted_volume;
    remaining_volume = current_volume - normalized_volume;
  }

  if(normalized_volume <= 0.0 || normalized_volume >= current_volume - EXECUTION_VOLUME_EPSILON)
  {
    reason_out = "partial_would_close_all";
    return false;
  }

  close_volume_out = normalized_volume;
  return true;
}

struct ExecutionLegTradeAdmissionContext
{
  bool                       allowed;
  string                     comment;
  double                     point_size;
  double                     normalized_volume;
  BrokerExecutionSnapshot    broker_snapshot;
  BrokerExecutionEligibility eligibility;

  ExecutionLegTradeAdmissionContext()
  {
    allowed           = false;
    comment           = "";
    point_size        = 0.0;
    normalized_volume = 0.0;
    broker_snapshot   = BrokerExecutionSnapshot();
    eligibility       = BrokerExecutionEligibility();
  }

  ExecutionLegTradeAdmissionContext(const ExecutionLegTradeAdmissionContext &context)
  {
    allowed           = context.allowed;
    comment           = context.comment;
    point_size        = context.point_size;
    normalized_volume = context.normalized_volume;
    broker_snapshot   = context.broker_snapshot;
    eligibility       = context.eligibility;
  }
};

double ResolveExecutionLegTrackedVolume(const ExecutionLegState &leg_state)
{
  if(leg_state.position_ticket > 0 && PositionSelectByTicket(leg_state.position_ticket))
  {
    if(!SelectedBrokerPositionMatchesExecutionScope(NO_SIGNAL))
      return leg_state.lot_size;

    double broker_volume = PositionGetDouble(POSITION_VOLUME);
    if(broker_volume > 0.0)
      return broker_volume;
  }

  return leg_state.lot_size;
}

void RefreshSignalExposureState(SignalParams &signal_params)
{
  double remaining_volume = 0.0;
  int total_legs = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState leg_state = signal_params.execution_legs[i];
    if(!leg_state.opens_position)
      continue;
    if(leg_state.status != EXECUTION_LEG_ACTIVE)
      continue;

    double tracked_volume = ResolveExecutionLegTrackedVolume(leg_state);
    if(tracked_volume > 0.0)
      remaining_volume += tracked_volume;
  }

  signal_params.remaining_open_volume = remaining_volume;
}

void RegisterSignalRealizedClose(SignalParams &signal_params,
                                 const ExecutionLegState &leg_state,
                                 const double closed_volume,
                                 const double close_price)
{
  if(closed_volume <= 0.0 || close_price <= 0.0)
    return;
  if(!leg_state.opens_position || leg_state.position_ticket <= 0)
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
  signal_params.broker_close_confirmed = true;
  signal_params.broker_close_source = "ea_close";
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

bool PrepareExecutionLegTradeAdmission(SignalParams &signal_params,
                                       ExecutionLegState &leg_state,
                                       const double point_size,
                                       const double normalized_volume,
                                       ExecutionLegTradeAdmissionContext &context_out)
{
  context_out = ExecutionLegTradeAdmissionContext();
  context_out.comment = ExecutionComposeLegComment(signal_params, leg_state);
  context_out.point_size = point_size;
  context_out.normalized_volume = normalized_volume;

  if(!EvaluateLocalExecutionLegEligibility(signal_params,
                                           leg_state,
                                           normalized_volume,
                                           context_out.broker_snapshot,
                                           context_out.eligibility))
  {
    signal_params.admission_status        = EXECUTION_ADMISSION_BLOCKED;
    signal_params.admission_block_source  = context_out.eligibility.block_source;
    signal_params.admission_block_reason  = context_out.eligibility.block_reason;
    signal_params.admission_updated_time  = TimeCurrent();
    signal_params.admission_spread_points = context_out.broker_snapshot.spread_points;
    signal_params.admission_max_spread    = Max_Spread;
    signal_params.admission_market_status = context_out.broker_snapshot.market_status;

    string block_reason = context_out.eligibility.block_source;
    if(context_out.eligibility.block_reason != "")
      block_reason = block_reason + ":" + context_out.eligibility.block_reason;
    ExecutionLogGuardrailBlock("LOCAL_EXECUTION_BLOCK", signal_params, leg_state, block_reason);
    if(Debug_Stop_On_Negative_Equity && context_out.eligibility.block_source == "margin")
      g_debug_no_money_abort_pending = true;
    return false;
  }

  context_out.allowed = true;
  signal_params.admission_status        = EXECUTION_ADMISSION_ALLOWED;
  signal_params.admission_block_source  = "";
  signal_params.admission_block_reason  = "";
  signal_params.admission_updated_time  = TimeCurrent();
  signal_params.admission_spread_points = context_out.broker_snapshot.spread_points;
  signal_params.admission_max_spread    = Max_Spread;
  signal_params.admission_market_status = context_out.broker_snapshot.market_status;
  return true;
}

bool ApplyExecutionLegTradeAdmission(SignalParams &signal_params,
                                     ExecutionLegState &leg_state,
                                     const ExecutionLegTradeAdmissionContext &context)
{
  if(!context.allowed)
    return false;

  SignalTypes direction = signal_params.signal_type;

  if(!leg_state.opens_position)
  {
    signal_params.admission_status = EXECUTION_ADMISSION_FILLED;
    signal_params.admission_updated_time = TimeCurrent();
    double fill_price = ExecutionCurrentPriceForDirection(direction, true);
    if(fill_price <= 0.0)
      fill_price = leg_state.entry_reference_price;
    if(fill_price <= 0.0)
      fill_price = ExecutionCurrentPriceForDirection(direction, true);

    leg_state.status            = EXECUTION_LEG_ACTIVE;
    leg_state.entry_price       = fill_price;
    leg_state.position_ticket   = 0;
    leg_state.position_comment  = context.comment;
    leg_state.last_action_time  = TimeCurrent();
    signal_params.execution_legs[leg_state.level_index] = leg_state;
    return true;
  }

  double order_volume = context.broker_snapshot.normalized_volume;
  signal_params.admission_status = EXECUTION_ADMISSION_SENT;
  signal_params.admission_updated_time = TimeCurrent();

  bool sent = false;
  if(direction == BULLISH)
    sent = g_position.Buy(order_volume, _Symbol, 0.0, 0.0, 0.0, context.comment);
  else
    sent = g_position.Sell(order_volume, _Symbol, 0.0, 0.0, 0.0, context.comment);

  if(!sent)
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    string send_reason = StringFormat("retcode=%I64u|error=%d",
                                      retcode,
                                      last_error);
    signal_params.admission_status       = EXECUTION_ADMISSION_SEND_FAILED;
    signal_params.admission_block_source = "broker_send";
    signal_params.admission_block_reason = send_reason;
    signal_params.admission_updated_time = TimeCurrent();
    ExecutionLogGuardrailBlock("BROKER_SEND_FAILED", signal_params, leg_state, send_reason);
    if(Debug_Stop_On_Negative_Equity)
    {
      if(retcode == TRADE_RETCODE_NO_MONEY)
        g_debug_no_money_abort_pending = true;
    }
    MarketStatusRegisterBrokerFailure("BROKER_SEND_FAILED", retcode, last_error, false);
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = ExecutionCurrentPriceForDirection(direction, true);

  leg_state.status = EXECUTION_LEG_ACTIVE;
  leg_state.entry_price = fill_price;
  ulong deal_ticket = (ulong)g_position.ResultDeal();
  leg_state.position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  leg_state.position_comment = context.comment;
  leg_state.last_action_time = TimeCurrent();

  signal_params.execution_legs[leg_state.level_index] = leg_state;
  signal_params.admission_status = EXECUTION_ADMISSION_FILLED;
  signal_params.admission_block_source = "";
  signal_params.admission_block_reason = "";
  signal_params.admission_updated_time = TimeCurrent();
  BrokerPositionSnapshot sent_snapshot;
  if(FindBrokerPositionForExecutionLeg(signal_params, leg_state, sent_snapshot))
  {
    ApplyBrokerPositionSnapshotToExecutionLeg(leg_state, sent_snapshot);
    signal_params.broker_entry_confirmed = true;
    signal_params.execution_legs[leg_state.level_index] = leg_state;
  }
  else
  {
    ExecutionLogGuardrailBlock("BROKER_RECONCILE_AMBIGUOUS",
                               signal_params,
                               leg_state,
                               "sent_order_position_not_found");
  }
  return sent;
}

bool ExecuteExecutionLegTrade(SignalParams &signal_params,
                              ExecutionLegState &leg_state,
                              const double point_size,
                              const double normalized_volume)
{
  ExecutionLegTradeAdmissionContext context;
  if(!PrepareExecutionLegTradeAdmission(signal_params,
                                        leg_state,
                                        point_size,
                                        normalized_volume,
                                        context))
    return false;

  return ApplyExecutionLegTradeAdmission(signal_params,
                                         leg_state,
                                         context);
}

bool CloseExecutionLegBrokerPosition(ExecutionLegState &leg_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(leg_state.position_ticket <= 0)
    return true;

  if(!PositionSelectByTicket(leg_state.position_ticket))
  {
    leg_state.position_ticket = 0;
    leg_state.lot_size = 0.0;
    return true;
  }

  if(!SelectedBrokerPositionMatchesExecutionScope(direction))
  {
    if(Enable_Logs)
      PrintFormat("CloseExecutionLegBrokerPosition scope mismatch | ticket=%I64u",
                  leg_state.position_ticket);
    return false;
  }

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

  if(!SelectedBrokerPositionMatchesExecutionScope(direction))
  {
    if(Enable_Logs)
      PrintFormat("CloseExecutionLegBrokerPositionVolume scope mismatch | ticket=%I64u",
                  leg_state.position_ticket);
    return false;
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
  if(PositionSelectByTicket(leg_state.position_ticket) &&
     SelectedBrokerPositionMatchesExecutionScope(direction))
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

bool UpdateDeterministicPartialTPLifecycle(SignalParams &signal_params,
                                           const int leg_index)
{
  if(!PartialTPEnabled())
    return false;
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return false;

  ExecutionLegState state = signal_params.execution_legs[leg_index];
  if(!state.opens_position ||
     state.status != EXECUTION_LEG_ACTIVE ||
     state.position_ticket <= 0)
    return false;

  if(!PositionSelectByTicket(state.position_ticket) ||
     !SelectedBrokerPositionMatchesExecutionScope(signal_params.signal_type))
    return false;

  double current_volume = PositionGetDouble(POSITION_VOLUME);
  if(current_volume <= 0.0)
    return false;

  double initial_volume = state.initial_lot_size;
  if(initial_volume <= 0.0)
    initial_volume = current_volume;

  for(int level_index = 0; level_index < PARTIAL_TP_LEVELS_TOTAL; level_index++)
  {
    if(PartialTPLevelConfirmed(signal_params, level_index))
      continue;

    double target_price = ResolvePartialTPPrice(signal_params, state, level_index);
    if(!PartialTPPriceTriggered(signal_params, target_price))
      return false;

    double close_volume = 0.0;
    string volume_reason = "";
    if(!ResolvePartialTPCloseVolume(current_volume,
                                    initial_volume,
                                    level_index,
                                    close_volume,
                                    volume_reason))
    {
      ExecutionLogGuardrailBlock("PARTIAL_TP_SKIPPED",
                                 signal_params,
                                 state,
                                 StringFormat("level=%d|reason=%s|current_volume=%.4f|initial_volume=%.4f",
                                              level_index + 1,
                                              volume_reason,
                                              current_volume,
                                              initial_volume));
      return false;
    }

    ExecutionLegState state_before_close = state;
    double close_price = 0.0;
    double closed_volume = 0.0;
    bool fully_closed = false;
    if(!CloseExecutionLegBrokerPositionVolume(state,
                                              signal_params.signal_type,
                                              close_volume,
                                              close_price,
                                              closed_volume,
                                              fully_closed))
    {
      ExecutionLogGuardrailBlock("PARTIAL_TP_CLOSE_FAILED",
                                 signal_params,
                                 state_before_close,
                                 StringFormat("level=%d|requested_volume=%.4f",
                                              level_index + 1,
                                              close_volume));
      return false;
    }

    if(closed_volume <= 0.0)
      return false;

    RegisterSignalRealizedClose(signal_params,
                                state_before_close,
                                closed_volume,
                                close_price);
    MarkPartialTPLevelConfirmed(signal_params,
                                level_index,
                                closed_volume,
                                close_price);

    if(fully_closed)
      state.status = EXECUTION_LEG_COMPLETED;
    else
      state.status = EXECUTION_LEG_ACTIVE;

    signal_params.execution_legs[leg_index] = state;
    RefreshSignalExposureState(signal_params);

    string event_label = StringFormat("PARTIAL_TP%d", level_index + 1);
    ExecutionLogEvent(event_label, signal_params, signal_params.execution_legs[leg_index]);

    if(fully_closed || level_index == PARTIAL_TP_LEVELS_TOTAL - 1)
    {
      signal_params.deterministic_stats_terminal_reason = "TP";
      int source_attempt_count = 0;
      bool newly_consumed = RegisterDeterministicSourceConsumedTp(signal_params,
                                                                 source_attempt_count);
      if(newly_consumed)
      {
        ExecutionLogDeterministicSourceConsumed(signal_params,
                                                signal_params.execution_legs[leg_index],
                                                source_attempt_count,
                                                event_label);
      }
      signal_params.signal_state = CLOSED;
      return true;
    }

    return false;
  }

  return false;
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
    ExecutionLegState state_before_close = state;
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

    RegisterSignalRealizedClose(signal_params, state_before_close, closed_volume, close_price);
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
    ExecutionLegState state_before_close = state;
    double tracked_volume = ResolveExecutionLegTrackedVolume(state);
    double close_price = 0.0;
    result = CloseExecutionLegBrokerPosition(state, direction, close_price);
    if(result)
    {
      RegisterSignalRealizedClose(signal_params, state_before_close, tracked_volume, close_price);
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

    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_symbol != _Symbol)
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
      if(SelectedBrokerPositionMatchesExecutionScope(signal_params.signal_type))
        attached_positions++;
    }
  }

  return (attached_positions == 0);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LIFECYCLE_MQH_
