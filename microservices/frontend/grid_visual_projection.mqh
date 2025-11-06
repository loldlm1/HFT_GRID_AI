#ifndef _MICROSERVICES_FRONTEND_GRID_VISUAL_PROJECTION_MQH_
#define _MICROSERVICES_FRONTEND_GRID_VISUAL_PROJECTION_MQH_
// trading_signals/grid_price_resolver is included earlier via the service cascade

double ResolveNextOverlayPrice(const SignalParams &signal_params,
                               const int source_index,
                               const int target_index,
                               const double direction_mult,
                               const double point_size)
{
  GridOrderState source_state = GridOrderState();
  GridOrderState target_state = GridOrderState();
  if(target_index >= 0 && target_index < ArraySize(signal_params.grid_orders))
    target_state = signal_params.grid_orders[target_index];

  if(source_index >= 0 && source_index < ArraySize(signal_params.grid_orders))
    source_state = signal_params.grid_orders[source_index];

  GridLevelPlan target_plan = GridLevelPlan();
  bool has_target_plan = false;
  if(target_index >= 0 && target_index < ArraySize(signal_params.grid_plan.levels))
  {
    target_plan = signal_params.grid_plan.levels[target_index];
    has_target_plan = true;
  }

  bool backend_from_source_next  = false;
  bool backend_from_plan         = false;
  bool backend_from_target_state = false;
  bool backend_from_target_next  = false;
  double backend_reference = 0.0;
  if(source_state.next_level_price > 0.0)
  {
    backend_reference = source_state.next_level_price;
    backend_from_source_next = true;
  }
  else if(has_target_plan && target_plan.next_resolved_price > 0.0)
  {
    backend_reference = target_plan.next_resolved_price;
    backend_from_plan = true;
  }
  else if(target_state.last_pending_price > 0.0)
  {
    backend_reference = target_state.last_pending_price;
    backend_from_target_state = true;
  }
  else if(target_state.next_level_price > 0.0)
  {
    backend_reference = target_state.next_level_price;
    backend_from_target_next = true;
  }

  double overlay_price = backend_reference;
  bool overlay_from_source_pending = false;
  bool overlay_from_plan          = false;
  bool overlay_from_fallback      = false;
  bool overlay_from_projection    = false;

  if(overlay_price <= 0.0 && has_target_plan)
  {
    overlay_price = target_plan.next_resolved_price;
    if(overlay_price > 0.0)
      overlay_from_plan = true;
  }

  if(overlay_price <= 0.0 && source_state.last_pending_price > 0.0)
  {
    overlay_price = source_state.last_pending_price;
    overlay_from_source_pending = true;
  }

  if(overlay_price <= 0.0)
  {
    int fallback_index = target_index;
    GridOrderState fallback_state = target_state;
    if(fallback_index < 0)
    {
      fallback_index = source_index + 1;
      fallback_state = source_state;
    }
    overlay_price = GridComputeFallbackNextPrice(signal_params,
                                                 fallback_state,
                                                 fallback_index,
                                                 point_size);
    if(overlay_price > 0.0)
      overlay_from_fallback = true;
  }

  if((overlay_from_source_pending || overlay_price <= 0.0) && source_index >= 0)
  {
    GridLevelPlan source_plan = GridLevelPlan();
    if(source_index < ArraySize(signal_params.grid_plan.levels))
      source_plan = signal_params.grid_plan.levels[source_index];

    double predicted_entry = ResolvePredictedEntryPrice(signal_params,
                                                       source_plan,
                                                       source_state,
                                                       direction_mult,
                                                       point_size);
    double projected_price = ResolveProjectedNextPrice(signal_params,
                                                       source_plan,
                                                       source_state,
                                                       direction_mult,
                                                       point_size,
                                                       source_index,
                                                       predicted_entry);
    if(projected_price > 0.0)
    {
      overlay_price = projected_price;
      overlay_from_projection = true;
      overlay_from_source_pending = false;
      overlay_from_plan = false;
      overlay_from_fallback = false;
    }
  }

  double tolerance = point_size;
  if(tolerance <= 0.0)
    tolerance = 1e-9;

  if(Enable_File_Logs && backend_reference > 0.0 && overlay_price > 0.0)
  {
    if(MathAbs(overlay_price - backend_reference) > (tolerance + 1e-9))
    {
      string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
      string detail = StringFormat("dir=%s|source=%d|target=%d|overlay=%.5f|backend=%.5f|source_next=%.5f|target_pending=%.5f|plan_resolved=%.5f|plan_source=%s",
                                   direction,
                                   source_index,
                                   target_index,
                                   overlay_price,
                                   backend_reference,
                                   source_state.next_level_price,
                                   target_state.last_pending_price,
                                   has_target_plan ? target_plan.next_resolved_price : 0.0,
                                   has_target_plan ? ((target_plan.next_price_source == "") ? "plan" : target_plan.next_price_source) : "-");
      AppendTimestampedLog("query_debug.txt", "NEXT_OVERLAY_DIFF", detail);
    }
  }
  if(Enable_File_Logs && overlay_price > 0.0 && backend_reference <= 0.0)
  {
    string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
    string source_tokens = "";
    if(backend_from_source_next)
      source_tokens = "source_next";
    else if(backend_from_plan)
      source_tokens = "plan_next";
    else if(backend_from_target_state)
      source_tokens = "target_pending";
    else if(backend_from_target_next)
      source_tokens = "target_next";
    else
      source_tokens = "-";

    string overlay_tokens = "-";
    if(overlay_from_source_pending)
      overlay_tokens = "source_pending";
    else if(overlay_from_plan)
      overlay_tokens = "plan_next";
    else if(overlay_from_fallback)
      overlay_tokens = "fallback";
    else if(overlay_from_projection)
      overlay_tokens = "projection";

    string detail = StringFormat("dir=%s|source=%d|target=%d|overlay=%.5f|backend=%.5f|fallback=%s|backend_source=%s|source_next=%.5f|target_pending=%.5f|plan_resolved=%.5f|plan_source=%s",
                                 direction,
                                 source_index,
                                 target_index,
                                 overlay_price,
                                 backend_reference,
                                 overlay_tokens,
                                 source_tokens,
                                 source_state.next_level_price,
                                 target_state.last_pending_price,
                                 has_target_plan ? target_plan.next_resolved_price : 0.0,
                                 has_target_plan ? ((target_plan.next_price_source == "") ? "plan" : target_plan.next_price_source) : "-");
    AppendTimestampedLog("query_debug.txt", "NEXT_OVERLAY_FALLBACK", detail);
  }

  if(!Enable_File_Logs || overlay_price <= 0.0 || source_index < 0)
    return overlay_price;

  static double last_overlay_logged[];
  static double last_backend_logged[];
  static bool   overlay_state_initialized = false;
  ArrayResize(last_overlay_logged, GRID_MAX_LEVELS);
  ArrayResize(last_backend_logged, GRID_MAX_LEVELS);
  if(!overlay_state_initialized)
  {
    for(int idx = 0; idx < GRID_MAX_LEVELS; idx++)
    {
      last_overlay_logged[idx] = 0.0;
      last_backend_logged[idx] = 0.0;
    }
    overlay_state_initialized = true;
  }

  double last_overlay = 0.0;
  double last_backend = 0.0;
  if(source_index < GRID_MAX_LEVELS)
  {
    last_overlay = last_overlay_logged[source_index];
    last_backend = last_backend_logged[source_index];
  }

  bool should_log_state = false;
  if(backend_reference <= 0.0)
  {
    should_log_state = true;
  }
  else
  {
    if(MathAbs(overlay_price - last_overlay) > (tolerance + 1e-9) ||
       MathAbs(backend_reference - last_backend) > (tolerance + 1e-9))
      should_log_state = true;
  }

  if(!should_log_state)
    return overlay_price;

  if(source_index < GRID_MAX_LEVELS)
  {
    last_overlay_logged[source_index] = overlay_price;
    last_backend_logged[source_index] = backend_reference;
  }

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string backend_origin = "";
  if(backend_from_source_next)
    backend_origin = "source_next";
  else if(backend_from_plan)
    backend_origin = "plan_next";
  else if(backend_from_target_state)
    backend_origin = "target_pending";
  else if(backend_from_target_next)
    backend_origin = "target_next";
  else
    backend_origin = "-";

  string overlay_origin = "";
  if(overlay_from_source_pending)
    overlay_origin = "source_pending";
  else if(overlay_from_plan)
    overlay_origin = "plan_next";
  else if(overlay_from_fallback)
    overlay_origin = "fallback";
  else if(overlay_from_projection)
    overlay_origin = "projection";
  else
    overlay_origin = "backend";

  string detail = StringFormat("dir=%s|source=%d|target=%d|overlay=%.5f|backend=%.5f|overlay_origin=%s|backend_origin=%s|source_next=%.5f|target_pending=%.5f|plan_resolved=%.5f|plan_source=%s",
                                direction,
                                source_index,
                                target_index,
                                overlay_price,
                                backend_reference,
                                overlay_origin,
                                backend_origin,
                                source_state.next_level_price,
                                target_state.last_pending_price,
                                has_target_plan ? target_plan.next_resolved_price : 0.0,
                                has_target_plan ? ((target_plan.next_price_source == "") ? "plan" : target_plan.next_price_source) : "-");
  AppendTimestampedLog("query_debug.txt", "NEXT_OVERLAY_STATE", detail);

  return overlay_price;
}

