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

enum ExtremumEngineIds
{
	EXTREMUM_ENGINE_NONE = 0,
	EXTREMUM_ENGINE_V1   = 1
};

enum SignalStates
{
	WAITING = 0,
	OPENED  = 1,
	TRALING = 2,
	CLOSED  = 3
};

enum StructureTriggerEntryModes
{
  LEVELS_AS_LIMITS = 0,
  LEVEL_AS_ZONE    = 1
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

enum ExecutionLotTypes
{
  EXECUTION_LOT_FIXED_SIZE              = 0,
  EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT = 1
};

enum ExecutionOrderStates
{
  EXECUTION_ORDER_WAITING        = 0,
  EXECUTION_ORDER_SEND_ATTEMPTED = 1,
  EXECUTION_ORDER_BROKER_ACTIVE  = 2,
  EXECUTION_ORDER_BROKER_CLOSED  = 3,
  EXECUTION_ORDER_CANCELED       = 4,
  EXECUTION_ORDER_FAILED         = 5
};

enum ExecutionAdmissionStatuses
{
  EXECUTION_ADMISSION_NOT_EVALUATED = 0,
  EXECUTION_ADMISSION_CANDIDATE     = 1,
  EXECUTION_ADMISSION_BLOCKED       = 2,
  EXECUTION_ADMISSION_ALLOWED       = 3,
  EXECUTION_ADMISSION_SENT          = 4,
  EXECUTION_ADMISSION_FILLED        = 5,
  EXECUTION_ADMISSION_SEND_FAILED   = 6
};

enum BrokerSessionTimeModes
{
  FIXED_TIME_SESSIONS = 0,
  EXNESS_SESSION       = 1
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
