#ifndef MODEL_CONTINUATION_MQH
#define MODEL_CONTINUATION_MQH

#include "continuation_schema.mqh"

// Capture only. No engine state, broker requests, sleeps or account activation.
bool ModelRunIdValid(const string id);
const string MODEL_CONTINUATION_ROOT = "MQL5ModelContinuationV1";
const int MODEL_CONTINUATION_BUFFER_BYTES = 1024 * 1024;
const int MODEL_CONTINUATION_MAX_PAYLOAD = 480 * 1024;
const int MODEL_CONTINUATION_INPUT_BLOCK_MS = 60000;
const int MODEL_CONTINUATION_INPUT_BLOCK_CALLBACKS = 65536;
bool ModelContinuationFlushInput(const string callback);

struct ModelContinuationBuffer
{
  int handle;
  uchar bytes[];
  int used;
  int pending_rows;
  long rows;
  long total_bytes;
  string chain;
};
ModelContinuationBuffer g_cont_buffers[MODEL_CONTINUATION_FILE_COUNT];

struct ModelContinuationReader
{
  int handle;
  uchar bytes[];
  int position;
  int available;
  long rows;
  long total_bytes;
  string chain;
};
ModelContinuationReader g_cont_replay_input, g_cont_replay_fact, g_cont_replay_birth, g_cont_replay_state;
bool g_cont_enabled = false;
bool g_cont_anchor_pending = false;
bool g_cont_segment_open = false;
bool g_cont_replaying = false;
bool g_cont_terminal = false;
bool g_cont_input_pending = false;
string g_cont_origin = "";
string g_cont_segment_root = "";
string g_cont_core_manifest = "";
string g_cont_core_summary = "";
string g_cont_previous_seal = "NONE";
string g_cont_previous_state = "NONE";
string g_cont_state_boundary = "";
string g_cont_state_hash = "";
string g_cont_input_chain = "";
string g_cont_history_chain = "";
long g_cont_history_observations = 0;
long g_cont_block_first_observer = 0;
ulong g_cont_block_first_monotonic = 0;
ulong g_cont_last_monotonic = 0;
long g_cont_maximum_observer_gap = 0;
ulong g_cont_maximum_monotonic_gap = 0;
long g_cont_maximum_quote_age = 0;
long g_cont_last_quote_age = 0;
long g_cont_broker_estimate = 0;
string g_cont_replay_root = "";
string g_cont_replay_state_next = "";
string g_cont_replay_input_next = "";
string g_cont_replay_expected_state = "";
string g_cont_replay_anchor_state = "";
long g_cont_replay_input_end = 0;
long g_cont_replay_fact_end = 0;
long g_cont_replay_birth_end = 0;
long g_cont_segment = 0;
long g_cont_input = 0;
long g_cont_fact = 0;
long g_cont_birth = 0;
long g_cont_record = 0;
long g_cont_segment_first_input = 0;
long g_cont_segment_first_fact = 0;
long g_cont_segment_first_birth = 0;
long g_cont_segment_first_record = 0;
long g_cont_segment_started = 0;
long g_cont_last_observer = 0;
long g_cont_block_first_input = 0;
long g_cont_block_first_time = 0;
long g_cont_block_last_time = 0;
long g_cont_block_available = 0;
long g_cont_block_unavailable = 0;
long g_cont_block_ticks = 0;
long g_cont_block_timers = 0;
long g_cont_block_trades = 0;
long g_cont_block_fresh_quotes = 0;
long g_cont_block_stale_quotes = 0;
long g_cont_block_missing_quotes = 0;
long g_cont_block_stale_ticks = 0;
long g_cont_block_stale_trades = 0;
bool g_cont_last_fresh = false;
bool g_cont_last_available = false;
bool g_cont_last_connected = false;
bool g_cont_last_synchronized = false;
bool g_cont_last_acquired = false;
string g_cont_last_quote = "";
string g_cont_last_transaction = "";

string ModelContinuationZero()
{
  return "0000000000000000000000000000000000000000000000000000000000000000";
}

int ModelContinuationNibble(const ushort value)
{
  if(value >= '0' && value <= '9') return value - '0';
  if(value >= 'a' && value <= 'f') return value - 'a' + 10;
  return -1;
}

string ModelContinuationHexBytes(const uchar &bytes[], const int count)
{
  string output;
  if(count < 0 || count > MODEL_CONTINUATION_BUFFER_BYTES ||
     !StringInit(output, count * 2, '0')) { ModelFail("CONTINUATION_HEX_CAP"); return ""; }
  string digits = "0123456789abcdef";
  for(int i = 0; i < count; i++)
    if(!StringSetCharacter(output, i * 2, StringGetCharacter(digits, bytes[i] >> 4)) ||
       !StringSetCharacter(output, i * 2 + 1, StringGetCharacter(digits, bytes[i] & 15)))
    { ModelFail("CONTINUATION_HEX_ENCODING"); return ""; }
  return output;
}

string ModelContinuationHex(const string text, const string context = "PAYLOAD")
{
  if(text == NULL) return MODEL_NULL;
  if(StringLen(text) == 0) return "-";
  uchar bytes[];
  ResetLastError();
  int copied = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
  int count = copied - 1;
  if(count < 0 || count > MODEL_CONTINUATION_MAX_PAYLOAD ||
     ArraySize(bytes) != copied || bytes[count] != 0)
  {
    if(!g_model_failed)
      PrintFormat("CONTINUATION_ENCODING_DIAGNOSTIC | context=%s | utf16_chars=%d | utf8_bytes=%d | native_error=%d | cap=%d",
                  context, StringLen(text), count, GetLastError(), MODEL_CONTINUATION_MAX_PAYLOAD);
    ModelFail("CONTINUATION_PAYLOAD_CAP");
    return "";
  }
  return ModelContinuationHexBytes(bytes, count);
}

bool ModelContinuationUnhex(const string text, uchar &bytes[])
{
  int count = StringLen(text) / 2;
  if(StringLen(text) % 2 != 0 || count > MODEL_CONTINUATION_BUFFER_BYTES ||
     ArrayResize(bytes, count) != count) return false;
  for(int i = 0; i < count; i++)
  {
    int high = ModelContinuationNibble(StringGetCharacter(text, i * 2));
    int low = ModelContinuationNibble(StringGetCharacter(text, i * 2 + 1));
    if(high < 0 || low < 0) return false;
    bytes[i] = (uchar)((high << 4) | low);
  }
  return true;
}

