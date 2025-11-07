//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

#include "../microservices/trading_signals/grid_atr_utils.mqh"

const int GRID_MAX_LEVELS = 6;

double GridPlanResolvePendingPoints(const GridOrderState &state)
{
  double pending_points = state.pending_distance_points;
  if(pending_points > 0.0)
    return pending_points;

  double reference_points = state.base_distance_points;
  if(reference_points <= 0.0)
    reference_points = state.resolved_distance_points;

  if(reference_points <= 0.0)
    return 0.0;

  if(state.entry_style == GRID_ENTRY_STYLE_LIMIT)
  {
    pending_points = reference_points - state.entry_offset_points;
    if(pending_points <= 0.0)
      pending_points = reference_points;
  }
  else
  {
    pending_points = reference_points + state.entry_offset_points;
  }

  return pending_points;
}

double GridResolveUnifiedStopPercent()
{
  return MathMax(Grid_Positions_Stops_Percent, 0.0);
}

double GridResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double GridResolveDirectionMultiplierSafe(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

bool CalculateBaseGridContext(const SignalParams &signal_params,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &entry_reference_price)
{
  entry_reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(entry_reference_price <= 0.0)
    entry_reference_price = signal_params.entry_price;
  if(entry_reference_price <= 0.0)
    entry_reference_price = (signal_params.signal_type == BULLISH) ? g_ask : g_bid;

  double point_size = GridResolvePointSizeSafe();
  double direction_mult = GridResolveDirectionMultiplierSafe(signal_params.signal_type);
  if(point_size <= 0.0 || direction_mult == 0.0 || entry_reference_price <= 0.0)
    return false;

  double atr_price = 0.0;
  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    if(!GridResolveAtrReferencePrice(signal_params.signal_type, tf, atr_price))
      return false;
  }
  else
  {
    double requested_points = EnforceBrokerDistance(g_symbol_constraints, Grid_ATR_Points_Setup);
    atr_price = entry_reference_price + direction_mult * requested_points * point_size;
  }

  distance_points = MathAbs(atr_price - entry_reference_price) / point_size;
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

GridOrderState BuildLevelState(const SignalParams &signal_params,
                               const int level_index,
                               const double entry_reference_price)
{
  GridOrderState state = GridOrderState();
  state.level_index = level_index;
  state.entry_reference_price = entry_reference_price;
  state.entry_style = (level_index == 0) ? Grid_Initial_Entry_Style : Grid_Deep_Entry_Style;
  state.atr_reference_points = signal_params.grid_base_distance_points;

  double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
  double level_multiplier = MathPow(exponential_multiplier, level_index);
  double base_distance = signal_params.grid_base_distance_points * level_multiplier;
  state.base_distance_points = base_distance;
  state.resolved_distance_points = 0.0;
  state.pending_distance_points = base_distance;

  double activation_distance = EnforceBrokerDistance(g_symbol_constraints, base_distance);
  state.activation_distance_points = activation_distance;
  state.activation_offset_points   = activation_distance;

  double protective_points = 0.0;
  if(state.entry_style == GRID_ENTRY_STYLE_STOP)
  {
    protective_points = signal_params.grid_entry_offset_points * level_multiplier;
    if(protective_points > 0.0)
      protective_points = EnforceBrokerDistance(g_symbol_constraints, protective_points);
  }

  state.entry_offset_points        = protective_points;
  state.protective_distance_points = protective_points;

  if(state.entry_style == GRID_ENTRY_STYLE_STOP && protective_points > 0.0)
    state.pending_distance_points += protective_points;
  else if(state.entry_style == GRID_ENTRY_STYLE_LIMIT && protective_points > 0.0)
  {
    double limit_candidate = base_distance - protective_points;
    if(limit_candidate > 0.0)
      state.pending_distance_points = limit_candidate;
  }

  double lot_multiplier = MathMax(Grid_Multiplier, 1.0);
  double scaled_lot = signal_params.grid_base_lot_size * MathPow(lot_multiplier, level_index);
  state.lot_size = NormalizeVolumeForSymbol(_Symbol, scaled_lot);

  if(state.entry_style == GRID_ENTRY_STYLE_LIMIT)
  {
    double point_size = GridResolvePointSizeSafe();
    double direction_mult = GridResolveDirectionMultiplierSafe(signal_params.signal_type);
    double pending_points = GridPlanResolvePendingPoints(state);
    if(point_size > 0.0 && direction_mult != 0.0 && entry_reference_price > 0.0)
      state.next_level_price = entry_reference_price - direction_mult * pending_points * point_size;
  }

  state.status = GRID_ORDER_WAITING;
  return state;
}

void LogGridPlanDiagnostics(const SignalParams &signal_params,
                            const double point_size,
                            const double base_distance_points)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string header = StringFormat("dir=%s|entry=%.5f|ask=%.5f|bid=%.5f|point=%.5f|base_dist=%.2f|entry_ref=%.5f|entry_offset_pts=%.2f",
                               direction,
                               signal_params.entry_price,
                               g_ask,
                               g_bid,
                               point_size,
                               base_distance_points,
                               signal_params.grid_entry_reference_price,
                               signal_params.grid_entry_offset_points);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_BASE", header);
}

