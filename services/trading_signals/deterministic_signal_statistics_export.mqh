//+------------------------------------------------------------------+
//|       trading_signals/deterministic_signal_statistics_export.mqh |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_STATS_EXPORT_MQH_
#define _TS_DETERMINISTIC_STATS_EXPORT_MQH_

const int    DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 6;
const string DETERMINISTIC_SIGNAL_STATS_STORAGE_ROOT   = "DeterministicSignalML";
const string DETERMINISTIC_SIGNAL_STATS_RUNS_FOLDER    = "runs";
const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_FILE  = "run_manifest.tsv";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE  = "signal_features.tsv";
const string DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_FILE = "signal_admissions.tsv";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE  = "signal_outcomes.tsv";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_FILE   = "run_summary.tsv";
const string DETERMINISTIC_SIGNAL_STATS_NULL           = "\\N";
const ushort DETERMINISTIC_SIGNAL_STATS_DELIMITER      = '\t';
const int    DETERMINISTIC_SIGNAL_STATS_FLUSH_ROWS     = 32;
const int    DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS = 2880;
const int    DETERMINISTIC_SIGNAL_STATS_PATH_RESERVE = 128;

const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_label\tdirection\tentry_time\tsource_time\tstructure_0\tstructure_1\tstructure_2\tmacro_h1_slope\tmacro_h4_slope\tmacro_d1_slope\tfib_sl_band\tfib_entry_band\thigh_chain_profile\tlow_chain_profile\tprevious_candle_profile\tentry_session_bucket\tentry_weekday\tstoch_structure_raw_percent\tb_percent_main_base\tb_percent_main_base_slope\tb_percent_main_macro\tb_percent_main_macro_slope\tsession_id\ttime_sin\ttime_cos";
const string DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tevent_time\tevent_type\tadmission_status\tadmission_source\tadmission_reason\tspread_points\tmax_spread\tmarket_status\tbroker_entry_confirmed\tbroker_close_confirmed\trisk_plan_status\trisk_target_amount\texpected_sl_loss\texpected_tp_profit\traw_lot\tnormalized_lot";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tterminal_time\tterminal_reason\tprofit_r\tduration_seconds\tduration_m1_bars\tentry_price\tclose_price\tnet_profit\tbroker_entry_confirmed\tbroker_close_confirmed\tbroker_close_source\tpartial_tp_mode\tpartial_tp1_confirmed\tpartial_tp2_confirmed\tpartial_tp3_confirmed\tpartial_tp1_closed_volume\tpartial_tp2_closed_volume\tpartial_tp3_closed_volume\thit_1r_before_sl\thit_1_5r_before_sl\thit_2r_before_sl\thit_3r_before_sl\tmax_favorable_r\tmax_adverse_r\tbars_to_1r\tbars_to_1_5r\tbars_to_2r\tbars_to_3r\tbars_to_sl\tpath_horizon_bars\tpath_status\tpath_label_source";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_at\tfinished_at\tfeature_rows\tadmission_rows\toutcome_rows\tfeature_invalid_rows\toutcome_invalid_rows\texport_status";

struct DeterministicSignalStatsOutcomePayload
{
  bool     valid;
  datetime terminal_time;
  string   terminal_reason;
  double   profit_r;
  bool     profit_r_valid;
  int      duration_seconds;
  int      duration_m1_bars;
  bool     duration_valid;
  double   entry_price;
  bool     entry_price_valid;
  double   close_price;
  bool     close_price_valid;
  double   net_profit;
  bool     net_profit_valid;

  DeterministicSignalStatsOutcomePayload()
  {
    valid = false;
    terminal_time = 0;
    terminal_reason = "";
    profit_r = 0.0;
    profit_r_valid = false;
    duration_seconds = 0;
    duration_m1_bars = 0;
    duration_valid = false;
    entry_price = 0.0;
    entry_price_valid = false;
    close_price = 0.0;
    close_price_valid = false;
    net_profit = 0.0;
    net_profit_valid = false;
  }

  DeterministicSignalStatsOutcomePayload(const DeterministicSignalStatsOutcomePayload &other)
  {
    valid = other.valid;
    terminal_time = other.terminal_time;
    terminal_reason = other.terminal_reason;
    profit_r = other.profit_r;
    profit_r_valid = other.profit_r_valid;
    duration_seconds = other.duration_seconds;
    duration_m1_bars = other.duration_m1_bars;
    duration_valid = other.duration_valid;
    entry_price = other.entry_price;
    entry_price_valid = other.entry_price_valid;
    close_price = other.close_price;
    close_price_valid = other.close_price_valid;
    net_profit = other.net_profit;
    net_profit_valid = other.net_profit_valid;
  }
};

struct DeterministicSignalStatsPathState
{
  bool     active;
  bool     finalized;
  bool     broker_outcome_ready;
  bool     outcome_written;
  string   signal_id;
  string   source_key;
  int      source_attempt_index;
  SignalTypes direction;
  datetime entry_time;
  double   entry_price;
  double   stop_price;
  double   risk_distance;
  double   max_favorable_r;
  double   max_adverse_r;
  bool     hit_1r;
  bool     hit_1_5r;
  bool     hit_2r;
  bool     hit_3r;
  bool     hit_sl;
  int      bars_to_1r;
  int      bars_to_1_5r;
  int      bars_to_2r;
  int      bars_to_3r;
  int      bars_to_sl;
  int      path_horizon_bars;
  string   path_status;
  string   broker_columns;
  DeterministicSignalStatsOutcomePayload outcome;

