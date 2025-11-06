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

bool GridGuardrailsAllowOrder(const double normalized_volume,
                              string &reason)
{
  reason = "";
  if(g_points_spread > Max_Spread)
  {
    reason = StringFormat("spread=%.1f>%.1f",
                          g_points_spread,
                          Max_Spread);
    return false;
  }

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

  if(free_margin < required_margin)
  {
    reason = StringFormat("margin=%.2f<%.2f",
                          free_margin,
                          required_margin);
    return false;
  }

  return true;
}

bool GridGuardrailsAllowOrder(const double normalized_volume)
{
  string reason = "";
  return GridGuardrailsAllowOrder(normalized_volume, reason);
}

void GridAppendReason(string &target,
                      const string token)
{
  if(token == "")
    return;
  if(target == "")
  {
    target = token;
    return;
  }
  target = target + ";" + token;
}

double GridSnapshotNextLevelPrice(const SignalParams &signal_params,
                                  const GridOrderState &order_state,
                                  const double point_size)
{
  int next_level_index = order_state.level_index + 1;
  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);
  double effective_point_size = point_size;
  if(effective_point_size <= 0.0)
    effective_point_size = GridResolvePointSize();

  double candidate_price = 0.0;

  if(next_level_index < ArraySize(signal_params.grid_plan.levels))
  {
    GridLevelPlan next_plan = signal_params.grid_plan.levels[next_level_index];
    candidate_price = next_plan.next_resolved_price;
    if(candidate_price <= 0.0)
      candidate_price = next_plan.next_blueprint_price;
    if(candidate_price <= 0.0)
    {
      double baseline_anchor = GridPlanResolveBaselineAnchorPrice(signal_params, next_plan);
      double distance_points = next_plan.distance_points;
      if(distance_points <= 0.0)
        distance_points = next_plan.baseline_distance_points;
      if(distance_points <= 0.0)
        distance_points = signal_params.grid_plan.base_distance_points;

      if(baseline_anchor > 0.0 && distance_points > 0.0 && effective_point_size > 0.0)
        candidate_price = baseline_anchor + direction_mult * distance_points * effective_point_size;
    }
  }
  else
  {
    double base_distance = signal_params.grid_plan.base_distance_points;
    double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
    double distance_points = base_distance * MathPow(exponential_multiplier, next_level_index);
    if(distance_points <= 0.0)
      distance_points = base_distance;

    double baseline_anchor = signal_params.grid_plan.base_anchor_price;
    if(baseline_anchor <= 0.0)
      baseline_anchor = order_state.anchor_price;

    if(baseline_anchor > 0.0 && distance_points > 0.0 && effective_point_size > 0.0)
      candidate_price = baseline_anchor + direction_mult * distance_points * effective_point_size;
  }

  return candidate_price;
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
  double entry_side_price_current = GridCurrentPriceForDirection(signal_params.signal_type, true);
  double entry_side_price_trailing = order_state.entry_side_price_trailing;
  if(entry_side_price_trailing <= 0.0)
    entry_side_price_trailing = signal_params.grid_plan.entry_side_price_initial;
  if(entry_side_price_current <= 0.0)
    entry_side_price_current = entry_side_price_trailing;

  double anchor_plan_price = level_plan.anchor_price;
  if(anchor_plan_price <= 0.0)
    anchor_plan_price = order_state.anchor_price;

  double point_size = GridResolvePointSize();
  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);
  double planned_pending_price = 0.0;
  double pending_points = GridPlanResolvePendingPoints(level_plan);
  if(level_plan.next_blueprint_price > 0.0)
    planned_pending_price = level_plan.next_blueprint_price;
  else if(anchor_plan_price > 0.0 && point_size > 0.0)
  {
    planned_pending_price = anchor_plan_price + direction_mult * pending_points * point_size;
  }

  double activation_gap_pts = level_plan.activation_offset_points;
  if(activation_gap_pts <= 0.0)
    activation_gap_pts = signal_params.grid_plan.entry_side_raw_gap_points;

  double entry_offset_pts = level_plan.entry_offset_points;
  if(entry_offset_pts <= 0.0)
    entry_offset_pts = signal_params.grid_plan.entry_side_offset_pts_initial;

  double protective_offset_pts = level_plan.protective_stop_points;
  if(protective_offset_pts <= 0.0)
    protective_offset_pts = GridPlanResolveProtectiveOffset(signal_params, level_plan);

  double next_resolved_price = level_plan.next_resolved_price;
  if(next_resolved_price <= 0.0)
    next_resolved_price = order_state.last_pending_price;
  string next_side = level_plan.next_price_side;
  if(next_side == "")
    next_side = (signal_params.signal_type == BULLISH) ? "ASK" : "BID";
  string clamp_reason = level_plan.next_price_clamp_reason;
  if(clamp_reason == "")
    clamp_reason = "-";

  double alias_next = level_plan.next_resolved_price;
  if(alias_next <= 0.0)
    alias_next = order_state.next_level_price;
  if(alias_next <= 0.0)
    alias_next = planned_pending_price;

  double tp_reference_points = order_state.tp_reference_points;
  if(tp_reference_points <= 0.0)
  {
    double tp_reference_price = alias_next;
    if(tp_reference_price <= 0.0)
      tp_reference_price = next_resolved_price;
    if(tp_reference_price <= 0.0)
      tp_reference_price = level_plan.next_blueprint_price;
    if(tp_reference_price <= 0.0)
      tp_reference_price = order_state.next_level_price;
    if(tp_reference_price <= 0.0)
      tp_reference_price = planned_pending_price;
    if(order_state.entry_price > 0.0 && tp_reference_price > 0.0 && point_size > 0.0)
      tp_reference_points = MathAbs(order_state.entry_price - tp_reference_price) / point_size;
  }

  string message = StringFormat("dir=%s|level=%d|status=%s|clamped_pending_price=%.5f|planned_pending_price=%.5f|protect_price=%.5f|entry=%.5f|tp=%.5f|next=%.5f|anchor=%.5f|anchor_plan=%.5f|dist=%.1f|pct=%.2f|style=%s|entry_side_price_curr=%.5f|entry_side_price_trail=%.5f|activation_gap_pts=%.2f|protective_pts=%.2f|tp_reference_pts=%.2f|entry_offset_pts=%.2f|next_blueprint=%.5f|next_resolved=%.5f|next_side=%s|next_clamp=%s",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                order_state.last_pending_price,
                                planned_pending_price,
                                order_state.stop_loss_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                alias_next,
                                order_state.anchor_price,
                                anchor_plan_price,
                                order_state.resolved_distance_points,
                                order_state.grid_range_percent,
                                EnumToString(level_plan.entry_style),
                                entry_side_price_current,
                                entry_side_price_trailing,
                                activation_gap_pts,
                                protective_offset_pts,
                                tp_reference_points,
                                entry_offset_pts,
                                planned_pending_price,
                                next_resolved_price,
                                next_side,
                                clamp_reason);
  AppendTimestampedLog("query_debug.txt", label, message);
}

