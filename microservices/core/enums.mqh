//+------------------------------------------------------------------+
//|                                    microservices/core/enums.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_CORE_ENUMS_MQH_
#define _MICROSERVICES_CORE_ENUMS_MQH_

// SIGNAL ENUMERATIONS

enum SignalTypes
{
	NO_SIGNAL = 0,
	BULLISH   = 1,
	BEARISH   = 2
};

enum SignalStates
{
	WAITING = 0,
	OPENED  = 1,
	TRALING = 2,
	CLOSED  = 3
};

// BASE INDICATOR STRATEGIES
enum BaseIndicatorStrategyTypes
{
	BB_NONE_TYPE = 0,
	MA_TYPE      = 1,
	BANDS_TYPE   = 2
};

// BASE INDICATOR PERIOD OPTIONS (LINKED TO BB_PERCENT_STANDARD)
enum BaseIndicatorPeriodTypes
{
  BASE_PERIOD_5  = 5,
  BASE_PERIOD_8  = 8,
  BASE_PERIOD_13 = 13,
  BASE_PERIOD_21 = 21,
  BASE_PERIOD_34 = 34,
  BASE_PERIOD_55 = 55
};

// SOLID INDICATOR PERIOD OPTIONS (LINKED TO STOCHASTIC_STRUCTURE)
enum SolidIndicatorPeriodTypes
{
  SOLID_PERIOD_5  = 5,
  SOLID_PERIOD_8  = 8,
  SOLID_PERIOD_13 = 13,
  SOLID_PERIOD_21 = 21,
  SOLID_PERIOD_34 = 34,
  SOLID_PERIOD_55 = 55
};

// STRATEGY DIRECTION MODES
enum StrategyDirectionTypes
{
  BOTH_DIRECTION    = 0,
  BULLISH_DIRECTION = 1,
  BEARISH_DIRECTION = 2
};

enum SignalConcurrencyModes
{
  SINGLE_RUNNING_SIGNAL   = 0,
  MULTIPLE_RUNNING_SIGNALS = 1
};

enum SupportRetestFilterModes
{
  SUPPORT_DISABLED = 0,
  SUPPORT_61       = 1,
  SUPPORT_78       = 2
};

enum ResistanceRetestFilterModes
{
  RESISTANCE_DISABLED = 0,
  RESISTANCE_61       = 1,
  RESISTANCE_78       = 2
};

enum GridBaseStrategyTypes
{
  ATR_RANGE    = 0,
  POINTS_RANGE = 1
};

enum GridAtrRangeModes
{
  GRID_ATR_REFERENCE_SUP_RES = 0,
  GRID_ATR_REFERENCE_TRAILING = 1,
  GRID_ATR_REFERENCE_BOTH = 2,
  GRID_ATR_REFERENCE_ROOT = 3
};

enum BreakEvenModes
{
  BE_DISABLE        = 0,
  BE_ENABLE         = 1,
  BE_PARTIAL_ENABLE = 2
};

enum TrailingStrategyModes
{
  TRAILING_DEFAULT   = 0,
  TRAILING_ATR_BASED = 1,
  TRAILING_LIPS_MA   = 2
};

enum TrailingExecutionModes
{
  TRAILING_EXECUTION_DEFAULT   = 0,
  TRAILING_EXECUTION_AGGRESIVE = 1
};

enum SlopeTypes
{
	NO_SLOPE   = 0,
	UP_SLOPE   = 1,
	DOWN_SLOPE = 2
};

enum PercentilTypes
{
	PERCENTIL_NULL = -99,
	PERCENTIL_MIN  = -10,
	PERCENTIL_MAX  = 110,
	PERCENTIL_0    = 0,
	PERCENTIL_10   = 10,
	PERCENTIL_20   = 20,
	PERCENTIL_30   = 30,
	PERCENTIL_40   = 40,
	PERCENTIL_50   = 50,
	PERCENTIL_60   = 60,
	PERCENTIL_70   = 70,
	PERCENTIL_80   = 80,
	PERCENTIL_90   = 90,
	PERCENTIL_100  = 100
};

