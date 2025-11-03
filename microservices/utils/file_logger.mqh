//+------------------------------------------------------------------+
//|                          microservices/utils/file_logger.mqh    |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_FILE_LOGGER_MQH_
#define _MICROSERVICES_UTILS_FILE_LOGGER_MQH_

// Appends a single line to the specified text file located in the common Files directory.
// Returns true on success.
bool AppendFileLog(const string filename, const string line)
{
  if(filename == "")
    return false;

  int handle = FileOpen(filename,
                        FILE_WRITE | FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
  if(handle == INVALID_HANDLE)
    return false;

  FileSeek(handle, 0, SEEK_END);
  FileWrite(handle, line);
  FileClose(handle);
  return true;
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