string ModelContinuationChain(const string previous, const string line)
{
  uchar bytes[], prefix[], combined[], key[], result[];
  if(!ModelContinuationUnhex(previous, prefix) || ArraySize(prefix) != 32)
  { ModelFail("CONTINUATION_DIGEST"); return ""; }
  int count = StringToCharArray(line, bytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
  if(count < 0 || count > MODEL_CONTINUATION_BUFFER_BYTES ||
     ArrayResize(combined, count + 32) != count + 32 ||
     ArrayCopy(combined, bytes, 32, 0, count) != count ||
     ArrayCopy(combined, prefix, 0, 0, 32) != 32 ||
     CryptEncode(CRYPT_HASH_SHA256, combined, key, result) != 32)
  { ModelFail("CONTINUATION_HASH"); return ""; }
  return ModelContinuationHexBytes(result, 32);
}

string ModelContinuationHashText(const string text)
{
  uchar bytes[], key[], result[];
  int count = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
  if(count < 0 || count > MODEL_CONTINUATION_BUFFER_BYTES ||
     ArrayResize(bytes, count) != count || CryptEncode(CRYPT_HASH_SHA256, bytes, key, result) != 32)
  { ModelFail("CONTINUATION_HASH"); return ""; }
  return ModelContinuationHexBytes(result, 32);
}

// Native NULL, explicit empty and UTF-8 text remain distinct without exposing comments.
string ModelContinuationPrivateTextHash(const string text)
{
  if(text == NULL) return ModelContinuationHashText("MQL5_NATIVE_NULL\r\n");
  if(text == "") return ModelContinuationHashText("MQL5_EMPTY\r\n");
  return ModelContinuationHashText("MQL5_UTF8\r\n" + text);
}

// Continuation causal inputs/checkpoints preserve every finite IEEE754 bit.
// EMPTY_VALUE is the finite DBL_MAX sentinel; signed zero also remains distinct.
union ModelContinuationDoubleBits
{
  double value;
  ulong bits;
};

string ModelContinuationNumber(const double value)
{
  if(!MathIsValidNumber(value)) { ModelFail("CONTINUATION_NONFINITE_STATE"); return MODEL_NULL; }
  ModelContinuationDoubleBits native;
  native.value = value;
  return StringFormat("%016I64x", native.bits);
}


void ModelContinuationHistory(const string role, const string source)
{
  if(!g_cont_enabled || g_model_failed) return;
  g_cont_history_observations++;
  g_cont_history_chain = ModelContinuationChain(g_cont_history_chain,
    ModelInteger(g_cont_history_observations) + "\t" + role + "\t" + source + "\r\n");
}

string ModelContinuationRate(const MqlRates &rate)
{
  string row = ModelInteger(rate.time);
  ModelCell(row, ModelContinuationNumber(rate.open)); ModelCell(row, ModelContinuationNumber(rate.high));
  ModelCell(row, ModelContinuationNumber(rate.low)); ModelCell(row, ModelContinuationNumber(rate.close));
  ModelCell(row, ModelInteger(rate.tick_volume)); ModelCell(row, ModelInteger(rate.spread));
  ModelCell(row, ModelInteger(rate.real_volume));
  return row;
}

string ModelContinuationSessions(const bool quote)
{
  string row = "";
  for(int day = 0; day < 7; day++)
    for(uint session = 0; session < 16; session++)
    {
      datetime first = 0, last = 0;
      bool found = quote ? SymbolInfoSessionQuote(g_model_config.symbol, (ENUM_DAY_OF_WEEK)day, session, first, last) :
                           SymbolInfoSessionTrade(g_model_config.symbol, (ENUM_DAY_OF_WEEK)day, session, first, last);
      if(!found) break;
      ModelCell(row, ModelInteger(day)); ModelCell(row, ModelInteger(session));
      ModelCell(row, ModelInteger(first)); ModelCell(row, ModelInteger(last));
    }
  return ModelContinuationHex(row, quote ? "QUOTE_SESSIONS" : "TRADE_SESSIONS");
}

bool ModelContinuationDigestValid(const string value)
{
  uchar bytes[];
  return StringLen(value) == 64 && ModelContinuationUnhex(value, bytes) && ArraySize(bytes) == 32;
}

void ModelContinuationCloseReader(ModelContinuationReader &reader)
{
  if(reader.handle != INVALID_HANDLE) FileClose(reader.handle);
  reader.handle = INVALID_HANDLE;
  ArrayFree(reader.bytes);
}

bool ModelContinuationRead(ModelContinuationReader &reader, string &line)
{
  uchar row[];
  int count = 0;
  line = "";
  while(true)
  {
    if(reader.position == reader.available)
    {
      reader.position = 0;
      ResetLastError();
      ulong offset = FileTell(reader.handle);
      ulong size = FileSize(reader.handle);
      int native_error = GetLastError();
      if(native_error != 0 || offset > size)
      { ModelFail("CONTINUATION_PREFIX_CURSOR"); return false; }
      if(offset == size)
      {
        if(count != 0) ModelFail("CONTINUATION_PARTIAL_PREFIX");
        return false;
      }
      ulong remaining = size - offset;
      int requested = (int)(remaining > 65536 ? 65536 : remaining);
      ResetLastError();
      reader.available = (int)FileReadArray(reader.handle, reader.bytes, 0, requested);
      native_error = GetLastError();
      if(native_error != 0 || reader.available != requested)
      {
        PrintFormat("MODEL_CONTINUATION_PREFIX_READ rows=%I64d offset=%I64u bytes=%I64u requested=%d actual=%d native_error=%d",
                    reader.rows, offset, size, requested, reader.available, native_error);
        ModelFail("CONTINUATION_PREFIX_READ");
        return false;
      }
    }
    uchar value = reader.bytes[reader.position++];
    if(count >= MODEL_CONTINUATION_BUFFER_BYTES) { ModelFail("CONTINUATION_PREFIX_ROW_CAP"); return false; }
    if(count == ArraySize(row) && ArrayResize(row, count + 4096, 4096) < count + 1)
    { ModelFail("CONTINUATION_PREFIX_BUFFER"); return false; }
    row[count++] = value;
    if(value != 10) continue;
    if(count < 2 || row[count - 2] != 13) { ModelFail("CONTINUATION_PREFIX_NEWLINE"); return false; }
    line = CharArrayToString(row, 0, count - 2, CP_UTF8);
    reader.total_bytes += count;
    reader.rows++;
    reader.chain = ModelContinuationChain(reader.chain, line + "\r\n");
    return !g_model_failed;
  }
  return false;
}

bool ModelContinuationOpenReader(ModelContinuationReader &reader, const string filename, const string header)
{
  reader.handle = FileOpen(filename, FILE_READ | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
  reader.position = 0;
  reader.available = 0;
  reader.rows = 0;
  reader.total_bytes = 0;
  reader.chain = ModelContinuationZero();
  if(reader.handle == INVALID_HANDLE || ArrayResize(reader.bytes, 65536) != 65536)
  { ModelFail("CONTINUATION_PREFIX_OPEN"); return false; }
  string actual;
  if(!ModelContinuationRead(reader, actual) || actual != header)
  { ModelFail("CONTINUATION_PREFIX_HEADER"); return false; }
  return true;
}

string ModelContinuationKey(const string text, const string key)
{
  string rows[];
  int count = StringSplit(text, '\n', rows);
  string prefix = key + "\t";
  string result = "";
  for(int i = 0; i < count; i++)
  {
    string row = rows[i];
    if(StringLen(row) > 0 && StringGetCharacter(row, StringLen(row) - 1) == 13)
      row = StringSubstr(row, 0, StringLen(row) - 1);
    if(StringFind(row, prefix) != 0) continue;
    if(result != "") { ModelFail("CONTINUATION_DUPLICATE_METADATA"); return ""; }
    result = StringSubstr(row, StringLen(prefix));
  }
  return result;
}

bool ModelContinuationReadMetadata(const string filename, string &text, string &chain)
{
  ModelContinuationReader reader;
  reader.handle = INVALID_HANDLE;
  if(!ModelContinuationOpenReader(reader, filename, "key\tvalue")) return false;
  text = "";
  string line;
  while(ModelContinuationRead(reader, line))
  {
    if(StringLen(text) + StringLen(line) > 65536) { ModelFail("CONTINUATION_METADATA_CAP"); break; }
    text += line + "\r\n";
  }
  chain = reader.chain;
  ModelContinuationCloseReader(reader);
  return !g_model_failed;
}

bool ModelContinuationWitnessInventory()
{
  string found;
  long search = FileFindFirst(g_cont_replay_root + "*", found, FILE_COMMON);
  if(search == INVALID_HANDLE) { ModelFail("CONTINUATION_WITNESS_INVENTORY"); return false; }
  int count = 0;
  bool valid = true;
  do
  {
    bool known = false;
    for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT; file++)
      if(found == ModelContinuationWitnessFilename(file)) { known = true; break; }
    if(!known || FileIsExist(g_cont_replay_root + found, FILE_COMMON) == false) valid = false;
    count++;
  }
  while(FileFindNext(search, found));
  FileFindClose(search);
  if(!valid || count != MODEL_CONTINUATION_FILE_COUNT) ModelFail("CONTINUATION_WITNESS_INVENTORY");
  return valid && count == MODEL_CONTINUATION_FILE_COUNT;
}

bool ModelContinuationWitnessMetadata(const string text, const bool manifest)
{
  string rows[];
  int count = StringSplit(text, '\n', rows);
  int observed = 0;
  for(int i = 0; i < count; i++)
  {
    if(rows[i] == "") continue;
    string row = rows[i];
    if(StringGetCharacter(row, StringLen(row) - 1) == 13) row = StringSubstr(row, 0, StringLen(row) - 1);
    string cells[];
    if(StringSplit(row, '\t', cells) != 2 || cells[0] == "" || cells[1] == "")
    { ModelFail("CONTINUATION_WITNESS_METADATA"); return false; }
    bool known = false;
    for(int key = 0; ; key++)
    {
      string expected = manifest ? ModelContinuationWitnessManifestKey(key) : ModelContinuationWitnessSealKey(key);
      if(expected == "") break;
      if(expected == cells[0]) { known = true; break; }
    }
    if(!known || ModelContinuationKey(text, cells[0]) != cells[1])
    { ModelFail("CONTINUATION_WITNESS_METADATA"); return false; }
    observed++;
  }
  int expected_count = 0;
  while((manifest ? ModelContinuationWitnessManifestKey(expected_count) : ModelContinuationWitnessSealKey(expected_count)) != "")
    expected_count++;
  if(observed != expected_count) ModelFail("CONTINUATION_WITNESS_METADATA");
  return observed == expected_count && !g_model_failed;
}

bool ModelContinuationVerifyWitness()
{
  if(!ModelContinuationWitnessInventory()) return false;
  string seal, actual;
  if(!ModelContinuationReadMetadata(g_cont_replay_root + "witness_seal.tsv", seal, actual) ||
     actual != g_model_config.replay_witness_proof || !ModelContinuationWitnessMetadata(seal, false))
  { ModelFail("CONTINUATION_WITNESS_PIN"); return false; }
  string names[] = {"witness_manifest.tsv", "input_prefix.tsv", "fact_prefix.tsv", "window_prefix.tsv", "state_checkpoint.tsv"};
  string headers[] = {"key\tvalue", ModelContinuationHeader(1), ModelContinuationHeader(2),
                      ModelContinuationHeader(3), ModelContinuationHeader(4)};
  for(int file = 0; file < 5; file++)
  {
    ModelContinuationReader reader;
    reader.handle = INVALID_HANDLE;
    if(!ModelContinuationOpenReader(reader, g_cont_replay_root + names[file], headers[file])) return false;
    string line;
    while(ModelContinuationRead(reader, line)) {}
    bool valid = ModelContinuationKey(seal, "rows_" + names[file]) == ModelInteger(reader.rows - 1) &&
                 ModelContinuationKey(seal, "bytes_" + names[file]) == ModelInteger(reader.total_bytes) &&
                 ModelContinuationKey(seal, "chain_" + names[file]) == reader.chain;
    ModelContinuationCloseReader(reader);
    if(!valid || g_model_failed) { ModelFail("CONTINUATION_WITNESS_INTEGRITY"); return false; }
  }
  string manifest, ignored;
  if(!ModelContinuationReadMetadata(g_cont_replay_root + "witness_manifest.tsv", manifest, ignored) ||
     !ModelContinuationWitnessMetadata(manifest, true)) return false;
  string native_receipt = ModelContinuationKey(manifest, "native_fence_proof");
  if(!ModelContinuationDigestValid(native_receipt))
  { ModelFail("CONTINUATION_NATIVE_FENCE_BINDING"); return false; }
  string legacy = ModelContinuationKey(manifest, "legacy_source_proof");
  if(legacy != "NONE" && !ModelContinuationDigestValid(legacy))
  { ModelFail("CONTINUATION_LEGACY_BINDING"); return false; }
  if(ModelContinuationKey(manifest, "family") != "MQL5_MODEL_CONTINUATION_WITNESS" ||
     ModelContinuationKey(manifest, "version") != "1" ||
     ModelContinuationKey(manifest, "descriptor_sha256") != MODEL_CONTINUATION_DIGEST ||
     ModelContinuationKey(manifest, "engine") != g_model_config.engine ||
     ModelContinuationKey(manifest, "origin") != "TESTER" || g_cont_origin != "TESTER" ||
     ModelContinuationKey(manifest, "source_id") != g_model_config.source_id ||
     ModelContinuationKey(manifest, "session_id") != g_model_config.session_id ||
     ModelContinuationKey(manifest, "source_proof") != g_model_config.source_proof ||
     ModelContinuationKey(manifest, "configuration_proof") != g_model_config.configuration_proof ||
     ModelContinuationKey(manifest, "history_proof") != g_model_config.history_proof ||
     ModelContinuationKey(manifest, "core_manifest_sha256") != ModelContinuationHashText(g_cont_core_manifest))
  { ModelFail("CONTINUATION_WITNESS_IDENTITY"); return false; }
  g_cont_replay_input_end = StringToInteger(ModelContinuationKey(manifest, "last_input_ordinal"));
  g_cont_replay_fact_end = StringToInteger(ModelContinuationKey(manifest, "last_fact_ordinal"));
  g_cont_replay_birth_end = StringToInteger(ModelContinuationKey(manifest, "last_birth_ordinal"));
  g_cont_previous_seal = ModelContinuationKey(manifest, "predecessor_seal");
  g_cont_replay_expected_state = ModelContinuationKey(manifest, "end_state_sha256");
  g_cont_replay_anchor_state = ModelContinuationKey(manifest, "anchor_state_sha256");
  if(g_cont_replay_input_end <= 0 || g_cont_replay_fact_end < 0 || g_cont_replay_birth_end < 0 ||
     !ModelContinuationDigestValid(g_cont_previous_seal) ||
     !ModelContinuationDigestValid(g_cont_replay_expected_state) ||
     !ModelContinuationDigestValid(g_cont_replay_anchor_state))
  { ModelFail("CONTINUATION_WITNESS_CURSOR"); return false; }
  return ModelContinuationOpenReader(g_cont_replay_input, g_cont_replay_root + "input_prefix.tsv", ModelContinuationHeader(1)) &&
         ModelContinuationOpenReader(g_cont_replay_fact, g_cont_replay_root + "fact_prefix.tsv", ModelContinuationHeader(2)) &&
         ModelContinuationOpenReader(g_cont_replay_birth, g_cont_replay_root + "window_prefix.tsv", ModelContinuationHeader(3)) &&
         ModelContinuationOpenReader(g_cont_replay_state, g_cont_replay_root + "state_checkpoint.tsv", ModelContinuationHeader(4));
}

bool ModelContinuationFlush(const int file)
{
  int used = g_cont_buffers[file].used;
  if(used == 0) return true;
  ResetLastError();
  bool valid = FileWriteArray(g_cont_buffers[file].handle, g_cont_buffers[file].bytes, 0, used) == (uint)used && GetLastError() == 0;
  if(valid)
  {
    FileFlush(g_cont_buffers[file].handle);
    valid = GetLastError() == 0;
  }
  if(!valid) { ModelFail("CONTINUATION_APPEND"); return false; }
  g_cont_buffers[file].used = 0;
  g_cont_buffers[file].pending_rows = 0;
  return true;
}

bool ModelContinuationWrite(const int file, const string line, const bool header = false)
{
  if(!g_cont_enabled || !g_cont_segment_open || g_model_failed ||
     file < 0 || file >= MODEL_CONTINUATION_FILE_COUNT ||
     StringFind(line, "\r") >= 0 || StringFind(line, "\n") >= 0) return false;
  uchar bytes[];
  int count = StringToCharArray(line + "\r\n", bytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
  if(count <= 0 || count > MODEL_CONTINUATION_BUFFER_BYTES)
  { ModelFail("CONTINUATION_ROW_CAP"); return false; }
  if(g_cont_buffers[file].used + count > MODEL_CONTINUATION_BUFFER_BYTES)
    if(!ModelContinuationFlush(file)) return false;
  if(ArrayCopy(g_cont_buffers[file].bytes, bytes, g_cont_buffers[file].used, 0, count) != count)
  { ModelFail("CONTINUATION_BUFFER_COPY"); return false; }
  g_cont_buffers[file].used += count;
  g_cont_buffers[file].pending_rows++;
  if(g_cont_buffers[file].pending_rows > g_model_buffer_peak) g_model_buffer_peak = g_cont_buffers[file].pending_rows;
  g_cont_buffers[file].rows += header ? 0 : 1;
  g_cont_buffers[file].total_bytes += count;
  g_cont_buffers[file].chain = ModelContinuationChain(g_cont_buffers[file].chain, line + "\r\n");
  if(g_cont_buffers[file].pending_rows >= MODEL_FLUSH_ROWS)
    return ModelContinuationFlush(file);
  return !g_model_failed;
}

void ModelContinuationMetadata(const string key, const string value)
{
  ModelContinuationWrite(0, key + "\t" + value);
}

void ModelContinuationCoreMetadata(const int file, const string key, const string value)
{
  string canonical = key == "run_id" ? g_model_config.session_id : value;
  if(!ModelCellValid(canonical) || !ModelCellValid(key)) { ModelFail("CONTINUATION_CORE_METADATA"); return; }
  if(file == MODEL_RUN_MANIFEST) g_cont_core_manifest += key + "\t" + canonical + "\r\n";
  else g_cont_core_summary += key + "\t" + canonical + "\r\n";
  if(StringLen(g_cont_core_manifest) > 65536 || StringLen(g_cont_core_summary) > 65536)
    ModelFail("CONTINUATION_METADATA_CAP");
}

bool ModelContinuationOpen(const ModelCaptureConfig &config)
{
  g_cont_enabled = true;
  g_cont_input_chain = ModelContinuationZero();
  g_cont_history_chain = ModelContinuationZero();
  g_cont_replay_input.handle = INVALID_HANDLE;
  g_cont_replay_fact.handle = INVALID_HANDLE;
  g_cont_replay_birth.handle = INVALID_HANDLE;
  g_cont_replay_state.handle = INVALID_HANDLE;
  for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT; file++) g_cont_buffers[file].handle = INVALID_HANDLE;
  if(!config.enabled || !ModelRunIdValid(config.source_id) || !ModelRunIdValid(config.session_id) ||
     (config.source_proof != "" && config.source_proof != MODEL_CONTINUATION_SOURCE_SHA256) ||
     (config.configuration_proof != "" && !ModelContinuationDigestValid(config.configuration_proof)) ||
     !ModelContinuationDigestValid(config.history_proof) ||
     (config.segment_seconds != 3600 && config.segment_seconds != 14400 && config.segment_seconds != 86400))
  { ModelFail("CONTINUATION_PARAMETERS"); return false; }
  g_model_config.source_proof = MODEL_CONTINUATION_SOURCE_SHA256;
  if(MQLInfoInteger(MQL_TESTER))
  {
    if(SymbolInfoInteger(config.symbol, SYMBOL_CUSTOM) == 0)
    { ModelFail("CONTINUATION_TESTER_NONCUSTOM_SOURCE_UNSUPPORTED"); return false; }
    g_cont_origin = "TESTER";
  }
  else if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) g_cont_origin = "LIVE_DEMO";
  else { ModelFail("CONTINUATION_REAL_ORIGIN_UNSUPPORTED"); return false; }
  g_cont_anchor_pending = g_cont_origin == "TESTER";
  if(config.replay_witness_id != "")
  {
    if(g_cont_origin != "TESTER" || !ModelRunIdValid(config.replay_witness_id) ||
       !ModelContinuationDigestValid(config.replay_witness_proof))
    { ModelFail("CONTINUATION_REPLAY_PARAMETERS"); return false; }
    g_cont_replaying = true;
    g_cont_replay_root = MODEL_CONTINUATION_ROOT + "\\witnesses\\" + config.replay_witness_id + "\\";
  }
  string candidate = MODEL_CONTINUATION_ROOT + "\\runs\\" + config.run_id + "\\";
  string found;
  long search = FileFindFirst(candidate + "*", found, FILE_COMMON);
  if(search != INVALID_HANDLE)
  {
    FileFindClose(search);
    ModelFail("CONTINUATION_RUN_ID_EXISTS");
    return false;
  }
  g_model_root = candidate;
  return true;
}

