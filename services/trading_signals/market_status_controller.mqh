#ifndef _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_

MarketStatusTypes g_market_status = MARKET_STATUS_ACTIVE;
string            g_market_status_reason = "";
datetime          g_market_status_updated = 0;
bool              g_market_force_close_pending = false;
string            g_market_force_close_reason = "";
ulong             g_market_force_close_generation = 0;
datetime          g_market_force_close_last_time = 0;
string            g_market_force_close_last_reason = "";
datetime          g_market_force_close_last_attempt_time = 0;
bool              g_market_force_close_scoped = false;
ulong             g_market_force_close_target_ticket = 0;
ulong             g_market_force_close_target_identifier = 0;
bool              g_market_platform_trade_allowed = true;
string            g_market_platform_trade_reason = "";
datetime          g_market_platform_trade_updated = 0;
bool              g_market_error_active = false;
string            g_market_error_context = "";
string            g_market_error_detail = "";
ulong             g_market_error_retcode = 0;
int               g_market_error_last_error = 0;
datetime          g_market_error_time = 0;
string            g_market_last_error_context = "";
string            g_market_last_error_detail = "";
ulong             g_market_last_error_retcode = 0;
int               g_market_last_error_last_error = 0;
datetime          g_market_last_error_time = 0;

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
    case MARKET_STATUS_PLATFORM_DISABLED:
      return "PLATFORM_DISABLED";
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
  PivotHftAuditLog("MARKET_STATUS",
                   StringFormat("status=%s|reason=%s",
                                MarketStatusToString(status),
                                reason));
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

void MarketStatusRegisterExecutionError(const string context,
                                        const string detail,
                                        const ulong retcode,
                                        const int last_error)
{
  datetime now_time = TimeCurrent();

  g_market_error_active     = true;
  g_market_error_context    = context;
  g_market_error_detail     = detail;
  g_market_error_retcode    = retcode;
  g_market_error_last_error = last_error;
  g_market_error_time       = now_time;

  g_market_last_error_context    = context;
  g_market_last_error_detail     = detail;
  g_market_last_error_retcode    = retcode;
  g_market_last_error_last_error = last_error;
  g_market_last_error_time       = now_time;
}

void MarketStatusClearExecutionError(const string reason)
{
  string clear_reason = reason;
  if(!g_market_error_active)
    return;

  if(clear_reason == "")
    clear_reason = "cleared";

  g_market_error_active     = false;
  g_market_error_context    = "";
  g_market_error_detail     = "";
  g_market_error_retcode    = 0;
  g_market_error_last_error = 0;
  g_market_error_time       = TimeCurrent();
}

string MarketStatusBuildErrorSummary(const bool active,
                                     const string context,
                                     const string detail,
                                     const ulong retcode,
                                     const int last_error,
                                     const datetime error_time)
{
  string prefix = active ? "Error: ACTIVE " : "Last error: ";
  string text = prefix + context;

  if(retcode > 0)
    text = text + StringFormat(" ret=%I64u", retcode);
  if(last_error > 0)
    text = text + StringFormat(" err=%d", last_error);
  if(detail != "")
    text = text + " " + detail;
  if(error_time > 0)
    text = text + " @" + TimeToString(error_time, TIME_SECONDS);

  int max_len = 110;
  if(StringLen(text) > max_len)
    text = StringSubstr(text, 0, max_len - 3) + "...";
  return text;
}

string MarketStatusErrorSummary()
{
  if(g_market_error_active)
  {
    return MarketStatusBuildErrorSummary(true,
                                         g_market_error_context,
                                         g_market_error_detail,
                                         g_market_error_retcode,
                                         g_market_error_last_error,
                                         g_market_error_time);
  }

  if(g_market_last_error_context != "")
  {
    return MarketStatusBuildErrorSummary(false,
                                         g_market_last_error_context,
                                         g_market_last_error_detail,
                                         g_market_last_error_retcode,
                                         g_market_last_error_last_error,
                                         g_market_last_error_time);
  }

  return "Error: OK";
}

string MarketStatusResolvePlatformTradeReason()
{
  if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
    return "Algo Trading disabled";
  if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
    return "EA trading disabled";
  if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
    return "Account trading disabled";
  if(AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0)
    return "Expert trading disabled by account";

  return "";
}

bool MarketStatusRefreshPlatformTradePermission()
{
  string reason = MarketStatusResolvePlatformTradeReason();
  bool allowed = (reason == "");
  bool previous_allowed = g_market_platform_trade_allowed;

  if(g_market_platform_trade_allowed == allowed &&
     g_market_platform_trade_reason == reason)
    return allowed;

  g_market_platform_trade_allowed = allowed;
  g_market_platform_trade_reason  = reason;
  g_market_platform_trade_updated = TimeCurrent();

  if(!allowed)
    MarketStatusRegisterExecutionError("PLATFORM_DISABLED", reason, 0, 0);
  else if(!previous_allowed)
    MarketStatusClearExecutionError("Platform trading restored");

  return allowed;
}

