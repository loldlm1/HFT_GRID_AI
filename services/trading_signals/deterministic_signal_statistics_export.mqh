//+------------------------------------------------------------------+
//|       trading_signals/deterministic_signal_statistics_export.mqh |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_STATS_EXPORT_MQH_
#define _TS_DETERMINISTIC_STATS_EXPORT_MQH_

const int    DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 4;
const string DETERMINISTIC_SIGNAL_STATS_STORAGE_ROOT   = "DeterministicSignalML";
const string DETERMINISTIC_SIGNAL_STATS_RUNS_FOLDER    = "runs";
const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_FILE  = "run_manifest.tsv";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE  = "signal_features.tsv";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE  = "signal_outcomes.tsv";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_FILE   = "run_summary.tsv";
const string DETERMINISTIC_SIGNAL_STATS_NULL           = "\\N";
const ushort DETERMINISTIC_SIGNAL_STATS_DELIMITER      = '\t';
const int    DETERMINISTIC_SIGNAL_STATS_FLUSH_ROWS     = 32;

const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_label\tdirection\tentry_time\tsource_time\tstructure_0\tstructure_1\tstructure_2\tmacro_h1_slope\tmacro_h4_slope\tmacro_d1_slope\tfib_sl_band\tfib_entry_band\thigh_chain_profile\tlow_chain_profile\tprevious_candle_profile\tentry_session_bucket\tentry_weekday";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tterminal_time\tterminal_reason\tprofit_r\tduration_seconds\tduration_m1_bars\tentry_price\tclose_price\tnet_profit";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_at\tfinished_at\tfeature_rows\toutcome_rows\tfeature_invalid_rows\toutcome_invalid_rows\texport_status";

string   g_deterministic_signal_stats_run_id = "";
string   g_deterministic_signal_stats_config_id = "";
string   g_deterministic_signal_stats_folder = "";
datetime g_deterministic_signal_stats_started_at = 0;
bool     g_deterministic_signal_stats_initialized = false;
bool     g_deterministic_signal_stats_failed = false;
int      g_deterministic_signal_stats_feature_rows = 0;
int      g_deterministic_signal_stats_outcome_rows = 0;
int      g_deterministic_signal_stats_feature_invalid_rows = 0;
int      g_deterministic_signal_stats_outcome_invalid_rows = 0;
string   g_deterministic_signal_stats_feature_buffer[];
string   g_deterministic_signal_stats_outcome_buffer[];

bool DeterministicSignalStatsEnabled()
{
  return Enable_Signal_Feature_Export;
}

string DeterministicSignalStatsBoolToken(const bool value)
{
  return value ? "1" : "0";
}

string DeterministicSignalStatsTimeToken(const datetime value)
{
  if(value <= 0)
    return DETERMINISTIC_SIGNAL_STATS_NULL;

  return TimeToString(value, TIME_DATE|TIME_SECONDS);
}

string DeterministicSignalStatsSanitizePart(const string raw_value)
{
  string value = raw_value;
  if(value == "")
    value = "default";

  string result = "";
  int total = StringLen(value);
  for(int i = 0; i < total; i++)
  {
    ushort ch = StringGetCharacter(value, i);
    bool is_digit = (ch >= '0' && ch <= '9');
    bool is_upper = (ch >= 'A' && ch <= 'Z');
    bool is_lower = (ch >= 'a' && ch <= 'z');
    bool is_safe = is_digit || is_upper || is_lower || ch == '_' || ch == '-' || ch == '.';
    if(is_safe)
      result = result + StringSubstr(value, i, 1);
    else
      result = result + "_";
  }

  if(result == "")
    result = "default";
  return result;
}

string DeterministicSignalStatsCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  if(value == "")
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return value;
}

