//+------------------------------------------------------------------+
//|                         pandora_box_state.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_

const int PANDORA_MINUTES_PER_DAY = 24 * 60;
const double PANDORA_EPSILON_EXTREME_BOX_RATIO = 5.0;
const int PANDORA_HISTORY_DAYS = 8;
const int PANDORA_TRADE_MARKER_MAX = 64;
const string PANDORA_INVALID_PREVIOUS_D1_ANCHOR = "No previous D1 anchor for Pandora wrapped window";

string PandoraLocalEntryStatusLabel(const PandoraLocalEntryStatuses status)
{
  switch(status)
  {
    case PANDORA_LOCAL_ENTRY_PENDING:
      return "Posicion local pendiente";
    case PANDORA_LOCAL_ENTRY_ACTIVE:
      return "Posicion local activa";
    case PANDORA_LOCAL_ENTRY_COMPLETED:
      return "Posicion local cerrada";
    case PANDORA_LOCAL_ENTRY_NONE:
    default:
      return "Posicion local";
  }
}

string PandoraExecutionSourceLabel(const PandoraExecutionSourceStatuses source)
{
  switch(source)
  {
    case PANDORA_EXECUTION_SOURCE_THEORETICAL:
      return "Teorica";
    case PANDORA_EXECUTION_SOURCE_BROKER_SIMULATED:
      return "Broker simulado";
    case PANDORA_EXECUTION_SOURCE_BROKER_FILLED:
      return "Broker fill";
    case PANDORA_EXECUTION_SOURCE_NONE:
    default:
      return "Sin fuente";
  }
}

string PandoraBrokerExecutionStatusLabel(const PandoraBrokerExecutionStatuses status)
{
  switch(status)
  {
    case PANDORA_BROKER_BLOCKED:
      return "Broker bloqueado";
    case PANDORA_BROKER_REJECTED:
      return "Broker rechazado";
    case PANDORA_BROKER_RETRY_PENDING:
      return "Broker retry pendiente";
    case PANDORA_BROKER_EXECUTED:
      return "Posicion ejecutada";
    case PANDORA_BROKER_CLOSED:
      return "Posicion broker cerrada";
    case PANDORA_BROKER_NOT_ATTEMPTED:
    default:
      return "Broker sin intento";
  }
}

string PandoraBrokerStopSyncStatusLabel(const PandoraBrokerStopSyncStatuses status)
{
  switch(status)
  {
    case PANDORA_BROKER_STOPS_NOT_REQUIRED:
      return "Stops broker no requeridos";
    case PANDORA_BROKER_STOPS_PENDING:
      return "Stops broker pendientes";
    case PANDORA_BROKER_STOPS_WIDE:
      return "Stops broker amplios";
    case PANDORA_BROKER_STOPS_TARGETED:
      return "Stops broker objetivo";
    case PANDORA_BROKER_STOPS_FAILED:
      return "Stops broker fallidos";
    case PANDORA_BROKER_STOPS_NONE:
    default:
      return "Stops broker sin estado";
  }
}

string PandoraLocalCloseMarkerLabel(const PandoraLocalCloseMarkers marker)
{
  switch(marker)
  {
    case PANDORA_LOCAL_CLOSE_VIRTUAL:
      return "Cierre local virtual";
    case PANDORA_LOCAL_CLOSE_BROKER:
      return "Cierre broker";
    case PANDORA_LOCAL_CLOSE_LOCAL_REJECTED:
      return "Rechazo local";
    case PANDORA_LOCAL_CLOSE_NONE:
    default:
      return "";
  }
}

bool PandoraTextContains(const string text,
                         const string token)
{
  if(token == "")
    return false;
  return (StringFind(text, token) >= 0);
}

string PandoraRetcodeShortLabel(const ulong retcode)
{
  switch((int)retcode)
  {
    case TRADE_RETCODE_INVALID_STOPS:
      return "ERR_Stops";
    case TRADE_RETCODE_INVALID_VOLUME:
    case TRADE_RETCODE_LIMIT_VOLUME:
      return "ERR_Volumen";
    case TRADE_RETCODE_NO_MONEY:
      return "ERR_Margen";
    case TRADE_RETCODE_MARKET_CLOSED:
      return "ERR_Mercado";
    case TRADE_RETCODE_TRADE_DISABLED:
    case TRADE_RETCODE_SERVER_DISABLES_AT:
    case TRADE_RETCODE_CLIENT_DISABLES_AT:
      return "ERR_Trading";
    case TRADE_RETCODE_PRICE_CHANGED:
    case TRADE_RETCODE_PRICE_OFF:
    case TRADE_RETCODE_INVALID_PRICE:
    case TRADE_RETCODE_REQUOTE:
      return "ERR_Precio";
    case TRADE_RETCODE_TIMEOUT:
      return "ERR_Timeout";
    case TRADE_RETCODE_TOO_MANY_REQUESTS:
      return "ERR_Frecuencia";
    case TRADE_RETCODE_INVALID_FILL:
      return "ERR_Fill";
    case TRADE_RETCODE_CONNECTION:
      return "ERR_Conexion";
    case TRADE_RETCODE_ERROR:
      return "ERR_Send_Failed";
    case TRADE_RETCODE_REJECT:
    case TRADE_RETCODE_CANCEL:
    case TRADE_RETCODE_INVALID:
    default:
      break;
  }

  if(retcode > 0)
    return "ERR_Broker";
  return "";
}

string PandoraBrokerRejectReasonLabel(const string context,
                                      const string detail,
                                      const ulong retcode)
{
  string combined = context + " " + detail;

  if(PandoraTextContains(combined, "spread") ||
     PandoraTextContains(combined, "Spread") ||
     PandoraTextContains(combined, "SPREAD"))
    return "ERR_Spread";

  if(PandoraTextContains(combined, "margin") ||
     PandoraTextContains(combined, "Margin") ||
     PandoraTextContains(combined, "MARGIN"))
    return "ERR_Margen";

  string retcode_label = PandoraRetcodeShortLabel(retcode);
  if(retcode_label != "")
    return retcode_label;

  if(context != "" || detail != "")
    return "ERR_Local";
  return "ERR_Broker";
}

string PandoraBrokerRejectSummary(const string context,
                                  const string detail,
                                  const ulong retcode,
                                  const int last_error)
{
  string summary = PandoraBrokerRejectReasonLabel(context, detail, retcode);
  if(retcode > 0)
    summary = summary + StringFormat(" ret=%I64u", retcode);
  if(last_error > 0)
    summary = summary + StringFormat(" err=%d", last_error);
  if(context != "")
    summary = summary + " " + context;
  if(detail != "")
    summary = summary + " " + detail;

  int max_len = 96;
  if(StringLen(summary) > max_len)
    summary = StringSubstr(summary, 0, max_len - 3) + "...";
  return summary;
}

string PandoraPositionExecutionLabel(const PandoraBrokerExecutionStatuses broker_status,
                                     const string rejection_reason)
{
  if(broker_status == PANDORA_BROKER_EXECUTED ||
     broker_status == PANDORA_BROKER_CLOSED)
    return "Posicion ejecutada";

  if(broker_status == PANDORA_BROKER_BLOCKED ||
     broker_status == PANDORA_BROKER_RETRY_PENDING ||
     broker_status == PANDORA_BROKER_REJECTED)
  {
    string reason = rejection_reason;
    if(reason == "")
      reason = "ERR_Broker";
    return "Posicion local - " + reason;
  }

  return "Posicion local";
}

bool PandoraBrokerAttemptAlreadyFinished(const SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return false;
  return (signal_params.pandora_broker_execution_status == PANDORA_BROKER_BLOCKED ||
          signal_params.pandora_broker_execution_status == PANDORA_BROKER_REJECTED ||
          signal_params.pandora_broker_execution_status == PANDORA_BROKER_EXECUTED ||
          signal_params.pandora_broker_execution_status == PANDORA_BROKER_CLOSED);
}

bool PandoraSpreadWithinBrokerRealisticRange()
{
  return (g_points_spread <= Max_Spread);
}

bool PandoraLocalEntryPendingAdmission(const SignalParams &signal_params)
{
  return (IsPandoraSignal(signal_params) &&
          signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_PENDING);
}

double PandoraResolveExecutableEntryPrice(const SignalTypes direction)
{
  double entry_price = GridCurrentPriceForDirection(direction, true);
  if(entry_price > 0.0)
    return entry_price;

  if(direction == BULLISH)
    return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  if(direction == BEARISH)
    return SymbolInfoDouble(_Symbol, SYMBOL_BID);
  return 0.0;
}

bool PandoraBrokerRetcodeAllowsLocalSimulation(const ulong retcode)
{
  switch((int)retcode)
  {
    case TRADE_RETCODE_INVALID_VOLUME:
    case TRADE_RETCODE_LIMIT_VOLUME:
    case TRADE_RETCODE_NO_MONEY:
    case TRADE_RETCODE_MARKET_CLOSED:
    case TRADE_RETCODE_TRADE_DISABLED:
    case TRADE_RETCODE_SERVER_DISABLES_AT:
    case TRADE_RETCODE_CLIENT_DISABLES_AT:
    case TRADE_RETCODE_CLOSE_ONLY:
    case TRADE_RETCODE_LONG_ONLY:
    case TRADE_RETCODE_SHORT_ONLY:
    case TRADE_RETCODE_ONLY_REAL:
    case TRADE_RETCODE_HEDGE_PROHIBITED:
    case TRADE_RETCODE_INVALID_FILL:
    case TRADE_RETCODE_INVALID_ORDER:
    case TRADE_RETCODE_INVALID_EXPIRATION:
    case TRADE_RETCODE_LIMIT_POSITIONS:
    case TRADE_RETCODE_LIMIT_ORDERS:
      return false;
    default:
      break;
  }
  return true;
}

void PandoraResetLocalTargetCache(SignalParams &signal_params,
                                  GridOrderState &order_state)
{
  signal_params.pandora_local_sl_price = 0.0;
  signal_params.pandora_local_tp_price = 0.0;
  signal_params.pandora_broker_sl_target_price = 0.0;
  signal_params.pandora_broker_tp_target_price = 0.0;
  signal_params.pandora_broker_sl_protection_price = 0.0;
  signal_params.pandora_broker_tp_protection_price = 0.0;
  signal_params.pandora_trailing_step_index = 0;
  signal_params.pandora_trailing_stop_price = 0.0;
  order_state.trailing_price = 0.0;
  order_state.is_trailing_active = false;
  order_state.tp_reached = false;
}

void PandoraSetActiveSourceAnchor(SignalParams &signal_params,
                                  GridOrderState &order_state,
                                  const PandoraExecutionSourceStatuses source,
                                  const double entry_price,
                                  const datetime entry_time,
                                  const string position_comment)
{
  if(!IsPandoraSignal(signal_params) || entry_price <= 0.0)
    return;

  datetime resolved_time = entry_time;
  if(resolved_time <= 0)
    resolved_time = TimeCurrent();

  signal_params.pandora_execution_source = source;
  signal_params.pandora_source_entry_price = entry_price;
  signal_params.pandora_source_entry_time = resolved_time;
  signal_params.pandora_local_entry_price = entry_price;
  signal_params.pandora_local_entry_time = resolved_time;
  signal_params.entry_price = entry_price;
  if(signal_params.entry_time <= 0)
    signal_params.entry_time = resolved_time;

  if(source == PANDORA_EXECUTION_SOURCE_BROKER_SIMULATED)
  {
    signal_params.pandora_broker_simulated_entry_price = entry_price;
    signal_params.pandora_broker_simulated_entry_time = resolved_time;
  }
  else if(source == PANDORA_EXECUTION_SOURCE_BROKER_FILLED)
  {
    signal_params.pandora_broker_fill_price = entry_price;
    signal_params.pandora_broker_fill_time = resolved_time;
  }

  signal_params.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_ACTIVE;
  order_state.status = GRID_ORDER_ACTIVE;
  order_state.entry_price = entry_price;
  if(order_state.position_comment == "" && position_comment != "")
    order_state.position_comment = position_comment;
  order_state.last_action_time = resolved_time;

  PandoraResetLocalTargetCache(signal_params, order_state);
}

bool PandoraRefreshLocalTargetPrices(SignalParams &signal_params,
                                     GridOrderState &order_state)
{
  if(!IsPandoraSignal(signal_params))
    return false;
  if(signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_PENDING)
    return false;

  double sl_price = 0.0;
  double tp_price = 0.0;
  if(!PandoraComputeLocalTargetPrices(signal_params, order_state, sl_price, tp_price))
    return false;

  signal_params.pandora_local_sl_price = sl_price;
  signal_params.pandora_local_tp_price = tp_price;
  if(tp_price > 0.0)
    order_state.take_profit_price = tp_price;
  else if(PandoraRiskStepTrailingEnabled())
    order_state.take_profit_price = 0.0;
  return true;
}

bool PandoraAdmitBrokerRealisticLocalEntry(SignalParams &signal_params,
                                           GridOrderState &order_state,
                                           const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return true;
  if(signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_ACTIVE)
    return true;
  if(signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_COMPLETED)
    return false;
  if(!PandoraSpreadWithinBrokerRealisticRange())
    return false;

  double entry_price = PandoraResolveExecutableEntryPrice(signal_params.signal_type);
  if(entry_price <= 0.0)
    return false;

  PandoraSetActiveSourceAnchor(signal_params,
                               order_state,
                               PANDORA_EXECUTION_SOURCE_BROKER_SIMULATED,
                               entry_price,
                               TimeCurrent(),
                               position_comment);
  PandoraRefreshLocalTargetPrices(signal_params, order_state);
  PandoraEnsureTradeMarkerId(signal_params);
  PandoraUpsertTradeMarkerSnapshot(signal_params);
  return true;
}

void PandoraRebaseToBrokerFill(SignalParams &signal_params,
                               GridOrderState &order_state,
                               const double fill_price,
                               const datetime fill_time,
                               const string position_comment)
{
  if(!IsPandoraSignal(signal_params) || fill_price <= 0.0)
    return;

  PandoraSetActiveSourceAnchor(signal_params,
                               order_state,
                               PANDORA_EXECUTION_SOURCE_BROKER_FILLED,
                               fill_price,
                               fill_time,
                               position_comment);
  PandoraRefreshLocalTargetPrices(signal_params, order_state);
}

