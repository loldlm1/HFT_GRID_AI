#ifndef CANDLE_DATASET_ADAPTER_MQH
#define CANDLE_DATASET_ADAPTER_MQH

long g_candle_dataset_checks = 0;

bool CandleDatasetInitialize()
{
  ModelCaptureConfig config;
  config.enabled = Enable_Signal_Feature_Export;
  config.run_id = Signal_Feature_Run_Id;
  config.engine = "CANDLE_PATTERN_ATR_V3";
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
                         const double tp, const double volume, const string eligibility,
                         const EntryAdmissionFacts &admission, const string reason)
{
  if(!ModelReady()) return;
  if((eligibility == "ACCEPTED" || eligibility == "ELIGIBLE") &&
     (!admission.valid || !admission.eligible)) { ModelFail("CANDLE_ADMISSION_INVARIANT"); return; }
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set(MODEL_F_TRIALS_TRIAL_ID, CandleTrialId(attempt.id, role, rr));
  row.Set(MODEL_F_TRIALS_ATTEMPT_ID, attempt.id);
  row.Set(MODEL_F_TRIALS_ROLE, role);
  row.Set(MODEL_F_TRIALS_ENTRY_POLICY, attempt.generation == 0 ? "ORIGINAL" : "REENTRY");
  row.Integer(MODEL_F_TRIALS_RR, rr);
  row.Clock(MODEL_F_TRIALS_DECLARED_TIME_MSC, reference_time);
  if(role != "BROKER" && eligibility == "ELIGIBLE") row.Clock(MODEL_F_TRIALS_ENTRY_TIME_MSC, reference_time);
  row.Clock(MODEL_F_TRIALS_DEADLINE_TIME_MSC, reference_time + (long)g_macro_seconds * 1000);
  row.Number(MODEL_F_TRIALS_ENTRY_PRICE, entry);
  row.Number(MODEL_F_TRIALS_SL, sl);
  row.Number(MODEL_F_TRIALS_TP, tp);
  row.Number(MODEL_F_TRIALS_VOLUME, volume);
  row.Set(MODEL_F_TRIALS_ELIGIBILITY, eligibility);
  if(eligibility != "ELIGIBLE" && eligibility != "ACCEPTED") row.Set(MODEL_F_TRIALS_REASON, reason == "" ? eligibility : reason);
  if(admission.valid)
  {
    row.Number(MODEL_F_TRIALS_ENTRY_BID, admission.bid);
    row.Number(MODEL_F_TRIALS_ENTRY_ASK, admission.ask);
    row.Number(MODEL_F_TRIALS_POINT_SIZE, admission.point);
    row.Number(MODEL_F_TRIALS_TRADE_TICK_SIZE, admission.tick_size);
    row.Number(MODEL_F_TRIALS_SPREAD_POINTS, (admission.ask - admission.bid) / admission.point);
    row.Number(MODEL_F_TRIALS_STOPS_LEVEL_POINTS, admission.stops_points);
    row.Number(MODEL_F_TRIALS_FREEZE_LEVEL_POINTS, admission.freeze_points);
    row.Number(MODEL_F_TRIALS_NORMALIZED_RISK_DISTANCE_PRICE, admission.risk_price);
    row.Number(MODEL_F_TRIALS_NORMALIZED_RISK_DISTANCE_POINTS, admission.risk_price / admission.point);
    row.Number(MODEL_F_TRIALS_MINIMUM_RISK_DISTANCE_POINTS, admission.minimum_price / admission.point);
    row.Flag(MODEL_F_TRIALS_DISTANCE_ELIGIBLE, admission.eligible);
  }
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
  row.Set(MODEL_F_OUTCOMES_TRIAL_ID, CandleTrialId(attempt_id, role, rr));
  row.Set(MODEL_F_OUTCOMES_ATTEMPT_ID, attempt_id);
  row.Set(MODEL_F_OUTCOMES_ROLE, role);
  row.Integer(MODEL_F_OUTCOMES_RR, rr);
  row.Set(MODEL_F_OUTCOMES_STATUS, status);
  row.Set(MODEL_F_OUTCOMES_BROKER_REASON, ModelNullable(broker_reason));
  row.Clock(MODEL_F_OUTCOMES_ENTRY_TIME_MSC, entry_time);
  int shift = entry_time > 0 ? iBarShift(_Symbol, Macro_Timeframe, (datetime)(entry_time / 1000), false) : -1;
  datetime opening = shift >= 0 ? iTime(_Symbol, Macro_Timeframe, shift) : 0;
  row.Clock(MODEL_F_OUTCOMES_ENTRY_MACRO_OPEN_TIME_MSC, (long)opening * 1000, true);
  row.Clock(MODEL_F_OUTCOMES_DEADLINE_TIME_MSC, deadline);
  row.Clock(MODEL_F_OUTCOMES_EXIT_TIME_MSC, exit_time);
  row.Clock(MODEL_F_OUTCOMES_OBSERVED_TIME_MSC, observed_time);
  row.Number(MODEL_F_OUTCOMES_ENTRY_PRICE, entry);
  row.Number(MODEL_F_OUTCOMES_EXIT_PRICE, exit_price);
  row.Number(MODEL_F_OUTCOMES_SL, sl);
  row.Number(MODEL_F_OUTCOMES_TP, tp);
  row.Number(MODEL_F_OUTCOMES_VOLUME, volume);
  row.Number(MODEL_F_OUTCOMES_GROSS_PROFIT, gross);
  row.Number(MODEL_F_OUTCOMES_COSTS, costs);
  row.Number(MODEL_F_OUTCOMES_NET_PROFIT, ModelNumberValid(gross) && ModelNumberValid(costs) ? gross + costs : EMPTY_VALUE);
  double risk = direction * (entry - sl);
  row.Number(MODEL_F_OUTCOMES_GROSS_R, ModelNumberValid(entry) && ModelNumberValid(exit_price) && ModelNumberValid(sl) && risk > 0.0 ?
                         direction * (exit_price - entry) / risk : EMPTY_VALUE);
  bool binary = role != "PARITY" && (status == "TP_FIRST" || status == "SL_FIRST");
  row.Flag(MODEL_F_OUTCOMES_BINARY_ELIGIBLE, binary);
  if(binary) row.Integer(MODEL_F_OUTCOMES_BINARY_LABEL, status == "TP_FIRST" ? 1 : 0);
  else row.Set(MODEL_F_OUTCOMES_EXCLUSION_REASON, role == "PARITY" ? "PARITY" : status);
  if(position_id > 0) row.Integer(MODEL_F_OUTCOMES_POSITION_ID, (long)position_id);
  if(entry_time > 0 && role == "BROKER" && ModelNumberValid(reference_entry) && ModelNumberValid(entry))
    row.Number(MODEL_F_OUTCOMES_FILL_DEVIATION_POINTS, (entry - reference_entry) / _Point);
  if(entry_time > 0 && exit_time > 0) row.Integer(MODEL_F_OUTCOMES_DURATION_MS, exit_time - entry_time);
  if(!ModelWrite(row) && !g_model_failed) ModelFail("CANDLE_OUTCOME_WRITE");
}

