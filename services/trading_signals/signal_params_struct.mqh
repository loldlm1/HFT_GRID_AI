//+------------------------------------------------------------------+
//|                                         signal_params_struct.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_

struct BrokerExecutionCheck
{
  string      phase;
  int         sequence;
  datetime    broker_time;
  string      symbol;
  SignalTypes direction;
  long        account_margin_mode;
  long        symbol_trade_mode;
  bool        account_margin_mode_supported;
  bool        symbol_trade_mode_allowed;
  bool        market_session_open;
  bool        account_trade_allowed;
  bool        account_expert_trade_allowed;
  bool        terminal_trade_allowed;
  bool        mql_trade_allowed;
  double      bid;
  double      ask;
  double      spread_points;
  double      point_size;
  double      stops_distance_points;
  double      freeze_distance_points;
  double      planned_entry_price;
  double      stop_loss_price;
  double      take_profit_price;
  double      risk_distance;
  double      requested_volume;
  double      normalized_volume;
  double      volume_min;
  double      volume_max;
  double      volume_step;
  bool        volume_valid;
  double      account_balance;
  double      free_margin;
  double      required_margin;
  bool        margin_valid;
  bool        geometry_valid;
  bool        stop_distance_valid;
  bool        freeze_distance_valid;
  bool        order_check_performed;
  bool        order_check_allowed;
  ulong       order_check_retcode;
  string      order_check_comment;
  bool        allowed;
  string      block_source;
  string      block_reason;
  ulong       send_retcode;
  string      send_comment;
  ulong       order_ticket;
  ulong       deal_ticket;

  BrokerExecutionCheck()
  {
    phase = "";
    sequence = 0;
    broker_time = 0;
    symbol = "";
    direction = NO_SIGNAL;
    account_margin_mode = 0;
    symbol_trade_mode = 0;
    account_margin_mode_supported = false;
    symbol_trade_mode_allowed = false;
    market_session_open = false;
    account_trade_allowed = false;
    account_expert_trade_allowed = false;
    terminal_trade_allowed = false;
    mql_trade_allowed = false;
    bid = 0.0;
    ask = 0.0;
    spread_points = 0.0;
    point_size = 0.0;
    stops_distance_points = 0.0;
    freeze_distance_points = 0.0;
    planned_entry_price = 0.0;
    stop_loss_price = 0.0;
    take_profit_price = 0.0;
    risk_distance = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    volume_min = 0.0;
    volume_max = 0.0;
    volume_step = 0.0;
    volume_valid = false;
    account_balance = 0.0;
    free_margin = 0.0;
    required_margin = 0.0;
    margin_valid = false;
    geometry_valid = false;
    stop_distance_valid = false;
    freeze_distance_valid = false;
    order_check_performed = false;
    order_check_allowed = false;
    order_check_retcode = 0;
    order_check_comment = "";
    allowed = false;
    block_source = "";
    block_reason = "";
    send_retcode = 0;
    send_comment = "";
    order_ticket = 0;
    deal_ticket = 0;
  }

  BrokerExecutionCheck(const BrokerExecutionCheck &other)
  {
    phase = other.phase;
    sequence = other.sequence;
    broker_time = other.broker_time;
    symbol = other.symbol;
    direction = other.direction;
    account_margin_mode = other.account_margin_mode;
    symbol_trade_mode = other.symbol_trade_mode;
    account_margin_mode_supported = other.account_margin_mode_supported;
    symbol_trade_mode_allowed = other.symbol_trade_mode_allowed;
    market_session_open = other.market_session_open;
    account_trade_allowed = other.account_trade_allowed;
    account_expert_trade_allowed = other.account_expert_trade_allowed;
    terminal_trade_allowed = other.terminal_trade_allowed;
    mql_trade_allowed = other.mql_trade_allowed;
    bid = other.bid;
    ask = other.ask;
    spread_points = other.spread_points;
    point_size = other.point_size;
    stops_distance_points = other.stops_distance_points;
    freeze_distance_points = other.freeze_distance_points;
    planned_entry_price = other.planned_entry_price;
    stop_loss_price = other.stop_loss_price;
    take_profit_price = other.take_profit_price;
    risk_distance = other.risk_distance;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    volume_min = other.volume_min;
    volume_max = other.volume_max;
    volume_step = other.volume_step;
    volume_valid = other.volume_valid;
    account_balance = other.account_balance;
    free_margin = other.free_margin;
    required_margin = other.required_margin;
    margin_valid = other.margin_valid;
    geometry_valid = other.geometry_valid;
    stop_distance_valid = other.stop_distance_valid;
    freeze_distance_valid = other.freeze_distance_valid;
    order_check_performed = other.order_check_performed;
    order_check_allowed = other.order_check_allowed;
    order_check_retcode = other.order_check_retcode;
    order_check_comment = other.order_check_comment;
    allowed = other.allowed;
    block_source = other.block_source;
    block_reason = other.block_reason;
    send_retcode = other.send_retcode;
    send_comment = other.send_comment;
    order_ticket = other.order_ticket;
    deal_ticket = other.deal_ticket;
  }
};

