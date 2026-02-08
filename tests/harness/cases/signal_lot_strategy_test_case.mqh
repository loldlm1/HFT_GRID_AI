#ifndef HFT_GRID_AI_TEST_CASE_SIGNAL_LOT_STRATEGY_MQH
#define HFT_GRID_AI_TEST_CASE_SIGNAL_LOT_STRATEGY_MQH

#include "../framework.mqh"

bool SignalLotStrategy_AssertOutcome(const string label,
                                     const SignalOutcomeTypes actual,
                                     const SignalOutcomeTypes expected,
                                     string &errors)
{
  if(actual == expected)
    return true;

  errors += StringFormat("%s expected %s got %s\n",
                         label,
                         EnumToString(expected),
                         EnumToString(actual));
  return false;
}

bool SignalLotStrategy_AssertStep(const string label,
                                  const int actual,
                                  const int expected,
                                  string &errors)
{
  if(actual == expected)
    return true;

  errors += StringFormat("%s expected %d got %d\n",
                         label,
                         expected,
                         actual);
  return false;
}

bool RunTest_signal_lot_strategy_test(string &errors)
{
  errors = "";

  SignalLotStrategy_AssertOutcome("neutral_zero",
                                  ResolveSignalOutcomeType(0.0),
                                  SIGNAL_OUTCOME_NEUTRAL,
                                  errors);
  SignalLotStrategy_AssertOutcome("neutral_small_positive",
                                  ResolveSignalOutcomeType(0.009),
                                  SIGNAL_OUTCOME_NEUTRAL,
                                  errors);
  SignalLotStrategy_AssertOutcome("neutral_small_negative",
                                  ResolveSignalOutcomeType(-0.009),
                                  SIGNAL_OUTCOME_NEUTRAL,
                                  errors);
  SignalLotStrategy_AssertOutcome("win_at_positive_boundary",
                                  ResolveSignalOutcomeType(0.01),
                                  SIGNAL_OUTCOME_WIN,
                                  errors);
  SignalLotStrategy_AssertOutcome("loss_at_negative_boundary",
                                  ResolveSignalOutcomeType(-0.01),
                                  SIGNAL_OUTCOME_LOSS,
                                  errors);

  SignalLotStrategy_AssertStep("off_always_resets",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_STRATEGY_OFF, 7, -10.0),
                               0,
                               errors);
  SignalLotStrategy_AssertStep("loss_mode_increments_on_loss",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_LOSS, 0, -1.0),
                               1,
                               errors);
  SignalLotStrategy_AssertStep("loss_mode_resets_on_win",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_LOSS, 4, 1.0),
                               0,
                               errors);
  SignalLotStrategy_AssertStep("loss_mode_holds_on_neutral",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_LOSS, 4, 0.005),
                               4,
                               errors);

  SignalLotStrategy_AssertStep("win_mode_increments_on_win",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_WIN, 1, 2.0),
                               2,
                               errors);
  SignalLotStrategy_AssertStep("win_mode_resets_on_loss",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_WIN, 5, -3.0),
                               0,
                               errors);
  SignalLotStrategy_AssertStep("win_mode_holds_on_neutral",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_WIN, 3, -0.004),
                               3,
                               errors);

  SignalLotStrategy_AssertStep("max_step_clamped_on_increment",
                               ResolveSignalLotSequenceStepAfterOutcome(RISK_APPLIED_ON_WIN,
                                                                        SIGNAL_LOT_SEQUENCE_MAX_STEP,
                                                                        100.0),
                               SIGNAL_LOT_SEQUENCE_MAX_STEP,
                               errors);

  return (errors == "");
}

#endif
