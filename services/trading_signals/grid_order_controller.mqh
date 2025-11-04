//+------------------------------------------------------------------+
//|                               grid_order_controller.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

// ── Internal helpers ──────────────────────────────────────────────

double GridResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double GridResolveDirectionMultiplier(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

double GridCurrentPriceForDirection(const SignalTypes direction,
                                    const bool use_entry_side)
{
  if(direction == BULLISH)
    return use_entry_side ? g_ask : g_bid;
  return use_entry_side ? g_bid : g_ask;
}

bool GridGuardrailsAllowOrder(const double normalized_volume)
{
  if(g_points_spread > Max_Spread)
    return false;

  double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(free_margin <= 0.0)
    return true;

  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot <= 0.0)
  {
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price         = GridCurrentPriceForDirection(BULLISH, true);
    double leverage      = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(contract_size > 0.0 && leverage > 0.0)
      margin_per_lot = (contract_size * price) / leverage;
  }

  if(margin_per_lot <= 0.0)
    return true;

  double required_margin = margin_per_lot * normalized_volume;
  if(required_margin <= 0.0)
    return true;

  return (free_margin >= required_margin);
}

void GridLogEvent(const string label,
                  const SignalParams &signal_params,
                  const GridOrderState &order_state,
                  const GridLevelPlan &level_plan)
{
  if(Enable_Logs) Print("LOG EVENT: ", label);
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|status=%s|pending=%.5f|protect=%.5f|entry=%.5f|tp=%.5f|next=%.5f|anchor=%.5f|dist=%.1f|pct=%.2f",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                order_state.last_pending_price,
                                order_state.stop_loss_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                order_state.next_level_price,
                                order_state.anchor_price,
                                order_state.resolved_distance_points,
                                order_state.grid_range_percent);
  AppendTimestampedLog("query_debug.txt", label, message);
}

string GridComposeLevelComment(const SignalParams &signal_params,
                               const GridOrderState &order_state)
{
  string direction_label = (signal_params.signal_type == BULLISH) ? "B" : "S";
  string time_label      = IntegerToString((long)signal_params.entry_time);
  return StringFormat("GRID_%s_%s_L%d", direction_label, time_label, order_state.level_index);
}

void GridEnsureOrderState(SignalParams &signal_params,
                          const int level_index)
{
  if(level_index < 0)
    return;

  int current_total = ArraySize(signal_params.grid_orders);
  if(current_total > level_index)
    return;

  int target_total = level_index + 1;
  ArrayResize(signal_params.grid_orders, target_total);
  for(int i = current_total; i < target_total; i++)
  {
    GridOrderState state = GridOrderState();
    state.level_index = i;
    signal_params.grid_orders[i] = state;
  }
}

void GridResetOrderStateForWaiting(GridOrderState &state,
                                   const GridLevelPlan &level_plan)
{
  int level_index = state.level_index;
  state = GridOrderState();
  state.level_index     = level_index;
  state.status          = GRID_ORDER_WAITING;
  state.trailing_points = level_plan.trailing_points;
  state.resolved_distance_points = level_plan.distance_points;
  state.grid_range_percent = -1.0;
}

void GridScalePlannedLevels(SignalParams &signal_params,
                            const double scaling_factor,
                            const int from_level_index)
{
  if(from_level_index < 0)
    return;
  if(scaling_factor <= 0.0)
    return;
  if(MathAbs(scaling_factor - 1.0) < 1e-6)
    return;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = from_level_index; i < levels_total; i++)
  {
    GridLevelPlan plan = signal_params.grid_plan.levels[i];
    plan.distance_points           *= scaling_factor;
    plan.baseline_distance_points  *= scaling_factor;
    plan.pending_order_points      *= scaling_factor;
    plan.entry_offset_points       *= scaling_factor;
    plan.protective_stop_points    *= scaling_factor;
    plan.activation_points         *= scaling_factor;
    plan.activation_offset_points  *= scaling_factor;
    plan.take_profit_points        *= scaling_factor;
    plan.final_take_profit_points  *= scaling_factor;
    plan.trailing_points           *= scaling_factor;
    signal_params.grid_plan.levels[i] = plan;
  }
}

