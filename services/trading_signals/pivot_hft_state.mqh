//+------------------------------------------------------------------+
//|                         pivot_hft_state.mqh                      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_

const int PIVOT_HFT_LEVEL_SLOT_TOTAL = 8;

enum PivotHftLevelTestStatuses
{
  PIVOT_HFT_LEVEL_UNTESTED      = 0,
  PIVOT_HFT_LEVEL_TOUCHED_OPEN  = 1,
  PIVOT_HFT_LEVEL_BURNED         = 2
};

struct PivotHftPivotSnapshot
{
  datetime source_bar_time;
  double pivot;
  double resistance_1;
  double resistance_2;
  double resistance_3;
  double support_1;
  double support_2;
  double support_3;
  bool valid;

  PivotHftPivotSnapshot()
  {
    source_bar_time = 0;
    pivot           = 0.0;
    resistance_1   = 0.0;
    resistance_2   = 0.0;
    resistance_3   = 0.0;
    support_1      = 0.0;
    support_2      = 0.0;
    support_3      = 0.0;
    valid           = false;
  }
};

struct PivotHftCampaignState
{
  PivotHftCampaignStatuses status;
  SignalTypes              direction;
  PivotHftPivotLevels      pivot_level;
  double                   pivot_price;
  datetime                 micro_bar_time;
  datetime                 arm_time;
  double                   tracked_extreme;
  double                   trigger_price;
  int                      attempt_count;
  string                   sequence_id;

  PivotHftCampaignState()
  {
    status           = PIVOT_HFT_CAMPAIGN_IDLE;
    direction        = NO_SIGNAL;
    pivot_level      = PIVOT_HFT_LEVEL_NONE;
    pivot_price      = 0.0;
    micro_bar_time   = 0;
    arm_time         = 0;
    tracked_extreme  = 0.0;
    trigger_price    = 0.0;
    attempt_count    = 0;
    sequence_id      = "";
  }
};

struct PivotHftPositionState
{
  PivotHftPositionStatuses status;
  PivotHftCloseOutcomes    close_outcome;
  SignalTypes              direction;
  PivotHftPivotLevels      pivot_level;
  ulong                    position_ticket;
  ulong                    position_identifier;
  ulong                    entry_deal_ticket;
  datetime                 campaign_micro_bar_time;
  datetime                 entry_time;
  datetime                 close_time;
  double                   pivot_price;
  double                   entry_price;
  double                   local_sl_price;
  double                   trailing_stop_price;
  double                   net_result;
  double                   entry_volume;
  int                      trailing_step_index;
  int                      campaign_attempt_count;
  string                   position_comment;
  bool                     close_requested;
  bool                     reattempt_pending;
  bool                     daily_outcome_registered;
  datetime                 last_close_audit_time;

  PivotHftPositionState()
  {
    status                 = PIVOT_HFT_POSITION_ACTIVE;
    close_outcome          = PIVOT_HFT_CLOSE_NONE;
    direction              = NO_SIGNAL;
    pivot_level            = PIVOT_HFT_LEVEL_NONE;
    position_ticket        = 0;
    position_identifier    = 0;
    entry_deal_ticket      = 0;
    campaign_micro_bar_time = 0;
    entry_time             = 0;
    close_time             = 0;
    pivot_price             = 0.0;
    entry_price            = 0.0;
    local_sl_price         = 0.0;
    trailing_stop_price    = 0.0;
    net_result             = 0.0;
    entry_volume           = 0.0;
    trailing_step_index    = 0;
    campaign_attempt_count = 0;
    position_comment       = "";
    close_requested        = false;
    reattempt_pending      = false;
    daily_outcome_registered = false;
    last_close_audit_time  = 0;
  }
};

PivotHftPivotSnapshot  g_pivot_hft_pivots;
PivotHftCampaignState  g_pivot_hft_campaign;
PivotHftPositionState  g_pivot_hft_positions[];
datetime               g_pivot_hft_last_micro_bar = 0;
datetime               g_pivot_hft_last_macro_bar = 0;
string                 g_pivot_hft_last_error = "";
datetime               g_pivot_hft_completed_levels_bar = 0;
bool                   g_pivot_hft_completed_levels[PIVOT_HFT_LEVEL_SLOT_TOTAL];

PivotHftLevelTestStatuses g_pivot_hft_level_test_status[PIVOT_HFT_LEVEL_SLOT_TOTAL];
datetime                  g_pivot_hft_level_test_first_touch_bar[PIVOT_HFT_LEVEL_SLOT_TOTAL];
datetime                  g_pivot_hft_level_test_activation_bar = 0;
datetime                  g_pivot_hft_level_test_source_bar = 0;
datetime                  g_pivot_hft_level_test_last_closed_bar = 0;
datetime                  g_pivot_hft_level_test_last_micro_bar = 0;
datetime                  g_pivot_hft_level_test_retry_after = 0;
bool                      g_pivot_hft_level_test_ready = false;
bool                      g_pivot_hft_level_test_failure_logged = false;
string                    g_pivot_hft_level_test_last_failure = "";

