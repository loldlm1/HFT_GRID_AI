
//+------------------------------------------------------------------+
//|                                 indicator_definitions_loader.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_
#define _SERVICES_TRADING_MANAGEMENT_INDICATOR_DEFINITIONS_LOADER_MQH_

// GLOBAL SETTINGS
ENUM_TIMEFRAMES Strategy_TF_List[];
int IndicatorPeriods[];
IndicatorsHandleInfo ExtBandsIndicatorsHandle[];
IndicatorsHandleInfo ExtBPercentIndicatorsHandle[];
IndicatorsHandleInfo ExtStochIndicatorsHandle[];
IndicatorsHandleInfo ExtStructStochIndicatorsHandle[];
IndicatorsHandleInfo ExtBodyMAIndicatorsHandle[];
IndicatorsHandleInfo ExtATRIndicatorsHandle[];

// TOTAL INDICATORS TO LOAD
int start_bands_indicators_load = 0;
int total_bands_indicators_load = 1;
int total_stoch_indicators_load = 1;
int total_tf_list_load          = 0;

// ── Helpers ─────────────────────────────────────────────────────────────

bool IsStrategyTimeframeSupported(const ENUM_TIMEFRAMES tf)
{
  switch(tf)
  {
    case PERIOD_M1:
    case PERIOD_M2:
    case PERIOD_M3:
    case PERIOD_M4:
    case PERIOD_M5:
    case PERIOD_M6:
    case PERIOD_M10:
    case PERIOD_M12:
    case PERIOD_M15:
    case PERIOD_M20:
    case PERIOD_M30:
    case PERIOD_H1:
    case PERIOD_H2:
    case PERIOD_H3:
    case PERIOD_H4:
      return true;
  }
  return false;
}

void PrepareStrategyTimeframes()
{
  ArrayResize(Strategy_TF_List, 0);

  ENUM_TIMEFRAMES configured_tf = Strategy_Timeframe;
  if(!IsStrategyTimeframeSupported(configured_tf))
  {
    PrintFormat("Strategy timeframe %d not supported. Falling back to PERIOD_M1.", (int)configured_tf);
    configured_tf = PERIOD_M1;
  }

  ArrayResize(Strategy_TF_List, 1);
  Strategy_TF_List[0] = configured_tf;
  total_tf_list_load = ArraySize(Strategy_TF_List);
}

void PrepareIndicatorPeriods()
{
  ArrayResize(IndicatorPeriods, 1);
  IndicatorPeriods[0] = (int)Base_Indicator_Period_Type;
}

void LoadAllIndicatorDefinitions()
{
  PrepareStrategyTimeframes();
  PrepareIndicatorPeriods();

  bool use_base_indicator  = (Base_Indicator_Strategy_Type != BB_NONE_TYPE);
  bool use_solid_indicator = (Solid_Indicator_Strategy_Type != SOLID_NONE_TYPE);

  bool use_atr_strategy = (Grid_Base_Strategy_Type == ATR_RANGE);

  if(!use_base_indicator && !use_solid_indicator)
  {
    Print("WARNING: Both base and solid strategies are disabled; signal generation will be halted.");
  }

  PrintFormat("Strategy context | TF=%s | BaseStrategy=%s | BasePeriod=%d | SolidStrategy=%s | SolidPeriod=%d | Direction=%s",
              EnumToString(Strategy_Timeframe),
              EnumToString(Base_Indicator_Strategy_Type),
              (int)Base_Indicator_Period_Type,
              EnumToString(Solid_Indicator_Strategy_Type),
              (int)Solid_Indicator_Period_Type,
              EnumToString(Strategy_Direction_Mode));

  ArrayResize(ExtBandsIndicatorsHandle, 0);
  ArrayResize(ExtBPercentIndicatorsHandle, 0);
  ArrayResize(ExtStochIndicatorsHandle, 0);
  ArrayResize(ExtStructStochIndicatorsHandle, 0);
  ArrayResize(ExtBodyMAIndicatorsHandle, 0);
  ArrayResize(ExtATRIndicatorsHandle, 0);

  // LOAD ALL INDICATORS VARIANTS
  if(Base_Indicator_Strategy_Type == BANDS_TYPE)
  {
    LoadAllBandsIndicators();
  }
  else
  {
    Print("Skipping Bollinger Bands indicator loading (not required for selected base strategy).");
  }

  if(use_base_indicator)
  {
    LoadAllBPercentIndicators();
  }
  else
  {
    Print("Base indicator strategy disabled; skipping Bollinger Percent indicator loading.");
  }

  if(use_solid_indicator)
  {
    LoadAllStochIndicators();
    LoadAllStructStochIndicators();
  }
  else
  {
    Print("Solid indicator strategy disabled; skipping stochastic indicator loading.");
  }

  if(use_atr_strategy)
  {
    LoadAllATRIndicators();
  }
  else
  {
    Print("ATR grid strategy disabled; skipping ATR indicator loading.");
  }

  LoadAllBodyMAIndicators();
}

