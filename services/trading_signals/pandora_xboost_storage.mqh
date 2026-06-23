//+------------------------------------------------------------------+
//|                     pandora_xboost_storage.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_

const string PANDORA_XBOOST_STATS_HEADER =
  "node_key,key_hash,samples,wins,losses,be,total_r,avg_r,avg_win_r,avg_loss_r,max_win_r,max_loss_r,max_drawdown_r,expectancy_r,last_seen";
const string PANDORA_XBOOST_SAMPLES_HEADER =
  "sample_id,node_key,close_event,r_multiple,seen_at";
const string PANDORA_XBOOST_BROKER_TRADES_HEADER =
  "broker_trade_id,strategy_key,root_id,root_date,node_key,node_path,sample_id,depth,broker_trade_index,side,entry_time,close_time,entry_price,close_price,sl_points,r_multiple_broker,net_profit,close_event,close_reason,model_score_r,model_posterior_r,model_samples,broker_window_samples,seen_at";
const string PANDORA_XBOOST_STORAGE_ROOT = "PandoraXBoost";
const string PANDORA_XBOOST_DEBUG_LOG = "query_debug.txt";

void PandoraXBoostLogEvent(const string label, const string message);
string PandoraXBoostTerminalFolder();
string PandoraXBoostServerFolder();
string PandoraXBoostSymbolTimeframeFolder();
string PandoraXBoostStorageFolder();
string PandoraXBoostStorageFolderLabel();
string PandoraXBoostStorageShortLabel();
string PandoraXBoostStorageAbsoluteFolder();
bool PandoraXBoostEnsureStorageFolder();
bool PandoraXBoostSaveStatsSnapshot();

void PandoraXBoostLogEvent(const string label, const string message)
{
  if(!Enable_File_Logs)
    return;
  AppendTimestampedLog(PANDORA_XBOOST_DEBUG_LOG, label, message);
}

string PandoraXBoostSanitizeFilePart(const string raw_value)
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
    bool is_safe = is_digit || is_upper || is_lower || ch == '_' || ch == '-';
    if(is_safe)
      result = result + StringSubstr(value, i, 1);
    else
      result = result + "_";
  }

  if(result == "")
    result = "default";
  return result;
}

string PandoraXBoostFilePrefix()
{
  string filename_prefix = StringFormat("pandora_xboost_v%d_%s_%s_%d",
                      PANDORA_XBOOST_SCHEMA_VERSION,
                      PandoraXBoostSanitizeFilePart(Pandora_XBoost_Strategy_Id),
                      PandoraXBoostSanitizeFilePart(_Symbol),
                      (int)_Period);
  return PandoraXBoostStorageFolder() + "\\" + filename_prefix;
}

string PandoraXBoostTerminalFolder()
{
  string data_path = TerminalInfoString(TERMINAL_DATA_PATH);
  if(data_path == "")
    data_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH);

  ulong terminal_hash = PandoraXBoostHashKey(data_path) % 100000000;
  return StringFormat("mt5_%I64u", terminal_hash);
}

string PandoraXBoostServerFolder()
{
  string server_name = AccountInfoString(ACCOUNT_SERVER);
  if(server_name == "")
    server_name = "server_unknown";
  return PandoraXBoostSanitizeFilePart(server_name);
}

string PandoraXBoostSymbolTimeframeFolder()
{
  return PandoraXBoostSanitizeFilePart(_Symbol) + "_tf_" + IntegerToString((int)_Period);
}

string PandoraXBoostStorageFolder()
{
  return PANDORA_XBOOST_STORAGE_ROOT + "\\" +
         PandoraXBoostTerminalFolder() + "\\" +
         PandoraXBoostServerFolder() + "\\" +
         PandoraXBoostSanitizeFilePart(Pandora_XBoost_Strategy_Id) + "\\" +
         PandoraXBoostSymbolTimeframeFolder();
}

string PandoraXBoostStorageFolderLabel()
{
  return "Common\\Files\\" + PandoraXBoostStorageFolder();
}

string PandoraXBoostStorageShortLabel()
{
  return "Common\\" + PandoraXBoostTerminalFolder() + "\\" +
         PandoraXBoostSanitizeFilePart(Pandora_XBoost_Strategy_Id) + "\\" +
         PandoraXBoostSymbolTimeframeFolder();
}

string PandoraXBoostStorageAbsoluteFolder()
{
  string common_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
  if(common_path == "")
    return PandoraXBoostStorageFolderLabel();
  return common_path + "\\Files\\" + PandoraXBoostStorageFolder();
}

bool PandoraXBoostEnsureStorageFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(PandoraXBoostStorageFolder(), delimiter, parts);
  if(total <= 0)
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_FOLDER_FAIL",
                          "reason=split_failed folder=" + PandoraXBoostStorageFolder());
    return false;
  }

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
    bool folder_created = FolderCreate(current_folder, FILE_COMMON);
    int folder_error = GetLastError();
    if(!folder_created && folder_error != 0)
    {
      PandoraXBoostLogEvent("PANDORA_XBOOST_FOLDER_CREATE",
                            StringFormat("folder=%s result=FAIL err=%d",
                                         current_folder,
                                         folder_error));
    }
  }
  PandoraXBoostLogEvent("PANDORA_XBOOST_FOLDER_READY",
                        "folder=" + PandoraXBoostStorageAbsoluteFolder());
  return true;
}

string PandoraXBoostStatsFilename()
{
  return PandoraXBoostFilePrefix() + "_stats.csv";
}

string PandoraXBoostSamplesFilename()
{
  return PandoraXBoostFilePrefix() + "_samples.csv";
}

string PandoraXBoostBrokerTradesFilename()
{
  return PandoraXBoostFilePrefix() + "_broker_trades.csv";
}

bool PandoraXBoostSplitCsvLine(const string row,
                               string &fields[])
{
  ushort delimiter = StringGetCharacter(",", 0);
  int total = StringSplit(row, delimiter, fields);
  return (total > 0);
}

bool PandoraXBoostSampleIdExists(const string sample_id)
{
  if(sample_id == "")
    return false;

  int total = ArraySize(g_pandora_xboost_sample_ids);
  for(int i = 0; i < total; i++)
  {
    if(g_pandora_xboost_sample_ids[i] == sample_id)
      return true;
  }
  return false;
}

bool PandoraXBoostRememberSampleId(const string sample_id)
{
  if(sample_id == "")
    return false;
  if(PandoraXBoostSampleIdExists(sample_id))
    return false;

  int total = ArraySize(g_pandora_xboost_sample_ids);
  ArrayResize(g_pandora_xboost_sample_ids, total + 1, 128);
  g_pandora_xboost_sample_ids[total] = sample_id;
  return true;
}

string PandoraXBoostCsvCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, ",", ";");
  return value;
}

bool PandoraXBoostBrokerTradeIdExists(const string broker_trade_id)
{
  if(broker_trade_id == "")
    return false;

  int total = ArraySize(g_pandora_xboost_broker_trade_ids);
  for(int i = 0; i < total; i++)
  {
    if(g_pandora_xboost_broker_trade_ids[i] == broker_trade_id)
      return true;
  }
  return false;
}

bool PandoraXBoostRememberBrokerTradeId(const string broker_trade_id)
{
  if(broker_trade_id == "")
    return false;
  if(PandoraXBoostBrokerTradeIdExists(broker_trade_id))
    return false;

  int total = ArraySize(g_pandora_xboost_broker_trade_ids);
  ArrayResize(g_pandora_xboost_broker_trade_ids, total + 1, 128);
  g_pandora_xboost_broker_trade_ids[total] = broker_trade_id;
  return true;
}

bool PandoraXBoostRememberBrokerTradeRow(const PandoraXBoostBrokerTradeRow &trade_row)
{
  if(!PandoraXBoostRememberBrokerTradeId(trade_row.broker_trade_id))
    return false;

  int total = ArraySize(g_pandora_xboost_broker_trades);
  ArrayResize(g_pandora_xboost_broker_trades, total + 1, 128);
  g_pandora_xboost_broker_trades[total] = trade_row;
  return true;
}

bool PandoraXBoostAppendPendingSampleRow(const string sample_id,
                                         const string row)
{
  if(sample_id == "" || row == "")
    return false;
  if(!PandoraXBoostRememberSampleId(sample_id))
    return false;

  int total = ArraySize(g_pandora_xboost_pending_sample_rows);
  ArrayResize(g_pandora_xboost_pending_sample_rows, total + 1, 128);
  g_pandora_xboost_pending_sample_rows[total] = row;
  g_pandora_xboost_storage_dirty = true;
  return true;
}

void PandoraXBoostClearStorageMemory()
{
  ArrayResize(g_pandora_xboost_stats, 0, 0);
  ArrayResize(g_pandora_xboost_sample_ids, 0, 0);
  ArrayResize(g_pandora_xboost_pending_sample_rows, 0, 0);
  ArrayResize(g_pandora_xboost_broker_trades, 0, 0);
  ArrayResize(g_pandora_xboost_broker_trade_ids, 0, 0);
  ArrayResize(g_pandora_xboost_pending_broker_trade_rows, 0, 0);
  PandoraXBoostClearTopCandidates();
  g_pandora_xboost_lookup_cache_key = "";
  g_pandora_xboost_lookup_cache_hash = 0;
  g_pandora_xboost_lookup_cache_index = -1;
  g_pandora_xboost_storage_loaded = false;
  g_pandora_xboost_storage_dirty = false;
  g_pandora_xboost_storage_load_time = 0;
}