string PivotHftLevelTestStatusLabel(const PivotHftLevelTestStatuses status)
{
  switch(status)
  {
    case PIVOT_HFT_LEVEL_TOUCHED_OPEN:
      return "TOUCHED_OPEN";
    case PIVOT_HFT_LEVEL_BURNED:
      return "BURNED";
    case PIVOT_HFT_LEVEL_UNTESTED:
    default:
      return "UNTESTED";
  }
}

void PivotHftResetLevelTestState()
{
  for(int i = 0; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
  {
    g_pivot_hft_level_test_status[i] = PIVOT_HFT_LEVEL_UNTESTED;
    g_pivot_hft_level_test_first_touch_bar[i] = 0;
  }

  g_pivot_hft_level_test_activation_bar = 0;
  g_pivot_hft_level_test_source_bar = 0;
  g_pivot_hft_level_test_last_closed_bar = 0;
  g_pivot_hft_level_test_last_micro_bar = 0;
  g_pivot_hft_level_test_retry_after = 0;
  g_pivot_hft_level_test_ready = false;
  g_pivot_hft_level_test_failure_logged = false;
  g_pivot_hft_level_test_last_failure = "";
}

void PivotHftPrepareLevelTestContext(const datetime activation_bar,
                                     const datetime source_bar,
                                     const bool force_reset = false)
{
  if(!force_reset &&
     activation_bar > 0 &&
     source_bar > 0 &&
     activation_bar == g_pivot_hft_level_test_activation_bar &&
     source_bar == g_pivot_hft_level_test_source_bar)
    return;

  PivotHftResetLevelTestState();
  g_pivot_hft_level_test_activation_bar = activation_bar;
  g_pivot_hft_level_test_source_bar = source_bar;
}

bool PivotHftLevelTestContextMatches(const datetime activation_bar,
                                     const datetime source_bar)
{
  return (activation_bar > 0 &&
          source_bar > 0 &&
          activation_bar == g_pivot_hft_level_test_activation_bar &&
          source_bar == g_pivot_hft_level_test_source_bar);
}

bool PivotHftLevelTestStateReady()
{
  return g_pivot_hft_level_test_ready;
}

datetime PivotHftLevelTestLastClosedBar()
{
  return g_pivot_hft_level_test_last_closed_bar;
}

datetime PivotHftLevelTestLastMicroBar()
{
  return g_pivot_hft_level_test_last_micro_bar;
}

void PivotHftMarkLevelTestUnavailable(const string reason,
                                     const datetime retry_after)
{
  g_pivot_hft_level_test_ready = false;
  g_pivot_hft_level_test_retry_after = retry_after;

  if(g_pivot_hft_level_test_failure_logged &&
     g_pivot_hft_level_test_last_failure == reason)
    return;

  g_pivot_hft_level_test_failure_logged = true;
  g_pivot_hft_level_test_last_failure = reason;
  PivotHftAuditLog("LEVEL_SCAN_FAILED",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|retry_at=%I64d|reason=%s",
                                (long)g_pivot_hft_level_test_activation_bar,
                                (long)g_pivot_hft_level_test_source_bar,
                                (long)retry_after,
                                reason));
}

bool PivotHftLevelTestRetryAllowed(const datetime now_time)
{
  return (now_time >= g_pivot_hft_level_test_retry_after);
}

void PivotHftMarkLevelTestReady(const datetime last_closed_bar,
                                const datetime current_micro_bar)
{
  g_pivot_hft_level_test_ready = true;
  g_pivot_hft_level_test_retry_after = 0;
  g_pivot_hft_level_test_failure_logged = false;
  g_pivot_hft_level_test_last_failure = "";
  g_pivot_hft_level_test_last_closed_bar = last_closed_bar;
  g_pivot_hft_level_test_last_micro_bar = current_micro_bar;
}

bool PivotHftLevelIndexValid(const PivotHftPivotLevels level)
{
  int level_index = (int)level;
  return (level_index > (int)PIVOT_HFT_LEVEL_NONE &&
          level_index < PIVOT_HFT_LEVEL_SLOT_TOTAL);
}

PivotHftLevelTestStatuses PivotHftGetLevelTestStatus(
  const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return PIVOT_HFT_LEVEL_UNTESTED;
  return g_pivot_hft_level_test_status[(int)level];
}

