//+------------------------------------------------------------------+
//|        trading_signals/deterministic_signal_ml_shadow_inference  |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_
#define _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_

const int    ML_SHADOW_ARTIFACT_SCHEMA_VERSION = 1;
const int    ML_SHADOW_PHASE1_SCHEMA_VERSION   = 7;
const string ML_SHADOW_STORAGE_ROOT            = "DeterministicSignalML";
const string ML_SHADOW_MODEL_EXPORTS_FOLDER    = "model_exports";
const string ML_SHADOW_RUNS_FOLDER             = "shadow_runs";
const string ML_SHADOW_MANIFEST_FILE           = "model_manifest.tsv";
const string ML_SHADOW_FEATURE_MAP_FILE        = "feature_map.tsv";
const string ML_SHADOW_CLASSIFIER_TREES_FILE   = "classifier_trees.tsv";
const string ML_SHADOW_REGRESSOR_TREES_FILE    = "regressor_trees.tsv";
const string ML_SHADOW_THRESHOLD_POLICY_FILE   = "threshold_policy.tsv";
const string ML_SHADOW_RUN_MANIFEST_FILE       = "shadow_manifest.tsv";
const string ML_SHADOW_PREDICTIONS_FILE        = "shadow_predictions.tsv";
const string ML_SHADOW_OUTCOMES_FILE           = "shadow_outcomes.tsv";
const string ML_SHADOW_SUMMARY_FILE            = "shadow_summary.tsv";
const string ML_SHADOW_ARBITRATION_DECISIONS_FILE = "arbitration_decisions.tsv";
const int    ML_SHADOW_FEATURE_RESERVE         = 64;
const int    ML_SHADOW_TREE_NODE_RESERVE       = 512;
const int    ML_SHADOW_MANIFEST_RESERVE        = 48;
const int    ML_SHADOW_MAX_FEATURES            = 512;
const int    ML_SHADOW_MAX_TREE_NODES          = 20000;
const int    ML_SHADOW_FLUSH_ROWS              = 32;
const string ML_SHADOW_RUN_MANIFEST_HEADER     = "schema_version\tkey\tvalue";
const string ML_SHADOW_PREDICTIONS_HEADER =
  "schema_version\tshadow_run_id\texport_id\tmodel_id\tdataset_id\tfeature_schema_version\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_id\tstrategy_label\tdirection\tsource_type\tentry_time\tclassifier_score\tregressor_score\tthreshold_probability\trecommendation\treason\tfeature_valid\tmodel_available\tstructure_0\tstructure_1\tstructure_2\tmacro_h1_slope\tmacro_h4_slope\tmacro_d1_slope\tfib_sl_band\tfib_entry_band\thigh_chain_profile\tlow_chain_profile\tprevious_candle_profile\tentry_session_bucket\tentry_weekday\tstoch_structure_raw_percent\tb_percent_main_base\tb_percent_main_base_slope\tb_percent_main_macro\tb_percent_main_macro_slope\tsession_id\ttime_sin\ttime_cos\tinference_mode\tadmission_action\tfilter_reason";
const string ML_SHADOW_OUTCOMES_HEADER =
  "schema_version\tshadow_run_id\texport_id\tmodel_id\tsignal_id\tsource_key\tsource_attempt_index\tterminal_time\tterminal_reason\trecommendation\tclassifier_score\tthreshold_probability\tprofit_r\tnet_profit\tduration_seconds";
const string ML_SHADOW_ARBITRATION_DECISIONS_HEADER =
  "schema_version\tshadow_run_id\texport_id\tmodel_id\tarbitration_group_id\tselected_signal_id\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_id\tstrategy_label\tdirection\tsource_type\tsource_extremum_slot\tsource_extremum_time\tsource_extremum_is_peak\tsource_extremum_price\tactivation_time\tclassifier_score\tregressor_score\tthreshold_probability\trank_position\trank_reason\tarbitration_action\tarbitration_reason";
const string ML_SHADOW_SUMMARY_HEADER =
  "schema_version\tshadow_run_id\texport_id\tmodel_id\tstarted_at\tfinished_at\tprediction_rows\toutcome_rows\tinvalid_feature_rows\tunavailable_events\tfilter_allow_rows\tfilter_block_rows\tfilter_invalid_feature_blocks\tfilter_unavailable_blocks\tarbitration_group_rows\tarbitration_single_candidate_groups\tarbitration_multi_candidate_groups\tarbitration_selected_rows\tarbitration_blocked_rows\tarbitration_classifier_tie_rows\tarbitration_regressor_tie_rows\tarbitration_strategy_tie_break_rows\texport_status";

struct MLShadowRuntimeState
{
  bool     enabled;
  bool     available;
  bool     classifier_available;
  bool     regressor_available;
  string   unavailable_reason;
  string   export_id;
  string   shadow_run_id;
  string   shadow_folder;
  string   artifact_folder;
  string   model_id;
  string   dataset_id;
  int      artifact_schema_version;
  int      phase1_schema_version;
  int      encoded_feature_count;
  int      classifier_tree_count;
  int      regressor_tree_count;
  double   classifier_base_score;
  double   regressor_base_score;
  double   threshold_probability;
  datetime loaded_at;
  datetime started_at;
  int      prediction_rows;
  int      outcome_rows;
  int      invalid_feature_rows;
  int      unavailable_events;
  int      filter_allow_rows;
  int      filter_block_rows;
  int      filter_invalid_feature_blocks;
  int      filter_unavailable_blocks;
  int      arbitration_group_rows;
  int      arbitration_single_candidate_groups;
  int      arbitration_multi_candidate_groups;
  int      arbitration_selected_rows;
  int      arbitration_blocked_rows;
  int      arbitration_classifier_tie_rows;
  int      arbitration_regressor_tie_rows;
  int      arbitration_strategy_tie_break_rows;
  bool     export_failed;

  MLShadowRuntimeState()
  {
    enabled                 = false;
    available               = false;
    classifier_available    = false;
    regressor_available     = false;
    unavailable_reason      = "";
    export_id               = "";
    shadow_run_id           = "";
    shadow_folder           = "";
    artifact_folder         = "";
    model_id                = "";
    dataset_id              = "";
    artifact_schema_version = 0;
    phase1_schema_version   = 0;
    encoded_feature_count   = 0;
    classifier_tree_count   = 0;
    regressor_tree_count    = 0;
    classifier_base_score   = 0.0;
    regressor_base_score    = 0.0;
    threshold_probability   = 0.0;
    loaded_at               = 0;
    started_at              = 0;
    prediction_rows         = 0;
    outcome_rows            = 0;
    invalid_feature_rows    = 0;
    unavailable_events      = 0;
    filter_allow_rows       = 0;
    filter_block_rows       = 0;
    filter_invalid_feature_blocks = 0;
    filter_unavailable_blocks = 0;
    arbitration_group_rows = 0;
    arbitration_single_candidate_groups = 0;
    arbitration_multi_candidate_groups = 0;
    arbitration_selected_rows = 0;
    arbitration_blocked_rows = 0;
    arbitration_classifier_tie_rows = 0;
    arbitration_regressor_tie_rows = 0;
    arbitration_strategy_tie_break_rows = 0;
    export_failed           = false;
  }
};

struct MLShadowFeatureMapRow
{
  int    encoded_index;
  string encoded_feature_name;
  string source_column;
  string encoding_type;
  string category;

  MLShadowFeatureMapRow()
  {
    encoded_index        = -1;
    encoded_feature_name = "";
    source_column        = "";
    encoding_type        = "";
    category             = "";
  }

  MLShadowFeatureMapRow(const MLShadowFeatureMapRow &row)
  {
    encoded_index        = row.encoded_index;
    encoded_feature_name = row.encoded_feature_name;
    source_column        = row.source_column;
    encoding_type        = row.encoding_type;
    category             = row.category;
  }
};

struct MLShadowTreeNode
{
  int    tree_index;
  int    node_index;
  bool   leaf;
  int    feature_index;
  double threshold;
  int    left_child;
  int    right_child;
  bool   default_left;
  double leaf_value;

  MLShadowTreeNode()
  {
    tree_index    = -1;
    node_index    = -1;
    leaf          = false;
    feature_index = -1;
    threshold     = 0.0;
    left_child    = -1;
    right_child   = -1;
    default_left  = false;
    leaf_value    = 0.0;
  }

  MLShadowTreeNode(const MLShadowTreeNode &node)
  {
    tree_index    = node.tree_index;
    node_index    = node.node_index;
    leaf          = node.leaf;
    feature_index = node.feature_index;
    threshold     = node.threshold;
    left_child    = node.left_child;
    right_child   = node.right_child;
    default_left  = node.default_left;
    leaf_value    = node.leaf_value;
  }
};

