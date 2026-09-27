#ifndef MODEL_EXPORT_MQH
#define MODEL_EXPORT_MQH

struct ModelWriteBuffer
{
  uchar bytes[];
  int used;
  int rows;
};
ModelWriteBuffer g_model_buffers[MODEL_FILE_COUNT];
uchar g_model_encode_scratch[];

void ModelReleaseBuffers()
{
  for(int file = 0; file < MODEL_FILE_COUNT; file++)
  {
    ArrayFree(g_model_buffers[file].bytes);
    g_model_buffers[file].used = 0;
    g_model_buffers[file].rows = 0;
  }
  ArrayFree(g_model_encode_scratch);
}

bool ModelWriteBytes(const int handle, const string text)
{
  uchar encoded[];
  int count = StringToCharArray(text, encoded, 0, WHOLE_ARRAY, CP_UTF8);
  if(count <= 1) return false;
  ResetLastError();
  return FileWriteArray(handle, encoded, 0, count - 1) == (uint)(count - 1) && GetLastError() == 0;
}

void ModelFail(const string reason)
{
  if(g_model_failed) return;
  g_model_failed = true;
  g_model_failure = reason;
  PrintFormat("MODEL_DATASET_FAILED | run=%s | time_msc=%I64d | %s",
              g_model_config.run_id, g_model_last_time, reason);
  if(g_model_root == "") return;
  string diagnostic = MODEL_STORAGE_ROOT + "\\diagnostics\\" + g_model_config.run_id + ".failure.txt";
  int handle = FileOpen(diagnostic, FILE_WRITE | FILE_BIN | FILE_COMMON);
  if(handle != INVALID_HANDLE)
  {
    if(!ModelWriteBytes(handle, reason + "\r\n")) Print("MODEL_DIAGNOSTIC_WRITE_FAILED");
    FileClose(handle);
  }
  // An in-directory marker also invalidates a seal if its final flush fails.
  handle = FileOpen(g_model_root + "FAILED.txt", FILE_WRITE | FILE_BIN | FILE_COMMON);
  if(handle != INVALID_HANDLE)
  {
    if(!ModelWriteBytes(handle, reason + "\r\n")) Print("MODEL_FAILURE_MARKER_WRITE_FAILED");
    FileClose(handle);
  }
}

bool ModelFlush(const int file, const bool sealing = false)
{
  int count = g_model_buffers[file].used;
  // Final sealing must recheck even tables whose last batch already flushed.
  if(count == 0 && !sealing) return true;
  if(g_model_failed && !sealing) return false;
  string path = g_model_root + ModelFileName(file);
  if(!FileIsExist(path, FILE_COMMON)) { ModelFail("MISSING_FILE_" + ModelFileName(file)); return false; }
  int handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
  if(handle == INVALID_HANDLE) { ModelFail("OPEN_" + ModelFileName(file)); return false; }
  uchar actual[];
  int bytes = g_model_layout[file].header_bytes;
  ResetLastError();
  bool valid = bytes > 0 && ArrayResize(actual, bytes) == bytes &&
               FileReadArray(handle, actual, 0, bytes) == (uint)bytes && GetLastError() == 0;
  for(int i = 0; valid && i < bytes; i++) if(actual[i] != g_model_layout[file].header[i]) valid = false;
  if(valid) valid = FileSeek(handle, 0, SEEK_END);
  if(valid && count > 0)
  {
    ResetLastError();
    valid = FileWriteArray(handle, g_model_buffers[file].bytes, 0, count) == (uint)count && GetLastError() == 0;
  }
  if(valid)
  {
    ResetLastError();
    FileFlush(handle);
    valid = GetLastError() == 0;
  }
  FileClose(handle);
  if(!valid) { ModelFail("HEADER_OR_APPEND_" + ModelFileName(file)); return false; }
  g_model_buffers[file].used = 0;
  g_model_buffers[file].rows = 0;
  return true;
}