bool PivotHftLevelIsBurned(const PivotHftPivotLevels level)
{
  return (PivotHftGetLevelTestStatus(level) == PIVOT_HFT_LEVEL_BURNED);
}

bool PivotHftLevelIsAvailable(const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return false;
  return !PivotHftLevelIsBurned(level);
}

datetime PivotHftLevelFirstTouchBar(const PivotHftPivotLevels level)
{
  if(!PivotHftLevelIndexValid(level))
    return 0;
  return g_pivot_hft_level_test_first_touch_bar[(int)level];
}

ulong PivotHftLevelTestMask()
{
  ulong mask = 0;
  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    if(g_pivot_hft_level_test_status[i] == PIVOT_HFT_LEVEL_BURNED)
      mask |= ((ulong)1 << i);
  return mask;
}

ulong PivotHftLevelOpenTouchMask()
{
  ulong mask = 0;
  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    if(g_pivot_hft_level_test_status[i] == PIVOT_HFT_LEVEL_TOUCHED_OPEN)
      mask |= ((ulong)1 << i);
  return mask;
}

void PivotHftCommitOpenMicroBar(const datetime closed_micro_bar)
{
  if(closed_micro_bar <= 0)
    return;

  for(int i = 1; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
  {
    if(g_pivot_hft_level_test_status[i] != PIVOT_HFT_LEVEL_TOUCHED_OPEN ||
       g_pivot_hft_level_test_first_touch_bar[i] != closed_micro_bar)
      continue;

    g_pivot_hft_level_test_status[i] = PIVOT_HFT_LEVEL_BURNED;
    PivotHftAuditLog("LEVEL_BURNED",
                     StringFormat("source=live|level=%s|bar=%I64d|status=%s",
                                  EnumToString((PivotHftPivotLevels)i),
                                  (long)closed_micro_bar,
                                  PivotHftLevelTestStatusLabel(
                                    g_pivot_hft_level_test_status[i])));
  }
}

void PivotHftFinalizeLevelTestContext(const datetime next_activation_bar)
{
  if(g_pivot_hft_level_test_activation_bar <= 0 ||
     g_pivot_hft_level_test_source_bar <= 0 ||
     next_activation_bar <= g_pivot_hft_level_test_activation_bar)
    return;

  datetime final_micro_bar = g_pivot_hft_level_test_last_micro_bar;
  ulong open_mask = PivotHftLevelOpenTouchMask();
  if(final_micro_bar > 0 && final_micro_bar < next_activation_bar)
    PivotHftCommitOpenMicroBar(final_micro_bar);

  PivotHftAuditLog("LEVEL_CONTEXT_FINALIZED",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|last_micro_bar=%I64d|next_activation_bar=%I64d|open_mask=%I64u|burned_mask=%I64u",
                                (long)g_pivot_hft_level_test_activation_bar,
                                (long)g_pivot_hft_level_test_source_bar,
                                (long)final_micro_bar,
                                (long)next_activation_bar,
                                open_mask,
                                PivotHftLevelTestMask()));
}

void PivotHftMarkHistoricalLevelTouched(
  const PivotHftPivotLevels level,
  const datetime micro_bar_time)
{
  if(!PivotHftLevelIndexValid(level) || micro_bar_time <= 0)
    return;

  int level_index = (int)level;
  if(g_pivot_hft_level_test_status[level_index] == PIVOT_HFT_LEVEL_BURNED)
    return;

  if(g_pivot_hft_level_test_first_touch_bar[level_index] <= 0)
    g_pivot_hft_level_test_first_touch_bar[level_index] = micro_bar_time;

  g_pivot_hft_level_test_status[level_index] = PIVOT_HFT_LEVEL_BURNED;
  PivotHftAuditLog("LEVEL_BURNED",
                   StringFormat("source=history|level=%s|bar=%I64d|status=%s",
                                EnumToString(level),
                                (long)micro_bar_time,
                                PivotHftLevelTestStatusLabel(
                                  g_pivot_hft_level_test_status[level_index])));
}