bool PandoraXBoostLoadStats()
{
  string filename = PandoraXBoostStatsFilename();
  if(!FileIsExist(filename, FILE_COMMON))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_STATS_MISSING",
                          "file=" + filename);
    return true;
  }

  ResetLastError();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_STATS_OPEN_FAIL",
                          StringFormat("file=%s err=%d",
                                       filename,
                                       open_error));
    return false;
  }

  bool header_seen = false;
  int rows_loaded = 0;
  while(!FileIsEnding(handle))
  {
    string row = FileReadString(handle);
    if(row == "")
      continue;
    if(!header_seen)
    {
      header_seen = true;
      if(row == PANDORA_XBOOST_STATS_HEADER)
        continue;
    }

    string fields[];
    if(!PandoraXBoostSplitCsvLine(row, fields))
      continue;
    if(ArraySize(fields) < 15)
      continue;

    PandoraXBoostStats stats;
    stats.node_key       = fields[0];
    stats.key_hash       = PandoraXBoostHashKey(stats.node_key);
    stats.samples        = (int)StringToInteger(fields[2]);
    stats.wins           = (int)StringToInteger(fields[3]);
    stats.losses         = (int)StringToInteger(fields[4]);
    stats.be             = (int)StringToInteger(fields[5]);
    stats.total_r        = StringToDouble(fields[6]);
    stats.avg_r          = StringToDouble(fields[7]);
    stats.avg_win_r      = StringToDouble(fields[8]);
    stats.avg_loss_r     = StringToDouble(fields[9]);
    stats.max_win_r      = StringToDouble(fields[10]);
    stats.max_loss_r     = StringToDouble(fields[11]);
    stats.max_drawdown_r = StringToDouble(fields[12]);
    stats.expectancy_r   = StringToDouble(fields[13]);
    stats.last_seen      = (datetime)StringToInteger(fields[14]);

    int total = ArraySize(g_pandora_xboost_stats);
    ArrayResize(g_pandora_xboost_stats, total + 1, 128);
    g_pandora_xboost_stats[total] = stats;
    rows_loaded++;
  }

  FileClose(handle);
  PandoraXBoostLogEvent("PANDORA_XBOOST_STATS_LOADED",
                        StringFormat("file=%s rows=%d",
                                     filename,
                                     rows_loaded));
  return true;
}

bool PandoraXBoostLoadSampleIds()
{
  string filename = PandoraXBoostSamplesFilename();
  if(!FileIsExist(filename, FILE_COMMON))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_MISSING",
                          "file=" + filename);
    return true;
  }

  ResetLastError();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_OPEN_FAIL",
                          StringFormat("file=%s err=%d",
                                       filename,
                                       open_error));
    return false;
  }

  bool header_seen = false;
  int ids_loaded = 0;
  while(!FileIsEnding(handle))
  {
    string row = FileReadString(handle);
    if(row == "")
      continue;
    if(!header_seen)
    {
      header_seen = true;
      if(row == PANDORA_XBOOST_SAMPLES_HEADER)
        continue;
    }

    string fields[];
    if(!PandoraXBoostSplitCsvLine(row, fields))
      continue;
    if(ArraySize(fields) < 1)
      continue;

    if(PandoraXBoostRememberSampleId(fields[0]))
      ids_loaded++;
  }

  FileClose(handle);
  PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_LOADED",
                        StringFormat("file=%s ids=%d",
                                     filename,
                                     ids_loaded));
  return true;
}

