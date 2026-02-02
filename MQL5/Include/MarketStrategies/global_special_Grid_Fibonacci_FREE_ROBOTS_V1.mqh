enum ma_method_speed
{
  Standard_Speed  = MODE_SMA,
  Growth_Speed    = MODE_EMA,
  Slow_Soft_Speed = MODE_SMMA,
  Fast_Soft_Speed = MODE_LWMA
};

enum PriceCandleType
{
  CANDLE_PRICE_HIGH   = PRICE_HIGH,
  CANDLE_PRICE_MEDIAN = PRICE_MEDIAN,
  CANDLE_PRICE_LOW    = PRICE_LOW,
};

enum strategy_type
{
  Strategy_Fast_Slow_MA = 1,
  Strategy_Middle_MA    = 2
};

enum hedging_positions_type
{
  Allow_Bullish_Positions          = 1,
  Allow_Bearish_Positions          = 2,
  Allow_Both_Positions             = 3
};

enum depth_ma_type
{
  DEPTH_MA_FAST   = 1,
  DEPTH_MA_MIDDLE = 2,
  DEPTH_MA_SLOW   = 3,
  DEPTH_BB_UPPER  = 4,
  DEPTH_BB_LOWER  = 5
};

enum strategy_ao_type
{
  STRATEGY_MA_FAST   = 1,
  STRATEGY_MA_MIDDLE = 2,
  STRATEGY_MA_SLOW   = 3,
  STRATEGY_BB        = 4
};

enum trend_ma_type
{
  TREND_UNDEFINED = 1,
  TREND_BULLISH   = 2,
  TREND_BEARISH   = 3
};

enum trigger_ma
{
  ANY_TRIGGER_MA    = 0,
  FAST_TRIGGER_MA   = 1,
  MIDDLE_TRIGGER_MA = 2,
  SLOW_TRIGGER_MA   = 3
};

enum structure_ao_type
{
  NO_AO_STRUCTURE         = 0,
  TREND_AO_STRUCTURE      = 1,
  REVERTION_AO_STRUCTURE  = 2,
  DIVERGENCE_AO_STRUCTURE = 3
};

enum macd_ao_state
{
  BOTH_AO_STATE      = 0,
  TREND_AO_STATE     = 1,
  REVERTION_AO_STATE = 2
};

enum trend_tf_type
{
  NO_TREND_TYPE   = 0,
  TF_TREND_AO     = 1
};

enum macd_trend_cloud_range_types
{
  AO_CLOUD_MA_UNDEFINED = 0,
  AO_CLOUD_MA_INSIDE    = 1,
  AO_CLOUD_MA_OUTSIDE   = 2
};

enum AOAOTypes
{
  AO_3_21   = 0,
  AO_5_34   = 1,
  AO_8_55   = 2,
  AO_13_89  = 3,
  AO_21_144 = 4,
  AO_34_233 = 5
};

enum DynamicEntryVariantTypes
{
  ONLY_INSIDE_ENVELOPE      = 0,
  ONLY_WICK_MA              = 1,
  ONLY_INSIDE_MA            = 2,
  WICK_OR_INSIDE_MA         = 3,
  CANDLE_INSIDE_AND_WICK_MA = 4
};

enum StaticEntryVariantTypes
{
  NO_STATIC_ENTRY             = 0,
  STRUCTURE_TREND_ZIGZAG      = 1,
  STRUCTURE_REVERTION_ZIGZAG  = 2,
  STRUCTURE_DIVERGENCE_ZIGZAG = 3
};

enum ExtraEntryVariantTypes
{
  NO_EXTRA_VARIANTS  = 0,
  STOCH_OVER_SB      = 1,
  ENGULFING_CANDLE   = 2,
  ALL_EXTRA_VARIANTS = 3
};

enum TrendSignalType
{
  NO_TREND_SIGNAL     = 0,
  ZIGZAG_TREND_SIGNAL = 1,
  AO_TREND_SIGNAL     = 2
};

enum StopLossType
{
  POINTS_BASED_SL    = 0,
  ATR_BASED_SL       = 1,
  FIBONACCI_BASED_SL = 2
};

enum IndicatorFilterType
{
  BOLINGER_BANDS_FILTER = 0
};

enum IndicatorFilterStrategyType
{
  FILTER_FREE_STRATEGY      = 0,
  FILTER_MIDDLE_STRATEGY    = 1,
  FILTER_EXTREMUMS_STRATEGY = 2
};

enum IndicatorFilterPeriod
{
  FILTER_PERIOD_5   = 1,
  FILTER_PERIOD_8   = 2,
  FILTER_PERIOD_13  = 3,
  FILTER_PERIOD_21  = 4,
  FILTER_PERIOD_34  = 5
};

enum FibonacciStrategyCustomType
{
  FIBONACCI_ALL_STRATEGIES = 0,
  FIBONACCI_REVERSION      = 1,
  FIBONACCI_TREND          = 2
};

enum PatternTrendType
{
  BULLISH_PATTERN = 0,
  BEARISH_PATTERN = 1
};

enum EngineFilterType
{
  ENGINE_CLASIC_TYPE        = 0,
  ENGINE_EMA21_PATTERN_TYPE = 1,
  ENGINE_AO_PATTERN_TYPE    = 2
};

enum VariantFilterType
{
  VARIANT_ALL_TYPE        = 0,
  VARIANT_ONLY_STOCH_TYPE = 1,
  VARIANT_ONLY_AO_TYPE    = 2
};

enum TrendMACDFilterType
{
  AWESOME_OSCILLATOR_TYPE = 1,
  MACD_SIGNAL_TYPE        = 2
};

enum ProfitTrendFilterType
{
  PROFIT_MACD_SIGNAL_TYPE   = 1,
  PROFIT_EMA_21_TYPE        = 2,
  PROFIT_BOTH_EMA_MACD_TYPE = 3
};

enum AllowTradesType
{
  MODE_ALL_TRADES_PER_SIGNAL = 1,
  MODE_ONE_TRADE_PER_SIGNAL  = 2
};

enum EquityCurveRiskType
{
  MODE_FREE_EQUITY_CURVE  = 1,
  MODE_TREND_EQUITY_CURVE = 2
};

enum TrainingDataTimeRecordedType
{
  TRAINING_ALL_TIME    = 0,
  TRAINING_1_YEAR_BASE = 1,
  TRAINING_2_YEAR_BASE = 2,
  TRAINING_3_YEAR_BASE = 3,
  TRAINING_4_YEAR_BASE = 4
};

enum SignalExecutionType
{
  SIGNAL_INSTANT_POSITION = 1,
  SIGNAL_DEEP_POSITION    = 2
};

FibonacciStrategyCustomType Fibonacci_Strategy = FIBONACCI_REVERSION;

double Max_Grid_Points       = -DBL_MAX;
int    Daily_Bullish_Signals = 0;
int    Daily_Bearish_Signals = 0;
int    Fast_MA_Period        = 5;
int    Slow_MA_Period        = 34;

// ++ INDICATOR INPUTS ++
//input group                                                "+= Robot Confirmations =+";
IndicatorRobotTypes     Robot_Indicator             = ROBOT_STOCH;

input group                                                "+= Indicator Variants Setup =+";
bool                         Hide_Indicator_Variants     = false;
AllowTradesType              Allow_Trades_Mode           = MODE_ALL_TRADES_PER_SIGNAL;
EquityCurveRiskType          Equity_Curve_Mode           = MODE_FREE_EQUITY_CURVE;
TrainingDataTimeRecordedType Training_Data_Mode          = TRAINING_ALL_TIME;
input bool                         Enable_Logs                   = true;
input IndicatorFilterPeriod        Indicator_Filter_Period       = FILTER_PERIOD_34;
input IndicatorFilterPeriod Indicator_Struct_Filter_Period       = FILTER_PERIOD_5;
input IndicatorFilterPeriod Indicator_Trend_Struct_Filter_Period = FILTER_PERIOD_5;
input ENUM_MA_METHOD               Indicator_Filter_Type         = MODE_SMA;
input ENUM_APPLIED_PRICE           Indicator_Filter_Price        = PRICE_TYPICAL;
input ENUM_TIMEFRAMES              Indicator_Signal_TF           = PERIOD_M1;
input ENUM_TIMEFRAMES              Indicator_Filter_TF           = PERIOD_M3;
input FibonacciSignalLevelsType    Indicator_Fibo_Level          = Fibonacci_Level_61;
input double                       Indicator_True_Factor         = 1.0;

input group  "+= Risk Managment Setup =+";
input RiskManagmentSetupType Risk_Managment_Setup_Type = RISK_FIXED_LOT_SIZE;
input double                 Risk_Account_Size         = 200;
input double                 Risk_Percentage_Lot_Size  = 1.0;
input double                 Risk_Custom_Lot_Size      = 0.01;
input double                 Risk_Profit_Ratio_Factor  = 1.1;

// ++ STRATEGY INPUTS ++

input group                                     "+= Strategy Direction Settings =+";
ENUM_TIMEFRAMES        Timeframe_Signal         = PERIOD_M1;
ENUM_TIMEFRAMES        Timeframe_Confirmation   = PERIOD_M6;
ENUM_TIMEFRAMES        Timeframe_Trend          = PERIOD_M12;
ENUM_TIMEFRAMES        Timeframe_Fractal_Signal = PERIOD_H8;
hedging_positions_type Trades_Only_Side         = Allow_Both_Positions;
input hedging_positions_type Allow_Hedging_Side = Allow_Both_Positions;