void PandoraCompleteNonOperableBrokerRejection(SignalParams &signal_params,
                                               GridOrderState &order_state,
                                               const string context,
                                               const string detail,
                                               const ulong retcode,
                                               const int last_error,
                                               const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  datetime now_time = TimeCurrent();
  signal_params.pandora_broker_send_attempted = true;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_REJECTED;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
  signal_params.pandora_broker_attempt_time = now_time;
  signal_params.pandora_broker_retry_next_time = 0;
  signal_params.pandora_broker_retry_deadline = 0;
  signal_params.pandora_broker_retcode = retcode;
  signal_params.pandora_broker_last_error = last_error;
  signal_params.pandora_broker_reject_context = context;
  signal_params.pandora_broker_reject_detail = detail;

  signal_params.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_COMPLETED;
  signal_params.pandora_local_close_marker = PANDORA_LOCAL_CLOSE_LOCAL_REJECTED;
  signal_params.pandora_local_close_time = now_time;
  double close_price = signal_params.pandora_source_entry_price;
  if(close_price <= 0.0)
    close_price = signal_params.pandora_local_entry_price;
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(signal_params.signal_type, false);
  signal_params.pandora_local_close_price = close_price;
  signal_params.close_time = now_time;
  signal_params.close_price = close_price;
  signal_params.raw_profit = 0.0;
  signal_params.pandora_close_outcome = PANDORA_CLOSE_BE;

  order_state.status = GRID_ORDER_COMPLETED;
  order_state.position_ticket = 0;
  if(order_state.position_comment == "" && position_comment != "")
    order_state.position_comment = position_comment;
  order_state.last_action_time = now_time;

  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

int PandoraBrokerRetryMaxAttempts()
{
  return MathMax(Pandora_Box_Broker_Retry_Attempts, 1);
}

int PandoraBrokerRetryMinSeconds()
{
  return MathMax(Pandora_Box_Broker_Retry_Min_Seconds, 0);
}

int PandoraBrokerRetryWindowSeconds()
{
  return MathMax(Pandora_Box_Broker_Retry_Window_Seconds, 0);
}

double PandoraBrokerRetrySymbolBaseDriftPoints()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double tick_points = 1.0;
  if(point_size > 0.0 && tick_size > 0.0)
    tick_points = MathMax(1.0, tick_size / point_size);

  double broker_min_points = MinBrokerDistancePoints(g_symbol_constraints);
  if(broker_min_points <= 0.0)
    broker_min_points = EnforceBrokerDistance(g_symbol_constraints, 0.0);

  double spread_points = MathMax(g_points_spread, 0.0);
  double base_points = MathMax(tick_points,
                               MathMax(broker_min_points, spread_points));
  if(base_points <= 0.0)
    base_points = 10.0;
  return base_points;
}

double PandoraBrokerRetryMaxDriftPoints()
{
  double factor = MathMax(Pandora_Box_Broker_Retry_Max_Drift_Symbol_Factor, 0.0);
  if(factor <= 0.0)
    return 0.0;
  return PandoraBrokerRetrySymbolBaseDriftPoints() * factor;
}

bool PandoraBrokerRetryEnabled()
{
  return (PandoraBrokerRetryMaxAttempts() > 1);
}

bool PandoraBrokerRetryPending(const SignalParams &signal_params)
{
  return (IsPandoraSignal(signal_params) &&
          signal_params.pandora_broker_execution_status == PANDORA_BROKER_RETRY_PENDING);
}

bool PandoraBrokerRetryBudgetAvailable(const SignalParams &signal_params)
{
  if(!PandoraBrokerRetryEnabled())
    return false;
  return (signal_params.pandora_broker_attempt_count < PandoraBrokerRetryMaxAttempts());
}

bool PandoraBrokerGuardrailRetryable(const string detail)
{
  return (PandoraTextContains(detail, "spread=") ||
          PandoraTextContains(detail, "spread>") ||
          PandoraTextContains(detail, "ERR_Spread"));
}

bool PandoraBrokerRetcodeRetryable(const ulong retcode,
                                   const int last_error)
{
  switch((int)retcode)
  {
    case TRADE_RETCODE_ERROR:
    case TRADE_RETCODE_PRICE_CHANGED:
    case TRADE_RETCODE_PRICE_OFF:
    case TRADE_RETCODE_REQUOTE:
    case TRADE_RETCODE_TIMEOUT:
    case TRADE_RETCODE_CONNECTION:
    case TRADE_RETCODE_TOO_MANY_REQUESTS:
    case TRADE_RETCODE_LOCKED:
    case TRADE_RETCODE_FROZEN:
      return true;
    default:
      break;
  }

  if(retcode == 0 && last_error == ERR_TRADE_SEND_FAILED)
    return true;
  return false;
}

bool PandoraBrokerRetcodeFinal(const ulong retcode)
{
  switch((int)retcode)
  {
    case TRADE_RETCODE_INVALID_STOPS:
    case TRADE_RETCODE_INVALID_VOLUME:
    case TRADE_RETCODE_LIMIT_VOLUME:
    case TRADE_RETCODE_NO_MONEY:
    case TRADE_RETCODE_MARKET_CLOSED:
    case TRADE_RETCODE_TRADE_DISABLED:
    case TRADE_RETCODE_SERVER_DISABLES_AT:
    case TRADE_RETCODE_CLIENT_DISABLES_AT:
    case TRADE_RETCODE_CLOSE_ONLY:
    case TRADE_RETCODE_LONG_ONLY:
    case TRADE_RETCODE_SHORT_ONLY:
    case TRADE_RETCODE_ONLY_REAL:
    case TRADE_RETCODE_HEDGE_PROHIBITED:
    case TRADE_RETCODE_INVALID_ORDER:
    case TRADE_RETCODE_INVALID_EXPIRATION:
    case TRADE_RETCODE_LIMIT_POSITIONS:
    case TRADE_RETCODE_LIMIT_ORDERS:
    case TRADE_RETCODE_INVALID_FILL:
    case TRADE_RETCODE_INVALID_PRICE:
    case TRADE_RETCODE_INVALID:
    case TRADE_RETCODE_REJECT:
    case TRADE_RETCODE_CANCEL:
      return true;
    default:
      break;
  }
  return false;
}

bool PandoraBrokerInvalidStopsRetryableAfterSend(const string context,
                                                 const ulong retcode)
{
  if(retcode != TRADE_RETCODE_INVALID_STOPS)
    return false;

  if(context != "ORDER_SEND_FAILED" &&
     context != "ORDER_SEND_REJECTED")
    return false;

  return true;
}

bool PandoraBrokerFailureRetryable(const string context,
                                   const string detail,
                                   const ulong retcode,
                                   const int last_error)
{
  if(!PandoraBrokerRetryEnabled())
    return false;
  if(PandoraBrokerInvalidStopsRetryableAfterSend(context,
                                                 retcode))
    return true;
  if(PandoraBrokerGuardrailRetryable(context) ||
     PandoraBrokerGuardrailRetryable(detail))
    return true;
  if(PandoraBrokerRetcodeFinal(retcode))
    return false;
  return PandoraBrokerRetcodeRetryable(retcode, last_error);
}

void PandoraRecordBrokerSendAttempt(SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;

  signal_params.pandora_broker_send_attempted = true;
  signal_params.pandora_broker_attempt_count++;
  signal_params.pandora_broker_attempt_time = TimeCurrent();
}

void PandoraEnsureBrokerRetryWindow(SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;
  if(signal_params.pandora_broker_retry_deadline > 0)
    return;

  int window_seconds = PandoraBrokerRetryWindowSeconds();
  if(window_seconds <= 0)
    return;

  datetime base_time = signal_params.pandora_local_entry_time;
  if(base_time <= 0)
    base_time = signal_params.entry_time;
  if(base_time <= 0)
    base_time = TimeCurrent();

  signal_params.pandora_broker_retry_deadline = base_time + window_seconds;
}

bool PandoraBrokerRetryWindowExpired(const SignalParams &signal_params,
                                     const datetime now_time)
{
  if(signal_params.pandora_broker_retry_deadline <= 0)
    return false;
  return (now_time > signal_params.pandora_broker_retry_deadline);
}

bool PandoraBrokerRetryDriftExceeded(const SignalParams &signal_params,
                                     const GridOrderState &order_state,
                                     const double current_entry_price,
                                     const double point_size,
                                     string &detail)
{
  detail = "";
  double max_drift_points = PandoraBrokerRetryMaxDriftPoints();
  if(max_drift_points <= 0.0)
    return false;
  if(current_entry_price <= 0.0 || point_size <= 0.0)
    return false;

  double local_entry_price = PandoraResolveLocalEntryPrice(signal_params, order_state);
  if(local_entry_price <= 0.0)
    return false;

  double drift_points = MathAbs(current_entry_price - local_entry_price) / point_size;
  if(drift_points <= max_drift_points)
    return false;

  detail = StringFormat("retry_drift=%.1f>%.1f",
                        drift_points,
                        max_drift_points);
  return true;
}

double PandoraResolveLocalEntryPrice(const SignalParams &signal_params,
                                     const GridOrderState &order_state)
{
  if(signal_params.pandora_source_entry_price > 0.0)
    return signal_params.pandora_source_entry_price;
  if(signal_params.pandora_local_entry_price > 0.0)
    return signal_params.pandora_local_entry_price;
  if(signal_params.pandora_broker_fill_price > 0.0)
    return signal_params.pandora_broker_fill_price;
  if(signal_params.pandora_broker_simulated_entry_price > 0.0)
    return signal_params.pandora_broker_simulated_entry_price;
  if(signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_PENDING)
    return 0.0;
  if(order_state.entry_price > 0.0)
    return order_state.entry_price;
  if(signal_params.entry_price > 0.0)
    return signal_params.entry_price;
  if(order_state.entry_reference_price > 0.0)
    return order_state.entry_reference_price;
  return GridCurrentPriceForDirection(signal_params.signal_type, true);
}

double PandoraNormalizeTargetPrice(const double price)
{
  if(price <= 0.0)
    return 0.0;

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  return NormalizeDouble(price, digits);
}

double PandoraResolveBrokerTickSize()
{
  return ResolveEffectiveTickSize(g_symbol_constraints.tick_size,
                                  g_symbol_constraints.point_size);
}

double PandoraNormalizeBrokerPrice(const double price,
                                   const bool round_up)
{
  if(price <= 0.0)
    return 0.0;

  double tick_size = PandoraResolveBrokerTickSize();
  if(tick_size <= 0.0)
    return PandoraNormalizeTargetPrice(price);

  double ticks = price / tick_size;
  double rounded_price = round_up
                         ? MathCeil(ticks - 1e-9) * tick_size
                         : MathFloor(ticks + 1e-9) * tick_size;

  return PandoraNormalizeTargetPrice(rounded_price);
}

bool PandoraBrokerStopAboveReference(const SignalTypes direction,
                                     const bool stop_loss)
{
  if(direction == BULLISH)
    return !stop_loss;
  return stop_loss;
}

double PandoraBrokerProtectionReferencePrice(const SignalTypes direction)
{
  double reference_price = (direction == BULLISH) ? g_bid : g_ask;
  if(reference_price > 0.0)
    return reference_price;

  reference_price = (direction == BULLISH)
                    ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                    : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  if(reference_price > 0.0)
    return reference_price;

  return GridCurrentPriceForDirection(direction, false);
}

double PandoraBrokerMinProtectionDistancePrice()
{
  return EffectiveBrokerDistancePrice(g_symbol_constraints, 0.0, 1.0);
}

double PandoraBrokerEffectiveProtectionDistancePoints()
{
  return EffectiveBrokerDistancePoints(g_symbol_constraints, 0.0, 1.0);
}

bool PandoraStopPriceMatches(const double current_price,
                             const double target_price,
                             const double tolerance)
{
  if(target_price <= 0.0)
    return (current_price <= tolerance);
  return MathAbs(current_price - target_price) <= tolerance;
}

string PandoraBrokerProtectionPolicyLabel(const SignalParams &signal_params,
                                          const double sl_price,
                                          const double tp_price)
{
  if(!IsPandoraSignal(signal_params))
    return "-";

  if(sl_price <= 0.0 && tp_price <= 0.0)
    return "no_initial_sltp";

  double tolerance = PandoraResolveBrokerTickSize() * 0.5;
  if(tolerance <= 0.0)
    tolerance = PandoraResolvePointSizeSafe() * 0.5;

  bool has_local_targets = (signal_params.pandora_broker_sl_target_price > 0.0 ||
                            signal_params.pandora_broker_tp_target_price > 0.0);
  bool exact_sl = PandoraStopPriceMatches(sl_price,
                                          signal_params.pandora_broker_sl_target_price,
                                          tolerance);
  bool exact_tp = PandoraStopPriceMatches(tp_price,
                                          signal_params.pandora_broker_tp_target_price,
                                          tolerance);
  if(has_local_targets && exact_sl && exact_tp)
    return "exact";

  bool has_protection = (signal_params.pandora_broker_sl_protection_price > 0.0 ||
                         signal_params.pandora_broker_tp_protection_price > 0.0);
  bool wide_sl = PandoraStopPriceMatches(sl_price,
                                         signal_params.pandora_broker_sl_protection_price,
                                         tolerance);
  bool wide_tp = PandoraStopPriceMatches(tp_price,
                                         signal_params.pandora_broker_tp_protection_price,
                                         tolerance);
  if(has_protection && wide_sl && wide_tp)
    return "wide";

  return "custom";
}

struct PandoraBrokerOpenStopCandidate
{
  string policy;
  double sl_price;
  double tp_price;
  PandoraBrokerStopSyncStatuses stop_status;
  bool available;

  PandoraBrokerOpenStopCandidate()
  {
    policy = "";
    sl_price = 0.0;
    tp_price = 0.0;
    stop_status = PANDORA_BROKER_STOPS_NONE;
    available = false;
  }
};

