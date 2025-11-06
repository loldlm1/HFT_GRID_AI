#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
// grid_price_resolver is provided via the trading_signals include cascade

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
  level_plan.next_price_source    = "execution_adjust";
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
      previous_plan.next_price_source    = "execution_adjust";
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

void GridScheduleNextLevel(SignalParams &signal_params,
                           const int target_level)
{
  if(target_level < 0)
    return;

  if(target_level >= ArraySize(signal_params.grid_plan.levels))
  {
    if(!GridEnsureLevelPlan(signal_params, target_level))
      return;
  }

  GridEnsureOrderState(signal_params, target_level);

  if(target_level >= ArraySize(signal_params.grid_plan.levels))
    return;

  GridOrderState state = signal_params.grid_orders[target_level];
  if(state.status != GRID_ORDER_INACTIVE)
    return;

  GridLevelPlan level_plan = signal_params.grid_plan.levels[target_level];
  if(level_plan.level_index != target_level)
    level_plan.level_index = target_level;

  GridResetOrderStateForWaiting(state, level_plan);
  signal_params.grid_orders[target_level] = state;
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
  double planned_entry_offset = level_plan.entry_offset_points;
  double planned_pending_points = level_plan.pending_order_points;
  double direction_mult = GridResolveDirectionMultiplier(direction);

  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    double atr_anchor = 0.0;
    int atr_shift = (level_index == 0) ? 1 : 0;
    if(GridResolveAtrAnchorPrice(direction, atr_shift, atr_anchor))
    {
      level_plan.anchor_price = atr_anchor;
      order_state.anchor_price = atr_anchor;
    }

    double reference_price = 0.0;
    if(level_index == 0)
      reference_price = GridCurrentPriceForDirection(direction, true);
    else if((level_index - 1) >= 0 && (level_index - 1) < ArraySize(signal_params.grid_orders))
    {
      GridOrderState previous_state = signal_params.grid_orders[level_index - 1];
      if(previous_state.entry_price > 0.0)
        reference_price = previous_state.entry_price;
    }
    if(reference_price <= 0.0)
      reference_price = GridCurrentPriceForDirection(direction, true);
    if(reference_price <= 0.0)
      reference_price = signal_params.grid_plan.entry_side_price_initial;

    if(reference_price > 0.0 && level_plan.anchor_price > 0.0 && resolved_point_size > 0.0)
    {
      double base_distance = MathAbs(reference_price - level_plan.anchor_price) / resolved_point_size;
      double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
      double scaled_distance = base_distance * MathPow(exponential_multiplier, level_index);
      level_plan.distance_points = scaled_distance;
      level_plan.baseline_distance_points = scaled_distance;
      signal_params.grid_plan.levels[level_index] = level_plan;
    }
  }

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

    double percent_reference_pts = 0.0;
    if(unified_percent > 0.0 && baseline_distance_points > 0.0)
      percent_reference_pts = baseline_distance_points * (unified_percent / 100.0);
    if(percent_reference_pts > 0.0)
      percent_reference_pts = EnforceBrokerDistance(g_symbol_constraints, percent_reference_pts);
    if(percent_reference_pts > protective_offset_pts + 1e-9)
      protective_offset_pts = percent_reference_pts;
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
  if(planned_pending_points > 0.0 &&
     pending_points < planned_pending_points - 1e-9)
    pending_points = planned_pending_points;

  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    level_plan.entry_offset_points = protective_offset_pts;
  else
    level_plan.entry_offset_points = 0.0;
  if(planned_entry_offset > 0.0)
  {
    if(level_plan.entry_offset_points <= 0.0 ||
       level_plan.entry_offset_points < planned_entry_offset - 1e-9)
      level_plan.entry_offset_points = planned_entry_offset;
  }
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

  double pending_price = pricing.next_price;
  string next_source = (pricing.source == "") ? "baseline" : pricing.source;
  if(pending_price <= 0.0 && resolved_anchor > 0.0 && resolved_point_size > 0.0)
  {
    pending_price = resolved_anchor + direction_mult * pending_points * resolved_point_size;
    if(pending_price > 0.0)
      next_source = "fallback";
  }

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
        next_source = "monotonic";
      }
    }
    else if(direction == BEARISH)
    {
      if(pending_price < previous_pending)
      {
        if(previous_pending - pending_price > (tick_tolerance + 1e-9))
          GridAppendReason(pricing.clamp_reason, "monotonic");
        pending_price = previous_pending;
        next_source = "monotonic";
      }
    }
  }

  order_state.anchor_price       = resolved_anchor;
  order_state.stop_loss_price    = 0.0;
  order_state.last_pending_price = pending_price;
  order_state.next_level_price   = 0.0;
  if(pending_price > 0.0)
    order_state.status = GRID_ORDER_PENDING;
  else
    order_state.status = GRID_ORDER_WAITING;
  order_state.last_action_time = TimeCurrent();

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
  level_plan.baseline_anchor_price      = resolved_anchor;
  level_plan.next_resolved_price        = pending_price;
  level_plan.next_price_side            = pricing.side;
  level_plan.next_price_clamp_reason    = pricing.clamp_reason;
  level_plan.next_price_source          = next_source;
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
    snapshot_next_price = GridComputeFallbackNextPrice(signal_params, order_state, level_index, point_size);

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

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LIFECYCLE_MQH_
