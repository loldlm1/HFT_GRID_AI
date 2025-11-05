//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

const int GRID_MAX_LEVELS = 6;

double GridPlanResolvePendingPoints(const GridLevelPlan &plan)
{
  double pending_points = plan.pending_order_points;
  if(pending_points <= 0.0)
  {
    if(plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
      pending_points = plan.distance_points - plan.entry_offset_points;
    else
      pending_points = plan.distance_points + plan.entry_offset_points;
    if(pending_points <= 0.0)
      pending_points = plan.distance_points;
  }
  return pending_points;
}

double GridResolveUnifiedStopPercent()
{
  double percent = MathMax(Grid_Positions_Stops_Percent, 0.0);
  return percent;
}

double GridPlanResolveBaselineAnchorPrice(const SignalParams &signal_params,
                                          const GridLevelPlan &plan)
{
  if(plan.baseline_anchor_price > 0.0)
    return plan.baseline_anchor_price;
  if(signal_params.grid_plan.base_anchor_price > 0.0)
    return signal_params.grid_plan.base_anchor_price;
  return plan.anchor_price;
}

double GridPlanResolveActivationGapPoints(const double entry_side_price,
                                          const double baseline_anchor_price,
                                          const double point_size,
                                          const double fallback_distance_points)
{
  double fallback_points = MathMax(fallback_distance_points, 0.0);
  if(point_size <= 0.0)
    return fallback_points;
  if(entry_side_price <= 0.0 || baseline_anchor_price <= 0.0)
    return fallback_points;

  double gap_points = MathAbs(entry_side_price - baseline_anchor_price) / point_size;
  if(gap_points <= 0.0)
    gap_points = fallback_points;
  return gap_points;
}

double GridPlanComputeProtectiveOffset(const double unified_percent,
                                       const double activation_gap_points)
{
  if(unified_percent <= 0.0 || activation_gap_points <= 0.0)
    return 0.0;
  return activation_gap_points * (unified_percent / 100.0);
}

double GridPlanResolveProtectiveOffset(const SignalParams &signal_params,
                                       const GridLevelPlan &plan)
{
  if(plan.entry_style == GRID_ENTRY_STYLE_LIMIT)
    return 0.0;

  if(plan.level_index == 0 &&
     signal_params.grid_plan.entry_side_offset_pts_initial > 0.0)
    return signal_params.grid_plan.entry_side_offset_pts_initial;

  if(plan.protective_stop_points > 0.0)
    return plan.protective_stop_points;

  if(plan.entry_offset_points > 0.0)
    return plan.entry_offset_points;

  return 0.0;
}

NextPriceResolution GridPlanResolveNextPricing(const SignalParams &signal_params,
                                               const GridLevelPlan &plan,
                                               const double anchor_price,
                                               const double pending_points,
                                               const double entry_side_reference)
{
  bool is_bullish = (signal_params.signal_type == BULLISH);
  double protective_points = GridPlanResolveProtectiveOffset(signal_params, plan);
  double tick_size = g_symbol_constraints.tick_size;
  double ask_value = g_ask;
  double bid_value = g_bid;

  if(entry_side_reference > 0.0)
  {
    if(is_bullish)
      ask_value = entry_side_reference;
    else
      bid_value = entry_side_reference;
  }

  return ResolveNextPrice(anchor_price,
                          plan.level_index,
                          is_bullish,
                          protective_points,
                          pending_points,
                          tick_size,
                          g_points_spread,
                          ask_value,
                          bid_value);
}

void LogGridPlanDiagnostics(const SignalParams &signal_params,
                            const double point_size,
                            const double base_distance_points,
                            const double base_anchor_price)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double activation_gap_pts = signal_params.grid_plan.entry_side_raw_gap_points;
  double entry_offset_pts = signal_params.grid_plan.entry_side_offset_pts_initial;
  double entry_side_price = signal_params.grid_plan.entry_side_price_initial;
  string header = StringFormat("dir=%s|entry=%.5f|ask=%.5f|bid=%.5f|point=%.5f|base_dist=%.2f|base_anchor=%.5f|activation_gap_pts=%.2f|entry_offset_pts=%.2f|entry_side=%.5f",
                               direction,
                               signal_params.entry_price,
                               g_ask,
                               g_bid,
                               point_size,
                               base_distance_points,
                               base_anchor_price,
                               activation_gap_pts,
                               entry_offset_pts,
                               entry_side_price);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_BASE", header);
}

