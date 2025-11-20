#ifndef _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_

bool GridSpawnRiskSarSignal(const SignalTypes direction,
                            double lot_size,
                            const double cumulative_loss)
{
  double normalized_lot = NormalizeVolumeForSymbol(_Symbol, lot_size);
  if(normalized_lot <= 0.0)
  {
    normalized_lot = NormalizeVolumeForSymbol(_Symbol, Grid_Lot_Strategy_Size);
    if(normalized_lot <= 0.0)
      return false;
  }

  SignalParams sar_signal;
  sar_signal.signal_type = direction;
  sar_signal.lot_size    = normalized_lot;
  sar_signal.is_sar_signal = true;
  sar_signal.entry_time  = TimeCurrent();
  sar_signal.entry_price = GridCurrentPriceForDirection(direction, true);
  sar_signal.sar_cumulative_loss = MathMax(cumulative_loss, 0.0);

  bool activation_ready = GridSarEntryConditionReady(sar_signal);
  if(activation_ready)
  {
    if(!BuildGridOrderForSignal(sar_signal))
    {
      Print("Trend risk SAR: failed to build reversal grid.");
      return false;
    }
  }
  else
  {
    if(Enable_Logs)
      Print("Trend risk SAR pending activation; waiting for MA cross before building grid.");
  }

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, sar_signal);
  else
    AddElementToArray(running_bearish_signals, sar_signal);

  if(activation_ready && ArraySize(sar_signal.grid_orders) > 0)
  {
    string reference_label = (Grid_Risk_Alligator_Reference == GRID_RISK_REF_TEETH) ? "TEETH" : "JAWS";
    GridLogEvent(StringFormat("GRID_RISK_TREND_%s_SAR_OPEN", reference_label),
                 sar_signal,
                 sar_signal.grid_orders[0]);
  }
  return true;
}

double GridResolveSarLotReferencePoints(const SignalTypes new_direction,
                                        const SignalParams &original_signal,
                                        const GridOrderState &original_state)
{
  SignalParams preview_signal;
  preview_signal.signal_type = new_direction;

  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  if(CalculateBaseGridContext(preview_signal,
                              Strategy_Timeframe,
                              base_distance_points,
                              entry_reference_price))
  {
    if(base_distance_points > 0.0)
      return base_distance_points;
  }

  double reference_points = GridResolveLotReferencePoints(original_signal, original_state);
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_base_distance_points;
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_entry_gap_points;

  if(reference_points <= 0.0)
  {
    double point_size = GridResolvePointSizeSafe();
    double entry_reference = original_state.entry_reference_price;
    double tp_price = original_state.take_profit_price;
    if(point_size > 0.0 && entry_reference > 0.0 && tp_price > 0.0)
      reference_points = MathAbs(tp_price - entry_reference) / point_size;
  }

  return MathMax(reference_points, 0.0);
}

bool GridApplyTrendRiskManagement(SignalParams &signal_params,
                                  const GridOrderState &override_state,
                                  const bool has_override,
                                  const bool use_entry_reference_price)
{
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_OFF)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolveRiskTrendTimeframe();
  double reference_price = 0.0;
  if(!GridResolveAlligatorRiskReferencePrice(target_tf, reference_price))
    return false;
  if(reference_price <= 0.0)
    return false;

  GridOrderState state_candidate = override_state;
  if(!has_override)
  {
    if(!GridFindLatestFilledOrder(signal_params, state_candidate))
      return false;
  }

  double current_price        = GridCurrentPriceForDirection(signal_params.signal_type, true);
  double next_level_price     = state_candidate.next_level_price;
  bool   has_next_level_price = (next_level_price > 0.0);
  bool   next_level_breach    = false;
  if(has_next_level_price)
  {
    if(signal_params.signal_type == BULLISH)
      next_level_breach = (next_level_price < reference_price && current_price < next_level_price);
    else if(signal_params.signal_type == BEARISH)
      next_level_breach = (next_level_price > reference_price && current_price > next_level_price);
  }

  bool breach = next_level_breach;

  if(!breach)
    return false;

  bool needs_floating = (Grid_Risk_Trend_Mode == GRID_RM_TREND_BE ||
                         Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR);
  double floating_profit = 0.0;
  if(needs_floating)
    floating_profit = GridCollectSignalFloatingProfit(signal_params);

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_BE)
  {
    double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tolerance <= 0.0)
      tolerance = 0.1;
    if(floating_profit < -tolerance)
      return false;
  }

  double sar_lot = state_candidate.lot_size;
  if(sar_lot <= 0.0)
    sar_lot = signal_params.grid_base_lot_size;
  if(sar_lot <= 0.0)
    sar_lot = Grid_Lot_Strategy_Size;

  SignalTypes sar_direction = (signal_params.signal_type == BULLISH) ? BEARISH : BULLISH;
  double realized_loss = 0.0;
  double cumulative_loss = signal_params.sar_cumulative_loss;
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR && floating_profit < 0.0)
  {
    realized_loss = -floating_profit;
    cumulative_loss += realized_loss;
  }
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR && floating_profit < 0.0)
  {
    double multiplier = Grid_Lot_Multiplier;
    if(multiplier <= 0.0)
      multiplier = 1.0;

    double coverage_amount = cumulative_loss * multiplier;
    if(coverage_amount > 0.0)
    {
      double reference_points = GridResolveSarLotReferencePoints(sar_direction, signal_params, state_candidate);
      if(reference_points > 0.0)
      {
        double converted = ConvertAmountToLots(_Symbol, coverage_amount, reference_points);
        if(converted > 0.0)
          sar_lot = converted;
      }
    }
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR)
    signal_params.sar_cumulative_loss = cumulative_loss;

  string reference_label = (Grid_Risk_Alligator_Reference == GRID_RISK_REF_TEETH) ? "TEETH" : "JAWS";
  string log_label = StringFormat("GRID_RISK_TREND_%s_SL", reference_label);
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_BE)
    log_label = StringFormat("GRID_RISK_TREND_%s_BE", reference_label);
  else if(Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR)
    log_label = StringFormat("GRID_RISK_TREND_%s_SAR_CLOSE", reference_label);
  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(log_label, signal_params, log_state);
  signal_params.signal_state = CLOSED;

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_SAR)
  {
    if(!GridSpawnRiskSarSignal(sar_direction, sar_lot, cumulative_loss))
      Print("Trend risk SAR: failed to launch reversal grid.");
  }
  return true;
}


#endif // _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
