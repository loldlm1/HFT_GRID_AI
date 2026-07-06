//+------------------------------------------------------------------+
//|     trading_signals/deterministic_signal_pattern_audit_playback  |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_
#define _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_

const int    PATTERN_AUDIT_PLAYBACK_SCHEMA_VERSION = 1;
const string PATTERN_AUDIT_FOLDER                  = "pattern_audits";
const string PATTERN_AUDIT_MATCHES_FILE            = "pattern_matches.tsv";
const string PATTERN_AUDIT_OBSERVATIONS_FILE       = "pattern_tester_observations.tsv";
const int    PATTERN_AUDIT_MATCH_RESERVE           = 256;
const string PATTERN_AUDIT_OBSERVATIONS_HEADER =
  "schema_version\taudit_id\tpattern_id\tsignal_id\tsource_key\tsource_attempt_index\tentry_time\texpected_match\tobservation_status\tpattern_label\tconditions_text";

struct PatternAuditPlaybackMatch
{
  string pattern_id;
  string pattern_label;
  string source_key;
  int    source_attempt_index;
  string signal_id;
  string conditions_text;
  bool   observed;

  PatternAuditPlaybackMatch()
  {
    pattern_id = "";
    pattern_label = "";
    source_key = "";
    source_attempt_index = 0;
    signal_id = "";
    conditions_text = "";
    observed = false;
  }

  PatternAuditPlaybackMatch(const PatternAuditPlaybackMatch &other)
  {
    pattern_id = other.pattern_id;
    pattern_label = other.pattern_label;
    source_key = other.source_key;
    source_attempt_index = other.source_attempt_index;
    signal_id = other.signal_id;
    conditions_text = other.conditions_text;
    observed = other.observed;
  }
};

struct PatternAuditPlaybackState
{
  bool     enabled;
  bool     initialized;
  bool     failed;
  string   audit_id;
  string   folder;
  int      loaded_matches;
  int      observed_matches;

  PatternAuditPlaybackState()
  {
    enabled = false;
    initialized = false;
    failed = false;
    audit_id = "";
    folder = "";
    loaded_matches = 0;
    observed_matches = 0;
  }
};

PatternAuditPlaybackState g_pattern_audit_state;
PatternAuditPlaybackMatch g_pattern_audit_matches[];

bool PatternAuditPlaybackEnabled()
{
  return Enable_Pattern_Audit_Overlay && MQLInfoInteger(MQL_TESTER) > 0;
}

string PatternAuditPlaybackFolder()
{
  return DETERMINISTIC_SIGNAL_STATS_STORAGE_ROOT + "\\" +
         PATTERN_AUDIT_FOLDER + "\\" +
         g_pattern_audit_state.audit_id;
}

string PatternAuditPlaybackPath(const string filename)
{
  return g_pattern_audit_state.folder + "\\" + filename;
}

bool PatternAuditPlaybackEnsureFolder()
{
  if(g_pattern_audit_state.folder == "")
    return false;

  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_pattern_audit_state.folder, delimiter, parts);
  if(total <= 0)
    return false;

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
    FolderCreate(current_folder, FILE_COMMON);
  }

  return true;
}

string PatternAuditPlaybackCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  if(value == "")
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return value;
}

bool PatternAuditPlaybackWriteLine(const string filename,
                                   const string line,
                                   const bool append)
{
  if(filename == "" || line == "")
    return false;

  int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
  if(append)
    flags |= FILE_READ;

  ResetLastError();
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    g_pattern_audit_state.failed = true;
    if(Enable_Logs || Enable_File_Logs)
    {
      PrintFormat("PATTERN_AUDIT_WRITE_FAIL | file=%s | err=%d",
                  filename,
                  GetLastError());
    }
    return false;
  }

  if(append)
    FileSeek(handle, 0, SEEK_END);

  FileWrite(handle, line);
  FileClose(handle);
  return true;
}

bool PatternAuditPlaybackAppendObservation(const string row)
{
  string filename = PatternAuditPlaybackPath(PATTERN_AUDIT_OBSERVATIONS_FILE);
  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  if(needs_header)
  {
    if(!PatternAuditPlaybackWriteLine(filename,
                                      PATTERN_AUDIT_OBSERVATIONS_HEADER,
                                      false))
      return false;
  }
  return PatternAuditPlaybackWriteLine(filename, row, true);
}