void CandleDatasetCheck(const CandleAttempt &attempt, const string action, const MqlTick &tick,
                        const bool allowed, const string reason, const double volume,
                        const double entry, const double sl, const double tp,
                        const double margin, const double stop_profit, const uint check_retcode,
                        const uint send_retcode, const ulong order, const ulong deal, const ulong position_id,
                        const EntryAdmissionFacts &admission)
{
  if(ModelReady())
  {
    ModelRow row;
    row.Init(MODEL_EXECUTION_CHECKS);
    row.Set(MODEL_F_EXECUTION_CHECKS_CHECK_ID, attempt.id + ":CHECK:" + ModelInteger(++g_candle_dataset_checks));
    row.Set(MODEL_F_EXECUTION_CHECKS_ATTEMPT_ID, attempt.id);
    row.Set(MODEL_F_EXECUTION_CHECKS_ACTION, action);
    row.Clock(MODEL_F_EXECUTION_CHECKS_TIME_MSC, tick.time_msc);
    row.Integer(MODEL_F_EXECUTION_CHECKS_SEQUENCE, g_candle_sequence);
    row.Flag(MODEL_F_EXECUTION_CHECKS_ALLOWED, allowed);
    row.Set(MODEL_F_EXECUTION_CHECKS_REASON, reason);
    row.Number(MODEL_F_EXECUTION_CHECKS_BID, tick.bid);
    row.Number(MODEL_F_EXECUTION_CHECKS_ASK, tick.ask);
    if(action == "ENTRY" && admission.valid)
    {
      row.Number(MODEL_F_EXECUTION_CHECKS_POINT_SIZE, admission.point);
      row.Number(MODEL_F_EXECUTION_CHECKS_TRADE_TICK_SIZE, admission.tick_size);
      row.Number(MODEL_F_EXECUTION_CHECKS_SPREAD_POINTS, (admission.ask - admission.bid) / admission.point);
      row.Number(MODEL_F_EXECUTION_CHECKS_STOPS_DISTANCE_POINTS, admission.stops_points);
      row.Number(MODEL_F_EXECUTION_CHECKS_FREEZE_DISTANCE_POINTS, admission.freeze_points);
      row.Number(MODEL_F_EXECUTION_CHECKS_RISK_DISTANCE_POINTS, admission.risk_price / admission.point);
    }
    row.Number(MODEL_F_EXECUTION_CHECKS_VOLUME, volume);
    row.Number(MODEL_F_EXECUTION_CHECKS_ENTRY_PRICE, entry);
    row.Number(MODEL_F_EXECUTION_CHECKS_SL, sl);
    row.Number(MODEL_F_EXECUTION_CHECKS_TP, tp);
    row.Number(MODEL_F_EXECUTION_CHECKS_MARGIN, margin);
    row.Number(MODEL_F_EXECUTION_CHECKS_STOP_PROFIT, stop_profit);
    row.Integer(MODEL_F_EXECUTION_CHECKS_CHECK_RETCODE, check_retcode);
    row.Integer(MODEL_F_EXECUTION_CHECKS_SEND_RETCODE, send_retcode);
    if(order > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_ORDER_TICKET, (long)order);
    if(deal > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_DEAL_TICKET, (long)deal);
    if(position_id > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_POSITION_ID, (long)position_id);
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
  row.Set(MODEL_F_ENTRY_ATTEMPTS_ATTEMPT_ID, attempt.id);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_SIGNAL_ID, attempt.root_id);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_SNAPSHOT_ID, snapshot_id);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_PARENT_ATTEMPT_ID, ModelNullable(attempt.parent_id));
  row.Integer(MODEL_F_ENTRY_ATTEMPTS_SEQUENCE, attempt.sequence);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_ENTRY_TYPE, attempt.generation == 0 ? "ORIGINAL" : "REENTRY");
  row.Set(MODEL_F_ENTRY_ATTEMPTS_DIRECTION, CandleDirection(attempt.direction));
  row.Clock(MODEL_F_ENTRY_ATTEMPTS_DECISION_TIME_MSC, tick.time_msc);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_MACRO_WINDOW_ID, ModelNullable(g_model_window_id));
  row.Number(MODEL_F_ENTRY_ATTEMPTS_BID, tick.bid);
  row.Number(MODEL_F_ENTRY_ATTEMPTS_ASK, tick.ask);
  if(!ModelWrite(row)) return;
  ModelRow extra;
  extra.Init(MODEL_CANDLE_ATTEMPTS);
  extra.Set(MODEL_F_CANDLE_ATTEMPTS_ATTEMPT_ID, attempt.id);
  extra.Set(MODEL_F_CANDLE_ATTEMPTS_PATTERN, attempt.pattern);
  extra.Set(MODEL_F_CANDLE_ATTEMPTS_CATEGORY, CandleCategory(attempt.pattern_direction, attempt.direction));
  extra.Integer(MODEL_F_CANDLE_ATTEMPTS_GENERATION, attempt.generation);
  extra.Number(MODEL_F_CANDLE_ATTEMPTS_ATR_0, atr_current);
  extra.Number(MODEL_F_CANDLE_ATTEMPTS_ATR_1, atr_completed);
  extra.Clock(MODEL_F_CANDLE_ATTEMPTS_ATR_SOURCE_TIME_MSC, (long)atr_source * 1000, true);
  extra.Integer(MODEL_F_CANDLE_ATTEMPTS_ATR_SHIFT, 1);
  extra.Number(MODEL_F_CANDLE_ATTEMPTS_ATR_MULTIPLIER, 1.0);
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
  extra.Number(MODEL_F_CANDLE_ATTEMPTS_REQUESTED_VOLUME, requested_volume);
  double executable = attempt.direction > 0 ? tick.ask : tick.bid;
  double lower, upper;
  extra.Set(MODEL_F_CANDLE_ATTEMPTS_ENTRY_INTERVAL, ModelInterval(executable, lower, upper));
  if(g_model_tested >= 0 && g_model_ladder.valid)
    extra.Number(MODEL_F_CANDLE_ATTEMPTS_CONTEXT_DISTANCE_POINTS, (executable - g_model_ladder.trade_prices[g_model_tested]) / _Point);
  if(attempt.generation > 0) extra.Set(MODEL_F_CANDLE_ATTEMPTS_REENTRY_CAUSE, "BROKER_SL");
  extra.Set(MODEL_F_CANDLE_ATTEMPTS_EXPIRY_POLICY, "ENTRY_PLUS_MACRO");
  if(!ModelWrite(extra) && !g_model_failed) ModelFail("CANDLE_ATTEMPT_WRITE");
}

