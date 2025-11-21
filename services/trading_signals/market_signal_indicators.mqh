//+------------------------------------------------------------------+
//|                             market_signal_indicators.mqh        |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_

void SetTFBandsPercentDataToSignalParams(SignalParams &signal_params)
{
  for(int i = 0; i < ArraySize(ExtBPercentIndicatorsHandle); i++)
  {
    BandsPercentStructure bands_percent_data;
    bands_percent_data = BandsPercentStructure();
    bands_percent_data.InitBandsPercentStructureValues(ExtBPercentIndicatorsHandle[i], 0);

    AddElementToArray(signal_params.bands_percent_data, bands_percent_data);
  }
}

void SetTFAlligatorDataToSignalParams(SignalParams &signal_params)
{
  int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
  int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
  int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

  for(int i = 0; i < ArraySize(ExtAlligatorIndicatorsHandle); i++)
  {
    AlligatorStructure alligator_data;
    alligator_data = AlligatorStructure();
    if(!alligator_data.InitAlligatorStructureValues(ExtAlligatorIndicatorsHandle[i],
                                                    0,
                                                    jaws_period,
                                                    teeth_period,
                                                    lips_period))
    {
      if(Enable_Logs)
        Print("Failed to initialize base Alligator data for timeframe: ",
              EnumToString(ExtAlligatorIndicatorsHandle[i].indicator_timeframe));
      continue;
    }
    AddElementToArray(signal_params.alligator_data, alligator_data);
  }
}

void SetTFStochasticDataToSignalParams(SignalParams &signal_params)
{
  for(int i = 0; i < ArraySize(ExtStochIndicatorsHandle); i++)
  {
    StochasticStructure stochastic_data;
    stochastic_data = StochasticStructure();
    stochastic_data.InitStochasticStructureValues(ExtStochIndicatorsHandle[i], 0);

    AddElementToArray(signal_params.stochastic_data, stochastic_data);
  }
}

void SetTFStochasticMarketStructureDataToSignalParams(SignalParams &signal_params)
{
  for(int i = 0; i < ArraySize(ExtStructStochIndicatorsHandle); i++)
  {
    StochasticMarketStructure stoch_market_structure_data;
    stoch_market_structure_data = StochasticMarketStructure();
    stoch_market_structure_data.InitStochMarketStructureValues(ExtStructStochIndicatorsHandle[i]);
    AddElementToArray(signal_params.stoch_market_structure_data, stoch_market_structure_data);
  }
}

void SetTFBodyMADataToSignalParams(SignalParams &signal_params)
{
  for(int i = 0; i < ArraySize(ExtBodyMAIndicatorsHandle); i++)
  {
    BodyMAStructure body_ma_data;
    body_ma_data = BodyMAStructure();
    body_ma_data.InitBodyMAStructureValues(ExtBodyMAIndicatorsHandle[i], 0);

    AddElementToArray(signal_params.body_ma_data, body_ma_data);
  }
}

bool LoadTrendFilterData(SignalParams &signal_params)
{
  if(!TrendContextEnabled() || Strategy_Trend_Mode == TREND_OFF)
  {
    signal_params.trend_filter_mode    = TREND_OFF;
    signal_params.trend_bpercent_valid = false;
    signal_params.trend_alligator_valid = false;
    signal_params.trend_stochastic_valid = false;
    return true;
  }

  signal_params.trend_filter_mode    = Strategy_Trend_Mode;
  signal_params.trend_bpercent_valid = false;
  signal_params.trend_alligator_valid = false;
  signal_params.trend_stochastic_valid = false;

  bool require_bpercent   = StrategyModeUsesAnyBPercent(Strategy_Trend_Mode);
  bool require_alligator  = StrategyModeUsesAlligator(Strategy_Trend_Mode);
  bool slope_bpercent     = Trend_BPercent_Slope_Filter;
  bool slope_alligator    = Trend_Alligator_Slope_Filter;

  if(require_bpercent || slope_bpercent)
  {
    if(TrendBPercentIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend Bollinger Percent indicator unavailable.");
      return false;
    }

    signal_params.trend_bpercent_data = BandsPercentStructure();
    signal_params.trend_bpercent_data.InitBandsPercentStructureValues(TrendBPercentIndicatorHandle, 0);
    signal_params.trend_bpercent_valid = true;
  }

  if(require_alligator || slope_alligator)
  {
    if(TrendAlligatorIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend Alligator indicator unavailable.");
      return false;
    }

    int jaws_period  = MathMax(Alligator_Jaws_Period, 1);
    int teeth_period = MathMax((int)Base_Indicator_Period_Type, 1);
    int lips_period  = MathMax((int)Stoch_Structure_Period_Type, 1);

    signal_params.trend_alligator_data = AlligatorStructure();
    if(!signal_params.trend_alligator_data.InitAlligatorStructureValues(TrendAlligatorIndicatorHandle,
                                                                        0,
                                                                        jaws_period,
                                                                        teeth_period,
                                                                        lips_period))
    {
      if(Enable_Logs)
        Print("Trend Alligator data initialization failed.");
      return false;
    }
    signal_params.trend_alligator_valid = true;
  }

  if(Trend_Stochastic_Slope_Filter)
  {
    if(TrendStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
    {
      if(Enable_Logs)
        Print("Trend stochastic indicator unavailable.");
      return false;
    }
    signal_params.trend_stochastic_data = StochasticStructure();
    signal_params.trend_stochastic_data.InitStochasticStructureValues(TrendStochIndicatorHandle, 0);
    signal_params.trend_stochastic_valid = true;
  }

  return true;
}

bool LoadTrendStructureData(SignalParams &signal_params)
{
  signal_params.trend_structure_valid = false;

  if(!TrendStructureDataRequired())
    return true;

  if(TrendStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
  {
    if(Enable_Logs)
      Print("Trend structure indicator unavailable.");
    return false;
  }

  signal_params.trend_structure_data = StochasticMarketStructure();
  if(!signal_params.trend_structure_data.InitStochMarketStructureValues(TrendStructStochIndicatorHandle))
  {
    if(Enable_Logs)
      Print("Trend structure data initialization failed.");
    return false;
  }

  signal_params.trend_structure_valid = true;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_INDICATORS_MQH_