void PandoraResetBrokerOpenStopCandidate(PandoraBrokerOpenStopCandidate &candidate)
{
  candidate.policy = "";
  candidate.sl_price = 0.0;
  candidate.tp_price = 0.0;
  candidate.stop_status = PANDORA_BROKER_STOPS_NONE;
  candidate.available = false;
}

void PandoraSetBrokerOpenStopCandidate(PandoraBrokerOpenStopCandidate &candidate,
                                       const string policy,
                                       const double sl_price,
                                       const double tp_price,
                                       const PandoraBrokerStopSyncStatuses stop_status)
{
  candidate.policy = policy;
  candidate.sl_price = sl_price;
  candidate.tp_price = tp_price;
  candidate.stop_status = stop_status;
  candidate.available = true;
}

bool PandoraBrokerOpenStopCandidateHasStops(const PandoraBrokerOpenStopCandidate &candidate)
{
  return (candidate.available &&
          (candidate.sl_price > 0.0 || candidate.tp_price > 0.0));
}

bool PandoraBrokerOpenStopCandidateMatches(const PandoraBrokerOpenStopCandidate &left,
                                           const PandoraBrokerOpenStopCandidate &right)
{
  if(!left.available || !right.available)
    return false;

  double tolerance = PandoraResolveBrokerTickSize() * 0.5;
  if(tolerance <= 0.0)
    tolerance = PandoraResolvePointSizeSafe() * 0.5;

  return PandoraStopPriceMatches(left.sl_price, right.sl_price, tolerance) &&
         PandoraStopPriceMatches(left.tp_price, right.tp_price, tolerance);
}

int PandoraBuildBrokerOpenStopCandidates(SignalParams &signal_params,
                                         GridOrderState &order_state,
                                         PandoraBrokerOpenStopCandidate &exact_candidate,
                                         PandoraBrokerOpenStopCandidate &wide_candidate,
                                         PandoraBrokerOpenStopCandidate &no_stop_candidate,
                                         string &detail)
{
  PandoraResetBrokerOpenStopCandidate(exact_candidate);
  PandoraResetBrokerOpenStopCandidate(wide_candidate);
  PandoraResetBrokerOpenStopCandidate(no_stop_candidate);
  detail = "";

  if(!IsPandoraSignal(signal_params))
    return 0;

  int total_candidates = 0;
  PandoraEnsureLocalTargetPrices(signal_params, order_state);

  double local_sl = PandoraResolveLocalStopTargetPrice(signal_params, order_state);
  double local_tp = PandoraResolveLocalTakeProfitTargetPrice(signal_params, order_state);
  signal_params.pandora_broker_sl_target_price = local_sl;
  signal_params.pandora_broker_tp_target_price = local_tp;

  if(local_sl > 0.0 || local_tp > 0.0)
  {
    double exact_sl = 0.0;
    double exact_tp = 0.0;
    if(local_sl > 0.0)
      exact_sl = PandoraNormalizeBrokerPrice(local_sl,
                                             PandoraBrokerStopAboveReference(signal_params.signal_type,
                                                                            true));
    if(local_tp > 0.0)
      exact_tp = PandoraNormalizeBrokerPrice(local_tp,
                                             PandoraBrokerStopAboveReference(signal_params.signal_type,
                                                                            false));

    if(exact_sl > 0.0 || exact_tp > 0.0)
    {
      PandoraSetBrokerOpenStopCandidate(exact_candidate,
                                        "exact",
                                        exact_sl,
                                        exact_tp,
                                        PANDORA_BROKER_STOPS_TARGETED);
      total_candidates++;
    }
  }
  else
  {
    detail = "no_local_targets";
  }

  double wide_sl = 0.0;
  double wide_tp = 0.0;
  bool all_exact = false;
  string wide_detail = "";
  if(PandoraResolveBrokerSafeStops(signal_params,
                                   order_state,
                                   wide_sl,
                                   wide_tp,
                                   all_exact,
                                   wide_detail))
  {
    PandoraBrokerOpenStopCandidate candidate;
    PandoraSetBrokerOpenStopCandidate(candidate,
                                      all_exact ? "exact_safe" : "wide",
                                      wide_sl,
                                      wide_tp,
                                      all_exact ? PANDORA_BROKER_STOPS_TARGETED
                                                : PANDORA_BROKER_STOPS_WIDE);
    if(!PandoraBrokerOpenStopCandidateMatches(candidate, exact_candidate))
    {
      PandoraSetBrokerOpenStopCandidate(wide_candidate,
                                        candidate.policy,
                                        candidate.sl_price,
                                        candidate.tp_price,
                                        candidate.stop_status);
      total_candidates++;
    }
  }
  else if(detail == "")
  {
    detail = wide_detail;
  }

  PandoraSetBrokerOpenStopCandidate(no_stop_candidate,
                                    "no_initial_sltp",
                                    0.0,
                                    0.0,
                                    PANDORA_BROKER_STOPS_PENDING);
  total_candidates++;

  return total_candidates;
}

bool PandoraBrokerProtectionPriceLegal(const SignalTypes direction,
                                       const bool stop_loss,
                                       const double price,
                                       const double reference_price,
                                       const double min_distance_price)
{
  if(price <= 0.0 || reference_price <= 0.0 || min_distance_price <= 0.0)
    return false;

  double tolerance = PandoraResolveBrokerTickSize() * 0.1;
  if(tolerance <= 0.0)
    tolerance = PandoraResolvePointSizeSafe() * 0.1;

  bool above_reference = PandoraBrokerStopAboveReference(direction, stop_loss);
  if(above_reference)
    return price >= reference_price + min_distance_price - tolerance;
  return price <= reference_price - min_distance_price + tolerance;
}

double PandoraResolveBrokerSafeProtectionPrice(const SignalTypes direction,
                                               const bool stop_loss,
                                               const double local_price,
                                               const double reference_price,
                                               const double min_distance_price,
                                               bool &is_exact)
{
  is_exact = false;
  if(local_price <= 0.0 || reference_price <= 0.0 || min_distance_price <= 0.0)
    return 0.0;

  bool above_reference = PandoraBrokerStopAboveReference(direction, stop_loss);
  double rounded_local = PandoraNormalizeBrokerPrice(local_price, above_reference);
  if(rounded_local <= 0.0)
    return 0.0;

  if(PandoraBrokerProtectionPriceLegal(direction,
                                       stop_loss,
                                       rounded_local,
                                       reference_price,
                                       min_distance_price))
  {
    double tolerance = PandoraResolveBrokerTickSize() * 0.5;
    if(tolerance <= 0.0)
      tolerance = PandoraResolvePointSizeSafe() * 0.5;
    is_exact = (MathAbs(rounded_local - local_price) <= tolerance);
    return rounded_local;
  }

  double required_price = above_reference
                          ? reference_price + min_distance_price
                          : reference_price - min_distance_price;
  double safe_price = PandoraNormalizeBrokerPrice(required_price, above_reference);
  if(safe_price <= 0.0)
    return 0.0;

  if(!PandoraBrokerProtectionPriceLegal(direction,
                                        stop_loss,
                                        safe_price,
                                        reference_price,
                                        min_distance_price))
    return 0.0;

  return safe_price;
}

void PandoraSetBrokerStopSyncResolvedStatus(SignalParams &signal_params,
                                            const bool all_exact)
{
  signal_params.pandora_broker_stop_sync_status = all_exact
                                                  ? PANDORA_BROKER_STOPS_TARGETED
                                                  : PANDORA_BROKER_STOPS_WIDE;
}

bool PandoraResolveBrokerSafeStops(SignalParams &signal_params,
                                   GridOrderState &order_state,
                                   double &sl_price,
                                   double &tp_price,
                                   bool &all_exact,
                                   string &detail)
{
  sl_price = 0.0;
  tp_price = 0.0;
  all_exact = false;
  detail = "";

  if(!IsPandoraSignal(signal_params))
    return false;

  PandoraEnsureLocalTargetPrices(signal_params, order_state);

  double local_sl = PandoraResolveLocalStopTargetPrice(signal_params, order_state);
  double local_tp = PandoraResolveLocalTakeProfitTargetPrice(signal_params, order_state);
  signal_params.pandora_broker_sl_target_price = local_sl;
  signal_params.pandora_broker_tp_target_price = local_tp;

  if(local_sl <= 0.0 && local_tp <= 0.0)
  {
    detail = "no_local_targets";
    signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_FAILED;
    return false;
  }

  double reference_price = PandoraBrokerProtectionReferencePrice(signal_params.signal_type);
  double min_distance_price = PandoraBrokerMinProtectionDistancePrice();
  if(reference_price <= 0.0 || min_distance_price <= 0.0)
  {
    detail = "missing_reference";
    signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_FAILED;
    return false;
  }

  bool sl_exact = true;
  bool tp_exact = true;
  if(local_sl > 0.0)
  {
    sl_price = PandoraResolveBrokerSafeProtectionPrice(signal_params.signal_type,
                                                       true,
                                                       local_sl,
                                                       reference_price,
                                                       min_distance_price,
                                                       sl_exact);
    if(sl_price <= 0.0)
      sl_exact = false;
  }

  if(local_tp > 0.0)
  {
    tp_price = PandoraResolveBrokerSafeProtectionPrice(signal_params.signal_type,
                                                       false,
                                                       local_tp,
                                                       reference_price,
                                                       min_distance_price,
                                                       tp_exact);
    if(tp_price <= 0.0)
      tp_exact = false;
  }

  if(sl_price <= 0.0 && tp_price <= 0.0)
  {
    detail = "no_legal_protection";
    signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_FAILED;
    return false;
  }

  signal_params.pandora_broker_sl_protection_price = sl_price;
  signal_params.pandora_broker_tp_protection_price = tp_price;

  all_exact = true;
  if(local_sl > 0.0 && !sl_exact)
    all_exact = false;
  if(local_tp > 0.0 && !tp_exact)
    all_exact = false;

  PandoraSetBrokerStopSyncResolvedStatus(signal_params, all_exact);
  if(!all_exact)
    detail = "wide_protection";
  return true;
}