void LogGridPlanLevelDetail(const SignalParams &signal_params,
                            const GridOrderState &state)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  double pending_points = GridPlanResolvePendingPoints(state);
  double tick_size = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                              g_symbol_constraints.point_size);
  string detail = StringFormat("dir=%s|level=%d|dist=%.2f|pending=%.2f|entry_offset=%.2f|activation=%.2f|tp=%.2f|tp_final=%.2f|trail=%.2f|lot=%.2f|style=%s|next_limit=%.5f|tick=%.5f|spread_pts=%.1f",
                               direction,
                               state.level_index,
                               state.base_distance_points,
                               pending_points,
                               state.entry_offset_points,
                               state.activation_distance_points,
                               state.take_profit_points,
                               state.final_take_profit_points,
                               state.trailing_points,
                               state.lot_size,
                               EnumToString(state.entry_style),
                               state.next_level_price,
                               tick_size,
                               g_points_spread);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_LEVEL", detail);
}

GridOrderState BuildLevelStateForIndex(const SignalParams &signal_params,
                                       const int level_index)
{
  double entry_reference_price = signal_params.grid_entry_reference_price;
  if(entry_reference_price <= 0.0)
    entry_reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(entry_reference_price <= 0.0)
    entry_reference_price = signal_params.entry_price;
  return BuildLevelState(signal_params, level_index, entry_reference_price);
}

bool GridEnsureLevelState(SignalParams &signal_params,
                          const int level_index)
{
  if(level_index < 0)
    return false;
  if(level_index >= GRID_MAX_LEVELS)
    return false;

  int current_total = ArraySize(signal_params.grid_orders);
  if(level_index < current_total)
    return true;

  for(int idx = current_total; idx <= level_index; idx++)
  {
    if(idx >= GRID_MAX_LEVELS)
      break;
    GridOrderState state = BuildLevelStateForIndex(signal_params, idx);
    AddElementToArray(signal_params.grid_orders, state);
    LogGridPlanLevelDetail(signal_params, state);
  }

  return true;
}

bool BuildGridPlanForSignal(SignalParams &signal_params)
{
  ArrayResize(signal_params.grid_orders, 0);
  signal_params.grid_initialized = false;

  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;

  if(!CalculateBaseGridContext(signal_params,
                               Strategy_Timeframe,
                               base_distance_points,
                               entry_reference_price))
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

  double unified_stop_percent = GridResolveUnifiedStopPercent();
  double entry_offset_points = 0.0;
  if(Grid_Initial_Entry_Style == GRID_ENTRY_STYLE_STOP && unified_stop_percent > 0.0)
  {
    entry_offset_points = base_distance_points * (unified_stop_percent / 100.0);
    if(entry_offset_points > 0.0)
      entry_offset_points = EnforceBrokerDistance(g_symbol_constraints, entry_offset_points);
  }

  signal_params.grid_base_distance_points      = base_distance_points;
  signal_params.grid_resolved_distance_points  = 0.0;
  signal_params.grid_base_lot_size             = base_lot;
  signal_params.grid_entry_reference_price     = entry_reference_price;
  signal_params.grid_entry_gap_points          = base_distance_points;
  signal_params.grid_entry_offset_points       = entry_offset_points;

  if(!GridEnsureLevelState(signal_params, 0))
    return false;

  signal_params.grid_initialized = true;

  double point_size = GridResolvePointSizeSafe();
  LogGridPlanDiagnostics(signal_params, point_size, base_distance_points);

  if(Enable_Logs)
  {
    PrintFormat("Grid plan ready | direction=%s | base_distance=%.2f pts | levels=%d",
                EnumToString(signal_params.signal_type),
                signal_params.grid_base_distance_points,
                ArraySize(signal_params.grid_orders));
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