void GridScheduleNextLevel(SignalParams &signal_params,
                           const int next_level_index)
{
  if(next_level_index < 0)
    return;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  if(next_level_index >= levels_total)
  {
    if(!GridEnsureLevelPlan(signal_params, next_level_index))
      return;
    levels_total = ArraySize(signal_params.grid_plan.levels);
    if(next_level_index >= levels_total)
      return;
  }

  GridEnsureOrderState(signal_params, next_level_index);
  GridOrderState next_state = signal_params.grid_orders[next_level_index];
  if(next_state.status == GRID_ORDER_WAITING ||
     next_state.status == GRID_ORDER_PENDING ||
     next_state.status == GRID_ORDER_ACTIVE)
    return;

  GridLevelPlan level_plan = signal_params.grid_plan.levels[next_level_index];
  GridResetOrderStateForWaiting(next_state, level_plan);
  signal_params.grid_orders[next_level_index] = next_state;
}

void GridRecalculateRangeMetrics(SignalParams &signal_params,
                                 const double point_size)
{
  int total_orders = ArraySize(signal_params.grid_orders);
  double range_high_price = 0.0;
  double range_low_price  = 0.0;
  bool   has_active       = false;
  int    active_levels    = 0;

  double temp_percents[];
  ArrayResize(temp_percents, total_orders);
  ArrayInitialize(temp_percents, -1.0);

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status != GRID_ORDER_ACTIVE || state.entry_price <= 0.0)
      continue;

    if(!has_active)
    {
      range_high_price = state.entry_price;
      range_low_price  = state.entry_price;
      has_active       = true;
    }
    else
    {
      if(state.entry_price > range_high_price)
        range_high_price = state.entry_price;
      if(state.entry_price < range_low_price)
        range_low_price = state.entry_price;
    }

    active_levels++;
  }

  if(!has_active)
  {
    signal_params.grid_plan.range_high_price = 0.0;
    signal_params.grid_plan.range_low_price  = 0.0;
    signal_params.grid_stats.current_range_points = 0.0;

    for(int i = 0; i < total_orders; i++)
    {
      GridOrderState state = signal_params.grid_orders[i];
      state.grid_range_percent = -1.0;
      signal_params.grid_orders[i] = state;

      if(i < ArraySize(signal_params.grid_plan.levels))
      {
        GridLevelPlan plan = signal_params.grid_plan.levels[i];
        plan.grid_range_percent = -1.0;
        signal_params.grid_plan.levels[i] = plan;
      }
    }
    return;
  }

  signal_params.grid_plan.range_high_price = range_high_price;
  signal_params.grid_plan.range_low_price  = range_low_price;

  double range_span_price = range_high_price - range_low_price;
  if(range_span_price <= 0.0 || active_levels < 2)
  {
    signal_params.grid_stats.current_range_points = 0.0;
    for(int i = 0; i < total_orders; i++)
    {
      GridOrderState state = signal_params.grid_orders[i];
      if(state.status == GRID_ORDER_ACTIVE)
        state.grid_range_percent = -1.0;
      else
        state.grid_range_percent = -1.0;
      signal_params.grid_orders[i] = state;

      if(i < ArraySize(signal_params.grid_plan.levels))
      {
        GridLevelPlan plan = signal_params.grid_plan.levels[i];
        plan.grid_range_percent = state.grid_range_percent;
        signal_params.grid_plan.levels[i] = plan;
      }
    }
    return;
  }

  double range_span_points = 0.0;
  if(point_size > 0.0)
    range_span_points = range_span_price / point_size;
  signal_params.grid_stats.current_range_points = MathAbs(range_span_points);

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status != GRID_ORDER_ACTIVE || state.entry_price <= 0.0)
      continue;

    double percent = (state.entry_price - range_low_price) / range_span_price * 100.0;
    if(percent < 0.0)
      percent = 0.0;
    if(percent > 100.0)
      percent = 100.0;
    temp_percents[i] = percent;
  }

  bool should_invert = false;
  if(total_orders > 0)
  {
    GridOrderState base_state = signal_params.grid_orders[0];
    if(base_state.status == GRID_ORDER_ACTIVE &&
       temp_percents[0] >= 0.0 &&
       temp_percents[0] < 50.0)
      should_invert = true;
  }

  if(should_invert)
  {
    for(int i = 0; i < total_orders; i++)
    {
      if(temp_percents[i] >= 0.0)
        temp_percents[i] = 100.0 - temp_percents[i];
    }
  }

  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(temp_percents[i] >= 0.0)
      state.grid_range_percent = temp_percents[i];
    else
      state.grid_range_percent = -1.0;
    signal_params.grid_orders[i] = state;

    if(i < ArraySize(signal_params.grid_plan.levels))
    {
      GridLevelPlan plan = signal_params.grid_plan.levels[i];
      plan.grid_range_percent = state.grid_range_percent;
      signal_params.grid_plan.levels[i] = plan;
    }
  }
}