// ++ Entry Wave Time Variables ++

datetime bullish_entry_wave_time = 0;
datetime bearish_entry_wave_time = 0;

bool bullish_valid_entry_structure = false;
bool bearish_valid_entry_structure = false;

// ++ MARKET STRUCTURE LOGIC INCLUDES ++
#include <MarketStrategies\free_robots_algos.mqh>
#include <MarketStrategies\free_robots_candlestick_patterns.mqh>
#include <MarketStrategies\oscillator_market_structures.mqh>
#include <MarketStrategies\imbalances_algo.mqh>

void DetectBullishFractalScalperSignal()
{
  SignalsDetectionInfo bullish_potential_signals[];
  SignalsDetectionInfo fractal_signal_information;
  SignalParams         bullish_signal_params;
  bullish_valid_entry_structure          = false;
  ENUM_TIMEFRAMES   timeframe            = PERIOD_CURRENT;
  ENUM_TIMEFRAMES   execution_timeframe  = PERIOD_CURRENT;
  ulong             delay_in_seconds     = (PeriodSeconds(_Period) * 1);
  datetime signal_bullish                = 0;
  bool out_of_news_range                 = true;
  bool valid_risk_managment_params       = false;
  bool close_status                      = false;
  bool position_opened                   = false;
  bool valid_time_signal                 = false;
  bool valid_single_signal               = false;
  bool spread_is_good                    = false;
  bool valid_hedging_bullish             = (Allow_Hedging_Side == Allow_Both_Positions || Allow_Hedging_Side == Allow_Bullish_Positions);
  bool valid_bullish_signal              = false;
  bool valid_bullish_signal_time         = false;
  bool valid_bullish_macd_fractal_signal = false;

  // BULLISH PATTERN AS BULLISH
  if(
    valid_hedging_bullish && BullishRobotIndicatorVariantsSignal(bullish_potential_signals)
  ) valid_bullish_macd_fractal_signal = true;

  if(valid_bullish_macd_fractal_signal)
  {
    signal_bullish                            = iTime(_Symbol, Timeframe_Signal, 0);
    bullish_valid_entry_structure             = true;
    bullish_signal_params.strategy_type       = stoch_divergence_signal;
    bullish_signal_params.execution_timeframe = Timeframe_Signal;
    SetValidBullishFibonacciSignals(bullish_signal_params, bullish_potential_signals);
  }
}

void DetectBearishFractalScalperSignal()
{
  SignalsDetectionInfo bearish_potential_signals[];
  SignalsDetectionInfo fractal_signal_information;
  SignalParams         bearish_signal_params;
  bearish_valid_entry_structure          = false;
  ENUM_TIMEFRAMES   timeframe            = PERIOD_CURRENT;
  ENUM_TIMEFRAMES   execution_timeframe  = PERIOD_CURRENT;
  ulong delay_in_seconds                 = (PeriodSeconds(_Period) * 1);
  datetime signal_bearish                = 0;
  bool out_of_news_range                 = true;
  bool valid_risk_managment_params       = false;
  bool close_status                      = false;
  bool position_opened                   = false;
  bool valid_time_signal                 = false;
  bool valid_single_signal               = false;
  bool spread_is_good                    = false;
  bool valid_hedging_bearish             = (Allow_Hedging_Side == Allow_Both_Positions || Allow_Hedging_Side == Allow_Bearish_Positions);
  bool valid_bearish_signal              = false;
  bool valid_bearish_signal_time         = false;
  bool valid_bearish_macd_fractal_signal = false;

  // BEARISH PATTERN AS BEARISH
  if(
    valid_hedging_bearish && BearishRobotIndicatorVariantsSignal(bearish_potential_signals)
  ) valid_bearish_macd_fractal_signal = true;

  if(valid_bearish_macd_fractal_signal)
  {
    signal_bearish                            = iTime(_Symbol, Timeframe_Signal, 0);
    bearish_valid_entry_structure             = true;
    bearish_signal_params.strategy_type       = stoch_divergence_signal;
    bearish_signal_params.execution_timeframe = Timeframe_Signal;
    SetValidBearishFibonacciSignals(bearish_signal_params, bearish_potential_signals);
  }
}

// ++++++++ SET VARIANTS SIGNAL POINTS LOGIC ++++++++

void SetValidBullishFibonacciSignals(SignalParams &bullish_signal_params, SignalsDetectionInfo &bullish_potential_signals[])
{
  DBTopVariantResumeStats top_variants_hashes[];
  DBTopEngineStats        top_engine_stats;
  int      running_signals_total         = ArraySize(RunningSignalLevels);
  int      total_potential_signals       = ArraySize(bullish_potential_signals);
  bool     valid_risk_managment_params   = false;
  bool     valid_unique_structure        = false;
  bool     found_high_winrate_signal     = false;
  bool     no_signals_running            = (running_signals_total == 0);
  string   unique_range_id               = "";
  string   entry_session_type            = "";
  string   unique_variant_hash           = "";
  int      over_boughtsold_period_signal = 0;
  int      bands_period_signal           = 0;

  for(int i = 0; i < total_potential_signals; i++)
  {
    SignalParams individual_bullish_signal_params     = bullish_signal_params;
    SignalParams individual_bearish_signal_params     = bullish_signal_params;
    individual_bullish_signal_params.signal_direction = BULLISH;

    valid_risk_managment_params = SetPositionRiskManagment(Timeframe_Signal, BULLISH, individual_bullish_signal_params, 0);

    if(valid_risk_managment_params)
    {
      // SET VALUES TO POTENTIAL SIGNAL
      individual_bullish_signal_params.entry_time           = iTime(_Symbol, Timeframe_Signal, 0);
      bullish_potential_signals[i].signal_direction         = BULLISH;
      bullish_potential_signals[i].signal_entry_hour        = GetSignalEntryHour();
      bullish_potential_signals[i].signal_entry_minute      = GetSignalEntryMinute();
      individual_bullish_signal_params.signal_detected_info = bullish_potential_signals[i];
      over_boughtsold_period_signal                         = bullish_potential_signals[i].over_boughtsold_period_signal;
      bands_period_signal                                   = bullish_potential_signals[i].bands_period_signal;

      GenerateBullishSideID(BULLISH, individual_bullish_signal_params, individual_bearish_signal_params);
      valid_unique_structure = true;
      unique_range_id        = individual_bullish_signal_params.unique_grid_id;
      unique_variant_hash    = individual_bullish_signal_params.unique_variant_hash;

      if(valid_unique_structure)
      {
        // WE SELECTS THE BEST UNIQUE SIGNAL TO OPEN THE POSITION
        // SUCCESS RATE BASED ON EVERY SIGNAL PARAMS
        // ONLY TAKES ONE TRADE FOR SIGNALS STACK
        if(no_signals_running && !HasOpenPosition() && !found_high_winrate_signal)
        {
          individual_bullish_signal_params.fibonacci_ratios.is_high_win_rate_level = true;

          found_high_winrate_signal = true;

          StartSignalExcecution(BULLISH, individual_bullish_signal_params);
        }
      }
    }
  }
}

void SetValidBearishFibonacciSignals(SignalParams &bearish_signal_params, SignalsDetectionInfo &bearish_potential_signals[])
{
  DBTopVariantResumeStats top_variants_hashes[];
  DBTopEngineStats        top_engine_stats;
  int      running_signals_total         = ArraySize(RunningSignalLevels);
  int      total_potential_signals       = ArraySize(bearish_potential_signals);
  bool     valid_risk_managment_params   = false;
  bool     valid_unique_structure        = false;
  bool     found_high_winrate_signal     = false;
  bool     no_signals_running            = (running_signals_total == 0);
  string   unique_range_id               = "";
  string   entry_session_type            = "";
  string   unique_variant_hash           = "";
  int      over_boughtsold_period_signal = 0;
  int      bands_period_signal           = 0;

  for(int i = 0; i < total_potential_signals; i++)
  {
    SignalParams individual_bearish_signal_params     = bearish_signal_params;
    SignalParams individual_bullish_signal_params     = bearish_signal_params;
    individual_bearish_signal_params.signal_direction = BEARISH;

    valid_risk_managment_params = SetPositionRiskManagment(Timeframe_Signal, BEARISH, individual_bearish_signal_params, 0);

    if(valid_risk_managment_params)
    {
      // SET VALUES TO POTENTIAL SIGNAL
      individual_bearish_signal_params.entry_time           = iTime(_Symbol, Timeframe_Signal, 0);
      bearish_potential_signals[i].signal_direction         = BEARISH;
      bearish_potential_signals[i].signal_entry_hour        = GetSignalEntryHour();
      bearish_potential_signals[i].signal_entry_minute      = GetSignalEntryMinute();
      individual_bearish_signal_params.signal_detected_info = bearish_potential_signals[i];
      over_boughtsold_period_signal                         = bearish_potential_signals[i].over_boughtsold_period_signal;
      bands_period_signal                                   = bearish_potential_signals[i].bands_period_signal;

      GenerateBearishSideID(BEARISH, individual_bearish_signal_params, individual_bullish_signal_params);
      valid_unique_structure = true;
      unique_range_id        = individual_bearish_signal_params.unique_grid_id;
      unique_variant_hash    = individual_bearish_signal_params.unique_variant_hash;

      if(valid_unique_structure)
      {
        // WE SELECTS THE BEST UNIQUE SIGNAL TO OPEN THE POSITION
        // SUCCESS RATE BASED ON EVERY SIGNAL PARAMS SCORE
        // ONLY TAKES ONE TRADE FOR SIGNALS STACK
        if(no_signals_running && !HasOpenPosition() && !found_high_winrate_signal)
        {
          individual_bearish_signal_params.fibonacci_ratios.is_high_win_rate_level = true;

          found_high_winrate_signal = true;

          StartSignalExcecution(BEARISH, individual_bearish_signal_params);
        }
      }
    }
  }
}

