//+------------------------------------------------------------------+
//|                         pivot_hft_state.mqh                      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_

#define PIVOT_HFT_LEVEL_SLOT_TOTAL 8
#define PIVOT_HFT_OCCUPIED_AUDIT_SIGNATURE_CAPACITY 64

enum PivotHftExecutionSources
{
  PIVOT_HFT_EXECUTION_BROKER  = 0,
  PIVOT_HFT_EXECUTION_VIRTUAL = 1
};

enum PivotHftRetryStates
{
  PIVOT_HFT_RETRY_NONE        = 0,
  PIVOT_HFT_RETRY_PENDING     = 1,
  PIVOT_HFT_RETRY_DEFERRED    = 2,
  PIVOT_HFT_RETRY_REARMED     = 3,
  PIVOT_HFT_RETRY_DISABLED    = 4,
  PIVOT_HFT_RETRY_INVALIDATED = 5
};

enum PivotHftModelValueProvenance
{
  PIVOT_HFT_MODEL_VALUE_UNAVAILABLE = 0,
  PIVOT_HFT_MODEL_VALUE_OBSERVED    = 1,
  PIVOT_HFT_MODEL_VALUE_FALLBACK    = 2
};

enum PivotHftLevelTestStatuses
{
  PIVOT_HFT_LEVEL_UNTESTED      = 0,
  PIVOT_HFT_LEVEL_TOUCHED_OPEN  = 1,
  PIVOT_HFT_LEVEL_BURNED         = 2
};

struct PivotHftPivotSnapshot
{
  datetime source_bar_time;
  double pivot;
  double resistance_1;
  double resistance_2;
  double resistance_3;
  double support_1;
  double support_2;
  double support_3;
  bool valid;

  PivotHftPivotSnapshot()
  {
    source_bar_time = 0;
    pivot           = 0.0;
    resistance_1   = 0.0;
    resistance_2   = 0.0;
    resistance_3   = 0.0;
    support_1      = 0.0;
    support_2      = 0.0;
    support_3      = 0.0;
    valid           = false;
  }
};

struct PivotHftEntrySafetySnapshot
{
  datetime evaluated_at;
  double   requested_sl_points;
  double   spread_points;
  double   stops_level_points;
  double   freeze_level_points;
  double   broker_floor_points;
  double   required_initial_sl_points;
  double   point_size;
  double   tick_size;
  string   reason;
  bool     valid;
  bool     blocked;

  PivotHftEntrySafetySnapshot()
    : evaluated_at(0),
      requested_sl_points(0.0),
      spread_points(0.0),
      stops_level_points(0.0),
      freeze_level_points(0.0),
      broker_floor_points(0.0),
      required_initial_sl_points(0.0),
      point_size(0.0),
      tick_size(0.0),
      reason(""),
      valid(false),
      blocked(false)
  {
  }
};

struct PivotHftCampaignState
{
  PivotHftCampaignStatuses status;
  SignalTypes              direction;
  PivotHftPivotLevels      pivot_level;
  double                   pivot_price;
  datetime                 micro_bar_time;
  datetime                 arm_time;
  double                   tracked_extreme;
  double                   trigger_price;
  int                      attempt_count;
  int                      retry_ordinal;
  ulong                    retry_source_ticket;
  string                   retry_source_id;
  string                   sequence_id;
  PivotHftExecutionSources model_source_execution_source;
  string                   model_source_execution_id;
  PivotHftModelValueProvenance entry_slippage_provenance;
  PivotHftModelValueProvenance close_slippage_provenance;
  PivotHftModelValueProvenance cost_per_lot_provenance;
  double                   modeled_entry_slippage_points;
  double                   modeled_close_slippage_points;
  double                   modeled_cost_per_lot;
  datetime                 terminal_time;
  string                   terminal_reason;
  string                   replacement_sequence_id;
  PivotHftPivotLevels      replacement_level;
  double                   replacement_price;
  bool                     execution_slot_block_logged;
  PivotHftEntrySafetySnapshot entry_safety;

  PivotHftCampaignState()
  {
    status           = PIVOT_HFT_CAMPAIGN_IDLE;
    direction        = NO_SIGNAL;
    pivot_level      = PIVOT_HFT_LEVEL_NONE;
    pivot_price      = 0.0;
    micro_bar_time   = 0;
    arm_time         = 0;
    tracked_extreme  = 0.0;
    trigger_price    = 0.0;
    attempt_count    = 0;
    retry_ordinal    = 0;
    retry_source_ticket = 0;
    retry_source_id  = "";
    sequence_id      = "";
    model_source_execution_source = PIVOT_HFT_EXECUTION_BROKER;
    model_source_execution_id = "";
    entry_slippage_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    close_slippage_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    cost_per_lot_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    modeled_entry_slippage_points = 0.0;
    modeled_close_slippage_points = 0.0;
    modeled_cost_per_lot = 0.0;
    terminal_time = 0;
    terminal_reason = "";
    replacement_sequence_id = "";
    replacement_level = PIVOT_HFT_LEVEL_NONE;
    replacement_price = 0.0;
    execution_slot_block_logged = false;
    entry_safety     = PivotHftEntrySafetySnapshot();
  }
};

struct PivotHftRiskGeometry
{
  datetime bands_source_bar;
  double   bands_upper;
  double   bands_lower;
  double   band_width_points;
  double   initial_sl_points;
  double   trailing_step_points;
  double   fixed_tp_points;
  bool     valid;

  PivotHftRiskGeometry()
    : bands_source_bar(0),
      bands_upper(0.0),
      bands_lower(0.0),
      band_width_points(0.0),
      initial_sl_points(0.0),
      trailing_step_points(0.0),
      fixed_tp_points(0.0),
      valid(false)
  {
  }
};

