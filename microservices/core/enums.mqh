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

enum IndicatorShiftTypes
{
  INDICATOR_SHIFT_0 = 0,
  INDICATOR_SHIFT_1 = 1,
  INDICATOR_SHIFT_2 = 2,
  INDICATOR_SHIFT_3 = 3,
  INDICATOR_SHIFT_5 = 5
};

// SOLID INDICATOR PERIOD OPTIONS (LINKED TO STOCHASTIC_STRUCTURE)
enum StochStructurePeriodTypes
{
  STOCH_STRUCTURE_PERIOD_OFF = 0,
  STOCH_STRUCTURE_PERIOD_5  = 5,
  STOCH_STRUCTURE_PERIOD_8  = 8,
  STOCH_STRUCTURE_PERIOD_13 = 13,
  STOCH_STRUCTURE_PERIOD_21 = 21,
  STOCH_STRUCTURE_PERIOD_34 = 34,
  STOCH_STRUCTURE_PERIOD_55 = 55
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
  ATR_RANGE               = 0,
  POINTS_RANGE            = 1,
  KELTNER_RANGE           = 2,
  BOLLINGER_RANGE         = 3,
  CHANNEL_INDICATOR_RANGE = 4,
  STOCH_STRUCTURE_RANGE   = 5,
  ATR_MA_RANGE            = 6
};

