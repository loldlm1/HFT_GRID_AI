//+------------------------------------------------------------------+
//|                         trading_signals/pivot_signal_struct     |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_

enum PivotRouteFixedCounts
{
  PIVOT_ROUTE_MAX_MILESTONES = 3
};

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
  double stops_distance_points;
  double freeze_distance_points;
  double planned_entry_price;
  double stop_loss_price;
  double take_profit_price;
  double risk_distance;
  double requested_volume;
  double normalized_volume;
  double volume_min;
  double volume_max;
  double volume_step;
  bool volume_valid;
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

struct PivotRouteMilestone
{
  PivotLevelIds reached_level;
  double reached_price;
  bool moves_stop;
  double desired_stop_price;

  PivotRouteMilestone()
  {
    Reset();
  }

  PivotRouteMilestone(const PivotRouteMilestone &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    reached_level = PIVOT_LEVEL_PP;
    reached_price = 0.0;
    moves_stop = false;
    desired_stop_price = 0.0;
  }

  void CopyFrom(const PivotRouteMilestone &other)
  {
    reached_level = other.reached_level;
    reached_price = other.reached_price;
    moves_stop = other.moves_stop;
    desired_stop_price = other.desired_stop_price;
  }
};

struct PivotSignalRoute
{
  PivotRouteStatuses status;
  double intended_entry_price;
  double initial_stop_loss;
  double terminal_take_profit;
  int milestone_count;
  PivotRouteMilestone milestones[PIVOT_ROUTE_MAX_MILESTONES];
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
    initial_stop_loss = 0.0;
    terminal_take_profit = 0.0;
    milestone_count = 0;
    denial_reason = "";
    for(int i = 0; i < PIVOT_ROUTE_MAX_MILESTONES; i++)
      milestones[i].Reset();
  }

  void CopyFrom(const PivotSignalRoute &other)
  {
    status = other.status;
    intended_entry_price = other.intended_entry_price;
    initial_stop_loss = other.initial_stop_loss;
    terminal_take_profit = other.terminal_take_profit;
    milestone_count = other.milestone_count;
    denial_reason = other.denial_reason;
    for(int i = 0; i < PIVOT_ROUTE_MAX_MILESTONES; i++)
      milestones[i].CopyFrom(other.milestones[i]);
  }
};

