//+------------------------------------------------------------------+
//|                              trading_signals/signal_lot_strategy.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_

int       g_signal_lot_sequence_step   = 0;
const int SIGNAL_LOT_SEQUENCE_MAX_STEP = 50;
const double SIGNAL_OUTCOME_EPSILON    = 0.01;

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
  if(MathAbs(raw_profit) < SIGNAL_OUTCOME_EPSILON)
    return SIGNAL_OUTCOME_NEUTRAL;
  if(raw_profit > 0.0)
    return SIGNAL_OUTCOME_WIN;
  return SIGNAL_OUTCOME_LOSS;
}

int ResolveSignalLotSequenceStepAfterOutcome(const SignalLotStrategyTypes lot_strategy,
                                             const int current_sequence_step,
                                             const double raw_profit)
{
  int next_step = ClampSignalLotSequenceStep(current_sequence_step);

  if(lot_strategy == RISK_STRATEGY_OFF)
    return 0;

  SignalOutcomeTypes outcome = ResolveSignalOutcomeType(raw_profit);
  if(outcome == SIGNAL_OUTCOME_NEUTRAL)
    return next_step;

  bool matched_outcome = (lot_strategy == RISK_APPLIED_ON_LOSS &&
                          outcome == SIGNAL_OUTCOME_LOSS) ||
                         (lot_strategy == RISK_APPLIED_ON_WIN &&
                          outcome == SIGNAL_OUTCOME_WIN);

  if(matched_outcome)
    return ClampSignalLotSequenceStep(next_step + 1);
  return 0;
}

void RegisterSignalLotSequenceOutcome(const double raw_profit)
{
  g_signal_lot_sequence_step = ResolveSignalLotSequenceStepAfterOutcome(Signal_Lot_Strategy,
                                                                         g_signal_lot_sequence_step,
                                                                         raw_profit);
}

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_LOT_STRATEGY_MQH_
