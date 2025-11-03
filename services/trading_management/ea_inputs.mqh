//+------------------------------------------------------------------+
//|                               trading_management/ea_inputs.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_

// NOTE: Keep input declarations centralized to guarantee consistent defaults
// across services. Any module relying on these inputs should include this file
// (directly or through the trading_management aggregator).

input group  "+= TC HFT Grid AI EA V1.0 =+";
input string EA_License_Key = "";

input group  "+= Account Settings EA =+";
input double Account_Size     = 1200.0;
input int    Custom_Magic     = 0;
input double Max_Spread       = 15.0;
input double Min_Range_Points = 15.0;

input group  "+= Strategy Context =+";
// Single timeframe used across all indicators during Phase 0.
input ENUM_TIMEFRAMES Strategy_Timeframe = PERIOD_M1;
input BaseIndicatorPeriodTypes Base_Indicator_Period_Type = BASE_PERIOD_21;
input ENUM_MA_METHOD          Base_Indicator_MA_Method  = MODE_EMA;
input BaseIndicatorStrategyTypes Base_Indicator_Strategy_Type = MA_TYPE;
input SolidIndicatorStrategyTypes Solid_Indicator_Strategy_Type = SOLID_NONE_TYPE;
input SolidIndicatorPeriodTypes  Solid_Indicator_Period_Type  = SOLID_PERIOD_5;
input StrategyDirectionTypes     Strategy_Direction_Mode      = BOTH_DIRECTION;

input group  "+= Developer Debug Settings =+";
input bool Test_Mode               = false;
input bool Hide_Indicator_Variants = true;
input bool Enable_Logs             = true;
input bool Enable_Verification_Logs = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
