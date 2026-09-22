#ifndef CANDLE_BROKER_MQH
#define CANDLE_BROKER_MQH

bool CandleSessionOpen(const datetime time)
{
  MqlDateTime parts;
  if(!TimeToStruct(time, parts)) return false;
  int second = parts.hour * 3600 + parts.min * 60 + parts.sec;
  for(int index = 0; index < 32; index++)
  {
    datetime start = 0, end = 0;
    if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)parts.day_of_week, index, start, end)) break;
    long begin = (long)start % 86400;
    long finish = (long)end % 86400;
    if((long)end - (long)start >= 86400) return true;
    if(finish == begin) continue;
    if(finish > begin && second >= begin && second < finish) return true;
    if(finish < begin && (second >= begin || second < finish)) return true;
  }
  return false;
}

string CandlePermission(const MqlTick &tick, const int direction, const bool closing)
{
  if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
     !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
     !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return "TRADE_PERMISSION";
  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return "HEDGING_REQUIRED";
  if(!CandleTickValid(tick) || tick.time > TimeCurrent() || TimeCurrent() - tick.time > 5) return "STALE_QUOTE";
  if(!CandleSessionOpen(tick.time)) return "BROKER_SESSION";
  long mode = 0, filling = 0, orders = 0;
  if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, mode) ||
     !SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, filling) ||
     !SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE, orders)) return "SYMBOL_SPECIFICATION";
  if(mode == SYMBOL_TRADE_MODE_DISABLED) return "SYMBOL_DISABLED";
  if(!closing && mode != SYMBOL_TRADE_MODE_FULL &&
     !(direction > 0 && mode == SYMBOL_TRADE_MODE_LONGONLY) &&
     !(direction < 0 && mode == SYMBOL_TRADE_MODE_SHORTONLY)) return "SYMBOL_DIRECTION";
  if((filling & SYMBOL_FILLING_FOK) == 0) return "FOK_UNAVAILABLE";
  if((orders & SYMBOL_ORDER_MARKET) == 0 ||
     (!closing && ((orders & SYMBOL_ORDER_SL) == 0 || (orders & SYMBOL_ORDER_TP) == 0))) return "ORDER_MODE";
  return "OK";
}

bool CandleVolume(double &volume)
{
  volume = 0.0;
  double minimum = 0.0, maximum = 0.0, step = 0.0;
  if(!SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, minimum) ||
     !SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, maximum) ||
     !SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, step) || minimum <= 0.0 || step <= 0.0 ||
     Lot_Strategy_Size < minimum || Lot_Strategy_Size > maximum) return false;
  volume = NormalizeDouble(MathFloor(Lot_Strategy_Size / step + 1e-9) * step, 8);
  return volume >= minimum && volume <= maximum;
}

bool CandleGeometry(const MqlTick &tick, const int direction, const double atr,
                     double &entry, double &sl, double &tp)
{
  entry = direction > 0 ? tick.ask : tick.bid;
  sl = EMPTY_VALUE;
  tp = EMPTY_VALUE;
  double tick_size = 0.0;
  if(!CandleTickValid(tick) || !CandleNumberValid(atr) || atr <= 0.0 ||
     !SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) || tick_size <= 0.0) return false;
  double units = NormalizeDouble((entry - direction * atr) / tick_size, 8);
  sl = NormalizeDouble((direction > 0 ? MathFloor(units) : MathCeil(units)) * tick_size, _Digits);
  double risk = direction * (entry - sl);
  tp = NormalizeDouble(entry + direction * risk, _Digits);
  return CandleNumberValid(sl) && CandleNumberValid(tp) && sl > 0.0 && tp > 0.0 && risk > 0.0;
}

string CandleStops(const MqlTick &tick, const int direction, const double sl, const double tp)
{
  long stops = 0, freeze = 0;
  if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stops) ||
     !SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze) ||
     stops < 0 || freeze < 0 || _Point <= 0.0) return "STOPS_SPECIFICATION";
  double exit_quote = direction > 0 ? tick.bid : tick.ask;
  double sl_gap = direction * (exit_quote - sl);
  double tp_gap = direction * (tp - exit_quote);
  double minimum = MathMax((double)stops, (double)freeze) * _Point;
  if(sl_gap <= 0.0 || tp_gap <= 0.0 || sl_gap < minimum || tp_gap < minimum) return "ATR_STOPS_TOO_CLOSE";
  return "OK";
}

