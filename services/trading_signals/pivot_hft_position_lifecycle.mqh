//+------------------------------------------------------------------+
//|                 pivot_hft_position_lifecycle.mqh                 |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_POSITION_LIFECYCLE_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_POSITION_LIFECYCLE_MQH_

double PivotHftCurrentCloseQuote(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_bid;
  if(direction == BEARISH)
    return g_ask;
  return 0.0;
}

PivotHftCloseTriggers PivotHftResolveLocalCloseTrigger(
  const PivotHftPositionState &position_state)
{
  if(position_state.trailing_step_index <= 0)
    return PIVOT_HFT_CLOSE_TRIGGER_INITIAL_SL;
  if(position_state.trailing_step_index == 1)
    return PIVOT_HFT_CLOSE_TRIGGER_BREAK_EVEN;
  return PIVOT_HFT_CLOSE_TRIGGER_TRAILING;
}

PivotHftNetClasses PivotHftClassifyNetResult(const double net_result)
{
  if(net_result > 0.0)
    return PIVOT_HFT_NET_PROFIT;
  if(net_result < 0.0)
    return PIVOT_HFT_NET_LOSS;
  return PIVOT_HFT_NET_FLAT;
}

string PivotHftCloseTriggerLabel(const PivotHftCloseTriggers trigger)
{
  switch(trigger)
  {
    case PIVOT_HFT_CLOSE_TRIGGER_INITIAL_SL:
      return "INITIAL_SL";
    case PIVOT_HFT_CLOSE_TRIGGER_BREAK_EVEN:
      return "BREAK_EVEN";
    case PIVOT_HFT_CLOSE_TRIGGER_TRAILING:
      return "TRAILING";
    case PIVOT_HFT_CLOSE_TRIGGER_EXTERNAL:
      return "EXTERNAL";
    case PIVOT_HFT_CLOSE_TRIGGER_FIXED_TP:
      return "FIXED_TP";
    case PIVOT_HFT_CLOSE_TRIGGER_ENTRY_SAFETY:
      return "ENTRY_SAFETY";
    case PIVOT_HFT_CLOSE_TRIGGER_NONE:
    default:
      return "NONE";
  }
}

string PivotHftNetClassLabel(const PivotHftNetClasses net_class)
{
  switch(net_class)
  {
    case PIVOT_HFT_NET_PROFIT:
      return "PROFIT";
    case PIVOT_HFT_NET_LOSS:
      return "LOSS";
    case PIVOT_HFT_NET_FLAT:
      return "FLAT";
    case PIVOT_HFT_NET_NONE:
    default:
      return "NONE";
  }
}

string PivotHftLevelMaskLabel(const ulong level_mask)
{
  string label = "";
  for(int level_index = 1;
      level_index < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      level_index++)
  {
    if((level_mask & ((ulong)1 << level_index)) == 0)
      continue;
    if(label != "")
      label += ",";
    label += PivotHftLevelLabel((PivotHftPivotLevels)level_index);
  }
  return (label == "") ? "-" : label;
}

void PivotHftClearCloseTrigger(PivotHftPositionState &position_state)
{
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_NONE;
  position_state.close_trigger_time = 0;
  position_state.close_trigger_quote = 0.0;
  position_state.close_trigger_stop = 0.0;
  position_state.close_trigger_target = 0.0;
  position_state.close_trigger_step = 0;
  position_state.close_send_confirmed = false;
}

void PivotHftCaptureLocalCloseTrigger(
  PivotHftPositionState &position_state,
  const double trigger_quote)
{
  position_state.close_trigger = PivotHftResolveLocalCloseTrigger(
    position_state);
  position_state.close_trigger_time = TimeCurrent();
  position_state.close_trigger_quote = trigger_quote;
  position_state.close_trigger_stop = position_state.local_sl_price;
  position_state.close_trigger_target = 0.0;
  position_state.close_trigger_step = position_state.trailing_step_index;
}

void PivotHftCaptureFixedTpCloseTrigger(
  PivotHftPositionState &position_state,
  const double trigger_quote)
{
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_FIXED_TP;
  position_state.close_trigger_time = TimeCurrent();
  position_state.close_trigger_quote = trigger_quote;
  position_state.close_trigger_stop = position_state.local_sl_price;
  position_state.close_trigger_target = position_state.local_tp_price;
  position_state.close_trigger_step = position_state.trailing_step_index;
}

void PivotHftCaptureEntrySafetyCloseTrigger(
  PivotHftPositionState &position_state)
{
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_ENTRY_SAFETY;
  position_state.close_trigger_time = TimeCurrent();
  position_state.close_trigger_quote =
    position_state.entry_safety_close_quote;
  position_state.close_trigger_stop = position_state.local_sl_price;
  position_state.close_trigger_target = 0.0;
  position_state.close_trigger_step = 0;
}

void PivotHftCaptureExternalCloseTrigger(
  PivotHftPositionState &position_state,
  const double trigger_quote)
{
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_EXTERNAL;
  position_state.close_trigger_time = TimeCurrent();
  position_state.close_trigger_quote = trigger_quote;
  position_state.close_trigger_stop = position_state.local_sl_price;
  position_state.close_trigger_target = position_state.local_tp_price;
  position_state.close_trigger_step = position_state.trailing_step_index;
}