// ++ STARTING SIGNAL DRAW AND FIBONACCI EXCECUTION ++

void StartSignalExcecution(int direction, SignalParams &signal_params)
{
  int    signal_direction = signal_params.signal_direction;
  string direction_name   = direction == BULLISH ? "BULLISH" : "BEARISH";

  //if(direction == BULLISH) DrawFibonacciRetracementBullishSignal(signal_params);
  //if(direction == BEARISH) DrawFibonacciRetracementBearishSignal(signal_params);

  // PRINT AT THE BEGGINING TO SEE WHEN THE SIGNAL OPENS IN THE MARKET
  Log(
    " ++ TAKING " + direction_name + " SIGNAL VARIANT ++ " + " \n" +
    " UNIQUE ID: " + (string)signal_params.unique_grid_id + " \n" +
    " ENTRY TIME: " + (string)signal_params.entry_time
  );

  // WE TAKES EVERY UNIQUE SIGNAL TO UPDATES THE STATISTIC DYNAMICALLY
  if(direction == BULLISH) StartIndividualBullishSignal(direction, signal_params);
  if(direction == BEARISH) StartIndividualBearishSignal(direction, signal_params);
}

// ++ SIGNAL STRUCTURE SIDE ID GENERATION ++

void GenerateBullishSideID(int direction, SignalParams &bullish_signal_params, SignalParams &bearish_signal_params)
{
  datetime signal_entry_time   = bullish_signal_params.entry_time;
  int      trigger_signal_type = bullish_signal_params.signal_detected_info.trigger_signal_type;
  int      bands_period_signal = bullish_signal_params.signal_detected_info.bands_period_signal;

  string unique_range_id = GenerateSHA256UniqueID(
    direction,
    signal_entry_time,
    trigger_signal_type, bands_period_signal
  );

  // ++ BULLISH SIDE SIGNAL ID ++
  bullish_signal_params.unique_grid_id = unique_range_id;
  bullish_signal_params.fibonacci_ratios.SetUniqueRangeID(unique_range_id);
}

void GenerateBearishSideID(int direction, SignalParams &bearish_signal_params, SignalParams &bullish_signal_params)
{
  datetime signal_entry_time   = bearish_signal_params.entry_time;
  int      trigger_signal_type = bearish_signal_params.signal_detected_info.trigger_signal_type;
  int      bands_period_signal = bearish_signal_params.signal_detected_info.bands_period_signal;

  string unique_range_id = GenerateSHA256UniqueID(
    direction,
    signal_entry_time,
    trigger_signal_type, bands_period_signal
  );

  // ++ BEARISH SIDE SIGNAL ID ++
  bearish_signal_params.unique_grid_id = unique_range_id;
  bearish_signal_params.fibonacci_ratios.SetUniqueRangeID(unique_range_id);
}

// ++ VARIANS SIGNALS LOGIC ++

bool BullishRobotIndicatorVariantsSignal(SignalsDetectionInfo &bullish_potential_signals[])
{
  int  total_body_candle_ma_indicators  = ArraySize(ExtSignalBodyCandleMAIndicatorsHandle);
  int  total_filter_indicators          = ArraySize(ExtSignalFilterIndicatorsHandle);
  int  total_over_boughtsold_indicators = 0;
  int  total_signals                    = 0;
  int  current_indicator_period         = 0;
  int  current_indicator_handler        = INVALID_HANDLE;
  int  current_extra_indicator_handler  = INVALID_HANDLE;

  total_over_boughtsold_indicators = ArraySize(ExtSignalStochIndicatorsHandle);

  for(int bb_i = 0; bb_i < total_filter_indicators; bb_i++)
  {
    SignalsDetectionInfo valid_signal_information;

    if(
      !CheckPatternsTrendSignal(
        BULLISH, Indicator_Signal_TF,
        ExtSignalStochIndicatorsHandle[0].indicator_handle,
        ExtSignalStochIndicatorsHandle[1].indicator_handle,
        ExtBPercentFilterIndicatorsHandle[0].indicator_handle,
        ExtBPercentFilterIndicatorsHandle[1].indicator_handle,
        ExtSignalStructStochIndicatorsHandle[0].indicator_handle,
        ExtSignalStructStochIndicatorsHandle[1].indicator_handle,
        ExtSignalFilterIndicatorsHandle[bb_i], valid_signal_information
      )
    ) continue;

    // PASSING, THEN STORE THE RSI/STOCH PERIOD
    valid_signal_information.over_boughtsold_period_signal = ExtSignalStochIndicatorsHandle[0].indicator_period;
    // PASSING, THEN STORE THE FILTER PERIOD
    valid_signal_information.bands_period_signal = ExtSignalFilterIndicatorsHandle[bb_i].indicator_period;

    // SET CANDLE PATTERN STATS
    //CheckCandlestickPatterns(BULLISH, Timeframe_Signal, ExtSignalBodyCandleMAIndicatorsHandle[0].indicator_handle, valid_signal_information);
    // SET SIGNAL STATISTIC
    //SetSignalStatisticData(BULLISH, valid_signal_information);

    // WIP: CHECK IN THE DATABASE IF THE PERIODS ARE HIGH WIN RATE
    // THEN ALL PASSING STORE THE SIGNAL INFORMATION IN THE ARRAY
    total_signals = AddElementToArray(bullish_potential_signals, valid_signal_information, 1000);
  }

  return total_signals > 0;
}

bool BearishRobotIndicatorVariantsSignal(SignalsDetectionInfo &bearish_potential_signals[])
{
  int  total_body_candle_ma_indicators  = ArraySize(ExtSignalBodyCandleMAIndicatorsHandle);
  int  total_filter_indicators          = ArraySize(ExtSignalFilterIndicatorsHandle);
  int  total_over_boughtsold_indicators = 0;
  int  total_signals                    = 0;
  int  current_indicator_period         = 0;
  int  current_indicator_handler        = INVALID_HANDLE;
  int  current_extra_indicator_handler  = INVALID_HANDLE;

  if(Robot_Indicator == ROBOT_RSI)   total_over_boughtsold_indicators = ArraySize(ExtSignalRSIIndicatorsHandle);
  if(Robot_Indicator == ROBOT_STOCH) total_over_boughtsold_indicators = ArraySize(ExtSignalStochIndicatorsHandle);

  for(int bb_i = 0; bb_i < total_filter_indicators; bb_i++)
  {
    SignalsDetectionInfo valid_signal_information;

    if(
      !CheckPatternsTrendSignal(
        BEARISH, Indicator_Signal_TF,
        ExtSignalStochIndicatorsHandle[0].indicator_handle,
        ExtSignalStochIndicatorsHandle[1].indicator_handle,
        ExtBPercentFilterIndicatorsHandle[0].indicator_handle,
        ExtBPercentFilterIndicatorsHandle[1].indicator_handle,
        ExtSignalStructStochIndicatorsHandle[0].indicator_handle,
        ExtSignalStructStochIndicatorsHandle[1].indicator_handle,
        ExtSignalFilterIndicatorsHandle[bb_i], valid_signal_information
      )
    ) continue;

    // PASSING, THEN STORE THE RSI/STOCH PERIOD
    valid_signal_information.over_boughtsold_period_signal = ExtSignalStochIndicatorsHandle[0].indicator_period;
    // PASSING, THEN STORE THE FILTER PERIOD
    valid_signal_information.bands_period_signal = ExtSignalFilterIndicatorsHandle[bb_i].indicator_period;

    // SET CANDLE PATTERN STATS
    //CheckCandlestickPatterns(BEARISH, Timeframe_Signal, ExtSignalBodyCandleMAIndicatorsHandle[0].indicator_handle, valid_signal_information);
    // SET SIGNAL STATISTIC
    //SetSignalStatisticData(BEARISH, valid_signal_information);

    // WIP: CHECK IN THE DATABASE IF THE PERIODS ARE HIGH WIN RATE
    // THEN ALL PASSING STORE THE SIGNAL INFORMATION IN THE ARRAY
    total_signals = AddElementToArray(bearish_potential_signals, valid_signal_information, 1000);
  }

  return total_signals > 0;
}

bool SignalIsTopEngine(int over_boughtsold_period_signal, int bands_period_signal, DBTopEngineStats &top_engine_stats)
{
  if(
    top_engine_stats.over_boughtsold_period_signal == over_boughtsold_period_signal &&
    top_engine_stats.bands_period_signal           == bands_period_signal
  ) return true;

  return false;
}

int GetSignalEntryHour()
{
  MqlDateTime time_info;
  datetime trend_timeframe = iTime(_Symbol, Timeframe_Fractal_Signal, 0);
  TimeToStruct(trend_timeframe, time_info);

  return time_info.hour;
}

int GetSignalEntryMinute()
{
  MqlDateTime time_info;
  datetime trend_timeframe = iTime(_Symbol, Timeframe_Signal, 0);
  TimeToStruct(trend_timeframe, time_info);

  return time_info.min;
}

bool HasOpenPosition()
{
  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    if(PositionGetTicket(i))
    {
      Print((int)PositionGetInteger(POSITION_MAGIC) ," == ", magic_number);
      if((int)PositionGetInteger(POSITION_MAGIC) == magic_number)
        return true;
    }
  }

  return false;
}