struct ExecutionState
{
  ExecutionOrderStates state;
  double planned_entry_price;
  double stop_loss_price;
  double take_profit_price;
  double risk_distance;
  double requested_volume;
  double normalized_volume;
  double broker_entry_price;
  double broker_volume;
  double broker_stop_loss;
  double broker_take_profit;
  double close_price;
  double closed_volume;
  double realized_profit;
  ulong order_ticket;
  ulong deal_ticket;
  ulong position_ticket;
  ulong position_identifier;
  ulong closed_position_ticket;
  string position_comment;
  datetime last_action_time;
  datetime broker_entry_time;
  datetime close_time;
  int last_check_sequence;
  bool send_attempted;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;
  bool broker_active_check_exported;
  bool broker_closed_check_exported;
  bool broker_terminal_check_exported;
  string terminal_reason;
  BrokerExecutionCheck observation_check;
  BrokerExecutionCheck filter_gate_check;
  BrokerExecutionCheck pre_send_check;
  BrokerExecutionCheck send_result_check;

  ExecutionState()
  {
    state = EXECUTION_ORDER_WAITING;
    planned_entry_price = 0.0;
    stop_loss_price = 0.0;
    take_profit_price = 0.0;
    risk_distance = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    broker_entry_price = 0.0;
    broker_volume = 0.0;
    broker_stop_loss = 0.0;
    broker_take_profit = 0.0;
    close_price = 0.0;
    closed_volume = 0.0;
    realized_profit = 0.0;
    order_ticket = 0;
    deal_ticket = 0;
    position_ticket = 0;
    position_identifier = 0;
    closed_position_ticket = 0;
    position_comment = "";
    last_action_time = 0;
    broker_entry_time = 0;
    close_time = 0;
    last_check_sequence = 0;
    send_attempted = false;
    broker_entry_confirmed = false;
    broker_close_confirmed = false;
    broker_active_check_exported = false;
    broker_closed_check_exported = false;
    broker_terminal_check_exported = false;
    terminal_reason = "";
  }

  ExecutionState(const ExecutionState &other)
  {
    state = other.state;
    planned_entry_price = other.planned_entry_price;
    stop_loss_price = other.stop_loss_price;
    take_profit_price = other.take_profit_price;
    risk_distance = other.risk_distance;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    broker_entry_price = other.broker_entry_price;
    broker_volume = other.broker_volume;
    broker_stop_loss = other.broker_stop_loss;
    broker_take_profit = other.broker_take_profit;
    close_price = other.close_price;
    closed_volume = other.closed_volume;
    realized_profit = other.realized_profit;
    order_ticket = other.order_ticket;
    deal_ticket = other.deal_ticket;
    position_ticket = other.position_ticket;
    position_identifier = other.position_identifier;
    closed_position_ticket = other.closed_position_ticket;
    position_comment = other.position_comment;
    last_action_time = other.last_action_time;
    broker_entry_time = other.broker_entry_time;
    close_time = other.close_time;
    last_check_sequence = other.last_check_sequence;
    send_attempted = other.send_attempted;
    broker_entry_confirmed = other.broker_entry_confirmed;
    broker_close_confirmed = other.broker_close_confirmed;
    broker_active_check_exported = other.broker_active_check_exported;
    broker_closed_check_exported = other.broker_closed_check_exported;
    broker_terminal_check_exported = other.broker_terminal_check_exported;
    terminal_reason = other.terminal_reason;
    observation_check = other.observation_check;
    filter_gate_check = other.filter_gate_check;
    pre_send_check = other.pre_send_check;
    send_result_check = other.send_result_check;
  }
};