void LogGridPlanLevelDetail(const SignalParams &signal_params,
                            const GridLevelPlan &level_plan)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double pending_points = GridPlanResolvePendingPoints(level_plan);
  double tick_size = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                              g_symbol_constraints.point_size);
  double alias_next = level_plan.next_resolved_price;
  if(alias_next <= 0.0)
    alias_next = level_plan.next_blueprint_price;
  string next_side = (level_plan.next_price_side == "") ? "-" : level_plan.next_price_side;
  string clamp_reason = (level_plan.next_price_clamp_reason == "") ? "-" : level_plan.next_price_clamp_reason;
  string detail = StringFormat("dir=%s|level=%d|dist=%.2f|baseline=%.2f|pending=%.2f|entry_offset=%.2f|activation=%.2f|activation_gap=%.2f|tp=%.2f|tp_final=%.2f|trail=%.2f|lot=%.2f|anchor=%.5f|entry_style=%s|next=%.5f|next_blueprint=%.5f|next_resolved=%.5f|side=%s|tick=%.5f|stop_level_pts=%.2f|spread_pts=%.1f|clamp=%s",
                               direction,
                               level_plan.level_index,
                               level_plan.distance_points,
                               level_plan.baseline_distance_points,
                               level_plan.pending_order_points,
                               level_plan.entry_offset_points,
                               level_plan.activation_points,
                               level_plan.activation_offset_points,
                               level_plan.take_profit_points,
                               level_plan.final_take_profit_points,
                               level_plan.trailing_points,
                               level_plan.lot_size,
                               level_plan.anchor_price,
                               EnumToString(level_plan.entry_style),
                               alias_next,
                               level_plan.next_blueprint_price,
                               level_plan.next_resolved_price,
                               next_side,
                               tick_size,
                               pending_points,
                               g_points_spread,
                               clamp_reason);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_LEVEL", detail);
}

bool FetchAtrGridContext(const SignalTypes direction,
                         const ENUM_TIMEFRAMES tf,
                         double &distance_points,
                         double &anchor_price)
{
  int total_atr_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_atr_handles <= 0)
    return false;

  for(int i = 0; i < total_atr_handles; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe != tf)
      continue;

    int buffer_index = (direction == BULLISH) ? 1 : 0;
    double atr_reference[];
    if(CopyBuffer(ExtATRIndicatorsHandle[i].indicator_handle,
                  buffer_index,
                  1,
                  1,
                  atr_reference) <= 0)
      return false;

    anchor_price = atr_reference[0];
    double current_price = (direction == BULLISH) ? g_ask : g_bid;
    double point_size    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point_size <= 0.0 || current_price <= 0.0 || anchor_price <= 0.0)
      return false;

    distance_points = MathAbs(current_price - anchor_price) / point_size;
    return (distance_points > 0.0);
  }

  return false;
}

bool CalculateBaseGridContext(const SignalTypes direction,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &anchor_price)
{
  distance_points = 0.0;
  anchor_price    = 0.0;

  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    if(!FetchAtrGridContext(direction, tf, distance_points, anchor_price))
    {
      Print("Failed to fetch ATR distance, falling back to direct points input.");
      distance_points = Grid_ATR_Points_Setup;
    }
    else
    {
      distance_points = distance_points * MathMax(Grid_ATR_Points_Setup, 1.0);
    }
  }
  else
  {
    distance_points = Grid_ATR_Points_Setup;
  }

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  if(anchor_price <= 0.0)
  {
    double current_price = (direction == BULLISH) ? g_ask : g_bid;
    double direction_mult = (direction == BULLISH) ? 1.0 : -1.0;
    anchor_price = current_price - direction_mult * distance_points * point_size;
  }

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
}