struct PivotSignalExecution
{
  ExecutionOrderStates state;
  double planned_entry_price;
  double stop_loss_price;
  double take_profit_price;
  double risk_distance;
  double requested_volume;
  double normalized_volume;
  double risk_target_amount;
  double expected_stop_loss;
  double broker_entry_price;
  double broker_volume;
  double broker_stop_loss;
  double broker_take_profit;
  double pending_stop_loss;
  double close_price;
  double closed_volume;
  double realized_profit;
  ulong order_ticket;
  ulong entry_deal_ticket;
  ulong close_deal_ticket;
  ulong position_ticket;
  ulong position_identifier;
  string position_comment;
  datetime broker_entry_time;
  datetime close_time;
  datetime last_action_time;
  datetime next_trailing_retry_time;
  int last_check_sequence;
  int highest_milestone_index;
  int pending_milestone_index;
  int trailing_event_sequence;
  int trailing_retry_count;
  bool trailing_retry_pending;
  bool trailing_confirmation_pending;
  bool trailing_ownership_failure_recorded;
  bool terminal_check_exported;
  bool send_attempted;
  bool broker_entry_confirmed;
  bool broker_close_confirmed;
  bool outcome_exported;
  string terminal_reason;
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
    risk_distance = 0.0;
    requested_volume = 0.0;
    normalized_volume = 0.0;
    risk_target_amount = 0.0;
    expected_stop_loss = 0.0;
    broker_entry_price = 0.0;
    broker_volume = 0.0;
    broker_stop_loss = 0.0;
    broker_take_profit = 0.0;
    pending_stop_loss = 0.0;
    close_price = 0.0;
    closed_volume = 0.0;
    realized_profit = 0.0;
    order_ticket = 0;
    entry_deal_ticket = 0;
    close_deal_ticket = 0;
    position_ticket = 0;
    position_identifier = 0;
    position_comment = "";
    broker_entry_time = 0;
    close_time = 0;
    last_action_time = 0;
    next_trailing_retry_time = 0;
    last_check_sequence = 0;
    highest_milestone_index = -1;
    pending_milestone_index = -1;
    trailing_event_sequence = 0;
    trailing_retry_count = 0;
    trailing_retry_pending = false;
    trailing_confirmation_pending = false;
    trailing_ownership_failure_recorded = false;
    terminal_check_exported = false;
    send_attempted = false;
    broker_entry_confirmed = false;
    broker_close_confirmed = false;
    outcome_exported = false;
    terminal_reason = "";
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
    risk_distance = other.risk_distance;
    requested_volume = other.requested_volume;
    normalized_volume = other.normalized_volume;
    risk_target_amount = other.risk_target_amount;
    expected_stop_loss = other.expected_stop_loss;
    broker_entry_price = other.broker_entry_price;
    broker_volume = other.broker_volume;
    broker_stop_loss = other.broker_stop_loss;
    broker_take_profit = other.broker_take_profit;
    pending_stop_loss = other.pending_stop_loss;
    close_price = other.close_price;
    closed_volume = other.closed_volume;
    realized_profit = other.realized_profit;
    order_ticket = other.order_ticket;
    entry_deal_ticket = other.entry_deal_ticket;
    close_deal_ticket = other.close_deal_ticket;
    position_ticket = other.position_ticket;
    position_identifier = other.position_identifier;
    position_comment = other.position_comment;
    broker_entry_time = other.broker_entry_time;
    close_time = other.close_time;
    last_action_time = other.last_action_time;
    next_trailing_retry_time = other.next_trailing_retry_time;
    last_check_sequence = other.last_check_sequence;
    highest_milestone_index = other.highest_milestone_index;
    pending_milestone_index = other.pending_milestone_index;
    trailing_event_sequence = other.trailing_event_sequence;
    trailing_retry_count = other.trailing_retry_count;
    trailing_retry_pending = other.trailing_retry_pending;
    trailing_confirmation_pending = other.trailing_confirmation_pending;
    trailing_ownership_failure_recorded =
      other.trailing_ownership_failure_recorded;
    terminal_check_exported = other.terminal_check_exported;
    send_attempted = other.send_attempted;
    broker_entry_confirmed = other.broker_entry_confirmed;
    broker_close_confirmed = other.broker_close_confirmed;
    outcome_exported = other.outcome_exported;
    terminal_reason = other.terminal_reason;
    observation_check.CopyFrom(other.observation_check);
    pre_send_check.CopyFrom(other.pre_send_check);
    send_result_check.CopyFrom(other.send_result_check);
  }
};

struct PivotSignal
{
  string signal_id;
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
  bool attempt_exported;

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
    signal_id = "";
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
    attempt_exported = false;
  }

  void CopyFrom(const PivotSignal &other)
  {
    signal_id = other.signal_id;
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
    attempt_exported = other.attempt_exported;
  }
};

bool PivotRouteSetLevelPrice(const PivotPriceLadder &levels,
                             const PivotLevelIds level,
                             double &price_out)
{
  return PivotTradePrice(levels, level, price_out);
}

bool PivotRouteAddMilestone(PivotSignalRoute &route,
                            const PivotPriceLadder &levels,
                            const PivotLevelIds reached_level,
                            const bool moves_stop,
                            const PivotLevelIds desired_stop_level = PIVOT_LEVEL_PP)
{
  if(route.milestone_count < 0 ||
     route.milestone_count >= PIVOT_ROUTE_MAX_MILESTONES)
    return false;

  PivotRouteMilestone milestone;
  if(!PivotRouteSetLevelPrice(levels,
                              reached_level,
                              milestone.reached_price))
    return false;
  milestone.reached_level = reached_level;
  milestone.moves_stop = moves_stop;
  if(moves_stop &&
     !PivotRouteSetLevelPrice(levels,
                              desired_stop_level,
                              milestone.desired_stop_price))
    return false;
  route.milestones[route.milestone_count].CopyFrom(milestone);
  route.milestone_count++;
  return true;
}

