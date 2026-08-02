//+------------------------------------------------------------------+
//|                         market_signal_state.mqh                  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_

bool g_forced_stop_triggered = false;
bool g_debug_no_money_abort_pending = false;

struct DailySignalStats
{
  datetime day_start;
  int total_signals;
  int losing_signals;

  DailySignalStats()
  {
    day_start = 0;
    total_signals = 0;
    losing_signals = 0;
  }
};

DailySignalStats g_daily_signal_stats[2];

int DirectionIndex(const SignalTypes direction)
{
  return (direction == BEARISH) ? 1 : 0;
}

datetime ResolveCurrentDayStart()
{
  datetime day = iTime(_Symbol, PERIOD_D1, 0);
  if(day <= 0)
  {
    datetime now = TimeCurrent();
    day = (datetime)((long)now - ((long)now % 86400));
  }
  return day;
}

void DailySignalStatsEnsureDay(const SignalTypes direction)
{
  if(direction != BULLISH && direction != BEARISH)
    return;

  int index = DirectionIndex(direction);
  datetime day = ResolveCurrentDayStart();
  if(g_daily_signal_stats[index].day_start == day)
    return;

  g_daily_signal_stats[index].day_start = day;
  g_daily_signal_stats[index].total_signals = 0;
  g_daily_signal_stats[index].losing_signals = 0;
}

bool DailySignalLimitAllowsAttempt(const SignalTypes direction)
{
  if(Daily_Signal_Limit <= 0)
    return true;
  if(direction != BULLISH && direction != BEARISH)
    return false;

  DailySignalStatsEnsureDay(direction);
  DailySignalStats stats = g_daily_signal_stats[DirectionIndex(direction)];
  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS_ON_LOSS)
    return stats.losing_signals < Daily_Signal_Limit;
  return stats.total_signals < Daily_Signal_Limit;
}

bool RegisterPivotHftDailySignalStart(const SignalTypes direction,
                                      bool &daily_start_registered)
{
  if(daily_start_registered)
    return false;
  if(direction != BULLISH && direction != BEARISH)
    return false;

  daily_start_registered = true;
  if(Daily_Signal_Limit <= 0)
    return true;

  DailySignalStatsEnsureDay(direction);
  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS)
    g_daily_signal_stats[DirectionIndex(direction)].total_signals++;
  return true;
}

void RegisterDailySignalOutcome(const SignalTypes direction,
                                const double net_result)
{
  if(Daily_Signal_Limit <= 0 ||
     Daily_Signal_Limit_Mode != STOP_DAILY_SIGNALS_ON_LOSS ||
     (direction != BULLISH && direction != BEARISH))
    return;

  DailySignalStatsEnsureDay(direction);
  if(net_result < 0.0)
    g_daily_signal_stats[DirectionIndex(direction)].losing_signals++;
}

void DebugForceCloseAllPositions()
{
  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    ResetLastError();
    bool closed = g_position.PositionClose(position_ticket);
    PivotHftAuditLog(closed ? "DEBUG_CLOSE_SENT" : "DEBUG_CLOSE_FAILED",
                     StringFormat("ticket=%I64u|ret=%I64u|err=%d",
                                  position_ticket,
                                  g_position.ResultRetcode(),
                                  GetLastError()));
  }
}

bool DebugEquityGuardAllowsProcessing()
{
  if(!Debug_Stop_On_Negative_Equity || MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  if(g_debug_no_money_abort_pending)
  {
    g_forced_stop_triggered = true;
    g_debug_no_money_abort_pending = false;
    PivotHftAuditLog("DEBUG_STOP",
                     StringFormat("reason=no_money|equity=%.2f|balance=%.2f",
                                  AccountInfoDouble(ACCOUNT_EQUITY),
                                  AccountInfoDouble(ACCOUNT_BALANCE)));
    DebugForceCloseAllPositions();
    TesterStop();
    return false;
  }

  if(AccountInfoDouble(ACCOUNT_EQUITY) <= 0.0)
  {
    g_forced_stop_triggered = true;
    PivotHftAuditLog("DEBUG_STOP",
                     StringFormat("reason=negative_equity|equity=%.2f|balance=%.2f",
                                  AccountInfoDouble(ACCOUNT_EQUITY),
                                  AccountInfoDouble(ACCOUNT_BALANCE)));
    DebugForceCloseAllPositions();
    TesterStop();
    return false;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