struct PivotHftPositionState
{
  PivotHftPositionStatuses status;
  PivotHftExecutionSources execution_source;
  PivotHftCloseTriggers    close_trigger;
  PivotHftNetClasses       net_class;
  PivotHftRetryStates      retry_state;
  SignalTypes              direction;
  PivotHftPivotLevels      pivot_level;
  ulong                    position_ticket;
  ulong                    position_identifier;
  ulong                    entry_deal_ticket;
  ulong                    exit_deal_ticket;
  ulong                    campaign_retry_source_ticket;
  ulong                    force_close_generation_at_entry;
  datetime                 campaign_micro_bar_time;
  datetime                 entry_micro_bar_time;
  datetime                 entry_time;
  datetime                 close_trigger_time;
  datetime                 close_time;
  datetime                 retry_state_time;
  datetime                 risk_bands_source_bar;
  double                   pivot_price;
  double                   entry_price;
  double                   entry_request_quote;
  double                   entry_slippage_points;
  double                   risk_bands_upper;
  double                   risk_bands_lower;
  double                   risk_band_width_points;
  double                   initial_sl_points;
  double                   trailing_step_points;
  double                   fixed_tp_points;
  double                   local_sl_price;
  double                   local_tp_price;
  double                   trailing_stop_price;
  double                   close_trigger_quote;
  double                   close_trigger_stop;
  double                   close_trigger_target;
  double                   close_price;
  double                   close_slippage_points;
  double                   net_result;
  double                   gross_result;
  double                   estimated_cost_result;
  double                   estimated_cost_per_lot;
  double                   entry_volume;
  int                      trailing_step_index;
  int                      close_trigger_step;
  int                      campaign_attempt_count;
  int                      campaign_retry_ordinal;
  int                      next_retry_ordinal;
  int                      next_retry_number;
  PivotHftExecutionSources next_retry_execution_source;
  string                   execution_id;
  string                   campaign_retry_source_id;
  string                   campaign_sequence_id;
  PivotHftExecutionSources model_source_execution_source;
  string                   model_source_execution_id;
  PivotHftModelValueProvenance entry_slippage_provenance;
  PivotHftModelValueProvenance close_slippage_provenance;
  PivotHftModelValueProvenance cost_per_lot_provenance;
  string                   position_comment;
  string                   retry_state_reason;
  PivotHftEntrySafetySnapshot entry_safety;
  double                   entry_safety_close_quote;
  double                   entry_safety_actual_spread_points;
  double                   entry_safety_available_buffer_points;
  string                   entry_safety_post_fill_reason;
  bool                     entry_safety_checked;
  bool                     entry_safety_failed;
  bool                     emergency_lifecycle;
  bool                     daily_start_registered;
  bool                     close_requested;
  bool                     close_send_confirmed;
  bool                     reattempt_pending;
  bool                     daily_outcome_registered;
  int                      close_attempt_count;
  datetime                 close_retry_after;
  datetime                 last_close_audit_time;

  PivotHftPositionState()
  {
    status                 = PIVOT_HFT_POSITION_ACTIVE;
    execution_source       = PIVOT_HFT_EXECUTION_BROKER;
    close_trigger          = PIVOT_HFT_CLOSE_TRIGGER_NONE;
    net_class              = PIVOT_HFT_NET_NONE;
    retry_state            = PIVOT_HFT_RETRY_NONE;
    direction              = NO_SIGNAL;
    pivot_level            = PIVOT_HFT_LEVEL_NONE;
    position_ticket        = 0;
    position_identifier    = 0;
    entry_deal_ticket      = 0;
    exit_deal_ticket       = 0;
    campaign_retry_source_ticket = 0;
    force_close_generation_at_entry = 0;
    campaign_micro_bar_time = 0;
    entry_micro_bar_time   = 0;
    entry_time             = 0;
    close_trigger_time     = 0;
    close_time             = 0;
    retry_state_time       = 0;
    risk_bands_source_bar  = 0;
    pivot_price             = 0.0;
    entry_price            = 0.0;
    entry_request_quote    = 0.0;
    entry_slippage_points  = 0.0;
    risk_bands_upper       = 0.0;
    risk_bands_lower       = 0.0;
    risk_band_width_points = 0.0;
    initial_sl_points      = 0.0;
    trailing_step_points   = 0.0;
    fixed_tp_points        = 0.0;
    local_sl_price         = 0.0;
    local_tp_price         = 0.0;
    trailing_stop_price    = 0.0;
    close_trigger_quote    = 0.0;
    close_trigger_stop     = 0.0;
    close_trigger_target   = 0.0;
    close_price            = 0.0;
    close_slippage_points  = 0.0;
    net_result             = 0.0;
    gross_result           = 0.0;
    estimated_cost_result  = 0.0;
    estimated_cost_per_lot = 0.0;
    entry_volume           = 0.0;
    trailing_step_index    = 0;
    close_trigger_step     = 0;
    campaign_attempt_count = 0;
    campaign_retry_ordinal = 0;
    next_retry_ordinal     = 0;
    next_retry_number      = 0;
    next_retry_execution_source = PIVOT_HFT_EXECUTION_BROKER;
    execution_id           = "";
    campaign_retry_source_id = "";
    campaign_sequence_id   = "";
    model_source_execution_source = PIVOT_HFT_EXECUTION_BROKER;
    model_source_execution_id = "";
    entry_slippage_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    close_slippage_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    cost_per_lot_provenance = PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
    position_comment       = "";
    retry_state_reason     = "";
    entry_safety           = PivotHftEntrySafetySnapshot();
    entry_safety_close_quote = 0.0;
    entry_safety_actual_spread_points = 0.0;
    entry_safety_available_buffer_points = 0.0;
    entry_safety_post_fill_reason = "";
    entry_safety_checked   = false;
    entry_safety_failed    = false;
    emergency_lifecycle    = false;
    daily_start_registered = false;
    close_requested        = false;
    close_send_confirmed   = false;
    reattempt_pending      = false;
    daily_outcome_registered = false;
    close_attempt_count    = 0;
    close_retry_after      = 0;
    last_close_audit_time  = 0;
  }
};

struct PivotHftEmergencyQuarantineState
{
  bool                     active;
  bool                     state_attached;
  bool                     daily_start_registered;
  bool                     daily_outcome_registered;
  PivotHftCloseTriggers    close_trigger;
  SignalTypes              direction;
  PivotHftPivotLevels      pivot_level;
  ulong                    position_ticket;
  ulong                    position_identifier;
  ulong                    entry_deal_ticket;
  ulong                    force_close_generation_at_entry;
  datetime                 campaign_micro_bar_time;
  datetime                 entry_time;
  datetime                 activated_at;
  datetime                 next_action_time;
  datetime                 last_audit_time;
  double                   pivot_price;
  double                   entry_price;
  double                   entry_volume;
  int                      campaign_attempt_count;
  int                      campaign_retry_ordinal;
  string                   campaign_sequence_id;
  string                   position_comment;
  string                   reason;

  PivotHftEmergencyQuarantineState()
  {
    active = false;
    state_attached = false;
    daily_start_registered = false;
    daily_outcome_registered = false;
    close_trigger = PIVOT_HFT_CLOSE_TRIGGER_REGISTRATION_FAILURE;
    direction = NO_SIGNAL;
    pivot_level = PIVOT_HFT_LEVEL_NONE;
    position_ticket = 0;
    position_identifier = 0;
    entry_deal_ticket = 0;
    force_close_generation_at_entry = 0;
    campaign_micro_bar_time = 0;
    entry_time = 0;
    activated_at = 0;
    next_action_time = 0;
    last_audit_time = 0;
    pivot_price = 0.0;
    entry_price = 0.0;
    entry_volume = 0.0;
    campaign_attempt_count = 0;
    campaign_retry_ordinal = 0;
    campaign_sequence_id = "";
    position_comment = "";
    reason = "";
  }
};