struct ResolvedStructureEntryAnchor
{
  bool valid;
  double percent;
  double price;

  ResolvedStructureEntryAnchor()
  {
    valid = false;
    percent = 0.0;
    price = 0.0;
  }
};

struct SignalParams
{
  SignalTypes signal_type;
  SignalStates signal_state;
  int engine_id;
  string engine_label;
  ENUM_TIMEFRAMES engine_timeframe;
  bool deterministic_strategy;
  string execution_sequence_id;
  string deterministic_source_key;
  int deterministic_source_attempt_index;
  string extremum_cycle_id;
  string extremum_revision_id;
  string extremum_attempt_id;
  int extremum_revision_index;
  int cycle_attempt_index;
  int revision_attempt_index;
  double candidate_depth_percent;
  double reference_range_points;
  double distance_from_first_revision_points;
  double distance_from_previous_revision_points;
  double depth_delta_from_previous_percent;
  int bars_since_cycle_start;
  StrategyContextTypes strategy_context;
  ENUM_TIMEFRAMES strategy_timeframe;
  string strategy_context_label;
  StructureTriggerEntryModes entry_trigger_mode;
  double entry_price;
  ResolvedStructureEntryAnchor resolved_structure_entry;
  bool entry_is_limit;
  double close_price;
  double stop_loss;
  double take_profit;
  double lot_size;
  double raw_profit;
  datetime entry_time;
  datetime close_time;
  datetime source_extremum_time;
  int source_extremum_slot;
  bool source_extremum_confirmed;
  bool source_extremum_is_peak;
  double source_extremum_price;
  double source_extremum_high;
  double source_extremum_low;
  double raw_entry_trigger_price;
  double raw_stop_anchor_price;
  double raw_take_profit_price;
  double raw_risk_distance;
  double realized_profit;
  double realized_closed_volume;
  double remaining_open_volume;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;
  string broker_close_source;
  string deterministic_stats_signal_id;
  bool deterministic_stats_feature_exported;
  bool deterministic_stats_outcome_exported;
  string deterministic_stats_terminal_reason;
  string deterministic_stats_last_execution_check_key;
  ExecutionAdmissionStatuses admission_status;
  string admission_block_source;
  string admission_block_reason;
  datetime admission_updated_time;
  double admission_spread_points;
  MarketStatusTypes admission_market_status;
  string ml_shadow_signal_id;
  bool ml_shadow_evaluated;
  bool ml_shadow_available;
  bool ml_shadow_feature_valid;
  bool ml_shadow_classifier_scored;
  bool ml_shadow_regressor_scored;
  string ml_shadow_model_id;
  string ml_shadow_export_id;
  double ml_shadow_classifier_score;
  double ml_shadow_regressor_score;
  double ml_shadow_threshold;
  string ml_shadow_recommendation;
  string ml_shadow_reason;
  bool ml_shadow_outcome_exported;
  bool execution_initialized;
  bool execution_risk_plan_valid;
  string execution_risk_plan_reason;
  double execution_risk_target_amount;
  double execution_expected_sl_loss;
  double execution_expected_tp_profit;
  double execution_raw_lot_size;
  double execution_normalized_lot_size;
  datetime context_structure_snapshot_time;
  bool base_structure_valid;
  StochasticMarketStructure base_structure_data;
  bool trend_structure_valid;
  StochasticMarketStructure trend_structure_data;
  bool macro_structure_valid;
  StochasticMarketStructure macro_structure_data;
  bool session_structure_valid;
  StochasticMarketStructure session_structure_data;
  ExecutionState execution;

