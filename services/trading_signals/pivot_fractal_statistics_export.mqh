//+------------------------------------------------------------------+
//|              trading_signals/pivot_fractal_statistics_export   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_

const int    PIVOT_V9_SCHEMA_VERSION = 9;
const string PIVOT_V9_ENGINE_LABEL   = "PIVOT_FRACTAL_V2";
const string PIVOT_V9_FEATURE_SET_ID = "schema_v9_pivot_fractal_xgb";
const string PIVOT_V9_STORAGE_ROOT   = "PivotFractalV9";
const string PIVOT_V9_RUNS_FOLDER    = "runs";
const string PIVOT_V9_NULL           = "\\N";
const int    PIVOT_V9_FLUSH_ROWS     = 256;

const string PIVOT_V9_MANIFEST_FILE = "run_manifest.tsv";
const string PIVOT_V9_WINDOWS_FILE  = "pivot_windows.tsv";
const string PIVOT_V9_LEVELS_FILE   = "pivot_levels.tsv";
const string PIVOT_V9_ATTEMPTS_FILE = "signal_attempts.tsv";
const string PIVOT_V9_FEATURES_FILE = "signal_features.tsv";
const string PIVOT_V9_CHECKS_FILE   = "execution_checks.tsv";
const string PIVOT_V9_TRAILING_FILE = "trailing_events.tsv";
const string PIVOT_V9_OUTCOMES_FILE = "signal_outcomes.tsv";
const string PIVOT_V9_SUMMARY_FILE  = "run_summary.tsv";

const string PIVOT_V9_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string PIVOT_V9_WINDOWS_HEADER =
  "schema_version\trun_id\tconfig_id\twindow_id\tsymbol\tpivot_timeframe\tactive_bar_open_broker_time\tactive_bar_open_analysis_time\tactive_bar_open_offset_minutes\tsource_bar_open_broker_time\tsource_bar_open_analysis_time\tsource_bar_open_offset_minutes\tsource_close_boundary_broker_time\tsource_close_boundary_analysis_time\tsource_close_boundary_offset_minutes\tsource_open\tsource_high\tsource_low\tsource_close\tsource_range\tfirst_observed_broker_time\tfirst_observed_analysis_time\tfirst_observed_offset_minutes\tfirst_observed_bid\tpp_initial_relation\tpp_role\tpp_arm_broker_time\tpp_arm_analysis_time\tpp_arm_offset_minutes\tpp_arm_bid\tmacro_band_base_1\tmacro_band_upper_1\tmacro_band_lower_1\tmacro_band_width_1\tmacro_band_width_percent_1\tmacro_band_complete\tmacro_band_invalid_reason\twindow_state\tinvalid_reason\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status";
const string PIVOT_V9_LEVELS_HEADER =
  "schema_version\trun_id\tconfig_id\twindow_id\tsymbol\tpivot_timeframe\tactive_bar_open_broker_time\tlevel_id\traw_price\ttrade_price\tlevel_order";
const string PIVOT_V9_ATTEMPTS_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tsymbol\tpivot_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\ttrigger_bid\ttrigger_ask\tspread_points\tintended_entry_price\tinitial_stop_loss\tterminal_take_profit\troute_status\tattempt_status\tblock_source\tblock_reason\tfeature_snapshot_complete\tsend_attempted";
const string PIVOT_V9_FEATURES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tsymbol\tpivot_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\tmicro_band_base_0\tmicro_band_upper_0\tmicro_band_lower_0\tmicro_band_width_0\tmicro_band_width_percent_0\tmicro_b_percent_0\tmicro_b_percent_1\tmicro_b_percent_2\tmicro_b_percent_3\tmicro_b_percent_4\tmicro_b_percent_5\tmacro_pivot_b_percent_0\tmacro_pivot_b_percent_1\tmacro_pivot_b_percent_2\tmacro_pivot_b_percent_3\tmacro_pivot_b_percent_4\tmacro_pivot_b_percent_5\tmicro_features_complete\tmacro_features_complete\tfeature_complete\tinvalid_reason";
const string PIVOT_V9_CHECKS_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tcheck_sequence\tcheck_phase\tbroker_time\tanalysis_time\toffset_minutes\tsymbol\tdirection\taccount_margin_mode\taccount_margin_mode_supported\tsymbol_trade_mode\tsymbol_trade_mode_allowed\tmarket_session_open\taccount_trade_allowed\taccount_expert_trade_allowed\tterminal_trade_allowed\tmql_trade_allowed\tbid\task\tspread_points\tpoint_size\tstops_distance_points\tfreeze_distance_points\tplanned_entry_price\tstop_loss_price\ttake_profit_price\trisk_distance\trequested_volume\tnormalized_volume\tvolume_min\tvolume_max\tvolume_step\tvolume_valid\taccount_balance\tfree_margin\trequired_margin\tmargin_valid\tgeometry_valid\tstop_distance_valid\tfreeze_distance_valid\torder_check_performed\torder_check_allowed\torder_check_retcode\torder_check_comment\tallowed\tblock_source\tblock_reason\tsend_retcode\tsend_comment\torder_ticket\tdeal_ticket\tposition_ticket\tposition_identifier\tbroker_entry_confirmed\tbroker_close_confirmed\tbroker_entry_price\tbroker_volume\tbroker_stop_loss\tbroker_take_profit\tclose_price\tclosed_volume\trealized_profit\tterminal_reason";
const string PIVOT_V9_TRAILING_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tevent_sequence\tevent_broker_time\tevent_analysis_time\tevent_offset_minutes\tsymbol\tdirection\tposition_ticket\tposition_identifier\tmilestone_level\tmilestone_price\tprevious_confirmed_stop\tdesired_stop\trequested_stop\tconfirmed_stop\ttake_profit\trequest_performed\trequest_succeeded\tretcode\tcomment\tretry_pending\tevent_status";
const string PIVOT_V9_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tsymbol\tpivot_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\tentry_broker_time\tentry_analysis_time\tentry_offset_minutes\tclose_broker_time\tclose_analysis_time\tclose_offset_minutes\torder_ticket\tentry_deal_ticket\tclose_deal_ticket\tposition_ticket\tposition_identifier\tbroker_entry_price\tbroker_volume\tinitial_stop_loss\tterminal_take_profit\tfinal_broker_stop_loss\tfinal_broker_take_profit\tclose_price\tclosed_volume\trealized_profit\thighest_milestone_level\tterminal_reason\tduration_seconds\tbroker_entry_confirmed\tbroker_close_confirmed";
const string PIVOT_V9_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_broker_time\tstarted_analysis_time\tstarted_offset_minutes\tfinished_broker_time\tfinished_analysis_time\tfinished_offset_minutes\tpivot_window_rows\tpivot_level_rows\tsignal_attempt_rows\tsignal_feature_rows\texecution_check_rows\ttrailing_event_rows\tsignal_outcome_rows\tfeature_incomplete_rows\tduplicate_identity_count\treferential_integrity_error_count\trow_integrity_error_count\texport_status\tcompletion_status";