bool ModelContinuationCreateSegment(const bool terminal = false)
{
  g_cont_segment++;
  string root = MODEL_CONTINUATION_ROOT + "\\runs\\" + g_model_config.run_id + "\\segments\\" +
                StringFormat("%08I64d", g_cont_segment) + "\\";
  string found;
  long search = FileFindFirst(root + "*", found, FILE_COMMON);
  if(search != INVALID_HANDLE)
  {
    FileFindClose(search);
    ModelFail("CONTINUATION_SEGMENT_EXISTS");
    return false;
  }
  g_cont_segment_root = root;
  g_model_root = root;
  g_cont_segment_open = true;
  g_cont_terminal = terminal;
  for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT; file++)
  {
    string filename = file == 5 ? "segment_seal.partial" : ModelContinuationFilename(file);
    g_cont_buffers[file].handle = FileOpen(root + filename,
      FILE_WRITE | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
    if(g_cont_buffers[file].handle == INVALID_HANDLE ||
       ArrayResize(g_cont_buffers[file].bytes, MODEL_CONTINUATION_BUFFER_BYTES) != MODEL_CONTINUATION_BUFFER_BYTES)
    { ModelFail("CONTINUATION_SEGMENT_CREATE"); return false; }
    g_cont_buffers[file].used = 0;
    g_cont_buffers[file].pending_rows = 0;
    g_cont_buffers[file].rows = 0;
    g_cont_buffers[file].total_bytes = 0;
    g_cont_buffers[file].chain = ModelContinuationZero();
    if(!ModelContinuationWrite(file, ModelContinuationHeader(file), true)) return false;
  }
  g_cont_segment_first_input = g_cont_input + 1;
  g_cont_segment_first_fact = g_cont_fact + 1;
  g_cont_segment_first_birth = g_cont_birth + 1;
  g_cont_segment_first_record = g_cont_record + 1;
  string keys[] = {"family", "continuation_version", "descriptor_sha256", "engine", "origin", "source_id", "session_id",
    "physical_run_id", "canonical_run_id", "source_proof", "configuration_proof", "history_proof", "segment_ordinal",
    "segment_seconds", "predecessor_seal", "predecessor_state_sha256", "replay_witness_id", "replay_witness_proof"};
  string values[] = {"MQL5_MODEL_CONTINUATION", "1", MODEL_CONTINUATION_DIGEST, g_model_config.engine, g_cont_origin,
    g_model_config.source_id, g_model_config.session_id, g_model_config.run_id, g_model_config.session_id,
    g_model_config.source_proof, g_model_config.configuration_proof, g_model_config.history_proof,
    ModelInteger(g_cont_segment), ModelInteger(g_model_config.segment_seconds), g_cont_previous_seal,
    g_cont_previous_state, ModelNullable(g_model_config.replay_witness_id), ModelNullable(g_model_config.replay_witness_proof)};
  for(int i = 0; i < ArraySize(keys); i++) ModelContinuationMetadata(keys[i], values[i]);
  string core[];
  int count = StringSplit(g_cont_core_manifest, '\n', core);
  for(int i = 0; i < count; i++)
  {
    string row = core[i];
    if(row == "") continue;
    if(StringGetCharacter(row, StringLen(row) - 1) == 13) row = StringSubstr(row, 0, StringLen(row) - 1);
    ModelContinuationWrite(0, "core_" + row);
  }
  ModelContinuationMetadata("core_manifest_sha256", ModelContinuationHashText(g_cont_core_manifest));
  ModelContinuationMetadata("weekly_quote_sessions_hex", ModelContinuationSessions(true));
  ModelContinuationMetadata("weekly_trade_sessions_hex", ModelContinuationSessions(false));
  ModelContinuationMetadata("session_schedule_observed_time_msc", ModelInteger((long)TimeCurrent() * 1000));
  ModelContinuationMetadata("acquisition_policy", g_cont_origin == "TESTER" ?
    "AUTHENTICATED_LOCAL_CUSTOM_TESTER_DELIVERY_V1" : "OBSERVED_CALLBACK_STREAM_FRESH_QUOTE_3S_V1");
  ModelContinuationMetadata("history_binding_policy", g_cont_origin == "TESTER" ?
    "IMMUTABLE_ORIGINAL_ANCHOR_REGISTERED_PHYSICAL_JOB_HISTORY_V1" : "INDEPENDENT_VERIFIED_NATIVE_HISTORY_RECEIPT_V1");
  ModelContinuationMetadata("startup_state_policy", g_cont_origin == "TESTER" ?
    "FIRST_DELIVERED_TICK_PRE_DISPATCH_FULL_STATE_V1" : "ONINIT_FULL_STATE_V1");
  ModelContinuationMetadata("observer_clock_basis", g_cont_origin == "TESTER" ? "TESTER_SIMULATED_QUOTE_SECONDS" : "UTC_SECONDS");
  ModelContinuationMetadata("capture_liveness_policy", "PHYSICAL_MONOTONIC_CALLBACK_OBSERVATION_V1");
  ModelContinuationMetadata("quote_freshness_policy", "NATIVE_BROKER_ESTIMATE_QUOTE_AGE_3S_V1");
  ModelContinuationMetadata("source_quality_policy", g_cont_origin == "TESTER" ?
    "HISTORICAL_SOURCE_GAPS_UNKNOWN_V1" : "INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1");
  ModelContinuationMetadata("closure_policy", "INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1");
  ModelContinuationMetadata("segment_phase", terminal ? "TERMINAL" : "CAPTURE");
  return !g_model_failed;
}

