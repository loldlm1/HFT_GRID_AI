//+------------------------------------------------------------------+
//|           trading_management_strategies/grid_trend_risk_sar.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_SAR_MQH_
#define _GRID_TREND_RISK_SAR_MQH_

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
  double normalized_lot = 0.0;
  if(lot_size > 0.0)
  {
    normalized_lot = NormalizeVolumeForSymbol(_Symbol, lot_size);
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

#endif // _GRID_TREND_RISK_SAR_MQH_