struct PivotV9AttemptPayload
{
  string signal_id;
  string window_id;
  ENUM_TIMEFRAMES pivot_timeframe;
  datetime active_bar_open;
  PivotLevelIds level_id;
  SignalTypes direction;
  datetime trigger_time;
  double trigger_bid;
  double trigger_ask;
  double spread_points;
  double intended_entry_price;
  double initial_stop_loss;
  double terminal_take_profit;
  PivotRouteStatuses route_status;
  string attempt_status;
  string block_source;
  string block_reason;
  bool feature_snapshot_complete;
  bool send_attempted;

  PivotV9AttemptPayload()
  {
    signal_id                 = "";
    window_id                 = "";
    pivot_timeframe           = PERIOD_CURRENT;
    active_bar_open           = 0;
    level_id                  = PIVOT_LEVEL_PP;
    direction                 = NO_SIGNAL;
    trigger_time              = 0;
    trigger_bid               = 0.0;
    trigger_ask               = 0.0;
    spread_points             = 0.0;
    intended_entry_price      = 0.0;
    initial_stop_loss         = 0.0;
    terminal_take_profit      = 0.0;
    route_status              = PIVOT_ROUTE_NOT_BUILT;
    attempt_status            = "";
    block_source              = "";
    block_reason              = "";
    feature_snapshot_complete = false;
    send_attempted            = false;
  }
};

struct PivotV9ExecutionPayload
{
  string signal_id;
  string window_id;
  BrokerExecutionCheck check;
  ulong position_ticket;
  ulong position_identifier;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;
  double broker_entry_price;
  double broker_volume;
  double broker_stop_loss;
  double broker_take_profit;
  double close_price;
  double closed_volume;
  double realized_profit;
  string terminal_reason;

  PivotV9ExecutionPayload()
  {
    signal_id              = "";
    window_id              = "";
    position_ticket        = 0;
    position_identifier    = 0;
    broker_entry_confirmed = false;
    broker_close_confirmed = false;
    broker_entry_price     = 0.0;
    broker_volume          = 0.0;
    broker_stop_loss       = 0.0;
    broker_take_profit     = 0.0;
    close_price            = 0.0;
    closed_volume          = 0.0;
    realized_profit        = 0.0;
    terminal_reason        = "";
  }
};

struct PivotV9TrailingPayload
{
  string signal_id;
  string window_id;
  int event_sequence;
  datetime event_time;
  SignalTypes direction;
  ulong position_ticket;
  ulong position_identifier;
  PivotLevelIds milestone_level;
  double milestone_price;
  double previous_confirmed_stop;
  double desired_stop;
  double requested_stop;
  double confirmed_stop;
  double take_profit;
  bool request_performed;
  bool request_succeeded;
  ulong retcode;
  string comment;
  bool retry_pending;
  string event_status;

  PivotV9TrailingPayload()
  {
    signal_id               = "";
    window_id               = "";
    event_sequence          = 0;
    event_time              = 0;
    direction               = NO_SIGNAL;
    position_ticket         = 0;
    position_identifier     = 0;
    milestone_level         = PIVOT_LEVEL_PP;
    milestone_price         = 0.0;
    previous_confirmed_stop = 0.0;
    desired_stop            = 0.0;
    requested_stop          = 0.0;
    confirmed_stop          = 0.0;
    take_profit             = 0.0;
    request_performed       = false;
    request_succeeded       = false;
    retcode                 = 0;
    comment                 = "";
    retry_pending           = false;
    event_status            = "";
  }
};

struct PivotV9OutcomePayload
{
  string signal_id;
  string window_id;
  ENUM_TIMEFRAMES pivot_timeframe;
  datetime active_bar_open;
  PivotLevelIds level_id;
  SignalTypes direction;
  datetime entry_time;
  datetime close_time;
  ulong order_ticket;
  ulong entry_deal_ticket;
  ulong close_deal_ticket;
  ulong position_ticket;
  ulong position_identifier;
  double broker_entry_price;
  double broker_volume;
  double initial_stop_loss;
  double terminal_take_profit;
  double final_broker_stop_loss;
  double final_broker_take_profit;
  double close_price;
  double closed_volume;
  double realized_profit;
  string highest_milestone_level;
  string terminal_reason;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;

  PivotV9OutcomePayload()
  {
    signal_id                  = "";
    window_id                  = "";
    pivot_timeframe            = PERIOD_CURRENT;
    active_bar_open            = 0;
    level_id                   = PIVOT_LEVEL_PP;
    direction                  = NO_SIGNAL;
    entry_time                 = 0;
    close_time                 = 0;
    order_ticket               = 0;
    entry_deal_ticket          = 0;
    close_deal_ticket          = 0;
    position_ticket            = 0;
    position_identifier        = 0;
    broker_entry_price         = 0.0;
    broker_volume              = 0.0;
    initial_stop_loss          = 0.0;
    terminal_take_profit       = 0.0;
    final_broker_stop_loss     = 0.0;
    final_broker_take_profit   = 0.0;
    close_price                = 0.0;
    closed_volume              = 0.0;
    realized_profit            = 0.0;
    highest_milestone_level    = "";
    terminal_reason            = "";
    broker_entry_confirmed     = false;
    broker_close_confirmed     = false;
  }
};

string g_pivot_v9_run_id    = "";
string g_pivot_v9_config_id = "";
string g_pivot_v9_folder    = "";
datetime g_pivot_v9_started_at = 0;
bool g_pivot_v9_initialized = false;
bool g_pivot_v9_failed      = false;
int g_pivot_v9_window_rows  = 0;
int g_pivot_v9_level_rows   = 0;
int g_pivot_v9_attempt_rows = 0;
int g_pivot_v9_feature_rows = 0;
int g_pivot_v9_check_rows   = 0;
int g_pivot_v9_trailing_rows = 0;
int g_pivot_v9_outcome_rows = 0;
int g_pivot_v9_feature_incomplete_rows = 0;
int g_pivot_v9_duplicate_identity_count = 0;
int g_pivot_v9_referential_integrity_error_count = 0;
int g_pivot_v9_row_integrity_error_count = 0;
bool g_pivot_v9_error_logged = false;
string g_pivot_v9_window_buffer[];
string g_pivot_v9_level_buffer[];
string g_pivot_v9_attempt_buffer[];
string g_pivot_v9_feature_buffer[];
string g_pivot_v9_check_buffer[];
string g_pivot_v9_trailing_buffer[];
string g_pivot_v9_outcome_buffer[];

bool PivotV9Enabled()
{
  return Enable_Signal_Feature_Export;
}

bool PivotV9Ready()
{
  return PivotV9Enabled() && g_pivot_v9_initialized && !g_pivot_v9_failed;
}

void PivotV9MarkFailed(const string operation,
                       const string filename = "",
                       const int error_code = 0)
{
  g_pivot_v9_failed = true;
  if(g_pivot_v9_error_logged || (!Enable_Logs && !Enable_File_Logs))
    return;
  PrintFormat("PIVOT_V9_EXPORT_FAILED | operation=%s | file=%s | error=%d",
              operation,
              filename,
              error_code);
  g_pivot_v9_error_logged = true;
}

