//+------------------------------------------------------------------+
//|                  grid_hedged_trailing.mqh                        |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_HEDGED_TRAILING_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_HEDGED_TRAILING_MQH_

double HedgedComputeProfitAtPrice(const SignalParams &signal_params,
                                  const double exit_price)
{
  double total = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  if(contract_size <= 0.0)
    contract_size = 100000.0;

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.position_ticket <= 0)
      continue;
    if(!PositionSelectByTicket(state.position_ticket))
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;

    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    long pos_type = PositionGetInteger(POSITION_TYPE);
    double diff = (pos_type == POSITION_TYPE_BUY)
                    ? (exit_price - open_price)
                    : (open_price - exit_price);
    total += diff * volume * contract_size;
  }
  return total;
}

bool HedgedUpdateTrailingOnTrendBar(SignalParams &signal_params,
                                    GridOrderState &grid_order)
{
  if(!signal_params.hedged_swing.hedged_mode)
    return false;

  ENUM_TIMEFRAMES tf = ResolveHedgedPrimaryTimeframe();
  datetime bar_time = iTime(_Symbol, tf, 0);
  if(bar_time <= 0)
    return false;
  if(signal_params.hedged_swing.trailing_bar_time == bar_time)
    return false;

  signal_params.hedged_swing.trailing_bar_time = bar_time;

  double point_size = GridResolvePointSize();
  double anchor_profit = 0.0;
  double swing_trail = HedgedResolveSwingTrailingAnchor(signal_params,
                                                        grid_order,
                                                        point_size,
                                                        true,
                                                        anchor_profit,
                                                        false);
  if(swing_trail > 0.0)
    signal_params.hedged_swing.trailing_price = swing_trail;

  if((signal_params.signal_type == BULLISH && Bullish_Swing_SL_Enable) ||
     (signal_params.signal_type == BEARISH && Bearish_Swing_SL_Enable))
  {
    double sl_profit = 0.0;
    double sl_anchor = HedgedResolveSwingTrailingAnchor(signal_params,
                                                        grid_order,
                                                        point_size,
                                                        false,
                                                        sl_profit,
                                                        true);
    if(sl_anchor > 0.0)
    {
      if(signal_params.signal_type == BULLISH)
      {
        if(sl_anchor > signal_params.hedged_swing.stop_loss_price)
          signal_params.hedged_swing.stop_loss_price = sl_anchor;
      }
      else
      {
        if(sl_anchor < signal_params.hedged_swing.stop_loss_price)
          signal_params.hedged_swing.stop_loss_price = sl_anchor;
      }
    }
  }

  return true;
}

bool HedgedCheckTrailingExit(SignalParams &signal_params,
                             GridOrderState &grid_order,
                             const double point_size)
{
  double trail = signal_params.hedged_swing.trailing_price;
  if(trail <= 0.0)
    return false;

  double current_price = GridCurrentPriceForDirection(signal_params.signal_type, false);
  bool exit = false;
  if(signal_params.signal_type == BULLISH)
    exit = (current_price <= trail);
  else
    exit = (current_price >= trail);

  if(exit)
  {
    GridCloseAllLevels(signal_params, point_size);
    HedgedBuildAndOpenAtAnchor(signal_params.signal_type, current_price, TimeCurrent(), signal_params);
    return true;
  }
  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_HEDGED_TRAILING_MQH_
