//+------------------------------------------------------------------+
//|                         pivot_hft_recovery.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RECOVERY_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RECOVERY_MQH_

const int PIVOT_HFT_RECOVERY_SCHEMA_VERSION = 1;
const int PIVOT_HFT_RECOVERY_SLOT_A = 0;
const int PIVOT_HFT_RECOVERY_SLOT_B = 1;
const int PIVOT_HFT_RECOVERY_MAX_FILE_BYTES = 262144;
const int PIVOT_HFT_RECOVERY_PREFLIGHT_RETRY_SECONDS = 5;
const string PIVOT_HFT_RECOVERY_MAGIC = "PHFT_RECOVERY";

enum PivotHftRecoveryStatuses
{
  PIVOT_HFT_RECOVERY_UNINITIALIZED = 0,
  PIVOT_HFT_RECOVERY_READY         = 1,
  PIVOT_HFT_RECOVERY_RECOVERED     = 2,
  PIVOT_HFT_RECOVERY_QUARANTINE    = 3,
  PIVOT_HFT_RECOVERY_CLOSE_WAIT    = 4,
  PIVOT_HFT_RECOVERY_STORAGE_ERROR = 5
};

struct PivotHftRecoveryRecord
{
  bool valid;
  int schema_version;
  int slot;
  ulong generation;
  string scope_hash;
  string payload_checksum;
  string payload;
  PivotHftPositionState position_state;

  PivotHftRecoveryRecord()
  {
    valid = false;
    schema_version = 0;
    slot = -1;
    generation = 0;
    scope_hash = "";
    payload_checksum = "";
    payload = "";
    position_state = PivotHftPositionState();
  }
};

struct PivotHftRecoveryBrokerPosition
{
  bool valid;
  SignalTypes direction;
  ulong position_ticket;
  ulong position_identifier;
  ulong entry_deal_ticket;
  datetime entry_time;
  double entry_price;
  double entry_volume;
  string position_comment;

  PivotHftRecoveryBrokerPosition()
  {
    valid = false;
    direction = NO_SIGNAL;
    position_ticket = 0;
    position_identifier = 0;
    entry_deal_ticket = 0;
    entry_time = 0;
    entry_price = 0.0;
    entry_volume = 0.0;
    position_comment = "";
  }
};

PivotHftRecoveryStatuses g_pivot_hft_recovery_status =
  PIVOT_HFT_RECOVERY_UNINITIALIZED;
bool g_pivot_hft_recovery_initialized = false;
bool g_pivot_hft_recovery_storage_ready = false;
string g_pivot_hft_recovery_reason = "";
string g_pivot_hft_recovery_scope_hash = "";
ulong g_pivot_hft_recovery_generation = 0;
int g_pivot_hft_recovery_active_slot = -1;
datetime g_pivot_hft_recovery_next_preflight = 0;
datetime g_pivot_hft_recovery_last_failure_audit = 0;
bool g_pivot_hft_recovery_cleanup_pending = false;
bool g_pivot_hft_recovery_multiple_quarantine = false;

string PivotHftRecoveryStatusLabel(
  const PivotHftRecoveryStatuses status)
{
  switch(status)
  {
    case PIVOT_HFT_RECOVERY_READY:
      return "READY";
    case PIVOT_HFT_RECOVERY_RECOVERED:
      return "RECOVERED";
    case PIVOT_HFT_RECOVERY_QUARANTINE:
      return "RECOVERY QUARANTINE";
    case PIVOT_HFT_RECOVERY_CLOSE_WAIT:
      return "RECOVERY CLOSE WAIT";
    case PIVOT_HFT_RECOVERY_STORAGE_ERROR:
      return "RECOVERY STORAGE ERROR";
    case PIVOT_HFT_RECOVERY_UNINITIALIZED:
    default:
      return "RECOVERY WAIT";
  }
}

string PivotHftRecoveryStatusLabel()
{
  return PivotHftRecoveryStatusLabel(g_pivot_hft_recovery_status);
}

string PivotHftRecoveryStatusReason()
{
  return g_pivot_hft_recovery_reason;
}

bool PivotHftRecoveryStorageReady()
{
  return g_pivot_hft_recovery_storage_ready;
}

bool PivotHftRecoveryAllowsSignalAttempts()
{
  if(!g_pivot_hft_recovery_initialized ||
     !g_pivot_hft_recovery_storage_ready)
    return false;
  return (g_pivot_hft_recovery_status == PIVOT_HFT_RECOVERY_READY ||
          g_pivot_hft_recovery_status == PIVOT_HFT_RECOVERY_RECOVERED);
}

void PivotHftRecoveryClearResolvedStorageError()
{
  if(g_market_error_active &&
     StringFind(g_market_error_context, "PIVOT_HFT_RECOVERY") == 0)
  {
    MarketStatusClearExecutionError("PIVOT_HFT_RECOVERY_READY");
  }
}

void PivotHftRecoverySetStatus(
  const PivotHftRecoveryStatuses status,
  const string reason)
{
  if(g_pivot_hft_recovery_status == status &&
     g_pivot_hft_recovery_reason == reason)
    return;

  g_pivot_hft_recovery_status = status;
  g_pivot_hft_recovery_reason = reason;
  if(status == PIVOT_HFT_RECOVERY_READY ||
     status == PIVOT_HFT_RECOVERY_RECOVERED)
    PivotHftRecoveryClearResolvedStorageError();
  PivotHftAuditLog("RECOVERY_STATUS",
                   StringFormat("status=%s|storage=%s|reason=%s",
                                PivotHftRecoveryStatusLabel(status),
                                g_pivot_hft_recovery_storage_ready
                                  ? "READY"
                                  : "UNAVAILABLE",
                                reason));
}

ulong PivotHftRecoveryFNV1a64(const string input_value)
{
  ulong hash = 1469598103934665603;
  int length = StringLen(input_value);
  for(int i = 0; i < length; i++)
  {
    uint character = (uint)StringGetCharacter(input_value, i);
    hash ^= (ulong)(character & 0xFF);
    hash *= 1099511628211;
    hash ^= (ulong)((character >> 8) & 0xFF);
    hash *= 1099511628211;
  }
  return hash;
}

string PivotHftRecoveryFormatHash(const ulong hash)
{
  uint high = (uint)(hash >> 32);
  uint low = (uint)(hash & 0xFFFFFFFF);
  return StringFormat("%08X%08X", high, low);
}

string PivotHftRecoveryResolveScopeHash()
{
  string scope_seed = StringFormat("%I64d|%s|%s|%I64d",
                                   AccountInfoInteger(ACCOUNT_LOGIN),
                                   AccountInfoString(ACCOUNT_SERVER),
                                   _Symbol,
                                   g_magic_number);
  return PivotHftRecoveryFormatHash(
    PivotHftRecoveryFNV1a64(scope_seed));
}

string PivotHftRecoverySlotFilename(const int slot)
{
  string slot_label = (slot == PIVOT_HFT_RECOVERY_SLOT_B) ? "b" : "a";
  return "pivot_hft_recovery_" + g_pivot_hft_recovery_scope_hash +
         "_" + slot_label + ".chk";
}

string PivotHftRecoveryProbeFilename()
{
  return "pivot_hft_recovery_" + g_pivot_hft_recovery_scope_hash +
         "_probe.tmp";
}

int PivotHftRecoveryHexValue(const int character)
{
  if(character >= '0' && character <= '9')
    return character - '0';
  if(character >= 'A' && character <= 'F')
    return character - 'A' + 10;
  if(character >= 'a' && character <= 'f')
    return character - 'a' + 10;
  return -1;
}

string PivotHftRecoveryEncodeString(const string value)
{
  string encoded = "";
  int length = StringLen(value);
  for(int i = 0; i < length; i++)
  {
    uint character = (uint)StringGetCharacter(value, i) & 0xFFFF;
    encoded += StringFormat("%04X", character);
  }
  return encoded;
}

bool PivotHftRecoveryDecodeString(const string encoded,
                                  string &value)
{
  value = "";
  int length = StringLen(encoded);
  if((length % 4) != 0)
    return false;

  for(int i = 0; i < length; i += 4)
  {
    int character = 0;
    for(int offset = 0; offset < 4; offset++)
    {
      int digit = PivotHftRecoveryHexValue(
        StringGetCharacter(encoded, i + offset));
      if(digit < 0)
        return false;
      character = character * 16 + digit;
    }
    value += ShortToString((ushort)character);
  }
  return true;
}

void PivotHftRecoveryAddField(string &payload,
                              const string key,
                              const string value)
{
  if(payload != "")
    payload += "|";
  payload += key + "=" + value;
}

void PivotHftRecoveryAddIntField(string &payload,
                                 const string key,
                                 const int value)
{
  PivotHftRecoveryAddField(payload, key, IntegerToString(value));
}

void PivotHftRecoveryAddLongField(string &payload,
                                  const string key,
                                  const long value)
{
  PivotHftRecoveryAddField(payload,
                           key,
                           StringFormat("%I64d", value));
}

void PivotHftRecoveryAddUlongField(string &payload,
                                   const string key,
                                   const ulong value)
{
  PivotHftRecoveryAddField(payload,
                           key,
                           StringFormat("%I64u", value));
}

void PivotHftRecoveryAddDoubleField(string &payload,
                                    const string key,
                                    const double value)
{
  PivotHftRecoveryAddField(payload, key, DoubleToString(value, 16));
}

