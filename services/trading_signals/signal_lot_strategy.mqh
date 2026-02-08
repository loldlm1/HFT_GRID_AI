//+------------------------------------------------------------------+
//|                              trading_signals/signal_lot_strategy.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_

int       g_signal_lot_sequence_step   = 0;
const int SIGNAL_LOT_SEQUENCE_MAX_STEP = 50;

int ClampSignalLotSequenceStep(const int sequence_step)
{
  int safe_step = sequence_step;
  if(safe_step < 0)
    safe_step = 0;
  if(safe_step > SIGNAL_LOT_SEQUENCE_MAX_STEP)
    safe_step = SIGNAL_LOT_SEQUENCE_MAX_STEP;
  return safe_step;
}

int ResolveSignalLotSequenceStepForNewSignal()
{
  if(Signal_Lot_Strategy == RISK_STRATEGY_OFF)
    return 0;

  g_signal_lot_sequence_step = ClampSignalLotSequenceStep(g_signal_lot_sequence_step);
  return g_signal_lot_sequence_step;
}

SignalOutcomeTypes ResolveSignalOutcomeType(const double raw_profit)
{
  if(raw_profit > 0.0)
    return SIGNAL_OUTCOME_WIN;
  if(raw_profit < 0.0)
    return SIGNAL_OUTCOME_LOSS;
  return SIGNAL_OUTCOME_NEUTRAL;
}

void RegisterSignalLotSequenceOutcome(const double raw_profit)
{
  if(Signal_Lot_Strategy == RISK_STRATEGY_OFF)
  {
    g_signal_lot_sequence_step = 0;
    return;
  }

  SignalOutcomeTypes outcome = ResolveSignalOutcomeType(raw_profit);
  if(outcome == SIGNAL_OUTCOME_NEUTRAL)
    return;

  bool matched_outcome = (Signal_Lot_Strategy == RISK_APPLIED_ON_LOSS &&
                          outcome == SIGNAL_OUTCOME_LOSS) ||
                         (Signal_Lot_Strategy == RISK_APPLIED_ON_WIN &&
                          outcome == SIGNAL_OUTCOME_WIN);

  if(matched_outcome)
    g_signal_lot_sequence_step = ClampSignalLotSequenceStep(g_signal_lot_sequence_step + 1);
  else
    g_signal_lot_sequence_step = 0;
}

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_