struct MLShadowDecisionResult
{
  bool     signal_id_valid;
  bool     snapshot_valid;
  bool     model_available;
  bool     feature_valid;
  bool     classifier_scored;
  bool     regressor_scored;
  bool     model_admits_entry;
  string   signal_id;
  string   recommendation;
  string   reason;
  double   classifier_score;
  double   regressor_score;
  double   threshold_probability;
  DeterministicSignalFeatureSnapshot snapshot;

  MLShadowDecisionResult()
  {
    signal_id_valid      = false;
    snapshot_valid       = false;
    model_available      = false;
    feature_valid        = false;
    classifier_scored    = false;
    regressor_scored     = false;
    model_admits_entry   = false;
    signal_id            = "";
    recommendation       = "NO_SCORE";
    reason               = "not_scored";
    classifier_score     = 0.0;
    regressor_score      = 0.0;
    threshold_probability = 0.0;
    snapshot             = DeterministicSignalFeatureSnapshot();
  }

  MLShadowDecisionResult(const MLShadowDecisionResult &result)
  {
    signal_id_valid      = result.signal_id_valid;
    snapshot_valid       = result.snapshot_valid;
    model_available      = result.model_available;
    feature_valid        = result.feature_valid;
    classifier_scored    = result.classifier_scored;
    regressor_scored     = result.regressor_scored;
    model_admits_entry   = result.model_admits_entry;
    signal_id            = result.signal_id;
    recommendation       = result.recommendation;
    reason               = result.reason;
    classifier_score     = result.classifier_score;
    regressor_score      = result.regressor_score;
    threshold_probability = result.threshold_probability;
    snapshot             = result.snapshot;
  }
};

MLShadowRuntimeState g_ml_shadow_state;
string               g_ml_shadow_manifest_keys[];
string               g_ml_shadow_manifest_values[];
MLShadowFeatureMapRow g_ml_shadow_feature_map[];
MLShadowTreeNode      g_ml_shadow_classifier_nodes[];
MLShadowTreeNode      g_ml_shadow_regressor_nodes[];
string                g_ml_shadow_prediction_buffer[];
string                g_ml_shadow_outcome_buffer[];
string                g_ml_shadow_arbitration_buffer[];

bool DeterministicSignalMLShadowEnabled()
{
  return (ML_Inference_Mode == ML_INFERENCE_SHADOW ||
          ML_Inference_Mode == ML_INFERENCE_FILTER);
}

bool DeterministicSignalMLFilterMode()
{
  return (ML_Inference_Mode == ML_INFERENCE_FILTER);
}

bool DeterministicSignalMLFilterTesterAllowed()
{
  if(!DeterministicSignalMLFilterMode())
    return true;
  return (MQLInfoInteger(MQL_TESTER) > 0);
}

bool DeterministicSignalMLShadowAvailable()
{
  return g_ml_shadow_state.enabled && g_ml_shadow_state.available;
}

string DeterministicSignalMLShadowUnavailableReason()
{
  return g_ml_shadow_state.unavailable_reason;
}

string MLShadowBoolToken(const bool value)
{
  return value ? "true" : "false";
}

bool MLShadowBoolValue(const string value)
{
  return (value == "true" || value == "TRUE" || value == "1");
}

string MLShadowCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", "");
  StringReplace(value, "\n", "");
  return value;
}

string MLShadowBuildArtifactFolder()
{
  string export_id = DeterministicSignalStatsSanitizePart(ML_Model_Export_Id);
  if(export_id == "")
    export_id = "default";

  return ML_SHADOW_STORAGE_ROOT + "\\" +
         ML_SHADOW_MODEL_EXPORTS_FOLDER + "\\" +
         export_id;
}

string MLShadowBuildShadowRunId()
{
  if(g_deterministic_signal_stats_run_id != "")
    return "shadow_" + g_deterministic_signal_stats_run_id;

  string time_token = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
  return "shadow_" +
         DeterministicSignalStatsSanitizePart(StringFormat("%s_%s_%d_%s",
                                                           time_token,
                                                           _Symbol,
                                                           (int)_Period,
                                                           g_ml_shadow_state.export_id));
}

string MLShadowBuildShadowFolder()
{
  return ML_SHADOW_STORAGE_ROOT + "\\" +
         ML_SHADOW_RUNS_FOLDER + "\\" +
         g_ml_shadow_state.shadow_run_id;
}

string MLShadowArtifactPath(const string filename)
{
  return g_ml_shadow_state.artifact_folder + "\\" + filename;
}

string MLShadowOutputPath(const string filename)
{
  return g_ml_shadow_state.shadow_folder + "\\" + filename;
}

void MLShadowClearArrays()
{
  ArrayResize(g_ml_shadow_manifest_keys, 0, ML_SHADOW_MANIFEST_RESERVE);
  ArrayResize(g_ml_shadow_manifest_values, 0, ML_SHADOW_MANIFEST_RESERVE);
  ArrayResize(g_ml_shadow_feature_map, 0, ML_SHADOW_FEATURE_RESERVE);
  ArrayResize(g_ml_shadow_classifier_nodes, 0, ML_SHADOW_TREE_NODE_RESERVE);
  ArrayResize(g_ml_shadow_regressor_nodes, 0, ML_SHADOW_TREE_NODE_RESERVE);
  ArrayResize(g_ml_shadow_prediction_buffer, 0, ML_SHADOW_FLUSH_ROWS);
  ArrayResize(g_ml_shadow_outcome_buffer, 0, ML_SHADOW_FLUSH_ROWS);
  ArrayResize(g_ml_shadow_arbitration_buffer, 0, ML_SHADOW_FLUSH_ROWS);
}

void DeterministicSignalMLShadowReset()
{
  g_ml_shadow_state = MLShadowRuntimeState();
  MLShadowClearArrays();
}

void MLShadowLogUnavailable(const string reason)
{
  if(reason == "")
    return;

  if(Enable_Logs)
  {
    PrintFormat("ML_UNAVAILABLE | mode=%s | export_id=%s | reason=%s",
                ExecutionMLInferenceModeToken(ML_Inference_Mode),
                g_ml_shadow_state.export_id,
                reason);
  }

  ExecutionAppendQueryDebugThrottledLog("ML_UNAVAILABLE",
                                        reason,
                                        StringFormat("mode=%s|export_id=%s|reason=%s",
                                                     ExecutionMLInferenceModeToken(ML_Inference_Mode),
                                                     g_ml_shadow_state.export_id,
                                                     reason),
                                        QUERY_DEBUG_GUARDRAIL_THROTTLE_SECONDS);
}

bool MLShadowMarkUnavailable(const string reason)
{
  g_ml_shadow_state.available = false;
  g_ml_shadow_state.unavailable_reason = reason;
  g_ml_shadow_state.unavailable_events++;
  MLShadowLogUnavailable(reason);
  return false;
}

bool MLShadowEnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_ml_shadow_state.shadow_folder, delimiter, parts);
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
    int folder_error = GetLastError();
    if(folder_error != 0 && folder_error != 5019)
    {
      if(Enable_Logs || Enable_File_Logs)
      {
        PrintFormat("ML_SHADOW_FOLDER_CREATE failed | folder=%s | err=%d",
                    current_folder,
                    folder_error);
      }
    }
  }

  return true;
}

string MLShadowOutputCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  if(value == "")
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return value;
}

string MLShadowTimeToken(const datetime value)
{
  if(value <= 0)
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return TimeToString(value, TIME_DATE|TIME_SECONDS);
}

string MLShadowDoubleToken(const bool valid,
                           const double value,
                           const int digits)
{
  if(!valid || !MathIsValidNumber(value))
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return DoubleToString(value, digits);
}

string MLShadowIntToken(const bool valid,
                        const int value)
{
  if(!valid)
    return DETERMINISTIC_SIGNAL_STATS_NULL;
  return IntegerToString(value);
}

