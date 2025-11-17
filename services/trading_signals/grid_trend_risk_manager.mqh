#ifndef _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_

bool GridApplyTrendRiskManagement(SignalParams &signal_params)
{
  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_OFF)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolveRiskTrendTimeframe();
  double lips_price = 0.0;
  if(!GridResolveAlligatorLipsPriceForTimeframe(target_tf, lips_price))
    return false;
  if(lips_price <= 0.0)
    return false;

  GridOrderState latest_state;
  if(!GridFindLatestOrderForLogging(signal_params, latest_state))
    return false;

  double entry_price = latest_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = latest_state.entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  bool breach = false;
  if(signal_params.signal_type == BULLISH)
    breach = (entry_price < lips_price);
  else if(signal_params.signal_type == BEARISH)
    breach = (entry_price > lips_price);

  if(!breach)
    return false;

  if(Grid_Risk_Trend_Mode == GRID_RM_TREND_LIPS_BE)
  {
    double floating_profit = GridCollectSignalFloatingProfit(signal_params);
    double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tolerance <= 0.0)
      tolerance = 0.1;
    if(floating_profit < -tolerance)
      return false;
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);

  string log_label = (Grid_Risk_Trend_Mode == GRID_RM_TREND_LIPS_BE) ?
                     "GRID_RISK_TREND_LIPS_BE" :
                     "GRID_RISK_TREND_LIPS_SL";
  GridLogEvent(log_label, signal_params, latest_state);
  signal_params.signal_state = CLOSED;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