string ModelContinuationTick(const MqlTick &tick)
{
  string row = ModelInteger(tick.time) + "\t" + ModelInteger(tick.time_msc);
  ModelCell(row, ModelContinuationNumber(tick.bid)); ModelCell(row, ModelContinuationNumber(tick.ask)); ModelCell(row, ModelContinuationNumber(tick.last));
  ModelCell(row, StringFormat("%I64u", tick.volume)); ModelCell(row, ModelContinuationNumber(tick.volume_real));
  ModelCell(row, ModelInteger(tick.flags));
  return ModelContinuationHex(row);
}

string ModelContinuationTransaction(const MqlTradeTransaction &transaction,
                                    const MqlTradeRequest &request, const MqlTradeResult &result)
{
  string row = ModelInteger(transaction.type);
  ModelCell(row, StringFormat("%I64u", transaction.deal)); ModelCell(row, StringFormat("%I64u", transaction.order));
  ModelCell(row, ModelContinuationHex(transaction.symbol)); ModelCell(row, StringFormat("%I64u", transaction.position));
  ModelCell(row, StringFormat("%I64u", transaction.position_by)); ModelCell(row, ModelContinuationNumber(transaction.price));
  ModelCell(row, ModelContinuationNumber(transaction.price_sl)); ModelCell(row, ModelContinuationNumber(transaction.price_tp));
  ModelCell(row, ModelContinuationNumber(transaction.volume)); ModelCell(row, ModelInteger(transaction.order_type));
  ModelCell(row, ModelInteger(transaction.order_state)); ModelCell(row, ModelInteger(transaction.deal_type));
  ModelCell(row, ModelInteger(transaction.time_type)); ModelCell(row, ModelInteger(transaction.time_expiration));
  ModelCell(row, ModelContinuationNumber(transaction.price_trigger));
  bool present = transaction.type == TRADE_TRANSACTION_REQUEST;
  ModelCell(row, ModelBoolean(present));
  if(!present)
  {
    for(int i = 17; i < MODEL_CONTINUATION_TRANSACTION_WIDTH; i++) ModelCell(row, MODEL_NULL);
  }
  else
  {
    ModelCell(row, ModelInteger(request.action)); ModelCell(row, ModelInteger(request.type));
    ModelCell(row, StringFormat("%I64u", request.magic)); ModelCell(row, StringFormat("%I64u", request.order));
    ModelCell(row, StringFormat("%I64u", request.position)); ModelCell(row, StringFormat("%I64u", request.position_by));
    ModelCell(row, ModelContinuationNumber(request.volume)); ModelCell(row, ModelContinuationNumber(request.price));
    ModelCell(row, ModelContinuationNumber(request.sl)); ModelCell(row, ModelContinuationNumber(request.tp));
    ModelCell(row, StringFormat("%I64u", request.deviation)); ModelCell(row, ModelInteger(request.type_filling));
    ModelCell(row, ModelInteger(request.type_time)); ModelCell(row, ModelInteger(request.expiration));
    ModelCell(row, ModelContinuationPrivateTextHash(request.comment)); ModelCell(row, ModelContinuationHex(request.symbol));
    ModelCell(row, ModelContinuationNumber(request.stoplimit)); ModelCell(row, ModelInteger(result.retcode));
    ModelCell(row, StringFormat("%I64u", result.deal)); ModelCell(row, StringFormat("%I64u", result.order));
    ModelCell(row, ModelContinuationNumber(result.volume)); ModelCell(row, ModelContinuationNumber(result.price));
    ModelCell(row, ModelContinuationNumber(result.bid)); ModelCell(row, ModelContinuationNumber(result.ask));
    ModelCell(row, ModelInteger(result.request_id)); ModelCell(row, ModelInteger(result.retcode_external));
    ModelCell(row, ModelContinuationPrivateTextHash(result.comment));
  }
  return ModelContinuationHex(row);
}

