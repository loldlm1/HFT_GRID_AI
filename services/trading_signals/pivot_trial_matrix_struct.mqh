//+------------------------------------------------------------------+
//|                    trading_signals/pivot_trial_matrix_struct    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STRUCT_MQH_

struct PivotTrialIdentity
{
  string origin_id;
  string window_id;
  string broker_signal_id;
  string policy_id;
  string trial_id;
  string parity_trial_id;
  PivotTrialRoles role;
  PivotTrialSlPolicies sl_policy;
  int tp_r_multiple;
  int reentry_index;

  PivotTrialIdentity()
  {
    Reset();
  }

  PivotTrialIdentity(const PivotTrialIdentity &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin_id = "";
    window_id = "";
    broker_signal_id = "";
    policy_id = "";
    trial_id = "";
    parity_trial_id = "";
    role = PIVOT_TRIAL_ROLE_MATRIX;
    sl_policy = PIVOT_TRIAL_SL_STRUCTURAL;
    tp_r_multiple = 0;
    reentry_index = 0;
  }

  void CopyFrom(const PivotTrialIdentity &other)
  {
    origin_id = other.origin_id;
    window_id = other.window_id;
    broker_signal_id = other.broker_signal_id;
    policy_id = other.policy_id;
    trial_id = other.trial_id;
    parity_trial_id = other.parity_trial_id;
    role = other.role;
    sl_policy = other.sl_policy;
    tp_r_multiple = other.tp_r_multiple;
    reentry_index = other.reentry_index;
  }
};

struct PivotTrialOriginSnapshot
{
  string origin_id;
  string window_id;
  string broker_signal_id;
  string symbol;
  ENUM_TIMEFRAMES macro_timeframe;
  ENUM_TIMEFRAMES micro_timeframe;
  datetime active_bar_open;
  datetime trigger_time;
  datetime origin_expiry_time;
  PivotLevelIds level_id;
  SignalTypes direction;
  double trigger_bid;
  double trigger_ask;
  double spread_points;
  double point_size;
  double trade_tick_size;
  double stops_level_points;
  double freeze_level_points;
  double pivot_raw_price;
  double pivot_trade_price;
  bool boundary_available;
  double next_outward_pivot_price;
  double structural_entry_price;
  double structural_stop_loss;
  double structural_take_profit;
  bool origin_micro_band_width_available;
  double origin_micro_band_width_0;
  PivotPriceLadder levels;
  PivotContextFeatureSnapshot features;

  PivotTrialOriginSnapshot()
  {
    Reset();
  }

  PivotTrialOriginSnapshot(const PivotTrialOriginSnapshot &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin_id = "";
    window_id = "";
    broker_signal_id = "";
    symbol = "";
    macro_timeframe = PERIOD_CURRENT;
    micro_timeframe = PERIOD_CURRENT;
    active_bar_open = 0;
    trigger_time = 0;
    origin_expiry_time = 0;
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    trigger_bid = 0.0;
    trigger_ask = 0.0;
    spread_points = 0.0;
    point_size = 0.0;
    trade_tick_size = 0.0;
    stops_level_points = 0.0;
    freeze_level_points = 0.0;
    pivot_raw_price = 0.0;
    pivot_trade_price = 0.0;
    boundary_available = false;
    next_outward_pivot_price = 0.0;
    structural_entry_price = 0.0;
    structural_stop_loss = 0.0;
    structural_take_profit = 0.0;
    origin_micro_band_width_available = false;
    origin_micro_band_width_0 = 0.0;
    levels.Reset();
    features.Reset();
  }

  void CopyFrom(const PivotTrialOriginSnapshot &other)
  {
    origin_id = other.origin_id;
    window_id = other.window_id;
    broker_signal_id = other.broker_signal_id;
    symbol = other.symbol;
    macro_timeframe = other.macro_timeframe;
    micro_timeframe = other.micro_timeframe;
    active_bar_open = other.active_bar_open;
    trigger_time = other.trigger_time;
    origin_expiry_time = other.origin_expiry_time;
    level_id = other.level_id;
    direction = other.direction;
    trigger_bid = other.trigger_bid;
    trigger_ask = other.trigger_ask;
    spread_points = other.spread_points;
    point_size = other.point_size;
    trade_tick_size = other.trade_tick_size;
    stops_level_points = other.stops_level_points;
    freeze_level_points = other.freeze_level_points;
    pivot_raw_price = other.pivot_raw_price;
    pivot_trade_price = other.pivot_trade_price;
    boundary_available = other.boundary_available;
    next_outward_pivot_price = other.next_outward_pivot_price;
    structural_entry_price = other.structural_entry_price;
    structural_stop_loss = other.structural_stop_loss;
    structural_take_profit = other.structural_take_profit;
    origin_micro_band_width_available =
      other.origin_micro_band_width_available;
    origin_micro_band_width_0 = other.origin_micro_band_width_0;
    levels.CopyFrom(other.levels);
    features.CopyFrom(other.features);
  }
};

