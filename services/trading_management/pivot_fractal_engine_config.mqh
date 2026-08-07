//+------------------------------------------------------------------+
//|                trading_management/pivot_fractal_engine_config   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_
#define _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_

enum PivotFractalFixedCounts
{
  PIVOT_LEVEL_COUNT           = 7,
  PIVOT_B_PERCENT_SHIFT_COUNT = 6
};

enum PivotTrialFixedCounts
{
  PIVOT_TRIAL_SL_POLICY_COUNT          = 4,
  PIVOT_TRIAL_TP_MULTIPLE_COUNT        = 4,
  PIVOT_TRIAL_MAX_REENTRY_INDEX        = 3,
  PIVOT_TRIAL_REENTRY_GENERATION_COUNT = 4,
  PIVOT_TRIAL_INITIAL_MATRIX_SIZE      = 16,
  PIVOT_TRIAL_MAX_ROWS_PER_ORIGIN      = 52,
  PIVOT_TRIAL_ACTIVE_STATE_CAP         = 2048
};

const int PIVOT_WINDOW_RETRY_SECONDS = 1;
const double PIVOT_TRIAL_MICRO_BW_13_RATIO = 0.13;
const double PIVOT_TRIAL_MICRO_BW_21_RATIO = 0.21;
const double PIVOT_TRIAL_MICRO_BW_34_RATIO = 0.34;

string PivotFractalEngineLabel(const int engine_id)
{
  if(engine_id == PIVOT_FRACTAL_V2)
    return "PIVOT_FRACTAL_V2";
  return "NONE";
}

bool PivotFractalEngineEnabled(const int engine_id)
{
  return (engine_id == PIVOT_FRACTAL_V2);
}

string PivotLevelLabel(const PivotLevelIds level)
{
  switch(level)
  {
    case PIVOT_LEVEL_S3: return "S3";
    case PIVOT_LEVEL_S2: return "S2";
    case PIVOT_LEVEL_S1: return "S1";
    case PIVOT_LEVEL_PP: return "PP";
    case PIVOT_LEVEL_R1: return "R1";
    case PIVOT_LEVEL_R2: return "R2";
    case PIVOT_LEVEL_R3: return "R3";
  }
  return "UNKNOWN";
}

bool PivotLevelIdAt(const int index, PivotLevelIds &level_out)
{
  if(index < 0 || index >= PIVOT_LEVEL_COUNT)
    return false;
  level_out = (PivotLevelIds)index;
  return true;
}

bool PivotTrialSlPolicyAt(const int index,
                          PivotTrialSlPolicies &policy_out)
{
  if(index < 0 || index >= PIVOT_TRIAL_SL_POLICY_COUNT)
    return false;
  policy_out = (PivotTrialSlPolicies)index;
  return true;
}

string PivotTrialSlPolicyLabel(const PivotTrialSlPolicies policy)
{
  switch(policy)
  {
    case PIVOT_TRIAL_SL_STRUCTURAL:  return "STRUCTURAL";
    case PIVOT_TRIAL_SL_MICRO_BW_13: return "MICRO_BW_13";
    case PIVOT_TRIAL_SL_MICRO_BW_21: return "MICRO_BW_21";
    case PIVOT_TRIAL_SL_MICRO_BW_34: return "MICRO_BW_34";
  }
  return "UNKNOWN";
}

bool PivotTrialSlPolicyRatio(const PivotTrialSlPolicies policy,
                             double &ratio_out)
{
  ratio_out = 0.0;
  switch(policy)
  {
    case PIVOT_TRIAL_SL_MICRO_BW_13:
      ratio_out = PIVOT_TRIAL_MICRO_BW_13_RATIO;
      return true;
    case PIVOT_TRIAL_SL_MICRO_BW_21:
      ratio_out = PIVOT_TRIAL_MICRO_BW_21_RATIO;
      return true;
    case PIVOT_TRIAL_SL_MICRO_BW_34:
      ratio_out = PIVOT_TRIAL_MICRO_BW_34_RATIO;
      return true;
    case PIVOT_TRIAL_SL_STRUCTURAL:
      return false;
  }
  return false;
}