  DeterministicSignalStatsPathState()
  {
    active = false;
    finalized = false;
    broker_outcome_ready = false;
    outcome_written = false;
    signal_id = "";
    source_key = "";
    source_attempt_index = 0;
    direction = NO_SIGNAL;
    entry_time = 0;
    entry_price = 0.0;
    stop_price = 0.0;
    risk_distance = 0.0;
    max_favorable_r = 0.0;
    max_adverse_r = 0.0;
    hit_1r = false;
    hit_1_5r = false;
    hit_2r = false;
    hit_3r = false;
    hit_sl = false;
    bars_to_1r = -1;
    bars_to_1_5r = -1;
    bars_to_2r = -1;
    bars_to_3r = -1;
    bars_to_sl = -1;
    path_horizon_bars = DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS;
    path_status = "";
    broker_columns = "";
    outcome = DeterministicSignalStatsOutcomePayload();
  }

  DeterministicSignalStatsPathState(const DeterministicSignalStatsPathState &other)
  {
    active = other.active;
    finalized = other.finalized;
    broker_outcome_ready = other.broker_outcome_ready;
    outcome_written = other.outcome_written;
    signal_id = other.signal_id;
    source_key = other.source_key;
    source_attempt_index = other.source_attempt_index;
    direction = other.direction;
    entry_time = other.entry_time;
    entry_price = other.entry_price;
    stop_price = other.stop_price;
    risk_distance = other.risk_distance;
    max_favorable_r = other.max_favorable_r;
    max_adverse_r = other.max_adverse_r;
    hit_1r = other.hit_1r;
    hit_1_5r = other.hit_1_5r;
    hit_2r = other.hit_2r;
    hit_3r = other.hit_3r;
    hit_sl = other.hit_sl;
    bars_to_1r = other.bars_to_1r;
    bars_to_1_5r = other.bars_to_1_5r;
    bars_to_2r = other.bars_to_2r;
    bars_to_3r = other.bars_to_3r;
    bars_to_sl = other.bars_to_sl;
    path_horizon_bars = other.path_horizon_bars;
    path_status = other.path_status;
    broker_columns = other.broker_columns;
    outcome = other.outcome;
  }
};

string   g_deterministic_signal_stats_run_id = "";
string   g_deterministic_signal_stats_config_id = "";
string   g_deterministic_signal_stats_folder = "";
datetime g_deterministic_signal_stats_started_at = 0;
bool     g_deterministic_signal_stats_initialized = false;
bool     g_deterministic_signal_stats_failed = false;
int      g_deterministic_signal_stats_feature_rows = 0;
int      g_deterministic_signal_stats_admission_rows = 0;
int      g_deterministic_signal_stats_outcome_rows = 0;
int      g_deterministic_signal_stats_feature_invalid_rows = 0;
int      g_deterministic_signal_stats_outcome_invalid_rows = 0;
string   g_deterministic_signal_stats_feature_buffer[];
string   g_deterministic_signal_stats_admission_buffer[];
string   g_deterministic_signal_stats_outcome_buffer[];
DeterministicSignalStatsPathState g_deterministic_signal_stats_path_states[];

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

bool DeterministicSignalStatsAppendRows(const string filename,
                                        const string header,
                                        string &buffer[])
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(filename == "" || header == "")
    return false;

  int total = ArraySize(buffer);
  if(total <= 0)
    return true;

  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
  if(!needs_header)
    flags |= FILE_READ;

  ResetLastError();
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    g_deterministic_signal_stats_failed = true;
    if(Enable_Logs || Enable_File_Logs)
    {
      PrintFormat("DETERMINISTIC_STATS_BATCH_WRITE_FAIL | file=%s | err=%d",
                  filename,
                  open_error);
    }
    return false;
  }

  if(needs_header)
    FileWrite(handle, header);
  else
    FileSeek(handle, 0, SEEK_END);

  for(int i = 0; i < total; i++)
  {
    if(buffer[i] == "")
    {
      FileClose(handle);
      g_deterministic_signal_stats_failed = true;
      return false;
    }
    FileWrite(handle, buffer[i]);
  }

  FileClose(handle);
  return true;
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

  if(!DeterministicSignalStatsAppendRows(filename, header, buffer))
    return false;

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