void GridLogPendingTrail(const SignalParams &signal_params,
                         const GridOrderState &order_state,
                         const double previous_anchor,
                         const double previous_pending,
                         const double new_anchor,
                         const double new_pending,
                         const double point_size)
{
  if(!Enable_File_Logs)
    return;

  double anchor_delta = new_anchor - previous_anchor;
  double pending_delta = new_pending - previous_pending;
  double delta_points = 0.0;
  if(point_size > 0.0)
    delta_points = pending_delta / point_size;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|anchor_prev=%.5f|anchor_new=%.5f|pending_prev=%.5f|pending_new=%.5f|delta_pts=%.2f",
                                direction,
                                order_state.level_index,
                                previous_anchor,
                                new_anchor,
                                previous_pending,
                                new_pending,
                                delta_points);
  AppendTimestampedLog("query_debug.txt", "LEVEL_PENDING_TRAIL", message);
}

bool GridApplyExecutionPriceAdjustment(SignalParams &signal_params,
                                       GridOrderState &order_state,
                                       GridLevelPlan &level_plan,
                                       const SignalTypes direction,
                                       const double point_size,
                                       const double execution_price)
{
  if(execution_price <= 0.0)
    return false;
  if(order_state.last_pending_price <= 0.0)
    return false;

  double tick_tolerance = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                                   point_size);
  if(tick_tolerance <= 0.0)
    tick_tolerance = 1e-9;

  double adjusted_price = order_state.last_pending_price;
  bool requires_adjustment = false;
  if(direction == BULLISH)
  {
    if(execution_price > order_state.last_pending_price + (tick_tolerance + 1e-9))
    {
      adjusted_price = execution_price;
      requires_adjustment = true;
    }
  }
  else if(direction == BEARISH)
  {
    if(execution_price < order_state.last_pending_price - (tick_tolerance + 1e-9))
    {
      adjusted_price = execution_price;
      requires_adjustment = true;
    }
  }

  if(!requires_adjustment)
    return false;

  double previous_pending = order_state.last_pending_price;
  order_state.last_pending_price = adjusted_price;

  level_plan.next_resolved_price = adjusted_price;
  if(level_plan.next_blueprint_price <= 0.0)
    level_plan.next_blueprint_price = adjusted_price;
  GridAppendReason(level_plan.next_price_clamp_reason, "execution_adjust");
  signal_params.grid_plan.levels[order_state.level_index] = level_plan;

  int previous_index = order_state.level_index - 1;
  GridLevelPlan previous_plan = GridLevelPlan();
  GridOrderState previous_state = GridOrderState();
  bool has_previous_plan = false;
  if(previous_index >= 0)
  {
    if(previous_index < ArraySize(signal_params.grid_orders))
      previous_state = signal_params.grid_orders[previous_index];
    if(previous_index < ArraySize(signal_params.grid_plan.levels))
    {
      previous_plan = signal_params.grid_plan.levels[previous_index];
      has_previous_plan = true;
    }

    double previous_next_price = previous_state.next_level_price;
    previous_state.next_level_price = adjusted_price;
    if(previous_index < ArraySize(signal_params.grid_orders))
      signal_params.grid_orders[previous_index] = previous_state;

    if(has_previous_plan)
    {
      previous_plan.next_resolved_price = adjusted_price;
      if(previous_plan.next_blueprint_price <= 0.0)
        previous_plan.next_blueprint_price = adjusted_price;
      GridAppendReason(previous_plan.next_price_clamp_reason, "execution_adjust");
      signal_params.grid_plan.levels[previous_index] = previous_plan;
    }

    double change_threshold = tick_tolerance;
    if(change_threshold <= 0.0)
      change_threshold = point_size;
    if(change_threshold <= 0.0)
      change_threshold = 1e-6;

    bool emit_update = false;
    if(adjusted_price > 0.0)
    {
      if(previous_next_price <= 0.0 ||
         MathAbs(adjusted_price - previous_next_price) >= (change_threshold - 1e-9))
        emit_update = true;
    }
    else if(previous_next_price > 0.0)
    {
      emit_update = true;
    }

    if(emit_update && has_previous_plan)
      GridLogEvent("LEVEL_NEXT_UPDATE", signal_params, previous_state, previous_plan);
  }

  if(Enable_File_Logs)
  {
    string direction_name = (direction == BULLISH) ? "BULLISH" : "BEARISH";
    double delta_points = 0.0;
    if(point_size > 0.0)
      delta_points = (adjusted_price - previous_pending) / point_size;
    string message = StringFormat("dir=%s|level=%d|prev_pending=%.5f|execution_price=%.5f|adjusted_pending=%.5f|delta_pts=%.2f",
                                  direction_name,
                                  order_state.level_index,
                                  previous_pending,
                                  execution_price,
                                  adjusted_price,
                                  delta_points);
    AppendTimestampedLog("query_debug.txt", "PENDING_EXEC_ADJUST", message);
  }

  return true;
}

void GridLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const string reason)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|status=%s|reason=%s",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                reason);
  AppendTimestampedLog("query_debug.txt", label, message);
}

void GridLogTrailingEvent(const string label,
                          const SignalParams &signal_params,
                          const GridOrderState &order_state,
                          const double trailing_price,
                          const double offset_points,
                          const string basis,
                          const string side,
                          const string reason)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double tp_reference_pts = order_state.tp_reference_points;
  string message = StringFormat("dir=%s|level=%d|price=%.5f|offset_pts=%.2f|tp_reference_pts=%.2f|basis=%s|side=%s|reason=%s",
                                direction,
                                order_state.level_index,
                                trailing_price,
                                offset_points,
                                tp_reference_pts,
                                (basis == "") ? "-" : basis,
                                (side == "") ? "-" : side,
                                (reason == "") ? "-" : reason);
  AppendTimestampedLog("query_debug.txt", label, message);
}

void GridLogWaitingReady(const SignalParams &signal_params,
                         const GridLevelPlan &level_plan,
                         const double adverse_points)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|adverse=%.2f|activation=%.2f|style=%s",
                                direction,
                                level_plan.level_index,
                                adverse_points,
                                level_plan.activation_points,
                                EnumToString(level_plan.entry_style));
  AppendTimestampedLog("query_debug.txt", "WAITING_READY", message);
}

double GridRecomputeTrailingAnchor(const SignalTypes direction,
                                   const GridLevelPlan &level_plan,
                                   const double current_anchor,
                                   const double point_size)
{
  double resolved_anchor = current_anchor;
  if(resolved_anchor <= 0.0)
    resolved_anchor = level_plan.anchor_price;

  if(point_size <= 0.0)
    return resolved_anchor;

  double direction_mult = GridResolveDirectionMultiplier(direction);
  double adverse_price  = GridCurrentPriceForDirection(direction, false);
  double candidate_anchor = adverse_price - direction_mult * level_plan.distance_points * point_size;

  if(direction == BULLISH)
  {
    if(resolved_anchor <= 0.0 || candidate_anchor < resolved_anchor)
      resolved_anchor = candidate_anchor;
  }
  else if(direction == BEARISH)
  {
    if(resolved_anchor <= 0.0 || candidate_anchor > resolved_anchor)
      resolved_anchor = candidate_anchor;
  }

  return resolved_anchor;
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
    plan.next_blueprint_price      = 0.0;
    plan.next_resolved_price       = 0.0;
    plan.next_price_side           = "";
    plan.next_price_clamp_reason   = "";
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

double GridResolveTrailingStopPrice(const SignalParams &signal_params,
                                    const GridOrderState &order_state,
                                    const GridLevelPlan &level_plan,
                                    const SignalTypes direction,
                                    const double point_size,
                                    const double close_price,
                                    double &resolved_offset_points,
                                    string &basis_out,
                                    string &reason_out)
{
  resolved_offset_points = 0.0;
  basis_out = "";
  reason_out = "";

  double trailing_percent = MathMax(Grid_Trailing_TP_Percent, 0.0);
  if(trailing_percent <= 0.0)
    return 0.0;

  double reference_points = order_state.tp_reference_points;
  if(reference_points <= 0.0 && order_state.entry_price > 0.0 && point_size > 0.0)
  {
    double reference_price = order_state.take_profit_price;
    if(reference_price <= 0.0)
      reference_price = level_plan.next_resolved_price;
    if(reference_price <= 0.0)
      reference_price = level_plan.next_blueprint_price;
    if(reference_price <= 0.0)
      reference_price = order_state.next_level_price;
    if(reference_price > 0.0)
      reference_points = MathAbs(order_state.entry_price - reference_price) / point_size;
  }

  if(reference_points <= 0.0)
    return 0.0;

  double offset_fraction = 1.0 - (trailing_percent / 100.0);
  if(offset_fraction < 0.0)
    offset_fraction = 0.0;

  resolved_offset_points = reference_points * offset_fraction;
  if(resolved_offset_points <= 0.0)
    resolved_offset_points = reference_points;

  basis_out = "TP";
  GridAppendReason(reason_out, "tp_reference");
  if(trailing_percent > 0.0)
    GridAppendReason(reason_out, "tp_percent");

  double requested_offset = resolved_offset_points;
  resolved_offset_points = EnforceBrokerDistance(g_symbol_constraints, resolved_offset_points);
  if(resolved_offset_points > requested_offset + 1e-9)
    GridAppendReason(reason_out, "broker_min");

  if(resolved_offset_points <= 0.0 || point_size <= 0.0 || close_price <= 0.0)
    return 0.0;

  double direction_mult = GridResolveDirectionMultiplier(direction);
  double requested_price = close_price - direction_mult * resolved_offset_points * point_size;
  double rounded_price = requested_price;

  double effective_tick = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                                   g_symbol_constraints.point_size);
  if(effective_tick > 0.0 && requested_price > 0.0)
  {
    double ticks = requested_price / effective_tick;
    if(direction == BULLISH)
      rounded_price = MathFloor(ticks + 1e-9) * effective_tick;
    else
      rounded_price = MathCeil(ticks - 1e-9) * effective_tick;
    if(MathAbs(rounded_price - requested_price) > 1e-9)
      GridAppendReason(reason_out, "tick_round");
  }

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;
  double trailing_price = NormalizeDouble(rounded_price, digits);

  return trailing_price;
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
  return GridPlanResolvePendingPoints(level_plan);
}

