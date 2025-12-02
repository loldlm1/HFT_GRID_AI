//+------------------------------------------------------------------+
//|                           protection_risk_filter.mqh             |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PROTECTION_RISK_FILTER_MQH_
#define _SERVICES_TRADING_SIGNALS_PROTECTION_RISK_FILTER_MQH_

double   g_protection_last_drawdown      = 0.0;
double   g_protection_last_threshold     = 0.0;
bool     g_protection_daily_lock_active  = false;
datetime g_protection_daily_lock_anchor  = 0;
bool     g_market_close_guard_active     = false;
datetime g_market_close_guard_session_end = 0;
datetime g_market_close_guard_trigger_time = 0;

double ProtectionRiskResolveThreshold()
{
  double safe_value = MathAbs(Protection_Risk_Drawdown_Value);
  if(Protection_Risk_Mode == ENABLED_OFF || safe_value <= 0.0)
    return 0.0;

  double base_amount = 0.0;
  switch(Protection_Risk_Drawdown_Type)
  {
    case PROTECTION_RISK_ACCOUNT_SIZE_PERCENT:
    {
      base_amount = MathAbs(Account_Size);
      if(base_amount <= 0.0)
        base_amount = MathAbs(AccountInfoDouble(ACCOUNT_BALANCE));
      return base_amount * (safe_value / 100.0);
    }
    case PROTECTION_RISK_ACCOUNT_BALANCE_PERCENT:
    {
      base_amount = MathAbs(AccountInfoDouble(ACCOUNT_BALANCE));
      if(base_amount <= 0.0)
        base_amount = MathAbs(Account_Size);
      return base_amount * (safe_value / 100.0);
    }
    case PROTECTION_RISK_FIXED_CURRENCY:
      return safe_value;
  }
  return 0.0;
}

double ProtectionRiskCollectDrawdown()
{
  double net_profit = 0.0;
  int total_positions = PositionsTotal();

  for(int i = total_positions-1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;

    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_symbol != _Symbol)
      continue;

    double position_profit = PositionGetDouble(POSITION_PROFIT);
    net_profit += position_profit;
  }

  if(net_profit >= 0.0)
    return 0.0;
  return MathAbs(net_profit);
}

void ProtectionRiskForceClosePositions()
{
  int total_positions = PositionsTotal();
  for(int i = total_positions-1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;

    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_symbol != _Symbol)
      continue;

    if(!g_position.PositionClose(position_ticket))
    {
      PrintFormat("ProtectionRiskForceClosePositions failed | ticket=%I64u | err=%d",
                  position_ticket,
                  GetLastError());
    }
  }
}

void ProtectionRiskForceCloseSignalArray(SignalParams &signals[],
                                         const SignalTypes direction)
{
  int total_signals = ArraySize(signals);
  if(total_signals <= 0)
    return;

  double point_size = GridResolvePointSize();
  double close_price = (direction == BULLISH) ? g_bid : g_ask;
  datetime close_time = TimeCurrent();

  for(int i = total_signals-1; i >= 0; i--)
  {
    if(signals[i].grid_initialized)
      GridCloseAllLevels(signals[i], point_size);

    signals[i].signal_state = CLOSED;
    signals[i].close_time   = close_time;
    signals[i].close_price  = close_price;
    if(signals[i].entry_price > 0.0 && close_price > 0.0)
      signals[i].raw_profit = RawProfitUsd(direction,
                                           signals[i].entry_price,
                                           close_price);

    if(direction == BULLISH)
      CloseBullishSignal(signals[i]);
    else
      CloseBearishSignal(signals[i]);

    RemoveElementFromArray(signals, i);
  }
}

void ProtectionRiskEnforceDrawdownGuard()
{
  ProtectionRiskForceCloseSignalArray(running_bullish_signals, BULLISH);
  ProtectionRiskForceCloseSignalArray(running_bearish_signals, BEARISH);
  ProtectionRiskForceClosePositions();
}

bool ProtectionRiskHasActiveEntities()
{
  if(ArraySize(running_bullish_signals) > 0)
    return true;
  if(ArraySize(running_bearish_signals) > 0)
    return true;

  int total_positions = PositionsTotal();
  for(int i = total_positions-1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;
    long position_magic = PositionGetInteger(POSITION_MAGIC);
    if(position_magic != g_magic_number)
      continue;
    string position_symbol = PositionGetString(POSITION_SYMBOL);
    if(position_symbol != _Symbol)
      continue;
    return true;
  }
  return false;
}

void ProtectionRiskProcessPendingForceClose()
{
  if(!MarketStatusHasPendingForceClose())
    return;
  if(!MarketStatusAllowsBrokerActions())
    return;

  ProtectionRiskEnforceDrawdownGuard();
  if(!ProtectionRiskHasActiveEntities())
    MarketStatusClearForceCloseRequest();
}

void ProtectionRiskScheduleForceClose(const string reason)
{
  MarketStatusRequestForceClose(reason);
  ProtectionRiskProcessPendingForceClose();
}

void ProtectionRiskResetDailyLock()
{
  if(!g_protection_daily_lock_active)
    return;

  ENUM_TIMEFRAMES anchor_tf = PERIOD_D1;
  if(Protection_Risk_Mode == ENABLED_GRID_PROTECTION_WEEKLY)
    anchor_tf = PERIOD_W1;

  datetime current_anchor = iTime(_Symbol, anchor_tf, 0);
  if(current_anchor == 0)
    return;

  if(current_anchor != g_protection_daily_lock_anchor)
  {
    g_protection_daily_lock_active = false;
    g_protection_daily_lock_anchor = current_anchor;
  }
}