void PivotHftRecoveryAddBoolField(string &payload,
                                  const string key,
                                  const bool value)
{
  PivotHftRecoveryAddField(payload, key, value ? "1" : "0");
}

void PivotHftRecoveryAddStringField(string &payload,
                                    const string key,
                                    const string value)
{
  PivotHftRecoveryAddField(payload,
                           key,
                           PivotHftRecoveryEncodeString(value));
}

bool PivotHftRecoveryGetField(const string payload,
                              const string key,
                              string &value)
{
  string prefix = key + "=";
  int start = -1;
  if(StringFind(payload, prefix) == 0)
    start = StringLen(prefix);
  else
  {
    string needle = "|" + prefix;
    int needle_start = StringFind(payload, needle);
    if(needle_start < 0)
      return false;
    start = needle_start + StringLen(needle);
  }

  int end = StringFind(payload, "|", start);
  if(end < 0)
    end = StringLen(payload);
  value = StringSubstr(payload, start, end - start);
  return true;
}

bool PivotHftRecoveryParseLong(const string text, long &value)
{
  value = 0;
  int length = StringLen(text);
  if(length <= 0)
    return false;

  int index = 0;
  bool negative = false;
  int first = StringGetCharacter(text, 0);
  if(first == '-' || first == '+')
  {
    negative = (first == '-');
    index++;
  }
  if(index >= length)
    return false;

  ulong magnitude = 0;
  for(; index < length; index++)
  {
    int character = StringGetCharacter(text, index);
    if(character < '0' || character > '9')
      return false;
    ulong digit = (ulong)(character - '0');
    ulong next_value = magnitude * 10 + digit;
    if(next_value < magnitude)
      return false;
    magnitude = next_value;
  }

  if(negative)
    value = -(long)magnitude;
  else
    value = (long)magnitude;
  return true;
}

bool PivotHftRecoveryParseUlong(const string text, ulong &value)
{
  value = 0;
  int length = StringLen(text);
  if(length <= 0)
    return false;

  for(int i = 0; i < length; i++)
  {
    int character = StringGetCharacter(text, i);
    if(character < '0' || character > '9')
      return false;
    ulong digit = (ulong)(character - '0');
    ulong next_value = value * 10 + digit;
    if(next_value < value)
      return false;
    value = next_value;
  }
  return true;
}

bool PivotHftRecoveryNumberTextValid(const string text)
{
  int length = StringLen(text);
  if(length <= 0)
    return false;

  bool has_digit = false;
  for(int i = 0; i < length; i++)
  {
    int character = StringGetCharacter(text, i);
    if(character >= '0' && character <= '9')
    {
      has_digit = true;
      continue;
    }
    if(character == '+' || character == '-' || character == '.' ||
       character == 'e' || character == 'E')
      continue;
    return false;
  }
  return has_digit;
}

bool PivotHftRecoveryParseIntField(const string payload,
                                   const string key,
                                   int &value)
{
  string text = "";
  long parsed = 0;
  if(!PivotHftRecoveryGetField(payload, key, text) ||
     !PivotHftRecoveryParseLong(text, parsed))
    return false;
  value = (int)parsed;
  return ((long)value == parsed);
}

bool PivotHftRecoveryParseLongField(const string payload,
                                    const string key,
                                    long &value)
{
  string text = "";
  return (PivotHftRecoveryGetField(payload, key, text) &&
          PivotHftRecoveryParseLong(text, value));
}

bool PivotHftRecoveryParseUlongField(const string payload,
                                     const string key,
                                     ulong &value)
{
  string text = "";
  return (PivotHftRecoveryGetField(payload, key, text) &&
          PivotHftRecoveryParseUlong(text, value));
}

bool PivotHftRecoveryParseDoubleField(const string payload,
                                      const string key,
                                      double &value)
{
  string text = "";
  if(!PivotHftRecoveryGetField(payload, key, text) ||
     !PivotHftRecoveryNumberTextValid(text))
    return false;
  value = StringToDouble(text);
  return MathIsValidNumber(value);
}

bool PivotHftRecoveryParseBoolField(const string payload,
                                    const string key,
                                    bool &value)
{
  string text = "";
  if(!PivotHftRecoveryGetField(payload, key, text))
    return false;
  if(text == "1")
  {
    value = true;
    return true;
  }
  if(text == "0")
  {
    value = false;
    return true;
  }
  return false;
}

bool PivotHftRecoveryParseStringField(const string payload,
                                      const string key,
                                      string &value)
{
  string encoded = "";
  return (PivotHftRecoveryGetField(payload, key, encoded) &&
          PivotHftRecoveryDecodeString(encoded, value));
}

string PivotHftRecoverySerializePositionState(
  const PivotHftPositionState &state)
{
  string payload = "";
  PivotHftRecoveryAddIntField(payload, "status", (int)state.status);
  PivotHftRecoveryAddIntField(payload, "execution_source",
                              (int)state.execution_source);
  PivotHftRecoveryAddIntField(payload, "close_trigger",
                              (int)state.close_trigger);
  PivotHftRecoveryAddIntField(payload, "net_class", (int)state.net_class);
  PivotHftRecoveryAddIntField(payload, "retry_state",
                              (int)state.retry_state);
  PivotHftRecoveryAddIntField(payload, "direction", (int)state.direction);
  PivotHftRecoveryAddIntField(payload, "pivot_level",
                              (int)state.pivot_level);
  PivotHftRecoveryAddUlongField(payload, "position_ticket",
                                state.position_ticket);
  PivotHftRecoveryAddUlongField(payload, "position_identifier",
                                state.position_identifier);
  PivotHftRecoveryAddUlongField(payload, "entry_deal_ticket",
                                state.entry_deal_ticket);
  PivotHftRecoveryAddUlongField(payload, "exit_deal_ticket",
                                state.exit_deal_ticket);
  PivotHftRecoveryAddUlongField(payload, "retry_source_ticket",
                                state.campaign_retry_source_ticket);
  PivotHftRecoveryAddUlongField(payload, "force_close_generation",
                                state.force_close_generation_at_entry);
  PivotHftRecoveryAddLongField(payload, "campaign_micro_bar",
                               (long)state.campaign_micro_bar_time);
  PivotHftRecoveryAddLongField(payload, "entry_micro_bar",
                               (long)state.entry_micro_bar_time);
  PivotHftRecoveryAddLongField(payload, "entry_time",
                               (long)state.entry_time);
  PivotHftRecoveryAddLongField(payload, "close_trigger_time",
                               (long)state.close_trigger_time);
  PivotHftRecoveryAddLongField(payload, "close_time",
                               (long)state.close_time);
  PivotHftRecoveryAddLongField(payload, "retry_state_time",
                               (long)state.retry_state_time);
  PivotHftRecoveryAddLongField(payload, "risk_bands_source_bar",
                               (long)state.risk_bands_source_bar);
  PivotHftRecoveryAddDoubleField(payload, "pivot_price", state.pivot_price);
  PivotHftRecoveryAddDoubleField(payload, "entry_price", state.entry_price);
  PivotHftRecoveryAddDoubleField(payload, "entry_request_quote",
                                 state.entry_request_quote);
  PivotHftRecoveryAddDoubleField(payload, "entry_slippage_points",
                                 state.entry_slippage_points);
  PivotHftRecoveryAddDoubleField(payload, "risk_bands_upper",
                                 state.risk_bands_upper);
  PivotHftRecoveryAddDoubleField(payload, "risk_bands_lower",
                                 state.risk_bands_lower);
  PivotHftRecoveryAddDoubleField(payload, "risk_band_width_points",
                                 state.risk_band_width_points);
  PivotHftRecoveryAddDoubleField(payload, "initial_sl_points",
                                 state.initial_sl_points);
  PivotHftRecoveryAddDoubleField(payload, "trailing_step_points",
                                 state.trailing_step_points);
  PivotHftRecoveryAddDoubleField(payload, "fixed_tp_points",
                                 state.fixed_tp_points);
  PivotHftRecoveryAddDoubleField(payload, "local_sl_price",
                                 state.local_sl_price);
  PivotHftRecoveryAddDoubleField(payload, "local_tp_price",
                                 state.local_tp_price);
  PivotHftRecoveryAddDoubleField(payload, "trailing_stop_price",
                                 state.trailing_stop_price);
  PivotHftRecoveryAddDoubleField(payload, "close_trigger_quote",
                                 state.close_trigger_quote);
  PivotHftRecoveryAddDoubleField(payload, "close_trigger_stop",
                                 state.close_trigger_stop);
  PivotHftRecoveryAddDoubleField(payload, "close_trigger_target",
                                 state.close_trigger_target);
  PivotHftRecoveryAddDoubleField(payload, "close_price", state.close_price);
  PivotHftRecoveryAddDoubleField(payload, "close_slippage_points",
                                 state.close_slippage_points);
  PivotHftRecoveryAddDoubleField(payload, "net_result", state.net_result);
  PivotHftRecoveryAddDoubleField(payload, "gross_result", state.gross_result);
  PivotHftRecoveryAddDoubleField(payload, "estimated_cost_result",
                                 state.estimated_cost_result);
  PivotHftRecoveryAddDoubleField(payload, "estimated_cost_per_lot",
                                 state.estimated_cost_per_lot);
  PivotHftRecoveryAddDoubleField(payload, "entry_volume", state.entry_volume);
  PivotHftRecoveryAddIntField(payload, "trailing_step_index",
                              state.trailing_step_index);
  PivotHftRecoveryAddIntField(payload, "close_trigger_step",
                              state.close_trigger_step);
  PivotHftRecoveryAddIntField(payload, "campaign_attempt_count",
                              state.campaign_attempt_count);
  PivotHftRecoveryAddIntField(payload, "campaign_retry_ordinal",
                              state.campaign_retry_ordinal);
  PivotHftRecoveryAddIntField(payload, "next_retry_ordinal",
                              state.next_retry_ordinal);
  PivotHftRecoveryAddIntField(payload, "next_retry_number",
                              state.next_retry_number);
  PivotHftRecoveryAddIntField(payload, "next_retry_execution_source",
                              (int)state.next_retry_execution_source);
  PivotHftRecoveryAddStringField(payload, "execution_id",
                                 state.execution_id);
  PivotHftRecoveryAddStringField(payload, "retry_source_id",
                                 state.campaign_retry_source_id);
  PivotHftRecoveryAddStringField(payload, "campaign_sequence_id",
                                 state.campaign_sequence_id);
  PivotHftRecoveryAddIntField(payload, "model_source_execution_source",
                              (int)state.model_source_execution_source);
  PivotHftRecoveryAddStringField(payload, "model_source_execution_id",
                                 state.model_source_execution_id);
  PivotHftRecoveryAddIntField(payload, "entry_slippage_provenance",
                              (int)state.entry_slippage_provenance);
  PivotHftRecoveryAddIntField(payload, "close_slippage_provenance",
                              (int)state.close_slippage_provenance);
  PivotHftRecoveryAddIntField(payload, "cost_per_lot_provenance",
                              (int)state.cost_per_lot_provenance);
  PivotHftRecoveryAddStringField(payload, "position_comment",
                                 state.position_comment);
  PivotHftRecoveryAddStringField(payload, "retry_state_reason",
                                 state.retry_state_reason);
  PivotHftRecoveryAddLongField(payload, "safety_evaluated_at",
                               (long)state.entry_safety.evaluated_at);
  PivotHftRecoveryAddDoubleField(payload, "safety_requested_sl_points",
                                 state.entry_safety.requested_sl_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_spread_points",
                                 state.entry_safety.spread_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_stops_level_points",
                                 state.entry_safety.stops_level_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_freeze_level_points",
                                 state.entry_safety.freeze_level_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_broker_floor_points",
                                 state.entry_safety.broker_floor_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_required_sl_points",
                                 state.entry_safety.required_initial_sl_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_point_size",
                                 state.entry_safety.point_size);
  PivotHftRecoveryAddDoubleField(payload, "safety_tick_size",
                                 state.entry_safety.tick_size);
  PivotHftRecoveryAddStringField(payload, "safety_reason",
                                 state.entry_safety.reason);
  PivotHftRecoveryAddBoolField(payload, "safety_valid",
                               state.entry_safety.valid);
  PivotHftRecoveryAddBoolField(payload, "safety_blocked",
                               state.entry_safety.blocked);
  PivotHftRecoveryAddDoubleField(payload, "safety_close_quote",
                                 state.entry_safety_close_quote);
  PivotHftRecoveryAddDoubleField(payload, "safety_actual_spread_points",
                                 state.entry_safety_actual_spread_points);
  PivotHftRecoveryAddDoubleField(payload, "safety_available_buffer_points",
                                 state.entry_safety_available_buffer_points);
  PivotHftRecoveryAddStringField(payload, "safety_post_fill_reason",
                                 state.entry_safety_post_fill_reason);
  PivotHftRecoveryAddBoolField(payload, "safety_checked",
                               state.entry_safety_checked);
  PivotHftRecoveryAddBoolField(payload, "safety_failed",
                               state.entry_safety_failed);
  PivotHftRecoveryAddBoolField(payload, "emergency_lifecycle",
                               state.emergency_lifecycle);
  PivotHftRecoveryAddBoolField(payload, "daily_start_registered",
                               state.daily_start_registered);
  PivotHftRecoveryAddBoolField(payload, "close_requested",
                               state.close_requested);
  PivotHftRecoveryAddBoolField(payload, "close_send_confirmed",
                               state.close_send_confirmed);
  PivotHftRecoveryAddBoolField(payload, "reattempt_pending",
                               state.reattempt_pending);
  PivotHftRecoveryAddBoolField(payload, "daily_outcome_registered",
                               state.daily_outcome_registered);
  PivotHftRecoveryAddIntField(payload, "close_attempt_count",
                              state.close_attempt_count);
  PivotHftRecoveryAddLongField(payload, "close_retry_after",
                               (long)state.close_retry_after);
  PivotHftRecoveryAddLongField(payload, "last_close_audit_time",
                               (long)state.last_close_audit_time);
  return payload;
}