ulong DeterministicSignalStatsHash(const string input_value)
{
  ulong hash = 1469598103934665603;
  int total = StringLen(input_value);
  for(int i = 0; i < total; i++)
  {
    hash ^= (ulong)StringGetCharacter(input_value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string DeterministicSignalStatsHashToken(const string input_value)
{
  ulong hash = DeterministicSignalStatsHash(input_value);
  return StringFormat("%I64u", hash);
}

string DeterministicSignalStatsBuildConfigPayload()
{
  return StringFormat("schema=%d|symbol=%s|period=%d|base_tf=%d|ma=%d|stoch=%d,%d,%d|s1=%s|s2=%s|s3=%s|direction=%d|concurrency=%d|lot_type=%d|lot_size=%.8f|lot_mult=%.8f|lot_strategy=%d|tp=%.8f|daily_limit=%d|daily_mode=%d|asia=%d|london=%d|newyork=%d|dst=%d",
                      DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION,
                      _Symbol,
                      (int)_Period,
                      (int)DETERMINISTIC_BASE_TIMEFRAME,
                      DETERMINISTIC_MA_PERIOD,
                      DETERMINISTIC_STOCH_K,
                      DETERMINISTIC_STOCH_D,
                      DETERMINISTIC_STOCH_SLOWING,
                      DeterministicSignalStatsBoolToken(Enable_Strategy_1),
                      DeterministicSignalStatsBoolToken(Enable_Strategy_2),
                      DeterministicSignalStatsBoolToken(Enable_Strategy_3),
                      (int)Strategy_Direction_Mode,
                      (int)Signal_Concurrency_Mode,
                      (int)Lot_Type,
                      Lot_Strategy_Size,
                      Lot_Multiplier,
                      (int)Signal_Lot_Strategy,
                      TP_Percent,
                      Daily_Signal_Limit,
                      (int)Daily_Signal_Limit_Mode,
                      (int)Session_Asia_Filter_Mode,
                      (int)Session_London_Filter_Mode,
                      (int)Session_NewYork_Filter_Mode,
                      (int)Session_Time_Dst_Mode);
}

string DeterministicSignalStatsBuildConfigId()
{
  return "cfg_" + DeterministicSignalStatsHashToken(DeterministicSignalStatsBuildConfigPayload());
}

string DeterministicSignalStatsBuildRunId()
{
  if(Signal_Feature_Run_Id != "")
    return DeterministicSignalStatsSanitizePart(Signal_Feature_Run_Id);

  string time_token = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
  return DeterministicSignalStatsSanitizePart(StringFormat("%s_%s_%d",
                                                           time_token,
                                                           _Symbol,
                                                           (int)_Period));
}

string DeterministicSignalStatsBuildRunFolder()
{
  return DETERMINISTIC_SIGNAL_STATS_STORAGE_ROOT + "\\" +
         DETERMINISTIC_SIGNAL_STATS_RUNS_FOLDER + "\\" +
         g_deterministic_signal_stats_run_id;
}

string DeterministicSignalStatsPath(const string filename)
{
  return g_deterministic_signal_stats_folder + "\\" + filename;
}

bool DeterministicSignalStatsEnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_deterministic_signal_stats_folder, delimiter, parts);
  if(total <= 0)
    return false;

  string current_folder = "";
  for(int i = 0; i < total; i++)
  {
    if(parts[i] == "")
      continue;
    if(current_folder == "")
      current_folder = parts[i];
    else
      current_folder = current_folder + "\\" + parts[i];

    ResetLastError();
    FolderCreate(current_folder, FILE_COMMON);
    int folder_error = GetLastError();
    if(folder_error != 0 && folder_error != 5019)
    {
      if(Enable_Logs || Enable_File_Logs)
      {
        PrintFormat("DETERMINISTIC_STATS_FOLDER_CREATE failed | folder=%s | err=%d",
                    current_folder,
                    folder_error);
      }
    }
  }

  return true;
}

bool DeterministicSignalStatsWriteLine(const string filename,
                                       const string line,
                                       const bool append)
{
  if(filename == "" || line == "")
    return false;

  int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
  if(append)
    flags |= FILE_READ;

  ResetLastError();
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    g_deterministic_signal_stats_failed = true;
    if(Enable_Logs || Enable_File_Logs)
    {
      PrintFormat("DETERMINISTIC_STATS_WRITE_FAIL | file=%s | err=%d",
                  filename,
                  open_error);
    }
    return false;
  }

  if(append)
    FileSeek(handle, 0, SEEK_END);

  FileWrite(handle, line);
  FileClose(handle);
  return true;
}

bool DeterministicSignalStatsAppendRow(const string filename,
                                       const string header,
                                       const string row)
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(filename == "" || header == "" || row == "")
    return false;

  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  if(needs_header)
  {
    if(!DeterministicSignalStatsWriteLine(filename, header, false))
      return false;
  }

  return DeterministicSignalStatsWriteLine(filename, row, true);
}

bool DeterministicSignalStatsFlushBuffer(const string filename,
                                         const string header,
                                         string &buffer[])
{
  if(!DeterministicSignalStatsReady())
    return false;

  int total = ArraySize(buffer);
  if(total <= 0)
    return true;

  for(int i = 0; i < total; i++)
  {
    if(!DeterministicSignalStatsAppendRow(filename, header, buffer[i]))
      return false;
  }

  ArrayResize(buffer, 0);
  return true;
}

bool DeterministicSignalStatsQueueRow(const string filename,
                                      const string header,
                                      const string row,
                                      string &buffer[])
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(filename == "" || header == "" || row == "")
    return false;

  int total = ArraySize(buffer);
  int resized = ArrayResize(buffer,
                            total + 1,
                            DETERMINISTIC_SIGNAL_STATS_FLUSH_ROWS);
  if(resized != total + 1)
  {
    g_deterministic_signal_stats_failed = true;
    return false;
  }

  buffer[total] = row;
  if(ArraySize(buffer) >= DETERMINISTIC_SIGNAL_STATS_FLUSH_ROWS)
    return DeterministicSignalStatsFlushBuffer(filename, header, buffer);

  return true;
}

bool DeterministicSignalStatsFlushFeatures()
{
  return DeterministicSignalStatsFlushBuffer(DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE),
                                            DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER,
                                            g_deterministic_signal_stats_feature_buffer);
}

bool DeterministicSignalStatsFlushOutcomes()
{
  return DeterministicSignalStatsFlushBuffer(DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE),
                                            DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER,
                                            g_deterministic_signal_stats_outcome_buffer);
}

bool DeterministicSignalStatsFlushAll()
{
  if(!DeterministicSignalStatsReady())
    return false;

  bool features_ok = DeterministicSignalStatsFlushFeatures();
  bool outcomes_ok = DeterministicSignalStatsFlushOutcomes();
  return features_ok && outcomes_ok;
}

string DeterministicSignalStatsManifestRow(const string key,
                                           const string value)
{
  return IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
         DeterministicSignalStatsCell(key) + "\t" +
         DeterministicSignalStatsCell(value);
}

