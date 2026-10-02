// Data-only transition semantics derived from Stochastic_Structure by @loldlm.
#ifndef MODEL_STOCHASTIC_STRUCTURE_MQH
#define MODEL_STOCHASTIC_STRUCTURE_MQH

struct ModelStructurePivot
{
  int kind;
  string classification;
  double price;
  datetime time;
  datetime confirmed_at;
};

struct ModelStructureState
{
  int kind;
  datetime last_bar;
  datetime candidate_time;
  double candidate_price;
  bool has_high;
  bool has_low;
  double last_high;
  double last_low;
};

ModelStructureState g_model_structure;
ModelStructurePivot g_model_confirmed_high, g_model_confirmed_low, g_model_confirmed_event;
datetime g_model_structure_cutoff = 0;
datetime g_model_structure_cursor = 0;
long g_model_structure_first_date = 0;
bool g_model_structure_initialized = false;
bool g_model_structure_history_changed = false;
bool g_model_structure_ready = false;
double g_model_structure_last_close = EMPTY_VALUE;
double g_model_structure_last_k = EMPTY_VALUE;
string g_model_structure_reason = "UNAVAILABLE";
int g_model_warmup_count = 0;
datetime g_model_warmup_first = 0, g_model_warmup_last = 0;
ulong g_model_warmup_fingerprint = 0xcbf29ce484222325;
string g_model_warmup_status = "UNAVAILABLE";

string ModelStructureClass(const ModelStructureState &state)
{
  if(state.kind == 0) return MODEL_NULL;
  bool has_previous = state.kind == 1 ? state.has_high : state.has_low;
  if(!has_previous) return state.kind == 1 ? "HIGH" : "LOW";
  double previous = state.kind == 1 ? state.last_high : state.last_low;
  double current_ticks = MathRound(state.candidate_price / g_model_tick_size);
  double previous_ticks = MathRound(previous / g_model_tick_size);
  if(current_ticks == previous_ticks) return "EQ";
  if(state.kind == 1) return current_ticks > previous_ticks ? "HH" : "LH";
  return current_ticks > previous_ticks ? "HL" : "LL";
}

void ModelStructureStart(ModelStructureState &state, const int kind, const datetime time, const double price)
{
  state.kind = kind;
  state.candidate_time = time;
  state.candidate_price = price;
}

bool ModelStructureAdvance(ModelStructureState &state, const datetime time, const datetime confirmed_at,
                            const double close, const double k, ModelStructurePivot &pivot)
{
  pivot.kind = 0;
  if(time <= state.last_bar || confirmed_at <= time || !ModelNumberValid(close) || close <= 0.0 ||
     !ModelNumberValid(k) || k < 0.0 || k > 100.0 || g_model_tick_size <= 0.0) return false;
  state.last_bar = time;
  if(state.kind == 0)
  {
    if(k > 80.0) ModelStructureStart(state, 1, time, close);
    else if(k < 20.0) ModelStructureStart(state, -1, time, close);
    return true;
  }
  bool reversal = state.kind == 1 ? k < 20.0 && state.candidate_price > close :
                                    k > 80.0 && state.candidate_price < close;
  if(reversal)
  {
    pivot.kind = state.kind;
    pivot.classification = ModelStructureClass(state);
    pivot.price = state.candidate_price;
    pivot.time = state.candidate_time;
    pivot.confirmed_at = confirmed_at;
    if(state.kind == 1) { state.has_high = true; state.last_high = pivot.price; }
    else { state.has_low = true; state.last_low = pivot.price; }
    ModelStructureStart(state, -state.kind, time, close);
  }
  else if(state.kind == 1 ? close > state.candidate_price : close < state.candidate_price)
  {
    state.candidate_price = close;
    state.candidate_time = time;
  }
  return true;
}

void ModelStructureAudit(const string phase, const datetime time, const double close, const double k,
                         const datetime confirmed_at, const string snapshot_id = "NONE")
{
  if(g_model_structure_audit == INVALID_HANDLE || g_model_audit_count >= MODEL_AUDIT_SNAPSHOTS ||
     g_model_structure_audit_count >= 8192) return;
  string row = phase;
  ModelCell(row, ModelInteger((long)time * 1000));
  ModelCell(row, ModelNumber(close));
  ModelCell(row, ModelNumber(k));
  ModelCell(row, ModelInteger((long)confirmed_at * 1000));
  ModelCell(row, snapshot_id);
  if(!ModelWriteBytes(g_model_structure_audit, row + "\r\n")) ModelFail("STRUCTURE_AUDIT_WRITE");
  g_model_structure_audit_count++;
}