bool PivotHftRecoveryDeserializePositionState(
  const string payload,
  PivotHftPositionState &state)
{
  state = PivotHftPositionState();
  int int_value = 0;
  long long_value = 0;

  if(!PivotHftRecoveryParseIntField(payload, "status", int_value))
    return false;
  state.status = (PivotHftPositionStatuses)int_value;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "execution_source",
                                    int_value))
    return false;
  state.execution_source = (PivotHftExecutionSources)int_value;
  if(!PivotHftRecoveryParseIntField(payload, "close_trigger", int_value))
    return false;
  state.close_trigger = (PivotHftCloseTriggers)int_value;
  if(!PivotHftRecoveryParseIntField(payload, "net_class", int_value))
    return false;
  state.net_class = (PivotHftNetClasses)int_value;
  if(!PivotHftRecoveryParseIntField(payload, "retry_state", int_value))
    return false;
  state.retry_state = (PivotHftRetryStates)int_value;
  if(!PivotHftRecoveryParseIntField(payload, "direction", int_value))
    return false;
  state.direction = (SignalTypes)int_value;
  if(!PivotHftRecoveryParseIntField(payload, "pivot_level", int_value))
    return false;
  state.pivot_level = (PivotHftPivotLevels)int_value;

  if(!PivotHftRecoveryParseUlongField(payload,
                                      "position_ticket",
                                      state.position_ticket) ||
     !PivotHftRecoveryParseUlongField(payload,
                                      "position_identifier",
                                      state.position_identifier) ||
     !PivotHftRecoveryParseUlongField(payload,
                                      "entry_deal_ticket",
                                      state.entry_deal_ticket) ||
     !PivotHftRecoveryParseUlongField(payload,
                                      "exit_deal_ticket",
                                      state.exit_deal_ticket) ||
     !PivotHftRecoveryParseUlongField(
       payload,
       "retry_source_ticket",
       state.campaign_retry_source_ticket) ||
     !PivotHftRecoveryParseUlongField(
       payload,
       "force_close_generation",
       state.force_close_generation_at_entry))
    return false;

  if(!PivotHftRecoveryParseLongField(payload,
                                     "campaign_micro_bar",
                                     long_value))
    return false;
  state.campaign_micro_bar_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "entry_micro_bar",
                                     long_value))
    return false;
  state.entry_micro_bar_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload, "entry_time", long_value))
    return false;
  state.entry_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "close_trigger_time",
                                     long_value))
    return false;
  state.close_trigger_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload, "close_time", long_value))
    return false;
  state.close_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "retry_state_time",
                                     long_value))
    return false;
  state.retry_state_time = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "risk_bands_source_bar",
                                     long_value))
    return false;
  state.risk_bands_source_bar = (datetime)long_value;

  if(!PivotHftRecoveryParseDoubleField(payload,
                                       "pivot_price",
                                       state.pivot_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "entry_price",
                                       state.entry_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "entry_request_quote",
                                       state.entry_request_quote) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "entry_slippage_points",
                                       state.entry_slippage_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "risk_bands_upper",
                                       state.risk_bands_upper) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "risk_bands_lower",
                                       state.risk_bands_lower) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "risk_band_width_points",
                                       state.risk_band_width_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "initial_sl_points",
                                       state.initial_sl_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "trailing_step_points",
                                       state.trailing_step_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "fixed_tp_points",
                                       state.fixed_tp_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "local_sl_price",
                                       state.local_sl_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "local_tp_price",
                                       state.local_tp_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "trailing_stop_price",
                                       state.trailing_stop_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "close_trigger_quote",
                                       state.close_trigger_quote) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "close_trigger_stop",
                                       state.close_trigger_stop) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "close_trigger_target",
                                       state.close_trigger_target) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "close_price",
                                       state.close_price) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "close_slippage_points",
                                       state.close_slippage_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "net_result",
                                       state.net_result) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "gross_result",
                                       state.gross_result) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "estimated_cost_result",
                                       state.estimated_cost_result) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "estimated_cost_per_lot",
                                       state.estimated_cost_per_lot) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "entry_volume",
                                       state.entry_volume))
    return false;

  if(!PivotHftRecoveryParseIntField(payload,
                                    "trailing_step_index",
                                    state.trailing_step_index) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "close_trigger_step",
                                    state.close_trigger_step) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "campaign_attempt_count",
                                    state.campaign_attempt_count) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "campaign_retry_ordinal",
                                    state.campaign_retry_ordinal) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "next_retry_ordinal",
                                    state.next_retry_ordinal) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "next_retry_number",
                                    state.next_retry_number))
    return false;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "next_retry_execution_source",
                                    int_value))
    return false;
  state.next_retry_execution_source =
    (PivotHftExecutionSources)int_value;

  if(!PivotHftRecoveryParseStringField(payload,
                                       "execution_id",
                                       state.execution_id) ||
     !PivotHftRecoveryParseStringField(
       payload,
       "retry_source_id",
       state.campaign_retry_source_id) ||
     !PivotHftRecoveryParseStringField(
       payload,
       "campaign_sequence_id",
       state.campaign_sequence_id))
    return false;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "model_source_execution_source",
                                    int_value))
    return false;
  state.model_source_execution_source =
    (PivotHftExecutionSources)int_value;
  if(!PivotHftRecoveryParseStringField(
       payload,
       "model_source_execution_id",
       state.model_source_execution_id))
    return false;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "entry_slippage_provenance",
                                    int_value))
    return false;
  state.entry_slippage_provenance =
    (PivotHftModelValueProvenance)int_value;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "close_slippage_provenance",
                                    int_value))
    return false;
  state.close_slippage_provenance =
    (PivotHftModelValueProvenance)int_value;
  if(!PivotHftRecoveryParseIntField(payload,
                                    "cost_per_lot_provenance",
                                    int_value))
    return false;
  state.cost_per_lot_provenance =
    (PivotHftModelValueProvenance)int_value;
  if(!PivotHftRecoveryParseStringField(payload,
                                       "position_comment",
                                       state.position_comment) ||
     !PivotHftRecoveryParseStringField(payload,
                                       "retry_state_reason",
                                       state.retry_state_reason))
    return false;

  if(!PivotHftRecoveryParseLongField(payload,
                                     "safety_evaluated_at",
                                     long_value))
    return false;
  state.entry_safety.evaluated_at = (datetime)long_value;
  if(!PivotHftRecoveryParseDoubleField(
       payload,
       "safety_requested_sl_points",
       state.entry_safety.requested_sl_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_spread_points",
       state.entry_safety.spread_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_stops_level_points",
       state.entry_safety.stops_level_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_freeze_level_points",
       state.entry_safety.freeze_level_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_broker_floor_points",
       state.entry_safety.broker_floor_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_required_sl_points",
       state.entry_safety.required_initial_sl_points) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "safety_point_size",
                                       state.entry_safety.point_size) ||
     !PivotHftRecoveryParseDoubleField(payload,
                                       "safety_tick_size",
                                       state.entry_safety.tick_size) ||
     !PivotHftRecoveryParseStringField(payload,
                                       "safety_reason",
                                       state.entry_safety.reason) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "safety_valid",
                                     state.entry_safety.valid) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "safety_blocked",
                                     state.entry_safety.blocked) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_close_quote",
       state.entry_safety_close_quote) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_actual_spread_points",
       state.entry_safety_actual_spread_points) ||
     !PivotHftRecoveryParseDoubleField(
       payload,
       "safety_available_buffer_points",
       state.entry_safety_available_buffer_points) ||
     !PivotHftRecoveryParseStringField(
       payload,
       "safety_post_fill_reason",
       state.entry_safety_post_fill_reason) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "safety_checked",
                                     state.entry_safety_checked) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "safety_failed",
                                     state.entry_safety_failed) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "emergency_lifecycle",
                                     state.emergency_lifecycle) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "daily_start_registered",
                                     state.daily_start_registered) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "close_requested",
                                     state.close_requested) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "close_send_confirmed",
                                     state.close_send_confirmed) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "reattempt_pending",
                                     state.reattempt_pending) ||
     !PivotHftRecoveryParseBoolField(payload,
                                     "daily_outcome_registered",
                                     state.daily_outcome_registered) ||
     !PivotHftRecoveryParseIntField(payload,
                                    "close_attempt_count",
                                    state.close_attempt_count))
    return false;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "close_retry_after",
                                     long_value))
    return false;
  state.close_retry_after = (datetime)long_value;
  if(!PivotHftRecoveryParseLongField(payload,
                                     "last_close_audit_time",
                                     long_value))
    return false;
  state.last_close_audit_time = (datetime)long_value;
  return true;
}

