#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

double PandoraResolveEntryAnchorPrice(const GridOrderState &grid_order,
                                      const SignalTypes direction)
{
  double entry_anchor = grid_order.entry_price;
  if(entry_anchor <= 0.0)
    entry_anchor = grid_order.entry_reference_price;
  if(entry_anchor <= 0.0)
    entry_anchor = GridCurrentPriceForDirection(direction, true);
  return entry_anchor;
}

double PandoraResolveInitialStopPrice(const SignalParams &signal_params,
                                      const GridOrderState &grid_order,
                                      const SignalTypes direction,
                                      const double point_size)
{
  if(point_size <= 0.0)
    return 0.0;

  double entry_anchor = PandoraResolveEntryAnchorPrice(grid_order, direction);
  if(entry_anchor <= 0.0)
    return 0.0;

  double sl_points = PandoraResolveSignalSLPoints(signal_params, true);
  if(sl_points <= 0.0)
    return 0.0;

  if(direction == BULLISH)
    return entry_anchor - sl_points * point_size;
  return entry_anchor + sl_points * point_size;
}

double PandoraResolveActiveStopPrice(const SignalParams &signal_params,
                                     const GridOrderState &grid_order,
                                     const SignalTypes direction,
                                     const double point_size)
{
  if(signal_params.pandora_trailing_stop_price > 0.0)
    return signal_params.pandora_trailing_stop_price;
  return PandoraResolveInitialStopPrice(signal_params, grid_order, direction, point_size);
}