int PatternAuditPlaybackHeaderIndex(string &header_cells[],
                                    const int header_total,
                                    const string column_name)
{
  for(int i = 0; i < header_total; i++)
  {
    if(header_cells[i] == column_name)
      return i;
  }
  return -1;
}

bool PatternAuditPlaybackReadLine(const int handle,
                                  string &line_out)
{
  line_out = "";
  if(FileIsEnding(handle))
    return false;

  line_out = FileReadString(handle);
  return true;
}

int PatternAuditPlaybackSplitLine(const string line,
                                  string &cells[])
{
  ushort delimiter = StringGetCharacter("\t", 0);
  return StringSplit(line, delimiter, cells);
}

bool PatternAuditPlaybackLoadMatches()
{
  ArrayResize(g_pattern_audit_matches, 0);

  string filename = PatternAuditPlaybackPath(PATTERN_AUDIT_MATCHES_FILE);
  ResetLastError();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    g_pattern_audit_state.failed = true;
    if(Enable_Logs || Enable_File_Logs)
    {
      PrintFormat("PATTERN_AUDIT_LOAD_FAIL | file=%s | err=%d",
                  filename,
                  GetLastError());
    }
    return false;
  }

  string header_line = "";
  if(!PatternAuditPlaybackReadLine(handle, header_line))
  {
    FileClose(handle);
    return false;
  }

  string header_cells[];
  int header_total = PatternAuditPlaybackSplitLine(header_line, header_cells);
  int pattern_id_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "pattern_id");
  int pattern_label_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "pattern_label");
  int signal_id_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "signal_id");
  int source_key_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "source_key");
  int source_attempt_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "source_attempt_index");
  int selected_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "selected_for_visual");
  int conditions_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "conditions_text");
  if(pattern_id_index < 0 ||
     pattern_label_index < 0 ||
     signal_id_index < 0 ||
     source_key_index < 0 ||
     source_attempt_index < 0 ||
     selected_index < 0 ||
     conditions_index < 0)
  {
    FileClose(handle);
    g_pattern_audit_state.failed = true;
    return false;
  }

  string line = "";
  while(PatternAuditPlaybackReadLine(handle, line))
  {
    if(line == "")
      continue;

    string cells[];
    int total = PatternAuditPlaybackSplitLine(line, cells);
    if(total <= conditions_index ||
       total <= source_attempt_index ||
       total <= source_key_index)
      continue;

    string selected_value = cells[selected_index];
    if(selected_value != "true" && selected_value != "1")
      continue;

    string source_key = cells[source_key_index];
    if(source_key == "" || source_key == DETERMINISTIC_SIGNAL_STATS_NULL)
      continue;

    PatternAuditPlaybackMatch match;
    match.pattern_id = cells[pattern_id_index];
    match.pattern_label = cells[pattern_label_index];
    match.signal_id = cells[signal_id_index];
    match.source_key = source_key;
    match.source_attempt_index = (int)StringToInteger(cells[source_attempt_index]);
    match.conditions_text = cells[conditions_index];

    int index = ArraySize(g_pattern_audit_matches);
    ArrayResize(g_pattern_audit_matches, index + 1, PATTERN_AUDIT_MATCH_RESERVE);
    g_pattern_audit_matches[index] = match;
  }

  FileClose(handle);
  g_pattern_audit_state.loaded_matches = ArraySize(g_pattern_audit_matches);
  return true;
}

void PatternAuditPlaybackInit()
{
  g_pattern_audit_state = PatternAuditPlaybackState();
  ArrayResize(g_pattern_audit_matches, 0);

  if(!PatternAuditPlaybackEnabled())
    return;

  if(Pattern_Audit_Set_Id == "")
  {
    if(Enable_Logs || Enable_File_Logs)
      Print("PATTERN_AUDIT_DISABLED | missing Pattern_Audit_Set_Id");
    return;
  }

  g_pattern_audit_state.enabled = true;
  g_pattern_audit_state.audit_id = DeterministicSignalStatsSanitizePart(Pattern_Audit_Set_Id);
  g_pattern_audit_state.folder = PatternAuditPlaybackFolder();
  PatternAuditPlaybackEnsureFolder();
  if(PatternAuditPlaybackLoadMatches())
    g_pattern_audit_state.initialized = true;

  if(Enable_Logs || Enable_File_Logs)
  {
    PrintFormat("PATTERN_AUDIT_INIT | audit_id=%s | initialized=%s | matches=%d",
                g_pattern_audit_state.audit_id,
                g_pattern_audit_state.initialized ? "true" : "false",
                g_pattern_audit_state.loaded_matches);
  }
}

