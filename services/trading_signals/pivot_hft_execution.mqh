//+------------------------------------------------------------------+
//|                       pivot_hft_execution.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_

bool PivotHftHedgingAccountSupported()
{
  ENUM_ACCOUNT_MARGIN_MODE margin_mode =
    (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  return (margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

bool PivotHftTradeRetcodeFilled(const ulong retcode)
{
  return (retcode == TRADE_RETCODE_DONE ||
          retcode == TRADE_RETCODE_DONE_PARTIAL);
}

string PivotHftDirectionToken(const SignalTypes direction)
{
  return (direction == BULLISH) ? "B" : "S";
}

string PivotHftBuildPositionComment(const PivotHftCampaignState &campaign)
{
  return StringFormat("phft_%I64d_%s_%s_%d",
                      (long)campaign.micro_bar_time,
                      PivotHftDirectionToken(campaign.direction),
                      PivotHftLevelLabel(campaign.pivot_level),
                      campaign.attempt_count + 1);
}

bool PivotHftSymbolAllowsDirection(const SignalTypes direction,
                                   string &reason)
{
  reason = "";
  ENUM_SYMBOL_TRADE_MODE trade_mode =
    (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);

  if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
    reason = "symbol_disabled";
  else if(trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
    reason = "symbol_close_only";
  else if(direction == BULLISH && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
    reason = "symbol_short_only";
  else if(direction == BEARISH && trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
    reason = "symbol_long_only";

  if(reason != "")
    return false;

  long order_mode = SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE);
  if((order_mode & SYMBOL_ORDER_MARKET) != SYMBOL_ORDER_MARKET)
  {
    reason = "market_orders_disabled";
    return false;
  }
  return true;
}

bool PivotHftMarginAllowsEntry(const SignalTypes direction,
                               const double volume,
                               string &reason)
{
  reason = "";
  ENUM_ORDER_TYPE order_type = (direction == BULLISH)
                               ? ORDER_TYPE_BUY
                               : ORDER_TYPE_SELL;
  double entry_price = PivotHftCurrentEntryQuote(direction);
  double required_margin = 0.0;
  ResetLastError();
  if(entry_price <= 0.0 ||
     !OrderCalcMargin(order_type,
                      _Symbol,
                      volume,
                      entry_price,
                      required_margin))
  {
    reason = StringFormat("margin_calc_failed:%d", GetLastError());
    return false;
  }

  double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(required_margin > 0.0 && free_margin + 1e-8 < required_margin)
  {
    reason = StringFormat("margin=%.2f<%.2f", free_margin, required_margin);
    return false;
  }
  return true;
}

bool PivotHftEntryGuardsAllow(const SignalTypes direction,
                              double &normalized_volume,
                              string &reason)
{
  normalized_volume = 0.0;
  reason = "";

  if(!PivotHftHedgingAccountSupported())
    reason = "hedging_account_required";
  else if(direction != BULLISH && direction != BEARISH)
    reason = "invalid_direction";
  else if(Pivot_HFT_Lot_Size <= 0.0)
    reason = "invalid_volume";
  else if(!ProtectionRiskAllowsSignalAttempt())
    reason = "protection_block";
  else if(!DebugEquityGuardAllowsProcessing())
    reason = "debug_equity_block";
  else if(!SessionTimeFilterAllowsSignalAttempt())
    reason = "session_block";
  else if(!DailySignalLimitAllowsAttempt(direction))
    reason = "daily_limit_block";
  else if(!MarketStatusRefreshPlatformTradePermission() ||
          !MarketStatusAllowsSignalAttempts())
    reason = "market_status_block";
  else if(!IsMarketOpen())
    reason = "market_closed";
  else if(!PivotHftSymbolAllowsDirection(direction, reason))
    return false;

  if(reason != "")
    return false;

  normalized_volume = NormalizeVolumeForSymbol(_Symbol, Pivot_HFT_Lot_Size);
  if(normalized_volume <= 0.0)
  {
    reason = "invalid_normalized_volume";
    return false;
  }

  if(g_points_spread > Max_Spread)
  {
    reason = StringFormat("spread=%.1f>%.1f",
                          g_points_spread,
                          Max_Spread);
    return false;
  }
  return PivotHftMarginAllowsEntry(direction, normalized_volume, reason);
}

ulong PivotHftFindFilledPosition(const ulong deal_ticket,
                                 const SignalTypes direction,
                                 const string comment)
{
  ulong deal_position_id = 0;
  if(deal_ticket > 0 && HistoryDealSelect(deal_ticket))
    deal_position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;

    ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(direction == BULLISH && position_type != POSITION_TYPE_BUY)
      continue;
    if(direction == BEARISH && position_type != POSITION_TYPE_SELL)
      continue;
    if(comment != "" && PositionGetString(POSITION_COMMENT) != comment)
      continue;

    ulong position_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    if(deal_position_id > 0 && position_identifier != deal_position_id)
      continue;
    return position_ticket;
  }
  return 0;
}

double PivotHftResolveInitialLocalStopPrice(
  const PivotHftPositionState &position_state)
{
  if(position_state.entry_price <= 0.0 ||
     position_state.initial_sl_points <= 0.0)
    return 0.0;

  double distance = PivotHftDistanceToPrice(
    position_state.initial_sl_points);
  if(distance <= 0.0)
    return 0.0;

  double stop_price = 0.0;
  if(position_state.direction == BULLISH)
    stop_price = position_state.entry_price - distance;
  else if(position_state.direction == BEARISH)
    stop_price = position_state.entry_price + distance;
  else
    return 0.0;

  return PivotHftNormalizePrice(stop_price);
}

bool PivotHftRegisterFilledPosition(const PivotHftCampaignState &campaign,
                                    const PivotHftRiskGeometry &risk_geometry,
                                    const ulong deal_ticket,
                                    const double result_price,
                                    const double result_volume,
                                    const string comment)
{
  if(!risk_geometry.valid)
    return false;

  ulong position_ticket = PivotHftFindFilledPosition(deal_ticket,
                                                     campaign.direction,
                                                     comment);
  if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
    return false;
  if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
     PositionGetInteger(POSITION_MAGIC) != g_magic_number)
    return false;

  PivotHftPositionState position_state;
  position_state.status = PIVOT_HFT_POSITION_ACTIVE;
  position_state.direction = campaign.direction;
  position_state.pivot_level = campaign.pivot_level;
  position_state.position_ticket = position_ticket;
  position_state.position_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  position_state.entry_deal_ticket = deal_ticket;
  position_state.campaign_micro_bar_time = campaign.micro_bar_time;
  position_state.entry_time = (datetime)PositionGetInteger(POSITION_TIME);
  position_state.entry_micro_bar_time =
    PivotHftResolveMicroBarAt(position_state.entry_time);
  if(position_state.entry_micro_bar_time <= 0)
    position_state.entry_micro_bar_time = PivotHftCurrentMicroBar();
  if(position_state.entry_micro_bar_time <= 0)
    position_state.entry_micro_bar_time = campaign.micro_bar_time;
  position_state.pivot_price = campaign.pivot_price;
  position_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
  position_state.campaign_attempt_count = campaign.attempt_count;
  position_state.position_comment = PositionGetString(POSITION_COMMENT);
  position_state.local_sl_mode = risk_geometry.local_sl_mode;
  position_state.risk_bands_source_bar = risk_geometry.bands_source_bar;
  position_state.risk_bands_upper = risk_geometry.bands_upper;
  position_state.risk_bands_lower = risk_geometry.bands_lower;
  position_state.risk_band_width_points = risk_geometry.band_width_points;
  position_state.initial_sl_points = risk_geometry.initial_sl_points;
  position_state.trailing_step_points = risk_geometry.trailing_step_points;
  position_state.fixed_tp_points = risk_geometry.fixed_tp_points;

  if(position_state.entry_price <= 0.0)
    position_state.entry_price = result_price;
  if(position_state.entry_volume <= 0.0)
    position_state.entry_volume = result_volume;
  if(position_state.entry_time <= 0)
    position_state.entry_time = TimeCurrent();

  position_state.local_sl_price = PivotHftResolveInitialLocalStopPrice(
    position_state);
  position_state.trailing_stop_price = position_state.local_sl_price;

  return (position_state.entry_price > 0.0 &&
          position_state.entry_volume > 0.0 &&
          position_state.local_sl_price > 0.0 &&
          PivotHftAppendPositionState(position_state));
}

bool PivotHftExecuteEntryIntent()
{
  if(!PivotHftEntryIntentReady())
    return false;

  PivotHftCampaignState campaign = g_pivot_hft_campaign;
  if(PivotHftHasBlockingPositionLifecycle() ||
     PivotHftHasManagedBrokerPosition())
  {
    if(!g_pivot_hft_campaign.execution_slot_block_logged)
    {
      PivotHftAuditLog("ENTRY_SINGLE_FLIGHT_BLOCKED",
                       StringFormat("sequence=%s|dir=%s|level=%s|reason=position_lifecycle_occupied",
                                    campaign.sequence_id,
                                    EnumToString(campaign.direction),
                                    PivotHftLevelLabel(campaign.pivot_level)));
      g_pivot_hft_campaign.execution_slot_block_logged = true;
    }
    g_pivot_hft_last_error = "position_lifecycle_occupied";
    return false;
  }
  double normalized_volume = 0.0;
  string guard_reason = "";
  if(!PivotHftEntryGuardsAllow(campaign.direction,
                               normalized_volume,
                               guard_reason))
  {
    PivotHftAuditLog("ENTRY_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  guard_reason,
                                  campaign.attempt_count + 1));
    g_pivot_hft_last_error = guard_reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_ENTRY_BLOCK",
                                       guard_reason,
                                       0,
                                       GetLastError());
    PivotHftMarkEntryRetryable();
    return false;
  }

  PivotHftRiskGeometry risk_geometry;
  string risk_reason = "";
  if(!PivotHftResolveRiskGeometry(risk_geometry, risk_reason))
  {
    PivotHftAuditLog("ENTRY_RISK_GEOMETRY_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  risk_reason,
                                  campaign.attempt_count + 1));
    g_pivot_hft_last_error = risk_reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_RISK_GEOMETRY_BLOCK",
                                       risk_reason,
                                       0,
                                       0);
    PivotHftMarkEntryRetryable();
    return false;
  }

  string comment = PivotHftBuildPositionComment(campaign);
  g_position.SetExpertMagicNumber((ulong)g_magic_number);
  g_position.SetTypeFillingBySymbol(_Symbol);

  ResetLastError();
  bool sent = false;
  if(campaign.direction == BULLISH)
    sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  ulong retcode = g_position.ResultRetcode();
  ulong deal_ticket = (ulong)g_position.ResultDeal();
  double result_price = g_position.ResultPrice();
  double result_volume = g_position.ResultVolume();
  int last_error = GetLastError();

  PivotHftAuditLog("ORDER_SEND_RESULT",
                   StringFormat("sequence=%s|sent=%d|dir=%s|level=%s|volume=%.2f|ret=%I64u|err=%d|deal=%I64u|price=%.5f|result_volume=%.2f|server_sl=0|server_tp=0|comment=%s",
                                campaign.sequence_id,
                                (int)sent,
                                EnumToString(campaign.direction),
                                PivotHftLevelLabel(campaign.pivot_level),
                                normalized_volume,
                                retcode,
                                last_error,
                                deal_ticket,
                                result_price,
                                result_volume,
                                comment));

  if(!sent ||
     !PivotHftTradeRetcodeFilled(retcode) ||
     deal_ticket == 0 ||
     result_price <= 0.0 ||
     result_volume <= 0.0)
  {
    if(retcode == TRADE_RETCODE_NO_MONEY &&
       Debug_Stop_On_Negative_Equity &&
       MQLInfoInteger(MQL_TESTER) > 0)
    {
      g_debug_no_money_abort_pending = true;
      PivotHftAuditLog("DEBUG_STOP_PENDING",
                       StringFormat("reason=no_money|sequence=%s|ret=%I64u|err=%d",
                                    campaign.sequence_id,
                                    retcode,
                                    last_error));
    }

    g_pivot_hft_last_error = StringFormat("ret=%I64u err=%d", retcode, last_error);
    MarketStatusRegisterBrokerFailure("PIVOT_HFT_ORDER_SEND_FAILED",
                                      retcode,
                                      last_error,
                                      false);
    PivotHftMarkEntryRetryable();
    return false;
  }

  if(!PivotHftRegisterFilledPosition(campaign,
                                     risk_geometry,
                                     deal_ticket,
                                     result_price,
                                     result_volume,
                                     comment))
  {
    PivotHftAuditLog("FILL_UNRESOLVED",
                     StringFormat("sequence=%s|deal=%I64u|ret=%I64u|err=%d",
                                  campaign.sequence_id,
                                  deal_ticket,
                                  retcode,
                                  last_error));
    g_pivot_hft_last_error = "filled_position_not_resolved";
    MarketStatusRegisterExecutionError("PIVOT_HFT_FILL_UNRESOLVED",
                                       g_pivot_hft_last_error,
                                       retcode,
                                       last_error);
    PivotHftResetCampaign();
    return false;
  }

  RegisterPivotHftDailySignalStart(campaign.direction);

  int registered_index = ArraySize(g_pivot_hft_positions) - 1;
  if(registered_index >= 0)
  {
    PivotHftPositionState registered_state =
      g_pivot_hft_positions[registered_index];
    PivotHftAuditLog("FILL_REGISTERED",
                     StringFormat("sequence=%s|ticket=%I64u|position_id=%I64u|deal=%I64u|dir=%s|level=%s|entry=%.5f|volume=%.2f|attempt=%d|origin_bar=%I64d|fill_bar=%I64d|sl_mode=%s|bands_bar=%I64d|band_width_pts=%.2f|initial_sl_pts=%.2f|local_sl=%.5f|step_pts=%.2f",
                                  campaign.sequence_id,
                                  registered_state.position_ticket,
                                  registered_state.position_identifier,
                                  registered_state.entry_deal_ticket,
                                  EnumToString(registered_state.direction),
                                  PivotHftLevelLabel(registered_state.pivot_level),
                                  registered_state.entry_price,
                                  registered_state.entry_volume,
                                  registered_state.campaign_attempt_count + 1,
                                  (long)registered_state.campaign_micro_bar_time,
                                  (long)registered_state.entry_micro_bar_time,
                                  EnumToString(registered_state.local_sl_mode),
                                  (long)registered_state.risk_bands_source_bar,
                                  registered_state.risk_band_width_points,
                                  registered_state.initial_sl_points,
                                  registered_state.local_sl_price,
                                  registered_state.trailing_step_points));
  }

  g_pivot_hft_last_error = "";
  MarketStatusClearExecutionError("PIVOT_HFT_ORDER_SEND_OK");
  PivotHftResetCampaign();

  if(Enable_Logs)
  {
    PrintFormat("PIVOT_HFT_FILL ticket=%I64u deal=%I64u dir=%s price=%.5f volume=%.2f",
                g_pivot_hft_positions[ArraySize(g_pivot_hft_positions) - 1].position_ticket,
                deal_ticket,
                EnumToString(campaign.direction),
                result_price,
                result_volume);
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_
