//+------------------------------------------------------------------+
//|              trading_signals/pivot_fractal_statistics_export   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_

const int    PIVOT_V10_SCHEMA_VERSION = 10;
const string PIVOT_V10_ENGINE_LABEL = "PIVOT_FRACTAL_V2";
const string PIVOT_V10_FEATURE_SET_ID =
  "schema_v10_macro_micro_pivot_bands";
const string PIVOT_V10_STORAGE_ROOT = "PivotFractalV10";
const string PIVOT_V10_RUNS_FOLDER = "runs";
const string PIVOT_V10_NULL = "\\N";
const int    PIVOT_V10_FLUSH_ROWS = 256;

const string PIVOT_V10_MANIFEST_FILE = "run_manifest.tsv";
const string PIVOT_V10_WINDOWS_FILE = "pivot_windows.tsv";
const string PIVOT_V10_ATTEMPTS_FILE = "signal_attempts.tsv";
const string PIVOT_V10_CHECKS_FILE = "execution_checks.tsv";
const string PIVOT_V10_OUTCOMES_FILE = "signal_outcomes.tsv";
const string PIVOT_V10_SUMMARY_FILE = "run_summary.tsv";

const string PIVOT_V10_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string PIVOT_V10_WINDOWS_HEADER =
  "schema_version\trun_id\tconfig_id\twindow_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tactive_bar_open_analysis_time\tactive_bar_open_offset_minutes\tsource_bar_open_broker_time\tsource_bar_open_analysis_time\tsource_bar_open_offset_minutes\tsource_close_boundary_broker_time\tsource_close_boundary_analysis_time\tsource_close_boundary_offset_minutes\tsource_open\tsource_high\tsource_low\tsource_close\tsource_range\traw_s3_price\traw_s2_price\traw_s1_price\traw_pp_price\traw_r1_price\traw_r2_price\traw_r3_price\ttrade_s3_price\ttrade_s2_price\ttrade_s1_price\ttrade_pp_price\ttrade_r1_price\ttrade_r2_price\ttrade_r3_price\tfirst_observed_broker_time\tfirst_observed_analysis_time\tfirst_observed_offset_minutes\tfirst_observed_bid\tpp_initial_relation\tpp_role\tpp_arm_broker_time\tpp_arm_analysis_time\tpp_arm_offset_minutes\tpp_arm_bid\tmacro_band_base_1\tmacro_band_upper_1\tmacro_band_lower_1\tmacro_band_width_1\tmacro_band_width_percent_1\tmacro_band_complete\tmacro_band_invalid_reason\twindow_state\tinvalid_reason\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status";
const string PIVOT_V10_ATTEMPTS_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\ttrigger_bid\ttrigger_ask\tspread_points\tpoint_size\tpivot_raw_price\tpivot_trade_price\tstructural_sl_price\tobserved_entry_price\tobserved_stop_loss\tobserved_take_profit\tobserved_risk_distance_points\tobserved_reward_distance_points\trequest_broker_time\trequest_analysis_time\trequest_offset_minutes\trequest_bid\trequest_ask\trequest_entry_price\trequest_stop_loss\trequest_take_profit\trequest_risk_distance_points\trequest_reward_distance_points\trequest_price_reward_risk_ratio\tlot_mode\tlot_strategy_size\treference_balance\taccount_currency\trisk_budget_amount\trequested_volume\tnormalized_volume\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\tmicro_band_base_0\tmicro_band_upper_0\tmicro_band_lower_0\tmicro_band_width_0\tmicro_band_width_percent_0\tmicro_b_percent_0\tmicro_b_percent_1\tmicro_b_percent_2\tmicro_b_percent_3\tmicro_b_percent_4\tmicro_b_percent_5\tmacro_pivot_b_percent_0\tmacro_pivot_b_percent_1\tmacro_pivot_b_percent_2\tmacro_pivot_b_percent_3\tmacro_pivot_b_percent_4\tmacro_pivot_b_percent_5\tmicro_features_complete\tmacro_features_complete\tfeature_snapshot_complete\tfeature_invalid_reason\tidentity_consumed\troute_status\tattempt_status\tblock_source\tblock_reason\tsend_attempted\tsend_succeeded";
const string PIVOT_V10_CHECKS_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tcheck_sequence\tcheck_phase\tbroker_time\tanalysis_time\toffset_minutes\tsymbol\tdirection\taccount_margin_mode\taccount_margin_mode_supported\tsymbol_trade_mode\tsymbol_trade_mode_allowed\tmarket_session_open\taccount_trade_allowed\taccount_expert_trade_allowed\tterminal_trade_allowed\tmql_trade_allowed\tbid\task\tspread_points\tpoint_size\tstops_distance_points\tfreeze_distance_points\tentry_price\tstop_loss_price\ttake_profit_price\trisk_distance_points\treward_distance_points\trisk_budget_amount\trequested_volume\tnormalized_volume\tvolume_min\tvolume_max\tvolume_step\tvolume_valid\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\taccount_balance\tfree_margin\trequired_margin\tmargin_valid\tgeometry_valid\tstop_distance_valid\tfreeze_distance_valid\torder_check_performed\torder_check_allowed\torder_check_retcode\torder_check_comment\tallowed\tblock_source\tblock_reason\tsend_performed\tsend_succeeded\tsend_retcode\tsend_comment\torder_ticket\tdeal_ticket\tposition_ticket\tposition_identifier\tbroker_entry_confirmed\tbroker_close_confirmed\tbroker_entry_price\tbroker_volume\tbroker_stop_loss\tbroker_take_profit\tclose_price\tclosed_volume\tterminal_reason";
const string PIVOT_V10_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\twindow_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\tentry_broker_time\tentry_analysis_time\tentry_offset_minutes\tclose_broker_time\tclose_analysis_time\tclose_offset_minutes\torder_ticket\tentry_deal_ticket\tlast_close_deal_ticket\tclose_deal_count\tposition_ticket\tposition_identifier\tsubmitted_request_price\tbroker_entry_price\tbroker_volume\timmutable_stop_loss\timmutable_take_profit\tclose_price\tclosed_volume\trequest_risk_distance_points\trequest_reward_distance_points\trequest_price_reward_risk_ratio\trisk_budget_amount\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\tentry_slippage_points\texit_slippage_points\tgross_profit\tcommission\tswap\tfee\tnet_profit\tgross_budget_r\tnet_budget_r\tgross_execution_r\tnet_execution_r\tterminal_reason\tclose_reason_consistent\tbinary_eligible\tbinary_target\texclusion_reason\tduration_seconds\tbroker_entry_confirmed\tbroker_close_confirmed";
const string PIVOT_V10_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_broker_time\tstarted_analysis_time\tstarted_offset_minutes\tfinished_broker_time\tfinished_analysis_time\tfinished_offset_minutes\tpivot_window_rows\tsignal_attempt_rows\texecution_check_rows\tsignal_outcome_rows\tfeature_complete_rows\tfeature_incomplete_rows\tsend_attempt_rows\tsend_succeeded_rows\tbroker_filled_rows\tbroker_closed_rows\tbinary_eligible_rows\tbinary_tp_rows\tbinary_sl_rows\texcluded_outcome_rows\texcluded_feature_incomplete_rows\texcluded_mixed_rows\texcluded_manual_rows\texcluded_stop_out_rows\texcluded_expert_rows\texcluded_other_rows\tcensored_attempt_rows\tduplicate_identity_count\treferential_integrity_error_count\trow_integrity_error_count\texport_status\tcompletion_status";

