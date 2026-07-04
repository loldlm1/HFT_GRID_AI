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
  return g_deterministic_signal_stats_initialized;
}

bool DeterministicSignalStatsReady()
{
  return DeterministicSignalStatsEnabled() &&
         g_deterministic_signal_stats_initialized &&
         !g_deterministic_signal_stats_failed;
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

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildDeterministicSignalSourceKey(signal_params);

  int macro_h1 = DeterministicSignalStatsMacroDir(PERIOD_H1);
  int macro_h4 = DeterministicSignalStatsMacroDir(PERIOD_H4);
  int macro_d1 = DeterministicSignalStatsMacroDir(PERIOD_D1);

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool source_is_peak = false;
  bool fib_range_valid = DeterministicSignalStatsResolveFibonacciRange(signal_params,
                                                                       peak_price,
                                                                       bottom_price,
                                                                       source_is_peak);

  double sl_fib_raw = 0.0;
  double entry_fib_raw = 0.0;
  bool sl_fib_valid = fib_range_valid &&
                      DeterministicSignalStatsFibonacciPercent(peak_price,
                                                               bottom_price,
                                                               source_is_peak,
                                                               signal_params.raw_stop_anchor_price,
                                                               sl_fib_raw);

  double entry_reference = signal_params.raw_entry_trigger_price;
  if(entry_reference <= 0.0)
    entry_reference = leg_state.entry_reference_price;
  bool entry_fib_valid = fib_range_valid &&
                         DeterministicSignalStatsFibonacciPercent(peak_price,
                                                                  bottom_price,
                                                                  source_is_peak,
                                                                  entry_reference,
                                                                  entry_fib_raw);

  string sl_fib_band = DETERMINISTIC_SIGNAL_STATS_NULL;
  string entry_fib_band = DETERMINISTIC_SIGNAL_STATS_NULL;
  bool sl_band_valid = sl_fib_valid &&
                       DeterministicSignalStatsFibonacciBand(sl_fib_raw, sl_fib_band);
  bool entry_band_valid = entry_fib_valid &&
                          DeterministicSignalStatsFibonacciBand(entry_fib_raw, entry_fib_band);
  valid_out = valid_out && sl_fib_valid && entry_fib_valid && sl_band_valid && entry_band_valid;

  MqlRates rates[];
  ArraySetAsSeries(rates, true);
  int copied = CopyRates(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1, 11, rates);
  int low_score_3 = 0;
  int low_score_5 = 0;
  int low_score_10 = 0;
  int high_score_3 = 0;
  int high_score_5 = 0;
  int high_score_10 = 0;
  bool low_3_valid = DeterministicSignalStatsChainScore(rates, copied, 3, false, low_score_3);
  bool low_5_valid = DeterministicSignalStatsChainScore(rates, copied, 5, false, low_score_5);
  bool low_10_valid = DeterministicSignalStatsChainScore(rates, copied, 10, false, low_score_10);
  bool high_3_valid = DeterministicSignalStatsChainScore(rates, copied, 3, true, high_score_3);
  bool high_5_valid = DeterministicSignalStatsChainScore(rates, copied, 5, true, high_score_5);
  bool high_10_valid = DeterministicSignalStatsChainScore(rates, copied, 10, true, high_score_10);
  valid_out = valid_out && low_3_valid && low_5_valid && low_10_valid &&
              high_3_valid && high_5_valid && high_10_valid;

  datetime entry_time = leg_state.last_action_time;
  if(entry_time <= 0)
    entry_time = TimeCurrent();

  row_out = IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
            DeterministicSignalStatsCell(signal_id) + "\t" +
            DeterministicSignalStatsCell(source_key) + "\t" +
            IntegerToString(signal_params.deterministic_source_attempt_index) + "\t" +
            DeterministicSignalStatsCell(_Symbol) + "\t" +
            IntegerToString(signal_params.strategy_id) + "\t" +
            DeterministicSignalStatsCell(signal_params.strategy_label) + "\t" +
            DeterministicSignalStatsDirectionToken(signal_params.signal_type) + "\t" +
            DeterministicSignalStatsTimeToken(entry_time) + "\t" +
            DeterministicSignalStatsTimeToken(signal_params.source_extremum_time) + "\t" +
            DeterministicSignalStatsSourceTypeToken(signal_params) + "\t" +
            IntegerToString(macro_h1) + "\t" +
            IntegerToString(macro_h4) + "\t" +
            IntegerToString(macro_d1) + "\t" +
            DeterministicSignalStatsDoubleToken(sl_fib_valid, sl_fib_raw, 1) + "\t" +
            DeterministicSignalStatsCell(sl_fib_band) + "\t" +
            DeterministicSignalStatsDoubleToken(entry_fib_valid, entry_fib_raw, 1) + "\t" +
            DeterministicSignalStatsCell(entry_fib_band) + "\t" +
            DeterministicSignalStatsIntToken(low_3_valid, low_score_3) + "\t" +
            DeterministicSignalStatsIntToken(low_5_valid, low_score_5) + "\t" +
            DeterministicSignalStatsIntToken(low_10_valid, low_score_10) + "\t" +
            DeterministicSignalStatsIntToken(high_3_valid, high_score_3) + "\t" +
            DeterministicSignalStatsIntToken(high_5_valid, high_score_5) + "\t" +
            DeterministicSignalStatsIntToken(high_10_valid, high_score_10);

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
  if(!DeterministicSignalStatsAppendRow(filename,
                                        DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER,
                                        row))
    return false;

  signal_params.deterministic_stats_feature_exported = true;
  g_deterministic_signal_stats_feature_rows++;
  if(!valid)
    g_deterministic_signal_stats_feature_invalid_rows++;
  return true;
}

#endif // _TS_DETERMINISTIC_STATS_EXPORT_MQH_