bool PivotV9RejectReference(const string operation)
{
  g_pivot_v9_referential_integrity_error_count++;
  if(!g_pivot_v9_error_logged && (Enable_Logs || Enable_File_Logs))
  {
    PrintFormat("PIVOT_V9_REFERENCE_REJECTED | operation=%s", operation);
    g_pivot_v9_error_logged = true;
  }
  return false;
}

string PivotV9BoolToken(const bool value)
{
  return value ? "1" : "0";
}

string PivotV9Cell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  if(value == "")
    return PIVOT_V9_NULL;
  return value;
}

string PivotV9TimeToken(const datetime value)
{
  if(value <= 0)
    return PIVOT_V9_NULL;
  return TimeToString(value, TIME_DATE | TIME_SECONDS);
}

string PivotV9DoubleToken(const double value,
                          const bool zero_allowed = true)
{
  if(!MathIsValidNumber(value) || (!zero_allowed && value <= 0.0))
    return PIVOT_V9_NULL;
  return DoubleToString(value, 10);
}

string PivotV9UlongToken(const ulong value)
{
  if(value == 0)
    return PIVOT_V9_NULL;
  return StringFormat("%I64u", value);
}

string PivotV9DirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BUY";
  if(direction == BEARISH)
    return "SELL";
  return "NONE";
}

string PivotV9WindowStateToken(const PivotWindowStates state)
{
  switch(state)
  {
    case PIVOT_WINDOW_EMPTY:   return "EMPTY";
    case PIVOT_WINDOW_PENDING: return "PENDING";
    case PIVOT_WINDOW_VALID:   return "VALID";
    case PIVOT_WINDOW_INVALID: return "INVALID";
  }
  return "UNKNOWN";
}

string PivotV9PriceSideToken(const PivotPriceSideStates side)
{
  switch(side)
  {
    case PIVOT_PRICE_SIDE_BELOW: return "BELOW";
    case PIVOT_PRICE_SIDE_EQUAL: return "EQUAL";
    case PIVOT_PRICE_SIDE_ABOVE: return "ABOVE";
  }
  return "UNAVAILABLE";
}

string PivotV9PpRoleToken(const PivotPpArmStates state)
{
  if(state == PIVOT_PP_BUY_ARMED)
    return "BUY";
  if(state == PIVOT_PP_SELL_ARMED)
    return "SELL";
  return "UNARMED";
}

string PivotV9RouteStatusToken(const PivotRouteStatuses status)
{
  switch(status)
  {
    case PIVOT_ROUTE_NOT_BUILT:        return "NOT_BUILT";
    case PIVOT_ROUTE_ALLOWED:          return "ALLOWED";
    case PIVOT_ROUTE_NO_FORWARD_LEVEL: return "NO_FORWARD_LEVEL";
    case PIVOT_ROUTE_INVALID_GEOMETRY: return "INVALID_GEOMETRY";
  }
  return "UNKNOWN";
}

string PivotV9TimestampColumns(const datetime broker_time,
                               const string symbol = "")
{
  string resolved_symbol = symbol == "" ? _Symbol : symbol;
  int offset_minutes = 0;
  datetime analysis_time = MarketDataNormalizeAnalysisTime(broker_time,
                                                            Broker_Session,
                                                            resolved_symbol,
                                                            offset_minutes);
  bool valid = (broker_time > 0 && analysis_time > 0);
  return PivotV9TimeToken(broker_time) + "\t" +
         PivotV9TimeToken(analysis_time) + "\t" +
         (valid ? IntegerToString(offset_minutes) : PIVOT_V9_NULL);
}

string PivotV9SanitizePart(const string raw_value)
{
  string value = raw_value == "" ? "default" : raw_value;
  string result = "";
  for(int i = 0; i < StringLen(value); i++)
  {
    ushort ch = StringGetCharacter(value, i);
    bool safe = (ch >= '0' && ch <= '9') ||
                (ch >= 'A' && ch <= 'Z') ||
                (ch >= 'a' && ch <= 'z') ||
                ch == '_' || ch == '-' || ch == '.';
    result += safe ? StringSubstr(value, i, 1) : "_";
  }
  return result == "" ? "default" : result;
}

ulong PivotV9Hash(const string value)
{
  ulong hash = 1469598103934665603;
  for(int i = 0; i < StringLen(value); i++)
  {
    hash ^= (ulong)StringGetCharacter(value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string PivotV9HashToken(const string value)
{
  return StringFormat("%I64u", PivotV9Hash(value));
}

string PivotV9WindowId(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const datetime active_bar_open)
{
  string identity = symbol + "|" +
                    IntegerToString((int)timeframe) + "|" +
                    StringFormat("%I64d", (long)active_bar_open);
  return "win_" + PivotV9HashToken(identity);
}

string PivotV9SignalId(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const datetime active_bar_open,
                       const PivotLevelIds level)
{
  string identity = symbol + "|" +
                    IntegerToString((int)timeframe) + "|" +
                    StringFormat("%I64d", (long)active_bar_open) + "|" +
                    PivotLevelLabel(level);
  return "sig_" + PivotV9HashToken(identity);
}

string PivotV9BuildConfigPayload()
{
  return StringFormat("schema=%d|engine=%s|symbol=%s|chart_tf=%d|macro_tf=%d|micro_tf=%d|trigger=live_bid_virtual_limit|pp=first_causal_bid_side_return|bands=%d,%.4f,PRICE_WEIGHTED|broker_session=%d|lot_type=%d|lot_size=%.8f",
                      PIVOT_V9_SCHEMA_VERSION,
                      PIVOT_V9_ENGINE_LABEL,
                      _Symbol,
                      (int)_Period,
                      (int)Macro_Timeframe,
                      (int)Micro_Timeframe,
                      PIVOT_CONTEXT_BANDS_PERIOD,
                      PIVOT_CONTEXT_B_PERCENT_DEVIATION,
                      (int)Broker_Session,
                      (int)Lot_Type,
                      Lot_Strategy_Size);
}

string PivotV9BuildRunId()
{
  if(Signal_Feature_Run_Id != "")
    return PivotV9SanitizePart(Signal_Feature_Run_Id);
  string time_token = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
  return PivotV9SanitizePart(time_token + "_" + _Symbol + "_pivot_v9");
}

string PivotV9Path(const string filename)
{
  return g_pivot_v9_folder + "\\" + filename;
}

bool PivotV9EnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_pivot_v9_folder, delimiter, parts);
  if(total <= 0)
    return false;

  string current = "";
  for(int i = 0; i < total; i++)
  {
    if(parts[i] == "")
      continue;
    current = current == "" ? parts[i] : current + "\\" + parts[i];
    ResetLastError();
    FolderCreate(current, FILE_COMMON);
    int error = GetLastError();
    if(error != 0 && error != 5019)
    {
      PivotV9MarkFailed("CREATE_FOLDER", current, error);
      return false;
    }
  }
  return true;
}

int PivotV9ColumnCount(const string row)
{
  if(row == "")
    return 0;
  int columns = 1;
  for(int i = 0; i < StringLen(row); i++)
  {
    if(StringGetCharacter(row, i) == '\t')
      columns++;
  }
  return columns;
}

bool PivotV9RowMatchesHeader(const string header,
                             const string row)
{
  bool matches = PivotV9ColumnCount(header) == PivotV9ColumnCount(row);
  if(!matches)
  {
    g_pivot_v9_row_integrity_error_count++;
    PivotV9MarkFailed("ROW_COLUMN_COUNT");
  }
  return matches;
}

bool PivotV9FileHeaderMatches(const string filename,
                              const string expected_header)
{
  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    PivotV9MarkFailed("OPEN_HEADER", filename, GetLastError());
    return false;
  }
  string actual_header = FileReadString(handle);
  FileClose(handle);
  if(actual_header != expected_header)
  {
    PivotV9MarkFailed("HEADER_MISMATCH", filename);
    return false;
  }
  return true;
}

