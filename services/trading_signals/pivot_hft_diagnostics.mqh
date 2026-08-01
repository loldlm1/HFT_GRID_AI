//+------------------------------------------------------------------+
//|                    pivot_hft_diagnostics.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_

const string PIVOT_HFT_AUDIT_FILENAME = "query_debug.txt";
string g_pivot_hft_audit_run_id = "";
bool   g_pivot_hft_audit_initialized = false;
bool   g_pivot_hft_audit_failure_warned = false;

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

void PivotHftAuditLog(const string label, const string message)
{
  if(!Enable_File_Logs)
    return;

  string scoped_message = PivotHftAuditRunPrefix();
  if(message != "")
    scoped_message += "|" + message;

  ResetLastError();
  if(AppendTimestampedLog(PIVOT_HFT_AUDIT_FILENAME,
                          label,
                          scoped_message))
    return;

  if(g_pivot_hft_audit_failure_warned)
    return;

  g_pivot_hft_audit_failure_warned = true;
  PrintFormat("Pivot HFT file log failed | path=%s | err=%d",
              PivotHftAuditFilePath(),
              GetLastError());
}

void PivotHftAuditInitialize()
{
  if(!Enable_File_Logs)
    return;

  g_pivot_hft_audit_run_id = StringFormat("%I64d_%I64d",
                                           (long)TimeCurrent(),
                                           (long)ChartID());
  g_pivot_hft_audit_initialized = true;
  g_pivot_hft_audit_failure_warned = false;

  PrintFormat("Pivot HFT file logging enabled | path=%s | run=%s",
              PivotHftAuditFilePath(),
              g_pivot_hft_audit_run_id);
  PivotHftAuditLog("RUN_START",
                   StringFormat("tester=%d|visual=%d|chart_tf=%s",
                                (int)MQLInfoInteger(MQL_TESTER),
                                (int)MQLInfoInteger(MQL_VISUAL_MODE),
                                EnumToString((ENUM_TIMEFRAMES)_Period)));
}

void PivotHftAuditShutdown(const int reason)
{
  if(!Enable_File_Logs || !g_pivot_hft_audit_initialized)
    return;

  PivotHftAuditLog("RUN_END", StringFormat("deinit_reason=%d", reason));
  g_pivot_hft_audit_initialized = false;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
