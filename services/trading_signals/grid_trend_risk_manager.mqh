//+------------------------------------------------------------------+
//|                services/trading_signals/grid_trend_risk_manager |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_MANAGER_MQH_
#define _GRID_TREND_RISK_MANAGER_MQH_

bool GridApplyTrendRiskManagement(SignalParams &signal_params,
                                  const GridOrderState &override_state,
                                  const bool has_override,
                                  const bool use_entry_reference_price)
{
  GridRiskTrendStrategyConfig risk_config = GridBuildRiskTrendStrategyConfig();
  if(risk_config.mode == GRID_RM_TREND_OFF)
    return false;

  if(risk_config.mode == GRID_RM_TREND_HEDGE)
    return GridApplyTrendHedgeManagement(signal_params, override_state, has_override);

  GridOrderState state_candidate = override_state;
  if(!has_override)
  {
    if(!GridFindLatestFilledOrder(signal_params, state_candidate))
      return false;
  }

  double reference_price = state_candidate.entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.grid_entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(reference_price <= 0.0)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolveRiskTrendStrategyTimeframe(risk_config);
  double current_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(!GridRiskTrendNextLevelBreached(signal_params.signal_type,
                                     state_candidate,
                                     reference_price,
                                     current_price))
    return false;

  if(!GridTrendSarAlligatorBreach(signal_params.signal_type,
                                  target_tf,
                                  risk_config))
    return false;

  double floating_profit = 0.0;
  if(GridRiskTrendModeRequiresFloating(risk_config))
    floating_profit = GridCollectSignalFloatingProfit(signal_params);

  if(risk_config.mode == GRID_RM_TREND_BE)
  {
    return GridRiskTrendHandleBreakEven(risk_config,
                                        signal_params,
                                        state_candidate,
                                        current_price,
                                        use_entry_reference_price,
                                        floating_profit);
  }

  if(risk_config.mode == GRID_RM_TREND_SL)
  {
    return GridRiskTrendHandleStopLoss(risk_config,
                                       signal_params,
                                       state_candidate,
                                       current_price,
                                       use_entry_reference_price);
  }

  if(risk_config.mode == GRID_RM_TREND_SAR)
  {
    return GridRiskTrendHandleSar(risk_config,
                                  signal_params,
                                  state_candidate,
                                  current_price,
                                  use_entry_reference_price,
                                  floating_profit);
  }

  return false;
}


#endif // _GRID_TREND_RISK_MANAGER_MQH_