bool PivotV9WriteLine(const string filename,
                      const string line,
                      const bool append)
{
  int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
  if(append)
    flags |= FILE_READ;
  ResetLastError();
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    PivotV9MarkFailed("OPEN_WRITE", filename, GetLastError());
    return false;
  }
  if(append && !FileSeek(handle, 0, SEEK_END))
  {
    PivotV9MarkFailed("SEEK_END", filename, GetLastError());
    FileClose(handle);
    return false;
  }
  bool written = FileWrite(handle, line) > 0;
  FileClose(handle);
  if(!written)
    PivotV9MarkFailed("WRITE_LINE", filename, GetLastError());
  return written;
}

bool PivotV9AppendRows(const string filename,
                       const string header,
                       string &buffer[])
{
  int total = ArraySize(buffer);
  if(total <= 0)
    return true;

  if(!FileIsExist(filename, FILE_COMMON))
  {
    PivotV9MarkFailed("DATA_FILE_MISSING", filename);
    return false;
  }
  if(!PivotV9FileHeaderMatches(filename, header))
    return false;

  int flags = FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON;
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    PivotV9MarkFailed("OPEN_APPEND", filename, GetLastError());
    return false;
  }
  if(!FileSeek(handle, 0, SEEK_END))
  {
    PivotV9MarkFailed("SEEK_APPEND", filename, GetLastError());
    FileClose(handle);
    return false;
  }

  bool success = true;
  for(int i = 0; i < total; i++)
  {
    if(!PivotV9RowMatchesHeader(header, buffer[i]) ||
       FileWrite(handle, buffer[i]) == 0)
    {
      success = false;
      break;
    }
  }
  FileClose(handle);
  if(!success)
    PivotV9MarkFailed("WRITE_BATCH", filename, GetLastError());
  return success;
}

bool PivotV9FlushBuffer(const string filename,
                        const string header,
                        string &buffer[])
{
  if(ArraySize(buffer) <= 0)
    return true;
  if(!PivotV9AppendRows(filename, header, buffer))
    return false;
  ArrayResize(buffer, 0);
  return true;
}

bool PivotV9QueueRow(const string filename,
                     const string header,
                     const string row,
                     string &buffer[])
{
  if(!PivotV9Ready() || !PivotV9RowMatchesHeader(header, row))
    return false;
  int total = ArraySize(buffer);
  if(ArrayResize(buffer, total + 1, PIVOT_V9_FLUSH_ROWS) != total + 1)
  {
    PivotV9MarkFailed("BUFFER_RESIZE", filename);
    return false;
  }
  buffer[total] = row;
  if(ArraySize(buffer) >= PIVOT_V9_FLUSH_ROWS)
    return PivotV9FlushBuffer(filename, header, buffer);
  return true;
}

bool PivotV9FlushAll()
{
  bool windows_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_WINDOWS_FILE), PIVOT_V9_WINDOWS_HEADER, g_pivot_v9_window_buffer);
  bool levels_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_LEVELS_FILE), PIVOT_V9_LEVELS_HEADER, g_pivot_v9_level_buffer);
  bool attempts_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_ATTEMPTS_FILE), PIVOT_V9_ATTEMPTS_HEADER, g_pivot_v9_attempt_buffer);
  bool features_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_FEATURES_FILE), PIVOT_V9_FEATURES_HEADER, g_pivot_v9_feature_buffer);
  bool checks_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_CHECKS_FILE), PIVOT_V9_CHECKS_HEADER, g_pivot_v9_check_buffer);
  bool trailing_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_TRAILING_FILE), PIVOT_V9_TRAILING_HEADER, g_pivot_v9_trailing_buffer);
  bool outcomes_ok = PivotV9FlushBuffer(PivotV9Path(PIVOT_V9_OUTCOMES_FILE), PIVOT_V9_OUTCOMES_HEADER, g_pivot_v9_outcome_buffer);
  return windows_ok && levels_ok && attempts_ok && features_ok &&
         checks_ok && trailing_ok && outcomes_ok;
}

string PivotV9ManifestRow(const string key,
                          const string value)
{
  return IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
         PivotV9Cell(key) + "\t" + PivotV9Cell(value);
}

bool PivotV9WriteManifest()
{
  string filename = PivotV9Path(PIVOT_V9_MANIFEST_FILE);
  if(FileIsExist(filename, FILE_COMMON))
    return false;
  if(!PivotV9WriteLine(filename, PIVOT_V9_MANIFEST_HEADER, false))
    return false;

  string rows[];
  ArrayResize(rows, 22);
  rows[0]  = PivotV9ManifestRow("run_id", g_pivot_v9_run_id);
  rows[1]  = PivotV9ManifestRow("config_id", g_pivot_v9_config_id);
  rows[2]  = PivotV9ManifestRow("started_broker_time", PivotV9TimeToken(g_pivot_v9_started_at));
  rows[3]  = PivotV9ManifestRow("symbol", _Symbol);
  rows[4]  = PivotV9ManifestRow("chart_period", EnumToString(_Period));
  rows[5]  = PivotV9ManifestRow("engine_id", IntegerToString(PIVOT_FRACTAL_V2));
  rows[6]  = PivotV9ManifestRow("engine_label", PIVOT_V9_ENGINE_LABEL);
  rows[7]  = PivotV9ManifestRow("pivot_timeframes", EnumToString(Macro_Timeframe));
  rows[8]  = PivotV9ManifestRow("feature_context_timeframes", EnumToString(Micro_Timeframe) + "," + EnumToString(Macro_Timeframe));
  rows[9]  = PivotV9ManifestRow("pivot_formula", "CLASSIC_PP_S1_S3_R1_R3");
  rows[10] = PivotV9ManifestRow("source_policy", "immediately_previous_completed_broker_candle_shift_1");
  rows[11] = PivotV9ManifestRow("identity_policy", "symbol,macro_timeframe,active_bar_open,level_first_touch_once");
  rows[12] = PivotV9ManifestRow("trigger_policy", "live_bid_virtual_limit_support_buy_resistance_sell_pp_return");
  rows[13] = PivotV9ManifestRow("execution_price_policy", "buy_ask_sell_bid_market_deal");
  rows[14] = PivotV9ManifestRow("time_policy", "broker_time_causal_analysis_time_export_only");
  rows[15] = PivotV9ManifestRow("broker_session", MarketDataTimePolicyToken(Broker_Session));
  rows[16] = PivotV9ManifestRow("lot_mode", EnumToString(Lot_Type));
  rows[17] = PivotV9ManifestRow("lot_size", DoubleToString(Lot_Strategy_Size, 8));
  rows[18] = PivotV9ManifestRow("b_percent", StringFormat("iBands;period=%d;deviation=%.4f;PRICE_WEIGHTED;shifts=0..5;shift0=trigger_bid;raw", PIVOT_CONTEXT_BANDS_PERIOD, PIVOT_CONTEXT_B_PERCENT_DEVIATION));
  rows[19] = PivotV9ManifestRow("feature_set_id", PIVOT_V9_FEATURE_SET_ID);
  rows[20] = PivotV9ManifestRow("outcome_policy", "broker_confirmed_only");
  rows[21] = PivotV9ManifestRow("research_approval_state", "OFFLINE_RESEARCH_ONLY");

  for(int i = 0; i < ArraySize(rows); i++)
  {
    if(!PivotV9RowMatchesHeader(PIVOT_V9_MANIFEST_HEADER, rows[i]) ||
       !PivotV9WriteLine(filename, rows[i], true))
      return false;
  }
  return true;
}

