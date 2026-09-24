#ifndef CANDLE_ENGINE_MQH
#define CANDLE_ENGINE_MQH

void CandleEnter(const string root_id, const string pattern, const int pattern_direction,
                  const int direction, const int generation, const string parent_id,
                  const MqlTick &tick)
{
  CandleAttempt attempt;
  attempt.root_id = root_id;
  attempt.pattern = pattern;
  attempt.pattern_direction = pattern_direction;
  attempt.direction = direction;
  attempt.generation = generation;
  attempt.parent_id = parent_id;
  attempt.sequence = ++g_candle_sequence;
  attempt.decision_time = tick.time_msc;
  attempt.id = root_id + ":" + CandleCategory(pattern_direction, direction) + ":" + ModelInteger(generation);
  double atr_current = EMPTY_VALUE, atr_completed = EMPTY_VALUE;
  datetime atr_source = 0;
  bool atr_available = CandleAtr(atr_current, atr_completed, atr_source, tick.time);
  if(!atr_available) atr_completed = EMPTY_VALUE;
  CandleDatasetAttempt(attempt, tick, atr_current, atr_completed, atr_source);
  CandleSubmit(attempt, tick, atr_completed);
}

void CandleReconcile(const MqlTick &tick, const bool allow_actions = true)
{
  for(int i = 0; i < g_candle_broker_extent; i++)
  {
    if(!g_candle_brokers[i].active) continue;
    if(!CandleResolveBrokerEntry(g_candle_brokers[i]))
    {
      CandlePendingEntry(g_candle_brokers[i], tick);
      continue;
    }
    if(CandleSelectOwnedPosition(g_candle_brokers[i]))
    {
      if(MathAbs(PositionGetDouble(POSITION_SL) - g_candle_brokers[i].sl) > _Point * 0.1 ||
         MathAbs(PositionGetDouble(POSITION_TP) - g_candle_brokers[i].tp) > _Point * 0.1)
      {
        g_candle_broker_uncertain = true;
        ModelFail("BROKER_PROTECTION_CHANGED");
      }
      if(allow_actions) CandleRequestExpiry(g_candle_brokers[i], tick);
      continue;
    }
    long close_time = 0, reason = -1;
    double exit_price = 0.0, gross = 0.0, costs = 0.0;
    if(!CandleBrokerCloseFacts(g_candle_brokers[i], close_time, exit_price, gross, costs, reason)) continue;
    CandleBrokerRecord record = g_candle_brokers[i];
    string status = "OTHER_CLOSE";
    if(close_time >= record.deadline) status = "TIME_EXIT";
    else if(reason == DEAL_REASON_SL) status = "SL_FIRST";
    else if(reason == DEAL_REASON_TP) status = "TP_FIRST";
    else if(!allow_actions && !record.close_pending) status = "CENSORED_RUN_END";
    string reason_name = EnumToString((ENUM_DEAL_REASON)reason);
    bool censored = status == "CENSORED_RUN_END";
    CandleDatasetOutcome(record.attempt.id, "BROKER", 1, record.attempt.direction, status, reason_name,
                  record.entry_time, record.deadline, censored ? 0 : close_time, tick.time_msc, record.entry,
                  censored ? EMPTY_VALUE : exit_price, record.sl, record.tp, record.volume,
                  censored ? EMPTY_VALUE : gross, censored ? EMPTY_VALUE : costs,
                  record.position_id, record.reference_entry);
    if(Enable_Logs)
      PrintFormat("CANDLE_CLOSED | %s | %s | entry=%I64d | close=%I64d | price=%.10f | gross=%.8f | costs=%.8f",
                  record.attempt.id, status, record.entry_time, close_time, exit_price, gross, costs);
    g_candle_brokers[i].active = false;
    g_candle_broker_count--;
    if(allow_actions && !g_candle_stopping && status == "SL_FIRST" && record.attempt.generation == 0 &&
       tick.time_msc >= close_time && tick.time_msc < record.deadline)
      CandleEnter(record.attempt.root_id, record.attempt.pattern, record.attempt.pattern_direction,
                  record.attempt.direction, 1, record.attempt.id, tick);
  }
  while(g_candle_broker_extent > 0 && !g_candle_brokers[g_candle_broker_extent - 1].active)
    g_candle_broker_extent--;
}

