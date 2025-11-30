//+------------------------------------------------------------------+
//|        trading_management_strategies/grid_trend_risk_breach.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_BREACH_MQH_
#define _GRID_TREND_RISK_BREACH_MQH_

bool GridTrendSarAlligatorBreach(const SignalTypes direction,
                                 const ENUM_TIMEFRAMES target_tf,
                                 const GridRiskTrendStrategyConfig &risk_config)
{
  int fast_index = -1;
  int slow_index = -1;

  GridRiskTrendTimeframeSources risk_source = GridResolveRiskTrendSource(risk_config);
  StrategyTrendModes risk_mode = GridResolveActiveRiskMode(risk_source);

  if(TrendModeUsesTeethAlligator(risk_mode))
  {
    fast_index = 2; // lips
    slow_index = 1; // teeth
  }
  else if(TrendModeUsesJawsAlligator(risk_mode))
  {
    fast_index = 1; // teeth
    slow_index = 0; // jaws
  }
  else
  {
    return false;
  }

  double fast_value = 0.0;
  double slow_value = 0.0;
  if(!GridResolveAlligatorBufferPrice(target_tf, fast_index, fast_value))
    return false;
  if(!GridResolveAlligatorBufferPrice(target_tf, slow_index, slow_value))
    return false;

  if(direction == BULLISH)
    return fast_value < slow_value;
  if(direction == BEARISH)
    return fast_value > slow_value;
  return false;
}

bool GridRiskTrendNextLevelBreached(const SignalTypes direction,
                                    const GridOrderState &state_candidate,
                                    const double reference_price,
                                    const double current_price)
{
  double next_level_price = state_candidate.next_level_price;
  if(next_level_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return (next_level_price < reference_price && current_price < next_level_price);

  if(direction == BEARISH)
    return (next_level_price > reference_price && current_price > next_level_price);

  return false;
}

#endif // _GRID_TREND_RISK_BREACH_MQH_