bool PandoraStopHit(const SignalTypes direction,
                    const double current_price,
                    const double stop_price)
{
  if(current_price <= 0.0 || stop_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return (current_price <= stop_price);
  return (current_price >= stop_price);
}

int PandoraResolveTrailingStepIndex(const SignalParams &signal_params,
                                    const GridOrderState &grid_order,
                                    const SignalTypes direction,
                                    const double current_price,
                                    const double point_size)
{
  if(!PandoraRiskStepTrailingEnabled())
    return 0;
  if(grid_order.entry_price <= 0.0 || current_price <= 0.0 || point_size <= 0.0)
    return 0;

  double step_points = PandoraResolveSignalTrailingStepPoints(signal_params);
  if(step_points <= 0.0)
    return 0;

  double move_points = (direction == BULLISH)
                       ? (current_price - grid_order.entry_price) / point_size
                       : (grid_order.entry_price - current_price) / point_size;
  if(move_points <= 0.0)
    return 0;

  return (int)MathFloor(move_points / step_points);
}

double PandoraResolveStepStopPrice(const SignalParams &signal_params,
                                   const GridOrderState &grid_order,
                                   const SignalTypes direction,
                                   const int step_index,
                                   const double point_size)
{
  if(step_index <= 0 || grid_order.entry_price <= 0.0 || point_size <= 0.0)
    return 0.0;

  double step_points = PandoraResolveSignalTrailingStepPoints(signal_params);
  if(step_points <= 0.0)
    return 0.0;

  double moved_points = (double)(step_index - 1) * step_points;
  if(direction == BULLISH)
    return grid_order.entry_price + moved_points * point_size;
  return grid_order.entry_price - moved_points * point_size;
}

bool PandoraTrailingStopImproves(const SignalTypes direction,
                                 const double candidate_stop,
                                 const double current_stop,
                                 const double tolerance)
{
  if(candidate_stop <= 0.0)
    return false;
  if(current_stop <= 0.0)
    return true;
  if(direction == BULLISH)
    return (candidate_stop > current_stop + tolerance);
  return (candidate_stop < current_stop - tolerance);
}

bool PandoraBrokerStopDistanceSatisfied(const SignalTypes direction,
                                        const double current_price,
                                        const double stop_price,
                                        const double point_size)
{
  if(current_price <= 0.0 || stop_price <= 0.0 || point_size <= 0.0)
    return false;

  double min_distance_points = EnforceBrokerDistance(g_symbol_constraints, 0.0);
  double min_distance_price  = min_distance_points * point_size;
  if(direction == BULLISH)
    return (stop_price <= current_price - min_distance_price);
  return (stop_price >= current_price + min_distance_price);
}

bool PandoraApplyStepTrailing(SignalParams &signal_params,
                              const int grid_order_level,
                              GridOrderState &grid_order,
                              const SignalTypes direction,
                              const double point_size,
                              const double current_price)
{
  if(!PandoraRiskStepTrailingEnabled())
    return false;
  if(grid_order_level < 0 || grid_order_level >= ArraySize(signal_params.grid_orders))
    return false;
  if(grid_order.status != GRID_ORDER_ACTIVE &&
     grid_order.status != GRID_ORDER_TP_TRAILING_ACTIVE)
    return false;

  int target_step_index = PandoraResolveTrailingStepIndex(signal_params,
                                                          grid_order,
                                                          direction,
                                                          current_price,
                                                          point_size);
  if(target_step_index <= signal_params.pandora_trailing_step_index)
    return false;

  double candidate_stop = PandoraResolveStepStopPrice(signal_params,
                                                      grid_order,
                                                      direction,
                                                      target_step_index,
                                                      point_size);
  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  candidate_stop = NormalizeDouble(candidate_stop, digits);

  double current_stop = PandoraResolveActiveStopPrice(signal_params,
                                                      grid_order,
                                                      direction,
                                                      point_size);
  double tolerance = point_size * 0.1;
  if(tolerance <= 0.0)
    tolerance = 0.00001;

  if(!PandoraTrailingStopImproves(direction, candidate_stop, current_stop, tolerance))
    return false;

  if(Pandora_Box_Set_Broker_SLTP)
  {
    if(grid_order.position_ticket <= 0 || !PositionSelectByTicket(grid_order.position_ticket))
      return false;
    if(!PandoraBrokerStopDistanceSatisfied(direction, current_price, candidate_stop, point_size))
      return false;

    if(!g_position.PositionModify(grid_order.position_ticket, candidate_stop, 0.0))
    {
      ulong retcode = g_position.ResultRetcode();
      int last_error = GetLastError();
      MarketStatusRegisterBrokerFailure("PANDORA_STEP_TRAIL_MODIFY_FAILED", retcode, last_error, true);
      return false;
    }
    MarketStatusClearExecutionError("PANDORA_STEP_TRAIL_MODIFY_OK");
  }

  signal_params.pandora_trailing_step_index = target_step_index;
  signal_params.pandora_trailing_stop_price = candidate_stop;
  signal_params.grid_orders[grid_order_level].status = GRID_ORDER_TP_TRAILING_ACTIVE;
  signal_params.grid_orders[grid_order_level].is_trailing_active = true;
  signal_params.grid_orders[grid_order_level].tp_reached = true;
  signal_params.grid_orders[grid_order_level].trailing_price = candidate_stop;
  grid_order = signal_params.grid_orders[grid_order_level];
  GridLogEvent("PANDORA_STEP_TRAILING_UPDATE", signal_params, grid_order);
  return true;
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!GridEnsureSarSignalInitialized(signal_params, true))
    return;
  if(!signal_params.grid_initialized)
    return;
  if(signal_params.signal_state == CLOSED)
    return;

  if(IsPandoraSignal(signal_params))
  {
    int grid_order_level = ArraySize(signal_params.grid_orders)-1;
    if(grid_order_level < 0)
      return;
    GridOrderState grid_order = signal_params.grid_orders[grid_order_level];
    SignalTypes direction = signal_params.signal_type;
    double point_size = GridResolvePointSize();

    if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
    {
      double normalized_volume = NormalizeVolumeForSymbol(_Symbol, grid_order.lot_size);
      if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size) &&
         GridExecuteLevelTrade(signal_params, grid_order, GridResolvePointSize(), normalized_volume))
      {
        signal_params.grid_orders[grid_order_level] = grid_order;
      }
    }
    else if(grid_order.status == GRID_ORDER_ACTIVE || grid_order.status == GRID_ORDER_TP_TRAILING_ACTIVE)
    {
      double current_price = GridCurrentPriceForDirection(direction, false);
      bool step_trailing = PandoraRiskStepTrailingEnabled();
      if(step_trailing && grid_order.entry_price > 0.0 && point_size > 0.0)
      {
        PandoraApplyStepTrailing(signal_params,
                                 grid_order_level,
                                 grid_order,
                                 direction,
                                 point_size,
                                 current_price);
        grid_order = signal_params.grid_orders[grid_order_level];
      }

      if(!Pandora_Box_Set_Broker_SLTP && grid_order.entry_price > 0.0 && point_size > 0.0)
      {
        double sl_price = PandoraResolveActiveStopPrice(signal_params,
                                                        grid_order,
                                                        direction,
                                                        point_size);
        double tp_price = step_trailing ? 0.0 : grid_order.take_profit_price;

        bool hit_sl = PandoraStopHit(direction, current_price, sl_price);
        bool hit_tp = false;
        if(tp_price > 0.0)
          hit_tp = (direction == BULLISH) ? current_price >= tp_price
                                          : current_price <= tp_price;

        if(hit_sl || hit_tp)
        {
          if(hit_tp)
          {
            signal_params.pandora_close_outcome = PANDORA_CLOSE_TP;
            signal_params.pandora_close_epsilon_points = 0.0;
          }
          else
          {
            double estimate_profit = RawProfitUsd(direction,
                                                  signal_params.entry_price,
                                                  current_price);
            double epsilon_points = 0.0;
            PandoraCloseOutcomes close_outcome = PandoraResolveSignalCloseOutcome(signal_params,
                                                                                  current_price,
                                                                                  estimate_profit,
                                                                                  epsilon_points);
            signal_params.pandora_close_outcome = close_outcome;
            signal_params.pandora_close_epsilon_points = epsilon_points;
          }
          GridCloseAllLevels(signal_params, point_size);
          signal_params.grid_orders[grid_order_level].status = GRID_ORDER_COMPLETED;
          grid_order = signal_params.grid_orders[grid_order_level];
        }
      }

      if(Pandora_Box_Set_Broker_SLTP &&
         grid_order.status != GRID_ORDER_COMPLETED &&
         grid_order.position_ticket <= 0 &&
         grid_order.position_comment != "")
      {
        ulong rebound_ticket = FindOpenPositionForSignal(direction,
                                                         grid_order.position_comment);
        if(rebound_ticket > 0)
          grid_order.position_ticket = rebound_ticket;
        else
        {
          PandoraCloseOutcomes history_outcome = PandoraResolveHistoryOutcomeByComment(grid_order.position_comment);
          if(history_outcome != PANDORA_CLOSE_NONE)
          {
            signal_params.pandora_close_outcome = history_outcome;
            grid_order.status = GRID_ORDER_COMPLETED;
          }
        }
      }

      if(grid_order.position_ticket > 0 && !PositionSelectByTicket(grid_order.position_ticket))
      {
        PandoraCloseOutcomes history_outcome = PandoraResolveHistoryOutcomeByPosition(grid_order.position_ticket);
        if(history_outcome != PANDORA_CLOSE_NONE)
          signal_params.pandora_close_outcome = history_outcome;
        grid_order.status = GRID_ORDER_COMPLETED;
      }
      signal_params.grid_orders[grid_order_level] = grid_order;
    }

    if(IsGridSignalComplete(signal_params))
      signal_params.signal_state = CLOSED;
    return;
  }

  double         point_size        = GridResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            grid_order_level  = ArraySize(signal_params.grid_orders)-1;
  GridOrderState grid_order        = signal_params.grid_orders[grid_order_level];

  GridOrderState risk_state = signal_params.grid_orders[grid_order_level];
  bool use_entry_reference = (risk_state.entry_price <= 0.0);
  if(GridApplyTrendRiskManagement(signal_params, risk_state, true, use_entry_reference))
    return;

  if(grid_order.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
  {
    if(UpdateGridOrderForSignal(signal_params))
      grid_order = signal_params.grid_orders[grid_order_level];

    if(!GridSignalHasExecutedLevel(signal_params))
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

    if(GridShouldActivateStopOrder(signal_params, grid_order, direction, point_size))
    {
      if(GridExecuteLevelTrade(signal_params, grid_order, point_size, normalized_volume))
      {
        UpdateGridOrderForSignal(signal_params);
        grid_order = signal_params.grid_orders[grid_order_level];
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