enum OscillatorPricesTypes
{
	OSCILLATOR_HIGH_PRICES = 0,
	OSCILLATOR_LOW_PRICES  = 1
};

enum OscillatorStructureTypes
{
	OSCILLATOR_STRUCTURE_EQ = 0, // iguales o sin cambio
	OSCILLATOR_STRUCTURE_HH = 1, // Higher High
	OSCILLATOR_STRUCTURE_HL = 2, // Higher Low
	OSCILLATOR_STRUCTURE_LH = 3, // Lower High
	OSCILLATOR_STRUCTURE_LL = 4  // Lower Low
};

enum BodyTrendTypes
{
	BODY_UNDEFINED = 0,
	STRONG_BODY_TREND = 1,
	WEAK_BODY_TREND = 2
};

enum BodyMATypes
{
	BODY_UNDEFINED_MA = 0,
	BODY_BULLISH_MA = 1,
	BODY_BEARISH_MA = 2
};

enum GridOrderStatuses
{
  GRID_ORDER_INACTIVE             = 0,
  GRID_ORDER_WAITING              = 1,
  GRID_ORDER_STOP_TRAILING_ACTIVE = 2,
  GRID_ORDER_ACTIVE               = 3,
  GRID_ORDER_TP_TRAILING_ACTIVE   = 4,
  GRID_ORDER_COMPLETED            = 5
};

enum GridEntryStyles
{
  GRID_ENTRY_STYLE_STOP  = 0,
  GRID_ENTRY_STYLE_LIMIT = 1
};

enum GridLotTypes
{
  GRID_LOT_SIZE                 = 0,
  GRID_LOT_PERCENTAGE_BASED     = 1,
  GRID_LOT_CURRENCY_BASED       = 2,
  GRID_LOT_CALCULATED           = 3,
  GRID_LOT_EQUITY_PERCENT_BASED = 4
};

enum GridRiskTrendModes
{
  GRID_RM_TREND_OFF      = 0,
  GRID_RM_TREND_LIPS_BE  = 1,
  GRID_RM_TREND_LIPS_SL  = 2
};

enum DailySignalLimitModes
{
  STOP_DAILY_SIGNALS       = 0,
  STOP_DAILY_SIGNALS_ON_LOSS = 1
};

enum GridTPReferenceModes
{
  GRID_TP_REF_CURRENT = 0,
  GRID_TP_REF_NEXT    = 1
};

enum ProtectionRiskModes
{
  ENABLED_OFF                 = 0,
  ENABLED_GRID_PROTECTION     = 1,
  ENABLED_GRID_PROTECTION_DAILY = 2
};

enum ProtectionRiskValueTypes
{
  PROTECTION_RISK_ACCOUNT_SIZE_PERCENT   = 0,
  PROTECTION_RISK_ACCOUNT_BALANCE_PERCENT = 1,
  PROTECTION_RISK_FIXED_CURRENCY         = 2
};

enum StrategyTrendModes
{
  TREND_OFF      = 0,
  TREND_BPERCENT = 1,
  TREND_ALLIGATOR = 2,
  TREND_BOTH      = 3
};

enum TrendStructureFilterModes
{
  BULLISH_STRUCT_OFF       = 0,
  BULLISH_STRUCT_LL_LH     = 1,
  BULLISH_STRUCT_LL        = 2,
  BULLISH_STRUCT_LH        = 3,
  BULLISH_STRUCT_OFF_FINAL = 4,
  BEARISH_STRUCT_OFF       = 5,
  BEARISH_STRUCT_HH_HL     = 6,
  BEARISH_STRUCT_HH        = 7,
  BEARISH_STRUCT_HL        = 8,
  BEARISH_STRUCT_OFF_FINAL = 9
};

enum MarketStatusTypes
{
  MARKET_STATUS_ACTIVE           = 0,
  MARKET_STATUS_CLOSE_GUARD      = 1,
  MARKET_STATUS_BROKER_CLOSEONLY = 2,
  MARKET_STATUS_BROKER_DISABLED  = 3
};

#endif // _MICROSERVICES_CORE_ENUMS_MQH_
