//+------------------------------------------------------------------+
//|                          microservices/utils/file_logger.mqh    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_FILE_LOGGER_MQH_
#define _MICROSERVICES_UTILS_FILE_LOGGER_MQH_

const int FILE_LOG_FLUSH_LINES = 128;
int g_file_log_handle = INVALID_HANDLE;
string g_file_log_filename = "";
int g_file_log_pending_lines = 0;

void CloseAppendFileLog()
{
  if(g_file_log_handle != INVALID_HANDLE)
  {
    FileFlush(g_file_log_handle);
    FileClose(g_file_log_handle);
  }
  g_file_log_handle = INVALID_HANDLE;
  g_file_log_filename = "";
  g_file_log_pending_lines = 0;
}

bool EnsureAppendFileLogOpen(const string filename)
{
  if(g_file_log_handle != INVALID_HANDLE && g_file_log_filename == filename)
    return true;

  CloseAppendFileLog();
  g_file_log_handle = FileOpen(filename,
                               FILE_WRITE | FILE_READ | FILE_TXT | FILE_COMMON |
                               FILE_ANSI | FILE_SHARE_READ);
  if(g_file_log_handle == INVALID_HANDLE)
    return false;

  FileSeek(g_file_log_handle, 0, SEEK_END);
  g_file_log_filename = filename;
  return true;
}

bool AppendFileLog(const string filename, const string line)
{
  if(filename == "")
    return false;
  if(!EnsureAppendFileLogOpen(filename))
    return false;

  if(FileWrite(g_file_log_handle, line) == 0)
  {
    CloseAppendFileLog();
    return false;
  }

  g_file_log_pending_lines++;
  if(g_file_log_pending_lines >= FILE_LOG_FLUSH_LINES)
  {
    FileFlush(g_file_log_handle);
    g_file_log_pending_lines = 0;
  }
  return true;
}

bool AppendTimestampedLogAt(const string filename,
                            const string label,
                            const string message,
                            const datetime event_time)
{
  datetime timestamp = event_time > 0 ? event_time : TimeCurrent();
  string line = StringFormat("%s | %s | %s",
                             TimeToString(timestamp, TIME_DATE | TIME_SECONDS),
                             label,
                             message);
  return AppendFileLog(filename, line);
}

bool AppendTimestampedLog(const string filename,
                          const string label,
                          const string message)
{
  return AppendTimestampedLogAt(filename, label, message, TimeCurrent());
}

#endif // _MICROSERVICES_UTILS_FILE_LOGGER_MQH_