bool PivotHftResolveFreshCloseTick(MqlTick &tick,
                                   string &reason)
{
  ZeroMemory(tick);
  reason = "";
  ResetLastError();
  if(!SymbolInfoTick(_Symbol, tick))
  {
    reason = StringFormat("fresh_tick_unavailable:%d", GetLastError());
    return false;
  }
  if(tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
  {
    reason = "invalid_fresh_tick";
    return false;
  }

  g_ask = tick.ask;
  g_bid = tick.bid;
  g_local_spread = tick.ask - tick.bid;
  double point_size = PivotHftPointSize();
  if(point_size > 0.0)
    g_points_spread = g_local_spread / point_size;
  return true;
}

bool PivotHftCalculateGrossResult(
  const PivotHftPositionState &position_state,
  const double close_price,
  double &gross_result)
{
  gross_result = 0.0;
  if(position_state.entry_price <= 0.0 ||
     position_state.entry_volume <= 0.0 ||
     close_price <= 0.0)
    return false;

  ENUM_ORDER_TYPE order_type = (position_state.direction == BULLISH)
                               ? ORDER_TYPE_BUY
                               : ORDER_TYPE_SELL;
  if(position_state.direction != BULLISH &&
     position_state.direction != BEARISH)
    return false;

  ResetLastError();
  return OrderCalcProfit(order_type,
                         _Symbol,
                         position_state.entry_volume,
                         position_state.entry_price,
                         close_price,
                         gross_result);
}

bool PivotHftEvaluatePostFillEntrySafety(
  PivotHftPositionState &position_state)
{
  if(position_state.entry_safety_checked)
    return !position_state.entry_safety_failed;

  position_state.entry_safety_checked = true;
  position_state.entry_safety_failed = false;
  position_state.entry_safety_post_fill_reason = "";

  double point_size = position_state.entry_safety.point_size;
  double required_floor_points =
    position_state.entry_safety.broker_floor_points;
  MqlTick fresh_tick;
  ZeroMemory(fresh_tick);
  ResetLastError();
  bool tick_ready = SymbolInfoTick(_Symbol, fresh_tick);
  int tick_error = GetLastError();

  if(!position_state.entry_safety.valid ||
     position_state.entry_safety.blocked)
    position_state.entry_safety_post_fill_reason =
      "pre_send_safety_snapshot_invalid";
  else if(!MathIsValidNumber(point_size) || point_size <= 0.0)
    position_state.entry_safety_post_fill_reason = "invalid_symbol_point_size";
  else if(!MathIsValidNumber(required_floor_points) ||
          required_floor_points <= 0.0)
    position_state.entry_safety_post_fill_reason =
      "invalid_broker_distance_floor";
  else if(position_state.entry_price <= 0.0 ||
          position_state.local_sl_price <= 0.0)
    position_state.entry_safety_post_fill_reason =
      "invalid_fill_or_local_sl";
  else if(!tick_ready)
    position_state.entry_safety_post_fill_reason =
      StringFormat("fresh_tick_unavailable:%d", tick_error);
  else if(fresh_tick.ask <= 0.0 || fresh_tick.bid <= 0.0 ||
          fresh_tick.ask < fresh_tick.bid)
    position_state.entry_safety_post_fill_reason = "invalid_fresh_tick";
  else
  {
    position_state.entry_safety_actual_spread_points =
      (fresh_tick.ask - fresh_tick.bid) / point_size;
    if(position_state.direction == BULLISH)
    {
      position_state.entry_safety_close_quote = fresh_tick.bid;
      position_state.entry_safety_available_buffer_points =
        (fresh_tick.bid - position_state.local_sl_price) / point_size;
    }
    else if(position_state.direction == BEARISH)
    {
      position_state.entry_safety_close_quote = fresh_tick.ask;
      position_state.entry_safety_available_buffer_points =
        (position_state.local_sl_price - fresh_tick.ask) / point_size;
    }
    else
      position_state.entry_safety_post_fill_reason = "invalid_direction";

    if(position_state.entry_safety_post_fill_reason == "" &&
       (!MathIsValidNumber(
          position_state.entry_safety_actual_spread_points) ||
        !MathIsValidNumber(
          position_state.entry_safety_available_buffer_points)))
      position_state.entry_safety_post_fill_reason =
        "invalid_post_fill_distance";
    if(position_state.entry_safety_post_fill_reason == "" &&
       position_state.entry_safety_available_buffer_points + 1e-9 <
         required_floor_points)
      position_state.entry_safety_post_fill_reason =
        "available_buffer_below_broker_floor";
  }

  if(position_state.entry_safety_post_fill_reason == "")
  {
    position_state.entry_safety_post_fill_reason = "ok";
    return true;
  }

  position_state.entry_safety_failed = true;
  PivotHftAuditLog("FILL_ENTRY_DISTANCE_INVALID",
                   StringFormat("%s|fill=%.5f|fresh_bid=%.5f|fresh_ask=%.5f|close_quote=%.5f|post_fill_local_sl=%.5f|actual_spread_pts=%.2f|available_buffer_pts=%.2f|required_broker_floor_pts=%.2f|pre_spread_pts=%.2f|reason=%s|%s",
                                PivotHftPositionAuditIdentityFields(
                                  position_state),
                                position_state.entry_price,
                                fresh_tick.bid,
                                fresh_tick.ask,
                                position_state.entry_safety_close_quote,
                                position_state.local_sl_price,
                                position_state.entry_safety_actual_spread_points,
                                position_state.entry_safety_available_buffer_points,
                                required_floor_points,
                                position_state.entry_safety.spread_points,
                                position_state.entry_safety_post_fill_reason,
                                PivotHftPositionRiskAuditFields(
                                  position_state)));
  return false;
}

bool PivotHftInitializeLocalStop(PivotHftPositionState &position_state)
{
  position_state.local_sl_price = PivotHftResolveInitialLocalStopPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.initial_sl_points);
  position_state.trailing_stop_price = position_state.local_sl_price;
  if(position_state.local_sl_price > 0.0)
  {
    PivotHftAuditLog("LOCAL_SL_INITIALIZED",
                     StringFormat("%s|dir=%s|entry=%.5f|local_sl=%.5f|bands_bar=%I64d|band_width_pts=%.2f|initial_sl_pts=%.2f|step_pts=%.2f|source=recovery",
                                  PivotHftPositionAuditIdentityFields(
                                    position_state),
                                  EnumToString(position_state.direction),
                                  position_state.entry_price,
                                  position_state.local_sl_price,
                                  (long)position_state.risk_bands_source_bar,
                                  position_state.risk_band_width_points,
                                  position_state.initial_sl_points,
                                  position_state.trailing_step_points));
  }
  return (position_state.local_sl_price > 0.0);
}