bool ModelWrite(ModelRow &row, const bool sealing = false)
{
  if(!g_model_config.enabled || !g_model_open || g_model_sealed || (g_model_failed && !sealing)) return false;
  string text;
  if(!row.Serialize(text)) return false;
  int file = row.file;
  // Three UTF-8 bytes per UTF-16 code unit also bounds surrogate pairs.
  int capacity = 3 * StringLen(text) + 3;
  if((ArraySize(g_model_encode_scratch) < capacity && ArrayResize(g_model_encode_scratch, capacity) != capacity) ||
     (ArraySize(g_model_buffers[file].bytes) == 0 && ArrayResize(g_model_buffers[file].bytes, MODEL_BATCH_BYTES) != MODEL_BATCH_BYTES))
  {
    ModelFail("BUFFER_ALLOCATION");
    return false;
  }
  int encoded = StringToCharArray(text, g_model_encode_scratch, 0, WHOLE_ARRAY, CP_UTF8);
  if(encoded <= 1 || encoded >= ArraySize(g_model_encode_scratch)) { ModelFail("ROW_ENCODING"); return false; }
  g_model_encode_scratch[encoded - 1] = 13;
  g_model_encode_scratch[encoded] = 10;
  int bytes = encoded + 1;
  if(g_model_buffers[file].used > 0 && bytes > MODEL_BATCH_BYTES - g_model_buffers[file].used)
    if(!ModelFlush(file, sealing)) return false;
  int offset = 0;
  while(offset < bytes)
  {
    int count = (int)MathMin(bytes - offset, MODEL_BATCH_BYTES - g_model_buffers[file].used);
    if(ArrayCopy(g_model_buffers[file].bytes, g_model_encode_scratch, g_model_buffers[file].used, offset, count) != count)
    { ModelFail("BUFFER_COPY"); return false; }
    g_model_buffers[file].used += count;
    offset += count;
    if(offset == bytes)
    {
      g_model_rows[file]++;
      g_model_buffers[file].rows++;
      if(g_model_buffers[file].rows > g_model_buffer_peak) g_model_buffer_peak = g_model_buffers[file].rows;
    }
    if(g_model_buffers[file].used == MODEL_BATCH_BYTES || g_model_buffers[file].rows == MODEL_FLUSH_ROWS)
      if(!ModelFlush(file, sealing)) return false;
  }
  return true;
}

void ModelMetadata(const int file, const string key, const string value, const bool sealing = false)
{
  ModelRow row;
  row.Init(file);
  row.Set(file == MODEL_RUN_MANIFEST ? MODEL_F_RUN_MANIFEST_KEY : MODEL_F_RUN_SUMMARY_KEY, key);
  row.Set(file == MODEL_RUN_MANIFEST ? MODEL_F_RUN_MANIFEST_VALUE : MODEL_F_RUN_SUMMARY_VALUE, value);
  if(!ModelWrite(row, sealing) && !g_model_failed) ModelFail("METADATA_" + key);
}

bool ModelRunIdValid(const string id)
{
  int length = StringLen(id);
  if(length < 1 || length > 64 || StringFind(id, "..") >= 0 || StringGetCharacter(id, 0) == '.') return false;
  for(int i = 0; i < length; i++)
  {
    ushort c = StringGetCharacter(id, i);
    if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false;
  }
  return true;
}

string ModelSafeMetadata(const string value) { return value == "" ? "UNKNOWN" : value; }

