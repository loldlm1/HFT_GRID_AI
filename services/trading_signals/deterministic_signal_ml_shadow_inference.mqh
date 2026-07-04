//+------------------------------------------------------------------+
//|        trading_signals/deterministic_signal_ml_shadow_inference  |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_
#define _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_

const int    ML_SHADOW_ARTIFACT_SCHEMA_VERSION = 1;
const int    ML_SHADOW_PHASE1_SCHEMA_VERSION   = 1;
const string ML_SHADOW_STORAGE_ROOT            = "DeterministicSignalML";
const string ML_SHADOW_MODEL_EXPORTS_FOLDER    = "model_exports";
const string ML_SHADOW_MANIFEST_FILE           = "model_manifest.tsv";
const string ML_SHADOW_FEATURE_MAP_FILE        = "feature_map.tsv";
const string ML_SHADOW_CLASSIFIER_TREES_FILE   = "classifier_trees.tsv";
const string ML_SHADOW_REGRESSOR_TREES_FILE    = "regressor_trees.tsv";
const string ML_SHADOW_THRESHOLD_POLICY_FILE   = "threshold_policy.tsv";
const int    ML_SHADOW_FEATURE_RESERVE         = 64;
const int    ML_SHADOW_TREE_NODE_RESERVE       = 512;
const int    ML_SHADOW_MANIFEST_RESERVE        = 48;
const int    ML_SHADOW_MAX_FEATURES            = 512;
const int    ML_SHADOW_MAX_TREE_NODES          = 20000;

struct MLShadowRuntimeState
{
  bool     enabled;
  bool     available;
  bool     classifier_available;
  bool     regressor_available;
  string   unavailable_reason;
  string   export_id;
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

  MLShadowRuntimeState()
  {
    enabled                 = false;
    available               = false;
    classifier_available    = false;
    regressor_available     = false;
    unavailable_reason      = "";
    export_id               = "";
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

MLShadowRuntimeState g_ml_shadow_state;
string               g_ml_shadow_manifest_keys[];
string               g_ml_shadow_manifest_values[];
MLShadowFeatureMapRow g_ml_shadow_feature_map[];
MLShadowTreeNode      g_ml_shadow_classifier_nodes[];
MLShadowTreeNode      g_ml_shadow_regressor_nodes[];

bool DeterministicSignalMLShadowEnabled()
{
  return (ML_Inference_Mode == ML_INFERENCE_SHADOW);
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

string MLShadowArtifactPath(const string filename)
{
  return g_ml_shadow_state.artifact_folder + "\\" + filename;
}

void MLShadowClearArrays()
{
  ArrayResize(g_ml_shadow_manifest_keys, 0, ML_SHADOW_MANIFEST_RESERVE);
  ArrayResize(g_ml_shadow_manifest_values, 0, ML_SHADOW_MANIFEST_RESERVE);
  ArrayResize(g_ml_shadow_feature_map, 0, ML_SHADOW_FEATURE_RESERVE);
  ArrayResize(g_ml_shadow_classifier_nodes, 0, ML_SHADOW_TREE_NODE_RESERVE);
  ArrayResize(g_ml_shadow_regressor_nodes, 0, ML_SHADOW_TREE_NODE_RESERVE);
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
  MLShadowLogUnavailable(reason);
  return false;
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

bool DeterministicSignalMLShadowInit()
{
  DeterministicSignalMLShadowReset();

  g_ml_shadow_state.enabled = DeterministicSignalMLShadowEnabled();
  g_ml_shadow_state.export_id = DeterministicSignalStatsSanitizePart(ML_Model_Export_Id);
  g_ml_shadow_state.artifact_folder = MLShadowBuildArtifactFolder();

  if(!g_ml_shadow_state.enabled)
    return true;

  if(g_ml_shadow_state.export_id == "")
    return MLShadowMarkUnavailable("empty_export_id");

  if(!MLShadowLoadManifest())
    return true;
  if(!MLShadowLoadThresholdPolicy())
    return true;
  if(!MLShadowLoadFeatureMap())
    return true;
  if(!MLShadowLoadTrees())
    return true;

  g_ml_shadow_state.available = true;
  g_ml_shadow_state.unavailable_reason = "";
  g_ml_shadow_state.loaded_at = TimeCurrent();
  MLShadowLogLoadStatus();
  return true;
}

void DeterministicSignalMLShadowDeinit()
{
  DeterministicSignalMLShadowReset();
}

#endif // _TS_DETERMINISTIC_SIGNAL_ML_SHADOW_INFERENCE_MQH_