bool PandoraXBoostLoadBrokerTrades()
{
  string filename = PandoraXBoostBrokerTradesFilename();
  if(!FileIsExist(filename, FILE_COMMON))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_MISSING",
                          "file=" + filename);
    return true;
  }

  ResetLastError();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_OPEN_FAIL",
                          StringFormat("file=%s err=%d",
                                       filename,
                                       open_error));
    return false;
  }

  bool header_seen = false;
  int rows_loaded = 0;
  int rows_skipped = 0;
  while(!FileIsEnding(handle))
  {
    string row = FileReadString(handle);
    if(row == "")
      continue;
    if(!header_seen)
    {
      header_seen = true;
      if(row == PANDORA_XBOOST_BROKER_TRADES_HEADER)
        continue;
    }

    string fields[];
    if(!PandoraXBoostSplitCsvLine(row, fields) || ArraySize(fields) < 24)
    {
      rows_skipped++;
      continue;
    }

    PandoraXBoostBrokerTradeRow trade_row;
    trade_row.broker_trade_id      = fields[0];
    trade_row.strategy_key         = fields[1];
    trade_row.root_id              = fields[2];
    trade_row.root_date            = (datetime)StringToInteger(fields[3]);
    trade_row.node_key             = fields[4];
    trade_row.node_path            = fields[5];
    trade_row.sample_id            = fields[6];
    trade_row.depth                = (int)StringToInteger(fields[7]);
    trade_row.broker_trade_index   = (int)StringToInteger(fields[8]);
    trade_row.side                 = PandoraXBoostDirectionFromLabel(fields[9]);
    trade_row.entry_time           = (datetime)StringToInteger(fields[10]);
    trade_row.close_time           = (datetime)StringToInteger(fields[11]);
    trade_row.entry_price          = StringToDouble(fields[12]);
    trade_row.close_price          = StringToDouble(fields[13]);
    trade_row.sl_points            = StringToDouble(fields[14]);
    trade_row.r_multiple_broker    = StringToDouble(fields[15]);
    trade_row.net_profit           = StringToDouble(fields[16]);
    trade_row.close_event          = PandoraXBoostCloseEventFromLabel(fields[17]);
    trade_row.close_reason         = fields[18];
    trade_row.model_score_r        = StringToDouble(fields[19]);
    trade_row.model_posterior_r    = StringToDouble(fields[20]);
    trade_row.model_samples        = (int)StringToInteger(fields[21]);
    trade_row.broker_window_samples = (int)StringToInteger(fields[22]);
    trade_row.seen_at              = (datetime)StringToInteger(fields[23]);

    if(PandoraXBoostRememberBrokerTradeRow(trade_row))
      rows_loaded++;
    else
      rows_skipped++;
  }

  FileClose(handle);
  PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_LOADED",
                        StringFormat("file=%s rows=%d skipped=%d",
                                     filename,
                                     rows_loaded,
                                     rows_skipped));
  return true;
}

bool PandoraXBoostLoad()
{
  PandoraXBoostClearStorageMemory();
  if(!PandoraXBoostEnabled())
    return true;

  PandoraXBoostEnsureStorageFolder();
  bool stats_loaded = PandoraXBoostLoadStats();
  bool samples_loaded = PandoraXBoostLoadSampleIds();
  bool broker_trades_loaded = PandoraXBoostLoadBrokerTrades();
  g_pandora_xboost_storage_loaded =
    stats_loaded && samples_loaded && broker_trades_loaded;
  g_pandora_xboost_storage_load_time = TimeCurrent();
  if(g_pandora_xboost_storage_loaded)
    PandoraXBoostSaveStatsSnapshot();

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_LOAD mode=%s stats=%d samples=%d broker=%d folder=%s stats_file=%s samples_file=%s broker_file=%s",
                PandoraXBoostModeLabel(Pandora_XBoost_Mode),
                ArraySize(g_pandora_xboost_stats),
                ArraySize(g_pandora_xboost_sample_ids),
                ArraySize(g_pandora_xboost_broker_trades),
                PandoraXBoostStorageAbsoluteFolder(),
                PandoraXBoostStatsFilename(),
                PandoraXBoostSamplesFilename(),
                PandoraXBoostBrokerTradesFilename());
  }
  PandoraXBoostLogEvent("PANDORA_XBOOST_LOAD",
                        StringFormat("mode=%s loaded=%s stats=%d samples=%d broker=%d folder=%s stats_file=%s samples_file=%s broker_file=%s",
                                     PandoraXBoostModeLabel(Pandora_XBoost_Mode),
                                     g_pandora_xboost_storage_loaded ? "OK" : "FAIL",
                                     ArraySize(g_pandora_xboost_stats),
                                     ArraySize(g_pandora_xboost_sample_ids),
                                     ArraySize(g_pandora_xboost_broker_trades),
                                     PandoraXBoostStorageAbsoluteFolder(),
                                     PandoraXBoostStatsFilename(),
                                     PandoraXBoostSamplesFilename(),
                                     PandoraXBoostBrokerTradesFilename()));

  return g_pandora_xboost_storage_loaded;
}

string PandoraXBoostFormatStatsRow(const PandoraXBoostStats &stats)
{
  return StringFormat("%s,%I64u,%d,%d,%d,%d,%.8f,%.8f,%.8f,%.8f,%.8f,%.8f,%.8f,%.8f,%I64d",
                      stats.node_key,
                      stats.key_hash,
                      stats.samples,
                      stats.wins,
                      stats.losses,
                      stats.be,
                      stats.total_r,
                      stats.avg_r,
                      stats.avg_win_r,
                      stats.avg_loss_r,
                      stats.max_win_r,
                      stats.max_loss_r,
                      stats.max_drawdown_r,
                      stats.expectancy_r,
                      (long)stats.last_seen);
}