void ModelContinuationInput(const string callback, const MqlTick &tick, const long sequence,
                             const bool acquired, const string transaction = "-")
{
  if(!g_cont_enabled || g_cont_terminal || g_model_failed) return;
  if(g_cont_anchor_pending) { ModelFail("CONTINUATION_STARTUP_ANCHOR_MISSING"); return; }
  bool connected = MQLInfoInteger(MQL_TESTER) > 0 || TerminalInfoInteger(TERMINAL_CONNECTED) > 0;
  bool synchronized = SymbolIsSynchronized(g_model_config.symbol);
  long broker = (long)TimeCurrent() * 1000;
  long observer = g_cont_origin == "TESTER" ? broker : (long)TimeGMT() * 1000;
  long broker_estimate = (long)TimeTradeServer() * 1000;
  long quote_age = broker_estimate - tick.time_msc;
  bool has_quote = acquired && tick.time_msc > 0;
  bool fresh = has_quote && quote_age >= -1000 && quote_age <= 3000;
  // Tester quote-clock jumps are simulated history, not process liveness.
  // Completeness requires an independently registered natural native job.
  bool available = (g_cont_origin == "TESTER" ? has_quote : fresh) && connected && synchronized;
  ulong monotonic = GetMicrosecondCount();
  if(g_cont_input > 0 && (observer < g_cont_last_observer || monotonic < g_cont_last_monotonic))
  { ModelFail("CONTINUATION_ACQUISITION_CLOCK_BACKWARD"); return; }
  long observer_gap = g_cont_input > 0 ? observer - g_cont_last_observer : 0;
  ulong monotonic_gap = g_cont_input > 0 ? monotonic - g_cont_last_monotonic : 0;
  bool previous_available = g_cont_last_available;
  if(!g_cont_replaying && g_cont_input_pending &&
     (available != previous_available || fresh != g_cont_last_fresh || observer_gap > 3000 ||
      (g_cont_origin == "LIVE_DEMO" && monotonic_gap > 3000000)))
    if(!ModelContinuationFlushInput("BOUNDARY")) return;
  if(g_cont_input_pending)
  {
    if(observer_gap > g_cont_maximum_observer_gap) g_cont_maximum_observer_gap = observer_gap;
    if(monotonic_gap > g_cont_maximum_monotonic_gap) g_cont_maximum_monotonic_gap = monotonic_gap;
  }
  else
  {
    g_cont_maximum_observer_gap = 0;
    g_cont_maximum_monotonic_gap = 0;
  }
  g_cont_broker_estimate = broker_estimate;
  g_cont_last_quote_age = quote_age;
  g_cont_last_monotonic = monotonic;
  string quote = ModelContinuationTick(tick);
  g_cont_input++;
  string canonical_input = ModelInteger(g_cont_input);
  ModelCell(canonical_input, callback); ModelCell(canonical_input, ModelInteger(sequence)); ModelCell(canonical_input, ModelInteger(broker));
  ModelCell(canonical_input, quote); ModelCell(canonical_input, transaction);
  ModelCell(canonical_input, ModelBoolean(connected)); ModelCell(canonical_input, ModelBoolean(synchronized)); ModelCell(canonical_input, ModelBoolean(acquired));
  g_cont_input_chain = ModelContinuationChain(g_cont_input_chain, canonical_input + "\r\n");
  if(!g_cont_input_pending)
  {
    g_cont_block_first_input = g_cont_input;
    g_cont_block_first_time = broker;
    g_cont_block_first_observer = observer;
    g_cont_block_first_monotonic = g_cont_last_monotonic;
    g_cont_maximum_quote_age = g_cont_last_quote_age;
    g_cont_input_pending = true;
  }
  g_cont_block_last_time = broker;
  g_cont_last_observer = observer;
  g_cont_last_connected = connected;
  g_cont_last_synchronized = synchronized;
  g_cont_last_acquired = has_quote;
  g_cont_last_fresh = fresh;
  g_cont_last_available = available;
  g_cont_last_quote = quote;
  g_cont_last_transaction = transaction;
  if(g_cont_last_quote_age > g_cont_maximum_quote_age) g_cont_maximum_quote_age = g_cont_last_quote_age;
  if(available) g_cont_block_available++;
  else g_cont_block_unavailable++;
  if(!has_quote) g_cont_block_missing_quotes++;
  else if(fresh) g_cont_block_fresh_quotes++;
  else
  {
    g_cont_block_stale_quotes++;
    if(callback == "TICK") g_cont_block_stale_ticks++;
    if(callback == "TRADE") g_cont_block_stale_trades++;
  }
  if(callback == "TICK") g_cont_block_ticks++;
  else if(callback == "TIMER") g_cont_block_timers++;
  else if(callback == "TRADE") g_cont_block_trades++;
  else ModelFail("CONTINUATION_INPUT_KIND");
}