string g_pivot_v10_run_id = "";
string g_pivot_v10_config_id = "";
string g_pivot_v10_folder = "";
datetime g_pivot_v10_started_at = 0;
bool g_pivot_v10_initialized = false;
bool g_pivot_v10_failed = false;
bool g_pivot_v10_error_logged = false;
bool g_pivot_v10_summary_written = false;
int g_pivot_v10_window_rows = 0;
int g_pivot_v10_attempt_rows = 0;
int g_pivot_v10_check_rows = 0;
int g_pivot_v10_outcome_rows = 0;
int g_pivot_v10_feature_complete_rows = 0;
int g_pivot_v10_feature_incomplete_rows = 0;
int g_pivot_v10_send_attempt_rows = 0;
int g_pivot_v10_send_succeeded_rows = 0;
int g_pivot_v10_broker_filled_rows = 0;
int g_pivot_v10_binary_eligible_rows = 0;
int g_pivot_v10_binary_tp_rows = 0;
int g_pivot_v10_binary_sl_rows = 0;
int g_pivot_v10_excluded_feature_incomplete_rows = 0;
int g_pivot_v10_excluded_mixed_rows = 0;
int g_pivot_v10_excluded_manual_rows = 0;
int g_pivot_v10_excluded_stop_out_rows = 0;
int g_pivot_v10_excluded_expert_rows = 0;
int g_pivot_v10_excluded_other_rows = 0;
int g_pivot_v10_censored_attempt_rows = 0;
int g_pivot_v10_duplicate_identity_count = 0;
int g_pivot_v10_referential_integrity_error_count = 0;
int g_pivot_v10_row_integrity_error_count = 0;
string g_pivot_v10_window_buffer[];
string g_pivot_v10_attempt_buffer[];
string g_pivot_v10_check_buffer[];
string g_pivot_v10_outcome_buffer[];

bool PivotV10Enabled()
{
  return Enable_Signal_Feature_Export;
}

bool PivotV10Ready()
{
  return PivotV10Enabled() && g_pivot_v10_initialized &&
         !g_pivot_v10_failed;
}

void PivotV10MarkFailed(const string operation,
                        const string filename = "",
                        const int error_code = 0)
{
  g_pivot_v10_failed = true;
  if(g_pivot_v10_error_logged || (!Enable_Logs && !Enable_File_Logs))
    return;
  PrintFormat("PIVOT_V10_EXPORT_FAILED | operation=%s | file=%s | error=%d",
              operation,
              filename,
              error_code);
  g_pivot_v10_error_logged = true;
}

bool PivotV10RejectReference(const string operation)
{
  g_pivot_v10_referential_integrity_error_count++;
  PivotV10MarkFailed(operation);
  return false;
}

string PivotV10BoolToken(const bool value)
{
  return value ? "1" : "0";
}

string PivotV10Cell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  return value == "" ? PIVOT_V10_NULL : value;
}

string PivotV10TimeToken(const datetime value)
{
  return value > 0
         ? TimeToString(value, TIME_DATE | TIME_SECONDS)
         : PIVOT_V10_NULL;
}

string PivotV10DoubleToken(const double value,
                           const bool positive_required = false)
{
  if(!MathIsValidNumber(value) || (positive_required && value <= 0.0))
    return PIVOT_V10_NULL;
  return DoubleToString(value, 10);
}

string PivotV10UlongToken(const ulong value)
{
  return value > 0 ? StringFormat("%I64u", value) : PIVOT_V10_NULL;
}

string PivotV10DirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BUY";
  if(direction == BEARISH)
    return "SELL";
  return "NONE";
}

string PivotV10WindowStateToken(const PivotWindowStates state)
{
  if(state == PIVOT_WINDOW_VALID)
    return "VALID";
  if(state == PIVOT_WINDOW_PENDING)
    return "PENDING";
  if(state == PIVOT_WINDOW_INVALID)
    return "INVALID";
  return "EMPTY";
}

string PivotV10PriceSideToken(const PivotPriceSideStates side)
{
  if(side == PIVOT_PRICE_SIDE_BELOW)
    return "BELOW";
  if(side == PIVOT_PRICE_SIDE_EQUAL)
    return "EQUAL";
  if(side == PIVOT_PRICE_SIDE_ABOVE)
    return "ABOVE";
  return "UNAVAILABLE";
}

string PivotV10PpRoleToken(const PivotPpArmStates state)
{
  if(state == PIVOT_PP_BUY_ARMED)
    return "BUY";
  if(state == PIVOT_PP_SELL_ARMED)
    return "SELL";
  return "UNARMED";
}

string PivotV10RouteStatusToken(const PivotRouteStatuses status)
{
  return status == PIVOT_ROUTE_ALLOWED ? "VALID" : "INVALID";
}

void PivotV10AppendColumn(string &row,
                          const string value)
{
  if(row != "")
    row += "\t";
  row += value;
}

void PivotV10AppendTimestamp(string &row,
                             const datetime broker_time,
                             const string symbol = "")
{
  string resolved_symbol = symbol == "" ? _Symbol : symbol;
  int offset_minutes = 0;
  datetime analysis_time = MarketDataNormalizeAnalysisTime(broker_time,
                                                            Broker_Session,
                                                            resolved_symbol,
                                                            offset_minutes);
  bool valid = broker_time > 0 && analysis_time > 0;
  PivotV10AppendColumn(row, PivotV10TimeToken(broker_time));
  PivotV10AppendColumn(row, PivotV10TimeToken(analysis_time));
  PivotV10AppendColumn(row,
                       valid
                       ? IntegerToString(offset_minutes)
                       : PIVOT_V10_NULL);
}

string PivotV10SanitizePart(const string raw_value)
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

