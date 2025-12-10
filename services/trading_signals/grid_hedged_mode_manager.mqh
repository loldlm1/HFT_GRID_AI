//+------------------------------------------------------------------+
//|                  grid_hedged_mode_manager.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_

bool HedgedHandleLifecycle(SignalParams &signal_params,
                           GridOrderState &grid_order,
                           const double point_size)
{
  HedgedActivateInitialPendingLevel(signal_params);
  HedgedActivatePendingLevels(signal_params);

  if(!GridSignalHasExecutedLevel(signal_params))
    return false;

  HedgedAlligatorState alligator_state;
  bool alligator_ok = HedgedResolveAlligatorState(signal_params.signal_type, alligator_state);
  HedgedAlligatorTrendPhase alligator_phase = alligator_ok ? alligator_state.phase : HEDGED_TREND_PHASE_UNKNOWN;

  SignalTypes direction = signal_params.signal_type;
  double check_price = GridCurrentPriceForDirection(direction, false);

  if(Hedged_Trend_Mode == HEDGED_TREND_ALLIGATOR && alligator_phase == HEDGED_TREND_PHASE_WRONG)
  {
    double floating_pl = GridCollectSignalFloatingProfit(signal_params);
    double last_entry = HedgedResolveLastFilledEntryPrice(signal_params);
    double profit_buffer = HedgedResolveProfitBuffer();
    bool close_now = (floating_pl > profit_buffer);
    if(!close_now && last_entry > 0.0)
    {
      if(direction == BULLISH)
        close_now = (check_price <= last_entry);
      else
        close_now = (check_price >= last_entry);
    }
    if(close_now)
    {
      GridCloseAllLevels(signal_params, point_size);
      signal_params.signal_state = CLOSED;
      return true;
    }
  }

  HedgedUpdateTrailingOnTrendBar(signal_params, grid_order);

  if(HedgedCheckTrailingExit(signal_params, grid_order, point_size))
    return true;

  if(HedgedSwingSlEnabled(direction) && signal_params.hedged_swing.stop_loss_price > 0.0)
  {
    bool stop_hit = (direction == BULLISH)
                      ? (check_price <= signal_params.hedged_swing.stop_loss_price)
                      : (check_price >= signal_params.hedged_swing.stop_loss_price);
    if(stop_hit)
    {
      GridCloseAllLevels(signal_params, point_size);
      if(HedgedShouldReopenImmediately(signal_params, direction))
        HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
      else
        signal_params.signal_state = CLOSED;
      return true;
    }
  }

  if(signal_params.hedged_swing.target_price > 0.0)
  {
    bool target_hit = (direction == BULLISH)
                        ? (check_price >= signal_params.hedged_swing.target_price)
                        : (check_price <= signal_params.hedged_swing.target_price);
    if(target_hit)
    {
      double floating_pl = GridCollectSignalFloatingProfit(signal_params);
      if(floating_pl >= 1.0)
      {
        GridCloseAllLevels(signal_params, point_size);
        if(HedgedShouldReopenImmediately(signal_params, direction))
          HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
        else
          signal_params.signal_state = CLOSED;
        return true;
      }

      return true;
    }
  }

  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