bool MLShadowWriteLine(const string filename,
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
    g_ml_shadow_state.export_failed = true;
    if(Enable_Logs || Enable_File_Logs)
    {
      PrintFormat("ML_SHADOW_WRITE_FAIL | file=%s | err=%d",
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

bool MLShadowAppendRow(const string filename,
                       const string header,
                       const string row)
{
  if(!g_ml_shadow_state.enabled || g_ml_shadow_state.shadow_folder == "")
    return false;

  bool needs_header = !FileIsExist(filename, FILE_COMMON);
  if(needs_header)
  {
    if(!MLShadowWriteLine(filename, header, false))
      return false;
  }

  return MLShadowWriteLine(filename, row, true);
}

bool MLShadowFlushBuffer(const string filename,
                         const string header,
                         string &buffer[])
{
  if(!g_ml_shadow_state.enabled)
    return false;

  int total = ArraySize(buffer);
  if(total <= 0)
    return true;

  for(int i = 0; i < total; i++)
  {
    if(!MLShadowAppendRow(filename, header, buffer[i]))
      return false;
  }

  ArrayResize(buffer, 0, ML_SHADOW_FLUSH_ROWS);
  return true;
}

bool MLShadowQueueRow(const string filename,
                      const string header,
                      const string row,
                      string &buffer[])
{
  if(!g_ml_shadow_state.enabled || row == "")
    return false;

  int total = ArraySize(buffer);
  int resized = ArrayResize(buffer, total + 1, ML_SHADOW_FLUSH_ROWS);
  if(resized != total + 1)
  {
    g_ml_shadow_state.export_failed = true;
    return false;
  }

  buffer[total] = row;
  if(ArraySize(buffer) >= ML_SHADOW_FLUSH_ROWS)
    return MLShadowFlushBuffer(filename, header, buffer);

  return true;
}

bool MLShadowFlushAll()
{
  if(!g_ml_shadow_state.enabled)
    return false;

  bool predictions_ok = MLShadowFlushBuffer(MLShadowOutputPath(ML_SHADOW_PREDICTIONS_FILE),
                                            ML_SHADOW_PREDICTIONS_HEADER,
                                            g_ml_shadow_prediction_buffer);
  bool outcomes_ok = MLShadowFlushBuffer(MLShadowOutputPath(ML_SHADOW_OUTCOMES_FILE),
                                         ML_SHADOW_OUTCOMES_HEADER,
                                         g_ml_shadow_outcome_buffer);
  bool arbitration_ok = MLShadowFlushBuffer(MLShadowOutputPath(ML_SHADOW_ARBITRATION_DECISIONS_FILE),
                                            ML_SHADOW_ARBITRATION_DECISIONS_HEADER,
                                            g_ml_shadow_arbitration_buffer);
  return predictions_ok && outcomes_ok && arbitration_ok;
}

string MLShadowManifestRow(const string key,
                           const string value)
{
  return IntegerToString(ML_SHADOW_ARTIFACT_SCHEMA_VERSION) + "\t" +
         MLShadowOutputCell(key) + "\t" +
         MLShadowOutputCell(value);
}

bool MLShadowWriteRunManifest()
{
  if(!g_ml_shadow_state.enabled || g_ml_shadow_state.shadow_folder == "")
    return false;

  string filename = MLShadowOutputPath(ML_SHADOW_RUN_MANIFEST_FILE);
  if(!MLShadowWriteLine(filename, ML_SHADOW_RUN_MANIFEST_HEADER, false))
    return false;

  MLShadowWriteLine(filename, MLShadowManifestRow("shadow_run_id", g_ml_shadow_state.shadow_run_id), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("export_id", g_ml_shadow_state.export_id), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("model_id", g_ml_shadow_state.model_id), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("dataset_id", g_ml_shadow_state.dataset_id), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("started_at", MLShadowTimeToken(g_ml_shadow_state.started_at)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("mode", ExecutionMLInferenceModeToken(ML_Inference_Mode)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("available", MLShadowBoolToken(g_ml_shadow_state.available)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("unavailable_reason", g_ml_shadow_state.unavailable_reason), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("feature_schema_version", IntegerToString(g_ml_shadow_state.phase1_schema_version)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("encoded_feature_count", IntegerToString(g_ml_shadow_state.encoded_feature_count)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("classifier_tree_count", IntegerToString(g_ml_shadow_state.classifier_tree_count)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("regressor_tree_count", IntegerToString(g_ml_shadow_state.regressor_tree_count)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("threshold_probability", DoubleToString(g_ml_shadow_state.threshold_probability, 8)), true);
  MLShadowWriteLine(filename, MLShadowManifestRow("policy", "shadow_fail_open"), true);
  return true;
}

bool MLShadowPrepareRowFiles()
{
  if(!g_ml_shadow_state.enabled || g_ml_shadow_state.shadow_folder == "")
    return false;

  bool predictions_ok = MLShadowWriteLine(MLShadowOutputPath(ML_SHADOW_PREDICTIONS_FILE),
                                          ML_SHADOW_PREDICTIONS_HEADER,
                                          false);
  bool outcomes_ok = MLShadowWriteLine(MLShadowOutputPath(ML_SHADOW_OUTCOMES_FILE),
                                       ML_SHADOW_OUTCOMES_HEADER,
                                       false);
  bool arbitration_ok = MLShadowWriteLine(MLShadowOutputPath(ML_SHADOW_ARBITRATION_DECISIONS_FILE),
                                          ML_SHADOW_ARBITRATION_DECISIONS_HEADER,
                                          false);
  return predictions_ok && outcomes_ok && arbitration_ok;
}

void MLShadowLogLoadStatus()
{
  ExecutionAppendQueryDebugLog("ML_MODEL_LOAD",
                               StringFormat("mode=%s|available=%s|export_id=%s|model_id=%s|dataset_id=%s|features=%d|classifier_trees=%d|regressor_trees=%d|threshold=%.8f",
                                            ExecutionMLInferenceModeToken(ML_Inference_Mode),
                                            MLShadowBoolToken(g_ml_shadow_state.available),
                                            g_ml_shadow_state.export_id,
                                            g_ml_shadow_state.model_id,
                                            g_ml_shadow_state.dataset_id,
                                            g_ml_shadow_state.encoded_feature_count,
                                            g_ml_shadow_state.classifier_tree_count,
                                            g_ml_shadow_state.regressor_tree_count,
                                            g_ml_shadow_state.threshold_probability));
}

bool MLShadowReadLine(const int handle,
                      string &line_out)
{
  line_out = "";
  if(FileIsEnding(handle))
    return false;

  line_out = FileReadString(handle);
  line_out = MLShadowCell(line_out);
  return true;
}

int MLShadowOpenRead(const string filename)
{
  ResetLastError();
  int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    int open_error = GetLastError();
    MLShadowMarkUnavailable(StringFormat("file_open_failed:%s:%d", filename, open_error));
  }
  return handle;
}

int MLShadowSplitLine(const string line,
                      string &cells[])
{
  ushort delimiter = StringGetCharacter("\t", 0);
  return StringSplit(line, delimiter, cells);
}

bool MLShadowReadRequiredFileLine(const int handle,
                                  string &line_out,
                                  const string context)
{
  if(!MLShadowReadLine(handle, line_out))
    return MLShadowMarkUnavailable("missing_line:" + context);
  return true;
}

void MLShadowStoreManifestValue(const string key,
                                const string value)
{
  int total = ArraySize(g_ml_shadow_manifest_keys);
  ArrayResize(g_ml_shadow_manifest_keys,
              total + 1,
              ML_SHADOW_MANIFEST_RESERVE);
  ArrayResize(g_ml_shadow_manifest_values,
              total + 1,
              ML_SHADOW_MANIFEST_RESERVE);
  g_ml_shadow_manifest_keys[total] = key;
  g_ml_shadow_manifest_values[total] = value;
}

string MLShadowManifestValue(const string key)
{
  int total = ArraySize(g_ml_shadow_manifest_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_ml_shadow_manifest_keys[i] == key)
      return g_ml_shadow_manifest_values[i];
  }
  return "";
}

bool MLShadowManifestHasValue(const string key)
{
  int total = ArraySize(g_ml_shadow_manifest_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_ml_shadow_manifest_keys[i] == key)
      return true;
  }
  return false;
}

bool MLShadowParseIntValue(const string value,
                           int &value_out)
{
  if(value == "")
    return false;

  value_out = (int)StringToInteger(value);
  return true;
}

bool MLShadowParseDoubleValue(const string value,
                              double &value_out)
{
  if(value == "")
    return false;

  value_out = StringToDouble(value);
  return MathIsValidNumber(value_out);
}

bool MLShadowLoadManifest()
{
  string filename = MLShadowArtifactPath(ML_SHADOW_MANIFEST_FILE);
  int handle = MLShadowOpenRead(filename);
  if(handle == INVALID_HANDLE)
    return false;

  string line = "";
  if(!MLShadowReadRequiredFileLine(handle, line, ML_SHADOW_MANIFEST_FILE))
  {
    FileClose(handle);
    return false;
  }

  while(MLShadowReadLine(handle, line))
  {
    if(line == "")
      continue;

    string cells[];
    int cell_count = MLShadowSplitLine(line, cells);
    if(cell_count < 2)
      continue;

    MLShadowStoreManifestValue(cells[0], cells[1]);
  }

  FileClose(handle);

  g_ml_shadow_state.model_id = MLShadowManifestValue("model_id");
  g_ml_shadow_state.dataset_id = MLShadowManifestValue("dataset_id");

  if(!MLShadowParseIntValue(MLShadowManifestValue("artifact_schema_version"),
                            g_ml_shadow_state.artifact_schema_version))
    return MLShadowMarkUnavailable("manifest_missing_artifact_schema_version");
  if(g_ml_shadow_state.artifact_schema_version != ML_SHADOW_ARTIFACT_SCHEMA_VERSION)
    return MLShadowMarkUnavailable("unsupported_artifact_schema_version");

  if(!MLShadowParseIntValue(MLShadowManifestValue("phase1_schema_version"),
                            g_ml_shadow_state.phase1_schema_version))
    return MLShadowMarkUnavailable("manifest_missing_phase1_schema_version");
  if(g_ml_shadow_state.phase1_schema_version != ML_SHADOW_PHASE1_SCHEMA_VERSION)
    return MLShadowMarkUnavailable("unsupported_phase1_schema_version");

  if(!MLShadowParseIntValue(MLShadowManifestValue("encoded_feature_count"),
                            g_ml_shadow_state.encoded_feature_count))
    return MLShadowMarkUnavailable("manifest_missing_encoded_feature_count");
  if(g_ml_shadow_state.encoded_feature_count <= 0 ||
     g_ml_shadow_state.encoded_feature_count > ML_SHADOW_MAX_FEATURES)
    return MLShadowMarkUnavailable("invalid_encoded_feature_count");

  if(!MLShadowParseIntValue(MLShadowManifestValue("classifier_tree_count"),
                            g_ml_shadow_state.classifier_tree_count))
    return MLShadowMarkUnavailable("manifest_missing_classifier_tree_count");
  if(g_ml_shadow_state.classifier_tree_count <= 0)
    return MLShadowMarkUnavailable("invalid_classifier_tree_count");

  if(!MLShadowParseDoubleValue(MLShadowManifestValue("classifier_base_score"),
                               g_ml_shadow_state.classifier_base_score))
    return MLShadowMarkUnavailable("manifest_missing_classifier_base_score");

  if(!MLShadowParseDoubleValue(MLShadowManifestValue("threshold_probability"),
                               g_ml_shadow_state.threshold_probability))
    return MLShadowMarkUnavailable("manifest_missing_threshold_probability");

  g_ml_shadow_state.classifier_available = MLShadowBoolValue(MLShadowManifestValue("classifier_available"));
  if(MLShadowManifestHasValue("classifier_available") &&
     !g_ml_shadow_state.classifier_available)
    return MLShadowMarkUnavailable("classifier_not_available");

  if(!MLShadowBoolValue(MLShadowManifestValue("mt5_runtime_ready")))
    return MLShadowMarkUnavailable("artifact_not_mt5_runtime_ready");
  if(!MLShadowBoolValue(MLShadowManifestValue("research_only")))
    return MLShadowMarkUnavailable("artifact_not_research_only");

  g_ml_shadow_state.regressor_available = MLShadowBoolValue(MLShadowManifestValue("regressor_available"));
  if(MLShadowParseIntValue(MLShadowManifestValue("regressor_tree_count"),
                           g_ml_shadow_state.regressor_tree_count) &&
     g_ml_shadow_state.regressor_tree_count > 0)
  {
    MLShadowParseDoubleValue(MLShadowManifestValue("regressor_base_score"),
                             g_ml_shadow_state.regressor_base_score);
  }
  else
  {
    g_ml_shadow_state.regressor_available = false;
    g_ml_shadow_state.regressor_tree_count = 0;
  }

  return true;
}

bool MLShadowLoadThresholdPolicy()
{
  string filename = MLShadowArtifactPath(ML_SHADOW_THRESHOLD_POLICY_FILE);
  int handle = MLShadowOpenRead(filename);
  if(handle == INVALID_HANDLE)
    return false;

  string line = "";
  if(!MLShadowReadRequiredFileLine(handle, line, ML_SHADOW_THRESHOLD_POLICY_FILE))
  {
    FileClose(handle);
    return false;
  }

  if(!MLShadowReadRequiredFileLine(handle, line, ML_SHADOW_THRESHOLD_POLICY_FILE + ":row"))
  {
    FileClose(handle);
    return false;
  }

  FileClose(handle);

  string cells[];
  int cell_count = MLShadowSplitLine(line, cells);
  if(cell_count < 8)
    return MLShadowMarkUnavailable("bad_threshold_policy_row");

  double threshold = 0.0;
  if(!MLShadowParseDoubleValue(cells[0], threshold))
    return MLShadowMarkUnavailable("bad_threshold_policy_threshold");
  if(MathAbs(threshold - g_ml_shadow_state.threshold_probability) > 0.0000001)
    return MLShadowMarkUnavailable("threshold_policy_manifest_mismatch");
  if(!MLShadowBoolValue(cells[7]))
    return MLShadowMarkUnavailable("threshold_policy_not_research_only");

  return true;
}

bool MLShadowLoadFeatureMap()
{
  string filename = MLShadowArtifactPath(ML_SHADOW_FEATURE_MAP_FILE);
  int handle = MLShadowOpenRead(filename);
  if(handle == INVALID_HANDLE)
    return false;

  string line = "";
  if(!MLShadowReadRequiredFileLine(handle, line, ML_SHADOW_FEATURE_MAP_FILE))
  {
    FileClose(handle);
    return false;
  }

  int expected_index = 0;
  while(MLShadowReadLine(handle, line))
  {
    if(line == "")
      continue;

    string cells[];
    int cell_count = MLShadowSplitLine(line, cells);
    if(cell_count < 4)
    {
      FileClose(handle);
      return MLShadowMarkUnavailable("bad_feature_map_row");
    }

    MLShadowFeatureMapRow row;
    row.encoded_index = (int)StringToInteger(cells[0]);
    row.encoded_feature_name = cells[1];
    row.source_column = cells[2];
    row.encoding_type = cells[3];
    row.category = (cell_count >= 5) ? cells[4] : "";

    if(row.encoded_index != expected_index)
    {
      FileClose(handle);
      return MLShadowMarkUnavailable("feature_map_index_gap");
    }
    if(row.encoding_type != "numeric" && row.encoding_type != "one_hot")
    {
      FileClose(handle);
      return MLShadowMarkUnavailable("unknown_feature_encoding");
    }

    int total = ArraySize(g_ml_shadow_feature_map);
    ArrayResize(g_ml_shadow_feature_map,
                total + 1,
                ML_SHADOW_FEATURE_RESERVE);
    g_ml_shadow_feature_map[total] = row;
    expected_index++;
  }

  FileClose(handle);

  if(ArraySize(g_ml_shadow_feature_map) != g_ml_shadow_state.encoded_feature_count)
    return MLShadowMarkUnavailable("feature_map_count_mismatch");

  return true;
}

int MLShadowFindTreeNode(const MLShadowTreeNode &nodes[],
                         const int tree_index,
                         const int node_index)
{
  int total = ArraySize(nodes);
  for(int i = 0; i < total; i++)
  {
    if(nodes[i].tree_index == tree_index &&
       nodes[i].node_index == node_index)
      return i;
  }
  return -1;
}

bool MLShadowParseTreeRow(const string line,
                          const string model_role,
                          MLShadowTreeNode &node_out)
{
  string cells[];
  int cell_count = MLShadowSplitLine(line, cells);
  if(cell_count < 4)
    return false;

  if(cells[0] != model_role)
    return false;

  node_out.tree_index = (int)StringToInteger(cells[1]);
  node_out.node_index = (int)StringToInteger(cells[2]);
  string node_type = cells[3];
  node_out.leaf = (node_type == "leaf");

  if(node_out.leaf)
  {
    string leaf_value = (cell_count >= 10) ? cells[9] : "";
    if(!MLShadowParseDoubleValue(leaf_value, node_out.leaf_value))
      return false;
    return true;
  }

  if(node_type != "split" || cell_count < 9)
    return false;

  node_out.feature_index = (int)StringToInteger(cells[4]);
  node_out.threshold = StringToDouble(cells[5]);
  node_out.left_child = (int)StringToInteger(cells[6]);
  node_out.right_child = (int)StringToInteger(cells[7]);
  node_out.default_left = (cells[8] == "1");

  if(node_out.feature_index < 0 ||
     node_out.feature_index >= g_ml_shadow_state.encoded_feature_count ||
     !MathIsValidNumber(node_out.threshold))
    return false;

  return true;
}

bool MLShadowValidateTreeNodes(const MLShadowTreeNode &nodes[],
                               const int expected_tree_count,
                               const string model_role)
{
  if(expected_tree_count <= 0)
    return false;

  bool roots[];
  ArrayResize(roots, expected_tree_count);

  int total = ArraySize(nodes);
  if(total <= 0 || total > ML_SHADOW_MAX_TREE_NODES)
    return false;

  for(int i = 0; i < total; i++)
  {
    if(nodes[i].tree_index < 0 ||
       nodes[i].tree_index >= expected_tree_count)
      return false;

    if(nodes[i].node_index == 0)
      roots[nodes[i].tree_index] = true;

    if(!nodes[i].leaf)
    {
      if(MLShadowFindTreeNode(nodes,
                              nodes[i].tree_index,
                              nodes[i].left_child) < 0)
        return false;
      if(MLShadowFindTreeNode(nodes,
                              nodes[i].tree_index,
                              nodes[i].right_child) < 0)
        return false;
    }
  }

  for(int tree_index = 0; tree_index < expected_tree_count; tree_index++)
  {
    if(!roots[tree_index])
      return false;
  }

  return true;
}

bool MLShadowLoadTreeFile(const string filename,
                          const string model_role,
                          const int expected_tree_count,
                          MLShadowTreeNode &nodes[],
                          const bool fatal)
{
  int handle = MLShadowOpenRead(filename);
  if(handle == INVALID_HANDLE)
    return false;

  string line = "";
  if(!MLShadowReadRequiredFileLine(handle, line, filename))
  {
    FileClose(handle);
    return false;
  }

  while(MLShadowReadLine(handle, line))
  {
    if(line == "")
      continue;

    MLShadowTreeNode node;
    if(!MLShadowParseTreeRow(line, model_role, node))
    {
      FileClose(handle);
      if(fatal)
        return MLShadowMarkUnavailable("bad_tree_row:" + model_role);
      return false;
    }

    int total = ArraySize(nodes);
    if(total >= ML_SHADOW_MAX_TREE_NODES)
    {
      FileClose(handle);
      if(fatal)
        return MLShadowMarkUnavailable("tree_node_limit_exceeded:" + model_role);
      return false;
    }

    ArrayResize(nodes,
                total + 1,
                ML_SHADOW_TREE_NODE_RESERVE);
    nodes[total] = node;
  }

  FileClose(handle);

  if(!MLShadowValidateTreeNodes(nodes, expected_tree_count, model_role))
  {
    if(fatal)
      return MLShadowMarkUnavailable("tree_validation_failed:" + model_role);
    return false;
  }

  return true;
}

bool MLShadowLoadTrees()
{
  if(!MLShadowLoadTreeFile(MLShadowArtifactPath(ML_SHADOW_CLASSIFIER_TREES_FILE),
                           "classifier",
                           g_ml_shadow_state.classifier_tree_count,
                           g_ml_shadow_classifier_nodes,
                           true))
    return false;

  if(g_ml_shadow_state.regressor_available &&
     g_ml_shadow_state.regressor_tree_count > 0)
  {
    string regressor_filename = MLShadowArtifactPath(ML_SHADOW_REGRESSOR_TREES_FILE);
    if(!FileIsExist(regressor_filename, FILE_COMMON) ||
       !MLShadowLoadTreeFile(regressor_filename,
                             "regressor",
                             g_ml_shadow_state.regressor_tree_count,
                             g_ml_shadow_regressor_nodes,
                             false))
    {
      g_ml_shadow_state.regressor_available = false;
      g_ml_shadow_state.regressor_tree_count = 0;
      ArrayResize(g_ml_shadow_regressor_nodes, 0, ML_SHADOW_TREE_NODE_RESERVE);
    }
  }

  return true;
}

string DeterministicSignalMLShadowEnsureSignalId(SignalParams &signal_params)
{
  if(signal_params.deterministic_stats_signal_id != "")
  {
    signal_params.ml_shadow_signal_id = signal_params.deterministic_stats_signal_id;
    return signal_params.ml_shadow_signal_id;
  }

  if(signal_params.ml_shadow_signal_id != "")
    return signal_params.ml_shadow_signal_id;

  if(!signal_params.deterministic_strategy ||
     g_ml_shadow_state.shadow_run_id == "")
    return "";

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildExtremumEngineSignalSourceKey(signal_params);

  string payload = g_ml_shadow_state.shadow_run_id + "|" +
                   source_key + "|" +
                   IntegerToString(signal_params.deterministic_source_attempt_index);
  signal_params.ml_shadow_signal_id = "sig_" + DeterministicSignalStatsHashToken(payload);
  return signal_params.ml_shadow_signal_id;
}

bool MLShadowSnapshotNumericValue(const DeterministicSignalFeatureSnapshot &snapshot,
                                  const string source_column,
                                  double &value_out,
                                  bool &valid_out)
{
  value_out = 0.0;
  valid_out = true;

  if(source_column == "macro_h1_slope")
    value_out = (double)snapshot.macro_h1_slope;
  else if(source_column == "macro_h4_slope")
    value_out = (double)snapshot.macro_h4_slope;
  else if(source_column == "macro_d1_slope")
    value_out = (double)snapshot.macro_d1_slope;
  else if(source_column == "stoch_structure_raw_percent")
  {
    value_out = snapshot.stoch_structure_raw_percent;
    valid_out = snapshot.stoch_structure_raw_percent_valid;
  }
  else if(source_column == "b_percent_main_base")
  {
    value_out = snapshot.b_percent_main_base;
    valid_out = snapshot.b_percent_main_base_valid;
  }
  else if(source_column == "b_percent_main_base_slope")
  {
    value_out = snapshot.b_percent_main_base_slope;
    valid_out = snapshot.b_percent_main_base_slope_valid;
  }
  else if(source_column == "b_percent_main_macro")
  {
    value_out = snapshot.b_percent_main_macro;
    valid_out = snapshot.b_percent_main_macro_valid;
  }
  else if(source_column == "b_percent_main_macro_slope")
  {
    value_out = snapshot.b_percent_main_macro_slope;
    valid_out = snapshot.b_percent_main_macro_slope_valid;
  }
  else if(source_column == "time_sin")
  {
    value_out = snapshot.time_sin;
    valid_out = snapshot.time_sin_valid;
  }
  else if(source_column == "time_cos")
  {
    value_out = snapshot.time_cos;
    valid_out = snapshot.time_cos_valid;
  }
  else
  {
    valid_out = false;
    return false;
  }

  if(!MathIsValidNumber(value_out))
    valid_out = false;
  return true;
}

bool MLShadowSnapshotCategoryValue(const DeterministicSignalFeatureSnapshot &snapshot,
                                   const string source_column,
                                   string &value_out)
{
  value_out = "";
  if(source_column == "strategy_label")
    value_out = snapshot.strategy_label;
  else if(source_column == "direction")
    value_out = snapshot.direction;
  else if(source_column == "structure_0")
    value_out = snapshot.structure_0_valid ? snapshot.structure_0 : "";
  else if(source_column == "structure_1")
    value_out = snapshot.structure_1_valid ? snapshot.structure_1 : "";
  else if(source_column == "structure_2")
    value_out = snapshot.structure_2_valid ? snapshot.structure_2 : "";
  else if(source_column == "fib_sl_band")
    value_out = snapshot.fib_sl_band_valid ? snapshot.fib_sl_band : "";
  else if(source_column == "fib_entry_band")
    value_out = snapshot.fib_entry_band_valid ? snapshot.fib_entry_band : "";
  else if(source_column == "high_chain_profile")
    value_out = snapshot.high_chain_profile_valid ? snapshot.high_chain_profile : "";
  else if(source_column == "low_chain_profile")
    value_out = snapshot.low_chain_profile_valid ? snapshot.low_chain_profile : "";
  else if(source_column == "previous_candle_profile")
    value_out = snapshot.previous_candle_profile_valid ? snapshot.previous_candle_profile : "";
  else if(source_column == "entry_session_bucket")
    value_out = snapshot.entry_session_bucket_valid ? snapshot.entry_session_bucket : "";
  else if(source_column == "session_id")
    value_out = snapshot.session_id_valid ? snapshot.session_id : "";
  else if(source_column == "entry_weekday")
    value_out = snapshot.entry_weekday_valid ? snapshot.entry_weekday : "";
  else
    return false;

  return true;
}

bool DeterministicSignalMLShadowEncodeSnapshot(const DeterministicSignalFeatureSnapshot &snapshot,
                                               double &features[],
                                               bool &missing_features[],
                                               bool &feature_valid_out,
                                               string &invalid_reason_out)
{
  feature_valid_out = snapshot.valid;
  invalid_reason_out = snapshot.invalid_reasons;

  int feature_count = ArraySize(g_ml_shadow_feature_map);
  if(feature_count <= 0 ||
     feature_count != g_ml_shadow_state.encoded_feature_count)
  {
    feature_valid_out = false;
    invalid_reason_out = "feature_map_unavailable";
    return false;
  }

  ArrayResize(features, feature_count);
  ArrayResize(missing_features, feature_count);
  for(int i = 0; i < feature_count; i++)
  {
    features[i] = 0.0;
    missing_features[i] = false;
  }

  for(int i = 0; i < feature_count; i++)
  {
    MLShadowFeatureMapRow map_row = g_ml_shadow_feature_map[i];
    if(map_row.encoded_index < 0 ||
       map_row.encoded_index >= feature_count)
      return false;

    if(map_row.encoding_type == "numeric")
    {
      double numeric_value = 0.0;
      bool numeric_valid = false;
      if(!MLShadowSnapshotNumericValue(snapshot,
                                       map_row.source_column,
                                       numeric_value,
                                       numeric_valid))
      {
        feature_valid_out = false;
        invalid_reason_out = "unknown_numeric_feature:" + map_row.source_column;
        return false;
      }

      if(numeric_valid)
        features[map_row.encoded_index] = numeric_value;
      else
      {
        missing_features[map_row.encoded_index] = true;
        feature_valid_out = false;
        if(invalid_reason_out != "")
          invalid_reason_out = invalid_reason_out + ",";
        invalid_reason_out = invalid_reason_out + map_row.source_column;
      }
    }
    else if(map_row.encoding_type == "one_hot")
    {
      string category_value = "";
      if(!MLShadowSnapshotCategoryValue(snapshot,
                                        map_row.source_column,
                                        category_value))
      {
        feature_valid_out = false;
        invalid_reason_out = "unknown_category_feature:" + map_row.source_column;
        return false;
      }

      if(category_value == "")
        features[map_row.encoded_index] = (map_row.category == "__MISSING__") ? 1.0 : 0.0;
      else
        features[map_row.encoded_index] = (category_value == map_row.category) ? 1.0 : 0.0;
    }
    else
      return false;
  }

  return true;
}

bool MLShadowScoreTree(const MLShadowTreeNode &nodes[],
                       const int tree_index,
                       const double &features[],
                       const bool &missing_features[],
                       double &score_out)
{
  score_out = 0.0;
  int node_position = MLShadowFindTreeNode(nodes, tree_index, 0);
  if(node_position < 0)
    return false;

  int guard = 0;
  while(!nodes[node_position].leaf)
  {
    int feature_index = nodes[node_position].feature_index;
    if(feature_index < 0 || feature_index >= ArraySize(features))
      return false;

    bool go_left = false;
    if(missing_features[feature_index])
      go_left = nodes[node_position].default_left;
    else
    {
      float feature_value = (float)features[feature_index];
      float threshold = (float)nodes[node_position].threshold;
      go_left = (feature_value < threshold);
    }

    int next_node = go_left ? nodes[node_position].left_child : nodes[node_position].right_child;
    node_position = MLShadowFindTreeNode(nodes, tree_index, next_node);
    if(node_position < 0)
      return false;

    guard++;
    if(guard > ML_SHADOW_MAX_TREE_NODES)
      return false;
  }

  score_out = nodes[node_position].leaf_value;
  return MathIsValidNumber(score_out);
}

bool MLShadowScoreForest(const MLShadowTreeNode &nodes[],
                         const int tree_count,
                         const double base_score,
                         const double &features[],
                         const bool &missing_features[],
                         double &margin_out)
{
  margin_out = base_score;
  if(tree_count <= 0)
    return false;

  for(int tree_index = 0; tree_index < tree_count; tree_index++)
  {
    double tree_score = 0.0;
    if(!MLShadowScoreTree(nodes,
                          tree_index,
                          features,
                          missing_features,
                          tree_score))
      return false;
    margin_out += tree_score;
  }

  return MathIsValidNumber(margin_out);
}

bool MLShadowScoreClassifier(const double &features[],
                             const bool &missing_features[],
                             double &score_out)
{
  score_out = 0.0;
  double margin = 0.0;
  if(!MLShadowScoreForest(g_ml_shadow_classifier_nodes,
                          g_ml_shadow_state.classifier_tree_count,
                          g_ml_shadow_state.classifier_base_score,
                          features,
                          missing_features,
                          margin))
    return false;

  score_out = 1.0 / (1.0 + MathExp(-margin));
  return MathIsValidNumber(score_out);
}

bool MLShadowScoreRegressor(const double &features[],
                            const bool &missing_features[],
                            double &score_out)
{
  score_out = 0.0;
  if(!g_ml_shadow_state.regressor_available ||
     g_ml_shadow_state.regressor_tree_count <= 0)
    return false;

  return MLShadowScoreForest(g_ml_shadow_regressor_nodes,
                             g_ml_shadow_state.regressor_tree_count,
                             g_ml_shadow_state.regressor_base_score,
                             features,
                             missing_features,
                             score_out);
}

string MLShadowRecommendationToken(const bool scored,
                                   const double classifier_score)
{
  if(!scored)
    return "NO_SCORE";
  if(classifier_score >= g_ml_shadow_state.threshold_probability)
    return "ALLOW";
  return "BLOCK";
}

bool DeterministicSignalMLShadowEvaluateDecision(SignalParams &signal_params,
                                                 const ExecutionLegState &leg_state,
                                                 MLShadowDecisionResult &decision_out)
{
  decision_out = MLShadowDecisionResult();
  decision_out.model_available = g_ml_shadow_state.available;
  decision_out.threshold_probability = g_ml_shadow_state.threshold_probability;

  if(!g_ml_shadow_state.enabled)
  {
    decision_out.reason = "ml_disabled";
    return false;
  }
  if(!signal_params.deterministic_strategy)
  {
    decision_out.reason = "not_deterministic_strategy";
    return false;
  }

  string signal_id = DeterministicSignalMLShadowEnsureSignalId(signal_params);
  decision_out.signal_id = signal_id;
  decision_out.signal_id_valid = (signal_id != "");
  if(!decision_out.signal_id_valid)
  {
    decision_out.reason = "missing_signal_id";
    return false;
  }

  DeterministicSignalFeatureSnapshot snapshot;
  if(!DeterministicSignalBuildFeatureSnapshot(signal_params,
                                              leg_state,
                                              snapshot))
  {
    decision_out.reason = "feature_snapshot_failed";
    return false;
  }

  decision_out.snapshot = snapshot;
  decision_out.snapshot_valid = true;
  decision_out.feature_valid = snapshot.valid;

  if(!g_ml_shadow_state.available)
  {
    decision_out.reason = "ML_UNAVAILABLE:" + g_ml_shadow_state.unavailable_reason;
  }
  else
  {
    double features[];
    bool missing_features[];
    string invalid_reason = "";
    bool encoding_ok = DeterministicSignalMLShadowEncodeSnapshot(snapshot,
                                                                 features,
                                                                 missing_features,
                                                                 decision_out.feature_valid,
                                                                 invalid_reason);
    if(!encoding_ok)
    {
      decision_out.reason = "encoding_failed:" + invalid_reason;
      decision_out.feature_valid = false;
    }
    else if(!decision_out.feature_valid)
    {
      decision_out.reason = "invalid_features:" + invalid_reason;
      g_ml_shadow_state.invalid_feature_rows++;
    }
    else if(!MLShadowScoreClassifier(features,
                                     missing_features,
                                     decision_out.classifier_score))
    {
      decision_out.reason = "classifier_score_failed";
    }
    else
    {
      decision_out.classifier_scored = true;
      decision_out.model_admits_entry = (decision_out.classifier_score >=
                                         g_ml_shadow_state.threshold_probability);
      decision_out.reason = decision_out.model_admits_entry ?
                            "classifier_score_gte_threshold" :
                            "classifier_score_lt_threshold";
      if(MLShadowScoreRegressor(features,
                                missing_features,
                                decision_out.regressor_score))
        decision_out.regressor_scored = true;
    }
  }

  decision_out.recommendation = MLShadowRecommendationToken(decision_out.classifier_scored,
                                                           decision_out.classifier_score);
  return decision_out.classifier_scored;
}

void MLShadowApplyDecisionToSignal(SignalParams &signal_params,
                                   const MLShadowDecisionResult &decision)
{
  signal_params.ml_shadow_model_id = g_ml_shadow_state.model_id;
  signal_params.ml_shadow_export_id = g_ml_shadow_state.export_id;
  signal_params.ml_shadow_threshold = g_ml_shadow_state.threshold_probability;
  signal_params.ml_shadow_available = decision.model_available;
  signal_params.ml_shadow_feature_valid = decision.feature_valid;
  signal_params.ml_shadow_classifier_scored = decision.classifier_scored;
  signal_params.ml_shadow_regressor_scored = decision.regressor_scored;
  signal_params.ml_shadow_classifier_score = decision.classifier_score;
  signal_params.ml_shadow_regressor_score = decision.regressor_score;
  signal_params.ml_shadow_recommendation = decision.recommendation;
  signal_params.ml_shadow_reason = decision.reason;
}

string MLShadowPredictionRow(const SignalParams &signal_params,
                             const DeterministicSignalFeatureSnapshot &snapshot,
                             const bool classifier_scored,
                             const double classifier_score,
                             const bool regressor_scored,
                             const double regressor_score,
                             const string recommendation,
                             const string reason,
                             const bool feature_valid,
                             const bool model_available,
                             const string admission_action,
                             const string filter_reason)
{
  return IntegerToString(ML_SHADOW_ARTIFACT_SCHEMA_VERSION) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.shadow_run_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.export_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.model_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.dataset_id) + "\t" +
         IntegerToString(g_ml_shadow_state.phase1_schema_version) + "\t" +
         MLShadowOutputCell(signal_params.ml_shadow_signal_id) + "\t" +
         MLShadowOutputCell(snapshot.source_key) + "\t" +
         IntegerToString(snapshot.source_attempt_index) + "\t" +
         MLShadowOutputCell(snapshot.symbol) + "\t" +
         IntegerToString(snapshot.strategy_id) + "\t" +
         MLShadowOutputCell(snapshot.strategy_label) + "\t" +
         MLShadowOutputCell(snapshot.direction) + "\t" +
         MLShadowOutputCell(snapshot.source_type) + "\t" +
         MLShadowTimeToken(snapshot.entry_time) + "\t" +
         MLShadowDoubleToken(classifier_scored, classifier_score, 8) + "\t" +
         MLShadowDoubleToken(regressor_scored, regressor_score, 8) + "\t" +
         MLShadowDoubleToken(g_ml_shadow_state.available, g_ml_shadow_state.threshold_probability, 8) + "\t" +
         MLShadowOutputCell(recommendation) + "\t" +
         MLShadowOutputCell(reason) + "\t" +
         MLShadowBoolToken(feature_valid) + "\t" +
         MLShadowBoolToken(model_available) + "\t" +
         MLShadowOutputCell(snapshot.structure_0_valid ? snapshot.structure_0 : "") + "\t" +
         MLShadowOutputCell(snapshot.structure_1_valid ? snapshot.structure_1 : "") + "\t" +
         MLShadowOutputCell(snapshot.structure_2_valid ? snapshot.structure_2 : "") + "\t" +
         IntegerToString(snapshot.macro_h1_slope) + "\t" +
         IntegerToString(snapshot.macro_h4_slope) + "\t" +
         IntegerToString(snapshot.macro_d1_slope) + "\t" +
         MLShadowOutputCell(snapshot.fib_sl_band_valid ? snapshot.fib_sl_band : "") + "\t" +
         MLShadowOutputCell(snapshot.fib_entry_band_valid ? snapshot.fib_entry_band : "") + "\t" +
         MLShadowOutputCell(snapshot.high_chain_profile_valid ? snapshot.high_chain_profile : "") + "\t" +
         MLShadowOutputCell(snapshot.low_chain_profile_valid ? snapshot.low_chain_profile : "") + "\t" +
         MLShadowOutputCell(snapshot.previous_candle_profile_valid ? snapshot.previous_candle_profile : "") + "\t" +
         MLShadowOutputCell(snapshot.entry_session_bucket_valid ? snapshot.entry_session_bucket : "") + "\t" +
         MLShadowOutputCell(snapshot.entry_weekday_valid ? snapshot.entry_weekday : "") + "\t" +
         MLShadowDoubleToken(snapshot.stoch_structure_raw_percent_valid, snapshot.stoch_structure_raw_percent, 6) + "\t" +
         MLShadowDoubleToken(snapshot.b_percent_main_base_valid, snapshot.b_percent_main_base, 6) + "\t" +
         MLShadowDoubleToken(snapshot.b_percent_main_base_slope_valid, snapshot.b_percent_main_base_slope, 6) + "\t" +
         MLShadowDoubleToken(snapshot.b_percent_main_macro_valid, snapshot.b_percent_main_macro, 6) + "\t" +
         MLShadowDoubleToken(snapshot.b_percent_main_macro_slope_valid, snapshot.b_percent_main_macro_slope, 6) + "\t" +
         MLShadowOutputCell(snapshot.session_id_valid ? snapshot.session_id : "") + "\t" +
         MLShadowDoubleToken(snapshot.time_sin_valid, snapshot.time_sin, 9) + "\t" +
         MLShadowDoubleToken(snapshot.time_cos_valid, snapshot.time_cos, 9) + "\t" +
         MLShadowOutputCell(ExecutionMLInferenceModeToken(ML_Inference_Mode)) + "\t" +
         MLShadowOutputCell(admission_action) + "\t" +
         MLShadowOutputCell(filter_reason);
}

bool DeterministicSignalMLShadowRecordDecisionPrediction(SignalParams &signal_params,
                                                         const MLShadowDecisionResult &decision,
                                                         const string log_label,
                                                         const string admission_action,
                                                         const string filter_reason)
{
  if(!decision.signal_id_valid || !decision.snapshot_valid)
    return false;

  string row = MLShadowPredictionRow(signal_params,
                                     decision.snapshot,
                                     decision.classifier_scored,
                                     decision.classifier_score,
                                     decision.regressor_scored,
                                     decision.regressor_score,
                                     decision.recommendation,
                                     decision.reason,
                                     decision.feature_valid,
                                     decision.model_available,
                                     admission_action,
                                     filter_reason);
  if(MLShadowQueueRow(MLShadowOutputPath(ML_SHADOW_PREDICTIONS_FILE),
                      ML_SHADOW_PREDICTIONS_HEADER,
                      row,
                      g_ml_shadow_prediction_buffer))
    g_ml_shadow_state.prediction_rows++;

  ExecutionAppendQueryDebugLog(log_label,
                               StringFormat("signal_id=%s|source_key=%s|score=%s|threshold=%s|recommendation=%s|reason=%s|feature_valid=%s|model_available=%s|admission_action=%s|filter_reason=%s",
                                            signal_params.ml_shadow_signal_id,
                                            decision.snapshot.source_key,
                                            MLShadowDoubleToken(decision.classifier_scored, decision.classifier_score, 8),
                                            MLShadowDoubleToken(decision.model_available, decision.threshold_probability, 8),
                                            decision.recommendation,
                                            decision.reason,
                                            MLShadowBoolToken(decision.feature_valid),
                                            MLShadowBoolToken(decision.model_available),
                                            admission_action,
                                            filter_reason));
  return true;
}

bool DeterministicSignalMLShadowRecordPrediction(SignalParams &signal_params,
                                                 const ExecutionLegState &leg_state)
{
  if(!g_ml_shadow_state.enabled)
    return false;
  if(!signal_params.deterministic_strategy)
    return false;
  if(signal_params.ml_shadow_evaluated)
    return false;

  signal_params.ml_shadow_evaluated = true;

  MLShadowDecisionResult decision;
  DeterministicSignalMLShadowEvaluateDecision(signal_params,
                                              leg_state,
                                              decision);
  MLShadowApplyDecisionToSignal(signal_params, decision);
  if(!decision.signal_id_valid || !decision.snapshot_valid)
    return false;

  DeterministicSignalMLShadowRecordDecisionPrediction(signal_params,
                                                      decision,
                                                      "ML_SHADOW_SCORE",
                                                      "OBSERVE",
                                                      "");
  return decision.classifier_scored;
}

string MLFilterBlockReason(const MLShadowDecisionResult &decision)
{
  if(!DeterministicSignalMLFilterTesterAllowed())
    return "filter_not_allowed_outside_tester";
  if(!decision.signal_id_valid)
    return "missing_signal_id";
  if(!decision.snapshot_valid)
    return "feature_snapshot_failed";
  if(!decision.model_available)
    return "model_unavailable:" + g_ml_shadow_state.unavailable_reason;
  if(!decision.feature_valid)
    return decision.reason;
  if(!decision.classifier_scored)
    return decision.reason;
  if(!decision.model_admits_entry)
    return decision.reason;
  return "";
}

void MLFilterRegisterDecisionCounters(const bool allowed,
                                      const MLShadowDecisionResult &decision,
                                      const string filter_reason)
{
  if(allowed)
  {
    g_ml_shadow_state.filter_allow_rows++;
    return;
  }

  g_ml_shadow_state.filter_block_rows++;

  if(filter_reason == "filter_not_allowed_outside_tester" ||
     !decision.model_available)
    g_ml_shadow_state.filter_unavailable_blocks++;

  if(!decision.signal_id_valid ||
     !decision.snapshot_valid ||
     !decision.feature_valid)
    g_ml_shadow_state.filter_invalid_feature_blocks++;
}

bool DeterministicSignalMLFilterAllowsEntry(SignalParams &signal_params,
                                            const ExecutionLegState &leg_state,
                                            string &block_reason_out)
{
  block_reason_out = "";

  if(!DeterministicSignalMLFilterMode())
    return true;

  if(signal_params.ml_shadow_evaluated)
  {
    bool previously_allowed = (signal_params.ml_shadow_recommendation == "ALLOW" &&
                               signal_params.ml_shadow_available &&
                               signal_params.ml_shadow_feature_valid);
    if(!previously_allowed)
      block_reason_out = signal_params.ml_shadow_reason;
    return previously_allowed;
  }

  signal_params.ml_shadow_evaluated = true;

  MLShadowDecisionResult decision;
  DeterministicSignalMLShadowEvaluateDecision(signal_params,
                                              leg_state,
                                              decision);
  MLShadowApplyDecisionToSignal(signal_params, decision);

  string filter_reason = MLFilterBlockReason(decision);
  bool allowed = (filter_reason == "");
  string admission_action = allowed ? "ALLOW" : "BLOCK";
  string log_label = allowed ? "ML_FILTER_ALLOW" : "ML_FILTER_BLOCK";
  MLFilterRegisterDecisionCounters(allowed, decision, filter_reason);

  if(decision.signal_id_valid && decision.snapshot_valid)
  {
    DeterministicSignalMLShadowRecordDecisionPrediction(signal_params,
                                                       decision,
                                                       log_label,
                                                       admission_action,
                                                       filter_reason);
  }
  else
  {
    ExecutionAppendQueryDebugLog(log_label,
                                 StringFormat("signal_id=%s|recommendation=%s|reason=%s|admission_action=%s|row_recorded=false",
                                              signal_params.ml_shadow_signal_id,
                                              decision.recommendation,
                                              filter_reason,
                                              admission_action));
  }

  if(!allowed)
    block_reason_out = filter_reason;

  return allowed;
}

string MLShadowOutcomeRow(SignalParams &signal_params,
                          const double profit_r,
                          const bool profit_r_valid,
                          const int duration_seconds,
                          const bool duration_valid)
{
  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildExtremumEngineSignalSourceKey(signal_params);

  return IntegerToString(ML_SHADOW_ARTIFACT_SCHEMA_VERSION) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.shadow_run_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.export_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.model_id) + "\t" +
         MLShadowOutputCell(signal_params.ml_shadow_signal_id) + "\t" +
         MLShadowOutputCell(source_key) + "\t" +
         IntegerToString(signal_params.deterministic_source_attempt_index) + "\t" +
         MLShadowTimeToken(signal_params.close_time) + "\t" +
         MLShadowOutputCell(DeterministicSignalStatsTerminalReason(signal_params)) + "\t" +
         MLShadowOutputCell(signal_params.ml_shadow_recommendation) + "\t" +
         MLShadowDoubleToken(signal_params.ml_shadow_evaluated, signal_params.ml_shadow_classifier_score, 8) + "\t" +
         MLShadowDoubleToken(g_ml_shadow_state.available, signal_params.ml_shadow_threshold, 8) + "\t" +
         MLShadowDoubleToken(profit_r_valid, profit_r, 4) + "\t" +
         MLShadowDoubleToken(MathIsValidNumber(signal_params.raw_profit), signal_params.raw_profit, 2) + "\t" +
         MLShadowIntToken(duration_valid, duration_seconds);
}

bool DeterministicSignalMLShadowRecordOutcome(SignalParams &signal_params)
{
  if(!g_ml_shadow_state.enabled)
    return false;
  if(!signal_params.deterministic_strategy ||
     !signal_params.ml_shadow_evaluated ||
     signal_params.ml_shadow_outcome_exported)
    return false;
  if(!SignalHasBrokerConfirmedOutcome(signal_params))
    return false;

  if(signal_params.ml_shadow_signal_id == "")
    DeterministicSignalMLShadowEnsureSignalId(signal_params);
  if(signal_params.ml_shadow_signal_id == "")
    return false;

  double entry_price = 0.0;
  bool entry_price_valid = DeterministicSignalStatsOutcomeEntryPrice(signal_params,
                                                                     entry_price);
  bool close_price_valid = (signal_params.close_price > 0.0 &&
                            MathIsValidNumber(signal_params.close_price));

  double profit_r = 0.0;
  bool profit_r_valid = entry_price_valid && close_price_valid &&
                        DeterministicSignalStatsProfitR(signal_params,
                                                        entry_price,
                                                        signal_params.close_price,
                                                        profit_r);

  datetime entry_time = DeterministicSignalStatsOutcomeEntryTime(signal_params);
  bool duration_valid = (entry_time > 0 &&
                         signal_params.close_time > 0 &&
                         signal_params.close_time >= entry_time);
  int duration_seconds = 0;
  if(duration_valid)
    duration_seconds = (int)(signal_params.close_time - entry_time);

  string row = MLShadowOutcomeRow(signal_params,
                                  profit_r,
                                  profit_r_valid,
                                  duration_seconds,
                                  duration_valid);
  if(!MLShadowQueueRow(MLShadowOutputPath(ML_SHADOW_OUTCOMES_FILE),
                       ML_SHADOW_OUTCOMES_HEADER,
                       row,
                       g_ml_shadow_outcome_buffer))
    return false;

  signal_params.ml_shadow_outcome_exported = true;
  g_ml_shadow_state.outcome_rows++;
  return true;
}

string MLShadowSummaryRow(const datetime finished_at,
                          const string export_status)
{
  return IntegerToString(ML_SHADOW_ARTIFACT_SCHEMA_VERSION) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.shadow_run_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.export_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.model_id) + "\t" +
         MLShadowTimeToken(g_ml_shadow_state.started_at) + "\t" +
         MLShadowTimeToken(finished_at) + "\t" +
         IntegerToString(g_ml_shadow_state.prediction_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.outcome_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.invalid_feature_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.unavailable_events) + "\t" +
         IntegerToString(g_ml_shadow_state.filter_allow_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.filter_block_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.filter_invalid_feature_blocks) + "\t" +
         IntegerToString(g_ml_shadow_state.filter_unavailable_blocks) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_group_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_single_candidate_groups) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_multi_candidate_groups) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_selected_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_blocked_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_classifier_tie_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_regressor_tie_rows) + "\t" +
         IntegerToString(g_ml_shadow_state.arbitration_strategy_tie_break_rows) + "\t" +
         MLShadowOutputCell(export_status);
}

bool MLShadowWriteSummary()
{
  if(!g_ml_shadow_state.enabled || g_ml_shadow_state.shadow_folder == "")
    return false;

  string filename = MLShadowOutputPath(ML_SHADOW_SUMMARY_FILE);
  if(!MLShadowWriteLine(filename, ML_SHADOW_SUMMARY_HEADER, false))
    return false;

  string status = g_ml_shadow_state.export_failed ? "FAILED" : "OK";
  return MLShadowWriteLine(filename,
                           MLShadowSummaryRow(TimeCurrent(), status),
                           true);
}

bool DeterministicSignalMLShadowInit()
{
  DeterministicSignalMLShadowReset();

  g_ml_shadow_state.enabled = DeterministicSignalMLShadowEnabled();
  g_ml_shadow_state.export_id = DeterministicSignalStatsSanitizePart(ML_Model_Export_Id);
  g_ml_shadow_state.artifact_folder = MLShadowBuildArtifactFolder();
  g_ml_shadow_state.shadow_run_id = MLShadowBuildShadowRunId();
  g_ml_shadow_state.shadow_folder = MLShadowBuildShadowFolder();
  g_ml_shadow_state.started_at = TimeCurrent();

  if(!g_ml_shadow_state.enabled)
    return true;

  bool folder_ok = MLShadowEnsureFolder();
  bool load_ok = false;

  if(DeterministicSignalMLFilterMode() &&
     !DeterministicSignalMLFilterTesterAllowed())
    MLShadowMarkUnavailable("filter_not_allowed_outside_tester");
  else if(!folder_ok)
    MLShadowMarkUnavailable("shadow_folder_unavailable");
  else if(g_ml_shadow_state.export_id == "")
    MLShadowMarkUnavailable("empty_export_id");
  else if(MLShadowLoadManifest() &&
          MLShadowLoadThresholdPolicy() &&
          MLShadowLoadFeatureMap() &&
          MLShadowLoadTrees())
    load_ok = true;

  if(load_ok)
  {
    g_ml_shadow_state.available = true;
    g_ml_shadow_state.unavailable_reason = "";
    g_ml_shadow_state.loaded_at = TimeCurrent();
  }

  if(folder_ok)
  {
    MLShadowWriteRunManifest();
    MLShadowPrepareRowFiles();
  }

  MLShadowLogLoadStatus();
  return true;
}

void DeterministicSignalMLShadowDeinit()
{
  if(g_ml_shadow_state.enabled)
  {
    if(!MLShadowFlushAll())
      g_ml_shadow_state.export_failed = true;
    MLShadowWriteSummary();
  }
  DeterministicSignalMLShadowReset();
}

#endif // _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_