// ++ LOAD ALL INDICATORS VARIANTS FUNCTIONS ++

void LoadAllBandsIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    int total_periods_load = ArraySize(IndicatorPeriods);
    int limit = start_bands_indicators_load + total_bands_indicators_load;
    if(total_periods_load > limit)
      total_periods_load = limit;

    for(int period_index = start_bands_indicators_load; period_index < total_periods_load; period_index++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[period_index];
      bands_indicator_handle_loaded.indicator_ma_method  = Base_Indicator_MA_Method;
      bands_indicator_handle_loaded.indicator_applied_price = PRICE_WEIGHTED;
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                                  trend_timeframe,
                                                                  "Examples\\BB_Standard.ex5",
                                                                  bands_indicator_handle_loaded.indicator_period,
                                                                  0,
                                                                  2.0,
                                                                  Base_Indicator_MA_Method,
                                                                  PRICE_WEIGHTED);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);

      AddElementToArray(ExtBandsIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllBPercentIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];
    int total_periods_load = ArraySize(IndicatorPeriods);
    int limit = start_bands_indicators_load + total_bands_indicators_load;
    if(total_periods_load > limit)
      total_periods_load = limit;

    for(int period_index = start_bands_indicators_load; period_index < total_periods_load; period_index++)
    {
      IndicatorsHandleInfo bands_indicator_handle_loaded;

      bands_indicator_handle_loaded.indicator_period     = IndicatorPeriods[period_index];
      bands_indicator_handle_loaded.indicator_ma_method  = Base_Indicator_MA_Method;
      bands_indicator_handle_loaded.indicator_applied_price = PRICE_WEIGHTED;
      bands_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                                  trend_timeframe,
                                                                  "Examples\\BB_Percent_Standard.ex5",
                                                                  bands_indicator_handle_loaded.indicator_period,
                                                                  0,
                                                                  2.0,
                                                                  5,
                                                                  Base_Indicator_MA_Method,
                                                                  PRICE_WEIGHTED);
      bands_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

      if(bands_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
      {
        Print("ERROR LOADING BANDS PERCENT INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);
        TesterStop();
        break;
      }

      Print("LOADED BANDS PERCENT INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", IndicatorPeriods[period_index]);

      AddElementToArray(ExtBPercentIndicatorsHandle, bands_indicator_handle_loaded);
    }
  }
}

void LoadAllStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo stoch_indicator_handle_loaded;

    stoch_indicator_handle_loaded.indicator_period    = (int)Solid_Indicator_Period_Type;
    stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic", stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
    stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      break;
    }

    Print("LOADED STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStochIndicatorsHandle, stoch_indicator_handle_loaded);
  }
}

void LoadAllStructStochIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo struct_stoch_indicator_handle_loaded;

    struct_stoch_indicator_handle_loaded.indicator_period    = (int)Solid_Indicator_Period_Type;
    struct_stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic_Structure", struct_stoch_indicator_handle_loaded.indicator_period, 3, 3, STO_CLOSECLOSE);
    struct_stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(struct_stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STRUCT STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);
      TesterStop();
      break;
    }

    Print("LOADED STRUCT STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe), " | PERIOD: ", struct_stoch_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtStructStochIndicatorsHandle, struct_stoch_indicator_handle_loaded);
  }
}

void LoadAllATRIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

    IndicatorsHandleInfo atr_indicator_handle_loaded;

    atr_indicator_handle_loaded.indicator_period    = (int)Base_Indicator_Period_Type;
    double atr_factor = Grid_ATR_Points_Setup;
    if(atr_factor <= 0.0)
      atr_factor = 1.0;
    atr_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol,
                                                              trend_timeframe,
                                                              "Examples\\ATR_SL_Factor.ex5",
                                                              atr_indicator_handle_loaded.indicator_period,
                                                              atr_factor,
                                                              0);
    atr_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(atr_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING ATR FACTOR INDICATOR: ", EnumToString(trend_timeframe), " | PERIOD: ", atr_indicator_handle_loaded.indicator_period);
      TesterStop();
      break;
    }

    Print("LOADED ATR FACTOR INDICATOR SUCCESSFULLY: ", EnumToString(trend_timeframe), " | PERIOD: ", atr_indicator_handle_loaded.indicator_period);

    AddElementToArray(ExtATRIndicatorsHandle, atr_indicator_handle_loaded);
  }
}

void LoadAllBodyMAIndicators()
{
  for(int i = 0; i < total_tf_list_load; ++i)
  {
    ENUM_TIMEFRAMES trend_timeframe = Strategy_TF_List[i];

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
