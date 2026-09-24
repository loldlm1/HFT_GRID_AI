#ifndef CANDLE_DATASET_ADAPTER_MQH
#define CANDLE_DATASET_ADAPTER_MQH

long g_candle_dataset_checks = 0;

bool CandleDatasetInitialize()
{
  ModelCaptureConfig config;
  config.enabled = Enable_Signal_Feature_Export;
  config.run_id = Signal_Feature_Run_Id;
  config.engine = "CANDLE_PATTERN_ATR_V2";
  config.symbol = _Symbol;
  config.macro = Macro_Timeframe;
  config.micro = Micro_Timeframe;
  config.exness = Broker_Session == EXNESS_SESSION;
  config.lot_type = EnumToString(Lot_Type);
  config.lot_size = Lot_Strategy_Size;
  config.reference_balance = PIVOT_EXECUTION_REFERENCE_BALANCE;
  config.broker_cap = CANDLE_BROKER_CAP;
  config.virtual_cap = CANDLE_VIRTUAL_CAP;
  return ModelInitialize(config);
}

void CandleDatasetTrial(const CandleAttempt &attempt, const string role, const int rr,
                         const long reference_time, const double entry, const double sl,
                         const double tp, const double volume, const string eligibility)
{
  if(!ModelReady()) return;
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set("trial_id", CandleTrialId(attempt.id, role, rr));
  row.Set("attempt_id", attempt.id);
  row.Set("role", role);
  row.Set("entry_policy", attempt.generation == 0 ? "ORIGINAL" : "REENTRY");
  row.Integer("rr", rr);
  row.Clock("declared_time_msc", reference_time);
  if(role != "BROKER" && eligibility == "ELIGIBLE") row.Clock("entry_time_msc", reference_time);
  row.Clock("deadline_time_msc", reference_time + (long)g_macro_seconds * 1000);
  row.Number("entry_price", entry);
  row.Number("sl", sl);
  row.Number("tp", tp);
  row.Number("volume", volume);
  row.Set("eligibility", eligibility);
  if(eligibility != "ELIGIBLE" && eligibility != "ACCEPTED") row.Set("reason", eligibility);
  if(!ModelWrite(row) && !g_model_failed) ModelFail("CANDLE_TRIAL_WRITE");
}

void CandleDatasetOutcome(const string attempt_id, const string role, const int rr,
                          const int direction, const string status, const string broker_reason,
                          const long entry_time, const long deadline, const long exit_time,
                          const long observed_time, const double entry, const double exit_price,
                          const double sl, const double tp, const double volume,
                          const double gross, const double costs, const ulong position_id,
                          const double reference_entry = EMPTY_VALUE)
{
  if(!ModelReady()) return;
  ModelRow row;
  row.Init(MODEL_OUTCOMES);
  row.Set("trial_id", CandleTrialId(attempt_id, role, rr));
  row.Set("attempt_id", attempt_id);
  row.Set("role", role);
  row.Integer("rr", rr);
  row.Set("status", status);
  row.Set("broker_reason", ModelNullable(broker_reason));
  row.Clock("entry_time_msc", entry_time);
  int shift = entry_time > 0 ? iBarShift(_Symbol, Macro_Timeframe, (datetime)(entry_time / 1000), false) : -1;
  datetime opening = shift >= 0 ? iTime(_Symbol, Macro_Timeframe, shift) : 0;
  row.Clock("entry_macro_open_time_msc", (long)opening * 1000, true);
  row.Clock("deadline_time_msc", deadline);
  row.Clock("exit_time_msc", exit_time);
  row.Clock("observed_time_msc", observed_time);
  row.Number("entry_price", entry);
  row.Number("exit_price", exit_price);
  row.Number("sl", sl);
  row.Number("tp", tp);
  row.Number("volume", volume);
  row.Number("gross_profit", gross);
  row.Number("costs", costs);
  row.Number("net_profit", ModelNumberValid(gross) && ModelNumberValid(costs) ? gross + costs : EMPTY_VALUE);
  double risk = direction * (entry - sl);
  row.Number("gross_r", ModelNumberValid(entry) && ModelNumberValid(exit_price) && ModelNumberValid(sl) && risk > 0.0 ?
                         direction * (exit_price - entry) / risk : EMPTY_VALUE);
  bool binary = role != "PARITY" && (status == "TP_FIRST" || status == "SL_FIRST");
  row.Flag("binary_eligible", binary);
  if(binary) row.Integer("binary_label", status == "TP_FIRST" ? 1 : 0);
  else row.Set("exclusion_reason", role == "PARITY" ? "PARITY" : status);
  if(position_id > 0) row.Integer("position_id", (long)position_id);
  if(entry_time > 0 && role == "BROKER" && ModelNumberValid(reference_entry) && ModelNumberValid(entry))
    row.Number("fill_deviation_points", (entry - reference_entry) / _Point);
  if(entry_time > 0 && exit_time > 0) row.Integer("duration_ms", exit_time - entry_time);
  if(!ModelWrite(row) && !g_model_failed) ModelFail("CANDLE_OUTCOME_WRITE");
}