bool PivotHftInitializeLocalTarget(PivotHftPositionState &position_state)
{
  if(position_state.fixed_tp_points <= 0.0)
    return false;

  position_state.local_tp_price = PivotHftResolveFixedLocalTargetPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.fixed_tp_points);
  if(position_state.local_tp_price > 0.0)
  {
    PivotHftAuditLog("LOCAL_TP_INITIALIZED",
                     StringFormat("%s|dir=%s|entry=%.5f|fixed_tp_pts=%.2f|local_tp=%.5f|source=recovery",
                                  PivotHftPositionAuditIdentityFields(
                                    position_state),
                                  EnumToString(position_state.direction),
                                  position_state.entry_price,
                                  position_state.fixed_tp_points,
                                  position_state.local_tp_price));
  }
  return (position_state.local_tp_price > 0.0);
}

double PivotHftFavorableDistancePoints(const PivotHftPositionState &position_state,
                                       const double current_price)
{
  double point_size = PivotHftPointSize();
  if(point_size <= 0.0 || position_state.entry_price <= 0.0 ||
     current_price <= 0.0)
    return 0.0;

  double distance = (position_state.direction == BULLISH)
                    ? current_price - position_state.entry_price
                    : position_state.entry_price - current_price;
  if(distance <= 0.0)
    return 0.0;
  return distance / point_size;
}

void PivotHftUpdateTrailingStop(PivotHftPositionState &position_state)
{
  double previous_stop = position_state.local_sl_price;
  int previous_step = position_state.trailing_step_index;
  double step_points = position_state.trailing_step_points;
  if(step_points <= 0.0 || position_state.entry_price <= 0.0)
    return;

  double current_price = PivotHftCurrentCloseQuote(position_state.direction);
  double favorable_points = PivotHftFavorableDistancePoints(position_state,
                                                            current_price);
  int completed_steps = (int)MathFloor(favorable_points / step_points);
  if(completed_steps < 1)
    return;

  double step_price = PivotHftDistanceToPrice(step_points);
  if(step_price <= 0.0)
    return;

  double desired_stop = (position_state.direction == BULLISH)
                        ? position_state.entry_price +
                          (completed_steps - 1) * step_price
                        : position_state.entry_price -
                          (completed_steps - 1) * step_price;
  desired_stop = PivotHftNormalizePrice(desired_stop);

  bool moves_forward = false;
  if(position_state.direction == BULLISH)
    moves_forward = (position_state.local_sl_price <= 0.0 ||
                     desired_stop > position_state.local_sl_price);
  else
    moves_forward = (position_state.local_sl_price <= 0.0 ||
                     desired_stop < position_state.local_sl_price);

  if(moves_forward)
  {
    position_state.local_sl_price = desired_stop;
    position_state.trailing_stop_price = desired_stop;
  }
  if(completed_steps > position_state.trailing_step_index)
    position_state.trailing_step_index = completed_steps;

  if(position_state.trailing_step_index != previous_step ||
     MathAbs(position_state.local_sl_price - previous_stop) >
       PivotHftTickSize() * 0.5)
  {
    PivotHftAuditLog("TRAILING_ADVANCED",
                     StringFormat("%s|dir=%s|entry=%.5f|previous_sl=%.5f|step=%d|be=%d|%s",
                                  PivotHftPositionAuditIdentityFields(
                                    position_state),
                                  EnumToString(position_state.direction),
                                  position_state.entry_price,
                                  previous_stop,
                                  position_state.trailing_step_index,
                                  (int)(position_state.trailing_step_index >= 1),
                                  PivotHftPositionRiskAuditFields(
                                    position_state)));
  }
}

bool PivotHftLocalStopTriggered(const PivotHftPositionState &position_state,
                                 double &trigger_quote)
{
  trigger_quote = 0.0;
  if(position_state.local_sl_price <= 0.0)
    return false;

  trigger_quote = PivotHftCurrentCloseQuote(position_state.direction);
  if(trigger_quote <= 0.0)
    return false;

  if(position_state.direction == BULLISH)
    return trigger_quote <= position_state.local_sl_price;
  if(position_state.direction == BEARISH)
    return trigger_quote >= position_state.local_sl_price;
  return false;
}

bool PivotHftFixedTpTriggered(const PivotHftPositionState &position_state,
                              double &trigger_quote)
{
  trigger_quote = 0.0;
  if(position_state.local_tp_price <= 0.0)
    return false;

  trigger_quote = PivotHftCurrentCloseQuote(position_state.direction);
  if(trigger_quote <= 0.0)
    return false;

  if(position_state.direction == BULLISH)
    return trigger_quote >= position_state.local_tp_price;
  if(position_state.direction == BEARISH)
    return trigger_quote <= position_state.local_tp_price;
  return false;
}

bool PivotHftHistoryNetResult(const PivotHftPositionState &position_state,
                               double &net_result,
                               datetime &close_time,
                               ulong &exit_deal_ticket,
                               double &close_price,
                               int &close_deal_count)
{
  net_result = 0.0;
  close_time = 0;
  exit_deal_ticket = 0;
  close_price = 0.0;
  close_deal_count = 0;
  if(position_state.position_identifier == 0 &&
     position_state.position_ticket == 0)
    return false;

  datetime to_time = TimeCurrent();
  datetime from_time = (position_state.entry_time > 86400)
                       ? position_state.entry_time - 86400
                       : to_time - 7 * 86400;
  if(from_time < 0)
    from_time = 0;
  if(!HistorySelect(from_time, to_time))
    return false;

  bool has_close_deal = false;
  long latest_close_time_msc = 0;
  double latest_close_price = 0.0;
  double close_price_volume = 0.0;
  double close_volume = 0.0;
  int total_deals = HistoryDealsTotal();
  for(int i = 0; i < total_deals; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket == 0)
      continue;
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      continue;
    if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_magic_number)
      continue;

    ulong deal_position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    if(position_state.position_identifier > 0 &&
       deal_position_id != position_state.position_identifier)
      continue;
    if(position_state.position_identifier == 0 &&
       deal_position_id != position_state.position_ticket)
      continue;

    net_result += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    net_result += HistoryDealGetDouble(deal_ticket, DEAL_FEE);

    ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
    {
      has_close_deal = true;
      close_deal_count++;
      datetime deal_time =
        (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      long deal_time_msc =
        HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
      if(deal_time_msc <= 0)
        deal_time_msc = (long)deal_time * 1000;

      double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      if(deal_price > 0.0 && deal_volume > 0.0)
      {
        close_price_volume += deal_price * deal_volume;
        close_volume += deal_volume;
      }

      if(deal_time_msc > latest_close_time_msc ||
         (deal_time_msc == latest_close_time_msc &&
          deal_ticket > exit_deal_ticket))
      {
        latest_close_time_msc = deal_time_msc;
        close_time = deal_time;
        exit_deal_ticket = deal_ticket;
        latest_close_price = deal_price;
      }
    }
  }

  if(close_volume > 0.0)
    close_price = PivotHftNormalizePrice(close_price_volume / close_volume);
  else
    close_price = PivotHftNormalizePrice(latest_close_price);
  return has_close_deal;
}