string ModelContinuationCanonicalInputRecord(const string line)
{
  string cells[];
  if(StringSplit(line, '\t', cells) != MODEL_CONTINUATION_INPUT_WIDTH) { ModelFail("CONTINUATION_INPUT_WIDTH"); return ""; }
  // Native tester simulated quote clocks remain causal; physical clocks do not.
  if(g_cont_origin != "TESTER") { cells[6] = "0"; cells[7] = "0"; }
  cells[8] = "0";
  cells[9] = "0";
  if(g_cont_origin != "TESTER") cells[27] = "0";
  cells[28] = "0";
  string result = "";
  for(int i = 0; i < ArraySize(cells); i++) ModelCell(result, cells[i]);
  return result;
}

bool ModelContinuationFlushInput(const string callback)
{
  if(!g_cont_input_pending || g_model_failed) return !g_model_failed;
  g_cont_record++;
  string row = ModelInteger(g_cont_record);
  ModelCell(row, ModelInteger(g_cont_block_first_input)); ModelCell(row, ModelInteger(g_cont_input));
  ModelCell(row, callback); ModelCell(row, ModelInteger(g_cont_block_first_time)); ModelCell(row, ModelInteger(g_cont_block_last_time));
  ModelCell(row, ModelInteger(g_cont_block_first_observer)); ModelCell(row, ModelInteger(g_cont_last_observer));
  ModelCell(row, StringFormat("%I64u", g_cont_block_first_monotonic)); ModelCell(row, StringFormat("%I64u", g_cont_last_monotonic));
  ModelCell(row, ModelInteger(g_cont_input - g_cont_block_first_input + 1));
  ModelCell(row, ModelInteger(g_cont_block_available)); ModelCell(row, ModelInteger(g_cont_block_unavailable));
  ModelCell(row, ModelInteger(g_cont_block_ticks)); ModelCell(row, ModelInteger(g_cont_block_timers));
  ModelCell(row, ModelInteger(g_cont_block_trades)); ModelCell(row, g_cont_input_chain);
  ModelCell(row, g_cont_last_quote); ModelCell(row, ModelBoolean(g_cont_last_connected));
  ModelCell(row, ModelBoolean(g_cont_last_synchronized));
  ModelCell(row, g_cont_last_available ? (g_cont_origin == "TESTER" ? "TESTER_CALLBACK_ACQUIRED" : "FRESH_CALLBACK_STREAM") : "UNAVAILABLE");
  ModelCell(row, g_cont_last_transaction);
  ModelCell(row, ModelInteger(g_cont_maximum_quote_age)); ModelCell(row, ModelInteger(g_cont_last_quote_age));
  ModelCell(row, ModelInteger(g_cont_broker_estimate)); ModelCell(row, ModelInteger(g_cont_history_observations));
  ModelCell(row, g_cont_history_chain);
  ModelCell(row, ModelInteger(g_cont_maximum_observer_gap));
  ModelCell(row, StringFormat("%I64u", g_cont_maximum_monotonic_gap));
  ModelCell(row, "OBSERVED_CALLBACK_ONLY");
  ModelCell(row, !g_cont_last_acquired ? "MISSING_NATIVE_QUOTE" :
    (g_cont_last_fresh ? "FRESH_NATIVE_QUOTE" : "STALE_CACHED_QUOTE"));
  ModelCell(row, ModelInteger(g_cont_block_fresh_quotes)); ModelCell(row, ModelInteger(g_cont_block_stale_quotes));
  ModelCell(row, ModelInteger(g_cont_block_missing_quotes)); ModelCell(row, ModelInteger(g_cont_block_stale_ticks));
  ModelCell(row, ModelInteger(g_cont_block_stale_trades));
  bool valid = false;
  if(g_cont_replaying)
  {
    string previous;
    if(StringLen(g_cont_replay_input_next) > 0) { previous = g_cont_replay_input_next; g_cont_replay_input_next = ""; }
    else if(!ModelContinuationRead(g_cont_replay_input, previous)) { ModelFail("CONTINUATION_INPUT_PREFIX_SHORT"); return false; }
    valid = ModelContinuationCanonicalInputRecord(previous) == ModelContinuationCanonicalInputRecord(row);
    if(!valid) ModelFail("CONTINUATION_INPUT_PREFIX_MISMATCH");
  }
  else valid = ModelContinuationWrite(1, row);
  g_cont_input_pending = false;
  g_cont_block_available = 0; g_cont_block_unavailable = 0;
  g_cont_block_ticks = 0; g_cont_block_timers = 0; g_cont_block_trades = 0;
  g_cont_block_fresh_quotes = 0; g_cont_block_stale_quotes = 0; g_cont_block_missing_quotes = 0;
  g_cont_block_stale_ticks = 0; g_cont_block_stale_trades = 0;
  return valid;
}