bool PivotV9CreateDataFiles()
{
  return PivotV9WriteLine(PivotV9Path(PIVOT_V9_WINDOWS_FILE), PIVOT_V9_WINDOWS_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_LEVELS_FILE), PIVOT_V9_LEVELS_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_ATTEMPTS_FILE), PIVOT_V9_ATTEMPTS_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_FEATURES_FILE), PIVOT_V9_FEATURES_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_CHECKS_FILE), PIVOT_V9_CHECKS_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_TRAILING_FILE), PIVOT_V9_TRAILING_HEADER, false) &&
         PivotV9WriteLine(PivotV9Path(PIVOT_V9_OUTCOMES_FILE), PIVOT_V9_OUTCOMES_HEADER, false);
}

bool PivotV9RunFilesExist()
{
  return FileIsExist(PivotV9Path(PIVOT_V9_MANIFEST_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_WINDOWS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_LEVELS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_ATTEMPTS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_FEATURES_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_CHECKS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_TRAILING_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_OUTCOMES_FILE), FILE_COMMON) ||
         FileIsExist(PivotV9Path(PIVOT_V9_SUMMARY_FILE), FILE_COMMON);
}

bool PivotV9RecordWindow(const PivotFractalWindowState &window,
                         const datetime terminal_time,
                         const string terminal_status)
{
  if(!PivotV9Ready())
    return false;
  if(window.active_bar_open <= 0)
    return PivotV9RejectReference("RECORD_WINDOW");
  string window_id = PivotV9WindowId(_Symbol,
                                     window.timeframe,
                                     window.active_bar_open);
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(window_id) + "\t" +
               PivotV9Cell(_Symbol) + "\t" +
               PivotV9Cell(EnumToString(window.timeframe)) + "\t" +
               PivotV9TimestampColumns(window.active_bar_open) + "\t" +
               PivotV9TimestampColumns(window.source_bar_open) + "\t" +
               PivotV9TimestampColumns(window.source_close_boundary) + "\t" +
               PivotV9DoubleToken(window.levels.source_open, false) + "\t" +
               PivotV9DoubleToken(window.levels.source_high, false) + "\t" +
               PivotV9DoubleToken(window.levels.source_low, false) + "\t" +
               PivotV9DoubleToken(window.levels.source_close, false) + "\t" +
               PivotV9DoubleToken(window.levels.source_range, false) + "\t" +
               PivotV9TimestampColumns(window.first_observed_time) + "\t" +
               PivotV9DoubleToken(window.first_observed_bid, false) + "\t" +
               PivotV9PriceSideToken(window.pp_initial_relation) + "\t" +
               PivotV9PpRoleToken(window.pp_arm_state) + "\t" +
               PivotV9TimestampColumns(window.pp_arm_time) + "\t" +
               (window.pp_arm_state != PIVOT_PP_UNARMED
                ? PivotV9DoubleToken(window.pp_arm_bid, false)
                : PIVOT_V9_NULL) + "\t" +
               (window.macro_band.complete
                ? PivotV9DoubleToken(window.macro_band.base_1, false)
                : PIVOT_V9_NULL) + "\t" +
               (window.macro_band.complete
                ? PivotV9DoubleToken(window.macro_band.upper_1, false)
                : PIVOT_V9_NULL) + "\t" +
               (window.macro_band.complete
                ? PivotV9DoubleToken(window.macro_band.lower_1, false)
                : PIVOT_V9_NULL) + "\t" +
               (window.macro_band.complete
                ? PivotV9DoubleToken(window.macro_band.width_1, false)
                : PIVOT_V9_NULL) + "\t" +
               (window.macro_band.complete
                ? PivotV9DoubleToken(window.macro_band.width_percent_1, false)
                : PIVOT_V9_NULL) + "\t" +
               PivotV9BoolToken(window.macro_band.complete) + "\t" +
               PivotV9Cell(window.macro_band.invalid_reason) + "\t" +
               PivotV9WindowStateToken(window.state) + "\t" +
               PivotV9Cell(window.invalid_reason) + "\t" +
               PivotV9TimestampColumns(terminal_time) + "\t" +
               PivotV9Cell(terminal_status);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_WINDOWS_FILE),
                      PIVOT_V9_WINDOWS_HEADER,
                      row,
                      g_pivot_v9_window_buffer))
    return false;
  g_pivot_v9_window_rows++;
  return true;
}

bool PivotV9RecordLevels(const PivotFractalWindowState &window)
{
  if(!PivotV9Ready())
    return false;
  if(window.active_bar_open <= 0 ||
     window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid)
    return PivotV9RejectReference("RECORD_LEVELS");
  string window_id = PivotV9WindowId(_Symbol,
                                     window.timeframe,
                                     window.active_bar_open);
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
  {
    PivotLevelIds level = (PivotLevelIds)i;
    string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
                 PivotV9Cell(g_pivot_v9_run_id) + "\t" +
                 PivotV9Cell(g_pivot_v9_config_id) + "\t" +
                 PivotV9Cell(window_id) + "\t" +
                 PivotV9Cell(_Symbol) + "\t" +
                 PivotV9Cell(EnumToString(window.timeframe)) + "\t" +
                 PivotV9TimeToken(window.active_bar_open) + "\t" +
                 PivotLevelLabel(level) + "\t" +
                 PivotV9DoubleToken(window.levels.raw_prices[i], false) + "\t" +
                 PivotV9DoubleToken(window.levels.trade_prices[i], false) + "\t" +
                 IntegerToString(i);
    if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_LEVELS_FILE),
                        PIVOT_V9_LEVELS_HEADER,
                        row,
                        g_pivot_v9_level_buffer))
      return false;
    g_pivot_v9_level_rows++;
  }
  return true;
}