bool DeterministicSignalStatsFlushAdmissions()
{
  return DeterministicSignalStatsFlushBuffer(DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_FILE),
                                            DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_HEADER,
                                            g_deterministic_signal_stats_admission_buffer);
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
  bool admissions_ok = DeterministicSignalStatsFlushAdmissions();
  bool outcomes_ok = DeterministicSignalStatsFlushOutcomes();
  return features_ok && admissions_ok && outcomes_ok;
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
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("admission_policy", "candidate_and_broker_admission_events"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("outcome_policy", "broker_confirmed_only"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("numeric_feature_set", "schema_v6_numeric_xgb"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("b_percent_indicator", "iBands:upper_lower_close:period_21:deviation_2.0:bands_shift_0:PRICE_CLOSE"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("path_ratio_policy", "bounded_tick_path_outcome_only"), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("path_horizon_m1_bars", IntegerToString(DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS)), true);
  DeterministicSignalStatsWriteLine(filename, DeterministicSignalStatsManifestRow("invalid_numeric_token", DETERMINISTIC_SIGNAL_STATS_NULL), true);
  return true;
}

bool DeterministicSignalStatsPrepareRowFiles()
{
  string features_filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE);
  string admissions_filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_FILE);
  string outcomes_filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE);

  if(!DeterministicSignalStatsWriteLine(features_filename,
                                        DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER,
                                        false))
      return false;

  if(!DeterministicSignalStatsWriteLine(admissions_filename,
                                        DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_HEADER,
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
         IntegerToString(g_deterministic_signal_stats_admission_rows) + "\t" +
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
  g_deterministic_signal_stats_admission_rows = 0;
  g_deterministic_signal_stats_outcome_rows = 0;
  g_deterministic_signal_stats_feature_invalid_rows = 0;
  g_deterministic_signal_stats_outcome_invalid_rows = 0;
  ArrayResize(g_deterministic_signal_stats_feature_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_admission_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_outcome_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_path_states, 0);
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

  DeterministicSignalStatsFinalizePendingPaths("RUN_ENDED");
  if(!DeterministicSignalStatsFlushAll())
    g_deterministic_signal_stats_failed = true;

  DeterministicSignalStatsWriteSummary();
  ArrayResize(g_deterministic_signal_stats_feature_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_admission_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_outcome_buffer, 0);
  ArrayResize(g_deterministic_signal_stats_path_states, 0);
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

bool DeterministicSignalStatsRecordAdmissionEvent(SignalParams &signal_params,
                                                  const string event_type)
{
  if(!DeterministicSignalStatsReady())
    return false;
  if(!signal_params.deterministic_strategy)
    return false;

  string signal_id = DeterministicSignalStatsEnsureSignalId(signal_params);
  if(signal_id == "")
    return false;

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildDeterministicSignalSourceKey(signal_params);

  string event_key = event_type + "|" +
                     EnumToString(signal_params.admission_status) + "|" +
                     signal_params.admission_block_source + "|" +
                     signal_params.admission_block_reason;
  if(signal_params.deterministic_stats_last_admission_key == event_key)
    return true;

  string row = IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
               DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
               DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
               DeterministicSignalStatsCell(signal_id) + "\t" +
               DeterministicSignalStatsCell(source_key) + "\t" +
               IntegerToString(signal_params.deterministic_source_attempt_index) + "\t" +
               DeterministicSignalStatsTimeToken(TimeCurrent()) + "\t" +
               DeterministicSignalStatsCell(event_type) + "\t" +
               DeterministicSignalStatsCell(EnumToString(signal_params.admission_status)) + "\t" +
               DeterministicSignalStatsCell(signal_params.admission_block_source) + "\t" +
               DeterministicSignalStatsCell(signal_params.admission_block_reason) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.admission_spread_points > 0.0,
                                                   signal_params.admission_spread_points,
                                                   1) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.admission_max_spread > 0.0,
                                                   signal_params.admission_max_spread,
                                                   1) + "\t" +
               DeterministicSignalStatsCell(MarketStatusToString(signal_params.admission_market_status)) + "\t" +
               DeterministicSignalStatsBoolToken(signal_params.broker_entry_confirmed) + "\t" +
               DeterministicSignalStatsBoolToken(signal_params.broker_close_confirmed) + "\t" +
               DeterministicSignalStatsCell(signal_params.execution_risk_plan_reason) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.execution_risk_target_amount > 0.0,
                                                   signal_params.execution_risk_target_amount,
                                                   2) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.execution_expected_sl_loss > 0.0,
                                                   signal_params.execution_expected_sl_loss,
                                                   2) + "\t" +
               DeterministicSignalStatsDoubleToken(MathAbs(signal_params.execution_expected_tp_profit) > 0.0,
                                                   signal_params.execution_expected_tp_profit,
                                                   2) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.execution_raw_lot_size > 0.0,
                                                   signal_params.execution_raw_lot_size,
                                                   4) + "\t" +
               DeterministicSignalStatsDoubleToken(signal_params.execution_normalized_lot_size > 0.0,
                                                   signal_params.execution_normalized_lot_size,
                                                   4);

  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_FILE);
  if(!DeterministicSignalStatsQueueRow(filename,
                                       DETERMINISTIC_SIGNAL_STATS_ADMISSIONS_HEADER,
                                       row,
                                       g_deterministic_signal_stats_admission_buffer))
    return false;

  signal_params.deterministic_stats_last_admission_key = event_key;
  g_deterministic_signal_stats_admission_rows++;
  return true;
}

bool DeterministicSignalStatsPathStatusHasFinalLabels(const string path_status)
{
  return (path_status == "SL_FIRST" ||
          path_status == "TARGET_3R" ||
          path_status == "HORIZON_EXPIRED");
}

int DeterministicSignalStatsFindPathState(const string signal_id)
{
  if(signal_id == "")
    return -1;

  int total = ArraySize(g_deterministic_signal_stats_path_states);
  for(int i = 0; i < total; i++)
  {
    if(g_deterministic_signal_stats_path_states[i].signal_id == signal_id)
      return i;
  }
  return -1;
}

