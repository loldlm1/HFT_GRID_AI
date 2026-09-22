#ifndef CANDLE_EXPORT_MQH
#define CANDLE_EXPORT_MQH

int g_candle_files[CANDLE_FILE_COUNT];
long g_candle_rows[CANDLE_FILE_COUNT];
bool g_candle_export_open = false;
bool g_candle_export_failed = false;
bool g_candle_sealed = false;
string g_candle_failure = "";
string g_candle_root = "";
long g_candle_last_time = 0;

void CandleExportFail(const string reason)
{
  if(g_candle_export_failed) return;
  g_candle_export_failed = true;
  g_candle_failure = reason;
  PrintFormat("CANDLE_RESEARCH_FAILED | run=%s | time_msc=%I64d | %s",
              Signal_Feature_Run_Id, g_candle_last_time, reason);
  if(g_candle_export_open)
  {
    // A separate failure marker invalidates an earlier seal if its final flush fails.
    int marker = FileOpen(g_candle_root + "FAILED.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
    if(marker != INVALID_HANDLE)
    {
      if(FileWriteString(marker, reason + "\r\n") == 0) Print("CANDLE_FAILURE_MARKER_WRITE_FAILED");
      FileClose(marker);
    }
  }
}

bool CandleWrite(const int file, const string row, const bool sealing = false)
{
  if(!Enable_Signal_Feature_Export || !g_candle_export_open) return false;
  if((g_candle_export_failed && !sealing) || file < 0 || file >= CANDLE_FILE_COUNT ||
     g_candle_files[file] == INVALID_HANDLE) return false;
  string fields[], headers[];
  if(StringSplit(row, '\t', fields) != StringSplit(CandleHeader(file), '\t', headers))
  {
    CandleExportFail("COLUMN_COUNT_" + CandleFileName(file));
    return false;
  }
  if(!FileIsExist(g_candle_root + CandleFileName(file), FILE_COMMON))
  {
    CandleExportFail("MISSING_FILE_" + CandleFileName(file));
    return false;
  }
  string text = row + "\r\n";
  uchar encoded[];
  int bytes = StringToCharArray(text, encoded, 0, WHOLE_ARRAY, CP_UTF8);
  if(bytes <= 1)
  {
    CandleExportFail("ENCODE_" + CandleFileName(file));
    return false;
  }
  ResetLastError();
  uint written = FileWriteString(g_candle_files[file], text);
  if(written != (uint)(bytes - 1) || GetLastError() != 0)
  {
    CandleExportFail("WRITE_" + CandleFileName(file));
    return false;
  }
  g_candle_rows[file]++;
  if(g_candle_rows[file] % 128 == 0)
  {
    ResetLastError();
    FileFlush(g_candle_files[file]);
    if(GetLastError() != 0) CandleExportFail("FLUSH_" + CandleFileName(file));
  }
  return !g_candle_export_failed || sealing;
}

bool CandleManifest(const string key, const string value)
{
  return CandleWrite(CANDLE_MANIFEST, key + "\t" + value);
}

bool CandleRunIdValid()
{
  int length = StringLen(Signal_Feature_Run_Id);
  if(length < 1 || length > 64 || StringFind(Signal_Feature_Run_Id, "..") >= 0)
    return false;
  for(int i = 0; i < length; i++)
  {
    ushort c = StringGetCharacter(Signal_Feature_Run_Id, i);
    if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false;
  }
  return StringGetCharacter(Signal_Feature_Run_Id, 0) != '.';
}

void CandleCloseFiles()
{
  for(int i = 0; i < CANDLE_FILE_COUNT; i++)
  {
    if(g_candle_files[i] != INVALID_HANDLE) FileClose(g_candle_files[i]);
    g_candle_files[i] = INVALID_HANDLE;
  }
  g_candle_export_open = false;
}

bool CandleOpenExport()
{
  ArrayInitialize(g_candle_files, INVALID_HANDLE);
  ArrayInitialize(g_candle_rows, 0);
  if(!Enable_Signal_Feature_Export) return true;
  if(!CandleRunIdValid())
  {
    Print("Candle export requires a new, safe run ID of 1-64 characters.");
    return false;
  }
  g_candle_root = "CandlePatternV1\\runs\\" + Signal_Feature_Run_Id + "\\";
  string found;
  long search = FileFindFirst(g_candle_root + "*", found, FILE_COMMON);
  if(search != INVALID_HANDLE)
  {
    FileFindClose(search);
    Print("Candle export refuses an existing non-empty run directory.");
    return false;
  }
  for(int i = 0; i < CANDLE_FILE_COUNT; i++)
  {
    g_candle_files[i] = FileOpen(g_candle_root + CandleFileName(i),
                               FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ,
                               0, CP_UTF8);
    if(g_candle_files[i] == INVALID_HANDLE)
    {
      CandleExportFail("OPEN_" + CandleFileName(i));
      CandleCloseFiles();
      return false;
    }
    string header = CandleHeader(i) + "\r\n";
    if(FileWriteString(g_candle_files[i], header) != (uint)StringLen(header))
    {
      CandleExportFail("HEADER_" + CandleFileName(i));
      CandleCloseFiles();
      return false;
    }
  }
  g_candle_export_open = true;
  CandleManifest("schema_version", "1");
  CandleManifest("engine", "CANDLE_PATTERN_ATR_V1");
  CandleManifest("feature_set", "candle_pattern_macro_micro_v1");
  CandleManifest("run_id", Signal_Feature_Run_Id);
  CandleManifest("symbol", _Symbol);
  CandleManifest("macro_seconds", CandleInteger(g_macro_seconds));
  CandleManifest("micro_seconds", CandleInteger(g_micro_seconds));
  CandleManifest("atr_period", "13");
  CandleManifest("atr_shift", "1");
  CandleManifest("atr_multiplier", "1");
  CandleManifest("lot_size", CandleNumber(Lot_Strategy_Size));
  CandleManifest("point", CandleNumber(_Point));
  CandleManifest("tick_size", CandleNumber(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)));
  CandleManifest("currency", AccountInfoString(ACCOUNT_CURRENCY));
  CandleManifest("ratios", "1,2,3");
  CandleManifest("protection", "FIXED_SUBMITTED");
  CandleManifest("expiry", "ENTRY_PLUS_MACRO");
  CandleManifest("allowance", "BROKER_MACRO_CANDLE");
  CandleManifest("categories", "PATTERN_AND_RELATIONSHIP");
  CandleManifest("reentry", "BROKER_SL_ONCE");
  CandleManifest("broker_cap", CandleInteger(CANDLE_BROKER_CAP));
  CandleManifest("virtual_cap", CandleInteger(CANDLE_VIRTUAL_CAP));
  return !g_candle_export_failed;
}