bool PivotHftPositionPivotSetStillAllowsRearm(
  const PivotHftPositionState &position_state,
  double &current_level_price)
{
  current_level_price = 0.0;
  if(!g_pivot_hft_pivots.valid)
    return false;

  current_level_price = PivotHftResolveLevelPrice(
    position_state.pivot_level,
    g_pivot_hft_pivots);
  double tolerance = PivotHftTickSize() * 0.5;
  return (current_level_price > 0.0 &&
           MathAbs(current_level_price - position_state.pivot_price) <=
             tolerance);
}

void PivotHftDeferRetry(PivotHftPositionState &position_state,
                        const string reason,
                        const datetime current_micro_bar)
{
  if(!PivotHftSetRetryState(position_state,
                            PIVOT_HFT_RETRY_DEFERRED,
                            reason))
    return;

  PivotHftAuditLog("REARM_DEFERRED",
                   PivotHftRetryDecisionAuditFields(position_state,
                                                    current_micro_bar));
}

bool PivotHftTryRearmClosedPosition(PivotHftPositionState &position_state)
{
  if(!position_state.reattempt_pending)
    return false;

  PivotHftPrepareNextRetryDecision(position_state);
  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(current_micro_bar <= 0)
  {
    PivotHftDeferRetry(position_state,
                       "micro_bar_unavailable",
                       current_micro_bar);
    return false;
  }
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
  {
    PivotHftDeferRetry(position_state,
                       "campaign_slot_busy",
                       current_micro_bar);
    return false;
  }
  if(PivotHftHasOtherBlockingPositionLifecycle(
       PivotHftPositionExecutionId(position_state),
       position_state.position_ticket))
  {
    PivotHftDeferRetry(position_state,
                       "position_lifecycle_busy",
                       current_micro_bar);
    return false;
  }
  if(PivotHftHasManagedBrokerPosition())
  {
    PivotHftDeferRetry(position_state,
                       "broker_position_busy",
                       current_micro_bar);
    return false;
  }

  int retry_ordinal = position_state.next_retry_ordinal;
  PivotHftExecutionSources next_execution_source =
    position_state.next_retry_execution_source;
  if(!ProtectionRiskAllowsSignalAttempt())
  {
    PivotHftDeferRetry(position_state,
                       "protection_block",
                       current_micro_bar);
    return false;
  }
  if(!SessionTimeFilterAllowsSignalAttempt())
  {
    PivotHftDeferRetry(position_state,
                       "session_block",
                       current_micro_bar);
    return false;
  }
  if(next_execution_source == PIVOT_HFT_EXECUTION_BROKER &&
     !DailySignalLimitAllowsAttempt(position_state.direction))
  {
    PivotHftDeferRetry(position_state,
                       "daily_limit",
                       current_micro_bar);
    return false;
  }
  if(!MarketStatusAllowsSignalAttempts())
  {
    PivotHftDeferRetry(position_state,
                       "market_status",
                       current_micro_bar);
    return false;
  }

  if(!PivotHftRefreshPivotSnapshot(false))
  {
    PivotHftDeferRetry(position_state,
                       "pivot_snapshot_wait",
                       current_micro_bar);
    return false;
  }
  if(!position_state.reattempt_pending)
    return false;
  if(!PivotHftIndicatorsReady())
  {
    PivotHftDeferRetry(position_state,
                       "indicators_wait",
                       current_micro_bar);
    return false;
  }

  double current_level_price = 0.0;
  if(!PivotHftPositionPivotSetStillAllowsRearm(position_state,
                                               current_level_price))
  {
    position_state.reattempt_pending = false;
    bool state_changed = PivotHftSetRetryState(
      position_state,
      PIVOT_HFT_RETRY_INVALIDATED,
      "pivot_set_changed");
    if(state_changed)
    {
      PivotHftAuditLog("REARM_INVALIDATED",
                       StringFormat("%s|stored_pivot_price=%.5f|current_pivot_price=%.5f",
                                    PivotHftRetryDecisionAuditFields(
                                      position_state,
                                      current_micro_bar),
                                    position_state.pivot_price,
                                    current_level_price));
      PivotHftCaptureTerminalRetryVisual(position_state,
                                         current_micro_bar);
    }
    position_state.status = PIVOT_HFT_POSITION_COMPLETED;
    return false;
  }

  double fresh_extreme = PivotHftCurrentEntryQuote(position_state.direction);
  if(fresh_extreme <= 0.0)
  {
    PivotHftDeferRetry(position_state,
                       "entry_quote_unavailable",
                       current_micro_bar);
    return false;
  }

  PivotHftStartCampaign(position_state.direction,
                        position_state.pivot_level,
                        position_state.pivot_price,
                        current_micro_bar,
                        position_state.campaign_sequence_id,
                        position_state.position_ticket,
                        retry_ordinal,
                        position_state.campaign_attempt_count + 1,
                        PivotHftPositionExecutionId(position_state),
                        position_state.entry_slippage_points,
                        position_state.close_slippage_points,
                        position_state.estimated_cost_per_lot,
                        position_state.model_source_execution_id,
                        position_state.model_source_execution_source,
                        position_state.entry_slippage_provenance,
                        position_state.close_slippage_provenance,
                        position_state.cost_per_lot_provenance);
  g_pivot_hft_campaign.tracked_extreme = fresh_extreme;
  position_state.reattempt_pending = false;
  bool state_changed = PivotHftSetRetryState(
    position_state,
    PIVOT_HFT_RETRY_REARMED,
    "campaign_rearmed");
  if(state_changed)
  {
    PivotHftAuditLog("POSITION_REARMED",
                     StringFormat("%s|attempt=%d|start_real_retry=%d|extreme=%.5f|next_threshold=%.5f|admission=latched|%s",
                                  PivotHftRetryDecisionAuditFields(
                                    position_state,
                                    current_micro_bar),
                                  g_pivot_hft_campaign.attempt_count + 1,
                                  Pivot_HFT_Start_Real_Retry,
                                  g_pivot_hft_campaign.tracked_extreme,
                                  PivotHftCampaignEntryThreshold(
                                    g_pivot_hft_campaign),
                                  PivotHftCampaignModelProvenanceAuditFields(
                                    g_pivot_hft_campaign)));
  }
  position_state.campaign_attempt_count = g_pivot_hft_campaign.attempt_count;
  position_state.campaign_retry_ordinal =
    g_pivot_hft_campaign.retry_ordinal;
  position_state.status = PIVOT_HFT_POSITION_COMPLETED;
  return true;
}

