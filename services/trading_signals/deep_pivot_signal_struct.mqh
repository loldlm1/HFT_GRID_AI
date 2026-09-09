//+------------------------------------------------------------------+
//|              trading_signals/deep_pivot_signal_struct            |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_SIGNAL_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_SIGNAL_STRUCT_MQH_

struct DeepPivotEventIdentity
{
  string deep_event_id;
  string deep_window_id;
  string symbol;
  ENUM_TIMEFRAMES deep_timeframe;
  datetime active_deep_bar_open;
  PivotLevelIds level_id;

  DeepPivotEventIdentity()
  {
    Reset();
  }

  DeepPivotEventIdentity(const DeepPivotEventIdentity &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    deep_event_id = "";
    deep_window_id = "";
    symbol = "";
    deep_timeframe = PERIOD_CURRENT;
    active_deep_bar_open = 0;
    level_id = PIVOT_LEVEL_PP;
  }

  void CopyFrom(const DeepPivotEventIdentity &other)
  {
    deep_event_id = other.deep_event_id;
    deep_window_id = other.deep_window_id;
    symbol = other.symbol;
    deep_timeframe = other.deep_timeframe;
    active_deep_bar_open = other.active_deep_bar_open;
    level_id = other.level_id;
  }
};

struct DeepPivotEvent
{
  DeepPivotEventIdentity identity;
  SignalTypes direction;
  datetime trigger_time;
  double trigger_bid;
  double trigger_ask;
  double spread_points;
  double point_size;
  double trade_tick_size;
  double stops_level_points;
  double freeze_level_points;
  double pivot_raw_price;
  double pivot_trade_price;
  double next_outward_pivot_price;
  PivotPriceLadder levels;
  PivotContextFeatureSnapshot features;
  bool deep_micro_features_complete;
  string deep_feature_invalid_reason;
  bool identity_consumed;
  DeepPivotAdmissionStatuses admission_status;
  int active_parent_count;
  int required_link_slots;
  int required_trial_slots;
  int required_outcome_slots;
  int reserved_link_slots;
  int reserved_trial_slots;
  int reserved_outcome_slots;
  string capacity_rejection_reason;
  bool terminal;

  DeepPivotEvent()
  {
    Reset();
  }

  DeepPivotEvent(const DeepPivotEvent &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    identity.Reset();
    direction = NO_SIGNAL;
    trigger_time = 0;
    trigger_bid = 0.0;
    trigger_ask = 0.0;
    spread_points = 0.0;
    point_size = 0.0;
    trade_tick_size = 0.0;
    stops_level_points = 0.0;
    freeze_level_points = 0.0;
    pivot_raw_price = 0.0;
    pivot_trade_price = 0.0;
    next_outward_pivot_price = 0.0;
    levels.Reset();
    features.Reset();
    deep_micro_features_complete = false;
    deep_feature_invalid_reason = "";
    identity_consumed = false;
    admission_status = DEEP_PIVOT_ADMISSION_ADMITTED;
    active_parent_count = 0;
    required_link_slots = 0;
    required_trial_slots = 0;
    required_outcome_slots = 0;
    reserved_link_slots = 0;
    reserved_trial_slots = 0;
    reserved_outcome_slots = 0;
    capacity_rejection_reason = "";
    terminal = false;
  }

  void CopyFrom(const DeepPivotEvent &other)
  {
    identity.CopyFrom(other.identity);
    direction = other.direction;
    trigger_time = other.trigger_time;
    trigger_bid = other.trigger_bid;
    trigger_ask = other.trigger_ask;
    spread_points = other.spread_points;
    point_size = other.point_size;
    trade_tick_size = other.trade_tick_size;
    stops_level_points = other.stops_level_points;
    freeze_level_points = other.freeze_level_points;
    pivot_raw_price = other.pivot_raw_price;
    pivot_trade_price = other.pivot_trade_price;
    next_outward_pivot_price = other.next_outward_pivot_price;
    levels.CopyFrom(other.levels);
    features.CopyFrom(other.features);
    deep_micro_features_complete = other.deep_micro_features_complete;
    deep_feature_invalid_reason = other.deep_feature_invalid_reason;
    identity_consumed = other.identity_consumed;
    admission_status = other.admission_status;
    active_parent_count = other.active_parent_count;
    required_link_slots = other.required_link_slots;
    required_trial_slots = other.required_trial_slots;
    required_outcome_slots = other.required_outcome_slots;
    reserved_link_slots = other.reserved_link_slots;
    reserved_trial_slots = other.reserved_trial_slots;
    reserved_outcome_slots = other.reserved_outcome_slots;
    capacity_rejection_reason = other.capacity_rejection_reason;
    terminal = other.terminal;
  }
};

