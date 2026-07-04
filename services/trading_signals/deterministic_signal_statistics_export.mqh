//+------------------------------------------------------------------+
//|       trading_signals/deterministic_signal_statistics_export.mqh |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_STATS_EXPORT_MQH_
#define _TS_DETERMINISTIC_STATS_EXPORT_MQH_

const int    DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 1;
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
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_id\tstrategy_label\tdirection\tentry_time\tsource_time\tsource_type\tmacro_h1_live_dir\tmacro_h4_live_dir\tmacro_d1_live_dir\tsl_fib_raw\tsl_fib_band\tentry_fib_raw\tentry_fib_band\tlow_chain_score_3\tlow_chain_score_5\tlow_chain_score_10\thigh_chain_score_3\thigh_chain_score_5\thigh_chain_score_10";
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

bool DeterministicSignalStatsChainScore(const MqlRates &rates[],
                                        const int copied,
                                        const int window,
                                        const bool use_high,
                                        int &score_out)
{
  score_out = 0;
  if(window <= 0 || copied < window + 1)
    return false;

  for(int i = 0; i < window; i++)
  {
    double current_value = use_high ? rates[i].high : rates[i].low;
    double previous_value = use_high ? rates[i + 1].high : rates[i + 1].low;
    if(current_value <= 0.0 || previous_value <= 0.0)
      continue;
    if(current_value > previous_value)
      score_out++;
    else if(current_value < previous_value)
      score_out--;
  }

  return true;
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
  int      macro_h1_live_dir;
  int      macro_h4_live_dir;
  int      macro_d1_live_dir;
  double   sl_fib_raw;
  bool     sl_fib_valid;
  string   sl_fib_band;
  bool     sl_fib_band_valid;
  double   entry_fib_raw;
  bool     entry_fib_valid;
  string   entry_fib_band;
  bool     entry_fib_band_valid;
  int      low_chain_score_3;
  bool     low_chain_score_3_valid;
  int      low_chain_score_5;
  bool     low_chain_score_5_valid;
  int      low_chain_score_10;
  bool     low_chain_score_10_valid;
  int      high_chain_score_3;
  bool     high_chain_score_3_valid;
  int      high_chain_score_5;
  bool     high_chain_score_5_valid;
  int      high_chain_score_10;
  bool     high_chain_score_10_valid;

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
    macro_h1_live_dir = 0;
    macro_h4_live_dir = 0;
    macro_d1_live_dir = 0;
    sl_fib_raw = 0.0;
    sl_fib_valid = false;
    sl_fib_band = DETERMINISTIC_SIGNAL_STATS_NULL;
    sl_fib_band_valid = false;
    entry_fib_raw = 0.0;
    entry_fib_valid = false;
    entry_fib_band = DETERMINISTIC_SIGNAL_STATS_NULL;
    entry_fib_band_valid = false;
    low_chain_score_3 = 0;
    low_chain_score_3_valid = false;
    low_chain_score_5 = 0;
    low_chain_score_5_valid = false;
    low_chain_score_10 = 0;
    low_chain_score_10_valid = false;
    high_chain_score_3 = 0;
    high_chain_score_3_valid = false;
    high_chain_score_5 = 0;
    high_chain_score_5_valid = false;
    high_chain_score_10 = 0;
    high_chain_score_10_valid = false;
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
  snapshot.source_time = signal_params.source_extremum_time;
  snapshot.source_type = DeterministicSignalStatsSourceTypeToken(signal_params);

  snapshot.macro_h1_live_dir = DeterministicSignalStatsMacroDir(PERIOD_H1);
  snapshot.macro_h4_live_dir = DeterministicSignalStatsMacroDir(PERIOD_H4);
  snapshot.macro_d1_live_dir = DeterministicSignalStatsMacroDir(PERIOD_D1);

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool source_is_peak = false;
  bool fib_range_valid = DeterministicSignalStatsResolveFibonacciRange(signal_params,
                                                                       peak_price,
                                                                       bottom_price,
                                                                       source_is_peak);

  snapshot.sl_fib_valid = fib_range_valid &&
                          DeterministicSignalStatsFibonacciPercent(peak_price,
                                                                   bottom_price,
                                                                   source_is_peak,
                                                                   signal_params.raw_stop_anchor_price,
                                                                   snapshot.sl_fib_raw);

  double entry_reference = signal_params.raw_entry_trigger_price;
  if(entry_reference <= 0.0)
    entry_reference = leg_state.entry_reference_price;
  snapshot.entry_fib_valid = fib_range_valid &&
                             DeterministicSignalStatsFibonacciPercent(peak_price,
                                                                      bottom_price,
                                                                      source_is_peak,
                                                                      entry_reference,
                                                                      snapshot.entry_fib_raw);

  snapshot.sl_fib_band_valid = snapshot.sl_fib_valid &&
                               DeterministicSignalStatsFibonacciBand(snapshot.sl_fib_raw,
                                                                     snapshot.sl_fib_band);
  snapshot.entry_fib_band_valid = snapshot.entry_fib_valid &&
                                  DeterministicSignalStatsFibonacciBand(snapshot.entry_fib_raw,
                                                                        snapshot.entry_fib_band);
  if(!snapshot.sl_fib_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "sl_fib_raw");
  if(!snapshot.entry_fib_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_fib_raw");
  if(!snapshot.sl_fib_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "sl_fib_band");
  if(!snapshot.entry_fib_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_fib_band");

  MqlRates rates[];
  ArraySetAsSeries(rates, true);
  int copied = CopyRates(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1, 11, rates);
  snapshot.low_chain_score_3_valid = DeterministicSignalStatsChainScore(rates, copied, 3, false, snapshot.low_chain_score_3);
  snapshot.low_chain_score_5_valid = DeterministicSignalStatsChainScore(rates, copied, 5, false, snapshot.low_chain_score_5);
  snapshot.low_chain_score_10_valid = DeterministicSignalStatsChainScore(rates, copied, 10, false, snapshot.low_chain_score_10);
  snapshot.high_chain_score_3_valid = DeterministicSignalStatsChainScore(rates, copied, 3, true, snapshot.high_chain_score_3);
  snapshot.high_chain_score_5_valid = DeterministicSignalStatsChainScore(rates, copied, 5, true, snapshot.high_chain_score_5);
  snapshot.high_chain_score_10_valid = DeterministicSignalStatsChainScore(rates, copied, 10, true, snapshot.high_chain_score_10);
  if(!snapshot.low_chain_score_3_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "low_chain_score_3");
  if(!snapshot.low_chain_score_5_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "low_chain_score_5");
  if(!snapshot.low_chain_score_10_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "low_chain_score_10");
  if(!snapshot.high_chain_score_3_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "high_chain_score_3");
  if(!snapshot.high_chain_score_5_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "high_chain_score_5");
  if(!snapshot.high_chain_score_10_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "high_chain_score_10");

  snapshot.entry_time = leg_state.last_action_time;
  if(snapshot.entry_time <= 0)
    snapshot.entry_time = TimeCurrent();

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
            IntegerToString(snapshot.strategy_id) + "\t" +
            DeterministicSignalStatsCell(snapshot.strategy_label) + "\t" +
            DeterministicSignalStatsCell(snapshot.direction) + "\t" +
            DeterministicSignalStatsTimeToken(snapshot.entry_time) + "\t" +
            DeterministicSignalStatsTimeToken(snapshot.source_time) + "\t" +
            DeterministicSignalStatsCell(snapshot.source_type) + "\t" +
            IntegerToString(snapshot.macro_h1_live_dir) + "\t" +
            IntegerToString(snapshot.macro_h4_live_dir) + "\t" +
            IntegerToString(snapshot.macro_d1_live_dir) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.sl_fib_valid, snapshot.sl_fib_raw, 1) + "\t" +
            DeterministicSignalStatsCell(snapshot.sl_fib_band) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.entry_fib_valid, snapshot.entry_fib_raw, 1) + "\t" +
            DeterministicSignalStatsCell(snapshot.entry_fib_band) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.low_chain_score_3_valid, snapshot.low_chain_score_3) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.low_chain_score_5_valid, snapshot.low_chain_score_5) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.low_chain_score_10_valid, snapshot.low_chain_score_10) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.high_chain_score_3_valid, snapshot.high_chain_score_3) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.high_chain_score_5_valid, snapshot.high_chain_score_5) + "\t" +
            DeterministicSignalStatsIntToken(snapshot.high_chain_score_10_valid, snapshot.high_chain_score_10);

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