void PivotHftCompletePositionFinalization(
  PivotHftPositionState &position_state,
  const double net_result,
  const datetime close_time,
  const ulong exit_deal_ticket,
  const double close_price,
  const int close_deal_count,
  const bool register_daily_outcome)
{
  position_state.net_result = net_result;
  position_state.exit_deal_ticket = exit_deal_ticket;
  position_state.close_price = close_price;
  position_state.close_time = (close_time > 0) ? close_time : TimeCurrent();
  if(position_state.close_trigger == PIVOT_HFT_CLOSE_TRIGGER_NONE)
  {
    position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_EXTERNAL;
    position_state.close_trigger_time = position_state.close_time;
  }
  position_state.net_class = PivotHftClassifyNetResult(net_result);
  position_state.status = PIVOT_HFT_POSITION_CLOSED;

  bool retry_eligible = (net_result <= 0.0 &&
                          position_state.close_requested &&
                          position_state.close_trigger !=
                            PIVOT_HFT_CLOSE_TRIGGER_EXTERNAL);
  int current_retry_number = PivotHftMarketRetryNumber(
    position_state.campaign_retry_ordinal);
  PivotHftPrepareNextRetryDecision(position_state);
  int next_retry_number = position_state.next_retry_number;
  PivotHftExecutionSources next_execution_source =
    position_state.next_retry_execution_source;
  position_state.reattempt_pending =
    (retry_eligible && Pivot_HFT_Start_Real_Retry > 0);
  bool pending_transition = false;
  bool disabled_transition = false;
  if(position_state.reattempt_pending)
  {
    pending_transition = PivotHftSetRetryState(
      position_state,
      PIVOT_HFT_RETRY_PENDING,
      "eligible_non_positive_close");
  }
  else if(retry_eligible)
  {
    disabled_transition = PivotHftSetRetryState(
      position_state,
      PIVOT_HFT_RETRY_DISABLED,
      "start_real_retry_zero");
  }
  else
  {
    PivotHftSetRetryState(position_state,
                          PIVOT_HFT_RETRY_NONE,
                          "");
  }

  PivotHftAuditLog("POSITION_FINALIZED",
                   StringFormat("%s|position_id=%I64u|dir=%s|level=%s|close_trigger=%s|trigger_time=%I64d|trigger_quote=%.5f|trigger_stop=%.5f|trigger_target=%.5f|trigger_step=%d|exit_deal=%I64u|close_price=%.5f|exit_deals=%d|net=%.5f|net_class=%s|close_requested=%d|close_confirmed=%d|retry_number=%d|retry_ordinal=%d|next_retry_number=%d|next_execution_source=%s|start_real_retry=%d|reattempt=%d|close_time=%I64d|%s|%s",
                                 PivotHftPositionAuditIdentityFields(
                                   position_state),
                                 position_state.position_identifier,
                                 EnumToString(position_state.direction),
                                 PivotHftLevelLabel(position_state.pivot_level),
                                 PivotHftCloseTriggerLabel(
                                   position_state.close_trigger),
                                 (long)position_state.close_trigger_time,
                                 position_state.close_trigger_quote,
                                 position_state.close_trigger_stop,
                                 position_state.close_trigger_target,
                                 position_state.close_trigger_step,
                                 position_state.exit_deal_ticket,
                                 position_state.close_price,
                                 close_deal_count,
                                 net_result,
                                 PivotHftNetClassLabel(position_state.net_class),
                                 (int)position_state.close_requested,
                                 (int)position_state.close_send_confirmed,
                                 current_retry_number,
                                 position_state.campaign_retry_ordinal,
                                 next_retry_number,
                                 PivotHftExecutionSourceLabel(
                                   next_execution_source),
                                 Pivot_HFT_Start_Real_Retry,
                                 (int)position_state.reattempt_pending,
                                 (long)position_state.close_time,
                                 PivotHftPositionRiskAuditFields(
                                   position_state),
                                  PivotHftExecutionModelAuditFields(
                                    position_state)));
  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(pending_transition)
  {
    PivotHftAuditLog("REARM_PENDING",
                     StringFormat("%s|start_real_retry=%d|net=%.5f|close_trigger=%s",
                                  PivotHftRetryDecisionAuditFields(
                                    position_state,
                                    current_micro_bar),
                                  Pivot_HFT_Start_Real_Retry,
                                  net_result,
                                  PivotHftCloseTriggerLabel(
                                    position_state.close_trigger)));
  }
  else if(disabled_transition)
  {
    PivotHftAuditLog("RETRY_DISABLED",
                     StringFormat("%s|start_real_retry=%d|net=%.5f|close_trigger=%s",
                                  PivotHftRetryDecisionAuditFields(
                                    position_state,
                                    current_micro_bar),
                                  Pivot_HFT_Start_Real_Retry,
                                  net_result,
                                  PivotHftCloseTriggerLabel(
                                    position_state.close_trigger)));
    PivotHftCaptureTerminalRetryVisual(position_state,
                                       current_micro_bar);
  }
  if(register_daily_outcome &&
     !position_state.daily_outcome_registered)
  {
    RegisterDailySignalOutcome(position_state.direction, net_result);
    position_state.daily_outcome_registered = true;
  }
  if(!position_state.reattempt_pending)
  {
    ulong consumed_mask = 0;
    if(net_result > 0.0)
    {
      consumed_mask = PivotHftMarkWinningLevelLadderCompleted(
        position_state.entry_micro_bar_time,
        position_state.direction,
        position_state.pivot_level);
    }
    if(consumed_mask == 0)
    {
      PivotHftMarkCampaignLevelCompleted(position_state.entry_micro_bar_time,
                                         position_state.pivot_level);
    }
    else
    {
      PivotHftAuditLog("WINNING_LEVELS_CONSUMED",
                       StringFormat("%s|dir=%s|winner=%s|bar=%I64d|consumed_mask=%I64u|consumed=%s",
                                    PivotHftPositionAuditIdentityFields(
                                      position_state),
                                    EnumToString(position_state.direction),
                                    PivotHftLevelLabel(
                                      position_state.pivot_level),
                                    (long)position_state.entry_micro_bar_time,
                                    consumed_mask,
                                    PivotHftLevelMaskLabel(consumed_mask)));
    }
    position_state.status = PIVOT_HFT_POSITION_COMPLETED;
  }
}