bool PandoraXBoostSaveStatsSnapshot()
{
  PandoraXBoostEnsureStorageFolder();
  string filename = PandoraXBoostStatsFilename();
  ResetLastError();
  int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_STATS_SAVE_FAIL",
                          StringFormat("file=%s err=%d rows=%d",
                                       filename,
                                       open_error,
                                       ArraySize(g_pandora_xboost_stats)));
    return false;
  }

  FileWrite(handle, PANDORA_XBOOST_STATS_HEADER);
  int total = ArraySize(g_pandora_xboost_stats);
  for(int i = 0; i < total; i++)
    FileWrite(handle, PandoraXBoostFormatStatsRow(g_pandora_xboost_stats[i]));

  FileClose(handle);
  PandoraXBoostLogEvent("PANDORA_XBOOST_STATS_SAVED",
                        StringFormat("file=%s rows=%d",
                                     filename,
                                     total));
  return true;
}

bool PandoraXBoostFlushPendingSamples()
{
  int total = ArraySize(g_pandora_xboost_pending_sample_rows);
  if(total <= 0)
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_FLUSH",
                          "pending=0 result=SKIP");
    return true;
  }

  string filename = PandoraXBoostSamplesFilename();
  PandoraXBoostEnsureStorageFolder();
  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  ResetLastError();
  int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_SAVE_FAIL",
                          StringFormat("file=%s err=%d pending=%d",
                                       filename,
                                       open_error,
                                       total));
    return false;
  }

  FileSeek(handle, 0, SEEK_END);
  if(needs_header)
    FileWrite(handle, PANDORA_XBOOST_SAMPLES_HEADER);

  for(int i = 0; i < total; i++)
    FileWrite(handle, g_pandora_xboost_pending_sample_rows[i]);

  FileClose(handle);
  ArrayResize(g_pandora_xboost_pending_sample_rows, 0, 0);
  PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLES_SAVED",
                        StringFormat("file=%s rows=%d header=%s",
                                     filename,
                                     total,
                                     needs_header ? "1" : "0"));
  return true;
}

string PandoraXBoostFormatBrokerTradeRow(const PandoraXBoostBrokerTradeRow &trade_row)
{
  return StringFormat("%s,%s,%s,%I64d,%s,%s,%s,%d,%d,%s,%I64d,%I64d,%.8f,%.8f,%.8f,%.8f,%.8f,%s,%s,%.8f,%.8f,%d,%d,%I64d",
                      PandoraXBoostCsvCell(trade_row.broker_trade_id),
                      PandoraXBoostCsvCell(trade_row.strategy_key),
                      PandoraXBoostCsvCell(trade_row.root_id),
                      (long)trade_row.root_date,
                      PandoraXBoostCsvCell(trade_row.node_key),
                      PandoraXBoostCsvCell(trade_row.node_path),
                      PandoraXBoostCsvCell(trade_row.sample_id),
                      trade_row.depth,
                      trade_row.broker_trade_index,
                      PandoraXBoostDirectionLabel(trade_row.side),
                      (long)trade_row.entry_time,
                      (long)trade_row.close_time,
                      trade_row.entry_price,
                      trade_row.close_price,
                      trade_row.sl_points,
                      trade_row.r_multiple_broker,
                      trade_row.net_profit,
                      PandoraXBoostCloseEventLabel(trade_row.close_event),
                      PandoraXBoostCsvCell(trade_row.close_reason),
                      trade_row.model_score_r,
                      trade_row.model_posterior_r,
                      trade_row.model_samples,
                      trade_row.broker_window_samples,
                      (long)trade_row.seen_at);
}

bool PandoraXBoostAppendPendingBrokerTradeRow(const PandoraXBoostBrokerTradeRow &trade_row)
{
  if(trade_row.broker_trade_id == "")
    return false;
  if(PandoraXBoostBrokerTradeIdExists(trade_row.broker_trade_id))
    return false;

  string row = PandoraXBoostFormatBrokerTradeRow(trade_row);
  if(row == "")
    return false;

  if(!PandoraXBoostRememberBrokerTradeRow(trade_row))
    return false;

  int total = ArraySize(g_pandora_xboost_pending_broker_trade_rows);
  ArrayResize(g_pandora_xboost_pending_broker_trade_rows, total + 1, 128);
  g_pandora_xboost_pending_broker_trade_rows[total] = row;
  g_pandora_xboost_storage_dirty = true;
  return true;
}