ulong PivotV10Hash(const string value)
{
  ulong hash = 1469598103934665603;
  for(int i = 0; i < StringLen(value); i++)
  {
    hash ^= (ulong)StringGetCharacter(value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string PivotV10HashToken(const string value)
{
  return StringFormat("%I64u", PivotV10Hash(value));
}

string PivotV10WindowId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open)
{
  string identity = symbol + "|" + IntegerToString((int)timeframe) + "|" +
                    StringFormat("%I64d", (long)active_bar_open);
  return "win_" + PivotV10HashToken(identity);
}

string PivotV10SignalId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open,
                        const PivotLevelIds level)
{
  string identity = symbol + "|" + IntegerToString((int)timeframe) + "|" +
                    StringFormat("%I64d", (long)active_bar_open) + "|" +
                    PivotLevelLabel(level);
  return "sig_" + PivotV10HashToken(identity);
}

string PivotV10BuildConfigPayload()
{
  return StringFormat("schema=%d|engine=%s|symbol=%s|chart_tf=%d|macro_tf=%d|micro_tf=%d|bands=%d,%.4f,PRICE_WEIGHTED|trigger=live_bid_virtual_limit|pp=first_causal_bid_side_return|route=structural_sl_fresh_quote_price_distance_1r_no_modifications|broker_session=%d|lot_type=%d|lot_size=%.8f|reference_balance=%.8f|currency=%s",
                      PIVOT_V10_SCHEMA_VERSION,
                      PIVOT_V10_ENGINE_LABEL,
                      _Symbol,
                      (int)_Period,
                      (int)Macro_Timeframe,
                      (int)Micro_Timeframe,
                      PIVOT_CONTEXT_BANDS_PERIOD,
                      PIVOT_CONTEXT_B_PERCENT_DEVIATION,
                      (int)Broker_Session,
                      (int)Lot_Type,
                      Lot_Strategy_Size,
                      PIVOT_EXECUTION_REFERENCE_BALANCE,
                      AccountInfoString(ACCOUNT_CURRENCY));
}

string PivotV10BuildRunId()
{
  if(Signal_Feature_Run_Id != "")
    return PivotV10SanitizePart(Signal_Feature_Run_Id);
  string time_token = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
  return PivotV10SanitizePart(time_token + "_" + _Symbol + "_pivot_v10");
}

string PivotV10Path(const string filename)
{
  return g_pivot_v10_folder + "\\" + filename;
}

bool PivotV10EnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_pivot_v10_folder, delimiter, parts);
  if(total <= 0)
    return false;

  string current = "";
  for(int i = 0; i < total; i++)
  {
    if(parts[i] == "")
      continue;
    current = current == "" ? parts[i] : current + "\\" + parts[i];
    ResetLastError();
    bool created = FolderCreate(current, FILE_COMMON);
    int error = GetLastError();
    if(i == total - 1 && !created && error == 5019)
    {
      PivotV10MarkFailed("RUN_FOLDER_ALREADY_EXISTS", current, error);
      return false;
    }
    if(error != 0 && error != 5019)
    {
      PivotV10MarkFailed("CREATE_FOLDER", current, error);
      return false;
    }
  }
  return true;
}

int PivotV10ColumnCount(const string row)
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

bool PivotV10RowMatchesHeader(const string header,
                              const string row)
{
  if(PivotV10ColumnCount(header) == PivotV10ColumnCount(row))
    return true;
  g_pivot_v10_row_integrity_error_count++;
  PivotV10MarkFailed("ROW_COLUMN_COUNT");
  return false;
}

bool PivotV10FileHeaderMatches(const string filename,
                               const string expected_header)
{
  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    PivotV10MarkFailed("OPEN_HEADER", filename, GetLastError());
    return false;
  }
  string actual_header = FileReadString(handle);
  FileClose(handle);
  if(actual_header == expected_header)
    return true;
  PivotV10MarkFailed("HEADER_MISMATCH", filename);
  return false;
}

bool PivotV10WriteLine(const string filename,
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
    PivotV10MarkFailed("OPEN_WRITE", filename, GetLastError());
    return false;
  }
  if(append && !FileSeek(handle, 0, SEEK_END))
  {
    PivotV10MarkFailed("SEEK_END", filename, GetLastError());
    FileClose(handle);
    return false;
  }
  bool written = FileWrite(handle, line) > 0;
  FileClose(handle);
  if(!written)
    PivotV10MarkFailed("WRITE_LINE", filename, GetLastError());
  return written;
}

bool PivotV10AppendRows(const string filename,
                        const string header,
                        string &buffer[])
{
  int total = ArraySize(buffer);
  if(total <= 0)
    return true;
  if(!FileIsExist(filename, FILE_COMMON) ||
     !PivotV10FileHeaderMatches(filename, header))
    return false;

  int handle = FileOpen(filename,
                        FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI |
                        FILE_COMMON);
  if(handle == INVALID_HANDLE || !FileSeek(handle, 0, SEEK_END))
  {
    PivotV10MarkFailed("OPEN_APPEND", filename, GetLastError());
    if(handle != INVALID_HANDLE)
      FileClose(handle);
    return false;
  }

  bool success = true;
  for(int i = 0; i < total; i++)
  {
    if(!PivotV10RowMatchesHeader(header, buffer[i]) ||
       FileWrite(handle, buffer[i]) == 0)
    {
      success = false;
      break;
    }
  }
  FileClose(handle);
  if(!success)
    PivotV10MarkFailed("WRITE_BATCH", filename, GetLastError());
  return success;
}

bool PivotV10FlushBuffer(const string filename,
                         const string header,
                         string &buffer[])
{
  if(ArraySize(buffer) <= 0)
    return true;
  if(!PivotV10AppendRows(filename, header, buffer))
    return false;
  ArrayResize(buffer, 0);
  return true;
}

bool PivotV10QueueRow(const string filename,
                      const string header,
                      const string row,
                      string &buffer[])
{
  if(!PivotV10Ready() || !PivotV10RowMatchesHeader(header, row))
    return false;
  int total = ArraySize(buffer);
  if(ArrayResize(buffer, total + 1, PIVOT_V10_FLUSH_ROWS) != total + 1)
  {
    PivotV10MarkFailed("BUFFER_RESIZE", filename);
    return false;
  }
  buffer[total] = row;
  if(ArraySize(buffer) >= PIVOT_V10_FLUSH_ROWS)
    return PivotV10FlushBuffer(filename, header, buffer);
  return true;
}

bool PivotV10FlushAll()
{
  bool windows_ok = PivotV10FlushBuffer(PivotV10Path(PIVOT_V10_WINDOWS_FILE),
                                        PIVOT_V10_WINDOWS_HEADER,
                                        g_pivot_v10_window_buffer);
  bool attempts_ok = PivotV10FlushBuffer(PivotV10Path(PIVOT_V10_ATTEMPTS_FILE),
                                         PIVOT_V10_ATTEMPTS_HEADER,
                                         g_pivot_v10_attempt_buffer);
  bool checks_ok = PivotV10FlushBuffer(PivotV10Path(PIVOT_V10_CHECKS_FILE),
                                       PIVOT_V10_CHECKS_HEADER,
                                       g_pivot_v10_check_buffer);
  bool outcomes_ok = PivotV10FlushBuffer(PivotV10Path(PIVOT_V10_OUTCOMES_FILE),
                                         PIVOT_V10_OUTCOMES_HEADER,
                                         g_pivot_v10_outcome_buffer);
  return windows_ok && attempts_ok && checks_ok && outcomes_ok;
}