int PivotHftMarketRetryNumber(const int retry_ordinal)
{
  return (retry_ordinal > 1) ? retry_ordinal - 1 : 0;
}

PivotHftExecutionSources PivotHftExecutionSourceForRetry(
  const int retry_number)
{
  if(retry_number > 0 &&
     Pivot_HFT_Start_Real_Retry > 1 &&
     retry_number < Pivot_HFT_Start_Real_Retry)
    return PIVOT_HFT_EXECUTION_VIRTUAL;
  return PIVOT_HFT_EXECUTION_BROKER;
}

string PivotHftExecutionSourceLabel(
  const PivotHftExecutionSources source)
{
  return (source == PIVOT_HFT_EXECUTION_VIRTUAL) ? "VIRTUAL" : "BROKER";
}

string PivotHftModelValueProvenanceLabel(
  const PivotHftModelValueProvenance provenance,
  const double value)
{
  bool is_zero = (MathAbs(value) <= 0.000000000001);
  if(provenance == PIVOT_HFT_MODEL_VALUE_OBSERVED)
    return is_zero ? "OBSERVED_ZERO" : "OBSERVED_VALUE";
  if(provenance == PIVOT_HFT_MODEL_VALUE_FALLBACK)
    return is_zero ? "FALLBACK_ZERO" : "FALLBACK_VALUE";
  return "UNAVAILABLE";
}

string PivotHftRetryStateLabel(const PivotHftRetryStates retry_state)
{
  switch(retry_state)
  {
    case PIVOT_HFT_RETRY_PENDING:
      return "PENDING";
    case PIVOT_HFT_RETRY_DEFERRED:
      return "DEFERRED";
    case PIVOT_HFT_RETRY_REARMED:
      return "REARMED";
    case PIVOT_HFT_RETRY_DISABLED:
      return "DISABLED";
    case PIVOT_HFT_RETRY_INVALIDATED:
      return "INVALIDATED";
    case PIVOT_HFT_RETRY_NONE:
    default:
      return "NONE";
  }
}

void PivotHftResolveNextRetryDecision(
  const PivotHftPositionState &position_state,
  int &retry_ordinal,
  int &retry_number,
  PivotHftExecutionSources &execution_source)
{
  retry_ordinal = position_state.campaign_retry_ordinal + 1;
  if(retry_ordinal <= 1)
    retry_ordinal = 2;
  retry_number = PivotHftMarketRetryNumber(retry_ordinal);
  execution_source = PivotHftExecutionSourceForRetry(retry_number);
}

void PivotHftPrepareNextRetryDecision(
  PivotHftPositionState &position_state)
{
  PivotHftResolveNextRetryDecision(
    position_state,
    position_state.next_retry_ordinal,
    position_state.next_retry_number,
    position_state.next_retry_execution_source);
}

bool PivotHftSetRetryState(PivotHftPositionState &position_state,
                           const PivotHftRetryStates retry_state,
                           const string reason)
{
  if(position_state.retry_state == retry_state &&
     position_state.retry_state_reason == reason)
    return false;

  position_state.retry_state = retry_state;
  position_state.retry_state_reason = reason;
  position_state.retry_state_time = TimeCurrent();
  return true;
}

string PivotHftPositionExecutionId(const PivotHftPositionState &position_state)
{
  if(position_state.execution_id != "")
    return position_state.execution_id;
  if(position_state.position_ticket > 0)
    return StringFormat("%I64u", position_state.position_ticket);
  return "-";
}

string PivotHftPositionAuditIdentityFields(
  const PivotHftPositionState &position_state)
{
  return StringFormat("execution_source=%s|execution_id=%s|ticket=%I64u",
                      PivotHftExecutionSourceLabel(
                        position_state.execution_source),
                      PivotHftPositionExecutionId(position_state),
                      position_state.position_ticket);
}

string PivotHftRetryDecisionAuditFields(
  const PivotHftPositionState &position_state,
  const datetime current_micro_bar)
{
  return StringFormat("source_execution_source=%s|source_execution_id=%s|source_ticket=%I64u|parent_execution_id=%s|sequence=%s|dir=%s|level=%s|pivot_price=%.5f|current_retry_number=%d|current_retry_ordinal=%d|next_retry_number=%d|next_retry_ordinal=%d|next_execution_source=%s|retry_state=%s|reason=%s|origin_bar=%I64d|fill_bar=%I64d|current_bar=%I64d",
                      PivotHftExecutionSourceLabel(
                        position_state.execution_source),
                      PivotHftPositionExecutionId(position_state),
                      position_state.position_ticket,
                      position_state.campaign_retry_source_id,
                      position_state.campaign_sequence_id,
                      EnumToString(position_state.direction),
                      PivotHftLevelLabel(position_state.pivot_level),
                      position_state.pivot_price,
                      PivotHftMarketRetryNumber(
                        position_state.campaign_retry_ordinal),
                      position_state.campaign_retry_ordinal,
                      position_state.next_retry_number,
                      position_state.next_retry_ordinal,
                      PivotHftExecutionSourceLabel(
                        position_state.next_retry_execution_source),
                      PivotHftRetryStateLabel(position_state.retry_state),
                      position_state.retry_state_reason,
                      (long)position_state.campaign_micro_bar_time,
                      (long)position_state.entry_micro_bar_time,
                      (long)current_micro_bar);
}

string PivotHftModelProvenanceAuditFields(
  const PivotHftExecutionSources source,
  const string source_execution_id,
  const double entry_slippage_points,
  const PivotHftModelValueProvenance entry_provenance,
  const double close_slippage_points,
  const PivotHftModelValueProvenance close_provenance,
  const double cost_per_lot,
  const PivotHftModelValueProvenance cost_provenance)
{
  string source_id = source_execution_id;
  if(source_id == "")
    source_id = "-";
  return StringFormat("model_source_execution_source=%s|model_source_execution_id=%s|model_entry_slippage_pts=%.2f|entry_slippage_provenance=%s|model_close_slippage_pts=%.2f|close_slippage_provenance=%s|model_cost_per_lot=%.5f|cost_per_lot_provenance=%s",
                      PivotHftExecutionSourceLabel(source),
                      source_id,
                      entry_slippage_points,
                      PivotHftModelValueProvenanceLabel(entry_provenance,
                                                        entry_slippage_points),
                      close_slippage_points,
                      PivotHftModelValueProvenanceLabel(close_provenance,
                                                        close_slippage_points),
                      cost_per_lot,
                      PivotHftModelValueProvenanceLabel(cost_provenance,
                                                        cost_per_lot));
}