bool VerifyTriggerSignalEquityCurve(SignalParams &signal_params)
{
  // OPPOSITE TREND MEANS OVERBOUGHT-OVERSOLD STRATEGIES SO IT COULD BE AN EGDE, USING MA LIKE STOCH
  if(signal_params.signal_detected_info.trigger_signal_type == 2)
  {
    if(signal_params.equity_curve_trigger_2_in_trend == -1) return true;
    if(signal_params.equity_curve_trigger_2_in_trend == 1 && signal_params.trigger_2_ema_5_trend  == 1) return true;
    if(signal_params.equity_curve_trigger_2_in_trend == 2 && signal_params.trigger_2_ema_34_trend == 1) return true;
    if(signal_params.equity_curve_trigger_2_in_trend == 3 && signal_params.trigger_2_stoch_trend  == 1) return true;
  }
  if(signal_params.signal_detected_info.trigger_signal_type == 4)
  {
    if(signal_params.equity_curve_trigger_4_in_trend == -1) return true;
    if(signal_params.equity_curve_trigger_4_in_trend == 4 && signal_params.trigger_4_ema_5_trend  == 1) return true;
    if(signal_params.equity_curve_trigger_4_in_trend == 5 && signal_params.trigger_4_ema_34_trend == 1) return true;
    if(signal_params.equity_curve_trigger_4_in_trend == 6 && signal_params.trigger_4_stoch_trend  == 1) return true;
  }

  return false;
}

bool VerifyTradesSide(int direction)
{
  if(direction == BEARISH && Trades_Only_Side == Allow_Bearish_Positions) return true;
  if(direction == BULLISH && Trades_Only_Side == Allow_Bullish_Positions) return true;
  if(Trades_Only_Side == Allow_Both_Positions)                            return true;

  return false;
}

void SetSignalStatisticData(int direction, SignalsDetectionInfo &valid_signal_information, bool reentry = false)
{
  // SET IMBALANCE TREND STATS
  CheckTrendImbalanceTypePattern(direction, valid_signal_information);
  // SET BANDS TIMEFRAMES TREND STATS
  CheckTrendBandsTypePattern(direction, valid_signal_information);
  // SET DEEP STOCH STATS
  CheckDeepStochasticPattern(valid_signal_information);
  // SET STOCH TIMEFRAMES STATS
  CheckTrendStochasticPattern(valid_signal_information, reentry);
}

// ++++++++ CORE LOGIC ++++++++

bool CheckRobotAlgoSignal(int direction, int current_indicator_handler)
{
  if(Robot_Indicator == ROBOT_RSI)   return CheckRSIConfirmation(direction, current_indicator_handler);
  if(Robot_Indicator == ROBOT_STOCH) return CheckStochConfirmation(direction, current_indicator_handler);

  return false;
}

bool CheckFractalRobotAlgoSignal(int direction, ENUM_TIMEFRAMES fractal_timeframe, int current_indicator_handler)
{
  if(fractal_timeframe == PERIOD_CURRENT) return true;

  if(Robot_Indicator == ROBOT_RSI)   return CheckRSIConfirmation(direction, current_indicator_handler);
  if(Robot_Indicator == ROBOT_STOCH) return CheckStochConfirmation(direction, current_indicator_handler);

  return false;
}

void CheckDeepStochasticPattern(SignalsDetectionInfo &valid_signal_information)
{
  for(int i = 0; i <= 5; i++)
  {
    int deep_stoch_period = ExtDeepStochIndicatorsHandle[i].indicator_period;

    if(deep_stoch_period == 8)   valid_signal_information.stoch_8_pattern   = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
    if(deep_stoch_period == 13)  valid_signal_information.stoch_13_pattern  = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
    if(deep_stoch_period == 21)  valid_signal_information.stoch_21_pattern  = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
    if(deep_stoch_period == 34)  valid_signal_information.stoch_34_pattern  = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
    if(deep_stoch_period == 55)  valid_signal_information.stoch_55_pattern  = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
    if(deep_stoch_period == 89)  valid_signal_information.stoch_89_pattern  = CheckStochStateType(Timeframe_Signal, ExtDeepStochIndicatorsHandle[i].indicator_handle);
  }
}

void CheckTrendImbalanceTypePattern(int direction, SignalsDetectionInfo &valid_signal_information)
{
  if(direction == BULLISH)
  {
    valid_signal_information.trend_imb_m2_pattern  = CheckBullishImbalancesTrend(PERIOD_M2);
    valid_signal_information.trend_imb_m3_pattern  = CheckBullishImbalancesTrend(PERIOD_M3);
    valid_signal_information.trend_imb_m6_pattern  = CheckBullishImbalancesTrend(PERIOD_M6);
    valid_signal_information.trend_imb_m10_pattern = CheckBullishImbalancesTrend(PERIOD_M10);
    valid_signal_information.trend_imb_m15_pattern = CheckBullishImbalancesTrend(PERIOD_M15);
    valid_signal_information.trend_imb_m30_pattern = CheckBullishImbalancesTrend(PERIOD_M30);
    valid_signal_information.trend_imb_h1_pattern  = CheckBullishImbalancesTrend(PERIOD_H1);
    valid_signal_information.trend_imb_h2_pattern  = CheckBullishImbalancesTrend(PERIOD_H2);
    valid_signal_information.trend_imb_h4_pattern  = CheckBullishImbalancesTrend(PERIOD_H4);
  }
  if(direction == BEARISH)
  {
    valid_signal_information.trend_imb_m2_pattern  = CheckBearishImbalancesTrend(PERIOD_M2);
    valid_signal_information.trend_imb_m3_pattern  = CheckBearishImbalancesTrend(PERIOD_M3);
    valid_signal_information.trend_imb_m6_pattern  = CheckBearishImbalancesTrend(PERIOD_M6);
    valid_signal_information.trend_imb_m10_pattern = CheckBearishImbalancesTrend(PERIOD_M10);
    valid_signal_information.trend_imb_m15_pattern = CheckBearishImbalancesTrend(PERIOD_M15);
    valid_signal_information.trend_imb_m30_pattern = CheckBearishImbalancesTrend(PERIOD_M30);
    valid_signal_information.trend_imb_h1_pattern  = CheckBearishImbalancesTrend(PERIOD_H1);
    valid_signal_information.trend_imb_h2_pattern  = CheckBearishImbalancesTrend(PERIOD_H2);
    valid_signal_information.trend_imb_h4_pattern  = CheckBearishImbalancesTrend(PERIOD_H4);
  }
}

void CheckTrendBandsTypePattern(int direction, SignalsDetectionInfo &valid_signal_information)
{
  valid_signal_information.bands_pattern           = CheckBandsStateType(direction, Timeframe_Confirmation);
  valid_signal_information.trend_bands_pattern     = CheckBandsStateType(direction, Timeframe_Trend);
  valid_signal_information.trend_bands_m10_pattern = CheckBandsStateType(direction, PERIOD_M10);
  valid_signal_information.trend_bands_m15_pattern = CheckBandsStateType(direction, PERIOD_M15);
  valid_signal_information.trend_bands_m30_pattern = CheckBandsStateType(direction, PERIOD_M30);
  valid_signal_information.trend_bands_h1_pattern  = CheckBandsStateType(direction, PERIOD_H1);
  valid_signal_information.trend_bands_h2_pattern  = CheckBandsStateType(direction, PERIOD_H2);
  valid_signal_information.trend_bands_h4_pattern  = CheckBandsStateType(direction, PERIOD_H4);
}

void CheckTrendMACDTypePattern(SignalsDetectionInfo &valid_signal_information)
{
  valid_signal_information.macd_awesome_pattern       = CheckAOStateType(Timeframe_Confirmation);
  valid_signal_information.trend_macd_awesome_pattern = CheckAOStateType(Timeframe_Trend);
  valid_signal_information.trend_macd_m10_pattern     = CheckAOStateType(PERIOD_M10);
  valid_signal_information.trend_macd_m15_pattern     = CheckAOStateType(PERIOD_M15);
  valid_signal_information.trend_macd_m30_pattern     = CheckAOStateType(PERIOD_M30);
  valid_signal_information.trend_macd_h1_pattern      = CheckAOStateType(PERIOD_H1);
  valid_signal_information.trend_macd_h2_pattern      = CheckAOStateType(PERIOD_H2);
  valid_signal_information.trend_macd_h4_pattern      = CheckAOStateType(PERIOD_H4);
}

void CheckTrendStochasticPattern(SignalsDetectionInfo &valid_signal_information, bool reentry)
{
  valid_signal_information.stoch_pattern           = CheckStochStateType(Timeframe_Confirmation, -1, reentry);
  valid_signal_information.trend_stoch_pattern     = CheckStochStateType(Timeframe_Trend, -1, reentry);
  valid_signal_information.trend_stoch_m10_pattern = CheckStochStateType(PERIOD_M10, -1, reentry);
  valid_signal_information.trend_stoch_m15_pattern = CheckStochStateType(PERIOD_M15, -1, reentry);
  valid_signal_information.trend_stoch_m30_pattern = CheckStochStateType(PERIOD_M30, -1, reentry);
  valid_signal_information.trend_stoch_h1_pattern  = CheckStochStateType(PERIOD_H1, -1, reentry);
  valid_signal_information.trend_stoch_h2_pattern  = CheckStochStateType(PERIOD_H2, -1, reentry);
  valid_signal_information.trend_stoch_h4_pattern  = CheckStochStateType(PERIOD_H4, -1, reentry);
}