bool PandoraXBoostFlushPendingBrokerTrades()
{
  int total = ArraySize(g_pandora_xboost_pending_broker_trade_rows);
  if(total <= 0)
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_FLUSH",
                          "pending=0 result=SKIP");
    return true;
  }

  string filename = PandoraXBoostBrokerTradesFilename();
  PandoraXBoostEnsureStorageFolder();
  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  ResetLastError();
  int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_SAVE_FAIL",
                          StringFormat("file=%s err=%d pending=%d",
                                       filename,
                                       open_error,
                                       total));
    return false;
  }

  FileSeek(handle, 0, SEEK_END);
  if(needs_header)
    FileWrite(handle, PANDORA_XBOOST_BROKER_TRADES_HEADER);

  for(int i = 0; i < total; i++)
    FileWrite(handle, g_pandora_xboost_pending_broker_trade_rows[i]);

  FileClose(handle);
  ArrayResize(g_pandora_xboost_pending_broker_trade_rows, 0, 0);
  PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADES_SAVED",
                        StringFormat("file=%s rows=%d header=%s",
                                     filename,
                                     total,
                                     needs_header ? "1" : "0"));
  return true;
}

bool PandoraXBoostSave()
{
  if(!PandoraXBoostEnabled())
    return true;

  int pending_before = ArraySize(g_pandora_xboost_pending_sample_rows);
  int pending_broker_before = ArraySize(g_pandora_xboost_pending_broker_trade_rows);
  bool samples_saved = PandoraXBoostFlushPendingSamples();
  bool broker_trades_saved = PandoraXBoostFlushPendingBrokerTrades();
  bool stats_saved = PandoraXBoostSaveStatsSnapshot();
  if(samples_saved && broker_trades_saved && stats_saved)
    g_pandora_xboost_storage_dirty = false;

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_SAVE samples=%s broker=%s stats=%s pending=%d broker_pending=%d folder=%s stats_file=%s samples_file=%s broker_file=%s",
                samples_saved ? "OK" : "FAIL",
                broker_trades_saved ? "OK" : "FAIL",
                stats_saved ? "OK" : "FAIL",
                pending_before,
                pending_broker_before,
                PandoraXBoostStorageAbsoluteFolder(),
                PandoraXBoostStatsFilename(),
                PandoraXBoostSamplesFilename(),
                PandoraXBoostBrokerTradesFilename());
  }
  PandoraXBoostLogEvent("PANDORA_XBOOST_SAVE",
                        StringFormat("samples=%s broker=%s stats=%s pending_before=%d broker_pending_before=%d pending_after=%d broker_pending_after=%d folder=%s stats_file=%s samples_file=%s broker_file=%s",
                                     samples_saved ? "OK" : "FAIL",
                                     broker_trades_saved ? "OK" : "FAIL",
                                     stats_saved ? "OK" : "FAIL",
                                     pending_before,
                                     pending_broker_before,
                                     ArraySize(g_pandora_xboost_pending_sample_rows),
                                     ArraySize(g_pandora_xboost_pending_broker_trade_rows),
                                     PandoraXBoostStorageAbsoluteFolder(),
                                     PandoraXBoostStatsFilename(),
                                     PandoraXBoostSamplesFilename(),
                                     PandoraXBoostBrokerTradesFilename()));

  return samples_saved && broker_trades_saved && stats_saved;
}

datetime PandoraXBoostResolveBrokerEntryTime(const SignalParams &signal_params)
{
  if(signal_params.pandora_broker_fill_time > 0)
    return signal_params.pandora_broker_fill_time;
  if(signal_params.pandora_local_entry_time > 0)
    return signal_params.pandora_local_entry_time;
  if(signal_params.entry_time > 0)
    return signal_params.entry_time;
  return TimeCurrent();
}

double PandoraXBoostResolveBrokerEntryPrice(const SignalParams &signal_params)
{
  if(signal_params.pandora_broker_fill_price > 0.0)
    return signal_params.pandora_broker_fill_price;
  if(signal_params.pandora_source_entry_price > 0.0)
    return signal_params.pandora_source_entry_price;
  if(signal_params.pandora_local_entry_price > 0.0)
    return signal_params.pandora_local_entry_price;
  return signal_params.entry_price;
}

datetime PandoraXBoostResolveBrokerCloseTime(const SignalParams &signal_params)
{
  if(signal_params.close_time > 0)
    return signal_params.close_time;
  if(signal_params.pandora_local_close_time > 0)
    return signal_params.pandora_local_close_time;
  return TimeCurrent();
}

double PandoraXBoostResolveBrokerClosePrice(const SignalParams &signal_params)
{
  if(signal_params.close_price > 0.0)
    return signal_params.close_price;
  return signal_params.pandora_local_close_price;
}