double GridPointsBetween(const SignalTypes direction,
                         const double reference_price,
                         const double candidate_price,
                         const double point_size)
{
  if(point_size <= 0.0)
    return 0.0;

  if(direction == BULLISH)
    return (reference_price - candidate_price) / point_size;
  return (candidate_price - reference_price) / point_size;
}

void GridUpdateNextLevelPrice(const SignalTypes direction,
                              GridOrderState &order_state,
                              const GridLevelPlan &level_plan,
                              const double point_size,
                              const double current_price)
{
  double direction_mult = GridResolveDirectionMultiplier(direction);
  double candidate_price = current_price - direction_mult * level_plan.distance_points * point_size;

  if(order_state.next_level_price == 0.0)
  {
    order_state.next_level_price = candidate_price;
    return;
  }

  if(direction == BULLISH)
  {
    if(candidate_price < order_state.next_level_price)
      order_state.next_level_price = candidate_price;
  }
  else if(direction == BEARISH)
  {
    if(candidate_price > order_state.next_level_price)
      order_state.next_level_price = candidate_price;
  }
}

double GridResolvePendingPoints(const GridLevelPlan &level_plan)
{
  double pending_points = level_plan.pending_order_points;
  if(pending_points <= 0.0)
  {
    pending_points = level_plan.distance_points + level_plan.entry_offset_points;
    if(pending_points <= 0.0)
      pending_points = level_plan.distance_points;
  }
  return pending_points;
}

void GridInitializePendingLevel(const SignalTypes direction,
                                GridOrderState &order_state,
                                const GridLevelPlan &level_plan,
                                const double point_size)
{
  double direction_mult = GridResolveDirectionMultiplier(direction);
  double anchor_price   = order_state.anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = GridCurrentPriceForDirection(direction, true);

  order_state.anchor_price     = anchor_price;
  order_state.status           = GRID_ORDER_PENDING;
  order_state.last_action_time = TimeCurrent();

  double pending_points = GridResolvePendingPoints(level_plan);
  double pending_price  = anchor_price + direction_mult * pending_points * point_size;

  order_state.anchor_price     = anchor_price;
  order_state.stop_loss_price    = 0.0;
  order_state.last_pending_price = pending_price;
  order_state.next_level_price   = 0.0;

  if(level_plan.take_profit_points > 0.0)
  {
    double expected_entry = pending_price;
    order_state.take_profit_price = expected_entry + direction_mult * level_plan.take_profit_points * point_size;
  }
  else
  {
    order_state.take_profit_price = 0.0;
  }

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = pending_price + direction_mult * level_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

  order_state.trailing_price   = 0.0;
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.resolved_distance_points = level_plan.distance_points;
  order_state.grid_range_percent = -1.0;
  order_state.entry_price        = 0.0;
  order_state.position_ticket    = 0;
  order_state.position_comment   = "";
}

void GridUpdatePendingLevel(const SignalTypes direction,
                            GridOrderState &order_state,
                            const GridLevelPlan &level_plan,
                            const double point_size)
{
  double direction_mult   = GridResolveDirectionMultiplier(direction);
  double anchor_price     = order_state.anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = GridCurrentPriceForDirection(direction, true);

  double pending_points = GridResolvePendingPoints(level_plan);
  double pending_price  = anchor_price + direction_mult * pending_points * point_size;

  order_state.stop_loss_price    = 0.0;
  order_state.last_pending_price = pending_price;
  order_state.next_level_price   = 0.0;

  if(level_plan.take_profit_points > 0.0)
  {
    double expected_entry = pending_price;
    order_state.take_profit_price = expected_entry + direction_mult * level_plan.take_profit_points * point_size;
  }
  else
  {
    order_state.take_profit_price = 0.0;
  }

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = pending_price + direction_mult * level_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

}