struct PivotTrialGeometry
{
  SignalTypes direction;
  double entry_bid;
  double entry_ask;
  double entry_price;
  PivotTrialQuoteSides entry_quote_side;
  PivotTrialQuoteSides exit_quote_side;
  double requested_risk_distance_price;
  double requested_risk_distance_points;
  long normalized_risk_ticks;
  double normalized_risk_distance_price;
  double normalized_risk_distance_points;
  double stop_loss_price;
  double take_profit_price;
  string geometry_equivalence_id;
  double spread_points;
  double point_size;
  double trade_tick_size;
  double stops_level_points;
  double freeze_level_points;
  double minimum_risk_distance_points;
  bool distance_eligible;
  bool boundary_available;
  double boundary_price;
  bool boundary_eligible;
  bool valid;
  string invalid_reason;

  PivotTrialGeometry()
  {
    Reset();
  }

  PivotTrialGeometry(const PivotTrialGeometry &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    direction = NO_SIGNAL;
    entry_bid = 0.0;
    entry_ask = 0.0;
    entry_price = 0.0;
    entry_quote_side = PIVOT_TRIAL_QUOTE_SIDE_NONE;
    exit_quote_side = PIVOT_TRIAL_QUOTE_SIDE_NONE;
    requested_risk_distance_price = 0.0;
    requested_risk_distance_points = 0.0;
    normalized_risk_ticks = 0;
    normalized_risk_distance_price = 0.0;
    normalized_risk_distance_points = 0.0;
    stop_loss_price = 0.0;
    take_profit_price = 0.0;
    geometry_equivalence_id = "";
    spread_points = 0.0;
    point_size = 0.0;
    trade_tick_size = 0.0;
    stops_level_points = 0.0;
    freeze_level_points = 0.0;
    minimum_risk_distance_points = 0.0;
    distance_eligible = false;
    boundary_available = false;
    boundary_price = 0.0;
    boundary_eligible = false;
    valid = false;
    invalid_reason = "";
  }

  void CopyFrom(const PivotTrialGeometry &other)
  {
    direction = other.direction;
    entry_bid = other.entry_bid;
    entry_ask = other.entry_ask;
    entry_price = other.entry_price;
    entry_quote_side = other.entry_quote_side;
    exit_quote_side = other.exit_quote_side;
    requested_risk_distance_price = other.requested_risk_distance_price;
    requested_risk_distance_points = other.requested_risk_distance_points;
    normalized_risk_ticks = other.normalized_risk_ticks;
    normalized_risk_distance_price = other.normalized_risk_distance_price;
    normalized_risk_distance_points = other.normalized_risk_distance_points;
    stop_loss_price = other.stop_loss_price;
    take_profit_price = other.take_profit_price;
    geometry_equivalence_id = other.geometry_equivalence_id;
    spread_points = other.spread_points;
    point_size = other.point_size;
    trade_tick_size = other.trade_tick_size;
    stops_level_points = other.stops_level_points;
    freeze_level_points = other.freeze_level_points;
    minimum_risk_distance_points = other.minimum_risk_distance_points;
    distance_eligible = other.distance_eligible;
    boundary_available = other.boundary_available;
    boundary_price = other.boundary_price;
    boundary_eligible = other.boundary_eligible;
    valid = other.valid;
    invalid_reason = other.invalid_reason;
  }
};

struct PivotTrialMoneyPlan
{
  double risk_budget_amount;
  double requested_volume;
  double normalized_volume;
  double virtual_expected_stop_loss;
  double virtual_expected_take_profit;
  double virtual_expected_reward_risk_ratio;
  bool complete;
  string invalid_reason;

  PivotTrialMoneyPlan()
  {
    Reset();
  }

  PivotTrialMoneyPlan(const PivotTrialMoneyPlan &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    risk_budget_amount = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    virtual_expected_stop_loss = 0.0;
    virtual_expected_take_profit = 0.0;
    virtual_expected_reward_risk_ratio = 0.0;
    complete = false;
    invalid_reason = "";
  }

  void CopyFrom(const PivotTrialMoneyPlan &other)
  {
    risk_budget_amount = other.risk_budget_amount;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    virtual_expected_stop_loss = other.virtual_expected_stop_loss;
    virtual_expected_take_profit = other.virtual_expected_take_profit;
    virtual_expected_reward_risk_ratio =
      other.virtual_expected_reward_risk_ratio;
    complete = other.complete;
    invalid_reason = other.invalid_reason;
  }
};

