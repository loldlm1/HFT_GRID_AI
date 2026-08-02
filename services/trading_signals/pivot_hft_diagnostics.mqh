//+------------------------------------------------------------------+
//|                    pivot_hft_diagnostics.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_

const string PIVOT_HFT_AUDIT_FILENAME = "query_debug.txt";
const int    PIVOT_HFT_AUDIT_SCHEMA_VERSION = 3;
const int    PIVOT_HFT_AUDIT_SUMMARY_VERSION = 1;
const int    PIVOT_HFT_AUDIT_COUNTER_MAX = 2147483647;
const string PIVOT_HFT_BROKER_COMMENT_PREFIX = "PH2";
const int    PIVOT_HFT_BROKER_COMMENT_MAX_LENGTH = 31;

struct PivotHftAuditCounters
{
  int events_counted;
  int initial_broker_fills;
  int virtual_retry_fills;
  int broker_retry_fills;
  int broker_fills_total;
  int normal_managed_fills;
  int emergency_managed_fills;
  int position_finalizations;
  int candidates_latched;
  int candidates_replaced;
  int candidates_discarded;
  int candidates_promoted;
  int retries_suppressed;
  int recovery_restores;
  int recovery_quarantines;
  int emergency_closes;
  int emergency_reconciled;
  int reconciliation_failures;
  int audit_write_failures;

  PivotHftAuditCounters()
    : events_counted(0),
      initial_broker_fills(0),
      virtual_retry_fills(0),
      broker_retry_fills(0),
      broker_fills_total(0),
      normal_managed_fills(0),
      emergency_managed_fills(0),
      position_finalizations(0),
      candidates_latched(0),
      candidates_replaced(0),
      candidates_discarded(0),
      candidates_promoted(0),
      retries_suppressed(0),
      recovery_restores(0),
      recovery_quarantines(0),
      emergency_closes(0),
      emergency_reconciled(0),
      reconciliation_failures(0),
      audit_write_failures(0)
  {
  }
};

string g_pivot_hft_audit_run_id = "";
bool   g_pivot_hft_audit_initialized = false;
bool   g_pivot_hft_audit_failure_warned = false;
int    g_pivot_hft_audit_handle = INVALID_HANDLE;
PivotHftAuditCounters g_pivot_hft_audit_counters;

void PivotHftAuditIncrementCounter(int &counter)
{
  if(counter < PIVOT_HFT_AUDIT_COUNTER_MAX)
    counter++;
}

int PivotHftAuditMessageInt(const string message,
                            const string key,
                            const int fallback = -1)
{
  string marker = key + "=";
  int value_start = -1;
  if(StringFind(message, marker) == 0)
  {
    value_start = StringLen(marker);
  }
  else
  {
    marker = "|" + key + "=";
    int marker_start = StringFind(message, marker);
    if(marker_start < 0)
      return fallback;
    value_start = marker_start + StringLen(marker);
  }
  int value_end = StringFind(message, "|", value_start);
  string value = (value_end < 0)
                 ? StringSubstr(message, value_start)
                 : StringSubstr(message,
                                value_start,
                                value_end - value_start);
  if(value == "")
    return fallback;
  long parsed = StringToInteger(value);
  if(parsed < 0 || parsed > PIVOT_HFT_AUDIT_COUNTER_MAX)
    return fallback;
  return (int)parsed;
}

void PivotHftAuditObserveEvent(const string label,
                               const string message)
{
  if(label == "RUN_SUMMARY" || label == "RUN_END")
    return;

  PivotHftAuditIncrementCounter(
    g_pivot_hft_audit_counters.events_counted);
  if(label == "BROKER_FILL_ACCOUNTED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.broker_fills_total);
    int retry_number = PivotHftAuditMessageInt(message,
                                               "retry_number");
    if(retry_number == 0)
    {
      PivotHftAuditIncrementCounter(
        g_pivot_hft_audit_counters.initial_broker_fills);
    }
    else if(retry_number > 0)
    {
      PivotHftAuditIncrementCounter(
        g_pivot_hft_audit_counters.broker_retry_fills);
    }
  }
  else if(label == "VIRTUAL_FILL_REGISTERED")
  {
    int retry_number = PivotHftAuditMessageInt(message,
                                               "retry_number");
    if(retry_number > 0)
    {
      PivotHftAuditIncrementCounter(
        g_pivot_hft_audit_counters.virtual_retry_fills);
    }
  }
  else if(label == "FILL_REGISTERED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.normal_managed_fills);
  }
  else if(label == "FILL_REGISTRATION_FAILED" ||
          label == "FILL_RECOVERY_CHECKPOINT_FAILED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.emergency_managed_fills);
  }
  else if(label == "POSITION_FINALIZED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.position_finalizations);
  }
  else if(label == "CANDIDATE_LATCHED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.candidates_latched);
  }
  else if(label == "CANDIDATE_REPLACED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.candidates_replaced);
  }
  else if(label == "CANDIDATE_DISCARDED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.candidates_discarded);
  }
  else if(label == "CANDIDATE_PROMOTED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.candidates_promoted);
  }
  else if(label == "RETRY_SUPERSEDED" ||
          label == "RETRY_CAMPAIGN_SUPERSEDED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.retries_suppressed);
  }
  else if(label == "RECOVERY_POSITION_RESTORED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.recovery_restores);
  }
  else if(label == "RECOVERY_POSITION_QUARANTINED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.recovery_quarantines);
  }
  else if(label == "EMERGENCY_CLOSE_SENT")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.emergency_closes);
  }
  else if(label == "EMERGENCY_EXPOSURE_RECONCILED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.emergency_reconciled);
  }

  if(label == "FILL_RECOVERY_CHECKPOINT_FAILED" ||
     label == "RECOVERY_STORAGE_FAILURE" ||
     label == "RECOVERY_QUARANTINE_STATE_FAILED" ||
     label == "PROTECTION_CLOSE_FAILED" ||
     label == "VIRTUAL_FILL_UNRESOLVED" ||
     label == "VIRTUAL_LIFECYCLE_ABORTED")
  {
    PivotHftAuditIncrementCounter(
      g_pivot_hft_audit_counters.reconciliation_failures);
  }
}