string PivotV10ManifestRow(const string key,
                           const string value)
{
  return IntegerToString(PIVOT_V10_SCHEMA_VERSION) + "\t" +
         PivotV10Cell(key) + "\t" + PivotV10Cell(value);
}

bool PivotV10WriteManifest()
{
  string filename = PivotV10Path(PIVOT_V10_MANIFEST_FILE);
  if(FileIsExist(filename, FILE_COMMON) ||
     !PivotV10WriteLine(filename, PIVOT_V10_MANIFEST_HEADER, false))
    return false;

  string rows[];
  ArrayResize(rows, 32);
  rows[0] = PivotV10ManifestRow("run_id", g_pivot_v10_run_id);
  rows[1] = PivotV10ManifestRow("config_id", g_pivot_v10_config_id);
  rows[2] = PivotV10ManifestRow("started_broker_time",
                               PivotV10TimeToken(g_pivot_v10_started_at));
  rows[3] = PivotV10ManifestRow("symbol", _Symbol);
  rows[4] = PivotV10ManifestRow("chart_period", EnumToString(_Period));
  rows[5] = PivotV10ManifestRow("engine_id", "2");
  rows[6] = PivotV10ManifestRow("engine_label", PIVOT_V10_ENGINE_LABEL);
  rows[7] = PivotV10ManifestRow("macro_timeframe",
                               EnumToString(Macro_Timeframe));
  rows[8] = PivotV10ManifestRow("micro_timeframe",
                               EnumToString(Micro_Timeframe));
  rows[9] = PivotV10ManifestRow("pivot_formula",
                               "CLASSIC_PP_S1_S3_R1_R3");
  rows[10] = PivotV10ManifestRow("source_policy",
                                "macro_immediately_previous_completed_broker_candle_shift_1");
  rows[11] = PivotV10ManifestRow("identity_policy",
                                "symbol,macro_timeframe,active_bar_open,level_first_trigger_once");
  rows[12] = PivotV10ManifestRow("trigger_policy",
                                "live_bid_virtual_limit_support_buy_resistance_sell");
  rows[13] = PivotV10ManifestRow("pp_policy",
                                "first_causal_bid_side_then_return_touch");
  rows[14] = PivotV10ManifestRow("execution_price_policy",
                                "trigger_bid_buy_fresh_ask_sell_fresh_bid_market_deal");
  rows[15] = PivotV10ManifestRow("route_policy",
                                "structural_sl_fresh_quote_price_distance_1r_no_modifications");
  rows[16] = PivotV10ManifestRow("bands_period",
                                IntegerToString(PIVOT_CONTEXT_BANDS_PERIOD));
  rows[17] = PivotV10ManifestRow("bands_deviation",
                                DoubleToString(PIVOT_CONTEXT_B_PERCENT_DEVIATION,
                                               4));
  rows[18] = PivotV10ManifestRow("bands_shift", "0");
  rows[19] = PivotV10ManifestRow("bands_ma_method", "MODE_SMA");
  rows[20] = PivotV10ManifestRow("bands_applied_price", "PRICE_WEIGHTED");
  rows[21] = PivotV10ManifestRow("lot_mode", EnumToString(Lot_Type));
  rows[22] = PivotV10ManifestRow("lot_strategy_size",
                                DoubleToString(Lot_Strategy_Size, 8));
  rows[23] = PivotV10ManifestRow("reference_balance",
                                DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE,
                                               8));
  rows[24] = PivotV10ManifestRow("account_currency",
                                AccountInfoString(ACCOUNT_CURRENCY));
  rows[25] = PivotV10ManifestRow("volume_normalization_policy",
                                "normalize_down_block_below_minimum");
  rows[26] = PivotV10ManifestRow("outcome_policy",
                                "broker_costs_and_execution_slippage_decomposed");
  rows[27] = PivotV10ManifestRow("binary_cohort_policy",
                                "feature_complete_consistent_broker_tp_or_sl_only");
  rows[28] = PivotV10ManifestRow("time_policy",
                                "broker_time_causal_analysis_time_export_only");
  rows[29] = PivotV10ManifestRow("broker_session",
                                MarketDataTimePolicyToken(Broker_Session));
  rows[30] = PivotV10ManifestRow("feature_set_id",
                                PIVOT_V10_FEATURE_SET_ID);
  rows[31] = PivotV10ManifestRow("research_approval_state",
                                "OFFLINE_RESEARCH_ONLY");

  for(int i = 0; i < ArraySize(rows); i++)
  {
    if(!PivotV10RowMatchesHeader(PIVOT_V10_MANIFEST_HEADER, rows[i]) ||
       !PivotV10WriteLine(filename, rows[i], true))
      return false;
  }
  return true;
}

bool PivotV10CreateDataFiles()
{
  return PivotV10WriteLine(PivotV10Path(PIVOT_V10_WINDOWS_FILE),
                           PIVOT_V10_WINDOWS_HEADER,
                           false) &&
         PivotV10WriteLine(PivotV10Path(PIVOT_V10_ATTEMPTS_FILE),
                           PIVOT_V10_ATTEMPTS_HEADER,
                           false) &&
         PivotV10WriteLine(PivotV10Path(PIVOT_V10_CHECKS_FILE),
                           PIVOT_V10_CHECKS_HEADER,
                           false) &&
         PivotV10WriteLine(PivotV10Path(PIVOT_V10_OUTCOMES_FILE),
                           PIVOT_V10_OUTCOMES_HEADER,
                           false) &&
         PivotV10WriteLine(PivotV10Path(PIVOT_V10_SUMMARY_FILE),
                           PIVOT_V10_SUMMARY_HEADER,
                           false);
}

