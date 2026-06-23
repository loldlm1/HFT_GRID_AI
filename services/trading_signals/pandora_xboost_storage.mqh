//+------------------------------------------------------------------+
//|                     pandora_xboost_storage.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_

const string PANDORA_XBOOST_STATS_HEADER =
  "node_key,key_hash,samples,wins,losses,be,total_r,avg_r,avg_win_r,avg_loss_r,max_win_r,max_loss_r,max_drawdown_r,expectancy_r,last_seen";
const string PANDORA_XBOOST_SAMPLES_HEADER =
  "sample_id,node_key,close_event,r_multiple,seen_at";

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
  return StringFormat("pandora_xboost_v%d_%s_%s_%d",
                      PANDORA_XBOOST_SCHEMA_VERSION,
                      PandoraXBoostSanitizeFilePart(Pandora_XBoost_Strategy_Id),
                      PandoraXBoostSanitizeFilePart(_Symbol),
                      (int)_Period);
}

string PandoraXBoostStatsFilename()
{
  return PandoraXBoostFilePrefix() + "_stats.csv";
}

string PandoraXBoostSamplesFilename()
{
  return PandoraXBoostFilePrefix() + "_samples.csv";
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
  g_pandora_xboost_storage_loaded = false;
  g_pandora_xboost_storage_dirty = false;
  g_pandora_xboost_storage_load_time = 0;
}

bool PandoraXBoostLoadStats()
{
  string filename = PandoraXBoostStatsFilename();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
  if(handle == INVALID_HANDLE)
    return true;

  bool header_seen = false;
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
    stats.key_hash       = (ulong)StringToInteger(fields[1]);
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
  }

  FileClose(handle);
  return true;
}

bool PandoraXBoostLoadSampleIds()
{
  string filename = PandoraXBoostSamplesFilename();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
  if(handle == INVALID_HANDLE)
    return true;

  bool header_seen = false;
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

    PandoraXBoostRememberSampleId(fields[0]);
  }

  FileClose(handle);
  return true;
}

bool PandoraXBoostLoad()
{
  PandoraXBoostClearStorageMemory();
  if(!PandoraXBoostEnabled())
    return true;

  bool stats_loaded = PandoraXBoostLoadStats();
  bool samples_loaded = PandoraXBoostLoadSampleIds();
  g_pandora_xboost_storage_loaded = stats_loaded && samples_loaded;
  g_pandora_xboost_storage_load_time = TimeCurrent();

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_LOAD mode=%s stats=%d samples=%d prefix=%s",
                PandoraXBoostModeLabel(Pandora_XBoost_Mode),
                ArraySize(g_pandora_xboost_stats),
                ArraySize(g_pandora_xboost_sample_ids),
                PandoraXBoostFilePrefix());
  }

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
  string filename = PandoraXBoostStatsFilename();
  int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
  if(handle == INVALID_HANDLE)
    return false;

  FileWrite(handle, PANDORA_XBOOST_STATS_HEADER);
  int total = ArraySize(g_pandora_xboost_stats);
  for(int i = 0; i < total; i++)
    FileWrite(handle, PandoraXBoostFormatStatsRow(g_pandora_xboost_stats[i]));

  FileClose(handle);
  return true;
}

bool PandoraXBoostFlushPendingSamples()
{
  int total = ArraySize(g_pandora_xboost_pending_sample_rows);
  if(total <= 0)
    return true;

  string filename = PandoraXBoostSamplesFilename();
  bool needs_header = !FileIsExist(filename);
  int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
  if(handle == INVALID_HANDLE)
    return false;

  FileSeek(handle, 0, SEEK_END);
  if(needs_header)
    FileWrite(handle, PANDORA_XBOOST_SAMPLES_HEADER);

  for(int i = 0; i < total; i++)
    FileWrite(handle, g_pandora_xboost_pending_sample_rows[i]);

  FileClose(handle);
  ArrayResize(g_pandora_xboost_pending_sample_rows, 0, 0);
  return true;
}

bool PandoraXBoostSave()
{
  if(!PandoraXBoostEnabled())
    return true;

  bool samples_saved = PandoraXBoostFlushPendingSamples();
  bool stats_saved = PandoraXBoostSaveStatsSnapshot();
  if(samples_saved && stats_saved)
    g_pandora_xboost_storage_dirty = false;

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_SAVE samples=%s stats=%s prefix=%s",
                samples_saved ? "OK" : "FAIL",
                stats_saved ? "OK" : "FAIL",
                PandoraXBoostFilePrefix());
  }

  return samples_saved && stats_saved;
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STORAGE_MQH_
