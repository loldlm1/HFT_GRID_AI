#ifndef MODEL_INDICATORS_MQH
#define MODEL_INDICATORS_MQH

int g_model_bands[2] = {INVALID_HANDLE, INVALID_HANDLE};
int g_model_stochastic[2] = {INVALID_HANDLE, INVALID_HANDLE};
int g_model_atr[2] = {INVALID_HANDLE, INVALID_HANDLE};
int g_model_structure_handle = INVALID_HANDLE;
int g_model_indicator_audit = INVALID_HANDLE;
int g_model_structure_audit = INVALID_HANDLE;
int g_model_audit_count = 0;
int g_model_structure_audit_count = 0;

int ModelOpenAudit(const string suffix, const string header)
{
  string path = MODEL_STORAGE_ROOT + "\\diagnostics\\" + g_model_config.run_id + suffix;
  int handle = FileOpen(path, FILE_WRITE | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
  if(handle == INVALID_HANDLE) { ModelFail("SOURCE_AUDIT_OPEN"); return INVALID_HANDLE; }
  if(!ModelWriteBytes(handle, header + "\r\n"))
  {
    FileClose(handle);
    ModelFail("SOURCE_AUDIT_HEADER");
    return INVALID_HANDLE;
  }
  return handle;
}

void ModelOpenIndicators()
{
  ArrayInitialize(g_model_bands, INVALID_HANDLE);
  ArrayInitialize(g_model_stochastic, INVALID_HANDLE);
  ArrayInitialize(g_model_atr, INVALID_HANDLE);
  if(!ModelReady()) return;
  for(int i = 0; i < 2; i++)
  {
    ENUM_TIMEFRAMES timeframe = i == 0 ? g_model_config.macro : g_model_config.micro;
    g_model_bands[i] = iBands(g_model_config.symbol, timeframe, 21, 0, 2.0, PRICE_WEIGHTED);
    g_model_stochastic[i] = iStochastic(g_model_config.symbol, timeframe, 5, 3, 3, MODE_SMA, STO_CLOSECLOSE);
    g_model_atr[i] = iATR(g_model_config.symbol, timeframe, 13);
    if(g_model_bands[i] != INVALID_HANDLE) g_model_handle_peak++;
    if(g_model_stochastic[i] != INVALID_HANDLE) g_model_handle_peak++;
    if(g_model_atr[i] != INVALID_HANDLE) g_model_handle_peak++;
  }
  if(g_model_config.micro == PERIOD_M1) g_model_structure_handle = g_model_stochastic[1];
  else
  {
    g_model_structure_handle = iStochastic(g_model_config.symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_CLOSECLOSE);
    if(g_model_structure_handle != INVALID_HANDLE) g_model_handle_peak++;
  }
  if(MQLInfoInteger(MQL_TESTER))
  {
    g_model_indicator_audit = ModelOpenAudit(".indicators.tsv",
      "snapshot_id\trole\tobserved_time_msc\tshift\tsource_time_msc\thigh\tlow\tclose\tlower\tupper\tstochastic_k\tstochastic_d\tatr_13");
    g_model_structure_audit = ModelOpenAudit(".structure.tsv", "phase\tbar_time_msc\tclose\tk\tconfirmation_time_msc\tsnapshot_id");
  }
}

void ModelCloseIndicators()
{
  if(g_model_released) return;
  g_model_released = true;
  if(g_model_structure_handle != INVALID_HANDLE && g_model_structure_handle != g_model_stochastic[1])
    if(!IndicatorRelease(g_model_structure_handle)) Print("MODEL_STRUCTURE_RELEASE_FAILED");
  g_model_structure_handle = INVALID_HANDLE;
  for(int i = 0; i < 2; i++)
  {
    if(g_model_bands[i] != INVALID_HANDLE && !IndicatorRelease(g_model_bands[i])) Print("MODEL_BANDS_RELEASE_FAILED");
    if(g_model_stochastic[i] != INVALID_HANDLE && !IndicatorRelease(g_model_stochastic[i])) Print("MODEL_STOCHASTIC_RELEASE_FAILED");
    if(g_model_atr[i] != INVALID_HANDLE && !IndicatorRelease(g_model_atr[i])) Print("MODEL_ATR_RELEASE_FAILED");
    g_model_bands[i] = INVALID_HANDLE;
    g_model_stochastic[i] = INVALID_HANDLE;
    g_model_atr[i] = INVALID_HANDLE;
  }
  if(g_model_indicator_audit != INVALID_HANDLE) FileClose(g_model_indicator_audit);
  if(g_model_structure_audit != INVALID_HANDLE) FileClose(g_model_structure_audit);
  g_model_indicator_audit = INVALID_HANDLE;
  g_model_structure_audit = INVALID_HANDLE;
}

bool ModelCopyBuffer(const int handle, const int buffer, const int warmup, double &values[])
{
  ArrayInitialize(values, EMPTY_VALUE);
  if(handle == INVALID_HANDLE) return false;
  double copied[10];
  // Nonvisual testing calculates on demand; request data before checking readiness.
  if(CopyBuffer(handle, buffer, 0, 10, copied) != 10) return false;
  if(BarsCalculated(handle) < warmup + 10) return false;
  for(int i = 0; i < 10; i++)
  {
    if(!ModelNumberValid(copied[i])) return false;
    values[9 - i] = copied[i];
  }
  return true;
}

void ModelIndicatorAudit(const string snapshot_id, const string role, const MqlTick &tick,
                         const MqlRates &rates[], const double &lower[], const double &upper[],
                         const double &k[], const double &d[], const double &atr[])
{
  if(g_model_indicator_audit == INVALID_HANDLE || g_model_audit_count >= MODEL_AUDIT_SNAPSHOTS) return;
  for(int shift = 0; shift < 10; shift++)
  {
    int source = 9 - shift;
    string row = snapshot_id;
    ModelCell(row, role);
    ModelCell(row, ModelInteger(tick.time_msc));
    ModelCell(row, ModelInteger(shift));
    ModelCell(row, ModelInteger((long)rates[source].time * 1000));
    ModelCell(row, ModelNumber(rates[source].high));
    ModelCell(row, ModelNumber(rates[source].low));
    ModelCell(row, ModelNumber(rates[source].close));
    ModelCell(row, ModelNumber(lower[shift]));
    ModelCell(row, ModelNumber(upper[shift]));
    ModelCell(row, ModelNumber(k[shift]));
    ModelCell(row, ModelNumber(d[shift]));
    ModelCell(row, ModelNumber(atr[shift]));
    if(!ModelWriteBytes(g_model_indicator_audit, row + "\r\n")) { ModelFail("SOURCE_AUDIT_WRITE"); return; }
  }
}

bool ModelCaptureIndicators(ModelRow &row, const int slot, const MqlTick &tick,
                            const string snapshot_id)
{
  string role = slot == 0 ? "macro" : "micro";
  ENUM_TIMEFRAMES timeframe = slot == 0 ? g_model_config.macro : g_model_config.micro;
  row.Flag(MODEL_ROLE_COMPLETE[slot], false);
  row.Flag(MODEL_ROLE_STOCHASTIC_COMPLETE[slot], false);
  row.Flag(MODEL_ROLE_PERCENT_B_COMPLETE[slot], false);
  row.Flag(MODEL_ROLE_ATR_COMPLETE[slot], false);
  row.Set(MODEL_ROLE_REASON[slot], "SOURCE_UNAVAILABLE");
  datetime opening = iTime(g_model_config.symbol, timeframe, 0);
  MqlRates rates[10];
  if(opening <= 0 || opening > tick.time || CopyRates(g_model_config.symbol, timeframe, 0, 10, rates) != 10 ||
     rates[9].time != opening) return false;
  for(int i = 0; i < 10; i++)
    if(rates[i].time <= 0 || rates[i].time > tick.time || (i > 0 && rates[i].time <= rates[i - 1].time)) return false;
  double lower[10], upper[10], k[10], d[10], atr[10], percent[10];
  bool lower_ok = ModelCopyBuffer(g_model_bands[slot], 2, 21, lower);
  bool upper_ok = ModelCopyBuffer(g_model_bands[slot], 1, 21, upper);
  bool k_ok = ModelCopyBuffer(g_model_stochastic[slot], 0, 8, k);
  bool d_ok = ModelCopyBuffer(g_model_stochastic[slot], 1, 8, d);
  bool atr_ok = ModelCopyBuffer(g_model_atr[slot], 0, 13, atr);
  bool bands_ok = lower_ok && upper_ok;
  bool stochastic_ok = k_ok && d_ok;
  ArrayInitialize(percent, EMPTY_VALUE);
  for(int shift = 0; shift < 10; shift++)
  {
    MqlRates source = rates[9 - shift];
    bool band_valid = ModelNumberValid(upper[shift]) && ModelNumberValid(lower[shift]) && upper[shift] > lower[shift] &&
                      ModelNumberValid(source.high) && ModelNumberValid(source.low) && ModelNumberValid(source.close);
    if(band_valid) percent[shift] = 100.0 * ((source.high + source.low + 2.0 * source.close) / 4.0 - lower[shift]) / (upper[shift] - lower[shift]);
    if(!band_valid || !ModelNumberValid(percent[shift])) bands_ok = false;
    if(!ModelNumberValid(k[shift]) || !ModelNumberValid(d[shift]) || k[shift] < 0.0 || k[shift] > 100.0 || d[shift] < 0.0 || d[shift] > 100.0) stochastic_ok = false;
    if(!ModelNumberValid(atr[shift]) || atr[shift] < 0.0) atr_ok = false;
  }
  if(iTime(g_model_config.symbol, timeframe, 0) != opening)
  {
    row.Set(MODEL_ROLE_REASON[slot], "BAR_CHANGED");
    return false;
  }
  for(int shift = 0; shift < 6; shift++)
  {
    int column = slot * 6 + shift;
    row.Clock(MODEL_ROLE_SOURCE[column], (long)rates[9 - shift].time * 1000, true);
    if(stochastic_ok)
    {
      row.Number(MODEL_ROLE_STOCHASTIC_K[column], k[shift]);
      row.Number(MODEL_ROLE_STOCHASTIC_D[column], d[shift]);
    }
    if(bands_ok)
    {
      double total = 0.0;
      for(int j = 0; j < 5; j++) total += percent[shift + j];
      row.Number(MODEL_ROLE_PERCENT_B[column], percent[shift]);
      row.Number(MODEL_ROLE_PERCENT_B_SMA_5[column], total / 5.0);
    }
    if(atr_ok)
    {
      double total = 0.0;
      for(int j = 0; j < 5; j++) total += atr[shift + j];
      row.Number(MODEL_ROLE_ATR_13[column], atr[shift]);
      row.Number(MODEL_ROLE_ATR_13_SMA_5[column], total / 5.0);
    }
  }
  if(g_cont_enabled)
    for(int source = 0; source < 10; source++)
      ModelContinuationHistory(role + "_INDICATORS", ModelContinuationRate(rates[9 - source]) +
        "\t" + ModelContinuationNumber(lower[source]) + "\t" + ModelContinuationNumber(upper[source]) +
        "\t" + ModelContinuationNumber(k[source]) + "\t" + ModelContinuationNumber(d[source]) + "\t" + ModelContinuationNumber(atr[source]));
  bool complete = bands_ok && stochastic_ok && atr_ok;
  row.Flag(MODEL_ROLE_COMPLETE[slot], complete);
  row.Flag(MODEL_ROLE_STOCHASTIC_COMPLETE[slot], stochastic_ok);
  row.Flag(MODEL_ROLE_PERCENT_B_COMPLETE[slot], bands_ok);
  row.Flag(MODEL_ROLE_ATR_COMPLETE[slot], atr_ok);
  row.Set(MODEL_ROLE_REASON[slot], complete ? "OK" : "INDICATOR_UNAVAILABLE");
  ModelIndicatorAudit(snapshot_id, role, tick, rates, lower, upper, k, d, atr);
  return complete;
}

#endif
