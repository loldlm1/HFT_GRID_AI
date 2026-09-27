#ifndef PIVOT_BROKER_EXPIRY_MQH
#define PIVOT_BROKER_EXPIRY_MQH

bool PivotCloseOrderTerminal(const PivotSignal &signal)
{
  ulong order = signal.execution.close_order_ticket;
  if(order == 0 || OrderSelect(order) || !HistoryOrderSelect(order)) return false;
  if(HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol ||
     (ulong)HistoryOrderGetInteger(order, ORDER_MAGIC) != g_execution_magic ||
     (ulong)HistoryOrderGetInteger(order, ORDER_POSITION_ID) != signal.execution.position_identifier)
    return false;
  ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(order, ORDER_STATE);
  return state == ORDER_STATE_FILLED || state == ORDER_STATE_CANCELED ||
         state == ORDER_STATE_REJECTED || state == ORDER_STATE_EXPIRED;
}

void RequestPivotBrokerExpiry(PivotSignal &signal, const MqlTick &tick)
{
  if(!signal.execution.broker_entry_confirmed || signal.execution.broker_close_confirmed ||
     signal.execution.deadline_time_msc <= 0) return;
  if(signal.execution.close_pending)
  {
    if(PivotCloseOrderTerminal(signal)) signal.execution.close_pending = false;
    else
    {
      if(tick.time_msc >= signal.execution.close_request_time_msc + 30000)
      {
        ActivatePivotOwnershipEntryBlock("EXPIRY_CLOSE_UNRESOLVED");
        PivotDatasetFail("EXPIRY_CLOSE_RECONCILIATION_TIMEOUT");
      }
      return;
    }
  }
  if(tick.time_msc < signal.execution.deadline_time_msc ||
     tick.time_msc < signal.execution.next_close_request_time_msc) return;
  string reason = "";
  if(!SelectPivotPositionByOwnedTicket(signal, reason)) return;
  MqlTick fresh;
  if(!SymbolInfoTick(_Symbol, fresh) || !PivotTrialQuoteValid(fresh) ||
     fresh.time_msc < tick.time_msc || fresh.time_msc < signal.execution.deadline_time_msc ||
     fresh.time > TimeCurrent() || TimeCurrent() - fresh.time > 5) return;
  signal.execution.next_close_request_time_msc = fresh.time_msc + 1000;
  reason = "OK";
  long mode = 0, orders = 0;
  if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
     !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
     !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) reason = "CLOSE_PERMISSION";
  else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    reason = "CLOSE_HEDGING_REQUIRED";
  else if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, mode) ||
          !SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE, orders)) reason = "CLOSE_SYMBOL_SPECIFICATION";
  else if(mode == SYMBOL_TRADE_MODE_DISABLED || (orders & SYMBOL_ORDER_MARKET) == 0 ||
          !ExecutionFullFillPolicyAvailable(_Symbol)) reason = "CLOSE_SYMBOL_PERMISSION";
  else if(!IsSymbolTradeSessionOpen(_Symbol, fresh.time)) reason = "CLOSE_BROKER_SESSION";

  MqlTradeRequest request = {};
  MqlTradeCheckResult check = {};
  MqlTradeResult result = {};
  request.action = TRADE_ACTION_DEAL;
  request.symbol = _Symbol;
  request.magic = g_execution_magic;
  request.position = signal.execution.position_ticket;
  request.type = signal.direction == BULLISH ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
  request.volume = PositionGetDouble(POSITION_VOLUME);
  request.price = signal.direction == BULLISH ? fresh.bid : fresh.ask;
  request.type_filling = ORDER_FILLING_FOK;
  request.comment = "PM2_TIME_EXIT";
  if(!MathIsValidNumber(request.volume) || request.volume <= 0.0) reason = "CLOSE_VOLUME";
  if(reason == "OK" && (!OrderCheck(request, check) ||
      (check.retcode != 0 && check.retcode != TRADE_RETCODE_DONE))) reason = "CLOSE_ORDER_CHECK";
  bool allowed = reason == "OK";
  bool sent = false, accepted = false;
  if(allowed)
  {
    // Reserve ownership before sending; the admission helper is entry-only.
    signal.execution.close_pending = true;
    signal.execution.close_request_time_msc = fresh.time_msc;
    sent = OrderSend(request, result);
    accepted = sent && PivotSendRetcodeAccepted(result.retcode);
    bool uncertain = !accepted && (result.order > 0 || result.deal > 0 || result.retcode == 0 ||
      result.retcode == TRADE_RETCODE_TIMEOUT || result.retcode == TRADE_RETCODE_CONNECTION ||
      result.retcode == TRADE_RETCODE_ERROR || result.retcode == TRADE_RETCODE_DONE_PARTIAL);
    signal.execution.close_order_ticket = result.order;
    signal.execution.close_pending = accepted || uncertain;
    reason = accepted ? "ACCEPTED" : (uncertain ? "CLOSE_UNRESOLVED" : "CLOSE_REJECTED");
    if(uncertain)
    {
      ActivatePivotOwnershipEntryBlock("EXPIRY_CLOSE_UNRESOLVED");
      PivotDatasetFail("EXPIRY_CLOSE_OWNERSHIP_UNRESOLVED");
    }
  }
  PivotDatasetRecordExpiryCheck(signal, fresh, request, check, result, allowed, accepted, reason);
  if(allowed) ReconcilePivotSignalBrokerPosition(signal);
}

#endif
