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

  if(!GridStrategyUsesChannelIndicator())
    return false;

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
  if(StrategyModeUsesTeethAlligator(mode))
    return alligator_data.teeth_value;
  if(StrategyModeUsesJawsAlligator(mode))
    return alligator_data.jaws_value;
  return 0.0;
}

bool BaseChannelMaFilterAllowsSignal(const SignalParams &signal_params)
{
  if(!Base_Channel_MA_Filter)
    return true;
  if(!GridStrategyUsesChannelIndicator())
    return true;
  if(!StrategyModeUsesAlligator(Strategy_Base_Mode))
    return true;

  ENUM_TIMEFRAMES strategy_tf = Strategy_Timeframe;
  AlligatorStructure base_alligator;
  if(!FindAlligatorDataForTimeframe(signal_params, strategy_tf, base_alligator))
    return true;

  double ma_value = ResolveContextAlligatorMaValue(base_alligator, Strategy_Base_Mode);
  if(ma_value <= 0.0)
    return true;

  double upper = 0.0;
  double lower = 0.0;
  if(!ResolveChannelBoundsForTimeframe(strategy_tf, upper, lower))
    return true;

  return !(ma_value <= upper && ma_value >= lower);
}

bool TrendChannelMaFilterAllowsSignal(const SignalParams &signal_params)
{
  if(!Trend_Channel_MA_Filter)
    return true;
  if(!GridStrategyUsesChannelIndicator())
    return true;
  if(!TrendContextEnabled() || Strategy_Trend_Mode == TREND_OFF)
    return true;
  if(!StrategyModeUsesAlligator(Strategy_Trend_Mode))
    return true;
  if(!signal_params.trend_alligator_valid)
    return true;

  ENUM_TIMEFRAMES trend_tf = Trend_Strategy_Timeframe;
  if(trend_tf == PERIOD_CURRENT)
    trend_tf = Strategy_Timeframe;

  double ma_value = ResolveContextAlligatorMaValue(signal_params.trend_alligator_data,
                                                   Strategy_Trend_Mode);
  if(ma_value <= 0.0)
    return true;

  double upper = 0.0;
  double lower = 0.0;
  if(!ResolveChannelBoundsForTimeframe(trend_tf, upper, lower))
    return true;

  return !(ma_value <= upper && ma_value >= lower);
}

bool MacroChannelMaFilterAllowsSignal(const SignalParams &signal_params)
{
  if(!Macro_Channel_MA_Filter)
    return true;
  if(!GridStrategyUsesChannelIndicator())
    return true;
  if(!MacroContextEnabled() || Strategy_Macro_Mode == TREND_OFF)
    return true;
  if(!StrategyModeUsesAlligator(Strategy_Macro_Mode))
    return true;
  if(!signal_params.macro_alligator_valid)
    return true;

  ENUM_TIMEFRAMES macro_tf = Macro_Strategy_Timeframe;
  if(macro_tf == PERIOD_CURRENT)
    macro_tf = Strategy_Timeframe;

  double ma_value = ResolveContextAlligatorMaValue(signal_params.macro_alligator_data,
                                                   Strategy_Macro_Mode);
  if(ma_value <= 0.0)
    return true;

  double upper = 0.0;
  double lower = 0.0;
  if(!ResolveChannelBoundsForTimeframe(macro_tf, upper, lower))
    return true;

  return !(ma_value <= upper && ma_value >= lower);
}

bool SessionChannelMaFilterAllowsSignal(const SignalParams &signal_params)
{
  if(!Session_Channel_MA_Filter)
    return true;
  if(!GridStrategyUsesChannelIndicator())
    return true;
  if(!SessionContextEnabled() || Strategy_Session_Mode == TREND_OFF)
    return true;
  if(!StrategyModeUsesAlligator(Strategy_Session_Mode))
    return true;
  if(!signal_params.session_alligator_valid)
    return true;

  ENUM_TIMEFRAMES session_tf = Session_Strategy_Timeframe;
  if(session_tf == PERIOD_CURRENT)
    session_tf = Strategy_Timeframe;

  double ma_value = ResolveContextAlligatorMaValue(signal_params.session_alligator_data,
                                                   Strategy_Session_Mode);
  if(ma_value <= 0.0)
    return true;

  double upper = 0.0;
  double lower = 0.0;
  if(!ResolveChannelBoundsForTimeframe(session_tf, upper, lower))
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