bool PivotV10RunFilesExist()
{
  return FileIsExist(PivotV10Path(PIVOT_V10_MANIFEST_FILE), FILE_COMMON) ||
         FileIsExist(PivotV10Path(PIVOT_V10_WINDOWS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV10Path(PIVOT_V10_ATTEMPTS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV10Path(PIVOT_V10_CHECKS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV10Path(PIVOT_V10_OUTCOMES_FILE), FILE_COMMON) ||
         FileIsExist(PivotV10Path(PIVOT_V10_SUMMARY_FILE), FILE_COMMON);
}

void PivotV10StatsReset()
{
  g_pivot_v10_run_id = "";
  g_pivot_v10_config_id = "";
  g_pivot_v10_folder = "";
  g_pivot_v10_started_at = 0;
  g_pivot_v10_initialized = false;
  g_pivot_v10_failed = false;
  g_pivot_v10_error_logged = false;
  g_pivot_v10_summary_written = false;
  g_pivot_v10_window_rows = 0;
  g_pivot_v10_attempt_rows = 0;
  g_pivot_v10_check_rows = 0;
  g_pivot_v10_outcome_rows = 0;
  g_pivot_v10_feature_complete_rows = 0;
  g_pivot_v10_feature_incomplete_rows = 0;
  g_pivot_v10_send_attempt_rows = 0;
  g_pivot_v10_send_succeeded_rows = 0;
  g_pivot_v10_broker_filled_rows = 0;
  g_pivot_v10_binary_eligible_rows = 0;
  g_pivot_v10_binary_tp_rows = 0;
  g_pivot_v10_binary_sl_rows = 0;
  g_pivot_v10_excluded_feature_incomplete_rows = 0;
  g_pivot_v10_excluded_mixed_rows = 0;
  g_pivot_v10_excluded_manual_rows = 0;
  g_pivot_v10_excluded_stop_out_rows = 0;
  g_pivot_v10_excluded_expert_rows = 0;
  g_pivot_v10_excluded_other_rows = 0;
  g_pivot_v10_censored_attempt_rows = 0;
  g_pivot_v10_duplicate_identity_count = 0;
  g_pivot_v10_referential_integrity_error_count = 0;
  g_pivot_v10_row_integrity_error_count = 0;
  ArrayResize(g_pivot_v10_window_buffer, 0);
  ArrayResize(g_pivot_v10_attempt_buffer, 0);
  ArrayResize(g_pivot_v10_check_buffer, 0);
  ArrayResize(g_pivot_v10_outcome_buffer, 0);
}

bool PivotV10StatsInit()
{
  PivotV10StatsReset();
  if(!PivotV10Enabled())
    return true;

  g_pivot_v10_started_at = TimeCurrent();
  g_pivot_v10_run_id = PivotV10BuildRunId();
  g_pivot_v10_config_id =
    "cfg_" + PivotV10HashToken(PivotV10BuildConfigPayload());
  g_pivot_v10_folder = PIVOT_V10_STORAGE_ROOT + "\\" +
                       PIVOT_V10_RUNS_FOLDER + "\\" +
                       g_pivot_v10_run_id;
  if(!PivotV10EnsureFolder())
    return false;
  if(PivotV10RunFilesExist())
  {
    PivotV10MarkFailed("RUN_FOLDER_ALREADY_INITIALIZED", g_pivot_v10_folder);
    return false;
  }

  g_pivot_v10_initialized = true;
  if(!PivotV10WriteManifest() || !PivotV10CreateDataFiles())
  {
    PivotV10MarkFailed("INITIALIZE_RUN_FILES", g_pivot_v10_folder);
    return false;
  }
  return true;
}

string PivotV10FeatureToken(const bool available,
                            const double value)
{
  return available ? PivotV10DoubleToken(value) : PIVOT_V10_NULL;
}

bool PivotV10RecordWindow(const PivotFractalWindowState &window,
                          const datetime requested_terminal_time,
                          const string terminal_status)
{
  if(!PivotV10Ready())
    return false;
  if(window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     window.active_bar_open <= 0 ||
     window.source_bar_open <= 0 ||
     window.first_observed_time <= 0)
    return PivotV10RejectReference("RECORD_WINDOW_INVALID");

  datetime terminal_time = requested_terminal_time;
  datetime latest_window_fact = window.active_bar_open;
  if(window.first_observed_time > latest_window_fact)
    latest_window_fact = window.first_observed_time;
  if(window.pp_arm_time > latest_window_fact)
    latest_window_fact = window.pp_arm_time;
  if(terminal_time <= latest_window_fact)
    terminal_time = latest_window_fact + 1;

  string row = "";
  PivotV10AppendColumn(row, IntegerToString(PIVOT_V10_SCHEMA_VERSION));
  PivotV10AppendColumn(row, g_pivot_v10_run_id);
  PivotV10AppendColumn(row, g_pivot_v10_config_id);
  PivotV10AppendColumn(row,
                       PivotV10WindowId(_Symbol,
                                       window.timeframe,
                                       window.active_bar_open));
  PivotV10AppendColumn(row, _Symbol);
  PivotV10AppendColumn(row, EnumToString(window.timeframe));
  PivotV10AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV10AppendTimestamp(row, window.active_bar_open);
  PivotV10AppendTimestamp(row, window.source_bar_open);
  PivotV10AppendTimestamp(row, window.source_close_boundary);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.levels.source_open, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.levels.source_high, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.levels.source_low, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.levels.source_close, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.levels.source_range, true));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV10AppendColumn(row,
                         PivotV10DoubleToken(window.levels.raw_prices[i], true));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV10AppendColumn(row,
                         PivotV10DoubleToken(window.levels.trade_prices[i], true));
  PivotV10AppendTimestamp(row, window.first_observed_time);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(window.first_observed_bid, true));
  PivotV10AppendColumn(row,
                       PivotV10PriceSideToken(window.pp_initial_relation));
  PivotV10AppendColumn(row, PivotV10PpRoleToken(window.pp_arm_state));
  PivotV10AppendTimestamp(row, window.pp_arm_time);
  PivotV10AppendColumn(row,
                       window.pp_arm_time > 0
                       ? PivotV10DoubleToken(window.pp_arm_bid, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PivotV10DoubleToken(window.macro_band.base_1, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PivotV10DoubleToken(window.macro_band.upper_1, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PivotV10DoubleToken(window.macro_band.lower_1, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PivotV10DoubleToken(window.macro_band.width_1, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PivotV10DoubleToken(window.macro_band.width_percent_1,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, PivotV10BoolToken(window.macro_band.complete));
  PivotV10AppendColumn(row,
                       window.macro_band.complete
                       ? PIVOT_V10_NULL
                       : PivotV10Cell(window.macro_band.invalid_reason));
  PivotV10AppendColumn(row, PivotV10WindowStateToken(window.state));
  PivotV10AppendColumn(row, PivotV10Cell(window.invalid_reason));
  PivotV10AppendTimestamp(row, terminal_time);
  PivotV10AppendColumn(row, terminal_status);

  if(!PivotV10QueueRow(PivotV10Path(PIVOT_V10_WINDOWS_FILE),
                       PIVOT_V10_WINDOWS_HEADER,
                       row,
                       g_pivot_v10_window_buffer))
    return false;
  g_pivot_v10_window_rows++;
  return true;
}

bool PivotV10RecordAttempt(const PivotSignal &signal)
{
  if(!PivotV10Ready())
    return false;
  if(signal.signal_id == "" || signal.window_id == "" ||
     signal.active_bar_open <= 0 || signal.trigger_time <= 0)
    return PivotV10RejectReference("RECORD_ATTEMPT_INVALID");

  BrokerExecutionCheck observed(signal.execution.observation_check);
  BrokerExecutionCheck request(signal.execution.pre_send_check);
  bool has_request = signal.execution.send_attempted;
  bool send_succeeded = has_request &&
                        signal.execution.send_result_check.allowed;
  bool observed_geometry = observed.geometry_valid &&
                           observed.risk_distance_points > 0.0 &&
                           observed.reward_distance_points > 0.0;
  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  double risk_budget = reference_mode
                       ? PIVOT_EXECUTION_REFERENCE_BALANCE *
                         Lot_Strategy_Size / 100.0
                       : 0.0;
  int level_index = (int)signal.level_id;
  if(level_index < 0 || level_index >= PIVOT_LEVEL_COUNT)
    return PivotV10RejectReference("RECORD_ATTEMPT_LEVEL");

  string row = "";
  PivotV10AppendColumn(row, IntegerToString(PIVOT_V10_SCHEMA_VERSION));
  PivotV10AppendColumn(row, g_pivot_v10_run_id);
  PivotV10AppendColumn(row, g_pivot_v10_config_id);
  PivotV10AppendColumn(row, signal.signal_id);
  PivotV10AppendColumn(row, signal.window_id);
  PivotV10AppendColumn(row, _Symbol);
  PivotV10AppendColumn(row, EnumToString(signal.pivot_timeframe));
  PivotV10AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV10AppendColumn(row, PivotV10TimeToken(signal.active_bar_open));
  PivotV10AppendColumn(row, PivotLevelLabel(signal.level_id));
  PivotV10AppendColumn(row, PivotV10DirectionToken(signal.direction));
  PivotV10AppendTimestamp(row, signal.trigger_time);
  PivotV10AppendColumn(row, PivotV10DoubleToken(signal.trigger_bid, true));
  PivotV10AppendColumn(row, PivotV10DoubleToken(signal.trigger_ask, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.trigger_spread_points));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(observed.point_size, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.levels.raw_prices[level_index],
                                           true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.levels.trade_prices[level_index],
                                           true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.route.structural_stop_loss,
                                           true));
  PivotV10AppendColumn(row,
                       observed_geometry
                       ? PivotV10DoubleToken(observed.planned_entry_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       observed_geometry
                       ? PivotV10DoubleToken(observed.stop_loss_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       observed_geometry
                       ? PivotV10DoubleToken(observed.take_profit_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       observed_geometry
                       ? PivotV10DoubleToken(observed.risk_distance_points, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       observed_geometry
                       ? PivotV10DoubleToken(observed.reward_distance_points, true)
                       : PIVOT_V10_NULL);
  if(has_request)
    PivotV10AppendTimestamp(row, request.broker_time);
  else
  {
    PivotV10AppendColumn(row, PIVOT_V10_NULL);
    PivotV10AppendColumn(row, PIVOT_V10_NULL);
    PivotV10AppendColumn(row, PIVOT_V10_NULL);
  }
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.bid, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.ask, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.planned_entry_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.stop_loss_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.take_profit_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.risk_distance_points, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.reward_distance_points, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.price_reward_risk_ratio,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, EnumToString(Lot_Type));
  PivotV10AppendColumn(row, DoubleToString(Lot_Strategy_Size, 8));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE, 8)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, PivotV10Cell(AccountInfoString(ACCOUNT_CURRENCY)));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(risk_budget, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.requested_volume, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.normalized_volume, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.quote_expected_stop_loss,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.quote_expected_take_profit,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request
                       ? PivotV10DoubleToken(request.quote_expected_reward_risk_ratio,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       has_request && reference_mode
                       ? PivotV10DoubleToken(request.risk_budget_utilization_ratio)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.features.micro_complete
                       ? PivotV10DoubleToken(signal.features.micro_band_base_0,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.features.micro_complete
                       ? PivotV10DoubleToken(signal.features.micro_band_upper_0,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.features.micro_complete
                       ? PivotV10DoubleToken(signal.features.micro_band_lower_0,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.features.micro_complete
                       ? PivotV10DoubleToken(signal.features.micro_band_width_0,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.features.micro_complete
                       ? PivotV10DoubleToken(signal.features.micro_band_width_percent_0,
                                            true)
                       : PIVOT_V10_NULL);
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    PivotV10AppendColumn(row,
                         PivotV10FeatureToken(
                           signal.features.micro_b_percent_available[shift],
                           signal.features.micro_b_percent[shift]));
  }
  for(int shift = 0; shift < PIVOT_B_PERCENT_SHIFT_COUNT; shift++)
  {
    PivotV10AppendColumn(row,
                         PivotV10FeatureToken(
                           signal.features.macro_pivot_b_percent_available[shift],
                           signal.features.macro_pivot_b_percent[shift]));
  }
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(signal.features.micro_complete));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(signal.features.macro_complete));
  PivotV10AppendColumn(row, PivotV10BoolToken(signal.features.complete));
  string feature_reason = signal.features.invalid_reason;
  if(!signal.features.complete && feature_reason == "")
    feature_reason = "FEATURE_EXPORT_DISABLED_OR_UNAVAILABLE";
  PivotV10AppendColumn(row,
                       signal.features.complete
                       ? PIVOT_V10_NULL
                       : PivotV10Cell(feature_reason));
  PivotV10AppendColumn(row, "1");
  PivotV10AppendColumn(row, PivotV10RouteStatusToken(signal.route.status));
  PivotV10AppendColumn(row, signal.attempt_status);
  PivotV10AppendColumn(row, PivotV10Cell(signal.block_source));
  PivotV10AppendColumn(row, PivotV10Cell(signal.block_reason));
  PivotV10AppendColumn(row, PivotV10BoolToken(has_request));
  PivotV10AppendColumn(row, PivotV10BoolToken(send_succeeded));

  if(!PivotV10QueueRow(PivotV10Path(PIVOT_V10_ATTEMPTS_FILE),
                       PIVOT_V10_ATTEMPTS_HEADER,
                       row,
                       g_pivot_v10_attempt_buffer))
    return false;
  g_pivot_v10_attempt_rows++;
  if(signal.features.complete)
    g_pivot_v10_feature_complete_rows++;
  else
    g_pivot_v10_feature_incomplete_rows++;
  if(has_request)
    g_pivot_v10_send_attempt_rows++;
  if(send_succeeded)
    g_pivot_v10_send_succeeded_rows++;
  if(signal.attempt_status == "CENSORED")
    g_pivot_v10_censored_attempt_rows++;
  return true;
}

bool PivotV10RecordExecutionCheck(const PivotSignal &signal,
                                  const BrokerExecutionCheck &check)
{
  if(!PivotV10Ready())
    return false;
  if(signal.signal_id == "" || signal.window_id == "" ||
     check.sequence <= 0 || check.broker_time <= 0)
    return PivotV10RejectReference("RECORD_EXECUTION_CHECK_INVALID");

  bool terminal_phase = check.phase == "TERMINAL";
  bool send_performed = check.phase == "SEND_RESULT" &&
                        signal.execution.send_attempted;
  bool send_succeeded = send_performed && check.allowed;
  bool entry_confirmed = !terminal_phase &&
                         signal.execution.broker_entry_confirmed;
  bool close_confirmed = terminal_phase &&
                         signal.execution.broker_close_confirmed;
  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  ulong order_ticket = signal.execution.order_ticket > 0
                       ? signal.execution.order_ticket
                       : check.order_ticket;
  ulong deal_ticket = check.deal_ticket;
  if(entry_confirmed)
    deal_ticket = signal.execution.entry_deal_ticket;
  if(close_confirmed)
    deal_ticket = signal.execution.last_close_deal_ticket;

  string row = "";
  PivotV10AppendColumn(row, IntegerToString(PIVOT_V10_SCHEMA_VERSION));
  PivotV10AppendColumn(row, g_pivot_v10_run_id);
  PivotV10AppendColumn(row, g_pivot_v10_config_id);
  PivotV10AppendColumn(row, signal.signal_id);
  PivotV10AppendColumn(row, signal.window_id);
  PivotV10AppendColumn(row, IntegerToString(check.sequence));
  PivotV10AppendColumn(row, check.phase);
  PivotV10AppendTimestamp(row, check.broker_time);
  PivotV10AppendColumn(row, _Symbol);
  PivotV10AppendColumn(row, PivotV10DirectionToken(signal.direction));
  PivotV10AppendColumn(row, StringFormat("%I64d", check.account_margin_mode));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(check.account_margin_mode_supported));
  PivotV10AppendColumn(row, StringFormat("%I64d", check.symbol_trade_mode));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(check.symbol_trade_mode_allowed));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.market_session_open));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.account_trade_allowed));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(check.account_expert_trade_allowed));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.terminal_trade_allowed));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.mql_trade_allowed));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.bid));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.ask));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.spread_points));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.point_size));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.stops_distance_points));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.freeze_distance_points));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.planned_entry_price));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.stop_loss_price));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.take_profit_price));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.risk_distance_points));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.reward_distance_points));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(check.risk_budget_amount)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.requested_volume));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.normalized_volume));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.volume_min));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.volume_max));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.volume_step));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.volume_valid));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.quote_expected_stop_loss));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(check.quote_expected_take_profit));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         check.quote_expected_reward_risk_ratio));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(
                           check.risk_budget_utilization_ratio)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.account_balance));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.free_margin));
  PivotV10AppendColumn(row, PivotV10DoubleToken(check.required_margin));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.margin_valid));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.geometry_valid));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.stop_distance_valid));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.freeze_distance_valid));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(check.order_check_performed));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.order_check_allowed));
  PivotV10AppendColumn(row,
                       check.order_check_performed
                       ? StringFormat("%I64u", check.order_check_retcode)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, PivotV10Cell(check.order_check_comment));
  PivotV10AppendColumn(row, PivotV10BoolToken(check.allowed));
  PivotV10AppendColumn(row, PivotV10Cell(check.block_source));
  PivotV10AppendColumn(row, PivotV10Cell(check.block_reason));
  PivotV10AppendColumn(row, PivotV10BoolToken(send_performed));
  PivotV10AppendColumn(row, PivotV10BoolToken(send_succeeded));
  PivotV10AppendColumn(row,
                       send_performed
                       ? StringFormat("%I64u", check.send_retcode)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row, PivotV10Cell(check.send_comment));
  PivotV10AppendColumn(row, PivotV10UlongToken(order_ticket));
  PivotV10AppendColumn(row, PivotV10UlongToken(deal_ticket));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(signal.execution.position_ticket));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(
                         signal.execution.position_identifier));
  PivotV10AppendColumn(row, PivotV10BoolToken(entry_confirmed));
  PivotV10AppendColumn(row, PivotV10BoolToken(close_confirmed));
  PivotV10AppendColumn(row,
                       signal.execution.broker_entry_confirmed
                       ? PivotV10DoubleToken(
                           signal.execution.broker_entry_price,
                           true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.execution.broker_entry_confirmed
                       ? PivotV10DoubleToken(signal.execution.broker_volume,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.execution.broker_entry_confirmed
                       ? PivotV10DoubleToken(
                           signal.execution.broker_stop_loss,
                           true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       signal.execution.broker_entry_confirmed
                       ? PivotV10DoubleToken(
                           signal.execution.broker_take_profit,
                           true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       close_confirmed
                       ? PivotV10DoubleToken(signal.execution.close_price, true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       close_confirmed
                       ? PivotV10DoubleToken(signal.execution.closed_volume,
                                            true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       close_confirmed
                       ? signal.execution.terminal_reason
                       : PIVOT_V10_NULL);

  if(!PivotV10QueueRow(PivotV10Path(PIVOT_V10_CHECKS_FILE),
                       PIVOT_V10_CHECKS_HEADER,
                       row,
                       g_pivot_v10_check_buffer))
    return false;
  g_pivot_v10_check_rows++;
  if(entry_confirmed)
    g_pivot_v10_broker_filled_rows++;
  return true;
}

bool PivotV10RecordOutcome(const PivotSignal &signal)
{
  if(!PivotV10Ready())
    return false;
  if(signal.signal_id == "" || signal.window_id == "" ||
     !signal.execution.broker_entry_confirmed ||
     !signal.execution.broker_close_confirmed ||
     signal.execution.close_deal_count <= 0)
    return PivotV10RejectReference("RECORD_OUTCOME_INVALID");

  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  long duration_seconds = (long)(signal.execution.close_time -
                                 signal.execution.broker_entry_time);
  if(duration_seconds < 0)
    return PivotV10RejectReference("RECORD_OUTCOME_TIME");

  string row = "";
  PivotV10AppendColumn(row, IntegerToString(PIVOT_V10_SCHEMA_VERSION));
  PivotV10AppendColumn(row, g_pivot_v10_run_id);
  PivotV10AppendColumn(row, g_pivot_v10_config_id);
  PivotV10AppendColumn(row, signal.signal_id);
  PivotV10AppendColumn(row, signal.window_id);
  PivotV10AppendColumn(row, _Symbol);
  PivotV10AppendColumn(row, EnumToString(signal.pivot_timeframe));
  PivotV10AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV10AppendColumn(row, PivotV10TimeToken(signal.active_bar_open));
  PivotV10AppendColumn(row, PivotLevelLabel(signal.level_id));
  PivotV10AppendColumn(row, PivotV10DirectionToken(signal.direction));
  PivotV10AppendTimestamp(row, signal.execution.broker_entry_time);
  PivotV10AppendTimestamp(row, signal.execution.close_time);
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(signal.execution.order_ticket));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(signal.execution.entry_deal_ticket));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(
                         signal.execution.last_close_deal_ticket));
  PivotV10AppendColumn(row,
                       IntegerToString(signal.execution.close_deal_count));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(signal.execution.position_ticket));
  PivotV10AppendColumn(row,
                       PivotV10UlongToken(
                         signal.execution.position_identifier));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.planned_entry_price,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.broker_entry_price,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.broker_volume,
                                           true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.broker_stop_loss,
                                           true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.broker_take_profit,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.close_price, true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.closed_volume,
                                           true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.risk_distance_points,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.reward_distance_points,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.price_reward_risk_ratio,
                         true));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(
                           signal.execution.risk_budget_amount,
                           true)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.quote_expected_stop_loss,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.quote_expected_take_profit,
                         true));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.quote_expected_reward_risk_ratio,
                         true));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(
                           signal.execution.risk_budget_utilization_ratio)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.entry_slippage_points));
  PivotV10AppendColumn(row,
                       signal.execution.terminal_reason == "BROKER_TP" ||
                       signal.execution.terminal_reason == "BROKER_SL"
                       ? PivotV10DoubleToken(
                           signal.execution.exit_slippage_points)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.gross_profit));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.commission));
  PivotV10AppendColumn(row, PivotV10DoubleToken(signal.execution.swap));
  PivotV10AppendColumn(row, PivotV10DoubleToken(signal.execution.fee));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.net_profit));
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(signal.execution.gross_budget_r)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       reference_mode
                       ? PivotV10DoubleToken(signal.execution.net_budget_r)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(
                         signal.execution.gross_execution_r));
  PivotV10AppendColumn(row,
                       PivotV10DoubleToken(signal.execution.net_execution_r));
  PivotV10AppendColumn(row, signal.execution.terminal_reason);
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(
                         signal.execution.close_reason_consistent));
  PivotV10AppendColumn(row,
                       PivotV10BoolToken(signal.execution.binary_eligible));
  PivotV10AppendColumn(row,
                       signal.execution.binary_eligible
                       ? IntegerToString(signal.execution.binary_target)
                       : PIVOT_V10_NULL);
  PivotV10AppendColumn(row,
                       PivotV10Cell(signal.execution.exclusion_reason));
  PivotV10AppendColumn(row, StringFormat("%I64d", duration_seconds));
  PivotV10AppendColumn(row, "1");
  PivotV10AppendColumn(row, "1");

  if(!PivotV10QueueRow(PivotV10Path(PIVOT_V10_OUTCOMES_FILE),
                       PIVOT_V10_OUTCOMES_HEADER,
                       row,
                       g_pivot_v10_outcome_buffer))
    return false;
  g_pivot_v10_outcome_rows++;
  if(signal.execution.binary_eligible)
  {
    g_pivot_v10_binary_eligible_rows++;
    if(signal.execution.binary_target == 1)
      g_pivot_v10_binary_tp_rows++;
    else if(signal.execution.binary_target == 0)
      g_pivot_v10_binary_sl_rows++;
  }
  else if(signal.execution.exclusion_reason == "FEATURE_INCOMPLETE")
  {
    g_pivot_v10_excluded_feature_incomplete_rows++;
  }
  if(signal.execution.terminal_reason == "MIXED")
    g_pivot_v10_excluded_mixed_rows++;
  else if(signal.execution.terminal_reason == "MANUAL")
    g_pivot_v10_excluded_manual_rows++;
  else if(signal.execution.terminal_reason == "STOP_OUT")
    g_pivot_v10_excluded_stop_out_rows++;
  else if(signal.execution.terminal_reason == "EXPERT")
    g_pivot_v10_excluded_expert_rows++;
  else if(signal.execution.terminal_reason == "OTHER")
    g_pivot_v10_excluded_other_rows++;
  return true;
}

