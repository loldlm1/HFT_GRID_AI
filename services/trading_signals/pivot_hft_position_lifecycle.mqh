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

bool PivotHftInitializeLocalStop(PivotHftPositionState &position_state)
{
  if(position_state.entry_price <= 0.0 ||
     Pivot_HFT_Local_SL_Points <= 0.0)
    return false;

  double distance = PivotHftDistanceToPrice(Pivot_HFT_Local_SL_Points);
  if(distance <= 0.0)
    return false;

  double stop_price = (position_state.direction == BULLISH)
                      ? position_state.entry_price - distance
                      : position_state.entry_price + distance;
  position_state.local_sl_price = PivotHftNormalizePrice(stop_price);
  position_state.trailing_stop_price = position_state.local_sl_price;
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
  double step_points = Pivot_HFT_TP_Step_Points;
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
}

bool PivotHftLocalStopTriggered(const PivotHftPositionState &position_state)
{
  if(position_state.local_sl_price <= 0.0)
    return false;

  double current_price = PivotHftCurrentCloseQuote(position_state.direction);
  if(current_price <= 0.0)
    return false;

  if(position_state.direction == BULLISH)
    return current_price <= position_state.local_sl_price;
  if(position_state.direction == BEARISH)
    return current_price >= position_state.local_sl_price;
  return false;
}

bool PivotHftHistoryNetResult(const PivotHftPositionState &position_state,
                              double &net_result,
                              datetime &close_time)
{
  net_result = 0.0;
  close_time = 0;
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
      datetime deal_time =
        (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(deal_time > close_time)
        close_time = deal_time;
    }
  }
  return has_close_deal;
}

bool PivotHftTryRearmClosedPosition(PivotHftPositionState &position_state)
{
  if(!position_state.reattempt_pending)
    return false;

  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(current_micro_bar <= 0 ||
     current_micro_bar != position_state.campaign_micro_bar_time)
  {
    position_state.reattempt_pending = false;
    return false;
  }
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
    return false;

  double close_price = PivotHftCurrentMicroClose();
  if(close_price <= 0.0 ||
     !PivotHftRefreshPivotSnapshot(false) ||
     !PivotHftRefreshBandsSnapshot(false) ||
     !PivotHftIndicatorsReady())
    return false;

  SignalTypes direction = NO_SIGNAL;
  PivotHftPivotLevels level = PIVOT_HFT_LEVEL_NONE;
  double level_price = 0.0;
  if(!PivotHftSelectCurrentTouchedLevel(close_price,
                                        direction,
                                        level,
                                        level_price))
    return false;
  if(direction != position_state.direction ||
     level != position_state.pivot_level)
    return false;

  PivotHftStartCampaign(direction,
                        level,
                        level_price,
                        current_micro_bar);
  g_pivot_hft_campaign.attempt_count =
    position_state.campaign_attempt_count + 1;
  position_state.reattempt_pending = false;
  position_state.campaign_attempt_count = g_pivot_hft_campaign.attempt_count;
  return true;
}

void PivotHftFinalizeClosedPosition(PivotHftPositionState &position_state)
{
  if(position_state.status == PIVOT_HFT_POSITION_COMPLETED ||
     position_state.status == PIVOT_HFT_POSITION_CLOSED)
    return;

  double net_result = 0.0;
  datetime close_time = 0;
  if(!PivotHftHistoryNetResult(position_state, net_result, close_time))
    return;

  position_state.net_result = net_result;
  position_state.close_time = (close_time > 0) ? close_time : TimeCurrent();
  position_state.status = PIVOT_HFT_POSITION_CLOSED;
  position_state.close_outcome = (net_result > 0.0)
                                 ? PIVOT_HFT_CLOSE_TP
                                 : ((net_result < 0.0)
                                    ? PIVOT_HFT_CLOSE_SL
                                    : PIVOT_HFT_CLOSE_BE);
  position_state.reattempt_pending = (net_result <= 0.0);
  if(!position_state.reattempt_pending)
    position_state.status = PIVOT_HFT_POSITION_COMPLETED;
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
    MarketStatusRegisterBrokerFailure("PIVOT_HFT_LOCAL_CLOSE_FAILED",
                                      g_position.ResultRetcode(),
                                      GetLastError(),
                                      true);
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    return false;
  }

  ulong retcode = g_position.ResultRetcode();
  if(!PivotHftTradeRetcodeFilled(retcode))
  {
    MarketStatusRegisterBrokerFailure("PIVOT_HFT_LOCAL_CLOSE_REJECTED",
                                      retcode,
                                      GetLastError(),
                                      true);
    position_state.close_requested = false;
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
    return false;
  }

  MarketStatusClearExecutionError("PIVOT_HFT_LOCAL_CLOSE_OK");
  position_state.close_requested = true;
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

  position_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
  if(position_state.local_sl_price <= 0.0)
    PivotHftInitializeLocalStop(position_state);

  PivotHftUpdateTrailingStop(position_state);
  if(PivotHftLocalStopTriggered(position_state))
  {
    position_state.close_requested = true;
    position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
    PivotHftClosePositionLocally(position_state);
    return;
  }

  if(position_state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
    position_state.status = PIVOT_HFT_POSITION_ACTIVE;
}

void PivotHftProcessAllPositions()
{
  int total_positions = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total_positions; i++)
    PivotHftProcessPositionState(g_pivot_hft_positions[i]);
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_POSITION_LIFECYCLE_MQH_