struct PivotTrialEntry
{
  PivotTrialIdentity identity;
  PivotLevelIds level_id;
  SignalTypes direction;
  datetime declared_time;
  datetime origin_expiry_time;
  int preceding_loss_count;
  bool origin_micro_band_width_available;
  double origin_micro_band_width_0;
  PivotTrialGeometry geometry;
  PivotTrialMoneyPlan money_plan;
  PivotContextFeatureSnapshot entry_features;
  PivotTrialEligibilityStatuses eligibility_status;
  string ineligible_reason;
  string parent_trial_id;
  string continuation_source_outcome_id;
  bool origin_window_active_at_entry;

  PivotTrialEntry()
  {
    Reset();
  }

  PivotTrialEntry(const PivotTrialEntry &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    identity.Reset();
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    declared_time = 0;
    origin_expiry_time = 0;
    preceding_loss_count = 0;
    origin_micro_band_width_available = false;
    origin_micro_band_width_0 = 0.0;
    geometry.Reset();
    money_plan.Reset();
    entry_features.Reset();
    eligibility_status = PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
    ineligible_reason = "";
    parent_trial_id = "";
    continuation_source_outcome_id = "";
    origin_window_active_at_entry = false;
  }

  void CopyFrom(const PivotTrialEntry &other)
  {
    identity.CopyFrom(other.identity);
    level_id = other.level_id;
    direction = other.direction;
    declared_time = other.declared_time;
    origin_expiry_time = other.origin_expiry_time;
    preceding_loss_count = other.preceding_loss_count;
    origin_micro_band_width_available =
      other.origin_micro_band_width_available;
    origin_micro_band_width_0 = other.origin_micro_band_width_0;
    geometry.CopyFrom(other.geometry);
    money_plan.CopyFrom(other.money_plan);
    entry_features.CopyFrom(other.entry_features);
    eligibility_status = other.eligibility_status;
    ineligible_reason = other.ineligible_reason;
    parent_trial_id = other.parent_trial_id;
    continuation_source_outcome_id = other.continuation_source_outcome_id;
    origin_window_active_at_entry = other.origin_window_active_at_entry;
  }
};

struct PivotTrialOutcome
{
  string outcome_id;
  PivotTrialIdentity identity;
  datetime terminal_time;
  PivotTrialFirstTouchOutcomes first_touch;
  string terminal_reason;
  double threshold_price;
  double observed_exit_bid;
  double observed_exit_ask;
  double observed_exit_price;
  PivotTrialQuoteSides exit_quote_side;
  double gap_points;
  long duration_seconds;
  double virtual_nominal_r;
  bool virtual_quote_gross_available;
  double virtual_quote_gross_profit;
  double virtual_quote_gross_r;
  bool virtual_binary_eligible;
  int virtual_binary_target;
  string virtual_exclusion_reason;
  bool first_touch_consistent;
  bool chain_terminal;
  PivotTrialChainTerminalReasons chain_terminal_reason;
  bool continuation_allowed;
  string continuation_reason;
  int next_reentry_index;
  string next_trial_id;

  PivotTrialOutcome()
  {
    Reset();
  }

  PivotTrialOutcome(const PivotTrialOutcome &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    outcome_id = "";
    identity.Reset();
    terminal_time = 0;
    first_touch = PIVOT_TRIAL_FIRST_TOUCH_PENDING;
    terminal_reason = "";
    threshold_price = 0.0;
    observed_exit_bid = 0.0;
    observed_exit_ask = 0.0;
    observed_exit_price = 0.0;
    exit_quote_side = PIVOT_TRIAL_QUOTE_SIDE_NONE;
    gap_points = 0.0;
    duration_seconds = 0;
    virtual_nominal_r = 0.0;
    virtual_quote_gross_available = false;
    virtual_quote_gross_profit = 0.0;
    virtual_quote_gross_r = 0.0;
    virtual_binary_eligible = false;
    virtual_binary_target = -1;
    virtual_exclusion_reason = "";
    first_touch_consistent = false;
    chain_terminal = false;
    chain_terminal_reason = PIVOT_TRIAL_CHAIN_NOT_TERMINAL;
    continuation_allowed = false;
    continuation_reason = "";
    next_reentry_index = -1;
    next_trial_id = "";
  }