void CandleDatasetCheck(const CandleAttempt &attempt, const string action, const MqlTick &tick,
                        const bool allowed, const string reason, const double volume,
                        const double entry, const double sl, const double tp,
                        const double margin, const double stop_profit, const uint check_retcode,
                        const uint send_retcode, const ulong order, const ulong deal, const ulong position_id)
{
  if(ModelReady())
  {
    ModelRow row;
    row.Init(MODEL_EXECUTION_CHECKS);
    row.Set("check_id", attempt.id + ":CHECK:" + ModelInteger(++g_candle_dataset_checks));
    row.Set("attempt_id", attempt.id);
    row.Set("action", action);
    row.Clock("time_msc", tick.time_msc);
    row.Integer("sequence", g_candle_sequence);
    row.Flag("allowed", allowed);
    row.Set("reason", reason);
    row.Number("bid", tick.bid);
    row.Number("ask", tick.ask);
    row.Number("volume", volume);
    row.Number("entry_price", entry);
    row.Number("sl", sl);
    row.Number("tp", tp);
    row.Number("margin", margin);
    row.Number("stop_profit", stop_profit);
    row.Integer("check_retcode", check_retcode);
    row.Integer("send_retcode", send_retcode);
    if(order > 0) row.Integer("order_ticket", (long)order);
    if(deal > 0) row.Integer("deal_ticket", (long)deal);
    if(position_id > 0) row.Integer("position_id", (long)position_id);
    if(!ModelWrite(row) && !g_model_failed) ModelFail("CANDLE_CHECK_WRITE");
  }
  if(Enable_Logs)
    PrintFormat("CANDLE_BROKER | %s | %s | time=%I64d | %s | %s | volume=%.8f | entry=%.10f | sl=%.10f | tp=%.10f | retcode=%u",
                action, attempt.id, tick.time_msc, CandleDirection(attempt.direction), reason,
                volume, entry, sl, tp, send_retcode);
}

