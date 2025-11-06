#ifndef _MICROSERVICES_FRONTEND_GRID_VISUAL_RESOLVERS_MQH_
#define _MICROSERVICES_FRONTEND_GRID_VISUAL_RESOLVERS_MQH_

int ResolveDisplayLevelIndex(const SignalParams &signal_params)
{
  int total_orders = ArraySize(signal_params.grid_orders);
  if(total_orders <= 0)
    return -1;

  int highest_active = -1;
  for(int i = 0; i < total_orders; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_ACTIVE)
      highest_active = i;
  }
  if(highest_active >= 0)
    return highest_active;

  int highest_pending = -1;
  for(int j = 0; j < total_orders; j++)
  {
    GridOrderState state = signal_params.grid_orders[j];
    if(state.status == GRID_ORDER_PENDING)
      highest_pending = j;
  }
  if(highest_pending >= 0)
    return highest_pending;

  if(total_orders > 0 && signal_params.grid_orders[0].status == GRID_ORDER_WAITING)
    return 0;

  for(int k = 0; k < total_orders; k++)
  {
    GridOrderState state = signal_params.grid_orders[k];
    if(state.status == GRID_ORDER_WAITING)
      return k;
  }

  for(int m = 0; m < total_orders; m++)
  {
    GridOrderState state = signal_params.grid_orders[m];
    if(state.status != GRID_ORDER_INACTIVE)
      return m;
  }

  return -1;
}

double ResolvePendingPointsForPlan(const GridLevelPlan &plan)
{
  double pending_points = plan.pending_order_points;
  double distance_points = plan.distance_points;
  double entry_offset = plan.entry_offset_points;

  if(pending_points <= 0.0)
  {
    if(plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
      pending_points = distance_points - entry_offset;
    else
      pending_points = distance_points + entry_offset;
    if(pending_points <= 0.0)
      pending_points = distance_points;
  }

  return pending_points;
}

double ResolveEffectiveDistancePoints(const GridLevelPlan &plan,
                                      const GridOrderState &state)
{
  if(state.resolved_distance_points > 0.0)
    return state.resolved_distance_points;
  if(plan.distance_points > 0.0)
    return plan.distance_points;
  return 0.0;
}

int ResolveNextOverlaySourceIndex(const SignalParams &signal_params)
{
  int orders_total = ArraySize(signal_params.grid_orders);

  int highest_active = -1;
  for(int k = 0; k < orders_total; k++)
  {
    GridOrderState order_state = signal_params.grid_orders[k];
    if(order_state.status == GRID_ORDER_ACTIVE)
      highest_active = k;
  }

  if(highest_active >= 0)
  {
    return highest_active;
  }

  for(int i = 0; i < orders_total; i++)
  {
    GridOrderState order_state = signal_params.grid_orders[i];
    if(order_state.status == GRID_ORDER_PENDING)
      return i;
  }

  for(int j = 0; j < orders_total; j++)
  {
    GridOrderState order_state = signal_params.grid_orders[j];
    if(order_state.status == GRID_ORDER_WAITING)
      return j;
  }

  if(orders_total > 0)
    return 0;

  return -1;
}

int ResolveNextOverlayTargetIndex(const SignalParams &signal_params,
                                  const int source_index)
{
  int levels_total = ArraySize(signal_params.grid_plan.levels);
  if(levels_total <= 0)
    return -1;

  if(source_index >= 0)
  {
    int candidate = source_index + 1;
    if(candidate < levels_total)
      return candidate;
    return -1;
  }

  return 0;
}

#endif // _MICROSERVICES_FRONTEND_GRID_VISUAL_RESOLVERS_MQH_
