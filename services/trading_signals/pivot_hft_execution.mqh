//+------------------------------------------------------------------+
//|                       pivot_hft_execution.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_

bool PivotHftClosePositionLocally(PivotHftPositionState &position_state);

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

bool PivotHftResolveFreshExecutionTick(MqlTick &tick,
                                       double &spread_points,
                                       string &reason)
{
  ZeroMemory(tick);
  spread_points = 0.0;
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

  double point_size = PivotHftPointSize();
  if(!MathIsValidNumber(point_size) || point_size <= 0.0)
  {
    reason = "invalid_symbol_point_size";
    return false;
  }

  spread_points = (tick.ask - tick.bid) / point_size;
  if(!MathIsValidNumber(spread_points) || spread_points < 0.0)
  {
    reason = "invalid_fresh_spread";
    return false;
  }
  if(spread_points > Max_Spread)
  {
    reason = StringFormat("spread=%.1f>%.1f", spread_points, Max_Spread);
    return false;
  }

  g_ask = tick.ask;
  g_bid = tick.bid;
  g_local_spread = tick.ask - tick.bid;
  g_points_spread = spread_points;
  return true;
}

double PivotHftEntryQuoteFromTick(const SignalTypes direction,
                                  const MqlTick &tick)
{
  if(direction == BULLISH)
    return tick.ask;
  if(direction == BEARISH)
    return tick.bid;
  return 0.0;
}

double PivotHftCloseQuoteFromTick(const SignalTypes direction,
                                  const MqlTick &tick)
{
  if(direction == BULLISH)
    return tick.bid;
  if(direction == BEARISH)
    return tick.ask;
  return 0.0;
}

double PivotHftApplyEntrySlippage(const SignalTypes direction,
                                  const double executable_quote,
                                  const double slippage_points)
{
  if(executable_quote <= 0.0 ||
     !MathIsValidNumber(slippage_points))
    return 0.0;

  double slippage_price = PivotHftDistanceToPrice(
    MathAbs(slippage_points));
  if(slippage_points < 0.0)
    slippage_price = -slippage_price;

  double fill_price = 0.0;
  if(direction == BULLISH)
    fill_price = executable_quote + slippage_price;
  else if(direction == BEARISH)
    fill_price = executable_quote - slippage_price;
  return PivotHftNormalizePrice(fill_price);
}

double PivotHftApplyCloseSlippage(const SignalTypes direction,
                                  const double executable_quote,
                                  const double slippage_points)
{
  if(executable_quote <= 0.0 ||
     !MathIsValidNumber(slippage_points))
    return 0.0;

  double slippage_price = PivotHftDistanceToPrice(
    MathAbs(slippage_points));
  if(slippage_points < 0.0)
    slippage_price = -slippage_price;

  double fill_price = 0.0;
  if(direction == BULLISH)
    fill_price = executable_quote - slippage_price;
  else if(direction == BEARISH)
    fill_price = executable_quote + slippage_price;
  return PivotHftNormalizePrice(fill_price);
}

double PivotHftSignedEntrySlippagePoints(const SignalTypes direction,
                                         const double request_quote,
                                         const double fill_price)
{
  double point_size = PivotHftPointSize();
  if(point_size <= 0.0 || request_quote <= 0.0 || fill_price <= 0.0)
    return 0.0;
  if(direction == BULLISH)
    return (fill_price - request_quote) / point_size;
  if(direction == BEARISH)
    return (request_quote - fill_price) / point_size;
  return 0.0;
}

double PivotHftSignedCloseSlippagePoints(const SignalTypes direction,
                                         const double request_quote,
                                         const double fill_price)
{
  double point_size = PivotHftPointSize();
  if(point_size <= 0.0 || request_quote <= 0.0 || fill_price <= 0.0)
    return 0.0;
  if(direction == BULLISH)
    return (request_quote - fill_price) / point_size;
  if(direction == BEARISH)
    return (fill_price - request_quote) / point_size;
  return 0.0;
}

string PivotHftBuildVirtualExecutionId(
  const PivotHftCampaignState &campaign)
{
  return StringFormat("V_%I64d_%s_%s_R%d_A%d",
                      (long)campaign.micro_bar_time,
                      PivotHftDirectionToken(campaign.direction),
                      PivotHftLevelLabel(campaign.pivot_level),
                      PivotHftMarketRetryNumber(campaign.retry_ordinal),
                      campaign.attempt_count + 1);
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
                              string &reason,
                              const bool require_daily_budget = true)
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
  else if(require_daily_budget &&
          !DailySignalLimitAllowsAttempt(direction))
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
                                 ulong &position_identifier)
{
  position_identifier = 0;
  ulong deal_position_id = 0;
  if(deal_ticket > 0 && HistoryDealSelect(deal_ticket))
  {
    if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol ||
       HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != g_magic_number)
      return 0;

    ENUM_DEAL_TYPE deal_type =
      (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
    if((direction == BULLISH && deal_type != DEAL_TYPE_BUY) ||
       (direction == BEARISH && deal_type != DEAL_TYPE_SELL))
      return 0;
    deal_position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
  }

  ulong matched_ticket = 0;
  ulong matched_identifier = 0;
  int matched_count = 0;
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

    ulong candidate_identifier =
      (ulong)PositionGetInteger(POSITION_IDENTIFIER);
    if(deal_position_id > 0 && candidate_identifier != deal_position_id)
      continue;
    matched_ticket = position_ticket;
    matched_identifier = candidate_identifier;
    matched_count++;
  }
  if(matched_count != 1)
    return 0;

  position_identifier = matched_identifier;
  return matched_ticket;
}

