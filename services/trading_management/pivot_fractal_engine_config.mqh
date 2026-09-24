//+------------------------------------------------------------------+
//|                trading_management/pivot_fractal_engine_config   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_
#define _SERVICES_TRADING_MANAGEMENT_PIVOT_FRACTAL_ENGINE_CONFIG_MQH_

enum PivotTrialFixedCounts
{
  PIVOT_TRIAL_ENTRY_POLICY_COUNT   = 2,
  PIVOT_TRIAL_TP_MULTIPLE_COUNT    = 4,
  PIVOT_TRIAL_INITIAL_LANE_COUNT   = 8,
  PIVOT_TRIAL_ACTIVE_STATE_CAP     = 2048
};

const int PIVOT_WINDOW_RETRY_SECONDS = 1;

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

bool PivotTrialEntryPolicyAt(const int index,
                             PivotTrialEntryPolicies &policy_out)
{
  if(index < 0 || index >= PIVOT_TRIAL_ENTRY_POLICY_COUNT)
    return false;
  policy_out = (PivotTrialEntryPolicies)index;
  return true;
}

string PivotTrialEntryPolicyLabel(const PivotTrialEntryPolicies policy)
{
  switch(policy)
  {
    case PIVOT_TRIAL_ENTRY_STRUCTURAL:  return "STRUCTURAL";
    case PIVOT_TRIAL_ENTRY_MIDPOINT_50: return "MIDPOINT_50";
  }
  return "UNKNOWN";
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

string PivotTrialEligibilityLabel(const PivotTrialEligibilityStatuses status)
{
  switch(status)
  {
    case PIVOT_TRIAL_ELIGIBILITY_ACTIVE:
      return "ACTIVE";
    case PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED:
      return "NOT_TRIGGERED";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY:
      return "INELIGIBLE_GEOMETRY";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE:
      return "INELIGIBLE_DISTANCE";
    case PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY:
      return "INELIGIBLE_MONEY_PLAN";
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