string PivotHftCampaignModelProvenanceAuditFields(
  const PivotHftCampaignState &campaign)
{
  return PivotHftModelProvenanceAuditFields(
    campaign.model_source_execution_source,
    campaign.model_source_execution_id,
    campaign.modeled_entry_slippage_points,
    campaign.entry_slippage_provenance,
    campaign.modeled_close_slippage_points,
    campaign.close_slippage_provenance,
    campaign.modeled_cost_per_lot,
    campaign.cost_per_lot_provenance);
}

string PivotHftPositionModelProvenanceAuditFields(
  const PivotHftPositionState &position_state)
{
  return PivotHftModelProvenanceAuditFields(
    position_state.model_source_execution_source,
    position_state.model_source_execution_id,
    position_state.entry_slippage_points,
    position_state.entry_slippage_provenance,
    position_state.close_slippage_points,
    position_state.close_slippage_provenance,
    position_state.estimated_cost_per_lot,
    position_state.cost_per_lot_provenance);
}

PivotHftPivotSnapshot  g_pivot_hft_pivots;
PivotHftCampaignState  g_pivot_hft_campaign;
PivotHftCampaignState  g_pivot_hft_expired_visual_campaign;
PivotHftPositionState  g_pivot_hft_positions[];
PivotHftEmergencyQuarantineState g_pivot_hft_emergency_quarantine;
datetime               g_pivot_hft_expired_visual_until = 0;
datetime               g_pivot_hft_last_micro_bar = 0;
datetime               g_pivot_hft_last_macro_bar = 0;
string                 g_pivot_hft_last_error = "";
datetime               g_pivot_hft_completed_levels_bar = 0;
bool                   g_pivot_hft_completed_levels[PIVOT_HFT_LEVEL_SLOT_TOTAL];

PivotHftLevelTestStatuses g_pivot_hft_level_test_status[PIVOT_HFT_LEVEL_SLOT_TOTAL];
datetime                  g_pivot_hft_level_test_first_touch_bar[PIVOT_HFT_LEVEL_SLOT_TOTAL];
datetime                  g_pivot_hft_level_test_activation_bar = 0;
datetime                  g_pivot_hft_level_test_source_bar = 0;
datetime                  g_pivot_hft_level_test_last_closed_bar = 0;
datetime                  g_pivot_hft_level_test_last_micro_bar = 0;
datetime                  g_pivot_hft_level_test_retry_after = 0;
bool                      g_pivot_hft_level_test_ready = false;
bool                      g_pivot_hft_level_test_failure_logged = false;
string                    g_pivot_hft_level_test_last_failure = "";
datetime                  g_pivot_hft_occupied_audit_bar = 0;
int                       g_pivot_hft_occupied_audit_count = 0;
ulong                     g_pivot_hft_occupied_audit_masks[
  PIVOT_HFT_OCCUPIED_AUDIT_SIGNATURE_CAPACITY];
SignalTypes               g_pivot_hft_occupied_audit_directions[
  PIVOT_HFT_OCCUPIED_AUDIT_SIGNATURE_CAPACITY];
PivotHftPivotLevels       g_pivot_hft_occupied_audit_selected_levels[
  PIVOT_HFT_OCCUPIED_AUDIT_SIGNATURE_CAPACITY];

void PivotHftResetOccupiedAuditState()
{
  g_pivot_hft_occupied_audit_bar = 0;
  g_pivot_hft_occupied_audit_count = 0;
}

bool PivotHftRegisterOccupiedAuditSignature(
  const datetime micro_bar_time,
  const SignalTypes direction,
  const ulong occupied_mask,
  const PivotHftPivotLevels selected_level)
{
  if(micro_bar_time <= 0 || occupied_mask == 0)
    return false;

  if(g_pivot_hft_occupied_audit_bar != micro_bar_time)
  {
    g_pivot_hft_occupied_audit_bar = micro_bar_time;
    g_pivot_hft_occupied_audit_count = 0;
  }

  for(int i = 0; i < g_pivot_hft_occupied_audit_count; i++)
  {
    if(g_pivot_hft_occupied_audit_masks[i] == occupied_mask &&
       g_pivot_hft_occupied_audit_directions[i] == direction &&
       g_pivot_hft_occupied_audit_selected_levels[i] == selected_level)
      return false;
  }

  if(g_pivot_hft_occupied_audit_count >=
     PIVOT_HFT_OCCUPIED_AUDIT_SIGNATURE_CAPACITY)
    return false;

  int signature_index = g_pivot_hft_occupied_audit_count;
  g_pivot_hft_occupied_audit_masks[signature_index] = occupied_mask;
  g_pivot_hft_occupied_audit_directions[signature_index] = direction;
  g_pivot_hft_occupied_audit_selected_levels[signature_index] = selected_level;
  g_pivot_hft_occupied_audit_count++;
  return true;
}

datetime PivotHftResolveMicroBarAt(const datetime event_time)
{
  if(event_time <= 0)
    return 0;

  int bar_shift = iBarShift(_Symbol,
                            Pivot_HFT_Micro_Timeframe,
                            event_time,
                            false);
  if(bar_shift < 0)
    return 0;
  return iTime(_Symbol, Pivot_HFT_Micro_Timeframe, bar_shift);
}

string PivotHftLevelTestStatusLabel(const PivotHftLevelTestStatuses status)
{
  switch(status)
  {
    case PIVOT_HFT_LEVEL_TOUCHED_OPEN:
      return "TOUCHED_OPEN";
    case PIVOT_HFT_LEVEL_BURNED:
      return "BURNED";
    case PIVOT_HFT_LEVEL_UNTESTED:
    default:
      return "UNTESTED";
  }
}

