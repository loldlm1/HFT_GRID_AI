//+------------------------------------------------------------------+
//|                     trading_signals/pivot_trial_matrix_state    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STATE_MQH_

const int PIVOT_TRIAL_STATE_RESERVE = 64;

PivotTrialActiveState g_pivot_trial_active_states[];
int g_pivot_trial_active_state_peak = 0;
int g_pivot_trial_duplicate_identity_count = 0;
bool g_pivot_trial_state_capacity_failed = false;
bool g_pivot_trial_state_allocation_failed = false;

void ResetPivotTrialMatrixState()
{
  int reset_size = ArrayResize(g_pivot_trial_active_states,
                               0,
                               PIVOT_TRIAL_STATE_RESERVE);
  g_pivot_trial_active_state_peak = 0;
  g_pivot_trial_duplicate_identity_count = 0;
  g_pivot_trial_state_capacity_failed = false;
  g_pivot_trial_state_allocation_failed = reset_size != 0;
}

int PivotTrialActiveStateCount()
{
  return ArraySize(g_pivot_trial_active_states);
}

int PivotTrialActiveStatePeak()
{
  return g_pivot_trial_active_state_peak;
}

int PivotTrialDuplicateIdentityCount()
{
  return g_pivot_trial_duplicate_identity_count;
}

bool PivotTrialStateCapacityFailed()
{
  return g_pivot_trial_state_capacity_failed;
}

bool PivotTrialStateAllocationFailed()
{
  return g_pivot_trial_state_allocation_failed;
}

bool PivotTrialResearchIntegrityFailed()
{
  return g_pivot_trial_state_capacity_failed ||
         g_pivot_trial_state_allocation_failed ||
         g_pivot_trial_duplicate_identity_count > 0;
}

bool PivotTrialMatrixHasOutstandingState()
{
  return PivotTrialActiveStateCount() > 0;
}

int FindPivotTrialActiveStateByTrialId(const string trial_id)
{
  if(trial_id == "")
    return -1;
  int total = PivotTrialActiveStateCount();
  for(int i = 0; i < total; i++)
  {
    if(g_pivot_trial_active_states[i].active &&
       g_pivot_trial_active_states[i].trial.identity.trial_id == trial_id)
      return i;
  }
  return -1;
}

int FindPivotTrialActiveStateByPolicyId(const string policy_id)
{
  if(policy_id == "")
    return -1;
  int total = PivotTrialActiveStateCount();
  for(int i = 0; i < total; i++)
  {
    if(g_pivot_trial_active_states[i].active &&
       g_pivot_trial_active_states[i].trial.identity.role ==
         PIVOT_TRIAL_ROLE_MATRIX &&
       g_pivot_trial_active_states[i].trial.identity.policy_id == policy_id)
      return i;
  }
  return -1;
}

int FindPivotTrialActiveStateByParityId(const string parity_trial_id)
{
  if(parity_trial_id == "")
    return -1;
  int total = PivotTrialActiveStateCount();
  for(int i = 0; i < total; i++)
  {
    if(g_pivot_trial_active_states[i].active &&
       g_pivot_trial_active_states[i].trial.identity.role ==
         PIVOT_TRIAL_ROLE_BROKER_PARITY &&
       g_pivot_trial_active_states[i].trial.identity.parity_trial_id ==
         parity_trial_id)
      return i;
  }
  return -1;
}

bool CopyPivotTrialActiveStateAt(const int index,
                                 PivotTrialActiveState &state_out)
{
  state_out.Reset();
  int total = PivotTrialActiveStateCount();
  if(index < 0 || index >= total)
    return false;
  state_out.CopyFrom(g_pivot_trial_active_states[index]);
  return true;
}