bool PivotHftRecoveryPositionStateValid(
  const PivotHftPositionState &state)
{
  if(state.execution_source != PIVOT_HFT_EXECUTION_BROKER ||
     (state.direction != BULLISH && state.direction != BEARISH) ||
     state.position_ticket == 0 ||
     state.position_identifier == 0 ||
     state.entry_time <= 0 ||
     state.entry_price <= 0.0 ||
     state.entry_volume <= 0.0 ||
     !MathIsValidNumber(state.entry_price) ||
     !MathIsValidNumber(state.entry_volume))
    return false;
  if(state.status < PIVOT_HFT_POSITION_ACTIVE ||
     state.status > PIVOT_HFT_POSITION_COMPLETED ||
     state.close_trigger < PIVOT_HFT_CLOSE_TRIGGER_NONE ||
     state.close_trigger > PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE ||
     state.net_class < PIVOT_HFT_NET_NONE ||
     state.net_class > PIVOT_HFT_NET_FLAT ||
     state.retry_state < PIVOT_HFT_RETRY_NONE ||
     state.retry_state > PIVOT_HFT_RETRY_INVALIDATED ||
     state.pivot_level < PIVOT_HFT_LEVEL_NONE ||
     state.pivot_level > PIVOT_HFT_LEVEL_S3)
    return false;
  if(state.next_retry_execution_source < PIVOT_HFT_EXECUTION_BROKER ||
     state.next_retry_execution_source > PIVOT_HFT_EXECUTION_VIRTUAL ||
     state.model_source_execution_source < PIVOT_HFT_EXECUTION_BROKER ||
     state.model_source_execution_source > PIVOT_HFT_EXECUTION_VIRTUAL ||
     state.entry_slippage_provenance <
       PIVOT_HFT_MODEL_VALUE_UNAVAILABLE ||
     state.entry_slippage_provenance > PIVOT_HFT_MODEL_VALUE_FALLBACK ||
     state.close_slippage_provenance <
       PIVOT_HFT_MODEL_VALUE_UNAVAILABLE ||
     state.close_slippage_provenance > PIVOT_HFT_MODEL_VALUE_FALLBACK ||
     state.cost_per_lot_provenance <
       PIVOT_HFT_MODEL_VALUE_UNAVAILABLE ||
     state.cost_per_lot_provenance > PIVOT_HFT_MODEL_VALUE_FALLBACK)
    return false;
  if(state.execution_id != StringFormat("%I64u", state.position_ticket))
    return false;
  if(!state.emergency_lifecycle)
  {
    if(state.entry_deal_ticket == 0 ||
       state.campaign_sequence_id == "" ||
       state.pivot_level == PIVOT_HFT_LEVEL_NONE ||
       state.risk_bands_source_bar <= 0 ||
       state.initial_sl_points <= 0.0 ||
       state.trailing_step_points <= 0.0 ||
       state.local_sl_price <= 0.0 ||
       state.trailing_stop_price <= 0.0 ||
       !MathIsValidNumber(state.local_sl_price) ||
       !MathIsValidNumber(state.trailing_stop_price) ||
       (state.fixed_tp_points > 0.0 && state.local_tp_price <= 0.0) ||
       !state.entry_safety.valid)
      return false;
  }
  return true;
}

string PivotHftRecoveryChecksum(const int schema_version,
                                const int slot,
                                const ulong generation,
                                const string scope_hash,
                                const string payload)
{
  string checksum_source = StringFormat("%d|%d|%I64u|%s|%s",
                                        schema_version,
                                        slot,
                                        generation,
                                        scope_hash,
                                        payload);
  return PivotHftRecoveryFormatHash(
    PivotHftRecoveryFNV1a64(checksum_source));
}

string PivotHftRecoveryBuildRecordText(
  const int slot,
  const ulong generation,
  const string payload)
{
  string checksum = PivotHftRecoveryChecksum(
    PIVOT_HFT_RECOVERY_SCHEMA_VERSION,
    slot,
    generation,
    g_pivot_hft_recovery_scope_hash,
    payload);
  return PIVOT_HFT_RECOVERY_MAGIC + "\n" +
         "schema=" + IntegerToString(PIVOT_HFT_RECOVERY_SCHEMA_VERSION) +
         "\nslot=" + IntegerToString(slot) +
         "\ngeneration=" + StringFormat("%I64u", generation) +
         "\nscope=" + g_pivot_hft_recovery_scope_hash +
         "\nchecksum=" + checksum +
         "\npayload=" + payload;
}

bool PivotHftRecoveryWriteText(const string filename,
                               const string content,
                               string &reason)
{
  reason = "";
  ResetLastError();
  int handle = FileOpen(filename, FILE_WRITE | FILE_BIN | FILE_ANSI);
  if(handle == INVALID_HANDLE)
  {
    reason = StringFormat("file_open_write_failed:%d", GetLastError());
    return false;
  }

  uint expected_length = (uint)StringLen(content);
  uint written_length = FileWriteString(handle, content);
  FileFlush(handle);
  FileClose(handle);
  if(written_length != expected_length)
  {
    reason = StringFormat("file_write_short:%u/%u",
                          written_length,
                          expected_length);
    return false;
  }
  return true;
}

bool PivotHftRecoveryReadText(const string filename,
                              string &content,
                              string &reason)
{
  content = "";
  reason = "";
  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_READ | FILE_BIN | FILE_ANSI | FILE_SHARE_READ);
  if(handle == INVALID_HANDLE)
  {
    reason = StringFormat("file_open_read_failed:%d", GetLastError());
    return false;
  }

  ulong file_size = FileSize(handle);
  if(file_size == 0 || file_size > PIVOT_HFT_RECOVERY_MAX_FILE_BYTES)
  {
    FileClose(handle);
    reason = (file_size == 0) ? "file_empty" : "file_too_large";
    return false;
  }

  content = FileReadString(handle, (int)file_size);
  int read_error = GetLastError();
  FileClose(handle);
  if((ulong)StringLen(content) != file_size)
  {
    reason = StringFormat("file_read_short:%d/%I64u:%d",
                          StringLen(content),
                          file_size,
                          read_error);
    return false;
  }
  return true;
}