bool PivotV9RecordAttempt(const PivotV9AttemptPayload &payload)
{
  if(!PivotV9Ready())
    return false;
  if(payload.signal_id == "" || payload.window_id == "")
    return PivotV9RejectReference("RECORD_ATTEMPT");
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(payload.signal_id) + "\t" +
               PivotV9Cell(payload.window_id) + "\t" +
               PivotV9Cell(_Symbol) + "\t" +
               PivotV9Cell(EnumToString(payload.pivot_timeframe)) + "\t" +
               PivotV9TimeToken(payload.active_bar_open) + "\t" +
               PivotLevelLabel(payload.level_id) + "\t" +
               PivotV9DirectionToken(payload.direction) + "\t" +
               PivotV9TimestampColumns(payload.trigger_time) + "\t" +
               PivotV9DoubleToken(payload.trigger_bid, false) + "\t" +
               PivotV9DoubleToken(payload.trigger_ask, false) + "\t" +
               PivotV9DoubleToken(payload.spread_points) + "\t" +
               PivotV9DoubleToken(payload.intended_entry_price, false) + "\t" +
               PivotV9DoubleToken(payload.initial_stop_loss, false) + "\t" +
               PivotV9DoubleToken(payload.terminal_take_profit, false) + "\t" +
               PivotV9RouteStatusToken(payload.route_status) + "\t" +
               PivotV9Cell(payload.attempt_status) + "\t" +
               PivotV9Cell(payload.block_source) + "\t" +
               PivotV9Cell(payload.block_reason) + "\t" +
               PivotV9BoolToken(payload.feature_snapshot_complete) + "\t" +
               PivotV9BoolToken(payload.send_attempted);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_ATTEMPTS_FILE),
                      PIVOT_V9_ATTEMPTS_HEADER,
                      row,
                      g_pivot_v9_attempt_buffer))
    return false;
  g_pivot_v9_attempt_rows++;
  return true;
}

bool PivotV9RecordFeatures(const PivotV9AttemptPayload &attempt,
                           const PivotContextFeatureSnapshot &snapshot)
{
  if(!PivotV9Ready())
    return false;
  if(attempt.signal_id == "" || attempt.window_id == "" || !snapshot.captured)
    return PivotV9RejectReference("RECORD_FEATURES");

  string micro_tokens = "";
  string macro_tokens = "";
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    if(shift > 0)
    {
      micro_tokens += "\t";
      macro_tokens += "\t";
    }
    micro_tokens += snapshot.micro_b_percent_available[shift]
                    ? PivotV9DoubleToken(snapshot.micro_b_percent[shift])
                    : PIVOT_V9_NULL;
    macro_tokens += snapshot.macro_pivot_b_percent_available[shift]
                    ? PivotV9DoubleToken(snapshot.macro_pivot_b_percent[shift])
                    : PIVOT_V9_NULL;
  }

  bool micro_shift_zero_available = snapshot.micro_bands.available[0];
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(attempt.signal_id) + "\t" +
               PivotV9Cell(attempt.window_id) + "\t" +
               PivotV9Cell(_Symbol) + "\t" +
               PivotV9Cell(EnumToString(attempt.pivot_timeframe)) + "\t" +
               PivotV9TimeToken(attempt.active_bar_open) + "\t" +
               PivotLevelLabel(attempt.level_id) + "\t" +
               PivotV9DirectionToken(attempt.direction) + "\t" +
               PivotV9TimestampColumns(attempt.trigger_time) + "\t" +
               (micro_shift_zero_available
                ? PivotV9DoubleToken(snapshot.micro_band_base_0, false)
                : PIVOT_V9_NULL) + "\t" +
               (micro_shift_zero_available
                ? PivotV9DoubleToken(snapshot.micro_band_upper_0, false)
                : PIVOT_V9_NULL) + "\t" +
               (micro_shift_zero_available
                ? PivotV9DoubleToken(snapshot.micro_band_lower_0, false)
                : PIVOT_V9_NULL) + "\t" +
               (micro_shift_zero_available
                ? PivotV9DoubleToken(snapshot.micro_band_width_0, false)
                : PIVOT_V9_NULL) + "\t" +
               (micro_shift_zero_available
                ? PivotV9DoubleToken(snapshot.micro_band_width_percent_0,
                                     false)
                : PIVOT_V9_NULL) + "\t" +
               micro_tokens + "\t" +
               macro_tokens + "\t" +
               PivotV9BoolToken(snapshot.micro_complete) + "\t" +
               PivotV9BoolToken(snapshot.macro_complete) + "\t" +
               PivotV9BoolToken(snapshot.complete) + "\t" +
               PivotV9Cell(snapshot.invalid_reason);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_FEATURES_FILE),
                      PIVOT_V9_FEATURES_HEADER,
                      row,
                      g_pivot_v9_feature_buffer))
    return false;
  g_pivot_v9_feature_rows++;
  if(!snapshot.complete)
    g_pivot_v9_feature_incomplete_rows++;
  return true;
}

