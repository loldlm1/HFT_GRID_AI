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

void PivotHftClearCloseTrigger(PivotHftPositionState &position_state)
{
  position_state.close_trigger = PIVOT_HFT_CLOSE_TRIGGER_NONE;
  position_state.close_trigger_time = 0;
  position_state.close_trigger_quote = 0.0;
  position_state.close_trigger_stop = 0.0;
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
  position_state.close_trigger_step = position_state.trailing_step_index;
}

bool PivotHftInitializeLocalStop(PivotHftPositionState &position_state)
{
  position_state.local_sl_price = PivotHftResolveInitialLocalStopPrice(
    position_state);
  position_state.trailing_stop_price = position_state.local_sl_price;
  if(position_state.local_sl_price > 0.0)
  {
    PivotHftAuditLog("LOCAL_SL_INITIALIZED",
                     StringFormat("ticket=%I64u|dir=%s|entry=%.5f|local_sl=%.5f|sl_mode=%s|bands_bar=%I64d|band_width_pts=%.2f|initial_sl_pts=%.2f|step_pts=%.2f|source=recovery",
                                  position_state.position_ticket,
                                  EnumToString(position_state.direction),
                                  position_state.entry_price,
                                  position_state.local_sl_price,
                                  EnumToString(position_state.local_sl_mode),
                                  (long)position_state.risk_bands_source_bar,
                                  position_state.risk_band_width_points,
                                  position_state.initial_sl_points,
                                  position_state.trailing_step_points));
  }
  return (position_state.local_sl_price > 0.0);
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
                     StringFormat("ticket=%I64u|dir=%s|entry=%.5f|previous_sl=%.5f|local_sl=%.5f|step_pts=%.2f|step=%d|be=%d",
                                  position_state.position_ticket,
                                  EnumToString(position_state.direction),
                                  position_state.entry_price,
                                  previous_stop,
                                  position_state.local_sl_price,
                                  step_points,
                                  position_state.trailing_step_index,
                                  (int)(position_state.trailing_step_index >= 1)));
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

bool PivotHftPositionLevelStillAllowsRearm(
  const PivotHftPositionState &position_state,
  const double close_price)
{
  if(close_price <= 0.0 ||
     !g_pivot_hft_pivots.valid ||
     !PivotHftIndicatorsReady())
    return false;

  double current_level_price = PivotHftResolveLevelPrice(
    position_state.pivot_level,
    g_pivot_hft_pivots);
  double tolerance = PivotHftTickSize() * 0.5;
  if(current_level_price <= 0.0 ||
     MathAbs(current_level_price - position_state.pivot_price) > tolerance)
    return false;

  if(position_state.direction == BEARISH)
    return (close_price >= position_state.pivot_price &&
            close_price >= g_pivot_hft_bands_upper);
  if(position_state.direction == BULLISH)
    return (close_price <= position_state.pivot_price &&
            close_price <= g_pivot_hft_bands_lower);
  return false;
}

bool PivotHftTryRearmClosedPosition(PivotHftPositionState &position_state)
{
  if(!position_state.reattempt_pending)
    return false;

  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(current_micro_bar <= 0 ||
     current_micro_bar != position_state.entry_micro_bar_time)
  {
    PivotHftAuditLog("REARM_EXPIRED",
                     StringFormat("ticket=%I64u|level=%s|origin_bar=%I64d|fill_bar=%I64d|current_bar=%I64d",
                                  position_state.position_ticket,
                                  PivotHftLevelLabel(position_state.pivot_level),
                                  (long)position_state.campaign_micro_bar_time,
                                  (long)position_state.entry_micro_bar_time,
                                  (long)current_micro_bar));
    position_state.reattempt_pending = false;
    position_state.status = PIVOT_HFT_POSITION_COMPLETED;
    return false;
  }
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
    return false;
  if(PivotHftHasOtherBlockingPositionLifecycle(
       position_state.position_ticket) ||
     PivotHftHasManagedBrokerPosition())
    return false;
  if(!ProtectionRiskAllowsSignalAttempt() ||
     !SessionTimeFilterAllowsSignalAttempt() ||
     !DailySignalLimitAllowsAttempt(position_state.direction) ||
     !MarketStatusAllowsSignalAttempts())
    return false;

  double close_price = PivotHftCurrentMicroClose();
  if(close_price <= 0.0 ||
     !PivotHftRefreshPivotSnapshot(false) ||
     !PivotHftRefreshBandsSnapshot(false) ||
     !PivotHftIndicatorsReady())
    return false;

  if(!PivotHftPositionLevelStillAllowsRearm(position_state, close_price))
    return false;

  PivotHftStartCampaign(position_state.direction,
                        position_state.pivot_level,
                        position_state.pivot_price,
                        current_micro_bar);
  g_pivot_hft_campaign.attempt_count =
    position_state.campaign_attempt_count + 1;
  position_state.reattempt_pending = false;
  position_state.campaign_attempt_count = g_pivot_hft_campaign.attempt_count;
  position_state.status = PIVOT_HFT_POSITION_COMPLETED;
  PivotHftAuditLog("POSITION_REARMED",
                   StringFormat("ticket=%I64u|sequence=%s|dir=%s|level=%s|attempt=%d",
                                position_state.position_ticket,
                                g_pivot_hft_campaign.sequence_id,
                                EnumToString(position_state.direction),
                                PivotHftLevelLabel(position_state.pivot_level),
                                g_pivot_hft_campaign.attempt_count + 1));
  return true;
}

