//+------------------------------------------------------------------+
//|     trading_signals/deterministic_signal_pattern_audit_playback  |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_
#define _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_

const int    PATTERN_AUDIT_PLAYBACK_SCHEMA_VERSION = 3;
const string PATTERN_AUDIT_FOLDER                  = "pattern_audits";
const string PATTERN_AUDIT_MATCHES_FILE            = "pattern_matches.tsv";
const string PATTERN_AUDIT_OBSERVATIONS_FILE       = "pattern_tester_observations.tsv";
const int    PATTERN_AUDIT_MATCH_RESERVE           = 256;
const int    PATTERN_AUDIT_INDEX_RESERVE           = 256;
const string PATTERN_AUDIT_OBSERVATIONS_HEADER =
  "schema_version\taudit_id\tpattern_id\tsignal_id\tsource_key\tsource_attempt_index\texpected_entry_broker_time\texpected_entry_analysis_time\texpected_entry_offset_minutes\tobserved_entry_broker_time\tobserved_entry_analysis_time\tobserved_entry_offset_minutes\texpected_signal_id\tobserved_signal_id\texpected_match\tobservation_status\tpattern_label\tconditions_text";

struct PatternAuditPlaybackMatch
{
  string pattern_id;
  string pattern_label;
  string source_key;
  int    source_attempt_index;
  string signal_id;
  string entry_broker_time;
  string entry_analysis_time;
  string entry_offset_minutes;
  string conditions_text;
  bool   observed;

  PatternAuditPlaybackMatch()
  {
    pattern_id = "";
    pattern_label = "";
    source_key = "";
    source_attempt_index = 0;
    signal_id = "";
    entry_broker_time = "";
    entry_analysis_time = "";
    entry_offset_minutes = "";
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
    entry_broker_time = other.entry_broker_time;
    entry_analysis_time = other.entry_analysis_time;
    entry_offset_minutes = other.entry_offset_minutes;
    conditions_text = other.conditions_text;
    observed = other.observed;
  }
};

struct PatternAuditPlaybackIndexEntry
{
  string key;
  int    first_index;
  int    match_count;

  PatternAuditPlaybackIndexEntry()
  {
    key = "";
    first_index = -1;
    match_count = 0;
  }

