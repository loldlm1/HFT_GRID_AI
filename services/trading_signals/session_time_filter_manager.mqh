//+------------------------------------------------------------------+
//|                  session_time_filter_manager.mqh                 |
//| Coordinates runtime session filters and signal gating.          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SESSION_TIME_FILTER_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_SESSION_TIME_FILTER_MANAGER_MQH_

bool      g_session_time_filter_any_enabled          = false;
bool      g_session_time_filter_window_active        = true;
int       g_session_time_filter_active_slot          = -1;
bool      g_session_time_filter_slot_active[SESSION_TIME_FILTER_SLOT_TOTAL];
bool      g_session_time_filter_slot_prev_state[SESSION_TIME_FILTER_SLOT_TOTAL];
bool      g_session_time_filter_invalid_warned[SESSION_TIME_FILTER_SLOT_TOTAL];
datetime  g_session_time_filter_last_day_anchor      = 0;
bool      g_session_time_filter_block_logged         = false;
string    g_session_time_filter_force_close_queue[];

void SessionTimeFilterQueueForceClose(const string reason);
bool SessionTimeFilterConsumeForceClose(string &reason);

void SessionTimeFilterResetSlotState()
{
  for(int i = 0; i < SESSION_TIME_FILTER_SLOT_TOTAL; i++)
  {
    g_session_time_filter_slot_active[i]     = false;
    g_session_time_filter_slot_prev_state[i] = false;
  }
}

void SessionTimeFilterRefreshWindowState()
{
  SessionTimeFilterEnsureInitialized();

  datetime day_anchor = iTime(_Symbol, PERIOD_D1, 0);
  if(day_anchor <= 0)
  {
    datetime now = TimeCurrent();
    day_anchor = (datetime)((long)now - ((long)now % 86400));
  }

  if(day_anchor != g_session_time_filter_last_day_anchor)
  {
    g_session_time_filter_last_day_anchor = day_anchor;
    SessionTimeFilterResetSlotState();
    for(int i = 0; i < SESSION_TIME_FILTER_SLOT_TOTAL; i++)
      g_session_time_filter_invalid_warned[i] = false;
    g_session_time_filter_block_logged = false;
  }

  g_session_time_filter_any_enabled = SessionTimeFilterAnyEnabled();
  if(!g_session_time_filter_any_enabled)
  {
    g_session_time_filter_window_active = true;
    g_session_time_filter_active_slot   = -1;
    SessionTimeFilterResetSlotState();
    return;
  }

  int current_minutes = SessionTimeFilterCurrentMinutes();
  g_session_time_filter_active_slot   = -1;
  g_session_time_filter_window_active = false;

  for(int slot = 0; slot < SESSION_TIME_FILTER_SLOT_TOTAL; slot++)
  {
    const SessionTimeFilterConfig *config = SessionTimeFilterConfigForSlot(slot);
    bool slot_enabled = SessionTimeFilterSlotEnabled(*config);
    bool slot_active  = false;

    if(slot_enabled)
    {
      if(!config->valid_range && !g_session_time_filter_invalid_warned[slot])
      {
        if(Enable_Logs)
        {
          PrintFormat("Session filter range invalid for %s | range=%s | defaulting to full trading day",
                      config->label,
                      config->raw_range);
        }
        g_session_time_filter_invalid_warned[slot] = true;
      }

      slot_active = SessionTimeFilterMinuteInRange(*config, current_minutes);
      if(slot_active && g_session_time_filter_active_slot < 0)
        g_session_time_filter_active_slot = slot;
      if(slot_active)
        g_session_time_filter_window_active = true;
    }

    g_session_time_filter_slot_active[slot] = slot_active;
  }
}

bool SessionTimeFilterAllowsSignalAttempt()
{
  SessionTimeFilterRefreshWindowState();

  if(!g_session_time_filter_any_enabled)
    return true;

  if(g_session_time_filter_window_active)
  {
    g_session_time_filter_block_logged = false;
    return true;
  }

  if(!g_session_time_filter_block_logged && Enable_Logs)
  {
    Print("Session filter blocked new signals: outside configured session windows.");
    g_session_time_filter_block_logged = true;
  }
  return false;
}

void SessionTimeFilterMonitorRuntime()
{
  SessionTimeFilterRefreshWindowState();

  if(!g_session_time_filter_any_enabled)
    return;

  for(int slot = 0; slot < SESSION_TIME_FILTER_SLOT_TOTAL; slot++)
  {
    bool current_state = g_session_time_filter_slot_active[slot];
    bool previous_state = g_session_time_filter_slot_prev_state[slot];

    if(current_state == previous_state)
      continue;

    g_session_time_filter_slot_prev_state[slot] = current_state;

    if(current_state)
      continue;

    const SessionTimeFilterConfig *config = SessionTimeFilterConfigForSlot(slot);
    if(config->mode != SESSION_FILTER_FORCE_CLOSE)
      continue;

    string reason = StringFormat("Session filter close: %s", config->label);
    if(Enable_Logs)
      PrintFormat("Session filter exit triggered | session=%s", config->label);
    SessionTimeFilterQueueForceClose(reason);
  }
}

bool SessionTimeFilterWindowIsOpen()
{
  SessionTimeFilterRefreshWindowState();
  if(!g_session_time_filter_any_enabled)
    return true;
  return g_session_time_filter_window_active;
}

string SessionTimeFilterActiveSessionLabel()
{
  SessionTimeFilterRefreshWindowState();
  if(!g_session_time_filter_any_enabled)
    return "ALL HOURS";
  if(g_session_time_filter_active_slot < 0)
    return "OUTSIDE";

  const SessionTimeFilterConfig *config =
    SessionTimeFilterConfigForSlot(g_session_time_filter_active_slot);
  return config->label;
}

void SessionTimeFilterQueueForceClose(const string reason)
{
  int total = ArraySize(g_session_time_filter_force_close_queue);
  ArrayResize(g_session_time_filter_force_close_queue, total + 1);
  g_session_time_filter_force_close_queue[total] = reason;
}

bool SessionTimeFilterConsumeForceClose(string &reason)
{
  int total = ArraySize(g_session_time_filter_force_close_queue);
  if(total <= 0)
    return false;

  reason = g_session_time_filter_force_close_queue[0];
  for(int i = 1; i < total; i++)
    g_session_time_filter_force_close_queue[i-1] = g_session_time_filter_force_close_queue[i];
  ArrayResize(g_session_time_filter_force_close_queue, total - 1);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_SESSION_TIME_FILTER_MANAGER_MQH_