void PivotHftResetLevelTestState()
{
  for(int i = 0; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
  {
    g_pivot_hft_level_test_status[i] = PIVOT_HFT_LEVEL_UNTESTED;
    g_pivot_hft_level_test_first_touch_bar[i] = 0;
  }

  g_pivot_hft_level_test_activation_bar = 0;
  g_pivot_hft_level_test_source_bar = 0;
  g_pivot_hft_level_test_last_closed_bar = 0;
  g_pivot_hft_level_test_last_micro_bar = 0;
  g_pivot_hft_level_test_retry_after = 0;
  g_pivot_hft_level_test_ready = false;
  g_pivot_hft_level_test_failure_logged = false;
  g_pivot_hft_level_test_last_failure = "";
}

void PivotHftPrepareLevelTestContext(const datetime activation_bar,
                                     const datetime source_bar,
                                     const bool force_reset = false)
{
  if(!force_reset &&
     activation_bar > 0 &&
     source_bar > 0 &&
     activation_bar == g_pivot_hft_level_test_activation_bar &&
     source_bar == g_pivot_hft_level_test_source_bar)
    return;

  PivotHftResetLevelTestState();
  g_pivot_hft_level_test_activation_bar = activation_bar;
  g_pivot_hft_level_test_source_bar = source_bar;
}

bool PivotHftLevelTestContextMatches(const datetime activation_bar,
                                     const datetime source_bar)
{
  return (activation_bar > 0 &&
          source_bar > 0 &&
          activation_bar == g_pivot_hft_level_test_activation_bar &&
          source_bar == g_pivot_hft_level_test_source_bar);
}

bool PivotHftLevelTestStateReady()
{
  return g_pivot_hft_level_test_ready;
}

datetime PivotHftLevelTestLastClosedBar()
{
  return g_pivot_hft_level_test_last_closed_bar;
}

datetime PivotHftLevelTestLastMicroBar()
{
  return g_pivot_hft_level_test_last_micro_bar;
}

void PivotHftMarkLevelTestUnavailable(const string reason,
                                     const datetime retry_after)
{
  g_pivot_hft_level_test_ready = false;
  g_pivot_hft_level_test_retry_after = retry_after;

  if(g_pivot_hft_level_test_failure_logged &&
     g_pivot_hft_level_test_last_failure == reason)
    return;

  g_pivot_hft_level_test_failure_logged = true;
  g_pivot_hft_level_test_last_failure = reason;
  PivotHftAuditLog("LEVEL_SCAN_FAILED",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|retry_at=%I64d|reason=%s",
                                (long)g_pivot_hft_level_test_activation_bar,
                                (long)g_pivot_hft_level_test_source_bar,
                                (long)retry_after,
                                reason));
}

bool PivotHftLevelTestRetryAllowed(const datetime now_time)
{
  return (now_time >= g_pivot_hft_level_test_retry_after);
}

void PivotHftMarkLevelTestReady(const datetime last_closed_bar,
                                const datetime current_micro_bar)
{
  g_pivot_hft_level_test_ready = true;
  g_pivot_hft_level_test_retry_after = 0;
  g_pivot_hft_level_test_failure_logged = false;
  g_pivot_hft_level_test_last_failure = "";
  g_pivot_hft_level_test_last_closed_bar = last_closed_bar;
  g_pivot_hft_level_test_last_micro_bar = current_micro_bar;
}

bool PivotHftLevelIndexValid(const PivotHftPivotLevels level)
{
  int level_index = (int)level;
  return (level_index > (int)PIVOT_HFT_LEVEL_NONE &&
          level_index < PIVOT_HFT_LEVEL_SLOT_TOTAL);
}

PivotHftLevelTestStatuses PivotHftGetLevelTestStatus(
  const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return PIVOT_HFT_LEVEL_UNTESTED;
  return g_pivot_hft_level_test_status[(int)level];
}

bool PivotHftLevelIsBurned(const PivotHftPivotLevels level)
{
  return (PivotHftGetLevelTestStatus(level) == PIVOT_HFT_LEVEL_BURNED);
}

bool PivotHftLevelIsAvailable(const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return false;
  return !PivotHftLevelIsBurned(level);
}

datetime PivotHftLevelFirstTouchBar(const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return 0;
  return g_pivot_hft_level_test_first_touch_bar[(int)level];
}

ulong PivotHftLevelTestMask()
{
  ulong mask = 0;
  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    if(g_pivot_hft_level_test_status[i] == PIVOT_HFT_LEVEL_BURNED)
      mask |= ((ulong)1 << i);
  return mask;
}

ulong PivotHftLevelOpenTouchMask()
{
  ulong mask = 0;
  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    if(g_pivot_hft_level_test_status[i] == PIVOT_HFT_LEVEL_TOUCHED_OPEN)
      mask |= ((ulong)1 << i);
  return mask;
}

void PivotHftCommitOpenMicroBar(const datetime closed_micro_bar)
{
  if(closed_micro_bar <= 0)
    return;

  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
  {
    if(g_pivot_hft_level_test_status[i] != PIVOT_HFT_LEVEL_TOUCHED_OPEN ||
       g_pivot_hft_level_test_first_touch_bar[i] != closed_micro_bar)
      continue;

    g_pivot_hft_level_test_status[i] = PIVOT_HFT_LEVEL_BURNED;
    PivotHftAuditLog("LEVEL_BURNED",
                     StringFormat("source=live|level=%s|bar=%I64d|status=%s",
                                  EnumToString((PivotHftPivotLevels)i),
                                  (long)closed_micro_bar,
                                  PivotHftLevelTestStatusLabel(
                                    g_pivot_hft_level_test_status[i])));
  }
}

void PivotHftFinalizeLevelTestContext(const datetime next_activation_bar)
{
  if(g_pivot_hft_level_test_activation_bar <= 0 ||
     g_pivot_hft_level_test_source_bar <= 0 ||
     next_activation_bar <= g_pivot_hft_level_test_activation_bar)
    return;

  datetime final_micro_bar = g_pivot_hft_level_test_last_micro_bar;
  ulong open_mask = PivotHftLevelOpenTouchMask();
  if(final_micro_bar > 0 && final_micro_bar < next_activation_bar)
    PivotHftCommitOpenMicroBar(final_micro_bar);

  PivotHftAuditLog("LEVEL_CONTEXT_FINALIZED",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|last_micro_bar=%I64d|next_activation_bar=%I64d|open_mask=%I64u|burned_mask=%I64u",
                                (long)g_pivot_hft_level_test_activation_bar,
                                (long)g_pivot_hft_level_test_source_bar,
                                (long)final_micro_bar,
                                (long)next_activation_bar,
                                open_mask,
                                PivotHftLevelTestMask()));
}

void PivotHftMarkHistoricalLevelTouched(
  const PivotHftPivotLevels level,
  const datetime micro_bar_time)
{
  if(!PivotHftLevelIndexValid(level) || micro_bar_time <= 0)
    return;

  int level_index = (int)level;
  if(g_pivot_hft_level_test_status[level_index] == PIVOT_HFT_LEVEL_BURNED)
    return;

  if(g_pivot_hft_level_test_first_touch_bar[level_index] <= 0)
    g_pivot_hft_level_test_first_touch_bar[level_index] = micro_bar_time;

  g_pivot_hft_level_test_status[level_index] = PIVOT_HFT_LEVEL_BURNED;
  PivotHftAuditLog("LEVEL_BURNED",
                   StringFormat("source=history|level=%s|bar=%I64d|status=%s",
                                EnumToString(level),
                                (long)micro_bar_time,
                                PivotHftLevelTestStatusLabel(
                                  g_pivot_hft_level_test_status[level_index])));
}

