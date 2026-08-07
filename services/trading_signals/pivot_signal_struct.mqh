//+------------------------------------------------------------------+
//|                         trading_signals/pivot_signal_struct     |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_

struct BrokerExecutionCheck
{
  string phase;
  int sequence;
  datetime broker_time;
  string symbol;
  SignalTypes direction;
  long account_margin_mode;
  long symbol_trade_mode;
  bool account_margin_mode_supported;
  bool symbol_trade_mode_allowed;
  bool market_session_open;
  bool account_trade_allowed;
  bool account_expert_trade_allowed;
  bool terminal_trade_allowed;
  bool mql_trade_allowed;
  double bid;
  double ask;
  double spread_points;
  double point_size;
  double trade_tick_size;
  double stops_distance_points;
  double freeze_distance_points;
  double planned_entry_price;
  double stop_loss_price;
  double take_profit_price;
  double risk_distance_points;
  double reward_distance_points;
  double price_reward_risk_ratio;
  double risk_budget_amount;
  double requested_volume;
  double normalized_volume;
  double volume_min;
  double volume_max;
  double volume_step;
  bool volume_valid;
  bool fok_supported;
  double quote_expected_stop_loss;
  double quote_expected_take_profit;
  double quote_expected_reward_risk_ratio;
  double risk_budget_utilization_ratio;
  double account_balance;
  double free_margin;
  double required_margin;
  bool margin_valid;
  bool geometry_valid;
  bool stop_distance_valid;
  bool freeze_distance_valid;
  bool order_check_performed;
  bool order_check_allowed;
  ulong order_check_retcode;
  string order_check_comment;
  bool allowed;
  string block_source;
  string block_reason;
  ulong send_retcode;
  string send_comment;
  ulong order_ticket;
  ulong deal_ticket;

  BrokerExecutionCheck()
  {
    Reset();
  }

  BrokerExecutionCheck(const BrokerExecutionCheck &other)
  {
    CopyFrom(other);
  }

  void Reset()
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
    trade_tick_size = 0.0;
    stops_distance_points = 0.0;
    freeze_distance_points = 0.0;
    planned_entry_price = 0.0;
    stop_loss_price = 0.0;
    take_profit_price = 0.0;
    risk_distance_points = 0.0;
    reward_distance_points = 0.0;
    price_reward_risk_ratio = 0.0;
    risk_budget_amount = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    volume_min = 0.0;
    volume_max = 0.0;
    volume_step = 0.0;
    volume_valid = false;
    fok_supported = false;
    quote_expected_stop_loss = 0.0;
    quote_expected_take_profit = 0.0;
    quote_expected_reward_risk_ratio = 0.0;
    risk_budget_utilization_ratio = 0.0;
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

  void CopyFrom(const BrokerExecutionCheck &other)
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
    trade_tick_size = other.trade_tick_size;
    stops_distance_points = other.stops_distance_points;
    freeze_distance_points = other.freeze_distance_points;
    planned_entry_price = other.planned_entry_price;
    stop_loss_price = other.stop_loss_price;
    take_profit_price = other.take_profit_price;
    risk_distance_points = other.risk_distance_points;
    reward_distance_points = other.reward_distance_points;
    price_reward_risk_ratio = other.price_reward_risk_ratio;
    risk_budget_amount = other.risk_budget_amount;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    volume_min = other.volume_min;
    volume_max = other.volume_max;
    volume_step = other.volume_step;
    volume_valid = other.volume_valid;
    fok_supported = other.fok_supported;
    quote_expected_stop_loss = other.quote_expected_stop_loss;
    quote_expected_take_profit = other.quote_expected_take_profit;
    quote_expected_reward_risk_ratio =
      other.quote_expected_reward_risk_ratio;
    risk_budget_utilization_ratio = other.risk_budget_utilization_ratio;
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

struct PivotSignalRoute
{
  PivotRouteStatuses status;
  double intended_entry_price;
  double structural_stop_loss;
  string denial_reason;

  PivotSignalRoute()
  {
    Reset();
  }

  PivotSignalRoute(const PivotSignalRoute &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    status = PIVOT_ROUTE_NOT_BUILT;
    intended_entry_price = 0.0;
    structural_stop_loss = 0.0;
    denial_reason = "";
  }