bool PandoraComputeLocalTargetPrices(const SignalParams &signal_params,
                                     const GridOrderState &order_state,
                                     double &sl_price,
                                     double &tp_price)
{
  sl_price = 0.0;
  tp_price = 0.0;

  if(!IsPandoraSignal(signal_params))
    return false;

  double point_size = PandoraResolvePointSizeSafe();
  if(point_size <= 0.0)
    return false;

  double entry_anchor = PandoraResolveLocalEntryPrice(signal_params, order_state);
  if(entry_anchor <= 0.0)
    return false;

  double sl_points = PandoraResolveConfiguredSLPoints(false);
  double tp_points = PandoraRiskStepTrailingEnabled()
                     ? 0.0
                     : PandoraResolveConfiguredTPPoints(false);
  if(sl_points <= 0.0 && tp_points <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
  {
    if(sl_points > 0.0)
      sl_price = entry_anchor - sl_points * point_size;
    if(tp_points > 0.0)
      tp_price = entry_anchor + tp_points * point_size;
  }
  else
  {
    if(sl_points > 0.0)
      sl_price = entry_anchor + sl_points * point_size;
    if(tp_points > 0.0)
      tp_price = entry_anchor - tp_points * point_size;
  }

  sl_price = PandoraNormalizeTargetPrice(sl_price);
  tp_price = PandoraNormalizeTargetPrice(tp_price);
  return (sl_price > 0.0 || tp_price > 0.0);
}

void PandoraEnsureLocalTargetPrices(SignalParams &signal_params,
                                    GridOrderState &order_state)
{
  if(!IsPandoraSignal(signal_params))
    return;

  if(signal_params.pandora_local_sl_price > 0.0 &&
     (PandoraRiskStepTrailingEnabled() || signal_params.pandora_local_tp_price > 0.0))
    return;

  double sl_price = 0.0;
  double tp_price = 0.0;
  if(!PandoraComputeLocalTargetPrices(signal_params, order_state, sl_price, tp_price))
    return;

  if(signal_params.pandora_local_sl_price <= 0.0 && sl_price > 0.0)
    signal_params.pandora_local_sl_price = sl_price;
  if(signal_params.pandora_local_tp_price <= 0.0 && tp_price > 0.0)
    signal_params.pandora_local_tp_price = tp_price;
}

double PandoraResolveLocalStopTargetPrice(const SignalParams &signal_params,
                                          const GridOrderState &order_state)
{
  if(signal_params.pandora_trailing_stop_price > 0.0)
    return signal_params.pandora_trailing_stop_price;
  if(signal_params.pandora_local_sl_price > 0.0)
    return signal_params.pandora_local_sl_price;

  double sl_price = 0.0;
  double tp_price = 0.0;
  if(PandoraComputeLocalTargetPrices(signal_params, order_state, sl_price, tp_price) &&
     sl_price > 0.0)
    return sl_price;

  return 0.0;
}

double PandoraResolveLocalTakeProfitTargetPrice(const SignalParams &signal_params,
                                                const GridOrderState &order_state)
{
  if(PandoraRiskStepTrailingEnabled())
    return 0.0;
  if(signal_params.pandora_local_tp_price > 0.0)
    return signal_params.pandora_local_tp_price;

  double sl_price = 0.0;
  double tp_price = 0.0;
  if(PandoraComputeLocalTargetPrices(signal_params, order_state, sl_price, tp_price) &&
     tp_price > 0.0)
    return tp_price;

  if(order_state.take_profit_price > 0.0)
    return order_state.take_profit_price;
  return 0.0;
}

PandoraLocalCloseMarkers PandoraResolveLocalCloseMarker(const SignalParams &signal_params,
                                                        const GridOrderState &order_state)
{
  if(order_state.position_ticket > 0 ||
     signal_params.pandora_broker_execution_status == PANDORA_BROKER_EXECUTED ||
     signal_params.pandora_broker_execution_status == PANDORA_BROKER_CLOSED)
    return PANDORA_LOCAL_CLOSE_BROKER;

  if(signal_params.pandora_broker_execution_status == PANDORA_BROKER_BLOCKED ||
     signal_params.pandora_broker_execution_status == PANDORA_BROKER_RETRY_PENDING ||
     signal_params.pandora_broker_execution_status == PANDORA_BROKER_REJECTED)
    return PANDORA_LOCAL_CLOSE_LOCAL_REJECTED;

  return PANDORA_LOCAL_CLOSE_VIRTUAL;
}

void PandoraMarkLocalClose(SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const double close_price,
                           const PandoraCloseOutcomes outcome,
                           const double epsilon_points)
{
  if(!IsPandoraSignal(signal_params))
    return;

  datetime close_time = TimeCurrent();
  signal_params.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_COMPLETED;
  if(signal_params.pandora_local_close_time <= 0)
    signal_params.pandora_local_close_time = close_time;
  if(signal_params.pandora_local_close_price <= 0.0 && close_price > 0.0)
    signal_params.pandora_local_close_price = close_price;
  if(signal_params.pandora_local_close_marker == PANDORA_LOCAL_CLOSE_NONE)
    signal_params.pandora_local_close_marker = PandoraResolveLocalCloseMarker(signal_params,
                                                                              order_state);

  if(outcome != PANDORA_CLOSE_NONE)
    signal_params.pandora_close_outcome = outcome;
  signal_params.pandora_close_epsilon_points = epsilon_points;

  if(signal_params.close_time <= 0)
    signal_params.close_time = signal_params.pandora_local_close_time;
  if(signal_params.close_price <= 0.0 && signal_params.pandora_local_close_price > 0.0)
    signal_params.close_price = signal_params.pandora_local_close_price;

  if(signal_params.pandora_local_close_marker == PANDORA_LOCAL_CLOSE_BROKER &&
     signal_params.pandora_broker_execution_status == PANDORA_BROKER_EXECUTED)
    signal_params.pandora_broker_execution_status = PANDORA_BROKER_CLOSED;

  if(signal_params.pandora_broker_execution_status == PANDORA_BROKER_RETRY_PENDING)
  {
    signal_params.pandora_broker_execution_status = PANDORA_BROKER_REJECTED;
    signal_params.pandora_broker_reject_context = "PANDORA_BROKER_RETRY_CANCELLED";
    signal_params.pandora_broker_reject_detail = "local_closed_before_retry";
  }
  signal_params.pandora_broker_retry_next_time = 0;
  signal_params.pandora_broker_retry_deadline = 0;

  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

void PandoraEnsureLocalEntryActive(SignalParams &signal_params,
                                   GridOrderState &order_state,
                                   const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  if(signal_params.pandora_local_entry_status != PANDORA_LOCAL_ENTRY_ACTIVE)
  {
    if(!PandoraAdmitBrokerRealisticLocalEntry(signal_params, order_state, position_comment))
      return;
  }

  datetime now_time = TimeCurrent();
  double local_entry_price = PandoraResolveLocalEntryPrice(signal_params, order_state);
  if(local_entry_price <= 0.0)
    return;

  signal_params.pandora_local_entry_status = PANDORA_LOCAL_ENTRY_ACTIVE;
  if(signal_params.pandora_local_entry_time <= 0)
    signal_params.pandora_local_entry_time = (signal_params.entry_time > 0)
                                             ? signal_params.entry_time
                                             : now_time;
  if(signal_params.pandora_local_entry_price <= 0.0)
    signal_params.pandora_local_entry_price = local_entry_price;

  if(signal_params.entry_price <= 0.0)
    signal_params.entry_price = local_entry_price;

  order_state.status = GRID_ORDER_ACTIVE;
  if(order_state.entry_price <= 0.0)
    order_state.entry_price = local_entry_price;
  order_state.position_ticket = 0;
  if(order_state.position_comment == "" && position_comment != "")
    order_state.position_comment = position_comment;
  order_state.last_action_time = now_time;

  PandoraRefreshLocalTargetPrices(signal_params, order_state);
  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

void PandoraMarkBrokerBlocked(SignalParams &signal_params,
                              GridOrderState &order_state,
                              const string context,
                              const string detail,
                              const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  PandoraEnsureLocalEntryActive(signal_params, order_state, position_comment);
  signal_params.pandora_broker_send_attempted = true;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_BLOCKED;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
  signal_params.pandora_broker_attempt_time = TimeCurrent();
  signal_params.pandora_broker_retry_next_time = 0;
  signal_params.pandora_broker_retry_deadline = 0;
  signal_params.pandora_broker_retcode = 0;
  signal_params.pandora_broker_last_error = 0;
  signal_params.pandora_broker_reject_context = context;
  signal_params.pandora_broker_reject_detail = detail;
  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

void PandoraMarkBrokerRetryPending(SignalParams &signal_params,
                                   GridOrderState &order_state,
                                   const string context,
                                   const string detail,
                                   const ulong retcode,
                                   const int last_error,
                                   const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  datetime now_time = TimeCurrent();
  PandoraEnsureLocalEntryActive(signal_params, order_state, position_comment);
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_RETRY_PENDING;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
  signal_params.pandora_broker_attempt_time = now_time;
  signal_params.pandora_broker_retcode = retcode;
  signal_params.pandora_broker_last_error = last_error;
  signal_params.pandora_broker_reject_context = context;
  signal_params.pandora_broker_reject_detail = detail;
  PandoraEnsureBrokerRetryWindow(signal_params);

  if(signal_params.pandora_broker_retry_next_time <= now_time)
    signal_params.pandora_broker_retry_next_time = now_time + PandoraBrokerRetryMinSeconds();

  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

void PandoraMarkBrokerRejected(SignalParams &signal_params,
                               GridOrderState &order_state,
                               const string context,
                               const string detail,
                               const ulong retcode,
                               const int last_error,
                               const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  PandoraEnsureLocalEntryActive(signal_params, order_state, position_comment);
  signal_params.pandora_broker_send_attempted = true;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_REJECTED;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
  signal_params.pandora_broker_attempt_time = TimeCurrent();
  signal_params.pandora_broker_retry_next_time = 0;
  signal_params.pandora_broker_retry_deadline = 0;
  signal_params.pandora_broker_retcode = retcode;
  signal_params.pandora_broker_last_error = last_error;
  signal_params.pandora_broker_reject_context = context;
  signal_params.pandora_broker_reject_detail = detail;
  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

void PandoraMarkBrokerExecuted(SignalParams &signal_params,
                               GridOrderState &order_state,
                               const ulong retcode,
                               const int last_error,
                               const string position_comment)
{
  if(!IsPandoraSignal(signal_params))
    return;

  double fill_price = order_state.entry_price;
  datetime fill_time = TimeCurrent();
  if(order_state.position_ticket > 0 && PositionSelectByTicket(order_state.position_ticket))
  {
    double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    if(position_open_price > 0.0)
      fill_price = position_open_price;
    datetime position_open_time = (datetime)PositionGetInteger(POSITION_TIME);
    if(position_open_time > 0)
      fill_time = position_open_time;
  }
  if(fill_price <= 0.0)
    fill_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(fill_price > 0.0)
    PandoraRebaseToBrokerFill(signal_params,
                              order_state,
                              fill_price,
                              fill_time,
                              position_comment);

  signal_params.pandora_broker_send_attempted = true;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_EXECUTED;
  signal_params.pandora_broker_attempt_time = TimeCurrent();
  signal_params.pandora_broker_retry_next_time = 0;
  signal_params.pandora_broker_retry_deadline = 0;
  signal_params.pandora_broker_retcode = retcode;
  signal_params.pandora_broker_last_error = last_error;
  signal_params.pandora_broker_reject_context = "";
  signal_params.pandora_broker_reject_detail = "";
  if(order_state.position_comment == "" && position_comment != "")
    order_state.position_comment = position_comment;
  PandoraUpsertTradeMarkerSnapshot(signal_params);
}

bool PandoraMarkPendingBrokerBlockedInArray(SignalParams &signals[],
                                            const string context,
                                            const string detail)
{
  bool marked = false;
  int total = ArraySize(signals);
  for(int i = total - 1; i >= 0; i--)
  {
    if(!IsPandoraSignal(signals[i]))
      continue;
    if(signals[i].signal_state == CLOSED)
      continue;
    if(PandoraBrokerAttemptAlreadyFinished(signals[i]))
      continue;
    if(PandoraBrokerRetryPending(signals[i]))
    {
      marked = true;
      continue;
    }
    if(PandoraLocalEntryPendingAdmission(signals[i]))
    {
      marked = true;
      continue;
    }

    int grid_order_level = ArraySize(signals[i].grid_orders) - 1;
    if(grid_order_level < 0)
      continue;

    GridOrderState order_state = signals[i].grid_orders[grid_order_level];
    if(order_state.status != GRID_ORDER_STOP_TRAILING_ACTIVE)
      continue;

    if(PandoraBrokerRetryBudgetAvailable(signals[i]) &&
       PandoraBrokerGuardrailRetryable(detail))
    {
      PandoraMarkBrokerRetryPending(signals[i],
                                    order_state,
                                    context,
                                    detail,
                                    0,
                                    0,
                                    "");
    }
    else
    {
      PandoraMarkBrokerBlocked(signals[i], order_state, context, detail, "");
    }
    signals[i].grid_orders[grid_order_level] = order_state;
    marked = true;
  }
  return marked;
}

bool PandoraMarkPendingBrokerBlocked(const string context,
                                     const string detail)
{
  bool marked = false;
  if(PandoraMarkPendingBrokerBlockedInArray(running_bullish_signals, context, detail))
    marked = true;
  if(PandoraMarkPendingBrokerBlockedInArray(running_bearish_signals, context, detail))
    marked = true;
  return marked;
}

struct PandoraBoxRuntimeState
{
  bool     enabled;
  bool     respect_session_filter;
  bool     visualization_enabled;
  bool     window_parsed;
  bool     window_valid;
  int      start_minutes;
  int      end_minutes;
  bool     window_wraps;
  datetime day_anchor;
  datetime window_start_time;
  datetime window_end_time;
  bool     window_closed;
  bool     box_computed;
  bool     box_valid;
  double   box_high;
  double   box_low;
  double   box_range_points;
  double   breakout_high_price;
  double   breakout_low_price;
  double   offset_points;
  double   effective_offset_points;
  double   max_range_points;
  StrategyDirectionTypes direction_mode;
  bool     stop_on_first_win;
  PandoraEntryCountModes entry_count_mode;
  PandoraEntryTypes entry_type;
  ENUM_TIMEFRAMES entry_body_timeframe;
  int      max_entries;
  int      counted_entries;
  int      total_entries;
  int      closed_entries;
  bool     finished;
  bool     session_window_seen_active;
  bool     bullish_rearm_required;
  bool     bearish_rearm_required;
  bool     bullish_rearm_ready;
  bool     bearish_rearm_ready;
  datetime last_rearm_close_bar_time;
  datetime bullish_body_signal_bar_time;
  datetime bearish_body_signal_bar_time;
  double   bullish_body_signal_close_price;
  double   bearish_body_signal_close_price;
  string   invalid_reason;

  PandoraBoxRuntimeState()
  {
    Reset();
  }

  void Reset()
  {
    enabled                   = false;
    respect_session_filter    = true;
    visualization_enabled     = true;
    window_parsed             = false;
    window_valid              = false;
    start_minutes             = 0;
    end_minutes               = 0;
    window_wraps              = false;
    day_anchor                = 0;
    window_start_time         = 0;
    window_end_time           = 0;
    window_closed             = false;
    box_computed              = false;
    box_valid                 = false;
    box_high                  = 0.0;
    box_low                   = 0.0;
    box_range_points          = 0.0;
    breakout_high_price       = 0.0;
    breakout_low_price        = 0.0;
    offset_points             = 0.0;
    effective_offset_points   = 0.0;
    max_range_points          = 0.0;
    direction_mode            = BOTH_DIRECTION;
    stop_on_first_win         = false;
    entry_count_mode          = COUNT_BOX_ENTRY_OFF;
    entry_type                = ENTRY_WICK_TYPE;
    entry_body_timeframe      = PERIOD_M5;
    max_entries               = 0;
    counted_entries           = 0;
    total_entries             = 0;
    closed_entries            = 0;
    finished                  = false;
    session_window_seen_active = false;
    bullish_rearm_required    = false;
    bearish_rearm_required    = false;
    bullish_rearm_ready       = false;
    bearish_rearm_ready       = false;
    last_rearm_close_bar_time = 0;
    bullish_body_signal_bar_time = 0;
    bearish_body_signal_bar_time = 0;
    bullish_body_signal_close_price = 0.0;
    bearish_body_signal_close_price = 0.0;
    invalid_reason            = "";
  }
};

struct PandoraHistorySnapshot
{
  datetime day_anchor;
  datetime window_start_time;
  datetime window_end_time;
  datetime data_end_time;
  bool     is_current_day;
  bool     window_valid;
  bool     box_computed;
  bool     box_valid;
  double   box_high;
  double   box_low;
  double   box_range_points;
  double   breakout_high_price;
  double   breakout_low_price;
  string   invalid_reason;

  PandoraHistorySnapshot()
  {
    Reset();
  }

  PandoraHistorySnapshot(const PandoraHistorySnapshot &snapshot)
  {
    day_anchor          = snapshot.day_anchor;
    window_start_time   = snapshot.window_start_time;
    window_end_time     = snapshot.window_end_time;
    data_end_time       = snapshot.data_end_time;
    is_current_day      = snapshot.is_current_day;
    window_valid        = snapshot.window_valid;
    box_computed        = snapshot.box_computed;
    box_valid           = snapshot.box_valid;
    box_high            = snapshot.box_high;
    box_low             = snapshot.box_low;
    box_range_points    = snapshot.box_range_points;
    breakout_high_price = snapshot.breakout_high_price;
    breakout_low_price  = snapshot.breakout_low_price;
    invalid_reason      = snapshot.invalid_reason;
  }

  void Reset()
  {
    day_anchor          = 0;
    window_start_time   = 0;
    window_end_time     = 0;
    data_end_time       = 0;
    is_current_day      = false;
    window_valid        = false;
    box_computed        = false;
    box_valid           = false;
    box_high            = 0.0;
    box_low             = 0.0;
    box_range_points    = 0.0;
    breakout_high_price = 0.0;
    breakout_low_price  = 0.0;
    invalid_reason      = "";
  }
};

struct PandoraTradeMarkerSnapshot
{
  string   marker_id;
  datetime day_anchor;
  SignalTypes direction;
  datetime entry_time;
  datetime close_time;
  double   entry_price;
  double   close_price;
  double   raw_profit;
  PandoraCloseOutcomes          close_outcome;
  PandoraBrokerExecutionStatuses broker_status;
  PandoraLocalCloseMarkers      close_marker;
  string   reject_reason;
  bool     completed;

  PandoraTradeMarkerSnapshot()
  {
    Reset();
  }

  PandoraTradeMarkerSnapshot(const PandoraTradeMarkerSnapshot &snapshot)
  {
    marker_id      = snapshot.marker_id;
    day_anchor     = snapshot.day_anchor;
    direction      = snapshot.direction;
    entry_time     = snapshot.entry_time;
    close_time     = snapshot.close_time;
    entry_price    = snapshot.entry_price;
    close_price    = snapshot.close_price;
    raw_profit     = snapshot.raw_profit;
    close_outcome  = snapshot.close_outcome;
    broker_status  = snapshot.broker_status;
    close_marker   = snapshot.close_marker;
    reject_reason  = snapshot.reject_reason;
    completed      = snapshot.completed;
  }

  void Reset()
  {
    marker_id      = "";
    day_anchor     = 0;
    direction      = NO_SIGNAL;
    entry_time     = 0;
    close_time     = 0;
    entry_price    = 0.0;
    close_price    = 0.0;
    raw_profit     = 0.0;
    close_outcome  = PANDORA_CLOSE_NONE;
    broker_status  = PANDORA_BROKER_NOT_ATTEMPTED;
    close_marker   = PANDORA_LOCAL_CLOSE_NONE;
    reject_reason  = "";
    completed      = false;
  }
};

PandoraBoxRuntimeState g_pandora_box_state;
PandoraHistorySnapshot g_pandora_history_snapshots[];
PandoraTradeMarkerSnapshot g_pandora_trade_marker_snapshots[];
datetime               g_pandora_history_last_day_anchor = 0;
datetime               g_pandora_history_last_previous_day_anchor = 0;
datetime               g_pandora_history_last_oldest_anchor = 0;
datetime               g_pandora_history_last_bar_time = 0;
string                 g_pandora_history_last_signature = "";

bool PandoraStrategyEnabled()
{
  return Pandora_Box_Enable;
}

ENUM_TIMEFRAMES PandoraResolveBoxTimeframe()
{
  ENUM_TIMEFRAMES tf = Strategy_Timeframe;
  if(tf == PERIOD_CURRENT)
    tf = PERIOD_M1;
  if(!IsStrategyTimeframeSupported(tf))
    tf = PERIOD_M1;
  return tf;
}

PandoraEntryTypes PandoraResolveEntryType()
{
  int configured_value = (int)Pandora_Box_Entry_Type;
  if(configured_value == (int)ENTRY_BODY_TYPE)
    return ENTRY_BODY_TYPE;
  return ENTRY_WICK_TYPE;
}

bool PandoraEntryBodyTimeframeSupported(const ENUM_TIMEFRAMES tf)
{
  switch(tf)
  {
    case PERIOD_M1:
    case PERIOD_M2:
    case PERIOD_M3:
    case PERIOD_M4:
    case PERIOD_M5:
    case PERIOD_M6:
    case PERIOD_M10:
    case PERIOD_M12:
    case PERIOD_M15:
    case PERIOD_M20:
    case PERIOD_M30:
    case PERIOD_H1:
    case PERIOD_H2:
    case PERIOD_H3:
    case PERIOD_H4:
    case PERIOD_H6:
    case PERIOD_H8:
    case PERIOD_H12:
    case PERIOD_D1:
    case PERIOD_W1:
    case PERIOD_MN1:
      return true;
  }
  return false;
}

ENUM_TIMEFRAMES PandoraResolveEntryBodyTimeframe()
{
  ENUM_TIMEFRAMES tf = Pandora_Box_Entry_Body_Timeframe;
  if(tf == PERIOD_CURRENT)
    tf = PandoraResolveBoxTimeframe();

  if(PandoraEntryBodyTimeframeSupported(tf))
    return tf;

  ENUM_TIMEFRAMES fallback_tf = PandoraResolveBoxTimeframe();
  if(PandoraEntryBodyTimeframeSupported(fallback_tf))
    return fallback_tf;

  return PERIOD_M5;
}

bool PandoraBodyEntryMode()
{
  return (g_pandora_box_state.entry_type == ENTRY_BODY_TYPE);
}

string PandoraEntryTypeLabel()
{
  if(PandoraBodyEntryMode())
    return "BODY";
  return "WICK";
}

string PandoraEntryBodyTimeframeLabel()
{
  ENUM_TIMEFRAMES tf = g_pandora_box_state.entry_body_timeframe;
  if(!PandoraEntryBodyTimeframeSupported(tf))
    tf = PandoraResolveEntryBodyTimeframe();
  return TimeframeToString(tf);
}

ENUM_TIMEFRAMES PandoraResolveRearmTimeframe()
{
  if(PandoraBodyEntryMode())
    return g_pandora_box_state.entry_body_timeframe;
  return PandoraResolveBoxTimeframe();
}

void PandoraResetBodyEntryState()
{
  g_pandora_box_state.bullish_body_signal_bar_time = 0;
  g_pandora_box_state.bearish_body_signal_bar_time = 0;
  g_pandora_box_state.bullish_body_signal_close_price = 0.0;
  g_pandora_box_state.bearish_body_signal_close_price = 0.0;
}

bool PandoraBodyCandleAlreadyProcessed(const SignalTypes direction,
                                       const datetime close_bar_time)
{
  if(close_bar_time <= 0)
    return true;

  if(direction == BULLISH)
    return (g_pandora_box_state.bullish_body_signal_bar_time == close_bar_time);

  return (g_pandora_box_state.bearish_body_signal_bar_time == close_bar_time);
}

void PandoraMarkBodyCandleProcessed(const SignalTypes direction,
                                    const datetime close_bar_time,
                                    const double close_price)
{
  if(direction == BULLISH)
  {
    g_pandora_box_state.bullish_body_signal_bar_time = close_bar_time;
    g_pandora_box_state.bullish_body_signal_close_price = close_price;
  }
  else
  {
    g_pandora_box_state.bearish_body_signal_bar_time = close_bar_time;
    g_pandora_box_state.bearish_body_signal_close_price = close_price;
  }
}

datetime PandoraBodySignalBarTime(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_body_signal_bar_time;
  return g_pandora_box_state.bearish_body_signal_bar_time;
}

double PandoraBodySignalClosePrice(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_body_signal_close_price;
  return g_pandora_box_state.bearish_body_signal_close_price;
}

bool IsPandoraSignal(const SignalParams &signal_params)
{
  return (signal_params.strategy_context_label == "PANDORA");
}

double PandoraResolvePointSizeSafe()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

string PandoraCompactTimeIdentifier(const datetime time_value)
{
  if(time_value <= 0)
    return "";

  MqlDateTime ts;
  if(!TimeToStruct(time_value, ts))
    return "";

  return StringFormat("%04d%02d%02d_%02d%02d%02d",
                      ts.year,
                      ts.mon,
                      ts.day,
                      ts.hour,
                      ts.min,
                      ts.sec);
}

string PandoraDirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BULL";
  if(direction == BEARISH)
    return "BEAR";
  return "NA";
}

string PandoraPriceToken(const double price)
{
  if(price <= 0.0)
    return "0";

  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;

  string price_token = DoubleToString(price, digits);
  StringReplace(price_token, ".", "");
  StringReplace(price_token, ",", "");
  StringReplace(price_token, "-", "N");
  return price_token;
}

string PandoraBuildTradeMarkerId(const SignalParams &signal_params)
{
  datetime day_anchor = g_pandora_box_state.day_anchor;
  if(day_anchor <= 0)
    day_anchor = ResolveCurrentDayStart();

  datetime entry_time = signal_params.pandora_local_entry_time;
  if(entry_time <= 0)
    entry_time = signal_params.entry_time;
  if(entry_time <= 0)
    entry_time = TimeCurrent();

  double entry_price = signal_params.pandora_source_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.pandora_local_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.entry_price;

  int sequence = g_pandora_box_state.total_entries + 1;
  if(sequence <= 0)
    sequence = ArraySize(g_pandora_trade_marker_snapshots) + 1;

  return StringFormat("%s_%s_%s_%03d_%s",
                      PandoraCompactTimeIdentifier(day_anchor),
                      PandoraDirectionToken(signal_params.signal_type),
                      PandoraCompactTimeIdentifier(entry_time),
                      sequence,
                      PandoraPriceToken(entry_price));
}

void PandoraEnsureTradeMarkerId(SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;
  if(signal_params.pandora_marker_id != "")
    return;

  signal_params.pandora_marker_id = PandoraBuildTradeMarkerId(signal_params);
}

int PandoraFindTradeMarkerSnapshotIndex(const string marker_id)
{
  if(marker_id == "")
    return -1;

  int total = ArraySize(g_pandora_trade_marker_snapshots);
  for(int i = 0; i < total; i++)
  {
    if(g_pandora_trade_marker_snapshots[i].marker_id == marker_id)
      return i;
  }
  return -1;
}

void PandoraTrimTradeMarkerSnapshots()
{
  int total = ArraySize(g_pandora_trade_marker_snapshots);
  while(total > PANDORA_TRADE_MARKER_MAX)
  {
    for(int i = 1; i < total; i++)
      g_pandora_trade_marker_snapshots[i - 1] = g_pandora_trade_marker_snapshots[i];
    total--;
    ArrayResize(g_pandora_trade_marker_snapshots, total);
  }
}

string PandoraResolveMarkerRejectReason(const SignalParams &signal_params)
{
  if(signal_params.pandora_broker_execution_status != PANDORA_BROKER_BLOCKED &&
     signal_params.pandora_broker_execution_status != PANDORA_BROKER_RETRY_PENDING &&
     signal_params.pandora_broker_execution_status != PANDORA_BROKER_REJECTED)
    return "";

  return PandoraBrokerRejectReasonLabel(signal_params.pandora_broker_reject_context,
                                        signal_params.pandora_broker_reject_detail,
                                        signal_params.pandora_broker_retcode);
}

void PandoraUpsertTradeMarkerSnapshot(SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;
  if(signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_PENDING)
    return;

  PandoraEnsureTradeMarkerId(signal_params);

  datetime entry_time = signal_params.pandora_local_entry_time;
  if(entry_time <= 0)
    entry_time = signal_params.entry_time;

  double entry_price = signal_params.pandora_source_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.pandora_local_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.entry_price;

  if(signal_params.pandora_marker_id == "" ||
     entry_time <= 0 ||
     entry_price <= 0.0)
    return;

  int marker_index = PandoraFindTradeMarkerSnapshotIndex(signal_params.pandora_marker_id);
  if(marker_index < 0)
  {
    marker_index = ArraySize(g_pandora_trade_marker_snapshots);
    ArrayResize(g_pandora_trade_marker_snapshots, marker_index + 1, PANDORA_TRADE_MARKER_MAX);
  }

  datetime day_anchor = g_pandora_box_state.day_anchor;
  if(day_anchor <= 0)
    day_anchor = ResolveCurrentDayStart();

  PandoraTradeMarkerSnapshot snapshot;
  snapshot.marker_id     = signal_params.pandora_marker_id;
  snapshot.day_anchor    = day_anchor;
  snapshot.direction     = signal_params.signal_type;
  snapshot.entry_time    = entry_time;
  snapshot.entry_price   = entry_price;
  snapshot.close_time    = signal_params.pandora_local_close_time;
  snapshot.close_price   = signal_params.pandora_local_close_price;
  snapshot.raw_profit    = signal_params.raw_profit;
  snapshot.close_outcome = signal_params.pandora_close_outcome;
  snapshot.broker_status = signal_params.pandora_broker_execution_status;
  snapshot.close_marker  = signal_params.pandora_local_close_marker;
  snapshot.reject_reason = PandoraResolveMarkerRejectReason(signal_params);
  snapshot.completed     = (signal_params.pandora_local_entry_status == PANDORA_LOCAL_ENTRY_COMPLETED ||
                            signal_params.signal_state == CLOSED ||
                            snapshot.close_time > 0 ||
                            snapshot.close_price > 0.0);

  if(snapshot.close_time <= 0 && signal_params.close_time > 0)
    snapshot.close_time = signal_params.close_time;
  if(snapshot.close_price <= 0.0 && signal_params.close_price > 0.0)
    snapshot.close_price = signal_params.close_price;

  g_pandora_trade_marker_snapshots[marker_index] = snapshot;
  PandoraTrimTradeMarkerSnapshots();
}

void PandoraClearTradeMarkerSnapshots()
{
  ArrayResize(g_pandora_trade_marker_snapshots, 0);
}

int PandoraTradeMarkerSnapshotCount()
{
  return ArraySize(g_pandora_trade_marker_snapshots);
}

PandoraTradeMarkerSnapshot PandoraTradeMarkerSnapshotAt(const int index)
{
  PandoraTradeMarkerSnapshot snapshot;
  if(index < 0 || index >= ArraySize(g_pandora_trade_marker_snapshots))
    return snapshot;
  return g_pandora_trade_marker_snapshots[index];
}

void PandoraResetDailyState()
{
  g_pandora_box_state.box_computed            = false;
  g_pandora_box_state.box_valid               = false;
  g_pandora_box_state.box_high                = 0.0;
  g_pandora_box_state.box_low                 = 0.0;
  g_pandora_box_state.box_range_points        = 0.0;
  g_pandora_box_state.breakout_high_price     = 0.0;
  g_pandora_box_state.breakout_low_price      = 0.0;
  g_pandora_box_state.invalid_reason          = "";
  g_pandora_box_state.window_closed           = false;
  g_pandora_box_state.window_wraps            = false;
  g_pandora_box_state.effective_offset_points = 0.0;
  g_pandora_box_state.finished                = false;
  g_pandora_box_state.session_window_seen_active = false;
  g_pandora_box_state.counted_entries         = 0;
  g_pandora_box_state.total_entries           = 0;
  g_pandora_box_state.closed_entries          = 0;
  g_pandora_box_state.bullish_rearm_required  = false;
  g_pandora_box_state.bearish_rearm_required  = false;
  g_pandora_box_state.bullish_rearm_ready     = false;
  g_pandora_box_state.bearish_rearm_ready     = false;
  g_pandora_box_state.last_rearm_close_bar_time = 0;
  PandoraResetBodyEntryState();
  PandoraClearTradeMarkerSnapshots();
}

void PandoraSyncRuntimeConfig()
{
  PandoraEntryTypes resolved_entry_type = PandoraResolveEntryType();
  ENUM_TIMEFRAMES resolved_body_timeframe = PandoraResolveEntryBodyTimeframe();
  bool entry_config_changed = (g_pandora_box_state.entry_type != resolved_entry_type ||
                               g_pandora_box_state.entry_body_timeframe != resolved_body_timeframe);

  g_pandora_box_state.enabled                = Pandora_Box_Enable;
  g_pandora_box_state.respect_session_filter = Pandora_Box_Use_Session_Filter;
  g_pandora_box_state.visualization_enabled  = Pandora_Box_Enable_Visualization;
  g_pandora_box_state.direction_mode         = Pandora_Box_Direction_Mode;
  g_pandora_box_state.offset_points          = MathMax(Pandora_Box_Offset_Points, 0.0);
  g_pandora_box_state.max_range_points       = MathMax(Pandora_Box_Max_Range_Points, 0.0);
  g_pandora_box_state.stop_on_first_win      = Pandora_Box_Stop_On_First_Win;
  g_pandora_box_state.entry_count_mode       = Pandora_Box_Entry_Count_Mode;
  g_pandora_box_state.entry_type             = resolved_entry_type;
  g_pandora_box_state.entry_body_timeframe   = resolved_body_timeframe;
  g_pandora_box_state.max_entries            = MathMax(Pandora_Box_Max_Entries, 0);

  if(entry_config_changed)
  {
    PandoraResetBodyEntryState();
    g_pandora_box_state.last_rearm_close_bar_time = 0;
    if(g_pandora_box_state.bullish_rearm_required)
      g_pandora_box_state.bullish_rearm_ready = false;
    if(g_pandora_box_state.bearish_rearm_required)
      g_pandora_box_state.bearish_rearm_ready = false;
  }
}

bool PandoraParseTimeComponent(string fragment,
                               int &minutes)
{
  StringTrimLeft(fragment);
  StringTrimRight(fragment);

  int delim = StringFind(fragment, ":");
  if(delim <= 0)
    return false;

  string hours_str = StringSubstr(fragment, 0, delim);
  string mins_str  = StringSubstr(fragment, delim + 1);
  if(StringLen(mins_str) <= 0)
    return false;

  int hours = (int)StringToInteger(hours_str);
  int mins  = (int)StringToInteger(mins_str);

  if(hours < 0 || hours > 23)
    return false;
  if(mins < 0 || mins > 59)
    return false;

  minutes = hours * 60 + mins;
  return true;
}

// Pandora wrapped windows are owned by the day they close. When start > end,
// the start side uses the last known closed D1 candle anchor.
bool PandoraParseWindowMinutes(string range_str,
                               int &start_minutes,
                               int &end_minutes,
                               bool &wraps)
{
  start_minutes = 0;
  end_minutes   = 0;
  wraps          = false;

  StringTrimLeft(range_str);
  StringTrimRight(range_str);
  if(StringLen(range_str) <= 0)
    return false;

  int delim = StringFind(range_str, "-");
  if(delim <= 0)
    return false;

  string start_part = StringSubstr(range_str, 0, delim);
  string end_part   = StringSubstr(range_str, delim + 1);
  if(StringLen(end_part) <= 0)
    return false;

  int parsed_start = 0;
  int parsed_end   = 0;
  if(!PandoraParseTimeComponent(start_part, parsed_start))
    return false;
  if(!PandoraParseTimeComponent(end_part, parsed_end))
    return false;

  if(parsed_start == parsed_end)
    return false;

  start_minutes = parsed_start;
  end_minutes   = parsed_end;
  wraps          = (parsed_start > parsed_end);
  return true;
}

bool PandoraResolveWindowTimes(const datetime close_day_anchor,
                               const datetime previous_day_anchor,
                               const int start_minutes,
                               const int end_minutes,
                               const bool wraps,
                               datetime &window_start_time,
                               datetime &window_end_time,
                               string &invalid_reason)
{
  window_start_time = 0;
  window_end_time   = 0;
  invalid_reason    = "";

  if(close_day_anchor <= 0)
  {
    invalid_reason = "Invalid Pandora close day anchor";
    return false;
  }

  datetime start_day_anchor = close_day_anchor;
  if(wraps)
  {
    if(previous_day_anchor <= 0)
    {
      invalid_reason = PANDORA_INVALID_PREVIOUS_D1_ANCHOR;
      return false;
    }
    start_day_anchor = previous_day_anchor;
  }

  int start_offset_minutes = ResolveTradingTimeOffsetMinutesAt(start_day_anchor);
  int end_offset_minutes   = ResolveTradingTimeOffsetMinutesAt(close_day_anchor);

  window_start_time = start_day_anchor +
                      ((start_minutes + start_offset_minutes) * 60);
  window_end_time   = close_day_anchor +
                      ((end_minutes + end_offset_minutes) * 60);

  if(window_start_time >= window_end_time)
  {
    invalid_reason = "Invalid resolved Pandora box window";
    window_start_time = 0;
    window_end_time   = 0;
    return false;
  }

  return true;
}

void PandoraEnsureDayAnchor()
{
  datetime day = ResolveCurrentDayStart();
  if(g_pandora_box_state.day_anchor != day)
  {
    g_pandora_box_state.day_anchor    = day;
    g_pandora_box_state.window_parsed = false;
    g_pandora_box_state.window_valid  = false;
    PandoraResetDailyState();
  }
}

bool PandoraEnsureWindowParsed()
{
  if(g_pandora_box_state.window_parsed)
  {
    if(g_pandora_box_state.window_valid)
      return true;

    if(g_pandora_box_state.window_wraps &&
       g_pandora_box_state.invalid_reason == PANDORA_INVALID_PREVIOUS_D1_ANCHOR &&
       iTime(_Symbol, PERIOD_D1, 1) > 0)
    {
      g_pandora_box_state.window_parsed = false;
    }
    else
    {
      return false;
    }
  }

  g_pandora_box_state.window_parsed = true;
  g_pandora_box_state.window_valid  = PandoraParseWindowMinutes(Pandora_Box_Time_Range,
                                                                g_pandora_box_state.start_minutes,
                                                                g_pandora_box_state.end_minutes,
                                                                g_pandora_box_state.window_wraps);
  if(!g_pandora_box_state.window_valid)
  {
    g_pandora_box_state.window_start_time = 0;
    g_pandora_box_state.window_end_time   = 0;
    g_pandora_box_state.window_wraps      = false;
    g_pandora_box_state.invalid_reason    = "Invalid Pandora box time range";
    return false;
  }

  datetime previous_day_anchor = 0;
  if(g_pandora_box_state.window_wraps)
    previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);

  string invalid_reason = "";
  g_pandora_box_state.window_valid = PandoraResolveWindowTimes(g_pandora_box_state.day_anchor,
                                                               previous_day_anchor,
                                                               g_pandora_box_state.start_minutes,
                                                               g_pandora_box_state.end_minutes,
                                                               g_pandora_box_state.window_wraps,
                                                               g_pandora_box_state.window_start_time,
                                                               g_pandora_box_state.window_end_time,
                                                               invalid_reason);
  if(!g_pandora_box_state.window_valid)
  {
    g_pandora_box_state.invalid_reason = invalid_reason;
    if(g_pandora_box_state.invalid_reason == "")
      g_pandora_box_state.invalid_reason = "Invalid Pandora box time range";
    return false;
  }

  g_pandora_box_state.invalid_reason = "";
  return true;
}

bool PandoraDirectionAllowed(const SignalTypes direction)
{
  StrategyDirectionTypes mode = g_pandora_box_state.direction_mode;
  if(mode == BOTH_DIRECTION)
    return true;
  if(mode == BULLISH_DIRECTION)
    return (direction == BULLISH);
  if(mode == BEARISH_DIRECTION)
    return (direction == BEARISH);
  return true;
}

bool PandoraDirectionHasActiveSignal(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    int total_bullish = ArraySize(running_bullish_signals);
    for(int i = total_bullish - 1; i >= 0; i--)
    {
      if(!IsPandoraSignal(running_bullish_signals[i]))
        continue;
      if(running_bullish_signals[i].signal_state != CLOSED)
        return true;
    }
    return false;
  }

  int total_bearish = ArraySize(running_bearish_signals);
  for(int j = total_bearish - 1; j >= 0; j--)
  {
    if(!IsPandoraSignal(running_bearish_signals[j]))
      continue;
    if(running_bearish_signals[j].signal_state != CLOSED)
      return true;
  }
  return false;
}

bool PandoraHasActiveSignals()
{
  if(PandoraDirectionHasActiveSignal(BULLISH))
    return true;
  return PandoraDirectionHasActiveSignal(BEARISH);
}

string PandoraLimitLabel()
{
  if(g_pandora_box_state.max_entries > 0)
    return IntegerToString(g_pandora_box_state.max_entries);
  return "INF";
}

bool PandoraEntryBudgetReached()
{
  if(g_pandora_box_state.max_entries <= 0)
    return false;
  return (g_pandora_box_state.total_entries >= g_pandora_box_state.max_entries);
}

bool PandoraCloseBudgetReached()
{
  if(g_pandora_box_state.max_entries <= 0)
    return false;
  return (g_pandora_box_state.closed_entries >= g_pandora_box_state.max_entries);
}

bool PandoraDailyCompleted()
{
  if(g_pandora_box_state.finished)
    return true;
  if(!PandoraEntryBudgetReached())
    return false;
  if(!PandoraCloseBudgetReached())
    return false;
  return !PandoraHasActiveSignals();
}

bool PandoraWaitClosePending()
{
  if(!PandoraEntryBudgetReached())
    return false;
  return !PandoraDailyCompleted();
}

bool PandoraDirectionNeedsRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_rearm_required;
  return g_pandora_box_state.bearish_rearm_required;
}

bool PandoraDirectionRearmReady(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_pandora_box_state.bullish_rearm_ready;
  return g_pandora_box_state.bearish_rearm_ready;
}

void PandoraClearDirectionRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    g_pandora_box_state.bullish_rearm_required = false;
    g_pandora_box_state.bullish_rearm_ready    = false;
  }
  else
  {
    g_pandora_box_state.bearish_rearm_required = false;
    g_pandora_box_state.bearish_rearm_ready    = false;
  }
}