void PivotHftMarkLevelTouchedInOpenMicroBar(
  const PivotHftPivotLevels level,
  const datetime micro_bar_time)
{
  if(!PivotHftLevelIndexValid(level) || micro_bar_time <= 0)
    return;

  int level_index = (int)level;
  if(g_pivot_hft_level_test_status[level_index] == PIVOT_HFT_LEVEL_BURNED)
    return;

  if(g_pivot_hft_level_test_status[level_index] ==
       PIVOT_HFT_LEVEL_TOUCHED_OPEN &&
     g_pivot_hft_level_test_first_touch_bar[level_index] != micro_bar_time)
  {
    PivotHftCommitOpenMicroBar(
      g_pivot_hft_level_test_first_touch_bar[level_index]);
  }

  if(g_pivot_hft_level_test_status[level_index] ==
       PIVOT_HFT_LEVEL_UNTESTED)
  {
    g_pivot_hft_level_test_status[level_index] =
      PIVOT_HFT_LEVEL_TOUCHED_OPEN;
    g_pivot_hft_level_test_first_touch_bar[level_index] = micro_bar_time;
    PivotHftAuditLog("LEVEL_TOUCH_PROVISIONAL",
                     StringFormat("source=live|level=%s|bar=%I64d|status=%s",
                                  EnumToString(level),
                                  (long)micro_bar_time,
                                  PivotHftLevelTestStatusLabel(
                                    g_pivot_hft_level_test_status[level_index])));
  }
}

void PivotHftResetCampaign()
{
  g_pivot_hft_campaign = PivotHftCampaignState();
}

void PivotHftClearExpiredCampaignVisual()
{
  g_pivot_hft_expired_visual_campaign = PivotHftCampaignState();
  g_pivot_hft_expired_visual_until = 0;
}

void PivotHftCaptureExpiredCampaignVisual(const datetime current_micro_bar,
                                          const string reason = "")
{
  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_IDLE ||
     current_micro_bar <= 0)
    return;

  g_pivot_hft_expired_visual_campaign = g_pivot_hft_campaign;
  g_pivot_hft_expired_visual_campaign.status = PIVOT_HFT_CAMPAIGN_EXPIRED;
  g_pivot_hft_expired_visual_campaign.terminal_time = TimeCurrent();
  g_pivot_hft_expired_visual_campaign.terminal_reason = reason;
  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
    micro_seconds = 60;
  g_pivot_hft_expired_visual_until = current_micro_bar + micro_seconds;
}

void PivotHftCaptureReplacedCampaignVisual(
  const PivotHftCampaignState &previous_campaign,
  const PivotHftCampaignState &replacement_campaign,
  const datetime current_micro_bar)
{
  if(previous_campaign.status == PIVOT_HFT_CAMPAIGN_IDLE ||
     current_micro_bar <= 0)
    return;

  g_pivot_hft_expired_visual_campaign = previous_campaign;
  g_pivot_hft_expired_visual_campaign.status = PIVOT_HFT_CAMPAIGN_EXPIRED;
  g_pivot_hft_expired_visual_campaign.terminal_time = TimeCurrent();
  g_pivot_hft_expired_visual_campaign.terminal_reason =
    "latest_level_replaced";
  g_pivot_hft_expired_visual_campaign.replacement_sequence_id =
    replacement_campaign.sequence_id;
  g_pivot_hft_expired_visual_campaign.replacement_level =
    replacement_campaign.pivot_level;
  g_pivot_hft_expired_visual_campaign.replacement_price =
    replacement_campaign.pivot_price;

  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
    micro_seconds = 60;
  g_pivot_hft_expired_visual_until = current_micro_bar + micro_seconds;
}

void PivotHftCaptureTerminalRetryVisual(
  const PivotHftPositionState &position_state,
  const datetime current_micro_bar)
{
  if(current_micro_bar <= 0 || position_state.retry_state_reason == "")
    return;

  PivotHftCampaignState snapshot;
  snapshot.status = PIVOT_HFT_CAMPAIGN_EXPIRED;
  snapshot.direction = position_state.direction;
  snapshot.pivot_level = position_state.pivot_level;
  snapshot.pivot_price = position_state.pivot_price;
  snapshot.micro_bar_time = position_state.campaign_micro_bar_time;
  snapshot.arm_time = position_state.retry_state_time;
  snapshot.attempt_count = position_state.campaign_attempt_count + 1;
  snapshot.retry_ordinal = position_state.next_retry_ordinal;
  snapshot.retry_source_ticket = position_state.position_ticket;
  snapshot.retry_source_id = PivotHftPositionExecutionId(position_state);
  snapshot.sequence_id = position_state.campaign_sequence_id;
  snapshot.model_source_execution_source =
    position_state.model_source_execution_source;
  snapshot.model_source_execution_id =
    position_state.model_source_execution_id;
  snapshot.entry_slippage_provenance =
    position_state.entry_slippage_provenance;
  snapshot.close_slippage_provenance =
    position_state.close_slippage_provenance;
  snapshot.cost_per_lot_provenance =
    position_state.cost_per_lot_provenance;
  snapshot.modeled_entry_slippage_points =
    position_state.entry_slippage_points;
  snapshot.modeled_close_slippage_points =
    position_state.close_slippage_points;
  snapshot.modeled_cost_per_lot = position_state.estimated_cost_per_lot;
  snapshot.terminal_time = position_state.retry_state_time;
  snapshot.terminal_reason = position_state.retry_state_reason;
  snapshot.entry_safety = position_state.entry_safety;
  g_pivot_hft_expired_visual_campaign = snapshot;

  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
    micro_seconds = 60;
  g_pivot_hft_expired_visual_until = current_micro_bar + micro_seconds;
}

void PivotHftCancelPendingCampaign(const string reason,
                                   const datetime current_micro_bar)
{
  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_IDLE)
    return;

  datetime visual_bar = current_micro_bar;
  if(visual_bar <= 0)
    visual_bar = iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0);
  PivotHftAuditLog("CAMPAIGN_CANCELLED",
                   StringFormat("sequence=%s|dir=%s|level=%s|origin_bar=%I64d|current_bar=%I64d|status=%s|reason=%s",
                                g_pivot_hft_campaign.sequence_id,
                                EnumToString(g_pivot_hft_campaign.direction),
                                EnumToString(g_pivot_hft_campaign.pivot_level),
                                (long)g_pivot_hft_campaign.micro_bar_time,
                                (long)visual_bar,
                                EnumToString(g_pivot_hft_campaign.status),
                                 reason));
  if(visual_bar > 0)
    PivotHftCaptureExpiredCampaignVisual(visual_bar, reason);
  PivotHftResetCampaign();
}

