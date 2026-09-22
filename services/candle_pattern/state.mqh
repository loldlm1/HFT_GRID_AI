#ifndef CANDLE_STATE_MQH
#define CANDLE_STATE_MQH

struct CandleAttempt
{
  string id;
  string root_id;
  string parent_id;
  string pattern;
  int pattern_direction;
  int direction;
  int generation;
  long sequence;
  long decision_time;
};

struct CandleBrokerRecord
{
  bool active;
  bool filled;
  bool close_pending;
  CandleAttempt attempt;
  ulong order;
  ulong deal;
  ulong position_id;
  ulong ticket;
  uint request_id;
  ulong close_order;
  long request_time;
  long close_request_time;
  long entry_time;
  long deadline;
  long next_request_time;
  double reference_entry;
  double entry;
  double sl;
  double tp;
  double volume;
};

struct CandleVirtualRecord
{
  bool active;
  string trial_id;
  string attempt_id;
  string lane;
  int direction;
  int rr;
  long entry_time;
  long deadline;
  double entry;
  double sl;
  double tp;
  double volume;
};

CandleBrokerRecord g_candle_brokers[2048];
CandleVirtualRecord g_candle_virtuals[6144];
int g_candle_broker_count = 0;
int g_candle_virtual_count = 0;
int g_candle_broker_extent = 0;
int g_candle_virtual_extent = 0;
int g_candle_broker_peak = 0;
int g_candle_virtual_peak = 0;
bool g_candle_broker_uncertain = false;

string CandleTrialId(const string attempt_id, const string lane, const int rr)
{
  return attempt_id + ":" + lane + ":" + CandleInteger(rr);
}

void CandleTrial(const CandleAttempt &attempt, const string lane, const int rr,
                 const long reference_time, const double entry, const double sl,
                 const double tp, const double volume, const string eligibility)
{
  string row = Signal_Feature_Run_Id;
  CandleCell(row, CandleTrialId(attempt.id, lane, rr));
  CandleCell(row, attempt.id);
  CandleCell(row, lane);
  CandleCell(row, CandleInteger(rr));
  CandleCell(row, CandleInteger(reference_time));
  CandleCell(row, CandleInteger(reference_time + (long)g_macro_seconds * 1000));
  CandleCell(row, CandleNumber(entry));
  CandleCell(row, CandleNumber(sl));
  CandleCell(row, CandleNumber(tp));
  CandleCell(row, CandleNumber(volume));
  CandleCell(row, eligibility);
  CandleWrite(CANDLE_TRIALS, row);
}

void CandleOutcome(const string attempt_id, const string lane, const int rr,
                   const int direction, const string status, const string broker_reason,
                   const long entry_time, const long deadline, const long exit_time,
                   const long observed_time, const double entry, const double exit_price,
                   const double sl, const double tp, const double volume,
                   const double gross, const double costs, const ulong position_id,
                   const double reference_entry = EMPTY_VALUE)
{
  string row = Signal_Feature_Run_Id;
  CandleCell(row, CandleTrialId(attempt_id, lane, rr));
  CandleCell(row, attempt_id);
  CandleCell(row, lane);
  CandleCell(row, CandleInteger(rr));
  CandleCell(row, status);
  CandleCell(row, CandleNullable(broker_reason));
  CandleCell(row, entry_time > 0 ? CandleInteger(entry_time) : "\\N");
  int macro_shift = entry_time > 0 ? iBarShift(_Symbol, Macro_Timeframe, (datetime)(entry_time / 1000), false) : -1;
  datetime macro_open = macro_shift >= 0 ? iTime(_Symbol, Macro_Timeframe, macro_shift) : 0;
  CandleCell(row, macro_open > 0 ? CandleInteger((long)macro_open * 1000) : "\\N");
  CandleCell(row, deadline > 0 ? CandleInteger(deadline) : "\\N");
  CandleCell(row, exit_time > 0 ? CandleInteger(exit_time) : "\\N");
  CandleCell(row, CandleInteger(observed_time));
  CandleCell(row, CandleNumber(entry));
  CandleCell(row, CandleNumber(exit_price));
  CandleCell(row, CandleNumber(sl));
  CandleCell(row, CandleNumber(tp));
  CandleCell(row, CandleNumber(volume));
  CandleCell(row, CandleNumber(gross));
  CandleCell(row, CandleNumber(costs));
  CandleCell(row, CandleNumber(CandleNumberValid(gross) && CandleNumberValid(costs) ? gross + costs : EMPTY_VALUE));
  double risk = direction * (entry - sl);
  double gross_r = CandleNumberValid(entry) && CandleNumberValid(exit_price) &&
                   CandleNumberValid(sl) && risk > 0.0 ? direction * (exit_price - entry) / risk : EMPTY_VALUE;
  CandleCell(row, CandleNumber(gross_r));
  CandleCell(row, status == "TP_FIRST" ? "1" : (status == "SL_FIRST" ? "0" : "\\N"));
  CandleCell(row, position_id > 0 ? CandleInteger((long)position_id) : "\\N");
  CandleCell(row, CandleNumber(entry_time > 0 && lane == "BROKER" && CandleNumberValid(reference_entry) &&
                              CandleNumberValid(entry) ? (entry - reference_entry) / _Point : EMPTY_VALUE));
  CandleWrite(CANDLE_OUTCOMES, row);
}