bool PivotHftRecoveryReadLine(const string content,
                              int &offset,
                              string &line)
{
  line = "";
  int length = StringLen(content);
  if(offset < 0 || offset >= length)
    return false;

  int end = StringFind(content, "\n", offset);
  if(end < 0)
  {
    line = StringSubstr(content, offset);
    offset = length;
  }
  else
  {
    line = StringSubstr(content, offset, end - offset);
    offset = end + 1;
  }
  if(StringLen(line) > 0 &&
     StringGetCharacter(line, StringLen(line) - 1) == '\r')
    line = StringSubstr(line, 0, StringLen(line) - 1);
  return true;
}

bool PivotHftRecoveryReadKeyLine(const string content,
                                 int &offset,
                                 const string key,
                                 string &value)
{
  string line = "";
  if(!PivotHftRecoveryReadLine(content, offset, line))
    return false;
  string prefix = key + "=";
  if(StringFind(line, prefix) != 0)
    return false;
  value = StringSubstr(line, StringLen(prefix));
  return true;
}

bool PivotHftRecoveryParseRecordText(
  const string content,
  const int expected_slot,
  PivotHftRecoveryRecord &record,
  string &reason)
{
  record = PivotHftRecoveryRecord();
  reason = "";
  int offset = 0;
  string line = "";
  if(!PivotHftRecoveryReadLine(content, offset, line) ||
     line != PIVOT_HFT_RECOVERY_MAGIC)
  {
    reason = "record_magic_mismatch";
    return false;
  }

  string schema_text = "";
  string slot_text = "";
  string generation_text = "";
  string scope_hash = "";
  string checksum = "";
  string payload = "";
  if(!PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "schema",
                                  schema_text) ||
     !PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "slot",
                                  slot_text) ||
     !PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "generation",
                                  generation_text) ||
     !PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "scope",
                                  scope_hash) ||
     !PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "checksum",
                                  checksum) ||
     !PivotHftRecoveryReadKeyLine(content,
                                  offset,
                                  "payload",
                                  payload))
  {
    reason = "record_header_invalid";
    return false;
  }

  long schema_value = 0;
  long slot_value = 0;
  ulong generation = 0;
  if(!PivotHftRecoveryParseLong(schema_text, schema_value) ||
     !PivotHftRecoveryParseLong(slot_text, slot_value) ||
     !PivotHftRecoveryParseUlong(generation_text, generation))
  {
    reason = "record_number_invalid";
    return false;
  }
  if(schema_value != PIVOT_HFT_RECOVERY_SCHEMA_VERSION)
  {
    reason = "record_schema_mismatch";
    return false;
  }
  if(slot_value != expected_slot)
  {
    reason = "record_slot_mismatch";
    return false;
  }
  if(generation == 0)
  {
    reason = "record_generation_invalid";
    return false;
  }
  if(scope_hash != g_pivot_hft_recovery_scope_hash)
  {
    reason = "record_scope_mismatch";
    return false;
  }

  string expected_checksum = PivotHftRecoveryChecksum(
    (int)schema_value,
    (int)slot_value,
    generation,
    scope_hash,
    payload);
  if(checksum != expected_checksum)
  {
    reason = "record_checksum_mismatch";
    return false;
  }

  PivotHftPositionState position_state;
  if(!PivotHftRecoveryDeserializePositionState(payload, position_state) ||
     !PivotHftRecoveryPositionStateValid(position_state))
  {
    reason = "record_position_state_invalid";
    return false;
  }

  record.valid = true;
  record.schema_version = (int)schema_value;
  record.slot = (int)slot_value;
  record.generation = generation;
  record.scope_hash = scope_hash;
  record.payload_checksum = checksum;
  record.payload = payload;
  record.position_state = position_state;
  return true;
}

bool PivotHftRecoveryReadSlot(const int slot,
                              PivotHftRecoveryRecord &record,
                              string &reason)
{
  record = PivotHftRecoveryRecord();
  reason = "";
  string filename = PivotHftRecoverySlotFilename(slot);
  if(!FileIsExist(filename))
  {
    reason = "missing";
    return false;
  }

  string content = "";
  if(!PivotHftRecoveryReadText(filename, content, reason))
    return false;
  return PivotHftRecoveryParseRecordText(content, slot, record, reason);
}

bool PivotHftRecoveryReadBestRecord(PivotHftRecoveryRecord &record,
                                    bool &slot_exists,
                                    int &invalid_slot_count)
{
  record = PivotHftRecoveryRecord();
  slot_exists = false;
  invalid_slot_count = 0;
  bool generation_conflict = false;
  for(int slot = PIVOT_HFT_RECOVERY_SLOT_A;
      slot <= PIVOT_HFT_RECOVERY_SLOT_B;
      slot++)
  {
    PivotHftRecoveryRecord candidate;
    string reason = "";
    bool exists = FileIsExist(PivotHftRecoverySlotFilename(slot));
    if(exists)
      slot_exists = true;
    if(!PivotHftRecoveryReadSlot(slot, candidate, reason))
    {
      if(exists)
      {
        invalid_slot_count++;
        PivotHftAuditLog("RECOVERY_SLOT_REJECTED",
                         StringFormat("slot=%d|reason=%s", slot, reason));
      }
      continue;
    }
    if(record.valid &&
       candidate.generation == record.generation &&
       candidate.payload != record.payload)
    {
      generation_conflict = true;
      invalid_slot_count++;
      PivotHftAuditLog("RECOVERY_SLOT_REJECTED",
                       StringFormat("slot=%d|reason=generation_conflict",
                                    slot));
      continue;
    }
    if(!record.valid || candidate.generation > record.generation)
      record = candidate;
  }
  if(generation_conflict)
  {
    record = PivotHftRecoveryRecord();
    return false;
  }
  return record.valid;
}

bool PivotHftRecoveryDeleteFileIfPresent(const string filename,
                                         string &reason)
{
  reason = "";
  if(!FileIsExist(filename))
    return true;
  ResetLastError();
  if(FileDelete(filename))
    return true;
  reason = StringFormat("file_delete_failed:%d", GetLastError());
  return false;
}

bool PivotHftRecoveryDeleteSlots(string &reason)
{
  reason = "";
  string delete_reason = "";
  if(!PivotHftRecoveryDeleteFileIfPresent(
       PivotHftRecoverySlotFilename(PIVOT_HFT_RECOVERY_SLOT_A),
       delete_reason))
  {
    reason = "slot_a_" + delete_reason;
    return false;
  }
  if(!PivotHftRecoveryDeleteFileIfPresent(
       PivotHftRecoverySlotFilename(PIVOT_HFT_RECOVERY_SLOT_B),
       delete_reason))
  {
    reason = "slot_b_" + delete_reason;
    return false;
  }
  g_pivot_hft_recovery_generation = 0;
  g_pivot_hft_recovery_active_slot = -1;
  g_pivot_hft_recovery_cleanup_pending = false;
  return true;
}

bool PivotHftRecoveryStoragePreflight(string &reason)
{
  reason = "";
  string probe_filename = PivotHftRecoveryProbeFilename();
  string probe_content = StringFormat("probe|%s|%I64d",
                                      g_pivot_hft_recovery_scope_hash,
                                      (long)TimeCurrent());
  if(!PivotHftRecoveryWriteText(probe_filename, probe_content, reason))
    return false;

  string read_content = "";
  if(!PivotHftRecoveryReadText(probe_filename, read_content, reason) ||
     read_content != probe_content)
  {
    if(reason == "")
      reason = "probe_readback_mismatch";
    string ignored_reason = "";
    PivotHftRecoveryDeleteFileIfPresent(probe_filename, ignored_reason);
    return false;
  }

  if(!PivotHftRecoveryDeleteFileIfPresent(probe_filename, reason))
    return false;
  return true;
}

void PivotHftRecoveryRegisterStorageFailure(const string reason)
{
  g_pivot_hft_recovery_storage_ready = false;
  g_pivot_hft_recovery_next_preflight = TimeCurrent() +
    PIVOT_HFT_RECOVERY_PREFLIGHT_RETRY_SECONDS;
  datetime now_time = TimeCurrent();
  if(g_pivot_hft_recovery_last_failure_audit == 0 ||
     now_time - g_pivot_hft_recovery_last_failure_audit >= 30)
  {
    PivotHftAuditLog("RECOVERY_STORAGE_FAILURE",
                     StringFormat("reason=%s", reason));
    g_pivot_hft_recovery_last_failure_audit = now_time;
  }
  MarketStatusRegisterExecutionError("PIVOT_HFT_RECOVERY_STORAGE",
                                     reason,
                                     0,
                                     GetLastError());
}