double PandoraXBoostResolveBrokerRMultiple(const SignalParams &signal_params,
                                           double &sl_points,
                                           double &entry_price,
                                           double &close_price)
{
  sl_points = PandoraResolveSignalSLPoints(signal_params, false);
  entry_price = PandoraXBoostResolveBrokerEntryPrice(signal_params);
  close_price = PandoraXBoostResolveBrokerClosePrice(signal_params);
  if(sl_points <= 0.0 || entry_price <= 0.0 || close_price <= 0.0)
    return 0.0;

  double point_size = PandoraResolvePointSizeSafe();
  if(point_size <= 0.0)
    return 0.0;

  double profit_points = 0.0;
  if(signal_params.signal_type == BULLISH)
    profit_points = (close_price - entry_price) / point_size;
  else if(signal_params.signal_type == BEARISH)
    profit_points = (entry_price - close_price) / point_size;
  else
    return 0.0;

  return profit_points / sl_points;
}

bool PandoraXBoostRecordBrokerTrade(SignalParams &signal_params,
                                    const string strategy_key,
                                    const datetime root_date,
                                    const string node_key,
                                    const string node_path,
                                    const string sample_id,
                                    const int depth,
                                    const PandoraXBoostCloseEvents close_event,
                                    const string close_label,
                                    const bool force_close)
{
  if(!signal_params.pandora_xboost_broker_selected)
    return false;
  if(signal_params.pandora_broker_execution_status != PANDORA_BROKER_EXECUTED &&
     signal_params.pandora_broker_execution_status != PANDORA_BROKER_CLOSED)
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADE_SKIP",
                          StringFormat("depth=%d id=%s reason=NOT_EXECUTED status=%s",
                                       depth,
                                       signal_params.pandora_xboost_display_id,
                                       PandoraBrokerExecutionStatusLabel(signal_params.pandora_broker_execution_status)));
    return false;
  }

  double sl_points = 0.0;
  double entry_price = 0.0;
  double close_price = 0.0;
  double r_multiple_broker =
    PandoraXBoostResolveBrokerRMultiple(signal_params,
                                        sl_points,
                                        entry_price,
                                        close_price);
  if(sl_points <= 0.0 || entry_price <= 0.0 || close_price <= 0.0)
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADE_SKIP",
                          StringFormat("depth=%d id=%s reason=INVALID_R_INPUTS sl=%.3f entry=%.5f close=%.5f",
                                       depth,
                                       signal_params.pandora_xboost_display_id,
                                       sl_points,
                                       entry_price,
                                       close_price));
    return false;
  }

  datetime entry_time = PandoraXBoostResolveBrokerEntryTime(signal_params);
  datetime close_time = PandoraXBoostResolveBrokerCloseTime(signal_params);
  string broker_trade_id = signal_params.pandora_xboost_broker_trade_id;
  if(broker_trade_id == "")
    broker_trade_id = PandoraXBoostBuildBrokerTradeId(strategy_key,
                                                      root_date,
                                                      node_path,
                                                      depth,
                                                      signal_params.pandora_xboost_broker_trade_index,
                                                      signal_params.signal_type,
                                                      entry_time);

  if(PandoraXBoostBrokerTradeIdExists(broker_trade_id))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADE_DUP",
                          StringFormat("depth=%d id=%s trade=%s",
                                       depth,
                                       signal_params.pandora_xboost_display_id,
                                       broker_trade_id));
    return false;
  }

  string close_reason = signal_params.pandora_observation_close_reason;
  if(close_reason == "")
    close_reason = force_close ? "force_close" : close_label;

  PandoraXBoostBrokerTradeRow trade_row;
  trade_row.broker_trade_id = broker_trade_id;
  trade_row.strategy_key = strategy_key;
  trade_row.root_id = signal_params.pandora_xboost_root_id;
  trade_row.root_date = root_date;
  trade_row.node_key = node_key;
  trade_row.node_path = node_path;
  trade_row.sample_id = sample_id;
  trade_row.depth = depth;
  trade_row.broker_trade_index = signal_params.pandora_xboost_broker_trade_index;
  trade_row.side = signal_params.signal_type;
  trade_row.entry_time = entry_time;
  trade_row.close_time = close_time;
  trade_row.entry_price = entry_price;
  trade_row.close_price = close_price;
  trade_row.sl_points = sl_points;
  trade_row.r_multiple_broker = r_multiple_broker;
  trade_row.net_profit = signal_params.raw_profit;
  trade_row.close_event = close_event;
  trade_row.close_reason = close_reason;
  trade_row.model_score_r = signal_params.pandora_xboost_model_score_r;
  trade_row.model_posterior_r = signal_params.pandora_xboost_model_posterior_r;
  trade_row.model_samples = signal_params.pandora_xboost_model_samples;
  trade_row.broker_window_samples =
    signal_params.pandora_xboost_broker_window_samples;
  trade_row.seen_at = TimeCurrent();

  if(!PandoraXBoostAppendPendingBrokerTradeRow(trade_row))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADE_APPEND_FAIL",
                          StringFormat("depth=%d id=%s trade=%s",
                                       depth,
                                       signal_params.pandora_xboost_display_id,
                                       broker_trade_id));
    return false;
  }

  signal_params.pandora_xboost_broker_trade_id = broker_trade_id;
  PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_TRADE_RECORDED",
                        StringFormat("depth=%d trade=%d id=%s r=%.3f sample=%s broker_id=%s",
                                     depth,
                                     signal_params.pandora_xboost_broker_trade_index,
                                     signal_params.pandora_xboost_display_id,
                                     r_multiple_broker,
                                     sample_id,
                                     broker_trade_id));
  return true;
}