bool PivotHftGetExpiredCampaignVisual(PivotHftCampaignState &snapshot)
{
  snapshot = PivotHftCampaignState();
  if(g_pivot_hft_expired_visual_until <= TimeCurrent() ||
     g_pivot_hft_expired_visual_campaign.status !=
       PIVOT_HFT_CAMPAIGN_EXPIRED)
    return false;

  snapshot = g_pivot_hft_expired_visual_campaign;
  return true;
}

void PivotHftClearPositionStates()
{
  ArrayResize(g_pivot_hft_positions, 0, 0);
}

bool PivotHftHasPositionStates()
{
  return (ArraySize(g_pivot_hft_positions) > 0 ||
          g_pivot_hft_emergency_quarantine.active);
}

bool PivotHftHasLivePositionStates()
{
  if(g_pivot_hft_emergency_quarantine.active)
    return true;

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionStatuses status = g_pivot_hft_positions[i].status;
    if(status == PIVOT_HFT_POSITION_ACTIVE ||
       status == PIVOT_HFT_POSITION_CLOSE_WAIT)
      return true;
  }
  return false;
}

bool PivotHftPositionStatusBlocksAdmission(
  const PivotHftPositionStatuses status)
{
  return (status != PIVOT_HFT_POSITION_COMPLETED);
}

bool PivotHftHasBlockingPositionLifecycle()
{
  if(g_pivot_hft_emergency_quarantine.active)
    return true;

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
    if(PivotHftPositionStatusBlocksAdmission(g_pivot_hft_positions[i].status))
      return true;
  return false;
}

bool PivotHftHasOtherBlockingPositionLifecycle(
  const string execution_id,
  const ulong position_ticket)
{
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    if(execution_id != "" &&
       PivotHftPositionExecutionId(state) == execution_id)
      continue;
    if(execution_id == "" &&
       position_ticket > 0 &&
       state.position_ticket == position_ticket)
      continue;
    if(PivotHftPositionStatusBlocksAdmission(state.status))
      return true;
  }
  return false;
}

int PivotHftInvalidatePendingRetries(const string reason,
                                     const datetime current_micro_bar)
{
  int invalidated = 0;
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    if(!g_pivot_hft_positions[i].reattempt_pending)
      continue;

    PivotHftPositionState state = g_pivot_hft_positions[i];
    PivotHftPrepareNextRetryDecision(state);
    bool state_changed = PivotHftSetRetryState(
      state,
      PIVOT_HFT_RETRY_INVALIDATED,
      reason);
    if(state_changed)
    {
      PivotHftAuditLog("REARM_INVALIDATED",
                       PivotHftRetryDecisionAuditFields(
                         state,
                         current_micro_bar));
      PivotHftCaptureTerminalRetryVisual(state, current_micro_bar);
    }

    g_pivot_hft_positions[i].next_retry_ordinal =
      state.next_retry_ordinal;
    g_pivot_hft_positions[i].next_retry_number =
      state.next_retry_number;
    g_pivot_hft_positions[i].next_retry_execution_source =
      state.next_retry_execution_source;
    g_pivot_hft_positions[i].retry_state = state.retry_state;
    g_pivot_hft_positions[i].retry_state_reason = state.retry_state_reason;
    g_pivot_hft_positions[i].retry_state_time = state.retry_state_time;
    g_pivot_hft_positions[i].reattempt_pending = false;
    g_pivot_hft_positions[i].status = PIVOT_HFT_POSITION_COMPLETED;
    invalidated++;
  }
  return invalidated;
}

bool PivotHftHasManagedBrokerPosition()
{
  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    return true;
  }
  return false;
}

void PivotHftEnsureCompletedLevelBar(const datetime micro_bar_time)
{
  if(micro_bar_time <= 0 ||
     g_pivot_hft_completed_levels_bar == micro_bar_time)
    return;

  for(int i = 0; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    g_pivot_hft_completed_levels[i] = false;
  g_pivot_hft_completed_levels_bar = micro_bar_time;
}

void PivotHftMarkCampaignLevelCompleted(const datetime micro_bar_time,
                                        const PivotHftPivotLevels level)
{
  if(iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0) != micro_bar_time)
    return;

  int level_index = (int)level;
  if(level_index <= (int)PIVOT_HFT_LEVEL_NONE ||
     level_index >= PIVOT_HFT_LEVEL_SLOT_TOTAL)
    return;

  PivotHftEnsureCompletedLevelBar(micro_bar_time);
  g_pivot_hft_completed_levels[level_index] = true;
}

ulong PivotHftMarkWinningLevelLadderCompleted(
  const datetime micro_bar_time,
  const SignalTypes direction,
  const PivotHftPivotLevels winning_level)
{
  if(iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0) != micro_bar_time)
    return 0;

  int first_level = 0;
  int last_level = (int)winning_level;
  if(direction == BEARISH &&
     winning_level >= PIVOT_HFT_LEVEL_R1 &&
     winning_level <= PIVOT_HFT_LEVEL_R3)
    first_level = (int)PIVOT_HFT_LEVEL_R1;
  else if(direction == BULLISH &&
          winning_level >= PIVOT_HFT_LEVEL_S1 &&
          winning_level <= PIVOT_HFT_LEVEL_S3)
    first_level = (int)PIVOT_HFT_LEVEL_S1;
  else
    return 0;

  PivotHftEnsureCompletedLevelBar(micro_bar_time);
  ulong consumed_mask = 0;
  for(int level_index = first_level;
      level_index <= last_level;
      level_index++)
  {
    g_pivot_hft_completed_levels[level_index] = true;
    consumed_mask |= ((ulong)1 << level_index);
  }
  return consumed_mask;
}

ulong PivotHftCampaignOccupiedLevelMask(const datetime micro_bar_time)
{
  if(micro_bar_time <= 0)
    return 0;

  PivotHftEnsureCompletedLevelBar(micro_bar_time);
  ulong occupied_mask = 0;
  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    if(g_pivot_hft_completed_levels[i])
      occupied_mask |= ((ulong)1 << i);

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    if(state.status == PIVOT_HFT_POSITION_COMPLETED)
      continue;
    if(state.campaign_micro_bar_time != micro_bar_time ||
       !PivotHftLevelIndexValid(state.pivot_level))
      continue;
    occupied_mask |= ((ulong)1 << (int)state.pivot_level);
  }
  return occupied_mask;
}