bool DeterministicSignalStatsWriteManifest()
{
  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_MANIFEST_FILE);
  if(!DeterministicSignalStatsWriteLine(filename,
                                        DETERMINISTIC_SIGNAL_STATS_MANIFEST_HEADER,
                                        false))
    return false;

  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("run_id", g_deterministic_signal_stats_run_id), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("config_id", g_deterministic_signal_stats_config_id), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("started_at", DeterministicSignalStatsTimeToken(g_deterministic_signal_stats_started_at)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("symbol", _Symbol), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("period", EnumToString(_Period)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("base_timeframe", EnumToString(DETERMINISTIC_BASE_TIMEFRAME)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("ma_period", IntegerToString(DETERMINISTIC_MA_PERIOD)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("stoch", StringFormat("%d,%d,%d", DETERMINISTIC_STOCH_K, DETERMINISTIC_STOCH_D, DETERMINISTIC_STOCH_SLOWING)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("enable_strategy_1", DeterministicSignalStatsBoolToken(Enable_Strategy_1)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("enable_strategy_2", DeterministicSignalStatsBoolToken(Enable_Strategy_2)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("enable_strategy_3", DeterministicSignalStatsBoolToken(Enable_Strategy_3)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("direction_mode", EnumToString(Strategy_Direction_Mode)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("concurrency_mode", EnumToString(Signal_Concurrency_Mode)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("tp_percent", DoubleToString(TP_Percent, 2)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("feature_policy", "broker_entered_only"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("invalid_numeric_token", DETERMINISTIC_SIGNAL_STATS_NULL), true);
  return true;
}

bool DeterministicSignalStatsPrepareRowFiles()
{
  string features_filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE);
  string outcomes_filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE);

  if(!DeterministicSignalStatsWriteLine(features_filename,
                                        DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER,
                                        false))
    return false;

  if(!DeterministicSignalStatsWriteLine(outcomes_filename,
                                        DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER,
                                        false))
    return false;

  return true;
}

string DeterministicSignalStatsSummaryRow(const datetime finished_at,
                                          const string export_status)
{
  return IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
         DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
         DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
         DeterministicSignalStatsTimeToken(g_deterministic_signal_stats_started_at) + "\t" +
         DeterministicSignalStatsTimeToken(finished_at) + "\t" +
         IntegerToString(g_deterministic_signal_stats_feature_rows) + "\t" +
         IntegerToString(g_deterministic_signal_stats_outcome_rows) + "\t" +
         IntegerToString(g_deterministic_signal_stats_feature_invalid_rows) + "\t" +
         IntegerToString(g_deterministic_signal_stats_outcome_invalid_rows) + "\t" +
         DeterministicSignalStatsCell(export_status);
}

bool DeterministicSignalStatsWriteSummary()
{
  if(!DeterministicSignalStatsEnabled() ||
     !g_deterministic_signal_stats_initialized)
    return false;

  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_SUMMARY_FILE);
  if(!DeterministicSignalStatsWriteLine(filename,
                                        DETERMINISTIC_SIGNAL_STATS_SUMMARY_HEADER,
                                        false))
    return false;

  string status = g_deterministic_signal_stats_failed ? "FAILED" : "OK";
  return DeterministicSignalStatsWriteLine(filename,
                                          DeterministicSignalStatsSummaryRow(TimeCurrent(),
                                                                            status),
                                          true);
}

void DeterministicSignalStatsReset()
{
  g_deterministic_signal_stats_run_id = "";
  g_deterministic_signal_stats_config_id = "";
  g_deterministic_signal_stats_folder = "";
  g_deterministic_signal_stats_started_at = 0;
  g_deterministic_signal_stats_initialized = false;
  g_deterministic_signal_stats_failed = false;
  g_deterministic_signal_stats_feature_rows = 0;
  g_deterministic_signal_stats_outcome_rows = 0;
  g_deterministic_signal_stats_feature_invalid_rows = 0;
  g_deterministic_signal_stats_outcome_invalid_rows = 0;
  ArrayResize(g_deterministic_signal_stats_feature_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_outcome_buffer, 0);
}

bool DeterministicSignalStatsInit()
{
  DeterministicSignalStatsReset();
  if(!DeterministicSignalStatsEnabled())
    return true;

  g_deterministic_signal_stats_started_at = TimeCurrent();
  g_deterministic_signal_stats_run_id = DeterministicSignalStatsBuildRunId();
  g_deterministic_signal_stats_config_id = DeterministicSignalStatsBuildConfigId();
  g_deterministic_signal_stats_folder = DeterministicSignalStatsBuildRunFolder();

  if(!DeterministicSignalStatsEnsureFolder())
  {
    g_deterministic_signal_stats_failed = true;
    return false;
  }

  g_deterministic_signal_stats_initialized = DeterministicSignalStatsWriteManifest();
  if(g_deterministic_signal_stats_initialized)
    g_deterministic_signal_stats_initialized = DeterministicSignalStatsPrepareRowFiles();
  return g_deterministic_signal_stats_initialized;
}

bool DeterministicSignalStatsReady()
{
  return DeterministicSignalStatsEnabled() &&
         g_deterministic_signal_stats_initialized &&
         !g_deterministic_signal_stats_failed;
}

void DeterministicSignalStatsDeinit()
{
  if(!DeterministicSignalStatsEnabled() ||
     !g_deterministic_signal_stats_initialized)
    return;

  if(!DeterministicSignalStatsFlushAll())
    g_deterministic_signal_stats_failed = true;

  DeterministicSignalStatsWriteSummary();
  ArrayResize(g_deterministic_signal_stats_feature_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_outcome_buffer, 0);
}

string DeterministicSignalStatsBuildSignalId(const SignalParams &signal_params)
{
  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildDeterministicSignalSourceKey(signal_params);

  string payload = g_deterministic_signal_stats_run_id + "|" +
                   source_key + "|" +
                   IntegerToString(signal_params.deterministic_source_attempt_index);
  return "sig_" + DeterministicSignalStatsHashToken(payload);
}

string DeterministicSignalStatsEnsureSignalId(SignalParams &signal_params)
{
  if(signal_params.deterministic_stats_signal_id == "" &&
     DeterministicSignalStatsReady() &&
     signal_params.deterministic_strategy)
  {
    signal_params.deterministic_stats_signal_id = DeterministicSignalStatsBuildSignalId(signal_params);
  }

  return signal_params.deterministic_stats_signal_id;
}

string DeterministicSignalStatsDirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BULLISH";
  if(direction == BEARISH)
    return "BEARISH";
  return "NONE";
}

string DeterministicSignalStatsSourceTypeToken(const SignalParams &signal_params)
{
  return signal_params.source_extremum_is_peak ? "PEAK" : "BOTTOM";
}

string DeterministicSignalStatsIntToken(const bool valid,
                                        const int value)
{
  if(!valid)
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return IntegerToString(value);
}

string DeterministicSignalStatsDoubleToken(const bool valid,
                                           const double value,
                                           const int digits)
{
  if(!valid || !MathIsValidNumber(value))
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return DoubleToString(value, digits);
}

int DeterministicSignalStatsMacroDir(const ENUM_TIMEFRAMES timeframe)
{
  double ma_now = 0.0;
  double ma_prev = 0.0;
  if(!CopyDeterministicMaSlopeValues(timeframe, 0, ma_now, ma_prev))
    return 0;

  double eps = 0.0000000001;
  if(ma_now > ma_prev + eps)
    return 1;
  if(ma_now < ma_prev - eps)
    return -1;
  return 0;
}

bool DeterministicSignalStatsStructurePrice(const OscillatorMarketStructure &structure,
                                            const bool peak_price,
                                            double &price_out)
{
  price_out = peak_price ? structure.extremum_high : structure.extremum_low;
  return (price_out > 0.0 &&
          price_out != DBL_MAX &&
          price_out != -DBL_MAX &&
          MathIsValidNumber(price_out));
}

bool DeterministicSignalStatsResolveFibonacciRange(const SignalParams &signal_params,
                                                   double &peak_price_out,
                                                   double &bottom_price_out,
                                                   bool &source_is_peak_out)
{
  peak_price_out = 0.0;
  bottom_price_out = 0.0;
  source_is_peak_out = signal_params.source_extremum_is_peak;

  if(!signal_params.base_structure_valid)
    return false;

  int total = ArraySize(signal_params.base_structure_data.os_market_structures);
  if(total < 3)
    return false;

  OscillatorMarketStructure source = signal_params.base_structure_data.os_market_structures[0];
  OscillatorMarketStructure opposite = signal_params.base_structure_data.os_market_structures[1];
  OscillatorMarketStructure same_previous = signal_params.base_structure_data.os_market_structures[2];

  if(source.is_peak != source_is_peak_out)
    return false;
  if(opposite.is_peak == source.is_peak)
    return false;
  if(same_previous.is_peak != source.is_peak)
    return false;

  if(source_is_peak_out)
  {
    if(!DeterministicSignalStatsStructurePrice(same_previous, true, peak_price_out))
      return false;
    if(!DeterministicSignalStatsStructurePrice(opposite, false, bottom_price_out))
      return false;
  }
  else
  {
    if(!DeterministicSignalStatsStructurePrice(opposite, true, peak_price_out))
      return false;
    if(!DeterministicSignalStatsStructurePrice(same_previous, false, bottom_price_out))
      return false;
  }

  return (peak_price_out > bottom_price_out);
}

string DeterministicSignalStatsStructureTypeToken(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HH: return "HH";
    case OSCILLATOR_STRUCTURE_HL: return "HL";
    case OSCILLATOR_STRUCTURE_LH: return "LH";
    case OSCILLATOR_STRUCTURE_LL: return "LL";
    case OSCILLATOR_STRUCTURE_EQ: return "EQ";
  }
  return "EQ";
}

bool DeterministicSignalStatsResolveStructureTypes(const SignalParams &signal_params,
                                                   string &source_type_out,
                                                   string &opposite_type_out,
                                                   string &same_previous_type_out)
{
  source_type_out = "";
  opposite_type_out = "";
  same_previous_type_out = "";

  if(!signal_params.base_structure_valid)
    return false;

  int extrema_total = ArraySize(signal_params.base_structure_data.os_market_structures);
  int stats_total = ArraySize(signal_params.base_structure_data.extremum_stats);
  if(extrema_total < 3 || stats_total < 3)
    return false;

  OscillatorMarketStructure source = signal_params.base_structure_data.os_market_structures[0];
  OscillatorMarketStructure opposite = signal_params.base_structure_data.os_market_structures[1];
  OscillatorMarketStructure same_previous = signal_params.base_structure_data.os_market_structures[2];

  if(source.is_peak != signal_params.source_extremum_is_peak)
    return false;
  if(opposite.is_peak == source.is_peak)
    return false;
  if(same_previous.is_peak != source.is_peak)
    return false;
  if(source.extremum_time != signal_params.source_extremum_time)
    return false;

  source_type_out = DeterministicSignalStatsStructureTypeToken(signal_params.base_structure_data.extremum_stats[0].structure_type);
  opposite_type_out = DeterministicSignalStatsStructureTypeToken(signal_params.base_structure_data.extremum_stats[1].structure_type);
  same_previous_type_out = DeterministicSignalStatsStructureTypeToken(signal_params.base_structure_data.extremum_stats[2].structure_type);
  return true;
}

bool DeterministicSignalStatsFibonacciPercent(const double peak_price,
                                              const double bottom_price,
                                              const bool source_is_peak,
                                              const double price,
                                              double &percent_out)
{
  percent_out = 0.0;
  if(peak_price <= bottom_price || price <= 0.0)
    return false;

  if(source_is_peak)
    percent_out = ((price - bottom_price) / (peak_price - bottom_price)) * 100.0;
  else
    percent_out = ((peak_price - price) / (peak_price - bottom_price)) * 100.0;

  return MathIsValidNumber(percent_out);
}

string DeterministicSignalStatsFibonacciLevelToken(const double value)
{
  double normalized = NormalizeDouble(value, 1);
  if(MathAbs(normalized) < 0.00001)
    normalized = 0.0;
  return DoubleToString(normalized, 1);
}

bool DeterministicSignalStatsFibonacciBand(const double percent,
                                           string &band_out)
{
  band_out = DETERMINISTIC_SIGNAL_STATS_NULL;
  if(!MathIsValidNumber(percent))
    return false;

  double cycle = 100.0;
  double base = MathFloor(percent / cycle) * cycle;
  double cursor = percent - base;
  double eps = 0.000001;
  double levels[4] = {0.0, 38.2, 61.8, 100.0};

  for(int i = 0; i < 3; i++)
  {
    double lower = levels[i];
    double upper = levels[i + 1];
    if(cursor >= lower - eps && cursor <= upper + eps)
    {
      band_out = DeterministicSignalStatsFibonacciLevelToken(base + lower) + "_" +
                 DeterministicSignalStatsFibonacciLevelToken(base + upper);
      return true;
    }
  }

  return false;
}

bool DeterministicSignalStatsStrictChainMatch(const MqlRates &rates[],
                                              const int copied,
                                              const int window,
                                              const bool use_high,
                                              const bool rising)
{
  if(window <= 0 || copied < window + 1)
    return false;

  for(int i = 0; i < window; i++)
  {
    double current_value = use_high ? rates[i].high : rates[i].low;
    double previous_value = use_high ? rates[i + 1].high : rates[i + 1].low;
    if(current_value <= 0.0 || previous_value <= 0.0)
      return false;

    if(rising)
    {
      if(current_value <= previous_value)
        return false;
    }
    else
    {
      if(current_value >= previous_value)
        return false;
    }
  }

  return true;
}

bool DeterministicSignalStatsChainProfile(const MqlRates &rates[],
                                          const int copied,
                                          const bool use_high,
                                          string &profile_out)
{
  string prefix = use_high ? "HIGH" : "LOW";
  profile_out = prefix + "_MIXED";
  if(copied < 4)
    return false;

  int windows[3] = {10, 5, 3};
  for(int i = 0; i < 3; i++)
  {
    int window = windows[i];
    if(DeterministicSignalStatsStrictChainMatch(rates, copied, window, use_high, true))
    {
      profile_out = prefix + "_UP_" + IntegerToString(window);
      return true;
    }
    if(DeterministicSignalStatsStrictChainMatch(rates, copied, window, use_high, false))
    {
      profile_out = prefix + "_DOWN_" + IntegerToString(window);
      return true;
    }
  }

  return true;
}

bool DeterministicSignalStatsPreviousCandleFeatures(const MqlRates &rate,
                                                    double &body_ratio_out,
                                                    double &upper_wick_ratio_out,
                                                    double &lower_wick_ratio_out,
                                                    double &close_location_out,
                                                    string &candle_dir_out)
{
  body_ratio_out = 0.0;
  upper_wick_ratio_out = 0.0;
  lower_wick_ratio_out = 0.0;
  close_location_out = 0.0;
  candle_dir_out = "";

  if(rate.high <= 0.0 || rate.low <= 0.0 || rate.high < rate.low)
    return false;

  double range = rate.high - rate.low;
  if(range <= 0.0 || !MathIsValidNumber(range))
    return false;

  double open_price = rate.open;
  double close_price = rate.close;
  if(open_price <= 0.0 || close_price <= 0.0)
    return false;

  double body = MathAbs(close_price - open_price);
  double upper_wick = rate.high - MathMax(open_price, close_price);
  double lower_wick = MathMin(open_price, close_price) - rate.low;
  if(upper_wick < 0.0)
    upper_wick = 0.0;
  if(lower_wick < 0.0)
    lower_wick = 0.0;

  body_ratio_out = body / range;
  upper_wick_ratio_out = upper_wick / range;
  lower_wick_ratio_out = lower_wick / range;
  close_location_out = (close_price - rate.low) / range;

  if(!MathIsValidNumber(body_ratio_out) ||
     !MathIsValidNumber(upper_wick_ratio_out) ||
     !MathIsValidNumber(lower_wick_ratio_out) ||
     !MathIsValidNumber(close_location_out))
    return false;

  double eps = 0.0000000001;
  if(close_price > open_price + eps)
    candle_dir_out = "BULL";
  else if(close_price < open_price - eps)
    candle_dir_out = "BEAR";
  else
    candle_dir_out = "DOJI";

  return true;
}

bool DeterministicSignalStatsPreviousCandleProfile(const MqlRates &rate,
                                                   string &profile_out)
{
  profile_out = DETERMINISTIC_SIGNAL_STATS_NULL;

  double body_ratio = 0.0;
  double upper_wick_ratio = 0.0;
  double lower_wick_ratio = 0.0;
  double close_location = 0.0;
  string candle_dir = "";
  if(!DeterministicSignalStatsPreviousCandleFeatures(rate,
                                                     body_ratio,
                                                     upper_wick_ratio,
                                                     lower_wick_ratio,
                                                     close_location,
                                                     candle_dir))
    return false;

  if(body_ratio < 0.10)
  {
    profile_out = "DOJI";
    return true;
  }

  if(candle_dir != "BULL" && candle_dir != "BEAR")
  {
    profile_out = "DOJI";
    return true;
  }

  if(upper_wick_ratio >= 0.50 &&
     upper_wick_ratio >= lower_wick_ratio * 1.50)
  {
    profile_out = candle_dir + "_UPPER_WICK";
    return true;
  }

  if(lower_wick_ratio >= 0.50 &&
     lower_wick_ratio >= upper_wick_ratio * 1.50)
  {
    profile_out = candle_dir + "_LOWER_WICK";
    return true;
  }

  if(body_ratio >= 0.60)
    profile_out = candle_dir + "_BODY_HIGH";
  else if(body_ratio >= 0.25)
    profile_out = candle_dir + "_BODY_MID";
  else
    profile_out = candle_dir + "_BODY_LOW";

  return true;
}

string DeterministicSignalStatsSessionBucket(const datetime entry_time)
{
  if(entry_time <= 0)
    return "";

  MqlDateTime parts;
  TimeToStruct(entry_time, parts);
  if(parts.hour >= 0 && parts.hour < 7)
    return "ASIA";
  if(parts.hour >= 7 && parts.hour < 12)
    return "LONDON";
  if(parts.hour >= 12 && parts.hour < 21)
    return "NEWYORK";
  return "OFFHOURS";
}

string DeterministicSignalStatsWeekdayToken(const datetime entry_time)
{
  if(entry_time <= 0)
    return "";

  MqlDateTime parts;
  TimeToStruct(entry_time, parts);
  switch(parts.day_of_week)
  {
    case 1: return "MON";
    case 2: return "TUE";
    case 3: return "WED";
    case 4: return "THU";
    case 5: return "FRI";
    case 6: return "SAT";
    case 0: return "SUN";
  }

  return "";
}

struct DeterministicSignalFeatureSnapshot
{
  bool     valid;
  string   invalid_reasons;
  string   source_key;
  int      source_attempt_index;
  string   symbol;
  int      strategy_id;
  string   strategy_label;
  string   direction;
  datetime entry_time;
  datetime source_time;
  string   source_type;
  string   structure_0;
  bool     structure_0_valid;
  string   structure_1;
  bool     structure_1_valid;
  string   structure_2;
  bool     structure_2_valid;
  int      macro_h1_slope;
  int      macro_h4_slope;
  int      macro_d1_slope;
  string   fib_sl_band;
  bool     fib_sl_band_valid;
  string   fib_entry_band;
  bool     fib_entry_band_valid;
  string   high_chain_profile;
  bool     high_chain_profile_valid;
  string   low_chain_profile;
  bool     low_chain_profile_valid;
  string   previous_candle_profile;
  bool     previous_candle_profile_valid;
  string   entry_session_bucket;
  bool     entry_session_bucket_valid;
  string   entry_weekday;
  bool     entry_weekday_valid;

  DeterministicSignalFeatureSnapshot()
  {
    valid = false;
    invalid_reasons = "";
    source_key = "";
    source_attempt_index = 0;
    symbol = "";
    strategy_id = DETERMINISTIC_STRATEGY_NONE;
    strategy_label = "";
    direction = "";
    entry_time = 0;
    source_time = 0;
    source_type = "";
    structure_0 = DETERMINISTIC_SIGNAL_STATS_NULL;
    structure_0_valid = false;
    structure_1 = DETERMINISTIC_SIGNAL_STATS_NULL;
    structure_1_valid = false;
    structure_2 = DETERMINISTIC_SIGNAL_STATS_NULL;
    structure_2_valid = false;
    macro_h1_slope = 0;
    macro_h4_slope = 0;
    macro_d1_slope = 0;
    fib_sl_band = DETERMINISTIC_SIGNAL_STATS_NULL;
    fib_sl_band_valid = false;
    fib_entry_band = DETERMINISTIC_SIGNAL_STATS_NULL;
    fib_entry_band_valid = false;
    high_chain_profile = DETERMINISTIC_SIGNAL_STATS_NULL;
    high_chain_profile_valid = false;
    low_chain_profile = DETERMINISTIC_SIGNAL_STATS_NULL;
    low_chain_profile_valid = false;
    previous_candle_profile = DETERMINISTIC_SIGNAL_STATS_NULL;
    previous_candle_profile_valid = false;
    entry_session_bucket = DETERMINISTIC_SIGNAL_STATS_NULL;
    entry_session_bucket_valid = false;
    entry_weekday = DETERMINISTIC_SIGNAL_STATS_NULL;
    entry_weekday_valid = false;
  }
};

void DeterministicSignalFeatureSnapshotAddInvalid(DeterministicSignalFeatureSnapshot &snapshot,
                                                  const string reason)
{
  snapshot.valid = false;
  if(snapshot.invalid_reasons != "")
    snapshot.invalid_reasons = snapshot.invalid_reasons + ",";
  snapshot.invalid_reasons = snapshot.invalid_reasons + reason;
}

bool DeterministicSignalBuildFeatureSnapshot(SignalParams &signal_params,
                                             const ExecutionLegState &leg_state,
                                             DeterministicSignalFeatureSnapshot &snapshot)
{
  snapshot = DeterministicSignalFeatureSnapshot();

  if(!signal_params.deterministic_strategy)
    return false;

  snapshot.valid = true;
  snapshot.source_key = signal_params.deterministic_source_key;
  if(snapshot.source_key == "")
    snapshot.source_key = BuildDeterministicSignalSourceKey(signal_params);
  snapshot.source_attempt_index = signal_params.deterministic_source_attempt_index;
  snapshot.symbol = _Symbol;
  snapshot.strategy_id = signal_params.strategy_id;
  snapshot.strategy_label = signal_params.strategy_label;
  snapshot.direction = DeterministicSignalStatsDirectionToken(signal_params.signal_type);
  snapshot.entry_time = leg_state.last_action_time;
  if(snapshot.entry_time <= 0)
    snapshot.entry_time = TimeCurrent();
  snapshot.source_time = signal_params.source_extremum_time;
  snapshot.source_type = DeterministicSignalStatsSourceTypeToken(signal_params);
  snapshot.structure_0_valid =
    DeterministicSignalStatsResolveStructureTypes(signal_params,
                                                 snapshot.structure_0,
                                                 snapshot.structure_1,
                                                 snapshot.structure_2);
  snapshot.structure_1_valid = snapshot.structure_0_valid;
  snapshot.structure_2_valid = snapshot.structure_0_valid;

  snapshot.macro_h1_slope = DeterministicSignalStatsMacroDir(PERIOD_H1);
  snapshot.macro_h4_slope = DeterministicSignalStatsMacroDir(PERIOD_H4);
  snapshot.macro_d1_slope = DeterministicSignalStatsMacroDir(PERIOD_D1);

  if(!snapshot.structure_0_valid)
  {
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "structure_0");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "structure_1");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "structure_2");
  }

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool source_is_peak = false;
  bool fib_range_valid = DeterministicSignalStatsResolveFibonacciRange(signal_params,
                                                                       peak_price,
                                                                       bottom_price,
                                                                       source_is_peak);

  double sl_fib_raw = 0.0;
  bool sl_fib_valid = fib_range_valid &&
                      DeterministicSignalStatsFibonacciPercent(peak_price,
                                                               bottom_price,
                                                               source_is_peak,
                                                               signal_params.raw_stop_anchor_price,
                                                               sl_fib_raw);

  double entry_reference = signal_params.raw_entry_trigger_price;
  if(entry_reference <= 0.0)
    entry_reference = leg_state.entry_reference_price;
  double entry_fib_raw = 0.0;
  bool entry_fib_valid = fib_range_valid &&
                         DeterministicSignalStatsFibonacciPercent(peak_price,
                                                                  bottom_price,
                                                                  source_is_peak,
                                                                  entry_reference,
                                                                  entry_fib_raw);

  snapshot.fib_sl_band_valid = sl_fib_valid &&
                               DeterministicSignalStatsFibonacciBand(sl_fib_raw,
                                                                     snapshot.fib_sl_band);
  snapshot.fib_entry_band_valid = entry_fib_valid &&
                                  DeterministicSignalStatsFibonacciBand(entry_fib_raw,
                                                                        snapshot.fib_entry_band);
  if(!snapshot.fib_sl_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "fib_sl_band");
  if(!snapshot.fib_entry_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "fib_entry_band");

  MqlRates rates[];
  ArraySetAsSeries(rates, true);
  int copied = CopyRates(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1, 11, rates);
  if(copied > 0)
  {
    snapshot.previous_candle_profile_valid =
      DeterministicSignalStatsPreviousCandleProfile(rates[0],
                                                    snapshot.previous_candle_profile);
  }
  if(!snapshot.previous_candle_profile_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "previous_candle_profile");

  snapshot.high_chain_profile_valid =
    DeterministicSignalStatsChainProfile(rates, copied, true, snapshot.high_chain_profile);
  snapshot.low_chain_profile_valid =
    DeterministicSignalStatsChainProfile(rates, copied, false, snapshot.low_chain_profile);
  if(!snapshot.high_chain_profile_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "high_chain_profile");
  if(!snapshot.low_chain_profile_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "low_chain_profile");

  snapshot.entry_session_bucket = DeterministicSignalStatsSessionBucket(snapshot.entry_time);
  snapshot.entry_session_bucket_valid = (snapshot.entry_session_bucket != "");
  if(!snapshot.entry_session_bucket_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_session_bucket");

  snapshot.entry_weekday = DeterministicSignalStatsWeekdayToken(snapshot.entry_time);
  snapshot.entry_weekday_valid = (snapshot.entry_weekday != "");
  if(!snapshot.entry_weekday_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_weekday");

  return true;
}

bool DeterministicSignalStatsBuildFeatureRow(SignalParams &signal_params,
                                             const ExecutionLegState &leg_state,
                                             string &row_out,
                                             bool &valid_out)
{
  row_out = "";
  valid_out = true;

  if(!DeterministicSignalStatsReady() ||
     !signal_params.deterministic_strategy)
    return false;

  string signal_id = DeterministicSignalStatsEnsureSignalId(signal_params);
  if(signal_id == "")
    return false;

  DeterministicSignalFeatureSnapshot snapshot;
  if(!DeterministicSignalBuildFeatureSnapshot(signal_params,
                                              leg_state,
                                              snapshot))
    return false;
  valid_out = snapshot.valid;

  row_out = IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
            DeterministicSignalStatsCell(signal_id) + "\t" +
            DeterministicSignalStatsCell(snapshot.source_key) + "\t" +
            IntegerToString(snapshot.source_attempt_index) + "\t" +
            DeterministicSignalStatsCell(snapshot.symbol) + "\t" +
            DeterministicSignalStatsCell(snapshot.strategy_label) + "\t" +
            DeterministicSignalStatsCell(snapshot.direction) + "\t" +
            DeterministicSignalStatsTimeToken(snapshot.entry_time) + "\t" +
            DeterministicSignalStatsTimeToken(snapshot.source_time) + "\t" +
            DeterministicSignalStatsCell(snapshot.structure_0_valid ? snapshot.structure_0 : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.structure_1_valid ? snapshot.structure_1 : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.structure_2_valid ? snapshot.structure_2 : "") + "\t" +
            IntegerToString(snapshot.macro_h1_slope) + "\t" +
            IntegerToString(snapshot.macro_h4_slope) + "\t" +
            IntegerToString(snapshot.macro_d1_slope) + "\t" +
            DeterministicSignalStatsCell(snapshot.fib_sl_band_valid ? snapshot.fib_sl_band : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.fib_entry_band_valid ? snapshot.fib_entry_band : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.high_chain_profile_valid ? snapshot.high_chain_profile : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.low_chain_profile_valid ? snapshot.low_chain_profile : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.previous_candle_profile_valid ? snapshot.previous_candle_profile : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.entry_session_bucket_valid ? snapshot.entry_session_bucket : "") + "\t" +
            DeterministicSignalStatsCell(snapshot.entry_weekday_valid ? snapshot.entry_weekday : "");

  return true;
}

bool DeterministicSignalStatsRecordFeature(SignalParams &signal_params,
                                           const ExecutionLegState &leg_state)
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(!signal_params.deterministic_strategy)
    return false;
  if(signal_params.deterministic_stats_feature_exported)
    return false;

  string row = "";
  bool valid = false;
  if(!DeterministicSignalStatsBuildFeatureRow(signal_params,
                                              leg_state,
                                              row,
                                              valid))
    return false;

  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE);
  if(!DeterministicSignalStatsQueueRow(filename,
                                       DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER,
                                       row,
                                       g_deterministic_signal_stats_feature_buffer))
    return false;

  signal_params.deterministic_stats_feature_exported = true;
  g_deterministic_signal_stats_feature_rows++;
  if(!valid)
    g_deterministic_signal_stats_feature_invalid_rows++;
  return true;
}

bool DeterministicSignalStatsOutcomeEntryPrice(const SignalParams &signal_params,
                                               double &entry_price_out)
{
  entry_price_out = 0.0;

  int total = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total; i++)
  {
    if(signal_params.execution_legs[i].entry_price > 0.0)
    {
      entry_price_out = signal_params.execution_legs[i].entry_price;
      return true;
    }
  }

  if(signal_params.entry_price > 0.0)
    entry_price_out = signal_params.entry_price;
  else if(signal_params.execution_entry_reference_price > 0.0)
    entry_price_out = signal_params.execution_entry_reference_price;
  else if(signal_params.raw_entry_trigger_price > 0.0)
    entry_price_out = signal_params.raw_entry_trigger_price;

  return (entry_price_out > 0.0 && MathIsValidNumber(entry_price_out));
}

datetime DeterministicSignalStatsOutcomeEntryTime(const SignalParams &signal_params)
{
  datetime entry_time = 0;
  int total = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total; i++)
  {
    if(signal_params.execution_legs[i].entry_price > 0.0 &&
       signal_params.execution_legs[i].last_action_time > 0)
    {
      if(entry_time <= 0 || signal_params.execution_legs[i].last_action_time < entry_time)
        entry_time = signal_params.execution_legs[i].last_action_time;
    }
  }

  if(entry_time <= 0)
    entry_time = signal_params.entry_time;
  return entry_time;
}