void PandoraRequireDirectionRearm(const SignalTypes direction)
{
  if(direction == BULLISH)
  {
    g_pandora_box_state.bullish_rearm_required = true;
    g_pandora_box_state.bullish_rearm_ready    = false;
  }
  else
  {
    g_pandora_box_state.bearish_rearm_required = true;
    g_pandora_box_state.bearish_rearm_ready    = false;
  }
}

bool PandoraPreviousCloseInsideBox()
{
  if(!g_pandora_box_state.box_valid)
    return false;

  ENUM_TIMEFRAMES tf = PandoraResolveRearmTimeframe();
  double close_1 = iClose(_Symbol, tf, 1);
  if(close_1 <= 0.0)
    return false;

  return (close_1 >= g_pandora_box_state.box_low &&
          close_1 <= g_pandora_box_state.box_high);
}

void PandoraRefreshRearmState()
{
  if(!g_pandora_box_state.window_closed ||
     !g_pandora_box_state.box_computed ||
     !g_pandora_box_state.box_valid)
    return;

  if(!g_pandora_box_state.bullish_rearm_required &&
     !g_pandora_box_state.bearish_rearm_required)
    return;

  ENUM_TIMEFRAMES tf = PandoraResolveRearmTimeframe();
  datetime close_bar_time = iTime(_Symbol, tf, 1);
  if(close_bar_time <= 0)
    return;

  if(g_pandora_box_state.last_rearm_close_bar_time == close_bar_time)
    return;

  g_pandora_box_state.last_rearm_close_bar_time = close_bar_time;
  if(!PandoraPreviousCloseInsideBox())
    return;

  if(g_pandora_box_state.bullish_rearm_required)
    g_pandora_box_state.bullish_rearm_ready = true;
  if(g_pandora_box_state.bearish_rearm_required)
    g_pandora_box_state.bearish_rearm_ready = true;
}