void CandleSummary(const string key, const string value)
{
  CandleWrite(CANDLE_SUMMARY, key + "\t" + value, true);
}

void CandleSealExport(const int broker_peak, const int virtual_peak)
{
  if(!g_candle_export_open || g_candle_sealed) return;
  g_candle_sealed = true;
  for(int i = 0; i < CANDLE_FILE_COUNT; i++)
  {
    ResetLastError();
    FileFlush(g_candle_files[i]);
    if(GetLastError() != 0) CandleExportFail("FINAL_FLUSH_" + CandleFileName(i));
    int check = FileOpen(g_candle_root + CandleFileName(i),
                         FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE,
                         0, CP_UTF8);
    if(check == INVALID_HANDLE) CandleExportFail("VERIFY_" + CandleFileName(i));
    else
    {
      if(FileReadString(check) != CandleHeader(i)) CandleExportFail("CHANGED_HEADER_" + CandleFileName(i));
      FileClose(check);
    }
  }
  for(int i = 0; i < CANDLE_FILE_COUNT - 1; i++)
    CandleSummary("rows_" + CandleFileName(i), CandleInteger(g_candle_rows[i]));
  CandleSummary("broker_peak", CandleInteger(broker_peak));
  CandleSummary("virtual_peak", CandleInteger(virtual_peak));
  CandleSummary("last_time_msc", CandleInteger(g_candle_last_time));
  CandleSummary("failure", g_candle_failure == "" ? "NONE" : g_candle_failure);
  CandleSummary("completion", g_candle_export_failed ? "CENSORED" : "NATURAL");
  CandleSummary("status", g_candle_export_failed ? "FAILED" : "OK");
  ResetLastError();
  FileFlush(g_candle_files[CANDLE_SUMMARY]);
  if(GetLastError() != 0) CandleExportFail("SUMMARY_FLUSH");
  CandleCloseFiles();
}

#endif