  SignalParams()
  {
    signal_type = NO_SIGNAL;
    signal_state = WAITING;
    engine_id = EXTREMUM_ENGINE_NONE;
    engine_label = "NONE";
    engine_timeframe = PERIOD_CURRENT;
    deterministic_strategy = false;
    execution_sequence_id = "";
    deterministic_source_key = "";
    deterministic_source_attempt_index = 0;
    extremum_cycle_id = "";
    extremum_revision_id = "";
    extremum_attempt_id = "";
    extremum_revision_index = 0;
    cycle_attempt_index = 0;
    revision_attempt_index = 0;
    candidate_depth_percent = 0.0;
    reference_range_points = 0.0;
    distance_from_first_revision_points = 0.0;
    distance_from_previous_revision_points = 0.0;
    depth_delta_from_previous_percent = 0.0;
    bars_since_cycle_start = 0;
    strategy_context = CONTEXT_SLOT_BASE;
    strategy_timeframe = PERIOD_CURRENT;
    strategy_context_label = "BASE";
    entry_trigger_mode = LEVELS_AS_LIMITS;
    entry_price = 0.0;
    entry_is_limit = false;
    close_price = 0.0;
    stop_loss = 0.0;
    take_profit = 0.0;
    lot_size = 0.0;
    raw_profit = 0.0;
    entry_time = 0;
    close_time = 0;
    source_extremum_time = 0;
    source_extremum_slot = -1;
    source_extremum_confirmed = false;
    source_extremum_is_peak = false;
    source_extremum_price = 0.0;
    source_extremum_high = 0.0;
    source_extremum_low = 0.0;
    raw_entry_trigger_price = 0.0;
    raw_stop_anchor_price = 0.0;
    raw_take_profit_price = 0.0;
    raw_risk_distance = 0.0;
    realized_profit = 0.0;
    realized_closed_volume = 0.0;
    remaining_open_volume = 0.0;
    broker_entry_confirmed = false;
    broker_close_confirmed = false;
    broker_close_source = "";
    deterministic_stats_signal_id = "";
    deterministic_stats_feature_exported = false;
    deterministic_stats_outcome_exported = false;
    deterministic_stats_terminal_reason = "";
    deterministic_stats_last_execution_check_key = "";
    admission_status = EXECUTION_ADMISSION_NOT_EVALUATED;
    admission_block_source = "";
    admission_block_reason = "";
    admission_updated_time = 0;
    admission_spread_points = 0.0;
    admission_market_status = MARKET_STATUS_ACTIVE;
    ml_shadow_signal_id = "";
    ml_shadow_evaluated = false;
    ml_shadow_available = false;
    ml_shadow_feature_valid = false;
    ml_shadow_classifier_scored = false;
    ml_shadow_regressor_scored = false;
    ml_shadow_model_id = "";
    ml_shadow_export_id = "";
    ml_shadow_classifier_score = 0.0;
    ml_shadow_regressor_score = 0.0;
    ml_shadow_threshold = 0.0;
    ml_shadow_recommendation = "";
    ml_shadow_reason = "";
    ml_shadow_outcome_exported = false;
    execution_initialized = false;
    execution_risk_plan_valid = false;
    execution_risk_plan_reason = "";
    execution_risk_target_amount = 0.0;
    execution_expected_sl_loss = 0.0;
    execution_expected_tp_profit = 0.0;
    execution_raw_lot_size = 0.0;
    execution_normalized_lot_size = 0.0;
    context_structure_snapshot_time = 0;
    base_structure_valid = false;
    trend_structure_valid = false;
    macro_structure_valid = false;
    session_structure_valid = false;
  }