  void CopyFrom(const PivotSignalRoute &other)
  {
    status = other.status;
    intended_entry_price = other.intended_entry_price;
    structural_stop_loss = other.structural_stop_loss;
    denial_reason = other.denial_reason;
  }
};

struct PivotSignalExecution
{
  ExecutionOrderStates state;
  double planned_entry_price;
  double stop_loss_price;
  double take_profit_price;
  double risk_distance_points;
  double reward_distance_points;
  double price_reward_risk_ratio;
  double requested_volume;
  double normalized_volume;
  double risk_budget_amount;
  double quote_expected_stop_loss;
  double quote_expected_take_profit;
  double quote_expected_reward_risk_ratio;
  double risk_budget_utilization_ratio;
  double broker_entry_price;
  double broker_volume;
  double broker_stop_loss;
  double broker_take_profit;
  double close_price;
  double closed_volume;
  double entry_slippage_points;
  double exit_slippage_points;
  double gross_profit;
  double commission;
  double swap;
  double fee;
  double net_profit;
  double gross_budget_r;
  double net_budget_r;
  double gross_execution_r;
  double net_execution_r;
  ulong order_ticket;
  ulong entry_deal_ticket;
  ulong last_close_deal_ticket;
  ulong position_ticket;
  ulong position_identifier;
  string position_comment;
  datetime broker_entry_time;
  datetime close_time;
  datetime last_action_time;
  int last_check_sequence;
  int close_deal_count;
  int binary_target;
  bool close_reason_consistent;
  bool binary_eligible;
  bool entry_check_exported;
  bool terminal_check_exported;
  bool send_attempted;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;
  bool outcome_exported;
  string terminal_reason;
  string exclusion_reason;
  BrokerExecutionCheck observation_check;
  BrokerExecutionCheck pre_send_check;
  BrokerExecutionCheck send_result_check;

  PivotSignalExecution()
  {
    Reset();
  }

  PivotSignalExecution(const PivotSignalExecution &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    state = EXECUTION_ORDER_WAITING;
    planned_entry_price = 0.0;
    stop_loss_price = 0.0;
    take_profit_price = 0.0;
    risk_distance_points = 0.0;
    reward_distance_points = 0.0;
    price_reward_risk_ratio = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    risk_budget_amount = 0.0;
    quote_expected_stop_loss = 0.0;
    quote_expected_take_profit = 0.0;
    quote_expected_reward_risk_ratio = 0.0;
    risk_budget_utilization_ratio = 0.0;
    broker_entry_price = 0.0;
    broker_volume = 0.0;
    broker_stop_loss = 0.0;
    broker_take_profit = 0.0;
    close_price = 0.0;
    closed_volume = 0.0;
    entry_slippage_points = 0.0;
    exit_slippage_points = 0.0;
    gross_profit = 0.0;
    commission = 0.0;
    swap = 0.0;
    fee = 0.0;
    net_profit = 0.0;
    gross_budget_r = 0.0;
    net_budget_r = 0.0;
    gross_execution_r = 0.0;
    net_execution_r = 0.0;
    order_ticket = 0;
    entry_deal_ticket = 0;
    last_close_deal_ticket = 0;
    position_ticket = 0;
    position_identifier = 0;
    position_comment = "";
    broker_entry_time = 0;
    close_time = 0;
    last_action_time = 0;
    last_check_sequence = 0;
    close_deal_count = 0;
    binary_target = -1;
    close_reason_consistent = false;
    binary_eligible = false;
    entry_check_exported = false;
    terminal_check_exported = false;
    send_attempted = false;
    broker_entry_confirmed = false;
    broker_close_confirmed = false;
    outcome_exported = false;
    terminal_reason = "";
    exclusion_reason = "";
    observation_check.Reset();
    pre_send_check.Reset();
    send_result_check.Reset();
  }

