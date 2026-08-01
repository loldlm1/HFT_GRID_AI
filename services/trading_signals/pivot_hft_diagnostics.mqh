//+------------------------------------------------------------------+
//|                    pivot_hft_diagnostics.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_

const string PIVOT_HFT_AUDIT_FILENAME = "query_debug.txt";
string g_pivot_hft_audit_run_id = "";
bool   g_pivot_hft_audit_initialized = false;
bool   g_pivot_hft_audit_failure_warned = false;
int    g_pivot_hft_audit_handle = INVALID_HANDLE;

string PivotHftAuditFilePath()
{
  string common_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
  if(common_path == "")
    return PIVOT_HFT_AUDIT_FILENAME;
  return common_path + "\\Files\\" + PIVOT_HFT_AUDIT_FILENAME;
}

string PivotHftAuditRunPrefix()
{
  string run_id = g_pivot_hft_audit_run_id;
  if(run_id == "")
    run_id = "uninitialized";

  return StringFormat("run=%s|symbol=%s|magic=%I64d",
                      run_id,
                      _Symbol,
                      g_magic_number);
}

string PivotHftBuildAuditRunId()
{
  return StringFormat("%I64d_%I64d_%I64u_%I64u",
                      (long)TimeCurrent(),
                      (long)ChartID(),
                      GetTickCount64(),
                      GetMicrosecondCount());
}

bool PivotHftAuditEnsureFileOpen()
{
  if(g_pivot_hft_audit_handle != INVALID_HANDLE)
    return true;

  g_pivot_hft_audit_handle = OpenAppendFileLog(PIVOT_HFT_AUDIT_FILENAME);
  return (g_pivot_hft_audit_handle != INVALID_HANDLE);
}

bool PivotHftAuditWriteLine(const string label,
                            const string scoped_message,
                            int &failure_error)
{
  failure_error = 0;
  string line = StringFormat("%s | %s | %s",
                             TimeToString(TimeCurrent(),
                                          TIME_DATE | TIME_SECONDS),
                             label,
                             scoped_message);
  if(PivotHftAuditEnsureFileOpen() &&
     AppendOpenFileLog(g_pivot_hft_audit_handle, line, true))
    return true;

  failure_error = GetLastError();
  CloseAppendFileLog(g_pivot_hft_audit_handle);
  if(PivotHftAuditEnsureFileOpen() &&
     AppendOpenFileLog(g_pivot_hft_audit_handle, line, true))
    return true;

  int retry_error = GetLastError();
  if(retry_error != 0)
    failure_error = retry_error;
  CloseAppendFileLog(g_pivot_hft_audit_handle);
  return false;
}

void PivotHftAuditLog(const string label, const string message)
{
  if(!Enable_File_Logs)
    return;

  string scoped_message = PivotHftAuditRunPrefix();
  if(message != "")
    scoped_message += "|" + message;

  int failure_error = 0;
  if(PivotHftAuditWriteLine(label, scoped_message, failure_error))
    return;

  if(g_pivot_hft_audit_failure_warned)
    return;

  g_pivot_hft_audit_failure_warned = true;
  PrintFormat("Pivot HFT file log failed | path=%s | err=%d",
              PivotHftAuditFilePath(),
              failure_error);
}

void PivotHftAuditInitialize()
{
  CloseAppendFileLog(g_pivot_hft_audit_handle);
  g_pivot_hft_audit_run_id = "";
  g_pivot_hft_audit_initialized = false;
  g_pivot_hft_audit_failure_warned = false;
  if(!Enable_File_Logs)
    return;

  g_pivot_hft_audit_run_id = PivotHftBuildAuditRunId();
  g_pivot_hft_audit_initialized = true;

  PrintFormat("Pivot HFT file logging enabled | path=%s | run=%s",
              PivotHftAuditFilePath(),
              g_pivot_hft_audit_run_id);
  PivotHftAuditLog("RUN_START",
                   StringFormat("tester=%d|visual=%d|chart_tf=%s|writer=shared_append",
                                (int)MQLInfoInteger(MQL_TESTER),
                                (int)MQLInfoInteger(MQL_VISUAL_MODE),
                                EnumToString((ENUM_TIMEFRAMES)_Period)));
}

void PivotHftAuditShutdown(const int reason)
{
  if(Enable_File_Logs && g_pivot_hft_audit_initialized)
    PivotHftAuditLog("RUN_END", StringFormat("deinit_reason=%d", reason));

  CloseAppendFileLog(g_pivot_hft_audit_handle);
  g_pivot_hft_audit_initialized = false;
  g_pivot_hft_audit_run_id = "";
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