struct DeepPivotParentCandidate
{
  DeepPivotParentKinds parent_kind;
  string origin_id;
  string parent_trial_id;
  string parent_broker_signal_id;
  PivotTrialEntryPolicies parent_entry_policy;
  int parent_tp_r_multiple;
  SignalTypes direction;
  datetime parent_entry_time;

  DeepPivotParentCandidate()
  {
    Reset();
  }

  DeepPivotParentCandidate(const DeepPivotParentCandidate &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    parent_kind = DEEP_PIVOT_PARENT_H1_VIRTUAL;
    origin_id = "";
    parent_trial_id = "";
    parent_broker_signal_id = "";
    parent_entry_policy = PIVOT_TRIAL_ENTRY_STRUCTURAL;
    parent_tp_r_multiple = 0;
    direction = NO_SIGNAL;
    parent_entry_time = 0;
  }

  void CopyFrom(const DeepPivotParentCandidate &other)
  {
    parent_kind = other.parent_kind;
    origin_id = other.origin_id;
    parent_trial_id = other.parent_trial_id;
    parent_broker_signal_id = other.parent_broker_signal_id;
    parent_entry_policy = other.parent_entry_policy;
    parent_tp_r_multiple = other.parent_tp_r_multiple;
    direction = other.direction;
    parent_entry_time = other.parent_entry_time;
  }
};

struct DeepPivotFrozenParent
{
  string deep_event_id;
  DeepPivotParentCandidate parent;

  DeepPivotFrozenParent()
  {
    Reset();
  }

  DeepPivotFrozenParent(const DeepPivotFrozenParent &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    deep_event_id = "";
    parent.Reset();
  }

  void CopyFrom(const DeepPivotFrozenParent &other)
  {
    deep_event_id = other.deep_event_id;
    parent.CopyFrom(other.parent);
  }
};

struct DeepPivotParentLink
{
  string parent_link_id;
  string deep_event_id;
  string origin_id;
  DeepPivotParentKinds parent_kind;
  string parent_trial_id;
  string parent_broker_signal_id;
  PivotTrialEntryPolicies parent_entry_policy;
  int parent_tp_r_multiple;
  SignalTypes direction;
  datetime parent_entry_time;
  datetime event_trigger_time;
  long parent_age_seconds;
  datetime parent_terminal_time;
  DeepPivotLinkStatuses link_status;
  bool active;

  DeepPivotParentLink()
  {
    Reset();
  }

  DeepPivotParentLink(const DeepPivotParentLink &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    parent_link_id = "";
    deep_event_id = "";
    origin_id = "";
    parent_kind = DEEP_PIVOT_PARENT_H1_VIRTUAL;
    parent_trial_id = "";
    parent_broker_signal_id = "";
    parent_entry_policy = PIVOT_TRIAL_ENTRY_STRUCTURAL;
    parent_tp_r_multiple = 0;
    direction = NO_SIGNAL;
    parent_entry_time = 0;
    event_trigger_time = 0;
    parent_age_seconds = 0;
    parent_terminal_time = 0;
    link_status = DEEP_PIVOT_LINK_ACTIVE;
    active = true;
  }

  void CopyFrom(const DeepPivotParentLink &other)
  {
    parent_link_id = other.parent_link_id;
    deep_event_id = other.deep_event_id;
    origin_id = other.origin_id;
    parent_kind = other.parent_kind;
    parent_trial_id = other.parent_trial_id;
    parent_broker_signal_id = other.parent_broker_signal_id;
    parent_entry_policy = other.parent_entry_policy;
    parent_tp_r_multiple = other.parent_tp_r_multiple;
    direction = other.direction;
    parent_entry_time = other.parent_entry_time;
    event_trigger_time = other.event_trigger_time;
    parent_age_seconds = other.parent_age_seconds;
    parent_terminal_time = other.parent_terminal_time;
    link_status = other.link_status;
    active = other.active;
  }
};

struct DeepPivotTrial
{
  string deep_trial_id;
  string deep_event_id;
  int tp_r_multiple;
  PivotLevelIds level_id;
  SignalTypes direction;
  datetime declared_time;
  PivotTrialGeometry geometry;
  PivotTrialMoneyPlan money_plan;
  PivotTrialEligibilityStatuses eligibility_status;
  string ineligible_reason;
  int remaining_parent_count;
  bool active;

  DeepPivotTrial()
  {
    Reset();
  }