bool DeterministicSignalStatsProfitR(const SignalParams &signal_params,
                                     const double entry_price,
                                     const double close_price,
                                     double &profit_r_out)
{
  profit_r_out = 0.0;
  if(entry_price <= 0.0 || close_price <= 0.0)
    return false;

  double risk_distance = MathAbs(entry_price - signal_params.raw_stop_anchor_price);
  if(risk_distance <= 0.0)
    risk_distance = MathAbs(signal_params.raw_risk_distance);
  if(risk_distance <= 0.0 || !MathIsValidNumber(risk_distance))
    return false;

  if(signal_params.signal_type == BULLISH)
    profit_r_out = (close_price - entry_price) / risk_distance;
  else if(signal_params.signal_type == BEARISH)
    profit_r_out = (entry_price - close_price) / risk_distance;
  else
    return false;

  return MathIsValidNumber(profit_r_out);
}

string DeterministicSignalStatsTerminalReason(const SignalParams &signal_params)
{
  if(signal_params.deterministic_stats_terminal_reason != "")
    return signal_params.deterministic_stats_terminal_reason;

  if(signal_params.raw_profit > 0.0)
    return "BROKER_PROFIT";
  if(signal_params.raw_profit < 0.0)
    return "BROKER_LOSS";
  return "CLOSED";
}