bool ModelCommitStructure(const MqlRates &source, const double k, const datetime confirmed_at, const bool warmup)
{
  ModelStructurePivot pivot;
  if(!ModelStructureAdvance(g_model_structure, source.time, confirmed_at, source.close, k, pivot)) return false;
  if(g_cont_enabled) ModelContinuationHistory(warmup ? "M1_WARMUP" : "M1_CONFIRMED",
    ModelContinuationRate(source) + "\t" + ModelContinuationNumber(k) + "\t" + ModelInteger(confirmed_at));
  if(pivot.kind != 0)
  {
    g_model_confirmed_event = pivot;
    if(pivot.kind == 1) g_model_confirmed_high = pivot;
    else g_model_confirmed_low = pivot;
  }
  g_model_structure_cursor = source.time;
  g_model_structure_last_close = source.close;
  g_model_structure_last_k = k;
  ModelStructureAudit(warmup ? "WARMUP" : "CLOSED", source.time, source.close, k, confirmed_at);
  if(warmup)
  {
    if(g_model_warmup_count == 0) g_model_warmup_first = source.time;
    g_model_warmup_last = source.time;
    g_model_warmup_count++;
    string source_token = ModelInteger((long)source.time * 1000) + "|" + ModelNumber(source.close) + "|" +
                          ModelNumber(k) + "|" + ModelInteger((long)confirmed_at * 1000) + "\n";
    g_model_warmup_fingerprint = ModelFingerprint(g_model_warmup_fingerprint, source_token);
  }
  return true;
}

bool ModelWarmStructure()
{
  if(g_model_structure_handle == INVALID_HANDLE || g_model_structure_cutoff <= 0) return false;
  int calculated = BarsCalculated(g_model_structure_handle);
  if(calculated <= 0) return false;
  int shift = iBarShift(g_model_config.symbol, PERIOD_M1, g_model_structure_cutoff - 1, false);
  int available = shift > 0 ? calculated - shift - 8 : 0;
  int count = (int)MathMin(MODEL_WARMUP_LIMIT, MathMax(0, available));
  if(!SeriesInfoInteger(g_model_config.symbol, PERIOD_M1, SERIES_FIRSTDATE, g_model_structure_first_date)) return false;
  if(count > 0)
  {
    MqlRates source[];
    double k[];
    if(CopyRates(g_model_config.symbol, PERIOD_M1, shift, count, source) != count ||
       CopyBuffer(g_model_structure_handle, 0, shift, count, k) != count) return false;
    for(int i = 0; i < count; i++)
    {
      datetime next = i + 1 < count ? source[i + 1].time : g_model_structure_cutoff;
      if(source[i].time >= g_model_structure_cutoff || next <= source[i].time || !ModelNumberValid(k[i]) ||
         k[i] < 0.0 || k[i] > 100.0 || !ModelNumberValid(source[i].close) || source[i].close <= 0.0) return false;
    }
    for(int i = 0; i < count; i++)
    {
      datetime next = i + 1 < count ? source[i + 1].time : g_model_structure_cutoff;
      if(!ModelCommitStructure(source[i], k[i], next, true)) return false;
    }
  }
  g_model_warmup_status = count == 0 ? "UNAVAILABLE" : (available > count ? "TRUNCATED" : (count < MODEL_WARMUP_LIMIT ? "PARTIAL" : "COMPLETE"));
  g_model_structure_initialized = true;
  return true;
}

void ModelUpdateStructure(const MqlTick &tick)
{
  g_model_structure_ready = false;
  g_model_structure_reason = "UNAVAILABLE";
  if(!ModelReady()) return;
  datetime current = iTime(g_model_config.symbol, PERIOD_M1, 0);
  if(current <= 0 || current > tick.time) return;
  if(g_model_structure_cutoff == 0)
  {
    int first_shift = iBarShift(g_model_config.symbol, PERIOD_M1, (datetime)(g_model_first_time / 1000), false);
    if(first_shift < 0) return;
    g_model_structure_cutoff = iTime(g_model_config.symbol, PERIOD_M1, first_shift);
    if(g_model_structure_cutoff <= 0 || (long)g_model_structure_cutoff * 1000 > g_model_first_time)
    {
      g_model_structure_cutoff = 0;
      return;
    }
  }
  if(!g_model_structure_initialized && !ModelWarmStructure()) return;
  if(g_model_structure_history_changed) { g_model_structure_reason = "HISTORY_CHANGED"; return; }
  long first_date = 0;
  if(!SeriesInfoInteger(g_model_config.symbol, PERIOD_M1, SERIES_FIRSTDATE, first_date)) return;
  if(first_date != g_model_structure_first_date)
  {
    g_model_structure_history_changed = true;
    g_model_structure_reason = "HISTORY_CHANGED";
    return;
  }
  int shift = g_model_structure_cursor > 0 ? iBarShift(g_model_config.symbol, PERIOD_M1, g_model_structure_cursor, true) :
                                           iBarShift(g_model_config.symbol, PERIOD_M1, g_model_structure_cutoff, true) + 1;
  if(shift < 1) { g_model_structure_reason = "HISTORY_UNAVAILABLE"; return; }
  int pending = shift - 1;
  if(pending > 0)
  {
    if(g_model_structure_cursor > 0 && ModelNumberValid(g_model_structure_last_k))
    {
      MqlRates prior[1]; double previous_k[1];
      if(CopyRates(g_model_config.symbol, PERIOD_M1, shift, 1, prior) != 1 ||
         CopyBuffer(g_model_structure_handle, 0, shift, 1, previous_k) != 1) return;
      if(prior[0].time != g_model_structure_cursor || prior[0].close != g_model_structure_last_close || previous_k[0] != g_model_structure_last_k)
      {
        g_model_structure_history_changed = true;
        g_model_structure_reason = "HISTORY_CHANGED";
        return;
      }
    }
    int count = (int)MathMin(pending, MODEL_CATCHUP_LIMIT);
    int start = pending - count + 1;
    MqlRates source[];
    double k[];
    if(CopyRates(g_model_config.symbol, PERIOD_M1, start - 1, count + 1, source) != count + 1 ||
       CopyBuffer(g_model_structure_handle, 0, start, count, k) != count) return;
    for(int i = 0; i < count; i++)
      if(source[i].time <= g_model_structure_cursor || source[i + 1].time <= source[i].time ||
         source[i + 1].time > current || !ModelNumberValid(k[i]) || k[i] < 0.0 || k[i] > 100.0) return;
    int calculated = BarsCalculated(g_model_structure_handle);
    for(int i = 0; i < count; i++)
    {
      if(calculated - (start + count - 1 - i) <= 8)
      {
        if(g_cont_enabled) ModelContinuationHistory("M1_UNREADY", ModelContinuationRate(source[i]) + "\t" + ModelContinuationNumber(k[i]));
        g_model_structure_cursor = source[i].time;
        g_model_structure_last_k = EMPTY_VALUE;
        continue;
      }
      if(!ModelCommitStructure(source[i], k[i], source[i + 1].time, false)) return;
    }
    if(pending > count) { g_model_structure_reason = "CATCHUP_PENDING"; return; }
  }
  g_model_structure_ready = true;
  g_model_structure_reason = g_model_structure.kind == 0 ? "INITIAL" : "OK";
}