  void CopyFrom(const PivotTrialOutcome &other)
  {
    outcome_id = other.outcome_id;
    identity.CopyFrom(other.identity);
    terminal_time = other.terminal_time;
    first_touch = other.first_touch;
    terminal_reason = other.terminal_reason;
    threshold_price = other.threshold_price;
    observed_exit_bid = other.observed_exit_bid;
    observed_exit_ask = other.observed_exit_ask;
    observed_exit_price = other.observed_exit_price;
    exit_quote_side = other.exit_quote_side;
    gap_points = other.gap_points;
    duration_seconds = other.duration_seconds;
    virtual_nominal_r = other.virtual_nominal_r;
    virtual_quote_gross_available = other.virtual_quote_gross_available;
    virtual_quote_gross_profit = other.virtual_quote_gross_profit;
    virtual_quote_gross_r = other.virtual_quote_gross_r;
    virtual_binary_eligible = other.virtual_binary_eligible;
    virtual_binary_target = other.virtual_binary_target;
    virtual_exclusion_reason = other.virtual_exclusion_reason;
    first_touch_consistent = other.first_touch_consistent;
    chain_terminal = other.chain_terminal;
    chain_terminal_reason = other.chain_terminal_reason;
    continuation_allowed = other.continuation_allowed;
    continuation_reason = other.continuation_reason;
    next_reentry_index = other.next_reentry_index;
    next_trial_id = other.next_trial_id;
  }
};

struct PivotTrialPolicyChainState
{
  string origin_id;
  string policy_id;
  string current_trial_id;
  string last_outcome_id;
  PivotTrialSlPolicies sl_policy;
  int tp_r_multiple;
  int current_reentry_index;
  int preceding_loss_count;
  datetime last_generation_time;
  double closed_nominal_r;
  double closed_virtual_gross_r;
  bool active;
  bool terminal;
  PivotTrialChainTerminalReasons terminal_reason;

  PivotTrialPolicyChainState()
  {
    Reset();
  }

  PivotTrialPolicyChainState(const PivotTrialPolicyChainState &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin_id = "";
    policy_id = "";
    current_trial_id = "";
    last_outcome_id = "";
    sl_policy = PIVOT_TRIAL_SL_STRUCTURAL;
    tp_r_multiple = 0;
    current_reentry_index = 0;
    preceding_loss_count = 0;
    last_generation_time = 0;
    closed_nominal_r = 0.0;
    closed_virtual_gross_r = 0.0;
    active = false;
    terminal = false;
    terminal_reason = PIVOT_TRIAL_CHAIN_NOT_TERMINAL;
  }

  void CopyFrom(const PivotTrialPolicyChainState &other)
  {
    origin_id = other.origin_id;
    policy_id = other.policy_id;
    current_trial_id = other.current_trial_id;
    last_outcome_id = other.last_outcome_id;
    sl_policy = other.sl_policy;
    tp_r_multiple = other.tp_r_multiple;
    current_reentry_index = other.current_reentry_index;
    preceding_loss_count = other.preceding_loss_count;
    last_generation_time = other.last_generation_time;
    closed_nominal_r = other.closed_nominal_r;
    closed_virtual_gross_r = other.closed_virtual_gross_r;
    active = other.active;
    terminal = other.terminal;
    terminal_reason = other.terminal_reason;
  }
};

struct PivotTrialParityLink
{
  string origin_id;
  string broker_signal_id;
  string parity_trial_id;
  bool accepted_request_copied;
  bool virtual_outcome_recorded;
  bool broker_outcome_linked;

  PivotTrialParityLink()
  {
    Reset();
  }

  PivotTrialParityLink(const PivotTrialParityLink &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin_id = "";
    broker_signal_id = "";
    parity_trial_id = "";
    accepted_request_copied = false;
    virtual_outcome_recorded = false;
    broker_outcome_linked = false;
  }

  void CopyFrom(const PivotTrialParityLink &other)
  {
    origin_id = other.origin_id;
    broker_signal_id = other.broker_signal_id;
    parity_trial_id = other.parity_trial_id;
    accepted_request_copied = other.accepted_request_copied;
    virtual_outcome_recorded = other.virtual_outcome_recorded;
    broker_outcome_linked = other.broker_outcome_linked;
  }
};

struct PivotTrialActiveState
{
  PivotTrialEntry trial;
  PivotTrialPolicyChainState chain;
  PivotTrialParityLink parity;
  bool active;

  PivotTrialActiveState()
  {
    Reset();
  }

  PivotTrialActiveState(const PivotTrialActiveState &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    trial.Reset();
    chain.Reset();
    parity.Reset();
    active = false;
  }

  void CopyFrom(const PivotTrialActiveState &other)
  {
    trial.CopyFrom(other.trial);
    chain.CopyFrom(other.chain);
    parity.CopyFrom(other.parity);
    active = other.active;
  }
};

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STRUCT_MQH_
