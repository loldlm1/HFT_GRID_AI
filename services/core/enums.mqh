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

enum DeterministicStrategyIds
{
  DETERMINISTIC_STRATEGY_NONE = 0,
  DETERMINISTIC_STRATEGY_1    = 1,
  DETERMINISTIC_STRATEGY_2    = 2,
  DETERMINISTIC_STRATEGY_3    = 3
};

enum SignalStates
{
	WAITING = 0,
	OPENED  = 1,
	TRALING = 2,
	CLOSED  = 3
};

// STRATEGY DIRECTION MODES
enum StrategyDirectionTypes
{
  BOTH_DIRECTION    = 0,
  BULLISH_DIRECTION = 1,
  BEARISH_DIRECTION = 2
};

enum StructureTriggerEntryModes
{
  LEVELS_AS_LIMITS = 0,
  LEVEL_AS_ZONE    = 1
};

enum SignalConcurrencyModes
{
  SINGLE_RUNNING_SIGNAL   = 0,
  MULTIPLE_RUNNING_SIGNALS = 1
};

enum StrategyRangeTypes
{
  STRATEGY_RANGE_ATR       = 0,
  STRATEGY_RANGE_POINTS    = 1,
  STRATEGY_RANGE_STRUCTURE = 2
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

enum ExecutionLegStatuses
{
  EXECUTION_LEG_INACTIVE             = 0,
  EXECUTION_LEG_WAITING              = 1,
  EXECUTION_LEG_PENDING              = 2,
  EXECUTION_LEG_ACTIVE               = 3,
  EXECUTION_LEG_COMPLETED            = 4
};

enum ExecutionEntryStyles
{
  EXECUTION_ENTRY_STYLE_STOP  = 0,
  EXECUTION_ENTRY_STYLE_LIMIT = 1
};

enum ExecutionLotTypes
{
  EXECUTION_LOT_FIXED_SIZE         = 0,
  EXECUTION_LOT_ACCOUNT_PERCENTAGE = 1,
  EXECUTION_LOT_TARGET_CURRENCY    = 2
};

enum SignalLotStrategyTypes
{
  RISK_STRATEGY_OFF     = 0,
  RISK_APPLIED_ON_LOSS  = 1,
  RISK_APPLIED_ON_WIN   = 2
};

enum SignalOutcomeTypes
{
  SIGNAL_OUTCOME_NEUTRAL = 0,
  SIGNAL_OUTCOME_WIN     = 1,
  SIGNAL_OUTCOME_LOSS    = 2
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

#define SESSION_TIME_FILTER_SLOT_TOTAL 3

enum SessionTimeFilterSlots
{
  SESSION_TIME_FILTER_ASIA   = 0,
  SESSION_TIME_FILTER_LONDON = 1,
  SESSION_TIME_FILTER_NEWYORK = 2
};

enum DstOffsetModes
{
  DST_MODE_OFF         = 0,
  DST_MODE_AUTO_EXNESS = 1,
  DST_MODE_MANUAL      = 2
};

enum ExecutionTPReferenceModes
{
  EXECUTION_TP_REF_CURRENT = 0,
  EXECUTION_TP_REF_NEXT    = 1
};

enum ProtectionRiskModes
{
  ENABLED_OFF                         = 0,
  ENABLED_EXECUTION_PROTECTION        = 1,
  ENABLED_EXECUTION_PROTECTION_DAILY  = 2,
  ENABLED_EXECUTION_PROTECTION_WEEKLY = 3
};

enum ProtectionRiskValueTypes
{
  PROTECTION_RISK_ACCOUNT_SIZE_PERCENT   = 0,
  PROTECTION_RISK_ACCOUNT_BALANCE_PERCENT = 1,
  PROTECTION_RISK_FIXED_CURRENCY         = 2
};

enum StrategyContextTypes
{
  CONTEXT_SLOT_BASE    = 0,
  CONTEXT_SLOT_TREND   = 1,
  CONTEXT_SLOT_MACRO   = 2,
  CONTEXT_SLOT_SESSION = 3
};

const int STRATEGY_CONTEXT_TOTAL = 4;

enum MarketStatusTypes
{
  MARKET_STATUS_ACTIVE           = 0,
  MARKET_STATUS_CLOSE_GUARD      = 1,
  MARKET_STATUS_BROKER_CLOSEONLY = 2,
  MARKET_STATUS_BROKER_DISABLED  = 3
};

enum MLInferenceModes
{
  ML_INFERENCE_DISABLED = 0,
  ML_INFERENCE_SHADOW   = 1,
  ML_INFERENCE_FILTER   = 2
};

#endif // _MICROSERVICES_CORE_ENUMS_MQH_