void GridInitializePendingLevel(SignalParams &signal_params,
                                const SignalTypes direction,
                                GridOrderState &order_state,
                                const double point_size)
{
  int level_index = order_state.level_index;
  if(level_index < 0)
    return;
  if(level_index >= ArraySize(signal_params.grid_plan.levels))
    return;

  double resolved_point_size = point_size;
  if(resolved_point_size <= 0.0)
    resolved_point_size = GridResolvePointSize();

  GridLevelPlan level_plan = signal_params.grid_plan.levels[level_index];
  double direction_mult = GridResolveDirectionMultiplier(direction);

  double anchor_price = order_state.anchor_price;
  if(anchor_price <= 0.0)
    anchor_price = level_plan.anchor_price;
  if(anchor_price <= 0.0)
  {
    double entry_price_ref = GridCurrentPriceForDirection(direction, true);
    anchor_price = entry_price_ref - direction_mult * level_plan.distance_points * resolved_point_size;
  }

  order_state.anchor_price       = anchor_price;
  order_state.status             = GRID_ORDER_PENDING;
  order_state.last_action_time   = TimeCurrent();

  order_state.stop_loss_price      = 0.0;
  order_state.last_pending_price   = 0.0;
  order_state.take_profit_price    = 0.0;
  order_state.final_take_profit_price = 0.0;
  order_state.trailing_price       = 0.0;
  order_state.is_trailing_active   = false;
  order_state.tp_reached           = false;
  order_state.tp_reference_points  = 0.0;
  order_state.resolved_distance_points = level_plan.distance_points;
  order_state.grid_range_percent   = -1.0;
  order_state.entry_price          = 0.0;
  order_state.position_ticket      = 0;
  order_state.position_comment     = "";
  order_state.next_level_price     = 0.0;
  if(order_state.entry_side_price_trailing <= 0.0)
    order_state.entry_side_price_trailing = signal_params.grid_plan.entry_side_price_initial;

  GridUpdatePendingLevel(signal_params,
                         direction,
                         order_state,
                         resolved_point_size);
}