double ResolvePredictedEntryPrice(const SignalParams &signal_params,
                                  const GridLevelPlan &level_plan,
                                  const GridOrderState &level_state,
                                  const double direction_mult,
                                  const double point_size)
{
  if(level_state.status == GRID_ORDER_ACTIVE && level_state.entry_price > 0.0)
    return level_state.entry_price;

  if(level_state.last_pending_price > 0.0)
    return level_state.last_pending_price;

  double anchor = level_plan.anchor_price;
  if(anchor <= 0.0)
    anchor = level_state.anchor_price;
  if(anchor <= 0.0)
    anchor = signal_params.grid_plan.base_anchor_price;

  double pending_points = ResolvePendingPointsForPlan(level_plan);
  if(anchor > 0.0 && pending_points > 0.0 && point_size > 0.0)
    return anchor + direction_mult * pending_points * point_size;

  double entry_side_price = signal_params.grid_plan.entry_side_price_initial;
  double offset_points = signal_params.grid_plan.entry_side_offset_pts_initial;
  if(entry_side_price > 0.0 && offset_points > 0.0 && point_size > 0.0)
    return entry_side_price + direction_mult * offset_points * point_size;

  return anchor;
}

double ResolveProjectedNextPrice(const SignalParams &signal_params,
                                 const GridLevelPlan &level_plan,
                                 const GridOrderState &level_state,
                                 const double direction_mult,
                                 const double point_size,
                                 const int level_index,
                                 const double predicted_entry_price)
{
  double backend_next = level_state.next_level_price;
  if(backend_next > 0.0)
    return backend_next;

  double fallback_next = GridComputeFallbackNextPrice(signal_params,
                                                      level_state,
                                                      level_index + 1,
                                                      point_size);
  if(fallback_next > 0.0)
    return fallback_next;

  return 0.0;
}

#endif // _MICROSERVICES_FRONTEND_GRID_VISUAL_PROJECTION_MQH_
