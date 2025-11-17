#ifndef _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_

bool GridSpawnRiskSarSignal(const SignalTypes direction,
                            double lot_size)
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
  sar_signal.entry_time  = TimeCurrent();
  sar_signal.entry_price = GridCurrentPriceForDirection(direction, true);

  if(!BuildGridOrderForSignal(sar_signal))
  {
    Print("Trend risk SAR: failed to build reversal grid.");
    return false;
  }

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, sar_signal);
  else
    AddElementToArray(running_bearish_signals, sar_signal);

  if(ArraySize(sar_signal.grid_orders) > 0)
    GridLogEvent("GRID_RISK_TREND_JAWS_SAR_OPEN", sar_signal, sar_signal.grid_orders[0]);
  return true;
}

bool GridApplyTrendRiskManagement(SignalParams &signal_params)
{
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_OFF)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolveRiskTrendTimeframe();
  double jaws_price = 0.0;
  if(!GridResolveAlligatorJawsPriceForRisk(target_tf, jaws_price))
    return false;
  if(jaws_price <= 0.0)
    return false;

  GridOrderState latest_state;
  if(!GridFindLatestOrderForLogging(signal_params, latest_state))
    return false;

  double entry_price = latest_state.entry_price;
  if(entry_price <= 0.0)
    return false;

  bool breach = false;
  if(signal_params.signal_type == BULLISH)
    breach = (entry_price < jaws_price);
  else if(signal_params.signal_type == BEARISH)
    breach = (entry_price > jaws_price);

  if(!breach)
    return false;

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_JAWS_BE)
  {
    double floating_profit = GridCollectSignalFloatingProfit(signal_params);
    double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tolerance <= 0.0)
      tolerance = 0.1;
    if(floating_profit < -tolerance)
      return false;
  }

  double sar_lot = latest_state.lot_size;
  if(sar_lot <= 0.0)
    sar_lot = signal_params.grid_base_lot_size;

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);

  string log_label = "GRID_RISK_TREND_JAWS_SL";
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_JAWS_BE)
    log_label = "GRID_RISK_TREND_JAWS_BE";
  else if(Grid_Risk_Trend_Mode == GRID_RM_TREND_JAWS_SAR)
    log_label = "GRID_RISK_TREND_JAWS_SAR_CLOSE";
  GridLogEvent(log_label, signal_params, latest_state);
  signal_params.signal_state = CLOSED;

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_JAWS_SAR)
  {
    SignalTypes new_direction = (signal_params.signal_type == BULLISH) ? BEARISH : BULLISH;
    if(!GridSpawnRiskSarSignal(new_direction, sar_lot))
      Print("Trend risk SAR: failed to launch reversal grid.");
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
