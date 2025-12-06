//+------------------------------------------------------------------+
//|                  grid_hedged_mode_manager.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_

bool HedgedHandleLifecycle(SignalParams &signal_params,
                           GridOrderState &grid_order,
                           const double point_size)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;
  if(!GridSignalHasExecutedLevel(signal_params))
    return false;

  SignalTypes direction = signal_params.signal_type;
  double check_price = GridCurrentPriceForDirection(direction, false);

  if(HedgedSwingSlEnabled(direction) && signal_params.hedged_swing.stop_loss_price > 0.0)
  {
    bool stop_hit = (direction == BULLISH)
                      ? (check_price <= signal_params.hedged_swing.stop_loss_price)
                      : (check_price >= signal_params.hedged_swing.stop_loss_price);
    if(stop_hit)
    {
      GridCloseAllLevels(signal_params, point_size);
      signal_params.signal_state = CLOSED;
      HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
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
      if(floating_pl >= 0.0)
      {
        GridCloseAllLevels(signal_params, point_size);
        HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
        return true;
      }

      double opposite_pl = HedgedCollectDirectionFloatingProfit((direction == BULLISH) ? BEARISH : BULLISH);
      if(opposite_pl > 0.0)
      {
        GridCloseAllLevels(signal_params, point_size);
        if(direction == BULLISH && ArraySize(running_bearish_signals) > 0)
        {
          GridCloseAllLevels(running_bearish_signals[0], point_size);
          HedgedBuildAndOpenAtAnchor(BEARISH, check_price, TimeCurrent(), running_bearish_signals[0]);
        }
        else if(direction == BEARISH && ArraySize(running_bullish_signals) > 0)
        {
          GridCloseAllLevels(running_bullish_signals[0], point_size);
          HedgedBuildAndOpenAtAnchor(BULLISH, check_price, TimeCurrent(), running_bullish_signals[0]);
        }
        HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
        return true;
      }

      GridCloseAllLevels(signal_params, point_size);
      HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
      return true;
    }
  }

  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