bool PandoraXBoostRecordClosedSignal(SignalParams &signal_params,
                                     const bool force_close)
{
  if(!PandoraXBoostEnabled())
    return false;
  if(!IsPandoraSignal(signal_params))
    return false;
  if(!signal_params.pandora_xboost_enabled)
    return false;

  string strategy_key = signal_params.pandora_xboost_strategy_key;
  if(strategy_key == "")
    strategy_key = PandoraXBoostBuildStrategyKey();

  SignalTypes root_side = signal_params.pandora_xboost_root_side;
  if(root_side == NO_SIGNAL)
    root_side = signal_params.signal_type;

  datetime root_date = g_pandora_box_state.day_anchor;
  if(root_date <= 0)
    root_date = ResolveCurrentDayStart();

  int depth = signal_params.pandora_xboost_depth;
  if(depth <= 0)
    depth = 1;

  PandoraXBoostCloseEvents parent_event = signal_params.pandora_xboost_parent_event;
  if(parent_event == PANDORA_XBOOST_EVENT_NONE)
    parent_event = PandoraXBoostRootEventForDirection(root_side);

  int event_step_index = signal_params.pandora_trailing_step_index;
  if(event_step_index < 0)
    event_step_index = 0;
  string node_key = signal_params.pandora_xboost_node_key;
  if(node_key == "")
  {
    node_key = PandoraXBoostBuildNodeKey(strategy_key,
                                         root_side,
                                         parent_event,
                                         depth,
                                         signal_params.signal_type,
                                         event_step_index,
                                         signal_params.pandora_xboost_node_path);
  }

  PandoraXBoostCloseEvents close_event = PandoraXBoostResolveCloseEvent(signal_params,
                                                                        force_close);
  signal_params.pandora_xboost_close_event = close_event;
  PandoraXBoostReleaseBrokerAfterClose(signal_params);
  if(close_event == PANDORA_XBOOST_EVENT_NONE)
    return false;

  double r_multiple = PandoraXBoostResolveSignalRMultiple(signal_params);
  string close_label = PandoraXBoostCloseEventLabel(close_event, event_step_index);
  string sample_path = signal_params.pandora_xboost_node_path;
  if(sample_path == "")
    sample_path = node_key;
  string sample_id = PandoraXBoostBuildSampleId(strategy_key,
                                                root_date,
                                                sample_path,
                                                depth,
                                                signal_params.signal_type,
                                                close_event,
                                                event_step_index);
  if(PandoraXBoostSampleIdExists(sample_id))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLE_DUP",
                          StringFormat("depth=%d id=%s",
                                       depth,
                                       sample_id));
    return false;
  }

  string row = StringFormat("%s,%s,%s,%.8f,%I64d",
                            sample_id,
                            node_key,
                            close_label,
                            r_multiple,
                            (long)TimeCurrent());
  if(!PandoraXBoostAppendPendingSampleRow(sample_id, row))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLE_APPEND_FAIL",
                          StringFormat("depth=%d id=%s",
                                       depth,
                                       sample_id));
    return false;
  }

  PandoraXBoostUpdateStats(node_key, r_multiple, TimeCurrent());
  signal_params.pandora_xboost_sample_id = sample_id;
  signal_params.pandora_xboost_node_key = node_key;
  PandoraXBoostRecordBrokerTrade(signal_params,
                                 strategy_key,
                                 root_date,
                                 node_key,
                                 sample_path,
                                 sample_id,
                                 depth,
                                 close_event,
                                 close_label,
                                 force_close);
  PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLE_RECORDED",
                        StringFormat("depth=%d id=%s date=%s close=%s r=%.3f model=%s sample=%s",
                                     depth,
                                     signal_params.pandora_xboost_display_id,
                                     PandoraXBoostDateKey(root_date),
                                     close_label,
                                     r_multiple,
                                     node_key,
                                     sample_id));
  if(!PandoraXBoostSave())
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_SAMPLE_SAVE_FAIL",
                          StringFormat("depth=%d id=%s",
                                       depth,
                                       sample_id));
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_