string PivotHftAuditSummaryFields()
{
  return StringFormat("summary_version=%d|events_counted=%d|initial_broker_fills=%d|virtual_retry_fills=%d|broker_retry_fills=%d|broker_fills_total=%d|normal_managed_fills=%d|emergency_managed_fills=%d|position_finalizations=%d|candidates_latched=%d|candidates_replaced=%d|candidates_discarded=%d|candidates_promoted=%d|retries_suppressed=%d|recovery_restores=%d|recovery_quarantines=%d|emergency_closes=%d|emergency_reconciled=%d|reconciliation_failures=%d|audit_write_failures=%d",
                      PIVOT_HFT_AUDIT_SUMMARY_VERSION,
                      g_pivot_hft_audit_counters.events_counted,
                      g_pivot_hft_audit_counters.initial_broker_fills,
                      g_pivot_hft_audit_counters.virtual_retry_fills,
                      g_pivot_hft_audit_counters.broker_retry_fills,
                      g_pivot_hft_audit_counters.broker_fills_total,
                      g_pivot_hft_audit_counters.normal_managed_fills,
                      g_pivot_hft_audit_counters.emergency_managed_fills,
                      g_pivot_hft_audit_counters.position_finalizations,
                      g_pivot_hft_audit_counters.candidates_latched,
                      g_pivot_hft_audit_counters.candidates_replaced,
                      g_pivot_hft_audit_counters.candidates_discarded,
                      g_pivot_hft_audit_counters.candidates_promoted,
                      g_pivot_hft_audit_counters.retries_suppressed,
                      g_pivot_hft_audit_counters.recovery_restores,
                      g_pivot_hft_audit_counters.recovery_quarantines,
                      g_pivot_hft_audit_counters.emergency_closes,
                      g_pivot_hft_audit_counters.emergency_reconciled,
                      g_pivot_hft_audit_counters.reconciliation_failures,
                      g_pivot_hft_audit_counters.audit_write_failures);
}

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

  PivotHftAuditObserveEvent(label, message);
  string scoped_message = PivotHftAuditRunPrefix();
  if(message != "")
    scoped_message += "|" + message;

  int failure_error = 0;
  if(PivotHftAuditWriteLine(label, scoped_message, failure_error))
    return;

  PivotHftAuditIncrementCounter(
    g_pivot_hft_audit_counters.audit_write_failures);
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
  g_pivot_hft_audit_counters = PivotHftAuditCounters();
  if(!Enable_File_Logs)
    return;

  g_pivot_hft_audit_run_id = PivotHftBuildAuditRunId();
  g_pivot_hft_audit_initialized = true;

  PrintFormat("Pivot HFT file logging enabled | path=%s | run=%s",
              PivotHftAuditFilePath(),
              g_pivot_hft_audit_run_id);
  PivotHftAuditLog("RUN_START",
                   StringFormat("schema_version=%d|tester=%d|tester_visual_mode=%d|chart_tf=%s|writer=shared_append|retry_identity=logical|broker_comment_schema=%s|recovery_scope_metadata=status_only",
                                PIVOT_HFT_AUDIT_SCHEMA_VERSION,
                                (int)MQLInfoInteger(MQL_TESTER),
                                (int)MQLInfoInteger(MQL_VISUAL_MODE),
                                EnumToString((ENUM_TIMEFRAMES)_Period),
                                PIVOT_HFT_BROKER_COMMENT_PREFIX));
}

void PivotHftAuditShutdown(const int reason)
{
  if(Enable_File_Logs && g_pivot_hft_audit_initialized)
  {
    PivotHftAuditLog("RUN_SUMMARY", PivotHftAuditSummaryFields());
    PivotHftAuditLog("RUN_END", StringFormat("deinit_reason=%d", reason));
  }

  CloseAppendFileLog(g_pivot_hft_audit_handle);
  g_pivot_hft_audit_initialized = false;
  g_pivot_hft_audit_run_id = "";
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DIAGNOSTICS_MQH_
