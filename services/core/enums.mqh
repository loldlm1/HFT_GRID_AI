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

enum PivotFractalEngineIds
{
  PIVOT_FRACTAL_NONE = 0,
  PIVOT_FRACTAL_V2   = 2
};

enum PivotLevelIds
{
  PIVOT_LEVEL_S3 = 0,
  PIVOT_LEVEL_S2 = 1,
  PIVOT_LEVEL_S1 = 2,
  PIVOT_LEVEL_PP = 3,
  PIVOT_LEVEL_R1 = 4,
  PIVOT_LEVEL_R2 = 5,
  PIVOT_LEVEL_R3 = 6
};

enum PivotWindowStates
{
  PIVOT_WINDOW_EMPTY   = 0,
  PIVOT_WINDOW_PENDING = 1,
  PIVOT_WINDOW_VALID   = 2,
  PIVOT_WINDOW_INVALID = 3
};

enum PivotTriggerStates
{
  PIVOT_TRIGGER_AVAILABLE = 0,
  PIVOT_TRIGGER_CONSUMED  = 1,
  PIVOT_TRIGGER_EXPIRED   = 2
};

enum PivotPriceSideStates
{
  PIVOT_PRICE_SIDE_UNAVAILABLE = 0,
  PIVOT_PRICE_SIDE_BELOW       = 1,
  PIVOT_PRICE_SIDE_EQUAL       = 2,
  PIVOT_PRICE_SIDE_ABOVE       = 3
};

enum PivotPpArmStates
{
  PIVOT_PP_UNARMED    = 0,
  PIVOT_PP_BUY_ARMED  = 1,
  PIVOT_PP_SELL_ARMED = 2
};

enum PivotRouteStatuses
{
  PIVOT_ROUTE_NOT_BUILT        = 0,
  PIVOT_ROUTE_ALLOWED          = 1,
  PIVOT_ROUTE_INVALID_GEOMETRY = 2
};

enum ExecutionLotTypes
{
  EXECUTION_LOT_FIXED_SIZE                = 0,
  EXECUTION_LOT_REFERENCE_BALANCE_PERCENT = 1
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

enum MarketStatusTypes
{
  MARKET_STATUS_ACTIVE           = 0,
  MARKET_STATUS_CLOSE_GUARD      = 1,
  MARKET_STATUS_BROKER_CLOSEONLY = 2,
  MARKET_STATUS_BROKER_DISABLED  = 3
};

#endif // _MICROSERVICES_CORE_ENUMS_MQH_