  PatternAuditPlaybackIndexEntry(const PatternAuditPlaybackIndexEntry &other)
  {
    key = other.key;
    first_index = other.first_index;
    match_count = other.match_count;
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
  int      indexed_keys;
  int      observed_matches;
  string   last_pattern_id;
  string   last_pattern_label;
  string   last_strategy_label;

  PatternAuditPlaybackState()
  {
    enabled = false;
    initialized = false;
    failed = false;
    audit_id = "";
    folder = "";
    loaded_matches = 0;
    indexed_keys = 0;
    observed_matches = 0;
    last_pattern_id = "";
    last_pattern_label = "";
    last_strategy_label = "";
  }
};

PatternAuditPlaybackState g_pattern_audit_state;
PatternAuditPlaybackMatch g_pattern_audit_matches[];
PatternAuditPlaybackIndexEntry g_pattern_audit_index[];
string g_pattern_audit_admitted_family_keys[];

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

string PatternAuditPlaybackCompositeKey(const string source_key,
                                        const int source_attempt_index)
{
  return source_key + "|" + IntegerToString(source_attempt_index);
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

void PatternAuditPlaybackResetObservations()
{
  string filename = PatternAuditPlaybackPath(PATTERN_AUDIT_OBSERVATIONS_FILE);
  if(filename == "")
    return;

  if(!FileIsExist(filename, FILE_COMMON))
    return;

  ResetLastError();
  if(!FileDelete(filename, FILE_COMMON) &&
     (Enable_Logs || Enable_File_Logs))
  {
    PrintFormat("PATTERN_AUDIT_RESET_OBSERVATIONS_FAIL | file=%s | err=%d",
                filename,
                GetLastError());
  }
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

int PatternAuditPlaybackCompareMatches(const PatternAuditPlaybackMatch &left,
                                       const PatternAuditPlaybackMatch &right)
{
  string left_key = PatternAuditPlaybackCompositeKey(left.source_key,
                                                    left.source_attempt_index);
  string right_key = PatternAuditPlaybackCompositeKey(right.source_key,
                                                     right.source_attempt_index);
  int key_compare = StringCompare(left_key, right_key);
  if(key_compare != 0)
    return key_compare;
  return StringCompare(left.pattern_id, right.pattern_id);
}

void PatternAuditPlaybackSortMatches()
{
  int total = ArraySize(g_pattern_audit_matches);
  for(int i = 1; i < total; i++)
  {
    PatternAuditPlaybackMatch current = g_pattern_audit_matches[i];
    int j = i - 1;
    while(j >= 0 && PatternAuditPlaybackCompareMatches(g_pattern_audit_matches[j], current) > 0)
    {
      g_pattern_audit_matches[j + 1] = g_pattern_audit_matches[j];
      j--;
    }
    g_pattern_audit_matches[j + 1] = current;
  }
}

void PatternAuditPlaybackBuildIndex()
{
  ArrayResize(g_pattern_audit_index, 0);

  int total = ArraySize(g_pattern_audit_matches);
  if(total <= 0)
    return;

  string current_key = "";
  int index_count = 0;
  for(int i = 0; i < total; i++)
  {
    string key = PatternAuditPlaybackCompositeKey(g_pattern_audit_matches[i].source_key,
                                                 g_pattern_audit_matches[i].source_attempt_index);
    if(i == 0 || key != current_key)
    {
      current_key = key;
      ArrayResize(g_pattern_audit_index, index_count + 1, PATTERN_AUDIT_INDEX_RESERVE);
      g_pattern_audit_index[index_count].key = key;
      g_pattern_audit_index[index_count].first_index = i;
      g_pattern_audit_index[index_count].match_count = 1;
      index_count++;
    }
    else
    {
      g_pattern_audit_index[index_count - 1].match_count++;
    }
  }

  g_pattern_audit_state.indexed_keys = ArraySize(g_pattern_audit_index);
}

int PatternAuditPlaybackFindIndex(const string source_key,
                                  const int source_attempt_index)
{
  string key = PatternAuditPlaybackCompositeKey(source_key, source_attempt_index);
  int left = 0;
  int right = ArraySize(g_pattern_audit_index) - 1;
  while(left <= right)
  {
    int middle = (left + right) / 2;
    int compare = StringCompare(g_pattern_audit_index[middle].key, key);
    if(compare == 0)
      return middle;
    if(compare < 0)
      left = middle + 1;
    else
      right = middle - 1;
  }
  return -1;
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
  int entry_broker_time_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "entry_broker_time");
  int entry_analysis_time_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "entry_analysis_time");
  int entry_offset_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "entry_offset_minutes");
  int selected_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "selected_for_visual");
  int conditions_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "conditions_text");
  int schema_version_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "phase1_schema_version");
  int feature_set_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "feature_set_id");
  int engine_id_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "engine_id");
  int engine_timeframe_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "engine_timeframe");
  int attempt_id_index = PatternAuditPlaybackHeaderIndex(header_cells, header_total, "extremum_attempt_id");
  if(pattern_id_index < 0 ||
     pattern_label_index < 0 ||
     signal_id_index < 0 ||
     source_key_index < 0 ||
     source_attempt_index < 0 ||
     entry_broker_time_index < 0 ||
     entry_analysis_time_index < 0 ||
     entry_offset_index < 0 ||
     selected_index < 0 ||
     conditions_index < 0 ||
     schema_version_index < 0 ||
     feature_set_index < 0 ||
     engine_id_index < 0 ||
     engine_timeframe_index < 0 ||
     attempt_id_index < 0)
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
       total <= entry_broker_time_index ||
       total <= entry_analysis_time_index ||
       total <= entry_offset_index ||
       total <= source_key_index ||
       total <= schema_version_index ||
       total <= feature_set_index ||
       total <= engine_id_index ||
       total <= engine_timeframe_index ||
       total <= attempt_id_index)
      continue;

    string selected_value = cells[selected_index];
    if(selected_value != "true" && selected_value != "1")
      continue;

    if((int)StringToInteger(cells[schema_version_index]) != DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION ||
       cells[feature_set_index] != "schema_v8_extremum_engine_xgb" ||
       (int)StringToInteger(cells[engine_id_index]) != EXTREMUM_ENGINE_V1 ||
       cells[engine_timeframe_index] != EnumToString(EXTREMUM_ENGINE_TIMEFRAME) ||
       cells[attempt_id_index] == "" ||
       cells[attempt_id_index] == DETERMINISTIC_SIGNAL_STATS_NULL)
      continue;

    string source_key = cells[source_key_index];
    if(source_key == "" || source_key == DETERMINISTIC_SIGNAL_STATS_NULL)
      continue;

    PatternAuditPlaybackMatch match;
    match.pattern_id = cells[pattern_id_index];
    match.pattern_label = cells[pattern_label_index];
    match.signal_id = cells[signal_id_index];
    match.entry_broker_time = cells[entry_broker_time_index];
    match.entry_analysis_time = cells[entry_analysis_time_index];
    match.entry_offset_minutes = cells[entry_offset_index];
    match.source_key = source_key;
    match.source_attempt_index = (int)StringToInteger(cells[source_attempt_index]);
    match.conditions_text = cells[conditions_index];

    int index = ArraySize(g_pattern_audit_matches);
    ArrayResize(g_pattern_audit_matches, index + 1, PATTERN_AUDIT_MATCH_RESERVE);
    g_pattern_audit_matches[index] = match;
  }

  FileClose(handle);
  PatternAuditPlaybackSortMatches();
  PatternAuditPlaybackBuildIndex();
  g_pattern_audit_state.loaded_matches = ArraySize(g_pattern_audit_matches);
  return true;
}