void CandleDatasetAttempt(const CandleAttempt &attempt, const MqlTick &tick,
                          const double atr_current, const double atr_completed, const datetime atr_source)
{
  if(!ModelReady()) return;
  string snapshot_id = attempt.id + ":FEATURES";
  if(!ModelCapture(attempt.root_id, snapshot_id, "CANDLE_DECISION", attempt.sequence, tick)) return;
  ModelRow row;
  row.Init(MODEL_ENTRY_ATTEMPTS);
  row.Set("attempt_id", attempt.id);
  row.Set("signal_id", attempt.root_id);
  row.Set("snapshot_id", snapshot_id);
  row.Set("parent_attempt_id", ModelNullable(attempt.parent_id));
  row.Integer("sequence", attempt.sequence);
  row.Set("entry_type", attempt.generation == 0 ? "ORIGINAL" : "REENTRY");
  row.Set("direction", CandleDirection(attempt.direction));
  row.Clock("decision_time_msc", tick.time_msc);
  row.Set("macro_window_id", ModelNullable(g_model_window_id));
  row.Number("bid", tick.bid);
  row.Number("ask", tick.ask);
  if(!ModelWrite(row)) return;
  ModelRow extra;
  extra.Init(MODEL_CANDLE_ATTEMPTS);
  extra.Set("attempt_id", attempt.id);
  extra.Set("pattern", attempt.pattern);
  extra.Set("category", CandleCategory(attempt.pattern_direction, attempt.direction));
  extra.Integer("generation", attempt.generation);
  extra.Number("atr_0", atr_current);
  extra.Number("atr_1", atr_completed);
  extra.Clock("atr_source_time_msc", (long)atr_source * 1000, true);
  extra.Integer("atr_shift", 1);
  extra.Number("atr_multiplier", 1.0);
  double requested_volume = Lot_Type == EXECUTION_LOT_FIXED_SIZE ? Lot_Strategy_Size : EMPTY_VALUE;
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    double entry = EMPTY_VALUE, sl = EMPTY_VALUE, tp = EMPTY_VALUE;
    if(CandleGeometry(tick, attempt.direction, atr_completed, entry, sl, tp))
    {
      double calculated = 0.0, volume = 0.0, stop_profit = EMPTY_VALUE;
      string reason = "";
      bool planned = CandleVolume(attempt.direction, entry, sl, tp, calculated, volume, stop_profit, reason);
      if(planned || (ModelNumberValid(calculated) && calculated > 0.0)) requested_volume = calculated;
    }
  }
  extra.Number("requested_volume", requested_volume);
  double executable = attempt.direction > 0 ? tick.ask : tick.bid;
  double lower, upper;
  extra.Set("entry_interval", ModelInterval(executable, lower, upper));
  if(g_model_tested >= 0 && g_model_ladder.valid)
    extra.Number("context_distance_points", (executable - g_model_ladder.trade_prices[g_model_tested]) / _Point);
  if(attempt.generation > 0) extra.Set("reentry_cause", "BROKER_SL");
  extra.Set("expiry_policy", "ENTRY_PLUS_MACRO");
  if(!ModelWrite(extra) && !g_model_failed) ModelFail("CANDLE_ATTEMPT_WRITE");
}

void CandleDatasetSignal(const string signal_id, const string pattern, const int direction,
                         const long sequence, const MqlRates &previous, const MqlRates &current,
                         const MqlTick &tick)
{
  if(!ModelReady()) return;
  ModelRow row;
  row.Init(MODEL_SIGNAL_EVENTS);
  row.Set("signal_id", signal_id);
  row.Integer("sequence", sequence);
  row.Set("symbol", _Symbol);
  row.Set("direction", CandleDirection(direction));
  row.Clock("signal_time_msc", tick.time_msc);
  row.Clock("source_time_msc", (long)current.time * 1000, true);
  row.Set("macro_window_id", ModelNullable(g_model_window_id));
  row.Number("bid", tick.bid);
  row.Number("ask", tick.ask);
  row.Set("admission", "DISCOVERED");
  if(!ModelWrite(row)) return;
  ModelRow extra;
  extra.Init(MODEL_CANDLE_SIGNALS);
  extra.Set("signal_id", signal_id);
  extra.Set("pattern", pattern);
  extra.Set("pattern_direction", direction > 0 ? "BULLISH" : "BEARISH");
  extra.Number("previous_open", previous.open);
  extra.Number("previous_high", previous.high);
  extra.Number("previous_low", previous.low);
  extra.Number("previous_close", previous.close);
  extra.Number("pattern_open", current.open);
  extra.Number("pattern_high", current.high);
  extra.Number("pattern_low", current.low);
  extra.Number("pattern_close", current.close);
  if(!ModelWrite(extra) && !g_model_failed) ModelFail("CANDLE_SIGNAL_WRITE");
}

#endif
