//+------------------------------------------------------------------+
//|                         pivot_hft_state.mqh                      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_STATE_MQH_

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
  }
};

PivotHftPivotSnapshot  g_pivot_hft_pivots;
PivotHftCampaignState  g_pivot_hft_campaign;
PivotHftPositionState  g_pivot_hft_positions[];
datetime               g_pivot_hft_last_micro_bar = 0;
datetime               g_pivot_hft_last_macro_bar = 0;
string                 g_pivot_hft_last_error = "";
const int              PIVOT_HFT_LEVEL_SLOT_TOTAL = 8;
datetime               g_pivot_hft_completed_levels_bar = 0;
bool                   g_pivot_hft_completed_levels[8];

void PivotHftResetCampaign()
{
  g_pivot_hft_campaign = PivotHftCampaignState();
}

void PivotHftClearPositionStates()
{
  ArrayResize(g_pivot_hft_positions, 0, 0);
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
