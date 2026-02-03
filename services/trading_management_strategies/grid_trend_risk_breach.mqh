//+------------------------------------------------------------------+
//|        trading_management_strategies/grid_trend_risk_breach.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_TREND_RISK_BREACH_MQH_
#define _GRID_TREND_RISK_BREACH_MQH_

bool GridTrendSarAlligatorBreach(const SignalTypes direction,
                                 const ENUM_TIMEFRAMES target_tf,
                                 const GridRiskTrendStrategyConfig &risk_config)
{
  if(direction != BULLISH && direction != BEARISH)
    return false;
  if((int)target_tf < 0)
    return false;
  if(risk_config.mode == GRID_RM_TREND_OFF)
    return false;
  return true;
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