bool PivotV9RecordExecutionCheck(const PivotV9ExecutionPayload &payload)
{
  if(!PivotV9Ready())
    return false;
  if(payload.signal_id == "" || payload.window_id == "")
    return PivotV9RejectReference("RECORD_EXECUTION_CHECK");
  BrokerExecutionCheck check(payload.check);
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(payload.signal_id) + "\t" +
               PivotV9Cell(payload.window_id) + "\t" +
               IntegerToString(check.sequence) + "\t" +
               PivotV9Cell(check.phase) + "\t" +
               PivotV9TimestampColumns(check.broker_time, check.symbol) + "\t" +
               PivotV9Cell(check.symbol) + "\t" +
               PivotV9DirectionToken(check.direction) + "\t" +
               IntegerToString((int)check.account_margin_mode) + "\t" +
               PivotV9BoolToken(check.account_margin_mode_supported) + "\t" +
               IntegerToString((int)check.symbol_trade_mode) + "\t" +
               PivotV9BoolToken(check.symbol_trade_mode_allowed) + "\t" +
               PivotV9BoolToken(check.market_session_open) + "\t" +
               PivotV9BoolToken(check.account_trade_allowed) + "\t" +
               PivotV9BoolToken(check.account_expert_trade_allowed) + "\t" +
               PivotV9BoolToken(check.terminal_trade_allowed) + "\t" +
               PivotV9BoolToken(check.mql_trade_allowed) + "\t" +
               PivotV9DoubleToken(check.bid, false) + "\t" +
               PivotV9DoubleToken(check.ask, false) + "\t" +
               PivotV9DoubleToken(check.spread_points) + "\t" +
               PivotV9DoubleToken(check.point_size, false) + "\t" +
               PivotV9DoubleToken(check.stops_distance_points) + "\t" +
               PivotV9DoubleToken(check.freeze_distance_points) + "\t" +
               PivotV9DoubleToken(check.planned_entry_price, false) + "\t" +
               PivotV9DoubleToken(check.stop_loss_price, false) + "\t" +
               PivotV9DoubleToken(check.take_profit_price, false) + "\t" +
               PivotV9DoubleToken(check.risk_distance, false) + "\t" +
               PivotV9DoubleToken(check.requested_volume, false) + "\t" +
               PivotV9DoubleToken(check.normalized_volume, false) + "\t" +
               PivotV9DoubleToken(check.volume_min, false) + "\t" +
               PivotV9DoubleToken(check.volume_max, false) + "\t" +
               PivotV9DoubleToken(check.volume_step, false) + "\t" +
               PivotV9BoolToken(check.volume_valid) + "\t" +
               PivotV9DoubleToken(check.account_balance) + "\t" +
               PivotV9DoubleToken(check.free_margin) + "\t" +
               PivotV9DoubleToken(check.required_margin) + "\t" +
               PivotV9BoolToken(check.margin_valid) + "\t" +
               PivotV9BoolToken(check.geometry_valid) + "\t" +
               PivotV9BoolToken(check.stop_distance_valid) + "\t" +
               PivotV9BoolToken(check.freeze_distance_valid) + "\t" +
               PivotV9BoolToken(check.order_check_performed) + "\t" +
               PivotV9BoolToken(check.order_check_allowed) + "\t" +
               StringFormat("%I64u", check.order_check_retcode) + "\t" +
               PivotV9Cell(check.order_check_comment) + "\t" +
               PivotV9BoolToken(check.allowed) + "\t" +
               PivotV9Cell(check.block_source) + "\t" +
               PivotV9Cell(check.block_reason) + "\t" +
               StringFormat("%I64u", check.send_retcode) + "\t" +
               PivotV9Cell(check.send_comment) + "\t" +
               PivotV9UlongToken(check.order_ticket) + "\t" +
               PivotV9UlongToken(check.deal_ticket) + "\t" +
               PivotV9UlongToken(payload.position_ticket) + "\t" +
               PivotV9UlongToken(payload.position_identifier) + "\t" +
               PivotV9BoolToken(payload.broker_entry_confirmed) + "\t" +
               PivotV9BoolToken(payload.broker_close_confirmed) + "\t" +
               PivotV9DoubleToken(payload.broker_entry_price, false) + "\t" +
               PivotV9DoubleToken(payload.broker_volume, false) + "\t" +
               PivotV9DoubleToken(payload.broker_stop_loss, false) + "\t" +
               PivotV9DoubleToken(payload.broker_take_profit, false) + "\t" +
               PivotV9DoubleToken(payload.close_price, false) + "\t" +
               PivotV9DoubleToken(payload.closed_volume) + "\t" +
               PivotV9DoubleToken(payload.realized_profit) + "\t" +
               PivotV9Cell(payload.terminal_reason);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_CHECKS_FILE),
                      PIVOT_V9_CHECKS_HEADER,
                      row,
                      g_pivot_v9_check_buffer))
    return false;
  g_pivot_v9_check_rows++;
  return true;
}

bool PivotV9RecordTrailingEvent(const PivotV9TrailingPayload &payload)
{
  if(!PivotV9Ready())
    return false;
  if(payload.signal_id == "" ||
     payload.window_id == "" ||
     payload.position_ticket == 0 ||
     payload.position_identifier == 0)
    return PivotV9RejectReference("RECORD_TRAILING_EVENT");
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(payload.signal_id) + "\t" +
               PivotV9Cell(payload.window_id) + "\t" +
               IntegerToString(payload.event_sequence) + "\t" +
               PivotV9TimestampColumns(payload.event_time) + "\t" +
               PivotV9Cell(_Symbol) + "\t" +
               PivotV9DirectionToken(payload.direction) + "\t" +
               PivotV9UlongToken(payload.position_ticket) + "\t" +
               PivotV9UlongToken(payload.position_identifier) + "\t" +
               PivotLevelLabel(payload.milestone_level) + "\t" +
               PivotV9DoubleToken(payload.milestone_price, false) + "\t" +
               PivotV9DoubleToken(payload.previous_confirmed_stop, false) + "\t" +
               PivotV9DoubleToken(payload.desired_stop, false) + "\t" +
               PivotV9DoubleToken(payload.requested_stop, false) + "\t" +
               PivotV9DoubleToken(payload.confirmed_stop, false) + "\t" +
               PivotV9DoubleToken(payload.take_profit, false) + "\t" +
               PivotV9BoolToken(payload.request_performed) + "\t" +
               PivotV9BoolToken(payload.request_succeeded) + "\t" +
               StringFormat("%I64u", payload.retcode) + "\t" +
               PivotV9Cell(payload.comment) + "\t" +
               PivotV9BoolToken(payload.retry_pending) + "\t" +
               PivotV9Cell(payload.event_status);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_TRAILING_FILE),
                      PIVOT_V9_TRAILING_HEADER,
                      row,
                      g_pivot_v9_trailing_buffer))
    return false;
  g_pivot_v9_trailing_rows++;
  return true;
}

bool PivotV9RecordOutcome(const PivotV9OutcomePayload &payload)
{
  if(!PivotV9Ready())
    return false;
  if(payload.signal_id == "" ||
     payload.window_id == "" ||
     payload.entry_time <= 0 ||
     payload.close_time < payload.entry_time ||
     payload.order_ticket == 0 ||
     payload.entry_deal_ticket == 0 ||
     payload.close_deal_ticket == 0 ||
     payload.position_ticket == 0 ||
     payload.position_identifier == 0 ||
     payload.broker_entry_price <= 0.0 ||
     payload.broker_volume <= 0.0 ||
     payload.close_price <= 0.0 ||
     payload.closed_volume <= 0.0 ||
     !payload.broker_entry_confirmed ||
     !payload.broker_close_confirmed)
    return PivotV9RejectReference("RECORD_OUTCOME");
  int duration_seconds = payload.close_time >= payload.entry_time
                         ? (int)(payload.close_time - payload.entry_time)
                         : -1;
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9Cell(payload.signal_id) + "\t" +
               PivotV9Cell(payload.window_id) + "\t" +
               PivotV9Cell(_Symbol) + "\t" +
               PivotV9Cell(EnumToString(payload.pivot_timeframe)) + "\t" +
               PivotV9TimeToken(payload.active_bar_open) + "\t" +
               PivotLevelLabel(payload.level_id) + "\t" +
               PivotV9DirectionToken(payload.direction) + "\t" +
               PivotV9TimestampColumns(payload.entry_time) + "\t" +
               PivotV9TimestampColumns(payload.close_time) + "\t" +
               PivotV9UlongToken(payload.order_ticket) + "\t" +
               PivotV9UlongToken(payload.entry_deal_ticket) + "\t" +
               PivotV9UlongToken(payload.close_deal_ticket) + "\t" +
               PivotV9UlongToken(payload.position_ticket) + "\t" +
               PivotV9UlongToken(payload.position_identifier) + "\t" +
               PivotV9DoubleToken(payload.broker_entry_price, false) + "\t" +
               PivotV9DoubleToken(payload.broker_volume, false) + "\t" +
               PivotV9DoubleToken(payload.initial_stop_loss, false) + "\t" +
               PivotV9DoubleToken(payload.terminal_take_profit, false) + "\t" +
               PivotV9DoubleToken(payload.final_broker_stop_loss, false) + "\t" +
               PivotV9DoubleToken(payload.final_broker_take_profit, false) + "\t" +
               PivotV9DoubleToken(payload.close_price, false) + "\t" +
               PivotV9DoubleToken(payload.closed_volume, false) + "\t" +
               PivotV9DoubleToken(payload.realized_profit) + "\t" +
               PivotV9Cell(payload.highest_milestone_level) + "\t" +
               PivotV9Cell(payload.terminal_reason) + "\t" +
               IntegerToString(duration_seconds) + "\t" +
               PivotV9BoolToken(payload.broker_entry_confirmed) + "\t" +
               PivotV9BoolToken(payload.broker_close_confirmed);
  if(!PivotV9QueueRow(PivotV9Path(PIVOT_V9_OUTCOMES_FILE),
                      PIVOT_V9_OUTCOMES_HEADER,
                      row,
                      g_pivot_v9_outcome_buffer))
    return false;
  g_pivot_v9_outcome_rows++;
  return true;
}