bool PivotTrialSlPolicyAllowsReentry(const PivotTrialSlPolicies policy)
{
  return policy == PIVOT_TRIAL_SL_MICRO_BW_13 ||
         policy == PIVOT_TRIAL_SL_MICRO_BW_21 ||
         policy == PIVOT_TRIAL_SL_MICRO_BW_34;
}

bool PivotTrialTpMultipleAt(const int index,
                            int &multiple_out)
{
  multiple_out = 0;
  switch(index)
  {
    case 0: multiple_out = 1; return true;
    case 1: multiple_out = 2; return true;
    case 2: multiple_out = 3; return true;
    case 3: multiple_out = 5; return true;
  }
  return false;
}

bool PivotTrialTpMultipleSupported(const int multiple)
{
  return multiple == 1 || multiple == 2 || multiple == 3 || multiple == 5;
}

string PivotTrialRoleLabel(const PivotTrialRoles role)
{
  if(role == PIVOT_TRIAL_ROLE_MATRIX)
    return "MATRIX";
  if(role == PIVOT_TRIAL_ROLE_BROKER_PARITY)
    return "BROKER_PARITY";
  return "UNKNOWN";
}

string PivotTrialEligibilityLabel(const PivotTrialEligibilityStatuses status)
{
  switch(status)
  {
    case PIVOT_TRIAL_ELIGIBILITY_ACTIVE:
      return "ACTIVE";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_FEATURE:
      return "INELIGIBLE_FEATURE";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY:
      return "INELIGIBLE_GEOMETRY";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE:
      return "INELIGIBLE_DISTANCE";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY:
      return "INELIGIBLE_MONEY_PLAN";
  }
  return "UNKNOWN";
}

string PivotTrialFirstTouchLabel(const PivotTrialFirstTouchOutcomes outcome)
{
  switch(outcome)
  {
    case PIVOT_TRIAL_FIRST_TOUCH_PENDING:  return "PENDING";
    case PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST: return "TP_FIRST";
    case PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST: return "SL_FIRST";
    case PIVOT_TRIAL_FIRST_TOUCH_CENSORED: return "CENSORED";
  }
  return "UNKNOWN";
}

string PivotTrialChainTerminalLabel(const PivotTrialChainTerminalReasons reason)
{
  switch(reason)
  {
    case PIVOT_TRIAL_CHAIN_NOT_TERMINAL:
      return "NOT_TERMINAL";
    case PIVOT_TRIAL_CHAIN_TP_REACHED:
      return "TP_REACHED";
    case PIVOT_TRIAL_CHAIN_STRUCTURAL_SL:
      return "STRUCTURAL_SL";
    case PIVOT_TRIAL_CHAIN_REENTRY_CAP_REACHED:
      return "REENTRY_CAP_REACHED";
    case PIVOT_TRIAL_CHAIN_NEXT_PIVOT_BOUNDARY:
      return "NEXT_PIVOT_BOUNDARY";
    case PIVOT_TRIAL_CHAIN_ORIGIN_EXPIRED:
      return "ORIGIN_WINDOW_EXPIRED";
    case PIVOT_TRIAL_CHAIN_RUN_END_CENSORED:
      return "RUN_END_CENSORED";
    case PIVOT_TRIAL_CHAIN_INELIGIBLE:
      return "INELIGIBLE";
    case PIVOT_TRIAL_CHAIN_PARITY_COMPLETE:
      return "PARITY_COMPLETE";
  }
  return "UNKNOWN";
}

string PivotTrialQuoteSideLabel(const PivotTrialQuoteSides side)
{
  if(side == PIVOT_TRIAL_QUOTE_SIDE_BID)
    return "BID";
  if(side == PIVOT_TRIAL_QUOTE_SIDE_ASK)
    return "ASK";
  return "NONE";
}

#endif // _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_