double PivotHftResolveInitialLocalStopPrice(
  const SignalTypes direction,
  const double entry_price,
  const double initial_sl_points)
{
  if(entry_price <= 0.0 || initial_sl_points <= 0.0)
    return 0.0;

  double distance = PivotHftDistanceToPrice(initial_sl_points);
  if(distance <= 0.0)
    return 0.0;

  double stop_price = 0.0;
  if(direction == BULLISH)
    stop_price = entry_price - distance;
  else if(direction == BEARISH)
    stop_price = entry_price + distance;
  else
    return 0.0;

  stop_price = PivotHftNormalizePrice(stop_price);
  if(direction == BULLISH && stop_price >= entry_price)
    return 0.0;
  if(direction == BEARISH && stop_price <= entry_price)
    return 0.0;
  return stop_price;
}

double PivotHftResolveFixedLocalTargetPrice(
  const SignalTypes direction,
  const double entry_price,
  const double fixed_tp_points)
{
  if(entry_price <= 0.0 || fixed_tp_points <= 0.0)
    return 0.0;

  double distance = PivotHftDistanceToPrice(fixed_tp_points);
  if(distance <= 0.0)
    return 0.0;

  double target_price = 0.0;
  if(direction == BULLISH)
    target_price = entry_price + distance;
  else if(direction == BEARISH)
    target_price = entry_price - distance;
  else
    return 0.0;

  target_price = PivotHftNormalizePrice(target_price);
  if(direction == BULLISH && target_price <= entry_price)
    return 0.0;
  if(direction == BEARISH && target_price >= entry_price)
    return 0.0;
  return target_price;
}

string PivotHftPositionRiskAuditFields(
  const PivotHftPositionState &position_state)
{
  return StringFormat("bands_bar=%I64d|band_width_pts=%.2f|initial_sl_pts=%.2f|step_pts=%.2f|step_sl_ratio=%.4f|fixed_tp_sl_ratio=%.4f|fixed_tp_pts=%.2f|local_sl=%.5f|local_tp=%.5f",
                      (long)position_state.risk_bands_source_bar,
                      position_state.risk_band_width_points,
                      position_state.initial_sl_points,
                      position_state.trailing_step_points,
                      Pivot_HFT_TP_Step_SL_Ratio,
                      Pivot_HFT_Fixed_TP_SL_Ratio,
                      position_state.fixed_tp_points,
                      position_state.local_sl_price,
                      position_state.local_tp_price);
}

string PivotHftEntrySafetyAuditFields(
  const PivotHftEntrySafetySnapshot &entry_safety)
{
  return StringFormat("requested_sl_pts=%.2f|required_sl_pts=%.2f|spread_pts=%.2f|stops_pts=%.2f|freeze_pts=%.2f|broker_floor_pts=%.2f|point=%.8f|tick=%.8f|reason=%s",
                      entry_safety.requested_sl_points,
                      entry_safety.required_initial_sl_points,
                      entry_safety.spread_points,
                      entry_safety.stops_level_points,
                      entry_safety.freeze_level_points,
                      entry_safety.broker_floor_points,
                      entry_safety.point_size,
                      entry_safety.tick_size,
                      entry_safety.reason);
}

string PivotHftExecutionModelAuditFields(
  const PivotHftPositionState &position_state)
{
  return StringFormat("request_quote=%.5f|entry_slippage_pts=%.2f|close_slippage_pts=%.2f|gross=%.5f|estimated_cost=%.5f|estimated_cost_per_lot=%.5f|%s",
                      position_state.entry_request_quote,
                      position_state.entry_slippage_points,
                      position_state.close_slippage_points,
                      position_state.gross_result,
                      position_state.estimated_cost_result,
                      position_state.estimated_cost_per_lot,
                      PivotHftPositionModelProvenanceAuditFields(
                        position_state));
}