void ModelConfirmedCells(ModelRow &row, const int slot, const ModelStructurePivot &pivot)
{
  if(pivot.kind == 0) return;
  row.Set(MODEL_CONFIRMED_KIND[slot], pivot.kind == 1 ? "HIGH" : "LOW");
  row.Set(MODEL_CONFIRMED_CLASS[slot], pivot.classification);
  row.Number(MODEL_CONFIRMED_PRICE[slot], pivot.price);
  row.Clock(MODEL_CONFIRMED_PIVOT_TIME_MSC[slot], (long)pivot.time * 1000, true);
  row.Clock(MODEL_CONFIRMED_CONFIRMATION_TIME_MSC[slot], (long)pivot.confirmed_at * 1000, true);
}

bool ModelCaptureStructure(ModelRow &row, const MqlTick &tick, const string snapshot_id)
{
  row.Flag(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_COMPLETE, false);
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_REASON, g_model_structure_reason);
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_FORMING_STATUS, "UNAVAILABLE");
  MqlRates current[1];
  double k[1];
  if(!g_model_structure_ready || g_model_structure_handle == INVALID_HANDLE || BarsCalculated(g_model_structure_handle) < 10 ||
     CopyRates(g_model_config.symbol, PERIOD_M1, 0, 1, current) != 1 ||
     CopyBuffer(g_model_structure_handle, 0, 0, 1, k) != 1 || current[0].time > tick.time ||
     current[0].time <= g_model_structure_cursor || current[0].time != iTime(g_model_config.symbol, PERIOD_M1, 0)) return false;
  row.Clock(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_OBSERVED_BAR_TIME_MSC, (long)current[0].time * 1000, true);
  row.Clock(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_LAST_CLOSED_TIME_MSC, (long)g_model_structure_cursor * 1000, true);
  ModelConfirmedCells(row, 0, g_model_confirmed_high);
  ModelConfirmedCells(row, 1, g_model_confirmed_low);
  ModelConfirmedCells(row, 2, g_model_confirmed_event);
  ModelStructureState projection = g_model_structure;
  ModelStructurePivot transient;
  if(!ModelStructureAdvance(projection, current[0].time, current[0].time + 60, current[0].close, k[0], transient)) return false;
  row.Flag(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_COMPLETE, true);
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_STRUCTURE_REASON, projection.kind == 0 ? "INITIAL" : "OK");
  row.Set(MODEL_F_FEATURE_SNAPSHOTS_FORMING_STATUS, projection.kind == 0 ? "INITIAL" : "FORMING");
  if(projection.kind != 0)
  {
    row.Set(MODEL_F_FEATURE_SNAPSHOTS_FORMING_KIND, projection.kind == 1 ? "HIGH" : "LOW");
    row.Set(MODEL_F_FEATURE_SNAPSHOTS_FORMING_CLASS, ModelStructureClass(projection));
    row.Number(MODEL_F_FEATURE_SNAPSHOTS_FORMING_PRICE, projection.candidate_price);
    row.Clock(MODEL_F_FEATURE_SNAPSHOTS_FORMING_PIVOT_TIME_MSC, (long)projection.candidate_time * 1000, true);
  }
  ModelStructureAudit("LIVE", current[0].time, current[0].close, k[0], current[0].time + 60, snapshot_id);
  return true;
}

#endif
