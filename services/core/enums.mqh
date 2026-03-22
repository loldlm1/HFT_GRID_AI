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

enum StructureTouchPolicyModes
{
  ALLOW_RETEST     = 0,
  FIRST_TOUCH_ONLY = 1
};

enum CandleStrategyTypes
{
  OFF_CANDLE_STRUCTURE       = 0,
  SHRINKED_CANDLE_STRUCTURE  = 1,
  EXPANDED_CANDLE_STRUCTURE  = 2,
  BULLISH_CANDLE_STRUCTURE   = 3,
  BEARISH_CANDLE_STRUCTURE   = 4
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
  FIB_LEVEL_RANGE        = 2
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
  GRID_ORDER_COMPLETED            = 4
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

enum GridTPReferenceModes
{
  GRID_TP_REF_CURRENT = 0,
  GRID_TP_REF_NEXT    = 1
};

enum TrailingStructureModes
{
  TRAILING_OFF             = 0,
  TRAILING_BY_STRUCTURE    = 1,
  TRAILING_BY_STRUCTURE_TP_BE = 2
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

enum StrategyContextTypes
{
  CONTEXT_SLOT_BASE    = 0,
  CONTEXT_SLOT_TREND   = 1,
  CONTEXT_SLOT_MACRO   = 2,
  CONTEXT_SLOT_SESSION = 3
};

const int STRATEGY_CONTEXT_TOTAL = 4;

enum TrendStructureCompoundModes
{
  COMPOUND_MODE_OFF = 0,

  // Continuation
  COMPOUND_MODE_TREND_RIDE_BUY         = 1,
  COMPOUND_MODE_TREND_RIDE_SELL        = 2,
  COMPOUND_MODE_PULLBACK_CONTINUE_BUY  = 3,
  COMPOUND_MODE_PULLBACK_CONTINUE_SELL = 4,

  // Reversion
  COMPOUND_MODE_REVERSAL_EARLY_BUY     = 5,
  COMPOUND_MODE_REVERSAL_EARLY_SELL    = 6,

  // Breakout
  COMPOUND_MODE_BREAKOUT_READY_BUY     = 7,
  COMPOUND_MODE_BREAKOUT_READY_SELL    = 8,

  // Uncommon / defensive
  COMPOUND_MODE_VOLATILITY_TRAP_BUY    = 9,
  COMPOUND_MODE_VOLATILITY_TRAP_SELL   = 10
};

enum MarketStatusTypes
{
  MARKET_STATUS_ACTIVE           = 0,
  MARKET_STATUS_CLOSE_GUARD      = 1,
  MARKET_STATUS_BROKER_CLOSEONLY = 2,
  MARKET_STATUS_BROKER_DISABLED  = 3
};

#endif // _MICROSERVICES_CORE_ENUMS_MQH_