void GridUpdatePendingLevel(SignalParams &signal_params,
                            const SignalTypes direction,
                            GridOrderState &order_state,
                            const double point_size)
{
  int level_index = order_state.level_index;
  if(level_index < 0)
    return;
  if(level_index >= ArraySize(signal_params.grid_plan.levels))
    return;

  double resolved_point_size = point_size;
  if(resolved_point_size <= 0.0)
    resolved_point_size = GridResolvePointSize();

  GridLevelPlan level_plan = signal_params.grid_plan.levels[level_index];
  double direction_mult = GridResolveDirectionMultiplier(direction);

  double previous_anchor  = order_state.anchor_price;
  double previous_pending = order_state.last_pending_price;

  double resolved_anchor = GridRecomputeTrailingAnchor(direction,
                                                       level_plan,
                                                       previous_anchor,
                                                       resolved_point_size);

  if(resolved_anchor <= 0.0)
    resolved_anchor = previous_anchor;
  if(resolved_anchor <= 0.0)
    resolved_anchor = level_plan.anchor_price;
  if(resolved_anchor <= 0.0)
  {
    double entry_price_ref = GridCurrentPriceForDirection(direction, true);
    resolved_anchor = entry_price_ref - direction_mult * level_plan.distance_points * resolved_point_size;
  }

  double pending_points = GridPlanResolvePendingPoints(level_plan);
  if(pending_points > 0.0)
    pending_points = EnforceBrokerDistance(g_symbol_constraints, pending_points);
  if(pending_points <= 0.0)
    pending_points = level_plan.distance_points;

  double entry_side_price_current = GridCurrentPriceForDirection(direction, true);
  double tracked_entry_side_price = order_state.entry_side_price_trailing;
  if(tracked_entry_side_price <= 0.0)
    tracked_entry_side_price = signal_params.grid_plan.entry_side_price_initial;

  if(entry_side_price_current > 0.0)
  {
    if(direction == BULLISH)
    {
      if(tracked_entry_side_price <= 0.0 || entry_side_price_current < tracked_entry_side_price)
        tracked_entry_side_price = entry_side_price_current;
    }
    else if(direction == BEARISH)
    {
      if(tracked_entry_side_price <= 0.0 || entry_side_price_current > tracked_entry_side_price)
        tracked_entry_side_price = entry_side_price_current;
    }
  }

  order_state.entry_side_price_trailing = tracked_entry_side_price;

  double protective_offset_pts = 0.0;
  double activation_gap_pts = 0.0;
  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
  {
    double entry_reference_price = tracked_entry_side_price;
    if(entry_reference_price <= 0.0)
      entry_reference_price = entry_side_price_current;
    if(entry_reference_price <= 0.0)
      entry_reference_price = signal_params.grid_plan.entry_side_price_initial;

    double baseline_distance_points = level_plan.distance_points;
    if(baseline_distance_points <= 0.0)
      baseline_distance_points = level_plan.baseline_distance_points;
    if(baseline_distance_points <= 0.0)
      baseline_distance_points = signal_params.grid_plan.base_distance_points;

    double baseline_anchor_price = GridPlanResolveBaselineAnchorPrice(signal_params,
                                                                      level_plan);
    activation_gap_pts = GridPlanResolveActivationGapPoints(entry_reference_price,
                                                            baseline_anchor_price,
                                                            resolved_point_size,
                                                            baseline_distance_points);
    double unified_percent = GridResolveUnifiedStopPercent();
    protective_offset_pts = GridPlanComputeProtectiveOffset(unified_percent,
                                                            activation_gap_pts);
    if(protective_offset_pts > 0.0)
      protective_offset_pts = EnforceBrokerDistance(g_symbol_constraints, protective_offset_pts);
  }

  if(level_plan.entry_style != GRID_ENTRY_STYLE_STOP)
    protective_offset_pts = 0.0;

  double baseline_distance_points = level_plan.distance_points;
  if(level_plan.resolved_distance_points > 0.0)
    baseline_distance_points = level_plan.resolved_distance_points;

  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    pending_points = baseline_distance_points + protective_offset_pts;
  else if(level_plan.entry_style == GRID_ENTRY_STYLE_LIMIT && protective_offset_pts > 0.0)
  {
    double limit_candidate = baseline_distance_points - protective_offset_pts;
    if(limit_candidate > 0.0)
      pending_points = limit_candidate;
    else
      pending_points = baseline_distance_points;
  }
  else
  {
    pending_points = baseline_distance_points;
  }

  if(pending_points > 0.0)
    pending_points = EnforceBrokerDistance(g_symbol_constraints, pending_points);
  if(pending_points <= 0.0)
    pending_points = baseline_distance_points;

  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    level_plan.entry_offset_points = protective_offset_pts;
  else
    level_plan.entry_offset_points = 0.0;
  level_plan.protective_stop_points = level_plan.entry_offset_points;
  level_plan.pending_order_points = pending_points;
  level_plan.activation_offset_points = activation_gap_pts;

  double entry_reference_price = tracked_entry_side_price;
  if(entry_reference_price <= 0.0)
    entry_reference_price = entry_side_price_current;

  double ask_value = g_ask;
  double bid_value = g_bid;
  if(direction == BULLISH && entry_reference_price > 0.0)
    ask_value = entry_reference_price;
  if(direction == BEARISH && entry_reference_price > 0.0)
    bid_value = entry_reference_price;

  NextPriceResolution pricing = ResolveNextPrice(resolved_anchor,
                                                 level_plan.level_index,
                                                 (direction == BULLISH),
                                                 protective_offset_pts,
                                                 pending_points,
                                                 g_symbol_constraints.tick_size,
                                                 g_points_spread,
                                                 ask_value,
                                                 bid_value,
                                                 previous_pending);

  double pending_price = pricing.resolved_next;
  double blueprint_price = pricing.blueprint_next;
  if(blueprint_price <= 0.0 && resolved_anchor > 0.0 && resolved_point_size > 0.0)
    blueprint_price = resolved_anchor + direction_mult * pending_points * resolved_point_size;
  if(pending_price <= 0.0 && resolved_anchor > 0.0 && resolved_point_size > 0.0)
    pending_price = resolved_anchor + direction_mult * pending_points * resolved_point_size;

  if(previous_pending > 0.0 && pending_price > 0.0)
  {
    double tick_tolerance = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                                     resolved_point_size);
    if(tick_tolerance <= 0.0)
      tick_tolerance = 1e-9;

    if(direction == BULLISH)
    {
      if(pending_price > previous_pending)
      {
        if(pending_price - previous_pending > (tick_tolerance + 1e-9))
          GridAppendReason(pricing.clamp_reason, "monotonic");
        pending_price = previous_pending;
      }
    }
    else if(direction == BEARISH)
    {
      if(pending_price < previous_pending)
      {
        if(previous_pending - pending_price > (tick_tolerance + 1e-9))
          GridAppendReason(pricing.clamp_reason, "monotonic");
        pending_price = previous_pending;
      }
    }
  }

  pricing.resolved_next = pending_price;

  order_state.anchor_price       = resolved_anchor;
  order_state.stop_loss_price    = 0.0;
  order_state.last_pending_price = pending_price;
  order_state.next_level_price   = 0.0;

  double expected_entry = pending_price;

  if(level_plan.take_profit_points > 0.0)
    order_state.take_profit_price = expected_entry + direction_mult * level_plan.take_profit_points * resolved_point_size;
  else
    order_state.take_profit_price = 0.0;

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = expected_entry + direction_mult * level_plan.final_take_profit_points * resolved_point_size;
  else
    order_state.final_take_profit_price = 0.0;

  if(previous_pending > 0.0 &&
     pending_price > 0.0 &&
     MathAbs(pending_price - previous_pending) > (resolved_point_size * 0.1))
  {
    GridLogPendingTrail(signal_params,
                        order_state,
                        previous_anchor,
                        previous_pending,
                        resolved_anchor,
                        pending_price,
                        resolved_point_size);
  }

  level_plan.anchor_price               = resolved_anchor;
  level_plan.next_blueprint_price       = blueprint_price;
  level_plan.next_resolved_price        = pending_price;
  level_plan.next_price_side            = pricing.side;
  level_plan.next_price_clamp_reason    = pricing.clamp_reason;
  signal_params.grid_plan.levels[level_index] = level_plan;
}