bool PandoraDirectionReadyForEntry(const SignalTypes direction)
{
  if(PandoraDirectionHasActiveSignal(direction))
    return false;

  if(!PandoraDirectionNeedsRearm(direction))
    return true;

  return PandoraDirectionRearmReady(direction);
}

void PandoraRegisterEntryTriggered(const SignalTypes direction)
{
  g_pandora_box_state.total_entries++;
  PandoraClearDirectionRearm(direction);

  if(!Enable_Logs)
    return;

  string limit_label = PandoraLimitLabel();
  if(PandoraBodyEntryMode())
  {
    datetime body_bar_time = PandoraBodySignalBarTime(direction);
    double body_close_price = PandoraBodySignalClosePrice(direction);
    PrintFormat("PANDORA_ENTRY_OPEN dir=%s entry=%s body_tf=%s bar=%s body_close=%.5f open=%d/%s close=%d/%s counted=%d/%s",
                EnumToString(direction),
                PandoraEntryTypeLabel(),
                PandoraEntryBodyTimeframeLabel(),
                TimeToString(body_bar_time, TIME_DATE | TIME_MINUTES),
                body_close_price,
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }
  else
  {
    PrintFormat("PANDORA_ENTRY_OPEN dir=%s entry=%s body_tf=%s open=%d/%s close=%d/%s counted=%d/%s",
                EnumToString(direction),
                PandoraEntryTypeLabel(),
                PandoraEntryBodyTimeframeLabel(),
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }

  if(PandoraEntryBudgetReached())
  {
    PrintFormat("PANDORA_BUDGET_REACHED open=%d/%s close=%d/%s active=%s",
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                PandoraHasActiveSignals() ? "true" : "false");
    if(PandoraWaitClosePending())
      PrintFormat("PANDORA_WAIT_CLOSE open=%d/%s close=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label);
  }
}

bool PandoraOutcomeCountsEntry(const PandoraCloseOutcomes outcome)
{
  if(outcome == PANDORA_CLOSE_NONE)
    return false;

  if(g_pandora_box_state.entry_count_mode == COUNT_BOX_ENTRY_ON_SL)
    return (outcome == PANDORA_CLOSE_SL || outcome == PANDORA_CLOSE_BE);

  if(g_pandora_box_state.entry_count_mode == COUNT_BOX_ENTRY_ON_TP)
    return (outcome == PANDORA_CLOSE_TP || outcome == PANDORA_CLOSE_BE);

  return (outcome == PANDORA_CLOSE_SL ||
          outcome == PANDORA_CLOSE_TP ||
          outcome == PANDORA_CLOSE_BE);
}

bool PandoraRiskStepTrailingEnabled()
{
  return (Pandora_Risk_Trailing_Mode == PANDORA_RISK_TRAILING_STEP_TP);
}

double PandoraResolveConfiguredDistancePoints(const double configured_value,
                                              const bool enforce_broker_distance)
{
  return PandoraResolveDistancePointsForRange(configured_value,
                                              g_pandora_box_state.box_range_points,
                                              enforce_broker_distance);
}

double PandoraResolveDistancePointsForRange(const double configured_value,
                                            const double box_range_points,
                                            const bool enforce_broker_distance)
{
  double requested_points = MathMax(configured_value, 0.0);
  if(requested_points <= 0.0)
    return 0.0;

  if(Pandora_Points_Value_Mode == PANDORA_VALUE_MODE_BOX_PERCENT)
  {
    if(box_range_points <= 0.0)
      return 0.0;
    requested_points = box_range_points * (requested_points / 100.0);
  }

  if(requested_points <= 0.0)
    return 0.0;

  if(enforce_broker_distance)
    return EnforceBrokerDistance(g_symbol_constraints, requested_points);
  return requested_points;
}

double PandoraResolveConfiguredSLPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Points_SL,
                                                enforce_broker_distance);
}

double PandoraResolveConfiguredTPPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Points_TP,
                                                enforce_broker_distance);
}