void PivotV10RegisterDuplicateIdentity()
{
  g_pivot_v10_duplicate_identity_count++;
}

bool PivotV10WriteSummary(const string completion_status)
{
  if(!PivotV10Enabled() || !g_pivot_v10_initialized ||
     g_pivot_v10_summary_written)
    return !g_pivot_v10_failed;

  if(!PivotV10FlushAll())
    PivotV10MarkFailed("FLUSH_ALL");
  datetime finished_at = TimeCurrent();
  if(finished_at < g_pivot_v10_started_at)
    finished_at = g_pivot_v10_started_at;

  string row = "";
  PivotV10AppendColumn(row, IntegerToString(PIVOT_V10_SCHEMA_VERSION));
  PivotV10AppendColumn(row, g_pivot_v10_run_id);
  PivotV10AppendColumn(row, g_pivot_v10_config_id);
  PivotV10AppendTimestamp(row, g_pivot_v10_started_at);
  PivotV10AppendTimestamp(row, finished_at);
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_window_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_attempt_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_check_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_outcome_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_feature_complete_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_feature_incomplete_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_send_attempt_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_send_succeeded_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_broker_filled_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_outcome_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_binary_eligible_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_binary_tp_rows));
  PivotV10AppendColumn(row, IntegerToString(g_pivot_v10_binary_sl_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_outcome_rows -
                                       g_pivot_v10_binary_eligible_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(
                         g_pivot_v10_excluded_feature_incomplete_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_excluded_mixed_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_excluded_manual_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_excluded_stop_out_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_excluded_expert_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_excluded_other_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_censored_attempt_rows));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_duplicate_identity_count));
  PivotV10AppendColumn(row,
                       IntegerToString(
                         g_pivot_v10_referential_integrity_error_count));
  PivotV10AppendColumn(row,
                       IntegerToString(g_pivot_v10_row_integrity_error_count));
  PivotV10AppendColumn(row, g_pivot_v10_failed ? "FAILED" : "OK");
  PivotV10AppendColumn(row, completion_status);

  string filename = PivotV10Path(PIVOT_V10_SUMMARY_FILE);
  if(!PivotV10RowMatchesHeader(PIVOT_V10_SUMMARY_HEADER, row) ||
     !PivotV10FileHeaderMatches(filename, PIVOT_V10_SUMMARY_HEADER) ||
     !PivotV10WriteLine(filename, row, true))
    return false;
  g_pivot_v10_summary_written = true;
  return !g_pivot_v10_failed;
}

void PivotV10StatsDeinit(const string completion_status = "CENSORED")
{
  if(!PivotV10Enabled() || !g_pivot_v10_initialized)
    return;
  PivotV10WriteSummary(completion_status);
  ArrayResize(g_pivot_v10_window_buffer, 0);
  ArrayResize(g_pivot_v10_attempt_buffer, 0);
  ArrayResize(g_pivot_v10_check_buffer, 0);
  ArrayResize(g_pivot_v10_outcome_buffer, 0);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