void CheckOscillatorTrendPatterns(int direction, SignalsDetectionInfo &valid_signal_information, bool reentry)
{
}

int CheckBandsStateType(int direction, ENUM_TIMEFRAMES timeframe)
{
  int    indicator_bands_handle = 0;
  double indicator_upper_values[];
  double indicator_ma_values[];
  double indicator_lower_values[];

  //if(timeframe == Timeframe_Confirmation) indicator_bands_handle = ExtBandsConfirmationContextIndicatorHandle.indicator_handle;
  //if(timeframe == Timeframe_Trend)        indicator_bands_handle = ExtBandsTrendContextIndicatorHandle.indicator_handle;

  if(timeframe == Timeframe_Confirmation)                               indicator_bands_handle = ExtBandsConfirmationContextIndicatorHandle.indicator_handle;
  if(timeframe == Timeframe_Trend)                                      indicator_bands_handle = ExtBandsTrendContextIndicatorHandle.indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[0].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[0].indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[1].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[1].indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[2].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[2].indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[3].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[3].indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[4].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[4].indicator_handle;
  if(timeframe == ExtTrendBandsIndicatorsHandle[5].indicator_timeframe) indicator_bands_handle = ExtTrendBandsIndicatorsHandle[5].indicator_handle;

  // MACD VALUES
  int total_upper_values = CopyBuffer(indicator_bands_handle, 0, 0, 5, indicator_upper_values);
  int total_ma_values    = CopyBuffer(indicator_bands_handle, 1, 0, 5, indicator_ma_values);
  int total_lower_values = CopyBuffer(indicator_bands_handle, 2, 0, 5, indicator_lower_values);

  ArraySetAsSeries(indicator_upper_values, true);
  ArraySetAsSeries(indicator_ma_values, true);
  ArraySetAsSeries(indicator_lower_values, true);

  if(total_upper_values <= 0 && total_ma_values <= 0 && total_lower_values <= 0)
  {
    PrintFormat("Failed to copy data from the Bands indicator, error code %d", GetLastError());
    TesterStop();
  }

  int    bands_trend_type_1 = -1;
  int    bands_trend_type_0 = -1;
  double close_1 = iClose(_Symbol, timeframe, 1);
  double low_0   = iLow(_Symbol, timeframe, 0);
  double high_0  = iHigh(_Symbol, timeframe, 0);

  // BANDS TREND TYPE
  if(close_1 >= indicator_upper_values[1])                                        bands_trend_type_1 = 1; // BANDS POSITIVE UPTREND
  if(close_1 >= indicator_ma_values[1]    && close_1 < indicator_upper_values[1]) bands_trend_type_1 = 2; // BANDS NEGATIVE UPTREND
  if(close_1 >  indicator_lower_values[1] && close_1 < indicator_ma_values[1])    bands_trend_type_1 = 3; // BANDS POSITIVE DOWNTREND
  if(close_1 <= indicator_lower_values[1])                                        bands_trend_type_1 = 4; // BANDS NEGATIVE DOWNTREND

  // BANDS BULLISH LOWS TYPE
  if(direction == BULLISH && low_0 >= indicator_upper_values[0])                                      bands_trend_type_0 = 1; // BANDS POSITIVE UPTREND
  if(direction == BULLISH && low_0 >= indicator_ma_values[0]    && low_0 < indicator_upper_values[0]) bands_trend_type_0 = 2; // BANDS NEGATIVE UPTREND
  if(direction == BULLISH && low_0 >  indicator_lower_values[0] && low_0 < indicator_ma_values[0])    bands_trend_type_0 = 3; // BANDS POSITIVE DOWNTREND
  if(direction == BULLISH && low_0 <= indicator_lower_values[0])                                      bands_trend_type_0 = 4; // BANDS NEGATIVE DOWNTREND

  // BANDS BEARISH HIGHS TYPE
  if(direction == BEARISH && high_0 >= indicator_upper_values[0])                                       bands_trend_type_0 = 1; // BANDS POSITIVE UPTREND
  if(direction == BEARISH && high_0 >= indicator_ma_values[0]    && high_0 < indicator_upper_values[0]) bands_trend_type_0 = 2; // BANDS NEGATIVE UPTREND
  if(direction == BEARISH && high_0 >  indicator_lower_values[0] && high_0 < indicator_ma_values[0])    bands_trend_type_0 = 3; // BANDS POSITIVE DOWNTREND
  if(direction == BEARISH && high_0 <= indicator_lower_values[0])                                       bands_trend_type_0 = 4; // BANDS NEGATIVE DOWNTREND

  return (int)GenerateMACDSetupID(bands_trend_type_1);
}

int CheckStochStateType(ENUM_TIMEFRAMES timeframe, int indicator_stoch_handle = -1, bool reentry = false)
{
  double indicator_main_values[];
  double indicator_signal_values[];
  int    indicator_trend_handle = indicator_stoch_handle;

  if(indicator_stoch_handle == -1 && timeframe == Timeframe_Confirmation)                               indicator_trend_handle = ExtStochConfirmationContextIndicatorHandle.indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == Timeframe_Trend)                                      indicator_trend_handle = ExtStochTrendContextIndicatorHandle.indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[0].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[0].indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[1].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[1].indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[2].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[2].indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[3].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[3].indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[4].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[4].indicator_handle;
  if(indicator_stoch_handle == -1 && timeframe == ExtTrendStochIndicatorsHandle[5].indicator_timeframe) indicator_trend_handle = ExtTrendStochIndicatorsHandle[5].indicator_handle;

  // STOCH VALUES
  int total_main_values   = CopyBuffer(indicator_trend_handle, MAIN_LINE, 0, 5, indicator_main_values);
  int total_signal_values = CopyBuffer(indicator_trend_handle, SIGNAL_LINE, 0, 5, indicator_signal_values);

  ArraySetAsSeries(indicator_main_values, true);
  ArraySetAsSeries(indicator_signal_values, true);

  if(total_main_values <= 0 && total_signal_values <= 0)
  {
    PrintFormat("Failed to copy data from the Stoch indicator, error code %d", GetLastError());
    TesterStop();
  }

  int stoch_index        = reentry ? 0 : 1;
  int stoch_trend_type_1 = -1;
  int stoch_main_type_1  = 0;

  // STOCH TREND TYPE
  if(indicator_main_values[stoch_index] >= 80)                                            stoch_trend_type_1 = 1; // MACD POSITIVE UPTREND
  if(indicator_main_values[stoch_index] >= 50 && indicator_main_values[stoch_index] < 80) stoch_trend_type_1 = 2; // MACD NEGATIVE UPTREND
  if(indicator_main_values[stoch_index] <= 50 && indicator_main_values[stoch_index] > 20) stoch_trend_type_1 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_main_values[stoch_index] <= 20)                                            stoch_trend_type_1 = 4; // MACD NEGATIVE DOWNTREND

  // STOCH MAIN TYPE
  if(indicator_main_values[stoch_index] > indicator_signal_values[stoch_index])            stoch_main_type_1 = 1; // MACD NEGATIVE DOWNTREND
  if(indicator_main_values[stoch_index] < indicator_signal_values[stoch_index])            stoch_main_type_1 = 2; // MACD NEGATIVE DOWNTREND

  return (int)GenerateMACDSetupID(stoch_trend_type_1);
}

int CheckAOStateType(ENUM_TIMEFRAMES timeframe)
{
  int    indicator_trend_handle = 0;
  double indicator_values[];
  double color_indicator_values[];

  if(timeframe == Timeframe_Confirmation)                              indicator_trend_handle = ExtMACDConfirmationContextIndicatorHandle.indicator_handle;
  if(timeframe == Timeframe_Trend)                                     indicator_trend_handle = ExtMACDTrendContextIndicatorHandle.indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[0].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[0].indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[1].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[1].indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[2].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[2].indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[3].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[3].indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[4].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[4].indicator_handle;
  if(timeframe == ExtTrendMacdIndicatorsHandle[5].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[5].indicator_handle;

  // MACD VALUES
  int total_values    = CopyBuffer(indicator_trend_handle, 0, 0, 5, indicator_values);
  int total_ma_values = CopyBuffer(indicator_trend_handle, 1, 0, 5, color_indicator_values);

  ArraySetAsSeries(indicator_values, true);
  ArraySetAsSeries(color_indicator_values, true);

  if(total_values <= 0 && total_ma_values <= 0)
  {
    PrintFormat("Failed to copy data from the AO indicator, error code %d", GetLastError());
    TesterStop();
  }

  int macd_trend_type_1 = -1;
  int macd_trend_type_2 = -1;

  if(indicator_values[1] >= 0 && color_indicator_values[1] == 1.0) macd_trend_type_1 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[1] >= 0 && color_indicator_values[1] == 2.0) macd_trend_type_1 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[1]  < 0 && color_indicator_values[1] == 1.0) macd_trend_type_1 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[1]  < 0 && color_indicator_values[1] == 2.0) macd_trend_type_1 = 4; // MACD NEGATIVE DOWNTREND

  if(indicator_values[2] >= 0 && color_indicator_values[2] == 1.0) macd_trend_type_2 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[2] >= 0 && color_indicator_values[2] == 2.0) macd_trend_type_2 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[2]  < 0 && color_indicator_values[2] == 1.0) macd_trend_type_2 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[2]  < 0 && color_indicator_values[2] == 2.0) macd_trend_type_2 = 4; // MACD NEGATIVE DOWNTREND

  return (int)GenerateMACDSetupID(macd_trend_type_1);
}