bool ModelContinuationFact(ModelRow &row, const string text)
{
  if(!g_cont_enabled || g_model_failed) return false;
  if(row.file == MODEL_RUN_MANIFEST || row.file == MODEL_RUN_SUMMARY) return true;
  if(g_cont_anchor_pending) { ModelFail("CONTINUATION_PRE_ANCHOR_FACT"); return false; }
  string key_name = ModelContinuationRowKey(row.file);
  string key = "";
  for(int i = 0; i < ArraySize(g_model_layout[row.file].names); i++)
    if(g_model_layout[row.file].names[i] == key_name) { key = row.cells[i]; break; }
  if(key_name == "" || key == "" || key == MODEL_NULL ||
     ArraySize(row.cells) == 0 || row.cells[0] != g_model_config.run_id || g_cont_input <= 0)
  { ModelFail("CONTINUATION_FACT_IDENTITY"); return false; }
  string canonical = g_model_config.session_id + StringSubstr(text, StringLen(g_model_config.run_id));
  g_cont_fact++;
  string record = ModelInteger(g_cont_fact) + "\t" + ModelInteger(g_cont_input) + "\t" +
    (g_cont_terminal ? "TERMINAL" : "CAPTURE") + "\t" + ModelFileName(row.file) + "\t" +
    ModelContinuationHex(key) + "\t" + ModelContinuationHex(canonical);
  if(g_cont_replaying)
  {
    string previous;
    if(g_cont_fact > g_cont_replay_fact_end || !ModelContinuationRead(g_cont_replay_fact, previous) || previous != record)
    { ModelFail("CONTINUATION_FACT_PREFIX_MISMATCH"); return false; }
    return true;
  }
  return ModelContinuationWrite(2, record);
}

bool ModelContinuationBirth(const string text)
{
  if(!g_cont_enabled) return true;
  if(g_cont_anchor_pending) { ModelFail("CONTINUATION_PRE_ANCHOR_BIRTH"); return false; }
  g_cont_birth++;
  string record = ModelInteger(g_cont_birth) + "\t" + ModelInteger(g_cont_input) + "\t" + text;
  if(g_cont_replaying)
  {
    string previous;
    if(g_cont_birth > g_cont_replay_birth_end || !ModelContinuationRead(g_cont_replay_birth, previous) || previous != record)
    { ModelFail("CONTINUATION_BIRTH_PREFIX_MISMATCH"); return false; }
    return true;
  }
  return ModelContinuationWrite(3, record);
}

void ModelContinuationBeginState(const string boundary)
{
  g_cont_state_boundary = boundary;
  g_cont_state_hash = ModelContinuationZero();
}

void ModelContinuationState(const string component, const string object_id, const string field,
                             const string value_type, const string value)
{
  if(!g_cont_enabled || g_model_failed || g_cont_state_boundary == "") return;
  string canonical = component + "\t" + object_id + "\t" + field + "\t" + value_type + "\t" + value;
  g_cont_state_hash = ModelContinuationChain(g_cont_state_hash, canonical + "\r\n");
  string row = g_cont_state_boundary + "\t" + canonical;
  if(g_cont_replaying)
  {
    string previous;
    if(StringLen(g_cont_replay_state_next) > 0) { previous = g_cont_replay_state_next; g_cont_replay_state_next = ""; }
    else if(!ModelContinuationRead(g_cont_replay_state, previous)) { ModelFail("CONTINUATION_STATE_PREFIX_SHORT"); return; }
    if(previous != row)
    {
      string previous_domain = StringLen(previous) == 0 ? (previous == NULL ? "ROW:NULL" : "ROW:EMPTY") : "ROW:UTF8\t" + previous;
      PrintFormat("MODEL_CONTINUATION_STATE_DIAGNOSTIC boundary=%s component=%s object_index=%s field=%s value_type=%s expected_sha256=%s actual_sha256=%s expected_chars=%d actual_chars=%d",
                  g_cont_state_boundary, component, object_id, field, value_type,
                  ModelContinuationHashText(previous_domain), ModelContinuationHashText("ROW:UTF8\t" + row),
                  StringLen(previous), StringLen(row));
      ModelFail("CONTINUATION_STATE_PREFIX_MISMATCH");
    }
  }
  else ModelContinuationWrite(4, row);
}

bool ModelContinuationFinishState()
{
  if(!g_cont_enabled || g_model_failed) return false;
  if(g_cont_replaying)
  {
    string expected = g_cont_state_boundary == "START" ? g_cont_replay_anchor_state : g_cont_replay_expected_state;
    if(g_cont_state_hash != expected) { ModelFail("CONTINUATION_STATE_DIGEST_MISMATCH"); return false; }
    if(g_cont_state_boundary == "START")
    {
      if(!ModelContinuationRead(g_cont_replay_state, g_cont_replay_state_next) ||
         StringFind(g_cont_replay_state_next, "END\t") != 0)
      { ModelFail("CONTINUATION_STATE_PREFIX_EXTRA"); return false; }
    }
    else
    {
      string extra;
      if(ModelContinuationRead(g_cont_replay_state, extra)) { ModelFail("CONTINUATION_STATE_PREFIX_EXTRA"); return false; }
    }
  }
  g_cont_previous_state = g_cont_state_hash;
  g_cont_state_boundary = "";
  return !g_model_failed;
}