double ResolveBaseGridLot(const double base_distance_points)
{
  double base_lot = Grid_Lot_Strategy_Size;

  if(Grid_Lot_Type == GRID_LOT_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double reference_points = base_distance_points;
  if(Grid_TP_Percent > 0.0)
    reference_points = base_distance_points * (Grid_TP_Percent / 100.0);
  if(reference_points <= 0.0)
    reference_points = base_distance_points;

  double target_amount = 0.0;
  if(Grid_Lot_Type == GRID_LOT_PERCENTAGE_BASED)
  {
    double base_balance = Account_Size;
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance > 0.0)
      base_balance = account_balance;
    target_amount = base_balance * (Grid_Lot_Strategy_Size / 100.0);
  }
  else if(Grid_Lot_Type == GRID_LOT_CURRENCY_BASED)
  {
    target_amount = Grid_Lot_Strategy_Size;
  }

  target_amount = MathAbs(target_amount);

  if(target_amount <= 0.0 || reference_points <= 0.0)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double resolved_lot = ConvertAmountToLots(_Symbol, target_amount, reference_points);
  if(resolved_lot <= 0.0)
    resolved_lot = base_lot;
  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

bool BuildGridPlanForSignal(SignalParams &signal_params)
{
  ArrayResize(signal_params.grid_plan.levels, 0);
  signal_params.grid_plan.initialized = false;

  double base_distance_points = 0.0;
  double base_anchor_price    = 0.0;

  if(!CalculateBaseGridContext(signal_params.signal_type,
                               Strategy_Timeframe,
                               base_distance_points,
                               base_anchor_price))
  {
    Print("Grid plan aborted: base distance not available.");
    return false;
  }

  if(base_distance_points <= 0.0)
  {
    Print("Grid plan aborted: base distance not available.");
    return false;
  }

  double base_lot = signal_params.lot_size;
  if(base_lot <= 0.0)
    base_lot = ResolveBaseGridLot(base_distance_points);
  if(base_lot <= 0.0)
  {
    double min_vol = g_symbol_constraints.min_volume;
    if(min_vol <= 0.0)
      min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    base_lot = min_vol;
  }

  signal_params.grid_plan.base_distance_points = base_distance_points;
  signal_params.grid_plan.base_anchor_price    = base_anchor_price;
  signal_params.grid_plan.base_lot_size        = base_lot;
  signal_params.grid_plan.direction            = signal_params.signal_type;
  signal_params.grid_plan.resolved_base_distance_points = 0.0;
  signal_params.grid_plan.range_high_price     = 0.0;
  signal_params.grid_plan.range_low_price      = 0.0;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  double entry_side_price = (signal_params.signal_type == BULLISH) ? g_ask : g_bid;
  if(entry_side_price <= 0.0)
    entry_side_price = signal_params.entry_price;
  double baseline_anchor_price = base_anchor_price;
  double activation_gap_points = GridPlanResolveActivationGapPoints(entry_side_price,
                                                                    baseline_anchor_price,
                                                                    point_size,
                                                                    base_distance_points);
  double unified_stop_percent = GridResolveUnifiedStopPercent();
  double entry_side_offset_pts_initial = GridPlanComputeProtectiveOffset(unified_stop_percent,
                                                                         activation_gap_points);
  if(Grid_Initial_Entry_Style != GRID_ENTRY_STYLE_STOP)
    entry_side_offset_pts_initial = 0.0;
  if(entry_side_offset_pts_initial > 0.0)
  {
    entry_side_offset_pts_initial = EnforceBrokerDistance(g_symbol_constraints,
                                                          entry_side_offset_pts_initial);
  }

  signal_params.grid_plan.entry_side_price_initial    = entry_side_price;
  signal_params.grid_plan.entry_side_raw_gap_points   = activation_gap_points;
  signal_params.grid_plan.entry_side_offset_pts_initial = entry_side_offset_pts_initial;

  if(!GridEnsureLevelPlan(signal_params, 0))
    return false;

  if(Enable_File_Logs)
  {
    GridLevelPlan initial_plan = signal_params.grid_plan.levels[0];
    double pending_points = GridPlanResolvePendingPoints(initial_plan);
    double planned_pending_price = initial_plan.next_blueprint_price;
    double entry_side_price_log = signal_params.grid_plan.entry_side_price_initial;
    if(entry_side_price_log <= 0.0)
      entry_side_price_log = (signal_params.signal_type == BULLISH) ? g_ask : g_bid;
    double clamped_pending_price = initial_plan.next_resolved_price;
    if(planned_pending_price <= 0.0)
      planned_pending_price = initial_plan.anchor_price +
                              ((signal_params.signal_type == BULLISH) ? 1.0 : -1.0) *
                              pending_points * point_size;
    string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
    double alias_next = clamped_pending_price;
    if(alias_next <= 0.0)
      alias_next = planned_pending_price;
    string next_side = (initial_plan.next_price_side == "") ? "-" : initial_plan.next_price_side;
    string clamp_reason = (initial_plan.next_price_clamp_reason == "") ? "-" : initial_plan.next_price_clamp_reason;
    string message = StringFormat("dir=%s|level=%d|dist=%.2f|pending_pts=%.2f|anchor=%.5f|activation_gap_pts=%.2f|entry_offset_pts=%.2f|entry_side_price=%.5f|clamped_pending_price=%.5f|style=%s|next=%.5f|next_blueprint=%.5f|next_resolved=%.5f|side=%s|clamp=%s",
                                  direction,
                                  initial_plan.level_index,
                                  initial_plan.distance_points,
                                  pending_points,
                                  initial_plan.anchor_price,
                                  signal_params.grid_plan.entry_side_raw_gap_points,
                                  signal_params.grid_plan.entry_side_offset_pts_initial,
                                  entry_side_price_log,
                                  clamped_pending_price,
                                  EnumToString(initial_plan.entry_style),
                                  alias_next,
                                  planned_pending_price,
                                  clamped_pending_price,
                                  next_side,
                                  clamp_reason);
    AppendTimestampedLog("query_debug.txt", "LEVEL_PENDING_INIT", message);
  }

  signal_params.grid_plan.initialized = true;

  if(Enable_Logs)
  {
    PrintFormat("Grid plan ready | direction=%s | base_distance=%.2f pts | levels=%d",
                EnumToString(signal_params.grid_plan.direction),
                signal_params.grid_plan.base_distance_points,
                ArraySize(signal_params.grid_plan.levels));
  }

  double log_point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(log_point_size <= 0.0)
    log_point_size = 0.0001;
  LogGridPlanDiagnostics(signal_params, log_point_size, base_distance_points, base_anchor_price);

  return true;
}

double ResolveBaseDistancePoints(const GridMetadata &metadata)
{
  if(metadata.resolved_base_distance_points > 0.0)
    return metadata.resolved_base_distance_points;
  return metadata.base_distance_points;
}

double ResolveBaseLotSize(const GridMetadata &metadata)
{
  if(metadata.base_lot_size > 0.0)
    return metadata.base_lot_size;
  double base_distance = ResolveBaseDistancePoints(metadata);
  if(base_distance <= 0.0)
    return 0.0;
  return ResolveBaseGridLot(base_distance);
}

GridLevelPlan BuildLevelPlanForIndex(const SignalParams &signal_params,
                                     const int level_index)
{
  GridLevelPlan level_plan = GridLevelPlan();
  level_plan.level_index = level_index;
  level_plan.anchor_price = signal_params.grid_plan.base_anchor_price;
  level_plan.entry_style = (level_index == 0) ? Grid_Initial_Entry_Style : Grid_Deep_Entry_Style;

  double base_distance = ResolveBaseDistancePoints(signal_params.grid_plan);
  double base_lot      = ResolveBaseLotSize(signal_params.grid_plan);
  double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
  double lot_multiplier         = MathMax(Grid_Multiplier, 1.0);
  double unified_stop_percent   = GridResolveUnifiedStopPercent();
  double point_size             = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  double level_multiplier = MathPow(exponential_multiplier, level_index);
  double distance_points  = base_distance * level_multiplier;
  level_plan.distance_points = distance_points;
  level_plan.baseline_distance_points = distance_points;
  level_plan.resolved_distance_points = 0.0;
  level_plan.atr_reference_points = signal_params.grid_plan.base_distance_points;

  double entry_side_price_ref = signal_params.grid_plan.entry_side_price_initial;
  if(entry_side_price_ref <= 0.0)
    entry_side_price_ref = (signal_params.signal_type == BULLISH) ? g_ask : g_bid;

  level_plan.baseline_anchor_price = signal_params.grid_plan.base_anchor_price;
  double baseline_anchor_price = GridPlanResolveBaselineAnchorPrice(signal_params,
                                                                    level_plan);
  double activation_gap_points = GridPlanResolveActivationGapPoints(entry_side_price_ref,
                                                                    baseline_anchor_price,
                                                                    point_size,
                                                                    distance_points);

  double protective_points = 0.0;
  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    protective_points = GridPlanComputeProtectiveOffset(unified_stop_percent,
                                                        activation_gap_points);
  if(protective_points > 0.0)
    protective_points = EnforceBrokerDistance(g_symbol_constraints, protective_points);

  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    level_plan.entry_offset_points = protective_points;
  else
    level_plan.entry_offset_points = 0.0;
  level_plan.protective_stop_points = level_plan.entry_offset_points;

  double pending_points = distance_points;
  if(level_plan.entry_style == GRID_ENTRY_STYLE_STOP)
    pending_points += level_plan.entry_offset_points;
  else if(level_plan.entry_style == GRID_ENTRY_STYLE_LIMIT && level_plan.entry_offset_points > 0.0)
  {
    double limit_points = distance_points - level_plan.entry_offset_points;
    if(limit_points > 0.0)
      pending_points = limit_points;
  }
  level_plan.pending_order_points = pending_points;

  double activation_points = distance_points;
  if(activation_points > 0.0)
    activation_points = EnforceBrokerDistance(g_symbol_constraints, activation_points);
  level_plan.activation_points = activation_points;
  level_plan.activation_offset_points = activation_gap_points;
  level_plan.take_profit_points = 0.0;
  level_plan.final_take_profit_points = 0.0;
  level_plan.trailing_points = 0.0;

  double scaled_lot = base_lot * MathPow(lot_multiplier, level_index);
  level_plan.lot_size = NormalizeVolumeForSymbol(_Symbol, scaled_lot);
  level_plan.grid_range_percent = -1.0;

  double pending_points_resolved = GridPlanResolvePendingPoints(level_plan);
  double entry_reference_price = signal_params.grid_plan.entry_side_price_initial;
  NextPriceResolution pricing = GridPlanResolveNextPricing(signal_params,
                                                           level_plan,
                                                           level_plan.anchor_price,
                                                           pending_points_resolved,
                                                           entry_reference_price);
  level_plan.next_blueprint_price    = pricing.blueprint_next;
  level_plan.next_resolved_price     = pricing.resolved_next;
  level_plan.next_price_side         = pricing.side;
  level_plan.next_price_clamp_reason = pricing.clamp_reason;

  return level_plan;
}

bool GridEnsureLevelPlan(SignalParams &signal_params,
                         const int level_index)
{
  if(level_index < 0)
    return false;
  if(level_index >= GRID_MAX_LEVELS)
    return false;

  int current_total = ArraySize(signal_params.grid_plan.levels);
  if(level_index < current_total)
    return true;

  for(int idx = current_total; idx <= level_index; idx++)
  {
    if(idx >= GRID_MAX_LEVELS)
      break;
    GridLevelPlan plan = BuildLevelPlanForIndex(signal_params, idx);
    AddElementToArray(signal_params.grid_plan.levels, plan);
    LogGridPlanLevelDetail(signal_params, plan);
  }

  if(Enable_Logs)
  {
    string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
    PrintFormat("Grid level plan prepared | dir=%s | level=%d",
                direction,
                level_index);
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
