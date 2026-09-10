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

void ResetPivotTrialLaneState()
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

bool PivotTrialResearchIntegrityFailed()
{
  return g_pivot_trial_state_capacity_failed ||
         g_pivot_trial_state_allocation_failed ||
         g_pivot_trial_duplicate_identity_count > 0;
}

bool PivotTrialLanesHaveOutstandingState()
{
  return PivotTrialActiveStateCount() > 0;
}

int FindPivotTrialActiveStateByTrialId(const string trial_id)
{
  if(trial_id == "")
    return -1;
  for(int i = 0; i < PivotTrialActiveStateCount(); i++)
  {
    if(g_pivot_trial_active_states[i].active &&
       g_pivot_trial_active_states[i].trial.identity.trial_id == trial_id)
      return i;
  }
  return -1;
}

int FindPivotTrialActiveStateByParityId(const string parity_trial_id)
{
  if(parity_trial_id == "")
    return -1;
  for(int i = 0; i < PivotTrialActiveStateCount(); i++)
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

bool PivotTrialOriginHasActiveStructuralLane(const string origin_id,
                                             const SignalTypes direction)
{
  for(int i = 0; i < PivotTrialActiveStateCount(); i++)
  {
    if(g_pivot_trial_active_states[i].active &&
       g_pivot_trial_active_states[i].trial.identity.origin_id == origin_id &&
       g_pivot_trial_active_states[i].trial.direction == direction &&
       g_pivot_trial_active_states[i].trial.identity.role ==
         PIVOT_TRIAL_ROLE_H1 &&
       g_pivot_trial_active_states[i].trial.identity.entry_policy ==
         PIVOT_TRIAL_ENTRY_STRUCTURAL &&
       g_pivot_trial_active_states[i].trial.eligibility_status ==
         PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
      return true;
  }
  return false;
}

bool CopyPivotTrialActiveStateAt(const int index,
                                 PivotTrialActiveState &state_out)
{
  state_out.Reset();
  if(index < 0 || index >= PivotTrialActiveStateCount())
    return false;
  state_out.CopyFrom(g_pivot_trial_active_states[index]);
  return true;
}

bool PivotTrialActiveStateIdentityValid(const PivotTrialActiveState &state,
                                        string &reason_out)
{
  reason_out = "";
  PivotTrialIdentity identity;
  identity.CopyFrom(state.trial.identity);
  if(!state.active || identity.trial_id == "" || identity.origin_id == "")
  {
    reason_out = "ACTIVE_TRIAL_IDENTITY_INVALID";
    return false;
  }
  if(identity.role == PIVOT_TRIAL_ROLE_H1)
  {
    if((identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL &&
        identity.entry_policy != PIVOT_TRIAL_ENTRY_MIDPOINT_50) ||
       !PivotTrialTpMultipleSupported(identity.tp_r_multiple) ||
       identity.parity_trial_id != "")
    {
      reason_out = "ACTIVE_H1_IDENTITY_INVALID";
      return false;
    }
    if(identity.entry_policy == PIVOT_TRIAL_ENTRY_STRUCTURAL &&
       (state.pending_entry || state.trial.entry_time <= 0 ||
        state.trial.midpoint_touched == false))
    {
      reason_out = "STRUCTURAL_PENDING_ENTRY_FORBIDDEN";
      return false;
    }
    if(state.pending_entry &&
       (identity.entry_policy != PIVOT_TRIAL_ENTRY_MIDPOINT_50 ||
        state.trial.entry_time != 0 || state.trial.midpoint_touched ||
        state.trial.eligibility_status !=
          PIVOT_TRIAL_ELIGIBILITY_NOT_TRIGGERED))
    {
      reason_out = "MIDPOINT_PENDING_STATE_INVALID";
      return false;
    }
    if(!state.pending_entry &&
       (state.trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE ||
        state.trial.entry_time <= 0 || !state.trial.midpoint_touched))
    {
      reason_out = "H1_ACTIVE_STATE_STATUS_INVALID";
      return false;
    }
  }
  else if(identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY)
  {
    if(identity.parity_trial_id == "" ||
       identity.parity_trial_id != identity.trial_id ||
       identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL ||
       identity.tp_r_multiple != 1 || state.pending_entry ||
       state.trial.entry_time <= 0 || !state.trial.midpoint_touched ||
       state.trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE)
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
  if(FindPivotTrialActiveStateByTrialId(state.trial.identity.trial_id) >= 0)
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
  if(total + 1 > g_pivot_trial_active_state_peak)
    g_pivot_trial_active_state_peak = total + 1;
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

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_STATE_MQH_