void PivotV9RegisterDuplicateIdentity()
{
  g_pivot_v9_duplicate_identity_count++;
}

bool PivotV9WriteSummary(const string completion_status)
{
  datetime finished_at = TimeCurrent();
  bool export_invalid = g_pivot_v9_failed ||
                        g_pivot_v9_feature_incomplete_rows > 0 ||
                        g_pivot_v9_duplicate_identity_count > 0 ||
                        g_pivot_v9_referential_integrity_error_count > 0 ||
                        g_pivot_v9_row_integrity_error_count > 0;
  string export_status = export_invalid ? "INVALID" : "OK";
  string row = IntegerToString(PIVOT_V9_SCHEMA_VERSION) + "\t" +
               PivotV9Cell(g_pivot_v9_run_id) + "\t" +
               PivotV9Cell(g_pivot_v9_config_id) + "\t" +
               PivotV9TimestampColumns(g_pivot_v9_started_at) + "\t" +
               PivotV9TimestampColumns(finished_at) + "\t" +
               IntegerToString(g_pivot_v9_window_rows) + "\t" +
               IntegerToString(g_pivot_v9_level_rows) + "\t" +
               IntegerToString(g_pivot_v9_attempt_rows) + "\t" +
               IntegerToString(g_pivot_v9_feature_rows) + "\t" +
               IntegerToString(g_pivot_v9_check_rows) + "\t" +
               IntegerToString(g_pivot_v9_trailing_rows) + "\t" +
               IntegerToString(g_pivot_v9_outcome_rows) + "\t" +
               IntegerToString(g_pivot_v9_feature_incomplete_rows) + "\t" +
               IntegerToString(g_pivot_v9_duplicate_identity_count) + "\t" +
               IntegerToString(g_pivot_v9_referential_integrity_error_count) + "\t" +
               IntegerToString(g_pivot_v9_row_integrity_error_count) + "\t" +
               export_status + "\t" +
               PivotV9Cell(completion_status);
  if(!PivotV9RowMatchesHeader(PIVOT_V9_SUMMARY_HEADER, row))
    return false;
  string filename = PivotV9Path(PIVOT_V9_SUMMARY_FILE);
  if(FileIsExist(filename, FILE_COMMON))
  {
    PivotV9MarkFailed("SUMMARY_ALREADY_EXISTS", filename);
    return false;
  }
  if(!PivotV9WriteLine(filename, PIVOT_V9_SUMMARY_HEADER, false))
    return false;
  return PivotV9WriteLine(filename, row, true);
}

void PivotV9StatsReset()
{
  g_pivot_v9_run_id    = "";
  g_pivot_v9_config_id = "";
  g_pivot_v9_folder    = "";
  g_pivot_v9_started_at = 0;
  g_pivot_v9_initialized = false;
  g_pivot_v9_failed      = false;
  g_pivot_v9_window_rows  = 0;
  g_pivot_v9_level_rows   = 0;
  g_pivot_v9_attempt_rows = 0;
  g_pivot_v9_feature_rows = 0;
  g_pivot_v9_check_rows   = 0;
  g_pivot_v9_trailing_rows = 0;
  g_pivot_v9_outcome_rows = 0;
  g_pivot_v9_feature_incomplete_rows = 0;
  g_pivot_v9_duplicate_identity_count = 0;
  g_pivot_v9_referential_integrity_error_count = 0;
  g_pivot_v9_row_integrity_error_count = 0;
  g_pivot_v9_error_logged = false;
  ArrayResize(g_pivot_v9_window_buffer, 0);
  ArrayResize(g_pivot_v9_level_buffer, 0);
  ArrayResize(g_pivot_v9_attempt_buffer, 0);
  ArrayResize(g_pivot_v9_feature_buffer, 0);
  ArrayResize(g_pivot_v9_check_buffer, 0);
  ArrayResize(g_pivot_v9_trailing_buffer, 0);
  ArrayResize(g_pivot_v9_outcome_buffer, 0);
}

bool PivotV9StatsInit()
{
  PivotV9StatsReset();
  if(!PivotV9Enabled())
    return true;

  g_pivot_v9_started_at = TimeCurrent();
  g_pivot_v9_run_id = PivotV9BuildRunId();
  g_pivot_v9_config_id = "cfg_" + PivotV9HashToken(PivotV9BuildConfigPayload());
  g_pivot_v9_folder = PIVOT_V9_STORAGE_ROOT + "\\" +
                      PIVOT_V9_RUNS_FOLDER + "\\" +
                      g_pivot_v9_run_id;
  if(!PivotV9EnsureFolder())
  {
    PivotV9MarkFailed("ENSURE_RUN_FOLDER", g_pivot_v9_folder, GetLastError());
    return false;
  }

  if(PivotV9RunFilesExist())
  {
    PivotV9MarkFailed("RUN_ALREADY_EXISTS", g_pivot_v9_folder);
    return false;
  }

  g_pivot_v9_initialized = true;
  if(!PivotV9WriteManifest())
  {
    PivotV9MarkFailed("WRITE_MANIFEST", PivotV9Path(PIVOT_V9_MANIFEST_FILE), GetLastError());
    return false;
  }
  if(!PivotV9CreateDataFiles())
  {
    PivotV9MarkFailed("CREATE_DATA_FILES", g_pivot_v9_folder, GetLastError());
    return false;
  }
  return true;
}

void PivotV9StatsDeinit(const string completion_status = "CENSORED")
{
  if(!PivotV9Enabled() || !g_pivot_v9_initialized)
    return;
  PivotV9FlushAll();
  PivotV9WriteSummary(completion_status);
  g_pivot_v9_initialized = false;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