void DeterministicSignalStatsRemovePathState(const int index)
{
  int total = ArraySize(g_deterministic_signal_stats_path_states);
  if(index < 0 || index >= total)
    return;

  for(int i = index; i < total - 1; i++)
    g_deterministic_signal_stats_path_states[i] = g_deterministic_signal_stats_path_states[i + 1];

  ArrayResize(g_deterministic_signal_stats_path_states, total - 1);
}

int DeterministicSignalStatsPathBarsElapsed(const datetime entry_time,
                                            const datetime current_time)
{
  if(entry_time <= 0 || current_time <= entry_time)
    return 0;

  int m1_seconds = PeriodSeconds(PERIOD_M1);
  if(m1_seconds <= 0)
    return 0;

  return (int)MathFloor((double)(current_time - entry_time) / (double)m1_seconds);
}

void DeterministicSignalStatsFinalizePathState(const int index,
                                               const string path_status)
{
  int total = ArraySize(g_deterministic_signal_stats_path_states);
  if(index < 0 || index >= total)
    return;

  g_deterministic_signal_stats_path_states[index].active = false;
  g_deterministic_signal_stats_path_states[index].finalized = true;
  g_deterministic_signal_stats_path_states[index].path_status = path_status;
}

bool DeterministicSignalStatsPathCurrentR(DeterministicSignalStatsPathState &state,
                                          const double price,
                                          double &current_r_out)
{
  current_r_out = 0.0;
  if(price <= 0.0 ||
     state.entry_price <= 0.0 ||
     state.risk_distance <= 0.0 ||
     !MathIsValidNumber(price) ||
     !MathIsValidNumber(state.entry_price) ||
     !MathIsValidNumber(state.risk_distance))
    return false;

  if(state.direction == BULLISH)
    current_r_out = (price - state.entry_price) / state.risk_distance;
  else if(state.direction == BEARISH)
    current_r_out = (state.entry_price - price) / state.risk_distance;
  else
    return false;

  return MathIsValidNumber(current_r_out);
}

void DeterministicSignalStatsRecordPathTargets(DeterministicSignalStatsPathState &state,
                                               const double current_r,
                                               const int bars_elapsed)
{
  if(!state.hit_1r && current_r >= 1.0)
  {
    state.hit_1r = true;
    state.bars_to_1r = bars_elapsed;
  }
  if(!state.hit_1_5r && current_r >= 1.5)
  {
    state.hit_1_5r = true;
    state.bars_to_1_5r = bars_elapsed;
  }
  if(!state.hit_2r && current_r >= 2.0)
  {
    state.hit_2r = true;
    state.bars_to_2r = bars_elapsed;
  }
  if(!state.hit_3r && current_r >= 3.0)
  {
    state.hit_3r = true;
    state.bars_to_3r = bars_elapsed;
  }
}

void DeterministicSignalStatsUpdatePathState(const int index,
                                             const datetime current_time)
{
  int total = ArraySize(g_deterministic_signal_stats_path_states);
  if(index < 0 || index >= total)
    return;

  DeterministicSignalStatsPathState state = g_deterministic_signal_stats_path_states[index];
  if(!state.active || state.finalized)
    return;

  if(state.risk_distance <= 0.0 || state.entry_time <= 0)
  {
    DeterministicSignalStatsFinalizePathState(index, "INVALID");
    return;
  }

  double price = 0.0;
  if(state.direction == BULLISH)
    price = g_bid;
  else if(state.direction == BEARISH)
    price = g_ask;
  else
  {
    DeterministicSignalStatsFinalizePathState(index, "INVALID");
    return;
  }

  double current_r = 0.0;
  if(!DeterministicSignalStatsPathCurrentR(state, price, current_r))
    return;

  int bars_elapsed = DeterministicSignalStatsPathBarsElapsed(state.entry_time,
                                                            current_time);
  if(current_r > state.max_favorable_r)
    state.max_favorable_r = current_r;
  if(current_r < state.max_adverse_r)
    state.max_adverse_r = current_r;

  DeterministicSignalStatsRecordPathTargets(state, current_r, bars_elapsed);

  if(!state.hit_sl && current_r <= -1.0)
  {
    state.hit_sl = true;
    state.bars_to_sl = bars_elapsed;
    g_deterministic_signal_stats_path_states[index] = state;
    DeterministicSignalStatsFinalizePathState(index, "SL_FIRST");
    return;
  }

  if(state.hit_3r)
  {
    g_deterministic_signal_stats_path_states[index] = state;
    DeterministicSignalStatsFinalizePathState(index, "TARGET_3R");
    return;
  }

  if(bars_elapsed >= state.path_horizon_bars)
  {
    g_deterministic_signal_stats_path_states[index] = state;
    DeterministicSignalStatsFinalizePathState(index, "HORIZON_EXPIRED");
    return;
  }

  g_deterministic_signal_stats_path_states[index] = state;
}

string DeterministicSignalStatsPathBoolToken(const bool labels_valid,
                                             const bool value)
{
  if(!labels_valid)
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return value ? "1" : "0";
}

string DeterministicSignalStatsPathBarsToken(const bool labels_valid,
                                             const int bars_value)
{
  if(!labels_valid || bars_value < 0)
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return IntegerToString(bars_value);
}

