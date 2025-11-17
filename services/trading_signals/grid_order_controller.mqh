#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

bool GridApplyTrendRiskManagement(SignalParams &signal_params)
{
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_OFF)
    return false;

  double lips_price = 0.0;
  if(!GridResolveAlligatorLipsTrailingPrice(signal_params, lips_price))
    return false;
  if(lips_price <= 0.0)
    return false;

  GridOrderState latest_state;
  if(!GridFindLatestOrderForLogging(signal_params, latest_state))
    return false;

  double entry_price = latest_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = latest_state.entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  bool breach = false;
  if(signal_params.signal_type == BULLISH)
    breach = (entry_price < lips_price);
  else if(signal_params.signal_type == BEARISH)
    breach = (entry_price > lips_price);

  if(!breach)
    return false;

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_LIPS_BE)
  {
    double floating_profit = GridCollectSignalFloatingProfit(signal_params);
    double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tolerance <= 0.0)
      tolerance = 0.1;
    if(floating_profit < -tolerance)
      return false;
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);

  string log_label = (Grid_Risk_Trend_Mode == GRID_RM_TREND_LIPS_BE) ?
                     "GRID_RISK_TREND_LIPS_BE" :
                     "GRID_RISK_TREND_LIPS_SL";
  GridLogEvent(log_label, signal_params, latest_state);
  signal_params.signal_state = CLOSED;
  return true;
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  double         point_size        = GridResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            grid_order_level  = ArraySize(signal_params.grid_orders)-1;
  GridOrderState grid_order        = signal_params.grid_orders[grid_order_level];

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    if(UpdateGridOrderForSignal(signal_params))
      grid_order = signal_params.grid_orders[grid_order_level];

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);

    if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        grid_order = signal_params.grid_orders[grid_order_level];
        GridLogEvent("GRID_ORDER_STOP_TRAILING_ACTIVE -> GRID_ORDER_ACTIVE", signal_params, grid_order);
      }
    }
  }

  grid_order = signal_params.grid_orders[grid_order_level];

  if(grid_order.status == GRID_ORDER_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid
    if(grid_order.final_take_profit_price > 0.0)
    {
      bool hit_final = (direction == BULLISH && current_price >= grid_order.final_take_profit_price) ||
                        (direction == BEARISH && current_price <= grid_order.final_take_profit_price);
      if(hit_final)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("LEVEL_FINAL_TP", signal_params, grid_order);
      }
    }
    if(GridShouldActivateTrailing(signal_params, grid_order, current_price))
    {
      signal_params.grid_orders[grid_order_level].status             = GRID_ORDER_TP_TRAILING_ACTIVE;
      signal_params.grid_orders[grid_order_level].tp_reached         = true;
      signal_params.grid_orders[grid_order_level].is_trailing_active = true;
      signal_params.grid_orders[grid_order_level].trailing_price     = UpdateTrailingTP(signal_params, grid_order);
      GridLogEvent("TP_TRAILING_START", signal_params, grid_order);
    }
    if(GridShouldActivateNextLevelLimit(signal_params, grid_order, direction, point_size))
    {
      int current_levels = ArraySize(signal_params.grid_orders);
      bool level_limit_hit = (Grid_Level_Stop_Limit > 0 &&
                              current_levels >= Grid_Level_Stop_Limit);

      if(level_limit_hit)
      {
        GridCloseAllLevels(signal_params, point_size);
        GridLogEvent("GRID_STOP_LEVEL_LIMIT", signal_params, grid_order);
      }
      else
      {
        BuildGridOrderForSignal(signal_params);
        GridLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, grid_order);
      }
    }
  }

  if(grid_order.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    double current_price = GridCurrentPriceForDirection(direction, false);
    // Final TP closes the entire grid even while trailing
    if(grid_order.final_take_profit_price > 0.0)
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
    if(signal_params.grid_orders[grid_order_level].trailing_price > 0.0)
    {
      if(direction == BULLISH && current_price <= signal_params.grid_orders[grid_order_level].trailing_price)
        exit_on_trail = true;
      if(direction == BEARISH && current_price >= signal_params.grid_orders[grid_order_level].trailing_price)
        exit_on_trail = true;
    }
    if(exit_on_trail)
    {
      GridCloseAllLevels(signal_params, point_size);
      GridLogEvent("EXIT_ON_TRAILING", signal_params, grid_order);
    }
  }

  if(GridApplyTrendRiskManagement(signal_params))
    return;

  if(Grid_BreakEven_Mode != BE_DISABLE)
  {
    GridProcessBreakEven(signal_params);
    if(GridCheckBreakEvenExit(signal_params))
      return;
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
