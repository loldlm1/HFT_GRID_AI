#ifndef _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_

MarketStatusTypes g_market_status = MARKET_STATUS_ACTIVE;
string            g_market_status_reason = "";
datetime          g_market_status_updated = 0;
bool              g_market_force_close_pending = false;
string            g_market_force_close_reason = "";

string MarketStatusToString(const MarketStatusTypes status)
{
  switch(status)
  {
    case MARKET_STATUS_CLOSE_GUARD:
      return "CLOSE_GUARD";
    case MARKET_STATUS_BROKER_CLOSEONLY:
      return "BROKER_CLOSEONLY";
    case MARKET_STATUS_BROKER_DISABLED:
      return "BROKER_DISABLED";
    case MARKET_STATUS_ACTIVE:
    default:
      return "ACTIVE";
  }
}

void MarketStatusLogChange(const MarketStatusTypes status,
                           const string reason)
{
  PrintFormat("Market status updated | status=%s | reason=%s",
              MarketStatusToString(status),
              reason);
}

void MarketStatusUpdate(const MarketStatusTypes status,
                        const string reason)
{
  if(g_market_status == status && g_market_status_reason == reason)
    return;

  g_market_status = status;
  g_market_status_reason = reason;
  g_market_status_updated = TimeCurrent();

  MarketStatusLogChange(status, reason);
}

MarketStatusTypes MarketStatusGet()
{
  return g_market_status;
}

datetime MarketStatusLastChangeTime()
{
  return g_market_status_updated;
}

string MarketStatusReason()
{
  return g_market_status_reason;
}

bool MarketStatusAllowsSignalAttempts()
{
  return (g_market_status == MARKET_STATUS_ACTIVE);
}

bool MarketStatusAllowsBrokerActions()
{
  return (g_market_status == MARKET_STATUS_ACTIVE) ||
         (g_market_status == MARKET_STATUS_CLOSE_GUARD) ||
         (g_market_status == MARKET_STATUS_BROKER_CLOSEONLY);
}

void MarketStatusRequestForceClose(const string reason)
{
  if(g_market_force_close_pending && g_market_force_close_reason == reason)
    return;

  g_market_force_close_pending = true;
  g_market_force_close_reason  = reason;
  //PrintFormat("Force close scheduled | reason=%s", reason);
}

bool MarketStatusHasPendingForceClose()
{
  return g_market_force_close_pending;
}

string MarketStatusPendingReason()
{
  return g_market_force_close_reason;
}

void MarketStatusClearForceCloseRequest()
{
  g_market_force_close_pending = false;
  g_market_force_close_reason  = "";
}

bool MarketStatusRetcodeImpliesClosure(const ulong retcode,
                                       const int last_error)
{
  if(retcode == TRADE_RETCODE_MARKET_CLOSED ||
     retcode == TRADE_RETCODE_TRADE_DISABLED)
    return true;

  if(last_error == ERR_TRADE_DISABLED)
    return true;

  return false;
}

void MarketStatusRegisterBrokerFailure(const string context,
                                       const ulong retcode,
                                       const int last_error,
                                       const bool requires_force_close)
{
  if(!MarketStatusRetcodeImpliesClosure(retcode, last_error))
    return;

  MarketStatusUpdate(MARKET_STATUS_BROKER_DISABLED, context);
  if(requires_force_close)
    MarketStatusRequestForceClose(context);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_