void CandleCheckRow(const CandleAttempt &attempt, const string action, const MqlTick &tick,
                    const bool allowed, const string reason, const double volume,
                    const double entry, const double sl, const double tp,
                    const double margin, const double stop_profit, const uint check_retcode,
                    const uint send_retcode, const ulong order, const ulong deal, const ulong position_id)
{
  string row = Signal_Feature_Run_Id;
  CandleCell(row, attempt.id);
  CandleCell(row, action);
  CandleCell(row, CandleInteger(tick.time_msc));
  CandleCell(row, CandleInteger(g_candle_sequence));
  CandleCell(row, CandleBoolean(allowed));
  CandleCell(row, reason);
  CandleCell(row, CandleNumber(tick.bid));
  CandleCell(row, CandleNumber(tick.ask));
  CandleCell(row, CandleNumber(volume));
  CandleCell(row, CandleNumber(entry));
  CandleCell(row, CandleNumber(sl));
  CandleCell(row, CandleNumber(tp));
  CandleCell(row, CandleNumber(margin));
  CandleCell(row, CandleNumber(stop_profit));
  CandleCell(row, CandleInteger(check_retcode));
  CandleCell(row, CandleInteger(send_retcode));
  CandleCell(row, order > 0 ? CandleInteger((long)order) : "\\N");
  CandleCell(row, deal > 0 ? CandleInteger((long)deal) : "\\N");
  CandleCell(row, position_id > 0 ? CandleInteger((long)position_id) : "\\N");
  CandleWrite(CANDLE_CHECKS, row);
  if(Enable_Logs)
    PrintFormat("CANDLE_BROKER | %s | %s | time=%I64d | %s | %s | volume=%.8f | entry=%.10f | sl=%.10f | tp=%.10f | retcode=%u",
                action, attempt.id, tick.time_msc, CandleDirection(attempt.direction), reason,
                volume, entry, sl, tp, send_retcode);
}

int CandleFreeBroker()
{
  for(int i = 0; i < g_candle_broker_extent; i++) if(!g_candle_brokers[i].active) return i;
  if(g_candle_broker_extent < CANDLE_BROKER_CAP) return g_candle_broker_extent++;
  return -1;
}