void ProtectionRiskResetMarketCloseGuard()
{
  bool was_active = g_market_close_guard_active;
  g_market_close_guard_active      = false;
  g_market_close_guard_session_end = 0;
  g_market_close_guard_trigger_time = 0;

  if(was_active && MarketStatusGet() == MARKET_STATUS_CLOSE_GUARD)
    MarketStatusUpdate(MARKET_STATUS_ACTIVE, "Market close guard cleared");
}

void ProtectionRiskCheckMarketCloseGuard()
{
  datetime session_from = 0;
  datetime session_to = 0;
  datetime trigger_time = 0;

  if(!ResolveCurrentSessionWindow(session_from, session_to))
  {
    ProtectionRiskResetMarketCloseGuard();
    return;
  }

  if(!ResolveSessionPreCloseTrigger(session_to, Market_Close_Guard_Timeframe, trigger_time))
  {
    ProtectionRiskResetMarketCloseGuard();
    return;
  }

  if(session_to != g_market_close_guard_session_end)
  {
    g_market_close_guard_active = false;
    g_market_close_guard_trigger_time = 0;
  }

  g_market_close_guard_session_end = session_to;
  g_market_close_guard_trigger_time = trigger_time;

  datetime current_time = TimeCurrent();
  if(current_time >= trigger_time && current_time < session_to)
  {
    if(!g_market_close_guard_active)
    {
      PrintFormat("Market close guard triggered | session_end=%s | trigger=%s | timeframe=%d",
                  TimeToString(session_to, TIME_DATE|TIME_SECONDS),
                  TimeToString(trigger_time, TIME_DATE|TIME_SECONDS),
                  Market_Close_Guard_Timeframe);
    }
    g_market_close_guard_active = true;

    if(MarketStatusGet() != MARKET_STATUS_BROKER_CLOSEONLY &&
       MarketStatusGet() != MARKET_STATUS_BROKER_DISABLED)
    {
      string reason = StringFormat("Session close guard | trigger=%s | close=%s",
                                   TimeToString(trigger_time, TIME_SECONDS),
                                   TimeToString(session_to, TIME_SECONDS));
      MarketStatusUpdate(MARKET_STATUS_CLOSE_GUARD, reason);
    }
    ProtectionRiskScheduleForceClose("Market close guard");
    return;
  }

  if(current_time >= session_to)
  {
    ProtectionRiskResetMarketCloseGuard();
    return;
  }
}

void ProtectionRiskMonitorTradeMode()
{
  ENUM_SYMBOL_TRADE_MODE trade_mode =
    (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);

  if(trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
  {
    MarketStatusUpdate(MARKET_STATUS_BROKER_CLOSEONLY, "Symbol trade mode close-only");
    ProtectionRiskScheduleForceClose("Broker close-only mode");
    return;
  }

  if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
  {
    MarketStatusUpdate(MARKET_STATUS_BROKER_DISABLED, "Symbol trade mode disabled");
    ProtectionRiskScheduleForceClose("Broker disabled mode");
    return;
  }

  if(g_market_close_guard_active)
  {
    if(MarketStatusGet() != MARKET_STATUS_CLOSE_GUARD)
      MarketStatusUpdate(MARKET_STATUS_CLOSE_GUARD, "Market close guard active");
    return;
  }

  if(MarketStatusGet() != MARKET_STATUS_ACTIVE)
    MarketStatusUpdate(MARKET_STATUS_ACTIVE, "Trading restored");
}

void ProtectionRiskFilterTick()
{
  ProtectionRiskResetDailyLock();
  //ProtectionRiskCheckMarketCloseGuard();
  ProtectionRiskProcessPendingForceClose();
  if(Protection_Risk_Mode == ENABLED_OFF)
    return;

  double threshold = ProtectionRiskResolveThreshold();
  g_protection_last_threshold = threshold;
  if(threshold <= 0.0)
    return;

  double drawdown = ProtectionRiskCollectDrawdown();
  g_protection_last_drawdown = drawdown;

  if(drawdown < threshold)
    return;

  PrintFormat("ProtectionRiskFilter triggered | drawdown=%.2f | threshold=%.2f | mode=%d",
              drawdown,
              threshold,
              Protection_Risk_Mode);

  ProtectionRiskEnforceDrawdownGuard();
  if(ProtectionRiskHasActiveEntities())
    ProtectionRiskScheduleForceClose("Drawdown guard pending close");

  if(Protection_Risk_Mode == ENABLED_GRID_PROTECTION_DAILY)
  {
    g_protection_daily_lock_active = true;
    g_protection_daily_lock_anchor = iTime(_Symbol, PERIOD_D1, 0);
  }
  if(Protection_Risk_Mode == ENABLED_GRID_PROTECTION_WEEKLY)
  {
    g_protection_daily_lock_active = true;
    g_protection_daily_lock_anchor = iTime(_Symbol, PERIOD_W1, 0);
  }
}

bool ProtectionRiskAllowsSignalAttempt()
{
  ProtectionRiskResetDailyLock();
  if(!MarketStatusAllowsSignalAttempts())
    return false;
  if(Protection_Risk_Mode == ENABLED_OFF)
    return true;
  if((Protection_Risk_Mode == ENABLED_GRID_PROTECTION_DAILY ||
      Protection_Risk_Mode == ENABLED_GRID_PROTECTION_WEEKLY) &&
     g_protection_daily_lock_active)
    return false;

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PROTECTION_RISK_FILTER_MQH_
