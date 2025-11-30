//+------------------------------------------------------------------+
//|              trading_management_strategies/grid_risk_trend_strategy.mqh |
//+------------------------------------------------------------------+
#ifndef _GRID_RISK_TREND_STRAT_MQH_
#define _GRID_RISK_TREND_STRAT_MQH_

struct GridRiskTrendStrategyConfig
{
  GridRiskTrendModes             mode;
  GridRiskAlligatorReferenceModes reference;
  GridRiskTrendTimeframeSources   timeframe_source;
  ENUM_TIMEFRAMES                 configured_timeframe;
};

GridRiskTrendStrategyConfig GridBuildRiskTrendStrategyConfig()
{
  GridRiskTrendStrategyConfig config;
  config.mode                = Grid_Risk_Trend_Mode;
  config.reference           = Grid_Risk_Alligator_Reference;
  config.timeframe_source    = Grid_Risk_Timeframe_Source;
  config.configured_timeframe = Grid_Risk_Trend_Timeframe;
  return config;
}

bool GridRiskTrendModeRequiresFloating(const GridRiskTrendStrategyConfig &config)
{
  return (config.mode == GRID_RM_TREND_BE ||
          config.mode == GRID_RM_TREND_SAR);
}

bool GridRiskTrendModeAllowsExit(const GridRiskTrendStrategyConfig &config,
                                 const double floating_profit)
{
  if(config.mode != GRID_RM_TREND_BE)
    return true;

  double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  if(tolerance <= 0.0)
    tolerance = 0.1;
  return (floating_profit >= -tolerance);
}

bool GridRiskTrendModeUsesSar(const GridRiskTrendStrategyConfig &config)
{
  return (config.mode == GRID_RM_TREND_SAR);
}

GridRiskTrendTimeframeSources GridResolveRiskTrendSource(const GridRiskTrendStrategyConfig &config)
{
  if(config.timeframe_source == GRID_RISK_TF_STRATEGY ||
     config.timeframe_source == GRID_RISK_TF_TREND ||
     config.timeframe_source == GRID_RISK_TF_MACRO ||
     config.timeframe_source == GRID_RISK_TF_SESSION)
    return config.timeframe_source;
  return GRID_RISK_TF_TREND;
}

ENUM_TIMEFRAMES GridResolveRiskTrendStrategyTimeframe(const GridRiskTrendStrategyConfig &config)
{
  if(Risk_Trend_Timeframe > 0)
    return Risk_Trend_Timeframe;
  if(config.configured_timeframe != PERIOD_CURRENT &&
     IsStrategyTimeframeSupported(config.configured_timeframe))
    return config.configured_timeframe;
  return ResolveRiskTrendTimeframe();
}

string GridRiskTrendComposeLogLabel(const GridRiskTrendStrategyConfig &config,
                                    const string suffix)
{
  string reference_label = (config.reference == GRID_RISK_REF_TEETH) ? "TEETH" : "JAWS";
  return StringFormat("GRID_RISK_TREND_%s_%s",
                      reference_label,
                      suffix);
}

#endif // _GRID_RISK_TREND_STRAT_MQH_