void PatternAuditPlaybackInit()
{
  g_pattern_audit_state = PatternAuditPlaybackState();
  ArrayResize(g_pattern_audit_matches, 0);
  ArrayResize(g_pattern_audit_index, 0);
  ArrayResize(g_pattern_audit_admitted_family_keys, 0);

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
  PatternAuditPlaybackResetObservations();
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
  ArrayResize(g_pattern_audit_index, 0);
  ArrayResize(g_pattern_audit_admitted_family_keys, 0);
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

bool PatternAuditPlaybackUiVisible()
{
  return g_pattern_audit_state.enabled;
}

string PatternAuditPlaybackPanelMode()
{
  if(!g_pattern_audit_state.enabled)
    return "OFF";
  if(g_pattern_audit_state.failed)
    return "LOAD FAILED";
  if(!g_pattern_audit_state.initialized)
    return "PENDING";
  return "TESTER FILTER";
}

string PatternAuditPlaybackPanelCounts()
{
  return IntegerToString(g_pattern_audit_state.observed_matches) + "/" +
         IntegerToString(g_pattern_audit_state.loaded_matches) + " hits";
}

string PatternAuditPlaybackPanelAuditId()
{
  return g_pattern_audit_state.audit_id;
}

string PatternAuditPlaybackPanelRecentPattern()
{
  if(g_pattern_audit_state.last_pattern_label != "")
  {
    string parts[];
    ushort delimiter = StringGetCharacter("|", 0);
    int total = StringSplit(g_pattern_audit_state.last_pattern_label, delimiter, parts);
    if(total >= 2)
    {
      string strategy = parts[0];
      string direction = parts[1];
      StringTrimLeft(strategy);
      StringTrimRight(strategy);
      StringTrimLeft(direction);
      StringTrimRight(direction);
      return strategy + " " + direction;
    }
    return g_pattern_audit_state.last_pattern_label;
  }
  return g_pattern_audit_state.last_pattern_id;
}

string PatternAuditPlaybackPanelRecentSetup()
{
  if(g_pattern_audit_state.last_pattern_label == "")
    return "";

  string parts[];
  ushort delimiter = StringGetCharacter("|", 0);
  int total = StringSplit(g_pattern_audit_state.last_pattern_label, delimiter, parts);
  if(total <= 2)
    return "";

  string setup = "";
  for(int i = 2; i < total && i < 5; i++)
  {
    string part = parts[i];
    StringTrimLeft(part);
    StringTrimRight(part);
    if(setup == "")
      setup = part;
    else
      setup = setup + " | " + part;
  }
  return setup;
}

string PatternAuditPlaybackPanelRecentExtra()
{
  if(g_pattern_audit_state.last_pattern_label == "")
    return "";

  string parts[];
  ushort delimiter = StringGetCharacter("|", 0);
  int total = StringSplit(g_pattern_audit_state.last_pattern_label, delimiter, parts);
  if(total <= 5)
    return "";

  string extra = "";
  for(int i = 5; i < total && i < 8; i++)
  {
    string part = parts[i];
    StringTrimLeft(part);
    StringTrimRight(part);
    if(extra == "")
      extra = part;
    else
      extra = extra + " | " + part;
  }
  return extra;
}

bool PatternAuditPlaybackResolveSignalKey(SignalParams &signal_params,
                                          string &source_key_out,
                                          int &attempt_index_out)
{
  source_key_out = signal_params.deterministic_source_key;
  if(source_key_out == "")
  {
    source_key_out = BuildExtremumEngineSignalSourceKey(signal_params);
    signal_params.deterministic_source_key = source_key_out;
  }
  attempt_index_out = signal_params.deterministic_source_attempt_index;
  return source_key_out != "";
}

string PatternAuditPlaybackSourceFamilyKey(const SignalParams &signal_params)
{
  return BuildExtremumEngineSignalSourceFamilyKey(signal_params);
}

bool PatternAuditPlaybackFamilyAlreadyAdmitted(const string source_family_key)
{
  if(source_family_key == "")
    return false;

  int total = ArraySize(g_pattern_audit_admitted_family_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_pattern_audit_admitted_family_keys[i] == source_family_key)
      return true;
  }
  return false;
}