int CheckMACDStateType(ENUM_TIMEFRAMES trend_timeframe)
{
  int    indicator_trend_handle = 0;
  double indicator_values[];
  double signal_indicator_values[];

  if(trend_timeframe == Timeframe_Confirmation)                              indicator_trend_handle = ExtMACDConfirmationContextIndicatorHandle.indicator_handle;
  if(trend_timeframe == Timeframe_Trend)                                     indicator_trend_handle = ExtMACDTrendContextIndicatorHandle.indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[0].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[0].indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[1].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[1].indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[2].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[2].indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[3].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[3].indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[4].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[4].indicator_handle;
  if(trend_timeframe == ExtTrendMacdIndicatorsHandle[5].indicator_timeframe) indicator_trend_handle = ExtTrendMacdIndicatorsHandle[5].indicator_handle;

  // MACD VALUES
  int total_values    = CopyBuffer(indicator_trend_handle, 0, 0, 5, indicator_values);
  int total_ma_values = CopyBuffer(indicator_trend_handle, 2, 0, 5, signal_indicator_values);

  ArraySetAsSeries(indicator_values, true);
  ArraySetAsSeries(signal_indicator_values, true);

  if(total_values <= 0 && total_ma_values <= 0)
  {
    PrintFormat("Failed to copy data from the AO indicator, error code %d", GetLastError());
    TesterStop();
  }

  int macd_trend_type_1 = -1;

  // MACD TREND TYPE
  if(indicator_values[1] > 0 && indicator_values[1] >= signal_indicator_values[1]) macd_trend_type_1 = 1; // MACD POSITIVE UPTREND
  if(indicator_values[1] > 0 && indicator_values[1]  < signal_indicator_values[1]) macd_trend_type_1 = 2; // MACD NEGATIVE UPTREND
  if(indicator_values[1] < 0 && indicator_values[1]  > signal_indicator_values[1]) macd_trend_type_1 = 3; // MACD POSITIVE DOWNTREND
  if(indicator_values[1] < 0 && indicator_values[1] <= signal_indicator_values[1]) macd_trend_type_1 = 4; // MACD NEGATIVE DOWNTREND

  return (int)GenerateMACDSetupID(macd_trend_type_1);
}

// ++++++++ SETTING RISK MANAGMENT ++++++++

bool SetPositionRiskManagment(ENUM_TIMEFRAMES timeframe, int direction, SignalParams &signal_params, int struct_indicator_handle)
{
  bool   valid_SL                  = false;
  double open_price                = 0;
  double stop_loss                 = 0;
  double ratio_fibo_tp             = 0;
  double custom_step_size_points   = 0;
  double custom_step_size_decimals = 0;
  double take_profit               = 0;
  double tp_points                 = 0;
  double custom_sl_points          = 0;
  double freeze_stop_points        = (m_symbol.StopsLevel() + m_symbol.FreezeLevel());

  if(direction == BULLISH)
  {
    open_price = NormalizeDouble(Ask, _Digits);

    valid_SL = CalculateBasedBullishSL(timeframe, open_price, take_profit, stop_loss, custom_sl_points, signal_params, struct_indicator_handle);

    signal_params.position_open_price       = open_price;
    signal_params.position_sl               = stop_loss;
    signal_params.position_tp               = take_profit;
    signal_params.position_grid_points      = custom_sl_points;
    signal_params.grid_start_price          = open_price;
    signal_params.grid_account_balance      = AccountInfoDouble(ACCOUNT_BALANCE);
  }
  if(direction == BEARISH)
  {
    open_price = NormalizeDouble(Bid, _Digits);

    valid_SL = CalculateBasedBearishSL(timeframe, open_price, take_profit, stop_loss, custom_sl_points, signal_params, struct_indicator_handle);

    signal_params.position_open_price      = open_price;
    signal_params.position_sl              = stop_loss;
    signal_params.position_tp              = take_profit;
    signal_params.position_grid_points     = custom_sl_points;
    signal_params.grid_start_price         = open_price;
    signal_params.grid_account_balance     = AccountInfoDouble(ACCOUNT_BALANCE);
  }

  return valid_SL;
}

// AO SL Risk Based

bool CalculateBasedBullishSL(ENUM_TIMEFRAMES timeframe, double &open_price_ask, double &take_profit, double &stop_loss, double &custom_sl_points, SignalParams &signal_params, int struct_indicator_handle)
{
  // BID CLOSES SL FOR BUYS
  open_price_ask             = NormalizeDouble(Ask, _Digits);
  double open_price_bid      = NormalizeDouble(Bid, _Digits);
  double atr_factor_1        = GetATRFactorLowerPrice(0, ExtSignalATRFactorIndicatorsHandle[0].indicator_handle);
  double points_indicator_sl = (open_price_ask-atr_factor_1)*decimal_digits;

  if(points_indicator_sl >= Min_Range_Points && points_indicator_sl > Points_Spread)
  {
    take_profit  = NormalizeDouble(open_price_ask+((points_indicator_sl/decimal_digits)*1.0), _Digits); // BUYS CLOSES ON BID FOR TP
    stop_loss    = NormalizeDouble(open_price_ask-((points_indicator_sl/decimal_digits)*1.0), _Digits); // TIGHT SL DUE TO CLOSE ON BID
    custom_sl_points = points_indicator_sl;

    return true;
  }

  return false;
}

bool CalculateBasedBearishSL(ENUM_TIMEFRAMES timeframe, double &open_price_bid, double &take_profit, double &stop_loss, double &custom_sl_points, SignalParams &signal_params, int struct_indicator_handle)
{
  // ASK CLOSE SL FOR SELLS
  open_price_bid             = NormalizeDouble(Bid, _Digits);
  double open_price_ask      = NormalizeDouble(Ask, _Digits);
  double atr_factor_1        = GetATRFactorUpperPrice(0, ExtSignalATRFactorIndicatorsHandle[0].indicator_handle);
  double points_indicator_sl = (atr_factor_1-open_price_bid)*decimal_digits;

  if(points_indicator_sl >= Min_Range_Points && points_indicator_sl > Points_Spread)
  {
    take_profit  = NormalizeDouble(open_price_bid-((points_indicator_sl/decimal_digits)*1.0), _Digits); // SELLS CLOSES ON ASK FOR TP
    stop_loss    = NormalizeDouble(open_price_bid+((points_indicator_sl/decimal_digits)*1.0), _Digits); // TIGHT SL DUE TO CLOSE ON ASK
    custom_sl_points = points_indicator_sl;

    return true;
  }

  return false;
}

// ++ SESSION SIGNAL TYPE ++

SignalSessionType GetEntrySessionType(datetime entry_signal_time)
{
  MqlDateTime signal_day_struct;
  TimeToStruct(entry_signal_time, signal_day_struct);

  // SESSIONS BY CONTINENT/BROKER
  if(signal_day_struct.hour >= 21 && signal_day_struct.hour <=  24) return ASIA_SESSION;
  if(signal_day_struct.hour >= 0  && signal_day_struct.hour <=  4)  return ASIA_SESSION;
  if(signal_day_struct.hour >= 5  && signal_day_struct.hour <= 11)  return LONDON_SESSION;
  if(signal_day_struct.hour >= 12 && signal_day_struct.hour <= 20)  return NEW_YORK_SESSION;

  // SESSIONS BY TRADING VOLUME
  //if(signal_day_struct.hour >= 8  && signal_day_struct.hour <= 20) return HIGH_VOLUME_SESSION;
  //if(signal_day_struct.hour >= 21 && signal_day_struct.hour <= 24) return LOW_VOLUME_SESSION;
  //if(signal_day_struct.hour >= 0  && signal_day_struct.hour <= 7)  return LOW_VOLUME_SESSION;

  return FREE_SESSION;
}

// ++++++++ LOADING INDICATORS/DATA ++++++++

// ++ SIGNAL ENGINE TIMEFRAME ++
IndicatorsHandleInfo ExtSignalBodyCandleMAIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalRealCandleMAIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalATRFactorIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalBBATRVolumeIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalFilterIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalRSIIndicatorsHandle[];
IndicatorsHandleInfo ExtSignalStochIndicatorsHandle[];
IndicatorsHandleInfo ExtBPercentFilterIndicatorsHandle[];
// CONFIRMATION HANDLES TIMEFRAME
IndicatorsHandleInfo ExtMACDConfirmationContextIndicatorHandle;
IndicatorsHandleInfo ExtBandsConfirmationContextIndicatorHandle;
IndicatorsHandleInfo ExtStochConfirmationContextIndicatorHandle;
// TREND HANDLES TIMEFRAME
IndicatorsHandleInfo ExtMACDTrendContextIndicatorHandle;
IndicatorsHandleInfo ExtBandsTrendContextIndicatorHandle;
IndicatorsHandleInfo ExtStochTrendContextIndicatorHandle;
// TREND FIBONACCI HANDLE
IndicatorsHandleInfo ExtSignalStructStochIndicatorsHandle[];
// DEEP STOCH HANDLE
IndicatorsHandleInfo ExtDeepStochIndicatorsHandle[];
// TREND MACD HANDLE
IndicatorsHandleInfo ExtTrendMacdIndicatorsHandle[];
// TREND BANDS HANDLE
IndicatorsHandleInfo ExtTrendBandsIndicatorsHandle[];
// TREND STOCH HANDLE
IndicatorsHandleInfo ExtTrendStochIndicatorsHandle[];

