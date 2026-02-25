//+------------------------------------------------------------------+
//|          trading_management_strategies/grid_trend_risk_modes.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_MODES_MQH_
#define _GRID_TREND_RISK_MODES_MQH_

bool GridRiskTrendHandleBreakEven(const GridRiskTrendStrategyConfig &config,
                                  SignalParams &signal_params,
                                  const GridOrderState &state_candidate,
                                  const double current_price,
                                  const bool use_entry_reference_price,
                                  const double floating_profit)
{
  if(!GridRiskTrendModeAllowsExit(config, floating_profit))
    return false;

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);

  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(GridRiskTrendComposeLogLabel(config, "BE"), signal_params, log_state);
  signal_params.signal_state = CLOSED;
  return true;
}

bool GridRiskTrendHandleStopLoss(const GridRiskTrendStrategyConfig &config,
                                 SignalParams &signal_params,
                                 const GridOrderState &state_candidate,
                                 const double current_price,
                                 const bool use_entry_reference_price)
{
  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);

  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(GridRiskTrendComposeLogLabel(config, "SL"), signal_params, log_state);
  signal_params.signal_state = CLOSED;
  return true;
}

bool GridRiskTrendHandleSar(const GridRiskTrendStrategyConfig &config,
                            SignalParams &signal_params,
                            const GridOrderState &state_candidate,
                            const double current_price,
                            const bool use_entry_reference_price,
                            const double floating_profit)
{
  SignalTypes sar_direction = (signal_params.signal_type == BULLISH) ? BEARISH : BULLISH;

  double cumulative_loss = signal_params.sar_cumulative_loss;
  if(floating_profit < 0.0)
  {
    double realized_loss = -floating_profit;
    cumulative_loss += realized_loss;
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);
  signal_params.sar_cumulative_loss = cumulative_loss;

  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(GridRiskTrendComposeLogLabel(config, "SAR_CLOSE"), signal_params, log_state);
  signal_params.signal_state = CLOSED;

  // SAR reuses the configured Pandora_Lot_Type flow; no special lot override.
  if(!GridSpawnRiskSarSignal(sar_direction, 0.0, cumulative_loss))
    Print("Trend risk SAR: failed to launch reversal grid.");

  return true;
}

#endif // _GRID_TREND_RISK_MODES_MQH_