void PatternAuditPlaybackRegisterAdmittedFamily(const string source_family_key)
{
  if(source_family_key == "" ||
     PatternAuditPlaybackFamilyAlreadyAdmitted(source_family_key))
    return;

  int index = ArraySize(g_pattern_audit_admitted_family_keys);
  ArrayResize(g_pattern_audit_admitted_family_keys, index + 1, PATTERN_AUDIT_INDEX_RESERVE);
  g_pattern_audit_admitted_family_keys[index] = source_family_key;
}

bool PatternAuditPlaybackHasSelectedMatch(SignalParams &signal_params)
{
  if(!PatternAuditPlaybackReady())
    return false;
  if(!signal_params.deterministic_strategy)
    return false;

  string source_key = "";
  int attempt_index = 0;
  if(!PatternAuditPlaybackResolveSignalKey(signal_params, source_key, attempt_index))
    return false;

  return PatternAuditPlaybackFindIndex(source_key, attempt_index) >= 0;
}

bool PatternAuditSelectedAdmissionAllowsEntry(SignalParams &signal_params,
                                              const ExecutionState &execution_state,
                                              string &block_reason_out)
{
  block_reason_out = "";
  if(!Enable_Pattern_Audit_Overlay)
    return true;

  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  if(Pattern_Audit_Set_Id == "")
  {
    block_reason_out = "pattern_audit_set_id_missing";
    return false;
  }

  if(!PatternAuditPlaybackReady())
  {
    block_reason_out = "pattern_audit_not_ready";
    return false;
  }

  if(PatternAuditPlaybackHasSelectedMatch(signal_params))
  {
    string source_family_key = PatternAuditPlaybackSourceFamilyKey(signal_params);
    if(PatternAuditPlaybackFamilyAlreadyAdmitted(source_family_key))
    {
      block_reason_out = "duplicate_source_family|source_family_key=" + source_family_key;
      return false;
    }
    return true;
  }

  string source_key = signal_params.deterministic_source_key;
  int attempt_index = signal_params.deterministic_source_attempt_index;
  block_reason_out = StringFormat("selected_pattern_not_matched|source_key=%s|attempt=%d|entry=%.5f",
                                  source_key,
                                  attempt_index,
                                  execution_state.planned_entry_price);
  return false;
}