bool PivotHftRegisterFilledPosition(const PivotHftCampaignState &campaign,
                                    const PivotHftRiskGeometry &risk_geometry,
                                    const ulong deal_ticket,
                                    const double result_price,
                                    const double result_volume,
                                    const string comment,
                                    const double request_quote,
                                    const bool daily_start_registered,
                                    int &registered_index,
                                    ulong &resolved_position_ticket,
                                    ulong &resolved_position_identifier)
{
  registered_index = -1;
  resolved_position_ticket = 0;
  resolved_position_identifier = 0;
  if(!risk_geometry.valid)
    return false;

  ulong position_ticket = PivotHftFindFilledPosition(
    deal_ticket,
    campaign.direction,
    resolved_position_identifier);
  resolved_position_ticket = position_ticket;
  if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
    return false;
  if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
     PositionGetInteger(POSITION_MAGIC) != g_magic_number)
    return false;

  PivotHftPositionState position_state;
  position_state.status = PIVOT_HFT_POSITION_ACTIVE;
  position_state.execution_source = PIVOT_HFT_EXECUTION_BROKER;
  position_state.direction = campaign.direction;
  position_state.pivot_level = campaign.pivot_level;
  position_state.position_ticket = position_ticket;
  position_state.execution_id = StringFormat("%I64u", position_ticket);
  position_state.position_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  resolved_position_identifier = position_state.position_identifier;
  position_state.entry_deal_ticket = deal_ticket;
  position_state.campaign_retry_source_ticket =
    campaign.retry_source_ticket;
  position_state.campaign_retry_source_id = campaign.retry_source_id;
  position_state.force_close_generation_at_entry =
    MarketStatusForceCloseGeneration();
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
  position_state.entry_request_quote = request_quote;
  position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
  position_state.campaign_attempt_count = campaign.attempt_count;
  position_state.campaign_retry_ordinal = campaign.retry_ordinal;
  position_state.campaign_sequence_id = campaign.sequence_id;
  position_state.position_comment = PositionGetString(POSITION_COMMENT);
  position_state.entry_safety = campaign.entry_safety;
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
  position_state.entry_slippage_points =
    PivotHftSignedEntrySlippagePoints(position_state.direction,
                                      position_state.entry_request_quote,
                                      position_state.entry_price);
  bool entry_slippage_observed =
    (position_state.entry_request_quote > 0.0 &&
     position_state.entry_price > 0.0 &&
     PivotHftPointSize() > 0.0 &&
     MathIsValidNumber(position_state.entry_slippage_points));
  if(!entry_slippage_observed)
    position_state.entry_slippage_points = 0.0;
  position_state.model_source_execution_source =
    PIVOT_HFT_EXECUTION_BROKER;
  position_state.model_source_execution_id = position_state.execution_id;
  position_state.entry_slippage_provenance = entry_slippage_observed
    ? PIVOT_HFT_MODEL_VALUE_OBSERVED
    : PIVOT_HFT_MODEL_VALUE_FALLBACK;
  position_state.close_slippage_provenance =
    PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
  position_state.cost_per_lot_provenance =
    PIVOT_HFT_MODEL_VALUE_UNAVAILABLE;
  position_state.daily_start_registered = daily_start_registered;

  position_state.local_sl_price = PivotHftResolveInitialLocalStopPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.initial_sl_points);
  position_state.local_tp_price = PivotHftResolveFixedLocalTargetPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.fixed_tp_points);
  position_state.trailing_stop_price = position_state.local_sl_price;

  if(position_state.entry_price <= 0.0 ||
     position_state.entry_volume <= 0.0 ||
     position_state.local_sl_price <= 0.0 ||
     (position_state.fixed_tp_points > 0.0 &&
      position_state.local_tp_price <= 0.0) ||
     !PivotHftAppendPositionState(position_state))
    return false;

  registered_index = PivotHftFindPositionStateIndex(
    position_state.execution_id,
    position_state.position_ticket);
  return (registered_index >= 0);
}

bool PivotHftAppendEmergencyFilledPosition(
  const PivotHftCampaignState &campaign,
  const PivotHftRiskGeometry &risk_geometry,
  const ulong deal_ticket,
  const ulong position_ticket,
  const ulong position_identifier,
  const double result_price,
  const double result_volume,
  const string comment,
  const double request_quote,
  const bool daily_start_registered,
  const PivotHftCloseTriggers close_trigger,
  const string retry_state_reason,
  int &emergency_index)
{
  emergency_index = -1;
  if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
    return false;
  if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
     PositionGetInteger(POSITION_MAGIC) != g_magic_number)
    return false;

  ulong selected_identifier =
    (ulong)PositionGetInteger(POSITION_IDENTIFIER);
  if(position_identifier > 0 && selected_identifier != position_identifier)
    return false;

  PivotHftPositionState position_state;
  position_state.status = PIVOT_HFT_POSITION_CLOSE_WAIT;
  position_state.execution_source = PIVOT_HFT_EXECUTION_BROKER;
  position_state.close_trigger = close_trigger;
  position_state.retry_state = PIVOT_HFT_RETRY_DISABLED;
  position_state.retry_state_reason = retry_state_reason;
  position_state.retry_state_time = TimeCurrent();
  position_state.direction = campaign.direction;
  position_state.pivot_level = campaign.pivot_level;
  position_state.position_ticket = position_ticket;
  position_state.position_identifier = selected_identifier;
  position_state.entry_deal_ticket = deal_ticket;
  position_state.campaign_retry_source_ticket =
    campaign.retry_source_ticket;
  position_state.force_close_generation_at_entry =
    MarketStatusForceCloseGeneration();
  position_state.campaign_micro_bar_time = campaign.micro_bar_time;
  position_state.entry_time =
    (datetime)PositionGetInteger(POSITION_TIME);
  if(position_state.entry_time <= 0)
    position_state.entry_time = TimeCurrent();
  position_state.entry_micro_bar_time =
    PivotHftResolveMicroBarAt(position_state.entry_time);
  if(position_state.entry_micro_bar_time <= 0)
    position_state.entry_micro_bar_time = campaign.micro_bar_time;
  position_state.close_trigger_time = TimeCurrent();
  position_state.pivot_price = campaign.pivot_price;
  position_state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
  if(position_state.entry_price <= 0.0)
    position_state.entry_price = result_price;
  position_state.entry_request_quote = request_quote;
  position_state.entry_volume = PositionGetDouble(POSITION_VOLUME);
  if(position_state.entry_volume <= 0.0)
    position_state.entry_volume = result_volume;
  position_state.close_trigger_quote = position_state.entry_price;
  position_state.campaign_attempt_count = campaign.attempt_count;
  position_state.campaign_retry_ordinal = campaign.retry_ordinal;
  position_state.execution_id = StringFormat("%I64u", position_ticket);
  position_state.campaign_retry_source_id = campaign.retry_source_id;
  position_state.campaign_sequence_id = campaign.sequence_id;
  position_state.position_comment = PositionGetString(POSITION_COMMENT);
  if(position_state.position_comment == "")
    position_state.position_comment = comment;
  position_state.entry_safety = campaign.entry_safety;
  position_state.daily_start_registered = daily_start_registered;
  position_state.emergency_lifecycle = true;
  position_state.close_requested = true;
  position_state.close_send_confirmed = false;
  if(risk_geometry.valid)
  {
    position_state.risk_bands_source_bar = risk_geometry.bands_source_bar;
    position_state.risk_bands_upper = risk_geometry.bands_upper;
    position_state.risk_bands_lower = risk_geometry.bands_lower;
    position_state.risk_band_width_points = risk_geometry.band_width_points;
    position_state.initial_sl_points = risk_geometry.initial_sl_points;
    position_state.trailing_step_points = risk_geometry.trailing_step_points;
    position_state.fixed_tp_points = risk_geometry.fixed_tp_points;
  }

  if(!PivotHftAppendPositionState(position_state))
    return false;
  emergency_index = PivotHftFindPositionStateIndex(
    position_state.execution_id,
    position_state.position_ticket);
  return (emergency_index >= 0);
}