bool PivotHftRecoveryWriteCheckpoint(
  const PivotHftPositionState &position_state,
  const string transition,
  string &reason)
{
  reason = "";
  if(position_state.execution_source != PIVOT_HFT_EXECUTION_BROKER)
    return true;
  if(!g_pivot_hft_recovery_initialized ||
     !g_pivot_hft_recovery_storage_ready)
  {
    reason = "recovery_storage_not_ready";
    return false;
  }
  if(!PivotHftRecoveryPositionStateValid(position_state))
  {
    reason = "checkpoint_position_state_invalid";
    return false;
  }

  ulong next_generation = g_pivot_hft_recovery_generation + 1;
  if(next_generation <= g_pivot_hft_recovery_generation)
  {
    reason = "checkpoint_generation_overflow";
    return false;
  }
  int next_slot = (g_pivot_hft_recovery_active_slot ==
                     PIVOT_HFT_RECOVERY_SLOT_A)
                  ? PIVOT_HFT_RECOVERY_SLOT_B
                  : PIVOT_HFT_RECOVERY_SLOT_A;
  string payload = PivotHftRecoverySerializePositionState(position_state);
  string record_text = PivotHftRecoveryBuildRecordText(next_slot,
                                                       next_generation,
                                                       payload);
  string filename = PivotHftRecoverySlotFilename(next_slot);
  if(!PivotHftRecoveryWriteText(filename, record_text, reason))
    return false;

  PivotHftRecoveryRecord readback;
  string read_reason = "";
  if(!PivotHftRecoveryReadSlot(next_slot, readback, read_reason) ||
     !readback.valid ||
     readback.generation != next_generation ||
     readback.payload != payload ||
     readback.position_state.position_ticket !=
       position_state.position_ticket ||
     readback.position_state.position_identifier !=
       position_state.position_identifier)
  {
    reason = (read_reason == "")
             ? "checkpoint_readback_mismatch"
             : read_reason;
    return false;
  }

  g_pivot_hft_recovery_generation = next_generation;
  g_pivot_hft_recovery_active_slot = next_slot;
  PivotHftAuditLog("RECOVERY_CHECKPOINT",
                   StringFormat("generation=%I64u|slot=%d|transition=%s|ticket=%I64u|position_id=%I64u|status=%s|close_trigger=%s|trailing_step=%d",
                                next_generation,
                                next_slot,
                                transition,
                                position_state.position_ticket,
                                position_state.position_identifier,
                                EnumToString(position_state.status),
                                EnumToString(position_state.close_trigger),
                                position_state.trailing_step_index));
  return true;
}

bool PivotHftRecoveryPositionExposureOpen(
  const PivotHftPositionState &position_state)
{
  if(position_state.position_ticket == 0 ||
     !PositionSelectByTicket(position_state.position_ticket))
    return false;
  if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
     PositionGetInteger(POSITION_MAGIC) != g_magic_number)
    return false;
  ulong selected_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  return (position_state.position_identifier == 0 ||
          selected_identifier == position_state.position_identifier);
}

void PivotHftRecoveryQuarantinePositionState(
  PivotHftPositionState &position_state,
  const string reason)
{
  position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE;
  if(position_state.close_trigger_time <= 0)
    position_state.close_trigger_time = TimeCurrent();
  position_state.close_requested = true;
  position_state.close_send_confirmed = false;
  position_state.emergency_lifecycle = true;
  position_state.reattempt_pending = false;
  position_state.retry_state = PIVOT_HFT_RETRY_DISABLED;
  position_state.retry_state_reason = "recovery_failure";
  position_state.retry_state_time = TimeCurrent();

  PivotHftCampaignState campaign;
  campaign.direction = position_state.direction;
  campaign.pivot_level = position_state.pivot_level;
  campaign.pivot_price = position_state.pivot_price;
  campaign.micro_bar_time = position_state.campaign_micro_bar_time;
  campaign.attempt_count = position_state.campaign_attempt_count;
  campaign.retry_ordinal = position_state.campaign_retry_ordinal;
  campaign.sequence_id = position_state.campaign_sequence_id;
  PivotHftActivateEmergencyQuarantine(
    campaign,
    position_state.position_ticket,
    position_state.position_identifier,
    position_state.entry_deal_ticket,
    position_state.entry_time,
    position_state.entry_price,
    position_state.entry_volume,
    position_state.position_comment,
    position_state.daily_start_registered,
    PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE,
    reason);
  g_pivot_hft_emergency_quarantine.daily_outcome_registered =
    position_state.daily_outcome_registered;
  PivotHftMarkEmergencyQuarantineStateAttached();
  PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_QUARANTINE, reason);
  MarketStatusRequestScopedForceClose("Pivot HFT recovery failure",
                                      position_state.position_ticket,
                                      position_state.position_identifier);
  PivotHftAuditLog("RECOVERY_POSITION_QUARANTINED",
                   StringFormat("ticket=%I64u|position_id=%I64u|reason=%s",
                                position_state.position_ticket,
                                position_state.position_identifier,
                                reason));
}

bool PivotHftRecoveryCheckpointOrQuarantine(
  PivotHftPositionState &position_state,
  const string transition)
{
  if(position_state.execution_source != PIVOT_HFT_EXECUTION_BROKER)
    return true;
  if(g_pivot_hft_recovery_multiple_quarantine &&
     position_state.emergency_lifecycle)
    return true;

  string reason = "";
  if(PivotHftRecoveryWriteCheckpoint(position_state,
                                     transition,
                                     reason))
    return true;

  PivotHftRecoveryRegisterStorageFailure(
    transition + ":" + reason);
  if(PivotHftRecoveryPositionExposureOpen(position_state))
  {
    PivotHftRecoveryQuarantinePositionState(
      position_state,
      transition + ":" + reason);
  }
  else
  {
    g_pivot_hft_recovery_cleanup_pending = true;
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                              transition + ":" + reason);
  }
  return false;
}

ulong PivotHftRecoveryFindEntryDeal(const ulong position_identifier,
                                    const SignalTypes direction)
{
  if(position_identifier == 0 ||
     !HistorySelectByPosition(position_identifier))
    return 0;

  ulong selected_deal = 0;
  long selected_time_msc = 0;
  int total_deals = HistoryDealsTotal();
  for(int i = 0; i < total_deals; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket == 0 ||
       HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_magic_number ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) !=
         position_identifier)
      continue;

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    ENUM_DEAL_TYPE deal_type =
      (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
    if(deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT)
      continue;
    if((direction == BULLISH && deal_type != DEAL_TYPE_BUY) ||
       (direction == BEARISH && deal_type != DEAL_TYPE_SELL))
      continue;

    long deal_time_msc = HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
    if(selected_deal == 0 || deal_time_msc < selected_time_msc ||
       (deal_time_msc == selected_time_msc && deal_ticket < selected_deal))
    {
      selected_deal = deal_ticket;
      selected_time_msc = deal_time_msc;
    }
  }
  return selected_deal;
}

bool PivotHftRecoveryHistoryOutcome(
  const PivotHftPositionState &position_state,
  double &net_result,
  datetime &close_time)
{
  net_result = 0.0;
  close_time = 0;
  if(position_state.position_identifier == 0 ||
     !HistorySelectByPosition(position_state.position_identifier))
    return false;

  bool has_close_deal = false;
  long latest_close_time_msc = 0;
  int total_deals = HistoryDealsTotal();
  for(int i = 0; i < total_deals; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket == 0 ||
       HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_magic_number ||
       (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) !=
         position_state.position_identifier)
      continue;

    net_result += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_FEE);

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT)
      continue;
    has_close_deal = true;
    datetime deal_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    long deal_time_msc = HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
    if(deal_time_msc <= 0)
      deal_time_msc = (long)deal_time * 1000;
    if(deal_time_msc > latest_close_time_msc)
    {
      latest_close_time_msc = deal_time_msc;
      close_time = deal_time;
    }
  }
  return has_close_deal;
}

int PivotHftRecoveryCollectBrokerPosition(
  PivotHftRecoveryBrokerPosition &broker_position,
  const bool resolve_entry_deal)
{
  broker_position = PivotHftRecoveryBrokerPosition();
  int matching_count = 0;
  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    matching_count++;
    if(broker_position.valid)
      continue;
    ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(position_type == POSITION_TYPE_BUY)
      broker_position.direction = BULLISH;
    else if(position_type == POSITION_TYPE_SELL)
      broker_position.direction = BEARISH;
    else
      continue;

    broker_position.valid = true;
    broker_position.position_ticket = position_ticket;
    broker_position.position_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    broker_position.entry_time =
      (datetime)PositionGetInteger(POSITION_TIME);
    broker_position.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    broker_position.entry_volume = PositionGetDouble(POSITION_VOLUME);
    broker_position.position_comment =
      PositionGetString(POSITION_COMMENT);
    if(resolve_entry_deal)
    {
      broker_position.entry_deal_ticket = PivotHftRecoveryFindEntryDeal(
        broker_position.position_identifier,
        broker_position.direction);
    }
  }
  return matching_count;
}