bool GridShouldActivatePendingLevel(const SignalTypes direction,
                                    const GridOrderState &order_state,
                                    const GridLevelPlan &level_plan)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(order_state.last_pending_price <= 0.0)
    return false;

  bool use_limit_activation = (level_plan.entry_style == GRID_ENTRY_STYLE_LIMIT);

  if(direction == BULLISH)
  {
    if(use_limit_activation)
      return (entry_side_price <= order_state.last_pending_price);
    return (entry_side_price >= order_state.last_pending_price);
  }

  if(use_limit_activation)
    return (entry_side_price >= order_state.last_pending_price);
  return (entry_side_price <= order_state.last_pending_price);
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

  GridUpdateNextLevelPrice(direction,
                           order_state,
                           active_plan,
                           point_size,
                           adverse_reference);

  double snapshot_next_price = order_state.next_level_price;
  if(snapshot_next_price <= 0.0)
    snapshot_next_price = GridSnapshotNextLevelPrice(signal_params,
                                                     order_state,
                                                     point_size);

  double tp_reference_points = 0.0;
  if(order_state.entry_price > 0.0 && snapshot_next_price > 0.0 && point_size > 0.0)
    tp_reference_points = MathAbs(order_state.entry_price - snapshot_next_price) / point_size;

  double tp_percent = MathMax(Grid_TP_Percent, 0.0);
  double tp_points = 0.0;
  if(tp_reference_points > 0.0 && tp_percent > 0.0)
    tp_points = tp_reference_points * (tp_percent / 100.0);
  if(tp_points > 0.0)
    tp_points = EnforceBrokerDistance(g_symbol_constraints, tp_points);

  double final_percent = MathMax(Grid_Final_TP_Percent, 0.0);
  double final_tp_points = 0.0;
  if(tp_reference_points > 0.0 && final_percent > 0.0)
    final_tp_points = tp_reference_points * (final_percent / 100.0);
  if(final_tp_points > 0.0)
    final_tp_points = EnforceBrokerDistance(g_symbol_constraints, final_tp_points);

  active_plan.take_profit_points = tp_points;
  active_plan.final_take_profit_points = final_tp_points;
  active_plan.trailing_points = 0.0;
  signal_params.grid_plan.levels[level_index] = active_plan;

  order_state.tp_reference_points = tp_reference_points;

  if(tp_points > 0.0)
    order_state.take_profit_price = fill_price + direction_mult * tp_points * point_size;
  else
    order_state.take_profit_price = 0.0;

  order_state.stop_loss_price   = 0.0;
  order_state.last_pending_price = 0.0;
  order_state.trailing_price = 0.0;
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;

  if(final_tp_points > 0.0)
    order_state.final_take_profit_price = fill_price + direction_mult * final_tp_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

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
  order_state.tp_reference_points = 0.0;
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
    state.tp_reference_points     = 0.0;
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
        string guardrail_reason = "";
        if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
        {
          if(signal_params.grid_plan.base_anchor_price > 0.0)
            order_state.anchor_price = signal_params.grid_plan.base_anchor_price;
          order_state.resolved_distance_points = level_plan.distance_points;
          GridInitializePendingLevel(signal_params,
                                     direction,
                                     order_state,
                                     point_size);
          level_plan = signal_params.grid_plan.levels[i];
          GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
        }
        else if(guardrail_reason != "")
        {
          GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
          order_state.last_action_time = now_time;
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
          if(order_state.last_action_time != now_time)
            GridLogWaitingReady(signal_params, level_plan, adverse_points);
          string guardrail_reason = "";
          if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
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
            GridInitializePendingLevel(signal_params,
                                       direction,
                                       order_state,
                                       point_size);
            level_plan = signal_params.grid_plan.levels[i];
            GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
            double previous_next_price             = previous_state.next_level_price;
            double new_next_price                  = level_plan.next_resolved_price;
            double change_threshold                = point_size;
            if(change_threshold <= 0.0)
              change_threshold = GridResolvePointSize();
            if(change_threshold <= 0.0)
              change_threshold = 1e-6;
            bool emit_next_update = false;
            if(new_next_price > 0.0)
            {
              if(previous_next_price <= 0.0 ||
                 MathAbs(new_next_price - previous_next_price) >= (change_threshold - 1e-9))
                emit_next_update = true;
            }
            else if(previous_next_price > 0.0)
            {
              emit_next_update = true;
            }
            previous_state.next_level_price        = new_next_price;
            previous_state.take_profit_price       = 0.0;
            previous_state.final_take_profit_price = 0.0;
            previous_plan.next_blueprint_price     = level_plan.next_blueprint_price;
            previous_plan.next_resolved_price      = level_plan.next_resolved_price;
            previous_plan.next_price_side          = level_plan.next_price_side;
            previous_plan.next_price_clamp_reason  = level_plan.next_price_clamp_reason;
            signal_params.grid_plan.levels[i - 1]  = previous_plan;
            if(emit_next_update)
            {
              GridLogEvent("LEVEL_NEXT_UPDATE", signal_params, previous_state, previous_plan);
            }
          }
          else if(guardrail_reason != "")
          {
            GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
            order_state.last_action_time = now_time;
          }
          else
          {
            order_state.last_action_time = now_time;
          }
        }
      }

      signal_params.grid_orders[i - 1] = previous_state;
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {
      GridUpdatePendingLevel(signal_params,
                             direction,
                             order_state,
                             point_size);
      level_plan = signal_params.grid_plan.levels[i];

      if(i > 0 && (i - 1) < ArraySize(signal_params.grid_orders))
      {
        GridOrderState previous_state = signal_params.grid_orders[i - 1];
        double previous_next_price = previous_state.next_level_price;
        double new_next_price = level_plan.next_resolved_price;
        double change_threshold = point_size;
        if(change_threshold <= 0.0)
          change_threshold = GridResolvePointSize();
        if(change_threshold <= 0.0)
          change_threshold = 1e-6;

        bool emit_next_update = false;
        if(new_next_price > 0.0)
        {
          if(previous_next_price <= 0.0 ||
             MathAbs(new_next_price - previous_next_price) >= (change_threshold - 1e-9))
            emit_next_update = true;
        }
        else if(previous_next_price > 0.0)
        {
          emit_next_update = true;
        }

        previous_state.next_level_price = new_next_price;
        if((i - 1) < ArraySize(signal_params.grid_plan.levels))
        {
          GridLevelPlan previous_plan = signal_params.grid_plan.levels[i - 1];
          previous_plan.next_blueprint_price    = level_plan.next_blueprint_price;
          previous_plan.next_resolved_price     = level_plan.next_resolved_price;
          previous_plan.next_price_side         = level_plan.next_price_side;
          previous_plan.next_price_clamp_reason = level_plan.next_price_clamp_reason;
          signal_params.grid_plan.levels[i - 1] = previous_plan;
        }
        signal_params.grid_orders[i - 1] = previous_state;

        if(emit_next_update)
        {
          GridLevelPlan logging_plan = GridLevelPlan();
          if((i - 1) < ArraySize(signal_params.grid_plan.levels))
            logging_plan = signal_params.grid_plan.levels[i - 1];
          GridLogEvent("LEVEL_NEXT_UPDATE", signal_params, previous_state, logging_plan);
        }
      }

      order_state.last_action_time = now_time;

      string guardrail_reason = "";
      bool guardrails_ok = GridGuardrailsAllowOrder(normalized_volume, guardrail_reason);

      if(guardrails_ok &&
         GridShouldActivatePendingLevel(direction, order_state, level_plan))
      {
        double execution_price = GridCurrentPriceForDirection(direction, true);
        if(GridApplyExecutionPriceAdjustment(signal_params,
                                             order_state,
                                             level_plan,
                                             direction,
                                             point_size,
                                             execution_price))
        {
          level_plan = signal_params.grid_plan.levels[i];
        }

        if(GridExecuteLevelTrade(signal_params, order_state, level_plan, point_size, normalized_volume))
        {
          signal_params.signal_state = OPENED;
          GridLevelPlan resolved_plan = level_plan;
          if(i < ArraySize(signal_params.grid_plan.levels))
            resolved_plan = signal_params.grid_plan.levels[i];
          GridLogEvent("LEVEL_FILLED", signal_params, order_state, resolved_plan);
        }
      }
      else if(!guardrails_ok && guardrail_reason != "")
      {
        GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
      }

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = GridCurrentPriceForDirection(direction, false);

      if(level_plan.final_take_profit_points > 0.0)
      {
        double final_reference_price = order_state.entry_price;
        if(final_reference_price <= 0.0)
          final_reference_price = order_state.last_pending_price;
        if(final_reference_price <= 0.0)
          final_reference_price = order_state.anchor_price;
        if(final_reference_price <= 0.0)
          final_reference_price = signal_params.grid_plan.base_anchor_price;

        double final_price = 0.0;
        if(final_reference_price > 0.0)
          final_price = final_reference_price + direction_mult * level_plan.final_take_profit_points * point_size;

        order_state.final_take_profit_price = final_price;

        bool final_hit = false;
        if(final_price > 0.0)
        {
          if(direction == BULLISH)
            final_hit = (close_price >= final_price);
          else if(direction == BEARISH)
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
        order_state.final_take_profit_price = 0.0;
      }

      double tp_price = 0.0;
      if(level_plan.take_profit_points > 0.0 && order_state.entry_price > 0.0)
        tp_price = order_state.entry_price + direction_mult * level_plan.take_profit_points * point_size;

      if(tp_price > 0.0 && !order_state.tp_reached)
      {
        order_state.take_profit_price = tp_price;
        bool tp_touch = ((direction == BULLISH) ? (close_price >= tp_price)
                                                : (close_price <= tp_price));
        if(tp_touch)
        {
          order_state.tp_reached = true;
          order_state.take_profit_price = 0.0;

          double trailing_offset_pts = 0.0;
          string trailing_basis = "";
          string trailing_reason_tokens = "";
          double trailing_price = GridResolveTrailingStopPrice(signal_params,
                                                               order_state,
                                                               level_plan,
                                                               direction,
                                                               point_size,
                                                               close_price,
                                                               trailing_offset_pts,
                                                               trailing_basis,
                                                               trailing_reason_tokens);
          if(trailing_price > 0.0)
          {
            order_state.is_trailing_active = true;
            order_state.trailing_price = trailing_price;
            order_state.stop_loss_price = trailing_price;
            order_state.trailing_points = trailing_offset_pts;
            GridAppendReason(trailing_reason_tokens, "tp_touch");
            string side_label = (direction == BULLISH) ? "BID" : "ASK";
            GridLogTrailingEvent("TRAILING_TP_START",
                                 signal_params,
                                 order_state,
                                 trailing_price,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 side_label,
                                 trailing_reason_tokens);
          }
          else
          {
            order_state.is_trailing_active = false;
          }
        }
      }
      else if(tp_price > 0.0)
      {
        order_state.take_profit_price = order_state.tp_reached ? 0.0 : tp_price;
      }
      else
      {
        order_state.take_profit_price = 0.0;
      }

      if(order_state.is_trailing_active)
      {
        double trailing_offset_pts = 0.0;
        string trailing_basis = "";
        string trailing_reason_tokens = "";
        double candidate_trailing = GridResolveTrailingStopPrice(signal_params,
                                                                 order_state,
                                                                 level_plan,
                                                                 direction,
                                                                 point_size,
                                                                 close_price,
                                                                 trailing_offset_pts,
                                                                 trailing_basis,
                                                                 trailing_reason_tokens);
        if(candidate_trailing > 0.0)
        {
          double previous_trailing = order_state.trailing_price;
          double tolerance = point_size;
          if(tolerance <= 0.0)
            tolerance = 1e-6;
          bool price_moved = false;
          if(previous_trailing <= 0.0)
            price_moved = true;
          else if(direction == BULLISH && candidate_trailing > previous_trailing + tolerance)
            price_moved = true;
          else if(direction == BEARISH && candidate_trailing < previous_trailing - tolerance)
            price_moved = true;

          order_state.trailing_points = trailing_offset_pts;

          if(price_moved)
          {
            order_state.trailing_price = candidate_trailing;
            string update_reason = trailing_reason_tokens;
            GridAppendReason(update_reason, "follow_move");
            string side_label = (direction == BULLISH) ? "BID" : "ASK";
            GridLogTrailingEvent("TRAILING_TP_UPDATE",
                                 signal_params,
                                 order_state,
                                 candidate_trailing,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 side_label,
                                 update_reason);
          }

          if(order_state.trailing_price <= 0.0)
            order_state.trailing_price = candidate_trailing;

          order_state.stop_loss_price = order_state.trailing_price;

          bool trailing_hit = false;
          string hit_side = (direction == BULLISH) ? "BID" : "ASK";
          if(direction == BULLISH && order_state.trailing_price > 0.0 && close_price <= order_state.trailing_price)
            trailing_hit = true;
          else if(direction == BEARISH && order_state.trailing_price > 0.0 && close_price >= order_state.trailing_price)
            trailing_hit = true;

          if(trailing_hit)
          {
            string hit_reason = trailing_reason_tokens;
            GridAppendReason(hit_reason, "price_cross");
            GridLogTrailingEvent("TRAILING_TP_HIT",
                                 signal_params,
                                 order_state,
                                 order_state.trailing_price,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 hit_side,
                                 hit_reason);
            order_state.is_trailing_active = false;
            request_close_all = true;
          }
        }
        else
        {
          order_state.is_trailing_active = false;
          order_state.stop_loss_price = 0.0;
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