string DeterministicSignalStatsPathColumns(const DeterministicSignalStatsPathState &state)
{
  bool labels_valid = DeterministicSignalStatsPathStatusHasFinalLabels(state.path_status);
  return DeterministicSignalStatsPathBoolToken(labels_valid, state.hit_1r) + "\t" +
         DeterministicSignalStatsPathBoolToken(labels_valid, state.hit_1_5r) + "\t" +
         DeterministicSignalStatsPathBoolToken(labels_valid, state.hit_2r) + "\t" +
         DeterministicSignalStatsPathBoolToken(labels_valid, state.hit_3r) + "\t" +
         DeterministicSignalStatsDoubleToken(labels_valid, state.max_favorable_r, 4) + "\t" +
         DeterministicSignalStatsDoubleToken(labels_valid, state.max_adverse_r, 4) + "\t" +
         DeterministicSignalStatsPathBarsToken(labels_valid, state.bars_to_1r) + "\t" +
         DeterministicSignalStatsPathBarsToken(labels_valid, state.bars_to_1_5r) + "\t" +
         DeterministicSignalStatsPathBarsToken(labels_valid, state.bars_to_2r) + "\t" +
         DeterministicSignalStatsPathBarsToken(labels_valid, state.bars_to_3r) + "\t" +
         DeterministicSignalStatsPathBarsToken(labels_valid, state.bars_to_sl) + "\t" +
         IntegerToString(state.path_horizon_bars) + "\t" +
         DeterministicSignalStatsCell(state.path_status) + "\t" +
         DeterministicSignalStatsCell(labels_valid ? "path_derived" : "none");
}

string DeterministicSignalStatsInvalidPathColumns()
{
  DeterministicSignalStatsPathState state;
  state.path_status = "INVALID";
  state.path_horizon_bars = DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS;
  return DeterministicSignalStatsPathColumns(state);
}

int DeterministicSignalStatsMacroDir(const ENUM_TIMEFRAMES timeframe)
{
  double ma_now = 0.0;
  double ma_prev = 0.0;
  if(!CopyDeterministicBandsBaseSlopeValues(timeframe, 0, ma_now, ma_prev))
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

bool DeterministicSignalStatsTimeCycle(const datetime entry_time,
                                       double &time_sin_out,
                                       double &time_cos_out)
{
  time_sin_out = 0.0;
  time_cos_out = 0.0;

  if(entry_time <= 0)
    return false;

  MqlDateTime parts;
  TimeToStruct(entry_time, parts);
  int minute_of_day = parts.hour * 60 + parts.min;
  double angle = 2.0 * 3.14159265358979323846 * (double)minute_of_day / 1440.0;
  time_sin_out = MathSin(angle);
  time_cos_out = MathCos(angle);
  return MathIsValidNumber(time_sin_out) && MathIsValidNumber(time_cos_out);
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
  double   stoch_structure_raw_percent;
  bool     stoch_structure_raw_percent_valid;
  string   fib_entry_band;
  bool     fib_entry_band_valid;
  double   b_percent_main_base;
  bool     b_percent_main_base_valid;
  double   b_percent_main_base_slope;
  bool     b_percent_main_base_slope_valid;
  double   b_percent_main_macro;
  bool     b_percent_main_macro_valid;
  double   b_percent_main_macro_slope;
  bool     b_percent_main_macro_slope_valid;
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
  string   session_id;
  bool     session_id_valid;
  double   time_sin;
  bool     time_sin_valid;
  double   time_cos;
  bool     time_cos_valid;

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
    stoch_structure_raw_percent = 0.0;
    stoch_structure_raw_percent_valid = false;
    fib_entry_band = DETERMINISTIC_SIGNAL_STATS_NULL;
    fib_entry_band_valid = false;
    b_percent_main_base = 0.0;
    b_percent_main_base_valid = false;
    b_percent_main_base_slope = 0.0;
    b_percent_main_base_slope_valid = false;
    b_percent_main_macro = 0.0;
    b_percent_main_macro_valid = false;
    b_percent_main_macro_slope = 0.0;
    b_percent_main_macro_slope_valid = false;
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
    session_id = DETERMINISTIC_SIGNAL_STATS_NULL;
    session_id_valid = false;
    time_sin = 0.0;
    time_sin_valid = false;
    time_cos = 0.0;
    time_cos_valid = false;
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
  snapshot.stoch_structure_raw_percent = sl_fib_raw;
  snapshot.stoch_structure_raw_percent_valid = sl_fib_valid;
  snapshot.fib_entry_band_valid = entry_fib_valid &&
                                  DeterministicSignalStatsFibonacciBand(entry_fib_raw,
                                                                        snapshot.fib_entry_band);
  if(!snapshot.fib_sl_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "fib_sl_band");
  if(!snapshot.stoch_structure_raw_percent_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "stoch_structure_raw_percent");
  if(!snapshot.fib_entry_band_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "fib_entry_band");

  double b_percent_previous = 0.0;
  int base_delay = DeterministicStrategyBaseDelay(signal_params.strategy_id);
  snapshot.b_percent_main_base_valid =
    CopyDeterministicBPercentMainSlopeValues(DETERMINISTIC_BASE_TIMEFRAME,
                                             base_delay,
                                             snapshot.b_percent_main_base,
                                             b_percent_previous,
                                             snapshot.b_percent_main_base_slope);
  snapshot.b_percent_main_base_slope_valid = snapshot.b_percent_main_base_valid;
  if(!snapshot.b_percent_main_base_valid)
  {
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "b_percent_main_base");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "b_percent_main_base_slope");
  }

  ENUM_TIMEFRAMES macro_timeframe = DeterministicStrategyMacroTimeframe(signal_params.strategy_id);
  b_percent_previous = 0.0;
  snapshot.b_percent_main_macro_valid =
    CopyDeterministicBPercentMainSlopeValues(macro_timeframe,
                                             DETERMINISTIC_MACRO_DELAY,
                                             snapshot.b_percent_main_macro,
                                             b_percent_previous,
                                             snapshot.b_percent_main_macro_slope);
  snapshot.b_percent_main_macro_slope_valid = snapshot.b_percent_main_macro_valid;
  if(!snapshot.b_percent_main_macro_valid)
  {
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "b_percent_main_macro");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "b_percent_main_macro_slope");
  }

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
  snapshot.session_id = snapshot.entry_session_bucket;
  snapshot.session_id_valid = snapshot.entry_session_bucket_valid;
  if(!snapshot.entry_session_bucket_valid)
  {
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_session_bucket");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "session_id");
  }

  snapshot.entry_weekday = DeterministicSignalStatsWeekdayToken(snapshot.entry_time);
  snapshot.entry_weekday_valid = (snapshot.entry_weekday != "");
  if(!snapshot.entry_weekday_valid)
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "entry_weekday");

  snapshot.time_sin_valid = DeterministicSignalStatsTimeCycle(snapshot.entry_time,
                                                             snapshot.time_sin,
                                                             snapshot.time_cos);
  snapshot.time_cos_valid = snapshot.time_sin_valid;
  if(!snapshot.time_sin_valid)
  {
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "time_sin");
    DeterministicSignalFeatureSnapshotAddInvalid(snapshot, "time_cos");
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
            DeterministicSignalStatsCell(snapshot.entry_weekday_valid ? snapshot.entry_weekday : "") + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.stoch_structure_raw_percent_valid, snapshot.stoch_structure_raw_percent, 6) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.b_percent_main_base_valid, snapshot.b_percent_main_base, 6) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.b_percent_main_base_slope_valid, snapshot.b_percent_main_base_slope, 6) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.b_percent_main_macro_valid, snapshot.b_percent_main_macro, 6) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.b_percent_main_macro_slope_valid, snapshot.b_percent_main_macro_slope, 6) + "\t" +
            DeterministicSignalStatsCell(snapshot.session_id_valid ? snapshot.session_id : "") + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.time_sin_valid, snapshot.time_sin, 9) + "\t" +
            DeterministicSignalStatsDoubleToken(snapshot.time_cos_valid, snapshot.time_cos, 9);

  return true;
}

