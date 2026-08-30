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

#endif // _SERVICES_TRADING_SIGNALS_DEEP_PIVOT_SIGNAL_STRUCT_MQH_