bool PivotHftRecoveryBrokerStateMatches(
  const PivotHftPositionState &state,
  const PivotHftRecoveryBrokerPosition &broker_position,
  string &reason)
{
  reason = "";
  if(!broker_position.valid)
    reason = "broker_position_invalid";
  else if(state.status != PIVOT_HFT_POSITION_ACTIVE &&
          state.status != PIVOT_HFT_POSITION_CLOSE_WAIT)
    reason = "checkpoint_status_not_open";
  else if(state.position_ticket != broker_position.position_ticket)
    reason = "position_ticket_mismatch";
  else if(state.position_identifier !=
          broker_position.position_identifier)
    reason = "position_identifier_mismatch";
  else if(state.direction != broker_position.direction)
    reason = "position_direction_mismatch";
  else if(state.entry_time != broker_position.entry_time)
    reason = "position_entry_time_mismatch";
  else
  {
    double price_tolerance = MathMax(PivotHftTickSize() * 0.5,
                                     PivotHftPointSize() * 0.5);
    double volume_tolerance = MathMax(
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) * 0.5,
      0.00000001);
    if(MathAbs(state.entry_price - broker_position.entry_price) >
         price_tolerance)
      reason = "position_entry_price_mismatch";
    else if(MathAbs(state.entry_volume - broker_position.entry_volume) >
              volume_tolerance)
      reason = "position_volume_mismatch";
  }

  if(reason != "")
    return false;
  if(state.entry_deal_ticket > 0)
  {
    ENUM_DEAL_ENTRY deal_entry = DEAL_ENTRY_IN;
    ENUM_DEAL_TYPE deal_type = DEAL_TYPE_BUY;
    if(!HistoryDealSelect(state.entry_deal_ticket) ||
       HistoryDealGetString(state.entry_deal_ticket, DEAL_SYMBOL) !=
         _Symbol ||
       HistoryDealGetInteger(state.entry_deal_ticket, DEAL_MAGIC) !=
         g_magic_number ||
       (ulong)HistoryDealGetInteger(state.entry_deal_ticket,
                                    DEAL_POSITION_ID) !=
         state.position_identifier)
    {
      reason = "entry_deal_identity_mismatch";
      return false;
    }
    deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
      state.entry_deal_ticket,
      DEAL_ENTRY);
    deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(
      state.entry_deal_ticket,
      DEAL_TYPE);
    if((deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT) ||
       (state.direction == BULLISH && deal_type != DEAL_TYPE_BUY) ||
       (state.direction == BEARISH && deal_type != DEAL_TYPE_SELL))
    {
      reason = "entry_deal_type_mismatch";
      return false;
    }
  }
  return true;
}

void PivotHftRecoveryRestoreDailyStart(
  PivotHftPositionState &position_state)
{
  if(position_state.entry_time < ResolveCurrentDayStart())
  {
    position_state.daily_start_registered = true;
    return;
  }
  bool restored_daily_start = false;
  RegisterPivotHftDailySignalStart(position_state.direction,
                                   restored_daily_start);
  position_state.daily_start_registered = restored_daily_start;
}

bool PivotHftRecoveryAppendSafetyQuarantine(
  const PivotHftRecoveryBrokerPosition &broker_position,
  const string reason)
{
  if(!broker_position.valid)
    return false;

  PivotHftPositionState position_state;
  position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
  position_state.execution_source = PIVOT_HFT_EXECUTION_BROKER;
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE;
  position_state.retry_state = PIVOT_HFT_RETRY_DISABLED;
  position_state.retry_state_reason = "recovery_failure";
  position_state.retry_state_time = TimeCurrent();
  position_state.direction = broker_position.direction;
  position_state.position_ticket = broker_position.position_ticket;
  position_state.position_identifier = broker_position.position_identifier;
  position_state.entry_deal_ticket = broker_position.entry_deal_ticket;
  position_state.entry_time = broker_position.entry_time;
  position_state.entry_price = broker_position.entry_price;
  position_state.entry_volume = broker_position.entry_volume;
  position_state.execution_id = StringFormat(
    "%I64u",
    broker_position.position_ticket);
  position_state.position_comment = broker_position.position_comment;
  position_state.close_trigger_time = TimeCurrent();
  position_state.close_trigger_quote = broker_position.entry_price;
  position_state.close_requested = true;
  position_state.emergency_lifecycle = true;
  position_state.campaign_sequence_id = "recovery";
  position_state.force_close_generation_at_entry =
    MarketStatusForceCloseGeneration();
  PivotHftRecoveryRestoreDailyStart(position_state);

  PivotHftCampaignState campaign;
  campaign.direction = broker_position.direction;
  campaign.sequence_id = "recovery";
  PivotHftActivateEmergencyQuarantine(
    campaign,
    broker_position.position_ticket,
    broker_position.position_identifier,
    broker_position.entry_deal_ticket,
    broker_position.entry_time,
    broker_position.entry_price,
    broker_position.entry_volume,
    broker_position.position_comment,
    position_state.daily_start_registered,
    PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE,
    reason);

  if(!PivotHftAppendPositionState(position_state))
    return false;
  PivotHftMarkEmergencyQuarantineStateAttached();
  int state_index = PivotHftFindPositionStateIndex(
    position_state.execution_id,
    position_state.position_ticket);
  if(state_index >= 0 && g_pivot_hft_recovery_storage_ready)
  {
    PivotHftRecoveryCheckpointOrQuarantine(
      g_pivot_hft_positions[state_index],
      "recovery_quarantine_attached");
  }
  return true;
}

void PivotHftRecoveryAppendMultipleSafetyStates()
{
  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket) ||
       PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    SignalTypes direction = (position_type == POSITION_TYPE_BUY)
                            ? BULLISH
                            : BEARISH;
    PivotHftPositionState position_state;
    position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    position_state.execution_source = PIVOT_HFT_EXECUTION_BROKER;
    position_state.close_trigger =
      PIVOT_HFT_CLOSE_TRIGGER_RECOVERY_FAILURE;
    position_state.retry_state = PIVOT_HFT_RETRY_DISABLED;
    position_state.retry_state_reason = "multiple_scoped_positions";
    position_state.retry_state_time = TimeCurrent();
    position_state.direction = direction;
    position_state.position_ticket = position_ticket;
    position_state.position_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    position_state.entry_time =
      (datetime)PositionGetInteger(POSITION_TIME);
    position_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
    position_state.position_comment =
      PositionGetString(POSITION_COMMENT);
    position_state.entry_deal_ticket = PivotHftRecoveryFindEntryDeal(
      position_state.position_identifier,
      direction);
    position_state.execution_id = StringFormat("%I64u", position_ticket);
    position_state.campaign_sequence_id = "recovery-multiple";
    position_state.close_trigger_time = TimeCurrent();
    position_state.close_trigger_quote = position_state.entry_price;
    position_state.close_requested = true;
    position_state.emergency_lifecycle = true;
    position_state.force_close_generation_at_entry =
      MarketStatusForceCloseGeneration();
    PivotHftRecoveryRestoreDailyStart(position_state);
    PivotHftAppendPositionState(position_state);
  }
}

bool PivotHftRecoveryReconcileFlatRecord(
  PivotHftRecoveryRecord &record,
  string &reason)
{
  reason = "";
  PivotHftPositionState state = record.position_state;
  datetime day_start = ResolveCurrentDayStart();
  if(state.entry_time >= day_start)
    PivotHftRecoveryRestoreDailyStart(state);

  double net_result = state.net_result;
  datetime close_time = state.close_time;
  if(state.status == PIVOT_HFT_POSITION_ACTIVE ||
     state.status == PIVOT_HFT_POSITION_CLOSE_WAIT ||
     close_time <= 0)
  {
    if(!PivotHftRecoveryHistoryOutcome(state,
                                       net_result,
                                       close_time))
    {
      reason = "stale_checkpoint_history_unavailable";
      return false;
    }
  }
  if(close_time >= day_start)
    RegisterDailySignalOutcome(state.direction, net_result);

  PivotHftAuditLog("RECOVERY_STALE_RECONCILED",
                   StringFormat("generation=%I64u|ticket=%I64u|position_id=%I64u|status=%s",
                                record.generation,
                                state.position_ticket,
                                state.position_identifier,
                                EnumToString(state.status)));
  return true;
}

bool PivotHftRecoveryRestoreRecord(
  PivotHftRecoveryRecord &record,
  const PivotHftRecoveryBrokerPosition &broker_position,
  string &reason)
{
  reason = "";
  if(!PivotHftRecoveryBrokerStateMatches(record.position_state,
                                         broker_position,
                                         reason))
    return false;

  PivotHftPositionState restored_state = record.position_state;
  if(restored_state.close_trigger != PIVOT_HFT_CLOSE_TRIGGER_NONE)
  {
    restored_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    restored_state.close_requested = true;
  }
  if(restored_state.status == PIVOT_HFT_POSITION_CLOSE_WAIT &&
     restored_state.close_retry_after <= TimeCurrent())
    restored_state.close_send_confirmed = false;
  PivotHftRecoveryRestoreDailyStart(restored_state);
  if(!PivotHftAppendPositionState(restored_state))
  {
    reason = "recovered_state_append_failed";
    return false;
  }

  int state_index = PivotHftFindPositionStateIndex(
    restored_state.execution_id,
    restored_state.position_ticket);
  if(state_index < 0)
  {
    reason = "recovered_state_lookup_failed";
    return false;
  }
  if(!PivotHftRecoveryCheckpointOrQuarantine(
       g_pivot_hft_positions[state_index],
       "startup_recovered"))
  {
    reason = "recovered_state_checkpoint_failed";
    return false;
  }

  PivotHftRecoveryStatuses status =
    (g_pivot_hft_positions[state_index].status ==
       PIVOT_HFT_POSITION_CLOSE_WAIT)
      ? PIVOT_HFT_RECOVERY_CLOSE_WAIT
      : PIVOT_HFT_RECOVERY_RECOVERED;
  PivotHftRecoverySetStatus(status, "exact_checkpoint_restored");
  PivotHftAuditLog("RECOVERY_POSITION_RESTORED",
                   StringFormat("generation=%I64u|ticket=%I64u|position_id=%I64u|status=%s|local_sl=%.5f|local_tp=%.5f|trailing_step=%d",
                                record.generation,
                                restored_state.position_ticket,
                                restored_state.position_identifier,
                                EnumToString(restored_state.status),
                                restored_state.local_sl_price,
                                restored_state.local_tp_price,
                                restored_state.trailing_step_index));
  return true;
}