void PivotHftFinalizeClosedPosition(PivotHftPositionState &position_state)
{
  if(position_state.status == PIVOT_HFT_POSITION_COMPLETED ||
     position_state.status == PIVOT_HFT_POSITION_CLOSED ||
     position_state.execution_source != PIVOT_HFT_EXECUTION_BROKER)
    return;

  double net_result = 0.0;
  datetime close_time = 0;
  ulong exit_deal_ticket = 0;
  double close_price = 0.0;
  int close_deal_count = 0;
  if(!PivotHftHistoryNetResult(position_state,
                               net_result,
                               close_time,
                               exit_deal_ticket,
                               close_price,
                               close_deal_count))
    return;

  double gross_result = 0.0;
  bool gross_ready = PivotHftCalculateGrossResult(position_state,
                                                   close_price,
                                                   gross_result);
  if(!gross_ready)
  {
    gross_result = net_result;
    PivotHftAuditLog("RESULT_MODEL_FALLBACK",
                     StringFormat("%s|reason=order_calc_profit_failed|err=%d|net=%.5f|close_price=%.5f",
                                  PivotHftPositionAuditIdentityFields(
                                    position_state),
                                  GetLastError(),
                                  net_result,
                                  close_price));
  }
  position_state.gross_result = gross_result;
  position_state.estimated_cost_result = net_result - gross_result;
  bool cost_model_observed = (gross_ready &&
                              position_state.entry_volume > 0.0 &&
                              MathIsValidNumber(
                                position_state.estimated_cost_result));
  if(cost_model_observed)
  {
    position_state.estimated_cost_per_lot =
      position_state.estimated_cost_result / position_state.entry_volume;
    if(!MathIsValidNumber(position_state.estimated_cost_per_lot))
      cost_model_observed = false;
  }
  if(!cost_model_observed)
  {
    position_state.estimated_cost_result = 0.0;
    position_state.estimated_cost_per_lot = 0.0;
  }
  position_state.cost_per_lot_provenance = cost_model_observed
    ? PIVOT_HFT_MODEL_VALUE_OBSERVED
    : PIVOT_HFT_MODEL_VALUE_FALLBACK;

  bool close_model_observed =
    (position_state.close_trigger_quote > 0.0 &&
     close_price > 0.0 &&
     PivotHftPointSize() > 0.0);
  position_state.close_slippage_points = PivotHftSignedCloseSlippagePoints(
    position_state.direction,
    position_state.close_trigger_quote,
    close_price);
  if(!MathIsValidNumber(position_state.close_slippage_points))
  {
    position_state.close_slippage_points = 0.0;
    close_model_observed = false;
  }
  position_state.close_slippage_provenance = close_model_observed
    ? PIVOT_HFT_MODEL_VALUE_OBSERVED
    : PIVOT_HFT_MODEL_VALUE_FALLBACK;
  position_state.model_source_execution_source =
    PIVOT_HFT_EXECUTION_BROKER;
  position_state.model_source_execution_id =
    PivotHftPositionExecutionId(position_state);

  PivotHftCompletePositionFinalization(position_state,
                                       net_result,
                                       close_time,
                                       exit_deal_ticket,
                                       close_price,
                                       close_deal_count,
                                       true);
}

void PivotHftAbortVirtualPosition(PivotHftPositionState &position_state,
                                  const string reason)
{
  PivotHftAuditLog("VIRTUAL_LIFECYCLE_ABORTED",
                   StringFormat("%s|sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|reason=%s",
                                PivotHftPositionAuditIdentityFields(
                                  position_state),
                                position_state.campaign_sequence_id,
                                EnumToString(position_state.direction),
                                PivotHftLevelLabel(position_state.pivot_level),
                                PivotHftMarketRetryNumber(
                                  position_state.campaign_retry_ordinal),
                                position_state.campaign_retry_ordinal,
                                reason));
  position_state.reattempt_pending = false;
  PivotHftMarkCampaignLevelCompleted(position_state.entry_micro_bar_time,
                                     position_state.pivot_level);
  position_state.status = PIVOT_HFT_POSITION_COMPLETED;
}