bool MarketStatusPlatformTradeAllowed()
{
  return g_market_platform_trade_allowed;
}

string MarketStatusPlatformTradeReason()
{
  return g_market_platform_trade_reason;
}

bool MarketStatusCanShowPlatformDisabled()
{
  return (g_market_status == MARKET_STATUS_ACTIVE ||
          g_market_status == MARKET_STATUS_PLATFORM_DISABLED);
}

bool MarketStatusAllowsSignalAttempts()
{
  if(!g_market_platform_trade_allowed)
    return false;
  return (g_market_status == MARKET_STATUS_ACTIVE);
}

bool MarketStatusAllowsBrokerActions()
{
  if(!g_market_platform_trade_allowed)
    return false;

  return (g_market_status == MARKET_STATUS_ACTIVE) ||
         (g_market_status == MARKET_STATUS_CLOSE_GUARD) ||
         (g_market_status == MARKET_STATUS_BROKER_CLOSEONLY);
}

void MarketStatusRequestForceCloseInternal(
  const string reason,
  const bool scoped,
  const ulong position_ticket,
  const ulong position_identifier)
{
  if(g_market_force_close_pending &&
     !g_market_force_close_scoped &&
     scoped)
    return;

  if(g_market_force_close_pending &&
     g_market_force_close_reason == reason &&
     g_market_force_close_scoped == scoped &&
     g_market_force_close_target_ticket == position_ticket &&
     g_market_force_close_target_identifier == position_identifier)
    return;

  g_market_force_close_pending = true;
  g_market_force_close_reason  = reason;
  g_market_force_close_scoped = scoped;
  g_market_force_close_target_ticket = position_ticket;
  g_market_force_close_target_identifier = position_identifier;
  g_market_force_close_generation++;
  g_market_force_close_last_time = TimeCurrent();
  g_market_force_close_last_reason = reason;
  g_market_force_close_last_attempt_time = 0;
  PivotHftAuditLog("FORCE_CLOSE_SCHEDULED",
                   StringFormat("reason=%s|generation=%I64u|scoped=%d|ticket=%I64u|position_id=%I64u",
                                reason,
                                g_market_force_close_generation,
                                (int)scoped,
                                position_ticket,
                                position_identifier));
  //PrintFormat("Force close scheduled | reason=%s", reason);
}

void MarketStatusRequestForceClose(const string reason)
{
  MarketStatusRequestForceCloseInternal(reason, false, 0, 0);
}

void MarketStatusRequestScopedForceClose(
  const string reason,
  const ulong position_ticket,
  const ulong position_identifier)
{
  bool scoped = (position_ticket > 0 || position_identifier > 0);
  MarketStatusRequestForceCloseInternal(reason,
                                        scoped,
                                        position_ticket,
                                        position_identifier);
}

bool MarketStatusHasPendingForceClose()
{
  return g_market_force_close_pending;
}

string MarketStatusPendingReason()
{
  return g_market_force_close_reason;
}

bool MarketStatusForceCloseIsScoped()
{
  return g_market_force_close_scoped;
}

ulong MarketStatusForceCloseTargetTicket()
{
  return g_market_force_close_target_ticket;
}

ulong MarketStatusForceCloseTargetIdentifier()
{
  return g_market_force_close_target_identifier;
}

bool MarketStatusForceCloseMatchesPosition(
  const ulong position_ticket,
  const ulong position_identifier)
{
  if(!g_market_force_close_scoped)
    return true;
  if(g_market_force_close_target_identifier > 0)
    return (position_identifier == g_market_force_close_target_identifier);
  return (position_ticket == g_market_force_close_target_ticket);
}

bool MarketStatusForceCloseAttemptAllowed()
{
  if(!g_market_force_close_pending)
    return false;
  datetime now_time = TimeCurrent();
  return (g_market_force_close_last_attempt_time == 0 ||
          now_time > g_market_force_close_last_attempt_time);
}

void MarketStatusMarkForceCloseAttempt()
{
  g_market_force_close_last_attempt_time = TimeCurrent();
}

ulong MarketStatusForceCloseGeneration()
{
  return g_market_force_close_generation;
}

datetime MarketStatusLastForceCloseTime()
{
  return g_market_force_close_last_time;
}

string MarketStatusLastForceCloseReason()
{
  return g_market_force_close_last_reason;
}

void MarketStatusClearForceCloseRequest()
{
  g_market_force_close_pending = false;
  g_market_force_close_reason  = "";
  g_market_force_close_scoped = false;
  g_market_force_close_target_ticket = 0;
  g_market_force_close_target_identifier = 0;
  g_market_force_close_last_attempt_time = 0;
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
  MarketStatusRegisterExecutionError(context, "", retcode, last_error);

  if(!MarketStatusRetcodeImpliesClosure(retcode, last_error))
    return;

  MarketStatusUpdate(MARKET_STATUS_BROKER_DISABLED, context);
  if(requires_force_close)
    MarketStatusRequestForceClose(context);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_STATUS_CONTROLLER_MQH_