bool PivotHftRecoveryInitialize()
{
  g_pivot_hft_recovery_initialized = false;
  g_pivot_hft_recovery_storage_ready = false;
  g_pivot_hft_recovery_reason = "";
  g_pivot_hft_recovery_scope_hash = PivotHftRecoveryResolveScopeHash();
  g_pivot_hft_recovery_generation = 0;
  g_pivot_hft_recovery_active_slot = -1;
  g_pivot_hft_recovery_cleanup_pending = false;
  g_pivot_hft_recovery_multiple_quarantine = false;
  PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_UNINITIALIZED,
                            "startup_reconciliation");

  PivotHftRecoveryBrokerPosition broker_position;
  int matching_positions = PivotHftRecoveryCollectBrokerPosition(
    broker_position,
    true);

  string preflight_reason = "";
  bool preflight_ready = PivotHftRecoveryStoragePreflight(
    preflight_reason);
  if(!preflight_ready)
    PivotHftRecoveryRegisterStorageFailure(preflight_reason);
  else
    g_pivot_hft_recovery_storage_ready = true;

  PivotHftRecoveryRecord record;
  bool slot_exists = false;
  int invalid_slot_count = 0;
  bool record_ready = PivotHftRecoveryReadBestRecord(record,
                                                     slot_exists,
                                                     invalid_slot_count);
  if(record_ready)
  {
    g_pivot_hft_recovery_generation = record.generation;
    g_pivot_hft_recovery_active_slot = record.slot;
  }

  g_pivot_hft_recovery_initialized = true;
  if(matching_positions == 0)
  {
    if(!preflight_ready)
    {
      PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                                preflight_reason);
      return false;
    }
    if(record_ready)
    {
      string reconcile_reason = "";
      if(!PivotHftRecoveryReconcileFlatRecord(record,
                                              reconcile_reason))
      {
        PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                                  reconcile_reason);
        return false;
      }
    }
    if(slot_exists)
    {
      string delete_reason = "";
      if(!PivotHftRecoveryDeleteSlots(delete_reason))
      {
        PivotHftRecoveryRegisterStorageFailure(delete_reason);
        PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                                  delete_reason);
        return false;
      }
    }
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_READY,
                              invalid_slot_count > 0
                                ? "corrupt_stale_slots_removed"
                                : "flat_scope_ready");
    return true;
  }

  if(!preflight_ready)
  {
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_QUARANTINE,
                              "storage_unavailable_with_exposure");
  }
  else if(matching_positions == 1 && record_ready)
  {
    string restore_reason = "";
    if(PivotHftRecoveryRestoreRecord(record,
                                     broker_position,
                                     restore_reason))
      return true;
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_QUARANTINE,
                              restore_reason);
  }
  else
  {
    PivotHftRecoverySetStatus(
      PIVOT_HFT_RECOVERY_QUARANTINE,
      (matching_positions > 1)
        ? "multiple_scoped_positions"
        : (invalid_slot_count > 0
             ? "checkpoint_corrupt"
             : "checkpoint_missing"));
  }

  if(matching_positions > 1)
  {
    g_pivot_hft_recovery_multiple_quarantine = true;
    PivotHftRecoveryAppendMultipleSafetyStates();
    MarketStatusRequestForceClose(
      "Pivot HFT recovery multiple-position quarantine");
  }
  else
  {
    string quarantine_reason = PivotHftRecoveryStatusReason();
    if(!PivotHftRecoveryAppendSafetyQuarantine(broker_position,
                                               quarantine_reason))
    {
      MarketStatusRequestScopedForceClose(
        "Pivot HFT recovery quarantine",
        broker_position.position_ticket,
        broker_position.position_identifier);
    }
  }
  ProtectionRiskProcessPendingForceClose();
  return true;
}

bool PivotHftRecoveryFinalizeBrokerLifecycle(
  PivotHftPositionState &position_state,
  const string transition)
{
  if(position_state.execution_source != PIVOT_HFT_EXECUTION_BROKER)
    return true;
  if(g_pivot_hft_recovery_multiple_quarantine &&
     position_state.emergency_lifecycle)
  {
    if(PivotHftHasManagedBrokerPosition())
      return true;
    string multiple_delete_reason = "";
    if(!PivotHftRecoveryDeleteSlots(multiple_delete_reason))
    {
      PivotHftRecoveryRegisterStorageFailure(multiple_delete_reason);
      PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                                multiple_delete_reason);
      return false;
    }
    g_pivot_hft_recovery_multiple_quarantine = false;
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_READY,
                              "multiple_exposure_reconciled");
    return true;
  }
  if(!PivotHftRecoveryCheckpointOrQuarantine(position_state, transition))
    return false;
  if(PivotHftRecoveryPositionExposureOpen(position_state))
    return true;

  string delete_reason = "";
  if(!PivotHftRecoveryDeleteSlots(delete_reason))
  {
    g_pivot_hft_recovery_cleanup_pending = true;
    PivotHftRecoveryRegisterStorageFailure(delete_reason);
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_STORAGE_ERROR,
                              delete_reason);
    return false;
  }
  g_pivot_hft_recovery_storage_ready = true;
  PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_READY,
                            "broker_lifecycle_reconciled");
  return true;
}

void PivotHftRecoveryOnEmergencyReconciled()
{
  if(PivotHftHasManagedBrokerPosition() ||
     g_pivot_hft_emergency_quarantine.active)
    return;
  string delete_reason = "";
  if(g_pivot_hft_recovery_storage_ready &&
     PivotHftRecoveryDeleteSlots(delete_reason))
  {
    PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_READY,
                              "emergency_lifecycle_reconciled");
    return;
  }
  g_pivot_hft_recovery_cleanup_pending = true;
  if(delete_reason != "")
    PivotHftRecoveryRegisterStorageFailure(delete_reason);
}

void PivotHftRecoveryTick()
{
  if(!g_pivot_hft_recovery_initialized)
    return;

  PivotHftRecoveryBrokerPosition broker_position;
  int matching_positions = PivotHftRecoveryCollectBrokerPosition(
    broker_position,
    false);
  datetime now_time = TimeCurrent();
  if(!g_pivot_hft_recovery_storage_ready &&
     now_time >= g_pivot_hft_recovery_next_preflight)
  {
    string preflight_reason = "";
    if(PivotHftRecoveryStoragePreflight(preflight_reason))
      g_pivot_hft_recovery_storage_ready = true;
    else
      PivotHftRecoveryRegisterStorageFailure(preflight_reason);
  }

  if(matching_positions > 0)
  {
    if(g_pivot_hft_recovery_status == PIVOT_HFT_RECOVERY_QUARANTINE ||
       g_pivot_hft_recovery_status ==
         PIVOT_HFT_RECOVERY_CLOSE_WAIT ||
       g_pivot_hft_recovery_status ==
         PIVOT_HFT_RECOVERY_STORAGE_ERROR)
    {
      if(matching_positions > 1)
        MarketStatusRequestForceClose(
          "Pivot HFT recovery multiple-position quarantine");
      else if(!g_pivot_hft_emergency_quarantine.active)
        MarketStatusRequestScopedForceClose(
          "Pivot HFT recovery quarantine",
          broker_position.position_ticket,
          broker_position.position_identifier);
      ProtectionRiskProcessPendingForceClose();
      if(MarketStatusHasPendingForceClose())
      {
        PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_CLOSE_WAIT,
                                  "recovery_close_pending");
      }
    }
    return;
  }

  if(g_pivot_hft_emergency_quarantine.active)
    return;
  if(g_pivot_hft_recovery_multiple_quarantine &&
     PivotHftHasPositionStates())
    return;
  if(!g_pivot_hft_recovery_cleanup_pending &&
     g_pivot_hft_recovery_status != PIVOT_HFT_RECOVERY_QUARANTINE &&
     g_pivot_hft_recovery_status != PIVOT_HFT_RECOVERY_CLOSE_WAIT &&
     g_pivot_hft_recovery_status !=
       PIVOT_HFT_RECOVERY_STORAGE_ERROR)
    return;
  if(!g_pivot_hft_recovery_storage_ready)
    return;

  string delete_reason = "";
  if(!PivotHftRecoveryDeleteSlots(delete_reason))
  {
    PivotHftRecoveryRegisterStorageFailure(delete_reason);
    return;
  }
  PivotHftRecoverySetStatus(PIVOT_HFT_RECOVERY_READY,
                            "flat_scope_recovered");
}

void PivotHftRecoveryFlushOnDeinit()
{
  int total = ArraySize(g_pivot_hft_positions);
  bool close_required = false;
  if(g_pivot_hft_recovery_multiple_quarantine &&
     PivotHftHasManagedBrokerPosition())
  {
    MarketStatusRequestForceClose(
      "Pivot HFT recovery deinit quarantine");
    close_required = true;
  }
  for(int i = 0; i < total; i++)
  {
    if(g_pivot_hft_positions[i].execution_source !=
         PIVOT_HFT_EXECUTION_BROKER ||
       !PivotHftRecoveryPositionExposureOpen(g_pivot_hft_positions[i]))
      continue;
    if(!PivotHftRecoveryCheckpointOrQuarantine(
         g_pivot_hft_positions[i],
         "deinit_flush"))
      close_required = true;
  }
  if(close_required)
    ProtectionRiskProcessPendingForceClose();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RECOVERY_MQH_