bool PivotHftFinalizeVirtualPosition(PivotHftPositionState &position_state)
{
  if(position_state.execution_source != PIVOT_HFT_EXECUTION_VIRTUAL ||
     position_state.status == PIVOT_HFT_POSITION_COMPLETED)
    return false;

  MqlTick close_tick;
  string close_reason = "";
  if(!PivotHftResolveFreshCloseTick(close_tick, close_reason))
  {
    PivotHftAbortVirtualPosition(position_state, close_reason);
    return false;
  }

  double executable_quote = PivotHftCloseQuoteFromTick(
    position_state.direction,
    close_tick);
  double modeled_close_slippage_points =
    position_state.close_slippage_points;
  double close_price = PivotHftApplyCloseSlippage(
    position_state.direction,
    executable_quote,
    modeled_close_slippage_points);
  if(close_price <= 0.0)
  {
    PivotHftAbortVirtualPosition(position_state,
                                 "invalid_virtual_close_price");
    return false;
  }

  double gross_result = 0.0;
  if(!PivotHftCalculateGrossResult(position_state,
                                   close_price,
                                   gross_result))
  {
    close_reason = StringFormat("order_calc_profit_failed:%d",
                                GetLastError());
    PivotHftAbortVirtualPosition(position_state, close_reason);
    return false;
  }

  double estimated_cost_result =
    position_state.estimated_cost_per_lot * position_state.entry_volume;
  if(!MathIsValidNumber(estimated_cost_result))
  {
    PivotHftAbortVirtualPosition(position_state,
                                 "invalid_virtual_cost_estimate");
    return false;
  }

  position_state.close_slippage_points =
    PivotHftSignedCloseSlippagePoints(position_state.direction,
                                      executable_quote,
                                      close_price);
  position_state.gross_result = gross_result;
  position_state.estimated_cost_result = estimated_cost_result;
  position_state.close_send_confirmed = true;
  double net_result = gross_result + estimated_cost_result;
  PivotHftAuditLog("VIRTUAL_CLOSE_FILLED",
                   StringFormat("%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|close_trigger=%s|trigger_quote=%.5f|bid=%.5f|ask=%.5f|executable_quote=%.5f|close_price=%.5f|modeled_close_slippage_pts=%.2f|applied_close_slippage_pts=%.2f|gross=%.5f|estimated_cost=%.5f|net=%.5f",
                                PivotHftPositionAuditIdentityFields(
                                  position_state),
                                EnumToString(position_state.direction),
                                PivotHftLevelLabel(position_state.pivot_level),
                                PivotHftMarketRetryNumber(
                                  position_state.campaign_retry_ordinal),
                                position_state.campaign_retry_ordinal,
                                PivotHftCloseTriggerLabel(
                                  position_state.close_trigger),
                                position_state.close_trigger_quote,
                                close_tick.bid,
                                close_tick.ask,
                                executable_quote,
                                close_price,
                                modeled_close_slippage_points,
                                position_state.close_slippage_points,
                                gross_result,
                                estimated_cost_result,
                                net_result));

  PivotHftCompletePositionFinalization(position_state,
                                       net_result,
                                       TimeCurrent(),
                                       0,
                                       close_price,
                                       1,
                                       false);
  return true;
}

bool PivotHftClosePositionLocally(PivotHftPositionState &position_state)
{
  if(position_state.position_ticket == 0 ||
     !PositionSelectByTicket(position_state.position_ticket))
    return false;
  if(!MarketStatusRefreshPlatformTradePermission() ||
     !MarketStatusAllowsBrokerActions())
    return false;

  ResetLastError();
  if(!g_position.PositionClose(position_state.position_ticket))
  {
    ulong retcode = g_position.ResultRetcode();
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("PIVOT_HFT_LOCAL_CLOSE_FAILED",
                                      retcode,
                                      last_error,
                                      true);
    datetime now_time = TimeCurrent();
    if(position_state.last_close_audit_time == 0 ||
       now_time - position_state.last_close_audit_time >= 30)
    {
      PivotHftAuditLog("LOCAL_CLOSE_FAILED",
                       StringFormat("%s|ret=%I64u|err=%d|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_target=%.5f|trigger_step=%d|%s",
                                     PivotHftPositionAuditIdentityFields(
                                       position_state),
                                     retcode,
                                     last_error,
                                     PivotHftCloseTriggerLabel(
                                       position_state.close_trigger),
                                     position_state.close_trigger_quote,
                                     position_state.close_trigger_stop,
                                     position_state.close_trigger_target,
                                     position_state.close_trigger_step,
                                     PivotHftPositionRiskAuditFields(
                                       position_state)));
      position_state.last_close_audit_time = now_time;
    }
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    PivotHftClearCloseTrigger(position_state);
    return false;
  }

  ulong retcode = g_position.ResultRetcode();
  ulong result_deal_ticket = (ulong)g_position.ResultDeal();
  double result_price = g_position.ResultPrice();
  double result_volume = g_position.ResultVolume();
  if(!PivotHftTradeRetcodeFilled(retcode))
  {
    int last_error = GetLastError();
    MarketStatusRegisterBrokerFailure("PIVOT_HFT_LOCAL_CLOSE_REJECTED",
                                      retcode,
                                      last_error,
                                      true);
    datetime now_time = TimeCurrent();
    if(position_state.last_close_audit_time == 0 ||
       now_time - position_state.last_close_audit_time >= 30)
    {
      PivotHftAuditLog("LOCAL_CLOSE_REJECTED",
                       StringFormat("%s|ret=%I64u|err=%d|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_target=%.5f|trigger_step=%d|result_deal=%I64u|result_price=%.5f|%s",
                                     PivotHftPositionAuditIdentityFields(
                                       position_state),
                                     retcode,
                                     last_error,
                                     PivotHftCloseTriggerLabel(
                                       position_state.close_trigger),
                                     position_state.close_trigger_quote,
                                     position_state.close_trigger_stop,
                                     position_state.close_trigger_target,
                                     position_state.close_trigger_step,
                                     result_deal_ticket,
                                     result_price,
                                     PivotHftPositionRiskAuditFields(
                                       position_state)));
      position_state.last_close_audit_time = now_time;
    }
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    PivotHftClearCloseTrigger(position_state);
    return false;
  }

  MarketStatusClearExecutionError("PIVOT_HFT_LOCAL_CLOSE_OK");
  PivotHftAuditLog("LOCAL_CLOSE_SENT",
                   StringFormat("%s|ret=%I64u|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_target=%.5f|trigger_step=%d|result_deal=%I64u|result_price=%.5f|result_volume=%.2f|%s",
                                 PivotHftPositionAuditIdentityFields(
                                   position_state),
                                 retcode,
                                 PivotHftCloseTriggerLabel(
                                   position_state.close_trigger),
                                 position_state.close_trigger_quote,
                                 position_state.close_trigger_stop,
                                 position_state.close_trigger_target,
                                 position_state.close_trigger_step,
                                 result_deal_ticket,
                                 result_price,
                                 result_volume,
                                 PivotHftPositionRiskAuditFields(
                                   position_state)));
  position_state.close_requested = true;
  position_state.close_send_confirmed =
    (retcode == TRADE_RETCODE_DONE);
  position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
  return true;
}