void PatternAuditPlaybackDeinit()
{
  ArrayResize(g_pattern_audit_matches, 0);
  g_pattern_audit_state.initialized = false;
}

bool PatternAuditPlaybackReady()
{
  return g_pattern_audit_state.enabled &&
         g_pattern_audit_state.initialized &&
         !g_pattern_audit_state.failed;
}

string PatternAuditPlaybackSignalId(const SignalParams &signal_params)
{
  return signal_params.deterministic_stats_signal_id;
}

void PatternAuditPlaybackDrawMarker(const PatternAuditPlaybackMatch &match,
                                    const SignalParams &signal_params,
                                    const ExecutionLegState &leg_state)
{
  if(!Enable_Pattern_Audit_Overlay ||
     MQLInfoInteger(MQL_VISUAL_MODE) <= 0)
    return;

  datetime marker_time = leg_state.last_action_time;
  if(marker_time <= 0)
    marker_time = TimeCurrent();

  double marker_price = leg_state.entry_price;
  if(marker_price <= 0.0)
    marker_price = leg_state.entry_reference_price;
  if(marker_price <= 0.0)
    marker_price = signal_params.entry_price;
  if(marker_price <= 0.0)
    marker_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  if(marker_price <= 0.0)
    return;

  string object_name = "HFT_EXEC_AI_PATTERN_AUDIT_" +
                       match.pattern_id + "_" +
                       IntegerToString((int)marker_time);
  long chart_id = ChartID();
  if(ObjectFind(chart_id, object_name) < 0)
  {
    ObjectCreate(chart_id, object_name, OBJ_TEXT, 0, marker_time, marker_price);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_BACK, false);
  }
  ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, clrDeepSkyBlue);
  ObjectSetString(chart_id, object_name, OBJPROP_TEXT, match.pattern_id);
  ObjectSetString(chart_id, object_name, OBJPROP_TOOLTIP,
                  match.pattern_label + " | " + match.conditions_text);
}

void PatternAuditPlaybackRecordSignal(SignalParams &signal_params,
                                      const ExecutionLegState &leg_state)
{
  if(!PatternAuditPlaybackReady())
    return;
  if(!signal_params.deterministic_strategy)
    return;

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
  {
    source_key = BuildDeterministicSignalSourceKey(signal_params);
    signal_params.deterministic_source_key = source_key;
  }
  if(source_key == "")
    return;

  int attempt_index = signal_params.deterministic_source_attempt_index;
  string signal_id = PatternAuditPlaybackSignalId(signal_params);
  string entry_time = DeterministicSignalStatsTimeToken(leg_state.last_action_time);

  int total = ArraySize(g_pattern_audit_matches);
  for(int i = 0; i < total; i++)
  {
    if(g_pattern_audit_matches[i].observed)
      continue;
    if(g_pattern_audit_matches[i].source_key != source_key)
      continue;
    if(g_pattern_audit_matches[i].source_attempt_index != attempt_index)
      continue;

    g_pattern_audit_matches[i].observed = true;
    g_pattern_audit_state.observed_matches++;

    string row = IntegerToString(PATTERN_AUDIT_PLAYBACK_SCHEMA_VERSION) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_state.audit_id) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].pattern_id) + "\t" +
                 PatternAuditPlaybackCell(signal_id) + "\t" +
                 PatternAuditPlaybackCell(source_key) + "\t" +
                 IntegerToString(attempt_index) + "\t" +
                 PatternAuditPlaybackCell(entry_time) + "\t" +
                 "true\tOBSERVED\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].pattern_label) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].conditions_text);
    PatternAuditPlaybackAppendObservation(row);
    PatternAuditPlaybackDrawMarker(g_pattern_audit_matches[i],
                                   signal_params,
                                   leg_state);
  }
}

#endif // _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_
