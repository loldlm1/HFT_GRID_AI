//+------------------------------------------------------------------+
//|                            market_signal_channel_guards.mqh       |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CHANNEL_GUARDS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CHANNEL_GUARDS_MQH_

bool ResolveChannelBoundsForTimeframe(const ENUM_TIMEFRAMES tf,
                                      double &upper,
                                      double &lower)
{
  upper = 0.0;
  lower = 0.0;

  GridBaseStrategyTypes channel_type = ResolveActiveChannelStrategy();
  if(!GridResolveChannelLinePrice(channel_type, GRID_CHANNEL_LINE_RESISTANCE, tf, upper))
    return false;
  if(!GridResolveChannelLinePrice(channel_type, GRID_CHANNEL_LINE_SUPPORT, tf, lower))
    return false;

  if(upper < lower)
  {
    double tmp = upper;
    upper = lower;
    lower = tmp;
  }
  return (upper > 0.0 && lower > 0.0);
}

bool FindAlligatorDataForTimeframe(const SignalParams &signal_params,
                                   const ENUM_TIMEFRAMES tf,
                                   AlligatorStructure &alligator_out)
{
  int total = ArraySize(signal_params.alligator_data);
  for(int i = 0; i < total; i++)
  {
    AlligatorStructure data = signal_params.alligator_data[i];
    if(data.indicator_timeframe == tf)
    {
      alligator_out = data;
      return true;
    }
  }
  return false;
}

double ResolveContextAlligatorMaValue(const AlligatorStructure &alligator_data,
                                      const StrategyTrendModes mode)
{
  if(TrendModeUsesTeethAlligator(mode))
    return alligator_data.teeth_value;
  if(TrendModeUsesJawsAlligator(mode))
    return alligator_data.jaws_value;
  return 0.0;
}

bool StrategyContextChannelMaFilterAllowsSignal(const StrategyContextTypes context,
                                                const StrategyContextIndicators &snapshot)
{
  if(!StrategyContextChannelFilterEnabled(context))
    return true;

  StrategyTrendModes trend_mode = StrategyContextTrendMode(context);
  if(!TrendModeUsesAlligator(trend_mode))
    return true;

  if(!snapshot.alligator_valid)
    return true;

  double ma_value = ResolveContextAlligatorMaValue(snapshot.alligator_data, trend_mode);
  if(ma_value <= 0.0)
    return true;

  double upper = 0.0;
  double lower = 0.0;
  if(!ResolveChannelBoundsForTimeframe(snapshot.timeframe, upper, lower))
    return true;

  return !(ma_value <= upper && ma_value >= lower);
}

bool ChannelGuardAllowsPendingSignal(SignalParams &signal_params,
                                     const string context_label)
{
  if(!GridStrategyUsesChannelIndicator())
    return true;

  if(Grid_Points_Range_Setup <= 0.0)
    return true;

  if(GridSignalHasExecutedLevel(signal_params))
    return true;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return true;

  GridOrderState pending_state = signal_params.grid_orders[total_levels - 1];
  double distance_points = 0.0;
  double required_points = 0.0;
  double reference_price = 0.0;

  bool guard_ok = GridSignalChannelGuardSatisfied(signal_params,
                                                  pending_state.entry_reference_price,
                                                  distance_points,
                                                  required_points,
                                                  reference_price);
  if(!guard_ok)
  {
    if(Enable_Logs)
    {
      PrintFormat("%s channel guard blocked signal | dist=%.2f pts | floor=%.2f pts | entry=%.5f | ref=%.5f",
                  context_label,
                  distance_points,
                  required_points,
                  pending_state.entry_reference_price,
                  reference_price);
    }
    return false;
  }

  if(signal_params.grid_initial_indicator_distance_points <= 0.0 &&
     distance_points > 0.0)
  {
    signal_params.grid_initial_indicator_distance_points = distance_points;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_CHANNEL_GUARDS_MQH_