void PivotHftProcessVirtualPositionState(
  PivotHftPositionState &position_state)
{
  if(position_state.execution_source != PIVOT_HFT_EXECUTION_VIRTUAL ||
     position_state.status != PIVOT_HFT_POSITION_ACTIVE)
    return;

  ulong force_close_generation = MarketStatusForceCloseGeneration();
  if(force_close_generation >
     position_state.force_close_generation_at_entry)
  {
    double trigger_quote = PivotHftCurrentCloseQuote(
      position_state.direction);
    PivotHftCaptureExternalCloseTrigger(position_state, trigger_quote);
    position_state.close_requested = false;
    PivotHftAuditLog("VIRTUAL_FORCE_CLOSE",
                     StringFormat("%s|generation=%I64u|scheduled_at=%I64d|reason=%s|trigger_quote=%.5f",
                                  PivotHftPositionAuditIdentityFields(
                                    position_state),
                                  force_close_generation,
                                  (long)MarketStatusLastForceCloseTime(),
                                  MarketStatusLastForceCloseReason(),
                                  trigger_quote));
    PivotHftFinalizeVirtualPosition(position_state);
    return;
  }

  if(position_state.local_sl_price <= 0.0 &&
     !PivotHftInitializeLocalStop(position_state))
  {
    PivotHftAbortVirtualPosition(position_state,
                                 "virtual_local_sl_init_failed");
    return;
  }

  if(!PivotHftEvaluatePostFillEntrySafety(position_state))
  {
    PivotHftCaptureEntrySafetyCloseTrigger(position_state);
    position_state.close_requested = true;
    PivotHftFinalizeVirtualPosition(position_state);
    return;
  }

  if(position_state.local_tp_price <= 0.0 &&
     position_state.fixed_tp_points > 0.0 &&
     !PivotHftInitializeLocalTarget(position_state))
  {
    PivotHftAbortVirtualPosition(position_state,
                                 "virtual_local_tp_init_failed");
    return;
  }

  double trigger_quote = 0.0;
  if(PivotHftFixedTpTriggered(position_state, trigger_quote))
  {
    PivotHftCaptureFixedTpCloseTrigger(position_state, trigger_quote);
    position_state.close_requested = true;
    PivotHftFinalizeVirtualPosition(position_state);
    return;
  }

  PivotHftUpdateTrailingStop(position_state);
  trigger_quote = 0.0;
  if(PivotHftLocalStopTriggered(position_state, trigger_quote))
  {
    PivotHftCaptureLocalCloseTrigger(position_state, trigger_quote);
    position_state.close_requested = true;
    PivotHftFinalizeVirtualPosition(position_state);
  }
}

void PivotHftProcessPositionState(PivotHftPositionState &position_state)
{
  if(position_state.status == PIVOT_HFT_POSITION_COMPLETED)
    return;

  if(position_state.status == PIVOT_HFT_POSITION_CLOSED)
  {
    PivotHftTryRearmClosedPosition(position_state);
    return;
  }

  if(position_state.execution_source == PIVOT_HFT_EXECUTION_VIRTUAL)
  {
    PivotHftProcessVirtualPositionState(position_state);
    return;
  }

  if(position_state.position_ticket == 0)
    return;
  if(!PositionSelectByTicket(position_state.position_ticket))
  {
    PivotHftFinalizeClosedPosition(position_state);
    return;
  }

  if(position_state.status == PIVOT_HFT_POSITION_CLOSE_WAIT &&
     position_state.close_requested)
  {
    if(!position_state.close_send_confirmed)
      PivotHftClosePositionLocally(position_state);
    return;
  }

  position_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
  if(position_state.local_sl_price <= 0.0)
    PivotHftInitializeLocalStop(position_state);

  if(!PivotHftEvaluatePostFillEntrySafety(position_state))
  {
    PivotHftCaptureEntrySafetyCloseTrigger(position_state);
    position_state.close_requested = true;
    position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    PivotHftClosePositionLocally(position_state);
    return;
  }

  if(position_state.local_tp_price <= 0.0 &&
     position_state.fixed_tp_points > 0.0)
    PivotHftInitializeLocalTarget(position_state);

  double trigger_quote = 0.0;
  if(PivotHftFixedTpTriggered(position_state, trigger_quote))
  {
    PivotHftCaptureFixedTpCloseTrigger(position_state, trigger_quote);
    position_state.close_requested = true;
    position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    PivotHftClosePositionLocally(position_state);
    return;
  }

  PivotHftUpdateTrailingStop(position_state);
  trigger_quote = 0.0;
  if(PivotHftLocalStopTriggered(position_state, trigger_quote))
  {
    PivotHftCaptureLocalCloseTrigger(position_state, trigger_quote);
    position_state.close_requested = true;
    position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    PivotHftClosePositionLocally(position_state);
    return;
  }

  if(position_state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
  {
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    PivotHftClearCloseTrigger(position_state);
  }
}

void PivotHftProcessAllPositions()
{
  int total_positions = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total_positions; i++)
    PivotHftProcessPositionState(g_pivot_hft_positions[i]);

  PivotHftCompactCompletedPositionStates();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_POSITION_LIFECYCLE_MQH_