double PandoraResolveConfiguredOffsetPoints(const bool enforce_broker_distance = true)
{
  return PandoraResolveConfiguredDistancePoints(Pandora_Box_Offset_Points,
                                                enforce_broker_distance);
}

double PandoraResolveSignalSLPoints(const SignalParams &signal_params,
                                    const bool enforce_broker_distance = true)
{
  double cached_points = signal_params.pandora_sl_points;
  if(cached_points > 0.0)
    return cached_points;
  return PandoraResolveConfiguredSLPoints(enforce_broker_distance);
}

double PandoraResolveSignalTPPoints(const SignalParams &signal_params,
                                    const bool enforce_broker_distance = true)
{
  double cached_points = signal_params.pandora_tp_points;
  if(cached_points > 0.0)
    return cached_points;
  return PandoraResolveConfiguredTPPoints(enforce_broker_distance);
}

double PandoraResolveSignalTrailingStepPoints(const SignalParams &signal_params)
{
  if(signal_params.pandora_trailing_step_points > 0.0)
    return signal_params.pandora_trailing_step_points;
  return PandoraResolveSignalSLPoints(signal_params, true);
}

bool PandoraResolveBrokerStops(const SignalParams &signal_params,
                               const GridOrderState &order_state,
                               double &sl_price,
                               double &tp_price)
{
  bool all_exact = false;
  string detail = "";

  SignalParams signal_copy(signal_params);
  GridOrderState order_copy;
  order_copy = order_state;

  return PandoraResolveBrokerSafeStops(signal_copy,
                                       order_copy,
                                       sl_price,
                                       tp_price,
                                       all_exact,
                                       detail);
}

double PandoraResolveSignalEpsilonPoints(const SignalParams &signal_params)
{
  double sl_points = PandoraResolveSignalSLPoints(signal_params, true);
  double tp_points = PandoraResolveSignalTPPoints(signal_params, true);
  if(PandoraRiskStepTrailingEnabled())
    tp_points = 0.0;

  double trade_ref_points = MathMax(sl_points, tp_points);
  double box_range_points = MathMax(g_pandora_box_state.box_range_points, 0.0);
  double raw_ref_points = MathMax(trade_ref_points, box_range_points);
  if(raw_ref_points <= 0.0)
    raw_ref_points = MathMax(sl_points, 1.0);
  if(trade_ref_points <= 0.0)
    trade_ref_points = raw_ref_points;

  double structural_points = 0.01 * raw_ref_points;

  double spread_floor = 0.20 * MathMax(g_points_spread, 0.0);
  double freeze_floor = 0.10 * MathMax(g_symbol_constraints.freeze_level_points +
                                       g_symbol_constraints.stops_level_points,
                                       0.0);

  double min_stop_points = g_symbol_constraints.min_stop_distance_points;
  if(min_stop_points <= 0.0)
    min_stop_points = MinBrokerDistancePoints(g_symbol_constraints);
  double min_stop_floor = 0.25 * MathMax(min_stop_points, 0.0);

  double execution_floor = MathMax(2.0,
                                   MathMax(spread_floor,
                                           MathMax(freeze_floor, min_stop_floor)));

  double box_ratio = 0.0;
  if(trade_ref_points > 0.0)
    box_ratio = box_range_points / trade_ref_points;
  bool is_extreme_box = (box_ratio >= PANDORA_EPSILON_EXTREME_BOX_RATIO);

  double cap_points = is_extreme_box
                      ? MathMax(5.0, 0.10 * trade_ref_points)
                      : MathMax(5.0, 0.20 * trade_ref_points);

  double bounded_structural = MathMin(structural_points, cap_points);
  double epsilon_points = MathCeil(MathMax(execution_floor, bounded_structural));
  if(epsilon_points < 1.0)
    epsilon_points = 1.0;

  return epsilon_points;
}

double PandoraResolveSignalEpsilonMoney(const SignalParams &signal_params,
                                        const GridOrderState &order_state,
                                        const double epsilon_points)
{
  if(epsilon_points <= 0.0)
    return 0.0;

  double volume = order_state.lot_size;
  if(volume <= 0.0)
    volume = signal_params.lot_size;
  if(volume <= 0.0)
    volume = NormalizeVolumeForSymbol(_Symbol, Pandora_Lot_Strategy_Size);
  if(volume <= 0.0)
    return 0.0;

  double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  if(tick_value <= 0.0 || tick_size <= 0.0 || point_size <= 0.0)
    return 0.0;

  double point_value_per_lot = tick_value * (point_size / tick_size);
  if(point_value_per_lot <= 0.0)
    return 0.0;

  return epsilon_points * point_value_per_lot * volume;
}

double PandoraResolveOutcomeEntryAnchorPrice(const SignalParams &signal_params,
                                             const GridOrderState &order_state)
{
  double entry_anchor = PandoraResolveLocalEntryPrice(signal_params, order_state);
  if(entry_anchor > 0.0)
    return entry_anchor;

  entry_anchor = order_state.entry_price;
  if(entry_anchor <= 0.0)
    entry_anchor = signal_params.entry_price;
  if(entry_anchor <= 0.0)
    entry_anchor = order_state.entry_reference_price;
  return entry_anchor;
}

double PandoraResolveStopAnchorPrice(const SignalParams &signal_params,
                                     const GridOrderState &order_state,
                                     const double entry_anchor,
                                     const double point_size)
{
  if(point_size <= 0.0 || entry_anchor <= 0.0)
    return 0.0;

  double local_stop_price = PandoraResolveLocalStopTargetPrice(signal_params,
                                                               order_state);
  if(local_stop_price > 0.0)
    return local_stop_price;

  double sl_points = PandoraResolveSignalSLPoints(signal_params, false);
  if(sl_points <= 0.0)
    return 0.0;

  if(signal_params.signal_type == BULLISH)
    return entry_anchor - sl_points * point_size;
  return entry_anchor + sl_points * point_size;
}

double PandoraResolveTakeProfitAnchorPrice(const SignalParams &signal_params,
                                           const GridOrderState &order_state,
                                           const double entry_anchor,
                                           const double point_size)
{
  if(PandoraRiskStepTrailingEnabled())
    return 0.0;

  double local_tp_price = PandoraResolveLocalTakeProfitTargetPrice(signal_params,
                                                                   order_state);
  if(local_tp_price > 0.0)
    return local_tp_price;

  double tp_points = PandoraResolveSignalTPPoints(signal_params, false);
  if(tp_points <= 0.0 || point_size <= 0.0 || entry_anchor <= 0.0)
    return 0.0;

  if(signal_params.signal_type == BULLISH)
    return entry_anchor + tp_points * point_size;
  return entry_anchor - tp_points * point_size;
}

PandoraCloseOutcomes PandoraResolveOutcomeFromDealProfit(const double deal_profit)
{
  if(deal_profit > 0.0)
    return PANDORA_CLOSE_TP;
  if(deal_profit < 0.0)
    return PANDORA_CLOSE_SL;
  return PANDORA_CLOSE_BE;
}

PandoraCloseOutcomes PandoraResolveHistoryOutcomeByPosition(const ulong position_ticket)
{
  if(position_ticket <= 0)
    return PANDORA_CLOSE_NONE;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 5 * 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return PANDORA_CLOSE_NONE;

  int total_deals = HistoryDealsTotal();
  datetime latest_time = 0;
  PandoraCloseOutcomes resolved = PANDORA_CLOSE_NONE;

  for(int i = total_deals - 1; i >= 0; i--)
  {
    ulong ticket = HistoryDealGetTicket(i);
    if(ticket <= 0)
      continue;

    ulong deal_position = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
    if(deal_position != position_ticket)
      continue;

    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
    if(deal_time < latest_time)
      continue;

    latest_time = deal_time;
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
    if(reason == DEAL_REASON_TP)
      resolved = PANDORA_CLOSE_TP;
    else if(reason == DEAL_REASON_SO)
      resolved = PANDORA_CLOSE_SL;
    else if(reason == DEAL_REASON_SL)
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
    else
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
  }

  return resolved;
}

PandoraCloseOutcomes PandoraResolveHistoryOutcomeByComment(const string position_comment)
{
  if(position_comment == "")
    return PANDORA_CLOSE_NONE;

  datetime to_time = TimeCurrent();
  datetime from_time = to_time - 5 * 86400;
  if(from_time < 0)
    from_time = 0;

  if(!HistorySelect(from_time, to_time))
    return PANDORA_CLOSE_NONE;

  int total_deals = HistoryDealsTotal();
  datetime latest_time = 0;
  PandoraCloseOutcomes resolved = PANDORA_CLOSE_NONE;

  for(int i = total_deals - 1; i >= 0; i--)
  {
    ulong ticket = HistoryDealGetTicket(i);
    if(ticket <= 0)
      continue;

    string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
    if(deal_symbol != _Symbol)
      continue;

    long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
    if(deal_magic != g_magic_number)
      continue;

    string deal_comment = HistoryDealGetString(ticket, DEAL_COMMENT);
    if(deal_comment != position_comment)
      continue;

    ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT)
      continue;

    datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
    if(deal_time < latest_time)
      continue;

    latest_time = deal_time;
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
    if(reason == DEAL_REASON_TP)
      resolved = PANDORA_CLOSE_TP;
    else if(reason == DEAL_REASON_SO)
      resolved = PANDORA_CLOSE_SL;
    else if(reason == DEAL_REASON_SL)
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
    else
      resolved = PandoraResolveOutcomeFromDealProfit(HistoryDealGetDouble(ticket, DEAL_PROFIT));
  }

  return resolved;
}