bool PivotHftRegisterVirtualPosition(
  const PivotHftCampaignState &campaign,
  const PivotHftRiskGeometry &risk_geometry,
  const double request_quote,
  const double fill_price,
  const double volume,
  const string comment)
{
  if(!risk_geometry.valid ||
     request_quote <= 0.0 ||
     fill_price <= 0.0 ||
     volume <= 0.0)
    return false;

  PivotHftPositionState position_state;
  position_state.status = PIVOT_HFT_POSITION_ACTIVE;
  position_state.execution_source = PIVOT_HFT_EXECUTION_VIRTUAL;
  position_state.execution_id = PivotHftBuildVirtualExecutionId(campaign);
  position_state.direction = campaign.direction;
  position_state.pivot_level = campaign.pivot_level;
  position_state.campaign_retry_source_ticket = campaign.retry_source_ticket;
  position_state.campaign_retry_source_id = campaign.retry_source_id;
  position_state.model_source_execution_source =
    campaign.model_source_execution_source;
  position_state.model_source_execution_id =
    campaign.model_source_execution_id;
  position_state.entry_slippage_provenance =
    campaign.entry_slippage_provenance;
  position_state.close_slippage_provenance =
    campaign.close_slippage_provenance;
  position_state.cost_per_lot_provenance =
    campaign.cost_per_lot_provenance;
  position_state.force_close_generation_at_entry =
    MarketStatusForceCloseGeneration();
  position_state.campaign_micro_bar_time = campaign.micro_bar_time;
  position_state.entry_time = TimeCurrent();
  position_state.entry_micro_bar_time =
    PivotHftResolveMicroBarAt(position_state.entry_time);
  if(position_state.entry_micro_bar_time <= 0)
    position_state.entry_micro_bar_time = PivotHftCurrentMicroBar();
  if(position_state.entry_micro_bar_time <= 0)
    position_state.entry_micro_bar_time = campaign.micro_bar_time;
  position_state.pivot_price = campaign.pivot_price;
  position_state.entry_price = fill_price;
  position_state.entry_request_quote = request_quote;
  position_state.entry_slippage_points =
    PivotHftSignedEntrySlippagePoints(position_state.direction,
                                      request_quote,
                                      fill_price);
  position_state.close_slippage_points =
    campaign.modeled_close_slippage_points;
  position_state.estimated_cost_per_lot = campaign.modeled_cost_per_lot;
  position_state.entry_volume = volume;
  position_state.campaign_attempt_count = campaign.attempt_count;
  position_state.campaign_retry_ordinal = campaign.retry_ordinal;
  position_state.campaign_sequence_id = campaign.sequence_id;
  position_state.position_comment = comment;
  position_state.entry_safety = campaign.entry_safety;
  position_state.risk_bands_source_bar = risk_geometry.bands_source_bar;
  position_state.risk_bands_upper = risk_geometry.bands_upper;
  position_state.risk_bands_lower = risk_geometry.bands_lower;
  position_state.risk_band_width_points = risk_geometry.band_width_points;
  position_state.initial_sl_points = risk_geometry.initial_sl_points;
  position_state.trailing_step_points = risk_geometry.trailing_step_points;
  position_state.fixed_tp_points = risk_geometry.fixed_tp_points;
  position_state.local_sl_price = PivotHftResolveInitialLocalStopPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.initial_sl_points);
  position_state.local_tp_price = PivotHftResolveFixedLocalTargetPrice(
    position_state.direction,
    position_state.entry_price,
    position_state.fixed_tp_points);
  position_state.trailing_stop_price = position_state.local_sl_price;

  return (position_state.execution_id != "" &&
          position_state.local_sl_price > 0.0 &&
          (position_state.fixed_tp_points <= 0.0 ||
           position_state.local_tp_price > 0.0) &&
          PivotHftAppendPositionState(position_state));
}