bool GridShouldActivatePendingLevel(const SignalTypes direction,
                                    const GridOrderState &order_state)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(direction == BULLISH)
    return (entry_side_price <= order_state.last_pending_price && order_state.last_pending_price > 0.0);
  return (entry_side_price >= order_state.last_pending_price && order_state.last_pending_price > 0.0);
}

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const GridLevelPlan &level_plan,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  double direction_mult = GridResolveDirectionMultiplier(direction);
  double expected_entry = order_state.last_pending_price;
  string comment        = GridComposeLevelComment(signal_params, order_state);
  int level_index       = order_state.level_index;

  bool trade_sent = false;
  if(direction == BULLISH)
    trade_sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    trade_sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!trade_sent)
  {
    if(Enable_Logs)
    {
      PrintFormat("Grid order execution failed | dir=%s | level=%d | retcode=%d",
                  EnumToString(direction),
                  order_state.level_index,
                  (int)g_position.ResultRetcode());
    }
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = expected_entry;

  order_state.status           = GRID_ORDER_ACTIVE;
  order_state.entry_price      = fill_price;
  if(order_state.anchor_price <= 0.0)
    order_state.anchor_price = fill_price;
  order_state.position_comment = comment;
  order_state.last_action_time = TimeCurrent();
  order_state.resolved_distance_points = 0.0;

  ulong deal_ticket = (ulong)g_position.ResultDeal();
  order_state.position_ticket = 0;
  if(deal_ticket > 0)
  {
    datetime history_start = TimeCurrent() - 86400;
    if(history_start < 0)
      history_start = 0;
    HistorySelect(history_start, TimeCurrent());
    if(HistoryDealSelect(deal_ticket))
    {
      ulong position_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if(position_ticket > 0)
        order_state.position_ticket = position_ticket;
    }
  }

  if(point_size > 0.0 && order_state.anchor_price > 0.0)
  {
    double actual_distance_points = MathAbs(order_state.entry_price - order_state.anchor_price) / point_size;
    order_state.resolved_distance_points = actual_distance_points;

    if(level_index == 0 && actual_distance_points > 0.0 &&
       signal_params.grid_plan.resolved_base_distance_points <= 0.0)
    {
      double previous_base = signal_params.grid_plan.base_distance_points;
      if(previous_base > 0.0)
      {
        double scaling_factor = actual_distance_points / previous_base;
        GridScalePlannedLevels(signal_params, scaling_factor, 0);
      }
      signal_params.grid_plan.base_distance_points = actual_distance_points;
      signal_params.grid_plan.resolved_base_distance_points = actual_distance_points;
    }

    if(level_index >= 0 && level_index < ArraySize(signal_params.grid_plan.levels))
    {
      GridLevelPlan plan_update = signal_params.grid_plan.levels[level_index];
      double previous_baseline = plan_update.baseline_distance_points;
      double scaling_factor = 1.0;
      if(previous_baseline > 0.0)
        scaling_factor = actual_distance_points / previous_baseline;
      plan_update.distance_points = actual_distance_points;
      plan_update.baseline_distance_points = actual_distance_points;
      plan_update.resolved_distance_points = actual_distance_points;
      if(MathAbs(scaling_factor - 1.0) > 1e-6)
      {
        plan_update.pending_order_points     *= scaling_factor;
        plan_update.entry_offset_points      *= scaling_factor;
        plan_update.protective_stop_points   *= scaling_factor;
        plan_update.activation_points        *= scaling_factor;
        plan_update.activation_offset_points *= scaling_factor;
        plan_update.take_profit_points       *= scaling_factor;
        plan_update.final_take_profit_points *= scaling_factor;
        plan_update.trailing_points          *= scaling_factor;
      }
      signal_params.grid_plan.levels[level_index] = plan_update;
    }
  }

  double adverse_reference = GridCurrentPriceForDirection(direction, false);

  GridLevelPlan active_plan = level_plan;
  if(level_index >= 0 && level_index < ArraySize(signal_params.grid_plan.levels))
    active_plan = signal_params.grid_plan.levels[level_index];

  order_state.take_profit_price = fill_price + direction_mult * active_plan.take_profit_points * point_size;
  order_state.stop_loss_price   = 0.0;
  order_state.last_pending_price = 0.0;
  if(active_plan.trailing_points > 0.0)
  {
    double base_trailing = adverse_reference - direction_mult * active_plan.trailing_points * point_size;
    order_state.trailing_price = base_trailing;
  }
  else
  {
    order_state.trailing_price = 0.0;
  }
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;

  if(active_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = order_state.anchor_price + direction_mult * active_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

  if(order_state.next_level_price == 0.0)
    GridUpdateNextLevelPrice(direction, order_state, active_plan, point_size, adverse_reference);

  if(signal_params.entry_price <= 0.0)
    signal_params.entry_price = fill_price;
  if(signal_params.entry_time == 0)
    signal_params.entry_time = TimeCurrent();
  if(signal_params.ticket_id == "")
    signal_params.ticket_id = comment;
  if(signal_params.grid_stats.activation_time == 0)
    signal_params.grid_stats.activation_time = TimeCurrent();

  signal_params.grid_orders[level_index] = order_state;
  GridScheduleNextLevel(signal_params, level_index + 1);
  GridRecalculateRangeMetrics(signal_params, point_size);
  order_state = signal_params.grid_orders[level_index];

  GridLogEvent("LEVEL_ACTIVE", signal_params, order_state, active_plan);
  return true;
}

void GridFinalizeLevel(const SignalTypes direction,
                       GridOrderState &order_state,
                       const double point_size,
                       const double close_price_override)
{
  double close_price = close_price_override;
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  double entry_price = order_state.entry_price;
  if(point_size <= 0.0 || entry_price <= 0.0)
  {
    order_state.realized_points = 0.0;
    order_state.status          = GRID_ORDER_COMPLETED;
    order_state.last_action_time = TimeCurrent();
    order_state.position_ticket  = 0;
    order_state.position_comment = "";
    order_state.resolved_distance_points = 0.0;
    order_state.grid_range_percent = -1.0;
    return;
  }

  double direction_mult = GridResolveDirectionMultiplier(direction);
  double point_delta    = (close_price - entry_price) / point_size * direction_mult;

  order_state.realized_points = point_delta;
  order_state.status          = GRID_ORDER_COMPLETED;
  order_state.last_action_time = TimeCurrent();
  order_state.position_ticket  = 0;
  order_state.position_comment = "";
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.final_take_profit_price = 0.0;
  order_state.next_level_price        = 0.0;
  order_state.last_pending_price      = 0.0;
  order_state.resolved_distance_points = 0.0;
  order_state.grid_range_percent = -1.0;
}

bool GridCloseBrokerPosition(GridOrderState &order_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(order_state.position_ticket > 0)
  {
    if(!PositionSelectByTicket(order_state.position_ticket))
      order_state.position_ticket = 0;
  }

  if(order_state.position_ticket <= 0)
  {
    int total_positions = PositionsTotal();
    for(int i = 0; i < total_positions; i++)
    {
      if(PositionGetTicket(i) == 0)
        continue;

      if((int)PositionGetInteger(POSITION_MAGIC) != g_magic_number)
        continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
        continue;

      if(order_state.position_comment != "")
      {
        string comment = PositionGetString(POSITION_COMMENT);
        if(comment != order_state.position_comment)
          continue;
      }

      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(direction == BULLISH && pos_type != POSITION_TYPE_BUY)
        continue;
      if(direction == BEARISH && pos_type != POSITION_TYPE_SELL)
        continue;

      order_state.position_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      break;
    }
  }

  if(order_state.position_ticket <= 0)
    return false;

  if(!PositionSelectByTicket(order_state.position_ticket))
    return false;

  if(!g_position.PositionClose(order_state.position_ticket))
  {
    if(Enable_Logs)
    {
      PrintFormat("PositionClose failed | ticket=%I64u | ret=%d",
                  order_state.position_ticket,
                  (int)g_position.ResultRetcode());
    }
    return false;
  }

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.position_ticket  = 0;
  order_state.position_comment = "";
  return true;
}

void GridCloseAllLevels(SignalParams &signal_params,
                        const double point_size)
{
  SignalTypes direction = signal_params.signal_type;
  int levels_total = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    GridLevelPlan  plan  = signal_params.grid_plan.levels[i];

    if(state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = 0.0;
      GridCloseBrokerPosition(state, direction, close_price);
      GridFinalizeLevel(direction, state, point_size, close_price);

      if(state.realized_points > 0.0)
        signal_params.grid_stats.total_positive_points += state.realized_points;
      else if(state.realized_points < 0.0)
        signal_params.grid_stats.total_negative_points += MathAbs(state.realized_points);

      signal_params.grid_stats.completed_levels++;
      GridLogEvent("LEVEL_CLOSE_ALL", signal_params, state, plan);
    }
    else if(state.status == GRID_ORDER_PENDING || state.status == GRID_ORDER_WAITING)
    {
      state.status = GRID_ORDER_COMPLETED;
      state.last_action_time = TimeCurrent();
      state.resolved_distance_points = 0.0;
      state.grid_range_percent = -1.0;
      GridLogEvent("LEVEL_CANCELLED", signal_params, state, plan);
    }

    state.final_take_profit_price = 0.0;
    state.next_level_price        = 0.0;
    state.last_pending_price      = 0.0;
    signal_params.grid_orders[i] = state;
  }

  GridRecalculateRangeMetrics(signal_params, point_size);
}