bool ModelContinuationStart()
{
  if(!g_cont_enabled) return false;
  string observed_configuration = ModelContinuationHashText(g_cont_core_manifest);
  if(g_model_config.configuration_proof != "" && g_model_config.configuration_proof != observed_configuration)
  { ModelFail("CONTINUATION_OBSERVED_CONFIGURATION_MISMATCH"); return false; }
  g_model_config.configuration_proof = observed_configuration;
  if(g_cont_replaying)
  {
    if(!ModelContinuationVerifyWitness()) return false;
  }
  else if(!ModelContinuationCreateSegment()) return false;
  if(g_cont_anchor_pending) return false;
  ModelContinuationBeginState("START");
  return true;
}

bool ModelContinuationAnchor(const string callback, const MqlTick &tick, const bool acquired)
{
  if(!g_cont_enabled || !g_cont_anchor_pending || g_model_failed) return false;
  if(g_cont_origin != "TESTER" || callback != "TICK" || !acquired ||
     tick.time_msc <= 0 || !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
     tick.bid <= 0 || tick.ask < tick.bid || g_cont_input != 0 || g_cont_fact != 0 ||
     g_cont_birth != 0 || g_cont_terminal || StringLen(g_cont_state_boundary) != 0)
  { ModelFail("CONTINUATION_STARTUP_FIRST_TICK_UNPROVEN"); return false; }
  g_cont_anchor_pending = false;
  ModelContinuationBeginState("START");
  return true;
}

bool ModelContinuationBoundaryDue(const string callback)
{
  if(!g_cont_enabled || g_cont_terminal || g_model_failed) return false;
  if(g_cont_replaying)
  {
    if(StringLen(g_cont_replay_input_next) == 0 && !ModelContinuationRead(g_cont_replay_input, g_cont_replay_input_next))
    { ModelFail("CONTINUATION_INPUT_PREFIX_SHORT"); return false; }
    string expected[];
    if(StringSplit(g_cont_replay_input_next, '\t', expected) != MODEL_CONTINUATION_INPUT_WIDTH ||
       g_cont_input > StringToInteger(expected[2]))
    { ModelFail("CONTINUATION_INPUT_PREFIX_CURSOR"); return false; }
    if(g_cont_input == StringToInteger(expected[2]))
      if(!ModelContinuationFlushInput(expected[3])) return false;
    return g_cont_input == g_cont_replay_input_end;
  }
  if(g_cont_input_pending &&
     (callback == "TRADE" ||
      g_cont_last_observer - g_cont_block_first_observer >= MODEL_CONTINUATION_INPUT_BLOCK_MS ||
      g_cont_input - g_cont_block_first_input + 1 >= MODEL_CONTINUATION_INPUT_BLOCK_CALLBACKS))
    if(!ModelContinuationFlushInput(callback == "TICK" ? "BOUNDARY" : callback)) return false;
  if(g_cont_segment_started == 0) g_cont_segment_started = g_cont_last_observer;
  return g_cont_last_observer >= g_cont_segment_started + (long)g_model_config.segment_seconds * 1000;
}

bool ModelContinuationSeal(const string completion)
{
  if(!g_cont_segment_open || g_model_failed) return false;
  for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT - 1; file++)
  {
    if(!ModelContinuationFlush(file)) return false;
    FileClose(g_cont_buffers[file].handle);
    g_cont_buffers[file].handle = INVALID_HANDLE;
    ModelContinuationWrite(5, "rows_" + ModelContinuationFilename(file) + "\t" + ModelInteger(g_cont_buffers[file].rows));
    ModelContinuationWrite(5, "bytes_" + ModelContinuationFilename(file) + "\t" + ModelInteger(g_cont_buffers[file].total_bytes));
    ModelContinuationWrite(5, "chain_" + ModelContinuationFilename(file) + "\t" + g_cont_buffers[file].chain);
  }
  string keys[] = {"completion", "first_input_ordinal", "last_input_ordinal", "first_fact_ordinal", "last_fact_ordinal",
    "first_birth_ordinal", "last_birth_ordinal", "first_record_ordinal", "last_record_ordinal",
    "input_chain_sha256", "end_state_sha256"};
  string values[] = {completion, ModelInteger(g_cont_segment_first_input), ModelInteger(g_cont_input),
    ModelInteger(g_cont_segment_first_fact), ModelInteger(g_cont_fact), ModelInteger(g_cont_segment_first_birth),
    ModelInteger(g_cont_birth), ModelInteger(g_cont_segment_first_record), ModelInteger(g_cont_record),
    g_cont_input_chain, g_cont_previous_state};
  for(int i = 0; i < ArraySize(keys); i++) ModelContinuationWrite(5, keys[i] + "\t" + values[i]);
  if(completion == "TERMINAL" || completion == "INTERRUPTED")
  {
    string rows[];
    int count = StringSplit(g_cont_core_summary, '\n', rows);
    for(int i = 0; i < count; i++)
    {
      string row = rows[i];
      if(row == "") continue;
      if(StringGetCharacter(row, StringLen(row) - 1) == 13) row = StringSubstr(row, 0, StringLen(row) - 1);
      ModelContinuationWrite(5, "core_summary_" + row);
    }
  }
  if(!ModelContinuationFlush(5)) return false;
  FileClose(g_cont_buffers[5].handle);
  g_cont_buffers[5].handle = INVALID_HANDLE;
  ResetLastError();
  if(!FileMove(g_cont_segment_root + "segment_seal.partial", FILE_COMMON,
               g_cont_segment_root + "segment_seal.tsv", FILE_COMMON) || GetLastError() != 0)
  { ModelFail("CONTINUATION_SEAL_PUBLICATION"); return false; }
  g_cont_previous_seal = g_cont_buffers[5].chain;
  for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT; file++)
  {
    if(g_cont_buffers[file].handle != INVALID_HANDLE) FileClose(g_cont_buffers[file].handle);
    g_cont_buffers[file].handle = INVALID_HANDLE;
    ArrayFree(g_cont_buffers[file].bytes);
  }
  g_cont_segment_open = false;
  g_cont_segment_started = g_cont_last_observer;
  return true;
}

bool ModelContinuationRotate()
{
  if(g_cont_replaying)
  {
    if(g_cont_input != g_cont_replay_input_end || g_cont_fact != g_cont_replay_fact_end ||
       g_cont_birth != g_cont_replay_birth_end)
    { ModelFail("CONTINUATION_PREFIX_CURSOR"); return false; }
    string extra;
    if(ModelContinuationRead(g_cont_replay_input, extra) || ModelContinuationRead(g_cont_replay_fact, extra) ||
       ModelContinuationRead(g_cont_replay_birth, extra))
    { ModelFail("CONTINUATION_PREFIX_EXTRA"); return false; }
    ModelContinuationCloseReader(g_cont_replay_input); ModelContinuationCloseReader(g_cont_replay_fact);
    ModelContinuationCloseReader(g_cont_replay_birth); ModelContinuationCloseReader(g_cont_replay_state);
    g_cont_replaying = false;
  }
  else
  {
    if(!ModelContinuationSeal("ROTATED")) return false;
  }
  if(!ModelContinuationCreateSegment()) return false;
  ModelContinuationBeginState("START");
  return true;
}

void ModelContinuationRelease()
{
  for(int file = 0; file < MODEL_CONTINUATION_FILE_COUNT; file++)
  {
    if(g_cont_buffers[file].handle != INVALID_HANDLE) FileClose(g_cont_buffers[file].handle);
    g_cont_buffers[file].handle = INVALID_HANDLE;
    ArrayFree(g_cont_buffers[file].bytes);
  }
  ModelContinuationCloseReader(g_cont_replay_input); ModelContinuationCloseReader(g_cont_replay_fact);
  ModelContinuationCloseReader(g_cont_replay_birth); ModelContinuationCloseReader(g_cont_replay_state);
}

#endif
