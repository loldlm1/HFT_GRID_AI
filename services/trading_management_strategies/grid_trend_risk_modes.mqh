//+------------------------------------------------------------------+
//|          trading_management_strategies/grid_trend_risk_modes.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_MODES_MQH_
#define _GRID_TREND_RISK_MODES_MQH_

#include "grid_risk_trend_strategy.mqh"

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

  double sar_lot = state_candidate.lot_size;
  if(sar_lot <= 0.0)
    sar_lot = signal_params.grid_base_lot_size;
  if(sar_lot <= 0.0)
    sar_lot = Grid_Lot_Strategy_Size;

  double cumulative_loss = signal_params.sar_cumulative_loss;
  if(floating_profit < 0.0)
  {
    double realized_loss = -floating_profit;
    cumulative_loss += realized_loss;

    double multiplier = Grid_Lot_Multiplier;
    if(multiplier <= 0.0)
      multiplier = 1.0;

    double coverage_amount = cumulative_loss * multiplier;
    if(coverage_amount > 0.0)
    {
      double reference_points = GridResolveSarLotReferencePoints(sar_direction, signal_params, state_candidate);
      if(reference_points > 0.0)
      {
        double converted = ConvertAmountToLots(_Symbol, coverage_amount, reference_points);
        if(converted > 0.0)
          sar_lot = converted;
      }
    }
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);
  signal_params.sar_cumulative_loss = cumulative_loss;

  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(GridRiskTrendComposeLogLabel(config, "SAR_CLOSE"), signal_params, log_state);
  signal_params.signal_state = CLOSED;

  if(!GridSpawnRiskSarSignal(sar_direction, sar_lot, cumulative_loss))
    Print("Trend risk SAR: failed to launch reversal grid.");

  return true;
}

#endif // _GRID_TREND_RISK_MODES_MQH_
