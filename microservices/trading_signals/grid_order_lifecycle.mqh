//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... lifecycle    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
// grid_price_resolver is provided via the trading_signals include cascade
#include "grid_order_helpers.mqh"

bool g_debug_no_money_abort_pending = false;

bool GridRefreshBrokerConstraintsForAction(const string context)
{
  if(RefreshBrokerConstraintsForAction(_Symbol,
                                       g_symbol_constraints,
                                       context))
    return true;

  MarketStatusRegisterExecutionError(context + "_CONSTRAINTS_REFRESH_FAILED",
                                     "symbol_specs_unavailable",
                                     0,
                                     GetLastError());
  return false;
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
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
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

bool GridShouldActivateStopOrder(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);

  double stop_trigger = order_state.entry_reference_price;
  if(stop_trigger <= 0.0)
    return false;
  // BUY STOP: Ask >= stop; SELL STOP: Bid <= stop
  if(direction == BULLISH) return entry_side_price >= stop_trigger;
  if(direction == BEARISH) return entry_side_price <= stop_trigger;
  return false;

  return false;
}

bool GridShouldActivateNextLevelLimit(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const SignalTypes direction,
                                    const double point_size)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);

  // Deeper levels activate on the NEXT level price (averaging on adverse move).
  double next_trigger = order_state.next_level_price;
  if(next_trigger <= 0.0)
    return false;
  // Bullish: trigger when Ask <= next; Bearish: trigger when Bid >= next
  if(direction == BULLISH) return entry_side_price <= next_trigger;
  if(direction == BEARISH) return entry_side_price >= next_trigger;

  return false;
}

bool ShouldSwitchToTrailingTP(const SignalTypes direction,
                              const GridOrderState &order_state,
                              const double current_price)
{
  if(order_state.take_profit_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return current_price >= order_state.take_profit_price;
  if(direction == BEARISH)
    return current_price <= order_state.take_profit_price;
  return false;
}

bool GridShouldActivateTrailing(SignalParams &signal_params,
                                const GridOrderState &order_state,
                                const double current_price)
{
  if(PandoraStrategyEnabled())
    return false;

  SignalTypes direction = signal_params.signal_type;
  if(Grid_Trailing_Execution_Mode != TRAILING_EXECUTION_AGGRESIVE)
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  double indicator_price = 0.0;
  if(!GridResolveTrailingStrategyPrice(signal_params, indicator_price))
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  double reference_price = order_state.take_profit_price;
  if(reference_price <= 0.0)
    return ShouldSwitchToTrailingTP(direction, order_state, current_price);

  if(direction == BULLISH)
    return indicator_price >= reference_price;
  if(direction == BEARISH)
    return indicator_price <= reference_price;
  return false;
}

bool GridBrokerStopPriceMatches(const double current_price,
                                const double target_price,
                                const double tolerance)
{
  if(target_price <= 0.0)
    return (current_price <= tolerance);
  return MathAbs(current_price - target_price) <= tolerance;
}

bool GridSyncPandoraBrokerStops(SignalParams &signal_params,
                                GridOrderState &order_state,
                                const string context,
                                const bool throttle)
{
  if(!IsPandoraSignal(signal_params))
    return true;

  if(!Pandora_Box_Set_Broker_SLTP)
    return true;

  if(order_state.position_ticket <= 0)
    return true;

  datetime now_time = TimeCurrent();
  if(throttle &&
     signal_params.pandora_broker_stop_sync_time > 0 &&
     now_time - signal_params.pandora_broker_stop_sync_time < 1)
    return true;

  if(throttle)
    signal_params.pandora_broker_stop_sync_time = now_time;

  GridRefreshBrokerConstraintsForAction(context + "_CONSTRAINTS");

  if(!PositionSelectByTicket(order_state.position_ticket))
  {
    signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_FAILED;
    MarketStatusRegisterExecutionError(context + "_FAILED", "position_not_found", 0, GetLastError());
    return false;
  }

  double target_sl = 0.0;
  double target_tp = 0.0;
  bool all_exact = false;
  string detail = "";
  if(!PandoraResolveBrokerSafeStops(signal_params,
                                    order_state,
                                    target_sl,
                                    target_tp,
                                    all_exact,
                                    detail))
  {
    if(detail == "")
      detail = "resolve_failed";
    MarketStatusRegisterExecutionError(context + "_UNAVAILABLE", detail, 0, GetLastError());
    return false;
  }

  double tolerance = PandoraResolveBrokerTickSize() * 0.5;
  if(tolerance <= 0.0)
    tolerance = PandoraResolvePointSizeSafe() * 0.5;

  double current_sl = PositionGetDouble(POSITION_SL);
  double current_tp = PositionGetDouble(POSITION_TP);
  bool sl_matches = GridBrokerStopPriceMatches(current_sl, target_sl, tolerance);
  bool tp_matches = GridBrokerStopPriceMatches(current_tp, target_tp, tolerance);
  if(sl_matches && tp_matches)
  {
    PandoraSetBrokerStopSyncResolvedStatus(signal_params, all_exact);
    return true;
  }

  ResetLastError();
  if(!g_position.PositionModify(order_state.position_ticket, target_sl, target_tp))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_FAILED;
    MarketStatusRegisterBrokerFailure(context + "_FAILED", retcode, last_error, true);
    return false;
  }

  signal_params.pandora_broker_stop_sync_time = now_time;
  PandoraSetBrokerStopSyncResolvedStatus(signal_params, all_exact);
  MarketStatusClearExecutionError(context + "_OK");

  return true;
}