bool CandleDetect(const MqlRates &previous, const MqlRates &current,
                   string &pattern, int &direction)
{
  pattern = "";
  direction = 0;
  if(!ModelNumberValid(previous.open) || !ModelNumberValid(previous.close) ||
     !ModelNumberValid(current.open) || !ModelNumberValid(current.close) ||
     previous.open <= 0.0 || previous.close <= 0.0 || current.open <= 0.0 || current.close <= 0.0 ||
     previous.open == previous.close || current.open == current.close) return false;
  bool bullish = current.close > current.open;
  if(bullish == (previous.close > previous.open)) return false;
  double previous_low = MathMin(previous.open, previous.close);
  double previous_high = MathMax(previous.open, previous.close);
  double current_low = MathMin(current.open, current.close);
  double current_high = MathMax(current.open, current.close);
  if(current_low <= previous_low && current_high >= previous_high &&
     (current_low < previous_low || current_high > previous_high)) pattern = "ENGULFING";
  else if(current_low >= previous_low && current_high <= previous_high &&
          (current_low > previous_low || current_high < previous_high)) pattern = "HARAMI";
  if(pattern == "") return false;
  direction = bullish ? 1 : -1;
  return true;
}

void CandleDiscover(const MqlTick &tick)
{
  datetime current_bar = iTime(_Symbol, Micro_Timeframe, 0);
  if(current_bar <= 0 || current_bar > tick.time || current_bar == g_last_micro_bar) return;
  if(g_last_micro_bar == 0) { g_last_micro_bar = current_bar; return; }
  MqlRates candles[2];
  // CopyRates places shift 2 first and the completed signal candle (shift 1) second.
  if(CopyRates(_Symbol, Micro_Timeframe, 1, 2, candles) != 2 ||
     candles[0].time >= candles[1].time || candles[1].time >= current_bar) return;
  g_last_micro_bar = current_bar;
  string pattern;
  int direction;
  if(!CandleDetect(candles[0], candles[1], pattern, direction)) return;
  string root_id = _Symbol + ":" + ModelInteger(g_micro_seconds) + ":" +
                   ModelInteger(current_bar) + ":" + pattern;
  long signal_sequence = ++g_candle_sequence;
  CandleDatasetSignal(root_id, pattern, direction, signal_sequence, candles[0], candles[1], tick);
  CandleEnter(root_id, pattern, direction, direction, 0, "", tick);
  CandleEnter(root_id, pattern, direction, -direction, 0, "", tick);
}

void CandleFinish()
{
  if(g_candle_stopping) return;
  g_candle_stopping = true;
  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick) || !CandleTickValid(tick))
  {
    ZeroMemory(tick);
    tick.time_msc = g_candle_last_time;
    tick.time = (datetime)(g_candle_last_time / 1000);
  }
  CandleReconcile(tick, false);
  CandleResolveVirtuals(tick, true);
  for(int i = 0; i < g_candle_broker_extent; i++)
  {
    if(!g_candle_brokers[i].active) continue;
    CandleBrokerRecord record = g_candle_brokers[i];
    CandleDatasetOutcome(record.attempt.id, "BROKER", 1, record.attempt.direction, "CENSORED_RUN_END", "",
                  record.entry_time, record.deadline, 0, tick.time_msc,
                  record.filled ? record.entry : EMPTY_VALUE, EMPTY_VALUE, record.sl, record.tp,
                  record.volume, EMPTY_VALUE, EMPTY_VALUE, record.position_id, record.reference_entry);
  }
  ModelSeal(g_candle_broker_peak, g_candle_virtual_peak);
}

#endif