void PivotHftMarkLevelTouchedInOpenMicroBar(
  const PivotHftPivotLevels level,
  const datetime micro_bar_time)
{
  if(!PivotHftLevelIndexValid(level) || micro_bar_time <= 0)
    return;

  int level_index = (int)level;
  if(g_pivot_hft_level_test_status[level_index] == PIVOT_HFT_LEVEL_BURNED)
    return;

  if(g_pivot_hft_level_test_status[level_index] ==
       PIVOT_HFT_LEVEL_TOUCHED_OPEN &&
     g_pivot_hft_level_test_first_touch_bar[level_index] != micro_bar_time)
  {
    PivotHftCommitOpenMicroBar(
      g_pivot_hft_level_test_first_touch_bar[level_index]);
  }

  if(g_pivot_hft_level_test_status[level_index] ==
       PIVOT_HFT_LEVEL_UNTESTED)
  {
    g_pivot_hft_level_test_status[level_index] =
      PIVOT_HFT_LEVEL_TOUCHED_OPEN;
    g_pivot_hft_level_test_first_touch_bar[level_index] = micro_bar_time;
    PivotHftAuditLog("LEVEL_TOUCH_PROVISIONAL",
                     StringFormat("source=live|level=%s|bar=%I64d|status=%s",
                                  EnumToString(level),
                                  (long)micro_bar_time,
                                  PivotHftLevelTestStatusLabel(
                                    g_pivot_hft_level_test_status[level_index])));
  }
}

void PivotHftResetCampaign()
{
  g_pivot_hft_campaign = PivotHftCampaignState();
}

void PivotHftClearPositionStates()
{
  ArrayResize(g_pivot_hft_positions, 0, 0);
}

bool PivotHftHasPositionStates()
{
  return (ArraySize(g_pivot_hft_positions) > 0);
}

bool PivotHftHasLivePositionStates()
{
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionStatuses status = g_pivot_hft_positions[i].status;
    if(status == PIVOT_HFT_POSITION_ACTIVE ||
       status == PIVOT_HFT_POSITION_CLOSE_WAIT)
      return true;
  }
  return false;
}

void PivotHftEnsureCompletedLevelBar(const datetime micro_bar_time)
{
  if(micro_bar_time <= 0 ||
     g_pivot_hft_completed_levels_bar == micro_bar_time)
    return;

  for(int i = 0; i < PIVOT_HFT_LEVEL_SLOT_TOTAL; i++)
    g_pivot_hft_completed_levels[i] = false;
  g_pivot_hft_completed_levels_bar = micro_bar_time;
}

bool PivotHftCampaignLevelCompleted(const datetime micro_bar_time,
                                    const PivotHftPivotLevels level)
{
  int level_index = (int)level;
  if(micro_bar_time <= 0 ||
     level_index <= (int)PIVOT_HFT_LEVEL_NONE ||
     level_index >= PIVOT_HFT_LEVEL_SLOT_TOTAL)
    return false;

  PivotHftEnsureCompletedLevelBar(micro_bar_time);
  return g_pivot_hft_completed_levels[level_index];
}

void PivotHftMarkCampaignLevelCompleted(const datetime micro_bar_time,
                                        const PivotHftPivotLevels level)
{
  if(iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0) != micro_bar_time)
    return;

  int level_index = (int)level;
  if(level_index <= (int)PIVOT_HFT_LEVEL_NONE ||
     level_index >= PIVOT_HFT_LEVEL_SLOT_TOTAL)
    return;

  PivotHftEnsureCompletedLevelBar(micro_bar_time);
  g_pivot_hft_completed_levels[level_index] = true;
}

bool PivotHftCampaignLevelOccupied(const datetime micro_bar_time,
                                   const PivotHftPivotLevels level)
{
  if(PivotHftCampaignLevelCompleted(micro_bar_time, level))
    return true;

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    if(state.status == PIVOT_HFT_POSITION_COMPLETED)
      continue;
    if(state.campaign_micro_bar_time == micro_bar_time &&
       state.pivot_level == level)
      return true;
  }
  return false;
}

int PivotHftFindPositionStateIndex(const ulong position_ticket)
{
  if(position_ticket == 0)
    return -1;

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    if(g_pivot_hft_positions[i].position_ticket == position_ticket)
      return i;
  }
  return -1;
}

bool PivotHftAppendPositionState(const PivotHftPositionState &position_state)
{
  if(position_state.position_ticket == 0)
    return false;
  if(PivotHftFindPositionStateIndex(position_state.position_ticket) >= 0)
    return false;

  int current_size = ArraySize(g_pivot_hft_positions);
  if(ArrayResize(g_pivot_hft_positions, current_size + 1, 16) != current_size + 1)
    return false;

  g_pivot_hft_positions[current_size] = position_state;
  return true;
}

void PivotHftCompactCompletedPositionStates()
{
  int total = ArraySize(g_pivot_hft_positions);
  int write_index = 0;
  for(int read_index = 0; read_index < total; read_index++)
  {
    if(g_pivot_hft_positions[read_index].status == PIVOT_HFT_POSITION_COMPLETED)
      continue;

    if(write_index != read_index)
      g_pivot_hft_positions[write_index] = g_pivot_hft_positions[read_index];
    write_index++;
  }

  if(write_index < total)
    ArrayResize(g_pivot_hft_positions, write_index);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_