bool ModelSpecification(string &text, const bool write_manifest)
{
  text = "";
  ENUM_SYMBOL_INFO_DOUBLE doubles[] = {SYMBOL_POINT, SYMBOL_TRADE_TICK_SIZE, SYMBOL_VOLUME_MIN,
    SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP, SYMBOL_TRADE_CONTRACT_SIZE};
  string double_names[] = {"point", "tick_size", "volume_min", "volume_max", "volume_step", "contract_size"};
  for(int i = 0; i < ArraySize(doubles); i++)
  {
    double value = 0.0;
    if(!SymbolInfoDouble(g_model_config.symbol, doubles[i], value) || !ModelNumberValid(value) || value <= 0.0) return false;
    ModelCell(text, ModelNumber(value));
    if(write_manifest) ModelMetadata(MODEL_RUN_MANIFEST, double_names[i], ModelNumber(value));
    if(i == 0 && write_manifest) g_model_point = value;
    if(i == 1 && write_manifest) g_model_tick_size = value;
  }
  ENUM_SYMBOL_INFO_INTEGER integers[] = {SYMBOL_DIGITS, SYMBOL_TRADE_CALC_MODE, SYMBOL_CHART_MODE};
  string integer_names[] = {"digits", "calculation_mode", "chart_mode"};
  for(int i = 0; i < ArraySize(integers); i++)
  {
    long value = 0;
    if(!SymbolInfoInteger(g_model_config.symbol, integers[i], value)) return false;
    ModelCell(text, ModelInteger(value));
    if(write_manifest) ModelMetadata(MODEL_RUN_MANIFEST, integer_names[i], ModelInteger(value));
  }
  ENUM_SYMBOL_INFO_STRING strings[] = {SYMBOL_CURRENCY_BASE, SYMBOL_CURRENCY_PROFIT, SYMBOL_CURRENCY_MARGIN};
  string string_names[] = {"base_currency", "profit_currency", "margin_currency"};
  for(int i = 0; i < ArraySize(strings); i++)
  {
    string value;
    if(!SymbolInfoString(g_model_config.symbol, strings[i], value)) return false;
    value = ModelSafeMetadata(value);
    ModelCell(text, value);
    if(write_manifest) ModelMetadata(MODEL_RUN_MANIFEST, string_names[i], value);
  }
  string currency = ModelSafeMetadata(AccountInfoString(ACCOUNT_CURRENCY));
  ModelCell(text, currency);
  if(write_manifest) ModelMetadata(MODEL_RUN_MANIFEST, "account_currency", currency);
  return true;
}