enum GridChannelLineTypes
{
  GRID_CHANNEL_LINE_SUPPORT    = 0,
  GRID_CHANNEL_LINE_RESISTANCE = 1,
  GRID_CHANNEL_LINE_MIDDLE     = 2
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
  TRAILING_STEP      = 1,
  TRAILING_ATR_BASED = 2,
  TRAILING_LIPS_MA   = 3
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

enum BodyVolumeFilterModes
{
  BODY_VOLUME_OFF  = 0,
  BODY_VOLUME_HIGH = 1,
  BODY_VOLUME_LOW  = 2
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
  GRID_LOT_SIZE             = 0,
  GRID_LOT_PERCENTAGE_BASED = 1,
  GRID_LOT_CURRENCY_BASED   = 2
};

enum PandoraLotTypes
{
  PANDORA_LOT_SIZE             = 0,
  PANDORA_LOT_PERCENTAGE_BASED = 1,
  PANDORA_LOT_CURRENCY_BASED   = 2
};

enum PandoraPointsValueModes
{
  PANDORA_POINTS_VALUE_MODE_POINTS      = 0,
  PANDORA_POINTS_VALUE_MODE_BOX_PERCENT = 1
};

enum PandoraRiskTrailingModes
{
  PANDORA_RISK_TRAILING_OFF     = 0,
  PANDORA_RISK_TRAILING_STEP_TP = 1
};

enum GridRiskTrendModes
{
  GRID_RM_TREND_OFF = 0,
  GRID_RM_TREND_BE  = 1,
  GRID_RM_TREND_SL  = 2,
  GRID_RM_TREND_SAR = 3,
  GRID_RM_TREND_HEDGE = 4
};

enum GridRiskAlligatorReferenceModes
{
  GRID_RISK_REF_JAWS  = 0,
  GRID_RISK_REF_TEETH = 1
};

enum GridRiskTrendTimeframeSources
{
  GRID_RISK_TF_STRATEGY = 0,
  GRID_RISK_TF_TREND    = 1,
  GRID_RISK_TF_MACRO    = 2,
  GRID_RISK_TF_SESSION  = 3
};

enum DailySignalLimitModes
{
  STOP_DAILY_SIGNALS       = 0,
  STOP_DAILY_SIGNALS_ON_LOSS = 1
};

enum SessionTimeFilterModes
{
  SESSION_FILTER_OFF         = 0,
  SESSION_FILTER_ALLOW_RUN   = 1,
  SESSION_FILTER_FORCE_CLOSE = 2
};

enum SessionTimeFilterSlots
{
  SESSION_TIME_FILTER_ASIA   = 0,
  SESSION_TIME_FILTER_LONDON = 1,
  SESSION_TIME_FILTER_NEWYORK = 2
};

#define SESSION_TIME_FILTER_SLOT_TOTAL 3

enum DstOffsetModes
{
  DST_MODE_OFF         = 0,
  DST_MODE_AUTO_EXNESS = 1,
  DST_MODE_MANUAL      = 2
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
  ENABLED_GRID_PROTECTION_DAILY = 2,
  ENABLED_GRID_PROTECTION_WEEKLY = 3
};

enum ProtectionRiskValueTypes
{
  PROTECTION_RISK_ACCOUNT_SIZE_PERCENT   = 0,
  PROTECTION_RISK_ACCOUNT_BALANCE_PERCENT = 1,
  PROTECTION_RISK_FIXED_CURRENCY         = 2
};

enum ChannelIndicatorTypes
{
  CHANNEL_INDICATOR_BOLLINGER = 0,
  CHANNEL_INDICATOR_KELTNER   = 1,
  CHANNEL_INDICATOR_ATR       = 2
};

enum StrategyEntryChannelModes
{
  ENTRY_EVAL_OFF              = 0,
  ENTRY_EVAL_GLOBAL           = 1,
  ENTRY_MODE_MA_TREND         = 2,
  ENTRY_MODE_REVERSION        = 3,
  ENTRY_MODE_BREAKOUT         = 4,
  ENTRY_EVAL_ON_TREND         = 5
};

enum StrategyGlobalStochEntryModes
{
  STOCH_ENTRY_OFF     = 0,
  STOCH_ENTRY_OVER_BS = 1
};

enum StrategyTrendModes
{
  TREND_OFF            = 0,
  TREND_ALLIGATOR_JAWS = 1,
  TREND_ALLIGATOR_TEETH = 2
};

enum StrategyContextTypes
{
  CONTEXT_SLOT_BASE    = 0,
  CONTEXT_SLOT_TREND   = 1,
  CONTEXT_SLOT_MACRO   = 2,
  CONTEXT_SLOT_SESSION = 3
};

const int STRATEGY_CONTEXT_TOTAL = 4;

inline bool EntryEvaluationUsesBPercentWindow(const StrategyEntryChannelModes mode)
{
  return false;
}

inline bool EntryEvaluationUsesBPercentMean(const StrategyEntryChannelModes mode)
{
  return (mode == ENTRY_MODE_MA_TREND ||
          mode == ENTRY_MODE_REVERSION ||
          mode == ENTRY_MODE_BREAKOUT);
}

inline bool EntryEvaluationUsesAnyBPercent(const StrategyEntryChannelModes mode)
{
  return EntryEvaluationUsesBPercentMean(mode);
}

inline bool TrendModeUsesAlligator(const StrategyTrendModes mode)
{
  return mode != TREND_OFF;
}

inline bool TrendModeUsesTeethAlligator(const StrategyTrendModes mode)
{
  return mode == TREND_ALLIGATOR_TEETH;
}

inline bool TrendModeUsesJawsAlligator(const StrategyTrendModes mode)
{
  if(!TrendModeUsesAlligator(mode))
    return false;
  return !TrendModeUsesTeethAlligator(mode);
}

enum TrendStructureFilterModes
{
  BULLISH_STRUCT_OFF       = 0,
  BULLISH_STRUCT_LL_LH     = 1,
  BULLISH_STRUCT_LL        = 2,
  BULLISH_STRUCT_LH        = 3,
  BULLISH_STRUCT_HH_LH     = 5,
  BEARISH_STRUCT_OFF       = 6,
  BEARISH_STRUCT_HH_HL     = 7,
  BEARISH_STRUCT_HH        = 8,
  BEARISH_STRUCT_HL        = 9,
  BEARISH_STRUCT_LL_HL     = 10
};

enum MarketStatusTypes
{
  MARKET_STATUS_ACTIVE           = 0,
  MARKET_STATUS_CLOSE_GUARD      = 1,
  MARKET_STATUS_BROKER_CLOSEONLY = 2,
  MARKET_STATUS_BROKER_DISABLED  = 3
};

#endif // _MICROSERVICES_CORE_ENUMS_MQH_