  DeepPivotTrial(const DeepPivotTrial &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    deep_trial_id = "";
    deep_event_id = "";
    tp_r_multiple = 0;
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    declared_time = 0;
    geometry.Reset();
    money_plan.Reset();
    eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    ineligible_reason = "";
    remaining_parent_count = 0;
    active = true;
  }

  void CopyFrom(const DeepPivotTrial &other)
  {
    deep_trial_id = other.deep_trial_id;
    deep_event_id = other.deep_event_id;
    tp_r_multiple = other.tp_r_multiple;
    level_id = other.level_id;
    direction = other.direction;
    declared_time = other.declared_time;
    geometry.CopyFrom(other.geometry);
    money_plan.CopyFrom(other.money_plan);
    eligibility_status = other.eligibility_status;
    ineligible_reason = other.ineligible_reason;
    remaining_parent_count = other.remaining_parent_count;
    active = other.active;
  }
};

struct DeepPivotOutcome
{
  string deep_outcome_id;
  string parent_link_id;
  string deep_trial_id;
  string deep_event_id;
  string origin_id;
  int tp_r_multiple;
  SignalTypes direction;
  datetime terminal_time;
  PivotTrialFirstTouchOutcomes first_touch;
  string terminal_status;
  string terminal_reason;
  double threshold_price;
  double observed_exit_bid;
  double observed_exit_ask;
  double observed_exit_price;
  PivotTrialQuoteSides exit_quote_side;
  double gap_points;
  bool lifecycle_seconds_available;
  long lifecycle_seconds;
  double virtual_nominal_r;
  bool virtual_quote_gross_available;
  double virtual_quote_gross_profit;
  double virtual_quote_gross_r;
  bool virtual_binary_eligible;
  int virtual_binary_target;
  string virtual_exclusion_reason;
  bool first_touch_consistent;
  bool active;

  DeepPivotOutcome()
  {
    Reset();
  }

  DeepPivotOutcome(const DeepPivotOutcome &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    deep_outcome_id = "";
    parent_link_id = "";
    deep_trial_id = "";
    deep_event_id = "";
    origin_id = "";
    tp_r_multiple = 0;
    direction = NO_SIGNAL;
    terminal_time = 0;
    first_touch = PIVOT_TRIAL_FIRST_TOUCH_PENDING;
    terminal_status = "";
    terminal_reason = "";
    threshold_price = 0.0;
    observed_exit_bid = 0.0;
    observed_exit_ask = 0.0;
    observed_exit_price = 0.0;
    exit_quote_side = PIVOT_TRIAL_QUOTE_SIDE_NONE;
    gap_points = 0.0;
    lifecycle_seconds_available = false;
    lifecycle_seconds = 0;
    virtual_nominal_r = 0.0;
    virtual_quote_gross_available = false;
    virtual_quote_gross_profit = 0.0;
    virtual_quote_gross_r = 0.0;
    virtual_binary_eligible = false;
    virtual_binary_target = -1;
    virtual_exclusion_reason = "";
    first_touch_consistent = false;
    active = true;
  }

  void CopyFrom(const DeepPivotOutcome &other)
  {
    deep_outcome_id = other.deep_outcome_id;
    parent_link_id = other.parent_link_id;
    deep_trial_id = other.deep_trial_id;
    deep_event_id = other.deep_event_id;
    origin_id = other.origin_id;
    tp_r_multiple = other.tp_r_multiple;
    direction = other.direction;
    terminal_time = other.terminal_time;
    first_touch = other.first_touch;
    terminal_status = other.terminal_status;
    terminal_reason = other.terminal_reason;
    threshold_price = other.threshold_price;
    observed_exit_bid = other.observed_exit_bid;
    observed_exit_ask = other.observed_exit_ask;
    observed_exit_price = other.observed_exit_price;
    exit_quote_side = other.exit_quote_side;
    gap_points = other.gap_points;
    lifecycle_seconds_available = other.lifecycle_seconds_available;
    lifecycle_seconds = other.lifecycle_seconds;
    virtual_nominal_r = other.virtual_nominal_r;
    virtual_quote_gross_available = other.virtual_quote_gross_available;
    virtual_quote_gross_profit = other.virtual_quote_gross_profit;
    virtual_quote_gross_r = other.virtual_quote_gross_r;
    virtual_binary_eligible = other.virtual_binary_eligible;
    virtual_binary_target = other.virtual_binary_target;
    virtual_exclusion_reason = other.virtual_exclusion_reason;
    first_touch_consistent = other.first_touch_consistent;
    active = other.active;
  }
};

#endif // _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_SIGNAL_STRUCT_MQH_