bool ModelOpen(const ModelCaptureConfig &config)
{
  g_model_config = config;
  ArrayInitialize(g_model_rows, 0);
  if(!config.enabled) return true;
  if(!ModelRunIdValid(config.run_id) || !ModelInitLayouts() || !ModelCellValid(config.symbol))
  {
    ModelFail("INITIALIZATION_PARAMETERS");
    return false;
  }
  string candidate = MODEL_STORAGE_ROOT + "\\runs\\" + config.run_id + "\\";
  string found;
  long search = FileFindFirst(candidate + "*", found, FILE_COMMON);
  if(search != INVALID_HANDLE)
  {
    FileFindClose(search);
    ModelFail("RUN_ID_EXISTS");
    return false;
  }
  g_model_root = candidate;
  for(int file = 0; file < MODEL_FILE_COUNT; file++)
  {
    if(!ModelEngineFile(file, config.engine)) continue;
    int handle = FileOpen(g_model_root + ModelFileName(file), FILE_WRITE | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
    if(handle == INVALID_HANDLE) { ModelFail("CREATE_" + ModelFileName(file)); return false; }
    bool ok = ModelWriteBytes(handle, ModelHeader(file) + "\r\n");
    FileClose(handle);
    if(!ok) { ModelFail("INITIAL_HEADER_" + ModelFileName(file)); return false; }
  }
  g_model_open = true;
  bool candle = ModelEngineKind(config.engine) == "CANDLE";
  if(ModelEngineKind(config.engine) == "") { ModelFail("UNKNOWN_ENGINE"); return false; }
  string keys[] = {"dataset_family", "schema_version", "engine", "feature_set", "extension_version", "outcome_policy",
    "run_id", "producer_version", "compiler_build", "symbol", "broker", "feed", "canonical_symbol", "mapping_status",
    "macro_seconds", "micro_seconds", "structure_seconds", "bands_period", "bands_shift", "bands_deviation", "bands_price",
    "stochastic_k", "stochastic_d", "stochastic_slowing", "stochastic_method", "stochastic_price", "atr_period", "atr_multiplier",
    "average_period", "feature_shifts", "warmup_limit", "catchup_limit", "structure_policy", "broker_session", "broker_time_basis",
    "analysis_clock_policy", "lot_type", "lot_size", "reference_balance", "broker_cap", "virtual_cap", "protection", "expiry", "reentry", "ratios"};
  string values[] = {"MQL5_MODEL_FEATURES", "1", config.engine, "macro_micro_standard_v1", "1",
    ModelOutcomePolicy(config.engine), config.run_id, ModelProducerVersion(config.engine), ModelInteger(__MQLBUILD__),
    config.symbol, ModelSafeMetadata(AccountInfoString(ACCOUNT_COMPANY)), ModelSafeMetadata(AccountInfoString(ACCOUNT_SERVER)), "UNMAPPED", "UNMAPPED",
    ModelInteger(PeriodSeconds(config.macro)), ModelInteger(PeriodSeconds(config.micro)), "60", "21", "0", "2", "PRICE_WEIGHTED",
    "5", "3", "3", "MODE_SMA", "STO_CLOSECLOSE", "13", "1", "5", "6", "4096", "256", "STOCHASTIC_CLOSE_M1_V1",
    config.exness ? "EXNESS_SESSION" : "FIXED_TIME_SESSIONS", config.exness ? "UTC_SHIFT_0" : "BROKER_NATIVE",
    config.exness ? "EXNESS_NEW_YORK_V1" : "BROKER_FIXED_V1", config.lot_type, ModelNumber(config.lot_size), ModelNumber(config.reference_balance),
    ModelInteger(config.broker_cap), ModelInteger(config.virtual_cap), "FIXED_SUBMITTED", ModelExpiryPolicy(config.engine),
    candle ? "BROKER_SL_ONCE" : "NONE", candle ? "1,2,3" : "1,2,3,5"};
  if(ArraySize(keys) != ArraySize(values)) { ModelFail("MANIFEST_LAYOUT"); return false; }
  ulong fingerprint = 0xcbf29ce484222325;
  for(int i = 0; i < ArraySize(keys); i++)
  {
    ModelMetadata(MODEL_RUN_MANIFEST, keys[i], values[i]);
    if(keys[i] != "run_id") fingerprint = ModelFingerprint(fingerprint, keys[i] + "=" + values[i] + "\n");
  }
  if(!ModelSpecification(g_model_specification, true)) { ModelFail("INSTRUMENT_SPECIFICATION"); return false; }
  fingerprint = ModelFingerprint(fingerprint, g_model_specification);
  ModelMetadata(MODEL_RUN_MANIFEST, "config_id", ModelFingerprintText(fingerprint));
  return !g_model_failed && ModelFlush(MODEL_RUN_MANIFEST);
}

bool ModelCheckSpecification()
{
  string current;
  if(!ModelSpecification(current, false) || current != g_model_specification)
  {
    ModelFail("INSTRUMENT_SPECIFICATION_CHANGED");
    return false;
  }
  return true;
}

void ModelSummaryClock(const string key, const long raw, const bool seconds)
{
  string prefix = StringSubstr(key, 0, StringLen(key) - 8);
  long analysis = 0;
  int offset = 0;
  bool available = raw > 0 && ModelAnalysisClock(raw, g_model_config.exness, analysis, offset);
  if(raw > 0 && !available) ModelFail("SUMMARY_CLOCK");
  ModelMetadata(MODEL_RUN_SUMMARY, key, available ? ModelInteger(raw) : "NONE", true);
  ModelMetadata(MODEL_RUN_SUMMARY, prefix + "analysis_time_msc", available ? ModelInteger(analysis) : "NONE", true);
  ModelMetadata(MODEL_RUN_SUMMARY, prefix + "offset_minutes", available ? ModelInteger(offset) : "NONE", true);
  ModelMetadata(MODEL_RUN_SUMMARY, prefix + "precision", available ? (seconds ? "SECOND" : "MILLISECOND") : "NONE", true);
}

void ModelStopTesterIfFailed()
{
  if(g_model_failed && MQLInfoInteger(MQL_TESTER) && !g_model_stop_sent)
  {
    g_model_stop_sent = true;
    TesterStop();
  }
}

#endif
