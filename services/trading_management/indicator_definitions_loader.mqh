
//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES TF_LIST[] =
{
  PERIOD_M1, PERIOD_M2, PERIOD_M3, PERIOD_M4, PERIOD_M5, PERIOD_M6,
  PERIOD_M10, PERIOD_M12, PERIOD_M15, PERIOD_M20, PERIOD_M30,
  PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4
  // PERIOD_H6, PERIOD_H8, PERIOD_H12, PERIOD_D1 (OPTIONAL)
};
int IndicatorPeriods[7] = {5, 8, 13, 21, 34, 55, 89};
IndicatorsHandleInfo ExtBandsIndicatorsHandle[];
IndicatorsHandleInfo ExtBPercentIndicatorsHandle[];
IndicatorsHandleInfo ExtStochIndicatorsHandle[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtBodyMAIndicatorsHandle[];

// TOTAL INDICATORS TO LOAD
int start_bands_indicators_load = 3;
int total_bands_indicators_load = 1;
int total_stoch_indicators_load = 1;
int total_tf_list_load          = ArraySize(TF_LIST);

// INPUT SETTINGS
input group  "+= Developer Debug Settings =+";
input bool Test_Mode                    = false;
input bool Hide_Indicator_Variants       = true;
input bool Enable_Logs                    = true;
input bool Enable_Verification_Logs      = false;

void LoadAllIndicatorDefinitions()
{
  // OVERRIDE TOTAL INDICATORS TO LOAD FOR TESTING PURPOSES
  if(Test_Mode)
  {
    start_bands_indicators_load = 0;
    total_bands_indicators_load = 1;
    total_stoch_indicators_load = 1;
    total_tf_list_load          = 1;
  }

  // HIDE INDICATORS VARIANTS
  TesterHideIndicators(Hide_Indicator_Variants);

  // LOAD ALL INDICATORS VARIANTS
  LoadAllBandsIndicators();
  LoadAllBPercentIndicators();
  LoadAllStochIndicators();
  LoadAllStructStochIndicators();
  LoadAllBodyMAIndicators();
}

// ++ LOAD ALL INDICATORS VARIANTS FUNCTIONS ++

void LoadAllBandsIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = TF_LIST[i];
    int total_periods_load = start_bands_indicators_load+total_bands_indicators_load;

    for(int i = start_bands_indicators_load; i < total_periods_load; i++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[i];
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\BB_Standard.ex5", bands_indicator_handle_loaded.indicator_period, 0, 2.0, MODE_EMA, PRICE_WEIGHTED);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);

      AddElementToArray(ExtBandsIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllBPercentIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = TF_LIST[i];
    int total_periods_load = start_bands_indicators_load+total_bands_indicators_load;

    for(int i = start_bands_indicators_load; i < total_periods_load; i++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[i];
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\BB_Percent_Standard.ex5", bands_indicator_handle_loaded.indicator_period, 0, 2.0, 5, MODE_EMA, PRICE_WEIGHTED);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS PERCENT INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS PERCENT INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);

      AddElementToArray(ExtBPercentIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = TF_LIST[i];

    for(int i = 0; i < total_stoch_indicators_load; i++)
    {
      IndicatorsHandleInfo stoch_indicator_handle_loaded;

      stoch_indicator_handle_loaded.indicator_period    = IndicatorPeriods[i];
      stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic", stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
      stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);
        TesterStop();
        break;
      }

      Print("LOADED STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);

      AddElementToArray(ExtStochIndicatorsHandle, stoch_indicator_handle_loaded);
    }
  }
}

void LoadAllStructStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = TF_LIST[i];

    for(int i = 0; i < total_stoch_indicators_load; i++)
    {
      IndicatorsHandleInfo struct_stoch_indicator_handle_loaded;

      struct_stoch_indicator_handle_loaded.indicator_period    = IndicatorPeriods[i];
      struct_stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic_Structure", struct_stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
      struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING STRUCT STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);
        TesterStop();
        break;
      }

      Print("LOADED STRUCT STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[i]);

      AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
    }
  }
}

void LoadAllBodyMAIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = TF_LIST[i];

    IndicatorsHandleInfo body_ma_indicator_handle_loaded;

    body_ma_indicator_handle_loaded.indicator_period    = 5;
    body_ma_indicator_handle_loaded.indicator_shift     = 0;
    body_ma_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Body_MA.ex5", 5, 0);
    body_ma_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(body_ma_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING BODY MA INDICATOR: ", EnumToString(trend_timeframe), " | PERIOD: 5");
      TesterStop();
      break;
    }

    Print("LOADED BODY MA INDICATOR SUCCESFULLY: ", EnumToString(trend_timeframe), " | PERIOD: 5");

    AddElementToArray(ExtBodyMAIndicatorsHandle, body_ma_indicator_handle_loaded);
  }
}

#endif // _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