double CandleProfit(const int direction, const double volume, const double entry, const double exit_price)
{
  double profit = 0.0;
  if(!OrderCalcProfit(direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                      _Symbol, volume, entry, exit_price, profit) || !CandleNumberValid(profit))
    return EMPTY_VALUE;
  return profit;
}

void CandleVirtualStart(const CandleAttempt &attempt, const string lane, const int rr,
                        const long time, const double entry, const double sl,
                        const double tp, const double volume, const string eligibility)
{
  if(!g_candle_export_open || g_candle_export_failed) return;
  string status = eligibility;
  int slot = -1;
  if(status == "ELIGIBLE")
  {
    for(int i = 0; i < g_candle_virtual_extent; i++)
      if(!g_candle_virtuals[i].active) { slot = i; break; }
    if(slot < 0 && g_candle_virtual_extent < CANDLE_VIRTUAL_CAP) slot = g_candle_virtual_extent++;
    if(slot < 0) status = "CAPACITY_REJECTED";
  }
  CandleTrial(attempt, lane, rr, time, entry, sl, tp, volume, status);
  if(slot < 0)
  {
    CandleOutcome(attempt.id, lane, rr, attempt.direction, status, "", 0, 0, 0,
                  time, EMPTY_VALUE, EMPTY_VALUE, sl, tp, volume, EMPTY_VALUE, EMPTY_VALUE, 0);
    if(lane == "PARITY" && status == "CAPACITY_REJECTED") CandleExportFail("PARITY_CAPACITY");
    return;
  }
  g_candle_virtuals[slot].active = true;
  g_candle_virtuals[slot].trial_id = CandleTrialId(attempt.id, lane, rr);
  g_candle_virtuals[slot].attempt_id = attempt.id;
  g_candle_virtuals[slot].lane = lane;
  g_candle_virtuals[slot].direction = attempt.direction;
  g_candle_virtuals[slot].rr = rr;
  g_candle_virtuals[slot].entry_time = time;
  g_candle_virtuals[slot].deadline = time + (long)g_macro_seconds * 1000;
  g_candle_virtuals[slot].entry = entry;
  g_candle_virtuals[slot].sl = sl;
  g_candle_virtuals[slot].tp = tp;
  g_candle_virtuals[slot].volume = volume;
  g_candle_virtual_count++;
  if(g_candle_virtual_count > g_candle_virtual_peak) g_candle_virtual_peak = g_candle_virtual_count;
}

void CandleResolveVirtuals(const MqlTick &tick, const bool run_end = false)
{
  for(int i = 0; i < g_candle_virtual_extent; i++)
  {
    if(!g_candle_virtuals[i].active) continue;
    CandleVirtualRecord trial = g_candle_virtuals[i];
    double quote = trial.direction > 0 ? tick.bid : tick.ask;
    string status = "";
    if(run_end) status = "CENSORED_RUN_END";
    else if(tick.time_msc >= trial.deadline) status = "TIME_EXIT";
    else if(trial.direction * (quote - trial.sl) <= 0.0) status = "SL_FIRST";
    else if(trial.direction * (quote - trial.tp) >= 0.0) status = "TP_FIRST";
    if(status == "") continue;
    double exit_price = run_end ? EMPTY_VALUE : quote;
    double gross = run_end ? EMPTY_VALUE : CandleProfit(trial.direction, trial.volume, trial.entry, quote);
    CandleOutcome(trial.attempt_id, trial.lane, trial.rr, trial.direction, status, "",
                  trial.entry_time, trial.deadline, run_end ? 0 : tick.time_msc, tick.time_msc,
                  trial.entry, exit_price, trial.sl, trial.tp, trial.volume, gross, EMPTY_VALUE, 0);
    g_candle_virtuals[i].active = false;
    g_candle_virtual_count--;
  }
  while(g_candle_virtual_extent > 0 && !g_candle_virtuals[g_candle_virtual_extent - 1].active)
    g_candle_virtual_extent--;
}

#endif
