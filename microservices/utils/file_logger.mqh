//+------------------------------------------------------------------+
//|                          microservices/utils/file_logger.mqh    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_FILE_LOGGER_MQH_
#define _MICROSERVICES_UTILS_FILE_LOGGER_MQH_

int OpenAppendFileLog(const string filename)
{
  if(filename == "")
    return INVALID_HANDLE;

  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_WRITE | FILE_READ | FILE_TXT | FILE_COMMON |
                        FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE);
  if(handle == INVALID_HANDLE)
    return INVALID_HANDLE;

  if(!FileSeek(handle, 0, SEEK_END))
  {
    FileClose(handle);
    return INVALID_HANDLE;
  }
  return handle;
}

bool AppendOpenFileLog(const int handle,
                       const string line,
                       const bool flush_after_write)
{
  if(handle == INVALID_HANDLE || line == "")
    return false;

  ResetLastError();
  if(!FileSeek(handle, 0, SEEK_END))
    return false;

  uint bytes_written = FileWrite(handle, line);
  if(bytes_written == 0)
    return false;
  if(flush_after_write)
    FileFlush(handle);
  return true;
}

void CloseAppendFileLog(int &handle)
{
  if(handle == INVALID_HANDLE)
    return;
  FileClose(handle);
  handle = INVALID_HANDLE;
}

// Appends a single line to the specified text file located in the common Files directory.
// Returns true on success.
bool AppendFileLog(const string filename, const string line)
{
  int handle = OpenAppendFileLog(filename);
  if(handle == INVALID_HANDLE)
    return false;

  bool written = AppendOpenFileLog(handle, line, true);
  CloseAppendFileLog(handle);
  return written;
}

bool AppendTimestampedLog(const string filename, const string label, const string message)
{
  string line = StringFormat("%s | %s | %s",
                             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                             label,
                             message);
  return AppendFileLog(filename, line);
}

#endif // _MICROSERVICES_UTILS_FILE_LOGGER_MQH_
