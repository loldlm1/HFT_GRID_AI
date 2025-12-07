#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!GridEnsureSarSignalInitialized(signal_params, true))
    return;
  if(!signal_params.grid_initialized)
    return;
  if(signal_params.signal_state == CLOSED)
    return;

  double         point_size        = GridResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            grid_order_level  = ArraySize(signal_params.grid_orders)-1;
  if(grid_order_level < 0)
    return;
  GridOrderState grid_order        = signal_params.grid_orders[grid_order_level];
  bool           hedged_mode       = signal_params.hedged_swing.hedged_mode;

  GridOrderState risk_state = signal_params.grid_orders[grid_order_level];
  bool use_entry_reference = (risk_state.entry_price <= 0.0);
  if(GridApplyTrendRiskManagement(signal_params, risk_state, true, use_entry_reference))
    return;

  if(hedged_mode && HedgedHandleLifecycle(signal_params, grid_order, point_size))
    return;

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    if(UpdateGridOrderForSignal(signal_params))
      grid_order = signal_params.grid_orders[grid_order_level];

    if(!hedged_mode && !GridSignalHasExecutedLevel(signal_params))
    {
      double guard_distance = 0.0;
      double guard_floor    = 0.0;
      double channel_price  = 0.0;
      bool guard_ok = GridSignalChannelGuardSatisfied(signal_params,
                                                      grid_order.entry_reference_price,
                                                      guard_distance,
                                                      guard_floor,
                                                      channel_price);
      if(!guard_ok)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("CHANNEL_GUARD_CANCEL", signal_params, grid_order);
        return;
      }
      if(signal_params.grid_initial_indicator_distance_points <= 0.0 &&
         guard_distance > 0.0)
      {
        signal_params.grid_initial_indicator_distance_points = guard_distance;
      }
    }

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);
    if(Grid_Lot_Type == GRID_LOT_MAX_MARGIN_SPLIT && !signal_params.is_sar_signal)
    {
      double aggressive_lot = GridResolveAggressiveLotSize(direction);
      if(aggressive_lot > 0.0)
      {
        normalized_volume = aggressive_lot;
        signal_params.grid_orders[grid_order_level].lot_size = aggressive_lot;
        grid_order.lot_size = aggressive_lot;
      }
    }

    if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        grid_order = signal_params.grid_orders[grid_order_level];
        HedgedMaybeRebuildSwingsOnVolExpansion(signal_params,
                                               grid_order.entry_price,
                                               grid_order.last_action_time);
        HedgedEnsureOppositePair(signal_params, grid_order);
        GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
        if(Grid_Risk_Trend_Mode == GRID_RM_TREND_HEDGE)
          GridApplyTrendHedgeManagement(signal_params, grid_order, true);
      }
    }
  }

  grid_order = signal_params.grid_orders[grid_order_level];

  if(grid_order.status == GRID_ORDER_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid
    if(!hedged_mode && grid_order.final_take_profit_price > 0.0)
    {
      bool hit_final = (direction == BULLISH && current_price >= grid_order.final_take_profit_price) ||
                        (direction == BEARISH && current_price <= grid_order.final_take_profit_price);
      if(hit_final)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_FINAL_TP", signal_params, grid_order);
      }
    }
    if(!hedged_mode && GridShouldActivateTrailing(signal_params, grid_order, current_price))
    {
      if(Grid_Risk_Trend_Mode == GRID_RM_TREND_HEDGE &&
         signal_params.hedge_position_ticket > 0)
      {
        GridCloseHedgePosition(signal_params, "HEDGE_CLOSE_ON_TRAILING", true);
      }
      signal_params.grid_orders[grid_order_level].status             = GRID_ORDER_TP_TRAILING_ACTIVE;
      signal_params.grid_orders[grid_order_level].tp_reached         = true;
      signal_params.grid_orders[grid_order_level].is_trailing_active = true;
      signal_params.grid_orders[grid_order_level].trailing_price     = UpdateTrailingTP(signal_params, grid_order);
      GridLogEvent("TP_TRAILING_START", signal_params, grid_order);
    }
    if(GridShouldActivateNextLevelLimit(signal_params, grid_order, direction, point_size))
    {
      int current_levels = ArraySize(signal_params.grid_orders);
      int position_levels = GridCountPositionOpeningLevels(signal_params);
      bool next_level_opens_position = GridNextLevelOpensPosition(signal_params);
      bool level_limit_hit = (Grid_Level_Stop_Limit > 0 &&
                              next_level_opens_position &&
                              position_levels >= Grid_Level_Stop_Limit);

      if(level_limit_hit)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("GRID_STOP_LEVEL_LIMIT", signal_params, grid_order);
      }
      else
      {
        if(Grid_Risk_Trend_Mode == GRID_RM_TREND_HEDGE)
          GridHedgeHandlePrevCloseOnNextLevel(signal_params, grid_order, point_size);

        BuildGridOrderForSignal(signal_params);
        GridLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, grid_order);

        GridOrderState newest_state = signal_params.grid_orders[ArraySize(signal_params.grid_orders) - 1];
        bool newest_use_reference = (newest_state.entry_price <= 0.0);
        if(GridApplyTrendRiskManagement(signal_params, newest_state, true, newest_use_reference))
          return;
      }
    }
  }

  if(grid_order.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid even while trailing
    if(!hedged_mode && grid_order.final_take_profit_price > 0.0)
    {
      bool hit_final = (direction == BULLISH && current_price >= grid_order.final_take_profit_price) ||
                        (direction == BEARISH && current_price <= grid_order.final_take_profit_price);
      if(hit_final)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_FINAL_TP", signal_params, grid_order);
      }
    }
    signal_params.grid_orders[grid_order_level].trailing_price = UpdateTrailingTP(signal_params, grid_order);

    bool exit_on_trail = false;
    if(!hedged_mode && signal_params.grid_orders[grid_order_level].trailing_price > 0.0)
    {
      if(direction == BULLISH && current_price <= signal_params.grid_orders[grid_order_level].trailing_price)
        exit_on_trail = true;
      if(direction == BEARISH && current_price >= signal_params.grid_orders[grid_order_level].trailing_price)
        exit_on_trail = true;
    }
    if(!hedged_mode && exit_on_trail)
    {
      GridCloseAllLevels(signal_params, point_size);
      GridLogEvent("EXIT_ON_TRAILING", signal_params, grid_order);
    }
  }

  if(!hedged_mode && Grid_BreakEven_Mode != BE_DISABLE)
  {
    GridProcessBreakEven(signal_params);
    if(GridCheckBreakEvenExit(signal_params))
      return;
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
