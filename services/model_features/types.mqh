#ifndef MODEL_TYPES_MQH
#define MODEL_TYPES_MQH

const string MODEL_NULL = "\\N";
const string MODEL_STORAGE_ROOT = "MQL5ModelDatasetV1";
const int MODEL_FLUSH_ROWS = 256;
const int MODEL_BATCH_BYTES = 1024 * 1024;
const int MODEL_WARMUP_LIMIT = 4096;
const int MODEL_CATCHUP_LIMIT = 256;
const int MODEL_AUDIT_SNAPSHOTS = 32;

struct ModelCaptureConfig
{
  bool enabled;
  string run_id;
  string engine;
  string symbol;
  ENUM_TIMEFRAMES macro;
  ENUM_TIMEFRAMES micro;
  bool exness;
  string lot_type;
  double lot_size;
  double reference_balance;
  int broker_cap;
  int virtual_cap;
  bool continuation;
  string source_id;
  string session_id;
  string source_proof;
  string configuration_proof;
  string history_proof;
  int segment_seconds;
  string replay_witness_id;
  string replay_witness_proof;
};

ModelCaptureConfig g_model_config;
bool g_model_open = false;
bool g_model_failed = false;
bool g_model_sealed = false;
bool g_model_stop_sent = false;
bool g_model_released = false;
string g_model_failure = "";
string g_model_root = "";
long g_model_first_time = 0;
long g_model_last_time = 0;
long g_model_sequence = 0;
long g_model_rows[MODEL_FILE_COUNT];
long g_model_feature_gaps = 0;
int g_model_buffer_peak = 0;
int g_model_handle_peak = 0;
double g_model_point = 0.0;
double g_model_tick_size = 0.0;
string g_model_specification = "";

bool ModelNumberValid(const double value)
{
  return MathIsValidNumber(value) && value != EMPTY_VALUE;
}

string ModelNumber(const double value)
{
  return ModelNumberValid(value) ? StringFormat("%.17g", value) : MODEL_NULL;
}

string ModelInteger(const long value) { return IntegerToString(value); }
string ModelBoolean(const bool value) { return value ? "1" : "0"; }
string ModelNullable(const string value) { return value == "" ? MODEL_NULL : value; }

bool ModelCellValid(const string value)
{
  int length = StringLen(value);
  if(length > 65536 || StringFind(value, "\t") >= 0 ||
     StringFind(value, "\r") >= 0 || StringFind(value, "\n") >= 0) return false;
  for(int i = 0; i < length; i++) if(StringGetCharacter(value, i) == 0) return false;
  return true;
}

bool ModelReady() { return g_model_config.enabled && g_model_open && !g_model_failed && !g_model_sealed; }
void ModelFail(const string reason);

void ModelCell(string &row, const string value)
{
  if(row != "") row += "\t";
  row += value;
}

struct ModelLayout
{
  string names[];
  string types;
  string nullable;
  string choices[];
  int clocks[];
  uchar header[];
  int header_bytes;
};
ModelLayout g_model_layout[MODEL_FILE_COUNT];

bool ModelInitLayouts()
{
  for(int file = 0; file < MODEL_FILE_COUNT; file++)
  {
    int count = StringSplit(ModelHeader(file), '\t', g_model_layout[file].names);
    g_model_layout[file].types = ModelTypes(file);
    g_model_layout[file].nullable = ModelNullability(file);
    g_model_layout[file].header_bytes = StringToCharArray(ModelHeader(file) + "\r\n",
      g_model_layout[file].header, 0, WHOLE_ARRAY, CP_UTF8) - 1;
    if(count <= 0 || count != StringLen(g_model_layout[file].types) ||
       count != StringLen(g_model_layout[file].nullable) || g_model_layout[file].header_bytes <= 0) return false;
    int raw_count = ModelRawColumnCount(file);
    if(ArrayResize(g_model_layout[file].choices, count) != count ||
       ArrayResize(g_model_layout[file].clocks, raw_count) != raw_count) return false;
    for(int i = 0; i < count; i++) g_model_layout[file].choices[i] = ModelAllowedValues(file, i);
    for(int i = 0; i < raw_count; i++)
    {
      int start = ModelClockColumn(file * MODEL_FIELD_STRIDE + i);
      bool clock = StringGetCharacter(g_model_layout[file].types, i) == 't';
      if(clock ? start < raw_count || start + 2 >= count : start != -1) return false;
      g_model_layout[file].clocks[i] = start;
    }
  }
  return true;
}