void CandleSubmit(const CandleAttempt &attempt, const MqlTick &decision_tick, const double atr)
{
  MqlTick tick = decision_tick;
  bool fresh = SymbolInfoTick(_Symbol, tick) && CandleTickValid(tick) && tick.time_msc >= decision_tick.time_msc;
  double entry = EMPTY_VALUE, sl = EMPTY_VALUE, tp = EMPTY_VALUE, volume = 0.0;
  bool geometry = fresh && CandleGeometry(tick, attempt.direction, atr, entry, sl, tp);
  bool volume_ok = CandleVolume(volume);
  string distance_reason = geometry ? CandleStops(tick, attempt.direction, sl, tp) : "INVALID_GEOMETRY";
  string reason = !fresh ? "QUOTE_UNAVAILABLE" : (!geometry ? "INVALID_GEOMETRY" :
                   (!volume_ok ? "INVALID_VOLUME" : CandlePermission(tick, attempt.direction, false)));
  if(reason == "OK") reason = distance_reason;
  if(reason == "OK" && g_candle_broker_uncertain) reason = "BROKER_OWNERSHIP_UNRESOLVED";
  double margin = EMPTY_VALUE, stop_profit = EMPTY_VALUE, target_profit = EMPTY_VALUE;
  if(geometry && volume_ok)
  {
    stop_profit = CandleProfit(attempt.direction, volume, entry, sl);
    target_profit = CandleProfit(attempt.direction, volume, entry, tp);
  }
  if(reason == "OK" && (!CandleNumberValid(stop_profit) || stop_profit >= 0.0 ||
                        !CandleNumberValid(target_profit) || target_profit <= 0.0)) reason = "PROFIT_CALCULATION";
  if(reason == "OK" && (!OrderCalcMargin(attempt.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                         _Symbol, volume, entry, margin) || !CandleNumberValid(margin) ||
                        margin < 0.0 || margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))) reason = "MARGIN";
  int slot = reason == "OK" ? CandleFreeBroker() : -1;
  if(reason == "OK" && slot < 0) reason = "BROKER_CAPACITY";

  MqlTradeRequest request = {};
  MqlTradeCheckResult check = {};
  MqlTradeResult result = {};
  request.action = TRADE_ACTION_DEAL;
  request.magic = CANDLE_MAGIC;
  request.symbol = _Symbol;
  request.type = attempt.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  request.volume = volume;
  request.price = entry;
  request.sl = sl;
  request.tp = tp;
  request.type_filling = ORDER_FILLING_FOK;
  request.deviation = 10;
  request.comment = "CANDLE_PATTERN_ATR_V1";
  if(reason == "OK" && (!OrderCheck(request, check) ||
                        (check.retcode != 0 && check.retcode != TRADE_RETCODE_DONE))) reason = "ORDER_CHECK";
  bool allowed = reason == "OK";
  bool accepted = false;
  if(allowed)
  {
    // Reserve broker ownership before sending; research resources never gate this request.
    ZeroMemory(g_candle_brokers[slot]);
    g_candle_brokers[slot].active = true;
    g_candle_brokers[slot].attempt = attempt;
    g_candle_brokers[slot].reference_entry = entry;
    g_candle_brokers[slot].sl = sl;
    g_candle_brokers[slot].tp = tp;
    g_candle_brokers[slot].volume = volume;
    g_candle_brokers[slot].request_time = tick.time_msc;
    bool sent = OrderSend(request, result);
    accepted = sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED ||
                        result.retcode == TRADE_RETCODE_DONE_PARTIAL);
    g_candle_brokers[slot].order = result.order;
    g_candle_brokers[slot].deal = result.deal;
    g_candle_brokers[slot].request_id = result.request_id;
    bool unresolved = !accepted && (result.order > 0 || result.deal > 0 ||
                      result.retcode == TRADE_RETCODE_TIMEOUT || result.retcode == TRADE_RETCODE_CONNECTION ||
                      result.retcode == TRADE_RETCODE_ERROR || result.retcode == 0);
    if(accepted || unresolved)
    {
      g_candle_broker_count++;
      if(g_candle_broker_count > g_candle_broker_peak) g_candle_broker_peak = g_candle_broker_count;
      reason = accepted ? "ACCEPTED" : "UNRESOLVED_SEND";
      if(unresolved)
      {
        g_candle_broker_uncertain = true;
        CandleExportFail("ENTRY_OWNERSHIP_UNRESOLVED");
      }
    }
    else
    {
      g_candle_brokers[slot].active = false;
      reason = "SEND_REJECTED";
    }
  }
  CandleCheckRow(attempt, "ENTRY", tick, allowed, reason, volume, entry, sl, tp, margin, stop_profit,
                 check.retcode, result.retcode, result.order, result.deal, 0);
  CandleTrial(attempt, "BROKER", 1, tick.time_msc, entry, sl, tp, volume, accepted ? "ACCEPTED" : "REJECTED");
  if(!accepted)
    CandleOutcome(attempt.id, "BROKER", 1, attempt.direction, "REJECTED", reason,
                  0, 0, 0, tick.time_msc, EMPTY_VALUE, EMPTY_VALUE, sl, tp, volume,
                  EMPTY_VALUE, EMPTY_VALUE, 0);
  string virtual_status = !geometry ? "INELIGIBLE_GEOMETRY" :
                          (distance_reason != "OK" ? "INELIGIBLE_DISTANCE" :
                          (!volume_ok || !CandleNumberValid(stop_profit) || stop_profit >= 0.0 ?
                           "INELIGIBLE_MONEY" : "ELIGIBLE"));
  if(CANDLE_VIRTUAL_CAP - g_candle_virtual_count < 2 && virtual_status == "ELIGIBLE")
    virtual_status = "CAPACITY_REJECTED";
  for(int rr = 2; rr <= 3; rr++)
  {
    double virtual_tp = geometry ? NormalizeDouble(entry + attempt.direction * rr * MathAbs(entry - sl), _Digits) : EMPTY_VALUE;
    string status = virtual_status;
    if(!CandleNumberValid(virtual_tp) || virtual_tp <= 0.0) status = "INELIGIBLE_GEOMETRY";
    else if(status == "ELIGIBLE")
    {
      double profit = CandleProfit(attempt.direction, volume, entry, virtual_tp);
      if(!CandleNumberValid(profit) || profit <= 0.0) status = "INELIGIBLE_MONEY";
    }
    CandleVirtualStart(attempt, "VIRTUAL", rr, tick.time_msc, entry, sl, virtual_tp, volume, status);
  }
  if(accepted) CandleVirtualStart(attempt, "PARITY", 1, tick.time_msc, entry, sl, tp, volume, "ELIGIBLE");
  if(accepted && result.retcode == TRADE_RETCODE_DONE_PARTIAL) CandleExportFail("UNEXPECTED_PARTIAL_FOK");
}