bool PivotRouteGeometryValid(const SignalTypes direction,
                             const PivotSignalRoute &route)
{
  if(route.intended_entry_price <= 0.0 ||
     route.initial_stop_loss <= 0.0 ||
     route.terminal_take_profit <= 0.0)
    return false;
  if(direction == BULLISH)
    return (route.initial_stop_loss < route.intended_entry_price &&
            route.terminal_take_profit > route.intended_entry_price);
  if(direction == BEARISH)
    return (route.initial_stop_loss > route.intended_entry_price &&
            route.terminal_take_profit < route.intended_entry_price);
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
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S1, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R1, true, PIVOT_LEVEL_PP) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R2, true, PIVOT_LEVEL_R1);
        break;
      case PIVOT_LEVEL_S1:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S2, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_PP, false) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R1, true, PIVOT_LEVEL_PP) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R2, true, PIVOT_LEVEL_R1);
        break;
      case PIVOT_LEVEL_S2:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R1, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S1, true, PIVOT_LEVEL_S2) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_PP, true, PIVOT_LEVEL_S1);
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
                                               synthetic_stop) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_PP, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S2, true, PIVOT_LEVEL_S3) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S1, true, PIVOT_LEVEL_S2);
        route_out.initial_stop_loss = synthetic_stop;
        break;
      }
      case PIVOT_LEVEL_R1:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_PP, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R2, true, PIVOT_LEVEL_R1);
        break;
      case PIVOT_LEVEL_R2:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R1, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, route_out.terminal_take_profit);
        break;
      case PIVOT_LEVEL_R3:
        route_out.status = PIVOT_ROUTE_NO_FORWARD_LEVEL;
        route_out.denial_reason = "NO_FORWARD_LEVEL";
        return false;
    }
  }
  else if(direction == BEARISH)
  {
    switch(entry_level)
    {
      case PIVOT_LEVEL_PP:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R1, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S1, true, PIVOT_LEVEL_PP) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S2, true, PIVOT_LEVEL_S1);
        break;
      case PIVOT_LEVEL_R1:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R2, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_PP, false) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S1, true, PIVOT_LEVEL_PP) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S2, true, PIVOT_LEVEL_S1);
        break;
      case PIVOT_LEVEL_R2:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_R3, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S1, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R1, true, PIVOT_LEVEL_R2) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_PP, true, PIVOT_LEVEL_R1);
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
                                               synthetic_stop) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_PP, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R2, true, PIVOT_LEVEL_R3) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_R1, true, PIVOT_LEVEL_R2);
        route_out.initial_stop_loss = synthetic_stop;
        break;
      }
      case PIVOT_LEVEL_S1:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_PP, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, route_out.terminal_take_profit) &&
                      PivotRouteAddMilestone(route_out, levels, PIVOT_LEVEL_S2, true, PIVOT_LEVEL_S1);
        break;
      case PIVOT_LEVEL_S2:
        route_built = PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S1, route_out.initial_stop_loss) &&
                      PivotRouteSetLevelPrice(levels, PIVOT_LEVEL_S3, route_out.terminal_take_profit);
        break;
      case PIVOT_LEVEL_S3:
        route_out.status = PIVOT_ROUTE_NO_FORWARD_LEVEL;
        route_out.denial_reason = "NO_FORWARD_LEVEL";
        return false;
    }
  }
  else
  {
    route_built = false;
  }

  if(!route_built || !PivotRouteGeometryValid(direction, route_out))
  {
    route_out.status = PIVOT_ROUTE_INVALID_GEOMETRY;
    route_out.denial_reason = "ROUTE_GEOMETRY_INVALID";
    return false;
  }

  route_out.status = PIVOT_ROUTE_ALLOWED;
  route_out.denial_reason = "";
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_SIGNAL_STRUCT_MQH_