bool PivotHftExecuteEntryIntent()
{
  if(!PivotHftEntryIntentReady() ||
     !PivotHftRecoveryAllowsSignalAttempts())
    return false;

  PivotHftCampaignState campaign = g_pivot_hft_campaign;
  int retry_number = PivotHftMarketRetryNumber(campaign.retry_ordinal);
  PivotHftExecutionSources execution_source =
    PivotHftExecutionSourceForRetry(retry_number);
  if(PivotHftHasBlockingPositionLifecycle() ||
     PivotHftHasManagedBrokerPosition())
  {
    if(!g_pivot_hft_campaign.execution_slot_block_logged)
    {
      PivotHftAuditLog("ENTRY_SINGLE_FLIGHT_BLOCKED",
                       StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|reason=position_lifecycle_occupied",
                                    campaign.sequence_id,
                                    EnumToString(campaign.direction),
                                    PivotHftLevelLabel(campaign.pivot_level),
                                    retry_number,
                                    campaign.retry_ordinal,
                                    PivotHftExecutionSourceLabel(
                                      execution_source)));
      g_pivot_hft_campaign.execution_slot_block_logged = true;
    }
    g_pivot_hft_last_error = "position_lifecycle_occupied";
    return false;
  }

  MqlTick execution_tick;
  double execution_spread_points = 0.0;
  string fresh_tick_reason = "";
  if(!PivotHftResolveFreshExecutionTick(execution_tick,
                                        execution_spread_points,
                                        fresh_tick_reason))
  {
    PivotHftAuditLog("ENTRY_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    execution_source),
                                  fresh_tick_reason,
                                  campaign.attempt_count + 1));
    g_pivot_hft_last_error = fresh_tick_reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_FRESH_TICK_BLOCK",
                                       fresh_tick_reason,
                                       0,
                                       GetLastError());
    PivotHftMarkEntryRetryable();
    return false;
  }

  double normalized_volume = 0.0;
  string guard_reason = "";
  if(!PivotHftEntryGuardsAllow(campaign.direction,
                               normalized_volume,
                               guard_reason,
                               execution_source ==
                                 PIVOT_HFT_EXECUTION_BROKER))
  {
    PivotHftAuditLog("ENTRY_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    execution_source),
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
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
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

  bool broker_constraints_ready = RefreshBrokerConstraintsForAction(
    _Symbol,
    g_symbol_constraints,
    "PIVOT_HFT_ENTRY_SAFETY");
  if(!PivotHftResolveFreshExecutionTick(execution_tick,
                                        execution_spread_points,
                                        fresh_tick_reason))
  {
    PivotHftAuditLog("ENTRY_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|reason=%s|stage=pre_execution|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    execution_source),
                                  fresh_tick_reason,
                                  campaign.attempt_count + 1));
    g_pivot_hft_last_error = fresh_tick_reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_PRE_EXECUTION_TICK_BLOCK",
                                       fresh_tick_reason,
                                       0,
                                       GetLastError());
    PivotHftMarkEntryRetryable();
    return false;
  }
  PivotHftEntrySafetySnapshot entry_safety;
  bool entry_distance_safe = PivotHftResolveEntrySafetySnapshot(
    risk_geometry.initial_sl_points,
    broker_constraints_ready,
    entry_safety);
  campaign.entry_safety = entry_safety;
  g_pivot_hft_campaign.entry_safety = entry_safety;
  if(!entry_distance_safe)
  {
    PivotHftAuditLog("ENTRY_RISK_DISTANCE_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|attempt=%d|%s",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    execution_source),
                                  campaign.attempt_count + 1,
                                  PivotHftEntrySafetyAuditFields(
                                    entry_safety)));
    g_pivot_hft_last_error = entry_safety.reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_ENTRY_DISTANCE_BLOCK",
                                       entry_safety.reason,
                                       0,
                                       GetLastError());
    PivotHftMarkEntryRetryable();
    return false;
  }

  double entry_quote = PivotHftEntryQuoteFromTick(campaign.direction,
                                                  execution_tick);
  double planned_entry_price = entry_quote;
  if(execution_source == PIVOT_HFT_EXECUTION_VIRTUAL)
  {
    bool model_values_finite =
      (MathIsValidNumber(campaign.modeled_entry_slippage_points) &&
       MathIsValidNumber(campaign.modeled_close_slippage_points) &&
       MathIsValidNumber(campaign.modeled_cost_per_lot));
    bool model_provenance_available =
      (campaign.entry_slippage_provenance !=
         PIVOT_HFT_MODEL_VALUE_UNAVAILABLE &&
       campaign.close_slippage_provenance !=
         PIVOT_HFT_MODEL_VALUE_UNAVAILABLE &&
       campaign.cost_per_lot_provenance !=
         PIVOT_HFT_MODEL_VALUE_UNAVAILABLE);
    if(!model_values_finite ||
       campaign.model_source_execution_id == "" ||
       !model_provenance_available)
    {
      if(!model_values_finite)
        risk_reason = "non_finite_virtual_execution_model";
      else if(campaign.model_source_execution_id == "")
        risk_reason = "virtual_model_source_unavailable";
      else
        risk_reason = "virtual_model_provenance_unavailable";
      PivotHftAuditLog("VIRTUAL_ENTRY_BLOCKED",
                       StringFormat("sequence=%s|retry_number=%d|retry_ordinal=%d|reason=%s|%s",
                                    campaign.sequence_id,
                                    retry_number,
                                    campaign.retry_ordinal,
                                    risk_reason,
                                    PivotHftCampaignModelProvenanceAuditFields(
                                      campaign)));
      g_pivot_hft_last_error = risk_reason;
      PivotHftMarkEntryRetryable();
      return false;
    }
    planned_entry_price = PivotHftApplyEntrySlippage(
      campaign.direction,
      entry_quote,
      campaign.modeled_entry_slippage_points);
  }
  double preview_local_sl = PivotHftResolveInitialLocalStopPrice(
    campaign.direction,
    planned_entry_price,
    risk_geometry.initial_sl_points);
  double preview_local_tp = PivotHftResolveFixedLocalTargetPrice(
    campaign.direction,
    planned_entry_price,
    risk_geometry.fixed_tp_points);
  if(preview_local_sl <= 0.0 ||
     (risk_geometry.fixed_tp_points > 0.0 && preview_local_tp <= 0.0))
  {
    risk_reason = (preview_local_sl <= 0.0)
                  ? "resolved_local_sl_price_invalid"
                  : "resolved_fixed_tp_price_invalid";
    PivotHftAuditLog("ENTRY_RISK_PRICE_BLOCKED",
                     StringFormat("sequence=%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=%s|entry_quote=%.5f|planned_entry=%.5f|initial_sl_pts=%.2f|fixed_tp_pts=%.2f|reason=%s|attempt=%d",
                                  campaign.sequence_id,
                                  EnumToString(campaign.direction),
                                  PivotHftLevelLabel(campaign.pivot_level),
                                  retry_number,
                                  campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    execution_source),
                                  entry_quote,
                                  planned_entry_price,
                                  risk_geometry.initial_sl_points,
                                  risk_geometry.fixed_tp_points,
                                  risk_reason,
                                  campaign.attempt_count + 1));
    g_pivot_hft_last_error = risk_reason;
    MarketStatusRegisterExecutionError("PIVOT_HFT_RISK_PRICE_BLOCK",
                                       risk_reason,
                                       0,
                                       0);
    PivotHftMarkEntryRetryable();
    return false;
  }

  string comment = PivotHftBuildPositionComment(campaign);
  if(execution_source == PIVOT_HFT_EXECUTION_VIRTUAL)
  {
    if(!PivotHftRegisterVirtualPosition(campaign,
                                        risk_geometry,
                                        entry_quote,
                                        planned_entry_price,
                                        normalized_volume,
                                        comment))
    {
      PivotHftAuditLog("VIRTUAL_FILL_UNRESOLVED",
                       StringFormat("sequence=%s|retry_number=%d|retry_ordinal=%d|request_quote=%.5f|planned_entry=%.5f|volume=%.2f|reason=virtual_position_registration_failed",
                                    campaign.sequence_id,
                                    retry_number,
                                    campaign.retry_ordinal,
                                    entry_quote,
                                    planned_entry_price,
                                    normalized_volume));
      g_pivot_hft_last_error = "virtual_position_registration_failed";
      MarketStatusRegisterExecutionError("PIVOT_HFT_VIRTUAL_FILL_UNRESOLVED",
                                         g_pivot_hft_last_error,
                                         0,
                                         0);
      PivotHftMarkEntryRetryable();
      return false;
    }

    int virtual_index = ArraySize(g_pivot_hft_positions) - 1;
    if(virtual_index >= 0)
    {
      PivotHftPositionState virtual_state =
        g_pivot_hft_positions[virtual_index];
      PivotHftAuditLog("VIRTUAL_FILL_REGISTERED",
                       StringFormat("sequence=%s|%s|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|source_ticket=%I64u|source_id=%s|bid=%.5f|ask=%.5f|execution_spread_pts=%.2f|entry=%.5f|volume=%.2f|origin_bar=%I64d|fill_bar=%I64d|%s|%s|%s",
                                    campaign.sequence_id,
                                    PivotHftPositionAuditIdentityFields(
                                      virtual_state),
                                    EnumToString(virtual_state.direction),
                                    PivotHftLevelLabel(
                                      virtual_state.pivot_level),
                                    retry_number,
                                    virtual_state.campaign_retry_ordinal,
                                    virtual_state.campaign_retry_source_ticket,
                                    virtual_state.campaign_retry_source_id,
                                    execution_tick.bid,
                                    execution_tick.ask,
                                    execution_spread_points,
                                    virtual_state.entry_price,
                                    virtual_state.entry_volume,
                                    (long)virtual_state.campaign_micro_bar_time,
                                    (long)virtual_state.entry_micro_bar_time,
                                    PivotHftPositionRiskAuditFields(
                                      virtual_state),
                                    PivotHftEntrySafetyAuditFields(
                                      virtual_state.entry_safety),
                                    PivotHftExecutionModelAuditFields(
                                      virtual_state)));
    }

    g_pivot_hft_last_error = "";
    MarketStatusClearExecutionError("PIVOT_HFT_VIRTUAL_ENTRY_OK");
    PivotHftResetCampaign();
    return true;
  }

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
                   StringFormat("sequence=%s|sent=%d|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|execution_source=BROKER|request_quote=%.5f|volume=%.2f|ret=%I64u|err=%d|deal=%I64u|price=%.5f|result_volume=%.2f|server_sl=0|server_tp=0|comment=%s",
                                campaign.sequence_id,
                                (int)sent,
                                EnumToString(campaign.direction),
                                PivotHftLevelLabel(campaign.pivot_level),
                                retry_number,
                                campaign.retry_ordinal,
                                entry_quote,
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
                       StringFormat("reason=no_money|sequence=%s|retry_number=%d|retry_ordinal=%d|ret=%I64u|err=%d",
                                    campaign.sequence_id,
                                    retry_number,
                                    campaign.retry_ordinal,
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

  bool daily_start_registered = false;
  bool daily_start_transition = RegisterPivotHftDailySignalStart(
    campaign.direction,
    daily_start_registered);
  PivotHftAuditLog("BROKER_FILL_ACCOUNTED",
                   StringFormat("sequence=%s|deal=%I64u|dir=%s|level=%s|retry_number=%d|retry_ordinal=%d|daily_start_registered=%d|daily_start_transition=%d|daily_limit=%d|daily_mode=%s",
                                campaign.sequence_id,
                                deal_ticket,
                                EnumToString(campaign.direction),
                                PivotHftLevelLabel(campaign.pivot_level),
                                retry_number,
                                campaign.retry_ordinal,
                                (int)daily_start_registered,
                                (int)daily_start_transition,
                                Daily_Signal_Limit,
                                EnumToString(Daily_Signal_Limit_Mode)));

  int registered_index = -1;
  ulong resolved_position_ticket = 0;
  ulong resolved_position_identifier = 0;
  if(!PivotHftRegisterFilledPosition(campaign,
                                     risk_geometry,
                                     deal_ticket,
                                     result_price,
                                     result_volume,
                                     comment,
                                     entry_quote,
                                     daily_start_registered,
                                     registered_index,
                                     resolved_position_ticket,
                                     resolved_position_identifier))
  {
    if(resolved_position_ticket == 0)
    {
      resolved_position_ticket = PivotHftFindFilledPosition(
        deal_ticket,
        campaign.direction,
        resolved_position_identifier);
    }

    datetime emergency_entry_time = TimeCurrent();
    double emergency_entry_price = result_price;
    double emergency_entry_volume = result_volume;
    string emergency_comment = comment;
    if(resolved_position_ticket > 0 &&
       PositionSelectByTicket(resolved_position_ticket) &&
       PositionGetString(POSITION_SYMBOL) == _Symbol &&
       PositionGetInteger(POSITION_MAGIC) == g_magic_number)
    {
      ulong selected_identifier =
        (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(resolved_position_identifier == 0 ||
         selected_identifier == resolved_position_identifier)
      {
        resolved_position_identifier = selected_identifier;
        emergency_entry_time =
          (datetime)PositionGetInteger(POSITION_TIME);
        emergency_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
        emergency_entry_volume = PositionGetDouble(POSITION_VOLUME);
        emergency_comment = PositionGetString(POSITION_COMMENT);
      }
    }
    if(emergency_entry_time <= 0)
      emergency_entry_time = TimeCurrent();
    if(emergency_entry_price <= 0.0)
      emergency_entry_price = result_price;
    if(emergency_entry_volume <= 0.0)
      emergency_entry_volume = result_volume;

    PivotHftActivateEmergencyQuarantine(
      campaign,
      resolved_position_ticket,
      resolved_position_identifier,
      deal_ticket,
      emergency_entry_time,
      emergency_entry_price,
      emergency_entry_volume,
      emergency_comment,
      daily_start_registered,
      PIVOT_HFT_CLOSE_TRIGGER_REGISTRATION_FAILURE,
      "filled_position_registration_failed");
    PivotHftAuditLog("FILL_REGISTRATION_FAILED",
                     StringFormat("sequence=%s|retry_number=%d|retry_ordinal=%d|deal=%I64u|ticket=%I64u|position_id=%I64u|ret=%I64u|err=%d|daily_start_registered=%d",
                                  campaign.sequence_id,
                                  retry_number,
                                  campaign.retry_ordinal,
                                  deal_ticket,
                                  resolved_position_ticket,
                                  resolved_position_identifier,
                                  retcode,
                                  last_error,
                                  (int)daily_start_registered));
    g_pivot_hft_last_error = "filled_position_not_resolved";
    MarketStatusRegisterExecutionError("PIVOT_HFT_FILL_UNRESOLVED",
                                       g_pivot_hft_last_error,
                                       retcode,
                                       last_error);

    int emergency_index = -1;
    bool emergency_attached = PivotHftAppendEmergencyFilledPosition(
      campaign,
      risk_geometry,
      deal_ticket,
      resolved_position_ticket,
      resolved_position_identifier,
      result_price,
      result_volume,
      comment,
      entry_quote,
      daily_start_registered,
      PIVOT_HFT_CLOSE_TRIGGER_REGISTRATION_FAILURE,
      "registration_failure",
      emergency_index);
    if(emergency_attached)
    {
      PivotHftMarkEmergencyQuarantineStateAttached();
      PivotHftRecoveryCheckpointOrQuarantine(
        g_pivot_hft_positions[emergency_index],
        "registration_failure_attached");
      PivotHftAuditLog("EMERGENCY_LIFECYCLE_REGISTERED",
                       StringFormat("sequence=%s|%s|position_id=%I64u|deal=%I64u|reason=normal_registration_failed",
                                    campaign.sequence_id,
                                    PivotHftPositionAuditIdentityFields(
                                      g_pivot_hft_positions[emergency_index]),
                                    g_pivot_hft_positions[emergency_index].position_identifier,
                                    deal_ticket));
      if(!PivotHftClosePositionLocally(
           g_pivot_hft_positions[emergency_index]))
      {
        if(!MarketStatusHasPendingForceClose())
        {
          MarketStatusRequestScopedForceClose(
            "Pivot HFT registration failure",
            resolved_position_ticket,
            resolved_position_identifier);
        }
      }
    }
    else
    {
      PivotHftAuditLog("EMERGENCY_QUARANTINE_ACTIVE",
                       StringFormat("sequence=%s|deal=%I64u|ticket=%I64u|position_id=%I64u|state_attached=0|reason=emergency_state_registration_failed",
                                    campaign.sequence_id,
                                    deal_ticket,
                                    resolved_position_ticket,
                                    resolved_position_identifier));
      MarketStatusRequestScopedForceClose(
        "Pivot HFT unresolved fill quarantine",
        resolved_position_ticket,
        resolved_position_identifier);
      ProtectionRiskProcessPendingForceClose();
    }
    PivotHftResetCampaign();
    return false;
  }

  if(registered_index < 0 ||
     !PivotHftRecoveryCheckpointOrQuarantine(
       g_pivot_hft_positions[registered_index],
       "broker_fill_registered"))
  {
    PivotHftAuditLog("FILL_RECOVERY_CHECKPOINT_FAILED",
                     StringFormat("sequence=%s|deal=%I64u|ticket=%I64u|position_id=%I64u|reason=durable_checkpoint_unavailable",
                                  campaign.sequence_id,
                                  deal_ticket,
                                  resolved_position_ticket,
                                  resolved_position_identifier));
    g_pivot_hft_last_error = "recovery_checkpoint_failed";
    MarketStatusRegisterExecutionError(
      "PIVOT_HFT_RECOVERY_CHECKPOINT_FAILED",
      g_pivot_hft_last_error,
      retcode,
      last_error);
    if(registered_index >= 0)
      PivotHftClosePositionLocally(
        g_pivot_hft_positions[registered_index]);
    PivotHftResetCampaign();
    return false;
  }

  if(registered_index >= 0)
  {
    PivotHftPositionState registered_state =
      g_pivot_hft_positions[registered_index];
    PivotHftAuditLog("FILL_REGISTERED",
                     StringFormat("sequence=%s|%s|position_id=%I64u|deal=%I64u|dir=%s|level=%s|entry=%.5f|volume=%.2f|attempt=%d|retry_number=%d|retry_ordinal=%d|source_ticket=%I64u|source_id=%s|origin_bar=%I64d|fill_bar=%I64d|%s|%s|%s",
                                  campaign.sequence_id,
                                  PivotHftPositionAuditIdentityFields(
                                    registered_state),
                                  registered_state.position_identifier,
                                  registered_state.entry_deal_ticket,
                                  EnumToString(registered_state.direction),
                                  PivotHftLevelLabel(registered_state.pivot_level),
                                  registered_state.entry_price,
                                  registered_state.entry_volume,
                                  registered_state.campaign_attempt_count + 1,
                                  PivotHftMarketRetryNumber(
                                    registered_state.campaign_retry_ordinal),
                                  registered_state.campaign_retry_ordinal,
                                  registered_state.campaign_retry_source_ticket,
                                  registered_state.campaign_retry_source_id,
                                  (long)registered_state.campaign_micro_bar_time,
                                  (long)registered_state.entry_micro_bar_time,
                                  PivotHftPositionRiskAuditFields(
                                    registered_state),
                                  PivotHftEntrySafetyAuditFields(
                                    registered_state.entry_safety),
                                  PivotHftExecutionModelAuditFields(
                                    registered_state)));
  }

  g_pivot_hft_last_error = "";
  MarketStatusClearExecutionError("PIVOT_HFT_ORDER_SEND_OK");
  PivotHftResetCampaign();

  if(Enable_Logs)
  {
    PrintFormat("PIVOT_HFT_FILL ticket=%I64u deal=%I64u dir=%s price=%.5f volume=%.2f",
                g_pivot_hft_positions[registered_index].position_ticket,
                deal_ticket,
                EnumToString(campaign.direction),
                result_price,
                result_volume);
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_EXECUTION_MQH_