bool CandleSelectOwnedPosition(CandleBrokerRecord &record)
{
  if(record.ticket > 0 && PositionSelectByTicket(record.ticket) &&
     (ulong)PositionGetInteger(POSITION_IDENTIFIER) == record.position_id &&
     PositionGetInteger(POSITION_MAGIC) == CANDLE_MAGIC && PositionGetString(POSITION_SYMBOL) == _Symbol) return true;
  int total = PositionsTotal();
  if(total > 16384) return false;
  for(int i = 0; i < total; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if(ticket > 0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == record.position_id &&
       PositionGetInteger(POSITION_MAGIC) == CANDLE_MAGIC && PositionGetString(POSITION_SYMBOL) == _Symbol)
    {
      record.ticket = ticket;
      return true;
    }
  }
  return false;
}

bool CandleResolveBrokerEntry(CandleBrokerRecord &record)
{
  if(record.filled) return true;
  if(record.deal > 0 && HistoryDealSelect(record.deal))
  {
    if(HistoryDealGetString(record.deal, DEAL_SYMBOL) != _Symbol ||
       HistoryDealGetInteger(record.deal, DEAL_MAGIC) != CANDLE_MAGIC ||
       HistoryDealGetInteger(record.deal, DEAL_ENTRY) != DEAL_ENTRY_IN) return false;
    record.position_id = (ulong)HistoryDealGetInteger(record.deal, DEAL_POSITION_ID);
    record.entry_time = HistoryDealGetInteger(record.deal, DEAL_TIME_MSC);
    record.entry = HistoryDealGetDouble(record.deal, DEAL_PRICE);
    record.volume = HistoryDealGetDouble(record.deal, DEAL_VOLUME);
  }
  else if(record.order > 0 && HistoryOrderSelect(record.order))
  {
    record.position_id = (ulong)HistoryOrderGetInteger(record.order, ORDER_POSITION_ID);
    if(record.position_id > 0 && HistorySelectByPosition(record.position_id))
    {
      int total = HistoryDealsTotal();
      if(total > CANDLE_HISTORY_CAP) { CandleExportFail("ENTRY_HISTORY_CAP"); return false; }
      for(int i = 0; i < total; i++)
      {
        ulong deal = HistoryDealGetTicket(i);
        if(deal > 0 && HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN &&
           HistoryDealGetInteger(deal, DEAL_MAGIC) == CANDLE_MAGIC && HistoryDealGetString(deal, DEAL_SYMBOL) == _Symbol)
        {
          record.deal = deal;
          record.entry_time = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
          record.entry = HistoryDealGetDouble(deal, DEAL_PRICE);
          record.volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
          break;
        }
      }
    }
  }
  if(record.position_id == 0 || record.entry_time <= 0 || record.entry <= 0.0 || record.volume <= 0.0) return false;
  record.deadline = record.entry_time + (long)g_macro_seconds * 1000;
  record.filled = true;
  return true;
}

bool CandleTerminalOrder(const ulong order, bool &unfilled)
{
  unfilled = false;
  if(order == 0 || OrderSelect(order) || !HistoryOrderSelect(order)) return false;
  long state = HistoryOrderGetInteger(order, ORDER_STATE);
  unfilled = state == ORDER_STATE_CANCELED || state == ORDER_STATE_REJECTED || state == ORDER_STATE_EXPIRED;
  return unfilled || state == ORDER_STATE_FILLED;
}

void CandlePendingEntry(CandleBrokerRecord &record, const MqlTick &tick)
{
  bool unfilled = false;
  if(CandleTerminalOrder(record.order, unfilled) && unfilled &&
     HistoryOrderGetInteger(record.order, ORDER_POSITION_ID) == 0)
  {
    CandleOutcome(record.attempt.id, "BROKER", 1, record.attempt.direction, "REJECTED", "ORDER_TERMINAL_UNFILLED",
                  0, 0, 0, tick.time_msc, EMPTY_VALUE, EMPTY_VALUE, record.sl, record.tp,
                  record.volume, EMPTY_VALUE, EMPTY_VALUE, 0);
    record.active = false;
    g_candle_broker_count--;
  }
  else if(tick.time_msc >= record.request_time + 30000)
  {
    // Retain ownership after the timeout; never resubmit an uncertain entry.
    g_candle_broker_uncertain = true;
    CandleExportFail("ENTRY_RECONCILIATION_TIMEOUT");
  }
}

