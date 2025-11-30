//+------------------------------------------------------------------+
//|           trading_management_strategies/grid_trend_risk_sar.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRATEGIES_GRID_TREND_RISK_SAR_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRATEGIES_GRID_TREND_RISK_SAR_MQH_

double GridResolveSarLotReferencePoints(const SignalTypes new_direction,
                                        const SignalParams &original_signal,
                                        const GridOrderState &original_state)
{
  SignalParams preview_signal;
  preview_signal.signal_type = new_direction;
  preview_signal.strategy_timeframe = original_signal.strategy_timeframe;

  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  ENUM_TIMEFRAMES context_tf = preview_signal.strategy_timeframe;
  if(context_tf == PERIOD_CURRENT)
    context_tf = Strategy_Timeframe;

  if(CalculateBaseGridContext(preview_signal,
                              context_tf,
                              base_distance_points,
                              entry_reference_price))
  {
    if(base_distance_points > 0.0)
      return base_distance_points;
  }

  double reference_points = GridResolveLotReferencePoints(original_signal, original_state);
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_base_distance_points;
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_entry_gap_points;

  if(reference_points <= 0.0)
  {
    double point_size = GridResolvePointSizeSafe();
    double entry_reference = original_state.entry_reference_price;
    double tp_price = original_state.take_profit_price;
    if(point_size > 0.0 && entry_reference > 0.0 && tp_price > 0.0)
      reference_points = MathAbs(tp_price - entry_reference) / point_size;
  }

  return MathMax(reference_points, 0.0);
}

bool GridEnsureSarSignalInitialized(SignalParams &signal_params,
                                    const bool log_activation)
{
  if(!signal_params.is_sar_signal)
    return true;
  if(signal_params.grid_initialized)
    return true;

  if(!GridSarEntryConditionReady(signal_params))
    return true;

  if(!BuildGridOrderForSignal(signal_params))
  {
    Print("Trend risk SAR: failed to build reversal grid.");
    return false;
  }

  if(log_activation && ArraySize(signal_params.grid_orders) > 0)
  {
    string reference_label = (Grid_Risk_Alligator_Reference == GRID_RISK_REF_TEETH) ? "TEETH" : "JAWS";
    GridLogEvent(StringFormat("GRID_RISK_TREND_%s_SAR_OPEN", reference_label),
                 signal_params,
                 signal_params.grid_orders[0]);
  }
  return true;
}

bool GridSpawnRiskSarSignal(const SignalTypes direction,
                            double lot_size,
                            const double cumulative_loss)
{
  double normalized_lot = NormalizeVolumeForSymbol(_Symbol, lot_size);
  if(normalized_lot <= 0.0)
  {
    normalized_lot = NormalizeVolumeForSymbol(_Symbol, Grid_Lot_Strategy_Size);
    if(normalized_lot <= 0.0)
      return false;
  }

  SignalParams sar_signal;
  sar_signal.signal_type = direction;
  sar_signal.lot_size    = normalized_lot;
  sar_signal.is_sar_signal = true;
  sar_signal.entry_time  = TimeCurrent();
  sar_signal.entry_price = GridCurrentPriceForDirection(direction, true);
  sar_signal.sar_cumulative_loss = MathMax(cumulative_loss, 0.0);
  sar_signal.strategy_context       = CONTEXT_SLOT_BASE;
  sar_signal.strategy_timeframe     = Strategy_Timeframe;
  sar_signal.strategy_context_label = StrategyContextLabel(CONTEXT_SLOT_BASE);

  if(!GridEnsureSarSignalInitialized(sar_signal, true))
    return false;

  if(!sar_signal.grid_initialized && Enable_Logs)
    Print("Trend risk SAR pending activation; waiting for MA cross before building grid.");

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, sar_signal);
  else
    AddElementToArray(running_bearish_signals, sar_signal);

  // Logging handled inside GridEnsureSarSignalInitialized when activation occurs.
  return true;
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRATEGIES_GRID_TREND_RISK_SAR_MQH_