bool GridRefreshPandoraStopsAfterFill(SignalParams &signal_params,
                                      GridOrderState &order_state)
{
  return GridSyncPandoraBrokerStops(signal_params,
                                    order_state,
                                    "PANDORA_INITIAL_SLTP_SYNC",
                                    false);
}

ENUM_ORDER_TYPE GridBrokerOrderTypeForSignal(const SignalTypes direction)
{
  if(direction == BULLISH)
    return ORDER_TYPE_BUY;
  return ORDER_TYPE_SELL;
}

ENUM_ORDER_TYPE_FILLING GridResolveDiagnosticFillingType()
{
  ENUM_SYMBOL_TRADE_EXECUTION execution_mode =
    (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
  long filling_mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

  if(execution_mode == SYMBOL_TRADE_EXECUTION_MARKET)
  {
    if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
    if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
  }

  return ORDER_FILLING_FOK;
}

bool GridBuildBrokerDealCheckRequest(const SignalTypes direction,
                                     const double normalized_volume,
                                     const double sl_price,
                                     const double tp_price,
                                     const string comment,
                                     MqlTradeRequest &request)
{
  ZeroMemory(request);

  if(normalized_volume <= 0.0)
    return false;

  request.action       = TRADE_ACTION_DEAL;
  request.symbol       = _Symbol;
  request.magic        = (ulong)g_magic_number;
  request.volume       = normalized_volume;
  request.type         = GridBrokerOrderTypeForSignal(direction);
  request.price        = GridCurrentPriceForDirection(direction, true);
  request.sl           = sl_price;
  request.tp           = tp_price;
  request.deviation    = 10;
  request.type_filling = GridResolveDiagnosticFillingType();
  request.type_time    = ORDER_TIME_GTC;
  request.comment      = comment;

  return (request.price > 0.0);
}

void GridRunBrokerDealOrderCheck(const SignalTypes direction,
                                 const double normalized_volume,
                                 const double sl_price,
                                 const double tp_price,
                                 const string comment,
                                 MqlTradeCheckResult &check_result,
                                 bool &check_available,
                                 bool &check_sent,
                                 int &check_error)
{
  ZeroMemory(check_result);
  check_available = false;
  check_sent = false;
  check_error = 0;

  MqlTradeRequest check_request;
  if(!GridBuildBrokerDealCheckRequest(direction,
                                      normalized_volume,
                                      sl_price,
                                      tp_price,
                                      comment,
                                      check_request))
    return;

  check_available = true;
  ResetLastError();
  check_sent = OrderCheck(check_request, check_result);
  check_error = GetLastError();
}

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  string comment = GridComposeLevelComment(signal_params, order_state);
  bool pandora_signal = IsPandoraSignal(signal_params);

  if(!order_state.opens_position)
  {
    double fill_price = GridCurrentPriceForDirection(direction, true);
    if(fill_price <= 0.0)
      fill_price = order_state.entry_reference_price;
    if(fill_price <= 0.0)
      fill_price = GridCurrentPriceForDirection(direction, true);

    order_state.status            = GRID_ORDER_ACTIVE;
    order_state.entry_price       = fill_price;
    order_state.position_ticket   = 0;
    order_state.position_comment  = comment;
    order_state.last_action_time  = TimeCurrent();
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  if(pandora_signal && PandoraBrokerAttemptAlreadyFinished(signal_params))
  {
    if(signal_params.pandora_broker_execution_status != PANDORA_BROKER_EXECUTED &&
       order_state.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
    {
      PandoraEnsureLocalEntryActive(signal_params, order_state, comment);
      signal_params.grid_orders[order_state.level_index] = order_state;
    }
    return true;
  }

  // Guardrails: spread/margin checks before sending
  string guard_reason = "";
  if(!GridGuardrailsAllowOrder(normalized_volume, guard_reason))
  {
    GridLogGuardrailBlock("GUARDRAIL_BLOCK", signal_params, order_state, guard_reason);
    if(Debug_Stop_On_Negative_Equity) g_debug_no_money_abort_pending = true;
    if(pandora_signal)
    {
      if(!PandoraSpreadWithinBrokerRealisticRange() ||
         !PandoraAdmitBrokerRealisticLocalEntry(signal_params, order_state, comment))
      {
        signal_params.grid_orders[order_state.level_index] = order_state;
        return true;
      }

      MqlTradeCheckResult empty_check_result;
      ZeroMemory(empty_check_result);
      if(PandoraBrokerRetryBudgetAvailable(signal_params) &&
         PandoraBrokerFailureRetryable("GUARDRAIL_BLOCK",
                                       guard_reason,
                                       0,
                                       0,
                                       empty_check_result,
                                       false,
                                       false))
      {
        PandoraMarkBrokerRetryPending(signal_params,
                                      order_state,
                                      "GUARDRAIL_BLOCK",
                                      guard_reason,
                                      0,
                                      0,
                                      comment);
      }
      else
      {
        PandoraMarkBrokerBlocked(signal_params,
                                 order_state,
                                 "GUARDRAIL_BLOCK",
                                 guard_reason,
                                 comment);
      }
      signal_params.grid_orders[order_state.level_index] = order_state;
      return true;
    }
    return false;
  }

  if(pandora_signal &&
     !PandoraAdmitBrokerRealisticLocalEntry(signal_params, order_state, comment))
  {
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  bool sent = false;
  double sl_price = 0.0;
  double tp_price = 0.0;
  if(pandora_signal)
    GridRefreshBrokerConstraintsForAction("PANDORA_BROKER_SEND");

  if(pandora_signal && Pandora_Box_Set_Broker_SLTP)
  {
    GridOrderState broker_seed_state = order_state;
    if(broker_seed_state.entry_price <= 0.0)
    {
      broker_seed_state.entry_price = GridCurrentPriceForDirection(direction, true);
      if(broker_seed_state.entry_price <= 0.0)
        broker_seed_state.entry_price = order_state.entry_reference_price;
    }
    bool all_exact = false;
    string detail = "";
    if(!PandoraResolveBrokerSafeStops(signal_params,
                                      broker_seed_state,
                                      sl_price,
                                      tp_price,
                                      all_exact,
                                      detail))
    {
      if(detail == "")
        detail = "pre_send";
      MarketStatusRegisterExecutionError("PANDORA_BROKER_STOPS_UNAVAILABLE", detail, 0, GetLastError());
      sl_price = 0.0;
      tp_price = 0.0;
    }
  }

  MqlTradeCheckResult broker_check_result;
  ZeroMemory(broker_check_result);
  bool broker_check_available = false;
  bool broker_check_sent = false;
  int broker_check_error = 0;
  if(pandora_signal)
  {
    GridRunBrokerDealOrderCheck(direction,
                                normalized_volume,
                                sl_price,
                                tp_price,
                                comment,
                                broker_check_result,
                                broker_check_available,
                                broker_check_sent,
                                broker_check_error);
  }

  if(direction == BULLISH)
  {
    ResetLastError();
    if(pandora_signal)
      PandoraRecordBrokerSendAttempt(signal_params);
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, sl_price, tp_price, comment);
  }
  else
  {
    ResetLastError();
    if(pandora_signal)
      PandoraRecordBrokerSendAttempt(signal_params);
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, sl_price, tp_price, comment);
  }

  ulong retcode = g_position.ResultRetcode();
  int last_error = GetLastError();
  if(!sent)
  {
    MqlTradeRequest broker_request;
    ZeroMemory(broker_request);
    g_position.Request(broker_request);
    GridLogBrokerSendDiagnostic("ORDER_SEND_DIAGNOSTIC",
                                signal_params,
                                order_state,
                                broker_request,
                                broker_check_result,
                                broker_check_available,
                                broker_check_sent,
                                broker_check_error,
                                retcode,
                                last_error,
                                g_position.ResultRetcodeDescription(),
                                g_position.ResultComment());

    if(Debug_Stop_On_Negative_Equity)
    {
      if(retcode == TRADE_RETCODE_NO_MONEY)
        g_debug_no_money_abort_pending = true;
    }
    MarketStatusRegisterBrokerFailure("ORDER_SEND_FAILED", retcode, last_error, false);
    if(pandora_signal)
    {
      string reject_detail = PandoraBrokerRejectSummary("ORDER_SEND_FAILED", "", retcode, last_error);
      if(!PandoraBrokerRetcodeAllowsLocalSimulation(retcode))
      {
        PandoraCompleteNonOperableBrokerRejection(signal_params,
                                                  order_state,
                                                  "ORDER_SEND_FAILED",
                                                  reject_detail,
                                                  retcode,
                                                  last_error,
                                                  comment);
      }
      else if(PandoraBrokerRetryBudgetAvailable(signal_params) &&
         PandoraBrokerFailureRetryable("ORDER_SEND_FAILED",
                                       reject_detail,
                                       retcode,
                                       last_error,
                                       broker_check_result,
                                       broker_check_available,
                                       broker_check_sent))
      {
        PandoraMarkBrokerRetryPending(signal_params,
                                      order_state,
                                      "ORDER_SEND_FAILED",
                                      reject_detail,
                                      retcode,
                                      last_error,
                                      comment);
      }
      else
      {
        PandoraMarkBrokerRejected(signal_params,
                                  order_state,
                                  "ORDER_SEND_FAILED",
                                  reject_detail,
                                  retcode,
                                  last_error,
                                  comment);
      }
      signal_params.grid_orders[order_state.level_index] = order_state;
      return true;
    }
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = GridCurrentPriceForDirection(direction, true);

  ulong deal_ticket = (ulong)g_position.ResultDeal();
  ulong position_ticket = ResolvePositionTicketFromDeal(deal_ticket);
  if(position_ticket == 0)
    position_ticket = FindOpenPositionForSignal(direction, comment);

  bool broker_executed = (retcode == TRADE_RETCODE_DONE ||
                          retcode == TRADE_RETCODE_DONE_PARTIAL);
  if(pandora_signal && (!broker_executed || position_ticket == 0))
  {
    string context = broker_executed ? "ORDER_SEND_POSITION_MISSING" : "ORDER_SEND_REJECTED";
    string reject_detail = PandoraBrokerRejectSummary(context, "", retcode, last_error);
    if(retcode == TRADE_RETCODE_DONE_PARTIAL)
      reject_detail = reject_detail + StringFormat(" volume=%.2f", g_position.ResultVolume());
    MqlTradeRequest broker_request;
    ZeroMemory(broker_request);
    g_position.Request(broker_request);
    GridLogBrokerSendDiagnostic(context + "_DIAGNOSTIC",
                                signal_params,
                                order_state,
                                broker_request,
                                broker_check_result,
                                broker_check_available,
                                broker_check_sent,
                                broker_check_error,
                                retcode,
                                last_error,
                                g_position.ResultRetcodeDescription(),
                                g_position.ResultComment());
    MarketStatusRegisterBrokerFailure(context, retcode, last_error, false);
    if(!PandoraBrokerRetcodeAllowsLocalSimulation(retcode))
    {
      PandoraCompleteNonOperableBrokerRejection(signal_params,
                                                order_state,
                                                context,
                                                reject_detail,
                                                retcode,
                                                last_error,
                                                comment);
    }
    else if(context != "ORDER_SEND_POSITION_MISSING" &&
       PandoraBrokerRetryBudgetAvailable(signal_params) &&
       PandoraBrokerFailureRetryable(context,
                                     reject_detail,
                                     retcode,
                                     last_error,
                                     broker_check_result,
                                     broker_check_available,
                                     broker_check_sent))
    {
      PandoraMarkBrokerRetryPending(signal_params,
                                    order_state,
                                    context,
                                    reject_detail,
                                    retcode,
                                    last_error,
                                    comment);
    }
    else
    {
      PandoraMarkBrokerRejected(signal_params,
                                order_state,
                                context,
                                reject_detail,
                                retcode,
                                last_error,
                                comment);
    }
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  MarketStatusClearExecutionError("ORDER_SEND_OK");

  order_state.status = GRID_ORDER_ACTIVE;
  order_state.entry_price = fill_price;
  order_state.position_ticket = position_ticket;
  order_state.position_comment = comment;
  order_state.last_action_time = TimeCurrent();

  if(pandora_signal)
  {
    if(retcode == TRADE_RETCODE_DONE_PARTIAL && Enable_Logs)
    {
      PrintFormat("PANDORA_BROKER_PARTIAL_FILL ticket=%I64u retcode=%I64u volume=%.2f requested=%.2f",
                  order_state.position_ticket,
                  retcode,
                  g_position.ResultVolume(),
                  normalized_volume);
    }
    PandoraMarkBrokerExecuted(signal_params,
                              order_state,
                              retcode,
                              last_error,
                              comment);
  }

  GridRefreshPandoraStopsAfterFill(signal_params, order_state);

  signal_params.grid_orders[order_state.level_index] = order_state;
  return sent;
}

bool GridHandlePandoraBrokerRetry(SignalParams &signal_params,
                                  GridOrderState &order_state,
                                  const double point_size,
                                  const double normalized_volume)
{
  if(!PandoraBrokerRetryPending(signal_params))
    return false;
  if(signal_params.pandora_local_entry_status != PANDORA_LOCAL_ENTRY_ACTIVE)
    return false;
  if(order_state.status == GRID_ORDER_COMPLETED)
    return false;
  if(order_state.position_ticket > 0)
    return false;

  datetime now_time = TimeCurrent();
  if(PandoraBrokerRetryWindowExpired(signal_params, now_time))
  {
    string expired_comment = order_state.position_comment;
    if(expired_comment == "")
      expired_comment = GridComposeLevelComment(signal_params, order_state);
    string detail = "retry_window_expired";
    PandoraMarkBrokerRejected(signal_params,
                              order_state,
                              "PANDORA_BROKER_RETRY_EXPIRED",
                              detail,
                              signal_params.pandora_broker_retcode,
                              signal_params.pandora_broker_last_error,
                              expired_comment);
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  if(signal_params.pandora_broker_retry_next_time > now_time)
    return false;

  string comment = order_state.position_comment;
  if(comment == "")
  {
    comment = GridComposeLevelComment(signal_params, order_state);
    order_state.position_comment = comment;
  }

  ulong existing_ticket = FindOpenPositionForSignal(signal_params.signal_type, comment);
  if(existing_ticket > 0)
  {
    order_state.position_ticket = existing_ticket;
    if(PositionSelectByTicket(existing_ticket))
    {
      double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(position_open_price > 0.0)
        order_state.entry_price = position_open_price;
    }
    PandoraMarkBrokerExecuted(signal_params,
                              order_state,
                              TRADE_RETCODE_DONE,
                              0,
                              comment);
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  if(!PandoraBrokerRetryBudgetAvailable(signal_params))
  {
    string detail = StringFormat("attempts=%d/%d",
                                 signal_params.pandora_broker_attempt_count,
                                 PandoraBrokerRetryMaxAttempts());
    PandoraMarkBrokerRejected(signal_params,
                              order_state,
                              "PANDORA_BROKER_RETRY_GIVE_UP",
                              detail,
                              signal_params.pandora_broker_retcode,
                              signal_params.pandora_broker_last_error,
                              comment);
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  double current_entry_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  string drift_detail = "";
  if(PandoraBrokerRetryDriftExceeded(signal_params,
                                     order_state,
                                     current_entry_price,
                                     point_size,
                                     drift_detail))
  {
    PandoraMarkBrokerRejected(signal_params,
                              order_state,
                              "PANDORA_BROKER_RETRY_DRIFT",
                              drift_detail,
                              signal_params.pandora_broker_retcode,
                              signal_params.pandora_broker_last_error,
                              comment);
    signal_params.grid_orders[order_state.level_index] = order_state;
    return true;
  }

  return GridExecuteLevelTrade(signal_params,
                               order_state,
                               point_size,
                               normalized_volume);
}

bool GridCloseBrokerPosition(GridOrderState &order_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(order_state.position_ticket <= 0)
    return true;

  if(!PositionSelectByTicket(order_state.position_ticket))
    return true;

  if(!g_position.PositionClose(order_state.position_ticket))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("POSITION_CLOSE_FAILED", retcode, last_error, true);
    return false;
  }
  MarketStatusClearExecutionError("POSITION_CLOSE_OK");

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.position_ticket = 0;
  return true;
}

void GridCloseAllLevels(SignalParams &signal_params,
                        const double point_size)
{
  bool result = false;
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    double close_price = 0.0;
    result = GridCloseBrokerPosition(state, direction, close_price);
    if(result) state.status = GRID_ORDER_COMPLETED;
    GridLogEvent("LEVEL_CLOSE_ALL", signal_params, state);
    signal_params.grid_orders[i] = state;
  }

  if(signal_params.hedge_position_ticket > 0 &&
     PositionSelectByTicket(signal_params.hedge_position_ticket))
  {
    long position_magic = PositionGetInteger(POSITION_MAGIC);
    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_magic == g_magic_number && position_symbol == _Symbol)
    {
      if(!g_position.PositionClose(signal_params.hedge_position_ticket))
      {
        ulong retcode = g_position.ResultRetcode();
        int last_error = GetLastError();
        MarketStatusRegisterBrokerFailure("HEDGE_CLOSE_ALL_FAILED", retcode, last_error, true);
      }
      else
      {
        MarketStatusClearExecutionError("HEDGE_CLOSE_ALL_OK");
      }
      GridOrderState hedge_state;
      hedge_state.position_ticket = signal_params.hedge_position_ticket;
      hedge_state.status = GRID_ORDER_COMPLETED;
      hedge_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      GridLogEvent("HEDGE_CLOSE_ALL", signal_params, hedge_state);
    }
    signal_params.hedge_position_ticket = 0;
    signal_params.hedge_sl_active = false;
    signal_params.hedge_sl_price = 0.0;
  }
  signal_params.hedge_finalized = true;
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

bool IsGridSignalComplete(const SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
       state.status == GRID_ORDER_ACTIVE ||
       state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
      return false;
  }

  int attached_positions = 0;
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
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

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
