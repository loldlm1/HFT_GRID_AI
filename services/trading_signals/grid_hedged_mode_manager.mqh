//+------------------------------------------------------------------+
//|                  grid_hedged_mode_manager.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_

bool HedgedHandleLifecycle(SignalParams &signal_params,
                           GridOrderState &grid_order,
                           const double point_size)
{
  HedgedActivatePendingLevels(signal_params);

  if(!GridSignalHasExecutedLevel(signal_params))
    return false;

  SignalTypes direction = signal_params.signal_type;
  double check_price = GridCurrentPriceForDirection(direction, false);

  /*
  if(HedgedGapRequiresRebase(signal_params, check_price))
  {
    double point = GridResolvePointSize();
    CloseBullishSignal(running_bullish_signals[0]);
    CloseBearishSignal(running_bearish_signals[0]);
    GridCloseAllLevels(running_bullish_signals[0], point);
    GridCloseAllLevels(running_bearish_signals[0], point);

    SignalParams bull_sig;
    SignalParams bear_sig;
    HedgedBuildAndOpenAtAnchor(BULLISH, check_price, TimeCurrent(), bull_sig);
    HedgedBuildAndOpenAtAnchor(BEARISH, check_price, TimeCurrent(), bear_sig);
    ArrayResize(running_bullish_signals, 0);
    ArrayResize(running_bearish_signals, 0);
    AddElementToArray(running_bullish_signals, bull_sig);
    AddElementToArray(running_bearish_signals, bear_sig);
    return true;
  }
  */

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
      if(floating_pl >= 1.0)
      {
        GridCloseAllLevels(signal_params, point_size);
        HedgedBuildAndOpenAtAnchor(direction, check_price, TimeCurrent(), signal_params);
        return true;
      }

      return true;
    }
  }

  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_HEDGED_MODE_MANAGER_MQH_