  void CopyFrom(const PivotSignalExecution &other)
  {
    state = other.state;
    planned_entry_price = other.planned_entry_price;
    stop_loss_price = other.stop_loss_price;
    take_profit_price = other.take_profit_price;
    risk_distance_points = other.risk_distance_points;
    reward_distance_points = other.reward_distance_points;
    price_reward_risk_ratio = other.price_reward_risk_ratio;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    risk_budget_amount = other.risk_budget_amount;
    quote_expected_stop_loss = other.quote_expected_stop_loss;
    quote_expected_take_profit = other.quote_expected_take_profit;
    quote_expected_reward_risk_ratio =
      other.quote_expected_reward_risk_ratio;
    risk_budget_utilization_ratio = other.risk_budget_utilization_ratio;
    broker_entry_price = other.broker_entry_price;
    broker_volume = other.broker_volume;
    broker_stop_loss = other.broker_stop_loss;
    broker_take_profit = other.broker_take_profit;
    close_price = other.close_price;
    closed_volume = other.closed_volume;
    entry_slippage_points = other.entry_slippage_points;
    exit_slippage_points = other.exit_slippage_points;
    gross_profit = other.gross_profit;
    commission = other.commission;
    swap = other.swap;
    fee = other.fee;
    net_profit = other.net_profit;
    gross_budget_r = other.gross_budget_r;
    net_budget_r = other.net_budget_r;
    gross_execution_r = other.gross_execution_r;
    net_execution_r = other.net_execution_r;
    order_ticket = other.order_ticket;
    entry_deal_ticket = other.entry_deal_ticket;
    last_close_deal_ticket = other.last_close_deal_ticket;
    position_ticket = other.position_ticket;
    position_identifier = other.position_identifier;
    position_comment = other.position_comment;
    broker_entry_time = other.broker_entry_time;
    close_time = other.close_time;
    last_action_time = other.last_action_time;
    last_check_sequence = other.last_check_sequence;
    close_deal_count = other.close_deal_count;
    binary_target = other.binary_target;
    close_reason_consistent = other.close_reason_consistent;
    binary_eligible = other.binary_eligible;
    entry_check_exported = other.entry_check_exported;
    terminal_check_exported = other.terminal_check_exported;
    send_attempted = other.send_attempted;
    broker_entry_confirmed = other.broker_entry_confirmed;
    broker_close_confirmed = other.broker_close_confirmed;
    outcome_exported = other.outcome_exported;
    terminal_reason = other.terminal_reason;
    exclusion_reason = other.exclusion_reason;
    observation_check.CopyFrom(other.observation_check);
    pre_send_check.CopyFrom(other.pre_send_check);
    send_result_check.CopyFrom(other.send_result_check);
  }
};

struct PivotSignal
{
  string origin_id;
  string broker_signal_id;
  string parity_trial_id;
  string window_id;
  ENUM_TIMEFRAMES pivot_timeframe;
  datetime active_bar_open;
  datetime source_bar_open;
  datetime source_close_boundary;
  PivotLevelIds level_id;
  SignalTypes direction;
  datetime trigger_time;
  double trigger_bid;
  double trigger_ask;
  double trigger_spread_points;
  PivotPriceLadder levels;
  PivotContextFeatureSnapshot features;
  PivotSignalRoute route;
  PivotSignalExecution execution;
  ExecutionAdmissionStatuses admission_status;
  string attempt_status;
  string block_source;
  string block_reason;
  bool matrix_declared;
  bool origin_registered;

  PivotSignal()
  {
    Reset();
  }

  PivotSignal(const PivotSignal &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin_id = "";
    broker_signal_id = "";
    parity_trial_id = "";
    window_id = "";
    pivot_timeframe = PERIOD_CURRENT;
    active_bar_open = 0;
    source_bar_open = 0;
    source_close_boundary = 0;
    level_id = PIVOT_LEVEL_PP;
    direction = NO_SIGNAL;
    trigger_time = 0;
    trigger_bid = 0.0;
    trigger_ask = 0.0;
    trigger_spread_points = 0.0;
    levels.Reset();
    features.Reset();
    route.Reset();
    execution.Reset();
    admission_status = EXECUTION_ADMISSION_NOT_EVALUATED;
    attempt_status = "";
    block_source = "";
    block_reason = "";
    matrix_declared = false;
    origin_registered = false;
  }