void PatternAuditPlaybackRecordSignal(SignalParams &signal_params,
                                      const ExecutionState &execution_state)
{
  if(!PatternAuditPlaybackReady())
    return;
  if(!signal_params.deterministic_strategy)
    return;

  string source_key = "";
  int attempt_index = 0;
  if(!PatternAuditPlaybackResolveSignalKey(signal_params, source_key, attempt_index))
    return;

  string observed_signal_id = PatternAuditPlaybackSignalId(signal_params);
  datetime observed_entry_broker_time = execution_state.broker_entry_time;
  if(observed_entry_broker_time <= 0)
    observed_entry_broker_time = execution_state.last_action_time;
  int observed_offset_minutes = 0;
  datetime observed_entry_analysis_time =
    DeterministicSignalStatsAnalysisTime(observed_entry_broker_time,
                                         _Symbol,
                                         observed_offset_minutes);

  int index_entry = PatternAuditPlaybackFindIndex(source_key, attempt_index);
  if(index_entry < 0)
    return;

  PatternAuditPlaybackRegisterAdmittedFamily(PatternAuditPlaybackSourceFamilyKey(signal_params));

  int first_index = g_pattern_audit_index[index_entry].first_index;
  int last_index = first_index + g_pattern_audit_index[index_entry].match_count;
  for(int i = first_index; i < last_index; i++)
  {
    if(g_pattern_audit_matches[i].observed)
      continue;

    g_pattern_audit_matches[i].observed = true;
    g_pattern_audit_state.observed_matches++;
    g_pattern_audit_state.last_pattern_id = g_pattern_audit_matches[i].pattern_id;
    g_pattern_audit_state.last_pattern_label = g_pattern_audit_matches[i].pattern_label;
    g_pattern_audit_state.last_strategy_label = signal_params.engine_label;

    string expected_signal_id = g_pattern_audit_matches[i].signal_id;
    string expected_entry_broker_time = g_pattern_audit_matches[i].entry_broker_time;
    string expected_entry_analysis_time = g_pattern_audit_matches[i].entry_analysis_time;
    string expected_entry_offset_minutes = g_pattern_audit_matches[i].entry_offset_minutes;
    string observed_entry_broker_token =
      DeterministicSignalStatsTimeToken(observed_entry_broker_time);
    string observed_entry_analysis_token =
      DeterministicSignalStatsTimeToken(observed_entry_analysis_time);
    bool analysis_time_match =
      expected_entry_analysis_time == observed_entry_analysis_token;
    string row = IntegerToString(PATTERN_AUDIT_PLAYBACK_SCHEMA_VERSION) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_state.audit_id) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].pattern_id) + "\t" +
                 PatternAuditPlaybackCell(expected_signal_id) + "\t" +
                 PatternAuditPlaybackCell(source_key) + "\t" +
                 IntegerToString(attempt_index) + "\t" +
                 PatternAuditPlaybackCell(expected_entry_broker_time) + "\t" +
                 PatternAuditPlaybackCell(expected_entry_analysis_time) + "\t" +
                 PatternAuditPlaybackCell(expected_entry_offset_minutes) + "\t" +
                 PatternAuditPlaybackCell(observed_entry_broker_token) + "\t" +
                 PatternAuditPlaybackCell(observed_entry_analysis_token) + "\t" +
                 DeterministicSignalStatsOffsetToken(observed_entry_broker_time,
                                                     observed_entry_analysis_time,
                                                     observed_offset_minutes) + "\t" +
                 PatternAuditPlaybackCell(expected_signal_id) + "\t" +
                 PatternAuditPlaybackCell(observed_signal_id) + "\t" +
                 (analysis_time_match ? "1" : "0") + "\t" +
                 (analysis_time_match ? "OBSERVED" : "ANALYSIS_TIME_MISMATCH") + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].pattern_label) + "\t" +
                 PatternAuditPlaybackCell(g_pattern_audit_matches[i].conditions_text);
    PatternAuditPlaybackAppendObservation(row);
  }
}

#endif // _TS_DETERMINISTIC_SIGNAL_PATTERN_AUDIT_PLAYBACK_MQH_