bool DeterministicSignalStatsBuildOutcomeRow(SignalParams &signal_params,
                                             string &row_out,
                                             bool &valid_out)
{
  row_out = "";
  valid_out = true;

  if(!DeterministicSignalStatsReady() ||
     !signal_params.deterministic_strategy)
    return false;

  string signal_id = DeterministicSignalStatsEnsureSignalId(signal_params);
  if(signal_id == "")
    return false;

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildDeterministicSignalSourceKey(signal_params);

  double entry_price = 0.0;
  bool entry_price_valid = DeterministicSignalStatsOutcomeEntryPrice(signal_params,
                                                                     entry_price);
  bool close_price_valid = (signal_params.close_price > 0.0 &&
                            MathIsValidNumber(signal_params.close_price));

  double profit_r = 0.0;
  bool profit_r_valid = entry_price_valid && close_price_valid &&
                        DeterministicSignalStatsProfitR(signal_params,
                                                        entry_price,
                                                        signal_params.close_price,
                                                        profit_r);

  datetime entry_time = DeterministicSignalStatsOutcomeEntryTime(signal_params);
  bool duration_valid = (entry_time > 0 &&
                         signal_params.close_time > 0 &&
                         signal_params.close_time >= entry_time);
  int duration_seconds = 0;
  int duration_m1_bars = 0;
  if(duration_valid)
  {
    duration_seconds = (int)(signal_params.close_time - entry_time);
    int m1_seconds = PeriodSeconds(PERIOD_M1);
    if(m1_seconds > 0)
      duration_m1_bars = (int)MathFloor((double)duration_seconds / (double)m1_seconds);
    else
      duration_valid = false;
  }

  bool net_profit_valid = MathIsValidNumber(signal_params.raw_profit);
  valid_out = entry_price_valid && close_price_valid && profit_r_valid &&
              duration_valid && net_profit_valid;

  row_out = IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
            DeterministicSignalStatsCell(signal_id) + "\t" +
            DeterministicSignalStatsCell(source_key) + "\t" +
            IntegerToString(signal_params.deterministic_source_attempt_index) + "\t" +
            DeterministicSignalStatsTimeToken(signal_params.close_time) + "\t" +
            DeterministicSignalStatsCell(DeterministicSignalStatsTerminalReason(signal_params)) + "\t" +
            DeterministicSignalStatsDoubleToken(profit_r_valid, profit_r, 4) + "\t" +
            DeterministicSignalStatsIntToken(duration_valid, duration_seconds) + "\t" +
            DeterministicSignalStatsIntToken(duration_valid, duration_m1_bars) + "\t" +
            DeterministicSignalStatsDoubleToken(entry_price_valid, entry_price, Digits()) + "\t" +
            DeterministicSignalStatsDoubleToken(close_price_valid, signal_params.close_price, Digits()) + "\t" +
            DeterministicSignalStatsDoubleToken(net_profit_valid, signal_params.raw_profit, 2);

  return true;
}

bool DeterministicSignalStatsRecordOutcome(SignalParams &signal_params)
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(!signal_params.deterministic_strategy)
    return false;
  if(!signal_params.deterministic_stats_feature_exported)
    return false;
  if(signal_params.deterministic_stats_outcome_exported)
    return false;
  if(!SignalHasBrokerConfirmedOutcome(signal_params))
    return false;

  string row = "";
  bool valid = false;
  if(!DeterministicSignalStatsBuildOutcomeRow(signal_params,
                                              row,
                                              valid))
    return false;

  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE);
  if(!DeterministicSignalStatsQueueRow(filename,
                                       DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER,
                                       row,
                                       g_deterministic_signal_stats_outcome_buffer))
    return false;

  signal_params.deterministic_stats_outcome_exported = true;
  g_deterministic_signal_stats_outcome_rows++;
  if(!valid)
    g_deterministic_signal_stats_outcome_invalid_rows++;
  return true;
}

#endif // _TS_DETERMINISTIC_STATS_EXPORT_MQH_