  void CopyFrom(const PivotSignal &other)
  {
    origin_id = other.origin_id;
    broker_signal_id = other.broker_signal_id;
    parity_trial_id = other.parity_trial_id;
    window_id = other.window_id;
    pivot_timeframe = other.pivot_timeframe;
    active_bar_open = other.active_bar_open;
    source_bar_open = other.source_bar_open;
    source_close_boundary = other.source_close_boundary;
    level_id = other.level_id;
    direction = other.direction;
    trigger_time = other.trigger_time;
    trigger_bid = other.trigger_bid;
    trigger_ask = other.trigger_ask;
    trigger_spread_points = other.trigger_spread_points;
    levels.CopyFrom(other.levels);
    features.CopyFrom(other.features);
    route.CopyFrom(other.route);
    execution.CopyFrom(other.execution);
    admission_status = other.admission_status;
    attempt_status = other.attempt_status;
    block_source = other.block_source;
    block_reason = other.block_reason;
    matrix_declared = other.matrix_declared;
    origin_registered = other.origin_registered;
  }
};

bool PivotRouteSetLevelPrice(const PivotPriceLadder &levels,
                             const PivotLevelIds level,
                             double &price_out)
{
  return PivotTradePrice(levels, level, price_out);
}

bool PivotRouteGeometryValid(const SignalTypes direction,
                             const PivotSignalRoute &route)
{
  if(route.intended_entry_price <= 0.0 ||
     route.structural_stop_loss <= 0.0)
    return false;
  if(direction == BULLISH)
    return route.structural_stop_loss < route.intended_entry_price;
  if(direction == BEARISH)
    return route.structural_stop_loss > route.intended_entry_price;
  return false;
}

bool BuildPivotSignalRoute(const string symbol,
                           const SignalTypes direction,
                           const PivotLevelIds entry_level,
                           const PivotPriceLadder &levels,
                           PivotSignalRoute &route_out)
{
  route_out.Reset();
  if(!levels.valid ||
     !PivotRouteSetLevelPrice(levels,
                              entry_level,
                              route_out.intended_entry_price))
  {
    route_out.status = PIVOT_ROUTE_INVALID_GEOMETRY;
    route_out.denial_reason = "PIVOT_LADDER_INVALID";
    return false;
  }

  bool route_built = true;
  if(direction == BULLISH)
  {
    switch(entry_level)
    {
      case PIVOT_LEVEL_PP:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_S1,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_S1:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_S2,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_S2:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_S3,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_S3:
      {
        double s2 = 0.0;
        double s3 = 0.0;
        double synthetic_stop = 0.0;
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S2, s2) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, s3) &&
                      NormalizePivotTradePrice(symbol,
                                               s3 - (s2 - s3),
                                               synthetic_stop);
        route_out.structural_stop_loss = synthetic_stop;
        break;
      }
      default:
        route_built = false;
        break;
    }
  }
  else if(direction == BEARISH)
  {
    switch(entry_level)
    {
      case PIVOT_LEVEL_PP:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_R1,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_R1:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_R2,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_R2:
        route_built = PivotRouteSetLevelPrice(levels,
                                              PIVOT_LEVEL_R3,
                                              route_out.structural_stop_loss);
        break;
      case PIVOT_LEVEL_R3:
      {
        double r2 = 0.0;
        double r3 = 0.0;
        double synthetic_stop = 0.0;
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R2, r2) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, r3) &&
                      NormalizePivotTradePrice(symbol,
                                               r3 + (r3 - r2),
                                               synthetic_stop);
        route_out.structural_stop_loss = synthetic_stop;
        break;
      }
      default:
        route_built = false;
        break;
    }
  }
  else
  {
    route_built = false;
  }

  if(!route_built || !PivotRouteGeometryValid(direction, route_out))
  {
    route_out.status = PIVOT_ROUTE_INVALID_GEOMETRY;
    route_out.denial_reason = route_built
                              ? "ROUTE_GEOMETRY_INVALID"
                              : "DIRECTION_LEVEL_ROUTE_UNSUPPORTED";
    return false;
  }

  route_out.status = PIVOT_ROUTE_ALLOWED;
  route_out.denial_reason = "";
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_