bool CandleBrokerCloseFacts(CandleBrokerRecord &record, long &close_time, double &exit_price,
                            double &gross, double &costs, long &reason)
{
  close_time = 0; exit_price = 0.0; gross = 0.0; costs = 0.0; reason = -1;
  if(record.position_id == 0 || !HistorySelectByPosition(record.position_id)) return false;
  int total = HistoryDealsTotal();
  if(total > CANDLE_HISTORY_CAP) { CandleExportFail("CLOSE_HISTORY_CAP"); return false; }
  double closed_volume = 0.0;
  for(int i = 0; i < total; i++)
  {
    ulong deal = HistoryDealGetTicket(i);
    if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
       (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != record.position_id) return false;
    costs += HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_SWAP) +
             HistoryDealGetDouble(deal, DEAL_FEE);
    long kind = HistoryDealGetInteger(deal, DEAL_ENTRY);
    if(kind != DEAL_ENTRY_OUT && kind != DEAL_ENTRY_OUT_BY) continue;
    double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
    exit_price += HistoryDealGetDouble(deal, DEAL_PRICE) * volume;
    closed_volume += volume;
    gross += HistoryDealGetDouble(deal, DEAL_PROFIT);
    long time = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
    if(time >= close_time) { close_time = time; reason = HistoryDealGetInteger(deal, DEAL_REASON); }
  }
  if(close_time <= 0 || closed_volume + 1e-8 < record.volume) return false;
  exit_price /= closed_volume;
  return CandleNumberValid(exit_price) && CandleNumberValid(gross) && CandleNumberValid(costs);
}

void CandleRequestExpiry(CandleBrokerRecord &record, const MqlTick &tick)
{
  if(record.close_pending)
  {
    bool unfilled = false;
    if(CandleTerminalOrder(record.close_order, unfilled)) record.close_pending = false;
    else
    {
      if(tick.time_msc >= record.close_request_time + 30000)
      {
        g_candle_broker_uncertain = true;
        CandleExportFail("CLOSE_RECONCILIATION_TIMEOUT");
      }
      return;
    }
  }
  if(tick.time_msc < record.deadline || tick.time_msc < record.next_request_time) return;
  if(!CandleSelectOwnedPosition(record)) return;
  MqlTick fresh;
  if(!SymbolInfoTick(_Symbol, fresh) || !CandleTickValid(fresh) || fresh.time_msc < tick.time_msc) return;
  record.next_request_time = tick.time_msc + 1000;
  string reason = CandlePermission(fresh, -record.attempt.direction, true);
  double volume = PositionGetDouble(POSITION_VOLUME);
  MqlTradeRequest request = {};
  MqlTradeCheckResult check = {};
  MqlTradeResult result = {};
  request.action = TRADE_ACTION_DEAL;
  request.magic = CANDLE_MAGIC;
  request.symbol = _Symbol;
  request.position = record.ticket;
  request.type = record.attempt.direction > 0 ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
  request.volume = volume;
  request.price = record.attempt.direction > 0 ? fresh.bid : fresh.ask;
  request.type_filling = ORDER_FILLING_FOK;
  request.deviation = 10;
  request.comment = "CANDLE_TIME_EXIT";
  if(reason == "OK" && (!CandleNumberValid(volume) || volume <= 0.0)) reason = "CLOSE_VOLUME";
  if(reason == "OK" && (!OrderCheck(request, check) ||
                        (check.retcode != 0 && check.retcode != TRADE_RETCODE_DONE))) reason = "CLOSE_CHECK";
  bool allowed = reason == "OK";
  if(allowed)
  {
    bool sent = OrderSend(request, result);
    bool accepted = sent && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED ||
                            result.retcode == TRADE_RETCODE_DONE_PARTIAL);
    bool uncertain = !accepted && (result.order > 0 || result.deal > 0 || result.retcode == 0 ||
                     result.retcode == TRADE_RETCODE_TIMEOUT || result.retcode == TRADE_RETCODE_CONNECTION ||
                     result.retcode == TRADE_RETCODE_ERROR);
    record.close_pending = accepted || uncertain;
    record.close_order = result.order;
    record.close_request_time = fresh.time_msc;
    reason = record.close_pending ? "ACCEPTED" : "CLOSE_REJECTED";
    if(uncertain || result.retcode == TRADE_RETCODE_DONE_PARTIAL)
    {
      g_candle_broker_uncertain = true;
      reason = "CLOSE_UNRESOLVED";
      CandleExportFail("CLOSE_OWNERSHIP_UNRESOLVED");
    }
  }
  CandleCheckRow(record.attempt, "TIME_EXIT", fresh, allowed, reason, volume, request.price,
                 record.sl, record.tp, EMPTY_VALUE, EMPTY_VALUE, check.retcode, result.retcode,
                 result.order, result.deal, record.position_id);
}

#endif