int PivotHftFindPositionStateIndex(const string execution_id,
                                   const ulong position_ticket)
{
  if(execution_id == "" && position_ticket == 0)
    return -1;

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    if(execution_id != "" &&
       PivotHftPositionExecutionId(g_pivot_hft_positions[i]) == execution_id)
      return i;
    if(execution_id == "" &&
       position_ticket > 0 &&
       g_pivot_hft_positions[i].position_ticket == position_ticket)
      return i;
  }
  return -1;
}

int PivotHftFindEmergencyPositionStateIndex()
{
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    if(!g_pivot_hft_positions[i].emergency_lifecycle)
      continue;
    if(g_pivot_hft_emergency_quarantine.position_identifier > 0 &&
       g_pivot_hft_positions[i].position_identifier !=
         g_pivot_hft_emergency_quarantine.position_identifier)
      continue;
    if(g_pivot_hft_emergency_quarantine.position_identifier == 0 &&
       g_pivot_hft_emergency_quarantine.position_ticket > 0 &&
       g_pivot_hft_positions[i].position_ticket !=
         g_pivot_hft_emergency_quarantine.position_ticket)
      continue;
    return i;
  }
  return -1;
}

void PivotHftActivateEmergencyQuarantine(
  const PivotHftCampaignState &campaign,
  const ulong position_ticket,
  const ulong position_identifier,
  const ulong deal_ticket,
  const datetime entry_time,
  const double entry_price,
  const double entry_volume,
  const string position_comment,
  const bool daily_start_registered,
  const PivotHftCloseTriggers close_trigger,
  const string reason)
{
  g_pivot_hft_emergency_quarantine =
    PivotHftEmergencyQuarantineState();
  g_pivot_hft_emergency_quarantine.active = true;
  g_pivot_hft_emergency_quarantine.daily_start_registered =
    daily_start_registered;
  g_pivot_hft_emergency_quarantine.close_trigger = close_trigger;
  g_pivot_hft_emergency_quarantine.direction = campaign.direction;
  g_pivot_hft_emergency_quarantine.pivot_level = campaign.pivot_level;
  g_pivot_hft_emergency_quarantine.position_ticket = position_ticket;
  g_pivot_hft_emergency_quarantine.position_identifier =
    position_identifier;
  g_pivot_hft_emergency_quarantine.entry_deal_ticket = deal_ticket;
  g_pivot_hft_emergency_quarantine.force_close_generation_at_entry =
    MarketStatusForceCloseGeneration();
  g_pivot_hft_emergency_quarantine.campaign_micro_bar_time =
    campaign.micro_bar_time;
  g_pivot_hft_emergency_quarantine.entry_time = entry_time;
  g_pivot_hft_emergency_quarantine.activated_at = TimeCurrent();
  g_pivot_hft_emergency_quarantine.pivot_price = campaign.pivot_price;
  g_pivot_hft_emergency_quarantine.entry_price = entry_price;
  g_pivot_hft_emergency_quarantine.entry_volume = entry_volume;
  g_pivot_hft_emergency_quarantine.campaign_attempt_count =
    campaign.attempt_count;
  g_pivot_hft_emergency_quarantine.campaign_retry_ordinal =
    campaign.retry_ordinal;
  g_pivot_hft_emergency_quarantine.campaign_sequence_id =
    campaign.sequence_id;
  g_pivot_hft_emergency_quarantine.position_comment = position_comment;
  g_pivot_hft_emergency_quarantine.reason = reason;
}

void PivotHftUpdateEmergencyQuarantineIdentity(
  const ulong position_ticket,
  const ulong position_identifier)
{
  if(!g_pivot_hft_emergency_quarantine.active)
    return;
  if(position_ticket > 0)
    g_pivot_hft_emergency_quarantine.position_ticket = position_ticket;
  if(position_identifier > 0)
    g_pivot_hft_emergency_quarantine.position_identifier =
      position_identifier;
}

void PivotHftMarkEmergencyQuarantineStateAttached()
{
  if(g_pivot_hft_emergency_quarantine.active)
    g_pivot_hft_emergency_quarantine.state_attached = true;
}

void PivotHftResetEmergencyQuarantine()
{
  g_pivot_hft_emergency_quarantine =
    PivotHftEmergencyQuarantineState();
}

bool PivotHftEmergencyQuarantineHasOpenExposure()
{
  if(!g_pivot_hft_emergency_quarantine.active)
    return false;

  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    ulong position_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    if(g_pivot_hft_emergency_quarantine.position_identifier > 0 &&
       position_identifier !=
         g_pivot_hft_emergency_quarantine.position_identifier)
      continue;
    if(g_pivot_hft_emergency_quarantine.position_identifier == 0 &&
       g_pivot_hft_emergency_quarantine.position_ticket > 0 &&
       position_ticket !=
         g_pivot_hft_emergency_quarantine.position_ticket)
      continue;
    g_pivot_hft_emergency_quarantine.position_ticket = position_ticket;
    if(position_identifier > 0)
      g_pivot_hft_emergency_quarantine.position_identifier =
        position_identifier;
    return true;
  }
  return false;
}

bool PivotHftAppendPositionState(const PivotHftPositionState &position_state)
{
  string execution_id = PivotHftPositionExecutionId(position_state);
  if(position_state.execution_source == PIVOT_HFT_EXECUTION_BROKER &&
     position_state.position_ticket == 0)
    return false;
  if(position_state.execution_source == PIVOT_HFT_EXECUTION_VIRTUAL &&
     (execution_id == "" || execution_id == "-"))
    return false;
  if(PivotHftFindPositionStateIndex(execution_id,
                                    position_state.position_ticket) >= 0)
    return false;

  int current_size = ArraySize(g_pivot_hft_positions);
  if(ArrayResize(g_pivot_hft_positions, current_size + 1, 16) != current_size + 1)
    return false;

  g_pivot_hft_positions[current_size] = position_state;
  return true;
}

void PivotHftCompactCompletedPositionStates()
{
  int total = ArraySize(g_pivot_hft_positions);
  int write_index = 0;
  for(int read_index = 0; read_index < total; read_index++)
  {
    if(g_pivot_hft_positions[read_index].status == PIVOT_HFT_POSITION_COMPLETED)
      continue;

    if(write_index != read_index)
      g_pivot_hft_positions[write_index] = g_pivot_hft_positions[read_index];
    write_index++;
  }

  if(write_index < total)
    ArrayResize(g_pivot_hft_positions, write_index);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_