bool PivotTrialActiveStateIdentityValid(const PivotTrialActiveState &state,
                                        string &reason_out)
{
  reason_out = "";
  if(!state.active || state.trial.identity.trial_id == "" ||
     state.trial.identity.origin_id == "")
  {
    reason_out = "ACTIVE_TRIAL_IDENTITY_INVALID";
    return false;
  }

  if(state.trial.identity.role == PIVOT_TRIAL_ROLE_MATRIX)
  {
    if(state.trial.identity.policy_id == "" ||
       !PivotTrialTpMultipleSupported(state.trial.identity.tp_r_multiple) ||
       state.trial.identity.reentry_index < 0 ||
       state.trial.identity.reentry_index > PIVOT_TRIAL_MAX_REENTRY_INDEX)
    {
      reason_out = "ACTIVE_MATRIX_IDENTITY_INVALID";
      return false;
    }
    if(state.trial.identity.sl_policy == PIVOT_TRIAL_SL_STRUCTURAL &&
       state.trial.identity.reentry_index != 0)
    {
      reason_out = "STRUCTURAL_REENTRY_FORBIDDEN";
      return false;
    }
  }
  else if(state.trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY)
  {
    if(state.trial.identity.parity_trial_id == "" ||
       state.trial.identity.parity_trial_id != state.trial.identity.trial_id ||
       state.trial.identity.reentry_index != 0)
    {
      reason_out = "ACTIVE_PARITY_IDENTITY_INVALID";
      return false;
    }
  }
  else
  {
    reason_out = "ACTIVE_TRIAL_ROLE_INVALID";
    return false;
  }
  return true;
}

bool AppendPivotTrialActiveState(const PivotTrialActiveState &state,
                                 string &reason_out)
{
  reason_out = "";
  if(!PivotTrialActiveStateIdentityValid(state, reason_out))
    return false;

  if(FindPivotTrialActiveStateByTrialId(state.trial.identity.trial_id) >= 0 ||
     (state.trial.identity.role == PIVOT_TRIAL_ROLE_MATRIX &&
      FindPivotTrialActiveStateByPolicyId(state.trial.identity.policy_id) >= 0) ||
     (state.trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY &&
      FindPivotTrialActiveStateByParityId(
        state.trial.identity.parity_trial_id) >= 0))
  {
    g_pivot_trial_duplicate_identity_count++;
    reason_out = "ACTIVE_TRIAL_IDENTITY_DUPLICATE";
    return false;
  }

  int total = PivotTrialActiveStateCount();
  if(total >= PIVOT_TRIAL_ACTIVE_STATE_CAP)
  {
    g_pivot_trial_state_capacity_failed = true;
    reason_out = "ACTIVE_TRIAL_STATE_CAP_REACHED";
    return false;
  }

  int resized = ArrayResize(g_pivot_trial_active_states,
                            total + 1,
                            PIVOT_TRIAL_STATE_RESERVE);
  if(resized != total + 1)
  {
    g_pivot_trial_state_allocation_failed = true;
    reason_out = "ACTIVE_TRIAL_STATE_RESIZE_FAILED";
    return false;
  }

  g_pivot_trial_active_states[total].CopyFrom(state);
  int current_total = total + 1;
  if(current_total > g_pivot_trial_active_state_peak)
    g_pivot_trial_active_state_peak = current_total;
  return true;
}

bool RemovePivotTrialActiveStateAt(const int index)
{
  int total = PivotTrialActiveStateCount();
  if(index < 0 || index >= total)
    return false;

  for(int i = index; i < total - 1; i++)
    g_pivot_trial_active_states[i].CopyFrom(
      g_pivot_trial_active_states[i + 1]);

  int reserve = total - 1 > 0 ? PIVOT_TRIAL_STATE_RESERVE : 0;
  int resized = ArrayResize(g_pivot_trial_active_states,
                            total - 1,
                            reserve);
  if(resized != total - 1)
  {
    g_pivot_trial_state_allocation_failed = true;
    return false;
  }
  return true;
}

bool RemovePivotTrialActiveStateByTrialId(const string trial_id)
{
  int index = FindPivotTrialActiveStateByTrialId(trial_id);
  if(index < 0)
    return false;
  return RemovePivotTrialActiveStateAt(index);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STATE_MQH_