void CandleDatasetSignal(const string signal_id, const string pattern, const int direction,
                         const long sequence, const MqlRates &previous, const MqlRates &current,
                         const MqlTick &tick)
{
  if(!ModelReady()) return;
  ModelRow row;
  row.Init(MODEL_SIGNAL_EVENTS);
  row.Set(MODEL_F_SIGNAL_EVENTS_SIGNAL_ID, signal_id);
  row.Integer(MODEL_F_SIGNAL_EVENTS_SEQUENCE, sequence);
  row.Set(MODEL_F_SIGNAL_EVENTS_SYMBOL, _Symbol);
  row.Set(MODEL_F_SIGNAL_EVENTS_DIRECTION, CandleDirection(direction));
  row.Clock(MODEL_F_SIGNAL_EVENTS_SIGNAL_TIME_MSC, tick.time_msc);
  row.Clock(MODEL_F_SIGNAL_EVENTS_SOURCE_TIME_MSC, (long)current.time * 1000, true);
  row.Set(MODEL_F_SIGNAL_EVENTS_MACRO_WINDOW_ID, ModelNullable(g_model_window_id));
  row.Number(MODEL_F_SIGNAL_EVENTS_BID, tick.bid);
  row.Number(MODEL_F_SIGNAL_EVENTS_ASK, tick.ask);
  row.Set(MODEL_F_SIGNAL_EVENTS_ADMISSION, "DISCOVERED");
  if(!ModelWrite(row)) return;
  ModelRow extra;
  extra.Init(MODEL_CANDLE_SIGNALS);
  extra.Set(MODEL_F_CANDLE_SIGNALS_SIGNAL_ID, signal_id);
  extra.Set(MODEL_F_CANDLE_SIGNALS_PATTERN, pattern);
  extra.Set(MODEL_F_CANDLE_SIGNALS_PATTERN_DIRECTION, direction > 0 ? "BULLISH" : "BEARISH");
  extra.Number(MODEL_F_CANDLE_SIGNALS_PREVIOUS_OPEN, previous.open);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PREVIOUS_HIGH, previous.high);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PREVIOUS_LOW, previous.low);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PREVIOUS_CLOSE, previous.close);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PATTERN_OPEN, current.open);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PATTERN_HIGH, current.high);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PATTERN_LOW, current.low);
  extra.Number(MODEL_F_CANDLE_SIGNALS_PATTERN_CLOSE, current.close);
  if(!ModelWrite(extra) && !g_model_failed) ModelFail("CANDLE_SIGNAL_WRITE");
}

#endif