  SignalParams(const SignalParams &other)
  {
    signal_type = other.signal_type;
    signal_state = other.signal_state;
    engine_id = other.engine_id;
    engine_label = other.engine_label;
    engine_timeframe = other.engine_timeframe;
    deterministic_strategy = other.deterministic_strategy;
    execution_sequence_id = other.execution_sequence_id;
    deterministic_source_key = other.deterministic_source_key;
    deterministic_source_attempt_index = other.deterministic_source_attempt_index;
    extremum_cycle_id = other.extremum_cycle_id;
    extremum_revision_id = other.extremum_revision_id;
    extremum_attempt_id = other.extremum_attempt_id;
    extremum_revision_index = other.extremum_revision_index;
    cycle_attempt_index = other.cycle_attempt_index;
    revision_attempt_index = other.revision_attempt_index;
    candidate_depth_percent = other.candidate_depth_percent;
    reference_range_points = other.reference_range_points;
    distance_from_first_revision_points = other.distance_from_first_revision_points;
    distance_from_previous_revision_points = other.distance_from_previous_revision_points;
    depth_delta_from_previous_percent = other.depth_delta_from_previous_percent;
    bars_since_cycle_start = other.bars_since_cycle_start;
    strategy_context = other.strategy_context;
    strategy_timeframe = other.strategy_timeframe;
    strategy_context_label = other.strategy_context_label;
    entry_trigger_mode = other.entry_trigger_mode;
    entry_price = other.entry_price;
    resolved_structure_entry = other.resolved_structure_entry;
    entry_is_limit = other.entry_is_limit;
    close_price = other.close_price;
    stop_loss = other.stop_loss;
    take_profit = other.take_profit;
    lot_size = other.lot_size;
    raw_profit = other.raw_profit;
    entry_time = other.entry_time;
    close_time = other.close_time;
    source_extremum_time = other.source_extremum_time;
    source_extremum_slot = other.source_extremum_slot;
    source_extremum_confirmed = other.source_extremum_confirmed;
    source_extremum_is_peak = other.source_extremum_is_peak;
    source_extremum_price = other.source_extremum_price;
    source_extremum_high = other.source_extremum_high;
    source_extremum_low = other.source_extremum_low;
    raw_entry_trigger_price = other.raw_entry_trigger_price;
    raw_stop_anchor_price = other.raw_stop_anchor_price;
    raw_take_profit_price = other.raw_take_profit_price;
    raw_risk_distance = other.raw_risk_distance;
    realized_profit = other.realized_profit;
    realized_closed_volume = other.realized_closed_volume;
    remaining_open_volume = other.remaining_open_volume;
    broker_entry_confirmed = other.broker_entry_confirmed;
    broker_close_confirmed = other.broker_close_confirmed;
    broker_close_source = other.broker_close_source;
    deterministic_stats_signal_id = other.deterministic_stats_signal_id;
    deterministic_stats_feature_exported = other.deterministic_stats_feature_exported;
    deterministic_stats_outcome_exported = other.deterministic_stats_outcome_exported;
    deterministic_stats_terminal_reason = other.deterministic_stats_terminal_reason;
    deterministic_stats_last_execution_check_key = other.deterministic_stats_last_execution_check_key;
    admission_status = other.admission_status;
    admission_block_source = other.admission_block_source;
    admission_block_reason = other.admission_block_reason;
    admission_updated_time = other.admission_updated_time;
    admission_spread_points = other.admission_spread_points;
    admission_market_status = other.admission_market_status;
    ml_shadow_signal_id = other.ml_shadow_signal_id;
    ml_shadow_evaluated = other.ml_shadow_evaluated;
    ml_shadow_available = other.ml_shadow_available;
    ml_shadow_feature_valid = other.ml_shadow_feature_valid;
    ml_shadow_classifier_scored = other.ml_shadow_classifier_scored;
    ml_shadow_regressor_scored = other.ml_shadow_regressor_scored;
    ml_shadow_model_id = other.ml_shadow_model_id;
    ml_shadow_export_id = other.ml_shadow_export_id;
    ml_shadow_classifier_score = other.ml_shadow_classifier_score;
    ml_shadow_regressor_score = other.ml_shadow_regressor_score;
    ml_shadow_threshold = other.ml_shadow_threshold;
    ml_shadow_recommendation = other.ml_shadow_recommendation;
    ml_shadow_reason = other.ml_shadow_reason;
    ml_shadow_outcome_exported = other.ml_shadow_outcome_exported;
    execution_initialized = other.execution_initialized;
    execution_risk_plan_valid = other.execution_risk_plan_valid;
    execution_risk_plan_reason = other.execution_risk_plan_reason;
    execution_risk_target_amount = other.execution_risk_target_amount;
    execution_expected_sl_loss = other.execution_expected_sl_loss;
    execution_expected_tp_profit = other.execution_expected_tp_profit;
    execution_raw_lot_size = other.execution_raw_lot_size;
    execution_normalized_lot_size = other.execution_normalized_lot_size;
    context_structure_snapshot_time = other.context_structure_snapshot_time;
    base_structure_valid = other.base_structure_valid;
    base_structure_data = other.base_structure_data;
    trend_structure_valid = other.trend_structure_valid;
    trend_structure_data = other.trend_structure_data;
    macro_structure_valid = other.macro_structure_valid;
    macro_structure_data = other.macro_structure_data;
    session_structure_valid = other.session_structure_valid;
    session_structure_data = other.session_structure_data;
    execution = other.execution;
  }
};