PandoraCloseOutcomes PandoraResolveSignalCloseOutcome(const SignalParams &signal_params,
                                                      const double close_price,
                                                      const double raw_profit,
                                                      double &epsilon_points_out)
{
  epsilon_points_out = 0.0;

  if(!IsPandoraSignal(signal_params))
    return PANDORA_CLOSE_NONE;

  if(signal_params.pandora_close_outcome != PANDORA_CLOSE_NONE)
  {
    epsilon_points_out = signal_params.pandora_close_epsilon_points;
    return signal_params.pandora_close_outcome;
  }

  int last_index = ArraySize(signal_params.grid_orders) - 1;
  if(last_index < 0)
  {
    if(raw_profit > 0.0)
      return PANDORA_CLOSE_TP;
    if(raw_profit < 0.0)
      return PANDORA_CLOSE_SL;
    return PANDORA_CLOSE_BE;
  }

  GridOrderState order_state = signal_params.grid_orders[last_index];
  if(order_state.position_ticket > 0)
  {
    PandoraCloseOutcomes history_outcome = PandoraResolveHistoryOutcomeByPosition(order_state.position_ticket);
    if(history_outcome != PANDORA_CLOSE_NONE)
      return history_outcome;
  }

  double point_size = GridResolvePointSize();
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  epsilon_points_out = PandoraResolveSignalEpsilonPoints(signal_params);
  double epsilon_price = epsilon_points_out * point_size;

  double entry_anchor = PandoraResolveOutcomeEntryAnchorPrice(signal_params, order_state);
  double be_anchor = entry_anchor;
  double sl_anchor = PandoraResolveStopAnchorPrice(signal_params,
                                                   order_state,
                                                   entry_anchor,
                                                   point_size);
  double tp_anchor = PandoraResolveTakeProfitAnchorPrice(signal_params,
                                                         order_state,
                                                         entry_anchor,
                                                         point_size);

  if(be_anchor > 0.0 && close_price > 0.0 &&
     MathAbs(close_price - be_anchor) <= epsilon_price)
  {
    return PANDORA_CLOSE_BE;
  }

  if(tp_anchor > 0.0 && close_price > 0.0)
  {
    if(signal_params.signal_type == BULLISH && close_price >= (tp_anchor - epsilon_price))
      return PANDORA_CLOSE_TP;
    if(signal_params.signal_type == BEARISH && close_price <= (tp_anchor + epsilon_price))
      return PANDORA_CLOSE_TP;
  }

  if(sl_anchor > 0.0 && close_price > 0.0)
  {
    bool hit_stop = false;
    if(signal_params.signal_type == BULLISH)
      hit_stop = (close_price <= (sl_anchor + epsilon_price));
    else
      hit_stop = (close_price >= (sl_anchor - epsilon_price));

    if(hit_stop)
    {
      if(entry_anchor > 0.0)
      {
        if(signal_params.signal_type == BULLISH && sl_anchor > (entry_anchor + epsilon_price))
          return PANDORA_CLOSE_TP;
        if(signal_params.signal_type == BEARISH && sl_anchor < (entry_anchor - epsilon_price))
          return PANDORA_CLOSE_TP;
      }
      return PANDORA_CLOSE_SL;
    }
  }

  double epsilon_money = PandoraResolveSignalEpsilonMoney(signal_params,
                                                          order_state,
                                                          epsilon_points_out);
  if(epsilon_money <= 0.0)
    epsilon_money = 0.01;

  if(MathAbs(raw_profit) <= epsilon_money)
    return PANDORA_CLOSE_BE;
  if(raw_profit > epsilon_money)
    return PANDORA_CLOSE_TP;
  if(raw_profit < -epsilon_money)
    return PANDORA_CLOSE_SL;

  return PANDORA_CLOSE_BE;
}

void PandoraFinalizeSignalOutcome(SignalParams &signal_params,
                                  const double close_price,
                                  const double raw_profit)
{
  if(!IsPandoraSignal(signal_params))
    return;

  double epsilon_points = 0.0;
  PandoraCloseOutcomes outcome = PandoraResolveSignalCloseOutcome(signal_params,
                                                                  close_price,
                                                                  raw_profit,
                                                                  epsilon_points);
  signal_params.pandora_close_outcome = outcome;
  signal_params.pandora_close_epsilon_points = epsilon_points;

  int last_index = ArraySize(signal_params.grid_orders) - 1;
  GridOrderState order_state;
  if(last_index >= 0)
    order_state = signal_params.grid_orders[last_index];

  PandoraMarkLocalClose(signal_params,
                        order_state,
                        close_price,
                        outcome,
                        epsilon_points);
}

void PandoraRegisterSideOutcome(const SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return;

  PandoraRequireDirectionRearm(signal_params.signal_type);
  g_pandora_box_state.closed_entries++;

  if(signal_params.raw_profit > 0.0 && g_pandora_box_state.stop_on_first_win)
  {
    g_pandora_box_state.finished = true;
    if(Enable_Logs)
    {
      string limit_label = PandoraLimitLabel();
      PrintFormat("PANDORA_DONE_FIRST_WIN open=%d/%s close=%d/%s counted=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label,
                  g_pandora_box_state.counted_entries,
                  limit_label);
    }
    return;
  }

  if(PandoraOutcomeCountsEntry(signal_params.pandora_close_outcome))
    g_pandora_box_state.counted_entries++;

  if(Enable_Logs)
  {
    string limit_label = PandoraLimitLabel();
    PrintFormat("PANDORA_ENTRY_CLOSE dir=%s outcome=%s open=%d/%s close=%d/%s counted=%d/%s",
                EnumToString(signal_params.signal_type),
                EnumToString(signal_params.pandora_close_outcome),
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }

  if(PandoraDailyCompleted())
  {
    g_pandora_box_state.finished = true;
    if(Enable_Logs)
    {
      string limit_label = PandoraLimitLabel();
      PrintFormat("PANDORA_DONE open=%d/%s close=%d/%s counted=%d/%s",
                  g_pandora_box_state.total_entries,
                  limit_label,
                  g_pandora_box_state.closed_entries,
                  limit_label,
                  g_pandora_box_state.counted_entries,
                  limit_label);
    }
    return;
  }

  if(PandoraWaitClosePending() && Enable_Logs)
  {
    string limit_label = PandoraLimitLabel();
    PrintFormat("PANDORA_WAIT_CLOSE open=%d/%s close=%d/%s counted=%d/%s",
                g_pandora_box_state.total_entries,
                limit_label,
                g_pandora_box_state.closed_entries,
                limit_label,
                g_pandora_box_state.counted_entries,
                limit_label);
  }
}

bool PandoraFinishedForDay()
{
  if(g_pandora_box_state.finished)
    return true;
  return PandoraDailyCompleted();
}

bool PandoraWindowCompleted()
{
  if(!g_pandora_box_state.window_valid)
    return false;

  datetime now_time = TimeCurrent();
  g_pandora_box_state.window_closed = (g_pandora_box_state.window_end_time > 0 &&
                                       now_time >= g_pandora_box_state.window_end_time);
  return g_pandora_box_state.window_closed;
}

bool PandoraBoxReady()
{
  if(!g_pandora_box_state.enabled)
    return false;
  if(!g_pandora_box_state.box_computed)
    return false;
  if(!g_pandora_box_state.box_valid)
    return false;
  if(PandoraDailyCompleted())
    return false;
  return true;
}

bool PandoraVisualizationEnabled()
{
  return g_pandora_box_state.enabled && g_pandora_box_state.visualization_enabled;
}

string PandoraWindowLabel()
{
  if(!g_pandora_box_state.window_valid)
    return Pandora_Box_Time_Range;
  return StringFormat("%02d:%02d-%02d:%02d",
                      g_pandora_box_state.start_minutes / 60,
                      g_pandora_box_state.start_minutes % 60,
                      g_pandora_box_state.end_minutes / 60,
                      g_pandora_box_state.end_minutes % 60);
}

string PandoraHistoryConfigSignature()
{
  return StringFormat("%s|%d|%d|%d|%d|%.4f|%.4f|%d",
                      Pandora_Box_Time_Range,
                      (int)PandoraResolveBoxTimeframe(),
                      (int)Session_Time_Dst_Mode,
                      Session_Time_Dst_Manual_Offset_Minutes,
                      ResolveTradingTimeOffsetMinutes(),
                      Pandora_Box_Offset_Points,
                      Pandora_Box_Max_Range_Points,
                      (int)Pandora_Points_Value_Mode);
}

void PandoraClearHistorySnapshots()
{
  ArrayResize(g_pandora_history_snapshots, 0);
  g_pandora_history_last_day_anchor          = 0;
  g_pandora_history_last_previous_day_anchor = 0;
  g_pandora_history_last_oldest_anchor       = 0;
  g_pandora_history_last_bar_time            = 0;
  g_pandora_history_last_signature           = "";
}

bool PandoraResolveWindowForDay(const datetime day_anchor,
                                const datetime previous_day_anchor,
                                datetime &window_start_time,
                                datetime &window_end_time,
                                string &invalid_reason)
{
  int start_minutes = 0;
  int end_minutes   = 0;
  bool wraps         = false;
  if(!PandoraParseWindowMinutes(Pandora_Box_Time_Range, start_minutes, end_minutes, wraps))
  {
    window_start_time = 0;
    window_end_time   = 0;
    invalid_reason    = "Invalid Pandora box time range";
    return false;
  }

  return PandoraResolveWindowTimes(day_anchor,
                                   previous_day_anchor,
                                   start_minutes,
                                   end_minutes,
                                   wraps,
                                   window_start_time,
                                   window_end_time,
                                   invalid_reason);
}

bool PandoraBuildHistorySnapshot(const datetime day_anchor,
                                 const int day_shift,
                                 const bool is_current_day,
                                 PandoraHistorySnapshot &snapshot_out)
{
  snapshot_out.Reset();
  snapshot_out.day_anchor     = day_anchor;
  snapshot_out.is_current_day = is_current_day;
  datetime previous_day_anchor = iTime(_Symbol, PERIOD_D1, day_shift + 1);
  string invalid_reason = "";
  snapshot_out.window_valid   = PandoraResolveWindowForDay(day_anchor,
                                                           previous_day_anchor,
                                                           snapshot_out.window_start_time,
                                                           snapshot_out.window_end_time,
                                                           invalid_reason);
  if(!snapshot_out.window_valid)
  {
    snapshot_out.invalid_reason = invalid_reason;
    if(snapshot_out.invalid_reason == "")
      snapshot_out.invalid_reason = "Invalid Pandora box time range";
    return false;
  }

  datetime query_end_time = snapshot_out.window_end_time;
  if(is_current_day)
  {
    datetime now_time = TimeCurrent();
    if(now_time < query_end_time)
      query_end_time = now_time;
  }

  snapshot_out.data_end_time = query_end_time;
  if(query_end_time <= snapshot_out.window_start_time)
  {
    snapshot_out.invalid_reason = "Pandora window pending";
    return false;
  }

  ENUM_TIMEFRAMES tf = PandoraResolveBoxTimeframe();
  MqlRates rates[];
  int copied = CopyRates(_Symbol,
                         tf,
                         snapshot_out.window_start_time,
                         query_end_time,
                         rates);
  if(copied <= 0)
  {
    snapshot_out.invalid_reason = "No data for Pandora box window";
    return false;
  }

  double box_high = rates[0].high;
  double box_low  = rates[0].low;
  for(int i = 1; i < copied; i++)
  {
    if(rates[i].high > box_high)
      box_high = rates[i].high;
    if(rates[i].low < box_low || box_low <= 0.0)
      box_low = rates[i].low;
  }

  double point_size = PandoraResolvePointSizeSafe();
  double range_points = 0.0;
  if(point_size > 0.0 && box_high > 0.0 && box_low > 0.0)
    range_points = MathAbs(box_high - box_low) / point_size;

  snapshot_out.box_computed     = true;
  snapshot_out.box_high         = box_high;
  snapshot_out.box_low          = box_low;
  snapshot_out.box_range_points = range_points;

  if(box_high <= 0.0 || box_low <= 0.0 || range_points <= 0.0)
  {
    snapshot_out.invalid_reason = "Failed to resolve Pandora box prices";
    snapshot_out.box_valid      = false;
    return false;
  }

  double offset_points = PandoraResolveDistancePointsForRange(Pandora_Box_Offset_Points,
                                                              snapshot_out.box_range_points,
                                                              true);
  double offset_price = offset_points * point_size;
  snapshot_out.breakout_high_price = box_high + offset_price;
  snapshot_out.breakout_low_price  = box_low - offset_price;

  snapshot_out.box_valid = true;
  if(Pandora_Box_Max_Range_Points > 0.0 &&
     range_points > Pandora_Box_Max_Range_Points)
  {
    snapshot_out.box_valid      = false;
    snapshot_out.invalid_reason = "Pandora box range exceeded";
  }

  return true;
}

bool PandoraHistoryNeedsRefresh()
{
  if(!PandoraStrategyEnabled())
    return (ArraySize(g_pandora_history_snapshots) > 0);

  string signature = PandoraHistoryConfigSignature();
  if(signature != g_pandora_history_last_signature)
    return true;

  datetime day_anchor = ResolveCurrentDayStart();
  if(day_anchor != g_pandora_history_last_day_anchor)
    return true;

  datetime previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);
  if(previous_day_anchor != g_pandora_history_last_previous_day_anchor)
    return true;

  datetime oldest_anchor = iTime(_Symbol, PERIOD_D1, PANDORA_HISTORY_DAYS);
  if(oldest_anchor != g_pandora_history_last_oldest_anchor)
    return true;

  datetime bar_time = iTime(_Symbol, PandoraResolveBoxTimeframe(), 0);
  if(bar_time != g_pandora_history_last_bar_time)
    return true;

  return false;
}

void PandoraRebuildHistorySnapshots()
{
  if(!PandoraStrategyEnabled())
  {
    PandoraClearHistorySnapshots();
    return;
  }

  ArrayResize(g_pandora_history_snapshots, PANDORA_HISTORY_DAYS);

  int stored = 0;
  for(int shift = 0; shift < PANDORA_HISTORY_DAYS; shift++)
  {
    datetime day_anchor = iTime(_Symbol, PERIOD_D1, shift);
    if(day_anchor <= 0)
      continue;

    PandoraHistorySnapshot snapshot;
    PandoraBuildHistorySnapshot(day_anchor, shift, (shift == 0), snapshot);
    g_pandora_history_snapshots[stored] = snapshot;
    stored++;
  }

  ArrayResize(g_pandora_history_snapshots, stored);
  g_pandora_history_last_day_anchor          = ResolveCurrentDayStart();
  g_pandora_history_last_previous_day_anchor = iTime(_Symbol, PERIOD_D1, 1);
  g_pandora_history_last_oldest_anchor       = iTime(_Symbol, PERIOD_D1, PANDORA_HISTORY_DAYS);
  g_pandora_history_last_bar_time            = iTime(_Symbol, PandoraResolveBoxTimeframe(), 0);
  g_pandora_history_last_signature           = PandoraHistoryConfigSignature();
}

void PandoraEnsureHistorySnapshots()
{
  if(!PandoraHistoryNeedsRefresh())
    return;
  PandoraRebuildHistorySnapshots();
}

int PandoraHistorySnapshotCount()
{
  PandoraEnsureHistorySnapshots();
  return ArraySize(g_pandora_history_snapshots);
}

PandoraHistorySnapshot PandoraHistorySnapshotAt(const int index)
{
  PandoraHistorySnapshot snapshot;
  if(index < 0 || index >= ArraySize(g_pandora_history_snapshots))
    return snapshot;
  return g_pandora_history_snapshots[index];
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_BOX_STATE_MQH_