bool DeterministicSignalStatsTrackPath(SignalParams &signal_params,
                                       const ExecutionLegState &leg_state,
                                       const string signal_id)
{
  if(signal_id == "" || DeterministicSignalStatsFindPathState(signal_id) >= 0)
    return true;

  DeterministicSignalStatsPathState state;
  state.signal_id = signal_id;
  state.source_key = signal_params.deterministic_source_key;
  if(state.source_key == "")
    state.source_key = BuildDeterministicSignalSourceKey(signal_params);
  state.source_attempt_index = signal_params.deterministic_source_attempt_index;
  state.direction = signal_params.signal_type;
  state.entry_time = leg_state.last_action_time;
  if(state.entry_time <= 0)
    state.entry_time = TimeCurrent();
  state.entry_price = leg_state.entry_price;
  if(state.entry_price <= 0.0)
    state.entry_price = signal_params.entry_price;
  if(state.entry_price <= 0.0)
    state.entry_price = signal_params.execution_entry_reference_price;
  if(state.entry_price <= 0.0)
    state.entry_price = signal_params.raw_entry_trigger_price;
  state.stop_price = signal_params.raw_stop_anchor_price;
  state.risk_distance = MathAbs(state.entry_price - state.stop_price);
  if(state.risk_distance <= 0.0)
    state.risk_distance = MathAbs(signal_params.raw_risk_distance);
  state.path_horizon_bars = DETERMINISTIC_SIGNAL_STATS_PATH_HORIZON_BARS;

  if(state.entry_price <= 0.0 ||
     state.risk_distance <= 0.0 ||
     (state.direction != BULLISH && state.direction != BEARISH))
  {
    state.active = false;
    state.finalized = true;
    state.path_status = "INVALID";
  }
  else
  {
    state.active = true;
    state.finalized = false;
    state.path_status = "TRACKING";
  }

  int index = ArraySize(g_deterministic_signal_stats_path_states);
  int resized = ArrayResize(g_deterministic_signal_stats_path_states,
                            index + 1,
                            DETERMINISTIC_SIGNAL_STATS_PATH_RESERVE);
  if(resized != index + 1)
  {
    g_deterministic_signal_stats_failed = true;
    return false;
  }

  g_deterministic_signal_stats_path_states[index] = state;
  DeterministicSignalStatsUpdatePathState(index, TimeCurrent());
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
  DeterministicSignalStatsTrackPath(signal_params, leg_state, signal_params.deterministic_stats_signal_id);
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

bool DeterministicSignalStatsBuildOutcomePayload(SignalParams &signal_params,
                                                 DeterministicSignalStatsOutcomePayload &payload_out,
                                                 bool &valid_out)
{
  payload_out = DeterministicSignalStatsOutcomePayload();
  valid_out = true;

  if(!DeterministicSignalStatsReady() ||
     !signal_params.deterministic_strategy)
    return false;

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
  payload_out.valid = valid_out;
  payload_out.terminal_time = signal_params.close_time;
  payload_out.terminal_reason = DeterministicSignalStatsTerminalReason(signal_params);
  payload_out.profit_r = profit_r;
  payload_out.profit_r_valid = profit_r_valid;
  payload_out.duration_seconds = duration_seconds;
  payload_out.duration_m1_bars = duration_m1_bars;
  payload_out.duration_valid = duration_valid;
  payload_out.entry_price = entry_price;
  payload_out.entry_price_valid = entry_price_valid;
  payload_out.close_price = signal_params.close_price;
  payload_out.close_price_valid = close_price_valid;
  payload_out.net_profit = signal_params.raw_profit;
  payload_out.net_profit_valid = net_profit_valid;
  return true;
}

string DeterministicSignalStatsOutcomeRowFromPayload(const string signal_id,
                                                     const string source_key,
                                                     const int source_attempt_index,
                                                     const string broker_columns,
                                                     const DeterministicSignalStatsOutcomePayload &payload,
                                                     const string path_columns)
{
  return IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
         DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
         DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
         DeterministicSignalStatsCell(signal_id) + "\t" +
         DeterministicSignalStatsCell(source_key) + "\t" +
         IntegerToString(source_attempt_index) + "\t" +
         DeterministicSignalStatsTimeToken(payload.terminal_time) + "\t" +
         DeterministicSignalStatsCell(payload.terminal_reason) + "\t" +
         DeterministicSignalStatsDoubleToken(payload.profit_r_valid, payload.profit_r, 4) + "\t" +
         DeterministicSignalStatsIntToken(payload.duration_valid, payload.duration_seconds) + "\t" +
         DeterministicSignalStatsIntToken(payload.duration_valid, payload.duration_m1_bars) + "\t" +
         DeterministicSignalStatsDoubleToken(payload.entry_price_valid, payload.entry_price, Digits()) + "\t" +
         DeterministicSignalStatsDoubleToken(payload.close_price_valid, payload.close_price, Digits()) + "\t" +
         DeterministicSignalStatsDoubleToken(payload.net_profit_valid, payload.net_profit, 2) + "\t" +
         broker_columns + "\t" +
         path_columns;
}

string DeterministicSignalStatsBrokerOutcomeColumns(const SignalParams &signal_params)
{
  return DeterministicSignalStatsBoolToken(signal_params.broker_entry_confirmed) + "\t" +
         DeterministicSignalStatsBoolToken(signal_params.broker_close_confirmed) + "\t" +
         DeterministicSignalStatsCell(signal_params.broker_close_source) + "\t" +
         DeterministicSignalStatsCell(EnumToString(Partial_TP_Mode)) + "\t" +
         DeterministicSignalStatsBoolToken(signal_params.partial_tp1_confirmed) + "\t" +
         DeterministicSignalStatsBoolToken(signal_params.partial_tp2_confirmed) + "\t" +
         DeterministicSignalStatsBoolToken(signal_params.partial_tp3_confirmed) + "\t" +
         DeterministicSignalStatsDoubleToken(signal_params.partial_tp1_closed_volume > 0.0,
                                             signal_params.partial_tp1_closed_volume,
                                             4) + "\t" +
         DeterministicSignalStatsDoubleToken(signal_params.partial_tp2_closed_volume > 0.0,
                                             signal_params.partial_tp2_closed_volume,
                                             4) + "\t" +
         DeterministicSignalStatsDoubleToken(signal_params.partial_tp3_closed_volume > 0.0,
                                             signal_params.partial_tp3_closed_volume,
                                             4);
}

bool DeterministicSignalStatsWriteOutcomeRow(const string row,
                                             const bool valid)
{
  if(row == "")
    return false;

  string filename = DeterministicSignalStatsPath(DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE);
  if(!DeterministicSignalStatsQueueRow(filename,
                                       DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER,
                                       row,
                                       g_deterministic_signal_stats_outcome_buffer))
    return false;

  g_deterministic_signal_stats_outcome_rows++;
  if(!valid)
    g_deterministic_signal_stats_outcome_invalid_rows++;
  return true;
}

bool DeterministicSignalStatsMaybeWritePathOutcome(const int index)
{
  int total = ArraySize(g_deterministic_signal_stats_path_states);
  if(index < 0 || index >= total)
    return false;

  DeterministicSignalStatsPathState state = g_deterministic_signal_stats_path_states[index];
  if(state.outcome_written)
    return true;
  if(!state.broker_outcome_ready || !state.finalized)
    return false;

  bool path_labels_valid = DeterministicSignalStatsPathStatusHasFinalLabels(state.path_status);
  bool row_valid = state.outcome.valid && path_labels_valid;
  string row = DeterministicSignalStatsOutcomeRowFromPayload(state.signal_id,
                                                             state.source_key,
                                                             state.source_attempt_index,
                                                             state.broker_columns,
                                                             state.outcome,
                                                             DeterministicSignalStatsPathColumns(state));
  if(!DeterministicSignalStatsWriteOutcomeRow(row, row_valid))
    return false;

  g_deterministic_signal_stats_path_states[index].outcome_written = true;
  return true;
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

  DeterministicSignalStatsOutcomePayload payload;
  if(!DeterministicSignalStatsBuildOutcomePayload(signal_params,
                                                  payload,
                                                  valid_out))
    return false;

  row_out = IntegerToString(DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_run_id) + "\t" +
            DeterministicSignalStatsCell(g_deterministic_signal_stats_config_id) + "\t" +
            DeterministicSignalStatsCell(signal_id) + "\t" +
            DeterministicSignalStatsCell(source_key) + "\t" +
            IntegerToString(signal_params.deterministic_source_attempt_index) + "\t" +
            DeterministicSignalStatsTimeToken(payload.terminal_time) + "\t" +
            DeterministicSignalStatsCell(payload.terminal_reason) + "\t" +
            DeterministicSignalStatsDoubleToken(payload.profit_r_valid, payload.profit_r, 4) + "\t" +
            DeterministicSignalStatsIntToken(payload.duration_valid, payload.duration_seconds) + "\t" +
            DeterministicSignalStatsIntToken(payload.duration_valid, payload.duration_m1_bars) + "\t" +
            DeterministicSignalStatsDoubleToken(payload.entry_price_valid, payload.entry_price, Digits()) + "\t" +
            DeterministicSignalStatsDoubleToken(payload.close_price_valid, payload.close_price, Digits()) + "\t" +
            DeterministicSignalStatsDoubleToken(payload.net_profit_valid, payload.net_profit, 2) + "\t" +
            DeterministicSignalStatsBrokerOutcomeColumns(signal_params) + "\t" +
            DeterministicSignalStatsInvalidPathColumns();

  return true;
}

void DeterministicSignalStatsUpdatePathTracker()
{
  if(!DeterministicSignalStatsReady())
    return;

  datetime current_time = TimeCurrent();
  for(int i = ArraySize(g_deterministic_signal_stats_path_states) - 1; i >= 0; i--)
  {
    if(g_deterministic_signal_stats_path_states[i].outcome_written)
    {
      DeterministicSignalStatsRemovePathState(i);
      continue;
    }

    if(g_deterministic_signal_stats_path_states[i].active &&
       !g_deterministic_signal_stats_path_states[i].finalized)
    {
      DeterministicSignalStatsUpdatePathState(i, current_time);
    }

    if(i >= ArraySize(g_deterministic_signal_stats_path_states))
      continue;

    if(g_deterministic_signal_stats_path_states[i].finalized)
      DeterministicSignalStatsMaybeWritePathOutcome(i);

    if(i < ArraySize(g_deterministic_signal_stats_path_states) &&
       g_deterministic_signal_stats_path_states[i].outcome_written)
      DeterministicSignalStatsRemovePathState(i);
  }
}

void DeterministicSignalStatsFinalizePendingPaths(const string path_status)
{
  if(!DeterministicSignalStatsReady())
    return;

  for(int i = ArraySize(g_deterministic_signal_stats_path_states) - 1; i >= 0; i--)
  {
    if(!g_deterministic_signal_stats_path_states[i].finalized)
      DeterministicSignalStatsFinalizePathState(i, path_status);

    DeterministicSignalStatsMaybeWritePathOutcome(i);
    if(i < ArraySize(g_deterministic_signal_stats_path_states) &&
       g_deterministic_signal_stats_path_states[i].outcome_written)
      DeterministicSignalStatsRemovePathState(i);
  }
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

  string signal_id = DeterministicSignalStatsEnsureSignalId(signal_params);
  if(signal_id == "")
    return false;

  DeterministicSignalStatsOutcomePayload payload;
  bool valid = false;
  if(!DeterministicSignalStatsBuildOutcomePayload(signal_params,
                                                  payload,
                                                  valid))
    return false;

  int path_index = DeterministicSignalStatsFindPathState(signal_id);
  if(path_index >= 0)
  {
    g_deterministic_signal_stats_path_states[path_index].outcome = payload;
    g_deterministic_signal_stats_path_states[path_index].broker_columns =
      DeterministicSignalStatsBrokerOutcomeColumns(signal_params);
    g_deterministic_signal_stats_path_states[path_index].broker_outcome_ready = true;
    if(!valid &&
       !g_deterministic_signal_stats_path_states[path_index].finalized)
    {
      DeterministicSignalStatsFinalizePathState(path_index, "INVALID");
    }

    signal_params.deterministic_stats_outcome_exported = true;
    if(g_deterministic_signal_stats_path_states[path_index].finalized)
      return DeterministicSignalStatsMaybeWritePathOutcome(path_index);

    return true;
  }

  string row = "";
  bool row_valid = false;
  if(!DeterministicSignalStatsBuildOutcomeRow(signal_params,
                                              row,
                                              row_valid))
    return false;

  if(!DeterministicSignalStatsWriteOutcomeRow(row, false))
    return false;

  signal_params.deterministic_stats_outcome_exported = true;
  return true;
}

#endif // _TS_DETERMINISTIC_STATS_EXPORT_MQH_