string BuildExtremumEngineSignalSequenceId(const int engine_id,
                                           const SignalTypes direction,
                                           const datetime entry_time,
                                           const datetime structure_time)
{
  string direction_token = (direction == BULLISH) ? "B" : "S";
  return StringFormat("%s_%s_%d_%d",
                      ExtremumEngineLabel(engine_id),
                      direction_token,
                      (int)entry_time,
                      (int)structure_time);
}

string BuildExtremumEngineSourceKey(const int engine_id,
                                    const SignalTypes direction,
                                    const int source_slot,
                                    const datetime extremum_time,
                                    const bool source_is_peak,
                                    const double source_price)
{
  if(engine_id <= EXTREMUM_ENGINE_NONE)
    return "";
  if(direction != BULLISH && direction != BEARISH)
    return "";
  if(source_slot < 0 || extremum_time <= 0 || source_price <= 0.0)
    return "";

  int digits = Digits();
  if(digits <= 0)
    digits = 5;

  string direction_token = (direction == BULLISH) ? "BULLISH" : "BEARISH";
  string type_token = source_is_peak ? "PEAK" : "BOTTOM";
  double normalized_price = NormalizeDouble(source_price, digits);
  return StringFormat("%s|%s|slot=%d|%s|time=%d|price=%s",
                      ExtremumEngineLabel(engine_id),
                      direction_token,
                      source_slot,
                      type_token,
                      (int)extremum_time,
                      DoubleToString(normalized_price, digits));
}

string BuildExtremumEngineSignalSourceKey(const SignalParams &signal_params)
{
  return BuildExtremumEngineSourceKey(signal_params.engine_id,
                                      signal_params.signal_type,
                                      signal_params.source_extremum_slot,
                                      signal_params.source_extremum_time,
                                      signal_params.source_extremum_is_peak,
                                      signal_params.source_extremum_price);
}

string BuildExtremumEngineSignalSourceFamilyKey(const SignalParams &signal_params)
{
  if(signal_params.signal_type != BULLISH && signal_params.signal_type != BEARISH)
    return "";
  if(signal_params.source_extremum_slot < 0 ||
     signal_params.source_extremum_time <= 0 ||
     signal_params.source_extremum_price <= 0.0)
    return "";

  int digits = Digits();
  if(digits <= 0)
    digits = 5;

  string direction_token = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string type_token = signal_params.source_extremum_is_peak ? "PEAK" : "BOTTOM";
  double normalized_price = NormalizeDouble(signal_params.source_extremum_price, digits);
  return StringFormat("%s|slot=%d|%s|time=%d|price=%s",
                      direction_token,
                      signal_params.source_extremum_slot,
                      type_token,
                      (int)signal_params.source_extremum_time,
                      DoubleToString(normalized_price, digits));
}

string BuildSignalSequenceId(const SignalTypes direction,
                             const datetime entry_time,
                             const datetime structure_time)
{
  string direction_token = (direction == BULLISH) ? "B" : "S";
  return StringFormat("%s_%d_%d",
                      direction_token,
                      (int)entry_time,
                      (int)structure_time);
}

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