void PivotHftFinalizeClosedPosition(PivotHftPositionState &position_state)
{
  if(position_state.status == PIVOT_HFT_POSITION_COMPLETED ||
     position_state.status == PIVOT_HFT_POSITION_CLOSED)
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
  position_state.reattempt_pending = (net_result <= 0.0 &&
                                      position_state.close_requested);
  PivotHftAuditLog("POSITION_FINALIZED",
                   StringFormat("ticket=%I64u|position_id=%I64u|dir=%s|level=%s|close_trigger=%s|trigger_time=%I64d|trigger_quote=%.5f|trigger_stop=%.5f|trigger_step=%d|exit_deal=%I64u|close_price=%.5f|exit_deals=%d|net=%.2f|net_class=%s|close_requested=%d|close_confirmed=%d|reattempt=%d|close_time=%I64d",
                                 position_state.position_ticket,
                                 position_state.position_identifier,
                                 EnumToString(position_state.direction),
                                 PivotHftLevelLabel(position_state.pivot_level),
                                 PivotHftCloseTriggerLabel(
                                   position_state.close_trigger),
                                 (long)position_state.close_trigger_time,
                                 position_state.close_trigger_quote,
                                 position_state.close_trigger_stop,
                                 position_state.close_trigger_step,
                                 position_state.exit_deal_ticket,
                                 position_state.close_price,
                                 close_deal_count,
                                 net_result,
                                 PivotHftNetClassLabel(position_state.net_class),
                                 (int)position_state.close_requested,
                                 (int)position_state.close_send_confirmed,
                                 (int)position_state.reattempt_pending,
                                 (long)position_state.close_time));
  if(!position_state.daily_outcome_registered)
  {
    RegisterDailySignalOutcome(position_state.direction, net_result);
    position_state.daily_outcome_registered = true;
  }
  if(!position_state.reattempt_pending)
  {
    PivotHftMarkCampaignLevelCompleted(position_state.entry_micro_bar_time,
                                       position_state.pivot_level);
    position_state.status = PIVOT_HFT_POSITION_COMPLETED;
  }
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
                       StringFormat("ticket=%I64u|ret=%I64u|err=%d|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_step=%d",
                                     position_state.position_ticket,
                                     retcode,
                                     last_error,
                                     PivotHftCloseTriggerLabel(
                                       position_state.close_trigger),
                                     position_state.close_trigger_quote,
                                     position_state.close_trigger_stop,
                                     position_state.close_trigger_step));
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
                       StringFormat("ticket=%I64u|ret=%I64u|err=%d|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_step=%d|result_deal=%I64u|result_price=%.5f",
                                     position_state.position_ticket,
                                     retcode,
                                     last_error,
                                     PivotHftCloseTriggerLabel(
                                       position_state.close_trigger),
                                     position_state.close_trigger_quote,
                                     position_state.close_trigger_stop,
                                     position_state.close_trigger_step,
                                     result_deal_ticket,
                                     result_price));
      position_state.last_close_audit_time = now_time;
    }
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    PivotHftClearCloseTrigger(position_state);
    return false;
  }

  MarketStatusClearExecutionError("PIVOT_HFT_LOCAL_CLOSE_OK");
  PivotHftAuditLog("LOCAL_CLOSE_SENT",
                   StringFormat("ticket=%I64u|ret=%I64u|close_trigger=%s|trigger_quote=%.5f|trigger_stop=%.5f|trigger_step=%d|result_deal=%I64u|result_price=%.5f|result_volume=%.2f",
                                 position_state.position_ticket,
                                 retcode,
                                 PivotHftCloseTriggerLabel(
                                   position_state.close_trigger),
                                 position_state.close_trigger_quote,
                                 position_state.close_trigger_stop,
                                 position_state.close_trigger_step,
                                 result_deal_ticket,
                                 result_price,
                                 result_volume));
  position_state.close_requested = true;
  position_state.close_send_confirmed =
    (retcode == TRADE_RETCODE_DONE);
  position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
  return true;
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

  PivotHftUpdateTrailingStop(position_state);
  double trigger_quote = 0.0;
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