struct ModelRow
{
  int file;
  bool valid;
  string cells[];

  void Init(const int file_id)
  {
    file = file_id;
    valid = file >= 0 && file < MODEL_FILE_COUNT && ModelEngineFile(file, g_model_config.engine);
    if(!valid) { ModelFail("ROW_FILE"); return; }
    int count = ArraySize(g_model_layout[file].names);
    if(ArrayResize(cells, count) != count) { valid = false; ModelFail("ROW_ALLOCATION"); return; }
    for(int i = 0; i < count; i++) cells[i] = MODEL_NULL;
    if(count > 0 && g_model_layout[file].names[0] == "run_id") cells[0] = g_model_config.run_id;
  }

  int Index(const int field, const ushort type)
  {
    if(!valid) return -1;
    int index = field % MODEL_FIELD_STRIDE;
    if(field < 0 || field / MODEL_FIELD_STRIDE != file || index >= ModelRawColumnCount(file))
    {
      valid = false;
      ModelFail("UNKNOWN_FIELD_" + ModelInteger(field));
      return -1;
    }
    if(StringGetCharacter(g_model_layout[file].types, index) != type)
    {
      valid = false;
      ModelFail("FIELD_TYPE_" + g_model_layout[file].names[index]);
      return -1;
    }
    return index;
  }

  void Assign(const int field, const string value, const ushort type)
  {
    int index = Index(field, type);
    if(index >= 0) cells[index] = value;
  }

  void Set(const int field, const string value) { Assign(field, value, 's'); }
  void Number(const int field, const double value) { Assign(field, ModelNumber(value), 'd'); }
  void Integer(const int field, const long value) { Assign(field, ModelInteger(value), 'i'); }
  void Flag(const int field, const bool value) { Assign(field, ModelBoolean(value), 'b'); }

  void Clock(const int field, const long raw_msc, const bool seconds = false)
  {
    int index = Index(field, 't');
    if(index < 0 || raw_msc <= 0) return;
    long analysis = 0;
    int offset = 0;
    if(!ModelAnalysisClock(raw_msc, g_model_config.exness, analysis, offset) ||
       (seconds && raw_msc % 1000 != 0))
    {
      valid = false;
      ModelFail("CLOCK_" + g_model_layout[file].names[index]);
      return;
    }
    int start = g_model_layout[file].clocks[index];
    if(start < ModelRawColumnCount(file) || start + 2 >= ArraySize(cells))
    { valid = false; ModelFail("CLOCK_LAYOUT"); return; }
    cells[index] = ModelInteger(raw_msc);
    cells[start] = ModelInteger(analysis);
    cells[start + 1] = ModelInteger(offset);
    cells[start + 2] = seconds ? "SECOND" : "MILLISECOND";
  }

  bool Serialize(string &text)
  {
    text = "";
    if(!valid) return false;
    int length = ArraySize(cells) - 1;
    for(int i = 0; i < ArraySize(cells); i++)
    {
      string value = cells[i];
      string choices = g_model_layout[file].choices[i];
      if(!ModelCellValid(value) || value == "" ||
         (value == MODEL_NULL && StringGetCharacter(g_model_layout[file].nullable, i) != '1') ||
         (value != MODEL_NULL && choices != "" && StringFind(choices, "|" + value + "|") < 0))
      {
        ModelFail("INVALID_FIELD_" + ModelFileName(file) + "_" + g_model_layout[file].names[i]);
        return false;
      }
      length += StringLen(value);
    }
    if(!StringReserve(text, (uint)length + 1)) { ModelFail("ROW_ALLOCATION"); return false; }
    for(int i = 0; i < ArraySize(cells); i++)
    {
      if((i > 0 && !StringAdd(text, "\t")) || !StringAdd(text, cells[i]))
      { ModelFail("ROW_ALLOCATION"); return false; }
    }
    return true;
  }
};

string ModelLevel(const int level)
{
  switch(level)
  {
    case 0: return "S3"; case 1: return "S2"; case 2: return "S1";
    case 3: return "PP"; case 4: return "R1"; case 5: return "R2"; case 6: return "R3";
  }
  return "";
}

// FNV-1a records a bounded source prefix/configuration identity, not authentication.
ulong ModelFingerprint(const ulong previous, const string text)
{
  uchar bytes[];
  int count = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
  ulong value = previous;
  for(int i = 0; i < count - 1; i++) value = (value ^ (ulong)bytes[i]) * 1099511628211;
  return value;
}

string ModelFingerprintText(const ulong value) { return StringFormat("%016I64x", value); }

#endif
