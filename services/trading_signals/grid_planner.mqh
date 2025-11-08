//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

const int GRID_MAX_LEVELS = 10;

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
  double pending_points = 0; // SHOULD BE USING THE signal_params pending_points
  double tick_size = ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                              g_symbol_constraints.point_size);
  string detail = StringFormat("dir=%s|level=%d|dist=%.2f|pending=%.2f|entry_offset=%.2f|activation=%.2f|tp=%.2f|tp_final=%.2f|trail=%.2f|lot=%.2f|style=%s|next_limit=%.5f|tick=%.5f|spread_pts=%.1f",
                               direction,
                               state.level_index,
                               signal_params.grid_base_distance_points,
                               pending_points,
                               signal_params.grid_entry_offset_points,
                               0,
                               0, // SHOULD BE CALCULATED TP
                               0, // SHOULD BE CALCULATED TP FINAL
                               0, // SHOULD BE CALCULATED TRAILING POINTS
                               state.lot_size,
                               EnumToString(state.entry_style),
                               state.next_level_price,
                               tick_size,
                               g_points_spread);
  AppendTimestampedLog("query_debug.txt", "GRID_PLAN_LEVEL", detail);
}

bool BuildGridSignalPoints(SignalParams &signal_params)
{
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

// Unified entry point to build (init) or refresh (tick) grid geometry and pending levels
bool BuildGridOrderForSignal(SignalParams &signal_params)
{
  if(!BuildGridSignalPoints(signal_params)) return false;

  int total_levels = ArraySize(signal_params.grid_orders);
  GridOrderState grid_order;

  // UPDATES STATUS ON PREV LEVELS
  for(int i = 0; i < total_levels; i++)
  {
    grid_order = signal_params.grid_orders[i];
    if(grid_order.status == GRID_ORDER_WAITING ||
       grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
    {
      signal_params.grid_orders[i].status = GRID_ORDER_ACTIVE;
    }
  }

  int grid_order_level = AddElementToArray(signal_params.grid_orders, grid_order)-1;

  if(grid_order_level < 0)
  {
    Print("ERROR CREATING NEW GRID ORDER LEVEL");
    TesterStop();
    return false;
  }

  // Seed level n
  signal_params.grid_orders[grid_order_level].level_index = grid_order_level;
  signal_params.grid_orders[grid_order_level].status      = GRID_ORDER_STOP_TRAILING_ACTIVE;
  signal_params.grid_orders[grid_order_level].lot_size    = signal_params.grid_base_lot_size;

  // Calculate trailing entry reference and next level activation
  signal_params.grid_orders[grid_order_level].entry_reference_price  = GetGridStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].next_level_price       = GetGridNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].take_profit_price      = GetGridTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].final_take_profit_price = GetGridTakeProfitFinalPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);

  // Telemetry
  LogGridPlanLevelDetail(signal_params, signal_params.grid_orders[0]);
  if(Enable_File_Logs)
    AppendTimestampedLog("query_debug.txt", "LEVEL_PENDING_INIT",
                          StringFormat("level=%d|entry_ref=%.5f|next=%.5f",
                                      0,
                                      signal_params.grid_orders[0].entry_reference_price,
                                      signal_params.grid_orders[0].next_level_price));
  return true;
}

bool UpdateGridOrderForSignal(SignalParams &signal_params)
{
  if(!BuildGridSignalPoints(signal_params)) return false;

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;

  // Calculate trailing entry reference and next level activation
  signal_params.grid_orders[grid_order_level].entry_reference_price  = GetGridStopReferencePrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].next_level_price       = GetGridNextLevelPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].take_profit_price      = GetGridTakeProfitPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);
  signal_params.grid_orders[grid_order_level].final_take_profit_price = GetGridTakeProfitFinalPrice(signal_params.signal_type,
                                                                              signal_params,
                                                                              signal_params.grid_orders[grid_order_level]);

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
