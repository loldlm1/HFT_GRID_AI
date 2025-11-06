#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
// grid_price_resolver is available from the trading_signals include cascade

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
  double pending_points = GridPlanResolvePendingPoints(level_plan);

  double activation_gap_pts = level_plan.activation_offset_points;
  if(activation_gap_pts <= 0.0)
    activation_gap_pts = signal_params.grid_plan.entry_side_raw_gap_points;

  double entry_offset_pts = level_plan.entry_offset_points;
  if(entry_offset_pts <= 0.0)
    entry_offset_pts = signal_params.grid_plan.entry_side_offset_pts_initial;

  double protective_offset_pts = level_plan.protective_stop_points;
  if(protective_offset_pts <= 0.0)
    protective_offset_pts = GridPlanResolveProtectiveOffset(signal_params, level_plan);

  double backend_pending_price = order_state.last_pending_price;
  double plan_next_price = level_plan.next_resolved_price;
  double fallback_next_price = GridComputeFallbackNextPrice(signal_params,
                                                            order_state,
                                                            order_state.level_index,
                                                            point_size);

  double display_next_price = backend_pending_price;
  string next_source = "backend";
  if(display_next_price <= 0.0 && plan_next_price > 0.0)
  {
    display_next_price = plan_next_price;
    next_source = (level_plan.next_price_source == "") ? "plan" : level_plan.next_price_source;
  }
  if(display_next_price <= 0.0 && fallback_next_price > 0.0)
  {
    display_next_price = fallback_next_price;
    next_source = "fallback";
  }
  if(display_next_price <= 0.0)
    next_source = "-";

  string next_side = level_plan.next_price_side;
  if(next_side == "")
    next_side = (signal_params.signal_type == BULLISH) ? "ASK" : "BID";
  string clamp_reason = level_plan.next_price_clamp_reason;
  if(clamp_reason == "")
    clamp_reason = "-";

  double tp_reference_points = order_state.tp_reference_points;
  if(tp_reference_points <= 0.0)
  {
    double tp_reference_price = backend_pending_price;
    if(tp_reference_price <= 0.0)
      tp_reference_price = plan_next_price;
    if(tp_reference_price <= 0.0)
      tp_reference_price = fallback_next_price;
    if(order_state.entry_price > 0.0 && tp_reference_price > 0.0 && point_size > 0.0)
      tp_reference_points = MathAbs(order_state.entry_price - tp_reference_price) / point_size;
  }

  string message = StringFormat("dir=%s|level=%d|status=%s|pending_backend=%.5f|pending_plan=%.5f|pending_fallback=%.5f|protect_price=%.5f|entry=%.5f|tp=%.5f|next=%.5f|next_source=%s|anchor=%.5f|anchor_plan=%.5f|dist=%.1f|pct=%.2f|style=%s|entry_side_price_curr=%.5f|entry_side_price_trail=%.5f|activation_gap_pts=%.2f|protective_pts=%.2f|tp_reference_pts=%.2f|entry_offset_pts=%.2f|next_side=%s|next_clamp=%s",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                backend_pending_price,
                                plan_next_price,
                                fallback_next_price,
                                order_state.stop_loss_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                display_next_price,
                                next_source,
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

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