void LoadFeeRobotsIndicatorDefinitions()
{
  // HIDE INDICATORS VARIANTS
  TesterHideIndicators(Hide_Indicator_Variants);

  LoadATRFactorVariantIndicator();
  LoadBPercentVariantIndicator(Indicator_Signal_TF);
  LoadAllIndicatorFilterVariantIndicators();
  LoadAllStochVariantIndicators(Indicator_Signal_TF);
  LoadAllStochStructureIndicators(Indicator_Signal_TF);

  // TF CONFIRMATIONS
  LoadBPercentVariantIndicator(Indicator_Filter_TF, Indicator_Filter_Price);
  LoadAllStochVariantIndicators(Indicator_Filter_TF, true);
  LoadAllStochStructureIndicators(Indicator_Filter_TF, true);
}

// ++ LOAD ALL INDICATORS VARIANTS FUNCTIONS ++

int FibonacciIndicatorPeriods[8] = {3, 5, 8, 13, 21, 34, 55, 89};

void LoadAllBodyCandleMAVariantIndicators()
{
  IndicatorsHandleInfo indicator_handle_loaded;
  int             fibonacci_period = 0;
  ENUM_TIMEFRAMES timeframe_setup  = Indicator_Signal_TF;

  // FROM 5 to 5
  for(int i = 1; i <= 1; i++)
  {
    fibonacci_period                                        = FibonacciIndicatorPeriods[i];
    indicator_handle_loaded.indicator_type                  = CANDLE_BODY_MA;
    indicator_handle_loaded.indicator_handle                = iCustom(_Symbol, timeframe_setup, "Examples\\Body_MA.ex5", fibonacci_period, 0);
    indicator_handle_loaded.indicator_period                = fibonacci_period;
    indicator_handle_loaded.indicator_timeframe             = timeframe_setup;

    if(indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING CANDLE BODY MA INDICATOR PERIOD: ", fibonacci_period);
      TesterStop();
      break;
    }

    Print("LOADED CANDLE BODY MA INDICATOR SUCCESFULLY PERIOD: ", fibonacci_period);

    AddElementToArray(ExtSignalBodyCandleMAIndicatorsHandle, indicator_handle_loaded);
  }
}

void LoadAllRealCandleMAVariantIndicators()
{
  IndicatorsHandleInfo indicator_handle_loaded;
  int             fibonacci_period = 0;
  ENUM_TIMEFRAMES timeframe_setup  = PERIOD_CURRENT;

  // FROM 5 to 5
  for(int i = 1; i <= 1; i++)
  {
    fibonacci_period                                        = FibonacciIndicatorPeriods[i];
    indicator_handle_loaded.indicator_type                  = CANDLE_BODY_MA;
    indicator_handle_loaded.indicator_handle                = iCustom(_Symbol, PERIOD_M1, "Examples\\Real_Candle_MA.ex5", fibonacci_period, 0);
    indicator_handle_loaded.indicator_period                = fibonacci_period;
    indicator_handle_loaded.indicator_timeframe             = PERIOD_M1;

    if(indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING CANDLE REAL MA INDICATOR PERIOD: ", fibonacci_period);
      TesterStop();
      break;
    }

    Print("LOADED CANDLE REAL MA INDICATOR SUCCESFULLY PERIOD: ", fibonacci_period);

    AddElementToArray(ExtSignalRealCandleMAIndicatorsHandle, indicator_handle_loaded);
  }
}

void LoadATRFactorVariantIndicator()
{
  IndicatorsHandleInfo indicator_handle_loaded;
  int             fibonacci_period = 0;
  ENUM_TIMEFRAMES timeframe_setup  = Indicator_Signal_TF;

  // FROM 5 to 5
  for(int i = 1; i <= 1; i++)
  {
    fibonacci_period                            = FibonacciIndicatorPeriods[i];
    indicator_handle_loaded.indicator_type      = ATR_FACTOR;
    indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, timeframe_setup, "Examples\\ATR_SL_Factor.ex5", fibonacci_period, Indicator_True_Factor);
    indicator_handle_loaded.indicator_period    = fibonacci_period;
    indicator_handle_loaded.indicator_timeframe = timeframe_setup;

    if(indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING ATR FACTOR INDICATOR PERIOD: ", fibonacci_period);
      TesterStop();
      break;
    }

    Print("LOADED ATR FACTOR INDICATOR SUCCESFULLY PERIOD: ", fibonacci_period);

    AddElementToArray(ExtSignalATRFactorIndicatorsHandle, indicator_handle_loaded);
  }
}

void LoadAllStochStructureIndicators(ENUM_TIMEFRAMES timeframe_setup = PERIOD_M1, bool trend_struct = false)
{
  IndicatorsHandleInfo stoch_indicator_handle_loaded;
  int periods_start = 0;
  int periods_end   = 0;
  GetStructFilterTypePeriod(periods_start, periods_end, trend_struct);
  int stoch_d       = FibonacciIndicatorPeriods[periods_start];
  int stoch_slowing = 3;

  stoch_indicator_handle_loaded.indicator_type      = STOCHASTIC_STRUCT;
  stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, timeframe_setup, "Examples\\Stochastic_Structure.ex5", stoch_d, 3, stoch_slowing, STO_CLOSECLOSE);
  stoch_indicator_handle_loaded.indicator_timeframe = timeframe_setup;

  if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
  {
    Print("ERROR LOADING STOCH STRUCTURE INDICATOR PERIOD: ", EnumToString(timeframe_setup));
    TesterStop();
  }

  Print("LOADED STOCH STRUCTURE INDICATORS SUCCESFULLY PERIOD: ", EnumToString(timeframe_setup));

  AddElementToArray(ExtSignalStructStochIndicatorsHandle, stoch_indicator_handle_loaded);
}

void LoadAllIndicatorFilterVariantIndicators()
{
  IndicatorsHandleInfo indicator_handle_loaded;
  IndicatorsHandleInfo indicator_stoch_struct_handle;
  ENUM_APPLIED_PRICE price_types[7]   = {PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED};
  ENUM_MA_METHOD     ma_types[4]      = {MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA};
  int                bands_shifts[4]  = {0, 3, 5, 8};
  int                filter_periods   = 5;
  int                macd_fast_period = 3;
  int                periods_start    = 0;
  int                periods_end      = 0;
  ENUM_TIMEFRAMES    timeframe_setup  = Indicator_Signal_TF;
  GetFilterTypePeriod(periods_start, periods_end);
  filter_periods = FibonacciIndicatorPeriods[periods_start];

  indicator_handle_loaded.indicator_ma_method     = Indicator_Filter_Type;
  indicator_handle_loaded.indicator_applied_price = Indicator_Filter_Price;
  indicator_handle_loaded.indicator_shift         = 0;//bands_shifts[shift_i];
  indicator_handle_loaded.indicator_handle        = iCustom(_Symbol, timeframe_setup, "Examples\\BB_Standard.ex5", filter_periods, indicator_handle_loaded.indicator_shift, 2.0, indicator_handle_loaded.indicator_ma_method, indicator_handle_loaded.indicator_applied_price);
  indicator_handle_loaded.indicator_period        = (int)GenerateFilterSetupID(filter_periods, int(indicator_handle_loaded.indicator_ma_method+1), indicator_handle_loaded.indicator_applied_price, indicator_handle_loaded.indicator_shift);
  indicator_handle_loaded.indicator_timeframe     = timeframe_setup;

  if(
    indicator_handle_loaded.indicator_handle == INVALID_HANDLE
  ) {
    Print("ERROR LOADING ENGINE INDICATOR PERIOD: ", indicator_handle_loaded.indicator_period);
    TesterStop();
  }

  Print("LOADED [ENGINE] INDICATOR SUCCESFULLY PERIOD: ", indicator_handle_loaded.indicator_period);

  AddElementToArray(ExtSignalFilterIndicatorsHandle, indicator_handle_loaded);
}

void LoadBPercentVariantIndicator(ENUM_TIMEFRAMES timeframe_setup = PERIOD_M1, ENUM_APPLIED_PRICE k_price_type = PRICE_CLOSE)
{
  IndicatorsHandleInfo indicator_handle_loaded;
  IndicatorsHandleInfo indicator_stoch_struct_handle;
  ENUM_APPLIED_PRICE price_types[7]   = {PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED};
  ENUM_MA_METHOD     ma_types[4]      = {MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA};
  int                bands_shifts[4]  = {0, 3, 5, 8};
  int                filter_periods   = 5;
  int                macd_fast_period = 3;
  int                periods_start    = 0;
  int                periods_end      = 0;
  GetFilterTypePeriod(periods_start, periods_end);
  filter_periods = FibonacciIndicatorPeriods[periods_start];

  indicator_handle_loaded.indicator_ma_method     = Indicator_Filter_Type;
  indicator_handle_loaded.indicator_applied_price = Indicator_Filter_Price;
  indicator_handle_loaded.indicator_shift         = 0;//bands_shifts[shift_i];
  indicator_handle_loaded.indicator_handle        = iCustom(_Symbol, timeframe_setup, "Examples\\BB_Percent_Standard.ex5", indicator_handle_loaded.indicator_shift, filter_periods, 5, 2.0, indicator_handle_loaded.indicator_ma_method, k_price_type, indicator_handle_loaded.indicator_applied_price);
  indicator_handle_loaded.indicator_period        = (int)GenerateFilterSetupID(filter_periods, int(indicator_handle_loaded.indicator_ma_method+1), indicator_handle_loaded.indicator_applied_price, indicator_handle_loaded.indicator_shift);
  indicator_handle_loaded.indicator_timeframe     = timeframe_setup;

  if(
    indicator_handle_loaded.indicator_handle == INVALID_HANDLE
  ) {
    Print("ERROR LOADING ENGINE % INDICATOR PERIOD: ", indicator_handle_loaded.indicator_period);
    TesterStop();
  }

  Print("LOADED [ENGINE %] INDICATOR SUCCESFULLY PERIOD: ", indicator_handle_loaded.indicator_period);

  AddElementToArray(ExtBPercentFilterIndicatorsHandle, indicator_handle_loaded);
}