// ── Public API ─────────────────────────────────────────────────────

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  signal_params.grid_stats = GridTelemetryStats();
  signal_params.grid_plan.resolved_base_distance_points = 0.0;
  signal_params.grid_plan.range_high_price = 0.0;
  signal_params.grid_plan.range_low_price  = 0.0;

  ArrayResize(signal_params.grid_orders, 0);
  int total_levels = ArraySize(signal_params.grid_plan.levels);
  if(total_levels <= 0)
    return;

  GridEnsureOrderState(signal_params, 0);
  GridOrderState initial_state = signal_params.grid_orders[0];
  GridResetOrderStateForWaiting(initial_state, signal_params.grid_plan.levels[0]);
  signal_params.grid_orders[0] = initial_state;
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  double point_size     = GridResolvePointSize();
  SignalTypes direction = signal_params.signal_type;
  double direction_mult = GridResolveDirectionMultiplier(direction);
  datetime now_time     = TimeCurrent();

  signal_params.grid_stats.last_update_time = now_time;

  bool request_close_all = false;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = 0; i < levels_total; i++)
  {
    if(i >= ArraySize(signal_params.grid_orders))
      continue;

    GridLevelPlan level_plan = signal_params.grid_plan.levels[i];
    GridOrderState order_state = signal_params.grid_orders[i];

    if(order_state.status == GRID_ORDER_INACTIVE)
    {
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, level_plan.lot_size);
    if(normalized_volume <= 0.0)
    {
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_WAITING)
    {
      if(i == 0)
      {
        if(GridGuardrailsAllowOrder(normalized_volume))
        {
          if(signal_params.grid_plan.base_anchor_price > 0.0)
            order_state.anchor_price = signal_params.grid_plan.base_anchor_price;
          order_state.resolved_distance_points = level_plan.distance_points;
          GridInitializePendingLevel(direction, order_state, level_plan, point_size);
          GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
        }
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      if(i - 1 >= ArraySize(signal_params.grid_orders))
      {
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      GridOrderState previous_state = signal_params.grid_orders[i - 1];
      bool previous_ready = (previous_state.status == GRID_ORDER_ACTIVE);
      if(previous_ready && previous_state.entry_price > 0.0)
      {
        double current_price = GridCurrentPriceForDirection(direction, false);
        double adverse_points = GridPointsBetween(direction,
                                                  previous_state.entry_price,
                                                  current_price,
                                                  point_size);
        if(adverse_points >= (level_plan.activation_points - 1e-6))
        {
          if(GridGuardrailsAllowOrder(normalized_volume))
          {
            double previous_distance_points = previous_state.resolved_distance_points;
            GridLevelPlan previous_plan = signal_params.grid_plan.levels[i - 1];
            if(previous_distance_points <= 0.0)
              previous_distance_points = previous_plan.distance_points;

            double base_anchor = previous_state.entry_price - direction_mult * previous_distance_points * point_size;
            if(previous_state.entry_price <= 0.0)
              base_anchor = previous_state.anchor_price - direction_mult * previous_distance_points * point_size;
            if(base_anchor <= 0.0)
              base_anchor = previous_state.anchor_price;

            order_state.anchor_price = base_anchor;
            order_state.resolved_distance_points = level_plan.distance_points;
            GridInitializePendingLevel(direction, order_state, level_plan, point_size);
            GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
            previous_state.next_level_price        = order_state.last_pending_price;
            previous_state.take_profit_price       = 0.0;
            previous_state.final_take_profit_price = 0.0;
          }
        }
      }

      signal_params.grid_orders[i - 1] = previous_state;
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {
      GridUpdatePendingLevel(direction, order_state, level_plan, point_size);
      order_state.last_action_time = now_time;

      if(GridGuardrailsAllowOrder(normalized_volume) &&
         GridShouldActivatePendingLevel(direction, order_state))
      {
        if(GridExecuteLevelTrade(signal_params, order_state, level_plan, point_size, normalized_volume))
        {
          signal_params.signal_state = OPENED;
          GridLevelPlan resolved_plan = level_plan;
          if(i < ArraySize(signal_params.grid_plan.levels))
            resolved_plan = signal_params.grid_plan.levels[i];
          GridLogEvent("LEVEL_FILLED", signal_params, order_state, resolved_plan);
        }
      }

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = GridCurrentPriceForDirection(direction, false);

      if(level_plan.final_take_profit_points > 0.0 && !order_state.tp_reached)
      {
        double final_price = order_state.anchor_price + direction_mult * level_plan.final_take_profit_points * point_size;
        order_state.final_take_profit_price = final_price;
        bool final_hit = false;
        if(direction == BULLISH)
        {
          if(final_price > order_state.entry_price)
            final_hit = (close_price >= final_price);
        }
        else
        {
          if(final_price < order_state.entry_price || order_state.entry_price <= 0.0)
            final_hit = (close_price <= final_price);
        }

        if(final_hit)
        {
          GridLogEvent("LEVEL_FINAL_TP", signal_params, order_state, level_plan);
          request_close_all = true;
        }
      }
      else
      {
        if(order_state.tp_reached)
          order_state.final_take_profit_price = 0.0;
      }

      if(level_plan.take_profit_points > 0.0 && !order_state.tp_reached)
      {
        double tp_price = order_state.entry_price + direction_mult * level_plan.take_profit_points * point_size;
        order_state.take_profit_price = tp_price;
        if((direction == BULLISH && close_price >= tp_price) ||
           (direction == BEARISH && close_price <= tp_price))
        {
          order_state.tp_reached = true;
          if(level_plan.trailing_points > 0.0)
            order_state.is_trailing_active = true;
          order_state.take_profit_price = 0.0;
        }
      }

      if(order_state.is_trailing_active && level_plan.trailing_points > 0.0)
      {
        double candidate_trailing = close_price - direction_mult * level_plan.trailing_points * point_size;

        if(order_state.trailing_price == 0.0)
          order_state.trailing_price = candidate_trailing;

        if(direction == BULLISH)
        {
          if(candidate_trailing > order_state.trailing_price)
            order_state.trailing_price = candidate_trailing;
          order_state.stop_loss_price = order_state.trailing_price;
          if(close_price <= order_state.trailing_price)
            request_close_all = true;
        }
        else
        {
          if(candidate_trailing < order_state.trailing_price || order_state.trailing_price == 0.0)
            order_state.trailing_price = candidate_trailing;
          order_state.stop_loss_price = order_state.trailing_price;
          if(close_price >= order_state.trailing_price)
            request_close_all = true;
        }
      }
      else
      {
        order_state.stop_loss_price = 0.0;
      }

      order_state.last_action_time = now_time;

      if(order_state.tp_reached)
        order_state.final_take_profit_price = 0.0;

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    signal_params.grid_orders[i] = order_state;
  }

  if(request_close_all)
  {
    GridCloseAllLevels(signal_params, point_size);
    signal_params.signal_state = CLOSED;
  }

  if(point_size > 0.0 && signal_params.entry_price > 0.0)
  {
    double close_price = GridCurrentPriceForDirection(direction, false);
    double entry_price = signal_params.entry_price;
    double price_delta = (direction == BULLISH)
                         ? (close_price - entry_price)
                         : (entry_price - close_price);
    double points_delta = price_delta / point_size;
    if(points_delta > signal_params.grid_stats.max_favorable_points)
      signal_params.grid_stats.max_favorable_points = points_delta;
    if(points_delta < 0.0 && MathAbs(points_delta) > signal_params.grid_stats.max_adverse_points)
      signal_params.grid_stats.max_adverse_points = MathAbs(points_delta);
  }
}

bool IsGridSignalComplete(const SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return true;

  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_PENDING ||
       state.status == GRID_ORDER_ACTIVE)
      return false;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