void LoadAllTrendBandsIndicators()
{
  ENUM_TIMEFRAMES trend_timeframes[6] = {PERIOD_M10, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H4};

  for(int i = 0; i < 6; i++)
  {
    ENUM_TIMEFRAMES trend_timeframe = trend_timeframes[i];
    IndicatorsHandleInfo stoch_indicator_handle_loaded;

    stoch_indicator_handle_loaded.indicator_type      = BOLINGER_BANDS;
    stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\BB_Standard.ex5", 21, 0, 2.0, MODE_EMA, PRICE_MEDIAN);
    stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING TREND BANDS INDICATOR PERIOD: ", EnumToString(trend_timeframe));
      TesterStop();
      break;
    }

    Print("LOADED TREND BANDS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe));

    AddElementToArray(ExtTrendBandsIndicatorsHandle, stoch_indicator_handle_loaded);
  }
}

void LoadAllTrendStochIndicators()
{
  ENUM_TIMEFRAMES trend_timeframes[6] = {PERIOD_M10, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H4};

  for(int i = 0; i < 6; i++)
  {
    ENUM_TIMEFRAMES trend_timeframe = trend_timeframes[i];
    IndicatorsHandleInfo stoch_indicator_handle_loaded;

    stoch_indicator_handle_loaded.indicator_type      = BOLINGER_BANDS;
    stoch_indicator_handle_loaded.indicator_handle    = iCustom(_Symbol, trend_timeframe, "Examples\\Stochastic", 5, 3, 3, STO_CLOSECLOSE);
    stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING TREND STOCHS INDICATOR PERIOD: ", EnumToString(trend_timeframe));
      TesterStop();
      break;
    }

    Print("LOADED TREND STOCHS INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe));

    AddElementToArray(ExtTrendStochIndicatorsHandle, stoch_indicator_handle_loaded);
  }
}

void LoadAllTrendMACDIndicators()
{
  ENUM_TIMEFRAMES trend_timeframes[6] = {PERIOD_M10, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H4};

  for(int i = 0; i < 6; i++)
  {
    ENUM_TIMEFRAMES trend_timeframe = trend_timeframes[i];
    IndicatorsHandleInfo stoch_indicator_handle_loaded;

    stoch_indicator_handle_loaded.indicator_type      = MACD;
    stoch_indicator_handle_loaded.indicator_handle = iCustom(_Symbol, trend_timeframe, "Examples\\MACD_Standard.ex5", 5, 34, 8, PRICE_MEDIAN, MODE_SMA);
    //if(Indicator_Trend_Filter_Type == MACD_SIGNAL_TYPE)        stoch_indicator_handle_loaded.indicator_handle = iCustom(_Symbol, trend_timeframe, "Examples\\MACD_Standard.ex5", 5, 34, 8, PRICE_MEDIAN, MODE_EMA);
    stoch_indicator_handle_loaded.indicator_timeframe = trend_timeframe;

    if(stoch_indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING MACD INDICATOR PERIOD: ", EnumToString(trend_timeframe));
      TesterStop();
      break;
    }

    Print("LOADED MACD INDICATORS SUCCESFULLY PERIOD: ", EnumToString(trend_timeframe));

    AddElementToArray(ExtTrendMacdIndicatorsHandle, stoch_indicator_handle_loaded);
  }
}

void LoadAllRSIVariantIndicators()
{
  IndicatorsHandleInfo indicator_handle_loaded;

  for(int i = 0; i <= 6; i++)
  {
    int fibonacci_period = FibonacciIndicatorPeriods[i];
    indicator_handle_loaded.indicator_type   = RELATIVE_STRENGTH_INDEX;
    indicator_handle_loaded.indicator_handle = iRSI(_Symbol, Timeframe_Signal, fibonacci_period, PRICE_MEDIAN);
    indicator_handle_loaded.indicator_period = fibonacci_period;

    if(indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING RSI INDICATOR PERIOD: ", fibonacci_period);
      TesterStop();
      break;
    }

    Print("LOADED RSI INDICATOR SUCCESFULLY PERIOD: ", fibonacci_period);

    AddElementToArray(ExtSignalRSIIndicatorsHandle, indicator_handle_loaded);
  }
}

void LoadAllStochVariantIndicators(ENUM_TIMEFRAMES timeframe_setup = PERIOD_M1, bool trend_struct = false)
{
  IndicatorsHandleInfo indicator_handle_loaded;

  // FROM 5 to 5
  for(int i = 1; i <= 1; i++)
  {
    int periods_start = 0;
    int periods_end   = 0;
    GetStructFilterTypePeriod(periods_start, periods_end, trend_struct);
    int stoch_d       = FibonacciIndicatorPeriods[periods_start];
    int stoch_slowing = 3;

    indicator_handle_loaded.indicator_type                  = STOCHASTIC;
    indicator_handle_loaded.indicator_handle                = iCustom(_Symbol, timeframe_setup, "Examples\\Stochastic", stoch_d, 3, stoch_slowing, STO_CLOSECLOSE);
    indicator_handle_loaded.indicator_period                = stoch_d;
    indicator_handle_loaded.indicator_timeframe             = timeframe_setup;

    if(indicator_handle_loaded.indicator_handle == INVALID_HANDLE)
    {
      Print("ERROR LOADING STOCHASTIC INDICATOR PERIOD: ", stoch_d);
      TesterStop();
      break;
    }

    Print("LOADED STOCHASTIC INDICATORS SUCCESFULLY PERIOD: ", stoch_d);

    AddElementToArray(ExtSignalStochIndicatorsHandle, indicator_handle_loaded);
  }
}

ENUM_TIMEFRAMES GetAOTrendTF(ENUM_TIMEFRAMES signal_timeframe)
{
  // 1ST TIMEFRAMES FRACTAL
  if(signal_timeframe == PERIOD_M1)  return PERIOD_M3;
  if(signal_timeframe == PERIOD_M3)  return PERIOD_M15;
  if(signal_timeframe == PERIOD_M15) return PERIOD_H2;
  if(signal_timeframe == PERIOD_H2)  return PERIOD_D1;

  // 2ND TIMEFRAMES FRACTAL
  if(signal_timeframe == PERIOD_M2)  return PERIOD_M6;
  if(signal_timeframe == PERIOD_M6)  return PERIOD_M30;
  if(signal_timeframe == PERIOD_M30) return PERIOD_H4;
  if(signal_timeframe == PERIOD_H4)  return PERIOD_D1;

  return signal_timeframe;
}

int GetMATrendPeriod(int index_period)
{
  if(index_period >= 1  && index_period <= 7)  return 34;
  if(index_period >= 8  && index_period <= 12) return 55;
  if(index_period >= 13 && index_period <= 20) return 89;
  if(index_period >= 21 && index_period <= 33) return 144;
  if(index_period >= 34)                       return 233;

  return 34;
}

void GetFilterTypePeriod(int &start, int &end)
{
  if(Indicator_Filter_Period == FILTER_PERIOD_5)    { start = 1; end = 2; }
  if(Indicator_Filter_Period == FILTER_PERIOD_8)    { start = 2; end = 3; }
  if(Indicator_Filter_Period == FILTER_PERIOD_13)   { start = 3; end = 4; }
  if(Indicator_Filter_Period == FILTER_PERIOD_21)   { start = 4; end = 5; }
  if(Indicator_Filter_Period == FILTER_PERIOD_34)   { start = 5; end = 6; }
}

void GetStructFilterTypePeriod(int &start, int &end, bool trend_struct = false)
{
  if(Indicator_Struct_Filter_Period == FILTER_PERIOD_5)    { start = 1; end = 2; }
  if(Indicator_Struct_Filter_Period == FILTER_PERIOD_8)    { start = 2; end = 3; }
  if(Indicator_Struct_Filter_Period == FILTER_PERIOD_13)   { start = 3; end = 4; }
  if(Indicator_Struct_Filter_Period == FILTER_PERIOD_21)   { start = 4; end = 5; }
  if(Indicator_Struct_Filter_Period == FILTER_PERIOD_34)   { start = 5; end = 6; }

  if(trend_struct && Indicator_Trend_Struct_Filter_Period == FILTER_PERIOD_5)    { start = 1; end = 2; }
  if(trend_struct && Indicator_Trend_Struct_Filter_Period == FILTER_PERIOD_8)    { start = 2; end = 3; }
  if(trend_struct && Indicator_Trend_Struct_Filter_Period == FILTER_PERIOD_13)   { start = 3; end = 4; }
  if(trend_struct && Indicator_Trend_Struct_Filter_Period == FILTER_PERIOD_21)   { start = 4; end = 5; }
  if(trend_struct && Indicator_Trend_Struct_Filter_Period == FILTER_PERIOD_34)   { start = 5; end = 6; }
}
